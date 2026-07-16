## GFGraphMath: 面向任意节点类型的纯图搜索算法。
##
## 节点可以是 Vector、StringName、Resource、对象引用或项目自定义值。
## 图结构由回调提供，框架只负责遍历、代价累计和路径重建。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGraphMath
extends RefCounted


# --- 常量 ---

## 分步路径搜索仍可继续推进。
## [br]
## @api public
## [br]
## @since 5.0.0
const PATH_SEARCH_STATUS_SEARCHING: StringName = GFGraphPathSearchState.STATUS_SEARCHING

## 分步路径搜索已找到路径。
## [br]
## @api public
## [br]
## @since 5.0.0
const PATH_SEARCH_STATUS_FOUND: StringName = GFGraphPathSearchState.STATUS_FOUND

## 分步路径搜索已耗尽可达节点且不可达。
## [br]
## @api public
## [br]
## @since 5.0.0
const PATH_SEARCH_STATUS_UNREACHABLE: StringName = GFGraphPathSearchState.STATUS_UNREACHABLE

## 分步路径搜索状态或回调无效。
## [br]
## @api public
## [br]
## @since 5.0.0
const PATH_SEARCH_STATUS_INVALID: StringName = GFGraphPathSearchState.STATUS_INVALID


# --- 公共方法 ---

## 使用 Dijkstra 查找一条最低代价路径。
## [br]
## @api public
## [br]
## @param start: 起点节点。
## [br]
## @schema start: Variant graph node identity.
## [br]
## @param goal: 终点节点。
## [br]
## @schema goal: Variant graph node identity.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_step_cost: 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。
## [br]
## @return 包含起点与终点的路径；无法到达时返回空数组。
## [br]
## @schema return: Array graph node path from start to goal.
static func find_path_dijkstra(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable()
) -> Array[Variant]:
	return _find_path(start, goal, get_neighbors, get_step_cost, Callable())


## 使用 A* 查找一条低代价路径。
## [br]
## @api public
## [br]
## @param start: 起点节点。
## [br]
## @schema start: Variant graph node identity.
## [br]
## @param goal: 终点节点。
## [br]
## @schema goal: Variant graph node identity.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_step_cost: 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。
## [br]
## @param heuristic: 可选启发回调，签名为 `func(node: Variant, goal: Variant) -> float`。
## [br]
## @return 包含起点与终点的路径；无法到达时返回空数组。
## [br]
## @schema return: Array graph node path from start to goal.
static func find_path_a_star(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable(),
	heuristic: Callable = Callable()
) -> Array[Variant]:
	return _find_path(start, goal, get_neighbors, get_step_cost, heuristic)


## 创建可分步推进的 A* / Dijkstra 搜索状态。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param start: 起点节点。
## [br]
## @schema start: Variant graph node identity.
## [br]
## @param goal: 终点节点。
## [br]
## @schema goal: Variant graph node identity.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_step_cost: 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。
## [br]
## @param heuristic: 可选启发回调，签名为 `func(node: Variant, goal: Variant) -> float`；为空时退化为 Dijkstra。
## [br]
## @return 运行期搜索状态句柄；传给 `advance_path_search()` 后会推进同一个句柄。
## [br]
## @schema return: GFGraphPathSearchState runtime handle. It contains Callable values and mutable search state, so it is not a save format.
static func begin_path_search(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable(),
	heuristic: Callable = Callable()
) -> GFGraphPathSearchState:
	return GFGraphPathSearchState.create(start, goal, get_neighbors, get_step_cost, heuristic)


