## 测试 Storage payload transfer 的单所有者、attempt lease 与失败归还语义。
extends GutTest


const _FILES: Array[String] = [
	"test_transfer_success.json",
	"test_transfer_invalid_payload.json",
	"test_transfer_non_finite.json",
	"test_transfer_frozen_binding.json",
	"test_transfer_dispose.json",
	"test_transfer_snapshot.json",
	"test_transfer_retry.json",
	"test_transfer_reentrant.json",
	"test_transfer_committed_recovery.json",
	"test_transfer_uncommitted_recovery.json",
	"test_transfer_path_freeze.json",
	"test_transfer_path_blocker.json",
]


class MalformedPayloadTransfer extends GFStoragePayloadTransfer:
	func begin_attempt_for_framework(
		_storage_id: int,
		_file_name: String,
		_target_file_key: String,
		_codec_options: Dictionary
	) -> Dictionary:
		return {
			"ok": true,
			"attempt_id": 1,
			"payload": "not-a-dictionary",
		}


class CleanupPreservingStorage extends GFStorageUtility:
	var preserve_committed_artifacts: bool = false

	func _remove_absolute_file_if_exists(path: String) -> void:
		if (
			preserve_committed_artifacts
			and (path.ends_with(".bak") or path.ends_with(".txn"))
		):
			return
		super._remove_absolute_file_if_exists(path)


var _storage: GFStorageUtility


func before_each() -> void:
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = "test_saves"
	_storage.encrypt_key = 0
	_storage.init()


func after_each() -> void:
	if _storage == null:
		return
	var original_save_dir_name: String = _storage.save_dir_name
	for save_dir_name: String in [
		"test_saves",
		"test_saves_frozen_a",
		"test_saves_frozen_b",
	]:
		_storage.save_dir_name = save_dir_name
		for file_name: String in _FILES:
			for suffix: String in ["", ".tmp", ".bak", ".txn"]:
				var path: String = _storage._get_full_path(file_name + suffix)
				if FileAccess.file_exists(path):
					var _removed: Error = DirAccess.remove_absolute(path)
	_storage.save_dir_name = original_save_dir_name
	_storage.dispose()
	_storage = null


func test_transfer_takes_and_releases_ownership_once_without_public_payload_getter() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})

	assert_not_null(transfer)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.READY)
	assert_false(transfer.has_method("get_payload"), "opaque transfer 不得公开 payload getter。")
	assert_false(transfer.has_method("peek_payload"), "opaque transfer 不得公开 payload peek。")
	assert_true(transfer.release())
	assert_true(transfer.is_released())
	assert_false(transfer.release(), "release 只能接受一次。")


func test_invalid_path_does_not_claim_transfer() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})

	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async("", transfer)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(
		operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
	)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.READY)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_null(operation.get_payload_transfer())
	assert_null(operation.reclaim_failed_payload())
	assert_push_error("[GFStorageUtility] save_payload_request_async 失败：file_name 为空。")


func test_malformed_transfer_payload_fails_closed_before_queueing() -> void:
	var transfer: GFStoragePayloadTransfer = MalformedPayloadTransfer.new()

	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_invalid_payload.json",
		transfer
	)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(
		operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
	)
	assert_true(_storage._async_queue.is_empty())
	assert_true(_storage._async_tasks.is_empty())
	assert_null(operation.get_payload_transfer())
	assert_null(operation.reclaim_failed_payload())


func test_successful_attempt_cannot_be_reclaimed_and_release_clears_payload() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"coins": 42})

	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_success.json",
		transfer
	)
	assert_same(operation.get_payload_transfer(), transfer)
	await _pump_storage_async_tasks()

	var result: GFStorageAsyncResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_write_failure_kind(), GFStorageAsyncResult.WriteFailureKind.NONE)
	assert_true(GFVariantData.get_option_bool(result.get_write_validation_report(), "ok"))
	assert_null(
		operation.get_payload_transfer(),
		"终态 operation 不得绕过失败归还协议继续暴露 transfer。"
	)
	assert_null(operation.reclaim_failed_payload(), "成功 attempt 不得走失败归还通道。")
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_true(transfer.is_claimed(), "完成单个 attempt 不等于结束整个 retry generation。")
	assert_true(transfer.release())
	assert_true(transfer.is_released())

	var loaded: GFStorageReadResult = _storage.load_data("test_transfer_success.json")
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "coins"), 42)


