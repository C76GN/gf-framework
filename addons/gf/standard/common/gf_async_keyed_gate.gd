## GFAsyncKeyedGate: 按 key 仲裁异步并发槽位。
##
## 用于把“同一个资源、槽位、存档、玩家或编辑器目标”的异步操作限制在可控并发内。
## gate 只负责排队、发放租约、释放后推进队列，以及记录取消/超时诊断；
## 不创建线程、不执行任务，也不解释 key 的业务含义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFAsyncKeyedGate
extends RefCounted


# --- 信号 ---

## 请求进入等待队列时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_id: gate 内唯一请求 ID。
## [br]
## @param key: 请求 key 副本。
## [br]
## @param metadata: 请求元数据。
## [br]
## @schema key: Variant，调用方传入的 key。
## [br]
## @schema metadata: Dictionary，调用方定义的请求上下文。
signal request_queued(request_id: int, key: Variant, metadata: Dictionary)

## 请求获得租约时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lease: 获得的租约句柄。
signal lease_acquired(lease: GFAsyncGateLease)

## 租约释放时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lease: 被释放的租约句柄。
## [br]
## @param reason: 稳定释放原因。
signal lease_released(lease: GFAsyncGateLease, reason: StringName)

## 等待请求取消时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_id: gate 内唯一请求 ID。
## [br]
## @param key: 请求 key 副本。
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @schema key: Variant，调用方传入的 key。
## [br]
## @schema metadata: Dictionary，包含取消上下文。
signal request_cancelled(request_id: int, key: Variant, reason: StringName, metadata: Dictionary)

## 等待请求超时时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_id: gate 内唯一请求 ID。
## [br]
## @param key: 请求 key 副本。
## [br]
## @param metadata: 超时上下文。
## [br]
## @schema key: Variant，调用方传入的 key。
## [br]
## @schema metadata: Dictionary，包含超时上下文。
signal request_timed_out(request_id: int, key: Variant, metadata: Dictionary)


# --- 常量 ---

## 请求已获得租约。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_ACQUIRED: StringName = &"acquired"

## 请求已进入队列。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_QUEUED: StringName = &"queued"

## 租约已释放。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_RELEASED: StringName = &"released"

## 请求已取消。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_CANCELLED: StringName = &"cancelled"

## 请求等待超时。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_TIMEOUT: StringName = &"timeout"

## 请求无效。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVALID: StringName = &"invalid"

## 默认每个 key 的并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_CONCURRENCY: int = 1

## 默认保留的最近事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_RECENT_EVENTS: int = 64


# --- 公共变量 ---

## 未显式配置 key 时的最大并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
var default_max_concurrency: int = DEFAULT_MAX_CONCURRENCY:
	set(value):
		default_max_concurrency = maxi(value, 1)
		var _pumped_count: int = _pump_all_keys()

## 最近事件历史上限。设置为 0 时不保留事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
	set(value):
		max_recent_events = maxi(value, 0)
		_trim_events()


# --- 私有变量 ---

var _queues_by_key: Dictionary = {}
var _active_by_key: Dictionary = {}
var _key_limits: Dictionary = {}
var _key_data: Dictionary = {}
var _lease_records: Dictionary = {}
var _events: Array[Dictionary] = []
var _next_request_id: int = 1
var _next_lease_id: int = 1
var _next_event_index: int = 1
var _cancelled_count: int = 0
var _timeout_count: int = 0
var _acquired_count: int = 0
var _released_count: int = 0


# --- 公共方法 ---

