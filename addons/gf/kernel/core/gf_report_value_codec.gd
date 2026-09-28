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



# --- 常量 ---

## 复用 Variant 字典访问与安全复制入口，统一报告选项的类型转换规则。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 报告脱敏或截断值使用的保留包装键，源字典含该键时改用条目编码避免混淆。
## [br]
## @api private
const _REPORT_MARKER_KEY: String = "__gf_report_value__"

## 报告脱敏 marker 的结构版本，写入每个报告包装值。
## [br]
## @api private
const _REPORT_SCHEMA_VERSION: int = 1

## Godot 特有类型的 JSON 包装键，编码时避免普通源字典冒充该结构。
## [br]
## @api private
const _VARIANT_MARKER_KEY: String = "__gf_variant__"

## Godot Variant 类型包装格式的版本，随类型和值一同输出。
## [br]
## @api private
const _VARIANT_SCHEMA_VERSION: int = 1

## JSON 双精度数字能精确表示的最大连续整数，超过时编码为 Int64 文本。
## [br]
## @api private
const _JSON_SAFE_INTEGER_MAX: int = 9_007_199_254_740_991

## JSON 双精度数字能精确表示的最小连续整数，低于时编码为 Int64 文本。
## [br]
## @api private
const _JSON_SAFE_INTEGER_MIN: int = -9_007_199_254_740_991

## 非有限浮点在 Variant marker 中使用的类型名。
## [br]
## @api private
const _FLOAT_TYPE_NAME: String = "Float"

## 非数浮点的稳定文本表示，避免直接传给 JSON 数字编码。
## [br]
## @api private
const _FLOAT_NAN_TEXT: String = "NaN"

## 正无穷浮点的稳定文本表示，配合 Float marker 输出。
## [br]
## @api private
const _FLOAT_POSITIVE_INF_TEXT: String = "INF"

## 负无穷浮点的稳定文本表示，配合 Float marker 输出。
## [br]
## @api private
const _FLOAT_NEGATIVE_INF_TEXT: String = "-INF"

## 未提供选项时允许的报告递归深度，根位于零层。
## [br]
## @api private
const _DEFAULT_MAX_DEPTH: int = 32

## 报告字符串默认保留的字符数上限，截断后另附省略号。
## [br]
## @api private
const _DEFAULT_MAX_STRING_LENGTH: int = 8192

## 集合摘要默认抽取的前部样本数，与完整集合内容摘要无等价保证。
## [br]
## @api private
const _DEFAULT_SUMMARY_SAMPLE_COUNT: int = 16

## 单个普通集合默认允许遍历的条目数，超出部分用截断 marker 表达。
## [br]
## @api private
const _DEFAULT_MAX_COLLECTION_ITEMS: int = 1024

## Packed Array 的默认长度限制，同时受普通集合项数限制约束。
## [br]
## @api private
const _DEFAULT_MAX_PACKED_LENGTH: int = 4096

## 一次报告清洗默认允许访问的节点总数，耗尽后停止继续遍历。
## [br]
## @api private
const _DEFAULT_MAX_TOTAL_NODES: int = 16384

## 报告清洗工作量及最终紧凑编码的默认字节预算。
## [br]
## @api private
const _DEFAULT_MAX_TOTAL_BYTES: int = 1024 * 1024

