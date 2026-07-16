## GFDeterministicVariantSerializer: 纯 Variant 数据的确定性规范编码器。
##
## 该类型为锁步、回放、黄金测试和内容 hash 提供稳定的 canonical value、JSON、
## UTF-8 bytes 与 SHA-256。强确定性输入应使用整数、字符串、布尔、整数向量、
## PackedByteArray 或定点数编码；`allow_floats` 仅用于接受 Godot 浮点值的规范文本，
## 不承诺跨平台、跨 Godot 版本或跨编译配置的数值演算一致性。它不读取文件，
## 不处理存档 metadata、压缩、混淆或对象图。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFDeterministicVariantSerializer
extends RefCounted


# --- 常量 ---

const _MARKER_KEY: String = "__gf_deterministic_variant__"
const _SCHEMA_VERSION: int = 1
const _TYPE_KEY: String = "type"
const _VALUE_KEY: String = "value"
const _VERSION_KEY: String = "version"
const _DEFAULT_MAX_ITEMS: int = 100_000
const _DEFAULT_MAX_STRING_LENGTH: int = 1_048_576
const _DEFAULT_MAX_OUTPUT_BYTES: int = 16 * 1024 * 1024


# --- 公共方法 ---

## 将 Variant 转换为 JSON 兼容的规范值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 待编码的 Variant。应为纯数据结构；Object、Resource、Callable、RID 和循环引用会失败。
## [br]
## @schema value: Variant value made from nil, bool, int, String, StringName, NodePath, integer vectors, arrays, dictionaries and packed scalar arrays. Float-based values require `options.allow_floats = true`.
## [br]
## @param options: 可选项。支持 allow_floats、max_depth、max_items、max_string_length 和 max_output_bytes。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return 规范化后的 JSON 兼容 Variant；失败时返回 null 并输出错误。
## [br]
## @schema return: Typed marker Dictionary using `__gf_deterministic_variant__`, or null when unsupported input is detected.
static func to_canonical_value(value: Variant, options: Dictionary = {}) -> Variant:
	var state: Dictionary = _make_state(options)
	var result: Variant = _canonicalize_value(value, state, [], 0)
	if not GFVariantData.get_option_bool(state, "ok", true):
		return null
	return result


## 将 Variant 编码为规范 JSON 文本。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 待编码的 Variant。
## [br]
## @schema value: Variant value supported by `to_canonical_value()`.
## [br]
## @param options: 可选项。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return 规范 JSON 文本；失败时返回空字符串。
static func to_canonical_json(value: Variant, options: Dictionary = {}) -> String:
	var canonical_value: Variant = to_canonical_value(value, options)
	if canonical_value == null:
		return ""
	var canonical_json: String = JSON.stringify(canonical_value, "", true)
	var max_output_bytes: int = maxi(GFVariantData.get_option_int(options, "max_output_bytes", _DEFAULT_MAX_OUTPUT_BYTES), 1)
	if canonical_json.to_utf8_buffer().size() > max_output_bytes:
		push_error("[GFDeterministicVariantSerializer] 规范输出超过 max_output_bytes。")
		return ""
	return canonical_json


## 将 Variant 编码为规范 UTF-8 字节。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 待编码的 Variant。
## [br]
## @schema value: Variant value supported by `to_canonical_value()`.
## [br]
## @param options: 可选项。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return 规范 JSON 文本的 UTF-8 bytes；失败时返回空数组。
static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:
	var canonical_json: String = to_canonical_json(value, options)
	if canonical_json.is_empty():
		return PackedByteArray()
	return canonical_json.to_utf8_buffer()


## 计算 Variant 规范编码的 SHA-256。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 待编码的 Variant。
## [br]
## @schema value: Variant value supported by `to_canonical_value()`.
## [br]
## @param options: 可选项。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return SHA-256 hex 字符串；失败时返回空字符串。
static func sha256(value: Variant, options: Dictionary = {}) -> String:
	var bytes: PackedByteArray = to_canonical_bytes(value, options)
	if bytes.is_empty():
		return ""

	var hashing: HashingContext = HashingContext.new()
	var _start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	var _update_error: Error = hashing.update(bytes)
	return hashing.finish().hex_encode()


# --- 私有/辅助方法 ---

