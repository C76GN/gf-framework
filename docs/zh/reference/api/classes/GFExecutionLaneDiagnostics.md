# GFExecutionLaneDiagnostics

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_execution_lane_diagnostics.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用执行通道诊断快照。 用于记录按 lane 划分的 queued / active / completed / failed / timeout / cancelled 等运行态指标。它只保存诊断数据，不调度任务、不决定重试策略，也不绑定具体业务通道。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`lane_snapshot_recorded`](#member-gfexecutionlanediagnostics-signals-lane_snapshot_recorded) | `signal lane_snapshot_recorded(lane_id: StringName, snapshot: Dictionary)` |
| 信号 | [`lane_event_recorded`](#member-gfexecutionlanediagnostics-signals-lane_event_recorded) | `signal lane_event_recorded(lane_id: StringName, event: Dictionary)` |
| 常量 | [`STATUS_OK`](#member-gfexecutionlanediagnostics-constants-status_ok) | `const STATUS_OK: StringName = &"ok"` |
| 常量 | [`STATUS_WARNING`](#member-gfexecutionlanediagnostics-constants-status_warning) | `const STATUS_WARNING: StringName = &"warning"` |
| 常量 | [`STATUS_ERROR`](#member-gfexecutionlanediagnostics-constants-status_error) | `const STATUS_ERROR: StringName = &"error"` |
| 常量 | [`EVENT_QUEUED`](#member-gfexecutionlanediagnostics-constants-event_queued) | `const EVENT_QUEUED: StringName = &"queued"` |
| 常量 | [`EVENT_STARTED`](#member-gfexecutionlanediagnostics-constants-event_started) | `const EVENT_STARTED: StringName = &"started"` |
| 常量 | [`EVENT_COMPLETED`](#member-gfexecutionlanediagnostics-constants-event_completed) | `const EVENT_COMPLETED: StringName = &"completed"` |
| 常量 | [`EVENT_FAILED`](#member-gfexecutionlanediagnostics-constants-event_failed) | `const EVENT_FAILED: StringName = &"failed"` |
| 常量 | [`EVENT_CANCELLED`](#member-gfexecutionlanediagnostics-constants-event_cancelled) | `const EVENT_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`EVENT_TIMEOUT`](#member-gfexecutionlanediagnostics-constants-event_timeout) | `const EVENT_TIMEOUT: StringName = &"timeout"` |
| 常量 | [`EVENT_RELEASED`](#member-gfexecutionlanediagnostics-constants-event_released) | `const EVENT_RELEASED: StringName = &"released"` |
| 常量 | [`DEFAULT_MAX_RECENT_EVENTS`](#member-gfexecutionlanediagnostics-constants-default_max_recent_events) | `const DEFAULT_MAX_RECENT_EVENTS: int = 128` |
| 属性 | [`max_recent_events`](#member-gfexecutionlanediagnostics-properties-max_recent_events) | `var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:` |
| 属性 | [`max_lanes`](#member-gfexecutionlanediagnostics-properties-max_lanes) | `var max_lanes: int = 1024:` |
| 属性 | [`max_inactive_lane_age_msec`](#member-gfexecutionlanediagnostics-properties-max_inactive_lane_age_msec) | `var max_inactive_lane_age_msec: int = 0:` |
| 方法 | [`record_lane_snapshot`](#member-gfexecutionlanediagnostics-methods-record_lane_snapshot) | `func record_lane_snapshot(lane_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`record_lane_event`](#member-gfexecutionlanediagnostics-methods-record_lane_event) | `func record_lane_event(lane_id: StringName, event_type: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`remove_lane`](#member-gfexecutionlanediagnostics-methods-remove_lane) | `func remove_lane(lane_id: StringName) -> bool:` |
| 方法 | [`compact_lanes`](#member-gfexecutionlanediagnostics-methods-compact_lanes) | `func compact_lanes(max_age_msec: int = -1) -> int:` |
| 方法 | [`clear`](#member-gfexecutionlanediagnostics-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_lane_snapshot`](#member-gfexecutionlanediagnostics-methods-get_lane_snapshot) | `func get_lane_snapshot(lane_id: StringName) -> Dictionary:` |
| 方法 | [`get_lane_snapshots`](#member-gfexecutionlanediagnostics-methods-get_lane_snapshots) | `func get_lane_snapshots(limit: int = 0) -> Array[Dictionary]:` |
| 方法 | [`get_recent_events`](#member-gfexecutionlanediagnostics-methods-get_recent_events) | `func get_recent_events(limit: int = 0) -> Array[Dictionary]:` |
| 方法 | [`get_health_snapshot`](#member-gfexecutionlanediagnostics-methods-get_health_snapshot) | `func get_health_snapshot(limit: int = 5) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfexecutionlanediagnostics-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfexecutionlanediagnostics-signals-lane_snapshot_recorded"></a>

### `lane_snapshot_recorded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal lane_snapshot_recorded(lane_id: StringName, snapshot: Dictionary)
```

lane 快照记录或更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |
| `snapshot` | lane 快照副本。 |

结构：

- `snapshot`: Dictionary，包含 queued_count、active_count、completed_count、failed_count、timeout_count、cancelled_count 和 metadata。

<a id="member-gfexecutionlanediagnostics-signals-lane_event_recorded"></a>

### `lane_event_recorded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal lane_event_recorded(lane_id: StringName, event: Dictionary)
```

lane 事件记录时发出。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |
| `event` | 事件快照副本。 |

结构：

- `event`: Dictionary，包含 event_type、lane_id、status、计数和 metadata。

## 常量

<a id="member-gfexecutionlanediagnostics-constants-status_ok"></a>

### `STATUS_OK`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_OK: StringName = &"ok"
```

lane 处于正常状态。

<a id="member-gfexecutionlanediagnostics-constants-status_warning"></a>

### `STATUS_WARNING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_WARNING: StringName = &"warning"
```

lane 存在排队积压或取消。

<a id="member-gfexecutionlanediagnostics-constants-status_error"></a>

### `STATUS_ERROR`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_ERROR: StringName = &"error"
```

lane 存在失败或超时。

<a id="member-gfexecutionlanediagnostics-constants-event_queued"></a>

### `EVENT_QUEUED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_QUEUED: StringName = &"queued"
```

请求进入队列事件。

<a id="member-gfexecutionlanediagnostics-constants-event_started"></a>

### `EVENT_STARTED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_STARTED: StringName = &"started"
```

请求开始执行事件。

<a id="member-gfexecutionlanediagnostics-constants-event_completed"></a>

### `EVENT_COMPLETED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_COMPLETED: StringName = &"completed"
```

请求完成事件。

<a id="member-gfexecutionlanediagnostics-constants-event_failed"></a>

### `EVENT_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_FAILED: StringName = &"failed"
```

请求失败事件。

<a id="member-gfexecutionlanediagnostics-constants-event_cancelled"></a>

### `EVENT_CANCELLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_CANCELLED: StringName = &"cancelled"
```

请求取消事件。

<a id="member-gfexecutionlanediagnostics-constants-event_timeout"></a>

### `EVENT_TIMEOUT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_TIMEOUT: StringName = &"timeout"
```

请求超时事件。

<a id="member-gfexecutionlanediagnostics-constants-event_released"></a>

### `EVENT_RELEASED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const EVENT_RELEASED: StringName = &"released"
```

请求释放槽位事件。

<a id="member-gfexecutionlanediagnostics-constants-default_max_recent_events"></a>

### `DEFAULT_MAX_RECENT_EVENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_RECENT_EVENTS: int = 128
```

默认保留的最近事件数量。

## 属性

<a id="member-gfexecutionlanediagnostics-properties-max_recent_events"></a>

### `max_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
```

最近事件历史上限。设置为 0 时不保留事件。

<a id="member-gfexecutionlanediagnostics-properties-max_lanes"></a>

### `max_lanes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_lanes: int = 1024:
```

lane 记录数量上限。为 0 时不限制；自动清理只会移除 inactive lane。

<a id="member-gfexecutionlanediagnostics-properties-max_inactive_lane_age_msec"></a>

### `max_inactive_lane_age_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_inactive_lane_age_msec: int = 0:
```

自动清理 inactive lane 的年龄阈值，单位毫秒。为 0 时不按时间自动清理。

## 方法

<a id="member-gfexecutionlanediagnostics-methods-record_lane_snapshot"></a>

### `record_lane_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_lane_snapshot(lane_id: StringName, options: Dictionary = {}) -> Dictionary:
```

记录一个 lane 的完整快照。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |
| `options` | 快照选项，支持 queued_count、active_count、completed_count、failed_count、timeout_count、cancelled_count、status、label 和 metadata。 |

返回：lane 快照。

结构：

- `options`: Dictionary，包含计数、status、label 和 metadata。
- `return`: Dictionary，包含 lane_id、status、计数、max_queued_count、max_active_count、event_count 和 metadata。

<a id="member-gfexecutionlanediagnostics-methods-record_lane_event"></a>

### `record_lane_event`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_lane_event(lane_id: StringName, event_type: StringName, options: Dictionary = {}) -> Dictionary:
```

记录一个 lane 事件并更新计数。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |
| `event_type` | 事件类型，建议使用 EVENT_* 常量。 |
| `options` | 事件选项，支持 queued_delta、active_delta、status、label 和 metadata。 |

返回：事件快照。

结构：

- `options`: Dictionary，包含 queued_delta、active_delta、status、label 和 metadata。
- `return`: Dictionary，包含 sequence、event_type、lane_id、status、计数和 metadata。

<a id="member-gfexecutionlanediagnostics-methods-remove_lane"></a>

### `remove_lane`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove_lane(lane_id: StringName) -> bool:
```

移除一个 lane。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfexecutionlanediagnostics-methods-compact_lanes"></a>

### `compact_lanes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func compact_lanes(max_age_msec: int = -1) -> int:
```

清理 inactive lane。

参数：

| 名称 | 说明 |
|---|---|
| `max_age_msec` | 大于等于 0 时移除超过该年龄的 inactive lane；小于 0 时仅应用 max_lanes 容量上限。 |

返回：移除的 lane 数量。

<a id="member-gfexecutionlanediagnostics-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部 lane 和事件历史。

<a id="member-gfexecutionlanediagnostics-methods-get_lane_snapshot"></a>

### `get_lane_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_lane_snapshot(lane_id: StringName) -> Dictionary:
```

获取一个 lane 的快照。

参数：

| 名称 | 说明 |
|---|---|
| `lane_id` | 执行通道 ID。 |

返回：lane 快照；不存在时为空字典。

结构：

- `return`: Dictionary，包含 lane_id、status、计数、max_queued_count、max_active_count、event_count 和 metadata。

<a id="member-gfexecutionlanediagnostics-methods-get_lane_snapshots"></a>

### `get_lane_snapshots`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_lane_snapshots(limit: int = 0) -> Array[Dictionary]:
```

获取全部 lane 快照。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部。 |

返回：lane 快照数组，按最近更新时间倒序排列。

结构：

- `return`: Array[Dictionary]，每个元素为 lane 快照。

<a id="member-gfexecutionlanediagnostics-methods-get_recent_events"></a>

### `get_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_recent_events(limit: int = 0) -> Array[Dictionary]:
```

获取最近 lane 事件。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部。 |

返回：最近事件数组，按记录顺序返回。

结构：

- `return`: Array[Dictionary]，每个元素包含 sequence、event_type、lane_id、status、计数和 metadata。

<a id="member-gfexecutionlanediagnostics-methods-get_health_snapshot"></a>

### `get_health_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_health_snapshot(limit: int = 5) -> Dictionary:
```

获取整体健康快照。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | recent_lanes 与 recent_events 的最大数量。 |

返回：健康快照字典。

结构：

- `return`: Dictionary，包含 status、lane_count、queued_count、active_count、failed_count、timeout_count、cancelled_count、recent_lanes 和 recent_events。

<a id="member-gfexecutionlanediagnostics-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 max_recent_events、health、lanes 和 recent_events。
