## 测试 Storage payload transfer 的单所有者、attempt lease 与失败归还语义。
extends GutTest


const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)

const _STORAGE_ROOTS: Array[String] = [
	"test_storage_payload_transfer",
	"test_storage_payload_transfer_frozen_a",
	"test_storage_payload_transfer_frozen_b",
]
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
	"test_transfer_legacy_visible.json",
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
	var preserved_paths: Dictionary = {}

	func _remove_absolute_file(path: String) -> Error:
		if preserve_committed_artifacts and preserved_paths.has(path):
			return OK
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		if not FileAccess.file_exists(path):
			return OK
		return DirAccess.remove_absolute(path)


var _storage: GFStorageUtility
var _additional_storages: Array[GFStorageUtility] = []


func _make_family_descriptor(save_dir_name: String, file_name: String) -> Dictionary:
	var storage_root_path: String = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		save_dir_name
	)
	return _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		storage_root_path,
		file_name
	)


func _cleanup_file_family(save_dir_name: String, file_name: String) -> void:
	var descriptor: Dictionary = _make_family_descriptor(save_dir_name, file_name)
	if descriptor.is_empty():
		return
	for path_key: String in [
		"payload_path",
		"candidate_path",
		"backup_path",
		"transaction_path",
		"transaction_pending_path",
		"transaction_commit_path",
		"transaction_commit_pending_path",
		"resource_stage_path",
		"owner_path",
	]:
		var path: String = GFVariantData.get_option_string(descriptor, path_key)
		if FileAccess.file_exists(path):
			var _remove_path_result: Error = DirAccess.remove_absolute(path)
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	for legacy_leaf: String in [
		"payload.json.tmp",
		"payload.json.bak",
		"payload.json.txn",
		"transaction.json",
	]:
		var legacy_path: String = family_path.path_join(legacy_leaf)
		if FileAccess.file_exists(legacy_path):
			var _remove_legacy_result: Error = DirAccess.remove_absolute(legacy_path)
	if DirAccess.dir_exists_absolute(family_path):
		var _remove_family_result: Error = DirAccess.remove_absolute(family_path)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	if FileAccess.file_exists(catalog_path):
		var _remove_catalog_result: Error = DirAccess.remove_absolute(catalog_path)


func _cleanup_legacy_visible_files(save_dir_name: String, file_name: String) -> void:
	var storage_root_path: String = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		save_dir_name
	)
	for suffix: String in ["", ".tmp", ".bak", ".txn"]:
		var visible_path: String = storage_root_path.path_join(file_name + suffix)
		if FileAccess.file_exists(visible_path):
			var _remove_visible_result: Error = DirAccess.remove_absolute(visible_path)


func _remove_owned_directory_tree(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_file_error != OK:
			return remove_file_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_directory_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_directory_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	directory = null
	return DirAccess.remove_absolute(path)


func _cleanup_owned_private_namespace(save_dir_name: String) -> Error:
	if not _STORAGE_ROOTS.has(save_dir_name):
		return ERR_UNAUTHORIZED
	var storage_root_path: String = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		save_dir_name
	).simplify_path()
	var private_root_name: String = ".gf-storage"
	var private_root_path: String = storage_root_path.path_join(private_root_name).simplify_path()
	if (
		storage_root_path.is_empty()
		or storage_root_path == "user://"
		or private_root_path.get_base_dir() != storage_root_path
		or private_root_path.get_file() != private_root_name
	):
		return ERR_UNAUTHORIZED
	return _remove_owned_directory_tree(private_root_path)


func _cleanup_known_test_artifacts() -> Error:
	for save_dir_name: String in _STORAGE_ROOTS:
		var private_cleanup_error: Error = _cleanup_owned_private_namespace(save_dir_name)
		if private_cleanup_error != OK:
			return private_cleanup_error
		for file_name: String in _FILES:
			_cleanup_file_family(save_dir_name, file_name)
			_cleanup_legacy_visible_files(save_dir_name, file_name)
	return OK


func _read_plain_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return GFVariantData.as_dictionary(parsed)


func _write_legacy_visible_data_file(file_name: String, data: Dictionary) -> String:
	var path: String = _storage._get_save_base_path().path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试夹具应能写入 legacy visible payload。")
	if file == null:
		return path
	var bytes: PackedByteArray = _storage._get_codec().encode(
		data,
		_storage._get_codec_options()
	)
	var _store_buffer_result: Variant = file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	assert_eq(write_error, OK, "测试夹具应完整写入 legacy visible payload。")
	return path


func _assert_transaction_records_absent(
	storage_utility: GFStorageUtility,
	file_name: String
) -> void:
	var descriptor: Dictionary = _make_family_descriptor(
		storage_utility.save_dir_name,
		file_name
	)
	for path_key: String in [
		"transaction_path",
		"transaction_pending_path",
		"transaction_commit_path",
		"transaction_commit_pending_path",
	]:
		assert_false(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)),
			"事务收敛后不应残留 %s。" % path_key
		)


