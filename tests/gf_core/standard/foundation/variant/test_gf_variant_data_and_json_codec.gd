## 测试 GFVariantData 与 GFVariantJsonCodec 的通用 Variant 行为。
extends GutTest


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


func test_duplicate_variant_deep_copies_collections() -> void:
	var source: Dictionary = {
		"items": [
			{ "value": 1 },
		],
	}
	var copy: Dictionary = _as_dictionary(GFVariantData.duplicate_variant(source))
	var copy_items: Array = _as_array(copy["items"])
	var copied_item: Dictionary = _as_dictionary(copy_items[0])
	copied_item["value"] = 2

	var source_items: Array = _as_array(source["items"])
	var source_item: Dictionary = _as_dictionary(source_items[0])
	assert_eq(_as_int(source_item["value"]), 1, "深拷贝不应共享嵌套集合。")


func test_duplicate_variant_preserves_recursive_dictionary_identity() -> void:
	var source: Dictionary = {
		"value": 1,
	}
	source["self"] = source

	var copy: Dictionary = _as_dictionary(GFVariantData.duplicate_variant(source))

	assert_false(is_same(copy, source), "循环字典应返回可独立修改的副本。")
	assert_true(is_same(copy["self"], copy), "循环字典副本应保留内部 self 引用。")


func test_duplicate_variant_can_optionally_duplicate_resources() -> void:
	var resource: Resource = Resource.new()

	assert_same(_as_resource(GFVariantData.duplicate_variant(resource)), resource, "默认应保留 Resource 引用。")
	assert_ne(_as_resource(GFVariantData.duplicate_variant(resource, true, true)), resource, "显式要求时应复制 Resource。")


func test_duplicate_variant_preserves_shared_resource_topology() -> void:
	var shared_resource: Resource = Resource.new()
	var source: Array = [shared_resource, shared_resource]

	var copy: Array = _as_array(GFVariantData.duplicate_variant(source, true, true))
	var first_copy: Resource = _as_resource(copy[0])
	var second_copy: Resource = _as_resource(copy[1])

	assert_not_same(first_copy, shared_resource, "显式复制 Resource 时必须断开源引用。")
	assert_same(first_copy, second_copy, "同一源 Resource 在复制图中必须映射到同一副本。")


func test_duplicate_variant_deep_copies_all_packed_array_types() -> void:
	var packed_values: Array = [
		PackedByteArray([1]),
		PackedInt32Array([1]),
		PackedInt64Array([1]),
		PackedFloat32Array([1.0]),
		PackedFloat64Array([1.0]),
		PackedStringArray(["source"]),
		PackedVector2Array([Vector2.ONE]),
		PackedVector3Array([Vector3.ONE]),
		PackedVector4Array([Vector4.ONE]),
		PackedColorArray([Color.WHITE]),
	]

	for source_value: Variant in packed_values:
		var copied_value: Variant = GFVariantData.duplicate_variant(source_value)
		var mutated_copy: Variant = _replace_first_packed_value(copied_value)

		assert_eq(typeof(copied_value), typeof(source_value), "深复制必须保留具体 PackedArray 类型。")
		assert_false(_packed_values_equal(mutated_copy, source_value), "修改 PackedArray 副本不得污染源值。")


func test_deep_merge_defaults_keeps_existing_values() -> void:
	var base: Dictionary = {
		"audio": {
			"volume": 0.5,
		},
	}
	var defaults: Dictionary = {
		"audio": {
			"volume": 1.0,
			"mute": false,
		},
		"language": "zh",
	}

	var merged: Dictionary = GFVariantData.deep_merge_defaults(base, defaults)
	var audio: Dictionary = _as_dictionary(base["audio"])

	assert_same(merged, base, "默认值合并应原地返回 base。")
	assert_eq(_as_float(audio["volume"]), 0.5, "已有字段不应被覆盖。")
	assert_false(_as_bool(audio["mute"]), "缺失嵌套字段应被补齐。")
	assert_eq(_as_string(base["language"]), "zh", "顶层缺失字段应被补齐。")


func test_to_dictionary_and_duplicate_metadata_return_copies() -> void:
	var source: Dictionary = {
		"nested": {
			"value": 1,
		},
	}

	var dictionary: Dictionary = GFVariantData.to_dictionary(source)
	var metadata: Dictionary = GFVariantData.duplicate_metadata(source)
	var dictionary_nested: Dictionary = _as_dictionary(dictionary["nested"])
	var metadata_nested: Dictionary = _as_dictionary(metadata["nested"])
	dictionary_nested["value"] = 2
	metadata_nested["value"] = 3

	var source_nested: Dictionary = _as_dictionary(source["nested"])
	assert_eq(_as_int(source_nested["value"]), 1, "归一化字典和元数据复制不应共享源集合。")
	var fallback_dictionary: Dictionary = GFVariantData.to_dictionary("bad", { "fallback": true })
	assert_true(_as_bool(fallback_dictionary["fallback"]), "非 Dictionary 输入应返回默认字典副本。")


func test_variant_narrowing_helpers_keep_copy_and_reference_semantics() -> void:
	var dictionary_source: Dictionary = {
		"nested": {
			"value": 1,
		},
	}
	var array_source: Array = [
		{
			"value": 1,
		},
	]

	var dictionary_ref: Dictionary = GFVariantData.as_dictionary(dictionary_source)
	var dictionary_copy: Dictionary = GFVariantData.to_dictionary(dictionary_source)
	var array_ref: Array = GFVariantData.as_array(array_source)
	var array_copy: Array = GFVariantData.to_array(array_source)

	dictionary_ref["ref"] = true
	var dictionary_copy_nested: Dictionary = _as_dictionary(dictionary_copy["nested"])
	dictionary_copy_nested["value"] = 2
	array_ref.append("ref")
	var array_copy_item: Dictionary = _as_dictionary(array_copy[0])
	array_copy_item["value"] = 2

	var dictionary_source_nested: Dictionary = _as_dictionary(dictionary_source["nested"])
	var array_source_item: Dictionary = _as_dictionary(array_source[0])
	assert_true(_as_bool(dictionary_source["ref"]), "as_dictionary() 应保留引用语义。")
	assert_eq(_as_int(dictionary_source_nested["value"]), 1, "to_dictionary() 应返回副本。")
	assert_true(array_source.has("ref"), "as_array() 应保留引用语义。")
	assert_eq(_as_int(array_source_item["value"]), 1, "to_array() 应返回副本。")


func test_scalar_variant_narrowing_helpers_use_explicit_fallbacks() -> void:
	assert_true(GFVariantData.to_bool("yes"), "bool 收窄应支持 yes。")
	assert_false(GFVariantData.to_bool("off", true), "bool 收窄应支持 off。")
	assert_true(GFVariantData.to_bool(0.5), "非零 float 应收窄为 true。")
	assert_false(GFVariantData.to_bool("maybe", false), "未知 bool 文本应返回 fallback。")
	assert_eq(GFVariantData.to_int("42"), 42, "int 收窄应支持整数字符串。")
	assert_eq(GFVariantData.to_int(true), 1, "int 收窄应支持 bool。")
	assert_eq(GFVariantData.to_int("1.5", 7), 7, "非整数字符串应返回 fallback。")
	assert_almost_eq(GFVariantData.to_float(&"3.5"), 3.5, 0.0001, "float 收窄应支持 StringName。")
	assert_almost_eq(GFVariantData.to_float(false), 0.0, 0.0001, "float 收窄应支持 bool。")
	assert_eq(GFVariantData.to_float("bad", 2.5), 2.5, "非法 float 文本应返回 fallback。")
	assert_eq(GFVariantData.to_text(NodePath("Root/Child")), "Root/Child", "String 收窄应支持 NodePath。")
	assert_eq(GFVariantData.to_text(null, "fallback"), "fallback", "null 文本应返回 fallback。")
	assert_eq(GFVariantData.to_string_name("route"), &"route", "StringName 收窄应支持 String。")
	assert_eq(GFVariantData.to_string_name(null, &"fallback"), &"fallback", "null 名称应返回 fallback。")


func test_exact_integer_helpers_preserve_json_numbers_without_coercion() -> void:
	assert_true(GFVariantData.is_exact_integer(1))
	assert_true(GFVariantData.is_exact_integer(1.0), "JSON 解析产生的整数 float 应被接受。")
	assert_true(GFVariantData.is_exact_integer(-2.0))
	assert_false(GFVariantData.is_exact_integer(1.5), "不得截断小数。")
	assert_false(GFVariantData.is_exact_integer("1"), "不得解析文本。")
	assert_false(GFVariantData.is_exact_integer(true), "不得把 bool 当作整数。")
	assert_false(GFVariantData.is_exact_integer(NAN))
	assert_false(GFVariantData.is_exact_integer(INF))
	assert_false(GFVariantData.is_exact_integer(9_007_199_254_740_992.0), "不接受超出 JSON 安全范围的 float。")
	assert_eq(GFVariantData.to_exact_int(3.0, -1), 3)
	assert_eq(GFVariantData.to_exact_int(3.5, -1), -1)
	assert_eq(GFVariantData.to_exact_int("3", -1), -1)


func test_values_equal_handles_numeric_and_string_name_options() -> void:
	assert_true(GFVariantData.values_equal(1, 1.0), "int/float 同数值应按通用等值语义相等。")
	assert_false(GFVariantData.values_equal(1.0, 1.01), "默认数值等值不应隐藏实际差异。")
	assert_true(
		GFVariantData.values_equal(1.0, 1.01, { "numeric_epsilon": 0.02 }),
		"numeric_epsilon 应允许调用方显式容忍浮点误差。"
	)
	assert_false(GFVariantData.values_equal("state.ready", &"state.ready"), "默认 String 与 StringName 不应跨类型相等。")
	assert_true(
		GFVariantData.values_equal("state.ready", &"state.ready", { "match_string_names": true }),
		"显式启用时 String 与 StringName 可按文本比较。"
	)


