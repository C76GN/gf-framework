## 测试 GFGraphMath 的 Dijkstra、A* 与距离图。
extends GutTest


# --- 常量 ---

const GF_GRAPH_MATH = preload("res://addons/gf/standard/foundation/math/gf_graph_math.gd")
const GF_GRAPH_PATH_SEARCH_STATE = preload("res://addons/gf/standard/foundation/math/gf_graph_path_search_state.gd")


# --- 测试 ---

func test_dijkstra_prefers_lowest_cost_path() -> void:
	var graph: Dictionary = {
		"A": ["B", "C"],
		"B": ["D"],
		"C": ["D"],
		"D": [],
	}
	var costs: Dictionary = {
		"A:B": 1.0,
		"B:D": 1.0,
		"A:C": 1.0,
		"C:D": 10.0,
	}

	var path: Array = GF_GRAPH_MATH.find_path_dijkstra(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(from_node: Variant, to_node: Variant) -> float:
			return GFVariantData.get_option_float(costs, "%s:%s" % [from_node, to_node], 1.0)
	)

	assert_eq(path, ["A", "B", "D"])


func test_astar_uses_custom_variant_nodes_and_heuristic() -> void:
	var graph: Dictionary = {
		Vector2i(0, 0): [Vector2i(1, 0), Vector2i(0, 1)],
		Vector2i(1, 0): [Vector2i(2, 0)],
		Vector2i(0, 1): [Vector2i(1, 1)],
		Vector2i(1, 1): [Vector2i(2, 0)],
		Vector2i(2, 0): [],
	}

	var path: Array = GF_GRAPH_MATH.find_path_a_star(
		Vector2i.ZERO,
		Vector2i(2, 0),
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		Callable(),
		func(node: Variant, goal: Variant) -> float:
			var from_cell: Vector2i = _as_vector2i(node)
			var goal_cell: Vector2i = _as_vector2i(goal)
			return float(absi(goal_cell.x - from_cell.x) + absi(goal_cell.y - from_cell.y))
	)

	assert_eq(_array_vector2i(path, 0), Vector2i.ZERO)
	assert_eq(_array_vector2i(path, path.size() - 1), Vector2i(2, 0))
	assert_true(path.size() <= 3, "A* 应优先选择启发函数指向的短路径。")


func test_path_search_advances_with_fixed_budget() -> void:
	var graph: Dictionary = {
		"A": ["B", "C"],
		"B": ["D"],
		"C": ["D"],
		"D": [],
	}
	var costs: Dictionary = {
		"A:B": 1.0,
		"B:D": 1.0,
		"A:C": 1.0,
		"C:D": 10.0,
	}
	var search_state: GFGraphPathSearchState = GF_GRAPH_MATH.begin_path_search(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(from_node: Variant, to_node: Variant) -> float:
			return GFVariantData.get_option_float(costs, "%s:%s" % [from_node, to_node], 1.0)
	)
	var report: Dictionary = GF_GRAPH_MATH.advance_path_search(search_state, 1)

	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_GRAPH_MATH.PATH_SEARCH_STATUS_SEARCHING,
		"首个预算片段不应一次性完成整条路径。"
	)
	assert_false(GFVariantData.get_option_bool(report, "finished"), "搜索状态应可跨帧继续推进。")

	var guard: int = 0
	while not GFVariantData.get_option_bool(report, "finished") and guard < 16:
		report = GF_GRAPH_MATH.advance_path_search(search_state, 1)
		guard += 1

	assert_true(GFVariantData.get_option_bool(report, "found"), "分步搜索应最终找到路径。")
	assert_eq(GFVariantData.get_option_array(report, "path"), ["A", "B", "D"])
	assert_eq(GFVariantData.get_option_float(report, "cost", -1.0), 2.0)
	assert_eq(GF_GRAPH_MATH.find_path_dijkstra(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(from_node: Variant, to_node: Variant) -> float:
			return GFVariantData.get_option_float(costs, "%s:%s" % [from_node, to_node], 1.0)
	), GFVariantData.get_option_array(report, "path"))


