## 测试 GFSpringMath 的标量、角度和向量弹簧步进。
extends GutTest

# --- 测试 ---

func test_step_float_moves_towards_target_and_tracks_velocity() -> void:
	var value: float = 0.0
	var velocity: float = 0.0

	for _index: int in range(12):
		var state: Dictionary = GFSpringMath.step_float(
			value,
			velocity,
			1.0,
			1.0 / 60.0,
			4.0,
			1.0
		)
		value = GFVariantData.get_option_float(state, "value")
		velocity = GFVariantData.get_option_float(state, "velocity")

	assert_true(value > 0.0, "弹簧应向目标推进。")
	assert_true(value < 1.2, "临界阻尼附近不应在短时间内产生大幅过冲。")
	assert_true(absf(velocity) > 0.0, "返回速度应可继续用于下一帧。")


func test_step_float_stays_stable_across_common_physics_tick_rates() -> void:
	var tick_rates: Array[int] = [30, 60, 120]
	var final_values: Array[float] = []
	var final_velocities: Array[float] = []
	var transient_values: Array[float] = []
	var transient_velocities: Array[float] = []
	var transient_time_seconds: float = 8.0 / 30.0

	for tick_rate: int in tick_rates:
		var delta_seconds: float = 1.0 / float(tick_rate)
		var transient_step_count: int = roundi(float(tick_rate) * transient_time_seconds)
		var value: float = 0.0
		var velocity: float = 0.0
		var peak_absolute_value: float = 0.0
		var peak_absolute_velocity: float = 0.0
		for _step_index: int in range(tick_rate):
			var state: Dictionary = GFSpringMath.step_float(
				value,
				velocity,
				1.0,
				delta_seconds,
				4.0,
				1.0
			)
			value = GFVariantData.get_option_float(state, "value")
			velocity = GFVariantData.get_option_float(state, "velocity")
			peak_absolute_value = maxf(peak_absolute_value, absf(value))
			peak_absolute_velocity = maxf(peak_absolute_velocity, absf(velocity))
			if _step_index + 1 == transient_step_count:
				transient_values.append(value)
				transient_velocities.append(velocity)

		assert_true(is_finite(value), "%s Hz 的最终值应保持有限。" % tick_rate)
		assert_true(is_finite(velocity), "%s Hz 的最终速度应保持有限。" % tick_rate)
		assert_lte(peak_absolute_value, 1.01, "%s Hz 不应产生明显过冲。" % tick_rate)
		assert_lte(peak_absolute_velocity, 16.0, "%s Hz 的速度应保持有界。" % tick_rate)
		assert_almost_eq(value, 1.0, 0.001, "%s Hz 跑满一秒后应收敛到目标。" % tick_rate)
		assert_almost_eq(velocity, 0.0, 0.001, "%s Hz 跑满一秒后速度应接近零。" % tick_rate)
		final_values.append(value)
		final_velocities.append(velocity)

	assert_almost_eq(final_values[0], final_values[1], 0.0001, "30 Hz 与 60 Hz 的终值应近似一致。")
	assert_almost_eq(final_values[1], final_values[2], 0.0001, "60 Hz 与 120 Hz 的终值应近似一致。")
	assert_almost_eq(final_velocities[0], final_velocities[1], 0.0001, "30 Hz 与 60 Hz 的终速应近似一致。")
	assert_almost_eq(final_velocities[1], final_velocities[2], 0.0001, "60 Hz 与 120 Hz 的终速应近似一致。")
	assert_almost_eq(transient_values[0], transient_values[1], 0.01, "30 Hz 与 60 Hz 在约 0.25 秒时的瞬态值应近似一致。")
	assert_almost_eq(transient_values[1], transient_values[2], 0.01, "60 Hz 与 120 Hz 在约 0.25 秒时的瞬态值应近似一致。")
	assert_almost_eq(transient_velocities[0], transient_velocities[1], 0.07, "30 Hz 与 60 Hz 在约 0.25 秒时的瞬态速度应近似一致。")
	assert_almost_eq(transient_velocities[1], transient_velocities[2], 0.07, "60 Hz 与 120 Hz 在约 0.25 秒时的瞬态速度应近似一致。")