func test_values_equal_preserves_integer_precision_and_safe_mixed_numeric_contract() -> void:
	assert_false(
		GFVariantData.values_equal(9_007_199_254_740_992, 9_007_199_254_740_993),
		"int/int 必须保持完整 64 位精度。"
	)
	assert_false(
		GFVariantData.values_equal(9_007_199_254_740_993, 9_007_199_254_740_992.0),
		"不能安全往返的 int/float 不得等价。"
	)
	assert_true(
		GFVariantData.values_equal(1_152_921_504_606_846_976, 1_152_921_504_606_846_976.0),
		"可由 float 精确表示且能安全往返的大整数仍应等价。"
	)
	assert_false(
		GFVariantData.values_equal(1, 1.25, { "numeric_epsilon": 0.5 }),
		"numeric_epsilon 不得把非整数 float 与 int 混为一谈。"
	)
	assert_false(GFVariantData.values_equal(1, INF), "非有限 float 不得与 int 等价。")


func test_vector_variant_narrowing_helpers_support_common_shapes() -> void:
	var fallback_2: Vector2 = Vector2(9.0, 8.0)
	var fallback_3: Vector3 = Vector3(7.0, 6.0, 5.0)

	assert_eq(GFVariantData.to_vector2(Vector3(1.0, 2.0, 3.0)), Vector2(1.0, 2.0), "Vector2 收窄应接受 Vector3。")
	assert_eq(GFVariantData.to_vector2({ &"x": "3.5", "y": 4 }), Vector2(3.5, 4.0), "Vector2 收窄应接受字典。")
	assert_eq(GFVariantData.to_vector2("bad", fallback_2), fallback_2, "非法 Vector2 输入应返回 fallback。")
	assert_eq(GFVariantData.to_vector3(Vector2(1.0, 2.0), fallback_3), Vector3(1.0, 2.0, 5.0), "Vector3 收窄应接受 Vector2 并保留 fallback z。")
	assert_eq(GFVariantData.to_vector3([1, "2", 3.5]), Vector3(1.0, 2.0, 3.5), "Vector3 收窄应接受数组。")
	assert_eq(GFVariantData.get_option_vector2({ "position": { "x": 5, "y": 6 } }, &"position"), Vector2(5.0, 6.0), "Vector2 选项读取应支持 String/StringName 键。")


func test_array_variant_narrowing_helpers_copy_and_normalize_items() -> void:
	var string_values: Array[String] = GFVariantData.to_string_array(["a", &"b", 3])
	var name_values: Array[StringName] = GFVariantData.to_string_name_array(PackedStringArray(["state.ready", "team.enemy"]))
	var int_values: Array[int] = GFVariantData.to_int_array(["1", 2.9, true])
	var fallback_names: Array[StringName] = [&"fallback"]
	var fallback_result: Array[StringName] = GFVariantData.to_string_name_array({}, fallback_names)

	fallback_result.append(&"mutated")

	assert_eq(string_values, ["a", "b", "3"], "String 数组收窄应归一每个元素。")
	assert_eq(name_values, [&"state.ready", &"team.enemy"], "StringName 数组收窄应接受 PackedStringArray。")
	assert_eq(int_values, [1, 2, 1], "int 数组收窄应复用 int 标量规则。")
	assert_eq(fallback_names, [&"fallback"], "数组 fallback 应返回副本。")


func test_merge_dictionary_supports_recursive_overwrite_and_defaults() -> void:
	var base: Dictionary = {
		"audio": {
			"volume": 0.5,
			"mute": false,
		},
	}

	var _ignored_first_merge: Dictionary = GFVariantData.merge_dictionary(base, {
		"audio": {
			"volume": 0.75,
			"bus": "Music",
		},
	})

	var audio: Dictionary = _as_dictionary(base["audio"])
	assert_eq(_as_float(audio["volume"]), 0.75, "默认合并应覆盖已有字段。")
	assert_eq(_as_string(audio["bus"]), "Music", "递归合并应补入嵌套字段。")
	assert_false(_as_bool(audio["mute"]), "未被覆盖的嵌套字段应保留。")

	var _ignored_default_merge: Dictionary = GFVariantData.merge_dictionary(base, {
		"audio": {
			"volume": 1.0,
		},
		"language": "zh",
	}, false)

	audio = _as_dictionary(base["audio"])
	assert_eq(_as_float(audio["volume"]), 0.75, "overwrite=false 时已有字段不应被覆盖。")
	assert_eq(_as_string(base["language"]), "zh", "overwrite=false 仍应补齐缺失字段。")


func test_merge_dictionary_reuses_equivalent_string_and_string_name_keys() -> void:
	var base: Dictionary = {
		"settings": {
			"volume": 0.5,
		},
		&"enabled": true,
	}

	var _ignored_merge: Dictionary = GFVariantData.merge_dictionary(base, {
		&"settings": {
			"mute": false,
		},
		"enabled": false,
	})

	var settings: Dictionary = GFVariantData.get_option_dictionary(base, "settings")
	assert_eq(_count_keys_by_text(base, "settings"), 1, "String/StringName 等价 key 合并不应生成重复字段。")
	assert_eq(_count_keys_by_text(base, "enabled"), 1, "反向 String/StringName 等价 key 合并不应生成重复字段。")
	assert_eq(_as_float(settings["volume"]), 0.5, "原有嵌套字段应保留。")
	assert_false(_as_bool(settings["mute"]), "等价 key 命中时仍应递归合并嵌套字典。")
	assert_false(GFVariantData.get_option_bool(base, &"enabled", true), "等价 key 命中时应覆盖原字段。")


func test_merge_dictionary_stops_on_recursive_dictionary_pairs() -> void:
	var target_settings: Dictionary = {
		"existing": true,
	}
	target_settings["self"] = target_settings
	var source_settings: Dictionary = {
		"added": 7,
	}
	source_settings["self"] = source_settings
	var target: Dictionary = {
		"settings": target_settings,
	}
	var source: Dictionary = {
		"settings": source_settings,
	}

	var merged: Dictionary = GFVariantData.merge_dictionary(target, source)

	assert_true(is_same(merged, target), "递归合并仍应原地返回 target。")
	assert_eq(GFVariantData.get_option_int(target_settings, "added"), 7, "循环分支外的字段应继续合并。")
	assert_true(is_same(target_settings["self"], target_settings), "已访问的循环分支不应被展开或替换。")


func test_kernel_merge_dictionary_rejects_depth_budget_before_mutating_any_target_shape() -> void:
	var source: Dictionary = {
		"branch": {
			"nested": {
				"value": 1,
			},
		},
	}
	var missing_branch_target: Dictionary = {}
	var shaped_target: Dictionary = {
		"branch": {
			"kept": true,
		},
	}
	var shaped_before: Dictionary = shaped_target.duplicate(true)

	var _ignored_missing_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		missing_branch_target,
		source,
		true,
		true,
		{ "max_depth": 1 }
	)
	assert_push_error("[GFVariantAccess] merge_dictionary 失败：source 超出 max_depth 预算，target 未修改。")
	var _ignored_shaped_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		shaped_target,
		source,
		true,
		true,
		{ "max_depth": 1 }
	)
	assert_push_error("[GFVariantAccess] merge_dictionary 失败：source 超出 max_depth 预算，target 未修改。")

	assert_eq(missing_branch_target.size(), 0, "target 缺少分支时也不得绕过深度预算。")
	assert_eq(shaped_target, shaped_before, "target 已有同形分支时超限也必须保持原样。")


func test_kernel_merge_dictionary_rejects_node_and_collection_budgets_atomically() -> void:
	var source: Dictionary = {
		"first": 1,
		"second": 2,
	}
	var node_limited_target: Dictionary = { "kept": true }
	var collection_limited_target: Dictionary = { "kept": true }

	var _ignored_node_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		node_limited_target,
		source,
		true,
		true,
		{ "max_nodes": 1 }
	)
	assert_push_error("[GFVariantAccess] merge_dictionary 失败：source 超出 max_nodes 预算，target 未修改。")
	var _ignored_collection_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		collection_limited_target,
		source,
		true,
		true,
		{ "max_collection_items": 1 }
	)
	assert_push_error("[GFVariantAccess] merge_dictionary 失败：source 超出 max_collection_items 预算，target 未修改。")

	assert_eq(node_limited_target, { "kept": true }, "节点超限不得留下 partial merge。")
	assert_eq(collection_limited_target, { "kept": true }, "集合元素超限不得留下 partial merge。")


func test_kernel_merge_dictionary_produces_same_result_for_valid_target_shapes() -> void:
	var source: Dictionary = {
		"settings": {
			"volume": 0.75,
		},
	}
	var missing_branch_target: Dictionary = {}
	var shaped_target: Dictionary = {
		"settings": {},
	}
	var budget_options: Dictionary = {
		"max_depth": 4,
		"max_nodes": 32,
		"max_collection_items": 16,
	}

	var _ignored_missing_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		missing_branch_target,
		source,
		true,
		true,
		budget_options
	)
	var _ignored_shaped_merge: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(
		shaped_target,
		source,
		true,
		true,
		budget_options
	)

	assert_eq(missing_branch_target, shaped_target, "合法 source 的结果不应依赖 target 是否预先存在同形分支。")


