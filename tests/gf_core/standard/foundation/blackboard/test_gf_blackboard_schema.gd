## 测试通用黑板 Schema 与字段声明。
extends GutTest


func test_blackboard_schema_coerces_values_and_defaults() -> void:
	var schema: GFBlackboardSchema = _make_agent_schema()
	schema.coerce_values = true

	var values: Dictionary = schema.apply_defaults({
		"hp": "12",
		"target": "enemy",
		"position": [1, 2],
	})
	var report: Dictionary = schema.validate_values(values)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "补默认值并转换后应通过 schema 校验。")
	assert_eq(GFVariantData.get_option_int(values, &"hp"), 12, "字段应按声明转换为 int。")
	assert_eq(GFVariantData.get_option_string_name(values, &"target"), &"enemy", "字段应按声明转换为 StringName。")
	assert_eq(GFVariantData.get_option_vector2(values, &"position"), Vector2(1.0, 2.0), "数组应可转换为 Vector2。")
	assert_true(GFVariantData.get_option_bool(values, &"enabled"), "缺失字段应补默认值。")


func test_blackboard_schema_reports_missing_type_and_extra_keys() -> void:
	var schema: GFBlackboardSchema = _make_agent_schema()
	schema.allow_extra_keys = false

	var report: Dictionary = schema.validate_values({
		"hp": "bad",
		"extra": true,
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺字段、类型错误和额外字段应使校验失败。")
	assert_true(_has_issue(report, "missing_required"), "报告应包含缺失必填字段。")
	assert_true(_has_issue(report, "invalid_type"), "报告应包含类型错误。")
	assert_true(_has_issue(report, "extra_key"), "报告应包含额外字段。")


func test_blackboard_schema_validation_does_not_apply_defaults() -> void:
	var schema: GFBlackboardSchema = _make_agent_schema()
	schema.coerce_values = true
	var enabled_entry: GFBlackboardEntry = schema.get_entry(&"enabled")
	enabled_entry.required = true

	var report: Dictionary = schema.validate_values({
		"hp": "12",
		"target": "enemy",
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "validate_values 只校验输入，不应隐式补默认值。")
	assert_true(_has_issue(report, "missing_required"), "必填默认值缺失时仍应报告 missing_required。")


func test_blackboard_schema_duplicate_isolated_entries() -> void:
	var schema: GFBlackboardSchema = _make_agent_schema()
	var schema_copy: GFBlackboardSchema = schema.duplicate_schema()
	schema_copy.entries.clear()

	var report: Dictionary = schema.validate_values({
		"hp": 10,
		"target": &"enemy",
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "修改 schema 拷贝不应污染原 schema。")
	assert_eq(schema_copy.entries.size(), 0, "拷贝应可独立修改。")


func test_blackboard_schema_reports_duplicate_entry_keys() -> void:
	var schema: GFBlackboardSchema = _make_agent_schema()
	var duplicate_entry: GFBlackboardEntry = GFBlackboardEntry.new()
	duplicate_entry.key = &"hp"
	duplicate_entry.value_type = GFBlackboardEntry.ValueType.FLOAT
	schema.entries.append(duplicate_entry)

	var report: Dictionary = schema.validate_values({
		"hp": 10,
		"target": &"enemy",
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "重复字段声明应让 schema 校验失败。")
	assert_true(_has_issue(report, "duplicate_entry_key"), "报告应包含 duplicate_entry_key。")


func test_blackboard_entry_rejects_invalid_color_string() -> void:
	var entry: GFBlackboardEntry = GFBlackboardEntry.new()
	entry.value_type = GFBlackboardEntry.ValueType.COLOR

	var invalid_result: Dictionary = entry.try_coerce_value("not_a_color")
	var valid_result: Dictionary = entry.try_coerce_value("#ff0000")

	assert_false(GFVariantData.get_option_bool(invalid_result, "ok"), "无效颜色字符串不应静默转换为黑色。")
	assert_true(GFVariantData.get_option_bool(valid_result, "ok"), "有效 HTML 颜色字符串应可转换。")
	assert_eq(_color_option(valid_result, "value"), Color(1.0, 0.0, 0.0, 1.0), "颜色通道应来自输入文本。")


# --- 私有/辅助方法 ---

func _make_agent_schema() -> GFBlackboardSchema:
	var hp_entry: GFBlackboardEntry = GFBlackboardEntry.new()
	hp_entry.key = &"hp"
	hp_entry.value_type = GFBlackboardEntry.ValueType.INT
	hp_entry.required = true
	hp_entry.allow_null = false

	var target_entry: GFBlackboardEntry = GFBlackboardEntry.new()
	target_entry.key = &"target"
	target_entry.value_type = GFBlackboardEntry.ValueType.STRING_NAME
	target_entry.required = true
	target_entry.allow_null = false

	var position_entry: GFBlackboardEntry = GFBlackboardEntry.new()
	position_entry.key = &"position"
	position_entry.value_type = GFBlackboardEntry.ValueType.VECTOR2
	position_entry.default_value = Vector2.ZERO

	var enabled_entry: GFBlackboardEntry = GFBlackboardEntry.new()
	enabled_entry.key = &"enabled"
	enabled_entry.value_type = GFBlackboardEntry.ValueType.BOOL
	enabled_entry.default_value = true

	var schema: GFBlackboardSchema = GFBlackboardSchema.new()
	schema.schema_id = &"agent"
	var entries: Array[GFBlackboardEntry] = [hp_entry, target_entry, position_entry, enabled_entry]
	schema.entries = entries
	return schema


func _has_issue(report: Dictionary, kind: String) -> bool:
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	for issue_variant: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if not issue.is_empty() and GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _color_option(options: Dictionary, key: Variant) -> Color:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT
