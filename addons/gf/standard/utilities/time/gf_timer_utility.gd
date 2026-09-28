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

## 单个到期重复计时器在一次补跑中的最大回调次数。
## [br]
## @api private
const _MAX_CATCH_UP_EXECUTIONS: int = 1024


# --- 私有变量 ---

## 保存尚未到期的任务记录；tick 会更新其剩余时间，到期后移入 ready 队列。
## [br]
## @api private
var _pending_timers: Array[Dictionary] = []

## 保存本次 tick 已到期、尚待按顺序执行的任务，供回调取消同帧后续任务。
## [br]
## @api private
var _ready_timers: Dictionary = {}

## 下一个要分配的正数句柄；init() 和 dispose() 会重置为 1。
## [br]
## @api private
var _next_timer_id: int = 1

## 标记当前正在调用回调的句柄，以支持执行期间取消。
## [br]
## @api private
var _executing_handles: Dictionary = {}

## 按执行中句柄保存对应任务记录，供 owner 查询和取消使用。
## [br]
## @api private
var _executing_timers: Dictionary = {}

## 暂存执行中任务的取消标记，回调返回后据此阻止重复排队。
## [br]
## @api private
var _cancelled_handles: Dictionary = {}

## 在 init() 或 dispose() 时递增，使当前 tick 放弃旧队列代次的剩余工作。
## [br]
## @api private
var _lifecycle_generation: int = 0


# --- GF 生命周期方法 ---

## 初始化定时器队列。
## [br]
## @api public
func init() -> void:
	_lifecycle_generation += 1
	_pending_timers.clear()
	_ready_timers.clear()
	_next_timer_id = 1
	_executing_handles.clear()
	_executing_timers.clear()
	_cancelled_handles.clear()


## 清空定时器队列。
## [br]
## @api public
func dispose() -> void:
	_lifecycle_generation += 1
	_pending_timers.clear()
	_ready_timers.clear()
	_next_timer_id = 1
	_executing_handles.clear()
	_executing_timers.clear()
	_cancelled_handles.clear()


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if _pending_timers.is_empty() or delta <= 0.0 or is_nan(delta) or is_inf(delta):
		return

	var lifecycle_generation: int = _lifecycle_generation
	var ready_handles: Array[int] = []

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
			var handle: int = _get_timer_id(timer_data)
			_ready_timers[handle] = timer_data
			ready_handles.append(handle)
			_pending_timers.remove_at(index)

	ready_handles.reverse()
	for handle: int in ready_handles:
		if lifecycle_generation != _lifecycle_generation:
			return
		if not _ready_timers.has(handle):
			continue
		var timer_data: Dictionary = _get_ready_timer(handle)
		var _ready_timer_erased_before_execute: bool = _ready_timers.erase(handle)
		_execute_ready_timer(timer_data, lifecycle_generation)
		if lifecycle_generation != _lifecycle_generation:
			return


# --- 公共方法 ---

## 在指定延迟后执行一次回调函数。
## 基于框架 `tick()` 推进计时，因此会自动遵循 `GFTimeUtility` 的暂停与缩放结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param delay: 有限延迟时长，单位为秒。
## [br]
## @param callback: 延迟结束后执行的无参回调函数。
## [br]
## @return 已排队定时器的句柄；无效回调或立即执行时返回 `0`。
func execute_after(delay: float, callback: Callable) -> int:
	if not callback.is_valid():
		push_error("[GFTimerUtility][timer_utility.after_callback_invalid] Cannot execute_after: the supplied callback is invalid.")
		return 0
	if not _is_finite_time_value(delay):
		push_error("[GFTimerUtility][timer_utility.after_delay_non_finite] Cannot execute_after: delay must be finite.")
		return 0

	if delay <= 0.0:
		var _result: Variant = callback.call()
		return 0

	return _queue_timer(delay, callback, 0.0, 1, null)


