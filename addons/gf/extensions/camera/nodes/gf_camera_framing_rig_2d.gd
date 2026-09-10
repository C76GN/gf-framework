## GFCameraFramingRig2D: 根据显式目标锚点计算共同入镜的二维相机姿态。
##
## 目标位置按期望相机旋转投影，再由实际 Camera2D 输出 Viewport 的尺寸计算统一缩放。
## 只计算锚点，不推断精灵、碰撞或项目对象的外形；目标路径的选择和维护属于调用方。
## 复用基础 Rig 的 active、priority、作用域、blend、offset 和旋转偏移。
## 单目标字段 target_path、use_target_rotation 与固定 zoom 不参与群体取景。
## fits 仅表示期望姿态下的锚点几何，不能保证混合途中、原生限位、拖拽或平滑后的画面。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFCameraFramingRig2D
extends GFCameraRig2D


# --- 常量 ---

const _MAX_TARGET_PATHS: int = 256
const _MAX_OPTION_VALUE: float = 1000000.0
const _MIN_ZOOM: float = 0.0001


# --- 导出变量 ---

## 相对于本 Rig 的目标路径；每次求值重新解析，最多 256 项。
## 缺失、离树、排队释放和重复的目标被忽略；没有有效目标时 Rig 不可选。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema target_paths: Array[NodePath]，每项指向与输出 Viewport 世界画布一致的 Node2D 锚点。
@export var target_paths: Array[NodePath] = []

## 输出 Viewport 左右、上下各自保留的像素边距；必须有限且位于 0 到 1000000。
## [br]
## @api public
## [br]
## @since unreleased
@export var viewport_margin: Vector2 = Vector2(16.0, 16.0)

## 最小统一缩放；必须位于 0.0001 到 max_zoom。约束导致真实锚点超出边距区域时 fits 为 false。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0.0001, 1000000.0, 0.001) var min_zoom: float = 0.1

## 最大统一缩放；必须位于 min_zoom 到 1000000。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0.0001, 1000000.0, 0.001) var max_zoom: float = 10.0

## 相机轴坐标内最小世界宽高；各分量必须有限、大于零且不超过 1000000。
## 单目标、重合目标或共线目标以此避免零尺寸除法。
## [br]
## @api public
## [br]
## @since unreleased
@export var min_extent: Vector2 = Vector2.ONE


# --- 公共方法 ---

