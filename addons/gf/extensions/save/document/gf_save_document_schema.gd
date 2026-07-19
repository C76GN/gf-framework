## GFSaveDocumentSchema: 项目存档文档的当前版本契约。
##
## 项目用该 Resource 声明 schema_id、当前文档版本、已知分区版本和必需分区。
## GF 只校验结构与版本，不解释任何业务字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 9.0.0
class_name GFSaveDocumentSchema
extends Resource


# --- 常量 ---

const _SCHEMA_FIELDS: Array = [
	"schema_id",
	"schema_version",
	"section_versions",
	"required_sections",
	"allow_unknown_sections",
]


# --- 导出变量 ---

## 项目存档 schema 的稳定 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var schema_id: StringName = &""

## 当前文档 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var schema_version: int = 1

## 已知分区及其当前版本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @schema section_versions: Dictionary from non-empty section_id to positive int version.
@export var section_versions: Dictionary = {}

## 当前 schema 必须存在的分区。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var required_sections: PackedStringArray = PackedStringArray()

## 是否允许并原样保留 schema 未声明的分区。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var allow_unknown_sections: bool = true


# --- 公共方法 ---

## 配置当前 schema 契约。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param p_schema_id: 稳定 schema ID。
## [br]
## @param p_schema_version: 当前文档版本。
## [br]
## @param p_section_versions: 分区当前版本映射。
## [br]
## @param options: 可包含 required_sections 与 allow_unknown_sections。
## [br]
## @schema p_section_versions: Dictionary from non-empty section_id to positive int version.
## [br]
## @schema options: Dictionary with optional required_sections: PackedStringArray and allow_unknown_sections: bool.
## [br]
## @return 当前 schema。
func configure(
	p_schema_id: StringName,
	p_schema_version: int,
	p_section_versions: Dictionary = {},
	options: Dictionary = {}
) -> GFSaveDocumentSchema:
	schema_id = p_schema_id
	schema_version = p_schema_version
	section_versions = _normalize_section_versions(p_section_versions)
	required_sections = _normalize_section_ids(
		GFVariantData.get_option_packed_string_array(options, "required_sections")
	)
	allow_unknown_sections = GFVariantData.get_option_bool(options, "allow_unknown_sections", true)
	return self


## 获取指定分区的当前版本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 分区 ID。
## [br]
## @return 已声明版本；未知分区返回 0。
func get_section_version(section_id: StringName) -> int:
	return GFVariantData.get_option_int(section_versions, section_id)


## 检查是否声明了分区。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 分区 ID。
## [br]
## @return 已声明时返回 true。
func has_section(section_id: StringName) -> bool:
	return section_versions.has(section_id) or section_versions.has(String(section_id))


## 获取排序后的已知分区 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 已知分区 ID。
func get_section_ids() -> PackedStringArray:
	return _sorted_dictionary_keys(section_versions)


## 校验 schema 自身。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_schema() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	if schema_id == &"":
		var _schema_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_schema_id",
			"Schema id is required.",
			{ "path": "schema_id" }
		)
	if schema_version <= 0:
		var _schema_version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_schema_version",
			"Document schema version must be positive.",
			{ "path": "schema_version", "version": schema_version }
		)
	for section_id_text: String in get_section_ids():
		var version: int = GFVariantData.get_option_int(section_versions, section_id_text)
		if version <= 0:
			var _section_version_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_schema_section_version",
				"Section schema version must be positive.",
				{ "path": "section_versions.%s" % section_id_text, "version": version }
			)
	for required_id: String in required_sections:
		if not has_section(StringName(required_id)):
			var _required_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"undeclared_required_section",
				"Required section must have a declared target version.",
				{ "path": "required_sections", "section_id": required_id }
			)
	return GFValidationReportDictionary.finalize_report(report, "Save document schema", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save document schema issue.",
		"no_action": "Save document schema is valid.",
	})


