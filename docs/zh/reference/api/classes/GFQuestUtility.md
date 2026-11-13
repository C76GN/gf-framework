# GFQuestUtility

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/quest/gf_quest_utility.gd`
- 模块：`Domain`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

冻结定义驱动的任务进度与生命周期。 历史和当前指标由项目查询或显式输入提供，累计指标只接受接取后的整数增量。 完成策略与指标模式分离；快照恢复不查询指标、不重放任务事件，也不发放奖励。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`quest_started`](#member-gfquestutility-signals-quest_started) | `signal quest_started(quest_id: StringName)` |
| 信号 | [`quest_available`](#member-gfquestutility-signals-quest_available) | `signal quest_available(quest_id: StringName)` |
| 信号 | [`quest_acceptance_blocked`](#member-gfquestutility-signals-quest_acceptance_blocked) | `signal quest_acceptance_blocked(quest_id: StringName, reason: String)` |
| 信号 | [`quest_progressed`](#member-gfquestutility-signals-quest_progressed) | `signal quest_progressed( quest_id: StringName, current: int, target: int )` |
| 信号 | [`quest_completed`](#member-gfquestutility-signals-quest_completed) | `signal quest_completed(quest_id: StringName)` |
| 信号 | [`quest_completion_blocked`](#member-gfquestutility-signals-quest_completion_blocked) | `signal quest_completion_blocked(quest_id: StringName, reason: String)` |
| 信号 | [`quest_cancelled`](#member-gfquestutility-signals-quest_cancelled) | `signal quest_cancelled(quest_id: StringName)` |
| 信号 | [`quest_failed`](#member-gfquestutility-signals-quest_failed) | `signal quest_failed(quest_id: StringName)` |
| 常量 | [`STATUS_AVAILABLE`](#member-gfquestutility-constants-status_available) | `const STATUS_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATUS_ACTIVE`](#member-gfquestutility-constants-status_active) | `const STATUS_ACTIVE: StringName = &"active"` |
| 常量 | [`STATUS_COMPLETED`](#member-gfquestutility-constants-status_completed) | `const STATUS_COMPLETED: StringName = &"completed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfquestutility-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_FAILED`](#member-gfquestutility-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 方法 | [`tick`](#member-gfquestutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`define_quest`](#member-gfquestutility-methods-define_quest) | `func define_quest(definition: GFQuestDefinition) -> bool:` |
| 方法 | [`accept_quest`](#member-gfquestutility-methods-accept_quest) | `func accept_quest(quest_id: StringName, acceptance_data: Dictionary = {}) -> bool:` |
| 方法 | [`complete_quest`](#member-gfquestutility-methods-complete_quest) | `func complete_quest(quest_id: StringName) -> bool:` |
| 方法 | [`cancel_quest`](#member-gfquestutility-methods-cancel_quest) | `func cancel_quest(quest_id: StringName) -> bool:` |
| 方法 | [`fail_quest`](#member-gfquestutility-methods-fail_quest) | `func fail_quest(quest_id: StringName, reason: String = "") -> bool:` |
| 方法 | [`add_acceptance_condition`](#member-gfquestutility-methods-add_acceptance_condition) | `func add_acceptance_condition(quest_id: StringName, condition: Callable) -> void:` |
| 方法 | [`clear_acceptance_conditions`](#member-gfquestutility-methods-clear_acceptance_conditions) | `func clear_acceptance_conditions(quest_id: StringName) -> void:` |
| 方法 | [`add_completion_blocker`](#member-gfquestutility-methods-add_completion_blocker) | `func add_completion_blocker(quest_id: StringName, blocker: Callable) -> void:` |
| 方法 | [`clear_completion_blockers`](#member-gfquestutility-methods-clear_completion_blockers) | `func clear_completion_blockers(quest_id: StringName) -> void:` |
| 方法 | [`set_quest_parent`](#member-gfquestutility-methods-set_quest_parent) | `func set_quest_parent(quest_id: StringName, parent_quest_id: StringName) -> bool:` |
| 方法 | [`clear_quest_parent`](#member-gfquestutility-methods-clear_quest_parent) | `func clear_quest_parent(quest_id: StringName) -> void:` |
| 方法 | [`get_child_quests`](#member-gfquestutility-methods-get_child_quests) | `func get_child_quests(quest_id: StringName) -> PackedStringArray:` |
| 方法 | [`get_quest_tree_report`](#member-gfquestutility-methods-get_quest_tree_report) | `func get_quest_tree_report(root_quest_id: StringName) -> Dictionary:` |
| 方法 | [`emit_quest_event`](#member-gfquestutility-methods-emit_quest_event) | `func emit_quest_event(event_id: StringName, amount: int) -> void:` |
| 方法 | [`is_quest_completed`](#member-gfquestutility-methods-is_quest_completed) | `func is_quest_completed(quest_id: StringName) -> bool:` |
| 方法 | [`get_quest_progress`](#member-gfquestutility-methods-get_quest_progress) | `func get_quest_progress(quest_id: StringName) -> float:` |
| 方法 | [`get_quest_status`](#member-gfquestutility-methods-get_quest_status) | `func get_quest_status(quest_id: StringName) -> StringName:` |
| 方法 | [`get_quests_by_status`](#member-gfquestutility-methods-get_quests_by_status) | `func get_quests_by_status(status: StringName) -> PackedStringArray:` |
| 方法 | [`get_quest_report`](#member-gfquestutility-methods-get_quest_report) | `func get_quest_report(quest_id: StringName) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfquestutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`register_metric_query`](#member-gfquestutility-methods-register_metric_query) | `func register_metric_query(metric_id: StringName, query: Callable) -> bool:` |
| 方法 | [`clear_metric_source`](#member-gfquestutility-methods-clear_metric_source) | `func clear_metric_source(metric_id: StringName) -> void:` |
| 方法 | [`set_metric_value`](#member-gfquestutility-methods-set_metric_value) | `func set_metric_value(metric_id: StringName, value: int) -> bool:` |
| 方法 | [`refresh_metric`](#member-gfquestutility-methods-refresh_metric) | `func refresh_metric(metric_id: StringName) -> bool:` |
| 方法 | [`is_quest_eligible`](#member-gfquestutility-methods-is_quest_eligible) | `func is_quest_eligible(quest_id: StringName) -> bool:` |
| 方法 | [`get_quest_state`](#member-gfquestutility-methods-get_quest_state) | `func get_quest_state(quest_id: StringName) -> GFQuestState:` |
| 方法 | [`export_snapshot`](#member-gfquestutility-methods-export_snapshot) | `func export_snapshot() -> Dictionary:` |
| 方法 | [`restore_snapshot`](#member-gfquestutility-methods-restore_snapshot) | `func restore_snapshot(snapshot: Dictionary) -> bool:` |
| 方法 | [`validate_restore_snapshot`](#member-gfquestutility-methods-validate_restore_snapshot) | `func validate_restore_snapshot(snapshot: Dictionary) -> Dictionary:` |

## 信号

<a id="member-gfquestutility-signals-quest_started"></a>

### `quest_started`

- API：`public`

```gdscript
signal quest_started(quest_id: StringName)
```

当任务开始监听时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-signals-quest_available"></a>

### `quest_available`

- API：`public`

```gdscript
signal quest_available(quest_id: StringName)
```

当任务进入可接取状态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-signals-quest_acceptance_blocked"></a>

### `quest_acceptance_blocked`

- API：`public`

```gdscript
signal quest_acceptance_blocked(quest_id: StringName, reason: String)
```

当任务接取条件拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `reason` | 拒绝原因。 |

<a id="member-gfquestutility-signals-quest_progressed"></a>

### `quest_progressed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal quest_progressed( quest_id: StringName, current: int, target: int )
```

当任务进度变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `current` | 当前进度。 |
| `target` | 目标进度。 |

<a id="member-gfquestutility-signals-quest_completed"></a>

### `quest_completed`

- API：`public`

```gdscript
signal quest_completed(quest_id: StringName)
```

当任务完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 完成的任务 ID。 |

<a id="member-gfquestutility-signals-quest_completion_blocked"></a>

### `quest_completion_blocked`

- API：`public`

```gdscript
signal quest_completion_blocked(quest_id: StringName, reason: String)
```

当任务完成条件被阻塞器拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `reason` | 阻塞原因。 |

<a id="member-gfquestutility-signals-quest_cancelled"></a>

### `quest_cancelled`

- API：`public`

```gdscript
signal quest_cancelled(quest_id: StringName)
```

当任务取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-signals-quest_failed"></a>

### `quest_failed`

- API：`public`

```gdscript
signal quest_failed(quest_id: StringName)
```

当任务失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

## 常量

<a id="member-gfquestutility-constants-status_available"></a>

### `STATUS_AVAILABLE`

- API：`public`

```gdscript
const STATUS_AVAILABLE: StringName = &"available"
```

任务已定义、可接取但尚未开始监听。

<a id="member-gfquestutility-constants-status_active"></a>

### `STATUS_ACTIVE`

- API：`public`

```gdscript
const STATUS_ACTIVE: StringName = &"active"
```

任务正在监听事件并累计进度。

<a id="member-gfquestutility-constants-status_completed"></a>

### `STATUS_COMPLETED`

- API：`public`

```gdscript
const STATUS_COMPLETED: StringName = &"completed"
```

任务已完成。

<a id="member-gfquestutility-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

任务已取消。

<a id="member-gfquestutility-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

任务已失败。

## 方法

<a id="member-gfquestutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float) -> void:
```

只续发超过单次256条预算的进度通知，不轮询指标查询。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 不用于指标或任务计时。 |

<a id="member-gfquestutility-methods-define_quest"></a>

### `define_quest`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func define_quest(definition: GFQuestDefinition) -> bool:
```

注册新定义或发布更高版本；已接取和终态任务保留原定义。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 通过 GFQuestDefinition 工厂创建的定义。 |

返回：注册成功为 true；重复版本内容不同、版本回退、无效定义或超过4096任务时拒绝。

<a id="member-gfquestutility-methods-accept_quest"></a>

### `accept_quest`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func accept_quest(quest_id: StringName, acceptance_data: Dictionary = {}) -> bool:
```

接取任务，冻结当前定义与项目提供的接取信息。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 已注册的任务身份。 |
| `acceptance_data` | 项目记录的周期、业务请求身份或时间样本，不由框架推断。 |

返回：接取成功或原本已经 active 时为 true；终态、非法数据或条件拒绝时为 false。

结构：

- `acceptance_data`: 原生纯数据 Dictionary，深度16、2048节点、64KiB；不包含回调或对象。

<a id="member-gfquestutility-methods-complete_quest"></a>

### `complete_quest`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func complete_quest(quest_id: StringName) -> bool:
```

确认完成；查询型任务先取得新指标，external 策略只检查项目阻塞器。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 活动任务 ID。 |

返回：本次确认成功为 true；未达标、指标不可用、已终止或被阻塞时为 false。

<a id="member-gfquestutility-methods-cancel_quest"></a>

### `cancel_quest`

- API：`public`

```gdscript
func cancel_quest(quest_id: StringName) -> bool:
```

取消一个任务。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：取消成功返回 true。

<a id="member-gfquestutility-methods-fail_quest"></a>

### `fail_quest`

- API：`public`

```gdscript
func fail_quest(quest_id: StringName, reason: String = "") -> bool:
```

标记任务失败。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `reason` | 可选失败原因，会写入任务 metadata 的 last_failure_reason。 |

返回：标记成功返回 true。

<a id="member-gfquestutility-methods-add_acceptance_condition"></a>

### `add_acceptance_condition`

- API：`public`

```gdscript
func add_acceptance_condition(quest_id: StringName, condition: Callable) -> void:
```

添加接取条件。条件返回 false 或包含 ok=false 的 Dictionary 时阻止接取。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `condition` | 条件回调。 |

<a id="member-gfquestutility-methods-clear_acceptance_conditions"></a>

### `clear_acceptance_conditions`

- API：`public`

```gdscript
func clear_acceptance_conditions(quest_id: StringName) -> void:
```

清空任务接取条件。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-methods-add_completion_blocker"></a>

### `add_completion_blocker`

- API：`public`

```gdscript
func add_completion_blocker(quest_id: StringName, blocker: Callable) -> void:
```

添加完成阻塞器。阻塞器返回 false 或包含 ok=false 的 Dictionary 时阻止完成。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `blocker` | 阻塞器回调。 |

<a id="member-gfquestutility-methods-clear_completion_blockers"></a>

### `clear_completion_blockers`

- API：`public`

```gdscript
func clear_completion_blockers(quest_id: StringName) -> void:
```

清空任务完成阻塞器。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-methods-set_quest_parent"></a>

### `set_quest_parent`

- API：`public`

```gdscript
func set_quest_parent(quest_id: StringName, parent_quest_id: StringName) -> bool:
```

设置任务父级关系。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 子任务 ID。 |
| `parent_quest_id` | 父任务 ID。 |

返回：设置成功返回 true。

<a id="member-gfquestutility-methods-clear_quest_parent"></a>

### `clear_quest_parent`

- API：`public`

```gdscript
func clear_quest_parent(quest_id: StringName) -> void:
```

清除任务父级关系。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

<a id="member-gfquestutility-methods-get_child_quests"></a>

### `get_child_quests`

- API：`public`

```gdscript
func get_child_quests(quest_id: StringName) -> PackedStringArray:
```

获取任务的直接子任务 ID。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：子任务 ID 列表。

<a id="member-gfquestutility-methods-get_quest_tree_report"></a>

### `get_quest_tree_report`

- API：`public`

```gdscript
func get_quest_tree_report(root_quest_id: StringName) -> Dictionary:
```

获取任务树报告。

参数：

| 名称 | 说明 |
|---|---|
| `root_quest_id` | 根任务 ID。 |

返回：树形报告；任务不存在时返回空字典。

结构：

- `return`: Dictionary，包含任务报告字段、children: Array[Dictionary]、total_count、completed_count 与 aggregate_progress。

<a id="member-gfquestutility-methods-emit_quest_event"></a>

### `emit_quest_event`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func emit_quest_event(event_id: StringName, amount: int) -> void:
```

手动触发一次任务事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 事件 ID。 |
| `amount` | 本次增加的进度值。 |

<a id="member-gfquestutility-methods-is_quest_completed"></a>

### `is_quest_completed`

- API：`public`

```gdscript
func is_quest_completed(quest_id: StringName) -> bool:
```

查询任务是否已经完成。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：已完成时返回 true。

<a id="member-gfquestutility-methods-get_quest_progress"></a>

### `get_quest_progress`

- API：`public`

```gdscript
func get_quest_progress(quest_id: StringName) -> float:
```

获取任务进度百分比。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：范围在 0.0 到 1.0 之间的进度值。

<a id="member-gfquestutility-methods-get_quest_status"></a>

### `get_quest_status`

- API：`public`

```gdscript
func get_quest_status(quest_id: StringName) -> StringName:
```

获取任务状态。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：状态文本。

<a id="member-gfquestutility-methods-get_quests_by_status"></a>

### `get_quests_by_status`

- API：`public`

```gdscript
func get_quests_by_status(status: StringName) -> PackedStringArray:
```

获取指定状态的任务 ID。

参数：

| 名称 | 说明 |
|---|---|
| `status` | 任务状态。 |

返回：任务 ID 列表。

<a id="member-gfquestutility-methods-get_quest_report"></a>

### `get_quest_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_quest_report(quest_id: StringName) -> Dictionary:
```

获取任务报告。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：任务报告字典。

结构：

- `return`: Dictionary，包含 quest_id、event_id、target_count、current_count、is_completed、status、parent_id、child_ids、metadata、acceptance_condition_count、completion_blocker_count、definition_version、metric_mode、completion_policy、metric_available、eligible、accepted 与 acceptance_data。资格是缓存状态，不执行查询或阻塞器。

<a id="member-gfquestutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取任务系统调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 quest_count、event_count 与 quests；quests 键为 String 任务 ID，值为任务报告字典。

<a id="member-gfquestutility-methods-register_metric_query"></a>

### `register_metric_query`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_metric_query(metric_id: StringName, query: Callable) -> bool:
```

注册项目指标查询；不自动调用，查询必须无参数并返回 int。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 非空指标身份，最多256字符。 |
| `query` | 同步主线程查询；无效或非 int 返回值使该指标不可用。 |

返回：绑定成功；最多4096个查询。

<a id="member-gfquestutility-methods-clear_metric_source"></a>

### `clear_metric_source`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear_metric_source(metric_id: StringName) -> void:
```

移除查询和该指标的显式输入，已有活动任务的指标变为不可用。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标身份。 |

<a id="member-gfquestutility-methods-set_metric_value"></a>

### `set_metric_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_metric_value(metric_id: StringName, value: int) -> bool:
```

输入历史或当前指标值，并仅更新受此指标影响的活动任务。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 项目指标身份。 |
| `value` | 精确整数；每个定义自行决定是否接受负数。 |

返回：输入被接受时为 true。注册了查询时拒绝混用显式输入；最多4096个缓存指标。

<a id="member-gfquestutility-methods-refresh_metric"></a>

### `refresh_metric`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func refresh_metric(metric_id: StringName) -> bool:
```

显式刷新一个指标；不进行每帧全量轮询。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 要刷新的历史或当前指标。 |

返回：查询或显式缓存有效且未被重入替换时为 true；非法结果使指标不可用。

<a id="member-gfquestutility-methods-is_quest_eligible"></a>

### `is_quest_eligible`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_quest_eligible(quest_id: StringName) -> bool:
```

查询缓存指标是否满足完成门槛，不执行项目查询或完成阻塞器。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务身份。 |

返回：活动任务的指标可用且达标时为 true；external 表示允许项目尝试确认，并非业务事实已成立。

<a id="member-gfquestutility-methods-get_quest_state"></a>

### `get_quest_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_quest_state(quest_id: StringName) -> GFQuestState:
```

导出一个任务的冻结状态；报告和状态副本都不能修改运行任务。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务身份。 |

返回：独立状态；任务不存在时为 null。

<a id="member-gfquestutility-methods-export_snapshot"></a>

### `export_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func export_snapshot() -> Dictionary:
```

导出扁平任务快照，包含父级身份但不保存运行时回调。

返回：可持久化的有界副本；超过整包预算时返回空字典，调用方不得将空字典作为有效存档。

结构：

- `return`: 封闭 Dictionary，format_version:int=1、states:Array[Dictionary]（GFQuestState记录，按quest_id排序）。最多4096任务，整个包深度24、200000节点、16MiB。

<a id="member-gfquestutility-methods-restore_snapshot"></a>

### `restore_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func restore_snapshot(snapshot: Dictionary) -> bool:
```

原子恢复任务状态，不发出任务或奖励事件，不执行查询和条件回调。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | export_snapshot 产生的封闭快照。 |

返回：全部验证和替换成功时为 true；失败不改变任务、监听或输入缓存。查询型活动任务恢复为指标不可用，须显式刷新。

结构：

- `snapshot`: 与 export_snapshot.return 相同。未知任务、重复身份、无效状态、缺失父级和环均拒绝。已接取任务采用快照定义；未接取任务采用当前目录定义。目录中新增且快照未包含的任务从available开始。

<a id="member-gfquestutility-methods-validate_restore_snapshot"></a>

### `validate_restore_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_restore_snapshot(snapshot: Dictionary) -> Dictionary:
```

只读检查当前目录能否恢复快照，不替换任务、监听或指标缓存。 与 restore_snapshot 共用候选准备，不执行查询、条件、任务信号或奖励。 报告只说明调用当时的输入与目录；正式恢复会重新验证，不能复用旧报告准入。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 待恢复的封闭快照。 |

返回：当前输入和目录的独立校验报告；不输出错误日志。

结构：

- `snapshot`: 与 restore_snapshot.snapshot 相同；不要求先执行实际恢复。
- `return`: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。 /snapshot/states/N 指输入中第 N 个状态，N 从 0 开始；invalid_state 定位整条状态记录，其内部字段须符合 GFQuestState 记录契约。
