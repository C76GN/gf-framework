# 2D 矩形打包

`GFRectPacking2D` 用于把一组矩形尺寸放进固定容器，或求解能容纳它们的正方形容器。它适合图集规划、离线资源生成、UI 小图块排布、调试缩略图布局等场景；框架只返回 `Rect2i` 坐标，不创建 `Texture`、`Material`、`Node` 或图集资源。

```gdscript
var result := GFRectPacking2D.pack_square([
	Vector2i(64, 64),
	Vector2i(128, 32),
	Vector2i(48, 80),
], {
	"padding": 2,
	"allow_rotate": true,
	"power_of_two": true,
})

if result["ok"]:
	var atlas_size: Vector2i = result["container_size"]
	var rects: Array = result["placements"]
	var uv_rects := GFRectPacking2D.normalize_placements(rects, atlas_size)
```

## 固定容器

`pack_fixed(rect_sizes, container_size, options)` 会按 MaxRects 风格拆分空闲矩形，并返回与输入顺序一致的 `placements`。容器不足时，能放下的矩形仍会尽量放置，放不下或尺寸无效的输入索引会进入 `unplaced_indices`。

常用 `options`：

- `padding`：每个矩形四周保留的像素边距。
- `allow_rotate`：允许交换宽高来提高打包成功率。
- `sort`：默认开启，按尺寸降序优化放置顺序；关闭后按输入顺序尝试。
- `max_rects`：最大输入矩形数量，默认 `GFRectPacking2D.DEFAULT_MAX_RECTS`。超过限制时返回 `ok == false`，避免误把实时大批量数据交给纯 GDScript 打包算法。

## 自动正方形

`pack_square(rect_sizes, options)` 会从总面积和最大边长估算下界，再查找可容纳全部矩形的正方形容器。`power_of_two` 为 true 时只返回 2 的幂边长，适合贴图图集；`max_size` 大于 0 时限制最大边长；`max_rects` 会在求解前先限制输入数量。

返回字典包含：

- `ok`：是否全部放置。
- `error`：失败原因；普通容器不足时为空，输入数量超限等保护性失败会写入原因。
- `container_size`：容器尺寸。
- `placements`：与输入顺序一致的 `Rect2i` 数组。
- `rotated`：每个矩形是否交换宽高。
- `unplaced_indices`：未放置输入索引。
- `placed_count`、`used_area`、`occupancy`：基础统计信息。

## 使用边界

`GFRectPacking2D` 不读取文件、不创建图集、不处理像素复制、不管理资源导入，也不规定矩形代表贴图、UI 控件还是调试缩略图。需要生成实际图集时，应由项目层或上层工具根据 `placements` 执行图片拷贝、资源保存和材质绑定。
