# 测试 Save Profile 的并发世代、恢复政策和事务化 section 应用。
extends GutTest


const GF_SAVE_EXTENSION = preload("res://addons/gf/extensions/save/extension.gd")


class FaultStorage extends GFStorageUtility:
	var save_calls: Array[Dictionary] = []
	var load_calls: PackedStringArray = PackedStringArray()
	var active_io_count: int = 0
	var max_active_io_count: int = 0
	var save_start_error: Error = OK
	var load_start_error: Error = OK
	var driver: GFSaveProfileUtility = null
	var _next_request_id: int = 1
	var _pending_save_operations: Array[GFStorageAsyncOperation] = []
	var _pending_load_operations: Array[GFStorageAsyncOperation] = []

	func save_data_request_async(
		file_name: String,
		data: Dictionary,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
		save_calls.append({
			"file_name": file_name,
			"data": data.duplicate(true),
		})
		if save_start_error != OK:
			_complete_operation(operation, save_start_error, null)
			return operation
		_pending_save_operations.append(operation)
		active_io_count += 1
		max_active_io_count = maxi(max_active_io_count, active_io_count)
		return operation

	func save_payload_request_async(
		file_name: String,
		transfer: GFStoragePayloadTransfer,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
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
			_complete_operation(
				operation,
				ERR_INVALID_PARAMETER,
				null,
				GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			)
			return operation
		var attempt_id: int = GFVariantData.get_option_int(attempt, "attempt_id")
		var _configured_transfer: bool = operation.configure_payload_attempt_for_framework(
			transfer,
			attempt_id
		)
		save_calls.append({
			"file_name": file_name,
			"data": GFVariantData.get_option_dictionary(attempt, "payload").duplicate(true),
		})
		if save_start_error != OK:
			_complete_operation(operation, save_start_error, null)
			return operation
		_pending_save_operations.append(operation)
		active_io_count += 1
		max_active_io_count = maxi(max_active_io_count, active_io_count)
		return operation

	func load_data_request_async(
		file_name: String,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_LOAD,
			file_name
		)
		var _appended: bool = load_calls.append(file_name)
		if load_start_error != OK:
			var failed: GFStorageReadResult = GFStorageReadResult.new().configure_failure(
				"Injected load start failure.",
				load_start_error,
				{},
				GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
				0,
				GFStorageReadResult.FailureKind.IO_FAILED
			)
			_complete_operation(operation, load_start_error, failed)
			return operation
		_pending_load_operations.append(operation)
		active_io_count += 1
		max_active_io_count = maxi(max_active_io_count, active_io_count)
		return operation

	func complete_save(error_code: Error) -> void:
		if _pending_save_operations.is_empty() and driver != null:
			driver.tick(0.0)
		if _pending_save_operations.is_empty():
			return
		var operation: GFStorageAsyncOperation = _pending_save_operations.pop_front()
		active_io_count = maxi(active_io_count - 1, 0)
		_complete_operation(operation, error_code, null)
		if driver != null:
			driver.tick(0.0)

	func complete_save_payload_invalid(worker_report: Dictionary) -> void:
		if _pending_save_operations.is_empty() and driver != null:
			driver.tick(0.0)
		if _pending_save_operations.is_empty():
			return
		var operation: GFStorageAsyncOperation = _pending_save_operations.pop_front()
		active_io_count = maxi(active_io_count - 1, 0)
		_complete_operation(
			operation,
			ERR_INVALID_DATA,
			null,
			GFStorageAsyncResult.WriteFailureKind.PAYLOAD_INVALID,
			worker_report
		)
		if driver != null:
			driver.tick(0.0)

	func complete_load(result: GFStorageReadResult) -> void:
		if _pending_load_operations.is_empty() and driver != null:
			driver.tick(0.0)
		if _pending_load_operations.is_empty():
			return
		var operation: GFStorageAsyncOperation = _pending_load_operations.pop_front()
		active_io_count = maxi(active_io_count - 1, 0)
		_complete_operation(operation, result.error_code, result)
		if driver != null:
			driver.tick(0.0)

	func get_pending_save_count() -> int:
		return _pending_save_operations.size()

	func _make_operation(operation_kind: StringName, file_name: String) -> GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
		var _configured: bool = operation.configure_for_framework(
			_next_request_id,
			operation_kind,
			file_name
		)
		_next_request_id += 1
		return operation

	func _complete_operation(
		operation: GFStorageAsyncOperation,
		error_code: Error,
		read_result: GFStorageReadResult,
		write_failure_kind: GFStorageAsyncResult.WriteFailureKind = (
			GFStorageAsyncResult.WriteFailureKind.NONE
		),
		write_validation_report: Dictionary = {}
	) -> void:
		var _finished_transfer: bool = operation.finish_payload_attempt_for_framework()
		var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
		var successful: bool = error_code == OK
		if operation.get_operation() == GFStorageAsyncOperation.OPERATION_LOAD:
			successful = read_result != null and read_result.ok
		var resolved_write_failure_kind: GFStorageAsyncResult.WriteFailureKind = (
			_resolve_write_failure_kind(
				operation.get_operation(),
				error_code,
				write_failure_kind
			)
		)
		var _configured: bool = result.configure_for_framework(
			operation.get_request_id(),
			operation.get_operation(),
			operation.get_file_name(),
			successful,
			error_code,
			read_result,
			resolved_write_failure_kind,
			write_validation_report
		)
		var _completed: bool = operation.complete_for_framework(result)

	static func _resolve_write_failure_kind(
		operation_kind: StringName,
		error_code: Error,
		requested_failure_kind: GFStorageAsyncResult.WriteFailureKind
	) -> GFStorageAsyncResult.WriteFailureKind:
		if operation_kind != GFStorageAsyncOperation.OPERATION_SAVE or error_code == OK:
			return GFStorageAsyncResult.WriteFailureKind.NONE
		if requested_failure_kind != GFStorageAsyncResult.WriteFailureKind.NONE:
			return requested_failure_kind
		match error_code:
			ERR_INVALID_PARAMETER:
				return GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			ERR_UNAVAILABLE:
				return GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
			ERR_CANT_CREATE:
				return GFStorageAsyncResult.WriteFailureKind.THREAD_START_FAILED
		return GFStorageAsyncResult.WriteFailureKind.IO_FAILED


class AutomaticCooperativeRealStorage extends GFStorageUtility:
	var thread_start_call_count: int = 0

	func has_async_thread_capability_for_framework() -> bool:
		return false

	func start_async_worker_for_framework(
		_task_type: StringName,
		_thread: Thread,
		_callback: Callable
	) -> Error:
		thread_start_call_count += 1
		return ERR_CANT_CREATE


class MemorySectionProvider extends GFSaveSectionProvider:
	var value: int = 0
	var fail_preparation: bool = false
	var fail_capture: bool = false
	var fail_apply: bool = false
	var fail_rollback: bool = false
	var apply_count: int = 0
	var rollback_count: int = 0
	var events: Array[String] = []
	var shared_events: Array[String] = []
	var preparation_callback: Callable = Callable()

	func _begin_save_snapshot(
		_context: Dictionary = {}
	) -> GFSaveSectionSnapshotOperation:
		events.append("prepare:%s" % String(section_id))
		shared_events.append("prepare:%s" % String(section_id))
		if preparation_callback.is_valid():
			var _callback_result: Variant = preparation_callback.call()
		if fail_preparation:
			var failed: GFSaveSectionSnapshotOperation = GFSaveSectionSnapshotOperation.new()
			var _failed: bool = failed._fail_snapshot(
				ERR_INVALID_DATA,
				"Injected snapshot failure."
			)
			return failed
		return make_completed_snapshot({"value": value})

	func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
		if fail_capture:
			return null
		return make_section({"value": value})

	func _apply_section(section: GFSaveSection, _context: Dictionary = {}) -> Error:
		events.append("apply:%s" % String(section_id))
		shared_events.append("apply:%s" % String(section_id))
		apply_count += 1
		var payload: Variant = section.get_payload()
		if fail_apply or not payload is Dictionary:
			return ERR_INVALID_DATA
		value = GFVariantData.get_option_int(GFVariantData.as_dictionary(payload), "value")
		return OK

	func _rollback_section(section: GFSaveSection, _context: Dictionary = {}) -> Error:
		events.append("rollback:%s" % String(section_id))
		shared_events.append("rollback:%s" % String(section_id))
		rollback_count += 1
		var payload: Variant = section.get_payload()
		if fail_rollback or not payload is Dictionary:
			return ERR_CANT_RESOLVE
		value = GFVariantData.get_option_int(GFVariantData.as_dictionary(payload), "value")
		return OK


class FailingMigrationStep extends GFSaveMigrationStep:
	func _migrate_document(
		_document: GFSaveDocument,
		_context: Dictionary = {}
	) -> GFSaveDocument:
		return null


var _clock: GFManualClock
var _storage: FaultStorage
var _utility: GFSaveProfileUtility


func before_each() -> void:
	_clock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	_storage = FaultStorage.new()
	_utility = GFSaveProfileUtility.new().setup(_storage, _clock)
	_storage.driver = _utility


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null
	if _storage != null:
		_storage.driver = null
		_storage.dispose()
	_storage = null
	_clock = null


func test_save_requests_coalesce_to_latest_generation_without_parallel_writes() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	assert_true(_register(_make_profile(&"test.save", provider)))

	provider.value = 1
	var first: GFSaveProfileOperation = _utility.save_profile(&"test.save")
	_utility.tick(0.0)
	provider.value = 2
	var second: GFSaveProfileOperation = _utility.save_profile(&"test.save")
	provider.value = 3
	var third: GFSaveProfileOperation = _utility.save_profile(&"test.save")

	assert_eq(_storage.save_calls.size(), 1, "首个写入在途时不得启动并行写入。")
	assert_eq(_storage.max_active_io_count, 1)
	assert_false(second.is_completed())
	assert_false(third.is_completed())

	_storage.complete_save(OK)

	assert_true(first.is_completed(), "首个 generation 应在自己的写入完成后结束。")
	assert_eq(_storage.save_calls.size(), 2, "中间请求应合并为一次后续写入。")
	assert_eq(_get_saved_value(_storage.save_calls[1]), 3, "后续写入必须在启动时采集最新状态。")
	assert_false(second.is_completed(), "被合并请求必须等待覆盖其 generation 的写入。")

	_storage.complete_save(OK)

	assert_true(second.is_completed())
	assert_true(third.is_completed())
	assert_true(second.get_result().was_coalesced())
	assert_false(third.get_result().was_coalesced())
	assert_eq(second.get_result().get_persisted_generation(), 3)
	assert_eq(_storage.max_active_io_count, 1, "任意时刻只允许一个底层 IO。")


func test_activation_declares_and_requires_storage_without_bootstrapping_profiles() -> void:
	var dependencies: Array[Script] = _utility.get_required_utilities()
	assert_eq(dependencies, [GFStorageUtility])
	var standalone: GFSaveProfileUtility = GFSaveProfileUtility.new()
	var failed: GFAsyncCompletion = standalone.begin_activation(GFAsyncScope.new())
	assert_true(failed.is_completed())
	assert_false(failed.is_successful())
	assert_true(standalone.get_profile_state_snapshot(&"implicit").is_empty())
	standalone.dispose()

	var activated: GFAsyncCompletion = _utility.begin_activation(GFAsyncScope.new())
	assert_true(activated.is_successful(), "standalone setup 注入 Storage 后应允许激活。")


func test_quiesce_rejects_new_admission_but_drains_accepted_profile_work() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 17)
	var profile: GFSaveProfile = _make_profile(&"test.quiesce", provider)
	assert_true(_register(profile))
	var accepted: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_count(), 1)

	var completion: GFAsyncCompletion = _utility.begin_quiesce(GFAsyncScope.new())
	assert_false(completion.is_completed())
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{"document": 1},
		{"context": 2},
		{"result": 3}
	)
	var rejected_save: GFSaveProfileOperation = _utility.save_profile(
		profile.profile_id,
		request
	)
	var rejected_load: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	var rejected_flush: GFSaveProfileOperation = _utility.flush_profile(profile.profile_id)
	assert_eq(rejected_save.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_eq(rejected_load.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_eq(rejected_flush.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(request.claim_for_framework().is_empty(), "准入拒绝不得消费 save request 所有权。")
	assert_false(_utility.unregister_profile(profile.profile_id))
	var registration: Dictionary = _utility.register_profile(
		_make_profile(&"test.quiesce.new", _make_provider(&"new", 1))
	)
	assert_true(_report_contains_issue(registration, &"utility_quiescing"))

	_storage.complete_save(OK)

	assert_true(accepted.is_completed())
	assert_true(accepted.get_result().is_successful())
	assert_true(completion.is_successful(), "已接纳 operation 和底层写入收敛后 quiesce 应成功。")


func test_flush_waits_for_latest_generation_visible_at_call_time() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	assert_true(_register(_make_profile(&"test.flush", provider)))

	var _first_save: GFSaveProfileOperation = _utility.save_profile(&"test.flush")
	_utility.tick(0.0)
	provider.value = 2
	var _second_save: GFSaveProfileOperation = _utility.save_profile(&"test.flush")
	var flush: GFSaveProfileOperation = _utility.flush_profile(&"test.flush")

	_storage.complete_save(OK)
	assert_false(flush.is_completed(), "flush 不得把较旧 generation 的完成视为已落盘。")
	_storage.complete_save(OK)

	assert_true(flush.is_completed())
	assert_true(flush.get_result().is_successful())
	assert_eq(flush.get_result().get_persisted_generation(), 2)


func test_flush_completes_when_its_captured_generation_persists() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	assert_true(_register(_make_profile(&"test.flush_captured", provider)))

	var first_save: GFSaveProfileOperation = _utility.save_profile(&"test.flush_captured")
	_utility.tick(0.0)
	var flush: GFSaveProfileOperation = _utility.flush_profile(&"test.flush_captured")
	var flush_results: Array[GFSaveProfileResult] = []
	var _connected: Error = flush.completed.connect(
		func(result: GFSaveProfileResult) -> void:
			flush_results.append(result)
	) as Error
	provider.value = 2
	var second_save: GFSaveProfileOperation = _utility.save_profile(&"test.flush_captured")

	_storage.complete_save(OK)

	assert_true(first_save.get_result().is_successful())
	assert_true(flush.is_completed(), "捕获的 generation 已持久化后 flush 必须立即完成。")
	if not flush.is_completed():
		return
	assert_true(flush.get_result().is_successful())
	assert_eq(flush.get_result().get_status(), GFSaveProfileResult.STATUS_FLUSHED)
	assert_eq(flush.get_result().get_requested_generation(), 1)
	assert_eq(flush.get_result().get_persisted_generation(), 1)
	assert_eq(flush_results.size(), 1, "捕获屏障满足时只允许一次 flush 终态通知。")
	assert_false(second_save.is_completed(), "调用后产生的 generation 不属于该 flush 屏障。")

	_storage.complete_save(FAILED)

	assert_true(flush.get_result().is_successful(), "后续 generation 失败不得改写既有 flush 终态。")
	assert_eq(flush.get_result().get_persisted_generation(), 1)
	assert_eq(flush_results.size(), 1, "后续 generation 终态不得重复完成旧 flush。")
	assert_false(second_save.get_result().is_successful())


func test_load_waits_for_save_barrier_before_starting_storage_read() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.load_barrier", provider)
	assert_true(_register(profile))
	var _save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var load_operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)

	assert_eq(_storage.load_calls.size(), 0, "保存屏障完成前不得读取旧文件。")
	_storage.complete_save(OK)
	assert_eq(_storage.load_calls.size(), 1)
	_storage.complete_load(_read_success(_make_document(profile, {&"state": {"value": 8}})))

	assert_true(load_operation.get_result().is_successful())
	assert_eq(load_operation.get_result().get_attempt_count(), 1)
	assert_eq(provider.value, 8)


func test_ready_load_runs_before_newer_queued_save() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.load_fairness", provider)
	assert_true(_register(profile))
	var first_save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var load_operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	provider.value = 2
	var second_save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)

	_storage.complete_save(OK)

	assert_true(first_save.get_result().is_successful())
	assert_eq(_storage.load_calls.size(), 1, "generation 屏障满足后，最老读取必须先于更新保存启动。")
	assert_eq(_storage.save_calls.size(), 1, "更新保存不得让已就绪读取持续饥饿。")
	if _storage.load_calls.size() != 1:
		return
	_storage.complete_load(_read_success(_make_document(profile, {&"state": {"value": 8}})))
	assert_true(load_operation.get_result().is_successful())
	assert_eq(_storage.save_calls.size(), 2, "读取完成后应继续处理更新保存。")
	_storage.complete_save(OK)
	assert_true(second_save.get_result().is_successful())


func test_ready_load_and_pending_save_use_bounded_fair_turns() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.load_save_fairness", provider)
	assert_true(_register(profile))
	var _first_save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var first_load: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	var second_load: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	provider.value = 2
	var second_save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)

	_storage.complete_save(OK)
	assert_eq(_storage.load_calls.size(), 1, "保存后应先服务一个已就绪读取。")
	assert_eq(_storage.save_calls.size(), 1)
	_storage.complete_load(_read_success(_make_document(profile, {&"state": {"value": 8}})))

	assert_true(first_load.get_result().is_successful())
	assert_eq(_storage.save_calls.size(), 2, "服务一个就绪读取后必须给等待保存一个轮次。")
	assert_eq(_storage.load_calls.size(), 1, "剩余就绪读取不得反向饿死等待保存。")
	_storage.complete_save(OK)
	assert_true(second_save.get_result().is_successful())
	assert_eq(_storage.load_calls.size(), 2, "保存轮次结束后应继续处理最老读取。")
	_storage.complete_load(_read_success(_make_document(profile, {&"state": {"value": 9}})))
	assert_true(second_load.get_result().is_successful())


