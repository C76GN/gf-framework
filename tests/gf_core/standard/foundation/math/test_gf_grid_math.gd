## 测试 GFGridMath 的索引转换、邻居、范围/直线、泛洪、BFS 与两折连线判断。
extends GutTest


const GF_GRID_MATH = preload("res://addons/gf/standard/foundation/math/gf_grid_math.gd")


# --- 测试 ---

func test_cell_index_roundtrip() -> void:
	var cell: Vector2i = Vector2i(2, 3)
	var index: int = GF_GRID_MATH.cell_to_index(cell, 5)

	assert_eq(index, 17, "二维坐标应正确转换为一维索引。")
	assert_eq(GF_GRID_MATH.index_to_cell(index, 5), cell, "一维索引应正确还原为二维坐标。")


func test_invalid_index_and_bounds_inputs_return_safe_defaults() -> void:
	assert_eq(GF_GRID_MATH.cell_to_index(Vector2i(1, 1), 0), -1, "无效宽度应返回 -1。")
	assert_eq(GF_GRID_MATH.index_to_cell(-1, 4), Vector2i(-1, -1), "负索引应返回哨兵坐标。")
	assert_false(GF_GRID_MATH.is_in_bounds(Vector2i.ZERO, Vector2i.ZERO), "零尺寸网格没有有效格子。")


func test_get_neighbors_filters_bounds() -> void:
	var neighbors: Array[Vector2i] = GF_GRID_MATH.get_neighbors(Vector2i.ZERO, Vector2i(3, 3))

	assert_eq(neighbors.size(), 2, "左上角正交邻居应只有 2 个。")
	assert_true(neighbors.has(Vector2i.RIGHT), "左上角应包含右侧邻居。")
	assert_true(neighbors.has(Vector2i.DOWN), "左上角应包含下方邻居。")


func test_rectangle_cells_are_endpoint_inclusive_and_row_major() -> void:
	var cells: Array[Vector2i] = GF_GRID_MATH.get_rectangle_cells(Vector2i(2, 1), Vector2i(0, 2))
	var bounded: Array[Vector2i] = GF_GRID_MATH.get_rectangle_cells(
		Vector2i(-1, -1),
		Vector2i(1, 1),
		Vector2i(2, 2)
	)

	assert_eq(
		cells,
		[
			Vector2i(0, 1),
			Vector2i(1, 1),
			Vector2i(2, 1),
			Vector2i(0, 2),
			Vector2i(1, 2),
			Vector2i(2, 2),
		],
		"矩形格子应包含两个端点并按稳定顺序返回。"
	)
	assert_eq(
		bounded,
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(0, 1),
			Vector2i(1, 1),
		],
		"矩形生成应按可选网格尺寸过滤越界格子。"
	)


func test_range_and_ring_follow_movement_topology() -> void:
	var orthogonal_range: Array[Vector2i] = GF_GRID_MATH.get_range(Vector2i(2, 2), 1)
	var diagonal_range: Array[Vector2i] = GF_GRID_MATH.get_range(
		Vector2i(2, 2),
		1,
		Vector2i(-1, -1),
		true
	)
	var orthogonal_ring: Array[Vector2i] = GF_GRID_MATH.get_ring(Vector2i(2, 2), 2)
	var bounded_ring: Array[Vector2i] = GF_GRID_MATH.get_ring(Vector2i.ZERO, 1, Vector2i(2, 2), true)

	assert_eq(orthogonal_range.size(), 5, "曼哈顿半径 1 应包含中心和四向邻居。")
	assert_false(orthogonal_range.has(Vector2i(1, 1)), "曼哈顿范围不应包含对角格。")
	assert_eq(diagonal_range.size(), 9, "切比雪夫半径 1 应包含 3x3 方块。")
	assert_eq(orthogonal_ring.size(), 8, "曼哈顿半径 2 外环应包含 8 个格子。")
	assert_true(orthogonal_ring.has(Vector2i(4, 2)), "曼哈顿外环应包含半径边界格。")
	assert_false(orthogonal_ring.has(Vector2i(3, 2)), "曼哈顿外环不应包含半径内部格。")
	assert_eq(bounded_ring.size(), 3, "切比雪夫外环应能按边界过滤左上角越界格。")


