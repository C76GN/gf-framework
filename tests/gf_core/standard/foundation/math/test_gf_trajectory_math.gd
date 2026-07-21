## 测试 GFTrajectoryMath 的运动预测、拦截解和有界公式采样。
extends GutTest


const GF_TRAJECTORY_MATH_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_trajectory_math.gd")


var _provider_call_count: int = 0


# --- 测试 ---

func test_predict_motion_2d_uses_constant_acceleration() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_2d(
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		Vector2(0.0, -2.0),
		2.0
	)

	assert_true(_get_bool(report, "ok"), "有限的未来时间应生成 2D 运动预测。")
	_assert_vector2_close(_get_vector2(report, "position"), Vector2(7.0, 6.0))
	_assert_vector2_close(_get_vector2(report, "velocity"), Vector2(3.0, 0.0))
	assert_almost_eq(_get_float(report, "time_seconds"), 2.0, 0.000001)


func test_predict_motion_3d_uses_constant_acceleration() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_3d(
		Vector3(1.0, 2.0, 3.0),
		Vector3(2.0, 0.0, -1.0),
		Vector3(0.0, 4.0, 2.0),
		0.5
	)

	assert_true(_get_bool(report, "ok"), "有限的未来时间应生成 3D 运动预测。")
	_assert_vector3_close(_get_vector3(report, "position"), Vector3(2.0, 2.5, 2.75))
	_assert_vector3_close(_get_vector3(report, "velocity"), Vector3(2.0, 2.0, 0.0))


func test_predict_motion_rejects_negative_time() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_2d(
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2.ZERO,
		-0.1
	)

	assert_false(_get_bool(report, "ok"), "未来位置入口不应接受负时间。")
	assert_eq(_get_reason(report), &"invalid_argument")


func test_predict_motion_rejects_non_finite_vectors() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_3d(
		Vector3(NAN, 0.0, 0.0),
		Vector3.ZERO,
		Vector3.ZERO,
		1.0
	)

	assert_false(_get_bool(report, "ok"), "非有限运动状态不应进入预测结果。")
	assert_eq(_get_reason(report), &"invalid_argument")


func test_predict_motion_zero_acceleration_avoids_time_square_overflow() -> void:
	var report_2d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_2d(
		Vector2(1.0, 2.0),
		Vector2.ZERO,
		Vector2.ZERO,
		1.0e308
	)
	var report_3d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.predict_motion_3d(
		Vector3(1.0, 2.0, 3.0),
		Vector3.ZERO,
		Vector3.ZERO,
		1.0e308
	)

	assert_true(_get_bool(report_2d, "ok"), "零加速度不应因先计算 t² 而产生伪溢出。")
	assert_true(_get_bool(report_3d, "ok"), "2D 与 3D 应使用相同的稳定计算顺序。")
	_assert_vector2_close(_get_vector2(report_2d, "position"), Vector2(1.0, 2.0))
	_assert_vector3_close(_get_vector3(report_3d, "position"), Vector3(1.0, 2.0, 3.0))


func test_solve_intercept_2d_finds_stationary_target() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2.ZERO
	)

	assert_true(_get_bool(report, "ok"), "静止目标应有直接拦截解。")
	assert_almost_eq(_get_float(report, "time_seconds"), 2.0, 0.000001)
	_assert_vector2_close(_get_vector2(report, "position"), Vector2(10.0, 0.0))
	_assert_vector2_close(_get_vector2(report, "launch_velocity"), Vector2(5.0, 0.0))


func test_solve_intercept_2d_leads_moving_target() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2(1.0, 0.0)
	)

	assert_true(_get_bool(report, "ok"), "速度较慢的远离目标应有超前拦截解。")
	assert_almost_eq(_get_float(report, "time_seconds"), 2.5, 0.000001)
	_assert_vector2_close(_get_vector2(report, "position"), Vector2(12.5, 0.0))
	_assert_vector2_close(_get_vector2(report, "launch_velocity"), Vector2(5.0, 0.0))


func test_solve_intercept_3d_handles_off_axis_motion() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_3d(
		Vector3.ZERO,
		5.0,
		Vector3(10.0, 0.0, 0.0),
		Vector3(0.0, 3.0, 0.0)
	)

	assert_true(_get_bool(report, "ok"), "3D 横向移动目标应有拦截解。")
	assert_almost_eq(_get_float(report, "time_seconds"), 2.5, 0.000001)
	_assert_vector3_close(_get_vector3(report, "position"), Vector3(10.0, 7.5, 0.0))
	assert_almost_eq(_get_vector3(report, "launch_velocity").length(), 5.0, 0.000001)


