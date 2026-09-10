@tool

## GFScenePlacementOperation: 编辑器内显式场景、父节点与命中位置的单次摆放操作。
##
## 预览只计算变换，不实例化源场景。确认时才通过编辑器撤销历史创建实例。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFScenePlacementOperation
extends GFEditorPickOperation


# --- 常量 ---

const _OPTIONS: Dictionary = {
	"mode": "plane",
	"plane_normal": Vector3.UP,
	"plane_origin": Vector3.ZERO,
	"grid_step": 0.0,
	"align_normal": false,
	"anchor": Vector3.ZERO,
	"yaw_degrees": 0.0,
	"scale": Vector3.ONE,
	"surface_offset": 0.0,
	"max_distance": 10000.0,
}


# --- 私有变量 ---

var _source: PackedScene = null
var _parent_ref: WeakRef = null
var _root_ref: WeakRef = null
var _options: Dictionary = {}
var _source_basis: Basis = Basis.IDENTITY
var _valid_pick: bool = false
var _applying: bool = false


# --- 公共方法 ---

## 配置一次编辑器摆放；活动操作必须先取消。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scene: 显式选择的 PackedScene。
## [br]
## @param parent: 当前编辑场景内的父 Node3D。
## [br]
## @param scene_root: 当前编辑场景根。
## [br]
## @param options: 有限的摆放参数。
## [br]
## @schema options: Dictionary，支持 mode: String (plane/surface)、plane_normal/plane_origin/anchor/scale: Vector3、grid_step/yaw_degrees/surface_offset/max_distance: float、align_normal: bool。
## [br]
## @return 配置错误码；失败不允许产生预览或实例。
func configure(
	scene: PackedScene,
	parent: Node3D,
	scene_root: Node,
	options: Dictionary = {}
) -> Error:
	if _applying or get_state() == State.PICKING or get_state() == State.READY:
		return ERR_BUSY
	_source = null
	_parent_ref = null
	_root_ref = null
	_valid_pick = false
	if scene == null or scene.get_script() != null:
		return ERR_INVALID_PARAMETER
	if not _valid_destination(parent, scene_root):
		return ERR_INVALID_PARAMETER
	if not scene.resource_path.is_empty() and scene.resource_path == scene_root.scene_file_path:
		return ERR_INVALID_PARAMETER
	var parsed: Dictionary = _parse_options(options)
	if parsed.is_empty():
		return ERR_INVALID_PARAMETER
	var source_report: Dictionary = _read_source_root(scene)
	if not _bool_field(source_report, "ok"):
		return ERR_INVALID_DATA
	var basis_value: Variant = source_report.get("basis")
	if not basis_value is Basis:
		return ERR_INVALID_DATA
	_source_basis = basis_value
	_source = scene
	_parent_ref = weakref(parent)
	_root_ref = weakref(scene_root)
	_options = parsed
	operation_id = &"scene_placement"
	label = "Place 3D Scene"
	return OK


## 开始拾取；提交及其同步补偿期间拒绝重入，不改变当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param context: 当前编辑器工具上下文。
## [br]
## @return 成功开始返回 true；正在提交时返回 false。
func begin(context: GFEditorToolContext) -> bool:
	if _applying:
		return false
	return super.begin(context)


## 更新最近命中；提交及其同步补偿期间忽略输入并保留当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param input_data: 视口射线或调用方已经查询到的表面命中。
## [br]
## @schema input_data: Dictionary，平面模式使用 ray_origin/ray_direction: Vector3；表面模式使用 hit: Dictionary，包含 position/normal: Vector3。
## [br]
## @return 本次输入后的操作状态。
func pick(input_data: Dictionary) -> State:
	if _applying:
		return get_state()
	return super.pick(input_data)


## 确认一个实例；同步回调中的再次确认会被拒绝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 确认结果；重入返回 ERR_BUSY，不改变外层确认的状态。
## [br]
## @schema return: Dictionary，至少包含 ok: bool、reason: StringName；实际提交与重入结果另含 error_code: Error、node: Node3D|null。
func apply() -> Dictionary:
	if _applying:
		return _apply_report(ERR_BUSY, &"apply_in_progress")
	_applying = true
	var report: Dictionary = super.apply()
	_applying = false
	return report


