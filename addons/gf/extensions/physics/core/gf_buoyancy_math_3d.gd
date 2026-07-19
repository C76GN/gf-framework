## GFBuoyancyMath3D: 通用 3D 浮力点采样数学工具。
##
## 只根据浸没深度、排水体积、重力和相对速度计算浸没比例与力，
## 不查询水体、不持有刚体，也不决定探针布局或施力时机。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFBuoyancyMath3D
extends RefCounted


# --- 公共方法 ---

## 根据采样点到流体表面的有符号深度计算浸没比例。
##
## 深度为正表示位于表面下方；`-immersion_radius` 为完全离水，
## `0` 为一半浸没，`immersion_radius` 为完全浸没。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param signed_depth: 采样点相对流体表面的有符号深度。
## [br]
## @param immersion_radius: 从半浸没到完全浸没所需的距离，必须大于 0。
## [br]
## @return 0 到 1 的浸没比例；输入无效时返回 0。
static func calculate_submersion_ratio(signed_depth: float, immersion_radius: float) -> float:
	if not _is_finite_float(signed_depth) or not _is_finite_float(immersion_radius) or immersion_radius <= 0.0:
		return 0.0
	return clampf(0.5 + signed_depth / (2.0 * immersion_radius), 0.0, 1.0)


## 计算一个采样点的阿基米德浮力。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param gravity_acceleration: 当前点的重力加速度向量。
## [br]
## @param fluid_density: 流体密度。
## [br]
## @param displaced_volume: 该采样点代表的最大排水体积。
## [br]
## @param submersion_ratio: 0 到 1 的浸没比例。
## [br]
## @return 与重力方向相反的浮力；输入或计算结果无效时返回零向量。
static func calculate_buoyancy_force(
	gravity_acceleration: Vector3,
	fluid_density: float,
	displaced_volume: float,
	submersion_ratio: float
) -> Vector3:
	if (
		not _is_finite_vector3(gravity_acceleration)
		or not _is_finite_float(fluid_density)
		or not _is_finite_float(displaced_volume)
		or not _is_finite_float(submersion_ratio)
		or fluid_density <= 0.0
		or displaced_volume <= 0.0
	):
		return Vector3.ZERO
	var ratio: float = clampf(submersion_ratio, 0.0, 1.0)
	var force: Vector3 = -gravity_acceleration * fluid_density * displaced_volume * ratio
	return force if _is_finite_vector3(force) else Vector3.ZERO


## 计算流体相对速度产生的线性与二次阻力。
##
## 两个系数都是点采样的有效力系数，由调用方按对象尺度和期望响应标定；
## GF 不把它们解释为某种固定形状的阻力面积或黏度模型。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param relative_velocity: 物体采样点相对流体的速度。
## [br]
## @param linear_coefficient: 线性阻力有效系数。
## [br]
## @param quadratic_coefficient: 二次阻力有效系数。
## [br]
## @param submersion_ratio: 0 到 1 的浸没比例。
## [br]
## @return 与相对速度相反的阻力；输入或计算结果无效时返回零向量。
static func calculate_drag_force(
	relative_velocity: Vector3,
	linear_coefficient: float,
	quadratic_coefficient: float,
	submersion_ratio: float
) -> Vector3:
	if (
		not _is_finite_vector3(relative_velocity)
		or not _is_finite_float(linear_coefficient)
		or not _is_finite_float(quadratic_coefficient)
		or not _is_finite_float(submersion_ratio)
	):
		return Vector3.ZERO
	var ratio: float = clampf(submersion_ratio, 0.0, 1.0)
	var linear_drag: float = maxf(linear_coefficient, 0.0)
	var quadratic_drag: float = maxf(quadratic_coefficient, 0.0)
	var speed: float = relative_velocity.length()
	if not _is_finite_float(speed):
		return Vector3.ZERO
	var force: Vector3 = -(
		relative_velocity * linear_drag
		+ relative_velocity * speed * quadratic_drag
	) * ratio
	return force if _is_finite_vector3(force) else Vector3.ZERO


## 组合一个采样点的浮力与阻力。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param gravity_acceleration: 当前点的重力加速度向量。
## [br]
## @param point_velocity: 物体采样点速度。
## [br]
## @param fluid_velocity: 流体在采样点的速度。
## [br]
## @param fluid_density: 流体密度。
## [br]
## @param displaced_volume: 采样点代表的最大排水体积。
## [br]
## @param submersion_ratio: 0 到 1 的浸没比例。
## [br]
## @param linear_coefficient: 线性阻力有效系数。
## [br]
## @param quadratic_coefficient: 二次阻力有效系数。
## [br]
## @return 浮力与阻力之和。
static func calculate_point_force(
	gravity_acceleration: Vector3,
	point_velocity: Vector3,
	fluid_velocity: Vector3,
	fluid_density: float,
	displaced_volume: float,
	submersion_ratio: float,
	linear_coefficient: float,
	quadratic_coefficient: float
) -> Vector3:
	var buoyancy_force: Vector3 = calculate_buoyancy_force(
		gravity_acceleration,
		fluid_density,
		displaced_volume,
		submersion_ratio
	)
	var drag_force: Vector3 = calculate_drag_force(
		point_velocity - fluid_velocity,
		linear_coefficient,
		quadratic_coefficient,
		submersion_ratio
	)
	var force: Vector3 = buoyancy_force + drag_force
	return force if _is_finite_vector3(force) else Vector3.ZERO


# --- 私有/辅助方法 ---

static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)
