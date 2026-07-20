@tool

## GF Package 文件事务引擎。
##
## 该内部引擎以写前 journal、持久备份和幂等恢复统一提交 package payload 与 lockfile。
## planner、registry source、archive staging 和结果展示不属于这个类型的职责。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/package
class_name GFPackageTransactionEngine
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _SCHEMA_CONTRACT_PATH: String = "res://addons/gf/kernel/package/gf_package_transaction_schema.json"
const _SCHEMA_VERSION: int = 1
const _REPORT_SCHEMA_VERSION: int = 1
const _COPY_CHUNK_BYTES: int = 1024 * 1024
const _TRANSACTION_ROOT_RELATIVE_PATH: String = ".gf/package_transactions"
const _ACTIVE_DIRECTORY_NAME: String = "active"
const _CANDIDATE_PREFIX: String = "candidate-"
const _CLEANUP_PREFIX: String = "cleanup-"
const _JOURNAL_PREFIX: String = "journal-"
const _JOURNAL_SUFFIX: String = ".json"
const _JOURNAL_TEMP_SUFFIX: String = ".tmp"
const _LOCKFILE_ORIGINAL_NAME: String = "lockfile-original.json"
const _LOCKFILE_PLANNED_NAME: String = "lockfile-planned.json"
const _BACKUP_DIRECTORY_NAME: String = "backups"
const _PACKAGE_ROOT_PREFIX: String = "addons/" + "gf/"
const _PHASE_PREPARING: String = "preparing"
const _PHASE_PREPARED: String = "prepared"
const _PHASE_APPLYING: String = "applying_payload"
const _PHASE_PAYLOAD_APPLIED: String = "payload_applied"
const _PHASE_COMMITTING: String = "committing_lockfile"
const _PHASE_COMMITTED: String = "committed"
const _PHASE_ROLLING_BACK: String = "rolling_back"
const _PHASE_RECOVERY_FAILED: String = "recovery_failed"
const _OUTCOME_NONE: String = "none"
const _OUTCOME_COMMITTED: String = "committed"
const _OUTCOME_ROLLED_BACK: String = "rolled_back"
const _OUTCOME_PENDING_RECOVERY: String = "pending_recovery"
const _OUTCOME_RECOVERED_COMMIT: String = "recovered_commit"
const _OUTCOME_RECOVERED_ROLLBACK: String = "recovered_rollback"
const _OUTCOME_RECOVERED_ABANDONED: String = "recovered_abandoned"
const _OUTCOME_BLOCKED: String = "blocked"
const _OUTCOME_RECOVERY_FAILED: String = "recovery_failed"
const _CANCELLED_ISSUE: String = "Package manager operation was cancelled."


# --- 公共方法 ---

## 构造事务引擎请求。
## [br]
## @api framework_internal
## [br]
## @param operation: install、update、uninstall 或 lockfile_only。
## [br]
## @param project_root: 目标项目绝对路径或 res:// 路径。
## [br]
## @param lockfile_path: 项目根目录内的 lockfile 绝对路径。
## [br]
## @param planned_lockfile: 提交后的完整 lockfile 数据。
## [br]
## @schema planned_lockfile: Dictionary，必须是可写入 JSON 的 lockfile 根对象。
## [br]
## @param writes: 待写入文件。
## [br]
## @schema writes: Array[Dictionary]，每项包含 relative_path 与 source_path。
## [br]
## @param deletes: 待删除文件。
## [br]
## @schema deletes: Array[Dictionary]，每项包含 relative_path。
## [br]
## @param cleanup_paths: 事务结束或恢复后可清理的项目 .gf 临时目录。
## [br]
## @schema cleanup_paths: String 数组，路径必须位于 project_root/.gf 内。
## [br]
## @return 版本化事务请求。
## [br]
## @schema return: Dictionary，包含 schema_version、operation、project_root、lockfile_path、planned_lockfile、writes、deletes、cleanup_paths。
static func make_request(
	operation: String,
	project_root: String,
	lockfile_path: String,
	planned_lockfile: Dictionary,
	writes: Array[Dictionary] = [],
	deletes: Array[Dictionary] = [],
	cleanup_paths: PackedStringArray = PackedStringArray()
) -> Dictionary:
	return {
		"schema_version": _SCHEMA_VERSION,
		"operation": operation,
		"project_root": project_root,
		"lockfile_path": lockfile_path,
		"planned_lockfile": planned_lockfile.duplicate(true),
		"writes": writes.duplicate(true),
		"deletes": deletes.duplicate(true),
		"cleanup_paths": _packed_to_array(cleanup_paths),
	}


## 执行一个完整 package 文件事务。
## [br]
## @api framework_internal
## [br]
## @param request: make_request() 创建的事务请求。
## [br]
## @schema request: Package transaction request schema version 1。
## [br]
## @param options: 内部取消与故障注入选项。
## [br]
## @schema options: Dictionary，可包含 cancel_callback、cancel_requested、simulate_copy_failure_after、simulate_delete_failure_after、simulate_transaction_failure_at、simulate_transaction_crash_at。
## [br]
## @return 版本化事务报告。
## [br]
## @schema return: Dictionary，包含 schema_version、ok、transaction_id、operation、phase、outcome、write_count、delete_count、lockfile_written、rolled_back、recovered、recovery_required、issues、warnings。
static func execute(request: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var normalized_request: Dictionary = _normalize_request(request, issues)
	var operation: String = _GF_VARIANT_ACCESS.get_option_string(normalized_request, "operation")
	if not issues.is_empty():
		return _make_report(false, "", operation, "", _OUTCOME_BLOCKED, 0, 0, false, false, false, false, issues)
	if _append_cancelled_if_requested(options, issues):
		return _make_report(false, "", operation, "", _OUTCOME_ROLLED_BACK, 0, 0, false, false, false, false, issues)

	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(normalized_request, "project_root")
	var recovery: Dictionary = recover_pending(project_root)
	if not _GF_VARIANT_ACCESS.get_option_bool(recovery, "ok", false):
		_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(recovery, "issues"))
		return _make_report(false, "", operation, "", _OUTCOME_BLOCKED, 0, 0, false, false, false, true, issues)

	var claim: Dictionary = _claim_transaction(normalized_request, issues)
	if not _GF_VARIANT_ACCESS.get_option_bool(claim, "ok", false):
		return _make_report(false, "", operation, "", _OUTCOME_BLOCKED, 0, 0, false, false, false, true, issues)

	var active_root: String = _GF_VARIANT_ACCESS.get_option_string(claim, "active_root")
	var journal: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(claim, "journal")
	var transaction_id: String = _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id")
	if not _prepare_transaction(active_root, journal, normalized_request, issues):
		var cleanup_issues: PackedStringArray = PackedStringArray()
		var preparation_cleanup_ok: bool = _cleanup_active_transaction(active_root, journal, cleanup_issues)
		_append_string_array(issues, cleanup_issues)
		if not preparation_cleanup_ok:
			_mark_abandoned(active_root, journal)
		return _make_report(false, transaction_id, operation, _GF_VARIANT_ACCESS.get_option_string(journal, "phase"), _OUTCOME_ROLLED_BACK, 0, 0, false, preparation_cleanup_ok, false, not preparation_cleanup_ok, issues)

	if _should_inject_crash(options, "after_prepared"):
		_mark_abandoned(active_root, journal)
		return _make_report(false, transaction_id, operation, _PHASE_PREPARED, _OUTCOME_PENDING_RECOVERY, 0, 0, false, false, false, true, issues)
	if _append_cancelled_if_requested(options, issues):
		return _rollback_after_failure(active_root, journal, operation, 0, 0, issues)

	if not _write_phase(active_root, journal, _PHASE_APPLYING, issues):
		return _rollback_after_failure(active_root, journal, operation, 0, 0, issues)
	var apply_result: Dictionary = _apply_payload(journal, normalized_request, options)
	var write_count: int = _GF_VARIANT_ACCESS.get_option_int(apply_result, "write_count")
	var delete_count: int = _GF_VARIANT_ACCESS.get_option_int(apply_result, "delete_count")
	_append_string_array(issues, _GF_VARIANT_ACCESS.get_option_packed_string_array(apply_result, "issues"))
	if not _GF_VARIANT_ACCESS.get_option_bool(apply_result, "ok", false):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if not _write_phase(active_root, journal, _PHASE_PAYLOAD_APPLIED, issues):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)

	if _should_inject_crash(options, "after_payload_applied"):
		_mark_abandoned(active_root, journal)
		return _make_report(false, transaction_id, operation, _PHASE_PAYLOAD_APPLIED, _OUTCOME_PENDING_RECOVERY, write_count, delete_count, false, false, false, true, issues)
	if _append_cancelled_if_requested(options, issues):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if not _write_phase(active_root, journal, _PHASE_COMMITTING, issues):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if _should_inject_failure(options, "before_lockfile_replace"):
		var _append_failure: bool = issues.append("Simulated package transaction failure before lockfile replace.")
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if not _commit_lockfile(active_root, journal, issues):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if _should_inject_crash(options, "after_lockfile_replace"):
		_mark_abandoned(active_root, journal)
		return _make_report(false, transaction_id, operation, _PHASE_COMMITTING, _OUTCOME_PENDING_RECOVERY, write_count, delete_count, true, false, false, true, issues)
	if not _write_phase(active_root, journal, _PHASE_COMMITTED, issues):
		return _rollback_after_failure(active_root, journal, operation, write_count, delete_count, issues)
	if _should_inject_crash(options, "after_lockfile_committed"):
		_mark_abandoned(active_root, journal)
		return _make_report(false, transaction_id, operation, _PHASE_COMMITTED, _OUTCOME_PENDING_RECOVERY, write_count, delete_count, true, false, false, true, issues)

	var cleanup_warnings: PackedStringArray = PackedStringArray()
	var cleanup_ok: bool = _cleanup_active_transaction(active_root, journal, cleanup_warnings)
	return _make_report(true, transaction_id, operation, _PHASE_COMMITTED, _OUTCOME_COMMITTED, write_count, delete_count, true, false, false, not cleanup_ok, issues, cleanup_warnings)


