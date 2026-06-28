## GFCameraDirector2D: 通用 2D 相机编排节点。
##
## Director 从显式路径或分组中收集 GFCameraRig2D，按优先级选择当前 Rig，
## 并把过渡后的姿态应用到 Camera2D。它不规定目标含义、输入来源或业务流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCameraDirector2D
extends Node


# --- 信号 ---

## 当前 Rig 变化后发出。
## [br]
## @api public
## [br]
## @param previous_rig: 上一个 Rig。
## [br]
## @param new_rig: 新 Rig。
signal active_rig_changed(previous_rig: GFCameraRig2D, new_rig: GFCameraRig2D)

## 相机姿态应用后发出。
## [br]
## @api public
## [br]
## @param rig: 当前 Rig。
signal camera_pose_applied(rig: GFCameraRig2D)


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

## 要控制的 Camera2D。
## [br]
## @api public
@export_node_path("Camera2D") var camera_path: NodePath = NodePath("")

## 显式候选 Rig 路径。
## [br]
## @api public
## [br]
## @schema rig_paths: Array[NodePath]，按顺序保存显式候选 GFCameraRig2D 节点路径。
@export var rig_paths: Array[NodePath] = []

## 是否按分组收集候选 Rig。
## [br]
## @api public
@export var collect_group_rigs: bool = true

## 候选 Rig 分组名。
## [br]
## @api public
@export var rig_group_name: StringName = &"gf_camera_rig_2d"

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

## 没有 Rig 时是否保持相机当前姿态。
## [br]
## @api public
@export var keep_camera_when_no_rig: bool = true

## 应用姿态时是否显式把 Camera2D 设为当前相机。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var make_current_on_apply: bool = false


# --- 私有变量 ---

var _active_rig: GFCameraRig2D = null
var _blend: GFCameraBlend = null
var _blend_elapsed_seconds: float = 0.0
var _blend_from_pose: Dictionary = {}
var _is_blending: bool = false
var _active_rig_is_manual_override: bool = false


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
## @return Camera2D；不存在时返回 null。
func get_camera() -> Camera2D:
	if camera_path.is_empty():
		return null
	return _get_camera_value(get_node_or_null(camera_path))


## 获取当前激活 Rig。
## [br]
## @api public
## [br]
## @return 当前 Rig；没有时返回 null。
func get_active_rig() -> GFCameraRig2D:
	_prune_active_rig()
	return _active_rig


## 收集候选 Rig。
## [br]
## @api public
## [br]
## @return 候选 Rig 列表。
## [br]
## @schema return: Array[GFCameraRig2D]，已去重并按优先级排序的候选 Rig。
func collect_candidate_rigs() -> Array[GFCameraRig2D]:
	var result: Array[GFCameraRig2D] = []
	var seen: Dictionary = {}
	for rig_path: NodePath in rig_paths:
		var rig: GFCameraRig2D = _get_rig_value(get_node_or_null(rig_path))
		_append_unique_rig(result, seen, rig)

	if collect_group_rigs and is_inside_tree() and rig_group_name != &"":
		for node: Node in get_tree().get_nodes_in_group(rig_group_name):
			_append_unique_rig(result, seen, _get_rig_value(node))
	result.sort_custom(_sort_rigs)
	return result


## 刷新当前激活 Rig。
## [br]
## @api public
## [br]
## @param force_snap: 为 true 时立即切到新 Rig。
## [br]
## @return 当前 Rig。
func refresh_active_rig(force_snap: bool = false) -> GFCameraRig2D:
	_prune_active_rig()
	if _active_rig_is_manual_override:
		return _active_rig

	var best_rig: GFCameraRig2D = null
	for rig: GFCameraRig2D in collect_candidate_rigs():
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
func set_active_rig(rig: GFCameraRig2D, force_snap: bool = false) -> bool:
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
func clear_active_rig_override(force_snap: bool = false) -> GFCameraRig2D:
	_active_rig_is_manual_override = false
	return refresh_active_rig(force_snap)


## 推进并应用相机姿态。
## [br]
## @api public
## [br]
## @param delta: 秒。
## [br]
## @return 成功应用时返回 true。
func process_camera(delta: float) -> bool:
	var _refresh_active_rig_result_199: Variant = refresh_active_rig(false)
	var camera: Camera2D = get_camera()
	if camera == null:
		return false
	if _active_rig == null or not is_instance_valid(_active_rig) or not _active_rig.is_available():
		return keep_camera_when_no_rig

	var target_pose: Dictionary = _active_rig.get_camera_pose()
	var pose: Dictionary = target_pose
	if _is_blending:
		_blend_elapsed_seconds += maxf(delta, 0.0)
		var weight: float = _blend.sample_weight(_blend_elapsed_seconds) if _blend != null else 1.0
		pose = _interpolate_pose(_blend_from_pose, target_pose, weight)
		if weight >= 1.0:
			_is_blending = false

	_apply_pose(camera, pose)
	camera_pose_applied.emit(_active_rig)
	return true


