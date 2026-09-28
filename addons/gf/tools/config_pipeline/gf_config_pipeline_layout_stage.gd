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
const IMPLEMENTATION_VERSION: int = 3

## XLSX 单个 ZIP 条目默认允许的压缩或解压字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_ENTRY_BYTES: int = 8 * 1024 * 1024

## XLSX 整个归档默认允许的文件字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_FILE_BYTES: int = 64 * 1024 * 1024

## XLSX ZIP 归档默认允许的条目数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_ENTRY_COUNT: int = 4096

## XLSX ZIP 条目默认允许的压缩率上限。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_COMPRESSION_RATIO: int = 100

## XLSX ZIP 条目路径默认允许的最大字符数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_PATH_LENGTH: int = 512

## XLSX ZIP 条目路径默认允许的最大目录深度。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_PATH_DEPTH: int = 32

## XLSX 工作簿默认允许读取的共享字符串数量。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_SHARED_STRINGS: int = 100000

## XLSX 工作表默认允许解析的行数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_ROWS: int = 100000

## XLSX 工作表默认允许解析的列数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_XLSX_COLUMNS: int = 512

## 提供有界 XLSX ZIP 归档读取的内部支持脚本。
## [br]
## @api private
## [br]
const _GF_BOUNDED_ZIP_SUPPORT = preload("res://addons/gf/tools/config_pipeline/gf_bounded_zip_support.gd")


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

	var source_receipt: Dictionary = GFVariantData.get_option_dictionary(
		read_result,
		"source_receipt"
	)
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
		parse_result = _parse_xlsx_file(source_path, parse_options, source_receipt)
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
	var result: Dictionary = _with_stage_result(parse_result, source_path, resolved_format)
	result["source_receipt"] = source_receipt.duplicate(true)
	return result


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract、output_contract 和 supported_formats。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contract": "gf.config_pipeline.reader_result@2",
		"output_contract": "gf.config_pipeline.layout_result@2",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_bounded_zip_support.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_importer.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
		"supported_formats": ["csv", "json", "config_file", "xlsx"],
	}


# --- 私有/辅助方法 ---

## 将解析器结果补齐为 Layout 阶段约定的来源、格式和错误字段。
## [br]
## @api private
## [br]
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


