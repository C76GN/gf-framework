## GFFixedDecimal: 基于整数缩放的定点小数值对象。
##
## 适合处理货币、税率、经营数值等对“累计误差”敏感、
## 但又不需要无限精度十进制库的场景。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFFixedDecimal
extends RefCounted


# --- 枚举 ---

## 缩放或除法时使用的舍入策略。
## [br]
## @api public
enum RoundingMode {
	## 四舍五入，0.5 始终朝绝对值更大的方向进位。
	HALF_UP,
	## 银行家舍入，0.5 时向最近的偶数靠拢。
	HALF_EVEN,
	## 向负无穷方向取整。
	FLOOR,
	## 向正无穷方向取整。
	CEIL,
	## 直接截断，朝 0 逼近。
	TRUNCATE,
}


# --- 常量 ---

## 定点数可保留的小数位上限，避免整数缩放时溢出。
## [br]
## @api public
const MAX_DECIMAL_PLACES: int = 18

## GFBigNumber 脚本资源，用于把格式化后的十进制文本转换为大数对象。
## [br]
## @api private
const _BIG_NUMBER_SCRIPT: Script = preload("res://addons/gf/standard/foundation/numeric/gf_big_number.gd")

## 本类使用的数值文本正规化与小数部分验证器。
## [br]
## @api private
const _DECIMAL_STRING_FORMATTER = preload("res://addons/gf/standard/foundation/formatting/gf_decimal_string_formatter.gd")

## 承担定点数序列化与边界规范化实现的脚本资源。
## [br]
## @api private
const _SERIALIZATION_SUPPORT: Script = preload("res://addons/gf/standard/foundation/numeric/gf_fixed_numeric_serialization_support.gd")

## 固定字节格式要求的完整字节数。
## [br]
## @api private
const _BYTE_FORMAT_SIZE: int = 15

## GFFD 字节头的第 1 个 ASCII 字节。
## [br]
## @api private
const _BYTE_MAGIC_0: int = 71

## GFFD 字节头的第 2 个 ASCII 字节。
## [br]
## @api private
const _BYTE_MAGIC_1: int = 70

## GFFD 字节头的第 3 个 ASCII 字节。
## [br]
## @api private
const _BYTE_MAGIC_2: int = 70

## GFFD 字节头的第 4 个 ASCII 字节。
## [br]
## @api private
const _BYTE_MAGIC_3: int = 68

## 固定字节格式中有符号幅值数据的起始偏移。
## [br]
## @api private
const _BYTE_MAGNITUDE_OFFSET: int = 7

## 状态字典中的定点数类型标识。
## [br]
## @api private
const _SERIALIZATION_TYPE: String = "gf.fixed_decimal"

## 状态字典与固定字节格式当前使用的版本号。
## [br]
## @api private
const _SERIALIZATION_VERSION: int = 1

## 定点数采用对称正负范围时的最大幅值。
## [br]
## @api private
const _MAX_INT_VALUE: int = 9_223_372_036_854_775_807

## 有符号幅值解码失败时使用的 int64 最小值哨兵。
## [br]
## @api private
const _INVALID_SIGNED_MAGNITUDE: int = -9_223_372_036_854_775_807 - 1


# --- 公共变量 ---

## 实际保存的整数值。
## [br]
## @api public
## [br]
## @since 3.17.0
var raw_value: int = 0:
	set(value):
		raw_value = _normalize_raw_value(value, "raw_value")

## 小数位数。
## [br]
## @api public
## [br]
## @since 3.17.0
var decimal_places: int = 2:
	set(value):
		decimal_places = _normalize_decimal_places(value)


# --- Godot 生命周期方法 ---

func _init(p_raw_value: int = 0, p_decimal_places: int = 2) -> void:
	raw_value = _normalize_raw_value(p_raw_value, "init")
	decimal_places = _normalize_decimal_places(p_decimal_places)


# --- 公共方法 ---

## 从 int 构建定点数。
## [br]
## @api public
## [br]
## @param value: 原始整数。
## [br]
## @param p_decimal_places: 目标小数位。
## [br]
## @return 定点数实例。
static func from_int(value: int, p_decimal_places: int = 2) -> GFFixedDecimal:
	var places: int = _normalize_decimal_places(p_decimal_places)
	return GFFixedDecimal.new(
		_checked_multiply(value, _pow10_int(places), "from_int"),
		places
	)


## 从 float 构建定点数。
## [br]
## @api public
## [br]
## @param value: 原始浮点数。
## [br]
## @param p_decimal_places: 目标小数位。
## [br]
## @param rounding_mode: 舍入策略。
## [br]
## @return 定点数实例。
static func from_float(
	value: float,
	p_decimal_places: int = 2,
	rounding_mode: RoundingMode = RoundingMode.HALF_UP
) -> GFFixedDecimal:
	var places: int = _normalize_decimal_places(p_decimal_places)
	if is_nan(value) or is_inf(value):
		push_error("[GFFixedDecimal][fixed_decimal.float_invalid] from_float received an invalid floating-point value.")
		return GFFixedDecimal.new(0, places)

	var scaled_value: float = value * _pow10_float(places)
	if is_nan(scaled_value) or is_inf(scaled_value) or absf(scaled_value) >= float(_MAX_INT_VALUE):
		push_error("[GFFixedDecimal][fixed_decimal.scaled_float_out_of_range] The scaled from_float value exceeds the representable range.")
		return GFFixedDecimal.new(0, places)

	var rounded: int = _round_scaled_float(scaled_value, rounding_mode)
	return GFFixedDecimal.new(rounded, places)


