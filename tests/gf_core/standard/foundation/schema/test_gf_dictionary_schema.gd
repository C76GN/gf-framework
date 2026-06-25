## 测试通用 Dictionary schema primitives。
extends GutTest


# --- 测试方法 ---

func test_dictionary_schema_reports_missing_invalid_and_extra_fields() -> void:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = &"profile"
	schema.allow_extra_fields = false
	var id_field: GFSchemaField = _make_field(&"id", GFSchemaField.ValueType.STRING, {
		"required": true,
		"allow_null": false,
	})
	var score_field: GFSchemaField = _make_field(&"score", GFSchemaField.ValueType.INT)
	var _id_added: bool = schema.add_field(id_field)
	var _score_added: bool = schema.add_field(score_field)

	var report: GFValidationReport = schema.validate_dictionary({
		"score": "bad",
		"extra": true,
	}, {
		"path": "profile",
	})

	assert_false(report.is_ok(), "缺必填、类型错误和额外字段应让 schema 校验失败。")
	assert_eq(report.get_error_count(), 3, "应报告三个错误。")
	assert_eq(_find_issue_path(report, "missing_required"), "profile/id", "缺必填字段应带稳定路径。")
	assert_eq(_find_issue_path(report, "invalid_type"), "profile/score", "类型错误应带稳定路径。")
	assert_eq(_find_issue_path(report, "extra_field"), "profile/extra", "额外字段应带稳定路径。")


func test_dictionary_schema_applies_defaults_and_coerces_values() -> void:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = &"settings"
	schema.coerce_values = true
	var active_field: GFSchemaField = _make_field(&"active", GFSchemaField.ValueType.BOOL, {
		"default_value": false,
	})
	var count_field: GFSchemaField = _make_field(&"count", GFSchemaField.ValueType.INT, {
		"default_value": 3,
	})
	var _active_added: bool = schema.add_field(active_field)
	var _count_added: bool = schema.add_field(count_field)

	var coerced: Dictionary = schema.coerce_dictionary({
		"active": "true",
	})
	var report: GFValidationReport = schema.validate_dictionary({
		"active": "true",
	})

	assert_true(report.is_ok(), "可转换值在开启 coerce_values 后应通过校验。")
	assert_eq(GFVariantData.get_option_bool(coerced, "active"), true, "bool 字段应被转换。")
	assert_eq(GFVariantData.get_option_int(coerced, "count"), 3, "缺失字段应补默认值。")


func test_dictionary_schema_can_warn_on_coerce_failures() -> void:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = &"settings"
	schema.coerce_values = true
	schema.fail_on_coerce_error = false
	var active_field: GFSchemaField = _make_field(&"active", GFSchemaField.ValueType.BOOL)
	var _active_added: bool = schema.add_field(active_field)

	var report: GFValidationReport = schema.validate_dictionary({
		"active": "maybe",
	})

	assert_true(report.is_ok(), "fail_on_coerce_error=false 时转换失败应作为 warning。")
	assert_eq(report.get_warning_count(), 1, "转换失败 warning 应保留。")
	assert_eq(_find_issue_kind(report, "coerce_failed"), "coerce_failed", "转换失败应有稳定 issue kind。")


