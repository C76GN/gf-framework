# Save Profile 运行时编排决策

状态：Accepted

适用版本：Unreleased
决策范围：`gf.extension.save`

## 背景

GF 已经具备版本化 `GFSaveDocument`、独立 section、迁移注册表、事务化
`GFStorageUtility` 和 Save Graph 的应用回滚能力，但项目仍需自行处理以下跨模块问题：

- 多个业务模块如何共同拥有一个存档文档，而不互相读取字段；
- 连续自动保存如何避免并行写入、丢失较新的状态或无限积压；
- 异步读取、迁移、校验、应用和回滚如何形成一个可观察终态；
- 缺失、损坏、未来版本和临时 IO 故障如何被明确区分；
- 测试如何确定性地注入失败，而不依赖真实磁盘竞争或计时。

这些责任不属于具体游戏业务，也不应由 UI、场景或单个 section 承担。

## 决策

新增 Save Profile 运行时层，复用既有文档、迁移和存储协议：

- `GFSaveProfile` 声明 profile 身份、文件、文档版本和 section providers。
- `GFSaveSectionProvider` 是 section 的唯一所有者，只暴露采集、应用和回滚协议。
- `GFSaveProfileUtility` 串行协调每个 profile 的保存、读取、迁移和应用。
- `GFSaveProfileOperation` 是异步调用句柄；`GFSaveProfileResult` 是不可变终态快照。
- `GFSaveRecoveryPolicy` 只允许显式、可审计的恢复和有界重试。
- `GFStorageAsyncOperation` 为每次底层 IO 提供独立 request ID 和类型化终态。

Profile 层不引入第二套文件格式，不解释业务字段，不绑定槽位 UI、云同步或平台 SDK。

## 核心不变量

1. 同一 profile 最多只有一个由状态机推进的当前 IO；超时后无法取消的 detached 写入可与重试物理并存，但只保留路径所有权和终态观测，不再参与当前调度。
2. 每次保存请求获得单调递增 generation；在途保存期间的新请求只保留最新 generation。
3. 被合并的保存句柄只有在包含其 generation 的后续写入成功后才完成。
4. `flush_profile()` 捕获调用时的目标 generation，不把“已入队”等同于“已持久化”。
5. 文档在全部迁移和校验成功前不得触碰运行时状态。
6. 应用前先采集所有可加载 provider 的回滚快照；任一应用失败后按逆序回滚。
7. 缺失或损坏数据默认失败并保留现状；使用当前状态恢复必须显式配置。
8. 未来 schema 永不进入重置或使用当前状态分支，必须升级代码后再读取。
9. 重试只适用于策略声明的临时错误，并受有限延迟序列约束。
10. 终态结果必须保留操作类型、generation、失败 section、底层读取结果和恢复信息。
11. 注册时必须规范化并独占存储目标，编译运行时配置；注册后的 Resource 变更不得改变在途行为。
12. 底层完成必须按 request ID 关联，禁止用文件名推断请求身份。
13. 未知 section 默认拒绝；保留或丢弃只能由显式政策决定。
14. 完成信号只能在状态机稳定后发出；provider 和状态回调中的重入被拒绝，完成回调可发起新的非递归操作。
15. 无法证明写入未提交时必须返回 `outcome_unknown`，不得伪装成确定失败。
16. 失败和未知写入证据必须按 generation 保存，后续失败不得覆盖较早 generation 的未知结果。
17. 超时写入在迟到终态前继续占有规范存储路径；不得注销 profile 或把路径转移给其他 profile。
18. 同一逻辑保存仍在等待或执行重试时，任一覆盖该 generation 的物理写入成功都立即胜出；其他在途尝试只保留路径所有权，不得再翻转逻辑终态。
19. 就绪读取和等待保存采用有界轮转：最老就绪读取不会被更新保存饿死，服务一个读取后也必须给等待保存一个轮次。

## 状态机

每个 profile 独立维护以下状态：

| 状态 | 含义 | 合法后继 |
| --- | --- | --- |
| `idle` | 无 IO、无到期重试 | `gathering`、`loading` |
| `gathering` | 在主线程采集不可变保存快照 | `saving`、`idle` |
| `saving` | 等待唯一写入请求的类型化终态 | `retry_wait`、`idle`、`gathering` |
| `loading` | 等待读取终态 | `retry_wait`、`applying`、`idle` |
| `retry_wait` | 等待单调时钟达到下一次重试时间 | `saving`、`loading`、`idle` |
| `applying` | 主线程迁移、校验和事务化应用 | `idle` |
| `disposed` | Utility 已释放，拒绝新任务 | 无 |

`saving -> gathering` 表示当前 generation 完成后采集被合并的最新 generation，正常
调度不会主动并行启动两个当前写入。物理写入超时后无法证明已经取消，因此 detached
原请求可与后续重试短暂并存；两者仍由同一 Profile 保有路径，只有重试属于当前 IO。
读取请求在调用时捕获的 generation 屏障收敛后执行，不等待之后请求的更新保存；加载或
应用过程中不接受保存，以免基于旧内存状态覆盖新读取的数据。`retry_wait -> idle` 表示
等待期间 detached 写入迟到成功，计划重试随逻辑保存完成而取消。

## 失败矩阵

