## GFVariantJsonCodec: Godot Variant 的 JSON 兼容编码器。
##
## 负责在 JSON.stringify() 可编码的数据和常见 Godot Variant 类型之间往返转换。
## 该类不负责集合复制或默认值合并；这类数据操作由 GFVariantData 提供。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFVariantJsonCodec
extends RefCounted


# --- 常量 ---

## JSON 对象中存放 GF Variant 类型标记的字段名。
## [br]
## @api framework_internal
const JSON_MARKER_KEY: String = "__gf_variant__"

## JSON 类型标记中的版本字段名。
## [br]
## @api framework_internal
const JSON_VERSION_KEY: String = "version"

## JSON 类型标记中的类型字段名。
## [br]
## @api framework_internal
const JSON_TYPE_KEY: String = "type"

## JSON 类型标记中的值字段名。
## [br]
## @api framework_internal
const JSON_VALUE_KEY: String = "value"

## JSON 类型标记中的 codec 身份字段名。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
const JSON_CODEC_KEY: String = "codec"

## 当前 typed marker 的 codec 身份。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
const JSON_CODEC_ID: String = "gf.variant-json"

## 当前 Variant JSON 标记格式版本。
## [br]
## @api framework_internal
const JSON_SCHEMA_VERSION: int = 1

## JSON Number 可安全表达的最大整数。
## [br]
## @api framework_internal
const JSON_SAFE_INTEGER_MAX: int = 9_007_199_254_740_991

## JSON Number 可安全表达的最小整数。
## [br]
## @api framework_internal
const JSON_SAFE_INTEGER_MIN: int = -9_007_199_254_740_991

const _FLOAT_TYPE_NAME: String = "Float"
const _FLOAT_NAN_TEXT: String = "NaN"
const _FLOAT_POSITIVE_INF_TEXT: String = "INF"
const _FLOAT_NEGATIVE_INF_TEXT: String = "-INF"


# --- 公共方法 ---

## 将 Variant 转为 JSON.stringify() 可安全编码的值。
## [br]
## @api public
## [br]
## @param value: 待转换的 Variant。
## [br]
## @param options: 可选项；encode_dictionary_keys 为 true 时会保留非字符串字典键；encode_unsafe_ints 为 false 时不标记超出 JSON 安全范围的整数。
## [br]
## @return JSON 兼容值；Godot 专有类型会带类型标记。
## [br]
## @schema value: Variant value to encode.
## [br]
## @schema options: Dictionary with encode_dictionary_keys, encode_unsafe_ints, unsupported, and circular_reference options.
## [br]
## @schema return: Variant made only from JSON-compatible values and typed marker dictionaries.
static func variant_to_json_compatible(value: Variant, options: Dictionary = {}) -> Variant:
	return _variant_to_json_compatible(value, options, [])


## 从 variant_to_json_compatible() 生成的值恢复 Godot Variant。
## [br]
## @api public
## [br]
## @param value: JSON.parse_string() 后的值。
## [br]
## @param options: 可选项；decode_typed_markers 为 false 时只递归恢复集合。
## [br]
## @return 恢复后的 Variant。
## [br]
## @schema value: Variant parsed from JSON-compatible data.
## [br]
## @schema options: Dictionary with decode_typed_markers and key decoding options.
## [br]
## @schema return: Variant restored from JSON-compatible data.
static func json_compatible_to_variant(value: Variant, options: Dictionary = {}) -> Variant:
	return _json_compatible_to_variant(value, options, [])


## 将任意 Variant 转为 JSON 兼容值后序列化为文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待序列化的 Variant。
## [br]
## @param indent: 缩进字符串；空字符串表示压缩输出。
## [br]
## @param sort_keys: 是否按键名排序 Dictionary。
## [br]
## @param options: 传给 variant_to_json_compatible() 的编码选项。
## [br]
## @return JSON 文本。
## [br]
## @schema value: Variant value to encode before JSON.stringify().
## [br]
## @schema options: Dictionary with encode_dictionary_keys, encode_unsafe_ints, unsupported, and circular_reference options.
static func stringify_json_compatible(
	value: Variant,
	indent: String = "",
	sort_keys: bool = false,
	options: Dictionary = {}
) -> String:
	var encoded: Variant = variant_to_json_compatible(value, options)
	return JSON.stringify(encoded, indent, sort_keys)


