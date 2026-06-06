## 测试通用导表 schema、导入器与 Provider 注册能力。
extends GutTest


# --- 测试 ---

func test_schema_validate_table_reports_missing_type_and_extra_fields() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.allow_extra_fields = false

	var report: Dictionary = schema.validate_table([
		{ "id": 1, "name": "Potion", "power": 3.5 },
		{ "id": "bad", "extra": true },
	])
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "包含缺字段、类型错误和额外字段时校验应失败。")
	assert_eq(GFVariantData.get_option_int(report, "row_count"), 2, "表校验应记录行数。")
	assert_true(_has_issue_kind(issues, "invalid_type"), "错误报告应包含类型错误。")
	assert_true(_has_issue_kind(issues, "missing_required"), "错误报告应包含缺失必填字段。")
	assert_true(_has_issue_kind(issues, "extra_field"), "错误报告应包含额外字段。")


func test_schema_coerce_record_applies_column_types_and_defaults() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.coerce_values = true

	var record: Dictionary = schema.coerce_record({ "id": "7", "name": 42 })

	assert_eq(GFVariantData.get_option_int(record, "id"), 7, "id 应按列声明转换为 int。")
	assert_eq(GFVariantData.get_option_string(record, "name"), "42", "name 应按列声明转换为 String。")
	assert_eq(GFVariantData.get_option_float(record, "power"), 1.0, "缺失字段应补默认值并转换。")


func test_schema_coerce_validation_reports_invalid_conversion() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.coerce_values = true

	var report: Dictionary = schema.validate_record({ "id": "bad", "name": "Potion", "power": "abc" }, "bad")
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "严格转换失败时校验应失败。")
	assert_true(_has_issue_kind(issues, "coerce_failed"), "错误报告应包含转换失败。")


