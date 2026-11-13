## GFDecimalStringFormatter: 小数文本格式化与校验辅助。
##
## 提供数值显示、定点数和大数共享的舍入、截断、尾零裁剪与数字字符校验逻辑。
## [br]
## @api framework_internal
class_name GFDecimalStringFormatter
extends RefCounted


# --- 常量 ---

## 浮点格式化允许的最大小数位数。
## [br]
## @api private
const _MAX_DECIMAL_PLACES: int = 18

## 数值文本解析器的默认输入字符预算。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
const DEFAULT_MAX_NUMERIC_TEXT_LENGTH: int = 4096


# --- 公共方法 ---

## 将有界数值文本解析为精确十进制分量，不把整数或尾数转成 float。
## [br]
## @api framework_internal
## [br]
## @param text: 最多4096字符的数字文本；沿用严格分隔符语法，科学指数及最终数量级范围为±1000000。
## [br]
## @return 验证后的分量或明确错误。
## [br]
## @schema return: 封闭 Dictionary，ok:bool、error:String、sign:String（空/+/-）、digits:String（无前后冗余零，零为0）、exponent:int。值为 sign*digits*10^exponent；失败时分量归零。
static func parse_components(text: String) -> Dictionary:
	var normalized: Dictionary = normalize_numeric_text(text)
	if not GFVariantData.get_option_bool(normalized, "ok"):
		return _component_error(GFVariantData.get_option_string(normalized, "error"))
	var body: String = GFVariantData.get_option_string(normalized, "text")
	var exponent_offset: int = 0
	var exponent_index: int = body.find("e")
	if exponent_index >= 0:
		var exponent_text: String = body.substr(exponent_index + 1)
		body = body.left(exponent_index)
		var negative_exponent: bool = exponent_text.begins_with("-")
		if negative_exponent or exponent_text.begins_with("+"):
			exponent_text = exponent_text.substr(1)
		var leading: int = 0
		while leading < exponent_text.length() - 1 and exponent_text.unicode_at(leading) == 48:
			leading += 1
		exponent_text = exponent_text.substr(leading)
		if (
			exponent_text.length() > 7
			or (
				exponent_text.length() == 7
				and exponent_text > "1000000"
			)
		):
			return _component_error("exponent_out_of_range")
		exponent_offset = exponent_text.to_int() * (-1 if negative_exponent else 1)
	var sign_text: String = ""
	if body.begins_with("-") or body.begins_with("+"):
		sign_text = body.left(1)
		body = body.substr(1)
	var point: int = body.find(".")
	var fraction_length: int = body.length() - point - 1 if point >= 0 else 0
	var result: Dictionary = _normalize_components(
		sign_text,
		body.replace(".", ""),
		exponent_offset - fraction_length
	)
	var magnitude: int = GFVariantData.get_option_int(result, "exponent") + GFVariantData.get_option_string(result, "digits").length() - 1
	if magnitude < -1000000 or magnitude > 1000000:
		return _component_error("exponent_out_of_range")
	return result