## 按最大迭代次数推进分步路径搜索状态。
## [br]
## 每次迭代最多弹出并扩展一个节点；`max_iterations <= 0` 时只返回当前报告。
## `search_state` 是运行期句柄，因此可以跨帧保存同一个引用继续推进。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param search_state: `begin_path_search()` 返回的状态句柄。
## [br]
## @schema search_state: GFGraphPathSearchState runtime handle returned by `begin_path_search()`. It contains Callable values and must not be serialized as save data.
## [br]
## @param max_iterations: 本次最多扩展多少个节点。
## [br]
## @return 搜索报告，包含 status、finished、found、iterations、frontier_count、expanded_count、path 和 cost。
## [br]
## @schema return: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.
static func advance_path_search(search_state: GFGraphPathSearchState, max_iterations: int = 64) -> Dictionary:
	if search_state == null:
		return {
			"ok": false,
			"status": PATH_SEARCH_STATUS_INVALID,
			"finished": true,
			"found": false,
			"reason": &"invalid_search_state",
			"iterations": 0,
			"frontier_count": 0,
			"expanded_count": 0,
			"path": [],
			"cost": INF,
		}

	return search_state.advance(max_iterations)


## 从起点生成距离图。
## [br]
## @api public
## [br]
## @param start: 起点节点。
## [br]
## @schema start: Variant graph node identity.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_step_cost: 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。
## [br]
## @param max_cost: 最大累计代价，超过后停止扩展。
## [br]
## @return 字典，键为可达节点，值为从起点到该节点的最低代价。
## [br]
## @schema return: Dictionary mapping reachable graph nodes to lowest float costs.
static func build_distance_map(
	start: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable(),
	max_cost: float = INF
) -> Dictionary:
	var distances: Dictionary = { start: 0.0 }
	if not get_neighbors.is_valid():
		return distances

	var frontier: GFPriorityQueue = GFPriorityQueue.new(false)
	_push_node_priority(frontier, start, 0.0)
	while not frontier.is_empty():
		var current_entry: Dictionary = _pop_node_priority(frontier)
		var current: Variant = GFVariantData.get_option_value(current_entry, "node")
		var current_cost: float = GFVariantData.get_option_float(distances, current, INF)
		if _get_entry_priority(current_entry) > current_cost:
			continue
		if current_cost > max_cost:
			continue

		for next_node: Variant in _get_neighbors(current, get_neighbors):
			var move_cost: float = _get_step_cost(current, next_node, get_step_cost)
			if move_cost < 0.0:
				continue

			var next_cost: float = current_cost + move_cost
			if next_cost > max_cost or next_cost >= GFVariantData.get_option_float(distances, next_node, INF):
				continue

			distances[next_node] = next_cost
			_push_node_priority(frontier, next_node, next_cost)

	return distances


## 查找指定代价内可达的节点。
## [br]
## @api public
## [br]
## @param start: 起点节点。
## [br]
## @schema start: Variant graph node identity.
## [br]
## @param max_cost: 最大累计代价。
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_step_cost: 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。
## [br]
## @return 字典，键为可达节点，值为从起点到该节点的最低代价。
## [br]
## @schema return: Dictionary mapping reachable graph nodes to lowest float costs.
static func find_reachable(
	start: Variant,
	max_cost: float,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable()
) -> Dictionary:
	return build_distance_map(start, get_neighbors, get_step_cost, max_cost)


