## GFRichTextFormatter: 通用 RichTextLabel BBCode 格式化辅助。
##
## 提供安全转义、Markdown 子集转 BBCode、变量占位符替换和可配置 token 替换。
## 该类不加载任何资源，不规定文本来源、语言、本地化、图标集或 UI 展示规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRichTextFormatter
extends RefCounted


# --- 常量 ---

## BBCode 输入模式。
## [br]
## @api public
const MARKUP_BBCODE: StringName = &"bbcode"

## 普通文本输入模式，会先转义 BBCode 控制字符。
## [br]
## @api public
const MARKUP_PLAIN: StringName = &"plain"

## Markdown 子集输入模式，会转换为 RichTextLabel BBCode。
## [br]
## @api public
const MARKUP_MARKDOWN: StringName = &"markdown"

## strip_bbcode() 移除标签期间用于暂存已转义左方括号的占位文本。
## [br]
## @api private
const _STRIP_LEFT_BRACKET_PLACEHOLDER: String = "__GF_ESCAPED_LEFT_BRACKET__"

## strip_bbcode() 移除标签期间用于暂存已转义右方括号的占位文本。
## [br]
## @api private
const _STRIP_RIGHT_BRACKET_PLACEHOLDER: String = "__GF_ESCAPED_RIGHT_BRACKET__"


# --- 公共方法 ---

## 格式化文本为 RichTextLabel 可用的 BBCode。
## [br]
## @api public
## [br]
## @param text: 原始文本。
## [br]
## @param options: 可选设置，支持 markup、variables、variable_resolver、variable_prefix、variable_suffix、token_resolver、token_prefix、token_suffix。
## [br]
## @return BBCode 文本。
## [br]
## @schema options: Dictionary，支持 markup、variables、variable_resolver、variable_prefix、variable_suffix、escape_variable_values、missing_variable_text、token_resolver、token_prefix、token_suffix、escape_token_values。
static func to_bbcode(text: String, options: Dictionary = {}) -> String:
	var markup: StringName = _get_option_string_name(options, "markup", MARKUP_BBCODE)
	var result: String = text

	match markup:
		MARKUP_PLAIN:
			result = escape_bbcode(result)
		MARKUP_MARKDOWN:
			result = markdown_to_bbcode(result)
		_:
			pass

	var raw_variables: Variant = GFVariantData.get_option_value(options, "variables", {})
	var variables: Dictionary = GFVariantData.as_dictionary(raw_variables)
	var variable_resolver: Callable = _get_callable_option(options, "variable_resolver")
	if not variables.is_empty() or variable_resolver.is_valid():
		result = replace_variables(result, variables, variable_resolver, options)

	var token_resolver: Callable = _get_callable_option(options, "token_resolver")
	if token_resolver.is_valid():
		result = replace_tokens(result, token_resolver, options)

	return result


## 把常见 Markdown 子集转换为 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @param text: Markdown 文本。
## [br]
## @return BBCode 文本。
static func markdown_to_bbcode(text: String) -> String:
	var pattern: String = (
		"!\\[([^\\]]*)\\]\\(([^\\)]+)\\)"
		+ "|\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
		+ "|`([^`]+)`"
		+ "|\\*\\*([^\\*]+)\\*\\*"
		+ "|\\*([^\\*]+)\\*"
		+ "|~~([^~]+)~~"
	)
	return _replace_regex_matches(text, pattern, func(match_result: RegExMatch) -> String:
		if not match_result.get_string(2).is_empty():
			return "[img]%s[/img]" % escape_bbcode(match_result.get_string(2))
		if not match_result.get_string(4).is_empty():
			return "[url=%s]%s[/url]" % [
				escape_bbcode(match_result.get_string(4)),
				escape_bbcode(match_result.get_string(3)),
			]
		if not match_result.get_string(5).is_empty():
			return "[code]%s[/code]" % escape_bbcode(match_result.get_string(5))
		if not match_result.get_string(6).is_empty():
			return "[b]%s[/b]" % escape_bbcode(match_result.get_string(6))
		if not match_result.get_string(7).is_empty():
			return "[i]%s[/i]" % escape_bbcode(match_result.get_string(7))
		if not match_result.get_string(8).is_empty():
			return "[s]%s[/s]" % escape_bbcode(match_result.get_string(8))
		return escape_bbcode(match_result.get_string(0))
	)


