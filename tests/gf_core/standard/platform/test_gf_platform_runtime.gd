## 测试平台 adapter 注册、显式路由和请求终态所有权。
extends GutTest


# --- 测试方法 ---

func test_runtime_initializes_adapter_and_routes_single_candidate() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new()
	var adapter: PlatformAdapterFixture = _make_adapter(&"primary", &"sample", true)
	watch_signals(runtime)

	assert_true(runtime.register_adapter(adapter), "已配置 adapter 应能注册。")
	var initialization: GFAsyncCompletion = runtime.initialize_adapter(&"primary")
	var handle: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "hello"}
	)
	var result: GFPlatformBridgeResult = handle.get_result()

	assert_true(initialization.is_successful(), "同步测试 adapter 应完成初始化。")
	assert_true(handle.is_successful(), "唯一候选 adapter 应被确定性路由。")
	assert_not_null(result, "成功请求应返回强类型结果。")
	assert_eq(result.contract_id, &"platform.share", "结果应绑定原请求契约。")
	assert_eq(result.method_id, &"share", "结果应绑定原请求方法。")
	assert_signal_emit_count(runtime, "request_started", 1, "每次调用应发出一次开始信号。")
	assert_signal_emit_count(runtime, "request_completed", 1, "同步终态也应发出一次完成信号。")
	runtime.dispose()


func test_runtime_canonicalizes_request_and_explicit_adapter_ids() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new()
	var adapter: PlatformAdapterFixture = _make_adapter(&"canonical_adapter", &"sample", false)
	assert_true(runtime.register_adapter(adapter))
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"canonical_adapter")
	var request: GFPlatformBridgeRequest = GFPlatformBridgeRequest.new()
	request.request_id = &" canonical_runtime_request "
	request.contract_id = &" platform.share "
	request.method_id = &" hold "
	var handle: GFPlatformRequestHandle = runtime.invoke(request, &" canonical_adapter ")

	assert_true(handle.is_pending(), "显式 Adapter 与请求 ID 的空白变体应在入口统一规范化。")
	assert_eq(handle.get_request_id(), &"canonical_runtime_request")
	var duplicate_handle: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"hold",
		{},
		{"request_id": &"canonical_runtime_request"}
	)
	assert_eq(duplicate_handle.get_result().status, &"duplicate_request_id")
	assert_true(
		runtime.cancel_request(&" canonical_runtime_request "),
		"按 ID 操作必须使用同一规范身份。"
	)
	assert_true(runtime.set_contract_route(&" platform.share ", &" canonical_adapter "))
	assert_eq(runtime.get_contract_route(&"platform.share"), &"canonical_adapter")
	runtime.dispose()


func test_runtime_requires_explicit_route_for_multiple_candidates() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new()
	var first: PlatformAdapterFixture = _make_adapter(&"first", &"sample", true)
	var second: PlatformAdapterFixture = _make_adapter(&"second", &"sample", true)
	assert_true(runtime.register_adapter(first), "第一个 adapter 应能注册。")
	assert_true(runtime.register_adapter(second), "同契约第二个 adapter 应作为候选注册。")
	var _first_initialized: GFAsyncCompletion = runtime.initialize_adapter(&"first")
	var _second_initialized: GFAsyncCompletion = runtime.initialize_adapter(&"second")

	var ambiguous: GFPlatformRequestHandle = runtime.invoke_contract(&"platform.share", &"share")
	var ambiguous_result: GFPlatformBridgeResult = ambiguous.get_result()
	assert_false(ambiguous.is_successful(), "多个候选时不得按注册顺序猜测 adapter。")
	assert_eq(ambiguous_result.status, &"ambiguous_adapter", "歧义应有稳定失败状态。")

	assert_true(runtime.set_contract_route(&"platform.share", &"second"), "显式路由应接受支持该契约的 adapter。")
	var routed: GFPlatformRequestHandle = runtime.invoke_contract(&"platform.share", &"share")
	var routed_payload: Dictionary = GFVariantData.to_dictionary(routed.get_result().value)
	assert_true(routed.is_successful(), "消除歧义后请求应成功。")
	assert_eq(GFVariantData.get_option_string_name(routed_payload, "adapter_id"), &"second")
	runtime.dispose()


