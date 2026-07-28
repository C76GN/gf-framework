## GFAsyncKeyedGate: 按 key 仲裁异步并发槽位。
##
## 用于把“同一个资源、槽位、存档、玩家或编辑器目标”的异步操作限制在可控并发内。
## gate 只负责排队、发放租约、释放后推进队列，以及记录取消/超时诊断；
## 全局槽位按稳定 key 游标轮转，持续繁忙的 key 不会永久阻塞其它 key；
## 不创建线程、不执行任务，也不解释 key 的业务含义。全部入口只允许在主线程调用；
## 跨线程请求应先通过 GFMainThreadDispatchQueue 回到主线程。
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

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")
const _STATUS_WRONG_THREAD: StringName = &"wrong_thread"

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

## 请求因等待队列或 key 容量耗尽而被拒绝。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_REJECTED: StringName = &"rejected"

## 默认每个 key 的并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_CONCURRENCY: int = 1

## 每个 key 最多允许配置的并发槽位数。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_CONCURRENCY: int = 4096

## 默认保留的最近事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_RECENT_EVENTS: int = 64

## 最近事件历史的绝对数量上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_RECENT_EVENTS: int = 4096

## 默认最多同时持有的 lease 总数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_ACTIVE_LEASES: int = 4096

## 同时持有 lease 的绝对数量上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_ACTIVE_LEASES: int = 65_536

## 默认最多保留的等待请求总数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_WAITING_REQUESTS: int = 1024

## 等待请求总数的绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_WAITING_REQUESTS: int = 65_536

## 默认每个 key 最多保留的等待请求数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_WAITING_PER_KEY: int = 64

## 单 key 等待请求数的绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_WAITING_PER_KEY: int = 4096

## 默认最多跟踪的活跃、等待或显式配置 key 数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_TRACKED_KEYS: int = 256

## tracked key 数量的绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_TRACKED_KEYS: int = 16_384

## 默认每次队列推进最多处理的等待请求数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_PUMP_WORK_ITEMS: int = 256

## 单次队列推进工作预算的绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_PUMP_WORK_ITEMS: int = 4096

## 等待请求总容量耗尽原因。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_MAX_WAITING_REQUESTS: StringName = &"max_waiting_requests"

## 单 key 等待容量耗尽原因。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_MAX_WAITING_PER_KEY: StringName = &"max_waiting_per_key"

## key 跟踪容量耗尽原因。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_MAX_TRACKED_KEYS: StringName = &"max_tracked_keys"

## 取消令牌订阅建立失败原因。
## [br]
## @api public
## [br]
## @since 10.0.0
const REASON_CANCEL_TOKEN_CONNECT_FAILED: StringName = &"cancel_token_connect_failed"


# --- 公共变量 ---

## 未显式配置 key 时的最大并发槽位数。
## [br]
## @api public
## [br]
## @since 7.0.0
var default_max_concurrency: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_default_max_concurrency = clampi(
			value,
			1,
			ABSOLUTE_MAX_CONCURRENCY
		)
		var _pumped_count: int = _pump_all_keys()
	get:
		if not Thread.is_main_thread():
			return 0
		return _default_max_concurrency

## 最近事件历史上限。设置为 0 时不保留事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_recent_events: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_recent_events = clampi(
			value,
			0,
			ABSOLUTE_MAX_RECENT_EVENTS
		)
		_trim_events()
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_recent_events

## 最多同时持有的 lease 总数。降低容量不会撤销现有 lease。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_active_leases: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_active_leases = clampi(
			value,
			1,
			ABSOLUTE_MAX_ACTIVE_LEASES
		)
		var _pumped_count: int = _pump_all_keys()
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_active_leases

## 最多保留的等待请求总数。降低容量不会驱逐现有请求。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_waiting_requests: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_waiting_requests = clampi(
			value,
			1,
			ABSOLUTE_MAX_WAITING_REQUESTS
		)
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_waiting_requests

## 每个 key 最多保留的等待请求数。降低容量不会驱逐现有请求。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_waiting_per_key: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_waiting_per_key = clampi(
			value,
			1,
			ABSOLUTE_MAX_WAITING_PER_KEY
		)
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_waiting_per_key

## 最多跟踪的活跃、等待或显式配置 key 数。降低容量不会驱逐现有 key。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_tracked_keys: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_tracked_keys = clampi(
			value,
			1,
			ABSOLUTE_MAX_TRACKED_KEYS
		)
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_tracked_keys

## 每次队列推进最多处理的等待请求数量。
## 取消和超时请求也会消耗该预算，剩余可执行工作会延迟到后续主线程迭代。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_pump_work_items: int:
	set(value):
		if not Thread.is_main_thread():
			return
		_max_pump_work_items = clampi(
			value,
			1,
			ABSOLUTE_MAX_PUMP_WORK_ITEMS
		)
		var _pumped_count: int = _pump_all_keys()
	get:
		if not Thread.is_main_thread():
			return 0
		return _max_pump_work_items


# --- 私有变量 ---

