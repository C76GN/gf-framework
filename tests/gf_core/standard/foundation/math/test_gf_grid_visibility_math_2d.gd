# 验证有界二维整片视野的几何、失败报告与查询隔离。
extends GutTest


const GF_GRID_VISIBILITY_MATH_2D_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_grid_visibility_math_2d.gd")


func test_empty_map_returns_euclidean_disk_in_row_major_order() -> void:
	var report: Dictionary = _compute(Vector2i(5, 5), Vector2i(2, 2), 2)
	var expected: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(2, 4),
	]
	assert_true(_ok(report))
	assert_eq(_cells(report), expected)
	assert_eq(_count(report), 13, "四象限共享边上的格子不应重复查询。")


func test_wall_is_visible_but_hides_cells_behind_it() -> void:
	var walls: Dictionary = {}
	for row: int in range(5):
		walls[Vector2i(2, row)] = true
	var report: Dictionary = _compute(Vector2i(5, 5), Vector2i(0, 2), 5, walls)
	var cells: Array[Vector2i] = _cells(report)
	assert_true(_ok(report))
	assert_has(cells, Vector2i(2, 2))
	assert_has(cells, Vector2i(1, 2))
	assert_does_not_have(cells, Vector2i(3, 2))
	assert_does_not_have(cells, Vector2i(4, 1))


func test_excluding_walls_changes_output_without_removing_occlusion() -> void:
	var walls: Dictionary = { Vector2i(1, 0): true }
	var with_walls: Dictionary = _compute(Vector2i(4, 1), Vector2i.ZERO, 3, walls)
	var without_walls: Dictionary = _compute(Vector2i(4, 1), Vector2i.ZERO, 3, walls, false)
	assert_eq(_cells(with_walls), [Vector2i.ZERO, Vector2i(1, 0)])
	assert_eq(_cells(without_walls), [Vector2i.ZERO])
	assert_eq(_count(with_walls), _count(without_walls))


func test_two_corner_touching_walls_allow_diagonal_visibility() -> void:
	var walls: Dictionary = { Vector2i(2, 1): true, Vector2i(1, 2): true }
	var report: Dictionary = _compute(Vector2i(4, 4), Vector2i(1, 1), 3, walls)
	assert_true(_ok(report))
	assert_has(_cells(report), Vector2i(2, 2), "固定规则允许两墙仅角接触处的视线。")
	assert_has(_cells(report), Vector2i(3, 3))
	assert_does_not_have(_cells(report), Vector2i(3, 1))


func test_doorway_reveals_corridor_without_revealing_across_wall() -> void:
	var walls: Dictionary = {
		Vector2i(2, 0): true, Vector2i(2, 1): true,
		Vector2i(2, 3): true, Vector2i(2, 4): true,
	}
	var report: Dictionary = _compute(Vector2i(6, 5), Vector2i(0, 2), 6, walls)
	assert_has(_cells(report), Vector2i(5, 2))
	assert_does_not_have(_cells(report), Vector2i(3, 0))
	assert_does_not_have(_cells(report), Vector2i(3, 4))


func test_map_edge_clips_disk_without_querying_outside_cells() -> void:
	var queried: Array[Vector2i] = []
	var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(3, 3), Vector2i.ZERO, 2,
		func(cell: Vector2i) -> bool:
			queried.append(cell)
			return false
	)
	var expected: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2),
	]
	assert_eq(_cells(report), expected)
	assert_eq(queried.size(), expected.size())
	for cell: Vector2i in queried:
		assert_has(expected, cell)


func test_zero_radius_only_queries_and_returns_origin() -> void:
	var report: Dictionary = _compute(Vector2i(10, 10), Vector2i(4, 5), 0)
	assert_true(_ok(report))
	assert_eq(_cells(report), [Vector2i(4, 5)])
	assert_eq(_count(report), 1)


func test_opaque_origin_is_explicit_failure_even_at_zero_radius() -> void:
	var report: Dictionary = _compute(Vector2i(3, 3), Vector2i(1, 1), 0, { Vector2i(1, 1): true })
	_assert_failure(report, &"origin_blocked")
	assert_eq(_count(report), 1)
	assert_eq(_error_cell(report), Vector2i(1, 1))


