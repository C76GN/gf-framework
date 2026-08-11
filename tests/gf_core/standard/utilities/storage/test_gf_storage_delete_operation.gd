# 测试异步 Storage 删除请求的公开入口、身份与 missing-family 安全基线。
extends GutTest


const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)
const _DELETE_RESULT_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/storage/gf_storage_delete_result.gd"
)
const _DELETE_PATH_KEYS: Array[String] = [
	"backup_path",
	"transaction_pending_path",
	"transaction_path",
	"transaction_commit_pending_path",
	"transaction_commit_path",
	"candidate_path",
	"resource_stage_path",
	"payload_path",
]
const _DELETE_STAGE_TOKENS: Array[StringName] = [
	&"backup",
	&"transaction_prepare_pending",
	&"transaction_prepare",
	&"transaction_commit_pending",
	&"transaction_commit",
	&"candidate",
	&"resource_stage",
	&"final",
]
const _DELETE_MEMBER_NAMES: Array[String] = [
	"BACKUP",
	"TRANSACTION_EVIDENCE",
	"TRANSACTION_EVIDENCE",
	"TRANSACTION_EVIDENCE",
	"TRANSACTION_EVIDENCE",
	"CANDIDATE",
	"RESOURCE_STAGE",
	"FINAL",
]


class DeleteStageFaultStorageUtility extends GFStorageUtility:
	var fail_path: String = ""
	var injected_error: Error = ERR_FILE_CANT_WRITE
	var remove_before_error: bool = false
	var removal_calls: Array[Dictionary] = []

	func remove_delete_family_member_for_framework(
		member_kind: StringName,
		path: String
	) -> Error:
		removal_calls.append({
			"member_kind": member_kind,
			"path": path,
		})
		if path == fail_path:
			if remove_before_error and FileAccess.file_exists(path):
				var physical_remove_error: Error = DirAccess.remove_absolute(path)
				if physical_remove_error != OK:
					return physical_remove_error
			return injected_error
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		if not FileAccess.file_exists(path):
			return OK
		return DirAccess.remove_absolute(path)


