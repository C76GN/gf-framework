# Save 扩展内部的持久化值校验器。
extends RefCounted


# --- 常量 ---

const _DEFAULT_MAX_DEPTH: int = 64
const _DEFAULT_MAX_NODES: int = 100000


# --- 框架内部方法 ---

## 校验值能否稳定写入 Save 扩展支持的存储格式。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 即将进入持久化边界的 Variant。
## [br]
## @param options: 校验预算。
## [br]
## @return 校验报告。
## [br]
## @schema value: 原生 Save Graph Variant；Object、RID、Callable、Signal、循环引用和非有限数会被拒绝。
## [br]
## @schema options: Dictionary，支持 max_depth 与 max_nodes。
## [br]
## @schema return: Dictionary，包含 ok、error、path 与 node_count。
static func validate(value: Variant, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"max_depth": maxi(GFVariantData.get_option_int(options, "max_depth", _DEFAULT_MAX_DEPTH), 0),
		"max_nodes": maxi(GFVariantData.get_option_int(options, "max_nodes", _DEFAULT_MAX_NODES), 1),
		"node_count": 0,
		"visited": [],
	}
	var issue: Dictionary = _validate_value(value, state, 0, "$")
	return {
		"ok": issue.is_empty(),
		"error": GFVariantData.get_option_string(issue, "error"),
		"path": GFVariantData.get_option_string(issue, "path"),
		"node_count": GFVariantData.get_option_int(state, "node_count"),
	}


# --- 私有/辅助方法 ---

static func _validate_value(value: Variant, state: Dictionary, depth: int, path: String) -> Dictionary:
	if depth > GFVariantData.get_option_int(state, "max_depth"):
		return _make_issue("max_depth_exceeded", path)
	state["node_count"] = GFVariantData.get_option_int(state, "node_count") + 1
	if GFVariantData.get_option_int(state, "node_count") > GFVariantData.get_option_int(state, "max_nodes"):
		return _make_issue("max_nodes_exceeded", path)

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return {}
		TYPE_FLOAT:
			return {} if _is_finite_float(value) else _make_issue("non_finite_number", path)
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _validate_floats([vector_2.x, vector_2.y], path)
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I:
			return {}
		TYPE_RECT2:
			var rect_2: Rect2 = value
			return _validate_floats([rect_2.position.x, rect_2.position.y, rect_2.size.x, rect_2.size.y], path)
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _validate_floats([vector_3.x, vector_3.y, vector_3.z], path)
		TYPE_TRANSFORM2D:
			var transform_2d: Transform2D = value
			return _validate_floats([
				transform_2d.x.x, transform_2d.x.y,
				transform_2d.y.x, transform_2d.y.y,
				transform_2d.origin.x, transform_2d.origin.y,
			], path)
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _validate_floats([vector_4.x, vector_4.y, vector_4.z, vector_4.w], path)
		TYPE_PLANE:
			var plane: Plane = value
			return _validate_floats([plane.normal.x, plane.normal.y, plane.normal.z, plane.d], path)
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return _validate_floats([quaternion.x, quaternion.y, quaternion.z, quaternion.w], path)
		TYPE_AABB:
			var box: AABB = value
			return _validate_floats([
				box.position.x, box.position.y, box.position.z,
				box.size.x, box.size.y, box.size.z,
			], path)
		TYPE_BASIS:
			var basis: Basis = value
			return _validate_floats([
				basis.x.x, basis.x.y, basis.x.z,
				basis.y.x, basis.y.y, basis.y.z,
				basis.z.x, basis.z.y, basis.z.z,
			], path)
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			return _validate_floats([
				transform_3d.basis.x.x, transform_3d.basis.x.y, transform_3d.basis.x.z,
				transform_3d.basis.y.x, transform_3d.basis.y.y, transform_3d.basis.y.z,
				transform_3d.basis.z.x, transform_3d.basis.z.y, transform_3d.basis.z.z,
				transform_3d.origin.x, transform_3d.origin.y, transform_3d.origin.z,
			], path)
		TYPE_COLOR:
			var color: Color = value
			return _validate_floats([color.r, color.g, color.b, color.a], path)
		TYPE_ARRAY:
			return _validate_array(GFVariantData.as_array(value), state, depth, path)
		TYPE_DICTIONARY:
			return _validate_dictionary(GFVariantData.as_dictionary(value), state, depth, path)
		TYPE_PACKED_FLOAT32_ARRAY:
			var floats_32: PackedFloat32Array = value
			return _validate_floats(Array(floats_32), path)
		TYPE_PACKED_FLOAT64_ARRAY:
			var floats_64: PackedFloat64Array = value
			return _validate_floats(Array(floats_64), path)
		TYPE_PACKED_VECTOR2_ARRAY:
			var vectors_2: PackedVector2Array = value
			for index: int in range(vectors_2.size()):
				var issue: Dictionary = _validate_value(vectors_2[index], state, depth + 1, "%s[%d]" % [path, index])
				if not issue.is_empty():
					return issue
			return {}
		TYPE_PACKED_VECTOR3_ARRAY:
			var vectors_3: PackedVector3Array = value
			for index: int in range(vectors_3.size()):
				var issue: Dictionary = _validate_value(vectors_3[index], state, depth + 1, "%s[%d]" % [path, index])
				if not issue.is_empty():
					return issue
			return {}
		TYPE_PACKED_VECTOR4_ARRAY:
			var vectors_4: PackedVector4Array = value
			for index: int in range(vectors_4.size()):
				var issue: Dictionary = _validate_value(vectors_4[index], state, depth + 1, "%s[%d]" % [path, index])
				if not issue.is_empty():
					return issue
			return {}
		TYPE_PACKED_COLOR_ARRAY:
			var colors: PackedColorArray = value
			for index: int in range(colors.size()):
				var issue: Dictionary = _validate_value(colors[index], state, depth + 1, "%s[%d]" % [path, index])
				if not issue.is_empty():
					return issue
			return {}
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return {}
		_:
			return _make_issue("unsupported_type_%s" % type_string(typeof(value)), path)