## 校验文档是否符合该 schema。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param document: 待校验文档。
## [br]
## @param require_current_versions: 为 true 时要求文档和已知分区恰好为当前版本；为 false 时旧版本仅产生迁移警告。
## [br]
## @return 结构化兼容性报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with compatible, migration_required, schema_id, schema_version, issues, counts, summary, and next_actions.
func validate_document(
	document: GFSaveDocument,
	require_current_versions: bool = true
) -> Dictionary:
	var report: Dictionary = {
		"issues": [],
		"compatible": false,
		"migration_required": false,
		"schema_id": schema_id,
		"schema_version": schema_version,
	}
	var schema_validation: Dictionary = validate_schema()
	_append_nested_issues(report, schema_validation, "schema")
	if document == null:
		var _null_document_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_document",
			"Save document is required.",
			{ "path": "document" }
		)
		return _finalize_document_report(report)
	var document_validation: Dictionary = document.validate_document()
	_append_nested_issues(report, document_validation, "document")
	if document.get_schema_id() != schema_id:
		var _schema_mismatch_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"schema_id_mismatch",
			"Document schema id does not match the target schema.",
			{
				"path": "document.schema_id",
				"actual": document.get_schema_id(),
				"expected": schema_id,
			}
		)
	_append_version_issue(
		report,
		"document.schema_version",
		document.get_schema_version(),
		schema_version,
		require_current_versions,
		&"document"
	)
	for required_id: String in required_sections:
		if not document.has_section(StringName(required_id)):
			var _missing_required_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"missing_required_section",
				"Required save section is missing.",
				{ "path": "document.sections.%s" % required_id, "section_id": required_id }
			)
	for section_id_text: String in document.get_section_ids():
		var section_id: StringName = StringName(section_id_text)
		var section: GFSaveSection = document.get_section(section_id)
		if section == null:
			continue
		if not has_section(section_id):
			if not allow_unknown_sections:
				var _unknown_section_issue: Variant = GFValidationReportDictionary.append_issue(
					report,
					"error",
					&"unknown_section",
					"Document contains a section not declared by the schema.",
					{ "path": "document.sections.%s" % section_id_text, "section_id": section_id }
				)
			continue
		_append_version_issue(
			report,
			"document.sections.%s.schema_version" % section_id_text,
			section.get_schema_version(),
			get_section_version(section_id),
			require_current_versions,
			section_id
		)
	return _finalize_document_report(report)


## 转换为字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return schema 字典。
## [br]
## @schema return: Dictionary with schema_id, schema_version, section_versions, required_sections, and allow_unknown_sections.
func to_dict() -> Dictionary:
	return {
		"schema_id": schema_id,
		"schema_version": schema_version,
		"section_versions": section_versions.duplicate(true),
		"required_sections": required_sections.duplicate(),
		"allow_unknown_sections": allow_unknown_sections,
	}


## 创建 schema 副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 隔离 schema。
func duplicate_schema() -> GFSaveDocumentSchema:
	return GFSaveDocumentSchema.from_dict(to_dict())


## 从字典创建 schema。
##
## 该方法执行严格边界检查，不修补非法字段或忽略未知字段。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: schema 字典。
## [br]
## @schema data: Dictionary with schema_id, schema_version, section_versions, required_sections, and allow_unknown_sections.
## [br]
## @return 新 schema；输入不规范或 schema 自身无效时返回 null。
static func from_dict(data: Dictionary) -> GFSaveDocumentSchema:
	if data.size() != _SCHEMA_FIELDS.size():
		return null
	for field_name: String in _SCHEMA_FIELDS:
		if not data.has(field_name):
			return null
	var schema_id_value: Variant = GFVariantData.get_option_value(data, "schema_id")
	if (
		typeof(schema_id_value) != TYPE_STRING
		and typeof(schema_id_value) != TYPE_STRING_NAME
	) or GFVariantData.to_text(schema_id_value).is_empty():
		return null
	var schema_version_value: Variant = GFVariantData.get_option_value(data, "schema_version")
	if (
		not GFVariantData.is_exact_integer(schema_version_value)
		or GFVariantData.to_exact_int(schema_version_value) <= 0
	):
		return null
	var section_versions_value: Variant = GFVariantData.get_option_value(data, "section_versions")
	if not section_versions_value is Dictionary:
		return null
	var strict_section_versions: Dictionary = {}
	var raw_section_versions: Dictionary = GFVariantData.as_dictionary(section_versions_value)
	for section_id_value: Variant in raw_section_versions.keys():
		if (
			typeof(section_id_value) != TYPE_STRING
			and typeof(section_id_value) != TYPE_STRING_NAME
		):
			return null
		var section_id_text: String = GFVariantData.to_text(section_id_value)
		if section_id_text.is_empty() or section_id_text != section_id_text.strip_edges():
			return null
		var section_version_value: Variant = raw_section_versions[section_id_value]
		if (
			not GFVariantData.is_exact_integer(section_version_value)
			or GFVariantData.to_exact_int(section_version_value) <= 0
		):
			return null
		var section_id: StringName = StringName(section_id_text)
		if strict_section_versions.has(section_id):
			return null
		strict_section_versions[section_id] = GFVariantData.to_exact_int(section_version_value)
	var required_value: Variant = GFVariantData.get_option_value(data, "required_sections")
	if not required_value is Array and not required_value is PackedStringArray:
		return null
	var strict_required_sections: PackedStringArray = PackedStringArray()
	for required_id_value: Variant in required_value:
		if (
			typeof(required_id_value) != TYPE_STRING
			and typeof(required_id_value) != TYPE_STRING_NAME
		):
			return null
		var required_id: String = GFVariantData.to_text(required_id_value)
		if (
			required_id.is_empty()
			or required_id != required_id.strip_edges()
			or strict_required_sections.has(required_id)
		):
			return null
		var _required_appended: bool = strict_required_sections.append(required_id)
	var allow_unknown_value: Variant = GFVariantData.get_option_value(data, "allow_unknown_sections")
	if typeof(allow_unknown_value) != TYPE_BOOL:
		return null
	var schema: GFSaveDocumentSchema = GFSaveDocumentSchema.new().configure(
		GFVariantData.to_string_name(schema_id_value),
		GFVariantData.to_exact_int(schema_version_value),
		strict_section_versions,
		{
			"required_sections": strict_required_sections,
			"allow_unknown_sections": GFVariantData.to_bool(allow_unknown_value),
		}
	)
	if not GFVariantData.get_option_bool(schema.validate_schema(), "ok", false):
		return null
	return schema


