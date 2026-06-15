## 测试 GFFixedDecimal 的构造、对齐、舍入和除法行为。
extends GutTest

func test_from_string_and_to_string_roundtrip() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("12.345", 3)

	assert_eq(value.to_decimal_string(), "12.345", "字符串构建后的定点数应保持原值。")
	assert_eq(value.decimal_places, 3, "小数位数应与构建参数一致。")


func test_from_string_accepts_scientific_notation_as_float_compatibility_path() -> void:
	var positive: GFFixedDecimal = GFFixedDecimal.from_string("1.25e3", 2)
	var negative: GFFixedDecimal = GFFixedDecimal.from_string("-4.5E-2", 4)

	assert_eq(positive.to_decimal_string(), "1250.00", "科学计数法兼容路径应先转为 float 再按目标精度缩放。")
	assert_eq(negative.to_decimal_string(), "-0.0450", "科学计数法兼容路径应保留符号和目标小数位。")


func test_from_string_scientific_notation_rejects_malformed_text() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1e--2", 2)

	assert_push_error("[GFFixedDecimal] 无法解析数字字符串：1e--2")
	assert_eq(value.to_decimal_string(), "0.00", "非法科学计数法文本应收敛为当前精度下的零。")


func test_from_string_scientific_notation_uses_from_float_overflow_boundary() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1e19", 0)

	assert_push_error("[GFFixedDecimal] from_float 缩放后超出可表示范围。")
	assert_eq(value.raw_value, 0, "科学计数法不是严格十进制解析，超出 float 缩放边界时沿用 from_float 归零语义。")


func test_add_aligns_decimal_places() -> void:
	var left: GFFixedDecimal = GFFixedDecimal.from_string("1.2", 1)
	var right: GFFixedDecimal = GFFixedDecimal.from_string("0.35", 2)
	var result: GFFixedDecimal = left.add(right)

	assert_eq(result.decimal_places, 2, "加法应自动对齐到更高的小数位。")
	assert_eq(result.to_decimal_string(), "1.55", "1.2 + 0.35 应得到 1.55。")


func test_rescaled_uses_rounding_mode() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1.235", 3)
	var rounded: GFFixedDecimal = value.rescaled(2, GFFixedDecimal.RoundingMode.HALF_UP)
	var truncated: GFFixedDecimal = value.rescaled(2, GFFixedDecimal.RoundingMode.TRUNCATE)

	assert_eq(rounded.to_decimal_string(), "1.24", "HALF_UP 应将 1.235 收敛到 1.24。")
	assert_eq(truncated.to_decimal_string(), "1.23", "TRUNCATE 应直接截断额外小数位。")


func test_multiply_and_divide_keep_expected_scale() -> void:
	var price: GFFixedDecimal = GFFixedDecimal.from_string("12.34", 2)
	var factor: GFFixedDecimal = GFFixedDecimal.from_string("0.5", 1)
	var multiplied: GFFixedDecimal = price.multiply(factor, 2)
	var divided: GFFixedDecimal = GFFixedDecimal.from_string("1", 0).divide(
		GFFixedDecimal.from_string("3", 0),
		4,
		GFFixedDecimal.RoundingMode.TRUNCATE
	)

	assert_eq(multiplied.to_decimal_string(), "6.17", "12.34 * 0.5 应得到 6.17。")
	assert_eq(divided.to_decimal_string(), "0.3333", "1 / 3 在 4 位小数截断下应得到 0.3333。")


func test_to_string_can_trim_trailing_zeroes() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1234.500", 3)

	assert_eq(value.to_decimal_string(true), "1234.5", "trim_zeroes 应裁掉多余的尾部 0。")


func test_to_dict_uses_json_safe_raw_value() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.new(9_223_372_036_854_775_000, 18)

	var data: Dictionary = value.to_dict()

	assert_eq(GFVariantData.get_option_string(data, "type"), "gf.fixed_decimal", "状态字典应带稳定类型标记。")
	assert_eq(GFVariantData.get_option_int(data, "version"), 1, "状态字典应带格式版本。")
	assert_eq(GFVariantData.get_option_string(data, "raw_value"), "9223372036854775000", "raw_value 应保存为字符串，避免 JSON 精度丢失。")
	assert_eq(GFVariantData.get_option_int(data, "decimal_places"), 18, "状态字典应保存小数位。")


