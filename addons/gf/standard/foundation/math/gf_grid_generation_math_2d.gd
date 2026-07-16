## GFGridGenerationMath2D: 2D 网格程序生成报告工具。
##
## 提供矩形迷宫拓扑、二值细胞自动机生成和连通区域后处理。它只输出稳定数据报告，
## 不创建 TileMap、节点、碰撞体、房间资源或任何项目业务对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFGridGenerationMath2D
extends RefCounted


# --- 常量 ---

const _ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

const _DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

## 默认矩形迷宫最大格子数，避免误把超大生成任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_MAZE_CELLS: int = 262144

## 默认细胞自动机最大格子数，避免误把超大生成任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS: int = 262144

## 默认连通区域分析最大格子数，避免误把超大生成后处理交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_CELL_REGION_CELLS: int = 262144


# --- 公共方法 ---

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
	var maze_seed: int = GFVariantData.get_option_int(options, "seed", 0)
	var include_diagonal: bool = GFVariantData.get_option_bool(options, "include_diagonal", false)
	var max_cells: int = maxi(
		GFVariantData.get_option_int(options, "max_cells", DEFAULT_MAX_MAZE_CELLS),
		1
	)
	var cell_count: int = grid_size.x * grid_size.y
	if grid_size.x <= 0 or grid_size.y <= 0:
		return _make_rect_maze_failure(grid_size, start_cell, maze_seed, include_diagonal, cell_count, max_cells, "grid_size must be positive.")
	if cell_count > max_cells:
		return _make_rect_maze_failure(grid_size, start_cell, maze_seed, include_diagonal, cell_count, max_cells, "cell_count exceeds max_cells.")
	if not GFGridCoordinateMath2D.is_in_bounds(start_cell, grid_size):
		return _make_rect_maze_failure(grid_size, start_cell, maze_seed, include_diagonal, cell_count, max_cells, "start_cell is outside grid_size.")

	var available_cells: Dictionary = _make_rect_maze_available_cells(grid_size, is_cell_enabled)
	var available_count: int = available_cells.size()
	var blocked_count: int = cell_count - available_count
	if not available_cells.has(start_cell):
		return _make_rect_maze_failure_with_counts(
			grid_size,
			start_cell,
			maze_seed,
			include_diagonal,
			cell_count,
			max_cells,
			available_count,
			blocked_count,
			"start_cell is not enabled."
		)

	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(maze_seed)
	var stack: Array[Vector2i] = [start_cell]
	var visited: Dictionary = { start_cell: true }
	var edges: Array[Dictionary] = []
	var connections: Dictionary = { start_cell: [] }

	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var candidates: Array[Vector2i] = _get_rect_maze_unvisited_neighbors(
			current,
			grid_size,
			include_diagonal,
			available_cells,
			visited
		)
		if candidates.is_empty():
			stack.remove_at(stack.size() - 1)
			continue

		var next_cell: Vector2i = candidates[rng.next_int_range(0, candidates.size() - 1)]
		visited[next_cell] = true
		stack.append(next_cell)
		edges.append({
			"from": current,
			"to": next_cell,
			"direction": next_cell - current,
		})
		_append_rect_maze_connection(connections, current, next_cell)
		_append_rect_maze_connection(connections, next_cell, current)

	return {
		"ok": true,
		"error": "",
		"algorithm": &"backtracker",
		"grid_size": grid_size,
		"start_cell": start_cell,
		"seed": maze_seed,
		"include_diagonal": include_diagonal,
		"cell_count": cell_count,
		"max_cells": max_cells,
		"available_count": available_count,
		"blocked_count": blocked_count,
		"visited_count": visited.size(),
		"edge_count": edges.size(),
		"complete": visited.size() == available_count,
		"edges": edges,
		"connections": connections,
	}


