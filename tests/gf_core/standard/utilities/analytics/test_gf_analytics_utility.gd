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


func test_dispose_releases_project_owned_callbacks() -> void:
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return {}
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		return {}
	_analytics.response_parser = func(
		_response_code: int,
		_body: PackedByteArray,
		_fallback_accepted: int
	) -> Dictionary:
		return {}

	_analytics.dispose()

	assert_false(_analytics.payload_builder.is_valid(), "dispose 应释放项目注入的 payload builder。")
	assert_false(_analytics.transport_callback.is_valid(), "dispose 应释放项目注入的 transport callback。")
	assert_false(_analytics.response_parser.is_valid(), "dispose 应释放项目注入的 response parser。")


func test_dispose_releases_callbacks_reinjected_by_flush_notifications() -> void:
	var analytics: PendingAnalyticsUtility = PendingAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.track(&"pending")
	analytics.flush()
	var reinject_callbacks: Callable = func(_result: Dictionary) -> void:
		analytics.payload_builder = func(_batch: Array) -> Dictionary:
			return {}
		analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
			return {}
		analytics.response_parser = func(
			_response_code: int,
			_body: PackedByteArray,
			_fallback_accepted: int
		) -> Dictionary:
			return {}
	var connect_error: Error = analytics.flush_completed.connect(reinject_callbacks) as Error
	assert_eq(connect_error, OK, "dispose 回归测试必须成功连接 flush 完成信号。")

	analytics.dispose()
	analytics.flush_completed.disconnect(reinject_callbacks)

	assert_false(analytics.payload_builder.is_valid(), "dispose 终态应释放通知回调重新注入的 payload builder。")
	assert_false(analytics.transport_callback.is_valid(), "dispose 终态应释放通知回调重新注入的 transport callback。")
	assert_false(analytics.response_parser.is_valid(), "dispose 终态应释放通知回调重新注入的 response parser。")


## 验证事件记录会进入队列并带上基础标识。
func test_track_adds_event_to_queue() -> void:
	_analytics.identify("client-a")
	_analytics.track(&"opened", { "index": 1 })

	assert_eq(_analytics.get_queue_size(), 1, "记录事件后队列长度应增加。")
	assert_eq(_analytics.get_client_id(), "client-a", "identify 应替换 client_id。")


func test_identify_rejects_oversized_client_id_before_event_encoding() -> void:
	var original_client_id: String = _analytics.get_client_id()

	_analytics.identify("x".repeat(4097))

	assert_eq(_analytics.get_client_id(), original_client_id, "超长 client_id 不得替换稳定客户端标识。")
	assert_push_warning("[GFAnalyticsUtility] client_id must contain 1..4096 characters without C0/DEL controls.")


func test_identify_and_legacy_track_reject_c0_and_del_controls() -> void:
	var original_client_id: String = _analytics.get_client_id()

	_analytics.identify("client\u0001hidden")
	_analytics.track(StringName("opened\u007fhidden"))

	assert_eq(_analytics.get_client_id(), original_client_id, "控制字符 client_id 不得替换稳定客户端标识。")
	assert_eq(_analytics.get_queue_size(), 0, "控制字符事件名不得进入 Analytics 队列。")
	assert_push_warning("[GFAnalyticsUtility] client_id must contain 1..4096 characters without C0/DEL controls.")
	assert_push_warning("[GFAnalyticsUtility] event_name contains control characters.")


func test_legacy_track_payload_does_not_gain_version_identity_fields() -> void:
	_analytics.config.batch_size = 10
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload.duplicate(true)
		return { "success": true, "accepted": 1 }

	_analytics.track(&"legacy_opened", { "index": 1 })
	_analytics.flush()

	var events: Array = GFVariantData.get_option_array(captured.payload, "events")
	assert_eq(events.size(), 1, "legacy 事件仍应正常发送。")
	if events.is_empty():
		return
	var event: Dictionary = GFVariantData.as_dictionary(events[0])
	assert_false(event.has("event_id"), "legacy track 不得静默改变既有 payload。")
	assert_false(event.has("schema_version"), "legacy track 不得静默增加版本字段。")


