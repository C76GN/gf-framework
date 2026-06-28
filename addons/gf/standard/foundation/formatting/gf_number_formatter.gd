## GFNumberFormatter: 统一的数字显示格式化工具。
##
## 负责普通数字、定点小数与大数值对象在 UI 中的显示转换，
## 提供完整显示、紧凑缩写、科学计数法、工程计数法与自动模式。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNumberFormatter
extends RefCounted


# --- 枚举 ---

## 格式化记法。
## [br]
## @api public
enum Notation {
	## 尽量输出普通十进制表示。
	FULL,
	## 输出紧凑缩写表示，如 12.3k。
	COMPACT_SHORT,
	## 输出科学计数法，如 1.23e8。
	SCIENTIFIC,
	## 输出工程计数法，如 123.4e6。
	ENGINEERING,
	## 自动选择更适合当前量级的表示方式。
	AUTO,
}

## 科学计数法输出风格。
## [br]
## @api public
enum ScientificStyle {
	## 使用小写 e。
	E_LOWER,
	## 使用大写 E。
	E_UPPER,
	## 使用 x 10^n 形式。
	POWER_OF_TEN,
}


# --- 常量 ---

# 自动模式切换到科学计数法的小数阈值。
const _AUTO_SMALL_SCIENTIFIC_THRESHOLD: int = -4

# 自动模式切换到紧凑缩写的指数阈值。
const _AUTO_COMPACT_THRESHOLD: int = 3

# FULL 模式允许的最大普通十进制指数。
const _FULL_MAX_EXPONENT: int = 15

const _DECIMAL_STRING_FORMATTER = preload("res://addons/gf/standard/foundation/formatting/gf_decimal_string_formatter.gd")

# FULL 模式允许的最小普通十进制指数。
const _FULL_MIN_EXPONENT: int = -6


# --- 公共变量 ---

## 默认的紧凑缩写后缀表。
## [br]
## @api public
static var DEFAULT_COMPACT_SUFFIXES: PackedStringArray = PackedStringArray([
	"",
	"k",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"De",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
])


# --- 公共方法 ---

## 统一入口：按指定记法格式化一个数字值。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by the formatter.
## [br]
## @param notation: 目标记法。
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @param scientific_style: 科学计数法的输出风格。
## [br]
## @return 格式化后的字符串。
static func format_number(
	value: Variant,
	notation: Notation = Notation.AUTO,
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_truncation: bool = false,
	scientific_style: ScientificStyle = ScientificStyle.E_LOWER
) -> String:
	match notation:
		Notation.FULL:
			return format_full(value, decimal_places, trim_zeroes, false, use_truncation)
		Notation.COMPACT_SHORT:
			return format_compact(value, decimal_places, trim_zeroes, use_truncation)
		Notation.SCIENTIFIC:
			return format_scientific(
				value,
				decimal_places,
				trim_zeroes,
				use_truncation,
				scientific_style,
				false
			)
		Notation.ENGINEERING:
			return format_scientific(
				value,
				decimal_places,
				trim_zeroes,
				use_truncation,
				scientific_style,
				true
			)
		Notation.AUTO:
			return format_auto(
				value,
				decimal_places,
				trim_zeroes,
				use_truncation,
				scientific_style
			)

	return str(value)


## 输出普通十进制字符串。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by the formatter.
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_grouping: 是否为整数部分添加千分位分隔。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @return 普通十进制字符串。
static func format_full(
	value: Variant,
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_grouping: bool = false,
	use_truncation: bool = false
) -> String:
	var text: String = ""
	if value is GFFixedDecimal:
		var fixed_value: GFFixedDecimal = value
		var rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
		if use_truncation:
			rounding_mode = GFFixedDecimal.RoundingMode.TRUNCATE
		text = fixed_value.rescaled(decimal_places, rounding_mode).to_decimal_string(trim_zeroes)
	elif value is GFBigNumber:
		var big_value: GFBigNumber = value
		if big_value.exponent > _FULL_MAX_EXPONENT or big_value.exponent < _FULL_MIN_EXPONENT:
			return format_scientific(big_value, decimal_places, trim_zeroes, use_truncation)
		text = _DECIMAL_STRING_FORMATTER.format_decimal_value(big_value.to_float(), decimal_places, trim_zeroes, use_truncation)
	else:
		match typeof(value):
			TYPE_INT:
				text = str(value)
			TYPE_FLOAT:
				text = _DECIMAL_STRING_FORMATTER.format_decimal_value(
					GFVariantData.to_float(value),
					decimal_places,
					trim_zeroes,
					use_truncation
				)
			TYPE_STRING:
				text = value
			_:
				text = str(value)

	if use_grouping:
		return _group_integer_part(text)
	return text


