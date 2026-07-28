## GFConfigPipelineLayoutStage: Config Pipeline 的内置布局解析阶段。
##
## 把 Reader 原始载荷解码为记录、表头和来源位置，不推导 schema、不转换字段类型。
## 内置实现支持 CSV、JSON、ConfigFile 与 XLSX，格式专属细节在此阶段内收敛。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineLayoutStage
extends RefCounted


# --- 常量 ---

## Layout 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.layout.builtin"

## Layout 阶段的实现版本；改变布局解析语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 2

const _DEFAULT_MAX_XLSX_ENTRY_BYTES: int = 8 * 1024 * 1024
const _DEFAULT_MAX_XLSX_FILE_BYTES: int = 64 * 1024 * 1024
const _DEFAULT_MAX_XLSX_ENTRY_COUNT: int = 4096
const _DEFAULT_MAX_XLSX_COMPRESSION_RATIO: int = 100
const _DEFAULT_MAX_XLSX_PATH_LENGTH: int = 512
const _DEFAULT_MAX_XLSX_PATH_DEPTH: int = 32
const _DEFAULT_MAX_XLSX_SHARED_STRINGS: int = 100000
const _DEFAULT_MAX_XLSX_ROWS: int = 100000
const _DEFAULT_MAX_XLSX_COLUMNS: int = 512
const _GF_BOUNDED_ZIP_SUPPORT = preload("res://addons/gf/kernel/package/gf_bounded_zip_support.gd")


# --- 公共方法 ---

## 解码 Reader 阶段载荷并保留格式无关的来源定位信息。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param source: 单表来源声明。
## [br]
## @param read_result: Reader 阶段结果。
## [br]
## @schema read_result: Dictionary，符合 gf.config_pipeline.reader_result@1。
## [br]
## @param options: 布局解析选项。
## [br]
## @schema options: Dictionary，可包含 parse_options；其字段覆盖 source.parse_options。
## [br]
## @return: Layout 阶段结果。
## [br]
## @schema return: Dictionary，包含 success、phase、data、header、row_locations、source、source_path、format、error_kind、error、error_line 和 error_column，并可包含格式专属字段。
func decode_source(
	source: GFConfigPipelineTableSource,
	read_result: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if source == null:
		return _make_layout_failure("invalid_table_source", "表来源声明为空。")
	var resolved_format: StringName = source.get_resolved_format()
	var source_path: String = source.source_path
	if not GFVariantData.get_option_bool(read_result, "success"):
		return _make_layout_failure(
			GFVariantData.get_option_string(read_result, "error_kind", "reader_failed"),
			GFVariantData.get_option_string(read_result, "error"),
			source_path,
			resolved_format,
			GFVariantData.get_option_int(read_result, "error_code", ERR_CANT_OPEN),
			GFVariantData.get_option_dictionary(read_result, "context")
		)

	var parse_options: Dictionary = source.parse_options.duplicate(true)
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(
		parse_options,
		GFVariantData.get_option_dictionary(options, "parse_options")
	)
	if not source_path.is_empty():
		parse_options["source"] = source_path

	var parse_result: Dictionary = {}
	if resolved_format == GFConfigPipelineTableSource.FORMAT_XLSX:
		if GFVariantData.get_option_string(read_result, "payload_kind") != "file":
			return _make_layout_failure(
				"invalid_reader_payload",
				"XLSX Layout 需要 file Reader 载荷。",
				source_path,
				resolved_format,
				ERR_INVALID_DATA
			)
		parse_result = _parse_xlsx_file(source_path, parse_options)
	else:
		if GFVariantData.get_option_string(read_result, "payload_kind") != "text":
			return _make_layout_failure(
				"invalid_reader_payload",
				"文本 Layout 需要 text Reader 载荷。",
				source_path,
				resolved_format,
				ERR_INVALID_DATA
			)
		var text: String = GFVariantData.get_option_string(read_result, "text")
		if resolved_format == GFConfigPipelineTableSource.FORMAT_CSV:
			parse_result = GFConfigTableImporter.parse_csv_table(text, parse_options)
		elif resolved_format == GFConfigPipelineTableSource.FORMAT_JSON:
			parse_result = GFConfigTableImporter.parse_json_table(text, parse_options)
		elif resolved_format == GFConfigPipelineTableSource.FORMAT_CONFIG_FILE:
			parse_result = GFConfigTableImporter.parse_config_file_table(text, parse_options)
		else:
			return _make_layout_failure(
				"unsupported_source_format",
				"不支持的配置表来源格式：%s。" % String(resolved_format),
				source_path,
				resolved_format,
				ERR_FILE_UNRECOGNIZED
			)
	return _with_stage_result(parse_result, source_path, resolved_format)


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、input_contract、output_contract 和 supported_formats。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contract": "gf.config_pipeline.reader_result@1",
		"output_contract": "gf.config_pipeline.layout_result@1",
		"supported_formats": ["csv", "json", "config_file", "xlsx"],
	}


