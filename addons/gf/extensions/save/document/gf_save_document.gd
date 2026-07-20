## GFSaveDocument: 项目级版本化存档文档。
##
## 文档把项目 schema 身份、文档版本和多个独立版本化分区组合成规范载荷。
## 物理编码、校验和与文件事务仍由 GFStorageUtility 负责。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFSaveDocument
extends RefCounted


# --- 常量 ---

## 文档格式标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT_ID: String = "gf_save_document"

## 当前文档容器格式版本。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT_VERSION: int = 1

const _GF_SAVE_PERSISTED_VALUE_VALIDATOR = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")
const _DOCUMENT_FIELDS: Array = [
	"format",
	"format_version",
	"schema_id",
	"schema_version",
	"sections",
	"metadata",
]
const _SECTION_FIELDS: Array = [
	"section_id",
	"schema_version",
	"payload",
	"metadata",
]


# --- 私有变量 ---

var _schema_id: StringName = &""
var _schema_version: int = 0
var _sections: Dictionary = {}
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 配置文档头与初始分区。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param schema_id: 项目定义的稳定 schema ID。
## [br]
## @param schema_version: 文档 schema 版本。
## [br]
## @param sections: 初始分区；无效或重复分区不会写入。
## [br]
## @param metadata: 项目定义且可持久化的文档元数据。
## [br]
## @schema metadata: Dictionary with project-defined persisted metadata.
## [br]
## @return 当前文档。
func configure(
	schema_id: StringName,
	schema_version: int,
	sections: Array[GFSaveSection] = [],
	metadata: Dictionary = {}
) -> GFSaveDocument:
	_schema_id = schema_id
	_schema_version = schema_version
	_sections.clear()
	_metadata = metadata.duplicate(true)
	for section: GFSaveSection in sections:
		var _stored: bool = set_section(section)
	return self


## 获取项目 schema ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return schema ID。
func get_schema_id() -> StringName:
	return _schema_id


## 获取文档 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 文档 schema 版本。
func get_schema_version() -> int:
	return _schema_version


## 获取文档元数据副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 深复制的文档元数据。
## [br]
## @schema return: Dictionary with project-defined persisted metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 添加或替换分区。
##
## 写入前会校验分区，文档始终只持有隔离副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section: 要写入的分区。
## [br]
## @return 分区有效时返回 true。
func set_section(section: GFSaveSection) -> bool:
	if section == null:
		return false
	var validation: Dictionary = section.validate_section()
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return false
	_sections[section.get_section_id()] = section.duplicate_section()
	return true


## 检查分区是否存在。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 分区 ID。
## [br]
## @return 存在时返回 true。
func has_section(section_id: StringName) -> bool:
	return _sections.has(section_id)


## 获取分区副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 分区 ID。
## [br]
## @return 分区副本；不存在时返回 null。
func get_section(section_id: StringName) -> GFSaveSection:
	var value: Variant = GFVariantData.get_option_value(_sections, section_id)
	if value is GFSaveSection:
		var section: GFSaveSection = value
		return section.duplicate_section()
	return null


## 获取全部分区副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 按 section_id 排序的分区数组。
func get_sections() -> Array[GFSaveSection]:
	var result: Array[GFSaveSection] = []
	for section_id_text: String in get_section_ids():
		var section: GFSaveSection = get_section(StringName(section_id_text))
		if section != null:
			result.append(section)
	return result


## 获取全部分区 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 排序后的分区 ID。
func get_section_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for section_id_value: Variant in _sections.keys():
		var _appended: bool = result.append(GFVariantData.to_text(section_id_value))
	result.sort()
	return result


## 移除分区。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 分区 ID。
## [br]
## @return 原本存在时返回 true。
func remove_section(section_id: StringName) -> bool:
	return _sections.erase(section_id)


