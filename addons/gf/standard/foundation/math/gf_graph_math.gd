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

	var frontier: Array[Dictionary] = []
	_heap_push_node(frontier, start, 0.0)
	while not frontier.is_empty():
		var current_entry: Dictionary = _heap_pop_node(frontier)
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
			_heap_push_node(frontier, next_node, next_cost)

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

	var open_heap: Array[Dictionary] = []
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _get_heuristic(start, goal, heuristic) }
	_heap_push_node(open_heap, start, GFVariantData.to_float(f_score[start], INF))

	while not open_heap.is_empty():
		var current_entry: Dictionary = _heap_pop_node(open_heap)
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
			_heap_push_node(open_heap, next_node, GFVariantData.to_float(f_score[next_node], INF))

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


static func _take_lowest_score_node(nodes: Array, scores: Dictionary) -> Variant:
	var best_index: int = 0
	var best_score: float = GFVariantData.get_option_float(scores, nodes[0], INF)
	for index: int in range(1, nodes.size()):
		var score: float = GFVariantData.get_option_float(scores, nodes[index], INF)
		if score < best_score:
			best_index = index
			best_score = score

	var node: Variant = nodes[best_index]
	nodes.remove_at(best_index)
	return node


static func _heap_push_node(heap: Array, node: Variant, priority: float) -> void:
	heap.append({
		"node": node,
		"priority": priority,
	})
	var index: int = heap.size() - 1
	while index > 0:
		var parent_index: int = (index - 1) >> 1
		var parent_entry: Dictionary = GFVariantData.as_dictionary(heap[parent_index])
		if _get_entry_priority(parent_entry) <= priority:
			break
		heap[parent_index] = heap[index]
		heap[index] = parent_entry
		index = parent_index


static func _heap_pop_node(heap: Array) -> Dictionary:
	if heap.is_empty():
		return {}

	var result: Dictionary = GFVariantData.as_dictionary(heap[0])
	var last_entry: Dictionary = GFVariantData.as_dictionary(heap.pop_back())
	if heap.is_empty():
		return result

	heap[0] = last_entry
	var index: int = 0
	while true:
		var left_index: int = index * 2 + 1
		var right_index: int = left_index + 1
		var best_index: int = index
		if (
			left_index < heap.size()
			and _path_heap_entry_is_before(
				GFVariantData.as_dictionary(heap[left_index]),
				GFVariantData.as_dictionary(heap[best_index])
			)
		):
			best_index = left_index
		if (
			right_index < heap.size()
			and _path_heap_entry_is_before(
				GFVariantData.as_dictionary(heap[right_index]),
				GFVariantData.as_dictionary(heap[best_index])
			)
		):
			best_index = right_index
		if best_index == index:
			break

		var best_entry: Dictionary = GFVariantData.as_dictionary(heap[best_index])
		heap[best_index] = heap[index]
		heap[index] = best_entry
		index = best_index
	return result


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


static func _path_heap_entry_is_before(left_entry: Dictionary, right_entry: Dictionary) -> bool:
	var left_priority: float = _get_entry_priority(left_entry)
	var right_priority: float = _get_entry_priority(right_entry)
	if left_priority < right_priority:
		return true
	if left_priority > right_priority:
		return false
	return (
		GFVariantData.get_option_int(left_entry, "sequence")
		< GFVariantData.get_option_int(right_entry, "sequence")
	)


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
