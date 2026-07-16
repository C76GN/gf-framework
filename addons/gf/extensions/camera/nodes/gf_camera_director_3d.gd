## GFCameraDirector3D: 通用 3D 相机编排节点。
##
## Director 从显式路径或分组中收集 GFCameraRig3D，按优先级选择当前 Rig，
## 并把过渡后的 Transform 应用到 Camera3D。它不规定目标含义、输入来源或业务流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCameraDirector3D
extends Node


const _GF_CAMERA_FINITE_MATH = preload("res://addons/gf/extensions/camera/core/gf_camera_finite_math.gd")
const _SELECTION_AUTO: int = 0
const _SELECTION_MANUAL_EMPTY: int = 1
const _SELECTION_MANUAL_RIG: int = 2


# --- 信号 ---

## 当前 Rig 变化后发出。
## [br]
## @api public
## [br]
## @param previous_rig: 上一个 Rig。
## [br]
## @param new_rig: 新 Rig。
signal active_rig_changed(previous_rig: GFCameraRig3D, new_rig: GFCameraRig3D)

## 相机姿态应用后发出。
## [br]
## @api public
## [br]
## @param rig: 当前 Rig。
signal camera_pose_applied(rig: GFCameraRig3D)


# --- 枚举 ---

## Director 自动更新模式。
## [br]
## @api public
enum UpdateMode {
	## 在 _process 中更新。
	IDLE,
	## 在 _physics_process 中更新。
	PHYSICS,
	## 只在 process_camera() 被显式调用时更新。
	MANUAL,
}


# --- 导出变量 ---

## 要控制的 Camera3D。
## [br]
## @api public
@export_node_path("Camera3D") var camera_path: NodePath = NodePath("")

## 显式候选 Rig 路径。
## [br]
## @api public
## [br]
## @schema rig_paths: Array[NodePath]，按顺序保存显式候选 GFCameraRig3D 节点路径。
@export var rig_paths: Array[NodePath] = []

## 是否按分组收集候选 Rig。
## [br]
## @api public
@export var collect_group_rigs: bool = true

## 候选 Rig 分组名。
## [br]
## @api public
@export var rig_group_name: StringName = &"gf_camera_rig_3d"

## 分组候选 Rig 的收集作用域。为空时使用 Director 父节点。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_node_path("Node") var camera_scope_path: NodePath = NodePath("")

## 分组候选 Rig 的收集频道。为空时只收集默认频道 Rig。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var camera_channel: StringName = &""

## 自动更新模式。
## [br]
## @api public
@export var update_mode: UpdateMode = UpdateMode.IDLE

## 默认过渡资源。Rig 没有设置 blend 时使用它。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var default_blend: GFCameraBlend = null

## 应用姿态时是否显式把 Camera3D 设为当前相机。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var make_current_on_apply: bool = false


# --- 私有变量 ---

var _active_rig: GFCameraRig3D = null
var _blend: GFCameraBlend = null
var _blend_elapsed_seconds: float = 0.0
var _blend_from_transform: Transform3D = Transform3D.IDENTITY
var _is_blending: bool = false
var _selection_mode: int = _SELECTION_AUTO
var _last_process_report: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	default_blend = GFCameraBlend.new()


func _process(delta: float) -> void:
	if update_mode == UpdateMode.IDLE:
		var _process_camera_result_102: Variant = process_camera(delta)


func _physics_process(delta: float) -> void:
	if update_mode == UpdateMode.PHYSICS:
		var _process_camera_result_107: Variant = process_camera(delta)


# --- 公共方法 ---

## 获取当前相机。
## [br]
## @api public
## [br]
## @return Camera3D；不存在时返回 null。
func get_camera() -> Camera3D:
	if camera_path.is_empty():
		return null
	return _get_camera_value(get_node_or_null(camera_path))


## 获取当前激活 Rig。
## [br]
## @api public
## [br]
## @return 当前 Rig；没有时返回 null。
func get_active_rig() -> GFCameraRig3D:
	if _selection_mode == _SELECTION_MANUAL_EMPTY:
		return null
	if _active_rig != null and is_instance_valid(_active_rig) and _active_rig.is_available():
		return _active_rig
	return refresh_active_rig(false)


## 收集候选 Rig。
## [br]
## @api public
## [br]
## @return 候选 Rig 列表。
## [br]
## @schema return: Array[GFCameraRig3D]，已去重并按优先级排序的候选 Rig。
func collect_candidate_rigs() -> Array[GFCameraRig3D]:
	var result: Array[GFCameraRig3D] = []
	var seen: Dictionary = {}
	for rig_path: NodePath in rig_paths:
		var rig: GFCameraRig3D = _get_rig_value(get_node_or_null(rig_path))
		_append_unique_rig(result, seen, rig)

	if collect_group_rigs and is_inside_tree() and rig_group_name != &"":
		for node: Node in get_tree().get_nodes_in_group(rig_group_name):
			var group_rig: GFCameraRig3D = _get_rig_value(node)
			if _is_group_rig_in_scope(group_rig):
				_append_unique_rig(result, seen, group_rig)
	result.sort_custom(_sort_rigs)
	return result