func test_track_versioned_validates_and_adds_stable_identity_fields() -> void:
	_analytics.config.batch_size = 10
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_versioned_event_schema()
	)
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.payload = payload.duplicate(true)
		return { "success": true, "accepted": 1 }

	var track_report: Dictionary = _analytics.track_versioned(
		&"opened",
		1,
		{ "index": 1 }
	)
	_analytics.flush()

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "严格 Schema 应注册成功。")
	assert_true(GFVariantData.get_option_bool(track_report, "ok"), "合法属性应通过精确版本校验。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "合法事件应被 Analytics 接受。")
	assert_eq(
		GFVariantData.get_option_string_name(track_report, "reason"),
		&"tracked",
		"成功应返回稳定 tracked 原因。"
	)
	var event_id: String = GFVariantData.get_option_string(track_report, "event_id")
	assert_true(GFUuid.is_valid(event_id, 7), "版本化事件应获得 UUID v7 身份。")
	var events: Array = GFVariantData.get_option_array(captured.payload, "events")
	assert_eq(events.size(), 1, "版本化事件应进入 transport payload。")
	if events.is_empty():
		return
	var event: Dictionary = GFVariantData.as_dictionary(events[0])
	assert_eq(GFVariantData.get_option_string(event, "event_id"), event_id, "返回身份与发送身份应一致。")
	assert_eq(GFVariantData.get_option_int(event, "schema_version"), 1, "发送事件应携带精确版本。")


func test_track_versioned_invalid_properties_do_not_queue_or_emit() -> void:
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_versioned_event_schema()
	)
	watch_signals(_analytics)

	var track_report: Dictionary = _analytics.track_versioned(
		&"opened",
		1,
		{ "index": "1" }
	)

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "严格 Schema 应注册成功。")
	assert_false(GFVariantData.get_option_bool(track_report, "accepted"), "类型错误不得被接受。")
	assert_eq(
		GFVariantData.get_option_string_name(track_report, "reason"),
		&"properties_invalid",
		"普通 Schema 错误应返回 properties_invalid。"
	)
	assert_true(
		GFVariantData.get_option_value(track_report, "validation") is GFValidationReport,
		"失败结果应携带结构化校验报告。"
	)
	assert_eq(_analytics.get_queue_size(), 0, "无效事件不得入队。")
	assert_signal_not_emitted(_analytics, "event_tracked", "无效事件不得发出 event_tracked。")


func test_track_versioned_rejects_nested_report_budget_marker_after_encoding() -> void:
	_analytics.config.max_payload_bytes = 4096
	_analytics.config.max_collection_items = 256
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_any_payload_versioned_event_schema()
	)
	var packed_values: PackedInt32Array = PackedInt32Array()
	var resize_error: Error = packed_values.resize(200) as Error

	assert_eq(resize_error, OK, "测试载荷应成功扩容。")
	var track_report: Dictionary = _analytics.track_versioned(
		&"packed_payload",
		1,
		{
			"payload": {
				"values": packed_values,
			},
		}
	)

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "ANY 属性 Schema 应注册成功。")
	assert_false(GFVariantData.get_option_bool(track_report, "accepted"), "嵌套预算标记不得作为版本化属性入队。")
	assert_eq(
		GFVariantData.get_option_string_name(track_report, "reason"),
		&"validation_budget_exceeded",
		"编码后出现嵌套预算标记应失败关闭。"
	)
	assert_eq(_analytics.get_queue_size(), 0, "编码截断的版本化事件不得留在队列。")


func test_track_versioned_requires_exact_registered_version() -> void:
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_versioned_event_schema()
	)

	var track_report: Dictionary = _analytics.track_versioned(
		&"opened",
		2,
		{ "index": 1 }
	)

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "版本 1 Schema 应注册成功。")
	assert_eq(
		GFVariantData.get_option_string_name(track_report, "reason"),
		&"schema_not_registered",
		"缺少版本 2 时不得隐式回退版本 1。"
	)
	assert_eq(_analytics.get_queue_size(), 0, "缺少精确版本时不得入队。")