func test_schema_can_report_duplicate_array_ids() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.require_unique_id = true

	var report: Dictionary = schema.validate_table([
		{ "id": 1, "name": "Potion", "power": 1.0 },
		{ "id": 1, "name": "Ether", "power": 2.0 },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "要求唯一 ID 时重复记录应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "duplicate_id"), "错误报告应包含重复 ID。")


func test_schema_can_report_duplicate_dictionary_ids() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.require_unique_id = true

	var report: Dictionary = schema.validate_table({
		"potion": { "id": 1, "name": "Potion", "power": 1.0 },
		"ether": { "id": 1, "name": "Ether", "power": 2.0 },
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "Dictionary 表要求唯一 ID 时重复记录应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "duplicate_id"), "错误报告应包含重复 ID。")


func test_schema_definition_reports_invalid_declarations() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	var duplicate_id_column: GFConfigTableColumn = _make_column(&"id", GFConfigTableColumn.ValueType.INT)
	var empty_column: GFConfigTableColumn = GFConfigTableColumn.new()
	schema.columns.append(duplicate_id_column)
	schema.columns.append(empty_column)
	schema.columns.append(null)

	var invalid_index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	invalid_index.index_id = &"bad_index"
	invalid_index.field_names = PackedStringArray(["missing"])
	schema.indexes.append(invalid_index)

	var duplicate_index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	duplicate_index.index_id = &"bad_index"
	duplicate_index.field_names = PackedStringArray(["id"])
	schema.indexes.append(duplicate_index)

	var invalid_reference: GFConfigTableReference = GFConfigTableReference.new()
	invalid_reference.reference_id = &"bad_reference"
	invalid_reference.source_fields = PackedStringArray(["missing_ref"])
	invalid_reference.target_table_name = &"items"
	schema.references.append(invalid_reference)

	var duplicate_reference: GFConfigTableReference = GFConfigTableReference.new()
	duplicate_reference.reference_id = &"bad_reference"
	duplicate_reference.source_fields = PackedStringArray(["id"])
	duplicate_reference.target_table_name = &"items"
	schema.references.append(duplicate_reference)

	var report: Dictionary = schema.validate_definition()
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "schema 定义存在结构问题时应失败。")
	assert_true(_has_issue_kind(issues, "duplicate_column_field"), "应报告重复字段声明。")
	assert_true(_has_issue_kind(issues, "empty_field"), "应报告空字段声明。")
	assert_true(_has_issue_kind(issues, "null_column"), "应报告空列声明。")
	assert_true(_has_issue_kind(issues, "index_unknown_field"), "应报告索引未知字段。")
	assert_true(_has_issue_kind(issues, "duplicate_index_id"), "应报告重复索引 ID。")
	assert_true(_has_issue_kind(issues, "reference_unknown_source_field"), "应报告引用未知来源字段。")
	assert_true(_has_issue_kind(issues, "duplicate_reference_id"), "应报告重复引用 ID。")


func test_config_provider_registers_schema_and_validates_table() -> void:
	var provider: GFConfigProvider = GFConfigProvider.new()
	var schema: GFConfigTableSchema = _make_item_schema()

	assert_true(provider.register_schema(schema), "有效 schema 应注册成功。")
	assert_true(provider.has_schema(&"items"), "Provider 应可查询已注册 schema。")

	var report: Dictionary = provider.validate_record(&"items", { "id": 1, "name": "Potion", "power": 2.0 })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "Provider 应通过已注册 schema 校验记录。")
	assert_eq(provider.get_schema_ids(), PackedStringArray(["items"]), "schema id 应排序返回。")


func test_config_provider_get_schema_returns_copy() -> void:
	var provider: GFConfigProvider = GFConfigProvider.new()
	var schema: GFConfigTableSchema = _make_item_schema()
	assert_true(provider.register_schema(schema), "有效 schema 应注册成功。")

	var schema_copy: GFConfigTableSchema = provider.get_schema(&"items")
	schema_copy.columns.clear()

	var report: Dictionary = provider.validate_record(&"items", { "id": 1, "name": "Potion", "power": 2.0 })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "修改 get_schema 返回值不应污染 Provider 内部 schema。")


func test_csv_importer_parses_quotes_and_validates_with_coercion() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.coerce_values = true

	var parsed: Dictionary = GFConfigTableImporter.parse_csv_table("id,name,power\n1,\"A,B\",2.5\n")
	var report: Dictionary = GFConfigTableImporter.validate_csv_table("id,name,power\n1,\"A,B\",2.5\n", schema)
	var rows: Array = GFVariantData.get_option_array(parsed, "data")
	var first_row: Dictionary = GFVariantData.as_dictionary(rows[0])

	assert_true(GFVariantData.get_option_bool(parsed, "success"), "CSV 应解析成功。")
	assert_eq(GFVariantData.get_option_string(first_row, "name"), "A,B", "引号内逗号应保留为单元格内容。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "启用 coerce_values 后 CSV 字符串值应可通过 schema 校验。")


func test_csv_importer_strips_bom_from_first_header() -> void:
	var parsed: Dictionary = GFConfigTableImporter.parse_csv_table("\ufeffid,name,power\n1,Potion,2.0\n")
	var rows: Array = GFVariantData.get_option_array(parsed, "data")
	var row: Dictionary = GFVariantData.as_dictionary(rows[0])

	assert_true(GFVariantData.get_option_bool(parsed, "success"), "带 UTF-8 BOM 的 CSV 应解析成功。")
	assert_true(row.has(&"id"), "BOM 不应污染第一列表头。")


func test_csv_importer_reports_duplicate_headers() -> void:
	var parsed: Dictionary = GFConfigTableImporter.parse_csv_table("id,id\n1,2\n")

	assert_false(GFVariantData.get_option_bool(parsed, "success"), "重复表头应报告解析失败。")
	assert_true(GFVariantData.get_option_string(parsed, "error").contains("duplicate"), "错误信息应说明重复表头。")


func test_csv_importer_reports_unclosed_quote_location() -> void:
	var parsed: Dictionary = GFConfigTableImporter.parse_csv_table("id,name\n1,\"Potion\n")
	var report: Dictionary = GFConfigTableImporter.validate_csv_table("id,name\n1,\"Potion\n", _make_item_schema())
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(parsed, "success"), "未闭合引号应报告解析失败。")
	assert_eq(GFVariantData.get_option_int(parsed, "error_line"), 2, "解析结果应报告引号起始行。")
	assert_eq(GFVariantData.get_option_int(parsed, "error_column"), 3, "解析结果应报告引号起始列。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "parse_failed", "校验报告应标记解析失败。")
	assert_eq(GFVariantData.get_option_int(issue, "line"), 2, "校验报告应透出解析失败行号。")


func test_json_importer_reports_parse_failure_as_validation_report() -> void:
	var report: Dictionary = GFConfigTableImporter.validate_json_table("{bad", _make_item_schema())
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非法 JSON 应返回失败校验报告。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "parse_failed", "失败报告应标记解析错误。")


func test_json_record_importer_validates_single_dictionary_record() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.coerce_values = true

	var report: Dictionary = GFConfigTableImporter.validate_json_record(
		"{\"id\":\"9\",\"name\":\"Potion\",\"power\":\"2.5\"}",
		schema,
		null,
		{ "source": "res://configs/item.json" }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "JSON 单记录根节点为 Dictionary 时应按 schema 校验。")
	assert_eq(GFVariantData.get_option_int(report, "row_count"), 1, "单记录校验报告应记录一行。")


func test_json_record_importer_reports_non_dictionary_root_context() -> void:
	var report: Dictionary = GFConfigTableImporter.validate_json_record(
		"[1, 2]",
		_make_item_schema(),
		null,
		{ "source": "res://configs/item.json" }
	)
	var issue: Dictionary = _find_issue_kind(GFVariantData.get_option_array(report, "issues"), "invalid_json_record")
	var supported_formats: Array = GFVariantData.get_option_array(issue, "supported_formats")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "JSON 单记录不接受 Array 根节点。")
	assert_eq(GFVariantData.get_option_string(issue, "expected_value"), "Dictionary", "错误应说明期望根节点类型。")
	assert_true(supported_formats.has("JSON object"), "错误应说明支持的 JSON 形态。")


