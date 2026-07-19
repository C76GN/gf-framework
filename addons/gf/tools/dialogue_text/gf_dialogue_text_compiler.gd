## GFDialogueTextCompiler: 对话 JSON 文本编译器。
##
## 在制作期、编辑器期或 CI 中把严格、可审计的 JSON 文本编译为 GFDialogueResource。
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
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param text: UTF-8 JSON 文本。
## [br]
## @param options: 编译选项，支持 source_path、subject 和 metadata。
## [br]
## @schema options: Dictionary，可包含 source_path、subject 和报告 metadata。
## [br]
## @return 编译结果。
## [br]
## @schema return: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null。
func compile_text(text: String, options: Dictionary = {}) -> Dictionary:
	var source_path: String = GFVariantData.get_option_string(options, "source_path", "<memory>")
	var subject: String = GFVariantData.get_option_string(options, "subject", "Dialogue text compile")
	var report: GFValidationReport = GFValidationReport.new(
		subject,
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		var parse_span: GFSourceSpan = GFSourceSpan.new(source_path, parser.get_error_line())
		var _parse_issue: RefCounted = report.add_source_error(
			&"invalid_json",
			"Dialogue source is not valid JSON: %s" % parser.get_error_message(),
			parse_span,
			null,
			"$"
		)
		return _make_result(null, report, source_path, text.sha256_text())

	var root_value: Variant = parser.data
	if not (root_value is Dictionary):
		_add_error(report, &"invalid_root_type", "Dialogue source root must be a JSON object.", source_path, "$")
		return _make_result(null, report, source_path, text.sha256_text())

	var source: Dictionary = root_value
	var resource: GFDialogueResource = _compile_dictionary(source, report, source_path)
	return _make_result(resource, report, source_path, text.sha256_text())


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
## @param options: 编译选项；source_path 会默认使用加载结果路径。
## [br]
## @schema options: Dictionary，支持 compile_text() 的选项。
## [br]
## @return 编译结果。
## [br]
## @schema return: Dictionary，包含 success、resource、report、source_path、content_hash 和 line_count；失败时 resource 为 null。
func compile_source(
	source_key: String,
	loader: GFSourceTextLoader,
	options: Dictionary = {}
) -> Dictionary:
	var subject: String = GFVariantData.get_option_string(options, "subject", "Dialogue text compile")
	var report: GFValidationReport = GFValidationReport.new(
		subject,
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	if loader == null:
		_add_error(report, &"missing_source_loader", "Dialogue source loader is null.", source_key, "$")
		return _make_result(null, report, source_key, "")

	var load_result: Dictionary = loader.load_text(source_key)
	if not GFResultDictionary.is_ok(load_result):
		var loader_report_value: Variant = GFVariantData.get_option_value(load_result, "report")
		var _merge_result: RefCounted = report.merge(loader_report_value)
		_add_error(report, &"source_load_failed", "Dialogue source could not be loaded.", source_key, "$")
		return _make_result(null, report, source_key, "")

	var compile_options: Dictionary = options.duplicate()
	if not compile_options.has("source_path"):
		compile_options["source_path"] = GFVariantData.get_option_string(load_result, "resolved_path", source_key)
	return compile_text(GFVariantData.get_option_string(load_result, "text"), compile_options)


# --- 私有/辅助方法 ---

func _compile_dictionary(
	source: Dictionary,
	report: GFValidationReport,
	source_path: String
) -> GFDialogueResource:
	_validate_allowed_fields(source, _TOP_LEVEL_FIELDS, "$", report, source_path)
	_validate_header(source, report, source_path)

	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = _read_string_name(source, "start_line_id", "$", report, source_path)
	resource.metadata = _read_dictionary(source, "metadata", "$", report, source_path)

	var lines_value: Variant = GFVariantData.get_option_value(source, "lines")
	if not (lines_value is Array):
		_add_error(report, &"invalid_field_type", "Field $.lines must be an array.", source_path, "$.lines")
		return resource

	var line_entries: Array = lines_value
	if line_entries.is_empty():
		_add_error(report, &"empty_lines", "Dialogue source must contain at least one line.", source_path, "$.lines")
	for line_index: int in range(line_entries.size()):
		var line_value: Variant = line_entries[line_index]
		var line_path: String = "$.lines[%d]" % line_index
		if not (line_value is Dictionary):
			_add_error(report, &"invalid_line_type", "Dialogue line must be an object.", source_path, line_path)
			continue
		var line_data: Dictionary = line_value
		var line: GFDialogueLine = _compile_line(line_data, line_path, report, source_path)
		resource.lines.append(line)

	var resource_report: Dictionary = resource.validate_resource()
	var _resource_report_merged: RefCounted = report.merge(resource_report, false)
	return resource


func _validate_header(source: Dictionary, report: GFValidationReport, source_path: String) -> void:
	var format_value: Variant = GFVariantData.get_option_value(source, "format")
	if not (format_value is String) or format_value != SOURCE_FORMAT:
		_add_error(
			report,
			&"invalid_source_format",
			"Field $.format must equal %s." % SOURCE_FORMAT,
			source_path,
			"$.format"
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
			"Field $.schema_version must equal %d." % SOURCE_SCHEMA_VERSION,
			source_path,
			"$.schema_version"
		)


func _compile_line(
	data: Dictionary,
	path: String,
	report: GFValidationReport,
	source_path: String
) -> GFDialogueLine:
	_validate_allowed_fields(data, _LINE_FIELDS, path, report, source_path)
	var line: GFDialogueLine = GFDialogueLine.new()
	line.line_id = _read_string_name(data, "line_id", path, report, source_path, true)
	line.kind = _read_line_kind(data, path, report, source_path) as GFDialogueLine.LineKind
	line.speaker_id = _read_string_name(data, "speaker_id", path, report, source_path)
	line.text = _read_string(data, "text", path, report, source_path)
	line.next_line_id = _read_string_name(data, "next_line_id", path, report, source_path)
	line.jump_line_id = _read_string_name(data, "jump_line_id", path, report, source_path)
	line.condition_id = _read_string_name(data, "condition_id", path, report, source_path)
	line.condition_payload = _read_payload(data, "condition_payload")
	line.fallback_line_id = _read_string_name(data, "fallback_line_id", path, report, source_path)
	line.mutation_id = _read_string_name(data, "mutation_id", path, report, source_path)
	line.mutation_payload = _read_payload(data, "mutation_payload")
	line.tags = _read_tags(data, "tags", path, report, source_path)
	line.metadata = _read_dictionary(data, "metadata", path, report, source_path)

	var responses_value: Variant = GFVariantData.get_option_value(data, "responses", [])
	if not (responses_value is Array):
		_add_error(report, &"invalid_field_type", "Field %s.responses must be an array." % path, source_path, "%s.responses" % path)
		return line
	var response_entries: Array = responses_value
	for response_index: int in range(response_entries.size()):
		var response_value: Variant = response_entries[response_index]
		var response_path: String = "%s.responses[%d]" % [path, response_index]
		if not (response_value is Dictionary):
			_add_error(report, &"invalid_response_type", "Dialogue response must be an object.", source_path, response_path)
			continue
		var response_data: Dictionary = response_value
		line.responses.append(_compile_response(response_data, response_path, report, source_path))
	return line


func _compile_response(
	data: Dictionary,
	path: String,
	report: GFValidationReport,
	source_path: String
) -> GFDialogueResponse:
	_validate_allowed_fields(data, _RESPONSE_FIELDS, path, report, source_path)
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = _read_string_name(data, "response_id", path, report, source_path, true)
	response.text = _read_string(data, "text", path, report, source_path)
	response.next_line_id = _read_string_name(data, "next_line_id", path, report, source_path)
	response.condition_id = _read_string_name(data, "condition_id", path, report, source_path)
	response.condition_payload = _read_payload(data, "condition_payload")
	response.mutation_id = _read_string_name(data, "mutation_id", path, report, source_path)
	response.mutation_payload = _read_payload(data, "mutation_payload")
	response.tags = _read_tags(data, "tags", path, report, source_path)
	response.metadata = _read_dictionary(data, "metadata", path, report, source_path)
	return response


func _read_line_kind(
	data: Dictionary,
	path: String,
	report: GFValidationReport,
	source_path: String
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
		"Field %s.kind must be one of text, mutation, jump, or end." % path,
		source_path,
		"%s.kind" % path
	)
	return GFDialogueLine.LineKind.TEXT


func _read_string_name(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String,
	required: bool = false
) -> StringName:
	if not data.has(field):
		if required:
			_add_error(report, &"missing_required_field", "Missing required field %s.%s." % [path, field], source_path, "%s.%s" % [path, field])
		return &""
	var value: Variant = data[field]
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	_add_error(report, &"invalid_field_type", "Field %s.%s must be a string." % [path, field], source_path, "%s.%s" % [path, field])
	return &""


func _read_string(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String
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
	_add_error(report, &"invalid_field_type", "Field %s.%s must be a string." % [path, field], source_path, "%s.%s" % [path, field])
	return ""


func _read_dictionary(
	data: Dictionary,
	field: String,
	path: String,
	report: GFValidationReport,
	source_path: String
) -> Dictionary:
	if not data.has(field):
		return {}
	var value: Variant = data[field]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	_add_error(report, &"invalid_field_type", "Field %s.%s must be an object." % [path, field], source_path, "%s.%s" % [path, field])
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
	source_path: String
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not data.has(field):
		return result
	var value: Variant = data[field]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if not (value is Array):
		_add_error(report, &"invalid_field_type", "Field %s.%s must be an array of strings." % [path, field], source_path, "%s.%s" % [path, field])
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
			_add_error(
				report,
				&"invalid_tag_type",
				"Field %s.%s[%d] must be a string." % [path, field, tag_index],
				source_path,
				"%s.%s[%d]" % [path, field, tag_index]
			)
	return result


func _validate_allowed_fields(
	data: Dictionary,
	allowed_fields: PackedStringArray,
	path: String,
	report: GFValidationReport,
	source_path: String
) -> void:
	for key_value: Variant in data.keys():
		if not (key_value is String or key_value is StringName):
			_add_error(report, &"invalid_field_name", "Field names must be strings.", source_path, path)
			continue
		var key_text: String = GFVariantData.to_text(key_value)
		if allowed_fields.has(key_text):
			continue
		_add_error(
			report,
			&"unknown_field",
			"Unknown dialogue source field %s.%s; use metadata for project-defined data." % [path, key_text],
			source_path,
			"%s.%s" % [path, key_text]
		)


func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	source_path: String,
	field_path: String
) -> void:
	var span: GFSourceSpan = GFSourceSpan.new(source_path)
	var _issue: RefCounted = report.add_source_error(
		kind,
		message,
		span,
		null,
		field_path,
		{ "field_path": field_path }
	)


func _make_result(
	resource: GFDialogueResource,
	report: GFValidationReport,
	source_path: String,
	content_hash: String
) -> Dictionary:
	var success: bool = resource != null and report.is_ok()
	var report_dictionary: Dictionary = report.to_dict({}, {
		"next_actions": {
			"invalid_json": "Fix the JSON syntax at the reported source line.",
			"unknown_field": "Move project-defined data into metadata or correct the structural field name.",
			"source_load_failed": "Check the source key, loader root, and loader diagnostics.",
		},
	})
	return {
		"success": success,
		"resource": resource if success else null,
		"report": report_dictionary,
		"source_path": source_path,
		"content_hash": content_hash,
		"line_count": resource.lines.size() if resource != null else 0,
	}
