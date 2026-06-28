## GFValidationReportDictionary: 通用校验报告字典辅助。
##
## 提供字典报告的追加、归一化、统计和严重级别提升工具，便于字典式报告
## 接入 `GFValidationIssue` / `GFValidationReport` 使用的标准字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFValidationReportDictionary
extends RefCounted


# --- 常量 ---

const _GF_VALIDATION_ISSUE_SCRIPT: Script = preload("res://addons/gf/standard/foundation/validation/gf_validation_issue.gd")
const _GF_VALIDATION_REPORT_SCRIPT = preload("res://addons/gf/standard/foundation/validation/gf_validation_report.gd")
const _GF_SOURCE_SPAN_SCRIPT = preload("res://addons/gf/standard/foundation/validation/gf_source_span.gd")


# --- 公共方法 ---

## 将任意问题转换为字典。
## [br]
## @api public
## [br]
## @param issue: GFValidationIssue 或问题字典。
## [br]
## @schema issue: Variant accepting GFValidationIssue or Dictionary issue payload.
## [br]
## @param include_empty_fields: 为 true 时包含空的可选字段。
## [br]
## @return 问题字典。
## [br]
## @schema return: Dictionary serialized issue payload.
static func issue_to_dict(issue: Variant, include_empty_fields: bool = false) -> Dictionary:
	var issue_instance: RefCounted = _get_script_instance(issue, _GF_VALIDATION_ISSUE_SCRIPT)
	if issue_instance != null:
		return _call_dictionary(issue_instance, &"to_dict", [include_empty_fields])
	if issue is Dictionary:
		var issue_data: Dictionary = issue
		if issue_data.is_empty():
			return {}
		var normalized_issue: RefCounted = _make_validation_issue()
		if normalized_issue == null:
			return {}
		_call_void(normalized_issue, &"apply_dict", [issue_data])
		return _call_dictionary(normalized_issue, &"to_dict", [include_empty_fields])
	return {}


## 将报告字典转换为 GFValidationReport。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary report payload.
## [br]
## @return 新报告。
static func report_from_dict(data: Dictionary) -> RefCounted:
	var report: RefCounted = _make_validation_report()
	if report == null:
		return null
	_call_void(report, &"apply_dict", [data])
	return report


## 向字典报告追加问题。
## [br]
## @api public
## [br]
## @param report: 目标报告字典。
## [br]
## @schema report: Dictionary report payload mutated in place.
## [br]
## @param severity: 严重级别，可传入 Severity、int 或字符串。
## [br]
## @schema severity: Variant accepting GFValidationIssue.Severity, int, String, or StringName.
## [br]
## @param kind: 问题类别。
## [br]
## @param message: 问题说明。
## [br]
## @param fields: 附加字段，例如 key、path、row_key、metadata。
## [br]
## @schema fields: Dictionary additional issue fields.
## [br]
## @return 追加的问题字典。
## [br]
## @schema return: Dictionary appended issue payload.
static func append_issue(
	report: Dictionary,
	severity: Variant,
	kind: StringName,
	message: String,
	fields: Dictionary = {}
) -> Dictionary:
	var issue: Dictionary = {
		"severity": _severity_to_string(severity),
		"kind": String(kind),
		"message": message,
	}
	for field_key: Variant in fields.keys():
		var field_name: String = GFVariantData.to_text(field_key)
		if field_name == "severity" or field_name == "kind" or field_name == "message":
			continue
		issue[field_key] = GFVariantData.duplicate_variant(fields[field_key])

	var issues: Array = _get_issue_array(report)
	issues.append(issue)
	return issue


## 向字典报告追加带源码定位的问题。
## [br]
## @api public
## [br]
## @param report: 目标报告字典。
## [br]
## @schema report: Dictionary report payload mutated in place.
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
## @param fields: 附加字段，例如 key、path、row_key、metadata。
## [br]
## @schema fields: Dictionary additional issue fields.
## [br]
## @return 追加的问题字典。
## [br]
## @schema return: Dictionary appended issue payload.
static func append_source_issue(
	report: Dictionary,
	severity: Variant,
	kind: StringName,
	message: String,
	source_span: Variant,
	fields: Dictionary = {}
) -> Dictionary:
	var merged_fields: Dictionary = fields.duplicate(true)
	var span_dict: Dictionary = _source_span_to_dict(source_span)
	for field_key: Variant in span_dict.keys():
		merged_fields[field_key] = GFVariantData.duplicate_variant(span_dict[field_key])
	if not span_dict.is_empty():
		merged_fields["source_span"] = span_dict.duplicate(true)
	return append_issue(report, severity, kind, message, merged_fields)


