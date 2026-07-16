## 测试配置表校验报告构建工具。
extends GutTest


# --- 测试 ---

func test_report_helper_adds_stable_issue_fields_and_context() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = helper.make_report(&"items", 2)

	helper.add_issue(report, "warning", "sample_warning", &"items", 1001, &"name", "示例警告。", {
		"source": "res://configs/items.csv",
		"line": 4,
		"column": 2,
		"row_index": 1,
		"rule_id": &"sample_rule",
		"value": "axe",
		"expected_value": "sword",
		"actual_value": "axe",
		"supported_values": ["sword", "shield"],
		"supported_formats": ["csv", "json"],
		"supported_content_types": ["item"],
		"project_only_note": "filtered",
	})
	helper.finalize_report(report)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "仅包含 warning 时报告仍应通过。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "warning 数量应累加。")
	assert_eq(GFVariantData.get_option_string_name(issue, "table_name"), &"items", "问题应包含表名。")
	assert_eq(GFVariantData.get_option_int(issue, "row_key"), 1001, "问题应包含行标识。")
	assert_eq(GFVariantData.get_option_string_name(issue, "field"), &"name", "问题应包含字段名。")
	assert_eq(GFVariantData.get_option_string(issue, "source"), "res://configs/items.csv", "问题应保留来源。")
	assert_eq(GFVariantData.get_option_string_name(issue, "rule_id"), &"sample_rule", "问题应保留规则标识。")
	assert_eq(GFVariantData.get_option_string(issue, "value"), "axe", "问题应保留当前值。")
	assert_eq(GFVariantData.get_option_string(issue, "expected_value"), "sword", "问题应保留期望值。")
	assert_eq(GFVariantData.get_option_string(issue, "actual_value"), "axe", "问题应保留实际值。")
	assert_eq(GFVariantData.get_option_array(issue, "supported_values"), ["sword", "shield"], "问题应保留支持值列表。")
	assert_eq(GFVariantData.get_option_array(issue, "supported_formats"), ["csv", "json"], "问题应保留支持格式列表。")
	assert_eq(GFVariantData.get_option_array(issue, "supported_content_types"), ["item"], "问题应保留支持内容类型列表。")
	assert_false(issue.has("project_only_note"), "未知上下文字段不应进入稳定 issue。")


func test_report_helper_merges_reports_with_optional_row_count() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var target: Dictionary = helper.make_report(&"items", 2)
	var source: Dictionary = helper.make_error_report(&"items", "sample_error", "示例错误。")
	source["row_count"] = 3

	helper.merge_report(target, source, true)
	helper.finalize_report(target)

	assert_false(GFVariantData.get_option_bool(target, "ok"), "合并 error 报告后应失败。")
	assert_eq(GFVariantData.get_option_int(target, "row_count"), 5, "开启 include_row_count 时应累加行数。")
	assert_eq(GFVariantData.get_option_int(target, "error_count"), 1, "错误数量应累加。")
	assert_eq((GFVariantData.get_option_array(target, "issues")).size(), 1, "问题列表应合并。")


func test_report_helper_sanitizes_context_for_json() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = helper.make_report(&"items", 1)

	helper.add_issue(report, "error", "unsafe_context", &"items", 1, &"value", "示例错误。", {
		"value": RefCounted.new(),
		"actual_value": NAN,
		"expected_value": Vector2(1.0, 2.0),
	})
	var text: String = JSON.stringify(report)

	assert_true(text.contains("__gf_report_value__"), "Object 上下文应被报告 codec 脱敏。")
	assert_true(text.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "NaN 和 Vector2 应被编码为 JSON-safe typed marker。")
	assert_false(text.contains("\"actual_value\":null"), "NaN 不应在 JSON.stringify 边界退化为 null。")
