## 验证独立确定性 JSON 的字节协议、类型往返与失败原子性。
extends GutTest


func test_null_has_versioned_golden_text() -> void:
	var report: Dictionary = GFVariantJsonCodec.encode_deterministic_result(null)
	assert_true(
		_equal_values(
			report.get("ok", false),
			true
		)
	)
	assert_true(
		_equal_values(
			report.get("text"),
			"{\n  \"format\": \"gf.variant-json-deterministic\",\n  \"version\": 1,\n  \"value\": [\"Nil\"]\n}\n"
		)
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(report))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		)
	)
	assert_true((decoded.get("value") == null))


func test_dictionary_order_and_key_types_are_deterministic() -> void:
	var first: Dictionary = {
		"z": 7,
		1: "integer",
		"1": "string",
		Vector2.ONE: "vector",
	}
	var second: Dictionary = {
		Vector2.ONE: "vector",
		"1": "string",
		1: "integer",
		"z": 7,
	}
	var a: Dictionary = GFVariantJsonCodec.encode_deterministic_result(first)
	var b: Dictionary = GFVariantJsonCodec.encode_deterministic_result(second)
	assert_true(
		_equal_values(
			a.get("ok", false),
			true
		)
	)
	assert_true(
		_equal_values(
			b.get("ok", false),
			true
		)
	)
	assert_true((_text(a) == _text(b)))
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(a))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		)
	)
	assert_true(
		_equal_values(
			decoded.get("value"),
			first
		)
	)


func test_integer_float_and_typed_containers_survive_text() -> void:
	var typed: Array[int] = [
		1,
		-9223372036854775807 - 1,
		9223372036854775807,
	]
	var mapping: Dictionary[StringName, Vector2] = { &"point": Vector2.ONE }
	var values: Array = [
		typed,
		mapping,
		1,
		1.0,
		Projection.IDENTITY,
		PackedInt64Array(typed),
	]
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(values)
	assert_true(
		_equal_values(
			encoded.get("ok", false),
			true
		)
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		)
	)
	if decoded.get("value") is Array:
		var restored: Array = decoded["value"]
		assert_true((restored.size() == values.size()))
		var restored_array: Array = restored[0]
		var restored_dictionary: Dictionary = restored[1]
		assert_true((restored_array.get_typed_builtin() == TYPE_INT))
		assert_true((restored_dictionary.get_typed_key_builtin() == TYPE_STRING_NAME))
		assert_true((restored_dictionary.get_typed_value_builtin() == TYPE_VECTOR2))
		assert_true((typeof(restored[2]) == TYPE_INT))
		assert_true((typeof(restored[3]) == TYPE_FLOAT))
		assert_true((restored == values))
	else:
		fail_test("Decoder must return an Array.")


func test_output_limit_and_cycles_publish_no_text() -> void:
	var limited: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		"abcdef",
		{ "max_output_bytes": 5 }
	)
	assert_false(
		_equal_values(
			limited.get("ok", true),
			true
		)
	)
	assert_true(
		_equal_values(
			limited.get("error_kind"),
			"limit_exceeded"
		)
	)
	assert_true((_text(limited) == ""))
	var cycle: Array = []
	cycle.append(cycle)
	var rejected: Dictionary = GFVariantJsonCodec.encode_deterministic_result(cycle)
	cycle.clear()
	assert_false(
		_equal_values(
			rejected.get("ok", true),
			true
		)
	)
	assert_true(
		_equal_values(
			rejected.get("error_kind"),
			"cycle"
		)
	)
	assert_true((_text(rejected) == ""))