func test_track_versioned_rejects_schema_version_outside_positive_int32() -> void:
	var track_report: Dictionary = _analytics.track_versioned(
		&"opened",
		2_147_483_648,
		{ "index": 1 }
	)

	assert_false(GFVariantData.get_option_bool(track_report, "ok"), "版本越界不得进入 Registry 查询。")
	assert_eq(
		GFVariantData.get_option_string_name(track_report, "reason"),
		&"invalid_schema_version",
		"版本越界应返回稳定的非法版本原因。"
	)
	assert_eq(_analytics.get_queue_size(), 0, "版本越界不得留下事件。")


func test_track_versioned_auto_flush_still_reports_accepted() -> void:
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_versioned_event_schema()
	)
	_analytics.config.batch_size = 1

	var track_report: Dictionary = _analytics.track_versioned(
		&"opened",
		1,
		{ "index": 1 }
	)

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "严格 Schema 应注册成功。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "同步 dry-run 清队列后仍应报告事件已接受。")
	assert_eq(_analytics.get_queue_size(), 0, "batch_size=1 应同步完成 dry-run。")
	assert_false(track_report.has("queued"), "返回值不得用瞬时 queued 状态误导调用方。")


func test_versioned_identity_survives_minimum_report_budgets() -> void:
	_analytics.config.max_string_length = 1
	_analytics.config.max_collection_items = 1
	_analytics.config.max_total_nodes = 1
	var tracked_events: Array[Dictionary] = []
	var completed_results: Array[Dictionary] = []
	var _tracked_connected: Error = _analytics.event_tracked.connect(
		func(_event_name: StringName, event_data: Dictionary) -> void:
			tracked_events.append(event_data.duplicate(true))
	) as Error
	var _completed_connected: Error = _analytics.flush_completed.connect(
		func(result: Dictionary) -> void:
			completed_results.append(result.duplicate(true))
	) as Error
	var registration: Dictionary = _analytics.schema_registry.register_schema(
		_make_empty_versioned_event_schema()
	)

	var track_report: Dictionary = _analytics.track_versioned(&"opened", 1, {})

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "空属性 Schema 应注册成功。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "最小属性预算仍应接受空属性事件。")
	assert_eq(tracked_events.size(), 1, "合法版本化事件应通过隔离信号公开完整信封。")
	if tracked_events.is_empty():
		return
	var event: Dictionary = tracked_events[0]
	assert_eq(
		GFVariantData.get_option_string(event, "event_id"),
		GFVariantData.get_option_string(track_report, "event_id"),
		"可信 event_id 不得被属性报告预算截断。"
	)
	assert_true(
		GFUuid.is_valid(GFVariantData.get_option_string(event, "event_id"), 7),
		"队列中应保留完整 UUIDv7。"
	)
	assert_eq(GFVariantData.get_option_int(event, "schema_version"), 1, "可信 schema_version 不得丢失。")
	assert_eq(GFVariantData.get_option_string(event, "event"), "opened", "可信事件名不得被字符串预算截断。")
	assert_true(
		GFVariantData.get_option_value(event, "properties") is Dictionary,
		"properties 根容器应保持 Dictionary。"
	)
	_analytics.flush()
	assert_eq(_analytics.get_queue_size(), 0, "最小报告预算不得把成功 transport 结果误判为失败。")
	assert_eq(completed_results.size(), 1, "最小报告预算下 flush 仍应完成一次。")
	if not completed_results.is_empty():
		assert_true(GFVariantData.get_option_bool(completed_results[0], "success"), "可信 success 控制字段不得被报告预算截断。")
		assert_eq(GFVariantData.get_option_int(completed_results[0], "accepted"), 1, "可信 accepted 控制字段不得被报告预算截断。")


func test_schema_registry_assignment_never_exposes_null() -> void:
	_analytics.schema_registry = null

	assert_not_null(_analytics.schema_registry, "schema_registry 公共属性必须始终可用。")
	assert_eq(
		GFVariantData.get_option_int(_analytics.schema_registry.get_debug_snapshot(), "schema_count"),
		0,
		"null 赋值应恢复为空注册表。"
	)


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
	assert_eq(_analytics.get_dropped_event_count(), 1, "丢弃最旧事件必须计入统一累计值。")


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


