# GFHexGridMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_hex_grid_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

六边形网格的纯算法工具。 提供 offset / cube 坐标转换、邻居枚举、距离、范围、环、直线、视线、 A* 路径查找和 Flow Field 生成。它不依赖 GFArchitecture，可直接在 Model、System、Controller 或测试中静态调用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`OffsetLayout`](#member-gfhexgridmath-enums-offsetlayout) | `enum OffsetLayout` |
| 枚举 | [`HexOrientation`](#member-gfhexgridmath-enums-hexorientation) | `enum HexOrientation` |
| 常量 | [`SQRT_3`](#member-gfhexgridmath-constants-sqrt_3) | `const SQRT_3: float = 1.7320508075688772` |
| 常量 | [`DEFAULT_HEX_SIZE`](#member-gfhexgridmath-constants-default_hex_size) | `const DEFAULT_HEX_SIZE: float = 32.0` |
| 方法 | [`is_in_bounds`](#member-gfhexgridmath-methods-is_in_bounds) | `static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:` |
| 方法 | [`offset_to_cube`](#member-gfhexgridmath-methods-offset_to_cube) | `static func offset_to_cube(cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector3i:` |
| 方法 | [`cube_to_offset`](#member-gfhexgridmath-methods-cube_to_offset) | `static func cube_to_offset(cube: Vector3i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector2i:` |
| 方法 | [`cube_round`](#member-gfhexgridmath-methods-cube_round) | `static func cube_round(cube: Vector3) -> Vector3i:` |
| 方法 | [`offset_to_pixel`](#member-gfhexgridmath-methods-offset_to_pixel) | `static func offset_to_pixel( cell: Vector2i, hex_size: float = DEFAULT_HEX_SIZE, layout: OffsetLayout = OffsetLayout.ODD_R, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2:` |
| 方法 | [`pixel_to_offset`](#member-gfhexgridmath-methods-pixel_to_offset) | `static func pixel_to_offset( pixel: Vector2, hex_size: float = DEFAULT_HEX_SIZE, layout: OffsetLayout = OffsetLayout.ODD_R, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2i:` |
| 方法 | [`cube_to_pixel`](#member-gfhexgridmath-methods-cube_to_pixel) | `static func cube_to_pixel( cube: Vector3i, hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2:` |
| 方法 | [`pixel_to_cube`](#member-gfhexgridmath-methods-pixel_to_cube) | `static func pixel_to_cube( pixel: Vector2, hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector3i:` |
| 方法 | [`get_polygon_points`](#member-gfhexgridmath-methods-get_polygon_points) | `static func get_polygon_points( hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> PackedVector2Array:` |
| 方法 | [`get_neighbors`](#member-gfhexgridmath-methods-get_neighbors) | `static func get_neighbors( cell: Vector2i, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:` |
| 方法 | [`distance`](#member-gfhexgridmath-methods-distance) | `static func distance( from_cell: Vector2i, to_cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R ) -> int:` |
| 方法 | [`cube_distance`](#member-gfhexgridmath-methods-cube_distance) | `static func cube_distance(from_cube: Vector3i, to_cube: Vector3i) -> int:` |
| 方法 | [`get_range`](#member-gfhexgridmath-methods-get_range) | `static func get_range( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:` |
| 方法 | [`get_ring`](#member-gfhexgridmath-methods-get_ring) | `static func get_ring( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:` |
| 方法 | [`get_line`](#member-gfhexgridmath-methods-get_line) | `static func get_line( from_cell: Vector2i, to_cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:` |
| 方法 | [`has_line_of_sight`](#member-gfhexgridmath-methods-has_line_of_sight) | `static func has_line_of_sight( from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, include_endpoints: bool = false ) -> bool:` |
| 方法 | [`find_path_a_star`](#member-gfhexgridmath-methods-find_path_a_star) | `static func find_path_a_star( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Array[Vector2i]:` |
| 方法 | [`begin_path_a_star_search`](#member-gfhexgridmath-methods-begin_path_a_star_search) | `static func begin_path_a_star_search( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> GFGraphPathSearchState:` |
| 方法 | [`simplify_path_line_of_sight`](#member-gfhexgridmath-methods-simplify_path_line_of_sight) | `static func simplify_path_line_of_sight( path: Array[Vector2i], is_blocking: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, include_endpoints: bool = false ) -> Array[Vector2i]:` |
| 方法 | [`build_flow_field`](#member-gfhexgridmath-methods-build_flow_field) | `static func build_flow_field( grid_size: Vector2i, goals: Array[Vector2i], is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Dictionary:` |
| 方法 | [`find_reachable`](#member-gfhexgridmath-methods-find_reachable) | `static func find_reachable( grid_size: Vector2i, start: Vector2i, max_cost: float, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Dictionary:` |

## 枚举

<a id="member-gfhexgridmath-enums-offsetlayout"></a>

### `OffsetLayout`

- API：`public`

```gdscript
enum OffsetLayout {
	## 奇数行右偏移，常用于 pointy-top 横向行布局。
	ODD_R,
	## 偶数行右偏移，常用于 pointy-top 横向行布局。
	EVEN_R,
	## 奇数列下偏移，常用于 flat-top 纵向列布局。
	ODD_Q,
	## 偶数列下偏移，常用于 flat-top 纵向列布局。
	EVEN_Q,
}
```

Offset 坐标布局。

<a id="member-gfhexgridmath-enums-hexorientation"></a>

### `HexOrientation`

- API：`public`

```gdscript
enum HexOrientation {
	## 尖顶朝上。
	POINTY_TOP,
	## 平顶朝上。
	FLAT_TOP,
}
```

像素坐标换算时使用的六边形朝向。

## 常量

<a id="member-gfhexgridmath-constants-sqrt_3"></a>

### `SQRT_3`

- API：`public`

```gdscript
const SQRT_3: float = 1.7320508075688772
```

根号 3 的缓存值，用于六边形像素坐标换算。

<a id="member-gfhexgridmath-constants-default_hex_size"></a>

### `DEFAULT_HEX_SIZE`

- API：`public`

```gdscript
const DEFAULT_HEX_SIZE: float = 32.0
```

默认六边形外接圆半径。

## 方法

<a id="member-gfhexgridmath-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`

```gdscript
static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
```

判断 offset 坐标是否位于网格范围内。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | offset 坐标。 |
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |

返回：在范围内返回 true。

<a id="member-gfhexgridmath-methods-offset_to_cube"></a>

### `offset_to_cube`

- API：`public`

```gdscript
static func offset_to_cube(cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector3i:
```

将 offset 坐标转换为 cube 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | offset 坐标。 |
| `layout` | offset 坐标布局。 |

返回：cube 坐标；满足 x + y + z == 0。

<a id="member-gfhexgridmath-methods-cube_to_offset"></a>

### `cube_to_offset`

- API：`public`

```gdscript
static func cube_to_offset(cube: Vector3i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector2i:
```

将 cube 坐标转换为 offset 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cube` | cube 坐标。 |
| `layout` | offset 坐标布局。 |

返回：offset 坐标。

<a id="member-gfhexgridmath-methods-cube_round"></a>

### `cube_round`

- API：`public`

```gdscript
static func cube_round(cube: Vector3) -> Vector3i:
```

四舍五入浮点 cube 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cube` | 浮点 cube 坐标。 |

返回：最近的整数 cube 坐标；满足 x + y + z == 0。

<a id="member-gfhexgridmath-methods-offset_to_pixel"></a>

### `offset_to_pixel`

- API：`public`

```gdscript
static func offset_to_pixel( cell: Vector2i, hex_size: float = DEFAULT_HEX_SIZE, layout: OffsetLayout = OffsetLayout.ODD_R, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2:
```

将 offset 坐标转换为像素中心点。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | offset 坐标。 |
| `hex_size` | 六边形外接圆半径。 |
| `layout` | offset 坐标布局。 |
| `orientation` | 六边形朝向。 |

返回：像素中心点。

<a id="member-gfhexgridmath-methods-pixel_to_offset"></a>

### `pixel_to_offset`

- API：`public`

```gdscript
static func pixel_to_offset( pixel: Vector2, hex_size: float = DEFAULT_HEX_SIZE, layout: OffsetLayout = OffsetLayout.ODD_R, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2i:
```

将像素坐标转换为最近的 offset 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `pixel` | 像素坐标。 |
| `hex_size` | 六边形外接圆半径。 |
| `layout` | offset 坐标布局。 |
| `orientation` | 六边形朝向。 |

返回：最近的 offset 坐标。

<a id="member-gfhexgridmath-methods-cube_to_pixel"></a>

### `cube_to_pixel`

- API：`public`

```gdscript
static func cube_to_pixel( cube: Vector3i, hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector2:
```

将 cube 坐标转换为像素中心点。

参数：

| 名称 | 说明 |
|---|---|
| `cube` | cube 坐标。 |
| `hex_size` | 六边形外接圆半径。 |
| `orientation` | 六边形朝向。 |

返回：像素中心点。

<a id="member-gfhexgridmath-methods-pixel_to_cube"></a>

### `pixel_to_cube`

- API：`public`

```gdscript
static func pixel_to_cube( pixel: Vector2, hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> Vector3i:
```

将像素坐标转换为最近的 cube 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `pixel` | 像素坐标。 |
| `hex_size` | 六边形外接圆半径。 |
| `orientation` | 六边形朝向。 |

返回：最近的 cube 坐标。

<a id="member-gfhexgridmath-methods-get_polygon_points"></a>

### `get_polygon_points`

- API：`public`

```gdscript
static func get_polygon_points( hex_size: float = DEFAULT_HEX_SIZE, orientation: HexOrientation = HexOrientation.POINTY_TOP ) -> PackedVector2Array:
```

获取六边形顶点相对坐标。

参数：

| 名称 | 说明 |
|---|---|
| `hex_size` | 六边形外接圆半径。 |
| `orientation` | 六边形朝向。 |

返回：顶点数组，按顺时针排列。

<a id="member-gfhexgridmath-methods-get_neighbors"></a>

### `get_neighbors`

- API：`public`

```gdscript
static func get_neighbors( cell: Vector2i, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:
```

获取指定 offset 坐标的邻居。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 中心坐标。 |
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `layout` | offset 坐标布局。 |

返回：位于网格范围内的邻居列表。

<a id="member-gfhexgridmath-methods-distance"></a>

### `distance`

- API：`public`

```gdscript
static func distance( from_cell: Vector2i, to_cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R ) -> int:
```

计算两个 offset 坐标之间的六边形距离。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 起点坐标。 |
| `to_cell` | 终点坐标。 |
| `layout` | offset 坐标布局。 |

返回：六边形步数距离。

<a id="member-gfhexgridmath-methods-cube_distance"></a>

### `cube_distance`

- API：`public`

```gdscript
static func cube_distance(from_cube: Vector3i, to_cube: Vector3i) -> int:
```

计算两个 cube 坐标之间的六边形距离。

参数：

| 名称 | 说明 |
|---|---|
| `from_cube` | 起点 cube 坐标。 |
| `to_cube` | 终点 cube 坐标。 |

返回：六边形步数距离。

<a id="member-gfhexgridmath-methods-get_range"></a>

### `get_range`

- API：`public`

```gdscript
static func get_range( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:
```

获取指定半径内的所有 offset 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心坐标。 |
| `radius` | 半径。 |
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `layout` | offset 坐标布局。 |

返回：半径内坐标列表，包含中心。

<a id="member-gfhexgridmath-methods-get_ring"></a>

### `get_ring`

- API：`public`

```gdscript
static func get_ring( center: Vector2i, radius: int, grid_size: Vector2i = Vector2i(-1, -1), layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:
```

获取指定半径的外环坐标。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心坐标。 |
| `radius` | 半径；0 时返回中心。 |
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `layout` | offset 坐标布局。 |

返回：外环坐标列表。

<a id="member-gfhexgridmath-methods-get_line"></a>

### `get_line`

- API：`public`

```gdscript
static func get_line( from_cell: Vector2i, to_cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R ) -> Array[Vector2i]:
```

获取连接两个 offset 坐标的六边形直线。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 起点坐标。 |
| `to_cell` | 终点坐标。 |
| `layout` | offset 坐标布局。 |

返回：坐标列表，包含起点与终点。

<a id="member-gfhexgridmath-methods-has_line_of_sight"></a>

### `has_line_of_sight`

- API：`public`

```gdscript
static func has_line_of_sight( from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, include_endpoints: bool = false ) -> bool:
```

判断两点之间是否有视线。

参数：

| 名称 | 说明 |
|---|---|
| `from_cell` | 起点坐标。 |
| `to_cell` | 终点坐标。 |
| `is_blocking` | 阻挡回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `include_endpoints` | 是否检查起点与终点是否阻挡。 |

返回：没有阻挡时返回 true。

<a id="member-gfhexgridmath-methods-find_path_a_star"></a>

### `find_path_a_star`

- API：`public`

```gdscript
static func find_path_a_star( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Array[Vector2i]:
```

使用 A* 查找一条六边形路径。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `start` | 起点坐标。 |
| `goal` | 终点坐标。 |
| `is_walkable` | 可通行回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `step_cost` | 可选代价回调，签名为 \`func(from: Vector2i, to: Vector2i) -> float\`；返回负数表示不可通行。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

<a id="member-gfhexgridmath-methods-begin_path_a_star_search"></a>

### `begin_path_a_star_search`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func begin_path_a_star_search( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> GFGraphPathSearchState:
```

创建可分步推进的六边形网格 A* 搜索状态。 状态由 `GFGraphMath.advance_path_search()` 推进；本方法只负责把 Hex 布局、 邻居、通行、代价和距离启发函数适配成通用图搜索回调。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `start` | 起点 offset 坐标。 |
| `goal` | 终点 offset 坐标。 |
| `is_walkable` | 可通行回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `step_cost` | 可选代价回调，签名为 \`func(from: Vector2i, to: Vector2i) -> float\`；返回负数表示不可通行。 |

返回：`GFGraphMath` 分步路径搜索状态句柄。

结构：

- `return`: GFGraphPathSearchState returned by `GFGraphMath.begin_path_search()`.

<a id="member-gfhexgridmath-methods-simplify_path_line_of_sight"></a>

### `simplify_path_line_of_sight`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func simplify_path_line_of_sight( path: Array[Vector2i], is_blocking: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, include_endpoints: bool = false ) -> Array[Vector2i]:
```

使用 Hex 视线检测抽稀六边形网格路径。 该方法只移除可由 Hex 直线视线覆盖的中间格子，保留起点与终点；它不执行单位移动、 转向动画或碰撞响应。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 包含起点与终点的 offset 路径。 |
| `is_blocking` | 阻挡回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `include_endpoints` | 是否检查每段抽稀直线的端点是否阻挡。 |

返回：抽稀后的路径；空路径仍返回空数组。

结构：

- `path`: Array[Vector2i] path cells.

<a id="member-gfhexgridmath-methods-build_flow_field"></a>

### `build_flow_field`

- API：`public`

```gdscript
static func build_flow_field( grid_size: Vector2i, goals: Array[Vector2i], is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Dictionary:
```

从一个或多个目标格生成六边形 Flow Field。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `goals` | 目标坐标列表。 |
| `is_walkable` | 可通行回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `step_cost` | 可选代价回调，签名为 \`func(from: Vector2i, to: Vector2i) -> float\`；返回负数表示不可通行。 |

返回：包含 `costs`、`directions` 和 `goals` 的字典；`directions[cell]` 是下一步 offset 方向。

结构：

- `return`: Dictionary with `costs: Dictionary[Vector2i, float]`, `directions: Dictionary[Vector2i, Vector2i]`, and `goals: Array[Vector2i]`.

<a id="member-gfhexgridmath-methods-find_reachable"></a>

### `find_reachable`

- API：`public`

```gdscript
static func find_reachable( grid_size: Vector2i, start: Vector2i, max_cost: float, is_walkable: Callable, layout: OffsetLayout = OffsetLayout.ODD_R, step_cost: Callable = Callable() ) -> Dictionary:
```

查找移动代价限制内的可达坐标。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸；任一轴小于 0 时视为无限网格。 |
| `start` | 起点坐标。 |
| `max_cost` | 最大移动代价。 |
| `is_walkable` | 可通行回调，签名为 \`func(cell: Vector2i) -> bool\`。 |
| `layout` | offset 坐标布局。 |
| `step_cost` | 可选代价回调，签名为 \`func(from: Vector2i, to: Vector2i) -> float\`；返回负数表示不可通行。 |

返回：字典，key 为可达坐标，value 为从起点到该坐标的最低代价。

结构：

- `return`: Dictionary[Vector2i, float] mapping each reachable cell to its lowest travel cost from `start`.
