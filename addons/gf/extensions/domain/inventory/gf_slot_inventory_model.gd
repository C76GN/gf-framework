## GFSlotInventoryModel: 通用可序列化槽位库存模型。
##
## 管理固定或可增长槽位中的 `GFInventoryStack`，支持槽位接收规则、
## 堆叠容量、最大堆叠数量、实例数据兼容性、移动、交换和序列化。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFSlotInventoryModel
extends GFModel


# --- 信号 ---

## 任意槽位变化时发出。
## [br]
## @api public
## [br]
## @param slot_index: 变化的槽位索引。
signal slot_changed(slot_index: int)

## 槽位内容变化时发出，并携带变化前后的稳定快照。
## [br]
## @api public
## [br]
## @param slot_index: 变化的槽位索引。
## [br]
## @param before_stack_data: 变化前的槽位堆叠字典；空槽为 `{}`。
## [br]
## @param after_stack_data: 变化后的槽位堆叠字典；空槽为 `{}`。
## [br]
## @schema before_stack_data: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽为空字典。
## [br]
## @schema after_stack_data: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽为空字典。
signal slot_state_changed(slot_index: int, before_stack_data: Dictionary, after_stack_data: Dictionary)

## 槽位从空变为有内容时发出。
## [br]
## @api public
## [br]
## @param slot_index: 变化的槽位索引。
## [br]
## @param stack_data: 新写入的槽位堆叠字典。
## [br]
## @schema stack_data: Dictionary，GFInventoryStack.to_dict() 形状的新堆叠快照。
signal slot_filled(slot_index: int, stack_data: Dictionary)

## 槽位从有内容变为空时发出。
## [br]
## @api public
## [br]
## @param slot_index: 变化的槽位索引。
## [br]
## @param previous_stack_data: 清空前的槽位堆叠字典。
## [br]
## @schema previous_stack_data: Dictionary，GFInventoryStack.to_dict() 形状的清空前堆叠快照。
signal slot_emptied(slot_index: int, previous_stack_data: Dictionary)

## 物品加入槽位后发出。
## [br]
## @api public
## [br]
## @param slot_index: 物品加入的槽位索引。
## [br]
## @param item_id: 加入的物品 ID。
## [br]
## @param amount: 实际加入数量。
signal item_added(slot_index: int, item_id: StringName, amount: int)

## 物品从槽位移除后发出。
## [br]
## @api public
## [br]
## @param slot_index: 物品移除的槽位索引。
## [br]
## @param item_id: 移除的物品 ID。
## [br]
## @param amount: 实际移除数量。
signal item_removed(slot_index: int, item_id: StringName, amount: int)

## 库存整体发生变化时发出。
## [br]
## @api public
signal inventory_changed


# --- 公共变量 ---

## 可选物品定义注册表。
## [br]
## @api public
var registry: GFInventoryItemRegistry = null

## 可选槽位定义。索引与库存槽位一致；空项表示该槽位不添加额外接收限制。
## [br]
## @api public
## [br]
## @schema slot_definitions: Array[GFInventorySlotDefinition]，按槽位索引存放的接收规则；空项表示不限制。
var slot_definitions: Array[GFInventorySlotDefinition] = []

## 是否允许库存在创建新堆叠时自动增长。
## 为 false 时，0 槽位库存不会接收 `add_item()` 的新堆叠。
## [br]
## @api public
var allow_growth: bool = false

## 默认初始槽位数量。仅在 GF 生命周期调用 `init()` 时自动应用。
## 手动创建后直接使用时，应调用 `set_slot_count()` 或启用 `allow_growth`。
## [br]
## @api public
var default_slot_count: int = 0


# --- 私有变量 ---

var _slots: Array = []
var _item_slot_index: Dictionary = {}
var _index_dirty: bool = true
var _mutation_depth: int = 0
var _is_emitting_inventory_events: bool = false
var _inventory_changed_pending: bool = false
var _pending_slot_changes: Dictionary = {}
var _pending_slot_change_order: Array[int] = []
var _pending_item_added_events: Array[Dictionary] = []
var _pending_item_removed_events: Array[Dictionary] = []


# --- GF 生命周期方法 ---

## 初始化默认槽位数量。
## [br]
## @api framework_internal
func init() -> void:
	if _slots.is_empty() and default_slot_count > 0:
		set_slot_count(default_slot_count)


# --- 公共方法 ---

## 设置物品注册表。
## [br]
## @api public
## [br]
## @param item_registry: 物品注册表。
func set_registry(item_registry: GFInventoryItemRegistry) -> void:
	if _reject_reentrant_mutation("set_registry"):
		return
	registry = item_registry
	_mark_index_dirty()


## 设置槽位数量。
## [br]
## @api public
## [br]
## @param count: 新槽位数量。
## [br]
## @param preserve_existing: 是否保留已有槽位内容。
func set_slot_count(count: int, preserve_existing: bool = true) -> void:
	if not _begin_inventory_mutation("set_slot_count"):
		return
	var next_count: int = maxi(count, 0)
	var before_slots: Array[Dictionary] = _snapshot_slots(maxi(_slots.size(), next_count))
	var next_slots: Array = []
	for index: int in range(next_count):
		if preserve_existing and index < _slots.size():
			next_slots.append(_slots[index])
		else:
			next_slots.append(null)
	_slots = next_slots
	_resize_slot_definitions(next_count)
	for index: int in range(before_slots.size()):
		_record_slot_change(index, before_slots[index], _snapshot_slot_data(index))
	_mark_inventory_changed()
	_end_inventory_mutation()


## 获取槽位数量。
## [br]
## @api public
## [br]
## @return: 槽位数量。
func get_slot_count() -> int:
	return _slots.size()


## 检查槽位索引是否有效。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 有效返回 true。
func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size()


## 设置槽位定义。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param definition: 槽位定义；传 null 表示清除该槽位额外规则。
## [br]
## @return: 成功返回 true。
func set_slot_definition(slot_index: int, definition: GFInventorySlotDefinition) -> bool:
	if _reject_reentrant_mutation("set_slot_definition"):
		return false
	if not is_valid_slot(slot_index):
		return false
	_resize_slot_definitions(_slots.size())
	slot_definitions[slot_index] = definition
	return true


