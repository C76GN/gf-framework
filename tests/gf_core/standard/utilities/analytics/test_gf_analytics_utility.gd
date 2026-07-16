## 测试 GFAnalyticsUtility 的本地队列、dry-run flush 与配置行为。
extends GutTest


# --- 私有变量 ---

var _analytics: GFAnalyticsUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	GFAutoload.reset_tree_exit_state()
	_analytics = GFAnalyticsUtility.new()
	_analytics.init()
	_analytics.config.auto_capture_context = false
	_analytics.config.flush_interval_seconds = 0.0


func after_each() -> void:
	GFAutoload.reset_tree_exit_state()
	if _analytics != null:
		_analytics.dispose()
	_analytics = null
	_remove_file_if_exists("user://gf_analytics_client.cfg")
	_remove_file_if_exists("user://test_gf_analytics_client.cfg")


# --- 测试方法 ---

## 验证 AutoLoad 退出期间关闭监听保持挂树并延迟释放，避免重入修改 SceneTree.root。
func test_dispose_defers_shutdown_watcher_detach_during_autoload_tree_exit() -> void:
	await get_tree().process_frame
	var watcher: Node = _analytics._shutdown_watcher
	assert_not_null(watcher, "Analytics 初始化后应创建关闭监听。")
	assert_not_null(watcher.get_parent(), "关闭监听应挂到 SceneTree.root。")
	GFAutoload.begin_tree_exit_scope()

	_analytics.dispose()
	_analytics = null

	assert_true(is_instance_valid(watcher), "AutoLoad 退出期间不应同步 free 仍在树中的关闭监听。")
	if not is_instance_valid(watcher):
		GFAutoload.reset_tree_exit_state()
		return
	assert_not_null(watcher.get_parent(), "AutoLoad 退出期间不应主动拆除关闭监听。")
	assert_true(watcher.is_queued_for_deletion(), "AutoLoad 退出期间关闭监听应进入延迟释放队列。")

	GFAutoload.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(watcher), "退出阶段登记 queue_free 后关闭监听仍应完成释放。")

## 验证事件记录会进入队列并带上基础标识。
func test_track_adds_event_to_queue() -> void:
	_analytics.identify("client-a")
	_analytics.track(&"opened", { "index": 1 })

	assert_eq(_analytics.get_queue_size(), 1, "记录事件后队列长度应增加。")
	assert_eq(_analytics.get_client_id(), "client-a", "identify 应替换 client_id。")


## 验证 endpoint 为空时 flush 走 dry-run 成功路径。
func test_flush_without_endpoint_is_dry_run_success() -> void:
	watch_signals(_analytics)
	_analytics.config.batch_size = 10
	_analytics.track(&"opened")

	_analytics.flush()

	assert_eq(_analytics.get_queue_size(), 0, "dry-run flush 成功后应清空本批队列。")
	assert_signal_emitted(_analytics, "flush_started", "flush 应发出开始信号。")
	assert_signal_emitted(_analytics, "flush_completed", "dry-run 应发出完成信号。")
	assert_signal_not_emitted(_analytics, "flush_failed", "dry-run 成功不应发出失败信号。")


## 验证队列超过上限时丢弃最旧事件。
func test_queue_respects_max_size() -> void:
	_analytics.config.max_queue_size = 2
	_analytics.config.batch_size = 10

	_analytics.track(&"first")
	_analytics.track(&"second")
	_analytics.track(&"third")

	assert_eq(_analytics.get_queue_size(), 2, "队列不应超过 max_queue_size。")


## 验证失败批次回灌后仍遵守队列上限。
func test_failed_flush_requeue_respects_max_size() -> void:
	_analytics.config.max_queue_size = 2
	_analytics.config.batch_size = 2
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		return { "success": false, "error": "offline" }
	_analytics.track(&"failed_a")
	_analytics.track(&"failed_b")

	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.events = GFVariantData.get_option_array(payload, "events").duplicate(true)
		return { "success": true, "accepted": captured.events.size() }
	_analytics.flush()

	assert_eq(captured.events.size(), 2, "失败批次回灌后应能再次被 flush。")
	if captured.events.size() < 2:
		return
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(captured.events[0]), "event"), "failed_a", "失败批次应保留在队列前端。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(captured.events[1]), "event"), "failed_b", "失败批次顺序应保持。")


