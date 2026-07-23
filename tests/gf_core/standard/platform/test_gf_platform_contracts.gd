## 测试平台契约描述符、请求约束和激活意图队列。
extends GutTest


# --- 测试方法 ---

func test_contract_descriptor_validates_request_result_budget_and_concurrency() -> void:
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(
		GFManualClock.new(1000000, 1700000000000)
	)
	var adapter: ContractPlatformAdapter = _make_contract_adapter()
	assert_true(runtime.register_adapter(adapter), "带有效描述符的 adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"contract_adapter")

	var invalid_request: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share"
	)
	assert_eq(
		invalid_request.get_result().status,
		&"invalid_contract_request",
		"缺少 schema 必填字段时应在 SDK 调用前拒绝。"
	)

	var oversized_request: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "x".repeat(300)}
	)
	assert_eq(
		oversized_request.get_result().status,
		&"invalid_contract_request",
		"超出声明字节预算时应拒绝。"
	)

	var first: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "hold"}
	)
	var second: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "hold"}
	)
	assert_true(first.is_pending(), "首个异步请求应保持等待。")
	assert_eq(
		second.get_result().status,
		&"contract_concurrency_exceeded",
		"同一方法超过并发上限时应 fail closed。"
	)
	assert_true(first.cancel(&"test_cancelled"), "首个请求应能进入本地取消终态。")
	var before_provider_release: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "hold"}
	)
	assert_eq(
		before_provider_release.get_result().status,
		&"contract_concurrency_exceeded",
		"Provider 确认停止前不得提前释放并发配额。"
	)
	assert_true(adapter.release_provider_call(first), "Provider 确认后应释放请求租约。")

	var invalid_result: GFPlatformRequestHandle = runtime.invoke_contract(
		&"platform.share",
		&"share",
		{"text": "bad-result"}
	)
	assert_eq(
		invalid_result.get_result().status,
		&"invalid_adapter_result",
		"Adapter 返回值违反结果 schema 时不得作为成功透出。"
	)
	runtime.dispose()


func test_contract_descriptor_requires_declared_capability_and_method() -> void:
	var descriptor: GFPlatformContractDescriptor = _make_share_contract()
	var adapter: ContractPlatformAdapter = ContractPlatformAdapter.new()
	var context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new().configure(
		&"sample",
		{"adapter_id": &"missing_capability"}
	)
	assert_true(
		adapter.configure(
			&"missing_capability",
			&"sample",
			PackedStringArray(["platform.share"]),
			[descriptor],
			context
		),
		"缺少运行时能力不应阻止 adapter 声明契约。"
	)
	var _initialized: GFAsyncCompletion = adapter.initialize()

	var missing_capability: GFPlatformRequestHandle = adapter.invoke(
		GFPlatformBridgeRequest.new().configure(
			&"missing_capability_request",
			&"platform.share",
			&"share",
			{"text": "hello"}
		)
	)
	var unknown_method: GFPlatformRequestHandle = adapter.invoke(
		GFPlatformBridgeRequest.new().configure(
			&"unknown_method_request",
			&"platform.share",
			&"unknown",
			{}
		)
	)

	assert_eq(
		missing_capability.get_result().status,
		&"invalid_contract_request",
		"缺少能力前置条件时请求应拒绝。"
	)
	assert_eq(
		unknown_method.get_result().status,
		&"unknown_contract_method",
		"已描述契约不得接受未声明方法。"
	)
	adapter.shutdown()


func test_adapter_configuration_requires_complete_descriptors_transactionally() -> void:
	var adapter: ContractPlatformAdapter = ContractPlatformAdapter.new()
	assert_false(
		adapter.configure(
			&"strict_adapter",
			&"sample",
			PackedStringArray(["platform.share"]),
			[]
		),
		"每个声明契约都必须提供有效描述符。"
	)
	assert_eq(adapter.get_adapter_id(), &"", "失败配置不得留下部分身份。")
	assert_true(
		adapter.configure(
			&"strict_adapter",
			&"sample",
			PackedStringArray(["platform.share"]),
			[_make_share_contract()]
		),
		"原子回滚后应允许使用完整描述符重试。"
	)
	adapter.shutdown()