## 合并另一份字典报告的问题。
## [br]
## @api public
## [br]
## @param target: 目标报告字典，会被当前方法修改。
## [br]
## @param source: 来源报告字典，不会被当前方法修改。
## [br]
## @param options: 可选合并设置；copy_fields 指定需要从 source 复制到 target 的字段名。
## [br]
## @schema target: Dictionary report payload mutated in place.
## [br]
## @schema source: Dictionary report payload copied from.
## [br]
## @schema options: Dictionary may contain copy_fields as PackedStringArray or Array[String].
## [br]
## @return 同一个目标报告字典。
## [br]
## @schema return: Dictionary merged report payload.
static func merge_report(target: Dictionary, source: Dictionary, options: Dictionary = {}) -> Dictionary:
	var target_issues: Array = _get_issue_array(target)
	for issue_variant: Variant in GFVariantData.get_option_array(source, "issues"):
		var issue: Dictionary = issue_to_dict(issue_variant)
		if issue.is_empty():
			continue
		target_issues.append(issue)
	target["issues"] = target_issues

	for field_name: String in _to_packed_string_array(GFVariantData.get_option_value(options, "copy_fields", PackedStringArray())):
		if not _has_text_key(source, field_name):
			continue
		target[field_name] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(source, field_name))
	return target