## 完整字节预算 marker 放不下时使用的短文本占位，仍须通过最终字节检查。
## [br]
## @api private
const _COMPACT_TRUNCATION_MARKER: String = "<gf_truncated>"



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
## 未知 profile 会 fail-closed 到 REDACTION_PROFILE_PRIVACY，且忽略 overrides，
## 防止拼写错误扩大报告暴露面。
## [br]
## @param profile: REDACTION_PROFILE_* 常量之一。
## [br]
## @param overrides: 覆盖默认 profile 的选项。
## [br]
## @return 编码选项字典；redaction_profile 始终是实际生效的规范 profile。
## [br]
## @schema overrides: Dictionary，可覆盖 path_redaction、include_node_name、include_node_path、include_object_instance_id、include_resource_path、max_depth、max_string_length、max_collection_items、max_packed_length、max_total_nodes 和 max_total_bytes；不能改写 profile 身份。
## [br]
## @schema return: Dictionary，可直接传给 GFReportValueCodec 的编码选项。
static func make_redaction_options(profile: String, overrides: Dictionary = {}) -> Dictionary:
	if not _is_supported_redaction_profile(profile):
		return _get_profile_defaults(REDACTION_PROFILE_PRIVACY)
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
## @param options: 可选项；支持 redaction_profile、include_resource_path、include_node_name、include_node_path、include_object_instance_id、max_depth、max_string_length、max_collection_items、max_packed_length、max_total_nodes、max_total_bytes 和 path_redaction；路径默认脱敏，所有非负预算均为遍历工作量与输出硬上限。循环引用始终使用固定受限 marker，不接受自定义 replacement。
## [br]
## @return JSON 兼容值；不支持的运行时类型会写入脱敏 marker。
## [br]
## @schema value: Variant report value to encode.
## [br]
## @schema options: Dictionary with redaction_profile, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options; path_redaction defaults to redacted and non-negative budgets stop traversal immediately when exhausted.
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
## @schema options: Dictionary with redaction_profile, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options.
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
## @schema options: Dictionary with redaction_profile, include_resource_path, include_node_name, include_node_path, include_object_instance_id, max_depth, max_string_length, max_collection_items, max_packed_length, max_total_nodes, max_total_bytes, path_redaction, and encode_dictionary_keys options.
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
## `encoded_preview_hash` 只指纹化经过预算限制的编码预览，不代表完整集合内容 hash。
## [br]
## @schema return: Dictionary with ok, collection_type, count, sample, truncated, and encoded_preview_hash.
static func make_collection_summary(value: Variant, options: Dictionary = {}) -> Dictionary:
	var collection_size: int = _get_collection_size(value)
	if collection_size < 0:
		return {
			"ok": false,
			"collection_type": type_string(typeof(value)),
			"count": 0,
			"sample": [],
			"truncated": false,
			"encoded_preview_hash": "",
		}

	var effective_options: Dictionary = _normalize_options(options)
	var sample_count: int = maxi(_option_int(effective_options, "sample_count", _DEFAULT_SUMMARY_SAMPLE_COUNT), 0)
	var sample: Array = _make_collection_sample(value, mini(sample_count, collection_size))
	var encoded_preview_text: String = stringify_json_compatible(value, "", true, effective_options)
	return {
		"ok": true,
		"collection_type": type_string(typeof(value)),
		"count": collection_size,
		"sample": to_json_compatible(sample, effective_options),
		"truncated": collection_size > sample.size(),
		"encoded_preview_hash": encoded_preview_text.sha256_text(),
	}


# --- 私有/辅助方法 ---