## 对节点执行稳定拓扑排序。
## [br]
## `get_dependencies` 签名为 `func(node: Variant) -> Array`，返回该节点依赖的节点。
## 只会排序 `nodes` 中声明的节点；外部依赖会进入报告但不会导致失败。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param nodes: 需要排序的节点列表；重复节点会按首次出现去重。
## [br]
## @schema nodes: Array graph node identities.
## [br]
## @param get_dependencies: 依赖回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @return 排序报告，包含 ok、reason、order、cycles、cycle_count、node_count、external_dependencies 和 external_dependency_count。
## [br]
## @schema return: Dictionary with ok, reason, order, cycles, cycle_count, node_count, external_dependencies, and external_dependency_count.
static func sort_topological(nodes: Array, get_dependencies: Callable) -> Dictionary:
	if not get_dependencies.is_valid():
		return {
			"ok": false,
			"reason": &"invalid_dependency_callback",
			"order": [],
			"cycles": [],
			"cycle_count": 0,
			"node_count": 0,
			"external_dependencies": [],
			"external_dependency_count": 0,
		}

	var ordered_nodes: Array[Variant] = []
	var node_set: Dictionary = {}
	for node: Variant in nodes:
		if node_set.has(node):
			continue
		node_set[node] = true
		ordered_nodes.append(node)

	var dependencies_by_node: Dictionary = {}
	var dependents_by_node: Dictionary = {}
	var in_degrees: Dictionary = {}
	for node: Variant in ordered_nodes:
		dependencies_by_node[node] = []
		dependents_by_node[node] = []
		in_degrees[node] = 0

	var external_dependencies: Array[Dictionary] = []
	for node: Variant in ordered_nodes:
		var seen_dependencies: Dictionary = {}
		var dependencies: Array = _get_topological_dependencies(node, get_dependencies)
		for dependency: Variant in dependencies:
			if seen_dependencies.has(dependency):
				continue
			seen_dependencies[dependency] = true
			if not node_set.has(dependency):
				external_dependencies.append({
					"node": GFVariantData.duplicate_variant(node),
					"dependency": GFVariantData.duplicate_variant(dependency),
				})
				continue

			var node_dependencies: Array = _get_topological_array(dependencies_by_node, node)
			node_dependencies.append(dependency)
			dependencies_by_node[node] = node_dependencies

			var dependency_dependents: Array = _get_topological_array(dependents_by_node, dependency)
			dependency_dependents.append(node)
			dependents_by_node[dependency] = dependency_dependents
			in_degrees[node] = _get_topological_int(in_degrees, node) + 1

	var ready: Array[Variant] = []
	for node: Variant in ordered_nodes:
		if _get_topological_int(in_degrees, node) == 0:
			ready.append(node)

	var sorted_nodes: Array[Variant] = []
	while not ready.is_empty():
		var current: Variant = ready.pop_front()
		sorted_nodes.append(current)
		for dependent: Variant in _get_topological_array(dependents_by_node, current):
			var next_degree: int = _get_topological_int(in_degrees, dependent) - 1
			in_degrees[dependent] = next_degree
			if next_degree == 0:
				ready.append(dependent)

	var cycles: Array = []
	if sorted_nodes.size() != ordered_nodes.size():
		cycles = _find_topological_cycles(ordered_nodes, dependencies_by_node)

	return {
		"ok": cycles.is_empty(),
		"reason": &"" if cycles.is_empty() else &"cycle_detected",
		"order": sorted_nodes,
		"cycles": cycles,
		"cycle_count": cycles.size(),
		"node_count": ordered_nodes.size(),
		"external_dependencies": external_dependencies,
		"external_dependency_count": external_dependencies.size(),
	}