## 校验文档头、分区和持久化安全性。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_document() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	if _schema_id == &"":
		var _schema_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_document_schema_id",
			"Document schema id is required.",
			{ "path": "schema_id" }
		)
	if _schema_version <= 0:
		var _schema_version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_document_schema_version",
			"Document schema version must be positive.",
			{ "path": "schema_version", "version": _schema_version }
		)
	_append_persisted_value_issue(report, _metadata, "metadata", &"invalid_document_metadata")
	for section_id_text: String in get_section_ids():
		var section: GFSaveSection = get_section(StringName(section_id_text))
		if section == null:
			var _invalid_section_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_document_section",
				"Document section is invalid.",
				{ "path": "sections.%s" % section_id_text }
			)
			continue
		var section_validation: Dictionary = section.validate_section()
		_append_nested_issues(report, section_validation, "sections.%s" % section_id_text)
	return GFValidationReportDictionary.finalize_report(report, "Save document", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save document issue.",
		"no_action": "Save document is valid.",
	})


## 转换为规范持久化字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 文档字典。
## [br]
## @schema return: Dictionary with format, format_version, schema_id, schema_version, sections, and metadata.
func to_dict() -> Dictionary:
	var section_data: Dictionary = {}
	for section_id_text: String in get_section_ids():
		var section: GFSaveSection = get_section(StringName(section_id_text))
		if section != null:
			section_data[section_id_text] = section.to_dict()
	return {
		"format": FORMAT_ID,
		"format_version": FORMAT_VERSION,
		"schema_id": _schema_id,
		"schema_version": _schema_version,
		"sections": section_data,
		"metadata": _metadata.duplicate(true),
	}


## 创建隔离副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 文档副本。
func duplicate_document() -> GFSaveDocument:
	return GFSaveDocument.new().configure(
		_schema_id,
		_schema_version,
		get_sections(),
		_metadata
	)


## 检查持久化字典是否为当前文档容器格式。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 待检查字典。
## [br]
## @schema data: Dictionary expected to follow GFSaveDocument.to_dict().
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
static func inspect_dict(data: Dictionary) -> Dictionary:
	var report: Dictionary = { "issues": [] }
	var format_value: Variant = GFVariantData.get_option_value(data, "format")
	if typeof(format_value) != TYPE_STRING or GFVariantData.to_text(format_value) != FORMAT_ID:
		var _format_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"document_format_mismatch",
			"Save document format does not match.",
			{ "path": "format" }
		)
	var format_version_value: Variant = GFVariantData.get_option_value(data, "format_version")
	if (
		not GFVariantData.is_exact_integer(format_version_value)
		or GFVariantData.to_exact_int(format_version_value, -1) != FORMAT_VERSION
	):
		var _format_version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"unsupported_document_format_version",
			"Save document container version is unsupported.",
			{ "path": "format_version", "version": format_version_value }
		)
	_append_unknown_field_issues(report, data, _DOCUMENT_FIELDS, "")
	var schema_id_value: Variant = GFVariantData.get_option_value(data, "schema_id")
	if (
		typeof(schema_id_value) != TYPE_STRING
		and typeof(schema_id_value) != TYPE_STRING_NAME
	) or GFVariantData.to_text(schema_id_value).is_empty():
		var _schema_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_document_schema_id",
			"Document schema id is required.",
			{ "path": "schema_id" }
		)
	var schema_version_value: Variant = GFVariantData.get_option_value(data, "schema_version")
	if (
		not GFVariantData.is_exact_integer(schema_version_value)
		or GFVariantData.to_exact_int(schema_version_value) <= 0
	):
		var _schema_version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_document_schema_version",
			"Document schema version must be positive.",
			{ "path": "schema_version" }
		)
	if not GFVariantData.get_option_value(data, "sections") is Dictionary:
		var _sections_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_document_sections",
			"Document sections must be a Dictionary.",
			{ "path": "sections" }
		)
	else:
		_append_section_dict_issues(report, GFVariantData.get_option_dictionary(data, "sections"))
	if not data.has("metadata") or not GFVariantData.get_option_value(data, "metadata") is Dictionary:
		var _metadata_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_document_metadata",
			"Document metadata must be a Dictionary.",
			{ "path": "metadata" }
		)
	else:
		var metadata_validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(
			GFVariantData.get_option_dictionary(data, "metadata")
		)
		if not GFVariantData.get_option_bool(metadata_validation, "ok", false):
			var _metadata_value_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_document_metadata",
				GFVariantData.get_option_string(metadata_validation, "error", "Metadata cannot be persisted."),
				{ "path": "metadata%s" % GFVariantData.get_option_string(metadata_validation, "path", "$").trim_prefix("$") }
			)
	return GFValidationReportDictionary.finalize_report(report, "Save document dictionary", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions_static(),
		"fallback_action": "Review the first save document dictionary issue.",
		"no_action": "Save document dictionary is valid.",
	})


