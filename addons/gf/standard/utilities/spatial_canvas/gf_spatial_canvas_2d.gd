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

## 输入处理结果。
##
## 手工转发调用只观察该返回值；只有 [constant InputDisposition.CONSUMED]
## 会让画布自身的 [code]_gui_input()[/code] 调用 [method Control.accept_event]。
## [br]
## @api public
## [br]
## @since 11.0.0
enum InputDisposition {
	## 事件未被画布识别或当前策略要求继续交给其他接收者。
	IGNORED,
	## 事件已更新画布，但仍允许 GUI 冒泡。
	HANDLED,
	## 事件已更新画布，并应在 GUI 边界停止传播。
	CONSUMED,
}

## 区分当前由鼠标还是原始触摸手势持有画布输入捕获。
## [br]
## @api private
## [br]
enum _InputCaptureOwner {
	NONE,
	MOUSE,
	RAW_TOUCH,
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

## 视图缩放的默认下限。
## [br]
## @api private
## [br]
const _DEFAULT_MIN_ZOOM: float = 0.05

## 视图缩放的默认上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ZOOM: float = 32.0

## 允许配置的最小缩放绝对下限。
## [br]
## @api private
## [br]
const _ABSOLUTE_MIN_ZOOM: float = 0.0001

## 允许配置的最大缩放绝对上限。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ZOOM: float = 1024.0

## 画布默认允许登记的条目数上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ITEMS: int = 16384

## 画布默认保留的选择数上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_SELECTION: int = 4096

## 单次查询默认检查的候选上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_QUERY_CANDIDATES: int = 4096

## 单次绘制默认生成的网格线数量上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_GRID_LINES: int = 512

## 单个滚轮事件允许的最大倍增因子。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_WHEEL_EVENT_FACTOR: float = 64.0

## 冻结放置操作记录使用的 schema 版本。
## [br]
## @api private
## [br]
const _PLACEMENT_OPERATION_VERSION: int = 1

## 网格配置接受的选项键白名单。
## [br]
## @api private
## [br]
const _GRID_OPTION_KEYS: Array[String] = [
	"rotation_step_radians",
	"visible",
]

## 资源预算配置接受的选项键白名单。
## [br]
## @api private
## [br]
const _BUDGET_OPTION_KEYS: Array[String] = [
	"max_items",
	"max_selection",
	"max_query_candidates",
	"max_grid_lines",
]

## 条目可选字段接受的选项键白名单。
## [br]
## @api private
## [br]
const _ITEM_OPTION_KEYS: Array[String] = [
	"selectable",
	"selection_priority",
	"exact_hit",
]

## 开始放置会话接受的选项键白名单。
## [br]
## @api private
## [br]
const _PLACEMENT_BEGIN_OPTION_KEYS: Array[String] = [
	"initial_world_position",
	"initial_rotation_radians",
	"snap_to_grid",
	"snap_rotation",
]

## 更新放置会话接受的选项键白名单。
## [br]
## @api private
## [br]
const _PLACEMENT_UPDATE_OPTION_KEYS: Array[String] = [
	"rotation_radians",
]

## 创建并绘制画布辅助叠层的脚本资源。
## [br]
## @api private
## [br]
const _OVERLAY_SCRIPT = preload(
	"res://addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_overlay.gd"
)


# --- 私有变量 ---

## 画布拥有的内容 Node2D；视图更新只调整其位置和缩放。
## [br]
## @api private
## [br]
var _content_root: Node2D = null

## 画布拥有的辅助绘制 Control。
## [br]
## @api private
## [br]
var _overlay: Control = null

## 收集触摸指针和系统手势的手势工具。
## [br]
## @api private
## [br]
var _gesture_utility: GFPointerGestureUtility = null

## 登记画布条目并提供空间候选查询的索引。
## [br]
## @api private
## [br]
var _query_index: GFSpatialQueryIndex2D = GFSpatialQueryIndex2D.new()

## 当前视图中心的世界坐标。
## [br]
## @api private
## [br]
var _world_center: Vector2 = Vector2.ZERO

## 每个世界单位对应的当前画布缩放。
## [br]
## @api private
## [br]
var _zoom: float = 1.0

## 当前视图允许的最小缩放。
## [br]
## @api private
## [br]
var _min_zoom: float = _DEFAULT_MIN_ZOOM

## 当前视图允许的最大缩放。
## [br]
## @api private
## [br]
var _max_zoom: float = _DEFAULT_MAX_ZOOM

## 是否按配置的世界边界约束视图中心。
## [br]
## @api private
## [br]
var _world_bounds_enabled: bool = false

## 约束视图中心时使用的规范化世界矩形。
## [br]
## @api private
## [br]
var _world_bounds: Rect2 = Rect2()

## 网格坐标系的世界原点。
## [br]
## @api private
## [br]
var _grid_origin: Vector2 = Vector2.ZERO

## 网格两个轴向的世界尺寸。
## [br]
## @api private
## [br]
var _grid_size: Vector2 = Vector2.ONE

## 放置旋转吸附的弧度步长。
## [br]
## @api private
## [br]
var _rotation_step_radians: float = 0.0

## 是否绘制网格辅助线。
## [br]
## @api private
## [br]
var _grid_visible: bool = true

## 运行时允许登记的最大条目数。
## [br]
## @api private
## [br]
var _max_items: int = _DEFAULT_MAX_ITEMS

## 运行时允许保留的最大选择数。
## [br]
## @api private
## [br]
var _max_selection: int = _DEFAULT_MAX_SELECTION

## 单次空间查询允许保留的最大候选数。
## [br]
## @api private
## [br]
var _max_query_candidates: int = _DEFAULT_MAX_QUERY_CANDIDATES

## 单次绘制允许生成的最大网格线数。
## [br]
## @api private
## [br]
var _max_grid_lines: int = _DEFAULT_MAX_GRID_LINES

## 按稳定条目 ID 保存的条目记录。
## [br]
## @api private
## [br]
var _items: Dictionary = {}

## 当前已选择的稳定条目 ID 集合。
## [br]
## @api private
## [br]
var _selected_ids: PackedStringArray = PackedStringArray()

## 是否绘制已选条目的轮廓。
## [br]
## @api private
## [br]
var _selected_item_outlines_visible: bool = true

## 最近一次查询是否因候选预算而截断。
## [br]
## @api private
## [br]
var _last_query_truncated: bool = false

## 最近一次查询符合前置筛选的候选总数。
## [br]
## @api private
## [br]
var _last_query_candidate_count: int = 0

## 最近一次网格绘制生成的线条数。
## [br]
## @api private
## [br]
var _last_grid_line_count: int = 0

## 最近一次网格绘制是否达到线条预算。
## [br]
## @api private
## [br]
var _grid_draw_truncated: bool = false

## 下一个放置会话使用的递增 ID。
## [br]
## @api private
## [br]
var _next_placement_session_id: int = 1

## 当前活动放置会话及其预览状态；无活动会话时为空字典。
## [br]
## @api private
## [br]
var _placement: Dictionary = {}

## 决定放置预览是否可接受的可选回调。
## [br]
## @api private
## [br]
var _placement_validator: Callable = Callable()

## 接收已冻结通用放置操作记录的可选回调。
## [br]
## @api private
## [br]
var _history_hook: Callable = Callable()

## 标记精确命中或放置回调执行期间，防止查询重入。
## [br]
## @api private
## [br]
var _callback_active: bool = false

## 是否由画布处理输入事件。
## [br]
## @api private
## [br]
var _input_enabled: bool = true

## 应用于画布的空间画布输入策略副本。
## [br]
## @api private
## [br]
var _input_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()

## 是否正在通过鼠标拖动平移视图。
## [br]
## @api private
## [br]
var _mouse_pan_active: bool = false

## 当前鼠标平移捕获的按钮。
## [br]
## @api private
## [br]
var _mouse_pan_button: MouseButton = MOUSE_BUTTON_NONE

## 上次鼠标平移事件的画布坐标。
## [br]
## @api private
## [br]
var _mouse_pan_last_position: Vector2 = Vector2.ZERO

## 是否正在拖动选择矩形。
## [br]
## @api private
## [br]
var _selection_drag_active: bool = false

## 当前选择拖动的画布起点。
## [br]
## @api private
## [br]
var _selection_drag_start: Vector2 = Vector2.ZERO

## 当前选择拖动的画布终点。
## [br]
## @api private
## [br]
var _selection_drag_end: Vector2 = Vector2.ZERO

## 当前拖动选择使用的集合更新模式。
## [br]
## @api private
## [br]
var _selection_drag_mode: SelectionMode = SelectionMode.REPLACE

## 启动当前选择捕获的鼠标按钮；触摸捕获时为 NONE。
## [br]
## @api private
## [br]
var _selection_capture_button: MouseButton = MOUSE_BUTTON_NONE

## 当前选择捕获关联的触摸指针索引；无触摸选择时为 -1。
## [br]
## @api private
## [br]
var _touch_selection_index: int = -1

## 最近手势更新报告的活动状态。
## [br]
## @api private
## [br]
var _gesture_active: bool = false

## 当前互斥输入捕获的设备类别。
## [br]
## @api private
## [br]
var _input_capture_owner: _InputCaptureOwner = _InputCaptureOwner.NONE

## 持有当前输入捕获的设备 ID。
## [br]
## @api private
## [br]
var _input_capture_device: int = 0


# --- Godot 生命周期方法 ---

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_force_pass_scroll_events = false
	_ensure_runtime_nodes()
	_ensure_gesture_utility()
	if not focus_exited.is_connected(_on_focus_exited):
		var _focus_exited_connected: Error = focus_exited.connect(_on_focus_exited) as Error
	_apply_view(false)


func _exit_tree() -> void:
	_reset_transient_input()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			var resolved_center: Vector2 = _clamp_world_center(_world_center, _zoom)
			if _is_view_state_finite(resolved_center, _zoom):
				_world_center = resolved_center
				_apply_view(is_node_ready())
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_reset_transient_input()
		CanvasItem.NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_reset_transient_input()


func _gui_input(event: InputEvent) -> void:
	var disposition: InputDisposition = handle_input_event(event)
	if disposition == InputDisposition.CONSUMED:
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
## @param mode: [enum SelectionMode] 值。
## [br]
## @return 更新后的隔离选择副本。
func set_selection(
	item_ids: PackedStringArray,
	mode: SelectionMode = SelectionMode.REPLACE
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
## @param mode: [enum SelectionMode] 值。
## [br]
## @return 更新后的选择。
func select_point(
	canvas_position: Vector2,
	mode: SelectionMode = SelectionMode.REPLACE
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
## @param mode: [enum SelectionMode] 值。
## [br]
## @param fully_contained: 为 true 时只选择完全位于矩形内的条目。
## [br]
## @return 更新后的选择。
func select_rect(
	canvas_rect: Rect2,
	mode: SelectionMode = SelectionMode.REPLACE,
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


## 设置是否绘制已选条目的默认矩形轮廓。
##
## 默认开启，可在入树前配置。只影响已选条目轮廓，不改变选择集合、选择信号、
## 点选、框选输入、拖拽框、网格或放置预览；值变化后请求覆盖层重绘。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param outlines_visible: 是否显示已选条目的默认轮廓。
func set_selected_item_outlines_visible(outlines_visible: bool) -> void:
	if _selected_item_outlines_visible == outlines_visible:
		return
	_selected_item_outlines_visible = outlines_visible
	_request_overlay_redraw()


## 获取已选条目的默认矩形轮廓显示配置。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 是否启用已选条目轮廓，默认 true。
func are_selected_item_outlines_visible() -> bool:
	return _selected_item_outlines_visible


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

## 原子替换输入解释策略。
##
## 方法先完整校验并深拷贝候选策略；失败时保留当前策略和所有瞬态状态。
## 成功切换会释放当前指针捕获，但不会清除选择集合或活动放置会话。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param policy: 候选输入策略。
## [br]
## @return 策略有效并完成替换时返回 true。
func set_input_policy(policy: GFSpatialCanvasInputPolicy) -> bool:
	var isolated_policy: GFSpatialCanvasInputPolicy = _isolate_input_policy(policy)
	if isolated_policy == null:
		return false
	var report: Dictionary = isolated_policy.validate_policy()
	if not GFVariantData.get_option_bool(report, "ok"):
		return false
	_reset_transient_input()
	_input_policy = isolated_policy
	return true


## 获取当前输入策略的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前策略的深拷贝。
func get_input_policy() -> GFSpatialCanvasInputPolicy:
	return _isolate_input_policy(_input_policy)


## 处理一个项目转发的输入事件。
##
## 事件按当前 [GFSpatialCanvasInputPolicy] 解释。方法不会调用 Viewport 的 handled API；
## 手工路由方应根据 [enum InputDisposition] 决定是否继续传播。
## 鼠标与原始触摸只允许一个来源持有瞬态捕获；冲突来源及系统手势在物理释放或
## 显式取消前返回 [constant InputDisposition.IGNORED] 且不修改画布状态。
## 系统标记为 canceled 的当前捕获事件只释放瞬态状态，不提交选择或放置。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param event: Godot 输入事件。
## [br]
## @return [enum InputDisposition] 值。
func handle_input_event(event: InputEvent) -> InputDisposition:
	if not _input_enabled or event == null:
		return InputDisposition.IGNORED
	_ensure_gesture_utility()

	if event.is_canceled():
		return _handle_canceled_input_event(event)

	if _matches_cancel_action(event):
		if has_active_placement():
			var _cancel_report: Dictionary = cancel_placement(&"input_cancelled")
			_reset_transient_input()
			return _general_disposition()
		if _has_transient_input_state():
			_reset_transient_input()
			return _general_disposition()
		return InputDisposition.IGNORED

	if _input_capture_conflicts_with_event(event):
		return InputDisposition.IGNORED

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if _is_mouse_wheel_button(mouse_button.button_index):
			return _handle_wheel_input(mouse_button)
		return _handle_mouse_button_input(mouse_button)

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null:
		return _handle_mouse_motion_input(mouse_motion)

	var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
	if screen_touch != null:
		return _handle_screen_touch_input(screen_touch)
	var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
	if screen_drag != null:
		return _handle_screen_drag_input(screen_drag)

	if event is InputEventPanGesture:
		if not _input_policy.system_pan_gesture_enabled:
			return InputDisposition.IGNORED
		return _handle_system_gesture_input(event)
	if event is InputEventMagnifyGesture:
		if not _input_policy.system_magnify_gesture_enabled:
			return InputDisposition.IGNORED
		return _handle_system_gesture_input(event)

	return InputDisposition.IGNORED


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
## @return [enum InputDisposition] 值；变换不可逆时返回 [constant InputDisposition.IGNORED]。
func handle_screen_input_event(event: InputEvent) -> InputDisposition:
	if event == null or not _input_enabled:
		return InputDisposition.IGNORED
	var canvas_transform: Transform2D = get_global_transform_with_canvas()
	var determinant: float = canvas_transform.determinant()
	if not _is_finite_float(determinant) or is_zero_approx(determinant):
		return InputDisposition.IGNORED
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
		"input_active": (
			_input_capture_owner != _InputCaptureOwner.NONE
			or _gesture_active
			or _mouse_pan_active
			or _selection_drag_active
			or _selection_capture_button != MOUSE_BUTTON_NONE
			or _touch_selection_index >= 0
		),
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

## 确保内容根与绘制叠层存在并已配置，然后应用当前视图。
## [br]
## @api private
## [br]
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


## 延迟创建触摸手势工具、配置追踪类型并连接其更新与结束信号。
## [br]
## @api private
## [br]
func _ensure_gesture_utility() -> void:
	if _gesture_utility != null:
		return
	_gesture_utility = GFPointerGestureUtility.new()
	_gesture_utility.track_mouse = false
	_gesture_utility.track_mouse_wheel = false
	_gesture_utility.track_touch = true
	_gesture_utility.track_gesture_events = true
	var _gesture_updated_connected: Error = _gesture_utility.gesture_updated.connect(
		_on_gesture_updated
	) as Error
	var _gesture_ended_connected: Error = _gesture_utility.gesture_ended.connect(
		_on_gesture_ended
	) as Error


## 复制输入策略字段并克隆有上限的选择修饰键绑定。
## [br]
## @api private
## [br]
func _isolate_input_policy(
	source: GFSpatialCanvasInputPolicy
) -> GFSpatialCanvasInputPolicy:
	if source == null:
		return null
	var isolated: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	isolated.pan_mouse_button = source.pan_mouse_button
	isolated.pan_action = source.pan_action
	isolated.pan_modifier_mask = source.pan_modifier_mask
	isolated.selection_mouse_button = source.selection_mouse_button
	isolated.selection_action = source.selection_action
	isolated.selection_default_mode = source.selection_default_mode
	isolated.selection_modifier_bindings.clear()
	var binding_count: int = mini(
		source.selection_modifier_bindings.size(),
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS
	)
	for binding_index: int in range(binding_count):
		var source_binding: GFSpatialCanvasSelectionModeBinding = (
			source.selection_modifier_bindings[binding_index]
		)
		if source_binding == null:
			isolated.selection_modifier_bindings.append(null)
			continue
		var isolated_binding: GFSpatialCanvasSelectionModeBinding = (
			GFSpatialCanvasSelectionModeBinding.new()
		)
		isolated_binding.modifier_mask = source_binding.modifier_mask
		isolated_binding.selection_mode = source_binding.selection_mode
		isolated.selection_modifier_bindings.append(isolated_binding)
	if (
		source.selection_modifier_bindings.size()
		> GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS
	):
		isolated.selection_modifier_bindings.append(null)
	isolated.drag_threshold = source.drag_threshold
	isolated.wheel_axis = source.wheel_axis
	isolated.wheel_routing = source.wheel_routing
	isolated.wheel_modifier_mask = source.wheel_modifier_mask
	isolated.wheel_zoom_factor = source.wheel_zoom_factor
	isolated.touch_enabled = source.touch_enabled
	isolated.touch_primary_behavior = source.touch_primary_behavior
	isolated.touch_multi_pan_enabled = source.touch_multi_pan_enabled
	isolated.touch_multi_zoom_enabled = source.touch_multi_zoom_enabled
	isolated.system_pan_gesture_enabled = source.system_pan_gesture_enabled
	isolated.system_magnify_gesture_enabled = source.system_magnify_gesture_enabled
	isolated.placement_cancel_action = source.placement_cancel_action
	isolated.consume_handled_events = source.consume_handled_events
	isolated.consume_wheel_events = source.consume_wheel_events
	return isolated


## 按中心和缩放更新内容根变换、请求叠层重绘，并按选项发出视图快照。
## [br]
## @api private
## [br]
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


## 构造当前世界中心、缩放和边界状态的视图字典。
## [br]
## @api private
## [br]
func _make_view_snapshot() -> Dictionary:
	return {
		"world_center": _world_center,
		"zoom": _zoom,
		"visible_world_rect": get_visible_world_rect(),
		"world_bounds_enabled": _world_bounds_enabled,
		"world_bounds": _world_bounds,
	}


## 按可见世界尺寸把视图中心限制在边界内；视口过大时将该轴置于边界中心。
## [br]
## @api private
## [br]
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


## 检查候选中心、缩放、内容变换及可见世界矩形是否均有效。
## [br]
## @api private
## [br]
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


## 计算可见世界矩形，并以 ok/value 字典报告有限性检查结果。
## [br]
## @api private
## [br]
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


## 把世界坐标转换为画布坐标，非法输入或结果以 ok=false 返回。
## [br]
## @api private
## [br]
func _try_world_to_canvas(world_position: Vector2) -> Dictionary:
	if not _is_finite_vector2(world_position):
		return { "ok": false, "value": Vector2.ZERO }
	var relative_position: Vector2 = world_position - _world_center
	var canvas_position: Vector2 = size * 0.5 + relative_position * _zoom
	if not _is_finite_vector2(relative_position) or not _is_finite_vector2(canvas_position):
		return { "ok": false, "value": Vector2.ZERO }
	return { "ok": true, "value": canvas_position }


## 把画布坐标转换为世界坐标，非法缩放或结果以 ok=false 返回。
## [br]
## @api private
## [br]
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


## 按网格原点和尺寸吸附世界坐标，并报告有限性检查结果。
## [br]
## @api private
## [br]
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


## 按可选弧度步长取整并环绕到 [-PI, PI]。
## [br]
## @api private
## [br]
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


## 拒绝非法坐标或回调重入后，查询点候选并应用精确命中与可选选择性过滤。
## [br]
## @api private
## [br]
func _query_items_at_internal(
	world_position: Vector2,
	selectable_only: bool
) -> PackedStringArray:
	if not _is_finite_vector2(world_position) or _callback_active:
		return PackedStringArray()
	var records: Array[Dictionary] = _query_index.query_records_radius(world_position, 0.0)
	return _filter_query_records(records, world_position, true, selectable_only)


## 查询矩形相交候选，可选要求条目完全包含于查询区域，再执行候选过滤。
## [br]
## @api private
## [br]
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


## 按候选预算截取并排序记录，再筛除失效条目和可选精确命中失败项。
## [br]
## @api private
## [br]
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


## 用有界堆保留排序最靠前的候选，并更新候选总数和截断状态。
## [br]
## @api private
## [br]
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


## 将查询记录插入以最差候选为根的有界堆。
## [br]
## @api private
## [br]
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


## 从指定位置向下恢复最差候选为根的堆顺序。
## [br]
## @api private
## [br]
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


## 反转查询排序比较，判断左记录是否比右记录更差。
## [br]
## @api private
## [br]
func _query_record_is_worse(left: Dictionary, right: Dictionary) -> bool:
	return _sort_query_records(right, left)


## 按 selection_priority 降序、条目 ID 升序排列查询记录。
## [br]
## @api private
## [br]
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


## 从查询记录的 entity 字段读取并规范化条目 ID。
## [br]
## @api private
## [br]
func _record_item_id(record: Dictionary) -> StringName:
	return _normalize_id(GFVariantData.get_option_string_name(record, "entity"))


## 执行条目的可选精确命中回调；回调重入或返回非 bool 时不命中。
## [br]
## @api private
## [br]
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


## 去重、过滤不存在或不可选的 ID，并对结果排序。
## [br]
## @api private
## [br]
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


## 排序并替换选择集合；仅集合变化时发出副本信号并请求重绘。
## [br]
## @api private
## [br]
func _set_selection_internal(next_selection: PackedStringArray) -> void:
	_sort_packed_strings(next_selection)
	if next_selection == _selected_ids:
		return
	_selected_ids = next_selection.duplicate()
	selection_changed.emit(_selected_ids.duplicate())
	_request_overlay_redraw()


## 按字典序原地排序 PackedStringArray。
## [br]
## @api private
## [br]
func _sort_packed_strings(values: PackedStringArray) -> void:
	values.sort()


## 从条目记录投影 ID、边界、可选状态和选择优先级。
## [br]
## @api private
## [br]
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


## 校验并按会话选项吸附位置和旋转，成功后写入预览边界。
## [br]
## @api private
## [br]
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


## 变换矩形四角并计算轴对齐边界；非法输入或派生值返回失败结果。
## [br]
## @api private
## [br]
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


## 把预览投影为带 schema 版本和通用放置字段的操作记录。
## [br]
## @api private
## [br]
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


## 以防重入标志和深复制输入调用接受回调，并规范化 bool 或结构化结果。
## [br]
## @api private
## [br]
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


## 创建包含当前会话 ID、ok、reason 和空 operation 的放置报告。
## [br]
## @api private
## [br]
func _make_placement_report(ok: bool, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"session_id": GFVariantData.get_option_int(_placement, "session_id"),
		"operation": {},
	}


## 创建包含当前会话 ID、ok、reason 和空 preview 的取消报告。
## [br]
## @api private
## [br]
func _make_placement_cancel_report(ok: bool, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"session_id": GFVariantData.get_option_int(_placement, "session_id"),
		"preview": {},
	}


## 检查当前放置会话活动且 ID 与正数预期值相同。
## [br]
## @api private
## [br]
func _placement_session_matches(expected_session_id: int) -> bool:
	return (
		has_active_placement()
		and expected_session_id > 0
		and GFVariantData.get_option_int(_placement, "session_id") == expected_session_id
	)


## 处理鼠标按下与释放，开始或结束平移/选择捕获并返回传播处置。
## [br]
## @api private
## [br]
func _handle_mouse_button_input(event: InputEventMouseButton) -> InputDisposition:
	if not event.pressed:
		if _mouse_pan_active and event.button_index == _mouse_pan_button:
			if _is_finite_vector2(event.position):
				var final_delta: Vector2 = event.position - _mouse_pan_last_position
				if not final_delta.is_zero_approx():
					var _panned: bool = pan_by_canvas_delta(final_delta)
			_reset_mouse_pan_capture()
			_release_input_capture(_InputCaptureOwner.MOUSE)
			return _general_disposition()
		if (
			_selection_capture_button != MOUSE_BUTTON_NONE
			and event.button_index == _selection_capture_button
		):
			if _is_finite_vector2(event.position):
				_finish_selection_capture_at(event.position)
			else:
				_reset_selection_capture()
			_release_input_capture(_InputCaptureOwner.MOUSE)
			return _general_disposition()
		return InputDisposition.IGNORED

	if not _is_finite_vector2(event.position):
		return InputDisposition.IGNORED
	if _mouse_pan_active or _selection_capture_button != MOUSE_BUTTON_NONE:
		return InputDisposition.IGNORED

	var pan_matches: bool = _matches_pan_press(event)
	var selection_matches: bool = _matches_pointer_press(
		event,
		_input_policy.selection_mouse_button,
		_input_policy.selection_action
	)
	if pan_matches and selection_matches:
		return InputDisposition.IGNORED
	if pan_matches:
		if not _acquire_input_capture(_InputCaptureOwner.MOUSE, event.device):
			return InputDisposition.IGNORED
		if is_inside_tree():
			grab_focus()
		_mouse_pan_active = true
		_mouse_pan_button = event.button_index
		_mouse_pan_last_position = event.position
		return _general_disposition()
	if selection_matches:
		if not _acquire_input_capture(_InputCaptureOwner.MOUSE, event.device):
			return InputDisposition.IGNORED
		if is_inside_tree():
			grab_focus()
		var selection_mode: SelectionMode = _selection_mode_from_modifier_mask(
			_modifier_mask_from_mouse_event(event)
		)
		if not _start_selection_capture(
			event.position,
			selection_mode,
			event.button_index,
			-1
		):
			_release_input_capture(_InputCaptureOwner.MOUSE)
			return InputDisposition.IGNORED
		return _general_disposition()
	return InputDisposition.IGNORED


## 处理鼠标移动以平移视图、更新选择拖动或移动放置预览。
## [br]
## @api private
## [br]
func _handle_mouse_motion_input(event: InputEventMouseMotion) -> InputDisposition:
	if not _is_finite_vector2(event.position):
		return InputDisposition.IGNORED
	if _mouse_pan_active:
		var pan_delta: Vector2 = event.position - _mouse_pan_last_position
		_mouse_pan_last_position = event.position
		if not pan_delta.is_zero_approx():
			var _panned: bool = pan_by_canvas_delta(pan_delta)
		return _general_disposition()
	if _selection_drag_active and _selection_capture_button != MOUSE_BUTTON_NONE:
		_selection_drag_end = event.position
		_request_overlay_redraw()
		return _general_disposition()
	if has_active_placement():
		if _update_placement_from_canvas_position(event.position):
			return _general_disposition()
	return InputDisposition.IGNORED


## 按轴向、路由修饰键和事件因子限制处理滚轮缩放。
## [br]
## @api private
## [br]
func _handle_wheel_input(event: InputEventMouseButton) -> InputDisposition:
	if (
		not event.pressed
		or not _is_finite_vector2(event.position)
		or not _is_finite_float(event.factor)
		or event.factor <= 0.0
		or event.factor > _ABSOLUTE_MAX_WHEEL_EVENT_FACTOR
	):
		return InputDisposition.IGNORED
	if _input_policy.wheel_routing == GFSpatialCanvasInputPolicy.WheelRouting.PARENT_ONLY:
		return InputDisposition.IGNORED
	if not _wheel_button_matches_axis(event.button_index):
		return InputDisposition.IGNORED
	if (
		_input_policy.wheel_routing
		== GFSpatialCanvasInputPolicy.WheelRouting.MODIFIER_GATED
		and _modifier_mask_from_mouse_event(event) != _input_policy.wheel_modifier_mask
	):
		return InputDisposition.IGNORED
	var factor: float = pow(_input_policy.wheel_zoom_factor, event.factor)
	if not _is_finite_float(factor) or factor <= 0.0:
		return InputDisposition.IGNORED
	if (
		event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	):
		factor = 1.0 / factor
	if not zoom_at(event.position, factor):
		return InputDisposition.IGNORED
	return _wheel_disposition()


## 按触摸策略建立指针捕获、选择状态并转发事件到手势工具。
## [br]
## @api private
## [br]
func _handle_screen_touch_input(event: InputEventScreenTouch) -> InputDisposition:
	if not _input_policy.touch_enabled:
		return InputDisposition.IGNORED
	if (
		_input_policy.touch_primary_behavior
		== GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.NONE
		and not _has_raw_touch_multi_behavior()
	):
		return InputDisposition.IGNORED
	var tracked: bool = _gesture_tracks_pointer(event.index)
	if not _is_finite_vector2(event.position):
		if not event.pressed and tracked:
			_reset_transient_input()
			return _general_disposition()
		return InputDisposition.IGNORED

	if event.pressed:
		if tracked:
			return InputDisposition.IGNORED
		var active_pointer_count: int = _gesture_utility.get_active_pointer_count()
		var starts_capture: bool = active_pointer_count == 0
		if starts_capture:
			if not _acquire_input_capture(_InputCaptureOwner.RAW_TOUCH, event.device):
				return InputDisposition.IGNORED
		elif _input_capture_owner != _InputCaptureOwner.RAW_TOUCH:
			return InputDisposition.IGNORED
		if active_pointer_count > 0:
			if not _has_raw_touch_multi_behavior():
				return InputDisposition.IGNORED
			if (
				_input_policy.touch_primary_behavior
				== GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
			):
				_reset_selection_capture()
		elif (
			_input_policy.touch_primary_behavior
			== GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
		):
			if not _start_selection_capture(
				event.position,
				_input_policy.selection_default_mode,
				MOUSE_BUTTON_NONE,
				event.index
			):
				_release_input_capture(_InputCaptureOwner.RAW_TOUCH)
				return InputDisposition.IGNORED
		if _gesture_utility.handle_input_event(event):
			return _general_disposition()
		if starts_capture:
			_reset_transient_input()
		return InputDisposition.IGNORED

	if not tracked:
		return InputDisposition.IGNORED
	if _touch_selection_index == event.index:
		_finish_selection_capture_at(event.position)
	var handled: bool = _gesture_utility.handle_input_event(event)
	if handled:
		return _general_disposition()
	return InputDisposition.IGNORED


## 处理已捕获设备的触摸拖动，更新选择/放置位置并转发手势事件。
## [br]
## @api private
## [br]
func _handle_screen_drag_input(event: InputEventScreenDrag) -> InputDisposition:
	if (
		not _input_policy.touch_enabled
		or _input_capture_owner != _InputCaptureOwner.RAW_TOUCH
		or not _gesture_tracks_pointer(event.index)
	):
		return InputDisposition.IGNORED
	if not _is_finite_vector2(event.position):
		_reset_transient_input()
		return _general_disposition()
	if _touch_selection_index == event.index:
		if has_active_placement():
			var _updated: bool = _update_placement_from_canvas_position(event.position)
		elif _selection_drag_active:
			_selection_drag_end = event.position
			_request_overlay_redraw()
	var handled: bool = _gesture_utility.handle_input_event(event)
	if handled:
		return _general_disposition()
	return InputDisposition.IGNORED


## 校验系统平移或放大手势数据后转发至手势工具。
## [br]
## @api private
## [br]
func _handle_system_gesture_input(event: InputEvent) -> InputDisposition:
	var pan_gesture: InputEventPanGesture = event as InputEventPanGesture
	if pan_gesture != null:
		if (
			not _is_finite_vector2(pan_gesture.position)
			or not _is_finite_vector2(pan_gesture.delta)
		):
			return InputDisposition.IGNORED
	var magnify_gesture: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify_gesture != null:
		if (
			not _is_finite_vector2(magnify_gesture.position)
			or not _is_finite_float(magnify_gesture.factor)
			or magnify_gesture.factor <= 0.0
		):
			return InputDisposition.IGNORED
	if _gesture_utility.handle_input_event(event):
		return _general_disposition()
	return InputDisposition.IGNORED


## 在放置会话中更新预览，否则初始化选择拖动并记录输入归属。
## [br]
## @api private
## [br]
func _start_selection_capture(
	canvas_position: Vector2,
	selection_mode: SelectionMode,
	mouse_button: MouseButton,
	touch_index: int
) -> bool:
	if has_active_placement():
		if not _update_placement_from_canvas_position(canvas_position):
			return false
	else:
		_selection_drag_active = true
		_selection_drag_start = canvas_position
		_selection_drag_end = canvas_position
		_selection_drag_mode = selection_mode
		_request_overlay_redraw()
	_selection_capture_button = mouse_button
	_touch_selection_index = touch_index
	return true


## 完成放置或按拖动距离执行点/矩形选择，随后重置选择捕获。
## [br]
## @api private
## [br]
func _finish_selection_capture_at(canvas_position: Vector2) -> void:
	if has_active_placement():
		if _update_placement_from_canvas_position(canvas_position):
			var _report: Dictionary = commit_placement()
		_reset_selection_capture()
		return
	if _selection_drag_active:
		_selection_drag_end = canvas_position
		var drag_size: float = _selection_drag_start.distance_to(_selection_drag_end)
		if drag_size <= _input_policy.drag_threshold:
			var _selected_point: PackedStringArray = select_point(
				_selection_drag_end,
				_selection_drag_mode
			)
		else:
			var drag_rect: Rect2 = Rect2(
				_selection_drag_start,
				_selection_drag_end - _selection_drag_start
			)
			var _selected_rect: PackedStringArray = select_rect(
				drag_rect,
				_selection_drag_mode
			)
	_reset_selection_capture()


## 只响应匹配当前设备及捕获控件的取消事件，并重置瞬时输入状态。
## [br]
## @api private
## [br]
func _handle_canceled_input_event(event: InputEvent) -> InputDisposition:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		if (
			_input_capture_owner != _InputCaptureOwner.MOUSE
			or mouse_button.device != _input_capture_device
		):
			return InputDisposition.IGNORED
		var matches_pan: bool = (
			_mouse_pan_active
			and mouse_button.button_index == _mouse_pan_button
		)
		var matches_selection: bool = (
			_selection_capture_button != MOUSE_BUTTON_NONE
			and mouse_button.button_index == _selection_capture_button
		)
		if not matches_pan and not matches_selection:
			return InputDisposition.IGNORED
		_reset_transient_input()
		return _general_disposition()

	var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
	if (
		screen_touch == null
		or _input_capture_owner != _InputCaptureOwner.RAW_TOUCH
		or screen_touch.device != _input_capture_device
		or not _gesture_tracks_pointer(screen_touch.index)
	):
		return InputDisposition.IGNORED
	_reset_transient_input()
	return _general_disposition()


## 转换画布位置为世界坐标并更新当前放置预览。
## [br]
## @api private
## [br]
func _update_placement_from_canvas_position(canvas_position: Vector2) -> bool:
	var world_position_result: Dictionary = _try_canvas_to_world(canvas_position)
	if not GFVariantData.get_option_bool(world_position_result, "ok"):
		return false
	return update_placement(
		GFVariantData.get_option_vector2(world_position_result, "value")
	)


## 返回第一个精确修饰键绑定的选择模式，未匹配时返回默认模式。
## [br]
## @api private
## [br]
func _selection_mode_from_modifier_mask(modifier_mask: int) -> SelectionMode:
	for binding: GFSpatialCanvasSelectionModeBinding in _input_policy.selection_modifier_bindings:
		if binding != null and binding.modifier_mask == modifier_mask:
			return binding.selection_mode as SelectionMode
	return _input_policy.selection_default_mode as SelectionMode


## 优先匹配显式鼠标按钮，否则按安全的 InputMap action 匹配。
## [br]
## @api private
## [br]
func _matches_pointer_press(
	event: InputEventMouseButton,
	direct_button: MouseButton,
	action: StringName
) -> bool:
	if direct_button != MOUSE_BUTTON_NONE:
		return event.button_index == direct_button
	if action == &"":
		return false
	return _runtime_pointer_action_matches(event, action)


## 按平移按钮及修饰键匹配，或回退到配置的 InputMap action。
## [br]
## @api private
## [br]
func _matches_pan_press(event: InputEventMouseButton) -> bool:
	if _input_policy.pan_mouse_button != MOUSE_BUTTON_NONE:
		return (
			event.button_index == _input_policy.pan_mouse_button
			and _modifier_mask_from_mouse_event(event) == _input_policy.pan_modifier_mask
		)
	if _input_policy.pan_action == &"":
		return false
	return _runtime_pointer_action_matches(event, _input_policy.pan_action)


## 拒绝指针输入或不安全 action 后检查取消 action 是否按下。
## [br]
## @api private
## [br]
func _matches_cancel_action(event: InputEvent) -> bool:
	if _is_pointer_action_event(event):
		return false
	if _input_policy.placement_cancel_action == &"":
		return false
	if not _runtime_cancel_action_is_safe(_input_policy.placement_cancel_action):
		return false
	return event.is_action_pressed(
		_input_policy.placement_cancel_action,
		false,
		true
	)


## 仅在有限 action 事件列表包含非滚轮鼠标按钮时匹配按下事件。
## [br]
## @api private
## [br]
func _runtime_pointer_action_matches(
	event: InputEventMouseButton,
	action: StringName
) -> bool:
	if action == &"" or not InputMap.has_action(action):
		return false
	var action_events: Array[InputEvent] = InputMap.action_get_events(action)
	if action_events.size() > GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS:
		return false
	var has_pointer_event: bool = false
	for action_event: InputEvent in action_events:
		if not action_event is InputEventMouseButton:
			continue
		var mouse_action_event: InputEventMouseButton = action_event
		if (
			not _is_mouse_wheel_button(mouse_action_event.button_index)
			and mouse_action_event.button_index != MOUSE_BUTTON_NONE
		):
			has_pointer_event = true
			break
	if not has_pointer_event:
		return false
	return event.is_action_pressed(action, false, true)


## 检查取消 action 存在且事件列表中没有指针事件。
## [br]
## @api private
## [br]
func _runtime_cancel_action_is_safe(action: StringName) -> bool:
	if action == &"" or not InputMap.has_action(action):
		return false
	var action_events: Array[InputEvent] = InputMap.action_get_events(action)
	if action_events.size() > GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS:
		return false
	for action_event: InputEvent in action_events:
		if _is_pointer_action_event(action_event):
			return false
	return true


## 判断输入事件是否属于鼠标、触摸或手势类别。
## [br]
## @api private
## [br]
func _is_pointer_action_event(event: InputEvent) -> bool:
	return (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventGesture
	)


## 从鼠标事件汇总 shift、ctrl、alt 和 meta 修饰键位。
## [br]
## @api private
## [br]
func _modifier_mask_from_mouse_event(event: InputEventMouseButton) -> int:
	var result: int = GFSpatialCanvasInputPolicy.ModifierMask.NONE
	if event.shift_pressed:
		result |= GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	if event.ctrl_pressed:
		result |= GFSpatialCanvasInputPolicy.ModifierMask.CTRL
	if event.alt_pressed:
		result |= GFSpatialCanvasInputPolicy.ModifierMask.ALT
	if event.meta_pressed:
		result |= GFSpatialCanvasInputPolicy.ModifierMask.META
	return result


## 判断按钮是否为四个鼠标滚轮方向之一。
## [br]
## @api private
## [br]
func _is_mouse_wheel_button(button: MouseButton) -> bool:
	return (
		button == MOUSE_BUTTON_WHEEL_UP
		or button == MOUSE_BUTTON_WHEEL_DOWN
		or button == MOUSE_BUTTON_WHEEL_LEFT
		or button == MOUSE_BUTTON_WHEEL_RIGHT
	)


## 按输入策略的轴向检查滚轮按钮是否匹配。
## [br]
## @api private
## [br]
func _wheel_button_matches_axis(button: MouseButton) -> bool:
	if _input_policy.wheel_axis == GFSpatialCanvasInputPolicy.WheelAxis.VERTICAL:
		return button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN
	return button == MOUSE_BUTTON_WHEEL_LEFT or button == MOUSE_BUTTON_WHEEL_RIGHT


## 从手势快照的 pointer_ids 中查找指定触摸指针。
## [br]
## @api private
## [br]
func _gesture_tracks_pointer(pointer_index: int) -> bool:
	var snapshot: Dictionary = _gesture_utility.get_gesture_snapshot()
	for pointer_value: Variant in GFVariantData.get_option_array(snapshot, "pointer_ids"):
		if not pointer_value is int:
			continue
		var pointer_id: int = pointer_value
		if pointer_id == pointer_index:
			return true
	return false


## 检查策略是否启用多点触摸平移或缩放。
## [br]
## @api private
## [br]
func _has_raw_touch_multi_behavior() -> bool:
	return (
		_input_policy.touch_multi_pan_enabled
		or _input_policy.touch_multi_zoom_enabled
	)


## 空闲时记录捕获类别和设备；后续仅允许同一类别与设备继续持有。
## [br]
## @api private
## [br]
func _acquire_input_capture(capture_owner: _InputCaptureOwner, device: int) -> bool:
	if capture_owner == _InputCaptureOwner.NONE:
		return false
	if _input_capture_owner == _InputCaptureOwner.NONE:
		_input_capture_owner = capture_owner
		_input_capture_device = device
	return _input_capture_owner == capture_owner and _input_capture_device == device


## 仅在捕获类别匹配时清除捕获类别和设备 ID。
## [br]
## @api private
## [br]
func _release_input_capture(capture_owner: _InputCaptureOwner) -> void:
	if _input_capture_owner == capture_owner:
		_input_capture_owner = _InputCaptureOwner.NONE
		_input_capture_device = 0


## 按当前鼠标/原始触摸捕获设备判断互斥输入事件。
## [br]
## @api private
## [br]
func _input_capture_conflicts_with_event(event: InputEvent) -> bool:
	if _input_capture_owner == _InputCaptureOwner.MOUSE:
		return (
			(event is InputEventMouse and event.device != _input_capture_device)
			or event is InputEventScreenTouch
			or event is InputEventScreenDrag
			or event is InputEventPanGesture
			or event is InputEventMagnifyGesture
		)
	if _input_capture_owner == _InputCaptureOwner.RAW_TOUCH:
		return (
			(
				(event is InputEventScreenTouch or event is InputEventScreenDrag)
				and event.device != _input_capture_device
			)
			or event is InputEventMouse
			or event is InputEventPanGesture
			or event is InputEventMagnifyGesture
		)
	return false


## 检查捕获、手势、平移、选择拖动或触摸选择是否仍活动。
## [br]
## @api private
## [br]
func _has_transient_input_state() -> bool:
	return (
		_input_capture_owner != _InputCaptureOwner.NONE
		or _gesture_active
		or _mouse_pan_active
		or _selection_drag_active
		or _selection_capture_button != MOUSE_BUTTON_NONE
		or _touch_selection_index >= 0
	)


## 按 consume_handled_events 将已处理输入映射为 CONSUMED 或 HANDLED。
## [br]
## @api private
## [br]
func _general_disposition() -> InputDisposition:
	if _input_policy.consume_handled_events:
		return InputDisposition.CONSUMED
	return InputDisposition.HANDLED


## 按 consume_wheel_events 将滚轮输入映射为 CONSUMED 或 HANDLED。
## [br]
## @api private
## [br]
func _wheel_disposition() -> InputDisposition:
	if _input_policy.consume_wheel_events:
		return InputDisposition.CONSUMED
	return InputDisposition.HANDLED








## 清除捕获、平移、选择和手势状态，并重置手势工具。
## [br]
## @api private
## [br]
func _reset_transient_input() -> void:
	_input_capture_owner = _InputCaptureOwner.NONE
	_input_capture_device = 0
	_reset_mouse_pan_capture()
	_reset_selection_capture()
	_gesture_active = false
	if _gesture_utility != null:
		_gesture_utility.reset_gesture()


## 清除鼠标平移状态、按钮和上次位置。
## [br]
## @api private
## [br]
func _reset_mouse_pan_capture() -> void:
	_mouse_pan_active = false
	_mouse_pan_button = MOUSE_BUTTON_NONE
	_mouse_pan_last_position = Vector2.ZERO


## 清除鼠标/触摸选择归属并重置拖动矩形。
## [br]
## @api private
## [br]
func _reset_selection_capture() -> void:
	_selection_capture_button = MOUSE_BUTTON_NONE
	_touch_selection_index = -1
	_reset_selection_drag()


## 清除拖动状态和端点，恢复默认选择模式并请求重绘。
## [br]
## @api private
## [br]
func _reset_selection_drag() -> void:
	_selection_drag_active = false
	_selection_drag_start = Vector2.ZERO
	_selection_drag_end = Vector2.ZERO
	_selection_drag_mode = SelectionMode.REPLACE
	_request_overlay_redraw()


## 叠层实例仍有效时请求重绘。
## [br]
## @api private
## [br]
func _request_overlay_redraw() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


## 绘制可见世界范围内的网格线，并记录线数及预算截断状态。
## [br]
## @api private
## [br]
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


## 按当前选择 ID 绘制仍存在条目的轮廓。
## [br]
## @api private
## [br]
func _draw_selection_overlay(target: Control) -> void:
	if not _selected_item_outlines_visible:
		return
	var color: Color = Color(0.25, 0.72, 1.0, 0.95)
	for item_text: String in _selected_ids:
		var item_id: StringName = StringName(item_text)
		if not _items.has(item_id):
			continue
		var item_record: Dictionary = GFVariantData.as_dictionary(_items[item_id])
		var world_rect: Rect2 = _get_option_rect2(item_record, "bounds")
		target.draw_rect(_world_rect_to_canvas_rect(world_rect), color, false, 2.0)


## 将活动放置 footprint 四角变换到画布并绘制预览轮廓。
## [br]
## @api private
## [br]
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


## 拖动选择活动时绘制规范化的选择矩形。
## [br]
## @api private
## [br]
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


## 转换世界矩形起终点后规范化为画布矩形。
## [br]
## @api private
## [br]
func _world_rect_to_canvas_rect(world_rect: Rect2) -> Rect2:
	var start: Vector2 = world_to_canvas(world_rect.position)
	var finish: Vector2 = world_to_canvas(world_rect.end)
	return _normalize_rect(Rect2(start, finish - start))


## 用包含边界的比较判断外矩形是否完全包住内矩形。
## [br]
## @api private
## [br]
func _rect_encloses_rect(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)


## 检查模式是否为 REPLACE、ADD、TOGGLE 或 SUBTRACT。
## [br]
## @api private
## [br]
func _is_selection_mode_valid(mode: SelectionMode) -> bool:
	return (
		mode == SelectionMode.REPLACE
		or mode == SelectionMode.ADD
		or mode == SelectionMode.TOGGLE
		or mode == SelectionMode.SUBTRACT
	)


## 去除字符串两端空白并转换为 StringName。
## [br]
## @api private
## [br]
func _normalize_id(value: StringName) -> StringName:
	return StringName(String(value).strip_edges())


## 将负宽高转换为正尺寸并调整原点以保留覆盖范围。
## [br]
## @api private
## [br]
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


## 拒绝 NaN 和正负无穷浮点值。
## [br]
## @api private
## [br]
func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


## 检查 Vector2 的两个分量均为有限值。
## [br]
## @api private
## [br]
func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


## 检查 Rect2 的位置、尺寸和终点坐标均为有限值。
## [br]
## @api private
## [br]
func _is_finite_rect2(value: Rect2) -> bool:
	return (
		_is_finite_vector2(value.position)
		and _is_finite_vector2(value.size)
		and _is_finite_vector2(value.position + value.size)
	)


## 从选项字典读取 Callable，类型不符时返回无效 Callable。
## [br]
## @api private
## [br]
func _get_callable_option(options: Dictionary, key: String) -> Callable:
	return _get_callable_value(GFVariantData.get_option_value(options, key, Callable()))


## 读取指定选项的 Rect2；字段缺失或类型不符时返回默认矩形。
## [br]
## @api private
## [br]
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


## 将 Variant 收窄为 Callable；类型不符时返回无效 Callable。
## [br]
## @api private
## [br]
func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 要求所有选项键为唯一且已知的 String 或 StringName。
## [br]
## @api private
## [br]
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


## 检查字符串键或对应 StringName 键是否存在。
## [br]
## @api private
## [br]
func _has_option(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))


## 字段缺失时通过；存在时要求值为 bool。
## [br]
## @api private
## [br]
func _option_is_bool(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is bool


## 要求字段存在且值为 bool。
## [br]
## @api private
## [br]
func _option_is_present_bool(options: Dictionary, key: String) -> bool:
	return _has_option(options, key) and GFVariantData.get_option_value(options, key) is bool


## 字段缺失时通过；存在时要求值为 int。
## [br]
## @api private
## [br]
func _option_is_int(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is int


## 字段缺失时通过；存在时要求值为 int 或 float。
## [br]
## @api private
## [br]
func _option_is_numeric(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	var value: Variant = GFVariantData.get_option_value(options, key)
	return value is int or value is float


## 字段缺失时通过；存在时要求值为 Vector2。
## [br]
## @api private
## [br]
func _option_is_vector2(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is Vector2


## 字段缺失时通过；存在时要求值为 Callable。
## [br]
## @api private
## [br]
func _option_is_callable(options: Dictionary, key: String) -> bool:
	if not _has_option(options, key):
		return true
	return GFVariantData.get_option_value(options, key) is Callable


## 把 Vector2 投影为含 x 和 y 的字典。
## [br]
## @api private
## [br]
func _vector_to_json(value: Vector2) -> Dictionary:
	return { "x": value.x, "y": value.y }


## 把 Rect2 投影为 position 与 size 字典。
## [br]
## @api private
## [br]
func _rect_to_json(value: Rect2) -> Dictionary:
	return {
		"position": _vector_to_json(value.position),
		"size": _vector_to_json(value.size),
	}


# --- 信号处理函数 ---

## 从手势快照更新活跃标志，按触摸单指或多指策略选择平移与缩放；缩放以快照中心为锚点。
## [br]
## @api private
func _on_gesture_updated(snapshot: Dictionary, _event: InputEvent) -> void:
	var active: bool = GFVariantData.get_option_bool(snapshot, "active")
	var pointer_count: int = GFVariantData.get_option_int(snapshot, "pointer_count")
	_gesture_active = active and pointer_count > 0
	var source: StringName = GFVariantData.get_option_string_name(snapshot, "source")
	var apply_pan: bool = true
	var apply_zoom: bool = true
	if String(source).begins_with("touch_"):
		if not _input_policy.touch_enabled:
			return
		if pointer_count >= 2:
			apply_pan = _input_policy.touch_multi_pan_enabled
			apply_zoom = _input_policy.touch_multi_zoom_enabled
		else:
			apply_pan = (
				_input_policy.touch_primary_behavior
				== GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.PAN
			)
			apply_zoom = false
	var pan_delta: Vector2 = GFVariantData.get_option_vector2(snapshot, "pan_delta")
	var scale_factor: float = GFVariantData.get_option_float(snapshot, "scale", 1.0)
	var center: Vector2 = GFVariantData.get_option_vector2(snapshot, "center", size * 0.5)
	if apply_pan and not pan_delta.is_zero_approx():
		var _panned: bool = pan_by_canvas_delta(pan_delta)
	if apply_zoom and not is_equal_approx(scale_factor, 1.0):
		var _zoomed: bool = zoom_at(center, scale_factor)




## 清除手势活跃标志并释放 RAW_TOUCH 的输入占用，不释放其他输入来源的捕获。
## [br]
## @api private
func _on_gesture_ended(_snapshot: Dictionary) -> void:
	_gesture_active = false
	_release_input_capture(_InputCaptureOwner.RAW_TOUCH)




## 焦点离开时清除临时输入状态，防止未收到释放事件的拖动或手势延续。
## [br]
## @api private
func _on_focus_exited() -> void:
	_reset_transient_input()
