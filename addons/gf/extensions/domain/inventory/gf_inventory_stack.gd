## GFInventoryStack: 通用库存堆叠记录。
##
## 只保存物品标识、数量和实例数据，不解释实例数据的业务含义。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFInventoryStack
extends Resource


# --- 导出变量 ---

## 物品稳定标识。
## [br]
## @api public
@export var item_id: StringName = &""

## 当前堆叠数量。
## [br]
## @api public
@export var amount: int:
	get:
		return _amount
	set(value):
		_amount = maxi(value, 0)

## 项目自定义实例数据。框架只用于兼容性比较和序列化。
## [br]
## @api public
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；GF 只用于兼容性比较和序列化。
@export var instance_data: Dictionary = {}


# --- 私有变量 ---

var _amount: int = 0


# --- Godot 生命周期方法 ---

func _init(stack_item_id: StringName = &"", stack_amount: int = 0, stack_instance_data: Dictionary = {}) -> void:
	item_id = stack_item_id
	amount = stack_amount
	instance_data = stack_instance_data.duplicate(true)


# --- 公共方法 ---

## 检查堆叠是否为空。
## [br]
## @api public
## [br]
## @return: 为空返回 true。
func is_empty() -> bool:
	return item_id == &"" or amount <= 0


## 获取当前堆叠容量上限。
## [br]
## @api public
## [br]
## @param registry: 可选物品注册表。
## [br]
## @return: 堆叠容量上限。
func get_stack_limit(registry: GFInventoryItemRegistry = null) -> int:
	if registry == null:
		return 99
	return registry.get_max_stack_amount(item_id)


## 获取当前堆叠剩余空间。
## [br]
## @api public
## [br]
## @param registry: 可选物品注册表。
## [br]
## @return: 剩余空间。
func get_available_space(registry: GFInventoryItemRegistry = null) -> int:
	if is_empty():
		return get_stack_limit(registry)
	return maxi(get_stack_limit(registry) - amount, 0)


## 检查是否可与指定物品实例合并。
## [br]
## @api public
## [br]
## @param target_item_id: 目标物品标识。
## [br]
## @param target_instance_data: 目标实例数据。
## [br]
## @param registry: 可选物品注册表。
## [br]
## @return: 可合并返回 true。
## [br]
## @schema target_instance_data: Dictionary，目标物品实例数据。
func can_merge(
	target_item_id: StringName,
	target_instance_data: Dictionary = {},
	registry: GFInventoryItemRegistry = null
) -> bool:
	if is_empty():
		return true
	if item_id != target_item_id:
		return false
	if registry == null:
		return instance_data == target_instance_data
	return registry.are_instance_data_compatible(item_id, instance_data, target_instance_data)


## 增加数量并返回未加入的剩余数量。
## [br]
## @api public
## [br]
## @param quantity: 尝试增加的数量。
## [br]
## @param registry: 可选物品注册表。
## [br]
## @return: 未加入的剩余数量。
func add_amount(quantity: int, registry: GFInventoryItemRegistry = null) -> int:
	if quantity <= 0 or is_empty():
		return maxi(quantity, 0)
	var accepted: int = mini(quantity, get_available_space(registry))
	amount += accepted
	return quantity - accepted


## 移除数量并返回实际移除数量。
## [br]
## @api public
## [br]
## @param quantity: 尝试移除的数量。
## [br]
## @return: 实际移除数量。
func remove_amount(quantity: int) -> int:
	if quantity <= 0 or is_empty():
		return 0
	var removed: int = mini(quantity, amount)
	amount -= removed
	if amount <= 0:
		clear()
	return removed


## 清空堆叠。
## [br]
## @api public
func clear() -> void:
	item_id = &""
	amount = 0
	instance_data.clear()


## 复制堆叠。
## [br]
## @api public
## [br]
## @return: 新堆叠资源。
func duplicate_stack() -> GFInventoryStack:
	return GFInventoryStack.new(item_id, amount, instance_data)


## 转换为字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: Godot Variant 字典；不保证可直接编码为 JSON。
## [br]
## @schema return: Dictionary，包含 item_id、amount 与 instance_data。
func to_dict() -> Dictionary:
	return {
		"item_id": String(item_id),
		"amount": amount,
		"instance_data": instance_data.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary，可包含 item_id、amount 与 instance_data。
func apply_dict(data: Dictionary) -> void:
	item_id = GFVariantData.get_option_string_name(data, "item_id", item_id)
	amount = GFVariantData.get_option_int(data, "amount", amount)
	instance_data = GFVariantData.get_option_dictionary(data, "instance_data")
	if amount <= 0:
		clear()


## 从字典创建堆叠。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @return: 堆叠资源。
## [br]
## @schema data: Dictionary，可包含 item_id、amount 与 instance_data。
static func from_dict(data: Dictionary) -> GFInventoryStack:
	var stack: GFInventoryStack = GFInventoryStack.new()
	stack.apply_dict(data)
	return stack
