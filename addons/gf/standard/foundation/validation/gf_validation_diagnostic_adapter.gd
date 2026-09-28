## GFValidationDiagnosticAdapter: 校验报告到编辑器诊断数据的适配器。
##
## 只把 `GFValidationIssue`、`GFValidationReport` 或兼容字典转换成纯 Dictionary
## 诊断记录，不创建 UI，也不假设具体编辑器控件，便于 Inspector、Dock、CI 和项目工具复用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFValidationDiagnosticAdapter
extends RefCounted


# --- 常量 ---

## 校验问题脚本基类。
## [br]
## @api framework_internal
const GF_VALIDATION_ISSUE_BASE = preload("res://addons/gf/standard/foundation/validation/gf_validation_issue.gd")

## 校验报告脚本基类。
## [br]
## @api framework_internal
const GF_VALIDATION_REPORT_BASE = preload("res://addons/gf/standard/foundation/validation/gf_validation_report.gd")

## 源码范围脚本基类。
## [br]
## @api framework_internal
const GF_SOURCE_SPAN_BASE = preload("res://addons/gf/standard/foundation/validation/gf_source_span.gd")


# --- 公共方法 ---

## 将单个问题转换成诊断字典。
## [br]
## @api public
## [br]
## @param issue: GFValidationIssue 或兼容问题字典。
## [br]
## @schema issue: Variant accepting GFValidationIssue or Dictionary issue payload.
## [br]
## @param options: 可选参数，支持 use_path_as_source、include_empty_source_span。
## [br]
## @schema options: Dictionary diagnostic conversion options.
## [br]
## @return 诊断字典；输入无效时返回空字典。
## [br]
## @schema return: Dictionary editor diagnostic record.
static func issue_to_diagnostic(issue: Variant, options: Dictionary = {}) -> Dictionary:
	var issue_data: Dictionary = _issue_to_dict(issue, GFVariantData.get_option_bool(options, "include_empty_source_span", false))
	if issue_data.is_empty():
		return {}

	var source_span: GFSourceSpan = _source_span_from_dict(_make_span_data(issue_data, options))
	var severity: String = GFValidationIssue.severity_to_string(GFVariantData.get_option_value(issue_data, "severity", "error"))
	var kind_key: String = _get_issue_kind(issue_data)
	var source_path: String = source_span.source_path
	var line: int = source_span.line
	var column: int = source_span.column
	var length: int = source_span.length
	var end_line: int = source_span.end_line
	var end_column: int = source_span.end_column
	var preview: String = source_span.preview
	var location: String = source_span.get_location_text()
	var source_span_dict: Dictionary = source_span.to_dict(false, true)
	var diagnostic: Dictionary = {
		"severity": severity,
		"kind": kind_key,
		"message": GFVariantData.get_option_string(issue_data, "message"),
		"key": GFVariantData.duplicate_variant(GFVariantData.get_option_value(issue_data, "key")),
		"path": GFVariantData.get_option_string(issue_data, "path"),
		"source_path": source_path,
		"line": line,
		"column": column,
		"length": length,
		"end_line": end_line,
		"end_column": end_column,
		"preview": preview,
		"line_index": line - 1 if line > 0 else -1,
		"column_index": column - 1 if column > 0 else -1,
		"location": location,
		"source_span": source_span_dict,
		"metadata": _read_dictionary(issue_data, "metadata"),
	}
	diagnostic["display_text"] = make_display_text(diagnostic)
	diagnostic["tooltip"] = make_tooltip(diagnostic)
	return diagnostic


