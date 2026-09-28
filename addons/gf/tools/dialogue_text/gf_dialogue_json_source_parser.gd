# Dialogue Text 内部严格 JSON source parser。
#
# 该脚本没有 class_name，只供 gf.tool.dialogue_text 编译器预加载。它在构造
# Variant 前执行 RFC JSON 词法、duplicate member、有限数值、Unicode 与结构预算
# 校验，并保留 raw JSON Pointer 到 token span 的映射。
extends RefCounted


# --- 常量 ---

## 有限浮点规范化时保留的十进制有效数字上限。
## [br]
## @api private
## [br]
const _MAX_FLOAT_SIGNIFICANT_DIGITS: int = 768

## 规范化指数为 308 时用于边界比较的十进制前缀。
## [br]
## @api private
## [br]
const _MAX_FLOAT_DECIMAL_PREFIX: String = "17976931348623157"


# --- 私有变量 ---

## 当前 strict JSON 文本输入。
## [br]
## @api private
## [br]
var _text: String = ""

## 当前输入的 String 长度缓存。
## [br]
## @api private
## [br]
var _text_length: int = 0

## 解析游标的当前位置。
## [br]
## @api private
## [br]
var _index: int = 0

## 解析游标当前所在的行号，初始为 1。
## [br]
## @api private
## [br]
var _line: int = 1

## 解析游标当前所在的列号，初始为 1。
## [br]
## @api private
## [br]
var _column: int = 1

## 标记上一个 codepoint 是否为 CR，用于识别 CRLF 行尾。
## [br]
## @api private
## [br]
var _previous_was_cr: bool = false

## 本次解析接受的最大容器深度。
## [br]
## @api private
## [br]
var _max_depth: int = 1

## 本次解析接受的最大节点数量。
## [br]
## @api private
## [br]
var _max_nodes: int = 1

## 单个 JSON 字符串接受的最大 UTF-8 字节数。
## [br]
## @api private
## [br]
var _max_string_bytes: int = 1

## 本次解析已经预留的节点数量。
## [br]
## @api private
## [br]
var _node_count: int = 0

## 本次解析已读取字符串及对象键的 UTF-8 字节数。
## [br]
## @api private
## [br]
var _string_byte_count: int = 0

## JSON Pointer 到值 token 来源片段的映射。
## [br]
## @api private
## [br]
var _value_spans: Dictionary = {}

## JSON Pointer 到对象 member 名称来源片段的映射。
## [br]
## @api private
## [br]
var _key_spans: Dictionary = {}

## 本次解析记录的首个错误信息。
## [br]
## @api private
## [br]
var _error: Dictionary = {}


# --- 框架内部方法 ---

## 解析严格 JSON，并返回值与 source provenance。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param text: 待解析的 UTF-8 JSON 文本。
## [br]
## @param limits: 已由调用方校验的深度、节点与字符串字节预算。
## [br]
## @schema limits: Dictionary with positive max_depth, max_nodes, and max_string_bytes limits.
## [br]
## @return: 严格 JSON 值、来源位置与稳定错误字段组成的解析报告。
## [br]
## @schema return: Dictionary with ok, value, value_spans, key_spans, node_count, string_byte_count, error_kind, error, pointer, span, and metadata.
func parse_text(text: String, limits: Dictionary) -> Dictionary:
	_text = text
	_text_length = text.length()
	_index = 0
	_line = 1
	_column = 1
	_previous_was_cr = false
	_max_depth = _read_positive_limit(limits, "max_depth")
	_max_nodes = _read_positive_limit(limits, "max_nodes")
	_max_string_bytes = _read_positive_limit(limits, "max_string_bytes")
	_node_count = 0
	_string_byte_count = 0
	_value_spans.clear()
	_key_spans.clear()
	_error.clear()

	_skip_whitespace()
	var value: Variant = _parse_value("", 1)
	if _has_error():
		return _make_failure_result()
	_skip_whitespace()
	if _index != _text_length:
		_set_error(
			&"invalid_json",
			"Strict JSON contains trailing content after the root value.",
			"",
			_make_current_span()
		)
		return _make_failure_result()
	return {
		"ok": true,
		"value": value,
		"value_spans": _value_spans.duplicate(true),
		"key_spans": _key_spans.duplicate(true),
		"node_count": _node_count,
		"string_byte_count": _string_byte_count,
		"error_kind": &"",
		"error": "",
		"pointer": "",
		"span": {},
		"metadata": {},
	}


