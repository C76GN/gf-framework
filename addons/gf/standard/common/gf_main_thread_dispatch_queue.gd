## GFMainThreadDispatchQueue: 主线程回调派发队列。
##
## 用于让后台线程、资源加载回调或项目侧异步流程把最终应用逻辑排回主线程。
## post() 保存无 owner 的强 Callable；post_method() 通过弱 owner 和方法名保存生命周期调用。
## 入队和取消入口由 Mutex 保护；dispatch()、tick() 与生命周期入口只允许在主线程调用。
## 队列不创建线程，也不解释调用方的业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFMainThreadDispatchQueue
extends GFUtility


# --- 常量 ---

## 默认最多保留的待派发回调数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_PENDING_CALLBACKS: int = 1024

## 最多允许配置的待派发回调数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_PENDING_CALLBACKS: int = 65_536

## dispatch() 未显式给出数量预算时使用的默认值。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_CALLBACKS_PER_DISPATCH: int = 16

## 单次 dispatch() 允许处理的回调数量绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_CALLBACKS_PER_DISPATCH: int = 4096

## 派发正常完成。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_COMPLETED: StringName = &"completed"

## 派发入口在非主线程被调用。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_WRONG_THREAD: StringName = &"wrong_thread"

## 当前实例已经处于同步派发调用中。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_BUSY: StringName = &"busy"


# --- 公共变量 ---

## 最多保留的待派发回调数量。降低容量不会驱逐现有回调。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_pending_callbacks: int = DEFAULT_MAX_PENDING_CALLBACKS:
	set(value):
		max_pending_callbacks = clampi(
			value,
			1,
			ABSOLUTE_MAX_PENDING_CALLBACKS
		)

## tick() 每次最多派发多少个回调。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_callbacks_per_tick: int = DEFAULT_MAX_CALLBACKS_PER_DISPATCH:
	set(value):
		max_callbacks_per_tick = clampi(
			value,
			1,
			ABSOLUTE_MAX_CALLBACKS_PER_DISPATCH
		)

## tick() 在回调之间检查的非抢占式软时间预算。小于等于 0 时不启用；
## 不会中断单个回调，并且非空入口快照至少会尝试派发一个回调。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_seconds_per_tick: float = 0.0:
	set(value):
		max_seconds_per_tick = maxf(value, 0.0)


# --- 私有变量 ---

var _mutex: Mutex = Mutex.new()
var _queue: Array[Dictionary] = []
var _dispatch_snapshot: Array[Dictionary] = []
var _dispatch_front_records: Array[Dictionary] = []
var _dispatch_back_records: Array[Dictionary] = []
var _dispatch_snapshot_cursor: int = 0
var _dispatch_snapshot_pending_count: int = 0
var _dispatch_snapshot_active: bool = false
var _pending_count: int = 0
var _next_handle: int = 1
var _dispatch_context_marked: bool = false
var _dispatch_in_progress: bool = false
var _posted_count: int = 0
var _dispatched_count: int = 0
var _cancelled_count: int = 0
var _failed_count: int = 0
var _skipped_owner_count: int = 0
var _high_watermark: int = 0
var _rejected_count: int = 0
var _dropped_count: int = 0


# --- GF 生命周期方法 ---

## 初始化队列，并标记该实例已有显式派发点。
## [br]
## @api public
## [br]
## @since 7.0.0
func init() -> void:
	clear()
	mark_dispatch_context()


## 按当前预算派发队列中的回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param _delta: 为兼容 GF tick 签名而保留。
func tick(_delta: float = 0.0) -> void:
	var _dispatch_report: Dictionary = dispatch(max_callbacks_per_tick, max_seconds_per_tick)


## 清空队列。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


# --- 公共方法 ---

## 把无 owner 的回调加入主线程派发队列。
## 该入口会强持有 callback；需要绑定 owner 生命周期时使用 post_method()。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param callback: 需要在显式派发点执行的回调。
## [br]
## @param options: 队列选项，支持 metadata、label 和 front。
## [br]
## @schema options: Dictionary，可包含 metadata: Dictionary、label: String、front: bool。
## [br]
## @return 派发句柄；callback 无效时返回 0。
func post(callback: Callable, options: Dictionary = {}) -> int:
	if not callback.is_valid():
		push_error("[GFMainThreadDispatchQueue] post 失败：callback 无效。")
		return 0
	if options.has("owner") or options.has(&"owner"):
		push_error("[GFMainThreadDispatchQueue] post 失败：owner 选项已移除，请使用 post_method()。")
		return 0

	return _enqueue(callback, options)


