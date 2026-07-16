## GFTextGenerationContext: 安全的纯数据文本生成上下文。
##
## 提供显式数据 scope、严格缺失检查、简单 token 替换、可选输出格式化、输出缓冲和预算诊断。
## token 只解析数据路径，不执行表达式、脚本或宿主对象方法。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFTextGenerationContext
extends RefCounted


# --- 公共变量 ---

## 缺失变量是否记录为错误。
## [br]
## @api public
## [br]
## @since 7.0.0
var strict_variables: bool = false

## 最大输出长度；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_output_length: int = 0

## 每级缩进使用的文本。
## [br]
## @api public
## [br]
## @since 7.0.0
var indent_text: String = "\t"

## 可选执行预算。
## [br]
## @api public
## [br]
## @since 7.0.0
var budget: GFExecutionBudget = null

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary，包含调用方定义的上下文。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _scopes: Array[Dictionary] = []
var _scope_labels: PackedStringArray = PackedStringArray()
var _output_parts: PackedStringArray = PackedStringArray()
var _output_length: int = 0
var _indent_level: int = 0
var _report: GFValidationReport = GFValidationReport.new("Text generation")


# --- Godot 生命周期方法 ---

## 创建文本生成上下文。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param root_values: 根数据 scope。
## [br]
## @param options: 可选配置，支持 strict_variables、max_output_length、indent_text、budget、subject 和 metadata。
## [br]
## @schema root_values: Dictionary，根数据。
## [br]
## @schema options: Dictionary，上下文配置。
func _init(root_values: Dictionary = {}, options: Dictionary = {}) -> void:
	var _configured_context: GFTextGenerationContext = configure(root_values, options)


# --- 公共方法 ---

## 配置上下文并清空输出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param root_values: 根数据 scope。
## [br]
## @param options: 可选配置，支持 strict_variables、max_output_length、indent_text、budget、subject 和 metadata。
## [br]
## @return 当前上下文。
## [br]
## @schema root_values: Dictionary，根数据。
## [br]
## @schema options: Dictionary，上下文配置。
func configure(root_values: Dictionary = {}, options: Dictionary = {}) -> GFTextGenerationContext:
	clear()
	strict_variables = GFVariantData.get_option_bool(options, "strict_variables", false)
	max_output_length = maxi(GFVariantData.get_option_int(options, "max_output_length", 0), 0)
	indent_text = GFVariantData.get_option_string(options, "indent_text", "\t")
	metadata = GFVariantData.get_option_dictionary(options, "metadata", {})

	var budget_value: Variant = GFVariantData.get_option_value(options, "budget", null)
	budget = _variant_to_budget(budget_value)
	_report = GFValidationReport.new(GFVariantData.get_option_string(options, "subject", "Text generation"), metadata)
	var _scope_depth: int = push_scope(root_values, "root")
	return self


## 清空 scope、输出和诊断。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_scopes.clear()
	_scope_labels.clear()
	_output_parts.clear()
	_output_length = 0
	_indent_level = 0
	_report = GFValidationReport.new("Text generation")


## 推入一个数据 scope。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param values: scope 数据。
## [br]
## @param label: scope 标签，仅用于诊断。
## [br]
## @return 当前 scope 数量。
## [br]
## @schema values: Dictionary，scope 数据。
func push_scope(values: Dictionary, label: String = "") -> int:
	_scopes.append(values.duplicate(true))
	var _label_append_result: bool = _scope_labels.append(label)
	return _scopes.size()


## 弹出顶层 scope。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 被移除的 scope；没有 scope 时返回空字典。
## [br]
## @schema return: Dictionary，被移除的 scope 数据。
func pop_scope() -> Dictionary:
	if _scopes.is_empty():
		return {}
	var scope: Dictionary = _scopes[_scopes.size() - 1]
	_scopes.remove_at(_scopes.size() - 1)
	_scope_labels.remove_at(_scope_labels.size() - 1)
	return scope