## 在指定延迟后执行一次 owner 绑定回调。owner 释放后任务会自动丢弃。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param owner: 定时器拥有者。
## [br]
## @param delay: 有限延迟时长，单位为秒。
## [br]
## @param callback: 延迟结束后执行的无参回调函数。
## [br]
## @return 已排队定时器的句柄；无效输入或立即执行时返回 `0`。
func execute_after_owned(owner: Object, delay: float, callback: Callable) -> int:
	if owner == null:
		push_error("[GFTimerUtility][timer_utility.after_owner_null] Cannot execute_after_owned: owner is null.")
		return 0
	if not callback.is_valid():
		push_error("[GFTimerUtility][timer_utility.after_owned_callback_invalid] Cannot execute_after_owned: the supplied callback is invalid.")
		return 0
	if not _is_finite_time_value(delay):
		push_error("[GFTimerUtility][timer_utility.after_owned_delay_non_finite] Cannot execute_after_owned: delay must be finite.")
		return 0

	if delay <= 0.0:
		var _result: Variant = callback.call()
		return 0

	return _queue_timer(delay, callback, 0.0, 1, owner)


## 按固定间隔重复执行回调。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param interval: 有限且大于 0 的重复间隔，单位为秒。
## [br]
## @param callback: 每次触发时执行的无参回调函数。
## [br]
## @param repeat_count: 触发次数；小于 0 表示无限重复。
## [br]
## @param initial_delay: 有限的首次触发延迟；小于 0 时使用 interval。
## [br]
## @return 已排队定时器的句柄；无效输入时返回 `0`。
func execute_repeating(
	interval: float,
	callback: Callable,
	repeat_count: int = -1,
	initial_delay: float = -1.0
) -> int:
	if not callback.is_valid():
		push_error("[GFTimerUtility][timer_utility.repeating_callback_invalid] Cannot execute_repeating: the supplied callback is invalid.")
		return 0
	if not _is_finite_time_value(interval):
		push_error("[GFTimerUtility][timer_utility.repeating_interval_non_finite] Cannot execute_repeating: interval must be finite.")
		return 0
	if interval <= 0.0:
		push_error("[GFTimerUtility][timer_utility.repeating_interval_nonpositive] Cannot execute_repeating: interval must be greater than zero.")
		return 0
	if not _is_finite_time_value(initial_delay):
		push_error("[GFTimerUtility][timer_utility.repeating_initial_delay_non_finite] Cannot execute_repeating: initial_delay must be finite.")
		return 0
	if repeat_count == 0:
		return 0

	var delay: float = initial_delay if initial_delay >= 0.0 else interval
	return _queue_timer(delay, callback, interval, repeat_count, null)


## 按固定间隔重复执行 owner 绑定回调。owner 释放后任务会自动丢弃。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param owner: 定时器拥有者。
## [br]
## @param interval: 有限且大于 0 的重复间隔，单位为秒。
## [br]
## @param callback: 每次触发时执行的无参回调函数。
## [br]
## @param repeat_count: 触发次数；小于 0 表示无限重复。
## [br]
## @param initial_delay: 有限的首次触发延迟；小于 0 时使用 interval。
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
		push_error("[GFTimerUtility][timer_utility.repeating_owner_null] Cannot execute_repeating_owned: owner is null.")
		return 0
	if not callback.is_valid():
		push_error("[GFTimerUtility][timer_utility.repeating_owned_callback_invalid] Cannot execute_repeating_owned: the supplied callback is invalid.")
		return 0
	if not _is_finite_time_value(interval):
		push_error("[GFTimerUtility][timer_utility.repeating_owned_interval_non_finite] Cannot execute_repeating_owned: interval must be finite.")
		return 0
	if interval <= 0.0:
		push_error("[GFTimerUtility][timer_utility.repeating_owned_interval_nonpositive] Cannot execute_repeating_owned: interval must be greater than zero.")
		return 0
	if not _is_finite_time_value(initial_delay):
		push_error("[GFTimerUtility][timer_utility.repeating_owned_initial_delay_non_finite] Cannot execute_repeating_owned: initial_delay must be finite.")
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
	if _ready_timers.has(handle):
		var _ready_timer_cancelled: bool = _ready_timers.erase(handle)
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
	for handle_variant: Variant in _ready_timers.keys():
		var ready_handle: int = GFVariantData.to_int(handle_variant, 0)
		var ready_timer: Dictionary = _get_ready_timer(ready_handle)
		if _get_timer_owner_id(ready_timer) == owner_id:
			var _ready_owner_timer_cancelled: bool = _ready_timers.erase(ready_handle)
			removed += 1
	for executing_handle_variant: Variant in _executing_timers.keys():
		var handle: int = GFVariantData.to_int(executing_handle_variant, 0)
		var executing_timer: Dictionary = _get_executing_timer(handle)
		if _get_timer_owner_id(executing_timer) == owner_id and not _cancelled_handles.has(handle):
			_cancelled_handles[handle] = true
			removed += 1
	return removed


