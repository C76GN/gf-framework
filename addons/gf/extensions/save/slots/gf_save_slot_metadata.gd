## GFSaveSlotMetadata: 通用存档槽元数据。
##
## 只描述槽位、版本、时间、标签和项目自定义字典，不绑定任何具体游戏业务字段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSaveSlotMetadata
extends Resource


# --- 导出变量 ---

## 槽位逻辑标识。可由项目映射到整数槽、文件名或云端 key。
## [br]
## @api public
@export var slot_id: StringName = &""

## 展示名称。
## [br]
## @api public
@export var display_name: String = ""

## 展示描述。
## [br]
## @api public
@export_multiline var description: String = ""

## 存档数据结构标识。
## [br]
## @api public
@export var schema_id: StringName = &""

## 存档数据结构版本。
## [br]
## @api public
@export_range(1, 999999, 1) var schema_version: int = 1

## 项目版本号。
## [br]
## @api public
@export var app_version: String = ""

## 创建时间戳。
## [br]
## @api public
@export var created_at_unix: int = 0

## 更新时间戳。
## [br]
## @api public
@export var updated_at_unix: int = 0

## 通用游玩时长或业务耗时。
## [br]
## @api public
@export var elapsed_seconds: float = 0.0

## 通用标签。
## [br]
## @api public
@export var tags: PackedStringArray = PackedStringArray()

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema custom_metadata: Dictionary，可包含项目自定义展示、兼容性或索引字段。
@export var custom_metadata: Dictionary = {}


# --- 公共方法 ---

## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @param include_empty: 是否包含空值。
## [br]
## @return 元数据字典。
## [br]
## @schema return: Dictionary，可包含 slot_id、display_name、description、schema_id、schema_version、app_version、created_at_unix、updated_at_unix、elapsed_seconds、tags 与 custom_metadata。
func to_dict(include_empty: bool = true) -> Dictionary:
	var result: Dictionary = {
		"slot_id": slot_id,
		"display_name": display_name,
		"description": description,
		"schema_id": schema_id,
		"schema_version": schema_version,
		"app_version": app_version,
		"created_at_unix": created_at_unix,
		"updated_at_unix": updated_at_unix,
		"elapsed_seconds": elapsed_seconds,
		"tags": tags,
		"custom_metadata": custom_metadata.duplicate(true),
	}
	if include_empty:
		return result

	for key: Variant in result.keys():
		if _is_empty_metadata_value(result[key]):
			var _erased: bool = result.erase(key)
	return result


## 转换为只包含非空值的补丁字典。
## [br]
## @api public
## [br]
## @return 补丁字典。
## [br]
## @schema return: Dictionary，字段同 to_dict()，但会省略空值。
func to_patch_dict() -> Dictionary:
	return to_dict(false)


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 元数据字典。
## [br]
## @schema data: Dictionary，可包含 slot_id、display_name、description、schema_id、schema_version、app_version、created_at_unix、updated_at_unix、elapsed_seconds、tags 与 custom_metadata。
func apply_dict(data: Dictionary) -> void:
	if data.has("slot_id"):
		slot_id = GFVariantData.to_string_name(data["slot_id"])
	if data.has("display_name"):
		display_name = GFVariantData.to_text(data["display_name"])
	if data.has("description"):
		description = GFVariantData.to_text(data["description"])
	if data.has("schema_id"):
		schema_id = GFVariantData.to_string_name(data["schema_id"])
	if data.has("schema_version"):
		schema_version = maxi(GFVariantData.to_int(data["schema_version"]), 1)
	if data.has("app_version"):
		app_version = GFVariantData.to_text(data["app_version"])
	if data.has("created_at_unix"):
		created_at_unix = GFVariantData.to_int(data["created_at_unix"])
	if data.has("updated_at_unix"):
		updated_at_unix = GFVariantData.to_int(data["updated_at_unix"])
	if data.has("elapsed_seconds"):
		elapsed_seconds = maxf(GFVariantData.to_float(data["elapsed_seconds"]), 0.0)
	if data.has("tags"):
		tags = PackedStringArray(GFVariantData.to_string_array(data["tags"]))
	if data.has("custom_metadata"):
		custom_metadata = GFVariantData.get_option_dictionary(data, "custom_metadata")


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新元数据。
func duplicate_metadata() -> GFSaveSlotMetadata:
	return GFSaveSlotMetadata.from_dict(to_dict(true))


