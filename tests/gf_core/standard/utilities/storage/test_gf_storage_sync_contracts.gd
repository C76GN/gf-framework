## 冻结同步请求和协议边界的准入回归。
extends GutTest


# --- 测试方法 ---

func test_request_preflight_reuses_factory_validation_without_copying_unsafe_values() -> void:
	var cycle: Dictionary = {}
	cycle["self"] = cycle
	var cases: Array[Dictionary] = [
		{
			"data": { "safe": 2 },
			"options": {},
			"ok": true,
			"kind": &"",
		},
		{
			"data": {},
			"options": { "mode": &"invalid" },
			"ok": false,
			"kind": &"invalid_mode",
		},
		{
			"data": {},
			"options": { "unknown": true },
			"ok": false,
			"kind": &"unknown_option",
		},
		{
			"data": cycle,
			"options": {},
			"ok": false,
			"kind": &"invalid_request_data",
		},
	]
	for entry: Dictionary in cases:
		var data: Dictionary = entry["data"]
		var options: Dictionary = entry["options"]
		var report: Dictionary = GFStorageSyncRequest.validate_input(
			"account",
			"key",
			"op",
			data,
			options
		)
		assert_eq(
			GFVariantData.get_option_bool(report, "ok"),
			GFVariantData.get_option_bool(entry, "ok")
		)
		assert_eq(
			GFVariantData.get_option_string_name(report, "error_kind"),
			GFVariantData.get_option_string_name(entry, "kind")
		)
		assert_eq(
			GFStorageSyncRequest.create(
				"account",
				"key",
				"op",
				data,
				options
			) != null,
			GFVariantData.get_option_bool(entry, "ok")
		)
		assert_false(report.has("data"))
		assert_false(report.has("namespace"))
	cycle.clear()
	var limits: Dictionary = GFStorageSyncRequest.get_limits()
	limits["max_output_bytes"] = 1
	assert_eq(
		GFVariantData.get_option_int(
			GFStorageSyncRequest.get_limits(),
			"max_output_bytes"
		),
		16777216
	)
	var deep: Dictionary = {}
	var cursor: Dictionary = deep
	for index: int in range(65):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	var budget: Dictionary = GFStorageSyncRequest.validate_input(
		"account",
		"key",
		"op",
		deep
	)
	assert_eq(
		GFVariantData.get_option_string_name(budget, "error_kind"),
		&"request_budget_exceeded"
	)
	var observed: Dictionary = budget["observed"]
	assert_eq(
		GFVariantData.get_option_string(observed, "limit_kind"),
		"max_depth"
	)
	assert_true(GFVariantData.get_option_bool(observed, "observed_is_lower_bound"))
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"key",
			"op",
			deep
		)
	)


func test_request_roundtrip_is_strict_and_isolated() -> void:
	var data: Dictionary = {
		"nested": { "value": 2 },
	}
	var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"account",
		"profile",
		"op",
		data,
		{ "expected_revision": "etag:009", "local_generation": 5 }
	)
	assert_not_null(request)
	if request == null:
		return
	data["nested"] = 8
	var copy: Dictionary = request.get_data()
	assert_true(
		_matches(
			copy,
			{
				"nested": { "value": 2 },
			}
		)
	)
	copy.clear()
	assert_false(request.get_data().is_empty())
	var record: Dictionary = request.to_record()
	var restored: GFStorageSyncRequest = GFStorageSyncRequest.from_record(record)
	assert_not_null(restored)
	assert_eq(
		restored.get_expected_revision(),
		"etag:009"
	)
	assert_eq(
		restored.get_local_generation(),
		5
	)
	record["data"] = {}
	assert_false(restored.get_data().is_empty())
	assert_false(request.get_debug_snapshot().has("data"))
	assert_false(request.get_debug_snapshot().has("namespace"))


func test_request_rejects_coercion_unknown_options_and_ambiguous_identity() -> void:
	assert_null(
		GFStorageSyncRequest.create(
			" account",
			"profile",
			"op"
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op\nnext"
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op",
			{},
			{ "local_generation": 1.0 }
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op",
			{},
			{ "expected_revision": 2 }
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op",
			{},
			{ "timeout_msec": 0 }
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op",
			{},
			{ "mode": "unknown" }
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"account",
			"profile",
			"op",
			{},
			{ "resolution": "newest" }
		)
	)
	var valid: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"account",
		"profile",
		"op"
	)
	var record: Dictionary = valid.to_record()
	record["extra"] = true
	assert_null(GFStorageSyncRequest.from_record(record))
	var _removed: bool = record.erase("extra")
	_removed = record.erase("mode")
	assert_null(GFStorageSyncRequest.from_record(record))


