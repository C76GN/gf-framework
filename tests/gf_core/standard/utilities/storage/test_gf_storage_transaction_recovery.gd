## 测试 Storage v2 transaction marker 的崩溃恢复、失败关闭与 committed-view 语义。
extends GutTest


const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)


var _save_dir_name: String = ""
var _storage_root_path: String = ""
var _storage: GFStorageUtility
var _storage_instances: Array[GFStorageUtility] = []


class DrainMutationStorageUtility extends GFStorageUtility:
	var inject_during_next_drain: bool = false
	var injection_file_name: String = ""
	var injection_payload: Dictionary = {}
	var injection_error: Error = OK

	func wait_for_async_tasks() -> void:
		super.wait_for_async_tasks()
		if not inject_during_next_drain:
			return
		inject_during_next_drain = false
		injection_error = _write_transaction_markers([injection_file_name], false)
		if injection_error != OK:
			return
		injection_error = _write_json(
			_get_temp_filename(injection_file_name),
			injection_payload
		)
		if injection_error != OK:
			return
		injection_error = DirAccess.rename_absolute(
			_get_full_path(injection_file_name),
			_get_full_path(_get_backup_filename(injection_file_name))
		)


class CommitInvariantSabotageStorageUtility extends GFStorageUtility:
	var sabotage_next_committed_validation: bool = false
	var sabotage_error: Error = OK

	func _validate_single_committed_absolute_transaction(
		final_path: String,
		temp_path: String
	) -> Error:
		if sabotage_next_committed_validation:
			sabotage_next_committed_validation = false
			sabotage_error = DirAccess.rename_absolute(final_path, temp_path)
			if sabotage_error != OK:
				return sabotage_error
		return OK if FileAccess.file_exists(final_path) and not FileAccess.file_exists(
			temp_path
		) else ERR_FILE_CORRUPT


func before_each() -> void:
	_save_dir_name = "gf-tx-recovery-" + GFUuid.generate_v4()
	_storage_root_path = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		_save_dir_name
	)
	_storage = _configure_storage(GFStorageUtility.new(), true)


func after_each() -> void:
	for storage: GFStorageUtility in _storage_instances:
		if is_instance_valid(storage):
			storage.dispose()
	_storage_instances.clear()
	var cleanup_error: Error = _remove_test_root()
	assert_eq(cleanup_error, OK, "测试结束后应完整删除本测唯一 Storage root。")
	_storage = null
	_storage_root_path = ""
	_save_dir_name = ""


func test_corrupt_final_prepare_record_is_distinct_from_absence_and_fails_closed() -> void:
	var file_name: String = "tri-state/prepare.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	assert_eq(
		_recover_transaction_files([file_name]),
		OK,
		"没有 marker 的稳定 family 应是合法 absent 状态。"
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var prepare_path: String = GFVariantData.get_option_string(descriptor, "transaction_path")
	assert_eq(_write_text(prepare_path, "{}"), OK)
	var evidence_before: PackedByteArray = FileAccess.get_file_as_bytes(prepare_path)

	var recovery_error: Error = _recover_transaction_files([file_name])

	assert_eq(recovery_error, ERR_FILE_CORRUPT, "存在但损坏的 final prepare 必须失败关闭。")
	assert_true(FileAccess.file_exists(prepare_path), "损坏 prepare 必须保留为诊断证据。")
	assert_eq(FileAccess.get_file_as_bytes(prepare_path), evidence_before, "失败关闭不得改写损坏证据。")


