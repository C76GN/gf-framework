extends GutTest


# --- 测试方法 ---

func test_query_signature_is_domain_separated_and_order_stable() -> void:
	var left: GFQuerySignature = GFQuerySignature.new()
	var _left_all: GFQuerySignature = left.add_values(&"all", ["player", "alive"])
	var _left_none: GFQuerySignature = left.add_values(&"none", ["stunned"])

	var right: GFQuerySignature = GFQuerySignature.new()
	var _right_none: GFQuerySignature = right.add_values(&"none", ["stunned"])
	var _right_all: GFQuerySignature = right.add_values(&"all", ["alive", "player"])

	var flat_collision: GFQuerySignature = GFQuerySignature.new()
	var _flat_any: GFQuerySignature = flat_collision.add_values(&"any", ["alive", "player", "stunned"])

	assert_eq(left.to_text(), right.to_text(), "同一域内值顺序不应影响签名。")
	assert_eq(left.to_hash(), right.to_hash(), "同一查询应得到相同 hash。")
	assert_ne(left.to_text(), flat_collision.to_text(), "不同语义域即使值集合相近也不应合并成同一签名。")


func test_query_signature_exports_sorted_dictionary() -> void:
	var signature: GFQuerySignature = GFQuerySignature.new()
	var _all_values: GFQuerySignature = signature.add_values(&"all", ["ready", "actor"])
	var _none_values: GFQuerySignature = signature.add_values(&"none", ["blocked"])
	var data: Dictionary = signature.to_dictionary()
	var all_values: PackedStringArray = GFVariantData.get_option_packed_string_array(data, "all")

	assert_true(data.has("all"), "导出字典应包含 all 域。")
	assert_eq(all_values.size(), 2, "all 域应包含两个规范化值。")
	assert_true(signature.has_domain(&"none"), "签名应能查询域是否存在。")


func test_query_signature_dictionary_round_trip_keeps_encoded_values() -> void:
	var signature: GFQuerySignature = GFQuerySignature.new()
	var _all_values: GFQuerySignature = signature.add_values(&"all", ["ready", 3, true])
	var data: Dictionary = signature.to_dictionary()

	var restored: GFQuerySignature = GFQuerySignature.from_dictionary(data)

	assert_eq(restored.to_dictionary(), data, "签名字典往返不应二次编码规范化值。")
	assert_eq(restored.to_text(), signature.to_text(), "签名文本应在字典往返后保持稳定。")


func test_query_signature_uses_strict_stable_key_codec() -> void:
	var signature: GFQuerySignature = GFQuerySignature.new()
	var _vector_value: GFQuerySignature = signature.add_value(&"cells", Vector2i(1, 2))
	var _unstable_value: GFQuerySignature = signature.add_value(&"cells", { "id": 1 })
	var values: PackedStringArray = signature.get_domain_values(&"cells")

	assert_eq(values.size(), 1, "不稳定查询值不应进入签名。")
	assert_true(values[0].begins_with("gfv1:"), "签名值应使用统一稳定 key token。")


func test_query_signature_length_prefixes_adversarial_domains() -> void:
	var separated: GFQuerySignature = GFQuerySignature.new()
	var _separated_a: GFQuerySignature = separated.add_value(&"a", "x")
	var _separated_b: GFQuerySignature = separated.add_value(&"b", "y")
	var a_token: String = separated.get_domain_values(&"a")[0]
	var injected_domain: StringName = StringName("a(1):%s|b" % a_token)
	var injected: GFQuerySignature = GFQuerySignature.new()
	var _injected_value: GFQuerySignature = injected.add_value(injected_domain, "y")

	assert_ne(separated.to_text(), injected.to_text(), "domain 中的旧格式分隔符不应伪造另一组签名。")
	assert_true(separated.to_text().begins_with("gfq1:"), "查询签名应使用版本化长度前缀格式。")


func test_cache_diagnostics_tracks_hits_misses_and_reasons() -> void:
	var diagnostics: GFCacheDiagnostics = GFCacheDiagnostics.new()
	diagnostics.cache_id = &"asset"

	diagnostics.record_hit("res://a.tres")
	diagnostics.record_miss("res://b.tres")
	diagnostics.record_write("res://a.tres")
	diagnostics.record_eviction(&"lru_capacity", "res://old.tres")
	diagnostics.record_invalidation(&"clear", "", 3)

	var snapshot: Dictionary = diagnostics.get_debug_snapshot()
	var reasons: Dictionary = GFVariantData.get_option_dictionary(snapshot, "invalidation_reasons")

	assert_eq(GFVariantData.get_option_string_name(snapshot, "cache_id"), &"asset")
	assert_eq(GFVariantData.get_option_int(snapshot, "hit_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "miss_count"), 1)
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "hit_ratio"), 0.5, 0.001)
	assert_eq(GFVariantData.get_option_int(snapshot, "invalidation_count"), 4, "eviction 应同时进入 invalidation 总计。")
	assert_eq(GFVariantData.get_option_int(reasons, "lru_capacity"), 1)
	assert_eq(GFVariantData.get_option_int(reasons, "clear"), 3)

	diagnostics.reset()
	assert_eq(GFVariantData.get_option_int(diagnostics.get_debug_snapshot(), "hit_count"), 0, "reset 后统计应清零。")


func test_cache_diagnostics_records_stable_key_text() -> void:
	var diagnostics: GFCacheDiagnostics = GFCacheDiagnostics.new()

	diagnostics.record_hit(Vector2i(3, 4))
	var snapshot: Dictionary = diagnostics.get_debug_snapshot()
	var last_event: Dictionary = GFVariantData.get_option_dictionary(snapshot, "last_event")

	assert_true(GFVariantData.get_option_string(last_event, "key").begins_with("gfv1:"), "缓存诊断应复用稳定 key token。")


func test_cache_diagnostics_ignores_non_positive_invalidation_amounts() -> void:
	var diagnostics: GFCacheDiagnostics = GFCacheDiagnostics.new()
	diagnostics.record_invalidation(&"empty_scan", null, 0)
	diagnostics.record_invalidation(&"invalid_scan", null, -2)

	var snapshot: Dictionary = diagnostics.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "invalidation_count"), 0, "非正数量不应伪造缓存失效事件。")
	assert_true(GFVariantData.get_option_dictionary(snapshot, "invalidation_reasons").is_empty(), "非正数量不应写入原因统计。")