# --- 私有/辅助方法 ---

func _with_stage_result(
	parse_result: Dictionary,
	source_path: String,
	resolved_format: StringName
) -> Dictionary:
	var result: Dictionary = parse_result
	result["phase"] = "layout"
	result["source_path"] = source_path
	result["format"] = resolved_format
	if not result.has("source"):
		result["source"] = source_path
	if GFVariantData.get_option_bool(result, "success"):
		result["error_kind"] = ""
		result["error_code"] = OK
	else:
		result["error_kind"] = GFVariantData.get_option_string(result, "error_kind", "parse_failed")
		result["error_code"] = GFVariantData.get_option_int(result, "error_code", ERR_PARSE_ERROR)
	return result


func _parse_xlsx_file(path: String, options: Dictionary) -> Dictionary:
	var file_limit: int = _get_xlsx_limit(options, "max_xlsx_file_bytes", _DEFAULT_MAX_XLSX_FILE_BYTES)
	var archive_file_limit: int = _resolve_xlsx_archive_file_limit(
		file_limit
	)
	var total_uncompressed_limit: int = (
		_resolve_xlsx_total_uncompressed_limit(
			options,
			file_limit
		)
	)
	var size_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if size_file == null:
		return _make_xlsx_parse_failure("XLSX open failed: %s" % error_string(FileAccess.get_open_error()), path)
	var file_size: int = int(size_file.get_length())
	size_file.close()
	if _is_xlsx_limit_exceeded(file_size, file_limit):
		return _make_xlsx_parse_failure("XLSX file exceeds max_xlsx_file_bytes.", path)

	var archive_session: Dictionary = _GF_BOUNDED_ZIP_SUPPORT.open_archive(
		path,
		{
			"max_archive_bytes": archive_file_limit,
			"max_entry_count": _get_xlsx_limit(
				options,
				"max_xlsx_entry_count",
				_DEFAULT_MAX_XLSX_ENTRY_COUNT
			),
			"max_entry_compressed_bytes": _get_xlsx_limit(
				options,
				"max_xlsx_entry_bytes",
				_DEFAULT_MAX_XLSX_ENTRY_BYTES
			),
			"max_entry_uncompressed_bytes": _get_xlsx_limit(
				options,
				"max_xlsx_entry_bytes",
				_DEFAULT_MAX_XLSX_ENTRY_BYTES
			),
			"max_total_uncompressed_bytes": total_uncompressed_limit,
			"max_compression_ratio": _get_xlsx_limit(
				options,
				"max_xlsx_compression_ratio",
				_DEFAULT_MAX_XLSX_COMPRESSION_RATIO
			),
			"max_path_length": _get_xlsx_limit(
				options,
				"max_xlsx_path_length",
				_DEFAULT_MAX_XLSX_PATH_LENGTH
			),
			"max_path_depth": _get_xlsx_limit(
				options,
				"max_xlsx_path_depth",
				_DEFAULT_MAX_XLSX_PATH_DEPTH
			),
		}
	)
	if not GFVariantData.get_option_bool(archive_session, "ok"):
		var failed_inspection: Dictionary = GFVariantData.get_option_dictionary(
			archive_session,
			"inspection"
		)
		return _make_xlsx_parse_failure(
			_xlsx_archive_inspection_error(failed_inspection),
			path
		)
	var files: PackedStringArray = _GF_BOUNDED_ZIP_SUPPORT.get_files(
		archive_session
	)
	var shared_strings_result: Dictionary = _read_xlsx_shared_strings(
		archive_session,
		files,
		options
	)
	if not GFVariantData.get_option_bool(shared_strings_result, "success"):
		if _close_zip_session(archive_session) != OK:
			return _make_xlsx_parse_failure(
				"XLSX bounded ZIP session cleanup failed.",
				path
			)
		return _make_xlsx_parse_failure(GFVariantData.get_option_string(shared_strings_result, "error"), path)
	var shared_strings: PackedStringArray = _get_packed_string_array_value(GFVariantData.get_option_value(shared_strings_result, "strings"))
	var workbook_result: Dictionary = _read_xlsx_workbook_sheets(
		archive_session,
		files,
		options
	)
	if not GFVariantData.get_option_bool(workbook_result, "success"):
		if _close_zip_session(archive_session) != OK:
			return _make_xlsx_parse_failure(
				"XLSX bounded ZIP session cleanup failed.",
				path
			)
		return _make_xlsx_parse_failure(
			GFVariantData.get_option_string(workbook_result, "error"),
			path
		)
	var workbook_sheets: Array[Dictionary] = _get_dictionary_array_value(
		GFVariantData.get_option_value(workbook_result, "sheets")
	)
	var worksheet_path: String = _resolve_xlsx_worksheet_path(files, workbook_sheets, options)
	if worksheet_path.is_empty():
		if _close_zip_session(archive_session) != OK:
			return _make_xlsx_parse_failure(
				"XLSX bounded ZIP session cleanup failed.",
				path
			)
		return _make_xlsx_parse_failure("XLSX sheet not found.", path)

	var worksheet_result: Dictionary = _zip_read_bytes(
		archive_session,
		files,
		worksheet_path,
		_get_xlsx_limit(
			options,
			"max_xlsx_entry_bytes",
			_DEFAULT_MAX_XLSX_ENTRY_BYTES
		)
	)
	var close_error: Error = _close_zip_session(archive_session)
	if close_error != OK:
		return _make_xlsx_parse_failure(
			"XLSX bounded ZIP session cleanup failed.",
			path
		)
	if not GFVariantData.get_option_bool(worksheet_result, "success"):
		return _make_xlsx_parse_failure(
			GFVariantData.get_option_string(worksheet_result, "error"),
			path
		)
	var worksheet_bytes: PackedByteArray = _get_packed_byte_array_value(
		GFVariantData.get_option_value(worksheet_result, "bytes")
	)
	if worksheet_bytes.size() == 0:
		return _make_xlsx_parse_failure("XLSX worksheet is empty: %s" % worksheet_path, path)
	return _parse_xlsx_sheet(worksheet_bytes, shared_strings, options)


