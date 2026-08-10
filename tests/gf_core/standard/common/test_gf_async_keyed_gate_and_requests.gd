extends GutTest

const GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT = preload("res://addons/gf/standard/common/gf_execution_lane_diagnostics.gd")


class CancelDuringTokenBindGate:
	extends GFAsyncKeyedGate

	func _connect_request_cancel_token(
		token: GFCancellationToken,
		callback: Callable
	) -> Error:
		var connect_error: Error = super._connect_request_cancel_token(
			token,
			callback
		)
		if connect_error == OK:
			var _cancelled: bool = token.request_cancel_internal(
				&"bind_window_cancelled",
				{ "scope": "bind_window" }
			)
		return connect_error


class FailingTokenBindGate:
	extends GFAsyncKeyedGate

	func _connect_request_cancel_token(
		_token: GFCancellationToken,
		_callback: Callable
	) -> Error:
		return ERR_CANT_CONNECT


class PumpProbeGate:
	extends GFAsyncKeyedGate

	var token_connect_count: int = 0

	func is_deferred_pump_scheduled() -> bool:
		return _deferred_pump_scheduled

	func get_scan_remaining_keys() -> int:
		return _pump_scan_remaining_keys

	func get_pump_key_cursor() -> int:
		return _pump_key_cursor

	func get_next_request_id() -> int:
		return _next_request_id

	func get_shared_token_request_count(
		token: GFCancellationToken
	) -> int:
		if token == null:
			return 0
		var token_id: int = token.get_instance_id()
		if not _cancel_token_states.has(token_id):
			return 0
		var state: Dictionary = GFVariantData.as_dictionary(
			_cancel_token_states[token_id]
		)
		var request_ids_value: Variant = state.get("request_ids")
		if request_ids_value is Dictionary:
			var request_ids: Dictionary = request_ids_value
			return request_ids.size()
		return 0

	func _connect_request_cancel_token(
		token: GFCancellationToken,
		callback: Callable
	) -> Error:
		token_connect_count += 1
		return super._connect_request_cancel_token(token, callback)


func test_keyed_gate_queues_per_key_and_promotes_on_release() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()

	var first: Dictionary = gate.request_lease(&"asset")
	var first_lease: GFAsyncGateLease = _result_to_lease(first)
	assert_eq(GFVariantData.get_option_string_name(first, "status"), GFAsyncKeyedGate.STATUS_ACQUIRED, "第一个同 key 请求应立即获得租约。")
	assert_true(first_lease != null and first_lease.is_active(), "获得的租约应处于 active。")

	var second: Dictionary = gate.request_lease(&"asset")
	var second_completion: GFAsyncCompletion = _result_to_completion(second)
	assert_eq(GFVariantData.get_option_string_name(second, "status"), GFAsyncKeyedGate.STATUS_QUEUED, "同 key 第二个请求应排队。")
	assert_true(second_completion != null and second_completion.is_pending(), "排队请求应返回 pending completion。")

	var other: Dictionary = gate.request_lease(&"other")
	assert_eq(GFVariantData.get_option_string_name(other, "status"), GFAsyncKeyedGate.STATUS_ACQUIRED, "不同 key 不应互相阻塞。")

	assert_true(first_lease.release(&"done"), "释放第一个租约应成功。")
	assert_true(second_completion.is_successful(), "释放后排队请求应被推进为成功。")

	var promoted: Dictionary = GFVariantData.as_dictionary(second_completion.get_result())
	var second_lease: GFAsyncGateLease = _result_to_lease(promoted)
	var snapshot: Dictionary = gate.get_key_snapshot(&"asset")
	assert_true(second_lease != null and second_lease.is_active(), "推进后的请求应获得新租约。")
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 0, "同 key 队列应清空。")
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 1, "同 key 应只保留一个活跃租约。")


func test_keyed_gate_try_request_is_fail_fast_without_queue_or_fairness_mutation() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_active_leases = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"asset")
	)
	var waiting: Dictionary = gate.request_lease(&"asset")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var signal_state: Dictionary = { "queued_count": 0 }
	var connect_error: Error = gate.request_queued.connect(
		func(
			_request_id: int,
			_key: Variant,
			_metadata: Dictionary
		) -> void:
			signal_state["queued_count"] = (
				GFVariantData.get_option_int(signal_state, "queued_count")
				+ 1
			)
	) as Error
	assert_eq(connect_error, OK)
	var before_snapshot: Dictionary = gate.get_debug_snapshot()
	var before_event_count: int = gate.get_recent_events().size()
	var before_request_id: int = gate.get_next_request_id()
	var before_pump_cursor: int = gate.get_pump_key_cursor()

	var same_key_result: Dictionary = gate.try_request_lease(&"asset")
	var other_key_result: Dictionary = gate.try_request_lease(&"other")
	var after_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(same_key_result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"同 key 已有活跃租约和 waiter 时应立即返回 busy。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(other_key_result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"全局租约容量耗尽时其它 key 也应立即返回 busy。"
	)
	assert_eq(
		GFVariantData.get_option_int(same_key_result, "request_id"),
		0,
		"busy 不得分配请求 ID。"
	)
	assert_false(same_key_result.has("completion"), "busy 不得分配 completion。")
	assert_false(same_key_result.has("lease"), "busy 不得分配 lease。")
	assert_eq(
		GFVariantData.get_option_int(signal_state, "queued_count"),
		0,
		"fail-fast 拒绝不得发出排队信号。"
	)
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "queued_count"),
		GFVariantData.get_option_int(before_snapshot, "queued_count"),
		"fail-fast 拒绝不得改变等待队列。"
	)
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "key_count"),
		GFVariantData.get_option_int(before_snapshot, "key_count"),
		"全局繁忙时不得为探测 key 建立跟踪状态。"
	)
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "busy_count"),
		2,
		"调试快照应累计 fail-fast busy 次数。"
	)
	assert_eq(
		gate.get_recent_events().size(),
		before_event_count,
		"busy 不是请求生命周期事件，不应写入事件环。"
	)
	assert_eq(gate.get_next_request_id(), before_request_id)
	assert_eq(gate.get_pump_key_cursor(), before_pump_cursor)

	assert_true(blocker.release(&"done"))
	assert_true(waiting_completion.is_successful())
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")


func test_keyed_gate_try_request_respects_per_key_active_limit() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_active_leases = 2
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"asset")
	)
	var before_snapshot: Dictionary = gate.get_debug_snapshot()
	var before_request_id: int = gate.get_next_request_id()
	var before_event_count: int = gate.get_recent_events().size()

	var result: Dictionary = gate.try_request_lease(&"asset")
	var after_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_int(before_snapshot, "active_count"),
		1,
		"测试前提应保留一个未耗尽全局容量的活跃租约。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"全局仍有空位但同 key 达到并发上限时应返回 busy。"
	)
	assert_eq(GFVariantData.get_option_int(result, "request_id"), 0)
	assert_false(result.has("completion"))
	assert_false(result.has("lease"))
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "queued_count"),
		GFVariantData.get_option_int(before_snapshot, "queued_count")
	)
	assert_eq(gate.get_next_request_id(), before_request_id)
	assert_eq(gate.get_recent_events().size(), before_event_count)

	var waiting: Dictionary = gate.request_lease(&"asset")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var unrelated_lease: GFAsyncGateLease = _result_to_lease(
		gate.try_request_lease(&"other")
	)
	assert_true(
		unrelated_lease != null,
		"仅被自身 key 上限阻塞的 waiter 不得浪费其它 key 可用的全局槽位。"
	)
	assert_true(unrelated_lease.release(&"done"))
	assert_true(blocker.release(&"done"))
	assert_true(waiting_completion.is_successful())
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")


func test_keyed_gate_try_request_respects_tracked_key_capacity_without_request_state() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_tracked_keys = 1
	assert_eq(gate.set_key_max_concurrency(&"reserved", 1), 1)
	var before_snapshot: Dictionary = gate.get_debug_snapshot()
	var before_request_id: int = gate.get_next_request_id()
	var before_event_count: int = gate.get_recent_events().size()

	var result: Dictionary = gate.try_request_lease(&"new")
	var after_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"tracked key 容量耗尽时 fail-fast 请求应返回 busy。"
	)
	assert_eq(GFVariantData.get_option_int(result, "request_id"), 0)
	assert_false(result.has("completion"))
	assert_false(result.has("lease"))
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "key_count"),
		GFVariantData.get_option_int(before_snapshot, "key_count"),
		"容量探测不得创建新 key 状态。"
	)
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "busy_count"),
		GFVariantData.get_option_int(before_snapshot, "busy_count") + 1
	)
	assert_eq(gate.get_next_request_id(), before_request_id)
	assert_eq(gate.get_recent_events().size(), before_event_count)


