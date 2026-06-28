## 测试 GFNumberFormatter 的完整显示、紧凑缩写与科学计数法行为。
extends GutTest

func test_format_compact_supports_k_suffix() -> void:
	var text: String = GFNumberFormatter.format_compact(1_000, 0)

	assert_eq(text, "1k", "1000 在紧凑模式下应格式化为 1k。")


func test_format_compact_can_keep_fractional_precision() -> void:
	var text: String = GFNumberFormatter.format_compact(12_345, 3)

	assert_eq(text, "12.345k", "12345 在 3 位小数紧凑模式下应得到 12.345k。")


func test_format_compact_carries_when_rounding_reaches_next_suffix() -> void:
	var text: String = GFNumberFormatter.format_compact(999_950, 1)

	assert_eq(text, "1M", "紧凑格式四舍五入到 1000k 时应进位到下一个后缀。")


func test_format_scientific_supports_multiple_styles() -> void:
	var scientific: String = GFNumberFormatter.format_scientific(1_000_000, 0)
	var power_text: String = GFNumberFormatter.format_scientific(
		1_000_000,
		0,
		true,
		false,
		GFNumberFormatter.ScientificStyle.POWER_OF_TEN
	)

	assert_eq(scientific, "1e6", "科学计数法默认应输出 e 风格。")
	assert_eq(power_text, "1 x 10^6", "POWER_OF_TEN 风格应输出 x 10^n。")


func test_format_full_understands_fixed_decimal() -> void:
	var money: GFFixedDecimal = GFFixedDecimal.from_string("1234.500", 3)
	var text: String = GFNumberFormatter.format_full(money, 3, true)

	assert_eq(text, "1234.5", "FULL 模式应能直接格式化定点小数。")


func test_format_full_respects_truncation_for_fixed_decimal() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1.239", 3)
	var text: String = GFNumberFormatter.format_full(value, 2, false, false, true)

	assert_eq(text, "1.23", "FULL 模式格式化定点小数时应遵守 use_truncation。")


func test_format_full_groups_negative_decimal_integer_part_only() -> void:
	var text: String = GFNumberFormatter.format_full(-1234567.5, 1, true, true)

	assert_eq(text, "-1,234,567.5", "千分位分组应保留负号，并且只作用于整数部分。")


func test_format_full_returns_stable_fallback_for_non_finite_floats() -> void:
	assert_eq(GFNumberFormatter.format_full(INF, 2), "0", "INF 不应泄漏为引擎相关格式文本。")
	assert_push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")

	assert_eq(GFNumberFormatter.format_full(NAN, 2), "0", "NAN 不应泄漏为引擎相关格式文本。")
	assert_push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")


func test_format_auto_falls_back_to_scientific_for_huge_values() -> void:
	var huge: GFBigNumber = GFBigNumber.from_string("1e60")
	var text: String = GFNumberFormatter.format_auto(huge, 0)

	assert_eq(text, "1e60", "超出紧凑后缀表的超大数应自动回退到科学计数法。")


func test_format_compact_default_suffixes_are_stable() -> void:
	var original_suffixes: PackedStringArray = GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES
	GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES = PackedStringArray(["", "bad"])
	var text: String = GFNumberFormatter.format_compact(1_000, 0)
	GFNumberFormatter.DEFAULT_COMPACT_SUFFIXES = original_suffixes

	assert_eq(text, "1k", "默认紧凑后缀不应被运行时全局状态污染。")


func test_trim_trailing_zeroes_returns_stable_zero_for_empty_result() -> void:
	assert_eq(GFDecimalStringFormatter.trim_trailing_zeroes("000"), "0", "裁剪后为空的数字文本应收敛为 0。")
	assert_eq(GFDecimalStringFormatter.trim_trailing_zeroes("-000"), "0", "裁剪后只剩负号的数字文本应收敛为 0。")