func test_dict_roundtrips_through_json() -> void:
	var source: GFFixedDecimal = GFFixedDecimal.new(-9_223_372_036_854_775_000, 18)
	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(source.to_dict())))
	var restored: GFFixedDecimal = GFFixedDecimal.from_dict(parsed)

	assert_eq(restored.raw_value, source.raw_value, "JSON 往返后应精确恢复 raw_value。")
	assert_eq(restored.decimal_places, source.decimal_places, "JSON 往返后应恢复小数位。")
	assert_eq(restored.to_decimal_string(), source.to_decimal_string(), "JSON 往返后十进制文本应保持一致。")


func test_apply_dict_rejects_unknown_format() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("12.34", 2)

	var applied: bool = value.apply_dict({
		"type": "other",
		"version": 1,
		"raw_value": "1234",
		"decimal_places": 2,
	})

	assert_false(applied)
	assert_push_error("[GFFixedDecimal] 不支持的状态字典格式。")
	assert_eq(value.raw_value, 0, "非法状态字典应重置为稳定零值。")
	assert_eq(value.decimal_places, 2, "非法状态字典应重置默认小数位。")


func test_apply_dict_rejects_malformed_raw_and_unsupported_range() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("12.34", 2)
	var malformed_applied: bool = value.apply_dict({
		"type": "gf.fixed_decimal",
		"version": 1,
		"raw_value": "1.25",
		"decimal_places": 2,
	})
	var min_int_applied: bool = value.apply_dict({
		"type": "gf.fixed_decimal",
		"version": 1,
		"raw_value": "-9223372036854775808",
		"decimal_places": 2,
	})
	var places_applied: bool = value.apply_dict({
		"type": "gf.fixed_decimal",
		"version": 1,
		"raw_value": "1234",
		"decimal_places": 19,
	})

	assert_false(malformed_applied)
	assert_push_error("[GFFixedDecimal] 不支持的状态字典格式。")
	assert_false(min_int_applied)
	assert_push_error("[GFFixedDecimal] 不支持的状态字典格式。")
	assert_false(places_applied)
	assert_push_error("[GFFixedDecimal] 不支持的状态字典格式。")
	assert_eq(value.raw_value, 0)
	assert_eq(value.decimal_places, 2)


func test_to_bytes_matches_golden_big_endian_format() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.new(-12_345, 3)

	var bytes: PackedByteArray = value.to_bytes()

	assert_eq(bytes, PackedByteArray([71, 70, 70, 68, 1, 3, 1, 0, 0, 0, 0, 0, 0, 48, 57]), "字节序列应使用固定 magic、版本、符号和大端绝对值。")


func test_bytes_roundtrip_preserves_max_raw_value() -> void:
	var source: GFFixedDecimal = GFFixedDecimal.new(9_223_372_036_854_775_807, 0)

	var restored: GFFixedDecimal = GFFixedDecimal.from_bytes(source.to_bytes())

	assert_eq(restored.raw_value, source.raw_value, "字节往返应保留 int64 正边界 raw_value。")
	assert_eq(restored.decimal_places, 0, "字节往返应保留小数位。")


func test_apply_bytes_rejects_unknown_format() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("12.34", 2)
	var invalid: PackedByteArray = PackedByteArray([71, 70, 70, 68, 2, 3, 0, 0, 0, 0, 0, 0, 0, 48, 57])

	var applied: bool = value.apply_bytes(invalid)

	assert_false(applied)
	assert_push_error("[GFFixedDecimal] 不支持的字节序列格式。")
	assert_eq(value.raw_value, 0, "非法字节序列应重置为稳定零值。")
	assert_eq(value.decimal_places, 2, "非法字节序列应重置默认小数位。")


func test_apply_bytes_rejects_bad_sign_and_magnitude_overflow() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("12.34", 2)
	var bad_sign_applied: bool = value.apply_bytes(PackedByteArray([
		71, 70, 70, 68,
		1,
		2,
		2,
		0, 0, 0, 0, 0, 0, 0, 1,
	]))
	var overflow_applied: bool = value.apply_bytes(PackedByteArray([
		71, 70, 70, 68,
		1,
		2,
		0,
		128, 0, 0, 0, 0, 0, 0, 0,
	]))

	assert_false(bad_sign_applied)
	assert_push_error("[GFFixedDecimal] 不支持的字节序列格式。")
	assert_false(overflow_applied)
	assert_push_error("[GFFixedDecimal] 不支持的字节序列格式。")
	assert_eq(value.raw_value, 0)
	assert_eq(value.decimal_places, 2)


