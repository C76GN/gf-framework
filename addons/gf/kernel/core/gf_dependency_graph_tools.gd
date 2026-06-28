## GFDependencyGraphTools: 字符串 ID 依赖图排序与循环诊断。
##
## 面向扩展 manifest、内容包、资源包等“稳定 ID -> 依赖 ID 列表”的轻量依赖图。
## 它只负责依赖优先排序、缺失依赖记录和循环检测，不解释节点业务类型。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFDependencyGraphTools
extends RefCounted


# --- 常量 ---

const _STATE_VISITING: int = 1
const _STATE_DONE: int = 2


# --- 公共方法 ---

## 按依赖优先顺序排序节点。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param node_ids: 需要排序的根节点 ID。
## [br]
## @param dependency_map: 依赖表，key 为节点 ID，value 为该节点依赖的 ID 列表。
## [br]
## @return 诊断字典，包含 ok、ordered_ids、missing_dependencies、dependency_cycles 和计数字段。
## [br]
## @schema dependency_map: Dictionary keyed by String or StringName node id, with Array or PackedStringArray dependency id values.
## [br]
## @schema return: Dictionary with ok, ordered_ids, missing_root_ids, missing_dependencies, dependency_cycles, node_count, missing_root_count, missing_dependency_count, and cycle_count.
static func sort_dependency_first(node_ids: PackedStringArray, dependency_map: Dictionary) -> Dictionary:
	var ordered_ids: PackedStringArray = PackedStringArray()
	var missing_root_ids: PackedStringArray = PackedStringArray()
	var missing_dependencies: Array[Dictionary] = []
	var dependency_cycles: Array[PackedStringArray] = []
	var states: Dictionary = {}
	var roots: PackedStringArray = _copy_unique_ids(node_ids)
	for node_id: String in roots:
		if not _has_node(dependency_map, node_id):
			var _missing_root_appended: bool = missing_root_ids.append(node_id)
			continue
		_visit_node(
			node_id,
			dependency_map,
			states,
			PackedStringArray(),
			ordered_ids,
			missing_dependencies,
			dependency_cycles
		)

	return {
		"ok": missing_root_ids.is_empty() and missing_dependencies.is_empty() and dependency_cycles.is_empty(),
		"ordered_ids": ordered_ids,
		"missing_root_ids": missing_root_ids,
		"missing_dependencies": missing_dependencies,
		"dependency_cycles": dependency_cycles,
		"node_count": ordered_ids.size(),
		"missing_root_count": missing_root_ids.size(),
		"missing_dependency_count": missing_dependencies.size(),
		"cycle_count": dependency_cycles.size(),
	}


# --- 私有/辅助方法 ---

static func _visit_node(
	node_id: String,
	dependency_map: Dictionary,
	states: Dictionary,
	stack: PackedStringArray,
	ordered_ids: PackedStringArray,
	missing_dependencies: Array[Dictionary],
	dependency_cycles: Array[PackedStringArray]
) -> void:
	var state: int = _get_state(states, node_id)
	if state == _STATE_DONE:
		return
	if state == _STATE_VISITING:
		_append_cycle(node_id, stack, dependency_cycles)
		return

	states[node_id] = _STATE_VISITING
	var next_stack: PackedStringArray = stack.duplicate()
	var _stack_appended: bool = next_stack.append(node_id)
	for dependency_id: String in _get_dependencies(dependency_map, node_id):
		if dependency_id.is_empty():
			continue
		if not _has_node(dependency_map, dependency_id):
			_append_missing_dependency(node_id, dependency_id, missing_dependencies)
			continue
		_visit_node(
			dependency_id,
			dependency_map,
			states,
			next_stack,
			ordered_ids,
			missing_dependencies,
			dependency_cycles
		)

	states[node_id] = _STATE_DONE
	if not ordered_ids.has(node_id):
		var _ordered_appended: bool = ordered_ids.append(node_id)


static func _get_state(states: Dictionary, node_id: String) -> int:
	if not states.has(node_id):
		return 0
	var state_value: Variant = states[node_id]
	if state_value is int:
		return state_value
	return 0


static func _get_dependencies(dependency_map: Dictionary, node_id: String) -> PackedStringArray:
	var value: Variant = _get_map_value(dependency_map, node_id, PackedStringArray())
	return _to_packed_string_array(value)


static func _has_node(dependency_map: Dictionary, node_id: String) -> bool:
	return dependency_map.has(node_id) or dependency_map.has(StringName(node_id))


static func _get_map_value(dependency_map: Dictionary, node_id: String, fallback: Variant) -> Variant:
	if dependency_map.has(node_id):
		return dependency_map[node_id]
	var node_name: StringName = StringName(node_id)
	if dependency_map.has(node_name):
		return dependency_map[node_name]
	return fallback


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		for item: String in packed:
			var text: String = item.strip_edges()
			if not text.is_empty() and not result.has(text):
				var _item_appended: bool = result.append(text)
		return result

	if value is Array:
		var items: Array = value
		for item: Variant in items:
			var text: String = _to_text(item).strip_edges()
			if not text.is_empty() and not result.has(text):
				var _item_appended: bool = result.append(text)
		return result

	var text_value: String = _to_text(value).strip_edges()
	if not text_value.is_empty():
		var _single_appended: bool = result.append(text_value)
	return result


static func _copy_unique_ids(node_ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for node_id: String in node_ids:
		var normalized_id: String = node_id.strip_edges()
		if normalized_id.is_empty() or result.has(normalized_id):
			continue
		var _id_appended: bool = result.append(normalized_id)
	return result


static func _append_missing_dependency(
	node_id: String,
	dependency_id: String,
	missing_dependencies: Array[Dictionary]
) -> void:
	for entry: Dictionary in missing_dependencies:
		if (
			_to_text(entry.get("node_id", "")) == node_id
			and _to_text(entry.get("dependency_id", "")) == dependency_id
		):
			return
	missing_dependencies.append({
		"node_id": node_id,
		"dependency_id": dependency_id,
	})


static func _append_cycle(
	node_id: String,
	stack: PackedStringArray,
	dependency_cycles: Array[PackedStringArray]
) -> void:
	var start_index: int = stack.find(node_id)
	var cycle: PackedStringArray = PackedStringArray()
	if start_index == -1:
		var _node_appended: bool = cycle.append(node_id)
	else:
		for index: int in range(start_index, stack.size()):
			var _stack_item_appended: bool = cycle.append(stack[index])
	var _closed_appended: bool = cycle.append(node_id)

	var cycle_key: String = _make_cycle_key(cycle)
	for existing_cycle: PackedStringArray in dependency_cycles:
		if _make_cycle_key(existing_cycle) == cycle_key:
			return
	dependency_cycles.append(cycle)


static func _make_cycle_key(cycle: PackedStringArray) -> String:
	return " -> ".join(Array(cycle))


static func _to_text(value: Variant) -> String:
	if value == null:
		return ""
	return str(value)