var _queue_states_by_key: Dictionary = {}
var _request_records: Dictionary = {}
var _cancel_token_states: Dictionary = {}
var _active_by_key: Dictionary = {}
var _active_limit_counts_by_key: Dictionary = {}
var _active_min_limit_by_key: Dictionary = {}
var _key_limits: Dictionary = {}
var _key_data: Dictionary = {}
var _key_slots: Array[String] = []
var _free_key_slots: Array[int] = []
var _key_slot_by_token: Dictionary = {}
var _lease_records: Dictionary = {}
var _waiting_request_slots: Array[int] = []
var _free_waiting_request_slots: Array[int] = []
var _waiting_slot_by_request_id: Dictionary = {}
var _waiting_expire_cursor: int = 0
var _active_lease_slots: Array[int] = []
var _free_active_lease_slots: Array[int] = []
var _active_slot_by_lease_id: Dictionary = {}
var _active_expire_cursor: int = 0
var _events: Array[Dictionary] = []
var _event_start_index: int = 0
var _default_max_concurrency: int = DEFAULT_MAX_CONCURRENCY
var _max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS
var _max_active_leases: int = DEFAULT_MAX_ACTIVE_LEASES
var _max_waiting_requests: int = DEFAULT_MAX_WAITING_REQUESTS
var _max_waiting_per_key: int = DEFAULT_MAX_WAITING_PER_KEY
var _max_tracked_keys: int = DEFAULT_MAX_TRACKED_KEYS
var _max_pump_work_items: int = DEFAULT_MAX_PUMP_WORK_ITEMS
var _next_request_id: int = 1
var _next_lease_id: int = 1
var _next_event_index: int = 1
var _pump_key_cursor: int = 0
var _pump_in_progress: bool = false
var _notification_depth: int = 0
var _notification_cutoffs: Array[int] = []
var _lifecycle_batch_depth: int = 0
var _pending_releases: Dictionary = {}
var _pending_release_order: Array[int] = []
var _draining_pending_releases: bool = false
var _pending_pump_cutoff: int = 0
var _deferred_pump_scheduled: bool = false
var _pump_dirty: bool = false
var _pump_scan_remaining_keys: int = 0
var _pump_cycle_progress_count: int = 0
var _pump_snapshot_request_cutoff: int = 0
var _pump_followup_requested: bool = false
var _queued_count: int = 0
var _cancelled_count: int = 0
var _timeout_count: int = 0
var _acquired_count: int = 0
var _released_count: int = 0
var _high_watermark: int = 0
var _key_high_watermark: int = 0
var _rejected_count: int = 0
var _dropped_count: int = 0


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
## @param options: 请求选项，支持 metadata、max_concurrency、timeout_msec、lease_timeout_msec 和 cancel_token。max_concurrency 只约束当前请求，不会写入持久 key 配置。
## [br]
## @return 请求结果字典。
## [br]
## @schema key: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
## [br]
## @schema options: Dictionary，可包含 metadata: Dictionary、max_concurrency: int、timeout_msec: int、lease_timeout_msec: int、cancel_token: GFCancellationToken。
## [br]
## @schema return: Dictionary，包含 ok、status、queued、acquired、request_id、key、lease、completion、metadata 和 reason。
func request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread():
		return _make_wrong_thread_request_result()
	var now_msec: int = Time.get_ticks_msec()

	var key_report: Dictionary = _GF_VARIANT_KEY_CODEC_SCRIPT.try_make_key_token(key)
	if not GFVariantData.get_option_bool(key_report, "ok"):
		return _make_invalid_key_result(key, key_report)
	var key_token: String = GFVariantData.get_option_string(key_report, "key_token")

	var request_id: int = _take_request_id()
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var timeout_msec: int = maxi(GFVariantData.get_option_int(options, "timeout_msec", 0), 0)
	var lease_timeout_msec: int = maxi(GFVariantData.get_option_int(options, "lease_timeout_msec", 0), 0)
	var request_max_concurrency: int = _get_request_max_concurrency(options)
	var token: GFCancellationToken = _variant_to_cancel_token(GFVariantData.get_option_value(options, "cancel_token"))
	var request: Dictionary = {
		"request_id": request_id,
		"key_token": key_token,
		"key": GFVariantData.duplicate_variant(key),
		"completion": completion,
		"metadata": metadata.duplicate(true),
		"requested_msec": now_msec,
		"expires_at_msec": now_msec + timeout_msec if timeout_msec > 0 else 0,
		"lease_timeout_msec": lease_timeout_msec,
		"max_concurrency": request_max_concurrency,
		"cancel_token": token,
		"cancel_token_id": 0,
		"cancel_callback": Callable(),
		"cancel_observed": false,
		"location": &"inflight",
		"queue_previous_request_id": 0,
		"queue_next_request_id": 0,
	}

	if token != null and token.is_cancel_requested():
		return _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			token.get_cancel_reason(),
			token.get_cancel_metadata(),
			false,
			false
		)

	if not _is_key_tracked(key_token) and _key_data.size() >= _max_tracked_keys:
		return _make_rejected_request_result(
			request,
			REASON_MAX_TRACKED_KEYS,
			&"key"
		)

	_remember_key(key_token, key)
	_update_key_high_watermark()
	_request_records[request_id] = request
	if not _bind_request_cancel_token(request):
		_forget_request_record(request)
		_prune_key_if_transient(key_token)
		var invalid_result: Dictionary = _make_request_result(
			STATUS_INVALID,
			false,
			request,
			null,
			REASON_CANCEL_TOKEN_CONNECT_FAILED,
			false,
			false
		)
		_record_event(
			&"request_invalid",
			request,
			null,
			REASON_CANCEL_TOKEN_CONNECT_FAILED
		)
		return invalid_result
	if _request_has_observed_cancellation(request):
		_prune_key_if_transient(key_token)
		return _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			_get_request_cancel_reason(request),
			_get_request_cancel_metadata(request),
			false,
			false
		)

	if (
		not _pump_in_progress
		and _notification_depth <= 0
		and _get_queue_size(key_token) <= 0
		and _can_activate_request(key_token, request)
	):
		return _activate_request(request, now_msec, true)

	if _get_queue_size(key_token) >= _max_waiting_per_key:
		_forget_request_record(request)
		var per_key_rejected: Dictionary = _make_rejected_request_result(
			request,
			REASON_MAX_WAITING_PER_KEY,
			&"per_key"
		)
		_prune_key_if_transient(key_token)
		return per_key_rejected
	if _queued_count >= _max_waiting_requests:
		_forget_request_record(request)
		var total_rejected: Dictionary = _make_rejected_request_result(
			request,
			REASON_MAX_WAITING_REQUESTS,
			&"total"
		)
		_prune_key_if_transient(key_token)
		return total_rejected

	_enqueue_waiting_request(request)
	_high_watermark = maxi(_high_watermark, _queued_count)
	if _pump_in_progress or _notification_depth > 0:
		_pump_dirty = true
		_pump_followup_requested = true
	_record_event(&"request_queued", request, null, &"")
	var queued_result: Dictionary = _make_request_result(
		STATUS_QUEUED,
		true,
		request,
		null,
		&"",
		true,
		true
	)
	_begin_notification(request_id)
	request_queued.emit(
		request_id,
		GFVariantData.duplicate_variant(key),
		metadata.duplicate(true)
	)
	_end_notification()
	var terminal_result: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"terminal_result"
	)
	if not terminal_result.is_empty():
		return terminal_result.duplicate(true)
	return queued_result


## 等待并返回租约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @param options: 请求选项；wait_options 会传给 GFAsyncWaitUtility.wait_completion_async()。
## [br]
## @return 获得的租约；取消、超时或失效时返回 null。
## [br]
## @schema key: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
## [br]
## @schema options: Dictionary，支持 request_lease() 选项，并可包含 wait_options: Dictionary。
func wait_for_lease_async(key: Variant, options: Dictionary = {}) -> GFAsyncGateLease:
	if not Thread.is_main_thread():
		return null
	var request_result: Dictionary = request_lease(key, options)
	var immediate_lease: GFAsyncGateLease = _variant_to_lease(GFVariantData.get_option_value(request_result, "lease"))
	if immediate_lease != null:
		return immediate_lease

	var completion: GFAsyncCompletion = _variant_to_completion(GFVariantData.get_option_value(request_result, "completion"))
	if completion == null:
		return null

	var wait_options: Dictionary = GFVariantData.get_option_dictionary(options, "wait_options")
	var snapshot: Dictionary = await GFAsyncWaitUtility.wait_completion_async(completion, wait_options)
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
## acquire/release 生命周期通知中的重入释放会延迟到最外层通知结束；通知期间的新请求
## 只能排队，随后与既有 waiter 一起由公平泵推进。
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
	if not Thread.is_main_thread():
		return false
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
	if not Thread.is_main_thread():
		return false
	return _cancel_request_on_main_thread(request_id, reason, metadata, false)


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
	if not Thread.is_main_thread():
		return 0
	_begin_lifecycle_batch()
	var detached_requests: Array[Dictionary] = (
		_detach_all_waiting_requests()
	)
	var leases: Array[GFAsyncGateLease] = _collect_active_leases()

	for request: Dictionary in detached_requests:
		var _result: Dictionary = _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			reason,
			metadata,
			false,
			false
		)
	var release_cutoff: int = _next_request_id - 1
	var _batch_released_count: int = _release_leases_without_pump(
		leases,
		reason,
		release_cutoff
	)
	_end_lifecycle_batch_and_flush(release_cutoff, false)
	return detached_requests.size() + leases.size()


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
	if not Thread.is_main_thread():
		return 0
	var key_token: String = _make_key_token(key)
	if key_token.is_empty():
		return 0
	if not _is_key_tracked(key_token) and _key_data.size() >= _max_tracked_keys:
		_rejected_count += 1
		return 0
	_remember_key(key_token, key)
	_update_key_high_watermark()
	var safe_limit: int = clampi(
		max_concurrency,
		1,
		ABSOLUTE_MAX_CONCURRENCY
	)
	_key_limits[key_token] = safe_limit
	var _pumped_count: int = _pump_all_keys()
	return safe_limit


## 清理某个 key 的显式最大并发槽位配置。
## [br]
## 清理后该 key 会回到 default_max_concurrency；如果该 key 没有队列或活跃租约，会被从快照中裁剪。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param key: 并发仲裁 key。
## [br]
## @return 找到并清理显式配置时返回 true。
## [br]
## @schema key: Variant，调用方传入的 key。
func clear_key_max_concurrency(key: Variant) -> bool:
	if not Thread.is_main_thread():
		return false
	var key_token: String = _make_key_token(key)
	if key_token.is_empty() or not _key_limits.has(key_token):
		return false
	var _erased: bool = _key_limits.erase(key_token)
	var _pumped_count: int = _pump_all_keys()
	_prune_key_if_transient(key_token)
	return true


