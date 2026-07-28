## GFSpatialCanvas2D: 有界运行时 2D 空间交互画布。
##
## 统一管理画布视图、世界/画布/格子坐标转换、显式条目查询、稳定选择和项目校验的
## 放置会话。项目仍拥有内容节点、占位与权限规则、业务命令、存档和网络同步。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFSpatialCanvas2D
extends Control


# --- 信号 ---

## 视图状态变化时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: 隔离的视图快照。
## [br]
## @schema snapshot: Dictionary，包含 world_center、zoom、visible_world_rect、world_bounds_enabled 和 world_bounds。
signal view_changed(snapshot: Dictionary)

## 选择集合变化时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param selected_ids: 稳定条目 ID 的隔离副本。
signal selection_changed(selected_ids: PackedStringArray)

## 放置会话开始时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: 放置预览的隔离副本。
## [br]
## @schema snapshot: Dictionary，包含 session_id、type_id、footprint、world_position、rotation_radians、world_bounds、snap_to_grid 和 snap_rotation。
signal placement_started(snapshot: Dictionary)

## 放置预览变化时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: 放置预览的隔离副本。
## [br]
## @schema snapshot: Dictionary，结构与 placement_started 相同。
signal placement_preview_changed(snapshot: Dictionary)

## 放置会话成功冻结通用操作记录时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param report: 成功提交报告的隔离副本。
## [br]
## @schema report: Dictionary，包含 ok、reason、session_id 和 operation。
signal placement_committed(report: Dictionary)

## 放置会话取消时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param report: 取消报告的隔离副本。
## [br]
## @schema report: Dictionary，包含 ok、reason、session_id 和 preview。
signal placement_cancelled(report: Dictionary)

## 历史 Hook 接受放置操作后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param operation: 通用放置操作记录的隔离副本。
## [br]
## @schema operation: Dictionary，包含 schema_version、operation、session_id、type_id、footprint、world_position、rotation_radians 和 world_bounds。
signal history_operation_requested(operation: Dictionary)


# --- 枚举 ---

## 选择集合更新模式。
## [br]
## @api public
## [br]
## @since 10.0.0
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


# --- 常量 ---

## 单个画布允许登记的条目绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_ITEMS: int = 65536

## 单个画布允许保留的选择绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_SELECTION: int = 16384

## 单次查询允许进入精确命中与结果窗口的候选绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_QUERY_CANDIDATES: int = 16384

## 单次绘制允许生成的网格线绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_GRID_LINES: int = 2048

const _DEFAULT_MIN_ZOOM: float = 0.05
const _DEFAULT_MAX_ZOOM: float = 32.0
const _ABSOLUTE_MIN_ZOOM: float = 0.0001
const _ABSOLUTE_MAX_ZOOM: float = 1024.0
const _DEFAULT_MAX_ITEMS: int = 16384
const _DEFAULT_MAX_SELECTION: int = 4096
const _DEFAULT_MAX_QUERY_CANDIDATES: int = 4096
const _DEFAULT_MAX_GRID_LINES: int = 512
const _DEFAULT_DRAG_THRESHOLD: float = 4.0
const _PLACEMENT_OPERATION_VERSION: int = 1
const _GRID_OPTION_KEYS: Array[String] = [
	"rotation_step_radians",
	"visible",
]
const _BUDGET_OPTION_KEYS: Array[String] = [
	"max_items",
	"max_selection",
	"max_query_candidates",
	"max_grid_lines",
]
const _ITEM_OPTION_KEYS: Array[String] = [
	"selectable",
	"selection_priority",
	"exact_hit",
]
const _PLACEMENT_BEGIN_OPTION_KEYS: Array[String] = [
	"initial_world_position",
	"initial_rotation_radians",
	"snap_to_grid",
	"snap_rotation",
]
const _PLACEMENT_UPDATE_OPTION_KEYS: Array[String] = [
	"rotation_radians",
]
const _OVERLAY_SCRIPT = preload(
	"res://addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_overlay.gd"
)


# --- 私有变量 ---

var _content_root: Node2D = null
var _overlay: Control = null
var _gesture_utility: GFPointerGestureUtility = null
var _query_index: GFSpatialQueryIndex2D = GFSpatialQueryIndex2D.new()

var _world_center: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _min_zoom: float = _DEFAULT_MIN_ZOOM
var _max_zoom: float = _DEFAULT_MAX_ZOOM
var _world_bounds_enabled: bool = false
var _world_bounds: Rect2 = Rect2()

var _grid_origin: Vector2 = Vector2.ZERO
var _grid_size: Vector2 = Vector2.ONE
var _rotation_step_radians: float = 0.0
var _grid_visible: bool = true

var _max_items: int = _DEFAULT_MAX_ITEMS
var _max_selection: int = _DEFAULT_MAX_SELECTION
var _max_query_candidates: int = _DEFAULT_MAX_QUERY_CANDIDATES
var _max_grid_lines: int = _DEFAULT_MAX_GRID_LINES

var _items: Dictionary = {}
var _selected_ids: PackedStringArray = PackedStringArray()
var _last_query_truncated: bool = false
var _last_query_candidate_count: int = 0
var _last_grid_line_count: int = 0
var _grid_draw_truncated: bool = false

var _next_placement_session_id: int = 1
var _placement: Dictionary = {}
var _placement_validator: Callable = Callable()
var _history_hook: Callable = Callable()
var _callback_active: bool = false

var _input_enabled: bool = true
var _selection_drag_active: bool = false
var _selection_drag_start: Vector2 = Vector2.ZERO
var _selection_drag_end: Vector2 = Vector2.ZERO
var _gesture_active: bool = false
var _drag_threshold: float = _DEFAULT_DRAG_THRESHOLD


# --- Godot 生命周期方法 ---

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_ensure_runtime_nodes()
	_ensure_gesture_utility()
	if not focus_exited.is_connected(_on_focus_exited):
		var _focus_exited_connected: Error = focus_exited.connect(_on_focus_exited) as Error
	_apply_view(false)


func _exit_tree() -> void:
	_reset_transient_input()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var resolved_center: Vector2 = _clamp_world_center(_world_center, _zoom)
		if _is_view_state_finite(resolved_center, _zoom):
			_world_center = resolved_center
			_apply_view(is_node_ready())


func _gui_input(event: InputEvent) -> void:
	if handle_input_event(event):
		accept_event()


# --- 公共方法（视图） ---

## 获取承载项目 2D 内容的根节点。
##
## GF 只更新该节点的位置与缩放，不扫描、重挂或主动释放项目子节点。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 画布拥有的内容根。
func get_content_root() -> Node2D:
	_ensure_runtime_nodes()
	return _content_root


## 原子设置世界中心与缩放。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_center: 目标世界中心。
## [br]
## @param zoom: 每个世界单位对应的画布缩放。
## [br]
## @return 输入有限且缩放有效时返回 true。
func set_view(world_center: Vector2, zoom: float) -> bool:
	if not _is_finite_vector2(world_center) or not _is_finite_float(zoom) or zoom <= 0.0:
		return false
	var resolved_zoom: float = clampf(zoom, _min_zoom, _max_zoom)
	var resolved_center: Vector2 = _clamp_world_center(world_center, resolved_zoom)
	if not _is_view_state_finite(resolved_center, resolved_zoom):
		return false
	var changed: bool = not resolved_center.is_equal_approx(_world_center) or not is_equal_approx(
		resolved_zoom,
		_zoom
	)
	_world_center = resolved_center
	_zoom = resolved_zoom
	_apply_view(changed)
	return true


## 获取当前世界中心。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前世界中心。
func get_world_center() -> Vector2:
	return _world_center


## 获取当前缩放。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前缩放。
func get_zoom() -> float:
	return _zoom


## 原子设置缩放上下限。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param minimum_zoom: 最小缩放。
## [br]
## @param maximum_zoom: 最大缩放。
## [br]
## @return 范围有限、为正且未突破绝对限制时返回 true。
func set_zoom_limits(minimum_zoom: float, maximum_zoom: float) -> bool:
	if (
		not _is_finite_float(minimum_zoom)
		or not _is_finite_float(maximum_zoom)
		or minimum_zoom < _ABSOLUTE_MIN_ZOOM
		or maximum_zoom > _ABSOLUTE_MAX_ZOOM
		or minimum_zoom > maximum_zoom
	):
		return false
	var previous_minimum: float = _min_zoom
	var previous_maximum: float = _max_zoom
	_min_zoom = minimum_zoom
	_max_zoom = maximum_zoom
	if not set_view(_world_center, _zoom):
		_min_zoom = previous_minimum
		_max_zoom = previous_maximum
		return false
	return true