func test_cancel_without_provider_confirmation_keeps_non_cancellable_lease() -> void:
	var adapter: ContractPlatformAdapter = ContractPlatformAdapter.new()
	var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample",
		PackedStringArray(["share"]),
		{},
		&"non_cancellable"
	)
	var context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new().configure(
		&"sample",
		{
			"adapter_id": &"non_cancellable",
			"capabilities": capabilities,
		}
	)
	assert_true(adapter.configure(
		&"non_cancellable",
		&"sample",
		PackedStringArray(["platform.share"]),
		[_make_share_contract(false)],
		context
	))
	var _initialized: GFAsyncCompletion = adapter.initialize()
	var first: GFPlatformRequestHandle = adapter.invoke(
		_make_share_request(&"non_cancellable_first", "hold")
	)

	assert_true(first.cancel(&"user_cancelled"), "本地句柄应立即结束。")
	assert_eq(adapter.cancel_count, 0, "不支持取消的方法不得调用 Provider 取消钩子。")
	var blocked: GFPlatformRequestHandle = adapter.invoke(
		_make_share_request(&"non_cancellable_second", "hold")
	)
	assert_eq(
		blocked.get_result().status,
		&"contract_concurrency_exceeded",
		"不可取消调用仍占用 Provider 并发租约。"
	)
	assert_true(adapter.release_provider_call(first), "Provider 终态确认后才能释放租约。")
	var next: GFPlatformRequestHandle = adapter.invoke(
		_make_share_request(&"non_cancellable_third", "hold")
	)
	assert_true(next.is_pending(), "释放租约后下一调用应被接受。")
	adapter.shutdown()


func test_platform_debug_snapshots_omit_payload_result_and_context_secrets() -> void:
	var clock: GFManualClock = GFManualClock.new(0, 1700000000000)
	var adapter: ContractPlatformAdapter = ContractPlatformAdapter.new()
	var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample",
		PackedStringArray(["share"]),
		{"provider_token": "capability-secret"},
		&"secret_adapter"
	)
	var context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new().configure(
		&"sample",
		{
			"adapter_id": &"secret_adapter",
			"capabilities": capabilities,
			"storage_roots": {"cloud": "user://private-secret"},
			"launch_options": {"token": "launch-secret"},
			"metadata": {"access_token": "context-secret"},
		}
	)
	assert_true(adapter.configure(
		&"secret_adapter",
		&"sample",
		PackedStringArray(["platform.share"]),
		[_make_share_contract()],
		context
	))
	assert_true(adapter.set_runtime_clock(clock), "测试应注入零起点时钟。")
	var _initialized: GFAsyncCompletion = adapter.initialize()
	var handle: GFPlatformRequestHandle = adapter.invoke(
		_make_share_request(&"secret_request", "hold", "request-secret")
	)
	var pending_debug: String = JSON.stringify({
		"adapter": adapter.get_debug_snapshot(),
		"handle": handle.get_debug_snapshot(),
	})

	assert_false(pending_debug.contains("request-secret"), "请求载荷不得进入调试快照。")
	assert_false(pending_debug.contains("capability-secret"), "能力 metadata 不得进入调试快照。")
	assert_false(pending_debug.contains("private-secret"), "存储物理路径不得进入调试快照。")
	assert_false(pending_debug.contains("launch-secret"), "启动参数不得进入调试快照。")
	assert_false(pending_debug.contains("context-secret"), "上下文 metadata 不得进入调试快照。")
	assert_true(
		adapter.complete_provider_call(
			handle,
			{"accepted": true},
			{"token": "result-secret"}
		),
		"Provider 首个终态应成功。"
	)
	assert_false(
		JSON.stringify(handle.get_debug_snapshot()).contains("result-secret"),
		"结果 metadata 不得进入调试快照。"
	)
	assert_eq(handle.get_result().started_at_msec, 0, "零毫秒起点必须有效。")
	assert_eq(handle.get_result().get_duration_msec(), 0, "同步零毫秒终态耗时应为零。")
	assert_false(
		adapter.complete_provider_call(handle, {"accepted": true}),
		"重复 Provider 终态不得覆盖首次结果。"
	)
	adapter.shutdown()


func test_adapter_shutdown_blocks_reentrant_requests_and_finishes_pending_once() -> void:
	var adapter: ContractPlatformAdapter = _make_contract_adapter(&"shutdown_adapter")
	var _initialized: GFAsyncCompletion = adapter.initialize()
	adapter.reenter_on_cancel = true
	var handle: GFPlatformRequestHandle = adapter.invoke(
		_make_share_request(&"shutdown_pending", "hold")
	)

	adapter.shutdown()

	assert_eq(handle.get_result().status, &"adapter_shutdown", "等待请求应进入关闭终态。")
	assert_eq(adapter.cancel_count, 1, "关闭只应通知 Provider 取消一次。")
	assert_eq(
		adapter.reentrant_status,
		&"adapter_not_ready",
		"取消钩子中的重入请求必须被 SHUTDOWN 状态拒绝。"
	)
	assert_eq(adapter.get_state(), GFPlatformAdapter.State.SHUTDOWN)
	assert_eq(
		GFVariantData.get_option_int(adapter.get_debug_snapshot(), "active_request_count"),
		0,
		"关闭后不得遗留请求租约。"
	)


