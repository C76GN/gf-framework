## 测试 GFAnalyticsOutboxAdapter 的持久交接、协议校验与所有权边界。
extends GutTest


# --- 私有变量 ---

const _PRIMARY_PATH: String = "user://test_gf_analytics_outbox_adapter.json"
const _SECONDARY_PATH: String = "user://test_gf_analytics_outbox_adapter_reload.json"

var _outboxes: Array[GFRequestOutboxUtility] = []
var _analytics_instances: Array[GFAnalyticsUtility] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_remove_outbox_files(_PRIMARY_PATH)
	_remove_outbox_files(_SECONDARY_PATH)


func after_each() -> void:
	for analytics: GFAnalyticsUtility in _analytics_instances:
		if analytics != null:
			analytics.dispose()
	_analytics_instances.clear()
	for outbox: GFRequestOutboxUtility in _outboxes:
		if outbox != null:
			outbox.dispose()
	_outboxes.clear()
	_remove_outbox_files(_PRIMARY_PATH)
	_remove_outbox_files(_SECONDARY_PATH)
	_remove_file_if_exists("user://gf_analytics_client.cfg")


# --- 测试方法 ---

func test_enqueue_payload_persists_fixed_neutral_envelope() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()

	var report: Dictionary = adapter.enqueue_payload({ "events": [event] })

	assert_true(GFVariantData.get_option_bool(report, "success"), "持久化成功后 Adapter 应接受整批。")
	assert_true(GFVariantData.get_option_bool(report, "persisted"), "成功报告必须明确已经可靠落盘。")
	assert_eq(GFVariantData.get_option_int(report, "accepted"), 1, "v1 应整批接受一个事件。")
	assert_eq(outbox.get_queue_size(), 1, "成功交接后 Outbox 应保存一个请求。")
	assert_true(FileAccess.file_exists(_PRIMARY_PATH), "可靠交接应创建持久化文件。")

	var pending_requests: Array[GFRequestEnvelope] = outbox.get_pending_requests()
	assert_eq(pending_requests.size(), 1, "应能查询到持久化请求副本。")
	if pending_requests.is_empty():
		return
	var envelope: GFRequestEnvelope = pending_requests[0]
	assert_true(adapter.handles_request(envelope), "Adapter 应识别自己创建的完整协议请求。")
	assert_true(envelope.headers.is_empty(), "持久化信封不得包含鉴权或供应商 Header。")
	assert_eq(
		GFVariantData.get_option_string(envelope.body, "schema_id"),
		String(GFAnalyticsOutboxAdapter.SCHEMA_ID),
		"body 应使用固定中立协议标识。"
	)
	assert_eq(
		GFVariantData.get_option_int(envelope.body, "protocol_version"),
		GFAnalyticsOutboxAdapter.PROTOCOL_VERSION,
		"body 应固定协议版本。"
	)


func test_same_versioned_batch_is_idempotently_reused() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()

	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	var second: Dictionary = adapter.enqueue_payload({ "events": [event.duplicate(true)] })

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_true(GFVariantData.get_option_bool(second, "success"), "相同事件批次应复用可靠副本。")
	assert_eq(
		GFVariantData.get_option_string_name(second, "reason"),
		&"already_queued",
		"重复批次应返回稳定 already_queued 原因。"
	)
	assert_eq(
		GFVariantData.get_option_string(second, "idempotency_key"),
		GFVariantData.get_option_string(first, "idempotency_key"),
		"相同有序 event_id 应派生相同幂等键。"
	)
	assert_eq(outbox.get_queue_size(), 1, "幂等复用不得新增重复请求。")


