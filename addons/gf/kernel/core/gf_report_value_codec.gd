## GFReportValueCodec: 报告与诊断快照的 JSON-safe 值编码器。
##
## 用于把公开报告、调试快照和诊断事件中的任意 Variant 收束为
## JSON.stringify() 可安全处理的结构。Object、Callable、Signal 和 RID
## 会被结构化脱敏，不会把运行时对象直接泄漏到报告边界。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFReportValueCodec
extends RefCounted


const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

const _REPORT_MARKER_KEY: String = "__gf_report_value__"
const _REPORT_SCHEMA_VERSION: int = 1
const _VARIANT_MARKER_KEY: String = "__gf_variant__"
const _VARIANT_SCHEMA_VERSION: int = 1
const _JSON_SAFE_INTEGER_MAX: int = 9_007_199_254_740_991
const _JSON_SAFE_INTEGER_MIN: int = -9_007_199_254_740_991
const _FLOAT_TYPE_NAME: String = "Float"
const _FLOAT_NAN_TEXT: String = "NaN"
const _FLOAT_POSITIVE_INF_TEXT: String = "INF"
const _FLOAT_NEGATIVE_INF_TEXT: String = "-INF"
const _DEFAULT_MAX_DEPTH: int = 32
const _DEFAULT_MAX_STRING_LENGTH: int = 8192
const _DEFAULT_SUMMARY_SAMPLE_COUNT: int = 16
const _DEFAULT_MAX_COLLECTION_ITEMS: int = 1024
const _DEFAULT_MAX_PACKED_LENGTH: int = 4096
const _DEFAULT_MAX_TOTAL_NODES: int = 16384
const _DEFAULT_MAX_TOTAL_BYTES: int = 1024 * 1024
const _COMPACT_TRUNCATION_MARKER: String = "<gf_truncated>"


# --- 常量 ---

## 本地调试报告配置，保留对象 id、Node 名称和路径，路径不脱敏。
## [br]
## @api public
## [br]
## @since 8.0.0
const REDACTION_PROFILE_DEBUG: String = "debug"

## 支持排障报告配置，保留对象 id 和 Node 名称，但默认隐藏路径。
## [br]
## @api public
## [br]
## @since 8.0.0
const REDACTION_PROFILE_SUPPORT: String = "support"

## 对外报告配置，隐藏对象 id、Node 名称和路径，只保留类型和有效性。
## [br]
## @api public
## [br]
## @since 8.0.0
const REDACTION_PROFILE_PUBLIC: String = "public"

## 隐私优先报告配置，隐藏对象 id、Node 名称、路径和 Resource 路径。
## [br]
## @api public
## [br]
## @since 8.0.0
const REDACTION_PROFILE_PRIVACY: String = "privacy"


# --- 公共方法 ---

