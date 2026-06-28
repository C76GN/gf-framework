## GFGravityField3D: 通用 3D 重力/加速度场。
##
## 提供点重力、远离中心和固定方向三种方向模式，以及常量、线性、平方反比
## 和曲线衰减。项目可继承并重写方向或强度计算以实现更复杂的场。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFGravityField3D
extends Node3D


# --- 信号 ---

## 力场参数变化时发出。
## [br]
## @api public
signal field_changed


# --- 枚举 ---

## 力场方向模式。
## [br]
## @api public
enum DirectionMode {
	## 朝向力场节点原点。
	TOWARD_ORIGIN,
	## 远离力场节点原点。
	AWAY_FROM_ORIGIN,
	## 使用固定方向。
	CONSTANT_DIRECTION,
}

## 强度衰减模式。
## [br]
## @api public
enum FalloffMode {
	## 半径内保持恒定强度。
	CONSTANT,
	## 从中心到半径边缘线性衰减。
	LINEAR,
	## 按平方反比衰减。
	INVERSE_SQUARE,
	## 使用 Curve 采样衰减；横轴为距离占半径比例。
	CURVE,
}


# --- 导出变量 ---

## 是否启用力场。
## [br]
## @api public
@export var enabled: bool = true:
	set(value):
		enabled = value
		field_changed.emit()

## 采样器使用优先级组合模式时的力场优先级；数值越大优先级越高。
## [br]
## @api public
@export var priority: int = 0:
	set(value):
		priority = value
		field_changed.emit()

## 基础加速度强度。
## [br]
## @api public
@export var acceleration: float = 9.8:
	set(value):
		acceleration = maxf(value, 0.0)
		field_changed.emit()

## 影响半径；小于等于 0 表示无限范围。
## [br]
## @api public
@export var radius: float = 0.0:
	set(value):
		radius = maxf(value, 0.0)
		field_changed.emit()

## 平方反比模式下用于避免近距离发散的最小距离。
## [br]
## @api public
@export var min_distance: float = 1.0:
	set(value):
		min_distance = maxf(value, 0.001)
		field_changed.emit()

## 方向模式。
## [br]
## @api public
@export var direction_mode: DirectionMode = DirectionMode.TOWARD_ORIGIN:
	set(value):
		direction_mode = value
		field_changed.emit()

## 固定方向模式使用的方向。
## [br]
## @api public
@export var constant_direction: Vector3 = Vector3.DOWN:
	set(value):
		constant_direction = value
		field_changed.emit()

## 强度衰减模式。
## [br]
## @api public
@export var falloff_mode: FalloffMode = FalloffMode.CONSTANT:
	set(value):
		falloff_mode = value
		field_changed.emit()

## 曲线衰减模式使用的 Curve。采样值会乘以 acceleration。
## [br]
## @api public
@export var falloff_curve: Curve = null:
	set(value):
		falloff_curve = value
		field_changed.emit()


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	add_to_group("gf_gravity_field_3d")


func _exit_tree() -> void:
	remove_from_group("gf_gravity_field_3d")


# --- 公共方法 ---

## 获取指定世界坐标处的加速度向量。
## [br]
## @api public
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 加速度向量。
func get_acceleration_at(world_position: Vector3) -> Vector3:
	if not enabled:
		return Vector3.ZERO

	var distance: float = global_position.distance_to(world_position)
	var strength: float = get_strength_at_distance(distance)
	if strength <= 0.0:
		return Vector3.ZERO

	var direction: Vector3 = _get_direction_at(world_position)
	if direction.is_zero_approx():
		return Vector3.ZERO
	return direction.normalized() * strength


## 获取指定距离处的力场强度。
## [br]
## @api public
## [br]
## @param distance: 距离。
## [br]
## @return 加速度强度。
func get_strength_at_distance(distance: float) -> float:
	if acceleration <= 0.0:
		return 0.0
	var safe_distance: float = maxf(distance, 0.0)
	if radius > 0.0 and safe_distance > radius:
		return 0.0

	match falloff_mode:
		FalloffMode.LINEAR:
			if radius <= 0.0:
				return acceleration
			return acceleration * clampf(1.0 - safe_distance / radius, 0.0, 1.0)
		FalloffMode.INVERSE_SQUARE:
			var effective_distance: float = maxf(safe_distance, min_distance)
			return acceleration * min_distance * min_distance / (effective_distance * effective_distance)
		FalloffMode.CURVE:
			if falloff_curve == null:
				return acceleration
			var sample_position: float = clampf(safe_distance / radius, 0.0, 1.0) if radius > 0.0 else 0.0
			return acceleration * maxf(falloff_curve.sample(sample_position), 0.0)
		_:
			return acceleration


## 获取力场采样优先级。
## [br]
## @api public
## [br]
## @return 优先级数值，越大越优先。
func get_gravity_priority() -> int:
	return priority


# --- 可重写钩子 / 虚方法 ---

## 获取指定世界坐标处的方向。子类可重写以实现自定义场。
## [br]
## @api protected
## [br]
## @param world_position: 世界坐标。
## [br]
## @return 方向向量。
func _get_direction_at(world_position: Vector3) -> Vector3:
	match direction_mode:
		DirectionMode.AWAY_FROM_ORIGIN:
			return world_position - global_position
		DirectionMode.CONSTANT_DIRECTION:
			return constant_direction
		_:
			return global_position - world_position