# --- 私有/辅助方法 ---

func _append_version_issue(
	report: Dictionary,
	field_path: String,
	actual_version: int,
	target_version: int,
	require_current_versions: bool,
	owner_id: StringName
) -> void:
	if actual_version == target_version:
		return
	if actual_version > target_version:
		var _future_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"future_schema_version",
			"Save data is newer than the target schema.",
			{
				"path": field_path,
				"owner_id": owner_id,
				"actual": actual_version,
				"target": target_version,
			}
		)
		return
	report["migration_required"] = true
	var severity: String = "error" if require_current_versions else "warning"
	var _older_issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		severity,
		&"migration_required",
		"Save data must be migrated to the target schema version.",
		{
			"path": field_path,
			"owner_id": owner_id,
			"actual": actual_version,
			"target": target_version,
		}
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
			GFVariantData.get_option_string_name(issue, "kind", &"invalid_nested_value"),
			GFVariantData.get_option_string(issue, "message", "Nested validation failed."),
			payload
		)


func _finalize_document_report(report: Dictionary) -> Dictionary:
	var finalized: Dictionary = GFValidationReportDictionary.finalize_report(report, "Save document compatibility", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save document compatibility issue.",
		"no_action": "Save document matches the target schema.",
	})
	finalized["compatible"] = GFVariantData.get_option_bool(finalized, "ok", false)
	return finalized


static func _normalize_section_versions(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var section_id_text: String = GFVariantData.to_text(key).strip_edges()
		if section_id_text.is_empty():
			continue
		result[StringName(section_id_text)] = GFVariantData.to_int(source[key])
	return result


static func _normalize_section_ids(source: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for section_id_text: String in source:
		var normalized: String = section_id_text.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _sorted_dictionary_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var text: String = GFVariantData.to_text(key).strip_edges()
		if not text.is_empty() and not result.has(text):
			var _appended: bool = result.append(text)
	result.sort()
	return result


func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_schema_id": "Assign a stable schema_id owned by the project.",
		"invalid_schema_version": "Use a positive current document version.",
		"invalid_schema_section_version": "Use a positive current version for every known section.",
		"undeclared_required_section": "Declare a target version for every required section.",
		"missing_document": "Provide a parsed GFSaveDocument.",
		"schema_id_mismatch": "Load the document with its matching project schema.",
		"future_schema_version": "Upgrade the project before loading newer save data.",
		"migration_required": "Run GFSaveMigrationRegistry before applying the document.",
		"missing_required_section": "Restore or migrate the required section before applying the document.",
		"unknown_section": "Declare the section or explicitly allow unknown sections.",
	}
