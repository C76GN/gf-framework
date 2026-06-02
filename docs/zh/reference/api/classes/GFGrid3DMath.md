# GFGrid3DMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_3d_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

3D 整数网格的纯算法工具。 提供边界判断、邻居枚举、A* 寻路、可达范围和台阶式表面邻居。 它不依赖 GridMap 或场景节点；可通行、代价和高度规则都由回调注入。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_in_bounds`](#member-gfgrid3dmath-methods-is_in_bounds) | `static func is_in_bounds(cell: Vector3i, grid_size: Vector3i) -> bool:` |
| 方法 | [`get_neighbors`](#member-gfgrid3dmath-methods-get_neighbors) | `static func get_neighbors( cell: Vector3i, grid_size: Vector3i, allow_diagonal: bool = false ) -> Array[Vector3i]:` |
| 方法 | [`get_surface_neighbors`](#member-gfgrid3dmath-methods-get_surface_neighbors) | `static func get_surface_neighbors( cell: Vector3i, grid_size: Vector3i, is_walkable: Callable, max_step_up: int = 1, max_step_down: int = 1, horizontal_directions: Array[Vector3i] = [] ) -> Array[Vector3i]:` |
| 方法 | [`find_path_a_star`](#member-gfgrid3dmath-methods-find_path_a_star) | `static func find_path_a_star( grid_size: Vector3i, start: Vector3i, goal: Vector3i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector3i]:` |
| 方法 | [`find_reachable`](#member-gfgrid3dmath-methods-find_reachable) | `static func find_reachable( grid_size: Vector3i, start: Vector3i, max_cost: float, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable() ) -> Dictionary:` |
| 方法 | [`find_surface_path_a_star`](#member-gfgrid3dmath-methods-find_surface_path_a_star) | `static func find_surface_path_a_star( grid_size: Vector3i, start: Vector3i, goal: Vector3i, is_walkable: Callable, max_step_up: int = 1, max_step_down: int = 1, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector3i]:` |

## 方法

<a id="member-gfgrid3dmath-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`

```gdscript
static func is_in_bounds(cell: Vector3i, grid_size: Vector3i) -> bool:
```

判断格子是否在 3D 网格范围内。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 待检测格子。 |
| `grid_size` | 网格尺寸，三个轴都必须大于 0。 |

返回：在范围内时返回 true。

<a id="member-gfgrid3dmath-methods-get_neighbors"></a>

### `get_neighbors`

- API：`public`

```gdscript
static func get_neighbors( cell: Vector3i, grid_size: Vector3i, allow_diagonal: bool = false ) -> Array[Vector3i]:
```

获取 3D 网格邻居。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 中心格子。 |
| `grid_size` | 网格尺寸。 |
| `allow_diagonal` | 是否包含 26 邻域；否则只包含 6 个正交邻居。 |

返回：边界内邻居数组。

<a id="member-gfgrid3dmath-methods-get_surface_neighbors"></a>

### `get_surface_neighbors`

- API：`public`

```gdscript
static func get_surface_neighbors( cell: Vector3i, grid_size: Vector3i, is_walkable: Callable, max_step_up: int = 1, max_step_down: int = 1, horizontal_directions: Array[Vector3i] = [] ) -> Array[Vector3i]:
```

获取台阶式表面移动邻居。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 当前站立格。 |
| `grid_size` | 网格尺寸。 |
| `is_walkable` | 可站立回调，签名为 `func(cell: Vector3i) -> bool`。 |
| `max_step_up` | 单步最多上升高度。 |
| `max_step_down` | 单步最多下降高度。 |
| `horizontal_directions` | 可选水平移动方向；为空时使用 X/Z 四方向。 |

返回：可站立的相邻表面格。

<a id="member-gfgrid3dmath-methods-find_path_a_star"></a>

### `find_path_a_star`

- API：`public`

```gdscript
static func find_path_a_star( grid_size: Vector3i, start: Vector3i, goal: Vector3i, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector3i]:
```

使用 A* 查找 3D 网格路径。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector3i) -> bool`。 |
| `allow_diagonal` | 是否允许 26 邻域移动。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector3i, to: Vector3i) -> float`；返回负数表示不可通行。 |
| `heuristic` | 启发函数名称，支持 `manhattan`、`chebyshev`、`euclidean`。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

<a id="member-gfgrid3dmath-methods-find_reachable"></a>

### `find_reachable`

- API：`public`

```gdscript
static func find_reachable( grid_size: Vector3i, start: Vector3i, max_cost: float, is_walkable: Callable, allow_diagonal: bool = false, step_cost: Callable = Callable() ) -> Dictionary:
```

查找指定代价内可达的 3D 网格格子。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `max_cost` | 最大累计代价。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector3i) -> bool`。 |
| `allow_diagonal` | 是否允许 26 邻域移动。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector3i, to: Vector3i) -> float`；返回负数表示不可通行。 |

返回：字典，键为可达格子，值为从起点到该格子的最低代价。

结构：

- `return`: Dictionary mapping reachable Vector3i cells to lowest float costs.

<a id="member-gfgrid3dmath-methods-find_surface_path_a_star"></a>

### `find_surface_path_a_star`

- API：`public`

```gdscript
static func find_surface_path_a_star( grid_size: Vector3i, start: Vector3i, goal: Vector3i, is_walkable: Callable, max_step_up: int = 1, max_step_down: int = 1, step_cost: Callable = Callable(), heuristic: StringName = &"manhattan" ) -> Array[Vector3i]:
```

使用台阶式表面邻居查找路径。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点站立格。 |
| `goal` | 终点站立格。 |
| `is_walkable` | 可站立回调，签名为 `func(cell: Vector3i) -> bool`。 |
| `max_step_up` | 单步最多上升高度。 |
| `max_step_down` | 单步最多下降高度。 |
| `step_cost` | 可选代价回调，签名为 `func(from: Vector3i, to: Vector3i) -> float`；返回负数表示不可通行。 |
| `heuristic` | 启发函数名称，支持 `manhattan`、`chebyshev`、`euclidean`。 |

返回：包含起点与终点的路径；无法到达时返回空数组。
