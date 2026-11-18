extends GutTest


func test_shared_frame_budget_pauses_without_reset_and_pins_original_version() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	assert_true(
		_read_bool(
			store.commit(
				{},
				[
					10,
					20,
					30,
				]
			),
			"ok"
		)
	)
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 1, "max_elapsed_msec": 0 })
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	assert_eq(
		_read_int(
			capture.get_report(),
			"processed_records"
		),
		1
	)
	assert_null(capture.get_snapshot())
	assert_true(
		_read_bool(
			store.commit({ 0: 90 }),
			"ok"
		)
	)
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	assert_eq(
		_read_int(
			capture.get_report(),
			"processed_records"
		),
		1
	)
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"ready"
	)
	var snapshot: GFDataSnapshot = capture.get_snapshot()
	var captured_values: Array = snapshot.get_value()
	assert_eq(
		captured_values,
		[
			10,
			20,
			30,
		]
	)
	assert_eq(
		_read_int(
			snapshot.get_statistics(),
			"items"
		),
		4
	)
	assert_eq(
		_read_int(
			snapshot.get_statistics(),
			"payload_bytes"
		),
		24
	)
	capture = null
	snapshot = null
	_finish(store)


func test_cancel_does_not_publish_and_releases_after_incremental_cleanup() -> void:
	var source: _Source = _Source.new()
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source)
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 2, "max_elapsed_msec": 0 })
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	capture.cancel()
	capture.cancel()
	assert_null(capture.get_snapshot())
	assert_eq(source.releases, 0)
	assert_false(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	budget.max_steps = 1
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"cancelled"
	)
	assert_false(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	budget.reset()
	var _state: String = capture.advance(budget)
	assert_true(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	assert_eq(source.releases, 1)
	var _again: String = capture.advance(budget)
	assert_eq(source.releases, 1)


func test_adapter_version_change_and_reentrant_cancel_never_publish() -> void:
	var changing: _Source = _Source.new()
	changing.change_revision = true
	var rejected: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(changing)
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 20, "max_elapsed_msec": 0 })
	assert_eq(
		rejected.advance(budget),
		"failed"
	)
	assert_eq(
		_read_string(
			rejected.get_report(),
			"error_kind"
		),
		"source_changed"
	)
	assert_true(
		_read_bool(
			rejected.get_report(),
			"settled"
		)
	)
	var cancelling: _Source = _Source.new()
	var cancelled: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(cancelling)
	cancelling.capture_ref = weakref(cancelled)
	budget.reset()
	assert_eq(
		cancelled.advance(budget),
		"cancelled"
	)
	assert_false(cancelling.released_during_read)
	assert_eq(cancelling.releases, 1)


