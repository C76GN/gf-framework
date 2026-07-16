## GFGridPathMath2D: 2D 网格路径搜索与 Flow Field 工具。
##
## 负责 BFS、A*、分步路径搜索、视线抽稀和 Flow Field 生成。坐标、
## 邻居和视线基础能力由 GFGridCoordinateMath2D 提供。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFGridPathMath2D
extends RefCounted


# --- 公共方法 ---

## 使用 BFS 查找一条最短路径。
## [br]
## @api public
## [br]
## @since 8.0.0
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
		not GFGridCoordinateMath2D.is_in_bounds(start, grid_size)
		or not GFGridCoordinateMath2D.is_in_bounds(goal, grid_size)
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
		for next_cell: Vector2i in GFGridCoordinateMath2D.get_neighbors(cell, grid_size, allow_diagonal):
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
## @since 8.0.0
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
		not GFGridCoordinateMath2D.is_in_bounds(start, grid_size)
		or not GFGridCoordinateMath2D.is_in_bounds(goal, grid_size)
		or not is_walkable.is_valid()
	):
		return []
	if start == goal:
		return [start]
	if not _call_cell_predicate(is_walkable, goal):
		return []

	var open_queue: GFPriorityQueue = GFPriorityQueue.new(false)
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _heuristic_distance(start, goal, heuristic, allow_diagonal) }
	_push_cell_priority(open_queue, start, GFVariantData.get_option_float(f_score, start, INF))

	while not open_queue.is_empty():
		var current_entry: Dictionary = _pop_cell_priority(open_queue)
		var current: Vector2i = _get_dictionary_vector2i(current_entry, "cell", Vector2i(-1, -1))
		if closed.has(current):
			continue
		if GFVariantData.get_option_float(current_entry, "priority", INF) > GFVariantData.get_option_float(f_score, current, INF):
			continue
		if current == goal:
			return _reconstruct_path(start, goal, came_from)

		closed[current] = true
		for next_cell: Vector2i in GFGridCoordinateMath2D.get_neighbors(current, grid_size, allow_diagonal):
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
			_push_cell_priority(open_queue, next_cell, GFVariantData.get_option_float(f_score, next_cell, INF))

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
	if not GFGridCoordinateMath2D.is_in_bounds(start, grid_size) or not GFGridCoordinateMath2D.is_in_bounds(goal, grid_size):
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
			for next_cell: Vector2i in GFGridCoordinateMath2D.get_neighbors(cell, grid_size, allow_diagonal):
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
			if GFGridCoordinateMath2D.has_line_of_sight(path[anchor_index], path[next_index], is_blocking, include_endpoints):
				break
			next_index -= 1

		result.append(path[next_index])
		anchor_index = next_index

	return result


## 从一个或多个目标格生成 Flow Field。
## [br]
## @api public
## [br]
## @since 8.0.0
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

	var frontier: GFPriorityQueue = GFPriorityQueue.new(false)
	for goal: Vector2i in goals:
		if (
			not GFGridCoordinateMath2D.is_in_bounds(goal, grid_size)
			or not _call_cell_predicate(is_walkable, goal)
			or costs.has(goal)
		):
			continue

		costs[goal] = 0.0
		directions[goal] = Vector2i.ZERO
		valid_goals.append(goal)
		_push_cell_priority(frontier, goal, 0.0)

	while not frontier.is_empty():
		var current_entry: Dictionary = _pop_cell_priority(frontier)
		var current: Vector2i = _get_dictionary_vector2i(current_entry, "cell", Vector2i(-1, -1))
		if GFVariantData.get_option_float(current_entry, "priority", INF) > GFVariantData.get_option_float(costs, current, INF):
			continue

		for next_cell: Vector2i in GFGridCoordinateMath2D.get_neighbors(current, grid_size, allow_diagonal):
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
			_push_cell_priority(frontier, next_cell, next_cost)

	return {
		"costs": costs,
		"directions": directions,
		"goals": valid_goals,
	}


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


static func _push_cell_priority(priority_queue: GFPriorityQueue, cell: Vector2i, priority: float) -> void:
	var _cell_queued: bool = priority_queue.push({
		"cell": cell,
		"priority": priority,
	}, priority)


static func _pop_cell_priority(priority_queue: GFPriorityQueue) -> Dictionary:
	return GFVariantData.as_dictionary(priority_queue.pop({}))


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
