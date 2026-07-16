extends GutTest

const GF_EXECUTION_LANE_DIAGNOSTICS_SCRIPT = preload("res://addons/gf/standard/common/gf_execution_lane_diagnostics.gd")


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
