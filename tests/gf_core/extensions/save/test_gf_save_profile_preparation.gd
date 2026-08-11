# 测试 Save Profile 的协作式准备预算和请求帧边界。
extends GutTest


class ChunkedSnapshotOperation extends GFSaveSectionSnapshotOperation:
	var snapshot_section_id: StringName = &""
	var snapshot_schema_version: int = 1
	var remaining_steps: int = 0
	var produced_values: Array = []
	var advance_call_count: int = 0
	var cancelled: bool = false

	func _init(
		p_section_id: StringName,
		p_schema_version: int,
		p_remaining_steps: int
	) -> void:
		snapshot_section_id = p_section_id
		snapshot_schema_version = p_schema_version
		remaining_steps = maxi(p_remaining_steps, 0)

	func _advance_snapshot(step_budget: int) -> int:
		advance_call_count += 1
		var consumed: int = mini(maxi(step_budget, 1), remaining_steps)
		for _index: int in range(consumed):
			produced_values.append({
				"state": produced_values.size(),
				"values": [1, 2, 3, 4],
			})
		remaining_steps -= consumed
		if remaining_steps == 0:
			var snapshot: GFSaveSectionSnapshot = GFSaveSectionSnapshot.take_ownership(
				snapshot_section_id,
				snapshot_schema_version,
				{"history": produced_values}
			)
			var _completed: bool = _complete_snapshot(snapshot)
		return maxi(consumed, 1)

	func _cancel_snapshot() -> void:
		cancelled = true


class ChunkedProvider extends GFSaveSectionProvider:
	var required_steps: int = 1
	var begin_call_count: int = 0
	var latest_operation: ChunkedSnapshotOperation = null
	var fail_begin: bool = false
	var received_context: Dictionary = {}

	func _begin_save_snapshot(
		context: Dictionary = {}
	) -> GFSaveSectionSnapshotOperation:
		begin_call_count += 1
		received_context = context
		if fail_begin:
			var failed: GFSaveSectionSnapshotOperation = GFSaveSectionSnapshotOperation.new()
			var _failed: bool = failed._fail_snapshot(
				ERR_INVALID_DATA,
				"Injected preparation failure."
			)
			return failed
		latest_operation = ChunkedSnapshotOperation.new(
			section_id,
			schema_version,
			required_steps
		)
		return latest_operation

	func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
		return make_section({"history": []})


class CaptureStorage extends GFStorageUtility:
	var save_call_count: int = 0
	var captured_payloads: Array[Dictionary] = []
	var captured_transfers: Array[GFStoragePayloadTransfer] = []
	var pending_operations: Array[GFStorageAsyncOperation] = []
	var _next_request_id: int = 1

	func save_payload_request_async(
		file_name: String,
		transfer: GFStoragePayloadTransfer,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
		var _configured: bool = operation.configure_for_framework(
			_next_request_id,
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
		_next_request_id += 1
		var attempt: Dictionary = transfer.begin_attempt_for_framework(
			get_instance_id(),
			file_name,
			_get_async_file_key(file_name),
			_get_codec_options()
		)
		if not GFVariantData.get_option_bool(attempt, "ok"):
			_complete(operation, ERR_INVALID_PARAMETER)
			return operation
		var _configured_attempt: bool = operation.configure_payload_attempt_for_framework(
			transfer,
			GFVariantData.get_option_int(attempt, "attempt_id")
		)
		save_call_count += 1
		var payload_value: Variant = attempt.get("payload")
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			captured_payloads.append(payload)
		captured_transfers.append(transfer)
		pending_operations.append(operation)
		return operation

	func complete_next(error_code: Error = OK) -> void:
		if pending_operations.is_empty():
			return
		var operation: GFStorageAsyncOperation = pending_operations.pop_front()
		_complete(operation, error_code)

	func _complete(operation: GFStorageAsyncOperation, error_code: Error) -> void:
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
var _storage: CaptureStorage
var _utility: GFSaveProfileUtility


func before_each() -> void:
	_clock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	_storage = CaptureStorage.new()
	_utility = GFSaveProfileUtility.new().setup(_storage, _clock)
	_utility.save_preparation_time_budget_usec = 0


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null
	if _storage != null:
		_storage.dispose()
	_storage = null
	_clock = null


func test_save_request_returns_before_provider_or_storage_work() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 14)
	assert_true(_register(_make_profile(&"test.deferred", provider)))
	_utility.save_preparation_work_budget_per_tick = 2
	_utility.save_preparation_slice_budget = 1

	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.deferred")

	assert_true(operation.is_pending())
	assert_eq(provider.begin_call_count, 0)
	assert_eq(_storage.save_call_count, 0)

	_utility.tick(0.0)

	assert_eq(provider.begin_call_count, 1)
	assert_not_null(provider.latest_operation)
	assert_eq(provider.latest_operation.advance_call_count, 0)
	assert_eq(provider.latest_operation.produced_values.size(), 0)
	assert_eq(_storage.save_call_count, 0)

	for _index: int in range(13):
		_utility.tick(0.0)
	assert_eq(_storage.save_call_count, 1)
	assert_eq(
		GFVariantData.get_option_array(
			GFVariantData.get_option_dictionary(
				GFVariantData.get_option_dictionary(
					GFVariantData.get_option_dictionary(
						_storage.captured_payloads[0],
						"sections"
					),
					"history"
				),
				"payload"
			),
			"history"
		).size(),
		14
	)
	_storage.complete_next()
	assert_true(operation.get_result().is_successful())


func test_request_claim_preserves_large_alias_identity_and_is_one_shot() -> void:
	var document_values: Array = _make_large_values(4_096)
	var context_values: Array = _make_large_values(4_096)
	var result_values: Array = _make_large_values(4_096)
	var document_metadata: Dictionary = {"values": document_values}
	var context: Dictionary = {"values": context_values}
	var result_metadata: Dictionary = {"values": result_values}
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		document_metadata,
		context,
		result_metadata
	)

	var claim: Dictionary = request.claim_for_framework()

	assert_true(request.is_claimed())
	assert_true(is_same(
		_dictionary_reference(claim, "document_metadata"),
		document_metadata
	))
	assert_true(is_same(_dictionary_reference(claim, "context"), context))
	assert_true(is_same(
		_dictionary_reference(claim, "result_metadata"),
		result_metadata
	))
	assert_true(is_same(
		_dictionary_reference(claim, "document_metadata").get("values"),
		document_values
	))
	assert_true(is_same(
		_dictionary_reference(claim, "context").get("values"),
		context_values
	))
	assert_true(is_same(
		_dictionary_reference(claim, "result_metadata").get("values"),
		result_values
	))
	assert_true(request.claim_for_framework().is_empty())


func test_save_admission_moves_large_request_without_request_frame_copy() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 1)
	assert_true(_register(_make_profile(&"test.request_move", provider)))
	var document_values: Array = _make_large_values(4_096)
	var context_values: Array = _make_large_values(4_096)
	var document_metadata: Dictionary = {"values": document_values}
	var context: Dictionary = {"values": context_values}
	var result_metadata: Dictionary = {"request_id": 42}
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		document_metadata,
		context,
		result_metadata
	)

	var operation: GFSaveProfileOperation = _utility.save_profile(
		&"test.request_move",
		request
	)

	assert_true(operation.is_pending())
	assert_true(request.is_claimed())
	assert_eq(provider.begin_call_count, 0)
	assert_eq(_storage.save_call_count, 0)

	_utility.tick(0.0)

	assert_true(is_same(provider.received_context, context))
	assert_eq(_storage.captured_payloads.size(), 1)
	var persisted_metadata: Dictionary = _dictionary_reference(
		_storage.captured_payloads[0],
		"metadata"
	)
	assert_true(is_same(persisted_metadata, document_metadata))
	assert_true(is_same(persisted_metadata.get("values"), document_values))
	assert_true(is_same(provider.received_context.get("values"), context_values))
	_storage.complete_next()
	assert_eq(
		GFVariantData.get_option_int(operation.get_result().get_metadata(), "request_id"),
		42
	)


func test_rejection_does_not_claim_request_and_claimed_request_is_invalid() -> void:
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{"document": true},
		{"context": true},
		{"result": true}
	)

	var missing: GFSaveProfileOperation = _utility.save_profile(
		&"test.request_rejection",
		request
	)

	assert_eq(
		missing.get_result().get_status(),
		GFSaveProfileResult.STATUS_INVALID_PROFILE
	)
	assert_false(request.is_claimed())

	var provider: ChunkedProvider = _make_provider(&"history", 1)
	assert_true(_register(_make_profile(&"test.request_rejection", provider)))
	var accepted: GFSaveProfileOperation = _utility.save_profile(
		&"test.request_rejection",
		request
	)
	var duplicate_request_operation: GFSaveProfileOperation = _utility.save_profile(
		&"test.request_rejection",
		request
	)
	var uninitialized: GFSaveProfileRequest = GFSaveProfileRequest.new()
	var invalid: GFSaveProfileOperation = _utility.save_profile(
		&"test.request_rejection",
		uninitialized
	)

	assert_true(accepted.is_pending())
	assert_true(request.is_claimed())
	assert_eq(
		duplicate_request_operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_INVALID_REQUEST
	)
	assert_eq(
		invalid.get_result().get_status(),
		GFSaveProfileResult.STATUS_INVALID_REQUEST
	)
	assert_false(uninitialized.is_claimed())
	assert_eq(
		GFVariantData.get_option_int(
			_utility.get_profile_state_snapshot(&"test.request_rejection"),
			"generation"
		),
		1,
		"无效或重复 Request 不得分配 generation。"
	)