## 替换变量占位符。
## [br]
## @api public
## [br]
## @param text: 输入文本。
## [br]
## @param variables: 变量字典。
## [br]
## @param resolver: 可选变量解析回调，签名为 func(name: String) -> Variant。
## [br]
## @param options: 可选设置，支持 variable_prefix、variable_suffix、escape_variable_values、missing_variable_text。
## [br]
## @return 替换后的文本。
## [br]
## @schema variables: Dictionary，key 为变量名 String，value 为会转成文本的任意值。
## [br]
## @schema options: Dictionary，支持 variable_prefix、variable_suffix、escape_variable_values、missing_variable_text。
static func replace_variables(
	text: String,
	variables: Dictionary = {},
	resolver: Callable = Callable(),
	options: Dictionary = {}
) -> String:
	var prefix: String = _get_option_text(options, "variable_prefix", "{{")
	var suffix: String = _get_option_text(options, "variable_suffix", "}}")
	var escape_values: bool = _get_option_bool(options, "escape_variable_values", true)
	var missing_text: String = _get_option_text(options, "missing_variable_text", "")
	return _replace_wrapped_segments(
		text,
		prefix,
		suffix,
		func(token: String) -> String:
			var value: Variant = null
			var has_value: bool = false
			if resolver.is_valid():
				value = resolver.call(token)
				has_value = value != null
			if not has_value and variables.has(token):
				value = variables[token]
				has_value = true
			if not has_value:
				return missing_text

			var value_text: String = str(value)
			return escape_bbcode(value_text) if escape_values else value_text
	)


## 替换可配置 token，例如 `:icon_id:`。
## [br]
## @api public
## [br]
## @param text: 输入文本。
## [br]
## @param resolver: token 解析回调，签名为 func(token: String) -> String。
## [br]
## @param options: 可选设置，支持 token_prefix、token_suffix、escape_token_values。
## [br]
## @return 替换后的文本。
## [br]
## @schema options: Dictionary，支持 token_prefix、token_suffix、escape_token_values。
static func replace_tokens(text: String, resolver: Callable, options: Dictionary = {}) -> String:
	if not resolver.is_valid():
		return text

	var prefix: String = _get_option_text(options, "token_prefix", ":")
	var suffix: String = _get_option_text(options, "token_suffix", ":")
	var escape_values: bool = _get_option_bool(options, "escape_token_values", false)
	return _replace_wrapped_segments(
		text,
		prefix,
		suffix,
		func(token: String) -> String:
			if not _is_safe_token(token):
				return prefix + token + suffix

			var raw_resolved: Variant = resolver.call(token)
			if raw_resolved == null:
				return prefix + token + suffix

			var resolved: String = GFVariantData.to_text(raw_resolved)
			if resolved.is_empty():
				return prefix + token + suffix
			return escape_bbcode(resolved) if escape_values else resolved
	)


## 转义 BBCode 控制字符。
## [br]
## @api public
## [br]
## @param text: 输入文本。
## [br]
## @return 可安全嵌入 BBCode 的文本。
static func escape_bbcode(text: String) -> String:
	var result: String = ""
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == "[":
			result += "[lb]"
		elif character == "]":
			result += "[rb]"
		else:
			result += character
	return result


