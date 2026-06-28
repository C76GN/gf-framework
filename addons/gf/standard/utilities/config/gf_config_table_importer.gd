## GFConfigTableImporter: 通用导表文本解析与 schema 校验入口。
##
## 提供 JSON、CSV 与 ConfigFile 的轻量解析，适合编辑器工具或 CI 在进入项目 Provider 前做结构检查。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFConfigTableImporter
extends RefCounted


# --- 常量 ---

# --- 公共方法 ---

## 解析 JSON 表文本。
## [br]
## @api public
## [br]
## @param text: JSON 文本。
## [br]
## @param options: 可选参数，支持 source。
## [br]
## @schema options: Dictionary，可包含 source。
## [br]
## @return 结果字典，包含 success、data、error、error_line 与 source。
## [br]
## @schema return: Dictionary，包含 success、data、error、error_line 和 source。
static func parse_json_table(text: String, options: Dictionary = {}) -> Dictionary:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return {
			"success": false,
			"data": null,
			"error": "JSON parse failed: %s" % json.get_error_message(),
			"error_line": json.get_error_line(),
			"source": GFVariantData.get_option_string(options, "source"),
		}

	return {
		"success": true,
		"data": json.data,
		"error": "",
		"error_line": 0,
		"source": GFVariantData.get_option_string(options, "source"),
	}


## 解析 CSV 表文本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param text: CSV 文本。
## [br]
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、source。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers 和 source。
## [br]
## @return 结果字典，包含 success、data、header、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、header、row_locations、error、error_line、error_column 和 source。
static func parse_csv_table(text: String, options: Dictionary = {}) -> Dictionary:
	var delimiter: String = GFVariantData.get_option_string(options, "delimiter", ",")
	if delimiter.is_empty():
		delimiter = ","
	var trim_cells: bool = GFVariantData.get_option_bool(options, "trim_cells", true)
	var skip_empty_lines: bool = GFVariantData.get_option_bool(options, "skip_empty_lines", true)
	var reject_duplicate_headers: bool = GFVariantData.get_option_bool(options, "reject_duplicate_headers", true)
	var source: String = GFVariantData.get_option_string(options, "source")
	var parse_result: Dictionary = _parse_csv_rows(_normalize_csv_text(text), delimiter.substr(0, 1), trim_cells)
	if not GFVariantData.get_option_bool(parse_result, "success"):
		return {
			"success": false,
			"data": null,
			"header": PackedStringArray(),
			"row_locations": [],
			"error": GFVariantData.get_option_string(parse_result, "error"),
			"error_line": GFVariantData.get_option_int(parse_result, "error_line"),
			"error_column": GFVariantData.get_option_int(parse_result, "error_column"),
			"source": source,
		}

	var rows: Array[PackedStringArray] = _get_parse_rows(parse_result)
	if rows.is_empty():
		return {
			"success": true,
			"data": [],
			"header": PackedStringArray(),
			"row_locations": [],
			"error": "",
			"error_line": 0,
			"error_column": 0,
			"source": source,
	}

	var header: PackedStringArray = rows[0]
	var header_error: String = _validate_csv_header(header, reject_duplicate_headers)
	if not header_error.is_empty():
		return {
			"success": false,
			"data": null,
			"header": header,
			"row_locations": [],
			"error": header_error,
			"error_line": 1,
			"error_column": 1,
			"source": source,
		}

	var records: Array[Dictionary] = []
	var row_locations: Array[Dictionary] = []
	for row_index: int in range(1, rows.size()):
		var row: PackedStringArray = rows[row_index]
		if skip_empty_lines and _csv_row_is_empty(row):
			continue
		if row.size() > header.size():
			return {
				"success": false,
				"data": null,
				"header": header,
				"row_locations": [],
				"error": "CSV parse failed: row_has_extra_cells",
				"error_line": row_index + 1,
				"error_column": header.size() + 1,
				"source": source,
			}

		var record: Dictionary = {}
		var row_location: Dictionary = _make_csv_row_location(source, row_index + 1, header)
		for column_index: int in range(header.size()):
			var key: StringName = StringName(header[column_index])
			if key == &"":
				continue
			record[key] = row[column_index] if column_index < row.size() else ""
		records.append(record)
		row_locations.append(row_location)

	return {
		"success": true,
		"data": records,
		"header": header,
		"row_locations": row_locations,
		"error": "",
		"error_line": 0,
		"error_column": 0,
		"source": source,
	}