func test_merge_dictionary_rejects_source_beyond_default_depth_budget() -> void:
	var source: Dictionary = {}
	var cursor: Dictionary = source
	for _depth: int in range(65):
		var nested: Dictionary = {}
		cursor["next"] = nested
		cursor = nested
	cursor["value"] = 1
	var target: Dictionary = {}

	var _ignored_merge: Dictionary = GFVariantData.merge_dictionary(target, source)
	assert_push_error("[GFVariantAccess] merge_dictionary 失败：source 超出 max_depth 预算，target 未修改。")

	assert_eq(target.size(), 0, "默认预算也必须在修改 target 前拒绝极深 source。")


func test_kernel_json_conversion_marks_circular_references_without_expanding_aliases() -> void:
	var source: Dictionary = {}
	source["left"] = source
	source["right"] = source

	var encoded: Dictionary = _as_dictionary(_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(source, 4))

	assert_eq(_as_string(encoded["left"]), "<circular_reference>", "循环边应立即使用稳定 marker。")
	assert_eq(_as_string(encoded["right"]), "<circular_reference>", "共享循环别名不应按深度指数展开。")


func test_kernel_json_conversion_fails_closed_when_budgets_are_exhausted() -> void:
	var node_limited: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
		[1, 2],
		32,
		{ "max_nodes": 2 }
	)
	var collection_limited: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
		[1, 2],
		32,
		{ "max_collection_items": 1 }
	)
	var packed_collection_limited: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
		PackedByteArray([1, 2]),
		32,
		{ "max_collection_items": 1 }
	)
	var byte_limited: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
		"abcdef",
		32,
		{ "max_bytes": 4 }
	)
	var depth_limited: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible({ "value": 1 }, 0)

	assert_eq(_as_string(node_limited), "<max_nodes>", "节点预算耗尽时不得返回 partial 数据。")
	assert_eq(_as_string(collection_limited), "<max_collection_items>", "集合元素预算耗尽时不得继续展开。")
	assert_eq(_as_string(packed_collection_limited), "<max_collection_items>", "PackedArray 必须在展开前检查集合元素预算。")
	assert_eq(_as_string(byte_limited), "<max_bytes>", "输出字节预算耗尽时不得返回超限数据。")
	assert_eq(_as_string(depth_limited), "<max_depth>", "深度预算耗尽时应返回顶层稳定 marker。")


func test_kernel_json_conversion_rejects_non_string_and_colliding_dictionary_keys() -> void:
	var non_string_source: Dictionary = {
		Vector2i(1, 2): "cell",
	}
	var colliding_source: Dictionary = {
		1: "numeric",
		"1": "text",
	}
	var string_name_source: Dictionary = {
		&"state": "ready",
	}

	var non_string_encoded: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(non_string_source)
	var colliding_encoded: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(colliding_source)
	var string_name_encoded: Dictionary = _as_dictionary(
		_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(string_name_source)
	)

	assert_eq(_as_string(non_string_encoded), "<invalid_dictionary_key>", "非字符串 key 必须 fail-closed。")
	assert_eq(_as_string(colliding_encoded), "<invalid_dictionary_key>", "非字符串与字符串同文本时不得静默覆盖字段。")
	assert_eq(_as_string(string_name_encoded["state"]), "ready", "StringName key 可无损规范化为 JSON 字符串 key。")


func test_diff_variant_reports_nested_dictionary_and_array_changes() -> void:
	var before: Dictionary = {
		"stats": {
			"hp": 10,
			"mp": 5,
		},
		"items": [
			{ "id": "potion" },
		],
		"removed": true,
	}
	var after: Dictionary = {
		"stats": {
			"hp": 12,
			"mp": 5,
		},
		"items": [
			{ "id": "potion" },
			{ "id": "key" },
		],
		"added": "new",
	}

	var report: Dictionary = GFVariantData.diff_variant(before, after)
	var hp_change: Dictionary = _find_change(report, "stats.hp")
	var added_item_change: Dictionary = _find_change(report, "items[1]")
	var removed_change: Dictionary = _find_change(report, "removed")
	var added_change: Dictionary = _find_change(report, "added")
	var reported_added_item: Dictionary = _as_dictionary(added_item_change["new_value"])

	assert_true(_as_bool(report["changed"]), "存在差异时报告应标记 changed。")
	assert_eq(_as_int(report["change_count"]), 4, "应记录字段修改、数组新增、字段删除和字段新增。")
	assert_false(_as_bool(report["truncated"]), "默认上限内不应截断。")
	assert_eq(_as_string(hp_change["kind"]), "changed", "数值变化应报告为 changed。")
	assert_eq(_as_int(hp_change["old_value"]), 10, "差异应包含旧值。")
	assert_eq(_as_int(hp_change["new_value"]), 12, "差异应包含新值。")
	assert_eq(_as_string(added_item_change["kind"]), "added", "数组尾部新增应报告为 added。")
	assert_eq(_as_string(removed_change["kind"]), "removed", "缺失字段应报告为 removed。")
	assert_eq(_as_string(added_change["kind"]), "added", "新增字段应报告为 added。")

	reported_added_item["id"] = "mutated"
	var after_items: Array = _as_array(after["items"])
	var after_added_item: Dictionary = _as_dictionary(after_items[1])
	assert_eq(_as_string(after_added_item["id"]), "key", "默认差异值应复制，避免报告修改污染源数据。")


func test_diff_variant_reports_type_changes_and_respects_limits() -> void:
	var limited_report: Dictionary = GFVariantData.diff_variant({
		"a": 1,
		"b": 2,
	}, {
		"a": 3,
		"b": 4,
	}, {
		"max_changes": 1,
	})
	var root_report: Dictionary = GFVariantData.diff_variant(1, "1")
	var root_changes: Array = _as_array(root_report["changes"])
	var root_change: Dictionary = _as_dictionary(root_changes[0])

	assert_true(_as_bool(limited_report["changed"]), "命中上限后仍应标记存在差异。")
	assert_true(_as_bool(limited_report["truncated"]), "max_changes 应限制记录数量并标记截断。")
	assert_eq(_as_int(limited_report["change_count"]), 1, "上限内只记录指定数量差异。")
	assert_eq(_as_string(root_change["path"]), "", "根值差异应使用空路径。")
	assert_eq(_as_string(root_change["kind"]), "type_changed", "类型不同应报告为 type_changed。")
	assert_eq(_as_string(root_change["old_type"]), type_string(TYPE_INT), "类型报告应包含旧类型。")
	assert_eq(_as_string(root_change["new_type"]), type_string(TYPE_STRING), "类型报告应包含新类型。")


func test_diff_variant_matches_string_and_string_name_keys_by_default() -> void:
	var before: Dictionary = {
		&"enabled": true,
		"profile": {
			&"name": "A",
		},
	}
	var after: Dictionary = {
		"enabled": true,
		&"profile": {
			"name": "A",
		},
	}

	var report: Dictionary = GFVariantData.diff_variant(before, after)

	assert_false(_as_bool(report["changed"]), "默认应复用 GF 的 String/StringName 等价 key 语义。")


func test_diff_variant_is_reflexive_for_scalar_and_cyclic_values() -> void:
	var recursive_dictionary: Dictionary = {}
	recursive_dictionary["self"] = recursive_dictionary
	var recursive_array: Array = []
	recursive_array.append(recursive_array)
	var shared_cycle: Dictionary = {
		"value": 1,
	}
	shared_cycle["self"] = shared_cycle
	var shared_graph: Dictionary = {
		"left": shared_cycle,
		"right": shared_cycle,
	}
	var values: Array = [
		NAN,
		recursive_dictionary,
		recursive_array,
		shared_graph,
	]

	for value: Variant in values:
		var report: Dictionary = GFVariantData.diff_variant(value, value, { "copy_values": false })
		var changes: Array = _as_array(report["changes"])

		assert_false(_as_bool(report["changed"]), "任意值与自身比较都必须 unchanged。")
		assert_eq(_as_int(report["change_count"]), 0, "自反比较不得生成 change。")
		assert_eq(changes.size(), 0, "自反比较的 changes 必须为空。")


func test_diff_variant_records_cycles_as_diagnostics_without_marking_changes() -> void:
	var before: Dictionary = {}
	before["self"] = before
	var after: Dictionary = {}
	after["self"] = after

	var report: Dictionary = GFVariantData.diff_variant(before, after, { "copy_values": false })
	var changes: Array = _as_array(report["changes"])
	var diagnostics: Array = _as_array(GFVariantData.get_option_value(report, "diagnostics", []))
	var cycle_diagnostic: Dictionary = _as_dictionary(diagnostics[0] if not diagnostics.is_empty() else {})

	assert_false(_as_bool(report["changed"]), "两个同构循环图应按展开内容视为 unchanged。")
	assert_eq(changes.size(), 0, "循环诊断不得伪装成 change。")
	assert_eq(GFVariantData.get_option_int(report, "diagnostic_count"), 1, "应记录一次活动 pair 重入诊断。")
	assert_false(GFVariantData.get_option_bool(report, "diagnostics_truncated"), "单个循环诊断不应被截断。")
	assert_eq(GFVariantData.get_option_string(cycle_diagnostic, "kind"), "cycle_detected", "循环应使用独立 traversal diagnostic。")
	assert_eq(GFVariantData.get_option_string(cycle_diagnostic, "path"), "self", "循环诊断应保留重入路径。")


