# GFDragDropController

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/drag_drop/gf_drag_drop_controller.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

可选拖放 Node 控制器。 在 `GFDragDropUtility` 的纯数据会话与落点规则之上，补充单指针捕获、source 生命周期、 可选拖拽层 reparent、取消和落点剪枝。它不解释 payload，不规定背包、棋盘、 卡牌或编辑器工具的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`drag_started`](#member-gfdragdropcontroller-signals-drag_started) | `signal drag_started(session_id: int, drag_type: StringName)` |
| 信号 | [`drag_moved`](#member-gfdragdropcontroller-signals-drag_moved) | `signal drag_moved(session_id: int, position: Vector2, delta: Vector2, zone_id: StringName)` |
| 信号 | [`drag_dropped`](#member-gfdragdropcontroller-signals-drag_dropped) | `signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)` |
| 信号 | [`drag_drop_rejected`](#member-gfdragdropcontroller-signals-drag_drop_rejected) | `signal drag_drop_rejected(session_id: int, reason: StringName)` |
| 信号 | [`drag_cancelled`](#member-gfdragdropcontroller-signals-drag_cancelled) | `signal drag_cancelled(session_id: int, reason: StringName)` |
| 信号 | [`drop_zone_registered`](#member-gfdragdropcontroller-signals-drop_zone_registered) | `signal drop_zone_registered(zone_id: StringName)` |
| 信号 | [`drop_zone_unregistered`](#member-gfdragdropcontroller-signals-drop_zone_unregistered) | `signal drop_zone_unregistered(zone_id: StringName)` |
| 属性 | [`cancel_when_source_exits_tree`](#member-gfdragdropcontroller-properties-cancel_when_source_exits_tree) | `var cancel_when_source_exits_tree: bool = true` |
| 属性 | [`cancel_when_source_freed`](#member-gfdragdropcontroller-properties-cancel_when_source_freed) | `var cancel_when_source_freed: bool = true` |
| 方法 | [`get_utility`](#member-gfdragdropcontroller-methods-get_utility) | `func get_utility() -> GFDragDropUtility:` |
| 方法 | [`register_zone`](#member-gfdragdropcontroller-methods-register_zone) | `func register_zone(zone: GFDropZone) -> bool:` |
| 方法 | [`register_rect_zone`](#member-gfdragdropcontroller-methods-register_rect_zone) | `func register_rect_zone( zone_id: StringName, rect: Rect2, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |
| 方法 | [`register_control_zone`](#member-gfdragdropcontroller-methods-register_control_zone) | `func register_control_zone( zone_id: StringName, control: Control, accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |
| 方法 | [`unregister_zone`](#member-gfdragdropcontroller-methods-unregister_zone) | `func unregister_zone(zone_id: StringName) -> bool:` |
| 方法 | [`prune_stale_drop_zones`](#member-gfdragdropcontroller-methods-prune_stale_drop_zones) | `func prune_stale_drop_zones() -> int:` |
| 方法 | [`clear_zones`](#member-gfdragdropcontroller-methods-clear_zones) | `func clear_zones() -> void:` |
| 方法 | [`start_drag`](#member-gfdragdropcontroller-methods-start_drag) | `func start_drag( drag_type: StringName, payload: Variant, position: Vector2, source: Object = null, options: Dictionary = {} ) -> int:` |
| 方法 | [`update_pointer`](#member-gfdragdropcontroller-methods-update_pointer) | `func update_pointer(position: Vector2, pointer_id: int = 0) -> bool:` |
| 方法 | [`get_active_drop_candidates`](#member-gfdragdropcontroller-methods-get_active_drop_candidates) | `func get_active_drop_candidates(position: Vector2, only_accepting: bool = true) -> Array[GFDropZone]:` |
| 方法 | [`get_active_best_drop_zone`](#member-gfdragdropcontroller-methods-get_active_best_drop_zone) | `func get_active_best_drop_zone(position: Vector2) -> GFDropZone:` |
| 方法 | [`drop`](#member-gfdragdropcontroller-methods-drop) | `func drop(position: Vector2, pointer_id: int = 0) -> Dictionary:` |
| 方法 | [`cancel_drag`](#member-gfdragdropcontroller-methods-cancel_drag) | `func cancel_drag(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_active_session`](#member-gfdragdropcontroller-methods-get_active_session) | `func get_active_session() -> GFDragSession:` |
| 方法 | [`get_active_session_id`](#member-gfdragdropcontroller-methods-get_active_session_id) | `func get_active_session_id() -> int:` |
| 方法 | [`has_active_drag`](#member-gfdragdropcontroller-methods-has_active_drag) | `func has_active_drag() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfdragdropcontroller-methods-get_debug_snapshot) | `func get_debug_snapshot(json_compatible: bool = true) -> Dictionary:` |

## 信号

<a id="member-gfdragdropcontroller-signals-drag_started"></a>

### `drag_started`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drag_started(session_id: int, drag_type: StringName)
```

控制器已提交 session、pointer、source 监听和可选 reparent 后同步发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `drag_type` | 拖拽类型。 |

<a id="member-gfdragdropcontroller-signals-drag_moved"></a>

### `drag_moved`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drag_moved(session_id: int, position: Vector2, delta: Vector2, zone_id: StringName)
```

拖拽位置更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `position` | 当前位置。 |
| `delta` | 本次位移。 |
| `zone_id` | 当前最佳落点 ID；没有落点时为空。 |

<a id="member-gfdragdropcontroller-signals-drag_dropped"></a>

### `drag_dropped`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)
```

旧会话的 pointer/source/reparent lease 已清理后同步发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `zone_id` | 落点 ID。 |
| `result` | 落点返回结果。 |

结构：

- `result`: Dictionary，由 GFDragDropUtility.drop() 规范化，包含 ok、session_id、zone_id、reason 和可选 value。

<a id="member-gfdragdropcontroller-signals-drag_drop_rejected"></a>

### `drag_drop_rejected`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drag_drop_rejected(session_id: int, reason: StringName)
```

拖拽释放被拒绝时发出；终态拒绝会先清理旧 lease，可重试拒绝仍保留会话。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `reason` | 拒绝原因。 |

<a id="member-gfdragdropcontroller-signals-drag_cancelled"></a>

### `drag_cancelled`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drag_cancelled(session_id: int, reason: StringName)
```

旧会话的 pointer/source/reparent lease 已清理后同步发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 会话 ID。 |
| `reason` | 取消原因。 |

<a id="member-gfdragdropcontroller-signals-drop_zone_registered"></a>

### `drop_zone_registered`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drop_zone_registered(zone_id: StringName)
```

落点注册后发出。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

<a id="member-gfdragdropcontroller-signals-drop_zone_unregistered"></a>

### `drop_zone_unregistered`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal drop_zone_unregistered(zone_id: StringName)
```

落点注销后发出。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

## 属性

<a id="member-gfdragdropcontroller-properties-cancel_when_source_exits_tree"></a>

### `cancel_when_source_exits_tree`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var cancel_when_source_exits_tree: bool = true
```

source 离开场景树时是否自动取消当前拖拽。

<a id="member-gfdragdropcontroller-properties-cancel_when_source_freed"></a>

### `cancel_when_source_freed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var cancel_when_source_freed: bool = true
```

source 引用失效时是否自动取消当前拖拽。

## 方法

<a id="member-gfdragdropcontroller-methods-get_utility"></a>

### `get_utility`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_utility() -> GFDragDropUtility:
```

获取底层拖放数据工具。 返回值是可写 live Utility；直接调用其 update/drop/cancel 会绕过控制器的 pointer 校验，但底层终态信号仍会驱动控制器清理。需要强制 pointer authority 时只使用控制器命令入口。

返回：当前控制器持有的拖放工具。

<a id="member-gfdragdropcontroller-methods-register_zone"></a>

### `register_zone`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_zone(zone: GFDropZone) -> bool:
```

注册落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone` | 落点规则。 |

返回：注册成功返回 true。

<a id="member-gfdragdropcontroller-methods-register_rect_zone"></a>

### `register_rect_zone`

- API：`public`
- 首次版本：`8.0.0`

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

<a id="member-gfdragdropcontroller-methods-register_control_zone"></a>

### `register_control_zone`

- API：`public`
- 首次版本：`8.0.0`

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

<a id="member-gfdragdropcontroller-methods-unregister_zone"></a>

### `unregister_zone`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_zone(zone_id: StringName) -> bool:
```

注销落点。

参数：

| 名称 | 说明 |
|---|---|
| `zone_id` | 落点 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfdragdropcontroller-methods-prune_stale_drop_zones"></a>

### `prune_stale_drop_zones`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prune_stale_drop_zones() -> int:
```

主动剪枝已失效的落点。

返回：本次移除的落点数量。

<a id="member-gfdragdropcontroller-methods-clear_zones"></a>

### `clear_zones`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_zones() -> void:
```

清空落点。

<a id="member-gfdragdropcontroller-methods-start_drag"></a>

### `start_drag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func start_drag( drag_type: StringName, payload: Variant, position: Vector2, source: Object = null, options: Dictionary = {} ) -> int:
```

开始由控制器管理的拖拽。 控制器一次只管理一个活动会话。需要并行拖拽时可创建多个控制器；底层 `GFDragDropUtility` 仍保留多会话能力。 started 只观察完整提交状态；若 started 监听器同步结束本会话，本方法返回 -1。

参数：

| 名称 | 说明 |
|---|---|
| `drag_type` | 拖拽类型。 |
| `payload` | 项目自定义载荷。 |
| `position` | 起始位置。 |
| `source` | 可选来源对象。 |
| `options` | 控制器选项。 |

返回：仍保持活动的会话 ID；启动失败或 started 回调已结束会话时返回 -1。

结构：

- `payload`: Variant，透传给 drop zone 的项目侧拖拽载荷。
- `options`: Dictionary，可包含 metadata: Dictionary、pointer_id: int、capture_pointer: bool、drag_parent: Node、keep_global_transform: bool、restore_source_parent_on_cancel: bool、restore_source_parent_on_rejected_drop: bool、restore_source_parent_on_success: bool。

<a id="member-gfdragdropcontroller-methods-update_pointer"></a>

### `update_pointer`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func update_pointer(position: Vector2, pointer_id: int = 0) -> bool:
```

更新活动拖拽的指针位置。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 当前指针位置。 |
| `pointer_id` | 发起更新的指针 ID。 |

返回：更新成功返回 true。

<a id="member-gfdragdropcontroller-methods-get_active_drop_candidates"></a>

### `get_active_drop_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_active_drop_candidates(position: Vector2, only_accepting: bool = true) -> Array[GFDropZone]:
```

获取活动拖拽在当前位置命中的落点候选。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 要检查的位置。 |
| `only_accepting` | 为 true 时只返回当前可接收会话的落点。 |

返回：按优先级排序的落点列表。

<a id="member-gfdragdropcontroller-methods-get_active_best_drop_zone"></a>

### `get_active_best_drop_zone`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_active_best_drop_zone(position: Vector2) -> GFDropZone:
```

获取活动拖拽在当前位置的最佳落点。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 要检查的位置。 |

返回：最佳落点；没有可用落点时返回 null。

<a id="member-gfdragdropcontroller-methods-drop"></a>

### `drop`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func drop(position: Vector2, pointer_id: int = 0) -> Dictionary:
```

将活动拖拽释放到指定位置。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 释放位置。 |
| `pointer_id` | 发起释放的指针 ID。 |

返回：结构化结果字典。

结构：

- `return`: Dictionary，包含 ok、session_id、zone_id、reason 和可选 value。

<a id="member-gfdragdropcontroller-methods-cancel_drag"></a>

### `cancel_drag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel_drag(reason: StringName = &"cancelled") -> bool:
```

取消活动拖拽。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：找到并取消时返回 true。

<a id="member-gfdragdropcontroller-methods-get_active_session"></a>

### `get_active_session`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_active_session() -> GFDragSession:
```

获取活动会话。

返回：活动会话；没有活动拖拽时返回 null。

<a id="member-gfdragdropcontroller-methods-get_active_session_id"></a>

### `get_active_session_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_active_session_id() -> int:
```

获取活动会话 ID。

返回：活动会话 ID；没有活动拖拽时返回 -1。

<a id="member-gfdragdropcontroller-methods-has_active_drag"></a>

### `has_active_drag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_active_drag() -> bool:
```

检查控制器是否有活动拖拽。

返回：存在活动拖拽时返回 true。

<a id="member-gfdragdropcontroller-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot(json_compatible: bool = true) -> Dictionary:
```

获取调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时返回可直接 JSON.stringify() 的值。 |

返回：当前控制器状态。

结构：

- `return`: Dictionary，包含 active_session_id、pointer_capture、has_source、source_inside_tree 和 utility。