func _resolve_xlsx_archive_file_limit(file_limit: int) -> int:
	if file_limit != 0:
		return file_limit
	return _GF_BOUNDED_ZIP_SUPPORT.get_absolute_max_archive_bytes()


func _resolve_xlsx_total_uncompressed_limit(
	options: Dictionary,
	file_limit: int
) -> int:
	var total_uncompressed_limit: int = _get_xlsx_limit(
		options,
		"max_xlsx_total_uncompressed_bytes",
		file_limit
	)
	if total_uncompressed_limit != 0:
		return total_uncompressed_limit
	return (
		_GF_BOUNDED_ZIP_SUPPORT
		.get_absolute_max_total_uncompressed_bytes()
	)


func _read_xlsx_shared_strings(
	archive_session: Dictionary,
	files: PackedStringArray,
	options: Dictionary
) -> Dictionary:
	var result: PackedStringArray = PackedStringArray()
	var read_result: Dictionary = _zip_read_bytes(
		archive_session,
		files,
		"xl/sharedStrings.xml",
		_get_xlsx_limit(
			options,
			"max_xlsx_entry_bytes",
			_DEFAULT_MAX_XLSX_ENTRY_BYTES
		)
	)
	if not GFVariantData.get_option_bool(read_result, "success"):
		return _make_xlsx_shared_strings_result(
			false,
			result,
			GFVariantData.get_option_string(read_result, "error")
		)
	var bytes: PackedByteArray = _get_packed_byte_array_value(
		GFVariantData.get_option_value(read_result, "bytes")
	)
	if bytes.size() == 0:
		return _make_xlsx_shared_strings_result(true, result)

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return _make_xlsx_shared_strings_result(false, result, "XLSX sharedStrings.xml parse failed: %s" % error_string(open_error))

	var max_shared_strings: int = _get_xlsx_limit(options, "max_xlsx_shared_strings", _DEFAULT_MAX_XLSX_SHARED_STRINGS)
	var current_text: String = ""
	var in_shared_string: bool = false
	var in_text: bool = false
	while parser.read() == OK:
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			if node_name == "si":
				in_shared_string = true
				current_text = ""
			elif in_shared_string and node_name == "t":
				in_text = true
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if in_shared_string and in_text:
				current_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if end_name == "t":
				in_text = false
			elif end_name == "si":
				if _is_xlsx_limit_exceeded(result.size() + 1, max_shared_strings):
					return _make_xlsx_shared_strings_result(false, result, "XLSX shared string count exceeds max_xlsx_shared_strings.")
				var _text_appended: bool = result.append(current_text)
				in_shared_string = false
				in_text = false
				current_text = ""
	return _make_xlsx_shared_strings_result(true, result)


