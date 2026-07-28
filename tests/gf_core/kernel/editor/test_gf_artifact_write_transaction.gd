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
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._reset_test_owned_write_failures()
	assert_eq(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._active_transactions.size(),
		0,
		"每个测试都必须终结其 artifact transaction ownership。"
	)
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._active_transactions.clear()
	_remove_absolute_path(ProjectSettings.globalize_path(_temp_root), true)


# --- 测试用例 ---

func test_sidecar_helpers_include_hidden_entries_and_bound_cleanup() -> void:
	var hidden_path: String = _temp_root.path_join(
		".gf-artifact-hidden-test"
	)
	_write_text(hidden_path, "sidecar")
	var absolute_root: String = ProjectSettings.globalize_path(_temp_root)
	var absolute_hidden_path: String = ProjectSettings.globalize_path(
		hidden_path
	)
	var absolute_project_root: String = ProjectSettings.globalize_path(
		"res://"
	)

	assert_eq(
		_find_matching_file(absolute_root, ".gf-artifact-hidden-test"),
		absolute_hidden_path,
		"sidecar helper 必须跨平台枚举 dotfile。"
	)
	assert_eq(
		_count_matching_files(absolute_root, ".gf-artifact-hidden-test"),
		1
	)
	assert_false(
		_is_path_inside_temp_root(absolute_root),
		"测试主体不得删除临时根目录本身。"
	)
	assert_true(
		_is_path_inside_temp_root(absolute_root, true),
		"生命周期 cleanup 可显式接管临时根目录。"
	)
	assert_true(
		_is_path_inside_temp_root(absolute_hidden_path),
		"临时根目录内的 sidecar 应可安全清理。"
	)
	assert_false(
		_is_path_inside_temp_root(absolute_project_root, true),
		"即使启用根目录 cleanup，也不得越界到项目根目录。"
	)
	assert_false(_is_path_inside_temp_root("", true))


func test_sidecar_helpers_refuse_linked_escape_paths_when_supported() -> void:
	var scan_root_path: String = _temp_root.path_join("scan-root")
	var linked_target_path: String = _temp_root.path_join("linked-target")
	var sentinel_path: String = linked_target_path.path_join("sentinel.txt")
	_write_text(sentinel_path, "sentinel")
	var absolute_scan_root: String = ProjectSettings.globalize_path(
		scan_root_path
	)
	var absolute_linked_target: String = ProjectSettings.globalize_path(
		linked_target_path
	)
	var make_scan_root_error: Error = (
		DirAccess.make_dir_recursive_absolute(absolute_scan_root)
	)
	assert_eq(make_scan_root_error, OK, "测试应能创建独立扫描根目录。")
	if make_scan_root_error != OK:
		return
	var absolute_link_path: String = absolute_scan_root.path_join(
		"linked-target"
	)
	var scan_root_directory: DirAccess = DirAccess.open(absolute_scan_root)
	assert_not_null(scan_root_directory, "测试应能打开独立扫描根目录。")
	if scan_root_directory == null:
		return
	var link_error: Error = scan_root_directory.create_link(
		absolute_linked_target,
		absolute_link_path
	)
	if link_error != OK:
		assert_true(
			OS.has_feature("windows"),
			"POSIX 平台必须支持测试用目录链接：%s" % error_string(
				link_error
			)
		)
		return

	var link_is_detected: bool = _absolute_path_is_link(absolute_link_path)
	assert_true(link_is_detected)
	if not link_is_detected:
		var direct_unlink_error: Error = DirAccess.remove_absolute(
			absolute_link_path
		)
		assert_eq(direct_unlink_error, OK)
		return
	assert_eq(
		_find_matching_file(absolute_scan_root, "sentinel.txt"),
		"",
		"sidecar finder 不得沿链接越过临时根目录。"
	)
	assert_eq(_count_matching_files(absolute_scan_root, "sentinel.txt"), 0)
	var linked_sentinel_is_allowed: bool = _is_path_inside_temp_root(
		absolute_link_path.path_join("sentinel.txt")
	)
	assert_false(
		linked_sentinel_is_allowed,
		"祖先链接后的词法子路径不得通过写入或删除门禁。"
	)
	if linked_sentinel_is_allowed:
		var direct_unlink_error: Error = DirAccess.remove_absolute(
			absolute_link_path
		)
		assert_eq(direct_unlink_error, OK)
		return
	_remove_absolute_path(absolute_link_path)
	assert_false(
		_absolute_path_is_link(absolute_link_path),
		"cleanup 必须移除链接本身。"
	)
	assert_false(
		DirAccess.dir_exists_absolute(absolute_link_path),
		"cleanup 后链接路径不得仍解析为目录。"
	)
	assert_true(
		FileAccess.file_exists(sentinel_path),
		"清理链接只能 unlink 自身，不得触及 sibling target。"
	)


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

	_assert_closed_commit_shape(report)
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


