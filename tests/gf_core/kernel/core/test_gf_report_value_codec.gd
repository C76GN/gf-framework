## 测试 GFReportValueCodec 的 kernel 层报告边界编码语义。
extends GutTest


# --- 测试用例 ---

func test_redacts_runtime_values_and_keeps_json_safe_numbers() -> void:
	var payload: Dictionary = {
		"owner": self,
		"value": NAN,
		"bytes": PackedByteArray([1, 2, 3]),
	}

	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(payload))
	var owner_marker: Dictionary = _as_dictionary(_as_dictionary(encoded["owner"])["__gf_report_value__"])
	var json_text: String = JSON.stringify(encoded)

	assert_eq(_as_string(owner_marker["type"]), "Object", "运行时对象应被结构化脱敏。")
	assert_true(_as_bool(owner_marker["redacted"]), "运行时对象 marker 应明确标记 redacted。")
	assert_true(json_text.contains("\"Float\""), "非有限 float 应继续使用 typed marker。")
	assert_false(json_text.contains(":null"), "报告编码不应把 NaN 直接交给 JSON.stringify 替换为 null。")


func test_redacts_paths_by_default() -> void:
	var payload: Dictionary = {
		"path": "res://secret/config.json",
	}

	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(payload))
	var unredacted: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(payload, {
		"path_redaction": "none",
	}))

	assert_eq(_as_string(encoded["path"]), "<redacted_path>", "报告导出默认不应暴露资源路径。")
	assert_eq(_as_string(unredacted["path"]), "res://secret/config.json", "开发态可显式保留完整路径。")


func test_uses_explicit_redaction_profiles() -> void:
	var support_encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"node": self,
	}))
	var debug_encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"node": self,
	}, GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG)))
	var public_encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"node": self,
	}, GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_PUBLIC)))
	var support_marker: Dictionary = _as_dictionary(_as_dictionary(support_encoded["node"])["__gf_report_value__"])
	var debug_marker: Dictionary = _as_dictionary(_as_dictionary(debug_encoded["node"])["__gf_report_value__"])
	var public_marker: Dictionary = _as_dictionary(_as_dictionary(public_encoded["node"])["__gf_report_value__"])

	assert_true(support_marker.has("node_name"), "support profile 应保留节点名用于排障。")
	assert_false(support_marker.has("node_path"), "support profile 默认不暴露节点路径。")
	assert_true(debug_marker.has("node_path"), "debug profile 应允许本地调试路径。")
	assert_false(public_marker.has("node_name"), "public profile 不应暴露节点名。")
	assert_false(public_marker.has("instance_id"), "public profile 不应暴露运行时实例 id。")


func test_summarizes_large_collections() -> void:
	var values: Array = []
	for index: int in range(20):
		values.append(Vector2i(index, index + 1))

	var summary: Dictionary = GFReportValueCodec.make_collection_summary(values, {
		"sample_count": 3,
		"encode_dictionary_keys": true,
	})
	var sample: Array = _as_array(summary["sample"])

	assert_true(_option_bool(summary, "ok"), "集合摘要应成功。")
	assert_eq(_option_int(summary, "count"), 20, "集合摘要应保留总数。")
	assert_eq(sample.size(), 3, "集合摘要应按 sample_count 截断样本。")
	assert_true(_option_bool(summary, "truncated"), "集合摘要应说明截断。")
	assert_false(_option_string(summary, "hash").is_empty(), "集合摘要应包含完整内容 hash。")
	assert_false(JSON.stringify(summary).contains(":null"), "集合摘要不应触发 JSON 非有限值替换。")


