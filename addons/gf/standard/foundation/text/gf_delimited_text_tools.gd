## GFDelimitedTextTools: 顶层分隔符扫描工具。
##
## 用于把函数参数、轻量命令或配置片段按分隔符拆分，同时忽略引号与括号内的分隔符。
## 该类只做纯文本扫描，不解释 SQL、表达式、对象方法或项目业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFDelimitedTextTools
extends RefCounted


# --- 常量 ---

## 按字面量分隔符扫描。
## [br]
## @api public
## [br]
## @since 8.0.0
const DELIMITER_MODE_LITERAL: StringName = &"literal"

## 按连续空白字符扫描分隔符；空白字符包括空格、制表、换行和回车。
## [br]
## @api public
## [br]
## @since 8.0.0
const DELIMITER_MODE_WHITESPACE: StringName = &"whitespace"

## 分隔符为空。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_INVALID_DELIMITER: StringName = &"invalid_delimiter"

## 遇到没有匹配开启符的关闭符。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_UNMATCHED_CLOSING: StringName = &"unmatched_closing"

## 扫描结束时仍有未关闭的引号或括号。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_UNMATCHED_OPENING: StringName = &"unmatched_opening"

const _DEFAULT_QUOTE_CHARS: String = "\"'"
const _DEFAULT_ESCAPE_CHAR: String = "\\"
const _DEFAULT_DELIMITER: String = ","
const _DEFAULT_PAIRS: Dictionary = {
	"(": ")",
	"[": "]",
	"{": "}",
}


# --- 公共方法 ---