## 按文件及归档预算打开 XLSX，并以可选 Reader 收据约束文件身份；读取共享字符串、工作簿及目标表后关闭会话，清理失败优先于读取结果，成功才解析表内容。
## [br]
## @api private
func _parse_xlsx_file(
	path: String,
	options: Dictionary,
	source_receipt: Dictionary = {}
) -> Dictionary:
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

	var expected_identity: Dictionary = {}
	if not source_receipt.is_empty():
		expected_identity = {
			"size_bytes": GFVariantData.get_option_int(source_receipt, "size_bytes", -1),
			"sha256": GFVariantData.get_option_string(source_receipt, "sha256"),
		}
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
		},
		expected_identity
	)
	if not GFVariantData.get_option_bool(archive_session, "ok"):
		return _make_xlsx_parse_failure(
			_xlsx_archive_session_error(archive_session),
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
	return _parse_xlsx_sheet(worksheet_bytes, shared_strings, options, worksheet_path)


## 将 XLSX 文件大小限制中的零值解析为 ZIP 支持脚本的绝对归档上限。
## [br]
## @api private
## [br]
func _resolve_xlsx_archive_file_limit(file_limit: int) -> int:
	if file_limit != 0:
		return file_limit
	return _GF_BOUNDED_ZIP_SUPPORT.get_absolute_max_archive_bytes()


## 解析 XLSX 总解压大小限制；配置为零时使用 ZIP 支持脚本的绝对上限。
## [br]
## @api private
## [br]
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


## 有界读取共享字符串 XML，将同一 si 内各 t 的文本和 CDATA 拼接为一项；缺失内容视为空表，数量或解析失败保留部分值但返回失败状态。
## [br]
## @api private
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
	var structure_error: String = _get_xlsx_xml_structure_error(
		bytes,
		"sst",
		"xl/sharedStrings.xml"
	)
	if not structure_error.is_empty():
		return _make_xlsx_shared_strings_result(false, result, structure_error)

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return _make_xlsx_shared_strings_result(false, result, "XLSX sharedStrings.xml parse failed: %s" % error_string(open_error))

	var max_shared_strings: int = _get_xlsx_limit(options, "max_xlsx_shared_strings", _DEFAULT_MAX_XLSX_SHARED_STRINGS)
	var current_text: String = ""
	var in_shared_string: bool = false
	var in_text: bool = false
	var read_error: Error = OK
	while true:
		read_error = parser.read()
		if read_error != OK:
			break
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
	if read_error != ERR_FILE_EOF:
		return _make_xlsx_shared_strings_result(
			false,
			result,
			"XLSX xl/sharedStrings.xml parse failed: %s." % error_string(read_error)
		)
	return _make_xlsx_shared_strings_result(true, result)


## 统一构造共享字符串读取结果，并复制传入的 PackedStringArray。
## [br]
## @api private
## [br]
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


## 读取工作簿及关系表，将非空关系目标归一后写入对应 sheet；缺失关系保留空路径，由后续工作表选择处理。
## [br]
## @api private
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

	var sheets_result: Dictionary = _parse_xlsx_workbook_sheet_entries(workbook_bytes)
	if not GFVariantData.get_option_bool(sheets_result, "success"):
		return {
			"success": false,
			"sheets": [],
			"error": GFVariantData.get_option_string(sheets_result, "error"),
		}
	var sheets: Array[Dictionary] = _get_dictionary_array_value(
		GFVariantData.get_option_value(sheets_result, "sheets")
	)
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
	var parsed_relationships: Dictionary = _parse_xlsx_workbook_relationships(
		_get_packed_byte_array_value(
			GFVariantData.get_option_value(relationships_result, "bytes")
		)
	)
	if not GFVariantData.get_option_bool(parsed_relationships, "success"):
		return {
			"success": false,
			"sheets": [],
			"error": GFVariantData.get_option_string(parsed_relationships, "error"),
		}
	var relationships: Dictionary = GFVariantData.get_option_dictionary(
		parsed_relationships,
		"relationships"
	)
	for sheet: Dictionary in sheets:
		var relation_id: String = GFVariantData.get_option_string(sheet, "relation_id")
		var target: String = GFVariantData.get_option_string(relationships, relation_id)
		if not target.is_empty():
			sheet["path"] = _normalize_xlsx_relationship_target("xl/workbook.xml", target)
	return { "success": true, "sheets": sheets, "error": "" }


## 验证精确 workbook 根名后按文档顺序收集 sheet 的名称、编号和 r:id 或 id；此处不拒绝空标识或重复标识。
## [br]
## @api private
func _parse_xlsx_workbook_sheet_entries(bytes: PackedByteArray) -> Dictionary:
	var result: Array[Dictionary] = []
	var structure_error: String = _get_xlsx_xml_structure_error(
		bytes,
		"workbook",
		"xl/workbook.xml"
	)
	if not structure_error.is_empty():
		return {
			"success": false,
			"sheets": result,
			"error": structure_error,
		}
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return {
			"success": false,
			"sheets": result,
			"error": "XLSX xl/workbook.xml parse failed: %s." % error_string(open_error),
		}

	var read_error: Error = OK
	while true:
		read_error = parser.read()
		if read_error != OK:
			break
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
	if read_error != ERR_FILE_EOF:
		return {
			"success": false,
			"sheets": result,
			"error": "XLSX xl/workbook.xml parse failed: %s." % error_string(read_error),
		}
	return { "success": true, "sheets": result, "error": "" }


## 读取精确 Relationship 元素的 Id 和 Target，跳过空 Id，重复 Id 由后项覆盖；空关系文件作为空映射成功返回。
## [br]
## @api private
func _parse_xlsx_workbook_relationships(bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {}
	if bytes.size() == 0:
		return { "success": true, "relationships": result, "error": "" }
	var structure_error: String = _get_xlsx_xml_structure_error(
		bytes,
		"Relationships",
		"xl/_rels/workbook.xml.rels"
	)
	if not structure_error.is_empty():
		return {
			"success": false,
			"relationships": result,
			"error": structure_error,
		}

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return {
			"success": false,
			"relationships": result,
			"error": "XLSX xl/_rels/workbook.xml.rels parse failed: %s." % error_string(open_error),
		}

	var read_error: Error = OK
	while true:
		read_error = parser.read()
		if read_error != OK:
			break
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "Relationship":
			continue

		var relation_id: String = _get_xml_attribute(parser, "Id")
		if relation_id.is_empty():
			continue
		result[relation_id] = _get_xml_attribute(parser, "Target")
	if read_error != ERR_FILE_EOF:
		return {
			"success": false,
			"relationships": result,
			"error": "XLSX xl/_rels/workbook.xml.rels parse failed: %s." % error_string(read_error),
		}
	return { "success": true, "relationships": result, "error": "" }


## 优先按明确 sheet_name 查找且不回退；否则按非负索引选择关系路径，不可用时尝试标准 sheetN.xml，最终必须存在于归档列表。
## [br]
## @api private
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


## 把 v 和 inlineStr 文本收集为稀疏单元格并解析共享字符串、布尔值；无效列引用被忽略，行列预算按读取行数和列索引检查，错误附物理行列。
## [br]
## @api private
func _parse_xlsx_sheet(
	bytes: PackedByteArray,
	shared_strings: PackedStringArray,
	options: Dictionary,
	entry_path: String = "xl/worksheets/sheet.xml"
) -> Dictionary:
	var structure_error: String = _get_xlsx_xml_structure_error(
		bytes,
		"worksheet",
		entry_path
	)
	if not structure_error.is_empty():
		return _make_xlsx_parse_failure(
			structure_error,
			GFVariantData.get_option_string(options, "source")
		)
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

	var read_error: Error = OK
	while true:
		read_error = parser.read()
		if read_error != OK:
			break
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

	if read_error != ERR_FILE_EOF:
		return _make_xlsx_parse_failure(
			"XLSX %s parse failed: %s." % [entry_path, error_string(read_error)],
			GFVariantData.get_option_string(options, "source"),
			current_row_number,
			1
		)
	return _xlsx_rows_to_parse_result(rows, options)


## 将稀疏单元格展开为行数组，同时传递物理行号；复制选项后强制要求非空表头，由通用行导入器处理表头位置和跳空行。
## [br]
## @api private
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


## 将按零起始列索引存储的单元格字典展开为行；缺失列为空串，并可裁剪边缘空白。
## [br]
## @api private
## [br]
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


## 将 XLSX 单元格原始值解析为文本；共享字符串索引无效或越界时返回失败结果。
## [br]
## @api private
## [br]
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


## 从单元格引用开头的字母列名计算零起始列索引；没有字母时返回 -1。
## [br]
## @api private
## [br]
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


## 解析正整数文本；有效整数至少返回 1，无效文本返回调用方给定的回退值。
## [br]
## @api private
## [br]
func _parse_positive_int(text: String, fallback_value: int) -> int:
	if text.is_valid_int():
		return maxi(text.to_int(), 1)
	return fallback_value


## 从有界 ZIP 会话读取指定条目，并以统一字典返回存在状态、字节或错误文本。
## [br]
## @api private
## [br]
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


## 检查非空归档路径是否列在 ZIP 文件清单中。
## [br]
## @api private
## [br]
func _zip_has_file(files: PackedStringArray, path: String) -> bool:
	if path.is_empty():
		return false
	return files.has(path)


## 将归档会话关闭操作转交给有界 ZIP 支持脚本。
## [br]
## @api private
## [br]
func _close_zip_session(archive_session: Dictionary) -> Error:
	return _GF_BOUNDED_ZIP_SUPPORT.close_archive(
		archive_session
	)


## 统一关系目标的路径分隔符；根路径相对归档根解析，其余相对工作簿目录解析，随后折叠点段。
## [br]
## @api private
func _normalize_xlsx_relationship_target(base_path: String, target: String) -> String:
	var normalized_target: String = target.replace("\\", "/")
	if normalized_target.begins_with("/"):
		return _normalize_zip_path(normalized_target.trim_prefix("/"))
	return _normalize_zip_path("%s/%s" % [base_path.get_base_dir(), normalized_target])


## 折叠空段、当前目录和父目录段；父目录越过归档根时返回空串，仅做文本归一而不确认条目存在。
## [br]
## @api private
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


## 按名称读取 XML 当前元素的属性；未找到时返回空串。
## [br]
## @api private
## [br]
func _get_xml_attribute(parser: XMLParser, attribute_name: String) -> String:
	for attribute_index: int in range(parser.get_attribute_count()):
		if parser.get_attribute_name(attribute_index) == attribute_name:
			return parser.get_attribute_value(attribute_index)
	return ""


## 按给定顺序查找 XML 当前元素的属性，并返回首个非空值。
## [br]
## @api private
## [br]
func _get_xml_attribute_any(parser: XMLParser, attribute_names: PackedStringArray) -> String:
	for attribute_name: String in attribute_names:
		var value: String = _get_xml_attribute(parser, attribute_name)
		if not value.is_empty():
			return value
	return ""


## 检查精确根名、标签配对和根外文本，并要求去空白后的文档以根闭合文本结束；不接受带前缀的替代根名或闭合根后的注释。
## [br]
## @api private
func _get_xlsx_xml_structure_error(
	bytes: PackedByteArray,
	expected_root: String,
	entry_path: String
) -> String:
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return "XLSX %s parse failed: %s." % [
			entry_path,
			error_string(open_error),
		]
	var element_stack: PackedStringArray = PackedStringArray()
	var root_seen: bool = false
	var root_closed: bool = false
	var root_was_empty: bool = false
	var read_error: Error = OK
	while true:
		read_error = parser.read()
		if read_error != OK:
			break
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			if element_stack.is_empty():
				if root_seen:
					return "XLSX %s parse failed: multiple root elements." % entry_path
				if node_name != expected_root:
					return "XLSX %s parse failed: expected root %s, got %s." % [
						entry_path,
						expected_root,
						node_name,
					]
				root_seen = true
				root_was_empty = parser.is_empty()
			if not parser.is_empty():
				var _element_appended: bool = element_stack.append(node_name)
			elif element_stack.is_empty():
				root_closed = true
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if (
				element_stack.is_empty()
				or element_stack[element_stack.size() - 1] != end_name
			):
				return "XLSX %s parse failed: mismatched closing element %s." % [
					entry_path,
					end_name,
				]
			element_stack.remove_at(element_stack.size() - 1)
			if element_stack.is_empty():
				root_closed = true
		elif (
			node_type == XMLParser.NODE_TEXT
			or node_type == XMLParser.NODE_CDATA
		):
			if element_stack.is_empty() and not parser.get_node_data().strip_edges().is_empty():
				return "XLSX %s parse failed: text outside root element." % entry_path
	if read_error != ERR_FILE_EOF:
		return "XLSX %s parse failed: %s." % [
			entry_path,
			error_string(read_error),
		]
	if not root_seen or not root_closed or not element_stack.is_empty():
		return "XLSX %s parse failed: incomplete XML document." % entry_path
	var xml_text: String = bytes.get_string_from_utf8().strip_edges()
	if root_was_empty:
		if not xml_text.ends_with("/>"):
			return "XLSX %s parse failed: trailing or truncated XML content." % entry_path
	elif not xml_text.ends_with("</%s>" % expected_root):
		return "XLSX %s parse failed: trailing or truncated XML content." % entry_path
	return ""


## 构造 XLSX 解析失败结果，并保留来源以及可选的行列位置。
## [br]
## @api private
## [br]
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


## 读取 XLSX 整数限制选项；缺少键时用默认值，存在时将值钳制到非负范围。
## [br]
## @api private
## [br]
func _get_xlsx_limit(options: Dictionary, key: String, default_value: int) -> int:
	if not options.has(key):
		return default_value
	return maxi(GFVariantData.get_option_int(options, key, default_value), 0)


## 仅当限制为正数且当前值大于限制时判定超限；零表示不在此处限制。
## [br]
## @api private
## [br]
func _is_xlsx_limit_exceeded(value: int, limit: int) -> bool:
	return limit > 0 and value > limit


## 先把来源身份变化映射为收据失效，再按固定预算错误优先级生成 XLSX 提示；其他预检错误取首项，缺失诊断时给出通用失败说明。
## [br]
## @api private
func _xlsx_archive_session_error(archive_session: Dictionary) -> String:
	var direct_codes: PackedStringArray = _get_packed_string_array_value(
		GFVariantData.get_option_value(archive_session, "issue_codes")
	)
	if direct_codes.has("archive_identity_mismatch"):
		return "XLSX source changed after Reader produced its compilation receipt."
	var inspection: Dictionary = GFVariantData.get_option_dictionary(
		archive_session,
		"inspection"
	)
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


## 仅在 Variant 是 PackedByteArray 时取回数组，否则返回空数组。
## [br]
## @api private
## [br]
func _get_packed_byte_array_value(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		var array_value: PackedByteArray = value
		return array_value
	return PackedByteArray()


## 仅在 Variant 是 PackedStringArray 时取回数组，否则返回空数组。
## [br]
## @api private
## [br]
func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var array_value: PackedStringArray = value
		return array_value
	return PackedStringArray()


## 从 Variant 数组中筛出 Dictionary 项；非数组输入返回空结果。
## [br]
## @api private
## [br]
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


## 构造 Layout 阶段失败结果，并深复制可选上下文。
## [br]
## @api private
## [br]
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
