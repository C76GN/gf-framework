# 任务与进度

`GFQuestDefinition` 声明冻结定义，`GFQuestUtility` 维护任务生命周期，`GFQuestState` 导出独立的可持久化状态。指标来源、完成策略和奖励政策由项目明确声明；Domain 不依赖 Save。

进度通知按顺序发布；同任务在回调中重入更新时，待发通知合并为最新值。每次最多发布256条，剩余通知由 tick 续发；tick 不轮询指标查询。恢复和释放会撤销旧状态的待发通知。

## 指标与完成策略

| 指标模式 | 数据来源 | 接取与更新 |
|---|---|---|
| `history` | 项目已有的历史事实查询或显式整数输入 | 接取时查询，之后由项目在事实变更时调用 `refresh_metric()` 或 `set_metric_value()`。 |
| `since_acceptance` | 接取后的整数增量事件 | 接取前事件不计入；历史指标缓存不参与累计。 |
| `current` | 会升降的当前值查询或显式整数输入 | 达标后仍可能失去资格；默认显式确认完成。 |

完成策略独立于指标模式：

- `automatic`：达标并通过完成阻塞器后进入 completed。history 和 since_acceptance 默认采用此策略；current 也可显式选择首次达标完成。
- `manual`：达标后保持 active，项目调用 `complete_quest()` 才尝试完成。查询型指标在确认时重新读取来源。
- `external`：项目显式判定完成，只检查生命周期与完成阻塞器，不要求计数达标，指标 ID 可为空。适合对话、剧情或多条件脚本任务。

`is_quest_eligible()` 只读取已发布的指标资格，不执行查询或阻塞器。external 返回 true 仅表示可以尝试项目确认。完成是已经提交的事实：之后当前值下降不撤销 completed。完成事件不表示奖励已发放或状态已持久化。

## 定义和接取

```gdscript
var quest: GFQuestUtility = GFQuestUtility.new()
var definition: GFQuestDefinition = GFQuestDefinition.create(
	&"collect_material", &"material_collected",
	{"version": 1, "target": 10, "completion": "manual"}
)
var registered: bool = quest.define_quest(definition)
var accepted: bool = quest.accept_quest(&"collect_material", {"period": "season:4"})
quest.emit_quest_event(&"material_collected", 3)
var progress: float = quest.get_quest_progress(&"collect_material")
```

注册到 Architecture 后也可用 `Gf.send_simple_event()` 输入累计进度。事件只接受 int 或单层 `{ "amount": int }`；浮点数、嵌套字典、缺少 amount 和其他载荷不产生进度，不再默认加一。`emit_quest_event()` 要求明确提供 amount。负增量默认忽略，需要时在定义中设置 `allow_negative: true`。累计加法在 int64 边界饱和，累计值最高保留到目标；公开进度比例始终在 0..1。

定义 ID 和计数指标 ID 必须非空、无首尾空白且不超过256字符。目标是非负整数；零目标的累计自动任务接取后立即完成，查询任务仍需要可用样本。定义和接取信息只接受有界原生纯数据，不持有对象或回调。

`define_quest()` 可为同一 ID 发布更高版本：available 任务采用新定义，已接取任务保持接取时的模式、目标、元数据和版本。相同版本仅允许相同内容重复注册；版本回退或同版本不同内容均拒绝。每个 Utility 最多4096个任务。`start_quest()` 已删除，统一使用定义与接取两个入口。

## 项目指标来源

```gdscript
var definition: GFQuestDefinition = GFQuestDefinition.create(
	&"hold_material", &"material_balance", {"mode": "current", "target": 100}
)
var registered: bool = quest.define_quest(definition)
var bound: bool = quest.register_metric_query(&"material_balance", func() -> int:
	return inventory.get_material_count()
)
var accepted: bool = quest.accept_quest(&"hold_material")
# 项目确认库存变化后刷新，框架不每帧扫描全部任务。
var refreshed: bool = quest.refresh_metric(&"material_balance")
```

查询同步在主线程执行，必须无参数并返回精确整数；无效 Callable、非整数结果和未授权的负数使指标不可用。查询及其结果通知期间拒绝同指标递归刷新。回调若恢复快照或替换来源，旧结果不能覆盖新状态。

也可不注册查询，改用 `set_metric_value(metric_id, value)`；每次输入只更新受此指标影响的活动任务。查询与显式输入不能混用，先 `clear_metric_source()` 再换来源。两个切换方向都会拒绝未清理的混用，拒绝时不改变原值或任务资格。每类来源最多4096项。不可用指标保留最后值用于报告，但它不能授权完成。

## 生命周期与任务树

`quest_started` 是提交后信号：累计任务已经建立事件监听，回调内发送增量不会丢失。条件、信号和阻塞器可能重入；取消、失败、恢复或替换状态后，旧调用不会覆盖新状态。

`add_acceptance_condition()` 和 `add_completion_blocker()` 注册 `(quest_id, report)` 同步回调，返回 bool 或 `{ "ok": bool, "reason": String }`。非法或已失效的回调结果拒绝转换。阻塞器检查后仍核对指标资格；它不能使已失去资格的计数任务完成。回调只在运行时持有，快照不序列化代码。

`cancel_quest()` 和 `fail_quest()` 可终止 available 或 active 任务；完成、失败、取消后停止监听。失败原因独立保存，并在报告 metadata 的 `last_failure_reason` 中提供，最多4096字符。