func test_dictionary_schema_validates_nested_dictionaries_and_array_items() -> void:
	var stats_schema: GFDictionarySchema = GFDictionarySchema.new()
	stats_schema.schema_id = &"stats"
	var power_field: GFSchemaField = _make_field(&"power", GFSchemaField.ValueType.INT, {
		"required": true,
	})
	var _power_added: bool = stats_schema.add_field(power_field)

	var tag_item_schema: GFSchemaField = _make_field(&"", GFSchemaField.ValueType.STRING, {
		"allow_null": false,
	})
	var root_schema: GFDictionarySchema = GFDictionarySchema.new()
	root_schema.schema_id = &"character"
	var stats_field: GFSchemaField = _make_field(&"stats", GFSchemaField.ValueType.DICTIONARY, {
		"dictionary_schema": stats_schema,
	})
	var tags_field: GFSchemaField = _make_field(&"tags", GFSchemaField.ValueType.ARRAY, {
		"array_item_schema": tag_item_schema,
	})
	var _stats_added: bool = root_schema.add_field(stats_field)
	var _tags_added: bool = root_schema.add_field(tags_field)

	var report: GFValidationReport = root_schema.validate_dictionary({
		"stats": {
			"power": "bad",
		},
		"tags": ["safe", 2],
	})

	assert_false(report.is_ok(), "嵌套字段和数组元素类型错误应被报告。")
	assert_eq(report.get_error_count(), 2, "应报告嵌套字段和数组元素两个错误。")
	assert_true(_has_issue_path(report, "stats/power"), "嵌套字典字段应带路径。")
	assert_true(_has_issue_path(report, "tags[1]"), "数组元素应带路径。")


func test_dictionary_schema_definition_reports_empty_and_duplicate_fields() -> void:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.fields = [
		_make_field(&"", GFSchemaField.ValueType.STRING),
		_make_field(&"id", GFSchemaField.ValueType.STRING),
		_make_field(&"id", GFSchemaField.ValueType.INT),
	]

	var report: GFValidationReport = schema.validate_definition()

	assert_false(report.is_ok(), "空字段名和重复字段名应让定义自检失败。")
	assert_eq(_find_issue_kind(report, "empty_field_name"), "empty_field_name")
	assert_eq(_find_issue_kind(report, "duplicate_field_name"), "duplicate_field_name")


func test_dictionary_schema_definition_preserves_nested_paths() -> void:
	var nested_schema: GFDictionarySchema = GFDictionarySchema.new()
	nested_schema.fields = [
		_make_field(&"id", GFSchemaField.ValueType.STRING),
		_make_field(&"id", GFSchemaField.ValueType.INT),
	]

	var schema: GFDictionarySchema = GFDictionarySchema.new()
	var stats_field: GFSchemaField = _make_field(&"stats", GFSchemaField.ValueType.DICTIONARY, {
		"dictionary_schema": nested_schema,
	})
	var _stats_added: bool = schema.add_field(stats_field)

	var report: GFValidationReport = schema.validate_definition()

	assert_false(report.is_ok(), "嵌套 schema 定义错误应被父 schema 汇总。")
	assert_eq(_find_issue_path(report, "duplicate_field_name"), "stats/id", "嵌套定义问题应保留父字段路径。")


func test_dictionary_schema_configure_applies_options_without_fields() -> void:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	var configured_schema: GFDictionarySchema = schema.configure(&"profile", [], {
		"allow_extra_fields": false,
		"coerce_values": true,
		"fail_on_coerce_error": false,
		"metadata": {
			"owner": "tools",
		},
	})
	var description: Dictionary = schema.describe()
	var copied_schema: GFDictionarySchema = schema.duplicate_schema()

	assert_true(configured_schema == schema, "configure() 应返回当前 schema。")
	assert_false(schema.allow_extra_fields, "空字段 schema 也应应用 allow_extra_fields。")
	assert_true(schema.coerce_values, "空字段 schema 也应应用 coerce_values。")
	assert_false(schema.fail_on_coerce_error, "空字段 schema 也应应用 fail_on_coerce_error。")
	assert_eq(GFVariantData.get_option_string(schema.metadata, "owner"), "tools", "空字段 schema 也应应用 metadata。")
	assert_false(GFVariantData.get_option_bool(description, "allow_extra_fields", true), "describe() 应反映 configure options。")
	assert_true(GFVariantData.get_option_bool(description, "coerce_values"), "describe() 应反映 coerce_values。")
	assert_false(copied_schema.allow_extra_fields, "duplicate_schema() 应保留 configure options。")
	assert_true(copied_schema.coerce_values, "duplicate_schema() 应保留 coerce_values。")
	assert_false(copied_schema.fail_on_coerce_error, "duplicate_schema() 应保留 fail_on_coerce_error。")
	assert_eq(GFVariantData.get_option_string(copied_schema.metadata, "owner"), "tools", "duplicate_schema() 应保留 metadata。")