func test_begin_budgets_peak_snapshot_and_restore_bytes_with_closed_shape() -> void:
	var first_path: String = _temp_root.path_join("first-budget.txt")
	var second_path: String = _temp_root.path_join("second-budget.txt")
	_write_text(first_path, "1234")
	_write_text(second_path, "123456")

	var rejected: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([first_path, second_path]),
		{
			"allowed_roots": [_temp_root],
			"max_backup_bytes": 15,
		}
	)

	_assert_closed_begin_shape(rejected)
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rejected, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(rejected, "state"),
		"failed"
	)
	assert_eq(_count_transaction_sidecars(), 0)

	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([first_path, second_path]),
		{
			"allowed_roots": [_temp_root],
			"max_backup_bytes": 16,
		}
	)

	_assert_closed_begin_shape(transaction)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			transaction,
			"backup_bytes"
		),
		16,
		"backup_bytes 应报告 snapshots 总和 10 加单个最大 restore working copy 6。"
	)
	var cleanup_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(cleanup_report, "ok"))
	assert_eq(_count_transaction_sidecars(), 0)


func test_commit_budgets_peak_snapshot_and_restore_bytes() -> void:
	var first_path: String = _temp_root.path_join("first-commit-budget.txt")
	var second_path: String = _temp_root.path_join("second-commit-budget.txt")
	_write_text(first_path, "1234")
	_write_text(second_path, "123456")
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			first_path,
			"ABCD"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			second_path,
			"ABCDEF"
		),
	]

	var rejected: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"max_backup_bytes": 15,
			"scan_filesystem": false,
		}
	)

	_assert_closed_commit_shape(rejected)
	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rejected, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(rejected, "status"),
		"preflight_failed"
	)
	assert_eq(_read_text(first_path), "1234")
	assert_eq(_read_text(second_path), "123456")
	assert_eq(_count_transaction_sidecars(), 0)

	var committed: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"max_backup_bytes": 16,
			"scan_filesystem": false,
		}
	)

	_assert_closed_commit_shape(committed)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(committed, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			committed,
			"backup_bytes"
		),
		16,
		"commit backup_bytes 应为 snapshots 总和 10 加单个最大 restore working copy 6。"
	)
	assert_eq(_read_text(first_path), "ABCD")
	assert_eq(_read_text(second_path), "ABCDEF")
	assert_eq(_count_transaction_sidecars(), 0)


func test_begin_late_failure_keeps_cleanup_recovery_ownership() -> void:
	var existing_path: String = _temp_root.path_join("existing.txt")
	_write_text(existing_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([existing_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var backup_path: String = _find_transaction_sidecar("backup")
	assert_false(backup_path.is_empty(), "测试必须先建立受事务持有的 backup。")
	if backup_path.is_empty():
		return
	var backup_absolute: String = ProjectSettings.globalize_path(backup_path)
	assert_true(_is_path_inside_temp_root(backup_absolute))
	if not _is_path_inside_temp_root(backup_absolute):
		return
	assert_eq(DirAccess.remove_absolute(backup_absolute), OK)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(backup_absolute),
		OK,
		"目录碰撞用于确定性注入 cleanup 失败。"
	)

	var failed_begin: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._finalize_failed_begin(
			transaction,
			PackedStringArray(["Injected late snapshot failure."])
		)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed_begin, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(failed_begin, "state"),
		"failed"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			failed_begin,
			"recovery_required"
		),
		"cleanup 失败时 begin 必须保留结构化恢复所有权。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed_begin,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	_remove_absolute_path(backup_absolute)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			failed_begin,
			"recovery_transaction"
		)
	)
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(recovery_transaction)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"清除介质冲突后，begin 返回的 recovery handle 必须可完成 cleanup。"
	)
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
	if backup_path.is_empty():
		return
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