## 生成二值细胞自动机网格报告。
## [br]
## 该方法只输出布尔格子状态、存活格列表和统计信息，不创建 TileMap、节点、地形、
## 房间、碰撞体或项目资源。默认规则使用常见八邻域洞穴平滑：存活格在相邻存活数
## 大于等于 4 时保留，死亡格在相邻存活数大于等于 5 时生成。
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
	var automata_seed: int = GFVariantData.get_option_int(options, "seed", 0)
	var requested_alive_chance: float = GFVariantData.get_option_float(options, "alive_chance", 0.45)
	var alive_chance: float = 0.45
	var iterations: int = maxi(GFVariantData.get_option_int(options, "iterations", 4), 0)
	var include_diagonal: bool = GFVariantData.get_option_bool(options, "include_diagonal", true)
	var outside_alive: bool = GFVariantData.get_option_bool(options, "outside_alive", true)
	var max_cells: int = maxi(
		GFVariantData.get_option_int(options, "max_cells", DEFAULT_MAX_CELLULAR_AUTOMATA_CELLS),
		1
	)
	var cell_count: int = grid_size.x * grid_size.y
	if is_nan(requested_alive_chance) or is_inf(requested_alive_chance):
		return _make_cellular_automata_failure(
			grid_size,
			automata_seed,
			alive_chance,
			iterations,
			include_diagonal,
			outside_alive,
			cell_count,
			max_cells,
			"alive_chance must be finite."
		)
	alive_chance = clampf(requested_alive_chance, 0.0, 1.0)
	if grid_size.x <= 0 or grid_size.y <= 0:
		return _make_cellular_automata_failure(
			grid_size,
			automata_seed,
			alive_chance,
			iterations,
			include_diagonal,
			outside_alive,
			cell_count,
			max_cells,
			"grid_size must be positive."
		)
	if cell_count > max_cells:
		return _make_cellular_automata_failure(
			grid_size,
			automata_seed,
			alive_chance,
			iterations,
			include_diagonal,
			outside_alive,
			cell_count,
			max_cells,
			"cell_count exceeds max_cells."
		)

	var max_neighbor_count: int = 8 if include_diagonal else 4
	var survive_min: int = GFVariantData.get_option_int(options, "survive_min", 4)
	var survive_max: int = GFVariantData.get_option_int(options, "survive_max", max_neighbor_count)
	var birth_min: int = GFVariantData.get_option_int(options, "birth_min", 5 if include_diagonal else 3)
	var birth_max: int = GFVariantData.get_option_int(options, "birth_max", max_neighbor_count)
	var rule_error: String = _validate_cellular_automata_rules(
		survive_min,
		survive_max,
		birth_min,
		birth_max,
		max_neighbor_count
	)
	if not rule_error.is_empty():
		return _make_cellular_automata_failure(
			grid_size,
			automata_seed,
			alive_chance,
			iterations,
			include_diagonal,
			outside_alive,
			cell_count,
			max_cells,
			rule_error,
			survive_min,
			survive_max,
			birth_min,
			birth_max
		)

	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(automata_seed)
	var cells: Dictionary = _make_cellular_automata_initial_cells(
		grid_size,
		is_initial_alive,
		rng,
		alive_chance
	)
	var directions: Array[Vector2i] = _get_cellular_automata_directions(include_diagonal)
	for _iteration_index: int in range(iterations):
		cells = _step_cellular_automata_cells(
			cells,
			grid_size,
			directions,
			outside_alive,
			survive_min,
			survive_max,
			birth_min,
			birth_max
		)

	return _make_cellular_automata_success(
		cells,
		grid_size,
		automata_seed,
		alive_chance,
		iterations,
		include_diagonal,
		outside_alive,
		cell_count,
		max_cells,
		survive_min,
		survive_max,
		birth_min,
		birth_max
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
	var include_diagonal: bool = GFVariantData.get_option_bool(options, "include_diagonal", false)
	var max_cells: int = maxi(
		GFVariantData.get_option_int(options, "max_cells", DEFAULT_MAX_CELL_REGION_CELLS),
		1
	)
	if cells.size() > max_cells:
		return _make_cell_region_failure(
			include_diagonal,
			cells.size(),
			0,
			max_cells,
			"input_count exceeds max_cells."
		)

	var unique_cells: Array[Vector2i] = _make_unique_sorted_cells(cells)
	if unique_cells.size() > max_cells:
		return _make_cell_region_failure(
			include_diagonal,
			cells.size(),
			unique_cells.size(),
			max_cells,
			"cell_count exceeds max_cells."
		)

	var cell_set: Dictionary = _make_vector2i_set(unique_cells)
	var visited: Dictionary = {}
	var regions: Array = []
	var region_indices: Dictionary = {}
	var directions: Array[Vector2i] = _get_cell_region_directions(include_diagonal)
	var largest_region_index: int = -1
	var largest_region_size: int = 0

	for start_cell: Vector2i in unique_cells:
		if visited.has(start_cell):
			continue

		var region: Array[Vector2i] = _collect_cell_region(start_cell, cell_set, visited, directions)
		region.sort_custom(_sort_cells_yx)
		var region_index: int = regions.size()
		for cell: Vector2i in region:
			region_indices[cell] = region_index
		if region.size() > largest_region_size:
			largest_region_size = region.size()
			largest_region_index = region_index
		regions.append(region)

	return {
		"ok": true,
		"error": "",
		"algorithm": &"cell_regions",
		"include_diagonal": include_diagonal,
		"input_count": cells.size(),
		"cell_count": unique_cells.size(),
		"max_cells": max_cells,
		"region_count": regions.size(),
		"all_connected": regions.size() <= 1,
		"largest_region_index": largest_region_index,
		"largest_region_size": largest_region_size,
		"regions": regions,
		"region_indices": region_indices,
	}


## 按连通区域尺寸过滤二维格子集合。
## [br]
## 该方法适合在细胞自动机、噪声阈值、候选散布或编辑器批处理后剔除小孤岛。
## 它只输出保留/移除的格子与区域报告，不创建或修改 TileMap、节点和项目资源。
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
	var include_diagonal: bool = GFVariantData.get_option_bool(options, "include_diagonal", false)
	var max_cells: int = maxi(
		GFVariantData.get_option_int(options, "max_cells", DEFAULT_MAX_CELL_REGION_CELLS),
		1
	)
	if minimum_region_size < 0:
		return _make_cell_region_filter_failure(
			include_diagonal,
			minimum_region_size,
			cells.size(),
			0,
			max_cells,
			"minimum_region_size must be non-negative."
		)

	var region_report: Dictionary = find_cell_regions(cells, {
		"include_diagonal": include_diagonal,
		"max_cells": max_cells,
	})
	if not GFVariantData.get_option_bool(region_report, "ok"):
		return _make_cell_region_filter_failure(
			include_diagonal,
			minimum_region_size,
			cells.size(),
			GFVariantData.get_option_int(region_report, "cell_count"),
			max_cells,
			GFVariantData.get_option_string(region_report, "error")
		)

	var kept_cells: Array[Vector2i] = []
	var removed_cells: Array[Vector2i] = []
	var kept_regions: Array = []
	var removed_regions: Array = []
	for region_value: Variant in GFVariantData.get_option_array(region_report, "regions"):
		var region: Array = GFVariantData.as_array(region_value)
		if region.size() >= minimum_region_size:
			kept_regions.append(region)
			_append_vector2i_values(kept_cells, region)
		else:
			removed_regions.append(region)
			_append_vector2i_values(removed_cells, region)

	return {
		"ok": true,
		"error": "",
		"algorithm": &"cell_region_filter",
		"include_diagonal": include_diagonal,
		"minimum_region_size": minimum_region_size,
		"input_count": cells.size(),
		"cell_count": GFVariantData.get_option_int(region_report, "cell_count"),
		"max_cells": max_cells,
		"region_count": GFVariantData.get_option_int(region_report, "region_count"),
		"kept_region_count": kept_regions.size(),
		"removed_region_count": removed_regions.size(),
		"kept_count": kept_cells.size(),
		"removed_count": removed_cells.size(),
		"kept_cells": kept_cells,
		"removed_cells": removed_cells,
		"kept_regions": kept_regions,
		"removed_regions": removed_regions,
		"region_report": region_report,
	}


# --- 私有/辅助方法 ---

static func _call_cell_predicate(predicate: Callable, cell: Vector2i, fallback: bool = false) -> bool:
	if not predicate.is_valid():
		return fallback
	return GFVariantData.to_bool(predicate.call(cell), fallback)


static func _make_rect_maze_available_cells(grid_size: Vector2i, is_cell_enabled: Callable) -> Dictionary:
	var result: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _call_cell_predicate(is_cell_enabled, cell, true):
				result[cell] = true
	return result


static func _get_rect_maze_unvisited_neighbors(
	cell: Vector2i,
	grid_size: Vector2i,
	include_diagonal: bool,
	available_cells: Dictionary,
	visited: Dictionary
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for next_cell: Vector2i in GFGridCoordinateMath2D.get_neighbors(cell, grid_size, include_diagonal):
		if available_cells.has(next_cell) and not visited.has(next_cell):
			result.append(next_cell)
	return result


static func _append_rect_maze_connection(connections: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var neighbors: Array = []
	var value: Variant = GFVariantData.get_option_value(connections, from_cell)
	if value is Array:
		neighbors = value
	neighbors.append(to_cell)
	connections[from_cell] = neighbors


static func _make_rect_maze_failure(
	grid_size: Vector2i,
	start_cell: Vector2i,
	maze_seed: int,
	include_diagonal: bool,
	cell_count: int,
	max_cells: int,
	error: String
) -> Dictionary:
	return _make_rect_maze_failure_with_counts(
		grid_size,
		start_cell,
		maze_seed,
		include_diagonal,
		cell_count,
		max_cells,
		0,
		maxi(cell_count, 0),
		error
	)


static func _make_rect_maze_failure_with_counts(
	grid_size: Vector2i,
	start_cell: Vector2i,
	maze_seed: int,
	include_diagonal: bool,
	cell_count: int,
	max_cells: int,
	available_count: int,
	blocked_count: int,
	error: String
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"algorithm": &"backtracker",
		"grid_size": grid_size,
		"start_cell": start_cell,
		"seed": maze_seed,
		"include_diagonal": include_diagonal,
		"cell_count": maxi(cell_count, 0),
		"max_cells": max_cells,
		"available_count": available_count,
		"blocked_count": blocked_count,
		"visited_count": 0,
		"edge_count": 0,
		"complete": false,
		"edges": [],
		"connections": {},
	}


static func _make_cellular_automata_initial_cells(
	grid_size: Vector2i,
	is_initial_alive: Callable,
	rng: GFDeterministicRandom,
	alive_chance: float
) -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if is_initial_alive.is_valid():
				cells[cell] = _call_cell_predicate(is_initial_alive, cell)
			else:
				cells[cell] = rng.next_float_unit() < alive_chance
	return cells


static func _step_cellular_automata_cells(
	cells: Dictionary,
	grid_size: Vector2i,
	directions: Array[Vector2i],
	outside_alive: bool,
	survive_min: int,
	survive_max: int,
	birth_min: int,
	birth_max: int
) -> Dictionary:
	var next_cells: Dictionary = {}
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var alive_neighbors: int = _count_cellular_automata_alive_neighbors(
				cell,
				grid_size,
				cells,
				directions,
				outside_alive
			)
			var is_alive: bool = GFVariantData.get_option_bool(cells, cell, false)
			if is_alive:
				next_cells[cell] = alive_neighbors >= survive_min and alive_neighbors <= survive_max
			else:
				next_cells[cell] = alive_neighbors >= birth_min and alive_neighbors <= birth_max
	return next_cells


static func _count_cellular_automata_alive_neighbors(
	cell: Vector2i,
	grid_size: Vector2i,
	cells: Dictionary,
	directions: Array[Vector2i],
	outside_alive: bool
) -> int:
	var count: int = 0
	for direction: Vector2i in directions:
		var next_cell: Vector2i = cell + direction
		if not GFGridCoordinateMath2D.is_in_bounds(next_cell, grid_size):
			if outside_alive:
				count += 1
			continue
		if GFVariantData.get_option_bool(cells, next_cell, false):
			count += 1
	return count


static func _get_cellular_automata_directions(include_diagonal: bool) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	directions.append_array(_ORTHOGONAL_DIRECTIONS)
	if include_diagonal:
		directions.append_array(_DIAGONAL_DIRECTIONS)
	return directions


static func _get_cell_region_directions(include_diagonal: bool) -> Array[Vector2i]:
	return _get_cellular_automata_directions(include_diagonal)


static func _make_unique_sorted_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		result.append(cell)
	result.sort_custom(_sort_cells_yx)
	return result


static func _make_vector2i_set(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		result[cell] = true
	return result


static func _collect_cell_region(
	start_cell: Vector2i,
	cell_set: Dictionary,
	visited: Dictionary,
	directions: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_cell]
	var queue_index: int = 0
	visited[start_cell] = true

	while queue_index < queue.size():
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		result.append(cell)

		for direction: Vector2i in directions:
			var next_cell: Vector2i = cell + direction
			if visited.has(next_cell) or not cell_set.has(next_cell):
				continue
			visited[next_cell] = true
			queue.append(next_cell)

	return result


static func _append_vector2i_values(target: Array[Vector2i], values: Array) -> void:
	for value: Variant in values:
		if value is Vector2i:
			var cell: Vector2i = value
			target.append(cell)


static func _sort_cells_yx(left: Vector2i, right: Vector2i) -> bool:
	if left.y == right.y:
		return left.x < right.x
	return left.y < right.y


static func _validate_cellular_automata_rules(
	survive_min: int,
	survive_max: int,
	birth_min: int,
	birth_max: int,
	max_neighbor_count: int
) -> String:
	if survive_min < 0 or birth_min < 0:
		return "rule minimums must be non-negative."
	if survive_max < survive_min:
		return "survive_max must be greater than or equal to survive_min."
	if birth_max < birth_min:
		return "birth_max must be greater than or equal to birth_min."
	if survive_max > max_neighbor_count or birth_max > max_neighbor_count:
		return "rule maximums exceed neighbor count."
	return ""


static func _make_cellular_automata_success(
	cells: Dictionary,
	grid_size: Vector2i,
	automata_seed: int,
	alive_chance: float,
	iterations: int,
	include_diagonal: bool,
	outside_alive: bool,
	cell_count: int,
	max_cells: int,
	survive_min: int,
	survive_max: int,
	birth_min: int,
	birth_max: int
) -> Dictionary:
	var alive_cells: Array[Vector2i] = []
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if GFVariantData.get_option_bool(cells, cell, false):
				alive_cells.append(cell)

	return {
		"ok": true,
		"error": "",
		"algorithm": &"cellular_automata",
		"grid_size": grid_size,
		"seed": automata_seed,
		"alive_chance": alive_chance,
		"iterations": iterations,
		"include_diagonal": include_diagonal,
		"outside_alive": outside_alive,
		"survive_min": survive_min,
		"survive_max": survive_max,
		"birth_min": birth_min,
		"birth_max": birth_max,
		"cell_count": cell_count,
		"max_cells": max_cells,
		"alive_count": alive_cells.size(),
		"dead_count": cell_count - alive_cells.size(),
		"cells": cells,
		"alive_cells": alive_cells,
	}


static func _make_cell_region_failure(
	include_diagonal: bool,
	input_count: int,
	cell_count: int,
	max_cells: int,
	error: String
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"algorithm": &"cell_regions",
		"include_diagonal": include_diagonal,
		"input_count": input_count,
		"cell_count": cell_count,
		"max_cells": max_cells,
		"region_count": 0,
		"all_connected": false,
		"largest_region_index": -1,
		"largest_region_size": 0,
		"regions": [],
		"region_indices": {},
	}


static func _make_cell_region_filter_failure(
	include_diagonal: bool,
	minimum_region_size: int,
	input_count: int,
	cell_count: int,
	max_cells: int,
	error: String
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"algorithm": &"cell_region_filter",
		"include_diagonal": include_diagonal,
		"minimum_region_size": minimum_region_size,
		"input_count": input_count,
		"cell_count": cell_count,
		"max_cells": max_cells,
		"region_count": 0,
		"kept_region_count": 0,
		"removed_region_count": 0,
		"kept_count": 0,
		"removed_count": 0,
		"kept_cells": [],
		"removed_cells": [],
		"kept_regions": [],
		"removed_regions": [],
		"region_report": {},
	}


static func _make_cellular_automata_failure(
	grid_size: Vector2i,
	automata_seed: int,
	alive_chance: float,
	iterations: int,
	include_diagonal: bool,
	outside_alive: bool,
	cell_count: int,
	max_cells: int,
	error: String,
	survive_min: int = 0,
	survive_max: int = 0,
	birth_min: int = 0,
	birth_max: int = 0
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"algorithm": &"cellular_automata",
		"grid_size": grid_size,
		"seed": automata_seed,
		"alive_chance": alive_chance,
		"iterations": iterations,
		"include_diagonal": include_diagonal,
		"outside_alive": outside_alive,
		"survive_min": survive_min,
		"survive_max": survive_max,
		"birth_min": birth_min,
		"birth_max": birth_max,
		"cell_count": maxi(cell_count, 0),
		"max_cells": max_cells,
		"alive_count": 0,
		"dead_count": 0,
		"cells": {},
		"alive_cells": [],
	}
