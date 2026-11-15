## 验证 canonical v2 协议、跨输出方式一致性及有限资源行为。
extends GutTest


# --- 测试用例 ---

func test_protocol_golden_vectors_from_independent_struct_encoder() -> void:
	var cases: Array = [
		[
			null,
			"4746430200",
			"c2f6f4900d26c5cc047b4a6f94200f7fe30dcf229c8c3f7bcfb85d80798bcc83",
			{},
		],
		[
			{ "a": 7, 2: "汉" },
			"47464302290200000000000000020200000000000000040300000000000000e6b18904010000000000000061020700000000000000",
			"03c99f40aa09306989ab11aea86ca31853e1bbe9d27ef1dd8b5143eabedd65f8",
			{},
		],
		[
			PackedInt32Array(
				[
					-2147483648,
					0,
					2147483647,
				]
			),
			"474643023303000000000000000000008000000000ffffff7f",
			"b25f333bcf6deeac6f363882de044cc10eba8ab7b3577ff123c78ed3e63c9c7d",
			{},
		],
		[
			[1.25, -0.0],
			"4746430228020000000000000003000000000000f43f030000000000000000",
			"f6baea2c46500df0c3413c8b6ba3022874ad506a8dea4eb8d527e237778e54fe",
			{ "allow_floats": true },
		],
	]
	for entry: Array in cases:
		var options: Dictionary = entry[3]
		var expected_bytes: String = entry[1]
		var expected_hash: String = entry[2]
		var result: Dictionary = GFDeterministicVariantSerializer.encode_result(
			entry[0],
			options
		)
		var bytes: PackedByteArray = result["bytes"]
		assert_true(
			GFVariantData.get_option_bool(result, "ok"),
			str(result)
		)
		assert_eq(
			bytes.hex_encode(),
			expected_bytes
		)
		assert_eq(
			GFDeterministicVariantSerializer.sha256(
				entry[0],
				options
			),
			expected_hash
		)
		assert_eq(
			GFVariantData.get_option_int(result, "canonical_version"),
			2
		)


func test_dictionary_order_aliases_and_declared_container_types_use_value_semantics() -> void:
	var shared: Array = [
		1,
		{ "z": 2, "a": true },
	]
	var left: Dictionary = { "b": shared, "a": shared }
	var right: Dictionary = {
		"a": [
			1,
			{ "a": true, "z": 2 },
		],
		"b": [
			1,
			{ "z": 2, "a": true },
		],
	}
	assert_eq(
		GFDeterministicVariantSerializer.sha256(left),
		GFDeterministicVariantSerializer.sha256(right)
	)
	var typed: Array[int] = [1, 2]
	assert_eq(
		GFDeterministicVariantSerializer.sha256(typed),
		GFDeterministicVariantSerializer.sha256([1, 2])
	)
	assert_ne(
		GFDeterministicVariantSerializer.sha256("1"),
		GFDeterministicVariantSerializer.sha256(1)
	)
	assert_ne(
		GFDeterministicVariantSerializer.sha256(&"1"),
		GFDeterministicVariantSerializer.sha256("1")
	)


func test_snapshot_reuse_isolated_from_source_and_export_mutation() -> void:
	var source: Dictionary = {
		"values": PackedInt64Array([1, 2]),
		"nested": [3],
	}
	var captured: Dictionary = GFDataSnapshot.capture(source)
	var snapshot: GFDataSnapshot = captured["snapshot"]
	var expected: String = GFDeterministicVariantSerializer.sha256(source)
	var nested_source: Array = source["nested"]
	nested_source.append(4)
	var copied: Dictionary = snapshot.get_value()
	copied["values"][0] = 9
	assert_eq(
		GFDeterministicVariantSerializer.sha256(snapshot),
		expected
	)
	assert_eq(
		GFDeterministicVariantSerializer.sha256(snapshot),
		expected
	)
	assert_ne(
		GFDeterministicVariantSerializer.sha256(source),
		expected
	)
	var unavailable: Dictionary = GFDeterministicVariantSerializer.hash_result(GFDataSnapshot.new())
	assert_eq(
		GFVariantData.get_option_string(unavailable, "error_kind"),
		"snapshot_unavailable"
	)