## 检查原父节点和编辑场景根是否仍有效。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 父节点仍位于原场景内，且世界变换可逆时返回 true。
func is_destination_valid() -> bool:
	return _source != null and _valid_destination(_get_parent_node(), _get_root_node())


# --- 可重写钩子 / 虚方法 ---

## 计算一次平面或碰撞命中的纯变换预览。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param input_data: 平面模式提供 ray_origin/ray_direction；表面模式提供 hit。
## [br]
## @schema input_data: Dictionary，ray_origin/ray_direction 为 Vector3；hit 为包含 position/normal: Vector3 的 Dictionary。表面模式可附射线以检查最大距离。
## [br]
## @return 分阶段拾取响应；任何无效输入都会清除上一有效命中。
## [br]
## @schema return: Dictionary，preview/result 包含 valid: bool、world_transform/local_transform: Transform3D、position/normal: Vector3、reason: StringName；local_transform 是父坐标换算值，top_level 根确认后的原生 transform 使用 world_transform；ready: bool 表示是否可确认。
func _on_pick(input_data: Dictionary) -> Dictionary:
	_valid_pick = false
	if not is_destination_valid():
		return _failed_pick(&"destination_unavailable")
	var hit: Dictionary = _resolve_hit(input_data)
	if not _bool_field(hit, "ok"):
		return _failed_pick(&"no_hit")
	var position: Vector3 = _vector_field(hit, "position")
	var normal: Vector3 = _vector_field(hit, "normal").normalized()
	var grid_step: float = _number_field(_options, "grid_step")
	if grid_step > 0.0:
		var grid_report: Dictionary = GFTransform3DMath.snap_point_to_plane_grid(
			position,
			normal,
			grid_step,
			_vector_field(_options, "plane_origin")
		)
		if not _bool_field(grid_report, "ok"):
			return _failed_pick(&"invalid_grid")
		position = _vector_field(grid_report, "point")
	position += normal * _number_field(_options, "surface_offset")
	var basis: Basis = _source_basis
	var yaw_axis: Vector3 = Vector3.UP
	if _bool_field(_options, "align_normal"):
		basis = Basis(Quaternion(basis.y.normalized(), normal)) * basis
		yaw_axis = normal
	basis = Basis(yaw_axis, deg_to_rad(_number_field(_options, "yaw_degrees"))) * basis
	var local_scale: Vector3 = _vector_field(_options, "scale")
	basis = Basis(basis.x * local_scale.x, basis.y * local_scale.y, basis.z * local_scale.z)
	var world_transform: Transform3D = GFTransform3DMath.move_local_point_to_world(
		Transform3D(basis, Vector3.ZERO),
		_vector_field(_options, "anchor"),
		position
	)
	var parent: Node3D = _get_parent_node()
	var local_transform: Transform3D = parent.global_transform.affine_inverse() * world_transform
	if not world_transform.is_finite() or not local_transform.is_finite():
		return _failed_pick(&"invalid_transform")
	_valid_pick = true
	var preview: Dictionary = {
		"valid": true,
		"world_transform": world_transform,
		"local_transform": local_transform,
		"position": position,
		"normal": normal,
		"reason": &"",
	}
	return { "preview": preview, "result": preview, "ready": true }


## 检查最近命中与原目标仍可应用。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 最近命中有效且目标仍有效时返回 true。
func _on_can_apply() -> bool:
	return _valid_pick and is_destination_valid()