## 将报告、报告字典或问题数组转换成诊断数组。
## [br]
## @api public
## [br]
## @param source: GFValidationReport、报告字典或问题数组。
## [br]
## @schema source: Variant accepting GFValidationReport, Dictionary report payload, or Array issues.
## [br]
## @param options: 可选参数，支持 source_path、include_positionless、use_path_as_source。
## [br]
## @schema options: Dictionary diagnostic conversion options.
## [br]
## @return 诊断数组。
## [br]
## @schema return: Array of Dictionary editor diagnostic records.
static func report_to_diagnostics(source: Variant, options: Dictionary = {}) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var source_filter: String = GFVariantData.get_option_string(options, "source_path")
	var include_positionless: bool = GFVariantData.get_option_bool(options, "include_positionless", true)
	for issue: Variant in _get_source_issues(source):
		var diagnostic: Dictionary = issue_to_diagnostic(issue, options)
		if diagnostic.is_empty():
			continue
		if not source_filter.is_empty() and GFVariantData.get_option_string(diagnostic, "source_path") != source_filter:
			continue
		if not include_positionless and GFVariantData.get_option_int(diagnostic, "line") <= 0:
			continue
		diagnostics.append(diagnostic)
	return diagnostics


## 按源路径分组诊断。
## [br]
## @api public
## [br]
## @param diagnostics: 诊断数组。
## [br]
## @schema diagnostics: Array of Dictionary editor diagnostic records.
## [br]
## @return source_path -> Array[Dictionary]。
## [br]
## @schema return: Dictionary keyed by source_path with diagnostic arrays.
static func group_by_source(diagnostics: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for diagnostic: Dictionary in diagnostics:
		var source_path: String = GFVariantData.get_option_string(diagnostic, "source_path")
		var group: Array = _get_group_array(result, source_path)
		group.append(diagnostic.duplicate(true))
	return result


## 生成适合行号栏、问题列表或资源面板消费的行记录。
## [br]
## @api public
## [br]
## @param diagnostics: 诊断数组。
## [br]
## @schema diagnostics: Array of Dictionary editor diagnostic records.
## [br]
## @param options: 可选参数，支持 include_positionless。
## [br]
## @schema options: Dictionary line record conversion options.
## [br]
## @return 行记录数组。
## [br]
## @schema return: Array of Dictionary line records.
static func make_line_records(diagnostics: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var include_positionless: bool = GFVariantData.get_option_bool(options, "include_positionless", false)
	for diagnostic: Dictionary in diagnostics:
		var line_number: int = GFVariantData.get_option_int(diagnostic, "line")
		if line_number <= 0 and not include_positionless:
			continue
		var column_number: int = GFVariantData.get_option_int(diagnostic, "column")
		records.append({
			"source_path": GFVariantData.get_option_string(diagnostic, "source_path"),
			"line": line_number,
			"line_index": line_number - 1 if line_number > 0 else -1,
			"column": column_number,
			"column_index": column_number - 1 if column_number > 0 else -1,
			"severity": GFVariantData.get_option_string(diagnostic, "severity", "error"),
			"kind": GFVariantData.get_option_string(diagnostic, "kind"),
			"message": GFVariantData.get_option_string(diagnostic, "message"),
			"tooltip": make_tooltip(diagnostic),
			"diagnostic": diagnostic.duplicate(true),
		})
	return records


## 生成单条诊断的简短显示文本。
## [br]
## @api public
## [br]
## @param diagnostic: 诊断字典。
## [br]
## @schema diagnostic: Dictionary editor diagnostic record.
## [br]
## @return 显示文本。
static func make_display_text(diagnostic: Dictionary) -> String:
	var message: String = GFVariantData.get_option_string(diagnostic, "message")
	var kind: String = GFVariantData.get_option_string(diagnostic, "kind")
	if message.is_empty():
		message = kind
	if message.is_empty():
		message = "Validation issue"

	var location: String = GFVariantData.get_option_string(diagnostic, "location")
	if location.is_empty() or location == "source":
		return message
	return "%s: %s" % [location, message]


## 生成单条诊断的工具提示文本。
## [br]
## @api public
## [br]
## @param diagnostic: 诊断字典。
## [br]
## @schema diagnostic: Dictionary editor diagnostic record.
## [br]
## @return 工具提示文本。
static func make_tooltip(diagnostic: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var severity: String = GFVariantData.get_option_string(diagnostic, "severity", "error")
	var kind: String = GFVariantData.get_option_string(diagnostic, "kind")
	var message: String = GFVariantData.get_option_string(diagnostic, "message")
	var location: String = GFVariantData.get_option_string(diagnostic, "location")
	_append_packed_string(lines, "[%s] %s" % [severity, kind if not kind.is_empty() else "validation"])
	if not message.is_empty():
		_append_packed_string(lines, message)
	if not location.is_empty() and location != "source":
		_append_packed_string(lines, location)
	var preview: String = GFVariantData.get_option_string(diagnostic, "preview")
	if not preview.is_empty():
		_append_packed_string(lines, preview)
	return "\n".join(lines)


# --- 私有/辅助方法 ---

## 委托 GFValidationReportDictionary 将问题对象或字典规范化为问题字典。
## [br]
## @api private
## [br]
static func _issue_to_dict(issue: Variant, include_empty_fields: bool = false) -> Dictionary:
	return GFValidationReportDictionary.issue_to_dict(issue, include_empty_fields)


## 从校验报告、报告字典或问题数组复制问题列表；其他输入返回空数组。
## [br]
## @api private
## [br]
static func _get_source_issues(source: Variant) -> Array:
	if source is GFValidationReport:
		var validation_report: GFValidationReport = source
		return validation_report.issues.duplicate()
	if source is Dictionary:
		var source_report: Dictionary = source
		return GFVariantData.as_array(GFVariantData.get_option_value(source_report, "issues", [])).duplicate()
	if source is Array:
		var source_issues: Array = source
		return source_issues.duplicate()
	return []


## 合并嵌套 source_span 与问题上的平面定位字段，并可按选项用 path 补 source_path。
## [br]
## @api private
## [br]
static func _make_span_data(issue_data: Dictionary, options: Dictionary) -> Dictionary:
	var span_data: Dictionary = {}
	var source_span_value: Variant = GFVariantData.get_option_value(issue_data, "source_span")
	if source_span_value is Dictionary:
		var source_span_data: Dictionary = GFVariantData.as_dictionary(source_span_value)
		span_data = source_span_data.duplicate(true)

	for field_name: String in ["source_path", "source", "line", "column", "length", "end_line", "end_column", "preview"]:
		if issue_data.has(field_name):
			span_data[field_name] = GFVariantData.duplicate_variant(issue_data[field_name])

	if GFVariantData.get_option_string(span_data, "source_path").is_empty() and GFVariantData.get_option_bool(options, "use_path_as_source", false):
		span_data["source_path"] = GFVariantData.get_option_string(issue_data, "path")
	return span_data


## 创建 GFSourceSpan 并从字典应用定位字段。
## [br]
## @api private
## [br]
static func _source_span_from_dict(data: Dictionary) -> GFSourceSpan:
	var span: GFSourceSpan = GFSourceSpan.new()
	span.apply_dict(data)
	return span


## 读取 kind 并转成文本；空值时使用 unknown。
## [br]
## @api private
## [br]
static func _get_issue_kind(issue_data: Dictionary) -> String:
	var kind_value: Variant = GFVariantData.get_option_value(issue_data, "kind", "unknown")
	var kind_text: String = GFVariantData.to_text(kind_value)
	return kind_text if not kind_text.is_empty() else "unknown"


## 读取指定字段并将值规范化为字典。
## [br]
## @api private
## [br]
static func _read_dictionary(data: Dictionary, field_name: String) -> Dictionary:
	return GFVariantData.to_dictionary(GFVariantData.get_option_value(data, field_name, {}))


## 取得目标字典中可复用的数组分组；字段不是数组时创建并保存新数组。
## [br]
## @api private
## [br]
static func _get_group_array(target: Dictionary, source_path: String) -> Array:
	var value: Variant = GFVariantData.get_option_value(target, source_path, [])
	if value is Array:
		var group: Array = value
		target[source_path] = group
		return group
	var empty_group: Array = []
	target[source_path] = empty_group
	return empty_group


## 向 PackedStringArray 追加一段文本。
## [br]
## @api private
## [br]
static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