func test_all_math_and_packed_types_roundtrip() -> void:
	var values: Array = [
		true,
		false,
		-7,
		0,
		1.25,
		&"type",
		NodePath("../child:position"),
		Vector2(1.25, -2.5),
		Vector2i(-2147483648, 2147483647),
		Vector3.ONE,
		Vector3i.ONE,
		Vector4.ONE,
		Vector4i.ONE,
		Rect2(
			1,
			2,
			3,
			4
		),
		Rect2i(
			1,
			2,
			3,
			4
		),
		Color(
			0.1,
			0.2,
			0.3,
			0.4
		),
		Plane(Vector3.UP, 2.5),
		Quaternion(
			1,
			2,
			3,
			4
		),
		AABB(
			Vector3.ONE,
			Vector3(
				2,
				3,
				4
			)
		),
		Basis.IDENTITY,
		Transform2D.IDENTITY,
		Transform3D.IDENTITY,
		Projection.IDENTITY,
		PackedByteArray([0, 255]),
		PackedInt32Array([-2147483648, 2147483647]),
		PackedInt64Array([-9223372036854775807 - 1, 9223372036854775807]),
		PackedFloat32Array([0.1, -1.5]),
		PackedFloat64Array([0.1, 1.0e100]),
		PackedStringArray(["汉", "😀"]),
		PackedVector2Array([Vector2.ONE]),
		PackedVector3Array([Vector3.ONE]),
		PackedVector4Array([Vector4.ONE]),
		PackedColorArray([Color.WHITE]),
	]
	for value: Variant in values:
		var decoded: Variant = _roundtrip(value)
		assert_true((typeof(decoded) == typeof(value)))
		assert_true(_equal_values(decoded, value))


func test_float_edges_and_special_values_are_stable() -> void:
	var bits: PackedByteArray = PackedByteArray()
	var _resized: int = bits.resize(8)
	bits.encode_double(0, 1.0)
	bits[0] = 1
	var adjacent: float = bits.decode_double(0)
	bits.fill(0)
	bits[0] = 1
	var subnormal: float = bits.decode_double(0)
	for value: float in [
		0.1,
		1.0,
		adjacent,
		subnormal,
		1.7976931348623157e308,
		1.0e-100,
	]:
		var restored: Variant = _roundtrip(value)
		assert_true((typeof(restored) == TYPE_FLOAT))
		assert_true(_equal_values(restored, value))
	assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(1.0)) != _text(GFVariantJsonCodec.encode_deterministic_result(adjacent))))
	assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(-0.0)) == _text(GFVariantJsonCodec.encode_deterministic_result(0.0))))
	for value: Variant in [
		NAN,
		INF,
		-INF,
		Vector2(NAN, INF),
		PackedFloat32Array([NAN, -INF]),
	]:
		var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(value)
		var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
		assert_true(
			_equal_values(
				encoded.get("ok", false),
				true
			),
			str(encoded)
		)
		assert_true(
			_equal_values(
				decoded.get("ok", false),
				true
			),
			str(decoded)
		)
		assert_true((typeof(decoded.get("value")) == typeof(value)))
		assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(decoded.get("value"))) == _text(encoded)))


func test_unicode_escapes_and_exact_utf8_limits() -> void:
	var value: String = "a".repeat(4095) + "汉😀" + "\"\\\b\f\n\r\t" + String.chr(1)
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(value)
	var text: String = _text(encoded)
	var bytes: int = text.to_utf8_buffer().size()
	assert_true(
		_equal_values(
			encoded.get("ok", false),
			true
		),
		str(encoded)
	)
	assert_true(
		_equal_values(
			encoded.get("output_bytes"),
			bytes
		)
	)
	assert_true(
		_equal_values(
			_roundtrip(value),
			value
		)
	)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.encode_deterministic_result(
				value,
				{ "max_output_bytes": bytes }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			value,
			{ "max_output_bytes": bytes - 1 }
		),
		"limit_exceeded"
	)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.decode_deterministic_result(
				text,
				{ "max_input_bytes": bytes }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			text,
			{ "max_input_bytes": bytes - 1 }
		),
		"limit_exceeded"
	)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.encode_deterministic_result(
				value,
				{ "max_string_length": value.length() }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			text,
			{ "max_string_length": value.length() - 1 }
		),
		"limit_exceeded"
	)
	var escaped: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_document("[\"String\",\"\\ud83d\\ude00\"]"))
	assert_true(
		_equal_values(
			escaped.get("ok", false),
			true
		),
		str(escaped)
	)
	assert_true(
		_equal_values(
			escaped.get("value"),
			"😀"
		)
	)