func test_invalid_dimensions_origin_and_radius_do_not_query() -> void:
	var cases: Array[Dictionary] = [
		{ "size": Vector2i.ZERO, "origin": Vector2i.ZERO, "radius": 0, "error": &"invalid_grid_size" },
		{ "size": Vector2i(-1, 2), "origin": Vector2i.ZERO, "radius": 1, "error": &"invalid_grid_size" },
		{ "size": Vector2i(2, 2), "origin": Vector2i(-1, 0), "radius": 1, "error": &"origin_out_of_bounds" },
		{ "size": Vector2i(2, 2), "origin": Vector2i(2, 0), "radius": 1, "error": &"origin_out_of_bounds" },
		{ "size": Vector2i(2, 2), "origin": Vector2i.ZERO, "radius": -1, "error": &"invalid_radius" },
		{ "size": Vector2i(2, 2), "origin": Vector2i.ZERO, "radius": 129, "error": &"invalid_radius" },
		{ "size": Vector2i(2, 2), "origin": Vector2i.ZERO, "radius": 9223372036854775807, "error": &"invalid_radius" },
	]
	var calls: Array[int] = [0]
	for item: Dictionary in cases:
		var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
			_vector_field(item, "size"),
			_vector_field(item, "origin"),
			GFVariantData.get_option_int(item, "radius"),
			func(_cell: Vector2i) -> bool:
				calls[0] += 1
				return false
		)
		_assert_failure(report, GFVariantData.get_option_string_name(item, "error"))
		assert_eq(_count(report), 0)
	assert_eq(calls[0], 0)


func test_budget_is_conservative_clipped_rectangle_admission_before_callbacks() -> void:
	var calls: Array[int] = [0]
	var predicate: Callable = func(_cell: Vector2i) -> bool:
		calls[0] += 1
		return false
	for budget: int in [0, 66050, 8]:
		var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
			Vector2i(3, 3), Vector2i(1, 1), 1, predicate, true, budget
		)
		_assert_failure(report, &"cell_budget_exceeded" if budget == 8 else &"invalid_budget")
	assert_eq(calls[0], 0)
	var accepted: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(3, 3), Vector2i(1, 1), 1, predicate, true, 9
	)
	assert_true(_ok(accepted))
	assert_eq(calls[0], 5)


func test_maximum_radius_has_consistent_default_budget() -> void:
	var report: Dictionary = _compute(Vector2i(257, 257), Vector2i(128, 128), 128)
	var cells: Array[Vector2i] = _cells(report)
	assert_true(_ok(report))
	assert_has(cells, Vector2i(256, 128))
	assert_has(cells, Vector2i(128, 0))
	assert_does_not_have(cells, Vector2i(256, 256))
	assert_lte(_count(report), 66049)
	assert_eq(cells.size(), 51433, "最大半径应返回完整整数圆盘。")
	assert_eq(_count(report), cells.size())


func test_extreme_vector_coordinates_use_bounded_local_window() -> void:
	var grid_size: Vector2i = Vector2i(2147483647, 2147483647)
	var origin: Vector2i = Vector2i(2147483646, 2147483646)
	var report: Dictionary = _compute(grid_size, origin, 1)
	var expected: Array[Vector2i] = [
		Vector2i(2147483646, 2147483645),
		Vector2i(2147483645, 2147483646), origin,
	]
	assert_true(_ok(report))
	assert_eq(_cells(report), expected)
	assert_eq(_count(report), 3)


func test_invalid_callable_or_arity_fails_without_engine_call() -> void:
	_assert_failure(
		GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(Vector2i.ONE, Vector2i.ZERO, 0, Callable()),
		&"invalid_predicate"
	)
	var wrong_arity: Callable = func() -> bool:
		return false
	_assert_failure(
		GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(Vector2i.ONE, Vector2i.ZERO, 0, wrong_arity),
		&"invalid_predicate"
	)


func test_released_predicate_owner_fails_before_any_query() -> void:
	var predicate_owner: _PredicateOwner = _PredicateOwner.new()
	var calls: Array[int] = [0]
	predicate_owner.calls = calls
	var predicate: Callable = predicate_owner.is_blocking
	predicate_owner.free()
	var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(3, 3), Vector2i(1, 1), 1, predicate
	)
	_assert_failure(report, &"invalid_predicate")
	assert_eq(_count(report), 0)
	assert_eq(calls[0], 0)


func test_non_bool_result_clears_partial_visibility_and_reports_cell() -> void:
	var calls: Array[int] = [0]
	var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(5, 5), Vector2i(2, 2), 2,
		func(_cell: Vector2i) -> Variant:
			calls[0] += 1
			if calls[0] < 3:
				return false
			return 1
	)
	_assert_failure(report, &"invalid_predicate_result")
	assert_eq(_count(report), 3)
	assert_eq(calls[0], 3, "错误后不应继续调用阻挡回调。")
	assert_ne(_error_cell(report), Vector2i(-1, -1))


func test_queries_are_cached_and_repeated_runs_do_not_mutate_input() -> void:
	var walls: Dictionary = { Vector2i(1, 1): true, Vector2i(3, 1): true, Vector2i(2, 3): true }
	var original: Dictionary = walls.duplicate(true)
	var query_counts: Dictionary = {}
	var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(5, 5), Vector2i(2, 2), 4,
		func(cell: Vector2i) -> bool:
			query_counts[cell] = GFVariantData.get_option_int(query_counts, cell) + 1
			return walls.has(cell)
	)
	assert_true(_ok(report))
	assert_eq(walls, original)
	for count: Variant in query_counts.values():
		var queried_once: bool = count is int and count == 1
		assert_true(queried_once)
	var repeated: Dictionary = _compute(Vector2i(5, 5), Vector2i(2, 2), 4, walls)
	assert_eq(report, repeated)


