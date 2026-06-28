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


func test_decimal_string_formatting_clamps_excessive_decimal_places() -> void:
	var text: String = GFDecimalStringFormatterBase.format_decimal_value(1.25, 1_000_000, false, false)

	assert_push_error("[GFDecimalStringFormatter] decimal_places 不能超过 18，已钳制。")
	assert_eq(text, "1.250000000000000000", "超大小数位数应被钳制到显示层上限。")
	assert_lte(text.length(), 24, "钳制后不应生成巨大字符串。")


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