func test_packed_and_utf8_chunks_keep_hash_bytes_and_measurement_identical() -> void:
	var packed: PackedInt64Array = PackedInt64Array()
	var _resized: int = packed.resize(20000)
	for index: int in packed.size():
		packed[index] = 9223372036854700000 + index
	var text: String = "a".repeat(4095) + "汉😀" + "z".repeat(4097)
	var long_key: String = "k".repeat(70000)
	_assert_modes(
		{
			long_key: [text, packed],
		},
		{ "max_items": 21000 }
	)
	var report: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		[
			PackedByteArray([1, 2]),
			"汉",
		]
	)
	assert_eq(
		GFVariantData.get_option_int(report, "items"),
		5
	)
	assert_eq(
		GFVariantData.get_option_int(report, "packed_items"),
		2
	)
	assert_eq(
		GFVariantData.get_option_int(report, "output_bytes"),
		36
	)


func test_finite_float_policy_preserves_adjacent_values_and_normalizes_all_zero_widths() -> void:
	var options: Dictionary = { "allow_floats": true }
	var disabled: Dictionary = GFDeterministicVariantSerializer.hash_result(1.0)
	assert_eq(
		GFVariantData.get_option_string(disabled, "error_kind"),
		"float_disabled"
	)
	assert_eq(
		GFDeterministicVariantSerializer.sha256(0.0, options),
		GFDeterministicVariantSerializer.sha256(-0.0, options)
	)
	assert_ne(
		GFDeterministicVariantSerializer.sha256(1.0, options),
		GFDeterministicVariantSerializer.sha256(1.0000000000000002, options)
	)
	for value: Variant in [
		INF,
		NAN,
		Vector2(INF, 0),
		PackedFloat32Array([NAN]),
		PackedFloat64Array([INF]),
	]:
		var result: Dictionary = GFDeterministicVariantSerializer.hash_result(value, options)
		assert_eq(
			GFVariantData.get_option_string(result, "error_kind"),
			"nonfinite_float"
		)
		assert_eq(
			GFVariantData.get_option_string(result, "hash"),
			""
		)
	for pair: Array in [
		[
			PackedFloat32Array([0.0]),
			PackedFloat32Array([-0.0]),
		],
		[
			PackedFloat64Array([0.0]),
			PackedFloat64Array([-0.0]),
		],
	]:
		assert_eq(
			GFDeterministicVariantSerializer.sha256(
				pair[0],
				options
			),
			GFDeterministicVariantSerializer.sha256(
				pair[1],
				options
			)
		)


func test_nested_dictionary_sort_budget_retains_parent_entry_overhead() -> void:
	var result: Dictionary = GFDeterministicVariantSerializer.hash_result(
		{
			"a": { "b": 0 },
		},
		{ "max_sort_bytes": 218 }
	)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string(result, "limit_kind"),
		"max_sort_bytes"
	)
	var accepted: Dictionary = GFDeterministicVariantSerializer.hash_result(
		{
			"a": { "b": 0 },
		},
		{ "max_sort_bytes": 346 }
	)
	assert_true(GFVariantData.get_option_bool(accepted, "ok"))
	assert_eq(
		GFVariantData.get_option_int(accepted, "peak_sort_bytes"),
		346
	)