## 获取槽位定义。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 槽位定义；无额外规则或无效槽位返回 null。
func get_slot_definition(slot_index: int) -> GFInventorySlotDefinition:
	if not is_valid_slot(slot_index) or slot_index >= slot_definitions.size():
		return null
	return slot_definitions[slot_index]


## 检查指定物品是否可被槽位接收。
##
## 该方法只检查全局注册表与槽位定义，不判断当前槽位是否为空、
## 是否可与已有堆叠合并或是否有剩余容量。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 槽位可接收该物品时返回 true。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；会先经注册表规范化。
func can_accept_item_at_slot(
	slot_index: int,
	item_id: StringName,
	instance_data: Dictionary = {}
) -> bool:
	if not is_valid_slot(slot_index) or item_id == &"" or not _accepts_item(item_id):
		return false

	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	return _slot_accepts_item(slot_index, item_id, normalized_data)


## 获取槽位堆叠副本。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 堆叠副本；空槽或无效槽位返回 null。
func get_stack(slot_index: int) -> GFInventoryStack:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	return stack.duplicate_stack() if stack != null else null


## 获取槽位堆叠字典。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 堆叠字典；空槽或无效槽位返回空字典。
## [br]
## @schema return: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽或无效槽位为空字典。
func get_stack_data(slot_index: int) -> Dictionary:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	return stack.to_dict() if stack != null else {}


## 检查槽位是否为空。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 空槽位返回 true。
func is_slot_empty(slot_index: int) -> bool:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	return stack == null or stack.is_empty()


## 设置指定槽位堆叠。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param stack: 堆叠；传 null 表示清空。
## [br]
## @return: 成功返回 true。
func set_stack(slot_index: int, stack: GFInventoryStack) -> bool:
	if not _begin_inventory_mutation("set_stack"):
		return false
	if not is_valid_slot(slot_index):
		_end_inventory_mutation()
		return false
	var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
	_slots[slot_index] = stack.duplicate_stack() if stack != null and not stack.is_empty() else null
	_record_slot_after_change(slot_index, before_stack_data)
	_end_inventory_mutation()
	return true


## 清空指定槽位。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return: 成功返回 true。
func clear_slot(slot_index: int) -> bool:
	if not _begin_inventory_mutation("clear_slot"):
		return false
	if not is_valid_slot(slot_index):
		_end_inventory_mutation()
		return false
	var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
	_slots[slot_index] = null
	_record_slot_after_change(slot_index, before_stack_data)
	_end_inventory_mutation()
	return true


## 清空全部槽位内容。
## [br]
## @api public
func clear() -> void:
	if not _begin_inventory_mutation("clear"):
		return
	var before_slots: Array[Dictionary] = _snapshot_slots(_slots.size())
	for index: int in range(_slots.size()):
		_slots[index] = null
		_record_slot_change(index, before_slots[index], _snapshot_slot_data(index))
	_mark_inventory_changed()
	_end_inventory_mutation()


## 添加物品到库存。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param amount: 添加数量。
## [br]
## @param instance_data: 实例数据。
## [br]
## @param start_slot: 起始槽位；小于 0 时从头开始。
## [br]
## @param partial_add: 容量不足时是否允许部分加入。
## [br]
## @return: 操作结果。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；会先经注册表规范化。
func add_item(
	item_id: StringName,
	amount: int = 1,
	instance_data: Dictionary = {},
	start_slot: int = -1,
	partial_add: bool = true
) -> GFInventoryOperationResult:
	if item_id == &"" or amount <= 0:
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"invalid_request")
	if not _accepts_item(item_id):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"item_not_registered")
	if not partial_add and get_remaining_capacity_for_item(item_id, instance_data) < amount:
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"not_enough_space")
	if not _begin_inventory_mutation("add_item"):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"reentrant_mutation")

	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	var remaining: int = amount
	for slot_index: int in _ordered_slot_indices(start_slot):
		remaining = _try_add_to_existing_stack(slot_index, item_id, remaining, normalized_data)
		if remaining <= 0:
			_end_inventory_mutation()
			return GFInventoryOperationResult.success(item_id, amount)

	while remaining > 0 and (_has_empty_slot_for_item(item_id, normalized_data) or allow_growth):
		if not _can_create_new_stack(item_id):
			break
		var empty_slot: int = _find_empty_slot_for_item(item_id, normalized_data)
		if empty_slot == -1 and allow_growth:
			_slots.append(null)
			slot_definitions.append(null)
			empty_slot = _slots.size() - 1
		if empty_slot == -1:
			break
		remaining = _try_add_to_empty_slot(empty_slot, item_id, remaining, normalized_data)

	var accepted: int = amount - remaining
	var reason: StringName = &"ok" if remaining <= 0 else &"not_enough_space"
	_end_inventory_mutation()
	return GFInventoryOperationResult.partial(item_id, amount, accepted, reason)


## 添加物品到指定槽位。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param item_id: 物品标识。
## [br]
## @param amount: 添加数量。
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 操作结果。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；会先经注册表规范化。
func add_item_to_slot(
	slot_index: int,
	item_id: StringName,
	amount: int = 1,
	instance_data: Dictionary = {}
) -> GFInventoryOperationResult:
	if not is_valid_slot(slot_index):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"invalid_slot", -1, slot_index)
	if item_id == &"" or amount <= 0 or not _accepts_item(item_id):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"invalid_request", -1, slot_index)
	if not _begin_inventory_mutation("add_item_to_slot"):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"reentrant_mutation", -1, slot_index)

	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	if not _slot_accepts_item(slot_index, item_id, normalized_data):
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"slot_rejects_item", -1, slot_index)

	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	var remaining: int = amount
	if stack == null:
		if not _can_create_new_stack(item_id):
			_end_inventory_mutation()
			return GFInventoryOperationResult.partial(item_id, amount, 0, &"stack_count_limit", -1, slot_index)
		remaining = _try_add_to_empty_slot(slot_index, item_id, remaining, normalized_data)
	elif stack.can_merge(item_id, normalized_data, registry):
		remaining = _try_add_to_existing_stack(slot_index, item_id, remaining, normalized_data)
	else:
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"incompatible_stack", -1, slot_index)

	_end_inventory_mutation()
	return GFInventoryOperationResult.partial(item_id, amount, amount - remaining, &"ok", -1, slot_index)