func test_csv_exporter_uses_schema_column_order_and_quotes_cells() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	var exported: Dictionary = GFConfigTableImporter.export_csv_table([
		{ "id": 1, "name": "A,B", "power": 2.0 },
	], schema)

	assert_true(GFVariantData.get_option_bool(exported, "success"), "CSV 导出应成功。")
	assert_true(GFVariantData.get_option_string(exported, "text").begins_with("id,name,power"), "schema 列顺序应作为默认导出顺序。")
	assert_true(GFVariantData.get_option_string(exported, "text").contains("\"A,B\""), "包含分隔符的单元格应加引号。")


func test_schema_infer_from_records_creates_columns() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.infer_from_records(&"items", [
		{ "id": 1, "name": "Potion", "power": 2.0 },
		{ "id": 2, "name": "Ether", "power": 3 },
	], {
		"required_if_present_in_all_rows": true,
	})

	assert_eq(schema.table_name, &"items", "推导 schema 应保留表名。")
	assert_eq(schema.get_column_names(), PackedStringArray(["id", "name", "power"]), "推导 schema 应包含记录字段。")
	assert_eq(schema.get_column(&"id").value_type, GFConfigTableColumn.ValueType.INT, "int 字段应被推导为 INT。")
	assert_eq(schema.get_column(&"power").value_type, GFConfigTableColumn.ValueType.FLOAT, "int/float 混合数字应被推导为 FLOAT。")
	assert_true(schema.get_column(&"name").required, "所有行都出现的字段可按选项标记为 required。")


