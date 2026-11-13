## 测试 GFDecimalStringFormatter 的小数字符串格式化与校验。
extends GutTest


# --- 常量 ---

const GFDecimalStringFormatterBase = preload("res://addons/gf/standard/foundation/formatting/gf_decimal_string_formatter.gd")


# --- 测试方法 ---

func test_exact_components_normalize_separators_and_exponents_without_float() -> void:
	var components: Dictionary = GFDecimalStringFormatter.parse_components("+9,007,199,254,740,993.12500e-2")
	assert_true(GFVariantData.get_option_bool(components, "ok"))
	assert_eq(
		GFVariantData.get_option_string(components, "sign"),
		"+"
	)
	assert_eq(
		GFVariantData.get_option_string(components, "digits"),
		"9007199254740993125"
	)
	assert_eq(
		GFVariantData.get_option_int(components, "exponent"),
		-5
	)
	var zero: Dictionary = GFDecimalStringFormatter.parse_components("-000.000e+001")
	assert_eq(
		GFVariantData.get_option_string(zero, "digits"),
		"0"
	)
	assert_eq(
		GFVariantData.get_option_string(zero, "sign"),
		""
	)
	assert_eq(
		GFVariantData.get_option_int(zero, "exponent"),
		0
	)


func test_exact_quantization_uses_decimal_digits_for_ties_and_long_carry() -> void:
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create(
		{
			"notation": "full",
			"decimal_places": 2,
			"rounding": "half_even",
			"trim_zeroes": false,
		}
	)
	var record: Dictionary = GFDecimalStringFormatter.format_components(
		GFDecimalStringFormatter.parse_components("9007199254740993.125"),
		0,
		policy
	)
	assert_eq(
		GFVariantData.get_option_string(record, "text"),
		"9007199254740993.12"
	)
	var digits: String = "9".repeat(1024)
	record = GFDecimalStringFormatter.format_components(
		GFDecimalStringFormatter.parse_components(digits + ".995"),
		0,
		policy
	)
	assert_eq(
		GFVariantData.get_option_string(record, "text"),
		"1" + "0".repeat(1024) + ".00"
	)


func test_component_budgets_fail_before_allocating_large_expanded_strings() -> void:
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create({ "notation": "full" })
	var record: Dictionary = GFDecimalStringFormatter.format_components(
		GFDecimalStringFormatter.parse_components("1e999999"),
		0,
		policy
	)
	assert_false(GFVariantData.get_option_bool(record, "ok"))
	assert_eq(
		GFVariantData.get_option_string(record, "error"),
		"output_budget"
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFDecimalStringFormatter.parse_components("1e99999999999999999999"),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFDecimalStringFormatter.format_components(
				{},
				0,
				policy
			),
			"ok"
		)
	)


## 验证小数格式化支持四舍五入、截断和尾零裁剪。
func test_decimal_string_formatting_rounds_truncates_and_trims() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(
			12.345,
			2,
			false,
			false
		),
		"12.35",
		"默认应按小数位四舍五入。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(
			-12.345,
			2,
			false,
			true
		),
		"-12.34",
		"截断负数时应向零靠近。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(
			-0.004,
			2,
			true,
			false
		),
		"0",
		"裁剪尾零后应规整 -0。"
	)


func test_decimal_string_formatting_rejects_non_finite_values() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(
			INF,
			2,
			true,
			false
		),
		"0",
		"非有限浮点值应格式化为稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter][decimal_string_formatter.value_non_finite] Only finite floating-point values can be formatted.")

	assert_eq(
		GFDecimalStringFormatterBase.apply_decimal_places(
			NAN,
			2,
			false
		),
		0.0,
		"直接调整非有限浮点值时也应返回稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter][decimal_string_formatter.value_non_finite] Only finite floating-point values can be formatted.")


func test_decimal_string_formatting_rejects_scaled_overflow() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.apply_decimal_places(
			1.0e300,
			18,
			false
		),
		0.0,
		"有限输入在小数缩放后溢出时应返回稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter][decimal_string_formatter.scaled_value_non_finite] The scaled decimal exceeds the finite floating-point range.")


