## GFGridCoordinateMath2D: 2D 网格坐标、区域和直线查询工具。
##
## 只处理网格坐标转换、边界、邻居、区域、chunk 窗口、集合差分、
## 直线、视线和泛洪查询，不包含路径搜索、地图生成或玩法连接规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFGridCoordinateMath2D
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
	var codec_options: Dictionary = options.duplicate(true)
	if not codec_options.has("encode_dictionary_keys"):
		codec_options["encode_dictionary_keys"] = true
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(report, codec_options))


## 将二维格坐标转换为一维索引。
## [br]
## @api public
## [br]
## @since 8.0.0
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
## @since 8.0.0
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
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return Vector2i.ZERO

	return Vector2i(
		floori(world_position.x / float(chunk_size.x)),
		floori(world_position.y / float(chunk_size.y))
	)


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
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return Vector2.ZERO

	return Vector2(chunk_cell.x * chunk_size.x, chunk_cell.y * chunk_size.y)


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
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return Vector2.ZERO

	return chunk_cell_to_world_origin(chunk_cell, chunk_size) + Vector2(chunk_size) * 0.5


## 判断格坐标是否位于网格范围内。
## [br]
## @api public
## [br]
## @since 8.0.0
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
## @since 8.0.0
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
	var result: Array[Vector2i] = []
	if radius < 0:
		return result

	var normalized_shape: StringName = _normalize_chunk_window_shape(shape)
	for y: int in range(center_chunk.y - radius, center_chunk.y + radius + 1):
		for x: int in range(center_chunk.x - radius, center_chunk.x + radius + 1):
			var chunk_cell: Vector2i = Vector2i(x, y)
			if _is_chunk_window_cell_in_shape(chunk_cell - center_chunk, radius, normalized_shape):
				result.append(chunk_cell)
	return result


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
	var previous_set: Dictionary = _make_vector2i_set(previous_cells)
	var next_set: Dictionary = _make_vector2i_set(next_cells)
	var added: Array[Vector2i] = []
	var removed: Array[Vector2i] = []
	var kept: Array[Vector2i] = []
	var emitted_added: Dictionary = {}
	var emitted_removed: Dictionary = {}
	var emitted_kept: Dictionary = {}

	for cell: Vector2i in next_cells:
		if previous_set.has(cell):
			if not emitted_kept.has(cell):
				kept.append(cell)
				emitted_kept[cell] = true
		elif not emitted_added.has(cell):
			added.append(cell)
			emitted_added[cell] = true

	for cell: Vector2i in previous_cells:
		if next_set.has(cell):
			continue
		if not emitted_removed.has(cell):
			removed.append(cell)
			emitted_removed[cell] = true

	return {
		"added": added,
		"removed": removed,
		"kept": kept,
		"changed": not added.is_empty() or not removed.is_empty(),
		"previous_count": previous_set.size(),
		"next_count": next_set.size(),
	}


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
## @since 8.0.0
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


# --- 私有/辅助方法 ---

static func _is_in_optional_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	if grid_size.x < 0 or grid_size.y < 0:
		return true
	return is_in_bounds(cell, grid_size)


static func _normalize_chunk_window_shape(shape: StringName) -> StringName:
	match shape:
		&"circle", &"euclidean":
			return &"circle"
		&"square", &"chebyshev":
			return &"square"
		&"diamond", &"manhattan":
			return &"diamond"
		_:
			return &"circle"


static func _is_chunk_window_cell_in_shape(delta: Vector2i, radius: int, shape: StringName) -> bool:
	match shape:
		&"square":
			return maxi(absi(delta.x), absi(delta.y)) <= radius
		&"diamond":
			return absi(delta.x) + absi(delta.y) <= radius
		_:
			return delta.length_squared() <= radius * radius


static func _make_vector2i_set(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		result[cell] = true
	return result


static func _get_grid_distance(from_cell: Vector2i, to_cell: Vector2i, include_diagonal: bool) -> int:
	var dx: int = absi(to_cell.x - from_cell.x)
	var dy: int = absi(to_cell.y - from_cell.y)
	return maxi(dx, dy) if include_diagonal else dx + dy


static func _call_cell_predicate(predicate: Callable, cell: Vector2i, fallback: bool = false) -> bool:
	if not predicate.is_valid():
		return fallback
	return GFVariantData.to_bool(predicate.call(cell), fallback)