func test_analytics_headers_enforce_http_field_grammar() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.headers = {
		"X:Colon": "no",
		"X Space": "no",
		"X-Control": "bad\u0001value",
		"X-Tab": "one\ttwo",
		"X-Utf8": "中文",
	}

	var headers: PackedStringArray = config.build_headers()

	assert_eq(headers.size(), 3, "只应保留默认 Header 和两个协议合法字段。")
	assert_true(headers.has("X-Tab: one\ttwo"), "字段值应允许 HTTP 线性制表符。")
	assert_true(headers.has("X-Utf8: 中文"), "无控制字符的 UTF-8 字段值应保持。")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：X:Colon")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：X Space")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：X-Control")


func test_analytics_headers_apply_bounded_custom_header_budget() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	for index: int in range(65):
		config.headers["X-Budget-%d" % index] = "value"

	var headers: PackedStringArray = config.build_headers()

	assert_eq(headers.size(), 65, "结果最多应包含默认 Header 和 64 个自定义 Header。")
	assert_push_warning("[GFAnalyticsConfig] 自定义 HTTP Header 数量超过 64，已忽略剩余字段。")


func test_analytics_headers_apply_byte_budgets() -> void:
	var oversized_config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	oversized_config.headers = {
		"X-Oversized": "s".repeat(8193),
	}

	var oversized_headers: PackedStringArray = oversized_config.build_headers()

	assert_eq(oversized_headers.size(), 1, "超过单字段字节预算的 Header 不得进入请求。")
	assert_push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：X-Oversized")

	var total_config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	for index: int in range(9):
		total_config.headers["X-Total-%d" % index] = "v".repeat(8100)

	var total_headers: PackedStringArray = total_config.build_headers()

	assert_eq(total_headers.size(), 9, "总预算应只允许默认 Header 和前八个大字段。")
	assert_push_warning("[GFAnalyticsConfig] 自定义 HTTP Header 总字节数超过 65536，已忽略剩余字段。")


func test_analytics_headers_reject_case_insensitive_duplicates() -> void:
	var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
	config.headers = {
		"X-Trace": "first",
		"x-trace": "second",
	}

	var headers: PackedStringArray = config.build_headers()

	assert_eq(headers.size(), 2, "同名 Header 只能保留一个大小写变体。")
	assert_true(headers.has("X-Trace: first"), "应保留第一个合法 Header。")
	assert_false(headers.has("x-trace: second"), "后续大小写重复字段必须拒绝。")
	assert_push_warning("[GFAnalyticsConfig] 忽略重复 HTTP Header：x-trace")


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


func test_flush_started_dispose_prevents_transport_after_notification() -> void:
	_analytics.config.batch_size = 10
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		captured.call_count += 1
		return { "success": true, "accepted": 1 }
	var analytics_ref: GFAnalyticsUtility = _analytics
	var on_flush_started: Callable = func(_batch: Array) -> void:
		analytics_ref.dispose()
	var _started_connected: Error = _analytics.flush_started.connect(on_flush_started) as Error
	watch_signals(_analytics)
	_analytics.track(&"dispose_on_start")

	_analytics.flush()

	assert_eq(captured.call_count, 0, "flush_started 中 dispose 后不得继续调用 transport。")
	assert_signal_emitted(_analytics, "flush_failed", "被 dispose 中断的批次应明确失败。")
	assert_signal_emitted(_analytics, "flush_completed", "中断批次仍应完成一次生命周期。")
	_analytics.flush_started.disconnect(on_flush_started)


