extends GutTest


func test_example_and_empty_columns() -> void:
	var single: PackedInt64Array = PackedInt64Array([-1])
	_expect_rows(
		single,
		single,
		PackedInt32Array([0])
	)
	_expect_rows(
		PackedInt64Array([2]),
		single,
		PackedInt32Array([-1])
	)
	var previous: PackedInt64Array = PackedInt64Array(
		[
			10,
			20,
			55,
			56,
		]
	)
	var current: PackedInt64Array = PackedInt64Array(
		[
			20,
			31,
			56,
			60,
		]
	)
	_expect_rows(
		previous,
		current,
		PackedInt32Array(
			[
				1,
				-1,
				3,
				-1,
			]
		)
	)
	_expect_rows(
		previous,
		previous,
		PackedInt32Array(
			[
				0,
				1,
				2,
				3,
			]
		)
	)
	_expect_rows(
		previous,
		PackedInt64Array(
			[
				10,
				20,
				55,
				56,
				70,
			]
		),
		PackedInt32Array(
			[
				0,
				1,
				2,
				3,
				-1,
			]
		)
	)
	_expect_rows(
		previous,
		PackedInt64Array([56, 10]),
		PackedInt32Array([3, 0])
	)
	_expect_rows(
		previous,
		PackedInt64Array(),
		PackedInt32Array()
	)
	_expect_rows(
		PackedInt64Array(),
		current,
		PackedInt32Array(
			[
				-1,
				-1,
				-1,
				-1,
			]
		)
	)
	_expect_rows(
		PackedInt64Array(),
		PackedInt64Array(),
		PackedInt32Array()
	)


func test_borrowed_columns_use_only_their_valid_prefix_and_results_are_independent() -> void:
	var schema: GFDataBatchSchema = GFDataBatchSchema.create(
		&"ids",
		1,
		[&"id"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT64])
	)
	var publication: GFDataBatchPublication = GFDataBatchPublication.create(
		schema,
		&"test",
		1,
		6,
		128
	)
	assert_eq(
		publication.publish_copy(
			{
				&"id": PackedInt64Array(
					[
						30,
						10,
						20,
						99,
						10,
					]
				),
			},
			3,
			5,
			1,
			1
		),
		OK
	)
	var previous: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		publication.publish_copy(
			{
				&"id": PackedInt64Array(
					[
						99,
						30,
						20,
						99,
					]
				),
			},
			3,
			4,
			2,
			2
		),
		OK
	)
	var current: GFDataBatchSnapshot = publication.get_current()
	var old_ids: PackedInt64Array = previous.borrow_int64_column(0)
	var ids: PackedInt64Array = current.borrow_int64_column(0)
	var first: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
		old_ids,
		previous.get_count(),
		ids,
		current.get_count()
	)
	var second: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
		old_ids,
		previous.get_count(),
		ids,
		current.get_count()
	)
	assert_eq(first.error, OK)
	assert_eq(second.error, OK)
	assert_eq(
		first.previous_rows,
		PackedInt32Array(
			[
				-1,
				0,
				2,
			]
		)
	)
	if not first.previous_rows.is_empty():
		first.previous_rows[0] = 42
	assert_eq(
		second.previous_rows,
		PackedInt32Array(
			[
				-1,
				0,
				2,
			]
		)
	)
	assert_eq(
		old_ids,
		PackedInt64Array(
			[
				30,
				10,
				20,
				99,
				10,
			]
		)
	)
	assert_eq(
		ids,
		PackedInt64Array(
			[
				99,
				30,
				20,
				99,
			]
		)
	)
	publication.close()


func test_duplicate_ids_fail_even_when_the_other_column_is_empty() -> void:
	var unique: PackedInt64Array = PackedInt64Array(
		[
			1,
			2,
			3,
			4,
		]
	)
	for repeated_ids: PackedInt64Array in [
		PackedInt64Array([1, 1]),
		PackedInt64Array(
			[
				2,
				3,
				4,
				2,
			]
		),
		PackedInt64Array(
			[
				-1,
				7,
				-1,
			]
		),
	]:
		for other: PackedInt64Array in [PackedInt64Array(), unique]:
			var old_duplicate: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
				repeated_ids,
				repeated_ids.size(),
				other,
				other.size()
			)
			var new_duplicate: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
				other,
				other.size(),
				repeated_ids,
				repeated_ids.size()
			)
			assert_eq(old_duplicate.error, ERR_INVALID_DATA)
			assert_eq(new_duplicate.error, ERR_INVALID_DATA)
			assert_true(old_duplicate.previous_rows.is_empty())
			assert_true(new_duplicate.previous_rows.is_empty())


func test_out_of_bounds_counts_return_an_error_distinct_from_empty_success() -> void:
	var ids: PackedInt64Array = PackedInt64Array([9])
	for invalid: int in [
		-1,
		2,
		2_147_483_648,
	]:
		var old_invalid: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
			ids,
			invalid,
			ids,
			0
		)
		var new_invalid: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
			ids,
			0,
			ids,
			invalid
		)
		assert_eq(old_invalid.error, ERR_INVALID_PARAMETER)
		assert_eq(new_invalid.error, ERR_INVALID_PARAMETER)
		assert_true(old_invalid.previous_rows.is_empty())
		assert_true(new_invalid.previous_rows.is_empty())


func test_signed_int64_permutations_match_an_independent_linear_search() -> void:
	var pool: PackedInt64Array = PackedInt64Array(
		[
			-9223372036854775807 - 1,
			-2,
			-1,
			0,
			1,
			1 << 60,
			(1 << 60) + 1,
			9223372036854775807,
		]
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 285
	for trial: int in range(80):
		var previous: PackedInt64Array = _shuffled_prefix(pool, rng)
		var current: PackedInt64Array = _shuffled_prefix(pool, rng)
		var expected: PackedInt32Array = PackedInt32Array()
		for id: int in current:
			var _appended: bool = expected.append(previous.find(id))
		_expect_rows(
			previous,
			current,
			expected
		)


func _expect_rows(
	previous: PackedInt64Array,
	current: PackedInt64Array,
	expected: PackedInt32Array
) -> void:
	var result: GFDataBatchRowMatch = GFDataBatchRowMatch.match_ids(
		previous,
		previous.size(),
		current,
		current.size()
	)
	assert_eq(result.error, OK)
	assert_eq(result.previous_rows, expected)


func _shuffled_prefix(pool: PackedInt64Array, rng: RandomNumberGenerator) -> PackedInt64Array:
	var ids: PackedInt64Array = pool.duplicate()
	for index: int in range(
		ids.size() - 1,
		0,
		-1
	):
		var other: int = rng.randi_range(0, index)
		var id: int = ids[index]
		ids[index] = ids[other]
		ids[other] = id
	return ids.slice(
		0,
		rng.randi_range(
			0,
			ids.size()
		)
	)