## 输出紧凑缩写字符串，如 1.2k / 3.4M。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by the formatter.
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @param suffixes: 自定义后缀表；为空时使用默认值。
## [br]
## @return 紧凑缩写字符串。
static func format_compact(
	value: Variant,
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_truncation: bool = false,
	suffixes: PackedStringArray = PackedStringArray()
) -> String:
	var compact_suffixes: PackedStringArray = suffixes
	if compact_suffixes.is_empty():
		compact_suffixes = _get_default_compact_suffixes()

	var big_value: GFBigNumber = GFBigNumber.from_variant(value)
	if big_value.is_zero():
		return "0"

	if big_value.exponent < _AUTO_COMPACT_THRESHOLD:
		return format_full(value, decimal_places, trim_zeroes, false, use_truncation)

	var suffix_index: int = GFVariantData.to_int(floor(float(big_value.exponent) / 3.0))
	if suffix_index >= compact_suffixes.size():
		return format_scientific(big_value, decimal_places, trim_zeroes, use_truncation)

	var scaled_exponent: int = suffix_index * 3
	var display_value: float = big_value.mantissa * pow(10.0, big_value.exponent - scaled_exponent)
	var display_text: String = _DECIMAL_STRING_FORMATTER.format_decimal_value(
		display_value,
		decimal_places,
		trim_zeroes,
		use_truncation
	)
	var reparsed: float = display_text.to_float()
	if absf(reparsed) >= 1000.0 and suffix_index + 1 < compact_suffixes.size():
		suffix_index += 1
		scaled_exponent = suffix_index * 3
		display_value = big_value.mantissa * pow(10.0, big_value.exponent - scaled_exponent)
		display_text = _DECIMAL_STRING_FORMATTER.format_decimal_value(display_value, decimal_places, trim_zeroes, use_truncation)

	return display_text + compact_suffixes[suffix_index]


## 输出科学计数法或工程计数法字符串。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by the formatter.
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @param style: 输出风格。
## [br]
## @param engineering: 为 true 时输出工程计数法。
## [br]
## @return 科学计数法字符串。
static func format_scientific(
	value: Variant,
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_truncation: bool = false,
	style: ScientificStyle = ScientificStyle.E_LOWER,
	engineering: bool = false
) -> String:
	var big_value: GFBigNumber = GFBigNumber.from_variant(value)
	if big_value.is_zero():
		return "0"

	var output_exponent: int = big_value.exponent
	if engineering:
		output_exponent = GFVariantData.to_int(floor(float(big_value.exponent) / 3.0)) * 3

	var display_value: float = big_value.mantissa * pow(10.0, big_value.exponent - output_exponent)
	var display_text: String = _DECIMAL_STRING_FORMATTER.format_decimal_value(
		display_value,
		decimal_places,
		trim_zeroes,
		use_truncation
	)
	var reparsed: float = display_text.to_float()
	var overflow_threshold: float = 1000.0 if engineering else 10.0
	if absf(reparsed) >= overflow_threshold:
		output_exponent += 3 if engineering else 1
		display_value = big_value.mantissa * pow(10.0, big_value.exponent - output_exponent)
		display_text = _DECIMAL_STRING_FORMATTER.format_decimal_value(display_value, decimal_places, trim_zeroes, use_truncation)

	match style:
		ScientificStyle.E_UPPER:
			return "%sE%d" % [display_text, output_exponent]
		ScientificStyle.POWER_OF_TEN:
			return "%s x 10^%d" % [display_text, output_exponent]
		_:
			return "%se%d" % [display_text, output_exponent]


## 自动选择最合适的数字记法。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by the formatter.
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @param scientific_style: 科学计数法输出风格。
## [br]
## @return 自动挑选后的字符串。
static func format_auto(
	value: Variant,
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_truncation: bool = false,
	scientific_style: ScientificStyle = ScientificStyle.E_LOWER
) -> String:
	var big_value: GFBigNumber = GFBigNumber.from_variant(value)
	if big_value.is_zero():
		return "0"

	var max_compact_exponent: int = (_get_default_compact_suffixes().size() - 1) * 3 + 2
	if big_value.exponent >= _AUTO_COMPACT_THRESHOLD and big_value.exponent <= max_compact_exponent:
		return format_compact(value, decimal_places, trim_zeroes, use_truncation)

	if big_value.exponent < _AUTO_SMALL_SCIENTIFIC_THRESHOLD or big_value.exponent > max_compact_exponent:
		return format_scientific(value, decimal_places, trim_zeroes, use_truncation, scientific_style)

	return format_full(value, decimal_places, trim_zeroes, false, use_truncation)


# --- 私有/辅助方法 ---


static func _get_default_compact_suffixes() -> PackedStringArray:
	return PackedStringArray([
		"",
		"k",
		"M",
		"B",
		"T",
		"Qa",
		"Qi",
		"Sx",
		"Sp",
		"Oc",
		"No",
		"De",
		"Ud",
		"Dd",
		"Td",
		"Qad",
		"Qid",
	])


static func _group_integer_part(text: String) -> String:
	var sign_text: String = ""
	var body: String = text
	if body.begins_with("-"):
		sign_text = "-"
		body = body.substr(1)

	var decimal_index: int = body.find(".")
	var integer_part: String = body
	var fractional_part: String = ""
	if decimal_index != -1:
		integer_part = body.substr(0, decimal_index)
		fractional_part = body.substr(decimal_index)

	var grouped: String = ""
	var digit_count: int = 0
	for i: int in range(integer_part.length() - 1, -1, -1):
		grouped = integer_part.substr(i, 1) + grouped
		digit_count += 1
		if digit_count % 3 == 0 and i > 0:
			grouped = "," + grouped

	return sign_text + grouped + fractional_part
