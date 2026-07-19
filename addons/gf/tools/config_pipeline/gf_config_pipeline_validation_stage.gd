## GFConfigPipelineValidationStage: Config Pipeline 的内置语义校验阶段。
##
## 把 Layout 记录规范化，解析类型化表头，推导或复制 schema，执行类型转换与完整校验。
## 只有通过语义校验的数据才会形成 GFConfigPipelineTableIR。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineValidationStage
extends RefCounted


# --- 常量 ---

## Validation 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.validation.builtin"

## Validation 阶段的实现版本；改变语义校验或 IR 生成语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 1


# --- 公共方法 ---

## 把 Layout 结果编译为通过校验的版本化单表 IR。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param source: 单表来源声明。
## [br]
## @param layout_result: Layout 阶段结果。
## [br]
## @schema layout_result: Dictionary，符合 gf.config_pipeline.layout_result@1。
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 parse_options；其字段覆盖 source.parse_options 并传给 schema 校验上下文。
## [br]
## @return: Validation 阶段结果。
## [br]
## @schema return: Dictionary，包含 success、phase、ir、report、source_path、format、error_kind 和 error。
func compile_table(
	source: GFConfigPipelineTableSource,
	layout_result: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if source == null:
		return _make_compile_failure(&"", "invalid_table_source", "表来源声明为空。")
	var table_name: StringName = source.get_table_key()
	var resolved_format: StringName = source.get_resolved_format()
	if table_name == &"":
		return _make_compile_failure(&"", "empty_table_name", "无法确定配置表名。", source.source_path, resolved_format)
	if not GFVariantData.get_option_bool(layout_result, "success"):
		var failure_context: Dictionary = GFVariantData.get_option_dictionary(layout_result, "context")
		failure_context["source"] = source.source_path
		failure_context["line"] = GFVariantData.get_option_int(layout_result, "error_line")
		failure_context["column"] = GFVariantData.get_option_int(layout_result, "error_column")
		failure_context["actual_value"] = resolved_format
		return _make_compile_failure(
			table_name,
			GFVariantData.get_option_string(layout_result, "error_kind", "parse_failed"),
			GFVariantData.get_option_string(layout_result, "error"),
			source.source_path,
			resolved_format,
			failure_context
		)

	var working_layout: Dictionary = layout_result.duplicate(false)
	working_layout["row_locations"] = GFVariantData.duplicate_variant(
		GFVariantData.get_option_value(layout_result, "row_locations", [])
	)
	var records_result: Dictionary = _normalize_records(GFVariantData.get_option_value(working_layout, "data"))
	if not GFVariantData.get_option_bool(records_result, "success"):
		return _make_compile_failure(
			table_name,
			"invalid_table_data",
			"配置表数据必须是 Array[Dictionary] 或 Dictionary[String, Dictionary]。",
			source.source_path,
			resolved_format,
			{
				"source": source.source_path,
				"actual_value": GFVariantData.get_option_string(records_result, "actual_value"),
				"expected_value": "Array[Dictionary] or Dictionary[String, Dictionary]",
			}
		)

	var records: Array[Dictionary] = _get_result_records(records_result)
	var typed_header_result: Dictionary = _apply_typed_header_schema(source, table_name, records, working_layout)
	if not GFVariantData.get_option_bool(typed_header_result, "success", true):
		var typed_header_context: Dictionary = GFVariantData.get_option_dictionary(typed_header_result, "context")
		typed_header_context["source"] = source.source_path
		return _make_compile_failure(
			table_name,
			GFVariantData.get_option_string(typed_header_result, "kind", "invalid_typed_header"),
			GFVariantData.get_option_string(typed_header_result, "error"),
			source.source_path,
			resolved_format,
			typed_header_context
		)

	records = _get_result_records(typed_header_result)
	var declared_schema: GFConfigTableSchema = _get_schema_from_result(typed_header_result)
	var schema: GFConfigTableSchema = _resolve_schema(source, table_name, records, declared_schema)
	var report: Dictionary = _validate_table_source(source, table_name, records, schema, working_layout, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		return {
			"success": false,
			"phase": "validation",
			"ir": null,
			"report": report,
			"source_path": source.source_path,
			"format": resolved_format,
			"error_kind": "validation_failed",
			"error": "配置表语义校验失败：%s。" % String(table_name),
		}
	if schema != null and schema.coerce_values and source.coerce_records:
		records = _coerce_records(records, schema)

	var source_map: Dictionary = _make_source_map(working_layout)
	var table_ir: GFConfigPipelineTableIR = GFConfigPipelineTableIR.create(
		table_name,
		source.source_path,
		resolved_format,
		records,
		schema,
		source_map,
		_make_table_metadata(source, resolved_format)
	)
	var contract: Dictionary = table_ir.validate_contract()
	if not GFVariantData.get_option_bool(contract, "success"):
		return _make_compile_failure(
			table_name,
			"invalid_table_ir",
			GFVariantData.get_option_string(contract, "error"),
			source.source_path,
			resolved_format
		)
	return {
		"success": true,
		"phase": "validation",
		"ir": table_ir,
		"report": report,
		"source_path": source.source_path,
		"format": resolved_format,
		"error_kind": "",
		"error": "",
	}


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、input_contract 和 output_contract。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contract": "gf.config_pipeline.layout_result@1",
		"output_contract": "%s@%d" % [GFConfigPipelineTableIR.FORMAT, GFConfigPipelineTableIR.FORMAT_VERSION],
	}


# --- 私有/辅助方法 ---

func _normalize_records(table_data: Variant) -> Dictionary:
	var records: Array[Dictionary] = []
	if table_data is Array:
		var rows: Array = GFVariantData.as_array(table_data)
		for row_value: Variant in rows:
			if not (row_value is Dictionary):
				return _make_records_failure(table_data)
			var row: Dictionary = row_value
			records.append(row.duplicate(true))
		return {
			"success": true,
			"records": records,
			"actual_value": "Array",
		}

	if table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		var keys: Array = table.keys()
		keys.sort()
		for key: Variant in keys:
			var row_value: Variant = table[key]
			if not (row_value is Dictionary):
				return _make_records_failure(table_data)
			var row: Dictionary = row_value
			records.append(row.duplicate(true))
		return {
			"success": true,
			"records": records,
			"actual_value": "Dictionary",
		}

	return _make_records_failure(table_data)


func _resolve_schema(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	declared_schema: GFConfigTableSchema = null
) -> GFConfigTableSchema:
	var source_schema: GFConfigTableSchema = source.schema
	var schema: GFConfigTableSchema = source_schema.duplicate_schema() if source_schema != null else null
	if schema == null and declared_schema != null:
		schema = declared_schema.duplicate_schema()
	if schema == null and source.infer_schema:
		schema = GFConfigTableSchema.infer_from_records(table_name, records, source.schema_options)
	if schema != null and schema.table_name == &"":
		schema.table_name = table_name
	return schema


func _validate_table_source(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	schema: GFConfigTableSchema,
	parse_result: Dictionary,
	options: Dictionary
) -> Dictionary:
	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = report_builder.make_report(table_name, records.size())
	if schema == null:
		report_builder.add_issue(
			report,
			"warning",
			"missing_schema",
			table_name,
			null,
			&"",
			"配置表来源没有 schema，已跳过结构校验。",
			{ "source": source.source_path }
		)
		report_builder.finalize_report(report)
		return report

	var validation_options: Dictionary = source.parse_options.duplicate(true)
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(
		validation_options,
		GFVariantData.get_option_dictionary(options, "parse_options")
	)
	if not source.source_path.is_empty():
		validation_options["source"] = source.source_path
	if parse_result.has("row_locations"):
		validation_options["row_locations"] = GFVariantData.get_option_value(parse_result, "row_locations")
	report_builder.merge_report(report, schema.validate_definition(validation_options), false)
	report_builder.merge_report(report, schema.validate_table(records, validation_options), false)
	report_builder.finalize_report(report)
	return report


func _apply_typed_header_schema(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	parse_result: Dictionary
) -> Dictionary:
	if not GFVariantData.get_option_bool(source.schema_options, "typed_headers", false):
		return {
			"success": true,
			"records": records,
			"schema": null,
		}

	var source_records: Array[Dictionary] = records
	var raw_fields: Array[StringName] = []
	if GFVariantData.get_option_bool(source.schema_options, "typed_header_type_row", false):
		var type_row_result: Dictionary = _collect_typed_header_type_row_field_names(parse_result, records)
		if not GFVariantData.get_option_bool(type_row_result, "success", true):
			return type_row_result
		raw_fields = _get_typed_header_field_array(type_row_result)
		source_records = _drop_first_record(records)
		_drop_first_parse_result_row_location(parse_result)
	else:
		raw_fields = _collect_typed_header_field_names(parse_result, records)

	var schema: GFConfigTableSchema = _make_typed_header_schema(table_name, source.schema_options)
	var field_name_map: Dictionary = {}
	var seen_fields: Dictionary = {}
	for raw_field_name: StringName in raw_fields:
		var header_result: Dictionary = _parse_typed_header_column(raw_field_name)
		if not GFVariantData.get_option_bool(header_result, "success"):
			return header_result

		var column: GFConfigTableColumn = _get_column_from_result(header_result)
		if column == null:
			return _make_typed_header_failure(
				"invalid_typed_header",
				"类型化表头声明无效：%s。" % String(raw_field_name),
				raw_field_name
			)

		var field_name: StringName = column.get_field_key()
		if seen_fields.has(field_name):
			return _make_typed_header_failure(
				"duplicate_typed_header_field",
				"类型化表头声明了重复字段：%s。" % String(field_name),
				raw_field_name
			)

		seen_fields[field_name] = true
		field_name_map[raw_field_name] = field_name
		schema.columns.append(column)

	_remap_parse_result_field_locations(parse_result, field_name_map)
	return {
		"success": true,
		"records": _remap_record_fields(source_records, field_name_map),
		"schema": schema,
	}


func _collect_typed_header_field_names(parse_result: Dictionary, records: Array[Dictionary]) -> Array[StringName]:
	var header_fields: Array[StringName] = _collect_header_field_names(GFVariantData.get_option_value(parse_result, "header"))
	if not header_fields.is_empty():
		return header_fields
	return _collect_record_field_names(records)


func _collect_header_field_names(header_value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen_fields: Dictionary = {}
	if header_value is PackedStringArray:
		var packed_header: PackedStringArray = header_value
		for column_name: String in packed_header:
			_append_header_field_name(result, seen_fields, column_name)
	elif header_value is Array:
		var header_array: Array = header_value
		for column_value: Variant in header_array:
			_append_header_field_name(result, seen_fields, GFVariantData.to_text(column_value))
	return result


func _append_header_field_name(target: Array[StringName], seen_fields: Dictionary, column_name: String) -> void:
	var field_name: StringName = StringName(column_name.strip_edges())
	if field_name == &"" or seen_fields.has(field_name):
		return
	seen_fields[field_name] = true
	target.append(field_name)


func _collect_record_field_names(records: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen_fields: Dictionary = {}
	for record: Dictionary in records:
		for field_key: Variant in record.keys():
			var field_name: StringName = GFVariantData.to_string_name(field_key)
			if field_name == &"" or seen_fields.has(field_name):
				continue
			seen_fields[field_name] = true
			result.append(field_name)
	return result


func _collect_typed_header_type_row_field_names(
	parse_result: Dictionary,
	records: Array[Dictionary]
) -> Dictionary:
	if records.is_empty():
		return _make_typed_header_failure(
			"missing_typed_header_type_row",
			"启用了 typed_header_type_row，但配置表缺少类型行。",
			&""
		)

	var header_fields: Array[StringName] = _collect_header_field_names(GFVariantData.get_option_value(parse_result, "header"))
	if header_fields.is_empty():
		header_fields = _collect_record_field_names(records)
	if header_fields.is_empty():
		return _make_typed_header_failure(
			"missing_typed_header_fields",
			"启用了 typed_header_type_row，但配置表缺少表头字段。",
			&""
		)

	var type_record: Dictionary = records[0]
	var result: Array[StringName] = []
	for raw_field_name: StringName in header_fields:
		var field_text: String = String(raw_field_name).strip_edges()
		if field_text.is_empty():
			continue
		var type_text: String = GFVariantData.to_text(_get_record_field_value(type_record, raw_field_name)).strip_edges()
		if type_text.is_empty():
			result.append(StringName(field_text))
		else:
			result.append(StringName("%s:%s" % [field_text, type_text]))
	return {
		"success": true,
		"fields": result,
	}


func _get_typed_header_field_array(data: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for field_value: Variant in GFVariantData.get_option_array(data, "fields"):
		var field_name: StringName = GFVariantData.to_string_name(field_value)
		if field_name != &"":
			result.append(field_name)
	return result


func _get_record_field_value(record: Dictionary, field_name: StringName) -> Variant:
	if record.has(field_name):
		return record[field_name]
	var field_text: String = String(field_name)
	if record.has(field_text):
		return record[field_text]
	return null


func _drop_first_record(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(1, records.size()):
		result.append(records[index])
	return result


func _drop_first_parse_result_row_location(parse_result: Dictionary) -> void:
	var row_locations_value: Variant = GFVariantData.get_option_value(parse_result, "row_locations", [])
	if not (row_locations_value is Array):
		return
	var row_locations: Array = row_locations_value
	if row_locations.is_empty():
		return
	row_locations.remove_at(0)
	parse_result["row_locations"] = row_locations


func _make_typed_header_schema(table_name: StringName, schema_options: Dictionary) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	schema.id_field = GFVariantData.get_option_string_name(schema_options, "id_field", &"id")
	schema.allow_extra_fields = GFVariantData.get_option_bool(schema_options, "allow_extra_fields", false)
	schema.coerce_values = GFVariantData.get_option_bool(schema_options, "coerce_values", true)
	schema.fail_on_coerce_error = GFVariantData.get_option_bool(schema_options, "fail_on_coerce_error", true)
	schema.require_unique_id = GFVariantData.get_option_bool(schema_options, "require_unique_id", false)
	var uses_type_row: bool = GFVariantData.get_option_bool(schema_options, "typed_header_type_row", false)
	schema.metadata = {
		"schema_source": "typed_header_type_row" if uses_type_row else "typed_headers",
		"header_syntax": "gf.typed_header_type_row.v1" if uses_type_row else "gf.typed_headers.v1",
	}
	return schema


func _parse_typed_header_column(raw_field_name: StringName) -> Dictionary:
	var raw_text: String = String(raw_field_name).strip_edges()
	if raw_text.is_empty():
		return _make_typed_header_failure("empty_typed_header", "类型化表头字段名为空。", raw_field_name)

	var separator_index: int = raw_text.rfind(":")
	var field_text: String = raw_text
	var type_text: String = "any"
	if separator_index >= 0:
		field_text = raw_text.substr(0, separator_index).strip_edges()
		type_text = raw_text.substr(separator_index + 1).strip_edges().to_lower()

	var markers: Dictionary = _strip_typed_header_markers(field_text, type_text)
	field_text = GFVariantData.get_option_string(markers, "field_text")
	type_text = GFVariantData.get_option_string(markers, "type_text", "any")
	if field_text.is_empty():
		return _make_typed_header_failure("empty_typed_header_field", "类型化表头字段名为空：%s。" % raw_text, raw_field_name)

	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = StringName(field_text)
	column.required = GFVariantData.get_option_bool(markers, "required")
	column.allow_null = GFVariantData.get_option_bool(markers, "allow_null", true) and not column.required
	column.metadata = { "source_header": raw_text }
	if not _assign_typed_header_value_type(column, type_text):
		return _make_typed_header_failure(
			"unsupported_typed_header_type",
			"类型化表头字段 %s 使用了不支持的类型：%s。" % [field_text, type_text],
			raw_field_name
		)

	return {
		"success": true,
		"column": column,
		"error": "",
	}


func _strip_typed_header_markers(field_text: String, type_text: String) -> Dictionary:
	var required: bool = false
	var allow_null: bool = true
	while field_text.ends_with("!") or field_text.ends_with("?"):
		if field_text.ends_with("!"):
			required = true
			allow_null = false
		else:
			allow_null = true
		field_text = field_text.substr(0, field_text.length() - 1).strip_edges()
	while type_text.ends_with("!") or type_text.ends_with("?"):
		if type_text.ends_with("!"):
			required = true
			allow_null = false
		else:
			allow_null = true
		type_text = type_text.substr(0, type_text.length() - 1).strip_edges()
	if type_text.is_empty():
		type_text = "any"
	return {
		"field_text": field_text,
		"type_text": type_text,
		"required": required,
		"allow_null": allow_null,
	}


func _assign_typed_header_value_type(column: GFConfigTableColumn, type_text: String) -> bool:
	match type_text:
		"", "any", "variant":
			column.value_type = GFConfigTableColumn.ValueType.ANY
		"bool", "boolean":
			column.value_type = GFConfigTableColumn.ValueType.BOOL
		"int", "integer":
			column.value_type = GFConfigTableColumn.ValueType.INT
		"float", "double", "number":
			column.value_type = GFConfigTableColumn.ValueType.FLOAT
		"string", "str":
			column.value_type = GFConfigTableColumn.ValueType.STRING
		"string_name", "stringname", "name":
			column.value_type = GFConfigTableColumn.ValueType.STRING_NAME
		"vector2", "vec2":
			column.value_type = GFConfigTableColumn.ValueType.VECTOR2
		"vector2i", "vec2i":
			column.value_type = GFConfigTableColumn.ValueType.VECTOR2I
		"color", "colour":
			column.value_type = GFConfigTableColumn.ValueType.COLOR
		"dictionary", "dict", "object":
			column.value_type = GFConfigTableColumn.ValueType.DICTIONARY
		"array", "list":
			column.value_type = GFConfigTableColumn.ValueType.ARRAY
		_:
			return false
	return true


func _remap_record_fields(records: Array[Dictionary], field_name_map: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		var remapped_record: Dictionary = {}
		for field_key: Variant in record.keys():
			var raw_field_name: StringName = GFVariantData.to_string_name(field_key)
			var target_field_name: StringName = GFVariantData.get_option_string_name(field_name_map, raw_field_name, raw_field_name)
			if target_field_name == &"":
				continue
			remapped_record[target_field_name] = GFVariantData.duplicate_variant(record[field_key])
		result.append(remapped_record)
	return result


func _remap_parse_result_field_locations(parse_result: Dictionary, field_name_map: Dictionary) -> void:
	var raw_locations: Variant = GFVariantData.get_option_value(parse_result, "row_locations", [])
	if not (raw_locations is Array):
		return

	var locations: Array = raw_locations
	for row_location_value: Variant in locations:
		if not (row_location_value is Dictionary):
			continue
		var row_location: Dictionary = row_location_value
		var raw_fields: Variant = GFVariantData.get_option_value(row_location, "fields", {})
		if not (raw_fields is Dictionary):
			continue
		var fields: Dictionary = raw_fields
		for raw_key_variant: Variant in field_name_map.keys():
			var raw_field_name: StringName = GFVariantData.to_string_name(raw_key_variant)
			var target_field_name: StringName = GFVariantData.get_option_string_name(field_name_map, raw_field_name, raw_field_name)
			var field_location: Variant = GFVariantData.get_option_value(fields, raw_field_name)
			if not (field_location is Dictionary):
				field_location = GFVariantData.get_option_value(fields, String(raw_field_name))
			if field_location is Dictionary:
				fields[target_field_name] = field_location
				fields[String(target_field_name)] = field_location


func _make_typed_header_failure(
	kind: String,
	message: String,
	raw_field_name: StringName
) -> Dictionary:
	return {
		"success": false,
		"kind": kind,
		"error": message,
		"context": {
			"field": raw_field_name,
			"actual_value": String(raw_field_name),
			"supported_values": PackedStringArray([
				"any",
				"bool",
				"int",
				"float",
				"string",
				"string_name",
				"vector2",
				"vector2i",
				"color",
				"dictionary",
				"array",
			]),
		},
	}


func _coerce_records(records: Array[Dictionary], schema: GFConfigTableSchema) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		result.append(schema.coerce_record(record))
	return result


func _make_table_metadata(source: GFConfigPipelineTableSource, resolved_format: StringName) -> Dictionary:
	var result: Dictionary = source.metadata.duplicate(true)
	result["source_path"] = source.source_path
	result["source_format"] = resolved_format
	return result


func _make_source_map(layout_result: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"source": GFVariantData.get_option_string(layout_result, "source"),
		"row_locations": GFVariantData.duplicate_variant(
			GFVariantData.get_option_value(layout_result, "row_locations", [])
		),
	}
	for key: String in ["header", "sections"]:
		if layout_result.has(key):
			result[key] = GFVariantData.duplicate_variant(layout_result[key])
	return result


func _make_compile_failure(
	table_name: StringName,
	kind: String,
	message: String,
	source_path: String = "",
	resolved_format: StringName = &"",
	context: Dictionary = {}
) -> Dictionary:
	var failure_context: Dictionary = context.duplicate(true)
	if not source_path.is_empty():
		failure_context["source"] = source_path
	var report: Dictionary = GFConfigValidationReport.new().make_error_report(table_name, kind, message, failure_context)
	return {
		"success": false,
		"phase": "validation",
		"ir": null,
		"report": report,
		"source_path": source_path,
		"format": resolved_format,
		"error_kind": kind,
		"error": message,
	}


func _make_records_failure(table_data: Variant) -> Dictionary:
	return {
		"success": false,
		"records": [],
		"actual_value": type_string(typeof(table_data)),
	}


func _get_result_records(result: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var raw_records: Variant = GFVariantData.get_option_value(result, "records", [])
	if not (raw_records is Array):
		return records
	var raw_array: Array = raw_records
	for row_value: Variant in raw_array:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			records.append(row)
	return records


func _get_schema_from_result(result: Dictionary) -> GFConfigTableSchema:
	var schema_value: Variant = GFVariantData.get_option_value(result, "schema")
	if schema_value is GFConfigTableSchema:
		var schema: GFConfigTableSchema = schema_value
		return schema
	return null


func _get_column_from_result(result: Dictionary) -> GFConfigTableColumn:
	var column_value: Variant = GFVariantData.get_option_value(result, "column")
	if column_value is GFConfigTableColumn:
		var column: GFConfigTableColumn = column_value
		return column
	return null
