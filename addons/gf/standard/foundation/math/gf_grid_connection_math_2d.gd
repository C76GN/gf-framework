## GFGridConnectionMath2D: 2D 网格连接判定工具。
##
## 提供最大转折次数连接判断，适合连连看类规则或需要限制折线转向次数的
## 纯逻辑检测。它不负责寻路移动、动画、碰撞响应或实体状态变更。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFGridConnectionMath2D
extends RefCounted


# --- 常量 ---

const _ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]


# --- 公共方法 ---

## 判断两个格子是否能在指定转折次数内连通。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_size: 网格尺寸。
## [br]
## @param start: 起点格子。
## [br]
## @param goal: 终点格子。
## [br]
## @param is_walkable: 可通行回调，签名为 `func(cell: Vector2i) -> bool`；起点与终点可不通行。
## [br]
## @param max_turns: 最大转折次数，连连看常用值为 2。
## [br]
## @param allow_outer_border: 是否允许路径经过网格外一圈虚拟空格。
## [br]
## @return 可连通时返回 true。
static func can_connect_with_max_turns(
	grid_size: Vector2i,
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	max_turns: int = 2,
	allow_outer_border: bool = true
) -> bool:
	if (
		start == goal
		or max_turns < 0
		or not is_walkable.is_valid()
		or not GFGridCoordinateMath2D.is_in_bounds(start, grid_size)
		or not GFGridCoordinateMath2D.is_in_bounds(goal, grid_size)
	):
		return false

	var queue: Array[Dictionary] = []
	var queue_index: int = 0
	var visited: Dictionary = {}
	for direction_index: int in range(_ORTHOGONAL_DIRECTIONS.size()):
		var direction: Vector2i = _ORTHOGONAL_DIRECTIONS[direction_index]
		var next_cell: Vector2i = start + direction
		if not _can_step_connector(next_cell, goal, grid_size, is_walkable, allow_outer_border):
			continue

		queue.append({
			"cell": next_cell,
			"direction_index": direction_index,
			"turns": 0,
		})
		visited[_make_connector_key(next_cell, direction_index)] = 0

	while queue_index < queue.size():
		var state: Dictionary = queue[queue_index]
		queue_index += 1
		var cell: Vector2i = _get_dictionary_vector2i(state, "cell", Vector2i(-1, -1))
		var direction_index: int = GFVariantData.get_option_int(state, "direction_index", -1)
		var turns: int = GFVariantData.get_option_int(state, "turns", max_turns + 1)

		if cell == goal and turns <= max_turns:
			return true

		for next_direction_index: int in range(_ORTHOGONAL_DIRECTIONS.size()):
			var next_turns: int = turns
			if next_direction_index != direction_index:
				next_turns += 1
			if next_turns > max_turns:
				continue

			var next_cell: Vector2i = cell + _ORTHOGONAL_DIRECTIONS[next_direction_index]
			if not _can_step_connector(next_cell, goal, grid_size, is_walkable, allow_outer_border):
				continue

			var key: Vector3i = _make_connector_key(next_cell, next_direction_index)
			if visited.has(key) and GFVariantData.get_option_int(visited, key, max_turns + 1) <= next_turns:
				continue

			visited[key] = next_turns
			queue.append({
				"cell": next_cell,
				"direction_index": next_direction_index,
				"turns": next_turns,
			})

	return false


# --- 私有/辅助方法 ---

static func _can_step_connector(
	cell: Vector2i,
	goal: Vector2i,
	grid_size: Vector2i,
	is_walkable: Callable,
	allow_outer_border: bool
) -> bool:
	if cell == goal:
		return true

	if GFGridCoordinateMath2D.is_in_bounds(cell, grid_size):
		return _call_cell_predicate(is_walkable, cell)

	if not allow_outer_border:
		return false

	return (
		cell.x >= -1
		and cell.y >= -1
		and cell.x <= grid_size.x
		and cell.y <= grid_size.y
	)


static func _call_cell_predicate(predicate: Callable, cell: Vector2i, fallback: bool = false) -> bool:
	if not predicate.is_valid():
		return fallback
	return GFVariantData.to_bool(predicate.call(cell), fallback)


static func _get_dictionary_vector2i(dictionary: Dictionary, key: Variant, fallback: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(dictionary, key, fallback)
	if value is Vector2i:
		var cell_value: Vector2i = value
		return cell_value
	return fallback


static func _make_connector_key(cell: Vector2i, direction_index: int) -> Vector3i:
	return Vector3i(cell.x, cell.y, direction_index)
