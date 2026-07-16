## 测试 GFPlacementSequenceMath 的连续位置与离散格子放置预测。
extends GutTest


# --- 常量 ---

const GF_PLACEMENT_SEQUENCE_MATH_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_placement_sequence_math.gd")


# --- 测试 ---

func test_position_2d_uses_fallback_without_history() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_2d(
		[],
		Vector2(3.0, 4.0)
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "fallback 位置有效时应成功。")
	assert_eq(GFVariantData.get_option_string_name(report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_FALLBACK)
	assert_eq(GFVariantData.get_option_vector2(report, "position"), Vector2(3.0, 4.0))
	assert_eq(GFVariantData.get_option_vector2(report, "step"), Vector2.ZERO)


func test_position_2d_repeats_last_with_single_history_entry() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_2d([
		Vector2(5.0, 8.0),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "单个历史位置可复用。")
	assert_eq(GFVariantData.get_option_string_name(report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_REPEAT_LAST)
	assert_eq(GFVariantData.get_option_vector2(report, "position"), Vector2(5.0, 8.0))
	assert_eq(GFVariantData.get_option_int(report, "valid_count"), 1)


func test_position_2d_extrapolates_from_last_two_entries() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_2d([
		Vector2(2.0, 3.0),
		Vector2(5.0, 7.0),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "两个历史位置应能外推。")
	assert_eq(GFVariantData.get_option_string_name(report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_EXTRAPOLATED)
	assert_eq(GFVariantData.get_option_vector2(report, "step"), Vector2(3.0, 4.0))
	assert_eq(GFVariantData.get_option_vector2(report, "position"), Vector2(8.0, 11.0))


func test_position_3d_can_clamp_extrapolated_step() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_3d(
		[
			Vector3.ZERO,
			Vector3(10.0, 0.0, 0.0),
		],
		Vector3.ZERO,
		{ "max_step_length": 2.5 }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "限制步长后仍应得到有效位置。")
	assert_true(GFVariantData.get_option_bool(report, "clamped"), "超过 max_step_length 时应标记 clamped。")
	assert_eq(GFVariantData.get_option_vector3(report, "step"), Vector3(2.5, 0.0, 0.0))
	assert_eq(GFVariantData.get_option_vector3(report, "position"), Vector3(12.5, 0.0, 0.0))


func test_position_reports_sanitize_invalid_values() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_2d(
		[
			Vector2(1.0, 1.0),
			Vector2(NAN, 3.0),
			Vector2(4.0, 5.0),
		],
		Vector2.ZERO,
		{ "max_step_length": NAN }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "无效历史值应被忽略而不是传播 NaN。")
	assert_eq(GFVariantData.get_option_int(report, "source_count"), 3)
	assert_eq(GFVariantData.get_option_int(report, "valid_count"), 2)
	assert_eq(GFVariantData.get_option_int(report, "ignored_invalid_count"), 1)
	assert_eq(GFVariantData.get_option_float(report, "max_step_length"), 0.0)
	assert_eq(GFVariantData.get_option_vector2(report, "position"), Vector2(7.0, 9.0))


func test_position_invalid_fallback_returns_stable_error_without_nan() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_position_2d(
		[],
		Vector2(NAN, 1.0)
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无历史且 fallback 无效时应明确失败。")
	assert_eq(GFVariantData.get_option_string_name(report, "error"), &"invalid_fallback_position")
	assert_eq(GFVariantData.get_option_vector2(report, "position"), Vector2.ZERO)


func test_cell_2d_extrapolates_discrete_step() -> void:
	var report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_cell_2d([
		Vector2i(2, 1),
		Vector2i(5, 4),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "离散格子预测应稳定成功。")
	assert_eq(GFVariantData.get_option_string_name(report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_EXTRAPOLATED)
	assert_eq(_get_vector2i(report, "step"), Vector2i(3, 3))
	assert_eq(_get_vector2i(report, "cell"), Vector2i(8, 7))


func test_cell_3d_uses_fallback_and_repeat_modes() -> void:
	var fallback_report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_cell_3d([], Vector3i(1, 2, 3))
	var repeat_report: Dictionary = GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.predict_next_cell_3d([Vector3i(4, 5, 6)])

	assert_eq(GFVariantData.get_option_string_name(fallback_report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_FALLBACK)
	assert_eq(_get_vector3i(fallback_report, "cell"), Vector3i(1, 2, 3))
	assert_eq(GFVariantData.get_option_string_name(repeat_report, "mode"), GF_PLACEMENT_SEQUENCE_MATH_SCRIPT.MODE_REPEAT_LAST)
	assert_eq(_get_vector3i(repeat_report, "cell"), Vector3i(4, 5, 6))


# --- 私有/辅助方法 ---

func _get_vector2i(report: Dictionary, key: String) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(report, key, Vector2i.ZERO)
	if value is Vector2i:
		var result: Vector2i = value
		return result
	return Vector2i.ZERO


func _get_vector3i(report: Dictionary, key: String) -> Vector3i:
	var value: Variant = GFVariantData.get_option_value(report, key, Vector3i.ZERO)
	if value is Vector3i:
		var result: Vector3i = value
		return result
	return Vector3i.ZERO