## 查找声明节点集中的连通分量。
## [br]
## 邻居回调只用于描述节点之间的边；只有 `nodes` 中声明的节点会参与分量计算。
## 节点之间的边按无向边处理，适合资源图、地图拓扑、流程子图和生成前诊断。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param nodes: 需要分组的节点列表；重复节点会按首次出现去重。
## [br]
## @schema nodes: Array graph node identities.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @return 连通分量报告，包含 ok、reason、components、component_indices、isolated_nodes、external_neighbors 等字段。
## [br]
## @schema return: Dictionary with ok, reason, components, component_count, component_indices, node_count, all_connected, isolated_nodes, isolated_node_count, external_neighbors, and external_neighbor_count.
static func find_connected_components(nodes: Array, get_neighbors: Callable) -> Dictionary:
	if not get_neighbors.is_valid():
		return {
			"ok": false,
			"reason": &"invalid_neighbor_callback",
			"components": [],
			"component_count": 0,
			"component_indices": {},
			"node_count": 0,
			"all_connected": false,
			"isolated_nodes": [],
			"isolated_node_count": 0,
			"external_neighbors": [],
			"external_neighbor_count": 0,
		}

	var ordered_nodes: Array[Variant] = []
	var node_set: Dictionary = {}
	for node: Variant in nodes:
		if node_set.has(node):
			continue
		node_set[node] = true
		ordered_nodes.append(node)

	var adjacency_by_node: Dictionary = {}
	for node: Variant in ordered_nodes:
		adjacency_by_node[node] = []

	var external_neighbors: Array[Dictionary] = []
	var seen_external_neighbors: Dictionary = {}
	for node: Variant in ordered_nodes:
		var node_neighbors: Array = _get_topological_array(adjacency_by_node, node)
		for neighbor: Variant in _get_neighbors(node, get_neighbors):
			if not node_set.has(neighbor):
				_record_external_neighbor(node, neighbor, external_neighbors, seen_external_neighbors)
				continue

			var _neighbor_appended: bool = _append_unique_variant(node_neighbors, neighbor)
			var reverse_neighbors: Array = _get_topological_array(adjacency_by_node, neighbor)
			var _reverse_neighbor_appended: bool = _append_unique_variant(reverse_neighbors, node)
			adjacency_by_node[neighbor] = reverse_neighbors
		adjacency_by_node[node] = node_neighbors

	var components: Array = []
	var component_indices: Dictionary = {}
	var visited: Dictionary = {}
	for node: Variant in ordered_nodes:
		if visited.has(node):
			continue

		var component_index: int = components.size()
		var component: Array = _collect_connected_component(
			node,
			component_index,
			adjacency_by_node,
			visited,
			component_indices
		)
		components.append(component)

	var isolated_nodes: Array = []
	for node: Variant in ordered_nodes:
		if _get_topological_array(adjacency_by_node, node).is_empty():
			isolated_nodes.append(node)

	return {
		"ok": true,
		"reason": &"",
		"components": components,
		"component_count": components.size(),
		"component_indices": component_indices,
		"node_count": ordered_nodes.size(),
		"all_connected": components.size() <= 1,
		"isolated_nodes": isolated_nodes,
		"isolated_node_count": isolated_nodes.size(),
		"external_neighbors": external_neighbors,
		"external_neighbor_count": external_neighbors.size(),
	}


## 查找声明节点集的最小生成树。
## [br]
## 图按无向加权边处理；`get_neighbors` 只要在任一方向返回邻居即可建立边。
## 图不连通时会返回最小生成森林，并通过 `all_connected` 标记结果不是单棵树。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param nodes: 需要纳入生成树的节点列表；重复节点会按首次出现去重。
## [br]
## @schema nodes: Array graph node identities.
## [br]
## @param get_neighbors: 邻居回调，签名为 `func(node: Variant) -> Array`。
## [br]
## @param get_edge_weight: 可选权重回调，签名为 `func(from: Variant, to: Variant) -> float`；为空时每条边权重为 1。
## [br]
## @return 最小生成树报告，包含 selected_edges、total_weight、components、isolated_nodes、external_neighbors 等字段。
## [br]
## @schema return: Dictionary with ok, reason, selected_edges, selected_edge_count, total_weight, components, component_count, component_indices, node_count, all_connected, isolated_nodes, isolated_node_count, external_neighbors, external_neighbor_count, invalid_edges, and invalid_edge_count.
static func find_minimum_spanning_tree(
	nodes: Array,
	get_neighbors: Callable,
	get_edge_weight: Callable = Callable()
) -> Dictionary:
	if not get_neighbors.is_valid():
		return _make_minimum_spanning_tree_report(
			false,
			&"invalid_neighbor_callback",
			[],
			0.0,
			[],
			{},
			0,
			[],
			[],
			[]
		)

	var ordered_nodes: Array[Variant] = []
	var node_set: Dictionary = {}
	for node: Variant in nodes:
		if node_set.has(node):
			continue
		node_set[node] = true
		ordered_nodes.append(node)

	var adjacency_by_node: Dictionary = {}
	for node: Variant in ordered_nodes:
		adjacency_by_node[node] = []

	var external_neighbors: Array[Dictionary] = []
	var seen_external_neighbors: Dictionary = {}
	var invalid_edges: Array[Dictionary] = []
	var edge_sequence: int = 0
	for node: Variant in ordered_nodes:
		for neighbor: Variant in _get_neighbors(node, get_neighbors):
			if not node_set.has(neighbor):
				_record_external_neighbor(node, neighbor, external_neighbors, seen_external_neighbors)
				continue
			if neighbor == node:
				continue

			var weight: float = _get_spanning_edge_weight(node, neighbor, get_edge_weight)
			if not _is_finite_graph_weight(weight):
				_record_invalid_spanning_edge(node, neighbor, weight, invalid_edges)
				continue

			_append_spanning_adjacency_edge(
				adjacency_by_node,
				node,
				_make_spanning_edge(node, neighbor, weight, edge_sequence)
			)
			_append_spanning_adjacency_edge(
				adjacency_by_node,
				neighbor,
				_make_spanning_edge(neighbor, node, weight, edge_sequence)
			)
			edge_sequence += 1

	if not invalid_edges.is_empty():
		return _make_minimum_spanning_tree_report(
			false,
			&"invalid_edge_weight",
			[],
			0.0,
			[],
			{},
			ordered_nodes.size(),
			[],
			external_neighbors,
			invalid_edges
		)

	var selected_edges: Array[Dictionary] = []
	var components: Array = []
	var component_indices: Dictionary = {}
	var visited: Dictionary = {}
	var total_weight: float = 0.0
	for node: Variant in ordered_nodes:
		if visited.has(node):
			continue

		var component_index: int = components.size()
		var component: Array = []
		var frontier: GFPriorityQueue = GFPriorityQueue.new(false)
		visited[node] = true
		component_indices[node] = component_index
		component.append(node)
		_push_spanning_frontier(frontier, adjacency_by_node, node, visited)

		while not frontier.is_empty():
			var edge: Dictionary = _pop_spanning_edge(frontier)
			var to_node: Variant = GFVariantData.get_option_value(edge, "to")
			if visited.has(to_node):
				continue

			visited[to_node] = true
			component_indices[to_node] = component_index
			component.append(to_node)
			selected_edges.append(_make_spanning_edge_report(edge))
			total_weight += GFVariantData.get_option_float(edge, "weight", 0.0)
			_push_spanning_frontier(frontier, adjacency_by_node, to_node, visited)

		components.append(component)

	var isolated_nodes: Array = []
	for node: Variant in ordered_nodes:
		if _get_topological_array(adjacency_by_node, node).is_empty():
			isolated_nodes.append(node)

	return _make_minimum_spanning_tree_report(
		true,
		&"",
		selected_edges,
		total_weight,
		components,
		component_indices,
		ordered_nodes.size(),
		isolated_nodes,
		external_neighbors,
		[]
	)