## 恢复或收尾项目中遗留的 package 文件事务。
## [br]
## @api framework_internal
## [br]
## @param project_root: 目标项目绝对路径或 res:// 路径。
## [br]
## @param options: 内部恢复选项。
## [br]
## @schema options: Dictionary；测试可传 force_recovery_current_process。
## [br]
## @return 版本化事务恢复报告。
## [br]
## @schema return: 与 execute() 相同的事务报告 schema。
static func recover_pending(project_root: String, options: Dictionary = {}) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var normalized_root: String = _normalize_project_root(project_root)
	if normalized_root.is_empty() or _path_has_link_component(normalized_root):
		var _append_root: bool = issues.append("Package transaction project root is invalid: %s" % project_root)
		return _make_report(false, "", "recover", "", _OUTCOME_BLOCKED, 0, 0, false, false, false, true, issues)
	if FileAccess.file_exists(normalized_root):
		var _append_root_file: bool = issues.append("Package transaction project root is not a directory: %s" % project_root)
		return _make_report(false, "", "recover", "", _OUTCOME_BLOCKED, 0, 0, false, false, false, true, issues)
	if not DirAccess.dir_exists_absolute(normalized_root):
		return make_empty_report("recover")

	var transaction_root: String = _transaction_root(normalized_root)
	if _path_has_link_component(transaction_root):
		var _append_transaction_link: bool = issues.append("Package transaction directory crosses a filesystem link: %s" % transaction_root)
		return _make_report(false, "", "recover", "", _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)
	if _path_exists(transaction_root) and not DirAccess.dir_exists_absolute(transaction_root):
		var _append_transaction_type: bool = issues.append("Package transaction path is not a directory: %s" % transaction_root)
		return _make_report(false, "", "recover", "", _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)
	if not _cleanup_abandoned_candidates(transaction_root, issues, normalized_root):
		return _make_report(false, "", "recover", "", _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)
	var active_root: String = transaction_root.path_join(_ACTIVE_DIRECTORY_NAME)
	if not _path_exists(active_root):
		return make_empty_report("recover")
	if not DirAccess.dir_exists_absolute(active_root) or _path_has_link_component(active_root):
		var _append_active_path: bool = issues.append("Active package transaction path is not a safe directory: %s" % active_root)
		return _make_report(false, "", "recover", "", _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)

	var journal: Dictionary = _read_latest_journal(active_root, issues, normalized_root)
	if journal.is_empty():
		if issues.is_empty():
			var _append_missing: bool = issues.append("Package transaction directory exists without a valid journal: %s" % active_root)
		return _make_report(false, "", "recover", "", _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)
	var transaction_id: String = _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id")
	var operation: String = _GF_VARIANT_ACCESS.get_option_string(journal, "operation")
	var phase: String = _GF_VARIANT_ACCESS.get_option_string(journal, "phase")
	if _normalize_project_root(_GF_VARIANT_ACCESS.get_option_string(journal, "project_root")) != normalized_root:
		var _append_mismatch: bool = issues.append("Package transaction journal project root does not match the requested project.")
		return _make_report(false, transaction_id, operation, phase, _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, false, true, issues)
	if _transaction_owner_is_running(journal) and not _GF_VARIANT_ACCESS.get_option_bool(options, "force_recovery_current_process", false):
		var _append_active: bool = issues.append("Another live process owns the active package transaction: %s" % transaction_id)
		return _make_report(false, transaction_id, operation, phase, _OUTCOME_BLOCKED, 0, 0, false, false, false, true, issues)

	var write_count: int = _GF_VARIANT_ACCESS.get_option_array(journal, "writes").size()
	var delete_count: int = _GF_VARIANT_ACCESS.get_option_array(journal, "deletes").size()
	if phase == _PHASE_PREPARING:
		var cleanup_ok: bool = _cleanup_active_transaction(active_root, journal, issues)
		return _make_report(cleanup_ok, transaction_id, operation, phase, _OUTCOME_RECOVERED_ABANDONED if cleanup_ok else _OUTCOME_RECOVERY_FAILED, 0, 0, false, false, true, not cleanup_ok, issues)

	var recovery_warnings: PackedStringArray = PackedStringArray()
	if phase == _PHASE_COMMITTED:
		var committed_verify_issues: PackedStringArray = PackedStringArray()
		if _verify_committed_state(journal, committed_verify_issues):
			var committed_cleanup_ok: bool = _cleanup_active_transaction(active_root, journal, issues)
			return _make_report(committed_cleanup_ok, transaction_id, operation, phase, _OUTCOME_RECOVERED_COMMIT if committed_cleanup_ok else _OUTCOME_RECOVERY_FAILED, write_count, delete_count, true, false, true, not committed_cleanup_ok, issues)
		_append_string_array(recovery_warnings, committed_verify_issues)

	var rollback_issues: PackedStringArray = PackedStringArray()
	var rollback_ok: bool = _rollback_state(active_root, journal, rollback_issues)
	_append_string_array(issues, rollback_issues)
	if rollback_ok:
		var cleanup_ok: bool = _cleanup_active_transaction(active_root, journal, issues)
		rollback_ok = cleanup_ok
	else:
		var phase_issues: PackedStringArray = PackedStringArray()
		var _phase_written: bool = _write_phase(active_root, journal, _PHASE_RECOVERY_FAILED, phase_issues)
		_append_string_array(issues, phase_issues)
	return _make_report(rollback_ok, transaction_id, operation, phase, _OUTCOME_RECOVERED_ROLLBACK if rollback_ok else _OUTCOME_RECOVERY_FAILED, write_count, delete_count, false, rollback_ok, true, not rollback_ok, issues, recovery_warnings)


## 创建无活动事务的稳定报告。
## [br]
## @api framework_internal
## [br]
## @param operation: 报告所属操作名。
## [br]
## @return 版本化空事务报告。
## [br]
## @schema return: 与 execute() 相同的事务报告 schema，outcome 为 none。
static func make_empty_report(operation: String = "") -> Dictionary:
	return _make_report(true, "", operation, "", _OUTCOME_NONE, 0, 0, false, false, false, false, PackedStringArray())


# --- 私有/辅助方法 ---

static func _normalize_request(request: Dictionary, issues: PackedStringArray) -> Dictionary:
	var schema_contract: Dictionary = _load_schema_contract(issues)
	if schema_contract.is_empty():
		return {}
	for field_name: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "request_required_fields"):
		if not request.has(field_name):
			var _append_field: bool = issues.append("Package transaction request is missing required field: %s" % field_name)
	if _GF_VARIANT_ACCESS.get_option_int(request, "schema_version", 0) != _GF_VARIANT_ACCESS.get_option_int(schema_contract, "schema_version", 0):
		var _append_schema: bool = issues.append("Unsupported package transaction request schema_version.")
		return {}
	var operation: String = _GF_VARIANT_ACCESS.get_option_string(request, "operation").strip_edges()
	if not _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "operations").has(operation):
		var _append_operation: bool = issues.append("Invalid package transaction operation: %s" % operation)
	var project_root: String = _normalize_project_root(_GF_VARIANT_ACCESS.get_option_string(request, "project_root"))
	if project_root.is_empty() or _path_has_link_component(project_root) or FileAccess.file_exists(project_root):
		var _append_project: bool = issues.append("Package transaction project root is invalid.")
	var lockfile_path: String = _normalize_absolute_path(_GF_VARIANT_ACCESS.get_option_string(request, "lockfile_path"))
	if lockfile_path.is_empty() or not _is_path_inside(project_root, lockfile_path):
		var _append_lockfile: bool = issues.append("Package transaction lockfile must stay inside project root: %s" % lockfile_path)
	elif _path_has_link_component(lockfile_path):
		var _append_lockfile_link: bool = issues.append("Package transaction lockfile path crosses a filesystem link: %s" % lockfile_path)
	var transaction_root: String = _transaction_root(project_root)
	if not lockfile_path.is_empty() and _is_path_inside(transaction_root, lockfile_path):
		var _append_internal_lock: bool = issues.append("Package lockfile cannot be stored inside the package transaction directory.")
	var planned_lockfile: Dictionary = _GF_VARIANT_ACCESS.get_option_dictionary(request, "planned_lockfile")

	var normalized_writes: Array[Dictionary] = []
	var normalized_deletes: Array[Dictionary] = []
	var seen_paths: Dictionary = {}
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(request, "writes"):
		if not raw_value is Dictionary:
			var _append_write_type: bool = issues.append("Package transaction write entry must be a Dictionary.")
			continue
		var raw_write: Dictionary = raw_value
		var relative_path: String = _normalize_payload_relative_path(_GF_VARIANT_ACCESS.get_option_string(raw_write, "relative_path"))
		var source_path: String = _normalize_absolute_path(_GF_VARIANT_ACCESS.get_option_string(raw_write, "source_path"))
		if relative_path.is_empty() or source_path.is_empty() or not FileAccess.file_exists(source_path) or _path_has_link_component(source_path):
			var _append_write: bool = issues.append("Invalid package transaction write entry: %s" % _GF_VARIANT_ACCESS.get_option_string(raw_write, "relative_path"))
			continue
		var path_identity: String = _portable_path_identity(relative_path)
		if seen_paths.has(path_identity):
			var _append_duplicate: bool = issues.append("Duplicate package transaction payload path: %s" % relative_path)
			continue
		seen_paths[path_identity] = true
		var target_path: String = project_root.path_join(relative_path).replace("\\", "/").simplify_path()
		if _path_has_link_component(target_path):
			var _append_target_link: bool = issues.append("Package transaction payload target crosses a filesystem link: %s" % relative_path)
		normalized_writes.append({ "relative_path": relative_path, "source_path": source_path })
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(request, "deletes"):
		if not raw_value is Dictionary:
			var _append_delete_type: bool = issues.append("Package transaction delete entry must be a Dictionary.")
			continue
		var raw_delete: Dictionary = raw_value
		var relative_path: String = _normalize_payload_relative_path(_GF_VARIANT_ACCESS.get_option_string(raw_delete, "relative_path"))
		if relative_path.is_empty():
			var _append_delete: bool = issues.append("Invalid package transaction delete entry: %s" % _GF_VARIANT_ACCESS.get_option_string(raw_delete, "relative_path"))
			continue
		var path_identity: String = _portable_path_identity(relative_path)
		if seen_paths.has(path_identity):
			var _append_duplicate: bool = issues.append("Duplicate package transaction payload path: %s" % relative_path)
			continue
		seen_paths[path_identity] = true
		var target_path: String = project_root.path_join(relative_path).replace("\\", "/").simplify_path()
		if _path_has_link_component(target_path):
			var _append_target_link: bool = issues.append("Package transaction payload target crosses a filesystem link: %s" % relative_path)
		normalized_deletes.append({ "relative_path": relative_path })

	var normalized_cleanup_paths: PackedStringArray = PackedStringArray()
	var project_internal_root: String = project_root.path_join(".gf")
	for raw_path: String in _GF_VARIANT_ACCESS.get_option_packed_string_array(request, "cleanup_paths"):
		var cleanup_path: String = _normalize_absolute_path(raw_path)
		if cleanup_path.is_empty() or cleanup_path == project_internal_root or not _is_path_inside(project_internal_root, cleanup_path):
			var _append_cleanup: bool = issues.append("Package transaction cleanup path must stay below project_root/.gf: %s" % raw_path)
			continue
		if _is_path_inside(transaction_root, cleanup_path) or _is_path_inside(cleanup_path, transaction_root):
			var _append_cleanup_transaction: bool = issues.append("Package transaction cleanup path cannot overlap the transaction directory: %s" % raw_path)
			continue
		if _path_has_link_component(cleanup_path):
			var _append_cleanup_link: bool = issues.append("Package transaction cleanup path crosses a filesystem link: %s" % raw_path)
			continue
		if not _packed_array_has_portable_path(normalized_cleanup_paths, cleanup_path):
			var _append_cleanup_path: bool = normalized_cleanup_paths.append(cleanup_path)

	if not issues.is_empty():
		return {}
	return {
		"schema_version": _SCHEMA_VERSION,
		"operation": operation,
		"project_root": project_root,
		"lockfile_path": lockfile_path,
		"planned_lockfile": planned_lockfile.duplicate(true),
		"writes": normalized_writes,
		"deletes": normalized_deletes,
		"cleanup_paths": _packed_to_array(normalized_cleanup_paths),
	}


