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
	assert_eq(hash_text, text.sha256_text(), "规范 hash 必须等于完整 canonical UTF-8 的 SHA-256。")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256_incremental(source), hash_text, "两种资源策略必须生成同一摘要。")
	assert_eq(hash_text.length(), 64, "SHA-256 hex 长度应固定为 64。")
	assert_true(hash_text.is_valid_hex_number(), "SHA-256 应输出 hex 文本。")


func test_float_values_are_rejected_by_default() -> void:
	var text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1.25)

	assert_eq(text, "", "默认不应把 float 纳入 deterministic 真值。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Floating-point values are excluded from deterministic encoding by default; use fixed-point numbers or explicitly enable allow_floats..")


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
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Floating-point values must not be NaN or Inf..")


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
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Input structure exceeds max_depth..")


func test_resource_budgets_reject_wide_long_and_oversized_output() -> void:
	var wide_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json([1, 2], {
		"max_items": 2,
	})
	assert_eq(wide_text, "", "超过 max_items 的宽结构应失败。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Input collection exceeds max_items..")

	var long_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json("abcd", {
		"max_string_length": 3,
	})
	assert_eq(long_text, "", "超过 max_string_length 的文本应失败。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: String exceeds max_string_length..")

	var oversized_output: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(1, {
		"max_output_bytes": 8,
	})
	assert_eq(oversized_output, "", "超过 max_output_bytes 的规范输出应失败。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")


func test_max_output_bytes_applies_only_to_encoded_output_entries() -> void:
	var canonical_value: Variant = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_value(
		"payload",
		{"max_output_bytes": 1}
	)
	var canonical_json: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(
		"payload",
		{"max_output_bytes": 1}
	)

	assert_true(canonical_value != null, "canonical value 没有唯一 bytes 表示，不应伪装执行输出字节预算。")
	assert_eq(canonical_json, "", "产生规范 bytes 的入口必须执行 max_output_bytes。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")


func test_objects_and_circular_references_are_rejected() -> void:
	var object_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(Resource.new())
	assert_eq(object_text, "", "Object/Resource 不应被通用 serializer 隐式反射。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Unsupported Variant type: Object..")

	var source: Dictionary = {}
	source["self"] = source
	var circular_text: String = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(source)

	assert_eq(circular_text, "", "循环引用不应被静默编码。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Input contains a cyclic Dictionary reference..")
	source.clear()


func test_streaming_matches_typed_encoding_for_every_supported_variant_type() -> void:
	var minimum_integer: int = -9_223_372_036_854_775_807 - 1
	var shared: Array = [1, {"shared": true}]
	var compound_keys: Dictionary = {}
	compound_keys[["array", 2]] = "array-key"
	compound_keys[{"z": 2, "a": 1}] = "dictionary-key"
	compound_keys[PackedInt64Array([2, 1])] = "packed-key"
	compound_keys[NodePath("root/child:property")] = "path-key"
	var source: Array = [
		null, true, false, minimum_integer, 9_223_372_036_854_775_807,
		"", "汉字😀é\"\\/\n\r\t" + String.chr(1),
		&"标签", NodePath("root/child:property"),
		0.0, -0.0, 1.0000000000000002, 5e-324, 1.7976931348623157e308,
		Vector2(1.5, -2.25), Vector2i(-2, 3),
		Vector3(1, 2, 3), Vector3i(-2, 3, 4),
		Vector4(1, 2, 3, 4), Vector4i(-2, 3, 4, 5),
		Rect2(-1, 2, 3, 4), Rect2i(-1, 2, 3, 4),
		Color(0.25, 0.5, 0.75, 1), Plane(Vector3.UP, 2.5),
		Quaternion(0.1, 0.2, 0.3, 0.4), AABB(Vector3(-1, 2, 3), Vector3(4, 5, 6)),
		Basis(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9)),
		Transform2D(0.5, Vector2(2, 3)), Transform3D(Basis.IDENTITY, Vector3(2, 3, 4)),
		Projection.IDENTITY, [], {}, compound_keys, shared, shared,
		PackedByteArray([0, 1, 255]), PackedInt32Array([-2147483648, 2147483647]),
		PackedInt64Array([minimum_integer, 9_223_372_036_854_775_807]),
		PackedFloat32Array([-0.0, 1.5, -2.25]), PackedFloat64Array([5e-324, 1.0000000000000002]),
		PackedStringArray(["", "汉😀\n\"\\", String.chr(1)]),
		PackedVector2Array([Vector2(1, 2), Vector2(-3, 4)]),
		PackedVector3Array([Vector3(1, 2, 3)]),
		PackedColorArray([Color(0.25, 0.5, 0.75, 1)]),
		PackedVector4Array([Vector4(1, 2, 3, 4)]),
		PackedByteArray(), PackedInt32Array(), PackedInt64Array(),
		PackedFloat32Array(), PackedFloat64Array(), PackedStringArray(),
		PackedVector2Array(), PackedVector3Array(), PackedColorArray(), PackedVector4Array(),
	]
	_assert_matches_typed_oracle(source, {"allow_floats": true})