class ThreadStartFaultStorageUtility extends GFStorageUtility:
	var fail_next_delete_start: bool = true

	func start_async_worker_for_framework(
		task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		if task_type == &"delete" and fail_next_delete_start:
			fail_next_delete_start = false
			return ERR_CANT_CREATE
		return thread.start(callback)


class LayoutAdmissionProbeStorageUtility extends GFStorageUtility:
	var expected_layout_path: String = ""
	var delete_start_count: int = 0
	var all_delete_starts_observed_layout: bool = true

	func start_async_worker_for_framework(
		task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		if task_type == &"delete":
			delete_start_count += 1
			all_delete_starts_observed_layout = (
				all_delete_starts_observed_layout
				and FileAccess.file_exists(expected_layout_path)
			)
		return thread.start(callback)


class BlockingDeleteStorageUtility extends GFStorageUtility:
	var blocked_path: String = ""
	var started_semaphore: Semaphore = Semaphore.new()
	var release_semaphore: Semaphore = Semaphore.new()
	var _did_block: bool = false

	func remove_delete_family_member_for_framework(
		_member_kind: StringName,
		path: String
	) -> Error:
		if path == blocked_path and not _did_block:
			_did_block = true
			started_semaphore.post()
			release_semaphore.wait()
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		if not FileAccess.file_exists(path):
			return OK
		return DirAccess.remove_absolute(path)

	func release_for_test() -> void:
		release_semaphore.post()


class BlockingSaveStorageUtility extends GFStorageUtility:
	var block_next_save: bool = true
	var started_semaphore: Semaphore = Semaphore.new()
	var release_semaphore: Semaphore = Semaphore.new()

	func _save_data_thread(
		file_name: String,
		final_path: String,
		temp_path: String,
		backup_path: String,
		transaction_path: String,
		transaction_pending_path: String,
		transaction_commit_path: String,
		transaction_commit_pending_path: String,
		transaction_id: String,
		data: Dictionary,
		codec_options: Dictionary
	) -> Dictionary:
		if block_next_save:
			block_next_save = false
			started_semaphore.post()
			release_semaphore.wait()
		return super._save_data_thread(
			file_name,
			final_path,
			temp_path,
			backup_path,
			transaction_path,
			transaction_pending_path,
			transaction_commit_path,
			transaction_commit_pending_path,
			transaction_id,
			data,
			codec_options
		)

	func release_for_test() -> void:
		release_semaphore.post()


var _storage: GFStorageUtility
var _save_dir_name: String = ""
var _storage_root_path: String = ""


func before_each() -> void:
	_save_dir_name = "gf-storage-delete-operation-" + GFUuid.generate_v4()
	_storage_root_path = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		_save_dir_name
	)
	assert_true(
		_storage_root_path.begins_with("user://gf-storage-delete-operation-"),
		"删除测试必须使用 UUID 独占 Storage root。"
	)
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0


func after_each() -> void:
	if _storage != null:
		_release_blocked_storage(_storage)
		_storage.dispose()
		_storage = null
	if _storage_root_path.begins_with("user://gf-storage-delete-operation-"):
		assert_eq(_remove_owned_test_tree(_storage_root_path), OK)
	_save_dir_name = ""
	_storage_root_path = ""


func _release_blocked_storage(storage: GFStorageUtility) -> void:
	if storage is BlockingDeleteStorageUtility:
		var blocking_delete: BlockingDeleteStorageUtility = storage
		blocking_delete.release_for_test()
	if storage is BlockingSaveStorageUtility:
		var blocking_save: BlockingSaveStorageUtility = storage
		blocking_save.release_for_test()


func test_delete_request_exposes_typed_missing_family_result_without_claiming() -> void:
	var operation_script_value: Variant = GFStorageAsyncOperation.new().get_script()
	assert_true(operation_script_value is GDScript)
	if not operation_script_value is GDScript:
		return
	var operation_script: GDScript = operation_script_value
	var operation_constants: Dictionary = operation_script.get_script_constant_map()
	assert_true(
		operation_constants.has("OPERATION_DELETE"),
		"GFStorageAsyncOperation 必须公开 OPERATION_DELETE。"
	)
	assert_true(
		_storage.has_method(&"delete_file_request_async"),
		"GFStorageUtility 必须公开 delete_file_request_async(file_name)。"
	)
	if (
		not operation_constants.has("OPERATION_DELETE")
		or not _storage.has_method(&"delete_file_request_async")
	):
		return

	var file_name: String = "contract/missing.json"
	var descriptor: Dictionary = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		file_name
	)
	var operation_value: Variant = _storage.call("delete_file_request_async", file_name)
	assert_true(operation_value is GFStorageAsyncOperation)
	if not operation_value is GFStorageAsyncOperation:
		return
	var operation: GFStorageAsyncOperation = operation_value
	assert_eq(
		operation.get_operation(),
		GFVariantData.get_option_string_name(operation_constants, "OPERATION_DELETE")
	)
	assert_eq(operation.get_file_name(), file_name)
	_storage.wait_for_async_tasks()
	assert_true(operation.is_completed(), "missing family 必须在调度排空后进入 typed 终态。")
	var async_result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(async_result)
	if async_result == null:
		return
	assert_true(async_result.has_method(&"get_delete_result"))
	if not async_result.has_method(&"get_delete_result"):
		return
	var delete_result_value: Variant = async_result.call("get_delete_result")
	assert_true(delete_result_value is RefCounted)
	if not delete_result_value is RefCounted:
		return
	var delete_result: RefCounted = delete_result_value
	assert_eq(GFVariantData.to_bool(delete_result.call("is_successful")), false)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_error_code")) as Error,
		ERR_FILE_NOT_FOUND
	)
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "owner_path")),
		"missing delete 不得创建 owner claim。"
	)
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")),
		"missing delete 不得创建 catalog shard。"
	)


func test_concurrent_missing_deletes_initialize_layout_before_worker_start() -> void:
	var probe_storage: LayoutAdmissionProbeStorageUtility = (
		LayoutAdmissionProbeStorageUtility.new()
	)
	probe_storage.expected_layout_path = _storage_root_path.path_join(
		".gf-storage/v1/layout.json"
	)
	assert_false(
		FileAccess.file_exists(probe_storage.expected_layout_path),
		"并发删除回归必须从尚未初始化 layout 的独占 root 开始。"
	)
	_replace_storage(probe_storage)
	_storage.max_async_thread_count = 2
	var first_operation: GFStorageAsyncOperation = _request_delete(
		"fresh-layout/first.json"
	)
	var second_operation: GFStorageAsyncOperation = _request_delete(
		"fresh-layout/second.json"
	)
	if first_operation == null or second_operation == null:
		return

	_storage.wait_for_async_tasks()
	assert_eq(probe_storage.delete_start_count, 2)
	assert_true(
		probe_storage.all_delete_starts_observed_layout,
		"fresh root 的 layout 必须在任一 delete worker 启动前由主线程完成。"
	)
	_assert_delete_terminal(
		first_operation,
		ERR_FILE_NOT_FOUND,
		"NOT_FOUND",
		0,
		0,
		0,
		"NONE"
	)
	_assert_delete_terminal(
		second_operation,
		ERR_FILE_NOT_FOUND,
		"NOT_FOUND",
		0,
		0,
		0,
		"NONE"
	)
	for file_name: String in [
		"fresh-layout/first.json",
		"fresh-layout/second.json",
	]:
		var descriptor: Dictionary = _descriptor(file_name)
		assert_false(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "owner_path")),
			"missing delete 不得创建 owner claim。"
		)
		assert_false(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")),
			"missing delete 不得创建 catalog shard。"
		)