## 验证自定义 HTTP Header 会过滤空名和 CR/LF 注入。
func test_analytics_headers_reject_invalid_entries() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.headers = {
		"X-Ok": "yes",
		"X-Bad\r\nInjected": "no",
		"": "empty",
	}

	var headers: PackedStringArray = config.build_headers()

	assert_eq(headers.size(), 2, "只应包含默认 Content-Type 和合法自定义 Header。")
	assert_true(headers.has("X-Ok: yes"), "合法 Header 应保留。")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：X-Bad\\r\\nInjected")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：")


## 验证启用压缩时会固定 Content-Encoding，避免自定义 Header 和请求体不一致。
func test_analytics_headers_add_gzip_when_payload_compression_enabled() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.compress_payload = true
	config.headers = {
		"Content-Encoding": "identity",
		"X-Trace": "abc",
	}

	var headers: PackedStringArray = config.build_headers()

	assert_true(headers.has("Content-Encoding: gzip"), "启用压缩后应声明 gzip 请求体。")
	assert_false(headers.has("Content-Encoding: identity"), "自定义 Content-Encoding 不应覆盖压缩配置。")
	assert_true(headers.has("X-Trace: abc"), "其他合法自定义 Header 应保留。")
	assert_push_warning("[GFAnalyticsConfig] compress_payload 已启用，忽略自定义 Content-Encoding。")


func test_analytics_headers_reject_custom_content_type() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.headers = {
		"Content-Type": "text/plain",
		"X-Trace": "abc",
	}

	var headers: PackedStringArray = config.build_headers()

	assert_eq(headers.count("Content-Type: application/json"), 1, "Content-Type 应固定为 application/json 且不重复。")
	assert_false(headers.has("Content-Type: text/plain"), "自定义 Content-Type 不应覆盖 JSON payload 契约。")
	assert_true(headers.has("X-Trace: abc"), "其他合法 Header 应保留。")
	assert_push_warning("[GFAnalyticsConfig] 忽略自定义 Content-Type；analytics payload 固定为 application/json。")


## 验证运行时代码写入非法批量配置时会被钳制，不会破坏队列。
func test_runtime_config_values_are_clamped() -> void:
	_analytics.config.max_queue_size = 0
	_analytics.config.batch_size = 0
	_analytics.track(&"first")
	_analytics.track(&"second")

	assert_eq(_analytics.config.max_queue_size, 1, "max_queue_size 应被钳制为至少 1。")
	assert_eq(_analytics.config.batch_size, 1, "batch_size 应被钳制为至少 1。")
	assert_eq(_analytics.get_queue_size(), 0, "batch_size 钳制为 1 后事件应立即 dry-run flush。")


## 验证配置关闭后不会继续记录事件。
func test_disabled_config_ignores_events() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.enabled = false
	_analytics.configure(config)

	_analytics.track(&"ignored")

	assert_eq(_analytics.get_queue_size(), 0, "禁用后不应记录事件。")


func test_config_assignment_never_exposes_null() -> void:
	_analytics.config = null

	assert_not_null(_analytics.config, "analytics 公共 config 必须始终保持可用资源，不能把 nullable 状态扩散给调用方。")


func test_overlong_event_name_is_rejected_before_queueing() -> void:
	var event_name: StringName = StringName("event_" + "x".repeat(1024))

	_analytics.track(event_name)

	assert_eq(_analytics.get_queue_size(), 0, "超过默认事件名预算的事件不得进入队列。")
	assert_push_warning("[GFAnalyticsUtility] event_name exceeds max_event_name_length.")