func test_active_time_age_and_frame_time_are_distinct_with_manual_clock() -> void:
	var clock: GFManualClock = GFManualClock.new()
	var source: _Source = _Source.new()
	source.clock = clock
	source.read_msec = 3
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(
		source,
		{ "max_work_msec": 5, "max_age_msec": 100 },
		clock
	)
	var budget: GFExecutionBudget = GFExecutionBudget.new(
		{ "max_steps": 1, "max_elapsed_msec": 2 },
		clock
	)
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	assert_eq(
		_read_int(
			capture.get_report(),
			"work_msec"
		),
		3
	)
	assert_true(clock.advance_msec(50))
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"failed"
	)
	assert_eq(
		_read_string(
			capture.get_report(),
			"error_kind"
		),
		"work_limit"
	)
	budget.reset()
	var _settled: String = capture.advance(budget)
	assert_true(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	var old_source: _Source = _Source.new()
	var aged: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(
		old_source,
		{ "max_age_msec": 5 },
		clock
	)
	assert_true(clock.advance_msec(6))
	budget.reset()
	assert_eq(
		aged.advance(budget),
		"failed"
	)
	assert_eq(
		_read_string(
			aged.get_report(),
			"error_kind"
		),
		"age_limit"
	)
	assert_eq(old_source.reads, 0)


func test_cumulative_limit_failure_keeps_game_commits_and_output_unpublished() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	assert_true(
		_read_bool(
			store.commit(
				{},
				[
					1,
					2,
					3,
				]
			),
			"ok"
		)
	)
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(
		store.acquire_snapshot(),
		{ "max_payload_bytes": 16 }
	)
	assert_true(
		_read_bool(
			store.commit({ 0: 99 }),
			"ok"
		)
	)
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 20, "max_elapsed_msec": 0 })
	assert_eq(
		capture.advance(budget),
		"failed"
	)
	assert_eq(
		_read_string(
			capture.get_report(),
			"error_kind"
		),
		"payload_limit"
	)
	assert_true(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	assert_null(capture.get_snapshot())
	var current: GFDataVersion = store.acquire_snapshot()
	var current_value: int = current.read_record(0).get_value()
	assert_eq(current_value, 99)
	current.release()
	_finish(store)


func test_empty_source_and_typed_nested_values_match_synchronous_capture() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	var empty: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
	assert_eq(
		empty.advance(budget),
		"ready"
	)
	var empty_values: Array = empty.get_snapshot().get_value()
	assert_eq(empty_values, [])
	empty = null
	var typed: Array[int] = [1, 2]
	var mapping: Dictionary[String, int] = { "one": 1 }
	var rows: Array = [
		typed,
		mapping,
		PackedInt64Array([-9223372036854775807 - 1, 9223372036854775807]),
	]
	assert_true(
		_read_bool(
			store.commit({}, rows),
			"ok"
		)
	)
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
	assert_eq(
		capture.advance(budget),
		"ready"
	)
	var sync: GFDataSnapshot = GFDataSnapshot.capture(rows)["snapshot"]
	var actual_values: Array = capture.get_snapshot().get_value()
	var expected_values: Array = sync.get_value()
	assert_eq(actual_values, expected_values)
	assert_eq(
		_read_int(
			capture.get_snapshot().get_statistics(),
			"items"
		),
		_read_int(
			sync.get_statistics(),
			"items"
		)
	)
	assert_eq(
		_read_int(
			capture.get_snapshot().get_statistics(),
			"payload_bytes"
		),
		_read_int(
			sync.get_statistics(),
			"payload_bytes"
		)
	)
	assert_eq(
		_read_int(
			capture.get_snapshot().get_statistics(),
			"maximum_depth"
		),
		_read_int(
			sync.get_statistics(),
			"maximum_depth"
		)
	)
	var copied: Array = capture.get_snapshot().get_value([0])
	assert_eq(
		copied.get_typed_builtin(),
		TYPE_INT
	)
	capture = null
	_finish(store)


func test_submillisecond_slices_accumulate_work_and_empty_cancel_does_not_publish() -> void:
	var clock: GFManualClock = GFManualClock.new()
	var source: _Source = _Source.new()
	source.clock = clock
	source.read_usec = 600
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(
		source,
		{ "max_work_msec": 1 },
		clock
	)
	var budget: GFExecutionBudget = GFExecutionBudget.new(
		{ "max_steps": 1, "max_elapsed_msec": 0 },
		clock
	)
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"failed"
	)
	assert_eq(
		_read_string(
			capture.get_report(),
			"error_kind"
		),
		"work_limit"
	)
	budget.reset()
	var _settled: String = capture.advance(budget)
	assert_eq(source.releases, 1)
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	var empty: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
	empty.cancel()
	budget.reset()
	assert_eq(
		empty.advance(budget),
		"cancelled"
	)
	assert_null(empty.get_snapshot())
	_finish(store)


func test_record_depth_and_atomic_record_size_limits_reject_adapter_output() -> void:
	for limits: Dictionary in [
		{ "max_record_items": 1 },
		{ "max_depth": 1 },
		{ "max_record_payload_bytes": 1 },
	]:
		var source: _Source = _Source.new()
		source.nested = true
		var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source, limits)
		var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
		assert_eq(
			capture.advance(budget),
			"failed"
		)
		assert_null(capture.get_snapshot())
		assert_eq(source.releases, 1)
		assert_eq(source.reads, 1)


