# GFVirtualInputPulseOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/sources/gf_virtual_input_pulse_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

单次虚拟输入脉冲的类型化运行时句柄。 句柄冻结创建时的 Mapping、source_id、player_index 与 action_id，并由 GFInputMappingUtility 的权威 lease 保证旧定时器不会释放后续脉冲。owner 与 cancellation_token 均为可选锚点；同时提供时，任一先结束都会取消脉冲。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfvirtualinputpulseoperation-signals-completed) | `signal completed(operation: GFVirtualInputPulseOperation)` |
| 枚举 | [`Status`](#member-gfvirtualinputpulseoperation-enums-status) | `enum Status` |
| 方法 | [`cancel`](#member-gfvirtualinputpulseoperation-methods-cancel) | `func cancel(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_generation`](#member-gfvirtualinputpulseoperation-methods-get_generation) | `func get_generation() -> int:` |
| 方法 | [`get_source_id`](#member-gfvirtualinputpulseoperation-methods-get_source_id) | `func get_source_id() -> StringName:` |
| 方法 | [`get_player_index`](#member-gfvirtualinputpulseoperation-methods-get_player_index) | `func get_player_index() -> int:` |
| 方法 | [`get_action_id`](#member-gfvirtualinputpulseoperation-methods-get_action_id) | `func get_action_id() -> StringName:` |
| 方法 | [`get_duration_seconds`](#member-gfvirtualinputpulseoperation-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`get_status`](#member-gfvirtualinputpulseoperation-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_terminal_reason`](#member-gfvirtualinputpulseoperation-methods-get_terminal_reason) | `func get_terminal_reason() -> StringName:` |
| 方法 | [`is_pending`](#member-gfvirtualinputpulseoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfvirtualinputpulseoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_release_count`](#member-gfvirtualinputpulseoperation-methods-get_release_count) | `func get_release_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfvirtualinputpulseoperation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfvirtualinputpulseoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal completed(operation: GFVirtualInputPulseOperation)
```

脉冲首次进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 已进入终态的当前句柄。 |

## 枚举

<a id="member-gfvirtualinputpulseoperation-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Status {
	## 等待定时、生命周期或显式终止。
	PENDING,
	## 到达脉冲时长并完成匹配释放。
	COMPLETED,
	## 被调用方、owner、token 或状态清理取消。
	CANCELLED,
	## 被同一稳定输入键上的新脉冲替换。
	REPLACED,
	## 因同一稳定输入键已有脉冲而拒绝启动。
	REJECTED,
	## 输入或运行时依赖无效，未能启动。
	FAILED,
}
```

脉冲操作状态。

## 方法

<a id="member-gfvirtualinputpulseoperation-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled") -> bool:
```

取消仍在等待的脉冲。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因；空值会规范化为 cancelled。 |

返回：本次调用是否首次使操作进入终态。

<a id="member-gfvirtualinputpulseoperation-methods-get_generation"></a>

### `get_generation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_generation() -> int:
```

获取 Source 分配的单调 generation。

返回：大于零的 generation；配置失败前可能为 0。

<a id="member-gfvirtualinputpulseoperation-methods-get_source_id"></a>

### `get_source_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_source_id() -> StringName:
```

获取冻结的虚拟输入源标识。

返回：创建脉冲时的 source_id。

<a id="member-gfvirtualinputpulseoperation-methods-get_player_index"></a>

### `get_player_index`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_player_index() -> int:
```

获取冻结的玩家索引。

返回：创建脉冲时的 player_index。

<a id="member-gfvirtualinputpulseoperation-methods-get_action_id"></a>

### `get_action_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_action_id() -> StringName:
```

获取冻结的动作标识。

返回：创建脉冲时的 action_id。

<a id="member-gfvirtualinputpulseoperation-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_duration_seconds() -> float:
```

获取规范化脉冲时长。

返回：秒数。

<a id="member-gfvirtualinputpulseoperation-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

获取当前状态。

返回：Status 枚举值。

<a id="member-gfvirtualinputpulseoperation-methods-get_terminal_reason"></a>

### `get_terminal_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_terminal_reason() -> StringName:
```

获取终态原因。

返回：等待中为空 StringName；终态时为稳定原因。

<a id="member-gfvirtualinputpulseoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_pending() -> bool:
```

返回操作是否仍在等待。

返回：等待中返回 true。

<a id="member-gfvirtualinputpulseoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_completed() -> bool:
```

返回操作是否已经进入任意终态。

返回：已完成、取消、替换、拒绝或失败时返回 true。

<a id="member-gfvirtualinputpulseoperation-methods-get_release_count"></a>

### `get_release_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_release_count() -> int:
```

获取该脉冲完成的匹配释放次数。

返回：仅当前 lease 实际清除动作贡献时为 1；无释放交接、未取得 lease 或未释放时为 0。

<a id="member-gfvirtualinputpulseoperation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：冻结身份、状态、时长、时间戳与释放证明。

结构：

- `return`: Dictionary，包含 generation、source_id、player_index、action_id、duration_seconds、status、status_name、terminal_reason、pending、completed、started_at_msec、completed_at_msec、release_count、lease_acquired 和 timer_handle。
