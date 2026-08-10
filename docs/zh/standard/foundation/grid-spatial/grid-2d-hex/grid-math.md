# 规则 2D 网格

2D 规则网格能力按职责拆成 `GFGridCoordinateMath2D`、`GFGridPathMath2D`、`GFGridGenerationMath2D` 与 `GFGridConnectionMath2D`。它们都是纯算法工具，适合消消乐、连连看、推箱子、战棋格子、地图编辑器或生成前数据处理。`GFGridMath` 仍作为聚合 facade 保留常用旧入口，但新代码优先直接依赖对应专门类。

## 核心能力

- `GFGridCoordinateMath2D`：范围、外环、矩形、直线、视线、泛洪、Chunk 坐标、窗口和集合差分。
- `GFGridPathMath2D`：BFS、A*、分步 A*、路径视线抽稀和 Flow Field。
- `GFGridGenerationMath2D`：矩形迷宫拓扑、二值细胞自动机报告和生成后连通区域后处理。
- `GFGridConnectionMath2D`：最大转弯连接判定，适合连连看、管线连接和棋盘路径规则。
- `GFGridMath`：薄 facade，便于旧代码或简单脚本一次性访问上述能力。

旋转、镜像或对角翻转格子模板时，使用同组的 `GFGridTransform2D`，避免把模板变换逻辑混进寻路或范围查询。

## 范围与形状

```gdscript
var move_area := GFGridCoordinateMath2D.get_range(unit_cell, 2, board_size)
var diagonal_area := GFGridCoordinateMath2D.get_range(unit_cell, 2, board_size, true)
var footprint := GFGridCoordinateMath2D.get_rectangle_cells(Vector2i(2, 2), Vector2i(4, 3), board_size)

var visible := GFGridCoordinateMath2D.has_line_of_sight(
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return wall_cells.has(cell)
)
```

`get_range()` 和 `get_ring()` 默认使用四方向移动对应的曼哈顿距离；`include_diagonal` 为 `true` 时改用八方向移动对应的切比雪夫距离。`get_line()` 使用 Bresenham 格子直线，适合离散网格上的普通射线、指示线和简单视线判断。

为 `get_rectangle_cells()`、`get_range()` 或 `get_ring()` 提供有效 `grid_size` 时，循环范围会先收缩到网格交集，巨大半径不会先扫描边界外坐标。省略边界仍会直接物化完整结果，适合调用方已证明范围较小的场景；需要大型流式枚举时，不应把裸数组入口当作跨帧迭代器。

## Chunk 窗口

Chunk API 只做坐标和集合计算，不加载资源、不发信号、不创建节点。项目层可以把返回的 `added` 映射为加载请求，把 `removed` 映射为卸载请求，或把 `kept` 用作调试和排序。

```gdscript
var chunk_size := Vector2i(256, 256)
var current_chunk := GFGridCoordinateMath2D.world_to_chunk_cell(player.global_position, chunk_size)
var next_window := GFGridCoordinateMath2D.get_chunk_window(current_chunk, 2, &"circle")
var diff := GFGridCoordinateMath2D.diff_cells(previous_window, next_window)

for chunk in diff["added"]:
	_request_chunk_load(chunk)
for chunk in diff["removed"]:
	_request_chunk_unload(chunk)
```

`get_chunk_window()` 支持三种形状：`"circle"` / `"euclidean"` 使用欧氏半径，`"square"` / `"chebyshev"` 使用方形窗口，`"diamond"` / `"manhattan"` 使用菱形窗口。返回顺序按 y/x 稳定排序，便于测试、缓存和可复现工具链。

## 路径与连接

```gdscript
var path := GFGridPathMath2D.find_path_bfs(
	Vector2i(8, 8),
	Vector2i(0, 0),
	Vector2i(5, 4),
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell)
)

var can_link := GFGridConnectionMath2D.can_connect_with_max_turns(
	Vector2i(10, 6),
	Vector2i(1, 1),
	Vector2i(8, 4),
	func(cell: Vector2i) -> bool:
		return board[cell.y][cell.x] == null
)
```

同步 `find_path_bfs()` / `find_path_a_star()` 适合小图或一次性查询。需要跨帧预算时，使用 `GFGraphPathSearchState` 分步搜索句柄：

```gdscript
var search := GFGridPathMath2D.begin_path_a_star_search(
	Vector2i(64, 64),
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell),
	false,
	func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
		return terrain_costs.get(to_cell, 1.0)
)

var report := {}
while not report.get("finished", false):
	report = GFGraphMath.advance_path_search(search, 48)
```

分步句柄复用 `GFGraphMath` 推进，`GFGridPathMath2D` 只负责网格边界、邻居、通行、代价和启发函数适配。

## 迷宫拓扑