## 确认时创建一个原生可撤销动作，不以注册成功冒充实例创建成功。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param tool_context: 必须提供 undo_manager 和同一个 edited_scene_root。
## [br]
## @param result: 最近有效变换。
## [br]
## @schema result: Dictionary，world_transform 为 Transform3D。
## [br]
## @return 本次确认结果。
## [br]
## @schema return: Dictionary，包含 ok: bool、error_code: Error、reason: StringName、node: Node3D|null。
func _on_apply(tool_context: GFEditorToolContext, result: Dictionary) -> Dictionary:
	if tool_context == null or tool_context.undo_manager == null:
		return _apply_report(ERR_UNCONFIGURED, &"undo_manager_required")
	for method_name: StringName in [&"create_action", &"add_do_method", &"add_undo_method", &"commit_action"]:
		if not tool_context.undo_manager.has_method(method_name):
			return _apply_report(ERR_INVALID_PARAMETER, &"undo_manager_incompatible")
	if tool_context.edited_scene_root != _get_root_node() or not is_destination_valid():
		return _apply_report(ERR_UNAVAILABLE, &"destination_unavailable")
	var transform_value: Variant = result.get("world_transform")
	if not transform_value is Transform3D:
		return _apply_report(ERR_INVALID_DATA, &"invalid_transform")
	var world_transform: Transform3D = transform_value
	var command: GFScenePlacementCreateCommand = GFScenePlacementCreateCommand.new()
	command.configure(_source, _get_parent_node(), _get_root_node(), world_transform)
	var execute_error: Error = command.execute()
	if execute_error != OK or not command.is_executed():
		return _apply_report(execute_error if execute_error != OK else ERR_CANT_CREATE, &"creation_failed")
	if not is_destination_valid() or get_state() != State.READY:
		var _revert_error: Error = command.revert()
		return _apply_report(ERR_UNAVAILABLE, &"operation_interrupted")
	var register_error: Error = command.add_to_undo_manager(tool_context.undo_manager, false)
	if register_error != OK:
		var _revert_error: Error = command.revert()
		return _apply_report(register_error, &"history_rejected")
	var report: Dictionary = _apply_report(OK, &"")
	report["node"] = command.get_instance()
	return report


## 取消会释放源资源与目标引用，不修改任何场景。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _tool_context: 原拾取上下文。
func _on_cancel(_tool_context: GFEditorToolContext) -> void:
	_valid_pick = false
	_source = null
	_parent_ref = null
	_root_ref = null


# --- 私有/辅助方法 ---

func _parse_options(options: Dictionary) -> Dictionary:
	var parsed: Dictionary = _OPTIONS.duplicate()
	for key: Variant in options:
		if not key is String or not _OPTIONS.has(key):
			return {}
		var value: Variant = options[key]
		var expected: Variant = _OPTIONS[key]
		if expected is Vector3:
			if not value is Vector3:
				return {}
			var vector: Vector3 = value
			if not _valid_vector(vector):
				return {}
		elif expected is float:
			if not value is float and not value is int:
				return {}
			var option_key: String = key
			var number: float = _number_field(options, option_key)
			if not is_finite(number) or absf(number) > 1000000.0:
				return {}
		elif typeof(value) != typeof(expected):
			return {}
		parsed[key] = value
	if parsed["mode"] != "plane" and parsed["mode"] != "surface":
		return {}
	if _vector_field(parsed, "plane_normal").length_squared() < 0.000000000001:
		return {}
	var scale_value: Vector3 = _vector_field(parsed, "scale").abs()
	if minf(scale_value.x, minf(scale_value.y, scale_value.z)) < 0.000001:
		return {}
	var grid: float = _number_field(parsed, "grid_step")
	if grid < 0.0 or (grid > 0.0 and grid <= 0.000001):
		return {}
	var distance: float = _number_field(parsed, "max_distance")
	if distance <= 0.0 or distance > 100000.0:
		return {}
	return parsed


