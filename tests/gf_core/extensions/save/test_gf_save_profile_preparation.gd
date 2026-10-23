# 测试 Save Profile 的协作式准备预算和请求帧边界。
extends GutTest


# --- 常量 ---

const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


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
		var consumed: int = mini(
			maxi(step_budget, 1),
			remaining_steps
		)
		for _index: int in range(consumed):
			produced_values.append(
				{
					"state": produced_values.size(),
					"values": [
						1,
						2,
						3,
						4,
					],
				}
			)
		remaining_steps -= consumed
		if remaining_steps == 0:
			var snapshot: GFSaveSectionSnapshot = GFSaveSectionSnapshot.take_ownership(
				snapshot_section_id,
				snapshot_schema_version,
				{ "history": produced_values }
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

	func _begin_save_snapshot(context: Dictionary = {}) -> GFSaveSectionSnapshotOperation:
		begin_call_count += 1
		received_context = context
		if fail_begin:
			var failed: GFSaveSectionSnapshotOperation = GFSaveSectionSnapshotOperation.new()
			var _failed: bool = failed._fail_snapshot(ERR_INVALID_DATA, "Injected preparation failure.")
			return failed
		latest_operation = ChunkedSnapshotOperation.new(
			section_id,
			schema_version,
			required_steps
		)
		return latest_operation


	func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
		return make_section({ "history": [] })


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
		var write_failure_kind: GFStorageAsyncResult.WriteFailureKind = _resolve_write_failure_kind(error_code)
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


	static func _resolve_write_failure_kind(error_code: Error) -> GFStorageAsyncResult.WriteFailureKind:
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
	assert_eq(
		provider.latest_operation.produced_values.size(),
		0
	)
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


func test_request_captures_metadata_and_claim_is_one_shot() -> void:
	var values: Array = _make_large_values(64)
	var packed: PackedInt32Array = PackedInt32Array(
		[
			1,
			2,
			3,
		]
	)
	var document_metadata: Dictionary = { "values": values, "packed": packed }
	var context: Dictionary = { "values": values }
	var result_metadata: Dictionary = { "values": values }
	var request: GFSaveProfileRequest = GFSaveProfileRequest.create(
		document_metadata,
		context,
		result_metadata
	)
	assert_not_null(request)
	if request == null:
		return
	var expected: Array = values.duplicate(true)
	values.clear()
	packed[0] = 99
	context["changed"] = true
	result_metadata.clear()

	var claim: Dictionary = request.claim_for_framework()

	assert_true(request.is_claimed())
	for key: String in [
		"document_metadata",
		"context",
		"result_metadata",
	]:
		var snapshot: Dictionary = _dictionary_reference(claim, key)
		var values_value: Variant = snapshot.get("values")
		assert_true(values_value is Array)
		if values_value is Array:
			var captured_values: Array = values_value
			assert_eq(captured_values, expected)
		assert_false(snapshot.has("changed"))
		assert_false(
			is_same(
				snapshot.get("values"),
				values
			)
		)
	var captured_packed: PackedInt32Array = _dictionary_reference(claim, "document_metadata").get("packed")
	assert_eq(
		captured_packed[0],
		1
	)
	assert_true(request.claim_for_framework().is_empty())


func test_save_admission_uses_snapshot_and_defers_provider_work() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 1)
	assert_true(_register(_make_profile(&"test.request_move", provider)))
	var document_metadata: Dictionary = { "values": _make_large_values(64) }
	var context: Dictionary = { "values": _make_large_values(64) }
	var result_metadata: Dictionary = { "request_id": 42 }
	var expected_metadata: Dictionary = document_metadata.duplicate(true)
	var expected_context: Dictionary = context.duplicate(true)
	var request: GFSaveProfileRequest = GFSaveProfileRequest.create(
		document_metadata,
		context,
		result_metadata
	)
	assert_not_null(request)
	if request == null:
		return
	document_metadata.clear()
	context.clear()
	result_metadata["request_id"] = 99

	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.request_move", request)
	var results: Array[GFSaveProfileResult] = []
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_collect_save_result"),
		[operation, results]
	)
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_collect_save_result"),
		[operation, results]
	)

	assert_true(operation.is_pending())
	assert_true(request.is_claimed())
	assert_eq(provider.begin_call_count, 0)
	assert_eq(_storage.save_call_count, 0)
	_utility.tick(0.0)
	assert_eq(provider.received_context, expected_context)
	assert_eq(
		_storage.captured_payloads.size(),
		1
	)
	assert_eq(
		_dictionary_reference(
			_storage.captured_payloads[0],
			"metadata"
		),
		expected_metadata
	)
	assert_eq(
		results.size(),
		0
	)
	_storage.complete_next()
	assert_eq(
		results.size(),
		2
	)
	var result: GFSaveProfileResult = await operation.wait_result_async()
	assert_eq(
		GFVariantData.get_option_int(
			result.get_metadata(),
			"request_id"
		),
		42
	)


