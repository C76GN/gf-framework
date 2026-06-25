# TileMap 缓存

`GFTileMapCache` 是通用格子数据快照与差分缓存，适合把 `TileMapLayer` 当前格子信息采集成纯字典，也可以完全由项目手动写入。

它不规定字段语义，因此可用于自动铺砖预览、地图差分刷新、编辑器工具或存档片段。

```gdscript
var previous := GFTileMapCache.new()
previous.update_from_tile_map(tile_map_layer)

# 项目层修改地图后再次采集。
var current := GFTileMapCache.new()
current.update_from_tile_map(tile_map_layer)

for cell in current.diff_cells(previous, &"source_id"):
	refresh_cell_visual(cell)

var saved := current.to_dict()
```

缓存输出仍是普通数据。字段如何对应地形、渲染刷新、碰撞、寻路或存档，由项目层决定。

## 区域片段与写回

`extract_region(region, normalize_origin)` 可以从缓存中切出一个矩形片段；默认会把片段坐标归一到 `(0, 0)` 开始，便于保存模板或复制到其他位置。`translated(offset)` 会返回平移后的新缓存；`get_used_rect()` 可读取当前缓存占用范围。

```gdscript
var room_fragment := current.extract_region(Rect2i(Vector2i(8, 8), Vector2i(6, 5)))
var pasted := room_fragment.translated(Vector2i(32, 12))
```

当缓存记录来自 `update_from_tile_map()` 或手动写入了 Godot TileMap 字段时，可以用 `apply_to_tile_map(layer, origin, options)` 写回 `TileMapLayer`：

```gdscript
var report := pasted.apply_to_tile_map(%GroundLayer, Vector2i.ZERO, {
	"overwrite": false,
	"erase_empty": true,
})

if not report["ok"]:
	push_warning(report["error"])
```

`overwrite = false` 时，目标层已有 tile 的格子会被跳过；`erase_empty = true` 时，没有可写 tile 字段的记录会擦除目标格子。返回 report 会列出 applied、skipped、erased 和 failed 计数，方便编辑器工具或导入流程给出预览。

这些能力只处理坐标和 tile 源数据，不决定自动铺砖规则、TileSet 选择、区块生命周期或存档格式。