func test_delete_removes_complete_family_in_final_last_order_and_keeps_claim() -> void:
	var file_name: String = "complete/all-members.json"
	var descriptor: Dictionary = _stage_complete_family(file_name)
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var owner_before: PackedByteArray = FileAccess.get_file_as_bytes(owner_path)
	var catalog_before: PackedByteArray = FileAccess.get_file_as_bytes(catalog_path)

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(operation, OK, "NONE", 8, 8, 0, "NONE")
	for path_key: String in _DELETE_PATH_KEYS:
		assert_false(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)),
			"成功删除后不得残留 %s。" % path_key
		)
	assert_eq(FileAccess.get_file_as_bytes(owner_path), owner_before, "owner claim 必须保留。")
	assert_eq(FileAccess.get_file_as_bytes(catalog_path), catalog_before, "catalog claim 必须保留。")
	assert_false(_storage.has_file(file_name))
	assert_false(_storage.list_files("complete", "json", true).has(file_name))


func test_delete_accepts_markerless_exact_backup_and_candidate_without_final() -> void:
	var file_name: String = "partial/markerless.json"
	var descriptor: Dictionary = _claim_empty_family(file_name)
	assert_eq(
		_write_text(GFVariantData.get_option_string(descriptor, "backup_path"), "backup"),
		OK
	)
	assert_eq(
		_write_text(GFVariantData.get_option_string(descriptor, "candidate_path"), "candidate"),
		OK
	)
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var claim_snapshot: Dictionary = _snapshot_existing_paths([owner_path, catalog_path])

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(operation, OK, "NONE", 2, 2, 0, "NONE")
	assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "backup_path")))
	assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "candidate_path")))
	_assert_snapshot_unchanged(claim_snapshot)


func test_delete_accepts_exact_single_member_transaction_marker() -> void:
	var file_name: String = "single-marker/data.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var prepare_marker: Dictionary = _make_single_member_marker(file_name, false)
	assert_eq(
		_write_json_record(
			GFVariantData.get_option_string(descriptor, "transaction_path"),
			prepare_marker
		),
		OK
	)

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(operation, OK, "NONE", 2, 2, 0, "NONE")
	assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")))
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "transaction_path"))
	)


func test_delete_reports_not_found_for_claimed_empty_family_without_mutating_claim() -> void:
	var file_name: String = "missing/claimed-empty.json"
	var descriptor: Dictionary = _claim_empty_family(file_name)
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var claim_snapshot: Dictionary = _snapshot_existing_paths([owner_path, catalog_path])

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(
		operation,
		ERR_FILE_NOT_FOUND,
		"NOT_FOUND",
		0,
		0,
		0,
		"NONE"
	)
	_assert_snapshot_unchanged(claim_snapshot)


func test_delete_rejects_group_malformed_and_mismatched_markers_without_modification() -> void:
	var group_a: String = "conflict/group-a.json"
	var group_b: String = "conflict/group-b.json"
	assert_eq(
		_storage.save_data_group({
			group_a: { "value": 1 },
			group_b: { "value": 2 },
		}),
		OK
	)
	assert_eq(_storage._write_transaction_markers([group_a, group_b], false), OK)
	var group_paths: Array[String] = []
	group_paths.append_array(_existing_family_paths(_descriptor(group_a), true))
	group_paths.append_array(_existing_family_paths(_descriptor(group_b), true))
	_assert_delete_conflict_preserves(group_a, group_paths)

	var malformed_file: String = "conflict/malformed.json"
	assert_eq(_storage.save_data(malformed_file, { "value": 3 }), OK)
	var malformed_descriptor: Dictionary = _descriptor(malformed_file)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(malformed_descriptor, "transaction_path"),
			"{malformed"
		),
		OK
	)
	_assert_delete_conflict_preserves(
		malformed_file,
		_existing_family_paths(malformed_descriptor, true)
	)

	var mismatched_file: String = "conflict/mismatched.json"
	var other_file: String = "conflict/other.json"
	assert_eq(_storage.save_data(mismatched_file, { "value": 4 }), OK)
	assert_eq(_storage.save_data(other_file, { "value": 5 }), OK)
	var mismatched_descriptor: Dictionary = _descriptor(mismatched_file)
	assert_eq(
		_write_json_record(
			GFVariantData.get_option_string(mismatched_descriptor, "transaction_path"),
			_make_single_member_marker(other_file, false)
		),
		OK
	)
	var mismatch_paths: Array[String] = []
	mismatch_paths.append_array(_existing_family_paths(mismatched_descriptor, true))
	mismatch_paths.append_array(_existing_family_paths(_descriptor(other_file), true))
	_assert_delete_conflict_preserves(mismatched_file, mismatch_paths)