## 把弱 owner 方法调用加入主线程派发队列。
## 队列只保存 owner 的弱引用与方法名，不保存绑定 Callable、调用参数或 owner 强引用。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner: 方法调用拥有者。
## [br]
## @param method_name: 派发时调用的方法名。
## [br]
## @param options: 队列选项，支持 label 和 front。
## [br]
## @schema options: Dictionary，可包含 label: String、front: bool。
## [br]
## @return 派发句柄；owner 或 method_name 无效时返回 0。
func post_method(owner: Object, method_name: StringName, options: Dictionary = {}) -> int:
	if owner == null or not is_instance_valid(owner):
		push_error("[GFMainThreadDispatchQueue] post_method 失败：owner 为空或已释放。")
		return 0
	if method_name == &"":
		push_error("[GFMainThreadDispatchQueue] post_method 失败：method_name 为空。")
		return 0

	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(owner, method_name)
	return _enqueue_method(invocation, owner.get_instance_id(), options)


## 派发队列中的回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param max_count: 最大派发数量；小于等于 0 时使用 max_callbacks_per_tick，并始终受绝对工作预算约束。
## [br]
## @param max_seconds: 在回调之间检查的非抢占式软时间预算；小于等于 0 时不启用。不会中断单个回调，非空入口快照至少尝试一条。
## [br]
## @return 派发报告。
## [br]
## @schema return: Dictionary，包含 ok、status、reason、dispatched_count、failed_count、skipped_owner_count、pending_count、budget_exhausted 和 dispatch_context_marked。
func dispatch(max_count: int = 0, max_seconds: float = 0.0) -> Dictionary:
	if not Thread.is_main_thread():
		return {
			"ok": false,
			"status": STATUS_WRONG_THREAD,
			"reason": STATUS_WRONG_THREAD,
			"dispatched_count": 0,
			"failed_count": 0,
			"skipped_owner_count": 0,
			"pending_count": get_pending_count(),
			"budget_exhausted": false,
			"dispatch_context_marked": _dispatch_context_marked,
		}
	if _dispatch_in_progress:
		return {
			"ok": false,
			"status": STATUS_BUSY,
			"reason": STATUS_BUSY,
			"dispatched_count": 0,
			"failed_count": 0,
			"skipped_owner_count": 0,
			"pending_count": get_pending_count(),
			"budget_exhausted": false,
			"dispatch_context_marked": _dispatch_context_marked,
		}

	_dispatch_in_progress = true
	var limit: int = clampi(
		max_count if max_count > 0 else max_callbacks_per_tick,
		1,
		ABSOLUTE_MAX_CALLBACKS_PER_DISPATCH
	)
	var seconds_budget: float = maxf(max_seconds, 0.0)
	var started_usec: int = Time.get_ticks_usec()
	var dispatched_now: int = 0
	var failed_now: int = 0
	var skipped_owner_now: int = 0
	var budget_exhausted: bool = false
	_begin_dispatch_snapshot()

	while dispatched_now + failed_now + skipped_owner_now < limit:
		if _is_dispatch_budget_exhausted(started_usec, seconds_budget, dispatched_now + failed_now + skipped_owner_now):
			budget_exhausted = _has_dispatch_snapshot_records()
			break

		var record: Dictionary = _pop_next_dispatch_record()
		if record.is_empty():
			break

		var invocation: GFWeakMethodInvocation = _get_record_method_invocation(record)
		if invocation != null:
			var invocation_report: Dictionary = invocation.invoke()
			var invocation_status: StringName = GFVariantData.get_option_string_name(
				invocation_report,
				"status",
				GFWeakMethodInvocation.STATUS_FAILED
			)
			if invocation_status == GFWeakMethodInvocation.STATUS_OWNER_RELEASED:
				skipped_owner_now += 1
				_skipped_owner_count += 1
			elif invocation_status != GFWeakMethodInvocation.STATUS_INVOKED:
				failed_now += 1
				_failed_count += 1
			elif _callback_result_is_failure(
				GFVariantData.get_option_value(invocation_report, "value")
			):
				failed_now += 1
				_failed_count += 1
			else:
				dispatched_now += 1
				_dispatched_count += 1
			continue

		var callback: Callable = _get_record_callback(record)
		if not callback.is_valid():
			failed_now += 1
			_failed_count += 1
			continue

		var result: Variant = callback.call()
		if _callback_result_is_failure(result):
			failed_now += 1
			_failed_count += 1
		else:
			dispatched_now += 1
			_dispatched_count += 1

	var processed_count: int = (
		dispatched_now
		+ failed_now
		+ skipped_owner_now
	)
	if (
		processed_count >= limit
		and _has_dispatch_snapshot_records()
	):
		budget_exhausted = true

	_finish_dispatch_snapshot()
	var report: Dictionary = {
		"ok": true,
		"status": STATUS_COMPLETED,
		"reason": &"",
		"dispatched_count": dispatched_now,
		"failed_count": failed_now,
		"skipped_owner_count": skipped_owner_now,
		"pending_count": get_pending_count(),
		"budget_exhausted": budget_exhausted,
		"dispatch_context_marked": _dispatch_context_marked,
	}
	_dispatch_in_progress = false
	return report