static func _validate_array(value: Array, state: Dictionary, depth: int, path: String) -> Dictionary:
	if _visited_contains(state, value):
		return _make_issue("circular_reference", path)
	_get_visited(state).append(value)
	for index: int in range(value.size()):
		var issue: Dictionary = _validate_value(value[index], state, depth + 1, "%s[%d]" % [path, index])
		if not issue.is_empty():
			var _removed_on_failure: Variant = _get_visited(state).pop_back()
			return issue
	var _removed: Variant = _get_visited(state).pop_back()
	return {}


static func _validate_dictionary(value: Dictionary, state: Dictionary, depth: int, path: String) -> Dictionary:
	if _visited_contains(state, value):
		return _make_issue("circular_reference", path)
	_get_visited(state).append(value)
	for key: Variant in value.keys():
		var key_path: String = "%s.<key:%s>" % [path, str(key)]
		var key_issue: Dictionary = _validate_value(key, state, depth + 1, key_path)
		if not key_issue.is_empty():
			var _removed_for_key: Variant = _get_visited(state).pop_back()
			return key_issue
		var value_issue: Dictionary = _validate_value(value[key], state, depth + 1, "%s.%s" % [path, str(key)])
		if not value_issue.is_empty():
			var _removed_for_value: Variant = _get_visited(state).pop_back()
			return value_issue
	var _removed: Variant = _get_visited(state).pop_back()
	return {}


static func _validate_floats(values: Array, path: String) -> Dictionary:
	for value: Variant in values:
		if not _is_finite_float(value):
			return _make_issue("non_finite_number", path)
	return {}


static func _is_finite_float(value: Variant) -> bool:
	var number: float = GFVariantData.to_float(value)
	return not is_nan(number) and not is_inf(number)


static func _visited_contains(state: Dictionary, value: Variant) -> bool:
	for visited_value: Variant in _get_visited(state):
		if is_same(visited_value, value):
			return true
	return false


static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.get_option_array(state, "visited")


static func _make_issue(error: String, path: String) -> Dictionary:
	return {
		"error": error,
		"path": path,
	}
