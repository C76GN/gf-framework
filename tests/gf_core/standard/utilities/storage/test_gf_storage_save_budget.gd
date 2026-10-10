@tool

# 测试纯数据保存的完整明文与最终物理字节预算、事务准入和异步快照。
extends GutTest


# --- 常量 ---

const _DEFAULT_BUDGET: int = 64 * 1024 * 1024
const _OWNED_ROOT_PREFIX: String = "user://gf-storage-save-budget-"


# --- 私有变量 ---

var _storage: _GatedStorage
var _storage_root: String = ""


# --- Godot 生命周期方法 ---

func before_each() -> void:
	var save_dir_name: String = "gf-storage-save-budget-" + GFUuid.generate_v4()
	_storage_root = GFStorageFamilyStore.make_storage_root_path_for_framework(save_dir_name)
	_storage = _GatedStorage.new()
	_storage.save_dir_name = save_dir_name
	_storage.normalize_json_numbers = true
	_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	_storage.max_async_thread_count = 1
	assert_eq(_storage.create_revision_storage(), OK)


func after_each() -> void:
	_storage.release_for_test()
	_storage.dispose()
	_storage = null
	assert_true(_storage_root.begins_with(_OWNED_ROOT_PREFIX))
	if _storage_root.begins_with(_OWNED_ROOT_PREFIX):
		assert_eq(_remove_owned_tree(_storage_root), OK)
	_storage_root = ""


# --- 公共方法 ---

func test_default_encryption_physical_expansion_is_rejected_before_new_write() -> void:
	assert_eq(_storage.encrypt_key, 42, "默认保存使用 key 42 的最终物理字节预算。")
	var file_name: String = "default-key.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	var original: Dictionary = _capture_family(file_name)
	var payload: Dictionary = {"value": 2, "text": "small physical fixture ".repeat(8)}
	var plaintext_count: int = _plaintext_byte_count(payload)
	var physical_count: int = _encoded_bytes(payload).size()
	assert_gt(physical_count, plaintext_count, "base64 封装会扩大最终文件。")
	_storage.max_read_bytes = plaintext_count
	assert_eq(_storage.save_data(file_name, payload), ERR_OUT_OF_MEMORY)
	_assert_family_preserved(file_name, original)

	var new_file_name: String = "new-family.json"
	assert_eq(_storage.save_data(new_file_name, payload), ERR_OUT_OF_MEMORY)
	var descriptor: Dictionary = _storage._make_family_descriptor(new_file_name)
	for path_key: String in ["catalog_path", "owner_path", "payload_path"]:
		assert_false(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)))
	_assert_no_new_transaction(new_file_name)


func test_compression_cannot_hide_a_complete_plaintext_budget_failure() -> void:
	_storage.use_compression = true
	_storage.use_integrity_checksum = true
	# 关闭可选 metadata 后，compression 不改变压缩前的文档形状。
	_storage.include_storage_metadata = false
	var file_name: String = "compressed.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	var original: Dictionary = _capture_family(file_name)
	var payload: Dictionary = {"value": 2, "text": "compressible fixture ".repeat(128)}
	var plaintext_count: int = _plaintext_byte_count(payload)
	var physical_count: int = _encoded_bytes(payload).size()
	assert_lt(physical_count * 2, plaintext_count, "小型压缩文件仍有较大的完整明文。")
	_storage.max_read_bytes = physical_count
	_storage.codec.max_decode_bytes = physical_count
	assert_eq(_storage.save_data(file_name, payload), ERR_OUT_OF_MEMORY)
	_assert_family_preserved(file_name, original)


func test_json_exact_and_one_byte_short_budgets_include_metadata_and_checksum() -> void:
	_assert_exact_budget_boundaries(GFStorageCodec.Format.JSON)


func test_binary_exact_and_one_byte_short_budgets_include_metadata_and_checksum() -> void:
	_assert_exact_budget_boundaries(GFStorageCodec.Format.BINARY)


func test_group_last_physical_budget_failure_preserves_every_member() -> void:
	_assert_group_budget_failure("physical")


func test_group_last_plaintext_budget_failure_preserves_every_member() -> void:
	_assert_group_budget_failure("plaintext")