## 解析 JSON 文本并把 GF Variant 类型标记恢复为 Godot Variant。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param text: JSON 文本。
## [br]
## @param fallback: 解析失败时返回的值。
## [br]
## @param options: 传给 json_compatible_to_variant() 的解码选项。
## [br]
## @return 恢复后的 Variant，或 fallback。
## [br]
## @schema fallback: Variant returned unchanged when JSON parsing fails.
## [br]
## @schema options: Dictionary with decode_typed_markers and key decoding options.
## [br]
## @schema return: Variant restored from GF JSON-compatible data, or fallback on parse error.
static func parse_json_compatible_text(
	text: String,
	fallback: Variant = null,
	options: Dictionary = {}
) -> Variant:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return fallback
	return json_compatible_to_variant(json.data, options)


## 解析 JSON 文本，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param text: JSON 文本。
## [br]
## @param fallback: 解析失败时返回的值。
## [br]
## @return 解析后的 JSON 值，或 fallback。
## [br]
## @schema fallback: Variant returned unchanged when JSON parsing fails.
## [br]
## @schema return: Variant parsed by Godot JSON, or fallback on parse error.
static func parse_json_text(text: String, fallback: Variant = null) -> Variant:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return fallback
	return json.data


## 格式化 JSON 文本，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param text: JSON 文本。
## [br]
## @param indent: 缩进字符串；默认使用 Tab。
## [br]
## @param sort_keys: 是否按键名排序 Dictionary。
## [br]
## @param fallback: 解析失败时返回的文本。
## [br]
## @return 格式化后的 JSON 文本，或 fallback。
static func format_json_text(
	text: String,
	indent: String = "\t",
	sort_keys: bool = false,
	fallback: String = ""
) -> String:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return fallback
	return JSON.stringify(json.data, indent, sort_keys)


## 压缩 JSON 文本，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param text: JSON 文本。
## [br]
## @param sort_keys: 是否按键名排序 Dictionary。
## [br]
## @param fallback: 解析失败时返回的文本。
## [br]
## @return 去除非必要空白后的 JSON 文本，或 fallback。
static func compact_json_text(text: String, sort_keys: bool = false, fallback: String = "") -> String:
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		return fallback
	return JSON.stringify(json.data, "", sort_keys)


## 将 Vector2 转成 JSON 友好的数组，非有限分量使用 Float typed marker。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param value: 待转换的 Vector2。
## [br]
## @return [x, y] 数组。
## [br]
## @schema return: Array with two JSON-compatible float values; non-finite components use Float typed markers.
static func vector2_to_array(value: Vector2) -> Array:
	return _float_array_to_json_compatible([value.x, value.y])


## 从数组读取 Vector2，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @param fallback: 转换失败时返回的值。
## [br]
## @return Vector2 值。
## [br]
## @schema value: Variant expected to be an Array with at least two numeric values.
static func array_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not (value is Array):
		return fallback

	var array: Array = value
	if array.size() < 2:
		return fallback
	return Vector2(_float_at(array, 0), _float_at(array, 1))


## 将 Vector3 转成 JSON 友好的数组，非有限分量使用 Float typed marker。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param value: 待转换的 Vector3。
## [br]
## @return [x, y, z] 数组。
## [br]
## @schema return: Array with three JSON-compatible float values; non-finite components use Float typed markers.
static func vector3_to_array(value: Vector3) -> Array:
	return _float_array_to_json_compatible([value.x, value.y, value.z])


## 从数组读取 Vector3，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @param fallback: 转换失败时返回的值。
## [br]
## @return Vector3 值。
## [br]
## @schema value: Variant expected to be an Array with at least three numeric values.
static func array_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if not (value is Array):
		return fallback

	var array: Array = value
	if array.size() < 3:
		return fallback
	return Vector3(_float_at(array, 0), _float_at(array, 1), _float_at(array, 2))


## 将 Color 转成 JSON 友好的数组，非有限通道使用 Float typed marker。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param value: 待转换的 Color。
## [br]
## @return [r, g, b, a] 数组。
## [br]
## @schema return: Array with four JSON-compatible float values; non-finite components use Float typed markers.
static func color_to_array(value: Color) -> Array:
	return _float_array_to_json_compatible([value.r, value.g, value.b, value.a])


## 从数组读取 Color，失败时返回 fallback。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @param fallback: 转换失败时返回的值。
## [br]
## @return Color 值。
## [br]
## @schema value: Variant expected to be an Array with at least four numeric values.
static func array_to_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if not (value is Array):
		return fallback

	var array: Array = value
	if array.size() < 4:
		return fallback
	return Color(_float_at(array, 0), _float_at(array, 1), _float_at(array, 2), _float_at(array, 3))


# --- 私有/辅助方法 ---

