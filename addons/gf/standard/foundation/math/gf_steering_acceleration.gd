## GFSteeringAcceleration: steering 计算输出的线性与角加速度。
##
## 作为纯数据对象在多个 steering 行为之间传递，不绑定节点或物理体。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSteeringAcceleration
extends RefCounted


# --- 公共变量 ---

## 线性加速度。
## [br]
## @api public
var linear: Vector3 = Vector3.ZERO

## 角加速度。
## [br]
## @api public
var angular: float = 0.0


# --- Godot 生命周期方法 ---

func _init(p_linear: Vector3 = Vector3.ZERO, p_angular: float = 0.0) -> void:
	linear = p_linear
	angular = p_angular


# --- 公共方法 ---

## 清零加速度。
## [br]
## @api public
## [br]
## @return 当前实例。
func clear() -> GFSteeringAcceleration:
	linear = Vector3.ZERO
	angular = 0.0
	return self


## 写入加速度值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param linear_acceleration: 线性加速度。
## [br]
## @param angular_acceleration: 角加速度。
## [br]
## @return 当前实例。
func set_values(linear_acceleration: Vector3, angular_acceleration: float = 0.0) -> GFSteeringAcceleration:
	linear = linear_acceleration
	angular = angular_acceleration
	return self


## 按权重叠加另一个加速度。
## [br]
## @api public
## [br]
## @param other: 另一个加速度。
## [br]
## @param weight: 权重。
## [br]
## @return 当前实例。
func add_scaled(other: GFSteeringAcceleration, weight: float = 1.0) -> GFSteeringAcceleration:
	if other == null:
		return self
	linear += other.linear * weight
	angular += other.angular * weight
	return self


## 按上限裁剪加速度。
## [br]
## @api public
## [br]
## @param max_linear: 最大线性加速度；小于 0 时不限制。
## [br]
## @param max_angular: 最大角加速度；小于 0 时不限制。
## [br]
## @return 当前实例。
func clamp_to(max_linear: float = -1.0, max_angular: float = -1.0) -> GFSteeringAcceleration:
	if max_linear >= 0.0 and linear.length() > max_linear:
		linear = linear.normalized() * max_linear
	if max_angular >= 0.0:
		angular = clampf(
			angular,
			-max_angular,
			max_angular
		)
	return self


## 判断加速度是否接近零。
## [br]
## @api public
## [br]
## @param threshold: 零阈值。
## [br]
## @return 接近零返回 true。
func is_zero(threshold: float = 0.001) -> bool:
	return linear.length_squared() <= threshold * threshold and absf(angular) <= threshold


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新加速度对象。
func duplicate_acceleration() -> GFSteeringAcceleration:
	return GFSteeringAcceleration.new(linear, angular)