## 先消耗深度、节点和工作字节预算，再递归清洗值；对象句柄脱敏、循环及截断使用 marker，字典键冲突风险转为条目列表。
## [br]
## @api private
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
				return _make_marker("CircularReference", {})
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
				return _make_marker("CircularReference", {})
			visited.append(value)
			var dictionary_value: Dictionary = value
			var dictionary_result: Dictionary = {}
			var encoded_entries: Array[Dictionary] = []
			var requires_entry_encoding: bool = false
			var dictionary_size: int = dictionary_value.size()
			var dictionary_limit: int = _get_collection_limit(dictionary_size, options)
			if dictionary_limit > 0:
				var encoded_entry_count: int = 0
				for key: Variant in dictionary_value:
					if key is String or key is StringName:
						if str(key) == _REPORT_MARKER_KEY:
							requires_entry_encoding = true
					var sanitized_key: Variant = _sanitize_report_value(
						key,
						options,
						visited,
						depth + 1,
						budget_state
					)
					if _is_budget_exhausted(budget_state):
						break
					var sanitized_value: Variant = _sanitize_report_value(
						dictionary_value[key],
						options,
						visited,
						depth + 1,
						budget_state
					)
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
					encoded_entry_count += 1
					if encoded_entry_count >= dictionary_limit:
						break
			var _removed_dictionary_reference: Variant = visited.pop_back()
			if _is_budget_exhausted(budget_state):
				return _make_budget_exhaustion_marker(budget_state, options)
			if dictionary_size > dictionary_limit:
				_mark_budget_truncated(budget_state)
				var collection_sample: Variant = dictionary_result
				if requires_entry_encoding:
					collection_sample = encoded_entries
				return _make_marker("CollectionBudget", {
					"collection_type": "Dictionary",
					"count": dictionary_size,
					"omitted_count": dictionary_size - dictionary_limit,
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


## 读取集合项数上限；负值表示不限制，非负值不超过集合长度。
## [br]
## @api private
static func _get_collection_limit(collection_size: int, options: Dictionary) -> int:
	var max_collection_items: int = _option_int(
		options,
		"max_collection_items",
		_DEFAULT_MAX_COLLECTION_ITEMS
	)
	if max_collection_items < 0:
		return collection_size
	return mini(collection_size, max_collection_items)


## 合并普通集合项数与 Packed Array 长度上限。
## [br]
## @api private
static func _get_packed_limit(collection_size: int, options: Dictionary) -> int:
	var collection_limit: int = _get_collection_limit(collection_size, options)
	var max_packed_length: int = _option_int(options, "max_packed_length", _DEFAULT_MAX_PACKED_LENGTH)
	if max_packed_length < 0:
		return collection_limit
	return mini(collection_limit, max_packed_length)


## 将 budget_state 中的截断计数增加一。
## [br]
## @api private
static func _mark_budget_truncated(budget_state: Dictionary) -> void:
	budget_state["truncated_count"] = _option_int(budget_state, "truncated_count", 0) + 1


## 从状态字典读取 exhausted 标志，缺失或非真值时返回 false。
## [br]
## @api private
static func _is_budget_exhausted(budget_state: Dictionary) -> bool:
	return _option_bool(budget_state, "exhausted", false)


## 首次耗尽时保存原因并增加截断计数；已有耗尽状态保持不变。
## [br]
## @api private
static func _exhaust_budget(budget_state: Dictionary, reason: String) -> void:
	if _is_budget_exhausted(budget_state):
		return
	budget_state["exhausted"] = true
	budget_state["reason"] = reason
	_mark_budget_truncated(budget_state)


## 按保存的耗尽原因生成 marker，并附带节点或字节限制信息。
## [br]
## @api private
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


## 先用最小开销快速拒绝，再对文本计入实际 UTF-8 字节与引号开销；其他类型采用估算工作量，最终输出大小由后续独立检查限制。
## [br]
## @api private
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


## 给遍历前的预算预检提供类型成本：文本字符数加引号、集合括号或固定类型开销；该估算不是完整 JSON 输出长度。
## [br]
## @api private
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


## 判断 Variant 类型是否属于此 codec 支持的 Packed Array。
## [br]
## @api private
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


## 按 Packed 与集合预算较小值清洗样本；完整样本包装为 PackedArray，局部样本为 CollectionBudget，总预算耗尽则返回耗尽 marker。
## [br]
## @api private
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
		return _make_marker("PackedArray", {
			"collection_type": type_string(typeof(value)),
			"count": item_count,
			"items": sample,
		})
	_mark_budget_truncated(budget_state)
	return _make_marker("CollectionBudget", {
		"collection_type": type_string(typeof(value)),
		"count": item_count,
		"omitted_count": item_count - item_limit,
		"sample": sample,
	})


## 非 String 键或清理后发生变化的键需要改用键值 entry 表示。
## [br]
## @api private
static func _report_key_requires_entry_encoding(source_key: Variant, sanitized_key: Variant) -> bool:
	if not (source_key is String) or not (sanitized_key is String):
		return true
	var source_text: String = source_key
	var sanitized_text: String = sanitized_key
	return source_text != sanitized_text


## 将存活对象缩减为类型与选项允许的 ID、节点名或脱敏路径；无效对象只保留 valid=false，不把对象引用带入报告。
## [br]
## @api private
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


## 将已清洗值编码为 JSON 基础值及带类型 marker，递归容器时检测当前引用路径的循环；预算裁剪应在前一清洗阶段完成。
## [br]
## @api private
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
				return _make_circular_reference_value()
			visited.append(value)
			var array_value: Array = value
			var result_array: Array = []
			for item: Variant in array_value:
				result_array.append(_variant_to_json_compatible(item, options, visited))
			var _removed_array_reference: Variant = visited.pop_back()
			return result_array
		TYPE_DICTIONARY:
			if _visited_contains_reference(visited, value):
				return _make_circular_reference_value()
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
			return _make_json_typed_value(
				"PackedInt64Array",
				_int_array_to_json_compatible(Array(int_64_array))
			)
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
			return _make_marker("UnsupportedVariant", {
				"variant_type": type_string(typeof(value)),
				"variant_type_id": typeof(value),
			})


## 通常将字典键转为文本；键碰撞、保留类型 marker 外形或显式键编码要求会改用类型化条目列表，避免丢失原键身份。
## [br]
## @api private
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


## 按源键顺序递归编码键值对为 entries 数组，保留无法用 JSON 对象键表达的键类型。
## [br]
## @api private
static func _dictionary_entries_to_json_compatible(value: Dictionary, options: Dictionary, visited: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key: Variant in value.keys():
		entries.append({
			"key": _dictionary_key_to_json_compatible(key, options, visited),
			"value": _variant_to_json_compatible(value[key], options, visited),
		})
	return entries


## 整数键一律以 Int64 文本 marker 编码，其余键沿用 Variant 编码，避免键在 JSON 数字处理时失真。
## [br]
## @api private
static func _dictionary_key_to_json_compatible(key: Variant, options: Dictionary, visited: Array) -> Variant:
	if typeof(key) == TYPE_INT:
		return _make_json_typed_value("Int64", str(_number_to_int(key)))
	return _variant_to_json_compatible(key, options, visited)


## 创建带版本、类型和 redacted 标志的报告 marker，并复制载荷到内部字典；同名载荷键会覆盖初始元数据。
## [br]
## @api private
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


## 将类型名和值包装为带 schema 版本的 Variant marker。
## [br]
## @api private
static func _make_json_typed_value(type_name: String, typed_value: Variant) -> Dictionary:
	return {
		_VARIANT_MARKER_KEY: {
			"version": _VARIANT_SCHEMA_VERSION,
			"type": type_name,
			"value": typed_value,
		},
	}


## 为 Variant 编码阶段保留字典键选项并强制编码不安全整数。
## [br]
## @api private
static func _make_variant_json_options(options: Dictionary) -> Dictionary:
	return {
		"encode_dictionary_keys": _option_bool(options, "encode_dictionary_keys", false),
		"encode_unsafe_ints": true,
	}


## 检查编码结果的 UTF-8 字节数，超限时改用最终预算 marker。
## [br]
## @api private
static func _apply_final_byte_budget(value: Variant, options: Dictionary) -> Variant:
	var max_total_bytes: int = _option_int(options, "max_total_bytes", _DEFAULT_MAX_TOTAL_BYTES)
	if max_total_bytes < 0:
		return value
	var encoded_text: String = JSON.stringify(value)
	if encoded_text.to_utf8_buffer().size() <= max_total_bytes:
		return value
	return _make_final_byte_budget_value(max_total_bytes)


## 依次尝试预算 marker、紧凑截断文本、空字符串；预算不足两字节时返回 null。
## [br]
## @api private
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


## 创建循环引用的报告 marker。
## [br]
## @api private
static func _make_circular_reference_value() -> Variant:
	return _make_marker("CircularReference", {})


## 按长度上限截断普通字符串，再应用路径脱敏选项。
## [br]
## @api private
static func _sanitize_string_value(value: String, options: Dictionary) -> String:
	var max_length: int = _option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH)
	var bounded_value: String = value
	if max_length >= 0 and bounded_value.length() > max_length:
		bounded_value = "%s..." % bounded_value.substr(0, max_length)
	return _redact_path(bounded_value, options)


## 按长度上限截断已知路径，再强制按路径规则处理。
## [br]
## @api private
static func _sanitize_known_path_value(value: String, options: Dictionary) -> String:
	var max_length: int = _option_int(options, "max_string_length", _DEFAULT_MAX_STRING_LENGTH)
	var bounded_value: String = value
	if max_length >= 0 and bounded_value.length() > max_length:
		bounded_value = "%s..." % bounded_value.substr(0, max_length)
	return _redact_path(bounded_value, options, true)


## 依据选项保留、取文件名、哈希或隐藏路径；普通文本仅在启发式识别为路径时处理，已知路径可强制进入脱敏。
## [br]
## @api private
static func _redact_path(value: String, options: Dictionary, known_path: bool = false) -> String:
	var path_redaction: String = _option_string(options, "path_redaction", "redact")
	if path_redaction == "none" or (not known_path and not _looks_like_path(value)):
		return value
	if path_redaction == "basename":
		return value.get_file()
	if path_redaction == "hash":
		return value.sha256_text()
	return "<redacted_path>"


## 用资源 URI、绝对路径及路径分隔符特征识别可能的路径文本。
## [br]
## @api private
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


## 返回受支持集合的元素数；其他 Variant 类型返回 -1。
## [br]
## @api private
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


## 按原遍历顺序取前部样本，字典转换为键值条目；样本本身未脱敏且数组索引额度须由调用方按集合长度限制。
## [br]
## @api private
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


## 把支持的集合转为普通数组，Array 深复制、字典输出键值条目、Packed Array 按元素复制；不支持的类型返回空数组。
## [br]
## @api private
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
			for key: Variant in dictionary_value:
				entries.append({
					"key": key,
					"value": dictionary_value[key],
				})
			return entries
		_:
			return []


## 判断 Array、Dictionary 或受支持 Packed Array 是否为空。
## [br]
## @api private
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


## 检查字典是否仅含保留 Variant marker 键且其值含 type/value。
## [br]
## @api private
static func _has_reserved_variant_marker_shape(value: Dictionary) -> bool:
	if value.size() != 1 or not value.has(_VARIANT_MARKER_KEY):
		return false
	var marker: Dictionary = _as_dictionary(_option_value(value, _VARIANT_MARKER_KEY))
	return marker.has("type") and marker.has("value")


## 按引用身份查找当前递归路径中的集合，不把内容相等但独立的集合误判为循环。
## [br]
## @api private
static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


## 将 StringName 转为 String，其他字典键使用 str()。
## [br]
## @api private
static func _json_key_to_string(key: Variant) -> String:
	if key is StringName:
		var string_name_key: StringName = key
		return String(string_name_key)
	return str(key)


## 判断整数是否超出可由 JSON 数字精确保留的范围。
## [br]
## @api private
static func _is_unsafe_json_integer(value: int) -> bool:
	return value < _JSON_SAFE_INTEGER_MIN or value > _JSON_SAFE_INTEGER_MAX


## 将有限浮点原样返回，并把 NaN 与正负无穷转成类型 marker。
## [br]
## @api private
static func _float_to_json_compatible(value: float) -> Variant:
	if is_nan(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_NAN_TEXT)
	if is_inf(value):
		return _make_json_typed_value(_FLOAT_TYPE_NAME, _FLOAT_POSITIVE_INF_TEXT if value > 0.0 else _FLOAT_NEGATIVE_INF_TEXT)
	return value


## 将数组中的 float/int 转为 JSON 浮点值，其他项写为 0.0。
## [br]
## @api private
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


## 将数组项转为整数，并为超出 JSON 安全范围的值生成 Int64 marker。
## [br]
## @api private
static func _int_array_to_json_compatible(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		var int_value: int = _number_to_int(value)
		if _is_unsafe_json_integer(int_value):
			result.append(_make_json_typed_value("Int64", str(int_value)))
		else:
			result.append(int_value)
	return result


## 按 x、y、z 基向量顺序将 Basis 转成三行浮点数组。
## [br]
## @api private
static func _basis_to_array(value: Basis) -> Array:
	return [
		_float_array_to_json_compatible([value.x.x, value.x.y, value.x.z]),
		_float_array_to_json_compatible([value.y.x, value.y.y, value.y.z]),
		_float_array_to_json_compatible([value.z.x, value.z.y, value.z.z]),
	]


## 按 x、y、origin 顺序将 Transform2D 转成三行浮点数组。
## [br]
## @api private
static func _transform_2d_to_array(value: Transform2D) -> Array:
	return [
		_float_array_to_json_compatible([value.x.x, value.x.y]),
		_float_array_to_json_compatible([value.y.x, value.y.y]),
		_float_array_to_json_compatible([value.origin.x, value.origin.y]),
	]


## 将 PackedByteArray 的每个字节依序复制到普通 Array。
## [br]
## @api private
static func _packed_byte_array_to_array(value: PackedByteArray) -> Array:
	var result: Array = []
	for item: int in value:
		result.append(item)
	return result


## 将 PackedVector2Array 转为每项含 x、y 的浮点数组。
## [br]
## @api private
static func _vector_2_array_to_array(value: PackedVector2Array) -> Array:
	var result: Array = []
	for item: Vector2 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y]))
	return result


