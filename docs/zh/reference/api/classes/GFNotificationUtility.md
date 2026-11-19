# GFNotificationUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_notification_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用运行时通知队列。 管理通知数据、队列、去重和生命周期信号。默认串行展示，可配置多个活动通知。 单条活动通知接口面向最早开始展示且仍在活动的记录。项目决定展示布局和样式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`notification_queued`](#member-gfnotificationutility-signals-notification_queued) | `signal notification_queued(notification: Dictionary)` |
| 信号 | [`notification_started`](#member-gfnotificationutility-signals-notification_started) | `signal notification_started(notification: Dictionary)` |
| 信号 | [`notification_finished`](#member-gfnotificationutility-signals-notification_finished) | `signal notification_finished(notification: Dictionary, reason: String)` |
| 信号 | [`notification_action_invoked`](#member-gfnotificationutility-signals-notification_action_invoked) | `signal notification_action_invoked(notification: Dictionary, action_id: StringName)` |
| 枚举 | [`Level`](#member-gfnotificationutility-enums-level) | `enum Level` |
| 枚举 | [`Priority`](#member-gfnotificationutility-enums-priority) | `enum Priority` |
| 属性 | [`default_duration_seconds`](#member-gfnotificationutility-properties-default_duration_seconds) | `var default_duration_seconds: float = 3.0` |
| 属性 | [`max_queue_size`](#member-gfnotificationutility-properties-max_queue_size) | `var max_queue_size: int = 32` |
| 属性 | [`max_active_notifications`](#member-gfnotificationutility-properties-max_active_notifications) | `var max_active_notifications: int = 1:` |
| 属性 | [`suppress_duplicates`](#member-gfnotificationutility-properties-suppress_duplicates) | `var suppress_duplicates: bool = true` |
| 方法 | [`tick`](#member-gfnotificationutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfnotificationutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`push_notification`](#member-gfnotificationutility-methods-push_notification) | `func push_notification( message: String, title: String = "", level: Level = Level.INFO, options: Dictionary = {} ) -> int:` |
| 方法 | [`dismiss_active`](#member-gfnotificationutility-methods-dismiss_active) | `func dismiss_active(reason: String = "dismissed") -> void:` |
| 方法 | [`dismiss_notification`](#member-gfnotificationutility-methods-dismiss_notification) | `func dismiss_notification(notification_id: int, reason: String = "dismissed") -> bool:` |
| 方法 | [`clear_notifications`](#member-gfnotificationutility-methods-clear_notifications) | `func clear_notifications(reason: String = "cleared") -> void:` |
| 方法 | [`get_active_notification`](#member-gfnotificationutility-methods-get_active_notification) | `func get_active_notification() -> Dictionary:` |
| 方法 | [`get_active_notifications`](#member-gfnotificationutility-methods-get_active_notifications) | `func get_active_notifications() -> Array[Dictionary]:` |
| 方法 | [`pause_active`](#member-gfnotificationutility-methods-pause_active) | `func pause_active() -> void:` |
| 方法 | [`resume_active`](#member-gfnotificationutility-methods-resume_active) | `func resume_active() -> void:` |
| 方法 | [`is_active_paused`](#member-gfnotificationutility-methods-is_active_paused) | `func is_active_paused() -> bool:` |
| 方法 | [`invoke_active_action`](#member-gfnotificationutility-methods-invoke_active_action) | `func invoke_active_action(action_id: StringName) -> bool:` |
| 方法 | [`invoke_notification_action`](#member-gfnotificationutility-methods-invoke_notification_action) | `func invoke_notification_action(notification_id: int, action_id: StringName) -> bool:` |
| 方法 | [`get_queue`](#member-gfnotificationutility-methods-get_queue) | `func get_queue() -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfnotificationutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnotificationutility-signals-notification_queued"></a>

### `notification_queued`

- API：`public`

```gdscript
signal notification_queued(notification: Dictionary)
```

通知进入队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `notification` | 通知副本。 |

结构：

- `notification`: Dictionary，包含 id、key、dedupe_key、title、message、level、priority、sticky、duration_seconds、created_at_unix、actions 和 metadata。

<a id="member-gfnotificationutility-signals-notification_started"></a>

### `notification_started`

- API：`public`

```gdscript
signal notification_started(notification: Dictionary)
```

通知开始展示时发出。

参数：

| 名称 | 说明 |
|---|---|
| `notification` | 通知副本。 |

结构：

- `notification`: Dictionary，字段同 notification_queued 的 notification。

<a id="member-gfnotificationutility-signals-notification_finished"></a>

### `notification_finished`

- API：`public`

```gdscript
signal notification_finished(notification: Dictionary, reason: String)
```

通知结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `notification` | 通知副本。 |
| `reason` | 结束原因。 |

结构：

- `notification`: Dictionary，字段同 notification_queued 的 notification。

<a id="member-gfnotificationutility-signals-notification_action_invoked"></a>

### `notification_action_invoked`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal notification_action_invoked(notification: Dictionary, action_id: StringName)
```

活动通知的动作被触发时发出。

参数：

| 名称 | 说明 |
|---|---|
| `notification` | 触发动作的通知副本。 |
| `action_id` | 动作标识。 |

结构：

- `notification`: Dictionary，字段同 notification_queued 的 notification。

## 枚举

<a id="member-gfnotificationutility-enums-level"></a>

### `Level`

- API：`public`

```gdscript
enum Level {
	## 普通信息。
	INFO,
	## 成功反馈。
	SUCCESS,
	## 警告信息。
	WARNING,
	## 错误信息。
	ERROR,
}
```

通知等级。

<a id="member-gfnotificationutility-enums-priority"></a>

### `Priority`

- API：`public`

```gdscript
enum Priority {
	## 低优先级。
	LOW,
	## 默认优先级。
	NORMAL,
	## 高优先级。
	HIGH,
	## 最高优先级。
	CRITICAL,
}
```

通知优先级。数值越大越靠前。

## 属性

<a id="member-gfnotificationutility-properties-default_duration_seconds"></a>

### `default_duration_seconds`

- API：`public`

```gdscript
var default_duration_seconds: float = 3.0
```

默认展示时长。

<a id="member-gfnotificationutility-properties-max_queue_size"></a>

### `max_queue_size`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_queue_size: int = 32
```

最大等待数量。设为 0 时只保留活动通知。

<a id="member-gfnotificationutility-properties-max_active_notifications"></a>

### `max_active_notifications`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_active_notifications: int = 1:
```

活动通知的准入上限，默认 1，范围 1 至 32。提高上限会补入等待通知。降低上限时已有活动通知自然结束。

<a id="member-gfnotificationutility-properties-suppress_duplicates"></a>

### `suppress_duplicates`

- API：`public`

```gdscript
var suppress_duplicates: bool = true
```

是否抑制重复入队。有显式 key 时按 key 去重，否则按消息文本去重。

## 方法

<a id="member-gfnotificationutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfnotificationutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放通知队列状态。

<a id="member-gfnotificationutility-methods-push_notification"></a>

### `push_notification`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_notification( message: String, title: String = "", level: Level = Level.INFO, options: Dictionary = {} ) -> int:
```

推入通知。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 通知正文。 |
| `title` | 通知标题。 |
| `level` | 通知等级。 |
| `options` | 可选参数，支持 duration_seconds、key、metadata、priority、sticky、actions。 |

返回：接纳时返回通知 ID。重复通知返回已有 ID，空通知和清空期间的请求返回 0。

结构：

- `options`: Dictionary，支持 duration_seconds、key、metadata、priority、sticky 和 actions。actions 为 Array[StringName|String|Dictionary]，Dictionary action 包含 id、可选 label、dismiss 和 metadata；label 为空时由项目 UI 决定展示文案。

<a id="member-gfnotificationutility-methods-dismiss_active"></a>

### `dismiss_active`

- API：`public`

```gdscript
func dismiss_active(reason: String = "dismissed") -> void:
```

结束当前通知。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 结束原因。 |

<a id="member-gfnotificationutility-methods-dismiss_notification"></a>

### `dismiss_notification`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dismiss_notification(notification_id: int, reason: String = "dismissed") -> bool:
```

按 ID 结束一条活动通知并处理腾出的名额。

参数：

| 名称 | 说明 |
|---|---|
| `notification_id` | push_notification() 返回的通知 ID。 |
| `reason` | 交给 notification_finished 的结束原因。 |

返回：该 ID 处于活动状态并已结束时返回 true。

<a id="member-gfnotificationutility-methods-clear_notifications"></a>

### `clear_notifications`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_notifications(reason: String = "cleared") -> void:
```

先撤下全部活动通知并清空等待队列，再为每条原先活动的通知发出结束信号。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 结束原因。 |

<a id="member-gfnotificationutility-methods-get_active_notification"></a>

### `get_active_notification`

- API：`public`

```gdscript
func get_active_notification() -> Dictionary:
```

获取当前通知。

返回：当前通知副本。

结构：

- `return`: Dictionary，当前通知记录；无当前通知时为空。字段同 notification_queued 的 notification。

<a id="member-gfnotificationutility-methods-get_active_notifications"></a>

### `get_active_notifications`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_notifications() -> Array[Dictionary]:
```

按开始展示的顺序获取所有活动通知的副本。

返回：活动通知记录数组。

结构：

- `return`: Array，元素为通知记录 Dictionary，字段同 notification_queued 的 notification。

<a id="member-gfnotificationutility-methods-pause_active"></a>

### `pause_active`

- API：`public`

```gdscript
func pause_active() -> void:
```

暂停当前通知倒计时。

<a id="member-gfnotificationutility-methods-resume_active"></a>

### `resume_active`

- API：`public`

```gdscript
func resume_active() -> void:
```

恢复当前通知倒计时。

<a id="member-gfnotificationutility-methods-is_active_paused"></a>

### `is_active_paused`

- API：`public`

```gdscript
func is_active_paused() -> bool:
```

当前通知是否处于暂停状态。

返回：暂停时返回 true。

<a id="member-gfnotificationutility-methods-invoke_active_action"></a>

### `invoke_active_action`

- API：`public`

```gdscript
func invoke_active_action(action_id: StringName) -> bool:
```

触发当前通知的一个动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：当前通知包含该动作时返回 true。

<a id="member-gfnotificationutility-methods-invoke_notification_action"></a>

### `invoke_notification_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func invoke_notification_action(notification_id: int, action_id: StringName) -> bool:
```

按 ID 触发活动通知的动作。动作要求结束时，只结束发出该动作的通知。

参数：

| 名称 | 说明 |
|---|---|
| `notification_id` | push_notification() 返回的通知 ID。 |
| `action_id` | 动作标识。 |

返回：该 ID 处于活动状态且包含该动作时返回 true。

<a id="member-gfnotificationutility-methods-get_queue"></a>

### `get_queue`

- API：`public`

```gdscript
func get_queue() -> Array[Dictionary]:
```

获取等待队列。

返回：通知副本数组。

结构：

- `return`: Array，元素为通知记录 Dictionary，字段同 notification_queued 的 notification。

<a id="member-gfnotificationutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：通知队列状态。

结构：

- `return`: Dictionary，包含 active、queue、queue_size、active_remaining_seconds、active_paused 和 max_queue_size。
