## GFDialogueTextCompiler: 对话 JSON 文本编译器。
##
## 在制作期、编辑器期或 CI 中把严格、可审计的 JSON 文本编译为 GFDialogueResource。
## strict 边界拒绝重复 member、宽松 JSON、非法 Unicode、int64 外整数、非有限、
## 溢出或规范化十进制指数不在 -307..308 的非零浮点，并以显式硬预算约束工作量。
## 编译器只解释对话资源已有字段，不定义角色、任务、本地化、UI 或项目状态语义。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFDialogueTextCompiler
extends RefCounted


# --- 常量 ---

## 对话文本格式标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const SOURCE_FORMAT: String = "gf.dialogue"

## 当前对话文本 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
const SOURCE_SCHEMA_VERSION: int = 1

const _JSON_SOURCE_PARSER_SCRIPT = preload("res://addons/gf/tools/dialogue_text/gf_dialogue_json_source_parser.gd")
const _REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _DEFAULT_MAX_TEXT_BYTES: int = 4 * 1024 * 1024
const _DEFAULT_MAX_DEPTH: int = 64
const _DEFAULT_MAX_NODES: int = 65_536
const _DEFAULT_MAX_STRING_BYTES: int = 1024 * 1024
const _DEFAULT_MAX_LINES: int = 4096
const _DEFAULT_MAX_RESPONSES: int = 16_384
const _DEFAULT_MAX_DIAGNOSTICS: int = 256
const _HARD_MAX_TEXT_BYTES: int = 16 * 1024 * 1024
const _HARD_MAX_DEPTH: int = 64
const _HARD_MAX_NODES: int = 262_144
const _HARD_MAX_STRING_BYTES: int = 4 * 1024 * 1024
const _HARD_MAX_LINES: int = 16_384
const _HARD_MAX_RESPONSES: int = 65_536
const _HARD_MAX_DIAGNOSTICS: int = 1024
const _TOP_LEVEL_FIELDS: PackedStringArray = [
	"format",
	"schema_version",
	"start_line_id",
	"lines",
	"metadata",
]
const _LINE_FIELDS: PackedStringArray = [
	"line_id",
	"kind",
	"speaker_id",
	"text",
	"next_line_id",
	"jump_line_id",
	"condition_id",
	"condition_payload",
	"fallback_line_id",
	"mutation_id",
	"mutation_payload",
	"responses",
	"tags",
	"metadata",
]
const _RESPONSE_FIELDS: PackedStringArray = [
	"response_id",
	"text",
	"next_line_id",
	"condition_id",
	"condition_payload",
	"mutation_id",
	"mutation_payload",
	"tags",
	"metadata",
]


# --- 公共方法 ---

## 编译 JSON 文本。
##
## 未知结构字段会作为错误报告；项目扩展数据应放入 metadata 或 payload 字段。
## 所有语法、schema 和资源图错误都携带 URI fragment JSON Pointer 与 source span；
## report 是有界 JSON-safe 的本地制作期投影并保留显式 source_path。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param text: UTF-8 strict JSON 文本；object member 必须唯一，整数限 int64，非零浮点的规范化十进制指数限 -307..308。
## [br]
## @param options: 编译选项，支持 source_path、subject、metadata，以及受框架硬上限约束的 max_text_bytes、max_depth、max_nodes、max_string_bytes、max_lines、max_responses 和 max_diagnostics 正整数预算。
## [br]
## @schema options: Dictionary，可包含 source_path、subject、报告 metadata 与严格正整数预算；0、负数、错误类型或超过框架硬上限都会失败关闭。
## [br]
## @return 编译结果。
## [br]
## @schema return: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null 且 line_count 为 0，report 可安全传给 JSON.stringify()。
func compile_text(text: String, options: Dictionary = {}) -> Dictionary:
	var source_path: String = GFVariantData.get_option_string(options, "source_path", "<memory>")
	var subject: String = GFVariantData.get_option_string(options, "subject", "Dialogue text compile")
	var report: GFValidationReport = GFValidationReport.new(
		subject,
		_sanitize_report_metadata(GFVariantData.get_option_value(options, "metadata"))
	)
	var limits: Dictionary = _resolve_limits(options, report, source_path)
	if not report.is_ok():
		return _make_result(null, report, source_path, "")
	var text_byte_count: int = text.to_utf8_buffer().size()
	if text_byte_count > GFVariantData.get_option_int(limits, "max_text_bytes"):
		_add_unlocated_error(
			report,
			&"input_budget_exceeded",
			"Dialogue source exceeds max_text_bytes before parsing.",
			source_path,
			"#",
			{
				"actual_bytes": text_byte_count,
				"max_text_bytes": GFVariantData.get_option_int(limits, "max_text_bytes"),
			}
		)
		return _make_result(null, report, source_path, "")

	var content_hash: String = text.sha256_text()
	var source_parser: _JSON_SOURCE_PARSER_SCRIPT = _JSON_SOURCE_PARSER_SCRIPT.new()
	var parse_result: Dictionary = source_parser.parse_text(text, limits)
	var provenance: Dictionary = _make_provenance(parse_result, limits)
	if not GFVariantData.get_option_bool(parse_result, "ok"):
		_add_error_at_explicit_span(
			report,
			GFVariantData.get_option_string_name(parse_result, "error_kind", &"invalid_json"),
			GFVariantData.get_option_string(parse_result, "error", "Strict JSON parsing failed."),
			source_path,
			GFVariantData.get_option_string(parse_result, "pointer"),
			GFVariantData.get_option_dictionary(parse_result, "span"),
			GFVariantData.get_option_dictionary(parse_result, "metadata"),
			provenance
		)
		return _make_result(null, report, source_path, content_hash)

	var root_value: Variant = GFVariantData.get_option_value(parse_result, "value")
	if not (root_value is Dictionary):
		_add_error(report, &"invalid_root_type", "Dialogue source root must be a JSON object.", source_path, "", provenance)
		return _make_result(null, report, source_path, content_hash)

	var source: Dictionary = root_value
	if not _validate_document_budgets(source, report, source_path, provenance, limits):
		return _make_result(null, report, source_path, content_hash)
	var resource: GFDialogueResource = _compile_dictionary(
		source,
		report,
		source_path,
		provenance
	)
	return _make_result(resource, report, source_path, content_hash)