func test_keyed_gate_try_request_reports_pre_cancelled_token() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(source.cancel(&"caller_cancelled", { "scope": "try" }))

	var result: Dictionary = gate.try_request_lease(&"asset", {
		"cancel_token": source.get_token(),
	})
	var snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_CANCELLED,
		"可即时提交但 token 已取消时应返回真实 cancelled 终态。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		&"caller_cancelled"
	)
	assert_gt(
		GFVariantData.get_option_int(result, "request_id"),
		0,
		"cancelled 表示 token 赢得了一个已接受请求的提交竞态。"
	)
	assert_false(GFVariantData.get_option_bool(result, "queued"))
	assert_false(result.has("completion"))
	assert_false(result.has("lease"))
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1)


func test_keyed_gate_try_request_does_not_overtake_cross_key_waiter() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_active_leases = 2
	gate.max_pump_work_items = 1
	var first_lease: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"first")
	)
	assert_eq(gate.set_key_max_concurrency(&"second", 2), 2)
	var second_lease: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"second")
	)
	var waiting: Dictionary = gate.request_lease(&"second")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)

	assert_true(first_lease.release(&"done"))
	assert_true(
		gate.is_deferred_pump_scheduled(),
		"有界推进先扫描空 slot 后应保留旧 waiter 的 continuation。"
	)
	assert_eq(
		GFVariantData.get_option_int(gate.get_debug_snapshot(), "active_count"),
		1,
		"释放后应存在一个可被错误窃取的全局空闲槽位。"
	)

	var result: Dictionary = gate.try_request_lease(&"third")

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"fail-fast 请求不得越过其它 key 尚未完成的公平推进周期。"
	)
	assert_eq(GFVariantData.get_option_int(result, "request_id"), 0)
	assert_false(result.has("completion"))
	assert_false(result.has("lease"))

	assert_true(second_lease.release(&"done"))
	assert_true(waiting_completion.is_successful())
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")
	await get_tree().process_frame


func test_keyed_gate_try_request_ignores_stale_continuation_after_last_waiter_cancel() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_active_leases = 2
	gate.max_pump_work_items = 1
	var first_lease: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"first")
	)
	assert_eq(gate.set_key_max_concurrency(&"second", 2), 2)
	var second_lease: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"second")
	)
	var waiting: Dictionary = gate.request_lease(&"second")

	assert_true(first_lease.release(&"done"))
	assert_true(gate.is_deferred_pump_scheduled())
	assert_true(
		gate.cancel_request(
			GFVariantData.get_option_int(waiting, "request_id"),
			&"withdrawn"
		)
	)
	assert_eq(
		GFVariantData.get_option_int(gate.get_debug_snapshot(), "queued_count"),
		0,
		"取消最后一个 waiter 后应立即清空权威等待状态。"
	)

	var result: Dictionary = gate.try_request_lease(&"third")
	var third_lease: GFAsyncGateLease = _result_to_lease(result)

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_ACQUIRED,
		"没有真实 waiter 时，旧 deferred 标志不得制造假 busy。"
	)
	assert_true(third_lease != null)

	assert_true(second_lease.release(&"done"))
	assert_true(third_lease.release(&"done"))
	await get_tree().process_frame


func test_keyed_gate_try_request_does_not_commit_inside_lifecycle_notification() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 2
	var callback_state: Dictionary = {
		"queued_count": 0,
		"result": {},
	}
	var queued_error: Error = gate.request_queued.connect(
		func(
			_request_id: int,
			_key: Variant,
			_metadata: Dictionary
		) -> void:
			callback_state["queued_count"] = (
				GFVariantData.get_option_int(callback_state, "queued_count")
				+ 1
			)
	) as Error
	assert_eq(queued_error, OK)
	var acquired_error: Error = gate.lease_acquired.connect(
		func(_lease: GFAsyncGateLease) -> void:
			callback_state["result"] = gate.try_request_lease(&"callback"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(acquired_error, OK)

	var outer_result: Dictionary = gate.try_request_lease(&"outer")
	var outer_lease: GFAsyncGateLease = _result_to_lease(outer_result)
	var outer_completion: GFAsyncCompletion = _result_to_completion(outer_result)
	var after_callback_result: Dictionary = gate.try_request_lease(&"callback")
	var callback_lease: GFAsyncGateLease = _result_to_lease(
		after_callback_result
	)
	var callback_result: Dictionary = GFVariantData.get_option_dictionary(
		callback_state,
		"result"
	)

	assert_true(outer_lease != null, "空闲 gate 的 fail-fast 请求应立即取得租约。")
	assert_true(
		outer_completion != null and outer_completion.is_successful(),
		"acquired 结果应保留与 request_lease 一致的已完成 completion。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(callback_result, "status"),
		GFAsyncKeyedGate.STATUS_BUSY,
		"acquire 通知内不得重入提交另一租约。"
	)
	assert_true(
		callback_lease != null,
		"最外层通知结束后同一请求应能立即取得剩余槽位。"
	)
	assert_eq(
		GFVariantData.get_option_int(callback_state, "queued_count"),
		0,
		"两个 fail-fast 请求都不得进入等待队列。"
	)
	assert_eq(
		GFVariantData.get_option_int(gate.get_debug_snapshot(), "busy_count"),
		1
	)

	var _outer_released: bool = outer_lease.release(&"done")
	var _callback_released: bool = callback_lease.release(&"done")


func test_keyed_gate_rejects_foreign_lease_with_colliding_local_id() -> void:
	var first_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var second_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var first_lease: GFAsyncGateLease = _result_to_lease(
		first_gate.request_lease(&"first")
	)
	var second_lease: GFAsyncGateLease = _result_to_lease(
		second_gate.request_lease(&"second")
	)

	assert_eq(first_lease.get_lease_id(), second_lease.get_lease_id())
	assert_false(
		first_gate.release_lease(second_lease, &"foreign"),
		"Gate 必须同时校验 lease ID 与对象身份。"
	)
	assert_true(first_lease.is_active())
	assert_true(second_lease.is_active())
	assert_eq(
		GFVariantData.get_option_int(
			first_gate.get_debug_snapshot(),
			"active_count"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(
			second_gate.get_debug_snapshot(),
			"active_count"
		),
		1
	)
	var _first_released: bool = first_lease.release(&"done")
	var _second_released: bool = second_lease.release(&"done")


func test_released_lease_does_not_retain_owning_gate() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var gate_reference: WeakRef = weakref(gate)
	var lease: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"lifetime"))

	assert_true(lease.release(&"done"))
	gate = null

	assert_true(
		gate_reference.get_ref() == null,
		"租约终态必须断开绑定 Gate 的 release callback。"
	)


func test_keyed_gate_returns_terminal_cancel_state_after_queued_signal_reentrancy() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"signal_cancel"))
	var connect_error: Error = gate.request_queued.connect(
		func(request_id: int, _key: Variant, _metadata: Dictionary) -> void:
			var _cancelled: bool = gate.cancel_request(
				request_id,
				&"listener_cancelled"
			),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var result: Dictionary = gate.request_lease(&"signal_cancel")
	var result_request_id: int = GFVariantData.get_option_int(result, "request_id")
	var request_events: Array[StringName] = []
	for event: Dictionary in gate.get_recent_events():
		if GFVariantData.get_option_int(event, "request_id") == result_request_id:
			request_events.append(
				GFVariantData.get_option_string_name(event, "event_type")
			)

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_CANCELLED,
		"同步排队观察者取消请求后，入口不得返回过期 queued 状态。"
	)
	assert_false(GFVariantData.get_option_bool(result, "queued"))
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		&"listener_cancelled"
	)
	assert_eq(
		request_events,
		[&"request_queued", &"request_cancelled"],
		"排队事件必须在由其触发的终态事件之前提交。"
	)
	assert_eq(
		GFVariantData.get_option_int(gate.get_debug_snapshot(), "queued_count"),
		0
	)
	var _released: bool = blocker.release(&"done")


func test_keyed_gate_returns_acquired_state_after_queued_signal_releases_slot() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"signal_release"))
	var connect_error: Error = gate.request_queued.connect(
		func(_request_id: int, _key: Variant, _metadata: Dictionary) -> void:
			var _listener_released: bool = blocker.release(&"listener_release"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var result: Dictionary = gate.request_lease(&"signal_release")
	var lease: GFAsyncGateLease = _result_to_lease(result)

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_ACQUIRED,
		"同步排队观察者释放槽位后，入口应返回已经提交的 acquired 状态。"
	)
	assert_true(lease != null and lease.is_active())
	assert_false(blocker.is_active())
	var _released: bool = lease.release(&"done")


func test_keyed_gate_closes_cancel_token_bind_window_without_lost_wakeup() -> void:
	var gate: CancelDuringTokenBindGate = CancelDuringTokenBindGate.new()
	var immediate_token: GFCancellationToken = GFCancellationToken.new()
	var immediate_result: Dictionary = gate.request_lease(&"immediate_bind_window", {
		"cancel_token": immediate_token,
	})

	assert_eq(
		GFVariantData.get_option_string_name(immediate_result, "status"),
		GFAsyncKeyedGate.STATUS_CANCELLED,
		"立即取得租约的路径也必须在订阅后复查取消状态。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(immediate_result, "reason"),
		&"bind_window_cancelled"
	)

	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"bind_window"))
	var token: GFCancellationToken = GFCancellationToken.new()

	var result: Dictionary = gate.request_lease(&"bind_window", {
		"cancel_token": token,
	})
	var snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_CANCELLED
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		&"bind_window_cancelled"
	)
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 2)
	var _released: bool = blocker.release(&"done")