func test_request_rejects_unsafe_and_oversized_metadata_before_consuming_mutations() -> void:
	var object: RefCounted = RefCounted.new()
	var object_array: Array[Resource] = []
	var script_array: Array[ChunkedProvider] = []
	var object_keys: Dictionary[Resource, String] = {}
	var object_values: Dictionary[String, Resource] = {}
	var callable_array: Array[Callable] = []
	var signal_array: Array[Signal] = []
	var rid_array: Array[RID] = []
	assert_true(script_array.get_typed_script() is Script)
	var cycle: Array = []
	cycle.append(cycle)
	var excessive: PackedByteArray = PackedByteArray()
	assert_eq(
		excessive.resize(1_048_577),
		OK
	)
	var invalid_inputs: Array[Dictionary] = [
		{ "object": object },
		{ "object_array": object_array },
		{ "script_array": script_array },
		{ "object_keys": object_keys },
		{ "object_values": object_values },
		{ "callable_array": callable_array },
		{ "signal_array": signal_array },
		{ "rid_array": rid_array },
		{ "cycle": cycle },
		{ "not_finite": INF },
		{ "bytes": excessive },
		{ "text": "x".repeat(262_145) },
	]
	var mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"history",
		1,
		{ "value": 1 }
	)
	for input: Dictionary in invalid_inputs:
		assert_null(
			GFSaveProfileRequest.create(
				input,
				{},
				{}
			)
		)
		assert_null(
			GFSaveProfileRequest.create(
				{},
				input,
				{}
			)
		)
		assert_null(
			GFSaveProfileRequest.create(
				{},
				{},
				input
			)
		)
		assert_null(GFSaveProfileReconcileRequest.create(input, {}))
		assert_null(
			GFSaveProfileMutationRequest.create(
				[mutation],
				{},
				input,
				{}
			)
		)
		assert_true(mutation.is_available())
	cycle.clear()


func test_request_preserves_safe_typed_container_snapshots() -> void:
	var integers: Array[int] = [1, 2]
	var empty_vectors: Array[Vector3] = []
	var scores: Dictionary[String, int] = { "first": 1 }
	var metadata: Dictionary = {
		"integers": integers,
		"empty_vectors": empty_vectors,
		"scores": scores,
	}
	var request: GFSaveProfileRequest = GFSaveProfileRequest.create(
		metadata,
		{},
		{}
	)
	assert_not_null(request)
	if request == null:
		return
	integers.append(3)
	scores["first"] = 99
	var claim: Dictionary = request.claim_for_framework()
	var captured: Dictionary = _dictionary_reference(claim, "document_metadata")
	var captured_integers: Array = captured.get("integers")
	var captured_vectors: Array = captured.get("empty_vectors")
	var captured_scores: Dictionary = captured.get("scores")
	assert_eq(
		captured_integers.get_typed_builtin(),
		TYPE_INT
	)
	assert_eq(
		captured_integers,
		[1, 2]
	)
	assert_eq(
		captured_vectors.get_typed_builtin(),
		TYPE_VECTOR3
	)
	assert_true(captured_vectors.is_empty())
	assert_eq(
		captured_scores.get_typed_key_builtin(),
		TYPE_STRING
	)
	assert_eq(
		captured_scores.get_typed_value_builtin(),
		TYPE_INT
	)
	assert_eq(
		captured_scores,
		{ "first": 1 }
	)


func test_request_rejects_excessive_depth_and_expanded_shared_graph() -> void:
	var deep: Dictionary = {}
	for _index: int in range(66):
		deep = { "next": deep }
	assert_null(
		GFSaveProfileRequest.create(
			deep,
			{},
			{}
		)
	)
	var shared: Array = [1]
	for _index: int in range(20):
		shared = [shared, shared]
	assert_null(
		GFSaveProfileRequest.create(
			{},
			{ "shared": shared },
			{}
		)
	)


