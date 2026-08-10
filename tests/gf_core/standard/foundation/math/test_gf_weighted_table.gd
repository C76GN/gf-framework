## 测试 GFWeightedTable 的权重选择、去重选择、复制与字典序列化。
extends GutTest


# --- 测试 ---

func test_pick_value_ignores_non_positive_weights() -> void:
	var table: GFWeightedTable = GFWeightedTable.new()
	table.default_value = "EMPTY"
	var _add_entry_result_10: Variant = table.add_entry("SKIP", 0.0)
	var _add_entry_result_11: Variant = table.add_entry("ONLY", 1.0)

	assert_eq(GFVariantData.to_text(table.pick_value(_make_rng(1))), "ONLY")
	assert_eq(table.get_total_weight(), 1.0)


func test_pick_value_ignores_non_finite_weights() -> void:
	var table: GFWeightedTable = GFWeightedTable.new()
	table.default_value = "EMPTY"
	var _inf_entry: Variant = table.add_entry("INF", INF)
	var _nan_entry: Variant = table.add_entry("NAN", NAN)
	var _valid_entry: Variant = table.add_entry("ONLY", 1.0)

	assert_push_error("[GFWeightedEntry] weight 必须是有限数字，已重置为 0。")
	assert_push_error("[GFWeightedEntry] weight 必须是有限数字，已重置为 0。")
	assert_eq(GFVariantData.to_text(table.pick_value(_make_rng(1))), "ONLY")
	assert_eq(table.get_total_weight(), 1.0)


func test_pick_value_normalizes_only_when_finite_weights_overflow_the_sum() -> void:
	var regular: GFWeightedTable = GFWeightedTable.new()
	var scaled: GFWeightedTable = GFWeightedTable.new()
	var regular_rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(91)
	var scaled_rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(91)
	var regular_values: Array[Variant] = []
	var scaled_values: Array[Variant] = []
	var _regular_a: GFWeightedEntry = regular.add_entry("a", 1.0)
	var _regular_b: GFWeightedEntry = regular.add_entry("b", 2.0)
	var _scaled_a: GFWeightedEntry = scaled.add_entry("a", 8.0e307)
	var _scaled_b: GFWeightedEntry = scaled.add_entry("b", 1.6e308)

	for _index: int in range(32):
		regular_values.append(regular.pick_value(regular_rng))
		scaled_values.append(scaled.pick_value(scaled_rng))

	assert_true(is_inf(scaled.get_total_weight()), "不可表示的真实总权重应显式保留为 INF。")
	assert_eq(scaled_values, regular_values, "共同缩放不得把有限正权重选择退化为 RNG 未定义行为。")


func test_non_finite_weight_serializes_as_safe_zero() -> void:
	var entry: GFWeightedEntry = GFWeightedEntry.new()

	entry.weight = INF
	var data: Dictionary = entry.to_dict()
	var json_text: String = JSON.stringify(data)

	assert_push_error("[GFWeightedEntry] weight 必须是有限数字，已重置为 0。")
	assert_eq(GFVariantData.get_option_float(data, "weight", -1.0), 0.0)
	assert_false(json_text.contains("Infinity"), "权重字典不应把 Infinity 交给 JSON.stringify。")
	assert_false(json_text.contains("NaN"), "权重字典不应把 NaN 交给 JSON.stringify。")


func test_pick_many_is_reproducible_with_seeded_rng() -> void:
	var first: Array = _make_sample_table().pick_many(8, _make_rng(42))
	var second: Array = _make_sample_table().pick_many(8, _make_rng(42))

	assert_eq(first, second, "相同随机种子应产生可复现的权重选择序列。")


func test_pick_many_uses_fixed_rng_when_deterministic_seed_is_set() -> void:
	var table: GFWeightedTable = _make_sample_table()
	table.deterministic_seed = 99

	var values: Array = table.pick_many(8)

	assert_eq(values, ["A", "C", "A", "B", "C", "B", "C", "C"])


