## GFGridVisibilityMath2D: 有界二维网格的整片视野查询。
##
## 使用迭代对称阴影扫描，只返回当前可见格，不持有场景、阵营或探索历史。
## 固定允许两堵仅在角点接触的墙之间透视；不等价于 Bresenham 点对点 LOS。
## 每次调用独立缓存阻挡值，回调须同步且不修改正在查询的地图。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFGridVisibilityMath2D
extends RefCounted


# --- 常量 ---

## 允许的最大整数欧氏半径。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_RADIUS: int = 128

## 查询窗口允许的最大格数，等于最大半径包围盒的面积。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_CELLS: int = 66049


# --- 公共方法 ---

## 计算有限网格内整数欧氏圆形范围的可见格。
##
## 透明格之间互见对称；可见墙面参与遮挡，是否输出由 include_walls 控制。
## 原点必须透明，半径为零也会查询原点。结果按 y 再 x 升序排列且无重复。
## 先以裁剪到网格内的半径包围盒面积做保守准入，即使圆内格数或实际可见格更少，
## 包围盒超预算也会失败。阻挡回调对圆内每个被访问格最多调用一次，不查询网格外。
## 回调的运行时间和外部副作用不能由此纯函数中断或回滚。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param grid_size: 网格正尺寸。
## [br]
## @param origin: 网格内的透明观察格。
## [br]
## @param radius: 0 至 MAX_RADIUS 的整数欧氏半径。
## [br]
## @param is_blocking: 同步纯查询，恰好接收一个 Vector2i 参数并返回 bool；不支持需要其它参数的回调或异步回调。
## [br]
## @param include_walls: 是否将可见墙格包含在输出中；墙格始终遮挡。
## [br]
## @param max_cells: 1 至 MAX_CELLS 的裁剪包围盒格数预算。
## [br]
## @return: 有界视野报告；成功的 error 为空，失败的 visible_cells 始终为空，不发布部分结果。
## [br]
## @schema return: Dictionary，包含 ok: bool、error: StringName、visible_cells: Array[Vector2i]、queried_cell_count: int（实际阻挡回调次数）、error_cell: Vector2i（查询失败格；成功或参数准入失败为 (-1, -1)）。error 为空 StringName，或 invalid_grid_size、origin_out_of_bounds、invalid_radius、invalid_budget、cell_budget_exceeded、invalid_predicate、invalid_predicate_result、origin_blocked。
static func compute_fov(
	grid_size: Vector2i,
	origin: Vector2i,
	radius: int,
	is_blocking: Callable,
	include_walls: bool = true,
	max_cells: int = MAX_CELLS
) -> Dictionary:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return _failure(&"invalid_grid_size")
	if origin.x < 0 or origin.y < 0 or origin.x >= grid_size.x or origin.y >= grid_size.y:
		return _failure(&"origin_out_of_bounds")
	if radius < 0 or radius > MAX_RADIUS:
		return _failure(&"invalid_radius")
	if max_cells < 1 or max_cells > MAX_CELLS:
		return _failure(&"invalid_budget")

	# 用 int64 标量先裁剪；Vector2i 加减会在极端合法网格边缘产生 32 位溢出。
	var min_x: int = maxi(int(origin.x) - radius, 0)
	var min_y: int = maxi(int(origin.y) - radius, 0)
	var max_x: int = mini(int(origin.x) + radius, int(grid_size.x) - 1)
	var max_y: int = mini(int(origin.y) + radius, int(grid_size.y) - 1)
	var width: int = max_x - min_x + 1
	var height: int = max_y - min_y + 1
	# 半径硬界使两个因子最多为 257，不对巨大 grid_size 做面积乘法。
	if width * height > max_cells:
		return _failure(&"cell_budget_exceeded")
	if not is_blocking.is_valid() or is_blocking.get_argument_count() != 1:
		return _failure(&"invalid_predicate")

	var scan: _ScanState = _ScanState.new(grid_size, origin, radius, is_blocking, include_walls)
	var origin_status: int = _query_blocking(scan, origin)
	if origin_status < 0:
		return _failure(scan._error, scan)
	if origin_status == 1:
		scan._error_cell = origin
		return _failure(&"origin_blocked", scan)
	scan._visible[origin] = true

	for quadrant: int in range(4):
		_scan_quadrant(scan, quadrant)
		if not scan._error.is_empty():
			return _failure(scan._error, scan)

	var visible_cells: Array[Vector2i] = []
	for row: int in range(min_y, max_y + 1):
		for column: int in range(min_x, max_x + 1):
			var cell: Vector2i = Vector2i(column, row)
			if scan._visible.has(cell):
				visible_cells.append(cell)
	return {
		"ok": true,
		"error": &"",
		"visible_cells": visible_cells,
		"queried_cell_count": scan._queried_cell_count,
		"error_cell": Vector2i(-1, -1),
	}