static func _claim_transaction(request: Dictionary, issues: PackedStringArray) -> Dictionary:
	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(request, "project_root")
	var transaction_root: String = _transaction_root(project_root)
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(transaction_root)
	if make_root_error != OK:
		var _append_root: bool = issues.append("Could not create package transaction root: %s" % error_string(make_root_error))
		return { "ok": false }
	if _path_has_link_component(transaction_root):
		var _append_root_link: bool = issues.append("Package transaction root crosses a filesystem link: %s" % transaction_root)
		return { "ok": false }
	var transaction_id: String = "%d-%d-%d" % [OS.get_process_id(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var candidate_root: String = transaction_root.path_join(_CANDIDATE_PREFIX + transaction_id)
	var make_candidate_error: Error = DirAccess.make_dir_absolute(candidate_root)
	if make_candidate_error != OK:
		var _append_candidate: bool = issues.append("Could not create package transaction candidate: %s" % error_string(make_candidate_error))
		return { "ok": false }
	if _path_has_link_component(candidate_root):
		var _append_candidate_link: bool = issues.append("Package transaction candidate crosses a filesystem link: %s" % candidate_root)
		return { "ok": false }
	var journal: Dictionary = {
		"schema_version": _SCHEMA_VERSION,
		"sequence": -1,
		"transaction_id": transaction_id,
		"operation": _GF_VARIANT_ACCESS.get_option_string(request, "operation"),
		"phase": _PHASE_PREPARING,
		"owner_pid": OS.get_process_id(),
		"project_root": project_root,
		"lockfile_path": _GF_VARIANT_ACCESS.get_option_string(request, "lockfile_path"),
		"lockfile_had_original": false,
		"lockfile_original_sha256": "",
		"lockfile_planned_sha256": "",
		"writes": [],
		"deletes": [],
		"cleanup_paths": _GF_VARIANT_ACCESS.get_option_array(request, "cleanup_paths"),
		"started_unix_time": int(Time.get_unix_time_from_system()),
	}
	if not _write_journal_snapshot(candidate_root, journal, issues):
		var _candidate_removed: bool = _remove_tree(candidate_root, PackedStringArray())
		return { "ok": false }
	var active_root: String = transaction_root.path_join(_ACTIVE_DIRECTORY_NAME)
	if _path_exists(active_root) or _path_has_link_component(active_root):
		var _candidate_removed: bool = _remove_tree(candidate_root, PackedStringArray())
		var _append_active_exists: bool = issues.append("Active package transaction path already exists or is unsafe: %s" % active_root)
		return { "ok": false }
	var claim_error: Error = DirAccess.rename_absolute(candidate_root, active_root)
	if claim_error != OK:
		var _candidate_removed: bool = _remove_tree(candidate_root, PackedStringArray())
		var _append_claim: bool = issues.append("Could not claim package transaction; another transaction may be active: %s" % error_string(claim_error))
		return { "ok": false }
	return { "ok": true, "active_root": active_root, "journal": journal }


static func _prepare_transaction(
	active_root: String,
	journal: Dictionary,
	request: Dictionary,
	issues: PackedStringArray
) -> bool:
	var planned_path: String = active_root.path_join(_LOCKFILE_PLANNED_NAME)
	var planned_text: String = JSON.stringify(_GF_VARIANT_ACCESS.get_option_dictionary(request, "planned_lockfile"), "\t", false) + "\n"
	if not _write_text_file(planned_path, planned_text, issues, "write planned lockfile snapshot"):
		return false
	journal["lockfile_planned_sha256"] = FileAccess.get_sha256(planned_path).to_lower()

	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	var had_original: bool = FileAccess.file_exists(lockfile_path)
	journal["lockfile_had_original"] = had_original
	if had_original:
		var original_path: String = active_root.path_join(_LOCKFILE_ORIGINAL_NAME)
		if not _copy_file(lockfile_path, original_path, issues, "backup original lockfile"):
			return false
		journal["lockfile_original_sha256"] = FileAccess.get_sha256(original_path).to_lower()

	var prepared_writes: Array[Dictionary] = []
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(request, "writes"):
		var write_entry: Dictionary = raw_value
		var prepared: Dictionary = _prepare_payload_entry(active_root, journal, write_entry, "write", issues)
		if prepared.is_empty():
			return false
		var source_path: String = _GF_VARIANT_ACCESS.get_option_string(write_entry, "source_path")
		prepared["expected_sha256"] = FileAccess.get_sha256(source_path).to_lower()
		prepared["expected_size_bytes"] = _file_size(source_path)
		prepared_writes.append(prepared)
	var prepared_deletes: Array[Dictionary] = []
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(request, "deletes"):
		var delete_entry: Dictionary = raw_value
		var prepared: Dictionary = _prepare_payload_entry(active_root, journal, delete_entry, "delete", issues)
		if prepared.is_empty():
			return false
		prepared_deletes.append(prepared)
	journal["writes"] = prepared_writes
	journal["deletes"] = prepared_deletes
	return _write_phase(active_root, journal, _PHASE_PREPARED, issues)


static func _prepare_payload_entry(
	active_root: String,
	journal: Dictionary,
	entry: Dictionary,
	action: String,
	issues: PackedStringArray
) -> Dictionary:
	var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(journal, "project_root")
	var target_path: String = project_root.path_join(relative_path).replace("\\", "/").simplify_path()
	if not _is_path_inside(project_root, target_path):
		var _append_target: bool = issues.append("Package transaction target is outside project root: %s" % target_path)
		return {}
	if _path_has_link_component(target_path):
		var _append_target_link: bool = issues.append("Package transaction target crosses a filesystem link: %s" % relative_path)
		return {}
	if DirAccess.dir_exists_absolute(target_path):
		var _append_directory: bool = issues.append("Package transaction target is a directory: %s" % relative_path)
		return {}
	var original_exists: bool = FileAccess.file_exists(target_path)
	var prepared: Dictionary = {
		"action": action,
		"relative_path": relative_path,
		"original_exists": original_exists,
		"original_sha256": "",
		"original_size_bytes": 0,
		"backup_relative_path": "",
	}
	if not original_exists:
		return prepared
	var backup_relative_path: String = _BACKUP_DIRECTORY_NAME.path_join(relative_path)
	var backup_path: String = active_root.path_join(backup_relative_path)
	if not _copy_file(target_path, backup_path, issues, "backup package payload %s" % relative_path):
		return {}
	prepared["original_sha256"] = FileAccess.get_sha256(backup_path).to_lower()
	prepared["original_size_bytes"] = _file_size(backup_path)
	prepared["backup_relative_path"] = backup_relative_path
	return prepared


static func _apply_payload(
	journal: Dictionary,
	request: Dictionary,
	options: Dictionary
) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var source_paths: Dictionary = {}
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(request, "writes"):
		var entry: Dictionary = raw_value
		source_paths[_GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")] = _GF_VARIANT_ACCESS.get_option_string(entry, "source_path")
	var write_count: int = 0
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(journal, "writes"):
		if _append_cancelled_if_requested(options, issues):
			return { "ok": false, "write_count": write_count, "delete_count": 0, "issues": _packed_to_array(issues) }
		var entry: Dictionary = raw_value
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
		var source_path: String = _GF_VARIANT_ACCESS.get_option_string(source_paths, relative_path)
		if not _apply_write(journal, entry, source_path, issues):
			return { "ok": false, "write_count": write_count, "delete_count": 0, "issues": _packed_to_array(issues) }
		write_count += 1
		var simulate_after: int = _GF_VARIANT_ACCESS.get_option_int(options, "simulate_copy_failure_after", 0)
		if simulate_after > 0 and write_count >= simulate_after:
			var _append_failure: bool = issues.append("Simulated package install copy failure.")
			return { "ok": false, "write_count": write_count, "delete_count": 0, "issues": _packed_to_array(issues) }

	var delete_count: int = 0
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(journal, "deletes"):
		if _append_cancelled_if_requested(options, issues):
			return { "ok": false, "write_count": write_count, "delete_count": delete_count, "issues": _packed_to_array(issues) }
		var entry: Dictionary = raw_value
		if not _apply_delete(journal, entry, issues):
			return { "ok": false, "write_count": write_count, "delete_count": delete_count, "issues": _packed_to_array(issues) }
		if _GF_VARIANT_ACCESS.get_option_bool(entry, "original_exists", false):
			delete_count += 1
		var simulate_after: int = _GF_VARIANT_ACCESS.get_option_int(options, "simulate_delete_failure_after", 0)
		if simulate_after > 0 and delete_count >= simulate_after:
			var _append_failure: bool = issues.append("Simulated package uninstall delete failure.")
			return { "ok": false, "write_count": write_count, "delete_count": delete_count, "issues": _packed_to_array(issues) }
	return { "ok": true, "write_count": write_count, "delete_count": delete_count, "issues": [] }


static func _apply_write(
	journal: Dictionary,
	entry: Dictionary,
	source_path: String,
	issues: PackedStringArray
) -> bool:
	if source_path.is_empty() or not FileAccess.file_exists(source_path) or _path_has_link_component(source_path):
		var _append_source: bool = issues.append("Package transaction staged source is missing: %s" % source_path)
		return false
	var expected_sha: String = _GF_VARIANT_ACCESS.get_option_string(entry, "expected_sha256")
	var expected_size: int = _GF_VARIANT_ACCESS.get_option_int(entry, "expected_size_bytes", -1)
	if FileAccess.get_sha256(source_path).to_lower() != expected_sha or _file_size(source_path) != expected_size:
		var _append_changed: bool = issues.append("Package transaction staged source changed after preparation: %s" % source_path)
		return false
	var target_path: String = _payload_target_path(journal, entry)
	var temp_path: String = _payload_temp_path(target_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"))
	if _path_has_link_component(target_path) or _path_has_link_component(temp_path):
		var _append_target_link: bool = issues.append("Package transaction write target crosses a filesystem link: %s" % target_path)
		return false
	if not _copy_file(source_path, temp_path, issues, "stage package payload %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")):
		return false
	if _path_has_link_component(target_path) or _path_has_link_component(temp_path):
		var _append_changed_link: bool = issues.append("Package transaction write path became a filesystem link: %s" % target_path)
		return false
	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not replace package payload: %s" % error_string(remove_error))
			return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, target_path)
	if rename_error != OK:
		var _append_rename: bool = issues.append("Could not commit package payload: %s" % error_string(rename_error))
		return false
	if not _file_matches(target_path, expected_sha, expected_size):
		var _append_verify: bool = issues.append("Committed package payload failed verification: %s" % target_path)
		return false
	return true


static func _apply_delete(journal: Dictionary, entry: Dictionary, issues: PackedStringArray) -> bool:
	var target_path: String = _payload_target_path(journal, entry)
	if _path_has_link_component(target_path):
		var _append_target_link: bool = issues.append("Package transaction delete target crosses a filesystem link: %s" % target_path)
		return false
	if DirAccess.dir_exists_absolute(target_path):
		var _append_directory: bool = issues.append("Refusing to delete directory as package payload: %s" % target_path)
		return false
	if not FileAccess.file_exists(target_path):
		return true
	var remove_error: Error = DirAccess.remove_absolute(target_path)
	if remove_error != OK:
		var _append_remove: bool = issues.append("Could not delete package payload: %s (%s)" % [target_path, error_string(remove_error)])
		return false
	return true


static func _commit_lockfile(active_root: String, journal: Dictionary, issues: PackedStringArray) -> bool:
	var planned_path: String = active_root.path_join(_LOCKFILE_PLANNED_NAME)
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	var temp_path: String = _lockfile_temp_path(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"))
	if _path_has_link_component(planned_path) or _path_has_link_component(lockfile_path) or _path_has_link_component(temp_path):
		var _append_lock_link: bool = issues.append("Package transaction lockfile path crosses a filesystem link.")
		return false
	if not _copy_file(planned_path, temp_path, issues, "stage package lockfile"):
		return false
	if _path_has_link_component(lockfile_path) or _path_has_link_component(temp_path):
		var _append_changed_link: bool = issues.append("Package transaction lockfile path became a filesystem link.")
		return false
	if FileAccess.file_exists(lockfile_path):
		var remove_error: Error = DirAccess.remove_absolute(lockfile_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not replace package lockfile: %s" % error_string(remove_error))
			return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, lockfile_path)
	if rename_error != OK:
		var _append_rename: bool = issues.append("Could not commit package lockfile: %s" % error_string(rename_error))
		return false
	if not _file_matches(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_planned_sha256"), _file_size(planned_path)):
		var _append_verify: bool = issues.append("Committed package lockfile failed verification: %s" % lockfile_path)
		return false
	return true


static func _rollback_after_failure(
	active_root: String,
	journal: Dictionary,
	operation: String,
	write_count: int,
	delete_count: int,
	issues: PackedStringArray
) -> Dictionary:
	var phase_issues: PackedStringArray = PackedStringArray()
	var _phase_written: bool = _write_phase(active_root, journal, _PHASE_ROLLING_BACK, phase_issues)
	_append_string_array(issues, phase_issues)
	var rollback_issues: PackedStringArray = PackedStringArray()
	var rollback_ok: bool = _rollback_state(active_root, journal, rollback_issues)
	_append_string_array(issues, rollback_issues)
	if rollback_ok:
		rollback_ok = _cleanup_active_transaction(active_root, journal, issues)
	else:
		var recovery_phase_issues: PackedStringArray = PackedStringArray()
		var _recovery_phase_written: bool = _write_phase(active_root, journal, _PHASE_RECOVERY_FAILED, recovery_phase_issues)
		_append_string_array(issues, recovery_phase_issues)
	return _make_report(false, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"), operation, _GF_VARIANT_ACCESS.get_option_string(journal, "phase"), _OUTCOME_ROLLED_BACK if rollback_ok else _OUTCOME_RECOVERY_FAILED, write_count, delete_count, false, rollback_ok, false, not rollback_ok, issues)


static func _rollback_state(active_root: String, journal: Dictionary, issues: PackedStringArray) -> bool:
	if _append_rollback_conflict_issues(journal, issues):
		return false
	var entries: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "deletes") + _GF_VARIANT_ACCESS.get_option_array(journal, "writes")
	for index: int in range(entries.size() - 1, -1, -1):
		var raw_value: Variant = entries[index]
		if not raw_value is Dictionary:
			var _append_entry: bool = issues.append("Package transaction journal contains an invalid payload entry.")
			continue
		var entry: Dictionary = raw_value
		_restore_payload_entry(active_root, journal, entry, issues)
	_restore_lockfile(active_root, journal, issues)
	if not _verify_original_state(journal, issues):
		return false
	return issues.is_empty()


static func _restore_payload_entry(
	active_root: String,
	journal: Dictionary,
	entry: Dictionary,
	issues: PackedStringArray
) -> void:
	var target_path: String = _payload_target_path(journal, entry)
	var temp_path: String = _payload_temp_path(target_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"))
	_remove_file_if_exists(temp_path, issues, "remove transaction payload temp")
	if _payload_matches_original_state(target_path, entry):
		return
	if not _payload_matches_planned_state(target_path, entry):
		var _append_conflict: bool = issues.append(
			"Package rollback target changed outside the transaction: %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
		)
		return
	if _GF_VARIANT_ACCESS.get_option_bool(entry, "original_exists", false):
		var backup_path: String = active_root.path_join(_GF_VARIANT_ACCESS.get_option_string(entry, "backup_relative_path"))
		_restore_file_from_snapshot(backup_path, target_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"), issues, "restore package payload")
		return
	_remove_file_if_exists(target_path, issues, "remove newly created package payload")
	_remove_empty_parents(target_path.get_base_dir(), _GF_VARIANT_ACCESS.get_option_string(journal, "project_root"))


static func _restore_lockfile(active_root: String, journal: Dictionary, issues: PackedStringArray) -> void:
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	var temp_path: String = _lockfile_temp_path(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"))
	_remove_file_if_exists(temp_path, issues, "remove transaction lockfile temp")
	if _lockfile_matches_original_state(lockfile_path, journal):
		return
	if not _lockfile_matches_planned_state(lockfile_path, journal):
		var _append_conflict: bool = issues.append("Package rollback lockfile changed outside the transaction.")
		return
	if _GF_VARIANT_ACCESS.get_option_bool(journal, "lockfile_had_original", false):
		_restore_file_from_snapshot(active_root.path_join(_LOCKFILE_ORIGINAL_NAME), lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"), issues, "restore package lockfile")
		return
	_remove_file_if_exists(lockfile_path, issues, "remove newly created package lockfile")


static func _append_rollback_conflict_issues(journal: Dictionary, issues: PackedStringArray) -> bool:
	var original_issue_count: int = issues.size()
	var entries: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "writes") + _GF_VARIANT_ACCESS.get_option_array(journal, "deletes")
	for raw_value: Variant in entries:
		if not raw_value is Dictionary:
			var _append_entry: bool = issues.append("Package transaction journal contains an invalid payload entry.")
			continue
		var entry: Dictionary = raw_value
		var target_path: String = _payload_target_path(journal, entry)
		var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
		if _path_has_link_component(target_path):
			var _append_link: bool = issues.append("Package rollback target crosses a filesystem link: %s" % relative_path)
			continue
		if not _payload_matches_original_state(target_path, entry) and not _payload_matches_planned_state(target_path, entry):
			var _append_conflict: bool = issues.append(
				"Package rollback conflict; target matches neither original nor planned state: %s" % relative_path
			)
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	if _path_has_link_component(lockfile_path):
		var _append_lock_link: bool = issues.append("Package rollback lockfile path crosses a filesystem link.")
	elif not _lockfile_matches_original_state(lockfile_path, journal) and not _lockfile_matches_planned_state(lockfile_path, journal):
		var _append_lock_conflict: bool = issues.append("Package rollback conflict; lockfile matches neither original nor planned state.")
	return issues.size() > original_issue_count


static func _payload_matches_original_state(target_path: String, entry: Dictionary) -> bool:
	if _GF_VARIANT_ACCESS.get_option_bool(entry, "original_exists", false):
		return _file_matches(
			target_path,
			_GF_VARIANT_ACCESS.get_option_string(entry, "original_sha256"),
			_GF_VARIANT_ACCESS.get_option_int(entry, "original_size_bytes", -1)
		)
	return not _path_exists(target_path)


static func _payload_matches_planned_state(target_path: String, entry: Dictionary) -> bool:
	if _GF_VARIANT_ACCESS.get_option_string(entry, "action") == "write":
		return _file_matches(
			target_path,
			_GF_VARIANT_ACCESS.get_option_string(entry, "expected_sha256"),
			_GF_VARIANT_ACCESS.get_option_int(entry, "expected_size_bytes", -1)
		)
	return not _path_exists(target_path)


static func _lockfile_matches_original_state(lockfile_path: String, journal: Dictionary) -> bool:
	if _GF_VARIANT_ACCESS.get_option_bool(journal, "lockfile_had_original", false):
		return _file_matches(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_original_sha256"), -1)
	return not _path_exists(lockfile_path)


static func _lockfile_matches_planned_state(lockfile_path: String, journal: Dictionary) -> bool:
	return _file_matches(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_planned_sha256"), -1)


static func _restore_file_from_snapshot(
	snapshot_path: String,
	target_path: String,
	transaction_id: String,
	issues: PackedStringArray,
	context: String
) -> void:
	if _path_has_link_component(snapshot_path) or _path_has_link_component(target_path):
		var _append_link: bool = issues.append("Filesystem link blocked while attempting to %s." % context)
		return
	if not FileAccess.file_exists(snapshot_path):
		var _append_missing: bool = issues.append("Missing transaction snapshot while attempting to %s: %s" % [context, snapshot_path])
		return
	var temp_path: String = target_path + ".gf-package-restore-" + transaction_id + ".tmp"
	if not _copy_file(snapshot_path, temp_path, issues, context):
		return
	if _path_has_link_component(snapshot_path) or _path_has_link_component(target_path) or _path_has_link_component(temp_path):
		var _append_changed_link: bool = issues.append("Filesystem link appeared while attempting to %s." % context)
		return
	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			var _append_remove: bool = issues.append("Could not replace target while attempting to %s: %s" % [context, error_string(remove_error)])
			return
	var rename_error: Error = DirAccess.rename_absolute(temp_path, target_path)
	if rename_error != OK:
		var _append_rename: bool = issues.append("Could not finish %s: %s" % [context, error_string(rename_error)])


static func _verify_committed_state(journal: Dictionary, issues: PackedStringArray) -> bool:
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	var planned_sha: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_planned_sha256")
	if planned_sha.is_empty() or not _file_matches(lockfile_path, planned_sha, -1):
		var _append_lockfile: bool = issues.append("Committed package transaction lockfile no longer matches its planned snapshot.")
		return false
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(journal, "writes"):
		if not raw_value is Dictionary:
			var _append_entry: bool = issues.append("Committed package transaction contains an invalid write entry.")
			return false
		var entry: Dictionary = raw_value
		if not _file_matches(_payload_target_path(journal, entry), _GF_VARIANT_ACCESS.get_option_string(entry, "expected_sha256"), _GF_VARIANT_ACCESS.get_option_int(entry, "expected_size_bytes", -1)):
			var _append_write: bool = issues.append("Committed package payload does not match journal: %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path"))
			return false
	for raw_value: Variant in _GF_VARIANT_ACCESS.get_option_array(journal, "deletes"):
		if not raw_value is Dictionary:
			var _append_entry: bool = issues.append("Committed package transaction contains an invalid delete entry.")
			return false
		var entry: Dictionary = raw_value
		if FileAccess.file_exists(_payload_target_path(journal, entry)):
			var _append_delete: bool = issues.append("Committed package delete target still exists: %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path"))
			return false
	return true


static func _verify_original_state(journal: Dictionary, issues: PackedStringArray) -> bool:
	var entries: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "writes") + _GF_VARIANT_ACCESS.get_option_array(journal, "deletes")
	for raw_value: Variant in entries:
		if not raw_value is Dictionary:
			var _append_entry: bool = issues.append("Package transaction journal contains an invalid payload entry during rollback verification.")
			continue
		var entry: Dictionary = raw_value
		var target_path: String = _payload_target_path(journal, entry)
		if _GF_VARIANT_ACCESS.get_option_bool(entry, "original_exists", false):
			if not _file_matches(target_path, _GF_VARIANT_ACCESS.get_option_string(entry, "original_sha256"), _GF_VARIANT_ACCESS.get_option_int(entry, "original_size_bytes", -1)):
				var _append_restore: bool = issues.append("Rolled-back package payload does not match original snapshot: %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path"))
		elif FileAccess.file_exists(target_path):
			var _append_created: bool = issues.append("Rolled-back package payload still exists: %s" % _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path"))
	var lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	if _GF_VARIANT_ACCESS.get_option_bool(journal, "lockfile_had_original", false):
		if not _file_matches(lockfile_path, _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_original_sha256"), -1):
			var _append_lockfile: bool = issues.append("Rolled-back package lockfile does not match original snapshot.")
	elif FileAccess.file_exists(lockfile_path):
		var _append_new_lockfile: bool = issues.append("Rolled-back package lockfile still exists.")
	return issues.is_empty()


static func _cleanup_active_transaction(active_root: String, journal: Dictionary, issues: PackedStringArray) -> bool:
	if not DirAccess.dir_exists_absolute(active_root):
		return true
	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(journal, "project_root")
	var transaction_root: String = _transaction_root(project_root)
	var validated_cleanup_paths: PackedStringArray = PackedStringArray()
	for raw_cleanup: Variant in _GF_VARIANT_ACCESS.get_option_array(journal, "cleanup_paths"):
		if not raw_cleanup is String:
			var _append_cleanup_type: bool = issues.append("Package transaction journal contains a non-string cleanup path.")
			continue
		var raw_cleanup_path: String = raw_cleanup
		var cleanup_path: String = _validate_cleanup_path(project_root, transaction_root, raw_cleanup_path)
		if cleanup_path.is_empty():
			var _append_cleanup_path: bool = issues.append("Package transaction journal contains an unsafe cleanup path: %s" % raw_cleanup_path)
			continue
		var _append_validated: bool = validated_cleanup_paths.append(cleanup_path)
	if validated_cleanup_paths.size() != _GF_VARIANT_ACCESS.get_option_array(journal, "cleanup_paths").size():
		return false
	if _path_has_link_component(active_root) or _tree_has_link(active_root):
		var _append_active_link: bool = issues.append("Active package transaction directory contains a filesystem link: %s" % active_root)
		return false
	var cleanup_root: String = transaction_root.path_join(
		_CLEANUP_PREFIX + _GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id")
	)
	if _path_exists(cleanup_root):
		cleanup_root += "-%d" % Time.get_ticks_usec()
	if _path_exists(cleanup_root) or _path_has_link_component(cleanup_root):
		var _append_cleanup_root: bool = issues.append("Package transaction cleanup directory is unsafe: %s" % cleanup_root)
		return false
	var finalize_error: Error = DirAccess.rename_absolute(active_root, cleanup_root)
	if finalize_error != OK:
		var _append_finalize: bool = issues.append("Could not finalize package transaction directory: %s" % error_string(finalize_error))
		return false
	var ok: bool = true
	for cleanup_path: String in validated_cleanup_paths:
		var cleanup_issues: PackedStringArray = PackedStringArray()
		var cleanup_ok: bool = _remove_tree(cleanup_path, cleanup_issues)
		if not cleanup_ok:
			_append_string_array(issues, cleanup_issues)
			ok = false
	var cleanup_directory_issues: PackedStringArray = PackedStringArray()
	var cleanup_directory_removed: bool = _remove_tree(cleanup_root, cleanup_directory_issues)
	if not cleanup_directory_removed:
		_append_string_array(issues, cleanup_directory_issues)
		ok = false
	_remove_empty_directory(transaction_root)
	return ok


static func _write_phase(
	active_root: String,
	journal: Dictionary,
	phase: String,
	issues: PackedStringArray
) -> bool:
	journal["phase"] = phase
	return _write_journal_snapshot(active_root, journal, issues)


static func _write_journal_snapshot(root: String, journal: Dictionary, issues: PackedStringArray) -> bool:
	var sequence: int = _GF_VARIANT_ACCESS.get_option_int(journal, "sequence", -1) + 1
	journal["sequence"] = sequence
	var base_name: String = "%s%06d%s" % [_JOURNAL_PREFIX, sequence, _JOURNAL_SUFFIX]
	var final_path: String = root.path_join(base_name)
	var temp_path: String = final_path + _JOURNAL_TEMP_SUFFIX
	if _path_exists(final_path) or _path_has_link_component(final_path) or _path_has_link_component(temp_path):
		var _append_existing: bool = issues.append("Package transaction journal snapshot path is unsafe or already exists: %s" % final_path)
		return false
	if not _write_text_file(temp_path, JSON.stringify(journal, "\t", false) + "\n", issues, "write package transaction journal"):
		return false
	if _path_has_link_component(final_path) or _path_has_link_component(temp_path):
		var _append_link: bool = issues.append("Package transaction journal path became a filesystem link: %s" % final_path)
		return false
	var rename_error: Error = DirAccess.rename_absolute(temp_path, final_path)
	if rename_error != OK:
		var _append_rename: bool = issues.append("Could not commit package transaction journal: %s" % error_string(rename_error))
		return false
	return true


static func _read_latest_journal(
	active_root: String,
	issues: PackedStringArray,
	expected_project_root: String = ""
) -> Dictionary:
	var directory: DirAccess = DirAccess.open(active_root)
	if directory == null:
		var _append_open: bool = issues.append("Could not open package transaction directory: %s" % active_root)
		return {}
	var names: PackedStringArray = PackedStringArray()
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		var _append_list: bool = issues.append("Could not enumerate package transaction journals: %s" % error_string(list_error))
		return {}
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.begins_with(_JOURNAL_PREFIX) and file_name.ends_with(_JOURNAL_SUFFIX):
			var _append_name: bool = names.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	if names.is_empty():
		var _append_missing: bool = issues.append("Package transaction has no journal snapshot: %s" % active_root)
		return {}
	var latest_name: String = names[names.size() - 1]
	var latest_path: String = active_root.path_join(latest_name)
	if _path_has_link_component(latest_path):
		var _append_link: bool = issues.append("Latest package transaction journal crosses a filesystem link: %s" % latest_path)
		return {}
	var parsed: Variant = _read_json_value(latest_path)
	if not parsed is Dictionary:
		var _append_invalid: bool = issues.append("Latest package transaction journal is unreadable: %s" % latest_path)
		return {}
	var sequence_text: String = latest_name.substr(
		_JOURNAL_PREFIX.length(),
		latest_name.length() - _JOURNAL_PREFIX.length() - _JOURNAL_SUFFIX.length()
	)
	var expected_sequence: int = sequence_text.to_int() if sequence_text.is_valid_int() else -1
	var journal: Dictionary = parsed
	if not _validate_journal(journal, active_root, expected_project_root, expected_sequence, issues):
		return {}
	return journal


static func _journal_is_valid(journal: Dictionary) -> bool:
	var schema_issues: PackedStringArray = PackedStringArray()
	var schema_contract: Dictionary = _load_schema_contract(schema_issues)
	if schema_contract.is_empty():
		return false
	var required_fields: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "journal_required_fields")
	var _append_started: bool = required_fields.append("started_unix_time")
	for field_name: String in required_fields:
		if not journal.has(field_name):
			return false
	return (
		_is_exact_integer(journal.get("schema_version"))
		and _GF_VARIANT_ACCESS.get_option_int(journal, "schema_version", 0) == _GF_VARIANT_ACCESS.get_option_int(schema_contract, "schema_version", 0)
		and typeof(journal.get("transaction_id")) == TYPE_STRING
		and _transaction_id_is_valid(_GF_VARIANT_ACCESS.get_option_string(journal, "transaction_id"))
		and typeof(journal.get("operation")) == TYPE_STRING
		and _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "operations").has(_GF_VARIANT_ACCESS.get_option_string(journal, "operation"))
		and typeof(journal.get("phase")) == TYPE_STRING
		and _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "phases").has(_GF_VARIANT_ACCESS.get_option_string(journal, "phase"))
		and _is_exact_integer(journal.get("sequence"))
		and _GF_VARIANT_ACCESS.get_option_int(journal, "sequence", -1) >= 0
		and _is_exact_integer(journal.get("owner_pid"))
		and _GF_VARIANT_ACCESS.get_option_int(journal, "owner_pid", -1) >= 0
		and _is_exact_integer(journal.get("started_unix_time"))
		and _GF_VARIANT_ACCESS.get_option_int(journal, "started_unix_time", -1) >= 0
	)


static func _validate_journal(
	journal: Dictionary,
	active_root: String,
	expected_project_root: String,
	expected_sequence: int,
	issues: PackedStringArray
) -> bool:
	var schema_contract: Dictionary = _load_schema_contract(issues)
	if schema_contract.is_empty():
		return false
	var required_fields: PackedStringArray = _GF_VARIANT_ACCESS.get_option_packed_string_array(schema_contract, "journal_required_fields")
	var _append_started: bool = required_fields.append("started_unix_time")
	var allowed_fields: PackedStringArray = required_fields.duplicate()
	var _append_fault: bool = allowed_fields.append("fault_injected")
	if not _dictionary_fields_are_exact(journal, required_fields, allowed_fields, "Package transaction journal", issues):
		return false
	if not _journal_is_valid(journal):
		var _append_base: bool = issues.append("Package transaction journal scalar schema is invalid.")
		return false
	if journal.has("fault_injected") and typeof(journal.get("fault_injected")) != TYPE_BOOL:
		var _append_fault_type: bool = issues.append("Package transaction journal fault_injected must be boolean.")
	if _GF_VARIANT_ACCESS.get_option_int(journal, "sequence", -1) != expected_sequence:
		var _append_sequence: bool = issues.append("Package transaction journal filename sequence does not match its payload.")

	var raw_project_root: String = _GF_VARIANT_ACCESS.get_option_string(journal, "project_root")
	var project_root: String = _normalize_project_root(raw_project_root)
	if project_root.is_empty() or raw_project_root.replace("\\", "/") != project_root:
		var _append_project: bool = issues.append("Package transaction journal project_root is not canonical.")
	if not expected_project_root.is_empty() and not _paths_equal(project_root, expected_project_root):
		var _append_expected_project: bool = issues.append("Package transaction journal project root does not match the requested project.")
	if not DirAccess.dir_exists_absolute(project_root) or _path_has_link_component(project_root):
		var _append_project_link: bool = issues.append("Package transaction journal project root is missing or crosses a filesystem link.")
	var transaction_root: String = _transaction_root(project_root)
	var normalized_active_root: String = _normalize_absolute_path(active_root)
	if (
		normalized_active_root.is_empty()
		or not _paths_equal(normalized_active_root.get_base_dir(), transaction_root)
		or (
			normalized_active_root.get_file() != _ACTIVE_DIRECTORY_NAME
			and not normalized_active_root.get_file().begins_with(_CANDIDATE_PREFIX)
		)
	):
		var _append_active: bool = issues.append("Package transaction journal directory is not bound to the project transaction root.")
	if _path_has_link_component(normalized_active_root):
		var _append_active_link: bool = issues.append("Package transaction journal directory crosses a filesystem link.")

	var raw_lockfile_path: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_path")
	var lockfile_path: String = _normalize_absolute_path(raw_lockfile_path)
	if lockfile_path.is_empty() or raw_lockfile_path.replace("\\", "/") != lockfile_path:
		var _append_lockfile: bool = issues.append("Package transaction journal lockfile_path is not canonical.")
	if not _is_path_inside(project_root, lockfile_path) or _is_path_inside(transaction_root, lockfile_path):
		var _append_lock_root: bool = issues.append("Package transaction journal lockfile_path is outside its permitted project root.")
	if _path_has_link_component(lockfile_path):
		var _append_lock_link: bool = issues.append("Package transaction journal lockfile_path crosses a filesystem link.")

	var raw_cleanup_values: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "cleanup_paths")
	var seen_cleanup_paths: Dictionary = {}
	for raw_cleanup: Variant in raw_cleanup_values:
		if not raw_cleanup is String:
			var _append_cleanup_type: bool = issues.append("Package transaction journal cleanup_paths must contain only non-empty strings.")
			continue
		var raw_cleanup_path: String = raw_cleanup
		var cleanup_path: String = _validate_cleanup_path(project_root, transaction_root, raw_cleanup_path)
		if cleanup_path.is_empty():
			var _append_cleanup: bool = issues.append("Package transaction journal cleanup path is unsafe: %s" % raw_cleanup_path)
			continue
		var cleanup_identity: String = _absolute_portable_path_identity(cleanup_path)
		if seen_cleanup_paths.has(cleanup_identity):
			var _append_cleanup_duplicate: bool = issues.append("Package transaction journal cleanup path is duplicated: %s" % raw_cleanup_path)
		seen_cleanup_paths[cleanup_identity] = true

	if typeof(journal.get("lockfile_had_original")) != TYPE_BOOL:
		var _append_lock_bool: bool = issues.append("Package transaction journal lockfile_had_original must be boolean.")
	for sha_field: String in ["lockfile_original_sha256", "lockfile_planned_sha256"]:
		if typeof(journal.get(sha_field)) != TYPE_STRING:
			var _append_sha_type: bool = issues.append("Package transaction journal %s must be a string." % sha_field)
	for array_field: String in ["writes", "deletes", "cleanup_paths"]:
		if typeof(journal.get(array_field)) != TYPE_ARRAY:
			var _append_array_type: bool = issues.append("Package transaction journal %s must be an array." % array_field)

	var phase: String = _GF_VARIANT_ACCESS.get_option_string(journal, "phase")
	var writes: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "writes")
	var deletes: Array = _GF_VARIANT_ACCESS.get_option_array(journal, "deletes")
	if phase == _PHASE_PREPARING:
		if not writes.is_empty() or not deletes.is_empty():
			var _append_preparing_payload: bool = issues.append("Preparing package transaction journal cannot contain prepared payload entries.")
		if (
			_GF_VARIANT_ACCESS.get_option_bool(journal, "lockfile_had_original", false)
			or not _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_original_sha256").is_empty()
			or not _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_planned_sha256").is_empty()
		):
			var _append_preparing_lock: bool = issues.append("Preparing package transaction journal cannot claim prepared lockfile snapshots.")
		return issues.is_empty()

	var planned_snapshot: String = normalized_active_root.path_join(_LOCKFILE_PLANNED_NAME)
	var planned_sha: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_planned_sha256")
	if not _is_sha256(planned_sha) or _path_has_link_component(planned_snapshot) or not _file_matches(planned_snapshot, planned_sha, -1):
		var _append_planned: bool = issues.append("Package transaction journal planned lockfile snapshot is missing or invalid.")
	if _GF_VARIANT_ACCESS.get_option_bool(journal, "lockfile_had_original", false):
		var original_snapshot: String = normalized_active_root.path_join(_LOCKFILE_ORIGINAL_NAME)
		var original_sha: String = _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_original_sha256")
		if not _is_sha256(original_sha) or _path_has_link_component(original_snapshot) or not _file_matches(original_snapshot, original_sha, -1):
			var _append_original: bool = issues.append("Package transaction journal original lockfile snapshot is missing or invalid.")
	elif not _GF_VARIANT_ACCESS.get_option_string(journal, "lockfile_original_sha256").is_empty():
		var _append_absent_original: bool = issues.append("Package transaction journal has an original lockfile digest without an original lockfile.")

	var seen_payload_paths: Dictionary = {}
	for raw_write: Variant in writes:
		_validate_journal_payload_entry(raw_write, "write", project_root, normalized_active_root, seen_payload_paths, issues)
	for raw_delete: Variant in deletes:
		_validate_journal_payload_entry(raw_delete, "delete", project_root, normalized_active_root, seen_payload_paths, issues)
	return issues.is_empty()


static func _validate_journal_payload_entry(
	raw_entry: Variant,
	action: String,
	project_root: String,
	active_root: String,
	seen_paths: Dictionary,
	issues: PackedStringArray
) -> void:
	if not raw_entry is Dictionary:
		var _append_type: bool = issues.append("Package transaction journal %s entry must be a Dictionary." % action)
		return
	var entry: Dictionary = raw_entry
	var common_fields: PackedStringArray = PackedStringArray([
		"action", "relative_path", "original_exists", "original_sha256", "original_size_bytes", "backup_relative_path"
	])
	var allowed_fields: PackedStringArray = common_fields.duplicate()
	if action == "write":
		var _append_expected_sha: bool = allowed_fields.append("expected_sha256")
		var _append_expected_size: bool = allowed_fields.append("expected_size_bytes")
	if not _dictionary_fields_are_exact(entry, allowed_fields, allowed_fields, "Package transaction journal %s entry" % action, issues):
		return
	if _GF_VARIANT_ACCESS.get_option_string(entry, "action") != action:
		var _append_action: bool = issues.append("Package transaction journal payload action is invalid.")
	var relative_path: String = _GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
	if relative_path.is_empty() or _normalize_payload_relative_path(relative_path) != relative_path:
		var _append_path: bool = issues.append("Package transaction journal payload path is invalid: %s" % relative_path)
		return
	var path_identity: String = _portable_path_identity(relative_path)
	if seen_paths.has(path_identity):
		var _append_duplicate: bool = issues.append("Package transaction journal payload path is duplicated: %s" % relative_path)
	seen_paths[path_identity] = true
	var target_path: String = project_root.path_join(relative_path).replace("\\", "/").simplify_path()
	if not _is_path_inside(project_root, target_path) or _path_has_link_component(target_path):
		var _append_target: bool = issues.append("Package transaction journal payload target is unsafe: %s" % relative_path)
	if typeof(entry.get("original_exists")) != TYPE_BOOL:
		var _append_original_bool: bool = issues.append("Package transaction journal original_exists must be boolean: %s" % relative_path)
		return
	if typeof(entry.get("original_sha256")) != TYPE_STRING or not _is_exact_integer(entry.get("original_size_bytes")):
		var _append_original_metadata: bool = issues.append("Package transaction journal original metadata is invalid: %s" % relative_path)
		return
	var backup_relative_path: String = _GF_VARIANT_ACCESS.get_option_string(entry, "backup_relative_path")
	if typeof(entry.get("backup_relative_path")) != TYPE_STRING:
		var _append_backup_type: bool = issues.append("Package transaction journal backup path is invalid: %s" % relative_path)
		return
	if _GF_VARIANT_ACCESS.get_option_bool(entry, "original_exists", false):
		var expected_backup: String = _BACKUP_DIRECTORY_NAME.path_join(relative_path).replace("\\", "/")
		var backup_path: String = active_root.path_join(backup_relative_path).replace("\\", "/").simplify_path()
		if backup_relative_path != expected_backup or not _is_path_inside(active_root, backup_path):
			var _append_backup_root: bool = issues.append("Package transaction journal backup path is not bound to its payload: %s" % relative_path)
		elif (
			_path_has_link_component(backup_path)
			or not _is_sha256(_GF_VARIANT_ACCESS.get_option_string(entry, "original_sha256"))
			or _GF_VARIANT_ACCESS.get_option_int(entry, "original_size_bytes", -1) < 0
			or not _file_matches(
				backup_path,
				_GF_VARIANT_ACCESS.get_option_string(entry, "original_sha256"),
				_GF_VARIANT_ACCESS.get_option_int(entry, "original_size_bytes", -1)
			)
		):
			var _append_backup: bool = issues.append("Package transaction journal backup snapshot is missing or invalid: %s" % relative_path)
	elif (
		not _GF_VARIANT_ACCESS.get_option_string(entry, "original_sha256").is_empty()
		or _GF_VARIANT_ACCESS.get_option_int(entry, "original_size_bytes", 0) != 0
		or not backup_relative_path.is_empty()
	):
		var _append_absent: bool = issues.append("Package transaction journal absent original state contains backup metadata: %s" % relative_path)
	if action == "write" and (
		typeof(entry.get("expected_sha256")) != TYPE_STRING
		or not _is_sha256(_GF_VARIANT_ACCESS.get_option_string(entry, "expected_sha256"))
		or not _is_exact_integer(entry.get("expected_size_bytes"))
		or _GF_VARIANT_ACCESS.get_option_int(entry, "expected_size_bytes", -1) < 0
	):
		var _append_expected: bool = issues.append("Package transaction journal planned write metadata is invalid: %s" % relative_path)


static func _load_schema_contract(issues: PackedStringArray) -> Dictionary:
	var parsed: Variant = _read_json_value(_SCHEMA_CONTRACT_PATH)
	if not parsed is Dictionary:
		var _append_parse: bool = issues.append("Package transaction schema contract is missing or invalid: %s" % _SCHEMA_CONTRACT_PATH)
		return {}
	var schema_contract: Dictionary = parsed
	if (
		_GF_VARIANT_ACCESS.get_option_int(schema_contract, "schema_version", 0) != _SCHEMA_VERSION
		or _GF_VARIANT_ACCESS.get_option_int(schema_contract, "report_schema_version", 0) != _REPORT_SCHEMA_VERSION
	):
		var _append_version: bool = issues.append("Package transaction schema contract version does not match the engine.")
		return {}
	return schema_contract


static func _mark_abandoned(active_root: String, journal: Dictionary) -> void:
	journal["owner_pid"] = 0
	journal["fault_injected"] = true
	var ignored_issues: PackedStringArray = PackedStringArray()
	var _snapshot_written: bool = _write_journal_snapshot(active_root, journal, ignored_issues)


static func _transaction_owner_is_running(journal: Dictionary) -> bool:
	var owner_pid: int = _GF_VARIANT_ACCESS.get_option_int(journal, "owner_pid", 0)
	if owner_pid <= 0 or _GF_VARIANT_ACCESS.get_option_bool(journal, "fault_injected", false):
		return false
	if owner_pid == OS.get_process_id():
		return true
	return OS.is_process_running(owner_pid)


static func _cleanup_abandoned_candidates(
	transaction_root: String,
	issues: PackedStringArray,
	expected_project_root: String
) -> bool:
	if not DirAccess.dir_exists_absolute(transaction_root):
		return true
	if _path_has_link_component(transaction_root):
		var _append_root_link: bool = issues.append("Package transaction root crosses a filesystem link: %s" % transaction_root)
		return false
	var directory: DirAccess = DirAccess.open(transaction_root)
	if directory == null:
		var _append_open: bool = issues.append("Could not open package transaction root: %s" % transaction_root)
		return false
	var candidates: PackedStringArray = PackedStringArray()
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		var _append_list: bool = issues.append("Could not enumerate package transaction root: %s" % error_string(list_error))
		return false
	var directory_name: String = directory.get_next()
	while not directory_name.is_empty():
		if directory_name.begins_with(_CANDIDATE_PREFIX) or directory_name.begins_with(_CLEANUP_PREFIX):
			var _append_candidate: bool = candidates.append(transaction_root.path_join(directory_name))
		directory_name = directory.get_next()
	directory.list_dir_end()
	for candidate_root: String in candidates:
		if not DirAccess.dir_exists_absolute(candidate_root) or _path_has_link_component(candidate_root) or _tree_has_link(candidate_root):
			var _append_candidate_link: bool = issues.append("Package transaction candidate is not a safe directory: %s" % candidate_root)
			continue
		if candidate_root.get_file().begins_with(_CLEANUP_PREFIX):
			if not _remove_tree(candidate_root, issues):
				continue
			continue
		var ignored_issues: PackedStringArray = PackedStringArray()
		var journal: Dictionary = _read_latest_journal(candidate_root, ignored_issues, expected_project_root)
		if journal.is_empty() or not _transaction_owner_is_running(journal):
			var _removed: bool = _remove_tree(candidate_root, issues)
	return issues.is_empty()


static func _make_report(
	ok: bool,
	transaction_id: String,
	operation: String,
	phase: String,
	outcome: String,
	write_count: int,
	delete_count: int,
	lockfile_written: bool,
	rolled_back: bool,
	recovered: bool,
	recovery_required: bool,
	issues: PackedStringArray,
	warnings: PackedStringArray = PackedStringArray()
) -> Dictionary:
	return {
		"schema_version": _REPORT_SCHEMA_VERSION,
		"ok": ok,
		"transaction_id": transaction_id,
		"operation": operation,
		"phase": phase,
		"outcome": outcome,
		"write_count": write_count,
		"delete_count": delete_count,
		"lockfile_written": lockfile_written,
		"rolled_back": rolled_back,
		"recovered": recovered,
		"recovery_required": recovery_required,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
		"warning_count": warnings.size(),
		"warnings": _packed_to_array(warnings),
	}


static func _transaction_root(project_root: String) -> String:
	return project_root.path_join(_TRANSACTION_ROOT_RELATIVE_PATH).replace("\\", "/").simplify_path()


static func _payload_target_path(journal: Dictionary, entry: Dictionary) -> String:
	return _GF_VARIANT_ACCESS.get_option_string(journal, "project_root").path_join(
		_GF_VARIANT_ACCESS.get_option_string(entry, "relative_path")
	).replace("\\", "/").simplify_path()


static func _payload_temp_path(target_path: String, transaction_id: String) -> String:
	return target_path + ".gf-package-" + transaction_id + ".tmp"


static func _lockfile_temp_path(lockfile_path: String, transaction_id: String) -> String:
	return lockfile_path + ".gf-package-" + transaction_id + ".tmp"


static func _normalize_project_root(path: String) -> String:
	var normalized: String = _normalize_absolute_path(path)
	if normalized.is_empty():
		return ""
	return _trim_trailing_separators(normalized)


static func _normalize_absolute_path(path: String) -> String:
	var stripped: String = path.strip_edges()
	if stripped.is_empty() or stripped != path:
		return ""
	var normalized: String = stripped
	if stripped.begins_with("res://") or stripped.begins_with("user://"):
		normalized = ProjectSettings.globalize_path(stripped)
	normalized = normalized.replace("\\", "/").simplify_path()
	if not normalized.is_absolute_path():
		return ""
	return normalized


static func _normalize_payload_relative_path(path: String) -> String:
	if path.is_empty() or path != path.strip_edges():
		return ""
	var normalized: String = path.replace("\\", "/")
	if normalized.is_empty() or normalized.begins_with("/") or normalized.contains(":"):
		return ""
	var parts: PackedStringArray = normalized.split("/", true)
	for part: String in parts:
		if (
			part.is_empty()
			or part == "."
			or part == ".."
			or part != part.rstrip(" .")
			or _string_has_control_character(part)
		):
			return ""
	normalized = "/".join(parts)
	if not normalized.begins_with(_PACKAGE_ROOT_PREFIX):
		return ""
	return normalized


static func _is_path_inside(root_path: String, child_path: String) -> bool:
	var root: String = _trim_trailing_separators(root_path.replace("\\", "/").simplify_path())
	var child: String = _trim_trailing_separators(child_path.replace("\\", "/").simplify_path())
	if OS.get_name() == "Windows":
		root = root.to_lower()
		child = child.to_lower()
	return child == root or child.begins_with(root + "/")


static func _paths_equal(left: String, right: String) -> bool:
	var normalized_left: String = _normalize_absolute_path(left)
	var normalized_right: String = _normalize_absolute_path(right)
	if OS.get_name() == "Windows":
		return normalized_left.to_lower() == normalized_right.to_lower()
	return normalized_left == normalized_right


static func _portable_path_identity(path: String) -> String:
	var normalized: String = _normalize_payload_relative_path(path)
	return normalized.to_lower() if not normalized.is_empty() else ""


static func _absolute_portable_path_identity(path: String) -> String:
	return _normalize_absolute_path(path).to_lower()


static func _packed_array_has_portable_path(values: PackedStringArray, path: String) -> bool:
	var identity: String = _absolute_portable_path_identity(path)
	for value: String in values:
		if _absolute_portable_path_identity(value) == identity:
			return true
	return false


static func _validate_cleanup_path(project_root: String, transaction_root: String, raw_path: String) -> String:
	if raw_path.is_empty() or raw_path != raw_path.strip_edges():
		return ""
	var cleanup_path: String = _normalize_absolute_path(raw_path)
	if cleanup_path.is_empty() or raw_path.replace("\\", "/") != cleanup_path:
		return ""
	var project_internal_root: String = project_root.path_join(".gf").replace("\\", "/").simplify_path()
	if cleanup_path == project_internal_root or not _is_path_inside(project_internal_root, cleanup_path):
		return ""
	if _is_path_inside(transaction_root, cleanup_path) or _is_path_inside(cleanup_path, transaction_root):
		return ""
	if _path_has_link_component(cleanup_path):
		return ""
	return cleanup_path


static func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or _path_component_is_link(path)


static func _path_has_link_component(path: String) -> bool:
	var current: String = _normalize_absolute_path(path)
	if current.is_empty():
		return true
	while not current.is_empty():
		if _path_component_is_link(current):
			return true
		var parent: String = _trim_trailing_separators(current.get_base_dir().replace("\\", "/"))
		if parent.is_empty() or parent == current:
			break
		current = parent
	return false


static func _path_component_is_link(path: String) -> bool:
	var normalized: String = _trim_trailing_separators(path.replace("\\", "/"))
	var parent: String = normalized.get_base_dir()
	var component_name: String = normalized.get_file()
	if parent.is_empty() or component_name.is_empty():
		return false
	var directory: DirAccess = DirAccess.open(parent)
	if directory == null:
		return DirAccess.dir_exists_absolute(parent)
	return directory.is_link(component_name)


static func _tree_has_link(path: String) -> bool:
	if _path_has_link_component(path):
		return true
	if FileAccess.file_exists(path) or not DirAccess.dir_exists_absolute(path):
		return false
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return true
	directory.include_hidden = true
	if directory.list_dir_begin() != OK:
		return true
	var result: bool = false
	var child_name: String = directory.get_next()
	while not child_name.is_empty():
		if child_name != "." and child_name != "..":
			if directory.is_link(child_name):
				result = true
				break
			if directory.current_is_dir() and _tree_has_link(path.path_join(child_name)):
				result = true
				break
		child_name = directory.get_next()
	directory.list_dir_end()
	return result


static func _string_has_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) < 32:
			return true
	return false


static func _is_exact_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


static func _transaction_id_is_valid(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		var code: int = character.unicode_at(0)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or (index > 0 and character in [".", "_", "-"])
		):
			return false
	return true


static func _dictionary_fields_are_exact(
	value: Dictionary,
	required_fields: PackedStringArray,
	allowed_fields: PackedStringArray,
	label: String,
	issues: PackedStringArray
) -> bool:
	var valid: bool = true
	for field_name: String in required_fields:
		if not value.has(field_name):
			var _append_missing: bool = issues.append("%s is missing required field: %s" % [label, field_name])
			valid = false
	for raw_key: Variant in value.keys():
		if not raw_key is String:
			var _append_unknown: bool = issues.append("%s contains unsupported field: %s" % [label, str(raw_key)])
			valid = false
			continue
		var field_name: String = raw_key
		if not allowed_fields.has(field_name):
			var _append_unknown: bool = issues.append("%s contains unsupported field: %s" % [label, field_name])
			valid = false
	return valid


static func _trim_trailing_separators(path: String) -> String:
	var result: String = path
	while (
		result.length() > 1
		and result.ends_with("/")
		and not (result.length() == 3 and result.substr(1, 1) == ":")
	):
		result = result.substr(0, result.length() - 1)
	return result


static func _copy_file(source_path: String, target_path: String, issues: PackedStringArray, context: String) -> bool:
	if _path_has_link_component(source_path) or _path_has_link_component(target_path):
		var _append_link: bool = issues.append("Could not %s because the path crosses a filesystem link." % context)
		return false
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		var _append_source: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	var source_length: int = source_file.get_length()
	var source_sha: String = FileAccess.get_sha256(source_path).to_lower()
	var make_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if make_error != OK:
		source_file.close()
		var _append_make: bool = issues.append("Could not create directory for %s: %s" % [context, error_string(make_error)])
		return false
	if _path_has_link_component(source_path) or _path_has_link_component(target_path):
		source_file.close()
		var _append_changed_link: bool = issues.append("Could not %s because the path became a filesystem link." % context)
		return false
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		var _append_target: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	while source_file.get_position() < source_length:
		var remaining: int = source_length - source_file.get_position()
		var chunk: PackedByteArray = source_file.get_buffer(mini(_COPY_CHUNK_BYTES, remaining))
		if source_file.get_error() != OK:
			var _append_read: bool = issues.append("Could not read while attempting to %s: %s" % [context, error_string(source_file.get_error())])
			source_file.close()
			target_file.close()
			return false
		var _store_result: Variant = target_file.store_buffer(chunk)
		if target_file.get_error() != OK:
			var _append_write: bool = issues.append("Could not write while attempting to %s: %s" % [context, error_string(target_file.get_error())])
			source_file.close()
			target_file.close()
			return false
	target_file.flush()
	source_file.close()
	target_file.close()
	if not _file_matches(target_path, source_sha, source_length):
		var _append_verify: bool = issues.append("Copied file verification failed while attempting to %s: %s" % [context, target_path])
		return false
	return true


static func _write_text_file(path: String, text: String, issues: PackedStringArray, context: String) -> bool:
	if _path_has_link_component(path):
		var _append_link: bool = issues.append("Could not %s because the path crosses a filesystem link." % context)
		return false
	var make_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create directory for %s: %s" % [context, error_string(make_error)])
		return false
	if _path_has_link_component(path):
		var _append_changed_link: bool = issues.append("Could not %s because the path became a filesystem link." % context)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var _append_open: bool = issues.append("Could not %s: %s" % [context, error_string(FileAccess.get_open_error())])
		return false
	var _store_result: Variant = file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		var _append_write: bool = issues.append("Could not %s: %s" % [context, error_string(write_error)])
		return false
	if _file_size(path) != text.to_utf8_buffer().size():
		var _append_size: bool = issues.append("Wrote file size mismatch while attempting to %s: %s" % [context, path])
		return false
	return true


static func _read_json_value(path: String) -> Variant:
	if _path_has_link_component(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text)


static func _file_matches(path: String, expected_sha: String, expected_size: int) -> bool:
	if _path_has_link_component(path) or not FileAccess.file_exists(path):
		return false
	if expected_size >= 0 and _file_size(path) != expected_size:
		return false
	return expected_sha.is_empty() or FileAccess.get_sha256(path).to_lower() == expected_sha


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var result: int = file.get_length()
	file.close()
	return result


static func _remove_file_if_exists(path: String, issues: PackedStringArray, context: String) -> void:
	if _path_has_link_component(path):
		var _append_link: bool = issues.append("Could not %s because the path crosses a filesystem link." % context)
		return
	if not FileAccess.file_exists(path):
		return
	var remove_error: Error = DirAccess.remove_absolute(path)
	if remove_error != OK:
		var _append_remove: bool = issues.append("Could not %s: %s" % [context, error_string(remove_error)])


static func _remove_tree(path: String, issues: PackedStringArray) -> bool:
	var normalized: String = _normalize_absolute_path(path)
	if normalized.is_empty() or normalized == "/" or normalized.length() < 4:
		var _append_unsafe: bool = issues.append("Refusing to remove unsafe package transaction path: %s" % path)
		return false
	if _path_has_link_component(normalized) or _tree_has_link(normalized):
		var _append_link: bool = issues.append("Refusing to remove package transaction path containing a filesystem link: %s" % normalized)
		return false
	if FileAccess.file_exists(normalized):
		var file_error: Error = DirAccess.remove_absolute(normalized)
		if file_error != OK:
			var _append_file: bool = issues.append("Could not remove package transaction file: %s" % normalized)
			return false
		return true
	if not DirAccess.dir_exists_absolute(normalized):
		return true
	var directory: DirAccess = DirAccess.open(normalized)
	if directory == null:
		var _append_open: bool = issues.append("Could not open package transaction directory for cleanup: %s" % normalized)
		return false
	directory.include_hidden = true
	var children: PackedStringArray = PackedStringArray()
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		var _append_list: bool = issues.append("Could not enumerate package transaction directory for cleanup: %s" % normalized)
		return false
	var child_name: String = directory.get_next()
	while not child_name.is_empty():
		if child_name != "." and child_name != "..":
			var _append_child: bool = children.append(normalized.path_join(child_name))
		child_name = directory.get_next()
	directory.list_dir_end()
	var ok: bool = true
	for child_path: String in children:
		if not _remove_tree(child_path, issues):
			ok = false
	if not ok:
		return false
	var directory_error: Error = DirAccess.remove_absolute(normalized)
	if directory_error != OK:
		var _append_directory: bool = issues.append("Could not remove package transaction directory: %s" % normalized)
		return false
	return true


static func _remove_empty_parents(directory_path: String, project_root: String) -> void:
	var current: String = _trim_trailing_separators(directory_path.replace("\\", "/").simplify_path())
	var root: String = _trim_trailing_separators(project_root.replace("\\", "/").simplify_path())
	while current != root and _is_path_inside(root, current):
		if _path_has_link_component(current):
			break
		if current == root.path_join("addons"):
			break
		if not DirAccess.dir_exists_absolute(current):
			current = current.get_base_dir()
			continue
		var remove_error: Error = DirAccess.remove_absolute(current)
		if remove_error != OK:
			break
		current = current.get_base_dir()


static func _remove_empty_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var _remove_error: Error = DirAccess.remove_absolute(path)


static func _append_cancelled_if_requested(options: Dictionary, issues: PackedStringArray) -> bool:
	var cancelled: bool = _GF_VARIANT_ACCESS.get_option_bool(options, "cancel_requested", false)
	var raw_callback: Variant = options.get("cancel_callback")
	if raw_callback is Callable:
		var callback: Callable = raw_callback
		if callback.is_valid():
			var callback_result: Variant = callback.call()
			cancelled = _GF_VARIANT_ACCESS.to_bool(callback_result, false)
	if not cancelled:
		return false
	if not issues.has(_CANCELLED_ISSUE):
		var _append_cancelled: bool = issues.append(_CANCELLED_ISSUE)
	return true


static func _should_inject_failure(options: Dictionary, phase: String) -> bool:
	return _GF_VARIANT_ACCESS.get_option_string(options, "simulate_transaction_failure_at") == phase


static func _should_inject_crash(options: Dictionary, phase: String) -> bool:
	return _GF_VARIANT_ACCESS.get_option_string(options, "simulate_transaction_crash_at") == phase


static func _append_string_array(target: PackedStringArray, values: PackedStringArray) -> void:
	for value: String in values:
		if not target.has(value):
			var _append_value: bool = target.append(value)


static func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
