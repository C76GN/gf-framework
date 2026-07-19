## GFQuietWindowCoalescer: 按 key 聚合连发消息的静默窗口协调器。
##
## 每个 key 独立收集按序消息，在最后一次提交后的静默窗口、批次最大窗口或
## 消息数量上限到达时关闭批次。框架不解释消息内容；项目可通过 merge_callback
## 定义文本拼接、状态折叠、网络载荷聚合或其它合并语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFQuietWindowCoalescer
extends RefCounted


# --- 信号 ---

## 一个消息批次关闭时发出。容量收缩及淘汰回调重入产生的后续容量通知会等待
## 后续 process frame，并按固定帧预算派发，避免单次提交被回调链无限延长。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param report: 批次报告。
## [br]
## @schema report: Dictionary，包含 batch_id、key、reason、message_count、messages、merged_value、opened_msec、closed_msec 和 duration_msec。
signal batch_closed(report: Dictionary)


# --- 常量 ---

const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const _MAX_TIMER_SLICE_MSEC: int = 1000
const _MAX_CAPACITY_NOTIFICATIONS_PER_DRAIN: int = 64

## 最后一条消息后的静默窗口到达。
## [br]
## @api public
## [br]
## @since 9.0.0
const REASON_QUIET_WINDOW: StringName = &"quiet_window"

## 批次从打开起已达到最大窗口。
## [br]
## @api public
## [br]
## @since 9.0.0
const REASON_MAX_WINDOW: StringName = &"max_window"

## 批次已达到消息数量上限。
## [br]
## @api public
## [br]
## @since 9.0.0
const REASON_BATCH_LIMIT: StringName = &"batch_limit"

## 调用方显式关闭批次。
## [br]
## @api public
## [br]
## @since 9.0.0
const REASON_MANUAL: StringName = &"manual"

## 待处理 key 数量达到上限时，最早批次被关闭。
## [br]
## @api public
## [br]
## @since 9.0.0
const REASON_PENDING_LIMIT: StringName = &"pending_limit"


# --- 公共变量 ---

## 最后一条消息后需要保持安静的毫秒数；设为 0 时提交后立即关闭。
## [br]
## @api public
## [br]
## @since 9.0.0
var quiet_window_msec: int = 250:
	set(value):
		quiet_window_msec = maxi(value, 0)

## 批次从打开到强制关闭的最大毫秒数；设为 0 时不启用该上限。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_window_msec: int = 1000:
	set(value):
		max_window_msec = maxi(value, 0)

## 单批最多收集的消息数。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_messages_per_batch: int = 64:
	set(value):
		max_messages_per_batch = maxi(value, 1)

## 同时打开的 key 批次数量上限；达到上限时关闭最早批次。运行时降低该值会
## 立即按稳定顺序移除超额批次，并按跨帧预算交付关闭通知。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_pending_batches: int = 128:
	set(value):
		value = maxi(value, 1)
		if max_pending_batches == value:
			return
		max_pending_batches = value
		_trim_pending_batches_to_limit(Time.get_ticks_msec())

## 是否使用 SceneTree 实时时钟自动关闭到期批次。运行中关闭会撤销现有计时但保留批次，
## 重新开启会处理已到期批次并重建其余计时；也可关闭后由 flush_ready() 显式推进。
## [br]
## @api public
## [br]
## @since 9.0.0
var auto_flush: bool = true:
	set(value):
		if auto_flush == value:
			return
		auto_flush = value
		_restart_auto_flush_timers()

## 可选合并回调，签名为 func(key: StringName, messages: Array) -> Variant。
## 未设置时 merged_value 是 messages 的副本。
## [br]
## @api public
## [br]
## @since 9.0.0
var merge_callback: Callable = Callable()


# --- 私有变量 ---

var _batches: Dictionary = {}
var _batch_serial: int = 0
var _lifecycle_serial: int = 0
var _pending_capacity_notifications: Array[Dictionary] = []
var _is_dispatching_capacity_notification: bool = false
var _capacity_notification_drain_scheduled: bool = false


# --- 公共方法 ---

