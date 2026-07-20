## GFPriorityWorkQueue: 带等待加成的稳定优先级工作队列。
##
## 以基础优先级、入队时间和稳定顺序选择下一个值。等待加成不设上限，
## 因此在新任务优先级有限的前提下，旧低优先级任务最终能够获得执行机会。
## 队列只负责仲裁顺序，不执行任务，也不解释载荷或业务优先级。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFPriorityWorkQueue
extends RefCounted


# --- 公共变量 ---

## 每经过多少毫秒增加一次等待优先级。
## [br]
## @api public
## [br]
## @since 9.0.0
var aging_interval_msec: int = 1000:
	set(value):
		aging_interval_msec = maxi(value, 1)

## 每个等待区间增加的优先级；始终保持为正有限值。
## [br]
## @api public
## [br]
## @since 9.0.0
var aging_step: float = 1.0:
	set(value):
		aging_step = value if is_finite(value) and value > 0.0 else 1.0

## 最大队列长度；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_size: int = 0:
	set(value):
		max_size = maxi(value, 0)


# --- 私有变量 ---

var _entries: Array[Dictionary] = []
var _next_order: int = 0
var _next_front_order: int = 0


# --- 公共方法 ---

## 使用当前单调时钟推入一个值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 工作载荷。
## [br]
## @param priority: 基础优先级，数值越大越先执行。
## [br]
## @param front: 为 true 时排在相同有效优先级的既有值之前。
## [br]
## @return 参数有效且未超过 max_size 时返回 true。
## [br]
## @schema value: Variant，由调用方持有语义的工作载荷。
func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:
	return push_at(value, priority, Time.get_ticks_msec(), front)


## 使用显式入队时间推入一个值，适合确定性模拟、恢复或测试。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 工作载荷。
## [br]
## @param priority: 基础优先级，数值越大越先执行。
## [br]
## @param enqueued_msec: 同一单调时间域中的入队毫秒时间。
## [br]
## @param front: 为 true 时排在相同有效优先级的既有值之前。
## [br]
## @return 参数有效且未超过 max_size 时返回 true。
## [br]
## @schema value: Variant，由调用方持有语义的工作载荷。
func push_at(
	value: Variant,
	priority: float,
	enqueued_msec: int,
	front: bool = false
) -> bool:
	if not is_finite(priority) or enqueued_msec < 0:
		return false
	if max_size > 0 and _entries.size() >= max_size:
		return false
	_reset_order_if_empty()
	_entries.append({
		"value": value,
		"priority": priority,
		"enqueued_msec": enqueued_msec,
		"order": _make_order(front),
	})
	return true


## 使用当前单调时钟弹出有效优先级最高的值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param default_value: 队列为空时的返回值。
## [br]
## @return 下一个工作载荷或 default_value。
## [br]
## @schema default_value: Variant，队列为空时的回退值。
## [br]
## @schema return: Variant，工作载荷或回退值。
func pop(default_value: Variant = null) -> Variant:
	return pop_at(Time.get_ticks_msec(), default_value)


## 使用显式当前时间弹出有效优先级最高的值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 与入队时间相同时间域中的当前毫秒时间。
## [br]
## @param default_value: 队列为空时的返回值。
## [br]
## @return 下一个工作载荷或 default_value。
## [br]
## @schema default_value: Variant，队列为空时的回退值。
## [br]
## @schema return: Variant，工作载荷或回退值。
func pop_at(now_msec: int, default_value: Variant = null) -> Variant:
	var index: int = _find_best_index(now_msec)
	if index < 0:
		return default_value
	var entry: Dictionary = _entries[index]
	_entries.remove_at(index)
	_reset_order_if_empty()
	return GFVariantData.get_option_value(entry, "value", default_value)


## 使用当前单调时钟读取下一个值但不移除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param default_value: 队列为空时的返回值。
## [br]
## @return 下一个工作载荷或 default_value。
## [br]
## @schema default_value: Variant，队列为空时的回退值。
## [br]
## @schema return: Variant，工作载荷或回退值。
func peek(default_value: Variant = null) -> Variant:
	return peek_at(Time.get_ticks_msec(), default_value)


## 使用显式当前时间读取下一个值但不移除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 与入队时间相同时间域中的当前毫秒时间。
## [br]
## @param default_value: 队列为空时的返回值。
## [br]
## @return 下一个工作载荷或 default_value。
## [br]
## @schema default_value: Variant，队列为空时的回退值。
## [br]
## @schema return: Variant，工作载荷或回退值。
func peek_at(now_msec: int, default_value: Variant = null) -> Variant:
	var index: int = _find_best_index(now_msec)
	if index < 0:
		return default_value
	return GFVariantData.get_option_value(_entries[index], "value", default_value)


## 移除第一个等于 value 的等待值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 要移除的工作载荷。
## [br]
## @return 找到并移除时返回 true。
## [br]
## @schema value: Variant，要匹配的工作载荷。
func remove_value(value: Variant) -> bool:
	for index: int in range(_entries.size()):
		if _values_equal(GFVariantData.get_option_value(_entries[index], "value"), value):
			_entries.remove_at(index)
			_reset_order_if_empty()
			return true
	return false


