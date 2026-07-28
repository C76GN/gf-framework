## GFTrajectoryMath: 通用运动预测、拦截和公式轨迹采样工具。
##
## 运动预测和拦截入口是 GF 内部无节点副作用的纯计算，不负责绘制、物理推进、目标选择或业务策略。
## 公式采样会同步执行项目显式提供的可信 Callable，并在调用前执行硬预算校验；GF 本身不访问节点，
## 但回调的副作用、阻塞与计算成本由调用方负责。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFTrajectoryMath
extends RefCounted


# --- 常量 ---

## 表示计算成功，没有失败原因。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_NONE: StringName = &""

## 表示输入参数无效、包含非有限数字，或计算结果无法保持有限。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_INVALID_ARGUMENT: StringName = &"invalid_argument"

## 表示拦截方程不存在非负实数解。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_NO_SOLUTION: StringName = &"no_solution"

## 表示拦截解超出调用方给定的时间窗口。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_BEYOND_HORIZON: StringName = &"beyond_horizon"

## 表示轨迹公式 Callable 无效。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_INVALID_PROVIDER: StringName = &"invalid_provider"

## 表示请求采样数量超过本次预算。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_SAMPLE_LIMIT_EXCEEDED: StringName = &"sample_limit_exceeded"

## 表示公式返回了错误类型或非有限坐标。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_PROVIDER_FAILED: StringName = &"provider_failed"

## 默认浮点容差。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_EPSILON: float = 0.000001

## 单次公式采样的默认点数预算。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_SAMPLE_COUNT: int = 1024

## 单次公式采样不可绕过的绝对点数上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_SAMPLE_COUNT: int = 16_384

# Godot 标准构建的 real_t 为 float32；双精度构建使用 float64。
const _FLOAT32_MACHINE_EPSILON: float = 0.00000011920928955078125
const _FLOAT64_MACHINE_EPSILON: float = 0.0000000000000002220446049250313
const _FLOAT32_HALF_ULP_AT_ONE: float = 0.000000059604644775390625
const _DISCRIMINANT_ROUNDOFF_FACTOR: float = 1.0


# --- 公共方法 ---

## 按恒定加速度预测 2D 未来位置和速度。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param initial_position: 当前世界或局部位置，由调用方保证坐标空间一致。
## [br]
## @param initial_velocity: 当前速度。
## [br]
## @param acceleration: 在预测区间内保持恒定的加速度。
## [br]
## @param time_seconds: 非负预测秒数。
## [br]
## @return 运动预测报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空或 invalid_argument）、error: String、time_seconds: float、position: Vector2、velocity: Vector2；成功时 time_seconds 等于请求值，失败时 time_seconds 为 0 且向量为零。
static func predict_motion_2d(
	initial_position: Vector2,
	initial_velocity: Vector2,
	acceleration: Vector2,
	time_seconds: float
) -> Dictionary:
	if (
		not _is_finite_vector2(initial_position)
		or not _is_finite_vector2(initial_velocity)
		or not _is_finite_vector2(acceleration)
		or not _is_nonnegative_finite_float(time_seconds)
	):
		return _make_motion_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Motion inputs and time_seconds must be finite, and time_seconds must be non-negative."
		)

	var velocity_displacement: Vector2 = _scale_vector2(initial_velocity, time_seconds)
	var acceleration_velocity_delta: Vector2 = _scale_vector2(acceleration, time_seconds)
	var acceleration_displacement: Vector2 = _scale_vector2(
		acceleration_velocity_delta,
		0.5 * time_seconds
	)
	var predicted_position: Vector2 = (
		initial_position
		+ velocity_displacement
		+ acceleration_displacement
	)
	var predicted_velocity: Vector2 = initial_velocity + acceleration_velocity_delta
	if not _is_finite_vector2(predicted_position) or not _is_finite_vector2(predicted_velocity):
		return _make_motion_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Motion prediction produced non-finite output."
		)

	return _make_motion_report_2d(
		true,
		REASON_NONE,
		"",
		time_seconds,
		predicted_position,
		predicted_velocity
	)