## 清理全部显式 key 最大并发槽位配置。
## [br]
## 清理后空闲 key 会从快照中裁剪，有等待队列的 key 会按 default_max_concurrency 继续推进。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被清理的显式配置数量。
func clear_all_key_max_concurrency() -> int:
	if not Thread.is_main_thread():
		return 0
	var key_tokens: Array = _key_limits.keys()
	_key_limits.clear()
	for key_token_value: Variant in key_tokens:
		var key_token: String = GFVariantData.to_text(key_token_value)
		_prune_key_if_transient(key_token)
	var _pumped_count: int = _pump_all_keys()
	return key_tokens.size()


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
	if not Thread.is_main_thread():
		return 0
	var key_token: String = _make_key_token(key)
	if key_token.is_empty():
		return 0
	return _get_key_limit(key_token)


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
	if not Thread.is_main_thread():
		return 0
	var now: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var expired_requests: Array[Dictionary] = []
	var expired_statuses: Array[StringName] = []
	var expired_reasons: Array[StringName] = []
	var expired_metadata: Array[Dictionary] = []
	var expired_as_timeout: Array[bool] = []
	var slot_count: int = _waiting_request_slots.size()
	if slot_count <= 0:
		_waiting_expire_cursor = 0
		return 0
	if _waiting_expire_cursor < 0 or _waiting_expire_cursor >= slot_count:
		_waiting_expire_cursor = 0
	var work_count: int = mini(_max_pump_work_items, slot_count)
	_begin_lifecycle_batch()
	for _work_index: int in range(work_count):
		var slot_index: int = _waiting_expire_cursor
		_waiting_expire_cursor = (_waiting_expire_cursor + 1) % slot_count
		var request_id: int = _waiting_request_slots[slot_index]
		if request_id <= 0:
			continue
		var request: Dictionary = _get_request_record(request_id)
		if (
			request.is_empty()
			or GFVariantData.get_option_string_name(
				request,
				"location"
			) != &"queued"
		):
			continue
		if _request_has_observed_cancellation(request):
			var _detached_cancelled: bool = _detach_waiting_request(request)
			expired_requests.append(request)
			expired_statuses.append(STATUS_CANCELLED)
			expired_reasons.append(_get_request_cancel_reason(request))
			expired_metadata.append(_get_request_cancel_metadata(request))
			expired_as_timeout.append(false)
			continue
		var expires_at_msec: int = GFVariantData.get_option_int(
			request,
			"expires_at_msec"
		)
		if expires_at_msec <= 0 or now < expires_at_msec:
			continue
		var _detached_expired: bool = _detach_waiting_request(request)
		expired_requests.append(request)
		expired_statuses.append(STATUS_TIMEOUT)
		expired_reasons.append(STATUS_TIMEOUT)
		expired_metadata.append({
			"now_msec": now,
			"expires_at_msec": expires_at_msec,
		})
		expired_as_timeout.append(true)

	for index: int in range(expired_requests.size()):
		var _completion_result: Dictionary = _complete_waiting_request(
			expired_requests[index],
			expired_statuses[index],
			expired_reasons[index],
			expired_metadata[index],
			expired_as_timeout[index],
			false
		)
	_end_lifecycle_batch_and_flush()
	return expired_requests.size()


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
	if not Thread.is_main_thread():
		return 0
	var now: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var slot_count: int = _active_lease_slots.size()
	if slot_count <= 0:
		_active_expire_cursor = 0
		return 0
	if _active_expire_cursor < 0 or _active_expire_cursor >= slot_count:
		_active_expire_cursor = 0
	var expired_leases: Array[GFAsyncGateLease] = []
	var work_count: int = mini(_max_pump_work_items, slot_count)
	for _work_index: int in range(work_count):
		var slot_index: int = _active_expire_cursor
		_active_expire_cursor = (_active_expire_cursor + 1) % slot_count
		var lease_id: int = _active_lease_slots[slot_index]
		if lease_id <= 0 or not _lease_records.has(lease_id):
			continue
		var record: Dictionary = GFVariantData.as_dictionary(_lease_records[lease_id])
		var expires_at_msec: int = GFVariantData.get_option_int(record, "expires_at_msec")
		if expires_at_msec <= 0 or now < expires_at_msec:
			continue
		var lease: GFAsyncGateLease = _variant_to_lease(GFVariantData.get_option_value(record, "lease"))
		if lease != null:
			expired_leases.append(lease)

	if expired_leases.is_empty():
		return 0
	_begin_lifecycle_batch()
	var release_cutoff: int = _next_request_id - 1
	var released_count: int = _release_leases_without_pump(
		expired_leases,
		STATUS_TIMEOUT,
		release_cutoff
	)
	_end_lifecycle_batch_and_flush(release_cutoff)
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
	if not Thread.is_main_thread():
		return false
	var key_token: String = _make_key_token(key)
	if key_token.is_empty():
		return false
	return _get_queue_size(key_token) > 0 or _get_active_count(key_token) > 0


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
	if not Thread.is_main_thread():
		return _make_wrong_thread_key_snapshot()
	var key_token: String = _make_key_token(key)
	if key_token.is_empty():
		return _make_invalid_key_snapshot(key)
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
	if not Thread.is_main_thread():
		return result
	for offset: int in range(_events.size()):
		var event_index: int = (
			(_event_start_index + offset) % _events.size()
		)
		var event: Dictionary = _events[event_index]
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
## @schema return: Dictionary，包含 queued_count、active_count、key_count、max_active_leases、等待、key 与推进预算配置、high_watermark、key_high_watermark、rejected_count、dropped_count、acquired_count、released_count、cancelled_count、timeout_count、keys 和 recent_events。
func get_debug_snapshot() -> Dictionary:
	if not Thread.is_main_thread():
		return _make_wrong_thread_debug_snapshot()
	var key_snapshots: Array[Dictionary] = []
	for key_token_value: Variant in _collect_key_tokens():
		key_snapshots.append(_get_key_snapshot_by_token(GFVariantData.to_text(key_token_value)))
	return {
		"default_max_concurrency": default_max_concurrency,
		"max_active_leases": max_active_leases,
		"max_waiting_requests": max_waiting_requests,
		"max_waiting_per_key": max_waiting_per_key,
		"max_tracked_keys": max_tracked_keys,
		"max_pump_work_items": max_pump_work_items,
		"queued_count": _get_total_queued_count(),
		"active_count": _get_total_active_count(),
		"key_count": key_snapshots.size(),
		"high_watermark": _high_watermark,
		"key_high_watermark": _key_high_watermark,
		"rejected_count": _rejected_count,
		"dropped_count": _dropped_count,
		"acquired_count": _acquired_count,
		"released_count": _released_count,
		"cancelled_count": _cancelled_count,
		"timeout_count": _timeout_count,
		"keys": key_snapshots,
		"recent_events": get_recent_events(),
	}


# --- 私有/辅助方法 ---

func _cancel_request_on_main_thread(
	request_id: int,
	reason: StringName,
	metadata: Dictionary,
	use_token_metadata: bool
) -> bool:
	if request_id <= 0:
		return false
	var request: Dictionary = _get_request_record(request_id)
	if (
		request.is_empty()
		or GFVariantData.get_option_string_name(
			request,
			"location"
		) != &"queued"
	):
		return false
	if not _detach_waiting_request(request):
		return false
	var completion_metadata: Dictionary = metadata
	if use_token_metadata:
		completion_metadata = _get_request_cancel_metadata(request)
	var _result: Dictionary = _complete_waiting_request(
		request,
		STATUS_CANCELLED,
		reason,
		completion_metadata,
		false,
		false
	)
	_prune_key_if_transient(
		GFVariantData.get_option_string(request, "key_token")
	)
	return true


func _cancel_requests_for_token_from_worker(
	token_id: int,
	reason: StringName
) -> void:
	if not Thread.is_main_thread():
		return
	var _cancelled_count_for_token: int = (
		_cancel_requests_for_token_on_main_thread(
			token_id,
			reason
		)
	)


func _activate_request(
	request: Dictionary,
	now_msec: int,
	include_completion: bool
) -> Dictionary:
	# Worker-side cancellation linearizes when its single deferred token callback
	# reaches the main thread. This final token-state check closes the interval
	# before the authoritative lease commit; whichever state is observed here wins.
	if _request_has_observed_cancellation(request):
		return _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			_get_request_cancel_reason(request),
			_get_request_cancel_metadata(request),
			false,
			include_completion
		)
	_forget_request_record(request)

	var key_token: String = GFVariantData.get_option_string(request, "key_token")
	var key: Variant = GFVariantData.get_option_value(request, "key")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"metadata"
	)
	var request_id: int = GFVariantData.get_option_int(request, "request_id")
	var lease_id: int = _take_lease_id()
	var lease_timeout_msec: int = GFVariantData.get_option_int(
		request,
		"lease_timeout_msec"
	)
	var expires_at_msec: int = (
		now_msec + lease_timeout_msec
		if lease_timeout_msec > 0
		else 0
	)
	var lease: GFAsyncGateLease = GFAsyncGateLease.new()
	var _configured: GFAsyncGateLease = lease.configure_from_gate(
		lease_id,
		request_id,
		key,
		metadata,
		Callable(self, "_release_lease_from_handle")
	)
	var request_limit: int = GFVariantData.get_option_int(
		request,
		"max_concurrency",
		0
	)
	_add_active_lease(key_token, lease, request_limit)
	_lease_records[lease_id] = {
		"lease": lease,
		"lease_id": lease_id,
		"request_id": request_id,
		"key_token": key_token,
		"key": GFVariantData.duplicate_variant(key),
		"metadata": metadata.duplicate(true),
		"acquired_msec": now_msec,
		"expires_at_msec": expires_at_msec,
		"max_concurrency": request_limit,
	}
	_register_active_lease_slot(lease_id)
	_acquired_count += 1

	var result: Dictionary = _make_request_result(
		STATUS_ACQUIRED,
		true,
		request,
		lease,
		&"",
		include_completion,
		true
	)
	request["terminal_result"] = result.duplicate(true)
	_record_event(&"lease_acquired", request, lease, &"")
	var notification_cutoff: int = _next_request_id - 1
	_begin_notification(notification_cutoff)
	var completion: GFAsyncCompletion = _variant_to_completion(
		GFVariantData.get_option_value(request, "completion")
	)
	if completion != null and completion.is_pending():
		var completion_result: Dictionary = _make_request_result(
			STATUS_ACQUIRED,
			true,
			request,
			lease,
			&"",
			false,
			true
		)
		var _completed: bool = completion.succeed(completion_result)
	lease_acquired.emit(lease)
	_end_notification()
	_prune_key_if_transient(
		GFVariantData.get_option_string(request, "key_token")
	)
	return result