func test_from_float_rejects_non_finite_values() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_float(INF, 2)

	assert_push_error("[GFFixedDecimal] from_float 收到非法浮点值。")
	assert_eq(value.to_decimal_string(), "0.00", "非法浮点值应被收敛为当前精度下的零。")


func test_decimal_places_are_clamped_to_safe_limit() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_int(1, 30)

	assert_push_error("[GFFixedDecimal] decimal_places 超出上限 18，已自动钳制。")
	assert_eq(value.decimal_places, GFFixedDecimal.MAX_DECIMAL_PLACES, "过大的小数位应被钳制到安全上限。")


func test_from_string_rejects_malformed_decimal_text() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1.2.3", 2)

	assert_push_error("[GFFixedDecimal] 无法解析数字字符串：1.2.3")
	assert_eq(value.to_decimal_string(), "0.00", "非法字符串应被收敛为当前精度下的零。")


func test_from_string_rounds_discarded_fraction_without_clamping_scale_first() -> void:
	var rounded_down: GFFixedDecimal = GFFixedDecimal.from_string(
		"0.0000000000000000004",
		18,
		GFFixedDecimal.RoundingMode.HALF_UP
	)
	var rounded_up: GFFixedDecimal = GFFixedDecimal.from_string(
		"0.0000000000000000005",
		18,
		GFFixedDecimal.RoundingMode.HALF_UP
	)
	var half_even_down: GFFixedDecimal = GFFixedDecimal.from_string(
		"0.0000000000000000025",
		18,
		GFFixedDecimal.RoundingMode.HALF_EVEN
	)
	var half_even_up: GFFixedDecimal = GFFixedDecimal.from_string(
		"0.0000000000000000035",
		18,
		GFFixedDecimal.RoundingMode.HALF_EVEN
	)

	assert_eq(rounded_down.raw_value, 0, "超出精度的小数应先按目标精度舍入，而不是先钳制小数位。")
	assert_eq(rounded_up.raw_value, 1, "HALF_UP 应正确处理第 19 位小数。")
	assert_eq(half_even_down.raw_value, 2, "HALF_EVEN 遇到偶数尾数时不应进位。")
	assert_eq(half_even_up.raw_value, 4, "HALF_EVEN 遇到奇数尾数时应进位到偶数。")


func test_from_string_saturates_int64_boundary_overflow() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("9223372036854775808", 0)

	assert_push_error("[GFFixedDecimal] 数字超出可表示范围。")
	assert_eq(value.raw_value, 9_223_372_036_854_775_807, "超过 int64 正边界的字符串应被钳制。")


func test_add_overflow_saturates_without_wraparound() -> void:
	var left: GFFixedDecimal = GFFixedDecimal.new(9_223_372_036_854_775_000, 0)
	var right: GFFixedDecimal = GFFixedDecimal.new(1_000, 0)
	var result: GFFixedDecimal = left.add(right)

	assert_push_error("[GFFixedDecimal] add 结果超出可表示范围，已钳制。")
	assert_eq(result.raw_value, 9_223_372_036_854_775_807, "加法溢出不应回绕为负数。")


func test_divide_large_positive_shift_saturates_instead_of_clamping_shift() -> void:
	var result: GFFixedDecimal = GFFixedDecimal.from_string("1", 0).divide(
		GFFixedDecimal.from_string("0.000000000000000001", 18),
		18
	)

	assert_push_error("[GFFixedDecimal] divide 结果超出可表示范围，已钳制。")
	assert_eq(result.raw_value, 9_223_372_036_854_775_807, "大位移除法溢出时应钳制，而不是把缩放位数截断成错误结果。")


func test_divide_large_positive_shift_uses_exact_integer_path() -> void:
	var result: GFFixedDecimal = GFFixedDecimal.from_string("1", 0).divide(
		GFFixedDecimal.from_string("1", 18),
		18
	)

	assert_eq(result.raw_value, 1_000_000_000_000_000_000, "大位移除法在可表示范围内应保持精确 raw 值。")
	assert_eq(result.to_decimal_string(), "1.000000000000000000", "大位移除法结果应保留目标精度。")
