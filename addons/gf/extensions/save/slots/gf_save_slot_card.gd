## GFSaveSlotCard: 通用存档槽摘要数据。
##
## 作为项目 UI 和存档系统之间的轻量 DTO，不规定具体界面布局、文案或业务字段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSaveSlotCard
extends Resource


# --- 导出变量 ---

## 整数槽位索引。文件名/云端 key 场景可保持为 -1。
## [br]
## @api public
@export var slot_index: int = -1

## 逻辑槽位标识。
## [br]
## @api public
@export var slot_id: StringName = &""

## 项目可选展示名称。
## [br]
## @api public
@export var display_name: String = ""

## 项目可选展示描述。
## [br]
## @api public
@export_multiline var description: String = ""

## 是否为空槽位。
## [br]
## @api public
@export var is_empty: bool = true

## 是否为当前选中槽位。
## [br]
## @api public
@export var is_active: bool = false

## 是否兼容当前项目版本或数据结构。
## [br]
## @api public
@export var is_compatible: bool = true

## 最近修改时间戳。
## [br]
## @api public
@export var modified_time: int = 0

## 原始元数据副本。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @schema metadata: Dictionary，通常来自 GFSaveSlotMetadata.to_dict() 或槽位存储摘要的 metadata 字段。
@export var metadata: Dictionary = {}

## 兼容性问题列表。
## [br]
## @api public
@export var compatibility_errors: PackedStringArray = PackedStringArray()


# --- 公共方法 ---

## 从槽位存储适配器的通用摘要配置卡片。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @param summary: 槽位摘要。
## [br]
## @param fallback_slot_id: 摘要缺少 slot_id 时的兜底标识。
## [br]
## @param active_slot_index: 当前选中槽位索引。
## [br]
## @return 当前卡片。
## [br]
## @schema summary: Dictionary，可包含 slot_index、slot_id、modified_time、is_compatible、compatibility_errors 与 metadata。
func configure_from_slot_summary(
	summary: Dictionary,
	fallback_slot_id: StringName = &"",
	active_slot_index: int = -1
) -> GFSaveSlotCard:
	metadata = GFVariantData.get_option_dictionary(summary, "metadata")
	slot_index = _get_summary_slot_index(summary, metadata, fallback_slot_id)
	var fallback_slot_text: String = String(fallback_slot_id) if fallback_slot_id != &"" else str(slot_index)
	slot_id = GFVariantData.get_option_string_name(metadata, "slot_id", StringName(fallback_slot_text))
	display_name = GFVariantData.get_option_string(metadata, "display_name")
	description = GFVariantData.get_option_string(metadata, "description")
	modified_time = GFVariantData.get_option_int(
		summary,
		"modified_time",
		GFVariantData.get_option_int(metadata, "updated_at_unix")
	)
	is_empty = false
	is_active = active_slot_index >= 0 and slot_index == active_slot_index
	is_compatible = GFVariantData.get_option_bool(
		summary,
		"is_compatible",
		GFVariantData.get_option_bool(metadata, "is_compatible", true)
	)
	var compatibility_error_value: Variant = GFVariantData.get_option_value(
		summary,
		"compatibility_errors",
		GFVariantData.get_option_value(metadata, "compatibility_errors", [])
	)
	compatibility_errors = PackedStringArray(GFVariantData.to_string_array(compatibility_error_value))
	return self


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return 卡片字典。
## [br]
## @schema return: Dictionary，包含 slot_index、slot_id、display_name、description、is_empty、is_active、is_compatible、status_id、modified_time、metadata 与 compatibility_errors。
func to_dict() -> Dictionary:
	return {
		"slot_index": slot_index,
		"slot_id": slot_id,
		"display_name": display_name,
		"description": description,
		"is_empty": is_empty,
		"is_active": is_active,
		"is_compatible": is_compatible,
		"status_id": get_status_id(),
		"modified_time": modified_time,
		"metadata": metadata.duplicate(true),
		"compatibility_errors": compatibility_errors,
	}


## 获取非本地化状态标识。
##
## 项目 UI 可基于该标识映射自己的文案、样式或图标。
## [br]
## @api public
## [br]
## @return 状态标识：empty、incompatible、active 或 ready。
func get_status_id() -> StringName:
	if is_empty:
		return &"empty"
	if not is_compatible:
		return &"incompatible"
	if is_active:
		return &"active"
	return &"ready"


## 从摘要创建卡片。
## [br]
## @api public
## [br]
## @param summary: 槽位摘要。
## [br]
## @param fallback_slot_id: 兜底标识。
## [br]
## @param active_slot_index: 当前选中槽位索引。
## [br]
## @return 新卡片。
## [br]
## @schema summary: Dictionary，可包含 slot_index、slot_id、modified_time、is_compatible、compatibility_errors 与 metadata。
static func from_slot_summary(
	summary: Dictionary,
	fallback_slot_id: StringName = &"",
	active_slot_index: int = -1
) -> GFSaveSlotCard:
	return GFSaveSlotCard.new().configure_from_slot_summary(summary, fallback_slot_id, active_slot_index)


# --- 私有/辅助方法 ---


func _get_summary_slot_index(
	summary: Dictionary,
	summary_metadata: Dictionary,
	fallback_slot_id: StringName
) -> int:
	if summary.has("slot_index"):
		return GFVariantData.get_option_int(summary, "slot_index", -1)

	var candidates: Array = [
		GFVariantData.get_option_value(summary, "slot_id"),
		GFVariantData.get_option_value(summary_metadata, "slot_id"),
		fallback_slot_id,
	]
	for candidate: Variant in candidates:
		var parsed: int = _parse_slot_index(candidate)
		if parsed >= 0:
			return parsed
	return slot_index


func _parse_slot_index(value: Variant) -> int:
	if value == null:
		return -1
	if value is int or value is float:
		return GFVariantData.to_int(value)

	var text: String = GFVariantData.to_text(value)
	if text.is_valid_int():
		return text.to_int()

	var digits: String = ""
	for index: int in range(text.length() - 1, -1, -1):
		var character: String = text.substr(index, 1)
		if not character.is_valid_int():
			break
		digits = character + digits
	if digits.is_valid_int():
		return digits.to_int()
	return -1
