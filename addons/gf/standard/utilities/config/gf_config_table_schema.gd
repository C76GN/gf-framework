## GFConfigTableSchema: 通用导表结构声明与校验器。
##
## 用于在导入期或运行时校验表数据结构，保持数据工具链可替换且不绑定业务表。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigTableSchema
extends Resource


# --- 常量 ---

const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")


# --- 导出变量 ---

## 表名。为空时可由调用方自行决定表标识。
## [br]
## @api public
@export var table_name: StringName = &""

## 记录 ID 字段。为空时不检查记录 ID。
## [br]
## @api public
@export var id_field: StringName = &"id"

## 字段声明列表。
## [br]
## @api public
## [br]
## @schema columns: Array[GFConfigTableColumn]，定义当前表允许的字段和字段级校验规则。
@export var columns: Array[GFConfigTableColumn] = []

## 是否允许记录包含 schema 未声明的字段。
## [br]
## @api public
@export var allow_extra_fields: bool = true

## 是否在校验前按字段声明尝试类型转换。
## [br]
## @api public
@export var coerce_values: bool = false

## 启用 coerce_values 时，转换失败是否作为校验错误。
## [br]
## @api public
@export var fail_on_coerce_error: bool = true

## 校验整表时是否要求 id_field 唯一。
## [br]
## @api public
@export var require_unique_id: bool = false

## 可选复合索引声明。唯一索引会参与表级校验。
## [br]
## @api public
## [br]
## @schema indexes: Array[GFConfigTableIndexDefinition]，定义当前表的复合索引和唯一性约束。
@export var indexes: Array[GFConfigTableIndexDefinition] = []

## 可选跨表引用声明。引用目标由 `GFConfigReferenceResolver` 在多表上下文中校验。
## [br]
## @api public
## [br]
## @schema references: Array[GFConfigTableReference]，定义当前表到其他表的引用关系。
@export var references: Array[GFConfigTableReference] = []

## 可选记录级校验规则。规则会在字段结构校验后作用于整条记录。
## [br]
## @api public
## [br]
## @schema record_validation_rules: Array[GFConfigValidationRule]，包含作用于单条记录的校验规则。
@export var record_validation_rules: Array[GFConfigValidationRule] = []

## 可选表级校验规则。规则会在行结构、唯一 ID 和索引校验后作用于整表。
## [br]
## @api public
## [br]
## @schema table_validation_rules: Array[GFConfigValidationRule]，包含作用于整张表的校验规则。
@export var table_validation_rules: Array[GFConfigValidationRule] = []

## 可选元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存导入器、编辑器或项目层附加到当前 schema 的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 从记录样本推导通用 schema。
## [br]
## @api public
## [br]
## @param inferred_table_name: 推导出的表名。
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param options: 可选参数，支持 id_field、required_if_present_in_all_rows、allow_extra_fields、coerce_values。
## [br]
## @schema options: Dictionary，可包含 id_field、required_if_present_in_all_rows、allow_extra_fields 和 coerce_values。
## [br]
## @return 推导出的 schema；数据无效时返回空 schema。
static func infer_from_records(
	inferred_table_name: StringName,
	table_data: Variant,
	options: Dictionary = {}
) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = inferred_table_name
	schema.id_field = GFVariantData.get_option_string_name(options, "id_field", &"id")
	schema.allow_extra_fields = GFVariantData.get_option_bool(options, "allow_extra_fields", true)
	schema.coerce_values = GFVariantData.get_option_bool(options, "coerce_values", false)

	var rows: Array[Dictionary] = _normalize_inference_rows(table_data)
	if rows.is_empty():
		return schema

	var field_presence: Dictionary = {}
	var field_values: Dictionary = {}
	for row: Dictionary in rows:
		for key: Variant in row.keys():
			var field_name: StringName = GFVariantData.to_string_name(key)
			field_presence[field_name] = GFVariantData.get_option_int(field_presence, field_name, 0) + 1
			_append_field_value(field_values, field_name, row[key])

	var field_names: PackedStringArray = PackedStringArray()
	for field_name: StringName in field_values.keys():
		_append_packed_string(field_names, String(field_name))
	field_names.sort()

	var require_if_present_all: bool = GFVariantData.get_option_bool(options, "required_if_present_in_all_rows", false)
	for field_text: String in field_names:
		var field_name: StringName = StringName(field_text)
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		var values: Array = _get_field_values(field_values, field_name)
		column.field_name = field_name
		column.value_type = _infer_column_value_type(values)
		column.required = require_if_present_all and GFVariantData.get_option_int(field_presence, field_name, 0) == rows.size()
		column.allow_null = _values_allow_null(values)
		schema.columns.append(column)

	return schema