func test_corrupt_final_commit_record_is_distinct_from_absence_and_fails_closed() -> void:
	var file_name: String = "tri-state/commit.json"
	assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
	assert_eq(
		_recover_transaction_files([file_name]),
		OK,
		"没有 marker 的稳定 family 应是合法 absent 状态。"
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var commit_path: String = GFVariantData.get_option_string(
		descriptor,
		"transaction_commit_path"
	)
	assert_eq(_write_text(commit_path, "{}"), OK)
	var evidence_before: PackedByteArray = FileAccess.get_file_as_bytes(commit_path)

	var recovery_error: Error = _recover_transaction_files([file_name])

	assert_eq(recovery_error, ERR_FILE_CORRUPT, "存在但损坏的 final commit 必须失败关闭。")
	assert_true(FileAccess.file_exists(commit_path), "损坏 commit 必须保留为诊断证据。")
	assert_eq(FileAccess.get_file_as_bytes(commit_path), evidence_before, "失败关闭不得改写损坏证据。")


func test_final_markers_reject_non_string_identity_fields_and_preserve_evidence() -> void:
	for test_case: Dictionary in _marker_identity_type_cases():
		var file_name: String = GFVariantData.get_option_string(test_case, "file_name")
		var field_path: String = GFVariantData.get_option_string(test_case, "field_path")
		var field_value: Variant = test_case.get("field_value")
		assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
		assert_eq(_storage._write_transaction_markers([file_name], false), OK)
		var descriptor: Dictionary = _descriptor(file_name)
		var marker_path: String = GFVariantData.get_option_string(
			descriptor,
			"transaction_path"
		)
		var marker: Dictionary = _storage._read_transaction_marker(file_name)
		var corrupt_marker: Dictionary = _mutate_marker_field(
			marker,
			field_path,
			field_value
		)
		assert_eq(_write_json_record(marker_path, corrupt_marker), OK)
		var evidence_before: PackedByteArray = FileAccess.get_file_as_bytes(marker_path)

		var recovery_error: Error = _recover_transaction_files([file_name])

		assert_eq(
			recovery_error,
			ERR_FILE_CORRUPT,
			"final marker 的非 String 字段必须失败关闭：%s" % field_path
		)
		assert_true(FileAccess.file_exists(marker_path), "损坏 final marker 必须保留。")
		assert_eq(
			FileAccess.get_file_as_bytes(marker_path),
			evidence_before,
			"失败关闭不得改写 final marker：%s" % field_path
		)


func test_pending_markers_reject_non_string_identity_fields_and_preserve_evidence() -> void:
	for test_case: Dictionary in _marker_identity_type_cases():
		var file_name: String = GFVariantData.get_option_string(test_case, "file_name")
		var field_path: String = GFVariantData.get_option_string(test_case, "field_path")
		var field_value: Variant = test_case.get("field_value")
		assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
		assert_eq(_storage._write_transaction_markers([file_name], false), OK)
		var descriptor: Dictionary = _descriptor(file_name)
		var final_path: String = GFVariantData.get_option_string(descriptor, "transaction_path")
		var pending_path: String = GFVariantData.get_option_string(
			descriptor,
			"transaction_pending_path"
		)
		var marker: Dictionary = _storage._read_transaction_marker(file_name)
		var corrupt_marker: Dictionary = _mutate_marker_field(
			marker,
			field_path,
			field_value
		)
		assert_eq(_write_json_record(pending_path, corrupt_marker), OK)
		assert_eq(DirAccess.remove_absolute(final_path), OK)
		var evidence_before: PackedByteArray = FileAccess.get_file_as_bytes(pending_path)

		var recovery_error: Error = _recover_transaction_files([file_name])

		assert_eq(
			recovery_error,
			ERR_FILE_CORRUPT,
			"pending marker 的非 String 字段必须失败关闭：%s" % field_path
		)
		assert_true(FileAccess.file_exists(pending_path), "损坏 pending marker 必须保留。")
		assert_eq(
			FileAccess.get_file_as_bytes(pending_path),
			evidence_before,
			"失败关闭不得改写 pending marker：%s" % field_path
		)


func test_valid_prepare_pending_is_promoted_then_rolls_back_to_old_generation() -> void:
	var file_name: String = "pending-prepare/data.json"
	assert_eq(_storage.save_data(file_name, {"value": 11}), OK)
	assert_eq(_storage._write_transaction_markers([file_name], false), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var prepare_path: String = GFVariantData.get_option_string(
		descriptor,
		"transaction_path"
	)
	var prepare_pending_path: String = GFVariantData.get_option_string(
		descriptor,
		"transaction_pending_path"
	)
	assert_eq(
		DirAccess.rename_absolute(prepare_path, prepare_pending_path),
		OK,
		"应能模拟 prepare pending 已 durable、final record 尚未 publish 的崩溃窗口。"
	)

	var recovery_error: Error = _recover_transaction_files([file_name])

	assert_eq(recovery_error, OK, "有效 prepare pending 必须先提升，再按未提交事务回滚。")
	_assert_group_evidence_absent([file_name])
	assert_eq(GFVariantData.get_option_int(_load_payload(file_name), "value"), 11)


func test_valid_commit_pending_in_reciprocal_group_keeps_new_generation() -> void:
	var data_file_name: String = "pending-commit/data.json"
	var meta_file_name: String = "pending-commit/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	_seed_group({
		data_file_name: {"value": 1},
		meta_file_name: {"value": 2},
	})
	_stage_fully_committed_group(file_names, {
		data_file_name: {"value": 101},
		meta_file_name: {"value": 202},
	})
	var meta_descriptor: Dictionary = _descriptor(meta_file_name)
	var commit_path: String = GFVariantData.get_option_string(
		meta_descriptor,
		"transaction_commit_path"
	)
	var commit_pending_path: String = GFVariantData.get_option_string(
		meta_descriptor,
		"transaction_commit_pending_path"
	)
	assert_eq(
		DirAccess.rename_absolute(commit_path, commit_pending_path),
		OK,
		"应能模拟 reciprocal group 中一个 commit record 尚停留在 pending 的窗口。"
	)

	var recovery_error: Error = _recover_transaction_files([data_file_name])

	assert_eq(recovery_error, OK, "有效 commit pending 必须提升并完成 committed group 收敛。")
	_assert_group_evidence_absent(file_names)
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "value"), 101)
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "value"), 202)


