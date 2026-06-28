# Tile 元数据层

`GFTileMetadataLayer` 在 `GFTileMapCache` 的格子字典基础上提供更直接的元数据读写、批量绘制、字段擦除、按值查询和可选 schema。

它适合支撑编辑器画刷、运行时标记、导出预处理或调试覆盖层，但仍只保存 `Vector2i -> Dictionary`，不解释字段语义。

```gdscript
var metadata := GFTileMetadataLayer.new()
metadata.set_schema_entry(&"cost", {
	"type": TYPE_INT,
	"default": 1,
})
metadata.paint_cells([Vector2i(1, 1), Vector2i(2, 1)], &"blocked", true)
metadata.merge_cell_data(Vector2i(3, 1), {
	"cost": 5,
	"tag": "road",
})

for cell in metadata.get_cells_with_value(&"blocked", true):
	# 项目层自行决定 blocked 影响寻路、渲染还是编辑器显示。
	pass
```

`schema` 只是给项目或编辑器 UI 使用的元数据字典。GF 不内置字段类型校验、TileSet 写回或业务规则。需要和基础缓存交换数据时，可用 `to_tile_map_cache()` / `from_tile_map_cache()`。

## 编辑器工具辅助

`GFTileMetadataPaintTool` 提供通用 paint patch、UndoRedo 兼容写入和 overlay 分段数据。项目或编辑器插件可以用它实现画刷、拖拽涂抹、擦除和格子覆盖层，但仍由项目决定字段含义与具体 UI。

```gdscript
var patch := GFTileMetadataPaintTool.make_paint_patch(
	metadata,
	[Vector2i(1, 1), Vector2i(2, 1)],
	&"blocked",
	true
)
GFTileMetadataPaintTool.apply_paint_patch(metadata, patch)
```

`get_cell_overlay_segments()` 会根据 `schema` 中的 `color`、`editor_color` 或 `paint_color` 生成分段颜色，方便工具层绘制多字段格子提示。它只输出数据，不直接绘制到 SceneTree 或 TileMap。
