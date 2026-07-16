# 2D 网格变换

`GFGridTransform2D` 提供矩形局部空间中的 8 种离散变换：不变、90/180/270 度旋转、水平/垂直镜像和两条对角线翻转。它只处理 `Vector2i` / `Vector2` 坐标，不读取 TileMap，也不写回任何节点。

## 典型用途

- 把格子画刷、房间蓝图、棋盘片段或建造模板旋转后落到目标起点。
- 把 marker、polygon、路径点等连续坐标和格子模板保持同一套变换。
- 在项目自己的 TileMap、GridMap、存档或编辑器工具中复用稳定坐标映射。

## 格子变换

```gdscript
var source_rect := Rect2i(Vector2i(10, 20), Vector2i(3, 2))
var target_origin := Vector2i(100, 200)

var target_cell := GFGridTransform2D.transform_cell(
	Vector2i(10, 20),
	source_rect,
	GFGridTransform2D.Transform.ROTATE_90,
	target_origin
)
```

`transform_local_cell()` 处理局部格坐标，适合已经把模板坐标归一到 `0..size-1` 的场景。`transform_cell()` 会先减去 `source_rect.position`，再叠加 `target_origin`。`get_transformed_size()` 可用于旋转非方形模板后计算新的包围尺寸。

## 方向变换

```gdscript
var rotated_direction := GFGridTransform2D.transform_cardinal_direction(
	Vector2i.RIGHT,
	GFGridTransform2D.Transform.ROTATE_90
)
```

`transform_cardinal_direction()` 用同一套离散变换处理 `Vector2i.RIGHT`、`LEFT`、`DOWN`、`UP`。这适合画刷朝向、模板出入口、WFC 邻接方向或格子移动规则。无效方向或无效变换会返回 `Vector2i.ZERO`，调用方可以把它当作非方向哨兵处理。

## 连续坐标

```gdscript
var marker := GFGridTransform2D.transform_local_point(
	Vector2(0.25, 0.5),
	Vector2(3.0, 2.0),
	GFGridTransform2D.Transform.MIRROR_X
)
```

连续坐标使用完整矩形尺寸，而不是格子最大索引，因此适合 marker、polygon 顶点、房间锚点和编辑器辅助线。格子坐标和连续坐标应按各自入口处理，避免把单元格中心、边界点和离散索引混在一起。

## 使用边界

`GFGridTransform2D` 不决定模板来源、渲染层、tile swap、碰撞层、房间规则或旋转后的业务含义。项目层负责把返回坐标写入自己的数据结构，并决定无效尺寸、越界格子或重叠冲突如何处理。
