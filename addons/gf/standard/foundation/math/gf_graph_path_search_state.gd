## GFGraphPathSearchState: 可预算推进的图路径搜索运行期句柄。
##
## 该对象保存 A* / Dijkstra 分步搜索所需的回调、frontier、分数和路径重建状态。
## 它只适合运行期跨帧推进，不是存档格式，也不应写入网络同步 payload。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 5.0.0
class_name GFGraphPathSearchState
extends RefCounted


# --- 常量 ---

## 分步路径搜索仍可继续推进。
## [br]
## @api public
## [br]
## @since 5.0.0
const STATUS_SEARCHING: StringName = &"searching"

## 分步路径搜索已找到路径。
## [br]
## @api public
## [br]
## @since 5.0.0
const STATUS_FOUND: StringName = &"found"

## 分步路径搜索已耗尽可达节点且不可达。
## [br]
## @api public
## [br]
## @since 5.0.0
const STATUS_UNREACHABLE: StringName = &"unreachable"

## 分步路径搜索状态或回调无效。
## [br]
## @api public
## [br]
## @since 5.0.0
const STATUS_INVALID: StringName = &"invalid"


# --- 私有变量 ---

var _start: Variant
var _goal: Variant
var _get_neighbors: Callable = Callable()
var _get_step_cost: Callable = Callable()
var _heuristic: Callable = Callable()
var _open_queue: GFPriorityQueue = GFPriorityQueue.new(false)
var _closed: Dictionary = {}
var _came_from: Dictionary = {}
var _g_score: Dictionary = {}
var _f_score: Dictionary = {}
var _path: Array = []
var _cost: float = INF
var _expanded_count: int = 0
var _iteration_count: int = 0
var _sequence: int = 0
var _status: StringName = STATUS_SEARCHING
var _reason: StringName = &""


# --- 公共方法 ---

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
## @return 搜索状态句柄。
static func create(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable = Callable(),
	heuristic: Callable = Callable()
) -> GFGraphPathSearchState:
	var state: GFGraphPathSearchState = GFGraphPathSearchState.new()
	state._configure(start, goal, get_neighbors, get_step_cost, heuristic)
	return state


## 创建已结束的无效搜索状态。
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
## @param reason: 无效原因。
## [br]
## @return 已标记为 invalid 的搜索状态句柄。
static func make_invalid(start: Variant, goal: Variant, reason: StringName) -> GFGraphPathSearchState:
	var state: GFGraphPathSearchState = GFGraphPathSearchState.new()
	state._start = start
	state._goal = goal
	state._finish(STATUS_INVALID, reason)
	return state


## 按最大迭代次数推进分步路径搜索状态。
## [br]
## 每次迭代最多弹出并扩展一个节点；`max_iterations <= 0` 时只返回当前报告。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param max_iterations: 本次最多扩展多少个节点。
## [br]
## @return 搜索报告，包含 status、finished、found、iterations、frontier_count、expanded_count、path 和 cost。
## [br]
## @schema return: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.
func advance(max_iterations: int = 64) -> Dictionary:
	if is_finished() or max_iterations <= 0:
		return make_report(0)

	var iterations: int = 0
	if not _get_neighbors.is_valid():
		_finish(STATUS_INVALID, &"invalid_neighbors")
		return make_report(iterations)

	while iterations < max_iterations and not _open_queue.is_empty():
		var current_entry: Dictionary = _pop_node_priority()
		var current: Variant = GFVariantData.get_option_value(current_entry, "node")
		if _closed.has(current):
			continue
		if _get_entry_priority(current_entry) > GFVariantData.get_option_float(_f_score, current, INF):
			continue

		iterations += 1
		_iteration_count += 1
		if current == _goal:
			_path = _reconstruct_path(_start, _goal, _came_from)
			_cost = GFVariantData.get_option_float(_g_score, current, INF)
			_finish(STATUS_FOUND, &"")
			return make_report(iterations)

		_closed[current] = true
		_expanded_count += 1
		for next_node: Variant in _get_neighbors_for(current):
			if _closed.has(next_node):
				continue

			var move_cost: float = _get_step_cost_for(current, next_node)
			if move_cost < 0.0:
				continue

			var tentative_score: float = GFVariantData.get_option_float(_g_score, current, INF) + move_cost
			if tentative_score >= GFVariantData.get_option_float(_g_score, next_node, INF):
				continue

			_came_from[next_node] = current
			_g_score[next_node] = tentative_score
			_f_score[next_node] = tentative_score + _get_heuristic_for(next_node, _goal)
			_push_node_priority(next_node, GFVariantData.get_option_float(_f_score, next_node, INF))

	if _open_queue.is_empty():
		_finish(STATUS_UNREACHABLE, &"unreachable")

	return make_report(iterations)