## 移除 BBCode 标签。
## [br]
## @api public
## [br]
## @param text: 输入文本。
## [br]
## @return 去掉标签后的文本。
static func strip_bbcode(text: String) -> String:
	var regex: RegEx = RegEx.new()
	var error: Error = regex.compile("\\[[^\\]]*\\]")
	if error != OK:
		return text

	var protected_text: String = text
	protected_text = protected_text.replace("[lb]", _STRIP_LEFT_BRACKET_PLACEHOLDER)
	protected_text = protected_text.replace("[rb]", _STRIP_RIGHT_BRACKET_PLACEHOLDER)
	var stripped: String = regex.sub(protected_text, "", true)
	stripped = stripped.replace(_STRIP_LEFT_BRACKET_PLACEHOLDER, "[")
	stripped = stripped.replace(_STRIP_RIGHT_BRACKET_PLACEHOLDER, "]")
	return stripped


# --- 私有/辅助方法 ---

## 从 options 读取指定值；仅当值为 Callable 时返回，否则返回空回调。
## [br]
## @api private
static func _get_callable_option(options: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, key, Callable())
	if value is Callable:
		return value
	return Callable()


## 从 options 读取文本选项，并在缺键时返回 fallback。
## [br]
## @api private
static func _get_option_text(options: Dictionary, key: String, fallback: String) -> String:
	if not options.has(key):
		return fallback
	return GFVariantData.to_text(options[key], fallback)


## 从 options 读取布尔选项，并在缺键时返回 fallback。
## [br]
## @api private
static func _get_option_bool(options: Dictionary, key: String, fallback: bool) -> bool:
	if not options.has(key):
		return fallback
	return GFVariantData.to_bool(options[key], fallback)


## 从 options 读取 StringName 选项，并在缺键时返回 fallback。
## [br]
## @api private
static func _get_option_string_name(options: Dictionary, key: String, fallback: StringName) -> StringName:
	if not options.has(key):
		return fallback
	return GFVariantData.to_string_name(options[key], fallback)


## 编译正则表达式并逐个构建替换片段；编译失败或 builder 无效时原样返回输入。
## [br]
## @api private
static func _replace_regex_matches(text: String, pattern: String, replacement_builder: Callable) -> String:
	var regex: RegEx = RegEx.new()
	var error: Error = regex.compile(pattern)
	if error != OK or not replacement_builder.is_valid():
		return text

	var result: String = ""
	var cursor: int = 0
	for match_result: RegExMatch in regex.search_all(text):
		var start: int = match_result.get_start()
		var end: int = match_result.get_end()
		if start < cursor:
			continue

		result += escape_bbcode(text.substr(cursor, start - cursor))
		result += GFVariantData.to_text(replacement_builder.call(match_result))
		cursor = end

	result += escape_bbcode(text.substr(cursor))
	return result


## 使用前后缀定位片段并调用 resolver 替换；设置无效时原样返回输入。
## [br]
## @api private
static func _replace_wrapped_segments(
	text: String,
	prefix: String,
	suffix: String,
	resolver: Callable
) -> String:
	if prefix.is_empty() or suffix.is_empty() or not resolver.is_valid():
		return text

	var result: String = ""
	var cursor: int = 0
	while cursor < text.length():
		var start: int = text.find(prefix, cursor)
		if start < 0:
			result += text.substr(cursor)
			break

		var token_start: int = start + prefix.length()
		var end: int = text.find(suffix, token_start)
		if end < 0:
			result += text.substr(cursor)
			break

		result += text.substr(cursor, start - cursor)
		var token: String = text.substr(token_start, end - token_start)
		result += GFVariantData.to_text(resolver.call(token))
		cursor = end + suffix.length()

	return result


## 仅当 token 非空且每个字符都由 _is_safe_token_character() 接受时返回 true。
## [br]
## @api private
static func _is_safe_token(token: String) -> bool:
	if token.is_empty():
		return false

	for index: int in range(token.length()):
		var character: String = token.substr(index, 1)
		if not _is_safe_token_character(character):
			return false
	return true


## 接受 ASCII 字母、数字、下划线、连字符和句点。
## [br]
## @api private
static func _is_safe_token_character(character: String) -> bool:
	return (
		(character >= "a" and character <= "z")
		or (character >= "A" and character <= "Z")
		or (character >= "0" and character <= "9")
		or character == "_"
		or character == "-"
		or character == "."
	)
