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
	assert_false(
		_option_string(summary, "encoded_preview_hash").is_empty(),
		"集合摘要应明确提供预算内编码预览 hash。"
	)
	assert_false(summary.has("hash"), "摘要不得把预算内预览误称为完整内容 hash。")
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


func test_dictionary_collection_limit_is_applied_before_key_materialization() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://addons/gf/kernel/core/gf_report_value_codec.gd"
	)
	var sanitizer_start: int = source.find("static func _sanitize_report_value(")
	var dictionary_start: int = source.find("\t\tTYPE_DICTIONARY:\n", sanitizer_start)
	var dictionary_end: int = source.find("\n\t\tTYPE_OBJECT:", dictionary_start)
	assert_true(sanitizer_start >= 0 and dictionary_start >= 0 and dictionary_end > dictionary_start)
	var dictionary_branch: String = source.substr(
		dictionary_start,
		dictionary_end - dictionary_start
	)

	assert_false(
		dictionary_branch.contains("dictionary_value.keys()"),
		"Dictionary 集合预算生效前不得通过 keys() 全量物化敌对输入。"
	)
	assert_false(
		dictionary_branch.contains("_uses_reserved_report_marker_key"),
		"保留 marker 检测必须合并进同一条有界迭代，不能先额外全表扫描。"
	)
	assert_false(
		source.contains("dictionary_value.keys()"),
		"Codec 内部 Dictionary 遍历不得额外物化完整 key Array。"
	)


func test_truncated_dictionary_samples_preserve_reserved_and_non_string_key_envelopes() -> void:
	var reserved_source: Dictionary = {
		"__gf_report_value__": { "type": "caller_data" },
		"omitted": 1,
	}
	var non_string_source: Dictionary = {
		7: "sampled",
		"omitted": 1,
	}
	var options: Dictionary = {
		"max_collection_items": 1,
		"max_total_nodes": 32,
		"max_total_bytes": 4096,
	}
	var reserved_encoded: Dictionary = _as_dictionary(
		GFReportValueCodec.to_json_compatible(reserved_source, options)
	)
	var non_string_encoded: Dictionary = _as_dictionary(
		GFReportValueCodec.to_json_compatible(non_string_source, options)
	)
	var reserved_marker: Dictionary = _as_dictionary(reserved_encoded["__gf_report_value__"])
	var non_string_marker: Dictionary = _as_dictionary(non_string_encoded["__gf_report_value__"])

	assert_eq(_as_string(reserved_marker["type"]), "CollectionBudget")
	assert_true(reserved_marker["sample"] is Array, "采样到保留 key 时必须使用 entries envelope。")
	assert_eq(_option_int(reserved_marker, "omitted_count"), 1)
	assert_eq(_as_string(non_string_marker["type"]), "CollectionBudget")
	assert_true(non_string_marker["sample"] is Array, "采样到非 String key 时必须使用 entries envelope。")
	assert_eq(_option_int(non_string_marker, "omitted_count"), 1)


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


func test_unknown_redaction_profile_falls_back_to_canonical_privacy() -> void:
	var options: Dictionary = GFReportValueCodec.make_redaction_options("publci", {
		"path_redaction": "none",
		"include_node_name": true,
	})
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"node": self,
		"path": "res://private/config.json",
	}, options))
	var node_marker: Dictionary = _as_dictionary(
		_as_dictionary(encoded["node"])["__gf_report_value__"]
	)
	var direct_encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"path": "res://private/direct.json",
	}, {
		"redaction_profile": "publci",
		"path_redaction": "none",
	}))

	assert_eq(
		_option_string(options, "redaction_profile"),
		GFReportValueCodec.REDACTION_PROFILE_PRIVACY,
		"未知 profile 必须规范化为实际生效的 privacy。"
	)
	assert_false(node_marker.has("node_name"), "未知 profile 不得保留 Node 名称。")
	assert_false(node_marker.has("instance_id"), "未知 profile 不得保留实例 id。")
	assert_eq(_as_string(encoded["path"]), "<redacted_path>", "未知 profile 不得接受放宽脱敏的 overrides。")
	assert_eq(
		_as_string(direct_encoded["path"]),
		"<redacted_path>",
		"直接传入未知 profile 也必须忽略放宽脱敏的字段。"
	)


