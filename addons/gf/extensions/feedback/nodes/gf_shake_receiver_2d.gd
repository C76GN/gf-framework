## GFShakeReceiver2D: 将反馈采样应用到 Node2D 的通用接收器。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFShakeReceiver2D
extends Node


# --- 常量 ---

## 通过弱引用检查和解析有效节点的框架内部脚本。
## [br]
## @api private
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 导出变量 ---

## 目标 Node2D 路径；为空时优先使用自身，其次使用父节点。路径目标暂时不存在或被
## 重建时，receiver 会继续解析同一路径，并为新目标重新建立基准。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node2D") var target_path: NodePath = NodePath(""):
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

## 当前目标节点的弱引用。
## [br]
## @api private
var _target_ref: WeakRef = null

## 捕获的目标基础位置。
## [br]
## @api private
var _base_position: Vector2 = Vector2.ZERO

## 捕获的目标基础角度。
## [br]
## @api private
var _base_rotation_degrees: float = 0.0

## 捕获的目标基础缩放。
## [br]
## @api private
var _base_scale: Vector2 = Vector2.ONE

## 指示是否已成功捕获目标基础变换。
## [br]
## @api private
var _has_captured_base: bool = false

## 上次施加到目标位置的反馈偏移。
## [br]
## @api private
var _last_position_offset: Vector2 = Vector2.ZERO

## 上次施加到目标角度的反馈偏移。
## [br]
## @api private
var _last_rotation_offset: float = 0.0

## 上次施加到目标缩放的反馈偏移。
## [br]
## @api private
var _last_scale_offset: Vector2 = Vector2.ZERO


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_rebind_target(capture_on_ready)


func _process(_delta: float) -> void:
	if get_target() == null:
		_rebind_target(capture_on_ready)
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
## @return: 目标 Node2D；不存在时返回 null。
func get_target() -> Node2D:
	if _target_ref == null:
		return null
	var target: Node = _INSTANCE_GUARD._get_live_node_from_ref(_target_ref)
	return _get_node_2d_value(target)


## 记录当前目标基础变换。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 记录成功返回 true。
func capture_base_transform() -> bool:
	var target: Node2D = get_target()
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
	var target: Node2D = get_target()
	var shake_utility: GFShakeUtility = _get_utility()
	if target == null or shake_utility == null:
		return false

	var sample: Dictionary = shake_utility.sample_channel(channel)
	var position: Vector3 = GFVariantData.get_option_vector3(sample, "position")
	var rotation_degrees: Vector3 = GFVariantData.get_option_vector3(sample, "rotation_degrees")
	var scale: Vector3 = GFVariantData.get_option_vector3(sample, "scale")
	if not _vector3_is_finite(position) or not _vector3_is_finite(rotation_degrees) or not _vector3_is_finite(scale):
		return false

	var next_position: Vector2 = target.position
	var next_rotation_degrees: float = target.rotation_degrees
	var next_scale: Vector2 = target.scale
	var next_position_offset: Vector2 = Vector2.ZERO
	var next_rotation_offset: float = 0.0
	var next_scale_offset: Vector2 = Vector2.ZERO
	if apply_position:
		next_position_offset = Vector2(position.x, position.y)
		next_position = target.position - _last_position_offset + next_position_offset
	elif _last_position_offset != Vector2.ZERO:
		next_position = target.position - _last_position_offset
	if apply_rotation:
		next_rotation_offset = rotation_degrees.z
		next_rotation_degrees = target.rotation_degrees - _last_rotation_offset + next_rotation_offset
	elif not is_zero_approx(_last_rotation_offset):
		next_rotation_degrees = target.rotation_degrees - _last_rotation_offset
	if apply_scale:
		next_scale_offset = Vector2(scale.x, scale.y)
		next_scale = target.scale - _last_scale_offset + next_scale_offset
	elif _last_scale_offset != Vector2.ZERO:
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
	var target: Node2D = get_target()
	if target == null:
		_clear_last_offsets()
		return false
	var next_position: Vector2 = _base_position if _has_captured_base else target.position - _last_position_offset
	var next_rotation_degrees: float = (
		_base_rotation_degrees if _has_captured_base else target.rotation_degrees - _last_rotation_offset
	)
	var next_scale: Vector2 = _base_scale if _has_captured_base else target.scale - _last_scale_offset
	if not _transform_is_finite(next_position, next_rotation_degrees, next_scale):
		return false
	target.position = next_position
	target.rotation_degrees = next_rotation_degrees
	target.scale = next_scale
	_clear_last_offsets()
	return true


# --- 私有/辅助方法 ---

## 优先返回显式工具，否则从全局架构查找 GFShakeUtility。
## [br]
## @api private
func _get_utility() -> GFShakeUtility:
	if utility != null:
		return utility
	var architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _get_shake_utility_value(architecture.get_utility(GFShakeUtility))


## 按 target_path、自身、父节点的顺序解析 Node2D 目标。
## [br]
## @api private
func _resolve_target() -> Node2D:
	if target_path != NodePath(""):
		return _get_node_2d_value(get_node_or_null(target_path))
	var self_target: Node2D = _get_node_2d_value(self)
	if self_target != null:
		return self_target
	return _get_node_2d_value(get_parent())


## 清除上次偏移、重新绑定目标弱引用并按参数选择性捕获基础变换。
## [br]
## @api private
func _rebind_target(should_capture_base: bool) -> void:
	_clear_last_offsets()
	_has_captured_base = false
	var target: Node2D = _resolve_target()
	_target_ref = weakref(target) if target != null else null
	if should_capture_base:
		var _capture_base_transform_result: Variant = capture_base_transform()


## 将任意值收窄为 Node2D 实例，否则返回 null。
## [br]
## @api private
func _get_node_2d_value(value: Variant) -> Node2D:
	if value is Node2D:
		var node: Node2D = value
		return node
	return null


## 将任意值收窄为 GFShakeUtility 实例，否则返回 null。
## [br]
## @api private
func _get_shake_utility_value(value: Variant) -> GFShakeUtility:
	if value is GFShakeUtility:
		var shake_utility: GFShakeUtility = value
		return shake_utility
	return null


## 清零上次记录的位置、角度和缩放偏移。
## [br]
## @api private
func _clear_last_offsets() -> void:
	_last_position_offset = Vector2.ZERO
	_last_rotation_offset = 0.0
	_last_scale_offset = Vector2.ZERO


## 检查位置、角度和缩放中的所有浮点分量是否有限。
## [br]
## @api private
func _transform_is_finite(position: Vector2, rotation_degrees: float, scale: Vector2) -> bool:
	return _vector2_is_finite(position) and is_finite(rotation_degrees) and _vector2_is_finite(scale)


## 检查 Vector2 的两个分量是否均为有限数值。
## [br]
## @api private
func _vector2_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


## 检查 Vector3 的三个分量是否均为有限数值。
## [br]
## @api private
func _vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
