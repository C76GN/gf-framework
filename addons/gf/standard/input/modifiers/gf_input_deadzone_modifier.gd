## GFInputDeadzoneModifier: 输入死区修饰器。
##
## 可对一维或二维轴值应用径向死区，并可选择把剩余范围重新映射到 0..1。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputDeadzoneModifier
extends GFInputModifier


# --- 导出变量 ---

## 低于该阈值的输入会被视为 0。与 upper_threshold 相等时形成阶跃：
## 低于共同阈值为 0，达到阈值为满幅。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_range(0.0, 1.0, 0.01) var lower_threshold: float = 0.2:
	set(value):
		if not is_finite(value):
			return
		lower_threshold = clampf(value, 0.0, upper_threshold)

## 达到该阈值时视为满幅输入；可与 lower_threshold 相等以表达硬阈值。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_range(0.0, 1.0, 0.01) var upper_threshold: float = 1.0:
	set(value):
		if not is_finite(value):
			return
		upper_threshold = clampf(value, lower_threshold, 1.0)

## 是否把死区外的剩余范围重新映射到 0..1。
## [br]
## @api public
@export var rescale_after_deadzone: bool = true


# --- 公共方法 ---

## 修改二维输入值。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @param _event: 原始输入事件，默认实现不直接使用。
## [br]
## @param _action: 当前输入动作配置，默认实现不直接使用。
## [br]
## @return 应用死区后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	var length: float = value.length()
	if not is_finite(length):
		return Vector2.ZERO
	if length < lower_threshold:
		return Vector2.ZERO
	if not rescale_after_deadzone:
		return value

	var threshold_span: float = upper_threshold - lower_threshold
	if threshold_span <= 0.0:
		return value.normalized()
	var scaled_length: float = clampf((minf(length, upper_threshold) - lower_threshold) / threshold_span, 0.0, 1.0)
	return value.normalized() * scaled_length


## 修改三维输入值。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @param _event: 原始输入事件，默认实现不直接使用。
## [br]
## @param _action: 当前输入动作配置，默认实现不直接使用。
## [br]
## @return 应用死区后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	var length: float = value.length()
	if not is_finite(length):
		return Vector3.ZERO
	if length < lower_threshold:
		return Vector3.ZERO
	if not rescale_after_deadzone:
		return value

	var threshold_span: float = upper_threshold - lower_threshold
	if threshold_span <= 0.0:
		return value.normalized()
	var scaled_length: float = clampf((minf(length, upper_threshold) - lower_threshold) / threshold_span, 0.0, 1.0)
	return value.normalized() * scaled_length
