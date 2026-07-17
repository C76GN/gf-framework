## GFSpringMath: 通用二阶弹簧平滑数学工具。
##
## 提供 float、角度、Vector2 与 Vector3 的稳定弹簧步进计算。
## 它只根据当前值、速度、目标值和参数输出下一帧状态，不持有节点、不创建 Tween，
## 也不解释相机、UI、角色移动或反馈表现语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.1.0
class_name GFSpringMath
extends RefCounted


# --- 常量 ---

const _MIN_FREQUENCY_HZ: float = 0.001
const _STABILITY_SAFETY_MARGIN: float = 1.1


# --- 公共方法 ---

## 对 float 值执行一次二阶弹簧步进。
## [br]
## @api public
## [br]
## @param current_value: 当前值。
## [br]
## @param velocity: 当前速度；调用方应保存返回的 `velocity` 用于下一次步进。
## [br]
## @param target_value: 目标值。
## [br]
## @param delta_seconds: 本次步进时间；小于等于 0 时返回原状态。
## [br]
## @param frequency_hz: 弹簧频率，越大越快接近目标；会被限制为大于 0。
## [br]
## @param damping_ratio: 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。
## [br]
## @param response: 目标速度响应系数；0 表示忽略 `target_velocity` 的前馈。
## [br]
## @param target_velocity: 目标值自身速度。
## [br]
## @return 包含下一帧 `value` 与 `velocity` 的字典。
## [br]
## @schema return: Dictionary with `value: float` and `velocity: float`.
static func step_float(
	current_value: float,
	velocity: float,
	target_value: float,
	delta_seconds: float,
	frequency_hz: float = 3.0,
	damping_ratio: float = 1.0,
	response: float = 0.0,
	target_velocity: float = 0.0
) -> Dictionary:
	var values: PackedFloat64Array = _step_float_values(
		current_value,
		velocity,
		target_value,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity
	)
	return {
		"value": values[0],
		"velocity": values[1],
	}


## 对弧度角执行一次二阶弹簧步进，并沿最短角度方向靠近目标。
## [br]
## @api public
## [br]
## @param current_radians: 当前角度（弧度）。
## [br]
## @param velocity: 当前角速度；调用方应保存返回的 `velocity` 用于下一次步进。
## [br]
## @param target_radians: 目标角度（弧度）。
## [br]
## @param delta_seconds: 本次步进时间；小于等于 0 时返回原状态。
## [br]
## @param frequency_hz: 弹簧频率，越大越快接近目标；会被限制为大于 0。
## [br]
## @param damping_ratio: 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。
## [br]
## @param response: 目标角速度响应系数；0 表示忽略 `target_velocity` 的前馈。
## [br]
## @param target_velocity: 目标角度自身速度。
## [br]
## @return 包含下一帧 `value` 与 `velocity` 的字典；`value` 不会自动归一化。
## [br]
## @schema return: Dictionary with `value: float` and `velocity: float`.
static func step_angle(
	current_radians: float,
	velocity: float,
	target_radians: float,
	delta_seconds: float,
	frequency_hz: float = 3.0,
	damping_ratio: float = 1.0,
	response: float = 0.0,
	target_velocity: float = 0.0
) -> Dictionary:
	var adjusted_target: float = current_radians + angle_difference(current_radians, target_radians)
	return step_float(
		current_radians,
		velocity,
		adjusted_target,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity
	)


