extends RefCounted


# --- 常量 ---

const _DEFAULT_MAX_DEPTH: int = 32
const _DEFAULT_MAX_NODES: int = 16_384
const _DEFAULT_MAX_BYTES: int = 4 * 1024 * 1024
const _DEFAULT_MAX_PACKED_LENGTH: int = 65_536
const _DEFAULT_IDENTITY_MAX_DEPTH: int = 64
const _DEFAULT_IDENTITY_MAX_NODES: int = 262_144
const _DEFAULT_IDENTITY_MAX_BYTES: int = 16 * 1024 * 1024
const _DEFAULT_IDENTITY_MAX_PACKED_LENGTH: int = 1_048_576
const _CIRCULAR_REFERENCE_MARKER: String = "<circular_reference>"
const _MAX_DEPTH_MARKER: String = "<max_depth>"
const _NODE_BUDGET_MARKER: String = "<node_budget>"
const _BYTE_BUDGET_MARKER: String = "<byte_budget>"
const _PACKED_BUDGET_MARKER: String = "<packed_length_budget>"
const _UNSUPPORTED_VARIANT_MARKER: String = "<unsupported_variant>"
const _TRUNCATED_KEY: String = "__gf_snapshot_truncated__"


# --- 公共方法 ---

## 在单次操作共享预算内创建可展示快照。
##
## 该入口允许用稳定标记截断不安全或超预算分支，不得用于资源身份计算。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待复制值。
## [br]
## @schema value: 任意可深复制的 Variant；Object、Callable、Signal 和 RID 会被标记截断。
## [br]
## @param options: 可选预算覆盖。
## [br]
## @schema options: 可包含 max_depth、max_nodes、max_bytes 和 max_packed_length 正整数。
## [br]
## @return: 深复制后的有界快照；截断位置使用稳定标记。
## [br]
## @schema return: 与输入结构对应的深复制 Variant；超限或不安全分支替换为稳定字符串标记。
static func copy_snapshot(value: Variant, options: Dictionary = {}) -> Variant:
	var state: _CopyState = _create_state(options, false)
	return _copy_value_impl(value, 0, "$", state)


## 在单次操作共享预算内创建字典快照。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待复制字典。
## [br]
## @schema value: 任意键值的 Dictionary 快照源。
## [br]
## @param options: 可选预算覆盖。
## [br]
## @schema options: 可包含 max_depth、max_nodes、max_bytes 和 max_packed_length 正整数。
## [br]
## @return: 深复制后的有界字典快照；根值无法复制时返回空字典。
## [br]
## @schema return: 输入字典的有界深复制；截断分支包含稳定标记。
static func copy_snapshot_dictionary(value: Dictionary, options: Dictionary = {}) -> Dictionary:
	var copied: Variant = copy_snapshot(value, options)
	if copied is Dictionary:
		var dictionary: Dictionary = copied
		return dictionary
	return {}


## 创建用于身份计算的完整副本报告。
##
## 身份模式不允许截断、循环引用或不稳定对象值；任何失败都不返回部分副本。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待复制值。
## [br]
## @schema value: 用于稳定身份计算的任意 Variant；必须完整、无循环且不含运行时对象类型。
## [br]
## @param options: 可选预算覆盖。
## [br]
## @schema options: 可包含 max_depth、max_nodes、max_bytes 和 max_packed_length 正整数。
## [br]
## @return: 包含 ok、value、error、path、node_count、byte_count 和 packed_length 字段的报告。
## [br]
## @schema return: ok 为 true 时 value 是完整副本；失败时 value 为 null，error/path 描述首个失败边界。
static func copy_complete_report(value: Variant, options: Dictionary = {}) -> Dictionary:
	var state: _CopyState = _create_state(options, true)
	var copied: Variant = _copy_value_impl(value, 0, "$", state)
	return {
		"ok": not state._failed,
		"value": copied if not state._failed else null,
		"error": StringName(state._error),
		"path": state._path,
		"node_count": state._node_count,
		"byte_count": state._byte_count,
		"packed_length": state._packed_length,
	}


# --- 私有/辅助方法 ---

static func _create_state(options: Dictionary, complete: bool) -> _CopyState:
	var state: _CopyState = _CopyState.new()
	state._complete = complete
	state._max_depth = _get_positive_option(
		options,
		"max_depth",
		_DEFAULT_IDENTITY_MAX_DEPTH if complete else _DEFAULT_MAX_DEPTH
	)
	state._max_nodes = _get_positive_option(
		options,
		"max_nodes",
		_DEFAULT_IDENTITY_MAX_NODES if complete else _DEFAULT_MAX_NODES
	)
	state._max_bytes = _get_positive_option(
		options,
		"max_bytes",
		_DEFAULT_IDENTITY_MAX_BYTES if complete else _DEFAULT_MAX_BYTES
	)
	state._max_packed_length = _get_positive_option(
		options,
		"max_packed_length",
		_DEFAULT_IDENTITY_MAX_PACKED_LENGTH if complete else _DEFAULT_MAX_PACKED_LENGTH
	)
	return state