func test_solve_intercept_handles_equal_speed_approach() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2(-5.0, 0.0)
	)

	assert_true(_get_bool(report, "ok"), "等速相向运动应走线性退化分支并得到有效解。")
	assert_almost_eq(_get_float(report, "time_seconds"), 1.0, 0.000001)
	_assert_vector2_close(_get_vector2(report, "position"), Vector2(5.0, 0.0))


func test_solve_intercept_respects_small_positive_epsilon_at_small_scale() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		0.0001,
		Vector2(0.001, 0.0),
		Vector2.ZERO,
		-1.0,
		0.000000000001
	)

	assert_true(_get_bool(report, "ok"), "小尺度速度不应被固定绝对容差误判为零。")
	assert_almost_eq(_get_float(report, "time_seconds"), 10.0, 0.000001)


func test_solve_intercept_negative_epsilon_uses_default() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2.ZERO,
		-1.0,
		-10.0
	)

	assert_true(_get_bool(report, "ok"), "非正 epsilon 应按文档回退到默认值。")
	assert_almost_eq(_get_float(report, "time_seconds"), 2.0, 0.000001)


func test_solve_intercept_keeps_tiny_positive_time_and_discards_negative_root() -> void:
	var report_2d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		10.0,
		Vector2(0.000002, 0.0),
		Vector2.ZERO
	)
	var report_3d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_3d(
		Vector3.ZERO,
		10.0,
		Vector3(0.000002, 0.0, 0.0),
		Vector3.ZERO
	)

	assert_true(_get_bool(report_2d, "ok"), "容差内的过去根不应被提升为 t=0。")
	assert_true(_get_bool(report_3d, "ok"), "2D 与 3D 应共享相同的非负根语义。")
	assert_almost_eq(_get_float(report_2d, "time_seconds"), 0.0000002, 0.000000000001)
	assert_almost_eq(_get_float(report_3d, "time_seconds"), 0.0000002, 0.000000000001)
	assert_almost_eq(_get_vector2(report_2d, "launch_velocity").length(), 10.0, 0.000001)
	assert_almost_eq(_get_vector3(report_3d, "launch_velocity").length(), 10.0, 0.000001)


func test_solve_intercept_reports_no_solution_when_target_is_too_fast() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2(6.0, 0.0)
	)

	assert_false(_get_bool(report, "ok"), "持续远离且更快的目标不应伪造拦截解。")
	assert_eq(_get_reason(report), &"no_solution")


func test_solve_intercept_reports_beyond_horizon() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		5.0,
		Vector2(10.0, 0.0),
		Vector2.ZERO,
		1.0
	)

	assert_false(_get_bool(report, "ok"), "超出预测窗口的解不应被当作可执行解。")
	assert_eq(_get_reason(report), &"beyond_horizon")


func test_solve_intercept_accepts_immediate_overlap() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_3d(
		Vector3(2.0, 3.0, 4.0),
		8.0,
		Vector3(2.0, 3.0, 4.0),
		Vector3(20.0, 0.0, 0.0)
	)

	assert_true(_get_bool(report, "ok"), "当前位置重合应作为 t=0 的有效拦截。")
	assert_almost_eq(_get_float(report, "time_seconds"), 0.0, 0.000001)
	_assert_vector3_close(_get_vector3(report, "launch_velocity"), Vector3.ZERO)


func test_solve_intercept_rejects_invalid_speed() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		0.0,
		Vector2.RIGHT,
		Vector2.ZERO
	)

	assert_false(_get_bool(report, "ok"), "非正发射速度应被拒绝。")
	assert_eq(_get_reason(report), &"invalid_argument")


func test_solve_intercept_rejects_unusable_launch_velocity_magnitude() -> void:
	var report_2d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		1.0e30,
		Vector2(10.0, 0.0),
		Vector2.ZERO
	)
	var report_3d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_3d(
		Vector3.ZERO,
		1.0e30,
		Vector3(10.0, 0.0, 0.0),
		Vector3.ZERO
	)

	assert_false(_get_bool(report_2d, "ok"), "长度溢出的 2D 发射速度不应进入成功报告。")
	assert_false(_get_bool(report_3d, "ok"), "长度溢出的 3D 发射速度不应进入成功报告。")
	assert_eq(_get_reason(report_2d), &"invalid_argument")
	assert_eq(_get_reason(report_3d), &"invalid_argument")