func _make_xlsx_shared_strings_result(
	success: bool,
	strings: PackedStringArray,
	error: String = ""
) -> Dictionary:
	return {
		"success": success,
		"strings": strings.duplicate(),
		"error": error,
	}


func _read_xlsx_workbook_sheets(
	archive_session: Dictionary,
	files: PackedStringArray,
	options: Dictionary
) -> Dictionary:
	var max_entry_bytes: int = _get_xlsx_limit(
		options,
		"max_xlsx_entry_bytes",
		_DEFAULT_MAX_XLSX_ENTRY_BYTES
	)
	var workbook_result: Dictionary = _zip_read_bytes(
		archive_session,
		files,
		"xl/workbook.xml",
		max_entry_bytes
	)
	if not GFVariantData.get_option_bool(workbook_result, "success"):
		return {
			"success": false,
			"sheets": [],
			"error": GFVariantData.get_option_string(workbook_result, "error"),
		}
	var workbook_bytes: PackedByteArray = _get_packed_byte_array_value(
		GFVariantData.get_option_value(workbook_result, "bytes")
	)
	if workbook_bytes.size() == 0:
		return { "success": true, "sheets": [], "error": "" }

	var sheets: Array[Dictionary] = _parse_xlsx_workbook_sheet_entries(workbook_bytes)
	var relationships_result: Dictionary = _zip_read_bytes(
		archive_session,
		files,
		"xl/_rels/workbook.xml.rels",
		max_entry_bytes
	)
	if not GFVariantData.get_option_bool(relationships_result, "success"):
		return {
			"success": false,
			"sheets": [],
			"error": GFVariantData.get_option_string(relationships_result, "error"),
		}
	var relationships: Dictionary = _parse_xlsx_workbook_relationships(
		_get_packed_byte_array_value(
			GFVariantData.get_option_value(relationships_result, "bytes")
		)
	)
	for sheet: Dictionary in sheets:
		var relation_id: String = GFVariantData.get_option_string(sheet, "relation_id")
		var target: String = GFVariantData.get_option_string(relationships, relation_id)
		if not target.is_empty():
			sheet["path"] = _normalize_xlsx_relationship_target("xl/workbook.xml", target)
	return { "success": true, "sheets": sheets, "error": "" }