## 重新计算字典报告的统计字段。
## [br]
## @api public
## [br]
## @param report: 目标报告字典。
## [br]
## @schema report: Dictionary report payload mutated in place.
## [br]
## @param subject: 摘要主题；为空时使用 report.subject 或 Validation report。
## [br]
## @param options: 可选控制，支持 next_actions、fallback_action、no_action、include_info_count、warnings_as_errors、promote_warning_kinds。
## [br]
## @schema options: Dictionary controlling report finalization.
## [br]
## @return 同一个报告字典。
## [br]
## @schema return: Dictionary finalized report payload.
static func finalize_report(
	report: Dictionary,
	subject: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var error_count: int = 0
	var warning_count: int = 0
	var info_count: int = 0
	var issue_counts_by_kind: Dictionary = {}
	var issues: Array = _get_issue_array(report)
	var normalized_issues: Array = []
	for issue_variant: Variant in issues:
		var issue: Dictionary = issue_to_dict(issue_variant)
		if issue.is_empty():
			continue
		normalized_issues.append(issue)

		var kind_key: String = _get_issue_kind(issue)
		issue_counts_by_kind[kind_key] = GFVariantData.get_option_int(issue_counts_by_kind, kind_key, 0) + 1

		match _get_effective_severity(issue, options):
			"error":
				error_count += 1
			"warning":
				warning_count += 1
			"info":
				info_count += 1

	report["issues"] = normalized_issues
	report["error_count"] = error_count
	report["warning_count"] = warning_count
	if GFVariantData.get_option_bool(options, "include_info_count", report.has("info_count")):
		report["info_count"] = info_count
	report[GFResultDictionary.KEY_ISSUE_COUNT] = normalized_issues.size()
	report["issue_counts_by_kind"] = issue_counts_by_kind
	report[GFResultDictionary.KEY_OK] = error_count == 0
	report[GFResultDictionary.KEY_HEALTHY] = error_count == 0 and warning_count == 0

	var summary_subject: String = subject
	if summary_subject.is_empty():
		summary_subject = GFVariantData.get_option_string(report, "subject")
	report[GFResultDictionary.KEY_SUMMARY] = make_summary(summary_subject, error_count, warning_count)

	var next_actions: Dictionary = GFVariantData.get_option_dictionary(options, "next_actions")
	var fallback_action: String = GFVariantData.get_option_string(options, "fallback_action", "Review the first reported issue.")
	var no_action: String = GFVariantData.get_option_string(options, "no_action", "No action required.")
	report[GFResultDictionary.KEY_NEXT_ACTION] = get_next_action(report, next_actions, fallback_action, no_action, options)
	return report


## 生成摘要文本。
## [br]
## @api public
## [br]
## @param subject: 摘要主题。
## [br]
## @param error_count: 错误数量。
## [br]
## @param warning_count: 警告数量。
## [br]
## @return 摘要文本。
static func make_summary(subject: String, error_count: int, warning_count: int) -> String:
	var label: String = subject
	if label.is_empty():
		label = "Validation report"
	if error_count > 0:
		return "%s has %d error(s) and %d warning(s)." % [label, error_count, warning_count]
	if warning_count > 0:
		return "%s has %d warning(s)." % [label, warning_count]
	return "%s is healthy." % label


## 获取报告下一步建议。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @schema report: Dictionary report payload.
## [br]
## @param action_map: 按问题类别映射的建议文本。
## [br]
## @schema action_map: Dictionary keyed by issue kind with action text values.
## [br]
## @param fallback_action: 存在问题但未命中映射时返回的建议。
## [br]
## @param no_action: 没有问题时返回的建议。
## [br]
## @param options: 严重级别计算选项。
## [br]
## @schema options: Dictionary severity evaluation options.
## [br]
## @return 建议文本。
static func get_next_action(
	report: Dictionary,
	action_map: Dictionary = {},
	fallback_action: String = "Review the first reported issue.",
	no_action: String = "No action required.",
	options: Dictionary = {}
) -> String:
	var issue: Dictionary = _get_first_issue_by_priority(report, options)
	if issue.is_empty():
		return no_action

	var kind_key: String = _get_issue_kind(issue)
	if action_map.has(kind_key):
		return GFVariantData.to_text(action_map[kind_key])
	var kind_name: StringName = StringName(kind_key)
	if action_map.has(kind_name):
		return GFVariantData.to_text(action_map[kind_name])
	return fallback_action


## 检查报告是否包含错误。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @schema report: Dictionary report payload.
## [br]
## @param options: 严重级别计算选项。
## [br]
## @schema options: Dictionary severity evaluation options.
## [br]
## @return 存在错误时返回 true。
static func has_error_issues(report: Dictionary, options: Dictionary = {}) -> bool:
	for issue_variant: Variant in _get_issue_array(report):
		var issue: Dictionary = issue_to_dict(issue_variant)
		if not issue.is_empty() and _get_effective_severity(issue, options) == "error":
			return true
	return false


## 生成稳定的问题指纹，用于项目工具的忽略项、基线和 CI 差异比较。
## [br]
## @api public
## [br]
## @param issue: GFValidationIssue 或兼容问题字典。
## [br]
## @schema issue: Variant accepting GFValidationIssue or Dictionary issue payload.
## [br]
## @param fields: 参与指纹计算的字段；为空时使用 severity、kind、path、source_path、key 和 message。
## [br]
## @return 问题指纹；输入无效时返回空字符串。
static func make_issue_fingerprint(issue: Variant, fields: PackedStringArray = PackedStringArray()) -> String:
	var issue_data: Dictionary = issue_to_dict(issue)
	if issue_data.is_empty():
		return ""

	var selected_fields: PackedStringArray = fields.duplicate()
	if selected_fields.is_empty():
		selected_fields = PackedStringArray(["severity", "kind", "path", "source_path", "key", "message"])

	var parts: PackedStringArray = PackedStringArray()
	for field_name: String in selected_fields:
		_append_packed_string(parts, "%s=%s" % [
			field_name,
			_fingerprint_value(GFVariantData.get_option_value(issue_data, field_name)),
		])
	return "|".join(parts)


## 返回应用忽略项和基线后的报告副本。
## [br]
## @api public
## [br]
## @param report: 输入报告字典，不会被修改。
## [br]
## @schema report: Dictionary report payload.
## [br]
## @param options: 可选过滤设置，支持 ignored_kinds、ignored_paths、ignored_path_patterns、ignored_keys、ignored_fingerprints、baseline_fingerprints、baseline_issues、fingerprint_fields、include_filter_summary。
## [br]
## @schema options: Dictionary issue filtering options.
## [br]
## @return 过滤并重新 finalize 的报告副本。
## [br]
## @schema return: Dictionary finalized report payload.
static func filter_issues(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	var filtered_report: Dictionary = report.duplicate(true)
	var source_issues: Array = _get_issue_array(filtered_report)
	var retained_issues: Array = []
	var filtered_count: int = 0
	var filter_context: Dictionary = _make_filter_context(options)
	for issue_variant: Variant in source_issues:
		var issue: Dictionary = issue_to_dict(issue_variant)
		if issue.is_empty():
			continue
		if _issue_matches_filter(issue, filter_context):
			filtered_count += 1
			continue
		retained_issues.append(issue)

	filtered_report["issues"] = retained_issues
	if GFVariantData.get_option_bool(options, "include_filter_summary", true):
		filtered_report["original_issue_count"] = source_issues.size()
		filtered_report["filtered_issue_count"] = filtered_count

	var subject: String = GFVariantData.to_text(
		GFVariantData.get_option_value(options, "subject", GFVariantData.get_option_string(filtered_report, "subject"))
	)
	return finalize_report(filtered_report, subject, options)


## 将报告中的警告提升为错误。
## [br]
## @api public
## [br]
## @param report: 报告字典。
## [br]
## @schema report: Dictionary report payload mutated in place.
## [br]
## @param kinds: 为空时提升全部警告；否则只提升匹配类别。
## [br]
## @return 同一个报告字典。
## [br]
## @schema return: Dictionary report payload mutated in place.
static func promote_warnings(report: Dictionary, kinds: PackedStringArray = PackedStringArray()) -> Dictionary:
	for issue_variant: Variant in _get_issue_array(report):
		var validation_issue: RefCounted = _get_script_instance(issue_variant, _GF_VALIDATION_ISSUE_SCRIPT)
		if validation_issue != null:
			var kind_key: String = GFVariantData.to_text(validation_issue.call(&"get_kind_key"))
			if GFVariantData.to_bool(validation_issue.call(&"is_warning")) and (kinds.is_empty() or kinds.has(kind_key)):
				validation_issue.set("severity", _error_severity_value())
			continue
		if issue_variant is Dictionary:
			var issue: Dictionary = issue_variant
			if _severity_to_string(GFVariantData.get_option_value(issue, "severity", "")) != "warning":
				continue
			if kinds.is_empty() or kinds.has(_get_issue_kind(issue)):
				issue["severity"] = "error"
	return report


# --- 私有/辅助方法 ---

static func _get_issue_array(report: Dictionary) -> Array:
	var issues_variant: Variant = GFVariantData.get_option_value(report, "issues", [])
	if not (issues_variant is Array):
		var empty_issues: Array = []
		report["issues"] = empty_issues
		return empty_issues
	var issues: Array = issues_variant
	report["issues"] = issues
	return issues


static func _source_span_to_dict(source_span: Variant) -> Dictionary:
	var source_span_instance: RefCounted = _get_script_instance(source_span, _GF_SOURCE_SPAN_SCRIPT)
	if source_span_instance != null:
		return _call_dictionary(source_span_instance, &"to_dict", [false, true])
	if source_span is Dictionary:
		var span: RefCounted = _make_source_span()
		if span == null:
			return {}
		var source_span_data: Dictionary = source_span
		_call_void(span, &"apply_dict", [source_span_data])
		return _call_dictionary(span, &"to_dict", [false, true])
	return {}


static func _get_effective_severity(issue: Dictionary, options: Dictionary) -> String:
	var severity_name: String = _severity_to_string(GFVariantData.get_option_value(issue, "severity", "error"))
	if severity_name == "warning":
		if GFVariantData.get_option_bool(options, "warnings_as_errors", false):
			return "error"
		if _kind_is_promoted(_get_issue_kind(issue), GFVariantData.get_option_value(options, "promote_warning_kinds", PackedStringArray())):
			return "error"
	return severity_name


static func _kind_is_promoted(kind_key: String, promoted_kinds: Variant) -> bool:
	if promoted_kinds is PackedStringArray:
		var promoted_names: PackedStringArray = promoted_kinds
		return promoted_names.has(kind_key)
	if promoted_kinds is Array:
		var promoted_values: Array = promoted_kinds
		return promoted_values.has(kind_key) or promoted_values.has(StringName(kind_key))
	return false


static func _get_issue_kind(issue: Dictionary) -> String:
	var kind_value: Variant = GFVariantData.get_option_value(issue, "kind", "unknown")
	var kind_text: String = GFVariantData.to_text(kind_value)
	return kind_text if not kind_text.is_empty() else "unknown"


static func _get_first_issue_by_priority(report: Dictionary, options: Dictionary) -> Dictionary:
	for issue_variant: Variant in _get_issue_array(report):
		var issue: Dictionary = issue_to_dict(issue_variant)
		if not issue.is_empty() and _get_effective_severity(issue, options) == "error":
			return issue
	for issue_variant: Variant in _get_issue_array(report):
		var issue: Dictionary = issue_to_dict(issue_variant)
		if not issue.is_empty() and _get_effective_severity(issue, options) == "warning":
			return issue
	for issue_variant: Variant in _get_issue_array(report):
		var issue: Dictionary = issue_to_dict(issue_variant)
		if not issue.is_empty():
			return issue
	return {}


static func _make_filter_context(options: Dictionary) -> Dictionary:
	var fingerprint_fields: PackedStringArray = _to_packed_string_array(GFVariantData.get_option_value(options, "fingerprint_fields", PackedStringArray()))
	return {
		"ignored_kinds": _make_string_lookup(GFVariantData.get_option_value(options, "ignored_kinds", PackedStringArray())),
		"ignored_keys": _make_string_lookup(GFVariantData.get_option_value(options, "ignored_keys", PackedStringArray())),
		"ignored_paths": _make_string_lookup(GFVariantData.get_option_value(options, "ignored_paths", PackedStringArray())),
		"ignored_path_regexes": _make_path_pattern_regexes(GFVariantData.get_option_value(options, "ignored_path_patterns", PackedStringArray())),
		"fingerprint_fields": fingerprint_fields,
		"fingerprints": _make_filter_fingerprint_lookup(options, fingerprint_fields),
	}


static func _issue_matches_filter(issue: Dictionary, filter_context: Dictionary) -> bool:
	var kind: String = _get_issue_kind(issue)
	var ignored_kinds: Dictionary = GFVariantData.get_option_dictionary(filter_context, "ignored_kinds")
	if _lookup_has_value(ignored_kinds, kind):
		return true
	var ignored_keys: Dictionary = GFVariantData.get_option_dictionary(filter_context, "ignored_keys")
	if _lookup_has_value(
		ignored_keys,
		GFVariantData.get_option_string(issue, "key")
	):
		return true

	var path: String = GFVariantData.get_option_string(issue, "path")
	var source_path: String = GFVariantData.get_option_string(issue, "source_path")
	var ignored_paths: Dictionary = GFVariantData.get_option_dictionary(filter_context, "ignored_paths")
	if _lookup_has_value(ignored_paths, path) or _lookup_has_value(ignored_paths, source_path):
		return true
	var path_regexes: Array = GFVariantData.get_option_array(filter_context, "ignored_path_regexes")
	if _path_matches_compiled_patterns(path, path_regexes):
		return true
	if _path_matches_compiled_patterns(source_path, path_regexes):
		return true

	var fingerprint_fields: PackedStringArray = GFVariantData.get_option_packed_string_array(filter_context, "fingerprint_fields")
	var issue_fingerprint: String = make_issue_fingerprint(issue, fingerprint_fields)
	var fingerprints: Dictionary = GFVariantData.get_option_dictionary(filter_context, "fingerprints")
	if _lookup_has_value(fingerprints, issue_fingerprint):
		return true
	return false


static func _make_filter_fingerprint_lookup(options: Dictionary, fingerprint_fields: PackedStringArray) -> Dictionary:
	var lookup: Dictionary = _make_string_lookup(GFVariantData.get_option_value(options, "ignored_fingerprints", PackedStringArray()))
	for fingerprint: String in _to_packed_string_array(GFVariantData.get_option_value(options, "baseline_fingerprints", PackedStringArray())):
		if not fingerprint.is_empty():
			lookup[fingerprint] = true

	var baseline_issues: Array = GFVariantData.get_option_array(options, "baseline_issues")
	for issue_variant: Variant in baseline_issues:
		var fingerprint: String = make_issue_fingerprint(issue_variant, fingerprint_fields)
		if not fingerprint.is_empty():
			lookup[fingerprint] = true
	return lookup


static func _make_string_lookup(value: Variant) -> Dictionary:
	var lookup: Dictionary = {}
	for item: String in _to_packed_string_array(value):
		if not item.is_empty():
			lookup[item] = true
	return lookup


static func _lookup_has_value(lookup: Dictionary, value: String) -> bool:
	return not value.is_empty() and lookup.has(value)


static func _has_text_key(data: Dictionary, key: String) -> bool:
	return data.has(key) or data.has(StringName(key))


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			var text: String = GFVariantData.to_text(item)
			if not text.is_empty():
				_append_packed_string(result, text)
	elif value is String or value is StringName:
		var text: String = GFVariantData.to_text(value)
		if not text.is_empty():
			_append_packed_string(result, text)
	return result


static func _path_matches_patterns(path: String, patterns: Variant) -> bool:
	if path.is_empty():
		return false
	return _path_matches_compiled_patterns(path, _make_path_pattern_regexes(patterns))


static func _make_path_pattern_regexes(patterns: Variant) -> Array[RegEx]:
	var regexes: Array[RegEx] = []
	for pattern: String in _to_packed_string_array(patterns):
		if pattern.is_empty():
			continue
		var regex: RegEx = RegEx.new()
		if regex.compile("^%s$" % _glob_to_regex(pattern)) != OK:
			continue
		regexes.append(regex)
	return regexes


static func _path_matches_compiled_patterns(path: String, regexes: Array) -> bool:
	if path.is_empty():
		return false
	for regex_variant: Variant in regexes:
		if regex_variant is RegEx:
			var regex: RegEx = regex_variant
			if regex.search(path) != null:
				return true
	return false


static func _glob_to_regex(pattern: String) -> String:
	var result: String = ""
	var index: int = 0
	while index < pattern.length():
		var character: String = pattern.substr(index, 1)
		if character == "*":
			if index + 1 < pattern.length() and pattern.substr(index + 1, 1) == "*":
				result += ".*"
				index += 2
			else:
				result += "[^/]*"
				index += 1
			continue
		if character == "?":
			result += "."
		elif "\\.+^$()[]{}|".contains(character):
			result += "\\%s" % character
		else:
			result += character
		index += 1
	return result


static func _fingerprint_value(value: Variant) -> String:
	var compatible: Variant = GFVariantJsonCodec.variant_to_json_compatible(value, {
		"unsupported": "string",
	})
	return JSON.stringify(compatible)


static func _get_script_instance(value: Variant, expected_script: Script) -> RefCounted:
	if not (value is RefCounted):
		return null
	var instance: RefCounted = value
	if _script_matches(instance, expected_script):
		return instance
	return null


static func _script_matches(instance: Object, expected_script: Script) -> bool:
	var script_value: Variant = instance.get_script()
	if not (script_value is Script):
		return false
	var current_script: Script = script_value
	while current_script != null:
		if current_script == expected_script:
			return true
		current_script = current_script.get_base_script()
	return false


static func _make_validation_issue() -> RefCounted:
	return GFValidationIssue.new()


static func _make_validation_report() -> RefCounted:
	return GFValidationReport.new()


static func _make_source_span() -> RefCounted:
	return GFSourceSpan.new()


static func _call_dictionary(instance: RefCounted, method_name: StringName, arguments: Array = []) -> Dictionary:
	if instance == null:
		return {}
	var result: Variant = instance.callv(method_name, arguments)
	return GFVariantData.as_dictionary(result)


static func _call_void(instance: RefCounted, method_name: StringName, arguments: Array = []) -> void:
	if instance == null:
		return
	var _result: Variant = instance.callv(method_name, arguments)


static func _severity_to_string(value: Variant) -> String:
	var severity_value: Variant = _GF_VALIDATION_ISSUE_SCRIPT.call(&"severity_to_string", value)
	var severity_name: String = GFVariantData.to_text(severity_value, "error")
	return severity_name if not severity_name.is_empty() else "error"


static func _error_severity_value() -> int:
	var severity_value: Variant = _GF_VALIDATION_ISSUE_SCRIPT.call(&"normalize_severity", "error")
	return GFVariantData.to_int(severity_value, 2)


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