func test_delete_fail_fast_matrix_keeps_final_until_every_prior_stage_succeeds() -> void:
	var fault_storage: DeleteStageFaultStorageUtility = DeleteStageFaultStorageUtility.new()
	_replace_storage(fault_storage)
	for failure_index: int in range(_DELETE_PATH_KEYS.size()):
		var file_name: String = "stage-failure/case-%d.json" % failure_index
		var descriptor: Dictionary = _stage_complete_family(file_name)
		var ordered_paths: Array[String] = _ordered_delete_paths(descriptor)
		var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
		var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
		var claim_snapshot: Dictionary = _snapshot_existing_paths([owner_path, catalog_path])
		fault_storage.fail_path = ordered_paths[failure_index]
		fault_storage.removal_calls.clear()

		var operation: GFStorageAsyncOperation = _request_delete(file_name)
		if operation == null:
			return
		_storage.wait_for_async_tasks()
		_assert_delete_terminal(
			operation,
			fault_storage.injected_error,
			"IO_FAILED",
			8,
			failure_index,
			8 - failure_index,
			_DELETE_MEMBER_NAMES[failure_index]
		)
		assert_eq(
			fault_storage.removal_calls.size(),
			failure_index + 1,
			"首错后不得继续删除。"
		)
		for call_index: int in range(fault_storage.removal_calls.size()):
			var call_record: Dictionary = fault_storage.removal_calls[call_index]
			assert_eq(GFVariantData.get_option_string(call_record, "path"), ordered_paths[call_index])
			assert_eq(
				GFVariantData.get_option_string_name(call_record, "member_kind"),
				_DELETE_STAGE_TOKENS[call_index]
			)
		for path_index: int in range(ordered_paths.size()):
			assert_eq(
				FileAccess.file_exists(ordered_paths[path_index]),
				path_index >= failure_index,
				"失败阶段及后续必须保留，之前阶段保持已删除。"
			)
		assert_true(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")),
			"FINAL 必须始终最后删除。"
		)
		_assert_snapshot_unchanged(claim_snapshot)


func test_delete_failure_counts_observed_removal_before_error() -> void:
	var fault_storage: DeleteStageFaultStorageUtility = DeleteStageFaultStorageUtility.new()
	_replace_storage(fault_storage)
	var file_name: String = "stage-failure/removed-before-error.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	fault_storage.fail_path = GFVariantData.get_option_string(descriptor, "payload_path")
	fault_storage.remove_before_error = true

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(
		operation,
		fault_storage.injected_error,
		"IO_FAILED",
		1,
		1,
		0,
		"FINAL"
	)
	assert_false(FileAccess.file_exists(fault_storage.fail_path))


func test_save_load_delete_load_requests_keep_same_file_fifo() -> void:
	_storage.max_async_thread_count = 2
	var file_name: String = "fifo/save-load-delete-load.json"
	var completion_order: Array[int] = []
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "value": 17 }
	)
	var first_load: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	var delete_operation: GFStorageAsyncOperation = _request_delete(file_name)
	if delete_operation == null:
		return
	var second_load: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	for operation: GFStorageAsyncOperation in [
		save_operation,
		first_load,
		delete_operation,
		second_load,
	]:
		var connect_error: Error = operation.completed.connect(
			func(result: GFStorageAsyncResult) -> void:
				completion_order.append(result.get_request_id())
		) as Error
		assert_eq(connect_error, OK)

	_storage.wait_for_async_tasks()
	assert_eq(
		completion_order,
		[
			save_operation.get_request_id(),
			first_load.get_request_id(),
			delete_operation.get_request_id(),
			second_load.get_request_id(),
		],
		"同文件 save/load/delete/load 必须严格按 admission 顺序完成。"
	)
	assert_true(save_operation.get_result().is_successful())
	var first_read: GFStorageReadResult = first_load.get_result().get_read_result()
	assert_not_null(first_read)
	if first_read != null:
		assert_true(first_read.ok)
		assert_eq(GFVariantData.get_option_int(first_read.payload, "value", -1), 17)
	_assert_delete_terminal(delete_operation, OK, "NONE", 1, 1, 0, "NONE")
	var second_read: GFStorageReadResult = second_load.get_result().get_read_result()
	assert_not_null(second_read)
	if second_read != null:
		assert_false(second_read.ok)
		assert_eq(second_read.error_code, ERR_FILE_NOT_FOUND)


func test_delete_save_load_requests_keep_same_file_fifo() -> void:
	var file_name: String = "fifo/delete-save-load.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
	_storage.max_async_thread_count = 2
	var delete_operation: GFStorageAsyncOperation = _request_delete(file_name)
	if delete_operation == null:
		return
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "value": 2 }
	)
	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(file_name)
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(delete_operation, OK, "NONE", 1, 1, 0, "NONE")
	assert_true(save_operation.get_result().is_successful())
	var read_result: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_not_null(read_result)
	if read_result != null:
		assert_true(read_result.ok)
		assert_eq(GFVariantData.get_option_int(read_result.payload, "value", -1), 2)


