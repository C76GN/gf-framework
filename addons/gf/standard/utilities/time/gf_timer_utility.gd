## GFTimerUtility: 纯代码驱动的全局定时器工具。
## 通过框架 `tick()` 驱动延时回调，不依赖场景树中的 `Timer` 节点，
## 因而可直接受到 `GFTimeUtility` 的时间缩放与暂停控制。适用于在
## `GFSystem`、`GFModel` 或其他纯逻辑模块中调度一次性、重复或 owner 绑定任务。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTimerUtility
extends GFUtility


# --- 常量 ---

const _MAX_CATCH_UP_EXECUTIONS: int = 1024


# --- 私有变量 ---

# 待执行的延时任务列表。每项包含 `id`、`remaining`、`interval`、`repeat_count` 与 `callback` 字段。
var _pending_timers: Array[Dictionary] = []
var _next_timer_id: int = 1
var _executing_handles: Dictionary = {}
var _cancelled_handles: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化定时器队列。
## [br]
## @api public
func init() -> void:
	_pending_timers.clear()
	_next_timer_id = 1
	_executing_handles.clear()
	_cancelled_handles.clear()


## 清空定时器队列。
## [br]
## @api public
func dispose() -> void:
	_pending_timers.clear()
	_next_timer_id = 1
	_executing_handles.clear()
	_cancelled_handles.clear()


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if _pending_timers.is_empty() or delta <= 0.0:
		return

	var ready_timers: Array[Dictionary] = []

	for index: int in range(_pending_timers.size() - 1, -1, -1):
		var timer_data: Dictionary = _pending_timers[index]
		if _timer_owner_is_released(timer_data):
			_pending_timers.remove_at(index)
			continue

		var remaining: float = _get_timer_remaining(timer_data) - delta
		timer_data["remaining"] = remaining
		_pending_timers[index] = timer_data

		if remaining <= 0.0:
			timer_data["overshoot"] = -remaining
			ready_timers.append(timer_data)
			_pending_timers.remove_at(index)

	ready_timers.reverse()
	for timer_data: Dictionary in ready_timers:
		_execute_ready_timer(timer_data)


# --- 公共方法 ---

## 在指定延迟后执行一次回调函数。
## 基于框架 `tick()` 推进计时，因此会自动遵循 `GFTimeUtility` 的暂停与缩放结果。
## [br]
## @api public
## [br]
## @param delay: 延迟时长，单位为秒。
## [br]
## @param callback: 延迟结束后执行的无参回调函数。
## [br]
## @return 已排队定时器的句柄；无效回调或立即执行时返回 `0`。
func execute_after(delay: float, callback: Callable) -> int:
	if not callback.is_valid():
		push_error("[GFTimerUtility] execute_after 失败：传入的 callback 无效。")
		return 0

	if delay <= 0.0:
		var _result: Variant = callback.call()
		return 0

	return _queue_timer(delay, callback, 0.0, 1, null)


## 在指定延迟后执行一次 owner 绑定回调。owner 释放后任务会自动丢弃。
## [br]
## @api public
## [br]
## @param owner: 定时器拥有者。
## [br]
## @param delay: 延迟时长，单位为秒。
## [br]
## @param callback: 延迟结束后执行的无参回调函数。
## [br]
## @return 已排队定时器的句柄；无效输入或立即执行时返回 `0`。
func execute_after_owned(owner: Object, delay: float, callback: Callable) -> int:
	if owner == null:
		push_error("[GFTimerUtility] execute_after_owned 失败：owner 为空。")
		return 0
	if not callback.is_valid():
		push_error("[GFTimerUtility] execute_after_owned 失败：传入的 callback 无效。")
		return 0

	if delay <= 0.0:
		var _result: Variant = callback.call()
		return 0

	return _queue_timer(delay, callback, 0.0, 1, owner)


## 按固定间隔重复执行回调。
## [br]
## @api public
## [br]
## @param interval: 重复间隔，单位为秒。
## [br]
## @param callback: 每次触发时执行的无参回调函数。
## [br]
## @param repeat_count: 触发次数；小于 0 表示无限重复。
## [br]
## @param initial_delay: 首次触发延迟；小于 0 时使用 interval。
## [br]
## @return 已排队定时器的句柄；无效输入时返回 `0`。
func execute_repeating(
	interval: float,
	callback: Callable,
	repeat_count: int = -1,
	initial_delay: float = -1.0
) -> int:
	if not callback.is_valid():
		push_error("[GFTimerUtility] execute_repeating 失败：传入的 callback 无效。")
		return 0
	if interval <= 0.0:
		push_error("[GFTimerUtility] execute_repeating 失败：interval 必须大于 0。")
		return 0
	if repeat_count == 0:
		return 0

	var delay: float = initial_delay if initial_delay >= 0.0 else interval
	return _queue_timer(delay, callback, interval, repeat_count, null)


## 按固定间隔重复执行 owner 绑定回调。owner 释放后任务会自动丢弃。
## [br]
## @api public
## [br]
## @param owner: 定时器拥有者。
## [br]
## @param interval: 重复间隔，单位为秒。
## [br]
## @param callback: 每次触发时执行的无参回调函数。
## [br]
## @param repeat_count: 触发次数；小于 0 表示无限重复。
## [br]
## @param initial_delay: 首次触发延迟；小于 0 时使用 interval。
## [br]
## @return 已排队定时器的句柄；无效输入时返回 `0`。
func execute_repeating_owned(
	owner: Object,
	interval: float,
	callback: Callable,
	repeat_count: int = -1,
	initial_delay: float = -1.0
) -> int:
	if owner == null:
		push_error("[GFTimerUtility] execute_repeating_owned 失败：owner 为空。")
		return 0
	if not callback.is_valid():
		push_error("[GFTimerUtility] execute_repeating_owned 失败：传入的 callback 无效。")
		return 0
	if interval <= 0.0:
		push_error("[GFTimerUtility] execute_repeating_owned 失败：interval 必须大于 0。")
		return 0
	if repeat_count == 0:
		return 0

	var delay: float = initial_delay if initial_delay >= 0.0 else interval
	return _queue_timer(delay, callback, interval, repeat_count, owner)