## 解析 Godot ConfigFile 表文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: ConfigFile 文本。
## [br]
## @param options: 可选参数，支持 source、section_field、include_empty_sections。
## [br]
## @schema options: Dictionary，可包含 source、section_field、include_empty_sections 字段；section_field 为空 StringName 时不写入 section 名字段。
## [br]
## @return 结果字典，包含 success、data、sections、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、sections、row_locations、error、error_line、error_column 和 source。
static func parse_config_file_table(text: String, options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var config_file: ConfigFile = ConfigFile.new()
	var parse_error: Error = config_file.parse(_normalize_config_file_text(text))
	if parse_error != OK:
		return {
			"success": false,
			"data": null,
			"sections": PackedStringArray(),
			"row_locations": [],
			"error": "ConfigFile parse failed: %s" % error_string(parse_error),
			"error_line": 0,
			"error_column": 0,
			"source": source,
		}

	var section_field: StringName = GFVariantData.get_option_string_name(options, "section_field", &"entry_name")
	var include_empty_sections: bool = GFVariantData.get_option_bool(options, "include_empty_sections", true)
	var sections: PackedStringArray = config_file.get_sections()
	sections.sort()
	var records: Array[Dictionary] = []
	var row_locations: Array[Dictionary] = []
	for section: String in sections:
		var keys: PackedStringArray = config_file.get_section_keys(section)
		keys.sort()
		if keys.is_empty() and not include_empty_sections:
			continue

		var record: Dictionary = {}
		var row_location: Dictionary = _make_config_file_row_location(
			source,
			records.size(),
			section,
			section_field,
			keys
		)
		if section_field != &"":
			record[section_field] = section
		for key: String in keys:
			record[StringName(key)] = config_file.get_value(section, key)
		records.append(record)
		row_locations.append(row_location)

	return {
		"success": true,
		"data": records,
		"sections": sections,
		"row_locations": row_locations,
		"error": "",
		"error_line": 0,
		"error_column": 0,
		"source": source,
	}


## 解析并校验 JSON 表文本。
## [br]
## @api public
## [br]
## @param text: JSON 文本。
## [br]
## @param schema: 表结构声明。
## [br]
## @param options: 可选参数，支持 source。
## [br]
## @schema options: Dictionary，可包含 source。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_json_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
	if schema == null:
		return _make_error_report(&"", "missing_schema", "schema 为空。")

	var parsed: Dictionary = parse_json_table(text, options)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(schema.get_table_key(), "parse_failed", _get_parse_error(parsed), {
			"source": _get_parse_source(parsed),
			"line": _get_parse_error_line(parsed),
		})
	return schema.validate_table(_get_parse_data(parsed), _make_validation_options(options, parsed))


## 解析并校验 JSON 单记录文本。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param text: JSON 文本，根节点必须是 Dictionary。
## [br]
## @param schema: 表结构声明；当前方法复用其字段声明校验单条记录。
## [br]
## @param row_key: 可选行标识；为空且 schema 声明了 id_field 时会尝试从记录字段读取。
## [br]
## @schema row_key: Variant，写入校验报告 issue 的行标识。
## [br]
## @param options: 可选参数，支持 source。
## [br]
## @schema options: Dictionary，可包含 source。
## [br]
## @return 校验报告；解析失败或根节点不是 Dictionary 时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_json_record(
	text: String,
	schema: GFConfigTableSchema,
	row_key: Variant = null,
	options: Dictionary = {}
) -> Dictionary:
	if schema == null:
		return _make_error_report(&"", "missing_schema", "schema 为空。")

	var parsed: Dictionary = parse_json_table(text, options)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(schema.get_table_key(), "parse_failed", _get_parse_error(parsed), {
			"source": _get_parse_source(parsed),
			"line": _get_parse_error_line(parsed),
		})

	var data: Variant = _get_parse_data(parsed)
	if not (data is Dictionary):
		return _make_error_report(schema.get_table_key(), "invalid_json_record", "JSON 记录根节点必须是 Dictionary。", {
			"source": _get_parse_source(parsed),
			"value": GFVariantData.duplicate_variant(data),
			"actual_value": type_string(typeof(data)),
			"expected_value": "Dictionary",
			"supported_formats": ["JSON object"],
		})

	var record: Dictionary = GFVariantData.as_dictionary(data)
	var resolved_row_key: Variant = row_key
	if resolved_row_key == null and schema.id_field != &"":
		resolved_row_key = GFVariantData.get_option_value(record, schema.id_field)
	return schema.validate_record(record, resolved_row_key, _make_validation_options(options, parsed))


