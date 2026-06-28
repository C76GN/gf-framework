## GFDecimalStringFormatter: 小数文本格式化与校验辅助。
##
## 提供数值显示、定点数和大数共享的舍入、截断、尾零裁剪与数字字符校验逻辑。
## [br]
## @api framework_internal
class_name GFDecimalStringFormatter
extends RefCounted


# --- 常量 ---

const _MAX_DECIMAL_PLACES: int = 18


# --- 公共方法 ---

## 按小数位数调整浮点值。
## [br]
## @api framework_internal
## [br]
## @param value: 输入值。
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param use_truncation: 为 true 时截断，否则四舍五入。
## [br]
## @return 调整后的值。
static func apply_decimal_places(value: float, decimal_places: int, use_truncation: bool) -> float:
	if _is_non_finite(value):
		push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")
		return 0.0

	var normalized_decimal_places: int = _normalize_decimal_places(decimal_places)
	if normalized_decimal_places <= 0:
		if use_truncation:
			return floor(value) if value >= 0.0 else ceil(value)
		return round(value)

	var scale: float = pow(10.0, normalized_decimal_places)
	if use_truncation:
		if value >= 0.0:
			return floor(value * scale) / scale
		return ceil(value * scale) / scale

	return round(value * scale) / scale


## 格式化小数值。
## [br]
## @api framework_internal
## [br]
## @param value: 输入值。
## [br]
## @param decimal_places: 小数位数。
## [br]
## @param trim_zeroes: 是否裁剪末尾零。
## [br]
## @param use_truncation: 为 true 时截断，否则四舍五入。
## [br]
## @return 格式化文本。
static func format_decimal_value(
	value: float,
	decimal_places: int,
	trim_zeroes: bool,
	use_truncation: bool
) -> String:
	if _is_non_finite(value):
		push_error("[GFDecimalStringFormatter] 只能格式化有限浮点值。")
		return "0"

	var normalized_decimal_places: int = _normalize_decimal_places(decimal_places)
	var adjusted_value: float = apply_decimal_places(value, normalized_decimal_places, use_truncation)
	if normalized_decimal_places <= 0:
		return str(int(adjusted_value))

	var text: String = ("%." + str(normalized_decimal_places) + "f") % adjusted_value
	if trim_zeroes:
		text = trim_trailing_zeroes(text)
	return text


## 裁剪小数字符串末尾零。
## [br]
## @api framework_internal
## [br]
## @param text: 小数字符串。
## [br]
## @return 裁剪后的文本。
static func trim_trailing_zeroes(text: String) -> String:
	var result: String = text
	while result.ends_with("0"):
		result = result.left(result.length() - 1)

	if result.ends_with("."):
		result = result.left(result.length() - 1)

	if result.is_empty() or result == "-":
		return "0"

	if result == "-0":
		return "0"

	return result


## 校验小数字符串拆分后的整数和小数部分。
## [br]
## @api framework_internal
## [br]
## @param integer_part: 整数部分。
## [br]
## @param fractional_part: 小数部分。
## [br]
## @param has_decimal_point: 原始文本是否包含小数点。
## [br]
## @return 合法返回 true。
static func is_valid_decimal_parts(
	integer_part: String,
	fractional_part: String,
	has_decimal_point: bool
) -> bool:
	if has_decimal_point and integer_part.find(".") != -1:
		return false
	if integer_part.is_empty() and fractional_part.is_empty():
		return false
	var integer_valid: bool = integer_part.is_empty() or contains_only_digits(integer_part)
	var fractional_valid: bool = fractional_part.is_empty() or contains_only_digits(fractional_part)
	return integer_valid and fractional_valid


## 判断文本是否只包含数字字符。
## [br]
## @api framework_internal
## [br]
## @param text: 输入文本。
## [br]
## @return 只包含数字时返回 true。
static func contains_only_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i: int in range(text.length()):
		var character: String = text.substr(i, 1)
		if character < "0" or character > "9":
			return false
	return true


# --- 私有/辅助方法 ---

static func _normalize_decimal_places(decimal_places: int) -> int:
	if decimal_places <= 0:
		return 0

	if decimal_places > _MAX_DECIMAL_PLACES:
		push_error("[GFDecimalStringFormatter] decimal_places 不能超过 %d，已钳制。" % _MAX_DECIMAL_PLACES)
		return _MAX_DECIMAL_PLACES

	return decimal_places


static func _is_non_finite(value: float) -> bool:
	return is_nan(value) or is_inf(value)
