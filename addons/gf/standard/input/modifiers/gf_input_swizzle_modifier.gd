## GFInputSwizzleModifier: 输入分量重排修饰器。
##
## 用于把二维或三维输入轴按通用顺序重排，适合在不改绑定资源的情况下
## 调整轴方向约定。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputSwizzleModifier
extends GFInputModifier


# --- 枚举 ---

## 分量重排顺序。
## [br]
## @api public
enum SwizzleOrder {
	## 保持 X/Y/Z。
	XYZ,
	## 输出 X/Z/Y。
	XZY,
	## 输出 Y/X/Z。
	YXZ,
	## 输出 Y/Z/X。
	YZX,
	## 输出 Z/X/Y。
	ZXY,
	## 输出 Z/Y/X。
	ZYX,
}


# --- 导出变量 ---

## 分量重排顺序。
## [br]
## @api public
@export var order: SwizzleOrder = SwizzleOrder.XYZ


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
## @return 分量重排后的二维输入值。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	var swizzled: Vector3 = _swizzle(Vector3(value.x, value.y, 0.0))
	return Vector2(swizzled.x, swizzled.y)


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
## @return 分量重排后的三维输入值。
func modify_3d(value: Vector3, _event: InputEvent = null, _action: GFInputAction = null) -> Vector3:
	return _swizzle(value)


# --- 私有/辅助方法 ---

## 按 SwizzleOrder 对 Vector3 的 x、y、z 分量重排；未列出的默认顺序保持原值。
## [br]
## @api private
## [br]
func _swizzle(value: Vector3) -> Vector3:
	match order:
		SwizzleOrder.XZY:
			return Vector3(value.x, value.z, value.y)
		SwizzleOrder.YXZ:
			return Vector3(value.y, value.x, value.z)
		SwizzleOrder.YZX:
			return Vector3(value.y, value.z, value.x)
		SwizzleOrder.ZXY:
			return Vector3(value.z, value.x, value.y)
		SwizzleOrder.ZYX:
			return Vector3(value.z, value.y, value.x)
		_:
			return value
