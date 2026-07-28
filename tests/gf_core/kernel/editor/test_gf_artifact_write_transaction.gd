extends GutTest


# --- 常量 ---

const _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd"
)
const _GF_VARIANT_ACCESS_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_variant_access.gd"
)


# --- 私有变量 ---

var _temp_root: String = ""


# --- 测试生命周期 ---

func before_each() -> void:
	_temp_root = "user://gf_artifact_write_transaction/%d-%d" % [
		Time.get_ticks_usec(),
		get_instance_id(),
	]


func after_each() -> void:
	_remove_absolute_path(ProjectSettings.globalize_path(_temp_root))


# --- 测试用例 ---

func test_commit_writes_all_entries_and_returns_json_safe_reports() -> void:
	var text_path: String = _temp_root.path_join("content/item.txt")
	var bytes_path: String = _temp_root.path_join("content/item.bin")
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			text_path,
			"artifact-text",
			{
				"artifact_id": &"text",
				"metadata": { "owner": self },
			}
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_bytes_entry(
			bytes_path,
			PackedByteArray([1, 2, 3, 4]),
			{ "artifact_id": &"bytes" }
		),
	]

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
			"metadata": { "request_owner": self },
		}
	)
	var reports: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		report,
		"reports"
	)

	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"),
		"全部 staging 成功后才应提交多产物事务。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"committed"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "written_count"),
		2
	)
	assert_eq(_read_text(text_path), "artifact-text")
	assert_eq(_read_bytes(bytes_path), PackedByteArray([1, 2, 3, 4]))
	assert_eq(reports.size(), 2)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(reports[0]),
			"content_sha256"
		).length(),
		64,
		"每个产物报告应包含内容摘要。"
	)
	assert_ne(
		JSON.stringify(report).find("__gf_report_value__"),
		-1,
		"调用方 metadata 中的运行时对象应在报告边界结构化脱敏。"
	)
	assert_eq(_count_transaction_sidecars(), 0, "成功提交后不应残留 staging 或 backup。")


func test_dry_run_and_overwrite_policy_leave_targets_untouched() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	var dry_run_path: String = _temp_root.path_join("dry-run.txt")
	_write_text(existing_path, "before")
	var existing_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			existing_path,
			"after"
		),
	]
	var dry_run_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			dry_run_path,
			"preview"
		),
	]

	var rejected_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
			existing_entries,
			{
				"allowed_roots": [_temp_root],
				"overwrite_existing": false,
				"scan_filesystem": false,
			}
		)
	)
	var dry_run_report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		dry_run_entries,
		{
			"allowed_roots": [_temp_root],
			"dry_run": true,
			"scan_filesystem": false,
		}
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rejected_report, "ok"),
		"entry 未覆盖 overwrite 时应继承批次禁止覆盖策略。"
	)
	assert_eq(_read_text(existing_path), "before")
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(dry_run_report, "ok")
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(dry_run_report, "status"),
		"dry_run"
	)
	assert_false(FileAccess.file_exists(dry_run_path))
	assert_eq(_count_transaction_sidecars(), 0)


func test_unchanged_batch_commits_without_sidecars() -> void:
	var target_path: String = _temp_root.path_join("unchanged.txt")
	_write_text(target_path, "same")
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			target_path,
			"same"
		),
	]

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
		}
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"committed"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "written_count"),
		0
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "unchanged_count"),
		1
	)
	assert_eq(_read_text(target_path), "same")
	assert_eq(_count_transaction_sidecars(), 0)


