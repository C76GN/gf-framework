## GFCameraOrbitRig3D: 通用 3D 环绕相机 Rig。
##
## 基于目标焦点、yaw / pitch 和距离计算期望 Camera3D Transform。
## 它只描述相机姿态，不处理碰撞、锁定目标、遮挡或具体玩法输入。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.23.0
class_name GFCameraOrbitRig3D
extends GFCameraRig3D


# --- 信号 ---

## 环绕参数变化后发出。
## [br]
## @api public
## [br]
## @param yaw_degrees_value: 当前水平角度。
## [br]
## @param pitch_degrees_value: 当前俯仰角度。
## [br]
## @param distance_value: 当前距离。
signal orbit_changed(yaw_degrees_value: float, pitch_degrees_value: float, distance_value: float)


# --- 导出变量 ---

## 水平角度，单位度。
## [br]
## @api public
@export var yaw_degrees: float = 0.0:
	set(value):
		if is_equal_approx(yaw_degrees, _sanitize_float(value, yaw_degrees)):
			return
		yaw_degrees = _sanitize_float(value, yaw_degrees)
		_emit_orbit_changed()

## 俯仰角度，单位度。
## [br]
## @api public
@export var pitch_degrees: float = -20.0:
	set(value):
		if is_equal_approx(pitch_degrees, clampf(_sanitize_float(value, pitch_degrees), min_pitch_degrees, max_pitch_degrees)):
			return
		pitch_degrees = clampf(_sanitize_float(value, pitch_degrees), min_pitch_degrees, max_pitch_degrees)
		_emit_orbit_changed()

## 与焦点的距离。
## [br]
## @api public
@export_range(0.0, 10000.0, 0.01, "or_greater") var distance: float = 8.0:
	set(value):
		if is_equal_approx(distance, clampf(_sanitize_float(value, distance), min_distance, max_distance)):
			return
		distance = clampf(_sanitize_float(value, distance), min_distance, max_distance)
		_emit_orbit_changed()

## 最小距离。
## [br]
## @api public
@export_range(0.0, 10000.0, 0.01, "or_greater") var min_distance: float = 1.0:
	set(value):
		min_distance = maxf(_sanitize_float(value, min_distance), 0.0)
		if max_distance < min_distance:
			max_distance = min_distance
		clamp_orbit()

## 最大距离。
## [br]
## @api public
@export_range(0.0, 10000.0, 0.01, "or_greater") var max_distance: float = 50.0:
	set(value):
		max_distance = maxf(_sanitize_float(value, max_distance), min_distance)
		clamp_orbit()

## 最小俯仰角度。
## [br]
## @api public
@export_range(-89.0, 89.0, 0.1) var min_pitch_degrees: float = -80.0:
	set(value):
		min_pitch_degrees = clampf(_sanitize_float(value, min_pitch_degrees), -89.0, max_pitch_degrees)
		clamp_orbit()

## 最大俯仰角度。
## [br]
## @api public
@export_range(-89.0, 89.0, 0.1) var max_pitch_degrees: float = 80.0:
	set(value):
		max_pitch_degrees = clampf(_sanitize_float(value, max_pitch_degrees), min_pitch_degrees, 89.0)
		clamp_orbit()

## 是否让相机始终朝向焦点。
## [br]
## @api public
@export var look_at_focus: bool = true

## 环绕相机的上方向。为零向量时回退到 Vector3.UP。
## [br]
## @api public
@export var orbit_up_axis: Vector3 = Vector3.UP


# --- 私有变量 ---

var _suspend_orbit_signal: bool = false


# --- 公共方法 ---

## 获取环绕焦点位置。
## [br]
## @api public
## [br]
## @return 当前焦点的全局位置。
func get_focus_position() -> Vector3:
	var target: Node3D = get_target_node()
	var focus_transform: Transform3D = _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		global_transform,
		Transform3D.IDENTITY
	)
	if target != null:
		focus_transform = _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
			target.global_transform,
			focus_transform
		)

	var safe_offset: Vector3 = _sanitize_vector3(offset, Vector3.ZERO)
	var effective_offset: Vector3 = focus_transform.basis * safe_offset if offset_follows_rotation else safe_offset
	return _sanitize_vector3(focus_transform.origin + effective_offset, focus_transform.origin)


## 获取从焦点指向相机的单位方向。
## [br]
## @api public
## [br]
## @return 环绕方向。
func get_orbit_direction() -> Vector3:
	var yaw: float = deg_to_rad(_sanitize_float(yaw_degrees, 0.0))
	var pitch: float = deg_to_rad(_sanitize_float(pitch_degrees, 0.0))
	var horizontal: float = cos(pitch)
	var direction: Vector3 = Vector3(
		sin(yaw) * horizontal,
		sin(pitch),
		cos(yaw) * horizontal
	)
	if direction.length_squared() <= 0.000001:
		return Vector3.BACK
	return direction.normalized()