## 从库存移除物品。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param amount: 移除数量。
## [br]
## @param instance_data: 实例数据。
## [br]
## @param start_slot: 起始槽位；小于 0 时从头开始。
## [br]
## @param partial_remove: 数量不足时是否允许部分移除。
## [br]
## @return: 操作结果。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；为空时匹配全部同 ID 物品。
func remove_item(
	item_id: StringName,
	amount: int = 1,
	instance_data: Dictionary = {},
	start_slot: int = -1,
	partial_remove: bool = true
) -> GFInventoryOperationResult:
	if item_id == &"" or amount <= 0:
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"invalid_request")
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	if not partial_remove and get_item_total(item_id, normalized_data) < amount:
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"not_enough_items")
	if not _begin_inventory_mutation("remove_item"):
		return GFInventoryOperationResult.partial(item_id, amount, 0, &"reentrant_mutation")

	var remaining: int = amount
	for slot_index: int in _ordered_slot_indices(start_slot):
		var stack: GFInventoryStack = _get_stack_ref(slot_index)
		if stack == null or not stack.can_merge(item_id, normalized_data, registry):
			continue
		var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
		var removed: int = stack.remove_amount(remaining)
		remaining -= removed
		if removed > 0:
			_record_item_removed(slot_index, item_id, removed)
			if stack.is_empty():
				_slots[slot_index] = null
			_record_slot_after_change(slot_index, before_stack_data)
		if remaining <= 0:
			_end_inventory_mutation()
			return GFInventoryOperationResult.success(item_id, amount)

	var accepted: int = amount - remaining
	var reason: StringName = &"ok" if remaining <= 0 else &"not_enough_items"
	_end_inventory_mutation()
	return GFInventoryOperationResult.partial(item_id, amount, accepted, reason)


## 从指定槽位移除物品。
## [br]
## @api public
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param amount: 移除数量。
## [br]
## @return: 操作结果。
func remove_item_from_slot(slot_index: int, amount: int = 1) -> GFInventoryOperationResult:
	if not _begin_inventory_mutation("remove_item_from_slot"):
		return GFInventoryOperationResult.partial(&"", amount, 0, &"reentrant_mutation", slot_index)
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	if stack == null or amount <= 0:
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(&"", amount, 0, &"invalid_slot", slot_index)
	var item_id: StringName = stack.item_id
	var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
	var removed: int = stack.remove_amount(amount)
	if stack.is_empty():
		_slots[slot_index] = null
	if removed > 0:
		_record_item_removed(slot_index, item_id, removed)
		_record_slot_after_change(slot_index, before_stack_data)
	_end_inventory_mutation()
	return GFInventoryOperationResult.partial(item_id, amount, removed, &"ok", slot_index)


## 交换两个槽位内容。
## [br]
## @api public
## [br]
## @param first_slot: 第一个槽位。
## [br]
## @param second_slot: 第二个槽位。
## [br]
## @return: 成功返回 true。
func swap_slots(first_slot: int, second_slot: int) -> bool:
	if not _begin_inventory_mutation("swap_slots"):
		return false
	if not is_valid_slot(first_slot) or not is_valid_slot(second_slot):
		_end_inventory_mutation()
		return false
	if first_slot == second_slot:
		_end_inventory_mutation()
		return true
	var first_before: Dictionary = _snapshot_slot_data(first_slot)
	var second_before: Dictionary = _snapshot_slot_data(second_slot)
	var first_stack: Variant = _slots[first_slot]
	_slots[first_slot] = _slots[second_slot]
	_slots[second_slot] = first_stack
	_record_slot_after_change(first_slot, first_before)
	_record_slot_after_change(second_slot, second_before)
	_end_inventory_mutation()
	return true


## 按排序规则重排槽位内容。
##
## 默认排序把非空槽位排在前面，再按 item_id 和原槽位索引稳定排序。
## 可传入回调覆盖本次排序，或继承并重写 `_should_sort_slot_before()`。
## [br]
## @api public
## [br]
## @param order_resolver: 可选比较回调，签名为 `func(left_slot_index, left_stack_data, right_slot_index, right_stack_data) -> bool`。
## [br]
## @return: 槽位顺序发生变化时返回 true。
func sort_slots(order_resolver: Callable = Callable()) -> bool:
	if not _begin_inventory_mutation("sort_slots"):
		return false
	var before_slots: Array[Dictionary] = _snapshot_slots(_slots.size())
	var entries: Array[Dictionary] = []
	for index: int in range(_slots.size()):
		entries.append({
			"slot_index": index,
			"stack": _slots[index],
			"stack_data": before_slots[index].duplicate(true),
		})

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _should_sort_entry_before(left, right, order_resolver)
	)

	for index: int in range(entries.size()):
		_slots[index] = entries[index]["stack"]
		_record_slot_change(index, before_slots[index], _snapshot_slot_data(index))

	var changed: bool = not _pending_slot_change_order.is_empty()
	if changed:
		_mark_inventory_changed()
	_end_inventory_mutation()
	return changed