func test_path_search_state_is_runtime_handle_not_dictionary() -> void:
	var raw_state: Variant = GF_GRAPH_MATH.begin_path_search(
		"A",
		"B",
		func(node: Variant) -> Array:
			return ["B"] if node == "A" else []
	)

	assert_true(raw_state is GF_GRAPH_PATH_SEARCH_STATE, "分步搜索状态应是显式运行期句柄。")
	assert_false(raw_state is Dictionary, "分步搜索不应把内部堆和 Callable 公开成 Dictionary ABI。")

	var search_state: GFGraphPathSearchState = _as_path_search_state(raw_state)
	assert_not_null(search_state, "分步搜索状态应可安全收窄为 GFGraphPathSearchState。")
	assert_eq(
		GFVariantData.get_option_string_name(search_state.make_report(), "status"),
		GF_GRAPH_MATH.PATH_SEARCH_STATUS_SEARCHING
	)


func test_path_search_zero_budget_does_not_expand_frontier() -> void:
	var counters: Dictionary = { "neighbor_call_count": 0 }
	var search_state: GFGraphPathSearchState = GF_GRAPH_MATH.begin_path_search(
		"A",
		"B",
		func(node: Variant) -> Array:
			counters["neighbor_call_count"] = GFVariantData.get_option_int(counters, "neighbor_call_count") + 1
			return ["B"] if node == "A" else []
	)
	var report: Dictionary = GF_GRAPH_MATH.advance_path_search(search_state, 0)

	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_GRAPH_MATH.PATH_SEARCH_STATUS_SEARCHING,
		"零预算只应返回当前状态，不应完成搜索。"
	)
	assert_eq(GFVariantData.get_option_int(report, "iterations"), 0, "零预算不应扩展节点。")
	assert_eq(GFVariantData.get_option_int(report, "expanded_count"), 0, "零预算不应改变累计扩展数量。")
	assert_eq(GFVariantData.get_option_int(report, "frontier_count"), 1, "起点仍应留在 frontier 中。")
	assert_eq(GFVariantData.get_option_int(counters, "neighbor_call_count"), 0, "零预算不应调用邻居回调。")


func test_path_search_equal_priority_uses_neighbor_order_as_tie_breaker() -> void:
	var graph: Dictionary = {
		"A": ["B", "C"],
		"B": ["D"],
		"C": ["D"],
		"D": [],
	}
	var sync_dijkstra_path: Array = GF_GRAPH_MATH.find_path_dijkstra(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, [])
	)
	var sync_astar_path: Array = GF_GRAPH_MATH.find_path_a_star(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, [])
	)
	var search_state: GFGraphPathSearchState = GF_GRAPH_MATH.begin_path_search(
		"A",
		"D",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, [])
	)
	var report: Dictionary = GF_GRAPH_MATH.advance_path_search(search_state, 1)
	var guard: int = 0
	while not GFVariantData.get_option_bool(report, "finished") and guard < 16:
		report = GF_GRAPH_MATH.advance_path_search(search_state, 1)
		guard += 1

	assert_true(GFVariantData.get_option_bool(report, "found"), "等价路径图中应找到路径。")
	assert_eq(sync_dijkstra_path, ["A", "B", "D"], "同步 Dijkstra 等价路径应按邻居返回顺序稳定选择。")
	assert_eq(sync_astar_path, ["A", "B", "D"], "同步 A* 等价路径应按邻居返回顺序稳定选择。")
	assert_eq(
		GFVariantData.get_option_array(report, "path"),
		["A", "B", "D"],
		"等价优先级应按邻居返回顺序稳定选择路径。"
	)


func test_path_search_reports_unreachable_goal() -> void:
	var graph: Dictionary = {
		"A": ["B"],
		"B": [],
		"C": [],
	}
	var search_state: GFGraphPathSearchState = GF_GRAPH_MATH.begin_path_search(
		"A",
		"C",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, [])
	)
	var report: Dictionary = GF_GRAPH_MATH.advance_path_search(search_state, 16)

	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_GRAPH_MATH.PATH_SEARCH_STATUS_UNREACHABLE
	)
	assert_true(GFVariantData.get_option_bool(report, "finished"))
	assert_false(GFVariantData.get_option_bool(report, "found"))
	assert_true(GFVariantData.get_option_array(report, "path").is_empty())


