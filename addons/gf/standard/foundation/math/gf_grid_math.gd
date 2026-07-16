## GFGridMath: 2D 网格算法聚合 facade。
##
## 该类只保留历史稳定入口和常用聚合调用；具体实现归属到
## GFGridCoordinateMath2D、GFGridPathMath2D、GFGridGenerationMath2D
## 与 GFGridConnectionMath2D。新代码优先直接依赖对应专门类，以保持坐标、
## 路径、生成和连接规则的职责边界清晰。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGridMath
extends RefCounted


# --- 常量 ---

## 默认矩形迷宫最大格子数，避免误把超大生成任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_MAZE_CELLS: int = GFGridGenerationMath2D.DEFAULT_MAX_MAZE_CELLS

## 默认细胞自动机最大格子数，避免误把超大生成任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS: int = GFGridGenerationMath2D.DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS

## 默认连通区域分析最大格子数，避免误把超大生成后处理交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_CELL_REGION_CELLS: int = GFGridGenerationMath2D.DEFAULT_MAX_CELL_REGION_CELLS


# --- 公共方法 ---

## 将 2D 网格报告转换为 JSON.stringify() 安全的结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 2D 网格工具返回的报告或快照字典。
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容报告。
## [br]
## @schema report: 2D 网格工具返回的报告或快照字典。
## [br]
## @schema options: GFReportValueCodec 编码选项字典。
## [br]
## @schema return: 可安全交给 JSON.stringify() 的 Dictionary。
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	return GFGridCoordinateMath2D.to_json_compatible_report(report, options)


## 将二维格坐标转换为一维索引。
## [br]
## @api public
## [br]
## @param cell: 二维格坐标。
## [br]
## @param width: 网格宽度。
## [br]
## @return 成功时返回一维索引；宽度无效时返回 -1。
static func cell_to_index(cell: Vector2i, width: int) -> int:
	return GFGridCoordinateMath2D.cell_to_index(cell, width)


## 将一维索引转换为二维格坐标。
## [br]
## @api public
## [br]
## @param index: 一维索引。
## [br]
## @param width: 网格宽度。
## [br]
## @return 成功时返回二维格坐标；参数无效时返回 Vector2i(-1, -1)。
static func index_to_cell(index: int, width: int) -> Vector2i:
	return GFGridCoordinateMath2D.index_to_cell(index, width)


## 将世界坐标转换为二维 chunk 坐标。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param world_position: 世界坐标。
## [br]
## @param chunk_size: 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2i.ZERO。
## [br]
## @return chunk 坐标。负世界坐标使用 floor 语义，因此 -0.1 会落入 -1 号 chunk。
static func world_to_chunk_cell(world_position: Vector2, chunk_size: Vector2i) -> Vector2i:
	return GFGridCoordinateMath2D.world_to_chunk_cell(world_position, chunk_size)