## 获取当前期望相机 Transform。
## [br]
## @api public
## [br]
## @return 期望全局 Transform。
func get_camera_transform() -> Transform3D:
	var focus: Vector3 = get_focus_position()
	var camera_position: Vector3 = _sanitize_vector3(
		focus + get_orbit_direction() * _sanitize_float(distance, 0.0),
		focus
	)
	var camera_transform: Transform3D = Transform3D(
		_GF_CAMERA_FINITE_MATH.sanitize_basis(global_transform.basis, Basis.IDENTITY),
		camera_position
	)
	if look_at_enabled:
		var look_at_target: Node3D = get_look_at_target_node()
		if look_at_target != null and not camera_position.is_equal_approx(look_at_target.global_position):
			var look_direction: Vector3 = look_at_target.global_position - camera_position
			camera_transform = camera_transform.looking_at(look_at_target.global_position, _get_safe_up_axis_for_direction(look_direction))
	elif look_at_focus and not camera_position.is_equal_approx(focus):
		camera_transform = camera_transform.looking_at(focus, _get_safe_orbit_up_axis_for_direction(focus - camera_position))
	return _GF_CAMERA_FINITE_MATH.sanitize_transform3d(
		_apply_rotation_offset(camera_transform),
		Transform3D(Basis.IDENTITY, camera_position)
	)


## 设置环绕参数。
## [br]
## @api public
## [br]
## @param new_yaw_degrees: 水平角度，单位度。
## [br]
## @param new_pitch_degrees: 俯仰角度，单位度。
## [br]
## @param new_distance: 与焦点的距离。
func set_orbit(new_yaw_degrees: float, new_pitch_degrees: float, new_distance: float) -> void:
	var previous_yaw: float = yaw_degrees
	var previous_pitch: float = pitch_degrees
	var previous_distance: float = distance
	_suspend_orbit_signal = true
	yaw_degrees = new_yaw_degrees
	pitch_degrees = new_pitch_degrees
	distance = new_distance
	_suspend_orbit_signal = false
	if (
		not is_equal_approx(previous_yaw, yaw_degrees)
		or not is_equal_approx(previous_pitch, pitch_degrees)
		or not is_equal_approx(previous_distance, distance)
	):
		_emit_orbit_changed()


## 应用环绕角度增量。
## [br]
## @api public
## [br]
## @param delta_degrees: x 为 yaw 增量，y 为 pitch 增量，单位度。
func apply_orbit_delta(delta_degrees: Vector2) -> void:
	var safe_delta: Vector2 = _sanitize_vector2(delta_degrees, Vector2.ZERO)
	set_orbit(yaw_degrees + safe_delta.x, pitch_degrees + safe_delta.y, distance)


## 应用距离增量。
## [br]
## @api public
## [br]
## @param delta_distance: 距离增量；正数拉远，负数拉近。
func apply_zoom_delta(delta_distance: float) -> void:
	set_orbit(yaw_degrees, pitch_degrees, distance + _sanitize_float(delta_distance, 0.0))


## 按当前上下限夹紧环绕参数。
## [br]
## @api public
func clamp_orbit() -> void:
	var previous_pitch: float = pitch_degrees
	var previous_distance: float = distance
	_suspend_orbit_signal = true
	pitch_degrees = clampf(pitch_degrees, min_pitch_degrees, max_pitch_degrees)
	distance = clampf(distance, min_distance, max_distance)
	_suspend_orbit_signal = false
	if not is_equal_approx(previous_pitch, pitch_degrees) or not is_equal_approx(previous_distance, distance):
		_emit_orbit_changed()


## 获取环绕 Rig 调试快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 yaw_degrees、pitch_degrees、distance、focus_position 和 direction。
func get_debug_snapshot() -> Dictionary:
	return GFReportValueCodec.to_report_dictionary({
		"yaw_degrees": yaw_degrees,
		"pitch_degrees": pitch_degrees,
		"distance": distance,
		"focus_position": get_focus_position(),
		"direction": get_orbit_direction(),
	}, GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG))


# --- 私有/辅助方法 ---

func _emit_orbit_changed() -> void:
	if _suspend_orbit_signal:
		return
	orbit_changed.emit(yaw_degrees, pitch_degrees, distance)


func _get_safe_orbit_up_axis() -> Vector3:
	var safe_axis: Vector3 = _sanitize_vector3(orbit_up_axis, Vector3.UP)
	if safe_axis.length_squared() <= 0.000001:
		return Vector3.UP
	return safe_axis.normalized()


func _get_safe_orbit_up_axis_for_direction(direction: Vector3) -> Vector3:
	var safe_up: Vector3 = _get_safe_orbit_up_axis()
	if direction.length_squared() <= 0.000001:
		return safe_up
	var normalized_direction: Vector3 = direction.normalized()
	if absf(normalized_direction.dot(safe_up)) < 0.999:
		return safe_up
	if absf(normalized_direction.dot(Vector3.UP)) < 0.999:
		return Vector3.UP
	return Vector3.RIGHT


func _sanitize_vector2(value: Vector2, fallback: Vector2) -> Vector2:
	return _GF_CAMERA_FINITE_MATH.sanitize_vector2(value, fallback)