static func _json_compatible_to_variant(value: Variant, options: Dictionary, visited: Array) -> Variant:
	if value is Array:
		if _visited_contains_reference(visited, value):
			return GFVariantData.get_option_value(options, "circular_reference", "<circular_reference>")
		visited.append(value)
		var array: Array = value
		var result_array: Array = []
		for item: Variant in array:
			result_array.append(_json_compatible_to_variant(item, options, visited))
		var _removed_array_reference: Variant = visited.pop_back()
		return result_array

	if value is Dictionary:
		if _visited_contains_reference(visited, value):
			return GFVariantData.get_option_value(options, "circular_reference", "<circular_reference>")
		visited.append(value)
		var dictionary: Dictionary = value
		if GFVariantData.get_option_bool(options, "decode_typed_markers", true) and _is_json_typed_value(dictionary):
			var typed_value: Variant = _json_typed_value_to_variant(dictionary, options)
			var _removed_typed_reference: Variant = visited.pop_back()
			return typed_value

		var result_dictionary: Dictionary = {}
		for key: Variant in dictionary.keys():
			result_dictionary[key] = _json_compatible_to_variant(dictionary[key], options, visited)
		var _removed_dictionary_reference: Variant = visited.pop_back()
		return result_dictionary

	return value


static func _number_to_float(value: Variant, fallback: float = 0.0) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	if value is bool:
		var bool_value: bool = value
		return float(bool_value)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return _json_float_marker_to_float(dictionary_value, fallback)
	return fallback


static func _number_to_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is bool:
		var bool_value: bool = value
		return int(bool_value)
	if value is String or value is StringName:
		return str(value).to_int()
	return fallback


static func _variant_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var result: Vector2 = value
		return result
	return Vector2.ZERO


static func _variant_to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var result: Vector2i = value
		return result
	return Vector2i.ZERO


static func _variant_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		var result: Vector3 = value
		return result
	return Vector3.ZERO


static func _variant_to_vector3i(value: Variant) -> Vector3i:
	if value is Vector3i:
		var result: Vector3i = value
		return result
	return Vector3i.ZERO


static func _variant_to_vector4(value: Variant) -> Vector4:
	if value is Vector4:
		var result: Vector4 = value
		return result
	return Vector4.ZERO


static func _variant_to_vector4i(value: Variant) -> Vector4i:
	if value is Vector4i:
		var result: Vector4i = value
		return result
	return Vector4i.ZERO


static func _variant_to_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		var result: Rect2 = value
		return result
	return Rect2()


static func _variant_to_rect2i(value: Variant) -> Rect2i:
	if value is Rect2i:
		var result: Rect2i = value
		return result
	return Rect2i()


static func _variant_to_color(value: Variant) -> Color:
	if value is Color:
		var result: Color = value
		return result
	return Color.TRANSPARENT


static func _variant_to_plane(value: Variant) -> Plane:
	if value is Plane:
		var result: Plane = value
		return result
	return Plane()


static func _variant_to_quaternion(value: Variant) -> Quaternion:
	if value is Quaternion:
		var result: Quaternion = value
		return result
	return Quaternion.IDENTITY


static func _variant_to_aabb(value: Variant) -> AABB:
	if value is AABB:
		var result: AABB = value
		return result
	return AABB()


static func _variant_to_basis(value: Variant) -> Basis:
	if value is Basis:
		var result: Basis = value
		return result
	return Basis()


static func _variant_to_transform_2d(value: Variant) -> Transform2D:
	if value is Transform2D:
		var result: Transform2D = value
		return result
	return Transform2D()


static func _variant_to_transform_3d(value: Variant) -> Transform3D:
	if value is Transform3D:
		var result: Transform3D = value
		return result
	return Transform3D()