## 设置顶层 scope 的值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 字段名。
## [br]
## @param value: 字段值。
## [br]
## @schema value: Variant，调用方数据。
func set_value(key: StringName, value: Variant) -> void:
	if _scopes.is_empty():
		var _new_scope_depth: int = push_scope({}, "root")
	var scope: Dictionary = _scopes[_scopes.size() - 1]
	scope[key] = GFVariantData.duplicate_variant(value)
	_scopes[_scopes.size() - 1] = scope


## 检查路径是否可解析。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param data_path: 点号分隔的数据路径。
## [br]
## @return 可解析时返回 true。
func has_value(data_path: String) -> bool:
	return GFVariantData.get_option_bool(_resolve_value(data_path), "found", false)


## 读取路径值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param data_path: 点号分隔的数据路径。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 读取到的值或默认值。
## [br]
## @schema default_value: Variant，缺失时的默认值。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
## [br]
## @schema return: Variant，读取到的数据。
func get_value(data_path: String, default_value: Variant = null, source_span: Variant = null) -> Variant:
	var resolved: Dictionary = _resolve_value(data_path)
	if GFVariantData.get_option_bool(resolved, "found", false):
		return GFVariantData.duplicate_variant(GFVariantData.get_option_value(resolved, "value"))
	if strict_variables:
		_add_source_error(
			&"missing_value",
			"Text generation value is missing: %s" % data_path,
			source_span,
			{ "path": data_path }
		)
	return GFVariantData.duplicate_variant(default_value)


## 替换文本中的 token。
## [br]
## token 默认使用 `{{name}}` 形式，name 只能是数据路径；不会执行表达式。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: 输入文本。
## [br]
## @param options: 可选配置，支持 start_token、end_token、missing_text、max_replacements、source_span 和 value_formatter。
## [br]
## @return 替换后的文本。
## [br]
## @schema options: Dictionary，token 替换配置；value_formatter 为 Callable(context: Dictionary) -> Variant，context 包含 path、value、fallback_text、source_span 和 metadata。
func replace_tokens(text: String, options: Dictionary = {}) -> String:
	var start_token: String = GFVariantData.get_option_string(options, "start_token", "{{")
	var end_token: String = GFVariantData.get_option_string(options, "end_token", "}}")
	var missing_text: String = GFVariantData.get_option_string(options, "missing_text")
	var max_replacements: int = GFVariantData.get_option_int(options, "max_replacements", 0)
	var replacement_state: Dictionary = _get_replacement_state(options)
	var source_span: Variant = GFVariantData.get_option_value(options, "source_span")
	if start_token.is_empty() or end_token.is_empty():
		_add_source_error(&"invalid_token_delimiter", "Token delimiters must not be empty.", source_span)
		return text

	var output: String = ""
	var cursor: int = 0
	var replacement_count: int = GFVariantData.get_option_int(replacement_state, "count")
	while cursor < text.length():
		if not _consume_step(source_span):
			var remaining_after_budget: String = text.substr(cursor)
			if _check_text_length(output.length() + remaining_after_budget.length(), source_span):
				output += remaining_after_budget
			return output

		var start_index: int = text.find(start_token, cursor)
		if start_index < 0:
			var remaining_text: String = text.substr(cursor)
			if not _check_text_length(output.length() + remaining_text.length(), source_span):
				return output
			output += remaining_text
			break

		var literal_text: String = text.substr(cursor, start_index - cursor)
		if not _check_text_length(output.length() + literal_text.length(), source_span):
			return output
		output += literal_text
		var token_start: int = start_index + start_token.length()
		var end_index: int = text.find(end_token, token_start)
		if end_index < 0:
			_add_source_error(&"unterminated_token", "Text generation token is not closed.", source_span)
			var unterminated_text: String = text.substr(start_index)
			if not _check_text_length(output.length() + unterminated_text.length(), source_span):
				return output
			output += unterminated_text
			break

		if max_replacements > 0 and replacement_count >= max_replacements:
			if not GFVariantData.get_option_bool(replacement_state, "limit_reported"):
				_add_source_error(&"replacement_limit_exceeded", "Token replacement limit exceeded.", source_span)
				replacement_state["limit_reported"] = true
			var skipped_text: String = text.substr(start_index)
			if not _check_text_length(output.length() + skipped_text.length(), source_span):
				return output
			output += skipped_text
			break

		var token_name: String = text.substr(token_start, end_index - token_start).strip_edges()
		var replacement_text: String = missing_text
		if token_name.is_empty():
			_add_source_error(&"empty_token", "Text generation token is empty.", source_span)
		else:
			var replacement_value: Variant = get_value(token_name, missing_text, source_span)
			replacement_text = _format_replacement_value(token_name, replacement_value, missing_text, options, source_span)
		if not _check_text_length(output.length() + replacement_text.length(), source_span):
			return output
		output += replacement_text
		replacement_count += 1
		replacement_state["count"] = replacement_count
		cursor = end_index + end_token.length()
	return output