func test_diff_variant_treats_isomorphic_shared_cycles_as_unchanged() -> void:
	var before_cycle: Dictionary = {
		"value": 1,
	}
	before_cycle["self"] = before_cycle
	var after_cycle: Dictionary = {
		"value": 1,
	}
	after_cycle["self"] = after_cycle
	var before: Dictionary = {
		"left": before_cycle,
		"right": before_cycle,
	}
	var after: Dictionary = {
		"left": after_cycle,
		"right": after_cycle,
	}

	var report: Dictionary = GFVariantData.diff_variant(before, after, {
		"copy_values": false,
		"max_diagnostics": 1,
	})
	var changes: Array = _as_array(report["changes"])
	var diagnostics: Array = _as_array(GFVariantData.get_option_value(report, "diagnostics", []))

	assert_false(_as_bool(report["changed"]), "独立但同构的共享循环图应按展开内容视为 unchanged。")
	assert_eq(changes.size(), 0, "共享循环诊断不得进入 changes。")
	assert_eq(diagnostics.size(), 1, "max_diagnostics 应限制记录的 traversal diagnostics。")
	assert_true(GFVariantData.get_option_bool(report, "diagnostics_truncated"), "省略额外循环诊断时必须显式标记截断。")


func test_diff_variant_keeps_shared_cycle_diagnostics_out_of_change_kinds() -> void:
	var before_cycle: Dictionary = {
		"value": 1,
	}
	before_cycle["self"] = before_cycle
	var after_cycle: Dictionary = {
		"value": 2,
	}
	after_cycle["self"] = after_cycle
	var before: Dictionary = {
		"left": before_cycle,
		"right": before_cycle,
	}
	var after: Dictionary = {
		"left": after_cycle,
		"right": after_cycle,
	}

	var report: Dictionary = GFVariantData.diff_variant(before, after, { "copy_values": false })
	var changes: Array = _as_array(report["changes"])
	var diagnostics: Array = _as_array(GFVariantData.get_option_value(report, "diagnostics", []))

	assert_true(_as_bool(report["changed"]), "循环图中的真实标量差异必须继续报告。")
	assert_true(diagnostics.size() >= 1, "共享循环图的活动 pair 重入应进入 traversal diagnostics。")
	for change_value: Variant in changes:
		var change: Dictionary = _as_dictionary(change_value)
		assert_true(
			["added", "removed", "changed", "type_changed"].has(_as_string(change["kind"])),
			"changes.kind 必须严格限制为公开声明的四种。"
		)


func test_diff_variant_reports_incomplete_traversal_without_inventing_changes() -> void:
	var before: Dictionary = {
		"level_1": {
			"level_2": {
				"level_3": {
					"value": 1,
				},
			},
		},
	}
	var after: Dictionary = before.duplicate(true)

	var report: Dictionary = GFVariantData.diff_variant(before, after, {
		"max_depth": 2,
		"copy_values": false,
	})
	var diagnostics: Array = GFVariantData.get_option_array(report, "diagnostics")
	var diagnostic: Dictionary = _as_dictionary(diagnostics[0] if not diagnostics.is_empty() else {})

	assert_false(GFVariantData.get_option_bool(report, "changed"), "预算耗尽本身不得伪造内容差异。")
	assert_false(GFVariantData.get_option_bool(report, "complete", true), "未遍历完的报告必须显式标记 complete=false。")
	assert_true(GFVariantData.get_option_bool(report, "traversal_truncated"), "深度预算耗尽必须与 max_changes 截断分开报告。")
	assert_eq(GFVariantData.get_option_string(report, "traversal_reason"), "max_depth", "报告应指出耗尽的具体预算。")
	assert_eq(GFVariantData.get_option_string(diagnostic, "kind"), "traversal_budget_exceeded", "预算问题应进入 traversal diagnostics。")
	assert_eq(GFVariantData.get_option_string(diagnostic, "reason"), "max_depth", "诊断应包含可机器读取的原因。")

	var node_limited_report: Dictionary = GFVariantData.diff_variant(before, after, {
		"max_depth": 0,
		"max_nodes": 2,
		"copy_values": false,
	})
	assert_false(GFVariantData.get_option_bool(node_limited_report, "complete", true), "节点预算耗尽也必须显式标记不完整。")
	assert_eq(GFVariantData.get_option_string(node_limited_report, "traversal_reason"), "max_nodes", "节点预算应使用独立原因。")

	var item_limited_report: Dictionary = GFVariantData.diff_variant(before, after, {
		"max_depth": 0,
		"max_nodes": 0,
		"max_collection_items": 1,
		"copy_values": false,
	})
	assert_false(GFVariantData.get_option_bool(item_limited_report, "complete", true), "集合预算耗尽也必须显式标记不完整。")
	assert_eq(GFVariantData.get_option_string(item_limited_report, "traversal_reason"), "max_collection_items", "集合预算应使用独立原因。")


func test_json_codec_preserves_business_dictionary_that_matches_reserved_marker_shape() -> void:
	var source: Dictionary = {
		GFVariantJsonCodec.JSON_MARKER_KEY: {
			GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
			GFVariantJsonCodec.JSON_TYPE_KEY: "StringName",
			GFVariantJsonCodec.JSON_VALUE_KEY: "route",
		},
	}

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(source)
	var text: String = JSON.stringify(encoded)
	var parsed: Variant = JSON.parse_string(text)
	var restored: Variant = GFVariantJsonCodec.json_compatible_to_variant(parsed)

	assert_true(restored is Dictionary, "业务字典即使撞到保留 key，也应保持字典语义。")
	var restored_dictionary: Dictionary = _as_dictionary(restored)
	assert_true(restored_dictionary.has(GFVariantJsonCodec.JSON_MARKER_KEY), "保留 key 应作为业务字段保留。")
	assert_true(encoded is Dictionary, "编码结果应仍是 JSON 字典。")
	var encoded_dictionary: Dictionary = _as_dictionary(encoded)
	assert_ne(encoded_dictionary, source, "撞到完整 marker 形状时应使用 Dictionary typed marker 转义。")


func test_json_codec_decoder_handles_circular_in_memory_dictionary() -> void:
	var source: Dictionary = {}
	source["self"] = source

	var restored: Variant = GFVariantJsonCodec.json_compatible_to_variant(source, {
		"circular_reference": "cycle",
	})

	assert_true(restored is Dictionary, "循环输入应返回可检查字典而不是递归挂起。")
	var restored_dictionary: Dictionary = _as_dictionary(restored)
	assert_eq(_as_string(restored_dictionary["self"]), "cycle", "循环位置应使用调用方指定占位值。")


func test_json_codec_decoder_keeps_cycle_state_inside_typed_dictionary_entries() -> void:
	var marker: Dictionary = {
		GFVariantJsonCodec.JSON_MARKER_KEY: {
			GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
			GFVariantJsonCodec.JSON_CODEC_KEY: GFVariantJsonCodec.JSON_CODEC_ID,
			GFVariantJsonCodec.JSON_TYPE_KEY: "Dictionary",
			GFVariantJsonCodec.JSON_VALUE_KEY: [],
		},
	}
	var marker_payload: Dictionary = _as_dictionary(marker[GFVariantJsonCodec.JSON_MARKER_KEY])
	var entries: Array = _as_array(marker_payload[GFVariantJsonCodec.JSON_VALUE_KEY])
	entries.append({
		"key": "self",
		"value": marker,
	})

	var restored: Variant = GFVariantJsonCodec.json_compatible_to_variant(marker, {
		"circular_reference": "cycle",
	})
	var restored_dictionary: Dictionary = _as_dictionary(restored)

	assert_true(restored is Dictionary, "typed Dictionary 的循环输入应安全终止。")
	assert_eq(_as_string(restored_dictionary["self"]), "cycle", "typed entry 递归必须复用外层 visited 状态。")


func test_json_codec_enforces_depth_and_collection_budgets() -> void:
	var deep_value: Dictionary = {
		"level_1": {
			"level_2": {
				"level_3": true,
			},
		},
	}

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(deep_value, {
		"max_depth": 2,
	})
	var encoded_dictionary: Dictionary = _as_dictionary(encoded)
	var marker: Dictionary = GFVariantData.get_option_dictionary(
		encoded_dictionary,
		GFVariantJsonCodec.JSON_MARKER_KEY
	)
	var marker_payload: Dictionary = GFVariantData.get_option_dictionary(
		marker,
		GFVariantJsonCodec.JSON_VALUE_KEY
	)
	var decoded: Variant = GFVariantJsonCodec.json_compatible_to_variant(deep_value, {
		"max_depth": 2,
		"traversal_limit": "limited",
	})
	var packed_limited: Variant = GFVariantJsonCodec.variant_to_json_compatible(
		PackedInt32Array([1, 2, 3]),
		{
			"max_collection_items": 2,
		}
	)
	var packed_marker: Dictionary = GFVariantData.get_option_dictionary(
		_as_dictionary(packed_limited),
		GFVariantJsonCodec.JSON_MARKER_KEY
	)
	var packed_payload: Dictionary = GFVariantData.get_option_dictionary(
		packed_marker,
		GFVariantJsonCodec.JSON_VALUE_KEY
	)
	var node_limited: Variant = GFVariantJsonCodec.variant_to_json_compatible(
		{
			"items": [1, 2],
		},
		{
			"max_nodes": 2,
		}
	)
	var node_marker: Dictionary = GFVariantData.get_option_dictionary(
		_as_dictionary(node_limited),
		GFVariantJsonCodec.JSON_MARKER_KEY
	)
	var node_payload: Dictionary = GFVariantData.get_option_dictionary(
		node_marker,
		GFVariantJsonCodec.JSON_VALUE_KEY
	)

	assert_eq(GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_TYPE_KEY), "TraversalLimit", "编码超限必须返回顶层稳定 marker，而非 partial 数据。")
	assert_eq(GFVariantData.get_option_string(marker_payload, "reason"), "max_depth", "超限 marker 应记录具体预算。")
	assert_eq(_as_string(decoded), "limited", "解码超限必须使用调用方指定的顶层 fallback。")
	assert_eq(GFVariantData.get_option_string(packed_marker, GFVariantJsonCodec.JSON_TYPE_KEY), "TraversalLimit", "PackedArray 也必须受集合预算约束。")
	assert_eq(GFVariantData.get_option_string(packed_payload, "reason"), "max_collection_items", "PackedArray 超限应报告集合预算。")
	assert_eq(GFVariantData.get_option_string(node_marker, GFVariantJsonCodec.JSON_TYPE_KEY), "TraversalLimit", "普通集合的叶节点必须受节点预算约束。")
	assert_eq(GFVariantData.get_option_string(node_payload, "reason"), "max_nodes", "节点超限应报告节点预算。")