## 获取稳定表键。
## [br]
## @api public
## [br]
## @return 表名。
func get_table_key() -> StringName:
	return table_name


## 获取字段声明。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 找到时返回字段声明，否则返回 null。
func get_column(field_name: StringName) -> GFConfigTableColumn:
	for column: GFConfigTableColumn in columns:
		if column != null and column.get_field_key() == field_name:
			return column
	return null


## 检查字段声明是否存在。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 存在返回 true。
func has_column(field_name: StringName) -> bool:
	return get_column(field_name) != null


## 获取索引声明。
## [br]
## @api public
## [br]
## @param index_id: 索引标识。
## [br]
## @return 找到时返回索引声明，否则返回 null。
func get_index(index_id: StringName) -> GFConfigTableIndexDefinition:
	for index: GFConfigTableIndexDefinition in indexes:
		if index != null and index.get_index_id() == index_id:
			return index
	return null


## 检查索引声明是否存在。
## [br]
## @api public
## [br]
## @param index_id: 索引标识。
## [br]
## @return 存在返回 true。
func has_index(index_id: StringName) -> bool:
	return get_index(index_id) != null


## 获取引用声明。
## [br]
## @api public
## [br]
## @param reference_id: 引用标识。
## [br]
## @return 找到时返回引用声明，否则返回 null。
func get_reference(reference_id: StringName) -> GFConfigTableReference:
	for reference_definition: GFConfigTableReference in references:
		if reference_definition != null and reference_definition.get_reference_id() == reference_id:
			return reference_definition
	return null


## 检查引用声明是否存在。
## [br]
## @api public
## [br]
## @param reference_id: 引用标识。
## [br]
## @return 存在返回 true。
func has_reference(reference_id: StringName) -> bool:
	return get_reference(reference_id) != null


## 获取当前 schema 的字段名列表。
## [br]
## @api public
## [br]
## @return 字段名列表。
func get_column_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for column: GFConfigTableColumn in columns:
		if column != null and column.get_field_key() != &"":
			_append_packed_string(result, str(column.get_field_key()))
	result.sort()
	return result


## 校验 schema 自身声明是否完整、一致。
## [br]
## @api public
## [br]
## @param options: 可选上下文，支持 source。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_definition(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(0)
	_validate_column_definitions(report, options)
	_validate_index_definitions(report, options)
	_validate_reference_definitions(report, options)
	_validate_rule_definitions(report, options)
	_finalize_report(report)
	return report


## 校验单条记录。
## [br]
## @api public
## [br]
## @param record: 记录字典。
## [br]
## @schema record: Dictionary，待校验的配置记录，键为字段名，值为字段数据。
## [br]
## @param row_key: 可选行标识，用于错误报告。
## [br]
## @schema row_key: Variant，写入校验报告 issue 的行标识。
## [br]
## @param options: 可选上下文，支持 source、line、row_index、row_locations。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_record(record: Dictionary, row_key: Variant = null, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(1)
	var working_record: Dictionary = _coerce_record_for_validation(record, row_key, report, options) if coerce_values else record
	var declared_fields: Dictionary = {}

	for column: GFConfigTableColumn in columns:
		if column == null:
			_add_issue(report, "error", "null_column", row_key, &"", "字段声明为空。", _make_record_context(row_key, options))
			continue

		var field_key: StringName = column.get_field_key()
		var field_context: Dictionary = _make_field_context(row_key, field_key, options)
		if field_key == &"":
			_add_issue(report, "error", "empty_field", row_key, &"", "字段名为空。", field_context)
			continue

		declared_fields[field_key] = true
		if not working_record.has(field_key):
			if column.required:
				_add_issue(
					report,
					"error",
					"missing_required",
					row_key,
					field_key,
					"缺少必填字段：%s。" % str(field_key),
					_make_value_context(row_key, field_key, options, null, "present", "missing")
				)
			continue

		var field_value: Variant = working_record[field_key]
		if field_value == null and not column.allow_null:
			_add_issue(
				report,
				"error",
				"null_value",
				row_key,
				field_key,
				"字段不允许为空：%s。" % str(field_key),
				_make_value_context(row_key, field_key, options, field_value, "non_null")
			)
		elif not column.is_value_valid(field_value):
			_add_issue(
				report,
				"error",
				"invalid_type",
				row_key,
				field_key,
				"字段类型不匹配：%s。" % str(field_key),
				_make_value_context(row_key, field_key, options, field_value, _value_type_to_name(column.value_type))
			)
		else:
			_validate_column_rules(column, field_value, row_key, report, options)

	if not allow_extra_fields:
		for field_variant: Variant in working_record.keys():
			var field_name: StringName = GFVariantData.to_string_name(field_variant)
			if not declared_fields.has(field_name):
				_add_issue(
					report,
					"error",
					"extra_field",
					row_key,
					field_name,
					"存在未声明字段：%s。" % str(field_name),
					_make_value_context(
						row_key,
						field_name,
						options,
						GFVariantData.get_option_value(working_record, field_name),
						"declared_field"
					)
				)

	_validate_record_rules(working_record, row_key, report, options)
	_finalize_report(report)
	return report