func _release_lease_from_handle(
	lease: GFAsyncGateLease,
	reason: StringName = &"manual"
) -> bool:
	if not Thread.is_main_thread():
		return false
	if lease == null:
		return false
	var lease_id: int = lease.get_lease_id()
	if not _lease_records.has(lease_id):
		return false

	var record: Dictionary = GFVariantData.as_dictionary(
		_lease_records[lease_id]
	)
	var recorded_lease: GFAsyncGateLease = _variant_to_lease(
		GFVariantData.get_option_value(record, "lease")
	)
	if recorded_lease != lease:
		return false
	var safe_reason: StringName = reason if reason != &"" else &"manual"
	var eligible_cutoff: int = (
		_get_current_notification_cutoff()
		if _notification_depth > 0
		else _next_request_id - 1
	)
	if _notification_depth > 0:
		return _queue_pending_release(
			lease,
			safe_reason,
			eligible_cutoff
		)
	var released: bool = _release_lease_now(
		lease,
		safe_reason,
		eligible_cutoff
	)
	if not released:
		return false
	return true


func _release_lease_now(
	lease: GFAsyncGateLease,
	reason: StringName,
	eligible_cutoff: int
) -> bool:
	var lease_id: int = lease.get_lease_id()
	if not _lease_records.has(lease_id):
		return false
	var record: Dictionary = GFVariantData.as_dictionary(
		_lease_records[lease_id]
	)
	var recorded_lease: GFAsyncGateLease = _variant_to_lease(
		GFVariantData.get_option_value(record, "lease")
	)
	if recorded_lease != lease:
		return false
	var key_token: String = GFVariantData.get_option_string(
		record,
		"key_token"
	)
	var safe_reason: StringName = reason if reason != &"" else &"manual"
	if not lease._mark_released_from_gate(safe_reason, false):
		return false
	_remove_active_lease(
		key_token,
		lease_id,
		GFVariantData.get_option_int(record, "max_concurrency", 0)
	)
	_unregister_active_lease_slot(lease_id)
	var _record_erased: bool = _lease_records.erase(lease_id)
	_released_count += 1
	_record_event(&"lease_released", record, lease, safe_reason)
	_remember_pending_pump_cutoff(eligible_cutoff)
	_begin_notification(eligible_cutoff)
	lease._emit_released_from_gate()
	lease_released.emit(lease, safe_reason)
	_end_notification()
	_prune_key_if_transient(key_token)
	return true


func _queue_pending_release(
	lease: GFAsyncGateLease,
	reason: StringName,
	eligible_cutoff: int
) -> bool:
	var lease_id: int = lease.get_lease_id()
	if _pending_releases.has(lease_id):
		return false
	if not lease._mark_release_pending_from_gate():
		return false
	_pending_releases[lease_id] = {
		"lease": lease,
		"reason": reason if reason != &"" else &"manual",
		"eligible_cutoff": eligible_cutoff,
	}
	_pending_release_order.append(lease_id)
	return true


func _drain_pending_releases() -> int:
	if (
		_notification_depth > 0
		or _lifecycle_batch_depth > 0
		or _draining_pending_releases
		or _pending_release_order.is_empty()
	):
		return 0
	_draining_pending_releases = true
	var released_count: int = 0
	var release_index: int = 0
	while release_index < _pending_release_order.size():
		var lease_id: int = _pending_release_order[release_index]
		release_index += 1
		var pending: Dictionary = GFVariantData.as_dictionary(
			_pending_releases.get(lease_id, {})
		)
		var _pending_erased: bool = _pending_releases.erase(lease_id)
		var lease: GFAsyncGateLease = _variant_to_lease(
			GFVariantData.get_option_value(pending, "lease")
		)
		if lease == null:
			continue
		var reason: StringName = GFVariantData.get_option_string_name(
			pending,
			"reason",
			&"manual"
		)
		var eligible_cutoff: int = GFVariantData.get_option_int(
			pending,
			"eligible_cutoff",
			_next_request_id - 1
		)
		if _release_lease_now(lease, reason, eligible_cutoff):
			released_count += 1
			_remember_pending_pump_cutoff(eligible_cutoff)
	_pending_release_order.clear()
	_draining_pending_releases = false
	return released_count


func _begin_notification(eligible_cutoff: int) -> void:
	_notification_depth += 1
	_notification_cutoffs.append(
		eligible_cutoff
		if eligible_cutoff > 0
		else _next_request_id - 1
	)


func _end_notification() -> void:
	if _notification_depth <= 0:
		return
	_notification_depth -= 1
	if not _notification_cutoffs.is_empty():
		var _removed_cutoff: Variant = _notification_cutoffs.pop_back()
	if (
		_notification_depth <= 0
		and _lifecycle_batch_depth <= 0
		and not _draining_pending_releases
	):
		_flush_lifecycle()


func _get_current_notification_cutoff() -> int:
	if _notification_cutoffs.is_empty():
		return _next_request_id - 1
	return _notification_cutoffs[0]


func _begin_lifecycle_batch() -> void:
	_lifecycle_batch_depth += 1


func _end_lifecycle_batch_and_flush(
	default_cutoff: int = 0,
	allow_immediate_pump: bool = true
) -> void:
	if _lifecycle_batch_depth > 0:
		_lifecycle_batch_depth -= 1
	if _lifecycle_batch_depth > 0:
		return
	_flush_lifecycle(default_cutoff, allow_immediate_pump)


func _remember_pending_pump_cutoff(eligible_cutoff: int) -> void:
	if eligible_cutoff <= 0:
		return
	if _pending_pump_cutoff <= 0:
		_pending_pump_cutoff = eligible_cutoff
	else:
		_pending_pump_cutoff = mini(
			_pending_pump_cutoff,
			eligible_cutoff
		)


func _take_pending_pump_cutoff() -> int:
	var cutoff: int = _pending_pump_cutoff
	_pending_pump_cutoff = 0
	return cutoff


func _flush_lifecycle(
	default_cutoff: int = 0,
	allow_immediate_pump: bool = true
) -> void:
	_remember_pending_pump_cutoff(default_cutoff)
	if (
		_notification_depth > 0
		or _lifecycle_batch_depth > 0
		or _draining_pending_releases
	):
		return
	if _pending_pump_cutoff <= 0 and _pending_release_order.is_empty():
		if _pump_dirty and _queued_count > 0:
			_schedule_deferred_key_pump()
		return
	var _drained_release_count: int = _drain_pending_releases()
	if (
		_notification_depth > 0
		or _lifecycle_batch_depth > 0
		or _draining_pending_releases
	):
		return
	if _queued_count <= 0:
		_pending_pump_cutoff = 0
		return
	if not allow_immediate_pump:
		_schedule_deferred_key_pump()
		return
	var cutoff: int = _take_pending_pump_cutoff()
	var _pumped_count: int = _pump_all_keys(false, cutoff)


func _release_leases_without_pump(
	leases: Array[GFAsyncGateLease],
	reason: StringName,
	eligible_cutoff: int
) -> int:
	var released_count: int = 0
	var safe_reason: StringName = reason if reason != &"" else &"manual"
	for lease: GFAsyncGateLease in leases:
		if lease == null:
			continue
		var lease_id: int = lease.get_lease_id()
		if _pending_releases.has(lease_id):
			continue
		if _notification_depth > 0:
			if _queue_pending_release(
				lease,
				safe_reason,
				eligible_cutoff
			):
				released_count += 1
			continue
		if _release_lease_now(
			lease,
			safe_reason,
			eligible_cutoff
		):
			released_count += 1
	return released_count


