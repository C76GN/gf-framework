# Save Profile 会话与事务

`GFSaveProfileTransactionCoordinator` 在 `GFSaveProfileUtility` 的单 Profile 保存、读取、
flush 原语之上，提供跨 Profile 的活动身份、切换、恢复、类型化修改和未知结果对账。
项目需要管理槽位、账号或角色存档时使用 Coordinator；只读写一个没有活动身份语义的
独立文档时，继续直接使用 Utility 原语。

## 两层职责

- `GFSaveProfileUtility` 负责 generation、Snapshot 准备预算、单 Profile IO 调度、迁移、
  校验和 section 应用回滚。它不决定哪个 Profile 当前代表运行时状态。
- `GFSaveProfileTransactionCoordinator` 负责 provider domain、活动 Profile 身份和跨原语
  事务。它复用 Utility，不引入第二套存档格式、迁移引擎或 Storage 提交协议。

Coordinator 的异步入口统一返回 `GFSaveProfileTransactionOperation`，终态由不可变的
`GFSaveProfileTransactionResult` 表达。项目不应通过字符串错误、底层文件名或普通
`GFSaveProfileResult` 猜测跨 Profile 事务是否提交。

## Provider domain 与活动身份

Coordinator 按 provider 的“完全相同对象身份、完全相同顺序”编译 domain。只有两个
Profile 的 provider 数量、每一位置的实例身份和顺序都一致，它们才共享一个 domain；
只重排同一组 provider 也不是同一拓扑。注册时若两个拓扑只部分重叠，Coordinator 会
失败关闭，避免同一权威状态被两个独立锁域并发修改。

每个 domain 最多有一个活动 Profile 身份，但互不相交的 domain 可以独立推进。活动身份
不是 UI 当前选中项，而是“当前 provider 状态由哪个已确认持久化身份拥有”的框架事实。
通过 `get_active_profile_id()` 查询它，通过 `get_domain_state_snapshot()` 取得有界诊断；
不要在项目中维护第二份可写 active 标志。

Profile 应通过 Coordinator 的 `register_profile()` / `unregister_profile()` 进入和退出该
边界。注册后，managed gate 只允许稳定活动 Profile 直接 `save_profile()` /
`flush_profile()`，供普通游戏状态与自动保存继续使用；直接 `load_profile()`、非活动
Profile 的 save/flush，以及事务或 reconcile fence 期间的全部直接原语都会被拒绝。
活动身份变更和原子 section 修改必须经 Coordinator，否则无法维持 domain 串行化。
同一 domain 已有活动身份时，仍可注销空闲的非活动成员；活动成员、进行中的事务或
reconcile fence 仍拒绝注销，成功注销会使该 domain 的 recovery lease 失效。

## 严格激活与切换

`activate_profile()` 只在 domain 尚无活动身份时加载一份已经存在且有效的 Profile。
读取、迁移、校验和所有 provider 应用全部成功后，活动身份才原子发布。它不会把当前
默认状态自动解释成已存在存档。

`switch_profile()` 要求目标与当前活动 Profile 属于同一精确拓扑，并按固定顺序执行：

1. 捕获调用时源 Profile 的 generation 屏障，并确认源状态已 flush。
2. 在触碰目标前采集全部 provider 的稳定回滚快照。
3. 严格读取、迁移、校验并事务化应用目标 Profile。
4. 全部成功后才把活动身份从源 Profile 原子切换到目标 Profile。

源 flush 已知失败时不会读取目标。目标读取或应用发生已知失败时，Coordinator 按逆序
恢复已尝试的 provider，并保留源活动身份；任一恢复失败都返回显式 rollback failure，
不能把部分恢复状态标成仍然安全的源状态。切换不会把任意两个不同 provider 拓扑转换成
同一业务状态，项目需要的字段映射必须留在自己的迁移或导入流程中。

## 缺失与损坏的显式边界

严格 activate 遇到缺失文件时返回 `recovery_required` 与一次性的
`GFSaveProfileRecoveryLease`；遇到已知损坏文件时也返回 recovery lease，但两种原因
不能互换。Switch 的目标缺失或可恢复损坏也会返回绑定当前活动来源的 Lease，并在整个
恢复流程中保留源活动身份：

- `bootstrap_profile()` 只消费由 `missing` 产生且仍属于当前 domain generation 的 lease。
- `adopt_profile()` 只消费由 `corrupt` 产生且仍属于当前 domain generation 的 lease。
- `bootstrap_and_switch_profile()` 消费 source-bound `missing` lease，重新 flush 调用时来源
  generation，再保存目标并在确认成功后切换身份。
- `adopt_and_switch_profile()` 消费 source-bound `corrupt` lease；Storage family 结构损坏
  必须先使用同一 Utility、同一目标读取签发的 opaque 授权完成 family reset，无法授权时
  失败关闭。Save 文档或完整性损坏不需要破坏性 reset。