func test_group_transaction_id_rejects_number_and_bool_and_preserves_all_records() -> void:
	var transaction_id_values: Array[Variant] = [73, true]
	for case_index: int in transaction_id_values.size():
		var data_file_name: String = "typed-group-%d/data.json" % case_index
		var meta_file_name: String = "typed-group-%d/meta.json" % case_index
		var file_names: Array[String] = [data_file_name, meta_file_name]
		_seed_group({
			data_file_name: { "value": 1 },
			meta_file_name: { "value": 2 },
		})
		assert_eq(_storage._write_transaction_markers(file_names, false), OK)
		var evidence_paths: Array[String] = []
		var evidence_bytes: Array[PackedByteArray] = []
		for file_name: String in file_names:
			var descriptor: Dictionary = _descriptor(file_name)
			var final_path: String = GFVariantData.get_option_string(
				descriptor,
				"transaction_path"
			)
			var pending_path: String = GFVariantData.get_option_string(
				descriptor,
				"transaction_pending_path"
			)
			var marker: Dictionary = _storage._read_transaction_marker(file_name)
			marker["transaction_id"] = transaction_id_values[case_index]
			assert_eq(_write_json_record(final_path, marker), OK)
			assert_eq(_write_json_record(pending_path, marker), OK)
			evidence_paths.append(final_path)
			evidence_bytes.append(FileAccess.get_file_as_bytes(final_path))
			evidence_paths.append(pending_path)
			evidence_bytes.append(FileAccess.get_file_as_bytes(pending_path))

		var recovery_error: Error = _recover_transaction_files([data_file_name])

		assert_eq(recovery_error, ERR_FILE_CORRUPT, "group transaction_id 必须是 String。")
		for evidence_index: int in evidence_paths.size():
			var evidence_path: String = evidence_paths[evidence_index]
			assert_true(FileAccess.file_exists(evidence_path), "损坏 group record 必须保留。")
			assert_eq(
				FileAccess.get_file_as_bytes(evidence_path),
				evidence_bytes[evidence_index],
				"失败关闭不得改写任何 reciprocal group record。"
			)


func test_partial_initial_prepare_without_physical_mutation_aborts_cleanly() -> void:
	var data_file_name: String = "partial-prepare/data.json"
	var meta_file_name: String = "partial-prepare/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	_seed_group({
		data_file_name: {"value": 10},
		meta_file_name: {"value": 20},
	})
	assert_eq(_storage._write_transaction_markers(file_names, false), OK)
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(
				_descriptor(meta_file_name),
				"transaction_path"
			)
		),
		OK,
		"应能模拟 initial prepare 只发布了部分成员。"
	)

	var recovery_error: Error = _recover_transaction_files([data_file_name])

	assert_eq(recovery_error, OK, "物理 payload 未变化时，partial initial prepare 应可安全 abort。")
	_assert_group_evidence_absent(file_names)
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "value"), 10)
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "value"), 20)