## 使用当前单调时钟把消息提交到 key 对应批次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param key: 独立合并通道的稳定标识；空值也可作为默认通道。
## [br]
## @param message: 由项目解释的消息载荷；入队时会复制可变容器。
## [br]
## @return 当前批次 ID。
## [br]
## @schema message: Variant，由项目解释的消息载荷。
func submit(key: StringName, message: Variant) -> int:
	return submit_at(key, message, Time.get_ticks_msec())


## 使用显式单调时间把消息提交到 key 对应批次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param key: 独立合并通道的稳定标识；空值也可作为默认通道。
## [br]
## @param message: 由项目解释的消息载荷；入队时会复制可变容器。
## [br]
## @param now_msec: 同一单调时间域中的当前毫秒时间。
## [br]
## @return 当前批次 ID。
## [br]
## @schema message: Variant，由项目解释的消息载荷。
func submit_at(key: StringName, message: Variant, now_msec: int) -> int:
	var effective_now: int = maxi(now_msec, 0)
	var evicted_batch: Dictionary = {}
	if not _batches.has(key):
		if _batches.size() >= max_pending_batches:
			var oldest_key: StringName = _find_oldest_key()
			evicted_batch = _take_batch(oldest_key)
		_create_batch(key, effective_now)

	var batch: Dictionary = _get_batch(key)
	var messages: Array = GFVariantData.get_option_array(batch, "messages")
	messages.append(GFVariantData.duplicate_variant(message))
	batch["messages"] = messages
	batch["last_message_msec"] = maxi(
		GFVariantData.get_option_int(batch, "last_message_msec"),
		effective_now
	)
	var batch_id: int = GFVariantData.get_option_int(batch, "batch_id")
	if not evicted_batch.is_empty():
		_dispatch_capacity_notification(evicted_batch, effective_now)
		var current_batch: Dictionary = _get_batch(key)
		if GFVariantData.get_option_int(current_batch, "batch_id") != batch_id:
			return batch_id
		batch = current_batch
		messages = GFVariantData.get_option_array(batch, "messages")
	if messages.size() >= max_messages_per_batch:
		var _limit_report: Dictionary = _close_batch(key, REASON_BATCH_LIMIT, effective_now)
		return batch_id
	if auto_flush:
		var ready_reason: StringName = _get_ready_reason(batch, effective_now)
		if ready_reason != &"":
			var _ready_report: Dictionary = _close_batch(key, ready_reason, effective_now)
		else:
			_start_batch_timer_if_needed(key, batch)
	return batch_id


## 关闭当前已经到达静默窗口或最大窗口的批次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param now_msec: 同一单调时间域中的当前毫秒时间；小于 0 时自动读取。
## [br]
## @return 本次关闭的批次报告。
## [br]
## @schema return: Array[Dictionary]，每项与 batch_closed 的 report schema 相同。
func flush_ready(now_msec: int = -1) -> Array[Dictionary]:
	var effective_now: int = Time.get_ticks_msec() if now_msec < 0 else maxi(now_msec, 0)
	var reports: Array[Dictionary] = []
	var keys: Array = _batches.keys()
	for key_value: Variant in keys:
		var key: StringName = GFVariantData.to_string_name(key_value)
		var batch: Dictionary = _get_batch(key)
		var reason: StringName = _get_ready_reason(batch, effective_now)
		if reason == &"":
			continue
		var report: Dictionary = _close_batch(key, reason, effective_now)
		if not report.is_empty():
			reports.append(report)
	return reports


## 显式关闭指定 key 的批次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param key: 要关闭的批次 key。
## [br]
## @param reason: 项目可提供的稳定关闭原因；为空时使用 manual。
## [br]
## @return 批次不存在时返回空字典，否则返回批次报告。
## [br]
## @schema return: Dictionary，与 batch_closed 的 report schema 相同。
func flush(key: StringName, reason: StringName = REASON_MANUAL) -> Dictionary:
	var effective_reason: StringName = reason if reason != &"" else REASON_MANUAL
	return _close_batch(key, effective_reason, Time.get_ticks_msec())


