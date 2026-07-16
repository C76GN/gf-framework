## GFValidationReport: 通用校验报告数据结构。
##
## 用于聚合 `GFValidationIssue`，提供错误/警告统计、健康状态、摘要、下一步建议
## 和字典序列化。报告不绑定具体配置、存档、节点或编辑器业务语义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFValidationReport
extends RefCounted


# --- 常量 ---

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")


# --- 公共变量 ---

## 报告主题，例如资源名、模块名或调用方自定义域。
## [br]
## @api public
var subject: String = ""

## 问题列表。
## [br]
## @api public
var issues: Array[RefCounted] = []

## 可选元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary of caller-defined report metadata.
var metadata: Dictionary = {}

## 额外报告字段。用于保留或附加调用方自己的统计数据。
## [br]
## @api public
## [br]
## @schema extra_fields: Dictionary of caller-defined serialized report fields.
var extra_fields: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(p_subject: String = "", p_metadata: Dictionary = {}) -> void:
	subject = p_subject
	metadata = p_metadata.duplicate(true)


# --- 公共方法 ---

## 配置报告主题和元数据。
## [br]
## @api public
## [br]
## @param p_subject: 报告主题。
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @schema p_metadata: Dictionary of caller-defined report metadata.
## [br]
## @return 当前报告。
func configure(p_subject: String = "", p_metadata: Dictionary = {}) -> RefCounted:
	subject = p_subject
	metadata = p_metadata.duplicate(true)
	return self


## 清空问题与额外字段。
## [br]
## @api public
func clear() -> void:
	issues.clear()
	metadata.clear()
	extra_fields.clear()


## 添加一个问题。
## [br]
## @api public
## [br]
## @param issue: GFValidationIssue 或问题字典。
## [br]
## @schema issue: Variant accepting GFValidationIssue or Dictionary issue payload.
## [br]
## @return 添加后的问题；输入无效时返回 null。
func add_issue(issue: Variant) -> RefCounted:
	var normalized_issue: GFValidationIssue = _normalize_issue(issue)
	if normalized_issue == null:
		return null
	issues.append(normalized_issue)
	return normalized_issue


## 添加信息问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_info(
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return _add_issue(GFValidationIssue.Severity.INFO, kind, message, key, path, issue_metadata)


## 添加警告问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_warning(
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return _add_issue(GFValidationIssue.Severity.WARNING, kind, message, key, path, issue_metadata)


## 添加错误问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_error(
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return _add_issue(GFValidationIssue.Severity.ERROR, kind, message, key, path, issue_metadata)