func test_transient_write_failure_uses_bounded_monotonic_retry_schedule() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 4)
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.retry_delays_msec = PackedInt32Array([10])
	assert_true(_register(_make_profile(&"test.retry", provider, policy)))
	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.retry")

	_storage.complete_save(ERR_BUSY)
	assert_false(operation.is_completed())
	assert_eq(_storage.save_calls.size(), 1)
	var _advanced_nine: bool = _clock.advance_msec(9)
	_utility.tick(0.0)
	assert_eq(_storage.save_calls.size(), 1, "重试截止时间前不得提前启动。")
	var _advanced_one: bool = _clock.advance_msec(1)
	_utility.tick(0.0)
	assert_eq(_storage.save_calls.size(), 2)

	_storage.complete_save(OK)

	assert_true(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_attempt_count(), 2)


func test_permanent_write_failure_does_not_consume_retry_budget() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 4)
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.retry_delays_msec = PackedInt32Array([1, 2, 3])
	assert_true(_register(_make_profile(&"test.permanent", provider, policy)))
	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.permanent")

	_storage.complete_save(ERR_INVALID_DATA)
	var _advanced: bool = _clock.advance_msec(100)
	_utility.tick(0.0)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)
	assert_eq(_storage.save_calls.size(), 1)


func test_transient_write_failure_stops_after_retry_schedule_is_exhausted() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 4)
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.retry_delays_msec = PackedInt32Array([1])
	assert_true(_register(_make_profile(&"test.retry_exhausted", provider, policy)))
	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.retry_exhausted")

	_storage.complete_save(ERR_BUSY)
	var _advanced: bool = _clock.advance_msec(1)
	_utility.tick(0.0)
	_storage.complete_save(ERR_BUSY)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_attempt_count(), 2)
	assert_eq(_storage.save_calls.size(), 2, "有限计划耗尽后不得继续重试。")