func test_transport_dispose_does_not_double_finish_flush() -> void:
	_analytics.config.batch_size = 10
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	var signal_counts: Array[int] = [0, 0]
	var analytics_ref: GFAnalyticsUtility = _analytics
	var _failure_connected: Error = _analytics.flush_failed.connect(
		func(_result: Dictionary) -> void:
			signal_counts[0] += 1
	) as Error
	var _completion_connected: Error = _analytics.flush_completed.connect(
		func(_result: Dictionary) -> void:
			signal_counts[1] += 1
	) as Error
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		captured.call_count += 1
		analytics_ref.dispose()
		return { "success": true, "accepted": 1 }
	_analytics.track(&"dispose_in_transport")

	_analytics.flush()

	assert_eq(captured.call_count, 1, "transport 应只调用一次。")
	assert_eq(signal_counts[0], 1, "transport 中 dispose 应只完成一次失败。")
	assert_eq(signal_counts[1], 1, "transport 中 dispose 应只完成一次 completion。")
	assert_false(_analytics.transport_callback.is_valid(), "transport 中 dispose 应释放 transport callback。")


func test_flush_failed_dispose_is_non_recursive_and_completes_once() -> void:
	_analytics.config.batch_size = 10
	var signal_counts: Array[int] = [0, 0]
	var analytics_ref: GFAnalyticsUtility = _analytics
	var on_flush_failed: Callable = func(_result: Dictionary) -> void:
		signal_counts[0] += 1
		analytics_ref.dispose()
	var _failure_connected: Error = _analytics.flush_failed.connect(on_flush_failed) as Error
	var _completion_connected: Error = _analytics.flush_completed.connect(
		func(_result: Dictionary) -> void:
			signal_counts[1] += 1
	) as Error
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		return { "success": false, "error": "offline" }
	_analytics.track(&"dispose_on_failure")

	_analytics.flush()

	assert_eq(signal_counts[0], 1, "flush_failed 监听器 dispose 不得递归再次发出失败。")
	assert_eq(signal_counts[1], 1, "失败批次应只发出一次 completion。")
	_analytics.flush_failed.disconnect(on_flush_failed)


func test_flush_completed_shutdown_drains_remaining_batches_without_looping() -> void:
	_analytics.config.batch_size = 8
	_analytics.config.flush_on_shutdown = true
	var transport_calls: Array[int] = [0]
	var completed_calls: Array[int] = [0]
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		transport_calls[0] += 1
		return {
			"success": true,
			"accepted": GFVariantData.get_option_array(payload, "events").size(),
	}
	var analytics_ref: GFAnalyticsUtility = _analytics
	var on_flush_completed: Callable = func(_result: Dictionary) -> void:
		completed_calls[0] += 1
		if completed_calls[0] == 1:
			analytics_ref.shutdown(true)
	var _completed_connected: Error = _analytics.flush_completed.connect(on_flush_completed) as Error
	_analytics.track(&"first")
	_analytics.track(&"second")
	_analytics.config.batch_size = 1

	_analytics.flush()

	assert_eq(transport_calls[0], 2, "通知中的 shutdown 应在通知结束后继续排空剩余批次。")
	assert_eq(completed_calls[0], 2, "每个排空批次都应完成一次。")
	assert_eq(_analytics.get_queue_size(), 0, "shutdown drain 应清空剩余同步批次。")
	_analytics.flush_completed.disconnect(on_flush_completed)


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
	var tags_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(properties, "tags"),
		"__gf_report_value__"
	)
	var position_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "position"), "__gf_variant__")
	var circular_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(properties, "circular"), "self"),
		"__gf_report_value__"
	)
	assert_eq(GFVariantData.get_option_string(nan_marker, "value"), "NaN", "NaN 应使用统一 typed marker。")
	assert_eq(GFVariantData.get_option_int(tags_marker, "version"), 1)
	assert_eq(GFVariantData.get_option_string(tags_marker, "type"), "PackedArray")
	assert_true(GFVariantData.get_option_bool(tags_marker, "redacted"))
	assert_eq(GFVariantData.get_option_string(tags_marker, "collection_type"), "PackedStringArray")
	assert_eq(GFVariantData.get_option_int(tags_marker, "count"), 2)
	assert_eq(GFVariantData.get_option_array(tags_marker, "items"), ["a", "b"])
	assert_eq(GFVariantData.get_option_string(position_marker, "type"), "Vector2", "Vector2 应使用统一 JSON-safe typed marker。")
	assert_eq(GFVariantData.get_option_int(circular_marker, "version"), 1)
	assert_eq(GFVariantData.get_option_string(circular_marker, "type"), "CircularReference", "循环 Dictionary 应使用统一 report marker。")
	assert_true(GFVariantData.get_option_bool(circular_marker, "redacted"))
	assert_eq(circular_marker.size(), 3, "循环 marker 只能暴露固定 schema 字段。")


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


