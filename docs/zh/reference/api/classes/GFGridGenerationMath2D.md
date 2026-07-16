# GFGridGenerationMath2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_generation_math_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

2D 网格程序生成报告工具。 提供矩形迷宫拓扑、二值细胞自动机生成和连通区域后处理。它只输出稳定数据报告， 不创建 TileMap、节点、碰撞体、房间资源或任何项目业务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_MAZE_CELLS`](#member-gfgridgenerationmath2d-constants-default_max_maze_cells) | `const DEFAULT_MAX_MAZE_CELLS: int = 262144` |
| 常量 | [`DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS`](#member-gfgridgenerationmath2d-constants-default_max_cellular_automata_cells) | `const DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS: int = 262144` |
| 常量 | [`DEFAULT_MAX_CELL_REGION_CELLS`](#member-gfgridgenerationmath2d-constants-default_max_cell_region_cells) | `const DEFAULT_MAX_CELL_REGION_CELLS: int = 262144` |
| 方法 | [`generate_rect_maze_backtracker`](#member-gfgridgenerationmath2d-methods-generate_rect_maze_backtracker) | `static func generate_rect_maze_backtracker( grid_size: Vector2i, start_cell: Vector2i = Vector2i.ZERO, is_cell_enabled: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`generate_cellular_automata_map`](#member-gfgridgenerationmath2d-methods-generate_cellular_automata_map) | `static func generate_cellular_automata_map( grid_size: Vector2i, is_initial_alive: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`find_cell_regions`](#member-gfgridgenerationmath2d-methods-find_cell_regions) | `static func find_cell_regions(cells: Array[Vector2i], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`filter_cell_regions_by_size`](#member-gfgridgenerationmath2d-methods-filter_cell_regions_by_size) | `static func filter_cell_regions_by_size( cells: Array[Vector2i], minimum_region_size: int, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfgridgenerationmath2d-constants-default_max_maze_cells"></a>

### `DEFAULT_MAX_MAZE_CELLS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_MAZE_CELLS: int = 262144
```

默认矩形迷宫最大格子数，避免误把超大生成任务交给单帧纯 GDScript。

<a id="member-gfgridgenerationmath2d-constants-default_max_cellular_automata_cells"></a>

### `DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS: int = 262144
```

默认细胞自动机最大格子数，避免误把超大生成任务交给单帧纯 GDScript。

<a id="member-gfgridgenerationmath2d-constants-default_max_cell_region_cells"></a>

### `DEFAULT_MAX_CELL_REGION_CELLS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_CELL_REGION_CELLS: int = 262144
```

默认连通区域分析最大格子数，避免误把超大生成后处理交给单帧纯 GDScript。

## 方法

<a id="member-gfgridgenerationmath2d-methods-generate_rect_maze_backtracker"></a>

### `generate_rect_maze_backtracker`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func generate_rect_maze_backtracker( grid_size: Vector2i, start_cell: Vector2i = Vector2i.ZERO, is_cell_enabled: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:
```

使用回溯生成矩形网格迷宫拓扑。 该方法只输出开放边与邻接表，不创建 TileMap、墙体节点、房间资源或碰撞体。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start_cell` | 起始格子。 |
| `is_cell_enabled` | 可用格回调，签名为 `func(cell: Vector2i) -> bool`；无效时全部格子可用。 |
| `options` | 生成选项。 |

返回：迷宫拓扑报告。

结构：

- `options`: Dictionary supports seed, include_diagonal, and max_cells.
- `return`: Dictionary with ok, error, algorithm, grid_size, start_cell, seed, include_diagonal, cell_count, max_cells, available_count, blocked_count, visited_count, edge_count, complete, edges, and connections.

<a id="member-gfgridgenerationmath2d-methods-generate_cellular_automata_map"></a>

### `generate_cellular_automata_map`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func generate_cellular_automata_map( grid_size: Vector2i, is_initial_alive: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:
```

生成二值细胞自动机网格报告。 该方法只输出布尔格子状态、存活格列表和统计信息，不创建 TileMap、节点、地形、 房间、碰撞体或项目资源。默认规则使用常见八邻域洞穴平滑：存活格在相邻存活数 大于等于 4 时保留，死亡格在相邻存活数大于等于 5 时生成。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `is_initial_alive` | 可选初始状态回调，签名为 `func(cell: Vector2i) -> bool`；无效时使用 seed 和 alive_chance 随机初始化。 |
| `options` | 生成选项。 |

返回：细胞自动机报告。

结构：

- `options`: Dictionary supports seed, alive_chance, iterations, include_diagonal, outside_alive, survive_min, survive_max, birth_min, birth_max, and max_cells.
- `return`: Dictionary with ok, error, algorithm, grid_size, seed, alive_chance, iterations, include_diagonal, outside_alive, survive_min, survive_max, birth_min, birth_max, cell_count, max_cells, alive_count, dead_count, cells, and alive_cells.

<a id="member-gfgridgenerationmath2d-methods-find_cell_regions"></a>

### `find_cell_regions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func find_cell_regions(cells: Array[Vector2i], options: Dictionary = {}) -> Dictionary:
```

查找一组二维格子的连通区域。 该方法只根据格子集合和四/八邻域连通关系输出区域报告，不解释格子的地形、房间、 墙体、实体或可通行语义。

参数：

| 名称 | 说明 |
|---|---|
| `cells` | 待分析格子集合；重复项会被去重。 |
| `options` | 分析选项。 |

返回：连通区域报告。

结构：

- `cells`: Array[Vector2i]，待分析格子集合。
- `options`: Dictionary supports include_diagonal and max_cells.
- `return`: Dictionary with ok, error, algorithm, include_diagonal, input_count, cell_count, max_cells, region_count, all_connected, largest_region_index, largest_region_size, regions, and region_indices.

<a id="member-gfgridgenerationmath2d-methods-filter_cell_regions_by_size"></a>

### `filter_cell_regions_by_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func filter_cell_regions_by_size( cells: Array[Vector2i], minimum_region_size: int, options: Dictionary = {} ) -> Dictionary:
```

按连通区域尺寸过滤二维格子集合。 该方法适合在细胞自动机、噪声阈值、候选散布或编辑器批处理后剔除小孤岛。 它只输出保留/移除的格子与区域报告，不创建或修改 TileMap、节点和项目资源。

参数：

| 名称 | 说明 |
|---|---|
| `cells` | 待过滤格子集合；重复项会被去重。 |
| `minimum_region_size` | 保留区域的最小格子数；0 表示保留全部区域。 |
| `options` | 分析选项。 |

返回：区域过滤报告。

结构：

- `cells`: Array[Vector2i]，待过滤格子集合。
- `options`: Dictionary supports include_diagonal and max_cells.
- `return`: Dictionary with ok, error, algorithm, include_diagonal, minimum_region_size, input_count, cell_count, max_cells, region_count, kept_region_count, removed_region_count, kept_count, removed_count, kept_cells, removed_cells, kept_regions, removed_regions, and region_report.
