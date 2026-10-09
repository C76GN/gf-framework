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

## 规范 typed marker 字典使用的顶层键名。
## [br]
## @api private
const _MARKER_KEY: String = "__gf_deterministic_variant__"

## typed marker 字典写入的 schema 版本。
## [br]
## @api private
const _SCHEMA_VERSION: int = 1

## typed marker 字典中的类型字段名。
## [br]
## @api private
const _TYPE_KEY: String = "type"

## typed marker 字典中的值字段名。
## [br]
## @api private
const _VALUE_KEY: String = "value"

## typed marker 字典中的版本字段名。
## [br]
## @api private
const _VERSION_KEY: String = "version"

## 默认可处理的元素计数上限。
## [br]
## @api private
const _DEFAULT_MAX_ITEMS: int = 100_000

## 默认字符串长度上限。
## [br]
## @api private
const _DEFAULT_MAX_STRING_LENGTH: int = 1_048_576

## 默认规范 JSON 输出字节上限。
## [br]
## @api private
const _DEFAULT_MAX_OUTPUT_BYTES: int = 16 * 1024 * 1024

## 限制单个 JSON 字符串片段的字符数，避免完整转义文本的临时分配。
## [br]
## @api private
const _STRING_CHUNK_CHARACTERS: int = 4096

## 增量 SHA-256 的缓冲上限，不包含输入和字典 key 排序文本。
## [br]
## @api private
const _HASH_CHUNK_BYTES: int = 64 * 1024

## 每个规范浮点 token 都是引号、固定前缀与十六个 hex 字符，共 28 个 ASCII 字节。
## [br]
## @api private
const _FLOAT_TOKEN_BYTES: int = 28


# --- 公共方法 ---

## 将 Variant 转换为 JSON 兼容的规范值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 待编码的 Variant。应为纯数据结构；Object、Resource、Callable、RID 和循环引用会失败。
## [br]
## @schema value: Variant value made from scalar, string, path, vector, rectangle, color, plane, quaternion, AABB, basis, transform, projection, array, dictionary, and packed array values. Float-based values require `options.allow_floats = true`.
## [br]
## @param options: 可选项。支持 allow_floats、max_depth、max_items 和 max_string_length；该入口不生成 bytes，因此不接受 max_output_bytes 作为输出保证。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, and max_string_length limits.
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
	return to_canonical_bytes(value, options).get_string_from_utf8()


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
	var preflight: Dictionary = _preflight(value, options, true)
	if not GFVariantData.get_option_bool(preflight, "ok", true):
		return PackedByteArray()
	var state: Dictionary = _make_state(options)
	var sink: _CanonicalSink = _CanonicalSink.new()
	sink._mode = &"bytes"
	_stream_value(value, state, [], 0, sink)
	if not _finish_stream(state, preflight):
		return PackedByteArray()
	return sink._buffer


## 计算 Variant 规范编码的 SHA-256，预检后构建完整 typed tree 和 JSON 文本以优先降低编码 CPU 开销。
## 大载荷需要控制工作内存时，使用生成相同摘要的 sha256_incremental()。
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
	var preflight: Dictionary = _preflight(value, options, true)
	if not GFVariantData.get_option_bool(preflight, "ok", true):
		return ""
	var state: Dictionary = _make_state(options)
	var canonical_value: Variant = _canonicalize_value(value, state, [], 0)
	if not GFVariantData.get_option_bool(state, "ok", true):
		return ""
	var canonical_json: String = JSON.stringify(canonical_value, "", true)
	var output_bytes: int = canonical_json.to_utf8_buffer().size()
	state["output_bytes"] = output_bytes
	if output_bytes > GFVariantData.get_option_int(state, "max_output_bytes", _DEFAULT_MAX_OUTPUT_BYTES):
		_fail_output(state)
		return ""
	if not _finish_stream(state, preflight):
		return ""
	return canonical_json.sha256_text()


