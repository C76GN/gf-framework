## GFCameraOrbitInput3D: 通用 3D 环绕相机输入桥接节点。
##
## 将 GFInputMappingUtility 的可配置动作值或鼠标拖拽转换为 GFCameraOrbitRig3D 的角度和距离增量。
## 它不创建输入上下文，也不定义项目动作绑定。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.23.0
class_name GFCameraOrbitInput3D
extends Node


# --- 枚举 ---

## 输入自动处理模式。
## [br]
## @api public
enum UpdateMode {
	## 在 _process 中读取输入。
	IDLE,
	## 在 _physics_process 中读取输入。
	PHYSICS,
	## 只在 process_input() 被显式调用时读取输入。
	MANUAL,
}


# --- 常量 ---

const _GF_CAMERA_FINITE_MATH := preload("res://addons/gf/extensions/camera/core/gf_camera_finite_math.gd")


# --- 导出变量 ---

## 是否启用输入桥接。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_clear_mouse_orbit_capture()

## 要控制的环绕 Rig。为空时使用父节点中的 GFCameraOrbitRig3D。
## [br]
## @api public
@export_node_path("GFCameraOrbitRig3D") var orbit_rig_path: NodePath = NodePath("")

## 自动处理模式。
## [br]
## @api public
@export var update_mode: UpdateMode = UpdateMode.IDLE

## 是否从 GFInputMappingUtility 读取动作值。默认关闭，项目应显式启用并配置动作 ID。
## [br]
## @api public
@export var use_input_mapping: bool = false

## 可选 GFNodeContext 路径。设置后会从该上下文获取 GFInputMappingUtility。
## [br]
## @api public
@export_node_path("GFNodeContext") var node_context_path: NodePath = NodePath("")

## 环绕输入动作 ID。动作值应为 Vector2。
## [br]
## @api public
@export var orbit_action_id: StringName = &"camera_orbit"

## 缩放输入动作 ID。动作值应为 float 或 bool。
## [br]
## @api public
@export var zoom_action_id: StringName = &"camera_zoom"

## 每秒环绕角速度，单位度。
## [br]
## @api public
@export var orbit_degrees_per_second: float = 120.0

## 每秒缩放速度，单位距离。
## [br]
## @api public
@export var zoom_units_per_second: float = 8.0

## 是否反转垂直环绕输入。
## [br]
## @api public
@export var invert_y: bool = false

## 是否启用鼠标拖拽环绕。默认关闭，避免框架节点隐式接管项目输入。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var mouse_orbit_enabled: bool = false:
	set(value):
		mouse_orbit_enabled = value
		if not mouse_orbit_enabled:
			_clear_mouse_orbit_capture()

## 鼠标拖拽环绕使用的按键。
## [br]
## @api public
@export var mouse_button: MouseButton = MOUSE_BUTTON_RIGHT

## 鼠标每像素对应的角度。
## [br]
## @api public
@export var mouse_degrees_per_pixel: float = 0.15

## 是否启用鼠标滚轮缩放。默认关闭，避免框架节点隐式接管项目输入。
## [br]
## @api public
@export var mouse_zoom_enabled: bool = false

## 鼠标滚轮每格缩放距离。
## [br]
## @api public
@export var mouse_wheel_step: float = 1.0

## 鼠标输入被应用后是否标记为已处理。
## [br]
## @api public
@export var consume_mouse_input: bool = true


# --- 公共变量 ---

## 显式注入的输入映射工具。为空时尝试从 node_context_path 或父级 GFNodeContext 获取。
## [br]
## @api public
var input_mapping_utility: GFInputMappingUtility = null


# --- 私有变量 ---

var _mouse_orbit_active: bool = false
var _mouse_orbit_device: int = 0
var _mouse_orbit_rig_ref: WeakRef = null
var _mouse_orbit_rig_instance_id: int = 0
var _mouse_orbit_capture_generation: int = 0
var _next_mouse_orbit_capture_generation: int = 1


# --- Godot 生命周期方法 ---

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		_clear_mouse_orbit_capture()
		return

	var applied: bool = false
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = _get_mouse_button_event(event)
		if mouse_orbit_enabled and button_event.button_index == mouse_button:
			applied = _apply_mouse_orbit_button(button_event)
		elif mouse_zoom_enabled:
			applied = _apply_mouse_wheel(button_event)
	elif mouse_orbit_enabled and event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = _get_mouse_motion_event(event)
		if _mouse_orbit_active and motion.device == _mouse_orbit_device:
			applied = _apply_captured_mouse_orbit(motion.relative)

	if applied and consume_mouse_input:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_clear_mouse_orbit_capture()


func _process(delta: float) -> void:
	if update_mode == UpdateMode.IDLE:
		var _process_input_result_141: Variant = process_input(delta)


func _physics_process(delta: float) -> void:
	if update_mode == UpdateMode.PHYSICS:
		var _process_input_result_146: Variant = process_input(delta)