func test_preflight_rejects_empty_duplicate_and_invalid_root_batches() -> void:
	var first_path: String = _temp_root.path_join("Item.txt")
	var second_path: String = _temp_root.path_join("item.txt")
	var duplicate_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(first_path, "a"),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(second_path, "b"),
	]
	var empty_entries: Array[Dictionary] = []
	var missing_root_entries: Array[Dictionary] = [duplicate_entries[0]]

	var duplicate_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			duplicate_entries,
			{ "allowed_roots": [_temp_root] }
		)
	)
	var invalid_root_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			duplicate_entries,
			{ "allowed_roots": ["D:/outside"] }
		)
	)
	var empty_root_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			duplicate_entries,
			{ "allowed_roots": [] }
		)
	)
	var empty_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(empty_entries)
	)
	var missing_root_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			missing_root_entries
		)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(duplicate_report, "ok"))
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(invalid_root_report, "ok"))
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(empty_root_report, "ok"))
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(empty_report, "ok"))
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(missing_root_report, "ok"),
		"公开事务必须显式声明非空 allowed_roots。"
	)
	assert_false(FileAccess.file_exists(first_path))
	assert_false(FileAccess.file_exists(second_path))


func test_preflight_rejects_hash_budget_and_nonportable_target() -> void:
	var hash_path: String = _temp_root.path_join("hash.txt")
	var reserved_path: String = _temp_root.path_join("CON.txt")
	var hash_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			hash_path,
			"payload",
			{ "expected_sha256": "0".repeat(64) }
		),
	]
	var reserved_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			reserved_path,
			"payload"
		),
	]

	var hash_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			hash_entries,
			{ "allowed_roots": [_temp_root] }
		)
	)
	var budget_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			hash_entries,
			{
				"allowed_roots": [_temp_root],
				"max_file_bytes": 3,
			}
		)
	)
	var reserved_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			reserved_entries,
			{ "allowed_roots": [_temp_root] }
		)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(hash_report, "ok"))
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(budget_report, "ok"))
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(reserved_report, "ok"))
	assert_false(FileAccess.file_exists(hash_path))
	assert_false(FileAccess.file_exists(reserved_path))


func test_file_entry_is_bounded_and_does_not_consume_source() -> void:
	var source_path: String = _temp_root.path_join("source.bin")
	var target_path: String = _temp_root.path_join("target.bin")
	_write_bytes(source_path, PackedByteArray([4, 3, 2, 1]))
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_file_entry(
			target_path,
			source_path
		),
	]

	var rejected_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.get_preflight_report(
			entries,
			{
				"allowed_roots": [_temp_root],
				"max_file_bytes": 3,
			}
		)
	)
	var committed_report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"max_file_bytes": 4,
			"scan_filesystem": false,
		}
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rejected_report, "ok"))
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(committed_report, "ok"))
	assert_eq(_read_bytes(target_path), PackedByteArray([4, 3, 2, 1]))
	assert_true(FileAccess.file_exists(source_path), "KIND_FILE 只读取，不应移动或删除源文件。")


func test_commit_from_worker_fails_before_any_filesystem_write() -> void:
	var target_path: String = _temp_root.path_join("worker/item.txt")
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			target_path,
			"payload"
		),
	]
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		func() -> Dictionary:
			return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
				entries,
				{
					"allowed_roots": [_temp_root],
					"scan_filesystem": false,
				}
			)
	)
	assert_eq(start_error, OK)
	var result_value: Variant = worker.wait_to_finish()
	var report: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(result_value)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"wrong_thread"
	)
	assert_false(FileAccess.file_exists(target_path))
	assert_false(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(_temp_root)
		),
		"错误线程必须在创建目标目录或 sidecar 前失败。"
	)


func test_terminal_action_from_worker_does_not_mint_recovery_handle() -> void:
	var existing_path: String = _temp_root.path_join("worker-existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		func() -> Dictionary:
			return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(
				transaction
			)
	)
	assert_eq(start_error, OK)
	var worker_value: Variant = worker.wait_to_finish()
	var worker_report: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(worker_value)
	)

	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(worker_report, "status"),
		"wrong_thread"
	)
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			worker_report,
			"recovery_required"
		),
		"错误线程不得把尚未验证的调用方字典铸造成恢复句柄。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			worker_report,
			"recovery_action"
		),
		&"",
		"没有受验证恢复句柄时不得报告终态动作。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			worker_report,
			"recovery_transaction"
		).is_empty()
	)
	var cleanup_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(cleanup_report, "ok"),
		"错误线程拒绝不应消费主线程仍需终结的原事务。"
	)
	assert_eq(_count_transaction_sidecars(), 0)


