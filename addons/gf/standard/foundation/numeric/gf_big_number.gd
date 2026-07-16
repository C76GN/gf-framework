## GFBigNumber: 面向挂机/放置场景的近似大数值对象。
##
## 使用科学计数法的尾数 + 指数表示任意量级的数值，
## 适合做超出原生 int/float 直观显示范围后的比较、加减乘除与格式化输入。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFBigNumber
extends RefCounted


# --- 常量 ---

# 归一化时判定为零的误差阈值。
const _NORMALIZATION_EPSILON: float = 0.000000000001

# 做加减法时，指数差超过该阈值则忽略较小项。
const _ADDITION_DROP_THRESHOLD: int = 18

# to_plain_string() 默认保留的小数位数。
const _DEFAULT_PLAIN_DECIMALS: int = 6

# 大数用于玩法和显示近似，不承诺 int64 全范围指数算术。
const _MAX_EXPONENT_MAGNITUDE: int = 1_000_000

const _DECIMAL_STRING_FORMATTER = preload("res://addons/gf/standard/foundation/formatting/gf_decimal_string_formatter.gd")


# --- 公共变量 ---

## 归一化后的尾数。非零时其绝对值始终落在 [1, 10) 区间内。
## [br]
## @api public
var mantissa: float = 0.0

## 以 10 为底的指数。
## [br]
## @api public
var exponent: int = 0


# --- Godot 生命周期方法 ---

func _init(p_mantissa: float = 0.0, p_exponent: int = 0) -> void:
	mantissa = p_mantissa
	exponent = p_exponent
	_normalize()


# --- 公共方法 ---

## 创建一个值为 0 的大数。
## [br]
## @api public
## [br]
## @return 零值实例。
static func zero() -> GFBigNumber:
	return GFBigNumber.new(0.0, 0)


## 创建一个值为 1 的大数。
## [br]
## @api public
## [br]
## @return 一值实例。
static func one() -> GFBigNumber:
	return GFBigNumber.new(1.0, 0)


## 从 int 构建大数。
## [br]
## @api public
## [br]
## @param value: 原始整数。
## [br]
## @return 归一化后的大数实例。
static func from_int(value: int) -> GFBigNumber:
	return GFBigNumber.new(float(value), 0)


## 从 float 构建大数。
## [br]
## @api public
## [br]
## @param value: 原始浮点数。
## [br]
## @return 归一化后的大数实例。
static func from_float(value: float) -> GFBigNumber:
	if is_nan(value) or is_inf(value):
		push_error("[GFBigNumber] from_float 收到非法浮点值。")
		return GFBigNumber.zero()

	return GFBigNumber.new(value, 0)


## 从字符串构建大数，支持普通写法与科学计数法。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 原始字符串，如 "12345"、"1.23e8"。
## [br]
## @param max_input_length: 最大输入字符数；小于等于 0 时使用框架默认预算。
## [br]
## @return 解析后的大数实例。
static func from_string(
	value: String,
	max_input_length: int = GFDecimalStringFormatter.DEFAULT_MAX_NUMERIC_TEXT_LENGTH
) -> GFBigNumber:
	var normalization: Dictionary = _DECIMAL_STRING_FORMATTER.normalize_numeric_text(value, max_input_length)
	if not GFVariantData.get_option_bool(normalization, "ok"):
		push_error("[GFBigNumber] 无法解析数字字符串（%s）：%s" % [
			GFVariantData.get_option_string(normalization, "error", "invalid_input"),
			value.left(128),
		])
		return GFBigNumber.zero()
	var trimmed: String = GFVariantData.get_option_string(normalization, "text")

	var exponent_offset: int = 0
	var scientific_index: int = maxi(trimmed.find("e"), trimmed.find("E"))
	if scientific_index != -1:
		var exponent_text: String = trimmed.substr(scientific_index + 1)
		trimmed = trimmed.substr(0, scientific_index)
		var exponent_result: Dictionary = _try_parse_exponent_text(exponent_text)
		if not GFVariantData.get_option_bool(exponent_result, &"ok", false):
			if GFVariantData.get_option_string(exponent_result, &"reason") == "range":
				push_error("[GFBigNumber] 指数超出支持范围。")
				return GFBigNumber.zero()

			push_error("[GFBigNumber] 无法解析科学计数法指数：%s" % value)
			return GFBigNumber.zero()
		exponent_offset = GFVariantData.get_option_int(exponent_result, &"value")

	var sign_multiplier: float = 1.0
	if trimmed.begins_with("-"):
		sign_multiplier = -1.0
		trimmed = trimmed.substr(1)
	elif trimmed.begins_with("+"):
		trimmed = trimmed.substr(1)

	var decimal_index: int = trimmed.find(".")
	var integer_part: String = trimmed
	var fractional_part: String = ""
	if decimal_index != -1:
		integer_part = trimmed.substr(0, decimal_index)
		fractional_part = trimmed.substr(decimal_index + 1)

	if not _DECIMAL_STRING_FORMATTER.is_valid_decimal_parts(integer_part, fractional_part, decimal_index != -1):
		push_error("[GFBigNumber] 无法解析数字字符串：%s" % value)
		return GFBigNumber.zero()

	var digits: String = integer_part + fractional_part
	var first_non_zero: int = -1
	for i: int in range(digits.length()):
		if digits.substr(i, 1) != "0":
			first_non_zero = i
			break

	if first_non_zero == -1:
		return GFBigNumber.zero()

	var significant_digits: String = digits.substr(first_non_zero)
	var mantissa_digits: String = significant_digits.substr(0, mini(16, significant_digits.length()))
	var mantissa_text: String = mantissa_digits.substr(0, 1)
	if mantissa_digits.length() > 1:
		mantissa_text += "." + mantissa_digits.substr(1)

	var mantissa_value: float = mantissa_text.to_float() * sign_multiplier
	var normalized_exponent: int = integer_part.length() - first_non_zero - 1 + exponent_offset
	if not _exponent_is_supported(normalized_exponent):
		push_error("[GFBigNumber] 指数超出支持范围。")
		return GFBigNumber.zero()
	return GFBigNumber.new(mantissa_value, normalized_exponent)