func test_activation_intents_are_deduplicated_bounded_and_replayable() -> void:
	var clock: GFManualClock = GFManualClock.new(2000000, 1700000000000)
	var runtime: GFPlatformRuntime = GFPlatformRuntime.new(clock)
	var adapter: ContractPlatformAdapter = _make_contract_adapter()
	var second_adapter: ContractPlatformAdapter = _make_contract_adapter(&"contract_adapter_2")
	assert_true(runtime.configure_activation_queue(2, 4), "测试队列容量应有效。")
	assert_true(runtime.register_adapter(adapter), "Adapter 应能注册。")
	assert_true(runtime.register_adapter(second_adapter), "第二个 Adapter 应能注册。")
	var _initialized: GFAsyncCompletion = runtime.initialize_adapter(&"contract_adapter")
	var _second_initialized: GFAsyncCompletion = runtime.initialize_adapter(&"contract_adapter_2")
	watch_signals(runtime)

	assert_true(adapter.publish_intent(&"intent_1", "room-1"), "首个意图应发布。")
	assert_true(adapter.publish_intent(&"intent_1", "room-1"), "重复回调仍可由 adapter 发布。")
	assert_true(adapter.publish_intent(&"intent_2", "room-2"), "第二个意图应发布。")
	assert_true(adapter.publish_intent(&"intent_3", "room-3"), "第三个意图应发布。")
	assert_true(
		second_adapter.publish_intent(&"intent_2", "room-other-adapter"),
		"不同 Adapter 可复用平台侧 Intent ID。"
	)
	var pending_intents: Array[GFPlatformActivationIntent] = runtime.get_activation_intents()

	assert_eq(pending_intents.size(), 2, "队列应按容量保留两个待消费意图。")
	assert_eq(pending_intents[0].intent_id, &"intent_3", "容量淘汰应移除最旧意图。")
	assert_eq(pending_intents[0].timestamp_msec, 2000, "时间戳应使用注入的单调时钟。")
	assert_eq(pending_intents[1].adapter_id, &"contract_adapter_2", "去重必须按 Adapter 作用域隔离。")
	assert_signal_emit_count(runtime, "activation_intent_received", 4, "仅同一 Adapter 的重复意图不得入队。")
	assert_signal_emit_count(runtime, "activation_intent_dropped", 3, "重复和容量淘汰都应可观测。")
	assert_not_null(
		runtime.consume_activation_intent(&"contract_adapter", &"intent_3"),
		"消费应使用 Adapter 与 Intent 复合身份。"
	)
	assert_true(
		runtime.acknowledge_activation_intent(&"contract_adapter_2", &"intent_2"),
		"确认应移除指定 Adapter 的意图。"
	)
	assert_true(runtime.get_activation_intents().is_empty(), "消费完成后队列应为空。")
	runtime.dispose()


func test_platform_adapter_conformance_reports_contract_method_and_capability_gaps() -> void:
	var adapter: ContractPlatformAdapter = _make_contract_adapter()
	var valid_report: Dictionary = GFPlatformAdapterConformance.inspect(adapter, {
		"required_contract_ids": PackedStringArray(["platform.share"]),
		"required_contract_versions": {"platform.share": "1.0.0"},
		"required_capability_ids": PackedStringArray(["share"]),
		"required_methods": {"platform.share": PackedStringArray(["share"])},
	})
	var invalid_report: Dictionary = GFPlatformAdapterConformance.inspect(adapter, {
		"required_contract_ids": PackedStringArray(["platform.share", "platform.invite"]),
		"required_contract_versions": {"platform.share": "2.0.0"},
		"required_capability_ids": PackedStringArray(["share", "invite"]),
		"required_methods": {"platform.share": PackedStringArray(["share", "cancel_share"])},
	})

	assert_true(GFVariantData.get_option_bool(valid_report, "ok"), "完整声明应通过静态一致性审查。")
	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"), "契约缺口必须使审查失败。")
	var counts: Dictionary = GFVariantData.get_option_dictionary(
		invalid_report,
		"issue_counts_by_kind"
	)
	assert_eq(GFVariantData.get_option_int(counts, GFPlatformAdapterConformance.KIND_CONTRACT_MISSING), 1)
	assert_eq(GFVariantData.get_option_int(counts, GFPlatformAdapterConformance.KIND_METHOD_MISSING), 1)
	assert_eq(GFVariantData.get_option_int(counts, GFPlatformAdapterConformance.KIND_CONTRACT_VERSION_MISMATCH), 1)
	assert_eq(GFVariantData.get_option_int(counts, GFPlatformAdapterConformance.KIND_CAPABILITY_MISSING), 1)
	var bridge_coverage: Dictionary = GFVariantData.get_option_dictionary(
		invalid_report,
		"bridge_coverage"
	)
	assert_false(
		GFVariantData.get_option_bool(bridge_coverage, "ok"),
		"通用桥接覆盖附录也应报告缺少的契约。"
	)