func test_invalid_payload_reports_stable_failure_and_reclaims_same_transfer_once() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"unsafe": Resource.new(),
	})

	var first_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_invalid_payload.json",
		transfer
	)
	await _pump_storage_async_tasks()

	var first_result: GFStorageAsyncResult = first_operation.get_result()
	var validation_report: Dictionary = first_result.get_write_validation_report()
	assert_false(first_result.is_successful())
	assert_eq(first_result.get_error_code(), ERR_INVALID_DATA)
	assert_eq(
		first_result.get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.PAYLOAD_INVALID
	)
	assert_eq(
		GFVariantData.get_option_string(validation_report, "failure_kind"),
		"unsupported_variant_type"
	)
	assert_eq(
		GFVariantData.as_array(validation_report.get("path_segments")).size(),
		1,
		"预检报告应提供不含 payload 值的结构化路径。"
	)
	assert_false(
		JSON.stringify(validation_report).contains("unsafe"),
		"validation report 不得输出命中的 Dictionary key 或 payload 值。"
	)
	assert_false(
		JSON.stringify(validation_report).contains("key_token"),
		"validation report 不得保留可离线关联 Dictionary key 的 digest。"
	)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_null(first_operation.get_payload_transfer())
	assert_same(first_operation.reclaim_failed_payload(), transfer)
	assert_null(first_operation.reclaim_failed_payload(), "失败 transfer 只归还一次。")

	var retry_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_invalid_payload.json",
		transfer
	)
	assert_same(retry_operation.get_payload_transfer(), transfer, "重试必须复用同一 opaque snapshot。")
	await _pump_storage_async_tasks()
	assert_false(retry_operation.get_result().is_successful())
	assert_same(retry_operation.reclaim_failed_payload(), transfer)
	assert_true(transfer.release())


func test_non_finite_nested_value_is_rejected_without_logging_payload_value() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"records": [
			{
				"position": Vector2(INF, 1.0),
			},
		],
	})
	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_non_finite.json",
		transfer
	)
	await _pump_storage_async_tasks()

	var result: GFStorageAsyncResult = operation.get_result()
	var report: Dictionary = result.get_write_validation_report()
	var path_segments: Array = GFVariantData.as_array(report.get("path_segments"))
	assert_false(result.is_successful())
	assert_eq(
		result.get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.PAYLOAD_INVALID
	)
	assert_eq(
		GFVariantData.get_option_string(report, "failure_kind"),
		"non_finite_number"
	)
	assert_eq(path_segments.size(), 3)
	assert_false(JSON.stringify(report).to_lower().contains("inf"))
	assert_same(operation.reclaim_failed_payload(), transfer)
	assert_true(transfer.release())


func test_preflight_rejects_non_finite_compound_and_packed_variants() -> void:
	var invalid_values: Array[Variant] = [
		NAN,
		Rect2(Vector2.ZERO, Vector2(INF, 1.0)),
		Transform2D(0.0, Vector2(1.0, INF)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, NAN, 0.0)),
		Color(1.0, INF, 1.0, 1.0),
		PackedFloat64Array([1.0, NAN]),
		PackedVector3Array([Vector3(0.0, INF, 0.0)]),
		PackedColorArray([Color(1.0, 1.0, NAN, 1.0)]),
		PackedVector4Array([Vector4(0.0, 0.0, 0.0, INF)]),
	]

	for value: Variant in invalid_values:
		var report: Dictionary = _storage._validate_thread_payload({"value": value})
		assert_false(GFVariantData.get_option_bool(report, "ok"))
		assert_eq(
			GFVariantData.get_option_string(report, "failure_kind"),
			"non_finite_number",
			"所有可持久化复合数值类型都必须 fail closed。"
		)


