## 测试 GFGridMath 的索引转换、邻居、范围/直线、泛洪、BFS 与两折连线判断。
extends GutTest


const GF_GRID_MATH = preload("res://addons/gf/standard/foundation/math/gf_grid_math.gd")
const GF_GRID_CONNECTION_MATH_2D = preload("res://addons/gf/standard/foundation/math/gf_grid_connection_math_2d.gd")
const GF_GRID_COORDINATE_MATH_2D = preload("res://addons/gf/standard/foundation/math/gf_grid_coordinate_math_2d.gd")
const GF_GRID_GENERATION_MATH_2D = preload("res://addons/gf/standard/foundation/math/gf_grid_generation_math_2d.gd")
const GF_GRID_PATH_MATH_2D = preload("res://addons/gf/standard/foundation/math/gf_grid_path_math_2d.gd")


# --- 测试 ---

func test_cell_index_roundtrip() -> void:
	var cell: Vector2i = Vector2i(2, 3)
	var index: int = GF_GRID_MATH.cell_to_index(cell, 5)

	assert_eq(index, 17, "二维坐标应正确转换为一维索引。")
	assert_eq(GF_GRID_MATH.index_to_cell(index, 5), cell, "一维索引应正确还原为二维坐标。")


func test_specialized_grid_classes_are_direct_public_entries() -> void:
	var cell_index: int = GF_GRID_COORDINATE_MATH_2D.cell_to_index(Vector2i(2, 1), 4)
	var path: Array[Vector2i] = GF_GRID_PATH_MATH_2D.find_path_bfs(
		Vector2i(3, 1),
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(_cell: Vector2i) -> bool:
			return true
	)
	var maze_report: Dictionary = GF_GRID_GENERATION_MATH_2D.generate_rect_maze_backtracker(
		Vector2i(2, 1),
		Vector2i.ZERO,
		Callable(),
		{ "seed": 1 }
	)
	var can_connect: bool = GF_GRID_CONNECTION_MATH_2D.can_connect_with_max_turns(
		Vector2i(2, 1),
		Vector2i.ZERO,
		Vector2i(1, 0),
		func(_cell: Vector2i) -> bool:
			return true
	)

	assert_eq(cell_index, 6, "坐标类应直接提供索引转换。")
	assert_eq(path, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)], "路径类应直接提供 BFS。")
	assert_true(GFVariantData.get_option_bool(maze_report, "ok"), "生成类应直接提供迷宫拓扑报告。")
	assert_true(can_connect, "连接类应直接提供最大转折连通判断。")


func test_invalid_index_and_bounds_inputs_return_safe_defaults() -> void:
	assert_eq(GF_GRID_MATH.cell_to_index(Vector2i(1, 1), 0), -1, "无效宽度应返回 -1。")
	assert_eq(GF_GRID_MATH.index_to_cell(-1, 4), Vector2i(-1, -1), "负索引应返回哨兵坐标。")
	assert_false(GF_GRID_MATH.is_in_bounds(Vector2i.ZERO, Vector2i.ZERO), "零尺寸网格没有有效格子。")


func test_chunk_coordinate_conversion_uses_floor_for_negative_world_positions() -> void:
	var chunk_size: Vector2i = Vector2i(64, 32)

	assert_eq(
		GF_GRID_MATH.world_to_chunk_cell(Vector2(127.9, 31.9), chunk_size),
		Vector2i(1, 0),
		"正世界坐标应落入对应 chunk。"
	)
	assert_eq(
		GF_GRID_MATH.world_to_chunk_cell(Vector2(-0.1, -0.1), chunk_size),
		Vector2i(-1, -1),
		"负世界坐标应使用 floor 语义落入前一个 chunk。"
	)
	assert_eq(
		GF_GRID_MATH.chunk_cell_to_world_origin(Vector2i(-1, 2), chunk_size),
		Vector2(-64.0, 64.0),
		"chunk 原点应支持负坐标。"
	)
	assert_eq(
		GF_GRID_MATH.chunk_cell_to_world_center(Vector2i(-1, 2), chunk_size),
		Vector2(-32.0, 80.0),
		"chunk 中心应基于原点加半个 chunk 尺寸。"
	)
	assert_eq(
		GF_GRID_MATH.world_to_chunk_cell(Vector2(10.0, 10.0), Vector2i.ZERO),
		Vector2i.ZERO,
		"无效 chunk_size 应返回安全默认值。"
	)


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


