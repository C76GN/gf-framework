## GFSaveSection: 版本化存档分区值对象。
##
## 分区用稳定 section_id、独立 schema_version 和任意可持久化 payload
## 表达一个模块拥有的数据边界，不解释项目业务字段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFSaveSection
extends RefCounted


# --- 常量 ---

const _GF_SAVE_PERSISTED_VALUE_VALIDATOR = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")
const _SECTION_FIELDS: Array = [
	"section_id",
	"schema_version",
	"payload",
	"metadata",
]


# --- 私有变量 ---

var _section_id: StringName = &""
var _schema_version: int = 0
var _payload: Variant = null
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 配置分区并复制所有动态数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param section_id: 稳定分区 ID。
## [br]
## @param schema_version: 分区 schema 版本，必须大于 0。
## [br]
## @param payload: 项目定义且可持久化的分区载荷。
## [br]
## @param metadata: 项目定义且可持久化的分区元数据。
## [br]
## @schema payload: Variant accepted by GFSavePersistedValueValidator.
## [br]
## @schema metadata: Dictionary with project-defined persisted metadata.
## [br]
## @return 当前分区。
func configure(
	section_id: StringName,
	schema_version: int,
	payload: Variant,
	metadata: Dictionary = {}
) -> GFSaveSection:
	_section_id = section_id
	_schema_version = schema_version
	_payload = GFVariantData.duplicate_variant(payload)
	_metadata = metadata.duplicate(true)
	return self


## 获取稳定分区 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 分区 ID。
func get_section_id() -> StringName:
	return _section_id


## 获取分区 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 分区 schema 版本。
func get_schema_version() -> int:
	return _schema_version


## 获取分区载荷副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 深复制的项目载荷。
## [br]
## @schema return: Variant accepted by GFSavePersistedValueValidator.
func get_payload() -> Variant:
	return GFVariantData.duplicate_variant(_payload)


## 获取分区元数据副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 深复制的分区元数据。
## [br]
## @schema return: Dictionary with project-defined persisted metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 校验分区身份、版本和持久化安全性。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_section() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	if _section_id == &"":
		var _missing_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_section_id",
			"Section id is required.",
			{ "path": "section_id" }
		)
	if _schema_version <= 0:
		var _version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_section_version",
			"Section schema version must be positive.",
			{ "path": "schema_version", "version": _schema_version }
		)
	_append_persisted_value_issue(report, _payload, "payload", &"invalid_section_payload")
	_append_persisted_value_issue(report, _metadata, "metadata", &"invalid_section_metadata")
	return GFValidationReportDictionary.finalize_report(report, "Save section", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save section issue.",
		"no_action": "Save section is valid.",
	})


## 转换为规范持久化字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 分区字典。
## [br]
## @schema return: Dictionary with section_id, schema_version, payload, and metadata.
func to_dict() -> Dictionary:
	return {
		"section_id": _section_id,
		"schema_version": _schema_version,
		"payload": GFVariantData.duplicate_variant(_payload),
		"metadata": _metadata.duplicate(true),
	}


## 创建隔离副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 分区副本。
func duplicate_section() -> GFSaveSection:
	return GFSaveSection.new().configure(
		_section_id,
		_schema_version,
		_payload,
		_metadata
	)


## 从持久化字典创建分区。
##
## 该方法执行严格边界检查，不修补非法字段或忽略未知字段。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 分区字典。
## [br]
## @schema data: Dictionary with section_id, schema_version, payload, and metadata.
## [br]
## @return 新分区；输入不规范时返回 null。
static func from_dict(data: Dictionary) -> GFSaveSection:
	if data.size() != _SECTION_FIELDS.size():
		return null
	for field_name: String in _SECTION_FIELDS:
		if not data.has(field_name):
			return null
	var section_id_value: Variant = GFVariantData.get_option_value(data, "section_id")
	if (
		typeof(section_id_value) != TYPE_STRING
		and typeof(section_id_value) != TYPE_STRING_NAME
	) or GFVariantData.to_text(section_id_value).is_empty():
		return null
	var schema_version_value: Variant = GFVariantData.get_option_value(data, "schema_version")
	if (
		not GFVariantData.is_exact_integer(schema_version_value)
		or GFVariantData.to_exact_int(schema_version_value) <= 0
	):
		return null
	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata")
	if not metadata_value is Dictionary:
		return null
	var payload_validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(
		GFVariantData.get_option_value(data, "payload")
	)
	if not GFVariantData.get_option_bool(payload_validation, "ok", false):
		return null
	var metadata_validation: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(metadata_value)
	if not GFVariantData.get_option_bool(metadata_validation, "ok", false):
		return null
	return GFSaveSection.new().configure(
		GFVariantData.to_string_name(section_id_value),
		GFVariantData.to_exact_int(schema_version_value),
		GFVariantData.get_option_value(data, "payload"),
		GFVariantData.as_dictionary(metadata_value)
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
	var nested_path: String = GFVariantData.get_option_string(validation, "path", "$")
	var _persisted_issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		issue_kind,
		GFVariantData.get_option_string(validation, "error", "Value cannot be persisted."),
		{
			"path": "%s%s" % [field_path, nested_path.trim_prefix("$")],
			"value_type": GFVariantData.get_option_string(validation, "value_type"),
		}
	)


func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_section_id": "Assign a stable section_id owned by one project module.",
		"invalid_section_version": "Use a positive section schema version.",
		"invalid_section_payload": "Convert the section payload to persisted-safe values.",
		"invalid_section_metadata": "Convert section metadata to persisted-safe values.",
	}