## 移动一个槽位的内容到另一个槽位，目标为空时移动，兼容时合并。
## [br]
## @api public
## [br]
## @param source_slot: 源槽位。
## [br]
## @param target_slot: 目标槽位。
## [br]
## @param amount: 移动数量；小于等于 0 时移动全部。
## [br]
## @return: 操作结果。
func move_between_slots(source_slot: int, target_slot: int, amount: int = 0) -> GFInventoryOperationResult:
	if not _begin_inventory_mutation("move_between_slots"):
		return GFInventoryOperationResult.partial(&"", amount, 0, &"reentrant_mutation", source_slot, target_slot)
	if source_slot == target_slot:
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(&"", amount, 0, &"same_slot", source_slot, target_slot)
	var source_stack: GFInventoryStack = _get_stack_ref(source_slot)
	if source_stack == null or not is_valid_slot(target_slot):
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(&"", amount, 0, &"invalid_slot", source_slot, target_slot)

	var source_before: Dictionary = _snapshot_slot_data(source_slot)
	var target_before: Dictionary = _snapshot_slot_data(target_slot)
	var move_amount: int = source_stack.amount if amount <= 0 else mini(amount, source_stack.amount)
	var target_stack: GFInventoryStack = _get_stack_ref(target_slot)
	if not _slot_accepts_item(target_slot, source_stack.item_id, source_stack.instance_data):
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(source_stack.item_id, move_amount, 0, &"slot_rejects_item", source_slot, target_slot)

	if target_stack == null:
		if source_stack.amount > move_amount and not _can_create_new_stack(source_stack.item_id):
			_end_inventory_mutation()
			return GFInventoryOperationResult.partial(source_stack.item_id, move_amount, 0, &"stack_count_limit", source_slot, target_slot)
		var moved_stack: GFInventoryStack = source_stack.duplicate_stack()
		var moved_amount: int = source_stack.remove_amount(move_amount)
		if moved_amount <= 0:
			_end_inventory_mutation()
			return GFInventoryOperationResult.partial(source_stack.item_id, move_amount, 0, &"invalid_slot", source_slot, target_slot)
		moved_stack.amount = moved_amount
		_slots[target_slot] = moved_stack
		if source_stack.is_empty():
			_slots[source_slot] = null
		_record_slot_after_change(source_slot, source_before)
		_record_slot_after_change(target_slot, target_before)
		_end_inventory_mutation()
		return GFInventoryOperationResult.success(moved_stack.item_id, moved_amount, source_slot, target_slot)

	if not target_stack.can_merge(source_stack.item_id, source_stack.instance_data, registry):
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(source_stack.item_id, move_amount, 0, &"incompatible_stack", source_slot, target_slot)

	var accepted: int = mini(move_amount, target_stack.get_available_space(registry))
	if accepted <= 0:
		_end_inventory_mutation()
		return GFInventoryOperationResult.partial(source_stack.item_id, move_amount, 0, &"not_enough_space", source_slot, target_slot)
	target_stack.amount += accepted
	var removed_from_source: int = source_stack.remove_amount(accepted)
	if removed_from_source < accepted:
		target_stack.amount -= accepted - removed_from_source
		accepted = removed_from_source
	if source_stack.is_empty():
		_slots[source_slot] = null
	_record_slot_after_change(source_slot, source_before)
	_record_slot_after_change(target_slot, target_before)
	_end_inventory_mutation()
	return GFInventoryOperationResult.partial(target_stack.item_id, move_amount, accepted, &"ok", source_slot, target_slot)


## 获取指定物品总数量。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 实例数据。为空时统计全部同 ID 物品。
## [br]
## @return: 总数量。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；为空时统计全部同 ID 物品。
func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:
	var total: int = 0
	var filter_by_instance: bool = not instance_data.is_empty()
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	for stack_variant: Variant in _slots:
		var stack: GFInventoryStack = _get_inventory_stack_value(stack_variant)
		if stack == null or stack.item_id != item_id:
			continue
		if filter_by_instance and not stack.can_merge(item_id, normalized_data, registry):
			continue
		total += stack.amount
	return total


## 检查是否拥有足够数量。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param amount: 需要数量。
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 数量足够返回 true。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；为空时统计全部同 ID 物品。
func has_item(item_id: StringName, amount: int = 1, instance_data: Dictionary = {}) -> bool:
	return get_item_total(item_id, instance_data) >= amount


## 获取指定物品剩余可加入容量。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 实例数据。
## [br]
## @return: 剩余容量。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；用于筛选可合并堆叠。
func get_remaining_capacity_for_item(item_id: StringName, instance_data: Dictionary = {}) -> int:
	if not _accepts_item(item_id):
		return 0
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	var capacity: int = 0
	for index: int in range(_slots.size()):
		var stack: GFInventoryStack = _get_inventory_stack_value(_slots[index])
		if stack == null:
			continue
		if stack.can_merge(item_id, normalized_data, registry) and _slot_accepts_item(index, item_id, normalized_data):
			capacity += stack.get_available_space(registry)

	var max_stack_count: int = _get_max_stack_count(item_id)
	var current_stack_count: int = _get_stack_count_for_item(item_id)
	var free_stack_slots: int = _get_empty_slot_count_for_item(item_id, normalized_data)
	if allow_growth and max_stack_count <= 0:
		return capacity + 2147483647
	if max_stack_count > 0:
		var remaining_stack_slots: int = maxi(max_stack_count - current_stack_count, 0)
		free_stack_slots = remaining_stack_slots if allow_growth else mini(free_stack_slots, remaining_stack_slots)
	capacity += free_stack_slots * _get_max_stack_amount(item_id)
	return capacity


## 获取空槽位索引。
## [br]
## @api public
## [br]
## @return: 空槽位索引数组。
func get_empty_slot_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for index: int in range(_slots.size()):
		if is_slot_empty(index):
			_append_packed_int32(result, index)
	return result


## 获取已占用槽位索引。
## [br]
## @api public
## [br]
## @return: 已占用槽位索引数组。
func get_occupied_slot_indices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for index: int in range(_slots.size()):
		if not is_slot_empty(index):
			_append_packed_int32(result, index)
	return result