func test_worker_validation_failure_maps_structural_position_without_key_leakage() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 4)
	assert_true(_register(_make_profile(&"test.worker_validation", provider)))
	var operation: GFSaveProfileOperation = _utility.save_profile(
		&"test.worker_validation"
	)

	_storage.complete_save_payload_invalid({
		"failure_kind": "unsupported_variant_type",
		"path_segments": [
			{
				"kind": "dictionary_value",
				"entry_index": 4,
				"raw_key": "PRIVATE_ROOT_KEY",
				"key_token_sha256": "PRIVATE_ROOT_DIGEST",
			},
			{
				"kind": "dictionary_value",
				"entry_index": 0,
				"raw_value": "PRIVATE_SECTION_VALUE",
				"key_token_sha256": "PRIVATE_SECTION_DIGEST",
			},
		],
		"variant_type": TYPE_OBJECT,
		"variant_type_name": "PRIVATE_TYPE_NAME",
		"visited_values": 7,
	})

	assert_true(operation.is_completed())
	var result: GFSaveProfileResult = operation.get_result()
	assert_eq(result.get_status(), GFSaveProfileResult.STATUS_PREPARATION_FAILED)
	assert_eq(result.get_failed_section_id(), &"state")
	var report_text: String = JSON.stringify(result.get_validation_report())
	assert_false(report_text.contains("PRIVATE_ROOT_KEY"))
	assert_false(report_text.contains("PRIVATE_ROOT_DIGEST"))
	assert_false(report_text.contains("PRIVATE_SECTION_VALUE"))
	assert_false(report_text.contains("PRIVATE_SECTION_DIGEST"))
	assert_false(report_text.contains("PRIVATE_TYPE_NAME"))


func test_load_apply_failure_rolls_back_applied_sections_in_reverse_order() -> void:
	var shared_events: Array[String] = []
	var first: MemorySectionProvider = _make_provider(&"first", 1)
	var second: MemorySectionProvider = _make_provider(&"second", 2)
	first.shared_events = shared_events
	second.shared_events = shared_events
	second.fail_apply = true
	var profile: GFSaveProfile = _make_profile_with_providers(&"test.transaction", [first, second])
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(&"test.transaction")

	_storage.complete_load(_read_success(_make_document(profile, {
		&"first": {"value": 10},
		&"second": {"value": 20},
	})))

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_APPLY_FAILED)
	assert_eq(operation.get_result().get_failed_section_id(), &"second")
	assert_eq(first.value, 1, "首个 provider 应恢复到应用前快照。")
	assert_eq(second.value, 2, "失败 provider 不得留下部分状态。")
	assert_eq(first.rollback_count, 1)
	assert_eq(second.rollback_count, 1, "失败 provider 也可能已部分写入，必须一并回滚。")
	assert_eq(
		shared_events.slice(shared_events.size() - 2),
		["rollback:second", "rollback:first"]
	)