# --- 私有/辅助方法 ---

## 先预留节点预算，再按当前字符解析值；只有未发生错误时才记录该 JSON Pointer 的完整值范围，null 是否有效须同时检查错误状态。
## [br]
## @api private
func _parse_value(pointer: String, depth: int) -> Variant:
	if _has_error():
		return null
	_skip_whitespace()
	var start_index: int = _index
	var start_line: int = _line
	var start_column: int = _column
	if not _reserve_node(pointer, start_line, start_column):
		return null
	var codepoint: int = _peek()
	var value: Variant = null
	match codepoint:
		123:
			if depth > _max_depth:
				_set_budget_error("JSON nesting exceeds max_depth.", pointer, _make_current_span())
				return null
			value = _parse_object(pointer, depth)
		91:
			if depth > _max_depth:
				_set_budget_error("JSON nesting exceeds max_depth.", pointer, _make_current_span())
				return null
			value = _parse_array(pointer, depth)
		34:
			value = _parse_string(pointer)
		116:
			value = _parse_keyword("true", true, pointer)
		102:
			value = _parse_keyword("false", false, pointer)
		110:
			value = _parse_keyword("null", null, pointer)
		_:
			if codepoint == 45 or _is_digit(codepoint):
				value = _parse_number(pointer)
			else:
				_set_error(
					&"invalid_json",
					"Strict JSON expected a value.",
					pointer,
					_make_current_span()
				)
	if not _has_error():
		_value_spans[pointer] = _make_span(
			start_index,
			start_line,
			start_column,
			_index,
			_line,
			_column
		)
	return value


## 逐成员解析并记录键范围，以转义后的 JSON Pointer 关联值；重复键报告首次和重复位置并停止，失败时返回的部分字典不能作为成功结果。
## [br]
## @api private
func _parse_object(pointer: String, depth: int) -> Dictionary:
	var result: Dictionary = {}
	var _opening_codepoint: int = _advance()
	_skip_whitespace()
	if _peek() == 125:
		var _closing_codepoint: int = _advance()
		return result
	var member_index: int = 0
	while not _has_error():
		_skip_whitespace()
		if _peek() != 34:
			_set_error(
				&"invalid_json",
				"Strict JSON object expected a quoted member name.",
				pointer,
				_make_current_span()
			)
			break
		var key_start_index: int = _index
		var key_start_line: int = _line
		var key_start_column: int = _column
		if not _reserve_node(pointer, key_start_line, key_start_column):
			break
		var key: String = _parse_string(pointer)
		if _has_error():
			break
		var member_pointer: String = _append_pointer(pointer, key)
		var key_span: Dictionary = _make_span(
			key_start_index,
			key_start_line,
			key_start_column,
			_index,
			_line,
			_column
		)
		if result.has(key):
			var first_span: Dictionary = GFVariantData.get_option_dictionary(
				_key_spans,
				member_pointer
			)
			_set_error(
				&"duplicate_field",
				"Strict JSON object member names must be unique.",
				member_pointer,
				key_span,
				{
					"related_source_spans": [first_span, key_span.duplicate(true)],
					"member_index": member_index,
				}
			)
			break
		_key_spans[member_pointer] = key_span
		_skip_whitespace()
		if _peek() != 58:
			_set_error(
				&"invalid_json",
				"Strict JSON object member name must be followed by a colon.",
				member_pointer,
				_make_current_span()
			)
			break
		var _colon_codepoint: int = _advance()
		var member_value: Variant = _parse_value(member_pointer, depth + 1)
		if _has_error():
			break
		result[key] = member_value
		member_index += 1
		_skip_whitespace()
		var separator: int = _peek()
		if separator == 125:
			var _closing_codepoint: int = _advance()
			break
		if separator != 44:
			_set_error(
				&"invalid_json",
				"Strict JSON object members must be separated by a comma.",
				pointer,
				_make_current_span()
			)
			break
		var _comma_codepoint: int = _advance()
		_skip_whitespace()
		if _peek() == 125:
			_set_error(
				&"invalid_json",
				"Strict JSON does not allow a trailing comma in an object.",
				pointer,
				_make_current_span()
			)
			break
	return result