## 从任意支持的 Variant 构建大数。
## [br]
## @api public
## [br]
## @param value: 支持 int/float/String/GFBigNumber/GFFixedDecimal。
## [br]
## @schema value: Variant numeric value accepted by GFBigNumber.
## [br]
## @return 对应的大数实例。
static func from_variant(value: Variant) -> GFBigNumber:
	if value is GFBigNumber:
		var big_number: GFBigNumber = value
		return big_number.clone()

	if value is GFFixedDecimal:
		var fixed_decimal: GFFixedDecimal = value
		return GFBigNumber.from_string(fixed_decimal.to_decimal_string(false))

	if value is int:
		var int_value: int = value
		return GFBigNumber.from_int(int_value)
	if value is float:
		var float_value: float = value
		return GFBigNumber.from_float(float_value)
	if value is String:
		var string_value: String = value
		return GFBigNumber.from_string(string_value)

	push_error("[GFBigNumber] from_variant 收到不支持的值类型。")
	return GFBigNumber.zero()


## 克隆当前大数。
## [br]
## @api public
## [br]
## @return 内容相同的新实例。
func clone() -> GFBigNumber:
	return GFBigNumber.new(mantissa, exponent)


## 当前值是否为零。
## [br]
## @api public
## [br]
## @return 为零时返回 true。
func is_zero() -> bool:
	return absf(mantissa) <= _NORMALIZATION_EPSILON


## 当前值是否为负数。
## [br]
## @api public
## [br]
## @return 为负时返回 true。
func is_negative() -> bool:
	return mantissa < 0.0


## 获取绝对值。
## [br]
## @api public
## [br]
## @return 新的大数实例。
func abs_value() -> GFBigNumber:
	return GFBigNumber.new(absf(mantissa), exponent)


## 获取相反数。
## [br]
## @api public
## [br]
## @return 新的大数实例。
func negated() -> GFBigNumber:
	return GFBigNumber.new(-mantissa, exponent)


## 比较当前值与另一个大数。
## [br]
## @api public
## [br]
## @param other: 另一个大数实例。
## [br]
## @return 当前值大于 other 返回 1，小于返回 -1，相等返回 0。
func compare_to(other: GFBigNumber) -> int:
	if other == null:
		return 1

	if is_zero() and other.is_zero():
		return 0

	var self_sign: int = _get_sign(mantissa)
	var other_sign: int = _get_sign(other.mantissa)
	if self_sign != other_sign:
		return 1 if self_sign > other_sign else -1

	if exponent != other.exponent:
		if self_sign > 0:
			return 1 if exponent > other.exponent else -1
		return -1 if exponent > other.exponent else 1

	if is_equal_approx(mantissa, other.mantissa):
		return 0

	return 1 if mantissa > other.mantissa else -1