func test_delete_waits_for_prior_save_instead_of_observing_enqueue_time_missing_state() -> void:
	var blocking_save: BlockingSaveStorageUtility = BlockingSaveStorageUtility.new()
	_replace_storage(blocking_save)
	_storage.max_async_thread_count = 2
	var file_name: String = "fifo/save-then-delete.json"
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "value": 9 }
	)
	var worker_started: bool = await _wait_for_semaphore(blocking_save.started_semaphore)
	assert_true(worker_started, "保存 worker 必须先被测试屏障冻结。")
	if not worker_started:
		return
	var delete_operation: GFStorageAsyncOperation = _request_delete(file_name)
	if delete_operation == null:
		return
	assert_true(delete_operation.is_pending(), "delete 不得按入队时的 missing 状态提前完成。")
	blocking_save.release_for_test()
	_storage.wait_for_async_tasks()
	assert_true(save_operation.get_result().is_successful())
	_assert_delete_terminal(delete_operation, OK, "NONE", 1, 1, 0, "NONE")


func test_unrelated_delete_can_complete_while_same_file_followers_remain_blocked() -> void:
	var blocking_storage: BlockingDeleteStorageUtility = BlockingDeleteStorageUtility.new()
	_replace_storage(blocking_storage)
	_storage.max_async_thread_count = 2
	var file_a: String = "concurrency/a.json"
	var file_b: String = "concurrency/b.json"
	assert_eq(_storage.save_data(file_a, { "value": 1 }), OK)
	assert_eq(_storage.save_data(file_b, { "value": 2 }), OK)
	blocking_storage.blocked_path = GFVariantData.get_option_string(
		_descriptor(file_a),
		"payload_path"
	)
	var delete_a: GFStorageAsyncOperation = _request_delete(file_a)
	if delete_a == null:
		return
	var worker_started: bool = await _wait_for_semaphore(blocking_storage.started_semaphore)
	assert_true(worker_started, "A delete 必须进入阻塞删除阶段。")
	if not worker_started:
		return
	var load_a: GFStorageAsyncOperation = _storage.load_data_request_async(file_a)
	var second_delete_a: GFStorageAsyncOperation = _request_delete(file_a)
	var delete_b: GFStorageAsyncOperation = _request_delete(file_b)
	if second_delete_a == null or delete_b == null:
		return
	var b_completed: bool = await _pump_until_completed(delete_b)
	assert_true(b_completed, "不同 file_key 的 B delete 不得被 A 队首阻塞。")
	assert_true(delete_a.is_pending())
	assert_true(load_a.is_pending())
	assert_true(second_delete_a.is_pending())
	if b_completed:
		_assert_delete_terminal(delete_b, OK, "NONE", 1, 1, 0, "NONE")

	blocking_storage.release_for_test()
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(delete_a, OK, "NONE", 1, 1, 0, "NONE")
	var load_result: GFStorageReadResult = load_a.get_result().get_read_result()
	assert_not_null(load_result)
	if load_result != null:
		assert_eq(load_result.error_code, ERR_FILE_NOT_FOUND)
	_assert_delete_terminal(
		second_delete_a,
		ERR_FILE_NOT_FOUND,
		"NOT_FOUND",
		0,
		0,
		0,
		"NONE"
	)