func test_solve_intercept_stationary_target_handles_large_finite_time() -> void:
	var report_2d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_2d(
		Vector2.ZERO,
		1.0e-20,
		Vector2(1.0e19, 0.0),
		Vector2.ZERO
	)
	var report_3d: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.solve_intercept_3d(
		Vector3.ZERO,
		1.0e-20,
		Vector3(1.0e19, 0.0, 0.0),
		Vector3.ZERO
	)

	assert_true(_get_bool(report_2d, "ok"), "零目标速度不应因极长有限时间的 Vector 标量转换而失败。")
	assert_true(_get_bool(report_3d, "ok"), "2D 与 3D 应共享稳定的目标位移计算。")
	assert_almost_eq(_get_float(report_2d, "time_seconds") / 1.0e39, 1.0, 0.000001)
	assert_almost_eq(_get_float(report_3d, "time_seconds") / 1.0e39, 1.0, 0.000001)
	assert_almost_eq(_get_vector2(report_2d, "launch_velocity").length() / 1.0e-20, 1.0, 0.001)
	assert_almost_eq(_get_vector3(report_3d, "launch_velocity").length() / 1.0e-20, 1.0, 0.001)


func test_sample_formula_2d_includes_both_interval_endpoints() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_circle_formula_2d"),
		0.0,
		PI,
		3
	)
	var points: PackedVector2Array = _get_vector2_array(report, "points")
	var times: PackedFloat64Array = _get_float_array(report, "times")

	assert_true(_get_bool(report, "ok"), "有限公式应完整采样。")
	assert_eq(points.size(), 3)
	assert_eq(times.size(), 3)
	_assert_vector2_close(points[0], Vector2(1.0, 0.0))
	_assert_vector2_close(points[1], Vector2(0.0, 1.0))
	_assert_vector2_close(points[2], Vector2(-1.0, 0.0))
	assert_almost_eq(times[0], 0.0, 0.000001)
	assert_almost_eq(times[2], PI, 0.000001)


func test_sample_formula_3d_supports_reverse_time_ranges() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_3d(
		Callable(self, &"_polynomial_formula_3d"),
		2.0,
		0.0,
		3
	)
	var points: PackedVector3Array = _get_vector3_array(report, "points")

	assert_true(_get_bool(report, "ok"), "通用公式采样应允许反向时间区间。")
	assert_eq(points.size(), 3)
	_assert_vector3_close(points[0], Vector3(2.0, 4.0, -2.0))
	_assert_vector3_close(points[1], Vector3(1.0, 1.0, -1.0))
	_assert_vector3_close(points[2], Vector3.ZERO)


func test_sample_formula_with_one_sample_uses_start_time() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_circle_formula_2d"),
		0.5,
		8.0,
		1
	)
	var times: PackedFloat64Array = _get_float_array(report, "times")

	assert_true(_get_bool(report, "ok"))
	assert_eq(times.size(), 1)
	assert_almost_eq(times[0], 0.5, 0.000001)


func test_sample_formula_keeps_extreme_finite_time_range_finite() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_constant_formula_2d"),
		-1.0e308,
		1.0e308,
		3
	)
	var times: PackedFloat64Array = _get_float_array(report, "times")

	assert_true(_get_bool(report, "ok"), "有限端点不应因插值中间步骤溢出。")
	assert_eq(times.size(), 3)
	assert_false(is_nan(times[1]) or is_inf(times[1]))
	assert_almost_eq(times[1], 0.0, 0.000001)


func test_sample_formula_rejects_limit_before_calling_provider() -> void:
	_provider_call_count = 0
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_counted_formula_2d"),
		0.0,
		1.0,
		5,
		4
	)

	assert_false(_get_bool(report, "ok"), "超预算采样应 fail closed。")
	assert_eq(_get_reason(report), &"sample_limit_exceeded")
	assert_eq(_provider_call_count, 0, "预算校验失败时不应执行项目回调。")


func test_sample_formula_rejects_limit_above_absolute_cap() -> void:
	_provider_call_count = 0
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_counted_formula_2d"),
		0.0,
		1.0,
		1,
		GF_TRAJECTORY_MATH_SCRIPT.ABSOLUTE_MAX_SAMPLE_COUNT + 1
	)

	assert_false(_get_bool(report, "ok"), "调用方不能绕过绝对采样上限。")
	assert_eq(_get_reason(report), &"invalid_argument")
	assert_eq(_provider_call_count, 0)