## 解析并校验 CSV 表文本。
## [br]
## @api public
## [br]
## @param text: CSV 文本。
## [br]
## @param schema: 表结构声明。
## [br]
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、source。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers 和 source。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_csv_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
	if schema == null:
		return _make_error_report(&"", "missing_schema", "schema 为空。")

	var parsed: Dictionary = parse_csv_table(text, options)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(schema.get_table_key(), "parse_failed", _get_parse_error(parsed), {
			"source": _get_parse_source(parsed),
			"line": _get_parse_error_line(parsed),
			"column": _get_parse_error_column(parsed),
		})
	return schema.validate_table(_get_parse_data(parsed), _make_validation_options(options, parsed))


## 解析并校验 Godot ConfigFile 表文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: ConfigFile 文本。
## [br]
## @param schema: 表结构声明。
## [br]
## @param options: 可选参数，支持 source、section_field、include_empty_sections。
## [br]
## @schema options: Dictionary，可包含 source、section_field 和 include_empty_sections 字段。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_config_file_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
	if schema == null:
		return _make_error_report(&"", "missing_schema", "schema 为空。")

	var parsed: Dictionary = parse_config_file_table(text, options)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(schema.get_table_key(), "parse_failed", _get_parse_error(parsed), {
			"source": _get_parse_source(parsed),
			"line": _get_parse_error_line(parsed),
			"column": _get_parse_error_column(parsed),
		})
	return schema.validate_table(_get_parse_data(parsed), _make_validation_options(options, parsed))


## 导出 CSV 表文本。
## [br]
## @api public
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param schema: 可选 schema；提供时默认按 schema.columns 排列列。
## [br]
## @param options: 可选参数，支持 delimiter、columns、include_header、coerce_values。
## [br]
## @schema options: Dictionary，可包含 delimiter、columns、include_header 和 coerce_values。
## [br]
## @return 结果字典，包含 success、text 与 error。
## [br]
## @schema return: Dictionary，包含 success、text 和 error。
static func export_csv_table(
	table_data: Variant,
	schema: GFConfigTableSchema = null,
	options: Dictionary = {}
) -> Dictionary:
	var normalized_rows: Dictionary = _normalize_table_rows(table_data)
	if not GFVariantData.get_option_bool(normalized_rows, "success"):
		return {
			"success": false,
			"text": "",
			"error": "table_data must be Array[Dictionary] or Dictionary.",
		}
	var rows: Array[Dictionary] = _copy_dictionary_rows(GFVariantData.get_option_value(normalized_rows, "rows", []))

	var delimiter: String = GFVariantData.get_option_string(options, "delimiter", ",")
	if delimiter.is_empty():
		delimiter = ","
	delimiter = delimiter.substr(0, 1)
	var columns: PackedStringArray = _resolve_export_columns(rows, schema, options)
	var lines: PackedStringArray = PackedStringArray()
	if GFVariantData.get_option_bool(options, "include_header", true):
		var _header_appended: bool = lines.append(_join_csv_row(columns, delimiter))

	var coerce_values: bool = GFVariantData.get_option_bool(options, "coerce_values", schema != null and schema.coerce_values)
	for row: Dictionary in rows:
		var record: Dictionary = schema.coerce_record(row) if coerce_values and schema != null else row
		var cells: PackedStringArray = PackedStringArray()
		for column_name: String in columns:
			var _cell_appended: bool = cells.append(_format_csv_cell(
				GFVariantData.get_option_value(record, StringName(column_name), ""),
				delimiter
			))
		var _line_appended: bool = lines.append(delimiter.join(cells))

	return {
		"success": true,
		"text": "\n".join(lines),
		"error": "",
	}


# --- 私有/辅助方法 ---

static func _get_parse_data(parsed: Dictionary) -> Variant:
	return GFVariantData.get_option_value(parsed, "data")


static func _get_parse_error(parsed: Dictionary) -> String:
	return GFVariantData.get_option_string(parsed, "error")


static func _get_parse_source(parsed: Dictionary) -> String:
	return GFVariantData.get_option_string(parsed, "source")


static func _get_parse_error_line(parsed: Dictionary) -> int:
	return GFVariantData.get_option_int(parsed, "error_line")