static func _variant_to_packed_byte_array(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		var result: PackedByteArray = value
		return result
	return PackedByteArray()


static func _variant_to_packed_int32_array(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		var result: PackedInt32Array = value
		return result
	return PackedInt32Array()


static func _variant_to_packed_int64_array(value: Variant) -> PackedInt64Array:
	if value is PackedInt64Array:
		var result: PackedInt64Array = value
		return result
	return PackedInt64Array()


static func _variant_to_packed_float32_array(value: Variant) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		var result: PackedFloat32Array = value
		return result
	return PackedFloat32Array()


static func _variant_to_packed_float64_array(value: Variant) -> PackedFloat64Array:
	if value is PackedFloat64Array:
		var result: PackedFloat64Array = value
		return result
	return PackedFloat64Array()


static func _variant_to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var result: PackedStringArray = value
		return result
	return PackedStringArray()


static func _variant_to_packed_vector2_array(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		var result: PackedVector2Array = value
		return result
	return PackedVector2Array()


static func _variant_to_packed_vector3_array(value: Variant) -> PackedVector3Array:
	if value is PackedVector3Array:
		var result: PackedVector3Array = value
		return result
	return PackedVector3Array()


static func _variant_to_packed_color_array(value: Variant) -> PackedColorArray:
	if value is PackedColorArray:
		var result: PackedColorArray = value
		return result
	return PackedColorArray()


static func _variant_to_packed_vector4_array(value: Variant) -> PackedVector4Array:
	if value is PackedVector4Array:
		var result: PackedVector4Array = value
		return result
	return PackedVector4Array()


static func _variant_to_json_compatible(value: Variant, options: Dictionary, visited: Array) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var float_value: float = value
			return _float_to_json_compatible(float_value)
		TYPE_INT:
			var int_value: int = _number_to_int(value)
			if GFVariantData.get_option_bool(options, "encode_unsafe_ints", true) and _is_unsafe_json_integer(int_value):
				return _make_json_typed_value("Int64", str(int_value))
			return int_value
		TYPE_STRING_NAME:
			return _make_json_typed_value("StringName", str(value))
		TYPE_NODE_PATH:
			return _make_json_typed_value("NodePath", str(value))
		TYPE_VECTOR2:
			var vector_2: Vector2 = _variant_to_vector2(value)
			return _make_json_typed_value("Vector2", vector2_to_array(vector_2))
		TYPE_VECTOR2I:
			var vector_2i: Vector2i = _variant_to_vector2i(value)
			return _make_json_typed_value("Vector2i", [vector_2i.x, vector_2i.y])
		TYPE_VECTOR3:
			var vector_3: Vector3 = _variant_to_vector3(value)
			return _make_json_typed_value("Vector3", vector3_to_array(vector_3))
		TYPE_VECTOR3I:
			var vector_3i: Vector3i = _variant_to_vector3i(value)
			return _make_json_typed_value("Vector3i", [vector_3i.x, vector_3i.y, vector_3i.z])
		TYPE_VECTOR4:
			var vector_4: Vector4 = _variant_to_vector4(value)
			return _make_json_typed_value("Vector4", _float_array_to_json_compatible([vector_4.x, vector_4.y, vector_4.z, vector_4.w]))
		TYPE_VECTOR4I:
			var vector_4i: Vector4i = _variant_to_vector4i(value)
			return _make_json_typed_value("Vector4i", [vector_4i.x, vector_4i.y, vector_4i.z, vector_4i.w])
		TYPE_RECT2:
			var rect_2: Rect2 = _variant_to_rect2(value)
			return _make_json_typed_value("Rect2", _float_array_to_json_compatible([rect_2.position.x, rect_2.position.y, rect_2.size.x, rect_2.size.y]))
		TYPE_RECT2I:
			var rect_2i: Rect2i = _variant_to_rect2i(value)
			return _make_json_typed_value("Rect2i", [rect_2i.position.x, rect_2i.position.y, rect_2i.size.x, rect_2i.size.y])
		TYPE_COLOR:
			var color: Color = _variant_to_color(value)
			return _make_json_typed_value("Color", color_to_array(color))
		TYPE_PLANE:
			var plane: Plane = _variant_to_plane(value)
			return _make_json_typed_value("Plane", _float_array_to_json_compatible([plane.normal.x, plane.normal.y, plane.normal.z, plane.d]))
		TYPE_QUATERNION:
			var quaternion: Quaternion = _variant_to_quaternion(value)
			return _make_json_typed_value("Quaternion", _float_array_to_json_compatible([quaternion.x, quaternion.y, quaternion.z, quaternion.w]))
		TYPE_AABB:
			var aabb: AABB = _variant_to_aabb(value)
			return _make_json_typed_value("AABB", _float_array_to_json_compatible([aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z]))
		TYPE_BASIS:
			return _make_json_typed_value("Basis", _basis_to_array(_variant_to_basis(value)))
		TYPE_TRANSFORM2D:
			return _make_json_typed_value("Transform2D", _transform_2d_to_array(_variant_to_transform_2d(value)))
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = _variant_to_transform_3d(value)
			return _make_json_typed_value("Transform3D", {
				"basis": _basis_to_array(transform_3d.basis),
				"origin": vector3_to_array(transform_3d.origin),
			})
		TYPE_ARRAY:
			if _visited_contains_reference(visited, value):
				return _make_circular_reference_value(options)
			visited.append(value)
			var array_value: Array = value
			var result_array: Array = []
			for item: Variant in array_value:
				result_array.append(_variant_to_json_compatible(item, options, visited))
			var _removed_array_reference: Variant = visited.pop_back()
			return result_array
		TYPE_DICTIONARY:
			if _visited_contains_reference(visited, value):
				return _make_circular_reference_value(options)
			visited.append(value)
			var dictionary_value: Dictionary = value
			var result_dictionary: Variant = _dictionary_to_json_compatible(dictionary_value, options, visited)
			var _removed_dictionary_reference: Variant = visited.pop_back()
			return result_dictionary
		TYPE_PACKED_BYTE_ARRAY:
			return _make_json_typed_value("PackedByteArray", _packed_byte_array_to_array(_variant_to_packed_byte_array(value)))
		TYPE_PACKED_INT32_ARRAY:
			return _make_json_typed_value("PackedInt32Array", _packed_int32_array_to_array(_variant_to_packed_int32_array(value)))
		TYPE_PACKED_INT64_ARRAY:
			return _make_json_typed_value("PackedInt64Array", _packed_int64_array_to_array(_variant_to_packed_int64_array(value)))
		TYPE_PACKED_FLOAT32_ARRAY:
			return _make_json_typed_value("PackedFloat32Array", _packed_float32_array_to_array(_variant_to_packed_float32_array(value)))
		TYPE_PACKED_FLOAT64_ARRAY:
			return _make_json_typed_value("PackedFloat64Array", _packed_float64_array_to_array(_variant_to_packed_float64_array(value)))
		TYPE_PACKED_STRING_ARRAY:
			return _make_json_typed_value("PackedStringArray", _packed_string_array_to_array(_variant_to_packed_string_array(value)))
		TYPE_PACKED_VECTOR2_ARRAY:
			return _make_json_typed_value("PackedVector2Array", _packed_vector2_array_to_array(_variant_to_packed_vector2_array(value)))
		TYPE_PACKED_VECTOR3_ARRAY:
			return _make_json_typed_value("PackedVector3Array", _packed_vector3_array_to_array(_variant_to_packed_vector3_array(value)))
		TYPE_PACKED_COLOR_ARRAY:
			return _make_json_typed_value("PackedColorArray", _packed_color_array_to_array(_variant_to_packed_color_array(value)))
		TYPE_PACKED_VECTOR4_ARRAY:
			return _make_json_typed_value("PackedVector4Array", _packed_vector4_array_to_array(_variant_to_packed_vector4_array(value)))
		_:
			if GFVariantData.get_option_string(options, "unsupported", "null") == "string":
				return str(value)
	return null


static func _make_json_typed_value(type_name: String, typed_value: Variant) -> Dictionary:
	return {
		JSON_MARKER_KEY: {
			JSON_VERSION_KEY: JSON_SCHEMA_VERSION,
			JSON_CODEC_KEY: JSON_CODEC_ID,
			JSON_TYPE_KEY: type_name,
			JSON_VALUE_KEY: typed_value,
		},
	}


static func _is_json_typed_value(value: Dictionary) -> bool:
	if value.size() != 1 or not value.has(JSON_MARKER_KEY):
		return false
	var marker: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(value, JSON_MARKER_KEY))
	return (
		GFVariantData.get_option_int(marker, JSON_VERSION_KEY, 0) == JSON_SCHEMA_VERSION
		and GFVariantData.get_option_string(marker, JSON_CODEC_KEY) == JSON_CODEC_ID
		and marker.has(JSON_TYPE_KEY)
		and marker.has(JSON_VALUE_KEY)
	)


static func _dictionary_to_json_compatible(value: Dictionary, options: Dictionary, visited: Array) -> Variant:
	if GFVariantData.get_option_bool(options, "encode_dictionary_keys", false):
		return _make_json_typed_value("Dictionary", _dictionary_entries_to_json_compatible(value, options, visited))

	var result: Dictionary = {}
	var seen_json_keys: Dictionary = {}
	for key: Variant in value.keys():
		var json_key: String = _json_key_to_string(key)
		if seen_json_keys.has(json_key):
			return _make_json_typed_value("Dictionary", _dictionary_entries_to_json_compatible(value, options, visited))
		seen_json_keys[json_key] = true
		result[json_key] = _variant_to_json_compatible(value[key], options, visited)
	if _is_json_typed_value(result):
		return result
	if _has_reserved_marker_shape(result):
		return _make_json_typed_value("Dictionary", _dictionary_entries_to_json_compatible(value, options, visited))
	return result


static func _dictionary_entries_to_json_compatible(value: Dictionary, options: Dictionary, visited: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key: Variant in value.keys():
		entries.append({
			"key": _dictionary_key_to_json_compatible(key, options, visited),
			"value": _variant_to_json_compatible(value[key], options, visited),
		})
	return entries


static func _dictionary_key_to_json_compatible(key: Variant, options: Dictionary, visited: Array) -> Variant:
	if typeof(key) == TYPE_INT:
		return _make_json_typed_value("Int64", str(_number_to_int(key)))
	return _variant_to_json_compatible(key, options, visited)


static func _make_circular_reference_value(options: Dictionary) -> Variant:
	return _make_json_typed_value(
		"CircularReference",
		GFVariantData.get_option_value(options, "circular_reference", "<circular_reference>")
	)


static func _has_reserved_marker_shape(value: Dictionary) -> bool:
	if value.size() != 1 or not value.has(JSON_MARKER_KEY):
		return false
	var marker: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(value, JSON_MARKER_KEY))
	return marker.has(JSON_TYPE_KEY) and marker.has(JSON_VALUE_KEY)


static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


static func _json_typed_value_to_variant(value: Dictionary, options: Dictionary) -> Variant:
	var marker: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(value, JSON_MARKER_KEY))
	if marker.is_empty():
		return value

	var type_name: String = GFVariantData.get_option_string(marker, JSON_TYPE_KEY)
	var raw_value: Variant = GFVariantData.get_option_value(marker, JSON_VALUE_KEY)
	match type_name:
		"Int64":
			return int(str(raw_value))
		_FLOAT_TYPE_NAME:
			return _json_float_value_to_float(raw_value)
		"StringName":
			return StringName(str(raw_value))
		"NodePath":
			return NodePath(str(raw_value))
		"Vector2":
			var vector_2: Array = GFVariantData.as_array(raw_value)
			return Vector2(_float_at(vector_2, 0), _float_at(vector_2, 1))
		"Vector2i":
			var vector_2i: Array = GFVariantData.as_array(raw_value)
			return Vector2i(_int_at(vector_2i, 0), _int_at(vector_2i, 1))
		"Vector3":
			var vector_3: Array = GFVariantData.as_array(raw_value)
			return Vector3(_float_at(vector_3, 0), _float_at(vector_3, 1), _float_at(vector_3, 2))
		"Vector3i":
			var vector_3i: Array = GFVariantData.as_array(raw_value)
			return Vector3i(_int_at(vector_3i, 0), _int_at(vector_3i, 1), _int_at(vector_3i, 2))
		"Vector4":
			var vector_4: Array = GFVariantData.as_array(raw_value)
			return Vector4(_float_at(vector_4, 0), _float_at(vector_4, 1), _float_at(vector_4, 2), _float_at(vector_4, 3))
		"Vector4i":
			var vector_4i: Array = GFVariantData.as_array(raw_value)
			return Vector4i(_int_at(vector_4i, 0), _int_at(vector_4i, 1), _int_at(vector_4i, 2), _int_at(vector_4i, 3))
		"Rect2":
			var rect_2: Array = GFVariantData.as_array(raw_value)
			return Rect2(_float_at(rect_2, 0), _float_at(rect_2, 1), _float_at(rect_2, 2), _float_at(rect_2, 3))
		"Rect2i":
			var rect_2i: Array = GFVariantData.as_array(raw_value)
			return Rect2i(_int_at(rect_2i, 0), _int_at(rect_2i, 1), _int_at(rect_2i, 2), _int_at(rect_2i, 3))
		"Color":
			var color: Array = GFVariantData.as_array(raw_value)
			return Color(_float_at(color, 0), _float_at(color, 1), _float_at(color, 2), _float_at(color, 3, 1.0))
		"Plane":
			var plane: Array = GFVariantData.as_array(raw_value)
			return Plane(Vector3(_float_at(plane, 0), _float_at(plane, 1), _float_at(plane, 2)), _float_at(plane, 3))
		"Quaternion":
			var quaternion: Array = GFVariantData.as_array(raw_value)
			return Quaternion(_float_at(quaternion, 0), _float_at(quaternion, 1), _float_at(quaternion, 2), _float_at(quaternion, 3, 1.0))
		"AABB":
			var aabb: Array = GFVariantData.as_array(raw_value)
			return AABB(
				Vector3(_float_at(aabb, 0), _float_at(aabb, 1), _float_at(aabb, 2)),
				Vector3(_float_at(aabb, 3), _float_at(aabb, 4), _float_at(aabb, 5))
			)
		"Basis":
			return _array_to_basis(GFVariantData.as_array(raw_value))
		"Transform2D":
			return _array_to_transform_2d(GFVariantData.as_array(raw_value))
		"Transform3D":
			return _dictionary_to_transform_3d(raw_value)
		"Dictionary":
			return _entries_to_dictionary(GFVariantData.as_array(raw_value), options)
		"PackedByteArray":
			return _array_to_packed_byte_array(GFVariantData.as_array(raw_value))
		"PackedInt32Array":
			return _array_to_packed_int32_array(GFVariantData.as_array(raw_value))
		"PackedInt64Array":
			return _array_to_packed_int64_array(GFVariantData.as_array(raw_value))
		"PackedFloat32Array":
			return _array_to_packed_float32_array(GFVariantData.as_array(raw_value))
		"PackedFloat64Array":
			return _array_to_packed_float64_array(GFVariantData.as_array(raw_value))
		"PackedStringArray":
			return _array_to_packed_string_array(GFVariantData.as_array(raw_value))
		"PackedVector2Array":
			return _array_to_packed_vector2_array(GFVariantData.as_array(raw_value))
		"PackedVector3Array":
			return _array_to_packed_vector3_array(GFVariantData.as_array(raw_value))
		"PackedColorArray":
			return _array_to_packed_color_array(GFVariantData.as_array(raw_value))
		"PackedVector4Array":
			return _array_to_packed_vector4_array(GFVariantData.as_array(raw_value))
	return raw_value


static func _json_key_to_string(key: Variant) -> String:
	if key is StringName:
		return GFVariantData.to_text(key)
	return str(key)


static func _is_unsafe_json_integer(value: int) -> bool:
	return value < JSON_SAFE_INTEGER_MIN or value > JSON_SAFE_INTEGER_MAX


static func _float_to_json_compatible(value: float) -> Variant:
	if is_nan(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_NAN_TEXT)
	if is_inf(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_POSITIVE_INF_TEXT if value > 0.0 else _FLOAT_NEGATIVE_INF_TEXT)
	return value


static func _float_array_to_json_compatible(values: Array[float]) -> Array:
	var result: Array = []
	for value: float in values:
		result.append(_float_to_json_compatible(value))
	return result


static func _json_float_marker_to_float(value: Dictionary, fallback: float = 0.0) -> float:
	if not _is_json_typed_value(value):
		return fallback
	var marker: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(value, JSON_MARKER_KEY))
	if GFVariantData.get_option_string(marker, JSON_TYPE_KEY) != _FLOAT_TYPE_NAME:
		return fallback
	return _json_float_value_to_float(GFVariantData.get_option_value(marker, JSON_VALUE_KEY), fallback)


