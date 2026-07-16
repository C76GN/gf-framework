# 2D Delaunay 与 Voronoi 图

`GFVoronoi2D` 提供纯数据层的二维点集计算：从 `PackedVector2Array` 生成 Delaunay 三角剖分，再按三角形外心生成 Voronoi 顶点与 cell。它不创建节点、Mesh、材质、地形、碰撞或编辑器交互，也不解释点代表城市、房间、区域、资源点还是采样点。

## 适用场景

- 需要在项目层生成邻接关系、区域 cell、采样分区或调试可视化数据。
- 需要把算法结果交给自己的渲染、地图、编辑器工具或内容管线。
- 输入点规模中等，适合在加载、生成或工具阶段用纯 GDScript 计算。

不适合用它直接承担大型实时几何处理、有限边界裁剪、地形网格生成、运行时物理碰撞或平台原生加速。这些属于项目策略、渲染管线或专门插件边界。

## 基本用法

```gdscript
var points := PackedVector2Array([
	Vector2(-1.0, -1.0),
	Vector2(1.0, -1.0),
	Vector2(1.0, 1.0),
	Vector2(-1.0, 1.0),
	Vector2.ZERO,
])

var diagram := GFVoronoi2D.build_voronoi(points)
if diagram["ok"]:
	for cell: Dictionary in diagram["cells"]:
		var site: Vector2 = cell["point"]
		var polygon: PackedVector2Array = cell["polygon"]
		var is_open: bool = cell["is_open"]
```

`is_open` 表示该点位于输入点集凸包上，对应 Voronoi cell 理论上向外无限延伸。GF 不会替项目裁剪到矩形、地图边界或导航区域；需要有限多边形时，应在项目层用自己的边界规则裁剪 `polygon`。

## 返回结构

`build_delaunay()` 返回：

- `ok` / `error`：输入是否成功处理。
- `input_point_count`、`point_count`、`duplicate_count`：原始输入数量、去重后数量和按 `epsilon` 合并的重复数量。
- `points`：去重并排序后的点集，后续索引都指向这个数组。
- `triangles`：每项是 3 个点索引的 `PackedInt32Array`。
- `edges`：每项是 2 个点索引的 `PackedInt32Array`。

`build_voronoi()` 在上述字段外追加：

- `vertices`：Delaunay 三角形外心生成的 Voronoi 顶点。
- `cells`：每个点对应一个字典，包含 `point_index`、`point`、`vertex_indices`、`polygon` 和 `is_open`。

需要在 Delaunay / Voronoi 结果上继续派生邻接、边界、点到三角形或边到三角形索引时，可以把结果交给 `GFDualMeshTopology2D`。它只返回拓扑字典，不生成地图、河流、生态群系、Tile 或渲染数据。

## 选项

两个入口都支持相同的 `options`：

- `epsilon`：点去重、退化三角形和外接圆判断的浮点容差，默认 `GFVoronoi2D.DEFAULT_EPSILON`。
- `max_points`：最大输入点数，默认 `GFVoronoi2D.DEFAULT_MAX_POINTS`。超过限制时返回 `ok == false`，避免误把大批实时数据交给 O(n²) 纯 GDScript 计算。

## 与其他模块的关系

- `GFGraphMath` 可消费 Delaunay `edges`，把几何邻接转成项目层路径图。
- `GFDualMeshTopology2D` 可消费 Delaunay 或 Voronoi 结果，生成双图拓扑和凸包边界信息。
- `GFGraphLayoutUtility` 关注编辑器图节点布局；`GFVoronoi2D` 关注平面点集几何关系，二者不共享业务语义。
- 地形、房间、资源分布、势力范围和可视化样式应留在项目或扩展侧，不写入 `GFVoronoi2D`。
