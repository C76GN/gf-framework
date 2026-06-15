## GFPoissonDisc2D: 通用二维 Poisson-disc 采样工具。
##
## 在矩形区域中生成最小间距受限的点集，适合程序化摆放、刷点候选、
## 空间采样和编辑器工具。它只返回纯数据，不创建 Node、地形、碰撞或渲染资源。
## 随机序列来自 GF 固定算法随机源；输出点仍是浮点几何数据，不作为定点锁步真值。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFPoissonDisc2D
extends RefCounted


# --- 常量 ---

## 默认每个活动点尝试生成候选点的次数。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_CANDIDATE_ATTEMPTS: int = 30

## 默认最大输出点数，避免误把超大实时采样交给纯 GDScript。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_POINTS: int = 4096

## 默认最大空间网格单元数量，避免极小半径导致大内存分配。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_GRID_CELLS: int = 262144

const _SQRT_TWO: float = 1.4142135623730951


# --- 公共方法 ---

## 在矩形区域中生成 Poisson-disc 采样点。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param area: 采样区域。
## [br]
## @param minimum_distance: 任意两点之间的最小距离。
## [br]
## @param options: 可选参数，支持 seed、candidate_attempts、max_points、max_grid_cells 和 start_point。
## [br]
## @return 采样结果字典。
## [br]
## @schema options: Dictionary，seed 为确定性随机种子，candidate_attempts 为每个活动点的候选尝试次数，max_points 为最大输出点数，max_grid_cells 为内部空间网格单元上限，start_point 为可选起始 Vector2。
## [br]
## @schema return: Dictionary，包含 ok、error、area、minimum_distance、seed、candidate_attempts、max_points、max_grid_cells、points、point_count 与 truncated 字段。
static func generate_points(area: Rect2, minimum_distance: float, options: Dictionary = {}) -> Dictionary:
	var validation_error: String = _get_input_error(area, minimum_distance)
	if not validation_error.is_empty():
		return _make_failure_result(area, minimum_distance, options, validation_error)

	var candidate_attempts: int = maxi(
		GFVariantData.get_option_int(options, "candidate_attempts", DEFAULT_CANDIDATE_ATTEMPTS),
		1
	)
	var max_points: int = maxi(
		GFVariantData.get_option_int(options, "max_points", DEFAULT_MAX_POINTS),
		0
	)
	if max_points <= 0:
		return _make_failure_result(area, minimum_distance, options, "max_points must be greater than 0.")

	var max_grid_cells: int = maxi(
		GFVariantData.get_option_int(options, "max_grid_cells", DEFAULT_MAX_GRID_CELLS),
		1
	)
	var rng_seed: int = GFVariantData.get_option_int(options, "seed", 0)
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(rng_seed)

	var start_result: Dictionary = _resolve_start_point(area, rng, options)
	if not GFVariantData.get_option_bool(start_result, "ok", false):
		return _make_failure_result(
			area,
			minimum_distance,
			options,
			GFVariantData.get_option_string(start_result, "error", "")
		)

	var cell_size: float = minimum_distance / _SQRT_TWO
	var grid_size: Vector2i = Vector2i(
		maxi(ceili(area.size.x / cell_size), 1),
		maxi(ceili(area.size.y / cell_size), 1)
	)
	var grid_cell_count: int = grid_size.x * grid_size.y
	if grid_cell_count > max_grid_cells:
		return _make_failure_result(
			area,
			minimum_distance,
			options,
			"grid cell count exceeds max_grid_cells."
		)
	var grid: PackedInt32Array = PackedInt32Array()
	var _grid_resize_result: int = grid.resize(grid_cell_count)
	for grid_index: int in range(grid.size()):
		grid[grid_index] = 0

	var points: PackedVector2Array = PackedVector2Array()
	var active_indices: PackedInt32Array = PackedInt32Array()
	var start_point: Vector2 = GFVariantData.to_vector2(
		GFVariantData.get_option_value(start_result, "point"),
		area.get_center()
	)
	_add_point(
		start_point,
		area,
		cell_size,
		grid_size,
		grid,
		points,
		active_indices
	)

	while not active_indices.is_empty() and points.size() < max_points:
		var active_slot: int = rng.next_int_range(0, active_indices.size() - 1)
		var source_index: int = active_indices[active_slot]
		var source_point: Vector2 = points[source_index]
		var accepted: bool = false
		for _candidate_index: int in range(candidate_attempts):
			var angle: float = rng.next_float_unit() * TAU
			var radius: float = rng.next_float_range(minimum_distance, minimum_distance * 2.0)
			var candidate: Vector2 = source_point + Vector2(cos(angle), sin(angle)) * radius
			if _is_candidate_valid(candidate, area, cell_size, minimum_distance, grid_size, grid, points):
				_add_point(candidate, area, cell_size, grid_size, grid, points, active_indices)
				accepted = true
				break

		if not accepted:
			active_indices.remove_at(active_slot)

	return _make_success_result(
		area,
		minimum_distance,
		rng_seed,
		candidate_attempts,
		max_points,
		max_grid_cells,
		points,
		not active_indices.is_empty()
	)