# --- 公共方法 ---

## 获取当前控制的环绕 Rig。
## [br]
## @api public
## [br]
## @return 环绕 Rig；不存在时返回 null。
func get_orbit_rig() -> GFCameraOrbitRig3D:
	if not orbit_rig_path.is_empty():
		return _get_orbit_rig_value(get_node_or_null(orbit_rig_path))
	return _get_orbit_rig_value(get_parent())


## 显式设置输入映射工具。
## [br]
## @api public
## [br]
## @param utility: 输入映射工具；传 null 表示回退到上下文查找。
func set_input_mapping_utility(utility: GFInputMappingUtility) -> void:
	input_mapping_utility = utility


## 读取输入映射并推进环绕 Rig。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
## [br]
## @return 应用了任意输入时返回 true。
func process_input(delta: float) -> bool:
	if not enabled or not use_input_mapping:
		return false

	var input_mapping: GFInputMappingUtility = _get_input_mapping_utility()
	if input_mapping == null:
		return false

	var safe_delta: float = maxf(_GF_CAMERA_FINITE_MATH.sanitize_float(delta, 0.0), 0.0)
	var applied: bool = false
	var orbit_value: Vector2 = input_mapping.get_action_vector(orbit_action_id)
	if orbit_value != Vector2.ZERO:
		applied = apply_orbit_vector(orbit_value, orbit_degrees_per_second * safe_delta) or applied

	var zoom_value: float = _coerce_zoom_value(input_mapping.get_action_value(zoom_action_id))
	if not is_zero_approx(zoom_value):
		applied = apply_zoom_value(zoom_value, zoom_units_per_second * safe_delta) or applied
	return applied


## 应用二维环绕输入。
## [br]
## @api public
## [br]
## @param value: x 为 yaw 输入，y 为 pitch 输入。
## [br]
## @param scale: 输入缩放量，通常是每秒速度乘以 delta。
## [br]
## @return 成功应用时返回 true。
func apply_orbit_vector(value: Vector2, scale: float = 1.0) -> bool:
	var rig: GFCameraOrbitRig3D = get_orbit_rig()
	if rig == null:
		return false
	return _apply_orbit_vector_to_rig(rig, value, scale)


## 应用一维缩放输入。
## [br]
## @api public
## [br]
## @param value: 缩放输入；正数拉远，负数拉近。
## [br]
## @param scale: 输入缩放量，通常是每秒速度乘以 delta。
## [br]
## @return 成功应用时返回 true。
func apply_zoom_value(value: float, scale: float = 1.0) -> bool:
	var rig: GFCameraOrbitRig3D = get_orbit_rig()
	if (
		rig == null
		or not _GF_CAMERA_FINITE_MATH.is_finite_float(value)
		or not _GF_CAMERA_FINITE_MATH.is_finite_float(scale)
		or is_zero_approx(value)
		or is_zero_approx(scale)
	):
		return false

	rig.apply_zoom_delta(value * scale)
	return true


## 获取输入桥接调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Report-safe Dictionary，包含输入就绪状态、缺失动作以及当前鼠标捕获代次。
func get_debug_snapshot() -> Dictionary:
	var input_mapping: GFInputMappingUtility = _get_input_mapping_utility()
	var missing_actions: PackedStringArray = _get_missing_action_ids(input_mapping)
	var missing_action_values: Array[String] = []
	for action_id: String in missing_actions:
		missing_action_values.append(action_id)
	var captured_rig: GFCameraOrbitRig3D = _get_captured_mouse_orbit_rig()
	return GFReportValueCodec.to_report_dictionary({
		"enabled": enabled,
		"update_mode": update_mode,
		"use_input_mapping": use_input_mapping,
		"orbit_action_id": String(orbit_action_id),
		"zoom_action_id": String(zoom_action_id),
		"has_rig": get_orbit_rig() != null,
		"has_input_mapping": input_mapping != null,
		"input_mapping_missing": use_input_mapping and input_mapping == null,
		"missing_actions": missing_action_values,
		"mouse_orbit_captured": captured_rig != null,
		"mouse_orbit_capture_generation": _mouse_orbit_capture_generation,
		"ready": enabled and get_orbit_rig() != null and (not use_input_mapping or (input_mapping != null and missing_actions.is_empty())),
	}, GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG))


# --- 私有/辅助方法 ---

func _apply_captured_mouse_orbit(relative_pixels: Vector2) -> bool:
	var rig: GFCameraOrbitRig3D = _get_captured_mouse_orbit_rig()
	if rig == null:
		return false
	var pitch_pixels: float = -relative_pixels.y
	return _apply_orbit_vector_to_rig(
		rig,
		Vector2(relative_pixels.x, pitch_pixels),
		mouse_degrees_per_pixel
	)


