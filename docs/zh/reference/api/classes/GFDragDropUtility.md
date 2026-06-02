# GFDragDropUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/drag_drop/gf_drag_drop_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用拖拽会话与落点匹配工具。 该工具只管理拖拽生命周期、落点注册、命中排序和结果包装。 它不读取输入、不移动节点、不保存业务历史，也不规定具体 UI 或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`drag_started`](#member-gfdragdroputility-signals-drag_started) | `signal drag_started(session_id: int, drag_type: StringName)` |
| 信号 | [`drag_moved`](#member-gfdragdroputility-signals-drag_moved) | `signal drag_moved(session_id: int, position: Vector2, delta: Vector2)` |
| 信号 | [`drag_dropped`](#member-gfdragdroputility-signals-drag_dropped) | `signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)` |
| 信号 | [`drag_drop_rejected`](#member-gfdragdroputility-signals-drag_drop_rejected) | `signal drag_drop_rejected(session_id: int, reason: StringName)` |
| 信号 | [`drag_cancelled`](#member-gfdragdroputility-signals-drag_cancelled) | `signal drag_cancelled(session_id: int)` |
| 信号 | [`drop_zone_registered`](#member-gfdragdroputility-signals-drop_zone_registered) | `signal drop_zone_registered(zone_id: StringName)` |
| 信号 | [`drop_zone_unregistered`](#member-gfdragdroputility-signals-drop_zone_unregistered) | `signal drop_zone_unregistered(zone_id: StringName)` |
| 方法 | [`dispose`](#member-gfdragdroputility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_zone`](#member-gfdragdroputility-methods-register_zone) | `func register_zone(zone: GFDropZone) -> bool:` |
| 方法 | [`register_rect_zone`](#member-gfdragdroputility-methods-register_rect_zone) | `func register_rect_zone( zone_id: StringName, rect: Rect2, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |
| 方法 | [`register_control_zone`](#member-gfdragdroputility-methods-register_control_zone) | `func register_control_zone( zone_id: StringName, control: Control, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |
| 方法 | [`unregister_zone`](#member-gfdragdroputility-methods-unregister_zone) | `func unregister_zone(zone_id: StringName) -> bool:` |
| 方法 | [`get_zone`](#member-gfdragdroputility-methods-get_zone) | `func get_zone(zone_id: StringName) -> GFDropZone:` |
| 方法 | [`clear_zones`](#member-gfdragdroputility-methods-clear_zones) | `func clear_zones() -> void:` |
| 方法 | [`start_drag`](#member-gfdragdroputility-methods-start_drag) | `func start_drag( drag_type: StringName, payload: Variant, position: Vector2, source: Object = null, metadata: Dictionary = {} ) -> int:` |
| 方法 | [`update_drag`](#member-gfdragdroputility-methods-update_drag) | `func update_drag(session_id: int, position: Vector2) -> bool:` |
| 方法 | [`drop`](#member-gfdragdroputility-methods-drop) | `func drop(session_id: int, position: Vector2) -> Dictionary:` |
| 方法 | [`cancel_drag`](#member-gfdragdroputility-methods-cancel_drag) | `func cancel_drag(session_id: int) -> bool:` |
| 方法 | [`get_session`](#member-gfdragdroputility-methods-get_session) | `func get_session(session_id: int) -> GFDragSession:` |
| 方法 | [`has_active_session`](#member-gfdragdroputility-methods-has_active_session) | `func has_active_session(session_id: int) -> bool:` |
| 方法 | [`get_drop_candidates`](#member-gfdragdroputility-methods-get_drop_candidates) | `func get_drop_candidates( session_id: int, position: Vector2, only_accepting: bool = true ) -> Array[GFDropZone]:` |
| 方法 | [`get_best_drop_zone`](#member-gfdragdroputility-methods-get_best_drop_zone) | `func get_best_drop_zone(session_id: int, position: Vector2) -> GFDropZone:` |
| 方法 | [`clear_sessions`](#member-gfdragdroputility-methods-clear_sessions) | `func clear_sessions() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfdragdroputility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdragdroputility-signals-drag_started"></a>

### `drag_started`

- API：`public`

```gdscript
signal drag_started(session_id: int, drag_type: StringName)
```

拖拽开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `drag_type` | 拖拽类型。 |

<a id="member-gfdragdroputility-signals-drag_moved"></a>

### `drag_moved`

- API：`public`

```gdscript
signal drag_moved(session_id: int, position: Vector2, delta: Vector2)
```

拖拽位置更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 当前位置。 |
| `delta` | 本次位移。 |

<a id="member-gfdragdroputility-signals-drag_dropped"></a>

### `drag_dropped`

- API：`public`

```gdscript
signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)
```

拖拽成功释放到落点时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `zone_id` | 落点 ID。 |
| `result` | 落点返回结果。 |

结构：

- `result`: Dictionary，由 drop() 规范化，包含 ok、session_id、zone_id、reason 和可选 value。

<a id="member-gfdragdroputility-signals-drag_drop_rejected"></a>

### `drag_drop_rejected`

- API：`public`

```gdscript
signal drag_drop_rejected(session_id: int, reason: StringName)
```

拖拽释放被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `reason` | 拒绝原因。 |

<a id="member-gfdragdroputility-signals-drag_cancelled"></a>

### `drag_cancelled`

- API：`public`

```gdscript
signal drag_cancelled(session_id: int)
```

拖拽取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |

<a id="member-gfdragdroputility-signals-drop_zone_registered"></a>

### `drop_zone_registered`

- API：`public`

```gdscript
signal drop_zone_registered(zone_id: StringName)
```

落点注册后发出。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

<a id="member-gfdragdroputility-signals-drop_zone_unregistered"></a>

### `drop_zone_unregistered`

- API：`public`

```gdscript
signal drop_zone_unregistered(zone_id: StringName)
```

落点注销后发出。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

## 方法

<a id="member-gfdragdroputility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放拖拽工具持有的会话与落点。

<a id="member-gfdragdroputility-methods-register_zone"></a>

### `register_zone`

- API：`public`

```gdscript
func register_zone(zone: GFDropZone) -> bool:
```

注册落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone` | 落点规则。 |

返回：注册成功返回 true。

<a id="member-gfdragdroputility-methods-register_rect_zone"></a>

### `register_rect_zone`

- API：`public`

```gdscript
func register_rect_zone( zone_id: StringName, rect: Rect2, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:
```

注册矩形落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |
| `rect` | 全局矩形区域。 |
| `accepted_types` | 可接收类型；为空表示不限制。 |
| `options` | 可选参数，支持 priority、enabled、metadata、can_accept、drop。 |

返回：注册成功时返回落点，否则返回 null。

结构：

- `options`: Dictionary，透传给 GFDropZone.from_rect()。

<a id="member-gfdragdroputility-methods-register_control_zone"></a>

### `register_control_zone`

- API：`public`

```gdscript
func register_control_zone( zone_id: StringName, control: Control, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:
```

注册 Control 全局矩形落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |
| `control` | 用于读取 get_global_rect() 的 Control。 |
| `accepted_types` | 可接收类型；为空表示不限制。 |
| `options` | 可选参数，支持 priority、enabled、metadata、can_accept、drop。 |

返回：注册成功时返回落点，否则返回 null。

结构：

- `options`: Dictionary，透传给 GFDropZone.from_control()。

<a id="member-gfdragdroputility-methods-unregister_zone"></a>

### `unregister_zone`

- API：`public`

```gdscript
func unregister_zone(zone_id: StringName) -> bool:
```

注销落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfdragdroputility-methods-get_zone"></a>

### `get_zone`

- API：`public`

```gdscript
func get_zone(zone_id: StringName) -> GFDropZone:
```

获取落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

返回：落点；不存在时返回 null。

<a id="member-gfdragdroputility-methods-clear_zones"></a>

### `clear_zones`

- API：`public`

```gdscript
func clear_zones() -> void:
```

清空落点。

<a id="member-gfdragdroputility-methods-start_drag"></a>

### `start_drag`

- API：`public`

```gdscript
func start_drag( drag_type: StringName, payload: Variant, position: Vector2, source: Object = null, metadata: Dictionary = {} ) -> int:
```

开始拖拽。

参数：

| 名称 | 说明 |
|---|---|
| `drag_type` | 拖拽类型。 |
| `payload` | 项目自定义载荷。 |
| `position` | 起始位置。 |
| `source` | 可选来源对象。 |
| `metadata` | 项目自定义元数据。 |

返回：会话 ID；失败时返回 -1。

结构：

- `payload`: Variant，透传给 drop zone 的项目侧拖拽载荷。
- `metadata`: Dictionary，复制到拖拽会话中的项目侧元数据。

<a id="member-gfdragdroputility-methods-update_drag"></a>

### `update_drag`

- API：`public`

```gdscript
func update_drag(session_id: int, position: Vector2) -> bool:
```

更新拖拽位置。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 当前位置。 |

返回：更新成功返回 true。

<a id="member-gfdragdroputility-methods-drop"></a>

### `drop`

- API：`public`

```gdscript
func drop(session_id: int, position: Vector2) -> Dictionary:
```

将拖拽释放到当前位置匹配到的最佳落点。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 释放位置。 |

返回：结构化结果字典。

结构：

- `return`: Dictionary，包含 ok、session_id、zone_id、reason 和可选 value。

<a id="member-gfdragdroputility-methods-cancel_drag"></a>

### `cancel_drag`

- API：`public`

```gdscript
func cancel_drag(session_id: int) -> bool:
```

取消拖拽。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |

返回：找到并取消时返回 true。

<a id="member-gfdragdroputility-methods-get_session"></a>

### `get_session`

- API：`public`

```gdscript
func get_session(session_id: int) -> GFDragSession:
```

获取会话。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |

返回：会话；不存在时返回 null。

<a id="member-gfdragdroputility-methods-has_active_session"></a>

### `has_active_session`

- API：`public`

```gdscript
func has_active_session(session_id: int) -> bool:
```

检查会话是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |

返回：存在时返回 true。

<a id="member-gfdragdroputility-methods-get_drop_candidates"></a>

### `get_drop_candidates`

- API：`public`

```gdscript
func get_drop_candidates( session_id: int, position: Vector2, only_accepting: bool = true ) -> Array[GFDropZone]:
```

获取当前位置命中的落点候选。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 要检查的位置。 |
| `only_accepting` | 为 true 时只返回当前可接收会话的落点。 |

返回：按优先级排序的落点列表。

<a id="member-gfdragdroputility-methods-get_best_drop_zone"></a>

### `get_best_drop_zone`

- API：`public`

```gdscript
func get_best_drop_zone(session_id: int, position: Vector2) -> GFDropZone:
```

获取当前位置最佳落点。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 要检查的位置。 |

返回：最佳落点；没有可用落点时返回 null。

<a id="member-gfdragdroputility-methods-clear_sessions"></a>

### `clear_sessions`

- API：`public`

```gdscript
func clear_sessions() -> void:
```

清空拖拽会话。

<a id="member-gfdragdroputility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：当前拖拽与落点状态。

结构：

- `return`: Dictionary，包含 active_session_count、zone_count、sessions: Array[Dictionary] 和 zones: Array[Dictionary]。