func test_rollback_retries_from_recorded_target_removed_state() -> void:
	var target_path: String = _temp_root.path_join("target-removed.txt")
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
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path)),
		OK,
		"测试应模拟 rollback 已删除 committed replacement。"
	)
	assert_true(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._record_rollback_target_removed(
			transaction,
			target_path
		),
		"删除后的中间状态必须写回受 registry 保护的事务。"
	)

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"backup rename 失败后返回的 rollback handle 必须能从 target_removed 重试。"
	)
	assert_eq(_read_text(target_path), "before")
	assert_eq(_count_transaction_sidecars(), 0)


func test_rollback_retries_after_restore_verification_failure() -> void:
	var target_path: String = _temp_root.path_join("restore-verification.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var backup_path: String = _find_transaction_sidecar("backup")
	assert_false(backup_path.is_empty(), "测试必须保留原始 backup。")
	if backup_path.is_empty():
		return
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._enable_selective_rollback(
		transaction
	)
	_write_text(target_path, "failed-restore")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._mark_transaction_path_modified(
		transaction,
		target_path,
		true,
		"failed-restore".to_utf8_buffer().size(),
		FileAccess.get_sha256(target_path).to_lower()
	)
	assert_true(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._record_rollback_restore_failure(
			transaction,
			target_path
		),
		"校验失败后的实际目标身份必须写回事务。"
	)

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"verification 失败后 recovery_action=rollback 必须能重用保留的 backup。"
	)
	assert_eq(_read_text(target_path), "before")
	assert_false(FileAccess.file_exists(backup_path))
	assert_eq(_count_transaction_sidecars(), 0)


func test_unknown_restore_failure_accepts_only_exact_original_state() -> void:
	var target_path: String = _temp_root.path_join("unknown-restore-state.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	var backup_path: String = _find_transaction_sidecar("backup")
	assert_false(backup_path.is_empty())
	if backup_path.is_empty():
		return
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path)),
		OK
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(target_path)
		),
		OK
	)
	assert_false(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._record_rollback_restore_failure(
			transaction,
			target_path
		),
		"目录状态不可哈希时应记录 state_known=false。"
	)
	_remove_absolute_path(ProjectSettings.globalize_path(target_path))
	_write_text(target_path, "mismatch")

	var rejected: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(rejected, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(rejected, "status"),
		"rollback_preflight_failed",
		"未知失败状态不得把任意可读 replacement 当作已恢复目标。"
	)
	assert_eq(_read_text(target_path), "mismatch")
	assert_true(FileAccess.file_exists(backup_path))
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			rejected,
			"recovery_transaction"
		)
	)
	_write_text(target_path, "before")

	var recovered: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(recovery_transaction)
	)

	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(recovered, "ok"),
		"目标后来精确等于原始快照时，应转为 target_restored 并只清理 backup。"
	)
	assert_eq(_read_text(target_path), "before")
	assert_false(FileAccess.file_exists(backup_path))
	assert_eq(_count_transaction_sidecars(), 0)


func test_rollback_restore_partial_cleanup_retains_retryable_ownership() -> void:
	var target_path: String = _temp_root.path_join("partial-restore.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"))
	_write_text(target_path, "after")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		1,
		0,
		1
	)

	var failed: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)
	)
	var restore_path: String = _find_transaction_sidecar_for_target(
		target_path,
		"restore"
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed, "ok"))
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed, "recovery_required")
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_ROLLBACK
	)
	assert_false(restore_path.is_empty())
	if restore_path.is_empty():
		return
	assert_true(FileAccess.file_exists(restore_path))
	assert_eq(
		_read_text(target_path),
		"after",
		"restore working copy 不完整时不得先删除权威目标。"
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			failed,
			"recovery_transaction"
		)
	)

	var recovered: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(recovery_transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(recovered, "ok"))
	assert_eq(_read_text(target_path), "before")
	assert_false(FileAccess.file_exists(restore_path))
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
	if first_backup_path.is_empty() or second_backup_path.is_empty():
		return
	var second_backup_absolute: String = ProjectSettings.globalize_path(
		second_backup_path
	)
	assert_true(_is_path_inside_temp_root(second_backup_absolute))
	if not _is_path_inside_temp_root(second_backup_absolute):
		return
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