## 通过受根路径约束的源码加载器编译文本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param source_key: 注册文本 key 或加载器根目录内的相对路径。
## [br]
## @param loader: 源码文本加载器。
## [br]
## @param options: 编译选项；source_path 会默认使用加载结果路径，预算选项与 compile_text() 相同。loader.max_bytes 必须为正且不大于有效 max_text_bytes，确保读取阶段先受同一上界约束。
## [br]
## @schema options: Dictionary，支持 compile_text() 的选项。
## [br]
## @return 编译结果。
## [br]
## @schema return: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null 且 line_count 为 0，report 可安全传给 JSON.stringify()。
func compile_source(
	source_key: String,
	loader: GFSourceTextLoader,
	options: Dictionary = {}
) -> Dictionary:
	var subject: String = GFVariantData.get_option_string(options, "subject", "Dialogue text compile")
	var report: GFValidationReport = GFValidationReport.new(
		subject,
		_sanitize_report_metadata(GFVariantData.get_option_value(options, "metadata"))
	)
	var limits: Dictionary = _resolve_limits(options, report, source_key)
	if not report.is_ok():
		return _make_result(null, report, source_key, "")
	if loader == null:
		_add_unlocated_error(report, &"missing_source_loader", "Dialogue source loader is null.", source_key, "#")
		return _make_result(null, report, source_key, "")
	var max_text_bytes: int = GFVariantData.get_option_int(limits, "max_text_bytes")
	if loader.max_bytes <= 0 or loader.max_bytes > max_text_bytes:
		_add_unlocated_error(
			report,
			&"unsafe_source_loader_budget",
			"Source loader max_bytes must be positive and no larger than the compiler max_text_bytes.",
			source_key,
			"#",
			{
				"loader_max_bytes": loader.max_bytes,
				"max_text_bytes": max_text_bytes,
			}
		)
		return _make_result(null, report, source_key, "")

	var load_result: Dictionary = loader.load_text(source_key)
	if not GFResultDictionary.is_ok(load_result):
		var loader_report_value: Variant = GFVariantData.get_option_value(load_result, "report")
		var safe_loader_report: Dictionary = _REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(
			loader_report_value,
			_make_report_codec_options()
		)
		_capture_owned_next_action(report, safe_loader_report)
		var _merge_result: RefCounted = report.merge(safe_loader_report)
		_add_unlocated_error(report, &"source_load_failed", "Dialogue source could not be loaded.", source_key, "#")
		return _make_result(null, report, source_key, "")

	var compile_options: Dictionary = options.duplicate()
	if not compile_options.has("source_path"):
		compile_options["source_path"] = GFVariantData.get_option_string(load_result, "resolved_path", source_key)
	return compile_text(GFVariantData.get_option_string(load_result, "text"), compile_options)


# --- 私有/辅助方法 ---

