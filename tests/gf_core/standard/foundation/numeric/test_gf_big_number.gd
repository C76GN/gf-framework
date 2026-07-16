## 测试 GFBigNumber 的解析、归一化、比较和基础算术。
extends GutTest

func test_from_string_normalizes_plain_number() -> void:
	var value: GFBigNumber = GFBigNumber.from_string("123450000")

	assert_almost_eq(value.mantissa, 1.2345, 0.000001, "普通大整数字符串应被归一化到尾数。")
	assert_eq(value.exponent, 8, "123450000 应被解析为 1.2345e8。")


func test_from_string_rejects_malformed_decimal_text() -> void:
	var value: GFBigNumber = GFBigNumber.from_string("12x.3")

	assert_push_error("[GFBigNumber] 无法解析数字字符串（invalid_separator）：12x.3")
	assert_true(value.is_zero(), "非法字符串应被收敛为零值。")


func test_from_string_rejects_malformed_separators() -> void:
	var malformed_group: GFBigNumber = GFBigNumber.from_string("1,2")
	var malformed_underscore: GFBigNumber = GFBigNumber.from_string("1__2")

	assert_push_error("[GFBigNumber] 无法解析数字字符串（invalid_separator）：1,2")
	assert_push_error("[GFBigNumber] 无法解析数字字符串（invalid_separator）：1__2")
	assert_true(malformed_group.is_zero(), "错误千分位不能被静默改写成另一个值。")
	assert_true(malformed_underscore.is_zero(), "错误下划线不能被静默移除。")


func test_from_string_enforces_input_length_budget() -> void:
	var value: GFBigNumber = GFBigNumber.from_string("12345", 4)

	assert_push_error("[GFBigNumber] 无法解析数字字符串（input_too_long）：12345")
	assert_true(value.is_zero(), "超出输入预算时应快速返回稳定零值。")


func test_from_string_rejects_exponents_outside_supported_range() -> void:
	var value: GFBigNumber = GFBigNumber.from_string("1e1000001")

	assert_push_error("[GFBigNumber] 指数超出支持范围。")
	assert_true(value.is_zero(), "超出支持范围的科学计数法指数应被拒绝。")


func test_init_rejects_non_finite_mantissa() -> void:
	var value: GFBigNumber = GFBigNumber.new(INF, 5)

	assert_push_error("[GFBigNumber] mantissa 必须是有限浮点值。")
	assert_true(value.is_zero(), "非有限尾数应被收敛为零值。")
	assert_eq(value.exponent, 0)


func test_from_string_accepts_sign_grouping_and_scientific_offset() -> void:
	var value: GFBigNumber = GFBigNumber.from_string(" +001,234.500e-2 ")

	assert_almost_eq(value.to_float(), 12.345, 0.000001, "解析时应忽略空白、逗号并正确叠加科学计数法指数。")


func test_add_combines_similar_exponents() -> void:
	var left: GFBigNumber = GFBigNumber.from_string("1.5e6")
	var right: GFBigNumber = GFBigNumber.from_string("2.25e6")
	var result: GFBigNumber = left.add(right)

	assert_almost_eq(result.mantissa, 3.75, 0.000001, "同量级加法应保留有效尾数。")
	assert_eq(result.exponent, 6, "同量级加法后指数应保持 6。")


func test_add_drops_negligible_value_when_gap_is_too_large() -> void:
	var huge: GFBigNumber = GFBigNumber.from_string("1e30")
	var tiny: GFBigNumber = GFBigNumber.from_string("1e5")
	var result: GFBigNumber = huge.add(tiny)

	assert_almost_eq(result.mantissa, 1.0, 0.000001, "指数差足够大时，较小项应被忽略。")
	assert_eq(result.exponent, 30, "指数差足够大时，应直接保留更大值。")


