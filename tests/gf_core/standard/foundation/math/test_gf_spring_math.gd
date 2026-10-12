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


func test_step_float_rejects_each_non_finite_input_with_one_diagnostic() -> void:
	var expected_count: int = 0
	for field_index: int in range(8):
		for invalid: float in [NAN, INF, -INF]:
			var arguments: Array[float] = [0.0, 0.0, 1.0, 0.016, 3.0, 1.0, 0.75, 0.2]
			arguments[field_index] = invalid
			var result: Dictionary = GFSpringMath.step_float(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments[7])
			expected_count += 1
			_assert_rejected(result, "step_float", expected_count)


func test_step_angle_rejects_each_non_finite_input_before_angle_conversion() -> void:
	var expected_count: int = 0
	for field_index: int in range(8):
		for invalid: float in [NAN, INF, -INF]:
			var arguments: Array[float] = [0.0, 0.0, 1.0, 0.016, 3.0, 1.0, 0.75, 0.2]
			arguments[field_index] = invalid
			var result: Dictionary = GFSpringMath.step_angle(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments[7])
			expected_count += 1
			_assert_rejected(result, "step_angle", expected_count)


func test_step_vector2_rejects_each_non_finite_component_and_parameter_once() -> void:
	var expected_count: int = 0
	for vector_index: int in range(4):
		for axis: int in range(2):
			for invalid: float in [NAN, INF, -INF]:
				var vectors: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ONE, Vector2.ONE * 0.2]
				var changed: Vector2 = vectors[vector_index]
				changed[axis] = invalid
				vectors[vector_index] = changed
				var result: Dictionary = GFSpringMath.step_vector2(vectors[0], vectors[1], vectors[2], 0.016, 3.0, 1.0, 0.75, vectors[3])
				expected_count += 1
				_assert_rejected(result, "step_vector2", expected_count)
	for field_index: int in range(4):
		for invalid: float in [NAN, INF, -INF]:
			var parameters: Array[float] = [0.016, 3.0, 1.0, 0.75]
			parameters[field_index] = invalid
			var result: Dictionary = GFSpringMath.step_vector2(Vector2.ZERO, Vector2.ZERO, Vector2.ONE, parameters[0], parameters[1], parameters[2], parameters[3], Vector2.ONE * 0.2)
			expected_count += 1
			_assert_rejected(result, "step_vector2", expected_count)


func test_step_vector3_rejects_each_non_finite_component_and_parameter_once() -> void:
	var expected_count: int = 0
	for vector_index: int in range(4):
		for axis: int in range(3):
			for invalid: float in [NAN, INF, -INF]:
				var vectors: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ONE, Vector3.ONE * 0.2]
				var changed: Vector3 = vectors[vector_index]
				changed[axis] = invalid
				vectors[vector_index] = changed
				var result: Dictionary = GFSpringMath.step_vector3(vectors[0], vectors[1], vectors[2], 0.016, 3.0, 1.0, 0.75, vectors[3])
				expected_count += 1
				_assert_rejected(result, "step_vector3", expected_count)
	for field_index: int in range(4):
		for invalid: float in [NAN, INF, -INF]:
			var parameters: Array[float] = [0.016, 3.0, 1.0, 0.75]
			parameters[field_index] = invalid
			var result: Dictionary = GFSpringMath.step_vector3(Vector3.ZERO, Vector3.ZERO, Vector3.ONE, parameters[0], parameters[1], parameters[2], parameters[3], Vector3.ONE * 0.2)
			expected_count += 1
			_assert_rejected(result, "step_vector3", expected_count)


func test_non_finite_input_is_rejected_before_finite_nonpositive_delta_noop() -> void:
	var expected_count: int = 0
	for delta: float in [0.0, -0.1]:
		_assert_rejected(GFSpringMath.step_float(NAN, 0.0, 1.0, delta), "step_float", expected_count + 1)
		expected_count += 1
		_assert_rejected(GFSpringMath.step_angle(0.0, 0.0, INF, delta), "step_angle", expected_count + 1)
		expected_count += 1
		_assert_rejected(GFSpringMath.step_vector2(Vector2.ZERO, Vector2(INF, 0.0), Vector2.ONE, delta), "step_vector2", expected_count + 1)
		expected_count += 1
		_assert_rejected(GFSpringMath.step_vector3(Vector3.ZERO, Vector3.ZERO, Vector3.ONE, delta, 3.0, 1.0, NAN), "step_vector3", expected_count + 1)
		expected_count += 1


func test_finite_nonpositive_delta_preserves_all_original_typed_states() -> void:
	for delta: float in [0.0, -0.1]:
		var scalar: Dictionary = GFSpringMath.step_float(2.0, -3.0, 10.0, delta, -5.0, -1.0)
		assert_eq(scalar.size(), 2)
		var scalar_value_preserved: bool = _float_equals(scalar.get("value"), 2.0)
		var scalar_velocity_preserved: bool = _float_equals(scalar.get("velocity"), -3.0)
		assert_true(scalar_value_preserved)
		assert_true(scalar_velocity_preserved)
		var angle: Dictionary = GFSpringMath.step_angle(3.2, -0.5, -3.2, delta)
		assert_eq(angle.size(), 2)
		var angle_value_preserved: bool = _float_equals(angle.get("value"), 3.2)
		var angle_velocity_preserved: bool = _float_equals(angle.get("velocity"), -0.5)
		assert_true(angle_value_preserved)
		assert_true(angle_velocity_preserved)
		var vector2: Dictionary = GFSpringMath.step_vector2(Vector2(2.0, -1.0), Vector2(-3.0, 4.0), Vector2.ONE, delta)
		assert_eq(vector2.size(), 2)
		var vector2_value_preserved: bool = _vector2_equals(vector2.get("value"), Vector2(2.0, -1.0))
		var vector2_velocity_preserved: bool = _vector2_equals(vector2.get("velocity"), Vector2(-3.0, 4.0))
		assert_true(vector2_value_preserved)
		assert_true(vector2_velocity_preserved)
		var vector3: Dictionary = GFSpringMath.step_vector3(Vector3(2.0, -1.0, 7.0), Vector3(-3.0, 4.0, -8.0), Vector3.ONE, delta)
		assert_eq(vector3.size(), 2)
		var vector3_value_preserved: bool = _vector3_equals(vector3.get("value"), Vector3(2.0, -1.0, 7.0))
		var vector3_velocity_preserved: bool = _vector3_equals(vector3.get("velocity"), Vector3(-3.0, 4.0, -8.0))
		assert_true(vector3_value_preserved)
		assert_true(vector3_velocity_preserved)
	assert_push_error_count(0)