func test_payload_builder_flush_reentry_is_ignored_without_recursion() -> void:
	var builder_calls: Array[int] = [0]
	var transport_calls: Array[int] = [0]
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		builder_calls[0] += 1
		_analytics.flush()
		return { "channel": "reentrant" }
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		transport_calls[0] += 1
		return {
			"success": true,
			"accepted": GFVariantData.get_option_array(payload, "events").size(),
		}
	_analytics.track(&"reentrant_builder")

	_analytics.flush()

	assert_eq(builder_calls[0], 1, "payload_builder 内 flush 不得递归进入 planner。")
	assert_eq(transport_calls[0], 1, "合法外层批次仍应发送一次。")
	assert_eq(_analytics.get_queue_size(), 0, "成功批次应正常完成。")


func test_payload_builder_queue_mutation_invalidates_stale_plan() -> void:
	var transport_calls: Array[int] = [0]
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		_analytics.clear_queue()
		return { "channel": "mutated" }
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		transport_calls[0] += 1
		return { "success": true, "accepted": 1 }
	_analytics.track(&"stale_plan")

	_analytics.flush()

	assert_eq(transport_calls[0], 0, "planner 回调改写队列后不得发送过期候选。")
	assert_eq(_analytics.get_queue_size(), 0, "回调显式清空队列的结果应保留。")


func test_non_monotonic_payload_builder_still_selects_largest_fitting_prefix() -> void:
	_analytics.config.batch_size = 10
	_analytics.config.max_queue_size = 10
	_analytics.config.max_payload_bytes = 1024
	_analytics.config.max_string_length = 1024
	var captured: AnalyticsPayloadCapture = AnalyticsPayloadCapture.new()
	_analytics.payload_builder = func(batch: Array) -> Dictionary:
		if batch.size() == 3:
			return { "mode": "fit" }
		return { "padding": "p".repeat(850) }
	_analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
		captured.events = GFVariantData.get_option_array(payload, "events").duplicate(true)
		return { "success": true, "accepted": captured.events.size() }
	for index: int in range(4):
		_analytics.track(&"non_monotonic", { "index": index })

	_analytics.flush()

	assert_eq(captured.events.size(), 3, "planner 必须按最大到最小验证，不能用单调性假设跳过可发送前缀。")
	assert_eq(_analytics.get_queue_size(), 1, "最大可发送前缀之后的事件应继续留队。")


func test_planner_work_budget_retains_queue_instead_of_dropping() -> void:
	_analytics.config.batch_size = 500
	_analytics.config.max_queue_size = 500
	_analytics.config.max_payload_bytes = 16 * 1024
	_analytics.config.max_string_length = 16 * 1024
	var failures: Array[Dictionary] = []
	var transport_calls: Array[int] = [0]
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return { "padding": "p".repeat(15_000) }
	_analytics.transport_callback = func(_payload: Dictionary) -> Dictionary:
		transport_calls[0] += 1
		return { "success": true, "accepted": 1 }
	var _failure_connected: Error = _analytics.flush_failed.connect(
		func(result: Dictionary) -> void:
			failures.append(result.duplicate(true))
	) as Error
	for index: int in range(50):
		_analytics.track(&"planner_budget", { "index": index })

	_analytics.flush()

	assert_eq(transport_calls[0], 0, "planner 尚未证明前缀可发送时不得调用 transport。")
	assert_eq(_analytics.get_queue_size(), 50, "planner 工作预算耗尽必须保留完整队列。")
	assert_eq(failures.size(), 1, "工作预算耗尽应产生一次明确失败进展。")
	if not failures.is_empty():
		assert_true(GFVariantData.get_option_bool(failures[0], "retained"), "失败结果应明确队列仍被保留。")
		assert_false(GFVariantData.get_option_bool(failures[0], "dropped"), "工作预算失败不得伪装成 drop。")
		assert_eq(GFVariantData.get_option_string(failures[0], "drop_reason"), "planner_budget_exceeded", "工作预算失败应返回稳定原因。")


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