func test_keyed_gate_fails_closed_when_cancel_token_subscription_fails() -> void:
	var gate: FailingTokenBindGate = FailingTokenBindGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"bind_failure"))
	var token: GFCancellationToken = GFCancellationToken.new()

	var result: Dictionary = gate.request_lease(&"bind_failure", {
		"cancel_token": token,
	})

	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncKeyedGate.STATUS_INVALID
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		GFAsyncKeyedGate.REASON_CANCEL_TOKEN_CONNECT_FAILED
	)
	assert_eq(
		GFVariantData.get_option_int(gate.get_debug_snapshot(), "queued_count"),
		0
	)
	var _released: bool = blocker.release(&"done")


func test_keyed_gate_cancels_waiting_requests_and_expires_active_leases() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"save"))
	var source: GFCancellationSource = GFCancellationSource.new()

	var waiting: Dictionary = gate.request_lease(&"save", {
		"cancel_token": source.get_token(),
	})
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var _cancelled: bool = source.cancel(&"user_cancelled", { "scope": "test" })

	assert_true(waiting_completion.is_cancelled(), "取消 token 应取消等待中的请求。")
	assert_eq(waiting_completion.get_cancel_reason(), &"user_cancelled", "等待请求应保留取消原因。")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "cancelled_count"), 1, "gate 应统计取消请求。")

	var timed_wait: Dictionary = gate.request_lease(&"save", {
		"timeout_msec": 1,
	})
	var timed_completion: GFAsyncCompletion = _result_to_completion(timed_wait)
	var expired_waiting: int = gate.expire_waiting_requests(Time.get_ticks_msec() + 100)
	assert_eq(expired_waiting, 1, "显式过期应清理等待超时请求。")
	assert_true(timed_completion.is_cancelled(), "等待超时应以取消终态完成 completion。")
	assert_eq(timed_completion.get_cancel_reason(), GFAsyncKeyedGate.STATUS_TIMEOUT, "等待超时应使用稳定 timeout 原因。")

	assert_true(blocker.release(&"done"), "释放阻塞租约应成功。")
	var expiring: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"save", {
		"lease_timeout_msec": 1,
	}))
	var expired_active: int = gate.expire_active_leases(Time.get_ticks_msec() + 100)
	assert_eq(expired_active, 1, "活跃租约超时应被释放。")
	assert_false(expiring.is_active(), "超时释放后租约不应继续 active。")
	assert_eq(expiring.get_release_reason(), GFAsyncKeyedGate.STATUS_TIMEOUT, "活跃租约超时释放应记录 timeout 原因。")


func test_keyed_gate_saturates_extreme_wait_and_lease_deadlines() -> void:
	var max_msec: int = 9_223_372_036_854_775_807
	var waiting_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(
		waiting_gate.request_lease(&"extreme_wait")
	)
	var waiting_result: Dictionary = waiting_gate.request_lease(
		&"extreme_wait",
		{ "timeout_msec": max_msec }
	)
	var waiting_completion: GFAsyncCompletion = _result_to_completion(
		waiting_result
	)

	assert_eq(
		waiting_gate.expire_waiting_requests(max_msec),
		1,
		"极大正等待超时必须饱和到可比较 deadline，不能回绕成永久等待。"
	)
	assert_true(waiting_completion.is_cancelled())
	assert_eq(
		waiting_completion.get_cancel_reason(),
		GFAsyncKeyedGate.STATUS_TIMEOUT
	)
	var _blocker_released: bool = blocker.release(&"done")

	var active_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var expiring_lease: GFAsyncGateLease = _result_to_lease(
		active_gate.request_lease(
			&"extreme_lease",
			{ "lease_timeout_msec": max_msec }
		)
	)

	assert_eq(
		active_gate.expire_active_leases(max_msec),
		1,
		"极大正租约超时必须饱和到可比较 deadline，不能回绕成永久租约。"
	)
	assert_false(expiring_lease.is_active())
	assert_eq(
		expiring_lease.get_release_reason(),
		GFAsyncKeyedGate.STATUS_TIMEOUT
	)


func test_keyed_gate_async_wait_timeout_removes_queued_request() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"save"))
	var timed_out_lease: GFAsyncGateLease = await gate.wait_for_lease_async(&"save", {
		"wait_options": {
			"tree": get_tree(),
			"timeout_seconds": 0.01,
		},
	})

	assert_true(blocker != null and blocker.is_active(), "阻塞租约应保持 active。")
	assert_null(timed_out_lease, "等待超时后不应返回租约。")
	assert_eq(GFVariantData.get_option_int(gate.get_key_snapshot(&"save"), "queued_count"), 0, "等待超时应清理排队请求。")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "cancelled_count"), 1, "等待超时应计入取消统计。")


func test_keyed_gate_prunes_transient_keys_after_release_but_keeps_explicit_limits() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var transient: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"transient"))
	var _released: bool = transient.release(&"done")

	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 0, "无队列、无租约、无显式配置的 key 应被裁剪。")

	var _limit: int = gate.set_key_max_concurrency(&"configured", 2)
	var configured: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"configured"))
	var _configured_released: bool = configured.release(&"done")

	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 1, "显式配置过并发限制的 key 应保留。")
	assert_eq(GFVariantData.get_option_int(gate.get_key_snapshot(&"configured"), "max_concurrency"), 2, "裁剪不应丢失显式 key 限制。")


func test_keyed_gate_request_limit_is_transient_and_fifo() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.default_max_concurrency = 3

	var first: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"download", {
		"max_concurrency": 1,
	}))
	var second: Dictionary = gate.request_lease(&"download", {
		"max_concurrency": 1,
	})
	var third: Dictionary = gate.request_lease(&"download")
	var second_completion: GFAsyncCompletion = _result_to_completion(second)
	var third_completion: GFAsyncCompletion = _result_to_completion(third)

	assert_true(first != null and first.is_active(), "首个请求应立即获得租约。")
	assert_true(second_completion != null and second_completion.is_pending(), "请求级限额应让第二个同 key 请求排队。")
	assert_true(third_completion != null and third_completion.is_pending(), "队列应保持 FIFO，不跳过头部限额请求。")

	var _first_released: bool = first.release(&"done")
	assert_true(second_completion.is_successful(), "释放头部租约后第二个请求应被推进。")
	assert_false(third_completion.is_successful(), "第三个请求不能越过第二个请求的单次限额。")

	var second_result: Dictionary = GFVariantData.as_dictionary(second_completion.get_result())
	var second_lease: GFAsyncGateLease = _result_to_lease(second_result)
	var _second_released: bool = second_lease.release(&"done")
	assert_true(third_completion.is_successful(), "第二个请求释放后第三个请求应被推进。")

	var third_result: Dictionary = GFVariantData.as_dictionary(third_completion.get_result())
	var third_lease: GFAsyncGateLease = _result_to_lease(third_result)
	var _third_released: bool = third_lease.release(&"done")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 0, "请求级 max_concurrency 不应留下持久 key limit。")


func test_keyed_gate_can_clear_explicit_key_limits() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var _configured: int = gate.set_key_max_concurrency(&"configured", 2)
	var configured: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"configured"))
	var _released: bool = configured.release(&"done")

	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 1, "显式限额应保留 key。")
	assert_true(gate.clear_key_max_concurrency(&"configured"), "应能清理单个显式 key 限额。")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 0, "清理显式限额后空闲 key 应被裁剪。")

	var _first_limit: int = gate.set_key_max_concurrency(&"first", 2)
	var _second_limit: int = gate.set_key_max_concurrency(&"second", 2)
	assert_eq(gate.clear_all_key_max_concurrency(), 2, "应报告被清理的显式 key 限额数量。")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 0, "批量清理后不应保留空闲 key。")


