## GFConfigTableEditorTools: 配置表 schema 的编辑器描述辅助。
##
## 该工具只把 `GFConfigTableSchema`、列声明和跨表引用转换为通用描述字典，
## 供 Inspector、表格编辑器、CI 预览或项目侧工具自由消费；不会创建 UI 控件，
## 也不规定具体业务字段语义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
class_name GFConfigTableEditorTools
extends RefCounted


# --- 常量 ---

## 列 metadata 中的通用显示标签键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_LABEL_KEY: StringName = &"label"

## 列 metadata 中的编辑器显示标签键，优先级高于 label。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_EDITOR_LABEL_KEY: StringName = &"editor_label"

## 列 metadata 中的可编辑状态键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_EDITABLE_KEY: StringName = &"editable"

## 列 metadata 中的通用候选值键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_CHOICES_KEY: StringName = &"choices"

## 列 metadata 中的通用提示文本键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_HINT_KEY: StringName = &"hint"

## 引用或 schema metadata 中声明选项显示字段的键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_LABEL_FIELDS_KEY: StringName = &"label_fields"

## 列 metadata 中的编辑器类型覆盖键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_EDITOR_KIND_KEY: StringName = &"editor_kind"

## 列 metadata 中的 Godot 属性类型覆盖键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_PROPERTY_TYPE_KEY: StringName = &"property_type"

## 列 metadata 中的 Godot PropertyHint 覆盖键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_PROPERTY_HINT_KEY: StringName = &"property_hint"

## 列 metadata 中的 Godot PropertyHint 字符串覆盖键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_PROPERTY_HINT_STRING_KEY: StringName = &"property_hint_string"

## 列 metadata 中的资源类型提示键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_RESOURCE_TYPE_KEY: StringName = &"resource_type"

## 列 metadata 中的资源扩展名提示键。
## [br]
## @api public
## [br]
## @since 6.0.0
const METADATA_RESOURCE_EXTENSIONS_KEY: StringName = &"resource_extensions"


# --- 公共方法 ---

