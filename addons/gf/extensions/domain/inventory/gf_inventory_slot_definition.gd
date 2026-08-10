## GFInventorySlotDefinition: 通用库存槽位接收规则。
##
## 只描述一个槽位允许接收哪些物品或分类，不保存槽位内容，也不绑定 UI、
## 拖拽、装备类型或具体项目玩法。项目可把它挂到 `GFSlotInventoryModel.slot_definitions`
## 上，为背包、快捷栏或容器槽位提供轻量约束。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.20.0
class_name GFInventorySlotDefinition
extends Resource


# --- 导出变量 ---

## 显示名称，供项目 UI 或编辑器工具使用。
## [br]
## @api public
@export var display_name: String = ""

## 允许的物品 ID。为空表示不按物品 ID 限制。
## [br]
## @api public
## [br]
## @schema accepted_item_ids: Array[StringName]，槽位允许接收的物品 ID；为空时不限制。
@export var accepted_item_ids: Array[StringName] = []

## 禁止的物品 ID。优先级高于 accepted_item_ids。
## [br]
## @api public
## [br]
## @schema rejected_item_ids: Array[StringName]，槽位拒绝接收的物品 ID。
@export var rejected_item_ids: Array[StringName] = []

## 允许的物品分类。为空表示不按分类限制。
## [br]
## @api public
## [br]
## @schema accepted_categories: Array[StringName]，槽位允许接收的物品分类；为空时不限制。
@export var accepted_categories: Array[StringName] = []

## 是否要求物品同时拥有全部 accepted_categories。false 表示拥有任一分类即可。
## [br]
## @api public
@export var require_all_categories: bool = false

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义槽位元数据；GF 不读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 可选接收检查回调。签名为 Callable(item_id, definition, instance_data, slot_index, inventory) -> bool。
## [br]
## @api public
var acceptance_checker: Callable = Callable()


# --- 公共方法 ---

## 判断槽位是否接受指定物品。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param definition: 可选物品定义；分类规则需要该定义。
## [br]
## @param instance_data: 物品实例数据。
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param inventory: 调用方库存模型。
## [br]
## @return: 接受时返回 true。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
func can_accept(
	item_id: StringName,
	definition: GFInventoryItemDefinition = null,
	instance_data: Dictionary = {},
	slot_index: int = -1,
	inventory: Object = null
) -> bool:
	if item_id == &"":
		return false
	if rejected_item_ids.has(item_id):
		return false
	if not accepted_item_ids.is_empty() and not accepted_item_ids.has(item_id):
		return false
	if not _matches_categories(definition):
		return false
	if acceptance_checker.is_valid():
		return GFVariantData.to_bool(acceptance_checker.call(
			item_id,
			definition,
			instance_data.duplicate(true),
			slot_index,
			inventory
		))
	return true


## 转换为字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: Godot Variant 字典；不保证可直接编码为 JSON。
## [br]
## @schema return: Dictionary，包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。
func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"accepted_item_ids": _string_name_array_to_packed_string_array(accepted_item_ids),
		"rejected_item_ids": _string_name_array_to_packed_string_array(rejected_item_ids),
		"accepted_categories": _string_name_array_to_packed_string_array(accepted_categories),
		"require_all_categories": require_all_categories,
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary，可包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。
func apply_dict(data: Dictionary) -> void:
	display_name = GFVariantData.get_option_string(data, "display_name", display_name)
	accepted_item_ids = GFVariantData.get_option_string_name_array(data, "accepted_item_ids", accepted_item_ids)
	rejected_item_ids = GFVariantData.get_option_string_name_array(data, "rejected_item_ids", rejected_item_ids)
	accepted_categories = GFVariantData.get_option_string_name_array(data, "accepted_categories", accepted_categories)
	require_all_categories = GFVariantData.get_option_bool(data, "require_all_categories", require_all_categories)
	metadata = GFVariantData.get_option_dictionary(data, "metadata", metadata)


## 从字典创建槽位定义。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @return: 槽位定义。
## [br]
## @schema data: Dictionary，可包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。
static func from_dict(data: Dictionary) -> GFInventorySlotDefinition:
	var definition: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	definition.apply_dict(data)
	return definition


# --- 私有/辅助方法 ---

func _matches_categories(definition: GFInventoryItemDefinition) -> bool:
	if accepted_categories.is_empty():
		return true
	if definition == null:
		return false
	if require_all_categories:
		return definition.matches_categories(accepted_categories)

	for category: StringName in accepted_categories:
		if definition.has_category(category):
			return true
	return false


static func _string_name_array_to_packed_string_array(values: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: StringName in values:
		var _appended: bool = result.append(String(value))
	return result