func test_single_save_rechecks_pending_target_after_codec_reentry() -> void:
	var file_name: String = "reentry-single.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	var original: Dictionary = _capture_family(file_name)
	var reentrant_codec: _ReentrantCodec = _ReentrantCodec.new()
	_storage.codec = reentrant_codec
	var async_payload: Dictionary = {"value": 41}
	var operations: Array[GFStorageAsyncOperation] = _enqueue_from_codec_once(
		reentrant_codec, 11, file_name, async_payload
	)

	assert_eq(_storage.save_data(file_name, {"value": 11}), ERR_BUSY)
	assert_eq(reentrant_codec.trigger_count_for_test, 1)
	assert_eq(operations.size(), 1)
	if operations.size() != 1:
		return
	var operation: GFStorageAsyncOperation = operations[0]
	_assert_pending_write_preserved(file_name, original, operation)
	_assert_reentrant_async_commit(file_name, original, operation, async_payload)


func test_group_last_codec_reentry_rechecks_every_target_before_commit() -> void:
	var first_name: String = "reentry-group-a.json"
	var last_name: String = "reentry-group-z.json"
	assert_eq(_storage.save_data_group({first_name: {"value": 1}, last_name: {"value": 2}}), OK)
	var first_original: Dictionary = _capture_family(first_name)
	var last_original: Dictionary = _capture_family(last_name)
	var reentrant_codec: _ReentrantCodec = _ReentrantCodec.new()
	_storage.codec = reentrant_codec
	var async_payload: Dictionary = {"value": 41}
	var operations: Array[GFStorageAsyncOperation] = _enqueue_from_codec_once(
		reentrant_codec, 32, first_name, async_payload
	)

	assert_eq(
		_storage.save_data_group({first_name: {"value": 31}, last_name: {"value": 32}}),
		ERR_BUSY
	)
	assert_eq(reentrant_codec.trigger_count_for_test, 1)
	assert_eq(operations.size(), 1)
	if operations.size() != 1:
		return
	var operation: GFStorageAsyncOperation = operations[0]
	_assert_pending_write_preserved(first_name, first_original, operation)
	_assert_pending_write_preserved(last_name, last_original, operation)
	_assert_reentrant_async_commit(first_name, first_original, operation, async_payload)
	_assert_family_preserved(last_name, last_original)


func test_legacy_cooperative_save_uses_queued_budgets_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.COOPERATIVE, &"legacy")


func test_legacy_threaded_save_uses_queued_budgets_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.THREADED, &"legacy")


func test_request_cooperative_save_settles_budget_failure_once_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.COOPERATIVE, &"request")


func test_request_threaded_save_settles_budget_failure_once_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.THREADED, &"request")


func test_transfer_cooperative_save_returns_failed_attempt_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.COOPERATIVE, &"transfer")


func test_transfer_threaded_save_returns_failed_attempt_and_preserves_fifo() -> void:
	_assert_async_snapshot_and_fifo(GFStorageUtility.AsyncExecutionMode.THREADED, &"transfer")


# --- 私有/辅助方法 ---

func _enqueue_from_codec_once(
	reentrant_codec: _ReentrantCodec, trigger_value: int, file_name: String, payload: Dictionary
) -> Array[GFStorageAsyncOperation]:
	var operations: Array[GFStorageAsyncOperation] = []
	var storage_owner: WeakRef = weakref(_storage)
	# callback 只捕获 weak owner 和结果容器，不形成 Storage -> codec -> Storage 强引用环。
	reentrant_codec.arm_for_test(trigger_value, func() -> void:
		var owner_value: Variant = storage_owner.get_ref()
		if owner_value is GFStorageUtility:
			var active_storage: GFStorageUtility = owner_value
			operations.append(active_storage.save_data_request_async(file_name, payload))
	)
	return operations


func _assert_pending_write_preserved(
	file_name: String, original: Dictionary, operation: GFStorageAsyncOperation
) -> void:
	assert_false(operation.is_completed(), "cooperative 重入请求应保持 pending，同步保存不得等待它。")
	_assert_no_new_transaction(file_name)
	assert_eq(_read_primary_bytes(file_name), _snapshot_bytes(original))
	assert_eq(_read_committed_state_bytes(file_name), _snapshot_bytes(original, "state_bytes"))