## 请求一个 key 的执行租约。
## [br]
## 如果当前 key 仍有并发槽位，会立即返回 acquired；否则返回 queued，并在 result 中提供
## GFAsyncCompletion。队列推进后 completion 会成功并携带 lease。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @param options: 请求选项，支持 metadata、max_concurrency、timeout_msec、lease_timeout_msec 和 cancel_token。
## [br]
## @return 请求结果字典。
## [br]
## @schema key: Variant，建议使用 String、StringName、int 或可稳定 var_to_str() 的纯数据值。
## [br]
## @schema options: Dictionary，可包含 metadata: Dictionary、max_concurrency: int、timeout_msec: int、lease_timeout_msec: int、cancel_token: GFCancelToken。
## [br]
## @schema return: Dictionary，包含 ok、status、queued、acquired、request_id、key、lease、completion、metadata 和 reason。
func request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:
	var now_msec: int = Time.get_ticks_msec()
	var _expired_waiting: int = expire_waiting_requests(now_msec)
	var _expired_active: int = expire_active_leases(now_msec)

	var key_token: String = _make_key_token(key)
	_remember_key(key_token, key)
	_apply_request_limit(key_token, options)

	var request_id: int = _take_request_id()
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var timeout_msec: int = maxi(GFVariantData.get_option_int(options, "timeout_msec", 0), 0)
	var lease_timeout_msec: int = maxi(GFVariantData.get_option_int(options, "lease_timeout_msec", 0), 0)
	var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(options, "cancel_token"))
	var request: Dictionary = {
		"request_id": request_id,
		"key_token": key_token,
		"key": GFVariantData.duplicate_variant(key),
		"completion": completion,
		"metadata": metadata.duplicate(true),
		"requested_msec": now_msec,
		"expires_at_msec": now_msec + timeout_msec if timeout_msec > 0 else 0,
		"lease_timeout_msec": lease_timeout_msec,
		"cancel_token": token,
		"cancel_callback": Callable(),
	}

	if token != null and token.is_cancelled():
		return _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			token.get_reason(),
			token.get_metadata(),
			false,
			false
		)

	if _can_activate_key(key_token):
		return _activate_request(request, now_msec, true)

	_bind_request_cancel_token(request)
	var queue: Array = _get_or_create_queue(key_token)
	queue.append(request)
	request_queued.emit(request_id, GFVariantData.duplicate_variant(key), metadata.duplicate(true))
	_record_event(&"request_queued", request, null, &"")
	return _make_request_result(STATUS_QUEUED, true, request, null, &"", true, true)


## 等待并返回租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @param options: 请求选项；wait_options 会传给 GFAsyncCompletion.wait_async()。
## [br]
## @return 获得的租约；取消、超时或失效时返回 null。
## [br]
## @schema key: Variant，建议使用 String、StringName、int 或可稳定 var_to_str() 的纯数据值。
## [br]
## @schema options: Dictionary，支持 request_lease() 选项，并可包含 wait_options: Dictionary。
func wait_for_lease_async(key: Variant, options: Dictionary = {}) -> GFAsyncGateLease:
	var request_result: Dictionary = request_lease(key, options)
	var immediate_lease: GFAsyncGateLease = _variant_to_lease(GFVariantData.get_option_value(request_result, "lease"))
	if immediate_lease != null:
		return immediate_lease

	var completion: GFAsyncCompletion = _variant_to_completion(GFVariantData.get_option_value(request_result, "completion"))
	if completion == null:
		return null

	var wait_options: Dictionary = GFVariantData.get_option_dictionary(options, "wait_options")
	var snapshot: Dictionary = await completion.wait_async(wait_options)
	var wait_status: StringName = GFVariantData.get_option_string_name(snapshot, "wait_status")
	if wait_status != &"" and wait_status != GFAsyncWaitUtility.STATUS_COMPLETED:
		var _cancelled_wait: bool = cancel_request(
			GFVariantData.get_option_int(request_result, "request_id"),
			_wait_status_to_cancel_reason(wait_status),
			{ "wait_snapshot": snapshot }
		)
		return null
	if not completion.is_successful():
		return null

	var completion_result: Dictionary = GFVariantData.as_dictionary(completion.get_result())
	return _variant_to_lease(GFVariantData.get_option_value(completion_result, "lease"))