`generate_rect_maze_backtracker()` 使用确定性随机源生成矩形网格的开放边和邻接表。它只输出拓扑报告，不创建墙体、门、TileMap、碰撞体或房间节点。

```gdscript
var maze := GFGridGenerationMath2D.generate_rect_maze_backtracker(
	Vector2i(16, 12),
	Vector2i.ZERO,
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell),
	{ "seed": 42 }
)

if maze["ok"]:
	var open_edges: Array = maze["edges"]
	var connections: Dictionary = maze["connections"]
	_build_tiles_from_maze(open_edges, connections)
```

报告中的 `edges` 每项包含 `from`、`to` 与 `direction`；`connections` 以 `Vector2i` 为 key，值为该格开放连接到的邻居数组。`complete` 表示从起点是否访问了全部可用格：如果项目传入的可用格规则把地图分成多个不连通区域，报告仍会保留起点连通分量，但 `complete` 为 `false`。

如果报告要进入日志、CI、HTTP 或外部编辑器进程，先调用 `GFGridCoordinateMath2D.to_json_compatible_report(report)` 或 facade 上的 `GFGridMath.to_json_compatible_report(report)`。它会把 `Vector2i` key、PackedArray、非有限浮点和其他 Godot Variant 转为可安全 `JSON.stringify()` 的结构；项目内继续处理原始格子 key 时仍应使用原始报告。

## 细胞自动机

`generate_cellular_automata_map()` 生成二值格子状态，默认使用八邻域洞穴平滑规则。它只返回 `cells`、`alive_cells` 和统计字段，不创建 TileMap、地形、碰撞或房间节点。

```gdscript
var cave := GFGridGenerationMath2D.generate_cellular_automata_map(
	Vector2i(64, 48),
	Callable(),
	{
		"seed": 42,
		"alive_chance": 0.45,
		"iterations": 4,
		"outside_alive": true,
	}
)

if cave["ok"]:
	for cell in cave["alive_cells"]:
		_paint_wall_cell(cell)
```

如果项目已有初始掩码，可以传入回调；规则阈值也可以替换成草地、雾区、装饰候选等项目自己的语义：

```gdscript
var smoothed := GFGridGenerationMath2D.generate_cellular_automata_map(
	board_size,
	func(cell: Vector2i) -> bool:
		return rough_mask.has(cell),
	{
		"iterations": 2,
		"include_diagonal": true,
		"outside_alive": false,
		"survive_min": 3,
		"survive_max": 8,
		"birth_min": 4,
		"birth_max": 8,
	}
)
```

## 连通区域后处理

`find_cell_regions()` 可以把任意二维格子集合按四邻域或八邻域拆成连通区域；`filter_cell_regions_by_size()` 会基于同一规则输出保留和移除的格子。它们适合在细胞自动机、噪声阈值、候选散布或编辑器批处理后剔除小孤岛，但不会解释墙体、地形、房间、实体或可通行语义。

```gdscript
var region_report := GFGridGenerationMath2D.find_cell_regions(
	cave["alive_cells"],
	{ "include_diagonal": false }
)

var cleaned := GFGridGenerationMath2D.filter_cell_regions_by_size(
	cave["alive_cells"],
	16,
	{ "include_diagonal": false }
)

if cleaned["ok"]:
	for cell in cleaned["kept_cells"]:
		_keep_generated_cell(cell)
```

区域报告中的 `regions` 是 `Array[Array[Vector2i]]`，`region_indices` 可以从格子反查区域索引；`largest_region_index` 和 `largest_region_size` 便于项目只保留主区域或在 UI 中提示生成质量。进入日志或外部工具前，同样先使用 `to_json_compatible_report()` 转换。

## 代价与流场

```gdscript
var path := GFGridPathMath2D.find_path_a_star(
	Vector2i(32, 32),
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell),
	false,
	func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
		return terrain_costs.get(to_cell, 1.0)
)

var field := GFGridPathMath2D.build_flow_field(
	Vector2i(32, 32),
	[target_cell],
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell)
)

var direction := (field["directions"] as Dictionary).get(unit_cell, Vector2i.ZERO)
```

## 路径抽稀

路径已经找到后，可以用现有视线规则移除多余中间格：

```gdscript
var simplified := GFGridPathMath2D.simplify_path_line_of_sight(
	path,
	func(cell: Vector2i) -> bool:
		return wall_cells.has(cell)
)
```

抽稀只判断格子直线是否被阻挡，不执行单位移动、不避让动态碰撞，也不替项目解释转向动画。

## 使用边界

这些 2D 网格工具只接收通行、代价、阻挡、初始状态和候选回调，不规定障碍、阵营、地形、棋子语义、移动动画、迷宫墙体表现、细胞状态含义或胜负规则。项目层负责把自己的地图数据转换成回调，并解释返回的范围、直线、路径、方向、迷宫拓扑、细胞自动机状态或连接结果。