func test_external_writer_transaction_rolls_back_existing_and_new_paths() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	var new_path: String = _temp_root.path_join("new.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path, new_path]),
		{ "allowed_roots": [_temp_root] }
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	_write_text(existing_path, "after")
	_write_text(new_path, "new")
	var rollback_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)
	var repeated_complete: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rollback_report, "ok"))
	assert_eq(_read_text(existing_path), "before")
	assert_false(FileAccess.file_exists(new_path))
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(repeated_complete, "ok"),
		"同一事务只能 complete 或 rollback 一次。"
	)
	assert_eq(_count_transaction_sidecars(), 0)


func test_external_writer_snapshot_budget_fails_before_creating_backups() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")

	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{
			"allowed_roots": [_temp_root],
			"max_backup_bytes": 0,
		}
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	assert_eq(_read_text(existing_path), "before")
	assert_eq(_count_transaction_sidecars(), 0)


func test_replace_revalidates_staging_content_immediately_before_rename() -> void:
	var target_path: String = _temp_root.path_join("staging-drift.txt")
	_write_text(target_path, "before")
	var options: Dictionary = {
		"allowed_roots": [_temp_root],
		"scan_filesystem": false,
	}
	var source_entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			target_path,
			"expected"
		),
	]
	var normalized: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._normalize_entries(
			source_entries,
			options,
			true
		)
	)
	var changed_entries: Array[Dictionary] = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._get_changed_entries(
			normalized
		)
	)
	var staging_result: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._stage_entries(
			changed_entries
		)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(staging_result, "ok"),
		"测试必须先建立有效 staging。"
	)
	var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		changed_entries[0],
		"staging_path"
	)
	_write_text(staging_path, "tampered")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		options
	)
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._enable_selective_rollback(
		transaction
	)

	var replace_result: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._replace_staged_entries(
			changed_entries,
			transaction
		)
	)
	var rollback_result: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(replace_result, "ok"),
		"staging 内容漂移必须在删除目标前失败。"
	)
	assert_eq(
		_read_text(target_path),
		"before",
		"不可信 staging 不得触碰既有目标。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rollback_result, "ok"),
		"未修改任何目标的事务应能安全释放 snapshot。"
	)


func test_selective_rollback_refuses_to_delete_post_commit_target_drift() -> void:
	var target_path: String = _temp_root.path_join("rollback-drift.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._enable_selective_rollback(
		transaction
	)
	_write_text(target_path, "committed")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._mark_transaction_path_modified(
		transaction,
		target_path,
		true,
		"committed".to_utf8_buffer().size(),
		FileAccess.get_sha256(target_path).to_lower()
	)
	_write_text(target_path, "external-drift")

	var refused_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(refused_report, "ok"),
		"已提交目标后来漂移时 rollback 必须 fail closed。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			refused_report,
			"status"
		),
		"rollback_preflight_failed"
	)
	assert_eq(
		_read_text(target_path),
		"external-drift",
		"恢复路径不得盲删不再属于事务的目标内容。"
	)
	_write_text(target_path, "committed")
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				refused_report,
				"recovery_transaction"
			)
		)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_eq(_read_text(target_path), "before")


func test_external_writer_complete_keeps_new_state_and_discards_backups() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	_write_text(existing_path, "after")

	var complete_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(complete_report, "ok"))
	assert_eq(_read_text(existing_path), "after")
	assert_eq(_count_transaction_sidecars(), 0)