## 释放一个租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lease: request_lease() 或 wait_for_lease_async() 返回的租约。
## [br]
## @param reason: 稳定释放原因。
## [br]
## @return 首次释放成功时返回 true。
func release_lease(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:
	if lease == null:
		return false
	return _release_lease_from_handle(lease, reason)


## 取消一个仍在等待队列中的请求。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_id: request_lease() 返回的请求 ID。
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 找到并取消等待请求时返回 true。
## [br]
## @schema metadata: Dictionary，调用方定义的取消上下文。
func cancel_request(request_id: int, reason: StringName = STATUS_CANCELLED, metadata: Dictionary = {}) -> bool:
	if request_id <= 0:
		return false
	for key_token_value: Variant in _queues_by_key.keys():
		var key_token: String = GFVariantData.to_text(key_token_value)
		var queue: Array = _get_queue(key_token)
		for index: int in range(queue.size()):
			var request: Dictionary = GFVariantData.as_dictionary(queue[index])
			if GFVariantData.get_option_int(request, "request_id") != request_id:
				continue
			var _removed: Variant = queue.pop_at(index)
			if queue.is_empty():
				var _queue_erased: bool = _queues_by_key.erase(key_token_value)
			var _result: Dictionary = _complete_waiting_request(
				request,
				STATUS_CANCELLED,
				reason,
				metadata,
				false,
				false
			)
			var _pumped_count: int = _pump_key(key_token)
			return true
	return false


## 取消全部等待请求并释放全部活跃租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 稳定清理原因。
## [br]
## @param metadata: 清理上下文。
## [br]
## @return 受影响的请求和租约数量。
## [br]
## @schema metadata: Dictionary，调用方定义的清理上下文。
func clear(reason: StringName = &"cleared", metadata: Dictionary = {}) -> int:
	var affected: int = 0
	for key_token_value: Variant in _queues_by_key.keys():
		var key_token: String = GFVariantData.to_text(key_token_value)
		var queue: Array = _get_queue(key_token)
		for request_value: Variant in queue:
			var request: Dictionary = GFVariantData.as_dictionary(request_value)
			var _result: Dictionary = _complete_waiting_request(
				request,
				STATUS_CANCELLED,
				reason,
				metadata,
				false,
				false
			)
			affected += 1
	_queues_by_key.clear()

	var leases: Array[GFAsyncGateLease] = []
	for lease_id: Variant in _lease_records.keys():
		var record: Dictionary = GFVariantData.as_dictionary(_lease_records[lease_id])
		var lease: GFAsyncGateLease = _variant_to_lease(GFVariantData.get_option_value(record, "lease"))
		if lease != null:
			leases.append(lease)
	for lease: GFAsyncGateLease in leases:
		if _release_lease_from_handle(lease, reason):
			affected += 1
	return affected


## 设置某个 key 的最大并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @param max_concurrency: 最大并发槽位数；小于 1 时按 1 处理。
## [br]
## @return 归一化后的并发槽位数。
## [br]
## @schema key: Variant，调用方传入的 key。
func set_key_max_concurrency(key: Variant, max_concurrency: int) -> int:
	var key_token: String = _make_key_token(key)
	_remember_key(key_token, key)
	var safe_limit: int = maxi(max_concurrency, 1)
	_key_limits[key_token] = safe_limit
	var _pumped_count: int = _pump_key(key_token)
	return safe_limit


## 获取某个 key 的最大并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @return 当前 key 的最大并发槽位数。
## [br]
## @schema key: Variant，调用方传入的 key。
func get_key_max_concurrency(key: Variant) -> int:
	return _get_key_limit(_make_key_token(key))


## 过期等待队列中已取消或超时的请求。
## [br]
## 该方法不会创建计时器；适合由调用方在帧循环、工具刷新或关键操作边界显式调用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param now_msec: 参考时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 本次过期的等待请求数量。
func expire_waiting_requests(now_msec: int = -1) -> int:
	var now: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var expired_count: int = 0
	for key_token_value: Variant in _queues_by_key.keys():
		var key_token: String = GFVariantData.to_text(key_token_value)
		var queue: Array = _get_queue(key_token)
		var kept: Array = []
		for request_value: Variant in queue:
			var request: Dictionary = GFVariantData.as_dictionary(request_value)
			var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(request, "cancel_token"))
			if token != null and token.is_cancelled():
				var _cancel_result: Dictionary = _complete_waiting_request(
					request,
					STATUS_CANCELLED,
					token.get_reason(),
					token.get_metadata(),
					false,
					false
				)
				expired_count += 1
				continue

			var expires_at_msec: int = GFVariantData.get_option_int(request, "expires_at_msec")
			if expires_at_msec > 0 and now >= expires_at_msec:
				var _timeout_result: Dictionary = _complete_waiting_request(
					request,
					STATUS_TIMEOUT,
					STATUS_TIMEOUT,
					{ "now_msec": now, "expires_at_msec": expires_at_msec },
					true,
					false
				)
				expired_count += 1
				continue

			kept.append(request)

		if kept.is_empty():
			var _queue_erased: bool = _queues_by_key.erase(key_token_value)
		else:
			_queues_by_key[key_token] = kept

	if expired_count > 0:
		var _pumped_count: int = _pump_all_keys()
	return expired_count