## 生成当前搜索报告，不推进搜索。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param iterations: 本次调用实际扩展的节点数。
## [br]
## @return 当前搜索报告。
## [br]
## @schema return: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.
func make_report(iterations: int = 0) -> Dictionary:
	return {
		"ok": is_valid(),
		"status": _status,
		"finished": is_finished(),
		"found": _status == STATUS_FOUND,
		"reason": _reason,
		"iterations": iterations,
		"frontier_count": _open_queue.size(),
		"expanded_count": _expanded_count,
		"path": _path.duplicate(),
		"cost": _cost,
	}


## 判断该状态是否满足搜索句柄基本格式。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 状态格式有效时返回 true。
func is_valid() -> bool:
	return _status != STATUS_INVALID


## 判断搜索是否已经结束。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 搜索已结束时返回 true。
func is_finished() -> bool:
	return _status != STATUS_SEARCHING


## 获取当前搜索状态。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 当前状态枚举值。
func get_status() -> StringName:
	return _status


## 获取当前结束或失败原因。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return reason 字段。
func get_reason() -> StringName:
	return _reason


## 获取当前找到的路径副本。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 路径节点数组副本。
## [br]
## @schema return: Array graph node path from start to goal.
func get_path() -> Array:
	return _path.duplicate()


## 获取当前路径成本。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 已找到路径的累计成本；未找到时为 INF。
func get_cost() -> float:
	return _cost


# --- 私有/辅助方法 ---

func _configure(
	start: Variant,
	goal: Variant,
	get_neighbors: Callable,
	get_step_cost: Callable,
	heuristic: Callable
) -> void:
	_start = start
	_goal = goal
	_get_neighbors = get_neighbors
	_get_step_cost = get_step_cost
	_heuristic = heuristic
	_g_score = { start: 0.0 }
	_f_score = { start: _get_heuristic_for(start, goal) }

	if not get_neighbors.is_valid():
		_finish(STATUS_INVALID, &"invalid_neighbors")
		return
	if start == goal:
		_path = [start]
		_cost = 0.0
		_finish(STATUS_FOUND, &"")
		return

	_push_node_priority(start, GFVariantData.get_option_float(_f_score, start, INF))


func _finish(status: StringName, reason: StringName) -> void:
	_status = status
	_reason = reason


func _get_neighbors_for(node: Variant) -> Array:
	var raw_neighbors: Variant = _get_neighbors.call(node)
	if typeof(raw_neighbors) != TYPE_ARRAY:
		return []

	return GFVariantData.as_array(raw_neighbors)


func _get_step_cost_for(from_node: Variant, to_node: Variant) -> float:
	if _get_step_cost.is_valid():
		return GFVariantData.to_float(_get_step_cost.call(from_node, to_node), -1.0)

	return 1.0


func _get_heuristic_for(node: Variant, goal: Variant) -> float:
	if _heuristic.is_valid():
		return maxf(0.0, GFVariantData.to_float(_heuristic.call(node, goal), 0.0))

	return 0.0


func _push_node_priority(node: Variant, priority: float) -> void:
	var sequence: int = _sequence
	_sequence += 1
	var _node_queued: bool = _open_queue.push_with_order({
		"node": node,
		"priority": priority,
		"sequence": sequence,
	}, priority, sequence)


func _pop_node_priority() -> Dictionary:
	return GFVariantData.as_dictionary(_open_queue.pop({}))


static func _reconstruct_path(start: Variant, goal: Variant, came_from: Dictionary) -> Array:
	var path: Array = [goal]
	var current: Variant = goal

	while current != start:
		if not came_from.has(current):
			return []

		current = came_from[current]
		path.push_front(current)

	return path


static func _get_entry_priority(entry: Dictionary, fallback: float = INF) -> float:
	return GFVariantData.get_option_float(entry, "priority", fallback)
