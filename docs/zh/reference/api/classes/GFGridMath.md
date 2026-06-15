# GFGridMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

网格类小游戏的纯算法工具。 提供一维索引与二维格坐标转换、邻居枚举、范围、外环、直线、视线、 泛洪搜索、BFS / A* 路径查找、Flow Field 生成以及连连看类“两折连线”判断。 它不依赖 GFArchitecture，可直接在 Model、System、Controller 或测试中静态调用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`cell_to_index`](#member-gfgridmath-methods-cell_to_index) | `static func cell_to_index(cell: Vector2i, width: int) -> int:` |
| 方法 | [`index_to_cell`](#member-gfgridmath-methods-index_to_cell) | `static func index_to_cell(index: int, width: int) -> Vector2i:` |
| 方法 | [`is_in_bounds`](#member-gfgridmath-methods-is_in_bounds) | `static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:` |
| 方法 | [`get_neighbors`](#member-gfgridmath-methods-get_neighbors) | `static func get_neighbors( cell: Vector2i, grid_size: Vector2i, include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_rectangle_cells`](#member-gfgridmath-methods-get_rectangle_cells) | `static func get_rectangle_cells( from_cell: Vector2i, to_cell: Vector2i, grid_size: Vector2i = Vector2i(-1, -1) ) -> Array[Vector2i]:` |
| 方法 | [`get_range`](#member-gfgridmath-methods-get_range) | `static func get_range( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_ring`](#member-gfgridmath-methods-get_ring) | `static func get_ring( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`get_line`](#member-gfgridmath-methods-get_line) | `static func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:` |
| 方法 | [`has_line_of_sight`](#member-gfgridmath-methods-has_line_of_sight) | `static func has_line_of_sight( from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable, include_endpoints: bool = false ) -> bool:` |
| 方法 | [`flood_fill`](#member-gfgridmath-methods-flood_fill) | `static func flood_fill( grid_size: Vector2i, start: Vector2i, is_match: Callable, include_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`find_path_bfs`](#member-gfgridmath-methods-find_path_bfs) | `static func find_path_bfs( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`find_path_a_star`](#member-gfgridmath-methods-find_path_a_star) | `static func find_path_a_star( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector2i]:` |
| 方法 | [`begin_path_a_star_search`](#member-gfgridmath-methods-begin_path_a_star_search) | `static func begin_path_a_star_search( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> GFGraphPathSearchState:` |
| 方法 | [`simplify_path_line_of_sight`](#member-gfgridmath-methods-simplify_path_line_of_sight) | `static func simplify_path_line_of_sight( path: Array[Vector2i], is_blocking: Callable, include_endpoints: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`build_flow_field`](#member-gfgridmath-methods-build_flow_field) | `static func build_flow_field( grid_size: Vector2i, goals: Array[Vector2i], is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable() ) -> Dictionary:` |
| 方法 | [`can_connect_with_max_turns`](#member-gfgridmath-methods-can_connect_with_max_turns) | `static func can_connect_with_max_turns( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, max_turns: int = 2, allow_outer_border: bool = true ) -> bool:` |

## 方法

<a id="member-gfgridmath-methods-cell_to_index"></a>

### `cell_to_index`

- API：`public`

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

<a id="member-gfgridmath-methods-index_to_cell"></a>

### `index_to_cell`

- API：`public`

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

<a id="member-gfgridmath-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`

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

<a id="member-gfgridmath-methods-get_neighbors"></a>

### `get_neighbors`

- API：`public`

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

<a id="member-gfgridmath-methods-get_rectangle_cells"></a>

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

<a id="member-gfgridmath-methods-get_range"></a>

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

<a id="member-gfgridmath-methods-get_ring"></a>

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

<a id="member-gfgridmath-methods-get_line"></a>

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

<a id="member-gfgridmath-methods-has_line_of_sight"></a>

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

<a id="member-gfgridmath-methods-flood_fill"></a>

### `flood_fill`

- API：`public`

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

<a id="member-gfgridmath-methods-find_path_bfs"></a>

### `find_path_bfs`

- API：`public`

```gdscript
static func find_path_bfs( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false ) -> Array[Vector2i]:
```

使用 BFS 查找一条最短路径。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `allow_diagonal` | 是否允许斜向移动。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

<a id="member-gfgridmath-methods-find_path_a_star"></a>

### `find_path_a_star`

- API：`public`

```gdscript
static func find_path_a_star( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector2i]:
```

使用 A* 查找一条低代价路径。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `allow_diagonal` | 是否允许斜向移动。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。 |
| `heuristic` | 启发函数名称，支持 `manhattan`、`chebyshev`、`octile`、`euclidean`。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

<a id="member-gfgridmath-methods-begin_path_a_star_search"></a>

### `begin_path_a_star_search`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func begin_path_a_star_search( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> GFGraphPathSearchState:
```

创建可分步推进的 2D 网格 A* 搜索状态。 状态由 `GFGraphMath.advance_path_search()` 推进；本方法只负责把网格边界、 邻居、通行、代价和启发函数适配成通用图搜索回调。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `allow_diagonal` | 是否允许斜向移动。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。 |
| `heuristic` | 启发函数名称，支持 `manhattan`、`chebyshev`、`octile`、`euclidean`。 |

返回：`GFGraphMath` 分步路径搜索状态句柄。

结构：

- `return`: GFGraphPathSearchState returned by `GFGraphMath.begin_path_search()`.

<a id="member-gfgridmath-methods-simplify_path_line_of_sight"></a>

### `simplify_path_line_of_sight`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func simplify_path_line_of_sight( path: Array[Vector2i], is_blocking: Callable, include_endpoints: bool = false ) -> Array[Vector2i]:
```

使用视线检测抽稀 2D 网格路径。 该方法只移除可由直线视线覆盖的中间格子，保留起点与终点；它不执行单位移动、 转向动画或碰撞响应。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 包含起点与终点的格子路径。 |
| `is_blocking` | 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `include_endpoints` | 是否检查每段抽稀直线的端点是否阻挡。 |

返回：抽稀后的路径；空路径仍返回空数组。

结构：

- `path`: Array[Vector2i] path cells.

<a id="member-gfgridmath-methods-build_flow_field"></a>

### `build_flow_field`

- API：`public`

```gdscript
static func build_flow_field( grid_size: Vector2i, goals: Array[Vector2i], is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable() ) -> Dictionary:
```

从一个或多个目标格生成 Flow Field。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `goals` | 目标格列表。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`。 |
| `allow_diagonal` | 是否允许斜向移动。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。 |

返回：包含 `costs`、`directions` 和 `goals` 的字典；`directions[cell]` 是下一步方向。

结构：

- `return`: Dictionary with `costs: Dictionary[Vector2i, float]`, `directions: Dictionary[Vector2i, Vector2i]`, and `goals: Array[Vector2i]`.

<a id="member-gfgridmath-methods-can_connect_with_max_turns"></a>

### `can_connect_with_max_turns`

- API：`public`

```gdscript
static func can_connect_with_max_turns( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, max_turns: int = 2, allow_outer_border: bool = true ) -> bool:
```

判断两个格子是否能在指定转折次数内连通。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`；起点与终点可不通行。 |
| `max_turns` | 最大转折次数，连连看常用值为 2。 |
| `allow_outer_border` | 是否允许路径经过网格外一圈虚拟空格。 |

返回：可连通时返回 true。
