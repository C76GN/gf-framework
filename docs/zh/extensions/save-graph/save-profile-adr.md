# Save Profile 运行时编排决策

状态：Accepted

适用版本：11.0.0
决策范围：`gf.extension.save`

## 背景

GF 已经具备版本化 `GFSaveDocument`、独立 section、迁移注册表、事务化
`GFStorageUtility` 和 Save Graph 的应用回滚能力，但项目仍需自行处理以下跨模块问题：

- 多个业务模块如何共同拥有一个存档文档，而不互相读取字段；
- 连续自动保存如何避免并行写入、丢失较新的状态或无限积压；
- 保存请求如何只入队，并把大型 Provider 的主线程准备限制在可配置预算内；
- 异步读取、迁移、校验、应用和回滚如何形成一个可观察终态；
- 缺失、损坏、未来版本和临时 IO 故障如何被明确区分；
- 共享同一组 Provider 的多个 Profile 如何只有一个可证明的活动身份；
- Profile 切换、显式恢复和 section 修改如何跨多次底层操作保持原子边界；
- 写入结果未知时如何冻结冲突工作，等待 generation 证据并显式严格重读；
- 测试如何确定性地注入失败，而不依赖真实磁盘竞争或计时。

这些责任不属于具体游戏业务，也不应由 UI、场景或单个 section 承担。

## 决策

新增 Save Profile 运行时层，复用既有文档、迁移和存储协议：

- `GFSaveProfile` 声明 profile 身份、文件、文档版本和 section providers。
- `GFSaveProfileRequest` 以一次性 opaque 句柄分别接管 document metadata、Provider
  context 和 result metadata；保存接纳只做 O(1) claim，不复制调用方对象图。
- `GFSaveSectionProvider` 是 section 的唯一所有者；保存通过
  `begin_save_snapshot()` / `_begin_save_snapshot()` 创建
  `GFSaveSectionSnapshotOperation`，读取事务回滚则单独使用 `_capture_section()`。
- `GFSaveProfileUtility` 串行协调每个 profile 的保存、读取、迁移和应用，并以全局
  work-unit 预算、单 profile slice 预算和软时间预算轮转推进保存准备。
- `GFStoragePayloadTransfer` 接收准备完成的文档所有权；Storage 执行器只执行纯
  Variant 图预检、物化、编码和 IO，不访问 Provider、场景树或业务对象。Profile 不选择
  或推断执行器；共享 Storage 的 `AUTOMATIC` 模式可按运行时能力选择 threaded 或
  cooperative，并保持相同的 Operation 与事务终态。
- `GFSaveProfileOperation` 是异步调用句柄；`GFSaveProfileResult` 是不可变终态快照，
  分开记录准备与 Storage 耗时，完整文档只存在于 load 结果。
- `GFSaveRecoveryPolicy` 只允许显式、可审计的恢复和有界重试。
- `GFStorageAsyncOperation` 为每次底层 IO 提供独立 request ID 和类型化终态。
- `GFSaveProfileTransactionCoordinator` 在上述原语之上编译精确 provider domain，管理
  活动 Profile 身份，并串行推进 activate、switch、bootstrap、adopt、对应的 and-switch
  continuation、mutation 和 reconcile。
- `GFSaveProfileTransactionOperation` / `GFSaveProfileTransactionResult` 为跨 Profile 流程
  提供独立类型化句柄与不可变终态，不扩张普通 `GFSaveProfileResult` 的单 Profile 语义。
- `GFSaveProfileRecoveryLease` 把已知 missing/corrupt 恢复选择变成一次性显式能力；
  `GFSaveProfileReconcileLease` 与 `GFSaveProfileReconcileRequest` 负责未知写入的受控重读收敛。
- `GFSaveSectionMutation` 与一次性 `GFSaveProfileMutationRequest` 提交候选 section，
  不接受可在事务中执行任意副作用的 Callable。

Profile 层不引入第二套文件格式，不解释业务字段，不绑定槽位 UI、云同步或平台 SDK。

## 核心不变量