func test_aliases_expand_and_marker_shaped_business_data_is_literal() -> void:
	var shared: Array = [1]
	var source: Array = [
		shared,
		shared,
		{
			"format": "gf.variant-json-deterministic",
			"version": 1,
			"value": ["Nil"],
		},
	]
	var restored: Variant = _roundtrip(source)
	if restored is Array:
		assert_false(
			is_same(
				restored[0],
				restored[1]
			)
		)
		assert_false(
			is_same(
				restored[0],
				shared
			)
		)
		assert_true(_equal_values(restored, source))
	else:
		fail_test("Expected Array.")
	assert_true((shared == [1]))


func test_nested_composite_keys_sort_without_losing_types() -> void:
	var first_key: Dictionary = {
		"z": [1, 2],
		"a": 3,
	}
	var second_key: Dictionary = {
		"a": 3,
		"z": [1, 2],
	}
	var first: Dictionary = {
		first_key: "nested",
		[1, "1"]: "array",
		null: "nil",
	}
	var second: Dictionary = {
		null: "nil",
		[1, "1"]: "array",
		second_key: "nested",
	}
	var a: Dictionary = GFVariantJsonCodec.encode_deterministic_result(first)
	var b: Dictionary = GFVariantJsonCodec.encode_deterministic_result(second)
	assert_true(
		_equal_values(
			a.get("ok", false),
			true
		),
		str(a)
	)
	assert_true(
		_equal_values(
			b.get("ok", false),
			true
		),
		str(b)
	)
	assert_true((_text(a) == _text(b)))
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(a))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		),
		str(decoded)
	)
	assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(decoded.get("value"))) == _text(a)))


func test_empty_typed_containers_and_packed_arrays_keep_identity() -> void:
	var typed: Array[StringName] = []
	var mapping: Dictionary[Vector2, Array] = {}
	var values: Array = [
		typed,
		mapping,
		PackedByteArray(),
		PackedFloat64Array(),
		PackedVector4Array(),
	]
	var restored: Variant = _roundtrip(values)
	if restored is Array:
		var array: Array = restored[0]
		var dictionary: Dictionary = restored[1]
		assert_true((array.get_typed_builtin() == TYPE_STRING_NAME))
		assert_true((dictionary.get_typed_key_builtin() == TYPE_VECTOR2))
		assert_true((dictionary.get_typed_value_builtin() == TYPE_ARRAY))
		for index: int in values.size():
			assert_true((typeof(restored[index]) == typeof(values[index])))
	else:
		fail_test("Expected Array.")


func test_live_values_and_object_typed_empty_containers_fail() -> void:
	var objects: Array[RefCounted] = []
	var mapping: Dictionary[Object, int] = {}
	for value: Variant in [
		objects,
		mapping,
		RefCounted.new(),
		Resource.new(),
		Callable(),
		Signal(),
		RID(),
	]:
		_assert_failure(
			GFVariantJsonCodec.encode_deterministic_result(value),
			"unsupported_type"
		)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document("[\"Array\",\"Object\",[]]")),
		"unsupported_type"
	)