## 设置可选世界边界。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param bounds: 有效世界矩形。
## [br]
## @param enabled: 是否启用中心约束。
## [br]
## @return 边界有限且启用时具有正面积，或显式禁用时返回 true。
func set_world_bounds(bounds: Rect2, enabled: bool = true) -> bool:
	if not _is_finite_rect2(bounds):
		return false
	var normalized_bounds: Rect2 = _normalize_rect(bounds)
	if enabled and (normalized_bounds.size.x <= 0.0 or normalized_bounds.size.y <= 0.0):
		return false
	var previous_bounds: Rect2 = _world_bounds
	var previous_enabled: bool = _world_bounds_enabled
	_world_bounds = normalized_bounds
	_world_bounds_enabled = enabled
	var resolved_center: Vector2 = _clamp_world_center(_world_center, _zoom)
	if not _is_view_state_finite(resolved_center, _zoom):
		_world_bounds = previous_bounds
		_world_bounds_enabled = previous_enabled
		return false
	_world_center = resolved_center
	_apply_view(true)
	return true


## 按画布像素增量平移内容。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param canvas_delta: 指针在画布空间的移动量。
## [br]
## @return 输入有效时返回 true。
func pan_by_canvas_delta(canvas_delta: Vector2) -> bool:
	if not _is_finite_vector2(canvas_delta) or _zoom <= 0.0:
		return false
	return set_view(_world_center - canvas_delta / _zoom, _zoom)


## 围绕指定画布焦点缩放。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param canvas_position: 缩放焦点。
## [br]
## @param factor: 相对缩放因子。
## [br]
## @return 输入有限且 factor 为正时返回 true。
func zoom_at(canvas_position: Vector2, factor: float) -> bool:
	if (
		not _is_finite_vector2(canvas_position)
		or not _is_finite_float(factor)
		or factor <= 0.0
	):
		return false
	var world_focus_result: Dictionary = _try_canvas_to_world(canvas_position)
	if not GFVariantData.get_option_bool(world_focus_result, "ok"):
		return false
	var world_focus: Vector2 = GFVariantData.get_option_vector2(world_focus_result, "value")
	var resolved_zoom: float = clampf(_zoom * factor, _min_zoom, _max_zoom)
	if not _is_finite_float(resolved_zoom):
		return false
	var viewport_center: Vector2 = size * 0.5
	var resolved_center: Vector2 = world_focus - (canvas_position - viewport_center) / resolved_zoom
	return set_view(resolved_center, resolved_zoom)


## 让世界矩形适配当前画布。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_rect: 目标世界矩形。
## [br]
## @param canvas_margin: 画布四周保留的像素边距。
## [br]
## @return 输入和当前画布尺寸有效时返回 true。
func focus_world_rect(world_rect: Rect2, canvas_margin: float = 0.0) -> bool:
	if not _is_finite_rect2(world_rect) or not _is_finite_float(canvas_margin):
		return false
	var normalized_rect: Rect2 = _normalize_rect(world_rect)
	var available_size: Vector2 = size - Vector2.ONE * maxf(canvas_margin, 0.0) * 2.0
	if (
		normalized_rect.size.x <= 0.0
		or normalized_rect.size.y <= 0.0
		or available_size.x <= 0.0
		or available_size.y <= 0.0
	):
		return false
	var target_zoom: float = minf(
		available_size.x / normalized_rect.size.x,
		available_size.y / normalized_rect.size.y
	)
	return set_view(normalized_rect.get_center(), target_zoom)


## 把世界坐标转换为本 Control 的画布坐标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 对应画布坐标；非法输入返回 Vector2.ZERO。
func world_to_canvas(world_position: Vector2) -> Vector2:
	var result: Dictionary = _try_world_to_canvas(world_position)
	return GFVariantData.get_option_vector2(result, "value")


## 把本 Control 的画布坐标转换为世界坐标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param canvas_position: 画布坐标。
## [br]
## @return 对应世界坐标；非法输入返回 Vector2.ZERO。
func canvas_to_world(canvas_position: Vector2) -> Vector2:
	var result: Dictionary = _try_canvas_to_world(canvas_position)
	return GFVariantData.get_option_vector2(result, "value")


## 把世界坐标转换为 Viewport 屏幕坐标。
##
## 该转换包含本 Control 及其 CanvasLayer/父级的画布变换。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 对应 Viewport 屏幕坐标；输入或派生结果非法时返回 Vector2.ZERO。
func world_to_screen(world_position: Vector2) -> Vector2:
	var canvas_result: Dictionary = _try_world_to_canvas(world_position)
	if not GFVariantData.get_option_bool(canvas_result, "ok"):
		return Vector2.ZERO
	var screen_position: Vector2 = (
		get_global_transform_with_canvas()
		* GFVariantData.get_option_vector2(canvas_result, "value")
	)
	return screen_position if _is_finite_vector2(screen_position) else Vector2.ZERO


## 把 Viewport 屏幕坐标转换为世界坐标。
##
## 该转换包含本 Control 及其 CanvasLayer/父级的画布变换。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param screen_position: Viewport 屏幕坐标。
## [br]
## @return 对应世界坐标；输入或画布变换不可逆时返回 Vector2.ZERO。
func screen_to_world(screen_position: Vector2) -> Vector2:
	if not _is_finite_vector2(screen_position):
		return Vector2.ZERO
	var canvas_transform: Transform2D = get_global_transform_with_canvas()
	var determinant: float = canvas_transform.determinant()
	if not _is_finite_float(determinant) or is_zero_approx(determinant):
		return Vector2.ZERO
	var canvas_position: Vector2 = canvas_transform.affine_inverse() * screen_position
	if not _is_finite_vector2(canvas_position):
		return Vector2.ZERO
	var result: Dictionary = _try_canvas_to_world(canvas_position)
	return GFVariantData.get_option_vector2(result, "value")


## 获取当前可见世界矩形。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前画布对应的世界矩形。
func get_visible_world_rect() -> Rect2:
	var result: Dictionary = _try_visible_world_rect(_world_center, _zoom)
	return _get_option_rect2(result, "value")


# --- 公共方法（网格与预算） ---

## 原子配置网格。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param origin: 网格原点。
## [br]
## @param cell_size: 单元尺寸，两个分量都必须大于 0。
## [br]
## @param options: 可选旋转步长与可见性。
## [br]
## @schema options: Dictionary，可包含 rotation_step_radians: float 和 visible: bool。
## [br]
## @return 配置有效时返回 true。
func configure_grid(
	origin: Vector2,
	cell_size: Vector2,
	options: Dictionary = {}
) -> bool:
	if (
		not _options_have_only_known_keys(options, _GRID_OPTION_KEYS)
		or not _option_is_numeric(options, "rotation_step_radians")
		or not _option_is_bool(options, "visible")
	):
		return false
	var rotation_step: float = GFVariantData.get_option_float(
		options,
		"rotation_step_radians",
		_rotation_step_radians
	)
	if (
		not _is_finite_vector2(origin)
		or not _is_finite_vector2(cell_size)
		or cell_size.x <= 0.0
		or cell_size.y <= 0.0
		or not _is_finite_float(rotation_step)
		or rotation_step < 0.0
		or rotation_step > TAU
	):
		return false
	_grid_origin = origin
	_grid_size = cell_size
	_rotation_step_radians = rotation_step
	_grid_visible = GFVariantData.get_option_bool(options, "visible", _grid_visible)
	_request_overlay_redraw()
	return true


## 获取网格原点。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前网格原点。
func get_grid_origin() -> Vector2:
	return _grid_origin


## 获取单元尺寸。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前网格尺寸。
func get_grid_size() -> Vector2:
	return _grid_size


## 将世界坐标转换为格坐标。
##
## 负坐标使用 floor 语义。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 格坐标；非法输入返回 Vector2i.ZERO。
func world_to_cell(world_position: Vector2) -> Vector2i:
	if not _is_finite_vector2(world_position):
		return Vector2i.ZERO
	var local: Vector2 = world_position - _grid_origin
	if not _is_finite_vector2(local):
		return Vector2i.ZERO
	var scaled: Vector2 = Vector2(local.x / _grid_size.x, local.y / _grid_size.y)
	if (
		not _is_finite_vector2(scaled)
		or scaled.x < -2147483648.0
		or scaled.x >= 2147483648.0
		or scaled.y < -2147483648.0
		or scaled.y >= 2147483648.0
	):
		return Vector2i.ZERO
	return Vector2i(
		floori(scaled.x),
		floori(scaled.y)
	)