## 显式关闭调用开始时已经存在的所有批次；回调重入创建的新批次留给下一轮。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param reason: 项目可提供的稳定关闭原因；为空时使用 manual。
## [br]
## @return 所有已关闭批次报告。
## [br]
## @schema return: Array[Dictionary]，每项与 batch_closed 的 report schema 相同。
func flush_all(reason: StringName = REASON_MANUAL) -> Array[Dictionary]:
	var effective_reason: StringName = reason if reason != &"" else REASON_MANUAL
	var reports: Array[Dictionary] = []
	for identity: Dictionary in _get_batch_identity_snapshot():
		var key: StringName = GFVariantData.get_option_string_name(identity, "key")
		var batch_id: int = GFVariantData.get_option_int(identity, "batch_id")
		if GFVariantData.get_option_int(_get_batch(key), "batch_id") != batch_id:
			continue
		var report: Dictionary = _close_batch(key, effective_reason, Time.get_ticks_msec())
		if not report.is_empty():
			reports.append(report)
	return reports


## 丢弃指定 key 的未关闭批次，不发出 batch_closed。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param key: 要丢弃的批次 key。
## [br]
## @return 批次存在并被丢弃时返回 true。
func cancel(key: StringName) -> bool:
	return _batches.erase(key)


## 丢弃全部未关闭批次并使现有计时任务失效。
## [br]
## @api public
## [br]
## @since 9.0.0
func clear() -> void:
	_lifecycle_serial += 1
	_batches.clear()


## 获取当前打开批次数量。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 打开批次数量。
func get_pending_batch_count() -> int:
	return _batches.size()


## 获取不包含消息正文的有界调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param max_entries: 最多返回多少个批次摘要；小于等于 0 时不返回摘要。
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含配置、pending_batch_count、retained_batch_count、truncated 和 batches；batches 每项包含 batch_id、key、message_count 与时间字段。
func get_debug_snapshot(max_entries: int = 32) -> Dictionary:
	var summaries: Array[Dictionary] = []
	var limit: int = maxi(max_entries, 0)
	for key_value: Variant in _batches.keys():
		if summaries.size() >= limit:
			break
		var key: StringName = GFVariantData.to_string_name(key_value)
		var batch: Dictionary = _get_batch(key)
		summaries.append({
			"batch_id": GFVariantData.get_option_int(batch, "batch_id"),
			"key": String(key),
			"message_count": GFVariantData.get_option_array(batch, "messages").size(),
			"opened_msec": GFVariantData.get_option_int(batch, "opened_msec"),
			"last_message_msec": GFVariantData.get_option_int(batch, "last_message_msec"),
		})
	return {
		"quiet_window_msec": quiet_window_msec,
		"max_window_msec": max_window_msec,
		"max_messages_per_batch": max_messages_per_batch,
		"max_pending_batches": max_pending_batches,
		"auto_flush": auto_flush,
		"pending_batch_count": _batches.size(),
		"retained_batch_count": summaries.size(),
		"truncated": summaries.size() < _batches.size(),
		"batches": summaries,
	}


# --- 私有/辅助方法 ---

func _create_batch(key: StringName, now_msec: int) -> void:
	_batch_serial += 1
	_batches[key] = {
		"batch_id": _batch_serial,
		"key": key,
		"opened_msec": now_msec,
		"last_message_msec": now_msec,
		"messages": [],
		"timer_started": false,
	}


func _get_batch(key: StringName) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(_batches, key)
	if value is Dictionary:
		var batch: Dictionary = value
		return batch
	return {}


func _take_batch(key: StringName) -> Dictionary:
	var batch: Dictionary = _get_batch(key)
	if batch.is_empty():
		return {}
	var _erased: bool = _batches.erase(key)
	return batch


func _start_batch_timer_if_needed(key: StringName, batch: Dictionary) -> void:
	if GFVariantData.get_option_bool(batch, "timer_started"):
		return
	batch["timer_started"] = true
	var batch_id: int = GFVariantData.get_option_int(batch, "batch_id")
	var lifecycle_serial: int = _lifecycle_serial
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_run_batch_timer"),
		[key, batch_id, lifecycle_serial]
	)