# --- 私有/辅助方法 ---

static func _get_input_error(area: Rect2, minimum_distance: float) -> String:
	if not _is_finite_point(area.position) or not _is_finite_point(area.size):
		return "area must contain finite values."
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return "area size must be positive."
	if is_nan(minimum_distance) or is_inf(minimum_distance) or minimum_distance <= 0.0:
		return "minimum_distance must be a positive finite value."
	return ""


static func _resolve_start_point(area: Rect2, rng: GFDeterministicRandom, options: Dictionary) -> Dictionary:
	if options.has("start_point"):
		var start_value: Variant = GFVariantData.get_option_value(options, "start_point")
		if not start_value is Vector2:
			return { "ok": false, "error": "start_point must be a Vector2." }

		var start_point: Vector2 = start_value
		if not _is_finite_point(start_point):
			return { "ok": false, "error": "start_point must contain finite values." }
		if not area.has_point(start_point):
			return { "ok": false, "error": "start_point must be inside area." }
		return { "ok": true, "error": "", "point": start_point }

	var random_point: Vector2 = area.position + Vector2(
		rng.next_float_unit() * area.size.x,
		rng.next_float_unit() * area.size.y
	)
	return { "ok": true, "error": "", "point": random_point }


static func _add_point(
	point: Vector2,
	area: Rect2,
	cell_size: float,
	grid_size: Vector2i,
	grid: PackedInt32Array,
	points: PackedVector2Array,
	active_indices: PackedInt32Array
) -> void:
	var point_index: int = points.size()
	var _point_appended: bool = points.append(point)
	var _active_appended: bool = active_indices.append(point_index)
	var cell: Vector2i = _point_to_cell(point, area, cell_size, grid_size)
	grid[_cell_to_index(cell, grid_size)] = point_index + 1


static func _is_candidate_valid(
	candidate: Vector2,
	area: Rect2,
	cell_size: float,
	minimum_distance: float,
	grid_size: Vector2i,
	grid: PackedInt32Array,
	points: PackedVector2Array
) -> bool:
	if not _is_finite_point(candidate):
		return false
	if not area.has_point(candidate):
		return false

	var cell: Vector2i = _point_to_cell(candidate, area, cell_size, grid_size)
	var search_start: Vector2i = Vector2i(maxi(cell.x - 2, 0), maxi(cell.y - 2, 0))
	var search_end: Vector2i = Vector2i(mini(cell.x + 2, grid_size.x - 1), mini(cell.y + 2, grid_size.y - 1))
	var minimum_distance_squared: float = minimum_distance * minimum_distance
	for x: int in range(search_start.x, search_end.x + 1):
		for y: int in range(search_start.y, search_end.y + 1):
			var point_index: int = grid[_cell_to_index(Vector2i(x, y), grid_size)] - 1
			if point_index < 0:
				continue
			if candidate.distance_squared_to(points[point_index]) < minimum_distance_squared:
				return false
	return true


static func _point_to_cell(point: Vector2, area: Rect2, cell_size: float, grid_size: Vector2i) -> Vector2i:
	var local: Vector2 = point - area.position
	return Vector2i(
		clampi(floori(local.x / cell_size), 0, grid_size.x - 1),
		clampi(floori(local.y / cell_size), 0, grid_size.y - 1)
	)


static func _cell_to_index(cell: Vector2i, grid_size: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x


static func _make_success_result(
	area: Rect2,
	minimum_distance: float,
	rng_seed: int,
	candidate_attempts: int,
	max_points: int,
	max_grid_cells: int,
	points: PackedVector2Array,
	truncated: bool
) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"area": area,
		"minimum_distance": minimum_distance,
		"seed": rng_seed,
		"candidate_attempts": candidate_attempts,
		"max_points": max_points,
		"max_grid_cells": max_grid_cells,
		"points": points,
		"point_count": points.size(),
		"truncated": truncated,
	}


static func _make_failure_result(
	area: Rect2,
	minimum_distance: float,
	options: Dictionary,
	error: String
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"area": area,
		"minimum_distance": minimum_distance,
		"seed": GFVariantData.get_option_int(options, "seed", 0),
		"candidate_attempts": maxi(
			GFVariantData.get_option_int(options, "candidate_attempts", DEFAULT_CANDIDATE_ATTEMPTS),
			1
		),
		"max_points": maxi(GFVariantData.get_option_int(options, "max_points", DEFAULT_MAX_POINTS), 0),
		"max_grid_cells": maxi(
			GFVariantData.get_option_int(options, "max_grid_cells", DEFAULT_MAX_GRID_CELLS),
			1
		),
		"points": PackedVector2Array(),
		"point_count": 0,
		"truncated": false,
	}


static func _is_finite_point(point: Vector2) -> bool:
	return not is_nan(point.x) and not is_inf(point.x) and not is_nan(point.y) and not is_inf(point.y)