func test_bounded_ranges_intersect_before_enumeration() -> void:
	var bounded_rectangle: Array[Vector2i] = GF_GRID_MATH.get_rectangle_cells(
		Vector2i(-2_147_483_648, -2_147_483_648),
		Vector2i(2_147_483_647, 2_147_483_647),
		Vector2i(2, 2)
	)
	var bounded_range: Array[Vector2i] = GF_GRID_MATH.get_range(
		Vector2i.ZERO,
		1_000_000_000,
		Vector2i(2, 2),
		false
	)
	var bounded_ring: Array[Vector2i] = GF_GRID_MATH.get_ring(
		Vector2i.ZERO,
		1_000_000_000,
		Vector2i(2, 2),
		true
	)

	assert_eq(
		bounded_rectangle,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	)
	assert_eq(bounded_range, bounded_rectangle, "有界范围工作量应由实际网格交集决定。")
	assert_true(bounded_ring.is_empty(), "小网格中不存在距离十亿的环格。")


func test_chunk_window_supports_circle_square_and_diamond_shapes() -> void:
	var center: Vector2i = Vector2i(10, -2)
	var circle: Array[Vector2i] = GF_GRID_MATH.get_chunk_window(center, 2)
	var square: Array[Vector2i] = GF_GRID_MATH.get_chunk_window(Vector2i.ZERO, 1, &"square")
	var diamond: Array[Vector2i] = GF_GRID_MATH.get_chunk_window(Vector2i.ZERO, 1, &"diamond")

	assert_eq(circle.size(), 13, "圆形 chunk 窗口应使用欧氏半径筛选候选。")
	assert_eq(circle[0], Vector2i(10, -4), "chunk 窗口应按 y/x 稳定顺序返回。")
	assert_true(circle.has(Vector2i(12, -2)), "圆形窗口应包含半径边界上的正交 chunk。")
	assert_false(circle.has(Vector2i(12, 0)), "圆形窗口不应包含半径外的角落 chunk。")
	assert_eq(square.size(), 9, "方形 chunk 窗口应包含完整 3x3。")
	assert_true(square.has(Vector2i(1, 1)), "方形窗口应包含角落 chunk。")
	assert_eq(diamond.size(), 5, "菱形 chunk 窗口应使用曼哈顿半径。")
	assert_true(GF_GRID_MATH.get_chunk_window(Vector2i.ZERO, -1).is_empty(), "负半径应返回空窗口。")


func test_diff_cells_returns_stable_unique_added_removed_and_kept_cells() -> void:
	var previous_cells: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
	]
	var next_cells: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(1, 0),
		Vector2i(3, 0),
		Vector2i(3, 0),
	]
	var unchanged_previous: Array[Vector2i] = [Vector2i.ONE]
	var unchanged_next: Array[Vector2i] = [Vector2i.ONE]
	var diff: Dictionary = GF_GRID_MATH.diff_cells(previous_cells, next_cells)
	var unchanged: Dictionary = GF_GRID_MATH.diff_cells(unchanged_previous, unchanged_next)

	assert_eq(GFVariantData.get_option_array(diff, "added"), [Vector2i(3, 0)], "新增格应按 next 首次出现顺序去重。")
	assert_eq(GFVariantData.get_option_array(diff, "removed"), [Vector2i(0, 0)], "移除格应按 previous 首次出现顺序去重。")
	assert_eq(
		GFVariantData.get_option_array(diff, "kept"),
		[Vector2i(2, 0), Vector2i(1, 0)],
		"保留格应按 next 顺序返回，便于按新窗口加载顺序处理。"
	)
	assert_true(GFVariantData.get_option_bool(diff, "changed"), "集合有增删时 changed 应为 true。")
	assert_eq(GFVariantData.get_option_int(diff, "previous_count"), 3, "旧集合计数应使用去重数量。")
	assert_eq(GFVariantData.get_option_int(diff, "next_count"), 3, "新集合计数应使用去重数量。")
	assert_false(GFVariantData.get_option_bool(unchanged, "changed"), "集合无增删时 changed 应为 false。")


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