func test_items_and_depth_have_exact_boundaries() -> void:
	var source: Array = [
		PackedInt64Array([1, 2]),
		"x",
	]
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		source,
		{ "max_items": 5 }
	)
	assert_true(
		_equal_values(
			encoded.get("ok", false),
			true
		),
		str(encoded)
	)
	assert_true(
		_equal_values(
			encoded.get("items"),
			5
		)
	)
	assert_true(
		_equal_values(
			encoded.get("packed_items"),
			2
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			source,
			{ "max_items": 4 }
		),
		"limit_exceeded"
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(
		_text(encoded),
		{ "max_items": 5 }
	)
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		),
		str(decoded)
	)
	assert_true(
		_equal_values(
			decoded.get("items"),
			5
		)
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			_text(encoded),
			{ "max_items": 4 }
		),
		"limit_exceeded"
	)
	var nested: Variant = null
	for depth: int in 256:
		nested = [nested]
	var deep: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		nested,
		{ "max_depth": 256 }
	)
	assert_true(
		_equal_values(
			deep.get("ok", false),
			true
		),
		str(deep)
	)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.decode_deterministic_result(
				_text(deep),
				{ "max_depth": 256 }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			nested,
			{ "max_depth": 255 }
		),
		"limit_exceeded"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			_text(deep),
			{ "max_depth": 255 }
		),
		"limit_exceeded"
	)


func test_sort_budget_counts_nested_live_workspace() -> void:
	var value: Dictionary = {
		"outer": { "inner": 7 },
		"other": 8,
	}
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(value)
	assert_true(
		_equal_values(
			encoded.get("ok", false),
			true
		),
		str(encoded)
	)
	var peak: int = encoded.get("peak_sort_bytes", 0)
	assert_gt(peak, 0)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.encode_deterministic_result(
				value,
				{ "max_sort_bytes": peak }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			value,
			{ "max_sort_bytes": peak - 1 }
		),
		"limit_exceeded"
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		),
		str(decoded)
	)
	var read_peak: int = decoded.get("peak_sort_bytes", 0)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.decode_deterministic_result(
				_text(encoded),
				{ "max_sort_bytes": read_peak }
			).get("ok", false),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			_text(encoded),
			{ "max_sort_bytes": read_peak - 1 }
		),
		"limit_exceeded"
	)


func test_invalid_options_are_rejected_before_payload_access() -> void:
	for options: Dictionary in [
		{ "max_depth": 0 },
		{ "max_depth": 257 },
		{ "max_items": -1 },
		{ "max_items": 1.0 },
		{ "unknown": true },
		{ 1: 2 },
		{ "cancel_token": "bad" },
	]:
		_assert_failure(
			GFVariantJsonCodec.encode_deterministic_result(null, options),
			"invalid_options"
		)
		_assert_failure(
			GFVariantJsonCodec.decode_deterministic_result("", options),
			"invalid_options"
		)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			null,
			{ "max_input_bytes": 8 }
		),
		"invalid_options"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			"",
			{ "max_output_bytes": 8 }
		),
		"invalid_options"
	)


func test_malformed_numbers_shapes_and_unicode_publish_no_value() -> void:
	var malformed: Array[String] = [
		"[\"Int64\",\"9223372036854775808\"]",
		"[\"Int64\",\"-9223372036854775809\"]",
		"[\"Int64\",\"01\"]",
		"[\"Int64\",\"-0\"]",
		"[\"Int64\",\"1.0\"]",
		"[\"Float64\",\"1e9999\"]",
		"[\"Float64\",\"1e-9999\"]",
		"[\"Float64\",\"+1.0\"]",
		"[\"Vector2\",[\"1.0\"]]",
		"[\"Vector2i\",[\"2147483648\",\"0\"]]",
		"[\"PackedByteArray\",[\"256\"]]",
		"[\"PackedInt32Array\",[\"2147483648\"]]",
		"[\"PackedFloat32Array\",[\"0.1\"]]",
		"[\"Array\",\"Int64\",[[\"Float64\",\"1.0\"]]]",
		"[\"String\",\"\\ud800\"]",
		"[\"String\",\"\\udc00\"]",
		"[\"String\",\"\\u0000\"]",
		"[\"String\",\"\\x00\"]",
		"[\"String\",\"raw\nnewline\"]",
		"[\"Array\",\"Variant\",[[\"Nil\"],]]",
		"[\"Nil\",null]",
		"[\"Unknown\"]",
	]
	for node: String in malformed:
		var result: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_document(node))
		assert_false(
			_equal_values(
				result.get("ok", true),
				true
			),
			node
		)
		assert_true(
			(result.get("value") == null),
			node
		)
		assert_false(
			_equal_values(
				result.get("counts_complete", true),
				true
			),
			node
		)
		assert_true(
			not _equal_values(
				result.get("error_kind", ""),
				""
			),
			node
		)