## 按零基下标构建元素 JSON Pointer 并逐项解析；拒绝缺少逗号和尾逗号，错误状态下可能留下包含失败空值的部分数组。
## [br]
## @api private
func _parse_array(pointer: String, depth: int) -> Array:
	var result: Array = []
	var _opening_codepoint: int = _advance()
	_skip_whitespace()
	if _peek() == 93:
		var _closing_codepoint: int = _advance()
		return result
	var item_index: int = 0
	while not _has_error():
		var item_pointer: String = _append_pointer(pointer, str(item_index))
		result.append(_parse_value(item_pointer, depth + 1))
		if _has_error():
			break
		item_index += 1
		_skip_whitespace()
		var separator: int = _peek()
		if separator == 93:
			var _closing_codepoint: int = _advance()
			break
		if separator != 44:
			_set_error(
				&"invalid_json",
				"Strict JSON array items must be separated by a comma.",
				pointer,
				_make_current_span()
			)
			break
		var _comma_codepoint: int = _advance()
		_skip_whitespace()
		if _peek() == 93:
			_set_error(
				&"invalid_json",
				"Strict JSON does not allow a trailing comma in an array.",
				pointer,
				_make_current_span()
			)
			break
	return result


## 解码字符串并拒绝原始控制字符及未配对代理码位；闭合后按 UTF-8 字节检查单字符串预算，再累加成功字符串的字节统计。
## [br]
## @api private
func _parse_string(pointer: String) -> String:
	var start_index: int = _index
	var start_line: int = _line
	var start_column: int = _column
	var fragments: PackedStringArray = PackedStringArray()
	var _opening_quote: int = _advance()
	while _index < _text_length and not _has_error():
		var codepoint: int = _peek()
		if codepoint == 34:
			var _closing_quote: int = _advance()
			var result: String = "".join(fragments)
			var byte_count: int = result.to_utf8_buffer().size()
			if byte_count > _max_string_bytes:
				_set_budget_error(
					"JSON string exceeds max_string_bytes.",
					pointer,
					_make_span(
						start_index,
						start_line,
						start_column,
						_index,
						_line,
						_column
					)
				)
				return ""
			_string_byte_count += byte_count
			return result
		if codepoint < 32:
			_set_error(
				&"invalid_json",
				"Strict JSON strings cannot contain raw control characters.",
				pointer,
				_make_current_span()
			)
			break
		if codepoint == 92:
			var _escape_prefix: int = _advance()
			_parse_escape(fragments, pointer)
			continue
		if codepoint >= 0xD800 and codepoint <= 0xDFFF:
			_set_error(
				&"invalid_unicode_escape",
				"Strict JSON strings cannot contain an unpaired surrogate.",
				pointer,
				_make_current_span()
			)
			break
		var _append_result: bool = fragments.append(String.chr(codepoint))
		var _raw_codepoint: int = _advance()
	if not _has_error():
		_set_error(
			&"invalid_json",
			"Strict JSON string is not terminated.",
			pointer,
			_make_span(start_index, start_line, start_column, _index, _line, _column)
		)
	return ""


