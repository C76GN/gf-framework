## GFArtifactWriteTransaction: 编辑器与项目工具可复用的多产物文件提交事务。
##
## 在显式资源根、文件数量和字节预算内预检文本、字节或临时文件产物，
## 先把全部内容写入目标同目录的 staging 文件，再逐项替换目标。任一提交
## 失败时逆序恢复已有目标并删除本次新增目标。该类不解释产物格式、生成器
## 业务、导入策略或远端发布目标，也不把进程中断或系统崩溃下的多文件
## 持久化误称为 crash-atomic。GDScript 文件 API 无法固定父目录句柄，因此
## allowed_roots 必须位于调用方信任且不会被本机其他进程恶意交换 junction
## 的目录；实现会在 rename、删除和恢复前后复核可观察的路径、内容与 sidecar
## 身份，并在漂移时 fail closed，而不是盲目破坏未知文件。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFArtifactWriteTransaction
extends RefCounted


# --- 常量 ---

## 文本产物 entry 类型。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_TEXT: StringName = &"text"

## 字节产物 entry 类型。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_BYTES: StringName = &"bytes"

## 已有临时文件产物 entry 类型。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_FILE: StringName = &"file"

## 默认最大产物数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_FILE_COUNT: int = 256

## 默认单产物最大字节数。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_FILE_BYTES: int = 64 * 1024 * 1024

## 默认单批产物最大总字节数。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024

## 默认事务回滚快照最大总字节数。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024

## 单次事务允许的产物数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_FILE_COUNT: int = 1024

## 单个产物允许的字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_FILE_BYTES: int = 64 * 1024 * 1024

## 单次事务允许的产物总字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024

## 单次事务允许的回滚快照总字节数绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024

## 同一进程内允许保持 open 的事务绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_ACTIVE_TRANSACTIONS: int = 256

## 恢复报告要求调用 rollback()。
## [br]
## @api public
## [br]
## @since unreleased
const RECOVERY_ACTION_ROLLBACK: StringName = &"rollback"

## 恢复报告要求调用 complete()。
## [br]
## @api public
## [br]
## @since unreleased
const RECOVERY_ACTION_COMPLETE: StringName = &"complete"

const _TRANSACTION_FORMAT: String = "gf.artifact_write.transaction"
const _TRANSACTION_VERSION: int = 1
const _COPY_BUFFER_BYTES: int = 64 * 1024
const _GF_PATH_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

static var _active_transactions: Dictionary[String, Dictionary] = {}


# --- 公共方法 ---

## 创建文本产物 entry。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param text: UTF-8 文本内容。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
## [br]
## @schema return: Dictionary，包含 kind、target_path、text、overwrite、expected_sha256、artifact_id 和 metadata。
static func make_text_entry(
	target_path: String,
	text: String,
	options: Dictionary = {}
) -> Dictionary:
	return _make_entry(KIND_TEXT, target_path, text, PackedByteArray(), "", options)


## 创建字节产物 entry。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param bytes: 产物字节；entry 持有隔离副本。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
## [br]
## @schema return: Dictionary，包含 kind、target_path、bytes、overwrite、expected_sha256、artifact_id 和 metadata。
static func make_bytes_entry(
	target_path: String,
	bytes: PackedByteArray,
	options: Dictionary = {}
) -> Dictionary:
	return _make_entry(KIND_BYTES, target_path, "", bytes, "", options)


## 创建已有文件产物 entry。
## [br]
## source_path 只在 commit() 期间读取，不会被移动或删除。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param source_path: 已生成文件路径。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
## [br]
## @schema return: Dictionary，包含 kind、target_path、source_path、overwrite、expected_sha256、artifact_id 和 metadata。
static func make_file_entry(
	target_path: String,
	source_path: String,
	options: Dictionary = {}
) -> Dictionary:
	return _make_entry(KIND_FILE, target_path, "", PackedByteArray(), source_path, options)


## 预检一组产物 entry，不创建目录或写入文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param entries: make_text_entry()、make_bytes_entry() 或 make_file_entry() 创建的 entry。
## [br]
## @param options: 批次边界选项。
## [br]
## @return JSON-safe 预检报告。
## [br]
## @schema entries: Array[Dictionary]，每项包含 kind、target_path、对应内容和可选 entry 选项。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 overwrite_existing、max_file_count、max_file_bytes、max_total_bytes、max_backup_bytes、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema return: Dictionary，包含 ok、status、entry_count、changed_count、unchanged_count、total_bytes、backup_bytes、issues、entries 和 metadata。
static func get_preflight_report(
	entries: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = _normalize_entries(entries, options, false)
	return _make_preflight_boundary(normalized, options)


## 以运行期补偿事务提交一组产物。
##
## dry_run 为 true 时只执行完整预检。成功写入时全部 staging 文件均已校验，
## 目标替换失败会触发逆序回滚；回滚不完整会在报告中显式标记。
## 每个同目录 rename 是独立文件替换，多目标整体不提供 crash atomicity。
## 提交入口只允许在主线程调用，错误线程会在任何目录或文件写入前失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param entries: make_text_entry()、make_bytes_entry() 或 make_file_entry() 创建的 entry。
## [br]
## @param options: 批次边界选项。
## [br]
## @return JSON-safe 提交报告。
## [br]
## @schema entries: Array[Dictionary]，每项包含 kind、target_path、对应内容和可选 entry 选项。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 overwrite_existing、max_file_count、max_file_bytes、max_total_bytes、max_backup_bytes、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema return: Dictionary，包含 ok、status、entry_count、written_count、unchanged_count、total_bytes、backup_bytes、rolled_back、rollback_complete、recovery_required、recovery_action、recovery_transaction、issues、reports 和 metadata；recovery_required 为 true 时，调用方必须按 recovery_action 将 recovery_transaction 原样交给 rollback() 或 complete()。
static func commit(
	entries: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	if not Thread.is_main_thread():
		return _make_commit_boundary(
			_make_empty_normalized_failure(
				entries.size(),
				"Artifact transactions may only commit on the main thread."
			),
			{},
			&"wrong_thread"
		)
	var normalized: Dictionary = _normalize_entries(entries, options, true)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(normalized, "ok"):
		return _make_commit_boundary(normalized, options, &"preflight_failed")
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "dry_run"):
		return _make_commit_boundary(normalized, options, &"dry_run")

	var changed_entries: Array[Dictionary] = _get_changed_entries(normalized)
	if changed_entries.is_empty():
		return _make_commit_boundary(normalized, options, &"committed")
	var staging_result: Dictionary = _stage_entries(changed_entries)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(staging_result, "ok"):
		_merge_issues(
			normalized,
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(staging_result, "issues"))
		return _make_commit_boundary(normalized, options, &"staging_failed")

	var target_paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in changed_entries:
		var _target_appended: bool = target_paths.append(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path")
		)
	var transaction: Dictionary = begin(target_paths, options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"):
		_merge_issues(
			normalized,
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(transaction, "issues"))
		return _make_commit_boundary(normalized, options, &"snapshot_failed")
	_enable_selective_rollback(transaction)

	var replace_result: Dictionary = _replace_staged_entries(
		changed_entries,
		transaction
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(replace_result, "ok"):
		var rollback_result: Dictionary = rollback(transaction)
		_merge_issues(
			normalized,
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(replace_result, "issues"))
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(rollback_result, "issues"))
		var rollback_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			rollback_result,
			"ok"
		)
		normalized["rolled_back"] = rollback_ok
		normalized["rollback_complete"] = rollback_ok
		if not rollback_ok and _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			rollback_result,
			"recovery_required"
		):
			normalized["recovery_required"] = true
			normalized["recovery_action"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
					rollback_result,
					"recovery_action"
				)
			)
			normalized["recovery_transaction"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					rollback_result,
					"recovery_transaction"
				).duplicate(true)
			)
		return _make_commit_boundary(normalized, options, &"commit_failed")

	var complete_result: Dictionary = complete(transaction)
	_merge_issues(
		normalized,
		_cleanup_entry_sidecars(changed_entries, "staging_path")
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(complete_result, "ok"):
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(complete_result, "issues"))
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			complete_result,
			"recovery_required"
		):
			normalized["recovery_required"] = true
			normalized["recovery_action"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
					complete_result,
					"recovery_action"
				)
			)
			normalized["recovery_transaction"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					complete_result,
					"recovery_transaction"
				).duplicate(true)
			)
		return _make_commit_boundary(normalized, options, &"cleanup_failed", changed_entries.size())

	_scan_filesystem_if_needed(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "scan_filesystem", true))
	return _make_commit_boundary(normalized, options, &"committed", changed_entries.size())