1. 同一 profile 最多只有一个由状态机推进的当前 IO；超时后无法取消的 detached 写入可与重试物理并存，但只保留路径所有权和终态观测，不再参与当前调度。
2. 每次保存请求获得单调递增 generation；在途保存期间的新请求只保留最新 generation。
3. 被合并的保存句柄只有在包含其 generation 的后续写入成功后才完成。
4. `flush_profile()` 捕获调用时的目标 generation，不把“已入队”等同于“已持久化”。
5. 文档在全部迁移和校验成功前不得触碰运行时状态。
6. 应用前先采集所有可加载 provider 的回滚快照；任一应用失败后按逆序回滚。
7. 缺失或损坏数据默认失败并保留现状；非 managed 普通读取使用当前状态必须显式配置。
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
20. `save_profile()` 先验证 Profile、能力和生命周期，再一次性 claim `GFSaveProfileRequest`；拒绝的边界不得消费 Request，成功接纳只完成 O(1) 所有权转移、generation 分配和入队。
21. 保存 Snapshot 只在主线程按全局 work-unit、单 profile slice 和软时间预算推进；软时间预算只能阻止开始下一个 slice，不能抢占已经开始的 Provider 回调。
22. Snapshot、section payload、metadata 和 Storage transfer 采用逻辑 move；交出所有权后，生产者必须放弃源值及全部嵌套集合 alias。
23. Storage 首次 claim transfer 时冻结 Storage 实例、规范文件名、canonical target file-family identity 与 codec options；超时 detached attempt 与重试可同时持有同一 Snapshot 的只读 lease，最后一个 lease 结束且所有者释放后才可销毁载荷。
24. Storage 执行器只能处理已移交的纯 Variant 图；图预算或可持久化性预检失败必须在本次新写入的编码以及 temp、marker、final 事务提交副作用前结束。既有事务 recovery 与目录初始化是独立前置生命周期；该约束不因执行器位于 worker thread 或主线程 lifecycle tick 而改变。
25. 保存终态不得为了诊断保留完整文档副本；只有读取终态可通过 `get_document()` 返回文档，准备耗时与 Storage attempt 累计耗时必须分开报告；同时活跃的 attempt 分别累计，重叠区间不折叠。
26. Storage 执行器失败报告只允许携带有界结构索引、Variant 类型和预算计数；Save 只能用文档构造时记录的 entry index 映射 section，不得复制 key/value 或可离线关联的 key 摘要。
27. Save Operation 只持有对应请求的 result metadata；document metadata 与 Provider context 由最新 generation 状态直接接管，开始准备时通过 assignment 移入当前状态，不得深复制。
28. Provider domain 只由完全相同的有序 Provider 对象身份构成；任何部分重叠或顺序不同的拓扑都不得共享活动身份或锁域。
29. 每个 domain 最多有一个活动 Profile；只有严格加载或显式恢复写入获得确定成功后才可原子发布或切换活动身份。
30. Coordinator 管理的 Profile 只允许稳定活动身份执行直接 save/flush；直接 load、非活动 Profile 操作和事务/fence 期间的全部直接操作必须失败关闭。
31. Switch 必须先 flush 调用时源 generation，再采集完整 Provider 快照并严格加载目标；已知失败按逆序恢复且不改变源活动身份。
32. 首次 activate 与 switch 的 missing 只能产生 Bootstrap Recovery Lease，corrupt 只能产生 Adopt Recovery Lease；switch Lease 还必须绑定仍活动的来源。两类一次性能力不得互换、复用或跨 domain generation 使用；无法为 Storage family 结构损坏签发精确 reset 授权时失败关闭。
33. Bootstrap/Adopt 与对应的 and-switch continuation 只有在候选写入确定成功后才发布目标；switch continuation 必须重新 flush 调用时来源，按需先完成来源绑定的 family reset，普通恢复政策不得隐式发布或切换活动身份。
34. Mutation 必须先固定 Provider 顺序并采集回滚快照，再应用类型化候选并等待保存终态；已知 Storage 失败证明未提交，因此逆序恢复内存且不得自动补偿写入。
35. 任何无法证明提交与否的写入都必须冻结整个 domain 并返回 Reconcile Lease；不得自动回滚、补偿、重试、激活或接受冲突工作。
36. Reconcile Lease 在底层 generation 证据 settled 前保持 waiting，pending 调用不 claim Request；ready 后只能严格重读 lease 指定 Profile，完整应用成功才解锁并重建活动身份。
37. Quiesce 必须先关闭 Coordinator 的新业务准入，再等待已接纳事务、底层 Profile 操作和路径所有权收敛；只允许既有 ready Reconcile Lease 作为 closure continuation 严格重读，不能借此创建其他事务；同步 dispose 不得把未知写入伪装成确定失败或已回滚。
38. 受管 strict load 必须绑定 manager capability，并在文档应用前及每次 Provider 回调后复核；dispose 撤权后的迟到读取不得提交 Provider 状态，已开始应用时必须逆序恢复并显式报告恢复失败。