func _run_batch_timer(key: StringName, batch_id: int, lifecycle_serial: int) -> void:
	while lifecycle_serial == _lifecycle_serial:
		var batch: Dictionary = _get_batch(key)
		if batch.is_empty() or GFVariantData.get_option_int(batch, "batch_id") != batch_id:
			return
		if not auto_flush:
			batch["timer_started"] = false
			return

		var now_msec: int = Time.get_ticks_msec()
		var reason: StringName = _get_ready_reason(batch, now_msec)
		if reason != &"":
			var _report: Dictionary = _close_batch(key, reason, now_msec)
			return

		var wait_msec: int = _get_next_wait_msec(batch, now_msec)
		var main_loop: MainLoop = Engine.get_main_loop()
		if not main_loop is SceneTree:
			batch["timer_started"] = false
			return
		var tree: SceneTree = main_loop
		var timer_slice_msec: int = mini(maxi(wait_msec, 1), _MAX_TIMER_SLICE_MSEC)
		await tree.create_timer(float(timer_slice_msec) / 1000.0, true, false, true).timeout


func _get_ready_reason(batch: Dictionary, now_msec: int) -> StringName:
	if batch.is_empty():
		return &""
	var opened_msec: int = GFVariantData.get_option_int(batch, "opened_msec")
	var last_message_msec: int = GFVariantData.get_option_int(batch, "last_message_msec")
	if max_window_msec > 0 and now_msec - opened_msec >= max_window_msec:
		return REASON_MAX_WINDOW
	if now_msec - last_message_msec >= quiet_window_msec:
		return REASON_QUIET_WINDOW
	return &""


func _get_next_wait_msec(batch: Dictionary, now_msec: int) -> int:
	var last_message_msec: int = GFVariantData.get_option_int(batch, "last_message_msec")
	var deadline_msec: int = last_message_msec + quiet_window_msec
	if max_window_msec > 0:
		var opened_msec: int = GFVariantData.get_option_int(batch, "opened_msec")
		deadline_msec = mini(deadline_msec, opened_msec + max_window_msec)
	return maxi(deadline_msec - now_msec, 1)


func _close_batch(key: StringName, reason: StringName, closed_msec: int) -> Dictionary:
	var batch: Dictionary = _take_batch(key)
	if batch.is_empty():
		return {}
	return _finalize_closed_batch(batch, reason, closed_msec)


func _finalize_closed_batch(
	batch: Dictionary,
	reason: StringName,
	closed_msec: int
) -> Dictionary:
	var key: StringName = GFVariantData.get_option_string_name(batch, "key")
	var messages: Array = GFVariantData.get_option_array(batch, "messages").duplicate(true)
	var merged_value: Variant = messages.duplicate(true)
	if merge_callback.is_valid():
		merged_value = merge_callback.call(key, messages.duplicate(true))
	var opened_msec: int = GFVariantData.get_option_int(batch, "opened_msec")
	var effective_closed_msec: int = maxi(closed_msec, opened_msec)
	var report: Dictionary = {
		"batch_id": GFVariantData.get_option_int(batch, "batch_id"),
		"key": String(key),
		"reason": String(reason),
		"message_count": messages.size(),
		"messages": messages,
		"merged_value": GFVariantData.duplicate_variant(merged_value),
		"opened_msec": opened_msec,
		"closed_msec": effective_closed_msec,
		"duration_msec": effective_closed_msec - opened_msec,
	}
	batch_closed.emit(report.duplicate(true))
	return report


func _dispatch_capacity_notification(batch: Dictionary, closed_msec: int) -> void:
	if (
		_is_dispatching_capacity_notification
		or not _pending_capacity_notifications.is_empty()
		or _capacity_notification_drain_scheduled
	):
		_enqueue_capacity_notification(batch, closed_msec)
		return

	_is_dispatching_capacity_notification = true
	var _report: Dictionary = _finalize_closed_batch(
		batch,
		REASON_PENDING_LIMIT,
		closed_msec
	)
	_is_dispatching_capacity_notification = false
	_schedule_capacity_notification_drain()


func _enqueue_capacity_notification(batch: Dictionary, closed_msec: int) -> void:
	_pending_capacity_notifications.append({
		"batch": batch.duplicate(true),
		"closed_msec": closed_msec,
	})
	_schedule_capacity_notification_drain()