func test_pending_request_has_single_cancel_terminal_state() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new()
	var adapter: PlatformAdapterFixture = _make_adapter(&"pending", &"sample", false)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"pending")
	watch_signals(runtime)

	var handle: GFPlatformRequestHandle = runtime.invoke_contract(&"platform.share", &"hold")
	assert_true(handle.is_pending(), "异步 adapter 接受后请求应保持 pending。")
	assert_true(runtime.cancel_request(handle.get_request_id(), &"user_cancelled"), "等待请求应能取消。")
	assert_false(runtime.cancel_request(handle.get_request_id(), &"again"), "终态请求不得再次取消。")
	var result: GFPlatformBridgeResult = handle.get_result()

	assert_eq(result.status, &"user_cancelled", "取消原因应成为稳定终态状态。")
	assert_eq(adapter.cancel_count, 1, "底层 adapter 只应收到一次取消通知。")
	assert_signal_emit_count(runtime, "request_completed", 1, "取消只应发出一次完成事件。")
	runtime.dispose()


func test_request_handle_rejects_inconsistent_preconstructed_terminal_results() -> void:
	var request: GFPlatformBridgeRequest = GFPlatformBridgeRequest.new().configure(
		&"terminal_contract",
		&"platform.share",
		&"share"
	)
	var clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	var success_with_error: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_success(
		request,
		null,
		&"ok",
		1000,
		1000
	)
	success_with_error.error = "unexpected"
	var failure_with_value: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_failure(
		request,
		"failed",
		&"failed",
		1000,
		1000
	)
	failure_with_value.value = "unexpected"
	var invalid_results: Array[GFPlatformBridgeResult] = [
		GFPlatformBridgeResult.new().configure_success(request, null, &"", 1000, 1000),
		success_with_error,
		GFPlatformBridgeResult.new().configure_failure(request, "", &"failed", 1000, 1000),
		failure_with_value,
		GFPlatformBridgeResult.new().configure_success(request, null, &"ok", 1000, 999),
		GFPlatformBridgeResult.new().configure_success(request, null, &"ok", 999, 1000),
		GFPlatformBridgeResult.new().configure_success(request, null, &"ok", 1000, 1001),
	]

	for invalid_result: GFPlatformBridgeResult in invalid_results:
		var handle: GFPlatformRequestHandle = GFPlatformRequestHandle.new()
		watch_signals(handle)
		assert_true(
			handle.configure_from_platform_layer(request, clock, 1000),
			"每个反例都应先建立同一 pending 请求。"
		)

		assert_false(
			handle.resolve_from_platform_layer(invalid_result),
			"身份匹配但终态字段矛盾的预构造结果必须失败关闭。"
		)
		assert_true(handle.is_pending(), "拒绝坏结果不得消费唯一终态。")
		assert_signal_not_emitted(handle, "completed", "拒绝坏结果不得发出完成信号。")
		assert_true(
			handle.succeed_from_platform_layer({"accepted": true}),
			"拒绝坏结果后仍应允许一次合法终态。"
		)
		assert_signal_emit_count(handle, "completed", 1, "合法终态只能发出一次完成信号。")


func test_pending_request_times_out_and_notifies_adapter() -> void:
	var clock: GFManualClock = GFManualClock.new(1000000, 1700000000000)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(clock)
	var adapter: PlatformAdapterFixture = _make_adapter(&"timeout", &"sample", false)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"timeout")
	var handle: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"hold",
		{},
		{"timeout_msec": 1}
	)

	assert_true(clock.advance_msec(1), "平台超时测试应由手动单调时钟推进。")
	runtime.tick(0.0)
	var result: GFPlatformBridgeResult = handle.get_result()

	assert_not_null(result, "超时应生成终态结果。")
	assert_eq(result.status, &"timed_out", "超时应使用稳定状态。")
	assert_eq(result.get_duration_msec(), 1, "结果耗时应使用同一注入时钟。")
	assert_eq(adapter.cancel_count, 1, "超时应通知 adapter 停止底层请求。")
	runtime.dispose()


func test_request_deadline_saturates_at_int64_max() -> void:
	var clock: ExtremeClock = ExtremeClock.new(9_223_372_036_854_775_806)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(clock)
	var adapter: PlatformAdapterFixture = _make_adapter(&"saturated_deadline", &"sample", false)
	assert_true(runtime.register_adapter(adapter))
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"saturated_deadline")
	var handle: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"hold",
		{},
		{"timeout_msec": 10}
	)

	runtime.tick(0.0)
	assert_true(handle.is_pending(), "极大正 timeout 不得回绕成永久等待或立即终态。")
	clock.now_msec = 9_223_372_036_854_775_807
	runtime.tick(0.0)
	assert_eq(handle.get_result().status, &"timed_out", "饱和 deadline 到达时仍应正常超时。")
	assert_eq(handle.get_result().get_duration_msec(), 1)
	runtime.dispose()


