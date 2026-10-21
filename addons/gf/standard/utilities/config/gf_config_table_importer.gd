## GFConfigTableImporter: 通用导表文本解析与 schema 校验入口。
##
## 提供 JSON、CSV、ConfigFile 与二维文本行的轻量解析，适合编辑器工具或 CI 在进入项目 Provider 前做结构检查。
## 每个顶层操作默认使用有限的 GFConfigWorkBudget；解析、映射和校验共享同一预算。
## 输入按 UTF-8 字节计量，文本每扫描 1024 个字符消耗一个工作单元，表格处理另按单元格和比较次数计量。
## JSON 与 ConfigFile 原生解析调用不可硬中断；容量和文本嵌套检查在调用前完成，解析结果随后通过值图准入。
## JSON 根容器深度为零；ConfigFile 另保守限制构造器嵌套，最终深度按映射出的记录数组计量。
## schema 校验前按记录、字段和声明规则访问次数预留工作；自定义规则及原生方法不提供可抢占执行保证。
## 解析预算失败保留本次调用的 source，便于定位输入；data 为空，不交付部分解析结果。
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
## @since 3.17.0
## [br]
## @param text: JSON 文本。
## [br]
## @param options: 可选参数，支持 source；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 结果字典，包含 success、data、error、error_line 与 source。
## [br]
## @schema return: Dictionary，包含 success、data、error、error_line 和 source；预算失败另含 error_kind 和 budget_report，且不返回部分 data 或 text。
static func parse_json_table(text: String, options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not _admit_text(
		text,
		budget,
		"JSON",
		true
	):
		return _make_budget_parse_failure(budget, source)
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return {
			"success": false,
			"data": null,
			"error": "JSON parse failed: %s" % json.get_error_message(),
			"error_line": json.get_error_line(),
			"source": source,
		}
	if not budget.admit_value(json.data, "JSON parsed value"):
		return _make_budget_parse_failure(budget, source)
	return {
		"success": true,
		"data": json.data,
		"error": "",
		"error_line": 0,
		"source": source,
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
## @param options: 可选参数，支持 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 结果字典，包含 success、data、header、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、header、header_location、row_locations、error、error_line、error_column 和 source；header_location 记录真实表头行及字段原始列，空表时可为空；预算失败另含 error_kind 和 budget_report，且不返回部分 data 或 text。
static func parse_rows_table(rows: Array[PackedStringArray], options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not budget.admit_value(rows, "tabular input"):
		return _make_budget_parse_failure(budget, source)
	for row: PackedStringArray in rows:
		for cell: String in row:
			if not _admit_text(
				cell,
				budget,
				"tabular cell"
			):
				return _make_budget_parse_failure(budget, source)
	return _parse_rows_table(
		rows,
		options,
		budget
	)


## 解析 CSV 表文本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param text: CSV 文本。
## [br]
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix、source；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 结果字典，包含 success、data、header、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、header、header_location、row_locations、error、error_line、error_column 和 source；header_location 记录真实表头行及字段原始列，空表时可为空；预算失败另含 error_kind 和 budget_report，且不返回部分 data 或 text。
static func parse_csv_table(text: String, options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not _admit_text(
		text,
		budget,
		"CSV"
	):
		return _make_budget_parse_failure(budget, source)
	var delimiter: String = GFVariantData.get_option_string(
		options,
		"delimiter",
		","
	)
	if delimiter.is_empty():
		delimiter = ","
	var trim_cells: bool = GFVariantData.get_option_bool(
		options,
		"trim_cells",
		true
	)
	var parse_result: Dictionary = _parse_csv_rows(
		_normalize_csv_text(text),
		delimiter.substr(0, 1),
		trim_cells,
		budget
	)
	if not budget.is_ok():
		return _make_budget_parse_failure(budget, source)
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
	var row_options: Dictionary = _make_budget_options(options, budget)
	row_options["source"] = source
	row_options["error_prefix"] = "CSV"
	row_options["row_numbers"] = _get_parse_row_numbers(parse_result)
	return _parse_rows_table(
		rows,
		row_options,
		budget
	)


## 解析 Godot ConfigFile 表文本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param text: ConfigFile 文本。
## [br]
## @param options: 可选参数，支持 source、section_field、include_empty_sections；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source、section_field、include_empty_sections 字段；section_field 为空 StringName 时不写入 section 名字段；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 结果字典，包含 success、data、sections、row_locations 与 error。
## [br]
## @schema return: Dictionary，包含 success、data、sections、row_locations、error、error_line、error_column 和 source；预算失败另含 error_kind 和 budget_report，且不返回部分 data 或 text。
static func parse_config_file_table(text: String, options: Dictionary = {}) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not _admit_text(
		text,
		budget,
		"ConfigFile",
		true,
		true
	):
		return _make_budget_parse_failure(budget, source)
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

	var section_field: StringName = GFVariantData.get_option_string_name(
		options,
		"section_field",
		&"entry_name"
	)
	var include_empty_sections: bool = GFVariantData.get_option_bool(
		options,
		"include_empty_sections",
		true
	)
	var sections: PackedStringArray = config_file.get_sections()
	if not budget.admit_value(sections, "ConfigFile sections") or not budget.consume_work(
		sections.size(),
		"ConfigFile section ordering"
	):
		return _make_budget_parse_failure(budget, source)
	sections.sort()
	var records: Array[Dictionary] = []
	var row_locations: Array[Dictionary] = []
	for section: String in sections:
		var keys: PackedStringArray = config_file.get_section_keys(section)
		if not budget.admit_value(keys, "ConfigFile keys") or not budget.consume_work(
			keys.size() * 3 + 1,
			"ConfigFile record mapping"
		):
			return _make_budget_parse_failure(budget, source)
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
			var value: Variant = config_file.get_value(section, key)
			if not budget.admit_value(value, "ConfigFile value"):
				return _make_budget_parse_failure(budget, source)
			record[StringName(key)] = value
		records.append(record)
		row_locations.append(row_location)

	if not budget.admit_value(records, "ConfigFile mapped records"):
		return _make_budget_parse_failure(budget, source)
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
## @since 3.17.0
## [br]
## @param text: JSON 文本。
## [br]
## @param schema: 表结构声明。
## [br]
## @param options: 可选参数，支持 source；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_json_table(
	text: String,
	schema: GFConfigTableSchema,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget):
		return _make_budget_validation_failure(budget, schema)
	var shared_options: Dictionary = _make_budget_options(options, budget)
	if schema == null:
		return _make_error_report(
			&"",
			"missing_schema",
			"schema 为空。"
		)

	var parsed: Dictionary = parse_json_table(text, shared_options)
	if not budget.is_ok():
		return _make_budget_validation_failure(budget, schema)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(
			schema.get_table_key(),
			"parse_failed",
			_get_parse_error(parsed),
			{ "source": _get_parse_source(parsed), "line": _get_parse_error_line(parsed), }
		)
	var data: Variant = _get_parse_data(parsed)
	var validation_options: Dictionary = _make_validation_options(shared_options, parsed)
	if not _admit_schema_validation(
		data,
		schema,
		budget
	) or not _admit_import_options(validation_options, budget):
		return _make_budget_validation_failure(budget, schema)
	var report: Dictionary = schema.validate_table(data, validation_options)
	return report if budget.is_ok() else _make_budget_validation_failure(budget, schema)


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
## @param options: 可选参数，支持 source；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
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
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget):
		return _make_budget_validation_failure(budget, schema)
	var shared_options: Dictionary = _make_budget_options(options, budget)
	if schema == null:
		return _make_error_report(
			&"",
			"missing_schema",
			"schema 为空。"
		)

	var parsed: Dictionary = parse_json_table(text, shared_options)
	if not budget.is_ok():
		return _make_budget_validation_failure(budget, schema)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(
			schema.get_table_key(),
			"parse_failed",
			_get_parse_error(parsed),
			{ "source": _get_parse_source(parsed), "line": _get_parse_error_line(parsed), }
		)

	var data: Variant = _get_parse_data(parsed)
	if not (data is Dictionary):
		return _make_error_report(
			schema.get_table_key(),
			"invalid_json_record",
			"JSON 记录根节点必须是 Dictionary。",
			{
				"source": _get_parse_source(parsed),
				"value": GFVariantData.duplicate_variant(data),
				"actual_value": type_string(typeof(data)),
				"expected_value": "Dictionary",
				"supported_formats": ["JSON object"],
			}
		)

	var record: Dictionary = GFVariantData.as_dictionary(data)
	var resolved_row_key: Variant = row_key
	if resolved_row_key == null and schema.id_field != &"":
		resolved_row_key = GFVariantData.get_option_value(record, schema.id_field)
	var validation_options: Dictionary = _make_validation_options(shared_options, parsed)
	if (
		not budget.admit_value(resolved_row_key, "validation row key")
		or not budget.admit_value(record, "schema input")
		or not _admit_schema_definitions(schema, budget)
		or not _admit_schema_record(
			record,
			schema,
			budget
		)
		or not _admit_import_options(validation_options, budget)
	):
		return _make_budget_validation_failure(budget, schema)
	var report: Dictionary = schema.validate_record(
		record,
		resolved_row_key,
		validation_options
	)
	return report if budget.is_ok() else _make_budget_validation_failure(budget, schema)


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
## @param options: 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_csv_table(
	text: String,
	schema: GFConfigTableSchema,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget):
		return _make_budget_validation_failure(budget, schema)
	var shared_options: Dictionary = _make_budget_options(options, budget)
	if schema == null:
		return _make_error_report(
			&"",
			"missing_schema",
			"schema 为空。"
		)

	var parsed: Dictionary = parse_csv_table(text, shared_options)
	if not budget.is_ok():
		return _make_budget_validation_failure(budget, schema)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(
			schema.get_table_key(),
			"parse_failed",
			_get_parse_error(parsed),
			{
				"source": _get_parse_source(parsed),
				"line": _get_parse_error_line(parsed),
				"column": _get_parse_error_column(parsed),
			}
		)
	var data: Variant = _get_parse_data(parsed)
	var validation_options: Dictionary = _make_validation_options(shared_options, parsed)
	if not _admit_schema_validation(
		data,
		schema,
		budget
	) or not _admit_import_options(validation_options, budget):
		return _make_budget_validation_failure(budget, schema)
	var report: Dictionary = schema.validate_table(data, validation_options)
	return report if budget.is_ok() else _make_budget_validation_failure(budget, schema)


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
## @param options: 可选参数，支持 source、section_field、include_empty_sections；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 source、section_field 和 include_empty_sections 字段；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 校验报告；解析失败时返回失败报告。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
static func validate_config_file_table(
	text: String,
	schema: GFConfigTableSchema,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget):
		return _make_budget_validation_failure(budget, schema)
	var shared_options: Dictionary = _make_budget_options(options, budget)
	if schema == null:
		return _make_error_report(
			&"",
			"missing_schema",
			"schema 为空。"
		)

	var parsed: Dictionary = parse_config_file_table(text, shared_options)
	if not budget.is_ok():
		return _make_budget_validation_failure(budget, schema)
	if not GFVariantData.get_option_bool(parsed, "success"):
		return _make_error_report(
			schema.get_table_key(),
			"parse_failed",
			_get_parse_error(parsed),
			{
				"source": _get_parse_source(parsed),
				"line": _get_parse_error_line(parsed),
				"column": _get_parse_error_column(parsed),
			}
		)
	var data: Variant = _get_parse_data(parsed)
	var validation_options: Dictionary = _make_validation_options(shared_options, parsed)
	if not _admit_schema_validation(
		data,
		schema,
		budget
	) or not _admit_import_options(validation_options, budget):
		return _make_budget_validation_failure(budget, schema)
	var report: Dictionary = schema.validate_table(data, validation_options)
	return report if budget.is_ok() else _make_budget_validation_failure(budget, schema)


## 导出 CSV 表文本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 形式的表数据。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param schema: 可选 schema；提供时默认按 schema.columns 排列列。
## [br]
## @param options: 可选参数，支持 delimiter、columns、include_header、coerce_values；另支持互斥的 work_limits 或 work_budget。
## [br]
## @schema options: Dictionary，可包含 delimiter、columns、include_header 和 coerce_values；work_limits 为 GFConfigWorkBudget 限制字典，work_budget 为共享操作句柄，两者互斥。
## [br]
## @return 结果字典，包含 success、text 与 error。
## [br]
## @schema return: Dictionary，包含 success、text 和 error；预算失败另含 error_kind 和 budget_report，且不返回部分 data 或 text。
static func export_csv_table(
	table_data: Variant,
	schema: GFConfigTableSchema = null,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not budget.admit_value(table_data, "CSV export input"):
		return _make_budget_export_failure(budget)
	var normalized_rows: Dictionary = _normalize_table_rows(table_data)
	if not GFVariantData.get_option_bool(normalized_rows, "success"):
		return {
			"success": false,
			"text": "",
			"error": "table_data must be Array[Dictionary] or Dictionary.",
		}
	var rows: Array[Dictionary] = _copy_dictionary_rows(
		GFVariantData.get_option_value(
			normalized_rows,
			"rows",
			[]
		)
	)
	var delimiter: String = GFVariantData.get_option_string(
		options,
		"delimiter",
		","
	)
	delimiter = "," if delimiter.is_empty() else delimiter.substr(0, 1)
	var columns: PackedStringArray = _resolve_export_columns(
		rows,
		schema,
		options,
		budget
	)
	if not budget.is_ok():
		return _make_budget_export_failure(budget)
	var lines: PackedStringArray = PackedStringArray()
	if GFVariantData.get_option_bool(
		options,
		"include_header",
		true
	):
		var header_line: String = _join_csv_row(
			columns,
			delimiter,
			budget
		)
		if not budget.is_ok():
			return _make_budget_export_failure(budget)
		var _header_appended: bool = lines.append(header_line)

	var coerce_values: bool = GFVariantData.get_option_bool(
		options,
		"coerce_values",
		schema != null and schema.coerce_values
	)
	for row: Dictionary in rows:
		if not budget.consume_work(
			columns.size() + 1,
			"CSV export record"
		):
			return _make_budget_export_failure(budget)
		if (
			coerce_values
			and schema != null
			and not _admit_schema_record(
				row,
				schema,
				budget,
				true
			)
		):
			return _make_budget_export_failure(budget)
		var record: Dictionary = schema.coerce_record(row) if coerce_values and schema != null else row
		if not budget.admit_value(record, "CSV export candidate"):
			return _make_budget_export_failure(budget)
		if not lines.is_empty() and not budget.consume_output_bytes(1, "CSV newline"):
			return _make_budget_export_failure(budget)
		var cells: PackedStringArray = PackedStringArray()
		for column_name: String in columns:
			if not cells.is_empty() and not budget.consume_output_bytes(
				_utf8_codepoint_bytes(delimiter.unicode_at(0)),
				"CSV delimiter"
			):
				return _make_budget_export_failure(budget)
			var cell: String = _format_csv_cell(
				GFVariantData.get_option_value(
					record,
					StringName(column_name),
					""
				),
				delimiter,
				budget
			)
			if not budget.is_ok():
				return _make_budget_export_failure(budget)
			var _cell_appended: bool = cells.append(cell)
		var _line_appended: bool = lines.append(delimiter.join(cells))
	return {
		"success": true,
		"text": "\n".join(lines),
		"error": "",
	}


# --- 框架内部方法 ---

## 为制作期 Layout 复用 CSV 词法解析；只返回单元格与真实起始行，不解释表头或字段。
## [br]
## @api framework_internal
## [br]
## @param text: 原始 CSV 文本。
## [br]
## @param options: 与 parse_csv_table 共用的 delimiter、trim_cells、source 和工作预算选项。
## [br]
## @schema options: Dictionary，预算沿用 work_limits 或 work_budget，二者互斥。
## [br]
## @return: 完整物理行或无部分数据的解析失败。
## [br]
## @schema return: Dictionary，成功包含 success、rows:Array[PackedStringArray]、row_numbers:PackedInt32Array；失败包含 error、error_line、error_column，预算失败另含 budget_report。
static func decode_csv_rows(text: String, options: Dictionary = {}) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not _admit_import_options(options, budget) or not _admit_text(
		text,
		budget,
		"CSV"
	):
		return _make_budget_parse_failure(
			budget,
			GFVariantData.get_option_string(options, "source")
		)
	var delimiter: String = GFVariantData.get_option_string(
		options,
		"delimiter",
		","
	)
	if delimiter.is_empty():
		delimiter = ","
	var result: Dictionary = _parse_csv_rows(
		_normalize_csv_text(text),
		delimiter.substr(0, 1),
		GFVariantData.get_option_bool(
			options,
			"trim_cells",
			true
		),
		budget
	)
	if not budget.is_ok():
		return _make_budget_parse_failure(
			budget,
			GFVariantData.get_option_string(options, "source")
		)
	return result


# --- 私有/辅助方法 ---

## 在共享操作预算内把已准入的文本行映射为记录；CSV 已计量原始文本，不重复计量单元格输入字节。
## [br]
## @api private
static func _parse_rows_table(
	rows: Array[PackedStringArray],
	options: Dictionary,
	budget: GFConfigWorkBudget
) -> Dictionary:
	var source: String = GFVariantData.get_option_string(options, "source")
	if not budget.admit_value(rows, "tabular rows"):
		return _make_budget_parse_failure(budget, source)
	var trim_cells: bool = GFVariantData.get_option_bool(
		options,
		"trim_cells",
		true
	)
	var skip_empty_lines: bool = GFVariantData.get_option_bool(
		options,
		"skip_empty_lines",
		true
	)
	var reject_duplicate_headers: bool = GFVariantData.get_option_bool(
		options,
		"reject_duplicate_headers",
		true
	)
	var reject_empty_header: bool = GFVariantData.get_option_bool(
		options,
		"reject_empty_header",
		false
	)
	var require_header: bool = GFVariantData.get_option_bool(
		options,
		"require_header",
		false
	)
	var error_prefix: String = GFVariantData.get_option_string(
		options,
		"error_prefix",
		"Table rows"
	)
	var row_numbers: PackedInt32Array = _get_tabular_row_numbers(
		rows.size(),
		options
	)
	var default_header_row_number: int = _get_tabular_row_number(row_numbers, 0)
	var header_row_number: int = maxi(
		GFVariantData.get_option_int(
			options,
			"header_row",
			default_header_row_number
		),
		1
	)

	if rows.is_empty():
		if require_header:
			return _make_tabular_parse_failure(
				"%s header row is missing." % error_prefix,
				source,
				header_row_number,
				1
			)
		var empty_records: Array[Dictionary] = []
		var empty_locations: Array[Dictionary] = []
		return _make_tabular_parse_success(
			empty_records,
			PackedStringArray(),
			empty_locations,
			source
		)

	var base_comment_prefixes: PackedStringArray = _get_string_prefixes(options, "comment_prefixes")
	var comment_row_prefixes: PackedStringArray = _get_string_prefixes(
		options,
		"comment_row_prefixes",
		base_comment_prefixes
	)
	var comment_column_prefixes: PackedStringArray = _get_string_prefixes(
		options,
		"comment_column_prefixes",
		base_comment_prefixes
	)
	var comment_prefix_case_sensitive: bool = GFVariantData.get_option_bool(
		options,
		"comment_prefix_case_sensitive",
		false
	)
	var condition_prefix: String = GFVariantData.get_option_string(
		options,
		"condition_directive_prefix",
		"#"
	)
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
		var row_work: int = rows[row_array_index].size() * (2 + comment_column_prefixes.size()) + header.size() * 2 + comment_row_prefixes.size() + condition_stack.size() + condition_symbols.size() + 1
		if not budget.consume_work(row_work, "tabular row mapping"):
			return _make_budget_parse_failure(budget, source)
		var row_number: int = _get_tabular_row_number(row_numbers, row_array_index)
		var row: PackedStringArray = _prepare_tabular_row(
			rows[row_array_index],
			trim_cells
		)
		if row_number == header_row_number:
			header_found = true
			source_header_width = row.size()
			selected_column_indices = _select_tabular_column_indices(
				row,
				comment_column_prefixes,
				comment_prefix_case_sensitive
			)
			header = _filter_tabular_row(row, selected_column_indices)
			var header_error: String = _validate_tabular_header(
				header,
				reject_duplicate_headers,
				reject_empty_header,
				error_prefix
			)
			if not header_error.is_empty():
				return _make_tabular_parse_failure(
					header_error,
					source,
					row_number,
					1
				)
			continue
		if row_number <= header_row_number:
			continue

		var first_cell: String = row[0] if not row.is_empty() else ""
		if enable_condition_directives:
			var directive: Dictionary = _parse_condition_directive(
				first_cell,
				condition_prefix,
				budget
			)
			if not budget.is_ok():
				return _make_budget_parse_failure(budget, source)
			var directive_kind: StringName = GFVariantData.get_option_string_name(directive, "kind")
			if directive_kind == &"invalid":
				return _make_tabular_parse_failure(
					"%s parse failed: %s"
					% [
						error_prefix,
						GFVariantData.get_option_string(
							directive,
							"error",
							"invalid_condition_directive"
						),
					],
					source,
					row_number,
					1
				)
			if directive_kind == &"if":
				if not budget.check_depth(
					condition_stack.size() + 1,
					"CSV condition stack"
				):
					return _make_budget_parse_failure(budget, source)
				condition_stack.append(
					{
						"active": _condition_symbols_match(
							GFVariantData.get_option_packed_string_array(directive, "symbols"),
							condition_symbols,
							budget
						),
						"line": row_number,
					}
				)
				if not budget.is_ok():
					return _make_budget_parse_failure(budget, source)
				continue
			if directive_kind == &"endif":
				if condition_stack.is_empty():
					return _make_tabular_parse_failure(
						"%s parse failed: unexpected_condition_end" % error_prefix,
						source,
						row_number,
						1
					)
				condition_stack.pop_back()
				continue

		if not _condition_stack_is_active(condition_stack):
			continue
		if skip_empty_lines and _tabular_row_is_empty(row):
			continue
		if _text_has_prefix(
			first_cell,
			comment_row_prefixes,
			comment_prefix_case_sensitive
		):
			continue
		if row.size() > source_header_width:
			return _make_tabular_parse_failure(
				"%s parse failed: row_has_extra_cells" % error_prefix,
				source,
				row_number,
				source_header_width + 1
			)

		var record: Dictionary = {}
		for column_index: int in range(header.size()):
			var key: StringName = StringName(header[column_index])
			if key == &"":
				continue
			var source_column_index: int = selected_column_indices[column_index]
			record[key] = row[source_column_index] if source_column_index < row.size() else ""
		records.append(record)
		row_locations.append(
			_make_tabular_row_location(
				source,
				row_number,
				records.size() - 1,
				header,
				selected_column_indices
			)
		)

	if not header_found and require_header:
		return _make_tabular_parse_failure(
			"%s header row is missing." % error_prefix,
			source,
			header_row_number,
			1
		)
	if not condition_stack.is_empty():
		var condition_info: Dictionary = condition_stack[condition_stack.size() - 1]
		return _make_tabular_parse_failure(
			"%s parse failed: missing_condition_end" % error_prefix,
			source,
			GFVariantData.get_option_int(
				condition_info,
				"line",
				rows.size()
			),
			1
		)

	return _make_tabular_parse_success(
		records,
		header,
		row_locations,
		source,
		_make_tabular_row_location(
			source,
			header_row_number,
			-1,
			header,
			selected_column_indices
		)
	)


## 从解析结果中读取 data。
## [br]
## @api private
## [br]
static func _get_parse_data(parsed: Dictionary) -> Variant:
	return GFVariantData.get_option_value(parsed, "data")


## 从解析结果中读取 error。
## [br]
## @api private
## [br]
static func _get_parse_error(parsed: Dictionary) -> String:
	return GFVariantData.get_option_string(parsed, "error")


## 从解析结果中读取 source。
## [br]
## @api private
## [br]
static func _get_parse_source(parsed: Dictionary) -> String:
	return GFVariantData.get_option_string(parsed, "source")


## 从解析结果中读取错误行号。
## [br]
## @api private
## [br]
static func _get_parse_error_line(parsed: Dictionary) -> int:
	return GFVariantData.get_option_int(parsed, "error_line")


## 从解析结果中读取错误列号。
## [br]
## @api private
## [br]
static func _get_parse_error_column(parsed: Dictionary) -> int:
	return GFVariantData.get_option_int(parsed, "error_column")


## 从解析结果中读取行位置记录。
## [br]
## @api private
## [br]
static func _get_parse_row_locations(parsed: Dictionary) -> Variant:
	return GFVariantData.get_option_value(parsed, "row_locations")


## 解析 CSV 文本为行数组，并记录每行对应的源行号。
## [br]
## @api private
## [br]
static func _parse_csv_rows(
	text: String,
	delimiter: String,
	trim_cells: bool,
	budget: GFConfigWorkBudget
) -> Dictionary:
	var rows: Array[PackedStringArray] = []
	var row_numbers: PackedInt32Array = PackedInt32Array()
	var row: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = PackedStringArray()
	var segment_start: int = 0
	var in_quotes: bool = false
	var quote_closed: bool = false
	var quote_start_line: int = 1
	var quote_start_column: int = 1
	var index: int = 0
	var line: int = 1
	var column: int = 1
	var row_start_line: int = 1
	var delimiter_code: int = delimiter.unicode_at(0)

	while index < text.length():
		if index % 1024 == 0 and not budget.consume_work(1, "CSV character scan"):
			return {}
		var code: int = text.unicode_at(index)
		if in_quotes:
			if code == 34:
				if not budget.consume_work(1, "CSV quoted fragment"):
					return {}
				var _quoted_span: bool = parts.append(
					text.substr(
						segment_start,
						index - segment_start
					)
				)
				if index + 1 < text.length() and text.unicode_at(index + 1) == 34:
					var _escaped_quote: bool = parts.append("\"")
					index += 1
					column += 1
					segment_start = index + 1
				else:
					in_quotes = false
					quote_closed = true
					segment_start = -1
			elif code == 10:
				line += 1
				column = 0
		elif code == delimiter_code or code == 10:
			if not budget.consume_work(1, "CSV cell"):
				return {}
			var _cell_added: bool = row.append(
				_collect_csv_cell(
					parts,
					text,
					segment_start,
					index,
					trim_cells
				)
			)
			parts = PackedStringArray()
			segment_start = index + 1
			quote_closed = false
			if code == 10:
				rows.append(row)
				var _row_number_added: bool = row_numbers.append(row_start_line)
				row = PackedStringArray()
				line += 1
				column = 0
				row_start_line = line
		elif quote_closed:
			if (
				code != 13
				and not (
					trim_cells
					and (
						code == 32
						or code == 9
					)
				)
			):
				return _make_csv_syntax_failure(
					"malformed_quote",
					line,
					column
				)
		elif code == 34:
			var prefix: String = _collect_csv_cell(
				parts,
				text,
				segment_start,
				index,
				false
			)
			if (
				not prefix.is_empty()
				and (
					not trim_cells
					or not prefix.strip_edges().is_empty()
				)
			):
				return _make_csv_syntax_failure(
					"malformed_quote",
					line,
					column
				)
			parts = PackedStringArray()
			segment_start = index + 1
			in_quotes = true
			quote_start_line = line
			quote_start_column = column
		elif code == 13:
			if not budget.consume_work(1, "CSV carriage return"):
				return {}
			var _unquoted_span: bool = parts.append(
				text.substr(
					segment_start,
					index - segment_start
				)
			)
			segment_start = index + 1
		index += 1
		column += 1

	if in_quotes:
		return _make_csv_syntax_failure(
			"unclosed_quote",
			quote_start_line,
			quote_start_column
		)
	if not budget.consume_work(1, "CSV final cell"):
		return {}
	var _final_cell_added: bool = row.append(
		_collect_csv_cell(
			parts,
			text,
			segment_start,
			text.length(),
			trim_cells
		)
	)
	if row.size() > 1 or not _csv_row_is_empty(row):
		rows.append(row)
		var _final_row_number_added: bool = row_numbers.append(row_start_line)
	return {
		"success": true,
		"rows": rows,
		"row_numbers": row_numbers,
		"error": "",
		"error_line": 0,
		"error_column": 0,
	}


## 在字段边界一次拼接原文片段，避免长字段逐字符扩容形成二次工作量。
## [br]
## @api private
static func _collect_csv_cell(
	parts: PackedStringArray,
	text: String,
	start: int,
	end: int,
	trim_cells: bool
) -> String:
	if start >= 0 and end > start:
		var _span_added: bool = parts.append(
			text.substr(
				start,
				end - start
			)
		)
	var cell: String = "".join(parts)
	return cell.strip_edges() if trim_cells else cell


## CSV 语法失败不携带可被误当作完整输入的部分行。
## [br]
## @api private
static func _make_csv_syntax_failure(
	kind: String,
	line: int,
	column: int
) -> Dictionary:
	return {
		"success": false,
		"rows": [],
		"row_numbers": PackedInt32Array(),
		"error": "CSV parse failed: %s" % kind,
		"error_line": line,
		"error_column": column,
	}


## 移除 CSV 文本开头的 UTF-8 BOM。
## [br]
## @api private
## [br]
static func _normalize_csv_text(text: String) -> String:
	return text.trim_prefix("\ufeff")


## 移除配置文件文本开头的 UTF-8 BOM。
## [br]
## @api private
## [br]
static func _normalize_config_file_text(text: String) -> String:
	return text.trim_prefix("\ufeff")


## 从解析结果读取并类型校验表格行数组。
## [br]
## @api private
## [br]
static func _get_parse_rows(parse_result: Dictionary) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var rows_value: Variant = GFVariantData.get_option_value(
		parse_result,
		"rows",
		[]
	)
	if not rows_value is Array:
		return result
	for row_value: Variant in rows_value:
		if row_value is PackedStringArray:
			var row: PackedStringArray = row_value
			result.append(row)
	return result


## 从解析结果读取行号数组并规范化类型。
## [br]
## @api private
## [br]
static func _get_parse_row_numbers(parse_result: Dictionary) -> PackedInt32Array:
	var row_numbers_value: Variant = GFVariantData.get_option_value(parse_result, "row_numbers")
	if row_numbers_value is PackedInt32Array:
		var row_numbers: PackedInt32Array = row_numbers_value
		return row_numbers
	return PackedInt32Array()


## 从选项读取有效的表格源行号，必要时生成默认行号。
## [br]
## @api private
## [br]
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
		var _row_number_appended: bool = result.append(
			GFVariantData.to_int(
				row_value,
				result.size() + 1
			)
		)
	return result


## 按数组索引读取源行号；无对应值时使用一基行号。
## [br]
## @api private
## [br]
static func _get_tabular_row_number(row_numbers: PackedInt32Array, row_array_index: int) -> int:
	if row_array_index >= 0 and row_array_index < row_numbers.size():
		return row_numbers[row_array_index]
	return row_array_index + 1


## 从选项读取指定键的字符串前缀数组。
## [br]
## @api private
## [br]
static func _get_string_prefixes(
	options: Dictionary,
	key: String,
	default_value: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	return GFVariantData.get_option_packed_string_array(
		options,
		key,
		default_value
	)


## 按 trim_cells 选项规范化表格行中的单元格。
## [br]
## @api private
## [br]
static func _prepare_tabular_row(row: PackedStringArray, trim_cells: bool) -> PackedStringArray:
	if not trim_cells:
		return row

	var result: PackedStringArray = PackedStringArray()
	for cell: String in row:
		var _cell_appended: bool = result.append(cell.strip_edges())
	return result


## 按注释列前缀和大小写选项选择导入列索引。
## [br]
## @api private
## [br]
static func _select_tabular_column_indices(
	header: PackedStringArray,
	comment_column_prefixes: PackedStringArray,
	case_sensitive: bool
) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for column_index: int in range(header.size()):
		if _text_has_prefix(
			header[column_index],
			comment_column_prefixes,
			case_sensitive
		):
			continue
		var _column_appended: bool = result.append(column_index)
	return result


## 按列索引从一行中筛选单元格。
## [br]
## @api private
## [br]
static func _filter_tabular_row(row: PackedStringArray, column_indices: PackedInt32Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for column_index: int in column_indices:
		var _cell_appended: bool = result.append(row[column_index] if column_index < row.size() else "")
	return result


## 按选项校验表头中的空名称和重复名称。
## [br]
## @api private
## [br]
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
			return (
				"%s header has duplicate column: %s"
				% [error_prefix, column_name]
			)
		seen[column_name] = true
	if reject_empty_header and not has_named_column:
		return "%s header row is empty." % error_prefix
	return ""


## 构造带记录、表头、行位置和来源信息的成功解析结果。
## [br]
## @api private
## [br]
static func _make_tabular_parse_success(
	records: Array[Dictionary],
	header: PackedStringArray,
	row_locations: Array[Dictionary],
	source: String,
	header_location: Dictionary = {}
) -> Dictionary:
	return {
		"success": true,
		"data": records,
		"header": header,
		"header_location": header_location,
		"row_locations": row_locations,
		"error": "",
		"error_line": 0,
		"error_column": 0,
		"source": source,
	}


## 构造带错误位置和来源信息的失败解析结果。
## [br]
## @api private
## [br]
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


## 识别单元格中的条件指令并解析其符号信息。
## [br]
## @api private
## [br]
static func _parse_condition_directive(
	first_cell: String,
	directive_prefix: String,
	budget: GFConfigWorkBudget
) -> Dictionary:
	var text: String = first_cell.strip_edges()
	if directive_prefix.is_empty() or not text.begins_with(directive_prefix):
		return { "kind": &"none" }

	var payload: String = text.substr(directive_prefix.length()).strip_edges()
	if payload == "endif":
		return { "kind": &"endif" }
	if payload == "if":
		return { "kind": &"invalid", "error": "empty_condition_symbols", }
	if not payload.begins_with("if ") and not payload.begins_with("if\t"):
		return { "kind": &"none" }

	if not budget.consume_work(
		payload.length(),
		"CSV condition symbols"
	):
		return { "kind": &"invalid" }
	var symbols: PackedStringArray = PackedStringArray()
	var symbol_text: String = payload.substr(2).strip_edges().replace("\t", " ")
	for token: String in symbol_text.split(" ", false):
		var symbol: String = token.strip_edges()
		if symbol.is_empty():
			continue
		var _symbol_appended: bool = symbols.append(symbol)
	if symbols.is_empty():
		return { "kind": &"invalid", "error": "empty_condition_symbols", }
	return { "kind": &"if", "symbols": symbols, }


## 检查所需条件符号是否全部处于启用集合中。
## [br]
## @api private
## [br]
static func _condition_symbols_match(
	required_symbols: PackedStringArray,
	active_symbols: PackedStringArray,
	budget: GFConfigWorkBudget
) -> bool:
	for symbol: String in required_symbols:
		if not budget.consume_work(
			active_symbols.size() + 1,
			"CSV condition comparisons"
		):
			return false
		if not active_symbols.has(symbol):
			return false
	return true


## 检查条件指令栈中的所有层级是否均处于活动状态。
## [br]
## @api private
## [br]
static func _condition_stack_is_active(condition_stack: Array[Dictionary]) -> bool:
	for condition_info: Dictionary in condition_stack:
		if not GFVariantData.get_option_bool(condition_info, "active"):
			return false
	return true


## 检查表格行是否只包含空白单元格。
## [br]
## @api private
## [br]
static func _tabular_row_is_empty(row: PackedStringArray) -> bool:
	for cell: String in row:
		if not cell.strip_edges().is_empty():
			return false
	return true


## 按大小写选项检查文本是否匹配任一前缀。
## [br]
## @api private
## [br]
static func _text_has_prefix(
	text: String,
	prefixes: PackedStringArray,
	case_sensitive: bool
) -> bool:
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


## 构造表格行的源位置记录。
## [br]
## @api private
## [br]
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


## 创建只读遍历所用的类型化行数组，保留已准入的记录引用，不重复深拷贝整张表。
## [br]
## @api private
## [br]
static func _copy_dictionary_rows(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var rows: Array = value
	for row_value: Variant in rows:
		if row_value is Dictionary:
			result.append(GFVariantData.as_dictionary(row_value))
	return result


## 检查 CSV 行是否只包含空白单元格。
## [br]
## @api private
## [br]
static func _csv_row_is_empty(row: PackedStringArray) -> bool:
	for cell: String in row:
		if not cell.strip_edges().is_empty():
			return false
	return true


## 构造配置文件行的位置记录。
## [br]
## @api private
## [br]
static func _make_config_file_row_location(
	source: String,
	row_index: int,
	section: String,
	section_field: StringName,
	keys: PackedStringArray
) -> Dictionary:
	var fields: Dictionary = {}
	if section_field != &"":
		var section_location: Dictionary = _make_config_file_field_location(
			source,
			row_index,
			section
		)
		fields[section_field] = section_location
		fields[String(section_field)] = section_location
	for key: String in keys:
		var field_name: StringName = StringName(key)
		var field_location: Dictionary = _make_config_file_field_location(
			source,
			row_index,
			section
		)
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


## 构造配置文件字段的位置记录。
## [br]
## @api private
## [br]
static func _make_config_file_field_location(
	source: String,
	row_index: int,
	section: String
) -> Dictionary:
	var location: Dictionary = { "row_index": row_index, "section": section, }
	if not source.is_empty():
		location["source"] = source
	return location


## 创建带有问题类型和来源位置的配置导入错误报告。
## [br]
## @api private
## [br]
static func _make_error_report(
	table_name: StringName,
	kind: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	return GFConfigValidationReport.new().make_error_report(
		table_name,
		kind,
		message,
		context
	)


## 复制验证选项并补充解析结果中的来源信息。
## [br]
## @api private
## [br]
static func _make_validation_options(options: Dictionary, parsed: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(false)
	if parsed.has("source") and not GFVariantData.get_option_string(parsed, "source").is_empty():
		result["source"] = _get_parse_source(parsed)
	if parsed.has("row_locations"):
		result["row_locations"] = _get_parse_row_locations(parsed)
	return result


## 将输入表数据规范化为记录行和位置元数据。
## [br]
## @api private
## [br]
static func _normalize_table_rows(table_data: Variant) -> Dictionary:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		for row_variant: Variant in table_data:
			if not (row_variant is Dictionary):
				return { "success": false, "rows": rows, }
			rows.append(GFVariantData.as_dictionary(row_variant))
		return { "success": true, "rows": rows, }
	if table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		var keys: Array = table.keys()
		keys.sort()
		for key: Variant in keys:
			var row_variant: Variant = table[key]
			if not (row_variant is Dictionary):
				return { "success": false, "rows": rows, }
			rows.append(GFVariantData.as_dictionary(row_variant))
		return { "success": true, "rows": rows, }
	return { "success": false, "rows": rows, }


## 根据行、schema 与选项解析导出列集合。
## [br]
## @api private
## [br]
static func _resolve_export_columns(
	rows: Array[Dictionary],
	schema: GFConfigTableSchema,
	options: Dictionary,
	budget: GFConfigWorkBudget
) -> PackedStringArray:
	if options.has("columns"):
		return GFVariantData.get_option_packed_string_array(options, "columns")
	if schema != null:
		if not budget.consume_work(
			schema.columns.size(),
			"CSV schema columns"
		):
			return PackedStringArray()
		var schema_columns: PackedStringArray = PackedStringArray()
		for column: GFConfigTableColumn in schema.columns:
			if column != null and column.get_field_key() != &"":
				var _column_appended: bool = schema_columns.append(str(column.get_field_key()))
		if not schema_columns.is_empty():
			if not budget.admit_value(schema_columns, "CSV schema column names"):
				return PackedStringArray()
			return schema_columns

	var seen: Dictionary = {}
	for row: Dictionary in rows:
		if not budget.consume_work(
			row.size() + 1,
			"CSV column discovery"
		):
			return PackedStringArray()
		for key: Variant in row.keys():
			seen[GFVariantData.to_text(key)] = true
	var result: PackedStringArray = PackedStringArray()
	for key_text: String in seen.keys():
		var _key_appended: bool = result.append(key_text)
	result.sort()
	return result


## 格式化一行 CSV 单元格并用分隔符连接。
## [br]
## @api private
## [br]
static func _join_csv_row(
	cells: PackedStringArray,
	delimiter: String,
	budget: GFConfigWorkBudget
) -> String:
	var escaped: PackedStringArray = PackedStringArray()
	for cell: String in cells:
		if not budget.consume_work(1, "CSV header cell"):
			return ""
		if not escaped.is_empty() and not budget.consume_output_bytes(
			_utf8_codepoint_bytes(delimiter.unicode_at(0)),
			"CSV delimiter"
		):
			return ""
		var formatted: String = _format_csv_cell(
			cell,
			delimiter,
			budget
		)
		if not budget.is_ok():
			return ""
		var _cell_appended: bool = escaped.append(formatted)
	return delimiter.join(escaped)


## 在 CSV 转义扩容前计量最终 UTF-8 字节；失败由共享预算锁存，不返回部分成功文本。
## [br]
## @api private
static func _format_csv_cell(
	value: Variant,
	delimiter: String,
	budget: GFConfigWorkBudget
) -> String:
	var text: String = str(value)
	var bytes: int = 0
	var quotes: int = 0
	var needs_quotes: bool = false
	var delimiter_code: int = delimiter.unicode_at(0)
	for index: int in range(text.length()):
		if index % 1024 == 0 and not budget.consume_work(1, "CSV escaped output scan"):
			return ""
		var code: int = text.unicode_at(index)
		bytes += _utf8_codepoint_bytes(code)
		if code == 34:
			quotes += 1
		if (
			code == delimiter_code
			or code == 10
			or code == 13
			or code == 34
		):
			needs_quotes = true
	if not budget.consume_output_bytes(
		bytes + quotes + (2 if needs_quotes else 0),
		"CSV escaped output"
	):
		return ""
	text = text.replace("\"", "\"\"")
	return "\"%s\"" % text if needs_quotes else text


## 预算失败保留本次调用已解析的来源，不复制输入或交付部分结果。
## [br]
## @api private
static func _make_budget_parse_failure(budget: GFConfigWorkBudget, source: String) -> Dictionary:
	var report: Dictionary = budget.get_report()
	return {
		"success": false,
		"data": null,
		"header": PackedStringArray(),
		"sections": PackedStringArray(),
		"row_locations": [],
		"error_kind": report["error_kind"],
		"error": report["error"],
		"error_line": 0,
		"error_column": 0,
		"source": source,
		"budget_report": report,
	}


## 导出预算失败不泄漏已经构建的前缀文本。
## [br]
## @api private
static func _make_budget_export_failure(budget: GFConfigWorkBudget) -> Dictionary:
	var report: Dictionary = budget.get_report()
	return {
		"success": false,
		"text": "",
		"error_kind": report["error_kind"],
		"error": report["error"],
		"budget_report": report,
	}


## 预算违规使用稳定问题种类，避免被包装成普通格式解析错误。
## [br]
## @api private
static func _make_budget_validation_failure(budget: GFConfigWorkBudget, schema: GFConfigTableSchema) -> Dictionary:
	var evidence: Dictionary = budget.get_report()
	var report: Dictionary = _make_error_report(
		schema.get_table_key() if schema != null else &"",
		str(evidence["error_kind"]),
		str(evidence["error"])
	)
	report["budget_report"] = evidence
	return report


## 只浅复制已准入的选项，复用原 handle 并移除只用于创建预算的 limits。
## [br]
## @api private
static func _make_budget_options(options: Dictionary, budget: GFConfigWorkBudget) -> Dictionary:
	var shared: Dictionary = options.duplicate(false)
	var _limits_removed: bool = shared.erase("work_limits")
	var _named_limits_removed: bool = shared.erase(&"work_limits")
	shared["work_budget"] = budget
	return shared


## 选项可包含预算 handle；其余值先准入再进入可能复制集合的读取工具。
## [br]
## @api private
static func _admit_import_options(options: Dictionary, budget: GFConfigWorkBudget) -> bool:
	if not budget.is_ok() or not budget.consume_work(
		options.size(),
		"import options"
	):
		return false
	var values: Dictionary = {}
	for key: Variant in options:
		if key == "work_limits" or key == "work_budget":
			continue
		values[key] = options[key]
	return budget.admit_value(values, "import options")


## 在复制、规范化和原生解析前扫描 UTF-8 容量及文本嵌套；原生解析本身不受可抢占时间预算保护。
## [br]
## @api private
static func _admit_text(
	text: String,
	budget: GFConfigWorkBudget,
	context: String,
	structured: bool = false,
	config_file: bool = false
) -> bool:
	if not budget.check_input_bytes(
		text.length(),
		context
	):
		return false
	var chunk_bytes: int = 0
	var depth: int = 0
	var quoted: bool = false
	var escaped: bool = false
	var comment: bool = false
	for index: int in range(text.length()):
		if index % 1024 == 0 and not budget.consume_work(1, context):
			return false
		var code: int = text.unicode_at(index)
		chunk_bytes += _utf8_codepoint_bytes(code)
		if structured:
			if comment:
				comment = code != 10
			elif quoted:
				if escaped:
					escaped = false
				elif code == 92:
					escaped = true
				elif code == 34:
					quoted = false
			elif code == 34:
				quoted = true
			elif (
				config_file
				and (
					code == 59
					or code == 35
				)
			):
				comment = true
			elif (
				code == 91
				or code == 123
				or (
					config_file
					and code == 40
				)
			):
				depth += 1
				if not budget.check_depth(
					depth - 1,
					context
				):
					return false
			elif (
				code == 93
				or code == 125
				or (
					config_file
					and code == 41
				)
			):
				depth = maxi(
					depth - 1,
					0
				)
		if index % 1024 == 1023:
			if not budget.consume_input_bytes(chunk_bytes, context):
				return false
			chunk_bytes = 0
	return budget.consume_input_bytes(chunk_bytes, context)


## 计量一个 Unicode 码点的 UTF-8 长度，避免为了预检先分配完整字节副本。
## [br]
## @api private
static func _utf8_codepoint_bytes(code: int) -> int:
	if code <= 0x7f:
		return 1
	if code <= 0x7ff:
		return 2
	if code <= 0xffff:
		return 3
	return 4


## 校验入口在 schema 复制与回调前按字段、规则和索引访问预留；逐元素规则继续受 schema 自身预算约束。
## [br]
## @api private
static func _admit_schema_validation(
	data: Variant,
	schema: GFConfigTableSchema,
	budget: GFConfigWorkBudget
) -> bool:
	if not budget.admit_value(data, "schema input") or not _admit_schema_definitions(schema, budget):
		return false
	if data is Array:
		var rows: Array = data
		for row: Variant in rows:
			if not _admit_schema_record(
				row,
				schema,
				budget
			):
				return false
	elif data is Dictionary:
		var keyed_rows: Dictionary = data
		for key: Variant in keyed_rows:
			if not _admit_schema_record(
				keyed_rows[key],
				schema,
				budget
			):
				return false
	return budget.is_ok()


## 为 schema 声明与索引字段预留工作，保持单条记录与整表各自的输入根深度。
## [br]
## @api private
static func _admit_schema_definitions(schema: GFConfigTableSchema, budget: GFConfigWorkBudget) -> bool:
	if not budget.consume_work(
		schema.columns.size() + schema.table_validation_rules.size() + schema.indexes.size(),
		"schema definitions"
	):
		return false
	for index_definition: GFConfigTableIndexDefinition in schema.indexes:
		if index_definition != null and not budget.admit_value(index_definition.field_names, "schema index fields"):
			return false
	return true


## 分批扣除每条记录的声明访问数，避免行数乘规则数溢出；缺省值在 coercion 复制前独立准入。
## [br]
## @api private
static func _admit_schema_record(
	value: Variant,
	schema: GFConfigTableSchema,
	budget: GFConfigWorkBudget,
	force_coerce: bool = false
) -> bool:
	if not budget.consume_work(
		1 + schema.record_validation_rules.size(),
		"schema record"
	):
		return false
	if not value is Dictionary:
		return true
	var record: Dictionary = value
	for column: GFConfigTableColumn in schema.columns:
		if not budget.consume_work(1, "schema column"):
			return false
		if column == null:
			continue
		if not budget.consume_work(
			column.validation_rules.size() + column.element_validation_rules.size(),
			"schema rule declarations"
		):
			return false
		if (
			(
				schema.coerce_values
				or force_coerce
			)
			and not record.has(column.get_field_key())
			and not budget.admit_value(column.default_value, "schema default")
		):
			return false
	for index_definition: GFConfigTableIndexDefinition in schema.indexes:
		if index_definition != null and not budget.consume_work(
			index_definition.field_names.size(),
			"schema row index"
		):
			return false
	return true
