## GFInventoryItemRegistry: 通用库存物品定义注册表。
##
## 统一提供物品堆叠上限、堆叠数量上限和实例数据兼容性规则。
## 未注册物品可按默认规则处理，便于项目渐进接入资源化定义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInventoryItemRegistry
extends Resource


# --- 导出变量 ---

## 物品定义表。Key 推荐为 StringName，Value 应为 GFInventoryItemDefinition。
## [br]
## @api public
## [br]
## @schema definitions: Dictionary，键为 StringName 或 String 物品 ID，值为 GFInventoryItemDefinition 物品定义资源。
@export var definitions: Dictionary = {}

## 未注册物品的默认单堆叠容量。
## [br]
## @api public
@export var default_max_stack_amount: int:
	get:
		return _default_max_stack_amount
	set(value):
		_default_max_stack_amount = maxi(value, 1)

## 未注册物品的默认堆叠数量上限。小于等于 0 表示不限制。
## [br]
## @api public
@export var default_max_stack_count: int:
	get:
		return _default_max_stack_count
	set(value):
		_default_max_stack_count = maxi(value, 0)

## 是否允许未注册物品进入库存。
## [br]
## @api public
@export var allow_unregistered_items: bool = true


# --- 私有变量 ---

var _default_max_stack_amount: int = 99
var _default_max_stack_count: int = 0


# --- 公共方法 ---

## 添加或替换物品定义。
## [br]
## @api public
## [br]
## @param definition: 物品定义。
func set_definition(definition: GFInventoryItemDefinition) -> void:
	if definition == null or definition.item_id == &"":
		return
	var _old_string_key_erased: bool = definitions.erase(String(definition.item_id))
	definitions[definition.item_id] = definition


## 移除物品定义。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
func remove_definition(item_id: StringName) -> void:
	var _string_name_key_erased: bool = definitions.erase(item_id)
	var _string_key_erased: bool = definitions.erase(String(item_id))


## 清空所有物品定义。
## [br]
## @api public
func clear() -> void:
	definitions.clear()


## 检查物品定义是否存在。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @return: 存在返回 true。
func has_definition(item_id: StringName) -> bool:
	return definitions.has(item_id) or definitions.has(String(item_id))


## 获取物品定义。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @return: 物品定义；不存在时返回 null。
func get_definition(item_id: StringName) -> GFInventoryItemDefinition:
	var definition: GFInventoryItemDefinition = _get_item_definition_value(GFVariantData.get_option_value(definitions, item_id))
	if definition != null:
		return definition
	return _get_item_definition_value(GFVariantData.get_option_value(definitions, String(item_id)))


## 检查物品是否可被库存接受。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @return: 可接受返回 true。
func accepts_item(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	return allow_unregistered_items or has_definition(item_id)


## 获取单堆叠容量。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @return: 单堆叠容量。
func get_max_stack_amount(item_id: StringName) -> int:
	var definition: GFInventoryItemDefinition = get_definition(item_id)
	if definition == null:
		return default_max_stack_amount
	return definition.max_stack_amount


## 获取堆叠数量上限。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @return: 堆叠数量上限；小于等于 0 表示不限制。
func get_max_stack_count(item_id: StringName) -> int:
	var definition: GFInventoryItemDefinition = get_definition(item_id)
	if definition == null:
		return default_max_stack_count
	return definition.max_stack_count


## 规范化物品实例数据。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 规范化后的实例数据副本。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据。
## [br]
## @schema return: Dictionary，规范化后的物品实例数据副本。
func normalize_instance_data(item_id: StringName, instance_data: Dictionary = {}) -> Dictionary:
	var definition: GFInventoryItemDefinition = get_definition(item_id)
	if definition == null:
		return instance_data.duplicate(true)
	return definition.normalize_instance_data(instance_data)


## 判断两份实例数据是否可合并堆叠。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param left: 左侧实例数据。
## [br]
## @param right: 右侧实例数据。
## [br]
## @return: 可合并返回 true。
## [br]
## @schema left: Dictionary，左侧物品实例数据。
## [br]
## @schema right: Dictionary，右侧物品实例数据。
func are_instance_data_compatible(
	item_id: StringName,
	left: Dictionary = {},
	right: Dictionary = {}
) -> bool:
	var definition: GFInventoryItemDefinition = get_definition(item_id)
	if definition == null:
		return left == right
	return definition.are_instance_data_compatible(left, right)


## 转换为字典。
## [br]
## @api public
## [br]
## @return: 可序列化字典。
## [br]
## @schema return: Dictionary，包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。
func to_dict() -> Dictionary:
	var definition_data: Dictionary = {}
	for item_id_variant: Variant in definitions.keys():
		var definition: GFInventoryItemDefinition = _get_item_definition_value(definitions[item_id_variant])
		if definition != null:
			definition_data[GFVariantData.to_text(item_id_variant)] = definition.to_dict()
	return {
		"definitions": definition_data,
		"default_max_stack_amount": default_max_stack_amount,
		"default_max_stack_count": default_max_stack_count,
		"allow_unregistered_items": allow_unregistered_items,
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary，可包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。
func apply_dict(data: Dictionary) -> void:
	definitions.clear()
	var raw_definitions: Dictionary = GFVariantData.get_option_dictionary(data, "definitions")
	for key: Variant in raw_definitions.keys():
		var definition_data: Dictionary = GFVariantData.as_dictionary(raw_definitions[key])
		if definition_data.is_empty():
			continue
		var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.from_dict(definition_data)
		if definition.item_id == &"":
			definition.item_id = StringName(GFVariantData.to_text(key))
		set_definition(definition)
	default_max_stack_amount = GFVariantData.get_option_int(data, "default_max_stack_amount", default_max_stack_amount)
	default_max_stack_count = GFVariantData.get_option_int(data, "default_max_stack_count", default_max_stack_count)
	allow_unregistered_items = GFVariantData.get_option_bool(data, "allow_unregistered_items", allow_unregistered_items)


## 从字典创建注册表。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @return: 物品定义注册表。
## [br]
## @schema data: Dictionary，可包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。
static func from_dict(data: Dictionary) -> GFInventoryItemRegistry:
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.apply_dict(data)
	return registry


# --- 私有/辅助方法 ---

func _get_item_definition_value(value: Variant) -> GFInventoryItemDefinition:
	if value is GFInventoryItemDefinition:
		var definition: GFInventoryItemDefinition = value
		return definition
	return null