func test_line_and_line_of_sight_use_bresenham_cells() -> void:
	var line: Array[Vector2i] = GF_GRID_MATH.get_line(Vector2i.ZERO, Vector2i(3, 2))
	var blocked: Dictionary = {
		Vector2i(1, 1): true,
	}
	var blocked_los: bool = GF_GRID_MATH.has_line_of_sight(
		Vector2i.ZERO,
		Vector2i(3, 2),
		func(cell: Vector2i) -> bool:
			return blocked.has(cell)
	)
	var endpoint_ignored_los: bool = GF_GRID_MATH.has_line_of_sight(
		Vector2i.ZERO,
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell == Vector2i.ZERO
	)
	var endpoint_checked_los: bool = GF_GRID_MATH.has_line_of_sight(
		Vector2i.ZERO,
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell == Vector2i.ZERO,
		true
	)

	assert_eq(
		line,
		[
			Vector2i(0, 0),
			Vector2i(1, 1),
			Vector2i(2, 1),
			Vector2i(3, 2),
		],
		"直线应按 Bresenham 生成包含起终点的格子。"
	)
	assert_false(blocked_los, "中间格阻挡时视线应失败。")
	assert_true(endpoint_ignored_los, "默认不检查端点时，起终点阻挡不应影响视线。")
	assert_false(endpoint_checked_los, "显式检查端点时，端点阻挡应让视线失败。")


func test_flood_fill_returns_connected_matching_cells() -> void:
	var filled: Array[Vector2i] = GF_GRID_MATH.flood_fill(
		Vector2i(4, 3),
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell.x < 2
	)

	assert_eq(filled.size(), 6, "x < 2 的两列格子应全部连通。")
	assert_true(filled.has(Vector2i(1, 2)), "泛洪结果应包含匹配区域内的底部格子。")
	assert_false(filled.has(Vector2i(2, 0)), "泛洪结果不应包含不匹配格子。")


func test_flood_fill_rejects_invalid_start_and_callable() -> void:
	var outside: Array[Vector2i] = GF_GRID_MATH.flood_fill(
		Vector2i(2, 2),
		Vector2i(-1, 0),
		func(_cell: Vector2i) -> bool:
			return true
	)
	var invalid_callable: Array[Vector2i] = GF_GRID_MATH.flood_fill(Vector2i(2, 2), Vector2i.ZERO, Callable())

	assert_true(outside.is_empty(), "起点越界时泛洪搜索应返回空数组。")
	assert_true(invalid_callable.is_empty(), "无效匹配回调不应导致崩溃。")


func test_diagonal_neighbors_unlock_diagonal_flood_fill() -> void:
	var filled: Array[Vector2i] = GF_GRID_MATH.flood_fill(
		Vector2i(2, 2),
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell == Vector2i.ZERO or cell == Vector2i(1, 1),
		true
	)

	assert_eq(filled, [Vector2i.ZERO, Vector2i(1, 1)], "允许斜向连通时应能跨对角格泛洪。")


func test_find_path_bfs_avoids_blocked_cells() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
		Vector2i(1, 1): true,
	}
	var path: Array[Vector2i] = GF_GRID_MATH.find_path_bfs(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell)
	)

	assert_false(path.is_empty(), "BFS 应能绕过障碍找到路径。")
	assert_eq(_vector2i_at(path, 0), Vector2i.ZERO, "路径应从起点开始。")
	assert_eq(_vector2i_at(path, path.size() - 1), Vector2i(2, 0), "路径应抵达终点。")
	assert_false(path.has(Vector2i(1, 0)), "路径不应穿过障碍。")


func test_find_path_bfs_rejects_blocked_goal_and_invalid_callable() -> void:
	var blocked_goal: Array[Vector2i] = GF_GRID_MATH.find_path_bfs(
		Vector2i(2, 2),
		Vector2i.ZERO,
		Vector2i(1, 1),
		func(cell: Vector2i) -> bool:
			return cell != Vector2i(1, 1)
	)
	var invalid_callable: Array[Vector2i] = GF_GRID_MATH.find_path_bfs(
		Vector2i(2, 2),
		Vector2i.ZERO,
		Vector2i(1, 1),
		Callable()
	)

	assert_true(blocked_goal.is_empty(), "终点不可通行时 BFS 应返回空数组。")
	assert_true(invalid_callable.is_empty(), "无效通行回调应返回空数组。")


func test_find_path_a_star_uses_custom_step_cost() -> void:
	var expensive: Dictionary = {
		Vector2i(1, 0): true,
	}
	var path: Array[Vector2i] = GF_GRID_MATH.find_path_a_star(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true,
		false,
		func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
			return 10.0 if expensive.has(to_cell) else 1.0
	)

	assert_false(path.is_empty(), "A* 应能找到可达路径。")
	assert_eq(_vector2i_at(path, 0), Vector2i.ZERO, "路径应从起点开始。")
	assert_eq(_vector2i_at(path, path.size() - 1), Vector2i(2, 0), "路径应抵达终点。")
	assert_false(path.has(Vector2i(1, 0)), "A* 应避开高代价格子。")