## 根据内置脱敏 profile 构建报告编码选项。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile: REDACTION_PROFILE_* 常量之一。
## [br]
## @param overrides: 覆盖默认 profile 的选项。
## [br]
## @return 编码选项字典。
## [br]
## @schema overrides: Dictionary，可覆盖 redaction_profile、path_redaction、include_node_name、include_node_path、include_object_instance_id、include_resource_path、max_depth、max_string_length、max_collection_items、max_packed_length、max_total_nodes 和 max_total_bytes。
## [br]
## @schema return: Dictionary，可直接传给 GFReportValueCodec 的编码选项。
static func make_redaction_options(profile: String, overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _get_profile_defaults(profile)
	for key: Variant in overrides.keys():
		result[key] = _duplicate_variant(overrides[key])
	result["redaction_profile"] = profile
	return result


## 将任意 Variant 转为报告边界可安全 JSON.stringify() 的值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待转换的报告值。
## [br]
## @param options: 可选项；支持 redaction_profile、circular_reference、include_resource_path、include_node_name、include_node_path、include_object_instance_id、max_depth、max_string_length、max_collection_items、max_packed_length、max_total_nodes、max_total_bytes 和 path_redaction；路径默认脱敏，所有非负预算均为遍历工作量与输出硬上限。
## [br]
## @return JSON 兼容值；不支持的运行时类型会写入脱敏 marker。
## [br]
## @schema value: Variant report value to encode.
## [br]
## @schema options: Dictionary with redaction_profile, circular_reference, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options; path_redaction defaults to redacted and non-negative budgets stop traversal immediately when exhausted.
## [br]
## @schema return: Variant made only from JSON-compatible values, GF variant markers, and GF report redaction markers.
static func to_json_compatible(value: Variant, options: Dictionary = {}) -> Variant:
	var effective_options: Dictionary = _normalize_options(options)
	var budget_state: Dictionary = {
		"node_count": 0,
		"work_bytes": 0,
		"truncated_count": 0,
		"exhausted": false,
		"reason": "",
	}
	var sanitized: Variant = _sanitize_report_value(value, effective_options, [], 0, budget_state)
	var encoded: Variant = _variant_to_json_compatible(sanitized, _make_variant_json_options(effective_options), [])
	return _apply_final_byte_budget(encoded, effective_options)


## 将任意报告值转为 JSON-safe Dictionary。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待转换的报告值。
## [br]
## @param options: 传给 to_json_compatible() 的编码选项。
## [br]
## @return JSON-safe 字典；转换结果不是 Dictionary 时返回空字典。
## [br]
## @schema value: Variant report value to encode before narrowing to Dictionary.
## [br]
## @schema options: Dictionary with redaction_profile, circular_reference, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options.
## [br]
## @schema return: Dictionary made only from JSON-compatible values, GF variant markers, and GF report redaction markers.
static func to_report_dictionary(value: Variant, options: Dictionary = {}) -> Dictionary:
	var encoded: Variant = to_json_compatible(value, options)
	if encoded is Dictionary:
		var encoded_dictionary: Dictionary = encoded
		return encoded_dictionary.duplicate(true)
	return {}


## 将报告值转为 JSON-safe 后序列化为文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待序列化的报告值。
## [br]
## @param indent: 缩进字符串；空字符串表示压缩输出。
## [br]
## @param sort_keys: 是否按键名排序 Dictionary。
## [br]
## @param options: 传给 to_json_compatible() 的编码选项。
## [br]
## @return JSON 文本。
## [br]
## @schema value: Variant report value to encode before JSON.stringify().
## [br]
## @schema options: Dictionary with redaction_profile, circular_reference, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options.
static func stringify_json_compatible(
	value: Variant,
	indent: String = "",
	sort_keys: bool = false,
	options: Dictionary = {}
) -> String:
	var encoded: Variant = to_json_compatible(value, options)
	var text: String = JSON.stringify(encoded, indent, sort_keys)
	var effective_options: Dictionary = _normalize_options(options)
	var max_total_bytes: int = _option_int(
		effective_options,
		"max_total_bytes",
		_DEFAULT_MAX_TOTAL_BYTES
	)
	if max_total_bytes < 0 or text.to_utf8_buffer().size() <= max_total_bytes:
		return text
	var fallback: Variant = _make_final_byte_budget_value(max_total_bytes)
	var fallback_text: String = JSON.stringify(fallback)
	if fallback_text.to_utf8_buffer().size() <= max_total_bytes:
		return fallback_text
	return ""


## 为报告中的大型集合生成稳定摘要。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待摘要的集合值。
## [br]
## @param options: 可选项；支持 sample_count 和传给 stringify_json_compatible() 的编码选项。
## [br]
## @return 摘要字典。
## [br]
## @schema value: Variant collection value to summarize.
## [br]
## @schema options: Dictionary with sample_count and GFReportValueCodec encoding options.
## [br]
## @schema return: Dictionary with ok, collection_type, count, sample, truncated, and hash.
static func make_collection_summary(value: Variant, options: Dictionary = {}) -> Dictionary:
	var collection_size: int = _get_collection_size(value)
	if collection_size < 0:
		return {
			"ok": false,
			"collection_type": type_string(typeof(value)),
			"count": 0,
			"sample": [],
			"truncated": false,
			"hash": "",
		}

	var effective_options: Dictionary = _normalize_options(options)
	var sample_count: int = maxi(_option_int(effective_options, "sample_count", _DEFAULT_SUMMARY_SAMPLE_COUNT), 0)
	var sample: Array = _make_collection_sample(value, mini(sample_count, collection_size))
	var full_text: String = stringify_json_compatible(value, "", true, effective_options)
	return {
		"ok": true,
		"collection_type": type_string(typeof(value)),
		"count": collection_size,
		"sample": to_json_compatible(sample, effective_options),
		"truncated": collection_size > sample.size(),
		"hash": full_text.sha256_text(),
	}


# --- 私有/辅助方法 ---

static func _sanitize_report_value(
	value: Variant,
	options: Dictionary,
	visited: Array,
	depth: int,
	budget_state: Dictionary
) -> Variant:
	if _is_budget_exhausted(budget_state):
		return _make_budget_exhaustion_marker(budget_state, options)
	var max_depth: int = _option_int(options, "max_depth", _DEFAULT_MAX_DEPTH)
	if max_depth >= 0 and depth > max_depth:
		_mark_budget_truncated(budget_state)
		return _make_marker("MaxDepth", {
			"depth": depth,
			"max_depth": max_depth,
		})
	var max_total_nodes: int = _option_int(options, "max_total_nodes", _DEFAULT_MAX_TOTAL_NODES)
	var node_count: int = _option_int(budget_state, "node_count", 0)
	if max_total_nodes >= 0 and node_count >= max_total_nodes:
		_exhaust_budget(budget_state, "NodeBudget")
		return _make_budget_exhaustion_marker(budget_state, options)
	budget_state["node_count"] = node_count + 1
	if not _consume_value_work_budget(value, options, budget_state):
		return _make_budget_exhaustion_marker(budget_state, options)

	match typeof(value):
		TYPE_STRING:
			var text_value: String = value
			return _sanitize_string_value(text_value, options)
		TYPE_STRING_NAME:
			var string_name_text: String = str(value)
			var sanitized_string_name: String = _sanitize_string_value(string_name_text, options)
			return value if sanitized_string_name == string_name_text else sanitized_string_name
		TYPE_NODE_PATH:
			var node_path_text: String = str(value)
			var sanitized_node_path: String = _sanitize_known_path_value(node_path_text, options)
			return value if sanitized_node_path == node_path_text else sanitized_node_path
		TYPE_ARRAY:
			if _visited_contains_reference(visited, value):
				return _make_marker("CircularReference", {
					"value": _option_value(options, "circular_reference", "<circular_reference>"),
				})
			visited.append(value)
			var array_value: Array = value
			var array_result: Array = []
			var array_limit: int = _get_collection_limit(array_value.size(), options)
			for index: int in range(array_limit):
				array_result.append(_sanitize_report_value(array_value[index], options, visited, depth + 1, budget_state))
				if _is_budget_exhausted(budget_state):
					break
			if not _is_budget_exhausted(budget_state) and array_value.size() > array_limit:
				_mark_budget_truncated(budget_state)
				array_result.append(_make_marker("CollectionBudget", {
					"collection_type": "Array",
					"count": array_value.size(),
					"omitted_count": array_value.size() - array_limit,
				}))
			var _removed_array_reference: Variant = visited.pop_back()
			return array_result
		TYPE_DICTIONARY:
			if _visited_contains_reference(visited, value):
				return _make_marker("CircularReference", {
					"value": _option_value(options, "circular_reference", "<circular_reference>"),
				})
			visited.append(value)
			var dictionary_value: Dictionary = value
			var dictionary_result: Dictionary = {}
			var encoded_entries: Array[Dictionary] = []
			var requires_entry_encoding: bool = false
			var dictionary_keys: Array = dictionary_value.keys()
			var dictionary_limit: int = _get_collection_limit(dictionary_keys.size(), options)
			for index: int in range(dictionary_limit):
				var key: Variant = dictionary_keys[index]
				var sanitized_key: Variant = _sanitize_report_value(key, options, visited, depth + 1, budget_state)
				if _is_budget_exhausted(budget_state):
					break
				var sanitized_value: Variant = _sanitize_report_value(dictionary_value[key], options, visited, depth + 1, budget_state)
				if _is_budget_exhausted(budget_state):
					break
				encoded_entries.append({
					"key": sanitized_key,
					"value": sanitized_value,
				})
				if _report_key_requires_entry_encoding(key, sanitized_key):
					requires_entry_encoding = true
				else:
					dictionary_result[key] = sanitized_value
			var _removed_dictionary_reference: Variant = visited.pop_back()
			if _is_budget_exhausted(budget_state):
				return _make_budget_exhaustion_marker(budget_state, options)
			if dictionary_keys.size() > dictionary_limit:
				_mark_budget_truncated(budget_state)
				var collection_sample: Variant = dictionary_result
				if requires_entry_encoding:
					collection_sample = encoded_entries
				return _make_marker("CollectionBudget", {
					"collection_type": "Dictionary",
					"count": dictionary_keys.size(),
					"omitted_count": dictionary_keys.size() - dictionary_limit,
					"sample": collection_sample,
				})
			if requires_entry_encoding:
				return _make_marker("Dictionary", { "entries": encoded_entries })
			return dictionary_result
		TYPE_OBJECT:
			return _object_to_marker(value, options)
		TYPE_CALLABLE:
			var callable_value: Callable = value
			return _make_marker("Callable", {
				"valid": callable_value.is_valid(),
			})
		TYPE_SIGNAL:
			return _make_marker("Signal", {})
		TYPE_RID:
			return _make_marker("RID", {})
		_:
			if _is_packed_array_type(typeof(value)):
				return _sanitize_packed_array(value, options, visited, depth, budget_state)
			return value


static func _get_collection_limit(collection_size: int, options: Dictionary) -> int:
	var max_collection_items: int = _option_int(
		options,
		"max_collection_items",
		_DEFAULT_MAX_COLLECTION_ITEMS
	)
	if max_collection_items < 0:
		return collection_size
	return mini(collection_size, max_collection_items)


static func _get_packed_limit(collection_size: int, options: Dictionary) -> int:
	var collection_limit: int = _get_collection_limit(collection_size, options)
	var max_packed_length: int = _option_int(options, "max_packed_length", _DEFAULT_MAX_PACKED_LENGTH)
	if max_packed_length < 0:
		return collection_limit
	return mini(collection_limit, max_packed_length)


static func _mark_budget_truncated(budget_state: Dictionary) -> void:
	budget_state["truncated_count"] = _option_int(budget_state, "truncated_count", 0) + 1


static func _is_budget_exhausted(budget_state: Dictionary) -> bool:
	return _option_bool(budget_state, "exhausted", false)


static func _exhaust_budget(budget_state: Dictionary, reason: String) -> void:
	if _is_budget_exhausted(budget_state):
		return
	budget_state["exhausted"] = true
	budget_state["reason"] = reason
	_mark_budget_truncated(budget_state)


static func _make_budget_exhaustion_marker(budget_state: Dictionary, options: Dictionary) -> Dictionary:
	var reason: String = _option_string(budget_state, "reason", "Budget")
	var payload: Dictionary = {
		"reason": reason,
		"node_count": _option_int(budget_state, "node_count", 0),
		"work_bytes": _option_int(budget_state, "work_bytes", 0),
	}
	if reason == "NodeBudget":
		payload["max_total_nodes"] = _option_int(options, "max_total_nodes", _DEFAULT_MAX_TOTAL_NODES)
	if reason == "ByteBudget":
		payload["max_total_bytes"] = _option_int(options, "max_total_bytes", _DEFAULT_MAX_TOTAL_BYTES)
	return _make_marker(reason, payload)


static func _consume_value_work_budget(
	value: Variant,
	options: Dictionary,
	budget_state: Dictionary
) -> bool:
	var max_total_bytes: int = _option_int(options, "max_total_bytes", _DEFAULT_MAX_TOTAL_BYTES)
	if max_total_bytes < 0:
		return true
	var used_bytes: int = _option_int(budget_state, "work_bytes", 0)
	var remaining_bytes: int = maxi(max_total_bytes - used_bytes, 0)
	var minimum_cost: int = _estimate_minimum_work_bytes(value)
	if minimum_cost > remaining_bytes:
		_exhaust_budget(budget_state, "ByteBudget")
		return false
	var exact_cost: int = minimum_cost
	match typeof(value):
		TYPE_STRING:
			var string_value: String = value
			exact_cost = string_value.to_utf8_buffer().size() + 2
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			var text_value: String = str(value)
			exact_cost = text_value.to_utf8_buffer().size() + 2
	if exact_cost > remaining_bytes:
		_exhaust_budget(budget_state, "ByteBudget")
		return false
	budget_state["work_bytes"] = used_bytes + exact_cost
	return true


static func _estimate_minimum_work_bytes(value: Variant) -> int:
	match typeof(value):
		TYPE_STRING:
			var string_value: String = value
			return string_value.length() + 2
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value).length() + 2
		TYPE_ARRAY, TYPE_DICTIONARY:
			return 2
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return 128
		_:
			if _is_packed_array_type(typeof(value)):
				return 2
			return 32


