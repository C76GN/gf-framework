## 测试 GFHexGridMath 的坐标转换、邻居、范围、视线、寻路与 Flow Field。
extends GutTest


# --- 常量 ---

const GF_HEX_GRID_MATH = preload("res://addons/gf/standard/foundation/math/gf_hex_grid_math.gd")


# --- 测试 ---

func test_offset_cube_roundtrip_for_supported_layouts() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	for layout: int in [
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R,
		GF_HEX_GRID_MATH.OffsetLayout.EVEN_R,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_Q,
		GF_HEX_GRID_MATH.OffsetLayout.EVEN_Q,
	]:
		var cube: Vector3i = GF_HEX_GRID_MATH.offset_to_cube(cell, layout)
		var roundtrip: Vector2i = GF_HEX_GRID_MATH.cube_to_offset(cube, layout)

		assert_eq(cube.x + cube.y + cube.z, 0, "cube 坐标三轴和应为 0。")
		assert_eq(roundtrip, cell, "offset/cube 转换应可往返。")


func test_pixel_roundtrip_pointy_and_flat() -> void:
	var cell: Vector2i = Vector2i(2, 3)
	var pointy_pixel: Vector2 = GF_HEX_GRID_MATH.offset_to_pixel(
		cell,
		24.0,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R,
		GF_HEX_GRID_MATH.HexOrientation.POINTY_TOP
	)
	var flat_pixel: Vector2 = GF_HEX_GRID_MATH.offset_to_pixel(
		cell,
		24.0,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_Q,
		GF_HEX_GRID_MATH.HexOrientation.FLAT_TOP
	)

	assert_eq(
		GF_HEX_GRID_MATH.pixel_to_offset(
			pointy_pixel,
			24.0,
			GF_HEX_GRID_MATH.OffsetLayout.ODD_R,
			GF_HEX_GRID_MATH.HexOrientation.POINTY_TOP
		),
		cell,
		"pointy-top 像素转换应可往返。"
	)
	assert_eq(
		GF_HEX_GRID_MATH.pixel_to_offset(
			flat_pixel,
			24.0,
			GF_HEX_GRID_MATH.OffsetLayout.ODD_Q,
			GF_HEX_GRID_MATH.HexOrientation.FLAT_TOP
		),
		cell,
		"flat-top 像素转换应可往返。"
	)


func test_neighbors_and_distance_use_hex_topology() -> void:
	var neighbors: Array[Vector2i] = GF_HEX_GRID_MATH.get_neighbors(
		Vector2i(1, 1),
		Vector2i(4, 4),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)

	assert_eq(neighbors.size(), 6, "内部六边形格子应有 6 个邻居。")
	assert_eq(
		GF_HEX_GRID_MATH.distance(
			Vector2i(0, 0),
			Vector2i(2, 1),
			GF_HEX_GRID_MATH.OffsetLayout.ODD_R
		),
		3,
		"六边形距离应按 cube 拓扑计算。"
	)