## 从字符串构建定点数。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param value: 普通十进制字符串；科学计数法会作为 float 兼容路径解析，不适合作为严格十进制导入源。
## [br]
## @param p_decimal_places: 目标小数位。
## [br]
## @param rounding_mode: 舍入策略。
## [br]
## @param max_input_length: 最大输入字符数；小于等于 0 时使用框架默认预算。
## [br]
## @return 定点数实例。
static func from_string(
	value: String,
	p_decimal_places: int = 2,
	rounding_mode: RoundingMode = RoundingMode.HALF_UP,
	max_input_length: int = GFDecimalStringFormatter.DEFAULT_MAX_NUMERIC_TEXT_LENGTH
) -> GFFixedDecimal:
	var places: int = _normalize_decimal_places(p_decimal_places)
	var normalization: Dictionary = _DECIMAL_STRING_FORMATTER.normalize_numeric_text(value, max_input_length)
	if not GFVariantData.get_option_bool(normalization, "ok"):
		push_error("[GFFixedDecimal][fixed_decimal.number_parse_failed_with_reason] Cannot parse the number string (%s): %s." % [
			GFVariantData.get_option_string(normalization, "error", "invalid_input"),
			value.left(128),
		])
		return GFFixedDecimal.new(0, places)
	var trimmed: String = GFVariantData.get_option_string(normalization, "text")

	if trimmed.find("e") != -1 or trimmed.find("E") != -1:
		if not trimmed.is_valid_float():
			push_error("[GFFixedDecimal][fixed_decimal.number_parse_failed] Cannot parse the number string: %s." % value)
			return GFFixedDecimal.new(0, places)
		return GFFixedDecimal.from_float(trimmed.to_float(), places, rounding_mode)

	var sign_multiplier: int = 1
	if trimmed.begins_with("-"):
		sign_multiplier = -1
		trimmed = trimmed.substr(1)
	elif trimmed.begins_with("+"):
		trimmed = trimmed.substr(1)

	var decimal_index: int = trimmed.find(".")
	var integer_part: String = trimmed
	var fractional_part: String = ""
	if decimal_index != -1:
		integer_part = trimmed.substr(0, decimal_index)
		fractional_part = trimmed.substr(decimal_index + 1)

	if not _decimal_parts_are_valid(integer_part, fractional_part, decimal_index != -1):
		push_error("[GFFixedDecimal][fixed_decimal.number_parse_failed] Cannot parse the number string: %s." % value)
		return GFFixedDecimal.new(0, places)

	return GFFixedDecimal.new(
		_parse_decimal_to_raw(integer_part, fractional_part, sign_multiplier, places, rounding_mode),
		places
	)


## 从状态字典恢复定点数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `type`, `version`, `raw_value`, and `decimal_places` fields.
## [br]
## @return 定点数实例。
static func from_dict(data: Dictionary) -> GFFixedDecimal:
	var value: GFFixedDecimal = GFFixedDecimal.new()
	var _applied: bool = value.apply_dict(data)
	return value


## 从固定字节序列恢复定点数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_bytes()` 输出的字节序列。
## [br]
## @return 定点数实例。
static func from_bytes(data: PackedByteArray) -> GFFixedDecimal:
	var value: GFFixedDecimal = GFFixedDecimal.new()
	var _applied: bool = value.apply_bytes(data)
	return value


## 克隆当前定点数。
## [br]
## @api public
## [br]
## @return 内容相同的新实例。
func clone() -> GFFixedDecimal:
	return GFFixedDecimal.new(raw_value, decimal_places)


## 当前值是否为零。
## [br]
## @api public
## [br]
## @return 为零时返回 true。
func is_zero() -> bool:
	return raw_value == 0


## 获取绝对值。
## [br]
## @api public
## [br]
## @return 新的定点数实例。
func abs_value() -> GFFixedDecimal:
	return GFFixedDecimal.new(_abs_int(raw_value), decimal_places)


## 获取相反数。
## [br]
## @api public
## [br]
## @return 新的定点数实例。
func negated() -> GFFixedDecimal:
	return GFFixedDecimal.new(_checked_multiply(raw_value, -1, "negated"), decimal_places)


## 重设小数位数。
## [br]
## @api public
## [br]
## @param target_decimal_places: 目标小数位数。
## [br]
## @param rounding_mode: 降位时的舍入策略。
## [br]
## @return 重设后的定点数实例。
func rescaled(
	target_decimal_places: int,
	rounding_mode: RoundingMode = RoundingMode.HALF_UP
) -> GFFixedDecimal:
	var target_places: int = _normalize_decimal_places(target_decimal_places)
	if target_places == decimal_places:
		return clone()

	return GFFixedDecimal.new(
		_rescale_raw(raw_value, decimal_places, target_places, rounding_mode),
		target_places
	)


## 与另一个定点数比较大小。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param other: 另一个定点数。
## [br]
## @return: 大于返回 1，小于返回 -1，相等返回 0；跨小数位比较不会先把 raw 值饱和对齐。
func compare_to(other: GFFixedDecimal) -> int:
	if other == null:
		return 1

	return _compare_scaled_raw_values(
		raw_value,
		decimal_places,
		other.raw_value,
		other.decimal_places
	)


## 与另一个定点数相加。
## [br]
## @api public
## [br]
## @param other: 另一个定点数。
## [br]
## @return 相加结果。
func add(other: GFFixedDecimal) -> GFFixedDecimal:
	if other == null:
		return clone()

	var target_places: int = maxi(decimal_places, other.decimal_places)
	if decimal_places == other.decimal_places:
		return GFFixedDecimal.new(_checked_add(raw_value, other.raw_value, "add"), target_places)
	var left_digits: String = str(_abs_int(raw_value)) + _repeat_character("0", target_places - decimal_places)
	var right_digits: String = str(_abs_int(other.raw_value)) + _repeat_character("0", target_places - other.decimal_places)
	var negative: bool = raw_value < 0
	var result_digits: String = ""
	if negative == (other.raw_value < 0):
		result_digits = _add_decimal_strings(left_digits, right_digits)
	elif _compare_decimal_strings(left_digits, right_digits) >= 0:
		result_digits = _subtract_decimal_strings(left_digits, right_digits)
	else:
		result_digits = _subtract_decimal_strings(right_digits, left_digits)
		negative = other.raw_value < 0
	return GFFixedDecimal.new(_decimal_string_to_int_saturated(result_digits, negative, "add"), target_places)