func test_merge_metadata_is_recursive_and_copies_values() -> void:
	var base: Dictionary = {
		"tags": ["base"],
		"nested": {
			"a": 1,
		},
	}
	var source: Dictionary = {
		"tags": ["source"],
		"nested": {
			"b": 2,
		},
	}

	var _ignored_metadata_merge: Dictionary = GFVariantData.merge_metadata(base, source)
	var base_tags: Array = _as_array(base["tags"])
	base_tags.append("mutated")

	var base_nested: Dictionary = _as_dictionary(base["nested"])
	var source_tags: Array = _as_array(source["tags"])
	assert_eq(_as_int(base_nested["a"]), 1, "元数据合并应保留已有嵌套字段。")
	assert_eq(_as_int(base_nested["b"]), 2, "元数据合并应写入新嵌套字段。")
	assert_eq(source_tags.size(), 1, "元数据合并应复制来源集合。")


func test_option_readers_support_string_and_string_name_keys() -> void:
	var options: Dictionary = {
		&"enabled": "off",
		"count": "3",
		&"ratio": "0.5",
		"name": &"player",
		&"metadata": {
			"nested": {
				"value": 1,
			},
		},
		"empty": null,
		"items": [
			{ "id": 1 },
		],
		&"tags": ["a", &"b"],
	}

	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var items: Array = GFVariantData.get_option_array(options, &"items")
	var metadata_nested: Dictionary = _as_dictionary(metadata["nested"])
	var first_item: Dictionary = _as_dictionary(items[0])
	metadata_nested["value"] = 2
	first_item["id"] = 9

	assert_false(GFVariantData.get_option_bool(options, "enabled", true), "bool 读取应支持字符串 false/off。")
	assert_eq(GFVariantData.get_option_int(options, &"count"), 3, "int 读取应支持 String 键和 StringName 查询。")
	assert_almost_eq(GFVariantData.get_option_float(options, "ratio"), 0.5, 0.0001, "float 读取应支持 StringName 键和 String 查询。")
	assert_eq(GFVariantData.get_option_string(options, &"name"), "player", "String 读取应归一文本。")
	assert_eq(GFVariantData.get_option_string_name(options, "name"), &"player", "StringName 读取应归一名称。")
	assert_eq(GFVariantData.get_option_string(options, "empty", "fallback"), "fallback", "显式 null 应使用默认字符串。")
	var original_metadata: Dictionary = _as_dictionary(options[&"metadata"])
	var original_metadata_nested: Dictionary = _as_dictionary(original_metadata["nested"])
	var original_items: Array = _as_array(options["items"])
	var original_first_item: Dictionary = _as_dictionary(original_items[0])
	assert_eq(_as_int(original_metadata_nested["value"]), 1, "Dictionary 选项应返回副本。")
	assert_eq(_as_int(original_first_item["id"]), 1, "Array 选项应返回副本。")
	assert_eq(GFVariantData.get_option_packed_string_array(options, "tags"), PackedStringArray(["a", "b"]), "PackedStringArray 读取应接受普通数组。")
	assert_eq(GFVariantData.get_option_string_name_array(options, "tags"), [&"a", &"b"], "StringName 数组选项应接受普通数组。")
	assert_eq(GFVariantData.get_option_string_array({ "paths": PackedStringArray(["res://a.gd"]) }, &"paths"), ["res://a.gd"], "String 数组选项应接受 PackedStringArray。")
	assert_eq(GFVariantData.get_option_int_array({ "ids": ["1", 2] }, &"ids"), [1, 2], "int 数组选项应按元素收窄。")
	assert_eq(_as_string(GFVariantData.get_option_value(options, &"missing", "fallback")), "fallback", "缺失选项应返回默认值。")


func test_vector_and_color_array_roundtrip() -> void:
	assert_eq(GFVariantJsonCodec.array_to_vector2(GFVariantJsonCodec.vector2_to_array(Vector2(1.0, 2.0))), Vector2(1.0, 2.0))
	assert_eq(GFVariantJsonCodec.array_to_vector3(GFVariantJsonCodec.vector3_to_array(Vector3(1.0, 2.0, 3.0))), Vector3(1.0, 2.0, 3.0))
	assert_eq(GFVariantJsonCodec.array_to_color(GFVariantJsonCodec.color_to_array(Color(0.1, 0.2, 0.3, 0.4))), Color(0.1, 0.2, 0.3, 0.4))
	assert_eq(GFVariantJsonCodec.array_to_vector2(["bad"], Vector2.ONE), Vector2.ONE, "非法数组应返回 fallback。")


func test_json_text_helpers_parse_format_and_compact() -> void:
	var source: String = "{ \"b\": 2, \"a\": [true, \" spaced value \"] }"

	var parsed: Dictionary = _as_dictionary(GFVariantJsonCodec.parse_json_text(source))
	var formatted: String = GFVariantJsonCodec.format_json_text(source, "  ", true)
	var compact: String = GFVariantJsonCodec.compact_json_text(formatted)

	assert_eq(_as_int(parsed["b"]), 2, "JSON 文本解析应返回 Godot JSON 数据。")
	assert_true(formatted.contains("\n"), "格式化 JSON 应包含换行。")
	assert_lt(formatted.find("\"a\""), formatted.find("\"b\""), "启用 sort_keys 时应稳定排序字典键。")
	assert_false(compact.contains("\n"), "压缩 JSON 不应保留换行。")
	assert_true(compact.contains("\" spaced value \""), "压缩 JSON 不应修改字符串内空白。")
	var compact_data: Dictionary = _as_dictionary(JSON.parse_string(compact))
	var source_data: Dictionary = _as_dictionary(JSON.parse_string(source))
	assert_eq(compact_data, source_data, "格式化和压缩不应改变 JSON 语义。")


func test_json_text_helpers_return_fallback_on_parse_error() -> void:
	var fallback_data: Dictionary = { "safe": true }

	assert_eq(_as_dictionary(GFVariantJsonCodec.parse_json_text("{", fallback_data)), fallback_data, "解析失败应返回调用方 fallback。")
	assert_eq(GFVariantJsonCodec.format_json_text("{", "\t", false, "invalid"), "invalid", "格式化失败应返回 fallback 文本。")
	assert_eq(GFVariantJsonCodec.compact_json_text("{", false, "invalid"), "invalid", "压缩失败应返回 fallback 文本。")


func test_stringify_json_compatible_encodes_nonfinite_values_before_stringify() -> void:
	var source: Dictionary = {
		"nan": NAN,
		"position": Vector3(1.0, INF, -INF),
		"name": &"state.ready",
	}

	var json_text: String = GFVariantJsonCodec.stringify_json_compatible(source, "", true)
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.parse_json_compatible_text(json_text))
	var decoded_nan: float = _as_float(decoded["nan"])
	var decoded_position: Vector3 = _as_vector3(decoded["position"])

	assert_false(json_text.contains(":null"), "高层 stringify 不应把非有限 float 交给 JSON.stringify 替换成 null。")
	assert_true(json_text.contains("\"NaN\""), "NaN 应以可读 typed marker 写入文本。")
	assert_true(is_nan(decoded_nan), "安全 stringify 后应能恢复 NaN。")
	assert_true(is_inf(decoded_position.y) and decoded_position.y > 0.0, "Vector3 中的正无穷应可恢复。")
	assert_true(is_inf(decoded_position.z) and decoded_position.z < 0.0, "Vector3 中的负无穷应可恢复。")
	assert_eq(_as_string(decoded["name"]), "state.ready", "StringName 应经高层入口往返。")


func test_parse_json_compatible_text_returns_fallback_on_parse_error() -> void:
	var fallback_data: Dictionary = { "safe": true }

	var parsed: Variant = GFVariantJsonCodec.parse_json_compatible_text("{", fallback_data)
	var parsed_dictionary: Dictionary = _as_dictionary(parsed)

	assert_true(is_same(parsed_dictionary, fallback_data), "JSON 兼容解析失败时应原样返回 fallback。")


func test_stringify_json_compatible_can_preserve_dictionary_keys() -> void:
	var source: Dictionary = {
		Vector2i(1, 2): "cell",
		"1,2": "text",
	}

	var json_text: String = GFVariantJsonCodec.stringify_json_compatible(source, "", false, {
		"encode_dictionary_keys": true,
	})
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.parse_json_compatible_text(json_text))

	assert_eq(_as_string(decoded[Vector2i(1, 2)]), "cell", "高层 stringify 应透传字典 key 编码选项。")
	assert_eq(_as_string(decoded["1,2"]), "text", "普通字符串 key 不应被同名 Vector key 覆盖。")


func test_json_compatible_codec_round_trips_godot_value_types() -> void:
	var source: Dictionary = {
		"position": Vector3(1.0, 2.0, 3.0),
		"cell": Vector2i(4, 5),
		"color": Color(0.2, 0.4, 0.6, 0.8),
		"path": NodePath("Root/Child"),
		"names": PackedStringArray(["a", "b"]),
		"points": PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)]),
	}

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(source)
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded))))

	assert_eq(_as_vector3(decoded["position"]), Vector3(1.0, 2.0, 3.0), "Vector3 应可经 JSON 兼容编码往返。")
	assert_eq(_as_vector2i(decoded["cell"]), Vector2i(4, 5), "Vector2i 应保留整数类型。")
	assert_eq(_as_color(decoded["color"]), Color(0.2, 0.4, 0.6, 0.8), "Color 应保留通道值。")
	assert_eq(_as_node_path(decoded["path"]), NodePath("Root/Child"), "NodePath 应恢复为 NodePath。")
	assert_eq(_as_packed_string_array(decoded["names"]), PackedStringArray(["a", "b"]), "PackedStringArray 应恢复为 PackedStringArray。")
	assert_eq(_as_packed_vector2_array(decoded["points"]), PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)]), "PackedVector2Array 应恢复。")