## 渲染安全模板文本。
##
## 支持普通 token 替换、`{{ for item in items }}` / `{{ end }}` 循环块，
## `{{ empty items }}` / `{{ end_empty }}` 空态块，以及 `{{ comment note }}` 注释。
## 模板块只读取纯数据路径，
## 不执行表达式、函数或对象方法。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param template_text: 模板文本。
## [br]
## @param options: 渲染选项，支持 replace_tokens() 选项，以及 max_loop_items、max_template_depth 和 loop_key。
## [br]
## @return 渲染后的文本。
## [br]
## @schema options: Dictionary，可包含 start_token、end_token、missing_text、max_replacements、source_span、value_formatter、max_loop_items、max_template_depth 和 loop_key。
func render_template(template_text: String, options: Dictionary = {}) -> String:
	var render_options: Dictionary = options.duplicate(true)
	render_options["_replacement_state"] = {
		"count": 0,
		"limit_reported": false,
	}
	var source_span: Variant = GFVariantData.get_option_value(render_options, "source_span")
	return _render_template_text(template_text, render_options, 0, source_span)


## 追加文本到输出缓冲。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: 要追加的文本。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 追加成功时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func append_text(text: String, source_span: Variant = null) -> bool:
	var next_length: int = _output_length + text.length()
	if not _check_output_length(next_length, source_span):
		return false
	var _append_result: bool = _output_parts.append(text)
	_output_length = next_length
	return true


## 追加一行文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: 行文本。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 追加成功时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func append_line(text: String = "", source_span: Variant = null) -> bool:
	return append_text("%s\n" % text, source_span)


## 追加带当前缩进的一行文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: 行文本。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 追加成功时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func append_indented_line(text: String = "", source_span: Variant = null) -> bool:
	return append_line("%s%s" % [_make_indent(), text], source_span)


## 增加缩进级别。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前缩进级别。
func push_indent() -> int:
	_indent_level += 1
	return _indent_level


## 减少缩进级别。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前缩进级别。
func pop_indent() -> int:
	_indent_level = maxi(_indent_level - 1, 0)
	return _indent_level


## 获取当前输出文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 输出文本。
func get_text() -> String:
	return "".join(_output_parts)


## 获取当前报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 校验报告。
func get_report() -> GFValidationReport:
	return _report