func _assert_reentrant_async_commit(
	file_name: String, original: Dictionary, operation: GFStorageAsyncOperation, payload: Dictionary
) -> void:
	var completions: Array[int] = _count_completions(operation)
	_storage.wait_for_async_tasks()
	assert_true(operation.is_completed())
	assert_true(operation.get_result().is_successful())
	assert_eq(operation.get_result().get_error_code(), OK)
	assert_eq(completions, [1])
	_assert_no_new_transaction(file_name)
	var committed: Dictionary = _capture_family(file_name)
	assert_eq(GFVariantData.get_option_dictionary(committed, "payload"), payload)
	assert_ne(
		GFVariantData.get_option_string(committed, "revision"),
		GFVariantData.get_option_string(original, "revision")
	)


func _assert_exact_budget_boundaries(format: GFStorageCodec.Format) -> void:
	_storage.file_format = format
	for with_descriptor_fields: bool in [false, true]:
		_storage.include_storage_metadata = with_descriptor_fields
		_storage.use_integrity_checksum = with_descriptor_fields
		_restore_budgets()
		var file_name: String = "exact-%d-%s.data" % [format, str(with_descriptor_fields)]
		var payload: Dictionary = {"value": 42, "text": "UTF-8 边界"}
		var plaintext_count: int = _plaintext_byte_count(payload)
		var physical_count: int = _encoded_bytes(payload).size()
		assert_gt(plaintext_count, JSON.stringify(payload).to_utf8_buffer().size())
		_storage.max_read_bytes = physical_count
		_storage.codec.max_decode_bytes = plaintext_count
		assert_eq(_storage.save_data(file_name, payload), OK, "两个预算均允许 exact 边界。")
		var original: Dictionary = _capture_family(file_name)
		assert_eq(GFVariantData.get_option_dictionary(original, "payload"), payload)
		assert_eq(_read_primary_bytes(file_name).size(), physical_count)

		_storage.max_read_bytes = physical_count - 1
		assert_eq(_storage.save_data(file_name, payload), ERR_OUT_OF_MEMORY)
		_assert_family_preserved(file_name, original)
		_storage.max_read_bytes = physical_count
		_storage.codec.max_decode_bytes = plaintext_count - 1
		assert_eq(_storage.save_data(file_name, payload), ERR_OUT_OF_MEMORY)
		_assert_family_preserved(file_name, original)


func _assert_group_budget_failure(limit_kind: String) -> void:
	var first_name: String = "group-a.json"
	var last_name: String = "group-z.json"
	assert_eq(_storage.save_data_group({first_name: {"value": 1}, last_name: {"value": 1}}), OK)
	var first_original: Dictionary = _capture_family(first_name)
	var last_original: Dictionary = _capture_family(last_name)
	var first_payload: Dictionary = {"value": 2}
	var last_payload: Dictionary = {"value": 2, "text": "last group member ".repeat(32)}
	_set_rejecting_budget(last_payload, limit_kind)
	if limit_kind == "physical":
		assert_lt(_encoded_bytes(first_payload).size(), _storage.max_read_bytes)
	else:
		assert_lt(_plaintext_byte_count(first_payload), _storage.codec.max_decode_bytes)
	assert_eq(
		_storage.save_data_group({first_name: first_payload, last_name: last_payload}),
		ERR_OUT_OF_MEMORY
	)
	_assert_family_preserved(first_name, first_original)
	_assert_family_preserved(last_name, last_original)


func _assert_async_snapshot_and_fifo(
	mode: GFStorageUtility.AsyncExecutionMode, entry_point: StringName
) -> void:
	_storage.async_execution_mode = mode
	for limit_kind: String in ["physical", "plaintext"]:
		_restore_budgets()
		var file_name: String = "%s-%s.json" % [entry_point, limit_kind]
		assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
		var original: Dictionary = _capture_family(file_name)
		var rejected_payload: Dictionary = {"value": 2, "text": "queued budget fixture ".repeat(32)}
		var follower_payload: Dictionary = {"value": 3, "text": "FIFO follower"}
		var legacy_errors: Array[int] = []
		var failed_primary_snapshots: Array[PackedByteArray] = []
		var failed_state_snapshots: Array[PackedByteArray] = []
		var on_saved: Callable = func(saved_file_name: String, error_code: Error) -> void:
			assert_eq(saved_file_name, file_name)
			legacy_errors.append(error_code)
			if error_code != OK:
				failed_primary_snapshots.append(_read_primary_bytes(file_name))
				failed_state_snapshots.append(_read_committed_state_bytes(file_name))
				_assert_no_new_transaction(file_name)
		assert_eq(_storage.save_completed.connect(on_saved), OK)

		_set_rejecting_budget(rejected_payload, limit_kind)
		var rejected_transfer: GFStoragePayloadTransfer = null
		var follower_transfer: GFStoragePayloadTransfer = null
		if entry_point == &"transfer":
			rejected_transfer = GFStoragePayloadTransfer.take_ownership(rejected_payload)
			follower_transfer = GFStoragePayloadTransfer.take_ownership(follower_payload)
		_storage.arm_for_test()
		var rejected: GFStorageAsyncOperation = _enqueue_save(
			entry_point, file_name, rejected_payload, rejected_transfer
		)
		var rejected_completions: Array[int] = _count_completions(rejected)
		if rejected != null:
			assert_false(rejected.is_completed())
		if rejected_transfer != null:
			assert_eq(rejected_transfer.get_active_attempt_count(), 1)

		# 放宽当前配置不能改变先前请求的低预算；后续请求冻结新的高预算。
		_restore_budgets()
		var follower: GFStorageAsyncOperation = _enqueue_save(
			entry_point, file_name, follower_payload, follower_transfer
		)
		var follower_completions: Array[int] = _count_completions(follower)
		_storage.max_read_bytes = 1
		_storage.codec.max_decode_bytes = 1
		# Threaded 首个 worker 在此之前尚未执行 callback；cooperative 尚未 tick。
		_storage.release_for_test()
		_storage.wait_for_async_tasks()
		_storage.save_completed.disconnect(on_saved)

		assert_eq(legacy_errors, [ERR_OUT_OF_MEMORY, OK], "同文件失败和后续成功必须各通知一次并保持 FIFO。")
		assert_eq(failed_primary_snapshots.size(), 1)
		assert_eq(failed_state_snapshots.size(), 1)
		if failed_primary_snapshots.size() == 1:
			assert_eq(failed_primary_snapshots[0], _snapshot_bytes(original))
		if failed_state_snapshots.size() == 1:
			assert_eq(failed_state_snapshots[0], _snapshot_bytes(original, "state_bytes"))
		if rejected != null:
			_assert_budget_failure(rejected)
			assert_eq(rejected_completions, [1])
		if follower != null:
			assert_true(follower.is_completed())
			assert_true(follower.get_result().is_successful(), "收紧当前配置不能修改已入队的高预算。")
			assert_eq(follower_completions, [1])
		_assert_no_new_transaction(file_name)
		_restore_budgets()
		var committed: Dictionary = _capture_family(file_name)
		assert_eq(GFVariantData.get_option_dictionary(committed, "payload"), follower_payload)
		assert_ne(
			GFVariantData.get_option_string(committed, "revision"),
			GFVariantData.get_option_string(original, "revision")
		)

		if rejected_transfer != null and follower_transfer != null:
			assert_eq(rejected_transfer.get_active_attempt_count(), 0)
			assert_eq(follower_transfer.get_active_attempt_count(), 0)
			assert_same(rejected.reclaim_failed_payload(), rejected_transfer)
			assert_null(rejected.reclaim_failed_payload(), "失败 attempt 的 transfer 只归还一次。")
			assert_null(follower.reclaim_failed_payload())
			# 相同 transfer 不允许用不同 codec options 重新 claim。
			var mismatched_errors: Array[int] = []
			var on_mismatched_save: Callable = func(saved_file_name: String, error_code: Error) -> void:
				assert_eq(saved_file_name, file_name)
				mismatched_errors.append(error_code)
			assert_eq(_storage.save_completed.connect(on_mismatched_save), OK)
			var mismatched: GFStorageAsyncOperation = _storage.save_payload_request_async(file_name, rejected_transfer)
			assert_true(mismatched.is_completed(), "配置不一致必须即时拒绝，不入队。")
			assert_eq(mismatched.get_result().get_error_code(), ERR_INVALID_PARAMETER)
			assert_eq(
				mismatched.get_result().get_write_failure_kind(),
				GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			)
			assert_eq(rejected_transfer.get_active_attempt_count(), 0)
			assert_null(mismatched.get_payload_transfer())
			assert_null(mismatched.reclaim_failed_payload())
			var mismatched_completions: Array[int] = _count_completions(mismatched)
			_storage.wait_for_async_tasks()
			_storage.save_completed.disconnect(on_mismatched_save)
			assert_eq(mismatched_errors, [ERR_INVALID_PARAMETER])
			assert_eq(mismatched_completions, [0], "即时终态不会再异步发出 completed。")
			_assert_family_preserved(file_name, committed)

			# 恢复首次完全相同的低预算后，重试取得新 attempt 并正常异步结算。
			_set_rejecting_budget(rejected_payload, limit_kind)
			_storage.arm_for_test()
			var retry: GFStorageAsyncOperation = _storage.save_payload_request_async(file_name, rejected_transfer)
			assert_false(retry.is_completed())
			assert_eq(rejected_transfer.get_active_attempt_count(), 1)
			var retry_completions: Array[int] = _count_completions(retry)
			_storage.release_for_test()
			_storage.wait_for_async_tasks()
			_assert_budget_failure(retry)
			assert_eq(retry_completions, [1])
			assert_eq(rejected_transfer.get_active_attempt_count(), 0)
			assert_same(retry.reclaim_failed_payload(), rejected_transfer)
			assert_null(retry.reclaim_failed_payload())
			_assert_family_preserved(file_name, committed)
			assert_true(rejected_transfer.release())
			assert_true(follower_transfer.release())
			assert_true(rejected_transfer.is_released())
			assert_true(follower_transfer.is_released())


func _enqueue_save(
	entry_point: StringName,
	file_name: String,
	payload: Dictionary,
	transfer: GFStoragePayloadTransfer
) -> GFStorageAsyncOperation:
	match entry_point:
		&"legacy":
			assert_eq(_storage.save_data_async(file_name, payload), OK)
			return null
		&"request":
			return _storage.save_data_request_async(file_name, payload)
		&"transfer":
			return _storage.save_payload_request_async(file_name, transfer)
	assert_true(false, "未知测试入口。")
	return null


func _count_completions(operation: GFStorageAsyncOperation) -> Array[int]:
	var count: Array[int] = [0]
	if operation != null:
		assert_eq(operation.completed.connect(func(_result: GFStorageAsyncResult) -> void:
			count[0] += 1
		), OK)
	return count


func _assert_budget_failure(operation: GFStorageAsyncOperation) -> void:
	assert_true(operation.is_completed())
	var result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), ERR_OUT_OF_MEMORY)
	assert_eq(result.get_write_failure_kind(), GFStorageAsyncResult.WriteFailureKind.LIMIT_EXCEEDED)


func _set_rejecting_budget(payload: Dictionary, limit_kind: String) -> void:
	_restore_budgets()
	if limit_kind == "physical":
		_storage.max_read_bytes = _encoded_bytes(payload).size() - 1
	else:
		_storage.codec.max_decode_bytes = _plaintext_byte_count(payload) - 1


func _restore_budgets() -> void:
	_storage.max_read_bytes = _DEFAULT_BUDGET
	_storage.codec.max_decode_bytes = _DEFAULT_BUDGET


func _encoding_options() -> Dictionary:
	return {
		"format": _storage.file_format,
		"use_compression": _storage.use_compression,
		"obfuscation_key": _storage.encrypt_key,
		"use_integrity_checksum": _storage.use_integrity_checksum,
		"include_metadata": _storage.include_storage_metadata,
		"version": _storage.save_version,
		"max_decode_bytes": _DEFAULT_BUDGET,
	}


func _encoded_bytes(payload: Dictionary, options: Dictionary = {}) -> PackedByteArray:
	var active_options: Dictionary = _encoding_options() if options.is_empty() else options
	var encoded: Dictionary = _storage.codec.encode_result(payload, active_options)
	assert_true(GFVariantData.get_option_bool(encoded, "ok"))
	assert_eq(GFVariantData.get_option_int(encoded, "error"), OK)
	var bytes_value: Variant = encoded.get("bytes")
	assert_true(bytes_value is PackedByteArray)
	if bytes_value is PackedByteArray:
		var bytes: PackedByteArray = bytes_value
		return bytes
	return PackedByteArray()


func _plaintext_byte_count(payload: Dictionary) -> int:
	# 使用公开 encoder 测量完整文档；不复制 envelope、checksum 或序列化算法。
	var options: Dictionary = _encoding_options()
	options["use_compression"] = false
	options["obfuscation_key"] = 0
	return _encoded_bytes(payload, options).size()