func test_keyed_gate_rejects_unstable_keys() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var unstable_key: Dictionary = { "id": 1 }

	var result: Dictionary = gate.request_lease(unstable_key)
	var snapshot: Dictionary = gate.get_key_snapshot(unstable_key)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "可变 Dictionary key 应被明确拒绝。")
	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncKeyedGate.STATUS_INVALID, "无效 key 应返回 invalid 状态。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"unstable_key", "无效 key 原因应稳定。")
	assert_eq(GFVariantData.get_option_int(gate.get_debug_snapshot(), "key_count"), 0, "无效 key 不应注册到 gate。")
	assert_eq(gate.set_key_max_concurrency(unstable_key, 2), 0, "无效 key 不应保存并发限制。")
	assert_false(gate.has_key_activity(unstable_key), "无效 key 不应产生活动状态。")
	assert_false(GFVariantData.get_option_bool(snapshot, "ok", true), "无效 key 快照应结构化报告失败。")


func test_keyed_gate_bounds_total_and_per_key_waiting_requests() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_waiting_requests = 1
	gate.max_waiting_per_key = 1

	var asset_blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"asset"))
	var asset_waiting: Dictionary = gate.request_lease(&"asset")
	var asset_completion: GFAsyncCompletion = _result_to_completion(asset_waiting)
	var per_key_rejected: Dictionary = gate.request_lease(&"asset")

	assert_true(asset_blocker != null, "首个 asset 请求应立即获得租约。")
	assert_true(asset_completion != null and asset_completion.is_pending(), "容量内等待请求应排队。")
	assert_eq(
		GFVariantData.get_option_string_name(per_key_rejected, "status"),
		GFAsyncKeyedGate.STATUS_REJECTED,
		"单 key 等待容量耗尽应稳定拒绝。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(per_key_rejected, "reason"),
		GFAsyncKeyedGate.REASON_MAX_WAITING_PER_KEY,
		"单 key 容量拒绝应返回稳定原因。"
	)

	var other_blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"other"))
	var total_rejected: Dictionary = gate.request_lease(&"other")
	var snapshot: Dictionary = gate.get_debug_snapshot()

	assert_true(other_blocker != null, "等待总容量耗尽不应阻止不同 key 的立即租约。")
	assert_eq(
		GFVariantData.get_option_string_name(total_rejected, "reason"),
		GFAsyncKeyedGate.REASON_MAX_WAITING_REQUESTS,
		"等待总容量耗尽应返回稳定原因。"
	)
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 1, "被拒绝请求不得进入等待队列。")
	assert_eq(GFVariantData.get_option_int(snapshot, "high_watermark"), 1, "快照应记录等待高水位。")
	assert_eq(GFVariantData.get_option_int(snapshot, "rejected_count"), 2, "快照应累计容量拒绝。")
	assert_eq(GFVariantData.get_option_int(snapshot, "dropped_count"), 0, "gate 不得静默丢弃请求。")

	var _asset_released: bool = asset_blocker.release(&"done")
	var promoted_result: Dictionary = GFVariantData.as_dictionary(asset_completion.get_result())
	var promoted_lease: GFAsyncGateLease = _result_to_lease(promoted_result)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")
	var _other_released: bool = other_blocker.release(&"done")


func test_keyed_gate_bounds_tracked_key_cardinality() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_tracked_keys = 1

	var first_lease: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"first"))
	var rejected: Dictionary = gate.request_lease(&"second")
	var saturated_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_true(first_lease != null, "容量内第一个 key 应获得租约。")
	assert_eq(
		GFVariantData.get_option_string_name(rejected, "reason"),
		GFAsyncKeyedGate.REASON_MAX_TRACKED_KEYS,
		"key 基数耗尽应返回稳定原因。"
	)
	assert_eq(GFVariantData.get_option_int(saturated_snapshot, "key_count"), 1, "拒绝不得注册额外 key。")
	assert_eq(GFVariantData.get_option_int(saturated_snapshot, "key_high_watermark"), 1, "快照应记录 key 高水位。")
	assert_eq(gate.set_key_max_concurrency(&"configured", 2), 0, "显式 key 配置也必须遵守基数预算。")

	var _first_released: bool = first_lease.release(&"done")
	var second_lease: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"second"))
	assert_true(second_lease != null, "旧 key 释放并裁剪后应允许新 key。")
	if second_lease != null:
		var _second_released: bool = second_lease.release(&"done")


func test_keyed_gate_bounds_active_leases_and_clamps_all_capacities() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.default_max_concurrency = 2_147_483_647
	gate.max_recent_events = 2_147_483_647
	gate.max_active_leases = 2_147_483_647
	gate.max_waiting_requests = 2_147_483_647
	gate.max_waiting_per_key = 2_147_483_647
	gate.max_tracked_keys = 2_147_483_647
	gate.max_pump_work_items = 2_147_483_647
	assert_eq(
		gate.default_max_concurrency,
		GFAsyncKeyedGate.ABSOLUTE_MAX_CONCURRENCY
	)
	assert_eq(
		gate.max_recent_events,
		GFAsyncKeyedGate.ABSOLUTE_MAX_RECENT_EVENTS
	)
	assert_eq(
		gate.max_active_leases,
		GFAsyncKeyedGate.ABSOLUTE_MAX_ACTIVE_LEASES
	)
	assert_eq(
		gate.max_waiting_requests,
		GFAsyncKeyedGate.ABSOLUTE_MAX_WAITING_REQUESTS
	)
	assert_eq(
		gate.max_waiting_per_key,
		GFAsyncKeyedGate.ABSOLUTE_MAX_WAITING_PER_KEY
	)
	assert_eq(
		gate.max_tracked_keys,
		GFAsyncKeyedGate.ABSOLUTE_MAX_TRACKED_KEYS
	)
	assert_eq(
		gate.max_pump_work_items,
		GFAsyncKeyedGate.ABSOLUTE_MAX_PUMP_WORK_ITEMS
	)
	assert_eq(
		gate.set_key_max_concurrency(&"clamped", 2_147_483_647),
		GFAsyncKeyedGate.ABSOLUTE_MAX_CONCURRENCY
	)

	var bounded_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	bounded_gate.max_active_leases = 1
	var first_lease: GFAsyncGateLease = _result_to_lease(
		bounded_gate.request_lease(&"first")
	)
	var second_result: Dictionary = bounded_gate.request_lease(&"second")
	var second_completion: GFAsyncCompletion = _result_to_completion(
		second_result
	)
	assert_true(first_lease != null)
	assert_true(
		second_completion != null and second_completion.is_pending(),
		"全局 active lease 容量耗尽时请求必须进入有界等待队列。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			bounded_gate.get_debug_snapshot(),
			"active_count"
		),
		1
	)
	var _first_released: bool = first_lease.release(&"done")
	assert_true(
		second_completion.is_successful(),
		"释放全局槽位后必须推进其他 key 的等待请求。"
	)
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(second_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")


func test_keyed_gate_bounds_release_pump_work_including_expired_requests() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_pump_work_items = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"pump_budget")
	)
	for _index: int in range(3):
		var queued: Dictionary = gate.request_lease(&"pump_budget", {
			"timeout_msec": 1,
		})
		assert_eq(
			GFVariantData.get_option_string_name(queued, "status"),
			GFAsyncKeyedGate.STATUS_QUEUED
		)
	var expiration_target_msec: int = Time.get_ticks_msec() + 2
	while Time.get_ticks_msec() < expiration_target_msec:
		await get_tree().process_frame

	var _released: bool = blocker.release(&"done")
	var immediate_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_int(immediate_snapshot, "timeout_count"),
		1,
		"同步 release 最多只能消费一个已过期等待请求。"
	)
	assert_eq(
		GFVariantData.get_option_int(immediate_snapshot, "queued_count"),
		2,
		"剩余工作应留给延迟推进或显式过期扫描。"
	)
	for _frame_index: int in range(4):
		await get_tree().process_frame
	var final_snapshot: Dictionary = gate.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(final_snapshot, "timeout_count"),
		3,
		"延迟 continuation 应在后续主线程迭代内完成剩余有界工作。"
	)
	assert_eq(
		GFVariantData.get_option_int(final_snapshot, "queued_count"),
		0
	)