func test_excessive_top_level_properties_are_rejected_before_queueing() -> void:
	var properties: Dictionary = {}
	for index: int in range(300):
		properties["field_%d" % index] = index

	_analytics.track(&"too_wide", properties)

	assert_eq(_analytics.get_queue_size(), 0, "超过顶层属性预算的事件不得进入队列。")
	assert_push_warning("[GFAnalyticsUtility] properties exceed max_property_count.")


func test_disabled_or_local_only_init_does_not_persist_client_id() -> void:
	var disabled_path: String = "user://test_gf_analytics_disabled_client.cfg"
	_remove_file_if_exists(disabled_path)
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.enabled = false
	config.client_id_storage_path = disabled_path

	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	analytics.configure(config)
	analytics.init()
	analytics.dispose()

	assert_false(FileAccess.file_exists(disabled_path), "禁用 analytics 初始化不应写入持久 client id。")
	_remove_file_if_exists(disabled_path)


## 验证持久 client id 可跨实例复用。
func test_persistent_client_id_survives_new_instance() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.client_id_storage_path = "user://test_gf_analytics_client.cfg"
	config.endpoint_url = "https://analytics.invalid/collect"
	config.flush_interval_seconds = 0.0
	config.auto_capture_context = false

	var first: GFAnalyticsUtility = GFAnalyticsUtility.new()
	first.configure(config)
	first.init()
	var client_id: String = first.get_client_id()
	first.dispose()

	var second: GFAnalyticsUtility = GFAnalyticsUtility.new()
	second.configure(config)
	second.init()

	assert_false(client_id.is_empty(), "首次初始化应生成 client id。")
	assert_eq(second.get_client_id(), client_id, "第二个实例应读取已持久化的 client id。")
	second.dispose()


func test_invalid_client_id_storage_scheme_is_reported_and_not_used() -> void:
	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	var analytics_config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	analytics_config.endpoint_url = "https://analytics.invalid/collect"
	analytics_config.client_id_storage_path = "http://invalid/client.cfg"
	analytics.config = analytics_config

	analytics.init()

	assert_false(analytics.get_client_id().is_empty(), "非法持久化路径不应阻止生成内存 client id。")
	assert_push_warning("[GFAnalyticsUtility] client_id_storage_path must stay under user:// without parent traversal.")
	analytics.dispose()


## 验证 init 不会覆盖提前 identify 的稳定 ID。
func test_identify_before_init_is_preserved() -> void:
	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	analytics.identify("pre-init-client")
	analytics.init()

	assert_eq(analytics.get_client_id(), "pre-init-client", "init 不应覆盖提前设置的 client id。")
	analytics.dispose()


## 验证自定义 transport hook 可接管 flush。
func test_transport_callback_receives_payload() -> void:
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1, "custom": true }

	_analytics.track(&"opened")
	_analytics.flush()

	assert_true(captured.payload.has("events"), "transport hook 应收到由事件批次构建的 payload。")
	assert_eq(_analytics.get_queue_size(), 0, "自定义 transport 成功后应清空本批队列。")


func test_event_tracked_listener_cannot_mutate_queued_event() -> void:
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	var _connect_result: Error = _analytics.event_tracked.connect(func(_event_name: StringName, event_data: Dictionary) -> void:
		var event_properties: Dictionary = GFVariantData.get_option_dictionary(event_data, "properties")
		event_properties["mutated"] = true
	) as Error
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1 }

	_analytics.track(&"opened", { "index": 1 })
	_analytics.flush()

	var events: Array = GFVariantData.get_option_array(captured.payload, "events")
	var event: Dictionary = GFVariantData.as_dictionary(events[0])
	var queued_properties: Dictionary = GFVariantData.get_option_dictionary(event, "properties")
	assert_false(queued_properties.has("mutated"), "event_tracked 监听器不应能污染已入队事件。")