func test_budget_failures_discard_outputs_and_stop_at_first_failure() -> void:
	var cases: Array = [
		[
			[1, 2],
			{ "max_items": 2 },
			"max_items",
		],
		[
			[
				[1],
			],
			{ "max_depth": 1 },
			"max_depth",
		],
		[
			"汉😀",
			{ "max_string_length": 1 },
			"max_string_length",
		],
		[
			PackedInt64Array([1, 2]),
			{ "max_output_bytes": 28 },
			"max_output_bytes",
		],
		[
			{ "a": 1 },
			{ "max_sort_bytes": 128 },
			"max_sort_bytes",
		],
	]
	for entry: Array in cases:
		var options: Dictionary = entry[1]
		var expected_limit: String = entry[2]
		for result: Dictionary in [
			GFDeterministicVariantSerializer.hash_result(
				entry[0],
				options
			),
			GFDeterministicVariantSerializer.encode_result(
				entry[0],
				options
			),
			GFDeterministicVariantSerializer.measure_canonical(
				entry[0],
				options
			),
		]:
			assert_true(
				result.has_all(
					[
						"ok",
						"counts_complete",
						"items",
						"packed_items",
						"output_bytes",
						"maximum_depth",
						"peak_sort_bytes",
						"hash",
						"bytes",
						"limit_kind",
						"observed_is_lower_bound",
					]
				)
			)
			assert_false(GFVariantData.get_option_bool(result, "ok"))
			assert_false(GFVariantData.get_option_bool(result, "counts_complete"))
			assert_eq(
				GFVariantData.get_option_string(result, "limit_kind"),
				expected_limit
			)
			assert_eq(
				GFVariantData.get_option_string(result, "hash"),
				""
			)
			var bytes: PackedByteArray = result["bytes"]
			assert_true(bytes.is_empty())
			assert_true(GFVariantData.get_option_bool(result, "observed_is_lower_bound"))
	var first: Dictionary = GFDeterministicVariantSerializer.hash_result(
		["long", Resource.new()],
		{ "max_output_bytes": 4 }
	)
	assert_eq(
		GFVariantData.get_option_string(first, "limit_kind"),
		"max_output_bytes"
	)
	assert_eq(
		GFVariantData.get_option_string(first, "failure_kind"),
		"output_limit"
	)
	var exact: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		{
			"a": [1, 2],
		}
	)
	var encoded: Dictionary = GFDeterministicVariantSerializer.encode_result(
		{
			"a": [1, 2],
		},
		{
			"max_items": GFVariantData.get_option_int(exact, "items"),
			"max_output_bytes": GFVariantData.get_option_int(exact, "output_bytes"),
			"max_sort_bytes": GFVariantData.get_option_int(exact, "peak_sort_bytes"),
		}
	)
	assert_true(
		GFVariantData.get_option_bool(encoded, "ok"),
		str(encoded)
	)


func test_cycles_objects_invalid_options_and_cancellation_fail_without_logging() -> void:
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic: Dictionary = GFDeterministicVariantSerializer.hash_result(cycle)
	assert_eq(
		GFVariantData.get_option_string(cyclic, "error_kind"),
		"cycle"
	)
	cycle.clear()
	var objects: Array[Resource] = []
	for value: Variant in [
		Resource.new(),
		Callable(self, "test_cycles_objects_invalid_options_and_cancellation_fail_without_logging"),
		RID(),
		objects,
	]:
		var unsupported: Dictionary = GFDeterministicVariantSerializer.hash_result(value)
		assert_eq(
			GFVariantData.get_option_string(unsupported, "error_kind"),
			"unsupported_type"
		)
	for options: Dictionary in [
		{ "max_items": 0 },
		{ "max_depth": 257 },
		{ "allow_floats": 1 },
		{ "unknown": 1 },
	]:
		var invalid_options: Dictionary = GFDeterministicVariantSerializer.hash_result(
			[1],
			options
		)
		assert_eq(
			GFVariantData.get_option_string(invalid_options, "error_kind"),
			"invalid_options"
		)
	var token: GFCancellationToken = GFCancellationToken.new()
	var _cancelled: bool = token.request_cancel_internal()
	var report: Dictionary = GFDeterministicVariantSerializer.hash_result(
		[1],
		{ "cancel_token": token }
	)
	assert_eq(
		GFVariantData.get_option_string(report, "error_kind"),
		"cancelled"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "items"),
		0
	)