## 刷新当前激活 Rig。
## [br]
## @api public
## [br]
## @param force_snap: 为 true 时立即切到新 Rig。
## [br]
## @return 当前 Rig。
func refresh_active_rig(force_snap: bool = false) -> GFCameraRig3D:
	if _selection_mode == _SELECTION_MANUAL_EMPTY:
		return null
	if _selection_mode == _SELECTION_MANUAL_RIG:
		if _active_rig != null and is_instance_valid(_active_rig) and _active_rig.is_available():
			return _active_rig
		_selection_mode = _SELECTION_AUTO

	var best_rig: GFCameraRig3D = null
	for rig: GFCameraRig3D in collect_candidate_rigs():
		if rig != null and rig.is_available():
			best_rig = rig
			break
	var _set_active_rig_result_166: Variant = _set_active_rig_internal(best_rig, force_snap, false)
	return _active_rig


## 显式设置当前 Rig，并进入手动覆盖模式。
## 手动覆盖模式下，refresh_active_rig() 不会自动切换到更高优先级 Rig；
## 调用 clear_active_rig_override() 后才恢复自动选择。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param rig: 新 Rig；可为 null。
## [br]
## @param force_snap: 为 true 时立即切换。
## [br]
## @return 设置成功返回 true。
func set_active_rig(rig: GFCameraRig3D, force_snap: bool = false) -> bool:
	return _set_active_rig_internal(rig, force_snap, true)


## 清除手动 Rig 覆盖，并立即恢复自动选择。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param force_snap: 为 true 时立即切换。
## [br]
## @return 自动选择后的当前 Rig。
func clear_active_rig_override(force_snap: bool = false) -> GFCameraRig3D:
	_selection_mode = _SELECTION_AUTO
	return refresh_active_rig(force_snap)


## 获取 Director 调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 has_camera、has_active_rig、active_rig_path、active_rig_is_manual_override、is_blending 和 last_process。
func get_debug_snapshot() -> Dictionary:
	var active_rig: GFCameraRig3D = get_active_rig()
	return GFReportValueCodec.to_report_dictionary({
		"has_camera": get_camera() != null,
		"has_active_rig": active_rig != null,
		"active_rig_path": _get_node_debug_path(active_rig),
		"active_rig_name": _get_node_debug_name(active_rig),
		"selection_mode": _get_selection_mode_name(),
		"active_rig_is_manual_override": _selection_mode != _SELECTION_AUTO,
		"is_blending": _is_blending,
		"last_process": _last_process_report.duplicate(true),
	}, GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_DEBUG,
		{ "path_redaction": "none" }
	))


## 推进并应用相机姿态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta: 秒。
## [br]
## @return 本帧实际应用相机姿态时返回 true；无可用 Rig 时返回 false。
func process_camera(delta: float) -> bool:
	var _refresh_active_rig_result_199: Variant = refresh_active_rig(false)
	var camera: Camera3D = get_camera()
	if camera == null:
		_cancel_blend()
		_last_process_report = _make_process_report(false, "missing_camera", camera, _active_rig)
		return false
	if _active_rig == null or not is_instance_valid(_active_rig) or not _active_rig.is_available():
		_cancel_blend()
		_last_process_report = _make_process_report(false, "missing_rig", camera, _active_rig)
		return false

	var target_transform: Transform3D = _active_rig.get_camera_transform()
	if not _GF_CAMERA_FINITE_MATH.is_valid_transform3d(target_transform):
		_cancel_blend()
		_last_process_report = _make_process_report(false, "invalid_target_pose", camera, _active_rig)
		return false
	var transform: Transform3D = target_transform
	if _is_blending:
		_blend_elapsed_seconds += maxf(_GF_CAMERA_FINITE_MATH.sanitize_float(delta, 0.0), 0.0)
		var weight: float = _blend.sample_weight(_blend_elapsed_seconds) if _blend != null else 1.0
		transform = _interpolate_transform(_blend_from_transform, target_transform, weight)
		if weight >= 1.0:
			_is_blending = false
	if not _GF_CAMERA_FINITE_MATH.is_valid_transform3d(transform):
		transform = target_transform
		_is_blending = false

	var applied_rig: GFCameraRig3D = _active_rig
	_apply_transform(camera, transform)
	_last_process_report = _make_process_report(true, "", camera, applied_rig)
	camera_pose_applied.emit(applied_rig)
	return true


# --- 私有/辅助方法 ---