## 与另一个定点数相减。
## [br]
## @api public
## [br]
## @param other: 另一个定点数。
## [br]
## @return 相减结果。
func subtract(other: GFFixedDecimal) -> GFFixedDecimal:
	if other == null:
		return clone()

	return add(other.negated())


## 与另一个定点数相乘。
## [br]
## @api public
## [br]
## @param other: 另一个定点数。
## [br]
## @param target_decimal_places: 结果小数位；传 -1 时取两者较大值。
## [br]
## @param rounding_mode: 结果降位时的舍入策略。
## [br]
## @return 相乘结果。
func multiply(
	other: GFFixedDecimal,
	target_decimal_places: int = -1,
	rounding_mode: RoundingMode = RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if other == null:
		return clone()

	var product_places: int = decimal_places + other.decimal_places
	var result_places: int = target_decimal_places
	if result_places < 0:
		result_places = maxi(decimal_places, other.decimal_places)
	else:
		result_places = _normalize_decimal_places(result_places)

	return GFFixedDecimal.new(
		_multiply_rescaled_raw(raw_value, other.raw_value, product_places - result_places, rounding_mode),
		result_places
	)


## 与另一个定点数相除。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param other: 另一个定点数。
## [br]
## @param target_decimal_places: 结果小数位；传 -1 时取两者较大值。
## [br]
## @param rounding_mode: 除法舍入策略。
## [br]
## @return: 相除结果；中间缩放使用可容纳精确值的路径，舍入与钳制只作用于最终 raw。
func divide(
	other: GFFixedDecimal,
	target_decimal_places: int = -1,
	rounding_mode: RoundingMode = RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if other == null or other.raw_value == 0:
		push_error("[GFFixedDecimal][fixed_decimal.divisor_null_or_zero] Cannot divide by a null or zero value.")
		var fallback_places: int = decimal_places if target_decimal_places < 0 else _normalize_decimal_places(target_decimal_places)
		return GFFixedDecimal.new(0, fallback_places)

	var result_places: int = target_decimal_places
	if result_places < 0:
		result_places = maxi(decimal_places, other.decimal_places)
	else:
		result_places = _normalize_decimal_places(result_places)

	var shift: int = result_places + other.decimal_places - decimal_places
	var numerator: int = raw_value
	var denominator: int = other.raw_value
	if shift > MAX_DECIMAL_PLACES:
		var scaled_raw: int = _divide_with_decimal_strings(numerator, denominator, shift, rounding_mode)
		return GFFixedDecimal.new(scaled_raw, result_places)
	if shift >= 0:
		var numerator_scale: int = _pow10_int(shift)
		if not _multiplication_fits(numerator, numerator_scale):
			var scaled_raw: int = _divide_with_decimal_strings(
				numerator,
				denominator,
				shift,
				rounding_mode
			)
			return GFFixedDecimal.new(scaled_raw, result_places)
		numerator *= numerator_scale
	else:
		var denominator_scale: int = _pow10_int(-shift)
		if not _multiplication_fits(denominator, denominator_scale):
			var scaled_raw: int = _divide_with_decimal_strings(
				numerator,
				denominator,
				shift,
				rounding_mode
			)
			return GFFixedDecimal.new(scaled_raw, result_places)
		denominator *= denominator_scale

	var divided_raw: int = _divide_with_rounding(numerator, denominator, rounding_mode)
	return GFFixedDecimal.new(divided_raw, result_places)


## 转换为 float。
## [br]
## @api public
## [br]
## @return 浮点值。
func to_float() -> float:
	return float(raw_value) / _pow10_float(decimal_places)


## 转换为 GFBigNumber。
## [br]
## @api public
## [br]
## @return 对应的大数值对象。
func to_big_number() -> GFBigNumber:
	return _make_big_number_from_string(to_decimal_string(false))


## 转换为普通字符串。
## [br]
## @api public
## [br]
## @param trim_zeroes: 是否裁掉尾部 0。
## [br]
## @return 十进制字符串。
func to_decimal_string(trim_zeroes: bool = false) -> String:
	if decimal_places == 0:
		return str(raw_value)

	var sign_text: String = ""
	var abs_raw: int = raw_value
	if raw_value < 0:
		sign_text = "-"
		abs_raw = _abs_int(raw_value)

	var scale: int = _pow10_int(decimal_places)
	var integer_part: int = _divide_truncated(abs_raw, scale)
	var fractional_part: int = abs_raw % scale
	var fractional_text: String = _left_pad(str(fractional_part), decimal_places, "0")
	if trim_zeroes:
		while fractional_text.ends_with("0"):
			fractional_text = fractional_text.left(fractional_text.length() - 1)

	if fractional_text.is_empty():
		return sign_text + str(integer_part)

	return sign_text + str(integer_part) + "." + fractional_text


## 导出 JSON 安全的状态字典。
## `raw_value` 固定写为十进制字符串，避免 JSON 64 位整数精度丢失。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 可稳定恢复定点数的状态字典。
## [br]
## @schema return: Dictionary with `type: String`, `version: int`, `raw_value: String`, and `decimal_places: int`.
func to_dict() -> Dictionary:
	var serialized_raw: int = _normalize_raw_value(raw_value, "to_dict")
	var serialized_places: int = _normalize_decimal_places(decimal_places)
	return {
		"type": _SERIALIZATION_TYPE,
		"version": _SERIALIZATION_VERSION,
		"raw_value": str(serialized_raw),
		"decimal_places": serialized_places,
	}


## 应用 JSON 安全状态字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `type`, `version`, `raw_value`, and `decimal_places` fields.
## [br]
## @return 状态有效并已应用时返回 true。
func apply_dict(data: Dictionary) -> bool:
	var type_name: String = GFVariantData.get_option_string(data, "type")
	var version: int = GFVariantData.get_option_int(data, "version")
	var raw_data: Variant = GFVariantData.get_option_value(data, "raw_value")
	var places: int = GFVariantData.get_option_int(data, "decimal_places", -1)
	if (
		type_name != _SERIALIZATION_TYPE
		or version != _SERIALIZATION_VERSION
		or not _state_value_is_int(raw_data)
		or not _decimal_places_are_in_serialized_range(places)
	):
		push_error("[GFFixedDecimal][fixed_decimal.state_format_unsupported] Unsupported state dictionary format.")
		_reset_serialized_zero()
		return false

	raw_value = _state_value_to_int(raw_data)
	decimal_places = places
	return true


## 导出固定二进制序列。
## 格式为 `GFFD` magic、版本、小数位、符号位和 8 字节大端绝对 raw 值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 可稳定恢复定点数的字节序列。
func to_bytes() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var _magic_0: bool = result.append(_BYTE_MAGIC_0)
	var _magic_1: bool = result.append(_BYTE_MAGIC_1)
	var _magic_2: bool = result.append(_BYTE_MAGIC_2)
	var _magic_3: bool = result.append(_BYTE_MAGIC_3)
	var _version_appended: bool = result.append(_SERIALIZATION_VERSION)
	var _places_appended: bool = result.append(_normalize_decimal_places(decimal_places))
	result = _append_signed_magnitude(result, raw_value, "GFFixedDecimal", "to_bytes")
	return result


## 应用固定二进制序列。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_bytes()` 输出的字节序列。
## [br]
## @return 字节序列有效并已应用时返回 true。
func apply_bytes(data: PackedByteArray) -> bool:
	if not _bytes_have_supported_header(data):
		push_error("[GFFixedDecimal][fixed_decimal.byte_format_unsupported] Unsupported byte sequence format.")
		_reset_serialized_zero()
		return false

	var signed_value: int = _read_signed_magnitude(data, 6, _BYTE_MAGNITUDE_OFFSET)
	if _signed_magnitude_is_invalid(signed_value):
		push_error("[GFFixedDecimal][fixed_decimal.byte_format_unsupported] Unsupported byte sequence format.")
		_reset_serialized_zero()
		return false

	raw_value = signed_value
	decimal_places = data[5]
	return true


# --- 私有/辅助方法 ---

## 按方法名和参数数组调用序列化支持脚本中的实现。
## [br]
## @api private
static func _call_serialization_support(method_name: StringName, arguments: Array) -> Variant:
	return _SERIALIZATION_SUPPORT.callv(method_name, arguments)


## 调用序列化支持方法，并在结果不是 bool 时返回 false。
## [br]
## @api private
static func _call_serialization_support_bool(method_name: StringName, arguments: Array) -> bool:
	var raw_result: Variant = _call_serialization_support(method_name, arguments)
	if raw_result is bool:
		var bool_result: bool = raw_result
		return bool_result
	return false


## 调用序列化支持方法，并在结果不是 int 时返回指定回退值。
## [br]
## @api private
static func _call_serialization_support_int(
	method_name: StringName,
	arguments: Array,
	fallback: int = 0
) -> int:
	var raw_result: Variant = _call_serialization_support(method_name, arguments)
	if raw_result is int:
		var int_result: int = raw_result
		return int_result
	return fallback


## 委托序列化支持脚本将有符号值追加到目标字节数组并返回该数组。
## [br]
## @api private
static func _append_signed_magnitude(
	target: PackedByteArray,
	value: int,
	owner_name: String,
	context: String
) -> PackedByteArray:
	var result: PackedByteArray = target
	var _ignored: Variant = _call_serialization_support(
		&"append_signed_magnitude",
		[result, value, owner_name, context]
	)
	return result


## 从固定字节数据读取有符号幅值；结果类型不符时返回无效哨兵。
## [br]
## @api private
static func _read_signed_magnitude(
	data: PackedByteArray,
	sign_offset: int,
	magnitude_offset: int
) -> int:
	return _call_serialization_support_int(
		&"read_signed_magnitude",
		[data, sign_offset, magnitude_offset],
		_INVALID_SIGNED_MAGNITUDE
	)


## 通过序列化支持脚本判断解码值是否等于无效哨兵。
## [br]
## @api private
static func _signed_magnitude_is_invalid(value: int) -> bool:
	return _call_serialization_support_bool(&"signed_magnitude_is_invalid", [value])


## 调用 GFBigNumber 的 from_string；脚本调用未返回该类型时回退到零值。
## [br]
## @api private
static func _make_big_number_from_string(value: String) -> GFBigNumber:
	var result: Variant = _BIG_NUMBER_SCRIPT.call(&"from_string", value)
	if result is GFBigNumber:
		return result
	return GFBigNumber.zero()


## 把整数、小数文本及小数点是否存在交给共享格式器验证。
## [br]
## @api private
static func _decimal_parts_are_valid(
	integer_part: String,
	fractional_part: String,
	has_decimal_point: bool
) -> bool:
	return _DECIMAL_STRING_FORMATTER.is_valid_decimal_parts(
		integer_part,
		fractional_part,
		has_decimal_point
	)


## 将一个字符串追加到 PackedStringArray。
## [br]
## @api private
static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


## 对齐小数位后比较两个 raw 整数值，并返回 -1、0 或 1。
## 使用十进制字符串扩位，避免先把对齐结果乘进 int。
## [br]
## @api private
static func _compare_scaled_raw_values(
	left_raw: int,
	left_places: int,
	right_raw: int,
	right_places: int
) -> int:
	var left_negative: bool = left_raw < 0
	var right_negative: bool = right_raw < 0
	if left_negative != right_negative:
		return -1 if left_negative else 1

	var target_places: int = maxi(left_places, right_places)
	var left_digits: String = (
		str(_abs_int(left_raw))
		+ _repeat_character("0", target_places - left_places)
	)
	var right_digits: String = (
		str(_abs_int(right_raw))
		+ _repeat_character("0", target_places - right_places)
	)
	var magnitude_compare: int = _compare_decimal_strings(left_digits, right_digits)
	return -magnitude_compare if left_negative else magnitude_compare


## 按目标小数位重缩放 raw 值；升位时检查乘法边界，降位时应用指定舍入。
## [br]
## @api private
static func _rescale_raw(
	value: int,
	from_places: int,
	to_places: int,
	rounding_mode: RoundingMode
) -> int:
	if to_places == from_places:
		return value

	if to_places > from_places:
		return _checked_multiply(value, _pow10_int(to_places - from_places), "rescaled")

	var divisor: int = _pow10_int(from_places - to_places)
	return _divide_with_rounding(value, divisor, rounding_mode)


## 对整数分子与分母求商，并依舍入模式处理余数和符号。
## 分母为零时记录错误并返回 0。
## [br]
## @api private
static func _divide_with_rounding(
	numerator: int,
	denominator: int,
	rounding_mode: RoundingMode
) -> int:
	if denominator == 0:
		push_error("[GFFixedDecimal][fixed_decimal.division_by_zero] Cannot divide by zero.")
		return 0

	var negative: bool = (numerator < 0) != (denominator < 0)
	var abs_numerator: int = _abs_int(numerator)
	var abs_denominator: int = _abs_int(denominator)
	var quotient: int = _divide_truncated(abs_numerator, abs_denominator)
	var remainder: int = abs_numerator % abs_denominator
	var adjusted: int = quotient

	match rounding_mode:
		RoundingMode.HALF_UP:
			if _compare_twice_remainder(remainder, abs_denominator) >= 0:
				adjusted = _checked_add(adjusted, 1, "divide")
		RoundingMode.HALF_EVEN:
			var half_compare: int = _compare_twice_remainder(remainder, abs_denominator)
			if half_compare > 0:
				adjusted = _checked_add(adjusted, 1, "divide")
			elif half_compare == 0 and quotient % 2 != 0:
				adjusted = _checked_add(adjusted, 1, "divide")
		RoundingMode.FLOOR:
			if negative and remainder != 0:
				adjusted = _checked_add(adjusted, 1, "divide")
		RoundingMode.CEIL:
			if not negative and remainder != 0:
				adjusted = _checked_add(adjusted, 1, "divide")
		RoundingMode.TRUNCATE:
			pass

	return -adjusted if negative else adjusted


## 按指定舍入模式把已缩放的浮点值转换为整数。
## [br]
## @api private
static func _round_scaled_float(value: float, rounding_mode: RoundingMode) -> int:
	match rounding_mode:
		RoundingMode.FLOOR:
			var floored_value: float = floor(value)
			return int(floored_value)
		RoundingMode.CEIL:
			var ceiled_value: float = ceil(value)
			return int(ceiled_value)
		RoundingMode.TRUNCATE:
			if value >= 0.0:
				var positive_truncated: float = floor(value)
				return int(positive_truncated)
			var negative_truncated: float = ceil(value)
			return int(negative_truncated)
		RoundingMode.HALF_UP:
			if value >= 0.0:
				var positive_rounded: float = floor(value + 0.5)
				return int(positive_rounded)
			var negative_rounded: float = ceil(value - 0.5)
			return int(negative_rounded)
		RoundingMode.HALF_EVEN:
			var sign_multiplier: int = 1
			var absolute_value: float = value
			if value < 0.0:
				sign_multiplier = -1
				absolute_value = -value

			var integer_part: float = floor(absolute_value)
			var fraction: float = absolute_value - integer_part
			var rounded: int = int(integer_part)
			if fraction > 0.5:
				rounded += 1
			elif is_equal_approx(fraction, 0.5) and rounded % 2 != 0:
				rounded += 1

			return rounded * sign_multiplier

	var fallback_rounded: float = round(value)
	return int(fallback_rounded)


## 以十进制字符串完成带位移的整数除法，再舍入并饱和为 raw 整数。
## 用于原生整数缩放无法容纳中间值的路径。
## [br]
## @api private
static func _divide_with_decimal_strings(
	numerator: int,
	denominator: int,
	shift: int,
	rounding_mode: RoundingMode
) -> int:
	if denominator == 0:
		push_error("[GFFixedDecimal][fixed_decimal.division_by_zero] Cannot divide by zero.")
		return 0

	var negative: bool = (numerator < 0) != (denominator < 0)
	var numerator_digits: String = str(_abs_int(numerator))
	var denominator_digits: String = str(_abs_int(denominator))
	if shift >= 0:
		numerator_digits += _repeat_character("0", shift)
	else:
		denominator_digits += _repeat_character("0", -shift)
	var division: Dictionary = _divide_decimal_strings(numerator_digits, denominator_digits)
	var quotient_text: String = GFVariantData.get_option_string(division, "quotient", "0")
	var remainder_text: String = GFVariantData.get_option_string(division, "remainder", "0")
	var adjusted_text: String = quotient_text
	var has_remainder: bool = remainder_text != "0"

	match rounding_mode:
		RoundingMode.HALF_UP:
			if _compare_decimal_strings(_multiply_decimal_string_by_digit(remainder_text, 2), denominator_digits) >= 0:
				adjusted_text = _add_one_decimal_string(adjusted_text)
		RoundingMode.HALF_EVEN:
			var half_compare: int = _compare_decimal_strings(
				_multiply_decimal_string_by_digit(remainder_text, 2),
				denominator_digits
			)
			if half_compare > 0:
				adjusted_text = _add_one_decimal_string(adjusted_text)
			elif half_compare == 0 and _decimal_string_is_odd(adjusted_text):
				adjusted_text = _add_one_decimal_string(adjusted_text)
		RoundingMode.FLOOR:
			if negative and has_remainder:
				adjusted_text = _add_one_decimal_string(adjusted_text)
		RoundingMode.CEIL:
			if not negative and has_remainder:
				adjusted_text = _add_one_decimal_string(adjusted_text)
		RoundingMode.TRUNCATE:
			pass

	return _decimal_string_to_int_saturated(adjusted_text, negative)


## 以十进制字符串计算 raw 乘积，按 scale_diff 移位或舍入后转回饱和整数。
## [br]
## @api private
static func _multiply_rescaled_raw(
	left_raw: int,
	right_raw: int,
	scale_diff: int,
	rounding_mode: RoundingMode
) -> int:
	var negative: bool = (left_raw < 0) != (right_raw < 0)
	var product_text: String = _multiply_decimal_strings(str(_abs_int(left_raw)), str(_abs_int(right_raw)))
	var adjusted_text: String = product_text
	if scale_diff >= 0:
		adjusted_text = _round_decimal_string_by_power(product_text, scale_diff, negative, rounding_mode)
	else:
		adjusted_text = product_text + _repeat_character("0", -scale_diff)
	return _decimal_string_to_int_saturated(adjusted_text, negative, "multiply")


## 将整数与小数部分转换为目标精度的 raw 值，并按模式处理被丢弃的小数位。
## [br]
## @api private
static func _parse_decimal_to_raw(
	integer_part: String,
	fractional_part: String,
	sign_multiplier: int,
	places: int,
	rounding_mode: RoundingMode
) -> int:
	var integer_digits: String = integer_part
	if integer_digits.is_empty():
		integer_digits = "0"

	var kept_fraction: String = fractional_part
	var discarded_fraction: String = ""
	if kept_fraction.length() > places:
		discarded_fraction = kept_fraction.substr(places)
		kept_fraction = kept_fraction.left(places)
	else:
		kept_fraction += _repeat_character("0", places - kept_fraction.length())

	var parsed_raw: int = _parse_signed_digits(integer_digits + kept_fraction, sign_multiplier)
	if _should_round_discarded(discarded_fraction, _abs_int(parsed_raw), sign_multiplier, rounding_mode):
		parsed_raw = _checked_add(parsed_raw, sign_multiplier, "from_string")
	return parsed_raw


## 根据首个被丢弃数字、后续非零位、保留值奇偶性和符号判断是否进位。
## [br]
## @api private
static func _should_round_discarded(
	discarded: String,
	kept_abs_raw: int,
	sign_multiplier: int,
	rounding_mode: RoundingMode
) -> bool:
	if discarded.is_empty() or not _has_non_zero_digit(discarded):
		return false

	var first_digit: int = discarded.substr(0, 1).to_int()
	match rounding_mode:
		RoundingMode.HALF_UP:
			return first_digit >= 5
		RoundingMode.HALF_EVEN:
			if first_digit > 5:
				return true
			if first_digit < 5:
				return false
			return _has_non_zero_digit(discarded.substr(1)) or kept_abs_raw % 2 != 0
		RoundingMode.FLOOR:
			return sign_multiplier < 0
		RoundingMode.CEIL:
			return sign_multiplier > 0
		RoundingMode.TRUNCATE:
			return false

	return false


## 判断文本中是否至少含有一个非零数字字符。
## [br]
## @api private
static func _has_non_zero_digit(text: String) -> bool:
	for i: int in range(text.length()):
		if text.substr(i, 1) != "0":
			return true
	return false


## 用逐位长除法计算非负十进制数字串的商与余数。
## 分母为零时返回字符串形式的零商和零余数。
## [br]
## @api private
static func _divide_decimal_strings(numerator_digits: String, denominator_digits: String) -> Dictionary:
	var numerator_text: String = _normalize_decimal_string(numerator_digits)
	var denominator_text: String = _normalize_decimal_string(denominator_digits)
	if denominator_text == "0":
		return {
			"quotient": "0",
			"remainder": "0",
		}

	var quotient_parts: PackedStringArray = PackedStringArray()
	var remainder: String = "0"
	for i: int in range(numerator_text.length()):
		remainder = _normalize_decimal_string(remainder + numerator_text.substr(i, 1))
		var quotient_digit: int = 0
		for candidate: int in range(9, -1, -1):
			var product: String = _multiply_decimal_string_by_digit(denominator_text, candidate)
			if _compare_decimal_strings(product, remainder) <= 0:
				quotient_digit = candidate
				remainder = _subtract_decimal_strings(remainder, product)
				break
		_append_packed_string(quotient_parts, str(quotient_digit))

	return {
		"quotient": _normalize_decimal_string("".join(quotient_parts)),
		"remainder": _normalize_decimal_string(remainder),
	}


## 去除十进制数字串的多余前导零，并把空文本规范为 "0"。
## [br]
## @api private
static func _normalize_decimal_string(text: String) -> String:
	var result: String = text
	while result.length() > 1 and result.begins_with("0"):
		result = result.substr(1)
	if result.is_empty():
		return "0"
	return result


## 通过逐位乘法和部分积相加计算两个非负十进制数字串的乘积。
## [br]
## @api private
static func _multiply_decimal_strings(left: String, right: String) -> String:
	var normalized_left: String = _normalize_decimal_string(left)
	var normalized_right: String = _normalize_decimal_string(right)
	if normalized_left == "0" or normalized_right == "0":
		return "0"

	var result: String = "0"
	var zero_suffix: String = ""
	for index: int in range(normalized_right.length() - 1, -1, -1):
		var digit: int = normalized_right.substr(index, 1).to_int()
		var partial: String = _multiply_decimal_string_by_digit(normalized_left, digit)
		if partial != "0":
			partial += zero_suffix
		result = _add_decimal_strings(result, partial)
		zero_suffix += "0"
	return _normalize_decimal_string(result)


## 从最低位开始相加两个非负十进制数字串，并传播进位。
## [br]
## @api private
static func _add_decimal_strings(left: String, right: String) -> String:
	var left_text: String = _normalize_decimal_string(left)
	var right_text: String = _normalize_decimal_string(right)
	var result_parts: PackedStringArray = PackedStringArray()
	var carry: int = 0
	var left_index: int = left_text.length() - 1
	var right_index: int = right_text.length() - 1
	while left_index >= 0 or right_index >= 0 or carry > 0:
		var digit_sum: int = carry
		if left_index >= 0:
			digit_sum += left_text.substr(left_index, 1).to_int()
		if right_index >= 0:
			digit_sum += right_text.substr(right_index, 1).to_int()
		_append_packed_string(result_parts, str(digit_sum % 10))
		carry = _divide_truncated(digit_sum, 10)
		left_index -= 1
		right_index -= 1
	result_parts.reverse()
	return _normalize_decimal_string("".join(result_parts))


## 按十进制位数拆分商与余数，并按舍入模式决定是否给商加一。
## [br]
## @api private
static func _round_decimal_string_by_power(
	value: String,
	scale_diff: int,
	negative: bool,
	rounding_mode: RoundingMode
) -> String:
	if scale_diff <= 0:
		return value

	var normalized_value: String = _normalize_decimal_string(value)
	var quotient: String = "0"
	var remainder: String = normalized_value
	if normalized_value.length() > scale_diff:
		quotient = normalized_value.left(normalized_value.length() - scale_diff)
		remainder = normalized_value.substr(normalized_value.length() - scale_diff)
	else:
		remainder = _repeat_character("0", scale_diff - normalized_value.length()) + normalized_value

	if _should_round_decimal_remainder(remainder, quotient, negative, rounding_mode):
		return _add_one_decimal_string(quotient)
	return _normalize_decimal_string(quotient)


## 依据余数文本、商的奇偶性、结果符号和舍入模式判断是否进位。
## [br]
## @api private
static func _should_round_decimal_remainder(
	remainder: String,
	quotient: String,
	negative: bool,
	rounding_mode: RoundingMode
) -> bool:
	if remainder.is_empty() or not _has_non_zero_digit(remainder):
		return false

	var first_digit: int = remainder.substr(0, 1).to_int()
	match rounding_mode:
		RoundingMode.HALF_UP:
			return first_digit >= 5
		RoundingMode.HALF_EVEN:
			if first_digit > 5:
				return true
			if first_digit < 5:
				return false
			return _has_non_zero_digit(remainder.substr(1)) or _decimal_string_is_odd(quotient)
		RoundingMode.FLOOR:
			return negative
		RoundingMode.CEIL:
			return not negative
		RoundingMode.TRUNCATE:
			return false
	return false


## 委托序列化支持脚本判断状态字段是否为可接受的整数值。
## [br]
## @api private
static func _state_value_is_int(value: Variant) -> bool:
	return _call_serialization_support_bool(&"state_value_is_int", [value])


## 委托序列化支持脚本把状态字段转换为 int。
## [br]
## @api private
static func _state_value_to_int(value: Variant) -> int:
	return _call_serialization_support_int(&"state_value_to_int", [value])


## 规范化两个数字串后按长度和字典序比较其非负数值。
## [br]
## @api private
static func _compare_decimal_strings(left: String, right: String) -> int:
	var normalized_left: String = _normalize_decimal_string(left)
	var normalized_right: String = _normalize_decimal_string(right)
	if normalized_left.length() > normalized_right.length():
		return 1
	if normalized_left.length() < normalized_right.length():
		return -1
	if normalized_left == normalized_right:
		return 0
	return 1 if normalized_left > normalized_right else -1


## 对两个非负数字串逐位相减；调用方需保证左侧数值不小于右侧。
## [br]
## @api private
static func _subtract_decimal_strings(left: String, right: String) -> String:
	var left_text: String = _normalize_decimal_string(left)
	var right_text: String = _normalize_decimal_string(right)
	var result_parts: PackedStringArray = PackedStringArray()
	var borrow: int = 0
	var left_index: int = left_text.length() - 1
	var right_index: int = right_text.length() - 1
	while left_index >= 0:
		var left_digit: int = left_text.substr(left_index, 1).to_int() - borrow
		var right_digit: int = 0
		if right_index >= 0:
			right_digit = right_text.substr(right_index, 1).to_int()
		if left_digit < right_digit:
			left_digit += 10
			borrow = 1
		else:
			borrow = 0
		_append_packed_string(result_parts, str(left_digit - right_digit))
		left_index -= 1
		right_index -= 1
	result_parts.reverse()
	return _normalize_decimal_string("".join(result_parts))


## 将非负数字串乘以一个数字，使用逐位乘法和进位。
## digit 小于等于 0 时返回 "0"，等于 1 时只做规范化。
## [br]
## @api private
static func _multiply_decimal_string_by_digit(text: String, digit: int) -> String:
	if digit <= 0:
		return "0"
	if digit == 1:
		return _normalize_decimal_string(text)

	var normalized_text: String = _normalize_decimal_string(text)
	var result_parts: PackedStringArray = PackedStringArray()
	var carry: int = 0
	for i: int in range(normalized_text.length() - 1, -1, -1):
		var product: int = normalized_text.substr(i, 1).to_int() * digit + carry
		_append_packed_string(result_parts, str(product % 10))
		carry = _divide_truncated(product, 10)
	while carry > 0:
		_append_packed_string(result_parts, str(carry % 10))
		carry = _divide_truncated(carry, 10)
	result_parts.reverse()
	return _normalize_decimal_string("".join(result_parts))


## 给规范化后的非负十进制数字串加一。
## [br]
## @api private
static func _add_one_decimal_string(text: String) -> String:
	var result: String = _normalize_decimal_string(text)
	var carry: int = 1
	for i: int in range(result.length() - 1, -1, -1):
		var digit: int = result.substr(i, 1).to_int() + carry
		var prefix: String = result.left(i)
		var suffix: String = result.substr(i + 1)
		result = prefix + str(digit % 10) + suffix
		carry = _divide_truncated(digit, 10)
		if carry == 0:
			return result
	return "1" + result


## 规范化数字串后检查其个位是否为奇数。
## [br]
## @api private
static func _decimal_string_is_odd(text: String) -> bool:
	var normalized_text: String = _normalize_decimal_string(text)
	return normalized_text.substr(normalized_text.length() - 1, 1).to_int() % 2 != 0


## 将非负数字串转为对称 int 范围内的整数，超界时记录错误并钳制到对应边界。
## [br]
## @api private
static func _decimal_string_to_int_saturated(text: String, is_negative: bool, context: String = "divide") -> int:
	var normalized_text: String = _normalize_decimal_string(text)
	if normalized_text.length() > 19 or (
		normalized_text.length() == 19
		and normalized_text > str(_MAX_INT_VALUE)
	):
		push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The %s result exceeds the representable range and was clamped." % context)
		return _get_saturated_int(is_negative)

	var result: int = 0
	for i: int in range(normalized_text.length()):
		result = _checked_multiply(result, 10, context)
		result = _checked_add(result, normalized_text.substr(i, 1).to_int(), context)

	return -result if is_negative else result


## 重复指定字符 max(count, 0) 次。
## [br]
## @api private
static func _repeat_character(character: String, count: int) -> String:
	var result: String = ""
	for _i: int in range(maxi(count, 0)):
		result += character
	return result


## 将小数位数规范化后以整数乘法计算对应的 10 的幂。
## [br]
## @api private
static func _pow10_int(power: int) -> int:
	var safe_power: int = _normalize_decimal_places(power)
	var result: int = 1
	for _i: int in range(safe_power):
		result *= 10
	return result


## 将小数位数规范化后计算对应的浮点 10 的幂。
## [br]
## @api private
static func _pow10_float(power: int) -> float:
	return pow(10.0, _normalize_decimal_places(power))


## 在文本左侧补充指定字符，直到达到目标宽度。
## [br]
## @api private
static func _left_pad(text: String, width: int, fill_char: String) -> String:
	var result: String = text
	while result.length() < width:
		result = fill_char + result
	return result


## 委托序列化支持脚本按 owner 与 context 规范 raw 值，结果非 int 时保留输入值。
## [br]
## @api private
static func _normalize_raw_value(value: int, context: String) -> int:
	return _call_serialization_support_int(
		&"normalize_raw_value",
		[value, "GFFixedDecimal", context],
		value
	)


## 委托序列化支持脚本规范化小数位数。
## [br]
## @api private
static func _normalize_decimal_places(value: int) -> int:
	return _call_serialization_support_int(&"normalize_decimal_places", [value, "GFFixedDecimal"], value)


## 委托序列化支持脚本检查小数位是否处于序列化允许范围。
## [br]
## @api private
static func _decimal_places_are_in_serialized_range(value: int) -> bool:
	return _call_serialization_support_bool(&"decimal_places_are_in_serialized_range", [value])


## 把已验证的十进制数字串解析为 raw 整数，超出对称范围时按符号钳制。
## [br]
## @api private
static func _parse_signed_digits(digits: String, sign_multiplier: int) -> int:
	var significant_digits: String = digits
	while significant_digits.length() > 1 and significant_digits.begins_with("0"):
		significant_digits = significant_digits.substr(1)

	if significant_digits.length() > 19 or (
		significant_digits.length() == 19
		and significant_digits > str(_MAX_INT_VALUE)
	):
		push_error("[GFFixedDecimal][fixed_decimal.number_out_of_range] Number exceeds the representable range.")
		return _get_saturated_int(sign_multiplier < 0)

	var result: int = 0
	for i: int in range(significant_digits.length()):
		result = _checked_multiply(result, 10, "from_string")
		result = _checked_add(result, significant_digits.substr(i, 1).to_int(), "from_string")

	if sign_multiplier < 0:
		return _checked_multiply(result, -1, "from_string")
	return result


## 检查整数乘积是否溢出；溢出时记录错误并返回相应符号的饱和值。
## [br]
## @api private
static func _checked_multiply(left: int, right: int, context: String) -> int:
	if left == 0 or right == 0:
		return 0

	var negative: bool = (left < 0) != (right < 0)
	if not _multiplication_fits(left, right):
		push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The %s result exceeds the representable range and was clamped." % context)
		return _get_saturated_int(negative)
	return left * right


## 通过除法边界判断两个非零整数相乘是否位于对称 int 范围内。
## [br]
## @api private
static func _multiplication_fits(left: int, right: int) -> bool:
	if left == 0 or right == 0:
		return true
	return _abs_int(left) <= _divide_truncated(_MAX_INT_VALUE, _abs_int(right))


## 执行朝零截断的整数除法。
## [br]
## @api private
static func _divide_truncated(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return numerator / denominator


## 检查加法结果是否越过对称 int 边界；越界时记录错误并返回饱和值。
## [br]
## @api private
static func _checked_add(left: int, right: int, context: String) -> int:
	if right > 0 and left > _MAX_INT_VALUE - right:
		push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The %s result exceeds the representable range and was clamped." % context)
		return _MAX_INT_VALUE
	if right < 0 and left < -_MAX_INT_VALUE - right:
		push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The %s result exceeds the representable range and was clamped." % context)
		return -_MAX_INT_VALUE
	return left + right


## 根据符号返回对称范围内的最大正值或负值。
## [br]
## @api private
static func _get_saturated_int(is_negative: bool) -> int:
	return -_MAX_INT_VALUE if is_negative else _MAX_INT_VALUE


## 委托序列化支持脚本计算对称范围内的绝对值。
## [br]
## @api private
static func _abs_int(value: int) -> int:
	return _call_serialization_support_int(&"abs_symmetric", [value])


## 检查字节数据的长度、GFFD 标识、版本号及小数位范围。
## [br]
## @api private
static func _bytes_have_supported_header(data: PackedByteArray) -> bool:
	return (
		data.size() == _BYTE_FORMAT_SIZE
		and data[0] == _BYTE_MAGIC_0
		and data[1] == _BYTE_MAGIC_1
		and data[2] == _BYTE_MAGIC_2
		and data[3] == _BYTE_MAGIC_3
		and data[4] == _SERIALIZATION_VERSION
		and _decimal_places_are_in_serialized_range(data[5])
	)


## 将反序列化失败后的对象重置为 raw 零值和 2 位小数。
## [br]
## @api private
func _reset_serialized_zero() -> void:
	raw_value = 0
	decimal_places = 2


## 在不计算 2 * remainder 的情况下比较其与 denominator 的两倍关系。
## 返回余数小于、等于或大于一半时的 -1、0 或 1。
## [br]
## @api private
static func _compare_twice_remainder(remainder: int, denominator: int) -> int:
	var complement: int = denominator - remainder
	if remainder > complement:
		return 1
	if remainder < complement:
		return -1
	return 0