func _pump_all_keys(
	continue_scan: bool = false,
	request_cutoff: int = 0
) -> int:
	if (
		_pump_in_progress
		or _notification_depth > 0
		or _lifecycle_batch_depth > 0
	):
		_pump_dirty = true
		if request_cutoff > 0:
			_remember_pending_pump_cutoff(request_cutoff)
		if _pump_in_progress:
			_pump_followup_requested = true
		if _lifecycle_batch_depth <= 0:
			_schedule_deferred_key_pump()
		return 0
	var slot_count: int = _key_slots.size()
	if slot_count <= 0 or _queued_count <= 0:
		_pump_key_cursor = 0
		_pump_scan_remaining_keys = 0
		_pump_cycle_progress_count = 0
		_pump_snapshot_request_cutoff = 0
		_pump_followup_requested = false
		_pump_dirty = false
		return 0

	if _pump_key_cursor < 0 or _pump_key_cursor >= slot_count:
		_pump_key_cursor = 0
	var activation_budget: int = maxi(
		0,
		_max_active_leases - _lease_records.size()
	)
	if activation_budget <= 0:
		_pump_scan_remaining_keys = 0
		_pump_cycle_progress_count = 0
		_pump_dirty = false
		return 0
	var starts_new_snapshot: bool = (
		not continue_scan
		or _pump_scan_remaining_keys <= 0
		or _pump_snapshot_request_cutoff <= 0
	)
	if starts_new_snapshot:
		_pump_scan_remaining_keys = slot_count
		_pump_cycle_progress_count = 0
		_pump_snapshot_request_cutoff = (
			request_cutoff
			if request_cutoff > 0
			else _next_request_id - 1
		)
		_pump_followup_requested = (
			_next_request_id - 1
			> _pump_snapshot_request_cutoff
		)
		_pump_dirty = false
	else:
		_pump_scan_remaining_keys = mini(
			_pump_scan_remaining_keys,
			slot_count
		)

	_pump_in_progress = true
	var activated_count: int = 0
	var _processed_count: int = 0
	var work_item_count: int = 0
	while (
		activated_count < activation_budget
		and work_item_count < _max_pump_work_items
		and _pump_scan_remaining_keys > 0
		and _queued_count > 0
	):
		var slot_index: int = _pump_key_cursor
		_pump_key_cursor = (_pump_key_cursor + 1) % slot_count
		_pump_scan_remaining_keys -= 1
		work_item_count += 1
		var key_token: String = _key_slots[slot_index]
		if key_token.is_empty():
			continue
		var key_report: Dictionary = _pump_key(
			key_token,
			_pump_snapshot_request_cutoff
		)
		var key_activated_count: int = GFVariantData.get_option_int(
			key_report,
			"activated_count"
		)
		var key_processed_count: int = GFVariantData.get_option_int(
			key_report,
			"processed_count"
		)
		activated_count += key_activated_count
		_processed_count += key_processed_count
		_pump_cycle_progress_count += key_processed_count

	_pump_in_progress = false
	var has_remaining_capacity: bool = (
		_lease_records.size() < _max_active_leases
	)
	var should_continue: bool = false
	if (
		has_remaining_capacity
		and _queued_count > 0
	):
		if _pump_scan_remaining_keys > 0:
			should_continue = true
		elif _pump_cycle_progress_count > 0:
			_pump_scan_remaining_keys = slot_count
			_pump_cycle_progress_count = 0
			should_continue = true
		elif _pump_followup_requested or _pump_dirty:
			_pump_scan_remaining_keys = 0
			_pump_cycle_progress_count = 0
			_pump_snapshot_request_cutoff = 0
			_pump_followup_requested = false
			_pump_dirty = false
			should_continue = true
	if should_continue:
		_schedule_deferred_key_pump()
	else:
		_pump_scan_remaining_keys = 0
		_pump_cycle_progress_count = 0
		_pump_snapshot_request_cutoff = 0
		_pump_followup_requested = false
		_pump_dirty = false
	return activated_count


func _pump_key(
	key_token: String,
	snapshot_max_request_id: int
) -> Dictionary:
	var now_msec: int = Time.get_ticks_msec()
	var activated_count: int = 0
	var processed_count: int = 0
	var request_id: int = _get_queue_head_request_id(key_token)
	if request_id <= 0 or request_id > snapshot_max_request_id:
		return {
			"activated_count": 0,
			"processed_count": 0,
		}
	var request: Dictionary = _get_request_record(request_id)
	if request.is_empty():
		return {
			"activated_count": 0,
			"processed_count": 0,
		}
	if _request_has_observed_cancellation(request):
		var _detached_cancelled: bool = _detach_waiting_request(request)
		var _cancel_result: Dictionary = _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			_get_request_cancel_reason(request),
			_get_request_cancel_metadata(request),
			false,
			false
		)
		processed_count = 1
	else:
		var expires_at_msec: int = GFVariantData.get_option_int(
			request,
			"expires_at_msec"
		)
		if expires_at_msec > 0 and now_msec >= expires_at_msec:
			var _detached_expired: bool = _detach_waiting_request(request)
			var _timeout_result: Dictionary = _complete_waiting_request(
				request,
				STATUS_TIMEOUT,
				STATUS_TIMEOUT,
				{
					"now_msec": now_msec,
					"expires_at_msec": expires_at_msec,
				},
				true,
				false
			)
			processed_count = 1
		elif _can_activate_request(key_token, request):
			var _detached_ready: bool = _detach_waiting_request(request)
			var activation_result: Dictionary = _activate_request(
				request,
				now_msec,
				false
			)
			if (
				GFVariantData.get_option_string_name(
					activation_result,
					"status"
				) == STATUS_ACQUIRED
			):
				activated_count = 1
			processed_count = 1

	_prune_key_if_transient(key_token)
	return {
		"activated_count": activated_count,
		"processed_count": processed_count,
	}


func _queue_front_is_in_snapshot(
	key_token: String,
	snapshot_max_request_id: int
) -> bool:
	var request_id: int = _get_queue_head_request_id(key_token)
	return request_id > 0 and request_id <= snapshot_max_request_id


func _schedule_deferred_key_pump() -> void:
	if _deferred_pump_scheduled:
		return
	_deferred_pump_scheduled = true
	var _deferred_result: Variant = call_deferred(
		"_flush_deferred_key_pump"
	)


func _flush_deferred_key_pump() -> void:
	_deferred_pump_scheduled = false
	if not Thread.is_main_thread():
		return
	var continue_scan: bool = (
		_pump_scan_remaining_keys > 0
		and _pump_snapshot_request_cutoff > 0
	)
	var cutoff: int = (
		0
		if continue_scan
		else _take_pending_pump_cutoff()
	)
	var _pumped_count: int = _pump_all_keys(
		continue_scan,
		cutoff
	)


func _complete_waiting_request(
	request: Dictionary,
	status: StringName,
	reason: StringName,
	metadata: Dictionary,
	timed_out: bool,
	include_completion: bool
) -> Dictionary:
	_forget_request_record(request)
	var safe_status: StringName = (
		status if status != &"" else STATUS_CANCELLED
	)
	var safe_reason: StringName = reason if reason != &"" else safe_status
	var completion: GFAsyncCompletion = _variant_to_completion(
		GFVariantData.get_option_value(request, "completion")
	)
	var completion_metadata: Dictionary = (
		GFVariantData.get_option_dictionary(request, "metadata")
	)
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(
		completion_metadata,
		metadata,
		true,
		true
	)
	var result: Dictionary = _make_request_result(
		safe_status,
		false,
		request,
		null,
		safe_reason,
		include_completion,
		false
	)
	result["metadata"] = completion_metadata.duplicate(true)
	result["reason"] = safe_reason
	request["terminal_result"] = result.duplicate(true)
	var notification_cutoff: int = _next_request_id - 1
	_remember_pending_pump_cutoff(notification_cutoff)
	_begin_notification(notification_cutoff)
	if timed_out:
		_timeout_count += 1
		_record_event(&"request_timed_out", request, null, safe_reason)
		if completion != null and completion.is_pending():
			var _timeout_completed: bool = completion.cancel(
				STATUS_TIMEOUT,
				_merged_metadata
			)
		request_timed_out.emit(
			GFVariantData.get_option_int(request, "request_id"),
			GFVariantData.duplicate_variant(
				GFVariantData.get_option_value(request, "key")
			),
			_merged_metadata.duplicate(true)
		)
	else:
		_cancelled_count += 1
		_record_event(&"request_cancelled", request, null, safe_reason)
		if completion != null and completion.is_pending():
			var _cancel_completed: bool = completion.cancel(
				safe_reason,
				_merged_metadata
			)
		request_cancelled.emit(
			GFVariantData.get_option_int(request, "request_id"),
			GFVariantData.duplicate_variant(
				GFVariantData.get_option_value(request, "key")
			),
			safe_reason,
			_merged_metadata.duplicate(true)
		)
	_end_notification()
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