`set_quest_parent()`、`clear_quest_parent()`、`get_child_quests()` 和 `get_quest_tree_report()` 保留父子组织能力。关系必须无环；报告按稳定 ID 排序，深链采用迭代处理。父子关系不自动接取、完成、传播失败、发奖或解锁章节。

## 快照与恢复

`get_quest_state()` 返回单任务冻结状态。`export_snapshot()` 返回封闭 `{format_version: 1, states: [...]}`，保存定义、是否已接取、项目接取信息、计数、生命周期、父级身份和失败原因。修改副本不会改变运行任务。

整包预算为4096任务、深度24、200000节点和16MiB；超出时导出返回空字典，项目必须按失败处理，不能覆盖已有存档。单任务状态预算深度20、8192节点、256KiB；定义元数据和接取信息各限深度16、2048节点、64KiB，恢复同样检查各自预算。

`restore_snapshot()` 先验证整个候选，再替换状态和监听。未知任务、重复 ID、非法生命周期、缺失父级、环或超预算均拒绝，失败保持原状态。项目先注册当前定义目录和条件回调，再恢复快照。已接取任务恢复冻结定义；未接取任务使用当前目录定义；目录新增且快照没有的任务从 available 开始。已有运行时条件绑定按任务 ID 保留。

恢复不触发查询、接取条件、进度或完成事件，也不重放奖励。累计值直接恢复并重新订阅增量；查询型 active 任务的缓存标记为不可用，显式输入缓存清空，项目恢复完其他 Model 后再刷新。已完成任务保持完成。切换 Profile 前应停止项目进度输入和副作用观察者，完成所有 Model 替换后再恢复输入。

## Save、周期与成就组合

项目 `GFSaveSectionProvider` 可以在 capture 中导出 Quest 快照，在 apply 中调用 `restore_snapshot()`。恢复失败应作为 Provider apply 失败交给 Profile 事务回滚，不能静默跳过。Save 的未知内容保留政策在项目 Provider 中显式声明；保留的未识别任务不直接进入 Quest 运行状态。见 [Save Profile 运行时](../save-graph/save-profile-runtime.md) 和 [字段保留政策](../save-graph/save-payload-retention.md)。

周期任务的接取信息可保存项目选择的周期身份、配置版本和时间样本。新周期采用新的实例身份或项目明确替换的运行状态；GF 不用系统时间自动清空任务，也不执行补签、离线奖励或重复发奖检查。

奖励应通过项目事务把“任务已完成、业务操作 ID 已处理、余额或道具变化”一起提交。只有 Profile 确认成功才能证明本地持久化；取消等待、失败和未知写入结果必须遵守其事务恢复契约。完成通知、平台回调或 UI 表现均不能替代这一确认，见 [Save Profile 会话与事务](../save-graph/save-profile-transactions.md)。

成就复用此生命周期与快照，不另建 Achievement Runtime。稳定成就 ID、删除或改名迁移、奖励和展示归项目所有。平台适配器翻译稳定 ID 与类型化结果；离线请求可进入专用 Outbox，使用稳定幂等键并接受 at-least-once 重放。平台确认和本地存档成功分别记录，见 [Platform Runtime](../../standard/foundation/platform-runtime.md) 和 [通用请求 Outbox](../../standard/utilities/io/config-remote-outbox/request-outbox.md)。

## 解释定义与读档拒绝

`GFQuestDefinition.validate_create(quest_id, metric_id, options)` 只读检查定义；`quest.validate_restore_snapshot(snapshot)` 只读检查当前任务目录能否接受快照。原有 `create()` 仍返回对象或 null，`restore_snapshot()` 仍返回 bool。诊断与实际操作使用同一验证路径，失败不改变已有任务或监听。

报告含 `ok`、`error_kind`、`path`；成功时后两项为空。路径从参数名开始，例如 `/options/target`、`/snapshot/states/0/definition/quest_id`。字典键中的 `~` 和 `/` 分别写成 `~0` 和 `~1`。报告是独立纯数据，不保存错误到服务的全局状态。

定义错误包括 `invalid_id`、`length_limit`、`invalid_key_type`、`unknown_field`、`invalid_type`、`invalid_value`、`required`。恢复额外区分 `service_disposed`、`unsupported_version`、`state_limit`、`invalid_state`、`unknown_quest`、`duplicate_id`、`missing_parent` 和 `cycle`。`invalid_state` 表示整条状态的结构或生命周期契约不合法，路径定位该状态记录。输入有多个错误时只报告当前验证顺序发现的第一项，不保证跨版本保持同一优先级。

数量或长度超限包含 `limit` 和 `observed`。纯数据错误提供 `measurement` 和 `limits`；可归因的预算错误为 `budget_exceeded`，并提供 `limit_kind`。`observed_is_lower_bound` 为 true 时，`observed` 仅为确定下界；失败计量中的计数只覆盖已遍历前缀。项目不应解析可读错误文本来决定流程。

```gdscript
var report: Dictionary = quest.validate_restore_snapshot(snapshot)
if not report["ok"]:
	show_restore_problem(report["error_kind"], report["path"])
	return
# 实际恢复仍重新检查；报告不锁定目录，也不授权之后修改的快照。
if not quest.restore_snapshot(snapshot):
	show_restore_problem("restore_rejected", "")
```

诊断不会运行查询、接取条件、完成阻止条件或任务信号，也不清空显式指标来源。成功诊断仍会构造并检查临时候选记录，因此是与正式校验同阶的工作，不适合逐帧重复执行。