func _apply_orbit_vector_to_rig(
	rig: GFCameraOrbitRig3D,
	value: Vector2,
	scale: float
) -> bool:
	if (
		rig == null
		or not is_instance_valid(rig)
		or not _GF_CAMERA_FINITE_MATH.is_finite_vector2(value)
		or not _GF_CAMERA_FINITE_MATH.is_finite_float(scale)
		or value == Vector2.ZERO
		or is_zero_approx(scale)
	):
		return false

	var pitch_value: float = value.y
	if invert_y:
		pitch_value = -pitch_value
	rig.apply_orbit_delta(Vector2(value.x, pitch_value) * scale)
	return true


func _apply_mouse_wheel(event: InputEventMouseButton) -> bool:
	if not event.pressed:
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		return apply_zoom_value(-mouse_wheel_step, 1.0)
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return apply_zoom_value(mouse_wheel_step, 1.0)
	return false


func _apply_mouse_orbit_button(event: InputEventMouseButton) -> bool:
	if event.pressed:
		var rig: GFCameraOrbitRig3D = get_orbit_rig()
		if rig == null:
			_clear_mouse_orbit_capture()
			return false
		_mouse_orbit_active = true
		_mouse_orbit_device = event.device
		_mouse_orbit_rig_ref = weakref(rig)
		_mouse_orbit_rig_instance_id = rig.get_instance_id()
		_mouse_orbit_capture_generation = _next_mouse_orbit_capture_generation
		_next_mouse_orbit_capture_generation += 1
		if _next_mouse_orbit_capture_generation <= 0:
			_next_mouse_orbit_capture_generation = 1
		return true
	if _mouse_orbit_active and event.device == _mouse_orbit_device:
		_clear_mouse_orbit_capture()
		return true
	return false


func _clear_mouse_orbit_capture() -> void:
	_mouse_orbit_active = false
	_mouse_orbit_device = 0
	_mouse_orbit_rig_ref = null
	_mouse_orbit_rig_instance_id = 0
	_mouse_orbit_capture_generation = 0


func _get_captured_mouse_orbit_rig() -> GFCameraOrbitRig3D:
	if not _mouse_orbit_active or _mouse_orbit_rig_ref == null:
		return null
	var rig: GFCameraOrbitRig3D = _get_orbit_rig_value(_mouse_orbit_rig_ref.get_ref())
	if (
		rig == null
		or not is_instance_valid(rig)
		or rig.get_instance_id() != _mouse_orbit_rig_instance_id
		or get_orbit_rig() != rig
	):
		_clear_mouse_orbit_capture()
		return null
	return rig


func _coerce_zoom_value(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is bool:
		var bool_value: bool = value
		return 1.0 if bool_value else 0.0
	if value is Vector2:
		var vector2: Vector2 = value
		return vector2.x
	if value is Vector3:
		var vector3: Vector3 = value
		return vector3.x
	return GFVariantData.to_float(value)


func _get_input_mapping_utility() -> GFInputMappingUtility:
	if input_mapping_utility != null:
		return input_mapping_utility

	var context: GFNodeContext = _get_node_context()
	if context == null:
		return null
	return _get_input_mapping_value(context.get_utility(GFInputMappingUtility))


func _get_node_context() -> GFNodeContext:
	if not node_context_path.is_empty():
		return _get_node_context_value(get_node_or_null(node_context_path))
	return _get_node_context_value(GFNodeTreeOps.find_first_parent_of_type(self, GFNodeContext))


func _get_mouse_motion_event(value: Variant) -> InputEventMouseMotion:
	if value is InputEventMouseMotion:
		var event: InputEventMouseMotion = value
		return event
	return null


func _get_mouse_button_event(value: Variant) -> InputEventMouseButton:
	if value is InputEventMouseButton:
		var event: InputEventMouseButton = value
		return event
	return null


func _get_orbit_rig_value(value: Variant) -> GFCameraOrbitRig3D:
	if value is GFCameraOrbitRig3D:
		var rig: GFCameraOrbitRig3D = value
		return rig
	return null


func _get_input_mapping_value(value: Variant) -> GFInputMappingUtility:
	if value is GFInputMappingUtility:
		var utility: GFInputMappingUtility = value
		return utility
	return null


func _get_node_context_value(value: Variant) -> GFNodeContext:
	if value is GFNodeContext:
		var context: GFNodeContext = value
		return context
	return null


func _get_missing_action_ids(input_mapping: GFInputMappingUtility) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not use_input_mapping:
		return result
	_append_missing_action_id(result, input_mapping, orbit_action_id)
	_append_missing_action_id(result, input_mapping, zoom_action_id)
	return result


func _append_missing_action_id(
	result: PackedStringArray,
	input_mapping: GFInputMappingUtility,
	action_id: StringName
) -> void:
	if action_id == &"" or result.has(String(action_id)):
		return
	if input_mapping == null or input_mapping.get_action_value(action_id) == null:
		var _append_result: bool = result.append(String(action_id))
