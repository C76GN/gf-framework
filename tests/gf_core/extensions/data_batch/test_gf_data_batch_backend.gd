extends GutTest


func test_backend_selection_is_explicit_and_fixed_before_any_publish() -> void:
	var unsupported: GFDataBatchBackend = GFDataBatchBackend.new()
	assert_null(_owner(null, true))
	assert_null(_owner(unsupported, true))
	var fallback: GFDataBatchPublication = _owner(unsupported, false)
	assert_false(
		_read_bool(
			fallback.get_debug_snapshot(),
			"backend_selected"
		)
	)
	assert_eq(
		_publish(fallback),
		OK
	)
	var backend: _Backend = _Backend.new()
	var publication: GFDataBatchPublication = _owner(backend, true)
	assert_true(
		_read_bool(
			publication.get_debug_snapshot(),
			"backend_selected"
		)
	)
	assert_eq(
		_publish(publication),
		OK
	)
	assert_eq(backend.calls, 1)
	assert_eq(
		publication.get_current().copy_int64_column(1),
		PackedInt64Array(
			[
				9223372036854775807,
				-9223372036854775807 - 1,
				9223372036854775807,
			]
		)
	)


func test_validation_precedes_backend_and_no_error_fallback_occurs() -> void:
	var backend: _Backend = _Backend.new()
	var publication: GFDataBatchPublication = _owner(backend, true)
	assert_eq(
		_publish(publication),
		OK
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	assert_eq(
		publication.publish_gather_copy(
			_columns(),
			2,
			3,
			PackedInt32Array([2]),
			2,
			2
		),
		ERR_INVALID_PARAMETER
	)
	assert_eq(backend.calls, 1)
	backend.malformed = true
	assert_eq(
		_publish(publication, 2),
		ERR_INVALID_DATA
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.BACKEND_FAILED
	)
	assert_same(
		publication.get_current(),
		original
	)
	assert_eq(
		_read_int(
			publication.get_debug_snapshot(),
			"publication_sequence"
		),
		1
	)


func test_backend_scratch_budget_is_reserved_before_computation() -> void:
	var backend: _Backend = _Backend.new()
	backend.scratch = 10000
	var publication: GFDataBatchPublication = _owner(backend, true)
	assert_eq(
		_publish(publication),
		ERR_OUT_OF_MEMORY
	)
	assert_eq(
		publication.get_last_failure(),
		GFDataBatchPublication.Failure.BYTE_BUDGET
	)
	assert_eq(backend.calls, 0)
	assert_null(publication.get_current())
	assert_eq(
		_read_int(
			publication.get_debug_snapshot(),
			"last_required_payload_bytes"
		),
		10036
	)
	backend.scratch = 9_223_372_036_854_775_807
	assert_eq(
		_publish(publication),
		ERR_OUT_OF_MEMORY
	)
	assert_eq(
		_read_int(
			publication.get_debug_snapshot(),
			"last_required_payload_bytes"
		),
		9_223_372_036_854_775_807
	)


func test_nested_publish_is_rejected_and_close_revokes_outer_commit() -> void:
	var backend: _Backend = _Backend.new()
	var publication: GFDataBatchPublication = _owner(backend, true)
	backend.owner_ref = weakref(publication)
	backend.reenter = true
	assert_eq(
		_publish(publication),
		OK
	)
	assert_eq(backend.nested_error, ERR_BUSY)
	assert_eq(
		_read_int(
			publication.get_debug_snapshot(),
			"publication_sequence"
		),
		1
	)
	var original: GFDataBatchSnapshot = publication.get_current()
	backend.close_owner = true
	assert_eq(
		_publish(publication, 2),
		ERR_UNAVAILABLE
	)
	assert_null(publication.get_current())
	assert_eq(
		original.get_count(),
		3
	)
	assert_false(
		_read_bool(
			publication.get_debug_snapshot(),
			"backend_busy"
		)
	)


func test_worker_creation_never_calls_an_explicit_backends_protocol() -> void:
	var backend: _Backend = _Backend.new()
	for required: bool in [false, true]:
		var worker: Thread = Thread.new()
		var construct: Callable = _owner.bind(backend, required)
		var started: Error = worker.start(construct)
		assert_eq(started, OK)
		if started != OK:
			return
		var value: Variant = worker.wait_to_finish()
		if required:
			assert_true(value == null)
		else:
			assert_true(value is GFDataBatchPublication)
			if value is GFDataBatchPublication:
				var publication: GFDataBatchPublication = value
				assert_eq(
					_publish(publication),
					OK
				)
				publication.close()
	assert_eq(backend.handshakes, 0)
	assert_eq(backend.calls, 0)


func test_missing_native_library_does_not_become_a_framework_dependency() -> void:
	var schema: GFDataBatchSchema = GFDataBatchSchema.create(
		&"portable",
		1,
		[&"value"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT32])
	)
	var automatic: GFDataBatchPublication = GFDataBatchPublication.create(
		schema,
		&"test",
		1,
		2,
		64
	)
	assert_not_null(automatic)
	if not Engine.has_singleton(&"GfPackedGatherBackend"):
		assert_null(GFDataBatchNativeBackend.create())
		assert_false(
			_read_bool(
				automatic.get_debug_snapshot(),
				"backend_selected"
			)
		)
	var scripted: GFDataBatchPublication = _owner(null, false)
	assert_eq(
		_publish(scripted),
		OK
	)