func test_delete_thread_start_failure_releases_lock_and_preserves_family_for_retry() -> void:
	var fault_storage: ThreadStartFaultStorageUtility = ThreadStartFaultStorageUtility.new()
	_replace_storage(fault_storage)
	var file_name: String = "start-failure/data.json"
	assert_eq(_storage.save_data(file_name, { "value": 23 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var family_snapshot: Dictionary = _snapshot_existing_paths(
		_existing_family_paths(descriptor, true)
	)

	var failed_operation: GFStorageAsyncOperation = _request_delete(file_name)
	assert_push_error(
		"[GFStorageUtility] 异步删除失败：start-failure/data.json，原因：Thread start failed"
	)
	if failed_operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(
		failed_operation,
		ERR_CANT_CREATE,
		"THREAD_START_FAILED",
		0,
		0,
		0,
		"NONE"
	)
	_assert_snapshot_unchanged(family_snapshot)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_file_locks.is_empty())

	var retry_operation: GFStorageAsyncOperation = _request_delete(file_name)
	if retry_operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(retry_operation, OK, "NONE", 1, 1, 0, "NONE")


func test_malformed_worker_result_uses_guaranteed_typed_terminal_once() -> void:
	var file_name: String = "fallback/malformed-worker.json"
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(
		operation.configure_for_framework(
			9001,
			GFStorageAsyncOperation.OPERATION_DELETE,
			file_name
		)
	)
	var completion_results: Array[GFStorageAsyncResult] = []
	var connect_error: Error = operation.completed.connect(
		func(result: GFStorageAsyncResult) -> void:
			completion_results.append(result)
	) as Error
	assert_eq(connect_error, OK)
	var task: Dictionary = {
		"type": &"delete",
		"file_name": file_name,
		"operation": operation,
	}

	_storage.call("_complete_finished_async_task", task, {"unexpected": true})
	_assert_delete_terminal(
		operation,
		ERR_BUG,
		"IO_FAILED",
		0,
		0,
		0,
		"FAMILY_METADATA"
	)
	assert_eq(completion_results.size(), 1)

	_storage.call("_complete_finished_async_task", task, null)
	assert_eq(completion_results.size(), 1, "malformed worker 结果只能发布一次 fallback 终态。")

	var invalid_error_file_name: String = "fallback/invalid-error-code.json"
	var invalid_error_operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(
		invalid_error_operation.configure_for_framework(
			9002,
			GFStorageAsyncOperation.OPERATION_DELETE,
			invalid_error_file_name
		)
	)
	var invalid_error_completion_results: Array[GFStorageAsyncResult] = []
	var invalid_error_connect: Error = invalid_error_operation.completed.connect(
		func(result: GFStorageAsyncResult) -> void:
			invalid_error_completion_results.append(result)
	) as Error
	assert_eq(invalid_error_connect, OK)
	var invalid_error_task: Dictionary = {
		"type": &"delete",
		"file_name": invalid_error_file_name,
		"operation": invalid_error_operation,
	}
	var invalid_error_worker_result: Dictionary = {
		"error_code": int(ERR_PRINTER_ON_FIRE) + 1,
		"failure_kind": int(GFStorageDeleteResult.FailureKind.IO_FAILED),
		"existing_member_count": 1,
		"removed_member_count": 0,
		"remaining_member_count": 1,
		"failed_member": int(GFStorageDeleteResult.FamilyMember.FINAL),
	}

	_storage.call(
		"_complete_finished_async_task",
		invalid_error_task,
		invalid_error_worker_result
	)
	_assert_delete_terminal(
		invalid_error_operation,
		ERR_BUG,
		"IO_FAILED",
		0,
		0,
		0,
		"FAMILY_METADATA"
	)
	assert_eq(invalid_error_completion_results.size(), 1)

	_storage.call(
		"_complete_finished_async_task",
		invalid_error_task,
		invalid_error_worker_result
	)
	assert_eq(
		invalid_error_completion_results.size(),
		1,
		"超出 Error enum 范围的 worker 结果只能发布一次 fallback 终态。"
	)


func test_dispose_completes_active_delete_but_rejects_queued_and_reentrant_delete() -> void:
	var blocking_storage: BlockingDeleteStorageUtility = BlockingDeleteStorageUtility.new()
	_replace_storage(blocking_storage)
	_storage.max_async_thread_count = 1
	var active_file: String = "dispose/active.json"
	var reentrant_file: String = "dispose/reentrant.json"
	assert_eq(_storage.save_data(active_file, { "value": 1 }), OK)
	assert_eq(_storage.save_data(reentrant_file, { "value": 2 }), OK)
	blocking_storage.blocked_path = GFVariantData.get_option_string(
		_descriptor(active_file),
		"payload_path"
	)
	var active_operation: GFStorageAsyncOperation = _request_delete(active_file)
	if active_operation == null:
		return
	var worker_started: bool = await _wait_for_semaphore(blocking_storage.started_semaphore)
	assert_true(worker_started)
	if not worker_started:
		return
	var queued_operation: GFStorageAsyncOperation = _request_delete(active_file)
	if queued_operation == null:
		return
	var active_signal_count: Array[int] = [0]
	var queued_signal_count: Array[int] = [0]
	var reentrant_operations: Array[GFStorageAsyncOperation] = []
	var active_connect_error: Error = active_operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			active_signal_count[0] += 1
			_storage.tick(0.0)
			_storage.wait_for_async_tasks()
			var reentrant_value: Variant = _storage.call(
				"delete_file_request_async",
				reentrant_file
			)
			if reentrant_value is GFStorageAsyncOperation:
				var reentrant_operation: GFStorageAsyncOperation = reentrant_value
				reentrant_operations.append(reentrant_operation)
	) as Error
	assert_eq(active_connect_error, OK)
	var queued_connect_error: Error = queued_operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			queued_signal_count[0] += 1
	) as Error
	assert_eq(queued_connect_error, OK)

	blocking_storage.release_for_test()
	_storage.dispose()
	assert_eq(active_signal_count[0], 1)
	assert_eq(queued_signal_count[0], 1)
	_assert_delete_terminal(active_operation, OK, "NONE", 1, 1, 0, "NONE")
	_assert_cancelled_terminal(queued_operation)
	assert_eq(reentrant_operations.size(), 1)
	if reentrant_operations.size() == 1:
		_assert_delete_terminal(
			reentrant_operations[0],
			ERR_UNAVAILABLE,
			"UNAVAILABLE",
			0,
			0,
			0,
			"NONE"
		)
	assert_true(
		FileAccess.file_exists(
			GFVariantData.get_option_string(_descriptor(reentrant_file), "payload_path")
		),
		"dispose completion 重入不得启动新的物理删除。"
	)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_queue.is_empty())
	assert_true(_storage._async_file_locks.is_empty())