func test_sample_formula_reports_provider_type_mismatch() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_wrong_type_formula"),
		0.0,
		1.0,
		3
	)

	assert_false(_get_bool(report, "ok"), "返回错误类型的公式不应生成可用轨迹。")
	assert_eq(_get_reason(report), &"provider_failed")
	assert_eq(_get_int(report, "failed_sample_index"), 0)
	assert_eq(_get_int(report, "sampled_count"), 0)


func test_sample_formula_reports_non_finite_provider_output() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_2d(
		Callable(self, &"_non_finite_formula_2d"),
		0.0,
		1.0,
		3
	)

	assert_false(_get_bool(report, "ok"), "公式输出 NaN 时应终止采样。")
	assert_eq(_get_reason(report), &"provider_failed")
	assert_eq(_get_int(report, "failed_sample_index"), 1)
	assert_eq(_get_int(report, "sampled_count"), 1)
	var times: PackedFloat64Array = _get_float_array(report, "times")
	var points: PackedVector2Array = _get_vector2_array(report, "points")
	assert_eq(times.size(), 1, "失败报告应保留已完成采样的时间前缀。")
	assert_eq(points.size(), 1, "失败报告应保留已完成采样的位置前缀。")
	assert_almost_eq(times[0], 0.0, 0.000001)
	_assert_vector2_close(points[0], Vector2.ZERO)


func test_sample_formula_rejects_invalid_callable() -> void:
	var report: Dictionary = GF_TRAJECTORY_MATH_SCRIPT.sample_formula_3d(
		Callable(),
		0.0,
		1.0,
		3
	)

	assert_false(_get_bool(report, "ok"), "无效 Callable 应在采样前被拒绝。")
	assert_eq(_get_reason(report), &"invalid_provider")


# --- 私有/辅助方法 ---

func _circle_formula_2d(time_seconds: float) -> Vector2:
	return Vector2(cos(time_seconds), sin(time_seconds))


func _polynomial_formula_3d(time_seconds: float) -> Vector3:
	return Vector3(time_seconds, time_seconds * time_seconds, -time_seconds)


func _counted_formula_2d(time_seconds: float) -> Vector2:
	_provider_call_count += 1
	return Vector2(time_seconds, 0.0)


func _constant_formula_2d(_time_seconds: float) -> Vector2:
	return Vector2.ZERO


func _wrong_type_formula(_time_seconds: float) -> String:
	return "not-a-vector"


func _non_finite_formula_2d(time_seconds: float) -> Vector2:
	if time_seconds > 0.0:
		return Vector2(NAN, 0.0)
	return Vector2.ZERO


func _get_bool(report: Dictionary, key: String) -> bool:
	var value: Variant = report.get(key, false)
	return value if value is bool else false


func _get_int(report: Dictionary, key: String) -> int:
	var value: Variant = report.get(key, 0)
	if value is int:
		var int_value: int = value
		return int_value
	return 0


func _get_float(report: Dictionary, key: String) -> float:
	var value: Variant = report.get(key, 0.0)
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return 0.0


func _get_reason(report: Dictionary) -> StringName:
	var value: Variant = report.get("reason", &"")
	if value is StringName:
		return value
	if value is String:
		var text: String = value
		return StringName(text)
	return &""


func _get_vector2(report: Dictionary, key: String) -> Vector2:
	var value: Variant = report.get(key, Vector2.ZERO)
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return Vector2.ZERO


func _get_vector3(report: Dictionary, key: String) -> Vector3:
	var value: Variant = report.get(key, Vector3.ZERO)
	if value is Vector3:
		var vector_value: Vector3 = value
		return vector_value
	return Vector3.ZERO


func _get_float_array(report: Dictionary, key: String) -> PackedFloat64Array:
	var value: Variant = report.get(key, PackedFloat64Array())
	if value is PackedFloat64Array:
		var array_value: PackedFloat64Array = value
		return array_value
	return PackedFloat64Array()


func _get_vector2_array(report: Dictionary, key: String) -> PackedVector2Array:
	var value: Variant = report.get(key, PackedVector2Array())
	if value is PackedVector2Array:
		var array_value: PackedVector2Array = value
		return array_value
	return PackedVector2Array()


func _get_vector3_array(report: Dictionary, key: String) -> PackedVector3Array:
	var value: Variant = report.get(key, PackedVector3Array())
	if value is PackedVector3Array:
		var array_value: PackedVector3Array = value
		return array_value
	return PackedVector3Array()


func _assert_vector2_close(actual: Vector2, expected: Vector2, epsilon: float = 0.000001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)


func _assert_vector3_close(actual: Vector3, expected: Vector3, epsilon: float = 0.000001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)
	assert_almost_eq(actual.z, expected.z, epsilon)