## 取消一个尚未派发的回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: post() 或 post_method() 返回的派发句柄。
## [br]
## @return 找到并取消时返回 true。
func cancel(handle: int) -> bool:
	if handle <= 0:
		return false

	_mutex.lock()
	var cancelled: bool = _cancel_handle_locked(handle)
	if cancelled:
		_cancelled_count += 1
	_mutex.unlock()
	return cancelled


## 取消指定 owner 的全部待派发弱方法调用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 回调拥有者。
## [br]
## @return 取消数量。
func cancel_owner(owner: Object) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0

	var owner_id: int = owner.get_instance_id()
	_mutex.lock()
	var removed_count: int = _cancel_owner_locked(owner_id)
	_cancelled_count += removed_count
	_mutex.unlock()
	return removed_count


## 清空全部待派发回调和统计。句柄序列在实例生命周期内保持单调，避免旧句柄命中新记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_mutex.lock()
	_queue.clear()
	_dispatch_snapshot.clear()
	_dispatch_front_records.clear()
	_dispatch_back_records.clear()
	_dispatch_snapshot_cursor = 0
	_dispatch_snapshot_pending_count = 0
	_pending_count = 0
	_posted_count = 0
	_dispatched_count = 0
	_cancelled_count = 0
	_failed_count = 0
	_skipped_owner_count = 0
	_high_watermark = 0
	_rejected_count = 0
	_dropped_count = 0
	_mutex.unlock()


## 标记该实例已有显式派发点。
## [br]
## @api public
## [br]
## @since 7.0.0
func mark_dispatch_context() -> void:
	_dispatch_context_marked = true


## 当前实例是否已经标记显式派发点。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已标记显式派发点时返回 true。
func has_dispatch_context() -> bool:
	return _dispatch_context_marked


## 获取待派发数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 队列长度。
func get_pending_count() -> int:
	_mutex.lock()
	var count: int = _pending_count
	_mutex.unlock()
	return count


## 检查队列是否为空。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 队列为空时返回 true。
func is_empty() -> bool:
	return get_pending_count() == 0


## 获取队列调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 pending_count、max_pending_callbacks、max_callbacks_per_dispatch、pending_handles、posted_count、dispatched_count、cancelled_count、failed_count、skipped_owner_count、high_watermark、rejected_count、dropped_count 和 dispatch_context_marked。
func get_debug_snapshot() -> Dictionary:
	_mutex.lock()
	var handles: PackedInt64Array = PackedInt64Array()
	var labels: PackedStringArray = PackedStringArray()
	var pending_records: Array[Dictionary] = _collect_pending_records_locked()
	for record: Dictionary in pending_records:
		var _handle_appended: bool = handles.append(_get_record_handle(record))
		var label: String = GFVariantData.get_option_string(record, "label")
		if not label.is_empty():
			var _label_appended: bool = labels.append(label)
	var pending_count: int = _pending_count
	var posted_count: int = _posted_count
	var dispatched_count: int = _dispatched_count
	var cancelled_count: int = _cancelled_count
	var failed_count: int = _failed_count
	var skipped_owner_count: int = _skipped_owner_count
	var configured_max_pending: int = max_pending_callbacks
	var configured_dispatch_budget: int = max_callbacks_per_tick
	var high_watermark: int = _high_watermark
	var rejected_count: int = _rejected_count
	var dropped_count: int = _dropped_count
	_mutex.unlock()

	return {
		"pending_count": pending_count,
		"max_pending_callbacks": configured_max_pending,
		"max_callbacks_per_dispatch": configured_dispatch_budget,
		"pending_handles": handles,
		"pending_labels": labels,
		"posted_count": posted_count,
		"dispatched_count": dispatched_count,
		"cancelled_count": cancelled_count,
		"failed_count": failed_count,
		"skipped_owner_count": skipped_owner_count,
		"high_watermark": high_watermark,
		"rejected_count": rejected_count,
		"dropped_count": dropped_count,
		"dispatch_context_marked": _dispatch_context_marked,
	}