func _make_invalid_key_result(key: Variant, key_report: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"status": STATUS_INVALID,
		"queued": false,
		"acquired": false,
		"request_id": 0,
		"key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(key),
		"metadata": {},
		"reason": GFVariantData.get_option_string_name(key_report, "reason", STATUS_INVALID),
	}


func _make_wrong_thread_request_result() -> Dictionary:
	return {
		"ok": false,
		"status": STATUS_INVALID,
		"queued": false,
		"acquired": false,
		"request_id": 0,
		"key": null,
		"metadata": {},
		"reason": _STATUS_WRONG_THREAD,
	}


func _make_wrong_thread_key_snapshot() -> Dictionary:
	return {
		"ok": false,
		"status": STATUS_INVALID,
		"key_token": "",
		"key": null,
		"queued_count": -1,
		"active_count": -1,
		"max_concurrency": 0,
		"waiting_request_ids": [],
		"active_lease_ids": [],
		"reason": _STATUS_WRONG_THREAD,
	}


func _make_wrong_thread_debug_snapshot() -> Dictionary:
	return {
		"ok": false,
		"status": STATUS_INVALID,
		"reason": _STATUS_WRONG_THREAD,
		"default_max_concurrency": 0,
		"max_active_leases": 0,
		"max_waiting_requests": 0,
		"max_waiting_per_key": 0,
		"max_tracked_keys": 0,
		"max_pump_work_items": 0,
		"queued_count": -1,
		"active_count": -1,
		"key_count": -1,
		"high_watermark": -1,
		"key_high_watermark": -1,
		"rejected_count": -1,
		"dropped_count": -1,
		"acquired_count": -1,
		"released_count": -1,
		"cancelled_count": -1,
		"timeout_count": -1,
		"keys": [],
		"recent_events": [],
	}


func _make_rejected_request_result(
	request: Dictionary,
	reason: StringName,
	capacity_scope: StringName
) -> Dictionary:
	_rejected_count += 1
	var result: Dictionary = _make_request_result(
		STATUS_REJECTED,
		false,
		request,
		null,
		reason,
		false,
		false
	)
	result["capacity_scope"] = capacity_scope
	_record_event(&"request_rejected", request, null, reason)
	return result


func _bind_request_cancel_token(request: Dictionary) -> bool:
	var token: GFCancellationToken = _variant_to_cancel_token(
		GFVariantData.get_option_value(request, "cancel_token")
	)
	if token == null:
		return true
	var request_id: int = GFVariantData.get_option_int(request, "request_id")
	var token_id: int = token.get_instance_id()
	request["cancel_token_id"] = token_id
	if _cancel_token_states.has(token_id):
		var existing_state: Dictionary = GFVariantData.as_dictionary(
			_cancel_token_states[token_id]
		)
		var existing_request_ids: Dictionary = (
			GFVariantData.as_dictionary(
				existing_state.get("request_ids")
			)
		)
		existing_request_ids[request_id] = true
		existing_state["request_ids"] = existing_request_ids
		_cancel_token_states[token_id] = existing_state
		return true

	var callback: Callable = Callable(
		self,
		"_handle_cancel_token_requested"
	).bind(token_id)
	var request_ids: Dictionary = {
		request_id: true,
	}
	_cancel_token_states[token_id] = {
		"token": token,
		"callback": callback,
		"request_ids": request_ids,
	}
	request["cancel_callback"] = callback
	var connect_error: Error = _connect_request_cancel_token(
		token,
		callback
	)
	if connect_error != OK:
		var _state_erased: bool = _cancel_token_states.erase(token_id)
		request["cancel_token_id"] = 0
		request["cancel_callback"] = Callable()
		return false
	return true


func _handle_cancel_token_requested(
	reason: StringName,
	token_id: int
) -> void:
	if Thread.is_main_thread():
		var _cancelled_for_token: int = (
			_cancel_requests_for_token_on_main_thread(
				token_id,
				reason
			)
		)
		return
	# Worker callbacks never enumerate requests. The token contributes one
	# deferred main-thread task regardless of how many requests share it.
	call_deferred(
		"_cancel_requests_for_token_from_worker",
		token_id,
		reason
	)


func _connect_request_cancel_token(
	token: GFCancellationToken,
	callback: Callable
) -> Error:
	return token.cancel_requested.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


func _disconnect_request_cancel_token(request: Dictionary) -> void:
	var token_id: int = GFVariantData.get_option_int(
		request,
		"cancel_token_id"
	)
	if token_id == 0 or not _cancel_token_states.has(token_id):
		request["cancel_token_id"] = 0
		request["cancel_callback"] = Callable()
		return
	var state: Dictionary = GFVariantData.as_dictionary(
		_cancel_token_states[token_id]
	)
	var request_ids: Dictionary = GFVariantData.as_dictionary(
		state.get("request_ids")
	)
	var request_id: int = GFVariantData.get_option_int(
		request,
		"request_id"
	)
	var _request_erased: bool = request_ids.erase(request_id)
	if request_ids.is_empty():
		var token: GFCancellationToken = _variant_to_cancel_token(
			GFVariantData.get_option_value(state, "token")
		)
		var callback: Callable = _variant_to_callable(
			GFVariantData.get_option_value(state, "callback")
		)
		if (
			token != null
			and callback.is_valid()
			and token.cancel_requested.is_connected(callback)
		):
			token.cancel_requested.disconnect(callback)
		var _state_erased: bool = _cancel_token_states.erase(token_id)
	else:
		state["request_ids"] = request_ids
		_cancel_token_states[token_id] = state
	request["cancel_token_id"] = 0
	request["cancel_callback"] = Callable()


func _cancel_requests_for_token_on_main_thread(
	token_id: int,
	reason: StringName
) -> int:
	if token_id == 0 or not _cancel_token_states.has(token_id):
		return 0
	var state: Dictionary = GFVariantData.as_dictionary(
		_cancel_token_states[token_id]
	)
	var token: GFCancellationToken = _variant_to_cancel_token(
		GFVariantData.get_option_value(state, "token")
	)
	var callback: Callable = _variant_to_callable(
		GFVariantData.get_option_value(state, "callback")
	)
	var request_ids: Dictionary = GFVariantData.as_dictionary(
		state.get("request_ids")
	)
	var _state_erased: bool = _cancel_token_states.erase(token_id)
	if (
		token != null
		and callback.is_valid()
		and token.cancel_requested.is_connected(callback)
	):
		token.cancel_requested.disconnect(callback)
	var safe_reason: StringName = reason if reason != &"" else STATUS_CANCELLED
	var cancel_metadata: Dictionary = {}
	if token != null and token.is_cancel_requested():
		safe_reason = token.get_cancel_reason()
		cancel_metadata = token.get_cancel_metadata()

	var detached_requests: Array[Dictionary] = []
	_begin_lifecycle_batch()
	# This enumeration is main-thread-only. Queue authority is detached for the
	# complete token fan-out before any user completion or signal is notified.
	for request_id_value: Variant in request_ids.keys():
		var request_id: int = GFVariantData.to_int(request_id_value)
		var request: Dictionary = _get_request_record(request_id)
		if request.is_empty():
			continue
		request["cancel_token_id"] = 0
		request["cancel_callback"] = Callable()
		request["cancel_observed"] = true
		request["cancel_reason"] = safe_reason
		request["cancel_metadata"] = cancel_metadata.duplicate(true)
		if (
			GFVariantData.get_option_string_name(
				request,
				"location"
			) == &"queued"
			and _detach_waiting_request(request)
		):
			detached_requests.append(request)

	for request: Dictionary in detached_requests:
		var _result: Dictionary = _complete_waiting_request(
			request,
			STATUS_CANCELLED,
			safe_reason,
			cancel_metadata,
			false,
			false
		)
	_end_lifecycle_batch_and_flush()
	return detached_requests.size()


func _request_has_observed_cancellation(request: Dictionary) -> bool:
	if GFVariantData.get_option_bool(request, "cancel_observed"):
		return true
	var token: GFCancellationToken = _variant_to_cancel_token(
		GFVariantData.get_option_value(request, "cancel_token")
	)
	return token != null and token.is_cancel_requested()


func _get_request_cancel_reason(request: Dictionary) -> StringName:
	var stored_reason: StringName = GFVariantData.get_option_string_name(
		request,
		"cancel_reason"
	)
	if stored_reason != &"":
		return stored_reason
	var token: GFCancellationToken = _variant_to_cancel_token(
		GFVariantData.get_option_value(request, "cancel_token")
	)
	if token != null and token.is_cancel_requested():
		var token_reason: StringName = token.get_cancel_reason()
		if token_reason != &"":
			return token_reason
	return STATUS_CANCELLED


