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

## 弹簧更新使用的最小有效频率。
## [br]
## @api private
## [br]
const _MIN_FREQUENCY_HZ: float = 0.001

## 稳定性下界计算使用的安全系数。
## [br]
## @api private
## [br]
const _STABILITY_SAFETY_MARGIN: float = 1.1


# --- 公共方法 ---

## 对 float 值执行一次二阶弹簧步进。
## 全部输入须有限；非有限输入或结果发出一次错误并返回空字典，不提供部分状态。
## [br]
## @api public
## [br]
## @since 4.1.0
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
## @return: 成功包含下一帧 value 与 velocity；非有限输入或计算结果返回空字典。
## [br]
## @schema return: Dictionary，失败为空，成功仅包含有限 value: float 与 velocity: float。
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
	if not _scalar_inputs_are_finite(current_value, velocity, target_value, delta_seconds, frequency_hz, damping_ratio, response, target_velocity):
		return _reject_input("step_float")
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
	if not _values_are_finite(values):
		return _reject_result("step_float")
	return {
		"value": values[0],
		"velocity": values[1],
	}


## 对弧度角执行一次二阶弹簧步进，并沿最短角度方向靠近目标。
## 全部输入先做有限准入；非有限输入或角差/步进结果发出一次错误并返回空字典。
## [br]
## @api public
## [br]
## @since 4.1.0
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
## @return: 成功包含下一帧 value 与 velocity，value 不会自动归一化；非有限输入或结果为空字典。
## [br]
## @schema return: Dictionary，失败为空，成功仅包含有限 value: float 与 velocity: float。
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
	if not _scalar_inputs_are_finite(current_radians, velocity, target_radians, delta_seconds, frequency_hz, damping_ratio, response, target_velocity):
		return _reject_input("step_angle")
	if delta_seconds <= 0.0:
		return {"value": current_radians, "velocity": velocity}
	var adjusted_target: float = current_radians + angle_difference(current_radians, target_radians)
	if not is_finite(adjusted_target):
		return _reject_result("step_angle")
	var values: PackedFloat64Array = _step_float_values(
		current_radians,
		velocity,
		adjusted_target,
		delta_seconds,
		frequency_hz,
		damping_ratio,
		response,
		target_velocity
	)
	if not _values_are_finite(values):
		return _reject_result("step_angle")
	return {"value": values[0], "velocity": values[1]}


## 对 Vector2 值执行一次逐分量二阶弹簧步进。
## 全部输入分量与参数须有限；最终原生向量也须有限，失败发出一次错误并返回空字典。
## [br]
## @api public
## [br]
## @since 4.1.0
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
## @return: 成功包含完整下一帧 value 与 velocity；非有限输入或任一结果分量为空字典。
## [br]
## @schema return: Dictionary，失败为空，成功仅包含分量均有限的 value: Vector2 与 velocity: Vector2。
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
	if not current_value.is_finite() or not velocity.is_finite() or not target_value.is_finite() or not target_velocity.is_finite():
		return _reject_input("step_vector2")
	if not _parameters_are_finite(delta_seconds, frequency_hz, damping_ratio, response):
		return _reject_input("step_vector2")
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
	if not _values_are_finite(x_values) or not _values_are_finite(y_values):
		return _reject_result("step_vector2")
	var next_value: Vector2 = Vector2(x_values[0], y_values[0])
	var next_velocity: Vector2 = Vector2(x_values[1], y_values[1])
	if not next_value.is_finite() or not next_velocity.is_finite():
		return _reject_result("step_vector2")
	return {
		"value": next_value,
		"velocity": next_velocity,
	}


## 对 Vector3 值执行一次逐分量二阶弹簧步进。
## 全部输入分量与参数须有限；最终原生向量也须有限，失败发出一次错误并返回空字典。
## [br]
## @api public
## [br]
## @since 4.1.0
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
## @return: 成功包含完整下一帧 value 与 velocity；非有限输入或任一结果分量为空字典。
## [br]
## @schema return: Dictionary，失败为空，成功仅包含分量均有限的 value: Vector3 与 velocity: Vector3。
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
	if not current_value.is_finite() or not velocity.is_finite() or not target_value.is_finite() or not target_velocity.is_finite():
		return _reject_input("step_vector3")
	if not _parameters_are_finite(delta_seconds, frequency_hz, damping_ratio, response):
		return _reject_input("step_vector3")
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
	if not _values_are_finite(x_values) or not _values_are_finite(y_values) or not _values_are_finite(z_values):
		return _reject_result("step_vector3")
	var next_value: Vector3 = Vector3(x_values[0], y_values[0], z_values[0])
	var next_velocity: Vector3 = Vector3(x_values[1], y_values[1], z_values[1])
	if not next_value.is_finite() or not next_velocity.is_finite():
		return _reject_result("step_vector3")
	return {
		"value": next_value,
		"velocity": next_velocity,
	}


# --- 私有/辅助方法 ---

## 一次验证全部标量输入，不构造临时参数数组，不把非有限参数交给钳制算式。
## [br]
## @api private
static func _scalar_inputs_are_finite(current_value: float, velocity: float, target_value: float, delta_seconds: float, frequency_hz: float, damping_ratio: float, response: float, target_velocity: float) -> bool:
	return is_finite(current_value) and is_finite(velocity) and is_finite(target_value) and is_finite(target_velocity) and _parameters_are_finite(delta_seconds, frequency_hz, damping_ratio, response)


## 校验四种入口共用的时间、频率、阻尼和响应参数；有限负参数仍由既有算式规范化。
## [br]
## @api private
static func _parameters_are_finite(delta_seconds: float, frequency_hz: float, damping_ratio: float, response: float) -> bool:
	return is_finite(delta_seconds) and is_finite(frequency_hz) and is_finite(damping_ratio) and is_finite(response)


## 检查私有标量步进的完整双状态，不允许有限极值产生非有限候选。
## [br]
## @api private
static func _values_are_finite(values: PackedFloat64Array) -> bool:
	return values.size() == 2 and is_finite(values[0]) and is_finite(values[1])


## 所有入口复用一个输入拒绝模板，向量失败不会逐分量重复输出。
## [br]
## @api private
static func _reject_input(method_name: String) -> Dictionary:
	push_error("[GFSpringMath][spring_math.non_finite_input] Cannot evaluate %s: inputs must be finite." % method_name)
	return {}


## 保留正确入口上下文并拒绝全部非有限结果，不输出部分状态。
## [br]
## @api private
static func _reject_result(method_name: String) -> Dictionary:
	push_error("[GFSpringMath][spring_math.non_finite_result] Cannot evaluate %s: the result is not finite." % method_name)
	return {}


## 对标量状态执行带稳定下界的半隐式弹簧步进并返回值与速度。
## [br]
## @api private
## [br]
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