## 将 PackedVector3Array 转为每项含 x、y、z 的浮点数组。
## [br]
## @api private
static func _vector_3_array_to_array(value: PackedVector3Array) -> Array:
	var result: Array = []
	for item: Vector3 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y, item.z]))
	return result


## 将 PackedVector4Array 转为每项含 x、y、z、w 的浮点数组。
## [br]
## @api private
static func _vector_4_array_to_array(value: PackedVector4Array) -> Array:
	var result: Array = []
	for item: Vector4 in value:
		result.append(_float_array_to_json_compatible([item.x, item.y, item.z, item.w]))
	return result


## 将 PackedColorArray 转为每项含 r、g、b、a 的浮点数组。
## [br]
## @api private
static func _color_array_to_array(value: PackedColorArray) -> Array:
	var result: Array = []
	for item: Color in value:
		result.append(_float_array_to_json_compatible([item.r, item.g, item.b, item.a]))
	return result


## 保留整数或将浮点截为整数，其他类型归零；调用点负责确保浮点范围适合转换。
## [br]
## @api private
static func _number_to_int(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


## 将 Variant 复制请求转发给共享访问辅助脚本。
## [br]
## @api private
static func _duplicate_variant(value: Variant) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(value)


## 将 Variant 按共享辅助脚本的规则收窄为 Dictionary。
## [br]
## @api private
static func _as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value, default_value)