func test_delete_never_adopts_legacy_visible_file() -> void:
	var file_name: String = "legacy/visible.json"
	var legacy_path: String = _storage_root_path.path_join(file_name)
	assert_eq(_write_text(legacy_path, "legacy-visible-bytes"), OK)
	var legacy_before: PackedByteArray = FileAccess.get_file_as_bytes(legacy_path)
	var descriptor: Dictionary = _descriptor(file_name)

	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(
		operation,
		ERR_FILE_NOT_FOUND,
		"NOT_FOUND",
		0,
		0,
		0,
		"NONE"
	)
	assert_eq(FileAccess.get_file_as_bytes(legacy_path), legacy_before)
	assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "owner_path")))
	assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")))
	assert_false(_storage.list_files("legacy", "json", true).has(file_name))


func test_delete_rejects_non_portable_paths_before_queue_or_worker_admission() -> void:
	for invalid_path: String in [
		"../escape.json",
		"/absolute.json",
		"C:/absolute.json",
		"Uppercase.json",
	]:
		var operation: GFStorageAsyncOperation = _request_delete(invalid_path)
		assert_push_error(
			"[GFStorageUtility] delete_file_request_async 失败：file_name 不满足 portable logical path profile。"
		)
		if operation == null:
			return
		_storage.wait_for_async_tasks()
		assert_eq(operation.get_file_name(), "")
		_assert_delete_terminal(
			operation,
			ERR_INVALID_PARAMETER,
			"INVALID_REQUEST",
			0,
			0,
			0,
			"NONE"
		)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_queue.is_empty())
	assert_true(_storage._async_file_locks.is_empty())


func _replace_storage(storage: GFStorageUtility) -> void:
	if _storage != null:
		_release_blocked_storage(_storage)
		_storage.dispose()
	_storage = storage
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0


func _descriptor(file_name: String) -> Dictionary:
	return _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		file_name
	)


func _claim_empty_family(file_name: String) -> Dictionary:
	_storage.init()
	assert_eq(
		_storage._prepare_family_for_write(file_name),
		OK,
		"测试夹具必须建立合法 catalog/owner claim。"
	)
	return _descriptor(file_name)


func _stage_complete_family(file_name: String) -> Dictionary:
	assert_eq(_storage.save_data(file_name, { "value": file_name }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		_write_text(GFVariantData.get_option_string(descriptor, "backup_path"), "backup"),
		OK
	)
	assert_eq(
		_write_text(GFVariantData.get_option_string(descriptor, "candidate_path"), "candidate"),
		OK
	)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "resource_stage_path"),
			"resource-stage"
		),
		OK
	)
	var prepare_marker: Dictionary = _make_single_member_marker(file_name, false)
	var commit_marker: Dictionary = _make_single_member_marker(file_name, true)
	for prepare_path_key: String in ["transaction_pending_path", "transaction_path"]:
		assert_eq(
			_write_json_record(
				GFVariantData.get_option_string(descriptor, prepare_path_key),
				prepare_marker
			),
			OK
		)
	for commit_path_key: String in [
		"transaction_commit_pending_path",
		"transaction_commit_path",
	]:
		assert_eq(
			_write_json_record(
				GFVariantData.get_option_string(descriptor, commit_path_key),
				commit_marker
			),
			OK
		)
	for path_key: String in _DELETE_PATH_KEYS:
		assert_true(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)),
			"完整 family 夹具必须包含 %s。" % path_key
		)
	return descriptor


func _make_single_member_marker(file_name: String, committed: bool) -> Dictionary:
	var file_names: Array[String] = [file_name]
	var had_final_by_file: Dictionary = { file_name: true }
	return GFStorageUtility._make_transaction_marker(
		file_names,
		file_name,
		"delete-test:%s" % file_name,
		committed,
		had_final_by_file
	)


func _ordered_delete_paths(descriptor: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	for path_key: String in _DELETE_PATH_KEYS:
		paths.append(GFVariantData.get_option_string(descriptor, path_key))
	return paths


func _existing_family_paths(descriptor: Dictionary, include_claim: bool) -> Array[String]:
	var path_keys: Array[String] = _DELETE_PATH_KEYS.duplicate()
	if include_claim:
		path_keys.append("owner_path")
		path_keys.append("catalog_path")
	var result: Array[String] = []
	for path_key: String in path_keys:
		var path: String = GFVariantData.get_option_string(descriptor, path_key)
		if not path.is_empty() and FileAccess.file_exists(path) and not result.has(path):
			result.append(path)
	return result


func _snapshot_existing_paths(paths: Array[String]) -> Dictionary:
	var snapshot: Dictionary = {}
	for path: String in paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			snapshot[path] = FileAccess.get_file_as_bytes(path)
	return snapshot


func _assert_snapshot_unchanged(snapshot: Dictionary) -> void:
	for path_value: Variant in snapshot:
		assert_true(path_value is String)
		if not path_value is String:
			continue
		var path: String = path_value
		assert_true(FileAccess.file_exists(path), "失败关闭必须保留证据：%s" % path)
		var expected_content_value: Variant = snapshot.get(path)
		if not expected_content_value is PackedByteArray:
			fail_test("snapshot 必须保存 PackedByteArray：%s" % path)
			continue
		var expected_content: PackedByteArray = expected_content_value
		assert_eq(
			FileAccess.get_file_as_bytes(path),
			expected_content,
			"失败关闭不得改写证据：%s" % path
		)


func _assert_delete_conflict_preserves(file_name: String, paths: Array[String]) -> void:
	var descriptor: Dictionary = _descriptor(file_name)
	var existing_member_count: int = 0
	for path_key: String in _DELETE_PATH_KEYS:
		if FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)):
			existing_member_count += 1
	var snapshot: Dictionary = _snapshot_existing_paths(paths)
	var operation: GFStorageAsyncOperation = _request_delete(file_name)
	if operation == null:
		return
	_storage.wait_for_async_tasks()
	_assert_delete_terminal(
		operation,
		ERR_FILE_CORRUPT,
		"CONFLICT",
		existing_member_count,
		0,
		existing_member_count,
		"TRANSACTION_EVIDENCE"
	)
	_assert_snapshot_unchanged(snapshot)


func _request_delete(file_name: String) -> GFStorageAsyncOperation:
	assert_true(
		_storage.has_method(&"delete_file_request_async"),
		"GFStorageUtility 必须公开 delete_file_request_async。"
	)
	if not _storage.has_method(&"delete_file_request_async"):
		return null
	var operation_value: Variant = _storage.call("delete_file_request_async", file_name)
	assert_true(operation_value is GFStorageAsyncOperation)
	if operation_value is GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = operation_value
		return operation
	return null


func _assert_delete_terminal(
	operation: GFStorageAsyncOperation,
	expected_error: Error,
	expected_failure_name: String,
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	expected_failed_member_name: String
) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_completed())
	var async_result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(async_result)
	if async_result == null:
		return
	assert_eq(async_result.get_error_code(), expected_error)
	assert_eq(async_result.is_successful(), expected_error == OK)
	assert_true(async_result.has_method(&"get_delete_result"))
	if not async_result.has_method(&"get_delete_result"):
		return
	var delete_result_value: Variant = async_result.call("get_delete_result")
	assert_true(delete_result_value is RefCounted)
	if not delete_result_value is RefCounted:
		return
	var delete_result: RefCounted = delete_result_value
	var failure_kinds: Dictionary = _delete_enum_values("FailureKind")
	var family_members: Dictionary = _delete_enum_values("FamilyMember")
	assert_eq(
		GFVariantData.to_bool(delete_result.call("is_successful")),
		expected_error == OK
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_error_code")) as Error,
		expected_error
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_failure_kind")),
		GFVariantData.get_option_int(failure_kinds, expected_failure_name, -1)
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_existing_member_count")),
		existing_member_count
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_removed_member_count")),
		removed_member_count
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_remaining_member_count")),
		remaining_member_count
	)
	assert_eq(
		GFVariantData.to_int(delete_result.call("get_failed_member")),
		GFVariantData.get_option_int(family_members, expected_failed_member_name, -1)
	)


func _assert_cancelled_terminal(operation: GFStorageAsyncOperation) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_completed())
	var async_result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(async_result)
	if async_result == null:
		return
	assert_eq(
		async_result.get_settlement_kind(),
		GFStorageAsyncResult.SettlementKind.CANCELLED
	)
	assert_eq(async_result.get_error_code(), ERR_SKIP)
	assert_false(async_result.is_successful())
	assert_null(async_result.get_read_result())
	assert_null(async_result.get_delete_result())
	assert_eq(
		async_result.get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.NONE
	)
	assert_true(async_result.get_write_validation_report().is_empty())


func _delete_enum_values(enum_name: String) -> Dictionary:
	assert_true(ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH))
	if not ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH):
		return {}
	var script_resource: Resource = load(_DELETE_RESULT_SCRIPT_PATH)
	assert_true(script_resource is GDScript)
	if not script_resource is GDScript:
		return {}
	var delete_result_script: GDScript = script_resource
	return GFVariantData.get_option_dictionary(
		delete_result_script.get_script_constant_map(),
		enum_name
	)


func _write_json_record(path: String, record: Dictionary) -> Error:
	return _write_text(path, JSON.stringify(record))


func _write_text(path: String, content: String) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _store_result: Variant = file.store_string(content)
	var write_error: Error = file.get_error()
	file.close()
	return write_error


func _wait_for_semaphore(semaphore: Semaphore) -> bool:
	for _frame_index: int in range(300):
		if semaphore.try_wait():
			return true
		await get_tree().process_frame
	return false


func _pump_until_completed(operation: GFStorageAsyncOperation) -> bool:
	for _frame_index: int in range(300):
		_storage.tick(0.0)
		if operation.is_completed():
			return true
		await get_tree().process_frame
	return operation.is_completed()


func _remove_owned_test_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
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
			else _remove_owned_test_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	directory = null
	return DirAccess.remove_absolute(path)