# --- 私有/辅助方法 ---

static func _find_path(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable,
	heuristic: Callable
) -> Array:
	if not get_neighbors.is_valid():
		return []
	if start == goal:
		return [start]

	var open_queue: GFPriorityQueue = GFPriorityQueue.new(false)
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _get_heuristic(start, goal, heuristic) }
	_push_node_priority(open_queue, start, GFVariantData.to_float(f_score[start], INF))

	while not open_queue.is_empty():
		var current_entry: Dictionary = _pop_node_priority(open_queue)
		var current: Variant = GFVariantData.get_option_value(current_entry, "node")
		if closed.has(current):
			continue
		if _get_entry_priority(current_entry) > GFVariantData.get_option_float(f_score, current, INF):
			continue
		if current == goal:
			return _reconstruct_path(start, goal, came_from)

		closed[current] = true
		for next_node: Variant in _get_neighbors(current, get_neighbors):
			if closed.has(next_node):
				continue

			var move_cost: float = _get_step_cost(current, next_node, get_step_cost)
			if move_cost < 0.0:
				continue

			var tentative_score: float = GFVariantData.get_option_float(g_score, current, INF) + move_cost
			if tentative_score >= GFVariantData.get_option_float(g_score, next_node, INF):
				continue

			came_from[next_node] = current
			g_score[next_node] = tentative_score
			f_score[next_node] = tentative_score + _get_heuristic(next_node, goal, heuristic)
			_push_node_priority(open_queue, next_node, GFVariantData.to_float(f_score[next_node], INF))

	return []


static func _reconstruct_path(start: Variant, goal: Variant, came_from: Dictionary) -> Array:
	var path: Array = [goal]
	var current: Variant = goal

	while current != start:
		if not came_from.has(current):
			return []

		current = came_from[current]
		path.push_front(current)

	return path