## 检查指定 handle 是否仍属于给定 owner 的待执行或执行中 timer。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @layer standard/utilities
## [br]
## @param handle: execute_after_owned() 返回的 timer handle。
## [br]
## @param owner: 创建 owner-bound timer 时使用的 owner。
## [br]
## @return: handle 与 owner 身份均匹配时返回 true。
func has_owned_timer_for_framework(handle: int, owner: Object) -> bool:
	if handle <= 0 or owner == null or not is_instance_valid(owner):
		return false
	for timer_data: Dictionary in _pending_timers:
		if _get_timer_id(timer_data) == handle and _timer_is_owned_by(timer_data, owner):
			return true
	if _ready_timers.has(handle):
		return _timer_is_owned_by(_get_ready_timer(handle), owner)
	if _executing_handles.has(handle):
		return _timer_is_owned_by(_get_executing_timer(handle), owner)
	return false


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
	for ready_handle_variant: Variant in _ready_timers.keys():
		var ready_handle: int = GFVariantData.to_int(ready_handle_variant, 0)
		var ready_timer: Dictionary = _get_ready_timer(ready_handle)
		var _ready_appended: bool = handles.append(ready_handle)
		if _timer_has_owner_ref(ready_timer):
			owner_bound_count += 1

	return {
		"pending_count": _pending_timers.size() + _ready_timers.size(),
		"pending_handles": handles,
		"owner_bound_count": owner_bound_count,
		"executing_count": _executing_handles.size(),
		"next_timer_id": _next_timer_id,
	}


# --- 私有/辅助方法 ---

## 判断时间值是否既非 NaN 也非正负无穷。
## [br]
## @api private
func _is_finite_time_value(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


## 分配句柄并创建含剩余时间、重复配置、回调与 owner 弱引用的待执行记录。
## [br]
## @api private
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


## 执行一个到期记录，并处理回调中的取消、owner 释放和生命周期重置。
## 重复任务按超时量补跑，达到单次上限后重新排入 pending；回调返回值不参与判定。
## [br]
## @api private
func _execute_ready_timer(timer_data: Dictionary, lifecycle_generation: int) -> void:
	var handle: int = _get_timer_id(timer_data)
	var overshoot: float = maxf(GFVariantData.get_option_float(timer_data, "overshoot", 0.0), 0.0)
	var catch_up_count: int = 0
	while true:
		if lifecycle_generation != _lifecycle_generation:
			return
		if _cancelled_handles.has(handle) or _timer_owner_is_released(timer_data):
			var _removed_cancelled_before: bool = _cancelled_handles.erase(handle)
			return

		var callback: Callable = _get_timer_callback(timer_data)
		if not callback.is_valid():
			return

		_executing_handles[handle] = true
		_executing_timers[handle] = timer_data
		var _result: Variant = callback.call()
		var _removed_executing: bool = _executing_handles.erase(handle)
		var _removed_executing_timer: bool = _executing_timers.erase(handle)

		if lifecycle_generation != _lifecycle_generation:
			return
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


## 判断 owner 弱引用是否已失效；没有 owner 引用的普通任务返回 false。
## [br]
## @api private
func _timer_owner_is_released(timer_data: Dictionary) -> bool:
	if not _timer_has_owner_ref(timer_data):
		return false
	var owner_ref: WeakRef = _get_timer_owner_ref(timer_data)
	return owner_ref == null or owner_ref.get_ref() == null


## 从任务记录读取句柄编号，缺失或类型不符时返回 0。
## [br]
## @api private
func _get_timer_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "id", 0)