## 将格坐标转换为世界坐标。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param cell: 格坐标。
## [br]
## @param use_center: 为 true 时返回格子中心，否则返回格子原点。
## [br]
## @return 对应世界坐标；派生结果非有限时返回 Vector2.ZERO。
func cell_to_world(cell: Vector2i, use_center: bool = false) -> Vector2:
	var offset: Vector2 = _grid_size * 0.5 if use_center else Vector2.ZERO
	var result: Vector2 = _grid_origin + Vector2(cell) * _grid_size + offset
	return result if _is_finite_vector2(result) else Vector2.ZERO


## 把世界坐标吸附到最近网格交点。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 待吸附坐标。
## [br]
## @return 吸附坐标；非法输入返回 Vector2.ZERO。
func snap_world_position(world_position: Vector2) -> Vector2:
	var result: Dictionary = _try_snap_world_position(world_position)
	return GFVariantData.get_option_vector2(result, "value")


## 按网格旋转步长吸附角度。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param rotation_radians: 弧度角。
## [br]
## @return 规范化吸附角；未配置步长时只规范化输入，非有限输入返回 0.0。
func snap_rotation(rotation_radians: float) -> float:
	var result: Dictionary = _try_snap_rotation(rotation_radians)
	return GFVariantData.get_option_float(result, "value")


## 原子配置实例预算。
## [br]
## 所有值都只能在 1 与对应绝对上限之间。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param options: 预算选项。
## [br]
## @schema options: Dictionary，可包含 max_items、max_selection、max_query_candidates 和 max_grid_lines。
## [br]
## @return 所有提供值都有效且不会低于当前状态占用时返回 true。
func configure_budgets(options: Dictionary) -> bool:
	if (
		_callback_active
		or not _options_have_only_known_keys(options, _BUDGET_OPTION_KEYS)
		or not _option_is_int(options, "max_items")
		or not _option_is_int(options, "max_selection")
		or not _option_is_int(options, "max_query_candidates")
		or not _option_is_int(options, "max_grid_lines")
	):
		return false
	var candidate_max_items: int = GFVariantData.get_option_int(
		options,
		"max_items",
		_max_items
	)
	var candidate_max_selection: int = GFVariantData.get_option_int(
		options,
		"max_selection",
		_max_selection
	)
	var candidate_max_query_candidates: int = GFVariantData.get_option_int(
		options,
		"max_query_candidates",
		_max_query_candidates
	)
	var candidate_max_grid_lines: int = GFVariantData.get_option_int(
		options,
		"max_grid_lines",
		_max_grid_lines
	)
	if (
		candidate_max_items < 1
		or candidate_max_items > ABSOLUTE_MAX_ITEMS
		or candidate_max_selection < 1
		or candidate_max_selection > ABSOLUTE_MAX_SELECTION
		or candidate_max_query_candidates < 1
		or candidate_max_query_candidates > ABSOLUTE_MAX_QUERY_CANDIDATES
		or candidate_max_grid_lines < 1
		or candidate_max_grid_lines > ABSOLUTE_MAX_GRID_LINES
		or candidate_max_items < _items.size()
		or candidate_max_selection < _selected_ids.size()
	):
		return false
	_max_items = candidate_max_items
	_max_selection = candidate_max_selection
	_max_query_candidates = candidate_max_query_candidates
	_max_grid_lines = candidate_max_grid_lines
	_request_overlay_redraw()
	return true


# --- 公共方法（条目与选择） ---

## 插入或更新一个稳定空间条目。
##
## 条目只保存 ID、有限 AABB、是否可选、选择优先级和可选同步精确命中 Hook。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param item_id: 稳定条目标识。
## [br]
## @param world_bounds: 世界空间 AABB。
## [br]
## @param options: 通用选择选项。
## [br]
## @schema options: Dictionary，可包含 selectable: bool、selection_priority: int 和 exact_hit: Callable(item_id, world_point, bounds) -> bool。
## [br]
## @return 插入或更新成功时返回 true。
func upsert_item(
	item_id: StringName,
	world_bounds: Rect2,
	options: Dictionary = {}
) -> bool:
	var normalized_id: StringName = _normalize_id(item_id)
	if (
		_callback_active
		or normalized_id == &""
		or not _is_finite_rect2(world_bounds)
		or not _options_have_only_known_keys(options, _ITEM_OPTION_KEYS)
		or not _option_is_bool(options, "selectable")
		or not _option_is_int(options, "selection_priority")
		or not _option_is_callable(options, "exact_hit")
	):
		return false
	if not _items.has(normalized_id) and _items.size() >= _max_items:
		return false
	var exact_hit: Callable = _get_callable_option(options, "exact_hit")
	var record: Dictionary = {
		"id": normalized_id,
		"bounds": _normalize_rect(world_bounds),
		"selectable": GFVariantData.get_option_bool(options, "selectable", true),
		"selection_priority": GFVariantData.get_option_int(
			options,
			"selection_priority",
			0
		),
		"exact_hit": exact_hit,
	}
	if not _query_index.upsert(
		normalized_id,
		_get_option_rect2(record, "bounds"),
		{
			"selectable": GFVariantData.get_option_bool(record, "selectable"),
			"selection_priority": GFVariantData.get_option_int(record, "selection_priority"),
		}
	):
		return false
	_items[normalized_id] = record
	if not GFVariantData.get_option_bool(record, "selectable"):
		var next_selection: PackedStringArray = _selected_ids.duplicate()
		var index: int = next_selection.find(String(normalized_id))
		if index >= 0:
			next_selection.remove_at(index)
			_set_selection_internal(next_selection)
	_request_overlay_redraw()
	return true


## 移除条目并同步剔除选择。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param item_id: 条目标识。
## [br]
## @return 找到并移除时返回 true。
func remove_item(item_id: StringName) -> bool:
	var normalized_id: StringName = _normalize_id(item_id)
	if _callback_active or normalized_id == &"" or not _items.has(normalized_id):
		return false
	var _index_removed: bool = _query_index.remove(normalized_id)
	var _item_removed: bool = _items.erase(normalized_id)
	var next_selection: PackedStringArray = _selected_ids.duplicate()
	var index: int = next_selection.find(String(normalized_id))
	if index >= 0:
		next_selection.remove_at(index)
		_set_selection_internal(next_selection)
	_request_overlay_redraw()
	return true


## 清空条目和选择。
## [br]
## @api public
## [br]
## @since 10.0.0
func clear_items() -> void:
	if _callback_active:
		return
	_items.clear()
	_query_index.clear()
	_set_selection_internal(PackedStringArray())
	_request_overlay_redraw()


## 获取不含回调的条目快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param item_id: 条目标识。
## [br]
## @return 包含 id、bounds、selectable 和 selection_priority 的字典；不存在时为空。
## [br]
## @schema return: Dictionary，包含 id、bounds、selectable 和 selection_priority。
func get_item(item_id: StringName) -> Dictionary:
	var normalized_id: StringName = _normalize_id(item_id)
	if normalized_id == &"" or not _items.has(normalized_id):
		return {}
	return _item_public_snapshot(GFVariantData.as_dictionary(_items[normalized_id]))


## 查询包含世界点的条目。
##
## 候选先以有界 top-K 保留全局 selection_priority 最高、稳定 ID 最小的窗口，
## 再在预算内执行 exact_hit。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 匹配的稳定 ID。
func query_items_at(world_position: Vector2) -> PackedStringArray:
	return _query_items_at_internal(world_position, false)


## 查询与世界矩形相交的条目。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_rect: 世界查询矩形。
## [br]
## @param fully_contained: 为 true 时只保留完全位于矩形内的条目。
## [br]
## @return 匹配的稳定 ID。
func query_items_in_rect(
	world_rect: Rect2,
	fully_contained: bool = false
) -> PackedStringArray:
	return _query_items_in_rect_internal(world_rect, fully_contained, false)


## 按模式更新选择。
##
## 只接受已登记且可选的稳定 ID；容量只限制替换或新增，不截断减去候选。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param item_ids: 候选条目 ID。
## [br]
## @param mode: SelectionMode 值。
## [br]
## @return 更新后的隔离选择副本。
func set_selection(
	item_ids: PackedStringArray,
	mode: int = SelectionMode.REPLACE
) -> PackedStringArray:
	if (
		_callback_active
		or not _is_selection_mode_valid(mode)
		or item_ids.size() > ABSOLUTE_MAX_ITEMS
	):
		return get_selection()
	var candidates: PackedStringArray = _normalize_selectable_ids(item_ids)
	var next_selection: PackedStringArray = _selected_ids.duplicate()
	match mode:
		SelectionMode.REPLACE:
			next_selection = candidates
			if next_selection.size() > _max_selection:
				next_selection = next_selection.slice(0, _max_selection)
		SelectionMode.ADD:
			for candidate: String in candidates:
				if not next_selection.has(candidate) and next_selection.size() < _max_selection:
					var _candidate_added: bool = next_selection.append(candidate)
		SelectionMode.TOGGLE:
			var additions: PackedStringArray = PackedStringArray()
			for candidate: String in candidates:
				var index: int = next_selection.find(candidate)
				if index >= 0:
					next_selection.remove_at(index)
				else:
					var _addition_queued: bool = additions.append(candidate)
			for candidate: String in additions:
				if next_selection.size() >= _max_selection:
					break
				var _candidate_toggled_on: bool = next_selection.append(candidate)
		SelectionMode.SUBTRACT:
			for candidate: String in candidates:
				var index: int = next_selection.find(candidate)
				if index >= 0:
					next_selection.remove_at(index)
	_sort_packed_strings(next_selection)
	_set_selection_internal(next_selection)
	return get_selection()