func test_path_search_rejects_invalid_neighbor_callback() -> void:
	var search_state: GFGraphPathSearchState = GF_GRAPH_MATH.begin_path_search("A", "B", Callable())
	var report: Dictionary = GF_GRAPH_MATH.advance_path_search(search_state, 1)

	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_GRAPH_MATH.PATH_SEARCH_STATUS_INVALID
	)
	assert_false(GFVariantData.get_option_bool(report, "ok"))


func test_negative_step_cost_blocks_edges() -> void:
	var graph: Dictionary = {
		"A": ["B"],
		"B": ["C"],
		"C": [],
	}

	var path: Array = GF_GRAPH_MATH.find_path_dijkstra(
		"A",
		"C",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(_from_node: Variant, to_node: Variant) -> float:
			return -1.0 if to_node == "C" else 1.0
	)

	assert_true(path.is_empty(), "负数代价应视为不可通行。")


func test_distance_map_respects_max_cost() -> void:
	var graph: Dictionary = {
		"A": ["B", "C"],
		"B": ["D"],
		"C": ["D"],
		"D": [],
	}
	var distances: Dictionary = GF_GRAPH_MATH.build_distance_map(
		"A",
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		Callable(),
		1.0
	)

	assert_true(distances.has("A"))
	assert_true(distances.has("B"))
	assert_true(distances.has("C"))
	assert_false(distances.has("D"), "超过 max_cost 的节点不应进入距离图。")


func test_topological_sort_orders_dependencies_before_dependents() -> void:
	var dependencies: Dictionary = {
		"gameplay": ["core"],
		"ui": ["core"],
		"core": [],
	}

	var report: Dictionary = GF_GRAPH_MATH.sort_topological(
		["gameplay", "core", "ui"],
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(dependencies, node, [])
	)
	var order: Array = GFVariantData.get_option_array(report, "order")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "无环依赖图应排序成功。")
	assert_eq(order.size(), 3, "排序结果应包含全部唯一节点。")
	assert_true(order.find("core") < order.find("gameplay"), "依赖节点应排在使用者之前。")
	assert_true(order.find("core") < order.find("ui"), "共享依赖应排在所有使用者之前。")