func test_finite_scalar_arithmetic_overflow_returns_no_partial_state() -> void:
	var result: Dictionary = GFSpringMath.step_float(1.0e308, 0.0, -1.0e308, 0.016)
	_assert_rejected(result, "step_float", 1, "non_finite_result")


func test_final_vector_conversion_or_arithmetic_overflow_returns_no_partial_state() -> void:
	var precision_probe: Vector2 = Vector2(1.234567890123456, 0.0)
	var magnitude: float = 1.0e38
	if precision_probe.x == 1.234567890123456:
		magnitude = 1.0e308
	var result2: Dictionary = GFSpringMath.step_vector2(Vector2.ZERO, Vector2.ZERO, Vector2(magnitude, magnitude), 0.01, 100.0, 0.0)
	_assert_rejected(result2, "step_vector2", 1, "non_finite_result")
	var result3: Dictionary = GFSpringMath.step_vector3(Vector3.ZERO, Vector3.ZERO, Vector3(magnitude, magnitude, magnitude), 0.01, 100.0, 0.0)
	_assert_rejected(result3, "step_vector3", 2, "non_finite_result")


func test_valid_results_remain_closed_and_retarget_keeps_the_current_velocity() -> void:
	var first: Dictionary = GFSpringMath.step_float(0.0, 0.0, 1.0, 0.016, 3.0, 1.0)
	assert_eq(first.size(), 2)
	assert_true(first.get("value") is float)
	assert_true(first.get("velocity") is float)
	var value: float = GFVariantData.get_option_float(first, "value")
	var velocity: float = GFVariantData.get_option_float(first, "velocity")
	var continuing: Dictionary = GFSpringMath.step_float(value, velocity, -1.0, 0.016, 3.0, 1.0)
	var reset_velocity: Dictionary = GFSpringMath.step_float(value, 0.0, -1.0, 0.016, 3.0, 1.0)
	assert_eq(continuing.size(), 2)
	var continuing_velocity_value: Variant = continuing.get("velocity")
	var reset_velocity_value: Variant = reset_velocity.get("velocity")
	var retains_velocity: bool = false
	if continuing_velocity_value is float and reset_velocity_value is float:
		var continuing_velocity: float = continuing_velocity_value
		var reset_velocity_float: float = reset_velocity_value
		retains_velocity = continuing_velocity != reset_velocity_float
	assert_true(retains_velocity)
	assert_true(is_finite(GFVariantData.get_option_float(continuing, "value")))
	assert_true(is_finite(GFVariantData.get_option_float(continuing, "velocity")))
	var clamped: Dictionary = GFSpringMath.step_float(0.0, 0.0, 1.0, 0.016, -5.0, -1.0)
	var normalized: Dictionary = GFSpringMath.step_float(0.0, 0.0, 1.0, 0.016, 0.001, 0.0)
	assert_eq(clamped, normalized)
	assert_push_error_count(0)


func test_angle_retarget_across_pi_keeps_short_direction_and_finite_velocity() -> void:
	var value: float = deg_to_rad(179.0)
	var velocity: float = 0.0
	for _index: int in range(12):
		var state: Dictionary = GFSpringMath.step_angle(value, velocity, deg_to_rad(-179.0), 0.016, 3.0, 1.0)
		assert_eq(state.size(), 2)
		value = GFVariantData.get_option_float(state, "value")
		velocity = GFVariantData.get_option_float(state, "velocity")
		assert_true(is_finite(value))
		assert_true(is_finite(velocity))
	assert_gt(value, deg_to_rad(179.0))
	assert_lt(value, deg_to_rad(181.0))
	assert_push_error_count(0)


# --- 辅助断言 ---

func _float_equals(value: Variant, expected: float) -> bool:
	if value is float:
		var scalar: float = value
		return scalar == expected
	return false


func _vector2_equals(value: Variant, expected: Vector2) -> bool:
	if value is Vector2:
		var vector: Vector2 = value
		return vector == expected
	return false


func _vector3_equals(value: Variant, expected: Vector3) -> bool:
	if value is Vector3:
		var vector: Vector3 = value
		return vector == expected
	return false


func _assert_rejected(result: Dictionary, method_name: String, expected_count: int, reason: String = "non_finite_input") -> void:
	assert_true(result.is_empty(), "%s must reject the whole state." % method_name)
	var detail: String = "inputs must be finite" if reason == "non_finite_input" else "the result is not finite"
	assert_push_error("[GFSpringMath][spring_math.%s] Cannot evaluate %s: %s." % [reason, method_name, detail])
	assert_push_error_count(expected_count, "Each public call must emit exactly one push_error.")
