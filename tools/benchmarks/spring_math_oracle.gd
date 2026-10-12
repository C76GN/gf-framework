# 有限数值探针使用的独立解析参照，不是 GF 的运行时 API。
extends RefCounted


# --- 框架内部方法 ---

## 精确积分一个目标速度保持常值的区间；目标从 target_value 线性前进。
## 方程为 x'' + 2*zeta*omega*x' + omega^2*x = omega^2*g + response*zeta*omega*g'。
## 输入仅用于有界探针；不复用 GFSpringMath 的步进或稳定下界。
## [br]
## @api framework_internal
## [br]
## @param current_value: 区间起点的有限标量值。
## [br]
## @param velocity: 区间起点的有限标量速度。
## [br]
## @param target_value: 区间起点的有限目标值。
## [br]
## @param delta_seconds: 0 至 120 秒的有限区间。
## [br]
## @param frequency_hz: 0 至 1000 范围内的有限正频率。
## [br]
## @param damping_ratio: 0 至 10 范围内的有限阻尼比。
## [br]
## @param response: 绝对值不超过 100 的有限响应系数。
## [br]
## @param target_velocity: 目标在本区间的有限线性速度。
## [br]
## @return: 闭合四字段结果；失败无可用候选状态。
## [br]
## @schema return: Dictionary，固定 ok: bool、error: String、value: float、velocity: float；成功 error 为空，失败数值为 0。
static func step(
	current_value: float,
	velocity: float,
	target_value: float,
	delta_seconds: float,
	frequency_hz: float,
	damping_ratio: float,
	response: float = 0.0,
	target_velocity: float = 0.0
) -> Dictionary:
	for item: float in [current_value, velocity, target_value, delta_seconds, frequency_hz, damping_ratio, response, target_velocity]:
		if not is_finite(item):
			return _reject("Oracle inputs must be finite.")
	if delta_seconds < 0.0 or delta_seconds > 120.0 or frequency_hz <= 0.0 or frequency_hz > 1000.0:
		return _reject("Oracle time or frequency is outside the bounded probe domain.")
	if damping_ratio < 0.0 or damping_ratio > 10.0 or absf(response) > 100.0:
		return _reject("Oracle damping or response is outside the bounded probe domain.")
	if maxf(absf(current_value), maxf(absf(velocity), maxf(absf(target_value), absf(target_velocity)))) > 1000000.0:
		return _reject("Oracle state exceeds the bounded probe magnitude.")
	var omega: float = TAU * frequency_hz
	var offset: float = (response - 2.0) * damping_ratio * target_velocity / omega
	var displacement: float = current_value - (target_value + offset)
	var relative_velocity: float = velocity - target_velocity
	var next_displacement: float = 0.0
	var next_relative_velocity: float = 0.0
	if damping_ratio < 1.0:
		var decay_rate: float = damping_ratio * omega
		var damped_frequency: float = omega * sqrt(1.0 - damping_ratio * damping_ratio)
		var sine: float = sin(damped_frequency * delta_seconds)
		var cosine: float = cos(damped_frequency * delta_seconds)
		var decay: float = exp(-decay_rate * delta_seconds)
		next_displacement = decay * (displacement * cosine + (relative_velocity + decay_rate * displacement) * sine / damped_frequency)
		next_relative_velocity = decay * (relative_velocity * cosine - (decay_rate * relative_velocity + omega * omega * displacement) * sine / damped_frequency)
	elif damping_ratio == 1.0:
		var critical_coefficient: float = relative_velocity + omega * displacement
		var critical_decay: float = exp(-omega * delta_seconds)
		next_displacement = critical_decay * (displacement + critical_coefficient * delta_seconds)
		next_relative_velocity = critical_decay * (relative_velocity - omega * critical_coefficient * delta_seconds)
	else:
		var discriminant: float = sqrt(damping_ratio * damping_ratio - 1.0)
		var first_root: float = -omega * (damping_ratio - discriminant)
		var second_root: float = -omega * (damping_ratio + discriminant)
		var first_coefficient: float = (relative_velocity - second_root * displacement) / (first_root - second_root)
		var second_coefficient: float = displacement - first_coefficient
		var first_decay: float = exp(first_root * delta_seconds)
		var second_decay: float = exp(second_root * delta_seconds)
		next_displacement = first_coefficient * first_decay + second_coefficient * second_decay
		next_relative_velocity = first_root * first_coefficient * first_decay + second_root * second_coefficient * second_decay
	var next_value: float = target_value + target_velocity * delta_seconds + offset + next_displacement
	var next_velocity: float = target_velocity + next_relative_velocity
	if not is_finite(next_value) or not is_finite(next_velocity):
		return _reject("Oracle output is not finite.")
	return {"ok": true, "error": "", "value": next_value, "velocity": next_velocity}


# --- 私有/辅助方法 ---

## 返回不包含部分数值状态的参照拒绝结果。
## [br]
## @api private
static func _reject(message: String) -> Dictionary:
	return {"ok": false, "error": message, "value": 0.0, "velocity": 0.0}
