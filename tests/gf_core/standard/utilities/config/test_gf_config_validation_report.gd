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


func test_report_helper_sanitizes_positional_row_key_for_json() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = helper.make_report(&"items", 3)

	helper.add_issue(report, "error", "object_key", &"items", RefCounted.new(), &"id", "Object key。")
	helper.add_issue(report, "error", "nan_key", &"items", NAN, &"id", "NaN key。")
	helper.add_issue(report, "error", "vector_key", &"items", Vector2(1.0, 2.0), &"id", "Vector key。")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var object_key: Variant = GFVariantData.get_option_value(GFVariantData.as_dictionary(issues[0]), "row_key")
	var nan_key: Variant = GFVariantData.get_option_value(GFVariantData.as_dictionary(issues[1]), "row_key")
	var vector_key: Variant = GFVariantData.get_option_value(GFVariantData.as_dictionary(issues[2]), "row_key")
	var text: String = JSON.stringify(report)

	assert_true(object_key is Dictionary, "positional Object row_key 不得作为活对象进入 issue。")
	assert_true(nan_key is Dictionary, "positional NaN row_key 应编码为 JSON-safe marker。")
	assert_true(vector_key is Dictionary, "positional Vector row_key 应编码为 JSON-safe marker。")
	assert_true(text.contains("__gf_report_value__"), "Object row_key 应使用报告 codec 脱敏。")
	assert_true(text.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "Variant row_key 应保留 typed marker。")
	assert_false(text.contains("\"row_key\":null"), "非有限 row_key 不得在最终 stringify 时才退化为 null。")


func test_report_helper_preserves_element_index_through_merge_and_json() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var source: Dictionary = helper.make_report(&"owners", 1)
	helper.add_issue(source, "error", "missing_reference", &"owners", 73, &"item_ids", "元素缺少目标。", {
		"element_index": 0,
		"value": 99,
	})
	var target: Dictionary = helper.make_report(&"all_tables")
	helper.merge_report(target, source)
	helper.finalize_report(target)
	var issues: Array = GFVariantData.get_option_array(target, "issues")
	assert_eq(issues.size(), 1, "合并应保留数组元素问题。")
	if issues.size() != 1:
		return
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var element_index: Variant = issue.get("element_index")
	var value: Variant = issue.get("value")
	assert_true(element_index is int, "元素下标应保留 int 类型，不能转换成字符串。")
	assert_eq(GFVariantData.get_option_int(issue, "element_index", -1), 0, "零基第一个元素的位置不可丢失。")
	assert_true(value is int, "实际标量元素值应保留 int 类型。")
	assert_eq(GFVariantData.get_option_int(issue, "value", -1), 99, "合并应保留具体元素值。")
	assert_eq(GFVariantData.get_option_string_name(issue, "field"), &"item_ids", "字段名应保持原始声明名称。")
	var text: String = JSON.stringify(target)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "包含元素位置的最终报告应能通过 JSON 往返。")
	if parsed is Dictionary:
		var parsed_report: Dictionary = parsed
		var parsed_issues: Array = GFVariantData.get_option_array(parsed_report, "issues")
		assert_eq(parsed_issues.size(), 1, "JSON 往返不得丢失元素问题。")
		if parsed_issues.size() == 1:
			var parsed_issue: Dictionary = GFVariantData.as_dictionary(parsed_issues[0])
			assert_eq(GFVariantData.get_option_int(parsed_issue, "element_index", -1), 0, "JSON 往返应保留元素位置。")
			assert_eq(GFVariantData.get_option_int(parsed_issue, "value", -1), 99, "JSON 往返应保留实际元素值。")


func test_report_helper_does_not_invent_element_index_for_container_issue() -> void:
	var helper: GFConfigValidationReport = GFConfigValidationReport.new()
	var source: Dictionary = helper.make_report(&"owners", 1)
	helper.add_issue(source, "error", "invalid_reference_value", &"owners", 73, &"item_ids", "来源不是数组。", { "value": null })
	var target: Dictionary = helper.make_report(&"all_tables")
	helper.merge_report(target, source)
	var issues: Array = GFVariantData.get_option_array(target, "issues")
	assert_eq(issues.size(), 1, "容器问题应保留。")
	if issues.size() != 1:
		return
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	assert_false(issue.has("element_index"), "无元素位置的容器问题不应补零或其他虚构下标。")
	assert_true(issue.has("value"), "容器问题仍应保存实际 null 值。")
	var value: Variant = issue.get("value")
	assert_true(value == null, "null 容器值应保持 null。")