func test_load_reports_distinct_terminal_when_provider_rollback_fails() -> void:
	var first: MemorySectionProvider = _make_provider(&"first", 1)
	first.fail_rollback = true
	var second: MemorySectionProvider = _make_provider(&"second", 2)
	second.fail_apply = true
	var profile: GFSaveProfile = _make_profile_with_providers(&"test.rollback_failure", [first, second])
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)

	_storage.complete_load(_read_success(_make_document(profile, {
		&"first": {"value": 10},
		&"second": {"value": 20},
	})))

	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_ROLLBACK_FAILED)
	assert_eq(operation.get_result().get_rollback_errors().size(), 1)
	assert_eq(operation.get_result().get_rollback_errors()[0].get_section_id(), &"first")
	assert_eq(first.value, 10, "回滚失败必须显式暴露可能不一致的运行时状态。")


func test_missing_data_defaults_to_failure_and_explicit_policy_preserves_current_state() -> void:
	var default_provider: MemorySectionProvider = _make_provider(&"state", 7)
	assert_true(_register(_make_profile(&"test.missing.default", default_provider)))
	var failed: GFSaveProfileOperation = _utility.load_profile(&"test.missing.default")
	_storage.complete_load(_read_failure(
		ERR_FILE_NOT_FOUND,
		"File not found",
		GFStorageReadResult.FailureKind.NOT_FOUND
	))

	assert_false(failed.get_result().is_successful())
	assert_eq(failed.get_result().get_status(), GFSaveProfileResult.STATUS_MISSING)
	assert_not_null(failed.get_result().get_storage_result())

	var recovery: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	recovery.missing_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	var recovered_provider: MemorySectionProvider = _make_provider(&"state", 9)
	assert_true(_register(_make_profile(&"test.missing.recover", recovered_provider, recovery)))
	var recovered: GFSaveProfileOperation = _utility.load_profile(&"test.missing.recover")
	_storage.complete_load(_read_failure(
		ERR_FILE_NOT_FOUND,
		"File not found",
		GFStorageReadResult.FailureKind.NOT_FOUND
	))

	assert_true(recovered.get_result().is_successful())
	assert_true(recovered.get_result().was_recovered())
	assert_eq(recovered.get_result().get_recovery_action(), GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE)
	assert_eq(recovered_provider.value, 9, "恢复读取不得改写当前内存状态。")
	assert_eq(_storage.save_calls.size(), 0, "恢复读取不得自动覆盖原文件。")


func test_future_schema_never_uses_corrupt_recovery_action() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.corrupt_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	var provider: MemorySectionProvider = _make_provider(&"state", 5)
	var profile: GFSaveProfile = _make_profile(&"test.future", provider, policy)
	assert_true(_register(profile))
	var future_document: GFSaveDocument = _make_document(profile, {&"state": {"value": 99}})
	var _configured: GFSaveDocument = future_document.configure(
		profile.profile_id,
		profile.schema_version + 1,
		future_document.get_sections(),
		future_document.get_metadata()
	)
	var operation: GFSaveProfileOperation = _utility.load_profile(&"test.future")

	_storage.complete_load(_read_success(future_document))

	assert_false(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_FUTURE_SCHEMA)
	assert_false(operation.get_result().was_recovered())
	assert_eq(provider.value, 5)


func test_storage_request_identity_ignores_other_same_file_completions() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.request_identity", provider)
	assert_true(_register(profile))
	var first: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var external: GFStorageAsyncOperation = _storage.save_data_request_async(
		profile.file_name,
		{"external": true}
	)
	provider.value = 2
	var second: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)

	_storage.complete_save(OK)
	assert_true(first.is_completed())
	assert_false(second.is_completed())
	_storage.complete_save(OK)
	assert_true(external.is_completed())
	assert_false(second.is_completed(), "外部同路径请求不得完成 Profile 的 generation。")
	_storage.complete_save(OK)
	assert_true(second.get_result().is_successful())


func test_registered_profile_uses_compiled_identity_after_resource_mutation() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 3)
	var profile: GFSaveProfile = _make_profile(&"test.compiled", provider)
	var original_file_name: String = profile.file_name
	assert_true(_register(profile))
	profile.profile_id = &"mutated.runtime"
	profile.schema_id = &"mutated.schema"
	profile.file_name = "mutated.sav"
	profile.providers = []

	var operation: GFSaveProfileOperation = _utility.save_profile(&"test.compiled")
	_utility.tick(0.0)
	assert_eq(GFVariantData.get_option_string(_storage.save_calls[0], "file_name"), original_file_name)
	_storage.complete_save(OK)
	assert_true(operation.get_result().is_successful())


func test_registration_rejects_duplicate_exact_storage_targets() -> void:
	var first: GFSaveProfile = _make_profile(&"test.path.first", _make_provider(&"state", 1))
	first.file_name = "slot/data.sav"
	var second: GFSaveProfile = _make_profile(&"test.path.second", _make_provider(&"state", 2))
	second.file_name = "slot/data.sav"
	assert_true(_register(first))
	var report: Dictionary = _utility.register_profile(second)
	assert_false(GFVariantData.get_option_bool(report, "registered"))
	assert_true(_report_contains_issue(report, &"duplicate_storage_target"))


func test_registration_rejects_noncanonical_storage_target_before_claim() -> void:
	var profile: GFSaveProfile = _make_profile(&"test.path.invalid", _make_provider(&"state", 1))
	profile.file_name = "slot\\data.sav"

	var report: Dictionary = _utility.register_profile(profile)

	assert_false(GFVariantData.get_option_bool(report, "registered"))
	assert_true(_report_contains_issue(report, &"invalid_storage_path"))
	assert_push_error(
		"[GFStorageUtility] canonicalize_data_file_name 失败：file_name 不满足 portable logical path profile。"
	)


func test_save_is_explicitly_rejected_while_load_is_active() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 10)
	var profile: GFSaveProfile = _make_profile(&"test.load_save_conflict", provider)
	assert_true(_register(profile))
	var load_operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_utility.tick(0.0)
	provider.value = 20
	var rejected_save: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	assert_eq(rejected_save.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_eq(_storage.save_calls.size(), 0)
	_storage.complete_load(_read_success(_make_document(profile, {&"state": {"value": 1}})))
	assert_true(load_operation.get_result().is_successful())
	assert_eq(provider.value, 1)


func test_dispose_reports_active_write_as_outcome_unknown_once() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 7)
	var profile: GFSaveProfile = _make_profile(&"test.dispose_unknown", provider)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	provider.value = 8
	var queued_operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var completions: Array[String] = []
	var _connected: Error = operation.completed.connect(
		func(_result: GFSaveProfileResult) -> void:
			completions.append("completed")
	) as Error
	_utility.dispose()
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(operation.get_result().get_storage_request_ids().size(), 1)
	assert_eq(queued_operation.get_result().get_status(), GFSaveProfileResult.STATUS_DISPOSED)
	assert_eq(queued_operation.get_result().get_storage_request_ids().size(), 0)
	assert_eq(completions.size(), 1)
	_storage.complete_save(OK)
	assert_eq(completions.size(), 1, "迟到 Storage 终态不得覆盖 disposal 结果。")