func _compile_dictionary(
	source: Dictionary,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> GFDialogueResource:
	_validate_allowed_fields(source, _TOP_LEVEL_FIELDS, "", report, source_path, provenance)
	_validate_header(source, report, source_path, provenance)

	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = _read_string_name(source, "start_line_id", "", report, source_path, provenance)
	resource.metadata = _read_dictionary(source, "metadata", "", report, source_path, provenance)

	var lines_value: Variant = GFVariantData.get_option_value(source, "lines")
	if not (lines_value is Array):
		_add_error(report, &"invalid_field_type", "Field #/lines must be an array.", source_path, "/lines", provenance)
		return resource

	var line_entries: Array = lines_value
	if line_entries.is_empty():
		_add_error(report, &"empty_lines", "Dialogue source must contain at least one line.", source_path, "/lines", provenance)
	for line_index: int in range(line_entries.size()):
		var line_value: Variant = line_entries[line_index]
		var line_path: String = "/lines/%d" % line_index
		if not (line_value is Dictionary):
			_add_error(report, &"invalid_line_type", "Dialogue line must be an object.", source_path, line_path, provenance)
			continue
		var line_data: Dictionary = line_value
		var line: GFDialogueLine = _compile_line(line_data, line_path, report, source_path, provenance)
		resource.lines.append(line)

	var resource_report: Dictionary = resource.validate_resource()
	_merge_resource_report(report, resource_report, source_path, provenance)
	return resource


func _validate_header(
	source: Dictionary,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> void:
	var format_value: Variant = GFVariantData.get_option_value(source, "format")
	if not (format_value is String) or format_value != SOURCE_FORMAT:
		_add_error(
			report,
			&"invalid_source_format",
			"Field #/format must equal %s." % SOURCE_FORMAT,
			source_path,
			"/format",
			provenance
		)

	var version_value: Variant = GFVariantData.get_option_value(source, "schema_version")
	var parsed_version: int = -1
	if version_value is int:
		parsed_version = version_value
	elif version_value is float:
		var float_version: float = version_value
		if not is_nan(float_version) and not is_inf(float_version) and float_version == floorf(float_version):
			parsed_version = int(float_version)
	if parsed_version != SOURCE_SCHEMA_VERSION:
		_add_error(
			report,
			&"unsupported_schema_version",
			"Field #/schema_version must equal %d." % SOURCE_SCHEMA_VERSION,
			source_path,
			"/schema_version",
			provenance
		)


func _compile_line(
	data: Dictionary,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> GFDialogueLine:
	_validate_allowed_fields(data, _LINE_FIELDS, path, report, source_path, provenance)
	var line: GFDialogueLine = GFDialogueLine.new()
	line.line_id = _read_string_name(data, "line_id", path, report, source_path, provenance, true)
	line.kind = _read_line_kind(data, path, report, source_path, provenance) as GFDialogueLine.LineKind
	line.speaker_id = _read_string_name(data, "speaker_id", path, report, source_path, provenance)
	line.text = _read_string(data, "text", path, report, source_path, provenance)
	line.next_line_id = _read_string_name(data, "next_line_id", path, report, source_path, provenance)
	line.jump_line_id = _read_string_name(data, "jump_line_id", path, report, source_path, provenance)
	line.condition_id = _read_string_name(data, "condition_id", path, report, source_path, provenance)
	line.condition_payload = _read_payload(data, "condition_payload")
	line.fallback_line_id = _read_string_name(data, "fallback_line_id", path, report, source_path, provenance)
	line.mutation_id = _read_string_name(data, "mutation_id", path, report, source_path, provenance)
	line.mutation_payload = _read_payload(data, "mutation_payload")
	line.tags = _read_tags(data, "tags", path, report, source_path, provenance)
	line.metadata = _read_dictionary(data, "metadata", path, report, source_path, provenance)
	_record_line_provenance(line, path, source_path, provenance)

	var responses_value: Variant = GFVariantData.get_option_value(data, "responses", [])
	if not (responses_value is Array):
		var responses_pointer: String = _append_pointer(path, "responses")
		_add_error(
			report,
			&"invalid_field_type",
			"Field %s must be an array." % _pointer_to_uri_fragment(responses_pointer),
			source_path,
			responses_pointer,
			provenance
		)
		return line
	var response_entries: Array = responses_value
	for response_index: int in range(response_entries.size()):
		var response_value: Variant = response_entries[response_index]
		var response_path: String = "%s/responses/%d" % [path, response_index]
		if not (response_value is Dictionary):
			_add_error(report, &"invalid_response_type", "Dialogue response must be an object.", source_path, response_path, provenance)
			continue
		var response_data: Dictionary = response_value
		line.responses.append(_compile_response(
			response_data,
			response_path,
			line.line_id,
			report,
			source_path,
			provenance
		))
	return line


func _compile_response(
	data: Dictionary,
	path: String,
	line_id: StringName,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> GFDialogueResponse:
	_validate_allowed_fields(data, _RESPONSE_FIELDS, path, report, source_path, provenance)
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = _read_string_name(data, "response_id", path, report, source_path, provenance, true)
	response.text = _read_string(data, "text", path, report, source_path, provenance)
	response.next_line_id = _read_string_name(data, "next_line_id", path, report, source_path, provenance)
	response.condition_id = _read_string_name(data, "condition_id", path, report, source_path, provenance)
	response.condition_payload = _read_payload(data, "condition_payload")
	response.mutation_id = _read_string_name(data, "mutation_id", path, report, source_path, provenance)
	response.mutation_payload = _read_payload(data, "mutation_payload")
	response.tags = _read_tags(data, "tags", path, report, source_path, provenance)
	response.metadata = _read_dictionary(data, "metadata", path, report, source_path, provenance)
	_record_response_provenance(response, line_id, path, source_path, provenance)
	return response


func _read_line_kind(
	data: Dictionary,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> int:
	if not data.has("kind"):
		return GFDialogueLine.LineKind.TEXT
	var value: Variant = data["kind"]
	if value is String:
		var kind_name: String = value
		match kind_name:
			"text":
				return GFDialogueLine.LineKind.TEXT
			"mutation":
				return GFDialogueLine.LineKind.MUTATION
			"jump":
				return GFDialogueLine.LineKind.JUMP
			"end":
				return GFDialogueLine.LineKind.END
	_add_error(
		report,
		&"invalid_line_kind",
		"Field %s must be one of text, mutation, jump, or end."
		% _pointer_to_uri_fragment(_append_pointer(path, "kind")),
		source_path,
		_append_pointer(path, "kind"),
		provenance
	)
	return GFDialogueLine.LineKind.TEXT


func _read_string_name(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary,
	required: bool = false
) -> StringName:
	if not data.has(field):
		if required:
			var missing_pointer: String = _append_pointer(path, field)
			_add_error(
				report,
				&"missing_required_field",
				"Missing required field %s." % _pointer_to_uri_fragment(missing_pointer),
				source_path,
				missing_pointer,
				provenance
			)
		return &""
	var value: Variant = data[field]
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	var field_pointer: String = _append_pointer(path, field)
	_add_error(
		report,
		&"invalid_field_type",
		"Field %s must be a string." % _pointer_to_uri_fragment(field_pointer),
		source_path,
		field_pointer,
		provenance
	)
	return &""


func _read_string(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> String:
	if not data.has(field):
		return ""
	var value: Variant = data[field]
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	var field_pointer: String = _append_pointer(path, field)
	_add_error(
		report,
		&"invalid_field_type",
		"Field %s must be a string." % _pointer_to_uri_fragment(field_pointer),
		source_path,
		field_pointer,
		provenance
	)
	return ""


func _read_dictionary(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> Dictionary:
	if not data.has(field):
		return {}
	var value: Variant = data[field]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	var field_pointer: String = _append_pointer(path, field)
	_add_error(
		report,
		&"invalid_field_type",
		"Field %s must be an object." % _pointer_to_uri_fragment(field_pointer),
		source_path,
		field_pointer,
		provenance
	)
	return {}


func _read_payload(data: Dictionary, field: String) -> Variant:
	if not data.has(field):
		return null
	return GFVariantData.duplicate_variant(data[field])


func _read_tags(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not data.has(field):
		return result
	var value: Variant = data[field]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if not (value is Array):
		var tags_pointer: String = _append_pointer(path, field)
		_add_error(
			report,
			&"invalid_field_type",
			"Field %s must be an array of strings." % _pointer_to_uri_fragment(tags_pointer),
			source_path,
			tags_pointer,
			provenance
		)
		return result
	var entries: Array = value
	for tag_index: int in range(entries.size()):
		var tag_value: Variant = entries[tag_index]
		if tag_value is String:
			var tag_text: String = tag_value
			var _append_result: bool = result.append(tag_text)
		elif tag_value is StringName:
			var tag_name: StringName = tag_value
			var _append_name_result: bool = result.append(String(tag_name))
		else:
			var tag_pointer: String = "%s/%d" % [_append_pointer(path, field), tag_index]
			_add_error(
				report,
				&"invalid_tag_type",
				"Field %s must be a string." % _pointer_to_uri_fragment(tag_pointer),
				source_path,
				tag_pointer,
				provenance
			)
	return result


func _validate_allowed_fields(
	data: Dictionary,
	allowed_fields: PackedStringArray,
	path: String,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> void:
	for key_value: Variant in data.keys():
		if not (key_value is String or key_value is StringName):
			_add_error(report, &"invalid_field_name", "Field names must be strings.", source_path, path, provenance, true)
			continue
		var key_text: String = GFVariantData.to_text(key_value)
		if allowed_fields.has(key_text):
			continue
		var field_pointer: String = _append_pointer(path, key_text)
		_add_error(
			report,
			&"unknown_field",
			"Unknown dialogue source field at %s; use metadata for project-defined data."
			% _pointer_to_uri_fragment(field_pointer),
			source_path,
			field_pointer,
			provenance,
			true
		)


func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	source_path: String,
	field_pointer: String,
	provenance: Dictionary,
	prefer_key_span: bool = false,
	metadata: Dictionary = {}
) -> void:
	if not _reserve_diagnostic_slot(report, source_path, provenance):
		return
	var span_data: Dictionary = _find_source_span(
		provenance,
		field_pointer,
		prefer_key_span
	)
	_add_error_at_explicit_span(
		report,
		kind,
		message,
		source_path,
		field_pointer,
		span_data,
		metadata,
		provenance,
		false
	)


func _resolve_limits(
	options: Dictionary,
	report: GFValidationReport,
	source_path: String
) -> Dictionary:
	var definitions: Array[Dictionary] = [
		{ "key": "max_text_bytes", "default": _DEFAULT_MAX_TEXT_BYTES, "hard": _HARD_MAX_TEXT_BYTES },
		{ "key": "max_depth", "default": _DEFAULT_MAX_DEPTH, "hard": _HARD_MAX_DEPTH },
		{ "key": "max_nodes", "default": _DEFAULT_MAX_NODES, "hard": _HARD_MAX_NODES },
		{ "key": "max_string_bytes", "default": _DEFAULT_MAX_STRING_BYTES, "hard": _HARD_MAX_STRING_BYTES },
		{ "key": "max_lines", "default": _DEFAULT_MAX_LINES, "hard": _HARD_MAX_LINES },
		{ "key": "max_responses", "default": _DEFAULT_MAX_RESPONSES, "hard": _HARD_MAX_RESPONSES },
		{ "key": "max_diagnostics", "default": _DEFAULT_MAX_DIAGNOSTICS, "hard": _HARD_MAX_DIAGNOSTICS },
	]
	var result: Dictionary = {}
	for definition: Dictionary in definitions:
		var key: String = GFVariantData.get_option_string(definition, "key")
		var default_limit: int = GFVariantData.get_option_int(definition, "default")
		var hard_limit: int = GFVariantData.get_option_int(definition, "hard")
		if not options.has(key):
			result[key] = default_limit
			continue
		var raw_limit: Variant = options[key]
		if not (raw_limit is int):
			_add_unlocated_error(
				report,
				&"invalid_compile_option",
				"Dialogue compiler limits must be strict integers.",
				source_path,
				"#",
				{ "option": key, "hard_max": hard_limit }
			)
			result[key] = default_limit
			continue
		var requested_limit: int = raw_limit
		if requested_limit <= 0 or requested_limit > hard_limit:
			_add_unlocated_error(
				report,
				&"invalid_compile_option",
				"Dialogue compiler limits must be positive and no larger than the framework hard maximum.",
				source_path,
				"#",
				{ "option": key, "hard_max": hard_limit }
			)
			result[key] = default_limit
			continue
		result[key] = requested_limit
	return result


func _make_provenance(parse_result: Dictionary, limits: Dictionary) -> Dictionary:
	return {
		"value_spans": GFVariantData.get_option_dictionary(parse_result, "value_spans"),
		"key_spans": GFVariantData.get_option_dictionary(parse_result, "key_spans"),
		"max_diagnostics": GFVariantData.get_option_int(
			limits,
			"max_diagnostics",
			_DEFAULT_MAX_DIAGNOSTICS
		),
		"diagnostic_budget_reported": false,
		"line_occurrences": {},
		"response_occurrences": {},
		"transition_occurrences": {},
		"automatic_transition_occurrences": {},
		"resource_subject_occurrences": {},
	}


func _validate_document_budgets(
	source: Dictionary,
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary,
	limits: Dictionary
) -> bool:
	var lines_value: Variant = GFVariantData.get_option_value(source, "lines")
	if not (lines_value is Array):
		return true
	var lines: Array = lines_value
	var max_lines: int = GFVariantData.get_option_int(limits, "max_lines", _DEFAULT_MAX_LINES)
	if lines.size() > max_lines:
		_add_error(
			report,
			&"input_budget_exceeded",
			"Dialogue source exceeds max_lines before Resource construction.",
			source_path,
			"/lines",
			provenance,
			false,
			{ "actual_lines": lines.size(), "max_lines": max_lines }
		)
		return false
	var max_responses: int = GFVariantData.get_option_int(
		limits,
		"max_responses",
		_DEFAULT_MAX_RESPONSES
	)
	var response_count: int = 0
	for line_index: int in range(lines.size()):
		var line_value: Variant = lines[line_index]
		if not (line_value is Dictionary):
			continue
		var line_data: Dictionary = line_value
		var responses_value: Variant = GFVariantData.get_option_value(line_data, "responses", [])
		if not (responses_value is Array):
			continue
		var responses: Array = responses_value
		if responses.size() > max_responses - response_count:
			var responses_pointer: String = "/lines/%d/responses" % line_index
			_add_error(
				report,
				&"input_budget_exceeded",
				"Dialogue source exceeds max_responses before Resource construction.",
				source_path,
				responses_pointer,
				provenance,
				false,
				{
					"consumed_responses": response_count,
					"next_response_count": responses.size(),
					"max_responses": max_responses,
				}
			)
			return false
		response_count += responses.size()
	return true


func _record_line_provenance(
	line: GFDialogueLine,
	path: String,
	_source_path: String,
	provenance: Dictionary
) -> void:
	var line_id_pointer: String = _append_pointer(path, "line_id")
	var resource_subject: String = "lines[%s]" % path.get_file()
	_record_occurrence(provenance, "resource_subject_occurrences", resource_subject, line_id_pointer)
	if line.line_id != &"":
		_record_occurrence(
			provenance,
			"line_occurrences",
			String(line.line_id),
			line_id_pointer
		)
	_record_transition_provenance(
		line.line_id,
		line.next_line_id,
		_append_pointer(path, "next_line_id"),
		provenance
	)
	_record_transition_provenance(
		line.line_id,
		line.jump_line_id,
		_append_pointer(path, "jump_line_id"),
		provenance
	)
	_record_transition_provenance(
		line.line_id,
		line.fallback_line_id,
		_append_pointer(path, "fallback_line_id"),
		provenance
	)
	if line.line_id != &"":
		var automatic_pointer: String = (
			_append_pointer(path, "jump_line_id")
			if line.kind == GFDialogueLine.LineKind.JUMP and line.jump_line_id != &""
			else _append_pointer(path, "next_line_id")
		)
		_record_occurrence(
			provenance,
			"automatic_transition_occurrences",
			String(line.line_id),
			automatic_pointer
		)


func _record_response_provenance(
	response: GFDialogueResponse,
	line_id: StringName,
	path: String,
	_source_path: String,
	provenance: Dictionary
) -> void:
	var response_id_pointer: String = _append_pointer(path, "response_id")
	var resource_subject: String = "%s.responses[%s]" % [line_id, path.get_file()]
	_record_occurrence(
		provenance,
		"resource_subject_occurrences",
		resource_subject,
		response_id_pointer
	)
	if line_id != &"" and response.response_id != &"":
		_record_occurrence(
			provenance,
			"response_occurrences",
			"%s.responses.%s" % [line_id, response.response_id],
			response_id_pointer
		)
	_record_transition_provenance(
		line_id,
		response.next_line_id,
		_append_pointer(path, "next_line_id"),
		provenance
	)


func _record_transition_provenance(
	line_id: StringName,
	target_id: StringName,
	pointer: String,
	provenance: Dictionary
) -> void:
	if line_id == &"" or target_id == &"":
		return
	_record_occurrence(
		provenance,
		"transition_occurrences",
		"%s -> %s" % [line_id, target_id],
		pointer
	)


func _record_occurrence(
	provenance: Dictionary,
	map_key: String,
	identity: String,
	pointer: String
) -> void:
	var mapping: Dictionary = GFVariantData.get_option_dictionary(provenance, map_key)
	var pointers: Array = []
	var pointers_value: Variant = GFVariantData.get_option_value(mapping, identity)
	if pointers_value is Array:
		pointers = pointers_value
	pointers.append(pointer)
	mapping[identity] = pointers
	provenance[map_key] = mapping


func _merge_resource_report(
	report: GFValidationReport,
	resource_report: Dictionary,
	source_path: String,
	provenance: Dictionary
) -> void:
	var issue_values: Array = GFVariantData.get_option_array(resource_report, "issues")
	var pointer_offsets: Dictionary = {}
	_capture_owned_next_action(report, resource_report)
	for issue_value: Variant in issue_values:
		if not _reserve_diagnostic_slot(report, source_path, provenance):
			break
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value).duplicate(true)
		var kind: StringName = GFVariantData.get_option_string_name(issue, "kind")
		var subject: String = GFVariantData.get_option_string(
			issue,
			"path",
			GFVariantData.get_option_string(issue, "subject")
		)
		var pointers: Array = _resolve_resource_issue_pointers(kind, subject, provenance)
		var primary_pointer: String = ""
		if not pointers.is_empty():
			var primary_index: int = _consume_primary_pointer_index(
				kind,
				subject,
				pointers.size(),
				pointer_offsets
			)
			primary_pointer = GFVariantData.to_text(pointers[primary_index])
		issue["path"] = _pointer_to_uri_fragment(primary_pointer)
		issue["source_span"] = _span_with_source_path(
			_find_source_span(provenance, primary_pointer),
			source_path
		)
		var issue_metadata: Dictionary = GFVariantData.get_option_dictionary(issue, "metadata")
		issue_metadata["field_path"] = _pointer_to_uri_fragment(primary_pointer)
		if kind in [&"duplicate_line_id", &"duplicate_response_id"]:
			issue_metadata["related_source_spans"] = _make_related_source_spans(
				pointers,
				provenance,
				source_path
			)
		issue["metadata"] = issue_metadata
		var _added_issue: RefCounted = report.add_issue(issue)


func _consume_primary_pointer_index(
	kind: StringName,
	subject: String,
	pointer_count: int,
	pointer_offsets: Dictionary
) -> int:
	if pointer_count <= 1:
		return 0
	if kind not in [&"duplicate_line_id", &"duplicate_response_id", &"missing_next_line"]:
		return 0
	var offset_key: String = "%s\u001F%s" % [kind, subject]
	var default_index: int = 1 if kind in [&"duplicate_line_id", &"duplicate_response_id"] else 0
	var selected_index: int = mini(
		GFVariantData.get_option_int(pointer_offsets, offset_key, default_index),
		pointer_count - 1
	)
	pointer_offsets[offset_key] = selected_index + 1
	return selected_index


func _capture_owned_next_action(
	report: GFValidationReport,
	owned_report: Dictionary
) -> void:
	if not report.issues.is_empty():
		return
	var owned_issues: Array = GFVariantData.get_option_array(owned_report, "issues")
	if owned_issues.is_empty():
		return
	report.extra_fields["_dialogue_owned_next_action"] = GFVariantData.get_option_string(
		owned_report,
		"next_action",
		"Review the first reported issue."
	)


func _resolve_resource_issue_pointers(
	kind: StringName,
	subject: String,
	provenance: Dictionary
) -> Array:
	match kind:
		&"empty_dialogue":
			return ["/lines"]
		&"missing_start_line":
			return ["/start_line_id"]
		&"duplicate_line_id":
			return _get_occurrences(provenance, "line_occurrences", subject)
		&"duplicate_response_id":
			return _get_occurrences(provenance, "response_occurrences", subject)
		&"missing_next_line":
			return _get_occurrences(provenance, "transition_occurrences", subject)
		&"automatic_cycle":
			return _get_occurrences(
				provenance,
				"automatic_transition_occurrences",
				subject
			)
	var subject_occurrences: Array = _get_occurrences(
		provenance,
		"resource_subject_occurrences",
		subject
	)
	if not subject_occurrences.is_empty():
		return subject_occurrences
	return _get_occurrences(provenance, "line_occurrences", subject)


func _get_occurrences(
	provenance: Dictionary,
	map_key: String,
	identity: String
) -> Array:
	var mapping: Dictionary = GFVariantData.get_option_dictionary(provenance, map_key)
	return GFVariantData.get_option_array(mapping, identity)


func _make_related_source_spans(
	pointers: Array,
	provenance: Dictionary,
	source_path: String
) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	for pointer_value: Variant in pointers:
		var pointer: String = GFVariantData.to_text(pointer_value)
		spans.append(_span_with_source_path(
			_find_source_span(provenance, pointer),
			source_path
		))
	return spans


func _add_unlocated_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	source_path: String,
	field_path: String,
	metadata: Dictionary = {}
) -> void:
	var span: GFSourceSpan = GFSourceSpan.new(source_path)
	var issue_metadata: Dictionary = metadata.duplicate(true)
	issue_metadata["field_path"] = field_path
	var _issue: RefCounted = report.add_source_error(
		kind,
		message,
		span,
		null,
		field_path,
		issue_metadata
	)


func _add_error_at_explicit_span(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	source_path: String,
	field_pointer: String,
	span_data: Dictionary,
	metadata: Dictionary,
	provenance: Dictionary,
	reserve_slot: bool = true
) -> void:
	if reserve_slot and not _reserve_diagnostic_slot(report, source_path, provenance):
		return
	var field_path: String = _pointer_to_uri_fragment(field_pointer)
	var issue_metadata: Dictionary = metadata.duplicate(true)
	issue_metadata["field_path"] = field_path
	if issue_metadata.has("related_source_spans"):
		var related_values: Array = GFVariantData.get_option_array(
			issue_metadata,
			"related_source_spans"
		)
		var related_spans: Array[Dictionary] = []
		for related_value: Variant in related_values:
			var related_span: Dictionary = GFVariantData.as_dictionary(related_value)
			related_spans.append(_span_with_source_path(related_span, source_path))
		issue_metadata["related_source_spans"] = related_spans
	var _issue: RefCounted = report.add_source_error(
		kind,
		message,
		_span_with_source_path(span_data, source_path),
		null,
		field_path,
		issue_metadata
	)


func _reserve_diagnostic_slot(
	report: GFValidationReport,
	source_path: String,
	provenance: Dictionary
) -> bool:
	var max_diagnostics: int = GFVariantData.get_option_int(
		provenance,
		"max_diagnostics",
		_DEFAULT_MAX_DIAGNOSTICS
	)
	if report.issues.size() < maxi(max_diagnostics - 1, 0):
		return true
	if not GFVariantData.get_option_bool(provenance, "diagnostic_budget_reported"):
		provenance["diagnostic_budget_reported"] = true
		_add_unlocated_error(
			report,
			&"diagnostic_budget_exceeded",
			"Dialogue compiler stopped after reaching max_diagnostics.",
			source_path,
			"#",
			{ "max_diagnostics": max_diagnostics }
		)
	return false


func _find_source_span(
	provenance: Dictionary,
	pointer: String,
	prefer_key_span: bool = false
) -> Dictionary:
	var key_spans: Dictionary = GFVariantData.get_option_dictionary(provenance, "key_spans")
	var value_spans: Dictionary = GFVariantData.get_option_dictionary(provenance, "value_spans")
	if prefer_key_span and key_spans.has(pointer):
		return GFVariantData.get_option_dictionary(key_spans, pointer)
	if value_spans.has(pointer):
		return GFVariantData.get_option_dictionary(value_spans, pointer)
	if key_spans.has(pointer):
		return GFVariantData.get_option_dictionary(key_spans, pointer)
	var ancestor: String = pointer
	while not ancestor.is_empty():
		var separator_index: int = ancestor.rfind("/")
		if separator_index < 0:
			break
		ancestor = ancestor.left(separator_index)
		if value_spans.has(ancestor):
			return GFVariantData.get_option_dictionary(value_spans, ancestor)
	return GFVariantData.get_option_dictionary(value_spans, "")


func _span_with_source_path(span_data: Dictionary, source_path: String) -> Dictionary:
	var result: Dictionary = span_data.duplicate(true)
	result["source_path"] = source_path
	return result


func _append_pointer(parent: String, token: String) -> String:
	return "%s/%s" % [parent, token.replace("~", "~0").replace("/", "~1")]


func _pointer_to_uri_fragment(pointer: String) -> String:
	var result: String = "#"
	for byte_value: int in pointer.to_utf8_buffer():
		if byte_value == 47 or _is_uri_unreserved_byte(byte_value):
			result += String.chr(byte_value)
		else:
			result += "%%%02X" % byte_value
	return result


func _is_uri_unreserved_byte(byte_value: int) -> bool:
	return (
		(byte_value >= 48 and byte_value <= 57)
		or (byte_value >= 65 and byte_value <= 90)
		or (byte_value >= 97 and byte_value <= 122)
		or byte_value in [45, 46, 95, 126]
	)


func _get_compiler_next_actions() -> Dictionary:
	return {
		"invalid_json": "Fix the strict JSON syntax at the reported source token.",
		"duplicate_field": "Remove the duplicate JSON object member and keep one authoritative value.",
		"invalid_unicode_escape": "Replace the invalid surrogate or Unicode escape with a valid Unicode scalar.",
		"number_out_of_range": "Use an integer inside the signed 64-bit domain.",
		"non_finite_number": "Use a finite JSON number inside the documented float domain.",
		"input_budget_exceeded": "Reduce the source structure or explicitly choose a smaller valid compilation unit.",
		"diagnostic_budget_exceeded": "Fix the earliest issues, then compile again to reveal any remaining diagnostics.",
		"invalid_compile_option": "Use strict positive integer limits no larger than the framework hard maxima.",
		"unsafe_source_loader_budget": "Configure loader.max_bytes to a positive value no larger than max_text_bytes.",
		"missing_source_loader": "Provide a configured GFSourceTextLoader.",
		"source_load_failed": "Check the source key, loader root, loader byte limit, and loader diagnostics.",
		"invalid_root_type": "Use a JSON object as the dialogue source root.",
		"unknown_field": "Move project-defined data into metadata or correct the structural field name.",
		"invalid_source_format": "Set format to gf.dialogue.",
		"unsupported_schema_version": "Set schema_version to the supported integer version or migrate the source.",
		"invalid_field_type": "Use the field type required by the dialogue source schema.",
		"empty_lines": "Add at least one dialogue line.",
		"invalid_line_type": "Replace the line entry with a JSON object.",
		"invalid_response_type": "Replace the response entry with a JSON object.",
		"invalid_line_kind": "Use text, mutation, jump, or end.",
		"missing_required_field": "Add the required non-optional source field.",
		"invalid_tag_type": "Use only JSON strings in tags.",
		"invalid_field_name": "Use JSON string member names.",
	}


func _sanitize_report_metadata(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	return _REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(
		value,
		_make_report_codec_options()
	)


func _make_report_codec_options() -> Dictionary:
	return _REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
		_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_SUPPORT,
		{
			"path_redaction": "none",
			"include_node_name": false,
			"include_node_path": false,
			"include_object_instance_id": false,
			"include_resource_path": false,
			"max_depth": 64,
			"max_string_length": 8192,
			"max_collection_items": 2048,
			"max_packed_length": 4096,
			"max_total_nodes": 32_768,
			"max_total_bytes": 4 * 1024 * 1024,
		}
	)


func _make_result(
	resource: GFDialogueResource,
	report: GFValidationReport,
	source_path: String,
	content_hash: String
) -> Dictionary:
	var success: bool = resource != null and report.is_ok()
	var runtime_fallback_action: String = GFVariantData.get_option_string(
		report.extra_fields,
		"_dialogue_owned_next_action",
		"Review the first reported issue."
	)
	var _erased_owned_next_action: bool = report.extra_fields.erase(
		"_dialogue_owned_next_action"
	)
	var raw_report: Dictionary = report.to_dict({}, {
		"next_actions": _get_compiler_next_actions(),
		"fallback_action": runtime_fallback_action,
	})
	var report_dictionary: Dictionary = _REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(
		raw_report,
		_make_report_codec_options()
	)
	return {
		"success": success,
		"resource": resource if success else null,
		"report": report_dictionary,
		"source_path": source_path,
		"content_hash": content_hash,
		"line_count": resource.lines.size() if success else 0,
	}