func test_flush_started_listener_cannot_mutate_transport_batch() -> void:
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	var _connect_result: Error = _analytics.flush_started.connect(func(batch: Array) -> void:
		batch.clear()
	) as Error
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.events = GFVariantData.get_option_array(payload, "events").duplicate(true)
		return { "success": true, "accepted": captured.events.size() }

	_analytics.track(&"opened")
	_analytics.flush()

	assert_eq(captured.events.size(), 1, "flush_started 监听器不应能清空即将发送的批次。")


func test_partial_accepted_flush_requeues_unaccepted_events() -> void:
	_analytics.config.batch_size = 3
	_analytics.config.max_queue_size = 10
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		return { "success": true, "accepted": 1 }

	_analytics.track(&"first")
	_analytics.track(&"second")
	_analytics.track(&"third")

	assert_eq(_analytics.get_queue_size(), 2, "partial accepted 后未接受事件应回到队列。")
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.events = GFVariantData.get_option_array(payload, "events").duplicate(true)
		return { "success": true, "accepted": captured.events.size() }
	_analytics.flush()

	assert_eq(captured.events.size(), 2, "未接受事件应能被下一次 flush 发送。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(captured.events[0]), "event"), "second", "partial ack 应保留事件顺序。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(captured.events[1]), "event"), "third", "partial ack 应保留队尾事件。")


func test_analytics_properties_are_json_safe() -> void:
	var circular: Dictionary = {}
	circular["self"] = circular
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1 }

	_analytics.track(&"unsafe", {
		"nan": NAN,
		"inf": INF,
		"tags": PackedStringArray(["a", "b"]),
		"position": Vector2(1.0, 2.0),
		"circular": circular,
	})
	_analytics.flush()

	var payload_text: String = JSON.stringify(captured.payload)
	var events: Array = GFVariantData.get_option_array(captured.payload, "events")
	var event: Dictionary = GFVariantData.as_dictionary(events[0])
	var properties: Dictionary = GFVariantData.get_option_dictionary(event, "properties")
	assert_false(payload_text.contains(":null"), "analytics payload 不应让非有限 float 被 JSON.stringify 替换成 null。")
	var nan_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "nan"), "__gf_variant__")
	var tags_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "tags"), "__gf_variant__")
	var position_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "position"), "__gf_variant__")
	var circular_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "circular"), "self"),
		"__gf_report_value__"
	)
	assert_eq(GFVariantData.get_option_string(nan_marker, "value"), "NaN", "NaN 应使用统一 typed marker。")
	assert_eq(GFVariantData.get_option_string(tags_marker, "type"), "PackedStringArray", "PackedStringArray 应保留统一类型标记。")
	assert_eq(GFVariantData.get_option_string(position_marker, "type"), "Vector2", "Vector2 应使用统一 JSON-safe typed marker。")
	assert_eq(GFVariantData.get_option_string(circular_marker, "type"), "CircularReference", "循环 Dictionary 应使用统一 report marker。")


func test_analytics_privacy_policy_redacts_object_identity_and_paths() -> void:
	var private_node: Node = Node.new()
	private_node.name = "PrivateAnalyticsNode"
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1 }

	_analytics.track(&"privacy", {
		"node": private_node,
		"asset": "res://private/secret_asset.tres",
	})
	_analytics.flush()
	private_node.free()

	var payload_text: String = JSON.stringify(captured.payload)
	var event: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_array(captured.payload, "events")[0])
	var properties: Dictionary = GFVariantData.get_option_dictionary(event, "properties")
	assert_false(payload_text.contains("PrivateAnalyticsNode"), "analytics 外发载荷不得包含 Node 名称。")
	assert_false(payload_text.contains("secret_asset.tres"), "analytics 外发载荷不得包含资源路径。")
	assert_eq(GFVariantData.get_option_string(properties, "asset"), "<redacted_path>", "路径值应按 privacy profile 脱敏。")