## 释放已超过 lease_timeout_msec 的活跃租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param now_msec: 参考时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 本次释放的活跃租约数量。
func expire_active_leases(now_msec: int = -1) -> int:
	var now: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var expired_leases: Array[GFAsyncGateLease] = []
	for lease_id: Variant in _lease_records.keys():
		var record: Dictionary = GFVariantData.as_dictionary(_lease_records[lease_id])
		var expires_at_msec: int = GFVariantData.get_option_int(record, "expires_at_msec")
		if expires_at_msec <= 0 or now < expires_at_msec:
			continue
		var lease: GFAsyncGateLease = _variant_to_lease(GFVariantData.get_option_value(record, "lease"))
		if lease != null:
			expired_leases.append(lease)

	var released_count: int = 0
	for lease: GFAsyncGateLease in expired_leases:
		if _release_lease_from_handle(lease, STATUS_TIMEOUT):
			released_count += 1
	return released_count


## 判断某个 key 当前是否存在等待或活跃租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @return 存在等待请求或活跃租约时返回 true。
## [br]
## @schema key: Variant，调用方传入的 key。
func has_key_activity(key: Variant) -> bool:
	var key_token: String = _make_key_token(key)
	return _get_queue(key_token).size() > 0 or _get_active_leases(key_token).size() > 0


## 获取某个 key 的状态快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @return key 状态快照。
## [br]
## @schema key: Variant，调用方传入的 key。
## [br]
## @schema return: Dictionary，包含 key、queued_count、active_count、max_concurrency、waiting_request_ids、active_lease_ids 和 metadata。
func get_key_snapshot(key: Variant) -> Dictionary:
	var key_token: String = _make_key_token(key)
	return _get_key_snapshot_by_token(key_token)


## 获取最近 gate 事件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最近事件数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 event_index、event_type、request_id、lease_id、key、reason 和 timestamp_msec。
func get_recent_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _events:
		result.append(event.duplicate(true))
	return result


## 获取 gate 调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return gate 状态快照。
## [br]
## @schema return: Dictionary，包含 queued_count、active_count、key_count、acquired_count、released_count、cancelled_count、timeout_count、keys 和 recent_events。
func get_debug_snapshot() -> Dictionary:
	var key_snapshots: Array[Dictionary] = []
	for key_token_value: Variant in _collect_key_tokens():
		key_snapshots.append(_get_key_snapshot_by_token(GFVariantData.to_text(key_token_value)))
	return {
		"default_max_concurrency": default_max_concurrency,
		"queued_count": _get_total_queued_count(),
		"active_count": _get_total_active_count(),
		"key_count": key_snapshots.size(),
		"acquired_count": _acquired_count,
		"released_count": _released_count,
		"cancelled_count": _cancelled_count,
		"timeout_count": _timeout_count,
		"keys": key_snapshots,
		"recent_events": get_recent_events(),
	}


# --- 私有/辅助方法 ---

func _activate_request(request: Dictionary, now_msec: int, include_completion: bool) -> Dictionary:
	_disconnect_request_cancel_token(request)

	var key_token: String = GFVariantData.get_option_string(request, "key_token")
	var key: Variant = GFVariantData.get_option_value(request, "key")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(request, "metadata")
	var request_id: int = GFVariantData.get_option_int(request, "request_id")
	var lease_id: int = _take_lease_id()
	var lease_timeout_msec: int = GFVariantData.get_option_int(request, "lease_timeout_msec")
	var expires_at_msec: int = now_msec + lease_timeout_msec if lease_timeout_msec > 0 else 0
	var lease: GFAsyncGateLease = GFAsyncGateLease.new()
	var _configured: GFAsyncGateLease = lease.configure_from_gate(
		lease_id,
		request_id,
		key,
		metadata,
		Callable(self, "_release_lease_from_handle")
	)

	var active: Array = _get_or_create_active(key_token)
	active.append(lease)
	_lease_records[lease_id] = {
		"lease": lease,
		"lease_id": lease_id,
		"request_id": request_id,
		"key_token": key_token,
		"key": GFVariantData.duplicate_variant(key),
		"metadata": metadata.duplicate(true),
		"acquired_msec": now_msec,
		"expires_at_msec": expires_at_msec,
	}
	_acquired_count += 1

	var result: Dictionary = _make_request_result(STATUS_ACQUIRED, true, request, lease, &"", include_completion, true)
	var completion: GFAsyncCompletion = _variant_to_completion(GFVariantData.get_option_value(request, "completion"))
	if completion != null and completion.is_pending():
		var completion_result: Dictionary = _make_request_result(STATUS_ACQUIRED, true, request, lease, &"", false, true)
		var _completed: bool = completion.succeed(completion_result)

	lease_acquired.emit(lease)
	_record_event(&"lease_acquired", request, lease, &"")
	return result


