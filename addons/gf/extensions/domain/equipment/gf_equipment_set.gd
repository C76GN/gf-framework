## GFEquipmentSet: 通用槽位集合。
##
## 用于管理一组 `GFEquipmentSlot`，不约束槽位名称或装备类型。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFEquipmentSet
extends Resource


# --- 导出变量 ---

## 槽位表。Key 推荐为 StringName，Value 应为 GFEquipmentSlot。
## [br]
## @api public
## [br]
## @schema slots: Dictionary，键为 StringName 槽位 ID，值为 GFEquipmentSlot 槽位资源。
@export var slots: Dictionary = {}


# --- 公共方法 ---

## 添加或替换槽位。
## [br]
## @api public
## [br]
## @param slot: 槽位资源。
func set_slot(slot: GFEquipmentSlot) -> void:
	if slot == null or slot.slot_id == &"":
		return
	slots[slot.slot_id] = slot


## 获取槽位。
## [br]
## @api public
## [br]
## @param slot_id: 槽位 ID。
## [br]
## @return 槽位资源；不存在时返回 null。
func get_slot(slot_id: StringName) -> GFEquipmentSlot:
	return _get_equipment_slot_value(GFVariantData.get_option_value(slots, slot_id))


## 挂载物品到槽位。
## [br]
## @api public
## [br]
## @param slot_id: 槽位 ID。
## [br]
## @param item_id: 物品 ID。
## [br]
## @param item_tags: 物品标签。
## [br]
## @return 成功时返回 true。
## [br]
## @schema item_tags: Array[StringName]，当前物品拥有的标签列表。
func equip(slot_id: StringName, item_id: StringName, item_tags: Array[StringName] = []) -> bool:
	var slot: GFEquipmentSlot = get_slot(slot_id)
	if slot == null:
		return false
	return slot.equip(item_id, item_tags)


## 清空槽位。
## [br]
## @api public
## [br]
## @param slot_id: 槽位 ID。
func unequip(slot_id: StringName) -> void:
	var slot: GFEquipmentSlot = get_slot(slot_id)
	if slot != null:
		slot.unequip()


## 获取槽位当前物品。
## [br]
## @api public
## [br]
## @param slot_id: 槽位 ID。
## [br]
## @return 物品 ID。
func get_equipped_item(slot_id: StringName) -> StringName:
	var slot: GFEquipmentSlot = get_slot(slot_id)
	if slot == null:
		return &""
	return slot.item_id


# --- 私有/辅助方法 ---

## 将任意值收窄为 GFEquipmentSlot 实例，否则返回 null。
## [br]
## @api private
func _get_equipment_slot_value(value: Variant) -> GFEquipmentSlot:
	if value is GFEquipmentSlot:
		var slot: GFEquipmentSlot = value
		return slot
	return null