func test_adapter_record_owner_pins_nested_version_until_result_or_cancel_cleanup() -> void:
	for cancel_capture: bool in [false, true]:
		var store: GFVersionedDataStore = GFVersionedDataStore.create()
		assert_true(
			_read_bool(
				store.commit(
					{},
					[5]
				),
				"ok"
			)
		)
		var source: _NestedSource = _NestedSource.new()
		source.store = store
		source.count = 2 if cancel_capture else 1
		var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source)
		var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 1, "max_elapsed_msec": 0 })
		assert_eq(
			capture.advance(budget),
			"pending" if cancel_capture else "ready"
		)
		assert_true(
			_read_bool(
				store.clear(),
				"ok"
			)
		)
		var _collected: int = store.collect_garbage(100)
		assert_eq(
			_read_int(
				store.get_statistics(),
				"readers"
			),
			1
		)
		assert_gt(
			_read_int(
				store.get_statistics(),
				"charged_bytes"
			),
			0
		)
		if cancel_capture:
			capture.cancel()
			budget.reset()
			assert_eq(
				capture.advance(budget),
				"cancelled"
			)
			assert_true(
				_read_bool(
					capture.get_report(),
					"settled"
				)
			)
		else:
			var value: int = capture.get_snapshot().get_value([0, 0])
			assert_eq(value, 5)
		capture = null
		assert_eq(
			_read_int(
				store.get_statistics(),
				"readers"
			),
			0
		)
		_finish(store)


func test_custom_record_and_capture_limits_survive_public_reads() -> void:
	var nested: Variant = 7
	for _depth: int in range(70):
		nested = [nested]
	var store: GFVersionedDataStore = GFVersionedDataStore.create({ "max_record_depth": 80 })
	assert_true(
		_read_bool(
			store.commit(
				{},
				[nested]
			),
			"ok"
		)
	)
	var version: GFDataVersion = store.acquire_snapshot()
	var record: GFDataSnapshot = version.read_record(0)
	assert_not_null(record)
	if record != null:
		assert_true(
			_read_bool(
				record.copy_value(),
				"ok"
			)
		)
	version.release()
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(
		store.acquire_snapshot(),
		{ "max_depth": 80 }
	)
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
	assert_eq(
		capture.advance(budget),
		"ready"
	)
	assert_true(
		_read_bool(
			capture.get_snapshot().copy_value(),
			"ok"
		)
	)
	var copied: Array = capture.get_snapshot().get_value()
	assert_eq(
		copied.size(),
		1
	)
	assert_false(
		_read_bool(
			capture.get_snapshot().copy_value({ "max_depth": 10 }),
			"ok"
		)
	)
	capture = null
	_finish(store)


func test_token_cancellation_wins_after_sticky_exhaustion_and_during_last_read() -> void:
	var cancellation: GFCancellationSource = GFCancellationSource.new()
	var budget: GFExecutionBudget = GFExecutionBudget.new(
		{
			"max_steps": 1,
			"max_elapsed_msec": 0,
			"cancel_token": cancellation.get_token(),
		}
	)
	assert_true(budget.consume_steps())
	assert_false(budget.consume_steps())
	assert_true(cancellation.cancel())
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	var empty: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
	assert_eq(
		empty.advance(budget),
		"cancelled"
	)
	assert_null(empty.get_snapshot())
	_finish(store)
	var last_cancellation: GFCancellationSource = GFCancellationSource.new()
	var source: _Source = _Source.new()
	source.cancel_on_last = last_cancellation
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source)
	var last_budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0, "cancel_token": last_cancellation.get_token() })
	assert_eq(
		capture.advance(last_budget),
		"cancelled"
	)
	assert_null(capture.get_snapshot())
	assert_eq(source.reads, 3)
	var cleanup: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
	var _settled: String = capture.advance(cleanup)
	assert_eq(source.releases, 1)