func test_failed_owned_write_reports_cleanup_and_refuses_replacement_delete() -> void:
	var target_path: String = _temp_root.path_join("owned-target.bin")
	var staging_owner_id: String = "0".repeat(32)
	var staging_path: String = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._make_sidecar_path(
			target_path,
			"staging",
			staging_owner_id,
			0
		)
	)
	_write_bytes(staging_path, PackedByteArray([1, 2, 3]))
	assert_true(FileAccess.file_exists(staging_path))
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		0,
		0,
		1
	)
	var write_report: Dictionary = {}

	var resolved_error: Error = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._resolve_owned_write_failure(
			staging_path,
			ERR_FILE_CANT_WRITE,
			write_report
		)
	)

	assert_eq(
		resolved_error,
		ERR_CANT_CREATE,
		"cleanup 失败必须成为主返回错误，不能被原 write error 吞掉。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"write_error"
		),
		ERR_FILE_CANT_WRITE
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"cleanup_error"
		),
		ERR_CANT_CREATE
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			write_report,
			"state"
		),
		&"partial"
	)
	var recovery_entry: Dictionary = {
		"target_path": target_path,
		"staging_path": staging_path,
		"staging_owner_id": staging_owner_id,
		"staging_owner_index": 0,
	}
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._apply_owned_write_report(
		recovery_entry,
		"staging",
		write_report
	)
	_write_bytes(staging_path, PackedByteArray([9, 9, 9]))
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._reset_test_owned_write_failures()

	var replacement_cleanup_error: Error = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._remove_owned_partial_sidecar(
			recovery_entry,
			"staging"
		)
	)

	assert_eq(replacement_cleanup_error, ERR_FILE_CORRUPT)
	assert_eq(
		_read_bytes(staging_path),
		PackedByteArray([9, 9, 9]),
		"sidecar 路径被 replacement 占用后必须保留未知文件。"
	)
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path)),
		OK
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(staging_path)
		),
		OK
	)
	assert_eq(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._remove_owned_partial_sidecar(
			recovery_entry,
			"staging"
		),
		ERR_UNAUTHORIZED,
		"同名目录碰撞不得被当作 sidecar 已缺失。"
	)
	assert_true(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(staging_path)
		),
		"fail-closed cleanup 必须保留未知目录。"
	)
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path)),
		OK
	)
	assert_eq(
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._remove_owned_partial_sidecar(
			recovery_entry,
			"staging"
		),
		OK,
		"调用方清除 identity drift 后，恢复所有权应可完成收口。"
	)


func test_begin_partial_backup_cleanup_failure_returns_complete_recovery() -> void:
	var target_path: String = _temp_root.path_join("partial-backup.txt")
	_write_text(target_path, "before")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		1,
		0,
		2
	)

	var failed_begin: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			failed_begin,
			"recovery_transaction"
		)
	)
	var partial_backup_path: String = _find_transaction_sidecar_for_target(
		target_path,
		"backup"
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed_begin, "ok"))
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			failed_begin,
			"recovery_required"
		),
		"partial backup 即时删除失败后必须保留 complete recovery。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed_begin,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	assert_false(partial_backup_path.is_empty())
	if partial_backup_path.is_empty():
		return
	assert_true(FileAccess.file_exists(partial_backup_path))

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(recovery_transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_false(FileAccess.file_exists(partial_backup_path))
	assert_eq(_read_text(target_path), "before")


func test_commit_snapshot_failure_preserves_begin_complete_recovery() -> void:
	var target_path: String = _temp_root.path_join("commit-partial-backup.txt")
	_write_text(target_path, "before")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		1,
		0,
		2
	)

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		[
			_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
				target_path,
				"after"
			),
		],
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
		}
	)
	_assert_closed_commit_shape(report)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			report,
			"recovery_transaction"
		)
	)
	var partial_backup_path: String = _find_transaction_sidecar_for_target(
		target_path,
		"backup"
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"snapshot_failed"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "recovery_required"),
		"commit 必须透传 begin snapshot failure 的恢复所有权。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			report,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	assert_false(partial_backup_path.is_empty())
	if partial_backup_path.is_empty():
		return
	assert_true(FileAccess.file_exists(partial_backup_path))
	assert_eq(_read_text(target_path), "before")

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(recovery_transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_false(FileAccess.file_exists(partial_backup_path))
	assert_eq(_read_text(target_path), "before")


func test_partial_backup_recovery_refuses_identity_drift() -> void:
	var target_path: String = _temp_root.path_join("partial-backup-drift.txt")
	_write_text(target_path, "before")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		1,
		0,
		2
	)
	var failed_begin: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			failed_begin,
			"recovery_transaction"
		)
	)
	var partial_backup_path: String = _find_transaction_sidecar_for_target(
		target_path,
		"backup"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			failed_begin,
			"recovery_required"
		)
	)
	assert_false(partial_backup_path.is_empty())
	if partial_backup_path.is_empty():
		return
	_write_text(partial_backup_path, "changed-after-failure")

	var refused_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(recovery_transaction)
	)

	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(refused_report, "ok"),
		"partial sidecar 身份漂移后 complete 不得删除未知字节。"
	)
	assert_true(FileAccess.file_exists(partial_backup_path))
	assert_eq(_read_text(partial_backup_path), "changed-after-failure")
	_remove_absolute_path(ProjectSettings.globalize_path(partial_backup_path))
	var retry_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			refused_report,
			"recovery_transaction"
		)
	)
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(retry_transaction)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"调用方移除未知碰撞后，complete 应能终结 cleanup obligation。"
	)
	assert_eq(_read_text(target_path), "before")


