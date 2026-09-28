## GFInputMagnitudeModifier: 输入幅值投影修饰器。
##
## 将多轴输入转换为长度值，并按配置写回到指定分量。它只处理向量数值，
## 不解释这个幅值代表移动、视角、压力或其他业务含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputMagnitudeModifier
extends GFInputModifier


# --- 导出变量 ---

## 输出幅值到 X 分量。
## [br]
## @api public
@export var output_x: bool = true

## 输出幅值到 Y 分量。
## [br]
## @api public
@export var output_y: bool = false

## 输出幅值到 Z 分量，仅用于三维输入。
## [br]
## @api public
@export var output_z: bool = false

## 是否使用绝对值幅值。
## [br]
## @api public
@export var absolute_value: bool = true

## 非输出分量是否保留原值。
## [br]
## @api public
@export var preserve_unselected_components: bool = false


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
## @return 幅值投影后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	var magnitude: float = _get_magnitude_2d(value)
	return Vector2(
		magnitude if output_x else (_preserve_component(value.x)),
		magnitude if output_y else (_preserve_component(value.y))
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
## @return 幅值投影后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	var magnitude: float = _get_magnitude_3d(value)
	return Vector3(
		magnitude if output_x else (_preserve_component(value.x)),
		magnitude if output_y else (_preserve_component(value.y)),
		magnitude if output_z else (_preserve_component(value.z))
	)


# --- 私有/辅助方法 ---

## 计算二维向量长度；绝对值模式直接返回长度，否则按最大绝对分量的符号保留方向。
## [br]
## @api private
## [br]
func _get_magnitude_2d(value: Vector2) -> float:
	var magnitude: float = value.length()
	if absolute_value:
		return magnitude
	return magnitude * _get_dominant_sign(Vector3(value.x, value.y, 0.0))


## 计算三维向量长度；绝对值模式直接返回长度，否则按主导分量符号保留方向。
## [br]
## @api private
## [br]
func _get_magnitude_3d(value: Vector3) -> float:
	var magnitude: float = value.length()
	if absolute_value:
		return magnitude
	return magnitude * _get_dominant_sign(value)


## 选择绝对值最大的 x/y/z 分量并返回其符号；最大分量为零时返回正号。
## [br]
## @api private
## [br]
func _get_dominant_sign(value: Vector3) -> float:
	var axis_value: float = value.x
	if absf(value.y) > absf(axis_value):
		axis_value = value.y
	if absf(value.z) > absf(axis_value):
		axis_value = value.z
	return -1.0 if axis_value < 0.0 else 1.0


## 按 preserve_unselected_components 配置保留未输出分量，否则返回零。
## [br]
## @api private
## [br]
func _preserve_component(value: float) -> float:
	return value if preserve_unselected_components else 0.0