static func _get_positive_option(options: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = options.get(key, fallback)
	if value is int:
		var int_value: int = value
		if int_value > 0:
			return int_value
	return fallback


static func _copy_value_impl(value: Variant, depth: int, path: String, state: _CopyState) -> Variant:
	if state._stopped:
		return _marker_for_error(state._error)
	if depth > state._max_depth:
		return _record_issue(state, "max_depth", path, _MAX_DEPTH_MARKER, false)
	if not _reserve_node(state, path):
		return _NODE_BUDGET_MARKER

	if value is Dictionary:
		var dictionary: Dictionary = value
		if _visited_contains(state._visited, dictionary):
			return _record_issue(state, "circular_reference", path, _CIRCULAR_REFERENCE_MARKER, false)
		state._visited.append(dictionary)
		var result: Dictionary = {}
		for key: Variant in dictionary:
			if state._stopped:
				break
			var key_path: String = _join_path(path, GFVariantData.to_text(key))
			var copied_key: Variant = _copy_value_impl(key, depth + 1, key_path + ".<key>", state)
			if state._stopped:
				break
			result[copied_key] = _copy_value_impl(dictionary[key], depth + 1, key_path, state)
		var _removed_dictionary: Variant = state._visited.pop_back()
		if state._stopped:
			_append_truncation_marker(result, _marker_for_error(state._error))
		return result

	if value is Array:
		var array: Array = value
		if _visited_contains(state._visited, array):
			return _record_issue(state, "circular_reference", path, _CIRCULAR_REFERENCE_MARKER, false)
		state._visited.append(array)
		var result: Array = []
		for index: int in range(array.size()):
			if state._stopped:
				break
			result.append(_copy_value_impl(array[index], depth + 1, "%s[%d]" % [path, index], state))
		var _removed_array: Variant = state._visited.pop_back()
		if state._stopped:
			result.append(_marker_for_error(state._error))
		return result

	if _is_packed_array(value):
		return _copy_packed_array(value, path, state)
	if _is_unstable_variant(value):
		return _record_issue(state, "unsupported_variant", path, _UNSUPPORTED_VARIANT_MARKER, false)
	if not _reserve_bytes(state, _estimate_scalar_bytes(value), path):
		return _BYTE_BUDGET_MARKER
	return value


static func _copy_packed_array(value: Variant, path: String, state: _CopyState) -> Variant:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed: PackedByteArray = value
			if _reserve_fixed_packed(state, packed.size(), 1, path):
				return packed.duplicate()
		TYPE_PACKED_INT32_ARRAY:
			var packed: PackedInt32Array = value
			if _reserve_fixed_packed(state, packed.size(), 4, path):
				return packed.duplicate()
		TYPE_PACKED_INT64_ARRAY:
			var packed: PackedInt64Array = value
			if _reserve_fixed_packed(state, packed.size(), 8, path):
				return packed.duplicate()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed: PackedFloat32Array = value
			if _reserve_fixed_packed(state, packed.size(), 4, path):
				return packed.duplicate()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed: PackedFloat64Array = value
			if _reserve_fixed_packed(state, packed.size(), 8, path):
				return packed.duplicate()
		TYPE_PACKED_STRING_ARRAY:
			var packed: PackedStringArray = value
			if _reserve_string_packed(state, packed, path):
				return packed.duplicate()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed: PackedVector2Array = value
			if _reserve_fixed_packed(state, packed.size(), 8, path):
				return packed.duplicate()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed: PackedVector3Array = value
			if _reserve_fixed_packed(state, packed.size(), 12, path):
				return packed.duplicate()
		TYPE_PACKED_COLOR_ARRAY:
			var packed: PackedColorArray = value
			if _reserve_fixed_packed(state, packed.size(), 16, path):
				return packed.duplicate()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed: PackedVector4Array = value
			if _reserve_fixed_packed(state, packed.size(), 16, path):
				return packed.duplicate()
	return _marker_for_error(state._error)


static func _reserve_fixed_packed(
	state: _CopyState,
	length: int,
	element_bytes: int,
	path: String
) -> bool:
	if not _reserve_packed_length(state, length, path):
		return false
	@warning_ignore("integer_division")
	var max_elements_by_bytes: int = state._max_bytes / element_bytes
	if length > max_elements_by_bytes:
		var _issue: Variant = _record_issue(state, "byte_budget", path, _BYTE_BUDGET_MARKER, true)
		return false
	return _reserve_bytes(state, length * element_bytes, path)


static func _reserve_string_packed(
	state: _CopyState,
	packed: PackedStringArray,
	path: String
) -> bool:
	if not _reserve_packed_length(state, packed.size(), path):
		return false
	var total_bytes: int = 0
	for item: String in packed:
		var item_bytes: int = item.to_utf8_buffer().size()
		if item_bytes > state._max_bytes - total_bytes:
			var _issue: Variant = _record_issue(state, "byte_budget", path, _BYTE_BUDGET_MARKER, true)
			return false
		total_bytes += item_bytes
	return _reserve_bytes(state, total_bytes, path)


static func _reserve_node(state: _CopyState, path: String) -> bool:
	if state._node_count >= state._max_nodes:
		var _issue: Variant = _record_issue(state, "node_budget", path, _NODE_BUDGET_MARKER, true)
		return false
	state._node_count += 1
	return true


static func _reserve_bytes(state: _CopyState, amount: int, path: String) -> bool:
	if amount < 0 or amount > state._max_bytes - state._byte_count:
		var _issue: Variant = _record_issue(state, "byte_budget", path, _BYTE_BUDGET_MARKER, true)
		return false
	state._byte_count += amount
	return true


static func _reserve_packed_length(state: _CopyState, amount: int, path: String) -> bool:
	if amount < 0 or amount > state._max_packed_length - state._packed_length:
		var _issue: Variant = _record_issue(
			state,
			"packed_length_budget",
			path,
			_PACKED_BUDGET_MARKER,
			true
		)
		return false
	state._packed_length += amount
	return true


static func _record_issue(
	state: _CopyState,
	error: String,
	path: String,
	marker: String,
	stop_operation: bool
) -> Variant:
	if (state._complete or stop_operation) and state._error.is_empty():
		state._error = error
		state._path = path
	if state._complete:
		state._failed = true
		state._stopped = true
	elif stop_operation:
		state._stopped = true
	return marker


static func _append_truncation_marker(dictionary: Dictionary, marker: String) -> void:
	var key: String = _TRUNCATED_KEY
	var suffix: int = 1
	while dictionary.has(key):
		key = "%s_%d" % [_TRUNCATED_KEY, suffix]
		suffix += 1
	dictionary[key] = marker


static func _marker_for_error(error: String) -> String:
	match error:
		"max_depth":
			return _MAX_DEPTH_MARKER
		"node_budget":
			return _NODE_BUDGET_MARKER
		"byte_budget":
			return _BYTE_BUDGET_MARKER
		"packed_length_budget":
			return _PACKED_BUDGET_MARKER
		"circular_reference":
			return _CIRCULAR_REFERENCE_MARKER
	return _UNSUPPORTED_VARIANT_MARKER


static func _estimate_scalar_bytes(value: Variant) -> int:
	match typeof(value):
		TYPE_NIL:
			return 0
		TYPE_BOOL:
			return 1
		TYPE_INT, TYPE_FLOAT:
			return 8
		TYPE_STRING:
			var text: String = value
			return text.to_utf8_buffer().size()
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			return String(string_name_value).to_utf8_buffer().size()
		TYPE_NODE_PATH:
			var node_path: NodePath = value
			return String(node_path).to_utf8_buffer().size()
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return 16
		TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I:
			return 24
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION, TYPE_COLOR:
			return 32
		TYPE_TRANSFORM2D, TYPE_AABB, TYPE_BASIS:
			return 72
		TYPE_TRANSFORM3D, TYPE_PROJECTION:
			return 128
	return 16


static func _is_packed_array(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]


static func _is_unstable_variant(value: Variant) -> bool:
	return typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]


static func _visited_contains(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


static func _join_path(path: String, segment: String) -> String:
	return "%s.%s" % [path, segment]


# --- 内部类 ---

class _CopyState extends RefCounted:
	var _complete: bool = false
	var _max_depth: int = 0
	var _max_nodes: int = 0
	var _max_bytes: int = 0
	var _max_packed_length: int = 0
	var _node_count: int = 0
	var _byte_count: int = 0
	var _packed_length: int = 0
	var _failed: bool = false
	var _stopped: bool = false
	var _error: String = ""
	var _path: String = ""
	var _visited: Array = []