## 获取指定物品所在槽位索引。
## [br]
## @api public
## [br]
## @param item_id: 物品标识。
## [br]
## @param instance_data: 实例数据。为空时返回全部同 ID 槽位。
## [br]
## @return: 槽位索引列表。
## [br]
## @schema instance_data: Dictionary，项目自定义物品实例数据；为空时返回全部同 ID 槽位。
func get_slots_for_item(item_id: StringName, instance_data: Dictionary = {}) -> PackedInt32Array:
	_rebuild_index_if_needed()
	var result: PackedInt32Array = PackedInt32Array()
	var raw_indices: PackedInt32Array = _get_slot_index_entries(item_id)
	var filter_by_instance: bool = not instance_data.is_empty()
	var normalized_data: Dictionary = _normalize_instance_data(item_id, instance_data)
	for slot_index: int in raw_indices:
		var stack: GFInventoryStack = _get_stack_ref(slot_index)
		if stack == null:
			continue
		if filter_by_instance and not stack.can_merge(item_id, normalized_data, registry):
			continue
		_append_packed_int32(result, slot_index)
	return result


## 立即重建物品到槽位的索引。
## [br]
## @api public
func rebuild_index() -> void:
	_item_slot_index.clear()
	for index: int in range(_slots.size()):
		var stack: GFInventoryStack = _get_stack_ref(index)
		if stack == null or stack.is_empty():
			continue
		if not _item_slot_index.has(stack.item_id):
			_item_slot_index[stack.item_id] = PackedInt32Array()
		var indices: PackedInt32Array = _get_slot_index_entries(stack.item_id)
		_append_packed_int32(indices, index)
		_item_slot_index[stack.item_id] = indices
	_index_dirty = false


## 获取索引调试快照。
## [br]
## @api public
## [br]
## @return: 索引快照字典。
## [br]
## @schema return: Dictionary，包含 dirty: bool、item_count: int、stack_count_by_item: Dictionary 与 slot_indices_by_item: Dictionary。
func get_index_debug_snapshot() -> Dictionary:
	_rebuild_index_if_needed()
	var stack_count_by_item: Dictionary = {}
	var slot_indices_by_item: Dictionary = {}
	for item_id_variant: Variant in _item_slot_index.keys():
		var item_id: StringName = _get_non_empty_string_name(item_id_variant)
		var indices: PackedInt32Array = _get_slot_index_entries(item_id)
		var slot_indices: Array[int] = []
		for slot_index: int in indices:
			slot_indices.append(slot_index)
		var key: String = String(item_id)
		stack_count_by_item[key] = indices.size()
		slot_indices_by_item[key] = slot_indices
	return {
		"dirty": _index_dirty,
		"item_count": _item_slot_index.size(),
		"stack_count_by_item": stack_count_by_item,
		"slot_indices_by_item": slot_indices_by_item,
	}


## 校验当前库存内容是否满足注册表约束。
## [br]
## @api public
## [br]
## @return: 校验报告字典。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、next_action、issue_count 与 issues；issues 每项包含 severity、kind、slot_index、item_id 与 message。
func validate_inventory() -> Dictionary:
	var report: Dictionary = _make_validation_report()
	var stack_counts: Dictionary = {}
	for index: int in range(_slots.size()):
		var stack: GFInventoryStack = _get_stack_ref(index)
		if stack == null:
			continue
		if stack.is_empty():
			_add_validation_issue(report, "warning", "empty_stack", index, stack.item_id, "槽位中存在空堆叠。")
			continue
		if not _accepts_item(stack.item_id):
			_add_validation_issue(report, "error", "unregistered_item", index, stack.item_id, "物品未被注册表接受。")
		if not _slot_accepts_item(index, stack.item_id, stack.instance_data):
			_add_validation_issue(report, "error", "slot_rejects_item", index, stack.item_id, "槽位规则拒绝该物品。")
		var stack_limit: int = _get_max_stack_amount(stack.item_id)
		if stack.amount > stack_limit:
			_add_validation_issue(report, "error", "stack_amount_exceeds_limit", index, stack.item_id, "堆叠数量超过单堆叠上限。")
		stack_counts[stack.item_id] = GFVariantData.get_option_int(stack_counts, stack.item_id) + 1

	for item_id: StringName in stack_counts.keys():
		var max_stack_count: int = _get_max_stack_count(item_id)
		if max_stack_count > 0 and GFVariantData.get_option_int(stack_counts, item_id) > max_stack_count:
			_add_validation_issue(report, "error", "stack_count_exceeds_limit", -1, item_id, "物品堆叠数量超过注册表上限。")
	_finalize_validation_report(report)
	return report


## 应用注册表约束并返回报告。
## [br]
## @api public
## [br]
## @param repair: 为 true 时会移除不合法堆叠并裁剪超过上限的数量。
## [br]
## @return: 校验报告字典。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、next_action、issue_count 与 issues；repair 为 true 时会同步修复可修复堆叠。
func apply_registry_constraints(repair: bool = false) -> Dictionary:
	var report: Dictionary = validate_inventory()
	if not repair:
		return report
	if not _begin_inventory_mutation("apply_registry_constraints"):
		return report

	var stack_counts: Dictionary = {}
	for index: int in range(_slots.size()):
		var stack: GFInventoryStack = _get_stack_ref(index)
		if stack == null:
			continue
		var before_stack_data: Dictionary = _snapshot_slot_data(index)
		if stack.is_empty() or not _accepts_item(stack.item_id) or not _slot_accepts_item(index, stack.item_id, stack.instance_data):
			_slots[index] = null
			_record_slot_after_change(index, before_stack_data)
			continue
		var stack_limit: int = _get_max_stack_amount(stack.item_id)
		if stack.amount > stack_limit:
			stack.amount = stack_limit
			_record_slot_after_change(index, before_stack_data)
		stack_counts[stack.item_id] = GFVariantData.get_option_int(stack_counts, stack.item_id) + 1
		var max_stack_count: int = _get_max_stack_count(stack.item_id)
		if max_stack_count > 0 and GFVariantData.get_option_int(stack_counts, stack.item_id) > max_stack_count:
			before_stack_data = _snapshot_slot_data(index)
			_slots[index] = null
			_record_slot_after_change(index, before_stack_data)
	_end_inventory_mutation()
	return report