## 捕获一组外部写入目标的事务前状态。
##
## 适合调用方必须使用 ResourceSaver 或其他专用 materializer 写最终目标的场景。
## begin() 成功后，调用方必须且只能调用 complete() 或 rollback() 之一。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param paths: 本次外部事务可能创建或覆盖的完整文件路径。
## [br]
## @param options: 快照边界选项。
## [br]
## @return 只能原样交给 complete() 或 rollback() 的完整性校验事务字典；调用方不得改写。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
## [br]
## @schema return: opaque Dictionary，包含 ok、format、format_version、state、transaction_id、transaction_token、entry_count、backup_bytes 和 metadata；不暴露目标或备份路径。
static func begin(
	paths: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	if not Thread.is_main_thread():
		return _make_begin_failure(
			"Artifact transactions may only be opened on the main thread.",
			{}
		)
	if _active_transactions.size() >= ABSOLUTE_MAX_ACTIVE_TRANSACTIONS:
		return _make_begin_failure(
			"Artifact transaction active-session capacity is exhausted.",
			options
		)
	var path_report: Dictionary = _normalize_transaction_paths(paths, options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(path_report, "ok"):
		return path_report

	var transaction_id: String = _make_unique_transaction_id()
	if transaction_id.is_empty():
		return _make_begin_failure(
			"Artifact transaction identity could not be allocated.",
			options
		)
	var snapshots: Array[Dictionary] = []
	for entry: Dictionary in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(path_report, "entries"):
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
		var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"existed"
		)
		var snapshot_state_error: String = _get_snapshot_source_state_error(entry)
		if not snapshot_state_error.is_empty():
			var state_cleanup_issues: PackedStringArray = _discard_transaction_backups(
				snapshots
			)
			var state_issues: PackedStringArray = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
					path_report,
					"issues"
				)
			)
			var _state_issue_appended: bool = state_issues.append(
				snapshot_state_error
			)
			for cleanup_issue: String in state_cleanup_issues:
				var _cleanup_appended: bool = state_issues.append(cleanup_issue)
			path_report["ok"] = false
			path_report["state"] = "failed"
			path_report["entries"] = []
			path_report["issues"] = state_issues
			return path_report
		var backup_path: String = ""
		if existed:
			backup_path = _make_sidecar_path(target_path, "backup", transaction_id, snapshots.size())
			var copy_error: Error = _copy_file(
				target_path,
				backup_path,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					entry,
					"size_bytes"
				),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"sha256"
				)
			)
			if copy_error != OK:
				var cleanup_issues: PackedStringArray = _discard_transaction_backups(snapshots)
				var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(path_report, "issues")
				var _issue_appended: bool = issues.append(
					"Could not snapshot artifact target %s: %s" % [
						target_path,
						error_string(copy_error),
					]
				)
				for cleanup_issue: String in cleanup_issues:
					var _cleanup_appended: bool = issues.append(cleanup_issue)
				path_report["ok"] = false
				path_report["state"] = "failed"
				path_report["entries"] = []
				path_report["issues"] = issues
				return path_report
		snapshots.append({
			"path": target_path,
			"existed": existed,
			"backup_path": backup_path,
			"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				entry,
				"size_bytes"
			),
			"sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"sha256"
			),
			"rollback_expected_state_known": false,
			"rollback_expected_existed": false,
			"rollback_expected_size_bytes": 0,
			"rollback_expected_sha256": "",
		})

	var handle: Dictionary = {
		"ok": true,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "open",
		"transaction_id": transaction_id,
		"transaction_token": _make_transaction_id(),
		"entry_count": snapshots.size(),
		"backup_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			path_report,
			"backup_bytes"
		),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			path_report,
			"metadata"
		).duplicate(true),
	}
	_active_transactions[transaction_id] = {
		"handle": handle.duplicate(true),
		"entries": snapshots,
		"terminal_mode": &"",
		"has_rollback_filter": false,
		"rollback_only_paths": PackedStringArray(),
	}
	return handle.duplicate(true)


## 逆序恢复 begin() 捕获的全部目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param transaction: begin() 返回且处于 open 状态的原始事务字典；任何改写都会失败。
## [br]
## @return 回滚报告。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction；recovery_required 为 true 时必须按 recovery_action 使用 recovery_transaction 重试要求的终态动作。
static func rollback(transaction: Dictionary) -> Dictionary:
	if not Thread.is_main_thread():
		return _make_transaction_action_report(
			false,
			&"wrong_thread",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray([
				"Artifact transactions may only be rolled back on the main thread.",
			])
		)
	var validation_error: String = _get_transaction_validation_error(transaction)
	if not validation_error.is_empty():
		return _make_transaction_action_report(false, &"invalid_transaction", PackedStringArray(), PackedStringArray(), PackedStringArray([validation_error]))

	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	var active_state: Dictionary = _active_transactions[transaction_id]
	var terminal_mode: StringName = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			active_state,
			"terminal_mode"
		)
	)
	if terminal_mode == RECOVERY_ACTION_COMPLETE:
		return _make_transaction_action_report(
			false,
			&"completion_required",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray([
				"Artifact transaction cleanup already started and must be completed.",
			]),
			transaction,
			RECOVERY_ACTION_COMPLETE
		)
	var restored_paths: PackedStringArray = PackedStringArray()
	var failed_paths: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	var entries: Array[Dictionary] = _get_transaction_entries(active_state)
	var rollback_only_paths: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			active_state,
			"rollback_only_paths"
		)
	)
	var has_rollback_filter: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		active_state,
		"has_rollback_filter"
	)
	issues = _get_rollback_preflight_issues(
		entries,
		has_rollback_filter,
		rollback_only_paths
	)
	if not issues.is_empty():
		return _make_transaction_action_report(
			false,
			&"rollback_preflight_failed",
			PackedStringArray(),
			PackedStringArray(),
			issues,
			transaction,
			RECOVERY_ACTION_ROLLBACK
		)

	active_state["terminal_mode"] = RECOVERY_ACTION_ROLLBACK
	_active_transactions[transaction_id] = active_state
	for entry_index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[entry_index]
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
		var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "existed")
		var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "backup_path")
		if has_rollback_filter and not rollback_only_paths.has(target_path):
			var discard_error: Error = _remove_transaction_backup(entry, true)
			if discard_error != OK:
				var _discard_failed_appended: bool = failed_paths.append(target_path)
				var _discard_issue_appended: bool = issues.append(
					"Could not discard an unused artifact snapshot for %s: %s" % [
						target_path,
						error_string(discard_error),
					]
				)
				_retain_transaction_entries(
					transaction_id,
					active_state,
					entries,
					0,
					entry_index + 1
				)
				return _make_transaction_action_report(
					false,
					&"rollback_failed",
					restored_paths,
					failed_paths,
					issues,
					transaction,
					RECOVERY_ACTION_ROLLBACK
				)
			continue
		var operation_error: Error = _get_observed_target_state_error(entry)
		if operation_error == OK and existed:
			operation_error = _get_transaction_backup_error(entry, false)
		if operation_error == OK:
			operation_error = _remove_file_path(target_path)
		if operation_error == OK and existed:
			operation_error = DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(target_path)
			)
		if operation_error == OK:
			operation_error = _get_restored_target_error(entry)
		if operation_error == OK:
			var _restored_appended: bool = restored_paths.append(target_path)
		else:
			var _failed_appended: bool = failed_paths.append(target_path)
			var _issue_appended: bool = issues.append(
				"Could not restore artifact target %s: %s" % [
					target_path,
					error_string(operation_error),
				]
			)
			_retain_transaction_entries(
				transaction_id,
				active_state,
				entries,
				0,
				entry_index + 1
			)
			return _make_transaction_action_report(
				false,
				&"rollback_failed",
				restored_paths,
				failed_paths,
				issues,
				transaction,
				RECOVERY_ACTION_ROLLBACK
			)
	var _active_erased: bool = _active_transactions.erase(transaction_id)
	return _make_transaction_action_report(
		true,
		&"rolled_back",
		restored_paths,
		failed_paths,
		issues
	)