## 更新第一个等于 value 的等待值基础优先级。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param value: 要更新的工作载荷。
## [br]
## @param priority: 新基础优先级。
## [br]
## @return 找到且 priority 有效时返回 true。
## [br]
## @schema value: Variant，要匹配的工作载荷。
func set_priority(value: Variant, priority: float) -> bool:
	if not is_finite(priority):
		return false
	for entry: Dictionary in _entries:
		if _values_equal(GFVariantData.get_option_value(entry, "value"), value):
			entry["priority"] = priority
			return true
	return false


## 清空队列。
## [br]
## @api public
## [br]
## @since 9.0.0
func clear() -> void:
	_entries.clear()
	_next_order = 0
	_next_front_order = 0


## 队列是否为空。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 为空时返回 true。
func is_empty() -> bool:
	return _entries.is_empty()


## 获取等待值数量。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 等待值数量。
func size() -> int:
	return _entries.size()


## 按指定时刻的弹出顺序导出值，不修改队列。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。
## [br]
## @param deep: 为 true 时深拷贝可复制载荷。
## [br]
## @return 工作载荷数组。
## [br]
## @schema return: Array，按有效优先级排列的工作载荷。
func to_array(now_msec: int = -1, deep: bool = false) -> Array:
	var result: Array = []
	for entry: Dictionary in to_entry_array(now_msec, deep):
		result.append(GFVariantData.get_option_value(entry, "value"))
	return result


## 按指定时刻的弹出顺序导出结构化条目，不修改队列。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。
## [br]
## @param deep: 为 true 时深拷贝可复制载荷。
## [br]
## @return 工作条目数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 value、priority、effective_priority、enqueued_msec、waited_msec 和 order。
func to_entry_array(now_msec: int = -1, deep: bool = false) -> Array[Dictionary]:
	var effective_now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var pending: Array[Dictionary] = _duplicate_entries(deep)
	var result: Array[Dictionary] = []
	while not pending.is_empty():
		var index: int = _find_best_index_in(pending, effective_now)
		var entry: Dictionary = pending[index]
		pending.remove_at(index)
		var enqueued_msec: int = GFVariantData.get_option_int(entry, "enqueued_msec")
		var waited_msec: int = maxi(effective_now - enqueued_msec, 0)
		entry["effective_priority"] = _get_effective_priority(entry, effective_now)
		entry["waited_msec"] = waited_msec
		result.append(entry)
	return result


## 获取有界配置与当前排序的调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 size、max_size、aging_interval_msec、aging_step 和 entries。
func get_debug_snapshot(now_msec: int = -1) -> Dictionary:
	return {
		"size": size(),
		"max_size": max_size,
		"aging_interval_msec": aging_interval_msec,
		"aging_step": aging_step,
		"entries": to_entry_array(now_msec, false),
	}


# --- 私有/辅助方法 ---

func _make_order(front: bool) -> int:
	if front:
		_next_front_order -= 1
		return _next_front_order
	var order: int = _next_order
	_next_order += 1
	return order


func _reset_order_if_empty() -> void:
	if not _entries.is_empty():
		return
	_next_order = 0
	_next_front_order = 0


func _find_best_index(now_msec: int) -> int:
	return _find_best_index_in(_entries, maxi(now_msec, 0))


func _find_best_index_in(entries: Array[Dictionary], now_msec: int) -> int:
	if entries.is_empty():
		return -1
	var best_index: int = 0
	for index: int in range(1, entries.size()):
		if _entry_is_before(entries[index], entries[best_index], now_msec):
			best_index = index
	return best_index


func _entry_is_before(left: Dictionary, right: Dictionary, now_msec: int) -> bool:
	var left_priority: float = _get_effective_priority(left, now_msec)
	var right_priority: float = _get_effective_priority(right, now_msec)
	if left_priority != right_priority:
		return left_priority > right_priority
	return GFVariantData.get_option_int(left, "order") < GFVariantData.get_option_int(right, "order")


func _get_effective_priority(entry: Dictionary, now_msec: int) -> float:
	var priority: float = GFVariantData.get_option_float(entry, "priority")
	var enqueued_msec: int = GFVariantData.get_option_int(entry, "enqueued_msec")
	var waited_msec: int = maxi(now_msec - enqueued_msec, 0)
	var aging_intervals: int = floori(float(waited_msec) / float(aging_interval_msec))
	return priority + float(aging_intervals) * aging_step


func _duplicate_entries(deep: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var value: Variant = GFVariantData.get_option_value(entry, "value")
		result.append({
			"value": GFVariantData.duplicate_variant(value) if deep else value,
			"priority": GFVariantData.get_option_float(entry, "priority"),
			"enqueued_msec": GFVariantData.get_option_int(entry, "enqueued_msec"),
			"order": GFVariantData.get_option_int(entry, "order"),
		})
	return result


func _values_equal(left: Variant, right: Variant) -> bool:
	if left is Object or right is Object:
		return left == right
	return GFVariantData.values_equal(left, right)
