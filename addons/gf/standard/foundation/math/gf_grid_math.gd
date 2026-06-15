## GFGridMath: 网格类小游戏的纯算法工具。
##
## 提供一维索引与二维格坐标转换、邻居枚举、范围、外环、直线、视线、
## 泛洪搜索、BFS / A* 路径查找、Flow Field 生成以及连连看类“两折连线”判断。
## 它不依赖 GFArchitecture，可直接在 Model、System、Controller 或测试中静态调用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGridMath
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


# --- 公共方法 ---

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
	if width <= 0:
		return -1

	return cell.y * width + cell.x


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
	if index < 0 or width <= 0:
		return Vector2i(-1, -1)

	return Vector2i(index % width, floori(float(index) / float(width)))


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
	return (
		grid_size.x > 0
		and grid_size.y > 0
		and cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


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
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = []
	directions.append_array(_ORTHOGONAL_DIRECTIONS)
	if include_diagonal:
		directions.append_array(_DIAGONAL_DIRECTIONS)

	for direction: Vector2i in directions:
		var next_cell: Vector2i = cell + direction
		if is_in_bounds(next_cell, grid_size):
			result.append(next_cell)

	return result


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
	var result: Array[Vector2i] = []
	var min_x: int = mini(from_cell.x, to_cell.x)
	var max_x: int = maxi(from_cell.x, to_cell.x)
	var min_y: int = mini(from_cell.y, to_cell.y)
	var max_y: int = maxi(from_cell.y, to_cell.y)

	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_in_optional_bounds(cell, grid_size):
				result.append(cell)
	return result


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
	var result: Array[Vector2i] = []
	if radius < 0:
		return result

	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_in_optional_bounds(cell, grid_size):
				continue
			if _get_grid_distance(center, cell, include_diagonal) <= radius:
				result.append(cell)
	return result


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
	var result: Array[Vector2i] = []
	if radius < 0:
		return result

	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_in_optional_bounds(cell, grid_size):
				continue
			if _get_grid_distance(center, cell, include_diagonal) == radius:
				result.append(cell)
	return result


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
	var result: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy

	while true:
		result.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break

		var doubled_error: int = error * 2
		if doubled_error >= dy:
			error += dy
			x0 += sx
		if doubled_error <= dx:
			error += dx
			y0 += sy
	return result


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
	if not is_blocking.is_valid():
		return true

	var line: Array[Vector2i] = get_line(from_cell, to_cell)
	for index: int in range(line.size()):
		if not include_endpoints and (index == 0 or index == line.size() - 1):
			continue
		if _call_cell_predicate(is_blocking, line[index]):
			return false
	return true


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
	if not is_in_bounds(start, grid_size) or not is_match.is_valid():
		return []
	if not _call_cell_predicate(is_match, start):
		return []

	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var queue_index: int = 0
	var visited: Dictionary = { start: true }

	while queue_index < queue.size():
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		result.append(cell)

		for next_cell: Vector2i in get_neighbors(cell, grid_size, include_diagonal):
			if visited.has(next_cell):
				continue
			visited[next_cell] = true

			if _call_cell_predicate(is_match, next_cell):
				queue.append(next_cell)

	return result


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
	if (
		not is_in_bounds(start, grid_size)
		or not is_in_bounds(goal, grid_size)
		or not is_walkable.is_valid()
	):
		return []
	if start == goal:
		return [start]
	if not _call_cell_predicate(is_walkable, goal):
		return []

	var queue: Array[Vector2i] = [start]
	var queue_index: int = 0
	var visited: Dictionary = { start: true }
	var came_from: Dictionary = {}

	while queue_index < queue.size():
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		for next_cell: Vector2i in get_neighbors(cell, grid_size, allow_diagonal):
			if visited.has(next_cell) or not _call_cell_predicate(is_walkable, next_cell):
				continue

			visited[next_cell] = true
			came_from[next_cell] = cell

			if next_cell == goal:
				return _reconstruct_path(start, goal, came_from)

			queue.append(next_cell)

	return []


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
	if (
		not is_in_bounds(start, grid_size)
		or not is_in_bounds(goal, grid_size)
		or not is_walkable.is_valid()
	):
		return []
	if start == goal:
		return [start]
	if not _call_cell_predicate(is_walkable, goal):
		return []

	var open_heap: Array[Dictionary] = []
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _heuristic_distance(start, goal, heuristic, allow_diagonal) }
	_heap_push_cell(open_heap, start, GFVariantData.get_option_float(f_score, start, INF))

	while not open_heap.is_empty():
		var current_entry: Dictionary = _heap_pop_cell(open_heap)
		var current: Vector2i = _get_dictionary_vector2i(current_entry, "cell", Vector2i(-1, -1))
		if closed.has(current):
			continue
		if GFVariantData.get_option_float(current_entry, "priority", INF) > GFVariantData.get_option_float(f_score, current, INF):
			continue
		if current == goal:
			return _reconstruct_path(start, goal, came_from)

		closed[current] = true
		for next_cell: Vector2i in get_neighbors(current, grid_size, allow_diagonal):
			if closed.has(next_cell) or not _call_cell_predicate(is_walkable, next_cell):
				continue

			var move_cost: float = _get_step_cost(current, next_cell, step_cost)
			if move_cost < 0.0:
				continue

			var tentative_score: float = GFVariantData.get_option_float(g_score, current, INF) + move_cost
			if tentative_score >= GFVariantData.get_option_float(g_score, next_cell, INF):
				continue

			came_from[next_cell] = current
			g_score[next_cell] = tentative_score
			f_score[next_cell] = tentative_score + _heuristic_distance(next_cell, goal, heuristic, allow_diagonal)
			_heap_push_cell(open_heap, next_cell, GFVariantData.get_option_float(f_score, next_cell, INF))

	return []


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
	if not is_walkable.is_valid():
		return _make_invalid_path_search(start, goal, &"invalid_walkable")
	if not is_in_bounds(start, grid_size) or not is_in_bounds(goal, grid_size):
		return _make_invalid_path_search(start, goal, &"invalid_bounds")
	if start == goal:
		return GFGraphMath.begin_path_search(
			start,
			goal,
			func(_node: Variant) -> Array:
				return []
		)
	if not _call_cell_predicate(is_walkable, goal):
		return _make_invalid_path_search(start, goal, &"blocked_goal")

	return GFGraphMath.begin_path_search(
		start,
		goal,
		func(node: Variant) -> Array:
			var cell: Vector2i = _variant_to_vector2i(node)
			var result: Array = []
			for next_cell: Vector2i in get_neighbors(cell, grid_size, allow_diagonal):
				if _call_cell_predicate(is_walkable, next_cell):
					result.append(next_cell)
			return result,
		func(from_node: Variant, to_node: Variant) -> float:
			return _get_step_cost(
				_variant_to_vector2i(from_node),
				_variant_to_vector2i(to_node),
				step_cost
			),
		func(node: Variant, goal_node: Variant) -> float:
			return _heuristic_distance(
				_variant_to_vector2i(node),
				_variant_to_vector2i(goal_node),
				heuristic,
				allow_diagonal
			)
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
	var result: Array[Vector2i] = []
	if path.is_empty():
		return result
	if path.size() <= 2:
		result.append_array(path)
		return result

	var anchor_index: int = 0
	result.append(path[anchor_index])
	while anchor_index < path.size() - 1:
		var next_index: int = path.size() - 1
		while next_index > anchor_index + 1:
			if has_line_of_sight(path[anchor_index], path[next_index], is_blocking, include_endpoints):
				break
			next_index -= 1

		result.append(path[next_index])
		anchor_index = next_index

	return result


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
	var costs: Dictionary = {}
	var directions: Dictionary = {}
	var valid_goals: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0 or not is_walkable.is_valid():
		return {
			"costs": costs,
			"directions": directions,
			"goals": valid_goals,
		}

	var frontier: Array[Dictionary] = []
	for goal: Vector2i in goals:
		if not is_in_bounds(goal, grid_size) or not _call_cell_predicate(is_walkable, goal) or costs.has(goal):
			continue

		costs[goal] = 0.0
		directions[goal] = Vector2i.ZERO
		valid_goals.append(goal)
		_heap_push_cell(frontier, goal, 0.0)

	while not frontier.is_empty():
		var current_entry: Dictionary = _heap_pop_cell(frontier)
		var current: Vector2i = _get_dictionary_vector2i(current_entry, "cell", Vector2i(-1, -1))
		if GFVariantData.get_option_float(current_entry, "priority", INF) > GFVariantData.get_option_float(costs, current, INF):
			continue

		for next_cell: Vector2i in get_neighbors(current, grid_size, allow_diagonal):
			if not _call_cell_predicate(is_walkable, next_cell):
				continue

			var move_cost: float = _get_step_cost(next_cell, current, step_cost)
			if move_cost < 0.0:
				continue

			var next_cost: float = GFVariantData.get_option_float(costs, current, INF) + move_cost
			if next_cost >= GFVariantData.get_option_float(costs, next_cell, INF):
				continue

			costs[next_cell] = next_cost
			directions[next_cell] = current - next_cell
			_heap_push_cell(frontier, next_cell, next_cost)

	return {
		"costs": costs,
		"directions": directions,
		"goals": valid_goals,
	}


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
	if (
		start == goal
		or max_turns < 0
		or not is_walkable.is_valid()
		or not is_in_bounds(start, grid_size)
		or not is_in_bounds(goal, grid_size)
	):
		return false

	var queue: Array[Dictionary] = []
	var queue_index: int = 0
	var visited: Dictionary = {}
	for direction_index: int in range(_ORTHOGONAL_DIRECTIONS.size()):
		var direction: Vector2i = _ORTHOGONAL_DIRECTIONS[direction_index]
		var next_cell: Vector2i = start + direction
		if not _can_step_connector(next_cell, goal, grid_size, is_walkable, allow_outer_border):
			continue

		queue.append({
			"cell": next_cell,
			"direction_index": direction_index,
			"turns": 0,
		})
		visited[_make_connector_key(next_cell, direction_index)] = 0

	while queue_index < queue.size():
		var state: Dictionary = queue[queue_index]
		queue_index += 1
		var cell: Vector2i = _get_dictionary_vector2i(state, "cell", Vector2i(-1, -1))
		var direction_index: int = GFVariantData.get_option_int(state, "direction_index", -1)
		var turns: int = GFVariantData.get_option_int(state, "turns", max_turns + 1)

		if cell == goal and turns <= max_turns:
			return true

		for next_direction_index: int in range(_ORTHOGONAL_DIRECTIONS.size()):
			var next_turns: int = turns
			if next_direction_index != direction_index:
				next_turns += 1
			if next_turns > max_turns:
				continue

			var next_cell: Vector2i = cell + _ORTHOGONAL_DIRECTIONS[next_direction_index]
			if not _can_step_connector(next_cell, goal, grid_size, is_walkable, allow_outer_border):
				continue

			var key: Vector3i = _make_connector_key(next_cell, next_direction_index)
			if visited.has(key) and GFVariantData.get_option_int(visited, key, max_turns + 1) <= next_turns:
				continue

			visited[key] = next_turns
			queue.append({
				"cell": next_cell,
				"direction_index": next_direction_index,
				"turns": next_turns,
			})

	return false


# --- 私有/辅助方法 ---

static func _reconstruct_path(start: Vector2i, goal: Vector2i, came_from: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current: Vector2i = goal

	while current != start:
		if not came_from.has(current):
			return []

		current = _get_dictionary_vector2i(came_from, current, Vector2i(-1, -1))
		path.push_front(current)

	return path


static func _is_in_optional_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	if grid_size.x < 0 or grid_size.y < 0:
		return true
	return is_in_bounds(cell, grid_size)


static func _get_grid_distance(from_cell: Vector2i, to_cell: Vector2i, include_diagonal: bool) -> int:
	var dx: int = absi(to_cell.x - from_cell.x)
	var dy: int = absi(to_cell.y - from_cell.y)
	return maxi(dx, dy) if include_diagonal else dx + dy


static func _take_lowest_score_cell(cells: Array[Vector2i], scores: Dictionary) -> Vector2i:
	var best_index: int = 0
	var best_score: float = GFVariantData.get_option_float(scores, cells[0], INF)
	for index: int in range(1, cells.size()):
		var score: float = GFVariantData.get_option_float(scores, cells[index], INF)
		if score < best_score:
			best_index = index
			best_score = score

	var cell: Vector2i = cells[best_index]
	cells.remove_at(best_index)
	return cell


static func _heap_push_cell(heap: Array[Dictionary], cell: Vector2i, priority: float) -> void:
	heap.append({
		"cell": cell,
		"priority": priority,
	})
	var index: int = heap.size() - 1
	while index > 0:
		var parent_index: int = (index - 1) >> 1
		if _get_heap_entry_priority(heap, parent_index) <= priority:
			break
		var parent_entry: Dictionary = _get_heap_entry(heap, parent_index)
		heap[parent_index] = heap[index]
		heap[index] = parent_entry
		index = parent_index


static func _heap_pop_cell(heap: Array[Dictionary]) -> Dictionary:
	if heap.is_empty():
		return {}

	var result: Dictionary = _get_heap_entry(heap, 0)
	var last_entry: Dictionary = _pop_heap_entry(heap)
	if heap.is_empty():
		return result

	heap[0] = last_entry
	var index: int = 0
	while true:
		var left_index: int = index * 2 + 1
		var right_index: int = left_index + 1
		var best_index: int = index
		if (
			left_index < heap.size()
			and _get_heap_entry_priority(heap, left_index) < _get_heap_entry_priority(heap, best_index)
		):
			best_index = left_index
		if (
			right_index < heap.size()
			and _get_heap_entry_priority(heap, right_index) < _get_heap_entry_priority(heap, best_index)
		):
			best_index = right_index
		if best_index == index:
			break

		var best_entry: Dictionary = _get_heap_entry(heap, best_index)
		heap[best_index] = heap[index]
		heap[index] = best_entry
		index = best_index
	return result


static func _heuristic_distance(
	from_cell: Vector2i,
	to_cell: Vector2i,
	heuristic: StringName,
	allow_diagonal: bool
) -> float:
	var dx: int = absi(to_cell.x - from_cell.x)
	var dy: int = absi(to_cell.y - from_cell.y)
	match heuristic:
		&"chebyshev":
			return float(maxi(dx, dy))
		&"octile":
			var diagonal: int = mini(dx, dy)
			var straight: int = maxi(dx, dy) - diagonal
			return float(straight) + float(diagonal) * 1.41421356237
		&"euclidean":
			return sqrt(float(dx * dx + dy * dy))
		_:
			return float(maxi(dx, dy)) if allow_diagonal and heuristic == &"auto" else float(dx + dy)


static func _get_step_cost(from_cell: Vector2i, to_cell: Vector2i, step_cost: Callable) -> float:
	if step_cost.is_valid():
		return GFVariantData.to_float(step_cost.call(from_cell, to_cell), -1.0)

	var delta: Vector2i = to_cell - from_cell
	return 1.41421356237 if absi(delta.x) == 1 and absi(delta.y) == 1 else 1.0


static func _can_step_connector(
	cell: Vector2i,
	goal: Vector2i,
	grid_size: Vector2i,
	is_walkable: Callable,
	allow_outer_border: bool
) -> bool:
	if cell == goal:
		return true

	if is_in_bounds(cell, grid_size):
		return _call_cell_predicate(is_walkable, cell)

	if not allow_outer_border:
		return false

	return (
		cell.x >= -1
		and cell.y >= -1
		and cell.x <= grid_size.x
		and cell.y <= grid_size.y
	)


static func _call_cell_predicate(predicate: Callable, cell: Vector2i, fallback: bool = false) -> bool:
	if not predicate.is_valid():
		return fallback
	return GFVariantData.to_bool(predicate.call(cell), fallback)


static func _get_dictionary_vector2i(dictionary: Dictionary, key: Variant, fallback: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(dictionary, key, fallback)
	if value is Vector2i:
		var cell_value: Vector2i = value
		return cell_value
	return fallback


static func _variant_to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i(-1, -1)


static func _make_invalid_path_search(
	start: Variant,
	goal: Variant,
	reason: StringName
) -> GFGraphPathSearchState:
	return GFGraphPathSearchState.make_invalid(start, goal, reason)


static func _get_heap_entry(heap: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= heap.size():
		return {}
	var value: Variant = heap[index]
	if value is Dictionary:
		var entry: Dictionary = value
		return entry
	return {}


static func _pop_heap_entry(heap: Array[Dictionary]) -> Dictionary:
	if heap.is_empty():
		return {}
	var value: Variant = heap.pop_back()
	if value is Dictionary:
		var entry: Dictionary = value
		return entry
	return {}


static func _get_heap_entry_priority(heap: Array[Dictionary], index: int) -> float:
	return GFVariantData.get_option_float(_get_heap_entry(heap, index), "priority", INF)


static func _make_connector_key(cell: Vector2i, direction_index: int) -> Vector3i:
	return Vector3i(cell.x, cell.y, direction_index)
