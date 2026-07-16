# Network 扩展内部的传输值结构校验器。
extends RefCounted


# --- 常量 ---

const _DEFAULT_MAX_DEPTH: int = 16
const _DEFAULT_MAX_NODES: int = 1024


# --- 框架内部方法 ---

## 校验值是否适合跨网络传输，并限制递归深度和节点数量。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待校验值。
## [br]
## @param options: 校验选项。
## [br]
## @return 校验报告。
## [br]
## @schema value: 任意 Variant；Object、Callable、Signal、RID、循环容器和非有限数会被拒绝。
## [br]
## @schema options: Dictionary，支持 max_depth 和 max_nodes。
## [br]
## @schema return: Dictionary，包含 ok、error、path 和 node_count。
static func validate(value: Variant, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"max_depth": maxi(GFVariantData.get_option_int(options, "max_depth", _DEFAULT_MAX_DEPTH), 0),
		"max_nodes": maxi(GFVariantData.get_option_int(options, "max_nodes", _DEFAULT_MAX_NODES), 1),
		"node_count": 0,
		"visited": [],
	}
	var issue: Dictionary = _validate_value(value, state, 0, "$", false)
	return {
		"ok": issue.is_empty(),
		"error": GFVariantData.get_option_string(issue, "error"),
		"path": GFVariantData.get_option_string(issue, "path"),
		"node_count": GFVariantData.get_option_int(state, "node_count"),
	}


# --- 私有/辅助方法 ---

static func _validate_value(
	value: Variant,
	state: Dictionary,
	depth: int,
	path: String,
	is_dictionary_key: bool
) -> Dictionary:
	if depth > GFVariantData.get_option_int(state, "max_depth"):
		return _make_issue("max_depth_exceeded", path)
	state["node_count"] = GFVariantData.get_option_int(state, "node_count") + 1
	if GFVariantData.get_option_int(state, "node_count") > GFVariantData.get_option_int(state, "max_nodes"):
		return _make_issue("max_nodes_exceeded", path)

	var value_type: int = typeof(value)
	if value_type == TYPE_OBJECT:
		return _make_issue("object_not_transport_safe", path)
	if value_type == TYPE_CALLABLE:
		return _make_issue("callable_not_transport_safe", path)
	if value_type == TYPE_SIGNAL:
		return _make_issue("signal_not_transport_safe", path)
	if value_type == TYPE_RID:
		return _make_issue("rid_not_transport_safe", path)
	if value_type == TYPE_FLOAT and not _is_finite_number(value):
		return _make_issue("non_finite_number", path)
	if not _is_finite_composite(value):
		return _make_issue("non_finite_number", path)
	if is_dictionary_key and not _is_transport_dictionary_key(value):
		return _make_issue("invalid_dictionary_key", path)

	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if _visited_contains(state, dictionary_value):
			return _make_issue("circular_reference", path)
		_get_visited(state).append(dictionary_value)
		for key: Variant in dictionary_value:
			var key_path: String = "%s.<key>" % path
			var key_issue: Dictionary = _validate_value(key, state, depth + 1, key_path, true)
			if not key_issue.is_empty():
				var _removed_key_reference: Variant = _get_visited(state).pop_back()
				return key_issue
			var value_path: String = "%s.%s" % [path, GFVariantData.to_text(key)]
			var child_issue: Dictionary = _validate_value(dictionary_value[key], state, depth + 1, value_path, false)
			if not child_issue.is_empty():
				var _removed_child_reference: Variant = _get_visited(state).pop_back()
				return child_issue
		var _removed_dictionary_tail: Variant = _get_visited(state).pop_back()
		return {}

	if value is Array:
		var array_value: Array = value
		if _visited_contains(state, array_value):
			return _make_issue("circular_reference", path)
		_get_visited(state).append(array_value)
		for index: int in range(array_value.size()):
			var child_issue: Dictionary = _validate_value(array_value[index], state, depth + 1, "%s[%d]" % [path, index], false)
			if not child_issue.is_empty():
				var _removed_array_child_reference: Variant = _get_visited(state).pop_back()
				return child_issue
		var _removed_array_tail: Variant = _get_visited(state).pop_back()
		return {}

	if _is_packed_array(value):
		for index: int in range(_get_packed_array_size(value)):
			var child_issue: Dictionary = _validate_value(
				_get_packed_array_value(value, index),
				state,
				depth + 1,
				"%s[%d]" % [path, index],
				false
			)
			if not child_issue.is_empty():
				return child_issue
	return {}