func test_duplicate_keys_and_envelope_drift_fail() -> void:
	var duplicate_text: String = "[\"Dictionary\",\"Variant\",\"Variant\",[[[\"String\",\"x\"],[\"Nil\"]],[[\"String\",\"\\u0078\"],[\"Nil\"]]]]"
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document(duplicate_text)),
		"duplicate_dictionary_key"
	)
	var valid: String = _document("[\"Nil\"]")
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(valid.replace("\"version\": 1", "\"version\": 2")),
		"unsupported_version"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(valid.replace("gf.variant-json-deterministic", "other")),
		"unsupported_format"
	)
	for text: String in [
		"",
		valid + "null",
		valid.replace("\"value\":", "\"extra\": 0, \"value\":"),
		valid.left(valid.length() - 2),
	]:
		var result: Dictionary = GFVariantJsonCodec.decode_deterministic_result(text)
		assert_false(
			_equal_values(
				result.get("ok", true),
				true
			),
			text
		)
		assert_true((result.get("value") == null))


func test_snapshot_and_binary_protocol_remain_independent() -> void:
	var source: Dictionary = {
		"a": [1, 2],
	}
	var captured: Dictionary = GFDataSnapshot.capture(source)
	var snapshot: GFDataSnapshot = captured["snapshot"]
	var expected: String = _text(GFVariantJsonCodec.encode_deterministic_result(source))
	var before: String = GFDeterministicVariantSerializer.sha256(snapshot)
	var source_array: Array = source["a"]
	source_array.append(3)
	assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(snapshot)) == expected))
	assert_true((GFDeterministicVariantSerializer.sha256(snapshot) == before))
	assert_true((GFDeterministicVariantSerializer.sha256(null) == "c2f6f4900d26c5cc047b4a6f94200f7fe30dcf229c8c3f7bcfb85d80798bcc83"))
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(GFDataSnapshot.new()),
		"snapshot_unavailable"
	)


func test_precancel_and_deadline_stop_both_directions() -> void:
	var token: GFCancellationToken = GFCancellationToken.new()
	var _cancelled: bool = token.request_cancel_internal()
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			null,
			{ "cancel_token": token }
		),
		"cancelled"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			_document("[\"Nil\"]"),
			{ "cancel_token": token }
		),
		"cancelled"
	)
	var payload: String = "x".repeat(1000000)
	var limited: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		payload,
		{ "max_elapsed_msec": 1 }
	)
	_assert_failure(limited, "limit_exceeded")
	assert_true(
		_equal_values(
			limited.get("limit_kind"),
			"max_elapsed_msec"
		)
	)
	var text: String = _document("[\"String\",\"" + payload + "\"]")
	var read_limited: Dictionary = GFVariantJsonCodec.decode_deterministic_result(
		text,
		{ "max_elapsed_msec": 1 }
	)
	_assert_failure(read_limited, "limit_exceeded")
	assert_true(
		_equal_values(
			read_limited.get("limit_kind"),
			"max_elapsed_msec"
		)
	)


func test_deep_dictionary_keys_fail_before_native_hashing() -> void:
	var key: String = "[\"Nil\"]"
	for depth: int in 128:
		key = "[\"Array\",\"Variant\",[" + key + "]]"
	var node: String = "[\"Dictionary\",\"Variant\",\"Variant\",[[" + key + ",[\"Nil\"]]]]"
	var report: Dictionary = GFVariantJsonCodec.decode_deterministic_result(
		_document(node),
		{ "max_depth": 256 }
	)
	assert_false(
		_equal_values(
			report.get("ok", true),
			true
		)
	)
	assert_true(report.get("value") == null)
	assert_true(
		_equal_values(
			report.get("limit_kind"),
			"max_key_depth"
		)
	)