func test_pick_value_accepts_explicit_deterministic_random_stream() -> void:
	var table: GFWeightedTable = _make_sample_table()
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(99)

	var first: String = GFVariantData.to_text(table.pick_value(rng))
	var second: String = GFVariantData.to_text(table.pick_value(rng))

	assert_eq([first, second], ["A", "C"], "显式传入 GFDeterministicRandom 时应沿同一随机流推进。")


func test_pick_many_accepts_explicit_deterministic_random_stream() -> void:
	var table: GFWeightedTable = _make_sample_table()
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(99)

	var values: Array = table.pick_many(8, rng)

	assert_eq(values, ["A", "C", "A", "B", "C", "B", "C", "C"])


func test_pick_value_restarts_fixed_rng_fallback_per_call() -> void:
	var table: GFWeightedTable = _make_sample_table()
	table.deterministic_seed = 99

	var first: String = GFVariantData.to_text(table.pick_value())
	var second: String = GFVariantData.to_text(table.pick_value())

	assert_eq(first, "A")
	assert_eq(second, first, "单次 pick 未传入随机源时会按 deterministic_seed 重新创建固定随机源。")


func test_pick_many_without_repeats_returns_unique_entries() -> void:
	var values: Array = _make_sample_table().pick_many(8, _make_rng(7), false)

	assert_eq(values.size(), 3)
	assert_eq(_count_unique(values), 3, "不允许重复时同一条目不应被选择两次。")


func test_serialized_table_roundtrips_entries_and_seed() -> void:
	var table: GFWeightedTable = _make_sample_table()
	table.default_value = "NONE"
	table.deterministic_seed = 99

	var restored: GFWeightedTable = GFWeightedTable.from_dict(table.to_dict())

	assert_eq(GFVariantData.to_text(restored.default_value), "NONE")
	assert_eq(restored.deterministic_seed, 99)
	assert_eq(restored.entries.size(), 3)
	assert_eq(GFVariantData.to_text(restored.entries[1].value), "B")
	assert_eq(restored.entries[1].weight, 2.0)


func test_duplicate_table_can_deep_copy_entries() -> void:
	var table: GFWeightedTable = GFWeightedTable.new()
	var entry: GFWeightedEntry = table.add_entry({"id": "A"}, 1.0, {"tag": "sample"})
	var copied: GFWeightedTable = table.duplicate_table(true)

	var entry_value: Dictionary = GFVariantData.as_dictionary(entry.value)
	var entry_metadata: Dictionary = GFVariantData.as_dictionary(entry.metadata)
	entry_value["id"] = "B"
	entry_metadata["tag"] = "changed"

	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(copied.entries[0].value), "id", ""), "A")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(copied.entries[0].metadata), "tag", ""), "sample")


func test_duplicate_table_can_deep_copy_resource_values() -> void:
	var table: GFWeightedTable = GFWeightedTable.new()
	var default_resource: Resource = Resource.new()
	var entry_resource: Resource = Resource.new()
	table.default_value = default_resource
	var _add_entry_result_64: Variant = table.add_entry(entry_resource, 1.0)

	var copied: GFWeightedTable = table.duplicate_table(true)

	assert_true(_resource_value(copied.default_value) != default_resource, "默认值 Resource 应被深拷贝。")
	assert_true(_resource_value(copied.entries[0].value) != entry_resource, "条目值 Resource 应被深拷贝。")


# --- 私有/辅助方法 ---

func _make_sample_table() -> GFWeightedTable:
	var table: GFWeightedTable = GFWeightedTable.new()
	var _add_entry_result_76: Variant = table.add_entry("A", 1.0)
	var _add_entry_result_77: Variant = table.add_entry("B", 2.0)
	var _add_entry_result_78: Variant = table.add_entry("C", 3.0)
	return table


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _count_unique(values: Array) -> int:
	var lookup: Dictionary = {}
	for value: Variant in values:
		lookup[value] = true
	return lookup.size()


func _resource_value(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null