static func _get_parse_error_column(parsed: Dictionary) -> int:
	return GFVariantData.get_option_int(parsed, "error_column")


static func _get_parse_row_locations(parsed: Dictionary) -> Variant:
	return GFVariantData.get_option_value(parsed, "row_locations")


static func _parse_csv_rows(text: String, delimiter: String, trim_cells: bool) -> Dictionary:
	var rows: Array[PackedStringArray] = []
	var row: PackedStringArray = PackedStringArray()
	var cell: String = ""
	var in_quotes: bool = false
	var quote_closed: bool = false
	var quote_start_line: int = 1
	var quote_start_column: int = 1
	var index: int = 0
	var line: int = 1
	var column: int = 1

	while index < text.length():
		var ch: String = text.substr(index, 1)
		if in_quotes:
			if ch == "\"":
				if index + 1 < text.length() and text.substr(index + 1, 1) == "\"":
					cell += "\""
					index += 1
				else:
					in_quotes = false
					quote_closed = true
			else:
				cell += ch
				if ch == "\n":
					line += 1
					column = 0
		else:
			if quote_closed:
				if ch == delimiter:
					var _closed_delimiter_cell_appended: bool = row.append(cell.strip_edges() if trim_cells else cell)
					cell = ""
					quote_closed = false
				elif ch == "\n":
					var _closed_newline_cell_appended: bool = row.append(cell.strip_edges() if trim_cells else cell)
					rows.append(row)
					row = PackedStringArray()
					cell = ""
					quote_closed = false
					line += 1
					column = 0
				elif ch == "\r" or (trim_cells and (ch == " " or ch == "\t")):
					pass
				else:
					return {
						"success": false,
						"rows": rows,
						"error": "CSV parse failed: malformed_quote",
						"error_line": line,
						"error_column": column,
					}
			elif ch == "\"":
				if not cell.is_empty() and (not trim_cells or not cell.strip_edges().is_empty()):
					return {
						"success": false,
						"rows": rows,
						"error": "CSV parse failed: malformed_quote",
						"error_line": line,
						"error_column": column,
					}
				cell = ""
				in_quotes = true
				quote_start_line = line
				quote_start_column = column
			elif ch == delimiter:
				var _delimiter_cell_appended: bool = row.append(cell.strip_edges() if trim_cells else cell)
				cell = ""
				quote_closed = false
			elif ch == "\n":
				var _newline_cell_appended: bool = row.append(cell.strip_edges() if trim_cells else cell)
				rows.append(row)
				row = PackedStringArray()
				cell = ""
				quote_closed = false
				line += 1
				column = 0
			elif ch != "\r":
				cell += ch
		index += 1
		column += 1

	if in_quotes:
		return {
			"success": false,
			"rows": rows,
			"error": "CSV parse failed: unclosed_quote",
			"error_line": quote_start_line,
			"error_column": quote_start_column,
		}

	var _final_cell_appended: bool = row.append(cell.strip_edges() if trim_cells else cell)
	if row.size() > 1 or not _csv_row_is_empty(row):
		rows.append(row)
	return {
		"success": true,
		"rows": rows,
		"error": "",
		"error_line": 0,
		"error_column": 0,
	}


static func _normalize_csv_text(text: String) -> String:
	return text.trim_prefix("\ufeff")


static func _normalize_config_file_text(text: String) -> String:
	return text.trim_prefix("\ufeff")


static func _get_parse_rows(parse_result: Dictionary) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var rows_value: Variant = GFVariantData.get_option_value(parse_result, "rows", [])
	if not rows_value is Array:
		return result
	for row_value: Variant in rows_value:
		if row_value is PackedStringArray:
			var row: PackedStringArray = row_value
			result.append(row)
	return result