func test_preflight_charges_packed_array_elements_against_value_budget() -> void:
	var oversized: PackedByteArray = PackedByteArray()
	var _resize_error: int = oversized.resize(1_000_001)

	var report: Dictionary = _storage._validate_thread_payload({
		"value": oversized,
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(report, "failure_kind"),
		"value_budget_exceeded"
	)
	assert_true(
		GFVariantData.get_option_int(report, "visited_values") > 1_000_000
	)


func test_preflight_stops_dictionary_iteration_at_value_budget_without_key_snapshot() -> void:
	var oversized_dictionary: Dictionary = {}
	for index: int in range(64):
		oversized_dictionary["entry_%d" % index] = index

	var report: Dictionary = _storage._validate_thread_payload(
		oversized_dictionary,
		8,
		1024,
		16
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(report, "failure_kind"),
		"value_budget_exceeded"
	)
	assert_eq(GFVariantData.get_option_int(report, "visited_values"), 9)


func test_preflight_enforces_byte_budget_without_exposing_key_value_or_digest() -> void:
	var report: Dictionary = _storage._validate_thread_payload(
		{"private_key": "do-not-expose-this-payload-value"},
		100,
		16,
		16
	)
	var serialized_report: String = JSON.stringify(report)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(report, "failure_kind"),
		"byte_budget_exceeded"
	)
	assert_true(GFVariantData.get_option_int(report, "visited_bytes") > 16)
	assert_false(serialized_report.contains("private_key"))
	assert_false(serialized_report.contains("do-not-expose"))
	assert_false(serialized_report.contains("key_token"))


func test_preflight_rejects_typed_object_container_metadata_without_elements() -> void:
	var unsafe_values: Array[Resource] = []
	var array_report: Dictionary = _storage._validate_thread_payload({
		"values": unsafe_values,
	})

	assert_false(GFVariantData.get_option_bool(array_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(array_report, "failure_kind"),
		"unsupported_typed_container"
	)
	assert_eq(
		GFVariantData.get_option_string(array_report, "variant_type_name"),
		"Array"
	)

	var unsafe_entries: Dictionary[String, Resource] = {}
	var dictionary_report: Dictionary = _storage._validate_thread_payload({
		"entries": unsafe_entries,
	})
	assert_false(GFVariantData.get_option_bool(dictionary_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(dictionary_report, "failure_kind"),
		"unsupported_typed_container"
	)
	assert_eq(
		GFVariantData.get_option_string(dictionary_report, "variant_type_name"),
		"Dictionary"
	)

	var safe_values: Array[int] = [1, 2, 3]
	var safe_entries: Dictionary[String, int] = {"value": 1}
	var safe_report: Dictionary = _storage._validate_thread_payload({
		"values": safe_values,
		"entries": safe_entries,
	})
	assert_true(GFVariantData.get_option_bool(safe_report, "ok"))


func test_same_binding_can_lease_pending_snapshot_and_dispose_reclaims_queued_attempt() -> void:
	_storage.max_async_thread_count = 1
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"values": PackedInt32Array(range(4096)),
	})

	var first_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_dispose.json",
		transfer
	)
	var queued_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_dispose.json",
		first_operation.get_payload_transfer()
	)

	assert_same(queued_operation.get_payload_transfer(), transfer)
	assert_eq(transfer.get_active_attempt_count(), 2)
	assert_eq(_storage._async_queue.size(), 1, "同文件 retry 应保留独立 lease 并等待当前原子写。")
	_storage.dispose()

	assert_true(first_operation.is_completed())
	assert_true(first_operation.get_result().is_successful())
	assert_true(queued_operation.is_completed())
	assert_false(queued_operation.get_result().is_successful())
	assert_eq(
		queued_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
	)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_same(queued_operation.reclaim_failed_payload(), transfer)
	assert_null(queued_operation.reclaim_failed_payload())
	assert_true(transfer.release())
	assert_true(transfer.is_released())


func test_claim_freezes_storage_file_and_codec_binding() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})
	var first_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_frozen_binding.json",
		transfer
	)
	_storage.encrypt_key = 7

	var rejected_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_frozen_binding.json",
		transfer
	)

	assert_true(rejected_operation.is_completed())
	assert_false(rejected_operation.get_result().is_successful())
	assert_eq(
		rejected_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
	)
	assert_null(rejected_operation.get_payload_transfer())
	assert_eq(transfer.get_active_attempt_count(), 1)
	await _pump_storage_async_tasks()
	assert_true(first_operation.get_result().is_successful())
	assert_true(transfer.release())