## 对已解析分量进行一次精确舍入并渲染缩放后的十进制文本。
## [br]
## @api framework_internal
## [br]
## @param components: parse_components 的成功分量。
## [br]
## @schema components: ok:bool=true、error:String、sign:String、digits:String、exponent:int；数字串最多4096字符，数量级±1000000，不接受任意对象。
## [br]
## @param scale_exponent: 先除以10的此幂，范围±1000002；为科学和工程计数边界进位预留两位。
## [br]
## @param policy: 冻结的小数位、有效位与舍入政策。
## [br]
## @return 渲染结果；输出超过8192字符时明确失败，调用方可以改用科学计数法。
## [br]
## @schema return: 封闭 Dictionary，ok:bool、error:String、text:String、display_exponent:int（舍入后缩放值的十进制数量级）。失败文本为空。
static func format_components(
	components: Dictionary,
	scale_exponent: int,
	policy: GFNumberFormatPolicy
) -> Dictionary:
	if (
		policy == null
		or not _valid_components(components)
		or scale_exponent < -1000002
		or scale_exponent > 1000002
	):
		return _formatted_error("invalid_components")
	var options: Dictionary = policy.to_record()
	if options.is_empty():
		return _formatted_error("invalid_policy")
	var digits: String = GFVariantData.get_option_string(components, "digits")
	var exponent: int = GFVariantData.get_option_int(components, "exponent")
	var sign_text: String = GFVariantData.get_option_string(components, "sign")
	var significant: int = GFVariantData.get_option_int(options, "significant_digits")
	var quantum: int = -GFVariantData.get_option_int(options, "decimal_places")
	if significant > 0 and digits != "0":
		quantum = maxi(
			quantum,
			digits.length() + exponent - scale_exponent - significant
		)
	var rounding: String = GFVariantData.get_option_string(options, "rounding")
	var rounded: Dictionary = _quantize_components(
		sign_text,
		digits,
		exponent,
		scale_exponent + quantum,
		rounding
	)
	var rounded_digits: String = GFVariantData.get_option_string(rounded, "digits")
	var rounded_exponent: int = GFVariantData.get_option_int(rounded, "exponent")
	var display_exponent: int = rounded_digits.length() + rounded_exponent - scale_exponent - 1
	if (
		significant > 0
		and rounded_digits != "0"
		and display_exponent - significant + 1 > quantum
	):
		quantum = display_exponent - significant + 1
		rounded = _quantize_components(
			sign_text,
			digits,
			exponent,
			scale_exponent + quantum,
			rounding
		)
		rounded_digits = GFVariantData.get_option_string(rounded, "digits")
		rounded_exponent = GFVariantData.get_option_int(rounded, "exponent")
		display_exponent = rounded_digits.length() + rounded_exponent - scale_exponent - 1
	var position: int = rounded_digits.length() + rounded_exponent - scale_exponent
	var places: int = maxi(0, -quantum)
	var rounded_sign: String = GFVariantData.get_option_string(rounded, "sign")
	if rounded_digits == "0":
		position = 1
		display_exponent = 0
	if rounded_sign.length() + maxi(position, 1) + (places + 1 if places > 0 else 0) > 8192:
		return _formatted_error("output_budget")
	var integer_text: String = "0"
	var fraction: String = ""
	if rounded_digits != "0":
		if position <= 0:
			fraction = "0".repeat(-position) + rounded_digits
		elif position >= rounded_digits.length():
			integer_text = rounded_digits + "0".repeat(position - rounded_digits.length())
		else:
			integer_text = rounded_digits.left(position)
			fraction = rounded_digits.substr(position)
	if fraction.length() < places:
		fraction += "0".repeat(places - fraction.length())
	var output: String = rounded_sign + integer_text
	if places > 0:
		output += "." + fraction
	if GFVariantData.get_option_bool(options, "trim_zeroes"):
		output = trim_trailing_zeroes(output)
	return {
		"ok": true,
		"error": "",
		"text": output,
		"display_exponent": display_exponent,
	}


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
static func apply_decimal_places(
	value: float,
	decimal_places: int,
	use_truncation: bool
) -> float:
	if _is_non_finite(value):
		push_error("[GFDecimalStringFormatter][decimal_string_formatter.value_non_finite] Only finite floating-point values can be formatted.")
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
		push_error("[GFDecimalStringFormatter][decimal_string_formatter.value_non_finite] Only finite floating-point values can be formatted.")
		return "0"

	var normalized_decimal_places: int = _normalize_decimal_places(decimal_places)
	var adjusted_value: float = apply_decimal_places(
		value,
		normalized_decimal_places,
		use_truncation
	)
	if normalized_decimal_places <= 0:
		if adjusted_value == 0.0:
			return "0"
		return "%.0f" % adjusted_value

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
## @param max_input_length: 原始输入（含边缘空白）的最大字符数；小于等于 0 表示使用默认预算。
## [br]
## @return 包含 ok、text 和 error 的规范化结果。
## [br]
## @schema return: Dictionary with ok: bool, text: String, and error: String.
static func normalize_numeric_text(text: String, max_input_length: int = DEFAULT_MAX_NUMERIC_TEXT_LENGTH) -> Dictionary:
	var limit: int = max_input_length if max_input_length > 0 else DEFAULT_MAX_NUMERIC_TEXT_LENGTH
	if text.length() > limit:
		return _make_numeric_text_result(
			false,
			"",
			"input_too_long"
		)
	var normalized: String = text.strip_edges()
	if normalized.is_empty():
		return _make_numeric_text_result(
			false,
			"",
			"empty_input"
		)

	var exponent_index: int = normalized.find("e")
	var uppercase_exponent_index: int = normalized.find("E")
	if (
		exponent_index < 0
		or (
			uppercase_exponent_index >= 0
			and uppercase_exponent_index < exponent_index
		)
	):
		exponent_index = uppercase_exponent_index
	var exponent_suffix: String = ""
	if exponent_index >= 0:
		if normalized.find(
			"e",
			exponent_index + 1
		) >= 0 or normalized.find(
			"E",
			exponent_index + 1
		) >= 0:
			return _make_numeric_text_result(
				false,
				"",
				"invalid_exponent"
			)
		var exponent_text: String = normalized.substr(exponent_index + 1)
		normalized = normalized.substr(0, exponent_index)
		if exponent_text.begins_with("+") or exponent_text.begins_with("-"):
			if exponent_text.length() == 1:
				return _make_numeric_text_result(
					false,
					"",
					"invalid_exponent"
				)
			exponent_suffix = "e" + exponent_text.substr(0, 1)
			exponent_text = exponent_text.substr(1)
		else:
			exponent_suffix = "e"
		if not contains_only_digits(exponent_text):
			return _make_numeric_text_result(
				false,
				"",
				"invalid_exponent"
			)
		exponent_suffix += exponent_text

	var sign_text: String = ""
	if normalized.begins_with("+") or normalized.begins_with("-"):
		sign_text = normalized.substr(0, 1)
		normalized = normalized.substr(1)
	if normalized.is_empty() or normalized.count(".") > 1:
		return _make_numeric_text_result(
			false,
			"",
			"invalid_mantissa"
		)

	var decimal_index: int = normalized.find(".")
	var integer_part: String = normalized if decimal_index < 0 else normalized.substr(0, decimal_index)
	var fractional_part: String = "" if decimal_index < 0 else normalized.substr(decimal_index + 1)
	if integer_part.is_empty() and fractional_part.is_empty():
		return _make_numeric_text_result(
			false,
			"",
			"invalid_mantissa"
		)
	var integer_result: Dictionary = _normalize_integer_digits(integer_part)
	var fraction_result: Dictionary = _normalize_underscore_digits(fractional_part, true)
	if (not GFVariantData.get_option_bool(integer_result, "ok") or not GFVariantData.get_option_bool(fraction_result, "ok")):
		return _make_numeric_text_result(
			false,
			"",
			"invalid_separator"
		)

	var result_text: String = sign_text + GFVariantData.get_option_string(integer_result, "text")
	if decimal_index >= 0:
		result_text += "." + GFVariantData.get_option_string(fraction_result, "text")
	return _make_numeric_text_result(
		true,
		result_text + exponent_suffix,
		""
	)


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