func test_report_codec_applies_optional_collection_and_node_budgets() -> void:
	var dictionary: Dictionary = {}
	var array: Array[int] = []
	var packed: PackedInt32Array = PackedInt32Array()
	for index: int in range(20):
		dictionary["key_%d" % index] = index
		array.append(index)
		var _packed_appended: bool = packed.append(index)
	var budget_options: Dictionary = {
		"max_collection_items": 2,
		"max_total_nodes": 32,
	}
	var encoded_array: Array = _as_array(GFReportValueCodec.to_json_compatible(array, budget_options))
	var encoded_dictionary: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(dictionary, budget_options))
	var encoded_packed: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(packed, budget_options))
	var dictionary_marker: Dictionary = _as_dictionary(encoded_dictionary["__gf_report_value__"])
	var packed_marker: Dictionary = _as_dictionary(encoded_packed["__gf_report_value__"])

	assert_eq(encoded_array.size(), 3, "Array 预算应保留样本和截断 marker。")
	assert_eq(_as_string(dictionary_marker["type"]), "CollectionBudget", "宽 Dictionary 应编码为集合预算 marker。")
	assert_eq(_option_int(dictionary_marker, "count"), 20, "Dictionary marker 应保留原始计数。")
	assert_eq(_as_string(packed_marker["type"]), "CollectionBudget", "宽 PackedArray 应编码为集合预算 marker。")
	assert_eq(_option_int(packed_marker, "count"), 20, "PackedArray marker 应保留原始计数。")
	assert_false(JSON.stringify([encoded_array, encoded_dictionary, encoded_packed]).contains(":null"), "预算 marker 应保持 JSON-safe。")


func test_report_codec_stops_remaining_array_traversal_after_node_budget() -> void:
	var values: Array[int] = []
	for index: int in range(100):
		values.append(index)

	var encoded: Array = _as_array(GFReportValueCodec.to_json_compatible(values, {
		"max_collection_items": 100,
		"max_total_nodes": 3,
		"max_total_bytes": 4096,
	}))
	var marker: Dictionary = _as_dictionary(_as_dictionary(encoded.back())["__gf_report_value__"])

	assert_eq(encoded.size(), 3, "node budget 耗尽后不得继续访问剩余 Array 条目。")
	assert_eq(_as_string(marker["type"]), "NodeBudget", "最后一个输出必须是稳定 NodeBudget marker。")
	assert_eq(_option_int(marker, "node_count"), 3, "marker 应报告预算耗尽时的节点计数。")


func test_report_codec_enforces_packed_length_independently() -> void:
	var values: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(values, {
		"max_collection_items": 100,
		"max_packed_length": 2,
		"max_total_nodes": 100,
		"max_total_bytes": 4096,
	}))
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])

	assert_eq(_as_string(marker["type"]), "CollectionBudget", "PackedArray 应由独立 max_packed_length 截断。")
	assert_eq(_option_int(marker, "omitted_count"), 2, "PackedArray marker 应报告未遍历条目数。")


func test_report_codec_caps_final_json_bytes_with_stable_marker() -> void:
	var encoded: Variant = GFReportValueCodec.to_json_compatible([
		"first payload value",
		"second payload value",
		"third payload value",
	], {
		"max_collection_items": 10,
		"max_total_nodes": 100,
		"max_total_bytes": 60,
	})
	var text: String = JSON.stringify(encoded)

	assert_true(text.to_utf8_buffer().size() <= 60, "最终紧凑 JSON 不得突破 max_total_bytes。")
	assert_true(text.contains("ByteBudget") or text.contains("<gf_truncated>"), "字节预算截断必须输出稳定 marker。")


func test_privacy_profile_redacts_known_node_path_and_posix_unc_paths() -> void:
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"node_path": NodePath("Root/PrivateNode"),
		"posix": "/home/private/project/config.json",
		"unc": "\\\\server\\private\\config.json",
	}, GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_PRIVACY)))

	assert_eq(_as_string(encoded["node_path"]), "<redacted_path>", "NodePath 是已知路径类型，不得依赖字符串启发式。")
	assert_eq(_as_string(encoded["posix"]), "<redacted_path>", "POSIX 绝对路径应被识别并脱敏。")
	assert_eq(_as_string(encoded["unc"]), "<redacted_path>", "UNC 路径应被识别并脱敏。")


# --- 私有/辅助方法 ---

func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		var array: Array = value
		return array
	return []


func _as_bool(value: Variant) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false


func _as_string(value: Variant) -> String:
	return str(value)


func _option_bool(options: Dictionary, key: String, default_value: bool = false) -> bool:
	if options.has(key) and options[key] is bool:
		var bool_value: bool = options[key]
		return bool_value
	return default_value


func _option_int(options: Dictionary, key: String, default_value: int = 0) -> int:
	if options.has(key) and options[key] is int:
		var int_value: int = options[key]
		return int_value
	return default_value


func _option_string(options: Dictionary, key: String, default_value: String = "") -> String:
	if options.has(key):
		return str(options[key])
	return default_value