## 计算实际 Camera2D 对应的共同入镜报告，不修改相机、目标或 Viewport。
## camera.custom_viewport 为 Viewport 时使用它，否则使用 camera.get_viewport()。
## 只支持中心锚定模式；ignore_rotation 生效时按零角计算，原生 offset 会反向补偿。
## bounds 表示旋转到期望相机轴后的原始目标包围矩形；边距使用输出 Viewport 像素。
## 自身 basis 必须有限且非退化；不修改相机缩放来补救无法应用的旋转。
## 目标与输出世界画布不一致、非有限数值、配置越界或无可用尺寸均明确失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param camera: 将接收姿态的、已入树且自身 basis 有限非退化、父变换可逆的 Camera2D。
## [br]
## @return 纯值报告；ok 为 true 时可应用，fits 独立判断真实锚点能否入镜，不把 min_extent 的人为留白视为目标。
## [br]
## @schema return: Dictionary，包含 ok: bool、reason: StringName、target_count: int、ignored_target_count: int、viewport_size: Vector2、bounds: Rect2、position: Vector2、rotation: float、zoom: float、required_zoom: float、fits: bool 和 zoom_limited: bool。失败时不提供可应用的姿态。
func get_framing_report(camera: Camera2D) -> Dictionary:
	var report: Dictionary = _make_report()
	var configuration_error: StringName = _get_configuration_error()
	if configuration_error != &"":
		return _fail_report(report, configuration_error)
	if not is_inside_tree() or is_queued_for_deletion() or not active:
		return _fail_report(report, &"inactive_rig")
	if not is_instance_valid(camera) or not camera.is_inside_tree() or camera.is_queued_for_deletion():
		return _fail_report(report, &"missing_camera")
	if camera.anchor_mode != Camera2D.ANCHOR_MODE_DRAG_CENTER:
		return _fail_report(report, &"unsupported_camera_anchor")
	if not _is_valid_camera_transform(camera):
		return _fail_report(report, &"invalid_camera_transform")
	if not _is_finite_vector(camera.offset):
		return _fail_report(report, &"invalid_camera_offset")

	var viewport: Viewport = camera.get_viewport()
	var custom_viewport: Node = camera.custom_viewport
	if is_instance_valid(custom_viewport) and custom_viewport is Viewport:
		viewport = custom_viewport
	if not is_instance_valid(viewport) or not viewport.is_inside_tree() or viewport.is_queued_for_deletion():
		return _fail_report(report, &"missing_viewport")
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	report["viewport_size"] = viewport_size
	var available_size: Vector2 = viewport_size - viewport_margin * 2.0
	if not _is_finite_vector(available_size) or available_size.x <= 0.0 or available_size.y <= 0.0:
		return _fail_report(report, &"invalid_viewport_size")

	var targets: Array[Node2D] = _collect_targets()
	report["target_count"] = targets.size()
	report["ignored_target_count"] = target_paths.size() - targets.size()
	if targets.is_empty():
		return _fail_report(report, &"empty_targets")
	var framing_rotation: float = 0.0 if camera.ignore_rotation else global_rotation + deg_to_rad(rotation_degrees_offset)
	if not is_finite(framing_rotation):
		return _fail_report(report, &"invalid_rotation")
	var viewport_canvas: RID = viewport.find_world_2d().canvas
	var bounds: Rect2 = Rect2()
	var first_target: bool = true
	for target: Node2D in targets:
		if target.get_canvas() != viewport_canvas:
			return _fail_report(report, &"target_canvas_mismatch")
		var target_position: Vector2 = target.global_position.rotated(-framing_rotation)
		if not _is_finite_vector(target_position):
			return _fail_report(report, &"invalid_target_position")
		if first_target:
			bounds = Rect2(target_position, Vector2.ZERO)
			first_target = false
		else:
			bounds = bounds.expand(target_position)
	if not _is_finite_vector(bounds.position) or not _is_finite_vector(bounds.size):
		return _fail_report(report, &"invalid_target_bounds")

	var world_offset: Vector2 = offset.rotated(framing_rotation) if offset_follows_rotation else offset
	var axis_offset: Vector2 = world_offset.rotated(-framing_rotation)
	var half_extent: Vector2 = (bounds.size * 0.5).max(min_extent * 0.5) + axis_offset.abs()
	var required_zoom: float = minf(available_size.x / (half_extent.x * 2.0), available_size.y / (half_extent.y * 2.0))
	var framing_zoom: float = clampf(required_zoom, min_zoom, max_zoom)
	var framing_position: Vector2 = bounds.get_center().rotated(framing_rotation) + world_offset - camera.offset
	if (
		not is_finite(required_zoom)
		or required_zoom <= 0.0
		or not _is_finite_vector(framing_position)
	):
		return _fail_report(report, &"invalid_derived_pose")
	var actual_pixel_extent: Vector2 = (bounds.size * 0.5 + axis_offset.abs()) * framing_zoom
	var fits: bool = (
		actual_pixel_extent.x <= available_size.x * 0.5 + 0.001
		and actual_pixel_extent.y <= available_size.y * 0.5 + 0.001
	)
	report["ok"] = true
	report["reason"] = &"" if fits else &"min_zoom_limited"
	report["bounds"] = bounds
	report["position"] = framing_position
	report["rotation"] = framing_rotation
	report["zoom"] = framing_zoom
	report["required_zoom"] = required_zoom
	report["fits"] = fits
	report["zoom_limited"] = framing_zoom != required_zoom
	return report