## 状态机

每个 profile 独立维护以下状态：

| 状态 | 含义 | 合法后继 |
| --- | --- | --- |
| `idle` | 无 IO、无到期重试 | `preparing`、`loading` |
| `preparing` | 在主线程按预算推进不可变保存 Snapshot | `saving`、`idle` |
| `saving` | 等待当前写入请求的类型化终态 | `retry_wait`、`idle`、`preparing` |
| `loading` | 等待读取终态 | `retry_wait`、`applying`、`idle` |
| `retry_wait` | 等待单调时钟达到下一次重试时间 | `saving`、`loading`、`idle` |
| `applying` | 主线程迁移、校验和事务化应用 | `idle` |
| `disposed` | Utility 已释放，拒绝新任务 | 无 |

`saving -> preparing` 表示当前 generation 完成后，为被合并的最新 generation 创建并
推进新的 Snapshot。正常调度不会主动并行启动两个当前写入。物理写入超时后无法证明
已经取消，因此 detached 原请求可与后续重试短暂并存；两者仍由同一 Profile 保有路径，
只有重试属于当前 IO，并从同一个冻结 transfer 取得独立 lease。
读取请求在调用时捕获的 generation 屏障收敛后执行，不等待之后请求的更新保存；加载或
应用过程中不接受保存，以免基于旧内存状态覆盖新读取的数据。`retry_wait -> idle` 表示
等待期间 detached 写入迟到成功，计划重试随逻辑保存完成而取消。

Coordinator 在 primitive 状态机之外为每个 provider domain 维护以下状态：

| Domain 状态 | 含义 | 公开准入 |
| --- | --- | --- |
| `inactive` | 尚无活动 Profile | activate；匹配 lease 的 bootstrap/adopt |
| `active` | 一个 Profile 拥有当前 Provider 状态 | switch、mutation；匹配 source-bound lease 的 `bootstrap_and_switch_profile()` / `adopt_and_switch_profile()`；活动 Profile save/flush |
| `transacting` | 已接纳事务正在推进 | 拒绝并发 domain 操作与直接原语 |
| `reconciliation_required` | 写入结果未知并持有 fence | 仅匹配 lease 的 reconcile 与诊断查询 |
| `disposed` | 强制释放终态 | 无 |

Quiesce 是 Coordinator 的全局准入阶段，不伪装成额外 domain 状态；诊断快照通过
`quiescing` 字段独立报告它。

## 失败矩阵