## 按恒定加速度预测 3D 未来位置和速度。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param initial_position: 当前世界或局部位置，由调用方保证坐标空间一致。
## [br]
## @param initial_velocity: 当前速度。
## [br]
## @param acceleration: 在预测区间内保持恒定的加速度。
## [br]
## @param time_seconds: 非负预测秒数。
## [br]
## @return 运动预测报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空或 invalid_argument）、error: String、time_seconds: float、position: Vector3、velocity: Vector3；成功时 time_seconds 等于请求值，失败时 time_seconds 为 0 且向量为零。
static func predict_motion_3d(
	initial_position: Vector3,
	initial_velocity: Vector3,
	acceleration: Vector3,
	time_seconds: float
) -> Dictionary:
	if (
		not _is_finite_vector3(initial_position)
		or not _is_finite_vector3(initial_velocity)
		or not _is_finite_vector3(acceleration)
		or not _is_nonnegative_finite_float(time_seconds)
	):
		return _make_motion_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Motion inputs and time_seconds must be finite, and time_seconds must be non-negative."
		)

	var velocity_displacement: Vector3 = _scale_vector3(initial_velocity, time_seconds)
	var acceleration_velocity_delta: Vector3 = _scale_vector3(acceleration, time_seconds)
	var acceleration_displacement: Vector3 = _scale_vector3(
		acceleration_velocity_delta,
		0.5 * time_seconds
	)
	var predicted_position: Vector3 = (
		initial_position
		+ velocity_displacement
		+ acceleration_displacement
	)
	var predicted_velocity: Vector3 = initial_velocity + acceleration_velocity_delta
	if not _is_finite_vector3(predicted_position) or not _is_finite_vector3(predicted_velocity):
		return _make_motion_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Motion prediction produced non-finite output."
		)

	return _make_motion_report_3d(
		true,
		REASON_NONE,
		"",
		time_seconds,
		predicted_position,
		predicted_velocity
	)


## 求恒速发射体拦截匀速 2D 目标的最早非负解。
##
## 发射速度使用当前坐标空间中的绝对速度，不隐式继承发射者速度。若发射体需要继承恒定的
## source_velocity，应传入 target_velocity - source_velocity；此时 launch_velocity 是相对发射者的速度，
## 世界速度为 source_velocity + launch_velocity，世界命中点为 position + source_velocity * time_seconds。
## 该方法不计算发射体加速度、重力或障碍物。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param source_position: 发射位置。
## [br]
## @param projectile_speed: 发射体恒定速率，必须大于零。
## [br]
## @param target_position: 目标当前位置。
## [br]
## @param target_velocity: 目标恒定速度。
## [br]
## @param max_time_seconds: 最大预测秒数；负值表示不限制。
## [br]
## @param epsilon: 浮点判定容差；非正值使用 DEFAULT_EPSILON。
## [br]
## @return 最早拦截解报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、no_solution 或 beyond_horizon）、error: String、time_seconds: float、position: Vector2、launch_velocity: Vector2、distance: float；成功时 time_seconds >= 0，正时间解的 launch_velocity 长度等于 projectile_speed，t=0 时为零；失败时 time_seconds 为 -1，其余数值结果为零。
static func solve_intercept_2d(
	source_position: Vector2,
	projectile_speed: float,
	target_position: Vector2,
	target_velocity: Vector2,
	max_time_seconds: float = -1.0,
	epsilon: float = DEFAULT_EPSILON
) -> Dictionary:
	if (
		not _is_finite_vector2(source_position)
		or not _is_finite_vector2(target_position)
		or not _is_finite_vector2(target_velocity)
		or not _is_finite_float(projectile_speed)
		or not _is_finite_float(max_time_seconds)
		or not _is_finite_float(epsilon)
	):
		return _make_intercept_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept inputs must contain only finite values."
		)

	var safe_epsilon: float = _normalize_epsilon(epsilon)
	if projectile_speed <= 0.0:
		return _make_intercept_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"projectile_speed must be greater than zero."
		)

	var relative_position: Vector2 = target_position - source_position
	var time_report: Dictionary = _solve_intercept_time(
		relative_position.length_squared(),
		relative_position.dot(target_velocity),
		target_velocity.length_squared(),
		target_velocity.length(),
		projectile_speed,
		max_time_seconds,
		safe_epsilon
	)
	if not _get_report_ok(time_report):
		return _make_intercept_report_2d(
			false,
			_get_report_reason(time_report),
			_get_report_error(time_report)
		)

	var intercept_time: float = _get_report_time(time_report)
	var target_displacement: Vector2 = _scale_vector2(target_velocity, intercept_time)
	var intercept_position: Vector2 = target_position + target_displacement
	if not _is_finite_vector2(intercept_position):
		return _make_intercept_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept calculation produced non-finite output."
		)

	var launch_velocity: Vector2 = Vector2.ZERO
	if intercept_time > 0.0:
		launch_velocity = _scale_vector2(
			(intercept_position - source_position).normalized(),
			projectile_speed
		)
	var launch_speed_squared: float = launch_velocity.length_squared()
	if (
		not _is_finite_vector2(launch_velocity)
		or (
			intercept_time > 0.0
			and (
				launch_velocity == Vector2.ZERO
				or not _is_finite_float(launch_speed_squared)
				or launch_speed_squared <= 0.0
			)
		)
	):
		return _make_intercept_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept launch_velocity cannot be represented as a finite non-zero Vector2 with usable magnitude."
		)
	var intercept_distance: float = projectile_speed * intercept_time
	if not _is_nonnegative_finite_float(intercept_distance):
		return _make_intercept_report_2d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept distance cannot be represented as a finite value."
		)
	return _make_intercept_report_2d(
		true,
		REASON_NONE,
		"",
		intercept_time,
		intercept_position,
		launch_velocity,
		intercept_distance
	)


