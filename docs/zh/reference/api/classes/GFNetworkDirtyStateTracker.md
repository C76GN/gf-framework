# GFNetworkDirtyStateTracker

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_dirty_state_tracker.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

通用网络状态 dirty 字段追踪器。 维护字段基线、优先级和近似比较规则，帮助项目或扩展决定哪些状态需要同步。 它不扫描节点、不规定 authority，也不发送消息。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Priority`](#member-gfnetworkdirtystatetracker-enums-priority) | `enum Priority` |
| 属性 | [`epsilon`](#member-gfnetworkdirtystatetracker-properties-epsilon) | `var epsilon: float = 0.001:` |
| 属性 | [`default_priority`](#member-gfnetworkdirtystatetracker-properties-default_priority) | `var default_priority: Priority = Priority.NORMAL` |
| 方法 | [`set_field_priority`](#member-gfnetworkdirtystatetracker-methods-set_field_priority) | `func set_field_priority(field_id: StringName, priority: Priority) -> void:` |
| 方法 | [`get_field_priority`](#member-gfnetworkdirtystatetracker-methods-get_field_priority) | `func get_field_priority(field_id: StringName) -> Priority:` |
| 方法 | [`set_baseline`](#member-gfnetworkdirtystatetracker-methods-set_baseline) | `func set_baseline(state: Dictionary) -> void:` |
| 方法 | [`update_baseline`](#member-gfnetworkdirtystatetracker-methods-update_baseline) | `func update_baseline(state: Dictionary, field_ids: PackedStringArray = PackedStringArray()) -> int:` |
| 方法 | [`get_dirty_report`](#member-gfnetworkdirtystatetracker-methods-get_dirty_report) | `func get_dirty_report(state: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_field_dirty`](#member-gfnetworkdirtystatetracker-methods-is_field_dirty) | `func is_field_dirty(state: Dictionary, field_id: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfnetworkdirtystatetracker-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkdirtystatetracker-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfnetworkdirtystatetracker-enums-priority"></a>

### `Priority`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
enum Priority {
	## 高频、强实时字段。
	REALTIME,
	## 高优先级字段。
	HIGH,
	## 普通字段。
	NORMAL,
	## 低频字段。
	LOW,
	## 只适合出生或初始状态同步的字段。
	SPAWN_ONLY,
	## 只保留在本地的字段。
	LOCAL_ONLY,
}
```

字段同步优先级。

## 属性

<a id="member-gfnetworkdirtystatetracker-properties-epsilon"></a>

### `epsilon`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var epsilon: float = 0.001:
```

浮点和向量近似比较阈值。

<a id="member-gfnetworkdirtystatetracker-properties-default_priority"></a>

### `default_priority`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var default_priority: Priority = Priority.NORMAL
```

默认字段优先级。

## 方法

<a id="member-gfnetworkdirtystatetracker-methods-set_field_priority"></a>

### `set_field_priority`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_field_priority(field_id: StringName, priority: Priority) -> void:
```

设置字段优先级。

参数：

| 名称 | 说明 |
|---|---|
| `field_id` | 字段标识。 |
| `priority` | 优先级。 |

<a id="member-gfnetworkdirtystatetracker-methods-get_field_priority"></a>

### `get_field_priority`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_field_priority(field_id: StringName) -> Priority:
```

获取字段优先级。

参数：

| 名称 | 说明 |
|---|---|
| `field_id` | 字段标识。 |

返回：字段优先级。

<a id="member-gfnetworkdirtystatetracker-methods-set_baseline"></a>

### `set_baseline`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_baseline(state: Dictionary) -> void:
```

设置基线状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 字段状态。 |

结构：

- `state`: Dictionary mapping field ids to values.

<a id="member-gfnetworkdirtystatetracker-methods-update_baseline"></a>

### `update_baseline`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func update_baseline(state: Dictionary, field_ids: PackedStringArray = PackedStringArray()) -> int:
```

使用当前状态更新全部或指定字段基线。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 字段状态。 |
| `field_ids` | 指定字段；为空时更新全部字段。 |

返回：更新字段数量。

结构：

- `state`: Dictionary mapping field ids to values.

<a id="member-gfnetworkdirtystatetracker-methods-get_dirty_report"></a>

### `get_dirty_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_dirty_report(state: Dictionary, options: Dictionary = {}) -> Dictionary:
```

获取 dirty 字段报告。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前字段状态。 |
| `options` | 可选参数，支持 include_spawn_only、include_local_only、priorities。 |

返回：dirty 字段报告。

结构：

- `state`: Dictionary mapping field ids to values.
- `options`: Dictionary with optional `include_spawn_only: bool`, `include_local_only: bool`, and `priorities: Array`.
- `return`: Dictionary with dirty_count, dirty_fields, by_priority, and values.

<a id="member-gfnetworkdirtystatetracker-methods-is_field_dirty"></a>

### `is_field_dirty`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_field_dirty(state: Dictionary, field_id: StringName) -> bool:
```

检查字段是否 dirty。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前字段状态。 |
| `field_id` | 字段标识。 |

返回：字段值变化时返回 true。

结构：

- `state`: Dictionary mapping field ids to values.

<a id="member-gfnetworkdirtystatetracker-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空基线和优先级。

<a id="member-gfnetworkdirtystatetracker-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with baseline_count, priority_count, epsilon, and default_priority.