func _prepare_blend(force_snap: bool) -> void:
	var camera: Camera3D = get_camera()
	_blend = _active_rig.blend if _active_rig != null and is_instance_valid(_active_rig) and _active_rig.blend != null else default_blend
	_blend_elapsed_seconds = 0.0
	_blend_from_transform = camera.global_transform if camera != null else Transform3D.IDENTITY
	_is_blending = (
		not force_snap
		and camera != null
		and _active_rig != null
		and is_instance_valid(_active_rig)
		and _GF_CAMERA_FINITE_MATH.is_valid_transform3d(_blend_from_transform)
		and _blend != null
		and not _blend.is_instant()
	)


func _set_active_rig_internal(rig: GFCameraRig3D, force_snap: bool, manual_override: bool) -> bool:
	if rig != null and (not is_instance_valid(rig) or not rig.is_available()):
		return false
	if manual_override:
		_selection_mode = _SELECTION_MANUAL_EMPTY if rig == null else _SELECTION_MANUAL_RIG
	else:
		_selection_mode = _SELECTION_AUTO
	if rig == _active_rig:
		if force_snap:
			_prepare_blend(true)
		return true
	var previous: GFCameraRig3D = _active_rig if _active_rig != null and is_instance_valid(_active_rig) else null
	_active_rig = rig
	_prepare_blend(force_snap)
	active_rig_changed.emit(previous, _active_rig)
	return true


func _interpolate_transform(from_transform: Transform3D, to_transform: Transform3D, weight: float) -> Transform3D:
	if not _GF_CAMERA_FINITE_MATH.is_valid_transform3d(from_transform):
		return to_transform
	var safe_weight: float = clampf(_GF_CAMERA_FINITE_MATH.sanitize_float(weight, 1.0), 0.0, 1.0)
	var origin: Vector3 = from_transform.origin.lerp(to_transform.origin, safe_weight)
	var from_quaternion: Quaternion = Quaternion(from_transform.basis.orthonormalized())
	var to_quaternion: Quaternion = Quaternion(to_transform.basis.orthonormalized())
	var basis: Basis = Basis(from_quaternion.slerp(to_quaternion, safe_weight)).orthonormalized()
	return _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		Transform3D(basis, origin),
		to_transform
	)


func _apply_transform(camera: Camera3D, transform: Transform3D) -> void:
	camera.global_transform = _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		transform,
		Transform3D.IDENTITY
	)
	if make_current_on_apply:
		camera.make_current()


func _cancel_blend() -> void:
	_blend = null
	_blend_elapsed_seconds = 0.0
	_blend_from_transform = Transform3D.IDENTITY
	_is_blending = false


func _get_camera_scope_node() -> Node:
	if not camera_scope_path.is_empty():
		return get_node_or_null(camera_scope_path)
	return get_parent()


func _append_unique_rig(result: Array[GFCameraRig3D], seen: Dictionary, rig: GFCameraRig3D) -> void:
	if rig == null:
		return
	var instance_id: int = rig.get_instance_id()
	if seen.has(instance_id):
		return
	seen[instance_id] = true
	result.append(rig)


func _is_group_rig_in_scope(rig: GFCameraRig3D) -> bool:
	if rig == null:
		return false
	if rig.camera_channel != camera_channel:
		return false
	var director_scope: Node = _get_camera_scope_node()
	var rig_scope: Node = rig.get_camera_scope_node()
	return director_scope != null and rig_scope == director_scope


func _sort_rigs(left: GFCameraRig3D, right: GFCameraRig3D) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return left.get_instance_id() < right.get_instance_id()


func _get_camera_value(value: Variant) -> Camera3D:
	if value is Camera3D:
		var camera: Camera3D = value
		return camera
	return null


func _get_rig_value(value: Variant) -> GFCameraRig3D:
	if value is GFCameraRig3D:
		var rig: GFCameraRig3D = value
		return rig
	return null


func _make_process_report(applied: bool, reason: String, camera: Camera3D, rig: GFCameraRig3D) -> Dictionary:
	return {
		"applied": applied,
		"reason": reason,
		"has_camera": camera != null,
		"has_active_rig": rig != null and is_instance_valid(rig),
		"active_rig_path": _get_node_debug_path(rig),
		"active_rig_name": _get_node_debug_name(rig),
		"selection_mode": _get_selection_mode_name(),
		"active_rig_is_manual_override": _selection_mode != _SELECTION_AUTO,
		"is_blending": _is_blending,
	}


func _get_selection_mode_name() -> String:
	match _selection_mode:
		_SELECTION_MANUAL_EMPTY:
			return "manual_empty"
		_SELECTION_MANUAL_RIG:
			return "manual_rig"
		_:
			return "auto"


func _get_node_debug_path(node: Node) -> String:
	if node != null and is_instance_valid(node) and node.is_inside_tree():
		return String(node.get_path())
	return ""


func _get_node_debug_name(node: Node) -> String:
	if node != null and is_instance_valid(node):
		return String(node.name)
	return ""