## 查找顶层分隔符位置。
## [br]
## 分隔符只有在不处于 quote_chars 或 pairs 管理的嵌套区间内时才会被记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param text: 要扫描的文本。
## [br]
## @param delimiter: 字面量分隔符；delimiter_mode 为 whitespace 时会被忽略。
## [br]
## @param options: 可选扫描配置。
## [br]
## @return 扫描报告。
## [br]
## @schema options: Dictionary，可包含 delimiter_mode、quote_chars、escape_char 和 pairs。
## [br]
## @schema return: Dictionary，包含 ok、error、delimiter_mode、delimiter、delimiter_spans、issues 和 issue_count。
static func find_top_level_delimiters(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:
	return _scan_top_level_delimiters(text, delimiter, options)


## 按顶层分隔符拆分文本。
## [br]
## 分隔符出现在引号、圆括号、方括号或花括号内时不会触发拆分。调用方可通过 pairs 或
## quote_chars 改写扫描规则。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param text: 要拆分的文本。
## [br]
## @param delimiter: 字面量分隔符；delimiter_mode 为 whitespace 时会被忽略。
## [br]
## @param options: 可选拆分配置。
## [br]
## @return 拆分报告。
## [br]
## @schema options: Dictionary，可包含 delimiter_mode、trim_parts、allow_empty、quote_chars、escape_char 和 pairs。
## [br]
## @schema return: Dictionary，包含 ok、error、delimiter_mode、delimiter、parts、part_spans、delimiter_spans、issues 和 issue_count。
static func split_top_level(text: String, delimiter: String = _DEFAULT_DELIMITER, options: Dictionary = {}) -> Dictionary:
	var scan: Dictionary = _scan_top_level_delimiters(text, delimiter, options)
	if GFVariantData.get_option_string_name(scan, "error") == ERROR_INVALID_DELIMITER:
		scan["parts"] = []
		scan["part_spans"] = []
		return scan

	var trim_parts: bool = GFVariantData.get_option_bool(options, "trim_parts", false)
	var allow_empty: bool = GFVariantData.get_option_bool(options, "allow_empty", true)
	var delimiter_spans: Array[Vector2i] = _to_vector2i_array(scan.get("delimiter_spans", []))
	var parts: Array[String] = []
	var part_spans: Array[Vector2i] = []
	var start_index: int = 0

	for delimiter_span: Vector2i in delimiter_spans:
		_append_part(text, start_index, delimiter_span.x, trim_parts, allow_empty, parts, part_spans)
		start_index = delimiter_span.y
	_append_part(text, start_index, text.length(), trim_parts, allow_empty, parts, part_spans)

	scan["parts"] = parts
	scan["part_spans"] = part_spans
	return scan


# --- 私有/辅助方法 ---

static func _scan_top_level_delimiters(text: String, delimiter: String, options: Dictionary) -> Dictionary:
	var mode: StringName = _resolve_delimiter_mode(options)
	var effective_delimiter: String = "\\s" if mode == DELIMITER_MODE_WHITESPACE else delimiter
	var issues: Array[Dictionary] = []
	var delimiter_spans: Array[Vector2i] = []
	if mode == DELIMITER_MODE_LITERAL and delimiter.is_empty():
		issues.append(_make_issue(ERROR_INVALID_DELIMITER, 0, "", "", ""))
		return _make_scan_report(false, ERROR_INVALID_DELIMITER, mode, effective_delimiter, delimiter_spans, issues)

	var quote_chars: String = GFVariantData.get_option_string(options, "quote_chars", _DEFAULT_QUOTE_CHARS)
	var escape_char: String = GFVariantData.get_option_string(options, "escape_char", _DEFAULT_ESCAPE_CHAR)
	var pairs: Dictionary = _normalize_pairs(GFVariantData.get_option_dictionary(options, "pairs", _DEFAULT_PAIRS))
	var closing_to_opening: Dictionary = _make_closing_to_opening(pairs)
	var stack: Array[Dictionary] = []
	var index: int = 0

	while index < text.length():
		var character: String = text.substr(index, 1)
		if stack.is_empty():
			var delimiter_span: Vector2i = _match_delimiter(text, index, effective_delimiter, mode)
			if delimiter_span.y > delimiter_span.x:
				delimiter_spans.append(delimiter_span)
				index = delimiter_span.y
				continue

		if not stack.is_empty() and _is_stack_top_quote(stack):
			if not escape_char.is_empty() and character == escape_char and index + 1 < text.length():
				index += 2
				continue
			if character == _stack_top_close(stack):
				stack.remove_at(stack.size() - 1)
			index += 1
			continue

		if _is_quote_character(character, quote_chars):
			stack.append(_make_stack_entry(character, character, index, true))
		elif pairs.has(character):
			stack.append(_make_stack_entry(character, GFVariantData.to_text(pairs[character]), index, false))
		elif closing_to_opening.has(character):
			if stack.is_empty() or _stack_top_close(stack) != character:
				issues.append(_make_issue(
					ERROR_UNMATCHED_CLOSING,
					index,
					GFVariantData.to_text(closing_to_opening[character]),
					character,
					""
				))
			else:
				stack.remove_at(stack.size() - 1)
		index += 1

	for entry: Dictionary in stack:
		issues.append(_make_issue(
			ERROR_UNMATCHED_OPENING,
			GFVariantData.get_option_int(entry, "index", -1),
			GFVariantData.get_option_string(entry, "open"),
			"",
			GFVariantData.get_option_string(entry, "close")
		))

	return _make_scan_report(issues.is_empty(), _first_issue_kind(issues), mode, effective_delimiter, delimiter_spans, issues)


static func _append_part(
	text: String,
	start_index: int,
	end_index: int,
	trim_parts: bool,
	allow_empty: bool,
	parts: Array[String],
	part_spans: Array[Vector2i]
) -> void:
	var clamped_start: int = clampi(start_index, 0, text.length())
	var clamped_end: int = clampi(end_index, clamped_start, text.length())
	var part: String = text.substr(clamped_start, clamped_end - clamped_start)
	if trim_parts:
		part = part.strip_edges()
	if not allow_empty and part.is_empty():
		return
	parts.append(part)
	part_spans.append(Vector2i(clamped_start, clamped_end))


static func _resolve_delimiter_mode(options: Dictionary) -> StringName:
	var mode: StringName = GFVariantData.get_option_string_name(options, "delimiter_mode", DELIMITER_MODE_LITERAL)
	if mode == DELIMITER_MODE_WHITESPACE:
		return mode
	return DELIMITER_MODE_LITERAL


static func _match_delimiter(text: String, index: int, delimiter: String, mode: StringName) -> Vector2i:
	if mode == DELIMITER_MODE_WHITESPACE:
		if not _is_whitespace(text.substr(index, 1)):
			return Vector2i(index, index)
		var end_index: int = index + 1
		while end_index < text.length() and _is_whitespace(text.substr(end_index, 1)):
			end_index += 1
		return Vector2i(index, end_index)
	if delimiter.is_empty():
		return Vector2i(index, index)
	if index + delimiter.length() > text.length():
		return Vector2i(index, index)
	if text.substr(index, delimiter.length()) == delimiter:
		return Vector2i(index, index + delimiter.length())
	return Vector2i(index, index)


static func _normalize_pairs(raw_pairs: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in raw_pairs.keys():
		var open_text: String = GFVariantData.to_text(raw_key)
		var close_text: String = GFVariantData.to_text(raw_pairs[raw_key])
		if open_text.is_empty() or close_text.is_empty():
			continue
		result[open_text.substr(0, 1)] = close_text.substr(0, 1)
	return result


static func _make_closing_to_opening(pairs: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in pairs.keys():
		var open_text: String = GFVariantData.to_text(raw_key)
		var close_text: String = GFVariantData.to_text(pairs[raw_key])
		if open_text.is_empty() or close_text.is_empty():
			continue
		result[close_text] = open_text
	return result


static func _is_quote_character(character: String, quote_chars: String) -> bool:
	return not character.is_empty() and quote_chars.find(character) >= 0


static func _is_whitespace(character: String) -> bool:
	return character == " " or character == "\t" or character == "\n" or character == "\r"


static func _make_stack_entry(open_text: String, close_text: String, index: int, is_quote: bool) -> Dictionary:
	return {
		"open": open_text,
		"close": close_text,
		"index": index,
		"is_quote": is_quote,
	}


static func _is_stack_top_quote(stack: Array[Dictionary]) -> bool:
	if stack.is_empty():
		return false
	var entry: Dictionary = stack[stack.size() - 1]
	return GFVariantData.get_option_bool(entry, "is_quote", false)


static func _stack_top_close(stack: Array[Dictionary]) -> String:
	if stack.is_empty():
		return ""
	var entry: Dictionary = stack[stack.size() - 1]
	return GFVariantData.get_option_string(entry, "close")


static func _make_issue(
	kind: StringName,
	index: int,
	expected: String,
	actual: String,
	open_close: String
) -> Dictionary:
	return {
		"kind": kind,
		"index": index,
		"expected": expected,
		"actual": actual,
		"close": open_close,
	}


static func _make_scan_report(
	ok: bool,
	error: StringName,
	mode: StringName,
	delimiter: String,
	delimiter_spans: Array[Vector2i],
	issues: Array[Dictionary]
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"delimiter_mode": mode,
		"delimiter": delimiter,
		"delimiter_spans": delimiter_spans,
		"issues": issues,
		"issue_count": issues.size(),
	}


static func _first_issue_kind(issues: Array[Dictionary]) -> StringName:
	if issues.is_empty():
		return &""
	var first_issue: Dictionary = issues[0]
	return GFVariantData.get_option_string_name(first_issue, "kind")


static func _to_vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not value is Array:
		return result
	var raw_array: Array = value
	for item: Variant in raw_array:
		if item is Vector2i:
			var span: Vector2i = item
			result.append(span)
	return result