static func _is_packed_array_type(value_type: int) -> bool:
	return value_type in [
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


static func _sanitize_packed_array(
	value: Variant,
	options: Dictionary,
	visited: Array,
	depth: int,
	budget_state: Dictionary
) -> Variant:
	var item_count: int = len(value)
	var item_limit: int = _get_packed_limit(item_count, options)
	var sample: Array = []
	for index: int in range(item_limit):
		sample.append(_sanitize_report_value(value[index], options, visited, depth + 1, budget_state))
		if _is_budget_exhausted(budget_state):
			break
	if _is_budget_exhausted(budget_state):
		return _make_budget_exhaustion_marker(budget_state, options)
	if item_count <= item_limit:
		if typeof(value) == TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(sample)
		return value
	_mark_budget_truncated(budget_state)
	return _make_marker("CollectionBudget", {
		"collection_type": type_string(typeof(value)),
		"count": item_count,
		"omitted_count": item_count - item_limit,
		"sample": sample,
	})


static func _report_key_requires_entry_encoding(source_key: Variant, sanitized_key: Variant) -> bool:
	match typeof(source_key):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID, TYPE_ARRAY, TYPE_DICTIONARY:
			return true
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(source_key) != str(sanitized_key) or typeof(source_key) != typeof(sanitized_key)
	return false


static func _object_to_marker(value: Variant, options: Dictionary) -> Dictionary:
	if value == null:
		return _make_marker("Object", {
			"valid": false,
		})
	var object: Object = value
	if not is_instance_valid(object):
		return _make_marker("Object", {
			"valid": false,
		})

	var payload: Dictionary = {
		"valid": true,
		"class": object.get_class(),
		"class_name": object.get_class(),
	}
	if _option_bool(options, "include_object_instance_id", true):
		payload["instance_id"] = object.get_instance_id()
	if object is Node:
		var node: Node = object
		if _option_bool(options, "include_node_name", true):
			payload["node_name"] = String(node.name)
		if _option_bool(options, "include_node_path", false):
			payload["node_path"] = _redact_path(String(node.get_path()) if node.is_inside_tree() else String(node.name), options)
	if object is Resource and _option_bool(options, "include_resource_path", true):
		var resource: Resource = object
		if not resource.resource_path.is_empty():
			payload["resource_path"] = _redact_path(resource.resource_path, options)
	return _make_marker("Object", payload)


static func _variant_to_json_compatible(value: Variant, options: Dictionary, visited: Array) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var float_value: float = value
			return _float_to_json_compatible(float_value)
		TYPE_INT:
			var int_value: int = _number_to_int(value)
			if _option_bool(options, "encode_unsafe_ints", true) and _is_unsafe_json_integer(int_value):
				return _make_json_typed_value("Int64", str(int_value))
			return int_value
		TYPE_STRING_NAME:
			return _make_json_typed_value("StringName", str(value))
		TYPE_NODE_PATH:
			return _make_json_typed_value("NodePath", str(value))
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _make_json_typed_value("Vector2", _float_array_to_json_compatible([vector_2.x, vector_2.y]))
		TYPE_VECTOR2I:
			var vector_2i: Vector2i = value
			return _make_json_typed_value("Vector2i", [vector_2i.x, vector_2i.y])
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _make_json_typed_value("Vector3", _float_array_to_json_compatible([vector_3.x, vector_3.y, vector_3.z]))
		TYPE_VECTOR3I:
			var vector_3i: Vector3i = value
			return _make_json_typed_value("Vector3i", [vector_3i.x, vector_3i.y, vector_3i.z])
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _make_json_typed_value("Vector4", _float_array_to_json_compatible([vector_4.x, vector_4.y, vector_4.z, vector_4.w]))
		TYPE_VECTOR4I:
			var vector_4i: Vector4i = value
			return _make_json_typed_value("Vector4i", [vector_4i.x, vector_4i.y, vector_4i.z, vector_4i.w])
		TYPE_RECT2:
			var rect_2: Rect2 = value
			return _make_json_typed_value("Rect2", _float_array_to_json_compatible([rect_2.position.x, rect_2.position.y, rect_2.size.x, rect_2.size.y]))
		TYPE_RECT2I:
			var rect_2i: Rect2i = value
			return _make_json_typed_value("Rect2i", [rect_2i.position.x, rect_2i.position.y, rect_2i.size.x, rect_2i.size.y])
		TYPE_COLOR:
			var color: Color = value
			return _make_json_typed_value("Color", _float_array_to_json_compatible([color.r, color.g, color.b, color.a]))
		TYPE_PLANE:
			var plane: Plane = value
			return _make_json_typed_value("Plane", _float_array_to_json_compatible([plane.normal.x, plane.normal.y, plane.normal.z, plane.d]))
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return _make_json_typed_value("Quaternion", _float_array_to_json_compatible([quaternion.x, quaternion.y, quaternion.z, quaternion.w]))
		TYPE_AABB:
			var aabb: AABB = value
			return _make_json_typed_value("AABB", _float_array_to_json_compatible([aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z]))
		TYPE_BASIS:
			var basis: Basis = value
			return _make_json_typed_value("Basis", _basis_to_array(basis))
		TYPE_TRANSFORM2D:
			var transform_2d: Transform2D = value
			return _make_json_typed_value("Transform2D", _transform_2d_to_array(transform_2d))
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			return _make_json_typed_value("Transform3D", {
				"basis": _basis_to_array(transform_3d.basis),
				"origin": _float_array_to_json_compatible([transform_3d.origin.x, transform_3d.origin.y, transform_3d.origin.z]),
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
			var byte_array: PackedByteArray = value
			return _make_json_typed_value("PackedByteArray", _packed_byte_array_to_array(byte_array))
		TYPE_PACKED_INT32_ARRAY:
			var int_32_array: PackedInt32Array = value
			return _make_json_typed_value("PackedInt32Array", Array(int_32_array))
		TYPE_PACKED_INT64_ARRAY:
			var int_64_array: PackedInt64Array = value
			return _make_json_typed_value("PackedInt64Array", Array(int_64_array))
		TYPE_PACKED_FLOAT32_ARRAY:
			var float_32_array: PackedFloat32Array = value
			return _make_json_typed_value("PackedFloat32Array", _float_array_to_json_compatible(Array(float_32_array)))
		TYPE_PACKED_FLOAT64_ARRAY:
			var float_64_array: PackedFloat64Array = value
			return _make_json_typed_value("PackedFloat64Array", _float_array_to_json_compatible(Array(float_64_array)))
		TYPE_PACKED_STRING_ARRAY:
			var string_array: PackedStringArray = value
			return _make_json_typed_value("PackedStringArray", Array(string_array))
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector_2_array: PackedVector2Array = value
			return _make_json_typed_value("PackedVector2Array", _vector_2_array_to_array(vector_2_array))
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector_3_array: PackedVector3Array = value
			return _make_json_typed_value("PackedVector3Array", _vector_3_array_to_array(vector_3_array))
		TYPE_PACKED_COLOR_ARRAY:
			var color_array: PackedColorArray = value
			return _make_json_typed_value("PackedColorArray", _color_array_to_array(color_array))
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector_4_array: PackedVector4Array = value
			return _make_json_typed_value("PackedVector4Array", _vector_4_array_to_array(vector_4_array))
		_:
			if _option_string(options, "unsupported", "null") == "string":
				return str(value)
	return null


static func _dictionary_to_json_compatible(value: Dictionary, options: Dictionary, visited: Array) -> Variant:
	if _option_bool(options, "encode_dictionary_keys", false):
		return _make_json_typed_value("Dictionary", _dictionary_entries_to_json_compatible(value, options, visited))

	var result: Dictionary = {}
	var seen_json_keys: Dictionary = {}
	for key: Variant in value.keys():
		var json_key: String = _json_key_to_string(key)
		if seen_json_keys.has(json_key):
			return _make_json_typed_value("Dictionary", _dictionary_entries_to_json_compatible(value, options, visited))
		seen_json_keys[json_key] = true
		result[json_key] = _variant_to_json_compatible(value[key], options, visited)
	if _has_reserved_variant_marker_shape(result):
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


static func _make_marker(marker_type: String, payload: Dictionary) -> Dictionary:
	var marker: Dictionary = {
		"version": _REPORT_SCHEMA_VERSION,
		"type": marker_type,
		"redacted": true,
	}
	for key: Variant in payload.keys():
		marker[key] = _duplicate_variant(payload[key])
	return {
		_REPORT_MARKER_KEY: marker,
	}


static func _make_json_typed_value(type_name: String, typed_value: Variant) -> Dictionary:
	return {
		_VARIANT_MARKER_KEY: {
			"version": _VARIANT_SCHEMA_VERSION,
			"type": type_name,
			"value": typed_value,
		},
	}


static func _make_variant_json_options(options: Dictionary) -> Dictionary:
	return {
		"encode_dictionary_keys": _option_bool(options, "encode_dictionary_keys", false),
		"encode_unsafe_ints": true,
		"unsupported": "string",
		"circular_reference": _option_value(options, "circular_reference", "<circular_reference>"),
	}


static func _apply_final_byte_budget(value: Variant, options: Dictionary) -> Variant:
	var max_total_bytes: int = _option_int(options, "max_total_bytes", _DEFAULT_MAX_TOTAL_BYTES)
	if max_total_bytes < 0:
		return value
	var encoded_text: String = JSON.stringify(value)
	if encoded_text.to_utf8_buffer().size() <= max_total_bytes:
		return value
	return _make_final_byte_budget_value(max_total_bytes)


static func _make_final_byte_budget_value(max_total_bytes: int) -> Variant:
	var marker: Dictionary = _make_marker("ByteBudget", {
		"max_total_bytes": max_total_bytes,
	})
	if JSON.stringify(marker).to_utf8_buffer().size() <= max_total_bytes:
		return marker
	if JSON.stringify(_COMPACT_TRUNCATION_MARKER).to_utf8_buffer().size() <= max_total_bytes:
		return _COMPACT_TRUNCATION_MARKER
	if max_total_bytes >= 2:
		return ""
	return null


static func _make_circular_reference_value(options: Dictionary) -> Variant:
	return _make_json_typed_value(
		"CircularReference",
		_option_value(options, "circular_reference", "<circular_reference>")
	)


static func _sanitize_string_value(value: String, options: Dictionary) -> String:
	var max_length: int = _option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH)
	var bounded_value: String = value
	if max_length >= 0 and bounded_value.length() > max_length:
		bounded_value = "%s..." % bounded_value.substr(0, max_length)
	return _redact_path(bounded_value, options)


static func _sanitize_known_path_value(value: String, options: Dictionary) -> String:
	var max_length: int = _option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH)
	var bounded_value: String = value
	if max_length >= 0 and bounded_value.length() > max_length:
		bounded_value = "%s..." % bounded_value.substr(0, max_length)
	return _redact_path(bounded_value, options, true)


static func _redact_path(value: String, options: Dictionary, known_path: bool = false) -> String:
	var path_redaction: String = _option_string(options, "path_redaction", "redact")
	if path_redaction == "none" or (not known_path and not _looks_like_path(value)):
		return value
	if path_redaction == "basename":
		return value.get_file()
	if path_redaction == "hash":
		return value.sha256_text()
	return "<redacted_path>"


static func _looks_like_path(value: String) -> bool:
	var normalized: String = value.strip_edges()
	return (
		normalized.begins_with("res://")
		or normalized.begins_with("user://")
		or normalized.begins_with("uid://")
		or normalized.begins_with("/")
		or normalized.begins_with("\\\\")
		or normalized.contains(" /")
		or normalized.contains(" \\\\")
		or normalized.contains(":/")
		or normalized.contains(":\\")
	)


static func _get_collection_size(value: Variant) -> int:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.size()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.size()
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return len(value)
	return -1


static func _make_collection_sample(value: Variant, limit: int) -> Array:
	var result: Array = []
	if limit <= 0:
		return result
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary_value: Dictionary = value
		for key: Variant in dictionary_value:
			result.append({
				"key": key,
				"value": dictionary_value[key],
			})
			if result.size() >= limit:
				break
		return result
	for index: int in range(limit):
		result.append(value[index])
	return result


static func _collection_to_array(value: Variant) -> Array:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.duplicate(true)
		TYPE_PACKED_BYTE_ARRAY:
			var byte_array: PackedByteArray = value
			return _packed_byte_array_to_array(byte_array)
		TYPE_PACKED_INT32_ARRAY:
			var int_32_array: PackedInt32Array = value
			return Array(int_32_array)
		TYPE_PACKED_INT64_ARRAY:
			var int_64_array: PackedInt64Array = value
			return Array(int_64_array)
		TYPE_PACKED_FLOAT32_ARRAY:
			var float_32_array: PackedFloat32Array = value
			return Array(float_32_array)
		TYPE_PACKED_FLOAT64_ARRAY:
			var float_64_array: PackedFloat64Array = value
			return Array(float_64_array)
		TYPE_PACKED_STRING_ARRAY:
			var string_array: PackedStringArray = value
			return Array(string_array)
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector_2_array: PackedVector2Array = value
			return Array(vector_2_array)
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector_3_array: PackedVector3Array = value
			return Array(vector_3_array)
		TYPE_PACKED_COLOR_ARRAY:
			var color_array: PackedColorArray = value
			return Array(color_array)
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector_4_array: PackedVector4Array = value
			return Array(vector_4_array)
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var entries: Array = []
			for key: Variant in dictionary_value.keys():
				entries.append({
					"key": key,
					"value": dictionary_value[key],
				})
			return entries
		_:
			return []


static func _is_empty_collection(value: Variant) -> bool:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.is_empty()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.is_empty()
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return _collection_to_array(value).is_empty()
		_:
			return false


static func _has_reserved_variant_marker_shape(value: Dictionary) -> bool:
	if value.size() != 1 or not value.has(_VARIANT_MARKER_KEY):
		return false
	var marker: Dictionary = _as_dictionary(_option_value(value, _VARIANT_MARKER_KEY))
	return marker.has("type") and marker.has("value")


static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


static func _json_key_to_string(key: Variant) -> String:
	if key is StringName:
		var string_name_key: StringName = key
		return String(string_name_key)
	return str(key)


static func _is_unsafe_json_integer(value: int) -> bool:
	return value < _JSON_SAFE_INTEGER_MIN or value > _JSON_SAFE_INTEGER_MAX


static func _float_to_json_compatible(value: float) -> Variant:
	if is_nan(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_NAN_TEXT)
	if is_inf(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_POSITIVE_INF_TEXT if value > 0.0 else _FLOAT_NEGATIVE_INF_TEXT)
	return value


static func _float_array_to_json_compatible(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if value is float:
			var float_value: float = value
			result.append(_float_to_json_compatible(float_value))
		elif value is int:
			var int_value: int = value
			result.append(float(int_value))
		else:
			result.append(0.0)
	return result


static func _basis_to_array(value: Basis) -> Array:
	return [
		_float_array_to_json_compatible([value.x.x, value.x.y, value.x.z]),
		_float_array_to_json_compatible([value.y.x, value.y.y, value.y.z]),
		_float_array_to_json_compatible([value.z.x, value.z.y, value.z.z]),
	]


static func _transform_2d_to_array(value: Transform2D) -> Array:
	return [
		_float_array_to_json_compatible([value.x.x, value.x.y]),
		_float_array_to_json_compatible([value.y.x, value.y.y]),
		_float_array_to_json_compatible([value.origin.x, value.origin.y]),
	]


static func _packed_byte_array_to_array(value: PackedByteArray) -> Array:
	var result: Array = []
	for item: int in value:
		result.append(item)
	return result


static func _vector_2_array_to_array(value: PackedVector2Array) -> Array:
	var result: Array = []
	for item: Vector2 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y]))
	return result