func test_topological_sort_reports_cycles_and_external_dependencies() -> void:
	var dependencies: Dictionary = {
		"a": ["b"],
		"b": ["a"],
		"c": ["missing"],
	}

	var report: Dictionary = GF_GRAPH_MATH.sort_topological(
		["a", "b", "c"],
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(dependencies, node, [])
	)
	var cycles: Array = GFVariantData.get_option_array(report, "cycles")
	var external_dependencies: Array = GFVariantData.get_option_array(report, "external_dependencies")
	var first_external_dependency: Dictionary = {}
	if not external_dependencies.is_empty():
		first_external_dependency = GFVariantData.as_dictionary(external_dependencies[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "有环依赖图应报告失败。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"cycle_detected", "失败原因应稳定。")
	assert_eq(GFVariantData.get_option_int(report, "cycle_count"), 1, "应报告依赖环数量。")
	assert_true(_cycle_contains(cycles, "a") and _cycle_contains(cycles, "b"), "依赖环应包含循环节点。")
	assert_eq(GFVariantData.get_option_int(report, "external_dependency_count"), 1, "外部依赖应被记录但不参与排序。")
	assert_eq(GFVariantData.get_option_string(first_external_dependency, "node"), "c")
	assert_eq(GFVariantData.get_option_string(first_external_dependency, "dependency"), "missing")


func test_connected_components_groups_declared_nodes_and_reports_external_neighbors() -> void:
	var graph: Dictionary = {
		"a": ["b", "missing"],
		"b": [],
		"c": ["d"],
		"d": [],
		"e": [],
	}

	var report: Dictionary = GF_GRAPH_MATH.find_connected_components(
		["a", "b", "c", "d", "e", "a"],
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, [])
	)
	var components: Array = GFVariantData.get_option_array(report, "components")
	var component_indices: Dictionary = GFVariantData.get_option_dictionary(report, "component_indices")
	var external_neighbors: Array = GFVariantData.get_option_array(report, "external_neighbors")
	var first_component: Array = GFVariantData.as_array(components[0]) if components.size() > 0 else []
	var second_component: Array = GFVariantData.as_array(components[1]) if components.size() > 1 else []
	var third_component: Array = GFVariantData.as_array(components[2]) if components.size() > 2 else []
	var first_external_neighbor: Dictionary = {}
	if not external_neighbors.is_empty():
		first_external_neighbor = GFVariantData.as_dictionary(external_neighbors[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效邻居回调应返回成功报告。")
	assert_eq(GFVariantData.get_option_int(report, "node_count"), 5, "重复节点应按首次出现去重。")
	assert_eq(GFVariantData.get_option_int(report, "component_count"), 3, "应识别两个连接子图和一个孤立节点。")
	assert_eq(first_component, ["a", "b"], "单向声明的边应按无向连通处理。")
	assert_eq(second_component, ["c", "d"], "第二个子图应保留稳定遍历顺序。")
	assert_eq(third_component, ["e"], "孤立节点应单独形成分量。")
	assert_eq(GFVariantData.get_option_int(component_indices, "a", -1), 0, "索引应指向节点所在分量。")
	assert_eq(GFVariantData.get_option_int(component_indices, "d", -1), 1, "索引应覆盖后续分量节点。")
	assert_false(GFVariantData.get_option_bool(report, "all_connected"), "多分量图不应标记为全连通。")
	assert_eq(GFVariantData.get_option_array(report, "isolated_nodes"), ["e"], "孤立节点应单独统计。")
	assert_eq(GFVariantData.get_option_int(report, "external_neighbor_count"), 1, "外部邻居应记录但不进入分量。")
	assert_eq(GFVariantData.get_option_string(first_external_neighbor, "node"), "a")
	assert_eq(GFVariantData.get_option_string(first_external_neighbor, "neighbor"), "missing")


func test_connected_components_rejects_invalid_neighbor_callback() -> void:
	var report: Dictionary = GF_GRAPH_MATH.find_connected_components(["a"], Callable())

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少邻居回调时应失败。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"invalid_neighbor_callback",
		"失败原因应稳定。"
	)
	assert_eq(GFVariantData.get_option_int(report, "component_count"), 0)


func test_minimum_spanning_tree_selects_lowest_weight_edges() -> void:
	var graph: Dictionary = {
		"A": ["B", "C"],
		"B": ["A", "C", "D"],
		"C": ["A", "B", "D"],
		"D": ["B", "C"],
	}
	var weights: Dictionary = {
		"A:B": 1.0,
		"A:C": 5.0,
		"B:C": 2.0,
		"B:D": 4.0,
		"C:D": 1.0,
	}

	var report: Dictionary = GF_GRAPH_MATH.find_minimum_spanning_tree(
		["A", "B", "C", "D"],
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(from_node: Variant, to_node: Variant) -> float:
			return _edge_weight(weights, from_node, to_node)
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效图应返回生成树报告。")
	assert_true(GFVariantData.get_option_bool(report, "all_connected"), "连通图应形成单棵生成树。")
	assert_eq(GFVariantData.get_option_int(report, "selected_edge_count"), 3, "N 个节点的生成树应有 N - 1 条边。")
	assert_almost_eq(GFVariantData.get_option_float(report, "total_weight"), 4.0, 0.001)
	assert_eq(
		_edge_keys(GFVariantData.get_option_array(report, "selected_edges")),
		PackedStringArray(["A-B", "B-C", "C-D"]),
		"等权之外的选择应按最低累计边权稳定输出。"
	)


func test_minimum_spanning_tree_returns_forest_for_disconnected_graph() -> void:
	var graph: Dictionary = {
		"solo": [],
		"x": ["y", "missing"],
		"y": [],
	}

	var report: Dictionary = GF_GRAPH_MATH.find_minimum_spanning_tree(
		["solo", "x", "y"],
		func(node: Variant) -> Array:
			return GFVariantData.get_option_array(graph, node, []),
		func(_from_node: Variant, _to_node: Variant) -> float:
			return 3.0
	)
	var components: Array = GFVariantData.get_option_array(report, "components")
	var component_indices: Dictionary = GFVariantData.get_option_dictionary(report, "component_indices")
	var first_component: Array = GFVariantData.as_array(components[0]) if components.size() > 0 else []
	var second_component: Array = GFVariantData.as_array(components[1]) if components.size() > 1 else []
	var external_neighbors: Array = GFVariantData.get_option_array(report, "external_neighbors")
	var first_external_neighbor: Dictionary = {}
	if not external_neighbors.is_empty():
		first_external_neighbor = GFVariantData.as_dictionary(external_neighbors[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "断开图仍应返回最小生成森林报告。")
	assert_false(GFVariantData.get_option_bool(report, "all_connected"), "断开图不应标记为单棵树。")
	assert_eq(GFVariantData.get_option_int(report, "component_count"), 2)
	assert_eq(first_component, ["solo"])
	assert_eq(second_component, ["x", "y"], "单向邻居声明应按无向边生成森林。")
	assert_eq(GFVariantData.get_option_int(component_indices, "x", -1), 1)
	assert_eq(GFVariantData.get_option_array(report, "isolated_nodes"), ["solo"])
	assert_eq(_edge_keys(GFVariantData.get_option_array(report, "selected_edges")), PackedStringArray(["x-y"]))
	assert_eq(GFVariantData.get_option_string(first_external_neighbor, "neighbor"), "missing")


func test_minimum_spanning_tree_rejects_invalid_inputs() -> void:
	var invalid_callback: Dictionary = GF_GRAPH_MATH.find_minimum_spanning_tree(["a"], Callable())
	var invalid_weight: Dictionary = GF_GRAPH_MATH.find_minimum_spanning_tree(
		["a", "b"],
		func(node: Variant) -> Array:
			return ["b"] if node == "a" else [],
		func(_from_node: Variant, _to_node: Variant) -> float:
			return NAN
	)

	assert_false(GFVariantData.get_option_bool(invalid_callback, "ok"), "缺少邻居回调时应失败。")
	assert_eq(GFVariantData.get_option_string_name(invalid_callback, "reason"), &"invalid_neighbor_callback")
	assert_false(GFVariantData.get_option_bool(invalid_weight, "ok"), "非有限权重无法稳定排序。")
	assert_eq(GFVariantData.get_option_string_name(invalid_weight, "reason"), &"invalid_edge_weight")
	assert_eq(GFVariantData.get_option_int(invalid_weight, "invalid_edge_count"), 1)


func _as_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO


func _array_vector2i(values: Array, index: int) -> Vector2i:
	if index < 0 or index >= values.size():
		return Vector2i.ZERO
	return _as_vector2i(values[index])


func _as_path_search_state(value: Variant) -> GFGraphPathSearchState:
	if value is GFGraphPathSearchState:
		var search_state: GFGraphPathSearchState = value
		return search_state
	return null


func _cycle_contains(cycles: Array, node: Variant) -> bool:
	for cycle_variant: Variant in cycles:
		if not (cycle_variant is Array):
			continue
		var cycle: Array = cycle_variant
		if cycle.has(node):
			return true
	return false


func _edge_weight(weights: Dictionary, from_node: Variant, to_node: Variant) -> float:
	var key: String = "%s:%s" % [from_node, to_node]
	if weights.has(key):
		return GFVariantData.get_option_float(weights, key, INF)

	var reverse_key: String = "%s:%s" % [to_node, from_node]
	return GFVariantData.get_option_float(weights, reverse_key, INF)


func _edge_keys(edges: Array) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for edge_variant: Variant in edges:
		var edge: Dictionary = GFVariantData.as_dictionary(edge_variant)
		var _key_appended: bool = keys.append("%s-%s" % [
			GFVariantData.get_option_string(edge, "from"),
			GFVariantData.get_option_string(edge, "to"),
		])
	return keys