func test_string_escape_and_hash_chunk_boundaries_match_the_typed_oracle() -> void:
	var boundary_text: String = "a".repeat(4095) + "😀汉\"\\\n" + "z".repeat(4097)
	var packed: PackedInt64Array = PackedInt64Array()
	for index: int in 5000:
		var _append_result: bool = packed.append(9_223_372_036_854_770_000 + index)
	var source: Dictionary = {
		boundary_text: PackedStringArray([
			boundary_text, "汉😀".repeat(4097), "\"".repeat(4096),
			String.chr(1).repeat(4096), "尾",
		]),
		"packed": packed,
	}
	_assert_matches_typed_oracle(source)
	var report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(source)
	assert_gt(GFVariantData.get_option_int(report, "output_bytes"), 64 * 1024, "样本必须跨越多个 hash 缓冲。")


func test_measure_reports_exact_utf8_bytes_and_historic_packed_item_counts() -> void:
	var source: Dictionary = {"packed": PackedStringArray(["汉", "😀"])}
	var report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(source)
	var expected_json: String = JSON.stringify(GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_value(source), "", true)
	assert_eq(report, {
		"ok": true,
		"error": "",
		"failure_kind": "",
		"items": 5,
		"packed_items": 2,
		"output_bytes": expected_json.to_utf8_buffer().size(),
	}, "闭合报告应计入根、key、packed 容器和两个元素。")
	var exact_options: Dictionary = {
		"max_items": 5,
		"max_string_length": 6,
		"max_output_bytes": GFVariantData.get_option_int(report, "output_bytes"),
	}
	_assert_matches_typed_oracle(source, exact_options)
	exact_options["max_output_bytes"] = GFVariantData.get_option_int(report, "output_bytes") - 1
	var rejected: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(source, exact_options)
	assert_false(GFVariantData.get_option_bool(rejected, "ok", true), "少一个 UTF-8 字节必须失败。")
	assert_eq(GFVariantData.get_option_string(rejected, "failure_kind"), "output_limit")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source, exact_options), "", "失败不能发布部分 hash。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256_incremental(source, exact_options), "", "增量策略也不能发布部分 hash。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(source, exact_options), PackedByteArray(), "失败不能发布部分 bytes。")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.output_limit] Canonical output exceeds max_output_bytes.")


func test_measure_checks_packed_budget_before_expansion_and_preserves_composite_counts() -> void:
	var packed: PackedInt64Array = PackedInt64Array()
	var _resize_error: Error = packed.resize(50_000) as Error
	var rejected: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(packed, {"max_items": 3})
	assert_false(GFVariantData.get_option_bool(rejected, "ok", true))
	assert_eq(GFVariantData.get_option_string(rejected, "failure_kind"), "input_invalid")
	assert_eq(GFVariantData.get_option_int(rejected, "items"), 1, "packed 整批计数失败前只消费根节点。")
	assert_eq(GFVariantData.get_option_int(rejected, "packed_items"), 0)
	assert_eq(GFVariantData.get_option_int(rejected, "output_bytes"), 0, "不能展开或编码超过输入预算的 packed 元素。")
	var vector_report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(
		PackedVector3Array([Vector3.ONE, Vector3.ZERO]), {"allow_floats": true, "max_items": 3}
	)
	assert_true(GFVariantData.get_option_bool(vector_report, "ok"))
	assert_eq(GFVariantData.get_option_int(vector_report, "items"), 3, "packed 分量不单独消费元素预算。")
	assert_eq(GFVariantData.get_option_int(vector_report, "packed_items"), 2)
	var transform_report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(
		Transform3D.IDENTITY, {"allow_floats": true, "max_items": 2, "max_depth": 1}
	)
	assert_true(GFVariantData.get_option_bool(transform_report, "ok"))
	assert_eq(GFVariantData.get_option_int(transform_report, "items"), 2, "Transform3D 只额外计入 basis 节点。")
	var late_nonfinite: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(
		PackedFloat64Array([1.0, INF]), {"allow_floats": true, "max_output_bytes": 1}
	)
	assert_eq(GFVariantData.get_option_string(late_nonfinite, "failure_kind"), "input_invalid", "packed 输出饱和后仍须校验后续浮点输入。")
	assert_eq(GFVariantData.get_option_string(late_nonfinite, "error"), "Floating-point values must not be NaN or Inf.")
	var late_string: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(
		PackedStringArray(["ok", "long"]), {"max_string_length": 2, "max_output_bytes": 1}
	)
	assert_eq(GFVariantData.get_option_string(late_string, "failure_kind"), "input_invalid", "packed 输出饱和后仍须校验后续字符串预算。")