## 把合法 JSON 转义追加到共享片段数组；Unicode 高代理必须紧随低代理并合成码点，孤立代理和非法转义立即记录错误。
## [br]
## @api private
func _parse_escape(fragments: PackedStringArray, pointer: String) -> void:
	var escape_codepoint: int = _peek()
	if escape_codepoint < 0:
		_set_error(
			&"invalid_json",
			"Strict JSON string ends after an escape prefix.",
			pointer,
			_make_current_span()
		)
		return
	var _escaped_codepoint: int = _advance()
	match escape_codepoint:
		34, 47, 92:
			var _append_literal_result: bool = fragments.append(String.chr(escape_codepoint))
		98:
			var _append_backspace_result: bool = fragments.append(String.chr(8))
		102:
			var _append_form_feed_result: bool = fragments.append(String.chr(12))
		110:
			var _append_newline_result: bool = fragments.append("\n")
		114:
			var _append_carriage_return_result: bool = fragments.append("\r")
		116:
			var _append_tab_result: bool = fragments.append("\t")
		117:
			var first_codepoint: int = _read_hex_quad(pointer)
			if _has_error():
				return
			if first_codepoint >= 0xD800 and first_codepoint <= 0xDBFF:
				if _peek() != 92 or _peek(1) != 117:
					_set_error(
						&"invalid_unicode_escape",
						"A high surrogate must be followed by a low surrogate escape.",
						pointer,
						_make_current_span()
					)
					return
				var _low_escape_prefix: int = _advance()
				var _low_escape_marker: int = _advance()
				var low_codepoint: int = _read_hex_quad(pointer)
				if _has_error():
					return
				if low_codepoint < 0xDC00 or low_codepoint > 0xDFFF:
					_set_error(
						&"invalid_unicode_escape",
						"A high surrogate must be followed by a low surrogate escape.",
						pointer,
						_make_current_span()
					)
					return
				var scalar_value: int = (
					0x10000
					+ ((first_codepoint - 0xD800) << 10)
					+ (low_codepoint - 0xDC00)
				)
				var _append_pair_result: bool = fragments.append(String.chr(scalar_value))
			elif first_codepoint >= 0xDC00 and first_codepoint <= 0xDFFF:
				_set_error(
					&"invalid_unicode_escape",
					"A low surrogate cannot appear without a preceding high surrogate.",
					pointer,
					_make_current_span()
				)
			else:
				var _append_unicode_result: bool = fragments.append(String.chr(first_codepoint))
		_:
			_set_error(
				&"invalid_json",
				"Strict JSON string contains an unsupported escape sequence.",
				pointer,
				_make_current_span()
			)


## 从当前位置读取四个十六进制数字并组合为整数；遇到非十六进制字符时设置 Unicode 错误。
## [br]
## @api private
## [br]
func _read_hex_quad(pointer: String) -> int:
	var result: int = 0
	for _offset: int in range(4):
		var codepoint: int = _peek()
		var digit: int = _hex_digit_value(codepoint)
		if digit < 0:
			_set_error(
				&"invalid_unicode_escape",
				"Unicode escapes must contain exactly four hexadecimal digits.",
				pointer,
				_make_current_span()
			)
			return 0
		result = (result << 4) | digit
		var _hex_codepoint: int = _advance()
	return result


## 先验证 JSON 数字语法，再分别按有符号 64 位整数或有限浮点路径转换；越界、非有限及不受支持的非零下溢都返回错误空值。
## [br]
## @api private
func _parse_number(pointer: String) -> Variant:
	var start_index: int = _index
	var start_line: int = _line
	var start_column: int = _column
	if _peek() == 45:
		var _minus_codepoint: int = _advance()
	if _peek() == 48:
		var _zero_codepoint: int = _advance()
		if _is_digit(_peek()):
			_set_error(
				&"invalid_json",
				"Strict JSON numbers cannot contain a leading zero.",
				pointer,
				_make_current_span()
			)
			return null
	elif _peek() >= 49 and _peek() <= 57:
		_advance_digits()
	else:
		_set_error(
			&"invalid_json",
			"Strict JSON number is missing its integer component.",
			pointer,
			_make_current_span()
		)
		return null
	var has_fraction_or_exponent: bool = false
	if _peek() == 46:
		has_fraction_or_exponent = true
		var _decimal_point: int = _advance()
		if not _is_digit(_peek()):
			_set_error(
				&"invalid_json",
				"Strict JSON fraction must contain at least one digit.",
				pointer,
				_make_current_span()
			)
			return null
		_advance_digits()
	if _peek() == 69 or _peek() == 101:
		has_fraction_or_exponent = true
		var _exponent_marker: int = _advance()
		if _peek() == 43 or _peek() == 45:
			var _exponent_sign: int = _advance()
		if not _is_digit(_peek()):
			_set_error(
				&"invalid_json",
				"Strict JSON exponent must contain at least one digit.",
				pointer,
				_make_current_span()
			)
			return null
		_advance_digits()
	var token: String = _text.substr(start_index, _index - start_index)
	if not has_fraction_or_exponent:
		if not _is_supported_int64_token(token):
			_set_error(
				&"number_out_of_range",
				"JSON integer is outside the supported signed 64-bit domain.",
				pointer,
				_make_span(start_index, start_line, start_column, _index, _line, _column)
			)
			return null
		return token.to_int()
	var float_result: Dictionary = _convert_finite_float_token(token)
	if not GFVariantData.get_option_bool(float_result, "ok"):
		_set_error(
			&"non_finite_number",
			"JSON number is outside the supported finite float domain.",
			pointer,
			_make_span(start_index, start_line, start_column, _index, _line, _column)
		)
		return null
	return GFVariantData.get_option_float(float_result, "value")