func test_transparent_cells_have_symmetric_visibility() -> void:
	var walls: Dictionary = { Vector2i(1, 1): true, Vector2i(3, 1): true, Vector2i(2, 3): true }
	var visibility: Dictionary = {}
	for row: int in range(5):
		for column: int in range(5):
			var origin: Vector2i = Vector2i(column, row)
			if not walls.has(origin):
				var report: Dictionary = _compute(Vector2i(5, 5), origin, 8, walls, false)
				assert_true(_ok(report))
				visibility[origin] = _cells(report)
	for origin: Vector2i in visibility:
		var visible: Array = GFVariantData.get_option_array(visibility, origin)
		for target: Vector2i in visibility:
			var reverse: Array = GFVariantData.get_option_array(visibility, target)
			assert_eq(visible.has(target), reverse.has(origin), "透明格互见应对称：%s / %s" % [origin, target])


func test_rotated_and_mirrored_maps_preserve_visibility() -> void:
	var walls: Dictionary = { Vector2i(1, 1): true, Vector2i(3, 1): true, Vector2i(2, 3): true }
	var origin: Vector2i = Vector2i(0, 2)
	var original_report: Dictionary = _compute(Vector2i(5, 5), origin, 6, walls)
	assert_true(_ok(original_report))
	var original: Array[Vector2i] = _cells(original_report)
	for mirrored: bool in [false, true]:
		var transformed_walls: Dictionary = {}
		for cell: Vector2i in walls:
			transformed_walls[_transform(cell, mirrored)] = true
		var report: Dictionary = _compute(Vector2i(5, 5), _transform(origin, mirrored), 6, transformed_walls)
		assert_true(_ok(report))
		var transformed: Array[Vector2i] = _cells(report)
		assert_eq(transformed.size(), original.size())
		for cell: Vector2i in original:
			assert_has(transformed, _transform(cell, mirrored))


func test_nested_independent_query_does_not_corrupt_outer_snapshot() -> void:
	var inner_results: Array[Dictionary] = []
	var report: Dictionary = GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		Vector2i(3, 3), Vector2i(1, 1), 1,
		func(_cell: Vector2i) -> bool:
			if inner_results.is_empty():
				inner_results.append(_compute(Vector2i.ONE, Vector2i.ZERO, 0))
			return false
	)
	assert_eq(inner_results.size(), 1)
	if inner_results.size() != 1:
		return
	assert_eq(_cells(inner_results[0]), [Vector2i.ZERO])
	assert_eq(report, _compute(Vector2i(3, 3), Vector2i(1, 1), 1))


func _compute(grid_size: Vector2i, origin: Vector2i, radius: int, walls: Dictionary = {}, include_walls: bool = true) -> Dictionary:
	return GF_GRID_VISIBILITY_MATH_2D_SCRIPT.compute_fov(
		grid_size, origin, radius,
		func(cell: Vector2i) -> bool:
			return walls.has(cell),
		include_walls
	)


func _ok(report: Dictionary) -> bool:
	var value: Variant = report.get("ok")
	assert_true(value is bool)
	if value is bool:
		return value
	return false


func _cells(report: Dictionary) -> Array[Vector2i]:
	var value: Variant = report.get("visible_cells")
	var result: Array[Vector2i] = []
	var all_cells_valid: bool = true
	assert_true(value is Array)
	if value is Array:
		for cell: Variant in value:
			if cell is Vector2i:
				result.append(cell)
			else:
				all_cells_valid = false
	assert_true(all_cells_valid)
	return result


func _count(report: Dictionary) -> int:
	var value: Variant = report.get("queried_cell_count")
	assert_true(value is int)
	if value is int:
		return value
	return 0


func _error_cell(report: Dictionary) -> Vector2i:
	return _vector_field(report, "error_cell")


func _vector_field(report: Dictionary, key: String) -> Vector2i:
	var value: Variant = report.get(key)
	assert_true(value is Vector2i)
	if value is Vector2i:
		return value
	return Vector2i(-1, -1)


func _assert_failure(report: Dictionary, error: StringName) -> void:
	assert_false(_ok(report))
	var actual: Variant = report.get("error")
	var matches_error: bool = actual is StringName and actual == error
	assert_true(matches_error)
	assert_eq(_cells(report), [])


func _transform(cell: Vector2i, mirrored: bool) -> Vector2i:
	return Vector2i(4 - cell.x, cell.y) if mirrored else Vector2i(4 - cell.y, cell.x)


class _PredicateOwner extends Node:
	var calls: Array[int]

	func is_blocking(_cell: Vector2i) -> bool:
		calls[0] += 1
		return false