func test_oversized_drop_notifications_do_not_reenter_flush() -> void:
	_analytics.config.batch_size = 1
	_analytics.config.max_payload_bytes = 1024
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return { "padding": "p".repeat(900) }
	var started_count: Array[int] = [0]
	var analytics_ref: GFAnalyticsUtility = _analytics
	var on_flush_started: Callable = func(_batch: Array) -> void:
		started_count[0] += 1
		if started_count[0] == 1:
			analytics_ref.track(&"replacement", { "value": "v".repeat(180) })
	var _started_connected: Error = _analytics.flush_started.connect(on_flush_started) as Error
	_analytics.track(&"oversized", { "value": "v".repeat(180) })

	assert_eq(started_count[0], 1, "drop 通知中的自动 flush 必须被通知 guard 阻止。")
	assert_eq(_analytics.get_queue_size(), 1, "通知中新入队事件应留给后续显式 flush。")
	_analytics.flush_started.disconnect(on_flush_started)


func test_drop_notification_shutdown_drains_remaining_events() -> void:
	_analytics.config.batch_size = 10
	_analytics.config.max_payload_bytes = 1024
	_analytics.config.flush_on_shutdown = true
	_analytics.payload_builder = func(_batch: Array) -> Dictionary:
		return { "padding": "p".repeat(900) }
	var completion_count: Array[int] = [0]
	var analytics_ref: GFAnalyticsUtility = _analytics
	var on_flush_completed: Callable = func(_result: Dictionary) -> void:
		completion_count[0] += 1
		if completion_count[0] == 1:
			analytics_ref.shutdown(true)
	var _completed_connected: Error = _analytics.flush_completed.connect(on_flush_completed) as Error
	_analytics.track(&"first_oversized", { "value": "v".repeat(180) })
	_analytics.track(&"second_oversized", { "value": "v".repeat(180) })

	_analytics.flush()

	assert_eq(completion_count[0], 2, "drop 通知中的 shutdown 应在通知结束后继续 drain。")
	assert_eq(_analytics.get_queue_size(), 0, "shutdown drain 应处理全部不可发送事件并终止。")
	_analytics.flush_completed.disconnect(on_flush_completed)


func test_response_parser_non_dictionary_fails_closed_and_requeues_batch() -> void:
	var analytics: PendingHTTPResponseAnalyticsUtility = PendingHTTPResponseAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.response_parser = func(
		_response_code: int,
		_body: PackedByteArray,
		_fallback_accepted: int
	) -> Variant:
		return null
	var failures: Array[Dictionary] = []
	var _failure_connected: Error = analytics.flush_failed.connect(
		func(result: Dictionary) -> void:
			failures.append(result.duplicate(true))
	) as Error
	analytics.track(&"pending_response")
	analytics.flush()

	analytics.complete_response("{}")

	assert_eq(analytics.get_queue_size(), 1, "无效 parser 结果必须回灌原批次。")
	assert_eq(failures.size(), 1, "无效 parser 结果应明确失败一次。")
	analytics.dispose()


func test_non_success_http_response_does_not_expose_response_body() -> void:
	var analytics: PendingHTTPResponseAnalyticsUtility = PendingHTTPResponseAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	var failures: Array[Dictionary] = []
	var _failure_connected: Error = analytics.flush_failed.connect(
		func(result: Dictionary) -> void:
			failures.append(result.duplicate(true))
	) as Error
	analytics.track(&"server_failure")
	analytics.flush()

	analytics.complete_response("secret-canary\r\nInjected: value", 503)

	assert_eq(failures.size(), 1, "非成功 HTTP 响应应产生一次结构化失败。")
	if failures.is_empty():
		analytics.dispose()
		return
	var failure: Dictionary = failures[0]
	assert_eq(GFVariantData.get_option_string(failure, "error"), "HTTP 503", "公开错误只应包含稳定状态。")
	assert_eq(GFVariantData.get_option_int(failure, "response_code"), 503, "HTTP 状态码应作为结构化字段公开。")
	assert_false(JSON.stringify(failure).contains("secret-canary"), "远端响应正文不得进入公共失败信号。")
	assert_eq(analytics.get_queue_size(), 1, "HTTP 失败后原批次仍应回灌。")
	analytics.dispose()


