## 测试 GFNumberFormatter 的完整显示、紧凑缩写与科学计数法行为。
extends GutTest


func test_full_zero_decimals_does_not_narrow_large_float() -> void:
	assert_eq(
		GFNumberFormatter.format_number(
			1.0e20,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 0,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"100000000000000000000"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			-1.0e20,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 0,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"-100000000000000000000"
	)


func test_format_compact_supports_k_suffix() -> void:
	var text: String = GFNumberFormatter.format_number(
		1_000,
		GFNumberFormatPolicy.create(
			{
				"notation": "compact",
				"decimal_places": 0,
				"trim_zeroes": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"1k",
		"1000 在紧凑模式下应格式化为 1k。"
	)


func test_format_compact_can_keep_fractional_precision() -> void:
	var text: String = GFNumberFormatter.format_number(
		12_345,
		GFNumberFormatPolicy.create(
			{
				"notation": "compact",
				"decimal_places": 3,
				"trim_zeroes": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"12.345k",
		"12345 在 3 位小数紧凑模式下应得到 12.345k。"
	)


func test_format_compact_carries_when_rounding_reaches_next_suffix() -> void:
	var text: String = GFNumberFormatter.format_number(
		999_950,
		GFNumberFormatPolicy.create(
			{
				"notation": "compact",
				"decimal_places": 1,
				"trim_zeroes": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"1M",
		"紧凑格式四舍五入到 1000k 时应进位到下一个后缀。"
	)


func test_format_scientific_supports_multiple_styles() -> void:
	var scientific: String = GFNumberFormatter.format_number(
		1_000_000,
		GFNumberFormatPolicy.create(
			{
				"notation": "scientific",
				"decimal_places": 0,
				"trim_zeroes": true,
				"rounding": "half_up",
				"scientific_style": "e",
			}
		)
	)
	var power_text: String = GFNumberFormatter.format_number(
		1_000_000,
		GFNumberFormatPolicy.create(
			{
				"notation": "scientific",
				"decimal_places": 0,
				"trim_zeroes": true,
				"rounding": "half_up",
				"scientific_style": "power",
			}
		)
	)

	assert_eq(
		scientific,
		"1e6",
		"科学计数法默认应输出 e 风格。"
	)
	assert_eq(
		power_text,
		"1 x 10^6",
		"POWER_OF_TEN 风格应输出 x 10^n。"
	)


func test_format_full_padding_does_not_rescale_large_fixed_values() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.new(1_000_000_000_000_000_000, 0)
	assert_eq(
		GFNumberFormatter.format_number(
			value,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"1000000000000000000.00"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			value,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"1000000000000000000"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			value.negated(),
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": true,
					"rounding": "half_up",
				}
			)
		),
		"-1,000,000,000,000,000,000.00"
	)
	assert_eq(value.raw_value, 1_000_000_000_000_000_000)
	assert_eq(value.decimal_places, 0)


func test_format_full_understands_fixed_decimal() -> void:
	var money: GFFixedDecimal = GFFixedDecimal.from_string("1234.500", 3)
	var text: String = GFNumberFormatter.format_number(
		money,
		GFNumberFormatPolicy.create(
			{
				"notation": "full",
				"decimal_places": 3,
				"trim_zeroes": true,
				"use_grouping": false,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"1234.5",
		"FULL 模式应能直接格式化定点小数。"
	)


func test_format_full_respects_truncation_for_fixed_decimal() -> void:
	var value: GFFixedDecimal = GFFixedDecimal.from_string("1.239", 3)
	var text: String = GFNumberFormatter.format_number(
		value,
		GFNumberFormatPolicy.create(
			{
				"notation": "full",
				"decimal_places": 2,
				"trim_zeroes": false,
				"use_grouping": false,
				"rounding": "toward_zero",
			}
		)
	)

	assert_eq(
		text,
		"1.23",
		"FULL 模式格式化定点小数时应遵守 toward_zero 政策。"
	)


func test_format_full_groups_negative_decimal_integer_part_only() -> void:
	var text: String = GFNumberFormatter.format_number(
		-1234567.5,
		GFNumberFormatPolicy.create(
			{
				"notation": "full",
				"decimal_places": 1,
				"trim_zeroes": true,
				"use_grouping": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"-1,234,567.5",
		"千分位分组应保留负号，并且只作用于整数部分。"
	)


func test_format_full_groups_positive_signed_text() -> void:
	var text: String = GFNumberFormatter.format_number(
		"+1234567.5",
		GFNumberFormatPolicy.create(
			{
				"notation": "full",
				"decimal_places": 1,
				"trim_zeroes": true,
				"use_grouping": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"+1,234,567.5",
		"千分位分组应保留显式正号。"
	)


func test_format_full_applies_precision_options_to_plain_numeric_text() -> void:
	assert_eq(
		GFNumberFormatter.format_number(
			"1.239",
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": false,
					"rounding": "toward_zero",
				}
			)
		),
		"1.23",
		"普通数值文本必须遵守截断和小数位参数。"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			"1.239",
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"1.24",
		"普通数值文本必须在字符串域精确舍入。"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			"1.200",
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"1.2",
		"trim_zeroes 必须作用于文本输入。"
	)
	assert_eq(
		GFNumberFormatter.format_number(
			"1.200",
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"1.20",
		"关闭 trim 时必须补齐目标精度。"
	)


func test_format_full_keeps_large_numeric_text_out_of_float_path() -> void:
	assert_eq(
		GFNumberFormatter.format_number(
			"9007199254740993.125",
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": false,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"9007199254740993.13",
		"超过 float 精确整数范围的文本也必须逐位舍入。"
	)


func test_format_full_returns_stable_fallback_for_non_finite_floats() -> void:
	assert_eq(
		GFNumberFormatter.format_number(
			INF,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"0",
		"INF 不应泄漏为引擎相关格式文本。"
	)
	assert_push_error("[GFNumberFormatter][number_formatter.invalid_input] Cannot format number: non_finite.")

	assert_eq(
		GFNumberFormatter.format_number(
			NAN,
			GFNumberFormatPolicy.create(
				{
					"notation": "full",
					"decimal_places": 2,
					"trim_zeroes": true,
					"use_grouping": false,
					"rounding": "half_up",
				}
			)
		),
		"0",
		"NAN 不应泄漏为引擎相关格式文本。"
	)
	assert_push_error("[GFNumberFormatter][number_formatter.invalid_input] Cannot format number: non_finite.")


func test_format_auto_falls_back_to_scientific_for_huge_values() -> void:
	var huge: GFBigNumber = GFBigNumber.from_string("1e60")
	var text: String = GFNumberFormatter.format_number(
		huge,
		GFNumberFormatPolicy.create(
			{
				"notation": "auto",
				"decimal_places": 0,
				"trim_zeroes": true,
				"rounding": "half_up",
				"scientific_style": "e",
			}
		)
	)

	assert_eq(
		text,
		"1e60",
		"超出紧凑后缀表的超大数应自动回退到科学计数法。"
	)


func test_format_compact_default_suffixes_are_returned_as_copy() -> void:
	var suffixes: PackedStringArray = GFNumberFormatPolicy.get_default_suffixes()
	suffixes[1] = "bad"
	var text: String = GFNumberFormatter.format_number(
		1_000,
		GFNumberFormatPolicy.create(
			{
				"notation": "compact",
				"decimal_places": 0,
				"trim_zeroes": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"1k",
		"修改默认后缀副本不应污染 compact 默认行为。"
	)
	assert_eq(
		GFNumberFormatPolicy.get_default_suffixes()[1],
		"k",
		"默认后缀 getter 应每次返回独立副本。"
	)


func test_format_full_rejects_non_numeric_string_instead_of_grouping_it() -> void:
	var text: String = GFNumberFormatter.format_number(
		"NOT_AVAILABLE_1000",
		GFNumberFormatPolicy.create(
			{
				"notation": "full",
				"decimal_places": 2,
				"trim_zeroes": true,
				"use_grouping": true,
				"rounding": "half_up",
			}
		)
	)

	assert_eq(
		text,
		"0",
		"非数值文本应使用稳定 fallback，不能被改写成伪数值。"
	)
	assert_push_error("[GFNumberFormatter][number_formatter.invalid_input] Cannot format number: invalid_exponent.")


func test_trim_trailing_zeroes_preserves_integer_text() -> void:
	assert_eq(
		GFDecimalStringFormatter.trim_trailing_zeroes("000"),
		"000",
		"整数文本不得因尾零裁剪而改变位数。"
	)
	assert_eq(
		GFDecimalStringFormatter.trim_trailing_zeroes("-000"),
		"-000",
		"带符号整数文本也不得改变位数。"
	)
	assert_eq(
		GFDecimalStringFormatter.trim_trailing_zeroes("-0"),
		"0",
		"精确负零应规范化为零。"
	)


func test_ten_thousand_units_carry_and_truncation_do_not_overstate_positive_value() -> void:
	assert_eq(
		_format(
			"12345678",
			{ "notation": "compact", "group_base": 10000 }
		),
		"1234.57万"
	)
	assert_eq(
		_format(
			"99999950",
			{
				"notation": "compact",
				"group_base": 10000,
				"decimal_places": 1,
			}
		),
		"1亿"
	)
	assert_eq(
		_format(
			"99999950",
			{
				"notation": "compact",
				"group_base": 10000,
				"decimal_places": 1,
				"rounding": "toward_zero",
			}
		),
		"9999.9万"
	)
	assert_eq(
		_format(
			"9999.95",
			{
				"notation": "compact",
				"group_base": 10000,
				"decimal_places": 1,
			}
		),
		"1万"
	)
	assert_eq(
		_format(
			"999.95",
			{ "decimal_places": 1 }
		),
		"1k"
	)
	assert_eq(
		_format(
			"999.95",
			{ "decimal_places": 1, "rounding": "toward_zero" }
		),
		"999.9"
	)


func test_every_rounding_direction_is_exact_for_positive_negative_and_tiny_text() -> void:
	var cases: Array[Dictionary] = [
		{
			"rounding": "half_up",
			"positive": "1.24",
			"negative": "-1.24",
		},
		{
			"rounding": "half_even",
			"positive": "1.24",
			"negative": "-1.24",
		},
		{
			"rounding": "toward_zero",
			"positive": "1.23",
			"negative": "-1.23",
		},
		{
			"rounding": "floor",
			"positive": "1.23",
			"negative": "-1.24",
		},
		{
			"rounding": "ceiling",
			"positive": "1.24",
			"negative": "-1.23",
		},
	]
	for record: Dictionary in cases:
		var policy: Dictionary = { "notation": "full", "rounding": GFVariantData.get_option_string(record, "rounding") }
		assert_eq(
			_format("1.235", policy),
			GFVariantData.get_option_string(record, "positive")
		)
		assert_eq(
			_format("-1.235", policy),
			GFVariantData.get_option_string(record, "negative")
		)
	assert_eq(
		_format(
			"1.245",
			{ "notation": "full", "rounding": "half_even" }
		),
		"1.24"
	)
	assert_eq(
		_format(
			"1.24501",
			{ "notation": "full", "rounding": "half_even" }
		),
		"1.25"
	)
	assert_eq(
		_format(
			"0.000001",
			{ "notation": "full", "rounding": "ceiling" }
		),
		"0.01"
	)
	assert_eq(
		_format(
			"-0.000001",
			{ "notation": "full", "rounding": "floor" }
		),
		"-0.01"
	)
	assert_eq(
		_format(
			"-0.004",
			{ "notation": "full", "trim_zeroes": false }
		),
		"0.00"
	)


func test_significant_digits_and_decimal_cap_are_applied_to_original_value() -> void:
	assert_eq(
		_format(
			"123456",
			{ "notation": "full", "significant_digits": 3 }
		),
		"123000"
	)
	assert_eq(
		_format(
			"9.999",
			{
				"notation": "full",
				"significant_digits": 3,
				"trim_zeroes": false,
			}
		),
		"10.0"
	)
	assert_eq(
		_format(
			"0.00123456",
			{
				"notation": "full",
				"significant_digits": 3,
				"decimal_places": 8,
				"trim_zeroes": false,
			}
		),
		"0.00123"
	)
	assert_eq(
		_format(
			"0.00123456",
			{
				"notation": "full",
				"significant_digits": 3,
				"decimal_places": 2,
			}
		),
		"0"
	)
	assert_eq(
		_format(
			"999950",
			{
				"notation": "compact",
				"significant_digits": 4,
				"decimal_places": 1,
			}
		),
		"1M"
	)


func test_scientific_and_compact_keep_all_large_integer_digits() -> void:
	assert_eq(
		_format(
			"9007199254740993",
			{ "notation": "scientific", "decimal_places": 18 }
		),
		"9.007199254740993e15"
	)
	assert_eq(
		_format(
			"9007199254740993",
			{ "notation": "compact", "decimal_places": 18 }
		),
		"9.007199254740993Qa"
	)
	assert_eq(
		_format(
			9223372036854775807,
			{ "notation": "full" }
		),
		"9223372036854775807"
	)
	assert_eq(
		_format(
			-9223372036854775807 - 1,
			{ "notation": "full" }
		),
		"-9223372036854775808"
	)
	assert_eq(
		_format(
			"9007199254740993125e-3",
			{ "notation": "full", "trim_zeroes": false }
		),
		"9007199254740993.13"
	)
	assert_eq(
		_format(
			"+9007199254740993",
			{ "notation": "scientific", "decimal_places": 18 }
		),
		"+9.007199254740993e15"
	)


func test_engineering_negative_exponents_and_rounding_carry() -> void:
	assert_eq(
		_format(
			"0.000012345",
			{ "notation": "engineering", "decimal_places": 3 }
		),
		"12.345e-6"
	)
	assert_eq(
		_format(
			"999.999",
			{ "notation": "engineering", "decimal_places": 2 }
		),
		"1e3"
	)
	assert_eq(
		_format(
			"9.999",
			{ "notation": "scientific", "decimal_places": 2 }
		),
		"1e1"
	)
	assert_eq(
		_format(
			"9.999e1000000",
			{ "notation": "scientific", "decimal_places": 2 }
		),
		"1e1000001"
	)
	assert_eq(
		_format(
			"0.00001",
			{ "scientific_style": "E" }
		),
		"1E-5"
	)


func test_custom_suffixes_are_frozen_and_exhaustion_falls_back_to_scientific() -> void:
	var suffixes: PackedStringArray = PackedStringArray(["", "thousand"])
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create({ "notation": "compact", "suffixes": suffixes })
	suffixes[1] = "changed"
	assert_eq(
		GFNumberFormatter.format_number(1000, policy),
		"1thousand"
	)
	assert_eq(
		GFNumberFormatter.format_number(1000000, policy),
		"1e6"
	)
	assert_eq(
		GFNumberFormatter.format_number("999999.99", policy),
		"1e6"
	)
	var copied: Dictionary = policy.to_record()
	copied["rounding"] = "toward_zero"
	assert_eq(
		GFNumberFormatter.format_number("999999.99", policy),
		"1e6"
	)


func test_full_budget_fallback_is_bounded_and_preserves_scientific_magnitude() -> void:
	var result: Dictionary = GFNumberFormatter.try_format(
		"1e1000000",
		GFNumberFormatPolicy.create({ "notation": "full" })
	)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "text"),
		"1e1000000"
	)
	assert_eq(
		_format(
			"1e8000",
			{ "notation": "full", "use_grouping": true }
		),
		"1e8000"
	)
	assert_eq(
		_format(
			"0e999999",
			{ "notation": "full", "trim_zeroes": false }
		),
		"0.00"
	)


func test_try_format_distinguishes_invalid_input_from_real_zero() -> void:
	for invalid: Variant in [
		true,
		null,
		{},
		"1e1000001",
		"1e999999999999999999999",
		"9".repeat(4097),
		"not-a-number",
		NAN,
	]:
		var result: Dictionary = GFNumberFormatter.try_format(invalid)
		assert_false(GFVariantData.get_option_bool(result, "ok"))
		assert_eq(
			GFVariantData.get_option_string(result, "text"),
			""
		)
		assert_false(GFVariantData.get_option_string(result, "error").is_empty())
	assert_true(
		GFVariantData.get_option_bool(
			GFNumberFormatter.try_format(0),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFNumberFormatter.try_format(
				1,
				GFNumberFormatPolicy.new()
			),
			"ok"
		)
	)


func test_policy_rejects_implicit_types_unknown_fields_and_ambiguous_suffixes() -> void:
	assert_null(GFNumberFormatPolicy.create({ "group_base": 100 }))
	assert_null(GFNumberFormatPolicy.create({ "decimal_places": 2.0 }))
	assert_null(GFNumberFormatPolicy.create({ "decimal_places": 19 }))
	assert_null(GFNumberFormatPolicy.create({ "significant_digits": -1 }))
	assert_null(GFNumberFormatPolicy.create({ "rounding": "nearest" }))
	assert_null(
		GFNumberFormatPolicy.create(
			{
				"suffixes": ["", "k"],
			}
		)
	)
	assert_null(
		GFNumberFormatPolicy.create(
			{
				"suffixes": PackedStringArray(
					[
						"",
						"k",
						"k",
					]
				),
			}
		)
	)
	assert_null(GFNumberFormatPolicy.create({ "use_truncation": true }))
	assert_eq(
		_format(
			"123456789",
			{
				"notation": "full",
				"group_base": 10000,
				"use_grouping": true,
			}
		),
		"1,2345,6789"
	)


func test_grouping_and_decimal_symbols_are_independent_of_compact_units() -> void:
	var options: Dictionary = {
		"notation": "full",
		"group_base": 10000,
		"use_grouping": true,
		"grouping_size": 3,
		"group_separator": ".",
		"decimal_separator": ",",
	}
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create(options)
	assert_not_null(policy)
	if policy == null:
		return
	assert_eq(
		GFNumberFormatter.format_number("123456789.25", policy),
		"123.456.789,25"
	)
	options["notation"] = "compact"
	options["suffixes"] = PackedStringArray(["", "万.枚"])
	assert_eq(
		_format("12345", options),
		"1,23万.枚"
	)
	options["notation"] = "scientific"
	assert_eq(
		_format("12345", options),
		"1,23e4"
	)
	options["notation"] = "engineering"
	assert_eq(
		_format("12345", options),
		"12,35e3"
	)
	assert_eq(
		_format(
			"-0.5",
			{ "notation": "full", "decimal_separator": "," }
		),
		"-0,5"
	)
	assert_eq(
		_format(
			"+1234",
			{
				"notation": "full",
				"use_grouping": true,
				"group_separator": " ",
			}
		),
		"+1 234"
	)


func test_auto_thresholds_use_original_exact_magnitude() -> void:
	var options: Dictionary = {
		"auto_scientific_below": -6,
		"auto_compact_from": 4,
		"decimal_places": 8,
	}
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create(options)
	assert_not_null(policy)
	if policy == null:
		return
	assert_eq(
		GFNumberFormatter.format_number("9999", policy),
		"9999"
	)
	assert_eq(
		GFNumberFormatter.format_number("10000", policy),
		"10k"
	)
	assert_eq(
		GFNumberFormatter.format_number("-10000", policy),
		"-10k"
	)
	assert_eq(
		GFNumberFormatter.format_number("0.000001", policy),
		"0.000001"
	)
	assert_eq(
		GFNumberFormatter.format_number("0.0000001", policy),
		"1e-7"
	)
	assert_eq(
		GFNumberFormatter.format_number(0, policy),
		"0"
	)
	options["auto_compact_from"] = 16
	assert_eq(
		_format("9999999999999999", options),
		"9999999999999999"
	)
	assert_eq(
		_format("10000000000000000", options),
		"10Qa"
	)
	assert_eq(
		_format("999.999", {}),
		"1k"
	)


func test_fallback_reports_notation_and_reason() -> void:
	var full: Dictionary = GFNumberFormatter.try_format(
		"1e1000000",
		GFNumberFormatPolicy.create({ "notation": "full" })
	)
	assert_true(GFVariantData.get_option_bool(full, "ok"))
	assert_eq(
		GFVariantData.get_option_string(full, "notation_used"),
		"scientific"
	)
	assert_eq(
		GFVariantData.get_option_string(full, "fallback_reason"),
		"output_budget"
	)
	var compact: Dictionary = GFNumberFormatter.try_format(
		"999999.99",
		GFNumberFormatPolicy.create(
			{
				"suffixes": PackedStringArray(["", "k"]),
			}
		)
	)
	assert_true(GFVariantData.get_option_bool(compact, "ok"))
	assert_eq(
		GFVariantData.get_option_string(compact, "text"),
		"1e6"
	)
	assert_eq(
		GFVariantData.get_option_string(compact, "notation_used"),
		"scientific"
	)
	assert_eq(
		GFVariantData.get_option_string(compact, "fallback_reason"),
		"suffix_exhausted"
	)
	var regular: Dictionary = GFNumberFormatter.try_format("1e6")
	assert_eq(
		GFVariantData.get_option_string(regular, "notation_used"),
		"compact"
	)
	assert_eq(
		GFVariantData.get_option_string(regular, "fallback_reason"),
		""
	)


func test_fallback_can_be_rejected_without_unbounded_output() -> void:
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create({ "notation": "full", "fallback_notation": "error" })
	assert_not_null(policy)
	if policy == null:
		return
	var result: Dictionary = GFNumberFormatter.try_format("1e1000000", policy)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "text"),
		""
	)
	assert_eq(
		GFVariantData.get_option_string(result, "error"),
		"output_budget"
	)
	assert_eq(
		GFVariantData.get_option_string(result, "fallback_reason"),
		"output_budget"
	)
	policy = GFNumberFormatPolicy.create(
		{
			"suffixes": PackedStringArray([""]),
			"fallback_notation": "error",
		}
	)
	result = GFNumberFormatter.try_format(1000, policy)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "error"),
		"suffix_exhausted"
	)
	policy = GFNumberFormatPolicy.create(
		{
			"notation": "full",
			"use_grouping": true,
			"grouping_size": 1,
			"group_separator": "____",
			"fallback_notation": "error",
		}
	)
	result = GFNumberFormatter.try_format("1e2000", policy)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "error"),
		"output_budget"
	)


func test_policy_creation_diagnostics_cannot_silently_use_defaults() -> void:
	var creation: Dictionary = GFNumberFormatPolicy.try_create({ "group_base": 1024 })
	assert_false(GFVariantData.get_option_bool(creation, "ok"))
	var absent_policy: GFNumberFormatPolicy = creation.get("policy")
	assert_null(absent_policy)
	assert_eq(
		GFVariantData.get_option_string(creation, "error_kind"),
		"invalid_value"
	)
	assert_eq(
		GFVariantData.get_option_string(creation, "path"),
		"options.group_base"
	)
	var result: Dictionary = GFNumberFormatter.try_format_options(
		"invalid input",
		{ "decimals": 1 }
	)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "error"),
		"invalid_policy"
	)
	assert_eq(
		GFVariantData.get_option_string(result, "policy_error_kind"),
		"unknown_option"
	)
	assert_eq(
		GFVariantData.get_option_string(result, "path"),
		"options.decimals"
	)
	assert_eq(
		GFVariantData.get_option_string(result, "text"),
		""
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFNumberFormatter.try_format_options(1234),
			"text"
		),
		"1.23k"
	)
	assert_eq(
		GFNumberFormatter.format_number(1234, null),
		"1.23k"
	)
	creation = GFNumberFormatPolicy.try_create({ "decimal_separator": "," })
	assert_true(GFVariantData.get_option_bool(creation, "ok"))
	var candidate: Variant = creation.get("policy")
	assert_true(candidate is GFNumberFormatPolicy)
	if candidate is GFNumberFormatPolicy:
		var policy: GFNumberFormatPolicy = candidate
		var record: Dictionary = policy.to_record()
		record["decimal_separator"] = "changed"
		creation.clear()
		assert_eq(
			GFNumberFormatter.format_number("1.5", policy),
			"1,5"
		)
	assert_false(
		GFVariantData.get_option_bool(
			GFNumberFormatter.try_format_options(
				"1,5",
				{ "decimal_separator": "," }
			),
			"ok"
		)
	)


func test_new_policy_fields_reject_invalid_values_with_field_paths() -> void:
	var invalid: Array[Dictionary] = [
		{ "grouping_size": 0 },
		{ "grouping_size": 8193 },
		{ "grouping_size": 3.0 },
		{ "group_separator": "12345" },
		{ "group_separator": "\n" },
		{ "decimal_separator": "" },
		{ "decimal_separator": "....." },
		{ "auto_scientific_below": 1 },
		{ "auto_scientific_below": -1000001 },
		{ "auto_compact_from": -1 },
		{ "auto_compact_from": 1000001 },
		{ "fallback_notation": "full" },
	]
	for options: Dictionary in invalid:
		var report: Dictionary = GFNumberFormatPolicy.try_create(options)
		assert_false(GFVariantData.get_option_bool(report, "ok"))
		assert_eq(
			GFVariantData.get_option_string(report, "path"),
			"options." + str(options.keys()[0])
		)
		assert_null(GFNumberFormatPolicy.create(options))
	assert_eq(
		_format(
			"1234.5",
			{
				"notation": "full",
				"use_grouping": true,
				"group_separator": "",
				"decimal_separator": "点",
			}
		),
		"1234点5"
	)


func test_display_separators_reject_control_and_line_separator_characters() -> void:
	for character: int in [
		128,
		133,
		159,
		8232,
		8233,
	]:
		for option: String in ["group_separator", "decimal_separator"]:
			var options: Dictionary = { option: String.chr(character) }
			var report: Dictionary = GFNumberFormatPolicy.try_create(options)
			assert_false(GFVariantData.get_option_bool(report, "ok"))
			assert_eq(
				GFVariantData.get_option_string(report, "path"),
				"options." + option
			)
			assert_false(
				GFVariantData.get_option_bool(
					GFNumberFormatter.try_format_options("1.5", options),
					"ok"
				)
			)


func test_display_budget_includes_custom_separators_without_changing_value() -> void:
	var exact: Dictionary = GFNumberFormatter.try_format_options(
		"1e8191",
		{
			"notation": "full",
			"decimal_places": 0,
			"fallback_notation": "error",
		}
	)
	assert_true(GFVariantData.get_option_bool(exact, "ok"))
	assert_eq(
		GFVariantData.get_option_string(exact, "text").length(),
		8192
	)
	var overflow: Dictionary = GFNumberFormatter.try_format_options(
		"1e8191",
		{
			"notation": "full",
			"decimal_places": 0,
			"use_grouping": true,
			"grouping_size": 3,
			"group_separator": " | ",
			"decimal_separator": ",",
			"scientific_style": "E",
		}
	)
	assert_true(GFVariantData.get_option_bool(overflow, "ok"))
	assert_eq(
		GFVariantData.get_option_string(overflow, "text"),
		"1E8191"
	)
	assert_eq(
		GFVariantData.get_option_string(overflow, "fallback_reason"),
		"output_budget"
	)


func _format(value: Variant, options: Dictionary) -> String:
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.create(options)
	assert_not_null(policy)
	return GFNumberFormatter.format_number(value, policy)