func test_multiply_and_divide_keep_normalized_form() -> void:
	var multiplied: GFBigNumber = GFBigNumber.from_string("2.5e3").multiply(GFBigNumber.from_string("4e2"))
	var divided: GFBigNumber = multiplied.divide(GFBigNumber.from_string("2e2"))

	assert_almost_eq(multiplied.mantissa, 1.0, 0.000001, "乘法结果应保持归一化。")
	assert_eq(multiplied.exponent, 6, "2.5e3 * 4e2 应得到 1e6。")
	assert_almost_eq(divided.mantissa, 5.0, 0.000001, "除法结果应保持正确尾数。")
	assert_eq(divided.exponent, 3, "1e6 / 2e2 应得到 5e3。")


func test_multiply_and_divide_reject_exponent_overflow() -> void:
	var multiplied: GFBigNumber = GFBigNumber.new(1.0, 600_000).multiply(GFBigNumber.new(1.0, 500_001))
	var divided: GFBigNumber = GFBigNumber.new(1.0, 600_000).divide(GFBigNumber.new(1.0, -500_001))

	assert_push_error("[GFBigNumber] 指数超出支持范围。")
	assert_push_error("[GFBigNumber] 指数超出支持范围。")
	assert_true(multiplied.is_zero(), "乘法指数超界应返回稳定零值。")
	assert_true(divided.is_zero(), "除法指数超界应返回稳定零值。")


func test_compare_handles_sign_and_magnitude() -> void:
	var positive: GFBigNumber = GFBigNumber.from_string("3e9")
	var smaller_positive: GFBigNumber = GFBigNumber.from_string("2e9")
	var negative: GFBigNumber = GFBigNumber.from_string("-1e2")

	assert_eq(positive.compare_to(smaller_positive), 1, "更大的正数应比较为 1。")
	assert_eq(smaller_positive.compare_to(positive), -1, "更小的正数应比较为 -1。")
	assert_eq(negative.compare_to(smaller_positive), -1, "负数应小于任意正数。")


func test_powi_supports_large_integer_growth() -> void:
	var value: GFBigNumber = GFBigNumber.from_float(1.15).powi(1_000)

	assert_eq(value.exponent, 60, "1.15^1000 的数量级应稳定落在 1e60。")
	assert_almost_eq(value.mantissa, 4.987011, 0.000001, "大整数幂应保持可用的尾数精度。")


func test_powf_supports_fractional_exponents() -> void:
	var value: GFBigNumber = GFBigNumber.from_int(50).powf(0.5)

	assert_almost_eq(value.to_float(), 7.0710678, 0.000001, "50 的平方根应约为 7.0710678。")


func test_pow_rejects_exponent_outside_supported_range() -> void:
	var value: GFBigNumber = GFBigNumber.new(1.0, 600_000).powi(2)

	assert_push_error("[GFBigNumber] 指数超出支持范围。")
	assert_true(value.is_zero(), "幂运算指数超界应返回稳定零值。")


func test_divide_by_zero_returns_zero_and_reports_error() -> void:
	var value: GFBigNumber = GFBigNumber.from_int(10).divide(GFBigNumber.zero())

	assert_push_error("[GFBigNumber] 尝试除以空值或零值。")
	assert_true(value.is_zero(), "大数除零应返回零值而不是产生非法尾数。")


func test_negative_value_rejects_fractional_power() -> void:
	var value: GFBigNumber = GFBigNumber.from_int(-4).powf(0.5)

	assert_push_error("[GFBigNumber] 负数不能执行非整数次幂。")
	assert_true(value.is_zero(), "负数开非整数次幂应安全返回零值。")


func test_scientific_string_carries_when_rounded_mantissa_overflows() -> void:
	var value: GFBigNumber = GFBigNumber.new(9.999, 5)

	assert_eq(value.to_scientific_string(2), "1e6", "尾数四舍五入到 10 时应向指数进位。")


func test_scientific_string_rejects_carry_past_supported_exponent() -> void:
	var value: GFBigNumber = GFBigNumber.new(9.999, 1_000_000)

	assert_eq(value.to_scientific_string(2), "0", "科学计数法进位超过支持范围时应返回稳定文本。")
	assert_push_error("[GFBigNumber] 指数超出支持范围。")
