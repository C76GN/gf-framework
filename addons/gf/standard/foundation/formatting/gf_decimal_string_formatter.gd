## GFDecimalStringFormatter: 小数文本格式化与校验辅助。
##
## 提供数值显示、定点数和大数共享的舍入、截断、尾零裁剪与数字字符校验逻辑。
## [br]
## @api framework_internal
class_name GFDecimalStringFormatter
extends RefCounted


# --- 常量 ---

const _MAX_DECIMAL_PLACES: int = 18

## 数值文本解析器的默认输入字符预算。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
const DEFAULT_MAX_NUMERIC_TEXT_LENGTH: int = 4096


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
		var integer_adjusted_value: float = 0.0
		if use_truncation:
			integer_adjusted_value = floor(value) if value >= 0.0 else ceil(value)
		else:
			integer_adjusted_value = round(value)
		if _is_non_finite(integer_adjusted_value):
			_report_scaled_non_finite()
			return 0.0
		return integer_adjusted_value

	var scale: float = pow(10.0, normalized_decimal_places)
	var scaled_value: float = value * scale
	if _is_non_finite(scaled_value):
		_report_scaled_non_finite()
		return 0.0

	var adjusted_value: float = 0.0
	if use_truncation:
		if value >= 0.0:
			adjusted_value = floor(scaled_value) / scale
		else:
			adjusted_value = ceil(scaled_value) / scale
	else:
		adjusted_value = round(scaled_value) / scale

	if _is_non_finite(adjusted_value):
		_report_scaled_non_finite()
		return 0.0
	return adjusted_value


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
	var decimal_index: int = text.find(".")
	if decimal_index < 0:
		return "0" if text == "-0" else text
	var result: String = text
	while result.length() > decimal_index + 1 and result.ends_with("0"):
		result = result.left(result.length() - 1)

	if result.ends_with("."):
		result = result.left(result.length() - 1)

	if result.is_empty() or result == "-":
		return "0"

	if result == "-0":
		return "0"

	return result


## 严格校验并移除合法数字分隔符。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param text: 待校验的十进制或科学计数法文本。
## [br]
## @param max_input_length: 最大输入字符数；小于等于 0 表示使用默认预算。
## [br]
## @return 包含 ok、text 和 error 的规范化结果。
## [br]
## @schema return: Dictionary with ok: bool, text: String, and error: String.
static func normalize_numeric_text(text: String, max_input_length: int = DEFAULT_MAX_NUMERIC_TEXT_LENGTH) -> Dictionary:
	var limit: int = max_input_length if max_input_length > 0 else DEFAULT_MAX_NUMERIC_TEXT_LENGTH
	var normalized: String = text.strip_edges()
	if normalized.is_empty():
		return _make_numeric_text_result(false, "", "empty_input")
	if normalized.length() > limit:
		return _make_numeric_text_result(false, "", "input_too_long")

	var exponent_index: int = normalized.find("e")
	var uppercase_exponent_index: int = normalized.find("E")
	if exponent_index < 0 or (uppercase_exponent_index >= 0 and uppercase_exponent_index < exponent_index):
		exponent_index = uppercase_exponent_index
	var exponent_suffix: String = ""
	if exponent_index >= 0:
		if normalized.find("e", exponent_index + 1) >= 0 or normalized.find("E", exponent_index + 1) >= 0:
			return _make_numeric_text_result(false, "", "invalid_exponent")
		var exponent_text: String = normalized.substr(exponent_index + 1)
		normalized = normalized.substr(0, exponent_index)
		if exponent_text.begins_with("+") or exponent_text.begins_with("-"):
			if exponent_text.length() == 1:
				return _make_numeric_text_result(false, "", "invalid_exponent")
			exponent_suffix = "e" + exponent_text.substr(0, 1)
			exponent_text = exponent_text.substr(1)
		else:
			exponent_suffix = "e"
		if not contains_only_digits(exponent_text):
			return _make_numeric_text_result(false, "", "invalid_exponent")
		exponent_suffix += exponent_text

	var sign_text: String = ""
	if normalized.begins_with("+") or normalized.begins_with("-"):
		sign_text = normalized.substr(0, 1)
		normalized = normalized.substr(1)
	if normalized.is_empty() or normalized.count(".") > 1:
		return _make_numeric_text_result(false, "", "invalid_mantissa")

	var decimal_index: int = normalized.find(".")
	var integer_part: String = normalized if decimal_index < 0 else normalized.substr(0, decimal_index)
	var fractional_part: String = "" if decimal_index < 0 else normalized.substr(decimal_index + 1)
	if integer_part.is_empty() and fractional_part.is_empty():
		return _make_numeric_text_result(false, "", "invalid_mantissa")
	var integer_result: Dictionary = _normalize_integer_digits(integer_part)
	var fraction_result: Dictionary = _normalize_underscore_digits(fractional_part, true)
	if not GFVariantData.get_option_bool(integer_result, "ok") or not GFVariantData.get_option_bool(fraction_result, "ok"):
		return _make_numeric_text_result(false, "", "invalid_separator")

	var result_text: String = sign_text + GFVariantData.get_option_string(integer_result, "text")
	if decimal_index >= 0:
		result_text += "." + GFVariantData.get_option_string(fraction_result, "text")
	return _make_numeric_text_result(true, result_text + exponent_suffix, "")


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

static func _normalize_integer_digits(value: String) -> Dictionary:
	if value.is_empty():
		return _make_numeric_text_result(true, "", "")
	if value.contains(","):
		if value.contains("_"):
			return _make_numeric_text_result(false, "", "invalid_separator")
		var groups: PackedStringArray = value.split(",", true)
		if groups.is_empty() or groups[0].is_empty() or groups[0].length() > 3 or not contains_only_digits(groups[0]):
			return _make_numeric_text_result(false, "", "invalid_separator")
		for index: int in range(1, groups.size()):
			if groups[index].length() != 3 or not contains_only_digits(groups[index]):
				return _make_numeric_text_result(false, "", "invalid_separator")
		return _make_numeric_text_result(true, "".join(groups), "")
	return _normalize_underscore_digits(value, false)


static func _normalize_underscore_digits(value: String, allow_empty: bool) -> Dictionary:
	if value.is_empty():
		return _make_numeric_text_result(allow_empty, "", "" if allow_empty else "invalid_digits")
	if value.begins_with("_") or value.ends_with("_"):
		return _make_numeric_text_result(false, "", "invalid_separator")
	var groups: PackedStringArray = value.split("_", true)
	for group: String in groups:
		if group.is_empty() or not contains_only_digits(group):
			return _make_numeric_text_result(false, "", "invalid_separator")
	return _make_numeric_text_result(true, "".join(groups), "")


static func _make_numeric_text_result(ok: bool, text: String, error: String) -> Dictionary:
	return {
		"ok": ok,
		"text": text,
		"error": error,
	}


static func _normalize_decimal_places(decimal_places: int) -> int:
	if decimal_places <= 0:
		return 0

	if decimal_places > _MAX_DECIMAL_PLACES:
		push_error("[GFDecimalStringFormatter] decimal_places 不能超过 %d，已钳制。" % _MAX_DECIMAL_PLACES)
		return _MAX_DECIMAL_PLACES

	return decimal_places


static func _is_non_finite(value: float) -> bool:
	return is_nan(value) or is_inf(value)


static func _report_scaled_non_finite() -> void:
	push_error("[GFDecimalStringFormatter] 小数缩放后超过有限浮点范围。")