func test_generate_rect_maze_backtracker_returns_spanning_tree_report() -> void:
	var report: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(4, 3),
		Vector2i.ZERO,
		Callable(),
		{ "seed": 17 }
	)
	var edges: Array = GFVariantData.get_option_array(report, "edges")
	var connections: Dictionary = GFVariantData.get_option_dictionary(report, "connections")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效矩形网格应生成迷宫报告。")
	assert_true(GFVariantData.get_option_bool(report, "complete"), "无禁用格时应访问全部格子。")
	assert_eq(GFVariantData.get_option_int(report, "available_count"), 12, "报告应记录可用格数量。")
	assert_eq(GFVariantData.get_option_int(report, "visited_count"), 12, "报告应记录访问格数量。")
	assert_eq(GFVariantData.get_option_int(report, "edge_count"), 11, "完美迷宫开放边数量应为格子数减一。")
	assert_eq(edges.size(), 11, "开放边数组数量应和报告一致。")
	assert_eq(_connection_count(connections, Vector2i.ZERO), 1, "起点应至少有一个开放连接。")


func test_generate_rect_maze_backtracker_is_seed_deterministic() -> void:
	var first_report: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Callable(),
		{ "seed": 1234 }
	)
	var second_report: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(3, 3),
		Vector2i.ZERO,
		Callable(),
		{ "seed": 1234 }
	)

	assert_eq(
		GFVariantData.get_option_array(first_report, "edges"),
		GFVariantData.get_option_array(second_report, "edges"),
		"相同 seed 应生成稳定开放边顺序。"
	)


func test_generate_rect_maze_backtracker_reports_unreachable_enabled_cells() -> void:
	var report: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(3, 1),
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell != Vector2i(1, 0),
		{ "seed": 5 }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "起点有效时可生成起点连通分量。")
	assert_false(GFVariantData.get_option_bool(report, "complete"), "禁用格隔断后不应声称访问全部可用格。")
	assert_eq(GFVariantData.get_option_int(report, "available_count"), 2, "报告应保留可用格统计。")
	assert_eq(GFVariantData.get_option_int(report, "blocked_count"), 1, "报告应保留禁用格统计。")
	assert_eq(GFVariantData.get_option_int(report, "visited_count"), 1, "访问数量应只包含起点连通分量。")


func test_generate_rect_maze_backtracker_rejects_invalid_inputs() -> void:
	var invalid_size: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(Vector2i.ZERO)
	var too_large: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(4, 4),
		Vector2i.ZERO,
		Callable(),
		{ "max_cells": 4 }
	)
	var blocked_start: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(2, 2),
		Vector2i.ZERO,
		func(cell: Vector2i) -> bool:
			return cell != Vector2i.ZERO
	)

	assert_false(GFVariantData.get_option_bool(invalid_size, "ok"), "无效尺寸应返回失败报告。")
	assert_false(GFVariantData.get_option_bool(too_large, "ok"), "超过 max_cells 应返回失败报告。")
	assert_false(GFVariantData.get_option_bool(blocked_start, "ok"), "起点不可用应返回失败报告。")


func test_generate_cellular_automata_map_is_seed_deterministic() -> void:
	var first_report: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
		Vector2i(4, 3),
		Callable(),
		{
			"seed": 91,
			"alive_chance": 0.45,
			"iterations": 2,
			"outside_alive": false,
		}
	)
	var second_report: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
		Vector2i(4, 3),
		Callable(),
		{
			"seed": 91,
			"alive_chance": 0.45,
			"iterations": 2,
			"outside_alive": false,
		}
	)
	var alive_cells: Array[Vector2i] = _option_vector2i_array(first_report, "alive_cells")

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "有效网格应生成细胞自动机报告。")
	assert_eq(
		alive_cells,
		_option_vector2i_array(second_report, "alive_cells"),
		"相同 seed 和规则应生成稳定结果。"
	)
	assert_eq(GFVariantData.get_option_int(first_report, "cell_count"), 12, "报告应记录总格子数。")
	assert_eq(
		GFVariantData.get_option_int(first_report, "alive_count")
			+ GFVariantData.get_option_int(first_report, "dead_count"),
		12,
		"存活与死亡计数之和应等于总格子数。"
	)


