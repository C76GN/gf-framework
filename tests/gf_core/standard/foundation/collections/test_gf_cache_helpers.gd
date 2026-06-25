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
	var signature: GFQuerySignature = GFQuerySignature.from_dictionary({
		"none": PackedStringArray(["blocked"]),
		"all": PackedStringArray(["ready", "actor"]),
	})
	var data: Dictionary = signature.to_dictionary()
	var all_values: PackedStringArray = GFVariantData.get_option_packed_string_array(data, "all")

	assert_true(data.has("all"), "导出字典应包含 all 域。")
	assert_eq(all_values.size(), 2, "all 域应包含两个规范化值。")
	assert_true(signature.has_domain(&"none"), "签名应能查询域是否存在。")


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
	assert_eq(GFVariantData.get_option_int(reasons, "lru_capacity"), 1)
	assert_eq(GFVariantData.get_option_int(reasons, "clear"), 3)

	diagnostics.reset()
	assert_eq(GFVariantData.get_option_int(diagnostics.get_debug_snapshot(), "hit_count"), 0, "reset 后统计应清零。")