## 完成 begin() 捕获的事务并删除回滚快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param transaction: begin() 返回且处于 open 状态的原始事务字典；任何改写都会失败。
## [br]
## @return 完成报告。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction；recovery_required 为 true 时 recovery_action 为 complete，必须使用 recovery_transaction 重试 complete()。
static func complete(transaction: Dictionary) -> Dictionary:
	if not Thread.is_main_thread():
		return _make_transaction_action_report(
			false,
			&"wrong_thread",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray([
				"Artifact transactions may only be completed on the main thread.",
			])
		)
	var validation_error: String = _get_transaction_validation_error(transaction)
	if not validation_error.is_empty():
		return _make_transaction_action_report(false, &"invalid_transaction", PackedStringArray(), PackedStringArray(), PackedStringArray([validation_error]))
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	var active_state: Dictionary = _active_transactions[transaction_id]
	var terminal_mode: StringName = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			active_state,
			"terminal_mode"
		)
	)
	if terminal_mode == RECOVERY_ACTION_ROLLBACK:
		return _make_transaction_action_report(
			false,
			&"rollback_required",
			PackedStringArray(),
			PackedStringArray(),
			PackedStringArray([
				"Artifact transaction rollback already started and must be completed.",
			]),
			transaction,
			RECOVERY_ACTION_ROLLBACK
		)
	active_state["terminal_mode"] = RECOVERY_ACTION_COMPLETE
	_active_transactions[transaction_id] = active_state
	var entries: Array[Dictionary] = _get_transaction_entries(active_state)
	var failed_paths: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	for entry_index: int in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"backup_path"
		)
		if backup_path.is_empty():
			continue
		var remove_error: Error = _remove_transaction_backup(entry, true)
		if remove_error == OK:
			continue
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"path"
		)
		var _failed_path_appended: bool = failed_paths.append(target_path)
		var _issue_appended: bool = issues.append(
			"Could not remove the artifact snapshot for %s: %s." % [
				target_path,
				error_string(remove_error),
			]
		)
		_retain_transaction_entries(
			transaction_id,
			active_state,
			entries,
			entry_index,
			entries.size()
		)
		return _make_transaction_action_report(
			false,
			&"cleanup_failed",
			PackedStringArray(),
			failed_paths,
			issues,
			transaction,
			RECOVERY_ACTION_COMPLETE
		)
	var _active_erased: bool = _active_transactions.erase(transaction_id)
	return _make_transaction_action_report(
		true,
		&"committed",
		PackedStringArray(),
		failed_paths,
		issues
	)


# --- 私有/辅助方法 ---

static func _make_entry(
	kind: StringName,
	target_path: String,
	text: String,
	bytes: PackedByteArray,
	source_path: String,
	options: Dictionary
) -> Dictionary:
	var entry: Dictionary = {
		"kind": kind,
		"target_path": target_path,
		"text": text,
		"bytes": bytes.duplicate(),
		"source_path": source_path,
		"expected_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "expected_sha256").strip_edges().to_lower(),
		"artifact_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "artifact_id"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
	}
	if options.has("overwrite") or options.has(&"overwrite"):
		entry["overwrite"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			options,
			"overwrite",
			true
		)
	return entry


static func _normalize_entries(
	entries: Array[Dictionary],
	options: Dictionary,
	include_bytes: bool
) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var normalized_entries: Array[Dictionary] = []
	var max_file_count: int = _bounded_limit_option(
		options,
		"max_file_count",
		DEFAULT_MAX_FILE_COUNT,
		ABSOLUTE_MAX_FILE_COUNT
	)
	var max_file_bytes: int = _bounded_limit_option(
		options,
		"max_file_bytes",
		DEFAULT_MAX_FILE_BYTES,
		ABSOLUTE_MAX_FILE_BYTES
	)
	var max_total_bytes: int = _bounded_limit_option(
		options,
		"max_total_bytes",
		DEFAULT_MAX_TOTAL_BYTES,
		ABSOLUTE_MAX_TOTAL_BYTES
	)
	var max_backup_bytes: int = _bounded_limit_option(
		options,
		"max_backup_bytes",
		DEFAULT_MAX_BACKUP_BYTES,
		ABSOLUTE_MAX_BACKUP_BYTES,
		true
	)
	if entries.is_empty():
		var _empty_issue_appended: bool = issues.append(
			"Artifact transaction requires at least one entry."
		)
	if max_file_count < 1:
		var _file_count_budget_issue_appended: bool = issues.append(
			"max_file_count must be an exact int within the framework limit."
		)
	if max_file_bytes < 1:
		var _file_budget_issue_appended: bool = issues.append(
			"max_file_bytes must be an exact int within the framework limit."
		)
	if max_total_bytes < 1:
		var _total_budget_issue_appended: bool = issues.append(
			"max_total_bytes must be an exact int within the framework limit."
		)
	if max_backup_bytes < 0:
		var _backup_budget_issue_appended: bool = issues.append(
			"max_backup_bytes must be an exact int within the framework limit."
		)
	max_file_count = maxi(max_file_count, 1)
	max_file_bytes = maxi(max_file_bytes, 1)
	max_total_bytes = maxi(max_total_bytes, 1)
	max_backup_bytes = maxi(max_backup_bytes, 0)
	if entries.size() > max_file_count:
		var _count_issue_appended: bool = issues.append(
			"Artifact entry count exceeds max_file_count: %d > %d." % [
				entries.size(),
				max_file_count,
			]
		)
	if not issues.is_empty():
		var rejected_entries: Array[Dictionary] = []
		return _make_normalized_entries_result(
			false,
			rejected_entries,
			entries.size(),
			0,
			0,
			0,
			0,
			issues
		)

	var portable_targets: Dictionary = {}
	var total_bytes: int = 0
	var backup_bytes: int = 0
	var changed_count: int = 0
	var unchanged_count: int = 0
	for entry_index: int in range(entries.size()):
		var entry: Dictionary = entries[entry_index].duplicate(false)
		var target_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path")
		)
		var path_error: String = _get_target_path_error(target_path, options)
		if not path_error.is_empty():
			var _path_issue_appended: bool = issues.append(
				"Artifact entry %d: %s" % [entry_index, path_error]
			)
			continue
		var portable_identity: String = target_path.to_lower()
		if portable_targets.has(portable_identity):
			var _duplicate_issue_appended: bool = issues.append(
				"Artifact target is duplicated under portable identity: %s." % target_path
			)
			continue
		portable_targets[portable_identity] = true

		var kind: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "kind")
		var remaining_total_bytes: int = max_total_bytes - total_bytes
		if remaining_total_bytes <= 0:
			var _total_exhausted_issue_appended: bool = issues.append(
				"Artifact payload bytes exceed max_total_bytes."
			)
			break
		var bytes_result: Dictionary = _read_entry_bytes(
			entry,
			kind,
			mini(max_file_bytes, remaining_total_bytes),
			include_bytes
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(bytes_result, "ok"):
			var _bytes_issue_appended: bool = issues.append(
				"Artifact entry %d: %s" % [
					entry_index,
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(bytes_result, "error"),
				]
			)
			continue
		var size_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(bytes_result, "size_bytes")
		total_bytes += size_bytes
		if total_bytes > max_total_bytes:
			var _total_issue_appended: bool = issues.append(
				"Artifact payload bytes exceed max_total_bytes: %d > %d." % [
					total_bytes,
					max_total_bytes,
				]
			)
			continue
		var content_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(bytes_result, "sha256")
		var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "expected_sha256").strip_edges().to_lower()
		if not expected_sha256.is_empty() and (
			not _is_sha256(expected_sha256)
			or expected_sha256 != content_sha256
		):
			var _hash_issue_appended: bool = issues.append(
				"Artifact entry %d expected_sha256 does not match its content." % entry_index
			)
			continue

		var existed: bool = FileAccess.file_exists(target_path)
		var existing_size: int = _file_size(target_path) if existed else 0
		if (
			existed
			and existing_size >= 0
			and existing_size != size_bytes
			and existing_size > max_backup_bytes - backup_bytes
		):
			var _early_backup_issue_appended: bool = issues.append(
				"Artifact rollback snapshots exceed max_backup_bytes: %d > %d." % [
					backup_bytes + existing_size,
					max_backup_bytes,
				]
			)
			continue
		var previous_sha256: String = (
			FileAccess.get_sha256(target_path).to_lower()
			if existed
			else ""
		)
		if existed and (existing_size < 0 or previous_sha256.is_empty()):
			var _existing_read_issue_appended: bool = issues.append(
				"Artifact target could not be read for preflight: %s." % target_path
			)
			continue
		var changed: bool = not existed or previous_sha256 != content_sha256
		var overwrite: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"overwrite",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "overwrite_existing", true)
		)
		if existed and changed and not overwrite:
			var _overwrite_issue_appended: bool = issues.append(
				"Artifact target exists and overwrite is disabled: %s." % target_path
			)
			continue
		if existed and changed:
			if existing_size > max_backup_bytes - backup_bytes:
				var _changed_backup_issue_appended: bool = issues.append(
					"Artifact rollback snapshots exceed max_backup_bytes: %d > %d." % [
						backup_bytes + existing_size,
						max_backup_bytes,
					]
				)
				continue
			backup_bytes += existing_size
		if changed:
			changed_count += 1
		else:
			unchanged_count += 1

		entry["target_path"] = target_path
		entry["size_bytes"] = size_bytes
		entry["content_sha256"] = content_sha256
		entry["previous_sha256"] = previous_sha256
		entry["changed"] = changed
		entry["existed"] = existed
		var resolved_source_path: String = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				bytes_result,
				"source_path"
			)
		)
		var _text_erased: bool = entry.erase("text")
		var _bytes_erased: bool = entry.erase("bytes")
		var _source_path_erased: bool = entry.erase("source_path")
		if include_bytes:
			if kind == KIND_FILE:
				entry["resolved_source_path"] = resolved_source_path
			else:
				entry["resolved_bytes"] = _get_packed_byte_array(
					bytes_result,
					"bytes"
				)
		normalized_entries.append(entry)

	if backup_bytes > max_backup_bytes:
		var _backup_issue_appended: bool = issues.append(
			"Artifact rollback snapshots exceed max_backup_bytes: %d > %d." % [
				backup_bytes,
				max_backup_bytes,
			]
		)
	return _make_normalized_entries_result(
		issues.is_empty() and normalized_entries.size() == entries.size(),
		normalized_entries,
		entries.size(),
		changed_count,
		unchanged_count,
		total_bytes,
		backup_bytes,
		issues
	)