## 将二维 chunk 坐标转换为世界原点坐标。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param chunk_cell: chunk 坐标。
## [br]
## @param chunk_size: 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2.ZERO。
## [br]
## @return chunk 左上/局部原点对应的世界坐标。
static func chunk_cell_to_world_origin(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:
	return GFGridCoordinateMath2D.chunk_cell_to_world_origin(chunk_cell, chunk_size)


## 将二维 chunk 坐标转换为世界中心坐标。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param chunk_cell: chunk 坐标。
## [br]
## @param chunk_size: 单个 chunk 的世界尺寸；任一轴小于等于 0 时返回 Vector2.ZERO。
## [br]
## @return chunk 中心对应的世界坐标。
static func chunk_cell_to_world_center(chunk_cell: Vector2i, chunk_size: Vector2i) -> Vector2:
	return GFGridCoordinateMath2D.chunk_cell_to_world_center(chunk_cell, chunk_size)


## 判断格坐标是否位于网格范围内。
## [br]
## @api public
## [br]
## @param cell: 二维格坐标。
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @return 在范围内返回 true。
static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	return GFGridCoordinateMath2D.is_in_bounds(cell, grid_size)


## 获取指定格子的邻居。
## [br]
## @api public
## [br]
## @param cell: 中心格子。
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param include_diagonal: 是否包含四个斜向邻居。
## [br]
## @return 位于网格范围内的邻居列表。
static func get_neighbors(
	cell: Vector2i,
	grid_size: Vector2i,
	include_diagonal: bool = false
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_neighbors(cell, grid_size, include_diagonal)


## 获取两个端点之间的矩形格子。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param from_cell: 第一个端点。
## [br]
## @param to_cell: 第二个端点。
## [br]
## @param grid_size: 可选网格尺寸；任一轴小于 0 时不按边界过滤。
## [br]
## @return 矩形内坐标列表，包含两个端点，按 y/x 稳定顺序返回。
static func get_rectangle_cells(
	from_cell: Vector2i,
	to_cell: Vector2i,
	grid_size: Vector2i = Vector2i(-1, -1)
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_rectangle_cells(from_cell, to_cell, grid_size)


## 获取指定半径内的所有格子。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param center: 中心格子。
## [br]
## @param radius: 半径。
## [br]
## @param grid_size: 可选网格尺寸；任一轴小于 0 时不按边界过滤。
## [br]
## @param include_diagonal: 为 false 时使用曼哈顿范围；为 true 时使用切比雪夫范围。
## [br]
## @return 半径内坐标列表，包含中心，按 y/x 稳定顺序返回。
static func get_range(
	center: Vector2i,
	radius: int,
	grid_size: Vector2i = Vector2i(-1, -1),
	include_diagonal: bool = false
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_range(center, radius, grid_size, include_diagonal)


## 获取指定半径的外环格子。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param center: 中心格子。
## [br]
## @param radius: 半径；0 时返回中心。
## [br]
## @param grid_size: 可选网格尺寸；任一轴小于 0 时不按边界过滤。
## [br]
## @param include_diagonal: 为 false 时使用曼哈顿外环；为 true 时使用切比雪夫外环。
## [br]
## @return 外环坐标列表，按 y/x 稳定顺序返回。
static func get_ring(
	center: Vector2i,
	radius: int,
	grid_size: Vector2i = Vector2i(-1, -1),
	include_diagonal: bool = false
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_ring(center, radius, grid_size, include_diagonal)


## 获取中心 chunk 周围的候选窗口。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param center_chunk: 中心 chunk 坐标。
## [br]
## @param radius: chunk 半径；小于 0 时返回空数组。
## [br]
## @param shape: 窗口形状。支持 "circle"/"euclidean"、"square"/"chebyshev"、"diamond"/"manhattan"；未知值按 circle 处理。
## [br]
## @return 候选 chunk 坐标数组，按 y/x 稳定顺序返回。
## [br]
## @schema return: Array[Vector2i]，中心 chunk 周围的候选 chunk 坐标。
static func get_chunk_window(
	center_chunk: Vector2i,
	radius: int,
	shape: StringName = &"circle"
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_chunk_window(center_chunk, radius, shape)


## 计算两个格子集合的稳定差分。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param previous_cells: 旧集合。重复项会被去重，removed 按首次出现顺序返回。
## [br]
## @schema previous_cells: Array[Vector2i]，旧格子集合。
## [br]
## @param next_cells: 新集合。重复项会被去重，added/kept 按首次出现顺序返回。
## [br]
## @schema next_cells: Array[Vector2i]，新格子集合。
## [br]
## @return 差分报告。
## [br]
## @schema return: Dictionary，包含 added: Array[Vector2i]、removed: Array[Vector2i]、kept: Array[Vector2i]、changed: bool、previous_count: int、next_count: int。
static func diff_cells(previous_cells: Array[Vector2i], next_cells: Array[Vector2i]) -> Dictionary:
	return GFGridCoordinateMath2D.diff_cells(previous_cells, next_cells)


## 获取连接两个格子的 Bresenham 直线。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param from_cell: 起点格子。
## [br]
## @param to_cell: 终点格子。
## [br]
## @return 坐标列表，包含起点与终点。
static func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.get_line(from_cell, to_cell)


## 判断两格之间是否有视线。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param from_cell: 起点格子。
## [br]
## @param to_cell: 终点格子。
## [br]
## @param is_blocking: 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param include_endpoints: 是否检查起点与终点是否阻挡。
## [br]
## @return 没有阻挡时返回 true；阻挡回调无效时也返回 true。
static func has_line_of_sight(
	from_cell: Vector2i,
	to_cell: Vector2i,
	is_blocking: Callable,
	include_endpoints: bool = false
) -> bool:
	return GFGridCoordinateMath2D.has_line_of_sight(from_cell, to_cell, is_blocking, include_endpoints)


## 从起点执行泛洪搜索，返回所有满足匹配条件且连通的格子。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param is_match: 匹配回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param include_diagonal: 是否允许斜向连通。
## [br]
## @return 连通格子列表。
static func flood_fill(
	grid_size: Vector2i,
	start: Vector2i,
	is_match: Callable,
	include_diagonal: bool = false
) -> Array[Vector2i]:
	return GFGridCoordinateMath2D.flood_fill(grid_size, start, is_match, include_diagonal)


## 使用回溯生成矩形网格迷宫拓扑。
## [br]
## 该方法只输出开放边与邻接表，不创建 TileMap、墙体节点、房间资源或碰撞体。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start_cell: 起始格子。
## [br]
## @param is_cell_enabled: 可用格回调，签名为 `func(cell: Vector2i) -> bool`；无效时全部格子可用。
## [br]
## @param options: 生成选项。
## [br]
## @schema options: Dictionary supports seed, include_diagonal, and max_cells.
## [br]
## @return 迷宫拓扑报告。
## [br]
## @schema return: Dictionary with ok, error, algorithm, grid_size, start_cell, seed, include_diagonal, cell_count, max_cells, available_count, blocked_count, visited_count, edge_count, complete, edges, and connections.
static func generate_rect_maze_backtracker(
	grid_size: Vector2i,
	start_cell: Vector2i = Vector2i.ZERO,
	is_cell_enabled: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	return GFGridGenerationMath2D.generate_rect_maze_backtracker(
		grid_size,
		start_cell,
		is_cell_enabled,
		options
	)


## 生成二值细胞自动机网格报告。
## [br]
## 该方法只输出布尔格子状态、存活格列表和统计信息，不创建 TileMap、节点、地形、
## 房间、碰撞体或项目资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param is_initial_alive: 可选初始状态回调，签名为 `func(cell: Vector2i) -> bool`；无效时使用 seed 和 alive_chance 随机初始化。
## [br]
## @param options: 生成选项。
## [br]
## @schema options: Dictionary supports seed, alive_chance, iterations, include_diagonal, outside_alive, survive_min, survive_max, birth_min, birth_max, and max_cells.
## [br]
## @return 细胞自动机报告。
## [br]
## @schema return: Dictionary with ok, error, algorithm, grid_size, seed, alive_chance, iterations, include_diagonal, outside_alive, survive_min, survive_max, birth_min, birth_max, cell_count, max_cells, alive_count, dead_count, cells, and alive_cells.
static func generate_cellular_automata_map(
	grid_size: Vector2i,
	is_initial_alive: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	return GFGridGenerationMath2D.generate_cellular_automata_map(
		grid_size,
		is_initial_alive,
		options
	)


## 查找一组二维格子的连通区域。
## [br]
## 该方法只根据格子集合和四/八邻域连通关系输出区域报告，不解释格子的地形、房间、
## 墙体、实体或可通行语义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cells: 待分析格子集合；重复项会被去重。
## [br]
## @schema cells: Array[Vector2i]，待分析格子集合。
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary supports include_diagonal and max_cells.
## [br]
## @return 连通区域报告。
## [br]
## @schema return: Dictionary with ok, error, algorithm, include_diagonal, input_count, cell_count, max_cells, region_count, all_connected, largest_region_index, largest_region_size, regions, and region_indices.
static func find_cell_regions(cells: Array[Vector2i], options: Dictionary = {}) -> Dictionary:
	return GFGridGenerationMath2D.find_cell_regions(cells, options)


## 按连通区域尺寸过滤二维格子集合。
## [br]
## 该方法只输出保留/移除的格子与区域报告，不创建或修改 TileMap、节点和项目资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cells: 待过滤格子集合；重复项会被去重。
## [br]
## @schema cells: Array[Vector2i]，待过滤格子集合。
## [br]
## @param minimum_region_size: 保留区域的最小格子数；0 表示保留全部区域。
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary supports include_diagonal and max_cells.
## [br]
## @return 区域过滤报告。
## [br]
## @schema return: Dictionary with ok, error, algorithm, include_diagonal, minimum_region_size, input_count, cell_count, max_cells, region_count, kept_region_count, removed_region_count, kept_count, removed_count, kept_cells, removed_cells, kept_regions, removed_regions, and region_report.
static func filter_cell_regions_by_size(
	cells: Array[Vector2i],
	minimum_region_size: int,
	options: Dictionary = {}
) -> Dictionary:
	return GFGridGenerationMath2D.filter_cell_regions_by_size(cells, minimum_region_size, options)


## 使用 BFS 查找一条最短路径。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param goal: 终点格子。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param allow_diagonal: 是否允许斜向移动。
## [br]
## @return 包含起点与终点的路径；无法到达时返回空数组。
static func find_path_bfs(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	allow_diagonal: bool = false
) -> Array[Vector2i]:
	return GFGridPathMath2D.find_path_bfs(grid_size, start, goal, is_walkable, allow_diagonal)


## 使用 A* 查找一条低代价路径。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param goal: 终点格子。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param allow_diagonal: 是否允许斜向移动。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @param heuristic: 启发函数名称，支持 `manhattan`、`chebyshev`、`octile`、`euclidean`。
## [br]
## @return 包含起点与终点的路径；无法到达时返回空数组。
static func find_path_a_star(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	allow_diagonal: bool = false,
	step_cost: Callable = Callable(),
	heuristic: StringName = &"manhattan"
) -> Array[Vector2i]:
	return GFGridPathMath2D.find_path_a_star(
		grid_size,
		start,
		goal,
		is_walkable,
		allow_diagonal,
		step_cost,
		heuristic
	)


## 创建可分步推进的 2D 网格 A* 搜索状态。
## [br]
## 状态由 `GFGraphMath.advance_path_search()` 推进；本方法只负责把网格边界、
## 邻居、通行、代价和启发函数适配成通用图搜索回调。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param goal: 终点格子。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param allow_diagonal: 是否允许斜向移动。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @param heuristic: 启发函数名称，支持 `manhattan`、`chebyshev`、`octile`、`euclidean`。
## [br]
## @return `GFGraphMath` 分步路径搜索状态句柄。
## [br]
## @schema return: GFGraphPathSearchState returned by `GFGraphMath.begin_path_search()`.
static func begin_path_a_star_search(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	allow_diagonal: bool = false,
	step_cost: Callable = Callable(),
	heuristic: StringName = &"manhattan"
) -> GFGraphPathSearchState:
	return GFGridPathMath2D.begin_path_a_star_search(
		grid_size,
		start,
		goal,
		is_walkable,
		allow_diagonal,
		step_cost,
		heuristic
	)


## 使用视线检测抽稀 2D 网格路径。
## [br]
## 该方法只移除可由直线视线覆盖的中间格子，保留起点与终点；它不执行单位移动、
## 转向动画或碰撞响应。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 包含起点与终点的格子路径。
## [br]
## @param is_blocking: 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param include_endpoints: 是否检查每段抽稀直线的端点是否阻挡。
## [br]
## @return 抽稀后的路径；空路径仍返回空数组。
## [br]
## @schema path: Array[Vector2i] path cells.
static func simplify_path_line_of_sight(
	path: Array[Vector2i],
	is_blocking: Callable,
	include_endpoints: bool = false
) -> Array[Vector2i]:
	return GFGridPathMath2D.simplify_path_line_of_sight(path, is_blocking, include_endpoints)


## 从一个或多个目标格生成 Flow Field。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param goals: 目标格列表。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param allow_diagonal: 是否允许斜向移动。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @return 包含 `costs`、`directions` 和 `goals` 的字典；`directions[cell]` 是下一步方向。
## [br]
## @schema return: Dictionary with `costs: Dictionary[Vector2i, float]`, `directions: Dictionary[Vector2i, Vector2i]`, and `goals: Array[Vector2i]`.
static func build_flow_field(
	grid_size: Vector2i,
	goals: Array[Vector2i],
	is_walkable: Callable,
	allow_diagonal: bool = false,
	step_cost: Callable = Callable()
) -> Dictionary:
	return GFGridPathMath2D.build_flow_field(
		grid_size,
		goals,
		is_walkable,
		allow_diagonal,
		step_cost
	)


## 判断两个格子是否能在指定转折次数内连通。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param goal: 终点格子。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`；起点与终点可不通行。
## [br]
## @param max_turns: 最大转折次数，连连看常用值为 2。
## [br]
## @param allow_outer_border: 是否允许路径经过网格外一圈虚拟空格。
## [br]
## @return 可连通时返回 true。
static func can_connect_with_max_turns(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	max_turns: int = 2,
	allow_outer_border: bool = true
) -> bool:
	return GFGridConnectionMath2D.can_connect_with_max_turns(
		grid_size,
		start,
		goal,
		is_walkable,
		max_turns,
		allow_outer_border
	)