func test_keyed_gate_bounds_expiry_scans_with_persistent_cursors() -> void:
	var waiting_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	waiting_gate.max_pump_work_items = 2
	var blocker: GFAsyncGateLease = _result_to_lease(
		waiting_gate.request_lease(&"waiting_expiry_budget")
	)
	for _request_index: int in range(5):
		var queued: Dictionary = waiting_gate.request_lease(
			&"waiting_expiry_budget",
			{ "timeout_msec": 1 }
		)
		assert_eq(
			GFVariantData.get_option_string_name(queued, "status"),
			GFAsyncKeyedGate.STATUS_QUEUED
		)
	var expiry_now: int = Time.get_ticks_msec() + 100

	for _scan_index: int in range(5):
		var expired_in_scan: int = waiting_gate.expire_waiting_requests(
			expiry_now
		)
		assert_lte(
			expired_in_scan,
			waiting_gate.max_pump_work_items,
			"显式等待过期扫描不得越过单次工作预算。"
		)
		if (
			GFVariantData.get_option_int(
				waiting_gate.get_debug_snapshot(),
				"timeout_count"
			) >= 5
		):
			break
	var waiting_snapshot: Dictionary = waiting_gate.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(waiting_snapshot, "timeout_count"),
		5
	)
	assert_eq(
		GFVariantData.get_option_int(waiting_snapshot, "queued_count"),
		0
	)
	var _blocker_released: bool = blocker.release(&"done")

	var active_gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	active_gate.max_pump_work_items = 2
	for lease_index: int in range(5):
		var lease: GFAsyncGateLease = _result_to_lease(
			active_gate.request_lease(
				StringName("active_expiry_%d" % lease_index),
				{ "lease_timeout_msec": 1 }
			)
		)
		assert_true(lease != null and lease.is_active())

	assert_eq(active_gate.expire_active_leases(expiry_now), 2)
	assert_eq(active_gate.expire_active_leases(expiry_now), 2)
	assert_eq(active_gate.expire_active_leases(expiry_now), 1)
	assert_eq(
		GFVariantData.get_option_int(
			active_gate.get_debug_snapshot(),
			"active_count"
		),
		0
	)


func test_keyed_gate_continues_for_request_enqueued_inside_pump_completion() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 2
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"pump_reentrant")
	)
	var waiting: Dictionary = gate.request_lease(&"pump_reentrant")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var reentrant_state: Dictionary = {}
	var connect_error: Error = waiting_completion.succeeded.connect(
		func(_result: Variant, _metadata: Dictionary) -> void:
			reentrant_state["request"] = gate.request_lease(&"other_key"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	assert_true(blocker.release(&"done"))
	var reentrant_request: Dictionary = GFVariantData.get_option_dictionary(
		reentrant_state,
		"request"
	)
	var reentrant_completion: GFAsyncCompletion = _result_to_completion(
		reentrant_request
	)
	assert_eq(
		GFVariantData.get_option_string_name(reentrant_request, "status"),
		GFAsyncKeyedGate.STATUS_QUEUED
	)
	assert_true(
		reentrant_completion != null and reentrant_completion.is_pending()
	)

	await get_tree().process_frame

	assert_true(
		reentrant_completion.is_successful(),
		"泵内 completion 新增且仍有全局容量的请求必须由 continuation 推进。"
	)
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	var reentrant_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(reentrant_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")
	if reentrant_lease != null:
		var _reentrant_released: bool = reentrant_lease.release(&"done")


func test_keyed_gate_stops_deferred_scan_after_one_no_progress_cycle() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	gate.max_pump_work_items = 1
	gate.max_active_leases = 2
	var _blocked_limit: int = gate.set_key_max_concurrency(&"blocked", 1)
	var _empty_a_limit: int = gate.set_key_max_concurrency(&"empty_a", 1)
	var _empty_b_limit: int = gate.set_key_max_concurrency(&"empty_b", 1)
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"blocked")
	)
	var waiting: Dictionary = gate.request_lease(&"blocked")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)

	gate.max_active_leases = 2
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(
		gate.is_deferred_pump_scheduled(),
		"完整扫描一轮没有推进时不得继续自调度。"
	)
	assert_eq(gate.get_scan_remaining_keys(), 0)
	assert_true(waiting_completion.is_pending())

	assert_true(blocker.release(&"done"))
	await get_tree().process_frame
	assert_true(waiting_completion.is_successful())
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")


func test_keyed_gate_release_notification_cannot_steal_slot_from_old_waiter() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"old_key")
	)
	var waiting: Dictionary = gate.request_lease(&"old_key")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var reentrant_state: Dictionary = {}
	var connect_error: Error = gate.lease_released.connect(
		func(released_lease: GFAsyncGateLease, _reason: StringName) -> void:
			if released_lease == blocker:
				reentrant_state["request"] = gate.request_lease(&"new_key"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	assert_true(blocker.release(&"done"))
	var reentrant_request: Dictionary = GFVariantData.get_option_dictionary(
		reentrant_state,
		"request"
	)
	var reentrant_completion: GFAsyncCompletion = _result_to_completion(
		reentrant_request
	)

	assert_true(
		waiting_completion.is_successful(),
		"释放通知之前已排队的请求应先取得刚释放的全局槽位。"
	)
	assert_true(
		reentrant_completion != null and reentrant_completion.is_pending(),
		"释放通知中新请求只能排队，不能同步窃取槽位。"
	)

	var old_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	assert_true(old_lease.release(&"done"))
	assert_true(reentrant_completion.is_successful())
	var new_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(reentrant_completion.get_result())
	)
	if new_lease != null:
		var _new_released: bool = new_lease.release(&"done")


func test_keyed_gate_continues_new_release_listener_request_after_cutoff() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"released_key")
	)
	var listener_state: Dictionary = {}
	var connect_error: Error = gate.lease_released.connect(
		func(released_lease: GFAsyncGateLease, _reason: StringName) -> void:
			if released_lease == blocker:
				listener_state["request"] = gate.request_lease(&"listener_key"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	assert_true(blocker.release(&"done"))
	var listener_request: Dictionary = GFVariantData.get_option_dictionary(
		listener_state,
		"request"
	)
	var listener_completion: GFAsyncCompletion = _result_to_completion(
		listener_request
	)
	assert_eq(
		GFVariantData.get_option_string_name(listener_request, "status"),
		GFAsyncKeyedGate.STATUS_QUEUED
	)
	assert_true(
		listener_completion != null and listener_completion.is_pending(),
		"通知中新请求不得进入冻结的旧 cutoff 周期。"
	)

	await get_tree().process_frame

	assert_true(
		listener_completion.is_successful(),
		"旧 cutoff 完整结束后必须启动 fresh continuation。"
	)
	var listener_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(listener_completion.get_result())
	)
	if listener_lease != null:
		var _listener_released: bool = listener_lease.release(&"done")


func test_keyed_gate_shares_one_cancel_subscription_and_detaches_batch() -> void:
	var gate: PumpProbeGate = PumpProbeGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"shared_token")
	)
	var source: GFCancellationSource = GFCancellationSource.new()
	var token: GFCancellationToken = source.get_token()
	var completions: Array[GFAsyncCompletion] = []
	var observed_queued_counts: Array[int] = []
	for _request_index: int in range(32):
		var waiting: Dictionary = gate.request_lease(&"shared_token", {
			"cancel_token": token,
		})
		var completion: GFAsyncCompletion = _result_to_completion(waiting)
		completions.append(completion)
		var connect_error: Error = completion.cancelled.connect(
			func(_reason: StringName, _metadata: Dictionary) -> void:
				observed_queued_counts.append(
					GFVariantData.get_option_int(
						gate.get_debug_snapshot(),
						"queued_count"
					)
				),
			CONNECT_ONE_SHOT
		) as Error
		assert_eq(connect_error, OK)

	assert_eq(gate.token_connect_count, 1)
	assert_eq(gate.get_shared_token_request_count(token), 32)
	assert_eq(token.cancel_requested.get_connections().size(), 1)
	assert_true(source.cancel(&"shared_cancel", { "scope": "batch" }))

	for completion: GFAsyncCompletion in completions:
		assert_true(completion.is_cancelled())
		assert_eq(completion.get_cancel_reason(), &"shared_cancel")
	assert_eq(observed_queued_counts.size(), 32)
	for queued_count: int in observed_queued_counts:
		assert_eq(
			queued_count,
			0,
			"共享 token 必须先事务式摘除整批权威队列，再通知完成。"
		)
	assert_eq(
		GFVariantData.get_option_int(
			gate.get_debug_snapshot(),
			"queued_count"
		),
		0
	)
	var _blocker_released: bool = blocker.release(&"done")