static func _is_transport_dictionary_key(value: Variant) -> bool:
	return value is String or value is StringName or typeof(value) == TYPE_INT


static func _is_finite_number(value: Variant) -> bool:
	var number: float = GFVariantData.to_float(value)
	return not is_nan(number) and not is_inf(number)


static func _is_finite_composite(value: Variant) -> bool:
	match typeof(value):
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return _is_finite_number(vector.x) and _is_finite_number(vector.y)
		TYPE_RECT2:
			var rect: Rect2 = value
			return _is_finite_composite(rect.position) and _is_finite_composite(rect.size)
		TYPE_VECTOR3:
			var vector: Vector3 = value
			return _is_finite_number(vector.x) and _is_finite_number(vector.y) and _is_finite_number(vector.z)
		TYPE_TRANSFORM2D:
			var transform: Transform2D = value
			return (
				_is_finite_composite(transform.x)
				and _is_finite_composite(transform.y)
				and _is_finite_composite(transform.origin)
			)
		TYPE_VECTOR4:
			var vector: Vector4 = value
			return (
				_is_finite_number(vector.x)
				and _is_finite_number(vector.y)
				and _is_finite_number(vector.z)
				and _is_finite_number(vector.w)
			)
		TYPE_PLANE:
			var plane: Plane = value
			return _is_finite_composite(plane.normal) and _is_finite_number(plane.d)
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return (
				_is_finite_number(quaternion.x)
				and _is_finite_number(quaternion.y)
				and _is_finite_number(quaternion.z)
				and _is_finite_number(quaternion.w)
			)
		TYPE_AABB:
			var bounds: AABB = value
			return _is_finite_composite(bounds.position) and _is_finite_composite(bounds.size)
		TYPE_BASIS:
			var basis: Basis = value
			return (
				_is_finite_composite(basis.x)
				and _is_finite_composite(basis.y)
				and _is_finite_composite(basis.z)
			)
		TYPE_TRANSFORM3D:
			var transform: Transform3D = value
			return _is_finite_composite(transform.basis) and _is_finite_composite(transform.origin)
		TYPE_PROJECTION:
			var projection: Projection = value
			return (
				_is_finite_composite(projection.x)
				and _is_finite_composite(projection.y)
				and _is_finite_composite(projection.z)
				and _is_finite_composite(projection.w)
			)
		TYPE_COLOR:
			var color: Color = value
			return (
				_is_finite_number(color.r)
				and _is_finite_number(color.g)
				and _is_finite_number(color.b)
				and _is_finite_number(color.a)
			)
	return true


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


static func _get_packed_array_size(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed: PackedByteArray = value
			return packed.size()
		TYPE_PACKED_INT32_ARRAY:
			var packed: PackedInt32Array = value
			return packed.size()
		TYPE_PACKED_INT64_ARRAY:
			var packed: PackedInt64Array = value
			return packed.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed: PackedFloat32Array = value
			return packed.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed: PackedFloat64Array = value
			return packed.size()
		TYPE_PACKED_STRING_ARRAY:
			var packed: PackedStringArray = value
			return packed.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed: PackedVector2Array = value
			return packed.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed: PackedVector3Array = value
			return packed.size()
		TYPE_PACKED_COLOR_ARRAY:
			var packed: PackedColorArray = value
			return packed.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed: PackedVector4Array = value
			return packed.size()
	return 0


static func _get_packed_array_value(value: Variant, index: int) -> Variant:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var packed: PackedByteArray = value
			return packed[index]
		TYPE_PACKED_INT32_ARRAY:
			var packed: PackedInt32Array = value
			return packed[index]
		TYPE_PACKED_INT64_ARRAY:
			var packed: PackedInt64Array = value
			return packed[index]
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed: PackedFloat32Array = value
			return packed[index]
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed: PackedFloat64Array = value
			return packed[index]
		TYPE_PACKED_STRING_ARRAY:
			var packed: PackedStringArray = value
			return packed[index]
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed: PackedVector2Array = value
			return packed[index]
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed: PackedVector3Array = value
			return packed[index]
		TYPE_PACKED_COLOR_ARRAY:
			var packed: PackedColorArray = value
			return packed[index]
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed: PackedVector4Array = value
			return packed[index]
	return null


static func _visited_contains(state: Dictionary, value: Variant) -> bool:
	for existing: Variant in _get_visited(state):
		if is_same(existing, value):
			return true
	return false


static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.get_option_array(state, "visited")


static func _make_issue(error: String, path: String) -> Dictionary:
	return {
		"error": error,
		"path": path,
	}