func _release_lease_from_handle(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:
	if lease == null:
		return false
	var lease_id: int = lease.get_lease_id()
	if not _lease_records.has(lease_id):
		return false

	var record: Dictionary = GFVariantData.as_dictionary(_lease_records[lease_id])
	var key_token: String = GFVariantData.get_option_string(record, "key_token")
	var safe_reason: StringName = reason if reason != &"" else &"manual"
	_remove_active_lease(key_token, lease_id)
	var _record_erased: bool = _lease_records.erase(lease_id)
	var _marked: bool = lease._mark_released_from_gate(safe_reason)
	_released_count += 1
	lease_released.emit(lease, safe_reason)
	_record_event(&"lease_released", record, lease, safe_reason)
	var _pumped_count: int = _pump_key(key_token)
	return true


func _pump_all_keys() -> int:
	var activated_count: int = 0
	for key_token_value: Variant in _collect_key_tokens():
		activated_count += _pump_key(GFVariantData.to_text(key_token_value))
	return activated_count


func _pump_key(key_token: String) -> int:
	var now_msec: int = Time.get_ticks_msec()
	var activated_count: int = 0
	var queue: Array = _get_queue(key_token)
	while not queue.is_empty() and _can_activate_key(key_token):
		var request_value: Variant = queue.pop_front()
		var request: Dictionary = GFVariantData.as_dictionary(request_value)
		var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(request, "cancel_token"))
		if token != null and token.is_cancelled():
			var _cancel_result: Dictionary = _complete_waiting_request(
				request,
				STATUS_CANCELLED,
				token.get_reason(),
				token.get_metadata(),
				false,
				false
			)
			continue
		var expires_at_msec: int = GFVariantData.get_option_int(request, "expires_at_msec")
		if expires_at_msec > 0 and now_msec >= expires_at_msec:
			var _timeout_result: Dictionary = _complete_waiting_request(
				request,
				STATUS_TIMEOUT,
				STATUS_TIMEOUT,
				{ "now_msec": now_msec, "expires_at_msec": expires_at_msec },
				true,
				false
			)
			continue
		var _result: Dictionary = _activate_request(request, now_msec, false)
		activated_count += 1

	if queue.is_empty():
		var _queue_erased: bool = _queues_by_key.erase(key_token)
	else:
		_queues_by_key[key_token] = queue
	return activated_count


func _complete_waiting_request(
	request: Dictionary,
	status: StringName,
	reason: StringName,
	metadata: Dictionary,
	timed_out: bool,
	include_completion: bool
) -> Dictionary:
	_disconnect_request_cancel_token(request)
	var safe_status: StringName = status if status != &"" else STATUS_CANCELLED
	var safe_reason: StringName = reason if reason != &"" else safe_status
	var completion: GFAsyncCompletion = _variant_to_completion(GFVariantData.get_option_value(request, "completion"))
	var completion_metadata: Dictionary = GFVariantData.get_option_dictionary(request, "metadata")
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(completion_metadata, metadata, true, true)
	var result: Dictionary = _make_request_result(safe_status, false, request, null, safe_reason, include_completion, false)
	result["metadata"] = completion_metadata.duplicate(true)
	result["reason"] = safe_reason

	if timed_out:
		_timeout_count += 1
		if completion != null and completion.is_pending():
			var _timeout_completed: bool = completion.cancel(STATUS_TIMEOUT, _merged_metadata)
		request_timed_out.emit(
			GFVariantData.get_option_int(request, "request_id"),
			GFVariantData.duplicate_variant(GFVariantData.get_option_value(request, "key")),
			_merged_metadata.duplicate(true)
		)
		_record_event(&"request_timed_out", request, null, safe_reason)
	else:
		_cancelled_count += 1
		if completion != null and completion.is_pending():
			var _cancel_completed: bool = completion.cancel(safe_reason, _merged_metadata)
		request_cancelled.emit(
			GFVariantData.get_option_int(request, "request_id"),
			GFVariantData.duplicate_variant(GFVariantData.get_option_value(request, "key")),
			safe_reason,
			_merged_metadata.duplicate(true)
		)
		_record_event(&"request_cancelled", request, null, safe_reason)

	return result