## 验证内部数字分量，限制计算与输出分配的来源。
## [br]
## @api private
static func _valid_components(record: Dictionary) -> bool:
	if (
		not GFVariantData.get_option_bool(record, "ok")
		or not record.get("digits") is String
		or not record.get("sign") is String
		or not record.get("exponent") is int
	):
		return false
	var digits: String = GFVariantData.get_option_string(record, "digits")
	var sign_text: String = GFVariantData.get_option_string(record, "sign")
	var exponent: int = GFVariantData.get_option_int(record, "exponent")
	if (
		digits.length() > 4096
		or not contains_only_digits(digits)
		or sign_text not in [
			"",
			"+",
			"-",
		]
	):
		return false
	if digits == "0":
		return sign_text.is_empty() and exponent == 0
	var magnitude: int = exponent + digits.length() - 1
	return (
		not digits.begins_with("0")
		and not digits.ends_with("0")
		and magnitude >= -1000000
		and magnitude <= 1000000
	)


## 去掉无意义的首尾零，并把尾零换算成十进制指数。
## [br]
## @api private
static func _normalize_components(
	sign_text: String,
	digits: String,
	exponent: int
) -> Dictionary:
	var first: int = 0
	while first < digits.length() and digits.unicode_at(first) == 48:
		first += 1
	if first == digits.length():
		return {
			"ok": true,
			"error": "",
			"sign": "",
			"digits": "0",
			"exponent": 0,
		}
	var last: int = digits.length() - 1
	while last > first and digits.unicode_at(last) == 48:
		last -= 1
	return {
		"ok": true,
		"error": "",
		"sign": sign_text,
		"digits": digits.substr(
			first,
			last - first + 1
		),
		"exponent": exponent + digits.length() - last - 1,
	}


## 将原始数字直接量化到指定十进制幂，避免缩放或重复舍入。
## [br]
## @api private
static func _quantize_components(
	sign_text: String,
	digits: String,
	exponent: int,
	quantum: int,
	rounding: String
) -> Dictionary:
	if digits == "0" or exponent >= quantum:
		return _normalize_components(
			sign_text,
			digits,
			exponent
		)
	var keep: int = digits.length() + exponent - quantum
	var kept: String = digits.left(keep) if keep > 0 else "0"
	var increment: bool = false
	match rounding:
		"floor":
			increment = sign_text == "-"
		"ceiling":
			increment = sign_text != "-"
		"half_up", "half_even":
			if keep >= 0:
				var next_digit: int = digits.unicode_at(keep) - 48
				increment = (
					next_digit > 5
					or (
						next_digit == 5
						and rounding == "half_up"
					)
				)
				if next_digit == 5 and rounding == "half_even":
					var odd: bool = (kept.unicode_at(kept.length() - 1) - 48) % 2 != 0
					increment = odd or not _digits_are_zero(digits.substr(keep + 1))
	if increment:
		kept = _increment_decimal_digits(kept)
	return _normalize_components(
		sign_text,
		kept,
		quantum
	)