func test_schema_unique_composite_index_reports_duplicates() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	var index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	index.index_id = &"name_power"
	index.field_names = PackedStringArray(["name", "power"])
	index.unique = true
	schema.indexes.append(index)

	var report: Dictionary = schema.validate_table([
		{ "id": 1, "name": "Potion", "power": 2.0 },
		{ "id": 2, "name": "Potion", "power": 2.0 },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "唯一复合索引重复时表校验应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "duplicate_index_key"), "错误报告应包含重复索引键。")


func test_reference_resolver_validates_and_resolves_cross_table_records() -> void:
	var item_schema: GFConfigTableSchema = _make_item_schema()
	var owner_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	owner_schema.table_name = &"owners"
	owner_schema.id_field = &"id"
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	id_column.required = true
	var item_id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	item_id_column.field_name = &"item_id"
	item_id_column.value_type = GFConfigTableColumn.ValueType.INT
	item_id_column.required = true
	owner_schema.columns = [id_column, item_id_column]

	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.reference_id = &"owner_item"
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	owner_schema.references.append(reference)

	var tables: Dictionary = {
		&"items": [
			{ "id": 1, "name": "Potion", "power": 2.0 },
		],
		&"owners": [
			{ "id": 10, "item_id": 1 },
		],
	}
	var report: Dictionary = GFConfigReferenceResolver.validate_tables(tables, [item_schema, owner_schema])
	var resolved: Dictionary = GFConfigReferenceResolver.resolve_record_references(
		{ "id": 10, "item_id": 1 },
		owner_schema,
		tables,
		{ &"items": item_schema }
	)
	var owner_item: Dictionary = GFVariantData.get_option_dictionary(resolved, &"owner_item")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法跨表引用应通过校验。")
	assert_eq(GFVariantData.get_option_string(owner_item, "name"), "Potion", "引用解析应返回目标记录副本。")


func test_reference_resolver_reports_missing_target_record() -> void:
	var item_schema: GFConfigTableSchema = _make_item_schema()
	var owner_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	owner_schema.table_name = &"owners"
	var item_id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	item_id_column.field_name = &"item_id"
	item_id_column.value_type = GFConfigTableColumn.ValueType.INT
	item_id_column.required = true
	owner_schema.columns = [item_id_column]
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	owner_schema.references.append(reference)

	var report: Dictionary = GFConfigReferenceResolver.validate_tables({
		&"items": [
			{ "id": 1, "name": "Potion", "power": 2.0 },
		],
		&"owners": [
			{ "item_id": 99 },
		],
	}, [item_schema, owner_schema])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失引用目标时应报告失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "missing_reference"), "错误报告应包含缺失引用。")


func test_column_validation_rules_report_common_data_errors() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	schema.columns = [
		_make_column(&"id", GFConfigTableColumn.ValueType.INT),
		_make_column(&"code", GFConfigTableColumn.ValueType.STRING),
		_make_column(&"kind", GFConfigTableColumn.ValueType.STRING),
		_make_column(&"tags", GFConfigTableColumn.ValueType.ARRAY),
		_make_column(&"icon_path", GFConfigTableColumn.ValueType.STRING),
		_make_column(&"name_key", GFConfigTableColumn.ValueType.STRING),
		_make_column(&"power", GFConfigTableColumn.ValueType.FLOAT),
	]

	var not_default: GFConfigNotDefaultValidationRule = GFConfigNotDefaultValidationRule.new()
	schema.get_column(&"id").validation_rules.append(not_default)
	var regex: GFConfigRegexValidationRule = GFConfigRegexValidationRule.new()
	regex.pattern = "^[a-z0-9_]+$"
	regex.require_full_match = true
	schema.get_column(&"code").validation_rules.append(regex)
	var kind_set: GFConfigSetValidationRule = GFConfigSetValidationRule.new()
	kind_set.allowed_values = ["weapon", "armor"]
	schema.get_column(&"kind").validation_rules.append(kind_set)
	var size: GFConfigSizeValidationRule = GFConfigSizeValidationRule.new()
	size.has_maximum_size = true
	size.maximum_size = 2
	schema.get_column(&"tags").validation_rules.append(size)
	var resource_path: GFConfigResourcePathValidationRule = GFConfigResourcePathValidationRule.new()
	resource_path.allowed_extensions = PackedStringArray(["gd"])
	schema.get_column(&"icon_path").validation_rules.append(resource_path)
	var text_key: GFConfigLocalizationKeyValidationRule = GFConfigLocalizationKeyValidationRule.new()
	text_key.known_keys = PackedStringArray(["item.name.valid"])
	text_key.use_translation_server = false
	schema.get_column(&"name_key").validation_rules.append(text_key)
	var range_rule: GFConfigRangeValidationRule = GFConfigRangeValidationRule.new()
	range_rule.has_maximum = true
	range_rule.maximum = 10.0
	schema.get_column(&"power").validation_rules.append(range_rule)

	var report: Dictionary = schema.validate_record({
		"id": 0,
		"code": "Bad Code",
		"kind": "consumable",
		"tags": ["a", "b", "c"],
		"icon_path": "res://missing_icon.png",
		"name_key": "item.name.missing",
		"power": 99.0,
	}, 0)
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "内置字段规则命中时校验应失败。")
	assert_true(_has_issue_kind(issues, "default_value_not_allowed"), "应报告默认值。")
	assert_true(_has_issue_kind(issues, "regex_mismatch"), "应报告正则不匹配。")
	assert_true(_has_issue_kind(issues, "set_value_not_allowed"), "应报告集合外取值。")
	assert_true(_has_issue_kind(issues, "size_out_of_range"), "应报告数量越界。")
	assert_true(_has_issue_kind(issues, "resource_path_extension_not_allowed"), "应报告资源扩展名不匹配。")
	assert_true(_has_issue_kind(issues, "localization_key_missing"), "应报告文本 key 缺失。")
	assert_true(_has_issue_kind(issues, "range_above_maximum"), "应报告范围越界。")


