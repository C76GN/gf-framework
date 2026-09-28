## GFManualTimerQueue: 手动 tick 驱动的确定性计时队列。
##
## 用整数 tick 调度一次性回调，适合回放、模拟、服务器步进、测试或编辑器批处理。
## 队列不读取引擎时间，也不创建 Timer 节点；调用方显式调用 advance_to() 或 advance_by() 推进时间。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFManualTimerQueue
extends RefCounted


# --- 公共变量 ---

## 单次 advance 最多执行多少个回调，避免同 tick 回调递归排队导致无限循环。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_callbacks_per_advance: int = 1024:
	set(value):
		max_callbacks_per_advance = maxi(value, 1)


# --- 私有变量 ---

## 当前手动 tick；推进时会暂时更新为正在执行的任务 tick。
## [br]
## @api private
var _current_tick: int = 0

## 按目标 tick 和排序序号排列的待执行计时器条目。
## [br]
## @api private
var _timers: Array[Dictionary] = []

## 下一个正数计时器句柄；clear() 后从 1 重新开始。
## [br]
## @api private
var _next_timer_id: int = 1

## 普通计时器使用的递增同 tick 排序序号。
## [br]
## @api private
var _next_order: int = 0

## front 计时器使用的递减排序序号，使后加入的 front 项排在先加入项之前。
## [br]
## @api private
var _next_front_order: int = 0

## 自队列清空以来成功执行的回调数。
## [br]
## @api private
var _executed_count: int = 0

## 自队列清空以来通过句柄或 owner 取消的计时器数。
## [br]
## @api private
var _cancelled_count: int = 0

## 自队列清空以来因 owner 已释放而跳过的计时器数。
## [br]
## @api private
var _skipped_owner_count: int = 0

## 自队列清空以来无效或返回失败结果的回调数。
## [br]
## @api private
var _failed_count: int = 0

## 阻止回调在当前 advance 尚未结束时嵌套推进同一队列。
## [br]
## @api private
var _advance_in_progress: bool = false

## 在 clear() 时递增，用于检测回调是否清空了正在推进的队列。
## [br]
## @api private
var _lifecycle_generation: int = 0


# --- 公共方法 ---

## 在绝对 tick 上调度回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target_tick: 目标 tick；小于当前 tick 时会归一到当前 tick。
## [br]
## @param callback: 到期后执行的回调。
## [br]
## @param options: 调度选项，支持 owner、metadata、label 和 front。
## [br]
## @schema options: Dictionary，可包含 owner: Object、metadata: Dictionary、label: String、front: bool。
## [br]
## @return 计时器句柄；callback 无效时返回 0。
func schedule_at(target_tick: int, callback: Callable, options: Dictionary = {}) -> int:
	if not callback.is_valid():
		push_error("[GFManualTimerQueue][manual_timer_queue.callback_invalid] Cannot schedule_at: callback is invalid.")
		return 0

	var owner: Object = _variant_to_object(GFVariantData.get_option_value(options, "owner"))
	return _queue_timer(maxi(target_tick, _current_tick), callback, owner, options)


## 在当前 tick 之后延迟若干 tick 调度回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param delay_ticks: 延迟 tick 数；小于 0 时按 0 处理。
## [br]
## @param callback: 到期后执行的回调。
## [br]
## @param options: 调度选项，支持 owner、metadata、label 和 front。
## [br]
## @schema options: Dictionary，可包含 owner: Object、metadata: Dictionary、label: String、front: bool。
## [br]
## @return 计时器句柄；callback 无效时返回 0。
func schedule_after(delay_ticks: int, callback: Callable, options: Dictionary = {}) -> int:
	return schedule_at(_current_tick + maxi(delay_ticks, 0), callback, options)


## 在绝对 tick 上调度 owner 绑定回调。owner 释放后回调会被跳过。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 计时器拥有者。
## [br]
## @param target_tick: 目标 tick；小于当前 tick 时会归一到当前 tick。
## [br]
## @param callback: 到期后执行的回调。
## [br]
## @param options: 调度选项，支持 metadata、label 和 front。
## [br]
## @schema options: Dictionary，可包含 metadata: Dictionary、label: String、front: bool。
## [br]
## @return 计时器句柄；参数无效时返回 0。
func schedule_at_owned(owner: Object, target_tick: int, callback: Callable, options: Dictionary = {}) -> int:
	if owner == null:
		push_error("[GFManualTimerQueue][manual_timer_queue.owner_null] Cannot schedule_at_owned: owner is null.")
		return 0
	var safe_options: Dictionary = options.duplicate(true)
	safe_options["owner"] = owner
	return schedule_at(target_tick, callback, safe_options)