func test_json_compatible_codec_keeps_typed_markers_idempotent() -> void:
	var source: Dictionary = {
		"position": Vector2(0.25, -0.5),
		"tags": PackedStringArray(["tutorial"]),
	}

	var encoded_once: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(source))
	var encoded_twice: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(encoded_once))
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded_twice))))

	assert_eq(_as_dictionary(encoded_twice["position"]), _as_dictionary(encoded_once["position"]), "合法 typed marker 二次编码应保持幂等。")
	assert_eq(_as_vector2(decoded["position"]), Vector2(0.25, -0.5), "二次编码后的 Vector2 应可恢复。")
	assert_eq(_as_packed_string_array(decoded["tags"]), PackedStringArray(["tutorial"]), "二次编码后的 PackedStringArray 应可恢复。")


func test_json_compatible_codec_preserves_unsafe_int64_values() -> void:
	var large_positive: int = 9_223_372_036_854_775_000
	var large_negative: int = -9_223_372_036_854_775_000
	var source: Dictionary = {
		"safe": 42,
		"large_positive": large_positive,
		"large_negative": large_negative,
		"packed": PackedInt64Array([large_positive, large_negative]),
	}

	var encoded: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(source))
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded))))

	assert_eq(_as_int(encoded["safe"]), 42, "JSON 安全范围内的整数应保持普通数字，方便阅读。")
	assert_true(encoded["large_positive"] is Dictionary, "超出 JSON 安全范围的 64 位整数应写入类型标记。")
	assert_eq(_as_int(decoded["large_positive"]), large_positive, "正向大整数应精确往返。")
	assert_eq(_as_int(decoded["large_negative"]), large_negative, "负向大整数应精确往返。")
	assert_eq(_as_packed_int64_array(decoded["packed"]), PackedInt64Array([large_positive, large_negative]), "PackedInt64Array 中的大整数应精确往返。")


func test_json_compatible_codec_encodes_nonfinite_float_values() -> void:
	var source: Dictionary = {
		"nan": NAN,
		"positive_inf": INF,
		"negative_inf": -INF,
		"vector": Vector2(NAN, INF),
		"packed": PackedFloat32Array([NAN, INF, -INF]),
	}

	var encoded: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(source))
	var json_text: String = JSON.stringify(encoded)
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(json_text)))
	var decoded_nan: float = _as_float(decoded["nan"])
	var decoded_positive_inf: float = _as_float(decoded["positive_inf"])
	var decoded_negative_inf: float = _as_float(decoded["negative_inf"])
	var decoded_vector: Vector2 = _as_vector2(decoded["vector"])
	var decoded_packed: PackedFloat32Array = _as_packed_float32_array(decoded["packed"])

	assert_true(json_text.contains("\"Float\""), "非有限 float 应使用 typed marker，避免 JSON.stringify 将其替换成 null。")
	assert_true(json_text.contains("\"NaN\""), "NaN 标记应可读且可往返。")
	assert_true(is_nan(decoded_nan), "NaN 应可经 JSON 兼容编码往返。")
	assert_true(is_inf(decoded_positive_inf) and decoded_positive_inf > 0.0, "正无穷应可经 JSON 兼容编码往返。")
	assert_true(is_inf(decoded_negative_inf) and decoded_negative_inf < 0.0, "负无穷应可经 JSON 兼容编码往返。")
	assert_true(is_nan(decoded_vector.x), "Vector2 非有限 x 分量应可往返。")
	assert_true(is_inf(decoded_vector.y) and decoded_vector.y > 0.0, "Vector2 非有限 y 分量应可往返。")
	assert_true(is_nan(decoded_packed[0]), "PackedFloat32Array 中的 NaN 应可往返。")
	assert_true(is_inf(decoded_packed[1]) and decoded_packed[1] > 0.0, "PackedFloat32Array 中的正无穷应可往返。")
	assert_true(is_inf(decoded_packed[2]) and decoded_packed[2] < 0.0, "PackedFloat32Array 中的负无穷应可往返。")


func test_json_compatible_codec_decodes_malformed_typed_marker_values_safely() -> void:
	var marker: Dictionary = {
		GFVariantJsonCodec.JSON_MARKER_KEY: {
			GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
			GFVariantJsonCodec.JSON_CODEC_KEY: GFVariantJsonCodec.JSON_CODEC_ID,
			GFVariantJsonCodec.JSON_TYPE_KEY: "Int64",
			GFVariantJsonCodec.JSON_VALUE_KEY: 42,
		},
	}

	var decoded: Variant = GFVariantJsonCodec.json_compatible_to_variant(marker)

	assert_eq(_as_int(decoded), 42, "手写 typed marker 使用数字 value 时也不应触发 String(Variant) 转换错误。")


func test_json_compatible_codec_can_preserve_dictionary_keys() -> void:
	var source: Dictionary = {
		Vector2i(1, 2): "cell",
		&"tag": "value",
	}

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(source, { "encode_dictionary_keys": true })
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded))))

	assert_eq(_as_string(decoded[Vector2i(1, 2)]), "cell", "启用字典键编码时应保留非字符串键。")
	assert_eq(_as_string(decoded[&"tag"]), "value", "StringName 字典键应恢复。")


func test_json_compatible_codec_preserves_dictionary_keys_when_stringified_keys_collide() -> void:
	var source: Dictionary = {
		1: "numeric",
		"1": "text",
	}

	var encoded: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(source))
	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(JSON.parse_string(JSON.stringify(encoded))))

	assert_true(encoded.has(GFVariantJsonCodec.JSON_MARKER_KEY), "默认字典编码发现 key 字符串碰撞时应自动切换 typed entries。")
	assert_eq(_as_string(decoded[1]), "numeric", "数字 key 应在碰撞场景下保留。")
	assert_eq(_as_string(decoded["1"]), "text", "字符串 key 应在碰撞场景下保留。")


func test_report_value_codec_redacts_runtime_values_and_keeps_json_safe_numbers() -> void:
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


func test_report_value_codec_redacts_runtime_dictionary_keys() -> void:
	var secret_node: Node = Node.new()
	secret_node.name = "PrivateAdapterName"
	var payload: Dictionary = { secret_node: "value" }
	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(
		payload,
		GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_PUBLIC)
	))
	var marker: Dictionary = _as_dictionary(encoded["__gf_report_value__"])
	var entries: Array = _as_array(marker["entries"])
	var first_entry: Dictionary = _as_dictionary(entries[0])
	var key_marker: Dictionary = _as_dictionary(_as_dictionary(first_entry["key"])["__gf_report_value__"])
	var json_text: String = JSON.stringify(encoded)
	secret_node.free()

	assert_eq(_as_string(marker["type"]), "Dictionary", "不稳定字典 key 应切换为结构化 entries。")
	assert_eq(_as_string(key_marker["type"]), "Object", "Object key 应经过同一报告脱敏边界。")
	assert_false(json_text.contains("PrivateAdapterName"), "public profile 不应通过字典 key 泄漏对象名称。")


func test_report_value_codec_redacts_paths_by_default() -> void:
	var payload: Dictionary = {
		"path": "res://secret/config.json",
	}

	var encoded: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(payload))
	var unredacted: Dictionary = _as_dictionary(GFReportValueCodec.to_json_compatible(payload, {
		"path_redaction": "none",
	}))

	assert_eq(_as_string(encoded["path"]), "<redacted_path>", "报告导出默认不应暴露资源路径。")
	assert_eq(_as_string(unredacted["path"]), "res://secret/config.json", "开发态可显式保留完整路径。")


func test_report_value_codec_uses_explicit_redaction_profiles() -> void:
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


func test_report_value_codec_summarizes_large_collections() -> void:
	var values: Array = []
	for index: int in range(20):
		values.append(Vector2i(index, index + 1))

	var summary: Dictionary = GFReportValueCodec.make_collection_summary(values, {
		"sample_count": 3,
		"encode_dictionary_keys": true,
	})
	var sample: Array = GFVariantData.get_option_array(summary, "sample")

	assert_true(GFVariantData.get_option_bool(summary, "ok"), "集合摘要应成功。")
	assert_eq(GFVariantData.get_option_int(summary, "count"), 20, "集合摘要应保留总数。")
	assert_eq(sample.size(), 3, "集合摘要应按 sample_count 截断样本。")
	assert_true(GFVariantData.get_option_bool(summary, "truncated"), "集合摘要应说明截断。")
	assert_false(
		GFVariantData.get_option_string(summary, "encoded_preview_hash").is_empty(),
		"集合摘要应明确提供预算内编码预览 hash。"
	)
	assert_false(summary.has("hash"), "预算内预览不得伪装成完整内容 hash。")
	assert_false(JSON.stringify(summary).contains(":null"), "集合摘要不应触发 JSON 非有限值替换。")


