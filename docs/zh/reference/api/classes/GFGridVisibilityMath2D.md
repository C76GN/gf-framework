# GFGridVisibilityMath2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_visibility_math_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

有界二维网格的整片视野查询。 使用迭代对称阴影扫描，只返回当前可见格，不持有场景、阵营或探索历史。 固定允许两堵仅在角点接触的墙之间透视；不等价于 Bresenham 点对点 LOS。 每次调用独立缓存阻挡值，回调须同步且不修改正在查询的地图。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`MAX_RADIUS`](#member-gfgridvisibilitymath2d-constants-max_radius) | `const MAX_RADIUS: int = 128` |
| 常量 | [`MAX_CELLS`](#member-gfgridvisibilitymath2d-constants-max_cells) | `const MAX_CELLS: int = 66049` |
| 方法 | [`compute_fov`](#member-gfgridvisibilitymath2d-methods-compute_fov) | `static func compute_fov( grid_size: Vector2i, origin: Vector2i, radius: int, is_blocking: Callable, include_walls: bool = true, max_cells: int = MAX_CELLS ) -> Dictionary:` |

## 常量

<a id="member-gfgridvisibilitymath2d-constants-max_radius"></a>

### `MAX_RADIUS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_RADIUS: int = 128
```

允许的最大整数欧氏半径。

<a id="member-gfgridvisibilitymath2d-constants-max_cells"></a>

### `MAX_CELLS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_CELLS: int = 66049
```

查询窗口允许的最大格数，等于最大半径包围盒的面积。

## 方法

<a id="member-gfgridvisibilitymath2d-methods-compute_fov"></a>

### `compute_fov`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func compute_fov( grid_size: Vector2i, origin: Vector2i, radius: int, is_blocking: Callable, include_walls: bool = true, max_cells: int = MAX_CELLS ) -> Dictionary:
```

计算有限网格内整数欧氏圆形范围的可见格。 透明格之间互见对称；可见墙面参与遮挡，是否输出由 include_walls 控制。 原点必须透明，半径为零也会查询原点。结果按 y 再 x 升序排列且无重复。 先以裁剪到网格内的半径包围盒面积做保守准入，即使圆内格数或实际可见格更少， 包围盒超预算也会失败。阻挡回调对圆内每个被访问格最多调用一次，不查询网格外。 回调的运行时间和外部副作用不能由此纯函数中断或回滚。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格正尺寸。 |
| `origin` | 网格内的透明观察格。 |
| `radius` | 0 至 MAX_RADIUS 的整数欧氏半径。 |
| `is_blocking` | 同步纯查询，恰好接收一个 Vector2i 参数并返回 bool；不支持需要其它参数的回调或异步回调。 |
| `include_walls` | 是否将可见墙格包含在输出中；墙格始终遮挡。 |
| `max_cells` | 1 至 MAX_CELLS 的裁剪包围盒格数预算。 |

返回：有界视野报告；成功的 error 为空，失败的 visible_cells 始终为空，不发布部分结果。

结构：

- `return`: Dictionary，包含 ok: bool、error: StringName、visible_cells: Array[Vector2i]、queried_cell_count: int（实际阻挡回调次数）、error_cell: Vector2i（查询失败格；成功或参数准入失败为 (-1, -1)）。error 为空 StringName，或 invalid_grid_size、origin_out_of_bounds、invalid_radius、invalid_budget、cell_budget_exceeded、invalid_predicate、invalid_predicate_result、origin_blocked。