func test_staging_partial_cleanup_failure_returns_complete_recovery() -> void:
	var target_path: String = _temp_root.path_join("partial-staging.txt")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		0,
		1,
		2
	)

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		[
			_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
				target_path,
				"staged"
			),
		],
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
			"metadata": {
				"owner": self,
				"private_path": "C:/private/project/secret.json",
			},
		}
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			report,
			"recovery_transaction"
		)
	)
	var partial_staging_path: String = _find_transaction_sidecar_for_target(
		target_path,
		"staging"
	)
	var recovery_metadata: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			recovery_transaction,
			"metadata"
		)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"staging_failed"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "recovery_required"),
		"partial staging 清理失败后不得遗留无主 sidecar。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			report,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	assert_false(partial_staging_path.is_empty())
	if partial_staging_path.is_empty():
		return
	assert_true(FileAccess.file_exists(partial_staging_path))
	assert_ne(
		JSON.stringify(recovery_metadata).find("__gf_report_value__"),
		-1,
		"staging cleanup recovery handle 不得泄漏运行时 Object。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			recovery_metadata,
			"private_path"
		),
		"secret.json",
		"staging cleanup recovery handle 中的路径 metadata 必须只保留 basename。"
	)
	assert_eq(
		JSON.stringify(recovery_transaction).find("C:/private/project"),
		-1,
		"恢复句柄不得保留调用方的完整私有路径。"
	)

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(recovery_transaction)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_false(FileAccess.file_exists(partial_staging_path))
	assert_false(FileAccess.file_exists(target_path))


func test_commit_accepts_portable_255_byte_target_leaf() -> void:
	var target_leaf: String = "%s.bin" % "a".repeat(251)
	var target_path: String = _temp_root.path_join(target_leaf)
	var payload: PackedByteArray = PackedByteArray([2, 5, 5])
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_bytes_entry(
			target_path,
			payload
		),
	]

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
		}
	)

	assert_eq(target_leaf.to_utf8_buffer().size(), 255)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"),
		"合法的 255-byte 目标 leaf 不应被内部 sidecar 后缀挤出文件系统边界。"
	)
	assert_eq(_read_bytes(target_path), payload)
	assert_eq(_count_transaction_sidecars(), 0)


func test_complete_staging_cleanup_failure_retains_recovery_ownership() -> void:
	var source_path: String = _temp_root.path_join("source.bin")
	var copied_target_path: String = _temp_root.path_join("copied.bin")
	var failed_target_path: String = _temp_root.path_join("failed.txt")
	_write_bytes(source_path, PackedByteArray([1, 2, 3, 4]))
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		0,
		1,
		2
	)
	var entries: Array[Dictionary] = [
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_file_entry(
			copied_target_path,
			source_path
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_text_entry(
			failed_target_path,
			"fail after write"
		),
	]

	var report: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(
		entries,
		{
			"allowed_roots": [_temp_root],
			"scan_filesystem": false,
		}
	)
	var recovery_transaction: Dictionary = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			report,
			"recovery_transaction"
		)
	)
	var complete_staging_path: String = (
		_find_transaction_sidecar_for_target(
			copied_target_path,
			"staging"
		)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "status"),
		"staging_failed"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			report,
			"recovery_required"
		),
		"完整 staging 删除失败也必须保留结构化 cleanup 所有权。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			report,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	assert_false(complete_staging_path.is_empty())
	if complete_staging_path.is_empty():
		return
	assert_true(FileAccess.file_exists(complete_staging_path))
	assert_false(FileAccess.file_exists(copied_target_path))
	assert_false(FileAccess.file_exists(failed_target_path))

	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(
			recovery_transaction
		)
	)

	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_false(FileAccess.file_exists(complete_staging_path))
	assert_true(FileAccess.file_exists(source_path))
	assert_eq(_count_transaction_sidecars(), 0)