func test_decimal_string_formatting_clamps_excessive_decimal_places() -> void:
	var text: String = GFDecimalStringFormatterBase.format_decimal_value(
		1.25,
		1_000_000,
		false,
		false
	)

	assert_push_error("[GFDecimalStringFormatter][decimal_string_formatter.decimal_places_clamped] decimal_places exceeds 18 and was clamped.")
	assert_eq(
		text,
		"1.250000000000000000",
		"超大小数位数应被钳制到显示层上限。"
	)
	assert_lte(
		text.length(),
		24,
		"钳制后不应生成巨大字符串。"
	)


func test_trim_trailing_zeroes_only_changes_fractional_digits() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.trim_trailing_zeroes("1000"),
		"1000",
		"整数尾零属于数值本身，不得被裁掉。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.trim_trailing_zeroes("1000.00"),
		"1000",
		"只有小数部分的尾零可以被裁掉。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.trim_trailing_zeroes("-1200.00"),
		"-1200",
		"负数整数部分的尾零也必须保留。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.trim_trailing_zeroes("-0.00"),
		"0",
		"负零应规范化为零。"
	)


func test_normalize_numeric_text_enforces_separator_grammar_and_budget() -> void:
	var grouped: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text(" +001,234.500e-2 ")
	var underscored: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1_234.5_00")
	var malformed_group: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1,2")
	var malformed_underscore: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1__2")
	var over_budget: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("12345", 4)
	var whitespace_bypass: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("    1    ", 4)
	var exact_budget: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1.20", 4)

	assert_true(
		GFVariantData.get_option_bool(grouped, "ok"),
		"合法千分位文本应通过。"
	)
	assert_eq(
		GFVariantData.get_option_string(grouped, "text"),
		"+001234.500e-2"
	)
	assert_true(
		GFVariantData.get_option_bool(underscored, "ok"),
		"合法数字下划线应通过。"
	)
	assert_eq(
		GFVariantData.get_option_string(underscored, "text"),
		"1234.500"
	)
	assert_eq(
		GFVariantData.get_option_string(malformed_group, "error"),
		"invalid_separator"
	)
	assert_eq(
		GFVariantData.get_option_string(malformed_underscore, "error"),
		"invalid_separator"
	)
	assert_eq(
		GFVariantData.get_option_string(over_budget, "error"),
		"input_too_long"
	)
	assert_eq(
		GFVariantData.get_option_string(whitespace_bypass, "error"),
		"input_too_long",
		"预算必须约束原始输入，而不是 trim 后文本。"
	)
	assert_true(
		GFVariantData.get_option_bool(exact_budget, "ok"),
		"长度恰好等于预算的合法文本应通过。"
	)


## 验证小数字符串拆分校验只接受纯数字部分。
func test_decimal_string_parts_validation() -> void:
	assert_true(
		GFDecimalStringFormatterBase.is_valid_decimal_parts(
			"12",
			"34",
			true
		),
		"合法小数拆分应通过。"
	)
	assert_true(
		GFDecimalStringFormatterBase.is_valid_decimal_parts(
			"",
			"5",
			true
		),
		"省略整数部分的小数应通过。"
	)
	assert_false(
		GFDecimalStringFormatterBase.is_valid_decimal_parts(
			"",
			"",
			false
		),
		"空数字不应通过。"
	)
	assert_false(
		GFDecimalStringFormatterBase.is_valid_decimal_parts(
			"12x",
			"34",
			true
		),
		"非数字字符不应通过。"
	)


func test_contains_only_digits_rejects_empty_text() -> void:
	assert_false(
		GFDecimalStringFormatterBase.contains_only_digits(""),
		"空字符串不应被视为纯数字。"
	)
	assert_true(
		GFDecimalStringFormatterBase.contains_only_digits("12345"),
		"纯数字字符串应通过。"
	)
	assert_false(
		GFDecimalStringFormatterBase.contains_only_digits("12a45"),
		"包含非数字字符时应失败。"
	)