## 取消一个尚未触发的延时任务。
## [br]
## @api public
## [br]
## @param handle: `execute_after()` 返回的定时器句柄。
## [br]
## @return 找到并取消任务时返回 `true`。
func cancel(handle: int) -> bool:
	if handle <= 0:
		return false

	for index: int in range(_pending_timers.size() - 1, -1, -1):
		if _get_timer_id(_pending_timers[index]) == handle:
			_pending_timers.remove_at(index)
			return true
	if _executing_handles.has(handle):
		_cancelled_handles[handle] = true
		return true
	return false


## 取消指定 owner 绑定的全部待执行任务。
## [br]
## @api public
## [br]
## @param owner: 定时器拥有者。
## [br]
## @return 被取消的任务数量。
func cancel_owner(owner: Object) -> int:
	if owner == null:
		return 0

	var owner_id: int = owner.get_instance_id()
	var removed: int = 0
	for index: int in range(_pending_timers.size() - 1, -1, -1):
		var timer_data: Dictionary = _pending_timers[index]
		if _get_timer_owner_id(timer_data) == owner_id:
			_pending_timers.remove_at(index)
			removed += 1
	return removed


## 获取定时器工具诊断快照。
## [br]
## @api public
## [br]
## @return 诊断快照字典。
## [br]
## @schema return: Dictionary with `pending_count`, `pending_handles`, `owner_bound_count`, `executing_count`, and `next_timer_id`.
func get_debug_snapshot() -> Dictionary:
	var handles: PackedInt32Array = PackedInt32Array()
	var owner_bound_count: int = 0
	for timer_data: Dictionary in _pending_timers:
		var _appended: bool = handles.append(_get_timer_id(timer_data))
		if _timer_has_owner_ref(timer_data):
			owner_bound_count += 1

	return {
		"pending_count": _pending_timers.size(),
		"pending_handles": handles,
		"owner_bound_count": owner_bound_count,
		"executing_count": _executing_handles.size(),
		"next_timer_id": _next_timer_id,
	}


# --- 私有/辅助方法 ---

func _queue_timer(
	delay: float,
	callback: Callable,
	interval: float,
	repeat_count: int,
	owner: Object
) -> int:
	var handle: int = _next_timer_id
	_next_timer_id += 1
	_pending_timers.append({
		"id": handle,
		"remaining": maxf(delay, 0.0),
		"interval": maxf(interval, 0.0),
		"repeat_count": repeat_count,
		"callback": callback,
		"owner_ref": weakref(owner) if owner != null else null,
		"owner_id": owner.get_instance_id() if owner != null else 0,
	})
	return handle


func _execute_ready_timer(timer_data: Dictionary) -> void:
	var handle: int = _get_timer_id(timer_data)
	var overshoot: float = maxf(GFVariantData.get_option_float(timer_data, "overshoot", 0.0), 0.0)
	var catch_up_count: int = 0
	while true:
		if _cancelled_handles.has(handle) or _timer_owner_is_released(timer_data):
			var _removed_cancelled_before: bool = _cancelled_handles.erase(handle)
			return

		var callback: Callable = _get_timer_callback(timer_data)
		if not callback.is_valid():
			return

		_executing_handles[handle] = true
		var _result: Variant = callback.call()
		var _removed_executing: bool = _executing_handles.erase(handle)

		if _cancelled_handles.has(handle):
			var _removed_cancelled_after: bool = _cancelled_handles.erase(handle)
			return
		if _timer_owner_is_released(timer_data):
			return

		var interval: float = _get_timer_interval(timer_data)
		if interval <= 0.0:
			return

		var repeat_count: int = _get_timer_repeat_count(timer_data)
		if repeat_count > 0:
			repeat_count -= 1
			if repeat_count <= 0:
				return
			timer_data["repeat_count"] = repeat_count

		catch_up_count += 1
		if catch_up_count >= _MAX_CATCH_UP_EXECUTIONS or overshoot < interval:
			timer_data["remaining"] = interval - overshoot if overshoot < interval else interval
			timer_data["overshoot"] = 0.0
			_pending_timers.append(timer_data)
			return
		overshoot -= interval


func _timer_owner_is_released(timer_data: Dictionary) -> bool:
	if not _timer_has_owner_ref(timer_data):
		return false
	var owner_ref: WeakRef = _get_timer_owner_ref(timer_data)
	return owner_ref == null or owner_ref.get_ref() == null


func _get_timer_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "id", 0)


func _get_timer_remaining(timer_data: Dictionary) -> float:
	return GFVariantData.get_option_float(timer_data, "remaining", 0.0)


func _get_timer_interval(timer_data: Dictionary) -> float:
	return GFVariantData.get_option_float(timer_data, "interval", 0.0)


func _get_timer_repeat_count(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "repeat_count", 0)


func _get_timer_owner_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "owner_id", 0)


func _get_timer_callback(timer_data: Dictionary) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(timer_data, "callback", Callable()))


func _get_timer_owner_ref(timer_data: Dictionary) -> WeakRef:
	return _variant_to_weak_ref(GFVariantData.get_option_value(timer_data, "owner_ref"))


func _timer_has_owner_ref(timer_data: Dictionary) -> bool:
	return GFVariantData.get_option_value(timer_data, "owner_ref") != null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var owner_ref: WeakRef = value
		return owner_ref
	return null