func test_runtime_forwards_context_and_monotonic_lifecycle_events() -> void:
	var clock: GFManualClock = GFManualClock.new(2000000, 1700000000000)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(clock)
	var adapter: PlatformAdapterFixture = _make_adapter(&"events", &"sample", true)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"events")
	watch_signals(runtime)
	var lifecycle_events: Array[GFPlatformLifecycleEvent] = []
	var connect_error: Error = runtime.lifecycle_event.connect(
		func(_adapter_id: StringName, event: GFPlatformLifecycleEvent) -> void:
			lifecycle_events.append(event)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听生命周期事件。")

	assert_true(adapter.publish_capability(&"cloud_storage"), "Adapter 应能发布新能力上下文。")
	assert_true(adapter.publish_background_event(), "Adapter 应能发布第一个生命周期事件。")
	assert_true(clock.advance_msec(5), "测试时钟应在事件间推进。")
	assert_true(adapter.publish_background_event(), "Adapter 应能发布第二个生命周期事件。")

	assert_true(runtime.has_capability(&"cloud_storage", &"events"), "运行时应查询指定 adapter 能力。")
	assert_signal_emit_count(runtime, "context_changed", 1, "上下文更新应转发一次。")
	assert_signal_emit_count(runtime, "lifecycle_event", 2, "生命周期事件应逐次转发。")
	assert_eq(adapter.last_sequence, 2, "Adapter 应为生命周期事件分配严格单调序号。")
	assert_eq(lifecycle_events.size(), 2, "测试应捕获两个生命周期事件。")
	assert_eq(lifecycle_events[0].timestamp_msec, 2000, "首个事件应由 adapter 使用统一时钟盖章。")
	assert_eq(lifecycle_events[1].timestamp_msec, 2005, "第二个事件应反映手动推进。")
	runtime.dispose()


func test_runtime_rejects_clock_replacement_while_request_is_pending() -> void:
	var first_clock: GFManualClock = GFManualClock.new(1000000, 1700000000000)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(first_clock)
	var adapter: PlatformAdapterFixture = _make_adapter(&"pending_clock", &"sample", false)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"pending_clock")
	var handle: GFPlatformRequestHandle = runtime.invoke_contract(&"platform.share", &"hold")

	assert_true(handle.is_pending(), "测试请求应保持等待。")
	assert_false(
		runtime.set_clock(GFManualClock.new(9000000, 1800000000000)),
		"存在等待请求时不得切换截止时间域。"
	)
	assert_same(runtime.get_clock(), first_clock, "拒绝替换后应保留原时钟。")

	assert_true(runtime.cancel_request(handle.get_request_id()), "清理测试请求应成功。")
	var second_clock: GFManualClock = GFManualClock.new(9000000, 1800000000000)
	assert_true(runtime.set_clock(second_clock), "请求结束后应能切换时钟。")
	assert_same(runtime.get_clock(), second_clock, "运行时应持有新时钟。")
	runtime.dispose()


func test_runtime_rejects_registration_when_adapter_has_provider_request_lease() -> void:
	var adapter: PlatformAdapterFixture = _make_adapter(&"leased_before_register", &"sample", false)
	var _initialized: GFAsyncCompletion = adapter.initialize()
	var direct_handle: GFPlatformRequestHandle = adapter.invoke(
		GFPlatformBridgeRequest.new().configure(
			&"direct_before_register",
			&"platform.share",
			&"hold"
		)
	)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(
		GFManualClock.new(9000000, 1800000000000)
	)

	assert_true(direct_handle.is_pending(), "直接调用应持有 Provider 请求租约。")
	assert_false(
		runtime.register_adapter(adapter),
		"注册不得替换已有 Provider 请求使用的时钟域。"
	)
	assert_true(runtime.get_adapter_ids().is_empty(), "时钟注入失败后不得留下半注册 Adapter。")

	adapter.shutdown()
	runtime.dispose()


func test_runtime_rejects_clock_replacement_for_direct_adapter_request() -> void:
	var first_clock: GFManualClock = GFManualClock.new(1000000, 1700000000000)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(first_clock)
	var adapter: PlatformAdapterFixture = _make_adapter(&"direct_clock_lease", &"sample", false)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"direct_clock_lease")
	var direct_handle: GFPlatformRequestHandle = adapter.invoke(
		GFPlatformBridgeRequest.new().configure(
			&"direct_registered_request",
			&"platform.share",
			&"hold"
		)
	)

	assert_true(direct_handle.is_pending(), "直接调用应保持等待。")
	assert_false(
		runtime.set_clock(GFManualClock.new(9000000, 1800000000000)),
		"Runtime 未跟踪的 Adapter Provider 租约也必须阻止时钟替换。"
	)
	assert_same(runtime.get_clock(), first_clock, "失败的事务式时钟替换不得改变 Runtime 时钟。")

	runtime.dispose()