static func _read_entry_bytes(
	entry: Dictionary,
	kind: StringName,
	max_file_bytes: int,
	include_bytes: bool
) -> Dictionary:
	var bytes: PackedByteArray = PackedByteArray()
	if kind == KIND_TEXT:
		var text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "text")
		if text.length() > max_file_bytes:
			return _make_bytes_result(
				false,
				PackedByteArray(),
				"Artifact text exceeds the entry byte budget."
			)
		bytes = text.to_utf8_buffer()
	elif kind == KIND_BYTES:
		var bytes_value: Variant = entry.get("bytes")
		if not bytes_value is PackedByteArray:
			return _make_bytes_result(
				false,
				PackedByteArray(),
				"Artifact bytes payload is invalid."
			)
		bytes = bytes_value
		if bytes.size() > max_file_bytes:
			return _make_bytes_result(
				false,
				PackedByteArray(),
				"Artifact bytes exceed the entry byte budget."
			)
	elif kind == KIND_FILE:
		var source_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "source_path")
		)
		if source_path.is_empty() or not FileAccess.file_exists(source_path):
			return _make_bytes_result(false, PackedByteArray(), "Artifact source file is missing.")
		if _path_has_link_component(source_path):
			return _make_bytes_result(false, PackedByteArray(), "Artifact source file crosses a filesystem link.")
		var source_size: int = _file_size(source_path)
		if source_size < 0 or source_size > max_file_bytes:
			return _make_bytes_result(
				false,
				PackedByteArray(),
				"Artifact source file exceeds the entry byte budget."
			)
		var source_sha256: String = FileAccess.get_sha256(source_path).to_lower()
		if source_sha256.is_empty():
			return _make_bytes_result(
				false,
				PackedByteArray(),
				"Artifact source file could not be hashed."
			)
		return {
			"ok": true,
			"bytes": PackedByteArray(),
			"source_path": source_path,
			"size_bytes": source_size,
			"sha256": source_sha256,
			"error": "",
		}
	else:
		return _make_bytes_result(false, PackedByteArray(), "Artifact kind is unsupported.")
	if bytes.size() > max_file_bytes:
		return _make_bytes_result(
			false,
			PackedByteArray(),
			"Artifact payload exceeds the entry byte budget."
		)
	return _make_bytes_result(true, bytes, "", include_bytes)


static func _make_bytes_result(
	ok: bool,
	bytes: PackedByteArray,
	error: String,
	include_bytes: bool = true
) -> Dictionary:
	return {
		"ok": ok,
		"bytes": bytes if include_bytes else PackedByteArray(),
		"source_path": "",
		"size_bytes": bytes.size(),
		"sha256": _sha256_bytes(bytes) if ok else "",
		"error": error,
	}


static func _make_normalized_entries_result(
	ok: bool,
	entries: Array[Dictionary],
	entry_count: int,
	changed_count: int,
	unchanged_count: int,
	total_bytes: int,
	backup_bytes: int,
	issues: PackedStringArray
) -> Dictionary:
	return {
		"ok": ok,
		"entries": entries,
		"entry_count": entry_count,
		"changed_count": changed_count,
		"unchanged_count": unchanged_count,
		"total_bytes": total_bytes,
		"backup_bytes": backup_bytes,
		"issues": issues,
		"rolled_back": false,
		"rollback_complete": true,
		"recovery_required": false,
		"recovery_action": &"",
		"recovery_transaction": {},
	}


static func _make_empty_normalized_failure(
	entry_count: int,
	issue: String
) -> Dictionary:
	return _make_normalized_entries_result(
		false,
		[],
		maxi(entry_count, 0),
		0,
		0,
		0,
		0,
		PackedStringArray([issue])
	)


static func _get_target_path_error(target_path: String, options: Dictionary) -> String:
	if target_path.is_empty():
		return "Artifact target path is empty."
	if not (target_path.begins_with("res://") or target_path.begins_with("user://")):
		return "Artifact target path must use res:// or user://."
	if target_path.ends_with("/") or target_path.get_file().is_empty():
		return "Artifact target path must identify a file."
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_path)):
		return "Artifact target path identifies an existing directory."
	for component: String in target_path.trim_prefix("res://").trim_prefix("user://").split("/", false):
		if not _portable_component_is_valid(component):
			return "Artifact target contains a non-portable path component: %s." % component
	var allowed_roots_report: Dictionary = _read_allowed_roots(options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(allowed_roots_report, "ok"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(allowed_roots_report, "error")
	var allowed_roots: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			allowed_roots_report,
			"roots"
		)
	)
	if not allowed_roots.is_empty():
		var inside_allowed_root: bool = false
		for allowed_root: String in allowed_roots:
			if _path_is_under_allowed_root(target_path, allowed_root):
				inside_allowed_root = true
				break
		if not inside_allowed_root:
			return "Artifact target is outside allowed_roots: %s." % target_path
	if _path_has_link_component(target_path):
		return "Artifact target crosses a filesystem link: %s." % target_path
	return ""