func test_every_supported_type_uses_identical_v2_pipeline() -> void:
	var minimum_integer: int = -9_223_372_036_854_775_807 - 1
	var shared: Array = [
		1,
		{ "shared": true },
	]
	var compound_keys: Dictionary = {}
	compound_keys[["array", 2]] = "array-key"
	compound_keys[{ "z": 2, "a": 1 }] = "dictionary-key"
	compound_keys[PackedInt64Array([2, 1])] = "packed-key"
	compound_keys[NodePath("root/child:property")] = "path-key"
	var source: Array = [
		null,
		true,
		false,
		minimum_integer,
		9_223_372_036_854_775_807,
		"",
		"汉字😀é\"\\/\n\r\t" + String.chr(1),
		&"标签",
		NodePath("root/child:property"),
		0.0,
		-0.0,
		1.0000000000000002,
		5e-324,
		1.7976931348623157e308,
		Vector2(1.5, -2.25),
		Vector2i(-2, 3),
		Vector3(
			1,
			2,
			3
		),
		Vector3i(
			-2,
			3,
			4
		),
		Vector4(
			1,
			2,
			3,
			4
		),
		Vector4i(
			-2,
			3,
			4,
			5
		),
		Rect2(
			-1,
			2,
			3,
			4
		),
		Rect2i(
			-1,
			2,
			3,
			4
		),
		Color(
			0.25,
			0.5,
			0.75,
			1
		),
		Plane(Vector3.UP, 2.5),
		Quaternion(
			0.1,
			0.2,
			0.3,
			0.4
		),
		AABB(
			Vector3(
				-1,
				2,
				3
			),
			Vector3(
				4,
				5,
				6
			)
		),
		Basis(
			Vector3(
				1,
				2,
				3
			),
			Vector3(
				4,
				5,
				6
			),
			Vector3(
				7,
				8,
				9
			)
		),
		Transform2D(
			0.5,
			Vector2(2, 3)
		),
		Transform3D(
			Basis.IDENTITY,
			Vector3(
				2,
				3,
				4
			)
		),
		Projection.IDENTITY,
		[],
		{},
		compound_keys,
		shared,
		shared,
		PackedByteArray(
			[
				0,
				1,
				255,
			]
		),
		PackedInt32Array([-2147483648, 2147483647]),
		PackedInt64Array([minimum_integer, 9_223_372_036_854_775_807]),
		PackedFloat32Array(
			[
				-0.0,
				1.5,
				-2.25,
			]
		),
		PackedFloat64Array([5e-324, 1.0000000000000002]),
		PackedStringArray(
			[
				"",
				"汉😀\n\"\\",
				String.chr(1),
			]
		),
		PackedVector2Array([Vector2(1, 2), Vector2(-3, 4)]),
		PackedVector3Array(
			[
				Vector3(
					1,
					2,
					3
				),
			]
		),
		PackedColorArray(
			[
				Color(
					0.25,
					0.5,
					0.75,
					1
				),
			]
		),
		PackedVector4Array(
			[
				Vector4(
					1,
					2,
					3,
					4
				),
			]
		),
		PackedByteArray(),
		PackedInt32Array(),
		PackedInt64Array(),
		PackedFloat32Array(),
		PackedFloat64Array(),
		PackedStringArray(),
		PackedVector2Array(),
		PackedVector3Array(),
		PackedColorArray(),
		PackedVector4Array(),
	]
	_assert_modes(
		source,
		{ "allow_floats": true }
	)


# --- 私有/辅助方法 ---

## 独立 HashingContext 验证字节摘要，输出策略之间复核精确计量。
## [br]
## @api private
func _assert_modes(value: Variant, options: Dictionary = {}) -> void:
	var encoded: Dictionary = GFDeterministicVariantSerializer.encode_result(value, options)
	var hashed: Dictionary = GFDeterministicVariantSerializer.hash_result(value, options)
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(value, options)
	assert_true(
		GFVariantData.get_option_bool(encoded, "ok"),
		str(encoded)
	)
	assert_true(
		GFVariantData.get_option_bool(hashed, "ok"),
		str(hashed)
	)
	assert_true(
		GFVariantData.get_option_bool(measured, "ok"),
		str(measured)
	)
	var bytes: PackedByteArray = encoded["bytes"]
	var context: HashingContext = HashingContext.new()
	assert_eq(
		context.start(HashingContext.HASH_SHA256),
		OK
	)
	assert_eq(
		context.update(bytes),
		OK
	)
	assert_eq(
		GFVariantData.get_option_string(hashed, "hash"),
		context.finish().hex_encode()
	)
	for field: String in [
		"items",
		"packed_items",
		"output_bytes",
		"maximum_depth",
		"peak_sort_bytes",
	]:
		assert_true(encoded.has(field))
		assert_true(hashed.has(field))
		assert_true(measured.has(field))
		assert_eq(
			GFVariantData.get_option_int(encoded, field),
			GFVariantData.get_option_int(hashed, field),
			field
		)
		assert_eq(
			GFVariantData.get_option_int(encoded, field),
			GFVariantData.get_option_int(measured, field),
			field
		)
	assert_eq(
		GFVariantData.get_option_int(measured, "output_bytes"),
		bytes.size()
	)
	assert_true(GFVariantData.get_option_bool(measured, "counts_complete"))
