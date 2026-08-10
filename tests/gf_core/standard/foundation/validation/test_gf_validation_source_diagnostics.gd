## 测试校验报告源码定位与诊断适配辅助。
extends GutTest


func test_source_span_normalizes_source_alias_and_location() -> void:
	var span: GFSourceSpan = _source_span_from_ref(GFSourceSpan.from_dict({
		"source": "res://data/items.csv",
		"line": 4,
		"column": 2,
		"length": 5,
	}))
	var data: Dictionary = span.to_dict(false, true)

	assert_eq(span.source_path, "res://data/items.csv", "source 应作为 source_path 兼容别名。")
	assert_eq(GFVariantData.get_option_string(data, "source_path"), "res://data/items.csv", "应输出标准 source_path。")
	assert_eq(GFVariantData.get_option_string(data, "source"), "res://data/items.csv", "需要时应输出 legacy source 别名。")
	assert_eq(span.get_effective_end_column(), 7, "未显式设置 end_column 时应由 column + length 推导。")
	assert_eq(span.get_location_text(), "res://data/items.csv:4:2", "定位文本应包含路径、行与列。")


func test_validation_issue_preserves_source_span_fields() -> void:
	var issue: GFValidationIssue = _issue_from_ref(GFValidationIssue.from_dict({
		"severity": "warning",
		"kind": "invalid_cell",
		"message": "Cell is invalid.",
		"source": "res://data/items.csv",
		"line": 6,
		"column": 3,
		"length": 2,
		"row_key": "potion",
	}))
	var data: Dictionary = issue.to_dict()
	var source_span: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(data, "source_span")
	)

	assert_eq(GFVariantData.get_option_string(data, "source_path"), "res://data/items.csv", "问题应暴露标准 source_path 字段。")
	assert_eq(GFVariantData.get_option_string(data, "source"), "res://data/items.csv", "问题应保留 source 兼容字段。")
	assert_eq(GFVariantData.get_option_int(data, "line"), 6, "问题应暴露行号。")
	assert_eq(GFVariantData.get_option_int(data, "column"), 3, "问题应暴露列号。")
	assert_eq(GFVariantData.get_option_int(source_span, "line"), 6, "嵌套 source_span 应保留行号。")
	assert_eq(GFVariantData.get_option_string(data, "row_key"), "potion", "额外业务定位字段仍应保留。")
	assert_eq(issue.get_location_text(), "res://data/items.csv:6:3", "问题应能生成定位文本。")


func test_validation_issue_owns_mutable_key_snapshots() -> void:
	var constructor_key: Dictionary = { "id": 1 }
	var configure_key: Array = ["profile", 2]
	var constructed: GFValidationIssue = GFValidationIssue.new(
		GFValidationIssue.Severity.ERROR,
		&"constructor_key",
		"Constructor key.",
		constructor_key
	)
	var configured: GFValidationIssue = GFValidationIssue.new()
	var _configured_issue: RefCounted = configured.configure(
		GFValidationIssue.Severity.WARNING,
		&"configure_key",
		"Configure key.",
		configure_key
	)

	constructor_key["id"] = 9
	configure_key[1] = 7
	var constructed_key: Dictionary = GFVariantData.as_dictionary(constructed.key)
	var configured_key: Array = GFVariantData.as_array(configured.key)

	assert_eq(GFVariantData.get_option_int(constructed_key, "id"), 1, "constructor 应在入口取得 Dictionary key 快照。")
	assert_eq(GFVariantData.to_int(configured_key[1]), 2, "configure 应在入口取得 Array key 快照。")


func test_validation_rule_result_owns_context_key_snapshot() -> void:
	var source_key: Dictionary = { "field": "score" }
	var rule: GFValidationRule = GFValidationRule.new().configure(
		&"invalid_value",
		func(_target: Variant, _report: GFValidationReport, _context: Dictionary) -> String:
			return "Invalid value."
	)
	var report: GFValidationReport = rule.validate(0, { "key": source_key })

	source_key["field"] = "mutated"
	var issue: GFValidationIssue = _issue_from_ref(report.issues[0])
	var issue_key: Dictionary = GFVariantData.as_dictionary(issue.key)

	assert_eq(GFVariantData.get_option_string(issue_key, "field"), "score", "规则生成 issue 时应拥有 context key 快照。")


func test_issue_metadata_does_not_create_source_span() -> void:
	var issue: GFValidationIssue = _issue_from_ref(GFValidationIssue.from_dict({
		"severity": "warning",
		"kind": "metadata_only",
		"message": "Metadata only.",
		"metadata": {
			"owner": "importer",
		},
	}))
	var data: Dictionary = issue.to_dict()
	var metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(data, "metadata"))

	assert_false(data.has("source_span"), "普通问题 metadata 不应被误写成 source_span。")
	assert_eq(GFVariantData.get_option_string(metadata, "owner"), "importer", "普通问题 metadata 应保留在顶层。")