# --- 私有/辅助方法 ---

func _make_contract_adapter(
	adapter_id: StringName = &"contract_adapter"
) -> ContractPlatformAdapter:
	var adapter: ContractPlatformAdapter = ContractPlatformAdapter.new()
	var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample",
		PackedStringArray(["share"]),
		{},
		adapter_id
	)
	var context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new().configure(
		&"sample",
		{
			"adapter_id": adapter_id,
			"capabilities": capabilities,
		}
	)
	var configured: bool = adapter.configure(
		adapter_id,
		&"sample",
		PackedStringArray(["platform.share"]),
		[_make_share_contract()],
		context
	)
	assert_true(configured, "测试 adapter 配置应成功。")
	return adapter


func _make_share_contract(
	supports_cancellation: bool = true
) -> GFPlatformContractDescriptor:
	var request_schema: GFDictionarySchema = GFDictionarySchema.new().configure(
		&"platform_share_request",
		[
			GFSchemaField.new().configure(
				&"text",
				GFSchemaField.ValueType.STRING,
				{"required": true}
			),
			GFSchemaField.new().configure(
				&"token",
				GFSchemaField.ValueType.STRING
			),
		],
		{"allow_extra_fields": false}
	)
	var result_schema: GFDictionarySchema = GFDictionarySchema.new().configure(
		&"platform_share_result",
		[
			GFSchemaField.new().configure(
				&"accepted",
				GFSchemaField.ValueType.BOOL,
				{"required": true}
			),
		],
		{"allow_extra_fields": false}
	)
	var method: GFPlatformContractMethodDescriptor = (
		GFPlatformContractMethodDescriptor.new().configure(
			&"share",
			{
				"request_schema": request_schema,
				"result_schema": result_schema,
				"required_capability_ids": PackedStringArray(["share"]),
				"max_request_bytes": 128,
				"max_result_bytes": 128,
				"max_concurrent_requests": 1,
				"supports_cancellation": supports_cancellation,
				"sensitive_fields": PackedStringArray(["token"]),
			}
		)
	)
	return GFPlatformContractDescriptor.new().configure(
		&"platform.share",
		"1.0.0",
		[method]
	)


func _make_share_request(
	request_id: StringName,
	text: String,
	token: String = ""
) -> GFPlatformBridgeRequest:
	var payload: Dictionary = {"text": text}
	if not token.is_empty():
		payload["token"] = token
	return GFPlatformBridgeRequest.new().configure(
		request_id,
		&"platform.share",
		&"share",
		payload
	)


# --- 内部类 ---

class ContractPlatformAdapter extends GFPlatformAdapter:
	var cancel_count: int = 0
	var reenter_on_cancel: bool = false
	var reentrant_status: StringName = &""

	func release_provider_call(handle: GFPlatformRequestHandle) -> bool:
		return _release_request(handle)

	func complete_provider_call(
		handle: GFPlatformRequestHandle,
		value: Dictionary,
		metadata: Dictionary = {}
	) -> bool:
		return _succeed_request(handle, value, &"ok", metadata)

	func publish_intent(intent_id: StringName, lobby_id: String) -> bool:
		return _publish_activation_intent(
			GFPlatformActivationIntent.new().configure(
				intent_id,
				&"network.lobby.join",
				{"lobby_id": lobby_id},
				{"source": &"invite"}
			)
		)

	func _dispatch(
		request: GFPlatformBridgeRequest,
		handle: GFPlatformRequestHandle
	) -> bool:
		var text: String = GFVariantData.get_option_string(request.payload, "text")
		if text == "hold":
			return true
		if text == "bad-result":
			return _succeed_request(handle, {"accepted": "yes"})
		return _succeed_request(handle, {"accepted": true})

	func _cancel_request(
		_handle: GFPlatformRequestHandle,
		_reason: StringName
	) -> void:
		cancel_count += 1
		if reenter_on_cancel:
			var reentrant: GFPlatformRequestHandle = invoke(
				_make_reentrant_request()
			)
			reentrant_status = reentrant.get_result().status

	func _make_reentrant_request() -> GFPlatformBridgeRequest:
		return GFPlatformBridgeRequest.new().configure(
			&"shutdown_reentrant",
			&"platform.share",
			&"share",
			{"text": "hold"}
		)