static func _push_node_priority(priority_queue: GFPriorityQueue, node: Variant, priority: float) -> void:
	var _node_queued: bool = priority_queue.push({
		"node": node,
		"priority": priority,
	}, priority)


static func _pop_node_priority(priority_queue: GFPriorityQueue) -> Dictionary:
	return GFVariantData.as_dictionary(priority_queue.pop({}))


static func _get_neighbors(node: Variant, get_neighbors: Callable) -> Array:
	var raw_neighbors: Variant = get_neighbors.call(node)
	if typeof(raw_neighbors) != TYPE_ARRAY:
		return []

	return GFVariantData.as_array(raw_neighbors)


static func _get_step_cost(from_node: Variant, to_node: Variant, get_step_cost: Callable) -> float:
	if get_step_cost.is_valid():
		return GFVariantData.to_float(get_step_cost.call(from_node, to_node), -1.0)

	return 1.0


static func _get_heuristic(node: Variant, goal: Variant, heuristic: Callable) -> float:
	if heuristic.is_valid():
		return maxf(0.0, GFVariantData.to_float(heuristic.call(node, goal), 0.0))

	return 0.0


static func _get_entry_priority(entry: Dictionary, fallback: float = INF) -> float:
	return GFVariantData.get_option_float(entry, "priority", fallback)


static func _get_topological_dependencies(node: Variant, get_dependencies: Callable) -> Array:
	var raw_dependencies: Variant = get_dependencies.call(node)
	if raw_dependencies is Array:
		var dependencies: Array = raw_dependencies
		return dependencies
	return []


static func _get_topological_array(source: Dictionary, key: Variant) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


static func _get_topological_int(source: Dictionary, key: Variant) -> int:
	var value: Variant = source.get(key, 0)
	if value is int:
		var int_value: int = value
		return int_value
	return 0


static func _record_external_neighbor(
	node: Variant,
	neighbor: Variant,
	external_neighbors: Array[Dictionary],
	seen_external_neighbors: Dictionary
) -> void:
	var key: String = "%s -> %s" % [var_to_str(node), var_to_str(neighbor)]
	if seen_external_neighbors.has(key):
		return

	seen_external_neighbors[key] = true
	external_neighbors.append({
		"node": GFVariantData.duplicate_variant(node),
		"neighbor": GFVariantData.duplicate_variant(neighbor),
	})


static func _get_spanning_edge_weight(from_node: Variant, to_node: Variant, get_edge_weight: Callable) -> float:
	if get_edge_weight.is_valid():
		return GFVariantData.to_float(get_edge_weight.call(from_node, to_node), NAN)
	return 1.0


static func _is_finite_graph_weight(weight: float) -> bool:
	return not (is_nan(weight) or is_inf(weight))


static func _make_spanning_edge(from_node: Variant, to_node: Variant, weight: float, sequence: int) -> Dictionary:
	return {
		"from": from_node,
		"to": to_node,
		"weight": weight,
		"sequence": sequence,
	}


static func _make_spanning_edge_report(edge: Dictionary) -> Dictionary:
	return {
		"from": GFVariantData.get_option_value(edge, "from"),
		"to": GFVariantData.get_option_value(edge, "to"),
		"weight": GFVariantData.get_option_float(edge, "weight", 0.0),
	}


static func _append_spanning_adjacency_edge(
	adjacency_by_node: Dictionary,
	node: Variant,
	edge: Dictionary
) -> void:
	var edges: Array = _get_topological_array(adjacency_by_node, node)
	edges.append(edge)
	adjacency_by_node[node] = edges


static func _push_spanning_frontier(
	frontier: GFPriorityQueue,
	adjacency_by_node: Dictionary,
	node: Variant,
	visited: Dictionary
) -> void:
	for edge_variant: Variant in _get_topological_array(adjacency_by_node, node):
		if not (edge_variant is Dictionary):
			continue

		var edge: Dictionary = edge_variant
		var to_node: Variant = GFVariantData.get_option_value(edge, "to")
		if visited.has(to_node):
			continue
		_push_spanning_edge(
			frontier,
			edge,
			GFVariantData.get_option_float(edge, "weight", INF),
			GFVariantData.get_option_int(edge, "sequence", 0)
		)