# --- 私有/辅助方法 ---

func _prepare_blend(force_snap: bool) -> void:
	var camera: Camera2D = get_camera()
	_blend = _active_rig.blend if _active_rig != null and is_instance_valid(_active_rig) and _active_rig.blend != null else default_blend
	_blend_elapsed_seconds = 0.0
	_blend_from_pose = _get_camera_pose(camera)
	_is_blending = (
		not force_snap
		and camera != null
		and _active_rig != null
		and is_instance_valid(_active_rig)
		and _blend != null
		and not _blend.is_instant()
	)


func _set_active_rig_internal(rig: GFCameraRig2D, force_snap: bool, manual_override: bool) -> bool:
	if rig != null and (not is_instance_valid(rig) or not rig.is_available()):
		return false
	if manual_override:
		_active_rig_is_manual_override = true
	if rig == _active_rig:
		if force_snap:
			_prepare_blend(true)
		return true
	var previous: GFCameraRig2D = _active_rig if _active_rig != null and is_instance_valid(_active_rig) else null
	_active_rig = rig
	_prepare_blend(force_snap)
	active_rig_changed.emit(previous, _active_rig)
	return true


func _prune_active_rig() -> void:
	if _active_rig == null:
		return
	if is_instance_valid(_active_rig) and _active_rig.is_available():
		return
	var previous: GFCameraRig2D = _active_rig if is_instance_valid(_active_rig) else null
	_active_rig = null
	_active_rig_is_manual_override = false
	_prepare_blend(true)
	active_rig_changed.emit(previous, null)


func _get_camera_pose(camera: Camera2D) -> Dictionary:
	if camera == null:
		return {
			"position": Vector2.ZERO,
			"rotation": 0.0,
			"zoom": Vector2.ONE,
		}
	return {
		"position": camera.global_position,
		"rotation": camera.global_rotation,
		"zoom": camera.zoom,
	}


func _interpolate_pose(from_pose: Dictionary, to_pose: Dictionary, weight: float) -> Dictionary:
	var safe_weight: float = clampf(weight, 0.0, 1.0)
	var from_position: Vector2 = GFVariantData.get_option_vector2(from_pose, "position")
	var to_position: Vector2 = GFVariantData.get_option_vector2(to_pose, "position")
	var from_zoom: Vector2 = GFVariantData.get_option_vector2(from_pose, "zoom", Vector2.ONE)
	var to_zoom: Vector2 = GFVariantData.get_option_vector2(to_pose, "zoom", Vector2.ONE)
	return {
		"position": from_position.lerp(to_position, safe_weight),
		"rotation": lerp_angle(
			GFVariantData.get_option_float(from_pose, "rotation"),
			GFVariantData.get_option_float(to_pose, "rotation"),
			safe_weight
		),
		"zoom": from_zoom.lerp(to_zoom, safe_weight),
		"rig": GFVariantData.get_option_value(to_pose, "rig"),
	}


func _apply_pose(camera: Camera2D, pose: Dictionary) -> void:
	camera.global_position = GFVariantData.get_option_vector2(pose, "position", camera.global_position)
	camera.global_rotation = GFVariantData.get_option_float(pose, "rotation", camera.global_rotation)
	camera.zoom = GFVariantData.get_option_vector2(pose, "zoom", camera.zoom)
	if make_current_on_apply:
		_make_camera_current(camera)


func _make_camera_current(camera: Camera2D) -> void:
	if camera == null:
		return
	if camera.has_method("make_current"):
		camera.call("make_current")
		return
	camera.enabled = true


func _append_unique_rig(result: Array[GFCameraRig2D], seen: Dictionary, rig: GFCameraRig2D) -> void:
	if rig == null:
		return
	var instance_id: int = rig.get_instance_id()
	if seen.has(instance_id):
		return
	seen[instance_id] = true
	result.append(rig)


func _sort_rigs(left: GFCameraRig2D, right: GFCameraRig2D) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return left.get_instance_id() < right.get_instance_id()


func _get_camera_value(value: Variant) -> Camera2D:
	if value is Camera2D:
		var camera: Camera2D = value
		return camera
	return null


func _get_rig_value(value: Variant) -> GFCameraRig2D:
	if value is GFCameraRig2D:
		var rig: GFCameraRig2D = value
		return rig
	return null