## 从规范字典解析文档。
##
## 容器或任一分区无效时 fail-closed 返回 null，不接受旧裸 Dictionary。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 文档字典。
## [br]
## @schema data: Dictionary following GFSaveDocument.to_dict().
## [br]
## @return 有效文档；解析失败时返回 null。
static func from_dict(data: Dictionary) -> GFSaveDocument:
	var inspection: Dictionary = inspect_dict(data)
	if not GFVariantData.get_option_bool(inspection, "ok", false):
		return null
	var sections: Array[GFSaveSection] = []
	var section_data: Dictionary = GFVariantData.get_option_dictionary(data, "sections")
	var section_ids: PackedStringArray = _sorted_dictionary_keys(section_data)
	for section_id_text: String in section_ids:
		var section_dictionary: Dictionary = GFVariantData.get_option_dictionary(section_data, section_id_text)
		var section: GFSaveSection = GFSaveSection.from_dict(section_dictionary)
		if section == null:
			return null
		sections.append(section)
	return GFSaveDocument.new().configure(
		GFVariantData.to_string_name(GFVariantData.get_option_value(data, "schema_id")),
		GFVariantData.to_exact_int(GFVariantData.get_option_value(data, "schema_version")),
		sections,
		GFVariantData.get_option_dictionary(data, "metadata")
	)


# --- 私有/辅助方法 ---

func _append_persisted_value_issue(
	report: Dictionary,
	value: Variant,
	field_path: String,
	issue_kind: StringName
) -> void:
	var validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(value)
	if GFVariantData.get_option_bool(validation, "ok", false):
		return
	var _persisted_issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		issue_kind,
		GFVariantData.get_option_string(validation, "error", "Value cannot be persisted."),
		{ "path": "%s%s" % [field_path, GFVariantData.get_option_string(validation, "path", "$").trim_prefix("$")] }
	)


func _append_nested_issues(report: Dictionary, nested_report: Dictionary, path_prefix: String) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(nested_report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var nested_path: String = GFVariantData.get_option_string(issue, "path")
		var payload: Dictionary = issue.duplicate(true)
		payload["path"] = path_prefix if nested_path.is_empty() else "%s.%s" % [path_prefix, nested_path]
		var _nested_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			GFVariantData.get_option_string(issue, "severity", "error"),
			GFVariantData.get_option_string_name(issue, "kind", &"invalid_document_section"),
			GFVariantData.get_option_string(issue, "message", "Section validation failed."),
			payload
		)


func _get_validation_next_actions() -> Dictionary:
	return _get_validation_next_actions_static()