## 逐片计算 Variant 规范编码的 SHA-256，不构建完整 typed tree 或规范 JSON 文本。
## hash 缓冲最多 64 KiB；字典排序仍保留 canonical key 文本，工作内存不是常量。
## 调用期间必须保持输入结构不变，增量编码可能增加 CPU 开销。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 待编码的纯 Variant 数据。
## [br]
## @schema value: Variant value supported by `to_canonical_value()`.
## [br]
## @param options: 与 sha256() 相同的编码选项和预算。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return 与 sha256() 相同的 SHA-256 hex 字符串；失败时返回空字符串。
static func sha256_incremental(value: Variant, options: Dictionary = {}) -> String:
	var preflight: Dictionary = _preflight(value, options, true)
	if not GFVariantData.get_option_bool(preflight, "ok", true):
		return ""
	var state: Dictionary = _make_state(options)
	var sink: _CanonicalSink = _CanonicalSink.new()
	sink._mode = &"hash"
	sink._hashing = HashingContext.new()
	if sink._hashing.start(HashingContext.HASH_SHA256) != OK:
		var _failed: Variant = _fail(state, "Cannot initialize the canonical hashing context.")
		return ""
	_stream_value(value, state, [], 0, sink)
	if not _finish_stream(state, preflight):
		return ""
	if sink._flush() != OK:
		var _failed: Variant = _fail(state, "Cannot update the canonical hashing context.")
		return ""
	return sink._hashing.finish().hex_encode()


## 只读预检规范编码的输入预算和精确输出字节数，不构建完整 typed tree 或输出文本，也不输出错误。
## 调用期间必须保持输入结构不变；报告不为后续已修改的数据提供编码资格。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 待测量的纯 Variant 数据。
## [br]
## @schema value: Variant value supported by `to_canonical_value()`.
## [br]
## @param options: 与规范 bytes 和 SHA-256 相同的编码选项和预算。
## [br]
## @schema options: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
## [br]
## @return 预检报告；成功时计数精确，失败时计数仅描述已遍历部分，不能视为完整输入或输出的大小。
## [br]
## @schema return: Closed Dictionary with ok: bool, error: String, failure_kind: String (empty, input_invalid, or output_limit), items: int (Variant nodes plus packed elements), packed_items: int (packed elements only), and output_bytes: int (exact on success; partial and capped by max_output_bytes on failure).
static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _preflight(value, options, false)
	return {
		"ok": GFVariantData.get_option_bool(state, "ok", true),
		"error": GFVariantData.get_option_string(state, "error"),
		"failure_kind": GFVariantData.get_option_string(state, "failure_kind"),
		"items": GFVariantData.get_option_int(state, "item_count"),
		"packed_items": GFVariantData.get_option_int(state, "packed_item_count"),
		"output_bytes": GFVariantData.get_option_int(state, "output_bytes"),
	}


# --- 私有/辅助方法 ---

## 从选项构造编码状态，并应用最小为 1 的深度、元素和字符串限制。
## [br]
## @api private
static func _make_state(options: Dictionary, report_errors: bool = true) -> Dictionary:
	var max_depth: int = GFVariantData.get_option_int(options, "max_depth", 256)
	return {
		"ok": true,
		"allow_floats": GFVariantData.get_option_bool(options, "allow_floats", false),
		"max_depth": maxi(max_depth, 1),
		"max_items": maxi(GFVariantData.get_option_int(options, "max_items", _DEFAULT_MAX_ITEMS), 1),
		"max_string_length": maxi(GFVariantData.get_option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH), 1),
		"item_count": 0,
		"packed_item_count": 0,
		"output_bytes": 0,
		"max_output_bytes": maxi(GFVariantData.get_option_int(options, "max_output_bytes", _DEFAULT_MAX_OUTPUT_BYTES), 1),
		"output_exceeded": false,
		"report_errors": report_errors,
		"error": "",
		"failure_kind": "",
	}