func test_claim_freezes_target_family_while_queued_task_keeps_original_path() -> void:
	_storage.max_async_thread_count = 1
	_storage.save_dir_name = "test_saves_frozen_a"
	var blocker_transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 1,
	})
	var blocker_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_path_blocker.json",
		blocker_transfer
	)
	var target_transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 2,
	})
	var target_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_path_freeze.json",
		target_transfer
	)
	assert_eq(_storage._async_queue.size(), 1)

	_storage.save_dir_name = "test_saves_frozen_b"
	var rejected_retry: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_path_freeze.json",
		target_transfer
	)

	assert_true(rejected_retry.is_completed())
	assert_eq(
		rejected_retry.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
	)
	assert_eq(target_transfer.get_active_attempt_count(), 1)
	await _pump_storage_async_tasks()
	assert_true(blocker_operation.get_result().is_successful())
	assert_true(target_operation.get_result().is_successful())

	_storage.save_dir_name = "test_saves_frozen_a"
	var loaded: GFStorageReadResult = _storage.load_data("test_transfer_path_freeze.json")
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "value"), 2)
	_storage.save_dir_name = "test_saves_frozen_b"
	assert_false(
		FileAccess.file_exists(_storage._get_full_path("test_transfer_path_freeze.json")),
		"Utility 配置变化不得让已 claim 的 queued task 漂移到新目录。"
	)
	assert_true(blocker_transfer.release())
	assert_true(target_transfer.release())


func test_old_attempt_and_retry_publish_independent_terminals_then_release_once() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"generation": 7,
	})
	var first_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_retry.json",
		transfer
	)
	var retry_transfer: GFStoragePayloadTransfer = first_operation.get_payload_transfer()
	var retry_operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_retry.json",
		retry_transfer
	)

	assert_same(retry_transfer, transfer)
	assert_same(retry_operation.get_payload_transfer(), transfer)
	assert_eq(transfer.get_active_attempt_count(), 2)
	await _pump_storage_async_tasks()

	assert_true(first_operation.is_completed())
	assert_true(first_operation.get_result().is_successful())
	assert_true(retry_operation.is_completed())
	assert_true(retry_operation.get_result().is_successful())
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_null(first_operation.reclaim_failed_payload())
	assert_null(retry_operation.reclaim_failed_payload())
	assert_true(transfer.release())
	assert_true(transfer.is_released())


func test_dispose_closes_async_admission_before_terminal_callbacks() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 1,
	})
	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_dispose.json",
		transfer
	)
	var reentrant_transfers: Array[GFStoragePayloadTransfer] = []
	var reentrant_operations: Array[GFStorageAsyncOperation] = []
	var connect_error: Error = operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			var admitted_transfer: GFStoragePayloadTransfer = (
				GFStoragePayloadTransfer.take_ownership({"value": 2})
			)
			reentrant_transfers.append(admitted_transfer)
			reentrant_operations.append(_storage.save_payload_request_async(
				"test_transfer_reentrant.json",
				admitted_transfer
			))
	) as Error
	assert_eq(connect_error, OK)

	_storage.dispose()

	assert_true(operation.is_completed())
	assert_eq(reentrant_transfers.size(), 1)
	assert_eq(reentrant_operations.size(), 1)
	var reentrant_operation: GFStorageAsyncOperation = reentrant_operations[0]
	var captured_transfer: GFStoragePayloadTransfer = reentrant_transfers[0]
	assert_true(reentrant_operation.is_completed())
	assert_eq(
		reentrant_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
	)
	assert_eq(captured_transfer.get_state(), GFStoragePayloadTransfer.State.READY)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_queue.is_empty())
	assert_true(captured_transfer.release())
	assert_true(transfer.release())


func test_worker_committed_marker_uses_shared_schema_and_recovery_keeps_new_file() -> void:
	var probe: CleanupPreservingStorage = CleanupPreservingStorage.new()
	probe.save_dir_name = "test_saves"
	probe.encrypt_key = 0
	probe.init()
	probe.preserve_committed_artifacts = true
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 9,
	})
	var operation: GFStorageAsyncOperation = probe.save_payload_request_async(
		"test_transfer_committed_recovery.json",
		transfer
	)
	await _pump_specific_storage(probe)

	assert_true(operation.get_result().is_successful())
	var marker: Dictionary = probe._read_transaction_marker(
		"test_transfer_committed_recovery.json"
	)
	assert_eq(GFVariantData.get_option_int(marker, "schema_version"), 1)
	assert_false(GFVariantData.get_option_string(marker, "transaction_id").is_empty())
	assert_eq(
		GFVariantData.get_option_string(marker, "file_key"),
		"test_transfer_committed_recovery.json"
	)
	assert_true(GFVariantData.get_option_bool(marker, "committed"))
	assert_false(GFVariantData.get_option_bool(marker, "had_final"))
	assert_true(transfer.release())
	probe.preserve_committed_artifacts = false
	probe.dispose()

	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		"test_transfer_committed_recovery.json"
	)
	await _pump_storage_async_tasks()
	var loaded: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "value"), 9)
	assert_false(
		FileAccess.file_exists(_storage._get_full_path(
			"test_transfer_committed_recovery.json.txn"
		))
	)