## 根据配置表 schema 构建通用列描述。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param schema: 配置表 schema。
## [br]
## @param options: 描述选项，支持 editable_by_default 和 include_references。
## [br]
## @schema options: Dictionary，可包含 editable_by_default 和 include_references 布尔值。
## [br]
## @return: 列描述列表。
## [br]
## @schema return: Array[Dictionary]，每项包含 field_name、label、value_type、required、allow_null、default_value、editable、choices、reference_ids、hint 和 metadata。
static func build_column_descriptors(
	schema: GFConfigTableSchema,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if schema == null:
		return descriptors

	var editable_by_default: bool = GFVariantData.get_option_bool(options, "editable_by_default", true)
	var include_references: bool = GFVariantData.get_option_bool(options, "include_references", true)
	for column: GFConfigTableColumn in schema.columns:
		if column == null:
			continue
		descriptors.append(_build_column_descriptor(schema, column, editable_by_default, include_references))
	return descriptors


## 根据配置表 schema 构建通用字段编辑描述。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param schema: 配置表 schema。
## [br]
## @param database: 可选配置数据库；提供后可为跨表引用字段附带候选记录。
## [br]
## @param options: 描述选项，支持 editable_by_default、include_references、include_reference_choices、label_fields 和 include_record。
## [br]
## @schema options: Dictionary，可包含 editable_by_default、include_references、include_reference_choices、label_fields 和 include_record。
## [br]
## @return: 字段编辑描述列表。
## [br]
## @schema return: Array[Dictionary]，每项包含列描述字段，并额外包含 editor_kind、value_type_name、property_type、property_hint、property_hint_string、property_info、constraints、validation_rules 和 references。
static func build_field_editor_descriptors(
	schema: GFConfigTableSchema,
	database: GFConfigDatabaseResource = null,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if schema == null:
		return descriptors

	var editable_by_default: bool = GFVariantData.get_option_bool(options, "editable_by_default", true)
	var include_references: bool = GFVariantData.get_option_bool(options, "include_references", true)
	var include_reference_choices: bool = GFVariantData.get_option_bool(options, "include_reference_choices", database != null)
	for column: GFConfigTableColumn in schema.columns:
		if column == null:
			continue
		var descriptor: Dictionary = _build_column_descriptor(schema, column, editable_by_default, include_references)
		_apply_field_editor_descriptor(
			descriptor,
			schema,
			column,
			database,
			include_reference_choices,
			options
		)
		descriptors.append(descriptor)
	return descriptors


## 根据跨表引用和目标表数据构建通用候选记录。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param reference_definition: 跨表引用声明。
## [br]
## @param target_table: 目标表数据，可为 GFConfigTableResource、Array[Dictionary] 或 Dictionary 形式表。
## [br]
## @schema target_table: Variant，支持 GFConfigTableResource、Array[Dictionary] 或键到记录 Dictionary 的 Dictionary。
## [br]
## @param target_schema: 可选目标 schema；为空且 target_table 为 GFConfigTableResource 时使用其 schema。
## [br]
## @param options: 候选记录选项，支持 label_fields 和 include_record。
## [br]
## @schema options: Dictionary，可包含 label_fields 与 include_record。
## [br]
## @return: 候选记录列表。
## [br]
## @schema return: Array[Dictionary]，每项包含 key、label、value、record_id、target_fields，并可按 include_record 包含 record。
static func build_reference_choice_records(
	reference_definition: GFConfigTableReference,
	target_table: Variant,
	target_schema: GFConfigTableSchema = null,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if reference_definition == null:
		return choices

	var resolved_schema: GFConfigTableSchema = target_schema
	if resolved_schema == null and target_table is GFConfigTableResource:
		var table_resource: GFConfigTableResource = target_table
		resolved_schema = table_resource.schema

	var target_fields: PackedStringArray = reference_definition.get_target_fields(resolved_schema)
	if target_fields.is_empty():
		return choices

	var label_fields: PackedStringArray = _resolve_label_fields(reference_definition, resolved_schema, options)
	var include_record: bool = GFVariantData.get_option_bool(options, "include_record", false)
	var records: Array[Dictionary] = _normalize_records(target_table)
	for record: Dictionary in records:
		var reference_key: String = reference_definition.make_target_key(record, resolved_schema)
		if reference_key.is_empty():
			continue
		var choice: Dictionary = {
			"key": reference_key,
			"label": _make_choice_label(record, label_fields, target_fields, reference_key),
			"value": GFVariantData.duplicate_variant(_make_choice_value(record, target_fields)),
			"record_id": GFVariantData.duplicate_variant(_get_record_id(record, resolved_schema, target_fields, reference_key)),
			"target_fields": target_fields.duplicate(),
		}
		if include_record:
			choice["record"] = record.duplicate(true)
		choices.append(choice)
	return choices


## 根据数据库资源中的目标表构建跨表引用候选记录。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param database: 配置数据库资源。
## [br]
## @param reference_definition: 跨表引用声明。
## [br]
## @param options: 候选记录选项，支持 label_fields 和 include_record。
## [br]
## @schema options: Dictionary，可包含 label_fields 与 include_record。
## [br]
## @return: 候选记录列表。
## [br]
## @schema return: Array[Dictionary]，每项包含 key、label、value、record_id、target_fields，并可按 include_record 包含 record。
static func build_reference_choice_records_for_database(
	database: GFConfigDatabaseResource,
	reference_definition: GFConfigTableReference,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if database == null or reference_definition == null:
		return choices
	var table_resource: GFConfigTableResource = database.get_table_resource(reference_definition.target_table_name, false)
	if table_resource == null:
		return choices
	return build_reference_choice_records(reference_definition, table_resource, table_resource.schema, options)


# --- 私有/辅助方法 ---

static func _build_column_descriptor(
	schema: GFConfigTableSchema,
	column: GFConfigTableColumn,
	editable_by_default: bool,
	include_references: bool
) -> Dictionary:
	var field_name: StringName = column.get_field_key()
	var metadata: Dictionary = column.metadata.duplicate(true)
	return {
		"field_name": field_name,
		"label": _resolve_column_label(field_name, metadata),
		"value_type": column.value_type,
		"required": column.required,
		"allow_null": column.allow_null,
		"default_value": GFVariantData.duplicate_variant(column.default_value),
		"editable": _get_metadata_bool(metadata, METADATA_EDITABLE_KEY, editable_by_default),
		"choices": _get_metadata_array(metadata, METADATA_CHOICES_KEY).duplicate(true),
		"reference_ids": _collect_field_reference_ids(schema, field_name) if include_references else PackedStringArray(),
		"hint": GFVariantData.to_text(_get_metadata_value(metadata, METADATA_HINT_KEY, "")),
		"metadata": metadata,
	}


static func _apply_field_editor_descriptor(
	descriptor: Dictionary,
	schema: GFConfigTableSchema,
	column: GFConfigTableColumn,
	database: GFConfigDatabaseResource,
	include_reference_choices: bool,
	options: Dictionary
) -> void:
	var metadata: Dictionary = GFVariantData.get_option_dictionary(descriptor, "metadata")
	var field_name: StringName = column.get_field_key()
	var choices: Array = _resolve_field_choices(column, descriptor)
	var constraints: Dictionary = _build_field_constraints(column, metadata)
	var references: Array[Dictionary] = _build_field_reference_descriptors(
		schema,
		field_name,
		database,
		include_reference_choices,
		options
	)
	var editor_kind: StringName = _resolve_editor_kind(column, metadata, choices, references, constraints)
	var property_type: int = _resolve_property_type(column, metadata)
	var property_hint: int = _resolve_property_hint(metadata, choices, constraints, editor_kind, column.value_type)
	var property_hint_string: String = _resolve_property_hint_string(
		metadata,
		choices,
		constraints,
		editor_kind,
		column.value_type
	)

	descriptor["choices"] = choices
	descriptor["editor_kind"] = editor_kind
	descriptor["value_type_name"] = _value_type_to_name(column.value_type)
	descriptor["property_type"] = property_type
	descriptor["property_hint"] = property_hint
	descriptor["property_hint_string"] = property_hint_string
	descriptor["property_info"] = _make_property_info(field_name, property_type, property_hint, property_hint_string)
	descriptor["constraints"] = constraints
	descriptor["validation_rules"] = _describe_validation_rules(column)
	descriptor["references"] = references


static func _resolve_column_label(field_name: StringName, metadata: Dictionary) -> String:
	var editor_label: String = GFVariantData.to_text(_get_metadata_value(metadata, METADATA_EDITOR_LABEL_KEY, ""))
	if not editor_label.is_empty():
		return editor_label
	var label: String = GFVariantData.to_text(_get_metadata_value(metadata, METADATA_LABEL_KEY, ""))
	if not label.is_empty():
		return label
	return String(field_name)


static func _collect_field_reference_ids(
	schema: GFConfigTableSchema,
	field_name: StringName
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var field_text: String = String(field_name)
	for reference_definition: GFConfigTableReference in schema.references:
		if reference_definition == null:
			continue
		if reference_definition.source_fields.has(field_text):
			var _appended: bool = result.append(String(reference_definition.get_reference_id()))
	result.sort()
	return result


static func _resolve_field_choices(column: GFConfigTableColumn, descriptor: Dictionary) -> Array:
	var metadata_choices: Array = GFVariantData.get_option_array(descriptor, "choices")
	if not metadata_choices.is_empty():
		return metadata_choices.duplicate(true)

	for rule: GFConfigValidationRule in column.validation_rules:
		if rule == null or not rule.enabled:
			continue
		if rule is GFConfigSetValidationRule:
			var set_rule: GFConfigSetValidationRule = rule
			if not set_rule.allowed_values.is_empty():
				return GFVariantData.to_array(set_rule.allowed_values)
	return []


static func _build_field_constraints(column: GFConfigTableColumn, metadata: Dictionary) -> Dictionary:
	var constraints: Dictionary = {}
	for rule: GFConfigValidationRule in column.validation_rules:
		if rule == null or not rule.enabled:
			continue
		_apply_rule_constraints(constraints, rule)
	_apply_metadata_constraints(constraints, metadata)
	return constraints


static func _apply_rule_constraints(constraints: Dictionary, rule: GFConfigValidationRule) -> void:
	if rule is GFConfigRangeValidationRule:
		var range_rule: GFConfigRangeValidationRule = rule
		var range_constraint: Dictionary = {}
		if range_rule.has_minimum:
			range_constraint["minimum"] = range_rule.minimum
			range_constraint["inclusive_minimum"] = range_rule.inclusive_minimum
		if range_rule.has_maximum:
			range_constraint["maximum"] = range_rule.maximum
			range_constraint["inclusive_maximum"] = range_rule.inclusive_maximum
		if not range_constraint.is_empty():
			constraints["range"] = range_constraint
		return

	if rule is GFConfigSetValidationRule:
		var set_rule: GFConfigSetValidationRule = rule
		constraints["set"] = {
			"allowed_values": GFVariantData.duplicate_variant(set_rule.allowed_values),
			"case_sensitive": set_rule.case_sensitive,
		}
		return

	if rule is GFConfigSizeValidationRule:
		var size_rule: GFConfigSizeValidationRule = rule
		var size_constraint: Dictionary = {}
		if size_rule.has_minimum_size:
			size_constraint["minimum_size"] = size_rule.minimum_size
		if size_rule.has_maximum_size:
			size_constraint["maximum_size"] = size_rule.maximum_size
		if not size_constraint.is_empty():
			constraints["size"] = size_constraint
		return

	if rule is GFConfigRegexValidationRule:
		var regex_rule: GFConfigRegexValidationRule = rule
		var patterns: Array = GFVariantData.get_option_array(constraints, "patterns")
		patterns.append({
			"pattern": regex_rule.pattern,
			"require_full_match": regex_rule.require_full_match,
			"allow_empty": regex_rule.allow_empty,
		})
		constraints["patterns"] = patterns
		return

	if rule is GFConfigResourcePathValidationRule:
		var resource_rule: GFConfigResourcePathValidationRule = rule
		constraints["resource_path"] = {
			"allow_empty": resource_rule.allow_empty,
			"require_resource_prefix": resource_rule.require_resource_prefix,
			"allow_uid_paths": resource_rule.allow_uid_paths,
			"allowed_extensions": resource_rule.allowed_extensions.duplicate(),
		}
		return

	if rule is GFConfigLocalizationKeyValidationRule:
		var localization_rule: GFConfigLocalizationKeyValidationRule = rule
		constraints["localization_key"] = {
			"allow_empty": localization_rule.allow_empty,
			"known_keys": localization_rule.known_keys.duplicate(),
			"use_translation_server": localization_rule.use_translation_server,
		}


static func _apply_metadata_constraints(constraints: Dictionary, metadata: Dictionary) -> void:
	var resource_type: String = GFVariantData.to_text(_get_metadata_value(metadata, METADATA_RESOURCE_TYPE_KEY, ""))
	var resource_extensions: PackedStringArray = _to_packed_string_array(_get_metadata_value(metadata, METADATA_RESOURCE_EXTENSIONS_KEY, []))
	if resource_type.is_empty() and resource_extensions.is_empty():
		return

	var resource_constraint: Dictionary = GFVariantData.get_option_dictionary(constraints, "resource_path")
	if not resource_type.is_empty():
		resource_constraint["resource_type"] = resource_type
	if not resource_extensions.is_empty():
		resource_constraint["allowed_extensions"] = resource_extensions
	constraints["resource_path"] = resource_constraint


static func _build_field_reference_descriptors(
	schema: GFConfigTableSchema,
	field_name: StringName,
	database: GFConfigDatabaseResource,
	include_choices: bool,
	options: Dictionary
) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	var field_text: String = String(field_name)
	for reference_definition: GFConfigTableReference in schema.references:
		if reference_definition == null or not reference_definition.source_fields.has(field_text):
			continue

		var target_schema: GFConfigTableSchema = _get_reference_target_schema(database, reference_definition)
		var reference_descriptor: Dictionary = {
			"reference_id": reference_definition.get_reference_id(),
			"source_fields": reference_definition.source_fields.duplicate(),
			"target_table_name": reference_definition.target_table_name,
			"target_fields": reference_definition.get_target_fields(target_schema),
			"required": reference_definition.required,
			"allow_null_values": reference_definition.allow_null_values,
			"metadata": reference_definition.metadata.duplicate(true),
		}
		if include_choices:
			reference_descriptor["choices"] = (
				build_reference_choice_records_for_database(database, reference_definition, options)
				if database != null
				else []
			)
		descriptors.append(reference_descriptor)
	return descriptors


static func _get_reference_target_schema(
	database: GFConfigDatabaseResource,
	reference_definition: GFConfigTableReference
) -> GFConfigTableSchema:
	if database == null or reference_definition == null:
		return null
	var table_resource: GFConfigTableResource = database.get_table_resource(reference_definition.target_table_name, false)
	if table_resource == null:
		return null
	return table_resource.schema


static func _resolve_editor_kind(
	column: GFConfigTableColumn,
	metadata: Dictionary,
	choices: Array,
	references: Array[Dictionary],
	constraints: Dictionary
) -> StringName:
	var metadata_kind: StringName = GFVariantData.to_string_name(_get_metadata_value(metadata, METADATA_EDITOR_KIND_KEY, &""))
	if metadata_kind != &"":
		return metadata_kind
	if not references.is_empty():
		return &"reference"
	if not choices.is_empty():
		return &"choice"
	if constraints.has("resource_path"):
		return &"resource_path_array" if column.value_type == GFConfigTableColumn.ValueType.ARRAY else &"resource_path"
	if constraints.has("localization_key"):
		return &"localization_key"

	match column.value_type:
		GFConfigTableColumn.ValueType.BOOL:
			return &"boolean"
		GFConfigTableColumn.ValueType.INT:
			return &"integer"
		GFConfigTableColumn.ValueType.FLOAT:
			return &"float"
		GFConfigTableColumn.ValueType.STRING:
			return &"text"
		GFConfigTableColumn.ValueType.STRING_NAME:
			return &"string_name"
		GFConfigTableColumn.ValueType.VECTOR2:
			return &"vector2"
		GFConfigTableColumn.ValueType.VECTOR2I:
			return &"vector2i"
		GFConfigTableColumn.ValueType.COLOR:
			return &"color"
		GFConfigTableColumn.ValueType.DICTIONARY:
			return &"dictionary"
		GFConfigTableColumn.ValueType.ARRAY:
			return &"array"
		_:
			return &"variant"


static func _resolve_property_type(column: GFConfigTableColumn, metadata: Dictionary) -> int:
	if _metadata_has_key(metadata, METADATA_PROPERTY_TYPE_KEY):
		return GFVariantData.to_int(_get_metadata_value(metadata, METADATA_PROPERTY_TYPE_KEY, TYPE_NIL), TYPE_NIL)
	return _value_type_to_property_type(column.value_type)


static func _resolve_property_hint(
	metadata: Dictionary,
	choices: Array,
	constraints: Dictionary,
	editor_kind: StringName,
	value_type: GFConfigTableColumn.ValueType
) -> int:
	if _metadata_has_key(metadata, METADATA_PROPERTY_HINT_KEY):
		return GFVariantData.to_int(_get_metadata_value(metadata, METADATA_PROPERTY_HINT_KEY, PROPERTY_HINT_NONE), PROPERTY_HINT_NONE)
	if not choices.is_empty() and not _make_choice_hint_string(choices).is_empty():
		return PROPERTY_HINT_ENUM
	if editor_kind == &"resource_path":
		return PROPERTY_HINT_FILE
	if not _make_range_hint_string(constraints, value_type).is_empty():
		return PROPERTY_HINT_RANGE
	return PROPERTY_HINT_NONE


static func _resolve_property_hint_string(
	metadata: Dictionary,
	choices: Array,
	constraints: Dictionary,
	editor_kind: StringName,
	value_type: GFConfigTableColumn.ValueType
) -> String:
	if _metadata_has_key(metadata, METADATA_PROPERTY_HINT_STRING_KEY):
		return GFVariantData.to_text(_get_metadata_value(metadata, METADATA_PROPERTY_HINT_STRING_KEY, ""))
	if not choices.is_empty():
		return _make_choice_hint_string(choices)
	if editor_kind == &"resource_path" or editor_kind == &"resource_path_array":
		return _make_resource_path_hint_string(constraints)
	return _make_range_hint_string(constraints, value_type)


static func _make_property_info(
	field_name: StringName,
	property_type: int,
	property_hint: int,
	property_hint_string: String
) -> Dictionary:
	return {
		"name": field_name,
		"type": property_type,
		"hint": property_hint,
		"hint_string": property_hint_string,
		"usage": PROPERTY_USAGE_DEFAULT,
	}


static func _value_type_to_property_type(value_type: GFConfigTableColumn.ValueType) -> int:
	match value_type:
		GFConfigTableColumn.ValueType.BOOL:
			return TYPE_BOOL
		GFConfigTableColumn.ValueType.INT:
			return TYPE_INT
		GFConfigTableColumn.ValueType.FLOAT:
			return TYPE_FLOAT
		GFConfigTableColumn.ValueType.STRING:
			return TYPE_STRING
		GFConfigTableColumn.ValueType.STRING_NAME:
			return TYPE_STRING_NAME
		GFConfigTableColumn.ValueType.VECTOR2:
			return TYPE_VECTOR2
		GFConfigTableColumn.ValueType.VECTOR2I:
			return TYPE_VECTOR2I
		GFConfigTableColumn.ValueType.COLOR:
			return TYPE_COLOR
		GFConfigTableColumn.ValueType.DICTIONARY:
			return TYPE_DICTIONARY
		GFConfigTableColumn.ValueType.ARRAY:
			return TYPE_ARRAY
		_:
			return TYPE_NIL


static func _value_type_to_name(value_type: GFConfigTableColumn.ValueType) -> String:
	match value_type:
		GFConfigTableColumn.ValueType.BOOL:
			return "bool"
		GFConfigTableColumn.ValueType.INT:
			return "int"
		GFConfigTableColumn.ValueType.FLOAT:
			return "float"
		GFConfigTableColumn.ValueType.STRING:
			return "String"
		GFConfigTableColumn.ValueType.STRING_NAME:
			return "StringName"
		GFConfigTableColumn.ValueType.VECTOR2:
			return "Vector2"
		GFConfigTableColumn.ValueType.VECTOR2I:
			return "Vector2i"
		GFConfigTableColumn.ValueType.COLOR:
			return "Color"
		GFConfigTableColumn.ValueType.DICTIONARY:
			return "Dictionary"
		GFConfigTableColumn.ValueType.ARRAY:
			return "Array"
		_:
			return "Variant"


static func _make_choice_hint_string(choices: Array) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for choice: Variant in choices:
		var label: String = _choice_to_label(choice)
		if label.is_empty() or label.contains(","):
			return ""
		var _label_appended: bool = labels.append(label)
	return ",".join(labels)


static func _choice_to_label(choice: Variant) -> String:
	if choice is Dictionary:
		var choice_dictionary: Dictionary = choice
		var label: String = GFVariantData.get_option_string(choice_dictionary, "label")
		if not label.is_empty():
			return label
		return GFVariantData.to_text(GFVariantData.get_option_value(choice_dictionary, "value"))
	return GFVariantData.to_text(choice)


static func _make_resource_path_hint_string(constraints: Dictionary) -> String:
	var resource_constraint: Dictionary = GFVariantData.get_option_dictionary(constraints, "resource_path")
	var extensions: PackedStringArray = _to_packed_string_array(GFVariantData.get_option_value(resource_constraint, "allowed_extensions", []))
	if extensions.is_empty():
		return ""

	var filters: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var normalized: String = extension.strip_edges().trim_prefix(".").to_lower()
		if normalized.is_empty():
			continue
		var _filter_appended: bool = filters.append("*.%s" % normalized)
	return ",".join(filters)


static func _make_range_hint_string(
	constraints: Dictionary,
	value_type: GFConfigTableColumn.ValueType
) -> String:
	var range_constraint: Dictionary = GFVariantData.get_option_dictionary(constraints, "range")
	if not _dictionary_has_key(range_constraint, "minimum") or not _dictionary_has_key(range_constraint, "maximum"):
		return ""
	if not GFVariantData.get_option_bool(range_constraint, "inclusive_minimum", true):
		return ""
	if not GFVariantData.get_option_bool(range_constraint, "inclusive_maximum", true):
		return ""

	var minimum: float = GFVariantData.get_option_float(range_constraint, "minimum")
	var maximum: float = GFVariantData.get_option_float(range_constraint, "maximum")
	var step: float = 1.0 if value_type == GFConfigTableColumn.ValueType.INT else 0.01
	return "%s,%s,%s" % [str(minimum), str(maximum), str(step)]


static func _describe_validation_rules(column: GFConfigTableColumn) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule: GFConfigValidationRule in column.validation_rules:
		if rule != null:
			result.append(rule.describe())
	return result


static func _resolve_label_fields(
	reference_definition: GFConfigTableReference,
	target_schema: GFConfigTableSchema,
	options: Dictionary
) -> PackedStringArray:
	var option_fields: PackedStringArray = _to_packed_string_array(GFVariantData.get_option_value(options, "label_fields"))
	if not option_fields.is_empty():
		return option_fields

	var reference_fields: PackedStringArray = _to_packed_string_array(_get_metadata_value(reference_definition.metadata, METADATA_LABEL_FIELDS_KEY, []))
	if not reference_fields.is_empty():
		return reference_fields

	if target_schema != null:
		var schema_fields: PackedStringArray = _to_packed_string_array(_get_metadata_value(target_schema.metadata, METADATA_LABEL_FIELDS_KEY, []))
		if not schema_fields.is_empty():
			return schema_fields
	return PackedStringArray()


static func _normalize_records(target_table: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if target_table is GFConfigTableResource:
		var table_resource: GFConfigTableResource = target_table
		return table_resource.get_records(true)
	if target_table is Array:
		var raw_records: Array = target_table
		for record_value: Variant in raw_records:
			if record_value is Dictionary:
				var record: Dictionary = record_value
				records.append(record.duplicate(true))
		return records
	if target_table is Dictionary:
		var table_dictionary: Dictionary = target_table
		return _normalize_dictionary_records(table_dictionary)
	return records


static func _normalize_dictionary_records(table_dictionary: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var key_lookup: Dictionary = {}
	var sorted_keys: PackedStringArray = PackedStringArray()
	for record_key: Variant in table_dictionary.keys():
		var key_text: String = var_to_str(record_key)
		key_lookup[key_text] = record_key
		var _key_appended: bool = sorted_keys.append(key_text)
	sorted_keys.sort()

	for key_text: String in sorted_keys:
		var original_key: Variant = GFVariantData.get_option_value(key_lookup, key_text)
		var record_value: Variant = table_dictionary[original_key]
		if record_value is Dictionary:
			var record: Dictionary = record_value
			records.append(record.duplicate(true))
	return records


static func _make_choice_value(record: Dictionary, target_fields: PackedStringArray) -> Variant:
	if target_fields.size() == 1:
		return _get_record_field(record, StringName(target_fields[0]), null)

	var value_dictionary: Dictionary = {}
	for field_text: String in target_fields:
		var field_name: StringName = StringName(field_text)
		value_dictionary[field_name] = GFVariantData.duplicate_variant(_get_record_field(record, field_name, null))
	return value_dictionary


static func _make_choice_label(
	record: Dictionary,
	label_fields: PackedStringArray,
	target_fields: PackedStringArray,
	fallback_key: String
) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for field_text: String in label_fields:
		var field_name: StringName = StringName(field_text)
		if not _record_has_field(record, field_name):
			continue
		var text: String = GFVariantData.to_text(_get_record_field(record, field_name, ""))
		if text.is_empty():
			continue
		var _part_appended: bool = parts.append(text)
	if not parts.is_empty():
		return " / ".join(parts)

	if target_fields.size() == 1:
		var target_field: StringName = StringName(target_fields[0])
		var target_text: String = GFVariantData.to_text(_get_record_field(record, target_field, ""))
		if not target_text.is_empty():
			return target_text
	return fallback_key


static func _get_record_id(
	record: Dictionary,
	target_schema: GFConfigTableSchema,
	target_fields: PackedStringArray,
	fallback_key: String
) -> Variant:
	if target_schema != null and target_schema.id_field != &"":
		return _get_record_field(record, target_schema.id_field, fallback_key)
	if target_fields.size() == 1:
		return _get_record_field(record, StringName(target_fields[0]), fallback_key)
	return fallback_key


static func _get_metadata_bool(metadata: Dictionary, key: StringName, default_value: bool) -> bool:
	return GFVariantData.to_bool(_get_metadata_value(metadata, key, default_value), default_value)


static func _get_metadata_array(metadata: Dictionary, key: StringName) -> Array:
	var raw_array: Variant = _get_metadata_value(metadata, key, [])
	return GFVariantData.to_array(raw_array, [])


static func _get_metadata_value(metadata: Dictionary, key: StringName, default_value: Variant) -> Variant:
	if metadata.has(key):
		return metadata[key]
	var text_key: String = String(key)
	if metadata.has(text_key):
		return metadata[text_key]
	return default_value


static func _metadata_has_key(metadata: Dictionary, key: StringName) -> bool:
	return metadata.has(key) or metadata.has(String(key))


static func _dictionary_has_key(dictionary: Dictionary, key: Variant) -> bool:
	if dictionary.has(key):
		return true
	if key is StringName:
		var key_name: StringName = key
		return dictionary.has(String(key_name))
	if key is String:
		var key_text: String = key
		return dictionary.has(StringName(key_text))
	return false


static func _to_packed_string_array(source: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if source is PackedStringArray:
		var packed_source: PackedStringArray = source
		return packed_source.duplicate()
	if source is Array:
		var source_array: Array = source
		for item: Variant in source_array:
			var text: String = GFVariantData.to_text(item)
			if text.is_empty():
				continue
			var _array_item_appended: bool = result.append(text)
		return result
	var source_text: String = GFVariantData.to_text(source)
	if not source_text.is_empty():
		var _source_text_appended: bool = result.append(source_text)
	return result


static func _record_has_field(record: Dictionary, field_name: StringName) -> bool:
	return record.has(field_name) or record.has(String(field_name))


static func _get_record_field(record: Dictionary, field_name: StringName, default_value: Variant) -> Variant:
	if record.has(field_name):
		return record[field_name]
	var text_key: String = String(field_name)
	if record.has(text_key):
		return record[text_key]
	return default_value