static func _read_allowed_roots(options: Dictionary) -> Dictionary:
	var roots: PackedStringArray = PackedStringArray()
	var has_allowed_roots: bool = (
		options.has("allowed_roots")
		or options.has(&"allowed_roots")
	)
	if not has_allowed_roots:
		return {
			"ok": false,
			"roots": roots,
			"error": "allowed_roots is required for artifact transactions.",
		}
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		options,
		"allowed_roots"
	)
	if not (
		raw_value is Array
		or raw_value is PackedStringArray
		or raw_value is String
		or raw_value is StringName
	):
		return {
			"ok": false,
			"roots": roots,
			"error": "allowed_roots must be a non-empty resource root collection.",
		}
	var raw_roots: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			options,
			"allowed_roots"
		)
	)
	if raw_roots.is_empty():
		return {
			"ok": false,
			"roots": roots,
			"error": "allowed_roots must not be empty when provided.",
		}
	for raw_root: String in raw_roots:
		var root_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_root_path(raw_root)
		if (
			root_path.is_empty()
			or not (
				root_path.begins_with("res://")
				or root_path.begins_with("user://")
			)
		):
			return {
				"ok": false,
				"roots": PackedStringArray(),
				"error": "allowed_roots contains an invalid resource root.",
			}
		if roots.has(root_path):
			continue
		var _root_appended: bool = roots.append(root_path)
	return {
		"ok": true,
		"roots": roots,
		"error": "",
	}


static func _path_is_under_allowed_root(path: String, root_path: String) -> bool:
	if root_path.ends_with("://"):
		return path.begins_with(root_path)
	return _GF_PATH_TOOLS_SCRIPT.is_path_under_root(path, root_path, false, false)


static func _get_changed_entries(normalized: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(normalized, "entries"):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "changed"):
			result.append(entry)
	return result


static func _stage_entries(entries: Array[Dictionary]) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var transaction_id: String = _make_transaction_id()
	for entry_index: int in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path")
		var directory_path: String = target_path.get_base_dir()
		var make_error: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory_path)
		)
		if make_error != OK or _path_has_link_component(directory_path):
			var _directory_issue_appended: bool = issues.append(
				"Could not prepare artifact target directory: %s." % directory_path
			)
			break
		var staging_path: String = _make_sidecar_path(
			target_path,
			"staging",
			transaction_id,
			entry_index
		)
		entry["staging_path"] = staging_path
		var size_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"size_bytes",
			-1
		)
		var content_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"content_sha256"
		)
		var write_error: Error = OK
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "kind")
			== KIND_FILE
		):
			write_error = _copy_file(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"resolved_source_path"
				),
				staging_path,
				size_bytes,
				content_sha256
			)
		else:
			var bytes: PackedByteArray = _get_packed_byte_array(
				entry,
				"resolved_bytes"
			)
			write_error = _write_bytes(staging_path, bytes)
		if (
			write_error != OK
			or _file_size(staging_path) != size_bytes
			or FileAccess.get_sha256(staging_path).to_lower()
			!= content_sha256
		):
			var _write_issue_appended: bool = issues.append(
				"Could not stage artifact target %s." % target_path
			)
			break
	return {
		"ok": issues.is_empty(),
		"issues": issues,
	}


static func _replace_staged_entries(
	entries: Array[Dictionary],
	transaction: Dictionary
) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path")
		var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "staging_path")
		var target_state_error: String = _get_target_state_error(entry)
		if not target_state_error.is_empty():
			var _state_issue_appended: bool = issues.append(target_state_error)
			break
		var staging_state_error: String = _get_staging_state_error(entry)
		if not staging_state_error.is_empty():
			var _staging_issue_appended: bool = issues.append(
				staging_state_error
			)
			break
		var remove_error: Error = _remove_file_path(target_path)
		if remove_error != OK:
			var _remove_issue_appended: bool = issues.append(
				"Could not replace artifact target %s: %s." % [
					target_path,
					error_string(remove_error),
				]
			)
			break
		_mark_transaction_path_modified(
			transaction,
			target_path,
			false,
			0,
			""
		)
		staging_state_error = _get_staging_state_error(entry)
		if not staging_state_error.is_empty():
			var _rename_boundary_issue_appended: bool = issues.append(
				staging_state_error
			)
			break
		var rename_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(staging_path),
			ProjectSettings.globalize_path(target_path)
		)
		if rename_error != OK:
			var _rename_issue_appended: bool = issues.append(
				"Could not commit artifact target %s: %s." % [
					target_path,
					error_string(rename_error),
				]
			)
			break
		entry["staging_path"] = ""
		var committed_state_error: String = _get_committed_target_state_error(
			entry
		)
		if not committed_state_error.is_empty():
			var _committed_state_issue_appended: bool = issues.append(
				committed_state_error
			)
			break
		_mark_transaction_path_modified(
			transaction,
			target_path,
			true,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				entry,
				"size_bytes"
			),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"content_sha256"
			)
		)
	return {
		"ok": issues.is_empty(),
		"issues": issues,
	}


static func _get_target_state_error(entry: Dictionary) -> String:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"target_path"
	)
	var expected_existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		entry,
		"existed"
	)
	var absolute_path: String = ProjectSettings.globalize_path(target_path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return "Artifact target became a directory before commit: %s." % target_path
	var exists_now: bool = FileAccess.file_exists(target_path)
	if exists_now != expected_existed:
		return "Artifact target existence changed before commit: %s." % target_path
	if not exists_now:
		return ""
	var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"previous_sha256"
	)
	var current_sha256: String = FileAccess.get_sha256(target_path).to_lower()
	if current_sha256.is_empty() or current_sha256 != expected_sha256:
		return "Artifact target content changed before commit: %s." % target_path
	return ""


static func _get_staging_state_error(entry: Dictionary) -> String:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"target_path"
	)
	var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"staging_path"
	)
	if (
		staging_path.is_empty()
		or staging_path.get_base_dir() != target_path.get_base_dir()
		or not staging_path.begins_with(
			"%s.gf-artifact-staging-" % target_path
		)
		or _path_has_link_component(target_path)
		or _path_has_link_component(staging_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(staging_path)
		)
		or not FileAccess.file_exists(staging_path)
	):
		return "Artifact staging identity changed before commit: %s." % target_path
	var expected_size: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		entry,
		"size_bytes",
		-1
	)
	var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"content_sha256"
	)
	if (
		expected_size < 0
		or not _is_sha256(expected_sha256)
		or _file_size(staging_path) != expected_size
		or FileAccess.get_sha256(staging_path).to_lower()
		!= expected_sha256
	):
		return "Artifact staging content changed before commit: %s." % target_path
	return ""


static func _get_committed_target_state_error(entry: Dictionary) -> String:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"target_path"
	)
	if (
		_path_has_link_component(target_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(target_path)
		)
		or not FileAccess.file_exists(target_path)
	):
		return "Artifact target identity changed during commit: %s." % target_path
	var expected_size: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		entry,
		"size_bytes",
		-1
	)
	var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"content_sha256"
	)
	if (
		expected_size < 0
		or not _is_sha256(expected_sha256)
		or _file_size(target_path) != expected_size
		or FileAccess.get_sha256(target_path).to_lower()
		!= expected_sha256
	):
		return "Artifact target content changed during commit: %s." % target_path
	return ""


static func _get_snapshot_source_state_error(entry: Dictionary) -> String:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"path"
	)
	var absolute_path: String = ProjectSettings.globalize_path(target_path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return "Artifact transaction target became a directory before snapshot: %s." % target_path
	var expected_existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		entry,
		"existed"
	)
	var exists_now: bool = FileAccess.file_exists(target_path)
	if exists_now != expected_existed:
		return "Artifact transaction target existence changed before snapshot: %s." % target_path
	if not exists_now:
		return ""
	var expected_size: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		entry,
		"size_bytes",
		-1
	)
	var current_size: int = _file_size(target_path)
	if current_size < 0 or current_size != expected_size:
		return "Artifact transaction target size changed before snapshot: %s." % target_path
	var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"sha256"
	)
	var current_sha256: String = FileAccess.get_sha256(target_path).to_lower()
	if current_sha256.is_empty() or current_sha256 != expected_sha256:
		return "Artifact transaction target content changed before snapshot: %s." % target_path
	return ""


