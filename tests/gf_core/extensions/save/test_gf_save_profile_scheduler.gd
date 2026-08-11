# 测试 Save Profile 准备调度、重入终止和物理 IO 计时边界。
extends GutTest


class CompletedProvider extends GFSaveSectionProvider:
	var clock: GFManualClock = null
	var begin_advance_msec: int = 0
	var begin_call_count: int = 0
	var utility_to_dispose: GFSaveProfileUtility = null
	var latest_snapshot: GFSaveSectionSnapshot = null
	var latest_operation: GFSaveSectionSnapshotOperation = null

	func _begin_save_snapshot(
		_context: Dictionary = {}
	) -> GFSaveSectionSnapshotOperation:
		begin_call_count += 1
		if clock != null and begin_advance_msec > 0:
			var _advanced: bool = clock.advance_msec(begin_advance_msec)
		latest_snapshot = make_snapshot({"value": begin_call_count})
		latest_operation = GFSaveSectionSnapshotOperation.completed(latest_snapshot)
		if utility_to_dispose != null:
			utility_to_dispose.dispose()
		return latest_operation

	func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
		return make_section({"value": begin_call_count})


class TimedStorage extends GFStorageUtility:
	var clock: GFManualClock = null
	var admission_advance_msec: int = 0
	var complete_synchronously: bool = false
	var synchronous_error: Error = OK
	var save_call_count: int = 0
	var latest_transfer: GFStoragePayloadTransfer = null
	var pending_operations: Array[GFStorageAsyncOperation] = []
	var _next_request_id: int = 1

	func save_payload_request_async(
		file_name: String,
		transfer: GFStoragePayloadTransfer
	) -> GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
		var _configured: bool = operation.configure_for_framework(
			_next_request_id,
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
		_next_request_id += 1
		save_call_count += 1
		latest_transfer = transfer
		var attempt: Dictionary = (
			transfer.begin_attempt_for_framework(
				get_instance_id(),
				file_name,
				_get_async_file_key(file_name),
				_get_codec_options()
			)
			if transfer != null
			else {}
		)
		if not GFVariantData.get_option_bool(attempt, "ok"):
			_complete(operation, ERR_INVALID_PARAMETER)
			return operation
		var _configured_attempt: bool = operation.configure_payload_attempt_for_framework(
			transfer,
			GFVariantData.get_option_int(attempt, "attempt_id")
		)
		if clock != null and admission_advance_msec > 0:
			var _advanced: bool = clock.advance_msec(admission_advance_msec)
		if complete_synchronously:
			_complete(operation, synchronous_error)
		else:
			pending_operations.append(operation)
		return operation

	func get_request_ids() -> PackedInt64Array:
		var result: PackedInt64Array = PackedInt64Array()
		for operation: GFStorageAsyncOperation in pending_operations:
			var _appended: bool = result.append(operation.get_request_id())
		return result

	func complete_request(request_id: int, error_code: Error = OK) -> bool:
		for index: int in range(pending_operations.size()):
			var operation: GFStorageAsyncOperation = pending_operations[index]
			if operation.get_request_id() != request_id:
				continue
			pending_operations.remove_at(index)
			_complete(operation, error_code)
			return true
		return false

	func complete_all(error_code: Error = ERR_UNAVAILABLE) -> void:
		while not pending_operations.is_empty():
			var operation: GFStorageAsyncOperation = pending_operations.pop_front()
			_complete(operation, error_code)

	func _complete(
		operation: GFStorageAsyncOperation,
		error_code: Error
	) -> void:
		var _finished: bool = operation.finish_payload_attempt_for_framework()
		var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
		var write_failure_kind: GFStorageAsyncResult.WriteFailureKind = (
			_resolve_write_failure_kind(error_code)
		)
		var _configured: bool = result.configure_for_framework(
			operation.get_request_id(),
			operation.get_operation(),
			operation.get_file_name(),
			error_code == OK,
			error_code,
			null,
			write_failure_kind
		)
		var _completed: bool = operation.complete_for_framework(result)

	static func _resolve_write_failure_kind(
		error_code: Error
	) -> GFStorageAsyncResult.WriteFailureKind:
		if error_code == OK:
			return GFStorageAsyncResult.WriteFailureKind.NONE
		match error_code:
			ERR_INVALID_PARAMETER:
				return GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			ERR_UNAVAILABLE:
				return GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
			ERR_CANT_CREATE:
				return GFStorageAsyncResult.WriteFailureKind.THREAD_START_FAILED
		return GFStorageAsyncResult.WriteFailureKind.IO_FAILED


var _clock: GFManualClock
var _storage: TimedStorage
var _utility: GFSaveProfileUtility


func before_each() -> void:
	_clock = GFManualClock.new(0, 1_700_000_000_000)
	_storage = TimedStorage.new()
	_storage.clock = _clock
	_utility = GFSaveProfileUtility.new().setup(_storage, _clock)
	_utility.save_preparation_time_budget_usec = 0


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null
	if _storage != null:
		_storage.complete_all()
		_storage.dispose()
	_storage = null
	_clock = null


func test_many_idle_profiles_only_schedule_the_requested_profile() -> void:
	var idle_providers: Array[CompletedProvider] = []
	for index: int in range(256):
		var provider: CompletedProvider = _make_provider(
			StringName("idle_%d" % index)
		)
		idle_providers.append(provider)
		assert_true(_register(_make_profile(
			StringName("test.scheduler_idle_%d" % index),
			[provider]
		)))
	var target_provider: CompletedProvider = _make_provider(&"target")
	var target_id: StringName = &"test.scheduler_target"
	assert_true(_register(_make_profile(target_id, [target_provider])))
	_utility.save_preparation_work_budget_per_tick = 1
	_utility.save_preparation_slice_budget = 1

	var operation: GFSaveProfileOperation = _utility.save_profile(target_id)
	var queued: Dictionary = _utility.get_profile_state_snapshot(target_id)

	assert_true(GFVariantData.get_option_bool(queued, "schedule_enqueued"))
	assert_eq(target_provider.begin_call_count, 0)
	_utility.tick(0.0)
	var scanned: Dictionary = _utility.get_profile_state_snapshot(target_id)
	assert_eq(
		GFVariantData.get_option_string_name(scanned, "preparation_phase"),
		&"provider_begin"
	)
	assert_eq(target_provider.begin_call_count, 0)
	for provider: CompletedProvider in idle_providers:
		assert_eq(provider.begin_call_count, 0)
	_utility.tick(0.0)
	assert_eq(target_provider.begin_call_count, 1)
	assert_true(operation.is_running())


func test_provider_scan_charges_disabled_entries_begin_and_finalize() -> void:
	var providers: Array[GFSaveSectionProvider] = []
	var disabled_providers: Array[CompletedProvider] = []
	for index: int in range(12):
		var disabled: CompletedProvider = _make_provider(
			StringName("disabled_%d" % index)
		)
		disabled.save_enabled = false
		disabled.required_on_load = false
		disabled_providers.append(disabled)
		providers.append(disabled)
	var target: CompletedProvider = _make_provider(&"target")
	providers.append(target)
	var profile_id: StringName = &"test.scheduler_scan"
	assert_true(_register(_make_profile(profile_id, providers)))
	_utility.save_preparation_work_budget_per_tick = 1
	_utility.save_preparation_slice_budget = 1

	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	for expected_index: int in range(1, 13):
		_utility.tick(0.0)
		var snapshot: Dictionary = _utility.get_profile_state_snapshot(profile_id)
		assert_eq(
			GFVariantData.get_option_int(snapshot, "preparation_provider_index"),
			expected_index
		)
		assert_eq(
			GFVariantData.get_option_int(snapshot, "preparation_work_units"),
			expected_index
		)
		assert_eq(target.begin_call_count, 0)
	_utility.tick(0.0)
	assert_eq(target.begin_call_count, 0, "选择可用 Provider 本身应单独计费。")
	_utility.tick(0.0)
	assert_eq(target.begin_call_count, 1, "Provider begin 应单独计费。")
	assert_eq(_storage.save_call_count, 0)
	_utility.tick(0.0)
	assert_eq(_storage.save_call_count, 1, "Finalize 应单独计费后才可进入 Storage。")
	for disabled: CompletedProvider in disabled_providers:
		assert_eq(disabled.begin_call_count, 0)
	assert_true(_storage.complete_request(1))
	assert_eq(operation.get_result().get_preparation_work_units(), 15)


func test_begin_callback_dispose_cancels_returned_snapshot() -> void:
	var provider: CompletedProvider = _make_provider(&"reentrant")
	provider.utility_to_dispose = _utility
	assert_true(_register(_make_profile(&"test.scheduler_dispose_begin", [provider])))
	_utility.save_preparation_work_budget_per_tick = 2
	_utility.save_preparation_slice_budget = 2

	var operation: GFSaveProfileOperation = _utility.save_profile(
		&"test.scheduler_dispose_begin"
	)
	_utility.tick(0.0)

	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_DISPOSED)
	assert_not_null(provider.latest_operation)
	assert_eq(
		provider.latest_operation.get_status(),
		GFSaveSectionSnapshotOperation.STATUS_CANCELLED
	)
	assert_not_null(provider.latest_snapshot)
	assert_eq(
		provider.latest_snapshot.get_state(),
		GFSaveSectionSnapshot.STATE_DISCARDED
	)
	assert_eq(_storage.save_call_count, 0)


func test_clock_zero_tracks_preparation_and_storage_time() -> void:
	var provider: CompletedProvider = _make_provider(&"timed")
	provider.clock = _clock
	provider.begin_advance_msec = 3
	var profile_id: StringName = &"test.scheduler_clock_zero"
	assert_true(_register(_make_profile(profile_id, [provider])))

	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	_utility.tick(0.0)
	assert_eq(_storage.save_call_count, 1)
	var _advanced: bool = _clock.advance_msec(7)
	assert_true(_storage.complete_request(1))

	var result: GFSaveProfileResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_preparation_duration_msec(), 3)
	assert_eq(result.get_storage_duration_msec(), 7)
	assert_eq(result.get_preparation_work_units(), 3)


func test_profile_snapshot_reports_live_preparation_and_storage_time() -> void:
	var profile_id: StringName = &"test.scheduler_live_timing"
	assert_true(_register(_make_profile(
		profile_id,
		[_make_provider(&"state")]
	)))
	_utility.save_preparation_work_budget_per_tick = 1
	_utility.save_preparation_slice_budget = 1
	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)

	_utility.tick(0.0)
	var _advanced_preparation: bool = _clock.advance_msec(4)
	var preparing: Dictionary = _utility.get_profile_state_snapshot(profile_id)
	assert_eq(
		GFVariantData.get_option_int(
			preparing,
			"preparation_duration_msec"
		),
		4
	)
	assert_eq(
		GFVariantData.get_option_int(preparing, "storage_duration_msec"),
		0
	)

	_utility.tick(0.0)
	_utility.tick(0.0)
	assert_eq(_storage.save_call_count, 1)
	var _advanced_storage: bool = _clock.advance_msec(6)
	var saving: Dictionary = _utility.get_profile_state_snapshot(profile_id)
	assert_eq(
		GFVariantData.get_option_int(
			saving,
			"preparation_duration_msec"
		),
		4
	)
	assert_eq(
		GFVariantData.get_option_int(saving, "storage_duration_msec"),
		6
	)

	assert_true(_storage.complete_request(1))
	assert_true(operation.get_result().is_successful())


func test_synchronous_storage_admission_is_timed_and_finalize_is_charged() -> void:
	var provider: CompletedProvider = _make_provider(&"sync")
	var profile_id: StringName = &"test.scheduler_sync_storage"
	assert_true(_register(_make_profile(profile_id, [provider])))
	_storage.complete_synchronously = true
	_storage.admission_advance_msec = 6

	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	_utility.tick(0.0)

	var result: GFSaveProfileResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_storage_duration_msec(), 6)
	assert_eq(result.get_preparation_work_units(), 3)
	assert_eq(
		GFVariantData.get_option_string_name(
			_utility.get_profile_state_snapshot(profile_id),
			"state"
		),
		GFSaveProfileUtility.STATE_IDLE
	)


func test_detached_tail_is_counted_while_retry_is_pending() -> void:
	var profile_id: StringName = &"test.scheduler_detached_tail"
	assert_true(_register(_make_profile(
		profile_id,
		[_make_provider(&"state")],
		_make_retry_policy()
	)))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	_utility.tick(0.0)
	var _advanced_timeout: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	var _advanced_tail: bool = _clock.advance_msec(4)

	assert_true(_storage.complete_request(1))

	var result: GFSaveProfileResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_storage_duration_msec(), 14)
	assert_eq(result.get_attempt_count(), 1)


func test_detached_success_counts_overlap_without_late_result_rewrite() -> void:
	var profile_id: StringName = &"test.scheduler_detached_overlap"
	assert_true(_register(_make_profile(
		profile_id,
		[_make_provider(&"state")],
		_make_retry_policy()
	)))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	_utility.tick(0.0)
	var _advanced_timeout: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	var _advanced_retry_wait: bool = _clock.advance_msec(5)
	_utility.tick(0.0)
	assert_eq(_storage.get_request_ids(), PackedInt64Array([1, 2]))
	var _advanced_overlap: bool = _clock.advance_msec(3)
	var live_snapshot: Dictionary = _utility.get_profile_state_snapshot(profile_id)
	assert_eq(
		GFVariantData.get_option_int(live_snapshot, "storage_duration_msec"),
		21
	)

	assert_true(_storage.complete_request(1))

	var result: GFSaveProfileResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_attempt_count(), 2)
	assert_eq(result.get_storage_duration_msec(), 21)
	assert_eq(result.get_storage_request_ids(), PackedInt64Array([1, 2]))
	assert_not_null(_storage.latest_transfer)
	assert_eq(
		_storage.latest_transfer.get_state(),
		GFStoragePayloadTransfer.State.RELEASE_PENDING
	)
	assert_true(_storage.complete_request(2, ERR_BUSY))
	assert_eq(operation.get_result().get_storage_duration_msec(), 21)
	assert_true(operation.get_result().is_successful())
	assert_true(_storage.latest_transfer.is_released())


func test_dispose_counts_detached_tail_and_active_retry_overlap() -> void:
	var profile_id: StringName = &"test.scheduler_dispose_timing"
	assert_true(_register(_make_profile(
		profile_id,
		[_make_provider(&"state")],
		_make_retry_policy()
	)))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile_id)
	_utility.tick(0.0)
	var _advanced_timeout: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	var _advanced_retry_wait: bool = _clock.advance_msec(5)
	_utility.tick(0.0)
	var _advanced_overlap: bool = _clock.advance_msec(3)

	_utility.dispose()

	var result: GFSaveProfileResult = operation.get_result()
	assert_eq(result.get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(result.get_attempt_count(), 2)
	assert_eq(result.get_storage_duration_msec(), 21)
	assert_eq(result.get_storage_request_ids(), PackedInt64Array([1, 2]))
	assert_eq(
		_storage.latest_transfer.get_state(),
		GFStoragePayloadTransfer.State.RELEASE_PENDING
	)
	assert_true(_storage.complete_request(1))
	assert_true(_storage.complete_request(2, ERR_BUSY))
	assert_true(_storage.latest_transfer.is_released())


func _make_provider(section_id: StringName) -> CompletedProvider:
	var provider: CompletedProvider = CompletedProvider.new()
	provider.section_id = section_id
	provider.schema_version = 1
	provider.required_on_load = true
	return provider


func _make_profile(
	profile_id: StringName,
	providers: Array[GFSaveSectionProvider],
	recovery_policy: GFSaveRecoveryPolicy = null
) -> GFSaveProfile:
	var profile: GFSaveProfile = GFSaveProfile.new()
	profile.profile_id = profile_id
	profile.file_name = "%s.json" % String(profile_id).replace(".", "_")
	profile.providers = providers
	if recovery_policy != null:
		profile.recovery_policy = recovery_policy
	return profile


func _make_retry_policy() -> GFSaveRecoveryPolicy:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	policy.retry_delays_msec = PackedInt32Array([5])
	return policy


func _register(profile: GFSaveProfile) -> bool:
	return GFVariantData.get_option_bool(
		_utility.register_profile(profile),
		"registered"
	)