func test_existing_pending_batch_must_be_repersisted_before_reuse() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()
	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	outbox.max_storage_bytes = 1

	var failed_reuse: Dictionary = adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_false(
		GFVariantData.get_option_bool(failed_reuse, "success"),
		"无法重新确认落盘时不得接受已有 pending。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(failed_reuse, "reason"),
		&"persistence_failed",
		"pending 耐久复核失败应给出稳定原因。"
	)
	assert_eq(
		GFVariantData.get_option_int(failed_reuse, "persistence_error"),
		ERR_OUT_OF_MEMORY,
		"pending 耐久复核应保留存储错误码。"
	)
	outbox.max_storage_bytes = 16 * 1024 * 1024
	var verified_reuse: Dictionary = adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})
	assert_true(
		GFVariantData.get_option_bool(verified_reuse, "success"),
		"恢复存储预算后才可复用已有 pending。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(verified_reuse, "reason"),
		&"already_queued",
		"成功复核后应返回 already_queued。"
	)


func test_exhausted_pending_batch_is_not_reported_as_queued() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		outbox,
		{ "max_attempts": 1 }
	)
	var event: Dictionary = _make_versioned_event()
	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	var exhausted: GFRequestEnvelope = outbox.get_pending_requests()[0]
	assert_true(outbox.remove_request(exhausted.request_id), "测试应能取出待模拟崩溃状态的请求。")
	exhausted.mark_attempt()
	assert_true(outbox.enqueue(exhausted), "测试应能恢复尚未迁入 failed store 的耗尽 pending。")

	var duplicate_report: Dictionary = adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_false(
		GFVariantData.get_option_bool(duplicate_report, "success"),
		"耗尽 pending 永远不会发送，不得报告成功。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(duplicate_report, "reason"),
		&"exhausted_pending",
		"耗尽但尚未迁移的 pending 应返回稳定原因。"
	)
	assert_eq(
		GFVariantData.get_option_int(duplicate_report, "accepted"),
		0,
		"耗尽 pending 不得接受重复事件。"
	)
	assert_eq(outbox.get_queue_size(), 1, "Adapter 不应擅自删除或复活耗尽请求。")


func test_failed_batch_is_not_reported_as_durable_success() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	outbox.retry_delays_msec = [0]
	outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": false, "error": "denied" }
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		outbox,
		{ "max_attempts": 1 }
	)
	var event: Dictionary = _make_versioned_event()
	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	var replay_report: Dictionary = await outbox.replay()

	var duplicate_report: Dictionary = adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_eq(
		GFVariantData.get_option_int(replay_report, "failed"),
		1,
		"测试批次应耗尽并进入 failed store。"
	)
	assert_eq(outbox.get_failed_request_count(), 1, "应保留一个 dead-letter 请求。")
	assert_false(
		GFVariantData.get_option_bool(duplicate_report, "success"),
		"dead-letter 不得被误报为耐久成功。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(duplicate_report, "reason"),
		&"already_failed",
		"重复 dead-letter 应返回 already_failed。"
	)
	assert_eq(
		GFVariantData.get_option_int(duplicate_report, "accepted"),
		0,
		"failed store 不得接受事件。"
	)


func test_tampered_existing_request_identity_fails_idempotent_reuse() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()
	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	var existing: GFRequestEnvelope = outbox.get_pending_requests()[0]
	assert_true(outbox.remove_request(existing.request_id), "测试应移除原始协议请求。")
	existing.request_id = &"tampered_request_id"
	assert_true(outbox.enqueue(existing), "测试应写入幂等键相同但身份被篡改的请求。")

	var second: Dictionary = adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_false(GFVariantData.get_option_bool(second, "success"), "篡改 request_id 的请求不得被复用。")
	assert_eq(
		GFVariantData.get_option_string_name(second, "reason"),
		&"idempotency_conflict",
		"协议身份不完整时应失败关闭。"
	)


func test_same_event_identity_with_changed_payload_fails_closed() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()
	var first: Dictionary = adapter.enqueue_payload({ "events": [event] })
	var conflicting: Dictionary = event.duplicate(true)
	conflicting["properties"] = { "index": 99 }

	var second: Dictionary = adapter.enqueue_payload({ "events": [conflicting] })

	assert_true(GFVariantData.get_option_bool(first, "success"), "首次交接应成功。")
	assert_false(GFVariantData.get_option_bool(second, "success"), "相同 event_id 的不同内容不得被静默复用。")
	assert_eq(
		GFVariantData.get_option_string_name(second, "reason"),
		&"idempotency_conflict",
		"身份碰撞应 fail closed。"
	)
	assert_eq(outbox.get_queue_size(), 1, "冲突请求不得进入队列。")