## 读取正在执行的任务记录；缺失或类型不符时返回空字典。
## [br]
## @api private
func _get_executing_timer(handle: int) -> Dictionary:
	var timer_value: Variant = GFVariantData.get_option_value(_executing_timers, handle, {})
	if timer_value is Dictionary:
		var timer_data: Dictionary = timer_value
		return timer_data
	return {}


## 读取已到期任务记录；缺失或类型不符时返回空字典。
## [br]
## @api private
func _get_ready_timer(handle: int) -> Dictionary:
	var timer_value: Variant = GFVariantData.get_option_value(_ready_timers, handle, {})
	if timer_value is Dictionary:
		var timer_data: Dictionary = timer_value
		return timer_data
	return {}


## 从任务记录读取剩余秒数，缺失时返回 0.0。
## [br]
## @api private
func _get_timer_remaining(timer_data: Dictionary) -> float:
	return GFVariantData.get_option_float(timer_data, "remaining", 0.0)


## 从任务记录读取重复间隔秒数，缺失时返回 0.0。
## [br]
## @api private
func _get_timer_interval(timer_data: Dictionary) -> float:
	return GFVariantData.get_option_float(timer_data, "interval", 0.0)


## 从任务记录读取剩余触发次数，缺失时返回 0。
## [br]
## @api private
func _get_timer_repeat_count(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "repeat_count", 0)


## 从任务记录读取 owner 实例编号，缺失时返回 0。
## [br]
## @api private
func _get_timer_owner_id(timer_data: Dictionary) -> int:
	return GFVariantData.get_option_int(timer_data, "owner_id", 0)


## 从任务记录读取并验证回调；字段无效时返回无效 Callable。
## [br]
## @api private
func _get_timer_callback(timer_data: Dictionary) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(timer_data, "callback", Callable()))


## 从任务记录读取 owner 弱引用；字段类型不符时返回 null。
## [br]
## @api private
func _get_timer_owner_ref(timer_data: Dictionary) -> WeakRef:
	return _variant_to_weak_ref(GFVariantData.get_option_value(timer_data, "owner_ref"))


## 检查任务记录是否包含非 null 的 owner_ref 字段。
## [br]
## @api private
func _timer_has_owner_ref(timer_data: Dictionary) -> bool:
	return GFVariantData.get_option_value(timer_data, "owner_ref") != null


## 通过实例编号和弱引用解析出的对象身份共同匹配 owner。
## [br]
## @api private
func _timer_is_owned_by(timer_data: Dictionary, owner: Object) -> bool:
	if timer_data.is_empty() or owner == null or not is_instance_valid(owner):
		return false
	if _get_timer_owner_id(timer_data) != owner.get_instance_id():
		return false
	var owner_ref: WeakRef = _get_timer_owner_ref(timer_data)
	return owner_ref != null and owner_ref.get_ref() == owner


## 将 Callable Variant 收窄为 Callable；其他类型返回无效 Callable。
## [br]
## @api private
func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 将 WeakRef Variant 收窄为 WeakRef；其他类型返回 null。
## [br]
## @api private
func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var owner_ref: WeakRef = value
		return owner_ref
	return null