func test_full_commit_with_partial_prepare_cleanup_converges() -> void:
	var data_file_name: String = "commit-prepare-cleanup/data.json"
	var meta_file_name: String = "commit-prepare-cleanup/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	_seed_group({
		data_file_name: {"value": 1},
		meta_file_name: {"value": 2},
	})
	_stage_fully_committed_group(file_names, {
		data_file_name: {"value": 101},
		meta_file_name: {"value": 202},
	})
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(
				_descriptor(data_file_name),
				"transaction_path"
			)
		),
		OK,
		"应能模拟 committed cleanup 只删除了部分 prepare。"
	)

	var recovery_error: Error = _recover_transaction_files([data_file_name])

	assert_eq(recovery_error, OK, "完整 reciprocal commit set 应支配 partial prepare cleanup。")
	_assert_group_evidence_absent(file_names)
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "value"), 101)
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "value"), 202)


func test_partial_commit_cleanup_after_prepare_cleanup_converges() -> void:
	var data_file_name: String = "commit-terminal-cleanup/data.json"
	var meta_file_name: String = "commit-terminal-cleanup/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	_seed_group({
		data_file_name: {"value": 3},
		meta_file_name: {"value": 4},
	})
	_stage_fully_committed_group(file_names, {
		data_file_name: {"value": 303},
		meta_file_name: {"value": 404},
	})
	for file_name: String in file_names:
		var descriptor: Dictionary = _descriptor(file_name)
		assert_eq(
			DirAccess.remove_absolute(GFVariantData.get_option_string(descriptor, "backup_path")),
			OK
		)
		assert_eq(
			DirAccess.remove_absolute(
				GFVariantData.get_option_string(descriptor, "transaction_path")
			),
			OK
		)
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(
				_descriptor(meta_file_name),
				"transaction_commit_path"
			)
		),
		OK,
		"应能模拟 prepare 已清空且 commit cleanup 仅完成部分成员。"
	)

	var recovery_error: Error = _recover_transaction_files([data_file_name])

	assert_eq(recovery_error, OK, "terminal committed physical state 应允许 partial commit cleanup 收敛。")
	_assert_group_evidence_absent(file_names)
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "value"), 303)
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "value"), 404)


func test_full_prepare_with_partial_commit_rolls_back() -> void:
	var data_file_name: String = "partial-commit/data.json"
	var meta_file_name: String = "partial-commit/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	_seed_group({
		data_file_name: {"value": 5},
		meta_file_name: {"value": 6},
	})
	_stage_fully_committed_group(file_names, {
		data_file_name: {"value": 505},
		meta_file_name: {"value": 606},
	})
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(
				_descriptor(meta_file_name),
				"transaction_commit_path"
			)
		),
		OK,
		"应能模拟 reciprocal commit set 尚未完整发布。"
	)

	var recovery_error: Error = _recover_transaction_files([data_file_name])

	assert_eq(recovery_error, OK, "full prepare + partial commit 不足以证明提交，必须回滚。")
	_assert_group_evidence_absent(file_names)
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "value"), 5)
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "value"), 6)