func test_range_and_ring_filter_bounds() -> void:
	var range_cells: Array[Vector2i] = GF_HEX_GRID_MATH.get_range(
		Vector2i(2, 2),
		1,
		Vector2i(5, 5),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var ring_cells: Array[Vector2i] = GF_HEX_GRID_MATH.get_ring(
		Vector2i.ZERO,
		1,
		Vector2i(2, 2),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)

	assert_eq(range_cells.size(), 7, "半径 1 范围应包含中心和 6 个邻居。")
	assert_true(range_cells.has(Vector2i(2, 2)), "范围应包含中心。")
	assert_true(ring_cells.size() < 6, "边界附近的外环应被 grid_size 过滤。")
	assert_false(ring_cells.has(Vector2i(-1, 0)), "越界外环坐标不应进入结果。")


func test_line_of_sight_respects_blocking_cells() -> void:
	var line: Array[Vector2i] = GF_HEX_GRID_MATH.get_line(
		Vector2i(0, 0),
		Vector2i(3, 0),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var blocked: Dictionary = {
		line[1]: true,
	}

	assert_eq(_vector2i_at(line, 0), Vector2i.ZERO, "直线应从起点开始。")
	assert_eq(_vector2i_at(line, line.size() - 1), Vector2i(3, 0), "直线应抵达终点。")
	assert_false(
		GF_HEX_GRID_MATH.has_line_of_sight(
			Vector2i(0, 0),
			Vector2i(3, 0),
			func(cell: Vector2i) -> bool:
				return blocked.has(cell),
			GF_HEX_GRID_MATH.OffsetLayout.ODD_R
		),
		"中间格阻挡时视线应失败。"
	)


func test_find_path_a_star_avoids_blocked_hex() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
	}
	var path: Array[Vector2i] = GF_HEX_GRID_MATH.find_path_a_star(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)

	assert_false(path.is_empty(), "A* 应能绕过阻挡格。")
	assert_eq(_vector2i_at(path, 0), Vector2i.ZERO, "路径应从起点开始。")
	assert_eq(_vector2i_at(path, path.size() - 1), Vector2i(2, 0), "路径应抵达终点。")
	assert_false(path.has(Vector2i(1, 0)), "路径不应穿过阻挡格。")


func test_begin_path_a_star_search_reaches_goal_with_budget() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
	}
	var sync_path: Array[Vector2i] = GF_HEX_GRID_MATH.find_path_a_star(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var search_state: GFGraphPathSearchState = GF_HEX_GRID_MATH.begin_path_a_star_search(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var report: Dictionary = GFGraphMath.advance_path_search(search_state, 1)
	var guard: int = 0
	while not GFVariantData.get_option_bool(report, "finished") and guard < 32:
		report = GFGraphMath.advance_path_search(search_state, 1)
		guard += 1

	var path: Array = GFVariantData.get_option_array(report, "path")
	assert_true(GFVariantData.get_option_bool(report, "found"), "分步 Hex A* 应能找到路径。")
	assert_eq(path, sync_path, "分步 Hex A* 路径应与同步 A* 对齐。")
	assert_eq(GFVariantData.get_option_float(report, "cost", -1.0), _path_step_cost(path), "分步 Hex A* 成本应与路径步数对齐。")
	assert_eq(_array_vector2i(path, 0), Vector2i.ZERO, "路径应从起点开始。")
	assert_eq(_array_vector2i(path, path.size() - 1), Vector2i(2, 0), "路径应抵达终点。")
	assert_false(path.has(Vector2i(1, 0)), "分步路径不应穿过阻挡格。")


func test_begin_path_a_star_search_matches_sync_custom_cost_path() -> void:
	var expensive: Dictionary = {
		Vector2i(1, 0): true,
	}
	var sync_path: Array[Vector2i] = GF_HEX_GRID_MATH.find_path_a_star(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R,
		func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
			return 8.0 if expensive.has(to_cell) else 1.0
	)
	var search_state: GFGraphPathSearchState = GF_HEX_GRID_MATH.begin_path_a_star_search(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R,
		func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
			return 8.0 if expensive.has(to_cell) else 1.0
	)
	var report: Dictionary = GFGraphMath.advance_path_search(search_state, 1)
	var guard: int = 0
	while not GFVariantData.get_option_bool(report, "finished") and guard < 32:
		report = GFGraphMath.advance_path_search(search_state, 1)
		guard += 1

	var step_path: Array = GFVariantData.get_option_array(report, "path")
	assert_true(GFVariantData.get_option_bool(report, "found"), "自定义代价下分步 Hex A* 应找到路径。")
	assert_eq(step_path, sync_path, "自定义代价下分步 Hex A* 路径应与同步 A* 对齐。")
	assert_false(step_path.has(Vector2i(1, 0)), "自定义代价下 Hex A* 应避开高代价格子。")


func test_simplify_path_line_of_sight_respects_hex_blocking() -> void:
	var start: Vector2i = Vector2i.ZERO
	var goal: Vector2i = Vector2i(3, 0)
	var direct_line: Array[Vector2i] = GF_HEX_GRID_MATH.get_line(
		start,
		goal,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var blocked_cell: Vector2i = _vector2i_at(direct_line, 1)
	var blocked: Dictionary = {
		blocked_cell: true,
	}
	var path: Array[Vector2i] = GF_HEX_GRID_MATH.find_path_a_star(
		Vector2i(5, 5),
		start,
		goal,
		func(cell: Vector2i) -> bool:
			return not blocked.has(cell),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var simplified: Array[Vector2i] = GF_HEX_GRID_MATH.simplify_path_line_of_sight(
		path,
		func(cell: Vector2i) -> bool:
			return blocked.has(cell),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var open_simplified: Array[Vector2i] = GF_HEX_GRID_MATH.simplify_path_line_of_sight(
		path,
		Callable(),
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)

	assert_false(path.is_empty(), "测试路径应能绕过阻挡格。")
	assert_eq(_vector2i_at(simplified, 0), start, "抽稀后仍应保留起点。")
	assert_eq(_vector2i_at(simplified, simplified.size() - 1), goal, "抽稀后仍应保留终点。")
	assert_false(simplified.has(blocked_cell), "抽稀后路径不应包含阻挡格。")
	assert_true(simplified.size() > 2, "阻挡直线时不能直接抽稀为起终点。")
	assert_eq(open_simplified, [start, goal], "无阻挡时可直接抽稀为起终点。")


func test_flow_field_and_reachable_report_costs() -> void:
	var field: Dictionary = GF_HEX_GRID_MATH.build_flow_field(
		Vector2i(4, 4),
		[Vector2i(2, 0)],
		func(_cell: Vector2i) -> bool:
			return true,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)
	var costs: Dictionary = GFVariantData.get_option_dictionary(field, "costs", {})
	var directions: Dictionary = GFVariantData.get_option_dictionary(field, "directions", {})
	var reachable: Dictionary = GF_HEX_GRID_MATH.find_reachable(
		Vector2i(4, 4),
		Vector2i.ZERO,
		1.0,
		func(_cell: Vector2i) -> bool:
			return true,
		GF_HEX_GRID_MATH.OffsetLayout.ODD_R
	)

	assert_eq(GFVariantData.get_option_float(costs, Vector2i(2, 0), 0.0), 0.0, "目标格代价应为 0。")
	assert_true(GFVariantData.get_option_value(directions, Vector2i.ZERO) != null, "Flow Field 应为可达格提供方向。")
	assert_true(reachable.has(Vector2i.ZERO), "可达结果应包含起点。")
	assert_true(reachable.size() <= 7, "移动代价 1 最多包含中心和一圈邻居。")


func _vector2i_at(cells: Array[Vector2i], index: int) -> Vector2i:
	if index < 0 or index >= cells.size():
		return Vector2i.ZERO
	return cells[index]


func _array_vector2i(cells: Array, index: int) -> Vector2i:
	if index < 0 or index >= cells.size():
		return Vector2i.ZERO
	var value: Variant = cells[index]
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO


func _path_step_cost(cells: Array) -> float:
	return maxf(0.0, float(cells.size() - 1))