## 在画布坐标点选最高优先级条目。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param canvas_position: 本 Control 的画布坐标。
## [br]
## @param mode: SelectionMode 值。
## [br]
## @return 更新后的选择。
func select_point(
	canvas_position: Vector2,
	mode: int = SelectionMode.REPLACE
) -> PackedStringArray:
	if not _is_finite_vector2(canvas_position) or not _is_selection_mode_valid(mode):
		return get_selection()
	var world_position_result: Dictionary = _try_canvas_to_world(canvas_position)
	if not GFVariantData.get_option_bool(world_position_result, "ok"):
		return get_selection()
	var hits: PackedStringArray = _query_items_at_internal(
		GFVariantData.get_option_vector2(world_position_result, "value"),
		true
	)
	var top_hit: PackedStringArray = PackedStringArray()
	for item_text: String in hits:
		var _top_hit_added: bool = top_hit.append(item_text)
		break
	return set_selection(top_hit, mode)


## 在画布坐标框选条目。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param canvas_rect: 画布选择矩形。
## [br]
## @param mode: SelectionMode 值。
## [br]
## @param fully_contained: 为 true 时只选择完全位于矩形内的条目。
## [br]
## @return 更新后的选择。
func select_rect(
	canvas_rect: Rect2,
	mode: int = SelectionMode.REPLACE,
	fully_contained: bool = false
) -> PackedStringArray:
	if not _is_finite_rect2(canvas_rect) or not _is_selection_mode_valid(mode):
		return get_selection()
	var normalized_canvas_rect: Rect2 = _normalize_rect(canvas_rect)
	var world_start_result: Dictionary = _try_canvas_to_world(normalized_canvas_rect.position)
	var world_end_result: Dictionary = _try_canvas_to_world(normalized_canvas_rect.end)
	if (
		not GFVariantData.get_option_bool(world_start_result, "ok")
		or not GFVariantData.get_option_bool(world_end_result, "ok")
	):
		return get_selection()
	var world_start: Vector2 = GFVariantData.get_option_vector2(world_start_result, "value")
	var world_end: Vector2 = GFVariantData.get_option_vector2(world_end_result, "value")
	var world_rect: Rect2 = _normalize_rect(Rect2(world_start, world_end - world_start))
	if not _is_finite_rect2(world_rect):
		return get_selection()
	var matches: PackedStringArray = _query_items_in_rect_internal(
		world_rect,
		fully_contained,
		true
	)
	return set_selection(matches, mode)


## 清空选择。
## [br]
## @api public
## [br]
## @since 10.0.0
func clear_selection() -> void:
	if _callback_active:
		return
	_set_selection_internal(PackedStringArray())


## 获取选择集合隔离副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 稳定 ID 列表。
func get_selection() -> PackedStringArray:
	return _selected_ids.duplicate()


# --- 公共方法（放置） ---

## 设置项目同步放置校验器。
##
## 回调签名为 Callable(preview: Dictionary) -> bool 或 Dictionary。Dictionary 应包含 ok，
## 可选 reason。空 Callable 表示不追加项目校验。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param callback: 受信同步校验回调。
func set_placement_validator(callback: Callable) -> void:
	if _callback_active:
		return
	_placement_validator = callback


## 设置项目同步历史 Hook。
##
## 回调签名为 Callable(operation: Dictionary) -> bool 或 Dictionary。返回拒绝时放置会话
## 保持活动。Dictionary 必须包含 ok: bool，可选 reason: StringName；回调收到操作记录的
## 深副本。空 Callable 表示项目通过 placement_committed 信号自行处理。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param callback: 受信同步历史回调。
## [br]
## @schema callback: Callable(operation: Dictionary) -> bool 或 Dictionary{ok: bool, reason?: StringName}。
func set_history_hook(callback: Callable) -> void:
	if _callback_active:
		return
	_history_hook = callback


## 开始一个通用放置会话。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param type_id: 项目稳定放置类型 ID。
## [br]
## @param footprint: 相对放置锚点的局部 AABB。
## [br]
## @param options: 初始位置、旋转和吸附选项。
## [br]
## @schema options: Dictionary，可包含 initial_world_position: Vector2、initial_rotation_radians: float、snap_to_grid: bool 和 snap_rotation: bool。
## [br]
## @return 成功时返回正 session ID；非法输入或已有会话时返回 0。
func begin_placement(
	type_id: StringName,
	footprint: Rect2,
	options: Dictionary = {}
) -> int:
	if (
		has_active_placement()
		or _callback_active
		or not _options_have_only_known_keys(options, _PLACEMENT_BEGIN_OPTION_KEYS)
		or not _option_is_vector2(options, "initial_world_position")
		or not _option_is_numeric(options, "initial_rotation_radians")
		or not _option_is_bool(options, "snap_to_grid")
		or not _option_is_bool(options, "snap_rotation")
	):
		return 0
	var normalized_type_id: StringName = _normalize_id(type_id)
	var initial_position: Vector2 = GFVariantData.get_option_vector2(
		options,
		"initial_world_position",
		Vector2.ZERO
	)
	var initial_rotation: float = GFVariantData.get_option_float(
		options,
		"initial_rotation_radians",
		0.0
	)
	if (
		normalized_type_id == &""
		or not _is_finite_rect2(footprint)
		or not _is_finite_vector2(initial_position)
		or not _is_finite_float(initial_rotation)
	):
		return 0
	var session_id: int = _next_placement_session_id
	var candidate_placement: Dictionary = {
		"session_id": session_id,
		"type_id": normalized_type_id,
		"footprint": _normalize_rect(footprint),
		"world_position": initial_position,
		"rotation_radians": initial_rotation,
		"snap_to_grid": GFVariantData.get_option_bool(options, "snap_to_grid"),
		"snap_rotation": GFVariantData.get_option_bool(options, "snap_rotation"),
	}
	if not _resolve_placement_geometry(candidate_placement):
		return 0
	_next_placement_session_id += 1
	_placement = candidate_placement
	var snapshot: Dictionary = get_placement_snapshot()
	placement_started.emit(snapshot.duplicate(true))
	_request_overlay_redraw()
	return session_id


## 更新活动放置预览。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param world_position: 新世界锚点。
## [br]
## @param options: 可选旋转角。
## [br]
## @schema options: Dictionary，可包含 rotation_radians: float。
## [br]
## @return 会话活动且输入有限时返回 true。
func update_placement(
	world_position: Vector2,
	options: Dictionary = {}
) -> bool:
	if (
		not has_active_placement()
		or _callback_active
		or not _is_finite_vector2(world_position)
		or not _options_have_only_known_keys(options, _PLACEMENT_UPDATE_OPTION_KEYS)
		or not _option_is_numeric(options, "rotation_radians")
	):
		return false
	var rotation_radians: float = GFVariantData.get_option_float(
		options,
		"rotation_radians",
		GFVariantData.get_option_float(_placement, "rotation_radians")
	)
	if not _is_finite_float(rotation_radians):
		return false
	var candidate_placement: Dictionary = _placement.duplicate(true)
	candidate_placement["world_position"] = world_position
	candidate_placement["rotation_radians"] = rotation_radians
	if not _resolve_placement_geometry(candidate_placement):
		return false
	_placement = candidate_placement
	var snapshot: Dictionary = get_placement_snapshot()
	placement_preview_changed.emit(snapshot.duplicate(true))
	_request_overlay_redraw()
	return true


## 提交活动放置会话。
##
## 该方法只冻结通用操作记录。项目校验器和历史 Hook 都接受后才结束会话；它不会创建
## 节点、扣除资源、写入地图或保存文件。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 稳定提交报告。
## [br]
## @schema return: Dictionary，包含 ok、reason、session_id 和 operation。
func commit_placement() -> Dictionary:
	if _callback_active:
		return _make_placement_report(false, &"callback_reentrancy")
	if not has_active_placement():
		return _make_placement_report(false, &"no_active_placement")
	var session_id: int = GFVariantData.get_option_int(_placement, "session_id")
	var preview: Dictionary = get_placement_snapshot()
	var validation: Dictionary = _invoke_acceptance_callback(
		_placement_validator,
		preview,
		&"validation_rejected"
	)
	if not GFVariantData.get_option_bool(validation, "ok"):
		return _make_placement_report(
			false,
			GFVariantData.get_option_string_name(validation, "reason", &"validation_rejected")
		)
	if not _placement_session_matches(session_id):
		return _make_placement_report(false, &"placement_changed_during_callback")
	var operation: Dictionary = _make_placement_operation(preview)
	var history_result: Dictionary = _invoke_acceptance_callback(
		_history_hook,
		operation,
		&"history_rejected"
	)
	if not GFVariantData.get_option_bool(history_result, "ok"):
		return _make_placement_report(
			false,
			GFVariantData.get_option_string_name(
				history_result,
				"reason",
				&"history_rejected"
			)
		)
	if not _placement_session_matches(session_id):
		return _make_placement_report(false, &"placement_changed_during_callback")
	_placement.clear()
	var report: Dictionary = {
		"ok": true,
		"reason": &"committed",
		"session_id": session_id,
		"operation": operation.duplicate(true),
	}
	history_operation_requested.emit(operation.duplicate(true))
	placement_committed.emit(report.duplicate(true))
	_request_overlay_redraw()
	return report


## 取消活动放置会话。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param reason: 项目取消原因。
## [br]
## @return 稳定取消报告。
## [br]
## @schema return: Dictionary，包含 ok、reason、session_id 和 preview。
func cancel_placement(reason: StringName = &"cancelled") -> Dictionary:
	if _callback_active:
		return _make_placement_cancel_report(false, &"callback_reentrancy")
	if not has_active_placement():
		return _make_placement_cancel_report(false, &"no_active_placement")
	var preview: Dictionary = get_placement_snapshot()
	var report: Dictionary = {
		"ok": true,
		"reason": reason if reason != &"" else &"cancelled",
		"session_id": GFVariantData.get_option_int(preview, "session_id"),
		"preview": preview,
	}
	_placement.clear()
	placement_cancelled.emit(report.duplicate(true))
	_request_overlay_redraw()
	return report


## 检查是否存在活动放置会话。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 有活动会话时返回 true。
func has_active_placement() -> bool:
	return not _placement.is_empty()


## 获取放置预览隔离副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 活动预览；无会话时为空字典。
## [br]
## @schema return: Dictionary，包含 session_id、type_id、footprint、world_position、rotation_radians、world_bounds、snap_to_grid 和 snap_rotation。
func get_placement_snapshot() -> Dictionary:
	return _placement.duplicate(true)


# --- 公共方法（输入与诊断） ---

## 处理一个项目转发的输入事件。
##
## 中键/单指拖动用于平移，滚轮/捏合用于焦点缩放，左键用于点选、框选或活动放置。
## 只有实际识别和消费的事件返回 true。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param event: Godot 输入事件。
## [br]
## @return 事件被画布消费时返回 true。
func handle_input_event(event: InputEvent) -> bool:
	if not _input_enabled or event == null:
		return false
	_ensure_gesture_utility()

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and key_event.keycode == KEY_ESCAPE:
		if has_active_placement():
			var _cancel_report: Dictionary = cancel_placement(&"input_cancelled")
			return true
		if _selection_drag_active:
			_reset_selection_drag()
			return true
		return false

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		return _handle_primary_mouse_button(mouse_button)

	if (
		_gesture_utility.get_active_pointer_count() > 0
		and _gesture_utility.handle_input_event(event)
	):
		return true

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null:
		if not _is_finite_vector2(mouse_motion.position):
			return false
		if has_active_placement():
			var world_position_result: Dictionary = _try_canvas_to_world(mouse_motion.position)
			if not GFVariantData.get_option_bool(world_position_result, "ok"):
				return false
			return update_placement(
				GFVariantData.get_option_vector2(world_position_result, "value")
			)
		if _selection_drag_active:
			_selection_drag_end = mouse_motion.position
			_request_overlay_redraw()
			return true

	return _gesture_utility.handle_input_event(event)


## 处理一个使用 Viewport 屏幕坐标的输入事件。
##
## 适合从 `_input()` 或自定义全局路由转发事件；事件会先复制并转换到本 Control
## 的局部画布坐标。`_gui_input()` 已提供局部事件，应直接使用 handle_input_event()。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param event: 使用 Viewport 屏幕坐标的 Godot 输入事件。
## [br]
## @return 事件被画布消费时返回 true；变换不可逆时返回 false。
func handle_screen_input_event(event: InputEvent) -> bool:
	if event == null or not _input_enabled:
		return false
	var canvas_transform: Transform2D = get_global_transform_with_canvas()
	var determinant: float = canvas_transform.determinant()
	if not _is_finite_float(determinant) or is_zero_approx(determinant):
		return false
	var local_event: InputEvent = make_input_local(event)
	return handle_input_event(local_event)


## 启用或禁用画布输入处理。
## [br]
## 禁用时会释放瞬态选择和手势状态，但不会清除条目、选择或放置会话。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param enabled: 是否启用输入。
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_reset_transient_input()


## 获取 JSON-safe 调试快照。
##
## 快照不包含项目回调、任意 metadata/payload 或内容节点。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 有界调试状态。
## [br]
## @schema return: JSON-compatible Dictionary，包含 view、grid、budgets、item_count、selection_count、placement_active、input_active、last_query_candidate_count、last_query_truncated、last_grid_line_count 和 grid_draw_truncated。
func get_debug_snapshot() -> Dictionary:
	return {
		"view": {
			"world_center": _vector_to_json(_world_center),
			"zoom": _zoom,
			"visible_world_rect": _rect_to_json(get_visible_world_rect()),
			"world_bounds_enabled": _world_bounds_enabled,
			"world_bounds": _rect_to_json(_world_bounds),
		},
		"grid": {
			"origin": _vector_to_json(_grid_origin),
			"cell_size": _vector_to_json(_grid_size),
			"rotation_step_radians": _rotation_step_radians,
			"visible": _grid_visible,
		},
		"budgets": {
			"max_items": _max_items,
			"max_selection": _max_selection,
			"max_query_candidates": _max_query_candidates,
			"max_grid_lines": _max_grid_lines,
		},
		"item_count": _items.size(),
		"selection_count": _selected_ids.size(),
		"placement_active": has_active_placement(),
		"input_active": _gesture_active or _selection_drag_active,
		"last_query_candidate_count": _last_query_candidate_count,
		"last_query_truncated": _last_query_truncated,
		"last_grid_line_count": _last_grid_line_count,
		"grid_draw_truncated": _grid_draw_truncated,
	}


# --- 框架内部方法 ---

## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param target: 接收有界 overlay 绘制调用的内部 Control。
func draw_overlay(target: Control) -> void:
	if not is_instance_valid(target):
		return
	_draw_grid_overlay(target)
	_draw_selection_overlay(target)
	_draw_placement_overlay(target)
	_draw_selection_drag_overlay(target)


# --- 私有/辅助方法 ---

func _ensure_runtime_nodes() -> void:
	if not is_instance_valid(_content_root):
		_content_root = Node2D.new()
		_content_root.name = "GFSpatialCanvasContent"
		add_child(_content_root)
	if not is_instance_valid(_overlay):
		_overlay = _OVERLAY_SCRIPT.new()
		_overlay.name = "GFSpatialCanvasOverlay"
		add_child(_overlay)
		var _overlay_configured: Variant = _overlay.call("configure", self)
	_apply_view(false)


func _ensure_gesture_utility() -> void:
	if _gesture_utility != null:
		return
	_gesture_utility = GFPointerGestureUtility.new()
	_gesture_utility.mouse_button_index = MOUSE_BUTTON_MIDDLE
	_gesture_utility.track_mouse_wheel = true
	_gesture_utility.track_touch = true
	_gesture_utility.track_gesture_events = true
	var _gesture_updated_connected: Error = _gesture_utility.gesture_updated.connect(
		_on_gesture_updated
	) as Error
	var _gesture_ended_connected: Error = _gesture_utility.gesture_ended.connect(
		_on_gesture_ended
	) as Error


func _apply_view(emit_change: bool) -> void:
	var content_position: Vector2 = size * 0.5 - _world_center * _zoom
	var content_scale: Vector2 = Vector2.ONE * _zoom
	if not _is_finite_vector2(content_position) or not _is_finite_vector2(content_scale):
		return
	if is_instance_valid(_content_root):
		_content_root.position = content_position
		_content_root.scale = content_scale
	_request_overlay_redraw()
	if emit_change:
		view_changed.emit(_make_view_snapshot())


func _make_view_snapshot() -> Dictionary:
	return {
		"world_center": _world_center,
		"zoom": _zoom,
		"visible_world_rect": get_visible_world_rect(),
		"world_bounds_enabled": _world_bounds_enabled,
		"world_bounds": _world_bounds,
	}


func _clamp_world_center(candidate: Vector2, candidate_zoom: float) -> Vector2:
	if not _world_bounds_enabled or candidate_zoom <= 0.0:
		return candidate
	var half_visible: Vector2 = size / candidate_zoom * 0.5
	var bounds_min: Vector2 = _world_bounds.position
	var bounds_max: Vector2 = _world_bounds.end
	var result: Vector2 = candidate
	if half_visible.x * 2.0 >= _world_bounds.size.x:
		result.x = _world_bounds.get_center().x
	else:
		result.x = clampf(candidate.x, bounds_min.x + half_visible.x, bounds_max.x - half_visible.x)
	if half_visible.y * 2.0 >= _world_bounds.size.y:
		result.y = _world_bounds.get_center().y
	else:
		result.y = clampf(candidate.y, bounds_min.y + half_visible.y, bounds_max.y - half_visible.y)
	return result


func _is_view_state_finite(candidate_center: Vector2, candidate_zoom: float) -> bool:
	if (
		not _is_finite_vector2(candidate_center)
		or not _is_finite_float(candidate_zoom)
		or candidate_zoom <= 0.0
	):
		return false
	var content_position: Vector2 = size * 0.5 - candidate_center * candidate_zoom
	var content_scale: Vector2 = Vector2.ONE * candidate_zoom
	if not _is_finite_vector2(content_position) or not _is_finite_vector2(content_scale):
		return false
	var visible_result: Dictionary = _try_visible_world_rect(candidate_center, candidate_zoom)
	return GFVariantData.get_option_bool(visible_result, "ok")


func _try_visible_world_rect(candidate_center: Vector2, candidate_zoom: float) -> Dictionary:
	if (
		not _is_finite_vector2(candidate_center)
		or not _is_finite_float(candidate_zoom)
		or candidate_zoom <= 0.0
		or not _is_finite_vector2(size)
	):
		return { "ok": false, "value": Rect2() }
	var visible_size: Vector2 = size / candidate_zoom
	var visible_position: Vector2 = candidate_center - visible_size * 0.5
	var visible_rect: Rect2 = Rect2(visible_position, visible_size)
	if not _is_finite_rect2(visible_rect):
		return { "ok": false, "value": Rect2() }
	return { "ok": true, "value": visible_rect }


func _try_world_to_canvas(world_position: Vector2) -> Dictionary:
	if not _is_finite_vector2(world_position):
		return { "ok": false, "value": Vector2.ZERO }
	var relative_position: Vector2 = world_position - _world_center
	var canvas_position: Vector2 = size * 0.5 + relative_position * _zoom
	if not _is_finite_vector2(relative_position) or not _is_finite_vector2(canvas_position):
		return { "ok": false, "value": Vector2.ZERO }
	return { "ok": true, "value": canvas_position }


func _try_canvas_to_world(canvas_position: Vector2) -> Dictionary:
	if (
		not _is_finite_vector2(canvas_position)
		or not _is_finite_float(_zoom)
		or _zoom <= 0.0
	):
		return { "ok": false, "value": Vector2.ZERO }
	var canvas_offset: Vector2 = canvas_position - size * 0.5
	var world_offset: Vector2 = canvas_offset / _zoom
	var world_position: Vector2 = _world_center + world_offset
	if (
		not _is_finite_vector2(canvas_offset)
		or not _is_finite_vector2(world_offset)
		or not _is_finite_vector2(world_position)
	):
		return { "ok": false, "value": Vector2.ZERO }
	return { "ok": true, "value": world_position }


func _try_snap_world_position(world_position: Vector2) -> Dictionary:
	if not _is_finite_vector2(world_position):
		return { "ok": false, "value": Vector2.ZERO }
	var local_position: Vector2 = world_position - _grid_origin
	if not _is_finite_vector2(local_position):
		return { "ok": false, "value": Vector2.ZERO }
	var grid_units: Vector2 = Vector2(
		local_position.x / _grid_size.x,
		local_position.y / _grid_size.y
	)
	if not _is_finite_vector2(grid_units):
		return { "ok": false, "value": Vector2.ZERO }
	var snapped_offset: Vector2 = Vector2(
		roundf(grid_units.x) * _grid_size.x,
		roundf(grid_units.y) * _grid_size.y
	)
	var snapped_position: Vector2 = _grid_origin + snapped_offset
	if not _is_finite_vector2(snapped_offset) or not _is_finite_vector2(snapped_position):
		return { "ok": false, "value": Vector2.ZERO }
	return { "ok": true, "value": snapped_position }


func _try_snap_rotation(rotation_radians: float) -> Dictionary:
	if not _is_finite_float(rotation_radians):
		return { "ok": false, "value": 0.0 }
	var snapped_rotation: float = rotation_radians
	if _rotation_step_radians > 0.0:
		var rotation_units: float = rotation_radians / _rotation_step_radians
		if not _is_finite_float(rotation_units):
			return { "ok": false, "value": 0.0 }
		snapped_rotation = roundf(rotation_units) * _rotation_step_radians
		if not _is_finite_float(snapped_rotation):
			return { "ok": false, "value": 0.0 }
	var wrapped_rotation: float = wrapf(snapped_rotation, -PI, PI)
	if not _is_finite_float(wrapped_rotation):
		return { "ok": false, "value": 0.0 }
	return { "ok": true, "value": wrapped_rotation }


func _query_items_at_internal(
	world_position: Vector2,
	selectable_only: bool
) -> PackedStringArray:
	if not _is_finite_vector2(world_position) or _callback_active:
		return PackedStringArray()
	var records: Array[Dictionary] = _query_index.query_records_radius(world_position, 0.0)
	return _filter_query_records(records, world_position, true, selectable_only)


func _query_items_in_rect_internal(
	world_rect: Rect2,
	fully_contained: bool,
	selectable_only: bool
) -> PackedStringArray:
	if not _is_finite_rect2(world_rect) or _callback_active:
		return PackedStringArray()
	var normalized_rect: Rect2 = _normalize_rect(world_rect)
	var records: Array[Dictionary] = _query_index.query_records_rect(normalized_rect)
	var filtered_records: Array[Dictionary] = []
	for record: Dictionary in records:
		var item_id: StringName = _record_item_id(record)
		if item_id == &"" or not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		var item_bounds: Rect2 = _get_option_rect2(item_record, "bounds")
		if fully_contained and not _rect_encloses_rect(normalized_rect, item_bounds):
			continue
		filtered_records.append(record)
	return _filter_query_records(
		filtered_records,
		Vector2.ZERO,
		false,
		selectable_only
	)


func _filter_query_records(
	records: Array[Dictionary],
	world_position: Vector2,
	apply_exact_hit: bool,
	selectable_only: bool
) -> PackedStringArray:
	var bounded_records: Array[Dictionary] = _take_bounded_query_records(
		records,
		selectable_only
	)
	bounded_records.sort_custom(_sort_query_records)
	var result: PackedStringArray = PackedStringArray()
	for record: Dictionary in bounded_records:
		var item_id: StringName = _record_item_id(record)
		if item_id == &"" or not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		if apply_exact_hit and not _item_exact_hit(item_record, world_position):
			continue
		var _result_added: bool = result.append(String(item_id))
	return result


func _take_bounded_query_records(
	records: Array[Dictionary],
	selectable_only: bool
) -> Array[Dictionary]:
	var heap: Array[Dictionary] = []
	var eligible_count: int = 0
	for record: Dictionary in records:
		var item_id: StringName = _record_item_id(record)
		if item_id == &"" or not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		if selectable_only and not GFVariantData.get_option_bool(item_record, "selectable", true):
			continue
		eligible_count += 1
		if heap.size() < _max_query_candidates:
			_push_query_record_heap(heap, record)
		elif _sort_query_records(record, heap[0]):
			heap[0] = record
			_sift_query_record_heap_down(heap, 0)
	_last_query_candidate_count = eligible_count
	_last_query_truncated = eligible_count > _max_query_candidates
	return heap


func _push_query_record_heap(heap: Array[Dictionary], record: Dictionary) -> void:
	heap.append(record)
	var index: int = heap.size() - 1
	while index > 0:
		var parent_index: int = (index - 1) >> 1
		if not _query_record_is_worse(heap[index], heap[parent_index]):
			break
		var parent_record: Dictionary = heap[parent_index]
		heap[parent_index] = heap[index]
		heap[index] = parent_record
		index = parent_index