## 读取任意类型的选项值并传入默认值。
## [br]
## @api private
static func _option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, key, default_value)


## 读取布尔选项并传入默认值。
## [br]
## @api private
static func _option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, key, default_value)


## 读取整数选项并传入默认值。
## [br]
## @api private
static func _option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, key, default_value)


## 读取字符串选项并传入默认值。
## [br]
## @api private
static func _option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, key, default_value)


## 合并有效 profile 的默认值与传入选项；未知 profile 直接采用 privacy 默认值。
## [br]
## @api private
static func _normalize_options(options: Dictionary) -> Dictionary:
	var profile: String = _option_string(options, "redaction_profile", REDACTION_PROFILE_SUPPORT)
	if not _is_supported_redaction_profile(profile):
		return _get_profile_defaults(REDACTION_PROFILE_PRIVACY)
	var result: Dictionary = _get_profile_defaults(profile)
	for key: Variant in options.keys():
		result[key] = options[key]
	return result


## 返回指定内置脱敏 profile 的路径、Node、Object 与 Resource 默认选项。
## [br]
## @api private
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
		REDACTION_PROFILE_SUPPORT:
			return {
				"redaction_profile": REDACTION_PROFILE_SUPPORT,
				"path_redaction": "redact",
				"include_node_name": true,
				"include_node_path": false,
				"include_object_instance_id": true,
				"include_resource_path": true,
			}
		_:
			return {
				"redaction_profile": REDACTION_PROFILE_PRIVACY,
				"path_redaction": "redact",
				"include_node_name": false,
				"include_node_path": false,
				"include_object_instance_id": false,
				"include_resource_path": false,
			}


## 检查 profile 是否属于四个内置脱敏配置。
## [br]
## @api private
static func _is_supported_redaction_profile(profile: String) -> bool:
	return profile in [
		REDACTION_PROFILE_DEBUG,
		REDACTION_PROFILE_SUPPORT,
		REDACTION_PROFILE_PUBLIC,
		REDACTION_PROFILE_PRIVACY,
	]
