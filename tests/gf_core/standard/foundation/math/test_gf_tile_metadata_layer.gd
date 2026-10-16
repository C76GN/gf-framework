## 测试 GFTileMetadataLayer 的通用格子元数据能力。
extends GutTest


func test_tile_metadata_layer_paints_queries_and_erases_values() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]

	assert_eq(
		layer.paint_cells(
			cells,
			&"blocked",
			true
		),
		2,
		"批量绘制应返回写入数量。"
	)
	assert_true(
		layer.has_cell_key(
			Vector2i(0, 0),
			&"blocked"
		),
		"绘制后格子字段应存在。"
	)
	assert_true(
		GFVariantData.to_bool(
			layer.get_cell_value(
				Vector2i(1, 0),
				&"blocked"
			)
		),
		"字段值应可读取。"
	)
	assert_eq(
		layer.get_cells_with_value(&"blocked", true).size(),
		2,
		"应能按字段值查询格子。"
	)
	assert_eq(
		layer.erase_cells_key(cells, &"blocked"),
		2,
		"批量擦除应返回移除数量。"
	)
	assert_false(
		layer.has_cell(Vector2i(0, 0)),
		"擦除最后字段后应移除空格子。"
	)


func test_tile_metadata_layer_merges_schema_and_converts_cache() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	layer.set_schema_entry(
		&"cost",
		{ "type": TYPE_INT, "default": 1, }
	)
	layer.merge_cell_data(
		Vector2i(2, 3),
		{ "cost": 5, "tag": "road", }
	)
	var cache: GFTileMapCache = layer.to_tile_map_cache()
	var restored: GFTileMetadataLayer = GFTileMetadataLayer.new()
	restored.from_tile_map_cache(cache)

	assert_eq(
		GFVariantData.get_option_int(
			layer.get_schema_entry(&"cost"),
			"default"
		),
		1,
		"schema 应以副本形式保存。"
	)
	assert_eq(
		GFVariantData.to_int(
			restored.get_cell_value(
				Vector2i(2, 3),
				&"cost"
			)
		),
		5,
		"转换为缓存再恢复应保留元数据。"
	)
	assert_eq(
		GFVariantData.to_text(
			restored.get_cell_value(
				Vector2i(2, 3),
				&"tag"
			)
		),
		"road",
		"恢复后应保留所有字段。"
	)
