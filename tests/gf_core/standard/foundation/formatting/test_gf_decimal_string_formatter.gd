## 测试 GFDecimalStringFormatter 的小数字符串格式化与校验。
extends GutTest


# --- 常量 ---

const GFDecimalStringFormatterBase = preload("res://addons/gf/standard/foundation/formatting/gf_decimal_string_formatter.gd")


# --- 测试方法 ---

## 验证小数格式化支持四舍五入、截断和尾零裁剪。
func test_decimal_string_formatting_rounds_truncates_and_trims() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(12.345, 2, false, false),
		"12.35",
		"默认应按小数位四舍五入。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(-12.345, 2, false, true),
		"-12.34",
		"截断负数时应向零靠近。"
	)
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(-0.004, 2, true, false),
		"0",
		"裁剪尾零后应规整 -0。"
	)


func test_decimal_string_formatting_rejects_non_finite_values() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.format_decimal_value(INF, 2, true, false),
		"0",
		"非有限浮点值应格式化为稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")

	assert_eq(
		GFDecimalStringFormatterBase.apply_decimal_places(NAN, 2, false),
		0.0,
		"直接调整非有限浮点值时也应返回稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")


func test_decimal_string_formatting_rejects_scaled_overflow() -> void:
	assert_eq(
		GFDecimalStringFormatterBase.apply_decimal_places(1.0e300, 18, false),
		0.0,
		"有限输入在小数缩放后溢出时应返回稳定 fallback。"
	)
	assert_push_error("[GFDecimalStringFormatter] 小数缩放后超过有限浮点范围。")


func test_decimal_string_formatting_clamps_excessive_decimal_places() -> void:
	var text: String = GFDecimalStringFormatterBase.format_decimal_value(1.25, 1_000_000, false, false)

	assert_push_error("[GFDecimalStringFormatter] decimal_places 不能超过 18，已钳制。")
	assert_eq(text, "1.250000000000000000", "超大小数位数应被钳制到显示层上限。")
	assert_lte(text.length(), 24, "钳制后不应生成巨大字符串。")


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
	assert_eq(GFDecimalStringFormatterBase.trim_trailing_zeroes("-0.00"), "0", "负零应规范化为零。")


func test_normalize_numeric_text_enforces_separator_grammar_and_budget() -> void:
	var grouped: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text(" +001,234.500e-2 ")
	var underscored: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1_234.5_00")
	var malformed_group: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1,2")
	var malformed_underscore: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("1__2")
	var over_budget: Dictionary = GFDecimalStringFormatterBase.normalize_numeric_text("12345", 4)

	assert_true(GFVariantData.get_option_bool(grouped, "ok"), "合法千分位文本应通过。")
	assert_eq(GFVariantData.get_option_string(grouped, "text"), "+001234.500e-2")
	assert_true(GFVariantData.get_option_bool(underscored, "ok"), "合法数字下划线应通过。")
	assert_eq(GFVariantData.get_option_string(underscored, "text"), "1234.500")
	assert_eq(GFVariantData.get_option_string(malformed_group, "error"), "invalid_separator")
	assert_eq(GFVariantData.get_option_string(malformed_underscore, "error"), "invalid_separator")
	assert_eq(GFVariantData.get_option_string(over_budget, "error"), "input_too_long")


## 验证小数字符串拆分校验只接受纯数字部分。
func test_decimal_string_parts_validation() -> void:
	assert_true(
		GFDecimalStringFormatterBase.is_valid_decimal_parts("12", "34", true),
		"合法小数拆分应通过。"
	)
	assert_true(
		GFDecimalStringFormatterBase.is_valid_decimal_parts("", "5", true),
		"省略整数部分的小数应通过。"
	)
	assert_false(
		GFDecimalStringFormatterBase.is_valid_decimal_parts("", "", false),
		"空数字不应通过。"
	)
	assert_false(
		GFDecimalStringFormatterBase.is_valid_decimal_parts("12x", "34", true),
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