func test_request_started_reentry_cannot_reuse_reserved_request_id() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new()
	var adapter: PlatformAdapterFixture = _make_adapter(&"reentrant", &"sample", false)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"reentrant")
	var nested_handles: Array[GFPlatformRequestHandle] = []
	var started_callback: Callable = (
		func(_adapter_id: StringName, _request: GFPlatformBridgeRequest) -> void:
			nested_handles.append(runtime.invoke_contract(
				&"platform.share",
				&"hold",
				{},
				{"request_id": &"same_request"}
			))
	)
	var connected: Error = runtime.request_started.connect(started_callback) as Error
	assert_eq(connected, OK, "测试应监听开始信号。")

	var original: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"hold",
		{},
		{"request_id": &"same_request"}
	)

	assert_true(original.is_pending(), "原请求应保留唯一租约。")
	assert_eq(nested_handles.size(), 1, "开始回调只应触发一次重入尝试。")
	assert_eq(
		nested_handles[0].get_result().status,
		&"duplicate_request_id",
		"开始信号重入不得绕过请求 ID 预留。"
	)
	assert_true(runtime.cancel_request(&"same_request"), "测试清理应取消原请求。")
	runtime.request_started.disconnect(started_callback)
	runtime.dispose()


func test_platform_runtime_preserves_zero_timestamp_results() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(
		GFManualClock.new(0, 1700000000000)
	)
	var adapter: PlatformAdapterFixture = _make_adapter(&"zero_time", &"sample", true)
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"zero_time")

	var handle: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share"
	)
	var result: GFPlatformBridgeResult = handle.get_result()

	assert_true(handle.is_successful(), "零时间戳不得被视为缺失。")
	assert_eq(result.started_at_msec, 0)
	assert_eq(result.completed_at_msec, 0)
	assert_eq(result.get_duration_msec(), 0)
	runtime.dispose()


# --- 私有/辅助方法 ---

func _make_adapter(
	adapter_id: StringName,
	platform_id: StringName,
	complete_immediately: bool
) -> PlatformAdapterFixture:
	var adapter: PlatformAdapterFixture = PlatformAdapterFixture.new()
	adapter.complete_immediately = complete_immediately
	var configured: bool = adapter.configure(
		adapter_id,
		platform_id,
		PackedStringArray(["platform.share"]),
		[_make_share_contract()]
	)
	assert_true(configured, "测试 adapter 配置应成功。")
	return adapter


func _make_share_contract() -> GFPlatformContractDescriptor:
	var methods: Array[GFPlatformContractMethodDescriptor] = [
		GFPlatformContractMethodDescriptor.new().configure(&"share"),
		GFPlatformContractMethodDescriptor.new().configure(&"hold"),
	]
	return GFPlatformContractDescriptor.new().configure(
		&"platform.share",
		"1.0.0",
		methods
	)


# --- 内部类 ---

class ExtremeClock extends GFClock:
	var now_msec: int = 0

	func _init(initial_msec: int) -> void:
		now_msec = initial_msec

	func get_monotonic_msec() -> int:
		return now_msec


class PlatformAdapterFixture extends GFPlatformAdapter:
	var complete_immediately: bool = true
	var cancel_count: int = 0
	var last_sequence: int = 0

	func publish_capability(capability_id: StringName) -> bool:
		var context: GFPlatformRuntimeContext = get_context()
		var _added: bool = context.capabilities.add_capability(capability_id)
		return _publish_context(context)

	func publish_background_event() -> bool:
		var event: GFPlatformLifecycleEvent = GFPlatformLifecycleEvent.new().configure(
			GFPlatformLifecycleEvent.TYPE_BACKGROUND
		)
		var published: bool = _publish_lifecycle_event(event)
		if published:
			last_sequence += 1
		return published

	func _dispatch(request: GFPlatformBridgeRequest, handle: GFPlatformRequestHandle) -> bool:
		if not complete_immediately or request.method_id == &"hold":
			return true
		return _succeed_request(handle, {"adapter_id": get_adapter_id()})

	func _cancel_request(_handle: GFPlatformRequestHandle, _reason: StringName) -> void:
		cancel_count += 1
		var _released: bool = _release_request(_handle)