## 与另一个大数相加。
## [br]
## @api public
## [br]
## @param other: 另一个大数实例。
## [br]
## @return 相加结果。
func add(other: GFBigNumber) -> GFBigNumber:
	if other == null or other.is_zero():
		return clone()

	if is_zero():
		return other.clone()

	var exponent_diff: int = exponent - other.exponent
	if exponent_diff >= _ADDITION_DROP_THRESHOLD:
		return clone()

	if exponent_diff <= -_ADDITION_DROP_THRESHOLD:
		return other.clone()

	if exponent_diff >= 0:
		return GFBigNumber.new(
			mantissa + other.mantissa / pow(10.0, exponent_diff),
			exponent
		)

	return GFBigNumber.new(
		mantissa / pow(10.0, -exponent_diff) + other.mantissa,
		other.exponent
	)


## 与另一个大数相减。
## [br]
## @api public
## [br]
## @param other: 另一个大数实例。
## [br]
## @return 相减结果。
func subtract(other: GFBigNumber) -> GFBigNumber:
	if other == null:
		return clone()

	return add(other.negated())


## 与另一个大数相乘。
## [br]
## @api public
## [br]
## @param other: 另一个大数实例。
## [br]
## @return 相乘结果。
func multiply(other: GFBigNumber) -> GFBigNumber:
	if other == null:
		return clone()

	if is_zero() or other.is_zero():
		return GFBigNumber.zero()

	var exponent_result: Dictionary = _try_add_exponents(exponent, other.exponent)
	if not GFVariantData.get_option_bool(exponent_result, &"ok", false):
		push_error("[GFBigNumber] 指数超出支持范围。")
		return GFBigNumber.zero()

	return GFBigNumber.new(mantissa * other.mantissa, GFVariantData.get_option_int(exponent_result, &"value"))


## 与另一个大数相除。
## [br]
## @api public
## [br]
## @param other: 另一个大数实例。
## [br]
## @return 相除结果。
func divide(other: GFBigNumber) -> GFBigNumber:
	if other == null or other.is_zero():
		push_error("[GFBigNumber] 尝试除以空值或零值。")
		return GFBigNumber.zero()

	if is_zero():
		return GFBigNumber.zero()

	var exponent_result: Dictionary = _try_add_exponents(exponent, -other.exponent)
	if not GFVariantData.get_option_bool(exponent_result, &"ok", false):
		push_error("[GFBigNumber] 指数超出支持范围。")
		return GFBigNumber.zero()

	return GFBigNumber.new(mantissa / other.mantissa, GFVariantData.get_option_int(exponent_result, &"value"))


## 将当前大数提升到整数次幂。
## [br]
## @api public
## [br]
## @param power: 幂指数。
## [br]
## @return 幂运算结果。
func powi(power: int) -> GFBigNumber:
	return powf(float(power))


## 将当前大数提升到浮点次幂。
## [br]
## @api public
## [br]
## @param power: 幂指数。
## [br]
## @return 幂运算结果。
func powf(power: float) -> GFBigNumber:
	if is_nan(power) or is_inf(power):
		push_error("[GFBigNumber] powf 收到非法指数。")
		return GFBigNumber.zero()

	if is_zero():
		if power < 0.0:
			push_error("[GFBigNumber] 零值不能提升到负幂。")
			return GFBigNumber.zero()

		if is_equal_approx(power, 0.0):
			return GFBigNumber.one()

		return GFBigNumber.zero()

	var integer_power: float = round(power)
	var is_integer_power: bool = is_equal_approx(power, integer_power)
	if is_negative() and not is_integer_power:
		push_error("[GFBigNumber] 负数不能执行非整数次幂。")
		return GFBigNumber.zero()

	var sign_multiplier: float = 1.0
	if is_negative() and int(integer_power) % 2 != 0:
		sign_multiplier = -1.0

	var abs_mantissa: float = absf(mantissa)
	var power_log10: float = (log(abs_mantissa) / log(10.0) + float(exponent)) * power
	if is_nan(power_log10) or is_inf(power_log10):
		push_error("[GFBigNumber] 指数超出支持范围。")
		return GFBigNumber.zero()

	var power_log10_floor: float = floor(power_log10)
	if power_log10_floor < -float(_MAX_EXPONENT_MAGNITUDE) or power_log10_floor > float(_MAX_EXPONENT_MAGNITUDE):
		push_error("[GFBigNumber] 指数超出支持范围。")
		return GFBigNumber.zero()

	var power_exponent: int = int(power_log10_floor)
	var power_mantissa: float = pow(10.0, power_log10 - power_exponent) * sign_multiplier
	return GFBigNumber.new(power_mantissa, power_exponent)