func test_user_dictionary_cannot_spoof_report_marker() -> void:
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible({
		"__gf_report_value__": {
			"version": 1,
			"type": "ByteBudget",
			"redacted": true,
			"max_total_bytes": 123,
		},
	}))
	var outer_marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])

	assert_eq(_as_string(outer_marker["type"]), "Dictionary", "保留 marker key 的用户字典必须转义为 entries envelope。")
	assert_true(outer_marker.has("entries"), "转义 envelope 应保留用户数据 entries。")
	assert_ne(_option_int(outer_marker, "max_total_bytes", -1), 123, "用户数据不得伪造 ByteBudget 语义。")


func test_circular_replacement_cannot_inject_unsanitized_runtime_value() -> void:
	var circular: Array = []
	circular.append(circular)
	var encoded: Variant = GFReportValueCodec.to_json_compatible(circular, {
		"circular_reference": self,
	})
	var text: String = JSON.stringify(encoded)

	assert_true(text.contains("CircularReference"), "循环值应使用固定受限 marker。")
	assert_false(text.contains(String(name)), "自定义 circular replacement 不得注入 Node 字符串表示。")
	assert_false(text.contains("\"value\""), "循环 marker 不应携带调用方提供的任意 replacement。")


func test_unsupported_variant_uses_restricted_marker() -> void:
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(Projection()))
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])

	assert_eq(_as_string(marker["type"]), "UnsupportedVariant", "未知 Variant 不得调用 str()。")
	assert_eq(_as_string(marker["variant_type"]), "Projection", "受限 marker 只保留类型信息。")


func test_dictionary_packed_key_uses_sanitized_entry_encoding() -> void:
	var source: Dictionary = {
		PackedStringArray(["res://private/key.txt"]): "visible",
	}
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(source))
	var text: String = JSON.stringify(encoded)
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])

	assert_eq(_as_string(marker["type"]), "Dictionary", "非 String key 必须使用 entries 编码。")
	assert_false(text.contains("res://private/key.txt"), "Packed key 内的路径不得在第二阶段恢复为原始 key。")
	assert_true(text.contains("<redacted_path>"), "key 与 value 必须经过相同脱敏协议。")


func test_packed_int64_uses_safe_integer_markers_without_discarding_sanitized_items() -> void:
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(
		PackedInt64Array([9_007_199_254_740_993]),
		{
			"max_depth": 8,
			"max_total_nodes": 16,
			"max_total_bytes": 4096,
		}
	))
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])
	var items: Array = _as_array(marker["items"])
	var int_marker: Dictionary = _as_dictionary(
		_as_dictionary(items[0])["__gf_variant__"]
	)

	assert_eq(_as_string(marker["type"]), "PackedArray", "完整 PackedArray 应保留经脱敏的 items。")
	assert_eq(_as_string(marker["collection_type"]), "PackedInt64Array")
	assert_eq(_as_string(int_marker["type"]), "Int64", "不安全 int64 必须使用精确字符串 marker。")
	assert_eq(_as_string(int_marker["value"]), "9007199254740993")


func test_packed_array_honors_depth_budget_in_returned_items() -> void:
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(
		PackedVector3Array([Vector3.ONE]),
		{
			"max_depth": 0,
			"max_total_nodes": 16,
			"max_total_bytes": 4096,
		}
	))
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])
	var items: Array = _as_array(marker["items"])
	var depth_marker: Dictionary = _as_dictionary(
		_as_dictionary(items[0])["__gf_report_value__"]
	)

	assert_eq(_as_string(depth_marker["type"]), "MaxDepth", "PackedArray 不得丢弃深度检查后的 item。")


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