func test_persistence_failure_rolls_back_adapter_request() -> void:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.auto_load_on_init = false
	outbox.storage_path = "res://analytics_outbox_must_not_write.json"
	outbox.init()
	_outboxes.append(outbox)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)

	var report: Dictionary = adapter.enqueue_payload({
		"events": [_make_versioned_event()],
	})

	assert_false(GFVariantData.get_option_bool(report, "success"), "落盘失败时不得向 Analytics 报告成功。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"persistence_failed",
		"落盘失败应提供稳定原因。"
	)
	assert_eq(outbox.get_queue_size(), 0, "可靠入队失败必须回滚本次内存请求。")


func test_full_outbox_rejects_without_removing_existing_request() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	outbox.max_queue_size = 1
	var seed_envelope: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"gf://other/request"
	)
	assert_true(outbox.enqueue(seed_envelope), "测试前置请求应成功入队。")
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)

	var report: Dictionary = adapter.enqueue_payload({
		"events": [_make_versioned_event()],
	})

	assert_false(GFVariantData.get_option_bool(report, "success"), "满队列不得接受新批次。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"outbox_rejected",
		"满队列应折叠为稳定 Outbox 拒绝原因。"
	)
	assert_eq(outbox.get_queue_size(), 1, "拒绝不得移除已有业务请求。")
	assert_eq(outbox.get_pending_requests()[0].url, "gf://other/request", "已有请求应保持不变。")


func test_reload_preserves_request_and_idempotency_identity() -> void:
	var first_outbox: GFRequestOutboxUtility = _make_outbox(_SECONDARY_PATH)
	var first_adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(first_outbox)
	var event: Dictionary = _make_versioned_event()
	var enqueue_report: Dictionary = first_adapter.enqueue_payload({ "events": [event] })
	var request_id: String = GFVariantData.get_option_string(enqueue_report, "request_id")
	var idempotency_key: String = GFVariantData.get_option_string(
		enqueue_report,
		"idempotency_key"
	)

	var second_outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	second_outbox.storage_path = _SECONDARY_PATH
	second_outbox.auto_load_on_init = true
	second_outbox.init()
	_outboxes.append(second_outbox)
	var second_adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		second_outbox
	)

	assert_eq(second_outbox.get_queue_size(), 1, "新实例应恢复一个待重放批次。")
	var restored: GFRequestEnvelope = second_outbox.get_pending_requests()[0]
	assert_eq(String(restored.request_id), request_id, "重启后 request_id 必须稳定。")
	assert_eq(restored.idempotency_key, idempotency_key, "重启后幂等键必须稳定。")
	assert_true(second_adapter.handles_request(restored), "恢复请求仍应通过固定协议校验。")
	var duplicate_report: Dictionary = second_adapter.enqueue_payload({
		"events": [event.duplicate(true)],
	})
	assert_true(
		GFVariantData.get_option_bool(duplicate_report, "success"),
		"重启后相同批次不得因 JSON 数字恢复类型变化而误报冲突。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(duplicate_report, "reason"),
		&"already_queued",
		"重启后相同批次应复用已有持久请求。"
	)
	assert_eq(second_outbox.get_queue_size(), 1, "跨重启幂等复用不得新增请求。")


