## GFInputCurveModifier: 输入曲线修饰器。
##
## 对输入分量按 Curve 重新采样，适合摇杆灵敏度、扳机响应和虚拟指针速度曲线。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputCurveModifier
extends GFInputModifier


# --- 导出变量 ---

## 输入曲线。采样区间为 0..1。
## [br]
## @api public
@export var curve: Curve = null

## 是否保留输入符号，只用绝对值采样曲线。
## [br]
## @api public
@export var preserve_sign: bool = true

## 是否处理 X 分量。
## [br]
## @api public
@export var apply_x: bool = true

## 是否处理 Y 分量。
## [br]
## @api public
@export var apply_y: bool = true

## 是否处理 Z 分量。
## [br]
## @api public
@export var apply_z: bool = true


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
## @return 按曲线采样后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	return Vector2(
		_apply_curve(value.x) if apply_x else value.x,
		_apply_curve(value.y) if apply_y else value.y
	)


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
## @return 按曲线采样后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	return Vector3(
		_apply_curve(value.x) if apply_x else value.x,
		_apply_curve(value.y) if apply_y else value.y,
		_apply_curve(value.z) if apply_z else value.z
	)


# --- 私有/辅助方法 ---

## 无曲线时返回原值；否则按符号策略对绝对输入限幅采样，并按需恢复符号。
## [br]
## @api private
## [br]
func _apply_curve(value: float) -> float:
	if curve == null:
		return value
	var sign_value: float = signf(value) if preserve_sign else 1.0
	var sample_value: float = absf(value) if preserve_sign else value
	var sampled: float = curve.sample_baked(clampf(sample_value, 0.0, 1.0))
	return sampled * sign_value
