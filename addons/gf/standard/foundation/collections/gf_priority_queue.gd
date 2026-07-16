## GFPriorityQueue: 稳定优先队列。
##
## 用二叉堆保存带数值优先级的值，支持高优先级优先或低优先级优先，
## 并在相同优先级下保持稳定顺序。它只管理排序和弹出顺序，不解释任务、
## 通知、AI 行为或项目业务语义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 7.0.0
class_name GFPriorityQueue
extends RefCounted


# --- 公共变量 ---

## 是否优先弹出较大的 priority。设为 false 时较小的 priority 优先。
## [br]
## @api public
## [br]
## @since 7.0.0
var high_priority_first: bool = true:
	set(value):
		high_priority_first = value
		_heapify()


# --- 私有变量 ---

var _entries: Array[Dictionary] = []
var _next_order: int = 0
var _next_front_order: int = 0


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_high_priority_first: 为 true 时 priority 数值越大越先弹出。
func _init(p_high_priority_first: bool = true) -> void:
	high_priority_first = p_high_priority_first


# --- 公共方法 ---

## 从值数组创建优先队列。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param values: 初始值数组。
## [br]
## @param priority: 所有初始值使用的优先级。
## [br]
## @param p_high_priority_first: 为 true 时 priority 数值越大越先弹出。
## [br]
## @return 新优先队列。
## [br]
## @schema values: Array of queue values copied by reference.
static func from_array(
	values: Array,
	priority: float = 0.0,
	p_high_priority_first: bool = true
) -> RefCounted:
	var priority_queue: RefCounted = _new_queue_instance(p_high_priority_first)
	if priority_queue == null:
		return null
	for value: Variant in values:
		var _push_result: Variant = priority_queue.call("push", value, priority)
	return priority_queue


## 推入一个值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要入队的值。
## [br]
## @param priority: 数值优先级。
## [br]
## @param front: 为 true 时会排在相同 priority 的既有元素之前。
## [br]
## @return priority 有限并成功入队时返回 true。
## [br]
## @schema value: Variant queue value.
func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:
	if not is_finite(priority):
		return false
	_reset_order_if_empty()
	var order: int = _make_order(front)
	_push_entry(value, priority, order)
	return true


## 按显式稳定顺序推入一个值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 要入队的值。
## [br]
## @param priority: 数值优先级。
## [br]
## @param order: 相同 priority 下的稳定排序值，数值越小越先弹出。
## [br]
## @return priority 有限并成功入队时返回 true。
## [br]
## @schema value: Variant queue value.
func push_with_order(value: Variant, priority: float = 0.0, order: int = 0) -> bool:
	if not is_finite(priority):
		return false
	_reset_order_if_empty()
	_push_entry(value, priority, order)
	return true


## 弹出当前最高优先级值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param default_value: 队列为空时返回的值。
## [br]
## @return 队列值或 default_value。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func pop(default_value: Variant = null) -> Variant:
	if _entries.is_empty():
		return default_value
	var entry: Dictionary = _pop_entry_from(_entries)
	_reset_order_if_empty()
	return GFVariantData.get_option_value(entry, "value", default_value)


## 读取当前最高优先级值但不移除。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param default_value: 队列为空时返回的值。
## [br]
## @return 队列值或 default_value。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func peek(default_value: Variant = null) -> Variant:
	if _entries.is_empty():
		return default_value
	return GFVariantData.get_option_value(_entries[0], "value", default_value)


## 读取当前最高优先级。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param default_value: 队列为空时返回的值。
## [br]
## @return 当前最高优先级或 default_value。
func peek_priority(default_value: float = 0.0) -> float:
	if _entries.is_empty():
		return default_value
	return GFVariantData.get_option_float(_entries[0], "priority", default_value)


## 移除第一个等于 value 的队列值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要移除的值。
## [br]
## @return 找到并移除时返回 true。
## [br]
## @schema value: Variant queue value.
func remove_value(value: Variant) -> bool:
	for index: int in range(_entries.size()):
		if _values_equal(GFVariantData.get_option_value(_entries[index], "value"), value):
			_remove_entry_at(index)
			_reset_order_if_empty()
			return true
	return false


## 移除所有等于 value 的队列值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要移除的值。
## [br]
## @return 移除数量。
## [br]
## @schema value: Variant queue value.
func remove_all(value: Variant) -> int:
	var removed_count: int = 0
	for index: int in range(_entries.size() - 1, -1, -1):
		if _values_equal(GFVariantData.get_option_value(_entries[index], "value"), value):
			_entries.remove_at(index)
			removed_count += 1
	if removed_count > 0:
		_heapify()
		_reset_order_if_empty()
	return removed_count


## 检查队列是否包含指定值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要查找的值。
## [br]
## @return 包含时返回 true。
## [br]
## @schema value: Variant queue value.
func has_value(value: Variant) -> bool:
	for entry: Dictionary in _entries:
		if _values_equal(GFVariantData.get_option_value(entry, "value"), value):
			return true
	return false


## 更新第一个等于 value 的队列值优先级。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要更新的值。
## [br]
## @param priority: 新优先级。
## [br]
## @param front: 为 true 时排到相同 priority 的既有元素之前。
## [br]
## @return 找到并更新时返回 true。
## [br]
## @schema value: Variant queue value.
func set_priority(value: Variant, priority: float, front: bool = false) -> bool:
	if not is_finite(priority):
		return false
	for index: int in range(_entries.size()):
		if _values_equal(GFVariantData.get_option_value(_entries[index], "value"), value):
			_entries[index]["priority"] = priority
			if front:
				_entries[index]["order"] = _make_order(true)
			_heapify()
			return true
	return false


## 清空队列。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_entries.clear()
	_next_order = 0
	_next_front_order = 0


## 队列是否为空。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 为空返回 true。
func is_empty() -> bool:
	return _entries.is_empty()


## 获取元素数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 元素数量。
func size() -> int:
	return _entries.size()


## 按弹出顺序导出值数组，不修改当前队列。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param deep: 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。
## [br]
## @return 队列值数组。
## [br]
## @schema return: Array of queue values in pop order.
func to_array(deep: bool = false) -> Array:
	var result: Array = []
	var entries: Array[Dictionary] = _duplicate_entries(false)
	while not entries.is_empty():
		var entry: Dictionary = _pop_entry_from(entries)
		var value: Variant = GFVariantData.get_option_value(entry, "value")
		result.append(GFVariantData.duplicate_variant(value) if deep else value)
	return result


## 按弹出顺序导出队列条目，不修改当前队列。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param deep: 为 true 时深拷贝条目中的 value。
## [br]
## @return 条目数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 value、priority 和 order。
func to_entry_array(deep: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries: Array[Dictionary] = _duplicate_entries(false)
	while not entries.is_empty():
		var entry: Dictionary = _pop_entry_from(entries)
		var value: Variant = GFVariantData.get_option_value(entry, "value")
		result.append({
			"value": GFVariantData.duplicate_variant(value) if deep else value,
			"priority": GFVariantData.get_option_float(entry, "priority"),
			"order": GFVariantData.get_option_int(entry, "order"),
		})
	return result


## 复制优先队列。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param deep: 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。
## [br]
## @return 新优先队列；实际对象类型为 GFPriorityQueue。
## [br]
## @schema return: RefCounted GFPriorityQueue instance.
func duplicate_priority_queue(deep: bool = false) -> RefCounted:
	var priority_queue: RefCounted = _new_queue_instance(high_priority_first)
	if priority_queue == null:
		return null
	priority_queue.set("_entries", _duplicate_entries(deep))
	priority_queue.set("_next_order", _next_order)
	priority_queue.set("_next_front_order", _next_front_order)
	return priority_queue


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary with size, high_priority_first, and entries.
func get_debug_snapshot() -> Dictionary:
	return {
		"size": size(),
		"high_priority_first": high_priority_first,
		"entries": to_entry_array(false),
	}


# --- 私有/辅助方法 ---

func _make_order(front: bool) -> int:
	if front:
		_next_front_order -= 1
		return _next_front_order
	var order: int = _next_order
	_next_order += 1
	return order


func _push_entry(value: Variant, priority: float, order: int) -> void:
	_entries.append({
		"value": value,
		"priority": priority,
		"order": order,
	})
	_sift_up(_entries.size() - 1)


func _reset_order_if_empty() -> void:
	if not _entries.is_empty():
		return
	_next_order = 0
	_next_front_order = 0


func _heapify() -> void:
	var start_index: int = floori(float(_entries.size()) / 2.0) - 1
	for index: int in range(start_index, -1, -1):
		_sift_down(index)


func _sift_up(index: int) -> void:
	var current_index: int = index
	while current_index > 0:
		var parent_index: int = floori(float(current_index - 1) / 2.0)
		if not _entry_is_before(_entries[current_index], _entries[parent_index]):
			return
		_swap_entries(current_index, parent_index)
		current_index = parent_index


func _sift_down(index: int) -> void:
	var current_index: int = index
	while true:
		var left_index: int = current_index * 2 + 1
		var right_index: int = left_index + 1
		var best_index: int = current_index
		if left_index < _entries.size() and _entry_is_before(_entries[left_index], _entries[best_index]):
			best_index = left_index
		if right_index < _entries.size() and _entry_is_before(_entries[right_index], _entries[best_index]):
			best_index = right_index
		if best_index == current_index:
			return
		_swap_entries(current_index, best_index)
		current_index = best_index


func _remove_entry_at(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var last_index: int = _entries.size() - 1
	if index == last_index:
		_entries.remove_at(last_index)
		return
	_entries[index] = _entries[last_index]
	_entries.remove_at(last_index)
	_sift_down(index)
	_sift_up(index)


func _pop_entry_from(entries: Array[Dictionary]) -> Dictionary:
	if entries.is_empty():
		return {}
	var entry: Dictionary = entries[0]
	var last_index: int = entries.size() - 1
	if last_index == 0:
		entries.remove_at(0)
		return entry
	entries[0] = entries[last_index]
	entries.remove_at(last_index)
	_sift_down_entries(entries, 0)
	return entry


func _sift_down_entries(entries: Array[Dictionary], index: int) -> void:
	var current_index: int = index
	while true:
		var left_index: int = current_index * 2 + 1
		var right_index: int = left_index + 1
		var best_index: int = current_index
		if left_index < entries.size() and _entry_is_before(entries[left_index], entries[best_index]):
			best_index = left_index
		if right_index < entries.size() and _entry_is_before(entries[right_index], entries[best_index]):
			best_index = right_index
		if best_index == current_index:
			return
		var temporary: Dictionary = entries[current_index]
		entries[current_index] = entries[best_index]
		entries[best_index] = temporary
		current_index = best_index


func _entry_is_before(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: float = GFVariantData.get_option_float(left, "priority")
	var right_priority: float = GFVariantData.get_option_float(right, "priority")
	if left_priority != right_priority:
		if high_priority_first:
			return left_priority > right_priority
		return left_priority < right_priority
	return GFVariantData.get_option_int(left, "order") < GFVariantData.get_option_int(right, "order")


func _swap_entries(left_index: int, right_index: int) -> void:
	var temporary: Dictionary = _entries[left_index]
	_entries[left_index] = _entries[right_index]
	_entries[right_index] = temporary


func _duplicate_entries(deep: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var value: Variant = GFVariantData.get_option_value(entry, "value")
		result.append({
			"value": GFVariantData.duplicate_variant(value) if deep else value,
			"priority": GFVariantData.get_option_float(entry, "priority"),
			"order": GFVariantData.get_option_int(entry, "order"),
		})
	return result


func _values_equal(left: Variant, right: Variant) -> bool:
	if left is Object or right is Object:
		return left == right
	return GFVariantData.values_equal(left, right)


static func _new_queue_instance(p_high_priority_first: bool) -> RefCounted:
	var priority_queue: GFPriorityQueue = GFPriorityQueue.new(p_high_priority_first)
	return priority_queue