static func _make_state(options: Dictionary) -> Dictionary:
	var max_depth: int = GFVariantData.get_option_int(options, "max_depth", 256)
	return {
		"ok": true,
		"allow_floats": GFVariantData.get_option_bool(options, "allow_floats", false),
		"max_depth": maxi(max_depth, 1),
		"max_items": maxi(GFVariantData.get_option_int(options, "max_items", _DEFAULT_MAX_ITEMS), 1),
		"max_string_length": maxi(GFVariantData.get_option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH), 1),
		"item_count": 0,
	}


static func _canonicalize_value(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if not GFVariantData.get_option_bool(state, "ok", true):
		return null
	if not _consume_items(state, 1):
		return null
	if depth > GFVariantData.get_option_int(state, "max_depth", 256):
		return _fail(state, "输入结构超过 max_depth。")
	var packed_item_count: int = _get_packed_item_count(value)
	if packed_item_count > 0 and not _consume_items(state, packed_item_count):
		return null

	match typeof(value):
		TYPE_NIL:
			return _make_typed_value("Nil", null)
		TYPE_BOOL:
			var bool_value: bool = value
			return _make_typed_value("Bool", bool_value)
		TYPE_INT:
			var int_value: int = value
			return _make_typed_value("Int", str(int_value))
		TYPE_FLOAT:
			var float_value: float = value
			return _make_typed_value("Float", _canonicalize_float(float_value, state))
		TYPE_STRING:
			var string_value: String = value
			if not _string_is_within_budget(string_value, state):
				return null
			return _make_typed_value("String", string_value)
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			if not _string_is_within_budget(String(string_name_value), state):
				return null
			return _make_typed_value("StringName", String(string_name_value))
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			if not _string_is_within_budget(String(node_path_value), state):
				return null
			return _make_typed_value("NodePath", String(node_path_value))
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _make_typed_value("Vector2", _canonicalize_float_array([vector_2.x, vector_2.y], state))
		TYPE_VECTOR2I:
			var vector_2i: Vector2i = value
			return _make_typed_value("Vector2i", _canonicalize_int_array([vector_2i.x, vector_2i.y]))
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _make_typed_value("Vector3", _canonicalize_float_array([vector_3.x, vector_3.y, vector_3.z], state))
		TYPE_VECTOR3I:
			var vector_3i: Vector3i = value
			return _make_typed_value("Vector3i", _canonicalize_int_array([vector_3i.x, vector_3i.y, vector_3i.z]))
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _make_typed_value("Vector4", _canonicalize_float_array([vector_4.x, vector_4.y, vector_4.z, vector_4.w], state))
		TYPE_VECTOR4I:
			var vector_4i: Vector4i = value
			return _make_typed_value("Vector4i", _canonicalize_int_array([vector_4i.x, vector_4i.y, vector_4i.z, vector_4i.w]))
		TYPE_RECT2:
			var rect_2: Rect2 = value
			return _make_typed_value(
				"Rect2",
				_canonicalize_float_array([
					rect_2.position.x,
					rect_2.position.y,
					rect_2.size.x,
					rect_2.size.y,
				], state)
			)
		TYPE_RECT2I:
			var rect_2i: Rect2i = value
			return _make_typed_value(
				"Rect2i",
				_canonicalize_int_array([
					rect_2i.position.x,
					rect_2i.position.y,
					rect_2i.size.x,
					rect_2i.size.y,
				])
			)
		TYPE_COLOR:
			var color: Color = value
			return _make_typed_value("Color", _canonicalize_float_array([color.r, color.g, color.b, color.a], state))
		TYPE_PLANE:
			var plane: Plane = value
			return _make_typed_value("Plane", _canonicalize_float_array([plane.normal.x, plane.normal.y, plane.normal.z, plane.d], state))
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return _make_typed_value("Quaternion", _canonicalize_float_array([quaternion.x, quaternion.y, quaternion.z, quaternion.w], state))
		TYPE_AABB:
			var aabb: AABB = value
			return _make_typed_value(
				"AABB",
				_canonicalize_float_array([
					aabb.position.x,
					aabb.position.y,
					aabb.position.z,
					aabb.size.x,
					aabb.size.y,
					aabb.size.z,
				], state)
			)
		TYPE_BASIS:
			var basis: Basis = value
			return _make_typed_value(
				"Basis",
				_canonicalize_float_array([
					basis.x.x,
					basis.x.y,
					basis.x.z,
					basis.y.x,
					basis.y.y,
					basis.y.z,
					basis.z.x,
					basis.z.y,
					basis.z.z,
				], state)
			)
		TYPE_TRANSFORM2D:
			var transform_2d: Transform2D = value
			return _make_typed_value(
				"Transform2D",
				_canonicalize_float_array([
					transform_2d.x.x,
					transform_2d.x.y,
					transform_2d.y.x,
					transform_2d.y.y,
					transform_2d.origin.x,
					transform_2d.origin.y,
				], state)
			)
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			return _make_typed_value("Transform3D", {
				"basis": _canonicalize_value(transform_3d.basis, state, visited, depth + 1),
				"origin": _make_typed_value(
					"Vector3",
					_canonicalize_float_array([transform_3d.origin.x, transform_3d.origin.y, transform_3d.origin.z], state)
				),
			})
		TYPE_ARRAY:
			return _canonicalize_array(value, state, visited, depth)
		TYPE_DICTIONARY:
			return _canonicalize_dictionary(value, state, visited, depth)
		TYPE_PACKED_BYTE_ARRAY:
			var byte_array: PackedByteArray = value
			return _make_typed_value("PackedByteArray", _canonicalize_packed_byte_array(byte_array))
		TYPE_PACKED_INT32_ARRAY:
			var int_32_array: PackedInt32Array = value
			return _make_typed_value("PackedInt32Array", _canonicalize_packed_int32_array(int_32_array))
		TYPE_PACKED_INT64_ARRAY:
			var int_64_array: PackedInt64Array = value
			return _make_typed_value("PackedInt64Array", _canonicalize_packed_int64_array(int_64_array))
		TYPE_PACKED_FLOAT32_ARRAY:
			var float_32_array: PackedFloat32Array = value
			return _make_typed_value("PackedFloat32Array", _canonicalize_packed_float32_array(float_32_array, state))
		TYPE_PACKED_FLOAT64_ARRAY:
			var float_64_array: PackedFloat64Array = value
			return _make_typed_value("PackedFloat64Array", _canonicalize_packed_float64_array(float_64_array, state))
		TYPE_PACKED_STRING_ARRAY:
			var string_array: PackedStringArray = value
			return _make_typed_value("PackedStringArray", _canonicalize_packed_string_array(string_array, state))
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector_2_array: PackedVector2Array = value
			return _make_typed_value("PackedVector2Array", _canonicalize_packed_vector2_array(vector_2_array, state))
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector_3_array: PackedVector3Array = value
			return _make_typed_value("PackedVector3Array", _canonicalize_packed_vector3_array(vector_3_array, state))
		TYPE_PACKED_COLOR_ARRAY:
			var color_array: PackedColorArray = value
			return _make_typed_value("PackedColorArray", _canonicalize_packed_color_array(color_array, state))
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector_4_array: PackedVector4Array = value
			return _make_typed_value("PackedVector4Array", _canonicalize_packed_vector4_array(vector_4_array, state))

	return _fail(state, "不支持的 Variant 类型：%s。" % type_string(typeof(value)))


static func _canonicalize_array(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if _visited_contains_reference(visited, value):
		return _fail(state, "输入包含循环 Array 引用。")

	visited.append(value)
	var array_value: Array = value
	var result: Array = []
	for item: Variant in array_value:
		result.append(_canonicalize_value(item, state, visited, depth + 1))
		if not GFVariantData.get_option_bool(state, "ok", true):
			var _removed_failed_array_reference: Variant = visited.pop_back()
			return null

	var _removed_array_reference: Variant = visited.pop_back()
	return _make_typed_value("Array", result)


static func _canonicalize_dictionary(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if _visited_contains_reference(visited, value):
		return _fail(state, "输入包含循环 Dictionary 引用。")

	visited.append(value)
	var dictionary_value: Dictionary = value
	var entries: Array = []
	for key: Variant in dictionary_value.keys():
		var canonical_key: Variant = _canonicalize_value(key, state, visited, depth + 1)
		var canonical_value: Variant = _canonicalize_value(dictionary_value[key], state, visited, depth + 1)
		if not GFVariantData.get_option_bool(state, "ok", true):
			var _removed_failed_dictionary_reference: Variant = visited.pop_back()
			return null
		entries.append({
			"key": canonical_key,
			"sort_key": JSON.stringify(canonical_key, "", true),
			"value": canonical_value,
		})

	entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_entry: Dictionary = GFVariantData.as_dictionary(left)
		var right_entry: Dictionary = GFVariantData.as_dictionary(right)
		return GFVariantData.get_option_string(left_entry, "sort_key") < GFVariantData.get_option_string(right_entry, "sort_key")
	)

	var result: Array = []
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		result.append({
			"key": GFVariantData.get_option_value(entry, "key"),
			"value": GFVariantData.get_option_value(entry, "value"),
		})

	var _removed_dictionary_reference: Variant = visited.pop_back()
	return _make_typed_value("Dictionary", result)


static func _make_typed_value(type_name: String, typed_value: Variant) -> Dictionary:
	return {
		_MARKER_KEY: {
			_TYPE_KEY: type_name,
			_VALUE_KEY: typed_value,
			_VERSION_KEY: _SCHEMA_VERSION,
		},
	}


static func _canonicalize_int_array(values: Array[int]) -> Array[String]:
	var result: Array[String] = []
	for value: int in values:
		result.append(str(value))
	return result


static func _canonicalize_float_array(values: Array[float], state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value: float in values:
		result.append(_canonicalize_float(value, state))
	return result


static func _canonicalize_float(value: float, state: Dictionary) -> String:
	if not GFVariantData.get_option_bool(state, "allow_floats", false):
		var _failed: Variant = _fail(state, "浮点值默认不参与确定性编码；请先使用定点数，或显式设置 allow_floats。")
		return ""
	if is_nan(value) or is_inf(value):
		var _failed: Variant = _fail(state, "浮点值不能是 NaN 或 Inf。")
		return ""
	if value == 0.0:
		return "ieee754le:0000000000000000"
	var bytes: PackedByteArray = PackedByteArray()
	var resize_error: Error = bytes.resize(8) as Error
	if resize_error != OK:
		var _failed: Variant = _fail(state, "无法分配浮点规范编码缓冲区。")
		return ""
	bytes.encode_double(0, value)
	return "ieee754le:%s" % bytes.hex_encode()


static func _canonicalize_packed_byte_array(value: PackedByteArray) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


static func _canonicalize_packed_int32_array(value: PackedInt32Array) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


static func _canonicalize_packed_int64_array(value: PackedInt64Array) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


static func _canonicalize_packed_float32_array(value: PackedFloat32Array, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: float in value:
		result.append(_canonicalize_float(item, state))
	return result


static func _canonicalize_packed_float64_array(value: PackedFloat64Array, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: float in value:
		result.append(_canonicalize_float(item, state))
	return result


static func _canonicalize_packed_string_array(value: PackedStringArray, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: String in value:
		if not _string_is_within_budget(item, state):
			return []
		result.append(item)
	return result


static func _canonicalize_packed_vector2_array(value: PackedVector2Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector2 in value:
		result.append(_canonicalize_float_array([item.x, item.y], state))
	return result


static func _canonicalize_packed_vector3_array(value: PackedVector3Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector3 in value:
		result.append(_canonicalize_float_array([item.x, item.y, item.z], state))
	return result


static func _canonicalize_packed_color_array(value: PackedColorArray, state: Dictionary) -> Array:
	var result: Array = []
	for item: Color in value:
		result.append(_canonicalize_float_array([item.r, item.g, item.b, item.a], state))
	return result


static func _canonicalize_packed_vector4_array(value: PackedVector4Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector4 in value:
		result.append(_canonicalize_float_array([item.x, item.y, item.z, item.w], state))
	return result


static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


static func _consume_items(state: Dictionary, amount: int) -> bool:
	var next_count: int = GFVariantData.get_option_int(state, "item_count") + maxi(amount, 0)
	if next_count > GFVariantData.get_option_int(state, "max_items", _DEFAULT_MAX_ITEMS):
		var _failed: Variant = _fail(state, "输入集合超过 max_items。")
		return false
	state["item_count"] = next_count
	return true


static func _string_is_within_budget(value: String, state: Dictionary) -> bool:
	if value.length() <= GFVariantData.get_option_int(state, "max_string_length", _DEFAULT_MAX_STRING_LENGTH):
		return true
	var _failed: Variant = _fail(state, "字符串超过 max_string_length。")
	return false


static func _get_packed_item_count(value: Variant) -> int:
	var value_type: Variant.Type = typeof(value) as Variant.Type
	if value_type in [
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
	]:
		return len(value)
	return 0


static func _fail(state: Dictionary, message: String) -> Variant:
	if GFVariantData.get_option_bool(state, "ok", true):
		state["ok"] = false
		push_error("[GFDeterministicVariantSerializer] %s" % message)
	return null