func _get_request_cancel_metadata(request: Dictionary) -> Dictionary:
	var stored_metadata: Dictionary = GFVariantData.get_option_dictionary(
		request,
		"cancel_metadata"
	)
	if not stored_metadata.is_empty():
		return stored_metadata
	var token: GFCancellationToken = _variant_to_cancel_token(
		GFVariantData.get_option_value(request, "cancel_token")
	)
	if token != null and token.is_cancel_requested():
		return token.get_cancel_metadata()
	return {}


func _can_activate_request(key_token: String, request: Dictionary) -> bool:
	return (
		_lease_records.size() < _max_active_leases
		and _get_active_count(key_token)
		< _get_effective_request_limit(key_token, request)
	)


func _get_key_limit(key_token: String) -> int:
	if _key_limits.has(key_token):
		return clampi(
			GFVariantData.to_int(
				_key_limits[key_token],
				_default_max_concurrency
			),
			1,
			ABSOLUTE_MAX_CONCURRENCY
		)
	return _default_max_concurrency


func _get_effective_request_limit(key_token: String, request: Dictionary) -> int:
	var configured_limit: int = _get_current_active_limit(key_token)
	var request_limit: int = GFVariantData.get_option_int(request, "max_concurrency", 0)
	if request_limit > 0:
		return mini(
			configured_limit,
			clampi(request_limit, 1, ABSOLUTE_MAX_CONCURRENCY)
		)
	return configured_limit


func _get_current_active_limit(key_token: String) -> int:
	var limit: int = _get_key_limit(key_token)
	if _active_min_limit_by_key.has(key_token):
		limit = mini(
			limit,
			GFVariantData.to_int(
				_active_min_limit_by_key[key_token],
				limit
			)
		)
	return limit


func _get_request_max_concurrency(options: Dictionary) -> int:
	var limit: int = GFVariantData.get_option_int(options, "max_concurrency", 0)
	if limit <= 0:
		return 0
	return clampi(limit, 1, ABSOLUTE_MAX_CONCURRENCY)


func _remember_key(key_token: String, key: Variant) -> void:
	if _key_data.has(key_token):
		return
	var slot_index: int = 0
	if _free_key_slots.is_empty():
		slot_index = _key_slots.size()
		_key_slots.append(key_token)
	else:
		slot_index = _free_key_slots.pop_back()
		_key_slots[slot_index] = key_token
	_key_slot_by_token[key_token] = slot_index
	_key_data[key_token] = {
		"key": GFVariantData.duplicate_variant(key),
		"key_token": key_token,
	}


func _is_key_tracked(key_token: String) -> bool:
	return _key_data.has(key_token)


func _update_key_high_watermark() -> void:
	_key_high_watermark = maxi(_key_high_watermark, _key_data.size())


func _get_queue_state(key_token: String) -> Dictionary:
	if not _queue_states_by_key.has(key_token):
		return {}
	return GFVariantData.as_dictionary(_queue_states_by_key[key_token])


func _get_or_create_queue_state(key_token: String) -> Dictionary:
	if not _queue_states_by_key.has(key_token):
		_queue_states_by_key[key_token] = {
			"head_request_id": 0,
			"tail_request_id": 0,
			"size": 0,
		}
	return GFVariantData.as_dictionary(_queue_states_by_key[key_token])


func _get_queue_size(key_token: String) -> int:
	return GFVariantData.get_option_int(
		_get_queue_state(key_token),
		"size"
	)


func _get_queue_head_request_id(key_token: String) -> int:
	return GFVariantData.get_option_int(
		_get_queue_state(key_token),
		"head_request_id"
	)


func _get_request_record(request_id: int) -> Dictionary:
	if request_id <= 0 or not _request_records.has(request_id):
		return {}
	return GFVariantData.as_dictionary(_request_records[request_id])


func _enqueue_waiting_request(request: Dictionary) -> void:
	var request_id: int = GFVariantData.get_option_int(
		request,
		"request_id"
	)
	var key_token: String = GFVariantData.get_option_string(
		request,
		"key_token"
	)
	var queue_state: Dictionary = _get_or_create_queue_state(key_token)
	var tail_request_id: int = GFVariantData.get_option_int(
		queue_state,
		"tail_request_id"
	)
	request["location"] = &"queued"
	request["queue_previous_request_id"] = tail_request_id
	request["queue_next_request_id"] = 0
	if tail_request_id > 0:
		var previous_request: Dictionary = _get_request_record(
			tail_request_id
		)
		previous_request["queue_next_request_id"] = request_id
		_request_records[tail_request_id] = previous_request
	else:
		queue_state["head_request_id"] = request_id
	queue_state["tail_request_id"] = request_id
	queue_state["size"] = (
		GFVariantData.get_option_int(queue_state, "size") + 1
	)
	_queue_states_by_key[key_token] = queue_state
	_request_records[request_id] = request
	_register_waiting_request_slot(request_id)
	_queued_count += 1


func _detach_waiting_request(request: Dictionary) -> bool:
	if (
		GFVariantData.get_option_string_name(
			request,
			"location"
		) != &"queued"
	):
		return false
	var request_id: int = GFVariantData.get_option_int(
		request,
		"request_id"
	)
	var key_token: String = GFVariantData.get_option_string(
		request,
		"key_token"
	)
	var queue_state: Dictionary = _get_queue_state(key_token)
	if queue_state.is_empty():
		return false
	var previous_request_id: int = GFVariantData.get_option_int(
		request,
		"queue_previous_request_id"
	)
	var next_request_id: int = GFVariantData.get_option_int(
		request,
		"queue_next_request_id"
	)
	if previous_request_id > 0:
		var previous_request: Dictionary = _get_request_record(
			previous_request_id
		)
		previous_request["queue_next_request_id"] = next_request_id
		_request_records[previous_request_id] = previous_request
	else:
		queue_state["head_request_id"] = next_request_id
	if next_request_id > 0:
		var next_request: Dictionary = _get_request_record(next_request_id)
		next_request["queue_previous_request_id"] = previous_request_id
		_request_records[next_request_id] = next_request
	else:
		queue_state["tail_request_id"] = previous_request_id
	var remaining_size: int = maxi(
		GFVariantData.get_option_int(queue_state, "size") - 1,
		0
	)
	if remaining_size <= 0:
		var _state_erased: bool = _queue_states_by_key.erase(key_token)
	else:
		queue_state["size"] = remaining_size
		_queue_states_by_key[key_token] = queue_state
	request["location"] = &"detached"
	request["queue_previous_request_id"] = 0
	request["queue_next_request_id"] = 0
	_request_records[request_id] = request
	_unregister_waiting_request_slot(request_id)
	_queued_count = maxi(_queued_count - 1, 0)
	return true


func _detach_all_waiting_requests() -> Array[Dictionary]:
	var detached_requests: Array[Dictionary] = []
	for request_id: int in _waiting_request_slots:
		if request_id <= 0:
			continue
		var request: Dictionary = _get_request_record(request_id)
		if request.is_empty():
			continue
		if _detach_waiting_request(request):
			detached_requests.append(request)
	return detached_requests


func _forget_request_record(request: Dictionary) -> void:
	if (
		GFVariantData.get_option_string_name(
			request,
			"location"
		) == &"queued"
	):
		var _detached: bool = _detach_waiting_request(request)
	_disconnect_request_cancel_token(request)
	var request_id: int = GFVariantData.get_option_int(
		request,
		"request_id"
	)
	if request_id > 0:
		var _request_erased: bool = _request_records.erase(request_id)
	request["location"] = &"terminal"


func _register_waiting_request_slot(request_id: int) -> void:
	var slot_index: int = 0
	if _free_waiting_request_slots.is_empty():
		slot_index = _waiting_request_slots.size()
		_waiting_request_slots.append(request_id)
	else:
		slot_index = _free_waiting_request_slots.pop_back()
		_waiting_request_slots[slot_index] = request_id
	_waiting_slot_by_request_id[request_id] = slot_index


func _unregister_waiting_request_slot(request_id: int) -> void:
	if not _waiting_slot_by_request_id.has(request_id):
		return
	var slot_index: int = GFVariantData.to_int(
		_waiting_slot_by_request_id[request_id],
		-1
	)
	var _slot_erased: bool = _waiting_slot_by_request_id.erase(request_id)
	if slot_index < 0 or slot_index >= _waiting_request_slots.size():
		return
	_waiting_request_slots[slot_index] = 0
	_free_waiting_request_slots.append(slot_index)