static func _mark_transaction_path_modified(
	transaction: Dictionary,
	target_path: String,
	expected_existed: bool,
	expected_size: int,
	expected_sha256: String
) -> void:
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	if not _active_transactions.has(transaction_id):
		return
	var active_state: Dictionary = _active_transactions[transaction_id]
	var modified_paths: PackedStringArray = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			active_state,
			"rollback_only_paths"
		)
	)
	if not modified_paths.has(target_path):
		var _path_appended: bool = modified_paths.append(target_path)
	var stored_entries_value: Variant = active_state.get("entries")
	if stored_entries_value is Array:
		var stored_entries: Array = stored_entries_value
		for entry_index: int in range(stored_entries.size()):
			if not stored_entries[entry_index] is Dictionary:
				continue
			var stored_entry: Dictionary = stored_entries[entry_index]
			if (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					stored_entry,
					"path"
				)
				!= target_path
			):
				continue
			stored_entry["rollback_expected_state_known"] = true
			stored_entry["rollback_expected_existed"] = expected_existed
			stored_entry["rollback_expected_size_bytes"] = (
				expected_size if expected_existed else 0
			)
			stored_entry["rollback_expected_sha256"] = (
				expected_sha256 if expected_existed else ""
			)
			stored_entries[entry_index] = stored_entry
			break
		active_state["entries"] = stored_entries
	active_state["rollback_only_paths"] = modified_paths
	_active_transactions[transaction_id] = active_state


static func _enable_selective_rollback(transaction: Dictionary) -> void:
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	if not _active_transactions.has(transaction_id):
		return
	var active_state: Dictionary = _active_transactions[transaction_id]
	active_state["has_rollback_filter"] = true
	active_state["rollback_only_paths"] = PackedStringArray()
	_active_transactions[transaction_id] = active_state


static func _normalize_transaction_paths(
	paths: PackedStringArray,
	options: Dictionary
) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var entries: Array[Dictionary] = []
	var identities: Dictionary = {}
	var max_file_count: int = _bounded_limit_option(
		options,
		"max_file_count",
		DEFAULT_MAX_FILE_COUNT,
		ABSOLUTE_MAX_FILE_COUNT
	)
	var max_backup_bytes: int = _bounded_limit_option(
		options,
		"max_backup_bytes",
		DEFAULT_MAX_BACKUP_BYTES,
		ABSOLUTE_MAX_BACKUP_BYTES,
		true
	)
	if paths.is_empty():
		var _empty_issue_appended: bool = issues.append(
			"Artifact transaction requires at least one target path."
		)
	if max_file_count < 1:
		var _file_count_budget_issue_appended: bool = issues.append(
			"max_file_count must be an exact int within the framework limit."
		)
	max_file_count = maxi(max_file_count, 1)
	if paths.size() > max_file_count:
		var _count_issue_appended: bool = issues.append(
			"Artifact transaction path count exceeds max_file_count."
		)
	if max_backup_bytes < 0:
		var _backup_budget_issue_appended: bool = issues.append(
			"max_backup_bytes must be an exact int within the framework limit."
		)
	max_backup_bytes = maxi(max_backup_bytes, 0)
	if not issues.is_empty():
		return {
			"ok": false,
			"format": _TRANSACTION_FORMAT,
			"format_version": _TRANSACTION_VERSION,
			"state": "failed",
			"entries": entries,
			"backup_bytes": 0,
			"issues": issues,
			"metadata": _to_report_metadata(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					options,
					"metadata"
				)
			),
		}
	var backup_bytes: int = 0
	for path: String in paths:
		if path.is_empty():
			var _empty_path_issue_appended: bool = issues.append(
				"Artifact transaction target path is empty."
			)
			continue
		var target_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(path)
		var path_error: String = _get_target_path_error(target_path, options)
		if not path_error.is_empty():
			var _path_issue_appended: bool = issues.append(path_error)
			continue
		var identity: String = target_path.to_lower()
		if identities.has(identity):
			var _duplicate_issue_appended: bool = issues.append(
				"Artifact transaction target is duplicated: %s." % target_path
			)
			continue
		identities[identity] = true
		var existed: bool = FileAccess.file_exists(target_path)
		var target_size: int = 0
		var target_sha256: String = ""
		if existed:
			target_size = _file_size(target_path)
			if target_size < 0:
				var _target_read_issue_appended: bool = issues.append(
					"Artifact transaction target could not be read: %s." % target_path
				)
				continue
			if target_size > max_backup_bytes - backup_bytes:
				var _backup_issue_appended: bool = issues.append(
					"Artifact transaction snapshots exceed max_backup_bytes."
				)
				continue
			target_sha256 = FileAccess.get_sha256(target_path).to_lower()
			if target_sha256.is_empty():
				var _target_hash_issue_appended: bool = issues.append(
					"Artifact transaction target could not be hashed: %s." % target_path
				)
				continue
			backup_bytes += target_size
		entries.append({
			"path": target_path,
			"existed": existed,
			"size_bytes": target_size,
			"sha256": target_sha256,
		})
	if backup_bytes > max_backup_bytes:
		var _total_backup_issue_appended: bool = issues.append(
			"Artifact transaction snapshots exceed max_backup_bytes."
		)
	return {
		"ok": issues.is_empty(),
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "prepared" if issues.is_empty() else "failed",
		"entries": entries,
		"backup_bytes": backup_bytes,
		"issues": issues,
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
		),
	}


static func _make_preflight_boundary(
	normalized: Dictionary,
	options: Dictionary
) -> Dictionary:
	return {
		"ok": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(normalized, "ok"),
		"status": "ready" if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(normalized, "ok") else "rejected",
		"entry_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "entry_count"),
		"changed_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "changed_count"),
		"unchanged_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "unchanged_count"),
		"total_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "total_bytes"),
		"backup_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "backup_bytes"),
		"issues": _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(normalized, "issues"),
		"entries": _make_entry_reports(normalized),
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
		),
	}


static func _make_commit_boundary(
	normalized: Dictionary,
	options: Dictionary,
	status: StringName,
	written_count: int = 0
) -> Dictionary:
	var result: Dictionary = {
		"ok": status == &"committed" or status == &"dry_run",
		"status": status,
		"entry_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "entry_count"),
		"written_count": written_count,
		"unchanged_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "unchanged_count"),
		"total_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "total_bytes"),
		"backup_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(normalized, "backup_bytes"),
		"rolled_back": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(normalized, "rolled_back"),
		"rollback_complete": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(normalized, "rollback_complete", true),
		"recovery_required": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			normalized,
			"recovery_required"
		),
		"recovery_action": &"",
		"recovery_transaction": {},
		"issues": _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(normalized, "issues"),
		"reports": _make_entry_reports(normalized),
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
		),
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		normalized,
		"recovery_required"
	):
		result["recovery_action"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				normalized,
				"recovery_action"
			)
		)
		result["recovery_transaction"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				normalized,
				"recovery_transaction"
			).duplicate(true)
		)
	return result


static func _make_entry_reports(normalized: Dictionary) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for entry_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(normalized, "entries"):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		reports.append({
			"artifact_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "artifact_id"),
			"kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "kind"),
			"target_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path"),
			"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "size_bytes"),
			"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "content_sha256"),
			"previous_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "previous_sha256"),
			"changed": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "changed"),
			"metadata": _to_report_metadata(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(entry, "metadata")
			),
		})
	return reports