func _schedule_capacity_notification_drain() -> void:
	if _capacity_notification_drain_scheduled or _pending_capacity_notifications.is_empty():
		return
	_capacity_notification_drain_scheduled = true
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_run_capacity_notification_drain"))


func _run_capacity_notification_drain() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		_capacity_notification_drain_scheduled = false
		return
	var tree: SceneTree = main_loop
	await tree.process_frame
	_capacity_notification_drain_scheduled = false
	_drain_capacity_notifications()


func _drain_capacity_notifications() -> void:
	_capacity_notification_drain_scheduled = false
	if _is_dispatching_capacity_notification:
		_schedule_capacity_notification_drain()
		return

	var notification_count: int = mini(
		_pending_capacity_notifications.size(),
		_MAX_CAPACITY_NOTIFICATIONS_PER_DRAIN
	)
	_is_dispatching_capacity_notification = true
	for _index: int in range(notification_count):
		if _pending_capacity_notifications.is_empty():
			break
		var notification_entry: Dictionary = _pending_capacity_notifications.pop_front()
		var batch: Dictionary = GFVariantData.get_option_dictionary(notification_entry, "batch")
		var closed_msec: int = GFVariantData.get_option_int(notification_entry, "closed_msec")
		var _report: Dictionary = _finalize_closed_batch(
			batch,
			REASON_PENDING_LIMIT,
			closed_msec
		)
	_is_dispatching_capacity_notification = false
	_schedule_capacity_notification_drain()


func _trim_pending_batches_to_limit(closed_msec: int) -> void:
	var evicted_batches: Array[Dictionary] = []
	while _batches.size() > max_pending_batches:
		var oldest_key: StringName = _find_oldest_key()
		var evicted_batch: Dictionary = _take_batch(oldest_key)
		if evicted_batch.is_empty():
			break
		evicted_batches.append(evicted_batch)

	for evicted_batch: Dictionary in evicted_batches:
		_enqueue_capacity_notification(evicted_batch, closed_msec)


func _restart_auto_flush_timers() -> void:
	_lifecycle_serial += 1
	var keys: Array = _batches.keys()
	for key_value: Variant in keys:
		var key: StringName = GFVariantData.to_string_name(key_value)
		var batch: Dictionary = _get_batch(key)
		if not batch.is_empty():
			batch["timer_started"] = false
	if not auto_flush:
		return

	var now_msec: int = Time.get_ticks_msec()
	for key_value: Variant in keys:
		var key: StringName = GFVariantData.to_string_name(key_value)
		var batch: Dictionary = _get_batch(key)
		if batch.is_empty():
			continue
		var reason: StringName = _get_ready_reason(batch, now_msec)
		if reason != &"":
			var _report: Dictionary = _close_batch(key, reason, now_msec)
		else:
			_start_batch_timer_if_needed(key, batch)


func _get_batch_identity_snapshot() -> Array[Dictionary]:
	var remaining: Dictionary = {}
	for key_value: Variant in _batches.keys():
		var key: StringName = GFVariantData.to_string_name(key_value)
		remaining[key] = GFVariantData.get_option_int(_get_batch(key), "batch_id")

	var result: Array[Dictionary] = []
	while not remaining.is_empty():
		var found: bool = false
		var oldest_key: StringName = &""
		var oldest_batch_id: int = 0
		for key_value: Variant in remaining.keys():
			var key: StringName = GFVariantData.to_string_name(key_value)
			var batch_id: int = GFVariantData.get_option_int(remaining, key)
			if not found or batch_id < oldest_batch_id:
				found = true
				oldest_key = key
				oldest_batch_id = batch_id
		if not found:
			break
		var _erased_identity: bool = remaining.erase(oldest_key)
		result.append({
			"key": oldest_key,
			"batch_id": oldest_batch_id,
		})
	return result


func _find_oldest_key() -> StringName:
	var found: bool = false
	var oldest_key: StringName = &""
	var oldest_batch_id: int = 0
	for key_value: Variant in _batches.keys():
		var key: StringName = GFVariantData.to_string_name(key_value)
		var batch_id: int = GFVariantData.get_option_int(_get_batch(key), "batch_id")
		if not found or batch_id < oldest_batch_id:
			found = true
			oldest_key = key
			oldest_batch_id = batch_id
	return oldest_key
