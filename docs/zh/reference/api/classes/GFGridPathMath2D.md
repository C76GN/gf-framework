# GFGridPathMath2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_path_math_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

2D 网格路径搜索与 Flow Field 工具。 负责 BFS、A*、分步路径搜索、视线抽稀和 Flow Field 生成。坐标、 邻居和视线基础能力由 GFGridCoordinateMath2D 提供。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`find_path_bfs`](#member-gfgridpathmath2d-methods-find_path_bfs) | `static func find_path_bfs( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`find_path_a_star`](#member-gfgridpathmath2d-methods-find_path_a_star) | `static func find_path_a_star( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector2i]:` |
| 方法 | [`begin_path_a_star_search`](#member-gfgridpathmath2d-methods-begin_path_a_star_search) | `static func begin_path_a_star_search( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> GFGraphPathSearchState:` |
| 方法 | [`simplify_path_line_of_sight`](#member-gfgridpathmath2d-methods-simplify_path_line_of_sight) | `static func simplify_path_line_of_sight( path: Array[Vector2i], is_blocking: Callable, include_endpoints: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`build_flow_field`](#member-gfgridpathmath2d-methods-build_flow_field) | `static func build_flow_field( grid_size: Vector2i, goals: Array[Vector2i], is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable() ) -> Dictionary:` |

## 方法

<a id="member-gfgridpathmath2d-methods-find_path_bfs"></a>

### `find_path_bfs`

- API：`public`
- 首次版本：`8.0.0`

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

<a id="member-gfgridpathmath2d-methods-find_path_a_star"></a>

### `find_path_a_star`

- API：`public`
- 首次版本：`8.0.0`

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

<a id="member-gfgridpathmath2d-methods-begin_path_a_star_search"></a>

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

<a id="member-gfgridpathmath2d-methods-simplify_path_line_of_sight"></a>

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

<a id="member-gfgridpathmath2d-methods-build_flow_field"></a>

### `build_flow_field`

- API：`public`
- 首次版本：`8.0.0`

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
