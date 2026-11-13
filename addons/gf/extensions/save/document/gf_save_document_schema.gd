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

## 允许出现在规范 schema 字典中的字段名。
## [br]
## @api private
## [br]
const _SCHEMA_FIELDS: Array = [
	"schema_id",
	"schema_version",
	"section_versions",
	"required_sections",
	"preserved_sections",
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

## 允许原样保留但不解释的分区 ID 清单；默认拒绝全部未知分区。
## [br]
## @api public
## [br]
## @since unreleased
@export var preserved_sections: PackedStringArray = PackedStringArray()


# --- 私有变量 ---

## 最近一次被拒绝的配置诊断；字段保持原值，但必须成功重新配置后才可持久化。
## [br]
## @api private
var _configuration_error: Dictionary = {}


# --- 公共方法 ---

## 配置当前 schema 契约，保留返回当前对象的旧用法。
##
## 失败时不覆盖原字段，但 validate_schema() 会报告最近的配置错误，to_dict() 返回空。
## 调用 try_configure() 可直接取得诊断；使用合法参数再次配置后解除拒绝状态。
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
## @param options: 可包含 required_sections 与 preserved_sections。
## [br]
## @schema p_section_versions: Dictionary from non-empty section_id to positive int version.
## [br]
## @schema options: Dictionary with optional required_sections: PackedStringArray and preserved_sections: PackedStringArray.
## [br]
## @return 当前 schema。
func configure(
	p_schema_id: StringName,
	p_schema_version: int,
	p_section_versions: Dictionary = {},
	options: Dictionary = {}
) -> GFSaveDocumentSchema:
	var _configured: Dictionary = try_configure(
		p_schema_id,
		p_schema_version,
		p_section_versions,
		options
	)
	return self


## 只读验证完整配置；不改变当前对象或清除其上次配置错误。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_schema_id: 文档 schema 身份。
## [br]
## @param p_schema_version: 当前正整数版本。
## [br]
## @param p_section_versions: 分区版本映射。
## [br]
## @schema p_section_versions: 与 configure() 相同的 Dictionary。
## [br]
## @param options: 只接受 required_sections 和 preserved_sections。
## [br]
## @schema options: 与 configure() 相同的闭合 Dictionary；allow_unknown_sections 已移除且不会自动转换。
## [br]
## @return 不含业务载荷的配置诊断。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String.
static func validate_configuration(
	p_schema_id: StringName,
	p_schema_version: int,
	p_section_versions: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_prepare_configuration(
			p_schema_id,
			p_schema_version,
			p_section_versions,
			options
		),
		"report"
	)


## 原子应用完整配置并返回诊断；失败保留原字段，同时阻止旧字段被误当作本次配置成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_schema_id: 文档 schema 身份。
## [br]
## @param p_schema_version: 当前正整数版本。
## [br]
## @param p_section_versions: 分区版本映射。
## [br]
## @schema p_section_versions: 与 configure() 相同的 Dictionary。
## [br]
## @param options: 只接受 required_sections 和 preserved_sections。
## [br]
## @schema options: 与 configure() 相同的闭合 Dictionary。
## [br]
## @return 配置诊断；再次成功配置会清除上次错误。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String.
func try_configure(
	p_schema_id: StringName,
	p_schema_version: int,
	p_section_versions: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var prepared: Dictionary = _prepare_configuration(
		p_schema_id,
		p_schema_version,
		p_section_versions,
		options
	)
	var report: Dictionary = GFVariantData.get_option_dictionary(prepared, "report")
	if not GFVariantData.get_option_bool(report, "ok"):
		_configuration_error = report.duplicate(true)
		return report
	var candidate: GFSaveDocumentSchema = prepared["schema"]
	schema_id = candidate.schema_id
	schema_version = candidate.schema_version
	section_versions = candidate.section_versions
	required_sections = candidate.required_sections
	preserved_sections = candidate.preserved_sections
	_configuration_error = {}
	return report


## 获取每个未知保留分区的固定规范编码预算。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 独立预算记录；整个请求仍须接受它所在层的总预算。
## [br]
## @schema return: Dictionary with max_depth:int,max_items:int,max_output_bytes:int,max_string_length:int.
static func get_preserved_section_limits() -> Dictionary:
	return {
		"max_depth": 64,
		"max_items": 100000,
		"max_output_bytes": 16777216,
		"max_string_length": 1048576,
	}


## 只读计量一个未知保留分区，不复制业务载荷。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param section: 待保留的完整分区；是否允许该 ID 仍由 validate_document() 判定。
## [br]
## @return 不含业务载荷的预算报告。
## [br]
## @schema return: Dictionary with ok:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary.
static func measure_preserved_section(section: GFSaveSection) -> Dictionary:
	var options: Dictionary = get_preserved_section_limits()
	var result: Dictionary = {
		"ok": false,
		"error_kind": &"invalid_preserved_section",
		"path": "section",
		"layer": &"preserved_section",
		"limits": options.duplicate(),
		"observed": {},
	}
	if section == null:
		return result
	options["allow_floats"] = true
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		section.get_transfer_record_for_framework(),
		options
	)
	result["observed"] = measured
	result["ok"] = GFVariantData.get_option_bool(measured, "ok")
	if result["ok"]:
		result["error_kind"] = &""
	elif not GFVariantData.get_option_string(measured, "limit_kind").is_empty():
		result["error_kind"] = &"preserved_section_budget_exceeded"
	result["path"] = "" if result["ok"] else "section"
	return result


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
	if not _configuration_error.is_empty():
		var _configuration_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			GFVariantData.get_option_string_name(_configuration_error, "error_kind"),
			"Schema configuration was rejected; configure it successfully before use.",
			{ "path": GFVariantData.get_option_string(_configuration_error, "path") }
		)
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
	var seen_preserved: Dictionary = {}
	for section_id: String in preserved_sections:
		if (
			section_id.is_empty()
			or section_id != section_id.strip_edges()
			or has_section(StringName(section_id))
			or seen_preserved.has(section_id)
		):
			var _preserved_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_preserved_section",
				"Preserved section IDs must be unique, trimmed and distinct from known sections.",
				{ "path": "preserved_sections" }
			)
		seen_preserved[section_id] = true
	return GFValidationReportDictionary.finalize_report(
		report,
		"Save document schema",
		{
			"include_issue_count": true,
			"next_actions": _get_validation_next_actions(),
			"fallback_action": "Review the first save document schema issue.",
			"no_action": "Save document schema is valid.",
		}
	)


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
func validate_document(document: GFSaveDocument, require_current_versions: bool = true) -> Dictionary:
	var report: Dictionary = {
		"issues": [],
		"compatible": false,
		"migration_required": false,
		"schema_id": schema_id,
		"schema_version": schema_version,
	}
	var schema_validation: Dictionary = validate_schema()
	_append_nested_issues(
		report,
		schema_validation,
		"schema"
	)
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
	_append_nested_issues(
		report,
		document_validation,
		"document"
	)
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
			if not preserved_sections.has(String(section_id)):
				var _unknown_section_issue: Variant = GFValidationReportDictionary.append_issue(
					report,
					"error",
					&"unknown_section",
					"Document contains a section not declared by the schema.",
					{ "path": "document.sections.%s" % section_id_text, "section_id": section_id }
				)
			else:
				var retained_measure: Dictionary = measure_preserved_section(section)
				if not GFVariantData.get_option_bool(retained_measure, "ok"):
					var _budget_issue: Variant = GFValidationReportDictionary.append_issue(
						report,
						"error",
						&"preserved_section_budget_exceeded",
						"Preserved section exceeds its native value or canonical size budget.",
						{ "path": "document.sections.%s" % section_id_text }
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
## @schema return: Dictionary with schema_id, schema_version, section_versions, required_sections, and preserved_sections; empty while a rejected configure() has not been corrected.
func to_dict() -> Dictionary:
	if not _configuration_error.is_empty():
		return {}
	return {
		"schema_id": schema_id,
		"schema_version": schema_version,
		"section_versions": section_versions.duplicate(true),
		"required_sections": required_sections.duplicate(),
		"preserved_sections": preserved_sections.duplicate(),
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
## @schema data: Dictionary with schema_id, schema_version, section_versions, required_sections, and preserved_sections.
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
		(
			typeof(schema_id_value) != TYPE_STRING
			and typeof(schema_id_value) != TYPE_STRING_NAME
		)
		or GFVariantData.to_text(schema_id_value).is_empty()
	):
		return null
	var schema_version_value: Variant = GFVariantData.get_option_value(data, "schema_version")
	if (not GFVariantData.is_exact_integer(schema_version_value) or GFVariantData.to_exact_int(schema_version_value) <= 0):
		return null
	var section_versions_value: Variant = GFVariantData.get_option_value(data, "section_versions")
	if not section_versions_value is Dictionary:
		return null
	var strict_section_versions: Dictionary = {}
	var raw_section_versions: Dictionary = GFVariantData.as_dictionary(section_versions_value)
	for section_id_value: Variant in raw_section_versions.keys():
		if (typeof(section_id_value) != TYPE_STRING and typeof(section_id_value) != TYPE_STRING_NAME):
			return null
		var section_id_text: String = GFVariantData.to_text(section_id_value)
		if section_id_text.is_empty() or section_id_text != section_id_text.strip_edges():
			return null
		var section_version_value: Variant = raw_section_versions[section_id_value]
		if (not GFVariantData.is_exact_integer(section_version_value) or GFVariantData.to_exact_int(section_version_value) <= 0):
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
		if (typeof(required_id_value) != TYPE_STRING and typeof(required_id_value) != TYPE_STRING_NAME):
			return null
		var required_id: String = GFVariantData.to_text(required_id_value)
		if (
			required_id.is_empty()
			or required_id != required_id.strip_edges()
			or strict_required_sections.has(required_id)
		):
			return null
		var _required_appended: bool = strict_required_sections.append(required_id)
	var preserved_value: Variant = GFVariantData.get_option_value(data, "preserved_sections")
	if not preserved_value is Array and not preserved_value is PackedStringArray:
		return null
	var strict_preserved: PackedStringArray = PackedStringArray()
	for section_id_value: Variant in preserved_value:
		if not section_id_value is String and not section_id_value is StringName:
			return null
		var _appended: bool = strict_preserved.append(GFVariantData.to_text(section_id_value))
	var schema: GFSaveDocumentSchema = (
		GFSaveDocumentSchema.new().configure(
			GFVariantData.to_string_name(schema_id_value),
			GFVariantData.to_exact_int(schema_version_value),
			strict_section_versions,
			{ "required_sections": strict_required_sections, "preserved_sections": strict_preserved, }
		)
	)
	if not GFVariantData.get_option_bool(
		schema.validate_schema(),
		"ok",
		false
	):
		return null
	return schema


# --- 私有/辅助方法 ---

## 准备隔离的 schema 后复用同一 validate_schema()，失败不向调用方返回可用候选。
## [br]
## @api private
static func _prepare_configuration(
	p_schema_id: StringName,
	p_schema_version: int,
	p_section_versions: Dictionary,
	options: Dictionary
) -> Dictionary:
	for key: Variant in options:
		if key == "allow_unknown_sections" or key == &"allow_unknown_sections":
			return {
				"report": {
					"ok": false,
					"error_kind": &"removed_option",
					"path": "options.allow_unknown_sections",
				},
			}
		if key not in ["required_sections", "preserved_sections"]:
			return {
				"report": {
					"ok": false,
					"error_kind": &"unknown_option",
					"path": "options",
				},
			}
	var candidate: GFSaveDocumentSchema = GFSaveDocumentSchema.new()
	candidate.schema_id = p_schema_id
	candidate.schema_version = p_schema_version
	candidate.section_versions = _normalize_section_versions(p_section_versions)
	candidate.required_sections = _normalize_section_ids(GFVariantData.get_option_packed_string_array(options, "required_sections"))
	candidate.preserved_sections = GFVariantData.get_option_packed_string_array(options, "preserved_sections").duplicate()
	var validation: Dictionary = candidate.validate_schema()
	if not GFVariantData.get_option_bool(validation, "ok"):
		var issues: Array = GFVariantData.get_option_array(validation, "issues")
		var issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}
		return {
			"report": {
				"ok": false,
				"error_kind": &"invalid_schema",
				"path": GFVariantData.get_option_string(issue, "path"),
			},
		}
	return {
		"schema": candidate,
		"report": {
			"ok": true,
			"error_kind": &"",
			"path": "",
		},
	}