func test_non_strict_invalid_integrity_still_uses_corrupt_policy() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 5)
	var profile: GFSaveProfile = _make_profile(&"test.integrity", provider)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	var result: GFStorageReadResult = _read_success(
		_make_document(profile, {&"state": {"value": 99}})
	)
	result.integrity_status = GFStorageReadResult.IntegrityStatus.INVALID
	_storage.complete_load(result)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_CORRUPT)
	assert_eq(provider.value, 5)


func test_storage_future_version_never_uses_corrupt_recovery() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.corrupt_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	var profile: GFSaveProfile = _make_profile(
		&"test.storage_future",
		_make_provider(&"state", 4),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_storage.complete_load(_read_failure(
		ERR_INVALID_DATA,
		"Unsupported future storage version.",
		GFStorageReadResult.FailureKind.FUTURE_VERSION
	))
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_FUTURE_SCHEMA)
	assert_false(operation.get_result().was_recovered())


func test_provider_reentrant_save_is_rejected_without_recursive_io() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.reentrant", provider)
	assert_true(_register(profile))
	var nested_operations: Array[GFSaveProfileOperation] = []
	provider.preparation_callback = func() -> void:
		nested_operations.append(_utility.save_profile(profile.profile_id))
	var outer: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	assert_eq(_storage.save_calls.size(), 1)
	assert_eq(nested_operations.size(), 1)
	assert_eq(nested_operations[0].get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	_storage.complete_save(OK)
	assert_true(outer.get_result().is_successful())
	provider.preparation_callback = Callable()


func test_completion_callback_dispose_leaves_disposed_as_final_state() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.completion_dispose", provider)
	assert_true(_register(profile))
	var states: Array[StringName] = []
	var _state_connected: Error = _utility.profile_state_changed.connect(
		func(_profile_id: StringName, _previous: StringName, current: StringName) -> void:
			states.append(current)
	) as Error
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var _operation_connected: Error = operation.completed.connect(
		func(_result: GFSaveProfileResult) -> void:
			_utility.dispose()
	) as Error
	_storage.complete_save(OK)
	assert_true(operation.get_result().is_successful())
	assert_eq(states[-1], GFSaveProfileUtility.STATE_DISPOSED)
	assert_eq(states.count(GFSaveProfileUtility.STATE_IDLE), 1)


func test_unknown_section_preserve_round_trips_opaque_data() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.unknown_preserve", provider)
	profile.unknown_section_policy = GFSaveProfile.UNKNOWN_SECTION_PRESERVE
	assert_true(_register(profile))
	var document: GFSaveDocument = _make_document(profile, {&"state": {"value": 2}})
	var _unknown_set: bool = document.set_section(
		GFSaveSection.new().configure(&"external", 9, {"opaque": "kept"})
	)
	var load_operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_storage.complete_load(_read_success(document))
	assert_true(load_operation.get_result().is_successful())
	var save_operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var saved: GFSaveDocument = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(_storage.save_calls[-1], "data")
	)
	assert_not_null(saved)
	assert_true(saved.has_section(&"external"))
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(saved.get_section(&"external").get_payload()),
			"opaque"
		),
		"kept"
	)
	_storage.complete_save(OK)
	assert_true(save_operation.get_result().is_successful())


func test_unknown_section_reject_is_default_and_drop_is_explicit() -> void:
	var reject_provider: MemorySectionProvider = _make_provider(&"state", 1)
	var reject_profile: GFSaveProfile = _make_profile(&"test.unknown_reject", reject_provider)
	assert_true(_register(reject_profile))
	var reject_document: GFSaveDocument = _make_document(
		reject_profile,
		{&"state": {"value": 2}}
	)
	var _reject_unknown_set: bool = reject_document.set_section(
		GFSaveSection.new().configure(&"external", 1, {"value": 8})
	)
	var rejected: GFSaveProfileOperation = _utility.load_profile(reject_profile.profile_id)
	_storage.complete_load(_read_success(reject_document))
	assert_eq(rejected.get_result().get_status(), GFSaveProfileResult.STATUS_VALIDATION_FAILED)

	var drop_provider: MemorySectionProvider = _make_provider(&"state", 3)
	var drop_profile: GFSaveProfile = _make_profile(&"test.unknown_drop", drop_provider)
	drop_profile.unknown_section_policy = GFSaveProfile.UNKNOWN_SECTION_DROP
	assert_true(_register(drop_profile))
	var drop_document: GFSaveDocument = _make_document(drop_profile, {&"state": {"value": 4}})
	var _drop_unknown_set: bool = drop_document.set_section(
		GFSaveSection.new().configure(&"external", 1, {"value": 8})
	)
	var loaded: GFSaveProfileOperation = _utility.load_profile(drop_profile.profile_id)
	_storage.complete_load(_read_success(drop_document))
	assert_true(loaded.get_result().is_successful())
	var _saved: GFSaveProfileOperation = _utility.save_profile(drop_profile.profile_id)
	_utility.tick(0.0)
	var saved_document: GFSaveDocument = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(_storage.save_calls[-1], "data")
	)
	assert_false(saved_document.has_section(&"external"))
	_storage.complete_save(OK)


func test_writable_profile_rejects_required_load_only_provider() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	provider.save_enabled = false
	var profile: GFSaveProfile = _make_profile(&"test.read_only", provider)
	var report: Dictionary = _utility.register_profile(profile)
	assert_false(GFVariantData.get_option_bool(report, "registered"))
	assert_true(_report_contains_issue(report, &"required_provider_not_saveable"))
	profile.save_enabled = false
	assert_true(_register(profile))
	var save_operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	assert_eq(
		save_operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION
	)


func test_start_failures_are_typed_and_do_not_hang() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.start_failure", provider)
	assert_true(_register(profile))
	_storage.save_start_error = ERR_CANT_CREATE
	var save_operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	assert_eq(save_operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)
	assert_eq(save_operation.get_result().get_attempt_count(), 1)
	_storage.save_start_error = OK
	var load_provider: MemorySectionProvider = _make_provider(&"state", 2)
	var load_profile: GFSaveProfile = _make_profile(&"test.load_start_failure", load_provider)
	assert_true(_register(load_profile))
	_storage.load_start_error = ERR_CANT_OPEN
	var load_operation: GFSaveProfileOperation = _utility.load_profile(load_profile.profile_id)
	_utility.tick(0.0)
	assert_eq(load_operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)
	assert_eq(load_operation.get_result().get_attempt_count(), 1)


func test_save_timeout_reports_outcome_unknown_and_ignores_late_completion() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	var profile: GFSaveProfile = _make_profile(
		&"test.timeout",
		_make_provider(&"state", 1),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var _advanced: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(operation.get_result().get_storage_request_ids().size(), 1)
	_storage.complete_save(OK)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)