func test_staging_cleanup_recovery_retains_only_cleanup_metadata() -> void:
	var target_path: String = _temp_root.path_join("bounded-recovery.txt")
	var owner_id: String = "a".repeat(32)
	var cleanup_entry: Dictionary = _make_complete_staging_cleanup_entry(
		target_path,
		"bounded recovery",
		owner_id
	)
	cleanup_entry["resolved_bytes"] = PackedByteArray([1, 2, 3, 4])
	cleanup_entry["resolved_source_path"] = "user://must-not-be-retained.bin"
	cleanup_entry["metadata"] = {
		"must_not_be_retained": PackedByteArray([5, 6, 7, 8]),
	}
	var recovery_transaction: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._register_staging_sidecar_cleanup(
			[cleanup_entry],
			{},
			"b".repeat(32)
		)
	)

	assert_false(recovery_transaction.is_empty())
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		recovery_transaction,
		"transaction_id"
	)
	var active_state: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._active_transactions[
			transaction_id
		]
	)
	var registered_entries: Array[Dictionary] = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._get_staging_cleanup_entries(
			active_state
		)
	)
	assert_eq(registered_entries.size(), 1)
	var registered_entry: Dictionary = registered_entries[0]
	assert_false(registered_entry.has("resolved_bytes"))
	assert_false(registered_entry.has("resolved_source_path"))
	assert_false(registered_entry.has("metadata"))
	var expected_keys: PackedStringArray = PackedStringArray([
		"content_sha256",
		"size_bytes",
		"staging_owner_id",
		"staging_owner_index",
		"staging_partial_identity_known",
		"staging_partial_sha256",
		"staging_partial_size_bytes",
		"staging_path",
		"staging_write_state",
		"target_path",
	])
	var actual_keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in registered_entry.keys():
		if not key_value is String:
			fail_test("staging cleanup recovery keys must be Strings.")
			continue
		var key: String = key_value
		var _key_appended: bool = actual_keys.append(key)
	actual_keys.sort()
	expected_keys.sort()
	assert_eq(actual_keys, expected_keys)

	var complete_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(
			recovery_transaction
		)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(complete_report, "ok"))
	assert_eq(_count_transaction_sidecars(), 0)


func test_complete_consumes_attached_staging_cleanup_with_retry() -> void:
	var target_path: String = _temp_root.path_join("complete-target.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	var cleanup_entry: Dictionary = _make_complete_staging_cleanup_entry(
		target_path,
		"complete-sidecar",
		"b".repeat(32)
	)
	var cleanup_entries: Array[Dictionary] = [cleanup_entry]
	var attached: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._register_staging_sidecar_cleanup(
			cleanup_entries,
			{},
			"c".repeat(32),
			transaction
		)
	)
	var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		cleanup_entry,
		"staging_path"
	)
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		0,
		0,
		1
	)

	var failed: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(attached)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed, "ok"))
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(failed, "status"),
		"cleanup_failed"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_COMPLETE
	)
	assert_true(FileAccess.file_exists(staging_path))
	_write_text(staging_path, "foreign replacement")
	var drifted: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				failed,
				"recovery_transaction"
			)
		)
	)
	assert_false(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(drifted, "ok"),
		"complete staging identity 漂移后不得删除未知文件。"
	)
	assert_eq(_read_text(staging_path), "foreign replacement")
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path)),
		OK
	)
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				drifted,
				"recovery_transaction"
			)
		)
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"),
		"调用方移除 complete staging collision 后必须可幂等完成 cleanup。"
	)
	assert_eq(_read_text(target_path), "before")
	assert_eq(_count_transaction_sidecars(), 0)


