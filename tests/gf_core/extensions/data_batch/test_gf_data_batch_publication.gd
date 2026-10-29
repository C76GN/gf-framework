extends GutTest


# --- 测试用例 ---

func test_schema_freezes_layout_and_rejects_ambiguous_definitions() -> void:
	var names: Array[StringName] = [&"team", &"life_id"]
	var types: PackedInt32Array = PackedInt32Array([GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64,])
	var schema: GFDataBatchSchema = GFDataBatchSchema.create(
		&"fleet",
		3,
		names,
		types
	)
	assert_not_null(schema)
	names[0] = &"changed"
	types[0] = GFDataBatchSchema.NumericType.INT64
	assert_eq(
		schema.get_schema_id(),
		&"fleet"
	)
	assert_eq(
		schema.get_version(),
		3
	)
	assert_eq(
		schema.find_column(&"team"),
		0
	)
	assert_eq(
		schema.find_column(&"changed"),
		-1
	)
	assert_eq(
		schema.get_column_type(0),
		GFDataBatchSchema.NumericType.INT32
	)
	assert_eq(
		schema.get_bytes_per_row(),
		12
	)
	assert_eq(
		schema.get_column_type(-1),
		GFDataBatchSchema.NumericType.INVALID
	)
	assert_eq(
		schema.get_column_name(2),
		&""
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			0,
			names,
			types
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"",
			1,
			names,
			types
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			[],
			PackedInt32Array()
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			[&"same", &"same"],
			types
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			[&""],
			PackedInt32Array([1])
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			[&"team"],
			PackedInt32Array([99])
		)
	)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			names,
			PackedInt32Array([1])
		)
	)
	var too_many: Array[StringName] = []
	var too_many_types: PackedInt32Array = PackedInt32Array()
	for index: int in range(GFDataBatchSchema.MAX_COLUMNS + 1):
		too_many.append(StringName("column_%d" % index))
		var _appended: bool = too_many_types.append(GFDataBatchSchema.NumericType.INT32)
	assert_null(
		GFDataBatchSchema.create(
			&"fleet",
			1,
			too_many,
			too_many_types
		)
	)


func test_publication_requires_valid_identity_and_finite_budgets() -> void:
	var schema: GFDataBatchSchema = _schema()
	assert_null(
		GFDataBatchPublication.create(
			null,
			&"fleet",
			1,
			4,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			GFDataBatchSchema.new(),
			&"fleet",
			1,
			4,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			schema,
			&"",
			1,
			4,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			schema,
			&"fleet",
			0,
			4,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			schema,
			&"fleet",
			1,
			0,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			schema,
			&"fleet",
			1,
			2_147_483_648,
			96
		)
	)
	assert_null(
		GFDataBatchPublication.create(
			schema,
			&"fleet",
			1,
			4,
			0
		)
	)
	var unconfigured: GFDataBatchPublication = GFDataBatchPublication.new()
	assert_eq(
		unconfigured.publish_copy(
			_columns(),
			2,
			2,
			0,
			0
		),
		ERR_UNAVAILABLE
	)
	assert_eq(
		unconfigured.get_last_failure(),
		GFDataBatchPublication.Failure.CLOSED
	)