func test_generate_cellular_automata_map_accepts_initial_callback_and_rules() -> void:
	var report: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
		Vector2i(3, 3),
		func(cell: Vector2i) -> bool:
			return cell == Vector2i(1, 1),
		{
			"iterations": 1,
			"include_diagonal": true,
			"outside_alive": false,
			"survive_min": 0,
			"survive_max": 8,
			"birth_min": 1,
			"birth_max": 8,
		}
	)
	var cells: Dictionary = GFVariantData.get_option_dictionary(report, "cells")
	var alive_cells: Array[Vector2i] = _option_vector2i_array(report, "alive_cells")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "回调初始化应能参与细胞自动机生成。")
	assert_eq(GFVariantData.get_option_int(report, "alive_count"), 9, "中心存活格应按规则扩散到整个 3x3。")
	assert_eq(alive_cells[0], Vector2i.ZERO, "存活格列表应按 y/x 稳定顺序返回。")
	assert_true(GFVariantData.get_option_bool(cells, Vector2i(2, 2), false), "cells 字典应保留最终布尔状态。")


func test_generate_cellular_automata_map_rejects_invalid_inputs() -> void:
	var invalid_size: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(Vector2i.ZERO)
	var too_large: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
		Vector2i(4, 4),
		Callable(),
		{ "max_cells": 4 }
	)
	var invalid_rule: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
		Vector2i(2, 2),
		Callable(),
		{
			"include_diagonal": false,
			"survive_min": 5,
			"survive_max": 4,
		}
	)

	assert_false(GFVariantData.get_option_bool(invalid_size, "ok"), "无效尺寸应返回失败报告。")
	assert_false(GFVariantData.get_option_bool(too_large, "ok"), "超过 max_cells 应返回失败报告。")
	assert_false(GFVariantData.get_option_bool(invalid_rule, "ok"), "无效规则范围应返回失败报告。")


func test_generate_cellular_automata_map_rejects_non_finite_alive_chance() -> void:
	for invalid_chance: float in [NAN, INF, -INF]:
		var report: Dictionary = GF_GRID_MATH.generate_cellular_automata_map(
			Vector2i(2, 2),
			Callable(),
			{ "alive_chance": invalid_chance }
		)
		var reported_chance: float = GFVariantData.get_option_float(report, "alive_chance")

		assert_false(GFVariantData.get_option_bool(report, "ok"), "非有限概率必须返回失败报告。")
		assert_eq(GFVariantData.get_option_string(report, "error"), "alive_chance must be finite.")
		assert_false(is_nan(reported_chance) or is_inf(reported_chance), "失败报告本身也必须保持 JSON-safe 数值。")


func test_find_cell_regions_groups_unique_cells_with_stable_indices() -> void:
	var report: Dictionary = GF_GRID_MATH.find_cell_regions(
		[
			Vector2i(4, 4),
			Vector2i(1, 0),
			Vector2i.ZERO,
			Vector2i(2, 0),
			Vector2i(4, 4),
		]
	)
	var regions: Array = GFVariantData.get_option_array(report, "regions")
	var region_indices: Dictionary = GFVariantData.get_option_dictionary(report, "region_indices")
	var first_region: Array = GFVariantData.as_array(regions[0])
	var second_region: Array = GFVariantData.as_array(regions[1])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效格子集合应返回区域报告。")
	assert_eq(GFVariantData.get_option_int(report, "input_count"), 5, "报告应保留原始输入数量。")
	assert_eq(GFVariantData.get_option_int(report, "cell_count"), 4, "重复格子应被去重。")
	assert_eq(GFVariantData.get_option_int(report, "region_count"), 2, "应识别两个互不连通区域。")
	assert_false(GFVariantData.get_option_bool(report, "all_connected"), "多个区域不应标记为全连通。")
	assert_eq(GFVariantData.get_option_int(report, "largest_region_index"), 0, "最大区域索引应稳定指向首个三格区域。")
	assert_eq(GFVariantData.get_option_int(region_indices, Vector2i(2, 0), -1), 0, "格子索引应指向所在区域。")
	assert_eq(first_region, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)], "区域内格子应按 y/x 稳定排序。")
	assert_eq(second_region, [Vector2i(4, 4)], "孤立格应单独形成区域。")