func test_tampered_or_authenticated_envelope_is_not_handled() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var _enqueue_report: Dictionary = adapter.enqueue_payload({
		"events": [_make_versioned_event()],
	})
	var restored: GFRequestEnvelope = outbox.get_pending_requests()[0]

	var tampered_schema: GFRequestEnvelope = restored.duplicate_request()
	tampered_schema.body["protocol_version"] = 99
	var tampered_metadata: GFRequestEnvelope = restored.duplicate_request()
	tampered_metadata.metadata["event_count"] = 99
	var persisted_auth: GFRequestEnvelope = restored.duplicate_request()
	var _auth_header_appended: bool = persisted_auth.headers.append("Authorization: secret")
	var unlimited_retry: GFRequestEnvelope = restored.duplicate_request()
	unlimited_retry.max_attempts = 0
	var excessive_retry: GFRequestEnvelope = restored.duplicate_request()
	excessive_retry.max_attempts = 65
	var text_protocol: GFRequestEnvelope = restored.duplicate_request()
	text_protocol.body["protocol_version"] = "1"
	var fractional_protocol: GFRequestEnvelope = restored.duplicate_request()
	fractional_protocol.body["protocol_version"] = 1.5
	var text_event_count: GFRequestEnvelope = restored.duplicate_request()
	text_event_count.metadata["event_count"] = "1"
	var negative_attempt_count: GFRequestEnvelope = restored.duplicate_request()
	negative_attempt_count.attempt_count = -1
	var negative_retry_deadline: GFRequestEnvelope = restored.duplicate_request()
	negative_retry_deadline.next_attempt_at_unix_msec = -1

	assert_false(adapter.handles_request(tampered_schema), "未知协议版本必须 fail closed。")
	assert_false(adapter.handles_request(tampered_metadata), "body/metadata 不一致必须 fail closed。")
	assert_false(adapter.handles_request(persisted_auth), "持久化鉴权 Header 的请求必须 fail closed。")
	assert_false(adapter.handles_request(unlimited_retry), "恢复请求不得绕过最小尝试次数。")
	assert_false(adapter.handles_request(excessive_retry), "恢复请求不得绕过尝试次数硬上限。")
	assert_false(adapter.handles_request(text_protocol), "协议版本不得接受字符串收窄。")
	assert_false(adapter.handles_request(fractional_protocol), "协议版本不得接受小数截断。")
	assert_false(adapter.handles_request(text_event_count), "事件计数不得接受字符串收窄。")
	assert_false(adapter.handles_request(negative_attempt_count), "协议路由不得接受负尝试次数。")
	assert_false(adapter.handles_request(negative_retry_deadline), "协议路由不得接受负重试截止时间。")
	assert_true(adapter.handles_request(restored), "修改查询副本不得污染内部有效请求。")


func test_configure_does_not_replace_outbox_transport_or_filter() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var transport: Callable = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": true }
	var replay_filter: Callable = func(_envelope: GFRequestEnvelope) -> bool:
		return true
	outbox.transport_callback = transport
	outbox.replay_filter = replay_filter

	var _adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)

	assert_eq(outbox.transport_callback, transport, "Adapter 不得接管项目 transport。")
	assert_eq(outbox.replay_filter, replay_filter, "Adapter 不得接管项目 replay filter。")