# --- 私有/辅助方法 ---

func _enqueue(callback: Callable, options: Dictionary) -> int:
	_mutex.lock()
	if _pending_count >= max_pending_callbacks:
		_rejected_count += 1
		_mutex.unlock()
		return 0
	var handle: int = _next_handle
	_next_handle += 1
	var record: Dictionary = {
		"handle": handle,
		"callback": callback,
		"owner_id": 0,
		"label": GFVariantData.get_option_string(options, "label"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
		"posted_msec": Time.get_ticks_msec(),
	}
	if _dispatch_snapshot_active:
		if GFVariantData.get_option_bool(options, "front", false):
			_dispatch_front_records.append(record)
		else:
			_dispatch_back_records.append(record)
	elif GFVariantData.get_option_bool(options, "front", false):
		_queue.push_front(record)
	else:
		_queue.append(record)
	_pending_count += 1
	_posted_count += 1
	_high_watermark = maxi(_high_watermark, _pending_count)
	_mutex.unlock()
	return handle


func _enqueue_method(
	invocation: GFWeakMethodInvocation,
	owner_id: int,
	options: Dictionary
) -> int:
	_mutex.lock()
	if _pending_count >= max_pending_callbacks:
		_rejected_count += 1
		_mutex.unlock()
		return 0
	var handle: int = _next_handle
	_next_handle += 1
	var record: Dictionary = {
		"handle": handle,
		"invocation": invocation,
		"owner_id": owner_id,
		"label": GFVariantData.get_option_string(options, "label"),
		"posted_msec": Time.get_ticks_msec(),
	}
	if _dispatch_snapshot_active:
		if GFVariantData.get_option_bool(options, "front", false):
			_dispatch_front_records.append(record)
		else:
			_dispatch_back_records.append(record)
	elif GFVariantData.get_option_bool(options, "front", false):
		_queue.push_front(record)
	else:
		_queue.append(record)
	_pending_count += 1
	_posted_count += 1
	_high_watermark = maxi(_high_watermark, _pending_count)
	_mutex.unlock()
	return handle


func _begin_dispatch_snapshot() -> void:
	_mutex.lock()
	_dispatch_snapshot = _queue
	_queue = []
	_dispatch_front_records.clear()
	_dispatch_back_records.clear()
	_dispatch_snapshot_cursor = 0
	_dispatch_snapshot_pending_count = _dispatch_snapshot.size()
	_dispatch_snapshot_active = true
	_mutex.unlock()


func _pop_next_dispatch_record() -> Dictionary:
	_mutex.lock()
	while _dispatch_snapshot_cursor < _dispatch_snapshot.size():
		var record: Dictionary = _dispatch_snapshot[
			_dispatch_snapshot_cursor
		]
		_dispatch_snapshot[_dispatch_snapshot_cursor] = {}
		_dispatch_snapshot_cursor += 1
		if record.is_empty():
			continue
		_dispatch_snapshot_pending_count -= 1
		_pending_count -= 1
		_mutex.unlock()
		return record
	_mutex.unlock()
	return {}


func _has_dispatch_snapshot_records() -> bool:
	_mutex.lock()
	var has_records: bool = _dispatch_snapshot_pending_count > 0
	_mutex.unlock()
	return has_records


func _finish_dispatch_snapshot() -> void:
	_mutex.lock()
	var merged_records: Array[Dictionary] = []
	_append_non_empty_records_reversed(
		merged_records,
		_dispatch_front_records
	)
	_append_non_empty_records(
		merged_records,
		_dispatch_snapshot,
		_dispatch_snapshot_cursor
	)
	_append_non_empty_records(
		merged_records,
		_dispatch_back_records,
		0
	)
	_queue = merged_records
	_dispatch_snapshot.clear()
	_dispatch_front_records.clear()
	_dispatch_back_records.clear()
	_dispatch_snapshot_cursor = 0
	_dispatch_snapshot_pending_count = 0
	_dispatch_snapshot_active = false
	_pending_count = _queue.size()
	_mutex.unlock()


func _cancel_handle_locked(handle: int) -> bool:
	if not _dispatch_snapshot_active:
		for index: int in range(_queue.size()):
			if _get_record_handle(_queue[index]) != handle:
				continue
			_queue.remove_at(index)
			_pending_count -= 1
			return true
		return false

	for index: int in range(_dispatch_front_records.size()):
		if _get_record_handle(_dispatch_front_records[index]) != handle:
			continue
		_dispatch_front_records.remove_at(index)
		_pending_count -= 1
		return true
	for index: int in range(
		_dispatch_snapshot_cursor,
		_dispatch_snapshot.size()
	):
		var snapshot_record: Dictionary = _dispatch_snapshot[index]
		if (
			snapshot_record.is_empty()
			or _get_record_handle(snapshot_record) != handle
		):
			continue
		_dispatch_snapshot[index] = {}
		_dispatch_snapshot_pending_count -= 1
		_pending_count -= 1
		return true
	for index: int in range(_dispatch_back_records.size()):
		if _get_record_handle(_dispatch_back_records[index]) != handle:
			continue
		_dispatch_back_records.remove_at(index)
		_pending_count -= 1
		return true
	return false


func _cancel_owner_locked(owner_id: int) -> int:
	var removed_count: int = 0
	if not _dispatch_snapshot_active:
		for index: int in range(_queue.size() - 1, -1, -1):
			if _get_record_owner_id(_queue[index]) != owner_id:
				continue
			_queue.remove_at(index)
			removed_count += 1
			_pending_count -= 1
		return removed_count

	for index: int in range(
		_dispatch_front_records.size() - 1,
		-1,
		-1
	):
		if _get_record_owner_id(_dispatch_front_records[index]) != owner_id:
			continue
		_dispatch_front_records.remove_at(index)
		removed_count += 1
		_pending_count -= 1
	for index: int in range(
		_dispatch_snapshot_cursor,
		_dispatch_snapshot.size()
	):
		var snapshot_record: Dictionary = _dispatch_snapshot[index]
		if (
			snapshot_record.is_empty()
			or _get_record_owner_id(snapshot_record) != owner_id
		):
			continue
		_dispatch_snapshot[index] = {}
		_dispatch_snapshot_pending_count -= 1
		removed_count += 1
		_pending_count -= 1
	for index: int in range(
		_dispatch_back_records.size() - 1,
		-1,
		-1
	):
		if _get_record_owner_id(_dispatch_back_records[index]) != owner_id:
			continue
		_dispatch_back_records.remove_at(index)
		removed_count += 1
		_pending_count -= 1
	return removed_count


func _collect_pending_records_locked() -> Array[Dictionary]:
	var pending_records: Array[Dictionary] = []
	if not _dispatch_snapshot_active:
		_append_non_empty_records(pending_records, _queue, 0)
		return pending_records
	_append_non_empty_records_reversed(
		pending_records,
		_dispatch_front_records
	)
	_append_non_empty_records(
		pending_records,
		_dispatch_snapshot,
		_dispatch_snapshot_cursor
	)
	_append_non_empty_records(
		pending_records,
		_dispatch_back_records,
		0
	)
	return pending_records


func _append_non_empty_records(
	target_records: Array[Dictionary],
	source_records: Array[Dictionary],
	start_index: int
) -> void:
	for index: int in range(start_index, source_records.size()):
		var record: Dictionary = source_records[index]
		if record.is_empty():
			continue
		target_records.append(record)


func _append_non_empty_records_reversed(
	target_records: Array[Dictionary],
	source_records: Array[Dictionary]
) -> void:
	for index: int in range(source_records.size() - 1, -1, -1):
		var record: Dictionary = source_records[index]
		if record.is_empty():
			continue
		target_records.append(record)


func _is_dispatch_budget_exhausted(started_usec: int, max_seconds: float, processed_count: int) -> bool:
	if max_seconds <= 0.0 or processed_count <= 0:
		return false
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return elapsed_seconds >= max_seconds


func _callback_result_is_failure(result: Variant) -> bool:
	if result is bool:
		var bool_result: bool = result
		return not bool_result
	if result is Dictionary:
		var dictionary_result: Dictionary = result
		return not GFVariantData.get_option_bool(dictionary_result, "ok", true)
	return false


func _get_record_handle(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "handle")


func _get_record_owner_id(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "owner_id")


func _get_record_callback(record: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(record, "callback", Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_record_method_invocation(record: Dictionary) -> GFWeakMethodInvocation:
	var value: Variant = GFVariantData.get_option_value(record, "invocation")
	if value is GFWeakMethodInvocation:
		var invocation: GFWeakMethodInvocation = value
		return invocation
	return null