## 求恒速发射体拦截匀速 3D 目标的最早非负解。
##
## 发射速度使用当前坐标空间中的绝对速度，不隐式继承发射者速度。若发射体需要继承恒定的
## source_velocity，应传入 target_velocity - source_velocity；此时 launch_velocity 是相对发射者的速度，
## 世界速度为 source_velocity + launch_velocity，世界命中点为 position + source_velocity * time_seconds。
## 该方法不计算发射体加速度、重力或障碍物。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param source_position: 发射位置。
## [br]
## @param projectile_speed: 发射体恒定速率，必须大于零。
## [br]
## @param target_position: 目标当前位置。
## [br]
## @param target_velocity: 目标恒定速度。
## [br]
## @param max_time_seconds: 最大预测秒数；负值表示不限制。
## [br]
## @param epsilon: 浮点判定容差；非正值使用 DEFAULT_EPSILON。
## [br]
## @return 最早拦截解报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、no_solution 或 beyond_horizon）、error: String、time_seconds: float、position: Vector3、launch_velocity: Vector3、distance: float；成功时 time_seconds >= 0，正时间解的 launch_velocity 长度等于 projectile_speed，t=0 时为零；失败时 time_seconds 为 -1，其余数值结果为零。
static func solve_intercept_3d(
	source_position: Vector3,
	projectile_speed: float,
	target_position: Vector3,
	target_velocity: Vector3,
	max_time_seconds: float = -1.0,
	epsilon: float = DEFAULT_EPSILON
) -> Dictionary:
	if (
		not _is_finite_vector3(source_position)
		or not _is_finite_vector3(target_position)
		or not _is_finite_vector3(target_velocity)
		or not _is_finite_float(projectile_speed)
		or not _is_finite_float(max_time_seconds)
		or not _is_finite_float(epsilon)
	):
		return _make_intercept_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept inputs must contain only finite values."
		)

	var safe_epsilon: float = _normalize_epsilon(epsilon)
	if projectile_speed <= 0.0:
		return _make_intercept_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"projectile_speed must be greater than zero."
		)

	var relative_position: Vector3 = target_position - source_position
	var time_report: Dictionary = _solve_intercept_time(
		relative_position.length_squared(),
		relative_position.dot(target_velocity),
		target_velocity.length_squared(),
		target_velocity.length(),
		projectile_speed,
		max_time_seconds,
		safe_epsilon
	)
	if not _get_report_ok(time_report):
		return _make_intercept_report_3d(
			false,
			_get_report_reason(time_report),
			_get_report_error(time_report)
		)

	var intercept_time: float = _get_report_time(time_report)
	var target_displacement: Vector3 = _scale_vector3(target_velocity, intercept_time)
	var intercept_position: Vector3 = target_position + target_displacement
	if not _is_finite_vector3(intercept_position):
		return _make_intercept_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept calculation produced non-finite output."
		)

	var launch_velocity: Vector3 = Vector3.ZERO
	if intercept_time > 0.0:
		launch_velocity = _scale_vector3(
			(intercept_position - source_position).normalized(),
			projectile_speed
		)
	var launch_speed_squared: float = launch_velocity.length_squared()
	if (
		not _is_finite_vector3(launch_velocity)
		or (
			intercept_time > 0.0
			and (
				launch_velocity == Vector3.ZERO
				or not _is_finite_float(launch_speed_squared)
				or launch_speed_squared <= 0.0
			)
		)
	):
		return _make_intercept_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept launch_velocity cannot be represented as a finite non-zero Vector3 with usable magnitude."
		)
	var intercept_distance: float = projectile_speed * intercept_time
	if not _is_nonnegative_finite_float(intercept_distance):
		return _make_intercept_report_3d(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept distance cannot be represented as a finite value."
		)
	return _make_intercept_report_3d(
		true,
		REASON_NONE,
		"",
		intercept_time,
		intercept_position,
		launch_velocity,
		intercept_distance
	)