func test_rollback_consumes_attached_staging_cleanup_with_retry() -> void:
	var target_path: String = _temp_root.path_join("rollback-target.txt")
	_write_text(target_path, "before")
	var transaction: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(
		PackedStringArray([target_path]),
		{ "allowed_roots": [_temp_root] }
	)
	var cleanup_entry: Dictionary = _make_complete_staging_cleanup_entry(
		target_path,
		"rollback-sidecar",
		"d".repeat(32)
	)
	var cleanup_entries: Array[Dictionary] = [cleanup_entry]
	var attached: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._register_staging_sidecar_cleanup(
			cleanup_entries,
			{},
			"e".repeat(32),
			transaction
		)
	)
	var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		cleanup_entry,
		"staging_path"
	)
	_write_text(target_path, "after")
	_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._configure_test_owned_write_failures(
		0,
		0,
		1
	)

	var failed: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(attached)
	)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(failed, "ok"))
	assert_eq(_read_text(target_path), "before")
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			failed,
			"recovery_action"
		),
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.RECOVERY_ACTION_ROLLBACK
	)
	assert_true(
		FileAccess.file_exists(staging_path),
		"rollback cleanup 失败后必须保留 staging obligation。"
	)
	var retry_report: Dictionary = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				failed,
				"recovery_transaction"
			)
		)
	)
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(retry_report, "ok"))
	assert_eq(_read_text(target_path), "before")
	assert_eq(_count_transaction_sidecars(), 0)


# --- 私有/辅助方法 ---

func _make_complete_staging_cleanup_entry(
	target_path: String,
	content: String,
	owner_id: String
) -> Dictionary:
	var staging_path: String = (
		_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT._make_sidecar_path(
			target_path,
			"staging",
			owner_id,
			0
		)
	)
	_write_text(staging_path, content)
	return {
		"target_path": target_path,
		"staging_path": staging_path,
		"staging_owner_id": owner_id,
		"staging_owner_index": 0,
		"staging_write_state": &"complete",
		"size_bytes": content.to_utf8_buffer().size(),
		"content_sha256": FileAccess.get_sha256(staging_path).to_lower(),
	}


func _assert_closed_commit_shape(report: Dictionary) -> void:
	var actual_keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in report.keys():
		if not key_value is String:
			fail_test("commit report keys must be Strings.")
			continue
		var key: String = key_value
		var _key_appended: bool = actual_keys.append(key)
	actual_keys.sort()
	var expected_keys: PackedStringArray = PackedStringArray([
		"backup_bytes",
		"entry_count",
		"issues",
		"metadata",
		"ok",
		"recovery_action",
		"recovery_required",
		"recovery_transaction",
		"reports",
		"rollback_complete",
		"rolled_back",
		"status",
		"total_bytes",
		"unchanged_count",
		"written_count",
	])
	expected_keys.sort()
	assert_eq(
		actual_keys,
		expected_keys,
		"commit success/failure must preserve one closed boundary shape."
	)


func _assert_closed_begin_shape(report: Dictionary) -> void:
	var actual_keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in report.keys():
		if not key_value is String:
			fail_test("begin report keys must be Strings.")
			continue
		var key: String = key_value
		var _key_appended: bool = actual_keys.append(key)
	actual_keys.sort()
	var expected_keys: PackedStringArray = PackedStringArray([
		"backup_bytes",
		"entry_count",
		"format",
		"format_version",
		"issues",
		"metadata",
		"ok",
		"recovery_action",
		"recovery_required",
		"recovery_transaction",
		"state",
		"transaction_id",
		"transaction_token",
	])
	expected_keys.sort()
	assert_eq(
		actual_keys,
		expected_keys,
		"begin success/failure must preserve one closed boundary shape."
	)