## 判断已通过整数词法分析的 token 是否落在有符号 64 位整数范围内。
## [br]
## @api private
## [br]
func _is_supported_int64_token(token: String) -> bool:
	var negative: bool = token.begins_with("-")
	var digits: String = token.substr(1) if negative else token
	var boundary: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() != boundary.length():
		return digits.length() < boundary.length()
	return _compare_decimal_digits(digits, boundary) <= 0


## 将已通过词法检查的数字归一为有界科学计数文本，截断有效位时保留非零尾部标记；拒绝超出支持指数范围、非有限或非零变零的结果。
## [br]
## @api private
func _convert_finite_float_token(token: String) -> Dictionary:
	var negative: bool = token.begins_with("-")
	var unsigned_token: String = token.substr(1) if token.begins_with("-") else token
	var exponent_index: int = unsigned_token.find("e")
	if exponent_index < 0:
		exponent_index = unsigned_token.find("E")
	var mantissa: String = unsigned_token
	var explicit_exponent: int = 0
	if exponent_index >= 0:
		mantissa = unsigned_token.substr(0, exponent_index)
		var exponent_text: String = unsigned_token.substr(exponent_index + 1)
		var exponent_negative: bool = exponent_text.begins_with("-")
		if exponent_text.begins_with("+") or exponent_negative:
			exponent_text = exponent_text.substr(1)
		explicit_exponent = _read_saturating_decimal_exponent(
			exponent_text,
			exponent_negative,
			token.length() + 1024
		)
	var decimal_index: int = mantissa.find(".")
	var digits_before_decimal: int = mantissa.length() if decimal_index < 0 else decimal_index
	var digits: String = mantissa.replace(".", "")
	var first_nonzero: int = _find_first_nonzero_digit(digits)
	if first_nonzero < 0:
		return {
			"ok": true,
			"value": -0.0 if negative else 0.0,
		}
	var normalized_exponent: int = (
		digits_before_decimal
		- first_nonzero
		- 1
		+ explicit_exponent
	)
	if normalized_exponent > 308 or normalized_exponent < -307:
		return { "ok": false }
	var significant_digits: String = digits.substr(first_nonzero)
	if normalized_exponent == 308:
		var comparable_prefix: String = significant_digits.substr(
			0,
			mini(significant_digits.length(), _MAX_FLOAT_DECIMAL_PREFIX.length())
		)
		while comparable_prefix.length() < _MAX_FLOAT_DECIMAL_PREFIX.length():
			comparable_prefix += "0"
		if _compare_decimal_digits(comparable_prefix, _MAX_FLOAT_DECIMAL_PREFIX) > 0:
			return { "ok": false }
	var canonical_digits: String = significant_digits.substr(
		0,
		mini(significant_digits.length(), _MAX_FLOAT_SIGNIFICANT_DIGITS)
	)
	if (
		significant_digits.length() > _MAX_FLOAT_SIGNIFICANT_DIGITS
		and _contains_nonzero_digit(significant_digits, _MAX_FLOAT_SIGNIFICANT_DIGITS)
	):
		canonical_digits += "1"
	var canonical_token: String = "-" if negative else ""
	canonical_token += canonical_digits.left(1)
	canonical_token += "."
	canonical_token += canonical_digits.substr(1) if canonical_digits.length() > 1 else "0"
	canonical_token += "e%d" % normalized_exponent
	var number: float = canonical_token.to_float()
	if is_nan(number) or is_inf(number) or number == 0.0:
		return { "ok": false }
	return {
		"ok": true,
		"value": number,
	}