func test_regex_validation_rule_recompiles_when_pattern_changes() -> void:
	var regex: GFConfigRegexValidationRule = GFConfigRegexValidationRule.new()
	regex.require_full_match = true
	regex.pattern = "^a+$"

	var first_report: Dictionary = regex.validate_value("aaa")
	regex.pattern = "^b+$"
	var second_report: Dictionary = regex.validate_value("aaa")
	regex.pattern = "^a+$"
	var recovered_report: Dictionary = regex.validate_value("aaa")

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "初始正则应匹配。")
	assert_false(GFVariantData.get_option_bool(second_report, "ok"), "pattern 改变后应使用新正则。")
	assert_true(GFVariantData.get_option_bool(recovered_report, "ok"), "pattern 改回后应重新编译并恢复通过。")


func test_resource_and_localization_rules_accept_valid_values() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"assets"
	schema.columns = [
		_make_column(&"path", GFConfigTableColumn.ValueType.STRING),
		_make_column(&"title_key", GFConfigTableColumn.ValueType.STRING),
	]
	var resource_path: GFConfigResourcePathValidationRule = GFConfigResourcePathValidationRule.new()
	resource_path.allowed_extensions = PackedStringArray(["gd"])
	schema.get_column(&"path").validation_rules.append(resource_path)
	var text_key: GFConfigLocalizationKeyValidationRule = GFConfigLocalizationKeyValidationRule.new()
	text_key.known_keys = PackedStringArray(["ui.title"])
	text_key.use_translation_server = false
	schema.get_column(&"title_key").validation_rules.append(text_key)

	var report: Dictionary = schema.validate_record({
		"path": "res://addons/gf/standard/utilities/config/gf_config_provider.gd",
		"title_key": "ui.title",
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "存在的 Godot 资源路径和显式文本 key 应通过校验。")


func test_schema_and_rules_surface_actionable_issue_context() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	var kind_column: GFConfigTableColumn = _make_column(&"kind", GFConfigTableColumn.ValueType.STRING)
	var kind_set: GFConfigSetValidationRule = GFConfigSetValidationRule.new()
	kind_set.allowed_values = ["weapon", "armor"]
	kind_column.validation_rules.append(kind_set)
	schema.columns.append(kind_column)
	var range_rule: GFConfigRangeValidationRule = GFConfigRangeValidationRule.new()
	range_rule.has_maximum = true
	range_rule.maximum = 10.0
	schema.get_column(&"power").validation_rules.append(range_rule)

	var report: Dictionary = schema.validate_record({
		"id": "bad",
		"name": "Potion",
		"power": 99.0,
		"kind": "consumable",
	}, "bad")
	var invalid_type_issue: Dictionary = _find_issue_kind(GFVariantData.get_option_array(report, "issues"), "invalid_type")
	var set_issue: Dictionary = _find_issue_kind(GFVariantData.get_option_array(report, "issues"), "set_value_not_allowed")
	var range_issue: Dictionary = _find_issue_kind(GFVariantData.get_option_array(report, "issues"), "range_above_maximum")
	var supported_values: Array = GFVariantData.get_option_array(set_issue, "supported_values")

	assert_eq(GFVariantData.get_option_string(invalid_type_issue, "expected_value"), "int", "类型错误应说明期望类型。")
	assert_eq(GFVariantData.get_option_string(invalid_type_issue, "value"), "bad", "类型错误应保留原始值。")
	assert_true(supported_values.has("weapon"), "集合规则错误应带允许值。")
	assert_eq(GFVariantData.get_option_float(range_issue, "actual_value"), 99.0, "范围规则错误应带实际数值。")
	assert_true(GFVariantData.get_option_string(range_issue, "expected_value").contains("<= 10"), "范围规则错误应说明期望范围。")


func test_record_and_table_validation_rules_can_be_customized() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	var record_rule: RequireNamePowerPairRule = RequireNamePowerPairRule.new()
	schema.record_validation_rules.append(record_rule)
	var table_size: GFConfigSizeValidationRule = GFConfigSizeValidationRule.new()
	table_size.has_maximum_size = true
	table_size.maximum_size = 1
	schema.table_validation_rules.append(table_size)

	var report: Dictionary = schema.validate_table([
		{ "id": 1, "name": "Potion", "power": 1.0 },
		{ "id": 2, "name": "Ether" },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "记录级和表级规则应参与 schema 校验。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "name_power_pair_missing"), "应报告自定义记录规则。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "table_size_out_of_range"), "应报告表级数量规则。")


func test_csv_validation_report_keeps_source_line_and_column() -> void:
	var schema: GFConfigTableSchema = _make_item_schema()
	schema.coerce_values = true

	var report: Dictionary = GFConfigTableImporter.validate_csv_table(
		"id,name,power\nbad,Potion,1.0\n",
		schema,
		{ "source": "res://configs/items.csv" }
	)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "CSV 类型转换失败应报告错误。")
	assert_eq(GFVariantData.get_option_string(first_issue, "source"), "res://configs/items.csv", "错误应保留来源文件。")
	assert_eq(GFVariantData.get_option_int(first_issue, "line"), 2, "错误应保留 CSV 行号。")
	assert_eq(GFVariantData.get_option_int(first_issue, "column"), 1, "错误应保留 CSV 列号。")


# --- 私有/辅助方法 ---

func _make_item_schema() -> GFConfigTableSchema:
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	id_column.required = true
	id_column.allow_null = false

	var name_column: GFConfigTableColumn = GFConfigTableColumn.new()
	name_column.field_name = &"name"
	name_column.value_type = GFConfigTableColumn.ValueType.STRING
	name_column.required = true
	name_column.allow_null = false

	var power_column: GFConfigTableColumn = GFConfigTableColumn.new()
	power_column.field_name = &"power"
	power_column.value_type = GFConfigTableColumn.ValueType.FLOAT
	power_column.default_value = 1.0

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	schema.columns = [id_column, name_column, power_column]
	return schema


func _make_column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = value_type
	column.required = true
	column.allow_null = false
	return column


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _find_issue_kind(issues: Array, kind: String) -> Dictionary:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}


# --- 内部类 ---

class RequireNamePowerPairRule:
	extends GFConfigValidationRule

	func _get_default_rule_id() -> StringName:
		return &"name_power_pair"

	func _validate_record(record: Dictionary, context: Dictionary, report: Dictionary) -> void:
		if record.has(&"name") and not record.has(&"power"):
			_add_issue(report, context, "name_power_pair_missing", "包含 name 时必须同时包含 power。")