func test_copy_publication_isolates_sources_and_reader_copies() -> void:
	var publication: GFDataBatchPublication = _owner()
	var teams: PackedInt32Array = PackedInt32Array(
		[
			2,
			4,
			-1,
		]
	)
	var ids: PackedInt64Array = PackedInt64Array(
		[
			9_007_199_254_740_993,
			-9_007_199_254_740_995,
			-1,
		]
	)
	var source: Dictionary = { &"team": teams, &"life_id": ids }
	assert_eq(
		publication.publish_copy(
			source,
			2,
			3,
			7,
			11
		),
		OK
	)
	var snapshot: GFDataBatchSnapshot = publication.get_current()
	assert_not_null(snapshot)
	assert_eq(
		snapshot.get_schema().get_version(),
		2
	)
	assert_eq(
		snapshot.get_producer_id(),
		&"fleet"
	)
	assert_eq(
		snapshot.get_producer_generation(),
		3
	)
	assert_eq(
		snapshot.get_publication_sequence(),
		1
	)
	assert_eq(
		snapshot.get_structural_revision(),
		7
	)
	assert_eq(
		snapshot.get_value_revision(),
		11
	)
	assert_eq(
		snapshot.get_count(),
		2
	)
	assert_eq(
		snapshot.get_capacity(),
		3
	)
	assert_eq(
		snapshot.get_payload_bytes(),
		36
	)
	teams[0] = 99
	ids[0] = 99
	source.clear()
	var team_copy: PackedInt32Array = snapshot.copy_int32_column(0)
	var id_copy: PackedInt64Array = snapshot.copy_int64_column(1)
	assert_eq(
		team_copy,
		PackedInt32Array(
			[
				2,
				4,
				-1,
			]
		)
	)
	assert_eq(
		id_copy,
		PackedInt64Array(
			[
				9_007_199_254_740_993,
				-9_007_199_254_740_995,
				-1,
			]
		)
	)
	team_copy[0] = 77
	id_copy[0] = 77
	assert_eq(
		snapshot.borrow_int32_column(0)[0],
		2
	)
	assert_eq(
		snapshot.borrow_int64_column(1)[0],
		9_007_199_254_740_993
	)
	assert_true(snapshot.copy_int32_column(1).is_empty())
	assert_true(snapshot.copy_int64_column(0).is_empty())
	assert_true(snapshot.borrow_int32_column(-1).is_empty())
	assert_true(snapshot.borrow_int64_column(2).is_empty())
	assert_eq(
		_debug_int(publication, "last_copied_payload_bytes"),
		36
	)
	assert_eq(
		_debug_int(publication, "last_transferred_payload_bytes"),
		0
	)


func test_string_keyed_typed_dictionary_supports_copy_and_transfer() -> void:
	var publication: GFDataBatchPublication = _owner()
	var source: Dictionary[String, Variant] = {
		"team": PackedInt32Array([3, 4]),
		"life_id": PackedInt64Array([9_007_199_254_740_993, -9_007_199_254_740_993]),
	}
	var copy_result: Error = publication.publish_copy(
		source,
		2,
		2,
		0,
		0
	)
	assert_eq(copy_result, OK)
	var copied: GFDataBatchSnapshot = publication.get_current()
	var transfer_result: Error = publication.publish_transfer(
		source,
		2,
		2,
		0,
		1
	)
	assert_eq(transfer_result, OK)
	assert_true(source.is_empty())
	var first_id: int = publication.get_current().borrow_int64_column(1)[0]
	assert_eq(first_id, 9_007_199_254_740_993)
	var old_team: int = copied.borrow_int32_column(0)[0]
	assert_eq(old_team, 3)


func test_repeated_capture_in_one_frame_publishes_immediately_and_preserves_two_generations() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(1),
			2,
			2,
			1,
			1
		),
		OK
	)
	var previous: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		publication.publish_copy(
			_columns(5),
			2,
			2,
			1,
			2
		),
		OK
	)
	var current: GFDataBatchSnapshot = publication.get_current()
	assert_false(publication.is_current(previous))
	assert_true(publication.is_current(current))
	assert_eq(
		previous.borrow_int32_column(0)[0],
		1
	)
	assert_eq(
		current.borrow_int32_column(0)[0],
		5
	)
	assert_eq(
		current.get_publication_sequence(),
		2
	)
	assert_eq(
		publication.publish_copy(
			_columns(9),
			2,
			2,
			1,
			3
		),
		OK
	)
	assert_eq(
		previous.borrow_int32_column(0)[0],
		1
	)
	assert_eq(
		current.borrow_int32_column(0)[0],
		5
	)
	assert_eq(
		publication.get_current().borrow_int32_column(0)[0],
		9
	)
	assert_eq(
		_debug_int(publication, "current_payload_bytes"),
		24
	)
	assert_eq(
		_debug_int(publication, "last_peak_payload_bytes"),
		48
	)


func test_current_identity_is_owner_and_snapshot_specific() -> void:
	var first: GFDataBatchPublication = _owner()
	var second: GFDataBatchPublication = _owner()
	assert_eq(
		first.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	assert_eq(
		second.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	assert_false(first.is_current(second.get_current()))
	assert_false(first.is_current(null))
	var next_generation: GFDataBatchPublication = GFDataBatchPublication.create(
		_schema(),
		&"fleet",
		4,
		10,
		240
	)
	assert_eq(
		next_generation.publish_copy(
			_columns(),
			2,
			2,
			0,
			0
		),
		OK
	)
	assert_eq(
		next_generation.get_current().get_producer_generation(),
		4
	)
	assert_false(first.is_current(next_generation.get_current()))


func test_invalid_revisions_do_not_replace_or_consume_publication_sequence() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			3,
			5
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	for revisions: PackedInt32Array in [
		PackedInt32Array([3, 5]),
		PackedInt32Array([2, 6]),
		PackedInt32Array([4, 4]),
		PackedInt32Array([-1, 6]),
	]:
		assert_eq(
			publication.publish_copy(
				_columns(9),
				2,
				2,
				revisions[0],
				revisions[1]
			),
			ERR_INVALID_PARAMETER
		)
		assert_eq(
			publication.get_last_failure(),
			GFDataBatchPublication.Failure.INVALID_REVISION
		)
		assert_same(
			publication.get_current(),
			original
		)
	assert_eq(
		publication.publish_copy(
			_columns(),
			1,
			2,
			3,
			6
		),
		ERR_INVALID_PARAMETER
	)
	assert_eq(
		publication.publish_copy(
			_columns(),
			1,
			2,
			4,
			6
		),
		OK
	)
	assert_eq(
		publication.get_current().get_publication_sequence(),
		2
	)
	assert_eq(
		publication.get_current().get_count(),
		1
	)


func test_full_column_validation_precedes_transfer_consumption() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	var invalid_columns: Array[Dictionary] = [
		{
			&"team": PackedInt32Array([1, 2]),
		},
		{
			&"team": PackedInt32Array([1, 2]),
			&"life_id": PackedInt64Array([10, 20]),
			&"extra": PackedInt32Array([1, 2]),
		},
		{
			&"team": PackedInt64Array([1, 2]),
			&"life_id": PackedInt64Array([10, 20]),
		},
		{
			&"team": PackedInt32Array([1, 2]),
			&"life_id": PackedInt64Array([10]),
		},
		{
			&"team": PackedInt32Array([1, 2]),
			&"life_id": [10, 20],
		},
	]
	for source: Dictionary in invalid_columns:
		var key_count: int = source.size()
		assert_eq(
			publication.publish_transfer(
				source,
				2,
				2,
				1,
				2
			),
			ERR_INVALID_PARAMETER
		)
		assert_eq(
			publication.get_last_failure(),
			GFDataBatchPublication.Failure.INVALID_COLUMN
		)
		assert_eq(
			source.size(),
			key_count
		)
		assert_same(
			publication.get_current(),
			original
		)
	assert_eq(
		publication.publish_copy(
			_columns(),
			-1,
			2,
			1,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.INVALID_SHAPE
	)
	assert_eq(
		publication.publish_copy(
			_columns(),
			3,
			2,
			1,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_same(
		publication.get_current(),
		original
	)


func test_transfer_is_explicit_single_consumption_and_preserves_int64_values() -> void:
	var publication: GFDataBatchPublication = _owner()
	var source: Dictionary = _columns()
	assert_eq(
		publication.publish_transfer(
			source,
			2,
			2,
			1,
			1
		),
		OK
	)
	assert_true(source.is_empty())
	var snapshot: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		snapshot.borrow_int64_column(1),
		PackedInt64Array([9_007_199_254_740_993, -9_007_199_254_740_993])
	)
	assert_eq(
		_debug_int(publication, "last_copied_payload_bytes"),
		0
	)
	assert_eq(
		_debug_int(publication, "last_transferred_payload_bytes"),
		24
	)
	assert_eq(
		publication.publish_transfer(
			source,
			2,
			2,
			1,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_same(
		publication.get_current(),
		snapshot
	)


func test_read_only_transfer_is_rejected_without_native_clear_error() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	var source: Dictionary = _columns(7)
	source.make_read_only()
	assert_eq(
		publication.publish_transfer(
			source,
			2,
			2,
			1,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.READ_ONLY_TRANSFER
	)
	assert_eq(
		source.size(),
		2
	)
	assert_same(
		publication.get_current(),
		original
	)
	assert_eq(
		publication.publish_copy(
			source,
			2,
			2,
			1,
			2
		),
		OK
	)
	assert_eq(
		publication.get_current().borrow_int32_column(0)[0],
		7
	)


func test_gather_copies_only_selected_rows_and_preserves_order_and_duplicates() -> void:
	var publication: GFDataBatchPublication = GFDataBatchPublication.create(
		_schema(),
		&"fleet",
		3,
		100,
		72
	)
	var teams: PackedInt32Array = PackedInt32Array()
	var ids: PackedInt64Array = PackedInt64Array()
	assert_eq(
		teams.resize(100),
		OK
	)
	assert_eq(
		ids.resize(100),
		OK
	)
	for index: int in range(100):
		teams[index] = index
		ids[index] = 9_007_199_254_740_992 + index
	var source: Dictionary = { &"team": teams, &"life_id": ids }
	var rows: PackedInt32Array = PackedInt32Array(
		[
			7,
			1,
			7,
		]
	)
	assert_eq(
		publication.publish_gather_copy(
			source,
			90,
			100,
			rows,
			1,
			1
		),
		OK
	)
	var snapshot: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		snapshot.get_count(),
		3
	)
	assert_eq(
		snapshot.get_capacity(),
		3
	)
	assert_eq(
		snapshot.borrow_int32_column(0),
		PackedInt32Array(
			[
				7,
				1,
				7,
			]
		)
	)
	assert_eq(
		snapshot.borrow_int64_column(1),
		PackedInt64Array(
			[
				9_007_199_254_740_999,
				9_007_199_254_740_993,
				9_007_199_254_740_999,
			]
		)
	)
	assert_eq(
		_debug_int(publication, "last_copied_payload_bytes"),
		36
	)
	assert_eq(
		_debug_int(publication, "current_payload_bytes"),
		36
	)
	rows[0] = 2
	teams[7] = 99
	ids[7] = 99
	assert_eq(
		snapshot.borrow_int32_column(0)[0],
		7
	)
	assert_eq(
		snapshot.borrow_int64_column(1)[0],
		9_007_199_254_740_999
	)
	assert_eq(
		source.size(),
		2
	)
	assert_eq(
		publication.publish_gather_copy(
			source,
			90,
			100,
			rows,
			2,
			2
		),
		OK
	)
	assert_eq(
		publication.get_current().borrow_int32_column(0)[0],
		2
	)
	assert_eq(
		_debug_int(publication, "last_peak_payload_bytes"),
		72
	)


func test_gather_rejects_indices_outside_source_count_and_keeps_previous_batch() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	for rows: PackedInt32Array in [
		PackedInt32Array([-1]),
		PackedInt32Array([1]),
	]:
		assert_eq(
			publication.publish_gather_copy(
				_columns(),
				1,
				2,
				rows,
				2,
				2
			),
			ERR_INVALID_PARAMETER
		)
		assert_eq(
			publication.get_last_failure(),
			GFDataBatchPublication.Failure.INVALID_SELECTION
		)
		assert_same(
			publication.get_current(),
			original
		)
	assert_eq(
		publication.publish_gather_copy(
			{
				&"team": PackedInt32Array([1, 2]),
			},
			2,
			2,
			PackedInt32Array([0]),
			2,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.INVALID_COLUMN
	)
	assert_same(
		publication.get_current(),
		original
	)


func test_empty_gather_and_empty_source_have_valid_zero_row_snapshots() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_gather_copy(
			_columns(),
			2,
			2,
			PackedInt32Array(),
			0,
			0
		),
		OK
	)
	assert_eq(
		publication.get_current().get_count(),
		0
	)
	assert_eq(
		publication.get_current().get_payload_bytes(),
		0
	)
	var empty: Dictionary = { &"team": PackedInt32Array(), &"life_id": PackedInt64Array() }
	assert_eq(
		publication.publish_copy(
			empty,
			0,
			0,
			0,
			1
		),
		OK
	)
	assert_eq(
		publication.get_current().get_publication_sequence(),
		2
	)
	assert_eq(
		publication.publish_transfer(
			empty,
			0,
			0,
			0,
			2
		),
		OK
	)
	assert_true(empty.is_empty())


func test_payload_budget_includes_current_plus_candidate_and_failure_keeps_transfer_input() -> void:
	var publication: GFDataBatchPublication = GFDataBatchPublication.create(
		_schema(),
		&"fleet",
		3,
		10,
		47
	)
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	var source: Dictionary = _columns(9)
	assert_eq(
		publication.publish_transfer(
			source,
			2,
			2,
			1,
			2
		),
		ERR_OUT_OF_MEMORY
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.BYTE_BUDGET
	)
	assert_eq(
		source.size(),
		2
	)
	assert_same(
		publication.get_current(),
		original
	)
	assert_eq(
		_debug_int(publication, "last_required_payload_bytes"),
		48
	)
	assert_eq(
		_debug_int(publication, "last_peak_payload_bytes"),
		24
	)
	assert_eq(
		_debug_int(publication, "publication_sequence"),
		1
	)
	assert_eq(
		publication.publish_gather_copy(
			source,
			2,
			2,
			PackedInt32Array([0]),
			2,
			2
		),
		OK
	)
	assert_eq(
		_debug_int(publication, "last_peak_payload_bytes"),
		36
	)
	assert_eq(
		_debug_int(publication, "current_payload_bytes"),
		12
	)
	assert_eq(
		original.borrow_int32_column(0)[0],
		1
	)


func test_row_budget_covers_source_capacity_and_gather_output_size() -> void:
	var publication: GFDataBatchPublication = GFDataBatchPublication.create(
		_schema(),
		&"fleet",
		3,
		2,
		240
	)
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		publication.publish_gather_copy(
			_columns(),
			2,
			3,
			PackedInt32Array([0]),
			2,
			2
		),
		ERR_OUT_OF_MEMORY
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.ROW_BUDGET
	)
	assert_eq(
		publication.publish_gather_copy(
			_columns(),
			2,
			2,
			PackedInt32Array(
				[
					0,
					0,
					0,
				]
			),
			2,
			2
		),
		ERR_OUT_OF_MEMORY
	)
	assert_same(
		publication.get_current(),
		original
	)


func test_close_rejects_new_work_without_revoking_owned_snapshots_or_copies() -> void:
	var publication: GFDataBatchPublication = _owner()
	assert_eq(
		publication.publish_copy(
			_columns(),
			2,
			2,
			1,
			1
		),
		OK
	)
	var historical: GFDataBatchSnapshot = publication.get_current()
	var independent: PackedInt64Array = historical.copy_int64_column(1)
	publication.close()
	publication.close()
	assert_null(publication.get_current())
	assert_false(publication.is_current(historical))
	assert_eq(
		_debug_int(publication, "current_payload_bytes"),
		0
	)
	var source: Dictionary = _columns()
	assert_eq(
		publication.publish_copy(
			source,
			2,
			2,
			1,
			2
		),
		ERR_UNAVAILABLE
	)
	assert_eq(
		publication.publish_transfer(
			source,
			2,
			2,
			1,
			2
		),
		ERR_UNAVAILABLE
	)
	assert_eq(
		publication.publish_gather_copy(
			source,
			2,
			2,
			PackedInt32Array([0]),
			2,
			2
		),
		ERR_UNAVAILABLE
	)
	assert_eq(
		source.size(),
		2
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.CLOSED
	)
	assert_eq(
		historical.copy_int64_column(1),
		independent
	)
	independent[0] = -5
	assert_eq(
		historical.borrow_int64_column(1)[0],
		9_007_199_254_740_993
	)


# --- 私有/辅助方法 ---

func _schema() -> GFDataBatchSchema:
	return GFDataBatchSchema.create(
		&"fleet.projection",
		2,
		[&"team", &"life_id"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64])
	)


func _owner() -> GFDataBatchPublication:
	return GFDataBatchPublication.create(
		_schema(),
		&"fleet",
		3,
		10,
		240
	)


func _columns(first_team: int = 1) -> Dictionary:
	return {
		&"team": PackedInt32Array([first_team, 2]),
		&"life_id": PackedInt64Array([9_007_199_254_740_993, -9_007_199_254_740_993]),
	}


func _debug_int(publication: GFDataBatchPublication, key: String) -> int:
	var value: Variant = publication.get_debug_snapshot().get(key)
	assert_true(value is int)
	if value is int:
		var number: int = value
		return number
	return -1