static func _vector_3_array_to_array(value: PackedVector3Array) -> Array:
	var result: Array = []
	for item: Vector3 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y, item.z]))
	return result


static func _vector_4_array_to_array(value: PackedVector4Array) -> Array:
	var result: Array = []
	for item: Vector4 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y, item.z, item.w]))
	return result


static func _color_array_to_array(value: PackedColorArray) -> Array:
	var result: Array = []
	for item: Color in value:
		result.append(_float_array_to_json_compatible([item.r, item.g, item.b, item.a]))
	return result


static func _number_to_int(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


static func _duplicate_variant(value: Variant) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(value)


static func _as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value, default_value)


static func _option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, key, default_value)


static func _option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, key, default_value)


static func _option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, key, default_value)


static func _option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, key, default_value)


static func _normalize_options(options: Dictionary) -> Dictionary:
	var profile: String = _option_string(options, "redaction_profile", REDACTION_PROFILE_SUPPORT)
	var result: Dictionary = _get_profile_defaults(profile)
	for key: Variant in options.keys():
		result[key] = options[key]
	return result


static func _get_profile_defaults(profile: String) -> Dictionary:
	match profile:
		REDACTION_PROFILE_DEBUG:
			return {
				"redaction_profile": REDACTION_PROFILE_DEBUG,
				"path_redaction": "none",
				"include_node_name": true,
				"include_node_path": true,
				"include_object_instance_id": true,
				"include_resource_path": true,
			}
		REDACTION_PROFILE_PUBLIC:
			return {
				"redaction_profile": REDACTION_PROFILE_PUBLIC,
				"path_redaction": "redact",
				"include_node_name": false,
				"include_node_path": false,
				"include_object_instance_id": false,
				"include_resource_path": false,
			}
		REDACTION_PROFILE_PRIVACY:
			return {
				"redaction_profile": REDACTION_PROFILE_PRIVACY,
				"path_redaction": "redact",
				"include_node_name": false,
				"include_node_path": false,
				"include_object_instance_id": false,
				"include_resource_path": false,
			}
		_:
			return {
				"redaction_profile": REDACTION_PROFILE_SUPPORT,
				"path_redaction": "redact",
				"include_node_name": true,
				"include_node_path": false,
				"include_object_instance_id": true,
				"include_resource_path": true,
			}