func test_preparation_budget_is_global_and_round_robin() -> void:
	var first_provider: ChunkedProvider = _make_provider(&"first", 3)
	var second_provider: ChunkedProvider = _make_provider(&"second", 3)
	assert_true(_register(_make_profile(&"test.first", first_provider)))
	assert_true(_register(_make_profile(&"test.second", second_provider)))
	_utility.save_preparation_work_budget_per_tick = 2
	_utility.save_preparation_slice_budget = 1

	var _first: GFSaveProfileOperation = _utility.save_profile(&"test.first")
	var _second: GFSaveProfileOperation = _utility.save_profile(&"test.second")
	_utility.tick(0.0)

	assert_eq(first_provider.begin_call_count, 0)
	assert_eq(second_provider.begin_call_count, 0)

	_utility.tick(0.0)

	assert_eq(first_provider.begin_call_count, 1)
	assert_eq(second_provider.begin_call_count, 1)
	assert_eq(first_provider.latest_operation.produced_values.size(), 0)
	assert_eq(second_provider.latest_operation.produced_values.size(), 0)

	_utility.tick(0.0)

	assert_eq(first_provider.latest_operation.produced_values.size(), 1)
	assert_eq(second_provider.latest_operation.produced_values.size(), 1)


func test_preparation_failure_never_starts_storage() -> void:
	var provider: ChunkedProvider = _make_provider(&"broken", 1)
	provider.fail_begin = true
	assert_true(_register(_make_profile(&"test.failure", provider)))

	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.failure")
	_utility.tick(0.0)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_PREPARATION_FAILED
	)
	assert_eq(operation.get_result().get_failed_section_id(), &"broken")
	assert_eq(operation.get_result().get_attempt_count(), 0)
	assert_eq(_storage.save_call_count, 0)


func test_dispose_cancels_active_preparation_without_storage_admission() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 10)
	assert_true(_register(_make_profile(&"test.cancel", provider)))
	_utility.save_preparation_work_budget_per_tick = 2
	_utility.save_preparation_slice_budget = 1
	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.cancel")
	_utility.tick(0.0)
	assert_not_null(provider.latest_operation)

	_utility.dispose()

	assert_true(provider.latest_operation.cancelled)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_DISPOSED)
	assert_eq(_storage.save_call_count, 0)


func test_result_separates_preparation_and_storage_timing() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 2)
	assert_true(_register(_make_profile(&"test.timing", provider)))
	_utility.save_preparation_work_budget_per_tick = 1
	_utility.save_preparation_slice_budget = 1
	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.timing")

	_utility.tick(0.0)
	var _advanced_first: bool = _clock.advance_msec(4)
	_utility.tick(0.0)
	var _advanced_second: bool = _clock.advance_msec(6)
	_utility.tick(0.0)
	_utility.tick(0.0)
	_utility.tick(0.0)
	assert_eq(_storage.save_call_count, 1)
	var _advanced_storage: bool = _clock.advance_msec(7)
	_storage.complete_next()

	var result: GFSaveProfileResult = operation.get_result()
	assert_eq(result.get_preparation_duration_msec(), 10)
	assert_eq(result.get_storage_duration_msec(), 7)
	assert_true(result.get_preparation_work_units() >= 3)
	assert_null(result.get_document(), "Save result 不应复制完整文档。")
	assert_false(result.to_dict().has("payload"))


func _make_provider(section_id: StringName, required_steps: int) -> ChunkedProvider:
	var provider: ChunkedProvider = ChunkedProvider.new()
	provider.section_id = section_id
	provider.schema_version = 1
	provider.required_on_load = true
	provider.required_steps = required_steps
	return provider


func _make_profile(
	profile_id: StringName,
	provider: GFSaveSectionProvider
) -> GFSaveProfile:
	var profile: GFSaveProfile = GFSaveProfile.new()
	profile.profile_id = profile_id
	profile.file_name = "%s.json" % String(profile_id).replace(".", "_")
	profile.providers = [provider]
	return profile


func _register(profile: GFSaveProfile) -> bool:
	return GFVariantData.get_option_bool(
		_utility.register_profile(profile),
		"registered"
	)


func _make_large_values(count: int) -> Array:
	var values: Array = []
	var _resize_result: int = values.resize(maxi(count, 0))
	for index: int in range(values.size()):
		values[index] = {
			"index": index,
			"flags": [true, false, true, false],
		}
	return values


func _dictionary_reference(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