func _sift_query_record_heap_down(heap: Array[Dictionary], start_index: int) -> void:
	var index: int = start_index
	while true:
		var left_index: int = index * 2 + 1
		if left_index >= heap.size():
			return
		var right_index: int = left_index + 1
		var worse_index: int = left_index
		if (
			right_index < heap.size()
			and _query_record_is_worse(heap[right_index], heap[left_index])
		):
			worse_index = right_index
		if not _query_record_is_worse(heap[worse_index], heap[index]):
			return
		var current_record: Dictionary = heap[index]
		heap[index] = heap[worse_index]
		heap[worse_index] = current_record
		index = worse_index


func _query_record_is_worse(left: Dictionary, right: Dictionary) -> bool:
	return _sort_query_records(right, left)


func _sort_query_records(left: Dictionary, right: Dictionary) -> bool:
	var left_id: StringName = _record_item_id(left)
	var right_id: StringName = _record_item_id(right)
	var left_record: Dictionary = GFVariantData.as_dictionary(_items.get(left_id, {}))
	var right_record: Dictionary = GFVariantData.as_dictionary(_items.get(right_id, {}))
	var left_priority: int = GFVariantData.get_option_int(left_record, "selection_priority")
	var right_priority: int = GFVariantData.get_option_int(right_record, "selection_priority")
	if left_priority != right_priority:
		return left_priority > right_priority
	return String(left_id) < String(right_id)


func _record_item_id(record: Dictionary) -> StringName:
	return _normalize_id(GFVariantData.get_option_string_name(record, "entity"))


func _item_exact_hit(item_record: Dictionary, world_position: Vector2) -> bool:
	var callback: Callable = _get_callable_value(
		GFVariantData.get_option_value(item_record, "exact_hit", Callable())
	)
	if callback.is_null():
		return true
	if not callback.is_valid():
		return false
	if _callback_active:
		return false
	_callback_active = true
	var result: Variant = callback.call(
		GFVariantData.get_option_string_name(item_record, "id"),
		world_position,
		_get_option_rect2(item_record, "bounds")
	)
	_callback_active = false
	return result is bool and GFVariantData.to_bool(result)


func _normalize_selectable_ids(item_ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for item_text: String in item_ids:
		var item_id: StringName = _normalize_id(StringName(item_text))
		if item_id == &"" or seen.has(item_id) or not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		if not GFVariantData.get_option_bool(item_record, "selectable", true):
			continue
		seen[item_id] = true
		var _selectable_added: bool = result.append(String(item_id))
	_sort_packed_strings(result)
	return result


func _set_selection_internal(next_selection: PackedStringArray) -> void:
	_sort_packed_strings(next_selection)
	if next_selection == _selected_ids:
		return
	_selected_ids = next_selection.duplicate()
	selection_changed.emit(_selected_ids.duplicate())
	_request_overlay_redraw()


func _sort_packed_strings(values: PackedStringArray) -> void:
	values.sort()


func _item_public_snapshot(item_record: Dictionary) -> Dictionary:
	return {
		"id": GFVariantData.get_option_string_name(item_record, "id"),
		"bounds": _get_option_rect2(item_record, "bounds"),
		"selectable": GFVariantData.get_option_bool(item_record, "selectable", true),
		"selection_priority": GFVariantData.get_option_int(
			item_record,
			"selection_priority"
		),
	}


func _resolve_placement_geometry(candidate_placement: Dictionary) -> bool:
	var world_position: Vector2 = GFVariantData.get_option_vector2(
		candidate_placement,
		"world_position"
	)
	var rotation_radians: float = GFVariantData.get_option_float(
		candidate_placement,
		"rotation_radians"
	)
	if (
		not _is_finite_vector2(world_position)
		or not _is_finite_float(rotation_radians)
	):
		return false
	if GFVariantData.get_option_bool(candidate_placement, "snap_to_grid"):
		var position_result: Dictionary = _try_snap_world_position(world_position)
		if not GFVariantData.get_option_bool(position_result, "ok"):
			return false
		world_position = GFVariantData.get_option_vector2(position_result, "value")
	if GFVariantData.get_option_bool(candidate_placement, "snap_rotation"):
		var rotation_result: Dictionary = _try_snap_rotation(rotation_radians)
		if not GFVariantData.get_option_bool(rotation_result, "ok"):
			return false
		rotation_radians = GFVariantData.get_option_float(rotation_result, "value")
	var bounds_result: Dictionary = _try_transformed_rect_bounds(
		_get_option_rect2(candidate_placement, "footprint"),
		world_position,
		rotation_radians
	)
	if not GFVariantData.get_option_bool(bounds_result, "ok"):
		return false
	candidate_placement["world_position"] = world_position
	candidate_placement["rotation_radians"] = rotation_radians
	candidate_placement["world_bounds"] = _get_option_rect2(bounds_result, "value")
	return true


func _try_transformed_rect_bounds(
	rect: Rect2,
	world_position: Vector2,
	rotation_radians: float
) -> Dictionary:
	if (
		not _is_finite_rect2(rect)
		or not _is_finite_vector2(world_position)
		or not _is_finite_float(rotation_radians)
	):
		return { "ok": false, "value": Rect2() }
	var transform: Transform2D = Transform2D(rotation_radians, world_position)
	if (
		not _is_finite_vector2(transform.x)
		or not _is_finite_vector2(transform.y)
		or not _is_finite_vector2(transform.origin)
	):
		return { "ok": false, "value": Rect2() }
	var corners: PackedVector2Array = PackedVector2Array([
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y),
	])
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		if not _is_finite_vector2(corner):
			return { "ok": false, "value": Rect2() }
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	var result: Rect2 = Rect2(minimum, maximum - minimum)
	if not _is_finite_rect2(result):
		return { "ok": false, "value": Rect2() }
	return { "ok": true, "value": result }


func _make_placement_operation(preview: Dictionary) -> Dictionary:
	return {
		"schema_version": _PLACEMENT_OPERATION_VERSION,
		"operation": &"spatial_canvas_placement",
		"session_id": GFVariantData.get_option_int(preview, "session_id"),
		"type_id": GFVariantData.get_option_string_name(preview, "type_id"),
		"footprint": _get_option_rect2(preview, "footprint"),
		"world_position": GFVariantData.get_option_vector2(preview, "world_position"),
		"rotation_radians": GFVariantData.get_option_float(preview, "rotation_radians"),
		"world_bounds": _get_option_rect2(preview, "world_bounds"),
	}


func _invoke_acceptance_callback(
	callback: Callable,
	value: Dictionary,
	default_rejection_reason: StringName
) -> Dictionary:
	if callback.is_null():
		return { "ok": true, "reason": &"accepted" }
	if not callback.is_valid():
		return { "ok": false, "reason": default_rejection_reason }
	if _callback_active:
		return { "ok": false, "reason": &"callback_reentrancy" }
	_callback_active = true
	var result: Variant = callback.call(value.duplicate(true))
	_callback_active = false
	if result is bool:
		return {
			"ok": GFVariantData.to_bool(result),
			"reason": &"accepted" if GFVariantData.to_bool(result) else default_rejection_reason,
		}
	if result is Dictionary:
		var report: Dictionary = GFVariantData.as_dictionary(result)
		if not _option_is_present_bool(report, "ok"):
			return { "ok": false, "reason": default_rejection_reason }
		var accepted: bool = GFVariantData.get_option_bool(report, "ok")
		return {
			"ok": accepted,
			"reason": GFVariantData.get_option_string_name(
				report,
				"reason",
				&"accepted" if accepted else default_rejection_reason
			),
		}
	return { "ok": false, "reason": default_rejection_reason }


func _make_placement_report(ok: bool, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"session_id": GFVariantData.get_option_int(_placement, "session_id"),
		"operation": {},
	}


func _make_placement_cancel_report(ok: bool, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"session_id": GFVariantData.get_option_int(_placement, "session_id"),
		"preview": {},
	}


func _placement_session_matches(expected_session_id: int) -> bool:
	return (
		has_active_placement()
		and expected_session_id > 0
		and GFVariantData.get_option_int(_placement, "session_id") == expected_session_id
	)