| 阶段/故障 | 默认结果 | 可恢复行为 | 必须保留的证据 |
| --- | --- | --- | --- |
| Profile、provider 或规范路径无效 | `invalid_profile` | 无 | 注册报告、profile/schema id、规范路径 |
| Request 未初始化、结构无效或已被 claim | `invalid_request` | 创建新的 Request；已 claim 句柄不可复用 | 操作类型、profile id |
| 当前 Profile 禁止该操作 | `unsupported_operation` | 修改声明后重新注册 | 操作类型、profile id |
| load/apply/provider 或状态回调期间请求保存或重入 | `busy` | 回调结束后由上层重新请求 | 操作类型、稳定状态快照 |
| Snapshot 创建、分片推进或 Storage 执行器载荷预检失败 | `preparation_failed` | 后续新 generation 可重试 | section id、错误码、校验报告 |
| 应用前回滚快照采集失败 | `snapshot_failed` | 修复 provider 后重试 | section id、错误码 |
| 异步 IO 启动失败 | `storage_failed` | 仅临时错误按有界计划重试 | 尝试次数、错误码 |
| 写入临时失败 | `storage_failed` | 按策略延迟重试 | generation、尝试次数 |
| 写入永久失败 | `storage_failed` | 无自动恢复 | generation、错误码 |
| 读取 IO 超时 | `storage_failed` | 可由上层重新读取 | request ID、尝试次数、超时 |
| 写入超时或写入中释放 | `outcome_unknown` | 先重读/对账，再决定重试 | request ID、generation、超时/释放原因 |
| 非 managed 普通读取文件不存在 | `missing` | 显式 `use_current_state` | 原始 `GFStorageReadResult` |
| 非 managed 普通读取文档损坏 | `corrupt` | 显式 `use_current_state`，不立即覆盖原文件 | 原始读取结果、恢复动作 |
| Managed activate 文件不存在 | `recovery_required` | 只签发 Bootstrap Recovery Lease | profile/domain/generation、读取结果 |
| Managed activate 文档损坏 | `recovery_required` | 只签发 Adopt Recovery Lease | profile/domain/generation、读取结果 |
| Switch 目标文件缺失或可恢复损坏 | `recovery_required` | 只签发绑定来源的 Bootstrap/Adopt Recovery Lease；保留源身份 | 来源/目标、domain generation、目标读取结果 |
| Switch 目标 Storage 结构损坏但无法授权 reset | `target_load_failed` | 失败关闭，不允许普通覆盖 | 目标读取结果、授权失败原因 |
| Managed Profile 直接 load 或非活动 save/flush | `busy` | 改用 Coordinator，或等待活动稳定 | profile/domain/活动身份 |
| Switch 的源 flush 失败 | `source_flush_failed` | 保留源活动身份 | 源 generation 与底层终态 |
| Switch 目标已知失败 | `target_load_failed` / 应用失败 | 逆序恢复并保留源身份 | 目标读取结果、回滚错误 |
| Switch 恢复 reset 或目标保存已知失败 | `persist_failed` | 保留源身份；reset 成功证据不得伪装成回滚 | reset 类型化证据、目标保存终态 |
| Mutation 已知持久化失败 | `persist_failed` | 逆序恢复；不发补偿写 | generation、底层确定失败 |
| 事务写入结果未知 | `outcome_unknown` | 冻结 domain，签发 Reconcile Lease | domain generation、request IDs |
| Lease 无效、过期或重复消费 | `invalid_lease` | 重新取得当前状态证据 | lease kind、domain generation |
| generation 证据仍为 unknown | `reconcile_pending` | 保持 fence，等待底层证据 settled；不 claim Request | bounded reconcile snapshot |
| ready lease 的严格重读失败 | `reconcile_failed` | 保持 fence，由项目稍后重新对账 | 读取结果、失败 section、回滚错误 |
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
- `use_current_state` 只适用于非 managed 普通读取，表示保留内存中的当前/default 状态并
  返回显式 recovered 终态；读取本身不写盘，也不删除、替换或修补原文件。
- Coordinator 的 strict load 忽略 `use_current_state`：missing/corrupt 必须分别经过
  Bootstrap/Adopt Recovery Lease；switch continuation 重新 flush 来源，并在 Storage
  结构损坏时凭来源绑定授权先 reset family，写确认后才能发布或切换活动身份。
- 未来 schema、schema id 不匹配和迁移失败不属于损坏恢复。
- 重试延迟是有限的毫秒序列；序列耗尽后必须返回失败，禁止无限循环。
- 时间判断只使用注入的 `GFClock` 单调时间，测试使用 `GFManualClock`。
- 每次 IO 都有正数超时；读取超时为确定失败，写入超时为结果未知。
- 写入重试复用同一个冻结 transfer；每个 attempt 单独 claim lease，终态后释放，逻辑
  保存不再需要任何 attempt 时由 Profile 最终 `release()`。
