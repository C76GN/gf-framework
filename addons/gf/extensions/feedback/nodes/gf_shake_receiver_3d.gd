## GFShakeReceiver3D: 将反馈采样应用到 Node3D 的通用接收器。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFShakeReceiver3D
extends Node


# --- 常量 ---

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 导出变量 ---

## 目标 Node3D 路径；为空时优先使用自身，其次使用父节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node3D") var target_path: NodePath = NodePath(""):
	set(value):
		if target_path == value:
			return
		if is_inside_tree():
			var _reset_to_base_result: Variant = reset_to_base()
		target_path = value
		if is_inside_tree():
			_rebind_target(capture_on_ready)

## 采样 channel。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var channel: StringName = &"default"

## 是否应用 position 偏移。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var apply_position: bool = true

## 是否应用 rotation_degrees 偏移。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var apply_rotation: bool = true

## 是否应用 scale 偏移。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var apply_scale: bool = false

## ready 时是否记录基础变换。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var capture_on_ready: bool = true

## 退出树时是否恢复基础变换。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var restore_on_exit: bool = true


# --- 公共变量 ---

## 可选反馈工具实例；为空时从全局架构查询。
## [br]
## @api public
## [br]
## @since 3.17.0
var utility: GFShakeUtility = null


# --- 私有变量 ---

var _target_ref: WeakRef = null
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation_degrees: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _has_captured_base: bool = false
var _last_position_offset: Vector3 = Vector3.ZERO
var _last_rotation_offset: Vector3 = Vector3.ZERO
var _last_scale_offset: Vector3 = Vector3.ZERO


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_rebind_target(capture_on_ready)


func _process(_delta: float) -> void:
	var _apply_current_sample_result_83: Variant = apply_current_sample()


func _exit_tree() -> void:
	if restore_on_exit:
		var _reset_to_base_result_88: Variant = reset_to_base()


# --- 公共方法 ---

## 设置反馈工具实例。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_utility: 反馈工具实例。
func set_utility(shake_utility: GFShakeUtility) -> void:
	utility = shake_utility


## 获取当前目标节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 目标 Node3D；不存在时返回 null。
func get_target() -> Node3D:
	if _target_ref == null:
		return null
	var target: Node = _INSTANCE_GUARD._get_live_node_from_ref(_target_ref)
	return _get_node_3d_value(target)


## 记录当前目标基础变换。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 记录成功返回 true。
func capture_base_transform() -> bool:
	var target: Node3D = get_target()
	if target == null or not _transform_is_finite(target.position, target.rotation_degrees, target.scale):
		return false
	_base_position = target.position
	_base_rotation_degrees = target.rotation_degrees
	_base_scale = target.scale
	_has_captured_base = true
	_clear_last_offsets()
	return true


## 应用当前 channel 采样。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 应用成功返回 true。
func apply_current_sample() -> bool:
	var target: Node3D = get_target()
	var shake_utility: GFShakeUtility = _get_utility()
	if target == null or shake_utility == null:
		return false

	var sample: Dictionary = shake_utility.sample_channel(channel)
	var position_offset: Vector3 = GFVariantData.get_option_vector3(sample, "position")
	var rotation_offset: Vector3 = GFVariantData.get_option_vector3(sample, "rotation_degrees")
	var scale_offset: Vector3 = GFVariantData.get_option_vector3(sample, "scale")
	if not _vector3_is_finite(position_offset) or not _vector3_is_finite(rotation_offset) or not _vector3_is_finite(scale_offset):
		return false

	var next_position: Vector3 = target.position
	var next_rotation_degrees: Vector3 = target.rotation_degrees
	var next_scale: Vector3 = target.scale
	var next_position_offset: Vector3 = Vector3.ZERO
	var next_rotation_offset: Vector3 = Vector3.ZERO
	var next_scale_offset: Vector3 = Vector3.ZERO
	if apply_position:
		next_position_offset = position_offset
		next_position = target.position - _last_position_offset + next_position_offset
	elif _last_position_offset != Vector3.ZERO:
		next_position = target.position - _last_position_offset
	if apply_rotation:
		next_rotation_offset = rotation_offset
		next_rotation_degrees = target.rotation_degrees - _last_rotation_offset + next_rotation_offset
	elif _last_rotation_offset != Vector3.ZERO:
		next_rotation_degrees = target.rotation_degrees - _last_rotation_offset
	if apply_scale:
		next_scale_offset = scale_offset
		next_scale = target.scale - _last_scale_offset + next_scale_offset
	elif _last_scale_offset != Vector3.ZERO:
		next_scale = target.scale - _last_scale_offset
	if not _transform_is_finite(next_position, next_rotation_degrees, next_scale):
		return false

	target.position = next_position
	target.rotation_degrees = next_rotation_degrees
	target.scale = next_scale
	_last_position_offset = next_position_offset
	_last_rotation_offset = next_rotation_offset
	_last_scale_offset = next_scale_offset
	return true


## 恢复目标基础变换。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 恢复成功返回 true。
func reset_to_base() -> bool:
	var target: Node3D = get_target()
	if target == null:
		_clear_last_offsets()
		return false
	var next_position: Vector3 = _base_position if _has_captured_base else target.position - _last_position_offset
	var next_rotation_degrees: Vector3 = (
		_base_rotation_degrees if _has_captured_base else target.rotation_degrees - _last_rotation_offset
	)
	var next_scale: Vector3 = _base_scale if _has_captured_base else target.scale - _last_scale_offset
	if not _transform_is_finite(next_position, next_rotation_degrees, next_scale):
		return false
	target.position = next_position
	target.rotation_degrees = next_rotation_degrees
	target.scale = next_scale
	_clear_last_offsets()
	return true


# --- 私有/辅助方法 ---

func _get_utility() -> GFShakeUtility:
	if utility != null:
		return utility
	var architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _get_shake_utility_value(architecture.get_utility(GFShakeUtility))


func _resolve_target() -> Node3D:
	if target_path != NodePath(""):
		return _get_node_3d_value(get_node_or_null(target_path))
	var self_target: Node3D = _get_node_3d_value(self)
	if self_target != null:
		return self_target
	return _get_node_3d_value(get_parent())


func _rebind_target(should_capture_base: bool) -> void:
	_clear_last_offsets()
	_has_captured_base = false
	var target: Node3D = _resolve_target()
	_target_ref = weakref(target) if target != null else null
	if should_capture_base:
		var _capture_base_transform_result: Variant = capture_base_transform()


func _get_node_3d_value(value: Variant) -> Node3D:
	if value is Node3D:
		var node: Node3D = value
		return node
	return null


func _get_shake_utility_value(value: Variant) -> GFShakeUtility:
	if value is GFShakeUtility:
		var shake_utility: GFShakeUtility = value
		return shake_utility
	return null


func _clear_last_offsets() -> void:
	_last_position_offset = Vector3.ZERO
	_last_rotation_offset = Vector3.ZERO
	_last_scale_offset = Vector3.ZERO


func _transform_is_finite(position: Vector3, rotation_degrees: Vector3, scale: Vector3) -> bool:
	return _vector3_is_finite(position) and _vector3_is_finite(rotation_degrees) and _vector3_is_finite(scale)


func _vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