func _parse_xlsx_workbook_sheet_entries(bytes: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return result

	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "sheet":
			continue

		var entry: Dictionary = {
			"name": _get_xml_attribute(parser, "name"),
			"sheet_id": _get_xml_attribute(parser, "sheetId"),
			"relation_id": _get_xml_attribute_any(parser, PackedStringArray(["r:id", "id"])),
			"path": "",
		}
		result.append(entry)
	return result


func _parse_xlsx_workbook_relationships(bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {}
	if bytes.size() == 0:
		return result

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return result

	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "Relationship":
			continue

		var relation_id: String = _get_xml_attribute(parser, "Id")
		if relation_id.is_empty():
			continue
		result[relation_id] = _get_xml_attribute(parser, "Target")
	return result


func _resolve_xlsx_worksheet_path(
	files: PackedStringArray,
	sheets: Array[Dictionary],
	options: Dictionary
) -> String:
	var sheet_name: String = GFVariantData.get_option_string(options, "sheet_name")
	if not sheet_name.is_empty():
		for sheet: Dictionary in sheets:
			if GFVariantData.get_option_string(sheet, "name") != sheet_name:
				continue
			var named_path: String = GFVariantData.get_option_string(sheet, "path")
			return named_path if _zip_has_file(files, named_path) else ""
		return ""

	var sheet_index: int = maxi(GFVariantData.get_option_int(options, "sheet_index", 0), 0)
	if sheet_index < sheets.size():
		var sheet: Dictionary = sheets[sheet_index]
		var indexed_path: String = GFVariantData.get_option_string(sheet, "path")
		if _zip_has_file(files, indexed_path):
			return indexed_path

	var fallback_path: String = "xl/worksheets/sheet%d.xml" % (sheet_index + 1)
	return fallback_path if _zip_has_file(files, fallback_path) else ""


func _parse_xlsx_sheet(
	bytes: PackedByteArray,
	shared_strings: PackedStringArray,
	options: Dictionary
) -> Dictionary:
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return _make_xlsx_parse_failure("XLSX worksheet parse failed: %s" % error_string(open_error), GFVariantData.get_option_string(options, "source"))

	var rows: Array[Dictionary] = []
	var max_rows: int = _get_xlsx_limit(options, "max_xlsx_rows", _DEFAULT_MAX_XLSX_ROWS)
	var max_columns: int = _get_xlsx_limit(options, "max_xlsx_columns", _DEFAULT_MAX_XLSX_COLUMNS)
	var current_cells: Dictionary = {}
	var current_row_number: int = 0
	var row_fallback_number: int = 0
	var current_cell_ref: String = ""
	var current_cell_type: String = ""
	var current_cell_value: String = ""
	var in_cell: bool = false
	var in_value: bool = false
	var in_inline_text: bool = false

	while parser.read() == OK:
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			if node_name == "row":
				row_fallback_number += 1
				current_row_number = _parse_positive_int(_get_xml_attribute(parser, "r"), row_fallback_number)
				current_cells = {}
			elif node_name == "c":
				in_cell = true
				current_cell_ref = _get_xml_attribute(parser, "r")
				current_cell_type = _get_xml_attribute(parser, "t")
				current_cell_value = ""
			elif in_cell and node_name == "v":
				in_value = true
			elif in_cell and current_cell_type == "inlineStr" and node_name == "t":
				in_inline_text = true
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if in_value or in_inline_text:
				current_cell_value += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if end_name == "v":
				in_value = false
			elif end_name == "t":
				in_inline_text = false
			elif end_name == "c":
				var column_index: int = _xlsx_column_index_from_cell_ref(current_cell_ref)
				if column_index >= 0:
					if _is_xlsx_limit_exceeded(column_index + 1, max_columns):
						return _make_xlsx_parse_failure(
							"XLSX column count exceeds max_xlsx_columns.",
							GFVariantData.get_option_string(options, "source"),
							current_row_number,
							column_index + 1
						)
					var cell_result: Dictionary = _resolve_xlsx_cell_value(current_cell_value, current_cell_type, shared_strings)
					if not GFVariantData.get_option_bool(cell_result, "success"):
						return _make_xlsx_parse_failure(
							GFVariantData.get_option_string(cell_result, "error"),
							GFVariantData.get_option_string(options, "source"),
							current_row_number,
							column_index + 1
						)
					current_cells[column_index] = GFVariantData.get_option_string(cell_result, "value")
				in_cell = false
				in_value = false
				in_inline_text = false
			elif end_name == "row":
				if _is_xlsx_limit_exceeded(rows.size() + 1, max_rows):
					return _make_xlsx_parse_failure(
						"XLSX row count exceeds max_xlsx_rows.",
						GFVariantData.get_option_string(options, "source"),
						current_row_number,
						1
					)
				rows.append({
					"row_number": current_row_number,
					"cells": current_cells.duplicate(true),
				})
				current_cells = {}

	return _xlsx_rows_to_parse_result(rows, options)


func _xlsx_rows_to_parse_result(rows: Array[Dictionary], options: Dictionary) -> Dictionary:
	var trim_cells: bool = GFVariantData.get_option_bool(options, "trim_cells", true)
	var parsed_rows: Array[PackedStringArray] = []
	var row_numbers: PackedInt32Array = PackedInt32Array()
	for row_info: Dictionary in rows:
		var row_number: int = GFVariantData.get_option_int(row_info, "row_number")
		var cells: Dictionary = GFVariantData.get_option_dictionary(row_info, "cells")
		parsed_rows.append(_xlsx_cells_to_row(cells, trim_cells))
		var _row_number_appended: bool = row_numbers.append(row_number)

	var row_options: Dictionary = options.duplicate(true)
	row_options["row_numbers"] = row_numbers
	row_options["require_header"] = true
	row_options["reject_empty_header"] = true
	row_options["error_prefix"] = "XLSX"
	return GFConfigTableImporter.parse_rows_table(parsed_rows, row_options)


func _xlsx_cells_to_row(cells: Dictionary, trim_cells: bool) -> PackedStringArray:
	var max_column_index: int = -1
	for key: Variant in cells.keys():
		if key is int:
			var column_index: int = key
			max_column_index = maxi(max_column_index, column_index)

	var result: PackedStringArray = PackedStringArray()
	for column_index: int in range(max_column_index + 1):
		var text: String = GFVariantData.to_text(GFVariantData.get_option_value(cells, column_index, ""))
		var _cell_appended: bool = result.append(text.strip_edges() if trim_cells else text)
	return result


func _resolve_xlsx_cell_value(
	raw_value: String,
	cell_type: String,
	shared_strings: PackedStringArray
) -> Dictionary:
	var text: String = raw_value.strip_edges()
	if cell_type == "s":
		if not text.is_valid_int():
			return {
				"success": false,
				"value": "",
				"error": "XLSX shared string index is invalid: %s." % text,
			}
		var shared_index: int = text.to_int()
		if shared_index < 0 or shared_index >= shared_strings.size():
			return {
				"success": false,
				"value": "",
				"error": "XLSX shared string index is out of range: %d." % shared_index,
			}
		return {
			"success": true,
			"value": shared_strings[shared_index],
			"error": "",
		}
	if cell_type == "b":
		return {
			"success": true,
			"value": "true" if text == "1" else "false",
			"error": "",
		}
	return {
		"success": true,
		"value": raw_value,
		"error": "",
	}


func _xlsx_column_index_from_cell_ref(cell_ref: String) -> int:
	var result: int = 0
	var has_letters: bool = false
	for index: int in range(cell_ref.length()):
		var character: String = cell_ref.substr(index, 1).to_upper()
		var code: int = character.unicode_at(0)
		if code < 65 or code > 90:
			break
		result = result * 26 + code - 64
		has_letters = true
	return result - 1 if has_letters else -1


func _parse_positive_int(text: String, fallback_value: int) -> int:
	if text.is_valid_int():
		return maxi(text.to_int(), 1)
	return fallback_value


func _zip_read_bytes(
	archive_session: Dictionary,
	files: PackedStringArray,
	path: String,
	max_bytes: int
) -> Dictionary:
	if not _zip_has_file(files, path):
		return {
			"success": true,
			"exists": false,
			"bytes": PackedByteArray(),
			"error": "",
		}
	var read_result: Dictionary = _GF_BOUNDED_ZIP_SUPPORT.read_entry(
		archive_session,
		path,
		max_bytes
	)
	if not GFVariantData.get_option_bool(read_result, "ok"):
		return {
			"success": false,
			"exists": true,
			"bytes": PackedByteArray(),
			"error": "XLSX entry read failed: %s (%s)" % [
				path,
				GFVariantData.get_option_string(read_result, "error"),
			],
		}
	return {
		"success": true,
		"exists": true,
		"bytes": _get_packed_byte_array_value(
			GFVariantData.get_option_value(read_result, "bytes")
		),
		"error": "",
	}


func _zip_has_file(files: PackedStringArray, path: String) -> bool:
	if path.is_empty():
		return false
	return files.has(path)


func _close_zip_session(archive_session: Dictionary) -> Error:
	return _GF_BOUNDED_ZIP_SUPPORT.close_archive(
		archive_session
	)


func _normalize_xlsx_relationship_target(base_path: String, target: String) -> String:
	var normalized_target: String = target.replace("\\", "/")
	if normalized_target.begins_with("/"):
		return _normalize_zip_path(normalized_target.trim_prefix("/"))
	return _normalize_zip_path("%s/%s" % [base_path.get_base_dir(), normalized_target])


func _normalize_zip_path(path: String) -> String:
	var stack: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = path.split("/", false)
	for part: String in parts:
		if part.is_empty() or part == ".":
			continue
		if part == "..":
			if stack.is_empty():
				return ""
			stack.remove_at(stack.size() - 1)
			continue
		var _part_appended: bool = stack.append(part)
	return "/".join(stack)


func _get_xml_attribute(parser: XMLParser, attribute_name: String) -> String:
	for attribute_index: int in range(parser.get_attribute_count()):
		if parser.get_attribute_name(attribute_index) == attribute_name:
			return parser.get_attribute_value(attribute_index)
	return ""


func _get_xml_attribute_any(parser: XMLParser, attribute_names: PackedStringArray) -> String:
	for attribute_name: String in attribute_names:
		var value: String = _get_xml_attribute(parser, attribute_name)
		if not value.is_empty():
			return value
	return ""


func _make_xlsx_parse_failure(
	message: String,
	source: String,
	line: int = 0,
	column: int = 0
) -> Dictionary:
	return {
		"success": false,
		"data": null,
		"row_locations": [],
		"error": message,
		"error_line": line,
		"error_column": column,
		"source": source,
	}


func _get_xlsx_limit(options: Dictionary, key: String, default_value: int) -> int:
	if not options.has(key):
		return default_value
	return maxi(GFVariantData.get_option_int(options, key, default_value), 0)


func _is_xlsx_limit_exceeded(value: int, limit: int) -> bool:
	return limit > 0 and value > limit


func _xlsx_archive_inspection_error(inspection: Dictionary) -> String:
	var codes: PackedStringArray = _get_packed_string_array_value(
		GFVariantData.get_option_value(inspection, "issue_codes")
	)
	if codes.has("archive_size_limit"):
		return "XLSX file exceeds max_xlsx_file_bytes."
	if codes.has("entry_count_limit"):
		return "XLSX archive exceeds max_xlsx_entry_count."
	if codes.has("entry_size_limit"):
		return "XLSX archive entry exceeds max_xlsx_entry_bytes."
	if codes.has("total_size_limit"):
		return "XLSX archive exceeds max_xlsx_total_uncompressed_bytes."
	if codes.has("compression_ratio_limit"):
		return "XLSX archive exceeds max_xlsx_compression_ratio."
	if codes.has("path_length_limit"):
		return "XLSX archive entry exceeds max_xlsx_path_length."
	if codes.has("path_depth_limit"):
		return "XLSX archive entry exceeds max_xlsx_path_depth."
	var issues: PackedStringArray = _get_packed_string_array_value(
		GFVariantData.get_option_value(inspection, "issues")
	)
	if not issues.is_empty():
		return "XLSX archive preflight failed: %s" % issues[0]
	return "XLSX archive preflight failed."


func _get_packed_byte_array_value(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		var array_value: PackedByteArray = value
		return array_value
	return PackedByteArray()


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var array_value: PackedStringArray = value
		return array_value
	return PackedStringArray()


func _get_dictionary_array_value(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var array_value: Array = value
	for item_value: Variant in array_value:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			result.append(item)
	return result


func _make_layout_failure(
	error_kind: String,
	message: String,
	source_path: String = "",
	resolved_format: StringName = &"",
	error_code: int = ERR_INVALID_DATA,
	context: Dictionary = {}
) -> Dictionary:
	return {
		"success": false,
		"phase": "layout",
		"data": null,
		"header": PackedStringArray(),
		"row_locations": [],
		"source": source_path,
		"source_path": source_path,
		"format": resolved_format,
		"error_kind": error_kind,
		"error_code": error_code,
		"error": message,
		"error_line": 0,
		"error_column": 0,
		"context": context.duplicate(true),
	}