static func _make_transaction_action_report(
	ok: bool,
	status: StringName,
	restored_paths: PackedStringArray,
	failed_paths: PackedStringArray,
	issues: PackedStringArray,
	recovery_transaction: Dictionary = {},
	recovery_action: StringName = &""
) -> Dictionary:
	var recovery_required: bool = not recovery_transaction.is_empty()
	return {
		"ok": ok,
		"status": status,
		"restored_paths": restored_paths,
		"failed_paths": failed_paths,
		"issues": issues,
		"recovery_required": recovery_required,
		"recovery_action": recovery_action if recovery_required else &"",
		"recovery_transaction": (
			recovery_transaction.duplicate(true)
			if recovery_required
			else {}
		),
	}


static func _get_transaction_entries(
	active_state: Dictionary
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		active_state,
		"entries"
	):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			entries.append(entry)
	return entries


static func _retain_transaction_entries(
	transaction_id: String,
	active_state: Dictionary,
	entries: Array[Dictionary],
	start_index: int,
	end_index: int
) -> void:
	var remaining_entries: Array[Dictionary] = []
	for entry_index: int in range(start_index, end_index):
		remaining_entries.append(entries[entry_index])
	active_state["entries"] = remaining_entries
	_active_transactions[transaction_id] = active_state


static func _get_transaction_validation_error(transaction: Dictionary) -> String:
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"):
		return "Artifact transaction was not initialized successfully."
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(transaction, "format") != _TRANSACTION_FORMAT:
		return "Artifact transaction format is unsupported."
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(transaction, "format_version") != _TRANSACTION_VERSION:
		return "Artifact transaction version is unsupported."
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(transaction, "state") != "open":
		return "Artifact transaction is not open."
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	if transaction_id.is_empty() or not _active_transactions.has(transaction_id):
		return "Artifact transaction is unknown or already terminated."
	var active_state: Dictionary = _active_transactions[transaction_id]
	var expected_handle: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		active_state,
		"handle"
	)
	if transaction != expected_handle:
		return "Artifact transaction integrity validation failed."
	return ""


static func _get_rollback_preflight_issues(
	entries: Array,
	has_rollback_filter: bool,
	rollback_only_paths: PackedStringArray
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var rollback_set: Dictionary[String, bool] = {}
	for rollback_path: String in rollback_only_paths:
		rollback_set[rollback_path] = true
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			var _invalid_entry_appended: bool = issues.append(
				"Artifact transaction contains an invalid snapshot entry."
			)
			continue
		var entry: Dictionary = entry_value
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"path"
		)
		var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"existed"
		)
		var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"backup_path"
		)
		if (
			target_path.is_empty()
			or _path_has_link_component(target_path)
			or DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(target_path)
			)
		):
			var _target_issue_appended: bool = issues.append(
				"Artifact rollback target identity is no longer safe: %s."
				% target_path
			)
			continue
		var will_restore: bool = (
			not has_rollback_filter
			or rollback_set.has(target_path)
		)
		if not will_restore and not existed:
			continue
		if not existed:
			if not backup_path.is_empty():
				var _unexpected_backup_appended: bool = issues.append(
					"Artifact rollback snapshot metadata is invalid: %s."
					% target_path
				)
				continue
		else:
			if (
				backup_path.is_empty()
				or not backup_path.begins_with(
					"%s.gf-artifact-backup-" % target_path
				)
				or _path_has_link_component(backup_path)
				or DirAccess.dir_exists_absolute(
					ProjectSettings.globalize_path(backup_path)
				)
				or not FileAccess.file_exists(backup_path)
			):
				var _backup_identity_appended: bool = issues.append(
					"Artifact rollback snapshot is missing or unsafe: %s."
					% target_path
				)
				continue
			var expected_size: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				entry,
				"size_bytes",
				-1
			)
			var expected_sha256: String = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"sha256"
				)
			)
			if (
				expected_size < 0
				or not _is_sha256(expected_sha256)
				or _file_size(backup_path) != expected_size
				or FileAccess.get_sha256(backup_path).to_lower()
				!= expected_sha256
			):
				var _backup_content_appended: bool = issues.append(
					"Artifact rollback snapshot content changed: %s."
					% target_path
				)
				continue
		if not will_restore:
			continue
		var target_state: Dictionary = _capture_regular_file_state(
			target_path
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			target_state,
			"ok"
		):
			var _target_state_issue_appended: bool = issues.append(
				"Artifact rollback target identity is no longer safe: %s."
				% target_path
			)
			continue
		if (
			has_rollback_filter
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				entry,
				"rollback_expected_state_known"
			)
			and not _file_state_matches_expected(
				target_state,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					entry,
					"rollback_expected_existed"
				),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					entry,
					"rollback_expected_size_bytes",
					-1
				),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"rollback_expected_sha256"
				)
			)
		):
			var _target_drift_issue_appended: bool = issues.append(
				"Artifact rollback refused a target that changed after commit: %s."
				% target_path
			)
			continue
		entry["rollback_observed_existed"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				target_state,
				"existed"
			)
		)
		entry["rollback_observed_size_bytes"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				target_state,
				"size_bytes"
			)
		)
		entry["rollback_observed_sha256"] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				target_state,
				"sha256"
			)
		)
	return issues


static func _capture_regular_file_state(path: String) -> Dictionary:
	if (
		path.is_empty()
		or _path_has_link_component(path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)
		)
	):
		return {
			"ok": false,
			"existed": false,
			"size_bytes": -1,
			"sha256": "",
		}
	var existed: bool = FileAccess.file_exists(path)
	if not existed:
		return {
			"ok": true,
			"existed": false,
			"size_bytes": 0,
			"sha256": "",
		}
	var size_bytes: int = _file_size(path)
	var sha256: String = FileAccess.get_sha256(path).to_lower()
	return {
		"ok": size_bytes >= 0 and _is_sha256(sha256),
		"existed": true,
		"size_bytes": size_bytes,
		"sha256": sha256,
	}


static func _file_state_matches_expected(
	state: Dictionary,
	expected_existed: bool,
	expected_size: int,
	expected_sha256: String
) -> bool:
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(state, "ok"):
		return false
	var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		state,
		"existed"
	)
	if existed != expected_existed:
		return false
	if not existed:
		return true
	return (
		expected_size >= 0
		and _is_sha256(expected_sha256)
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			state,
			"size_bytes",
			-1
		)
		== expected_size
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			state,
			"sha256"
		)
		== expected_sha256
	)


static func _get_observed_target_state_error(entry: Dictionary) -> Error:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"path"
	)
	var state: Dictionary = _capture_regular_file_state(target_path)
	if not _file_state_matches_expected(
		state,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"rollback_observed_existed"
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"rollback_observed_size_bytes",
			-1
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"rollback_observed_sha256"
		)
	):
		return ERR_FILE_CORRUPT
	return OK


static func _get_transaction_backup_error(
	entry: Dictionary,
	allow_missing: bool
) -> Error:
	var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"backup_path"
	)
	if backup_path.is_empty():
		return OK
	if (
		not backup_path.begins_with(
			"%s.gf-artifact-backup-"
			% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
		)
		or _path_has_link_component(backup_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(backup_path)
		)
	):
		return ERR_UNAUTHORIZED
	if not FileAccess.file_exists(backup_path):
		return OK if allow_missing else ERR_FILE_NOT_FOUND
	var expected_size: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		entry,
		"size_bytes",
		-1
	)
	var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"sha256"
	)
	if (
		expected_size < 0
		or not _is_sha256(expected_sha256)
		or _file_size(backup_path) != expected_size
		or FileAccess.get_sha256(backup_path).to_lower()
		!= expected_sha256
	):
		return ERR_FILE_CORRUPT
	return OK


static func _remove_transaction_backup(
	entry: Dictionary,
	allow_missing: bool
) -> Error:
	var validation_error: Error = _get_transaction_backup_error(
		entry,
		allow_missing
	)
	if validation_error != OK:
		return validation_error
	var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"backup_path"
	)
	if backup_path.is_empty() or not FileAccess.file_exists(backup_path):
		return OK
	var remove_error: Error = _remove_file_path(backup_path)
	if remove_error != OK:
		return remove_error
	if (
		FileAccess.file_exists(backup_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(backup_path)
		)
	):
		return ERR_CANT_CREATE
	return OK