func test_measure_is_quiet_and_input_errors_precede_output_limit() -> void:
	var source: Array = ["x".repeat(100), Resource.new()]
	var options: Dictionary = {"max_output_bytes": 1}
	var report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(source, options)
	assert_eq(GFVariantData.get_option_string(report, "failure_kind"), "input_invalid", "输出已超限仍应完成输入验证。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "Unsupported Variant type: Object.")
	assert_eq(GFVariantData.get_option_int(report, "items"), 3)
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(source, options), "")
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Unsupported Variant type: Object..")
	var nested: Array = [[1]]
	assert_false(GFVariantData.get_option_bool(GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(nested, {"max_depth": 1}), "ok", true))
	assert_false(GFVariantData.get_option_bool(GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical("汉😀", {"max_string_length": 1}), "ok", true))
	assert_true(GFVariantData.get_option_bool(GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical("汉😀", {"max_string_length": 2}), "ok"), "字符串预算计字符而非 UTF-8 字节。")
	assert_false(GFVariantData.get_option_bool(GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(NAN, {"allow_floats": true}), "ok", true))
	var cycle: Array = []
	cycle.append(cycle)
	assert_false(GFVariantData.get_option_bool(GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(cycle), "ok", true))
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(cycle), PackedByteArray())
	assert_push_error("[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: Input contains a cyclic Array reference..")
	cycle.clear()


func test_hash_resource_strategies_share_input_limits_and_error_priority() -> void:
	var cases: Array[Dictionary] = [
		{"value": 1.25, "options": {}, "message": "Floating-point values are excluded from deterministic encoding by default; use fixed-point numbers or explicitly enable allow_floats."},
		{"value": PackedFloat64Array([1.0, INF]), "options": {"allow_floats": true, "max_output_bytes": 1}, "message": "Floating-point values must not be NaN or Inf."},
		{"value": ["x".repeat(100), Resource.new()], "options": {"max_output_bytes": 1}, "message": "Unsupported Variant type: Object."},
		{"value": PackedByteArray([1, 2]), "options": {"max_items": 2}, "message": "Input collection exceeds max_items."},
		{"value": [[1]], "options": {"max_depth": 1}, "message": "Input structure exceeds max_depth."},
		{"value": PackedStringArray(["ok", "long"]), "options": {"max_string_length": 2, "max_output_bytes": 1}, "message": "String exceeds max_string_length."},
	]
	for fixture: Dictionary in cases:
		var value: Variant = GFVariantData.get_option_value(fixture, "value")
		var options: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(fixture, "options"))
		var message: String = "[GFDeterministicVariantSerializer][deterministic_variant_serializer.serialization_failed] Serialization failed: %s." % GFVariantData.get_option_string(fixture, "message")
		assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(value, options), "", "快速策略应拒绝不合格输入。")
		assert_push_error(message)
		assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256_incremental(value, options), "", "增量策略应以同一错误拒绝输入。")
		assert_push_error(message)


# --- 辅助方法 ---

func _assert_matches_typed_oracle(value: Variant, options: Dictionary = {}) -> void:
	var canonical_value: Variant = GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_value(value, options)
	assert_true(canonical_value != null, "等价性样本必须可编码。")
	var expected_json: String = JSON.stringify(canonical_value, "", true)
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_json(value, options), expected_json, "流式 JSON 必须逐字节保留 typed tree 的格式。")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.to_canonical_bytes(value, options), expected_json.to_utf8_buffer(), "流式 bytes 必须逐字节相等。")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256(value, options), expected_json.sha256_text(), "快速策略必须来自同一字节协议。")
	assert_eq(GF_DETERMINISTIC_VARIANT_SERIALIZER.sha256_incremental(value, options), expected_json.sha256_text(), "增量策略必须逐字节保留同一摘要协议。")
	var report: Dictionary = GF_DETERMINISTIC_VARIANT_SERIALIZER.measure_canonical(value, options)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_int(report, "output_bytes"), expected_json.to_utf8_buffer().size(), "测量结果必须是精确 UTF-8 字节数。")