static func _json_float_value_to_float(value: Variant, fallback: float = 0.0) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)

	var text: String = GFVariantData.to_text(value).strip_edges().to_lower()
	match text:
		"nan":
			return NAN
		"inf", "+inf", "infinity", "+infinity":
			return INF
		"-inf", "-infinity":
			return -INF
	return fallback


static func _float_at(array: Array, index: int, fallback: float = 0.0) -> float:
	if index < 0 or index >= array.size():
		return fallback
	return _number_to_float(array[index], fallback)


static func _int_at(array: Array, index: int, fallback: int = 0) -> int:
	if index < 0 or index >= array.size():
		return fallback
	return _number_to_int(array[index], fallback)


static func _basis_to_array(value: Basis) -> Array:
	return _float_array_to_json_compatible([
		value.x.x,
		value.x.y,
		value.x.z,
		value.y.x,
		value.y.y,
		value.y.z,
		value.z.x,
		value.z.y,
		value.z.z,
	])


static func _array_to_basis(value: Array) -> Basis:
	return Basis(
		Vector3(_float_at(value, 0, 1.0), _float_at(value, 1), _float_at(value, 2)),
		Vector3(_float_at(value, 3), _float_at(value, 4, 1.0), _float_at(value, 5)),
		Vector3(_float_at(value, 6), _float_at(value, 7), _float_at(value, 8, 1.0))
	)