func _read_bool(record: Dictionary, key: String) -> bool:
	assert_true(record.has(key))
	var value: Variant = record.get(key)
	assert_true(value is bool)
	if value is bool:
		var typed: bool = value
		return typed
	return false


func _read_int(record: Dictionary, key: String) -> int:
	assert_true(record.has(key))
	var value: Variant = record.get(key)
	assert_true(value is int)
	if value is int:
		var typed: int = value
		return typed
	return -1


func _owner(backend: GFDataBatchBackend, required: bool) -> GFDataBatchPublication:
	var schema: GFDataBatchSchema = GFDataBatchSchema.create(
		&"numeric",
		1,
		[&"narrow", &"wide"],
		PackedInt32Array([GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64])
	)
	return GFDataBatchPublication.create(
		schema,
		&"test",
		1,
		20,
		1024,
		backend,
		required
	)


func _columns() -> Dictionary:
	return {
		&"narrow": PackedInt32Array(
			[
				-2147483648,
				2147483647,
				999,
			]
		),
		&"wide": PackedInt64Array(
			[
				-9223372036854775807 - 1,
				9223372036854775807,
				999,
			]
		),
	}


func _publish(publication: GFDataBatchPublication, revision: int = 1) -> Error:
	return publication.publish_gather_copy(
		_columns(),
		2,
		3,
		PackedInt32Array(
			[
				1,
				0,
				1,
			]
		),
		revision,
		revision
	)


class _Backend extends GFDataBatchBackend:
	var calls: int = 0
	var handshakes: int = 0
	var scratch: int = 0
	var malformed: bool = false
	var owner_ref: WeakRef = null
	var reenter: bool = false
	var close_owner: bool = false
	var nested_error: Error = OK


	func get_protocol_version() -> int:
		handshakes += 1
		return 1


	func supports_type(numeric_type: int) -> bool:
		handshakes += 1
		return numeric_type in [GFDataBatchSchema.NumericType.INT32, GFDataBatchSchema.NumericType.INT64]


	func get_scratch_bytes(_output_bytes: int) -> int:
		return scratch


	func gather(
		columns: Array,
		indices: PackedInt32Array,
		source_count: int
	) -> Array:
		calls += 1
		if malformed:
			return [PackedInt64Array(), PackedInt64Array()]
		if owner_ref != null:
			var value: Variant = owner_ref.get_ref()
			if value is GFDataBatchPublication:
				var owner: GFDataBatchPublication = value
				if reenter:
					nested_error = owner.publish_copy(
						{},
						0,
						0,
						10,
						10
					)
				if close_owner:
					owner.close()
		var result: Array = []
		for column: Variant in columns:
			if column is PackedInt32Array:
				var input: PackedInt32Array = column
				var output: PackedInt32Array = PackedInt32Array()
				for index: int in indices:
					if index >= source_count:
						return []
					var _appended: bool = output.append(input[index])
				result.append(output)
			else:
				var input: PackedInt64Array = column
				var output: PackedInt64Array = PackedInt64Array()
				for index: int in indices:
					var _appended: bool = output.append(input[index])
				result.append(output)
		return result