func _read_source_root(scene: PackedScene) -> Dictionary:
	var state: SceneState = scene.get_state()
	var root_type: StringName = &""
	var basis: Basis = Basis.IDENTITY
	var found_transform: bool = false
	var depth: int = 0
	while state != null:
		depth += 1
		if depth > 32 or state.get_node_count() == 0 or state.get_node_property_count(0) > 4096:
			return {}
		if root_type == &"":
			root_type = state.get_node_type(0)
		if not found_transform:
			for index: int in range(state.get_node_property_count(0)):
				if state.get_node_property_name(0, index) != &"transform":
					continue
				var value: Variant = state.get_node_property_value(0, index)
				if not value is Transform3D:
					return {}
				var transform: Transform3D = value
				if not transform.is_finite() or absf(transform.basis.determinant()) <= 0.00000001:
					return {}
				basis = transform.basis
				found_transform = true
		state = state.get_base_scene_state()
	if root_type != &"Node3D" and not ClassDB.is_parent_class(root_type, &"Node3D"):
		return {}
	return { "ok": true, "basis": basis }


func _resolve_hit(input_data: Dictionary) -> Dictionary:
	var origin_value: Variant = input_data.get("ray_origin")
	var direction_value: Variant = input_data.get("ray_direction")
	var max_distance: float = _number_field(_options, "max_distance")
	if _options["mode"] == "plane":
		if not origin_value is Vector3 or not direction_value is Vector3:
			return {}
		var origin: Vector3 = origin_value
		var direction: Vector3 = direction_value
		if not _valid_vector(origin) or not _valid_vector(direction):
			return {}
		return GFTransform3DMath.intersect_ray_plane(
			origin, direction, _vector_field(_options, "plane_normal"),
			_vector_field(_options, "plane_origin"), max_distance
		)
	var hit_value: Variant = input_data.get("hit")
	if not hit_value is Dictionary:
		return {}
	var hit: Dictionary = hit_value
	var position_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not position_value is Vector3 or not normal_value is Vector3:
		return {}
	var position: Vector3 = position_value
	var normal: Vector3 = normal_value
	if not _valid_vector(position) or not _valid_vector(normal) or normal.length_squared() < 0.000000000001:
		return {}
	if origin_value is Vector3:
		var origin: Vector3 = origin_value
		if not _valid_vector(origin) or origin.distance_to(position) > max_distance:
			return {}
	return { "ok": true, "position": position, "normal": normal }


func _failed_pick(reason: StringName) -> Dictionary:
	var preview: Dictionary = {
		"valid": false,
		"world_transform": Transform3D.IDENTITY,
		"local_transform": Transform3D.IDENTITY,
		"position": Vector3.ZERO,
		"normal": Vector3.ZERO,
		"reason": reason,
	}
	return { "preview": preview, "result": preview, "ready": false }


func _apply_report(error: Error, reason: StringName) -> Dictionary:
	return { "ok": error == OK, "error_code": error, "reason": reason, "node": null }


func _get_parent_node() -> Node3D:
	if _parent_ref != null:
		var value: Variant = _parent_ref.get_ref()
		if value is Node3D:
			var parent: Node3D = value
			return parent
	return null


func _get_root_node() -> Node:
	if _root_ref != null:
		var value: Variant = _root_ref.get_ref()
		if value is Node:
			var root: Node = value
			return root
	return null


func _valid_destination(parent: Node3D, root: Node) -> bool:
	return (
		is_instance_valid(parent) and is_instance_valid(root)
		and not parent.is_queued_for_deletion() and not root.is_queued_for_deletion()
		and parent.is_inside_tree() and root.is_inside_tree()
		and (parent == root or root.is_ancestor_of(parent))
		and parent.global_transform.is_finite()
		and absf(parent.global_transform.basis.determinant()) > 0.00000001
	)


func _valid_vector(value: Vector3) -> bool:
	return value.is_finite() and maxf(absf(value.x), maxf(absf(value.y), absf(value.z))) <= 1000000.0


func _vector_field(data: Dictionary, key: String) -> Vector3:
	var value: Variant = data.get(key)
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


func _number_field(data: Dictionary, key: String) -> float:
	var value: Variant = data.get(key)
	if value is float:
		var number: float = value
		return number
	if value is int:
		var number: int = value
		return float(number)
	return 0.0


func _bool_field(data: Dictionary, key: String) -> bool:
	var value: Variant = data.get(key)
	if value is bool:
		var flag: bool = value
		return flag
	return false
