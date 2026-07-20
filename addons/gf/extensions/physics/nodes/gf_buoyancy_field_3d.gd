## GFBuoyancyField3D: 可扩展的 3D 浮力点采样场。
##
## 默认以节点局部 Y 平面作为无限流体表面，把几何采样和浮力数学组合成纯结果字典。
## 项目可以重写表面、流速钩子实现有限水体、高度场或移动流体，但刚体施力、探针布局、
## Area 检测、网络同步和玩法规则仍由项目层决定。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFBuoyancyField3D
extends Node3D


# --- 常量 ---

## 浮力场默认场景树分组。
## [br]
## @api public
## [br]
## @since 9.0.0
const FIELD_GROUP: StringName = &"gf_buoyancy_field_3d"

const _BUOYANCY_MATH_SCRIPT = preload("res://addons/gf/extensions/physics/core/gf_buoyancy_math_3d.gd")


# --- 导出变量 ---

## 是否启用采样场。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var enabled: bool = true

## 调用方组合多个流体场时可读取的优先级；数值越大优先级越高。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var priority: int = 0

## 默认平面相对节点局部原点的 Y 偏移。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var surface_offset: float = 0.0:
	set(value):
		surface_offset = _finite_float_or(value, 0.0)

## 流体密度。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var fluid_density: float = 1000.0:
	set(value):
		fluid_density = maxf(_finite_float_or(value, 0.0), 0.0)

## 默认世界空间流体速度。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var fluid_velocity: Vector3 = Vector3.ZERO:
	set(value):
		fluid_velocity = value if _is_finite_vector3(value) else Vector3.ZERO

## 点采样线性阻力有效系数。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var linear_drag_coefficient: float = 0.0:
	set(value):
		linear_drag_coefficient = maxf(_finite_float_or(value, 0.0), 0.0)

## 点采样二次阻力有效系数。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var quadratic_drag_coefficient: float = 0.0:
	set(value):
		quadratic_drag_coefficient = maxf(_finite_float_or(value, 0.0), 0.0)


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	add_to_group(FIELD_GROUP)


func _exit_tree() -> void:
	remove_from_group(FIELD_GROUP)


# --- 公共方法 ---

## 获取默认平面的世界空间原点。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 默认流体表面原点。
func get_surface_origin() -> Vector3:
	return to_global(Vector3(0.0, surface_offset, 0.0))


## 获取世界坐标相对流体表面的有符号深度。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 正数表示表面下方，负数表示表面上方；输入或表面无效时返回 0。
func get_signed_depth_at(world_position: Vector3) -> float:
	if not enabled or not _is_finite_vector3(world_position):
		return 0.0
	var depth: float = _get_signed_depth_at(world_position)
	return depth if _is_finite_float(depth) else 0.0


## 获取采样点处的流体表面法线。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 归一化世界空间法线；无效时返回 Vector3.UP。
func get_surface_normal_at(world_position: Vector3) -> Vector3:
	if not enabled or not _is_finite_vector3(world_position):
		return Vector3.UP
	var surface_normal: Vector3 = _get_surface_normal_at(world_position)
	if not _is_finite_vector3(surface_normal) or surface_normal.is_zero_approx():
		return Vector3.UP
	return surface_normal.normalized()


## 获取采样点处的世界空间流体速度。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 世界空间流体速度；无效时返回零向量。
func get_fluid_velocity_at(world_position: Vector3) -> Vector3:
	if not enabled or not _is_finite_vector3(world_position):
		return Vector3.ZERO
	var velocity: Vector3 = _get_fluid_velocity_at(world_position)
	return velocity if _is_finite_vector3(velocity) else Vector3.ZERO


## 获取调用方组合多个浮力场时使用的优先级。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 优先级数值，越大越优先。
func get_buoyancy_priority() -> int:
	return priority