## 创建报告副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 校验报告副本。
func duplicate_report() -> GFValidationReport:
	var duplicated: RefCounted = _report.duplicate_report()
	if duplicated is GFValidationReport:
		var report: GFValidationReport = duplicated
		return report
	return GFValidationReport.new("Text generation")


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 上下文状态字典。
## [br]
## @schema return: Dictionary，包含 scope、输出和诊断状态。
func get_debug_snapshot() -> Dictionary:
	return {
		"scope_count": _scopes.size(),
		"scope_labels": _scope_labels.duplicate(),
		"output_length": _output_length,
		"indent_level": _indent_level,
		"strict_variables": strict_variables,
		"max_output_length": max_output_length,
		"issue_count": _report.issues.size(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _format_replacement_value(
	data_path: String,
	replacement_value: Variant,
	fallback_text: String,
	options: Dictionary,
	source_span: Variant
) -> String:
	var formatter: Callable = _get_value_formatter(options)
	if not formatter.is_valid():
		if options.has("value_formatter"):
			_add_source_error(
				&"invalid_value_formatter",
				"Text generation value formatter is invalid.",
				source_span,
				{ "path": data_path }
			)
		return GFVariantData.to_text(replacement_value, fallback_text)

	var formatter_context: Dictionary = {
		"path": data_path,
		"value": GFVariantData.duplicate_variant(replacement_value),
		"fallback_text": fallback_text,
		"source_span": source_span,
		"metadata": metadata.duplicate(true),
	}
	var formatted_value: Variant = formatter.call(formatter_context)
	return GFVariantData.to_text(formatted_value, fallback_text)


func _get_value_formatter(options: Dictionary) -> Callable:
	var formatter_value: Variant = GFVariantData.get_option_value(options, "value_formatter")
	if formatter_value is Callable:
		var formatter: Callable = formatter_value
		return formatter
	return Callable()


func _get_replacement_state(options: Dictionary) -> Dictionary:
	var state_value: Variant = GFVariantData.get_option_value(options, "_replacement_state")
	if state_value is Dictionary:
		var state: Dictionary = state_value
		return state
	return {
		"count": 0,
		"limit_reported": false,
	}


func _render_template_text(text: String, options: Dictionary, depth: int, source_span: Variant) -> String:
	var max_depth: int = maxi(GFVariantData.get_option_int(options, "max_template_depth", 32), 1)
	if depth > max_depth:
		_add_source_error(&"template_depth_limit_exceeded", "Text generation template nesting limit exceeded.", source_span)
		return ""

	var start_token: String = GFVariantData.get_option_string(options, "start_token", "{{")
	var end_token: String = GFVariantData.get_option_string(options, "end_token", "}}")
	if start_token.is_empty() or end_token.is_empty():
		return replace_tokens(text, options)

	var output: String = ""
	var cursor: int = 0
	var search_index: int = 0
	while search_index < text.length():
		if not _consume_step(source_span):
			var budget_remaining_text: String = replace_tokens(text.substr(cursor), options)
			if _can_append_template_fragment(output.length(), budget_remaining_text, source_span):
				output += budget_remaining_text
			return output

		var start_index: int = text.find(start_token, search_index)
		if start_index < 0:
			var remaining_text: String = replace_tokens(text.substr(cursor), options)
			if _can_append_template_fragment(output.length(), remaining_text, source_span):
				output += remaining_text
			return output

		var token_start: int = start_index + start_token.length()
		var end_index: int = text.find(end_token, token_start)
		if end_index < 0:
			output += replace_tokens(text.substr(cursor), options)
			return output

		var token_text: String = text.substr(token_start, end_index - token_start).strip_edges()
		if _is_comment_directive(token_text):
			var literal_text: String = replace_tokens(text.substr(cursor, start_index - cursor), options)
			if not _can_append_template_fragment(output.length(), literal_text, source_span):
				return output
			output += literal_text
			cursor = end_index + end_token.length()
			search_index = cursor
			continue

		if _is_for_directive(token_text):
			var literal_text: String = replace_tokens(text.substr(cursor, start_index - cursor), options)
			if not _can_append_template_fragment(output.length(), literal_text, source_span):
				return output
			output += literal_text
			var for_directive: Dictionary = _parse_for_directive(token_text, source_span)
			var block_result: Dictionary = _find_template_loop_block(text, end_index + end_token.length(), start_token, end_token, source_span)
			if for_directive.is_empty() or block_result.is_empty():
				return output

			var block_text: String = GFVariantData.get_option_string(block_result, "block_text")
			var loop_text: String = _render_template_loop(for_directive, block_text, options, depth, source_span)
			if not _can_append_template_fragment(output.length(), loop_text, source_span):
				return output
			output += loop_text
			cursor = GFVariantData.get_option_int(block_result, "after_end")
			search_index = cursor
			continue

		if _is_empty_directive(token_text):
			var literal_text: String = replace_tokens(text.substr(cursor, start_index - cursor), options)
			if not _can_append_template_fragment(output.length(), literal_text, source_span):
				return output
			output += literal_text
			var empty_directive: Dictionary = _parse_empty_directive(token_text, source_span)
			var block_result: Dictionary = _find_template_empty_block(text, end_index + end_token.length(), start_token, end_token, source_span)
			if empty_directive.is_empty() or block_result.is_empty():
				return output

			var block_text: String = GFVariantData.get_option_string(block_result, "block_text")
			var empty_text: String = _render_template_empty_block(empty_directive, block_text, options, depth, source_span)
			if not _can_append_template_fragment(output.length(), empty_text, source_span):
				return output
			output += empty_text
			cursor = GFVariantData.get_option_int(block_result, "after_end")
			search_index = cursor
			continue

		if token_text == "end":
			_add_source_error(&"unexpected_template_end", "Text generation template has an unexpected end block.", source_span)
			var before_unexpected_end: String = replace_tokens(text.substr(cursor, start_index - cursor), options)
			if _can_append_template_fragment(output.length(), before_unexpected_end, source_span):
				output += before_unexpected_end
			return output

		if token_text == "end_empty":
			_add_source_error(&"unexpected_template_empty_end", "Text generation template has an unexpected empty end block.", source_span)
			var before_unexpected_empty_end: String = replace_tokens(text.substr(cursor, start_index - cursor), options)
			if _can_append_template_fragment(output.length(), before_unexpected_empty_end, source_span):
				output += before_unexpected_empty_end
			return output

		search_index = end_index + end_token.length()

	var trailing_text: String = replace_tokens(text.substr(cursor), options)
	if _can_append_template_fragment(output.length(), trailing_text, source_span):
		output += trailing_text
	return output


func _render_template_empty_block(
	empty_directive: Dictionary,
	block_text: String,
	options: Dictionary,
	depth: int,
	source_span: Variant
) -> String:
	var data_path: String = GFVariantData.get_option_string(empty_directive, "path")
	var resolved_value: Variant = get_value(data_path, null, source_span)
	if not _is_template_value_empty(resolved_value):
		return ""
	return _render_template_text(block_text, options, depth + 1, source_span)


func _render_template_loop(
	for_directive: Dictionary,
	block_text: String,
	options: Dictionary,
	depth: int,
	source_span: Variant
) -> String:
	var collection_path: String = GFVariantData.get_option_string(for_directive, "collection_path")
	var loop_variable: String = GFVariantData.get_option_string(for_directive, "variable")
	var collection_value: Variant = get_value(collection_path, [], source_span)
	var items: Array = _to_template_iterable_array(collection_value, collection_path, source_span)
	var max_loop_items: int = maxi(GFVariantData.get_option_int(options, "max_loop_items", 0), 0)
	if max_loop_items > 0 and items.size() > max_loop_items:
		_add_source_error(
			&"template_loop_limit_exceeded",
			"Text generation template loop item limit exceeded: %s." % collection_path,
			source_span,
			{
				"path": collection_path,
				"actual_value": items.size(),
				"expected_value": max_loop_items,
			}
		)
		return ""

	var output: String = ""
	var loop_key: String = GFVariantData.get_option_string(options, "loop_key", "loop")
	for index: int in range(items.size()):
		if not _consume_step(source_span):
			return output
		var scope: Dictionary = {
			loop_variable: GFVariantData.duplicate_variant(items[index]),
		}
		if not loop_key.is_empty():
			scope[loop_key] = {
				"index": index,
				"number": index + 1,
				"count": items.size(),
				"first": index == 0,
				"last": index == items.size() - 1,
			}
		var _scope_depth: int = push_scope(scope, "for %s in %s" % [loop_variable, collection_path])
		var item_text: String = _render_template_text(block_text, options, depth + 1, source_span)
		var _removed_scope: Dictionary = pop_scope()
		if not _can_append_template_fragment(output.length(), item_text, source_span):
			return output
		output += item_text
	return output


func _find_template_loop_block(
	text: String,
	body_start: int,
	start_token: String,
	end_token: String,
	source_span: Variant
) -> Dictionary:
	var depth: int = 1
	var search_index: int = body_start
	while search_index < text.length():
		var start_index: int = text.find(start_token, search_index)
		if start_index < 0:
			_add_source_error(&"missing_template_loop_end", "Text generation template loop is missing an end block.", source_span)
			return {}

		var token_start: int = start_index + start_token.length()
		var end_index: int = text.find(end_token, token_start)
		if end_index < 0:
			_add_source_error(&"unterminated_token", "Text generation token is not closed.", source_span)
			return {}

		var token_text: String = text.substr(token_start, end_index - token_start).strip_edges()
		if _is_for_directive(token_text):
			depth += 1
		elif token_text == "end":
			depth -= 1
			if depth == 0:
				return {
					"block_text": text.substr(body_start, start_index - body_start),
					"after_end": end_index + end_token.length(),
				}
		search_index = end_index + end_token.length()

	_add_source_error(&"missing_template_loop_end", "Text generation template loop is missing an end block.", source_span)
	return {}


func _find_template_empty_block(
	text: String,
	body_start: int,
	start_token: String,
	end_token: String,
	source_span: Variant
) -> Dictionary:
	var depth: int = 1
	var search_index: int = body_start
	while search_index < text.length():
		var start_index: int = text.find(start_token, search_index)
		if start_index < 0:
			_add_source_error(&"missing_template_empty_end", "Text generation template empty block is missing an end_empty block.", source_span)
			return {}

		var token_start: int = start_index + start_token.length()
		var end_index: int = text.find(end_token, token_start)
		if end_index < 0:
			_add_source_error(&"unterminated_token", "Text generation token is not closed.", source_span)
			return {}

		var token_text: String = text.substr(token_start, end_index - token_start).strip_edges()
		if _is_empty_directive(token_text):
			depth += 1
		elif token_text == "end_empty":
			depth -= 1
			if depth == 0:
				return {
					"block_text": text.substr(body_start, start_index - body_start),
					"after_end": end_index + end_token.length(),
				}
		search_index = end_index + end_token.length()

	_add_source_error(&"missing_template_empty_end", "Text generation template empty block is missing an end_empty block.", source_span)
	return {}


func _parse_for_directive(token_text: String, source_span: Variant) -> Dictionary:
	var body: String = token_text.substr("for ".length()).strip_edges()
	var separator: String = " in "
	var separator_index: int = body.find(separator)
	if separator_index < 0:
		_add_source_error(&"invalid_template_loop", "Text generation template loop must use `for item in items`.", source_span)
		return {}

	var loop_variable: String = body.substr(0, separator_index).strip_edges()
	var collection_path: String = body.substr(separator_index + separator.length()).strip_edges()
	if not _is_safe_template_identifier(loop_variable):
		_add_source_error(&"invalid_template_loop_variable", "Text generation template loop variable is invalid: %s." % loop_variable, source_span)
		return {}
	if collection_path.is_empty():
		_add_source_error(&"invalid_template_loop", "Text generation template loop collection path is empty.", source_span)
		return {}
	return {
		"variable": loop_variable,
		"collection_path": collection_path,
	}


func _parse_empty_directive(token_text: String, source_span: Variant) -> Dictionary:
	var data_path: String = token_text.substr("empty ".length()).strip_edges()
	if data_path.is_empty():
		_add_source_error(&"invalid_template_empty_block", "Text generation template empty block path is empty.", source_span)
		return {}
	return {
		"path": data_path,
	}


func _to_template_iterable_array(value: Variant, collection_path: String, source_span: Variant) -> Array:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value
		TYPE_PACKED_BYTE_ARRAY:
			var packed_byte: PackedByteArray = value
			return _packed_iterable_to_array(packed_byte)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return _packed_iterable_to_array(packed_strings)
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return _packed_iterable_to_array(packed_int32)
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return _packed_iterable_to_array(packed_int64)
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return _packed_iterable_to_array(packed_float32)
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return _packed_iterable_to_array(packed_float64)
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2: PackedVector2Array = value
			return _packed_iterable_to_array(packed_vector2)
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3: PackedVector3Array = value
			return _packed_iterable_to_array(packed_vector3)
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4: PackedVector4Array = value
			return _packed_iterable_to_array(packed_vector4)
		TYPE_PACKED_COLOR_ARRAY:
			var packed_color: PackedColorArray = value
			return _packed_iterable_to_array(packed_color)

	_add_source_error(
		&"template_loop_not_iterable",
		"Text generation template loop collection is not an Array: %s." % collection_path,
		source_span,
		{
			"path": collection_path,
			"actual_value": type_string(typeof(value)),
		}
	)
	return []


func _packed_iterable_to_array(values: Variant) -> Array:
	var result: Array = []
	for item: Variant in values:
		result.append(GFVariantData.duplicate_variant(item))
	return result


func _can_append_template_fragment(current_length: int, fragment: String, source_span: Variant) -> bool:
	if fragment.is_empty():
		return true
	return _check_text_length(current_length + fragment.length(), source_span)


func _is_comment_directive(token_text: String) -> bool:
	return token_text == "comment" or token_text.begins_with("comment ")


func _is_for_directive(token_text: String) -> bool:
	return token_text.begins_with("for ")


func _is_empty_directive(token_text: String) -> bool:
	return token_text.begins_with("empty ")


func _is_template_value_empty(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return true
		TYPE_BOOL:
			var bool_value: bool = value
			return not bool_value
		TYPE_STRING:
			var text_value: String = value
			return text_value.is_empty()
		TYPE_STRING_NAME:
			var name_value: StringName = value
			return String(name_value).is_empty()
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			return String(node_path_value).is_empty()
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.is_empty()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.is_empty()
		TYPE_PACKED_BYTE_ARRAY:
			var packed_byte: PackedByteArray = value
			return packed_byte.is_empty()
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return packed_strings.is_empty()
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return packed_int32.is_empty()
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return packed_int64.is_empty()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return packed_float32.is_empty()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return packed_float64.is_empty()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2: PackedVector2Array = value
			return packed_vector2.is_empty()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3: PackedVector3Array = value
			return packed_vector3.is_empty()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4: PackedVector4Array = value
			return packed_vector4.is_empty()
		TYPE_PACKED_COLOR_ARRAY:
			var packed_color: PackedColorArray = value
			return packed_color.is_empty()
	return false


func _is_safe_template_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		var code: int = character.to_lower().unicode_at(0)
		var is_letter: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = character == "_"
		if index == 0:
			if not (is_letter or is_underscore):
				return false
		elif not (is_letter or is_digit or is_underscore):
			return false
	return true


func _resolve_value(data_path: String) -> Dictionary:
	if data_path.is_empty():
		return { "found": false }
	for scope_index: int in range(_scopes.size() - 1, -1, -1):
		var scope: Dictionary = _scopes[scope_index]
		var resolved: Dictionary = _resolve_in_dictionary(scope, data_path)
		if GFVariantData.get_option_bool(resolved, "found", false):
			return resolved
	return { "found": false }


func _resolve_in_dictionary(scope: Dictionary, data_path: String) -> Dictionary:
	if scope.has(data_path):
		return { "found": true, "value": scope[data_path] }
	var data_key: StringName = StringName(data_path)
	if scope.has(data_key):
		return { "found": true, "value": scope[data_key] }

	var current: Variant = scope
	for segment: String in data_path.split("."):
		if segment.is_empty():
			return { "found": false }
		var segment_result: Dictionary = _resolve_segment(current, segment)
		if not GFVariantData.get_option_bool(segment_result, "found", false):
			return { "found": false }
		current = GFVariantData.get_option_value(segment_result, "value")
	return { "found": true, "value": current }


func _resolve_segment(value: Variant, segment: String) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has(segment):
			return { "found": true, "value": dictionary[segment] }
		var segment_key: StringName = StringName(segment)
		if dictionary.has(segment_key):
			return { "found": true, "value": dictionary[segment_key] }
		return { "found": false }
	if value is Array and segment.is_valid_int():
		var array: Array = value
		var index: int = segment.to_int()
		if index >= 0 and index < array.size():
			return { "found": true, "value": array[index] }
	if segment.is_valid_int():
		return _resolve_packed_array_segment(value, segment.to_int())
	return { "found": false }


func _resolve_packed_array_segment(value: Variant, index: int) -> Dictionary:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed_byte: PackedByteArray = value
			if _is_index_in_bounds(index, packed_byte.size()):
				return { "found": true, "value": packed_byte[index] }
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			if _is_index_in_bounds(index, packed_strings.size()):
				return { "found": true, "value": packed_strings[index] }
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			if _is_index_in_bounds(index, packed_int32.size()):
				return { "found": true, "value": packed_int32[index] }
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			if _is_index_in_bounds(index, packed_int64.size()):
				return { "found": true, "value": packed_int64[index] }
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			if _is_index_in_bounds(index, packed_float32.size()):
				return { "found": true, "value": packed_float32[index] }
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			if _is_index_in_bounds(index, packed_float64.size()):
				return { "found": true, "value": packed_float64[index] }
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector2: PackedVector2Array = value
			if _is_index_in_bounds(index, packed_vector2.size()):
				return { "found": true, "value": packed_vector2[index] }
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector3: PackedVector3Array = value
			if _is_index_in_bounds(index, packed_vector3.size()):
				return { "found": true, "value": packed_vector3[index] }
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector4: PackedVector4Array = value
			if _is_index_in_bounds(index, packed_vector4.size()):
				return { "found": true, "value": packed_vector4[index] }
		TYPE_PACKED_COLOR_ARRAY:
			var packed_color: PackedColorArray = value
			if _is_index_in_bounds(index, packed_color.size()):
				return { "found": true, "value": packed_color[index] }
	return { "found": false }


func _is_index_in_bounds(index: int, size: int) -> bool:
	return index >= 0 and index < size


func _check_output_length(next_length: int, source_span: Variant) -> bool:
	if not _consume_step(source_span):
		return false
	return _check_text_length(next_length, source_span)


func _check_text_length(next_length: int, source_span: Variant) -> bool:
	if max_output_length > 0 and next_length > max_output_length:
		_add_source_error(&"output_limit_exceeded", "Text generation output length limit exceeded.", source_span)
		return false
	if budget != null and not budget.check_output_length(next_length, source_span):
		_merge_budget_report()
		return false
	return true


func _consume_step(source_span: Variant) -> bool:
	if budget == null:
		return true
	if budget.consume_steps(1, source_span):
		return true
	_merge_budget_report()
	return false


func _merge_budget_report() -> void:
	if budget == null:
		return
	var budget_report: GFValidationReport = budget.make_report("Text generation budget")
	var _merged_report: RefCounted = _report.merge(budget_report)


func _add_source_error(
	kind: StringName,
	message: String,
	source_span: Variant = null,
	issue_metadata: Dictionary = {}
) -> void:
	if source_span is GFSourceSpan or source_span is Dictionary:
		var _source_issue: RefCounted = _report.add_source_error(kind, message, source_span, null, "", issue_metadata)
	else:
		var _issue: RefCounted = _report.add_error(kind, message, null, "", issue_metadata)


func _make_indent() -> String:
	if _indent_level <= 0:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for _index: int in range(_indent_level):
		var _append_result: bool = parts.append(indent_text)
	return "".join(parts)


static func _variant_to_budget(value: Variant) -> GFExecutionBudget:
	if value is GFExecutionBudget:
		var typed_budget: GFExecutionBudget = value
		return typed_budget
	return null