func test_detached_write_success_cancels_pending_retry() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	policy.retry_delays_msec = PackedInt32Array([5])
	var profile: GFSaveProfile = _make_profile(
		&"test.detached_pending_retry_win",
		_make_provider(&"state", 1),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var _advanced_timeout: bool = _clock.advance_msec(10)
	_utility.tick(0.0)

	_storage.complete_save(OK)

	assert_true(operation.is_completed(), "原写入在等待重试时晚到成功，应立即完成逻辑保存。")
	if not operation.is_completed():
		return
	assert_true(operation.get_result().is_successful())
	var _advanced_retry: bool = _clock.advance_msec(5)
	_utility.tick(0.0)
	assert_eq(_storage.save_calls.size(), 1, "已确认成功后不得再启动计划中的重试。")


func test_detached_write_success_wins_over_active_retry_failure() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	policy.retry_delays_msec = PackedInt32Array([5])
	var profile: GFSaveProfile = _make_profile(
		&"test.detached_retry_win",
		_make_provider(&"state", 1),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var _advanced_timeout: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	var _advanced_retry: bool = _clock.advance_msec(5)
	_utility.tick(0.0)
	assert_eq(_storage.save_calls.size(), 2, "超时后应按策略启动一次重试。")

	_storage.complete_save(OK)

	assert_true(operation.is_completed(), "原写入晚到成功后，受覆盖的逻辑保存应立即完成。")
	if not operation.is_completed():
		return
	assert_true(operation.get_result().is_successful())
	assert_eq(_utility.get_persisted_generation(profile.profile_id), 1)
	assert_eq(
		GFVariantData.get_option_int(
			_utility.get_profile_state_snapshot(profile.profile_id),
			"detached_write_count",
			-1
		),
		1,
		"已启动的重试仍应保持路径所有权，直到物理写入结束。"
	)
	_storage.complete_save(ERR_BUSY)
	assert_true(operation.get_result().is_successful(), "后续重试失败不得翻转已确认的保存成功。")
	assert_eq(
		GFVariantData.get_option_int(
			_utility.get_profile_state_snapshot(profile.profile_id),
			"detached_write_count",
			-1
		),
		0
	)


func test_generation_scoped_unknown_evidence_survives_a_later_preparation_failure() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.generation_evidence", provider, policy)
	assert_true(_register(profile))
	var first: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var first_flush: GFSaveProfileOperation = _utility.flush_profile(profile.profile_id)
	provider.fail_preparation = true
	var second: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var _advanced: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	assert_eq(first.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(
		second.get_result().get_status(),
		GFSaveProfileResult.STATUS_PREPARATION_FAILED
	)
	assert_eq(first_flush.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(first_flush.get_result().get_storage_request_ids().size(), 1)


func test_timed_out_write_retains_path_ownership_until_late_terminal() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.io_timeout_msec = 10
	var profile: GFSaveProfile = _make_profile(
		&"test.detached_ownership",
		_make_provider(&"state", 1),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	var _advanced: bool = _clock.advance_msec(10)
	_utility.tick(0.0)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_false(_utility.unregister_profile(profile.profile_id))
	assert_eq(GFVariantData.get_option_int(
		_utility.get_profile_state_snapshot(profile.profile_id),
		"detached_write_count",
		-1
	), 1)
	_storage.complete_save(OK)
	assert_eq(_utility.get_persisted_generation(profile.profile_id), 1)
	assert_true(_utility.unregister_profile(profile.profile_id))


func test_future_storage_failure_takes_priority_over_invalid_integrity() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.corrupt_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	var profile: GFSaveProfile = _make_profile(
		&"test.future_integrity_priority",
		_make_provider(&"state", 1),
		policy
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	var read_result: GFStorageReadResult = _read_failure(
		ERR_INVALID_DATA,
		"Unsupported future storage version.",
		GFStorageReadResult.FailureKind.FUTURE_VERSION
	)
	read_result.integrity_status = GFStorageReadResult.IntegrityStatus.INVALID
	_storage.complete_load(read_result)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_FUTURE_SCHEMA)
	assert_false(operation.get_result().was_recovered())


func test_dispose_requested_from_preparation_callback_prevents_storage_start() -> void:
	var profile: GFSaveProfile = _make_profile(
		&"test.dispose_admission_barrier",
		_make_provider(&"state", 1)
	)
	assert_true(_register(profile))
	var _connected: Error = _utility.profile_state_changed.connect(
		func(_profile_id: StringName, _previous: StringName, current: StringName) -> void:
			if current == GFSaveProfileUtility.STATE_PREPARING:
				_utility.dispose()
	) as Error
	var operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	_utility.tick(0.0)
	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_DISPOSED)
	assert_eq(_storage.save_calls.size(), 0)
	assert_eq(_storage.get_pending_save_count(), 0)


func test_completion_callback_can_start_a_new_non_recursive_save() -> void:
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.completion_reschedule", provider)
	assert_true(_register(profile))
	var second_operations: Array[GFSaveProfileOperation] = []
	var first: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var _connected: Error = first.completed.connect(
		func(_result: GFSaveProfileResult) -> void:
			provider.value = 2
			second_operations.append(_utility.save_profile(profile.profile_id))
	) as Error
	_storage.complete_save(OK)
	_utility.tick(0.0)
	assert_eq(second_operations.size(), 1)
	assert_eq(_storage.save_calls.size(), 2)
	assert_false(second_operations[0].is_completed())
	_storage.complete_save(OK)
	assert_true(second_operations[0].get_result().is_successful())


func test_large_failed_barrier_queue_is_drained_iteratively_without_read_io() -> void:
	var profile: GFSaveProfile = _make_profile(
		&"test.iterative_barrier",
		_make_provider(&"state", 1)
	)
	assert_true(_register(profile))
	var save_operation: GFSaveProfileOperation = _utility.save_profile(profile.profile_id)
	var load_operations: Array[GFSaveProfileOperation] = []
	for _index: int in range(2_000):
		load_operations.append(_utility.load_profile(profile.profile_id))
	_storage.complete_save(ERR_CANT_CREATE)
	assert_eq(save_operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)
	assert_eq(_storage.load_calls.size(), 0)
	for operation: GFSaveProfileOperation in load_operations:
		assert_true(operation.is_completed())
		assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)


func test_disabled_profile_rejects_load_and_flush_without_io() -> void:
	var load_disabled_profile: GFSaveProfile = _make_profile(
		&"test.disabled_load",
		_make_provider(&"state", 1)
	)
	load_disabled_profile.load_enabled = false
	assert_true(_register(load_disabled_profile))
	var load_operation: GFSaveProfileOperation = _utility.load_profile(
		load_disabled_profile.profile_id
	)
	var load_only_provider: MemorySectionProvider = _make_provider(&"state", 1)
	load_only_provider.save_enabled = false
	var save_disabled_profile: GFSaveProfile = _make_profile(
		&"test.disabled_flush",
		load_only_provider
	)
	save_disabled_profile.save_enabled = false
	assert_true(_register(save_disabled_profile))
	var flush_operation: GFSaveProfileOperation = _utility.flush_profile(
		save_disabled_profile.profile_id
	)
	assert_eq(load_operation.get_result().get_status(), GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION)
	assert_eq(flush_operation.get_result().get_status(), GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION)
	assert_eq(_storage.load_calls.size(), 0)
	assert_eq(_storage.save_calls.size(), 0)


func test_preparation_and_rollback_snapshot_failures_keep_distinct_statuses() -> void:
	var preparation_provider: MemorySectionProvider = _make_provider(&"state", 1)
	preparation_provider.fail_preparation = true
	var preparation_profile: GFSaveProfile = _make_profile(
		&"test.preparation_failure",
		preparation_provider
	)
	assert_true(_register(preparation_profile))
	var preparation_operation: GFSaveProfileOperation = _utility.save_profile(
		preparation_profile.profile_id
	)
	_utility.tick(0.0)
	assert_eq(
		preparation_operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_PREPARATION_FAILED
	)
	assert_eq(preparation_operation.get_result().get_attempt_count(), 0)

	var snapshot_provider: MemorySectionProvider = _make_provider(&"state", 2)
	snapshot_provider.fail_capture = true
	var snapshot_profile: GFSaveProfile = _make_profile(&"test.snapshot_failure", snapshot_provider)
	assert_true(_register(snapshot_profile))
	var snapshot_operation: GFSaveProfileOperation = _utility.load_profile(snapshot_profile.profile_id)
	_storage.complete_load(_read_success(
		_make_document(snapshot_profile, {&"state": {"value": 3}})
	))
	assert_eq(
		snapshot_operation.get_result().get_status(),
		GFSaveProfileResult.STATUS_SNAPSHOT_FAILED
	)


func test_load_retry_uses_bounded_schedule_and_timeout_is_terminal() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.retry_delays_msec = PackedInt32Array([5])
	policy.io_timeout_msec = 20
	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.load_retry", provider, policy)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_storage.complete_load(_read_failure(
		ERR_BUSY,
		"Injected transient read failure.",
		GFStorageReadResult.FailureKind.IO_FAILED
	))
	assert_false(operation.is_completed())
	var _advanced_retry: bool = _clock.advance_msec(5)
	_utility.tick(0.0)
	assert_eq(_storage.load_calls.size(), 2)
	var _advanced_timeout: bool = _clock.advance_msec(20)
	_utility.tick(0.0)
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_STORAGE_FAILED)
	assert_eq(operation.get_result().get_error_code(), ERR_TIMEOUT)
	assert_eq(operation.get_result().get_attempt_count(), 2)