## 推进到指定绝对 tick，并执行所有到期回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target_tick: 目标 tick，不能小于当前 tick。
## [br]
## @param options: 推进选项，支持 max_callbacks。
## [br]
## 同一队列的 callback 内再次推进会返回 status=advance_in_progress，不执行嵌套 drain。
## [br]
## @schema options: Dictionary，可包含 max_callbacks: int。
## [br]
## @return 推进报告。
## [br]
## @schema return: Dictionary，包含 ok、status、from_tick、target_tick、current_tick、executed_count、failed_count、skipped_owner_count、truncated 和 pending_count。
func advance_to(target_tick: int, options: Dictionary = {}) -> Dictionary:
	if _advance_in_progress:
		return _make_advance_report(
			false,
			&"advance_in_progress",
			_current_tick,
			target_tick,
			0,
			0,
			0,
			false
		)
	if target_tick < _current_tick:
		return _make_advance_report(false, &"backward_tick", _current_tick, target_tick, 0, 0, 0, false)

	var from_tick: int = _current_tick
	var lifecycle_generation: int = _lifecycle_generation
	var max_callbacks: int = GFVariantData.get_option_int(options, "max_callbacks", max_callbacks_per_advance)
	var limit: int = maxi(max_callbacks, 1)
	var executed_now: int = 0
	var failed_now: int = 0
	var skipped_owner_now: int = 0
	var truncated: bool = false
	_advance_in_progress = true

	while true:
		if executed_now + failed_now + skipped_owner_now >= limit and _has_due_timer(target_tick):
			truncated = true
			break

		var timer_data: Dictionary = _pop_next_due_timer(target_tick)
		if timer_data.is_empty():
			break

		_current_tick = GFVariantData.get_option_int(timer_data, "target_tick", _current_tick)
		if _timer_owner_is_released(timer_data):
			skipped_owner_now += 1
			_skipped_owner_count += 1
			continue

		var callback: Callable = _get_timer_callback(timer_data)
		if not callback.is_valid():
			failed_now += 1
			_failed_count += 1
			continue

		var result: Variant = callback.call()
		if lifecycle_generation != _lifecycle_generation:
			_advance_in_progress = false
			return _make_advance_report(
				false,
				&"cleared_during_advance",
				from_tick,
				target_tick,
				executed_now,
				failed_now,
				skipped_owner_now,
				false
			)
		if _callback_result_is_failure(result):
			failed_now += 1
			_failed_count += 1
		else:
			executed_now += 1
			_executed_count += 1

	if not truncated:
		_current_tick = target_tick

	_advance_in_progress = false
	return _make_advance_report(true, &"advanced", from_tick, target_tick, executed_now, failed_now, skipped_owner_now, truncated)


## 按相对 tick 推进队列。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param delta_ticks: 推进 tick 数；小于 0 时返回错误报告。
## [br]
## @param options: 推进选项，支持 max_callbacks。
## [br]
## @schema options: Dictionary，可包含 max_callbacks: int。
## [br]
## @return 推进报告。
## [br]
## @schema return: Dictionary，结构同 advance_to()。
func advance_by(delta_ticks: int, options: Dictionary = {}) -> Dictionary:
	if delta_ticks < 0:
		return _make_advance_report(false, &"negative_delta", _current_tick, _current_tick + delta_ticks, 0, 0, 0, false)
	return advance_to(_current_tick + delta_ticks, options)


## 取消一个尚未执行的计时器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: schedule_at() 返回的计时器句柄。
## [br]
## @return 找到并取消时返回 true。
func cancel(handle: int) -> bool:
	if handle <= 0:
		return false
	for index: int in range(_timers.size()):
		if _get_timer_id(_timers[index]) == handle:
			_timers.remove_at(index)
			_cancelled_count += 1
			return true
	return false


## 取消指定 owner 绑定的全部待执行计时器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 计时器拥有者。
## [br]
## @return 取消数量。
func cancel_owner(owner: Object) -> int:
	if owner == null:
		return 0
	var owner_id: int = owner.get_instance_id()
	var removed_count: int = 0
	for index: int in range(_timers.size() - 1, -1, -1):
		if _get_timer_owner_id(_timers[index]) == owner_id:
			_timers.remove_at(index)
			removed_count += 1
	_cancelled_count += removed_count
	return removed_count


## 清空队列和统计。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_lifecycle_generation += 1
	_current_tick = 0
	_timers.clear()
	_next_timer_id = 1
	_next_order = 0
	_next_front_order = 0
	_executed_count = 0
	_cancelled_count = 0
	_skipped_owner_count = 0
	_failed_count = 0


## 获取当前 tick。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前 tick。
func get_current_tick() -> int:
	return _current_tick


## 获取待执行计时器数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 待执行数量。
func get_pending_count() -> int:
	return _timers.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 current_tick、pending_count、next_due_tick、pending_handles、executed_count、cancelled_count、failed_count 和 skipped_owner_count。
func get_debug_snapshot() -> Dictionary:
	var handles: PackedInt32Array = PackedInt32Array()
	var next_due_tick: int = -1
	for timer_data: Dictionary in _timers:
		var _handle_appended: bool = handles.append(_get_timer_id(timer_data))
		var target_tick: int = _get_timer_target_tick(timer_data)
		if next_due_tick < 0 or target_tick < next_due_tick:
			next_due_tick = target_tick
	return {
		"current_tick": _current_tick,
		"pending_count": _timers.size(),
		"next_due_tick": next_due_tick,
		"pending_handles": handles,
		"executed_count": _executed_count,
		"cancelled_count": _cancelled_count,
		"failed_count": _failed_count,
		"skipped_owner_count": _skipped_owner_count,
	}


