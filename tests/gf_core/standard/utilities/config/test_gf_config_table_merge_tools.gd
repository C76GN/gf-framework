## 测试配置表合并工具与构建 Profile。
extends GutTest


# --- 测试 ---

func test_merge_tables_updates_inserts_and_deletes_array_records() -> void:
	var base_rows: Array = [
		{ "id": 1, "stats": { "hp": 10, "mp": 5 } },
		{ "id": 2, "stats": { "hp": 20 } },
	]
	var patch_rows: Array = [
		{ "id": 1, "stats": { "hp": 15 } },
		{ "id": 3, "stats": { "hp": 30 } },
		{ "id": 2, "_delete": true },
	]

	var result: Dictionary = GFConfigTableMergeTools.merge_tables(base_rows, patch_rows)
	var merged_rows: Array = GFVariantData.get_option_array(result, "data")
	var first_row: Dictionary = GFVariantData.as_dictionary(merged_rows[0])
	var first_stats: Dictionary = GFVariantData.get_option_dictionary(first_row, "stats")
	var second_row: Dictionary = GFVariantData.as_dictionary(merged_rows[1])

	assert_true(GFVariantData.get_option_bool(result, "ok"), "合法补丁合并应成功。")
	assert_eq(GFVariantData.get_option_int(result, "updated_count"), 1, "应统计更新记录。")
	assert_eq(GFVariantData.get_option_int(result, "inserted_count"), 1, "应统计新增记录。")
	assert_eq(GFVariantData.get_option_int(result, "deleted_count"), 1, "应统计删除记录。")
	assert_eq(merged_rows.size(), 2, "删除一条并新增一条后应保留两条记录。")
	assert_eq(GFVariantData.get_option_int(first_stats, "hp"), 15, "嵌套字段应被补丁更新。")
	assert_eq(GFVariantData.get_option_int(first_stats, "mp"), 5, "未覆盖的嵌套字段应保留。")
	assert_eq(GFVariantData.get_option_int(second_row, "id"), 3, "新增记录应追加到末尾。")


func test_merge_tables_can_use_dictionary_outer_keys() -> void:
	var policy: GFConfigTableMergePolicy = GFConfigTableMergePolicy.new()
	policy.key_fields = PackedStringArray()
	var result: Dictionary = GFConfigTableMergeTools.merge_tables({
		"a": { "name": "A" },
	}, {
		"a": { "name": "AA" },
		"b": { "name": "B" },
	}, policy)
	var merged: Dictionary = GFVariantData.get_option_dictionary(result, "data")
	var row_a: Dictionary = GFVariantData.get_option_dictionary(merged, "a")
	var row_b: Dictionary = GFVariantData.get_option_dictionary(merged, "b")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "Dictionary 表应可使用外层 key 合并。")
	assert_eq(GFVariantData.get_option_string(row_a, "name"), "AA", "外层 key 相同的记录应更新。")
	assert_eq(GFVariantData.get_option_string(row_b, "name"), "B", "新外层 key 应插入。")


func test_merge_tables_reports_duplicate_base_keys() -> void:
	var result: Dictionary = GFConfigTableMergeTools.merge_tables([
		{ "id": 1, "name": "A" },
		{ "id": 1, "name": "B" },
	], [])

	assert_false(GFVariantData.get_option_bool(result, "ok"), "基础表合并键重复时应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(result, "issues"), "duplicate_base_key"), "应报告重复基础键。")


func test_build_profile_filters_schema_and_records_by_metadata() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	var id_column: GFConfigTableColumn = _make_column(&"id")
	var runtime_column: GFConfigTableColumn = _make_column(&"runtime_name")
	runtime_column.metadata = { "groups": ["runtime"] }
	var server_column: GFConfigTableColumn = _make_column(&"server_note")
	server_column.metadata = { "tags": ["server_only"] }
	schema.columns = [id_column, runtime_column, server_column]
	var runtime_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	runtime_rule.rule_id = &"runtime_rule"
	runtime_rule.metadata = { "groups": ["runtime"] }
	var server_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	server_rule.rule_id = &"server_rule"
	server_rule.metadata = { "tags": ["server_only"] }
	schema.record_validation_rules = [runtime_rule, server_rule]
	schema.table_validation_rules = [server_rule]
	var index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	index.field_names = PackedStringArray(["runtime_name"])
	index.unique = true
	schema.indexes.append(index)

	var profile: GFConfigBuildProfile = GFConfigBuildProfile.new()
	profile.default_include = false
	profile.include_groups = PackedStringArray(["runtime"])
	profile.exclude_tags = PackedStringArray(["server_only"])

	var filtered_schema: GFConfigTableSchema = profile.filter_schema(schema)
	var filtered_records: Array = profile.filter_records([
		{ "id": 1, "runtime_name": "A", "_metadata": { "groups": ["runtime"] } },
		{ "id": 2, "runtime_name": "B", "_metadata": { "tags": ["server_only"] } },
	])
	var filtered_record: Dictionary = GFVariantData.as_dictionary(filtered_records[0])

	assert_eq(filtered_schema.get_column_names(), PackedStringArray(["runtime_name"]), "Profile 应按列 metadata 裁剪 schema。")
	assert_eq(filtered_schema.indexes.size(), 1, "字段仍存在时索引应保留。")
	assert_eq(filtered_schema.record_validation_rules.size(), 1, "Profile 应按 rule metadata 裁剪记录规则。")
	assert_eq(filtered_schema.record_validation_rules[0].get_rule_id(), &"runtime_rule", "Profile 应保留命中 runtime 分组的规则。")
	assert_eq(filtered_schema.table_validation_rules.size(), 0, "Profile 应移除被排除 metadata 命中的表规则。")
	assert_eq(filtered_records.size(), 1, "Profile 应按记录 metadata 裁剪数据。")
	assert_eq(GFVariantData.get_option_int(filtered_record, "id"), 1, "只应保留命中 runtime 分组的记录。")


# --- 私有/辅助方法 ---

func _make_column(field_name: StringName) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = GFConfigTableColumn.ValueType.STRING
	return column


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false