func test_analytics_payload_is_bounded_before_transport() -> void:
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1 }

	_analytics.track(&"bounded", { "large": "x".repeat(1024 * 1024) })
	_analytics.flush()

	assert_true(JSON.stringify(captured.payload).to_utf8_buffer().size() < 256 * 1024, "analytics 载荷必须在 transport 前应用字符串和总载荷预算。")


func test_payload_builder_cannot_mutate_or_replace_encoded_event_batch() -> void:
	var private_node: Node = Node.new()
	private_node.name = "PayloadBuilderPrivateNode"
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.payload_builder = func(batch: Array) -> Dictionary:
		batch.clear()
		return {
			"channel": "custom",
			"events": [{ "node": private_node }],
		}
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload
		return { "success": true, "accepted": 1 }

	_analytics.track(&"protected_event")
	_analytics.flush()
	private_node.free()

	var events: Array = GFVariantData.get_option_array(captured.payload, "events")
	assert_eq(events.size(), 1, "builder 对输入副本的修改不能清空真实 flush 批次。")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.as_dictionary(events[0]), "event"),
		"protected_event",
		"builder 只能扩展载荷信封，不能替换已经过隐私编码的事件。"
	)
	assert_false(JSON.stringify(captured.payload).contains("PayloadBuilderPrivateNode"), "builder 不得绕过 analytics 隐私边界。")


func test_final_envelope_budget_splits_batches_before_dequeue() -> void:
	_analytics.config.batch_size = 10
	_analytics.config.max_queue_size = 10
	_analytics.config.max_payload_bytes = 1024
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return {
			"channel": "bounded",
			"padding": "p".repeat(450),
		}
	var payloads: Array[Dictionary] = []
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		payloads.append(payload.duplicate(true))
		return {
			"success": true,
			"accepted": GFVariantData.get_option_array(payload, "events").size(),
		}
	for index: int in range(3):
		_analytics.track(&"envelope", {
			"index": index,
			"value": "v".repeat(180),
		})

	_analytics.shutdown()
	var sent_event_count: int = 0
	for payload: Dictionary in payloads:
		assert_true(JSON.stringify(payload).to_utf8_buffer().size() <= 1024, "每个最终 envelope 都必须遵守 max_payload_bytes。")
		sent_event_count += GFVariantData.get_option_array(payload, "events").size()

	assert_true(payloads.size() >= 2, "最终 envelope 超限时应缩小批次，而不是按事件数量盲目发送。")
	assert_eq(sent_event_count, 3, "切批不得丢失可发送事件。")
	assert_eq(_analytics.get_queue_size(), 0, "shutdown draining 应发送所有可发送前缀。")


func test_unsendable_single_event_is_dropped_once_with_failure_progress() -> void:
	_analytics.config.batch_size = 10
	_analytics.config.max_payload_bytes = 1024
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return { "padding": "p".repeat(900) }
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	var failures: Array[Dictionary] = []
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		captured.call_count += 1
		return { "success": true, "accepted": 1 }
	var _failure_connected: Error = _analytics.flush_failed.connect(
		func(result: Dictionary) -> void:
			failures.append(result.duplicate(true))
	) as Error
	_analytics.track(&"too_large_for_envelope", { "value": "v".repeat(180) })

	_analytics.flush()

	assert_eq(captured.call_count, 0, "不可发送的单事件不得进入 transport。")
	assert_eq(_analytics.get_queue_size(), 0, "不可发送事件必须明确 drop，不能原样无限 requeue。")
	assert_eq(failures.size(), 1, "drop 应产生一次明确失败进展。")
	if not failures.is_empty():
		assert_true(GFVariantData.get_option_bool(failures[0], "dropped"), "失败结果应明确 dropped。")
		assert_eq(GFVariantData.get_option_string(failures[0], "drop_reason"), "final_envelope_too_large", "drop 应提供稳定原因。")


func test_dispose_reports_and_completes_in_flight_batch() -> void:
	var analytics: PendingAnalyticsUtility = PendingAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.track(&"pending")
	analytics.flush()
	watch_signals(analytics)

	analytics.dispose()

	assert_signal_emitted(analytics, "flush_failed", "dispose 不得静默丢弃 in-flight batch。")
	assert_signal_emitted(analytics, "flush_completed", "dispose 应完成既有 flush 生命周期。")


## 验证 shutdown 会 flush 剩余事件并阻止后续记录。
func test_shutdown_flushes_and_ignores_future_events() -> void:
	_analytics.track(&"before_shutdown")

	_analytics.shutdown()
	_analytics.track(&"after_shutdown")

	assert_eq(_analytics.get_queue_size(), 0, "shutdown dry-run flush 后队列应为空，后续事件应被忽略。")


## 验证 shutdown 在同步 flush 路径中会清空超过单批大小的队列。
func test_shutdown_flushes_all_synchronous_batches() -> void:
	_analytics.config.batch_size = 10
	_analytics.config.max_queue_size = 10
	for index: int in range(5):
		_analytics.track(&"queued", { "index": index })
	_analytics.config.batch_size = 2

	_analytics.shutdown()

	assert_eq(_analytics.get_queue_size(), 0, "shutdown 应连续 flush dry-run 批次直到队列清空。")


func test_shutdown_draining_continues_after_async_batch_completion() -> void:
	var analytics: DeferredDrainAnalyticsUtility = DeferredDrainAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.config.batch_size = 10
	for index: int in range(3):
		analytics.track(&"queued", { "index": index })
	analytics.config.batch_size = 1

	analytics.shutdown()
	assert_eq(analytics.sent_batches.size(), 1, "shutdown 应先启动第一批异步 drain。")
	analytics.complete_current(true)
	assert_eq(analytics.sent_batches.size(), 2, "第一批完成后 draining 不得被普通 shutdown guard 阻断。")
	analytics.complete_current(true)
	assert_eq(analytics.sent_batches.size(), 3, "draining 应继续启动后续异步批次。")
	analytics.complete_current(true)

	assert_eq(analytics.get_queue_size(), 0, "全部异步批次完成后队列应为空。")
	analytics.track(&"after_shutdown")
	assert_eq(analytics.get_queue_size(), 0, "draining 完成后 shutdown 仍应拒绝新事件。")
	analytics.dispose()


func test_shutdown_draining_stops_after_explicit_async_failure() -> void:
	var analytics: DeferredDrainAnalyticsUtility = DeferredDrainAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.config.batch_size = 10
	analytics.track(&"first")
	analytics.track(&"second")
	analytics.config.batch_size = 1

	analytics.shutdown()
	analytics.complete_current(false)

	assert_eq(analytics.sent_batches.size(), 1, "draining 失败后不得立即重发同一批形成循环。")
	assert_eq(analytics.get_queue_size(), 2, "失败批次和未发送事件应保留给显式恢复策略。")
	analytics.dispose()


# --- 私有/辅助方法 ---

func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		var remove_error: Error = DirAccess.remove_absolute(path)
		assert_eq(remove_error, OK, "测试应能删除 analytics 临时文件。")


# --- 内部类 ---

class AnalyticsPayloadCapture:
	extends RefCounted

	var events: Array = []
	var payload: Dictionary = {}
	var call_count: int = 0


class PendingAnalyticsUtility extends GFAnalyticsUtility:
	func _send_batch(_batch: Array) -> void:
		pass


class DeferredDrainAnalyticsUtility extends GFAnalyticsUtility:
	var sent_batches: Array = []
	var _completion_index: int = 0

	func _send_batch(batch: Array) -> void:
		sent_batches.append(batch.duplicate(true))

	func complete_current(success: bool) -> void:
		if _completion_index >= sent_batches.size():
			return
		var batch: Array = sent_batches[_completion_index]
		_completion_index += 1
		_finish_flush({
			"success": success,
			"accepted": batch.size() if success else 0,
			"error": "" if success else "injected async failure",
		}, batch)
