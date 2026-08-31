# GFSpatialCanvas2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_2d.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

有界运行时 2D 空间交互画布。 统一管理画布视图、世界/画布/格子坐标转换、显式条目查询、稳定选择和项目校验的 放置会话。项目仍拥有内容节点、占位与权限规则、业务命令、存档和网络同步。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`view_changed`](#member-gfspatialcanvas2d-signals-view_changed) | `signal view_changed(snapshot: Dictionary)` |
| 信号 | [`selection_changed`](#member-gfspatialcanvas2d-signals-selection_changed) | `signal selection_changed(selected_ids: PackedStringArray)` |
| 信号 | [`placement_started`](#member-gfspatialcanvas2d-signals-placement_started) | `signal placement_started(snapshot: Dictionary)` |
| 信号 | [`placement_preview_changed`](#member-gfspatialcanvas2d-signals-placement_preview_changed) | `signal placement_preview_changed(snapshot: Dictionary)` |
| 信号 | [`placement_committed`](#member-gfspatialcanvas2d-signals-placement_committed) | `signal placement_committed(report: Dictionary)` |
| 信号 | [`placement_cancelled`](#member-gfspatialcanvas2d-signals-placement_cancelled) | `signal placement_cancelled(report: Dictionary)` |
| 信号 | [`history_operation_requested`](#member-gfspatialcanvas2d-signals-history_operation_requested) | `signal history_operation_requested(operation: Dictionary)` |
| 枚举 | [`SelectionMode`](#member-gfspatialcanvas2d-enums-selectionmode) | `enum SelectionMode` |
| 枚举 | [`InputDisposition`](#member-gfspatialcanvas2d-enums-inputdisposition) | `enum InputDisposition` |
| 常量 | [`ABSOLUTE_MAX_ITEMS`](#member-gfspatialcanvas2d-constants-absolute_max_items) | `const ABSOLUTE_MAX_ITEMS: int = 65536` |
| 常量 | [`ABSOLUTE_MAX_SELECTION`](#member-gfspatialcanvas2d-constants-absolute_max_selection) | `const ABSOLUTE_MAX_SELECTION: int = 16384` |
| 常量 | [`ABSOLUTE_MAX_QUERY_CANDIDATES`](#member-gfspatialcanvas2d-constants-absolute_max_query_candidates) | `const ABSOLUTE_MAX_QUERY_CANDIDATES: int = 16384` |
| 常量 | [`ABSOLUTE_MAX_GRID_LINES`](#member-gfspatialcanvas2d-constants-absolute_max_grid_lines) | `const ABSOLUTE_MAX_GRID_LINES: int = 2048` |
| 方法 | [`get_content_root`](#member-gfspatialcanvas2d-methods-get_content_root) | `func get_content_root() -> Node2D:` |
| 方法 | [`set_view`](#member-gfspatialcanvas2d-methods-set_view) | `func set_view(world_center: Vector2, zoom: float) -> bool:` |
| 方法 | [`get_world_center`](#member-gfspatialcanvas2d-methods-get_world_center) | `func get_world_center() -> Vector2:` |
| 方法 | [`get_zoom`](#member-gfspatialcanvas2d-methods-get_zoom) | `func get_zoom() -> float:` |
| 方法 | [`set_zoom_limits`](#member-gfspatialcanvas2d-methods-set_zoom_limits) | `func set_zoom_limits(minimum_zoom: float, maximum_zoom: float) -> bool:` |
| 方法 | [`set_world_bounds`](#member-gfspatialcanvas2d-methods-set_world_bounds) | `func set_world_bounds(bounds: Rect2, enabled: bool = true) -> bool:` |
| 方法 | [`pan_by_canvas_delta`](#member-gfspatialcanvas2d-methods-pan_by_canvas_delta) | `func pan_by_canvas_delta(canvas_delta: Vector2) -> bool:` |
| 方法 | [`zoom_at`](#member-gfspatialcanvas2d-methods-zoom_at) | `func zoom_at(canvas_position: Vector2, factor: float) -> bool:` |
| 方法 | [`focus_world_rect`](#member-gfspatialcanvas2d-methods-focus_world_rect) | `func focus_world_rect(world_rect: Rect2, canvas_margin: float = 0.0) -> bool:` |
| 方法 | [`world_to_canvas`](#member-gfspatialcanvas2d-methods-world_to_canvas) | `func world_to_canvas(world_position: Vector2) -> Vector2:` |
| 方法 | [`canvas_to_world`](#member-gfspatialcanvas2d-methods-canvas_to_world) | `func canvas_to_world(canvas_position: Vector2) -> Vector2:` |
| 方法 | [`world_to_screen`](#member-gfspatialcanvas2d-methods-world_to_screen) | `func world_to_screen(world_position: Vector2) -> Vector2:` |
| 方法 | [`screen_to_world`](#member-gfspatialcanvas2d-methods-screen_to_world) | `func screen_to_world(screen_position: Vector2) -> Vector2:` |
| 方法 | [`get_visible_world_rect`](#member-gfspatialcanvas2d-methods-get_visible_world_rect) | `func get_visible_world_rect() -> Rect2:` |
| 方法 | [`configure_grid`](#member-gfspatialcanvas2d-methods-configure_grid) | `func configure_grid( origin: Vector2, cell_size: Vector2, options: Dictionary = {} ) -> bool:` |
| 方法 | [`get_grid_origin`](#member-gfspatialcanvas2d-methods-get_grid_origin) | `func get_grid_origin() -> Vector2:` |
| 方法 | [`get_grid_size`](#member-gfspatialcanvas2d-methods-get_grid_size) | `func get_grid_size() -> Vector2:` |
| 方法 | [`world_to_cell`](#member-gfspatialcanvas2d-methods-world_to_cell) | `func world_to_cell(world_position: Vector2) -> Vector2i:` |
| 方法 | [`cell_to_world`](#member-gfspatialcanvas2d-methods-cell_to_world) | `func cell_to_world(cell: Vector2i, use_center: bool = false) -> Vector2:` |
| 方法 | [`snap_world_position`](#member-gfspatialcanvas2d-methods-snap_world_position) | `func snap_world_position(world_position: Vector2) -> Vector2:` |
| 方法 | [`snap_rotation`](#member-gfspatialcanvas2d-methods-snap_rotation) | `func snap_rotation(rotation_radians: float) -> float:` |
| 方法 | [`configure_budgets`](#member-gfspatialcanvas2d-methods-configure_budgets) | `func configure_budgets(options: Dictionary) -> bool:` |
| 方法 | [`upsert_item`](#member-gfspatialcanvas2d-methods-upsert_item) | `func upsert_item( item_id: StringName, world_bounds: Rect2, options: Dictionary = {} ) -> bool:` |
| 方法 | [`remove_item`](#member-gfspatialcanvas2d-methods-remove_item) | `func remove_item(item_id: StringName) -> bool:` |
| 方法 | [`clear_items`](#member-gfspatialcanvas2d-methods-clear_items) | `func clear_items() -> void:` |
| 方法 | [`get_item`](#member-gfspatialcanvas2d-methods-get_item) | `func get_item(item_id: StringName) -> Dictionary:` |
| 方法 | [`query_items_at`](#member-gfspatialcanvas2d-methods-query_items_at) | `func query_items_at(world_position: Vector2) -> PackedStringArray:` |
| 方法 | [`query_items_in_rect`](#member-gfspatialcanvas2d-methods-query_items_in_rect) | `func query_items_in_rect( world_rect: Rect2, fully_contained: bool = false ) -> PackedStringArray:` |
| 方法 | [`set_selection`](#member-gfspatialcanvas2d-methods-set_selection) | `func set_selection( item_ids: PackedStringArray, mode: SelectionMode = SelectionMode.REPLACE ) -> PackedStringArray:` |
| 方法 | [`select_point`](#member-gfspatialcanvas2d-methods-select_point) | `func select_point( canvas_position: Vector2, mode: SelectionMode = SelectionMode.REPLACE ) -> PackedStringArray:` |
| 方法 | [`select_rect`](#member-gfspatialcanvas2d-methods-select_rect) | `func select_rect( canvas_rect: Rect2, mode: SelectionMode = SelectionMode.REPLACE, fully_contained: bool = false ) -> PackedStringArray:` |
| 方法 | [`clear_selection`](#member-gfspatialcanvas2d-methods-clear_selection) | `func clear_selection() -> void:` |
| 方法 | [`get_selection`](#member-gfspatialcanvas2d-methods-get_selection) | `func get_selection() -> PackedStringArray:` |
| 方法 | [`set_placement_validator`](#member-gfspatialcanvas2d-methods-set_placement_validator) | `func set_placement_validator(callback: Callable) -> void:` |
| 方法 | [`set_history_hook`](#member-gfspatialcanvas2d-methods-set_history_hook) | `func set_history_hook(callback: Callable) -> void:` |
| 方法 | [`begin_placement`](#member-gfspatialcanvas2d-methods-begin_placement) | `func begin_placement( type_id: StringName, footprint: Rect2, options: Dictionary = {} ) -> int:` |
| 方法 | [`update_placement`](#member-gfspatialcanvas2d-methods-update_placement) | `func update_placement( world_position: Vector2, options: Dictionary = {} ) -> bool:` |
| 方法 | [`commit_placement`](#member-gfspatialcanvas2d-methods-commit_placement) | `func commit_placement() -> Dictionary:` |
| 方法 | [`cancel_placement`](#member-gfspatialcanvas2d-methods-cancel_placement) | `func cancel_placement(reason: StringName = &"cancelled") -> Dictionary:` |
| 方法 | [`has_active_placement`](#member-gfspatialcanvas2d-methods-has_active_placement) | `func has_active_placement() -> bool:` |
| 方法 | [`get_placement_snapshot`](#member-gfspatialcanvas2d-methods-get_placement_snapshot) | `func get_placement_snapshot() -> Dictionary:` |
| 方法 | [`set_input_policy`](#member-gfspatialcanvas2d-methods-set_input_policy) | `func set_input_policy(policy: GFSpatialCanvasInputPolicy) -> bool:` |
| 方法 | [`get_input_policy`](#member-gfspatialcanvas2d-methods-get_input_policy) | `func get_input_policy() -> GFSpatialCanvasInputPolicy:` |
| 方法 | [`handle_input_event`](#member-gfspatialcanvas2d-methods-handle_input_event) | `func handle_input_event(event: InputEvent) -> InputDisposition:` |
| 方法 | [`handle_screen_input_event`](#member-gfspatialcanvas2d-methods-handle_screen_input_event) | `func handle_screen_input_event(event: InputEvent) -> InputDisposition:` |
| 方法 | [`set_input_enabled`](#member-gfspatialcanvas2d-methods-set_input_enabled) | `func set_input_enabled(enabled: bool) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfspatialcanvas2d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfspatialcanvas2d-signals-view_changed"></a>

### `view_changed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal view_changed(snapshot: Dictionary)
```

视图状态变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 隔离的视图快照。 |

结构：

- `snapshot`: Dictionary，包含 world_center、zoom、visible_world_rect、world_bounds_enabled 和 world_bounds。

<a id="member-gfspatialcanvas2d-signals-selection_changed"></a>

### `selection_changed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal selection_changed(selected_ids: PackedStringArray)
```

选择集合变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `selected_ids` | 稳定条目 ID 的隔离副本。 |

<a id="member-gfspatialcanvas2d-signals-placement_started"></a>

### `placement_started`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal placement_started(snapshot: Dictionary)
```

放置会话开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 放置预览的隔离副本。 |

结构：

- `snapshot`: Dictionary，包含 session_id、type_id、footprint、world_position、rotation_radians、world_bounds、snap_to_grid 和 snap_rotation。

<a id="member-gfspatialcanvas2d-signals-placement_preview_changed"></a>

### `placement_preview_changed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal placement_preview_changed(snapshot: Dictionary)
```

放置预览变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 放置预览的隔离副本。 |

结构：

- `snapshot`: Dictionary，结构与 placement_started 相同。

<a id="member-gfspatialcanvas2d-signals-placement_committed"></a>

### `placement_committed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal placement_committed(report: Dictionary)
```

放置会话成功冻结通用操作记录时发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 成功提交报告的隔离副本。 |

结构：

- `report`: Dictionary，包含 ok、reason、session_id 和 operation。

<a id="member-gfspatialcanvas2d-signals-placement_cancelled"></a>

### `placement_cancelled`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal placement_cancelled(report: Dictionary)
```

放置会话取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 取消报告的隔离副本。 |

结构：

- `report`: Dictionary，包含 ok、reason、session_id 和 preview。

<a id="member-gfspatialcanvas2d-signals-history_operation_requested"></a>

### `history_operation_requested`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal history_operation_requested(operation: Dictionary)
```

历史 Hook 接受放置操作后发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 通用放置操作记录的隔离副本。 |

结构：

- `operation`: Dictionary，包含 schema_version、operation、session_id、type_id、footprint、world_position、rotation_radians 和 world_bounds。

## 枚举

<a id="member-gfspatialcanvas2d-enums-selectionmode"></a>

### `SelectionMode`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
enum SelectionMode {
	## 用候选替换当前选择。
	REPLACE,
	## 把候选加入当前选择。
	ADD,
	## 切换每个候选的选择状态。
	TOGGLE,
	## 从当前选择移除候选。
	SUBTRACT,
}
```

选择集合更新模式。

<a id="member-gfspatialcanvas2d-enums-inputdisposition"></a>

### `InputDisposition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum InputDisposition {
	## 事件未被画布识别或当前策略要求继续交给其他接收者。
	IGNORED,
	## 事件已更新画布，但仍允许 GUI 冒泡。
	HANDLED,
	## 事件已更新画布，并应在 GUI 边界停止传播。
	CONSUMED,
}
```

输入处理结果。 手工转发调用只观察该返回值；只有 [constant InputDisposition.CONSUMED] 会让画布自身的 [code]_gui_input()[/code] 调用 [method Control.accept_event]。

## 常量

<a id="member-gfspatialcanvas2d-constants-absolute_max_items"></a>

### `ABSOLUTE_MAX_ITEMS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_ITEMS: int = 65536
```

单个画布允许登记的条目绝对上限。

<a id="member-gfspatialcanvas2d-constants-absolute_max_selection"></a>

### `ABSOLUTE_MAX_SELECTION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_SELECTION: int = 16384
```

单个画布允许保留的选择绝对上限。

<a id="member-gfspatialcanvas2d-constants-absolute_max_query_candidates"></a>

### `ABSOLUTE_MAX_QUERY_CANDIDATES`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_QUERY_CANDIDATES: int = 16384
```

单次查询允许进入精确命中与结果窗口的候选绝对上限。

<a id="member-gfspatialcanvas2d-constants-absolute_max_grid_lines"></a>

### `ABSOLUTE_MAX_GRID_LINES`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_GRID_LINES: int = 2048
```

单次绘制允许生成的网格线绝对上限。

## 方法

<a id="member-gfspatialcanvas2d-methods-get_content_root"></a>

### `get_content_root`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_content_root() -> Node2D:
```

获取承载项目 2D 内容的根节点。 GF 只更新该节点的位置与缩放，不扫描、重挂或主动释放项目子节点。

返回：画布拥有的内容根。

<a id="member-gfspatialcanvas2d-methods-set_view"></a>

### `set_view`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_view(world_center: Vector2, zoom: float) -> bool:
```

原子设置世界中心与缩放。

参数：

| 名称 | 说明 |
|---|---|
| `world_center` | 目标世界中心。 |
| `zoom` | 每个世界单位对应的画布缩放。 |

返回：输入有限且缩放有效时返回 true。

<a id="member-gfspatialcanvas2d-methods-get_world_center"></a>

### `get_world_center`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_world_center() -> Vector2:
```

获取当前世界中心。

返回：当前世界中心。

<a id="member-gfspatialcanvas2d-methods-get_zoom"></a>

### `get_zoom`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_zoom() -> float:
```

获取当前缩放。

返回：当前缩放。

<a id="member-gfspatialcanvas2d-methods-set_zoom_limits"></a>

### `set_zoom_limits`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_zoom_limits(minimum_zoom: float, maximum_zoom: float) -> bool:
```

原子设置缩放上下限。

参数：

| 名称 | 说明 |
|---|---|
| `minimum_zoom` | 最小缩放。 |
| `maximum_zoom` | 最大缩放。 |

返回：范围有限、为正且未突破绝对限制时返回 true。

<a id="member-gfspatialcanvas2d-methods-set_world_bounds"></a>

### `set_world_bounds`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_world_bounds(bounds: Rect2, enabled: bool = true) -> bool:
```

设置可选世界边界。

参数：

| 名称 | 说明 |
|---|---|
| `bounds` | 有效世界矩形。 |
| `enabled` | 是否启用中心约束。 |

返回：边界有限且启用时具有正面积，或显式禁用时返回 true。

<a id="member-gfspatialcanvas2d-methods-pan_by_canvas_delta"></a>

### `pan_by_canvas_delta`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func pan_by_canvas_delta(canvas_delta: Vector2) -> bool:
```

按画布像素增量平移内容。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_delta` | 指针在画布空间的移动量。 |

返回：输入有效时返回 true。

<a id="member-gfspatialcanvas2d-methods-zoom_at"></a>

### `zoom_at`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func zoom_at(canvas_position: Vector2, factor: float) -> bool:
```

围绕指定画布焦点缩放。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_position` | 缩放焦点。 |
| `factor` | 相对缩放因子。 |

返回：输入有限且 factor 为正时返回 true。

<a id="member-gfspatialcanvas2d-methods-focus_world_rect"></a>

### `focus_world_rect`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func focus_world_rect(world_rect: Rect2, canvas_margin: float = 0.0) -> bool:
```

让世界矩形适配当前画布。

参数：

| 名称 | 说明 |
|---|---|
| `world_rect` | 目标世界矩形。 |
| `canvas_margin` | 画布四周保留的像素边距。 |

返回：输入和当前画布尺寸有效时返回 true。

<a id="member-gfspatialcanvas2d-methods-world_to_canvas"></a>

### `world_to_canvas`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func world_to_canvas(world_position: Vector2) -> Vector2:
```

把世界坐标转换为本 Control 的画布坐标。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |

返回：对应画布坐标；非法输入返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-canvas_to_world"></a>

### `canvas_to_world`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func canvas_to_world(canvas_position: Vector2) -> Vector2:
```

把本 Control 的画布坐标转换为世界坐标。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_position` | 画布坐标。 |

返回：对应世界坐标；非法输入返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-world_to_screen"></a>

### `world_to_screen`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func world_to_screen(world_position: Vector2) -> Vector2:
```

把世界坐标转换为 Viewport 屏幕坐标。 该转换包含本 Control 及其 CanvasLayer/父级的画布变换。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |

返回：对应 Viewport 屏幕坐标；输入或派生结果非法时返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-screen_to_world"></a>

### `screen_to_world`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func screen_to_world(screen_position: Vector2) -> Vector2:
```

把 Viewport 屏幕坐标转换为世界坐标。 该转换包含本 Control 及其 CanvasLayer/父级的画布变换。

参数：

| 名称 | 说明 |
|---|---|
| `screen_position` | Viewport 屏幕坐标。 |

返回：对应世界坐标；输入或画布变换不可逆时返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-get_visible_world_rect"></a>

### `get_visible_world_rect`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_visible_world_rect() -> Rect2:
```

获取当前可见世界矩形。

返回：当前画布对应的世界矩形。

<a id="member-gfspatialcanvas2d-methods-configure_grid"></a>

### `configure_grid`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure_grid( origin: Vector2, cell_size: Vector2, options: Dictionary = {} ) -> bool:
```

原子配置网格。

参数：

| 名称 | 说明 |
|---|---|
| `origin` | 网格原点。 |
| `cell_size` | 单元尺寸，两个分量都必须大于 0。 |
| `options` | 可选旋转步长与可见性。 |

返回：配置有效时返回 true。

结构：

- `options`: Dictionary，可包含 rotation_step_radians: float 和 visible: bool。

<a id="member-gfspatialcanvas2d-methods-get_grid_origin"></a>

### `get_grid_origin`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_grid_origin() -> Vector2:
```

获取网格原点。

返回：当前网格原点。

<a id="member-gfspatialcanvas2d-methods-get_grid_size"></a>

### `get_grid_size`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_grid_size() -> Vector2:
```

获取单元尺寸。

返回：当前网格尺寸。

<a id="member-gfspatialcanvas2d-methods-world_to_cell"></a>

### `world_to_cell`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func world_to_cell(world_position: Vector2) -> Vector2i:
```

将世界坐标转换为格坐标。 负坐标使用 floor 语义。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |

返回：格坐标；非法输入返回 Vector2i.ZERO。

<a id="member-gfspatialcanvas2d-methods-cell_to_world"></a>

### `cell_to_world`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func cell_to_world(cell: Vector2i, use_center: bool = false) -> Vector2:
```

将格坐标转换为世界坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `use_center` | 为 true 时返回格子中心，否则返回格子原点。 |

返回：对应世界坐标；派生结果非有限时返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-snap_world_position"></a>

### `snap_world_position`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func snap_world_position(world_position: Vector2) -> Vector2:
```

把世界坐标吸附到最近网格交点。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 待吸附坐标。 |

返回：吸附坐标；非法输入返回 Vector2.ZERO。

<a id="member-gfspatialcanvas2d-methods-snap_rotation"></a>

### `snap_rotation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func snap_rotation(rotation_radians: float) -> float:
```

按网格旋转步长吸附角度。

参数：

| 名称 | 说明 |
|---|---|
| `rotation_radians` | 弧度角。 |

返回：规范化吸附角；未配置步长时只规范化输入，非有限输入返回 0.0。

<a id="member-gfspatialcanvas2d-methods-configure_budgets"></a>

### `configure_budgets`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure_budgets(options: Dictionary) -> bool:
```

原子配置实例预算。 所有值都只能在 1 与对应绝对上限之间。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 预算选项。 |

返回：所有提供值都有效且不会低于当前状态占用时返回 true。

结构：

- `options`: Dictionary，可包含 max_items、max_selection、max_query_candidates 和 max_grid_lines。

<a id="member-gfspatialcanvas2d-methods-upsert_item"></a>

### `upsert_item`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func upsert_item( item_id: StringName, world_bounds: Rect2, options: Dictionary = {} ) -> bool:
```

插入或更新一个稳定空间条目。 条目只保存 ID、有限 AABB、是否可选、选择优先级和可选同步精确命中 Hook。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 稳定条目标识。 |
| `world_bounds` | 世界空间 AABB。 |
| `options` | 通用选择选项。 |

返回：插入或更新成功时返回 true。

结构：

- `options`: Dictionary，可包含 selectable: bool、selection_priority: int 和 exact_hit: Callable(item_id, world_point, bounds) -> bool。

<a id="member-gfspatialcanvas2d-methods-remove_item"></a>

### `remove_item`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func remove_item(item_id: StringName) -> bool:
```

移除条目并同步剔除选择。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

返回：找到并移除时返回 true。

<a id="member-gfspatialcanvas2d-methods-clear_items"></a>

### `clear_items`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_items() -> void:
```

清空条目和选择。

<a id="member-gfspatialcanvas2d-methods-get_item"></a>

### `get_item`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_item(item_id: StringName) -> Dictionary:
```

获取不含回调的条目快照。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 条目标识。 |

返回：包含 id、bounds、selectable 和 selection_priority 的字典；不存在时为空。

结构：

- `return`: Dictionary，包含 id、bounds、selectable 和 selection_priority。

<a id="member-gfspatialcanvas2d-methods-query_items_at"></a>

### `query_items_at`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func query_items_at(world_position: Vector2) -> PackedStringArray:
```

查询包含世界点的条目。 候选先以有界 top-K 保留全局 selection_priority 最高、稳定 ID 最小的窗口， 再在预算内执行 exact_hit。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |

返回：匹配的稳定 ID。

<a id="member-gfspatialcanvas2d-methods-query_items_in_rect"></a>

### `query_items_in_rect`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func query_items_in_rect( world_rect: Rect2, fully_contained: bool = false ) -> PackedStringArray:
```

查询与世界矩形相交的条目。

参数：

| 名称 | 说明 |
|---|---|
| `world_rect` | 世界查询矩形。 |
| `fully_contained` | 为 true 时只保留完全位于矩形内的条目。 |

返回：匹配的稳定 ID。

<a id="member-gfspatialcanvas2d-methods-set_selection"></a>

### `set_selection`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_selection( item_ids: PackedStringArray, mode: SelectionMode = SelectionMode.REPLACE ) -> PackedStringArray:
```

按模式更新选择。 只接受已登记且可选的稳定 ID；容量只限制替换或新增，不截断减去候选。

参数：

| 名称 | 说明 |
|---|---|
| `item_ids` | 候选条目 ID。 |
| `mode` | [enum SelectionMode] 值。 |

返回：更新后的隔离选择副本。

<a id="member-gfspatialcanvas2d-methods-select_point"></a>

### `select_point`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func select_point( canvas_position: Vector2, mode: SelectionMode = SelectionMode.REPLACE ) -> PackedStringArray:
```

在画布坐标点选最高优先级条目。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_position` | 本 Control 的画布坐标。 |
| `mode` | [enum SelectionMode] 值。 |

返回：更新后的选择。

<a id="member-gfspatialcanvas2d-methods-select_rect"></a>

### `select_rect`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func select_rect( canvas_rect: Rect2, mode: SelectionMode = SelectionMode.REPLACE, fully_contained: bool = false ) -> PackedStringArray:
```

在画布坐标框选条目。

参数：

| 名称 | 说明 |
|---|---|
| `canvas_rect` | 画布选择矩形。 |
| `mode` | [enum SelectionMode] 值。 |
| `fully_contained` | 为 true 时只选择完全位于矩形内的条目。 |

返回：更新后的选择。

<a id="member-gfspatialcanvas2d-methods-clear_selection"></a>

### `clear_selection`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_selection() -> void:
```

清空选择。

<a id="member-gfspatialcanvas2d-methods-get_selection"></a>

### `get_selection`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_selection() -> PackedStringArray:
```

获取选择集合隔离副本。

返回：稳定 ID 列表。

<a id="member-gfspatialcanvas2d-methods-set_placement_validator"></a>

### `set_placement_validator`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_placement_validator(callback: Callable) -> void:
```

设置项目同步放置校验器。 回调签名为 Callable(preview: Dictionary) -> bool 或 Dictionary。Dictionary 应包含 ok， 可选 reason。空 Callable 表示不追加项目校验。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 受信同步校验回调。 |

<a id="member-gfspatialcanvas2d-methods-set_history_hook"></a>

### `set_history_hook`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_history_hook(callback: Callable) -> void:
```

设置项目同步历史 Hook。 回调签名为 Callable(operation: Dictionary) -> bool 或 Dictionary。返回拒绝时放置会话 保持活动。Dictionary 必须包含 ok: bool，可选 reason: StringName；回调收到操作记录的 深副本。空 Callable 表示项目通过 placement_committed 信号自行处理。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 受信同步历史回调。 |

结构：

- `callback`: Callable(operation: Dictionary) -> bool 或 Dictionary{ok: bool, reason?: StringName}。

<a id="member-gfspatialcanvas2d-methods-begin_placement"></a>

### `begin_placement`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func begin_placement( type_id: StringName, footprint: Rect2, options: Dictionary = {} ) -> int:
```

开始一个通用放置会话。

参数：

| 名称 | 说明 |
|---|---|
| `type_id` | 项目稳定放置类型 ID。 |
| `footprint` | 相对放置锚点的局部 AABB。 |
| `options` | 初始位置、旋转和吸附选项。 |

返回：成功时返回正 session ID；非法输入或已有会话时返回 0。

结构：

- `options`: Dictionary，可包含 initial_world_position: Vector2、initial_rotation_radians: float、snap_to_grid: bool 和 snap_rotation: bool。

<a id="member-gfspatialcanvas2d-methods-update_placement"></a>

### `update_placement`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func update_placement( world_position: Vector2, options: Dictionary = {} ) -> bool:
```

更新活动放置预览。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 新世界锚点。 |
| `options` | 可选旋转角。 |

返回：会话活动且输入有限时返回 true。

结构：

- `options`: Dictionary，可包含 rotation_radians: float。

<a id="member-gfspatialcanvas2d-methods-commit_placement"></a>

### `commit_placement`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func commit_placement() -> Dictionary:
```

提交活动放置会话。 该方法只冻结通用操作记录。项目校验器和历史 Hook 都接受后才结束会话；它不会创建 节点、扣除资源、写入地图或保存文件。

返回：稳定提交报告。

结构：

- `return`: Dictionary，包含 ok、reason、session_id 和 operation。

<a id="member-gfspatialcanvas2d-methods-cancel_placement"></a>

### `cancel_placement`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func cancel_placement(reason: StringName = &"cancelled") -> Dictionary:
```

取消活动放置会话。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 项目取消原因。 |

返回：稳定取消报告。

结构：

- `return`: Dictionary，包含 ok、reason、session_id 和 preview。

<a id="member-gfspatialcanvas2d-methods-has_active_placement"></a>

### `has_active_placement`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func has_active_placement() -> bool:
```

检查是否存在活动放置会话。

返回：有活动会话时返回 true。

<a id="member-gfspatialcanvas2d-methods-get_placement_snapshot"></a>

### `get_placement_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_placement_snapshot() -> Dictionary:
```

获取放置预览隔离副本。

返回：活动预览；无会话时为空字典。

结构：

- `return`: Dictionary，包含 session_id、type_id、footprint、world_position、rotation_radians、world_bounds、snap_to_grid 和 snap_rotation。

<a id="member-gfspatialcanvas2d-methods-set_input_policy"></a>

### `set_input_policy`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_input_policy(policy: GFSpatialCanvasInputPolicy) -> bool:
```

原子替换输入解释策略。 方法先完整校验并深拷贝候选策略；失败时保留当前策略和所有瞬态状态。 成功切换会释放当前指针捕获，但不会清除选择集合或活动放置会话。

参数：

| 名称 | 说明 |
|---|---|
| `policy` | 候选输入策略。 |

返回：策略有效并完成替换时返回 true。

<a id="member-gfspatialcanvas2d-methods-get_input_policy"></a>

### `get_input_policy`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_input_policy() -> GFSpatialCanvasInputPolicy:
```

获取当前输入策略的隔离副本。

返回：当前策略的深拷贝。

<a id="member-gfspatialcanvas2d-methods-handle_input_event"></a>

### `handle_input_event`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func handle_input_event(event: InputEvent) -> InputDisposition:
```

处理一个项目转发的输入事件。 事件按当前 [GFSpatialCanvasInputPolicy] 解释。方法不会调用 Viewport 的 handled API； 手工路由方应根据 [enum InputDisposition] 决定是否继续传播。 鼠标与原始触摸只允许一个来源持有瞬态捕获；冲突来源及系统手势在物理释放或 显式取消前返回 [constant InputDisposition.IGNORED] 且不修改画布状态。 系统标记为 canceled 的当前捕获事件只释放瞬态状态，不提交选择或放置。

参数：

| 名称 | 说明 |
|---|---|
| `event` | Godot 输入事件。 |

返回：[enum InputDisposition] 值。

<a id="member-gfspatialcanvas2d-methods-handle_screen_input_event"></a>

### `handle_screen_input_event`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func handle_screen_input_event(event: InputEvent) -> InputDisposition:
```

处理一个使用 Viewport 屏幕坐标的输入事件。 适合从 `_input()` 或自定义全局路由转发事件；事件会先复制并转换到本 Control 的局部画布坐标。`_gui_input()` 已提供局部事件，应直接使用 handle_input_event()。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 使用 Viewport 屏幕坐标的 Godot 输入事件。 |

返回：[enum InputDisposition] 值；变换不可逆时返回 [constant InputDisposition.IGNORED]。

<a id="member-gfspatialcanvas2d-methods-set_input_enabled"></a>

### `set_input_enabled`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_input_enabled(enabled: bool) -> void:
```

启用或禁用画布输入处理。 禁用时会释放瞬态选择和手势状态，但不会清除条目、选择或放置会话。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 是否启用输入。 |

<a id="member-gfspatialcanvas2d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 JSON-safe 调试快照。 快照不包含项目回调、任意 metadata/payload 或内容节点。

返回：有界调试状态。

结构：

- `return`: JSON-compatible Dictionary，包含 view、grid、budgets、item_count、selection_count、placement_active、input_active、last_query_candidate_count、last_query_truncated、last_grid_line_count 和 grid_draw_truncated。