func _capture_family(file_name: String) -> Dictionary:
	var loaded: GFStorageReadResult = _storage.load_data(file_name)
	var revision: GFStorageRevisionResult = _storage.query_committed_revision(file_name)
	assert_true(loaded.ok)
	assert_true(revision.is_successful())
	assert_false(revision.get_revision().is_empty())
	return {
		"bytes": _read_primary_bytes(file_name),
		"state_bytes": _read_committed_state_bytes(file_name),
		"payload": loaded.payload,
		"revision": revision.get_revision(),
	}


func _snapshot_bytes(snapshot: Dictionary, key: String = "bytes") -> PackedByteArray:
	var bytes_value: Variant = snapshot.get(key)
	if bytes_value is PackedByteArray:
		var bytes: PackedByteArray = bytes_value
		return bytes
	return PackedByteArray()


func _read_primary_bytes(file_name: String) -> PackedByteArray:
	var descriptor: Dictionary = _storage._make_family_descriptor(file_name)
	return FileAccess.get_file_as_bytes(GFVariantData.get_option_string(descriptor, "payload_path"))


func _read_committed_state_bytes(file_name: String) -> PackedByteArray:
	var context: Dictionary = _storage._make_revision_context(file_name)
	return FileAccess.get_file_as_bytes(GFVariantData.get_option_string(context, "state_path"))


func _assert_family_preserved(file_name: String, original: Dictionary) -> void:
	# 此处 fixture 无 prior recovery 待办；先查本次保存痕迹，再通过读取验证原代次。
	_assert_no_new_transaction(file_name)
	assert_eq(_read_primary_bytes(file_name), _snapshot_bytes(original))
	assert_eq(_read_committed_state_bytes(file_name), _snapshot_bytes(original, "state_bytes"))
	var physical_limit: int = _storage.max_read_bytes
	var plaintext_limit: int = _storage.codec.max_decode_bytes
	_restore_budgets()
	var current: Dictionary = _capture_family(file_name)
	assert_eq(
		GFVariantData.get_option_dictionary(current, "payload"),
		GFVariantData.get_option_dictionary(original, "payload")
	)
	assert_eq(
		GFVariantData.get_option_string(current, "revision"),
		GFVariantData.get_option_string(original, "revision")
	)
	_storage.max_read_bytes = physical_limit
	_storage.codec.max_decode_bytes = plaintext_limit


func _assert_no_new_transaction(file_name: String) -> void:
	var descriptor: Dictionary = _storage._make_family_descriptor(file_name)
	for path_key: String in [
		"candidate_path", "resource_stage_path", "transaction_path", "transaction_pending_path",
		"transaction_commit_path", "transaction_commit_pending_path",
	]:
		assert_false(
			FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)),
			"预算拒绝不能保留本次保存的 %s。" % path_key
		)


func _remove_owned_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_error != OK:
			return remove_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_tree(child_path)
		)
		if remove_error != OK:
			return remove_error
	directory = null
	return DirAccess.remove_absolute(path)


# --- 内部类 ---

class _ReentrantCodec extends GFStorageCodec:
	var trigger_count_for_test: int = 0
	var _trigger_value: int = 0
	var _callback: Callable = Callable()

	func encode_result(data: Dictionary, options: Dictionary = {}) -> Dictionary:
		if _callback.is_valid() and GFVariantData.get_option_int(data, "value") == _trigger_value:
			var callback: Callable = _callback
			_callback = Callable()
			trigger_count_for_test += 1
			var _result: Variant = callback.call()
		return super.encode_result(data, options)


	func arm_for_test(trigger_value: int, callback: Callable) -> void:
		_trigger_value = trigger_value
		_callback = callback


class _GatedStorage extends GFStorageUtility:
	var _worker_release: Semaphore = Semaphore.new()
	var _gate_next_worker: bool = false
	var _release_posted: bool = true

	func start_async_worker_for_framework(
		_task_type: StringName, thread: Thread, callback: Callable
	) -> Error:
		if _gate_next_worker:
			_gate_next_worker = false
			return thread.start(Callable(self, &"_run_gated_worker").bind(callback, _worker_release))
		return thread.start(callback)


	func arm_for_test() -> void:
		_worker_release = Semaphore.new()
		_gate_next_worker = true
		_release_posted = false


	func release_for_test() -> void:
		if _release_posted:
			return
		_release_posted = true
		_gate_next_worker = false
		_worker_release.post()


	func _run_gated_worker(callback: Callable, worker_release: Semaphore) -> Variant:
		worker_release.wait()
		return callback.call()
