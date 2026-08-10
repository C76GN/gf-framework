## 测试 GFValidationConstraintRule 通用约束规则。
extends GutTest


# --- 测试方法 ---

func test_range_constraint_reports_out_of_bounds_and_describes_rule() -> void:
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(0.0, 10.0, {
		"rule_id": &"score_range",
		"metadata": {
			"unit": "points",
		},
	})

	var ok_report: GFValidationReport = rule.validate(5)
	var report: GFValidationReport = rule.validate(-1, {
		"path": "score",
		"key": &"score",
		"subject": "profile",
	})
	var issue: GFValidationIssue = _first_issue(report)
	var description: Dictionary = rule.describe()

	assert_true(ok_report.is_ok(), "范围内数值应通过。")
	assert_false(report.is_ok(), "范围外数值应报告错误。")
	assert_not_null(issue, "范围错误应生成 issue。")
	assert_eq(issue.get_kind_key(), "score_range", "显式 rule_id 应成为 issue kind。")
	assert_eq(issue.path, "score", "规则应继承调用方路径。")
	assert_eq(GFVariantData.get_option_string(issue.metadata, "constraint_kind"), "range", "issue metadata 应标记约束类别。")
	assert_eq(GFVariantData.get_option_string(description, "constraint_kind_name"), "range", "describe() 应包含约束类别。")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.get_option_dictionary(description, "metadata"), "unit"),
		"points",
		"describe() 应保留规则 metadata。"
	)


func test_range_constraint_compares_large_integers_without_float_rounding() -> void:
	var exact_boundary: int = 9_007_199_254_740_992
	var adjacent_value: int = exact_boundary + 1
	var exact_rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(
		9_007_199_254_740_992.0,
		9_007_199_254_740_992.0
	)
	var exclusive_rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(
		9_007_199_254_740_992.0,
		9_007_199_254_740_994.0,
		{ "inclusive_minimum": false }
	)

	assert_true(exact_rule.validate(exact_boundary).is_ok(), "精确落在大整数边界上的值应通过。")
	assert_false(exact_rule.validate(adjacent_value).is_ok(), "相邻 int 不得因 float 舍入折叠到同一边界。")
	assert_true(exclusive_rule.validate(adjacent_value).is_ok(), "exclusive 大整数边界后的相邻值应按精确 int 语义通过。")


func test_range_constraint_compares_int64_extremes_against_float_bounds() -> void:
	var minimum_int: int = -9_223_372_036_854_775_808
	var maximum_int: int = 9_223_372_036_854_775_807
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(
		-9_223_372_036_854_775_808.0,
		9_223_372_036_854_775_808.0
	)

	assert_true(rule.validate(minimum_int).is_ok(), "int64 最小值应能与可精确表示的 float 下界比较。")
	assert_true(rule.validate(maximum_int).is_ok(), "int64 最大值应小于 exclusive int64 上界对应的 float。")


func test_set_constraint_supports_case_insensitive_text() -> void:
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_set(["Idle", "Run"], {
		"rule_id": &"state_allowed",
		"case_sensitive": false,
	})

	var ok_report: GFValidationReport = rule.validate("idle")
	var report: GFValidationReport = rule.validate("Jump")

	assert_true(ok_report.is_ok(), "关闭大小写敏感后文本集合应按小写比较。")
	assert_false(report.is_ok(), "集合外值应报告错误。")
	assert_eq(_find_issue_kind(report, "state_allowed"), "state_allowed", "集合约束应使用稳定 rule_id。")


func test_regex_constraint_supports_full_match() -> void:
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_regex("[a-z0-9_]+", {
		"rule_id": &"snake_case_id",
		"require_full_match": true,
	})

	var ok_report: GFValidationReport = rule.validate("item_01")
	var report: GFValidationReport = rule.validate("item 01")

	assert_true(ok_report.is_ok(), "完整匹配的文本应通过。")
	assert_false(report.is_ok(), "未完整匹配的文本应报告错误。")
	assert_eq(_find_issue_kind(report, "snake_case_id"), "snake_case_id", "正则约束应使用稳定 rule_id。")


func test_size_constraint_supports_collections_and_packed_arrays() -> void:
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_size(2, 3, {
		"rule_id": &"small_collection",
	})

	var ok_report: GFValidationReport = rule.validate(["a", "b"])
	var too_large_report: GFValidationReport = rule.validate(PackedStringArray(["a", "b", "c", "d"]))
	var invalid_type_report: GFValidationReport = rule.validate(42)

	assert_true(ok_report.is_ok(), "范围内集合尺寸应通过。")
	assert_false(too_large_report.is_ok(), "过大 PackedArray 应报告错误。")
	assert_false(invalid_type_report.is_ok(), "无尺寸值应报告错误。")
	assert_eq(_find_issue_kind(too_large_report, "small_collection"), "small_collection", "尺寸约束应使用稳定 rule_id。")


func test_schema_fields_can_use_constraint_rule_and_duplicate_subclass() -> void:
	var range_rule: GFValidationConstraintRule = GFValidationConstraintRule.new().configure_range(1.0, 5.0, {
		"rule_id": &"retry_range",
	})
	var field: GFSchemaField = GFSchemaField.new().configure(&"retry_count", GFSchemaField.ValueType.INT, {
		"validation_rules": [range_rule],
	})
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	var _field_added: bool = schema.add_field(field)

	var report: GFValidationReport = schema.validate_dictionary({
		"retry_count": 8,
	}, {
		"path": "options",
	})
	var copied_field: GFSchemaField = field.duplicate_field()
	var description: Dictionary = copied_field.describe()
	var rule_descriptions: Array = GFVariantData.get_option_array(description, "validation_rules")
	var first_rule_description: Dictionary = GFVariantData.as_dictionary(rule_descriptions[0])

	assert_false(report.is_ok(), "字段级范围规则失败时 schema 应报告错误。")
	assert_eq(_find_issue_path(report, "retry_range"), "options/retry_count", "字段级约束应继承字段路径。")
	assert_true(copied_field.validation_rules[0] is GFValidationConstraintRule, "字段副本应保留约束规则子类。")
	assert_eq(GFVariantData.get_option_string(first_rule_description, "constraint_kind_name"), "range", "字段描述应包含约束规则细节。")


# --- 私有/辅助方法 ---

func _first_issue(report: GFValidationReport) -> GFValidationIssue:
	for issue_ref: RefCounted in report.issues:
		if issue_ref is GFValidationIssue:
			var issue: GFValidationIssue = issue_ref
			return issue
	return null


func _find_issue_kind(report: GFValidationReport, kind: String) -> String:
	for issue_ref: RefCounted in report.issues:
		if issue_ref is GFValidationIssue:
			var issue: GFValidationIssue = issue_ref
			if issue.get_kind_key() == kind:
				return issue.get_kind_key()
	return ""


func _find_issue_path(report: GFValidationReport, kind: String) -> String:
	for issue_ref: RefCounted in report.issues:
		if issue_ref is GFValidationIssue:
			var issue: GFValidationIssue = issue_ref
			if issue.get_kind_key() == kind:
				return issue.path
	return ""