static func _push_spanning_edge(
	priority_queue: GFPriorityQueue,
	edge: Dictionary,
	priority: float,
	sequence: int
) -> void:
	var _edge_queued: bool = priority_queue.push_with_order(edge, priority, sequence)


static func _pop_spanning_edge(priority_queue: GFPriorityQueue) -> Dictionary:
	return GFVariantData.as_dictionary(priority_queue.pop({}))


static func _record_invalid_spanning_edge(
	from_node: Variant,
	to_node: Variant,
	weight: float,
	invalid_edges: Array[Dictionary]
) -> void:
	invalid_edges.append({
		"from": GFVariantData.duplicate_variant(from_node),
		"to": GFVariantData.duplicate_variant(to_node),
		"weight": weight,
	})


static func _make_minimum_spanning_tree_report(
	ok: bool,
	reason: StringName,
	selected_edges: Array,
	total_weight: float,
	components: Array,
	component_indices: Dictionary,
	node_count: int,
	isolated_nodes: Array,
	external_neighbors: Array,
	invalid_edges: Array
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"selected_edges": selected_edges,
		"selected_edge_count": selected_edges.size(),
		"total_weight": total_weight,
		"components": components,
		"component_count": components.size(),
		"component_indices": component_indices,
		"node_count": node_count,
		"all_connected": ok and components.size() <= 1,
		"isolated_nodes": isolated_nodes,
		"isolated_node_count": isolated_nodes.size(),
		"external_neighbors": external_neighbors,
		"external_neighbor_count": external_neighbors.size(),
		"invalid_edges": invalid_edges,
		"invalid_edge_count": invalid_edges.size(),
	}


static func _collect_connected_component(
	start_node: Variant,
	component_index: int,
	adjacency_by_node: Dictionary,
	visited: Dictionary,
	component_indices: Dictionary
) -> Array:
	var component: Array = []
	var queue: Array = [start_node]
	var queue_index: int = 0
	visited[start_node] = true
	while queue_index < queue.size():
		var current: Variant = queue[queue_index]
		queue_index += 1
		component.append(current)
		component_indices[current] = component_index

		for neighbor: Variant in _get_topological_array(adjacency_by_node, current):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return component


static func _append_unique_variant(values: Array, value: Variant) -> bool:
	if values.has(value):
		return false
	values.append(value)
	return true


static func _find_topological_cycles(nodes: Array, dependencies_by_node: Dictionary) -> Array:
	var cycles: Array = []
	var states: Dictionary = {}
	var path: Array = []
	var seen_cycles: Dictionary = {}
	for node: Variant in nodes:
		if _get_topological_int(states, node) != 0:
			continue
		_collect_topological_cycles(node, dependencies_by_node, states, path, cycles, seen_cycles)
	return cycles


static func _collect_topological_cycles(
	node: Variant,
	dependencies_by_node: Dictionary,
	states: Dictionary,
	path: Array,
	cycles: Array,
	seen_cycles: Dictionary
) -> void:
	states[node] = 1
	path.append(node)
	for dependency: Variant in _get_topological_array(dependencies_by_node, node):
		var dependency_state: int = _get_topological_int(states, dependency)
		if dependency_state == 0:
			_collect_topological_cycles(dependency, dependencies_by_node, states, path, cycles, seen_cycles)
		elif dependency_state == 1:
			var start_index: int = path.find(dependency)
			if start_index >= 0:
				var cycle: Array = path.slice(start_index)
				cycle.append(dependency)
				var cycle_key: String = _make_topological_cycle_key(cycle)
				if not seen_cycles.has(cycle_key):
					seen_cycles[cycle_key] = true
					cycles.append(cycle)
	var _removed_node: Variant = path.pop_back()
	states[node] = 2


static func _make_topological_cycle_key(cycle: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: Variant in cycle:
		var _append_result: bool = parts.append(var_to_str(node))
	return " -> ".join(parts)
