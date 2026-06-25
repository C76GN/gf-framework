extends GutTest


# --- 测试用例 ---

func test_build_column_descriptors_exposes_metadata_and_references() -> void:
	var id_column: GFConfigTableColumn = _make_column(&"id", GFConfigTableColumn.ValueType.INT)
	var name_column: GFConfigTableColumn = _make_column(&"name", GFConfigTableColumn.ValueType.STRING)
	name_column.metadata = {
		"editor_label": "Display Name",
		"editable": false,
		"choices": ["Potion", "Ether"],
		"hint": "Shown in generic editors.",
	}
	var item_id_column: GFConfigTableColumn = _make_column(&"item_id", GFConfigTableColumn.ValueType.INT)
	var reference: GFConfigTableReference = _make_item_reference()

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"owners"
	schema.columns = [id_column, name_column, item_id_column]
	schema.references = [reference]

	var descriptors: Array[Dictionary] = GFConfigTableEditorTools.build_column_descriptors(schema)
	var name_descriptor: Dictionary = _find_descriptor(descriptors, &"name")
	var item_descriptor: Dictionary = _find_descriptor(descriptors, &"item_id")
	var choices: Array = GFVariantData.get_option_array(name_descriptor, "choices")
	var reference_ids: PackedStringArray = PackedStringArray()
	var reference_ids_value: Variant = GFVariantData.get_option_value(item_descriptor, "reference_ids", PackedStringArray())
	if reference_ids_value is PackedStringArray:
		var packed_reference_ids: PackedStringArray = reference_ids_value
		reference_ids = packed_reference_ids

	assert_eq(descriptors.size(), 3, "应为 schema 中每个字段生成描述。")
	assert_eq(GFVariantData.get_option_string(name_descriptor, "label"), "Display Name", "editor_label 应优先作为显示标签。")
	assert_false(GFVariantData.get_option_bool(name_descriptor, "editable", true), "metadata.editable 应控制编辑描述。")
	assert_eq(choices.size(), 2, "metadata.choices 应复制到列描述。")
	assert_eq(GFVariantData.get_option_string(name_descriptor, "hint"), "Shown in generic editors.", "hint 应进入列描述。")
	assert_true(reference_ids.has("owner_item"), "引用字段描述应包含 reference_id。")


func test_build_reference_choice_records_for_database_uses_reference_key_and_label_fields() -> void:
	var item_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	item_schema.table_name = &"items"
	item_schema.id_field = &"id"
	item_schema.columns = [
		_make_column(&"id", GFConfigTableColumn.ValueType.INT),
		_make_column(&"name", GFConfigTableColumn.ValueType.STRING),
	]

	var item_table: GFConfigTableResource = GFConfigTableResource.new()
	item_table.table_name = &"items"
	item_table.schema = item_schema
	item_table.records = [
		{ &"id": 1, &"name": "Potion" },
		{ &"id": 2, &"name": "Ether" },
	]

	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	var _registered: bool = database.register_table(item_table)
	var reference: GFConfigTableReference = _make_item_reference()
	reference.metadata = {
		"label_fields": ["name"],
	}

	var choices: Array[Dictionary] = GFConfigTableEditorTools.build_reference_choice_records_for_database(database, reference, {
		"include_record": true,
	})
	var first_choice: Dictionary = choices[0] if not choices.is_empty() else {}
	var first_record: Dictionary = GFVariantData.get_option_dictionary(first_choice, "record")

	assert_eq(choices.size(), 2, "应为目标表记录生成候选项。")
	assert_eq(GFVariantData.get_option_string(first_choice, "label"), "Potion", "label_fields 应用于候选显示文本。")
	assert_eq(GFVariantData.get_option_int(first_choice, "value"), 1, "单目标字段应直接作为候选 value。")
	assert_eq(GFVariantData.get_option_int(first_choice, "record_id"), 1, "record_id 应来自目标 schema id_field。")
	assert_eq(GFVariantData.get_option_string(first_record, &"name"), "Potion", "include_record 时应附带记录副本。")