func test_direct_budget_assignment_remains_hard_bounded() -> void:
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new()

	adapter.max_payload_bytes = 1 << 30
	adapter.max_events_per_request = 1 << 20
	adapter.max_attempts = 1 << 20
	adapter.max_depth = 1 << 20
	adapter.max_collection_items = 1 << 20
	adapter.max_string_length = 1 << 20
	adapter.max_total_nodes = 1 << 30

	assert_eq(adapter.max_payload_bytes, 16 * 1024 * 1024, "payload 直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_events_per_request, 500, "事件数直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_attempts, 64, "尝试次数直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_depth, 32, "深度直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_collection_items, 4096, "集合直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_string_length, 65536, "字符串直接赋值也必须受硬上限约束。")
	assert_eq(adapter.max_total_nodes, 1000000, "节点数直接赋值也必须受硬上限约束。")

	adapter.max_payload_bytes = 0
	adapter.max_events_per_request = 0
	adapter.max_attempts = 0
	adapter.max_depth = 0
	adapter.max_collection_items = 0
	adapter.max_string_length = 0
	adapter.max_total_nodes = 0

	assert_eq(adapter.max_payload_bytes, 1024, "payload 直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_events_per_request, 1, "事件数直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_attempts, 1, "尝试次数直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_depth, 1, "深度直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_collection_items, 1, "集合直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_string_length, 1, "字符串直接赋值也必须保留最小预算。")
	assert_eq(adapter.max_total_nodes, 1, "节点数直接赋值也必须保留最小预算。")


func test_payload_limits_and_duplicate_event_ids_fail_before_enqueue() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox, {
		"max_events_per_request": 1,
		"max_string_length": 16,
	})
	var event: Dictionary = _make_versioned_event()
	var duplicate_event: Dictionary = event.duplicate(true)
	var too_many: Dictionary = adapter.enqueue_payload({
		"events": [event, duplicate_event],
	})
	var too_long: Dictionary = adapter.enqueue_payload({
		"events": [{
			"event": "x".repeat(17),
			"properties": {},
		}],
	})

	assert_eq(
		GFVariantData.get_option_string_name(too_many, "reason"),
		&"event_limit_exceeded",
		"事件数量上限应在复制和持久化前拒绝。"
	)
	assert_false(GFVariantData.get_option_bool(too_long, "success"), "超长事件名不得持久化。")
	assert_eq(outbox.get_queue_size(), 0, "非法 payload 不得留下请求。")


func test_payload_aggregate_byte_budget_rejects_before_outbox_handoff() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox, {
		"max_payload_bytes": 1024,
		"max_string_length": 1024,
	})
	var event: Dictionary = _make_versioned_event()
	event["properties"] = {
		"first": "a".repeat(400),
		"second": "b".repeat(400),
		"third": "c".repeat(400),
	}

	var report: Dictionary = adapter.enqueue_payload({ "events": [event] })

	assert_false(GFVariantData.get_option_bool(report, "success"), "整批编码下界超过预算时必须拒绝。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"payload_too_large",
		"整批字节预算失败应返回稳定原因。"
	)
	assert_eq(outbox.get_queue_size(), 0, "字节预算失败不得进入 Outbox 深复制或持久化。")


func test_v1_rejects_custom_payload_fields_and_incomplete_event_shapes() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()

	var custom_payload_report: Dictionary = adapter.enqueue_payload({
		"events": [event],
		"tenant": "must-not-be-dropped",
	})
	var incomplete_report: Dictionary = adapter.enqueue_payload({
		"events": [{
			"event": "opened",
		}],
	})
	var extra_event: Dictionary = event.duplicate(true)
	extra_event["tenant"] = "must-not-be-dropped"
	var extra_event_report: Dictionary = adapter.enqueue_payload({
		"events": [extra_event],
	})
	var invalid_properties: Dictionary = event.duplicate(true)
	invalid_properties["properties"] = []
	var invalid_properties_report: Dictionary = adapter.enqueue_payload({
		"events": [invalid_properties],
	})
	var control_name: Dictionary = event.duplicate(true)
	control_name["event"] = "opened\u0001hidden"
	var control_name_report: Dictionary = adapter.enqueue_payload({
		"events": [control_name],
	})

	assert_eq(
		GFVariantData.get_option_string_name(custom_payload_report, "reason"),
		&"unsupported_payload_fields",
		"v1 不得静默丢弃 payload_builder 的自定义顶层字段。"
	)
	for report: Dictionary in [
		incomplete_report,
		extra_event_report,
		invalid_properties_report,
		control_name_report,
	]:
		assert_eq(
			GFVariantData.get_option_string_name(report, "reason"),
			&"invalid_payload",
			"v1 事件必须符合 legacy/versioned 精确字段与类型契约。"
		)
	assert_eq(outbox.get_queue_size(), 0, "协议形状失败不得留下 Outbox 请求。")