func test_response_parser_state_change_cannot_finish_a_new_generation() -> void:
	var analytics: PendingHTTPResponseAnalyticsUtility = PendingHTTPResponseAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	var parser_calls: Array[int] = [0]
	var analytics_ref: PendingHTTPResponseAnalyticsUtility = analytics
	analytics.response_parser = func(
		_response_code: int,
		_body: PackedByteArray,
		_fallback_accepted: int
	) -> Dictionary:
		parser_calls[0] += 1
		analytics_ref.dispose()
		analytics_ref.init()
		analytics_ref.config.auto_capture_context = false
		analytics_ref.config.flush_interval_seconds = 0.0
		analytics_ref.track(&"new_generation")
		return { "success": true, "accepted": 1 }
	analytics.track(&"old_generation")
	analytics.flush()

	analytics.complete_response("{}")

	assert_eq(parser_calls[0], 1, "response_parser 应调用一次。")
	assert_eq(analytics.get_queue_size(), 1, "旧 HTTP callback 不得完成 parser 中创建的新 generation。")
	assert_false(analytics.response_parser.is_valid(), "parser 中 dispose 应释放旧 generation 的 parser。")
	analytics.dispose()


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


func _make_versioned_event_schema() -> GFAnalyticsEventSchema:
	var field: GFSchemaField = GFSchemaField.new().configure(
		&"index",
		GFSchemaField.ValueType.INT,
		{
			"required": true,
			"allow_null": false,
		}
	)
	var properties_schema: GFDictionarySchema = GFDictionarySchema.new().configure(
		&"analytics.opened.properties",
		[field],
		{
			"allow_extra_fields": false,
			"coerce_values": false,
		}
	)
	return GFAnalyticsEventSchema.new().configure(&"opened", 1, properties_schema)


func _make_empty_versioned_event_schema() -> GFAnalyticsEventSchema:
	var properties_schema: GFDictionarySchema = GFDictionarySchema.new().configure(
		&"analytics.opened.empty_properties",
		[],
		{
			"allow_extra_fields": false,
			"coerce_values": false,
		}
	)
	return GFAnalyticsEventSchema.new().configure(&"opened", 1, properties_schema)


func _make_any_payload_versioned_event_schema() -> GFAnalyticsEventSchema:
	var field: GFSchemaField = GFSchemaField.new().configure(
		&"payload",
		GFSchemaField.ValueType.ANY,
		{
			"required": true,
			"allow_null": false,
		}
	)
	var properties_schema: GFDictionarySchema = GFDictionarySchema.new().configure(
		&"analytics.packed_payload.properties",
		[field],
		{
			"allow_extra_fields": false,
			"coerce_values": false,
		}
	)
	return GFAnalyticsEventSchema.new().configure(&"packed_payload", 1, properties_schema)


# --- 内部类 ---

class AnalyticsPayloadCapture:
	extends RefCounted

	var events: Array = []
	var payload: Dictionary = {}
	var call_count: int = 0


class PendingAnalyticsUtility extends GFAnalyticsUtility:
	func _send_batch(_batch: Array) -> void:
		pass


class PendingHTTPResponseAnalyticsUtility extends GFAnalyticsUtility:
	func _send_batch(_batch: Array) -> void:
		_active_http_generation = _flush_generation


	func complete_response(body_text: String, response_code: int = 200) -> void:
		_on_request_completed(
			HTTPRequest.RESULT_SUCCESS,
			response_code,
			PackedStringArray(),
			body_text.to_utf8_buffer()
		)


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