四个入口都把当前内存状态作为候选，只有 Storage 写入获得确定成功后才激活或切换目标。
无效、过期、重复消费或原因不匹配的 lease 会失败关闭。框架不会因为 Profile 的普通
读取恢复政策而替项目自动创建、覆盖或接管一个活动身份；是否向用户展示“新建”或
“接管损坏存档”，以及是否先备份损坏文件，均由项目决定。

## 类型化修改并持久化

`GFSaveSectionMutation` 表达一个 section 的候选替换，`GFSaveProfileMutationRequest`
以一次性所有权句柄提交有界、类型化的 mutation 清单。`mutate_and_persist()` 只修改当前
活动 Profile，不接受任意回调，也不允许项目绕过 provider 的 section 身份、schema 与
应用契约。

Coordinator 固定本次 provider 顺序，先采集回滚快照，再按请求应用候选 section，最后
通过 Utility 保存并等待对应 generation 的确定终态。已知应用或 Storage 失败时，已尝试
provider 按逆序恢复；Storage 的已知失败已经证明本次写入没有提交，因此不会再发起一笔
“补偿保存”。这种额外写入既不能增加正确性，还会扩大新的未知提交窗口。

Mutation Request 是 move-only 边界。成功提交后，调用方必须放弃请求及其候选 payload
的全部嵌套 alias；无效或 busy 的前置拒绝不消费请求。项目仍负责业务字段含义、跨 section
约束和候选生成，框架只保证类型、顺序、所有权与事务终态。

## 结果未知与对账

写入超时、释放中仍有物理写入等无法证明是否提交的情况返回 `outcome_unknown`，并交付
一次性的 `GFSaveProfileReconcileLease`。Coordinator 此时冻结整个 provider domain：
不发布新的活动身份，不执行反向回滚、自动重试或补偿写，也拒绝新的 activate、switch、
bootstrap、adopt、bootstrap/adopt-and-switch、mutation 和直接原语。否则磁盘可能已经
保存候选状态，而内存又被静默改回旧状态。

`GFSaveProfileReconcileLease` 初始为 waiting。此时调用 `reconcile_profile()` 只返回
`reconcile_pending`，不会 claim `GFSaveProfileReconcileRequest`。底层 Utility 的
generation 证据从 unknown 进入 persisted 或 failed 后，lease 才变为 ready；迟到证据
本身仍不会自动提交、回滚或解除 fence。

项目随后用同一 lease 和 Request 再次调用 reconcile。Coordinator 此时才 claim Request，
严格重读 lease 记录的 reconcile Profile；读取和全部 provider 应用成功后，才解除 fence
并从该 Profile 重建活动身份。Request 只携带本次严格读取的 context 与 result metadata，
不接受“已提交/未提交”布尔结论、可执行 patch 或恢复回调。Switch 的源 flush 结果未知时，
reconcile Profile 固定为源 Profile，原目标不会在迟到成功后自动继续；项目需要重新发起
一次新的 switch。对账成功前 lease 保持 domain 所有权，错误 domain、过期或重复消费均
返回显式失败。

## Architecture 生命周期

需要在首个运行场景开放前恢复存档的项目 System，应声明
`GFSaveProfileTransactionCoordinator` 为必需 Utility，并在 `begin_activation(scope)`
中把 activate/switch/bootstrap/adopt 及 bootstrap/adopt-and-switch Operation 的唯一终态桥接到
`GFAsyncCompletion`。不要手动轮询 `architecture.tick()`；依赖 DAG 会继续推进
Coordinator、Save Profile 与 Storage 的本地依赖闭包。

Quiesce 先关闭 Coordinator 的新事务准入，再等待已接纳事务、底层 Profile 原语和仍持有
路径所有权的迟到写入收敛。关闭期间只保留一个窄例外：已经持有的 ready Reconcile Lease
可作为 closure continuation 发起严格重读，从而解除既有 fence；它不能创建新业务事务，
waiting lease 也仍须先等待物理尾部收敛。同步 `dispose()` 只用于无法等待的最终释放：未开始事务进入
`disposed`，无法证明的写入保持 `outcome_unknown` 与诊断证据，不能伪装成已回滚。
Dispose 会立即撤销 manager capability；已经完成 Storage 读取但尚未应用的 strict load 会
在触碰 Provider 前终止，正在 Provider apply 回调中的读取会在回调返回后复核 capability
并逆序恢复，避免迟到读取在 Coordinator 终态之后改写权威内存。
项目可控退出、账号登出或运行域替换应等待 Architecture 的类型化异步关闭。

## 项目责任边界

框架不内置槽位数量、账号到路径映射、自动覆盖政策、损坏文件备份、云端冲突合并、
存档选择 UI、业务字段 schema 或跨 section 业务校验。项目负责构造 Profile 与 provider、
选择目标身份、生成 mutation、决定何时重试 reconcile，并决定何时把失败展示给用户。
Coordinator 只提供可复用的活动身份和事务安全边界，不把任何一种游戏流程固化为默认策略。

完整 primitive 状态机与失败矩阵见
[Save Profile 运行时编排决策](save-profile-adr.md)，单 Profile 保存与读取用法见
[Save Profile 运行时](save-profile-runtime.md)。