func test_debug_snapshot_does_not_expose_event_body() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		outbox,
		{ "endpoint_url": "gf://analytics/private-endpoint-marker" }
	)
	var event: Dictionary = _make_versioned_event()
	event["properties"] = { "private_marker": "must-not-appear" }
	var _enqueue_report: Dictionary = adapter.enqueue_payload({ "events": [event] })

	var snapshot_text: String = JSON.stringify(adapter.get_debug_snapshot())

	assert_false(snapshot_text.contains("private_marker"), "调试快照不得暴露属性键。")
	assert_false(snapshot_text.contains("must-not-appear"), "调试快照不得暴露属性值。")
	assert_false(snapshot_text.contains("\"events\""), "调试快照不得包含事件数组。")
	assert_false(snapshot_text.contains("endpoint_url"), "调试快照不得暴露持久化端点字段。")
	assert_false(snapshot_text.contains("private-endpoint-marker"), "调试快照不得暴露端点值。")


func test_endpoint_rejects_credentials_query_and_fragment() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var event: Dictionary = _make_versioned_event()
	var configured_whitespace: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		outbox,
		{ "endpoint_url": " gf://analytics/events " }
	)
	var configured_whitespace_report: Dictionary = configured_whitespace.enqueue_payload({
		"events": [event.duplicate(true)],
	})
	var configured_empty: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(
		outbox,
		{ "endpoint_url": "" }
	)
	var configured_empty_report: Dictionary = configured_empty.enqueue_payload({
		"events": [event.duplicate(true)],
	})
	for configured_report: Dictionary in [
		configured_whitespace_report,
		configured_empty_report,
	]:
		assert_eq(
			GFVariantData.get_option_string_name(configured_report, "reason"),
			&"invalid_endpoint",
			"configure() 不得规范化或回退调用方显式提供的非法端点。"
		)
	for invalid_endpoint: String in [
		"https://user:secret@example.test/events",
		"https://example.test/events?token=secret",
		"https://example.test/events#secret",
		"gf://analytics/private token",
		"gf://analytics/private\u00a0token",
		"gf://analytics/\u000bevents",
		"gf://analytics/\u0001events",
	]:
		adapter.endpoint_url = invalid_endpoint
		var report: Dictionary = adapter.enqueue_payload({
			"events": [event.duplicate(true)],
		})
		assert_false(
			GFVariantData.get_option_bool(report, "success"),
			"非法持久端点必须拒绝：%s。" % JSON.stringify(invalid_endpoint)
		)
		assert_eq(
			GFVariantData.get_option_string_name(report, "reason"),
			&"invalid_endpoint",
			"非法端点应返回稳定原因：%s。" % JSON.stringify(invalid_endpoint)
		)
	assert_eq(outbox.get_queue_size(), 0, "非法端点不得留下请求。")


func test_schema_version_must_fit_positive_int32() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var max_version_event: Dictionary = _make_versioned_event()
	max_version_event["schema_version"] = 2147483647
	var max_report: Dictionary = adapter.enqueue_payload({
		"events": [max_version_event],
	})
	var overflow_event: Dictionary = _make_versioned_event()
	overflow_event["schema_version"] = 2147483648

	var overflow_report: Dictionary = adapter.enqueue_payload({
		"events": [overflow_event],
	})

	assert_true(
		GFVariantData.get_option_bool(max_report, "success"),
		"PackedInt32 正上界应仍可进入版本化 Outbox。"
	)
	assert_false(
		GFVariantData.get_option_bool(overflow_report, "success"),
		"超出 PackedInt32 的 schema_version 必须拒绝。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(overflow_report, "reason"),
		&"invalid_payload",
		"版本越界应归一为非法 payload。"
	)