func test_keyed_gate_commits_acquire_then_release_lifecycle_order() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"notification_order")
	)
	var waiting: Dictionary = gate.request_lease(&"notification_order")
	var target_request_id: int = GFVariantData.get_option_int(
		waiting,
		"request_id"
	)
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var events: Array[StringName] = []
	var promoted_state: Dictionary = {}
	var completion_error: Error = waiting_completion.succeeded.connect(
		func(result: Variant, _metadata: Dictionary) -> void:
			events.append(&"completion")
			var callback_lease: GFAsyncGateLease = _result_to_lease(
				GFVariantData.as_dictionary(result)
			)
			promoted_state["lease"] = callback_lease
			var _released_error: Error = callback_lease.released.connect(
				func(_lease: GFAsyncGateLease, _reason: StringName) -> void:
					events.append(&"lease_released"),
				CONNECT_ONE_SHOT
			) as Error
			var _release_requested: bool = callback_lease.release(
				&"completion_release"
			),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(completion_error, OK)
	var acquired_error: Error = gate.lease_acquired.connect(
		func(acquired_lease: GFAsyncGateLease) -> void:
			if acquired_lease.get_request_id() == target_request_id:
				events.append(&"acquired"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(acquired_error, OK)
	var released_error: Error = gate.lease_released.connect(
		func(released_lease: GFAsyncGateLease, _reason: StringName) -> void:
			if released_lease.get_request_id() == target_request_id:
				events.append(&"gate_released")
	) as Error
	assert_eq(released_error, OK)

	assert_true(blocker.release(&"done"))
	var promoted: GFAsyncGateLease = null
	var promoted_value: Variant = GFVariantData.get_option_value(
		promoted_state,
		"lease"
	)
	if promoted_value is GFAsyncGateLease:
		promoted = promoted_value
	var request_events: Array[StringName] = []
	for event: Dictionary in gate.get_recent_events():
		if GFVariantData.get_option_int(event, "request_id") == target_request_id:
			request_events.append(
				GFVariantData.get_option_string_name(event, "event_type")
			)

	assert_eq(
		events,
		[
			&"completion",
			&"acquired",
			&"lease_released",
			&"gate_released",
		],
		"释放请求必须等 acquire completion 与 signal 全部通知后再发释放通知。"
	)
	assert_eq(
		request_events,
		[
			&"request_queued",
			&"lease_acquired",
			&"lease_released",
		],
		"诊断事件必须先提交 acquired，再提交 released。"
	)
	assert_true(promoted != null and not promoted.is_active())
	assert_false(
		GFVariantData.get_option_bool(
			promoted.get_debug_snapshot(),
			"release_pending"
		)
	)


func test_keyed_gate_rotates_global_slot_across_hot_keys() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 1

	var first_hot_lease: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"hot")
	)
	var second_hot_result: Dictionary = gate.request_lease(&"hot")
	var cold_result: Dictionary = gate.request_lease(&"cold")
	var second_hot_completion: GFAsyncCompletion = _result_to_completion(
		second_hot_result
	)
	var cold_completion: GFAsyncCompletion = _result_to_completion(cold_result)

	assert_true(first_hot_lease != null)
	assert_true(second_hot_completion != null and second_hot_completion.is_pending())
	assert_true(cold_completion != null and cold_completion.is_pending())

	var _first_hot_released: bool = first_hot_lease.release(&"done")
	assert_true(
		second_hot_completion.is_successful(),
		"首轮可从稳定游标位置推进 hot key。"
	)
	assert_true(cold_completion.is_pending())
	var second_hot_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(second_hot_completion.get_result())
	)
	var third_hot_result: Dictionary = gate.request_lease(&"hot")
	var third_hot_completion: GFAsyncCompletion = _result_to_completion(
		third_hot_result
	)

	var _second_hot_released: bool = second_hot_lease.release(&"done")
	assert_true(
		cold_completion.is_successful(),
		"持续补入的 hot key 不得无限抢占唯一全局槽位。"
	)
	assert_true(
		third_hot_completion != null and third_hot_completion.is_pending(),
		"轮转应先让不同 key 取得进展。"
	)

	var cold_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(cold_completion.get_result())
	)
	var _cold_released: bool = cold_lease.release(&"done")
	assert_true(third_hot_completion.is_successful())
	var third_hot_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(third_hot_completion.get_result())
	)
	if third_hot_lease != null:
		var _third_hot_released: bool = third_hot_lease.release(&"done")


func test_keyed_gate_defers_reentrant_requests_beyond_pump_snapshot() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	gate.max_active_leases = 1
	var blocker: GFAsyncGateLease = _result_to_lease(
		gate.request_lease(&"shared")
	)
	var waiting_result: Dictionary = gate.request_lease(&"shared")
	var waiting_completion: GFAsyncCompletion = _result_to_completion(
		waiting_result
	)
	var callback_state: Dictionary = {
		"callback_count": 0,
	}
	var connect_error: Error = waiting_completion.succeeded.connect(
		func(
			completion_result: Variant,
			_metadata: Dictionary
		) -> void:
			callback_state["callback_count"] = (
				GFVariantData.get_option_int(
					callback_state,
					"callback_count"
				)
				+ 1
			)
			var acquired_result: Dictionary = GFVariantData.as_dictionary(
				completion_result
			)
			var acquired_lease: GFAsyncGateLease = _result_to_lease(
				acquired_result
			)
			callback_state["released"] = acquired_lease.release(
				&"reentrant_release"
			)
			callback_state["request"] = gate.request_lease(&"shared"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var _blocker_released: bool = blocker.release(&"done")
	var reentrant_result: Dictionary = GFVariantData.get_option_dictionary(
		callback_state,
		"request"
	)
	var reentrant_completion: GFAsyncCompletion = _result_to_completion(
		reentrant_result
	)
	var immediate_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_int(callback_state, "callback_count"),
		1,
		"同一等待请求只能完成一次。"
	)
	assert_true(
		GFVariantData.get_option_bool(callback_state, "released"),
		"完成回调应能重入释放刚取得的 lease。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(
			reentrant_result,
			"status"
		),
		GFAsyncKeyedGate.STATUS_QUEUED,
		"泵回调中新建的请求不得进入当前快照。"
	)
	assert_true(
		reentrant_completion != null and reentrant_completion.is_pending()
	)
	assert_eq(
		GFVariantData.get_option_int(immediate_snapshot, "active_count"),
		0,
		"重入释放后当前泵不得递归激活新请求。"
	)
	assert_eq(
		GFVariantData.get_option_int(immediate_snapshot, "queued_count"),
		1
	)

	await get_tree().process_frame

	assert_true(
		reentrant_completion.is_successful(),
		"重入请求应由后续主线程推进点取得进展。"
	)
	var reentrant_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(reentrant_completion.get_result())
	)
	if reentrant_lease != null:
		var _released: bool = reentrant_lease.release(&"done")


func test_keyed_gate_rejects_worker_thread_public_access_without_mutation() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var _configured: int = gate.set_key_max_concurrency(&"thread", 1)
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"thread", {
		"lease_timeout_msec": 100_000,
	}))
	var waiting: Dictionary = gate.request_lease(&"thread", {
		"timeout_msec": 100_000,
	})
	var waiting_completion: GFAsyncCompletion = _result_to_completion(waiting)
	var before_snapshot: Dictionary = gate.get_debug_snapshot()
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(self, &"_access_keyed_gate_from_worker").bind(
			gate,
			blocker,
			GFVariantData.get_option_int(waiting, "request_id")
		)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	var worker_value: Variant = worker.wait_to_finish()
	var worker_result: Dictionary = GFVariantData.as_dictionary(worker_value)
	var request_result: Dictionary = GFVariantData.get_option_dictionary(
		worker_result,
		"request"
	)
	var try_result: Dictionary = GFVariantData.get_option_dictionary(
		worker_result,
		"try_request"
	)
	var key_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		worker_result,
		"key_snapshot"
	)
	var debug_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		worker_result,
		"debug_snapshot"
	)
	var after_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(request_result, "reason"),
		&"wrong_thread",
		"worker 请求应返回稳定线程拒绝原因。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(try_result, "reason"),
		&"wrong_thread",
		"worker fail-fast 请求也应返回稳定线程拒绝原因。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(key_snapshot, "reason"),
		&"wrong_thread",
		"worker key 快照不得读取 gate 状态。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(debug_snapshot, "reason"),
		&"wrong_thread",
		"worker 调试快照不得读取 gate 状态。"
	)
	assert_eq(GFVariantData.get_option_int(worker_result, "default_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "recent_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "active_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "waiting_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "per_key_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "tracked_limit"), 0)
	assert_false(GFVariantData.get_option_bool(worker_result, "released"))
	assert_false(GFVariantData.get_option_bool(worker_result, "cancelled"))
	assert_eq(GFVariantData.get_option_int(worker_result, "cleared"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "set_limit"), 0)
	assert_false(GFVariantData.get_option_bool(worker_result, "clear_limit"))
	assert_eq(GFVariantData.get_option_int(worker_result, "clear_all_limits"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "get_limit"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "expired_waiting"), 0)
	assert_eq(GFVariantData.get_option_int(worker_result, "expired_active"), 0)
	assert_false(GFVariantData.get_option_bool(worker_result, "has_activity"))
	assert_eq(GFVariantData.get_option_array(worker_result, "events"), [])
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "queued_count"),
		GFVariantData.get_option_int(before_snapshot, "queued_count"),
		"worker 调用不得改变等待计数。"
	)
	assert_eq(
		GFVariantData.get_option_int(after_snapshot, "active_count"),
		GFVariantData.get_option_int(before_snapshot, "active_count"),
		"worker 调用不得改变活跃计数。"
	)
	assert_eq(gate.default_max_concurrency, GFAsyncKeyedGate.DEFAULT_MAX_CONCURRENCY)
	assert_eq(gate.max_recent_events, GFAsyncKeyedGate.DEFAULT_MAX_RECENT_EVENTS)
	assert_eq(gate.max_active_leases, GFAsyncKeyedGate.DEFAULT_MAX_ACTIVE_LEASES)
	assert_eq(gate.max_waiting_requests, GFAsyncKeyedGate.DEFAULT_MAX_WAITING_REQUESTS)
	assert_eq(gate.max_waiting_per_key, GFAsyncKeyedGate.DEFAULT_MAX_WAITING_PER_KEY)
	assert_eq(gate.max_tracked_keys, GFAsyncKeyedGate.DEFAULT_MAX_TRACKED_KEYS)
	assert_true(waiting_completion != null and waiting_completion.is_pending())

	var _blocker_released: bool = blocker.release(&"done")
	var promoted_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(waiting_completion.get_result())
	)
	if promoted_lease != null:
		var _promoted_released: bool = promoted_lease.release(&"done")
	var _limit_cleared: bool = gate.clear_key_max_concurrency(&"thread")