static func _copy_dictionary_rows(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var rows: Array = value
	for row_value: Variant in rows:
		if row_value is Dictionary:
			result.append(GFVariantData.to_dictionary(row_value))
	return result


static func _validate_csv_header(header: PackedStringArray, reject_duplicate_headers: bool) -> String:
	if not reject_duplicate_headers:
		return ""

	var seen: Dictionary = {}
	for column_name: String in header:
		if column_name.is_empty():
			continue
		if seen.has(column_name):
			return "CSV header has duplicate column: %s" % column_name
		seen[column_name] = true
	return ""


static func _csv_row_is_empty(row: PackedStringArray) -> bool:
	for cell: String in row:
		if not cell.strip_edges().is_empty():
			return false
	return true


static func _make_csv_row_location(source: String, line_number: int, header: PackedStringArray) -> Dictionary:
	var fields: Dictionary = {}
	for column_index: int in range(header.size()):
		var key: StringName = StringName(header[column_index])
		if key == &"":
			continue
		var field_location: Dictionary = {
			"line": line_number,
			"column": column_index + 1,
			"column_index": column_index,
		}
		if not source.is_empty():
			field_location["source"] = source
		fields[key] = field_location
		fields[String(key)] = field_location

	var row_location: Dictionary = {
		"line": line_number,
		"row_index": line_number - 2,
		"fields": fields,
	}
	if not source.is_empty():
		row_location["source"] = source
	return row_location


static func _make_config_file_row_location(
	source: String,
	row_index: int,
	section: String,
	section_field: StringName,
	keys: PackedStringArray
) -> Dictionary:
	var fields: Dictionary = {}
	if section_field != &"":
		var section_location: Dictionary = _make_config_file_field_location(source, row_index, section)
		fields[section_field] = section_location
		fields[String(section_field)] = section_location
	for key: String in keys:
		var field_name: StringName = StringName(key)
		var field_location: Dictionary = _make_config_file_field_location(source, row_index, section)
		fields[field_name] = field_location
		fields[key] = field_location

	var row_location: Dictionary = {
		"row_index": row_index,
		"section": section,
		"fields": fields,
	}
	if not source.is_empty():
		row_location["source"] = source
	return row_location


static func _make_config_file_field_location(source: String, row_index: int, section: String) -> Dictionary:
	var location: Dictionary = {
		"row_index": row_index,
		"section": section,
	}
	if not source.is_empty():
		location["source"] = source
	return location


static func _make_error_report(
	table_name: StringName,
	kind: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	return GFConfigValidationReport.new().make_error_report(table_name, kind, message, context)


static func _make_validation_options(options: Dictionary, parsed: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	if parsed.has("source") and not GFVariantData.get_option_string(parsed, "source").is_empty():
		result["source"] = _get_parse_source(parsed)
	if parsed.has("row_locations"):
		result["row_locations"] = _get_parse_row_locations(parsed)
	return result


static func _normalize_table_rows(table_data: Variant) -> Dictionary:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		for row_variant: Variant in table_data:
			if not (row_variant is Dictionary):
				return {
					"success": false,
					"rows": rows,
				}
			rows.append(GFVariantData.to_dictionary(row_variant))
		return {
			"success": true,
			"rows": rows,
		}
	if table_data is Dictionary:
		var table: Dictionary = GFVariantData.to_dictionary(table_data)
		var keys: Array = table.keys()
		keys.sort()
		for key: Variant in keys:
			var row_variant: Variant = table[key]
			if not (row_variant is Dictionary):
				return {
					"success": false,
					"rows": rows,
				}
			rows.append(GFVariantData.to_dictionary(row_variant))
		return {
			"success": true,
			"rows": rows,
		}
	return {
		"success": false,
		"rows": rows,
	}


static func _resolve_export_columns(
	rows: Array[Dictionary],
	schema: GFConfigTableSchema,
	options: Dictionary
) -> PackedStringArray:
	if options.has("columns"):
		return GFVariantData.get_option_packed_string_array(options, "columns")
	if schema != null:
		var schema_columns: PackedStringArray = schema.get_column_names()
		if not schema_columns.is_empty():
			return schema_columns

	var seen: Dictionary = {}
	for row: Dictionary in rows:
		for key: Variant in row.keys():
			seen[GFVariantData.to_text(key)] = true
	var result: PackedStringArray = PackedStringArray()
	for key_text: String in seen.keys():
		var _key_appended: bool = result.append(key_text)
	result.sort()
	return result


static func _join_csv_row(cells: PackedStringArray, delimiter: String) -> String:
	var escaped: PackedStringArray = PackedStringArray()
	for cell: String in cells:
		var _cell_appended: bool = escaped.append(_format_csv_cell(cell, delimiter))
	return delimiter.join(escaped)


static func _format_csv_cell(value: Variant, delimiter: String) -> String:
	var text: String = str(value)
	var needs_quotes: bool = text.contains(delimiter) or text.contains("\n") or text.contains("\r") or text.contains("\"")
	text = text.replace("\"", "\"\"")
	return "\"%s\"" % text if needs_quotes else text