func _make_request_result(
	status: StringName,
	ok: bool,
	request: Dictionary,
	lease: GFAsyncGateLease,
	reason: StringName,
	include_completion: bool,
	include_lease: bool
) -> Dictionary:
	var completion: GFAsyncCompletion = _variant_to_completion(GFVariantData.get_option_value(request, "completion"))
	var result: Dictionary = {
		"ok": ok,
		"status": status,
		"queued": status == STATUS_QUEUED,
		"acquired": status == STATUS_ACQUIRED,
		"request_id": GFVariantData.get_option_int(request, "request_id"),
		"key": GFVariantData.duplicate_variant(GFVariantData.get_option_value(request, "key")),
		"metadata": GFVariantData.get_option_dictionary(request, "metadata"),
		"reason": reason,
	}
	if include_lease:
		result["lease"] = lease
	if include_completion:
		result["completion"] = completion
	return result


func _bind_request_cancel_token(request: Dictionary) -> void:
	var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(request, "cancel_token"))
	if token == null:
		return
	var request_id: int = GFVariantData.get_option_int(request, "request_id")
	var callback: Callable = func(reason: StringName, metadata: Dictionary) -> void:
		var _cancelled: bool = cancel_request(request_id, reason, metadata)
	request["cancel_callback"] = callback
	var connect_error: Error = token.cancelled.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error
	if connect_error != OK:
		request["cancel_callback"] = Callable()


func _disconnect_request_cancel_token(request: Dictionary) -> void:
	var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(request, "cancel_token"))
	var callback: Callable = _variant_to_callable(GFVariantData.get_option_value(request, "cancel_callback"))
	if token != null and callback.is_valid() and token.cancelled.is_connected(callback):
		token.cancelled.disconnect(callback)
	request["cancel_callback"] = Callable()


func _apply_request_limit(key_token: String, options: Dictionary) -> void:
	var limit: int = GFVariantData.get_option_int(options, "max_concurrency", 0)
	if limit > 0:
		_key_limits[key_token] = maxi(limit, 1)


func _can_activate_key(key_token: String) -> bool:
	return _get_active_leases(key_token).size() < _get_key_limit(key_token)


func _get_key_limit(key_token: String) -> int:
	if _key_limits.has(key_token):
		return maxi(GFVariantData.to_int(_key_limits[key_token], default_max_concurrency), 1)
	return default_max_concurrency


func _remember_key(key_token: String, key: Variant) -> void:
	if _key_data.has(key_token):
		return
	_key_data[key_token] = {
		"key": GFVariantData.duplicate_variant(key),
		"key_token": key_token,
	}


func _get_queue(key_token: String) -> Array:
	if not _queues_by_key.has(key_token):
		return []
	var value: Variant = _queues_by_key[key_token]
	if value is Array:
		var queue: Array = value
		return queue
	return []


func _get_or_create_queue(key_token: String) -> Array:
	if not _queues_by_key.has(key_token):
		_queues_by_key[key_token] = []
	var value: Variant = _queues_by_key[key_token]
	if value is Array:
		var queue: Array = value
		return queue
	var new_queue: Array = []
	_queues_by_key[key_token] = new_queue
	return new_queue


func _get_active_leases(key_token: String) -> Array:
	if not _active_by_key.has(key_token):
		return []
	var value: Variant = _active_by_key[key_token]
	if value is Array:
		var active: Array = value
		return active
	return []


func _get_or_create_active(key_token: String) -> Array:
	if not _active_by_key.has(key_token):
		_active_by_key[key_token] = []
	var value: Variant = _active_by_key[key_token]
	if value is Array:
		var active: Array = value
		return active
	var new_active: Array = []
	_active_by_key[key_token] = new_active
	return new_active