func test_request_rejects_unsafe_values_before_copy() -> void:
	assert_null(
		GFStorageSyncRequest.create(
			"n",
			"k",
			"op",
			{ "object": Resource.new() }
		)
	)
	assert_null(
		GFStorageSyncRequest.create(
			"n",
			"k",
			"op",
			{ "nan": NAN }
		)
	)
	var loop: Dictionary = {}
	loop["self"] = loop
	assert_null(
		GFStorageSyncRequest.create(
			"n",
			"k",
			"op",
			loop
		)
	)
	loop.clear()
	assert_null(
		GFStorageSyncRequest.create(
			"n",
			"k",
			"op",
			{ "bytes": "x".repeat(16777217) }
		)
	)


func test_default_transport_and_journal_do_not_claim_capabilities_or_persistence() -> void:
	var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"n",
		"k",
		"op"
	)
	var transport: GFStorageSyncTransport = GFStorageSyncTransport.new()
	assert_false(
		GFVariantData.get_option_bool(
			transport.get_capabilities(),
			"conditional_write"
		)
	)
	assert_true(transport.read(request).is_failed())
	assert_true(transport.conditional_write(request).is_failed())
	assert_true(transport.probe(request).is_failed())
	var journal: GFStorageSyncJournal = GFStorageSyncJournal.new()
	assert_true(journal.persist_intent(request).is_failed())
	assert_true(journal.persist_outcome(request, {}).is_failed())
	assert_true(journal.load_intent("n", "k").is_failed())


func test_result_is_frozen_and_operation_completes_once() -> void:
	var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"n",
		"k",
		"op"
	)
	var data: Dictionary = { "value": 3 }
	var result: GFStorageSyncResult = GFStorageSyncResult.new()
	assert_true(
		result.configure_for_framework(
			request,
			GFStorageSyncResult.Status.COMMITTED,
			{
				"exists": true,
				"revision": "remote-token",
				"data": data,
				"remote_committed": true,
			}
		)
	)
	data["value"] = 4
	assert_true(
		_matches(
			result.get_data(),
			{ "value": 3 }
		)
	)
	assert_false(result.configure_for_framework(request, GFStorageSyncResult.Status.OUTCOME_UNKNOWN))
	assert_false(result.get_debug_snapshot().has("data"))
	var operation: GFStorageSyncOperation = GFStorageSyncOperation.new()
	var observed: Array[GFStorageSyncResult] = []
	var observe: Callable = func(value: GFStorageSyncResult) -> void:
		observed.append(value)
	var _connected: Error = operation.completed.connect(observe) as Error
	assert_true(operation.complete_for_framework(result))
	assert_false(operation.complete_for_framework(result))
	assert_false(operation.cancel_wait())
	assert_eq(
		observed.size(),
		1
	)
	var already_completed: GFStorageSyncResult = await operation.wait_result_async()
	assert_eq(
		already_completed.get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)


func test_result_distinguishes_unknown_from_unconfirmed_local_checkpoint() -> void:
	var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"n",
		"k",
		"op"
	)
	var unknown: GFStorageSyncResult = GFStorageSyncResult.new()
	assert_true(unknown.configure_for_framework(request, GFStorageSyncResult.Status.OUTCOME_UNKNOWN))
	assert_true(unknown.requires_recovery())
	assert_false(unknown.is_remote_committed())
	var pending_completion: GFStorageSyncResult = GFStorageSyncResult.new()
	assert_true(
		pending_completion.configure_for_framework(
			request,
			GFStorageSyncResult.Status.RECOVERY_REQUIRED,
			{
				"exists": true,
				"revision": "r",
				"remote_committed": true,
				"error_kind": &"checkpoint_failed",
			}
		)
	)
	assert_true(pending_completion.requires_recovery())
	assert_true(pending_completion.is_remote_committed())
	assert_false(pending_completion.is_successful())
	var invalid: GFStorageSyncResult = GFStorageSyncResult.new()
	assert_false(invalid.configure_for_framework(request, GFStorageSyncResult.Status.COMMITTED))


# --- 私有/辅助方法 ---

func _matches(left: Variant, right: Variant) -> bool:
	return left == right
