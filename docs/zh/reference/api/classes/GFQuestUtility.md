# GFQuestUtility

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/quest/gf_quest_utility.gd`
- 模块：`Domain`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

轻量级任务进度监听系统。 基于 `simple event` 将业务事件映射为任务进度累积， 适合用于成就、收集与击杀类目标的低成本跟踪。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`quest_started`](#member-gfquestutility-signals-quest_started) | `signal quest_started(quest_id: StringName)` |
| 信号 | [`quest_available`](#member-gfquestutility-signals-quest_available) | `signal quest_available(quest_id: StringName)` |
| 信号 | [`quest_acceptance_blocked`](#member-gfquestutility-signals-quest_acceptance_blocked) | `signal quest_acceptance_blocked(quest_id: StringName, reason: String)` |
| 信号 | [`quest_progressed`](#member-gfquestutility-signals-quest_progressed) | `signal quest_progressed(quest_id: StringName, current: int, target: int)` |
| 信号 | [`quest_completed`](#member-gfquestutility-signals-quest_completed) | `signal quest_completed(quest_id: StringName)` |
| 信号 | [`quest_completion_blocked`](#member-gfquestutility-signals-quest_completion_blocked) | `signal quest_completion_blocked(quest_id: StringName, reason: String)` |
| 信号 | [`quest_cancelled`](#member-gfquestutility-signals-quest_cancelled) | `signal quest_cancelled(quest_id: StringName)` |
| 信号 | [`quest_failed`](#member-gfquestutility-signals-quest_failed) | `signal quest_failed(quest_id: StringName)` |
| 常量 | [`STATUS_AVAILABLE`](#member-gfquestutility-constants-status_available) | `const STATUS_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATUS_ACTIVE`](#member-gfquestutility-constants-status_active) | `const STATUS_ACTIVE: StringName = &"active"` |
| 常量 | [`STATUS_COMPLETED`](#member-gfquestutility-constants-status_completed) | `const STATUS_COMPLETED: StringName = &"completed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfquestutility-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_FAILED`](#member-gfquestutility-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 属性 | [`allow_negative_progress`](#member-gfquestutility-properties-allow_negative_progress) | `var allow_negative_progress: bool = false` |
| 方法 | [`start_quest`](#member-gfquestutility-methods-start_quest) | `func start_quest(quest_id: StringName, target_event: StringName, target_count: int = 1) -> void:` |
| 方法 | [`define_quest`](#member-gfquestutility-methods-define_quest) | `func define_quest( quest_id: StringName, target_event: StringName, target_count: int = 1, metadata: Dictionary = {} ) -> void:` |
| 方法 | [`accept_quest`](#member-gfquestutility-methods-accept_quest) | `func accept_quest(quest_id: StringName) -> bool:` |
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
| 方法 | [`emit_quest_event`](#member-gfquestutility-methods-emit_quest_event) | `func emit_quest_event(event_id: StringName, amount: int = 1) -> void:` |
| 方法 | [`is_quest_completed`](#member-gfquestutility-methods-is_quest_completed) | `func is_quest_completed(quest_id: StringName) -> bool:` |
| 方法 | [`get_quest_progress`](#member-gfquestutility-methods-get_quest_progress) | `func get_quest_progress(quest_id: StringName) -> float:` |
| 方法 | [`get_quest_status`](#member-gfquestutility-methods-get_quest_status) | `func get_quest_status(quest_id: StringName) -> StringName:` |
| 方法 | [`get_quests_by_status`](#member-gfquestutility-methods-get_quests_by_status) | `func get_quests_by_status(status: StringName) -> PackedStringArray:` |
| 方法 | [`get_quest_report`](#member-gfquestutility-methods-get_quest_report) | `func get_quest_report(quest_id: StringName) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfquestutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

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

```gdscript
signal quest_progressed(quest_id: StringName, current: int, target: int)
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

## 属性

<a id="member-gfquestutility-properties-allow_negative_progress"></a>

### `allow_negative_progress`

- API：`public`

```gdscript
var allow_negative_progress: bool = false
```

是否允许事件传入负数进度。默认关闭，避免任务进度被异常 payload 反向扣减。

## 方法

<a id="member-gfquestutility-methods-start_quest"></a>

### `start_quest`

- API：`public`

```gdscript
func start_quest(quest_id: StringName, target_event: StringName, target_count: int = 1) -> void:
```

开始监听一个任务。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `target_event` | 推进该任务的事件 ID。 |
| `target_count` | 完成任务所需的累计次数。 |

<a id="member-gfquestutility-methods-define_quest"></a>

### `define_quest`

- API：`public`

```gdscript
func define_quest( quest_id: StringName, target_event: StringName, target_count: int = 1, metadata: Dictionary = {} ) -> void:
```

定义一个可接取任务，但暂不开始监听事件。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |
| `target_event` | 推进该任务的事件 ID。 |
| `target_count` | 完成任务所需的累计次数。 |
| `metadata` | 任务元数据。框架不解释该字段。 |

结构：

- `metadata`: Dictionary，项目自定义任务元数据；GF 会复制保存并在任务报告中透传。

<a id="member-gfquestutility-methods-accept_quest"></a>

### `accept_quest`

- API：`public`

```gdscript
func accept_quest(quest_id: StringName) -> bool:
```

接取一个已定义任务，并开始监听事件。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：接取成功返回 true。

<a id="member-gfquestutility-methods-complete_quest"></a>

### `complete_quest`

- API：`public`

```gdscript
func complete_quest(quest_id: StringName) -> bool:
```

手动完成一个任务。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 任务 ID。 |

返回：完成成功返回 true。

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

```gdscript
func emit_quest_event(event_id: StringName, amount: int = 1) -> void:
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

- `return`: Dictionary，包含 quest_id、event_id、target_count、current_count、is_completed、status、parent_id、child_ids、metadata、acceptance_condition_count 与 completion_blocker_count。

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
