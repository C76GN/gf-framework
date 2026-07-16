extends GutTest


func test_region_key_supports_negative_cells() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)

	assert_eq(region_map.get_region_key_for_cell(Vector3i(-1, 0, 0)), Vector3i(-1, 0, 0))
	assert_eq(region_map.get_region_key_for_cell(Vector3i(4, 4, 4)), Vector3i(1, 1, 1))


func test_set_get_dirty_regions_and_clear_specific_region() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)

	region_map.set_cell(Vector3i(1, 1, 1), "a")
	region_map.set_cell(Vector3i(5, 1, 1), "b")

	assert_eq(GFVariantData.to_text(region_map.get_cell(Vector3i(1, 1, 1))), "a")
	assert_eq(GFVariantData.to_text(region_map.get_cell(Vector3i(5, 1, 1))), "b")
	assert_eq(region_map.get_dirty_region_keys().size(), 2)

	region_map.clear_dirty(Vector3i(0, 0, 0))

	assert_false(region_map.get_dirty_region_keys().has(Vector3i(0, 0, 0)))
	assert_true(region_map.get_dirty_region_keys().has(Vector3i(1, 0, 0)))


func test_region_keys_for_cell_bounds_returns_touched_regions() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)

	var keys: Array[Vector3i] = region_map.get_region_keys_for_cell_bounds(Vector3i(4, 0, 4), Vector3i(3, 0, 3))

	assert_eq(keys.size(), 4)
	assert_true(keys.has(Vector3i(0, 0, 0)))
	assert_true(keys.has(Vector3i(0, 0, 1)))
	assert_true(keys.has(Vector3i(1, 0, 0)))
	assert_true(keys.has(Vector3i(1, 0, 1)))


func test_erase_removes_empty_region_and_marks_dirty() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)

	region_map.set_cell(Vector3i(2, 2, 2), 42)
	region_map.clear_dirty()

	assert_true(region_map.erase_cell(Vector3i(2, 2, 2)))
	assert_false(region_map.has_cell(Vector3i(2, 2, 2)))
	assert_eq(region_map.get_region_keys().size(), 0)
	assert_true(region_map.get_dirty_region_keys().has(Vector3i(0, 0, 0)))


func test_duplicate_values_prevents_external_mutation() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	var payload: Dictionary = {"count": 1, "tags": ["a"]}

	region_map.set_cell(Vector3i.ZERO, payload)
	payload["count"] = 2
	_append_tag(payload, "b")

	var stored: Dictionary = GFVariantData.as_dictionary(region_map.get_cell(Vector3i.ZERO))
	stored["count"] = 3
	_append_tag(stored, "c")

	assert_eq(GFVariantData.as_dictionary(region_map.get_cell(Vector3i.ZERO)), {"count": 1, "tags": ["a"]})


func test_clear_marks_removed_regions_dirty() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)
	region_map.set_cell(Vector3i.ZERO, "a")
	region_map.set_cell(Vector3i(5, 0, 0), "b")
	region_map.clear_dirty()

	region_map.clear()

	assert_eq(region_map.get_region_keys().size(), 0)
	assert_true(region_map.get_dirty_region_keys().has(Vector3i.ZERO), "清空已有区域应留下删除脏标记。")
	assert_true(region_map.get_dirty_region_keys().has(Vector3i(1, 0, 0)), "清空多个已有区域应分别标脏。")


func test_region_size_change_reindexes_cells() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()
	region_map.region_size = Vector3i(4, 4, 4)
	region_map.set_cell(Vector3i.ZERO, "a")
	region_map.set_cell(Vector3i(5, 0, 0), "b")
	region_map.clear_dirty()

	region_map.region_size = Vector3i(8, 8, 8)

	assert_true(region_map.has_cell(Vector3i.ZERO), "调整 region_size 不应丢失已有格子。")
	assert_eq(GFVariantData.to_text(region_map.get_cell(Vector3i(5, 0, 0))), "b")
	assert_eq(region_map.get_region_keys(), [Vector3i.ZERO], "已有格子应按新的 region_size 重新索引。")
	assert_true(region_map.get_dirty_region_keys().has(Vector3i(1, 0, 0)), "旧区域删除也应被标脏。")


func test_region_size_is_clamped_before_indexing() -> void:
	var region_map: GFRegionMap3D = GFRegionMap3D.new()

	region_map.region_size = Vector3i(0, -5, 0)
	region_map.set_cell(Vector3i(2, 3, 4), "a")

	assert_eq(region_map.region_size, Vector3i.ONE)
	assert_eq(region_map.get_region_key_for_cell(Vector3i(2, 3, 4)), Vector3i(2, 3, 4))


func _append_tag(data: Dictionary, tag: String) -> void:
	var tags_value: Variant = GFVariantData.get_option_value(data, "tags")
	if tags_value is Array:
		var tags: Array = tags_value
		tags.append(tag)
