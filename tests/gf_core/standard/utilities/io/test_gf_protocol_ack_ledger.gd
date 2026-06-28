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
	assert_true(GFVariantData.to_bool(ledger.call("register_packet", "packet")), "非空文本 ID 应允许。")
	assert_false(GFVariantData.to_bool(ledger.call("register_packet", "packet")), "重复 ID 应被拒绝。")