func test_build_field_editor_descriptors_derives_property_info_and_constraints() -> void:
	var kind_column: GFConfigTableColumn = _make_column(&"kind", GFConfigTableColumn.ValueType.STRING)
	var kind_set: GFConfigSetValidationRule = GFConfigSetValidationRule.new()
	kind_set.allowed_values = ["weapon", "armor"]
	kind_column.validation_rules.append(kind_set)

	var power_column: GFConfigTableColumn = _make_column(&"power", GFConfigTableColumn.ValueType.INT)
	var power_range: GFConfigRangeValidationRule = GFConfigRangeValidationRule.new()
	power_range.has_minimum = true
	power_range.minimum = 0.0
	power_range.has_maximum = true
	power_range.maximum = 10.0
	power_column.validation_rules.append(power_range)

	var icon_column: GFConfigTableColumn = _make_column(&"icon_path", GFConfigTableColumn.ValueType.STRING)
	var resource_path: GFConfigResourcePathValidationRule = GFConfigResourcePathValidationRule.new()
	resource_path.allowed_extensions = PackedStringArray(["png", "svg"])
	icon_column.validation_rules.append(resource_path)

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns = [kind_column, power_column, icon_column]

	var descriptors: Array[Dictionary] = GFConfigTableEditorTools.build_field_editor_descriptors(schema)
	var kind_descriptor: Dictionary = _find_descriptor(descriptors, &"kind")
	var power_descriptor: Dictionary = _find_descriptor(descriptors, &"power")
	var icon_descriptor: Dictionary = _find_descriptor(descriptors, &"icon_path")
	var power_constraints: Dictionary = GFVariantData.get_option_dictionary(power_descriptor, "constraints")
	var power_range_constraint: Dictionary = GFVariantData.get_option_dictionary(power_constraints, "range")
	var icon_constraints: Dictionary = GFVariantData.get_option_dictionary(icon_descriptor, "constraints")
	var icon_resource_constraint: Dictionary = GFVariantData.get_option_dictionary(icon_constraints, "resource_path")
	var icon_extensions: Variant = GFVariantData.get_option_value(icon_resource_constraint, "allowed_extensions")
	var icon_property_info: Dictionary = GFVariantData.get_option_dictionary(icon_descriptor, "property_info")

	assert_eq(GFVariantData.get_option_string_name(kind_descriptor, "editor_kind"), &"choice", "集合规则应推导为候选输入。")
	assert_eq(GFVariantData.get_option_int(kind_descriptor, "property_hint"), PROPERTY_HINT_ENUM, "简单候选值应生成 enum hint。")
	assert_eq(GFVariantData.get_option_string(kind_descriptor, "property_hint_string"), "weapon,armor", "候选 hint 字符串应来自允许值。")
	assert_eq(GFVariantData.get_option_string_name(power_descriptor, "editor_kind"), &"integer", "int 字段应保持整数编辑类型。")
	assert_eq(GFVariantData.get_option_int(power_descriptor, "property_type"), TYPE_INT, "int 字段应映射 Godot int 属性类型。")
	assert_eq(GFVariantData.get_option_int(power_descriptor, "property_hint"), PROPERTY_HINT_RANGE, "闭区间范围应生成 range hint。")
	assert_eq(GFVariantData.get_option_float(power_range_constraint, "maximum"), 10.0, "范围约束应保留最大值。")
	assert_eq(GFVariantData.get_option_string_name(icon_descriptor, "editor_kind"), &"resource_path", "资源路径规则应推导为资源路径编辑类型。")
	assert_eq(GFVariantData.get_option_int(icon_property_info, "hint"), PROPERTY_HINT_FILE, "资源路径字段应输出文件选择 hint。")
	assert_true(icon_extensions is PackedStringArray, "资源路径约束应保留扩展名列表。")
	if icon_extensions is PackedStringArray:
		var packed_extensions: PackedStringArray = icon_extensions
		assert_true(packed_extensions.has("png"), "资源路径约束应包含 png 扩展名。")


