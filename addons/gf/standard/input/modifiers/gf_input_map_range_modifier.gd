## GFInputMapRangeModifier: 输入范围映射修饰器。
##
## 将输入分量从一个数值范围线性映射到另一个范围，适合灵敏度曲线前后的
## 简单归一化处理。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputMapRangeModifier
extends GFInputModifier


# --- 导出变量 ---

## 输入最小值。
## [br]
## @api public
@export var input_min: float = 0.0

## 输入最大值。
## [br]
## @api public
@export var input_max: float = 1.0

## 输出最小值。
## [br]
## @api public
@export var output_min: float = 0.0

## 输出最大值。
## [br]
## @api public
@export var output_max: float = 1.0

## 是否限制输出到目标范围内。
## [br]
## @api public
@export var clamp_output: bool = true


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
## @return 范围映射后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	return Vector2(_map_value(value.x), _map_value(value.y))


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
## @return 范围映射后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	return Vector3(_map_value(value.x), _map_value(value.y), _map_value(value.z))


# --- 私有/辅助方法 ---

## 把输入值在线性输入/输出范围间映射；输入范围近零时返回 output_min，且可选钳制输出。
## [br]
## @api private
## [br]
func _map_value(value: float) -> float:
	var input_range: float = input_max - input_min
	if is_zero_approx(input_range):
		return output_min

	var t: float = (value - input_min) / input_range
	var mapped: float = lerpf(output_min, output_max, t)
	if not clamp_output:
		return mapped

	var min_value: float = minf(output_min, output_max)
	var max_value: float = maxf(output_min, output_max)
	return clampf(mapped, min_value, max_value)