func test_variant_key_codec_accepts_finite_values_and_rejects_unstable_values() -> void:
	var vector_token: String = GFVariantKeyCodec.make_key_token(Vector2(1.0, 2.0))
	var string_token: String = GFVariantKeyCodec.make_key_token("1")
	var int_token: String = GFVariantKeyCodec.make_key_token(1)

	assert_true(vector_token.begins_with("gfv1:"), "稳定数学值应能生成带版本前缀的 key token。")
	assert_ne(string_token, int_token, "不同 Variant 类型不能因为文本相同而碰撞。")
	assert_false(GFVariantKeyCodec.is_stable_key({ "id": 1 }), "Dictionary 不应作为稳定 key。")
	assert_false(GFVariantKeyCodec.is_stable_key(NAN), "NaN 不应作为稳定 key。")
	assert_eq(GFVariantKeyCodec.make_key_token(self), "", "运行时对象不应隐式编码为 key。")


func test_json_compatible_codec_marks_circular_references() -> void:
	var source: Dictionary = {}
	source["self"] = source

	var encoded: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(source))
	var circular_marker: Dictionary = _as_dictionary(encoded["self"])
	var circular_payload: Dictionary = _as_dictionary(circular_marker[GFVariantJsonCodec.JSON_MARKER_KEY])
	var json_text: String = JSON.stringify(encoded)

	assert_eq(_as_string(circular_payload[GFVariantJsonCodec.JSON_TYPE_KEY]), "CircularReference", "循环引用应被标记而不是递归展开。")
	assert_false(json_text.is_empty(), "包含循环引用的结构仍应可被 JSON.stringify 编码。")


func test_json_compatible_codec_marks_circular_array_references() -> void:
	var source: Array = []
	source.append(source)

	var encoded: Array = _as_array(GFVariantJsonCodec.variant_to_json_compatible(source))
	var circular_marker: Dictionary = _as_dictionary(encoded[0])
	var circular_payload: Dictionary = _as_dictionary(circular_marker[GFVariantJsonCodec.JSON_MARKER_KEY])

	assert_eq(_as_string(circular_payload[GFVariantJsonCodec.JSON_TYPE_KEY]), "CircularReference", "数组自引用应被标记。")


func test_json_compatible_codec_does_not_decode_plain_dictionary_type_fields() -> void:
	var source: Dictionary = {
		"_gf_type": "Vector2",
		"value": [1.0, 2.0],
	}

	var decoded: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(source))

	assert_eq(_as_string(decoded["_gf_type"]), "Vector2", "普通业务字典中的旧类型字段不应被误判为 typed marker。")
	assert_eq(_as_array(decoded["value"]), [1.0, 2.0], "普通业务字典中的 value 字段应原样保留。")


func test_json_compatible_codec_only_decodes_dedicated_variant_marker() -> void:
	var marker: Dictionary = _as_dictionary(GFVariantJsonCodec.variant_to_json_compatible(Vector2(1.0, 2.0)))
	var wrapped_business_data: Dictionary = {
		GFVariantJsonCodec.JSON_MARKER_KEY: marker[GFVariantJsonCodec.JSON_MARKER_KEY],
		"label": "business",
	}

	var decoded_marker: Variant = GFVariantJsonCodec.json_compatible_to_variant(marker)
	var decoded_business_data: Dictionary = _as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(wrapped_business_data))

	assert_eq(_as_vector2(decoded_marker), Vector2(1.0, 2.0), "独立 typed marker 应恢复为对应 Godot 类型。")
	assert_true(decoded_business_data.has("label"), "带有额外业务字段的字典不应被当作 typed marker。")


func test_reference_codec_requires_marker_version() -> void:
	var business_data: Dictionary = {
		GFVariantReferenceCodec.REFERENCE_MARKER_KEY: {
			GFVariantReferenceCodec.REFERENCE_KIND_KEY: GFVariantReferenceCodec.REFERENCE_KIND_RESOURCE,
			GFVariantReferenceCodec.REFERENCE_PATH_KEY: "res://business.tres",
		},
	}

	var decoded: Dictionary = GFVariantReferenceCodec.decode_reference(business_data)

	assert_false(GFVariantReferenceCodec.is_reference_marker(business_data), "缺少版本的业务字典不应被识别为引用标记。")
	assert_false(GFVariantData.get_option_bool(decoded, "ok", true), "缺少版本的字典不应进入引用解码路径。")


func test_reference_codec_roundtrips_resource_reference() -> void:
	var directory_path: String = "res://gf_variant_reference_codec.tmp"
	var resource_path: String = directory_path.path_join("resource.tres")
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	assert_true(make_dir_error == OK or make_dir_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 引用目录。")

	var resource: Resource = StyleBoxFlat.new()
	resource.resource_name = "ReferenceCodecResource"
	assert_eq(ResourceSaver.save(resource, resource_path), OK, "测试 Resource 应能保存。")
	var loaded_resource: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	var encoded: Dictionary = GFVariantReferenceCodec.encode_reference(loaded_resource)
	var marker: Dictionary = GFVariantReferenceCodec.get_reference_marker(encoded)
	var json_encoded: Dictionary = _as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var denied_result: Dictionary = GFVariantReferenceCodec.decode_reference(json_encoded)
	var result: Dictionary = GFVariantReferenceCodec.decode_reference(json_encoded, {
		GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS: PackedStringArray([resource_path.get_base_dir()]),
	})
	var decoded_resource: Resource = _as_resource(GFVariantData.get_option_value(result, "value"))

	assert_false(GFVariantData.get_option_bool(denied_result, "ok", true), "未提供 Resource allowlist 时不应恢复引用。")
	assert_true(GFVariantData.get_option_bool(result, "ok"), "Resource 引用标记应能经 JSON 往返后恢复。")
	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_KIND_KEY), GFVariantReferenceCodec.REFERENCE_KIND_RESOURCE, "Resource 引用应标记类型。")
	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_PATH_KEY), resource_path, "Resource 引用应保留路径。")
	assert_eq(decoded_resource.resource_path, resource_path, "Resource 应按路径或 UID 恢复。")

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if FileAccess.file_exists(resource_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)
	var absolute_directory_path: String = ProjectSettings.globalize_path(directory_path)
	if DirAccess.dir_exists_absolute(absolute_directory_path):
		var _remove_directory_result: Variant = DirAccess.remove_absolute(absolute_directory_path)


func test_reference_codec_can_restrict_resource_decode_paths() -> void:
	var directory_path: String = "res://gf_variant_reference_policy.tmp"
	var resource_path: String = directory_path.path_join("resource.tres")
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	assert_true(make_dir_error == OK or make_dir_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 策略目录。")

	var resource: Resource = StyleBoxFlat.new()
	resource.resource_name = "PolicyResource"
	assert_eq(ResourceSaver.save(resource, resource_path), OK, "测试 Resource 应能保存到策略目录。")
	var loaded_resource: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var encoded: Dictionary = GFVariantReferenceCodec.encode_reference(loaded_resource)

	var denied_result: Dictionary = GFVariantReferenceCodec.decode_reference(encoded, {
		GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS: PackedStringArray(["res://allowed"]),
	})
	var allowed_root_result: Dictionary = GFVariantReferenceCodec.decode_reference(encoded, {
		GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS: PackedStringArray([directory_path]),
	})
	var allowed_pattern_result: Dictionary = GFVariantReferenceCodec.decode_reference(encoded, {
		GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_PATTERNS: PackedStringArray([directory_path.path_join("*.tres")]),
	})

	assert_false(GFVariantData.get_option_bool(denied_result, "ok", true), "不在允许根目录内的 Resource 引用不应恢复。")
	assert_eq(GFVariantData.get_option_string(denied_result, "kind"), GFVariantReferenceCodec.REFERENCE_KIND_RESOURCE, "拒绝报告应保留引用类型。")
	assert_true(GFVariantData.get_option_bool(allowed_root_result, "ok"), "允许根目录内的 Resource 引用应可恢复。")
	assert_true(GFVariantData.get_option_bool(allowed_pattern_result, "ok"), "匹配允许模式的 Resource 引用应可恢复。")

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if FileAccess.file_exists(resource_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)
	var absolute_directory_path: String = ProjectSettings.globalize_path(directory_path)
	if DirAccess.dir_exists_absolute(absolute_directory_path):
		var _remove_directory_result: Variant = DirAccess.remove_absolute(absolute_directory_path)


func test_reference_codec_roundtrips_node_reference_with_explicit_root() -> void:
	var root: Node = Node.new()
	root.name = "ReferenceRoot"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)

	var encoded: Dictionary = GFVariantReferenceCodec.encode_reference(child, {
		GFVariantReferenceCodec.OPTION_ROOT_NODE: root,
	})
	var marker: Dictionary = GFVariantReferenceCodec.get_reference_marker(encoded)
	var json_encoded: Dictionary = _as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var result: Dictionary = GFVariantReferenceCodec.decode_reference(json_encoded, {
		GFVariantReferenceCodec.OPTION_ROOT_NODE: root,
	})
	var missing_root_result: Dictionary = GFVariantReferenceCodec.decode_reference(json_encoded)

	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_KIND_KEY), GFVariantReferenceCodec.REFERENCE_KIND_NODE, "Node 引用应标记类型。")
	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_NODE_PATH_KEY), "Child", "Node 引用应保存相对 root 的 NodePath。")
	assert_true(GFVariantData.get_option_bool(result, "ok"), "提供 root 时应能恢复 Node 引用。")
	assert_same(_as_node(GFVariantData.get_option_value(result, "value")), child, "Node 引用恢复结果应为同一节点。")
	assert_false(GFVariantData.get_option_bool(missing_root_result, "ok"), "没有 root 时不应从场景树全局解析 Node。")


