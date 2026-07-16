extends GutTest


# --- 常量 ---

const GF_PROTOCOL_ACK_LEDGER_SCRIPT = preload("res://addons/gf/standard/utilities/io/gf_protocol_ack_ledger.gd")


# --- 测试方法 ---

func test_ack_ledger_tracks_ack_failure_and_expiration() -> void:
	var ledger: RefCounted = GF_PROTOCOL_ACK_LEDGER_SCRIPT.new()
	ledger.set("timeout_msec", 100)

	assert_true(GFVariantData.to_bool(ledger.call("register_packet", 1, { "topic": "spawn" }, 1000)), "应能注册待确认条目。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", 2, {}, 1000)), "应能注册第二个待确认条目。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", 3, {}, 1000)), "应能注册第三个待确认条目。")
	assert_true(GFVariantData.to_bool(ledger.call("acknowledge_packet", 1, { "accepted": true }, 1040)), "待确认条目应能标记为 acked。")
	assert_true(GFVariantData.to_bool(ledger.call("fail_packet", 2, "rejected", {}, 1050)), "待确认条目应能标记为 failed。")

	var expiration: Dictionary = GFVariantData.as_dictionary(ledger.call("expire_pending", 1101))
	var acked: Dictionary = GFVariantData.as_dictionary(ledger.call("get_packet", 1))
	var failed: Dictionary = GFVariantData.as_dictionary(ledger.call("get_packet", 2))
	var expired: Dictionary = GFVariantData.as_dictionary(ledger.call("get_packet", 3))
	var state_counts: Dictionary = GFVariantData.get_option_dictionary(expiration, "state_counts")

	assert_eq(GFVariantData.get_option_string_name(acked, "state"), GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_ACKED)
	assert_eq(GFVariantData.get_option_string_name(failed, "state"), GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_FAILED)
	assert_eq(GFVariantData.get_option_string_name(expired, "state"), GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_EXPIRED)
	assert_eq(GFVariantData.get_option_int(expiration, "expired_count"), 1, "过期报告应统计新过期条目。")
	assert_eq(GFVariantData.get_option_int(state_counts, GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_ACKED), 1)
	assert_eq(GFVariantData.get_option_int(state_counts, GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_FAILED), 1)
	assert_eq(GFVariantData.get_option_int(state_counts, GF_PROTOCOL_ACK_LEDGER_SCRIPT.STATE_EXPIRED), 1)


func test_ack_ledger_prunes_terminal_records_before_pending_records() -> void:
	var ledger: RefCounted = GF_PROTOCOL_ACK_LEDGER_SCRIPT.new()
	ledger.set("max_entries", 2)

	assert_true(GFVariantData.to_bool(ledger.call("register_packet", &"old", {}, 1)), "应能注册 old。")
	assert_true(GFVariantData.to_bool(ledger.call("acknowledge_packet", &"old", null, 2)), "old 应能进入终态。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", &"live", {}, 3)), "应能注册 live。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", &"new", {}, 4)), "容量满时应优先清理终态 old。")

	assert_false(GFVariantData.to_bool(ledger.call("has_packet", &"old")), "终态 old 应被容量清理。")
	assert_true(GFVariantData.to_bool(ledger.call("is_pending", &"live")), "pending live 应保留。")
	assert_true(GFVariantData.to_bool(ledger.call("is_pending", &"new")), "pending new 应保留。")
	assert_eq(GFVariantData.as_array(ledger.call("get_pending_ids")), [&"live", &"new"], "pending ID 顺序应稳定。")


func test_ack_ledger_rejects_duplicate_and_empty_text_ids() -> void:
	var ledger: RefCounted = GF_PROTOCOL_ACK_LEDGER_SCRIPT.new()

	assert_false(GFVariantData.to_bool(ledger.call("register_packet", &"")), "空 StringName ID 应被拒绝。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", [])), "可变 Array 不得成为协议身份。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", {})), "可变 Dictionary 不得成为协议身份。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", RefCounted.new())), "进程对象不得成为协议身份。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", 1.5)), "浮点值不得成为协议身份。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", "packet")), "非空文本 ID 应允许。")
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", 7)), "整数 ID 应允许。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", "packet")), "重复 ID 应被拒绝。")


func test_ack_ledger_marks_retry_ready_packets_in_order() -> void:
	var ledger: GFProtocolAckLedger = GFProtocolAckLedger.new()
	ledger.retry_interval_msec = 50
	ledger.max_attempts = 2

	assert_true(ledger.register_packet(&"first", {}, 1000), "应能注册 first。")
	assert_true(ledger.register_packet(&"second", {}, 1000), "应能注册 second。")
	assert_true(ledger.record_packet_attempt(&"first", 1000), "首次发送应记录尝试。")
	assert_true(ledger.record_packet_attempt(&"second", 1010), "第二个包首次发送应记录尝试。")

	assert_eq(ledger.get_retry_ready_ids(1049), [], "未到重试时间前不应进入 ready。")
	assert_eq(ledger.get_retry_ready_ids(1060), [&"first", &"second"], "到期重试 ID 应保持登记顺序。")
	assert_true(ledger.record_packet_attempt(&"first", 1060), "第二次尝试仍应允许。")
	assert_false(ledger.get_retry_ready_ids(1110).has(&"first"), "达到 max_attempts 后不应继续进入 retry-ready。")
	assert_false(ledger.record_packet_attempt(&"first", 1120), "超过 max_attempts 时应拒绝新尝试。")

	var first_packet: Dictionary = ledger.get_packet(&"first")
	assert_eq(ledger.get_attempt_count(&"first"), 2, "尝试计数应保留成功记录次数。")
	assert_eq(GFVariantData.get_option_string_name(first_packet, "state"), GFProtocolAckLedger.STATE_FAILED)
	assert_eq(GFVariantData.get_option_string(first_packet, "error"), "max_attempts_exceeded")


func test_ack_ledger_deduplicates_and_orders_incoming_packets() -> void:
	var ledger: GFProtocolAckLedger = GFProtocolAckLedger.new()
	ledger.incoming_window_size = 2

	var first: Dictionary = ledger.accept_incoming_packet(&"p1", 1, &"state", 1000)
	var duplicate_report: Dictionary = ledger.accept_incoming_packet(&"p1", 1, &"state", 1001)
	var older_sequence: Dictionary = ledger.accept_incoming_packet(&"p0", 0, &"state", 1002)
	var second: Dictionary = ledger.accept_incoming_packet(&"p2", 2, &"state", 1003)
	var third: Dictionary = ledger.accept_incoming_packet(&"p3", 3, &"state", 1004)

	assert_true(GFVariantData.get_option_bool(first, "accepted"), "首个入站包应被接受。")
	assert_true(GFVariantData.get_option_bool(duplicate_report, "duplicate"), "重复 ID 应被识别。")
	assert_true(GFVariantData.get_option_bool(older_sequence, "out_of_order"), "旧 sequence 应被拒绝。")
	assert_true(GFVariantData.get_option_bool(second, "accepted"), "更高 sequence 应被接受。")
	assert_true(GFVariantData.get_option_bool(third, "accepted"), "继续递增的 sequence 应被接受。")
	assert_false(ledger.has_incoming_packet(&"p1"), "超过入站窗口后最旧 ID 应被清理。")
	assert_true(ledger.has_incoming_packet(&"p2"), "窗口内较新 ID 应保留。")
	assert_true(ledger.has_incoming_packet(&"p3"), "窗口内最新 ID 应保留。")