## 累加十进制指数，并在绝对值超过 saturation 后停止累加并返回带符号结果。
## [br]
## @api private
## [br]
func _read_saturating_decimal_exponent(
	digits: String,
	negative: bool,
	saturation: int
) -> int:
	var value: int = 0
	for index: int in range(digits.length()):
		var digit: int = digits.unicode_at(index) - 48
		value = value * 10 + digit
		if value > saturation:
			value = saturation + 1
			break
	return -value if negative else value


## 返回十进制字符串中首个非零数字的索引；全为零时返回 -1。
## [br]
## @api private
## [br]
func _find_first_nonzero_digit(digits: String) -> int:
	for index: int in range(digits.length()):
		if digits.unicode_at(index) != 48:
			return index
	return -1


## 检查从 start_index 开始的十进制字符串后缀是否含非零数字。
## [br]
## @api private
## [br]
func _contains_nonzero_digit(digits: String, start_index: int) -> bool:
	for index: int in range(start_index, digits.length()):
		if digits.unicode_at(index) != 48:
			return true
	return false


## 按十进制数字逐位并结合长度比较两个数字串，返回 -1、0 或 1。
## [br]
## @api private
## [br]
func _compare_decimal_digits(left: String, right: String) -> int:
	for index: int in range(mini(left.length(), right.length())):
		var left_digit: int = left.unicode_at(index)
		var right_digit: int = right.unicode_at(index)
		if left_digit < right_digit:
			return -1
		if left_digit > right_digit:
			return 1
	if left.length() < right.length():
		return -1
	if left.length() > right.length():
		return 1
	return 0


## 匹配当前位置起的 keyword；发现不同字符时设置 invalid_json，否则返回对应 Variant 值。
## [br]
## @api private
## [br]
func _parse_keyword(keyword: String, value: Variant, pointer: String) -> Variant:
	for offset: int in range(keyword.length()):
		if _peek() != keyword.unicode_at(offset):
			_set_error(
				&"invalid_json",
				"Strict JSON contains an invalid literal.",
				pointer,
				_make_current_span()
			)
			return null
		var _literal_codepoint: int = _advance()
	return value


## 连续消费当前位置的 ASCII 十进制数字。
## [br]
## @api private
## [br]
func _advance_digits() -> void:
	while _is_digit(_peek()):
		var _digit_codepoint: int = _advance()


## 在 max_nodes 预算内递增节点数；超限时用给定位置设置 input_budget_exceeded。
## [br]
## @api private
## [br]
func _reserve_node(pointer: String, line: int, column: int) -> bool:
	if _node_count >= _max_nodes:
		_set_budget_error(
			"JSON structure exceeds max_nodes.",
			pointer,
			{
				"line": line,
				"column": column,
				"length": 1,
				"end_line": line,
				"end_column": column + 1,
			}
		)
		return false
	_node_count += 1
	return true


## 跳过当前 JSON 语法允许的空白字符。
## [br]
## @api private
## [br]
func _skip_whitespace() -> void:
	while _is_json_whitespace(_peek()):
		var _whitespace_codepoint: int = _advance()


## 读取游标偏移处的 Unicode codepoint；目标索引越界时返回 -1。
## [br]
## @api private
## [br]
func _peek(offset: int = 0) -> int:
	var target_index: int = _index + offset
	if target_index < 0 or target_index >= _text_length:
		return -1
	return _text.unicode_at(target_index)


## 消费一个字符串码点并更新行列；CRLF 视为一次换行，单独 CR 或 LF 也换行，到达输入末尾返回 -1。
## [br]
## @api private
func _advance() -> int:
	if _index >= _text_length:
		return -1
	var codepoint: int = _text.unicode_at(_index)
	_index += 1
	if codepoint == 13:
		_line += 1
		_column = 1
		_previous_was_cr = true
	elif codepoint == 10:
		if not _previous_was_cr:
			_line += 1
		_column = 1
		_previous_was_cr = false
	else:
		_column += 1
		_previous_was_cr = false
	return codepoint