func test_external_writer_rejects_tampered_transaction_state() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var valid_transaction: Dictionary = transaction.duplicate(true)
	transaction["transaction_token"] = "forged"

	var forged_rollback: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(forged_rollback, "ok"),
		"调用方篡改事务路径后必须在任何文件操作前失败。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			forged_rollback,
			"status"
		),
		"invalid_transaction"
	)
	assert_eq(_read_text(existing_path), "before")
	var cleanup_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(valid_transaction)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(cleanup_report, "ok"))
	assert_eq(_count_transaction_sidecars(), 0)


func test_terminal_operation_consumes_all_copied_handles() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var copied_handle: Dictionary = transaction.duplicate(true)
	_write_text(existing_path, "committed")

	var complete_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)
	var repeated_rollback: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(copied_handle)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(complete_report, "ok"))
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(repeated_rollback, "ok"),
		"任意 handle 副本完成终态后，其他副本都必须失效。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			repeated_rollback,
			"status"
		),
		"invalid_transaction"
	)
	assert_eq(
		_read_text(existing_path),
		"committed",
		"失效副本不得删除已经提交的目标。"
	)
	assert_eq(_count_transaction_sidecars(), 0)


func test_rollback_preflights_every_snapshot_before_touching_targets() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var backup_path: String = _find_transaction_sidecar("backup")
	assert_false(backup_path.is_empty(), "begin 应创建受控回滚快照。")
	_write_text(existing_path, "writer-state")
	_write_text(backup_path, "tampered")

	var rollback_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rollback_report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			rollback_report,
			"status"
		),
		"rollback_preflight_failed"
	)
	assert_eq(
		_read_text(existing_path),
		"writer-state",
		"任一快照不可信时，rollback 必须在零目标写入下失败。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			rollback_report,
			"recovery_required"
		),
		"预检失败后必须显式返回仍受 registry 约束的恢复句柄。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			rollback_report,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_ROLLBACK,
		"rollback 预检失败必须明确要求重试 rollback。"
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			rollback_report,
			"recovery_transaction"
		)
	)
	_write_text(backup_path, "before")
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(recovery_transaction)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"修复快照后，保留的 opaque handle 必须允许再次回滚。"
	)
	assert_eq(_read_text(existing_path), "before")
	assert_eq(_count_transaction_sidecars(), 0)


func test_external_writer_rollback_does_not_remove_directory_collision() -> void:
	var target_path: String = _temp_root.path_join("collision")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path)
	)
	assert_eq(make_error, OK)

	var rollback_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rollback_report, "ok"),
		"目标被替换为目录时回滚必须显式失败，不能递归删除未知内容。"
	)
	assert_true(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_path))
	)
	var cleanup_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(cleanup_report, "ok"))