func _get_active_lease_map(key_token: String) -> Dictionary:
	if not _active_by_key.has(key_token):
		return {}
	return GFVariantData.as_dictionary(_active_by_key[key_token])


func _get_active_count(key_token: String) -> int:
	return _get_active_lease_map(key_token).size()


func _add_active_lease(
	key_token: String,
	lease: GFAsyncGateLease,
	request_limit: int
) -> void:
	var active: Dictionary = _get_active_lease_map(key_token)
	active[lease.get_lease_id()] = lease
	_active_by_key[key_token] = active
	if request_limit <= 0:
		return
	var safe_limit: int = clampi(
		request_limit,
		1,
		ABSOLUTE_MAX_CONCURRENCY
	)
	var counts: Dictionary = GFVariantData.as_dictionary(
		_active_limit_counts_by_key.get(key_token, {})
	)
	counts[safe_limit] = GFVariantData.to_int(
		counts.get(safe_limit, 0)
	) + 1
	_active_limit_counts_by_key[key_token] = counts
	if (
		not _active_min_limit_by_key.has(key_token)
		or safe_limit
		< GFVariantData.to_int(_active_min_limit_by_key[key_token])
	):
		_active_min_limit_by_key[key_token] = safe_limit


func _remove_active_lease(
	key_token: String,
	lease_id: int,
	request_limit: int
) -> void:
	var active: Dictionary = _get_active_lease_map(key_token)
	var _lease_erased: bool = active.erase(lease_id)
	if active.is_empty():
		var _active_erased: bool = _active_by_key.erase(key_token)
	else:
		_active_by_key[key_token] = active
	if request_limit <= 0:
		return
	var safe_limit: int = clampi(
		request_limit,
		1,
		ABSOLUTE_MAX_CONCURRENCY
	)
	var counts: Dictionary = GFVariantData.as_dictionary(
		_active_limit_counts_by_key.get(key_token, {})
	)
	var remaining_count: int = maxi(
		GFVariantData.to_int(counts.get(safe_limit, 0)) - 1,
		0
	)
	if remaining_count > 0:
		counts[safe_limit] = remaining_count
		_active_limit_counts_by_key[key_token] = counts
		return
	var _limit_erased: bool = counts.erase(safe_limit)
	if counts.is_empty():
		var _counts_erased: bool = _active_limit_counts_by_key.erase(
			key_token
		)
		var _min_erased: bool = _active_min_limit_by_key.erase(key_token)
		return
	_active_limit_counts_by_key[key_token] = counts
	if (
		GFVariantData.to_int(
			_active_min_limit_by_key.get(key_token, 0)
		) != safe_limit
	):
		return
	var next_minimum: int = ABSOLUTE_MAX_CONCURRENCY
	for limit_value: Variant in counts:
		next_minimum = mini(
			next_minimum,
			GFVariantData.to_int(limit_value)
		)
	_active_min_limit_by_key[key_token] = next_minimum


func _register_active_lease_slot(lease_id: int) -> void:
	var slot_index: int = 0
	if _free_active_lease_slots.is_empty():
		slot_index = _active_lease_slots.size()
		_active_lease_slots.append(lease_id)
	else:
		slot_index = _free_active_lease_slots.pop_back()
		_active_lease_slots[slot_index] = lease_id
	_active_slot_by_lease_id[lease_id] = slot_index


func _unregister_active_lease_slot(lease_id: int) -> void:
	if not _active_slot_by_lease_id.has(lease_id):
		return
	var slot_index: int = GFVariantData.to_int(
		_active_slot_by_lease_id[lease_id],
		-1
	)
	var _slot_erased: bool = _active_slot_by_lease_id.erase(lease_id)
	if slot_index < 0 or slot_index >= _active_lease_slots.size():
		return
	_active_lease_slots[slot_index] = 0
	_free_active_lease_slots.append(slot_index)


func _collect_active_leases() -> Array[GFAsyncGateLease]:
	var leases: Array[GFAsyncGateLease] = []
	for lease_id: int in _active_lease_slots:
		if lease_id <= 0 or not _lease_records.has(lease_id):
			continue
		var record: Dictionary = GFVariantData.as_dictionary(
			_lease_records[lease_id]
		)
		var lease: GFAsyncGateLease = _variant_to_lease(
			GFVariantData.get_option_value(record, "lease")
		)
		if lease != null:
			leases.append(lease)
	return leases


func _get_key_snapshot_by_token(key_token: String) -> Dictionary:
	var key_record: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(_key_data, key_token, {})
	)
	var key: Variant = GFVariantData.get_option_value(key_record, "key")
	var waiting_request_ids: Array[int] = []
	var request_id: int = _get_queue_head_request_id(key_token)
	while request_id > 0:
		waiting_request_ids.append(request_id)
		var request: Dictionary = _get_request_record(request_id)
		if request.is_empty():
			break
		request_id = GFVariantData.get_option_int(
			request,
			"queue_next_request_id"
		)
	var active_lease_ids: Array[int] = []
	var active: Dictionary = _get_active_lease_map(key_token)
	for lease_id_value: Variant in active:
		active_lease_ids.append(GFVariantData.to_int(lease_id_value))
	active_lease_ids.sort()
	return {
		"key_token": key_token,
		"key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(key),
		"queued_count": _get_queue_size(key_token),
		"active_count": active.size(),
		"max_concurrency": _get_key_limit(key_token),
		"waiting_request_ids": waiting_request_ids,
		"active_lease_ids": active_lease_ids,
	}


func _make_invalid_key_snapshot(key: Variant) -> Dictionary:
	return {
		"ok": false,
		"status": STATUS_INVALID,
		"key_token": "",
		"key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(key),
		"queued_count": 0,
		"active_count": 0,
		"max_concurrency": 0,
		"waiting_request_ids": [],
		"active_lease_ids": [],
		"reason": "unstable_key",
	}


func _collect_key_tokens() -> Array:
	var key_tokens: Array[String] = []
	for key_token: String in _key_slots:
		if not key_token.is_empty():
			key_tokens.append(key_token)
	return key_tokens


func _prune_key_if_transient(key_token: String) -> void:
	if (
		_queue_states_by_key.has(key_token)
		or _active_by_key.has(key_token)
		or _key_limits.has(key_token)
	):
		return
	var _erased_key_data: bool = _key_data.erase(key_token)
	if not _key_slot_by_token.has(key_token):
		return
	var slot_index: int = GFVariantData.to_int(
		_key_slot_by_token[key_token],
		-1
	)
	var _slot_erased: bool = _key_slot_by_token.erase(key_token)
	if slot_index < 0 or slot_index >= _key_slots.size():
		return
	_key_slots[slot_index] = ""
	_free_key_slots.append(slot_index)


func _get_total_queued_count() -> int:
	return _queued_count


func _get_total_active_count() -> int:
	return _lease_records.size()


func _record_event(event_type: StringName, source: Dictionary, lease: GFAsyncGateLease, reason: StringName) -> void:
	if _max_recent_events <= 0:
		return
	var key: Variant = GFVariantData.get_option_value(source, "key")
	var event: Dictionary = {
		"event_index": _next_event_index,
		"event_type": event_type,
		"request_id": GFVariantData.get_option_int(source, "request_id"),
		"lease_id": lease.get_lease_id() if lease != null else GFVariantData.get_option_int(source, "lease_id"),
		"key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(key),
		"key_token": GFVariantData.get_option_string(source, "key_token", _make_key_token(key)),
		"reason": reason,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	_next_event_index += 1
	if _events.size() < _max_recent_events:
		_events.append(event)
		return
	_events[_event_start_index] = event
	_event_start_index = (
		(_event_start_index + 1) % _events.size()
	)


func _trim_events() -> void:
	if _max_recent_events <= 0:
		_events.clear()
		_event_start_index = 0
		return
	var retained_count: int = mini(
		_events.size(),
		_max_recent_events
	)
	var first_retained_offset: int = _events.size() - retained_count
	var retained_events: Array[Dictionary] = []
	for offset: int in range(
		first_retained_offset,
		_events.size()
	):
		var event_index: int = (
			(_event_start_index + offset) % _events.size()
		)
		retained_events.append(_events[event_index])
	_events = retained_events
	_event_start_index = 0


func _take_request_id() -> int:
	var result: int = _next_request_id
	_next_request_id += 1
	return result


func _take_lease_id() -> int:
	var result: int = _next_lease_id
	_next_lease_id += 1
	return result


func _make_key_token(key: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(key)


func _variant_to_cancel_token(value: Variant) -> GFCancellationToken:
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
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