func _assert_single_member_transaction_record(
	record: Dictionary,
	descriptor: Dictionary,
	committed: bool,
	had_final: bool
) -> void:
	var logical_path: String = GFVariantData.get_option_string(descriptor, "logical_path")
	var family_id: String = GFVariantData.get_option_string(descriptor, "family_id")
	assert_eq(record.size(), 6, "v2 transaction record 必须使用固定六字段 envelope。")
	assert_eq(
		GFVariantData.get_option_string(record, "schema"),
		"gf.storage.transaction-commit" if committed else "gf.storage.transaction-prepare"
	)
	assert_eq(GFVariantData.get_option_int(record, "schema_version"), 2)
	assert_false(GFVariantData.get_option_string(record, "transaction_id").is_empty())
	assert_true(record.get("committed") is bool)
	assert_eq(GFVariantData.get_option_bool(record, "committed"), committed)
	assert_eq(
		GFVariantData.get_option_dictionary(record, "owner"),
		{
			"logical_path": logical_path,
			"family_id": family_id,
		}
	)
	var members: Array = GFVariantData.get_option_array(record, "members")
	assert_eq(members.size(), 1)
	if members.size() != 1:
		return
	assert_eq(
		GFVariantData.as_dictionary(members[0]),
		{
			"logical_path": logical_path,
			"family_id": family_id,
			"had_final": had_final,
		}
	)


func before_each() -> void:
	assert_eq(
		_cleanup_known_test_artifacts(),
		OK,
		"setup 必须只清理本测试白名单内的 private namespace。"
	)
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = "test_storage_payload_transfer"
	_storage.encrypt_key = 0
	_storage.init()


func after_each() -> void:
	if _storage != null:
		_storage.dispose()
	for storage_utility: GFStorageUtility in _additional_storages:
		if storage_utility != null:
			storage_utility.dispose()
	assert_eq(
		_cleanup_known_test_artifacts(),
		OK,
		"teardown 必须完整清理本测试拥有的 private namespace。"
	)
	_storage = null
	_additional_storages.clear()


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


func test_absolute_path_does_not_claim_transfer() -> void:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({"value": 1})

	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		"C:/outside/transfer.json",
		transfer
	)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_error_code(), ERR_INVALID_PARAMETER)
	assert_eq(operation.get_file_name(), "")
	assert_eq(operation.get_result().get_file_name(), "")
	assert_eq(
		operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
	)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.READY)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_null(operation.get_payload_transfer())
	assert_null(operation.reclaim_failed_payload())
	assert_true(transfer.release())
	assert_push_error(
		"[GFStorageUtility] save_payload_request_async 失败：file_name 不满足 portable logical path profile。"
	)


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


func test_payload_transfer_does_not_read_or_adopt_legacy_visible_file() -> void:
	var file_name: String = "test_transfer_legacy_visible.json"
	var visible_path: String = _write_legacy_visible_data_file(file_name, { "value": 1 })
	var visible_before: PackedByteArray = FileAccess.get_file_as_bytes(visible_path)
	var descriptor: Dictionary = _make_family_descriptor(_storage.save_dir_name, file_name)

	var missing_result: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(missing_result.ok, "没有 catalog/owner 的 visible 文件不得成为可读 family。")
	assert_eq(missing_result.error_code, ERR_FILE_NOT_FOUND)
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")),
		"读取 legacy visible 文件不得隐式创建 catalog。"
	)
	assert_eq(FileAccess.get_file_as_bytes(visible_path), visible_before)

	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({ "value": 2 })
	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		file_name,
		transfer
	)
	await _pump_storage_async_tasks()

	assert_true(operation.get_result().is_successful())
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")))
	assert_eq(
		FileAccess.get_file_as_bytes(visible_path),
		visible_before,
		"claim 私有 family 不得修改或领养同名 legacy visible 文件。"
	)
	var loaded: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "value"), 2)
	assert_true(transfer.release())


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