func test_keyed_gate_hands_worker_token_cancellation_to_main_thread() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"cancel"))
	var token: GFCancellationToken = GFCancellationToken.new()
	var waiting: Dictionary = gate.request_lease(&"cancel", {
		"cancel_token": token,
	})
	var completion: GFAsyncCompletion = _result_to_completion(waiting)
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(self, &"_cancel_token_from_worker").bind(token)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	var worker_value: Variant = worker.wait_to_finish()
	var worker_cancelled: bool = false
	if worker_value is bool:
		var typed_worker_cancelled: bool = worker_value
		worker_cancelled = typed_worker_cancelled
	assert_true(worker_cancelled, "worker 应能触发测试 token 的取消终态。")

	await get_tree().process_frame

	assert_true(completion != null and completion.is_cancelled(), "worker token 取消应在主线程完成等待请求。")
	assert_eq(completion.get_cancel_reason(), &"worker_cancelled")
	assert_eq(
		GFVariantData.get_option_string(completion.get_metadata(), "scope"),
		"worker"
	)
	var snapshot: Dictionary = gate.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1)
	var _released: bool = blocker.release(&"done")


func test_keyed_gate_clear_commits_queue_state_before_reentrant_completion() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"clear"))
	var waiting: Dictionary = gate.request_lease(&"clear")
	var completion: GFAsyncCompletion = _result_to_completion(waiting)
	var reentrant_state: Dictionary = {}
	var connect_error: Error = completion.cancelled.connect(
		func(_reason: StringName, _metadata: Dictionary) -> void:
			reentrant_state["request"] = gate.request_lease(&"clear"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var affected: int = gate.clear(&"test_clear")
	var reentrant_request: Dictionary = GFVariantData.get_option_dictionary(
		reentrant_state,
		"request"
	)
	var reentrant_completion: GFAsyncCompletion = _result_to_completion(
		reentrant_request
	)
	var snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(affected, 2, "clear 只应报告调用时已经存在的请求与租约。")
	assert_eq(
		GFVariantData.get_option_string_name(reentrant_request, "status"),
		GFAsyncKeyedGate.STATUS_QUEUED,
		"完成回调中的同 key 请求应观察到已经提交的空队列。"
	)
	assert_true(
		reentrant_completion != null and reentrant_completion.is_pending(),
		"clear 不应夹带 key 扫描；重入请求应交给延迟有界推进。"
	)
	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "released_count"), 1)

	await get_tree().process_frame

	assert_true(
		reentrant_completion.is_successful(),
		"延迟 continuation 必须推进 clear 通知中新建的请求。"
	)
	var reentrant_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(reentrant_completion.get_result())
	)
	if reentrant_lease != null:
		var _released: bool = reentrant_lease.release(&"done")
	assert_false(blocker.is_active())


func test_keyed_gate_expiry_commits_queue_state_before_reentrant_completion() -> void:
	var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
	var blocker: GFAsyncGateLease = _result_to_lease(gate.request_lease(&"expiry"))
	var expiring: Dictionary = gate.request_lease(&"expiry", {
		"timeout_msec": 1,
	})
	var completion: GFAsyncCompletion = _result_to_completion(expiring)
	var reentrant_state: Dictionary = {}
	var connect_error: Error = completion.cancelled.connect(
		func(_reason: StringName, _metadata: Dictionary) -> void:
			reentrant_state["request"] = gate.request_lease(&"expiry"),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var expired_count: int = gate.expire_waiting_requests(
		Time.get_ticks_msec() + 100
	)
	var reentrant_request: Dictionary = GFVariantData.get_option_dictionary(
		reentrant_state,
		"request"
	)
	var reentrant_completion: GFAsyncCompletion = _result_to_completion(
		reentrant_request
	)
	var waiting_snapshot: Dictionary = gate.get_debug_snapshot()

	assert_eq(expired_count, 1)
	assert_eq(
		GFVariantData.get_option_string_name(reentrant_request, "status"),
		GFAsyncKeyedGate.STATUS_QUEUED
	)
	assert_true(
		reentrant_completion != null and reentrant_completion.is_pending(),
		"重入请求必须保留在新队列中。"
	)
	assert_eq(GFVariantData.get_option_int(waiting_snapshot, "queued_count"), 1)
	assert_eq(GFVariantData.get_option_int(waiting_snapshot, "timeout_count"), 1)

	var _blocker_released: bool = blocker.release(&"done")
	assert_true(reentrant_completion.is_successful(), "释放槽位后应正常推进重入请求。")
	var reentrant_lease: GFAsyncGateLease = _result_to_lease(
		GFVariantData.as_dictionary(reentrant_completion.get_result())
	)
	if reentrant_lease != null:
		var _released: bool = reentrant_lease.release(&"done")
	var final_snapshot: Dictionary = gate.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(final_snapshot, "queued_count"), 0)
	assert_eq(GFVariantData.get_option_int(final_snapshot, "active_count"), 0)
	assert_eq(GFVariantData.get_option_int(final_snapshot, "key_count"), 0)


func test_request_handler_registry_keeps_single_handler_contract() -> void:
	var registry: GFRequestHandlerRegistry = GFRequestHandlerRegistry.new()
	var handler: Callable = func(request: Dictionary) -> Dictionary:
		var payload: Dictionary = GFVariantData.get_option_dictionary(request, "payload")
		return {
			"value": GFVariantData.get_option_int(payload, "value") + 1,
			"sequence": GFVariantData.get_option_int(request, "sequence"),
		}

	var registered: Dictionary = registry.register_handler(&"config.resolve", handler, {
		"metadata": { "scope": "test" },
	})
	assert_true(GFVariantData.get_option_bool(registered, "ok"), "首次注册应成功。")
	assert_true(registry.has_handler(&"config.resolve"), "注册后应能查询 handler。")

	var duplicate_result: Dictionary = registry.register_handler(&"config.resolve", handler)
	assert_eq(GFVariantData.get_option_string_name(duplicate_result, "status"), GFRequestHandlerRegistry.STATUS_DUPLICATE, "重复注册默认应被拒绝。")

	var invoked: Dictionary = registry.invoke(&"config.resolve", { "value": 4 }, { "caller": "unit" })
	var invoked_result: Dictionary = GFVariantData.get_option_dictionary(invoked, "result")
	assert_true(GFVariantData.get_option_bool(invoked, "ok"), "有 handler 时 invoke 应成功。")
	assert_eq(GFVariantData.get_option_int(invoked_result, "value"), 5, "handler 应收到 payload 并返回结果。")

	var missing: Dictionary = registry.try_invoke(&"config.missing")
	assert_eq(GFVariantData.get_option_string_name(missing, "status"), GFRequestHandlerRegistry.STATUS_MISSING, "try_invoke 缺少 handler 应返回 missing。")
	assert_true(GFVariantData.get_option_bool(missing, "missing_allowed"), "try_invoke 应标记缺失是可预期结果。")

	var snapshot: Dictionary = registry.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "invoked_count"), 1, "注册表应统计成功调用次数。")
	assert_eq(GFVariantData.get_option_int(snapshot, "duplicate_count"), 1, "注册表应统计重复注册。")


func test_request_handler_registry_does_not_restore_handler_unregistered_during_invoke() -> void:
	var registry: GFRequestHandlerRegistry = GFRequestHandlerRegistry.new()
	var unregister_results: Array[Dictionary] = [{}]
	var handler: Callable = func(_request: Dictionary) -> String:
		unregister_results[0] = registry.unregister_handler(&"config.once")
		return "handled"
	var _registered: Dictionary = registry.register_handler(&"config.once", handler)

	var invoked: Dictionary = registry.invoke(&"config.once")

	assert_true(GFVariantData.get_option_bool(invoked, "ok"), "当前调用应正常完成。")
	assert_eq(GFVariantData.get_option_string(invoked, "result"), "handled", "当前调用结果不应因注销丢失。")
	assert_true(GFVariantData.get_option_bool(unregister_results[0], "ok"), "handler 内注销应成功。")
	assert_false(registry.has_handler(&"config.once"), "外层调用不得把已注销 entry 写回。")
	assert_eq(
		GFVariantData.get_option_string_name(registry.try_invoke(&"config.once"), "status"),
		GFRequestHandlerRegistry.STATUS_MISSING,
		"后续调用必须观察到注销结果。"
	)