func test_find_path_a_star_allows_diagonal_path() -> void:
	var path: Array[Vector2i] = GF_GRID_MATH.find_path_a_star(
		Vector2i(2, 2),
		Vector2i.ZERO,
		Vector2i(1, 1),
		func(_cell: Vector2i) -> bool:
			return true,
		true,
		Callable(),
		&"octile"
	)

	assert_eq(path, [Vector2i.ZERO, Vector2i(1, 1)], "允许斜向移动时 A* 应能直接走对角。")


func test_begin_path_a_star_search_matches_sync_path_with_budget() -> void:
	var expensive: Dictionary = {
		Vector2i(1, 0): true,
	}
	var search_state: GFGraphPathSearchState = GF_GRID_MATH.begin_path_a_star_search(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true,
		false,
		func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
			return 10.0 if expensive.has(to_cell) else 1.0
	)
	var report: Dictionary = GFGraphMath.advance_path_search(search_state, 1)
	var guard: int = 0
	while not GFVariantData.get_option_bool(report, "finished") and guard < 16:
		report = GFGraphMath.advance_path_search(search_state, 1)
		guard += 1

	var sync_path: Array[Vector2i] = GF_GRID_MATH.find_path_a_star(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true,
		false,
		func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
			return 10.0 if expensive.has(to_cell) else 1.0
	)

	assert_true(GFVariantData.get_option_bool(report, "found"), "分步网格 A* 应能找到路径。")
	assert_eq(GFVariantData.get_option_array(report, "path"), sync_path)


func test_simplify_path_line_of_sight_keeps_blocked_corner() -> void:
	var path: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(2, 2),
	]
	var blocked: Dictionary = {
		Vector2i(1, 1): true,
	}
	var simplified: Array[Vector2i] = GF_GRID_MATH.simplify_path_line_of_sight(
		path,
		func(cell: Vector2i) -> bool:
			return blocked.has(cell)
	)
	var open_simplified: Array[Vector2i] = GF_GRID_MATH.simplify_path_line_of_sight(path, Callable())

	assert_eq(
		simplified,
		[Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2)],
		"抽稀不能穿过阻挡格，必须保留必要转角。"
	)
	assert_eq(open_simplified, [Vector2i(0, 0), Vector2i(2, 2)], "无阻挡时可直接抽稀到终点。")


func test_build_flow_field_points_toward_nearest_goal() -> void:
	var field: Dictionary = GF_GRID_MATH.build_flow_field(
		Vector2i(3, 1),
		[Vector2i(2, 0)],
		func(_cell: Vector2i) -> bool:
			return true
	)
	var directions: Dictionary = GFVariantData.get_option_dictionary(field, "directions", {})
	var costs: Dictionary = GFVariantData.get_option_dictionary(field, "costs", {})

	assert_eq(_option_vector2i(directions, Vector2i(0, 0)), Vector2i.RIGHT, "Flow Field 应指向下一步方向。")
	assert_eq(_option_vector2i(directions, Vector2i(2, 0)), Vector2i.ZERO, "目标格方向应为 ZERO。")
	assert_eq(GFVariantData.get_option_float(costs, Vector2i(0, 0), 0.0), 2.0, "Flow Field 应记录到目标的累计代价。")


func test_can_connect_with_max_turns_uses_outer_border() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
	}
	var can_connect: bool = GF_GRID_MATH.can_connect_with_max_turns(
		Vector2i(3, 1),
		Vector2i(0, 0),
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		2,
		true
	)

	assert_true(can_connect, "允许外圈虚拟空格时，应能绕过中间障碍完成两折连线。")


func test_can_connect_with_max_turns_rejects_excess_turns() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
	}
	var can_connect: bool = GF_GRID_MATH.can_connect_with_max_turns(
		Vector2i(3, 1),
		Vector2i(0, 0),
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		1,
		true
	)

	assert_false(can_connect, "只允许一次转折时，绕过中间障碍的外圈路径应失败。")


func _vector2i_at(cells: Array[Vector2i], index: int) -> Vector2i:
	if index < 0 or index >= cells.size():
		return Vector2i.ZERO
	return cells[index]


func _option_vector2i(options: Dictionary, key: Variant) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO
