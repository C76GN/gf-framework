extends GutTest


const TRANSPORT_SCRIPT = preload("res://tests/gf_core/standard/utilities/storage/fixtures/controlled_storage_sync_transport.gd")
const JOURNAL_SCRIPT = preload("res://tests/gf_core/standard/utilities/storage/fixtures/controlled_storage_sync_journal.gd")


class ManualClock extends GFClock:
	var now: int = 0

	func get_monotonic_msec() -> int:
		return now


var _transport: TRANSPORT_SCRIPT = TRANSPORT_SCRIPT.new()
var _journal: JOURNAL_SCRIPT = JOURNAL_SCRIPT.new()
var _clock: ManualClock = ManualClock.new()
var _sync: GFStorageSyncUtility = null


func before_each() -> void:
	_transport = TRANSPORT_SCRIPT.new()
	_journal = JOURNAL_SCRIPT.new()
	_clock = ManualClock.new()
	_sync = GFStorageSyncUtility.new()
	assert_true(
		_sync.setup(
			_transport,
			_journal,
			_clock
		)
	)


func after_each() -> void:
	_sync.dispose()
	_transport.pending.clear()
	_journal.pending.clear()


func test_intent_and_checkpoint_must_finish_before_commit_is_reported() -> void:
	_journal.held = [&"intent", &"outcome"]
	var operation: GFStorageSyncOperation = _sync.synchronize(_request())
	assert_false(operation.is_completed())
	assert_eq(
		_transport.calls,
		[&"read"]
	)
	_journal.execute()
	assert_false(
		operation.is_completed(),
		"远端成功不能代替本地 checkpoint。"
	)
	assert_eq(
		_transport.calls,
		[&"read", &"write"]
	)
	_journal.execute()
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)
	assert_true(operation.get_result().is_remote_committed())
	assert_eq(
		_journal.calls,
		[
			&"load",
			&"intent",
			&"outcome",
		]
	)
	assert_true(_journal.intents.is_empty())


func test_default_conflict_and_preview_never_write_or_order_revision() -> void:
	_transport.put(
		"account",
		"profile",
		{ "coins": 9 },
		"rev-2"
	)
	var request: GFStorageSyncRequest = _request({ "expected_revision": "rev-100" })
	var result: GFStorageSyncResult = _sync.synchronize(request).get_result()
	assert_eq(
		result.get_status(),
		GFStorageSyncResult.Status.CONFLICT
	)
	assert_eq(
		result.get_conflict_report().get_actual_revision(),
		"rev-2"
	)
	assert_eq(
		result.get_conflict_report().get_local_data(),
		{ "coins": 4 }
	)
	var preview: GFStorageSyncResult = _sync.synchronize(_request({ "mode": &"preview" })).get_result()
	assert_eq(
		preview.get_status(),
		GFStorageSyncResult.Status.PREVIEW
	)
	assert_false(_transport.calls.has(&"write"))
	assert_false(_journal.calls.has(&"intent"))


func test_explicit_local_choice_uses_observed_revision_and_still_detects_race() -> void:
	_transport.put(
		"account",
		"profile",
		{ "coins": 9 },
		"first"
	)
	_journal.held = [&"intent"]
	var operation: GFStorageSyncOperation = _sync.synchronize(_request({ "resolution": &"local" }))
	_transport.put(
		"account",
		"profile",
		{ "coins": 12 },
		"concurrent"
	)
	_journal.execute()
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.CONFLICT
	)
	assert_eq(
		operation.get_result().get_request().get_expected_revision(),
		"first"
	)
	assert_eq(
		operation.get_result().get_data(),
		{ "coins": 12 }
	)
	assert_true(_journal.intents.is_empty())


func test_custom_merge_resubmits_new_identity_against_observed_revision() -> void:
	_transport.put(
		"account",
		"profile",
		{ "coins": 9 },
		"remote"
	)
	var conflict: GFStorageConflictReport = _sync.synchronize(_request()).get_result().get_conflict_report()
	var merged: GFStorageSyncRequest = GFStorageSyncRequest.create(
		conflict.get_namespace(),
		conflict.get_key(),
		"merged-op",
		{ "coins": 13 },
		{ "expected_revision": conflict.get_actual_revision() }
	)
	var result: GFStorageSyncResult = _sync.synchronize(merged).get_result()
	assert_eq(
		result.get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)
	assert_eq(
		result.get_data(),
		{ "coins": 13 }
	)


func test_pull_remote_selection_and_unchanged_are_explicit_nonwrite_results() -> void:
	_transport.put(
		"account",
		"profile",
		{ "coins": 4 },
		"same"
	)
	var unchanged: GFStorageSyncResult = _sync.synchronize(_request({ "expected_revision": "same" })).get_result()
	assert_eq(
		unchanged.get_status(),
		GFStorageSyncResult.Status.UNCHANGED
	)
	var pull: GFStorageSyncResult = _sync.synchronize(_request({ "mode": &"pull" })).get_result()
	assert_eq(
		pull.get_status(),
		GFStorageSyncResult.Status.REMOTE_SELECTED
	)
	var selected: GFStorageSyncResult = _sync.synchronize(_request({ "resolution": &"remote" })).get_result()
	assert_eq(
		selected.get_status(),
		GFStorageSyncResult.Status.REMOTE_SELECTED
	)
	assert_false(_transport.calls.has(&"write"))
	assert_false(_journal.calls.has(&"intent"))


func test_mode_support_inspection_matches_runtime_without_io() -> void:
	var transport: TRANSPORT_SCRIPT = TRANSPORT_SCRIPT.new()
	transport.capabilities["conditional_write"] = false
	transport.capabilities["probe"] = false
	var readonly: GFStorageSyncUtility = GFStorageSyncUtility.new()
	assert_true(readonly.setup(transport))
	for mode: StringName in [&"preview", &"pull"]:
		assert_true(
			GFVariantData.get_option_bool(
				readonly.inspect_support(mode),
				"ok"
			)
		)
	assert_true(
		GFVariantData.get_option_bool(
			readonly.inspect_support(&"push", &"remote"),
			"ok"
		)
	)
	var rejected: Dictionary = readonly.inspect_support()
	assert_false(GFVariantData.get_option_bool(rejected, "ok"))
	assert_eq(
		GFVariantData.get_option_string(rejected, "path"),
		"journal"
	)
	var missing: PackedStringArray = rejected["missing_capabilities"]
	assert_true(missing.has("conditional_write"))
	assert_true(missing.has("probe"))
	assert_false(
		GFVariantData.get_option_bool(
			readonly.inspect_support(&"probe"),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			readonly.inspect_support(&"unknown"),
			"ok"
		)
	)
	assert_true(transport.calls.is_empty())
	assert_eq(
		readonly.synchronize(_request()).get_result().get_status(),
		GFStorageSyncResult.Status.REJECTED
	)
	assert_true(transport.calls.is_empty())
	assert_eq(
		readonly.synchronize(_request({ "mode": &"preview" })).get_result().get_status(),
		GFStorageSyncResult.Status.PREVIEW
	)
	readonly.dispose()


func test_capability_failure_is_honest_but_readonly_preview_still_works() -> void:
	_transport.capabilities["probe"] = false
	assert_eq(
		_sync.synchronize(_request()).get_result().get_status(),
		GFStorageSyncResult.Status.REJECTED
	)
	assert_true(_transport.calls.is_empty())
	assert_eq(
		_sync.synchronize(_request({ "mode": &"preview" })).get_result().get_status(),
		GFStorageSyncResult.Status.PREVIEW
	)


func test_failed_intent_never_dispatches_write() -> void:
	_journal.fail_next = &"intent"
	var result: GFStorageSyncResult = _sync.synchronize(_request()).get_result()
	assert_eq(
		result.get_status(),
		GFStorageSyncResult.Status.NOT_COMMITTED
	)
	assert_false(_transport.calls.has(&"write"))


func test_cancel_before_dispatch_and_late_intent_persistence_require_explicit_recovery() -> void:
	_journal.held = [&"intent"]
	var request: GFStorageSyncRequest = _request()
	var operation: GFStorageSyncOperation = _sync.synchronize(request)
	assert_true(operation.cancel_wait())
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.NOT_COMMITTED
	)
	_journal.execute()
	assert_false(_transport.calls.has(&"write"))
	var blocked: GFStorageSyncResult = _sync.synchronize(_request({}, "next")).get_result()
	assert_eq(
		blocked.get_error_kind(),
		&"recovery_pending"
	)
	assert_eq(
		_sync.recover(request).get_result().get_status(),
		GFStorageSyncResult.Status.OUTCOME_UNKNOWN
	)


func test_lost_commit_response_is_recovered_by_original_operation_after_restart() -> void:
	_transport.held = [&"write"]
	var request: GFStorageSyncRequest = _request({ "local_generation": 7, "timeout_msec": 10 })
	var operation: GFStorageSyncOperation = _sync.synchronize(request)
	watch_signals(operation)
	var delayed: Dictionary = _transport.execute(0, false)
	_clock.now = 11
	_sync.tick(0.0)
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.OUTCOME_UNKNOWN
	)
	assert_signal_emit_count(
		operation,
		"completed",
		1
	)
	var delayed_completion: GFAsyncCompletion = delayed["completion"]
	var _delivered: bool = delayed_completion.succeed(delayed["reply"])
	assert_signal_emit_count(
		operation,
		"completed",
		1
	)
	_sync.dispose()
	_sync = GFStorageSyncUtility.new()
	assert_true(
		_sync.setup(
			_transport,
			_journal,
			_clock
		)
	)
	_transport.put(
		"account",
		"profile",
		{ "coins": 100 },
		"later-other-device"
	)
	var recovered: GFStorageSyncResult = _sync.recover(request).get_result()
	assert_eq(
		recovered.get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)
	assert_eq(
		recovered.get_data(),
		{ "coins": 4 },
		"查证须返回历史提交，不能认领最新远端值。"
	)
	assert_eq(
		recovered.get_request().get_local_generation(),
		7
	)
	assert_eq(
		_transport.calls.count(&"write"),
		1
	)
	assert_eq(
		_transport.calls.count(&"probe"),
		1
	)
	assert_true(_journal.intents.is_empty())