## 获取展示名称，允许调用方提供兜底文本。
## [br]
## @api public
## [br]
## @param fallback: 兜底文本。
## [br]
## @return 展示名称。
func get_display_name(fallback: String = "") -> String:
	if not display_name.is_empty():
		return display_name
	return fallback


## 校验元数据的通用结构。
## [br]
## @api public
## [br]
## @return 诊断报告。
## [br]
## @schema return: Dictionary，包含 ok、healthy、issues、issue_count、warning_count、error_count、summary 与 next_actions 等校验报告字段。
func validate_metadata() -> Dictionary:
	var report: Dictionary = {
		"issues": [],
	}
	if slot_id == &"":
		var _append_issue_result_185: Variant = GFValidationReportDictionary.append_issue(report, "warning", &"empty_slot_id", "Slot id is empty.", {
			"path": "slot_id",
		})
	if schema_version <= 0:
		var _append_issue_result_189: Variant = GFValidationReportDictionary.append_issue(report, "error", &"invalid_schema_version", "Schema version must be positive.", {
			"path": "schema_version",
		})
	if elapsed_seconds < 0.0:
		var _append_issue_result_193: Variant = GFValidationReportDictionary.append_issue(report, "error", &"invalid_elapsed_seconds", "Elapsed seconds cannot be negative.", {
			"path": "elapsed_seconds",
		})
	return GFValidationReportDictionary.finalize_report(report, "Save slot metadata", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save slot metadata issue.",
		"no_action": "Save slot metadata is healthy.",
	})


## 从 Dictionary 创建元数据。
## [br]
## @api public
## [br]
## @param data: 元数据字典。
## [br]
## @return 新元数据。
## [br]
## @schema data: Dictionary，字段同 to_dict() 返回值。
static func from_dict(data: Dictionary) -> GFSaveSlotMetadata:
	var metadata: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	metadata.apply_dict(data)
	return metadata


## 使用常用字段创建元数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param p_slot_id: 槽位标识。
## [br]
## @param p_display_name: 展示名称。
## [br]
## @param p_custom_metadata: 自定义元数据。
## [br]
## @param unix_time_seconds: 显式 Unix epoch 秒时间戳；0 表示未知。
## [br]
## @return 新元数据。
## [br]
## @schema p_custom_metadata: Dictionary，可包含项目自定义展示、兼容性或索引字段。
static func from_values(
	p_slot_id: StringName,
	p_display_name: String = "",
	p_custom_metadata: Dictionary = {},
	unix_time_seconds: int = 0
) -> GFSaveSlotMetadata:
	var metadata: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	metadata.slot_id = p_slot_id
	metadata.display_name = p_display_name
	metadata.custom_metadata = p_custom_metadata.duplicate(true)
	var now: int = maxi(unix_time_seconds, 0)
	metadata.created_at_unix = now
	metadata.updated_at_unix = now
	return metadata


# --- 私有/辅助方法 ---

func _is_empty_metadata_value(value: Variant) -> bool:
	if value == null:
		return true
	if value is String or value is StringName:
		return GFVariantData.to_text(value).is_empty()
	if value is Array:
		var array: Array = value
		return array.is_empty()
	if value is PackedStringArray:
		var string_array: PackedStringArray = value
		return string_array.is_empty()
	if value is Dictionary:
		return GFVariantData.as_dictionary(value).is_empty()
	if value is int or value is float:
		return GFVariantData.to_float(value) == 0.0
	return false


func _get_validation_next_actions() -> Dictionary:
	return {
		"empty_slot_id": "Set a stable slot_id before showing or saving this slot.",
		"invalid_schema_version": "Use a positive schema_version for save compatibility checks.",
		"invalid_elapsed_seconds": "Clamp elapsed_seconds to zero or a positive duration.",
	}
