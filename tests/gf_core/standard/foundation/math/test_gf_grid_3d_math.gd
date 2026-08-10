## 测试 GFGrid3DMath 的邻居、寻路、可达范围和台阶式表面移动。
extends GutTest

# --- 测试 ---

func test_neighbors_respect_bounds_and_diagonal_option() -> void:
	var grid_size: Vector3i = Vector3i(3, 3, 3)

	assert_eq(GFGrid3DMath.get_neighbors(Vector3i(1, 1, 1), grid_size).size(), 6)
	assert_eq(GFGrid3DMath.get_neighbors(Vector3i(1, 1, 1), grid_size, true).size(), 26)
	assert_eq(GFGrid3DMath.get_neighbors(Vector3i.ZERO, grid_size).size(), 3)


func test_find_path_a_star_avoids_blocked_cell() -> void:
	var blocked: Dictionary = {
		Vector3i(1, 0, 0): true,
	}
	var path: Array[Vector3i] = GFGrid3DMath.find_path_a_star(
		Vector3i(3, 1, 2),
		Vector3i(0, 0, 0),
		Vector3i(2, 0, 0),
		func(cell: Vector3i) -> bool:
			return not blocked.has(cell)
	)

	assert_false(path.is_empty(), "A* 应能绕过阻挡格。")
	assert_eq(_vector3i_at(path, 0), Vector3i(0, 0, 0))
	assert_eq(_vector3i_at(path, path.size() - 1), Vector3i(2, 0, 0))
	assert_false(path.has(Vector3i(1, 0, 0)))


func test_find_reachable_reports_costs_with_limit() -> void:
	var reachable: Dictionary = GFGrid3DMath.find_reachable(
		Vector3i(3, 3, 3),
		Vector3i(1, 1, 1),
		1.0,
		func(_cell: Vector3i) -> bool:
			return true
	)

	assert_eq(reachable.size(), 7)
	assert_eq(GFVariantData.get_option_float(reachable, Vector3i(1, 1, 1)), 0.0)
	assert_eq(GFVariantData.get_option_float(reachable, Vector3i(2, 1, 1)), 1.0)


func test_surface_neighbors_respect_step_limits() -> void:
	var walkable: Dictionary = {
		Vector3i(0, 1, 0): true,
		Vector3i(1, 2, 0): true,
		Vector3i(2, 3, 0): true,
	}

	var neighbors: Array[Vector3i] = GFGrid3DMath.get_surface_neighbors(
		Vector3i(0, 1, 0),
		Vector3i(3, 4, 1),
		func(cell: Vector3i) -> bool:
			return walkable.has(cell),
		1,
		1
	)

	assert_true(neighbors.has(Vector3i(1, 2, 0)))
	assert_false(neighbors.has(Vector3i(2, 3, 0)), "只应枚举一步水平移动范围内的表面邻居。")


func test_surface_neighbors_clamps_vertical_scan_to_grid() -> void:
	var visited: Array[Vector3i] = []
	var neighbors: Array[Vector3i] = GFGrid3DMath.get_surface_neighbors(
		Vector3i(0, 1, 0),
		Vector3i(2, 3, 1),
		func(candidate: Vector3i) -> bool:
			visited.append(candidate)
			return false,
		9_223_372_036_854_775_807,
		9_223_372_036_854_775_807,
		[Vector3i.RIGHT]
	)

	assert_true(neighbors.is_empty())
	assert_eq(
		visited,
		[Vector3i(1, 2, 0), Vector3i(1, 1, 0), Vector3i(1, 0, 0)],
		"巨大 step 配置也只能访问网格内的候选。"
	)


func test_surface_path_can_climb_with_step_constraints() -> void:
	var walkable: Dictionary = {
		Vector3i(0, 0, 0): true,
		Vector3i(1, 1, 0): true,
		Vector3i(2, 1, 0): true,
	}
	var path: Array[Vector3i] = GFGrid3DMath.find_surface_path_a_star(
		Vector3i(3, 3, 1),
		Vector3i(0, 0, 0),
		Vector3i(2, 1, 0),
		func(cell: Vector3i) -> bool:
			return walkable.has(cell),
		1,
		1
	)

	assert_eq(path, [Vector3i(0, 0, 0), Vector3i(1, 1, 0), Vector3i(2, 1, 0)])


func _vector3i_at(cells: Array[Vector3i], index: int) -> Vector3i:
	if index < 0 or index >= cells.size():
		return Vector3i.ZERO
	return cells[index]
