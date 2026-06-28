## GFTextGenerationContext: 安全的纯数据文本生成上下文。
##
## 提供显式数据 scope、严格缺失检查、简单 token 替换、输出缓冲和预算诊断。
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
	strict_variables = GFVariantData.get_option_bool(options, "strict_variables", strict_variables)
	max_output_length = maxi(GFVariantData.get_option_int(options, "max_output_length", max_output_length), 0)
	indent_text = GFVariantData.get_option_string(options, "indent_text", indent_text)
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)

	var budget_value: Variant = GFVariantData.get_option_value(options, "budget", budget)
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
## @param options: 可选配置，支持 start_token、end_token、missing_text、max_replacements 和 source_span。
## [br]
## @return 替换后的文本。
## [br]
## @schema options: Dictionary，token 替换配置。
func replace_tokens(text: String, options: Dictionary = {}) -> String:
	var start_token: String = GFVariantData.get_option_string(options, "start_token", "{{")
	var end_token: String = GFVariantData.get_option_string(options, "end_token", "}}")
	var missing_text: String = GFVariantData.get_option_string(options, "missing_text")
	var max_replacements: int = GFVariantData.get_option_int(options, "max_replacements", 0)
	var source_span: Variant = GFVariantData.get_option_value(options, "source_span")
	if start_token.is_empty() or end_token.is_empty():
		_add_source_error(&"invalid_token_delimiter", "Token delimiters must not be empty.", source_span)
		return text

	var output: String = ""
	var cursor: int = 0
	var replacement_count: int = 0
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
			_add_source_error(&"replacement_limit_exceeded", "Token replacement limit exceeded.", source_span)
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
			replacement_text = GFVariantData.to_text(get_value(token_name, missing_text, source_span), missing_text)
		if not _check_text_length(output.length() + replacement_text.length(), source_span):
			return output
		output += replacement_text
		replacement_count += 1
		cursor = end_index + end_token.length()
	return output


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
	return { "found": false }


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