## 将 token 中的 ~ 与 / 按 JSON Pointer 规则转义后追加到父路径。
## [br]
## @api private
## [br]
func _append_pointer(parent: String, token: String) -> String:
	var escaped_token: String = token.replace("~", "~0").replace("/", "~1")
	return "%s/%s" % [parent, escaped_token]


## 将预算失败记录为 input_budget_exceeded，并附上当前节点和字符串字节计数。
## [br]
## @api private
## [br]
func _set_budget_error(message: String, pointer: String, span: Dictionary) -> void:
	_set_error(&"input_budget_exceeded", message, pointer, span, {
		"node_count": _node_count,
		"string_byte_count": _string_byte_count,
	})


## 只在 _error 为空时写入首个错误，并深复制 span 与 metadata。
## [br]
## @api private
## [br]
func _set_error(
	kind: StringName,
	message: String,
	pointer: String,
	span: Dictionary,
	metadata: Dictionary = {}
) -> void:
	if _has_error():
		return
	_error = {
		"error_kind": kind,
		"error": message,
		"pointer": pointer,
		"span": span.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 组合解析失败报告，保留已收集片段映射、计数和首个错误字段。
## [br]
## @api private
## [br]
func _make_failure_result() -> Dictionary:
	return {
		"ok": false,
		"value": null,
		"value_spans": _value_spans.duplicate(true),
		"key_spans": _key_spans.duplicate(true),
		"node_count": _node_count,
		"string_byte_count": _string_byte_count,
		"error_kind": GFVariantData.get_option_string_name(_error, "error_kind", &"invalid_json"),
		"error": GFVariantData.get_option_string(_error, "error", "Strict JSON parsing failed."),
		"pointer": GFVariantData.get_option_string(_error, "pointer"),
		"span": GFVariantData.get_option_dictionary(_error, "span"),
		"metadata": GFVariantData.get_option_dictionary(_error, "metadata"),
	}


## 为当前位置构造一个码点宽的诊断范围；即使位于输入末尾也保留该占位宽度。
## [br]
## @api private
func _make_current_span() -> Dictionary:
	return {
		"line": _line,
		"column": _column,
		"length": 1,
		"end_line": _line,
		"end_column": _column + 1,
	}


## 用起止行列构造范围；单行 length 使用字符串索引差，多行 length 置零并依赖显式结束位置。
## [br]
## @api private
func _make_span(
	start_index: int,
	start_line: int,
	start_column: int,
	end_index: int,
	end_line: int,
	end_column: int
) -> Dictionary:
	return {
		"line": start_line,
		"column": start_column,
		"length": maxi(end_index - start_index, 0) if start_line == end_line else 0,
		"end_line": end_line,
		"end_column": end_column,
	}


## 读取限制字典中的整数选项，并将缺失或小于 1 的值限制为 1。
## [br]
## @api private
## [br]
func _read_positive_limit(limits: Dictionary, key: String) -> int:
	return maxi(GFVariantData.get_option_int(limits, key, 1), 1)


## 判断首个错误字典是否已被设置。
## [br]
## @api private
## [br]
func _has_error() -> bool:
	return not _error.is_empty()


## 判断 codepoint 是否为 ASCII 数字 0–9。
## [br]
## @api private
## [br]
func _is_digit(codepoint: int) -> bool:
	return codepoint >= 48 and codepoint <= 57


## 将 ASCII 十六进制数字转换为 0–15；其他 codepoint 返回 -1。
## [br]
## @api private
## [br]
func _hex_digit_value(codepoint: int) -> int:
	if codepoint >= 48 and codepoint <= 57:
		return codepoint - 48
	if codepoint >= 65 and codepoint <= 70:
		return codepoint - 65 + 10
	if codepoint >= 97 and codepoint <= 102:
		return codepoint - 97 + 10
	return -1


## 判断 codepoint 是否为 JSON 空白 HT、LF、CR 或空格。
## [br]
## @api private
## [br]
func _is_json_whitespace(codepoint: int) -> bool:
	return codepoint in [9, 10, 13, 32]