func test_report_source_issue_converts_to_editor_diagnostics() -> void:
	var report: GFValidationReport = GFValidationReport.new("Config table")
	var _add_source_error_result_64: Variant = report.add_source_error(&"invalid_value", "Value is invalid.", {
		"source_path": "res://data/items.csv",
		"line": 8,
		"column": 4,
		"length": 3,
	})

	var diagnostics: Array[Dictionary] = GFValidationDiagnosticAdapter.report_to_diagnostics(report, {
		"include_positionless": false,
	})
	var line_records: Array[Dictionary] = GFValidationDiagnosticAdapter.make_line_records(diagnostics)
	var grouped: Dictionary = GFValidationDiagnosticAdapter.group_by_source(diagnostics)
	var diagnostic: Dictionary = diagnostics[0]
	var grouped_source: Array = GFVariantData.as_array(
		GFVariantData.get_option_value(grouped, "res://data/items.csv")
	)

	assert_eq(diagnostics.size(), 1, "报告应转换为一条诊断。")
	assert_eq(GFVariantData.get_option_string(diagnostic, "source_path"), "res://data/items.csv", "诊断应包含源路径。")
	assert_eq(GFVariantData.get_option_int(diagnostic, "line_index"), 7, "诊断应提供 0-based 行索引。")
	assert_eq(GFVariantData.get_option_int(diagnostic, "column_index"), 3, "诊断应提供 0-based 列索引。")
	assert_true(GFVariantData.get_option_string(diagnostic, "display_text").contains("Value is invalid."), "显示文本应包含问题说明。")
	assert_eq(line_records.size(), 1, "可定位诊断应生成行记录。")
	assert_eq(grouped_source.size(), 1, "诊断应按源路径分组。")


func test_diagnostic_adapter_normalizes_legacy_issue_fields() -> void:
	var diagnostic: Dictionary = GFValidationDiagnosticAdapter.issue_to_diagnostic({
		"severity": "error",
		"code": "legacy_code",
		"type": "legacy_type",
		"message": "Legacy issue.",
		"path": "items[0]",
	})

	assert_eq(GFVariantData.get_option_string(diagnostic, "kind"), "unknown", "诊断适配器不应再把旧 code/type 当作问题类别。")
	assert_false(diagnostic.has("code"), "诊断不应输出旧 code 字段。")
	assert_false(diagnostic.has("type"), "诊断不应输出旧 type 字段。")
	assert_eq(GFVariantData.get_option_string(diagnostic, "path"), "items[0]", "标准定位字段应继续保留。")


func test_report_source_issue_accepts_string_severity() -> void:
	var report: GFValidationReport = GFValidationReport.new("Config table")
	var _add_source_issue_result_107: Variant = report.add_source_issue(
		"warning",
		&"invalid_value",
		"Value is suspicious.",
		{
			"source_path": "res://data/items.csv",
			"line": 8,
			"column": 4,
		}
	)

	assert_eq(report.get_warning_count(), 1, "对象式源码问题入口应接受字符串 severity。")
	assert_eq(report.get_error_count(), 0, "warning 字符串不应被误归一为 error。")


func test_dictionary_report_can_append_source_issue() -> void:
	var report: Dictionary = {
		"issues": [],
	}
	var _appended_report: Dictionary = GFValidationReportDictionary.append_source_issue(
		report,
		"warning",
		&"missing_optional",
		"Optional field is missing.",
		GFSourceSpan.make("res://data/items.csv", 10, 1, 4),
		{ "row_key": "shield" }
	)
	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(report, "Config table")

	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var source_span: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(issue, "source_span")
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "只有警告时报告仍应通过。")
	assert_eq(GFVariantData.get_option_string(issue, "source_path"), "res://data/items.csv", "字典报告应包含标准 source_path。")
	assert_eq(GFVariantData.get_option_int(issue, "line"), 10, "字典报告应包含行号。")
	assert_eq(GFVariantData.get_option_int(source_span, "column"), 1, "嵌套 source_span 应包含列号。")
	assert_eq(GFVariantData.get_option_string(issue, "row_key"), "shield", "附加字段应保留。")


# --- 私有/辅助方法 ---

func _source_span_from_ref(value: RefCounted) -> GFSourceSpan:
	if value is GFSourceSpan:
		var span: GFSourceSpan = value
		return span
	return null


func _issue_from_ref(value: RefCounted) -> GFValidationIssue:
	if value is GFValidationIssue:
		var issue: GFValidationIssue = value
		return issue
	return null
