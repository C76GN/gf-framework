## GFInputSignClampModifier: 输入符号方向限制修饰器。
##
## 用于只保留正向或负向输入分量，也可以把保留的负向分量重新映射为正值。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputSignClampModifier
extends GFInputModifier


# --- 枚举 ---

## 允许通过的符号方向。
## [br]
## @api public
enum AllowedSign {
	## 只保留大于等于 0 的值。
	POSITIVE,
	## 只保留小于等于 0 的值。
	NEGATIVE,
}


# --- 导出变量 ---

## 允许通过的符号方向。
## [br]
## @api public
@export var allowed_sign: AllowedSign = AllowedSign.POSITIVE

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

## 是否把保留的负向分量转为正值。
## [br]
## @api public
@export var remap_to_positive: bool = false


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
## @return 符号过滤后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	return Vector2(
		_apply_sign(value.x) if apply_x else value.x,
		_apply_sign(value.y) if apply_y else value.y
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
## @return 符号过滤后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	return Vector3(
		_apply_sign(value.x) if apply_x else value.x,
		_apply_sign(value.y) if apply_y else value.y,
		_apply_sign(value.z) if apply_z else value.z
	)


# --- 私有/辅助方法 ---

## 按 allowed_sign 保留非负或非正分量，并可将结果绝对化映射为正值。
## [br]
## @api private
## [br]
func _apply_sign(value: float) -> float:
	var result: float = maxf(value, 0.0)
	if allowed_sign == AllowedSign.NEGATIVE:
		result = minf(value, 0.0)
	if remap_to_positive:
		return absf(result)
	return result
