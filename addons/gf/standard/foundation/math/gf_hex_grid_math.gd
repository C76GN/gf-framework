## GFHexGridMath: 六边形网格的纯算法工具。
##
## 提供 offset / cube 坐标转换、邻居枚举、距离、范围、环、直线、视线、
## A* 路径查找和 Flow Field 生成。它不依赖 GFArchitecture，可直接在
## Model、System、Controller 或测试中静态调用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFHexGridMath
extends RefCounted


# --- 枚举 ---

## Offset 坐标布局。
## [br]
## @api public
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

## 像素坐标换算时使用的六边形朝向。
## [br]
## @api public
enum HexOrientation {
	## 尖顶朝上。
	POINTY_TOP,
	## 平顶朝上。
	FLAT_TOP,
}


# --- 常量 ---

## 根号 3 的缓存值，用于六边形像素坐标换算。
## [br]
## @api public
const SQRT_3: float = 1.7320508075688772

## 默认六边形外接圆半径。
## [br]
## @api public
const DEFAULT_HEX_SIZE: float = 32.0

const _CUBE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, -1, 0),
	Vector3i(1, 0, -1),
	Vector3i(0, 1, -1),
	Vector3i(-1, 1, 0),
	Vector3i(-1, 0, 1),
	Vector3i(0, -1, 1),
]


# --- 公共方法 ---