## 获取库存调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: Dictionary，包含 slot_count、occupied_slot_count、empty_slot_count、allow_growth、items 与 index。
func get_debug_snapshot() -> Dictionary:
	return {
		"slot_count": _slots.size(),
		"occupied_slot_count": get_occupied_slot_indices().size(),
		"empty_slot_count": get_empty_slot_indices().size(),
		"allow_growth": allow_growth,
		"items": _get_item_totals(),
		"index": get_index_debug_snapshot(),
	}


## 序列化为字典。
## [br]
## @api public
## [br]
## @return: 可序列化字典。
## [br]
## @schema return: Dictionary，包含 slot_count、allow_growth 与 slots；slots 每项为 GFInventoryStack.to_dict() 形状或空字典。
func to_dict() -> Dictionary:
	var stack_data: Array[Dictionary] = []
	for stack_variant: Variant in _slots:
		var stack: GFInventoryStack = _get_inventory_stack_value(stack_variant)
		stack_data.append(stack.to_dict() if stack != null else {})
	return {
		"slot_count": _slots.size(),
		"allow_growth": allow_growth,
		"slots": stack_data,
	}


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: 序列化数据。
## [br]
## @schema data: Dictionary，包含 slot_count、allow_growth 与 slots；slots 每项为 GFInventoryStack.to_dict() 形状或空字典。
func from_dict(data: Dictionary) -> void:
	var slot_count_value: Variant = GFVariantData.get_option_value(data, "slot_count", null)
	var slots_value: Variant = GFVariantData.get_option_value(data, "slots", null)
	if (
		typeof(slot_count_value) != TYPE_INT
		or GFVariantData.to_int(slot_count_value, -1) < 0
		or not (slots_value is Array)
		or GFVariantData.as_array(slots_value).size() != GFVariantData.to_int(slot_count_value, -1)
	):
		push_error("[GFSlotInventoryModel] from_dict 失败：快照必须包含非负整数 slot_count，且 slots 数量必须与其一致。")
		return
	if not _begin_inventory_mutation("from_dict"):
		return
	allow_growth = GFVariantData.get_option_bool(data, "allow_growth", allow_growth)
	var slot_count: int = GFVariantData.get_option_int(data, "slot_count")
	var raw_slots: Array = GFVariantData.get_option_array(data, "slots")
	var count: int = maxi(slot_count, 0)
	var before_slots: Array[Dictionary] = _snapshot_slots(maxi(_slots.size(), count))
	_slots.clear()
	for index: int in range(count):
		var stack_data: Dictionary = {}
		if index < raw_slots.size():
			stack_data = GFVariantData.as_dictionary(raw_slots[index])
		if stack_data.is_empty():
			_slots.append(null)
		else:
			var stack: GFInventoryStack = GFInventoryStack.from_dict(stack_data)
			_slots.append(stack if not stack.is_empty() else null)
	_resize_slot_definitions(count)
	for index: int in range(before_slots.size()):
		_record_slot_change(index, before_slots[index], _snapshot_slot_data(index))
	_mark_inventory_changed()
	_end_inventory_mutation()


# --- 可重写钩子 / 虚方法 ---

## 判断左侧槽位是否应排在右侧槽位之前。
##
## `sort_slots()` 会传入排序前的槽位索引和堆叠快照。空槽位快照为 `{}`。
## 子类可重写该方法实现项目自己的格子排序规则。
## [br]
## @api protected
## [br]
## @param left_slot_index: 左侧槽位原索引。
## [br]
## @param left_stack_data: 左侧槽位堆叠快照。
## [br]
## @param right_slot_index: 右侧槽位原索引。
## [br]
## @param right_stack_data: 右侧槽位堆叠快照。
## [br]
## @return: 左侧是否应排在右侧之前。
## [br]
## @schema left_stack_data: Dictionary，GFInventoryStack.to_dict() 形状的左侧槽位快照；空槽为空字典。
## [br]
## @schema right_stack_data: Dictionary，GFInventoryStack.to_dict() 形状的右侧槽位快照；空槽为空字典。
func _should_sort_slot_before(
	left_slot_index: int,
	left_stack_data: Dictionary,
	right_slot_index: int,
	right_stack_data: Dictionary
) -> bool:
	var left_empty: bool = _is_empty_stack_data(left_stack_data)
	var right_empty: bool = _is_empty_stack_data(right_stack_data)
	if left_empty != right_empty:
		return not left_empty
	if left_empty:
		return left_slot_index < right_slot_index

	var left_item_id: String = GFVariantData.get_option_string(left_stack_data, "item_id")
	var right_item_id: String = GFVariantData.get_option_string(right_stack_data, "item_id")
	if left_item_id != right_item_id:
		return left_item_id < right_item_id
	return left_slot_index < right_slot_index


# --- 私有/辅助方法 ---

func _get_non_empty_string_name(value: Variant, default_value: StringName = &"") -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return default_value if string_name_value == &"" else string_name_value
	if value is String:
		var text_value: String = value
		var trimmed_value: String = text_value.strip_edges()
		return default_value if trimmed_value.is_empty() else StringName(trimmed_value)
	return default_value


func _get_inventory_stack_value(value: Variant) -> GFInventoryStack:
	if value is GFInventoryStack:
		return value
	return null