| 阶段/故障 | 默认结果 | 可恢复行为 | 必须保留的证据 |
| --- | --- | --- | --- |
| Profile、provider 或规范路径无效 | `invalid_profile` | 无 | 注册报告、profile/schema id、规范路径 |
| 当前 Profile 禁止该操作 | `unsupported_operation` | 修改声明后重新注册 | 操作类型、profile id |
| load/apply/provider 或状态回调期间请求保存或重入 | `busy` | 回调结束后由上层重新请求 | 操作类型、稳定状态快照 |
| section 采集失败或载荷不可持久化 | `gather_failed` | 后续新 generation 可重试 | section id、错误码 |
| 应用前回滚快照采集失败 | `snapshot_failed` | 修复 provider 后重试 | section id、错误码 |
| 异步 IO 启动失败 | `storage_failed` | 仅临时错误按有界计划重试 | 尝试次数、错误码 |
| 写入临时失败 | `storage_failed` | 按策略延迟重试 | generation、尝试次数 |
| 写入永久失败 | `storage_failed` | 无自动恢复 | generation、错误码 |
| 读取 IO 超时 | `storage_failed` | 可由上层重新读取 | request ID、尝试次数、超时 |
| 写入超时或写入中释放 | `outcome_unknown` | 先重读/对账，再决定重试 | request ID、generation、超时/释放原因 |
| 文件不存在 | `missing` | 显式 `use_current_state` | 原始 `GFStorageReadResult` |
| 文档损坏或完整性失败 | `corrupt` | 显式 `use_current_state`，不立即覆盖原文件 | 原始读取结果、恢复动作 |
| schema id 不匹配 | `schema_mismatch` | 无 | 实际/目标 schema |
| 旧版本缺少迁移链 | `migration_failed` | 注册完整迁移链后重试 | 迁移结果 |
| 迁移步骤失败 | `migration_failed` | 修复步骤后重试 | 迁移结果、步骤 id |
| 文档或 section 来自未来版本 | `future_schema` | 禁止恢复或重置 | 实际/目标版本 |
| 当前 schema 校验失败 | `validation_failed` | 修复数据/契约后重试 | 校验报告 |
| provider 应用失败 | `apply_failed` | 自动逆序回滚已应用 provider | 失败 section、回滚错误 |
| 回滚失败 | `rollback_failed` | 无静默降级，状态视为未知 | 原始失败和全部回滚错误 |
| Utility 释放时存在未启动任务 | `disposed` | 无 | 未完成 operation 列表 |
| 超时写入迟到完成 | 已有句柄终态不变；仍在重试的逻辑保存以任一成功写入为准 | 对账后继续；成功会取消未启动重试 | request ID、generation、全部尝试 ID、迟到终态 |
| 其他同名文件请求完成 | 不改变当前操作 | 无 | request ID、已完成句柄 |

## 恢复与重试政策

- `missing` 与 `corrupt` 默认动作均为 `fail`。
- `use_current_state` 只表示保留内存中的当前/default 状态并返回显式 recovered
  终态；读取操作本身不写盘，也不删除、替换或修补原文件。
- 未来 schema、schema id 不匹配和迁移失败不属于损坏恢复。
- 重试延迟是有限的毫秒序列；序列耗尽后必须返回失败，禁止无限循环。
- 时间判断只使用注入的 `GFClock` 单调时间，测试使用 `GFManualClock`。
- 每次 IO 都有正数超时；读取超时为确定失败，写入超时为结果未知。
- `strict_integrity` 关闭只改变底层读取许可，不允许 Profile 把已知完整性失败当作有效文档。
- 未知 section 默认拒绝；`preserve` 会缓存并在下一次保存原样合并，`drop` 才会丢弃。

## 验证策略

故障注入测试至少覆盖：

- 在途写入期间多次保存只产生一次后续最新 generation 写入；
- flush 等待调用时可见的最新 generation；
- 临时失败按单调时钟和有限延迟重试，永久失败不重试；
- section 应用失败后已应用 section 被逆序回滚；
- 缺失/损坏默认失败，显式策略只保留当前状态；
- 未来 schema 即使配置恢复动作也必须失败；
- 同文件外部请求、注册后 Resource 变更和重复规范路径不会破坏请求身份；
- load/apply 期间保存、provider/状态回调重入和完成回调释放都获得稳定、单次终态；
- 完成回调在稳定终态后可安全发起新的非递归操作；
- 写入超时/释放返回 outcome-unknown，迟到回调不会二次完成；
- 原写入在等待重试或重试在途时迟到成功，会完成仍未终结的逻辑保存并阻止后续失败翻转结果；
- 就绪读取与等待保存交替获得有界轮次，任一方向的持续请求都不能让另一方向无限饥饿；
- 后续 generation 失败不会抹掉较早 generation 的 outcome-unknown，迟到终态前路径不能转移；
- 未知 section 的 reject、preserve、drop 三种政策均有往返测试；
- Storage 的未来格式、迁移失败和非严格完整性失败保持类型化分类；
- 真实 `GFStorageUtility` 往返测试覆盖异步句柄集成，不只依赖测试替身。

## 后果

项目获得统一、可测试的异步存档入口，业务模块只实现自己的 section provider。
代价是 provider 必须定义稳定 section id、版本和可回滚应用语义；注册后这些身份与能力
被冻结。无法回滚的外部副作用必须留在更高层事务参与者中，不能伪装成普通 section
应用。写入结果未知时，上层还必须采用重读、版本戳或业务对账策略，而不能盲目重复提交。