## 判断 offset 坐标是否位于网格范围内。
## [br]
## @api public
## [br]
## @param cell: offset 坐标。
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @return 在范围内返回 true。
static func is_in_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	if grid_size.x < 0 or grid_size.y < 0:
		return true

	return (
		grid_size.x > 0
		and grid_size.y > 0
		and cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


## 将 offset 坐标转换为 cube 坐标。
## [br]
## @api public
## [br]
## @param cell: offset 坐标。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return cube 坐标；满足 x + y + z == 0。
static func offset_to_cube(cell: Vector2i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector3i:
	var x: int = 0
	var z: int = 0
	match layout:
		OffsetLayout.EVEN_R:
			x = cell.x - _half_even(cell.y + _parity(cell.y))
			z = cell.y
		OffsetLayout.ODD_Q:
			x = cell.x
			z = cell.y - _half_even(cell.x - _parity(cell.x))
		OffsetLayout.EVEN_Q:
			x = cell.x
			z = cell.y - _half_even(cell.x + _parity(cell.x))
		_:
			x = cell.x - _half_even(cell.y - _parity(cell.y))
			z = cell.y

	return Vector3i(x, -x - z, z)


## 将 cube 坐标转换为 offset 坐标。
## [br]
## @api public
## [br]
## @param cube: cube 坐标。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return offset 坐标。
static func cube_to_offset(cube: Vector3i, layout: OffsetLayout = OffsetLayout.ODD_R) -> Vector2i:
	match layout:
		OffsetLayout.EVEN_R:
			return Vector2i(cube.x + _half_even(cube.z + _parity(cube.z)), cube.z)
		OffsetLayout.ODD_Q:
			return Vector2i(cube.x, cube.z + _half_even(cube.x - _parity(cube.x)))
		OffsetLayout.EVEN_Q:
			return Vector2i(cube.x, cube.z + _half_even(cube.x + _parity(cube.x)))
		_:
			return Vector2i(cube.x + _half_even(cube.z - _parity(cube.z)), cube.z)


## 四舍五入浮点 cube 坐标。
## [br]
## @api public
## [br]
## @param cube: 浮点 cube 坐标。
## [br]
## @return 最近的整数 cube 坐标；满足 x + y + z == 0。
static func cube_round(cube: Vector3) -> Vector3i:
	var rounded_x: int = roundi(cube.x)
	var rounded_y: int = roundi(cube.y)
	var rounded_z: int = roundi(cube.z)
	var x_diff: float = absf(float(rounded_x) - cube.x)
	var y_diff: float = absf(float(rounded_y) - cube.y)
	var z_diff: float = absf(float(rounded_z) - cube.z)

	if x_diff > y_diff and x_diff > z_diff:
		rounded_x = -rounded_y - rounded_z
	elif y_diff > z_diff:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y

	return Vector3i(rounded_x, rounded_y, rounded_z)


## 将 offset 坐标转换为像素中心点。
## [br]
## @api public
## [br]
## @param cell: offset 坐标。
## [br]
## @param hex_size: 六边形外接圆半径。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param orientation: 六边形朝向。
## [br]
## @return 像素中心点。
static func offset_to_pixel(
	cell: Vector2i,
	hex_size: float = DEFAULT_HEX_SIZE,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	orientation: HexOrientation = HexOrientation.POINTY_TOP
) -> Vector2:
	return cube_to_pixel(offset_to_cube(cell, layout), hex_size, orientation)


## 将像素坐标转换为最近的 offset 坐标。
## [br]
## @api public
## [br]
## @param pixel: 像素坐标。
## [br]
## @param hex_size: 六边形外接圆半径。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param orientation: 六边形朝向。
## [br]
## @return 最近的 offset 坐标。
static func pixel_to_offset(
	pixel: Vector2,
	hex_size: float = DEFAULT_HEX_SIZE,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	orientation: HexOrientation = HexOrientation.POINTY_TOP
) -> Vector2i:
	return cube_to_offset(pixel_to_cube(pixel, hex_size, orientation), layout)


## 将 cube 坐标转换为像素中心点。
## [br]
## @api public
## [br]
## @param cube: cube 坐标。
## [br]
## @param hex_size: 六边形外接圆半径。
## [br]
## @param orientation: 六边形朝向。
## [br]
## @return 像素中心点。
static func cube_to_pixel(
	cube: Vector3i,
	hex_size: float = DEFAULT_HEX_SIZE,
	orientation: HexOrientation = HexOrientation.POINTY_TOP
) -> Vector2:
	var safe_size: float = maxf(hex_size, 0.0001)
	var q: float = float(cube.x)
	var r: float = float(cube.z)
	match orientation:
		HexOrientation.FLAT_TOP:
			return Vector2(safe_size * 1.5 * q, safe_size * (SQRT_3 * 0.5 * q + SQRT_3 * r))
		_:
			return Vector2(safe_size * (SQRT_3 * q + SQRT_3 * 0.5 * r), safe_size * 1.5 * r)


## 将像素坐标转换为最近的 cube 坐标。
## [br]
## @api public
## [br]
## @param pixel: 像素坐标。
## [br]
## @param hex_size: 六边形外接圆半径。
## [br]
## @param orientation: 六边形朝向。
## [br]
## @return 最近的 cube 坐标。
static func pixel_to_cube(
	pixel: Vector2,
	hex_size: float = DEFAULT_HEX_SIZE,
	orientation: HexOrientation = HexOrientation.POINTY_TOP
) -> Vector3i:
	var safe_size: float = maxf(hex_size, 0.0001)
	var q: float = 0.0
	var r: float = 0.0
	match orientation:
		HexOrientation.FLAT_TOP:
			q = (2.0 / 3.0 * pixel.x) / safe_size
			r = (-1.0 / 3.0 * pixel.x + SQRT_3 / 3.0 * pixel.y) / safe_size
		_:
			q = (SQRT_3 / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / safe_size
			r = (2.0 / 3.0 * pixel.y) / safe_size

	return cube_round(Vector3(q, -q - r, r))


## 获取六边形顶点相对坐标。
## [br]
## @api public
## [br]
## @param hex_size: 六边形外接圆半径。
## [br]
## @param orientation: 六边形朝向。
## [br]
## @return 顶点数组，按顺时针排列。
static func get_polygon_points(
	hex_size: float = DEFAULT_HEX_SIZE,
	orientation: HexOrientation = HexOrientation.POINTY_TOP
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var offset_degrees: float = -30.0 if orientation == HexOrientation.POINTY_TOP else 0.0
	for index: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(index) + offset_degrees)
		_append_vector2(points, Vector2(cos(angle) * hex_size, sin(angle) * hex_size))
	return points


## 获取指定 offset 坐标的邻居。
## [br]
## @api public
## [br]
## @param cell: 中心坐标。
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return 位于网格范围内的邻居列表。
static func get_neighbors(
	cell: Vector2i,
	grid_size: Vector2i = Vector2i(-1, -1),
	layout: OffsetLayout = OffsetLayout.ODD_R
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cube: Vector3i = offset_to_cube(cell, layout)
	for direction: Vector3i in _CUBE_DIRECTIONS:
		var next_cell: Vector2i = cube_to_offset(cube + direction, layout)
		if is_in_bounds(next_cell, grid_size):
			result.append(next_cell)
	return result


## 计算两个 offset 坐标之间的六边形距离。
## [br]
## @api public
## [br]
## @param from_cell: 起点坐标。
## [br]
## @param to_cell: 终点坐标。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return 六边形步数距离。
static func distance(
	from_cell: Vector2i,
	to_cell: Vector2i,
	layout: OffsetLayout = OffsetLayout.ODD_R
) -> int:
	return cube_distance(offset_to_cube(from_cell, layout), offset_to_cube(to_cell, layout))


## 计算两个 cube 坐标之间的六边形距离。
## [br]
## @api public
## [br]
## @param from_cube: 起点 cube 坐标。
## [br]
## @param to_cube: 终点 cube 坐标。
## [br]
## @return 六边形步数距离。
static func cube_distance(from_cube: Vector3i, to_cube: Vector3i) -> int:
	return _half_even(
		absi(from_cube.x - to_cube.x)
		+ absi(from_cube.y - to_cube.y)
		+ absi(from_cube.z - to_cube.z)
	)


## 获取指定半径内的所有 offset 坐标。
## [br]
## @api public
## [br]
## @param center: 中心坐标。
## [br]
## @param radius: 半径。
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return 半径内坐标列表，包含中心。
static func get_range(
	center: Vector2i,
	radius: int,
	grid_size: Vector2i = Vector2i(-1, -1),
	layout: OffsetLayout = OffsetLayout.ODD_R
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0:
		return result

	var center_cube: Vector3i = offset_to_cube(center, layout)
	for dx: int in range(-radius, radius + 1):
		var min_dy: int = maxi(-radius, -dx - radius)
		var max_dy: int = mini(radius, -dx + radius)
		for dy: int in range(min_dy, max_dy + 1):
			var dz: int = -dx - dy
			var cell: Vector2i = cube_to_offset(center_cube + Vector3i(dx, dy, dz), layout)
			if is_in_bounds(cell, grid_size):
				result.append(cell)
	return result


## 获取指定半径的外环坐标。
## [br]
## @api public
## [br]
## @param center: 中心坐标。
## [br]
## @param radius: 半径；0 时返回中心。
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return 外环坐标列表。
static func get_ring(
	center: Vector2i,
	radius: int,
	grid_size: Vector2i = Vector2i(-1, -1),
	layout: OffsetLayout = OffsetLayout.ODD_R
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0:
		return result
	if radius == 0:
		return [center] if is_in_bounds(center, grid_size) else result

	var cube: Vector3i = offset_to_cube(center, layout) + _CUBE_DIRECTIONS[4] * radius
	for direction_index: int in range(6):
		for _step: int in range(radius):
			var cell: Vector2i = cube_to_offset(cube, layout)
			if is_in_bounds(cell, grid_size):
				result.append(cell)
			cube += _CUBE_DIRECTIONS[direction_index]
	return result


## 获取连接两个 offset 坐标的六边形直线。
## [br]
## @api public
## [br]
## @param from_cell: 起点坐标。
## [br]
## @param to_cell: 终点坐标。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @return 坐标列表，包含起点与终点。
static func get_line(
	from_cell: Vector2i,
	to_cell: Vector2i,
	layout: OffsetLayout = OffsetLayout.ODD_R
) -> Array[Vector2i]:
	var from_cube: Vector3i = offset_to_cube(from_cell, layout)
	var to_cube: Vector3i = offset_to_cube(to_cell, layout)
	var steps: int = cube_distance(from_cube, to_cube)
	if steps <= 0:
		return [from_cell]

	var result: Array[Vector2i] = []
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		result.append(cube_to_offset(_cube_lerp_round(from_cube, to_cube, t), layout))
	return result


## 判断两点之间是否有视线。
## [br]
## @api public
## [br]
## @param from_cell: 起点坐标。
## [br]
## @param to_cell: 终点坐标。
## [br]
## @param is_blocking: 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param include_endpoints: 是否检查起点与终点是否阻挡。
## [br]
## @return 没有阻挡时返回 true。
static func has_line_of_sight(
	from_cell: Vector2i,
	to_cell: Vector2i,
	is_blocking: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	include_endpoints: bool = false
) -> bool:
	if not is_blocking.is_valid():
		return true

	var line: Array[Vector2i] = get_line(from_cell, to_cell, layout)
	for index: int in range(line.size()):
		if not include_endpoints and (index == 0 or index == line.size() - 1):
			continue
		if _call_cell_bool(is_blocking, line[index]):
			return false
	return true


## 使用 A* 查找一条六边形路径。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param start: 起点坐标。
## [br]
## @param goal: 终点坐标。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @return 包含起点与终点的路径；无法到达时返回空数组。
static func find_path_a_star(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	step_cost: Callable = Callable()
) -> Array[Vector2i]:
	if (
		not is_in_bounds(start, grid_size)
		or not is_in_bounds(goal, grid_size)
		or not is_walkable.is_valid()
	):
		return []
	if start == goal:
		return [start]
	if not _call_cell_bool(is_walkable, goal):
		return []

	var open_set: Array[Vector2i] = [start]
	var open_lookup: Dictionary = { start: true }
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: float(distance(start, goal, layout)) }

	while not open_set.is_empty():
		var current: Vector2i = _take_lowest_score_cell(open_set, f_score)
		_erase_dictionary_key(open_lookup, current)
		if current == goal:
			return _reconstruct_path(start, goal, came_from)

		closed[current] = true
		for next_cell: Vector2i in get_neighbors(current, grid_size, layout):
			if closed.has(next_cell) or not _call_cell_bool(is_walkable, next_cell):
				continue

			var move_cost: float = _get_step_cost(current, next_cell, step_cost)
			if move_cost < 0.0:
				continue

			var tentative_score: float = _get_score(g_score, current) + move_cost
			if tentative_score >= _get_score(g_score, next_cell):
				continue

			came_from[next_cell] = current
			g_score[next_cell] = tentative_score
			f_score[next_cell] = tentative_score + float(distance(next_cell, goal, layout))
			if not open_lookup.has(next_cell):
				open_set.append(next_cell)
				open_lookup[next_cell] = true

	return []


## 创建可分步推进的六边形网格 A* 搜索状态。
## [br]
## 状态由 `GFGraphMath.advance_path_search()` 推进；本方法只负责把 Hex 布局、
## 邻居、通行、代价和距离启发函数适配成通用图搜索回调。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param start: 起点 offset 坐标。
## [br]
## @param goal: 终点 offset 坐标。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @return `GFGraphMath` 分步路径搜索状态句柄。
## [br]
## @schema return: GFGraphPathSearchState returned by `GFGraphMath.begin_path_search()`.
static func begin_path_a_star_search(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	step_cost: Callable = Callable()
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
	if not _call_cell_bool(is_walkable, goal):
		return _make_invalid_path_search(start, goal, &"blocked_goal")

	return GFGraphMath.begin_path_search(
		start,
		goal,
		func(node: Variant) -> Array:
			var cell: Vector2i = _variant_to_vector2i(node)
			var result: Array = []
			for next_cell: Vector2i in get_neighbors(cell, grid_size, layout):
				if _call_cell_bool(is_walkable, next_cell):
					result.append(next_cell)
			return result,
		func(from_node: Variant, to_node: Variant) -> float:
			return _get_step_cost(
				_variant_to_vector2i(from_node),
				_variant_to_vector2i(to_node),
				step_cost
			),
		func(node: Variant, goal_node: Variant) -> float:
			return float(distance(
				_variant_to_vector2i(node),
				_variant_to_vector2i(goal_node),
				layout
			))
	)


## 使用 Hex 视线检测抽稀六边形网格路径。
## [br]
## 该方法只移除可由 Hex 直线视线覆盖的中间格子，保留起点与终点；它不执行单位移动、
## 转向动画或碰撞响应。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 包含起点与终点的 offset 路径。
## [br]
## @param is_blocking: 阻挡回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param include_endpoints: 是否检查每段抽稀直线的端点是否阻挡。
## [br]
## @return 抽稀后的路径；空路径仍返回空数组。
## [br]
## @schema path: Array[Vector2i] path cells.
static func simplify_path_line_of_sight(
	path: Array[Vector2i],
	is_blocking: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
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
			if has_line_of_sight(path[anchor_index], path[next_index], is_blocking, layout, include_endpoints):
				break
			next_index -= 1

		result.append(path[next_index])
		anchor_index = next_index

	return result


## 从一个或多个目标格生成六边形 Flow Field。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param goals: 目标坐标列表。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @return 包含 `costs`、`directions` 和 `goals` 的字典；`directions[cell]` 是下一步 offset 方向。
## [br]
## @schema return: Dictionary with `costs: Dictionary[Vector2i, float]`, `directions: Dictionary[Vector2i, Vector2i]`, and `goals: Array[Vector2i]`.
static func build_flow_field(
	grid_size: Vector2i,
	goals: Array[Vector2i],
	is_walkable: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	step_cost: Callable = Callable()
) -> Dictionary:
	var costs: Dictionary = {}
	var directions: Dictionary = {}
	var valid_goals: Array[Vector2i] = []
	if not is_walkable.is_valid():
		return {
			"costs": costs,
			"directions": directions,
			"goals": valid_goals,
		}

	var frontier: Array[Vector2i] = []
	for goal: Vector2i in goals:
		if not is_in_bounds(goal, grid_size) or not _call_cell_bool(is_walkable, goal) or costs.has(goal):
			continue

		costs[goal] = 0.0
		directions[goal] = Vector2i.ZERO
		valid_goals.append(goal)
		frontier.append(goal)

	while not frontier.is_empty():
		var current: Vector2i = _take_lowest_score_cell(frontier, costs)
		for next_cell: Vector2i in get_neighbors(current, grid_size, layout):
			if not _call_cell_bool(is_walkable, next_cell):
				continue

			var move_cost: float = _get_step_cost(next_cell, current, step_cost)
			if move_cost < 0.0:
				continue

			var next_cost: float = _get_score(costs, current) + move_cost
			if next_cost >= _get_score(costs, next_cell):
				continue

			costs[next_cell] = next_cost
			directions[next_cell] = current - next_cell
			if not frontier.has(next_cell):
				frontier.append(next_cell)

	return {
		"costs": costs,
		"directions": directions,
		"goals": valid_goals,
	}


## 查找移动代价限制内的可达坐标。
## [br]
## @api public
## [br]
## @param grid_size: 网格尺寸；任一轴小于 0 时视为无限网格。
## [br]
## @param start: 起点坐标。
## [br]
## @param max_cost: 最大移动代价。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`。
## [br]
## @param layout: offset 坐标布局。
## [br]
## @param step_cost: 可选代价回调，签名为 `func(from: Vector2i, to: Vector2i) -> float`；返回负数表示不可通行。
## [br]
## @return 字典，key 为可达坐标，value 为从起点到该坐标的最低代价。
## [br]
## @schema return: Dictionary[Vector2i, float] mapping each reachable cell to its lowest travel cost from `start`.
static func find_reachable(
	grid_size: Vector2i,
	start: Vector2i,
	max_cost: float,
	is_walkable: Callable,
	layout: OffsetLayout = OffsetLayout.ODD_R,
	step_cost: Callable = Callable()
) -> Dictionary:
	var costs: Dictionary = {}
	if max_cost < 0.0 or not is_in_bounds(start, grid_size) or not is_walkable.is_valid():
		return costs
	if not _call_cell_bool(is_walkable, start):
		return costs

	var frontier: Array[Vector2i] = [start]
	costs[start] = 0.0
	while not frontier.is_empty():
		var current: Vector2i = _take_lowest_score_cell(frontier, costs)
		for next_cell: Vector2i in get_neighbors(current, grid_size, layout):
			if not _call_cell_bool(is_walkable, next_cell):
				continue

			var move_cost: float = _get_step_cost(current, next_cell, step_cost)
			if move_cost < 0.0:
				continue

			var next_cost: float = _get_score(costs, current) + move_cost
			if next_cost > max_cost or next_cost >= _get_score(costs, next_cell):
				continue

			costs[next_cell] = next_cost
			if not frontier.has(next_cell):
				frontier.append(next_cell)
	return costs


# --- 私有/辅助方法 ---

static func _parity(value: int) -> int:
	return int(posmod(value, 2))


static func _half_even(value: int) -> int:
	return value >> 1


static func _append_vector2(target: PackedVector2Array, value: Vector2) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


static func _call_cell_bool(callback: Callable, cell: Vector2i) -> bool:
	return GFVariantData.to_bool(callback.call(cell), false)


static func _get_score(scores: Dictionary, cell: Vector2i) -> float:
	return GFVariantData.get_option_float(scores, cell, INF)


static func _cube_lerp_round(from_cube: Vector3i, to_cube: Vector3i, t: float) -> Vector3i:
	var from_float: Vector3 = Vector3(from_cube.x, from_cube.y, from_cube.z)
	var to_float: Vector3 = Vector3(to_cube.x, to_cube.y, to_cube.z)
	return cube_round(from_float.lerp(to_float, t))


static func _get_step_cost(from_cell: Vector2i, to_cell: Vector2i, step_cost: Callable) -> float:
	if step_cost.is_valid():
		return GFVariantData.to_float(step_cost.call(from_cell, to_cell), 1.0)
	return 1.0


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


static func _take_lowest_score_cell(cells: Array[Vector2i], scores: Dictionary) -> Vector2i:
	var best_index: int = 0
	var best_score: float = _get_score(scores, cells[0])
	for index: int in range(1, cells.size()):
		var score: float = _get_score(scores, cells[index])
		if score < best_score:
			best_index = index
			best_score = score

	var cell: Vector2i = cells[best_index]
	cells.remove_at(best_index)
	return cell


static func _reconstruct_path(start: Vector2i, goal: Vector2i, came_from: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current: Vector2i = goal

	while current != start:
		if not came_from.has(current):
			return []

		current = came_from[current]
		path.push_front(current)

	return path