## 添加带源码定位的问题。
## [br]
## @api public
## [br]
## @param severity: 严重级别，可传入 Severity、int 或字符串。
## [br]
## @schema severity: Variant accepting GFValidationIssue.Severity, int, String, or StringName.
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param source_span: GFSourceSpan 或兼容字典。
## [br]
## @schema source_span: Variant accepting GFSourceSpan or Dictionary span payload.
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_source_issue(
	severity: Variant,
	kind: StringName,
	message: String,
	source_span: Variant,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	var issue: GFValidationIssue = _add_issue(severity, kind, message, key, path, issue_metadata)
	var _source_issue: RefCounted = issue.set_source_span(source_span)
	return issue


## 添加带源码定位的信息问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param source_span: GFSourceSpan 或兼容字典。
## [br]
## @schema source_span: Variant accepting GFSourceSpan or Dictionary span payload.
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_source_info(
	kind: StringName,
	message: String,
	source_span: Variant,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return add_source_issue(GFValidationIssue.Severity.INFO, kind, message, source_span, key, path, issue_metadata)


## 添加带源码定位的警告问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param source_span: GFSourceSpan 或兼容字典。
## [br]
## @schema source_span: Variant accepting GFSourceSpan or Dictionary span payload.
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_source_warning(
	kind: StringName,
	message: String,
	source_span: Variant,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return add_source_issue(GFValidationIssue.Severity.WARNING, kind, message, source_span, key, path, issue_metadata)


## 添加带源码定位的错误问题。
## [br]
## @api public
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param source_span: GFSourceSpan 或兼容字典。
## [br]
## @schema source_span: Variant accepting GFSourceSpan or Dictionary span payload.
## [br]
## @param key: 可选定位键。
## [br]
## @schema key: Variant caller-defined location key.
## [br]
## @param path: 可选路径。
## [br]
## @param issue_metadata: 可选元数据。
## [br]
## @schema issue_metadata: Dictionary of caller-defined issue metadata.
## [br]
## @return 新问题。
func add_source_error(
	kind: StringName,
	message: String,
	source_span: Variant,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> RefCounted:
	return add_source_issue(GFValidationIssue.Severity.ERROR, kind, message, source_span, key, path, issue_metadata)


## 合并另一个报告或报告字典。
## [br]
## @api public
## [br]
## @param source: GFValidationReport 或包含 issues 的字典。
## [br]
## @schema source: Variant accepting GFValidationReport or Dictionary report payload.
## [br]
## @param include_metadata: 为 true 时合并源报告 metadata。
## [br]
## @return 当前报告。
func merge(source: Variant, include_metadata: bool = true) -> RefCounted:
	if source is GFValidationReport:
		var source_report: GFValidationReport = source
		for issue_variant: Variant in source_report.issues:
			_add_issue_if_valid(issue_variant)
		if include_metadata:
			for key: Variant in source_report.metadata.keys():
				metadata[key] = GFVariantData.duplicate_variant(source_report.metadata[key])
			for key: Variant in source_report.extra_fields.keys():
				extra_fields[key] = GFVariantData.duplicate_variant(source_report.extra_fields[key])
	elif source is Dictionary:
		var source_dict: Dictionary = source
		var source_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(source_dict, "issues", []))
		for issue_variant: Variant in source_issues:
			_add_issue_if_valid(issue_variant)
		var source_metadata_value: Variant = GFVariantData.get_option_value(source_dict, "metadata")
		if include_metadata and source_metadata_value is Dictionary:
			var source_metadata: Dictionary = GFVariantData.as_dictionary(source_metadata_value)
			for key: Variant in source_metadata.keys():
				metadata[key] = GFVariantData.duplicate_variant(source_metadata[key])
	return self


## 从字典应用报告字段。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary report payload.
func apply_dict(data: Dictionary) -> void:
	issues.clear()
	subject = GFVariantData.get_option_string(data, "subject", subject)
	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", metadata)
	metadata = GFVariantData.as_dictionary(metadata_value).duplicate(true)
	extra_fields.clear()

	var source_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(data, "issues", []))
	for issue_variant: Variant in source_issues:
		_add_issue_if_valid(issue_variant)

	for field_key: Variant in data.keys():
		if _is_reserved_report_field(GFVariantData.to_text(field_key)):
			continue
		extra_fields[field_key] = GFVariantData.duplicate_variant(data[field_key])


## 转换为报告字典。
## [br]
## @api public
## [br]
## @param additional_fields: 附加到输出中的调用方字段。
## [br]
## @schema additional_fields: Dictionary of caller-defined serialized fields.
## [br]
## @param options: 可选输出控制，支持 include_subject、include_metadata、include_info_count、include_issue_count、include_empty_issue_fields、summary_subject、next_actions、fallback_action、no_action。
## [br]
## @schema options: Dictionary controlling report serialization options.
## [br]
## @return 报告字典。
## [br]
## @schema return: Dictionary serialized report payload.
func to_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = extra_fields.duplicate(true)
	for field_key: Variant in additional_fields.keys():
		result[field_key] = GFVariantData.duplicate_variant(additional_fields[field_key])

	var include_subject: bool = GFVariantData.get_option_bool(options, "include_subject", not subject.is_empty())
	var include_metadata: bool = GFVariantData.get_option_bool(options, "include_metadata", not metadata.is_empty())
	var include_info_count: bool = GFVariantData.get_option_bool(options, "include_info_count", true)
	var include_issue_count: bool = GFVariantData.get_option_bool(options, "include_issue_count", true)
	var include_empty_issue_fields: bool = GFVariantData.get_option_bool(options, "include_empty_issue_fields", false)
	var summary_subject: String = GFVariantData.get_option_string(options, "summary_subject", subject)
	var next_actions: Dictionary = GFVariantData.get_option_dictionary(options, "next_actions")
	var fallback_action: String = GFVariantData.get_option_string(options, "fallback_action", "Review the first reported issue.")
	var no_action: String = GFVariantData.get_option_string(options, "no_action", "No action required.")

	if include_subject:
		result["subject"] = subject
	if include_metadata:
		result["metadata"] = metadata.duplicate(true)

	result["ok"] = is_ok()
	result["healthy"] = is_healthy()
	result["error_count"] = get_error_count()
	result["warning_count"] = get_warning_count()
	if include_info_count:
		result["info_count"] = get_info_count()
	if include_issue_count:
		result["issue_count"] = issues.size()
	result["issue_counts_by_kind"] = get_issue_counts_by_kind()
	result["summary"] = make_summary(summary_subject)
	result["next_action"] = get_next_action(next_actions, fallback_action, no_action)

	var issue_dicts: Array[Dictionary] = []
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue == null:
			continue
		issue_dicts.append(validation_issue.to_dict(include_empty_issue_fields))
	result["issues"] = issue_dicts
	return result


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param additional_fields: 附加到输出中的调用方字段。
## [br]
## @schema additional_fields: Dictionary of caller-defined serialized fields.
## [br]
## @param options: 传给 to_dict() 的输出控制。
## [br]
## @schema options: Dictionary controlling report serialization options.
## [br]
## @return JSON-safe 报告字典。
## [br]
## @schema return: Dictionary serialized report payload made safe for JSON.stringify().
func to_json_compatible_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var raw_report: Dictionary = to_dict(additional_fields, options)
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(raw_report))


## 创建当前报告深拷贝。
## [br]
## @api public
## [br]
## @return 新报告。
func duplicate_report() -> RefCounted:
	var report: GFValidationReport = GFValidationReport.new()
	report.apply_dict(to_dict({}, { "include_empty_issue_fields": true }))
	return report


## 获取错误数量。
## [br]
## @api public
## [br]
## @return 错误数量。
func get_error_count() -> int:
	var count: int = 0
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null and validation_issue.is_error():
			count += 1
	return count


## 获取警告数量。
## [br]
## @api public
## [br]
## @return 警告数量。
func get_warning_count() -> int:
	var count: int = 0
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null and validation_issue.is_warning():
			count += 1
	return count


## 获取信息数量。
## [br]
## @api public
## [br]
## @return 信息数量。
func get_info_count() -> int:
	var count: int = 0
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null and validation_issue.is_info():
			count += 1
	return count


## 检查报告是否没有错误。
## [br]
## @api public
## [br]
## @return 没有错误时返回 true。
func is_ok() -> bool:
	return get_error_count() == 0


## 检查报告是否完全健康。
## [br]
## @api public
## [br]
## @return 没有错误和警告时返回 true。
func is_healthy() -> bool:
	return get_error_count() == 0 and get_warning_count() == 0


## 按问题类别统计数量。
## [br]
## @api public
## [br]
## @return 类别计数字典。
## [br]
## @schema return: Dictionary keyed by issue kind with integer counts.
func get_issue_counts_by_kind() -> Dictionary:
	var result: Dictionary = {}
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue == null:
			continue
		var kind_key: String = validation_issue.get_kind_key()
		result[kind_key] = GFVariantData.get_option_int(result, kind_key, 0) + 1
	return result


## 生成摘要文本。
## [br]
## @api public
## [br]
## @param subject_override: 临时覆盖报告主题。
## [br]
## @return 摘要文本。
func make_summary(subject_override: String = "") -> String:
	var label: String = subject_override if not subject_override.is_empty() else subject
	if label.is_empty():
		label = "Validation report"

	var error_count: int = get_error_count()
	var warning_count: int = get_warning_count()
	if error_count > 0:
		return "%s has %d error(s) and %d warning(s)." % [label, error_count, warning_count]
	if warning_count > 0:
		return "%s has %d warning(s)." % [label, warning_count]
	return "%s is healthy." % label


## 获取下一步建议。
## [br]
## @api public
## [br]
## @param action_map: 按问题类别映射的建议文本。
## [br]
## @schema action_map: Dictionary keyed by issue kind with action text values.
## [br]
## @param fallback_action: 存在问题但没有命中映射时返回的建议。
## [br]
## @param no_action: 没有问题时返回的建议。
## [br]
## @return 建议文本。
func get_next_action(
	action_map: Dictionary = {},
	fallback_action: String = "Review the first reported issue.",
	no_action: String = "No action required."
) -> String:
	var issue: GFValidationIssue = _get_first_issue_by_priority()
	if issue == null:
		return no_action

	var kind_key: String = issue.get_kind_key()
	if action_map.has(kind_key):
		return GFVariantData.to_text(action_map[kind_key])
	var kind_name: StringName = StringName(kind_key)
	if action_map.has(kind_name):
		return GFVariantData.to_text(action_map[kind_name])
	return fallback_action


## 将警告提升为错误。
## [br]
## @api public
## [br]
## @param kinds: 为空时提升全部警告；否则只提升匹配类别。
## [br]
## @return 当前报告。
func promote_warnings_to_errors(kinds: PackedStringArray = PackedStringArray()) -> RefCounted:
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue == null or not validation_issue.is_warning():
			continue
		if kinds.is_empty() or kinds.has(validation_issue.get_kind_key()):
			validation_issue.severity = GFValidationIssue.Severity.ERROR
	return self


## 从字典创建报告。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary report payload.
## [br]
## @return 新报告。
static func from_dict(data: Dictionary) -> RefCounted:
	var report: GFValidationReport = GFValidationReport.new()
	report.apply_dict(data)
	return report


# --- 私有/辅助方法 ---

func _add_issue(
	p_severity: Variant,
	p_kind: StringName,
	p_message: String,
	p_key: Variant,
	p_path: String,
	p_metadata: Dictionary
) -> GFValidationIssue:
	var issue: GFValidationIssue = GFValidationIssue.new(p_severity, p_kind, p_message, p_key, p_path, p_metadata)
	issues.append(issue)
	return issue


func _normalize_issue(issue: Variant) -> GFValidationIssue:
	if issue is GFValidationIssue:
		var validation_issue: GFValidationIssue = issue
		return _as_validation_issue(validation_issue.duplicate_issue())
	if issue is Dictionary:
		var issue_data: Dictionary = issue
		var normalized_issue: GFValidationIssue = GFValidationIssue.new()
		normalized_issue.apply_dict(issue_data)
		return normalized_issue
	return null


func _add_issue_if_valid(issue: Variant) -> void:
	var _added_issue: RefCounted = add_issue(issue)


func _get_first_issue_by_priority() -> GFValidationIssue:
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null and validation_issue.is_error():
			return validation_issue
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null and validation_issue.is_warning():
			return validation_issue
	for issue: RefCounted in issues:
		var validation_issue: GFValidationIssue = _as_validation_issue(issue)
		if validation_issue != null:
			return validation_issue
	return null


static func _as_validation_issue(value: Variant) -> GFValidationIssue:
	if value is GFValidationIssue:
		var validation_issue: GFValidationIssue = value
		return validation_issue
	return null


static func _is_reserved_report_field(field_name: String) -> bool:
	return (
		field_name == "subject"
		or field_name == "metadata"
		or field_name == "issues"
		or field_name == "ok"
		or field_name == "healthy"
		or field_name == "error_count"
		or field_name == "warning_count"
		or field_name == "info_count"
		or field_name == "issue_count"
		or field_name == "issue_counts_by_kind"
		or field_name == "summary"
		or field_name == "next_action"
	)