func test_checkpoint_failure_keeps_confirmed_remote_commit_distinct_from_unknown() -> void:
	_journal.fail_next = &"outcome"
	var request: GFStorageSyncRequest = _request()
	var result: GFStorageSyncResult = _sync.synchronize(request).get_result()
	assert_eq(
		result.get_status(),
		GFStorageSyncResult.Status.RECOVERY_REQUIRED
	)
	assert_true(result.is_remote_committed())
	assert_eq(
		result.get_data(),
		{ "coins": 4 }
	)
	assert_false(_journal.intents.is_empty())
	assert_eq(
		_sync.recover(request).get_result().get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)
	assert_eq(
		_transport.calls.count(&"write"),
		1
	)


func test_cancel_after_send_is_unknown_and_late_response_does_not_change_result() -> void:
	_transport.held = [&"write"]
	var operation: GFStorageSyncOperation = _sync.synchronize(_request())
	watch_signals(operation)
	assert_true(operation.cancel_wait())
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.OUTCOME_UNKNOWN
	)
	var _delivered: Dictionary = _transport.execute()
	assert_signal_emit_count(
		operation,
		"completed",
		1
	)
	assert_false(_journal.intents.is_empty())


func test_authoritative_not_committed_clears_intent_and_does_not_claim_success() -> void:
	_transport.next_write_status = &"not_committed"
	var result: GFStorageSyncResult = _sync.synchronize(_request()).get_result()
	assert_eq(
		result.get_status(),
		GFStorageSyncResult.Status.NOT_COMMITTED
	)
	assert_false(result.is_successful())
	assert_true(_journal.intents.is_empty())


func test_record_ownership_out_of_order_batch_and_namespace_isolation() -> void:
	_transport.held = [&"read"]
	var requests: Array[GFStorageSyncRequest] = [
		_request(),
		_request({}, "different-operation"),
		GFStorageSyncRequest.create(
			"other-account",
			"profile",
			"other-op",
			{ "coins": 8 }
		),
	]
	var operations: Array[GFStorageSyncOperation] = _sync.synchronize_many(requests)
	assert_false(operations[0].is_completed())
	assert_eq(
		operations[1].get_result().get_error_kind(),
		&"record_busy"
	)
	var _second: Dictionary = _transport.execute(1)
	assert_true(operations[2].is_completed())
	assert_false(operations[0].is_completed())
	var _first: Dictionary = _transport.execute()
	assert_eq(
		operations[0].get_result().get_status(),
		GFStorageSyncResult.Status.COMMITTED
	)
	assert_eq(
		operations[2].get_result().get_data(),
		{ "coins": 8 }
	)


func test_malformed_commit_reply_is_unknown_not_success() -> void:
	_transport.held = [&"write"]
	var operation: GFStorageSyncOperation = _sync.synchronize(_request())
	var invocation: Dictionary = _transport.pending.pop_front()
	var completion: GFAsyncCompletion = invocation["completion"]
	var _done: bool = completion.succeed(
		{
			"status": &"committed",
			"data": { "coins": 4 },
		}
	)
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.OUTCOME_UNKNOWN
	)
	assert_eq(
		operation.get_result().get_error_kind(),
		&"invalid_reply"
	)
	assert_false(_journal.intents.is_empty())


func test_recovery_rejects_different_candidate_and_identity() -> void:
	_transport.held = [&"write"]
	var original: GFStorageSyncOperation = _sync.synchronize(_request())
	var _cancelled: bool = original.cancel_wait()
	var forged: GFStorageSyncRequest = GFStorageSyncRequest.create(
		"account",
		"profile",
		"op",
		{ "coins": 999 }
	)
	assert_eq(
		_sync.recover(forged).get_result().get_error_kind(),
		&"intent_mismatch"
	)
	assert_eq(
		_transport.calls.count(&"probe"),
		0
	)


func test_dispose_detaches_observers_and_prevents_reentrant_admission() -> void:
	_transport.held = [&"read"]
	var operation: GFStorageSyncOperation = _sync.synchronize(_request())
	_sync.dispose()
	assert_eq(
		operation.get_result().get_status(),
		GFStorageSyncResult.Status.NOT_COMMITTED
	)
	assert_eq(
		_sync.synchronize(_request()).get_result().get_status(),
		GFStorageSyncResult.Status.REJECTED
	)
	var _delivered: Dictionary = _transport.execute()
	assert_false(_transport.calls.has(&"write"))
	assert_eq(
		GFVariantData.get_option_int(
			_sync.get_debug_snapshot(),
			"pending_count"
		),
		0
	)


func _request(options: Dictionary = {}, operation_id: String = "op") -> GFStorageSyncRequest:
	return GFStorageSyncRequest.create(
		"account",
		"profile",
		operation_id,
		{ "coins": 4 },
		options
	)
