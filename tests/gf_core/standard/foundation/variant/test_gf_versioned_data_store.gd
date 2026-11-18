extends GutTest


func test_pinned_version_isolated_from_input_nested_aliases_and_new_commits() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	var shared: Dictionary = { "value": 4 }
	var row: Dictionary = { "a": shared, "b": shared }
	assert_true(
		_read_bool(
			store.commit(
				{},
				[row]
			),
			"ok"
		)
	)
	var previous: GFDataVersion = store.acquire_snapshot()
	shared["value"] = 90
	assert_true(
		_read_bool(
			store.commit(
				{
					0: { "new": 8 },
				},
				[
					{ "next": 9 },
				],
				1
			),
			"ok"
		)
	)
	assert_eq(
		previous.get_record_count(),
		1
	)
	assert_eq(
		previous.get_revision(),
		1
	)
	var old_row: GFDataSnapshot = previous.read_record(0)
	var first: Dictionary = old_row.get_value()
	var left: Dictionary = first["a"]
	var right: Dictionary = first["b"]
	left["value"] = 55
	assert_eq(
		_read_int(right, "value"),
		4
	)
	var old_value: int = old_row.get_value(["a", "value"])
	assert_eq(old_value, 4)
	var current: GFDataVersion = store.acquire_snapshot()
	var current_value: int = current.read_record(0).get_value(["new"])
	assert_eq(current_value, 8)
	previous.release()
	previous.release()
	assert_null(previous.read_record(0))
	old_value = old_row.get_value(["a", "value"])
	assert_eq(old_value, 4)
	current.release()
	_finish(store)


func test_page_boundaries_and_multiple_changes_preserve_old_root() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	var rows: Array = []
	for index: int in range(1100):
		rows.append(index)
	assert_true(
		_read_bool(
			store.commit({}, rows),
			"ok"
		)
	)
	var previous: GFDataVersion = store.acquire_snapshot()
	assert_true(
		_read_bool(
			store.commit(
				{
					0: -1,
					31: -2,
					32: -3,
					1023: -4,
					1024: -5,
				},
				[1100, 1101]
			),
			"ok"
		)
	)
	var current: GFDataVersion = store.acquire_snapshot()
	for index: int in [
		0,
		31,
		32,
		1023,
		1024,
	]:
		var old_value: int = previous.read_record(index).get_value()
		assert_eq(old_value, index)
	var replaced_value: int = current.read_record(1024).get_value()
	var appended_value: int = current.read_record(1101).get_value()
	assert_eq(replaced_value, -5)
	assert_eq(appended_value, 1101)
	previous.release()
	current.release()
	_finish(store)


func test_failed_transaction_has_no_partial_publication_or_revision_change() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create()
	assert_true(
		_read_bool(
			store.commit(
				{},
				[10, 20]
			),
			"ok"
		)
	)
	var cycle: Array = []
	cycle.append(cycle)
	var rejected: Dictionary = store.commit(
		{ 0: 90 },
		[cycle]
	)
	assert_false(_read_bool(rejected, "ok"))
	assert_eq(
		_read_string(rejected, "error_kind"),
		"invalid_record"
	)
	cycle.clear()
	assert_false(
		_read_bool(
			store.commit(
				{ 1: 80 },
				[],
				0
			),
			"ok"
		)
	)
	var version: GFDataVersion = store.acquire_snapshot()
	assert_eq(
		version.get_revision(),
		1
	)
	assert_eq(
		version.get_record_count(),
		2
	)
	var unchanged_value: int = version.read_record(0).get_value()
	assert_eq(unchanged_value, 10)
	version.release()
	_finish(store)


func test_version_reader_budgets_clear_and_close_keep_active_readers_valid() -> void:
	var store: GFVersionedDataStore = GFVersionedDataStore.create({ "max_versions": 2, "max_readers": 2 })
	assert_true(
		_read_bool(
			store.commit(
				{},
				[1]
			),
			"ok"
		)
	)
	var first: GFDataVersion = store.acquire_snapshot()
	assert_true(
		_read_bool(
			store.commit({ 0: 2 }),
			"ok"
		)
	)
	var second: GFDataVersion = store.acquire_snapshot()
	assert_null(store.acquire_snapshot())
	assert_eq(
		_read_string(
			store.commit({ 0: 3 }),
			"error_kind"
		),
		"version_limit"
	)
	first.release()
	assert_true(
		_read_bool(
			store.clear(),
			"ok"
		)
	)
	store.close()
	assert_null(store.acquire_snapshot())
	var retained_value: int = second.read_record(0).get_value()
	assert_eq(retained_value, 2)
	assert_false(
		_read_bool(
			store.commit(
				{},
				[4]
			),
			"ok"
		)
	)
	second.release()
	_finish(store)


func test_limits_reject_before_publication_and_pending_garbage_remains_charged() -> void:
	assert_null(GFVersionedDataStore.create({ "unknown": 1 }))
	assert_null(GFVersionedDataStore.create({ "max_nodes": 0 }))
	var store: GFVersionedDataStore = GFVersionedDataStore.create(
		{
			"max_owned_bytes": 8192,
			"max_record_items": 8,
			"max_record_payload_bytes": 64,
			"max_records": 100,
		}
	)
	assert_true(
		_read_bool(
			store.commit(
				{},
				[1, 2]
			),
			"ok"
		)
	)
	var rows: Array = []
	var _resized: Error = rows.resize(80) as Error
	rows.fill(3)
	assert_false(
		_read_bool(
			store.commit({}, rows),
			"ok"
		)
	)
	assert_eq(
		_read_int(
			store.get_statistics(),
			"count"
		),
		2
	)
	store.close()
	var before: Dictionary = store.get_statistics()
	assert_gt(
		_read_int(before, "pending_nodes"),
		0
	)
	assert_gt(
		_read_int(before, "charged_bytes"),
		0
	)
	assert_lte(
		store.collect_garbage(1),
		1
	)
	_finish(store)


func test_dropped_leases_release_accounting_and_failed_private_page_edits_do_not_escape() -> void:
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
	var lease: GFDataVersion = store.acquire_snapshot()
	var before_nodes: int = _read_int(
		store.get_statistics(),
		"nodes"
	)
	var another: GFDataVersion = store.acquire_snapshot()
	assert_eq(
		_read_int(
			store.get_statistics(),
			"nodes"
		),
		before_nodes
	)
	assert_true(another != null)
	another = null
	assert_eq(
		_read_int(
			store.get_statistics(),
			"readers"
		),
		1
	)
	var rejected: Dictionary = store.commit(
		{
			0: 99,
			1: 88,
			2: RefCounted.new(),
		}
	)
	assert_false(_read_bool(rejected, "ok"))
	var retained_value: int = lease.read_record(0).get_value()
	assert_eq(retained_value, 10)
	var current: GFDataVersion = store.acquire_snapshot()
	var current_value: int = current.read_record(1).get_value()
	assert_eq(current_value, 20)
	assert_eq(
		current.get_revision(),
		1
	)
	current = null
	lease = null
	_finish(store)
	var surviving_store: GFVersionedDataStore = GFVersionedDataStore.create()
	assert_true(
		_read_bool(
			surviving_store.commit(
				{},
				[41]
			),
			"ok"
		)
	)
	var surviving_lease: GFDataVersion = surviving_store.acquire_snapshot()
	surviving_store = null
	var surviving_value: int = surviving_lease.read_record(0).get_value()
	assert_eq(surviving_value, 41)
	surviving_lease.release()


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
			"charged_bytes"
		),
		0
	)
	assert_eq(
		_read_int(
			store.get_statistics(),
			"nodes"
		),
		0
	)