func test_reference_codec_rejects_node_paths_outside_reference_root() -> void:
	var root: Node = Node.new()
	root.name = "ReferenceRoot"
	add_child_autofree(root)
	var other_root: Node = Node.new()
	other_root.name = "OtherReferenceRoot"
	add_child_autofree(other_root)
	var outside_child: Node = Node.new()
	outside_child.name = "Outside"
	other_root.add_child(outside_child)

	var parent_escape_marker: Dictionary = {
		GFVariantReferenceCodec.REFERENCE_MARKER_KEY: {
			GFVariantReferenceCodec.REFERENCE_VERSION_KEY: 1,
			GFVariantReferenceCodec.REFERENCE_KIND_KEY: GFVariantReferenceCodec.REFERENCE_KIND_NODE,
			GFVariantReferenceCodec.REFERENCE_NODE_PATH_KEY: "../OtherReferenceRoot/Outside",
		},
	}
	var absolute_escape_marker: Dictionary = {
		GFVariantReferenceCodec.REFERENCE_MARKER_KEY: {
			GFVariantReferenceCodec.REFERENCE_VERSION_KEY: 1,
			GFVariantReferenceCodec.REFERENCE_KIND_KEY: GFVariantReferenceCodec.REFERENCE_KIND_NODE,
			GFVariantReferenceCodec.REFERENCE_NODE_PATH_KEY: String(outside_child.get_path()),
		},
	}
	var parent_escape_result: Dictionary = GFVariantReferenceCodec.decode_reference(parent_escape_marker, {
		GFVariantReferenceCodec.OPTION_ROOT_NODE: root,
	})
	var absolute_escape_result: Dictionary = GFVariantReferenceCodec.decode_reference(absolute_escape_marker, {
		GFVariantReferenceCodec.OPTION_ROOT_NODE: root,
	})

	assert_false(GFVariantData.get_option_bool(parent_escape_result, "ok", true), "Node 引用不应允许 .. 越过 reference root。")
	assert_false(GFVariantData.get_option_bool(absolute_escape_result, "ok", true), "Node 引用不应允许绝对路径绕过 reference root。")


func test_reference_codec_marks_node_outside_root_as_unsupported() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var other_root: Node = Node.new()
	other_root.name = "OtherRoot"
	add_child_autofree(other_root)
	var child: Node = Node.new()
	child.name = "Outside"
	other_root.add_child(child)

	var encoded: Dictionary = GFVariantReferenceCodec.encode_reference(child, {
		GFVariantReferenceCodec.OPTION_ROOT_NODE: root,
	})

	assert_true(GFVariantReferenceCodec.is_unsupported_reference_marker(encoded), "root 外的 Node 不应被编码成可恢复引用。")


# --- 测试侧 Variant 观察辅助 ---

func _as_dictionary(value: Variant) -> Dictionary:
	assert_true(value is Dictionary, "测试观察值应为 Dictionary。")
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _as_array(value: Variant) -> Array:
	assert_true(value is Array, "测试观察值应为 Array。")
	if value is Array:
		var array: Array = value
		return array
	return []


func _count_keys_by_text(data: Dictionary, key_text: String) -> int:
	var count: int = 0
	for key: Variant in data.keys():
		if GFVariantData.to_text(key) == key_text:
			count += 1
	return count


func _find_change(report: Dictionary, path: String) -> Dictionary:
	var changes: Array = _as_array(report["changes"])
	for change_value: Variant in changes:
		var change: Dictionary = _as_dictionary(change_value)
		if _as_string(change["path"]) == path:
			return change
	assert_true(false, "应找到路径 %s 的差异。" % path)
	return {}


func _as_bool(value: Variant) -> bool:
	assert_true(value is bool, "测试观察值应为 bool。")
	if value is bool:
		var boolean: bool = value
		return boolean
	return false


func _as_float(value: Variant) -> float:
	assert_true(value is int or value is float, "测试观察值应为数字。")
	if value is float:
		var number: float = value
		return number
	if value is int:
		var integer: int = value
		return float(integer)
	return 0.0


func _as_int(value: Variant) -> int:
	assert_true(value is int or value is float, "测试观察值应为数字。")
	if value is int:
		var integer: int = value
		return integer
	if value is float:
		var number: float = value
		return int(number)
	return 0


func _as_string(value: Variant) -> String:
	assert_true(value is String or value is StringName or value is NodePath, "测试观察值应为文本。")
	if value is String:
		var text: String = value
		return text
	if value is StringName:
		var text_name: StringName = value
		return String(text_name)
	if value is NodePath:
		var path: NodePath = value
		return String(path)
	return ""


func _as_vector2(value: Variant) -> Vector2:
	assert_true(value is Vector2, "测试观察值应为 Vector2。")
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	return Vector2.ZERO


func _as_vector3(value: Variant) -> Vector3:
	assert_true(value is Vector3, "测试观察值应为 Vector3。")
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


func _as_vector2i(value: Variant) -> Vector2i:
	assert_true(value is Vector2i, "测试观察值应为 Vector2i。")
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	return Vector2i.ZERO


func _as_color(value: Variant) -> Color:
	assert_true(value is Color, "测试观察值应为 Color。")
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT


func _as_node_path(value: Variant) -> NodePath:
	assert_true(value is NodePath, "测试观察值应为 NodePath。")
	if value is NodePath:
		var path: NodePath = value
		return path
	return NodePath()


func _as_packed_string_array(value: Variant) -> PackedStringArray:
	assert_true(value is PackedStringArray, "测试观察值应为 PackedStringArray。")
	if value is PackedStringArray:
		var array: PackedStringArray = value
		return array
	return PackedStringArray()


func _as_packed_vector2_array(value: Variant) -> PackedVector2Array:
	assert_true(value is PackedVector2Array, "测试观察值应为 PackedVector2Array。")
	if value is PackedVector2Array:
		var array: PackedVector2Array = value
		return array
	return PackedVector2Array()


func _as_packed_int64_array(value: Variant) -> PackedInt64Array:
	assert_true(value is PackedInt64Array, "测试观察值应为 PackedInt64Array。")
	if value is PackedInt64Array:
		var array: PackedInt64Array = value
		return array
	return PackedInt64Array()


func _as_packed_float32_array(value: Variant) -> PackedFloat32Array:
	assert_true(value is PackedFloat32Array, "测试观察值应为 PackedFloat32Array。")
	if value is PackedFloat32Array:
		var array: PackedFloat32Array = value
		return array
	return PackedFloat32Array()


func _as_resource(value: Variant) -> Resource:
	assert_true(value is Resource, "测试观察值应为 Resource。")
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _as_node(value: Variant) -> Node:
	assert_true(value is Node, "测试观察值应为 Node。")
	if value is Node:
		var node: Node = value
		return node
	return null


func _replace_first_packed_value(value: Variant) -> Variant:
	if value is PackedByteArray:
		var packed_bytes: PackedByteArray = value
		packed_bytes[0] = 2
		return packed_bytes
	if value is PackedInt32Array:
		var packed_int32: PackedInt32Array = value
		packed_int32[0] = 2
		return packed_int32
	if value is PackedInt64Array:
		var packed_int64: PackedInt64Array = value
		packed_int64[0] = 2
		return packed_int64
	if value is PackedFloat32Array:
		var packed_float32: PackedFloat32Array = value
		packed_float32[0] = 2.0
		return packed_float32
	if value is PackedFloat64Array:
		var packed_float64: PackedFloat64Array = value
		packed_float64[0] = 2.0
		return packed_float64
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		packed_strings[0] = "copy"
		return packed_strings
	if value is PackedVector2Array:
		var packed_vector2: PackedVector2Array = value
		packed_vector2[0] = Vector2.ZERO
		return packed_vector2
	if value is PackedVector3Array:
		var packed_vector3: PackedVector3Array = value
		packed_vector3[0] = Vector3.ZERO
		return packed_vector3
	if value is PackedVector4Array:
		var packed_vector4: PackedVector4Array = value
		packed_vector4[0] = Vector4.ZERO
		return packed_vector4
	if value is PackedColorArray:
		var packed_colors: PackedColorArray = value
		packed_colors[0] = Color.BLACK
		return packed_colors
	return value


func _packed_values_equal(left: Variant, right: Variant) -> bool:
	if left is PackedByteArray and right is PackedByteArray:
		var left_bytes: PackedByteArray = left
		var right_bytes: PackedByteArray = right
		return left_bytes == right_bytes
	if left is PackedInt32Array and right is PackedInt32Array:
		var left_int32: PackedInt32Array = left
		var right_int32: PackedInt32Array = right
		return left_int32 == right_int32
	if left is PackedInt64Array and right is PackedInt64Array:
		var left_int64: PackedInt64Array = left
		var right_int64: PackedInt64Array = right
		return left_int64 == right_int64
	if left is PackedFloat32Array and right is PackedFloat32Array:
		var left_float32: PackedFloat32Array = left
		var right_float32: PackedFloat32Array = right
		return left_float32 == right_float32
	if left is PackedFloat64Array and right is PackedFloat64Array:
		var left_float64: PackedFloat64Array = left
		var right_float64: PackedFloat64Array = right
		return left_float64 == right_float64
	if left is PackedStringArray and right is PackedStringArray:
		var left_strings: PackedStringArray = left
		var right_strings: PackedStringArray = right
		return left_strings == right_strings
	if left is PackedVector2Array and right is PackedVector2Array:
		var left_vector2: PackedVector2Array = left
		var right_vector2: PackedVector2Array = right
		return left_vector2 == right_vector2
	if left is PackedVector3Array and right is PackedVector3Array:
		var left_vector3: PackedVector3Array = left
		var right_vector3: PackedVector3Array = right
		return left_vector3 == right_vector3
	if left is PackedVector4Array and right is PackedVector4Array:
		var left_vector4: PackedVector4Array = left
		var right_vector4: PackedVector4Array = right
		return left_vector4 == right_vector4
	if left is PackedColorArray and right is PackedColorArray:
		var left_colors: PackedColorArray = left
		var right_colors: PackedColorArray = right
		return left_colors == right_colors
	return false