func test_node_paths_and_actual_numeric_failure_reasons() -> void:
	for text: String in [
		"a/",
		"../child:property",
		"",
	]:
		var source: NodePath = NodePath(text)
		assert_true(
			_equal_values(
				_roundtrip(source),
				source
			)
		)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document("[\"NodePath\",\"a::b\"]")),
		"invalid_node_path"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document("[\"PackedFloat32Array\",[\"0.1@9a9999999999b93f\"]]")),
		"precision_loss"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document("[\"Array\",\"Int64\",[[\"Float64\",\"1.0@000000000000f03f\"]]]")),
		"type_mismatch"
	)


func test_sort_budget_matches_independent_fixed_costs() -> void:
	var nested_value: Dictionary = {
		"a": { "b": null },
	}
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(nested_value)
	# Two live 128-byte entry headers and one 14-character key at 8 bytes/character.
	assert_true(
		_equal_values(
			encoded.get("peak_sort_bytes"),
			368
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			nested_value,
			{ "max_sort_bytes": 367 }
		),
		"limit_exceeded"
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
	# Decoder retains both key texts until duplicate detection for each dictionary finishes.
	assert_true(
		_equal_values(
			decoded.get("peak_sort_bytes"),
			480
		)
	)
	var nested_key: Dictionary = { "a": null }
	var keyed: Dictionary = { nested_key: null }
	var key_encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(keyed)
	# 256 header bytes + (35 prefix + 14 temporary key + 16 emitted characters) * 8.
	assert_true(
		_equal_values(
			key_encoded.get("peak_sort_bytes"),
			776
		)
	)
	assert_true(
		_equal_values(
			GFVariantJsonCodec.encode_deterministic_result(
				keyed,
				{ "max_sort_bytes": 776 }
			).get("ok"),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			keyed,
			{ "max_sort_bytes": 775 }
		),
		"limit_exceeded"
	)


func test_key_depth_has_independent_exact_boundary() -> void:
	var key: Variant = null
	for depth: int in 64:
		key = [key]
	var payload: Dictionary = { key: true }
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		payload,
		{ "max_depth": 256 }
	)
	assert_true(
		_equal_values(
			encoded.get("ok"),
			true
		)
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(
		_text(encoded),
		{ "max_depth": 256 }
	)
	assert_true(
		_equal_values(
			decoded.get("ok"),
			true
		)
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			payload,
			{ "max_depth": 256, "max_key_depth": 63 }
		),
		"limit_exceeded"
	)
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(
			_text(encoded),
			{ "max_depth": 256, "max_key_depth": 63 }
		),
		"limit_exceeded"
	)
	_assert_failure(
		GFVariantJsonCodec.encode_deterministic_result(
			null,
			{ "max_key_depth": 65 }
		),
		"invalid_options"
	)


func test_random_binary64_values_and_fixed_float_golden() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 731291
	var bytes: PackedByteArray = PackedByteArray()
	var _resized: int = bytes.resize(8)
	for sample: int in 256:
		for index: int in 8:
			bytes[index] = rng.randi_range(0, 255)
		var value: float = bytes.decode_double(0)
		if is_finite(value):
			var restored: Variant = _roundtrip(value)
			assert_true(typeof(restored) == TYPE_FLOAT)
			assert_true(_equal_values(restored, value))
	assert_true(_text(GFVariantJsonCodec.encode_deterministic_result(1.0)).contains("[\"Float64\", \"1.0@000000000000f03f\"]"))
	_assert_failure(
		GFVariantJsonCodec.decode_deterministic_result(_document("[\"Float64\",\"2.0@000000000000f03f\"]")),
		"invalid_number"
	)


