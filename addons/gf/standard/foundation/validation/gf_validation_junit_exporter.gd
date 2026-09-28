## GFValidationJUnitExporter: 将 GFValidationReport 导出为 JUnit XML。
##
## 该导出器只负责把通用校验报告转成 CI 友好的文本，不决定测试命名、
## 构建失败策略或项目修复流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFValidationJUnitExporter
extends RefCounted


# --- 公共方法 ---

## 导出单个报告。
## [br]
## @api public
## [br]
## @param report: 校验报告。
## [br]
## @param options: 可选参数，支持 suite_name、warnings_as_failures、include_passing_case。
## [br]
## @schema options: Dictionary JUnit export options.
## [br]
## @return JUnit XML 文本。
static func export_report(report: GFValidationReport, options: Dictionary = {}) -> String:
	return export_reports([report], options)


## 导出多个报告。
## [br]
## @api public
## [br]
## @param reports: 校验报告数组。
## [br]
## @schema reports: Array of GFValidationReport values.
## [br]
## @param options: 可选参数，支持 suite_name、warnings_as_failures、include_passing_case。
## [br]
## @schema options: Dictionary JUnit export options.
## [br]
## @return JUnit XML 文本。
static func export_reports(reports: Array, options: Dictionary = {}) -> String:
	var suite_name: String = GFVariantData.get_option_string(options, "suite_name", "GF Validation")
	var warnings_as_failures: bool = GFVariantData.get_option_bool(options, "warnings_as_failures", true)
	var include_passing_case: bool = GFVariantData.get_option_bool(options, "include_passing_case", true)
	var case_lines: PackedStringArray = PackedStringArray()
	var test_count: int = 0
	var failure_count: int = 0

	for report_variant: Variant in reports:
		var report: GFValidationReport = _as_validation_report(report_variant)
		if report == null:
			continue
		var issues: Array[RefCounted] = report.issues
		if issues.is_empty() and include_passing_case:
			test_count += 1
			_append_packed_string(case_lines, _make_passing_case(report))
			continue
		for issue: RefCounted in issues:
			var validation_issue: GFValidationIssue = _as_validation_issue(issue)
			if validation_issue == null:
				continue
			test_count += 1
			var is_failure: bool = validation_issue.is_error() or (warnings_as_failures and validation_issue.is_warning())
			if is_failure:
				failure_count += 1
			_append_packed_string(case_lines, _make_issue_case(report, validation_issue, is_failure))

	var lines: PackedStringArray = PackedStringArray()
	_append_packed_string(lines, '<?xml version="1.0" encoding="UTF-8"?>')
	_append_packed_string(lines, '<testsuite name="%s" tests="%d" failures="%d" errors="0" skipped="0">' % [
		_escape_attribute(suite_name),
		test_count,
		failure_count,
	])
	for line: String in case_lines:
		_append_packed_string(lines, line)
	_append_packed_string(lines, "</testsuite>")
	return "\n".join(lines)


# --- 私有/辅助方法 ---

## 为没有问题的报告生成一个健康状态 JUnit testcase 元素。
## [br]
## @api private
## [br]
static func _make_passing_case(report: GFValidationReport) -> String:
	return '\t<testcase classname="%s" name="healthy" />' % _escape_attribute(_get_report_subject(report))


## 将问题转换为 testcase；错误及按选项视为失败的警告附带 failure 元素。
## [br]
## @api private
## [br]
static func _make_issue_case(report: GFValidationReport, issue: GFValidationIssue, is_failure: bool) -> String:
	var class_label: String = _escape_attribute(_get_report_subject(report))
	var kind: String = _escape_attribute(issue.get_kind_key())
	var message: String = _escape_attribute(issue.message)
	var severity: String = _escape_attribute(GFValidationIssue.severity_to_string(issue.severity))
	var location: String = _escape_text(issue.get_location_text())
	var text: String = _escape_text(issue.message)
	if not location.is_empty():
		text = "%s\n%s" % [location, text]
	if not is_failure:
		return '\t<testcase classname="%s" name="%s" />' % [class_label, kind]
	return '\t<testcase classname="%s" name="%s"><failure message="%s" type="%s">%s</failure></testcase>' % [
		class_label,
		kind,
		message,
		severity,
		text,
	]


## 读取报告主题；报告为空或主题为空时返回 GFValidationReport。
## [br]
## @api private
## [br]
static func _get_report_subject(report: GFValidationReport) -> String:
	if report == null or report.subject.is_empty():
		return "GFValidationReport"
	return report.subject


## 转义 XML 文本并额外转义双引号和单引号属性字符。
## [br]
## @api private
## [br]
static func _escape_attribute(value: String) -> String:
	return _escape_text(value).replace("\"", "&quot;").replace("'", "&apos;")


## 转义 XML 文本节点中的与号和尖括号。
## [br]
## @api private
## [br]
static func _escape_text(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


## 仅当 Variant 为 GFValidationReport 时返回该报告实例。
## [br]
## @api private
## [br]
static func _as_validation_report(value: Variant) -> GFValidationReport:
	if value is GFValidationReport:
		var report: GFValidationReport = value
		return report
	return null


## 仅当 Variant 为 GFValidationIssue 时返回该问题实例。
## [br]
## @api private
## [br]
static func _as_validation_issue(value: Variant) -> GFValidationIssue:
	if value is GFValidationIssue:
		var issue: GFValidationIssue = value
		return issue
	return null


## 向 PackedStringArray 追加一段文本。
## [br]
## @api private
## [br]
static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