## 对 Vector2 值执行一次逐分量二阶弹簧步进。
## [br]
## @api public
## [br]
## @param current_value: 当前值。
## [br]
## @param velocity: 当前速度；调用方应保存返回的 `velocity` 用于下一次步进。
## [br]
## @param target_value: 目标值。
## [br]
## @param delta_seconds: 本次步进时间；小于等于 0 时返回原状态。
## [br]
## @param frequency_hz: 弹簧频率，越大越快接近目标；会被限制为大于 0。
## [br]
## @param damping_ratio: 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。
## [br]
## @param response: 目标速度响应系数；0 表示忽略 `target_velocity` 的前馈。
## [br]
## @param target_velocity: 目标值自身速度。
## [br]
## @return 包含下一帧 `value` 与 `velocity` 的字典。
## [br]
## @schema return: Dictionary with `value: Vector2` and `velocity: Vector2`.
static func step_vector2(
	current_value: Vector2,
	velocity: Vector2,
	target_value: Vector2,
	delta_seconds: float,
	frequency_hz: float = 3.0,
	damping_ratio: float = 1.0,
	response: float = 0.0,
	target_velocity: Vector2 = Vector2.ZERO
) -> Dictionary:
	var x_values: PackedFloat64Array = _step_float_values(
		current_value.x,
		velocity.x,
		target_value.x,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity.x
	)
	var y_values: PackedFloat64Array = _step_float_values(
		current_value.y,
		velocity.y,
		target_value.y,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity.y
	)
	return {
		"value": Vector2(x_values[0], y_values[0]),
		"velocity": Vector2(x_values[1], y_values[1]),
	}


## 对 Vector3 值执行一次逐分量二阶弹簧步进。
## [br]
## @api public
## [br]
## @param current_value: 当前值。
## [br]
## @param velocity: 当前速度；调用方应保存返回的 `velocity` 用于下一次步进。
## [br]
## @param target_value: 目标值。
## [br]
## @param delta_seconds: 本次步进时间；小于等于 0 时返回原状态。
## [br]
## @param frequency_hz: 弹簧频率，越大越快接近目标；会被限制为大于 0。
## [br]
## @param damping_ratio: 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。
## [br]
## @param response: 目标速度响应系数；0 表示忽略 `target_velocity` 的前馈。
## [br]
## @param target_velocity: 目标值自身速度。
## [br]
## @return 包含下一帧 `value` 与 `velocity` 的字典。
## [br]
## @schema return: Dictionary with `value: Vector3` and `velocity: Vector3`.
static func step_vector3(
	current_value: Vector3,
	velocity: Vector3,
	target_value: Vector3,
	delta_seconds: float,
	frequency_hz: float = 3.0,
	damping_ratio: float = 1.0,
	response: float = 0.0,
	target_velocity: Vector3 = Vector3.ZERO
) -> Dictionary:
	var x_values: PackedFloat64Array = _step_float_values(
		current_value.x,
		velocity.x,
		target_value.x,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity.x
	)
	var y_values: PackedFloat64Array = _step_float_values(
		current_value.y,
		velocity.y,
		target_value.y,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity.y
	)
	var z_values: PackedFloat64Array = _step_float_values(
		current_value.z,
		velocity.z,
		target_value.z,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity.z
	)
	return {
		"value": Vector3(x_values[0], y_values[0], z_values[0]),
		"velocity": Vector3(x_values[1], y_values[1], z_values[1]),
	}


# --- 私有/辅助方法 ---

static func _step_float_values(
	current_value: float,
	velocity: float,
	target_value: float,
	delta_seconds: float,
	frequency_hz: float,
	damping_ratio: float,
	response: float,
	target_velocity: float
) -> PackedFloat64Array:
	if delta_seconds <= 0.0:
		return PackedFloat64Array([current_value, velocity])

	var safe_frequency_hz: float = maxf(frequency_hz, _MIN_FREQUENCY_HZ)
	var safe_damping_ratio: float = maxf(damping_ratio, 0.0)
	var angular_frequency: float = TAU * safe_frequency_hz
	var k1: float = safe_damping_ratio / (PI * safe_frequency_hz)
	var k2: float = 1.0 / (angular_frequency * angular_frequency)
	var k3: float = response * safe_damping_ratio / angular_frequency
	var combined_stability_floor: float = _STABILITY_SAFETY_MARGIN * (
		delta_seconds * delta_seconds * 0.25 + delta_seconds * k1 * 0.5
	)
	var stable_k2: float = maxf(
		k2,
		maxf(
			combined_stability_floor,
			delta_seconds * k1
		)
	)
	var acceleration: float = (
		target_value
		+ k3 * target_velocity
		- current_value
		- k1 * velocity
	) / stable_k2
	var next_velocity: float = velocity + delta_seconds * acceleration
	var next_value: float = current_value + delta_seconds * next_velocity
	return PackedFloat64Array([next_value, next_velocity])
