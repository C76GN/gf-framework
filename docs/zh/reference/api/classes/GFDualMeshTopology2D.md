# GFDualMeshTopology2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_dual_mesh_topology_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

二维 Delaunay / Voronoi 双图拓扑工具。 从 GFVoronoi2D 的纯数据结果派生点邻接、边到三角形、点到三角形和边界信息。 它不生成地图、Mesh、Tile、河流、生态群系或渲染数据，项目层可在这些拓扑之上解释领域语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`build_from_points`](#member-gfdualmeshtopology2d-methods-build_from_points) | `static func build_from_points(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_from_voronoi`](#member-gfdualmeshtopology2d-methods-build_from_voronoi) | `static func build_from_voronoi(voronoi_result: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_from_delaunay`](#member-gfdualmeshtopology2d-methods-build_from_delaunay) | `static func build_from_delaunay(delaunay_result: Dictionary, _options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_edge_key`](#member-gfdualmeshtopology2d-methods-make_edge_key) | `static func make_edge_key(a: int, b: int) -> String:` |
| 方法 | [`get_point_neighbors`](#member-gfdualmeshtopology2d-methods-get_point_neighbors) | `static func get_point_neighbors(topology: Dictionary, point_index: int) -> PackedInt32Array:` |
| 方法 | [`get_edge_triangles`](#member-gfdualmeshtopology2d-methods-get_edge_triangles) | `static func get_edge_triangles(topology: Dictionary, a: int, b: int) -> PackedInt32Array:` |

## 方法

<a id="member-gfdualmeshtopology2d-methods-build_from_points"></a>

### `build_from_points`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func build_from_points(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
```

从点集构建 Delaunay / Voronoi 拓扑。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 输入点集。 |
| `options` | 可选参数，会传给 GFVoronoi2D.build_voronoi()；另支持 include_cells。 |

返回：拓扑报告。

结构：

- `options`: Dictionary，可包含 GFVoronoi2D options 和 include_cells: bool。
- `return`: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges、hull_points 和可选 cells。

<a id="member-gfdualmeshtopology2d-methods-build_from_voronoi"></a>

### `build_from_voronoi`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func build_from_voronoi(voronoi_result: Dictionary, options: Dictionary = {}) -> Dictionary:
```

从 GFVoronoi2D.build_voronoi() 结果构建双图拓扑。

参数：

| 名称 | 说明 |
|---|---|
| `voronoi_result` | GFVoronoi2D.build_voronoi() 返回的结果字典。 |
| `options` | 可选参数，支持 include_cells。 |

返回：拓扑报告。

结构：

- `voronoi_result`: Dictionary，包含 points、triangles、edges、vertices、cells 等字段。
- `options`: Dictionary，可包含 include_cells: bool。
- `return`: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges、hull_points 和可选 cells。

<a id="member-gfdualmeshtopology2d-methods-build_from_delaunay"></a>

### `build_from_delaunay`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func build_from_delaunay(delaunay_result: Dictionary, _options: Dictionary = {}) -> Dictionary:
```

从 GFVoronoi2D.build_delaunay() 结果构建双图拓扑。

参数：

| 名称 | 说明 |
|---|---|
| `delaunay_result` | GFVoronoi2D.build_delaunay() 返回的结果字典。 |
| `_options` | 保留给未来扩展的选项。 |

返回：拓扑报告。

结构：

- `delaunay_result`: Dictionary，包含 points、triangles 和可选 edges。
- `_options`: Dictionary，当前未使用。
- `return`: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges 和 hull_points。

<a id="member-gfdualmeshtopology2d-methods-make_edge_key"></a>

### `make_edge_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_edge_key(a: int, b: int) -> String:
```

构建稳定边键。

参数：

| 名称 | 说明 |
|---|---|
| `a` | 第一个点索引。 |
| `b` | 第二个点索引。 |

返回：稳定边键。

<a id="member-gfdualmeshtopology2d-methods-get_point_neighbors"></a>

### `get_point_neighbors`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_point_neighbors(topology: Dictionary, point_index: int) -> PackedInt32Array:
```

获取指定点的邻接点索引。

参数：

| 名称 | 说明 |
|---|---|
| `topology` | build_from_* 返回的拓扑报告。 |
| `point_index` | 点索引。 |

返回：邻接点索引。

结构：

- `topology`: Dictionary，build_from_* 返回的拓扑报告。

<a id="member-gfdualmeshtopology2d-methods-get_edge_triangles"></a>

### `get_edge_triangles`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_edge_triangles(topology: Dictionary, a: int, b: int) -> PackedInt32Array:
```

获取指定边关联的三角形索引。

参数：

| 名称 | 说明 |
|---|---|
| `topology` | build_from_* 返回的拓扑报告。 |
| `a` | 第一个点索引。 |
| `b` | 第二个点索引。 |

返回：共享该边的三角形索引。

结构：

- `topology`: Dictionary，build_from_* 返回的拓扑报告。