static func _get_restored_target_error(entry: Dictionary) -> Error:
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"path"
	)
	var expected_existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		entry,
		"existed"
	)
	var state: Dictionary = _capture_regular_file_state(target_path)
	if not _file_state_matches_expected(
		state,
		expected_existed,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"size_bytes",
			-1
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "sha256")
	):
		return ERR_FILE_CORRUPT
	return OK


static func _discard_transaction_backups(
	entries: Array[Dictionary]
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "backup_path")
		if backup_path.is_empty():
			continue
		var remove_error: Error = _remove_transaction_backup(entry, true)
		if remove_error != OK:
			var _issue_appended: bool = issues.append(
				"Could not remove artifact snapshot %s: %s." % [
					backup_path,
					error_string(remove_error),
				]
			)
	return issues


static func _cleanup_entry_sidecars(
	entries: Array[Dictionary],
	field_name: String
) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, field_name)
		if path.is_empty():
			continue
		if field_name == "staging_path":
			var staging_error: String = _get_staging_state_error(entry)
			if (
				not staging_error.is_empty()
				and FileAccess.file_exists(path)
			):
				var _identity_issue_appended: bool = issues.append(
					"Refused to remove a changed artifact sidecar for %s."
					% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						entry,
						"target_path"
					)
				)
				continue
		var remove_error: Error = _remove_file_path(path)
		if remove_error == OK:
			entry[field_name] = ""
			continue
		var _issue_appended: bool = issues.append(
			"Could not remove artifact sidecar %s: %s." % [
				path,
				error_string(remove_error),
			]
		)
	return issues


static func _merge_issues(
	target: Dictionary,
	additional: PackedStringArray
) -> void:
	var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(target, "issues")
	for issue: String in additional:
		var _issue_appended: bool = issues.append(issue)
	target["issues"] = issues


static func _make_sidecar_path(
	target_path: String,
	kind: String,
	transaction_id: String,
	index: int
) -> String:
	return "%s.gf-artifact-%s-%s-%d" % [
		target_path,
		kind,
		transaction_id,
		index,
	]


static func _write_bytes(path: String, bytes: PackedByteArray) -> Error:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(absolute_path)
	):
		return ERR_ALREADY_EXISTS
	if _path_has_link_component(path):
		return ERR_UNAUTHORIZED
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _store_result: Variant = file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	return write_error


static func _copy_file(
	source_path: String,
	target_path: String,
	expected_size: int,
	expected_sha256: String
) -> Error:
	if expected_size < 0 or not _is_sha256(expected_sha256):
		return ERR_INVALID_PARAMETER
	if _path_has_link_component(source_path) or _path_has_link_component(target_path):
		return ERR_UNAUTHORIZED
	var absolute_target_path: String = ProjectSettings.globalize_path(
		target_path
	)
	if (
		FileAccess.file_exists(target_path)
		or DirAccess.dir_exists_absolute(absolute_target_path)
	):
		return ERR_ALREADY_EXISTS
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()
	if source_file.get_length() != expected_size:
		source_file.close()
		return ERR_FILE_CORRUPT
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		var open_error: Error = FileAccess.get_open_error()
		source_file.close()
		return open_error
	while source_file.get_position() < expected_size:
		var remaining: int = expected_size - source_file.get_position()
		var chunk: PackedByteArray = source_file.get_buffer(mini(remaining, _COPY_BUFFER_BYTES))
		var read_error: Error = source_file.get_error()
		if read_error != OK or chunk.is_empty():
			source_file.close()
			target_file.close()
			var _remove_error: Error = _remove_file_path(target_path)
			return read_error if read_error != OK else ERR_FILE_CORRUPT
		var _store_result: Variant = target_file.store_buffer(chunk)
		var write_error: Error = target_file.get_error()
		if write_error != OK:
			source_file.close()
			target_file.close()
			var _remove_error: Error = _remove_file_path(target_path)
			return write_error
	var final_source_size: int = source_file.get_length()
	source_file.close()
	target_file.close()
	if (
		final_source_size != expected_size
		or _file_size(target_path) != expected_size
		or FileAccess.get_sha256(target_path).to_lower() != expected_sha256
	):
		var _remove_error: Error = _remove_file_path(target_path)
		return ERR_FILE_CORRUPT
	return OK


static func _remove_file_path(path: String) -> Error:
	if path.is_empty():
		return OK
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return ERR_INVALID_DATA
	if not FileAccess.file_exists(path):
		return OK
	if _path_has_link_component(path):
		return ERR_UNAUTHORIZED
	var remove_error: Error = DirAccess.remove_absolute(absolute_path)
	if remove_error != OK:
		return remove_error
	if (
		_path_has_link_component(path)
		or FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(absolute_path)
	):
		return ERR_FILE_CORRUPT
	return OK


static func _path_has_link_component(path: String) -> bool:
	var current: String = _trim_trailing_separators(
		ProjectSettings.globalize_path(path).replace("\\", "/")
	)
	while not current.is_empty():
		if _path_component_is_link(current):
			return true
		var parent: String = _trim_trailing_separators(
			current.get_base_dir().replace("\\", "/")
		)
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


static func _portable_component_is_valid(component: String) -> bool:
	if (
		component.is_empty()
		or component == "."
		or component == ".."
		or component != component.rstrip(" .")
		or _string_has_control_character(component)
		or not _string_is_ascii(component)
	):
		return false
	for invalid_character: String in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		if component.contains(invalid_character):
			return false
	var device_stem: String = component.split(".", true)[0].to_upper()
	if ["CON", "PRN", "AUX", "NUL"].has(device_stem):
		return false
	if device_stem.length() == 4:
		var device_prefix: String = device_stem.substr(0, 3)
		var device_number: String = device_stem.substr(3, 1)
		if (
			(device_prefix == "COM" or device_prefix == "LPT")
			and ("123456789".contains(device_number) or "¹²³".contains(device_number))
		):
			return false
	return true


static func _string_is_ascii(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true


static func _string_has_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return true
	return false


static func _trim_trailing_separators(path: String) -> String:
	var result: String = path
	while result.length() > 1 and result.ends_with("/"):
		result = result.substr(0, result.length() - 1)
	return result


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


static func _get_packed_byte_array(
	source: Dictionary,
	key: String
) -> PackedByteArray:
	var value: Variant = source.get(key)
	if value is PackedByteArray:
		var bytes: PackedByteArray = value
		return bytes
	return PackedByteArray()


static func _to_report_metadata(metadata: Dictionary) -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(
		metadata,
		_GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
			_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_SUPPORT,
			{ "path_redaction": "basename" }
		)
	)


static func _make_begin_failure(
	issue: String,
	options: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "failed",
		"transaction_id": "",
		"transaction_token": "",
		"entry_count": 0,
		"backup_bytes": 0,
		"issues": PackedStringArray([issue]),
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				options,
				"metadata"
			)
		),
	}


static func _bounded_limit_option(
	options: Dictionary,
	key: String,
	fallback: int,
	absolute_maximum: int,
	allow_zero: bool = false
) -> int:
	var has_value: bool = options.has(key) or options.has(StringName(key))
	if not has_value:
		return fallback
	var value: Variant = (
		options.get(key)
		if options.has(key)
		else options.get(StringName(key))
	)
	if not value is int:
		return -1
	var int_value: int = value
	var minimum: int = 0 if allow_zero else 1
	if int_value < minimum or int_value > absolute_maximum:
		return -1
	return int_value


static func _make_unique_transaction_id() -> String:
	for _attempt: int in range(8):
		var candidate: String = _make_transaction_id()
		if not candidate.is_empty() and not _active_transactions.has(candidate):
			return candidate
	return ""


static func _make_transaction_id() -> String:
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if random_bytes.size() == 16:
		return random_bytes.hex_encode()
	var fallback_bytes: PackedByteArray = (
		"%d:%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	).to_utf8_buffer()
	return _sha256_bytes(fallback_bytes).substr(0, 32)


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


static func _scan_filesystem_if_needed(scan_filesystem: bool) -> void:
	if not scan_filesystem or not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.scan()