## 校验整张表。
## [br]
## @api public
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param options: 可选上下文，支持 source、row_locations。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_table(table_data: Variant, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(0)
	if table_data is Array:
		_validate_array_table(GFVariantData.as_array(table_data), report, options)
	elif table_data is Dictionary:
		_validate_dictionary_table(GFVariantData.as_dictionary(table_data), report, options)
	else:
		_add_issue(report, "error", "invalid_table", null, &"", "表数据必须是 Array 或 Dictionary。", _make_record_context(null, options))

	_finalize_report(report)
	return report


## 按字段声明转换单条记录。
## [br]
## @api public
## [br]
## @param record: 输入记录。
## [br]
## @schema record: Dictionary，待转换的配置记录，键为字段名，值为字段数据。
## [br]
## @return 转换后的新记录。
## [br]
## @schema return: Dictionary，转换后的记录副本。
func coerce_record(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	for column: GFConfigTableColumn in columns:
		if column == null or column.get_field_key() == &"":
			continue

		var field_key: StringName = column.get_field_key()
		if result.has(field_key):
			result[field_key] = column.coerce_value(result[field_key])
		elif column.default_value != null:
			result[field_key] = column.coerce_value(column.default_value)
	return result


## 创建空记录模板。
## [br]
## @api public
## [br]
## @param include_optional: 为 true 时包含非必填字段。
## [br]
## @return 新记录字典。
## [br]
## @schema return: Dictionary，键为字段名，值为字段默认值转换后的结果。
func build_empty_record(include_optional: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for column: GFConfigTableColumn in columns:
		if column == null or column.get_field_key() == &"":
			continue
		if column.required or include_optional:
			result[column.get_field_key()] = column.coerce_value(column.default_value)
	return result


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @return 新 schema。
func duplicate_schema() -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	schema.id_field = id_field
	schema.allow_extra_fields = allow_extra_fields
	schema.coerce_values = coerce_values
	schema.fail_on_coerce_error = fail_on_coerce_error
	schema.require_unique_id = require_unique_id
	for index: GFConfigTableIndexDefinition in indexes:
		schema.indexes.append(index.duplicate_index() if index != null else null)
	for reference_definition: GFConfigTableReference in references:
		schema.references.append(reference_definition.duplicate_reference() if reference_definition != null else null)
	for rule: GFConfigValidationRule in record_validation_rules:
		schema.record_validation_rules.append(rule.duplicate_rule() if rule != null else null)
	for rule: GFConfigValidationRule in table_validation_rules:
		schema.table_validation_rules.append(rule.duplicate_rule() if rule != null else null)
	schema.metadata = metadata.duplicate(true)
	for column: GFConfigTableColumn in columns:
		schema.columns.append(column.duplicate_column() if column != null else null)
	return schema


## 导出 schema 摘要。
## [br]
## @api public
## [br]
## @return schema 字典。
## [br]
## @schema return: Dictionary，包含 table_name、id_field、columns、allow_extra_fields、coerce_values、fail_on_coerce_error、require_unique_id、indexes、references、record_validation_rules、table_validation_rules 和 metadata。
func describe() -> Dictionary:
	var column_descriptions: Array[Dictionary] = []
	for column: GFConfigTableColumn in columns:
		if column != null:
			column_descriptions.append(column.describe())
	var index_descriptions: Array[Dictionary] = []
	for index: GFConfigTableIndexDefinition in indexes:
		if index != null:
			index_descriptions.append(index.describe())
	var reference_descriptions: Array[Dictionary] = []
	for reference_definition: GFConfigTableReference in references:
		if reference_definition != null:
			reference_descriptions.append(reference_definition.describe())
	var record_rule_descriptions: Array[Dictionary] = _describe_validation_rules(record_validation_rules)
	var table_rule_descriptions: Array[Dictionary] = _describe_validation_rules(table_validation_rules)
	return {
		"table_name": table_name,
		"id_field": id_field,
		"columns": column_descriptions,
		"allow_extra_fields": allow_extra_fields,
		"coerce_values": coerce_values,
		"fail_on_coerce_error": fail_on_coerce_error,
		"require_unique_id": require_unique_id,
		"indexes": index_descriptions,
		"references": reference_descriptions,
		"record_validation_rules": record_rule_descriptions,
		"table_validation_rules": table_rule_descriptions,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_record_row_key(record: Dictionary, default_value: Variant) -> Variant:
	if id_field == &"":
		return default_value
	return GFVariantData.get_option_value(record, id_field, default_value)


func _get_row_entry_record(row_entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(row_entry, "record", {}))


func _get_row_entry_key(row_entry: Dictionary) -> Variant:
	return GFVariantData.get_option_value(row_entry, "row_key")


func _validate_array_table(rows: Array, report: Dictionary, options: Dictionary) -> void:
	report["row_count"] = rows.size()
	var seen_ids: Dictionary = {}
	var valid_rows: Array[Dictionary] = []
	for index: int in range(rows.size()):
		var row: Variant = rows[index]
		if not (row is Dictionary):
			_add_issue(report, "error", "invalid_row", index, &"", "行数据必须是 Dictionary。", _make_record_context(index, _make_row_options(options, index)))
			continue

		var record: Dictionary = GFVariantData.as_dictionary(row)
		var row_key: Variant = _get_record_row_key(record, index)
		var row_options: Dictionary = _make_row_options(options, index)
		valid_rows.append({
			"row_key": row_key,
			"row_index": index,
			"record": record,
		})
		_merge_report(report, validate_record(record, row_key, row_options))
		_validate_unique_id(record, row_key, seen_ids, report, row_options)
	_validate_index_constraints(valid_rows, report)
	_validate_table_rules(valid_rows, report, options)


func _validate_dictionary_table(table: Dictionary, report: Dictionary, options: Dictionary) -> void:
	report["row_count"] = table.size()
	var seen_ids: Dictionary = {}
	var valid_rows: Array[Dictionary] = []
	for key: Variant in table.keys():
		var row: Variant = table[key]
		if not (row is Dictionary):
			_add_issue(report, "error", "invalid_row", key, &"", "行数据必须是 Dictionary。", _make_record_context(key, options))
			continue

		var record: Dictionary = GFVariantData.as_dictionary(row)
		var row_key: Variant = _get_record_row_key(record, key)
		valid_rows.append({
			"row_key": row_key,
			"record": record,
		})
		_merge_report(report, validate_record(record, row_key, options))
		_validate_unique_id(record, row_key, seen_ids, report, options)
	_validate_index_constraints(valid_rows, report)
	_validate_table_rules(valid_rows, report, options)


func _make_report(row_count: int) -> Dictionary:
	return _CONFIG_VALIDATION_REPORT.new().make_report(table_name, row_count)


func _validate_column_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_fields: Dictionary = {}
	for index: int in range(columns.size()):
		var column: GFConfigTableColumn = columns[index]
		var context: Dictionary = _make_definition_context(options, index)
		if column == null:
			_add_issue(report, "error", "null_column", null, &"", "字段声明为空。", context)
			continue

		var field_key: StringName = column.get_field_key()
		context["field"] = field_key
		if field_key == &"":
			_add_issue(report, "error", "empty_field", null, &"", "字段名为空。", context)
			continue
		if seen_fields.has(field_key):
			_add_issue(
				report,
				"error",
				"duplicate_column_field",
				null,
				field_key,
				"字段声明重复：%s。" % String(field_key),
				context
			)
		seen_fields[field_key] = true
		_validate_column_rule_definitions(column, report, context)


func _validate_column_rule_definitions(
	column: GFConfigTableColumn,
	report: Dictionary,
	context: Dictionary
) -> void:
	for rule: GFConfigValidationRule in column.validation_rules:
		if rule == null:
			_add_issue(
				report,
				"error",
				"null_validation_rule",
				null,
				column.get_field_key(),
				"字段校验规则为空。",
				context
			)


func _validate_index_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_index_ids: Dictionary = {}
	for index: GFConfigTableIndexDefinition in indexes:
		if index == null:
			_add_issue(report, "error", "null_index", null, &"", "索引声明为空。", _make_record_context(null, options))
			continue
		if not index.is_valid_definition():
			_add_issue(report, "error", "invalid_index", null, &"", "索引声明无效。", _make_record_context(null, options))
			continue

		var index_id: StringName = index.get_index_id()
		if seen_index_ids.has(index_id):
			_add_issue(
				report,
				"error",
				"duplicate_index_id",
				null,
				&"",
				"索引 ID 重复：%s。" % String(index_id),
				_make_record_context(null, options)
			)
		seen_index_ids[index_id] = true
		for field_name: String in index.field_names:
			if not has_column(StringName(field_name)):
				_add_issue(
					report,
					"error",
					"index_unknown_field",
					null,
					StringName(field_name),
					"索引字段未声明：%s。" % field_name,
					_make_field_context(null, StringName(field_name), options)
				)


func _validate_reference_definitions(report: Dictionary, options: Dictionary) -> void:
	var seen_reference_ids: Dictionary = {}
	for reference_definition: GFConfigTableReference in references:
		if reference_definition == null:
			_add_issue(report, "error", "null_reference", null, &"", "引用声明为空。", _make_record_context(null, options))
			continue
		if not reference_definition.is_valid_definition():
			_add_issue(report, "error", "invalid_reference", null, &"", "引用声明无效。", _make_record_context(null, options))
			continue

		var reference_id: StringName = reference_definition.get_reference_id()
		if seen_reference_ids.has(reference_id):
			_add_issue(
				report,
				"error",
				"duplicate_reference_id",
				null,
				&"",
				"引用 ID 重复：%s。" % String(reference_id),
				_make_record_context(null, options)
		)
		seen_reference_ids[reference_id] = true
		for field_name: String in reference_definition.source_fields:
			if not has_column(StringName(field_name)):
				_add_issue(
					report,
					"error",
					"reference_unknown_source_field",
					null,
					StringName(field_name),
					"引用来源字段未声明：%s。" % field_name,
					_make_field_context(null, StringName(field_name), options)
				)


func _validate_rule_definitions(report: Dictionary, options: Dictionary) -> void:
	for rule: GFConfigValidationRule in record_validation_rules:
		if rule == null:
			_add_issue(report, "error", "null_record_validation_rule", null, &"", "记录校验规则为空。", _make_record_context(null, options))
	for rule: GFConfigValidationRule in table_validation_rules:
		if rule == null:
			_add_issue(report, "error", "null_table_validation_rule", null, &"", "表校验规则为空。", _make_record_context(null, options))


func _coerce_record_for_validation(record: Dictionary, row_key: Variant, report: Dictionary, options: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	for column: GFConfigTableColumn in columns:
		if column == null or column.get_field_key() == &"":
			continue

		var field_key: StringName = column.get_field_key()
		var has_value: bool = result.has(field_key)
		if not has_value and column.default_value == null:
			continue

		var source_value: Variant = result[field_key] if has_value else column.default_value
		var coerce_result: Dictionary = column.try_coerce_value(source_value)
		result[field_key] = GFVariantData.get_option_value(coerce_result, "value")
		if fail_on_coerce_error and not GFVariantData.get_option_bool(coerce_result, "ok", false):
			_add_issue(
				report,
				"error",
				"coerce_failed",
				row_key,
				field_key,
				GFVariantData.get_option_string(coerce_result, "message", "字段类型转换失败：%s。" % str(field_key)),
				_make_value_context(row_key, field_key, options, source_value, _value_type_to_name(column.value_type))
			)
	return result


func _validate_unique_id(
	record: Dictionary,
	row_key: Variant,
	seen_ids: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	if not require_unique_id or id_field == &"" or not record.has(id_field):
		return

	var id_value: Variant = record[id_field]
	var id_column: GFConfigTableColumn = get_column(id_field)
	if coerce_values and id_column != null:
		id_value = id_column.coerce_value(id_value)

	var id_key: String = _make_variant_key(id_value)
	if seen_ids.has(id_key):
		_add_issue(
			report,
			"error",
			"duplicate_id",
			row_key,
			id_field,
			"记录 ID 重复：%s。" % str(id_value),
			_make_field_context(row_key, id_field, options)
		)
		return

	seen_ids[id_key] = row_key


func _validate_index_constraints(rows: Array[Dictionary], report: Dictionary) -> void:
	for index: GFConfigTableIndexDefinition in indexes:
		if index == null:
			_add_issue(report, "error", "null_index", null, &"", "索引声明为空。")
			continue
		if not index.is_valid_definition():
			_add_issue(report, "error", "invalid_index", null, &"", "索引声明无效。")
			continue
		for field_name: String in index.field_names:
			if not has_column(StringName(field_name)):
				_add_issue(report, "error", "index_unknown_field", null, StringName(field_name), "索引字段未声明：%s。" % field_name)
		if not index.unique:
			continue

		var seen_keys: Dictionary = {}
		for row_entry: Dictionary in rows:
			var record: Dictionary = _get_row_entry_record(row_entry)
			var key: String = index.make_key(record)
			if key.is_empty():
				continue
			if seen_keys.has(key):
				_add_issue(
					report,
					"error",
					"duplicate_index_key",
					_get_row_entry_key(row_entry),
					&"",
					"唯一索引重复：%s。" % String(index.get_index_id())
				)
				continue
			seen_keys[key] = _get_row_entry_key(row_entry)


func _make_variant_key(value: Variant) -> String:
	return "%d:%s" % [typeof(value), str(value)]


func _validate_column_rules(
	column: GFConfigTableColumn,
	value: Variant,
	row_key: Variant,
	report: Dictionary,
	options: Dictionary
) -> void:
	for rule: GFConfigValidationRule in column.validation_rules:
		if rule == null:
			_add_issue(report, "error", "null_validation_rule", row_key, column.get_field_key(), "字段校验规则为空。", _make_field_context(row_key, column.get_field_key(), options))
			continue
		_merge_report(report, rule.validate_value(value, _make_field_context(row_key, column.get_field_key(), options)))


func _validate_record_rules(record: Dictionary, row_key: Variant, report: Dictionary, options: Dictionary) -> void:
	for rule: GFConfigValidationRule in record_validation_rules:
		if rule == null:
			_add_issue(report, "error", "null_record_validation_rule", row_key, &"", "记录校验规则为空。", _make_record_context(row_key, options))
			continue
		_merge_report(report, rule.validate_record(record, _make_record_context(row_key, options)))


func _validate_table_rules(rows: Array[Dictionary], report: Dictionary, options: Dictionary) -> void:
	for rule: GFConfigValidationRule in table_validation_rules:
		if rule == null:
			_add_issue(report, "error", "null_table_validation_rule", null, &"", "表校验规则为空。", _make_record_context(null, options))
			continue
		_merge_report(report, rule.validate_table(rows, _make_record_context(null, options)))


func _describe_validation_rules(rules: Array[GFConfigValidationRule]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule: GFConfigValidationRule in rules:
		if rule != null:
			result.append(rule.describe())
	return result


func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	row_key: Variant,
	field_name: StringName,
	message: String,
	context: Dictionary = {}
) -> void:
	_CONFIG_VALIDATION_REPORT.new().add_issue(report, severity, kind, table_name, row_key, field_name, message, context)


func _merge_report(target: Dictionary, source: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().merge_report(target, source)


func _finalize_report(report: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().finalize_report(report)


func _make_row_options(options: Dictionary, row_index: int) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	result["row_index"] = row_index
	return result


func _make_definition_context(options: Dictionary, column_index: int) -> Dictionary:
	var context: Dictionary = _make_record_context(null, options)
	context["column_index"] = column_index
	return context


func _make_record_context(row_key: Variant, options: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"table_name": table_name,
		"row_key": row_key,
	}
	_copy_context_fields(context, options)
	_apply_row_location(context, &"", options)
	return context


func _make_field_context(row_key: Variant, field_name: StringName, options: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"table_name": table_name,
		"row_key": row_key,
		"field": field_name,
	}
	_copy_context_fields(context, options)
	_apply_row_location(context, field_name, options)
	return context


func _make_value_context(
	row_key: Variant,
	field_name: StringName,
	options: Dictionary,
	field_value: Variant,
	expected_value: Variant,
	actual_value: Variant = null
) -> Dictionary:
	var context: Dictionary = _make_field_context(row_key, field_name, options)
	context["value"] = GFVariantData.duplicate_variant(field_value)
	context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	context["actual_value"] = GFVariantData.duplicate_variant(field_value if actual_value == null else actual_value)
	return context


func _copy_context_fields(target: Dictionary, source: Dictionary) -> void:
	for field_name: String in [
		"source",
		"line",
		"column",
		"row_index",
		"column_index",
		"rule_id",
		"value",
		"expected_value",
		"actual_value",
		"supported_values",
		"supported_formats",
		"supported_content_types",
	]:
		if source.has(field_name):
			target[field_name] = GFVariantData.duplicate_variant(source[field_name])


func _apply_row_location(context: Dictionary, field_name: StringName, options: Dictionary) -> void:
	var row_index: int = GFVariantData.get_option_int(options, "row_index", -1)
	var row_locations: Variant = GFVariantData.get_option_value(options, "row_locations", [])
	if row_index < 0 or not (row_locations is Array):
		return
	var locations: Array = GFVariantData.as_array(row_locations)
	if row_index >= locations.size() or not (locations[row_index] is Dictionary):
		return

	var row_location: Dictionary = GFVariantData.as_dictionary(locations[row_index])
	_copy_context_fields(context, row_location)
	var field_locations: Variant = GFVariantData.get_option_value(row_location, "fields", {})
	if not (field_locations is Dictionary) or field_name == &"":
		return
	var fields: Dictionary = GFVariantData.as_dictionary(field_locations)
	var field_location: Variant = GFVariantData.get_option_value(fields, field_name)
	if field_location is Dictionary:
		_copy_context_fields(context, GFVariantData.as_dictionary(field_location))


static func _append_field_value(field_values: Dictionary, field_name: StringName, value: Variant) -> void:
	var values: Array = _get_field_values(field_values, field_name)
	values.append(value)
	field_values[field_name] = values


static func _get_field_values(field_values: Dictionary, field_name: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(field_values, field_name, []))


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _normalize_inference_rows(table_data: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		for row_variant: Variant in table_data:
			if row_variant is Dictionary:
				rows.append(GFVariantData.as_dictionary(row_variant).duplicate(true))
	elif table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		for key: Variant in table.keys():
			var row_variant: Variant = table[key]
			if row_variant is Dictionary:
				rows.append(GFVariantData.as_dictionary(row_variant).duplicate(true))
	return rows


static func _infer_column_value_type(values: Array) -> GFConfigTableColumn.ValueType:
	var inferred_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.ANY
	for value: Variant in values:
		if value == null:
			continue

		var value_type: GFConfigTableColumn.ValueType = _value_to_column_type(value)
		if inferred_type == GFConfigTableColumn.ValueType.ANY:
			inferred_type = value_type
		elif inferred_type == GFConfigTableColumn.ValueType.INT and value_type == GFConfigTableColumn.ValueType.FLOAT:
			inferred_type = GFConfigTableColumn.ValueType.FLOAT
		elif inferred_type == GFConfigTableColumn.ValueType.FLOAT and value_type == GFConfigTableColumn.ValueType.INT:
			continue
		elif inferred_type != value_type:
			return GFConfigTableColumn.ValueType.ANY
	return inferred_type


static func _value_to_column_type(value: Variant) -> GFConfigTableColumn.ValueType:
	match typeof(value):
		TYPE_BOOL:
			return GFConfigTableColumn.ValueType.BOOL
		TYPE_INT:
			return GFConfigTableColumn.ValueType.INT
		TYPE_FLOAT:
			return GFConfigTableColumn.ValueType.FLOAT
		TYPE_STRING:
			return GFConfigTableColumn.ValueType.STRING
		TYPE_STRING_NAME:
			return GFConfigTableColumn.ValueType.STRING_NAME
		TYPE_DICTIONARY:
			return GFConfigTableColumn.ValueType.DICTIONARY
		TYPE_ARRAY:
			return GFConfigTableColumn.ValueType.ARRAY
		_:
			if value is Vector2:
				return GFConfigTableColumn.ValueType.VECTOR2
			if value is Vector2i:
				return GFConfigTableColumn.ValueType.VECTOR2I
			if value is Color:
				return GFConfigTableColumn.ValueType.COLOR
	return GFConfigTableColumn.ValueType.ANY


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
			return "any"


static func _values_allow_null(values: Array) -> bool:
	for value: Variant in values:
		if value == null:
			return true
	return false