func test_readonly_values_are_encoded_without_mutation() -> void:
	var nested: Array[int] = [1, 2]
	nested.make_read_only()
	var source: Dictionary = { "items": nested }
	source.make_read_only()
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(source)
	assert_true(
		_equal_values(
			encoded.get("ok"),
			true
		)
	)
	assert_true(source.is_read_only())
	assert_true(nested.is_read_only())
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
	assert_true(
		_equal_values(
			decoded.get("ok"),
			true
		)
	)
	if decoded.get("value") is Dictionary:
		var restored: Dictionary = decoded["value"]
		assert_false(restored.is_read_only())
		assert_true(restored == source)
	else:
		fail_test("Expected Dictionary.")


func test_cancellation_during_work_publishes_no_partial_result() -> void:
	var payload: Array = range(1000)
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(payload)
	assert_true(
		_equal_values(
			encoded.get("ok"),
			true
		)
	)
	var write_token: _StepCancellationToken = _StepCancellationToken.new()
	var write_report: Dictionary = GFVariantJsonCodec.encode_deterministic_result(
		payload,
		{ "cancel_token": write_token }
	)
	_assert_failure(write_report, "cancelled")
	assert_true(
		_greater_count(
			write_report.get("items", 0),
			0
		)
	)
	assert_true(
		_greater_count(
			write_report.get("output_bytes", 0),
			0
		)
	)
	var read_token: _StepCancellationToken = _StepCancellationToken.new()
	var read_report: Dictionary = GFVariantJsonCodec.decode_deterministic_result(
		_text(encoded),
		{ "cancel_token": read_token }
	)
	_assert_failure(read_report, "cancelled")
	assert_true(
		_greater_count(
			read_report.get("items", 0),
			0
		)
	)


func _equal_values(actual: Variant, expected: Variant) -> bool:
	return actual == expected


func _greater_count(actual: Variant, expected: int) -> bool:
	return actual is int and actual > expected


func _document(node: String) -> String:
	return "{\n  \"format\": \"gf.variant-json-deterministic\",\n  \"version\": 1,\n  \"value\": " + node + "\n}\n"


func _roundtrip(value: Variant) -> Variant:
	var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result(value)
	assert_true(
		_equal_values(
			encoded.get("ok", false),
			true
		),
		str(encoded)
	)
	var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(_text(encoded))
	assert_true(
		_equal_values(
			decoded.get("ok", false),
			true
		),
		str(decoded)
	)
	assert_true((_text(GFVariantJsonCodec.encode_deterministic_result(decoded.get("value"))) == _text(encoded)))
	return decoded.get("value")


func _assert_failure(report: Dictionary, kind: String) -> void:
	for field: String in [
		"ok",
		"format_id",
		"format_version",
		"counts_complete",
		"items",
		"packed_items",
		"input_bytes",
		"output_bytes",
		"maximum_depth",
		"peak_sort_bytes",
		"error_kind",
		"error_path",
		"limit_kind",
		"limit",
		"observed",
	]:
		assert_true(
			report.has(field),
			field
		)
	assert_false(
		_equal_values(
			report.get("ok", true),
			true
		),
		str(report)
	)
	assert_true(
		_equal_values(
			report.get("error_kind"),
			kind
		),
		str(report)
	)
	assert_false(
		_equal_values(
			report.get("counts_complete", true),
			true
		)
	)
	assert_true(
		not _equal_values(
			report.get("error_path", ""),
			""
		)
	)
	if report.has("text"):
		assert_true(
			_equal_values(
				report.get("text"),
				""
			)
		)
	if report.has("value"):
		assert_true((report.get("value") == null))


func _text(report: Dictionary) -> String:
	var result: Variant = report.get("text", "")
	return result if result is String else ""


class _StepCancellationToken extends GFCancellationToken:
	var _checks_remaining: int = 200


	func is_cancel_requested() -> bool:
		_checks_remaining -= 1
		if _checks_remaining == 0:
			var _requested: bool = request_cancel_internal()
		return super.is_cancel_requested()