- `strict_integrity` 关闭只改变底层读取许可，不允许 Profile 把已知完整性失败当作有效文档。
- 未知 section 默认拒绝；`preserve` 会缓存并在下一次保存原样合并，`drop` 才会丢弃。

## 验证策略

故障注入测试至少覆盖：

- 在途写入期间多次保存只产生一次后续最新 generation 写入；
- 大型 document metadata、context 与 result metadata 的 Request 在 `save_profile()`
  返回前不深复制且不调用 Provider；claim 保留根与嵌套 alias 身份并且只能成功一次；
- 无效 Profile、关闭能力和 busy 拒绝不 claim Request；未初始化或重复提交的 Request
  返回 `invalid_request`，不分配新的 generation；
- 全局 work budget、单 profile slice budget 和软时间 budget 都能限制一次 tick 启动
  的准备工作，轮转不会让单个 profile 独占预算；
- Provider 的 Snapshot Operation 能跨 tick 完成，错误和取消都只进入一次终态；
- Snapshot 与 transfer 的源 alias 在移交后不再使用；首次 claim 后 Storage、规范文件名
  和 codec options 冻结，detached attempt 与重试 lease 都能安全复用同一载荷；
- Storage 执行器对循环、超限或不可持久化 Variant 图在本次新写入的编码与 temp、marker、final
  事务提交前失败关闭；既有 recovery 与目录初始化不伪装成该保证的一部分；
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
- Save 结果的 `get_document()` 返回 `null`，load 结果仍返回文档；准备耗时、准备 work
  units 与 Storage attempt 累计耗时分别可观察；
- 真实 `GFStorageUtility` 往返测试覆盖 threaded 与 cooperative 异步句柄集成，包括无线程
  activation，不只依赖测试替身；Save Profile 不为执行模式增加第二套公开 API。
- 精确相同的有序 Provider 身份共享 domain，重排和部分重叠注册失败关闭；不相交 domain
  可独立推进；
- activate/switch 只在严格成功后发布活动身份；missing/corrupt 分别只能由匹配的
  bootstrap/adopt continuation 继续，switch Lease 绑定来源且在目标保存确认前保留源身份；
- source-bound switch recovery 覆盖调用时最新来源 flush、结构损坏 reset、目标保存、
  已知失败与 source/target outcome-unknown fence，活动身份只在最终确认后发布一次；
- 活动 managed Profile 只开放稳定期 save/flush，直接 load、非活动写入和事务期重入均被拒绝；
- switch 源 flush、目标读取、应用和逆序恢复的每个故障点都保持可证明身份；
- typed mutation 的无效请求不被消费，已知持久化失败逆序恢复且不产生补偿写；
- outcome-unknown 冻结整个 domain；waiting reconcile 不 claim Request，底层证据 settled
  后仍需匹配 lease 严格重读指定 Profile并完整应用，才可解锁并重建活动身份；
- quiesce 等待已接纳事务和路径所有权，forced dispose 保留未知终态证据。

## 后果

项目获得统一、可测试的异步存档入口，业务模块只实现自己的 section provider。
代价是调用方和 provider 都必须遵循显式所有权协议：Request 成功创建后放弃三个输入
图的全部 alias，provider 定义稳定 section id、版本、可回滚应用语义和协作式 Snapshot
协议；旧 `_gather_section()` 契约及其隐式回退不再存在。Provider 必须把每个 work unit
保持在明确上界，并在逻辑 move 后主动放弃全部源 alias。注册后身份与能力被冻结。无法
回滚的外部副作用必须留在更高层事务参与者中，不能伪装成普通 section 应用。写入结果
未知时，上层还必须采用重读、版本戳或业务对账策略，而不能盲目重复提交。

Coordinator 进一步把活动身份和跨 Profile 流程变成框架级可测试契约。代价是 managed
Profile 必须通过精确 Provider 拓扑共享 domain，并遵循一次性 Recovery/Reconcile Lease
与 Mutation Request；项目仍需拥有账号到 Profile 的映射、恢复确认、损坏备份、云端冲突、
业务 schema 和对账重试时机，框架不会替这些政策选择默认答案。
