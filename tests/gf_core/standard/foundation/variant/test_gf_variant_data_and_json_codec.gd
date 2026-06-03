## 测试 GFVariantData 与 GFVariantJsonCodec 的通用 Variant 行为。
extends GutTest


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


func test_duplicate_variant_can_optionally_duplicate_resources() -> void:
	var resource: Resource = Resource.new()

	assert_same(_as_resource(GFVariantData.duplicate_variant(resource)), resource, "默认应保留 Resource 引用。")
	assert_ne(_as_resource(GFVariantData.duplicate_variant(resource, true, true)), resource, "显式要求时应复制 Resource。")


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


func test_json_compatible_codec_decodes_malformed_typed_marker_values_safely() -> void:
	var marker: Dictionary = {
		GFVariantJsonCodec.JSON_MARKER_KEY: {
			GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
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


func test_reference_codec_roundtrips_resource_reference() -> void:
	var resource_path: String = "user://gf_variant_reference_codec_resource.tres"
	var resource: Resource = Resource.new()
	resource.resource_name = "ReferenceCodecResource"
	assert_eq(ResourceSaver.save(resource, resource_path), OK, "测试 Resource 应能保存。")
	var loaded_resource: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	var encoded: Dictionary = GFVariantReferenceCodec.encode_reference(loaded_resource)
	var marker: Dictionary = GFVariantReferenceCodec.get_reference_marker(encoded)
	var json_encoded: Dictionary = _as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var result: Dictionary = GFVariantReferenceCodec.decode_reference(json_encoded)
	var decoded_resource: Resource = _as_resource(GFVariantData.get_option_value(result, "value"))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "Resource 引用标记应能经 JSON 往返后恢复。")
	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_KIND_KEY), GFVariantReferenceCodec.REFERENCE_KIND_RESOURCE, "Resource 引用应标记类型。")
	assert_eq(GFVariantData.get_option_string(marker, GFVariantReferenceCodec.REFERENCE_PATH_KEY), resource_path, "Resource 引用应保留路径。")
	assert_eq(decoded_resource.resource_path, resource_path, "Resource 应按路径或 UID 恢复。")

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if FileAccess.file_exists(resource_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)


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