## 创建无载荷的分量解析错误。
## [br]
## @api private
static func _component_error(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"sign": "",
		"digits": "0",
		"exponent": 0,
	}


## 创建有界格式化失败结果。
## [br]
## @api private
static func _formatted_error(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"text": "",
		"display_exponent": 0,
	}


## 校验并规范化整数位的逗号分组或下划线分隔。
## [br]
## @api private
static func _normalize_integer_digits(value: String) -> Dictionary:
	if value.is_empty():
		return _make_numeric_text_result(
			true,
			"",
			""
		)
	if value.contains(","):
		if value.contains("_"):
			return _make_numeric_text_result(
				false,
				"",
				"invalid_separator"
			)
		var groups: PackedStringArray = value.split(",", true)
		if (
			groups.is_empty()
			or groups[0].is_empty()
			or groups[0].length() > 3
			or not contains_only_digits(groups[0])
		):
			return _make_numeric_text_result(
				false,
				"",
				"invalid_separator"
			)
		for index: int in range(
			1,
			groups.size()
		):
			if groups[index].length() != 3 or not contains_only_digits(groups[index]):
				return _make_numeric_text_result(
					false,
					"",
					"invalid_separator"
				)
		return _make_numeric_text_result(
			true,
			"".join(groups),
			""
		)
	return _normalize_underscore_digits(value, false)


## 校验并移除数字串中的下划线分隔符。
## [br]
## @api private
static func _normalize_underscore_digits(value: String, allow_empty: bool) -> Dictionary:
	if value.is_empty():
		return _make_numeric_text_result(
			allow_empty,
			"",
			"" if allow_empty else "invalid_digits"
		)
	if value.begins_with("_") or value.ends_with("_"):
		return _make_numeric_text_result(
			false,
			"",
			"invalid_separator"
		)
	var groups: PackedStringArray = value.split("_", true)
	for group: String in groups:
		if group.is_empty() or not contains_only_digits(group):
			return _make_numeric_text_result(
				false,
				"",
				"invalid_separator"
			)
	return _make_numeric_text_result(
		true,
		"".join(groups),
		""
	)


## 创建包含 ok、text 和 error 字段的解析结果。
## [br]
## @api private
static func _make_numeric_text_result(
	ok: bool,
	text: String,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"text": text,
		"error": error,
	}


## 从末位开始对十进制数字串加一，并向前传播进位。
## [br]
## @api private
static func _increment_decimal_digits(value: String) -> String:
	var digits: PackedByteArray = value.to_ascii_buffer()
	for index: int in range(
		digits.size() - 1,
		-1,
		-1
	):
		if digits[index] < 57:
			digits[index] += 1
			return digits.get_string_from_ascii()
		digits[index] = 48
	return "1" + digits.get_string_from_ascii()


## 检查字符串中的每个字符是否都是 0。
## [br]
## @api private
static func _digits_are_zero(value: String) -> bool:
	for index: int in range(value.length()):
		if value.substr(index, 1) != "0":
			return false
	return true


## 将小数位数限制在 0 到 _MAX_DECIMAL_PLACES。
## [br]
## @api private
static func _normalize_decimal_places(decimal_places: int) -> int:
	if decimal_places <= 0:
		return 0

	if decimal_places > _MAX_DECIMAL_PLACES:
		push_error("[GFDecimalStringFormatter][decimal_string_formatter.decimal_places_clamped] decimal_places exceeds %d and was clamped." % _MAX_DECIMAL_PLACES)
		return _MAX_DECIMAL_PLACES

	return decimal_places


## 判断浮点值是否为 NaN 或正负无穷。
## [br]
## @api private
static func _is_non_finite(value: float) -> bool:
	return is_nan(value) or is_inf(value)


## 报告缩放计算超出有限浮点范围。
## [br]
## @api private
static func _report_scaled_non_finite() -> void:
	push_error("[GFDecimalStringFormatter][decimal_string_formatter.scaled_value_non_finite] The scaled decimal exceeds the finite floating-point range.")