## 在闭区间内均匀调用同步公式并生成 2D 轨迹点。
##
## sample_count 为 1 时只采样 start_time_seconds；否则首尾时间都会被包含。
## 反向时间区间是合法的。公式必须快速、同步且返回有限 Vector2。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param position_provider: 接收一个 float 秒数并返回 Vector2 的同步 Callable。
## [br]
## @param start_time_seconds: 起始采样时间。
## [br]
## @param end_time_seconds: 结束采样时间。
## [br]
## @param sample_count: 请求采样点数量，必须大于零。
## [br]
## @param max_sample_count: 本次预算，必须位于 1 到 ABSOLUTE_MAX_SAMPLE_COUNT。
## [br]
## @return 有界 2D 采样报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、invalid_provider、sample_limit_exceeded 或 provider_failed）、error: String、start_time_seconds: float、end_time_seconds: float、requested_sample_count: int、sample_limit: int、sampled_count: int、failed_sample_index: int、times: PackedFloat64Array、points: PackedVector2Array；始终满足 sampled_count == times.size() == points.size()；成功时 failed_sample_index 为 -1，运行中失败时为首个失败索引并保留此前有效前缀，预检失败时数组为空且索引为 -1。
static func sample_formula_2d(
	position_provider: Callable,
	start_time_seconds: float,
	end_time_seconds: float,
	sample_count: int,
	max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT
) -> Dictionary:
	var validation_reason: StringName = _validate_sample_request(
		position_provider,
		start_time_seconds,
		end_time_seconds,
		sample_count,
		max_sample_count
	)
	if validation_reason != REASON_NONE:
		return _make_sample_report_2d(
			false,
			validation_reason,
			_get_sample_validation_error(validation_reason),
			start_time_seconds,
			end_time_seconds,
			sample_count,
			max_sample_count
		)

	var times: PackedFloat64Array = PackedFloat64Array()
	var points: PackedVector2Array = PackedVector2Array()
	for sample_index: int in range(sample_count):
		var sample_time: float = _get_sample_time(
			start_time_seconds,
			end_time_seconds,
			sample_index,
			sample_count
		)
		if not _is_finite_float(sample_time):
			return _make_sample_report_2d(
				false,
				REASON_INVALID_ARGUMENT,
				"Sample time interpolation produced non-finite output.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var raw_position: Variant = position_provider.call(sample_time)
		if not raw_position is Vector2:
			return _make_sample_report_2d(
				false,
				REASON_PROVIDER_FAILED,
				"position_provider must return Vector2.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var sample_position: Vector2 = raw_position
		if not _is_finite_vector2(sample_position):
			return _make_sample_report_2d(
				false,
				REASON_PROVIDER_FAILED,
				"position_provider returned non-finite Vector2 coordinates.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var _time_appended: bool = times.append(sample_time)
		var _point_appended: bool = points.append(sample_position)

	return _make_sample_report_2d(
		true,
		REASON_NONE,
		"",
		start_time_seconds,
		end_time_seconds,
		sample_count,
		max_sample_count,
		times,
		points
	)


## 在闭区间内均匀调用同步公式并生成 3D 轨迹点。
##
## sample_count 为 1 时只采样 start_time_seconds；否则首尾时间都会被包含。
## 反向时间区间是合法的。公式必须快速、同步且返回有限 Vector3。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param position_provider: 接收一个 float 秒数并返回 Vector3 的同步 Callable。
## [br]
## @param start_time_seconds: 起始采样时间。
## [br]
## @param end_time_seconds: 结束采样时间。
## [br]
## @param sample_count: 请求采样点数量，必须大于零。
## [br]
## @param max_sample_count: 本次预算，必须位于 1 到 ABSOLUTE_MAX_SAMPLE_COUNT。
## [br]
## @return 有界 3D 采样报告。
## [br]
## @schema return: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、invalid_provider、sample_limit_exceeded 或 provider_failed）、error: String、start_time_seconds: float、end_time_seconds: float、requested_sample_count: int、sample_limit: int、sampled_count: int、failed_sample_index: int、times: PackedFloat64Array、points: PackedVector3Array；始终满足 sampled_count == times.size() == points.size()；成功时 failed_sample_index 为 -1，运行中失败时为首个失败索引并保留此前有效前缀，预检失败时数组为空且索引为 -1。
static func sample_formula_3d(
	position_provider: Callable,
	start_time_seconds: float,
	end_time_seconds: float,
	sample_count: int,
	max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT
) -> Dictionary:
	var validation_reason: StringName = _validate_sample_request(
		position_provider,
		start_time_seconds,
		end_time_seconds,
		sample_count,
		max_sample_count
	)
	if validation_reason != REASON_NONE:
		return _make_sample_report_3d(
			false,
			validation_reason,
			_get_sample_validation_error(validation_reason),
			start_time_seconds,
			end_time_seconds,
			sample_count,
			max_sample_count
		)

	var times: PackedFloat64Array = PackedFloat64Array()
	var points: PackedVector3Array = PackedVector3Array()
	for sample_index: int in range(sample_count):
		var sample_time: float = _get_sample_time(
			start_time_seconds,
			end_time_seconds,
			sample_index,
			sample_count
		)
		if not _is_finite_float(sample_time):
			return _make_sample_report_3d(
				false,
				REASON_INVALID_ARGUMENT,
				"Sample time interpolation produced non-finite output.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var raw_position: Variant = position_provider.call(sample_time)
		if not raw_position is Vector3:
			return _make_sample_report_3d(
				false,
				REASON_PROVIDER_FAILED,
				"position_provider must return Vector3.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var sample_position: Vector3 = raw_position
		if not _is_finite_vector3(sample_position):
			return _make_sample_report_3d(
				false,
				REASON_PROVIDER_FAILED,
				"position_provider returned non-finite Vector3 coordinates.",
				start_time_seconds,
				end_time_seconds,
				sample_count,
				max_sample_count,
				times,
				points,
				sample_index
			)
		var _time_appended: bool = times.append(sample_time)
		var _point_appended: bool = points.append(sample_position)

	return _make_sample_report_3d(
		true,
		REASON_NONE,
		"",
		start_time_seconds,
		end_time_seconds,
		sample_count,
		max_sample_count,
		times,
		points
	)


# --- 私有/辅助方法 ---

static func _solve_intercept_time(
	relative_distance_squared: float,
	relative_position_dot_velocity: float,
	target_speed_squared: float,
	target_speed: float,
	projectile_speed: float,
	max_time_seconds: float,
	epsilon: float
) -> Dictionary:
	if relative_distance_squared <= epsilon * epsilon:
		return _make_time_report(true, REASON_NONE, "", 0.0)

	var projectile_speed_squared: float = projectile_speed * projectile_speed
	var coefficient_a: float = 0.0
	# 先比较未平方的速度，避免同一 Vector.length() 的平方往返误差伪造二次项。
	if target_speed != projectile_speed:
		coefficient_a = target_speed_squared - projectile_speed_squared
	var coefficient_b: float = 2.0 * relative_position_dot_velocity
	var coefficient_c: float = relative_distance_squared
	if (
		not _is_finite_float(coefficient_a)
		or not _is_finite_float(coefficient_b)
		or not _is_finite_float(coefficient_c)
	):
		return _make_time_report(
			false,
			REASON_INVALID_ARGUMENT,
			"Intercept coefficients are non-finite."
		)

	var roots: PackedFloat64Array = PackedFloat64Array()
	# 非零二次项即使很小，也可能表示有效的远期拦截，不能用调用方容差降阶。
	if coefficient_a == 0.0:
		if coefficient_b == 0.0:
			return _make_time_report(false, REASON_NO_SOLUTION, "No non-negative intercept solution exists.")
		_append_nonnegative_root(roots, -coefficient_c / coefficient_b)
	else:
		var discriminant: float = (
			coefficient_b * coefficient_b
			- 4.0 * coefficient_a * coefficient_c
		)
		if not _is_finite_float(discriminant):
			return _make_time_report(
				false,
				REASON_INVALID_ARGUMENT,
				"Intercept discriminant is non-finite."
			)
		var discriminant_scale: float = maxf(
			absf(coefficient_b * coefficient_b),
			absf(4.0 * coefficient_a * coefficient_c)
		)
		# 只吸收 real_t 和后续运算的机器舍入；调用方 epsilon 不能改变实根拓扑。
		var discriminant_roundoff_limit: float = (
			_get_real_component_machine_epsilon()
			* _DISCRIMINANT_ROUNDOFF_FACTOR
			* discriminant_scale
		)
		if discriminant < -discriminant_roundoff_limit:
			return _make_time_report(false, REASON_NO_SOLUTION, "No real intercept solution exists.")

		var sqrt_discriminant: float = sqrt(maxf(discriminant, 0.0))
		var sqrt_discriminant_scale: float = sqrt(discriminant_scale)
		if sqrt_discriminant <= epsilon * sqrt_discriminant_scale:
			_append_nonnegative_root(
				roots,
				-coefficient_b / (2.0 * coefficient_a)
			)
		else:
			var b_sign: float = 1.0 if coefficient_b >= 0.0 else -1.0
			var stable_term: float = -0.5 * (coefficient_b + b_sign * sqrt_discriminant)
			var stable_term_scale: float = maxf(absf(coefficient_b), sqrt_discriminant)
			if absf(stable_term) <= epsilon * stable_term_scale:
				_append_nonnegative_root(
					roots,
					(-coefficient_b - sqrt_discriminant) / (2.0 * coefficient_a)
				)
				_append_nonnegative_root(
					roots,
					(-coefficient_b + sqrt_discriminant) / (2.0 * coefficient_a)
				)
			else:
				_append_nonnegative_root(roots, stable_term / coefficient_a)
				_append_nonnegative_root(roots, coefficient_c / stable_term)

	if roots.is_empty():
		return _make_time_report(false, REASON_NO_SOLUTION, "No non-negative intercept solution exists.")
	roots.sort()
	var intercept_time: float = roots[0]
	if max_time_seconds >= 0.0 and intercept_time > max_time_seconds + epsilon:
		return _make_time_report(
			false,
			REASON_BEYOND_HORIZON,
			"The earliest intercept solution exceeds max_time_seconds."
		)
	return _make_time_report(true, REASON_NONE, "", intercept_time)


static func _get_real_component_machine_epsilon() -> float:
	var precision_probe: float = Vector2(1.0 + _FLOAT32_HALF_ULP_AT_ONE, 0.0).x
	if precision_probe == 1.0:
		return _FLOAT32_MACHINE_EPSILON
	return _FLOAT64_MACHINE_EPSILON


static func _append_nonnegative_root(
	roots: PackedFloat64Array,
	root: float
) -> void:
	if not _is_finite_float(root) or root < 0.0:
		return
	var normalized_root: float = maxf(root, 0.0)
	var _root_appended: bool = roots.append(normalized_root)


static func _validate_sample_request(
	position_provider: Callable,
	start_time_seconds: float,
	end_time_seconds: float,
	sample_count: int,
	max_sample_count: int
) -> StringName:
	if not position_provider.is_valid():
		return REASON_INVALID_PROVIDER
	if not _is_finite_float(start_time_seconds) or not _is_finite_float(end_time_seconds):
		return REASON_INVALID_ARGUMENT
	if sample_count <= 0:
		return REASON_INVALID_ARGUMENT
	if max_sample_count <= 0 or max_sample_count > ABSOLUTE_MAX_SAMPLE_COUNT:
		return REASON_INVALID_ARGUMENT
	if sample_count > max_sample_count:
		return REASON_SAMPLE_LIMIT_EXCEEDED
	return REASON_NONE


static func _get_sample_validation_error(reason: StringName) -> String:
	match reason:
		REASON_INVALID_PROVIDER:
			return "position_provider must be a valid Callable."
		REASON_SAMPLE_LIMIT_EXCEEDED:
			return "sample_count exceeds max_sample_count."
		_:
			return "Sample times and limits must be finite and within the documented bounds."


static func _get_sample_time(
	start_time_seconds: float,
	end_time_seconds: float,
	sample_index: int,
	sample_count: int
) -> float:
	if sample_count <= 1:
		return start_time_seconds
	var ratio: float = float(sample_index) / float(sample_count - 1)
	return start_time_seconds * (1.0 - ratio) + end_time_seconds * ratio


static func _make_motion_report_2d(
	ok: bool,
	reason: StringName,
	error: String,
	time_seconds: float = 0.0,
	predicted_position: Vector2 = Vector2.ZERO,
	predicted_velocity: Vector2 = Vector2.ZERO
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"time_seconds": time_seconds if _is_finite_float(time_seconds) else 0.0,
		"position": predicted_position if _is_finite_vector2(predicted_position) else Vector2.ZERO,
		"velocity": predicted_velocity if _is_finite_vector2(predicted_velocity) else Vector2.ZERO,
	}


static func _make_motion_report_3d(
	ok: bool,
	reason: StringName,
	error: String,
	time_seconds: float = 0.0,
	predicted_position: Vector3 = Vector3.ZERO,
	predicted_velocity: Vector3 = Vector3.ZERO
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"time_seconds": time_seconds if _is_finite_float(time_seconds) else 0.0,
		"position": predicted_position if _is_finite_vector3(predicted_position) else Vector3.ZERO,
		"velocity": predicted_velocity if _is_finite_vector3(predicted_velocity) else Vector3.ZERO,
	}


static func _make_intercept_report_2d(
	ok: bool,
	reason: StringName,
	error: String,
	time_seconds: float = -1.0,
	intercept_position: Vector2 = Vector2.ZERO,
	launch_velocity: Vector2 = Vector2.ZERO,
	distance: float = 0.0
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"time_seconds": time_seconds if _is_finite_float(time_seconds) else -1.0,
		"position": intercept_position if _is_finite_vector2(intercept_position) else Vector2.ZERO,
		"launch_velocity": launch_velocity if _is_finite_vector2(launch_velocity) else Vector2.ZERO,
		"distance": distance if _is_nonnegative_finite_float(distance) else 0.0,
	}


static func _make_intercept_report_3d(
	ok: bool,
	reason: StringName,
	error: String,
	time_seconds: float = -1.0,
	intercept_position: Vector3 = Vector3.ZERO,
	launch_velocity: Vector3 = Vector3.ZERO,
	distance: float = 0.0
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"time_seconds": time_seconds if _is_finite_float(time_seconds) else -1.0,
		"position": intercept_position if _is_finite_vector3(intercept_position) else Vector3.ZERO,
		"launch_velocity": launch_velocity if _is_finite_vector3(launch_velocity) else Vector3.ZERO,
		"distance": distance if _is_nonnegative_finite_float(distance) else 0.0,
	}


static func _make_sample_report_2d(
	ok: bool,
	reason: StringName,
	error: String,
	start_time_seconds: float,
	end_time_seconds: float,
	requested_sample_count: int,
	sample_limit: int,
	times: PackedFloat64Array = PackedFloat64Array(),
	points: PackedVector2Array = PackedVector2Array(),
	failed_sample_index: int = -1
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"start_time_seconds": _finite_or_zero(start_time_seconds),
		"end_time_seconds": _finite_or_zero(end_time_seconds),
		"requested_sample_count": requested_sample_count,
		"sample_limit": sample_limit,
		"sampled_count": points.size(),
		"failed_sample_index": failed_sample_index,
		"times": times,
		"points": points,
	}


static func _make_sample_report_3d(
	ok: bool,
	reason: StringName,
	error: String,
	start_time_seconds: float,
	end_time_seconds: float,
	requested_sample_count: int,
	sample_limit: int,
	times: PackedFloat64Array = PackedFloat64Array(),
	points: PackedVector3Array = PackedVector3Array(),
	failed_sample_index: int = -1
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"start_time_seconds": _finite_or_zero(start_time_seconds),
		"end_time_seconds": _finite_or_zero(end_time_seconds),
		"requested_sample_count": requested_sample_count,
		"sample_limit": sample_limit,
		"sampled_count": points.size(),
		"failed_sample_index": failed_sample_index,
		"times": times,
		"points": points,
	}


static func _make_time_report(
	ok: bool,
	reason: StringName,
	error: String,
	time_seconds: float = -1.0
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"error": error,
		"time_seconds": time_seconds,
	}


static func _get_report_ok(report: Dictionary) -> bool:
	var value: Variant = report.get("ok", false)
	return value if value is bool else false


static func _get_report_reason(report: Dictionary) -> StringName:
	var value: Variant = report.get("reason", REASON_INVALID_ARGUMENT)
	if value is StringName:
		var reason: StringName = value
		return reason
	if value is String:
		var reason_text: String = value
		return StringName(reason_text)
	return REASON_INVALID_ARGUMENT


static func _get_report_error(report: Dictionary) -> String:
	var value: Variant = report.get("error", "")
	if value is String:
		var error_text: String = value
		return error_text
	if value is StringName:
		var error_name: StringName = value
		return String(error_name)
	return ""


static func _get_report_time(report: Dictionary) -> float:
	var value: Variant = report.get("time_seconds", -1.0)
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return -1.0


static func _normalize_epsilon(epsilon: float) -> float:
	return epsilon if epsilon > 0.0 else DEFAULT_EPSILON


static func _finite_or_zero(value: float) -> float:
	return value if _is_finite_float(value) else 0.0


static func _scale_vector2(value: Vector2, scalar: float) -> Vector2:
	return Vector2(value.x * scalar, value.y * scalar)


static func _scale_vector3(value: Vector3, scalar: float) -> Vector3:
	return Vector3(value.x * scalar, value.y * scalar, value.z * scalar)


static func _is_nonnegative_finite_float(value: float) -> bool:
	return value >= 0.0 and _is_finite_float(value)


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		_is_finite_float(value.x)
		and _is_finite_float(value.y)
		and _is_finite_float(value.z)
	)