static func _append_section_dict_issues(report: Dictionary, section_data: Dictionary) -> void:
	for section_id_text: String in _sorted_dictionary_keys(section_data):
		var value: Variant = GFVariantData.get_option_value(section_data, section_id_text)
		if not value is Dictionary:
			var _section_type_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_document_section",
				"Document section must be a Dictionary.",
				{ "path": "sections.%s" % section_id_text }
			)
			continue
		var section_dictionary: Dictionary = GFVariantData.as_dictionary(value)
		_append_unknown_field_issues(
			report,
			section_dictionary,
			_SECTION_FIELDS,
			"sections.%s" % section_id_text
		)
		var section_id_value: Variant = GFVariantData.get_option_value(section_dictionary, "section_id")
		if (
			typeof(section_id_value) != TYPE_STRING
			and typeof(section_id_value) != TYPE_STRING_NAME
		) or GFVariantData.to_text(section_id_value) != section_id_text:
			var _section_id_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"document_section_id_mismatch",
				"Section key and section_id must match.",
				{ "path": "sections.%s.section_id" % section_id_text }
			)
		var section_version_value: Variant = GFVariantData.get_option_value(section_dictionary, "schema_version")
		if (
			not GFVariantData.is_exact_integer(section_version_value)
			or GFVariantData.to_exact_int(section_version_value) <= 0
		):
			var _section_version_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_section_version",
				"Section schema version must be a positive integer.",
				{ "path": "sections.%s.schema_version" % section_id_text }
			)
		if not section_dictionary.has("payload"):
			var _payload_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"missing_section_payload",
				"Section payload field is required.",
				{ "path": "sections.%s.payload" % section_id_text }
			)
		if not section_dictionary.has("metadata") or not GFVariantData.get_option_value(section_dictionary, "metadata") is Dictionary:
			var _metadata_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_section_metadata",
				"Section metadata must be a Dictionary.",
				{ "path": "sections.%s.metadata" % section_id_text }
			)
		var section: GFSaveSection = GFSaveSection.from_dict(section_dictionary)
		if section == null:
			var _invalid_section_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_document_section",
				"Document section contains invalid or non-persistable fields.",
				{ "path": "sections.%s" % section_id_text }
			)
			continue
		var section_validation: Dictionary = section.validate_section()
		for issue_value: Variant in GFVariantData.get_option_array(section_validation, "issues"):
			var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
			var nested_path: String = GFVariantData.get_option_string(issue, "path")
			var payload: Dictionary = issue.duplicate(true)
			payload["path"] = "sections.%s" % section_id_text
			if not nested_path.is_empty():
				payload["path"] = "%s.%s" % [GFVariantData.get_option_string(payload, "path"), nested_path]
			var _nested_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				GFVariantData.get_option_string(issue, "severity", "error"),
				GFVariantData.get_option_string_name(issue, "kind", &"invalid_document_section"),
				GFVariantData.get_option_string(issue, "message", "Section validation failed."),
				payload
			)


static func _sorted_dictionary_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var text: String = GFVariantData.to_text(key).strip_edges()
		if not text.is_empty() and not result.has(text):
			var _appended: bool = result.append(text)
	result.sort()
	return result


static func _append_unknown_field_issues(
	report: Dictionary,
	source: Dictionary,
	allowed_fields: Array,
	path_prefix: String
) -> void:
	for key: Variant in source.keys():
		var field_name: String = GFVariantData.to_text(key)
		if allowed_fields.has(field_name):
			continue
		var field_path: String = field_name
		if not path_prefix.is_empty():
			field_path = "%s.%s" % [path_prefix, field_name]
		var _unknown_field_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"unknown_document_field",
			"Unknown save document field requires a container format version change.",
			{ "path": field_path, "field": field_name }
		)


static func _get_validation_next_actions_static() -> Dictionary:
	return {
		"document_format_mismatch": "Load only canonical GFSaveDocument payloads at the save boundary.",
		"unsupported_document_format_version": "Upgrade GF before reading a newer save document container.",
		"missing_document_schema_id": "Assign a stable project schema_id.",
		"invalid_document_schema_version": "Use a positive document schema version.",
		"invalid_document_sections": "Store sections in a Dictionary keyed by section_id.",
		"invalid_document_section": "Repair the invalid section before loading the document.",
		"document_section_id_mismatch": "Keep the section dictionary key equal to section_id.",
		"missing_section_payload": "Persist an explicit payload field, including null when intentional.",
		"invalid_document_metadata": "Convert document metadata to persisted-safe values.",
		"invalid_section_metadata": "Store section metadata as a persisted-safe Dictionary.",
		"unknown_document_field": "Remove the unknown field or introduce a new document container format version.",
	}