func _write_text(path: String, text: String) -> void:
	_write_bytes(path, text.to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	assert_true(
		_is_path_inside_temp_root(absolute_path),
		"测试写入路径必须位于当前临时根目录内。"
	)
	if not _is_path_inside_temp_root(absolute_path):
		return
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
	var target_hash: String = _sha256_text(target_path)
	var absolute_path: String = _find_matching_file(
		absolute_target_path.get_base_dir(),
		".gf-artifact-%s-%s-" % [
			kind,
			target_hash,
		]
	)
	if absolute_path.is_empty():
		return ""
	return ProjectSettings.localize_path(absolute_path)


func _sha256_text(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(text.to_utf8_buffer())
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


func _find_matching_file(path: String, needle: String) -> String:
	if not _is_path_inside_temp_root(path, true):
		return ""
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return ""
	directory.include_hidden = true
	directory.include_navigational = false
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return ""
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = path.path_join(entry_name)
			var entry_is_link: bool = directory.is_link(entry_name)
			if directory.current_is_dir() and not entry_is_link:
				var nested_match: String = _find_matching_file(
					entry_path,
					needle
				)
				if not nested_match.is_empty():
					directory.list_dir_end()
					return nested_match
			elif not entry_is_link and entry_name.contains(needle):
				directory.list_dir_end()
				return entry_path
		entry_name = directory.get_next()
	directory.list_dir_end()
	return ""


func _count_matching_files(path: String, needle: String) -> int:
	if not _is_path_inside_temp_root(path, true):
		return 0
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return 0
	directory.include_hidden = true
	directory.include_navigational = false
	var count: int = 0
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return 0
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = path.path_join(entry_name)
			var entry_is_link: bool = directory.is_link(entry_name)
			if directory.current_is_dir() and not entry_is_link:
				count += _count_matching_files(entry_path, needle)
			elif not entry_is_link and entry_name.contains(needle):
				count += 1
		entry_name = directory.get_next()
	directory.list_dir_end()
	return count


func _remove_absolute_path(
	path: String,
	allow_temp_root: bool = false
) -> void:
	if not _is_path_inside_temp_root(path, allow_temp_root, true):
		fail_test(
			"拒绝清理当前测试临时根目录以外的路径：%s" % path
		)
		return
	if _absolute_path_is_link(path):
		var remove_link_result: Error = DirAccess.remove_absolute(path)
		assert_eq(
			remove_link_result,
			OK,
			"测试清理必须成功 unlink 临时目录内的链接。"
		)
		return
	if FileAccess.file_exists(path):
		var _remove_file_result: Error = DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.include_navigational = false
	var child_paths: PackedStringArray = PackedStringArray()
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		fail_test("无法枚举测试清理目录：%s" % path)
		return
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var _append_result: bool = child_paths.append(
				path.path_join(entry_name)
			)
		entry_name = directory.get_next()
	directory.list_dir_end()
	for child_path: String in child_paths:
		_remove_absolute_path(child_path)
	var _remove_directory_result: Error = DirAccess.remove_absolute(path)


func _is_path_inside_temp_root(
	path: String,
	allow_temp_root: bool = false,
	allow_leaf_link: bool = false
) -> bool:
	if path.is_empty() or _temp_root.is_empty():
		return false
	var normalized_path: String = _normalize_cleanup_path(path)
	var normalized_temp_root: String = _normalize_cleanup_path(
		ProjectSettings.globalize_path(_temp_root)
	)
	if normalized_path.is_empty() or normalized_temp_root.is_empty():
		return false
	if normalized_path == normalized_temp_root:
		return (
			allow_temp_root
			and not _path_has_link_from_temp_root(
				normalized_path,
				allow_leaf_link
			)
		)
	if not normalized_path.begins_with(normalized_temp_root + "/"):
		return false
	return not _path_has_link_from_temp_root(
		normalized_path,
		allow_leaf_link
	)


func _path_has_link_from_temp_root(
	normalized_path: String,
	allow_leaf_link: bool
) -> bool:
	var normalized_temp_root: String = _normalize_cleanup_path(
		ProjectSettings.globalize_path(_temp_root)
	)
	var current_path: String = normalized_path
	if allow_leaf_link:
		if current_path == normalized_temp_root:
			return false
		current_path = _normalize_cleanup_path(current_path.get_base_dir())
	while not current_path.is_empty():
		if _absolute_path_is_link(current_path):
			return true
		if current_path == normalized_temp_root:
			return false
		var parent_path: String = _normalize_cleanup_path(
			current_path.get_base_dir()
		)
		if parent_path.is_empty() or parent_path == current_path:
			return true
		current_path = parent_path
	return true


func _normalize_cleanup_path(path: String) -> String:
	var normalized_path: String = path.simplify_path().replace("\\", "/")
	while normalized_path.length() > 1 and normalized_path.ends_with("/"):
		normalized_path = normalized_path.trim_suffix("/")
	if OS.has_feature("windows"):
		return normalized_path.to_lower()
	return normalized_path


func _absolute_path_is_link(path: String) -> bool:
	var parent_path: String = path.get_base_dir()
	var entry_name: String = path.get_file()
	if parent_path.is_empty() or entry_name.is_empty():
		return false
	var parent_directory: DirAccess = DirAccess.open(parent_path)
	if parent_directory == null:
		return false
	return parent_directory.is_link(entry_name)