func test_corrupt_recovery_is_explicit_and_does_not_write() -> void:
	var policy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	policy.corrupt_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	var provider: MemorySectionProvider = _make_provider(&"state", 8)
	var profile: GFSaveProfile = _make_profile(&"test.corrupt_recovery", provider, policy)
	assert_true(_register(profile))
	var operation: GFSaveProfileOperation = _utility.load_profile(profile.profile_id)
	_storage.complete_load(_read_failure(
		ERR_FILE_CORRUPT,
		"Corrupt payload.",
		GFStorageReadResult.FailureKind.CORRUPT
	))
	assert_true(operation.get_result().is_successful())
	assert_true(operation.get_result().was_recovered())
	assert_eq(provider.value, 8)
	assert_eq(_storage.save_calls.size(), 0)


func test_schema_mismatch_missing_migration_and_validation_are_distinct() -> void:
	var mismatch_provider: MemorySectionProvider = _make_provider(&"state", 1)
	var mismatch_profile: GFSaveProfile = _make_profile(&"test.schema_mismatch", mismatch_provider)
	assert_true(_register(mismatch_profile))
	var mismatch_document: GFSaveDocument = _make_document(
		mismatch_profile,
		{&"state": {"value": 2}}
	)
	var _mismatch_configured: GFSaveDocument = mismatch_document.configure(
		&"other.schema",
		1,
		mismatch_document.get_sections()
	)
	var mismatch: GFSaveProfileOperation = _utility.load_profile(mismatch_profile.profile_id)
	_storage.complete_load(_read_success(mismatch_document))
	assert_eq(mismatch.get_result().get_status(), GFSaveProfileResult.STATUS_SCHEMA_MISMATCH)

	var migration_provider: MemorySectionProvider = _make_provider(&"state", 3)
	var migration_profile: GFSaveProfile = _make_profile(&"test.migration_missing", migration_provider)
	migration_profile.schema_version = 2
	assert_true(_register(migration_profile))
	var old_document: GFSaveDocument = _make_document(
		migration_profile,
		{&"state": {"value": 4}}
	)
	var _old_configured: GFSaveDocument = old_document.configure(
		migration_profile.get_effective_schema_id(),
		1,
		old_document.get_sections()
	)
	var missing_migration: GFSaveProfileOperation = _utility.load_profile(
		migration_profile.profile_id
	)
	_storage.complete_load(_read_success(old_document))
	assert_eq(
		missing_migration.get_result().get_status(),
		GFSaveProfileResult.STATUS_MIGRATION_FAILED
	)

	var validation_provider: MemorySectionProvider = _make_provider(&"state", 5)
	var validation_profile: GFSaveProfile = _make_profile(&"test.validation", validation_provider)
	assert_true(_register(validation_profile))
	var invalid_document: GFSaveDocument = GFSaveDocument.new().configure(
		validation_profile.get_effective_schema_id(),
		validation_profile.schema_version
	)
	var validation: GFSaveProfileOperation = _utility.load_profile(validation_profile.profile_id)
	_storage.complete_load(_read_success(invalid_document))
	assert_eq(validation.get_result().get_status(), GFSaveProfileResult.STATUS_VALIDATION_FAILED)


func test_migration_step_failure_and_future_section_are_rejected() -> void:
	var migration_provider: MemorySectionProvider = _make_provider(&"state", 1)
	var migration_profile: GFSaveProfile = _make_profile(&"test.migration_step", migration_provider)
	migration_profile.schema_version = 2
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	var step: FailingMigrationStep = FailingMigrationStep.new()
	step.step_id = &"fail.document.1.2"
	step.schema_id = migration_profile.get_effective_schema_id()
	step.from_version = 1
	step.to_version = 2
	assert_true(registry.register_step(step))
	assert_true(GFVariantData.get_option_bool(
		_utility.register_profile(migration_profile, registry),
		"registered"
	))
	var old_document: GFSaveDocument = _make_document(
		migration_profile,
		{&"state": {"value": 2}}
	)
	var _old_configured: GFSaveDocument = old_document.configure(
		migration_profile.get_effective_schema_id(),
		1,
		old_document.get_sections()
	)
	var failed_migration: GFSaveProfileOperation = _utility.load_profile(
		migration_profile.profile_id
	)
	_storage.complete_load(_read_success(old_document))
	assert_eq(
		failed_migration.get_result().get_status(),
		GFSaveProfileResult.STATUS_MIGRATION_FAILED
	)

	var future_provider: MemorySectionProvider = _make_provider(&"state", 7)
	var future_profile: GFSaveProfile = _make_profile(&"test.future_section", future_provider)
	assert_true(_register(future_profile))
	var future_document: GFSaveDocument = GFSaveDocument.new().configure(
		future_profile.get_effective_schema_id(),
		future_profile.schema_version,
		[GFSaveSection.new().configure(&"state", 2, {"value": 9})]
	)
	var future: GFSaveProfileOperation = _utility.load_profile(future_profile.profile_id)
	_storage.complete_load(_read_success(future_document))
	assert_eq(future.get_result().get_status(), GFSaveProfileResult.STATUS_FUTURE_SCHEMA)


func test_registration_report_preserves_validation_evidence_and_provider_lock() -> void:
	var invalid: GFSaveProfile = GFSaveProfile.new()
	var report: Dictionary = _utility.register_profile(invalid)
	assert_false(GFVariantData.get_option_bool(report, "registered"))
	assert_true(GFVariantData.get_option_int(report, "error_count") > 0)
	assert_true(_report_contains_issue(report, &"invalid_profile_id"))

	var provider: MemorySectionProvider = _make_provider(&"state", 1)
	var profile: GFSaveProfile = _make_profile(&"test.provider_lock", provider)
	assert_true(_register(profile))
	provider.section_id = &"mutated"
	assert_push_error("[GFSaveSectionProvider] 已注册的 section_id 不可修改。")
	assert_eq(provider.section_id, &"state")