func test_step_float_underdamped_response_decays_at_30_hz() -> void:
	var tick_rate: int = 30
	var total_steps: int = tick_rate * 3
	var delta_seconds: float = 1.0 / float(tick_rate)
	var value: float = 0.0
	var velocity: float = 0.0
	var peak_absolute_value: float = 0.0
	var peak_absolute_velocity: float = 0.0
	var first_window_peak_error: float = 0.0
	var final_window_peak_error: float = 0.0
	var all_values_finite: bool = true
	var all_velocities_finite: bool = true

	for step_index: int in range(total_steps):
		var state: Dictionary = GFSpringMath.step_float(
			value,
			velocity,
			1.0,
			delta_seconds,
			8.0,
			0.2
		)
		value = GFVariantData.get_option_float(state, "value")
		velocity = GFVariantData.get_option_float(state, "velocity")
		all_values_finite = all_values_finite and is_finite(value)
		all_velocities_finite = all_velocities_finite and is_finite(velocity)
		peak_absolute_value = maxf(peak_absolute_value, absf(value))
		peak_absolute_velocity = maxf(peak_absolute_velocity, absf(velocity))
		var absolute_error: float = absf(1.0 - value)
		if step_index < tick_rate:
			first_window_peak_error = maxf(first_window_peak_error, absolute_error)
		if step_index >= total_steps - tick_rate:
			final_window_peak_error = maxf(final_window_peak_error, absolute_error)

	assert_true(all_values_finite, "欠阻尼步进值应始终保持有限。")
	assert_true(all_velocities_finite, "欠阻尼步进速度应始终保持有限。")
	assert_lte(peak_absolute_value, 2.75, "30 Hz 欠阻尼响应的值峰值应保持有界。")
	assert_lte(peak_absolute_velocity, 100.0, "30 Hz 欠阻尼响应的速度峰值应保持有界。")
	assert_true(
		final_window_peak_error < first_window_peak_error * 0.01,
		"正阻尼响应的末窗误差应明显小于首窗，而不是停留在边界二周期。"
	)
	assert_almost_eq(value, 1.0, 0.001, "欠阻尼响应运行三秒后应回到目标附近。")
	assert_almost_eq(velocity, 0.0, 0.01, "欠阻尼响应运行三秒后速度应衰减。")


func test_step_float_keeps_state_when_delta_is_zero() -> void:
	var state: Dictionary = GFSpringMath.step_float(
		2.0,
		-3.0,
		10.0,
		0.0,
		5.0,
		1.0
	)

	assert_eq(GFVariantData.get_option_float(state, "value"), 2.0)
	assert_eq(GFVariantData.get_option_float(state, "velocity"), -3.0)


func test_step_angle_uses_shortest_direction() -> void:
	var current_radians: float = deg_to_rad(350.0)
	var target_radians: float = deg_to_rad(10.0)

	var state: Dictionary = GFSpringMath.step_angle(
		current_radians,
		0.0,
		target_radians,
		1.0 / 60.0,
		4.0,
		1.0
	)
	var value: float = GFVariantData.get_option_float(state, "value")

	assert_true(value > current_radians, "350 度到 10 度应沿正向 20 度短弧推进。")
	assert_true(value < current_radians + deg_to_rad(20.0), "单步不应直接跳到短弧终点之后。")


func test_step_vector2_applies_component_spring() -> void:
	var state: Dictionary = GFSpringMath.step_vector2(
		Vector2.ZERO,
		Vector2.ZERO,
		Vector2(2.0, -4.0),
		1.0 / 60.0,
		4.0,
		1.0
	)
	var value: Vector2 = GFVariantData.get_option_vector2(state, "value")
	var velocity: Vector2 = GFVariantData.get_option_vector2(state, "velocity")

	assert_true(value.x > 0.0)
	assert_true(value.y < 0.0)
	assert_true(velocity.length() > 0.0)


func test_step_vector3_sanitizes_frequency_and_damping() -> void:
	var state: Dictionary = GFSpringMath.step_vector3(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ONE,
		1.0 / 60.0,
		-5.0,
		-1.0
	)
	var value: Vector3 = GFVariantData.get_option_vector3(state, "value")
	var velocity: Vector3 = GFVariantData.get_option_vector3(state, "velocity")

	assert_false(is_nan(value.x))
	assert_false(is_nan(value.y))
	assert_false(is_nan(value.z))
	assert_false(is_nan(velocity.x))
	assert_false(is_nan(velocity.y))
	assert_false(is_nan(velocity.z))
