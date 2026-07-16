# GFGridCoordinateMath2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_coordinate_math_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

2D 网格坐标、区域和直线查询工具。 只处理网格坐标转换、边界、邻居、区域、chunk 窗口、集合差分、 直线、视线和泛洪查询，不包含路径搜索、地图生成或玩法连接规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`to_json_compatible_report`](#member-gfgridcoordinatemath2d-methods-to_json_compatible_report) | `static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`cell_to_index`](#member-gfgridcoordinatemath2d-methods-cell_to_index) | `static func cell_to_index(cell: Vector2i, width: int) -> int:` |
| 方法 | [`index_to_cell`](#member-gfgridcoordinatemath2d-methods-index_to_cell) | `static func index_to_cell(index: int, width: int) -> Vector2i:` |
| 方法 | [`world_to_chunk_cell`](#member-gfgridcoordinatemath2d-methods-world_to_chunk_cell) | `static func world_to_chunk_cell(world_position: Vector2, chunk_size: Vector2i) -> Vector2i:` |
| 方法 | [`chunk_cell_to_world_origin`](#member-gfgridcoordinatemath2d-methods-chunk_cell_to_world_origin) | `static func chunk_cell_to_world_origin(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:` |
| 方法 | [`chunk_cell_to_world_center`](#member-gfgridcoordinatemath2d-methods-chunk_cell_to_world_center) | `static func chunk_cell_to_world_center(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:` |
| 方法 | [`is_in_bounds`](#member-gfgridcoordinatemath2d-methods-is_in_bounds) | `static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:` |
| 方法 | [`get_neighbors`](#member-gfgridcoordinatemath2d-methods-get_neighbors) | `static func get_neighbors( cell: Vector2i, grid_size: Vector2i, include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_rectangle_cells`](#member-gfgridcoordinatemath2d-methods-get_rectangle_cells) | `static func get_rectangle_cells( from_cell: Vector2i, to_cell: Vector2i, grid_size: Vector2i = Vector2i(-1, -1) ) -> Array[Vector2i]:` |
| 方法 | [`get_range`](#member-gfgridcoordinatemath2d-methods-get_range) | `static func get_range( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_ring`](#member-gfgridcoordinatemath2d-methods-get_ring) | `static func get_ring( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_chunk_window`](#member-gfgridcoordinatemath2d-methods-get_chunk_window) | `static func get_chunk_window( center_chunk: Vector2i, radius: int, shape: StringName = &"circle" ) -> Array[Vector2i]:` |
| 方法 | [`diff_cells`](#member-gfgridcoordinatemath2d-methods-diff_cells) | `static func diff_cells(previous_cells: Array[Vector2i], next_cells: Array[Vector2i]) -> Dictionary:` |
| 方法 | [`get_line`](#member-gfgridcoordinatemath2d-methods-get_line) | `static func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:` |
| 方法 | [`has_line_of_sight`](#member-gfgridcoordinatemath2d-methods-has_line_of_sight) | `static func has_line_of_sight( from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable, include_endpoints: bool = false ) -> bool:` |
| 方法 | [`flood_fill`](#member-gfgridcoordinatemath2d-methods-flood_fill) | `static func flood_fill( grid_size: Vector2i, start: Vector2i, is_match: Callable, include_diagonal: bool = false ) -> Array[Vector2i]:` |

## 方法

<a id="member-gfgridcoordinatemath2d-methods-to_json_compatible_report"></a>

### `to_json_compatible_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将 2D 网格报告转换为 JSON.stringify() 安全的结构。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 2D 网格工具返回的报告或快照字典。 |
| `options` | 报告编码选项，透传给 GFReportValueCodec。 |

返回：JSON 兼容报告。

结构：

- `report`: 2D 网格工具返回的报告或快照字典。
- `options`: GFReportValueCodec 编码选项字典。
- `return`: 可安全交给 JSON.stringify() 的 Dictionary。

<a id="member-gfgridcoordinatemath2d-methods-cell_to_index"></a>

### `cell_to_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func cell_to_index(cell: Vector2i, width: int) -> int:
```

将二维格坐标转换为一维索引。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 二维格坐标。 |
| `width` | 网格宽度。 |

返回：成功时返回一维索引；宽度无效时返回 -1。

<a id="member-gfgridcoordinatemath2d-methods-index_to_cell"></a>

### `index_to_cell`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func index_to_cell(index: int, width: int) -> Vector2i:
```

将一维索引转换为二维格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 一维索引。 |
| `width` | 网格宽度。 |

返回：成功时返回二维格坐标；参数无效时返回 Vector2i(-1, -1)。

<a id="member-gfgridcoordinatemath2d-methods-world_to_chunk_cell"></a>

### `world_to_chunk_cell`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func world_to_chunk_cell(world_position: Vector2, chunk_size: Vector2i) -> Vector2i:
```

将世界坐标转换为二维 chunk 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |
| `chunk_size` | 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2i.ZERO。 |

返回：chunk 坐标。负世界坐标使用 floor 语义，因此 -0.1 会落入 -1 号 chunk。

<a id="member-gfgridcoordinatemath2d-methods-chunk_cell_to_world_origin"></a>

### `chunk_cell_to_world_origin`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func chunk_cell_to_world_origin(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:
```

将二维 chunk 坐标转换为世界原点坐标。

参数：

| 名称 | 说明 |
|---|---|
| `chunk_cell` | chunk 坐标。 |
| `chunk_size` | 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2.ZERO。 |

返回：chunk 左上/局部原点对应的世界坐标。

<a id="member-gfgridcoordinatemath2d-methods-chunk_cell_to_world_center"></a>

### `chunk_cell_to_world_center`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func chunk_cell_to_world_center(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:
```

将二维 chunk 坐标转换为世界中心坐标。

参数：

| 名称 | 说明 |
|---|---|
| `chunk_cell` | chunk 坐标。 |
| `chunk_size` | 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2.ZERO。 |

返回：chunk 中心对应的世界坐标。

<a id="member-gfgridcoordinatemath2d-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
```

判断格坐标是否位于网格范围内。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 二维格坐标。 |
| `grid_size` | 网格尺寸。 |

返回：在范围内返回 true。

<a id="member-gfgridcoordinatemath2d-methods-get_neighbors"></a>

### `get_neighbors`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_neighbors( cell: Vector2i, grid_size: Vector2i, include_diagonal: bool = false ) -> Array[Vector2i]:
```

获取指定格子的邻居。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 中心格子。 |
| `grid_size` | 网格尺寸。 |
| `include_diagonal` | 是否包含四个斜向邻居。 |

返回：位于网格范围内的邻居列表。

<a id="member-gfgridcoordinatemath2d-methods-get_rectangle_cells"></a>

### `get_rectangle_cells`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
static func get_rectangle_cells( from_cell: Vector2i, to_cell: Vector2i, grid_size: Vector2i = Vector2i(-1, -1) ) -> Array[Vector2i]:
```

获取两个端点之间的矩形格子。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 第一个端点。 |
| `to_cell` | 第二个端点。 |
| `grid_size` | 可选网格尺寸；任一轴小于 0 时不按边界过滤。 |

返回：矩形内坐标列表，包含两个端点，按 y/x 稳定顺序返回。

<a id="member-gfgridcoordinatemath2d-methods-get_range"></a>

### `get_range`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
static func get_range( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:
```

获取指定半径内的所有格子。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心格子。 |
| `radius` | 半径。 |
| `grid_size` | 可选网格尺寸；任一轴小于 0 时不按边界过滤。 |
| `include_diagonal` | 为 false 时使用曼哈顿范围；为 true 时使用切比雪夫范围。 |

返回：半径内坐标列表，包含中心，按 y/x 稳定顺序返回。

<a id="member-gfgridcoordinatemath2d-methods-get_ring"></a>

### `get_ring`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
static func get_ring( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:
```

获取指定半径的外环格子。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心格子。 |
| `radius` | 半径；0 时返回中心。 |
| `grid_size` | 可选网格尺寸；任一轴小于 0 时不按边界过滤。 |
| `include_diagonal` | 为 false 时使用曼哈顿外环；为 true 时使用切比雪夫外环。 |

返回：外环坐标列表，按 y/x 稳定顺序返回。

<a id="member-gfgridcoordinatemath2d-methods-get_chunk_window"></a>

### `get_chunk_window`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_chunk_window( center_chunk: Vector2i, radius: int, shape: StringName = &"circle" ) -> Array[Vector2i]:
```

获取中心 chunk 周围的候选窗口。

参数：

| 名称 | 说明 |
|---|---|
| `center_chunk` | 中心 chunk 坐标。 |
| `radius` | chunk 半径；小于 0 时返回空数组。 |
| `shape` | 窗口形状。支持 "circle"/"euclidean"、"square"/"chebyshev"、"diamond"/"manhattan"；未知值按 circle 处理。 |

返回：候选 chunk 坐标数组，按 y/x 稳定顺序返回。

结构：

- `return`: Array[Vector2i]，中心 chunk 周围的候选 chunk 坐标。

<a id="member-gfgridcoordinatemath2d-methods-diff_cells"></a>

### `diff_cells`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func diff_cells(previous_cells: Array[Vector2i], next_cells: Array[Vector2i]) -> Dictionary:
```

计算两个格子集合的稳定差分。

参数：

| 名称 | 说明 |
|---|---|
| `previous_cells` | 旧集合。重复项会被去重，removed 按首次出现顺序返回。 |
| `next_cells` | 新集合。重复项会被去重，added/kept 按首次出现顺序返回。 |

返回：差分报告。

结构：

- `previous_cells`: Array[Vector2i]，旧格子集合。
- `next_cells`: Array[Vector2i]，新格子集合。
- `return`: Dictionary，包含 added: Array[Vector2i]、removed: Array[Vector2i]、kept: Array[Vector2i]、changed: bool、previous_count: int、next_count: int。

<a id="member-gfgridcoordinatemath2d-methods-get_line"></a>

### `get_line`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
static func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
```

获取连接两个格子的 Bresenham 直线。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 起点格子。 |
| `to_cell` | 终点格子。 |

返回：坐标列表，包含起点与终点。

<a id="member-gfgridcoordinatemath2d-methods-has_line_of_sight"></a>

### `has_line_of_sight`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
static func has_line_of_sight( from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable, include_endpoints: bool = false ) -> bool:
```

判断两格之间是否有视线。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 起点格子。 |
| `to_cell` | 终点格子。 |
| `is_blocking` | 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `include_endpoints` | 是否检查起点与终点是否阻挡。 |

返回：没有阻挡时返回 true；阻挡回调无效时也返回 true。

<a id="member-gfgridcoordinatemath2d-methods-flood_fill"></a>

### `flood_fill`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func flood_fill( grid_size: Vector2i, start: Vector2i, is_match: Callable, include_diagonal: bool = false ) -> Array[Vector2i]:
```

从起点执行泛洪搜索，返回所有满足匹配条件且连通的格子。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `is_match` | 匹配回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `include_diagonal` | 是否允许斜向连通。 |

返回：连通格子列表。
