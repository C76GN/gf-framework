## GFConfigReferenceResolver: 通用导表引用校验与解析工具。
##
## 在多张表加载后统一检查引用、构建复合索引，并可把记录中的引用解析为目标记录副本。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFConfigReferenceResolver
extends RefCounted


# --- 公共方法 ---

## 构建表数据索引。
## [br]
## @api public
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param field_names: 参与索引的字段名。
## [br]
## @return 索引字典，key 为复合键，value 为记录数组。
## [br]
## @schema return: Dictionary，键为复合索引字符串，值为匹配记录副本组成的 Array[Dictionary]。
static func build_index(table_data: Variant, field_names: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _normalize_rows(table_data):
		var record: Dictionary = _get_row_record(entry)
		var key: String = _make_key(record, field_names, true)
		if key.is_empty():
			continue
		if not result.has(key):
			result[key] = []
		var records: Array = _get_index_records(result, key)
		records.append(record.duplicate(true))
	return result


## 校验多张表的 schema 与引用关系。
## [br]
## @api public
## [br]
## @param tables_by_name: 表名到表数据的字典。
## [br]
## @schema tables_by_name: Dictionary，键为表名 StringName，值为 Array[Dictionary] 或 Dictionary 表数据。
## [br]
## @param schemas: schema 列表。
## [br]
## @schema schemas: Array[GFConfigTableSchema]，参与校验的表结构声明。
## [br]
## @param options: 可选参数，当前支持 validate_schema。
## [br]
## @schema options: Dictionary，可包含 validate_schema。
## [br]
## @return 聚合校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_tables(
	tables_by_name: Dictionary,
	schemas: Array[GFConfigTableSchema],
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = _make_report()
	var schema_lookup: Dictionary = _build_schema_lookup(schemas)
	var validate_schema: bool = GFVariantData.get_option_bool(options, "validate_schema", true)
	var reference_index_cache: Dictionary = {}

	for schema: GFConfigTableSchema in schemas:
		if schema == null:
			continue
		var table_name: StringName = schema.get_table_key()
		if not tables_by_name.has(table_name):
			_add_issue(report, "error", "missing_table", table_name, null, &"", "缺少表数据：%s。" % String(table_name))
			continue
		if validate_schema:
			_merge_report(report, schema.validate_definition())
			_merge_report(report, schema.validate_table(tables_by_name[table_name]))
		_validate_schema_references(schema, tables_by_name, schema_lookup, reference_index_cache, report)

	_finalize_report(report)
	return report


## 解析单条记录的引用目标。
## [br]
## @api public
## [br]
## @param record: 来源记录。
## [br]
## @schema record: Dictionary，来源配置记录。
## [br]
## @param schema: 来源 schema。
## [br]
## @param tables_by_name: 表名到表数据的字典。
## [br]
## @schema tables_by_name: Dictionary，键为表名 StringName，值为 Array[Dictionary] 或 Dictionary 表数据。
## [br]
## @param schemas_by_name: 可选 schema 字典。
## [br]
## @schema schemas_by_name: Dictionary，键为表名 StringName，值为 GFConfigTableSchema。
## [br]
## @return 引用 ID 到目标记录副本的字典。
## [br]
## @schema return: Dictionary，键为 reference_id，值为解析出的目标记录 Dictionary 副本。
static func resolve_record_references(
	record: Dictionary,
	schema: GFConfigTableSchema,
	tables_by_name: Dictionary,
	schemas_by_name: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	if schema == null:
		return result

	var reference_index_cache: Dictionary = {}
	for reference_definition: GFConfigTableReference in schema.references:
		if reference_definition == null or not reference_definition.is_valid_definition():
			continue
		var source_key: String = reference_definition.make_source_key(record)
		if source_key.is_empty():
			continue

		var target_schema: GFConfigTableSchema = _get_schema_by_name(schemas_by_name, reference_definition.target_table_name)
		var target_fields: PackedStringArray = reference_definition.get_target_fields(target_schema)
		var target_table: Variant = _get_table_by_name(tables_by_name, reference_definition.target_table_name, null)
		if target_table == null:
			continue
		var target_index: Dictionary = _get_reference_index(
			target_table,
			reference_definition.target_table_name,
			target_fields,
			reference_index_cache
		)
		var matches: Array = _get_index_records(target_index, source_key)
		if not matches.is_empty():
			var matched_record: Dictionary = GFVariantData.as_dictionary(matches[0])
			result[reference_definition.get_reference_id()] = matched_record.duplicate(true)
	return result


# --- 私有/辅助方法 ---

static func _validate_schema_references(
	schema: GFConfigTableSchema,
	tables_by_name: Dictionary,
	schema_lookup: Dictionary,
	reference_index_cache: Dictionary,
	report: Dictionary
) -> void:
	for reference_definition: GFConfigTableReference in schema.references:
		if reference_definition == null or not reference_definition.is_valid_definition():
			_add_issue(report, "error", "invalid_reference", schema.get_table_key(), null, &"", "引用声明无效。")
			continue

		var target_schema: GFConfigTableSchema = _get_schema_by_name(schema_lookup, reference_definition.target_table_name)
		var target_fields: PackedStringArray = reference_definition.get_target_fields(target_schema)
		if target_fields.is_empty():
			_add_issue(
				report,
				"error",
				"missing_reference_target_fields",
				schema.get_table_key(),
				null,
				&"",
				"引用缺少目标字段：%s。" % String(reference_definition.get_reference_id())
			)
			continue

		var target_table: Variant = _get_table_by_name(tables_by_name, reference_definition.target_table_name, null)
		if target_table == null:
			_add_issue(
				report,
				"error",
				"missing_reference_target_table",
				schema.get_table_key(),
				null,
				&"",
				"引用目标表不存在：%s。" % String(reference_definition.target_table_name)
			)
			continue

		var target_index: Dictionary = _get_reference_index(
			target_table,
			reference_definition.target_table_name,
			target_fields,
			reference_index_cache
		)
		for entry: Dictionary in _normalize_rows(_get_table_by_name(tables_by_name, schema.get_table_key())):
			var record: Dictionary = _get_row_record(entry)
			var source_key: String = reference_definition.make_source_key(record)
			if source_key.is_empty():
				if reference_definition.required:
					_add_issue(
						report,
						"error",
						"missing_reference_value",
						schema.get_table_key(),
						_get_row_key(entry),
						_first_field(reference_definition.source_fields),
						"引用来源字段缺失：%s。" % String(reference_definition.get_reference_id())
					)
				continue
			if reference_definition.required and not target_index.has(source_key):
				_add_issue(
					report,
					"error",
					"missing_reference",
					schema.get_table_key(),
					_get_row_key(entry),
					_first_field(reference_definition.source_fields),
					"引用目标不存在：%s。" % String(reference_definition.get_reference_id())
				)


static func _build_schema_lookup(schemas: Array[GFConfigTableSchema]) -> Dictionary:
	var result: Dictionary = {}
	for schema: GFConfigTableSchema in schemas:
		if schema != null and schema.get_table_key() != &"":
			result[schema.get_table_key()] = schema
	return result


static func _get_reference_index(
	target_table: Variant,
	table_name: StringName,
	field_names: PackedStringArray,
	index_cache: Dictionary
) -> Dictionary:
	var cache_key: String = _make_reference_index_cache_key(table_name, field_names)
	if index_cache.has(cache_key):
		var cached_value: Variant = index_cache[cache_key]
		return GFVariantData.as_dictionary(cached_value)

	var index: Dictionary = build_index(target_table, field_names)
	index_cache[cache_key] = index
	return index


static func _make_reference_index_cache_key(table_name: StringName, field_names: PackedStringArray) -> String:
	return "%s::%s" % [String(table_name), "|".join(field_names)]


static func _get_schema_by_name(schemas_by_name: Dictionary, table_name: StringName) -> GFConfigTableSchema:
	return _variant_to_table_schema(GFVariantData.get_option_value(schemas_by_name, table_name))


static func _get_table_by_name(
	tables_by_name: Dictionary,
	table_name: StringName,
	default_value: Variant = []
) -> Variant:
	return GFVariantData.get_option_value(tables_by_name, table_name, default_value)


static func _get_index_records(index: Dictionary, key: String) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(index, key, []))


static func _get_row_record(row_entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(row_entry, "record", {}))


static func _get_row_key(row_entry: Dictionary) -> Variant:
	return GFVariantData.get_option_value(row_entry, "row_key")


static func _normalize_rows(table_data: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		var array_table: Array = GFVariantData.as_array(table_data)
		for index: int in range(array_table.size()):
			var row_variant: Variant = array_table[index]
			if row_variant is Dictionary:
				var row: Dictionary = GFVariantData.as_dictionary(row_variant)
				rows.append({
					"row_key": GFVariantData.get_option_value(row, &"id", index),
					"record": row.duplicate(true),
				})
	elif table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		for key: Variant in table.keys():
			var row_variant: Variant = table[key]
			if row_variant is Dictionary:
				var row: Dictionary = GFVariantData.as_dictionary(row_variant)
				rows.append({
					"row_key": key,
					"record": row.duplicate(true),
				})
	return rows


static func _make_key(record: Dictionary, field_names: PackedStringArray, allow_null_values: bool) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for field_name: String in field_names:
		var key: StringName = StringName(field_name)
		if not record.has(key):
			return ""
		var value: Variant = record[key]
		if value == null and not allow_null_values:
			return ""
		var _appended: bool = parts.append("%d:%s" % [typeof(value), var_to_str(value)])
	return "|".join(parts)


static func _make_report() -> Dictionary:
	return GFConfigValidationReport.new().make_report()


static func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	table_name: StringName,
	row_key: Variant,
	field_name: StringName,
	message: String
) -> void:
	GFConfigValidationReport.new().add_issue(report, severity, kind, table_name, row_key, field_name, message)


static func _merge_report(target: Dictionary, source: Dictionary) -> void:
	GFConfigValidationReport.new().merge_report(target, source, true)


static func _finalize_report(report: Dictionary) -> void:
	GFConfigValidationReport.new().finalize_report(report)


static func _first_field(fields: PackedStringArray) -> StringName:
	if fields.is_empty():
		return &""
	return StringName(fields[0])


static func _variant_to_table_schema(value: Variant) -> GFConfigTableSchema:
	if value is GFConfigTableSchema:
		var schema: GFConfigTableSchema = value
		return schema
	return null