func _get_packed_int32_array_value(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value
	var result: PackedInt32Array = PackedInt32Array()
	if value is Array:
		for item: Variant in GFVariantData.as_array(value):
			_append_packed_int32(result, GFVariantData.to_int(item))
	return result


func _get_slot_index_entries(item_id: StringName) -> PackedInt32Array:
	return _get_packed_int32_array_value(GFVariantData.get_option_value(_item_slot_index, item_id, PackedInt32Array()))


func _append_packed_int32(target: PackedInt32Array, value: int) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _begin_inventory_mutation(method_name: String) -> bool:
	if _is_emitting_inventory_events:
		push_error("[GFSlotInventoryModel] %s 失败：库存变更通知派发中不允许同步修改库存。请使用 call_deferred() 或在当前通知结束后再修改。" % method_name)
		return false
	if _mutation_depth > 0:
		push_error("[GFSlotInventoryModel] %s 失败：库存变更处理中不允许同步修改库存。请在当前操作结束后再修改。" % method_name)
		return false
	_mutation_depth += 1
	return true


func _end_inventory_mutation() -> void:
	_mutation_depth = maxi(_mutation_depth - 1, 0)
	if _mutation_depth == 0:
		_flush_inventory_events()


func _reject_reentrant_mutation(method_name: String) -> bool:
	if _is_emitting_inventory_events:
		push_error("[GFSlotInventoryModel] %s 失败：库存变更通知派发中不允许同步修改库存。请使用 call_deferred() 或在当前通知结束后再修改。" % method_name)
		return true
	if _mutation_depth > 0:
		push_error("[GFSlotInventoryModel] %s 失败：库存变更处理中不允许同步修改库存。请在当前操作结束后再修改。" % method_name)
		return true
	return false


func _get_stack_ref(slot_index: int) -> GFInventoryStack:
	if not is_valid_slot(slot_index):
		return null
	return _get_inventory_stack_value(_slots[slot_index])


func _accepts_item(item_id: StringName) -> bool:
	if registry == null:
		return item_id != &""
	return registry.accepts_item(item_id)


func _normalize_instance_data(item_id: StringName, instance_data: Dictionary) -> Dictionary:
	if registry == null:
		return instance_data.duplicate(true)
	return registry.normalize_instance_data(item_id, instance_data)


func _get_max_stack_amount(item_id: StringName) -> int:
	if registry == null:
		return 99
	return registry.get_max_stack_amount(item_id)


func _get_max_stack_count(item_id: StringName) -> int:
	if registry == null:
		return 0
	return registry.get_max_stack_count(item_id)


func _get_stack_count_for_item(item_id: StringName) -> int:
	var count: int = 0
	for stack_variant: Variant in _slots:
		var stack: GFInventoryStack = _get_inventory_stack_value(stack_variant)
		if stack != null and stack.item_id == item_id:
			count += 1
	return count


func _can_create_new_stack(item_id: StringName) -> bool:
	var max_stack_count: int = _get_max_stack_count(item_id)
	return max_stack_count <= 0 or _get_stack_count_for_item(item_id) < max_stack_count


func _resize_slot_definitions(count: int) -> void:
	while slot_definitions.size() < count:
		slot_definitions.append(null)
	while slot_definitions.size() > count:
		slot_definitions.remove_at(slot_definitions.size() - 1)


func _slot_accepts_item(slot_index: int, item_id: StringName, instance_data: Dictionary) -> bool:
	if not is_valid_slot(slot_index):
		return false

	var slot_definition: GFInventorySlotDefinition = get_slot_definition(slot_index)
	if slot_definition == null:
		return true

	var item_definition: GFInventoryItemDefinition = null
	if registry != null:
		item_definition = registry.get_definition(item_id)
	return slot_definition.can_accept(item_id, item_definition, instance_data, slot_index, self)


func _ordered_slot_indices(start_slot: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if _slots.is_empty():
		return result
	var start: int = clampi(start_slot, 0, _slots.size() - 1) if start_slot >= 0 else 0
	for offset: int in range(_slots.size()):
		_append_packed_int32(result, (start + offset) % _slots.size())
	return result


func _try_add_to_existing_stack(
	slot_index: int,
	item_id: StringName,
	remaining: int,
	instance_data: Dictionary
) -> int:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	if (
		stack == null
		or not stack.can_merge(item_id, instance_data, registry)
		or not _slot_accepts_item(slot_index, item_id, instance_data)
	):
		return remaining
	var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
	var before: int = stack.amount
	var next_remaining: int = stack.add_amount(remaining, registry)
	var added: int = stack.amount - before
	if added > 0:
		_record_item_added(slot_index, item_id, added)
		_record_slot_after_change(slot_index, before_stack_data)
	return next_remaining


func _try_add_to_empty_slot(
	slot_index: int,
	item_id: StringName,
	remaining: int,
	instance_data: Dictionary
) -> int:
	if not _slot_accepts_item(slot_index, item_id, instance_data):
		return remaining
	var accepted: int = mini(remaining, _get_max_stack_amount(item_id))
	if accepted <= 0:
		return remaining
	var before_stack_data: Dictionary = _snapshot_slot_data(slot_index)
	_slots[slot_index] = GFInventoryStack.new(item_id, accepted, instance_data)
	_record_item_added(slot_index, item_id, accepted)
	_record_slot_after_change(slot_index, before_stack_data)
	return remaining - accepted


func _has_empty_slot_for_item(item_id: StringName, instance_data: Dictionary) -> bool:
	return _find_empty_slot_for_item(item_id, instance_data) != -1


func _find_empty_slot_for_item(item_id: StringName, instance_data: Dictionary) -> int:
	for index: int in range(_slots.size()):
		if is_slot_empty(index) and _slot_accepts_item(index, item_id, instance_data):
			return index
	return -1


func _get_empty_slot_count_for_item(item_id: StringName, instance_data: Dictionary) -> int:
	var count: int = 0
	for index: int in range(_slots.size()):
		if is_slot_empty(index) and _slot_accepts_item(index, item_id, instance_data):
			count += 1
	return count


func _record_slot_after_change(slot_index: int, before_stack_data: Dictionary) -> void:
	_record_slot_change(slot_index, before_stack_data, _snapshot_slot_data(slot_index))


func _record_slot_change(slot_index: int, before_stack_data: Dictionary, after_stack_data: Dictionary) -> void:
	if before_stack_data == after_stack_data:
		return
	_mark_index_dirty()
	_mark_inventory_changed()
	if not _pending_slot_changes.has(slot_index):
		_pending_slot_change_order.append(slot_index)
		_pending_slot_changes[slot_index] = {
			"before": before_stack_data.duplicate(true),
			"after": after_stack_data.duplicate(true),
		}
		return

	var event: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_pending_slot_changes, slot_index, {}))
	event["after"] = after_stack_data.duplicate(true)
	var before_event_data: Dictionary = GFVariantData.get_option_dictionary(event, "before")
	var after_event_data: Dictionary = GFVariantData.get_option_dictionary(event, "after")
	if before_event_data == after_event_data:
		_erase_dictionary_key(_pending_slot_changes, slot_index)
		_pending_slot_change_order.erase(slot_index)