func test_complete_failure_retains_narrowed_state_for_same_action_retry() -> void:
	var first_path: String = _temp_root.path_join("first.txt")
	var second_path: String = _temp_root.path_join("second.txt")
	_write_text(first_path, "first-before")
	_write_text(second_path, "second-before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([first_path, second_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var first_backup_path: String = (
		_find_transaction_sidecar_for_target(first_path, "backup")
	)
	var second_backup_path: String = (
		_find_transaction_sidecar_for_target(second_path, "backup")
	)
	assert_false(first_backup_path.is_empty(), "首个目标应创建回滚快照。")
	assert_false(second_backup_path.is_empty(), "第二个目标应创建回滚快照。")
	var second_backup_absolute: String = ProjectSettings.globalize_path(
		second_backup_path
	)
	assert_eq(
		DirAccess.remove_absolute(second_backup_absolute),
		OK,
		"测试应能移除第二个快照文件。"
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(second_backup_absolute),
		OK,
		"测试应能以目录冲突注入确定性的 cleanup 故障。"
	)
	_write_text(first_path, "first-committed")
	_write_text(second_path, "second-committed")

	var failed_complete: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed_complete, "ok"),
		"任一剩余快照无法清理时 complete 必须失败。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			failed_complete,
			"status"
		),
		"cleanup_failed"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			failed_complete,
			"recovery_required"
		),
		"cleanup 失败必须保留可重试的 opaque 恢复句柄。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed_complete,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE,
		"cleanup 失败必须明确要求重试 complete。"
	)
	assert_false(
		FileAccess.file_exists(first_backup_path),
		"成功清理的前缀必须从 active state 收窄并立即释放。"
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			failed_complete,
			"recovery_transaction"
		)
	)
	var wrong_action: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(recovery_transaction)
	)
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(wrong_action, "ok"),
		"cleanup 已开始后不得切换为 rollback。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(wrong_action, "status"),
		"completion_required"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			wrong_action,
			"recovery_required"
		),
		"错误终态动作也必须继续返回正确的恢复句柄。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			wrong_action,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE,
		"终态锁定后必须继续报告同一个恢复动作。"
	)
	_remove_absolute_path(second_backup_absolute)
	var retry_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			wrong_action,
			"recovery_transaction"
		)
	)
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(retry_transaction)
	)

	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"排除介质冲突后必须能完成剩余 cleanup。"
	)
	assert_eq(_read_text(first_path), "first-committed")
	assert_eq(_read_text(second_path), "second-committed")
	assert_eq(_count_transaction_sidecars(), 0)


# --- 私有/辅助方法 ---

func _write_text(path: String, text: String) -> void:
	_write_bytes(path, text.to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	assert_eq(make_error, OK, "测试目录应创建成功。")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试文件应可写入。")
	if file == null:
		return
	var _store_result: Variant = file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	assert_eq(write_error, OK, "测试文件应完整写入。")


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _read_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _count_transaction_sidecars() -> int:
	var absolute_root: String = ProjectSettings.globalize_path(_temp_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return 0
	return _count_matching_files(absolute_root, ".gf-artifact-")


func _find_transaction_sidecar(kind: String) -> String:
	var absolute_root: String = ProjectSettings.globalize_path(_temp_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return ""
	var absolute_path: String = _find_matching_file(
		absolute_root,
		".gf-artifact-%s-" % kind
	)
	if absolute_path.is_empty():
		return ""
	return ProjectSettings.localize_path(absolute_path)


func _find_transaction_sidecar_for_target(
	target_path: String,
	kind: String
) -> String:
	var absolute_target_path: String = ProjectSettings.globalize_path(target_path)
	var absolute_path: String = _find_matching_file(
		absolute_target_path.get_base_dir(),
		"%s.gf-artifact-%s-" % [
			absolute_target_path.get_file(),
			kind,
		]
	)
	if absolute_path.is_empty():
		return ""
	return ProjectSettings.localize_path(absolute_path)


func _find_matching_file(path: String, needle: String) -> String:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return ""
	var _list_error: Error = directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = path.path_join(entry_name)
			if directory.current_is_dir():
				var nested_match: String = _find_matching_file(
					entry_path,
					needle
				)
				if not nested_match.is_empty():
					directory.list_dir_end()
					return nested_match
			elif entry_name.contains(needle):
				directory.list_dir_end()
				return entry_path
		entry_name = directory.get_next()
	directory.list_dir_end()
	return ""


func _count_matching_files(path: String, needle: String) -> int:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return 0
	var count: int = 0
	var _list_error: Error = directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = path.path_join(entry_name)
			if directory.current_is_dir():
				count += _count_matching_files(entry_path, needle)
			elif entry_name.contains(needle):
				count += 1
		entry_name = directory.get_next()
	directory.list_dir_end()
	return count


func _remove_absolute_path(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_file_result: Error = DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	var _list_error: Error = directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			_remove_absolute_path(path.path_join(entry_name))
		entry_name = directory.get_next()
	directory.list_dir_end()
	var _remove_directory_result: Error = DirAccess.remove_absolute(path)