func test_mutation_and_reconcile_requests_isolate_metadata() -> void:
	var metadata: Dictionary = {
		"nested": [1, 2],
	}
	var mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"history",
		1,
		{ "value": 1 }
	)
	var mutation_request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create(
		[mutation],
		metadata,
		metadata,
		metadata
	)
	var reconcile_request: GFSaveProfileReconcileRequest = GFSaveProfileReconcileRequest.create(metadata, metadata)
	assert_not_null(mutation_request)
	assert_not_null(reconcile_request)
	if mutation_request == null or reconcile_request == null:
		return
	var original: Array = metadata.get("nested")
	original.append(3)
	var mutation_claim: Dictionary = mutation_request.claim_for_framework()
	var reconcile_claim: Dictionary = reconcile_request.claim_for_framework()
	for key: String in [
		"document_metadata",
		"context",
		"result_metadata",
	]:
		var nested_value: Variant = _dictionary_reference(mutation_claim, key).get("nested")
		assert_true(nested_value is Array)
		if nested_value is Array:
			var nested: Array = nested_value
			assert_eq(
				nested,
				[1, 2]
			)
	for key: String in ["context", "result_metadata"]:
		var nested_value: Variant = _dictionary_reference(reconcile_claim, key).get("nested")
		assert_true(nested_value is Array)
		if nested_value is Array:
			var nested: Array = nested_value
			assert_eq(
				nested,
				[1, 2]
			)


func test_load_and_flush_reject_unbounded_metadata_without_scheduling() -> void:
	var provider: ChunkedProvider = _make_provider(&"history", 1)
	assert_true(_register(_make_profile(&"test.metadata_rejection", provider)))
	var invalid: Dictionary = { "object": RefCounted.new() }
	var load_operation: GFSaveProfileOperation = _utility.load_profile(&"test.metadata_rejection", invalid)
	var flush_operation: GFSaveProfileOperation = _utility.flush_profile(&"test.metadata_rejection", invalid)
	var loaded: GFSaveProfileResult = await load_operation.wait_result_async()
	var flushed: GFSaveProfileResult = await flush_operation.wait_result_async()
	assert_eq(
		loaded.get_status(),
		GFSaveProfileResult.STATUS_INVALID_REQUEST
	)
	assert_eq(
		flushed.get_status(),
		GFSaveProfileResult.STATUS_INVALID_REQUEST
	)
	assert_eq(provider.begin_call_count, 0)
	assert_eq(_storage.save_call_count, 0)


func test_rejection_does_not_claim_request_and_claimed_request_is_invalid() -> void:
	var request: GFSaveProfileRequest = GFSaveProfileRequest.create(
		{ "document": true },
		{ "context": true },
		{ "result": true }
	)

	var missing: GFSaveProfileOperation = _utility.save_profile(&"test.request_rejection", request)

	assert_eq(
		missing.get_result().get_status(),
		GFSaveProfileResult.STATUS_INVALID_PROFILE
	)
	assert_false(request.is_claimed())

	var provider: ChunkedProvider = _make_provider(&"history", 1)
	assert_true(_register(_make_profile(&"test.request_rejection", provider)))
	var accepted: GFSaveProfileOperation = _utility.save_profile(&"test.request_rejection", request)
	var duplicate_request_operation: GFSaveProfileOperation = _utility.save_profile(&"test.request_rejection", request)
	var uninitialized: GFSaveProfileRequest = GFSaveProfileRequest.new()
	var invalid: GFSaveProfileOperation = _utility.save_profile(&"test.request_rejection", uninitialized)

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
	assert_eq(
		first_provider.latest_operation.produced_values.size(),
		0
	)
	assert_eq(
		second_provider.latest_operation.produced_values.size(),
		0
	)

	_utility.tick(0.0)

	assert_eq(
		first_provider.latest_operation.produced_values.size(),
		1
	)
	assert_eq(
		second_provider.latest_operation.produced_values.size(),
		1
	)


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
	assert_eq(
		operation.get_result().get_failed_section_id(),
		&"broken"
	)
	assert_eq(
		operation.get_result().get_attempt_count(),
		0
	)
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
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_DISPOSED
	)
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
	assert_eq(
		result.get_preparation_duration_msec(),
		10
	)
	assert_eq(
		result.get_storage_duration_msec(),
		7
	)
	assert_true(result.get_preparation_work_units() >= 3)
	assert_null(
		result.get_document(),
		"Save result 不应复制完整文档。"
	)
	assert_false(result.to_dict().has("payload"))


func _make_provider(section_id: StringName, required_steps: int) -> ChunkedProvider:
	var provider: ChunkedProvider = ChunkedProvider.new()
	provider.section_id = section_id
	provider.schema_version = 1
	provider.required_on_load = true
	provider.required_steps = required_steps
	return provider


func _make_profile(profile_id: StringName, provider: GFSaveSectionProvider) -> GFSaveProfile:
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
			"flags": [
				true,
				false,
				true,
				false,
			],
		}
	return values


func _dictionary_reference(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _collect_save_result(operation: GFSaveProfileOperation, results: Array[GFSaveProfileResult]) -> void:
	var result: GFSaveProfileResult = await operation.wait_result_async()
	results.append(result)