## 将当前值转换为 float。
## [br]
## @api public
## [br]
## @return 可表达时返回浮点值，超出范围时返回 +/-INF。
func to_float() -> float:
	if is_zero():
		return 0.0

	return mantissa * pow(10.0, exponent)


## 在量级适中时输出普通十进制字符串，过大时会回退到科学计数法。
## [br]
## @api public
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @return 普通字符串表示。
func to_plain_string(decimal_places: int = _DEFAULT_PLAIN_DECIMALS, trim_zeroes: bool = true) -> String:
	if is_zero():
		return "0"

	if exponent > 15 or exponent < -decimal_places - 1:
		return to_scientific_string(decimal_places, trim_zeroes)

	return _DECIMAL_STRING_FORMATTER.format_decimal_value(to_float(), decimal_places, trim_zeroes, false)


## 输出科学计数法字符串。
## [br]
## @api public
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @param use_truncation: 是否使用截断而不是四舍五入。
## [br]
## @return 科学计数法字符串。
func to_scientific_string(
	decimal_places: int = 2,
	trim_zeroes: bool = true,
	use_truncation: bool = false
) -> String:
	if is_zero():
		return "0"

	var output_mantissa: float = mantissa
	var output_exponent: int = exponent
	var mantissa_text: String = _DECIMAL_STRING_FORMATTER.format_decimal_value(output_mantissa, decimal_places, trim_zeroes, use_truncation)
	if absf(mantissa_text.to_float()) >= 10.0:
		if not _exponent_is_supported(output_exponent + 1):
			push_error("[GFBigNumber] 指数超出支持范围。")
			return "0"

		output_mantissa /= 10.0
		output_exponent += 1
		mantissa_text = _DECIMAL_STRING_FORMATTER.format_decimal_value(output_mantissa, decimal_places, trim_zeroes, use_truncation)

	return "%se%d" % [mantissa_text, output_exponent]


# --- 私有/辅助方法 ---

func _normalize() -> void:
	if is_nan(mantissa) or is_inf(mantissa):
		push_error("[GFBigNumber] mantissa 必须是有限浮点值。")
		mantissa = 0.0
		exponent = 0
		return

	if absf(mantissa) <= _NORMALIZATION_EPSILON:
		mantissa = 0.0
		exponent = 0
		return

	var abs_mantissa: float = absf(mantissa)
	var shift_floor: float = floor(log(abs_mantissa) / log(10.0))
	var shift: int = int(shift_floor)
	mantissa /= pow(10.0, shift)
	exponent += shift

	while absf(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1

	while absf(mantissa) < 1.0 and absf(mantissa) > _NORMALIZATION_EPSILON:
		mantissa *= 10.0
		exponent -= 1

	if absf(mantissa) <= _NORMALIZATION_EPSILON:
		mantissa = 0.0
		exponent = 0

	if not _exponent_is_supported(exponent):
		push_error("[GFBigNumber] 指数超出支持范围。")
		mantissa = 0.0
		exponent = 0


static func _get_sign(value: float) -> int:
	if value > 0.0:
		return 1

	if value < 0.0:
		return -1

	return 0


static func _try_parse_exponent_text(text: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return _make_parse_error()

	var digits: String = trimmed
	var negative: bool = false
	if digits.begins_with("-") or digits.begins_with("+"):
		negative = digits.begins_with("-")
		digits = digits.substr(1)

	if digits.is_empty():
		return _make_parse_error()

	for index: int in range(digits.length()):
		var character: String = digits.substr(index, 1)
		if character < "0" or character > "9":
			return _make_parse_error()

	var significant_digits: String = digits
	while significant_digits.length() > 1 and significant_digits.begins_with("0"):
		significant_digits = significant_digits.substr(1)

	var limit_text: String = str(_MAX_EXPONENT_MAGNITUDE)
	if significant_digits.length() > limit_text.length():
		return _make_parse_error("range")
	if significant_digits.length() == limit_text.length() and significant_digits > limit_text:
		return _make_parse_error("range")

	var value: int = significant_digits.to_int()
	if negative:
		value = -value
	return {
		&"ok": true,
		&"value": value,
	}


static func _try_add_exponents(left: int, right: int) -> Dictionary:
	var result: int = left + right
	if not _exponent_is_supported(result):
		return _make_parse_error()
	return {
		&"ok": true,
		&"value": result,
	}


static func _exponent_is_supported(value: int) -> bool:
	return value >= -_MAX_EXPONENT_MAGNITUDE and value <= _MAX_EXPONENT_MAGNITUDE


static func _make_parse_error(reason: String = "") -> Dictionary:
	return {
		&"ok": false,
		&"reason": reason,
	}