func test_initialized_root_is_frozen_while_queued_task_keeps_original_family() -> void:
	var storage_utility: GFStorageUtility = GFStorageUtility.new()
	storage_utility.save_dir_name = "test_storage_payload_transfer_frozen_a"
	storage_utility.encrypt_key = 0
	storage_utility.init()
	storage_utility.max_async_thread_count = 1
	_additional_storages.append(storage_utility)
	var blocker_transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 1,
	})
	var blocker_operation: GFStorageAsyncOperation = storage_utility.save_payload_request_async(
		"test_transfer_path_blocker.json",
		blocker_transfer
	)
	var target_transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 2,
	})
	var target_operation: GFStorageAsyncOperation = storage_utility.save_payload_request_async(
		"test_transfer_path_freeze.json",
		target_transfer
	)
	assert_eq(storage_utility._async_queue.size(), 1)

	storage_utility.save_dir_name = "test_storage_payload_transfer_frozen_b"

	assert_eq(
		storage_utility.save_dir_name,
		"test_storage_payload_transfer_frozen_a",
		"初始化后的 Storage root 不得漂移。"
	)
	assert_push_error(
		"[GFStorageUtility] save_dir_name 已在 Storage 初始化后冻结；请为另一个 root 创建新的 Utility。"
	)
	assert_eq(target_transfer.get_active_attempt_count(), 1)
	await _pump_specific_storage(storage_utility)
	assert_true(blocker_operation.get_result().is_successful())
	assert_true(target_operation.get_result().is_successful())

	var loaded: GFStorageReadResult = storage_utility.load_data("test_transfer_path_freeze.json")
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "value"), 2)
	var frozen_descriptor: Dictionary = _make_family_descriptor(
		storage_utility.save_dir_name,
		"test_transfer_path_freeze.json"
	)
	var other_descriptor: Dictionary = _make_family_descriptor(
		"test_storage_payload_transfer_frozen_b",
		"test_transfer_path_freeze.json"
	)
	assert_true(
		FileAccess.file_exists(GFVariantData.get_option_string(frozen_descriptor, "payload_path")),
		"queued task 应提交到初始化时冻结的 private family。"
	)
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(other_descriptor, "payload_path")),
		"被拒绝的 root 变更不得创建另一 private family。"
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
	var file_name: String = "test_transfer_committed_recovery.json"
	_storage.dispose()
	_storage = null
	var probe: CleanupPreservingStorage = CleanupPreservingStorage.new()
	probe.save_dir_name = "test_storage_payload_transfer"
	probe.encrypt_key = 0
	probe.init()
	_additional_storages.append(probe)
	var descriptor: Dictionary = _make_family_descriptor(probe.save_dir_name, file_name)
	probe.preserved_paths[GFVariantData.get_option_string(descriptor, "backup_path")] = true
	probe.preserved_paths[GFVariantData.get_option_string(descriptor, "transaction_path")] = true
	probe.preserved_paths[
		GFVariantData.get_option_string(descriptor, "transaction_commit_path")
	] = true
	probe.preserve_committed_artifacts = true
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 9,
	})
	var operation: GFStorageAsyncOperation = probe.save_payload_request_async(
		file_name,
		transfer
	)
	await _pump_specific_storage(probe)

	assert_true(operation.get_result().is_successful())
	var prepare_record: Dictionary = _read_plain_json_file(
		GFVariantData.get_option_string(descriptor, "transaction_path")
	)
	var commit_record: Dictionary = _read_plain_json_file(
		GFVariantData.get_option_string(descriptor, "transaction_commit_path")
	)
	_assert_single_member_transaction_record(prepare_record, descriptor, false, false)
	_assert_single_member_transaction_record(commit_record, descriptor, true, false)
	assert_eq(
		GFVariantData.get_option_string(prepare_record, "transaction_id"),
		GFVariantData.get_option_string(commit_record, "transaction_id"),
		"prepare/commit 必须证明同一个 frozen transaction snapshot。"
	)
	assert_true(transfer.release())
	probe.preserve_committed_artifacts = false
	probe.dispose()
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = "test_storage_payload_transfer"
	_storage.encrypt_key = 0
	_storage.init()

	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	await _pump_storage_async_tasks()
	var loaded: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "value"), 9)
	_assert_transaction_records_absent(_storage, file_name)


func test_frozen_async_recovery_rolls_back_valid_uncommitted_marker() -> void:
	var file_name: String = "test_transfer_uncommitted_recovery.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
	var descriptor: Dictionary = _make_family_descriptor(_storage.save_dir_name, file_name)
	var payload_path: String = GFVariantData.get_option_string(descriptor, "payload_path")
	var backup_path: String = GFVariantData.get_option_string(descriptor, "backup_path")
	assert_eq(_storage._write_transaction_markers([file_name], false), OK)
	var prepare_record: Dictionary = _read_plain_json_file(
		GFVariantData.get_option_string(descriptor, "transaction_path")
	)
	_assert_single_member_transaction_record(prepare_record, descriptor, false, true)
	assert_eq(
		DirAccess.rename_absolute(payload_path, backup_path),
		OK
	)
	assert_eq(_storage._write_json(file_name, { "value": 2 }), OK)

	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	await _pump_storage_async_tasks()

	var result: GFStorageReadResult = operation.get_result().get_read_result()
	assert_true(result.ok)
	assert_eq(
		GFVariantData.get_option_int(result.payload, "value"),
		1,
		"valid uncommitted marker 必须恢复旧 final，而不是保留部分提交的新代次。"
	)
	_assert_transaction_records_absent(_storage, file_name)
	assert_false(FileAccess.file_exists(backup_path))


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