func test_versioned_analytics_clears_only_after_durable_handoff() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.config.batch_size = 1
	analytics.transport_callback = Callable(adapter, "enqueue_payload")
	_analytics_instances.append(analytics)
	var register_report: Dictionary = analytics.schema_registry.register_schema(
		_make_event_schema()
	)

	var track_report: Dictionary = analytics.track_versioned(&"opened", 1, { "index": 1 })

	assert_true(GFVariantData.get_option_bool(register_report, "ok"), "测试 Schema 应注册成功。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "合法版本化事件应被 Analytics 接受。")
	assert_eq(analytics.get_queue_size(), 0, "可靠交接成功后 Analytics 才能清除事件。")
	assert_eq(outbox.get_queue_size(), 1, "可靠交接后专用 Outbox 应拥有批次。")
	assert_true(
		adapter.handles_request(outbox.get_pending_requests()[0]),
		"Outbox 中的版本化事件批次应通过 Adapter 校验。"
	)


func test_invalid_client_id_is_rejected_before_adapter_handoff() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox(_PRIMARY_PATH)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.config.batch_size = 1
	analytics.transport_callback = Callable(adapter, "enqueue_payload")
	_analytics_instances.append(analytics)
	var original_client_id: String = analytics.get_client_id()
	var register_report: Dictionary = analytics.schema_registry.register_schema(
		_make_event_schema()
	)

	analytics.identify("client\u0001hidden")
	var track_report: Dictionary = analytics.track_versioned(&"opened", 1, { "index": 1 })

	assert_true(GFVariantData.get_option_bool(register_report, "ok"), "测试 Schema 应注册成功。")
	assert_eq(analytics.get_client_id(), original_client_id, "非法 client_id 应在生产端被拒绝。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "保留的安全 client_id 应继续允许事件交接。")
	assert_eq(analytics.get_queue_size(), 0, "Adapter 不应永久拒绝生产端接受的事件。")
	assert_eq(outbox.get_queue_size(), 1, "安全事件应完成耐久交接。")
	assert_push_warning("[GFAnalyticsUtility] client_id must contain 1..4096 characters without C0/DEL controls.")


func test_versioned_analytics_requeues_when_durable_handoff_fails() -> void:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.auto_load_on_init = false
	outbox.storage_path = "res://analytics_outbox_must_not_write.json"
	outbox.init()
	_outboxes.append(outbox)
	var adapter: GFAnalyticsOutboxAdapter = GFAnalyticsOutboxAdapter.new().configure(outbox)
	var analytics: GFAnalyticsUtility = GFAnalyticsUtility.new()
	analytics.init()
	analytics.config.auto_capture_context = false
	analytics.config.flush_interval_seconds = 0.0
	analytics.config.batch_size = 1
	analytics.transport_callback = Callable(adapter, "enqueue_payload")
	_analytics_instances.append(analytics)
	var register_report: Dictionary = analytics.schema_registry.register_schema(
		_make_event_schema()
	)

	var track_report: Dictionary = analytics.track_versioned(&"opened", 1, { "index": 1 })

	assert_true(GFVariantData.get_option_bool(register_report, "ok"), "测试 Schema 应注册成功。")
	assert_true(GFVariantData.get_option_bool(track_report, "accepted"), "事件进入 Analytics 队列本身应成功。")
	assert_eq(analytics.get_queue_size(), 1, "持久交接失败时原事件必须回灌。")
	assert_eq(outbox.get_queue_size(), 0, "持久化失败回滚后 Outbox 不得残留重复批次。")


# --- 私有/辅助方法 ---

func _make_outbox(path: String) -> GFRequestOutboxUtility:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.storage_path = path
	outbox.auto_load_on_init = false
	outbox.auto_persist = true
	outbox.init()
	_outboxes.append(outbox)
	return outbox


func _make_versioned_event() -> Dictionary:
	return {
		"event": "opened",
		"event_id": GFUuid.generate_v7(),
		"schema_version": 1,
		"client_id": "client",
		"session_id": "session",
		"timestamp": "2026-07-24T00:00:00Z",
		"properties": { "index": 1 },
	}


func _make_event_schema() -> GFAnalyticsEventSchema:
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


func _remove_outbox_files(path: String) -> void:
	_remove_file_if_exists(path)
	_remove_file_if_exists(path + ".tmp")
	_remove_file_if_exists(path + ".bak")


func _remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var remove_error: Error = DirAccess.remove_absolute(path)
	assert_eq(remove_error, OK, "测试临时文件应可删除。")
