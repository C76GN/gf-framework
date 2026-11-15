extends GutTest


func test_unready_snapshot_exports_a_complete_failure_report() -> void:
	var snapshot: GFDataSnapshot = GFDataSnapshot.new()
	var report: Dictionary = snapshot.copy_value()
	assert_false(snapshot.is_ready())
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_true(report["value"] == null)
	assert_eq(
		GFVariantData.get_option_string(report, "error_kind"),
		"snapshot_unavailable"
	)
	assert_true(
		report.has_all(
			[
				"ok",
				"value",
				"error_kind",
				"counts_complete",
				"items",
				"packed_items",
				"payload_bytes",
				"maximum_depth",
				"error_path",
				"limit_kind",
				"limit",
				"observed",
			]
		)
	)


func test_capture_expands_aliases_and_isolates_source_and_reads() -> void:
	var shared: Dictionary = { "number": 4 }
	var source: Dictionary = {
		"left": shared,
		"right": shared,
		"packed": PackedInt64Array([1, 9223372036854775807]),
	}
	var capture: Dictionary = GFDataSnapshot.capture(source)
	assert_true(GFVariantData.get_option_bool(capture, "ok"))
	var snapshot: GFDataSnapshot = capture["snapshot"]
	shared["number"] = 9
	var first: Dictionary = snapshot.copy_value()["value"]
	var left: Dictionary = first["left"]
	var right: Dictionary = first["right"]
	assert_false(is_same(left, right))
	assert_eq(
		GFVariantData.get_option_int(left, "number"),
		4
	)
	left["number"] = 12
	assert_eq(
		GFVariantData.get_option_int(right, "number"),
		4
	)
	var selected_number: int = snapshot.get_value(["left", "number"])
	assert_eq(selected_number, 4)
	var packed: PackedInt64Array = snapshot.get_value(["packed"])
	packed[0] = 3
	var second_packed: PackedInt64Array = snapshot.get_value(["packed"])
	assert_eq(
		second_packed[0],
		1
	)


func test_capture_rejects_cycles_objects_and_object_typed_containers() -> void:
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic: Dictionary = GFDataSnapshot.capture(cycle)
	assert_false(GFVariantData.get_option_bool(cyclic, "ok"))
	assert_true(cyclic["snapshot"] == null)
	assert_eq(
		GFVariantData.get_option_string(cyclic, "error_kind"),
		"cycle"
	)
	cycle.clear()
	var object_result: Dictionary = GFDataSnapshot.capture(Resource.new())
	assert_false(GFVariantData.get_option_bool(object_result, "ok"))
	var typed: Array[Resource] = []
	var typed_result: Dictionary = GFDataSnapshot.capture(typed)
	assert_false(GFVariantData.get_option_bool(typed_result, "ok"))


func test_capture_preserves_typed_values_and_packed_columns() -> void:
	var numbers: Array[int] = [1, 2]
	var names: Dictionary[String, int] = { "one": 1 }
	var result: Dictionary = GFDataSnapshot.capture({ "numbers": numbers, "names": names })
	var snapshot: GFDataSnapshot = result["snapshot"]
	var copied_numbers: Array = snapshot.get_value(["numbers"])
	var copied_names: Dictionary = snapshot.get_value(["names"])
	assert_eq(
		copied_numbers.get_typed_builtin(),
		TYPE_INT
	)
	assert_eq(
		copied_names.get_typed_key_builtin(),
		TYPE_STRING
	)
	assert_eq(
		copied_names.get_typed_value_builtin(),
		TYPE_INT
	)


func test_capture_enforces_expanded_item_budget_and_discards_partial_tree() -> void:
	var shared: Array = [
		1,
		2,
		3,
	]
	var report: Dictionary = GFDataSnapshot.capture(
		[shared, shared],
		{ "max_items": 6 }
	)
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_true(report["snapshot"] == null)
	assert_false(GFVariantData.get_option_bool(report, "counts_complete"))
	assert_eq(
		GFVariantData.get_option_string(report, "limit_kind"),
		"max_items"
	)
	var bytes_report: Dictionary = GFDataSnapshot.capture(
		PackedInt64Array([1, 2]),
		{ "max_payload_bytes": 15 }
	)
	assert_false(GFVariantData.get_option_bool(bytes_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(bytes_report, "limit_kind"),
		"max_payload_bytes"
	)


func test_default_copy_expands_aliases_and_graph_copy_explicitly_preserves_them() -> void:
	var shared: Array = [1]
	var source: Array = [shared, shared]
	var value_copy: Array = GFVariantData.duplicate_variant(source)
	var graph_copy: Array = GFVariantData.duplicate_graph(source)
	assert_false(
		is_same(
			value_copy[0],
			value_copy[1]
		)
	)
	assert_true(
		is_same(
			graph_copy[0],
			graph_copy[1]
		)
	)
	var copied_item: Array = value_copy[0]
	copied_item.append(2)
	var copied_sibling: Array = value_copy[1]
	var original_item: Array = source[0]
	assert_eq(
		copied_sibling,
		[1]
	)
	assert_eq(
		original_item,
		[1]
	)
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic: Dictionary = GFVariantData.copy_value(cycle)
	assert_eq(
		GFVariantData.get_option_string(cyclic, "error_kind"),
		"cycle"
	)
	cycle.clear()
	var object_result: Dictionary = GFVariantData.copy_value(Resource.new())
	assert_eq(
		GFVariantData.get_option_string(object_result, "error_kind"),
		"unsupported_type"
	)
	var wide: Array = []
	for index: int in 2048:
		wide.append({ "id": index })
	var result: Dictionary = GFVariantData.copy_value(wide)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_int(result, "items"),
		1 + 2048 * 3
	)


func test_capture_cancellation_invalid_limits_and_export_limits() -> void:
	for limits: Dictionary in [
		{ 1: 1 },
		{ Vector2.ZERO: 1 },
		{ Resource.new(): 1 },
	]:
		var invalid_capture: Dictionary = GFDataSnapshot.capture(
			[1],
			limits
		)
		var invalid_hash: Dictionary = GFDeterministicVariantSerializer.hash_result(
			[1],
			limits
		)
		assert_eq(
			GFVariantData.get_option_string(invalid_capture, "error_kind"),
			"invalid_limits"
		)
		assert_eq(
			GFVariantData.get_option_string(invalid_hash, "error_kind"),
			"invalid_options"
		)
	var token: GFCancellationToken = GFCancellationToken.new()
	var _cancelled: bool = token.request_cancel_internal()
	var cancelled: Dictionary = GFDataSnapshot.capture(
		[1],
		{ "cancel_token": token }
	)
	assert_eq(
		GFVariantData.get_option_string(cancelled, "error_kind"),
		"cancelled"
	)
	var invalid_budget: Dictionary = GFDataSnapshot.capture(
		[1],
		{ "max_items": 0 }
	)
	assert_eq(
		GFVariantData.get_option_string(invalid_budget, "error_kind"),
		"invalid_limits"
	)
	var report: Dictionary = GFDataSnapshot.capture(
		[
			1,
			2,
			3,
		]
	)
	var snapshot: GFDataSnapshot = report["snapshot"]
	var copied: Dictionary = snapshot.copy_value({ "max_items": 2 })
	assert_false(GFVariantData.get_option_bool(copied, "ok"))
	assert_true(copied["value"] == null)
	var selected_number: int = snapshot.get_value([0])
	assert_eq(selected_number, 1)