## 追加文档或分区版本不匹配的问题，并标记迁移需求。
## [br]
## @api private
## [br]
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


## 将嵌套校验报告的问题复制到父报告并加上路径前缀。
## [br]
## @api private
## [br]
func _append_nested_issues(
	report: Dictionary,
	nested_report: Dictionary,
	path_prefix: String
) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(nested_report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var nested_path: String = GFVariantData.get_option_string(issue, "path")
		var payload: Dictionary = issue.duplicate(true)
		payload["path"] = path_prefix if nested_path.is_empty() else (
			"%s.%s"
			% [path_prefix, nested_path]
		)
		var _nested_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			GFVariantData.get_option_string(
				issue,
				"severity",
				"error"
			),
			GFVariantData.get_option_string_name(
				issue,
				"kind",
				&"invalid_nested_value"
			),
			GFVariantData.get_option_string(
				issue,
				"message",
				"Nested validation failed."
			),
			payload
		)


## 完成兼容性报告并根据 ok 字段设置 compatible。
## [br]
## @api private
## [br]
func _finalize_document_report(report: Dictionary) -> Dictionary:
	var finalized: Dictionary = GFValidationReportDictionary.finalize_report(
		report,
		"Save document compatibility",
		{
			"include_issue_count": true,
			"next_actions": _get_validation_next_actions(),
			"fallback_action": "Review the first save document compatibility issue.",
			"no_action": "Save document matches the target schema.",
		}
	)
	finalized["compatible"] = GFVariantData.get_option_bool(
		finalized,
		"ok",
		false
	)
	return finalized


## 清理分区 ID 键并读取其版本值。
## [br]
## @api private
## [br]
static func _normalize_section_versions(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var section_id_text: String = GFVariantData.to_text(key).strip_edges()
		if section_id_text.is_empty():
			continue
		result[StringName(section_id_text)] = GFVariantData.to_int(source[key])
	return result


## 去除分区 ID 首尾空白、删除空值与重复值并排序。
## [br]
## @api private
## [br]
static func _normalize_section_ids(source: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for section_id_text: String in source:
		var normalized: String = section_id_text.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result


## 提取非空且文本唯一的字典键，并按文本排序。
## [br]
## @api private
## [br]
static func _sorted_dictionary_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var text: String = GFVariantData.to_text(key).strip_edges()
		if not text.is_empty() and not result.has(text):
			var _appended: bool = result.append(text)
	result.sort()
	return result


## 返回 schema 校验与文档兼容性问题的后续操作建议。
## [br]
## @api private
## [br]
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
		"unknown_section": "Declare the section or list its exact ID in preserved_sections.",
		"invalid_preserved_section": "List unique unknown section IDs without whitespace.",
	}