func test_request_handler_registry_does_not_overwrite_replacement_registered_during_invoke() -> void:
	var registry: GFRequestHandlerRegistry = GFRequestHandlerRegistry.new()
	var replacement_call_count: Array[int] = [0]
	var replacement: Callable = func(_request: Dictionary) -> String:
		replacement_call_count[0] += 1
		return "replacement"
	var replace_results: Array[Dictionary] = [{}]
	var original: Callable = func(_request: Dictionary) -> String:
		replace_results[0] = registry.register_handler(
			&"config.resolve",
			replacement,
			{ "replace": true }
		)
		return "original"
	var _registered: Dictionary = registry.register_handler(&"config.resolve", original)

	var first_result: Dictionary = registry.invoke(&"config.resolve")
	var replacement_snapshot: Dictionary = registry.get_handler_snapshot(&"config.resolve")
	var second_result: Dictionary = registry.invoke(&"config.resolve")

	assert_eq(GFVariantData.get_option_string(first_result, "result"), "original", "当前调用应返回原 handler 结果。")
	assert_true(GFVariantData.get_option_bool(replace_results[0], "ok"), "handler 内 replace 应成功。")
	assert_eq(
		GFVariantData.get_option_int(replacement_snapshot, "invocation_count"),
		0,
		"原 handler 的统计不得覆盖新 registration。"
	)
	assert_eq(GFVariantData.get_option_string(second_result, "result"), "replacement", "后续调用必须命中新 handler。")
	assert_eq(replacement_call_count[0], 1, "新 handler 应只处理后续调用。")


func test_request_handler_registry_json_compatible_reports_sanitize_runtime_values() -> void:
	var registry: GFRequestHandlerRegistry = GFRequestHandlerRegistry.new()
	var resource_value: Resource = Resource.new()
	var handler: Callable = func(_request: Dictionary) -> Dictionary:
		return {
			"resource": resource_value,
			"value": NAN,
			"bytes": PackedByteArray([1, 2, 3]),
			"callback": Callable(self, "get_script"),
		}
	var _registered: Dictionary = registry.register_handler(&"diagnostics.snapshot", handler, {
		"metadata": {
			"resource": resource_value,
			"value": NAN,
		},
	})

	var invoked: Dictionary = registry.invoke(&"diagnostics.snapshot", {}, {
		"resource": resource_value,
		"value": NAN,
	})
	var safe_result: Dictionary = GFRequestHandlerRegistry.to_json_compatible_result(invoked)
	var safe_snapshot: Dictionary = registry.get_json_compatible_debug_snapshot()
	var safe_events: Array[Dictionary] = registry.get_json_compatible_recent_events()
	var json_text: String = JSON.stringify({
		"result": safe_result,
		"snapshot": safe_snapshot,
		"events": safe_events,
	})

	assert_false(json_text.contains(":null"), "JSON-safe 请求报告不应把 NaN 直接交给 JSON.stringify。")
	assert_true(json_text.contains("__gf_report_value__"), "运行时对象和 Callable 应被报告 marker 脱敏。")
	assert_false(GFVariantData.get_option_value(safe_result, "result") is Resource, "JSON-safe 结果不应泄漏 Resource。")


func test_execution_lane_diagnostics_records_counts_and_health() -> void:
	var diagnostics: RefCounted = GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.new()

	var queued: Dictionary = GFVariantData.as_dictionary(diagnostics.call(
		"record_lane_event",
		&"assets",
		GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.EVENT_QUEUED,
		{ "metadata": { "path": "res://a.tres" } }
	))
	assert_eq(GFVariantData.get_option_int(queued, "queued_count"), 1, "queued 事件应增加排队数量。")

	var started: Dictionary = GFVariantData.as_dictionary(diagnostics.call(
		"record_lane_event",
		&"assets",
		GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.EVENT_STARTED
	))
	assert_eq(GFVariantData.get_option_int(started, "queued_count"), 0, "started 事件默认应消费一个排队项。")
	assert_eq(GFVariantData.get_option_int(started, "active_count"), 1, "started 事件应增加 active。")

	var completed: Dictionary = GFVariantData.as_dictionary(diagnostics.call(
		"record_lane_event",
		&"assets",
		GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.EVENT_COMPLETED
	))
	assert_eq(GFVariantData.get_option_int(completed, "active_count"), 0, "completed 事件应释放 active。")
	assert_eq(GFVariantData.get_option_int(completed, "completed_count"), 1, "completed 事件应计数。")

	var timed_out: Dictionary = GFVariantData.as_dictionary(diagnostics.call(
		"record_lane_event",
		&"assets",
		GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.EVENT_TIMEOUT
	))
	assert_eq(GFVariantData.get_option_string_name(timed_out, "status"), GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.STATUS_ERROR, "timeout 后 lane 应进入 error 健康状态。")

	var health: Dictionary = GFVariantData.as_dictionary(diagnostics.call("get_health_snapshot"))
	assert_eq(GFVariantData.get_option_string_name(health, "status"), GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT.STATUS_ERROR, "整体健康应聚合最严重 lane 状态。")
	assert_eq(GFVariantData.get_option_int(health, "timeout_count"), 1, "整体健康应聚合 timeout 数量。")


func _access_keyed_gate_from_worker(
	gate: GFAsyncKeyedGate,
	lease: GFAsyncGateLease,
	waiting_request_id: int
) -> Dictionary:
	var default_limit: int = gate.default_max_concurrency
	var recent_limit: int = gate.max_recent_events
	var active_limit: int = gate.max_active_leases
	var waiting_limit: int = gate.max_waiting_requests
	var per_key_limit: int = gate.max_waiting_per_key
	var tracked_limit: int = gate.max_tracked_keys
	gate.default_max_concurrency = 2
	gate.max_recent_events = 1
	gate.max_active_leases = 1
	gate.max_waiting_requests = 1
	gate.max_waiting_per_key = 1
	gate.max_tracked_keys = 1
	var request_result: Dictionary = gate.request_lease(&"worker")
	var try_result: Dictionary = gate.try_request_lease(&"worker")
	var released: bool = gate.release_lease(lease, &"worker")
	var cancelled: bool = gate.cancel_request(waiting_request_id, &"worker")
	var cleared: int = gate.clear(&"worker")
	var set_limit: int = gate.set_key_max_concurrency(&"worker", 2)
	var clear_limit: bool = gate.clear_key_max_concurrency(&"thread")
	var clear_all_limits: int = gate.clear_all_key_max_concurrency()
	var get_limit: int = gate.get_key_max_concurrency(&"thread")
	var expired_waiting: int = gate.expire_waiting_requests(2_147_483_647)
	var expired_active: int = gate.expire_active_leases(2_147_483_647)
	var has_activity: bool = gate.has_key_activity(&"thread")
	var key_snapshot: Dictionary = gate.get_key_snapshot(&"thread")
	var events: Array[Dictionary] = gate.get_recent_events()
	var debug_snapshot: Dictionary = gate.get_debug_snapshot()
	return {
		"default_limit": default_limit,
		"recent_limit": recent_limit,
		"active_limit": active_limit,
		"waiting_limit": waiting_limit,
		"per_key_limit": per_key_limit,
		"tracked_limit": tracked_limit,
		"request": request_result,
		"try_request": try_result,
		"released": released,
		"cancelled": cancelled,
		"cleared": cleared,
		"set_limit": set_limit,
		"clear_limit": clear_limit,
		"clear_all_limits": clear_all_limits,
		"get_limit": get_limit,
		"expired_waiting": expired_waiting,
		"expired_active": expired_active,
		"has_activity": has_activity,
		"key_snapshot": key_snapshot,
		"events": events,
		"debug_snapshot": debug_snapshot,
	}


func _cancel_token_from_worker(token: GFCancellationToken) -> bool:
	return token.request_cancel_internal(
		&"worker_cancelled",
		{ "scope": "worker" }
	)


func _result_to_lease(result: Dictionary) -> GFAsyncGateLease:
	var value: Variant = GFVariantData.get_option_value(result, "lease")
	if value is GFAsyncGateLease:
		var lease: GFAsyncGateLease = value
		return lease
	return null


func _result_to_completion(result: Dictionary) -> GFAsyncCompletion:
	var value: Variant = GFVariantData.get_option_value(result, "completion")
	if value is GFAsyncCompletion:
		var completion: GFAsyncCompletion = value
		return completion
	return null