## 采样单个排水点的浸没状态、浮力和阻力。
##
## 方法不修改 RigidBody3D。调用方可把 `force` 传给 `apply_force()`，也可以只读取
## 浸没比例驱动音效、粒子、控制器或自定义物理积分。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param world_position: 排水点世界坐标。
## [br]
## @param point_velocity: 排水点世界空间速度。
## [br]
## @param displaced_volume: 排水点代表的最大排水体积。
## [br]
## @param immersion_radius: 从半浸没到完全浸没所需距离。
## [br]
## @param gravity_acceleration: 当前排水点的重力加速度向量。
## [br]
## @return 采样结果字典。
## [br]
## @schema return: Dictionary，包含 available、active、reason、signed_depth、submersion_ratio、surface_normal、fluid_velocity、buoyancy_force、drag_force 和 force。
func sample_point(
	world_position: Vector3,
	point_velocity: Vector3,
	displaced_volume: float,
	immersion_radius: float,
	gravity_acceleration: Vector3
) -> Dictionary:
	if not enabled:
		return _make_inactive_sample(&"disabled")
	if (
		not _is_finite_vector3(world_position)
		or not _is_finite_vector3(point_velocity)
		or not _is_finite_vector3(gravity_acceleration)
		or not _is_finite_float(displaced_volume)
		or not _is_finite_float(immersion_radius)
		or displaced_volume < 0.0
		or immersion_radius <= 0.0
	):
		return _make_inactive_sample(&"invalid_input")

	var signed_depth: float = _get_signed_depth_at(world_position)
	if not _is_finite_float(signed_depth):
		return _make_inactive_sample(&"invalid_surface")
	var surface_normal: Vector3 = get_surface_normal_at(world_position)
	var sampled_fluid_velocity: Vector3 = get_fluid_velocity_at(world_position)
	var submersion_ratio: float = _BUOYANCY_MATH_SCRIPT.calculate_submersion_ratio(
		signed_depth,
		immersion_radius
	)
	var buoyancy_force: Vector3 = _BUOYANCY_MATH_SCRIPT.calculate_buoyancy_force(
		gravity_acceleration,
		fluid_density,
		displaced_volume,
		submersion_ratio
	)
	var drag_force: Vector3 = _BUOYANCY_MATH_SCRIPT.calculate_drag_force(
		point_velocity - sampled_fluid_velocity,
		linear_drag_coefficient,
		quadratic_drag_coefficient,
		submersion_ratio
	)
	return {
		"available": true,
		"active": submersion_ratio > 0.0,
		"reason": &"",
		"signed_depth": signed_depth,
		"submersion_ratio": submersion_ratio,
		"surface_normal": surface_normal,
		"fluid_velocity": sampled_fluid_velocity,
		"buoyancy_force": buoyancy_force,
		"drag_force": drag_force,
		"force": buoyancy_force + drag_force,
	}


# --- 可重写钩子 / 虚方法 ---

## 计算世界坐标相对流体表面的有符号深度。
##
## 默认实现使用节点局部 Y 平面；子类可实现有限体积、高度场或其他连续表面。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 正数表示流体内部，负数表示外部。
func _get_signed_depth_at(world_position: Vector3) -> float:
	var surface_normal: Vector3 = _get_surface_normal_at(world_position)
	if not _is_finite_vector3(surface_normal) or surface_normal.is_zero_approx():
		return -INF
	return (get_surface_origin() - world_position).dot(surface_normal.normalized())


## 计算采样点处的世界空间流体表面法线。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 世界空间表面法线。
func _get_surface_normal_at(world_position: Vector3) -> Vector3:
	if not _is_finite_vector3(world_position):
		return Vector3.UP
	var basis_y: Vector3 = global_basis.y
	return basis_y.normalized() if not basis_y.is_zero_approx() else Vector3.UP


## 计算采样点处的世界空间流体速度。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param world_position: 世界空间采样点。
## [br]
## @return 世界空间流体速度。
func _get_fluid_velocity_at(world_position: Vector3) -> Vector3:
	if not _is_finite_vector3(world_position):
		return Vector3.ZERO
	return fluid_velocity


# --- 私有/辅助方法 ---

func _make_inactive_sample(reason: StringName) -> Dictionary:
	return {
		"available": false,
		"active": false,
		"reason": reason,
		"signed_depth": 0.0,
		"submersion_ratio": 0.0,
		"surface_normal": Vector3.UP,
		"fluid_velocity": Vector3.ZERO,
		"buoyancy_force": Vector3.ZERO,
		"drag_force": Vector3.ZERO,
		"force": Vector3.ZERO,
	}


func _finite_float_or(value: float, fallback: float) -> float:
	return fallback if not _is_finite_float(value) else value


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)