func _handle_primary_mouse_button(event: InputEventMouseButton) -> bool:
	if not _is_finite_vector2(event.position):
		return false
	if event.pressed and is_inside_tree():
		grab_focus()
	if has_active_placement():
		var world_position_result: Dictionary = _try_canvas_to_world(event.position)
		if not GFVariantData.get_option_bool(world_position_result, "ok"):
			return false
		var _updated: bool = update_placement(
			GFVariantData.get_option_vector2(world_position_result, "value")
		)
		if not _updated:
			return false
		if event.pressed:
			return true
		var _report: Dictionary = commit_placement()
		return true
	if event.pressed:
		_selection_drag_active = true
		_selection_drag_start = event.position
		_selection_drag_end = event.position
		_request_overlay_redraw()
		return true
	if not _selection_drag_active:
		return false
	_selection_drag_end = event.position
	var mode: int = _selection_mode_from_mouse_event(event)
	var drag_size: float = _selection_drag_start.distance_to(_selection_drag_end)
	if drag_size <= _drag_threshold:
		var _selected_point: PackedStringArray = select_point(_selection_drag_end, mode)
	else:
		var drag_rect: Rect2 = Rect2(
			_selection_drag_start,
			_selection_drag_end - _selection_drag_start
		)
		var _selected_rect: PackedStringArray = select_rect(drag_rect, mode)
	_reset_selection_drag()
	return true


func _selection_mode_from_mouse_event(event: InputEventMouseButton) -> int:
	if event.ctrl_pressed or event.meta_pressed:
		return SelectionMode.TOGGLE
	if event.shift_pressed:
		return SelectionMode.ADD
	return SelectionMode.REPLACE


func _on_gesture_updated(snapshot: Dictionary, _event: InputEvent) -> void:
	_gesture_active = (
		GFVariantData.get_option_bool(snapshot, "active")
		and GFVariantData.get_option_int(snapshot, "pointer_count") > 0
	)
	var pan_delta: Vector2 = GFVariantData.get_option_vector2(snapshot, "pan_delta")
	var scale_factor: float = GFVariantData.get_option_float(snapshot, "scale", 1.0)
	var center: Vector2 = GFVariantData.get_option_vector2(snapshot, "center", size * 0.5)
	if not pan_delta.is_zero_approx():
		var _panned: bool = pan_by_canvas_delta(pan_delta)
	if not is_equal_approx(scale_factor, 1.0):
		var _zoomed: bool = zoom_at(center, scale_factor)


func _on_gesture_ended(_snapshot: Dictionary) -> void:
	_gesture_active = false


func _on_focus_exited() -> void:
	_reset_transient_input()


func _reset_transient_input() -> void:
	_reset_selection_drag()
	_gesture_active = false
	if _gesture_utility != null:
		_gesture_utility.reset_gesture()


func _reset_selection_drag() -> void:
	_selection_drag_active = false
	_selection_drag_start = Vector2.ZERO
	_selection_drag_end = Vector2.ZERO
	_request_overlay_redraw()


func _request_overlay_redraw() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _draw_grid_overlay(target: Control) -> void:
	_last_grid_line_count = 0
	_grid_draw_truncated = false
	if not _grid_visible or _zoom <= 0.0:
		return
	var visible_rect: Rect2 = get_visible_world_rect()
	var start_x: float = _grid_origin.x + floorf(
		(visible_rect.position.x - _grid_origin.x) / _grid_size.x
	) * _grid_size.x
	var start_y: float = _grid_origin.y + floorf(
		(visible_rect.position.y - _grid_origin.y) / _grid_size.y
	) * _grid_size.y
	var line_color: Color = Color(0.55, 0.65, 0.8, 0.22)
	var x: float = start_x
	while x <= visible_rect.end.x and _last_grid_line_count < _max_grid_lines:
		target.draw_line(
			world_to_canvas(Vector2(x, visible_rect.position.y)),
			world_to_canvas(Vector2(x, visible_rect.end.y)),
			line_color
		)
		_last_grid_line_count += 1
		x += _grid_size.x
	var y: float = start_y
	while y <= visible_rect.end.y and _last_grid_line_count < _max_grid_lines:
		target.draw_line(
			world_to_canvas(Vector2(visible_rect.position.x, y)),
			world_to_canvas(Vector2(visible_rect.end.x, y)),
			line_color
		)
		_last_grid_line_count += 1
		y += _grid_size.y
	if x <= visible_rect.end.x or y <= visible_rect.end.y:
		_grid_draw_truncated = true


func _draw_selection_overlay(target: Control) -> void:
	var color: Color = Color(0.25, 0.72, 1.0, 0.95)
	for item_text: String in _selected_ids:
		var item_id: StringName = StringName(item_text)
		if not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		var world_rect: Rect2 = _get_option_rect2(item_record, "bounds")
		target.draw_rect(_world_rect_to_canvas_rect(world_rect), color, false, 2.0)


func _draw_placement_overlay(target: Control) -> void:
	if not has_active_placement():
		return
	var footprint: Rect2 = _get_option_rect2(_placement, "footprint")
	var world_position: Vector2 = GFVariantData.get_option_vector2(
		_placement,
		"world_position"
	)
	var rotation_radians: float = GFVariantData.get_option_float(_placement, "rotation_radians")
	var transform: Transform2D = Transform2D(rotation_radians, world_position)
	var points: PackedVector2Array = PackedVector2Array([
		world_to_canvas(transform * footprint.position),
		world_to_canvas(transform * Vector2(footprint.end.x, footprint.position.y)),
		world_to_canvas(transform * footprint.end),
		world_to_canvas(transform * Vector2(footprint.position.x, footprint.end.y)),
		world_to_canvas(transform * footprint.position),
	])
	target.draw_polyline(points, Color(0.35, 1.0, 0.55, 0.95), 2.0)


func _draw_selection_drag_overlay(target: Control) -> void:
	if not _selection_drag_active:
		return
	target.draw_rect(
		_normalize_rect(
			Rect2(_selection_drag_start, _selection_drag_end - _selection_drag_start)
		),
		Color(0.2, 0.65, 1.0, 0.8),
		false,
		1.0
	)


func _world_rect_to_canvas_rect(world_rect: Rect2) -> Rect2:
	var start: Vector2 = world_to_canvas(world_rect.position)
	var finish: Vector2 = world_to_canvas(world_rect.end)
	return _normalize_rect(Rect2(start, finish - start))


func _rect_encloses_rect(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)


func _is_selection_mode_valid(mode: int) -> bool:
	return (
		mode == SelectionMode.REPLACE
		or mode == SelectionMode.ADD
		or mode == SelectionMode.TOGGLE
		or mode == SelectionMode.SUBTRACT
	)


func _normalize_id(value: StringName) -> StringName:
	return StringName(String(value).strip_edges())


func _normalize_rect(rect: Rect2) -> Rect2:
	var rect_position: Vector2 = rect.position
	var rect_size: Vector2 = rect.size
	if rect_size.x < 0.0:
		rect_position.x += rect_size.x
		rect_size.x = -rect_size.x
	if rect_size.y < 0.0:
		rect_position.y += rect_size.y
		rect_size.y = -rect_size.y
	return Rect2(rect_position, rect_size)


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


func _is_finite_rect2(value: Rect2) -> bool:
	return (
		_is_finite_vector2(value.position)
		and _is_finite_vector2(value.size)
		and _is_finite_vector2(value.position + value.size)
	)


func _get_callable_option(options: Dictionary, key: String) -> Callable:
	return _get_callable_value(GFVariantData.get_option_value(options, key, Callable()))


func _get_option_rect2(
	options: Dictionary,
	key: Variant,
	default_value: Rect2 = Rect2()
) -> Rect2:
	var value: Variant = GFVariantData.get_option_value(options, key, default_value)
	if value is Rect2:
		var rect: Rect2 = value
		return rect
	return default_value


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _options_have_only_known_keys(
	options: Dictionary,
	known_keys: Array[String]
) -> bool:
	var seen_keys: Dictionary = {}
	for raw_key: Variant in options.keys():
		var normalized_key: String = ""
		if raw_key is String:
			normalized_key = raw_key
		elif raw_key is StringName:
			var raw_key_name: StringName = raw_key
			normalized_key = String(raw_key_name)
		else:
			return false
		if not known_keys.has(normalized_key) or seen_keys.has(normalized_key):
			return false
		seen_keys[normalized_key] = true
	return true


func _has_option(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))


func _option_is_bool(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is bool


func _option_is_present_bool(options: Dictionary, key: String) -> bool:
	return _has_option(options, key) and GFVariantData.get_option_value(options, key) is bool


func _option_is_int(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is int


func _option_is_numeric(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	var value: Variant = GFVariantData.get_option_value(options, key)
	return value is int or value is float


func _option_is_vector2(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is Vector2


func _option_is_callable(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is Callable


func _vector_to_json(value: Vector2) -> Dictionary:
	return { "x": value.x, "y": value.y }


func _rect_to_json(value: Rect2) -> Dictionary:
	return {
		"position": _vector_to_json(value.position),
		"size": _vector_to_json(value.size),
	}