func test_find_cell_regions_respects_diagonal_connectivity_option() -> void:
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 1)]
	var orthogonal_report: Dictionary = GF_GRID_MATH.find_cell_regions(cells)
	var diagonal_report: Dictionary = GF_GRID_MATH.find_cell_regions(cells, { "include_diagonal": true })

	assert_eq(GFVariantData.get_option_int(orthogonal_report, "region_count"), 2, "默认四邻域不应跨对角连通。")
	assert_eq(GFVariantData.get_option_int(diagonal_report, "region_count"), 1, "开启八邻域后对角格应连通。")
	assert_true(GFVariantData.get_option_bool(diagonal_report, "all_connected"), "八邻域连通后应标记为全连通。")


func test_filter_cell_regions_by_size_returns_kept_and_removed_cells() -> void:
	var report: Dictionary = GF_GRID_GENERATION_MATH_2D.filter_cell_regions_by_size(
		[
			Vector2i.ZERO,
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(5, 5),
		],
		2
	)
	var kept_cells: Array[Vector2i] = _option_vector2i_array(report, "kept_cells")
	var removed_cells: Array[Vector2i] = _option_vector2i_array(report, "removed_cells")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "区域尺寸过滤应返回成功报告。")
	assert_eq(GFVariantData.get_option_int(report, "kept_region_count"), 1, "大区域应被保留。")
	assert_eq(GFVariantData.get_option_int(report, "removed_region_count"), 1, "小区域应被移除。")
	assert_eq(kept_cells, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)], "保留格子应按稳定顺序输出。")
	assert_eq(removed_cells, [Vector2i(5, 5)], "孤立小区域应进入 removed_cells。")


func test_cell_region_reports_reject_invalid_inputs() -> void:
	var too_large: Dictionary = GF_GRID_MATH.find_cell_regions(
		[Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)],
		{ "max_cells": 2 }
	)
	var negative_minimum: Dictionary = GF_GRID_MATH.filter_cell_regions_by_size(
		[Vector2i.ZERO],
		-1
	)

	assert_false(GFVariantData.get_option_bool(too_large, "ok"), "超过 max_cells 的区域分析应返回失败报告。")
	assert_eq(GFVariantData.get_option_string(too_large, "error"), "input_count exceeds max_cells.")
	assert_false(GFVariantData.get_option_bool(negative_minimum, "ok"), "负数最小区域尺寸应返回失败报告。")
	assert_eq(GFVariantData.get_option_string(negative_minimum, "error"), "minimum_region_size must be non-negative.")


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


func test_grid_reports_have_json_compatible_export() -> void:
	var maze_report: Dictionary = GF_GRID_MATH.generate_rect_maze_backtracker(
		Vector2i(2, 1),
		Vector2i.ZERO,
		Callable(),
		{ "seed": 3 }
	)
	var flow_report: Dictionary = GF_GRID_MATH.build_flow_field(
		Vector2i(2, 1),
		[Vector2i(1, 0)],
		func(_cell: Vector2i) -> bool:
			return true
	)
	var safe_report: Dictionary = GF_GRID_MATH.to_json_compatible_report({
		"maze": maze_report,
		"flow": flow_report,
	})
	var json_text: String = JSON.stringify(safe_report)

	assert_false(json_text.is_empty(), "JSON-safe GridMath 报告应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe GridMath 报告不应依赖 JSON.stringify 降级非法值。")


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


func _option_vector2i_array(options: Dictionary, key: Variant) -> Array[Vector2i]:
	var values: Array = GFVariantData.get_option_array(options, key)
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if value is Vector2i:
			var cell: Vector2i = value
			result.append(cell)
	return result


func _connection_count(connections: Dictionary, cell: Vector2i) -> int:
	return GFVariantData.get_option_array(connections, cell).size()