func test_record_release_reentry_cannot_spend_more_than_cleanup_budget() -> void:
	var probe: _ReleaseProbe = _ReleaseProbe.new()
	var source: _ReentrantRecordsSource = _ReentrantRecordsSource.new()
	source.probe = probe
	var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source)
	probe.capture_ref = weakref(capture)
	var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_steps": 2, "max_elapsed_msec": 0 })
	assert_eq(
		capture.advance(budget),
		"pending"
	)
	capture.cancel()
	budget.max_steps = 1
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"cancelled"
	)
	assert_eq(probe.releases, 1)
	assert_false(
		_read_bool(
			capture.get_report(),
			"settled"
		)
	)
	budget.reset()
	assert_eq(
		capture.advance(budget),
		"cancelled"
	)
	assert_eq(probe.releases, 2)
	assert_true(
		_read_bool(
			capture.get_report(),
			"settled"
		)
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


func _read_string(record: Dictionary, key: String) -> String:
	assert_true(record.has(key))
	var value: Variant = record.get(key)
	assert_true(value is String)
	if value is String:
		var typed: String = value
		return typed
	return ""


func _finish(store: GFVersionedDataStore) -> void:
	store.close()
	var rounds: int = 0
	while _read_int(
		store.get_statistics(),
		"pending_nodes"
	) > 0 and rounds < 10000:
		var _collected: int = store.collect_garbage(64)
		rounds += 1
	assert_eq(
		_read_int(
			store.get_statistics(),
			"readers"
		),
		0
	)
	assert_eq(
		_read_int(
			store.get_statistics(),
			"charged_bytes"
		),
		0
	)


class _NestedSource extends GFDataSnapshotSource:
	var store: GFVersionedDataStore = null
	var count: int = 1


	func _get_record_count() -> int:
		return count


	func _get_revision() -> int:
		return 1


	func _read_record(_index: int) -> GFDataSnapshot:
		var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(store.acquire_snapshot())
		var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
		if capture.advance(budget) != "ready":
			return null
		return capture.get_snapshot()


class _Source extends GFDataSnapshotSource:
	var revision: int = 1
	var reads: int = 0
	var releases: int = 0
	var change_revision: bool = false
	var capture_ref: WeakRef = null
	var clock: GFManualClock = null
	var read_msec: int = 0
	var read_usec: int = 0
	var nested: bool = false
	var cancel_on_last: GFCancellationSource = null
	var released_during_read: bool = false


	func _get_record_count() -> int:
		return 3


	func _get_revision() -> int:
		return revision


	func _read_record(index: int) -> GFDataSnapshot:
		reads += 1
		if cancel_on_last != null and index == 2:
			var _cancelled: bool = cancel_on_last.cancel()
		if change_revision:
			revision += 1
		if clock != null:
			var _advanced: bool = clock.advance_msec(read_msec)
			var _advanced_usec: bool = clock.advance_usec(read_usec)
		if capture_ref != null:
			var value: Variant = capture_ref.get_ref()
			if value is GFDataSnapshotCapture:
				var capture: GFDataSnapshotCapture = value
				capture.cancel()
			released_during_read = releases > 0
		if nested:
			return GFDataSnapshot.capture(
				[
					[index],
				]
			)["snapshot"]
		return GFDataSnapshot.capture(index)["snapshot"]


	func _release() -> void:
		releases += 1


class _ReleaseProbe extends RefCounted:
	var releases: int = 0
	var capture_ref: WeakRef = null


class _ReentrantRecordsSource extends _Source:
	var probe: _ReleaseProbe = null


	func _read_record(_index: int) -> GFDataSnapshot:
		var source: _ReentrantReleaseSource = _ReentrantReleaseSource.new()
		source.probe = probe
		var capture: GFDataSnapshotCapture = GFDataSnapshotCapture.begin(source)
		var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
		if capture.advance(budget) != "ready":
			return null
		return capture.get_snapshot()


class _ReentrantReleaseSource extends _Source:
	var probe: _ReleaseProbe = null


	func _get_record_count() -> int:
		return 1


	func _release() -> void:
		probe.releases += 1
		var value: Variant = probe.capture_ref.get_ref()
		if value is GFDataSnapshotCapture:
			var capture: GFDataSnapshotCapture = value
			var budget: GFExecutionBudget = GFExecutionBudget.new({ "max_elapsed_msec": 0 })
			var _state: String = capture.advance(budget)
