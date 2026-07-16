extends GutTest


func test_tile_map_cache_full_update_removes_stale_cells() -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	var cache: GFTileMapCache = GFTileMapCache.new()
	cache.set_cell_data(Vector2i.ZERO, { "source_id": 1 })

	cache.update_from_tile_map(layer)

	assert_false(cache.has_cell(Vector2i.ZERO), "target_cells 为空时应把 TileMapLayer 当前 used cells 作为权威快照。")
	layer.free()


func test_tile_map_cache_get_value_copies_stored_and_default_values() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	var fallback: Dictionary = { "tags": ["fallback"] }
	cache.set_cell_data(Vector2i.ZERO, {
		"payload": { "tags": ["stored"] },
	})

	var stored_value: Dictionary = GFVariantData.as_dictionary(cache.get_value(Vector2i.ZERO, &"payload"))
	var raw_stored_tags: Variant = stored_value["tags"]
	var stored_tags: Array = raw_stored_tags if raw_stored_tags is Array else []
	stored_tags.append("changed")
	var default_value: Dictionary = GFVariantData.as_dictionary(cache.get_value(Vector2i.ONE, &"payload", fallback))
	var raw_default_tags: Variant = default_value["tags"]
	var default_tags: Array = raw_default_tags if raw_default_tags is Array else []
	default_tags.append("changed")

	assert_eq(GFVariantData.as_dictionary(cache.get_value(Vector2i.ZERO, &"payload")), { "tags": ["stored"] }, "字段读取应隔离缓存内部集合。")
	assert_eq(fallback, { "tags": ["fallback"] }, "字段缺失默认值也应返回副本。")


func test_tile_map_cache_from_dict_preserves_empty_cell_records() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()

	cache.from_dict({ "3,4": {} })

	assert_true(cache.has_cell(Vector2i(3, 4)), "空字典记录也代表一个明确存在的缓存格子。")
	assert_eq(cache.get_cell_data(Vector2i(3, 4)), {}, "空字典记录应原样恢复。")


func test_tile_map_cache_from_dict_accepts_extreme_valid_cell_coordinates() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	var extreme_cell: Vector2i = Vector2i(-2_147_483_648, -2_147_483_648)

	cache.from_dict({ "-2147483648,-2147483648": { "marker": "edge" } })

	assert_true(cache.has_cell(extreme_cell), "极端但合法的 Vector2i 坐标不应被解析失败哨兵误伤。")
	assert_eq(cache.get_cell_data(extreme_cell), { "marker": "edge" }, "极端坐标的记录应正确恢复。")


func test_tile_map_cache_from_dict_ignores_non_dictionary_records() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()

	cache.from_dict({ "1,2": "invalid" })

	assert_false(cache.has_cell(Vector2i(1, 2)), "非 Dictionary 记录不应被静默转换成空格子。")


func test_tile_map_cache_to_dict_roundtrips_through_json() -> void:
	var cache: GFTileMapCache = GFTileMapCache.new()
	cache.set_cell_data(Vector2i(3, 4), {
		"source_id": 2,
		"atlas_coords": Vector2i(7, 8),
		"alternative_tile": 1,
		"tags": PackedStringArray(["a", "b"]),
	})
	var encoded: Dictionary = cache.to_dict()
	var encoded_record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(encoded, "3,4"))

	assert_eq(typeof(GFVariantData.get_option_value(encoded_record, "atlas_coords")), TYPE_DICTIONARY, "Vector2i 字段应被编码为 JSON-safe typed marker。")

	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var restored: GFTileMapCache = GFTileMapCache.new()
	restored.from_dict(parsed)
	var restored_record: Dictionary = restored.get_cell_data(Vector2i(3, 4))

	assert_eq(GFVariantData.get_option_int(restored_record, "source_id"), 2)
	assert_eq(_record_atlas_coords(restored_record), Vector2i(7, 8))
	assert_eq(GFVariantData.get_option_int(restored_record, "alternative_tile"), 1)
	assert_eq(_record_tags(restored_record), PackedStringArray(["a", "b"]))


func _record_atlas_coords(record: Dictionary) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(record, "atlas_coords")
	if value is Vector2i:
		var atlas_coords: Vector2i = value
		return atlas_coords
	return Vector2i.ZERO


func _record_tags(record: Dictionary) -> PackedStringArray:
	var value: Variant = GFVariantData.get_option_value(record, "tags")
	if value is PackedStringArray:
		var tags: PackedStringArray = value
		return tags
	return PackedStringArray()