func test_frozen_async_recovery_rolls_back_valid_uncommitted_marker() -> void:
	var file_name: String = "test_transfer_uncommitted_recovery.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	assert_eq(_storage._write_transaction_markers([file_name], false), OK)
	assert_eq(
		DirAccess.rename_absolute(
			_storage._get_full_path(file_name),
			_storage._get_full_path(file_name + ".bak")
		),
		OK
	)
	assert_eq(_storage._write_json(file_name, {"value": 2}), OK)

	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	await _pump_storage_async_tasks()

	var result: GFStorageReadResult = operation.get_result().get_read_result()
	assert_true(result.ok)
	assert_eq(
		GFVariantData.get_option_int(result.payload, "value"),
		1,
		"valid uncommitted marker 必须恢复旧 final，而不是保留部分提交的新代次。"
	)
	assert_false(
		FileAccess.file_exists(_storage._get_full_path(file_name + ".txn"))
	)
	assert_false(
		FileAccess.file_exists(_storage._get_full_path(file_name + ".bak"))
	)


func test_release_waits_for_active_attempt_before_clearing_payload() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})
	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"test_transfer_success.json",
		transfer
	)

	assert_true(transfer.release())
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.RELEASE_PENDING)
	assert_false(transfer.is_released())
	await _pump_storage_async_tasks()

	assert_true(operation.get_result().is_successful())
	assert_true(transfer.is_released(), "最后一个 active attempt 完成后才应清空 payload。")


func test_operation_cannot_publish_terminal_result_before_attempt_lease_finishes() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})
	var attempt: Dictionary = transfer.begin_attempt_for_framework(
		_storage.get_instance_id(),
		"test_transfer_success.json",
		_storage._get_async_file_key("test_transfer_success.json"),
		_storage._get_codec_options()
	)
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(operation.configure_for_framework(
		999,
		GFStorageAsyncOperation.OPERATION_SAVE,
		"test_transfer_success.json"
	))
	assert_true(operation.configure_payload_attempt_for_framework(
		transfer,
		GFVariantData.get_option_int(attempt, "attempt_id")
	))
	var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(result.configure_for_framework(
		999,
		GFStorageAsyncOperation.OPERATION_SAVE,
		"test_transfer_success.json",
		true,
		OK
	))

	assert_false(
		operation.complete_for_framework(result),
		"attempt lease 结束前不得发布逻辑终态。"
	)
	assert_true(operation.finish_payload_attempt_for_framework())
	assert_true(operation.complete_for_framework(result))
	assert_null(operation.get_payload_transfer())
	assert_true(transfer.release())


func test_legacy_request_api_keeps_deep_snapshot_copy() -> void:
	var source: Dictionary = {
		"nested": {
			"value": 1,
		},
	}
	var operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		"test_transfer_snapshot.json",
		source
	)
	var nested: Dictionary = GFVariantData.as_dictionary(source["nested"])
	nested["value"] = 99
	await _pump_storage_async_tasks()

	assert_true(operation.get_result().is_successful())
	var loaded: GFStorageReadResult = _storage.load_data("test_transfer_snapshot.json")
	var loaded_nested: Dictionary = GFVariantData.get_option_dictionary(loaded.payload, "nested")
	assert_eq(GFVariantData.get_option_int(loaded_nested, "value"), 1)


func _pump_storage_async_tasks() -> void:
	await _pump_specific_storage(_storage)


func _pump_specific_storage(storage: GFStorageUtility) -> void:
	for _index: int in range(240):
		storage.tick(0.0)
		if storage._async_tasks.is_empty() and storage._async_queue.is_empty():
			return
		await get_tree().process_frame