# --- 私有/辅助方法 ---

## 生成计时器条目、分配句柄与顺序号，并插入已排序队列。
## [br]
## @api private
func _queue_timer(target_tick: int, callback: Callable, owner: Object, options: Dictionary) -> int:
	var handle: int = _next_timer_id
	_next_timer_id += 1
	var timer_data: Dictionary = {
		"id": handle,
		"target_tick": target_tick,
		"order": _make_order(GFVariantData.get_option_bool(options, "front", false)),
		"callback": callback,
		"owner_ref": weakref(owner) if owner != null else null,
		"owner_id": owner.get_instance_id() if owner != null else 0,
		"label": GFVariantData.get_option_string(options, "label"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	_insert_timer_sorted(timer_data)
	return handle


## 为普通计时器分配递增序号，为 front 计时器分配递减序号。
## [br]
## @api private
func _make_order(front: bool) -> int:
	if front:
		_next_front_order -= 1
		return _next_front_order
	var order: int = _next_order
	_next_order += 1
	return order


## 检查按 tick 排序后的队首是否不晚于目标 tick。
## [br]
## @api private
func _has_due_timer(target_tick: int) -> bool:
	if _timers.is_empty():
		return false
	return _get_timer_target_tick(_timers[0]) <= target_tick


## 仅在队首计时器已到期时将其从队列移除并返回。
## [br]
## @api private
func _pop_next_due_timer(target_tick: int) -> Dictionary:
	if _timers.is_empty():
		return {}
	if _get_timer_target_tick(_timers[0]) > target_tick:
		return {}
	return _timers.pop_front()


## 用二分查找按 `_timer_is_before()` 的顺序插入新计时器。
## [br]
## @api private
func _insert_timer_sorted(timer_data: Dictionary) -> void:
	var low: int = 0
	var high: int = _timers.size()
	while low < high:
		var middle: int = floori(float(low + high) / 2.0)
		if _timer_is_before(timer_data, _timers[middle]):
			high = middle
		else:
			low = middle + 1
	var _insert_result: Variant = _timers.insert(low, timer_data)


## 先按目标 tick 排序，再按序号确定同 tick 的先后顺序。
## [br]
## @api private
func _timer_is_before(left: Dictionary, right: Dictionary) -> bool:
	var left_tick: int = _get_timer_target_tick(left)
	var right_tick: int = _get_timer_target_tick(right)
	if left_tick != right_tick:
		return left_tick < right_tick
	return GFVariantData.get_option_int(left, "order") < GFVariantData.get_option_int(right, "order")


## 判断条目记录的弱引用 owner 是否已失效；无 owner 的条目不会被跳过。
## [br]
## @api private
func _timer_owner_is_released(timer_data: Dictionary) -> bool:
	var owner_ref: WeakRef = _get_timer_owner_ref(timer_data)
	return owner_ref != null and owner_ref.get_ref() == null


## 将 false 或 `ok` 为 false 的 Dictionary 识别为回调失败，其余结果视为成功。
## [br]
## @api private
func _callback_result_is_failure(result: Variant) -> bool:
	if result is bool:
		var bool_result: bool = result
		return not bool_result
	if result is Dictionary:
		var dictionary_result: Dictionary = result
		return not GFVariantData.get_option_bool(dictionary_result, "ok", true)
	return false


## 统一组装推进结果，并从当前队列读取 current_tick 与待执行数量。
## [br]
## @api private
func _make_advance_report(
	ok: bool,
	status: StringName,
	from_tick: int,
	target_tick: int,
	executed_now: int,
	failed_now: int,
	skipped_owner_now: int,
	truncated: bool
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"from_tick": from_tick,
		"target_tick": target_tick,
		"current_tick": _current_tick,
		"executed_count": executed_now,
		"failed_count": failed_now,
		"skipped_owner_count": skipped_owner_now,
		"truncated": truncated,
		"pending_count": _timers.size(),
	}


## 从计时器条目读取句柄编号。
## [br]
## @api private
func _get_timer_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "id")


## 从计时器条目读取绝对目标 tick。
## [br]
## @api private
func _get_timer_target_tick(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "target_tick")


## 从计时器条目读取 owner 的实例编号。
## [br]
## @api private
func _get_timer_owner_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "owner_id")


## 读取回调字段并确认其为 Callable，否则返回无效 Callable。
## [br]
## @api private
func _get_timer_callback(timer_data: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(timer_data, "callback", Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 读取 owner 弱引用字段并确认其为 WeakRef，否则返回 null。
## [br]
## @api private
func _get_timer_owner_ref(timer_data: Dictionary) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(timer_data, "owner_ref")
	if value is WeakRef:
		var owner_ref: WeakRef = value
		return owner_ref
	return null


## 将对象 Variant 收窄为 Object；其他值返回 null。
## [br]
## @api private
func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null