func _record_item_added(slot_index: int, item_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_pending_item_added_events.append({
		"slot_index": slot_index,
		"item_id": item_id,
		"amount": amount,
	})
	_mark_inventory_changed()


func _record_item_removed(slot_index: int, item_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_pending_item_removed_events.append({
		"slot_index": slot_index,
		"item_id": item_id,
		"amount": amount,
	})
	_mark_inventory_changed()


func _flush_inventory_events() -> void:
	if (
		not _inventory_changed_pending
		and _pending_slot_change_order.is_empty()
		and _pending_item_added_events.is_empty()
		and _pending_item_removed_events.is_empty()
	):
		return

	var item_added_events: Array = _pending_item_added_events.duplicate(true)
	var item_removed_events: Array = _pending_item_removed_events.duplicate(true)
	var slot_order: Array[int] = []
	for slot_index: int in _pending_slot_change_order:
		slot_order.append(slot_index)
	var slot_changes: Dictionary = _pending_slot_changes.duplicate(true)
	var should_emit_inventory_changed: bool = _inventory_changed_pending

	_pending_item_added_events.clear()
	_pending_item_removed_events.clear()
	_pending_slot_change_order.clear()
	_pending_slot_changes.clear()
	_inventory_changed_pending = false

	_is_emitting_inventory_events = true
	for event_value: Variant in item_added_events:
		var event: Dictionary = GFVariantData.as_dictionary(event_value)
		item_added.emit(
			GFVariantData.get_option_int(event, "slot_index", -1),
			_get_non_empty_string_name(GFVariantData.get_option_value(event, "item_id", &"")),
			GFVariantData.get_option_int(event, "amount")
		)
	for event_value: Variant in item_removed_events:
		var event: Dictionary = GFVariantData.as_dictionary(event_value)
		item_removed.emit(
			GFVariantData.get_option_int(event, "slot_index", -1),
			_get_non_empty_string_name(GFVariantData.get_option_value(event, "item_id", &"")),
			GFVariantData.get_option_int(event, "amount")
		)
	for slot_index: int in slot_order:
		var change: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(slot_changes, slot_index, {}))
		var before_stack_data: Dictionary = GFVariantData.get_option_dictionary(change, "before")
		var after_stack_data: Dictionary = GFVariantData.get_option_dictionary(change, "after")
		slot_state_changed.emit(slot_index, before_stack_data.duplicate(true), after_stack_data.duplicate(true))
		if _is_empty_stack_data(before_stack_data) and not _is_empty_stack_data(after_stack_data):
			slot_filled.emit(slot_index, after_stack_data.duplicate(true))
		elif not _is_empty_stack_data(before_stack_data) and _is_empty_stack_data(after_stack_data):
			slot_emptied.emit(slot_index, before_stack_data.duplicate(true))
		slot_changed.emit(slot_index)
	if should_emit_inventory_changed:
		inventory_changed.emit()
	_is_emitting_inventory_events = false


func _mark_inventory_changed() -> void:
	_inventory_changed_pending = true


func _snapshot_slots(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(count):
		result.append(_snapshot_slot_data(index))
	return result


func _snapshot_slot_data(slot_index: int) -> Dictionary:
	var stack: GFInventoryStack = _get_stack_ref(slot_index)
	if stack == null or stack.is_empty():
		return {}
	return stack.to_dict()


func _is_empty_stack_data(stack_data: Dictionary) -> bool:
	return stack_data.is_empty() or GFVariantData.get_option_string(stack_data, "item_id").is_empty() or GFVariantData.get_option_int(stack_data, "amount") <= 0


func _should_sort_entry_before(left: Dictionary, right: Dictionary, order_resolver: Callable) -> bool:
	var left_slot_index: int = GFVariantData.get_option_int(left, "slot_index", -1)
	var right_slot_index: int = GFVariantData.get_option_int(right, "slot_index", -1)
	var left_stack_data: Dictionary = GFVariantData.get_option_dictionary(left, "stack_data")
	var right_stack_data: Dictionary = GFVariantData.get_option_dictionary(right, "stack_data")
	if order_resolver.is_valid():
		var result: Variant = order_resolver.call(
			left_slot_index,
			left_stack_data.duplicate(true),
			right_slot_index,
			right_stack_data.duplicate(true)
		)
		if typeof(result) == TYPE_BOOL:
			return GFVariantData.to_bool(result)
	return _should_sort_slot_before(left_slot_index, left_stack_data, right_slot_index, right_stack_data)


func _get_item_totals() -> Dictionary:
	var totals: Dictionary = {}
	for stack_variant: Variant in _slots:
		var stack: GFInventoryStack = _get_inventory_stack_value(stack_variant)
		if stack == null:
			continue
		var key: String = String(stack.item_id)
		totals[key] = GFVariantData.get_option_int(totals, key) + stack.amount
	return totals


func _mark_index_dirty() -> void:
	_index_dirty = true


func _rebuild_index_if_needed() -> void:
	if _index_dirty:
		rebuild_index()


func _make_validation_report() -> Dictionary:
	return {
		"ok": true,
		"error_count": 0,
		"warning_count": 0,
		"issues": [],
	}


func _add_validation_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	slot_index: int,
	item_id: StringName,
	message: String
) -> void:
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues", []))
	issues.append({
		"severity": severity,
		"kind": kind,
		"slot_index": slot_index,
		"item_id": item_id,
		"message": message,
	})
	report["issues"] = issues
	if severity == "warning":
		report["warning_count"] = GFVariantData.get_option_int(report, "warning_count") + 1
	else:
		report["error_count"] = GFVariantData.get_option_int(report, "error_count") + 1
		report["ok"] = false


func _finalize_validation_report(report: Dictionary) -> void:
	report["ok"] = GFVariantData.get_option_int(report, "error_count") == 0