func test_rollback_restore_failure_preserves_evidence_and_retry_succeeds() -> void:
	var file_name: String = "retry/restore.json"
	assert_eq(_storage.save_data(file_name, {"value": 7}), OK)
	assert_eq(_storage._write_transaction_markers([file_name], false), OK)
	assert_eq(
		_storage._write_json(_storage._get_temp_filename(file_name), {"value": 707}),
		OK
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var final_path: String = GFVariantData.get_option_string(descriptor, "payload_path")
	var backup_path: String = GFVariantData.get_option_string(descriptor, "backup_path")
	var candidate_path: String = GFVariantData.get_option_string(descriptor, "candidate_path")
	var prepare_path: String = GFVariantData.get_option_string(descriptor, "transaction_path")
	assert_eq(DirAccess.rename_absolute(final_path, backup_path), OK)
	assert_eq(
		DirAccess.make_dir_absolute(final_path),
		OK,
		"同名目录应稳定阻断 backup restore。"
	)
	var transaction_reference: Dictionary = _storage._read_transaction_marker(file_name)
	var rollback_files: Array[String] = [file_name]

	var rollback_error: Error = GFVariantData.to_exact_int(
		_storage._transaction_manager.call(
			"_rollback_group_from_record",
			rollback_files,
			transaction_reference
		),
		ERR_BUG
	) as Error

	assert_ne(rollback_error, OK, "restore 被阻断时 rollback 必须报告失败。")
	assert_true(FileAccess.file_exists(prepare_path), "rollback 失败后必须保留 prepare evidence。")
	assert_true(FileAccess.file_exists(backup_path), "rollback 失败后必须保留 backup evidence。")
	assert_true(FileAccess.file_exists(candidate_path), "rollback 失败后必须保留 candidate evidence。")
	assert_eq(DirAccess.remove_absolute(final_path), OK, "解除 restore 阻断应成功。")

	var retry_error: Error = _recover_transaction_files([file_name])

	assert_eq(retry_error, OK, "解除物理故障后必须能凭保留证据幂等重试。")
	_assert_group_evidence_absent([file_name])
	assert_eq(GFVariantData.get_option_int(_load_payload(file_name), "value"), 7)


func test_activation_fails_and_closes_admission_on_corrupt_layout() -> void:
	var layout_path: String = _storage_root_path.path_join(".gf-storage/v1/layout.json")
	assert_true(FileAccess.file_exists(layout_path))
	assert_eq(_write_text(layout_path, "{}"), OK)
	_storage.dispose()
	var activating_storage: GFStorageUtility = _configure_storage(
		GFStorageUtility.new(),
		false
	)

	var completion: GFAsyncCompletion = activating_storage.begin_activation(null)

	assert_true(completion.is_failed(), "corrupt layout 必须让 activation 进入失败终态。")
	assert_eq(
		GFVariantData.get_option_int(completion.get_metadata(), "error_code", OK),
		ERR_FILE_CORRUPT
	)
	assert_eq(
		activating_storage.save_data("probe.json", {"value": 1}),
		ERR_UNAVAILABLE,
		"activation readiness 失败后必须关闭新的 I/O admission。"
	)


func test_list_recovers_committed_view_after_drain() -> void:
	var drain_storage: DrainMutationStorageUtility = DrainMutationStorageUtility.new()
	_replace_primary_storage(drain_storage)
	var file_name: String = "list/committed.json"
	assert_eq(drain_storage.save_data(file_name, {"value": 8}), OK)
	drain_storage.injection_file_name = file_name
	drain_storage.injection_payload = {"value": 808}
	drain_storage.inject_during_next_drain = true

	var files: PackedStringArray = drain_storage.list_files("", "json", true)

	assert_eq(drain_storage.injection_error, OK, "drain fault fixture 应构造完整 prepare 与未完成物理提交。")
	assert_true(files.has(file_name), "list 必须在 drain 后恢复并投影旧 committed payload。")
	_assert_group_evidence_absent([file_name])
	assert_eq(GFVariantData.get_option_int(_load_payload(file_name), "value"), 8)


func test_durable_commit_with_invalid_final_candidate_invariant_reports_failure() -> void:
	var sabotage_storage: CommitInvariantSabotageStorageUtility = (
		CommitInvariantSabotageStorageUtility.new()
	)
	_replace_primary_storage(sabotage_storage)
	var file_name: String = "async/invariant.json"
	sabotage_storage.sabotage_next_committed_validation = true

	var operation: GFStorageAsyncOperation = sabotage_storage.save_data_request_async(
		file_name,
		{"value": 9}
	)
	sabotage_storage.wait_for_async_tasks()
	var result: GFStorageAsyncResult = operation.get_result()
	var descriptor: Dictionary = _descriptor(file_name)

	assert_eq(sabotage_storage.sabotage_error, OK, "故障夹具应在 durable commit 后破坏 final/candidate invariant。")
	assert_false(result.is_successful(), "durable commit 后的终态 invariant 失败不得报告成功。")
	assert_eq(result.get_error_code(), ERR_FILE_CORRUPT)
	assert_false(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")),
		"故障夹具应留下 missing final。"
	)
	assert_true(
		FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "candidate_path")),
		"故障夹具应留下 candidate 作为冲突证据。"
	)
	assert_true(
		FileAccess.file_exists(
			GFVariantData.get_option_string(descriptor, "transaction_commit_path")
		),
		"调用方失败终态前 commit record 应已 durable。"
	)


func _marker_identity_type_cases() -> Array[Dictionary]:
	return [
		{
			"file_name": "1",
			"field_path": "owner.logical_path",
			"field_value": 1,
		},
		{
			"file_name": "true",
			"field_path": "member.logical_path",
			"field_value": true,
		},
		{
			"file_name": "typed-owner-family.json",
			"field_path": "owner.family_id",
			"field_value": 17,
		},
		{
			"file_name": "typed-member-family.json",
			"field_path": "member.family_id",
			"field_value": false,
		},
	]