func _remove_active_lease(key_token: String, lease_id: int) -> void:
	var active: Array = _get_active_leases(key_token)
	for index: int in range(active.size()):
		var lease: GFAsyncGateLease = _variant_to_lease(active[index])
		if lease != null and lease.get_lease_id() == lease_id:
			var _removed: Variant = active.pop_at(index)
			break
	if active.is_empty():
		var _active_erased: bool = _active_by_key.erase(key_token)
	else:
		_active_by_key[key_token] = active


func _get_key_snapshot_by_token(key_token: String) -> Dictionary:
	var key_record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_key_data, key_token, {}))
	var key: Variant = GFVariantData.get_option_value(key_record, "key")
	var queue: Array = _get_queue(key_token)
	var active: Array = _get_active_leases(key_token)
	var waiting_request_ids: Array[int] = []
	for request_value: Variant in queue:
		var request: Dictionary = GFVariantData.as_dictionary(request_value)
		waiting_request_ids.append(GFVariantData.get_option_int(request, "request_id"))
	var active_lease_ids: Array[int] = []
	for lease_value: Variant in active:
		var lease: GFAsyncGateLease = _variant_to_lease(lease_value)
		if lease != null:
			active_lease_ids.append(lease.get_lease_id())
	return {
		"key_token": key_token,
		"key": GFVariantData.duplicate_variant(key),
		"queued_count": queue.size(),
		"active_count": active.size(),
		"max_concurrency": _get_key_limit(key_token),
		"waiting_request_ids": waiting_request_ids,
		"active_lease_ids": active_lease_ids,
	}


func _collect_key_tokens() -> Array:
	var result: Array = []
	for source: Dictionary in [_key_data, _queues_by_key, _active_by_key, _key_limits]:
		for key_token: Variant in source.keys():
			if not result.has(key_token):
				result.append(key_token)
	return result


func _get_total_queued_count() -> int:
	var count: int = 0
	for key_token: Variant in _queues_by_key.keys():
		count += _get_queue(GFVariantData.to_text(key_token)).size()
	return count


func _get_total_active_count() -> int:
	var count: int = 0
	for key_token: Variant in _active_by_key.keys():
		count += _get_active_leases(GFVariantData.to_text(key_token)).size()
	return count


func _record_event(event_type: StringName, source: Dictionary, lease: GFAsyncGateLease, reason: StringName) -> void:
	if max_recent_events <= 0:
		return
	var key: Variant = GFVariantData.get_option_value(source, "key")
	var event: Dictionary = {
		"event_index": _next_event_index,
		"event_type": event_type,
		"request_id": GFVariantData.get_option_int(source, "request_id"),
		"lease_id": lease.get_lease_id() if lease != null else GFVariantData.get_option_int(source, "lease_id"),
		"key": GFVariantData.duplicate_variant(key),
		"key_token": GFVariantData.get_option_string(source, "key_token", _make_key_token(key)),
		"reason": reason,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	_next_event_index += 1
	_events.append(event)
	_trim_events()


func _trim_events() -> void:
	while _events.size() > max_recent_events:
		_events.pop_front()


func _take_request_id() -> int:
	var result: int = _next_request_id
	_next_request_id += 1
	return result


func _take_lease_id() -> int:
	var result: int = _next_lease_id
	_next_lease_id += 1
	return result


func _make_key_token(key: Variant) -> String:
	return "%s:%s" % [type_string(typeof(key)), var_to_str(key)]


func _variant_to_cancel_token(value: Variant) -> GFCancelToken:
	if value is GFCancelToken:
		var token: GFCancelToken = value
		return token
	return null


func _variant_to_completion(value: Variant) -> GFAsyncCompletion:
	if value is GFAsyncCompletion:
		var completion: GFAsyncCompletion = value
		return completion
	return null


func _variant_to_lease(value: Variant) -> GFAsyncGateLease:
	if value is GFAsyncGateLease:
		var lease: GFAsyncGateLease = value
		return lease
	return null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()


func _wait_status_to_cancel_reason(wait_status: StringName) -> StringName:
	if wait_status == GFAsyncWaitUtility.STATUS_TIMEOUT:
		return STATUS_TIMEOUT
	if wait_status == GFAsyncWaitUtility.STATUS_INVALID:
		return STATUS_INVALID
	if wait_status == GFAsyncWaitUtility.STATUS_CANCELLED:
		return STATUS_CANCELLED
	return wait_status if wait_status != &"" else STATUS_CANCELLED
