extends GutTest


func test_region_map_2d_copies_default_and_snapshot_values() -> void:
	var region_map: GFRegionMap2D = GFRegionMap2D.new()
	var fallback: Dictionary = { "tags": ["fallback"] }
	var payload: Dictionary = { "tags": ["stored"] }

	region_map.set_cell(Vector2i.ZERO, payload)
	var missing_value: Dictionary = GFVariantData.as_dictionary(region_map.get_cell(Vector2i(10, 10), fallback))
	var raw_missing_tags: Variant = missing_value["tags"]
	var missing_tags: Array = raw_missing_tags if raw_missing_tags is Array else []
	missing_tags.append("changed")
	var snapshot: Dictionary = region_map.get_region_snapshot(Vector2i.ZERO)
	var stored_value: Dictionary = GFVariantData.as_dictionary(snapshot[Vector2i.ZERO])
	var raw_stored_tags: Variant = stored_value["tags"]
	var stored_tags: Array = raw_stored_tags if raw_stored_tags is Array else []
	stored_tags.append("changed")

	assert_eq(fallback, { "tags": ["fallback"] }, "缺失默认值应按 duplicate_values 隔离。")
	assert_eq(GFVariantData.as_dictionary(region_map.get_cell(Vector2i.ZERO)), { "tags": ["stored"] }, "区域快照默认应深拷贝集合值。")


func test_region_map_2d_clear_marks_removed_regions_dirty() -> void:
	var region_map: GFRegionMap2D = GFRegionMap2D.new()
	region_map.region_size = Vector2i(4, 4)
	region_map.set_cell(Vector2i.ZERO, "a")
	region_map.set_cell(Vector2i(5, 0), "b")
	region_map.clear_dirty()

	region_map.clear()

	assert_eq(region_map.get_region_keys().size(), 0)
	assert_true(region_map.get_dirty_region_keys().has(Vector2i.ZERO), "清空已有区域应留下删除脏标记。")
	assert_true(region_map.get_dirty_region_keys().has(Vector2i(1, 0)), "清空多个已有区域应分别标脏。")


func test_region_map_2d_reindexes_cells_when_region_size_changes() -> void:
	var region_map: GFRegionMap2D = GFRegionMap2D.new()
	region_map.region_size = Vector2i(4, 4)
	region_map.set_cell(Vector2i.ZERO, "a")
	region_map.set_cell(Vector2i(5, 0), "b")
	region_map.clear_dirty()

	region_map.region_size = Vector2i(8, 8)

	assert_true(region_map.has_cell(Vector2i.ZERO), "调整 region_size 不应丢失已有格子。")
	assert_eq(GFVariantData.to_text(region_map.get_cell(Vector2i(5, 0))), "b")
	assert_eq(region_map.get_region_keys(), [Vector2i.ZERO], "已有格子应按新的 region_size 重新索引。")
	assert_true(region_map.get_dirty_region_keys().has(Vector2i(1, 0)), "旧区域删除也应被标脏。")


func test_region_map_2d_clamps_region_size_before_indexing() -> void:
	var region_map: GFRegionMap2D = GFRegionMap2D.new()

	region_map.region_size = Vector2i(0, -5)
	region_map.set_cell(Vector2i(2, 3), "a")

	assert_eq(region_map.region_size, Vector2i.ONE)
	assert_eq(region_map.get_region_key_for_cell(Vector2i(2, 3)), Vector2i(2, 3))