## 消耗元素预算并检查递归深度，再按 Variant 类型编码或委派给容器助手。
## [br]
## @api private
static func _canonicalize_value(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if not _begin_value(value, state, depth):
		return null
	return _canonicalize_payload(value, state, visited, depth)


## 在任何展开之前计入 Variant 节点、packed 元素和递归深度；两个编码路径共享预算语义。
## [br]
## @api private
static func _begin_value(value: Variant, state: Dictionary, depth: int) -> bool:
	if not GFVariantData.get_option_bool(state, "ok", true):
		return false
	if not _consume_items(state, 1):
		return false
	if depth > GFVariantData.get_option_int(state, "max_depth", 256):
		var _failed: Variant = _fail(state, "Input structure exceeds max_depth.")
		return false
	var packed_item_count: int = _get_packed_item_count(value)
	if packed_item_count > 0:
		if not _consume_items(state, packed_item_count):
			return false
		state["packed_item_count"] = GFVariantData.get_option_int(state, "packed_item_count") + packed_item_count
	return true


## 构建已通过节点预算的 typed payload；流式路径只复用分量数固定的叶值编码。
## [br]
## @api private
static func _canonicalize_payload(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:

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
		TYPE_PROJECTION:
			var projection: Projection = value
			return _make_typed_value(
				"Projection",
				_canonicalize_float_array([
					projection.x.x,
					projection.x.y,
					projection.x.z,
					projection.x.w,
					projection.y.x,
					projection.y.y,
					projection.y.z,
					projection.y.w,
					projection.z.x,
					projection.z.y,
					projection.z.z,
					projection.z.w,
					projection.w.x,
					projection.w.y,
					projection.w.z,
					projection.w.w,
				], state)
			)
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

	return _fail(state, "Unsupported Variant type: %s." % type_string(typeof(value)))


## 拒绝当前递归路径中已出现的同一 Array 引用，并编码其元素。
## [br]
## @api private
static func _canonicalize_array(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if _visited_contains_reference(visited, value):
		return _fail(state, "Input contains a cyclic Array reference.")

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


## 规范化键和值，并按 canonical key 的 JSON 文本排序后编码字典条目。
## [br]
## @api private
static func _canonicalize_dictionary(value: Variant, state: Dictionary, visited: Array, depth: int) -> Variant:
	if _visited_contains_reference(visited, value):
		return _fail(state, "Input contains a cyclic Dictionary reference.")

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


## 创建包含 serializer marker、类型、值和 schema 版本的字典。
## [br]
## @api private
static func _make_typed_value(type_name: String, typed_value: Variant) -> Dictionary:
	return {
		_MARKER_KEY: {
			_TYPE_KEY: type_name,
			_VALUE_KEY: typed_value,
			_VERSION_KEY: _SCHEMA_VERSION,
		},
	}


## 将整数数组的各项转换为十进制字符串。
## [br]
## @api private
static func _canonicalize_int_array(values: Array[int]) -> Array[String]:
	var result: Array[String] = []
	for value: int in values:
		result.append(str(value))
	return result


## 逐项以当前编码状态规范化浮点数组。
## [br]
## @api private
static func _canonicalize_float_array(values: Array[float], state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value: float in values:
		result.append(_canonicalize_float(value, state))
	return result


## 按 allow_floats 规则拒绝禁用值、NaN 或 Inf，并编码 IEEE-754 little-endian 字节。
## [br]
## @api private
static func _canonicalize_float(value: float, state: Dictionary) -> String:
	if not _float_is_valid(value, state):
		return ""
	if value == 0.0:
		return "ieee754le:0000000000000000"
	var bytes: PackedByteArray = PackedByteArray()
	var resize_error: Error = bytes.resize(8) as Error
	if resize_error != OK:
		var _failed: Variant = _fail(state, "Cannot allocate the canonical floating-point encoding buffer.")
		return ""
	bytes.encode_double(0, value)
	return "ieee754le:%s" % bytes.hex_encode()


## 只验证浮点输入，不分配编码缓冲；packed 测量只需固定 token 长度与输入有效性。
## [br]
## @api private
static func _float_is_valid(value: float, state: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(state, "allow_floats", false):
		var _failed: Variant = _fail(state, "Floating-point values are excluded from deterministic encoding by default; use fixed-point numbers or explicitly enable allow_floats.")
		return false
	if is_nan(value) or is_inf(value):
		var _failed: Variant = _fail(state, "Floating-point values must not be NaN or Inf.")
		return false
	return true


## 将 PackedByteArray 的每个字节转换为十进制字符串。
## [br]
## @api private
static func _canonicalize_packed_byte_array(value: PackedByteArray) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


## 将 PackedInt32Array 的每个整数转换为十进制字符串。
## [br]
## @api private
static func _canonicalize_packed_int32_array(value: PackedInt32Array) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


## 将 PackedInt64Array 的每个整数转换为十进制字符串。
## [br]
## @api private
static func _canonicalize_packed_int64_array(value: PackedInt64Array) -> Array[String]:
	var result: Array[String] = []
	for item: int in value:
		result.append(str(item))
	return result


## 逐项使用当前状态规范化 PackedFloat32Array。
## [br]
## @api private
static func _canonicalize_packed_float32_array(value: PackedFloat32Array, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: float in value:
		result.append(_canonicalize_float(item, state))
	return result


## 逐项使用当前状态规范化 PackedFloat64Array。
## [br]
## @api private
static func _canonicalize_packed_float64_array(value: PackedFloat64Array, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: float in value:
		result.append(_canonicalize_float(item, state))
	return result


## 校验 PackedStringArray 中每项的字符串预算并保留其文本。
## [br]
## @api private
static func _canonicalize_packed_string_array(value: PackedStringArray, state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item: String in value:
		if not _string_is_within_budget(item, state):
			return []
		result.append(item)
	return result


## 将 PackedVector2Array 编码为逐项的规范浮点分量数组。
## [br]
## @api private
static func _canonicalize_packed_vector2_array(value: PackedVector2Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector2 in value:
		result.append(_canonicalize_float_array([item.x, item.y], state))
	return result


## 将 PackedVector3Array 编码为逐项的规范浮点分量数组。
## [br]
## @api private
static func _canonicalize_packed_vector3_array(value: PackedVector3Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector3 in value:
		result.append(_canonicalize_float_array([item.x, item.y, item.z], state))
	return result


## 将 PackedColorArray 编码为逐项的规范颜色分量数组。
## [br]
## @api private
static func _canonicalize_packed_color_array(value: PackedColorArray, state: Dictionary) -> Array:
	var result: Array = []
	for item: Color in value:
		result.append(_canonicalize_float_array([item.r, item.g, item.b, item.a], state))
	return result


## 将 PackedVector4Array 编码为逐项的规范浮点分量数组。
## [br]
## @api private
static func _canonicalize_packed_vector4_array(value: PackedVector4Array, state: Dictionary) -> Array:
	var result: Array = []
	for item: Vector4 in value:
		result.append(_canonicalize_float_array([item.x, item.y, item.z, item.w], state))
	return result


## 计数 sink 不排序字典，也不保存规范 key 文本；输出超限后仍检查剩余输入以保留输入错误优先级。
## [br]
## @api private
static func _preflight(value: Variant, options: Dictionary, report_errors: bool) -> Dictionary:
	var state: Dictionary = _make_state(options, report_errors)
	_stream_value(value, state, [], 0, _CanonicalSink.new())
	if GFVariantData.get_option_bool(state, "ok", true) and GFVariantData.get_option_bool(state, "output_exceeded", false):
		_fail_output(state)
	return state


## 在输出完成后重新检查预算和预检计数；调用者仍负责避免并发修改输入。
## [br]
## @api private
static func _finish_stream(state: Dictionary, preflight: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(state, "ok", true):
		return false
	if GFVariantData.get_option_bool(state, "output_exceeded", false):
		_fail_output(state)
		return false
	for field: String in ["item_count", "packed_item_count", "output_bytes"]:
		if GFVariantData.get_option_int(state, field) != GFVariantData.get_option_int(preflight, field):
			var _failed: Variant = _fail(state, "Input changed during canonical encoding.")
			return false
	return true


## 对可增长的容器、packed 数组和字符串逐片编码；固定大小叶值复用 typed 编码协议。
## [br]
## @api private
static func _stream_value(value: Variant, state: Dictionary, visited: Array, depth: int, sink: _CanonicalSink) -> void:
	if not _begin_value(value, state, depth):
		return
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			var text: String = str(value)
			if not _string_is_within_budget(text, state):
				return
			_emit_typed_start(type_string(typeof(value)), state, sink)
			_emit_json_string(text, state, sink)
			_emit_typed_end(state, sink)
		TYPE_ARRAY:
			_stream_array(value, state, visited, depth, sink)
		TYPE_DICTIONARY:
			_stream_dictionary(value, state, visited, depth, sink)
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			_emit_typed_start("Transform3D", state, sink)
			_emit("{\"basis\":", state, sink)
			_stream_value(transform_3d.basis, state, visited, depth + 1, sink)
			_emit(",\"origin\":", state, sink)
			# origin 保持 typed value 路径的计数规则，不另计 Variant 节点或深度。
			var origin: Variant = _canonicalize_payload(transform_3d.origin, state, visited, depth)
			_emit(JSON.stringify(origin, "", true), state, sink)
			_emit("}", state, sink)
			_emit_typed_end(state, sink)
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			_emit_typed_start(type_string(typeof(value)), state, sink)
			_emit("[", state, sink)
			_stream_packed_payload(value, state, sink)
			_emit("]", state, sink)
			_emit_typed_end(state, sink)
		_:
			var leaf: Variant = _canonicalize_payload(value, state, visited, depth)
			_emit(JSON.stringify(leaf, "", true), state, sink)


## packed 测量使用局部字节计数；实际输出把小 token 合并成有界批次以摊薄 sink 与 UTF-8 转换开销。
## [br]
## @api private
static func _stream_packed_payload(value: Variant, state: Dictionary, sink: _CanonicalSink) -> void:
	if sink._mode == &"count":
		var output_bytes: int = GFVariantData.get_option_int(state, "output_bytes")
		var maximum: int = GFVariantData.get_option_int(state, "max_output_bytes", _DEFAULT_MAX_OUTPUT_BYTES)
		var exceeded: bool = GFVariantData.get_option_bool(state, "output_exceeded", false)
		for index: int in _get_packed_item_count(value):
			var element_bytes: int = _measure_packed_element(value[index], state, not exceeded)
			if element_bytes < 0:
				break
			if index > 0:
				element_bytes += 1
			if element_bytes > maximum - output_bytes:
				output_bytes = maximum
				exceeded = true
			else:
				output_bytes += element_bytes
		state["output_bytes"] = output_bytes
		state["output_exceeded"] = exceeded
		return
	var batch: PackedStringArray = PackedStringArray()
	var batch_characters: int = 0
	for index: int in _get_packed_item_count(value):
		var item: Variant = value[index]
		var separator: String = "," if index > 0 else ""
		if item is String:
			var string_item: String = item
			if not _string_is_within_budget(string_item, state):
				return
			if string_item.length() > _STRING_CHUNK_CHARACTERS:
				_emit("".join(batch) + separator, state, sink)
				batch.clear()
				batch_characters = 0
				_emit_json_string(string_item, state, sink)
				continue
		var token: String = _packed_element_token(item, state)
		if token.is_empty():
			return
		var token_characters: int = separator.length() + token.length()
		if batch_characters + token_characters > _STRING_CHUNK_CHARACTERS:
			_emit("".join(batch), state, sink)
			batch.clear()
			batch_characters = 0
			if not GFVariantData.get_option_bool(state, "ok", true):
				return
		if token_characters > _STRING_CHUNK_CHARACTERS:
			_emit(separator + token, state, sink)
			continue
		# PackedArray.append() 的 bool 来自 Vector 对 Error 的转换，false 表示 OK。
		var append_failed: bool = batch.append(separator + token)
		if append_failed:
			var _failed: Variant = _fail(state, "Cannot allocate the canonical packed token batch.")
			return
		batch_characters += token_characters
	_emit("".join(batch), state, sink)


## packed 元素的精确 JSON 字节计数；输出已饱和后仍执行输入校验，但不再生成 token 文本。
## [br]
## @api private
static func _measure_packed_element(value: Variant, state: Dictionary, measure_output: bool) -> int:
	match typeof(value):
		TYPE_INT:
			return str(value).length() + 2 if measure_output else 0
		TYPE_FLOAT:
			var float_value: float = value
			if not _float_is_valid(float_value, state):
				return -1
			return _FLOAT_TOKEN_BYTES if measure_output else 0
		TYPE_STRING:
			var text: String = value
			if not _string_is_within_budget(text, state):
				return -1
			if not measure_output:
				return 0
			var byte_count: int = 2
			var offset: int = 0
			while offset < text.length():
				byte_count += JSON.stringify(text.substr(offset, _STRING_CHUNK_CHARACTERS), "", true).to_utf8_buffer().size() - 2
				offset += _STRING_CHUNK_CHARACTERS
			return byte_count
	var components: Array[float] = _packed_float_components(value)
	for component: float in components:
		if not _float_is_valid(component, state):
			return -1
	return 1 + components.size() * (_FLOAT_TOKEN_BYTES + 1) if measure_output else 0


## 只为小 packed 元素生成 token；大型字符串由分段字符串入口处理，不物化整串转义文本。
## [br]
## @api private
static func _packed_element_token(value: Variant, state: Dictionary) -> String:
	match typeof(value):
		TYPE_INT:
			var int_value: int = value
			return "\"%s\"" % str(int_value)
		TYPE_FLOAT:
			var float_value: float = value
			var float_token: String = _canonicalize_float(float_value, state)
			return "\"%s\"" % float_token if not float_token.is_empty() else ""
		TYPE_STRING:
			var string_value: String = value
			return JSON.stringify(string_value, "", true)
	var tokens: Array[String] = _canonicalize_float_array(_packed_float_components(value), state)
	return JSON.stringify(tokens, "", true) if GFVariantData.get_option_bool(state, "ok", true) else ""


## 获取 packed 向量或颜色的固定数量分量，顺序沿用 typed 编码。
## [br]
## @api private
static func _packed_float_components(value: Variant) -> Array[float]:
	match typeof(value):
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return [vector_2.x, vector_2.y]
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return [vector_3.x, vector_3.y, vector_3.z]
		TYPE_COLOR:
			var color: Color = value
			return [color.r, color.g, color.b, color.a]
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return [vector_4.x, vector_4.y, vector_4.z, vector_4.w]
	return []


## 依序编码 Array 并以当前递归路径检测循环；共享但非循环的容器可以重复出现。
## [br]
## @api private
static func _stream_array(value: Variant, state: Dictionary, visited: Array, depth: int, sink: _CanonicalSink) -> void:
	if _visited_contains_reference(visited, value):
		var _failed: Variant = _fail(state, "Input contains a cyclic Array reference.")
		return
	visited.append(value)
	_emit_typed_start("Array", state, sink)
	_emit("[", state, sink)
	var array_value: Array = value
	for index: int in array_value.size():
		if index > 0:
			_emit(",", state, sink)
		_stream_value(array_value[index], state, visited, depth + 1, sink)
		if not GFVariantData.get_option_bool(state, "ok", true):
			break
	_emit("]", state, sink)
	_emit_typed_end(state, sink)
	var _removed_array_reference: Variant = visited.pop_back()


## 测量时按插入顺序验证输入；输出时只保留 canonical key 文本并沿用原 sort_custom 比较规则。
## [br]
## @api private
static func _stream_dictionary(value: Variant, state: Dictionary, visited: Array, depth: int, sink: _CanonicalSink) -> void:
	if _visited_contains_reference(visited, value):
		var _failed: Variant = _fail(state, "Input contains a cyclic Dictionary reference.")
		return
	visited.append(value)
	_emit_typed_start("Dictionary", state, sink)
	_emit("[", state, sink)
	var dictionary_value: Dictionary = value
	if sink._mode == &"count":
		var index: int = 0
		for key: Variant in dictionary_value.keys():
			if index > 0:
				_emit(",", state, sink)
			_emit("{\"key\":", state, sink)
			_stream_value(key, state, visited, depth + 1, sink)
			_emit(",\"value\":", state, sink)
			_stream_value(dictionary_value[key], state, visited, depth + 1, sink)
			_emit("}", state, sink)
			index += 1
			if not GFVariantData.get_option_bool(state, "ok", true):
				break
	else:
		_stream_sorted_entries(dictionary_value, state, visited, depth, sink)
	_emit("]", state, sink)
	_emit_typed_end(state, sink)
	var _removed_dictionary_reference: Variant = visited.pop_back()


## 排序 key 可为任意受支持的复合值；key 文本工作集仍随字典大小增长，且受输出预算限制。
## [br]
## @api private
static func _stream_sorted_entries(value: Dictionary, state: Dictionary, visited: Array, depth: int, sink: _CanonicalSink) -> void:
	var entries: Array[Dictionary] = []
	for key: Variant in value.keys():
		var key_state: Dictionary = _make_state(state, false)
		var key_sink: _CanonicalSink = _CanonicalSink.new()
		key_sink._mode = &"bytes"
		_stream_value(key, key_state, visited, depth + 1, key_sink)
		if not GFVariantData.get_option_bool(key_state, "ok", true):
			if GFVariantData.get_option_string(key_state, "failure_kind") == "output_limit":
				_fail_output(state)
			else:
				var _failed: Variant = _fail(state, GFVariantData.get_option_string(key_state, "error"))
			return
		entries.append({
			"sort_key": key_sink._buffer.get_string_from_utf8(),
			"value": value[key],
			"items": GFVariantData.get_option_int(key_state, "item_count"),
			"packed_items": GFVariantData.get_option_int(key_state, "packed_item_count"),
		})
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "sort_key") < GFVariantData.get_option_string(right, "sort_key")
	)
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		if not _consume_items(state, GFVariantData.get_option_int(entry, "items")):
			return
		state["packed_item_count"] = GFVariantData.get_option_int(state, "packed_item_count") + GFVariantData.get_option_int(entry, "packed_items")
		if index > 0:
			_emit(",", state, sink)
		_emit("{\"key\":", state, sink)
		_emit_text_chunks(GFVariantData.get_option_string(entry, "sort_key"), state, sink)
		_emit(",\"value\":", state, sink)
		_stream_value(GFVariantData.get_option_value(entry, "value"), state, visited, depth + 1, sink)
		_emit("}", state, sink)
		if not GFVariantData.get_option_bool(state, "ok", true):
			return


## 写入固定 schema 的 typed marker 前缀；类型名只来自本文件支持的 Godot 类型。
## [br]
## @api private
static func _emit_typed_start(type_name: String, state: Dictionary, sink: _CanonicalSink) -> void:
	_emit("{\"__gf_deterministic_variant__\":{\"type\":\"%s\",\"value\":" % type_name, state, sink)


## 按历史字段排序写入 typed marker 后缀。
## [br]
## @api private
static func _emit_typed_end(state: Dictionary, sink: _CanonicalSink) -> void:
	_emit(",\"version\":1}}", state, sink)


## 分段使用 Godot 自身的 JSON 字符串转义，确保 Unicode、控制字符和转义字节与旧协议完全相同。
## [br]
## @api private
static func _emit_json_string(value: String, state: Dictionary, sink: _CanonicalSink) -> void:
	_emit("\"", state, sink)
	var offset: int = 0
	while offset < value.length() and GFVariantData.get_option_bool(state, "ok", true) and not GFVariantData.get_option_bool(state, "output_exceeded", false):
		var token: String = JSON.stringify(value.substr(offset, _STRING_CHUNK_CHARACTERS), "", true)
		_emit(token.substr(1, token.length() - 2), state, sink)
		offset += _STRING_CHUNK_CHARACTERS
	_emit("\"", state, sink)


## 分段消费已经规范化的 key 文本，避免为完整 key 再分配一份 UTF-8 临时数组。
## [br]
## @api private
static func _emit_text_chunks(value: String, state: Dictionary, sink: _CanonicalSink) -> void:
	var offset: int = 0
	while offset < value.length() and GFVariantData.get_option_bool(state, "ok", true):
		_emit(value.substr(offset, _STRING_CHUNK_CHARACTERS), state, sink)
		offset += _STRING_CHUNK_CHARACTERS


## 计量一个有界文本片段；计数模式在输出超限时饱和，实际输出模式立即停止并拒绝部分结果。
## [br]
## @api private
static func _emit(fragment: String, state: Dictionary, sink: _CanonicalSink) -> void:
	if not GFVariantData.get_option_bool(state, "ok", true) or GFVariantData.get_option_bool(state, "output_exceeded", false):
		return
	var bytes: PackedByteArray = fragment.to_utf8_buffer()
	var output_bytes: int = GFVariantData.get_option_int(state, "output_bytes")
	var max_output_bytes: int = GFVariantData.get_option_int(state, "max_output_bytes", _DEFAULT_MAX_OUTPUT_BYTES)
	if bytes.size() > max_output_bytes - output_bytes:
		state["output_bytes"] = max_output_bytes
		state["output_exceeded"] = true
		if sink._mode != &"count":
			_fail_output(state)
		return
	state["output_bytes"] = output_bytes + bytes.size()
	if sink._write(bytes) != OK:
		var _failed: Variant = _fail(state, "Cannot update the canonical hashing context.")


## 记录唯一输出预算错误；安静测量仅填充报告字段，不发出 native diagnostic。
## [br]
## @api private
static func _fail_output(state: Dictionary) -> void:
	if GFVariantData.get_option_bool(state, "ok", true):
		state["ok"] = false
		state["error"] = "Canonical output exceeds max_output_bytes."
		state["failure_kind"] = "output_limit"
		if GFVariantData.get_option_bool(state, "report_errors", true):
			push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")


## 检查 visited 中是否已包含同一容器引用。
## [br]
## @api private
static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


## 增加非负元素数并检查 max_items；超限时将 state 标为失败。
## [br]
## @api private
static func _consume_items(state: Dictionary, amount: int) -> bool:
	var current_count: int = GFVariantData.get_option_int(state, "item_count")
	var consumed: int = maxi(amount, 0)
	if consumed > GFVariantData.get_option_int(state, "max_items", _DEFAULT_MAX_ITEMS) - current_count:
		var _failed: Variant = _fail(state, "Input collection exceeds max_items.")
		return false
	state["item_count"] = current_count + consumed
	return true


## 检查字符串长度；超限时记录失败并返回 false。
## [br]
## @api private
static func _string_is_within_budget(value: String, state: Dictionary) -> bool:
	if value.length() <= GFVariantData.get_option_int(state, "max_string_length", _DEFAULT_MAX_STRING_LENGTH):
		return true
	var _failed: Variant = _fail(state, "String exceeds max_string_length.")
	return false


## 返回支持的 PackedArray 元素数量，其他 Variant 返回 0。
## [br]
## @api private
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


## 记录首个序列化失败并输出错误；后续失败不覆盖已有状态。
## [br]
## @api private
static func _fail(state: Dictionary, message: String) -> Variant:
	if GFVariantData.get_option_bool(state, "ok", true):
		state["ok"] = false
		state["error"] = message
		state["failure_kind"] = "input_invalid"
		if GFVariantData.get_option_bool(state, "report_errors", true):
			push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: %s." % message)
	return null


# --- 内部类 ---

## 单次编码持有的 sink；字节入口保存完整输出，hash 入口最多保留一个固定大小缓冲。
## [br]
## @api private
class _CanonicalSink extends RefCounted:
	# --- 私有变量 ---

	## count 仅计量，bytes 收集输出，hash 逐块更新；不向调用者暴露任意回调。
	## [br]
	## @api private
	var _mode: StringName = &"count"

	## 由本 sink 独占可变引用，避免每个片段写入触发 PackedByteArray 的复制。
	## [br]
	## @api private
	var _buffer: PackedByteArray = PackedByteArray()

	## hash 模式拥有的上下文，失败时不会发布未完成的摘要。
	## [br]
	## @api private
	var _hashing: HashingContext = null

	# --- 私有/辅助方法 ---

	## 将片段加入输出或固定大小 hash 缓冲；返回错误让外层统一拒绝部分结果。
	## [br]
	## @api private
	func _write(fragment: PackedByteArray) -> Error:
		if _mode == &"bytes":
			_buffer.append_array(fragment)
			return OK
		if _mode != &"hash":
			return OK
		var offset: int = 0
		while offset < fragment.size():
			var amount: int = mini(_HASH_CHUNK_BYTES - _buffer.size(), fragment.size() - offset)
			_buffer.append_array(fragment.slice(offset, offset + amount))
			offset += amount
			if _buffer.size() == _HASH_CHUNK_BYTES:
				var update_error: Error = _flush()
				if update_error != OK:
					return update_error
		return OK


	## 提交最后一个或已填满的 hash 缓冲；空缓冲不发起无意义的 update。
	## [br]
	## @api private
	func _flush() -> Error:
		if _hashing == null:
			return ERR_UNCONFIGURED
		if _buffer.is_empty():
			return OK
		var update_error: Error = _hashing.update(_buffer)
		_buffer.clear()
		return update_error
