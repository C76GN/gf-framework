## 测试 GFDeterministicVariantSerializer 的稳定排序、类型标记和 hash 行为。
extends GutTest


# --- 常量 ---

const GF_DETERMINISTIC_VARIANT_SERIALIZER = preload("res://addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd")


# --- 测试 ---

func test_mixed_dictionary_keys_have_golden_json_and_hash() -> void:
	var source: Dictionary = {}
	source[2] = "two"
	source["1"] = "one"
	source[&"one"] = "string-name"
	var expected_json: String = (
		"{\"__gf_deterministic_variant__\":{\"type\":\"Dictionary\",\"value\":["
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"Int\",\"value\":\"2\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"two\",\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"1\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"one\",\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"StringName\",\"value\":\"one\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"string-name\",\"version\":1}}}"
		+ "],\"version\":1}}"
	)

	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source),
		expected_json,
		"混合 key 类型的排序和类型标记应有固定 JSON golden。"
	)
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source),
		"37199f3647a74c40f4cfe1a20f20426e8db94587cdbb86c0f541ce5990e2f510",
		"混合 key 类型的 canonical hash 应固定。"
	)


func test_packed_array_and_fixed_state_have_golden_json_bytes_and_hash() -> void:
	var fixed_decimal: GFFixedDecimal = GFFixedDecimal.from_string("1.50", 2)
	var source: Dictionary = {
		"packed": PackedByteArray([0, 255]),
		"fixed": fixed_decimal.to_dict(),
	}
	var expected_json: String = (
		"{\"__gf_deterministic_variant__\":{\"type\":\"Dictionary\",\"value\":["
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"fixed\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"Dictionary\",\"value\":["
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"decimal_places\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"Int\",\"value\":\"2\",\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"raw_value\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"150\",\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"type\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"gf.fixed_decimal\",\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"version\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"Int\",\"value\":\"1\",\"version\":1}}}"
		+ "],\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"packed\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"PackedByteArray\",\"value\":[\"0\",\"255\"],\"version\":1}}}"
		+ "],\"version\":1}}"
	)

	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source),
		expected_json,
		"定点状态字典和 PackedByteArray 应有固定 JSON golden。"
	)
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(source).hex_encode(),
		expected_json.to_utf8_buffer().hex_encode(),
		"规范 bytes 应固定为规范 JSON 的 UTF-8。"
	)
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source),
		"05f831a042b1f6ca2760ab5f3b6360717dc2bb68ee715e9690870924cd36f632",
		"定点状态字典和 PackedByteArray 的 canonical hash 应固定。"
	)


func test_allow_floats_has_golden_json_and_hash() -> void:
	var source: Dictionary = {
		"zero": -0.0,
		"vector": Vector2(1.5, -2.25),
	}
	var options: Dictionary = {
		"allow_floats": true,
	}
	var expected_json: String = (
		"{\"__gf_deterministic_variant__\":{\"type\":\"Dictionary\",\"value\":["
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"vector\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"Vector2\",\"value\":[\"ieee754le:000000000000f83f\",\"ieee754le:00000000000002c0\"],\"version\":1}}},"
		+ "{\"key\":{\"__gf_deterministic_variant__\":{\"type\":\"String\",\"value\":\"zero\",\"version\":1}},\"value\":{\"__gf_deterministic_variant__\":{\"type\":\"Float\",\"value\":\"ieee754le:0000000000000000\",\"version\":1}}}"
		+ "],\"version\":1}}"
	)

	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source, options),
		expected_json,
		"显式允许浮点时有限 float 和 Vector2 应有固定 JSON golden。"
	)
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source, options),
		"ff2ea02d71d2f893b464740387abc91b093cf9fd4bde3bec40a90d7a519e8c4c",
		"显式允许浮点时 canonical hash 应固定。"
	)


func test_dictionary_order_is_canonical_recursively() -> void:
	var left: Dictionary = {
		"b": {
			"y": 2,
			"x": 1,
		},
		"a": [3, 2, 1],
	}
	var right: Dictionary = {
		"a": [3, 2, 1],
		"b": {
			"x": 1,
			"y": 2,
		},
	}

	var left_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(left)
	var right_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(right)

	assert_false(left_json.is_empty(), "规范 JSON 不应为空。")
	assert_eq(left_json, right_json, "同一份数据不应受 Dictionary 插入顺序影响。")
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(left),
		GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(right),
		"规范 bytes 应与 JSON 排序契约一致。"
	)


func test_dictionary_key_types_do_not_collapse_to_plain_strings() -> void:
	var source: Dictionary = {
		1: "int-key",
		"1": "string-key",
		&"tag": "string-name-key",
		Vector2i(2, 3): "vector-key",
	}

	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source)

	assert_true(text.contains("\"type\":\"Int\""), "int key 应保留类型标记。")
	assert_true(text.contains("\"type\":\"String\""), "String key 应保留类型标记。")
	assert_true(text.contains("\"type\":\"StringName\""), "StringName key 应保留类型标记。")
	assert_true(text.contains("\"type\":\"Vector2i\""), "Vector2i key 应保留类型标记。")


func test_fixed_numeric_state_dictionaries_hash_stably() -> void:
	var fixed_decimal: GFFixedDecimal = GFFixedDecimal.from_string("12.340", 3)
	var fixed_vector: GFFixedVector2 = GFFixedVector2.from_decimal_strings("1.25", "-3.50", 2)
	var left: Dictionary = {
		"vector": fixed_vector.to_dict(),
		"decimal": fixed_decimal.to_dict(),
	}
	var right: Dictionary = {
		"decimal": {
			"decimal_places": 3,
			"raw_value": "12340",
			"type": "gf.fixed_decimal",
			"version": 1,
		},
		"vector": {
			"decimal_places": 2,
			"raw_y": "-350",
			"raw_x": "125",
			"version": 1,
			"type": "gf.fixed_vector2",
		},
	}

	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(left),
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(right),
		"定点类型的 to_dict() 状态应可通过通用 canonical hash 稳定比较。"
	)