func test_build_field_editor_descriptors_honors_metadata_property_overrides() -> void:
	var value_column: GFConfigTableColumn = _make_column(&"value", GFConfigTableColumn.ValueType.ANY)
	value_column.metadata = {
		"editor_kind": "scene_path",
		"property_type": TYPE_STRING,
		"property_hint": PROPERTY_HINT_FILE,
		"property_hint_string": "*.tscn",
	}
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.columns = [value_column]

	var descriptors: Array[Dictionary] = GFConfigTableEditorTools.build_field_editor_descriptors(schema)
	var descriptor: Dictionary = _find_descriptor(descriptors, &"value")
	var property_info: Dictionary = GFVariantData.get_option_dictionary(descriptor, "property_info")

	assert_eq(GFVariantData.get_option_string_name(descriptor, "editor_kind"), &"scene_path", "metadata.editor_kind 应覆盖推导结果。")
	assert_eq(GFVariantData.get_option_int(descriptor, "property_type"), TYPE_STRING, "metadata.property_type 应覆盖属性类型。")
	assert_eq(GFVariantData.get_option_int(property_info, "hint"), PROPERTY_HINT_FILE, "metadata.property_hint 应进入 property_info。")
	assert_eq(GFVariantData.get_option_string(property_info, "hint_string"), "*.tscn", "metadata.property_hint_string 应进入 property_info。")


func test_build_field_editor_descriptors_embeds_reference_choices_when_database_is_provided() -> void:
	var item_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	item_schema.table_name = &"items"
	item_schema.id_field = &"id"
	item_schema.columns = [
		_make_column(&"id", GFConfigTableColumn.ValueType.INT),
		_make_column(&"name", GFConfigTableColumn.ValueType.STRING),
	]

	var item_table: GFConfigTableResource = GFConfigTableResource.new()
	item_table.table_name = &"items"
	item_table.schema = item_schema
	item_table.records = [
		{ &"id": 1, &"name": "Potion" },
		{ &"id": 2, &"name": "Ether" },
	]

	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	var _registered: bool = database.register_table(item_table)
	var reference: GFConfigTableReference = _make_item_reference()
	reference.metadata = {
		"label_fields": ["name"],
	}
	var source_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	source_schema.table_name = &"owners"
	source_schema.columns = [
		_make_column(&"item_id", GFConfigTableColumn.ValueType.INT),
	]
	source_schema.references = [reference]

	var descriptors: Array[Dictionary] = GFConfigTableEditorTools.build_field_editor_descriptors(source_schema, database)
	var item_descriptor: Dictionary = _find_descriptor(descriptors, &"item_id")
	var references: Array = GFVariantData.get_option_array(item_descriptor, "references")
	var reference_descriptor: Dictionary = {}
	if not references.is_empty():
		var reference_descriptor_value: Variant = references[0]
		if reference_descriptor_value is Dictionary:
			reference_descriptor = reference_descriptor_value
	var choices: Array = GFVariantData.get_option_array(reference_descriptor, "choices")
	var first_choice: Dictionary = {}
	if not choices.is_empty():
		var first_choice_value: Variant = choices[0]
		if first_choice_value is Dictionary:
			first_choice = first_choice_value

	assert_eq(GFVariantData.get_option_string_name(item_descriptor, "editor_kind"), &"reference", "引用字段应推导为 reference 编辑类型。")
	assert_eq(references.size(), 1, "引用字段应附带引用描述。")
	assert_eq(choices.size(), 2, "提供 database 时应附带引用候选记录。")
	assert_eq(GFVariantData.get_option_string(first_choice, "label"), "Potion", "引用候选应复用 label_fields。")


# --- 私有/辅助方法 ---

func _make_column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = value_type
	column.required = true
	column.allow_null = false
	return column


func _make_item_reference() -> GFConfigTableReference:
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.reference_id = &"owner_item"
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	reference.required = true
	return reference


func _find_descriptor(descriptors: Array[Dictionary], field_name: StringName) -> Dictionary:
	for descriptor: Dictionary in descriptors:
		if GFVariantData.get_option_string_name(descriptor, "field_name") == field_name:
			return descriptor
	return {}