static func _transform_2d_to_array(value: Transform2D) -> Array:
	return _float_array_to_json_compatible([
		value.x.x,
		value.x.y,
		value.y.x,
		value.y.y,
		value.origin.x,
		value.origin.y,
	])


static func _array_to_transform_2d(value: Array) -> Transform2D:
	return Transform2D(
		Vector2(_float_at(value, 0, 1.0), _float_at(value, 1)),
		Vector2(_float_at(value, 2), _float_at(value, 3, 1.0)),
		Vector2(_float_at(value, 4), _float_at(value, 5))
	)


static func _dictionary_to_transform_3d(value: Variant) -> Transform3D:
	if not (value is Dictionary):
		return Transform3D()
	var data: Dictionary = value
	var origin: Array = GFVariantData.as_array(GFVariantData.get_option_value(data, "origin", []))
	return Transform3D(
		_array_to_basis(GFVariantData.as_array(GFVariantData.get_option_value(data, "basis", []))),
		Vector3(_float_at(origin, 0), _float_at(origin, 1), _float_at(origin, 2))
	)


static func _entries_to_dictionary(entries: Array, options: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var key: Variant = json_compatible_to_variant(GFVariantData.get_option_value(entry, "key"), options)
		result[key] = json_compatible_to_variant(GFVariantData.get_option_value(entry, "value"), options)
	return result


static func _packed_byte_array_to_array(value: PackedByteArray) -> Array[int]:
	var result: Array[int] = []
	for item: int in value:
		result.append(item)
	return result


static func _array_to_packed_byte_array(value: Array) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	for item: Variant in value:
		var _item_appended: bool = result.append(_number_to_int(item))
	return result


static func _packed_int32_array_to_array(value: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	for item: int in value:
		result.append(item)
	return result


static func _array_to_packed_int32_array(value: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for item: Variant in value:
		var _item_appended: bool = result.append(_number_to_int(item))
	return result


static func _packed_int64_array_to_array(value: PackedInt64Array) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


static func _array_to_packed_int64_array(value: Array) -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	for item: Variant in value:
		var _item_appended: bool = result.append(_number_to_int(item))
	return result


static func _packed_float32_array_to_array(value: PackedFloat32Array) -> Array:
	var result: Array = []
	for item: float in value:
		result.append(_float_to_json_compatible(item))
	return result


static func _array_to_packed_float32_array(value: Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	for item: Variant in value:
		var _item_appended: bool = result.append(_number_to_float(item))
	return result


static func _packed_float64_array_to_array(value: PackedFloat64Array) -> Array:
	var result: Array = []
	for item: float in value:
		result.append(_float_to_json_compatible(item))
	return result


static func _array_to_packed_float64_array(value: Array) -> PackedFloat64Array:
	var result: PackedFloat64Array = PackedFloat64Array()
	for item: Variant in value:
		var _item_appended: bool = result.append(_number_to_float(item))
	return result


static func _packed_string_array_to_array(value: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for item: String in value:
		result.append(item)
	return result


static func _array_to_packed_string_array(value: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: Variant in value:
		var _item_appended: bool = result.append(str(item))
	return result


static func _packed_vector2_array_to_array(value: PackedVector2Array) -> Array:
	var result: Array = []
	for item: Vector2 in value:
		result.append(vector2_to_array(item))
	return result


static func _array_to_packed_vector2_array(value: Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for item: Variant in value:
		var data: Array = GFVariantData.as_array(item)
		var _item_appended: bool = result.append(Vector2(_float_at(data, 0), _float_at(data, 1)))
	return result


static func _packed_vector3_array_to_array(value: PackedVector3Array) -> Array:
	var result: Array = []
	for item: Vector3 in value:
		result.append(vector3_to_array(item))
	return result


static func _array_to_packed_vector3_array(value: Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for item: Variant in value:
		var data: Array = GFVariantData.as_array(item)
		var _item_appended: bool = result.append(Vector3(_float_at(data, 0), _float_at(data, 1), _float_at(data, 2)))
	return result


static func _packed_color_array_to_array(value: PackedColorArray) -> Array:
	var result: Array = []
	for item: Color in value:
		result.append(color_to_array(item))
	return result


static func _array_to_packed_color_array(value: Array) -> PackedColorArray:
	var result: PackedColorArray = PackedColorArray()
	for item: Variant in value:
		var data: Array = GFVariantData.as_array(item)
		var _item_appended: bool = result.append(Color(_float_at(data, 0), _float_at(data, 1), _float_at(data, 2), _float_at(data, 3, 1.0)))
	return result


static func _packed_vector4_array_to_array(value: PackedVector4Array) -> Array:
	var result: Array = []
	for item: Vector4 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y, item.z, item.w]))
	return result


static func _array_to_packed_vector4_array(value: Array) -> PackedVector4Array:
	var result: PackedVector4Array = PackedVector4Array()
	for item: Variant in value:
		var data: Array = GFVariantData.as_array(item)
		var _item_appended: bool = result.append(Vector4(_float_at(data, 0), _float_at(data, 1), _float_at(data, 2), _float_at(data, 3)))
	return result