func _mutate_marker_field(
	marker: Dictionary,
	field_path: String,
	field_value: Variant
) -> Dictionary:
	var result: Dictionary = marker.duplicate(true)
	if field_path.begins_with("owner."):
		var owner_record: Dictionary = GFVariantData.get_option_dictionary(result, "owner")
		owner_record[field_path.trim_prefix("owner.")] = field_value
		result["owner"] = owner_record
		return result
	var members: Array = GFVariantData.get_option_array(result, "members")
	var member: Dictionary = GFVariantData.as_dictionary(members[0])
	member[field_path.trim_prefix("member.")] = field_value
	members[0] = member
	result["members"] = members
	return result


func _write_json_record(path: String, record: Dictionary) -> Error:
	return _write_text(path, JSON.stringify(record))


func _configure_storage(storage: GFStorageUtility, initialize: bool) -> GFStorageUtility:
	storage.save_dir_name = _save_dir_name
	storage.encrypt_key = 0
	_storage_instances.append(storage)
	if initialize:
		storage.init()
	return storage


func _replace_primary_storage(storage: GFStorageUtility) -> void:
	if _storage != null:
		_storage.dispose()
	_storage = _configure_storage(storage, true)


func _descriptor(file_name: String) -> Dictionary:
	return _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		file_name
	)


func _recover_transaction_files(file_names: Array[String]) -> Error:
	return GFVariantData.to_exact_int(
		_storage.call("_recover_transaction_files", file_names),
		ERR_BUG
	) as Error


func _seed_group(payloads_by_file: Dictionary) -> void:
	assert_eq(_storage.save_data_group(payloads_by_file), OK, "测试夹具应写入旧 committed generation。")


func _stage_fully_committed_group(
	file_names: Array[String],
	payloads_by_file: Dictionary
) -> void:
	assert_eq(_storage._write_transaction_markers(file_names, false), OK)
	for file_name: String in file_names:
		assert_eq(
			_storage._write_json(
				_storage._get_temp_filename(file_name),
				GFVariantData.get_option_dictionary(payloads_by_file, file_name)
			),
			OK
		)
		assert_eq(
			DirAccess.rename_absolute(
				_storage._get_full_path(file_name),
				_storage._get_full_path(_storage._get_backup_filename(file_name))
			),
			OK
		)
		assert_eq(
			DirAccess.rename_absolute(
				_storage._get_full_path(_storage._get_temp_filename(file_name)),
				_storage._get_full_path(file_name)
			),
			OK
		)
	assert_eq(_storage._write_transaction_markers(file_names, true), OK)


func _load_payload(file_name: String) -> Dictionary:
	var result: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(result.ok, "测试辅助读取应成功：%s；%s" % [file_name, result.error])
	return result.payload.duplicate(true) if result.ok else {}


func _assert_group_evidence_absent(file_names: Array[String]) -> void:
	for file_name: String in file_names:
		var descriptor: Dictionary = _descriptor(file_name)
		for path_key: String in [
			"candidate_path",
			"backup_path",
			"transaction_path",
			"transaction_pending_path",
			"transaction_commit_path",
			"transaction_commit_pending_path",
			"resource_stage_path",
		]:
			assert_false(
				FileAccess.file_exists(GFVariantData.get_option_string(descriptor, path_key)),
				"事务收敛后不应残留 %s：%s" % [path_key, file_name]
			)


func _write_text(path: String, text: String) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(text) != null
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error


func _remove_test_root() -> Error:
	if (
		_storage_root_path.is_empty()
		or _storage_root_path == "user://"
		or not _storage_root_path.begins_with("user://gf-tx-recovery-")
	):
		return ERR_INVALID_PARAMETER
	return _remove_tree(_storage_root_path)


func _remove_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return ERR_FILE_CANT_OPEN
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return begin_error
	var entries: Array[String] = []
	var entry: String = directory.get_next()
	while not entry.is_empty():
		entries.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	for child_name: String in entries:
		var child_error: Error = _remove_tree(path.path_join(child_name))
		if child_error != OK:
			return child_error
	return DirAccess.remove_absolute(path)