func test_real_storage_round_trip_completes_through_async_signals() -> void:
	var real_storage: GFStorageUtility = GFStorageUtility.new()
	real_storage.save_dir_name = "test_save_profile_runtime"
	real_storage.init()
	var real_utility: GFSaveProfileUtility = GFSaveProfileUtility.new().setup(real_storage, _clock)
	var provider: MemorySectionProvider = _make_provider(&"state", 42)
	var profile: GFSaveProfile = _make_profile(&"test.real_round_trip", provider)
	assert_true(GFVariantData.get_option_bool(real_utility.register_profile(profile), "registered"))

	var save_operation: GFSaveProfileOperation = real_utility.save_profile(profile.profile_id)
	await _pump_real_storage(real_utility, real_storage, save_operation)
	provider.value = 0
	var load_operation: GFSaveProfileOperation = real_utility.load_profile(profile.profile_id)
	await _pump_real_storage(real_utility, real_storage, load_operation)

	assert_true(save_operation.get_result().is_successful())
	assert_true(load_operation.get_result().is_successful())
	assert_eq(provider.value, 42)
	real_storage.wait_for_async_tasks()
	var _delete_error: Error = real_storage.delete_file(profile.file_name)
	real_utility.dispose()
	real_storage.dispose()


func test_extension_installer_ready_injects_storage_for_real_round_trip() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var real_storage: GFStorageUtility = GFStorageUtility.new()
	real_storage.save_dir_name = "test_save_profile_installer"
	real_storage.init()
	assert_true(await architecture.register_utility_instance(real_storage))
	var installer: GFInstaller = GF_SAVE_EXTENSION.new()
	installer.install(architecture, GFAsyncScope.new())
	assert_true(await architecture.init())
	var installed_utility: GFSaveProfileUtility = architecture.get_local_utility(
		GFSaveProfileUtility
	)
	assert_not_null(installed_utility)
	var provider: MemorySectionProvider = _make_provider(&"state", 73)
	var profile: GFSaveProfile = _make_profile(&"test.installer_round_trip", provider)
	assert_true(GFVariantData.get_option_bool(
		installed_utility.register_profile(profile),
		"registered"
	))
	var save_operation: GFSaveProfileOperation = installed_utility.save_profile(profile.profile_id)
	await _pump_real_storage(installed_utility, real_storage, save_operation)
	provider.value = 0
	var load_operation: GFSaveProfileOperation = installed_utility.load_profile(profile.profile_id)
	await _pump_real_storage(installed_utility, real_storage, load_operation)
	assert_true(save_operation.get_result().is_successful())
	assert_true(load_operation.get_result().is_successful())
	assert_eq(provider.value, 73)
	real_storage.wait_for_async_tasks()
	var _delete_error: Error = real_storage.delete_file(profile.file_name)
	architecture.dispose()


func test_extension_activation_round_trips_with_automatic_cooperative_storage() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var real_storage: AutomaticCooperativeRealStorage = AutomaticCooperativeRealStorage.new()
	real_storage.save_dir_name = "tspc-" + GFUuid.generate_v4()
	real_storage.encrypt_key = 0
	real_storage.init()
	assert_true(await architecture.register_utility_instance(real_storage))
	var installer: GFInstaller = GF_SAVE_EXTENSION.new()
	installer.install(architecture, GFAsyncScope.new())
	assert_true(await architecture.init(), "AUTOMATIC + 无线程能力不得阻断 Save extension activation。")
	var installed_utility: GFSaveProfileUtility = architecture.get_local_utility(
		GFSaveProfileUtility
	)
	assert_not_null(installed_utility)
	if installed_utility == null:
		architecture.dispose()
		return

	var provider: MemorySectionProvider = _make_provider(&"state", 91)
	var profile: GFSaveProfile = _make_profile(&"test.cooperative_activation", provider)
	assert_true(GFVariantData.get_option_bool(
		installed_utility.register_profile(profile),
		"registered"
	))
	var save_operation: GFSaveProfileOperation = installed_utility.save_profile(profile.profile_id)
	assert_true(
		_pump_cooperative_profile_storage(architecture, save_operation),
		"显式 lifecycle ticks 必须完成真实 cooperative save。"
	)
	provider.value = 0
	var load_operation: GFSaveProfileOperation = installed_utility.load_profile(profile.profile_id)
	assert_true(
		_pump_cooperative_profile_storage(architecture, load_operation),
		"显式 lifecycle ticks 必须完成真实 cooperative load。"
	)

	assert_true(save_operation.get_result().is_successful())
	assert_true(load_operation.get_result().is_successful())
	assert_eq(provider.value, 91)
	assert_eq(real_storage.thread_start_call_count, 0)
	real_storage.wait_for_async_tasks()
	var _delete_error: Error = real_storage.delete_file(profile.file_name)
	architecture.dispose()


func _make_provider(section_id: StringName, value: int) -> MemorySectionProvider:
	var provider: MemorySectionProvider = MemorySectionProvider.new()
	provider.section_id = section_id
	provider.schema_version = 1
	provider.required_on_load = true
	provider.value = value
	return provider


func _make_profile(
	profile_id: StringName,
	provider: GFSaveSectionProvider,
	recovery_policy: GFSaveRecoveryPolicy = null
) -> GFSaveProfile:
	return _make_profile_with_providers(profile_id, [provider], recovery_policy)


func _make_profile_with_providers(
	profile_id: StringName,
	providers: Array[GFSaveSectionProvider],
	recovery_policy: GFSaveRecoveryPolicy = null
) -> GFSaveProfile:
	var profile: GFSaveProfile = GFSaveProfile.new()
	profile.profile_id = profile_id
	profile.file_name = "%s.sav" % String(profile_id)
	profile.schema_version = 1
	profile.providers = providers
	if recovery_policy != null:
		profile.recovery_policy = recovery_policy
	return profile


func _make_document(profile: GFSaveProfile, payloads: Dictionary) -> GFSaveDocument:
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		profile.get_effective_schema_id(),
		profile.schema_version
	)
	for provider: GFSaveSectionProvider in profile.providers:
		var payload: Variant = GFVariantData.get_option_value(payloads, provider.section_id)
		var _section_set: bool = document.set_section(GFSaveSection.new().configure(
			provider.section_id,
			provider.schema_version,
			payload
		))
	return document


func _read_success(document: GFSaveDocument) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_success(document.to_dict())


func _read_failure(
	error_code: Error,
	error: String,
	failure_kind: GFStorageReadResult.FailureKind = GFStorageReadResult.FailureKind.IO_FAILED
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _register(profile: GFSaveProfile) -> bool:
	return GFVariantData.get_option_bool(_utility.register_profile(profile), "registered")


func _report_contains_issue(report: Dictionary, kind: StringName) -> bool:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == kind:
			return true
	return false


func _get_saved_value(save_call: Dictionary) -> int:
	var data: Dictionary = GFVariantData.get_option_dictionary(save_call, "data")
	var document: GFSaveDocument = GFSaveDocument.from_dict(data)
	if document == null:
		return -1
	var section: GFSaveSection = document.get_section(&"state")
	if section == null:
		return -1
	return GFVariantData.get_option_int(GFVariantData.as_dictionary(section.get_payload()), "value")


func _pump_cooperative_profile_storage(
	architecture: GFArchitecture,
	operation: GFSaveProfileOperation
) -> bool:
	for _tick_index: int in range(12):
		architecture.tick(0.0)
		if operation.is_completed():
			return true
	return operation.is_completed()


func _pump_real_storage(
	utility: GFSaveProfileUtility,
	storage: GFStorageUtility,
	operation: GFSaveProfileOperation
) -> void:
	for _index: int in range(120):
		utility.tick(0.0)
		storage.tick(0.0)
		if operation.is_completed():
			return
		await get_tree().process_frame