func test_schema_field_validation_rules_inherit_field_context() -> void:
	var positive_rule: GFValidationRule = GFValidationRule.new().configure(
		&"positive_value",
		func(value: Variant, _report: GFValidationReport, _context: Dictionary) -> String:
			return "" if GFVariantData.to_int(value, 0) > 0 else "Value must be positive."
	)
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	var score_field: GFSchemaField = _make_field(&"score", GFSchemaField.ValueType.INT, {
		"validation_rules": [positive_rule],
	})
	var _score_added: bool = schema.add_field(score_field)

	var report: GFValidationReport = schema.validate_dictionary({
		"score": 0,
	}, {
		"path": "profile",
	})

	assert_false(report.is_ok(), "字段级规则返回错误时应让 schema 校验失败。")
	assert_eq(_find_issue_kind(report, "positive_value"), "positive_value", "规则 ID 应成为稳定 issue kind。")
	assert_eq(_find_issue_path(report, "positive_value"), "profile/score", "规则 issue 应继承字段路径。")


func test_schema_field_duplicates_validation_rules() -> void:
	var rule: GFValidationRule = GFValidationRule.new().configure(&"not_empty")
	rule.metadata = {
		"owner": "schema",
	}
	var field: GFSchemaField = _make_field(&"name", GFSchemaField.ValueType.STRING)
	var _rule_added: bool = field.add_validation_rule(rule)

	var copied_field: GFSchemaField = field.duplicate_field()
	var description: Dictionary = copied_field.describe()
	var rule_descriptions: Array = GFVariantData.get_option_array(description, "validation_rules")
	var first_rule_description: Dictionary = {}
	if not rule_descriptions.is_empty():
		first_rule_description = GFVariantData.as_dictionary(rule_descriptions[0])

	assert_eq(copied_field.get_enabled_validation_rules().size(), 1, "字段副本应保留启用的校验规则。")
	assert_eq(copied_field.validation_rules[0].rule_id, &"not_empty", "字段副本应复制规则配置。")
	assert_eq(rule_descriptions.size(), 1, "describe() 应包含字段级规则摘要。")
	assert_eq(GFVariantData.get_option_string(first_rule_description, "rule_id"), "not_empty", "规则摘要应包含 rule_id。")


# --- 私有/辅助方法 ---

func _make_field(
	field_name: StringName,
	value_type: GFSchemaField.ValueType,
	options: Dictionary = {}
) -> GFSchemaField:
	var field: GFSchemaField = GFSchemaField.new()
	var _configured_field: GFSchemaField = field.configure(field_name, value_type, options)
	return field


func _find_issue_kind(report: GFValidationReport, kind: String) -> String:
	for issue_ref: RefCounted in report.issues:
		var issue: GFValidationIssue = _as_issue(issue_ref)
		if issue != null and issue.get_kind_key() == kind:
			return issue.get_kind_key()
	return ""


func _find_issue_path(report: GFValidationReport, kind: String) -> String:
	for issue_ref: RefCounted in report.issues:
		var issue: GFValidationIssue = _as_issue(issue_ref)
		if issue != null and issue.get_kind_key() == kind:
			return issue.path
	return ""


func _has_issue_path(report: GFValidationReport, path: String) -> bool:
	for issue_ref: RefCounted in report.issues:
		var issue: GFValidationIssue = _as_issue(issue_ref)
		if issue != null and issue.path == path:
			return true
	return false


func _as_issue(value: Variant) -> GFValidationIssue:
	if value is GFValidationIssue:
		var issue: GFValidationIssue = value
		return issue
	return null
