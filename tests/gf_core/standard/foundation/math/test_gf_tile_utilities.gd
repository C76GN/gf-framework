## 测试 TileMap 相关的通用规则与缓存基础件。
extends GutTest


func test_tile_rule_set_resolves_registered_rule() -> void:
	var rules: GFTileRuleSet = GFTileRuleSet.new()
	rules.default_result = "empty"

	rules.register_rule([1, 2, 3], "tile_a")

	assert_true(rules.has_rule([1, 2, 3]), "注册后的邻域规则应可查询。")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 2, 3])), "tile_a", "邻域值完全匹配时应返回注册结果。")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 2, 4])), "empty", "没有匹配规则时应返回默认结果。")


func test_tile_rule_set_falls_back_per_neighbor() -> void:
	var rules: GFTileRuleSet = GFTileRuleSet.new()
	rules.fallback_neighbor_value = 0
	rules.default_result = "empty"
	rules.register_rule([1, 0, 1], "edge")

	assert_eq(GFVariantData.to_text(rules.resolve([1, 9, 1])), "edge", "单个邻域值缺失时应尝试使用 fallback 值匹配。")


func test_tile_rule_set_allows_results_as_neighbor_value() -> void:
	var rules: GFTileRuleSet = GFTileRuleSet.new()
	rules.default_result = "empty"

	rules.register_rule([1, "results", 2], "safe")

	assert_true(rules.has_rule([1, "results", 2]), "邻域值不应和内部结果字段冲突。")
	assert_eq(GFVariantData.to_text(rules.resolve([1, "results", 2])), "safe", "使用 results 作为普通邻域值也应可解析。")


func test_tile_rule_set_weighted_result_uses_fixed_rng_golden_sequence() -> void:
	var rules: GFTileRuleSet = GFTileRuleSet.new()
	rules.deterministic_seed = 11
	rules.register_rule([1, 1, 1, 1], "grass", 1.0)
	rules.register_rule([1, 1, 1, 1], "flower", 2.0)
	rules.register_rule([1, 1, 1, 1], "stone", 3.0)

	assert_eq(GFVariantData.to_text(rules.resolve([1, 1, 1, 1], Vector2i.ZERO)), "stone")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 1, 1, 1], Vector2i(1, 0))), "stone")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 1, 1, 1], Vector2i(4, 8))), "flower")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 1, 1, 1], Vector2i(-2, 5))), "flower")
	assert_eq(GFVariantData.to_text(rules.resolve([1, 1, 1, 1], Vector2i(4, 8), 99)), "flower")


func test_tile_map_cache_diff_can_compare_full_record_or_single_key() -> void:
	var previous: GFTileMapCache = GFTileMapCache.new()
	var current: GFTileMapCache = GFTileMapCache.new()
	previous.set_cell_data(Vector2i(0, 0), { "terrain": 1, "variant": "a" })
	current.set_cell_data(Vector2i(0, 0), { "terrain": 1, "variant": "b" })
	current.set_cell_data(Vector2i(1, 0), { "terrain": 2, "variant": "c" })

	var full_diff: Array[Vector2i] = current.diff_cells(previous)
	var terrain_diff: Array[Vector2i] = current.diff_cells(previous, &"terrain")

	assert_true(full_diff.has(Vector2i(0, 0)), "完整字典比较应识别字段变化。")
	assert_true(full_diff.has(Vector2i(1, 0)), "完整字典比较应识别新增格子。")
	assert_false(terrain_diff.has(Vector2i(0, 0)), "按指定字段比较时无关字段变化不应算差异。")
	assert_true(terrain_diff.has(Vector2i(1, 0)), "按指定字段比较仍应识别新增格子。")


func test_tile_map_cache_roundtrips_serialized_cell_keys() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	cache.set_cell_data(Vector2i(-2, 5), { "terrain": 3 })

	var restored: GFTileMapCache = GFTileMapCache.new()
	restored.from_dict(cache.to_dict())

	assert_true(restored.has_cell(Vector2i(-2, 5)), "序列化恢复后应保留格坐标。")
	assert_eq(GFVariantData.to_int(restored.get_value(Vector2i(-2, 5), &"terrain")), 3, "序列化恢复后应保留格子字段。")


func test_tile_map_cache_extracts_translates_and_reports_bounds() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	cache.set_cell_data(Vector2i(4, 5), { "source_id": 1 })
	cache.set_cell_data(Vector2i(5, 5), { "source_id": 2 })
	cache.set_cell_data(Vector2i(9, 9), { "source_id": 3 })

	var region: GFTileMapCache = cache.extract_region(Rect2i(Vector2i(4, 5), Vector2i(2, 1)))
	var moved: GFTileMapCache = region.translated(Vector2i(10, -1))

	assert_true(region.has_cell(Vector2i.ZERO), "归一区域应把左上角映射到原点。")
	assert_true(region.has_cell(Vector2i(1, 0)), "区域内第二格应保留相对坐标。")
	assert_false(region.has_cell(Vector2i(9, 9)), "区域外格子不应进入片段。")
	assert_true(moved.has_cell(Vector2i(10, -1)), "translated 应返回偏移后的缓存副本。")
	assert_eq(cache.get_used_rect(), Rect2i(Vector2i(4, 5), Vector2i(6, 5)), "覆盖区域应包含全部缓存格子。")


func test_tile_map_cache_applies_to_tile_map_layer_with_offset_and_overwrite_policy() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	cache.set_cell_data(Vector2i.ZERO, {
		"source_id": 1,
		"atlas_coords": Vector2i(2, 3),
		"alternative_tile": 0,
	})
	cache.set_cell_data(Vector2i(1, 0), { "source_id": -1 })

	var layer: TileMapLayer = TileMapLayer.new()
	layer.set_cell(Vector2i(10, 10), 7, Vector2i(0, 0), 0)

	var skipped_report: Dictionary = cache.apply_to_tile_map(layer, Vector2i(10, 10), { "overwrite": false })
	var applied_report: Dictionary = cache.apply_to_tile_map(layer, Vector2i(20, 10))

	assert_eq(GFVariantData.get_option_int(skipped_report, "skipped_count"), 1, "overwrite=false 时已有格子应跳过。")
	assert_eq(layer.get_cell_source_id(Vector2i(10, 10)), 7, "跳过时原格子不应被覆盖。")
	assert_eq(GFVariantData.get_option_int(applied_report, "applied_count"), 1, "空目标应写入缓存格子。")
	assert_eq(layer.get_cell_source_id(Vector2i(20, 10)), 1, "写回后目标格子 source_id 应匹配缓存。")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(20, 10)), Vector2i(2, 3), "写回后 atlas 坐标应匹配缓存。")
	assert_eq(GFVariantData.get_option_int(applied_report, "erased_count"), 1, "source_id < 0 的记录应按 erase_empty 策略清理目标格。")
