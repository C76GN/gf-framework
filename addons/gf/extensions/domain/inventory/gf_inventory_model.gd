## GFInventoryModel: 通用可序列化库存模型。
##
## 只管理 item_id、数量和元数据，不假设道具类型、品质、装备等业务概念。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFInventoryModel
extends GFModel


# --- 私有变量 ---

var _stacks: Dictionary = {}


# --- 公共方法 ---

## 添加物品数量。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @param amount: 增加数量。
## [br]
## @param metadata: 可选元数据；首次加入时保存。
## [br]
## @schema metadata: Dictionary，首次加入物品时保存的项目自定义元数据。
func add_item(item_id: StringName, amount: int = 1, metadata: Dictionary = {}) -> void:
	if item_id == &"" or amount <= 0:
		return

	var stack: Dictionary = _get_stack_record(item_id)
	stack["amount"] = GFVariantData.get_option_int(stack, "amount") + amount
	if not stack.has("metadata"):
		stack["metadata"] = metadata.duplicate(true)
	_stacks[item_id] = stack


## 移除物品数量。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @param amount: 移除数量。
## [br]
## @return: 成功移除完整数量时返回 true。
func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if item_id == &"" or amount <= 0 or not _stacks.has(item_id):
		return false

	var stack: Dictionary = _get_stack_record(item_id)
	var current_amount: int = GFVariantData.get_option_int(stack, "amount")
	if current_amount < amount:
		return false

	current_amount -= amount
	if current_amount <= 0:
		_erase_stack(item_id)
	else:
		stack["amount"] = current_amount
		_stacks[item_id] = stack
	return true


## 设置物品数量。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @param amount: 新数量；小于等于 0 时移除。
func set_item_amount(item_id: StringName, amount: int) -> void:
	if item_id == &"":
		return
	if amount <= 0:
		_erase_stack(item_id)
		return

	var stack: Dictionary = _get_stack_record(item_id)
	stack["amount"] = amount
	if not stack.has("metadata"):
		stack["metadata"] = {}
	_stacks[item_id] = stack


## 获取物品数量。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @return: 数量。
func get_item_amount(item_id: StringName) -> int:
	if not _stacks.has(item_id):
		return 0
	return GFVariantData.get_option_int(_get_stack_record(item_id), "amount")


## 检查是否拥有足够数量。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @param amount: 需要数量。
## [br]
## @return: 足够时返回 true。
func has_item(item_id: StringName, amount: int = 1) -> bool:
	return get_item_amount(item_id) >= amount


## 获取物品元数据。
## [br]
## @api public
## [br]
## @param item_id: 物品 ID。
## [br]
## @return: 元数据副本。
## [br]
## @schema return: Dictionary，物品项目自定义元数据副本；不存在时为空字典。
func get_item_metadata(item_id: StringName) -> Dictionary:
	if not _stacks.has(item_id):
		return {}
	return GFVariantData.get_option_dictionary(_get_stack_record(item_id), "metadata")


## 获取库存快照。
## [br]
## @api public
## [br]
## @return: 库存字典副本。
## [br]
## @schema return: Dictionary，键为 StringName 物品 ID，值为包含 amount 与 metadata 的堆叠记录。
func get_items() -> Dictionary:
	return _stacks.duplicate(true)


## 清空库存。
## [br]
## @api public
func clear() -> void:
	_stacks.clear()


## 序列化库存状态。
## [br]
## @api public
## [br]
## @return: 可写入存档的字典。
## [br]
## @schema return: Dictionary，包含 items 字典；items 键为 String 物品 ID，值为 amount 与 metadata 记录。
func to_dict() -> Dictionary:
	var serialized: Dictionary = {}
	for item_id: StringName in _stacks:
		serialized[String(item_id)] = _get_stack_record(item_id).duplicate(true)
	return { "items": serialized }


## 从字典恢复库存状态。
## [br]
## @api public
## [br]
## @param data: 序列化数据。
## [br]
## @schema data: Dictionary，包含 items 字典；items 键为 String 物品 ID，值为 amount 与 metadata 记录。
func from_dict(data: Dictionary) -> void:
	_stacks.clear()
	var raw_items: Dictionary = GFVariantData.get_option_dictionary(data, "items")
	for key: Variant in raw_items:
		var item_id: StringName = StringName(GFVariantData.to_text(key))
		if item_id == &"":
			continue
		var stack: Dictionary = GFVariantData.as_dictionary(raw_items[key])
		var amount: int = GFVariantData.get_option_int(stack, "amount")
		if amount <= 0:
			continue
		_stacks[item_id] = {
			"amount": amount,
			"metadata": GFVariantData.get_option_dictionary(stack, "metadata"),
		}


# --- 私有/辅助方法 ---

func _get_stack_record(item_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_stacks, item_id, {}))


func _erase_stack(item_id: StringName) -> void:
	var erased: bool = _stacks.erase(item_id)
	if erased:
		return