## 获取共同入镜的期望姿态，供现有 Director 选择和混合。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param camera: 实际接收姿态的 Camera2D；未提供时明确失败，不猜测全局 Viewport。
## [br]
## @return 有效时返回姿态；失败返回空字典，细节可通过 get_framing_report() 查询。
## [br]
## @schema return: Dictionary，成功包含 position: Vector2、rotation: float、zoom: Vector2 与 rig: GFCameraFramingRig2D；失败为空。
func get_camera_pose(camera: Camera2D = null) -> Dictionary:
	var report: Dictionary = get_framing_report(camera)
	if not GFVariantData.get_option_bool(report, "ok"):
		return {}
	return {
		"position": GFVariantData.get_option_vector2(report, "position"),
		"rotation": GFVariantData.get_option_float(report, "rotation"),
		"zoom": Vector2.ONE * GFVariantData.get_option_float(report, "zoom"),
		"rig": self,
	}


## 检查配置和目标是否允许 Director 选择本 Rig。
## 输出 Camera2D 的尺寸、画布与变换在计算姿态时进一步验证。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已入树、启用、配置有效且至少有一个有效锚点时返回 true。
func is_available() -> bool:
	return (
		active
		and is_inside_tree()
		and not is_queued_for_deletion()
		and _get_configuration_error() == &""
		and not _collect_targets().is_empty()
	)


# --- 私有/辅助方法 ---

func _get_configuration_error() -> StringName:
	if target_paths.size() > _MAX_TARGET_PATHS:
		return &"target_limit"
	if (
		not _is_finite_vector(viewport_margin)
		or viewport_margin.x < 0.0 or viewport_margin.y < 0.0
		or viewport_margin.x > _MAX_OPTION_VALUE or viewport_margin.y > _MAX_OPTION_VALUE
	):
		return &"invalid_margin"
	if (
		not _is_finite_vector(min_extent)
		or min_extent.x <= 0.0 or min_extent.y <= 0.0
		or min_extent.x > _MAX_OPTION_VALUE or min_extent.y > _MAX_OPTION_VALUE
	):
		return &"invalid_min_extent"
	if (
		not is_finite(min_zoom) or not is_finite(max_zoom)
		or min_zoom < _MIN_ZOOM or max_zoom < min_zoom or max_zoom > _MAX_OPTION_VALUE
	):
		return &"invalid_zoom_limits"
	if not _is_finite_vector(offset) or not is_finite(rotation_degrees_offset):
		return &"invalid_rig_offset"
	return &""


func _collect_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_inside_tree() or target_paths.size() > _MAX_TARGET_PATHS:
		return result
	var seen: Dictionary[int, bool] = {}
	for path: NodePath in target_paths:
		if path.is_empty():
			continue
		var node: Node = get_node_or_null(path)
		if not (node is Node2D) or not node.is_inside_tree() or node.is_queued_for_deletion():
			continue
		var instance_id: int = node.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		var target: Node2D = node
		result.append(target)
	return result


func _is_valid_camera_transform(camera: Camera2D) -> bool:
	var camera_transform: Transform2D = camera.transform
	var camera_determinant: float = camera_transform.determinant()
	if (
		not _is_finite_vector(camera_transform.x)
		or not _is_finite_vector(camera_transform.y)
		or not is_finite(camera_determinant)
		or camera_determinant == 0.0
	):
		return false
	if camera.top_level:
		return true
	var parent_node: Node = camera.get_parent()
	if not (parent_node is CanvasItem):
		return true
	var parent: CanvasItem = parent_node
	var parent_transform: Transform2D = parent.get_global_transform()
	var determinant: float = parent_transform.determinant()
	return (
		_is_finite_vector(parent_transform.x)
		and _is_finite_vector(parent_transform.y)
		and _is_finite_vector(parent_transform.origin)
		and is_finite(determinant)
		and absf(determinant) > 0.000001
	)


func _make_report() -> Dictionary:
	return {
		"ok": false,
		"reason": &"",
		"target_count": 0,
		"ignored_target_count": 0,
		"viewport_size": Vector2.ZERO,
		"bounds": Rect2(),
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"zoom": 0.0,
		"required_zoom": 0.0,
		"fits": false,
		"zoom_limited": false,
	}


func _fail_report(report: Dictionary, reason: StringName) -> Dictionary:
	report["reason"] = reason
	return report


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