func test_hash_is_sha256_of_canonical_bytes() -> void:
	var source: Dictionary = {
		"state": PackedInt64Array([9_223_372_036_854_775_000, -9_223_372_036_854_775_000]),
		"seed": 42,
	}

	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source)
	var bytes: PackedByteArray = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(source)
	var hash_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source)

	assert_eq(bytes.get_string_from_utf8(), text, "规范 bytes 应直接来自规范 JSON 的 UTF-8。")
	assert_eq(hash_text.length(), 64, "SHA-256 hex 长度应固定为 64。")
	assert_true(hash_text.is_valid_hex_number(), "SHA-256 应输出 hex 文本。")


func test_float_values_are_rejected_by_default() -> void:
	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1.25)

	assert_eq(text, "", "默认不应把 float 纳入 deterministic 真值。")
	assert_push_error("[GFDeterministicVariantSerializer] 浮点值默认不参与确定性编码；请先使用定点数，或显式设置 allow_floats。")


func test_finite_floats_can_be_enabled_and_negative_zero_is_normalized() -> void:
	var positive_zero: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(0.0, {
		"allow_floats": true,
	})
	var negative_zero: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(-0.0, {
		"allow_floats": true,
	})
	var vector_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(Vector2(1.5, -2.25), {
		"allow_floats": true,
	})

	assert_eq(positive_zero, negative_zero, "正负零应归一为同一 canonical float。")
	assert_false(vector_text.is_empty(), "显式允许后可编码有限浮点向量。")
	assert_true(vector_text.contains("\"type\":\"Vector2\""), "浮点向量应保留类型标记。")


func test_projection_has_stable_canonical_encoding_when_floats_are_enabled() -> void:
	var projection: Projection = Projection.create_perspective(
		1.2,
		16.0 / 9.0,
		0.1,
		100.0
	)
	var options: Dictionary = {"allow_floats": true}
	var first_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(
		projection,
		options
	)
	var second_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(
		projection,
		options
	)

	assert_false(first_text.is_empty(), "有限 Projection 应能进入 canonical 编码。")
	assert_true(first_text.contains("\"type\":\"Projection\""), "Projection 应保留类型标记。")
	assert_eq(first_text, second_text, "相同 Projection 的 canonical 文本必须稳定。")
	assert_eq(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(projection, options),
		first_text.sha256_text(),
		"Projection hash 应来自同一份 canonical UTF-8 文本。"
	)


func test_adjacent_float_values_have_distinct_canonical_encodings() -> void:
	var options: Dictionary = {
		"allow_floats": true,
	}
	var lower_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1.0, options)
	var upper_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1.0000000000000002, options)
	var lower_packed_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(
		PackedFloat64Array([1.0]),
		options
	)
	var upper_packed_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(
		PackedFloat64Array([1.0000000000000002]),
		options
	)

	assert_ne(lower_json, upper_json, "相邻可观察 float 不得碰撞到同一 canonical 文本。")
	assert_ne(lower_packed_json, upper_packed_json, "PackedFloat64Array 也必须保留完整浮点位模式。")
	assert_ne(
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(1.0, options),
		GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(1.0000000000000002, options),
		"相邻 float 的 canonical hash 必须不同。"
	)


func test_nonfinite_float_is_rejected_even_when_float_option_is_enabled() -> void:
	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(INF, {
		"allow_floats": true,
	})

	assert_eq(text, "", "NaN/Inf 永远不应进入 canonical 编码。")
	assert_push_error("[GFDeterministicVariantSerializer] 浮点值不能是 NaN 或 Inf。")


func test_max_depth_rejects_too_deep_structures() -> void:
	var source: Dictionary = {
		"outer": {
			"inner": 1,
		},
	}

	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source, {
		"max_depth": 1,
	})

	assert_eq(text, "", "超过 max_depth 的结构不应被编码。")
	assert_push_error("[GFDeterministicVariantSerializer] 输入结构超过 max_depth。")


func test_resource_budgets_reject_wide_long_and_oversized_output() -> void:
	var wide_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json([1, 2], {
		"max_items": 2,
	})
	assert_eq(wide_text, "", "超过 max_items 的宽结构应失败。")
	assert_push_error("[GFDeterministicVariantSerializer] 输入集合超过 max_items。")

	var long_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json("abcd", {
		"max_string_length": 3,
	})
	assert_eq(long_text, "", "超过 max_string_length 的文本应失败。")
	assert_push_error("[GFDeterministicVariantSerializer] 字符串超过 max_string_length。")

	var oversized_output: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1, {
		"max_output_bytes": 8,
	})
	assert_eq(oversized_output, "", "超过 max_output_bytes 的规范输出应失败。")
	assert_push_error("[GFDeterministicVariantSerializer] 规范输出超过 max_output_bytes。")


func test_objects_and_circular_references_are_rejected() -> void:
	var object_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(Resource.new())
	assert_eq(object_text, "", "Object/Resource 不应被通用 serializer 隐式反射。")
	assert_push_error("[GFDeterministicVariantSerializer] 不支持的 Variant 类型：Object。")

	var source: Dictionary = {}
	source["self"] = source
	var circular_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source)

	assert_eq(circular_text, "", "循环引用不应被静默编码。")
	assert_push_error("[GFDeterministicVariantSerializer] 输入包含循环 Dictionary 引用。")