# --- 私有/辅助方法 ---

static func _scan_quadrant(scan: _ScanState, quadrant: int) -> void:
	var rows: Array[_Row] = [_Row.new(1, Vector2i(-1, 1), Vector2i(1, 1))]
	while not rows.is_empty():
		var row: _Row = rows[rows.size() - 1]
		rows.remove_at(rows.size() - 1)
		if row._depth > scan._radius:
			continue

		# 以有理斜率保留角点边界；商只用于有硬界的行取整，不累计浮点斜率误差。
		var first_column: int = floori(
			float(2 * row._depth * row._low.x + row._low.y) / float(2 * row._low.y)
		)
		var last_column: int = ceili(
			float(2 * row._depth * row._high.x - row._high.y) / float(2 * row._high.y)
		)
		var previous_status: int = -1
		for column: int in range(first_column, last_column + 1):
			var offset: Vector2i = _quadrant_offset(quadrant, row._depth, column)
			var column_status: int = _visit_cell(scan, row, column, offset)
			if column_status < 0:
				return

			var boundary: Vector2i = Vector2i(2 * column - 1, 2 * row._depth)
			if previous_status == 1 and column_status == 0:
				row._low = boundary
			elif previous_status == 0 and column_status == 1:
				rows.append(_Row.new(row._depth + 1, row._low, boundary))
			previous_status = column_status

		if previous_status == 0:
			rows.append(_Row.new(row._depth + 1, row._low, row._high))


static func _visit_cell(scan: _ScanState, row: _Row, column: int, offset: Vector2i) -> int:
	var cell_x: int = int(scan._origin.x) + int(offset.x)
	var cell_y: int = int(scan._origin.y) + int(offset.y)
	if cell_x < 0 or cell_y < 0 or cell_x >= scan._grid_size.x or cell_y >= scan._grid_size.y:
		return 1
	if offset.x * offset.x + offset.y * offset.y > scan._radius * scan._radius:
		return 1

	var cell: Vector2i = Vector2i(cell_x, cell_y)
	var status: int = _query_blocking(scan, cell)
	if status < 0:
		return status
	var symmetric: bool = (
		column * row._low.y >= row._depth * row._low.x
		and column * row._high.y <= row._depth * row._high.x
	)
	if (status == 1 and scan._include_walls) or (status == 0 and symmetric):
		scan._visible[cell] = true
	return status


static func _query_blocking(scan: _ScanState, cell: Vector2i) -> int:
	var cached: Variant = scan._blocking.get(cell)
	if cached is bool:
		return 1 if cached else 0
	if not scan._predicate.is_valid():
		scan._error = &"invalid_predicate"
		scan._error_cell = cell
		return -1

	scan._queried_cell_count += 1
	var result: Variant = scan._predicate.call(cell)
	if not result is bool:
		scan._error = &"invalid_predicate_result"
		scan._error_cell = cell
		return -1
	var blocked: bool = result
	scan._blocking[cell] = blocked
	return 1 if blocked else 0


static func _quadrant_offset(quadrant: int, depth: int, column: int) -> Vector2i:
	match quadrant:
		0:
			return Vector2i(column, -depth)
		1:
			return Vector2i(depth, column)
		2:
			return Vector2i(column, depth)
		_:
			return Vector2i(-depth, column)


static func _failure(error: StringName, scan: _ScanState = null) -> Dictionary:
	var visible_cells: Array[Vector2i] = []
	return {
		"ok": false,
		"error": error,
		"visible_cells": visible_cells,
		"queried_cell_count": scan._queried_cell_count if scan != null else 0,
		"error_cell": scan._error_cell if scan != null else Vector2i(-1, -1),
	}


# --- 内部类 ---

class _Row extends RefCounted:
	var _depth: int
	var _low: Vector2i
	var _high: Vector2i

	func _init(depth: int, low: Vector2i, high: Vector2i) -> void:
		_depth = depth
		_low = low
		_high = high


class _ScanState extends RefCounted:
	var _grid_size: Vector2i
	var _origin: Vector2i
	var _radius: int
	var _predicate: Callable
	var _include_walls: bool
	var _blocking: Dictionary[Vector2i, bool] = {}
	var _visible: Dictionary[Vector2i, bool] = {}
	var _error: StringName = &""
	var _error_cell: Vector2i = Vector2i(-1, -1)
	var _queried_cell_count: int = 0

	func _init(grid_size: Vector2i, origin: Vector2i, radius: int, predicate: Callable, include_walls: bool) -> void:
		_grid_size = grid_size
		_origin = origin
		_radius = radius
		_predicate = predicate
		_include_walls = include_walls
