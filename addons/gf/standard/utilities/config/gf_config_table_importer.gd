## GFConfigTableImporter: 通用导表文本解析与 schema 校验入口。
##
## 提供 JSON、CSV、ConfigFile 与二维文本行的轻量解析，适合编辑器工具或 CI 在进入项目 Provider 前做结构检查。
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


## 把已解析的二维文本表转换为记录数组。
## [br]
## 未显式传 header_row 时，传入 rows 的第一行作为表头；显式传 header_row 时按 1-based 源行号定位表头。可通过注释前缀与条件块过滤行列。
## [br]
## 条件块只支持 `#if SYMBOL ...` 与 `#endif`，所有 SYMBOL 都在 condition_symbols 中时才保留块内数据行。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param rows: 已解析的二维文本行。
## [br]
## @schema rows: Array[PackedStringArray]，每个条目是一行单元格文本。
## [br]
## @param options: 可选参数，支持 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix。
## [br]
## @schema options: Dictionary，可包含 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix。
## [br]
## @return 结果字典，包含 success、data、header、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、header、row_locations、error、error_line、error_column 和 source。
static func parse_rows_table(rows: Array[PackedStringArray], options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var trim_cells: bool = GFVariantData.get_option_bool(options, "trim_cells", true)
	var skip_empty_lines: bool = GFVariantData.get_option_bool(options, "skip_empty_lines", true)
	var reject_duplicate_headers: bool = GFVariantData.get_option_bool(options, "reject_duplicate_headers", true)
	var reject_empty_header: bool = GFVariantData.get_option_bool(options, "reject_empty_header", false)
	var require_header: bool = GFVariantData.get_option_bool(options, "require_header", false)
	var error_prefix: String = GFVariantData.get_option_string(options, "error_prefix", "Table rows")
	var row_numbers: PackedInt32Array = _get_tabular_row_numbers(rows.size(), options)
	var default_header_row_number: int = _get_tabular_row_number(row_numbers, 0)
	var header_row_number: int = maxi(GFVariantData.get_option_int(options, "header_row", default_header_row_number), 1)

	if rows.is_empty():
		if require_header:
			return _make_tabular_parse_failure("%s header row is missing." % error_prefix, source, header_row_number, 1)
		var empty_records: Array[Dictionary] = []
		var empty_locations: Array[Dictionary] = []
		return _make_tabular_parse_success(empty_records, PackedStringArray(), empty_locations, source)

	var base_comment_prefixes: PackedStringArray = _get_string_prefixes(options, "comment_prefixes")
	var comment_row_prefixes: PackedStringArray = _get_string_prefixes(options, "comment_row_prefixes", base_comment_prefixes)
	var comment_column_prefixes: PackedStringArray = _get_string_prefixes(options, "comment_column_prefixes", base_comment_prefixes)
	var comment_prefix_case_sensitive: bool = GFVariantData.get_option_bool(options, "comment_prefix_case_sensitive", false)
	var condition_prefix: String = GFVariantData.get_option_string(options, "condition_directive_prefix", "#")
	if condition_prefix.is_empty():
		condition_prefix = "#"
	var condition_symbols: PackedStringArray = _get_string_prefixes(options, "condition_symbols")
	var enable_condition_directives: bool = GFVariantData.get_option_bool(
		options,
		"enable_condition_directives",
		options.has("condition_symbols")
	)

	var header: PackedStringArray = PackedStringArray()
	var selected_column_indices: PackedInt32Array = PackedInt32Array()
	var records: Array[Dictionary] = []
	var row_locations: Array[Dictionary] = []
	var condition_stack: Array[Dictionary] = []
	var header_found: bool = false
	var source_header_width: int = 0

	for row_array_index: int in range(rows.size()):
		var row_number: int = _get_tabular_row_number(row_numbers, row_array_index)
		var row: PackedStringArray = _prepare_tabular_row(rows[row_array_index], trim_cells)
		if row_number == header_row_number:
			header_found = true
			source_header_width = row.size()
			selected_column_indices = _select_tabular_column_indices(row, comment_column_prefixes, comment_prefix_case_sensitive)
			header = _filter_tabular_row(row, selected_column_indices)
			var header_error: String = _validate_tabular_header(header, reject_duplicate_headers, reject_empty_header, error_prefix)
			if not header_error.is_empty():
				return _make_tabular_parse_failure(header_error, source, row_number, 1)
			continue
		if row_number <= header_row_number:
			continue

		var first_cell: String = row[0] if not row.is_empty() else ""
		if enable_condition_directives:
			var directive: Dictionary = _parse_condition_directive(first_cell, condition_prefix)
			var directive_kind: StringName = GFVariantData.get_option_string_name(directive, "kind")
			if directive_kind == &"if":
				condition_stack.append({
					"active": _condition_symbols_match(
						GFVariantData.get_option_packed_string_array(directive, "symbols"),
						condition_symbols
					),
					"line": row_number,
				})
				continue
			if directive_kind == &"endif":
				if condition_stack.is_empty():
					return _make_tabular_parse_failure("%s parse failed: unexpected_condition_end" % error_prefix, source, row_number, 1)
				condition_stack.pop_back()
				continue

		if not _condition_stack_is_active(condition_stack):
			continue
		if skip_empty_lines and _tabular_row_is_empty(row):
			continue
		if _text_has_prefix(first_cell, comment_row_prefixes, comment_prefix_case_sensitive):
			continue
		if row.size() > source_header_width:
			return _make_tabular_parse_failure("%s parse failed: row_has_extra_cells" % error_prefix, source, row_number, source_header_width + 1)

		var record: Dictionary = {}
		for column_index: int in range(header.size()):
			var key: StringName = StringName(header[column_index])
			if key == &"":
				continue
			var source_column_index: int = selected_column_indices[column_index]
			record[key] = row[source_column_index] if source_column_index < row.size() else ""
		records.append(record)
		row_locations.append(_make_tabular_row_location(source, row_number, records.size() - 1, header, selected_column_indices))

	if not header_found and require_header:
		return _make_tabular_parse_failure("%s header row is missing." % error_prefix, source, header_row_number, 1)
	if not condition_stack.is_empty():
		var condition_info: Dictionary = condition_stack[condition_stack.size() - 1]
		return _make_tabular_parse_failure(
			"%s parse failed: missing_condition_end" % error_prefix,
			source,
			GFVariantData.get_option_int(condition_info, "line", rows.size()),
			1
		)

	return _make_tabular_parse_success(records, header, row_locations, source)


## 解析 CSV 表文本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param text: CSV 文本。
## [br]
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix、source。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。
## [br]
## @return 结果字典，包含 success、data、header、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、header、row_locations、error、error_line、error_column 和 source。
static func parse_csv_table(text: String, options: Dictionary = {}) -> Dictionary:
	var delimiter: String = GFVariantData.get_option_string(options, "delimiter", ",")
	if delimiter.is_empty():
		delimiter = ","
	var trim_cells: bool = GFVariantData.get_option_bool(options, "trim_cells", true)
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
	var row_options: Dictionary = options.duplicate(true)
	row_options["source"] = source
	row_options["error_prefix"] = "CSV"
	return parse_rows_table(rows, row_options)


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
## @since 3.17.0
## [br]
## @param text: CSV 文本。
## [br]
## @param schema: 表结构声明。
## [br]
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。
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


static func _get_tabular_row_numbers(row_count: int, options: Dictionary) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(options, "row_numbers")
	if value is PackedInt32Array:
		var packed: PackedInt32Array = value
		return packed if packed.size() == row_count else PackedInt32Array()
	if not value is Array:
		return PackedInt32Array()

	var rows: Array = value
	if rows.size() != row_count:
		return PackedInt32Array()

	var result: PackedInt32Array = PackedInt32Array()
	for row_value: Variant in rows:
		var _row_number_appended: bool = result.append(GFVariantData.to_int(row_value, result.size() + 1))
	return result


static func _get_tabular_row_number(row_numbers: PackedInt32Array, row_array_index: int) -> int:
	if row_array_index >= 0 and row_array_index < row_numbers.size():
		return row_numbers[row_array_index]
	return row_array_index + 1


static func _get_string_prefixes(
	options: Dictionary,
	key: String,
	default_value: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	return GFVariantData.get_option_packed_string_array(options, key, default_value)


static func _prepare_tabular_row(row: PackedStringArray, trim_cells: bool) -> PackedStringArray:
	if not trim_cells:
		return row

	var result: PackedStringArray = PackedStringArray()
	for cell: String in row:
		var _cell_appended: bool = result.append(cell.strip_edges())
	return result


static func _select_tabular_column_indices(
	header: PackedStringArray,
	comment_column_prefixes: PackedStringArray,
	case_sensitive: bool
) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for column_index: int in range(header.size()):
		if _text_has_prefix(header[column_index], comment_column_prefixes, case_sensitive):
			continue
		var _column_appended: bool = result.append(column_index)
	return result


static func _filter_tabular_row(row: PackedStringArray, column_indices: PackedInt32Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for column_index: int in column_indices:
		var _cell_appended: bool = result.append(row[column_index] if column_index < row.size() else "")
	return result


static func _validate_tabular_header(
	header: PackedStringArray,
	reject_duplicate_headers: bool,
	reject_empty_header: bool,
	error_prefix: String
) -> String:
	var has_named_column: bool = false
	var seen: Dictionary = {}
	for column_name: String in header:
		if column_name.is_empty():
			continue
		has_named_column = true
		if reject_duplicate_headers and seen.has(column_name):
			return "%s header has duplicate column: %s" % [error_prefix, column_name]
		seen[column_name] = true
	if reject_empty_header and not has_named_column:
		return "%s header row is empty." % error_prefix
	return ""


static func _make_tabular_parse_success(
	records: Array[Dictionary],
	header: PackedStringArray,
	row_locations: Array[Dictionary],
	source: String
) -> Dictionary:
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


static func _make_tabular_parse_failure(
	error: String,
	source: String,
	line_number: int,
	column_number: int
) -> Dictionary:
	return {
		"success": false,
		"data": null,
		"header": PackedStringArray(),
		"row_locations": [],
		"error": error,
		"error_line": line_number,
		"error_column": column_number,
		"source": source,
	}


static func _parse_condition_directive(first_cell: String, directive_prefix: String) -> Dictionary:
	var text: String = first_cell.strip_edges()
	if directive_prefix.is_empty() or not text.begins_with(directive_prefix):
		return { "kind": &"none" }

	var payload: String = text.substr(directive_prefix.length()).strip_edges()
	if payload == "endif":
		return { "kind": &"endif" }
	if payload == "if":
		return {
			"kind": &"if",
			"symbols": PackedStringArray(),
		}
	if not payload.begins_with("if "):
		return { "kind": &"none" }

	var symbols: PackedStringArray = PackedStringArray()
	for token: String in payload.substr(3).split(" ", false):
		var symbol: String = token.strip_edges()
		if symbol.is_empty():
			continue
		var _symbol_appended: bool = symbols.append(symbol)
	return {
		"kind": &"if",
		"symbols": symbols,
	}


static func _condition_symbols_match(required_symbols: PackedStringArray, active_symbols: PackedStringArray) -> bool:
	for symbol: String in required_symbols:
		if not active_symbols.has(symbol):
			return false
	return true


static func _condition_stack_is_active(condition_stack: Array[Dictionary]) -> bool:
	for condition_info: Dictionary in condition_stack:
		if not GFVariantData.get_option_bool(condition_info, "active"):
			return false
	return true


static func _tabular_row_is_empty(row: PackedStringArray) -> bool:
	for cell: String in row:
		if not cell.strip_edges().is_empty():
			return false
	return true


static func _text_has_prefix(text: String, prefixes: PackedStringArray, case_sensitive: bool) -> bool:
	if prefixes.is_empty():
		return false

	var checked_text: String = text if case_sensitive else text.to_lower()
	for prefix: String in prefixes:
		if prefix.is_empty():
			continue
		var checked_prefix: String = prefix if case_sensitive else prefix.to_lower()
		if checked_text.begins_with(checked_prefix):
			return true
	return false


static func _make_tabular_row_location(
	source: String,
	line_number: int,
	row_index: int,
	header: PackedStringArray,
	column_indices: PackedInt32Array
) -> Dictionary:
	var fields: Dictionary = {}
	for column_index: int in range(header.size()):
		var key: StringName = StringName(header[column_index])
		if key == &"":
			continue
		var source_column_index: int = column_indices[column_index]
		var field_location: Dictionary = {
			"line": line_number,
			"column": source_column_index + 1,
			"column_index": source_column_index,
		}
		if not source.is_empty():
			field_location["source"] = source
		fields[key] = field_location
		fields[String(key)] = field_location

	var row_location: Dictionary = {
		"line": line_number,
		"row_index": row_index,
		"fields": fields,
	}
	if not source.is_empty():
		row_location["source"] = source
	return row_location


static func _copy_dictionary_rows(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var rows: Array = value
	for row_value: Variant in rows:
		if row_value is Dictionary:
			result.append(GFVariantData.to_dictionary(row_value))
	return result


static func _csv_row_is_empty(row: PackedStringArray) -> bool:
	for cell: String in row:
		if not cell.strip_edges().is_empty():
			return false
	return true


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
