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
## @since 10.0.0
class_name GFArtifactWriteTransaction
extends RefCounted


# --- 常量 ---

## 文本产物 entry 类型。
## [br]
## @api public
## [br]
## @since 10.0.0
const KIND_TEXT: StringName = &"text"

## 字节产物 entry 类型。
## [br]
## @api public
## [br]
## @since 10.0.0
const KIND_BYTES: StringName = &"bytes"

## 已有临时文件产物 entry 类型。
## [br]
## @api public
## [br]
## @since 10.0.0
const KIND_FILE: StringName = &"file"

## 默认最大产物数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_FILE_COUNT: int = 256

## 默认单产物最大字节数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_FILE_BYTES: int = 64 * 1024 * 1024

## 默认单批产物最大总字节数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024

## 默认事务 snapshots 与单个 restore working copy 的最大并发恢复字节数。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024

## 单次事务允许的产物数量绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_FILE_COUNT: int = 1024

## 单个产物允许的字节数绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_FILE_BYTES: int = 64 * 1024 * 1024

## 单次事务允许的产物总字节数绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024

## 单次事务 snapshots 与单个 restore working copy 的最大并发恢复字节数绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024

## 同一进程内允许保持 open 的事务绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_ACTIVE_TRANSACTIONS: int = 256

## 恢复报告要求调用 rollback()。
## [br]
## @api public
## [br]
## @since 10.0.0
const RECOVERY_ACTION_ROLLBACK: StringName = &"rollback"

## 恢复报告要求调用 complete()。
## [br]
## @api public
## [br]
## @since 10.0.0
const RECOVERY_ACTION_COMPLETE: StringName = &"complete"

## 事务句柄和活动状态字典中的格式标识，供校验句柄所属协议。
## [br]
## @api private
const _TRANSACTION_FORMAT: String = "gf.artifact_write.transaction"

## 活动事务状态使用的格式版本号。
## [br]
## @api private
const _TRANSACTION_VERSION: int = 1

## 复制文件时每次读取的缓冲区字节数。
## [br]
## @api private
const _COPY_BUFFER_BYTES: int = 64 * 1024

## 事务条目标记尚未完成回滚目标处理的阶段。
## [br]
## @api private
const _ROLLBACK_PHASE_PENDING: StringName = &"pending"

## 事务条目标记回滚流程已移除目标文件的阶段。
## [br]
## @api private
const _ROLLBACK_PHASE_TARGET_REMOVED: StringName = &"target_removed"

## 事务条目标记恢复目标文件失败的阶段。
## [br]
## @api private
const _ROLLBACK_PHASE_RESTORE_FAILED: StringName = &"restore_failed"

## 事务条目标记恢复目标文件完成的阶段。
## [br]
## @api private
const _ROLLBACK_PHASE_TARGET_RESTORED: StringName = &"target_restored"

## 自有文件写入报告的初始状态标记。
## [br]
## @api private
const _WRITE_STATE_PENDING: StringName = &"pending"

## 自有文件写入报告表示写入留下部分内容的状态标记。
## [br]
## @api private
const _WRITE_STATE_PARTIAL: StringName = &"partial"

## 自有文件写入报告表示写入完成的状态标记。
## [br]
## @api private
const _WRITE_STATE_COMPLETE: StringName = &"complete"

## 引用 GF 路径工具脚本，供事务辅助方法规范化路径并执行路径边界检查。
## [br]
## @api private
const _GF_PATH_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 引用报告值编解码工具，供报告元数据转换与脱敏。
## [br]
## @api private
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")

## 引用 Variant 安全读取工具，供事务状态和记录字段的类型化读取。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

## 按事务 ID 保存当前活动事务状态，供事务提交、回滚与清理流程查找并更新。
## [br]
## @api private
static var _active_transactions: Dictionary[String, Dictionary] = {}

## 测试故障注入计数器，用于在复制操作写入后模拟失败。
## [br]
## @api private
static var _test_copy_failures_after_write: int = 0

## 测试故障注入计数器，用于在字节写入后模拟失败。
## [br]
## @api private
static var _test_bytes_failures_after_write: int = 0

## 测试故障注入计数器，用于模拟自有 sidecar 删除失败。
## [br]
## @api private
static var _test_owned_remove_failures: int = 0


# --- 公共方法 ---

## 创建文本产物 entry。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param text: UTF-8 文本内容。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata；两个 hash 字段都必须是精确 String。expected_sha256 约束新内容；preflight_existing_sha256 在预检与每个可观察替换边界复核既有目标，但不提供跨进程原子 compare-and-exchange。
## [br]
## @schema return: Dictionary，包含 kind、target_path、text、overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata。
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
## @since 10.0.0
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param bytes: 产物字节；entry 持有隔离副本。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata；两个 hash 字段都必须是精确 String。expected_sha256 约束新内容；preflight_existing_sha256 在预检与每个可观察替换边界复核既有目标，但不提供跨进程原子 compare-and-exchange。
## [br]
## @schema return: Dictionary，包含 kind、target_path、bytes、overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata。
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
## @since 10.0.0
## [br]
## @param target_path: 目标 `res://` 或 `user://` 文件路径。
## [br]
## @param source_path: 已生成文件路径。
## [br]
## @param options: 单 entry 选项。
## [br]
## @return 可交给 commit() 的 entry 副本。
## [br]
## @schema options: Dictionary，可包含 overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata；两个 hash 字段都必须是精确 String。expected_sha256 约束新内容；preflight_existing_sha256 在预检与每个可观察替换边界复核既有目标，但不提供跨进程原子 compare-and-exchange。
## [br]
## @schema return: Dictionary，包含 kind、target_path、source_path、overwrite、expected_sha256、preflight_existing_sha256、artifact_id 和 metadata。
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
## @since 10.0.0
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
## @since 10.0.0
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
## @schema return: closed Dictionary，始终且仅包含 ok、status、entry_count、written_count、unchanged_count、total_bytes、backup_bytes、rolled_back、rollback_complete、recovery_required、recovery_action、recovery_transaction、issues、reports 和 metadata；backup_bytes 是 changed target snapshots 与单个 rollback restore working copy 的最大并发占用；recovery_required 为 true 时，调用方必须按 recovery_action 将 recovery_transaction 原样交给 rollback() 或 complete()。
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
	if _active_transactions.size() >= ABSOLUTE_MAX_ACTIVE_TRANSACTIONS:
		_merge_issues(
			normalized,
			PackedStringArray([
				"Artifact transaction active-session capacity is exhausted.",
			])
		)
		return _make_commit_boundary(normalized, options, &"snapshot_failed")
	var staging_cleanup_transaction_id: String = _make_unique_transaction_id()
	if staging_cleanup_transaction_id.is_empty():
		_merge_issues(
			normalized,
			PackedStringArray([
				"Artifact transaction identity could not be allocated.",
			])
		)
		return _make_commit_boundary(normalized, options, &"snapshot_failed")
	var staging_result: Dictionary = _stage_entries(changed_entries)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(staging_result, "ok"):
		var stage_failure_cleanup_issues: PackedStringArray = (
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(
			normalized,
			stage_failure_cleanup_issues
		)
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(staging_result, "issues"))
		if not stage_failure_cleanup_issues.is_empty():
			_apply_staging_sidecar_recovery(
				normalized,
				changed_entries,
				options,
				staging_cleanup_transaction_id
			)
		return _make_commit_boundary(normalized, options, &"staging_failed")

	var target_paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in changed_entries:
		var _target_appended: bool = target_paths.append(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "target_path")
		)
	var transaction: Dictionary = begin(target_paths, options)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(transaction, "ok"):
		var snapshot_failure_cleanup_issues: PackedStringArray = (
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(normalized, snapshot_failure_cleanup_issues)
		_merge_issues(normalized, _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(transaction, "issues"))
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			transaction,
			"recovery_required"
		):
			normalized["recovery_required"] = true
			normalized["recovery_action"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
					transaction,
					"recovery_action"
				)
			)
			normalized["recovery_transaction"] = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
					transaction,
					"recovery_transaction"
				).duplicate(true)
			)
		if not snapshot_failure_cleanup_issues.is_empty():
			_apply_staging_sidecar_recovery(
				normalized,
				changed_entries,
				options,
				staging_cleanup_transaction_id
			)
		return _make_commit_boundary(normalized, options, &"snapshot_failed")
	_enable_selective_rollback(transaction)

	var replace_result: Dictionary = _replace_staged_entries(
		changed_entries,
		transaction
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(replace_result, "ok"):
		var rollback_result: Dictionary = rollback(transaction)
		var replace_failure_cleanup_issues: PackedStringArray = (
			_cleanup_entry_sidecars(changed_entries, "staging_path")
		)
		_merge_issues(normalized, replace_failure_cleanup_issues)
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
		if not replace_failure_cleanup_issues.is_empty():
			_apply_staging_sidecar_recovery(
				normalized,
				changed_entries,
				options,
				staging_cleanup_transaction_id
			)
		return _make_commit_boundary(normalized, options, &"commit_failed")

	var complete_result: Dictionary = complete(transaction)
	var staging_cleanup_issues: PackedStringArray = (
		_cleanup_entry_sidecars(changed_entries, "staging_path")
	)
	_merge_issues(normalized, staging_cleanup_issues)
	var complete_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		complete_result,
		"ok"
	)
	if not complete_ok:
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
	if not staging_cleanup_issues.is_empty():
		_apply_staging_sidecar_recovery(
			normalized,
			changed_entries,
			options,
			staging_cleanup_transaction_id
		)
	if not complete_ok or not staging_cleanup_issues.is_empty():
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
## @since 10.0.0
## [br]
## @param paths: 本次外部事务可能创建或覆盖的完整文件路径。
## [br]
## @param options: 快照边界选项。
## [br]
## @return 只能原样交给 complete() 或 rollback() 的完整性校验事务字典；调用方不得改写。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
## [br]
## @schema return: closed Dictionary，始终且仅包含 ok、format、format_version、state、transaction_id、transaction_token、entry_count、backup_bytes、issues、recovery_required、recovery_action、recovery_transaction 和 metadata；backup_bytes 是 snapshots 与单个 rollback restore working copy 的最大并发占用。ok=true 时 state=open、issues 为空且 recovery 字段为空；ok=false 时 state=failed、公开事务身份为空，只有 cleanup 未完成时 recovery_required=true、recovery_action=complete 且 recovery_transaction 为待终结的 opaque handle；不暴露目标或 sidecar 路径。
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
		return _make_begin_failure_report(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
				path_report,
				"issues"
			),
			options,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(
				path_report,
				"entries"
			).size(),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				path_report,
				"backup_bytes"
			)
		)

	var transaction_id: String = _make_unique_transaction_id()
	if transaction_id.is_empty():
		return _make_begin_failure(
			"Artifact transaction identity could not be allocated.",
			options
		)
	var handle: Dictionary = {
		"ok": true,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "open",
		"transaction_id": transaction_id,
		"transaction_token": _make_transaction_id(),
		"entry_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
			path_report,
			"entries"
		).size(),
		"backup_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			path_report,
			"backup_bytes"
		),
		"issues": PackedStringArray(),
		"recovery_required": false,
		"recovery_action": &"",
		"recovery_transaction": {},
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			path_report,
			"metadata"
		).duplicate(true),
	}
	_active_transactions[transaction_id] = {
		"handle": handle.duplicate(true),
		"entries": [],
		"staging_cleanup_entries": [],
		"terminal_mode": &"",
		"has_rollback_filter": false,
		"rollback_only_paths": PackedStringArray(),
	}
	var snapshots: Array[Dictionary] = []
	for entry: Dictionary in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(path_report, "entries"):
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
		var snapshot_index: int = snapshots.size()
		var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"existed"
		)
		var snapshot_state_error: String = _get_snapshot_source_state_error(entry)
		if not snapshot_state_error.is_empty():
			var state_issues: PackedStringArray = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
					path_report,
					"issues"
				)
			)
			var _state_issue_appended: bool = state_issues.append(
				snapshot_state_error
			)
			return _finalize_failed_begin(handle, state_issues)
		var backup_path: String = ""
		var snapshot: Dictionary = {
			"path": target_path,
			"existed": existed,
			"backup_path": "",
			"backup_owner_id": transaction_id,
			"backup_owner_index": snapshot_index,
			"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				entry,
				"size_bytes"
			),
			"sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"sha256"
			),
			"backup_write_state": _WRITE_STATE_PENDING,
			"backup_partial_identity_known": false,
			"backup_partial_size_bytes": 0,
			"backup_partial_sha256": "",
			"rollback_expected_state_known": false,
			"rollback_expected_existed": false,
			"rollback_expected_size_bytes": 0,
			"rollback_expected_sha256": "",
			"rollback_phase": _ROLLBACK_PHASE_PENDING,
			"rollback_restore_path": "",
			"rollback_restore_owner_id": transaction_id,
			"rollback_restore_owner_index": snapshot_index,
			"rollback_restore_write_state": _WRITE_STATE_PENDING,
			"rollback_restore_write_error": OK,
			"rollback_restore_cleanup_error": OK,
			"rollback_restore_partial_identity_known": false,
			"rollback_restore_partial_size_bytes": 0,
			"rollback_restore_partial_sha256": "",
			"rollback_failed_state_known": false,
			"rollback_failed_existed": false,
			"rollback_failed_size_bytes": 0,
			"rollback_failed_sha256": "",
		}
		if existed:
			backup_path = _make_sidecar_path(
				target_path,
				"backup",
				transaction_id,
				snapshot_index
			)
			snapshot["backup_path"] = backup_path
			snapshots.append(snapshot)
			_store_transaction_entries(
				transaction_id,
				_active_transactions[transaction_id],
				snapshots
			)
			var write_report: Dictionary = {}
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
				),
				write_report
			)
			_apply_owned_write_report(snapshot, "backup", write_report)
			snapshots[snapshots.size() - 1] = snapshot
			_store_transaction_entries(
				transaction_id,
				_active_transactions[transaction_id],
				snapshots
			)
			if copy_error != OK:
				var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(path_report, "issues")
				var _issue_appended: bool = issues.append(
					"Could not snapshot artifact target %s: %s" % [
						target_path,
						error_string(copy_error),
					]
				)
				_append_owned_write_report_issues(
					issues,
					target_path,
					"snapshot",
					write_report
				)
				return _finalize_failed_begin(handle, issues)
		else:
			snapshots.append(snapshot)
		var active_state: Dictionary = _active_transactions[transaction_id]
		active_state["entries"] = snapshots
		_active_transactions[transaction_id] = active_state
	return handle.duplicate(true)


## 逆序恢复 begin() 捕获的全部目标。
## [br]
## @api public
## [br]
## @since 10.0.0
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
	active_state["entries"] = entries
	_active_transactions[transaction_id] = active_state
	for entry_index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[entry_index]
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
		var existed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "existed")
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
		var operation_error: Error = OK
		var rollback_phase: StringName = _get_rollback_phase(entry)
		if not existed:
			if rollback_phase == _ROLLBACK_PHASE_PENDING:
				operation_error = _get_observed_target_state_error(entry)
				if operation_error == OK:
					operation_error = _remove_file_path(target_path)
				if operation_error == OK:
					_record_rollback_target_removed_state(
						transaction_id,
						active_state,
						entries,
						entry_index
					)
					entry = entries[entry_index]
			elif rollback_phase != _ROLLBACK_PHASE_TARGET_REMOVED:
				operation_error = ERR_INVALID_DATA
			if operation_error == OK:
				operation_error = _get_target_removed_state_error(entry)
		else:
			if rollback_phase == _ROLLBACK_PHASE_PENDING:
				operation_error = _prepare_rollback_restore(
					entry,
					transaction_id,
					entry_index
				)
				entries[entry_index] = entry
				_store_transaction_entries(
					transaction_id,
					active_state,
					entries
				)
				if operation_error == OK:
					operation_error = _get_observed_target_state_error(entry)
				if operation_error == OK:
					operation_error = _remove_file_path(target_path)
				if operation_error == OK:
					_record_rollback_target_removed_state(
						transaction_id,
						active_state,
						entries,
						entry_index
					)
					entry = entries[entry_index]
					rollback_phase = _ROLLBACK_PHASE_TARGET_REMOVED
			elif rollback_phase == _ROLLBACK_PHASE_RESTORE_FAILED:
				if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					entry,
					"rollback_failed_state_known"
				):
					operation_error = _get_recorded_restore_failure_error(
						entry
					)
					if operation_error == OK:
						operation_error = _remove_file_path(target_path)
					if operation_error == OK:
						_record_rollback_target_removed_state(
							transaction_id,
							active_state,
							entries,
							entry_index
						)
						entry = entries[entry_index]
						rollback_phase = _ROLLBACK_PHASE_TARGET_REMOVED
				else:
					operation_error = _get_restored_target_error(entry)
					if operation_error == OK:
						entry["rollback_phase"] = (
							_ROLLBACK_PHASE_TARGET_RESTORED
						)
						entries[entry_index] = entry
						_store_transaction_entries(
							transaction_id,
							active_state,
							entries
						)
						rollback_phase = _ROLLBACK_PHASE_TARGET_RESTORED
			elif rollback_phase == _ROLLBACK_PHASE_TARGET_REMOVED:
				operation_error = _get_target_removed_state_error(entry)
			elif rollback_phase == _ROLLBACK_PHASE_TARGET_RESTORED:
				operation_error = _get_restored_target_error(entry)
			else:
				operation_error = ERR_INVALID_DATA

			if (
				operation_error == OK
				and rollback_phase == _ROLLBACK_PHASE_TARGET_REMOVED
			):
				operation_error = _prepare_rollback_restore(
					entry,
					transaction_id,
					entry_index
				)
				entries[entry_index] = entry
				_store_transaction_entries(
					transaction_id,
					active_state,
					entries
				)
				if operation_error == OK:
					operation_error = _get_target_removed_state_error(entry)
				if operation_error == OK:
					var restore_path: String = (
						_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
							entry,
							"rollback_restore_path"
						)
					)
					operation_error = DirAccess.rename_absolute(
						ProjectSettings.globalize_path(restore_path),
						ProjectSettings.globalize_path(target_path)
					)
				if operation_error == OK:
					entry["rollback_restore_path"] = ""
					entry["rollback_phase"] = (
						_ROLLBACK_PHASE_TARGET_RESTORED
					)
					entries[entry_index] = entry
					_store_transaction_entries(
						transaction_id,
						active_state,
						entries
					)
					operation_error = _get_restored_target_error(entry)
					if operation_error != OK:
						var _failure_state_recorded: bool = (
							_record_rollback_restore_failure_state(
								transaction_id,
								active_state,
								entries,
								entry_index
							)
						)
						entry = entries[entry_index]
					else:
						rollback_phase = _ROLLBACK_PHASE_TARGET_RESTORED

			if (
				operation_error == OK
				and (
					rollback_phase == _ROLLBACK_PHASE_TARGET_RESTORED
					or _get_rollback_phase(entry)
					== _ROLLBACK_PHASE_TARGET_RESTORED
				)
			):
				operation_error = _remove_transaction_backup(entry, true)
		if operation_error == OK:
			var _restored_appended: bool = restored_paths.append(target_path)
		else:
			var _failed_appended: bool = failed_paths.append(target_path)
			_append_owned_write_entry_issues(
				issues,
				target_path,
				"rollback restore",
				entry,
				"rollback_restore"
			)
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
	active_state = _active_transactions[transaction_id]
	active_state["entries"] = []
	_active_transactions[transaction_id] = active_state
	var staging_cleanup_report: Dictionary = (
		_complete_registered_staging_cleanup(
			transaction_id,
			active_state
		)
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		staging_cleanup_report,
		"ok"
	):
		return _make_transaction_action_report(
			false,
			&"rollback_failed",
			restored_paths,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
				staging_cleanup_report,
				"failed_paths"
			),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
				staging_cleanup_report,
				"issues"
			),
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
## @since 10.0.0
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
	var staging_cleanup_report: Dictionary = (
		_complete_registered_staging_cleanup(
			transaction_id,
			active_state
		)
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		staging_cleanup_report,
		"ok"
	):
		return _make_transaction_action_report(
			false,
			&"cleanup_failed",
			PackedStringArray(),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
				staging_cleanup_report,
				"failed_paths"
			),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
				staging_cleanup_report,
				"issues"
			),
			transaction,
			RECOVERY_ACTION_COMPLETE
		)
	active_state = _active_transactions[transaction_id]
	for entry_index: int in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var backup_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"backup_path"
		)
		if backup_path.is_empty():
			continue
		var remove_error: Error = (
			_remove_owned_partial_sidecar(entry, "backup")
			if _get_sidecar_write_state(entry, "backup")
			== _WRITE_STATE_PARTIAL
			else _remove_transaction_backup(entry, true)
		)
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

## 组装待写入条目，复制字节数组并规范字符串哈希选项；保留旧哈希选项供后续验证明确拒绝，元数据沿用读取到的字典。
## [br]
## @api private
static func _make_entry(
	kind: StringName,
	target_path: String,
	text: String,
	bytes: PackedByteArray,
	source_path: String,
	options: Dictionary
) -> Dictionary:
	var expected_sha256_value: Variant = options.get("expected_sha256", "")
	var preflight_existing_sha256_value: Variant = options.get(
		"preflight_existing_sha256",
		""
	)
	if expected_sha256_value is String:
		var expected_sha256_text: String = expected_sha256_value
		expected_sha256_value = expected_sha256_text.strip_edges().to_lower()
	if preflight_existing_sha256_value is String:
		var preflight_existing_sha256_text: String = preflight_existing_sha256_value
		preflight_existing_sha256_value = (
			preflight_existing_sha256_text.strip_edges().to_lower()
		)
	var entry: Dictionary = {
		"kind": kind,
		"target_path": target_path,
		"text": text,
		"bytes": bytes.duplicate(),
		"source_path": source_path,
		"expected_sha256": expected_sha256_value,
		"preflight_existing_sha256": preflight_existing_sha256_value,
		"artifact_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "artifact_id"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
	}
	if options.has("expected_existing_sha256") or options.has(&"expected_existing_sha256"):
		entry["expected_existing_sha256"] = options.get("expected_existing_sha256")
	if options.has("overwrite") or options.has(&"overwrite"):
		entry["overwrite"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			options,
			"overwrite",
			true
		)
	return entry


## 预检数量、路径归属、可移植身份、载荷与恢复空间预算，核对可选内容哈希和目标预检哈希后生成规范条目。
## 文件载荷保留已校验的来源路径而不提前读取完整字节；目标新鲜度检查是可观察的非原子检查，不能当作并发写入锁。
## [br]
## @api private
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
	var snapshot_bytes: int = 0
	var largest_backup_bytes: int = 0
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
		if entry.has("expected_sha256") and typeof(entry["expected_sha256"]) != TYPE_STRING:
			var _hash_type_issue_appended: bool = issues.append(
				"Artifact entry %d expected_sha256 must be an exact String." % entry_index
			)
			continue
		var expected_sha256: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"expected_sha256"
		).strip_edges().to_lower()
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
		if entry.has("expected_existing_sha256"):
			var _legacy_existing_hash_issue_appended: bool = issues.append(
				"Artifact entry %d expected_existing_sha256 is unsupported; use preflight_existing_sha256 for a non-atomic observable freshness check." % entry_index
			)
			continue
		if (
			entry.has("preflight_existing_sha256")
			and typeof(entry["preflight_existing_sha256"]) != TYPE_STRING
		):
			var _existing_hash_type_issue_appended: bool = issues.append(
				"Artifact entry %d preflight_existing_sha256 must be an exact String." % entry_index
			)
			continue
		var preflight_existing_sha256: String = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"preflight_existing_sha256"
			).strip_edges().to_lower()
		)
		if not preflight_existing_sha256.is_empty() and (
			not _is_sha256(preflight_existing_sha256)
			or not existed
			or previous_sha256 != preflight_existing_sha256
		):
			var _existing_hash_issue_appended: bool = issues.append(
				"Artifact entry %d preflight_existing_sha256 does not match its existing target." % entry_index
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
			var candidate_snapshot_bytes: int = (
				snapshot_bytes + existing_size
			)
			var candidate_largest_backup_bytes: int = maxi(
				largest_backup_bytes,
				existing_size
			)
			var candidate_backup_bytes: int = (
				candidate_snapshot_bytes
				+ candidate_largest_backup_bytes
			)
			if candidate_backup_bytes > max_backup_bytes:
				var _changed_backup_issue_appended: bool = issues.append(
					"Artifact rollback recovery bytes exceed max_backup_bytes: %d > %d." % [
						candidate_backup_bytes,
						max_backup_bytes,
					]
				)
				continue
			snapshot_bytes = candidate_snapshot_bytes
			largest_backup_bytes = candidate_largest_backup_bytes
			backup_bytes = candidate_backup_bytes
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
			"Artifact rollback recovery bytes exceed max_backup_bytes: %d > %d." % [
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


## 按载荷种类验证单文件预算并计算字节数与哈希；文本转为 UTF-8 后再次检查预算，文件来源只返回路径和摘要，内存载荷是否附带字节由 include_bytes 控制。
## [br]
## @api private
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


## 构造字节读取结果字典；仅成功时计算 SHA-256，include_bytes 为 false 时不在结果中保留字节。
## [br]
## @api private
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


## 构造归一化记录结果，包含条目计数、字节计数、问题列表及初始回滚和恢复字段。
## [br]
## @api private
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


## 构造无条目的失败结果；entry_count 限制为非负值，其余计数清零并记录单条问题。
## [br]
## @api private
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


## 校验目标为允许根目录内的资源文件路径，拒绝目录、不可移植组件和链接路径；有效时返回空错误文本。
## [br]
## @api private
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


## 要求显式提供非空允许根目录集合，规范化 res:// 或 user:// 根路径并去重；缺失或无效时返回失败说明。
## [br]
## @api private
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


## 对 res:// 根目录使用前缀判断；其他路径交给 GFPathTools.is_path_under_root 并传入固定的 false、false 选项。
## [br]
## @api private
static func _path_is_under_allowed_root(path: String, root_path: String) -> bool:
	if root_path.ends_with("://"):
		return path.begins_with(root_path)
	return _GF_PATH_TOOLS_SCRIPT.is_path_under_root(path, root_path, false, false)


## 从归一化结果中筛出 changed 为 true 的字典条目。
## [br]
## @api private
static func _get_changed_entries(normalized: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(normalized, "entries"):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "changed"):
			result.append(entry)
	return result


## 逐项准备父目录和带事务身份的暂存文件，保存完整或部分写入状态并核对最终大小与哈希；首个失败即停止，已写入现场交由后续清理处理。
## [br]
## @api private
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
		entry["staging_owner_id"] = transaction_id
		entry["staging_owner_index"] = entry_index
		entry["staging_write_state"] = _WRITE_STATE_PENDING
		entry["staging_partial_identity_known"] = false
		entry["staging_partial_size_bytes"] = 0
		entry["staging_partial_sha256"] = ""
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
		var write_report: Dictionary = {}
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
				content_sha256,
				write_report
			)
		else:
			var bytes: PackedByteArray = _get_packed_byte_array(
				entry,
				"resolved_bytes"
			)
			write_error = _write_bytes(
				staging_path,
				bytes,
				write_report
			)
		_apply_owned_write_report(entry, "staging", write_report)
		if (
			write_error != OK
			or _file_size(staging_path) != size_bytes
			or FileAccess.get_sha256(staging_path).to_lower()
			!= content_sha256
		):
			var _write_issue_appended: bool = issues.append(
				"Could not stage artifact target %s: %s." % [
					target_path,
					error_string(write_error),
				]
			)
			_append_owned_write_report_issues(
				issues,
				target_path,
				"staging",
				write_report
			)
			break
	return {
		"ok": issues.is_empty(),
		"issues": issues,
	}


## 逐项核对目标基线和暂存身份，移除旧目标后登记已修改状态，再改名提交并校验内容；首个失败即停止，由外层依据登记状态安排回滚。
## [br]
## @api private
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


## 在提交前核对目标未变成目录、存在性未变且已有内容哈希仍匹配预检值；有效时返回空文本。
## [br]
## @api private
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


## 核对暂存路径结构和文件存在性，并验证预期字节数与内容哈希；不一致时返回提交前状态错误。
## [br]
## @api private
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
		_get_sidecar_path_schema_error(entry, "staging") != OK
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


## 提交后确认目标仍是无链接组件的普通文件，且大小和哈希与待写入内容一致。
## [br]
## @api private
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


## 快照前复核目标未变成目录，且存在性、大小和哈希仍符合预检状态；有效时返回空文本。
## [br]
## @api private
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


## 仅为仍登记的事务记录已修改路径及其最后预期状态，供选择性回滚识别应恢复的目标与冲突。
## [br]
## @api private
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


## 为活动事务启用路径过滤并清空已修改路径集合；后续只有显式登记的路径参与回滚。
## [br]
## @api private
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


## 预检事务目标数量、允许根、可移植路径身份及现有文件摘要，并按快照总量加最大单份恢复空间计算备份预算；返回准备状态和问题列表。
## [br]
## @api private
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
	var snapshot_bytes: int = 0
	var largest_backup_bytes: int = 0
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
			var candidate_snapshot_bytes: int = (
				snapshot_bytes + target_size
			)
			var candidate_largest_backup_bytes: int = maxi(
				largest_backup_bytes,
				target_size
			)
			var candidate_backup_bytes: int = (
				candidate_snapshot_bytes
				+ candidate_largest_backup_bytes
			)
			if candidate_backup_bytes > max_backup_bytes:
				var _backup_issue_appended: bool = issues.append(
					"Artifact transaction rollback recovery bytes exceed max_backup_bytes."
				)
				continue
			target_sha256 = FileAccess.get_sha256(target_path).to_lower()
			if target_sha256.is_empty():
				var _target_hash_issue_appended: bool = issues.append(
					"Artifact transaction target could not be hashed: %s." % target_path
				)
				continue
			snapshot_bytes = candidate_snapshot_bytes
			largest_backup_bytes = candidate_largest_backup_bytes
			backup_bytes = candidate_backup_bytes
		entries.append({
			"path": target_path,
			"existed": existed,
			"size_bytes": target_size,
			"sha256": target_sha256,
		})
	if backup_bytes > max_backup_bytes:
		var _total_backup_issue_appended: bool = issues.append(
			"Artifact transaction rollback recovery bytes exceed max_backup_bytes."
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


## 将归一化结果投影为预检边界字典，包含 ready/rejected 状态、计数、条目报告和脱敏元数据。
## [br]
## @api private
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


## 从规范结果构建对外提交报告，保留写入计数、回滚及恢复状态；仅 committed 或 dry_run 标记成功，需要恢复时深复制恢复事务。
## [br]
## @api private
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


## 把归一化条目投影为报告字段，并对每条记录的 metadata 执行支持报告配置的脱敏转换。
## [br]
## @api private
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


## 把未能清理的受管暂存文件登记到恢复事务；可复用已有恢复句柄，新建恢复时使用完成清理动作，登记失败则追加诊断。
## [br]
## @api private
static func _apply_staging_sidecar_recovery(
	normalized: Dictionary,
	entries: Array[Dictionary],
	options: Dictionary,
	transaction_id: String
) -> void:
	var existing_recovery: Dictionary = {}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		normalized,
		"recovery_required"
	):
		existing_recovery = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			normalized,
			"recovery_transaction"
		)
	var recovery_transaction: Dictionary = (
		_register_staging_sidecar_cleanup(
			entries,
			options,
			transaction_id,
			existing_recovery
		)
	)
	if recovery_transaction.is_empty():
		_merge_issues(
			normalized,
			PackedStringArray([
				"Owned staging sidecar cleanup could not retain a recovery transaction.",
			])
		)
		return
	normalized["recovery_required"] = true
	if existing_recovery.is_empty():
		normalized["recovery_action"] = RECOVERY_ACTION_COMPLETE
	normalized["recovery_transaction"] = recovery_transaction.duplicate(true)


## 收集完整或部分写入的暂存现场，按路径合并到有效恢复事务；没有现有事务时在容量和身份允许的条件下登记仅负责清理的事务句柄。
## [br]
## @api private
static func _register_staging_sidecar_cleanup(
	entries: Array[Dictionary],
	options: Dictionary,
	transaction_id: String,
	existing_recovery: Dictionary = {}
) -> Dictionary:
	var recovery_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var write_state: StringName = _get_sidecar_write_state(
			entry,
			"staging"
		)
		if (
			(
				write_state == _WRITE_STATE_COMPLETE
				or write_state == _WRITE_STATE_PARTIAL
			)
			and not _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"staging_path"
			).is_empty()
		):
			recovery_entries.append(_make_staging_cleanup_entry(entry))
	if recovery_entries.is_empty():
		return {}
	if not existing_recovery.is_empty():
		if not _get_transaction_validation_error(existing_recovery).is_empty():
			return {}
		var existing_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			existing_recovery,
			"transaction_id"
		)
		var existing_state: Dictionary = _active_transactions[existing_id]
		var existing_entries: Array[Dictionary] = (
			_get_staging_cleanup_entries(existing_state)
		)
		var existing_paths: Dictionary[String, bool] = {}
		for existing_entry: Dictionary in existing_entries:
			existing_paths[
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					existing_entry,
					"staging_path"
				)
			] = true
		for recovery_entry: Dictionary in recovery_entries:
			var recovery_path: String = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					recovery_entry,
					"staging_path"
				)
			)
			if not existing_paths.has(recovery_path):
				existing_entries.append(recovery_entry)
				existing_paths[recovery_path] = true
		existing_state["staging_cleanup_entries"] = existing_entries
		_active_transactions[existing_id] = existing_state
		return existing_recovery
	if (
		transaction_id.is_empty()
		or _active_transactions.has(transaction_id)
		or _active_transactions.size() >= ABSOLUTE_MAX_ACTIVE_TRANSACTIONS
	):
		return {}
	var handle: Dictionary = {
		"ok": true,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "open",
		"transaction_id": transaction_id,
		"transaction_token": _make_transaction_id(),
		"entry_count": recovery_entries.size(),
		"backup_bytes": 0,
		"issues": PackedStringArray(),
		"recovery_required": false,
		"recovery_action": &"",
		"recovery_transaction": {},
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				options,
				"metadata"
			)
		),
	}
	_active_transactions[transaction_id] = {
		"handle": handle.duplicate(true),
		"entries": [],
		"staging_cleanup_entries": recovery_entries,
		"terminal_mode": RECOVERY_ACTION_COMPLETE,
		"has_rollback_filter": false,
		"rollback_only_paths": PackedStringArray(),
	}
	return handle


## 提取清理暂存文件必需的目标、内容摘要、所有者和部分写入身份字段，不携带原始载荷。
## [br]
## @api private
static func _make_staging_cleanup_entry(entry: Dictionary) -> Dictionary:
	return {
		"target_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"target_path"
		),
		"size_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"size_bytes",
			-1
		),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"content_sha256"
		),
		"staging_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"staging_path"
		),
		"staging_owner_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"staging_owner_id"
		),
		"staging_owner_index": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"staging_owner_index",
			-1
		),
		"staging_write_state": _get_sidecar_write_state(
			entry,
			"staging"
		),
		"staging_partial_identity_known": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				entry,
				"staging_partial_identity_known"
			)
		),
		"staging_partial_size_bytes": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				entry,
				"staging_partial_size_bytes",
				-1
			)
		),
		"staging_partial_sha256": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"staging_partial_sha256"
			)
		),
	}


## 尝试完成失败初始化的事务清理，并合并原始与清理诊断；清理仍需恢复时返回独立恢复句柄，失败主结果不保留可用事务身份。
## [br]
## @api private
static func _finalize_failed_begin(
	transaction: Dictionary,
	issues: PackedStringArray
) -> Dictionary:
	var cleanup_report: Dictionary = complete(transaction)
	var merged_issues: PackedStringArray = issues.duplicate()
	for cleanup_issue: String in (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(
			cleanup_report,
			"issues"
		)
	):
		var _cleanup_issue_appended: bool = merged_issues.append(
			cleanup_issue
		)
	var recovery_required: bool = (
		not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(cleanup_report, "ok")
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			cleanup_report,
			"recovery_required"
		)
	)
	return {
		"ok": false,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "failed",
		"transaction_id": "",
		"transaction_token": "",
		"entry_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			transaction,
			"entry_count"
		),
		"backup_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			transaction,
			"backup_bytes"
		),
		"issues": merged_issues,
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			transaction,
			"metadata"
		).duplicate(true),
		"recovery_required": recovery_required,
		"recovery_action": (
			RECOVERY_ACTION_COMPLETE if recovery_required else &""
		),
		"recovery_transaction": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				cleanup_report,
				"recovery_transaction"
			).duplicate(true)
			if recovery_required
			else {}
		),
	}


## 构造事务动作结果；仅当 recovery_transaction 非空时标记需要恢复并复制该字典。
## [br]
## @api private
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


## 从活动状态的 entries 中保留 Dictionary 项，忽略其他类型。
## [br]
## @api private
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


## 从活动状态的 staging_cleanup_entries 中保留 Dictionary 项，忽略其他类型。
## [br]
## @api private
static func _get_staging_cleanup_entries(
	active_state: Dictionary
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		active_state,
		"staging_cleanup_entries"
	):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			entries.append(entry)
	return entries


## 读取由 sidecar_kind 拼出的写入状态键；字段缺失时回退到 pending。
## [br]
## @api private
static func _get_sidecar_write_state(
	entry: Dictionary,
	sidecar_kind: String
) -> StringName:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
		entry,
		"%s_write_state" % sidecar_kind,
		_WRITE_STATE_PENDING
	)


## 清空写入报告并填入 pending 状态、默认错误码及空的部分文件身份字段。
## [br]
## @api private
static func _initialize_owned_write_report(write_report: Dictionary) -> void:
	write_report.clear()
	write_report["state"] = _WRITE_STATE_PENDING
	write_report["write_error"] = OK
	write_report["cleanup_error"] = OK
	write_report["partial_identity_known"] = false
	write_report["partial_size_bytes"] = 0
	write_report["partial_sha256"] = ""


## 按暂存文件种类把写入状态、写入和清理错误及部分文件身份写回条目。
## [br]
## @api private
static func _apply_owned_write_report(
	entry: Dictionary,
	sidecar_kind: String,
	write_report: Dictionary
) -> void:
	entry["%s_write_state" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			write_report,
			"state",
			_WRITE_STATE_PENDING
		)
	)
	entry["%s_write_error" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"write_error",
			OK
		)
	)
	entry["%s_cleanup_error" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"cleanup_error",
			OK
		)
	)
	entry["%s_partial_identity_known" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			write_report,
			"partial_identity_known"
		)
	)
	entry["%s_partial_size_bytes" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"partial_size_bytes"
		)
	)
	entry["%s_partial_sha256" % sidecar_kind] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			write_report,
			"partial_sha256"
		)
	)


## 在清理部分写入前捕获当前普通文件摘要；文件已消失时回到待写入状态，无法确认身份时保留部分状态并返回错误。
## [br]
## @api private
static func _record_owned_partial_before_cleanup(
	path: String,
	write_report: Dictionary
) -> Error:
	var partial_state: Dictionary = _capture_regular_file_state(path)
	write_report["state"] = _WRITE_STATE_PARTIAL
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(partial_state, "ok"):
		return ERR_FILE_CORRUPT
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		partial_state,
		"existed"
	):
		write_report["state"] = _WRITE_STATE_PENDING
		return OK
	write_report["partial_identity_known"] = true
	write_report["partial_size_bytes"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			partial_state,
			"size_bytes"
		)
	)
	write_report["partial_sha256"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			partial_state,
			"sha256"
		)
	)
	return OK


## 分别追加受管文件的写入错误和部分清理错误，使两种失败均保留在问题列表中。
## [br]
## @api private
static func _append_owned_write_report_issues(
	issues: PackedStringArray,
	target_path: String,
	sidecar_kind: String,
	write_report: Dictionary
) -> void:
	var write_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		write_report,
		"write_error",
		OK
	) as Error
	var cleanup_error: Error = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		write_report,
		"cleanup_error",
		OK
	) as Error
	if write_error != OK:
		var _write_issue_appended: bool = issues.append(
			"Artifact %s write failed for %s: %s." % [
				sidecar_kind,
				target_path,
				error_string(write_error),
			]
		)
	if cleanup_error != OK:
		var _cleanup_issue_appended: bool = issues.append(
			"Artifact %s partial cleanup failed for %s: %s." % [
				sidecar_kind,
				target_path,
				error_string(cleanup_error),
			]
		)


## 从条目的指定文件种类字段提取写入和清理错误，再用展示标签追加诊断。
## [br]
## @api private
static func _append_owned_write_entry_issues(
	issues: PackedStringArray,
	target_path: String,
	sidecar_kind_label: String,
	entry: Dictionary,
	sidecar_kind: String
) -> void:
	var write_report: Dictionary = {
		"write_error": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"%s_write_error" % sidecar_kind,
			OK
		),
		"cleanup_error": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"%s_cleanup_error" % sidecar_kind,
			OK
		),
	}
	_append_owned_write_report_issues(
		issues,
		target_path,
		sidecar_kind_label,
		write_report
	)


## 仅对部分写入且仍存在的受管文件核对路径结构与已记录的大小和哈希；身份未知或变化时拒绝后续清理。
## [br]
## @api private
static func _get_owned_partial_sidecar_error(
	entry: Dictionary,
	sidecar_kind: String
) -> Error:
	if _get_sidecar_write_state(entry, sidecar_kind) != _WRITE_STATE_PARTIAL:
		return OK
	var path_field: String = "%s_path" % sidecar_kind
	var sidecar_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		path_field
	)
	if sidecar_path.is_empty():
		return OK
	if (
		_get_sidecar_path_schema_error(entry, sidecar_kind) != OK
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(sidecar_path)
		)
	):
		return ERR_UNAUTHORIZED
	if not FileAccess.file_exists(sidecar_path):
		return OK
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		entry,
		"%s_partial_identity_known" % sidecar_kind
	):
		return ERR_FILE_CORRUPT
	var state: Dictionary = _capture_regular_file_state(sidecar_path)
	if not _file_state_matches_expected(
		state,
		true,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"%s_partial_size_bytes" % sidecar_kind,
			-1
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"%s_partial_sha256" % sidecar_kind
		)
	):
		return ERR_FILE_CORRUPT
	return OK


## 验证部分写入文件身份后清理；已不存在或成功删除时清空路径并恢复待写入状态，失败时保留记录。
## [br]
## @api private
static func _remove_owned_partial_sidecar(
	entry: Dictionary,
	sidecar_kind: String
) -> Error:
	if _get_sidecar_write_state(entry, sidecar_kind) != _WRITE_STATE_PARTIAL:
		return OK
	var path_field: String = "%s_path" % sidecar_kind
	var sidecar_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		path_field
	)
	if sidecar_path.is_empty():
		return OK
	var identity_error: Error = _get_owned_partial_sidecar_error(
		entry,
		sidecar_kind
	)
	if identity_error != OK:
		return identity_error
	if not FileAccess.file_exists(sidecar_path):
		entry[path_field] = ""
		entry["%s_write_state" % sidecar_kind] = _WRITE_STATE_PENDING
		return OK
	var remove_error: Error = _remove_owned_sidecar_path(sidecar_path)
	if remove_error != OK:
		return remove_error
	entry[path_field] = ""
	entry["%s_write_state" % sidecar_kind] = _WRITE_STATE_PENDING
	return OK


## 按写入状态清理受管暂存文件，完整文件必须匹配预期内容，部分文件使用已捕获身份；成功或已缺失时清除路径和写入状态。
## [br]
## @api private
static func _remove_owned_staging_sidecar(entry: Dictionary) -> Error:
	var staging_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"staging_path"
	)
	if staging_path.is_empty():
		return OK
	if (
		_get_sidecar_path_schema_error(entry, "staging") != OK
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(staging_path)
		)
	):
		return ERR_UNAUTHORIZED
	if (
		not FileAccess.file_exists(staging_path)
	):
		entry["staging_path"] = ""
		entry["staging_write_state"] = _WRITE_STATE_PENDING
		return OK
	var write_state: StringName = _get_sidecar_write_state(entry, "staging")
	if write_state == _WRITE_STATE_PARTIAL:
		return _remove_owned_partial_sidecar(entry, "staging")
	if write_state != _WRITE_STATE_COMPLETE:
		return ERR_UNAUTHORIZED
	if not _get_staging_state_error(entry).is_empty():
		return ERR_FILE_CORRUPT
	var remove_error: Error = _remove_owned_sidecar_path(staging_path)
	if remove_error != OK:
		return remove_error
	if (
		FileAccess.file_exists(staging_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(staging_path)
		)
	):
		return ERR_FILE_CORRUPT
	entry["staging_path"] = ""
	entry["staging_write_state"] = _WRITE_STATE_PENDING
	return OK


## 把最新条目序列写入活动状态并回存到事务注册表。
## [br]
## @api private
static func _store_transaction_entries(
	transaction_id: String,
	active_state: Dictionary,
	entries: Array[Dictionary]
) -> void:
	active_state["entries"] = entries
	_active_transactions[transaction_id] = active_state


## 读取条目的 rollback_phase；字段为空时返回 pending 状态标记。
## [br]
## @api private
static func _get_rollback_phase(entry: Dictionary) -> StringName:
	var rollback_phase: StringName = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			entry,
			"rollback_phase"
		)
	)
	if rollback_phase.is_empty():
		return _ROLLBACK_PHASE_PENDING
	return rollback_phase


## 验证事务句柄并定位目标条目，记录目标已被移除的回滚阶段；句柄或目标无效时返回 false。
## [br]
## @api private
static func _record_rollback_target_removed(
	transaction: Dictionary,
	target_path: String
) -> bool:
	var validation_error: String = _get_transaction_validation_error(
		transaction
	)
	if not validation_error.is_empty():
		return false
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	var active_state: Dictionary = _active_transactions[transaction_id]
	var entries: Array[Dictionary] = _get_transaction_entries(active_state)
	var entry_index: int = _find_transaction_entry_index(
		entries,
		target_path
	)
	if entry_index < 0:
		return false
	_record_rollback_target_removed_state(
		transaction_id,
		active_state,
		entries,
		entry_index
	)
	return true


## 将指定条目标记为目标已移除，并清除旧的失败现场身份，再保存事务状态。
## [br]
## @api private
static func _record_rollback_target_removed_state(
	transaction_id: String,
	active_state: Dictionary,
	entries: Array[Dictionary],
	entry_index: int
) -> void:
	var entry: Dictionary = entries[entry_index]
	entry["rollback_phase"] = _ROLLBACK_PHASE_TARGET_REMOVED
	entry["rollback_failed_state_known"] = false
	entry["rollback_failed_existed"] = false
	entry["rollback_failed_size_bytes"] = 0
	entry["rollback_failed_sha256"] = ""
	entries[entry_index] = entry
	_store_transaction_entries(transaction_id, active_state, entries)


## 验证事务并定位目标，捕获恢复失败后的现场身份；返回是否成功确认该现场状态。
## [br]
## @api private
static func _record_rollback_restore_failure(
	transaction: Dictionary,
	target_path: String
) -> bool:
	var validation_error: String = _get_transaction_validation_error(
		transaction
	)
	if not validation_error.is_empty():
		return false
	var transaction_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		transaction,
		"transaction_id"
	)
	var active_state: Dictionary = _active_transactions[transaction_id]
	var entries: Array[Dictionary] = _get_transaction_entries(active_state)
	var entry_index: int = _find_transaction_entry_index(
		entries,
		target_path
	)
	if entry_index < 0:
		return false
	return _record_rollback_restore_failure_state(
		transaction_id,
		active_state,
		entries,
		entry_index
	)


## 捕获目标当前的普通文件状态，将回滚阶段设为恢复失败并清除恢复暂存路径；无论能否确认身份都保存状态，返回身份是否已知。
## [br]
## @api private
static func _record_rollback_restore_failure_state(
	transaction_id: String,
	active_state: Dictionary,
	entries: Array[Dictionary],
	entry_index: int
) -> bool:
	var entry: Dictionary = entries[entry_index]
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"path"
	)
	var failed_state: Dictionary = _capture_regular_file_state(target_path)
	var state_known: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		failed_state,
		"ok"
	)
	entry["rollback_phase"] = _ROLLBACK_PHASE_RESTORE_FAILED
	entry["rollback_restore_path"] = ""
	entry["rollback_failed_state_known"] = state_known
	entry["rollback_failed_existed"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			failed_state,
			"existed"
		)
		if state_known
		else false
	)
	entry["rollback_failed_size_bytes"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			failed_state,
			"size_bytes"
		)
		if state_known
		else 0
	)
	entry["rollback_failed_sha256"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			failed_state,
			"sha256"
		)
		if state_known
		else ""
	)
	entries[entry_index] = entry
	_store_transaction_entries(transaction_id, active_state, entries)
	return state_known


## 按 path 精确匹配目标路径，返回首个条目索引；没有匹配项时返回 -1。
## [br]
## @api private
static func _find_transaction_entry_index(
	entries: Array[Dictionary],
	target_path: String
) -> int:
	for entry_index: int in range(entries.size()):
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entries[entry_index],
				"path"
			)
			== target_path
		):
			return entry_index
	return -1


## 保留给定半开索引区间内的未完成条目并回存事务，以便恢复时从剩余工作继续。
## [br]
## @api private
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


## 依次检查事务初始化状态、格式、版本、open 状态、活动登记和句柄身份；验证通过返回空字符串，否则返回首个对应错误。
## [br]
## @api private
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


## 按回滚过滤集合和条目阶段验证目标、备份及恢复暂存文件；待回滚项保存本轮观察到的目标摘要，重试项必须仍匹配已记录的中间状态，发现漂移时返回问题而不改写文件。
## [br]
## @api private
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
			var backup_phase: StringName = _get_rollback_phase(entry)
			var backup_error: Error = _get_transaction_backup_error(
				entry,
				backup_phase == _ROLLBACK_PHASE_TARGET_RESTORED
			)
			if backup_path.is_empty() or backup_error != OK:
				var _backup_identity_appended: bool = issues.append(
					"Artifact rollback snapshot is missing or unsafe: %s."
					% target_path
				)
				continue
			var restore_path: String = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"rollback_restore_path"
				)
			)
			if (
				(
					backup_phase == _ROLLBACK_PHASE_RESTORE_FAILED
					or backup_phase
					== _ROLLBACK_PHASE_TARGET_RESTORED
				)
				and not restore_path.is_empty()
			):
				var _restore_metadata_appended: bool = issues.append(
					"Artifact rollback restore metadata is invalid: %s."
					% target_path
				)
				continue
			if (
				not restore_path.is_empty()
				and (
					_get_owned_partial_sidecar_error(
						entry,
						"rollback_restore"
					)
					if _get_sidecar_write_state(
						entry,
						"rollback_restore"
					)
					== _WRITE_STATE_PARTIAL
					else _get_rollback_restore_error(entry, true)
				)
				!= OK
			):
				var _restore_identity_appended: bool = issues.append(
					"Artifact rollback restore sidecar is unsafe: %s."
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
		var rollback_phase: StringName = _get_rollback_phase(entry)
		if rollback_phase == _ROLLBACK_PHASE_PENDING:
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
			continue
		if (
			rollback_phase == _ROLLBACK_PHASE_TARGET_REMOVED
			and not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				target_state,
				"existed"
			)
		):
			continue
		if (
			rollback_phase == _ROLLBACK_PHASE_RESTORE_FAILED
			and (
				(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						entry,
						"rollback_failed_state_known"
					)
					and _file_state_matches_expected(
						target_state,
						_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
							entry,
							"rollback_failed_existed"
						),
						_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
							entry,
							"rollback_failed_size_bytes",
							-1
						),
						_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
							entry,
							"rollback_failed_sha256"
						)
					)
				)
				or (
					not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
						entry,
						"rollback_failed_state_known"
					)
					and _file_state_matches_expected(
						target_state,
						existed,
						_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
							entry,
							"size_bytes",
							-1
						),
						_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
							entry,
							"sha256"
						)
					)
				)
			)
		):
			continue
		if (
			rollback_phase == _ROLLBACK_PHASE_TARGET_RESTORED
			and _file_state_matches_expected(
				target_state,
				existed,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					entry,
					"size_bytes",
					-1
				),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					entry,
					"sha256"
				)
			)
		):
			continue
		var _phase_state_issue_appended: bool = issues.append(
			"Artifact rollback intermediate state changed: %s."
			% target_path
		)
	return issues


## 先验证备份并清理可确认身份的部分恢复文件，再复用有效恢复文件或从备份复制；保留写入报告，并在复制完成后再次核对恢复内容。
## [br]
## @api private
static func _prepare_rollback_restore(
	entry: Dictionary,
	transaction_id: String,
	entry_index: int
) -> Error:
	var backup_error: Error = _get_transaction_backup_error(entry, false)
	if backup_error != OK:
		return backup_error
	if (
		_get_sidecar_write_state(entry, "rollback_restore")
		== _WRITE_STATE_PARTIAL
	):
		var partial_remove_error: Error = _remove_owned_partial_sidecar(
			entry,
			"rollback_restore"
		)
		if partial_remove_error != OK:
			return partial_remove_error
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"path"
	)
	var restore_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"rollback_restore_path"
	)
	if restore_path.is_empty():
		restore_path = _make_sidecar_path(
			target_path,
			"restore",
			transaction_id,
			entry_index
		)
		entry["rollback_restore_path"] = restore_path
	var restore_error: Error = _get_rollback_restore_error(entry, true)
	if restore_error != OK:
		return restore_error
	if FileAccess.file_exists(restore_path):
		return OK
	var write_report: Dictionary = {}
	var copy_error: Error = _copy_file(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "backup_path"),
		restore_path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "size_bytes", -1),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "sha256"),
		write_report
	)
	_apply_owned_write_report(
		entry,
		"rollback_restore",
		write_report
	)
	if copy_error != OK:
		return copy_error
	return _get_rollback_restore_error(entry, false)


## 验证恢复文件的受管路径、普通文件属性及原始内容摘要；缺失是否可接受由 allow_missing 决定。
## [br]
## @api private
static func _get_rollback_restore_error(
	entry: Dictionary,
	allow_missing: bool
) -> Error:
	var restore_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"rollback_restore_path"
	)
	if restore_path.is_empty():
		return OK if allow_missing else ERR_FILE_NOT_FOUND
	if (
		_get_sidecar_path_schema_error(entry, "rollback_restore") != OK
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(restore_path)
		)
	):
		return ERR_UNAUTHORIZED
	if not FileAccess.file_exists(restore_path):
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
		or _file_size(restore_path) != expected_size
		or FileAccess.get_sha256(restore_path).to_lower()
		!= expected_sha256
	):
		return ERR_FILE_CORRUPT
	return OK


## 确认回滚目标仍处于可识别且不存在的状态；目标重新出现或身份不安全时返回损坏错误。
## [br]
## @api private
static func _get_target_removed_state_error(entry: Dictionary) -> Error:
	var target_state: Dictionary = _capture_regular_file_state(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
	)
	if (
		not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(target_state, "ok")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			target_state,
			"existed"
		)
	):
		return ERR_FILE_CORRUPT
	return OK


## 要求已保存恢复失败现场身份，并确认目标仍匹配该现场的存在性、大小与哈希。
## [br]
## @api private
static func _get_recorded_restore_failure_error(entry: Dictionary) -> Error:
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		entry,
		"rollback_failed_state_known"
	):
		return ERR_FILE_CORRUPT
	var target_state: Dictionary = _capture_regular_file_state(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path")
	)
	if not _file_state_matches_expected(
		target_state,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			entry,
			"rollback_failed_existed"
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			entry,
			"rollback_failed_size_bytes",
			-1
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"rollback_failed_sha256"
		)
	):
		return ERR_FILE_CORRUPT
	return OK


## 拒绝空路径、链接路径和目录，返回普通文件的存在状态、大小与哈希；缺失文件返回有效的空状态。
## [br]
## @api private
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


## 先要求 state.ok 和 existed 与期望相同；文件存在时还要求期望大小非负、SHA-256 格式有效且大小与哈希均匹配。
## [br]
## @api private
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


## 重新捕获目标状态，与本轮回滚预检保存的观察摘要比较；目标变化时阻止后续操作。
## [br]
## @api private
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


## 空备份路径视为无需备份，否则验证受管路径和原始内容摘要；有路径但文件缺失时依 allow_missing 决定是否报错。
## [br]
## @api private
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
		_get_sidecar_path_schema_error(entry, "backup") != OK
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


## 验证备份身份和内容后删除文件，并确认路径不再被文件或目录占用；空路径或被允许的缺失状态直接成功。
## [br]
## @api private
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


## 核对恢复后的目标是否与事务开始时记录的存在性、大小和哈希一致。
## [br]
## @api private
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


## 清理注册的暂存条目，把仍有暂存路径的失败项保留到活动事务，并返回对应目标路径与诊断以供重试。
## [br]
## @api private
static func _complete_registered_staging_cleanup(
	transaction_id: String,
	active_state: Dictionary
) -> Dictionary:
	var entries: Array[Dictionary] = _get_staging_cleanup_entries(active_state)
	var issues: PackedStringArray = _cleanup_entry_sidecars(
		entries,
		"staging_path"
	)
	var remaining_entries: Array[Dictionary] = []
	var failed_paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"staging_path"
		).is_empty():
			continue
		remaining_entries.append(entry)
		var _failed_path_appended: bool = failed_paths.append(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry,
				"target_path"
			)
		)
	active_state["staging_cleanup_entries"] = remaining_entries
	_active_transactions[transaction_id] = active_state
	return {
		"ok": issues.is_empty() and remaining_entries.is_empty(),
		"failed_paths": failed_paths,
		"issues": issues,
	}


## 逐项清理指定路径字段，暂存文件走所有者与写入状态校验路径；成功后清空字段，失败则保留路径并收集问题。
## [br]
## @api private
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
			var staging_remove_error: Error = (
				_remove_owned_staging_sidecar(entry)
			)
			if staging_remove_error == OK:
				continue
			var _staging_issue_appended: bool = issues.append(
				"Could not remove an owned artifact staging sidecar for %s: %s."
				% [
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						entry,
						"target_path"
					),
					error_string(staging_remove_error),
				]
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


## 将 additional 中的问题逐项追加到 target 的 issues 字段，再写回 target。
## [br]
## @api private
static func _merge_issues(
	target: Dictionary,
	additional: PackedStringArray
) -> void:
	var issues: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(target, "issues")
	for issue: String in additional:
		var _issue_appended: bool = issues.append(issue)
	target["issues"] = issues


## 以目标路径哈希、文件种类、事务 ID 和条目索引构造同目录受管文件名；身份格式或索引无效时返回空路径。
## [br]
## @api private
static func _make_sidecar_path(
	target_path: String,
	kind: String,
	transaction_id: String,
	index: int
) -> String:
	var target_hash: String = _sha256_bytes(target_path.to_utf8_buffer())
	if (
		target_path.is_empty()
		or not ["backup", "restore", "staging"].has(kind)
		or not _is_lower_hex(target_hash, 64)
		or not _is_lower_hex(transaction_id, 32)
		or index < 0
		or index >= ABSOLUTE_MAX_FILE_COUNT
	):
		return ""
	return target_path.get_base_dir().path_join(
		".gf-artifact-%s-%s-%s-%d" % [
			kind,
			target_hash,
			transaction_id,
			index,
		]
	)


## 根据目标与所有者身份重建期望路径，严格核对目录、文件名、字节长度及无链接条件；不在此步骤验证文件内容。
## [br]
## @api private
static func _get_sidecar_path_schema_error(
	entry: Dictionary,
	sidecar_kind: String
) -> Error:
	if not [
		"backup",
		"rollback_restore",
		"staging",
	].has(sidecar_kind):
		return ERR_INVALID_PARAMETER
	var path_field: String = "%s_path" % sidecar_kind
	var target_field: String = (
		"target_path" if sidecar_kind == "staging" else "path"
	)
	var path_kind: String = (
		"restore" if sidecar_kind == "rollback_restore" else sidecar_kind
	)
	var sidecar_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		path_field
	)
	var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		target_field
	)
	var owner_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		entry,
		"%s_owner_id" % sidecar_kind
	)
	var owner_index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		entry,
		"%s_owner_index" % sidecar_kind,
		-1
	)
	if (
		sidecar_path.is_empty()
		or target_path.is_empty()
		or not _is_lower_hex(owner_id, 32)
		or owner_index < 0
		or owner_index >= ABSOLUTE_MAX_FILE_COUNT
	):
		return ERR_INVALID_DATA
	var expected_path: String = _make_sidecar_path(
		target_path,
		path_kind,
		owner_id,
		owner_index
	)
	var sidecar_leaf: String = sidecar_path.get_file()
	if (
		expected_path.is_empty()
		or sidecar_path != expected_path
		or sidecar_path.get_base_dir() != target_path.get_base_dir()
		or not _portable_component_is_valid(sidecar_leaf)
		or sidecar_leaf.to_utf8_buffer().size() > 255
		or _path_has_link_component(target_path)
		or _path_has_link_component(sidecar_path)
	):
		return ERR_UNAUTHORIZED
	return OK


## 拒绝已有目标与链接路径后写入字节，并核对写入位置、最终大小和哈希；失败交给部分文件清理流程，成功把报告标为完整写入。
## [br]
## @api private
static func _write_bytes(
	path: String,
	bytes: PackedByteArray,
	write_report: Dictionary = {}
) -> Error:
	_initialize_owned_write_report(write_report)
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
	var written_bytes: int = file.get_position()
	file.close()
	if (
		write_error == OK
		and _test_bytes_failures_after_write > 0
	):
		_test_bytes_failures_after_write -= 1
		write_error = ERR_FILE_CANT_WRITE
	var expected_sha256: String = _sha256_bytes(bytes)
	if (
		write_error != OK
		or written_bytes != bytes.size()
		or _file_size(path) != bytes.size()
		or expected_sha256.is_empty()
		or FileAccess.get_sha256(path).to_lower() != expected_sha256
	):
		return _resolve_owned_write_failure(
			path,
			write_error if write_error != OK else ERR_FILE_CANT_WRITE,
			write_report
		)
	write_report["state"] = _WRITE_STATE_COMPLETE
	return OK


## 记录原始写入错误并捕获部分文件身份，确认现场未变后尝试删除；清理失败优先作为返回错误，同时在报告中保留原始写入错误与恢复身份。
## [br]
## @api private
static func _resolve_owned_write_failure(
	path: String,
	write_error: Error,
	write_report: Dictionary = {}
) -> Error:
	var effective_write_error: Error = (
		write_error if write_error != OK else ERR_FILE_CANT_WRITE
	)
	write_report["write_error"] = effective_write_error
	var cleanup_error: Error = _record_owned_partial_before_cleanup(
		path,
		write_report
	)
	if (
		cleanup_error == OK
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			write_report,
			"state"
		)
		== _WRITE_STATE_PARTIAL
	):
		cleanup_error = _get_owned_write_report_partial_error(
			path,
			write_report
		)
		if cleanup_error == OK:
			cleanup_error = _remove_owned_sidecar_path(path)
	if cleanup_error == OK:
		write_report["state"] = _WRITE_STATE_PENDING
		write_report["partial_identity_known"] = false
		write_report["partial_size_bytes"] = 0
		write_report["partial_sha256"] = ""
	write_report["cleanup_error"] = cleanup_error
	return cleanup_error if cleanup_error != OK else effective_write_error


## 清理前验证部分写入报告对应的路径与已捕获文件摘要；文件缺失视为已清理，身份未知或变化时拒绝删除。
## [br]
## @api private
static func _get_owned_write_report_partial_error(
	path: String,
	write_report: Dictionary
) -> Error:
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			write_report,
			"state"
		)
		!= _WRITE_STATE_PARTIAL
	):
		return OK
	if (
		path.is_empty()
		or _path_has_link_component(path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)
		)
	):
		return ERR_UNAUTHORIZED
	if not FileAccess.file_exists(path):
		return OK
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		write_report,
		"partial_identity_known"
	):
		return ERR_FILE_CORRUPT
	var state: Dictionary = _capture_regular_file_state(path)
	if not _file_state_matches_expected(
		state,
		true,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			write_report,
			"partial_size_bytes",
			-1
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			write_report,
			"partial_sha256"
		)
	):
		return ERR_FILE_CORRUPT
	return OK


## 在目标缺失且两端路径无链接时按固定块大小复制已知长度文件，最终核对来源长度及目标大小和哈希；读取、写入或校验失败时处理受管部分文件。
## [br]
## @api private
static func _copy_file(
	source_path: String,
	target_path: String,
	expected_size: int,
	expected_sha256: String,
	write_report: Dictionary = {}
) -> Error:
	_initialize_owned_write_report(write_report)
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
			return _resolve_owned_write_failure(
				target_path,
				read_error if read_error != OK else ERR_FILE_CORRUPT,
				write_report
			)
		var _store_result: Variant = target_file.store_buffer(chunk)
		var write_error: Error = target_file.get_error()
		if write_error != OK:
			source_file.close()
			target_file.close()
			return _resolve_owned_write_failure(
				target_path,
				write_error,
				write_report
			)
		if _test_copy_failures_after_write > 0:
			_test_copy_failures_after_write -= 1
			source_file.close()
			target_file.close()
			return _resolve_owned_write_failure(
				target_path,
				ERR_FILE_CANT_WRITE,
				write_report
			)
	var final_source_size: int = source_file.get_length()
	source_file.close()
	target_file.close()
	if (
		final_source_size != expected_size
		or _file_size(target_path) != expected_size
		or FileAccess.get_sha256(target_path).to_lower() != expected_sha256
	):
		return _resolve_owned_write_failure(
			target_path,
			ERR_FILE_CORRUPT,
			write_report
		)
	write_report["state"] = _WRITE_STATE_COMPLETE
	return OK


## 空路径或缺失文件直接成功，拒绝目录及存在文件的链接路径；删除后复核路径未被文件、目录或链接重新占用。
## [br]
## @api private
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


## 有待注入的删除失败时递减计数器并返回 ERR_CANT_CREATE；否则委托通用路径删除方法。
## [br]
## @api private
static func _remove_owned_sidecar_path(path: String) -> Error:
	if _test_owned_remove_failures > 0:
		_test_owned_remove_failures -= 1
		return ERR_CANT_CREATE
	return _remove_file_path(path)


## 设置复制后写入、字节写入后和自有路径删除三类测试故障次数，负值按零处理。
## [br]
## @api private
static func _configure_test_owned_write_failures(
	copy_failures_after_write: int,
	bytes_failures_after_write: int,
	remove_failures: int
) -> void:
	_test_copy_failures_after_write = maxi(
		copy_failures_after_write,
		0
	)
	_test_bytes_failures_after_write = maxi(
		bytes_failures_after_write,
		0
	)
	_test_owned_remove_failures = maxi(remove_failures, 0)


## 将三类测试故障注入计数器全部重置为零。
## [br]
## @api private
static func _reset_test_owned_write_failures() -> void:
	_test_copy_failures_after_write = 0
	_test_bytes_failures_after_write = 0
	_test_owned_remove_failures = 0


## 将路径转为绝对路径并逐级检查当前组件和父目录，任一级为链接即返回 true。
## [br]
## @api private
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


## 通过父目录判断当前组件是否为链接；父目录存在但不能打开时保守返回 true。
## [br]
## @api private
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


## 限制组件为无控制字符的 ASCII 名称，拒绝空值、点目录、尾随空格或点、路径保留字符及 Windows 设备名。
## [br]
## @api private
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


## 检查字符串中每个 Unicode 码点是否都不大于 0x7f。
## [br]
## @api private
static func _string_is_ascii(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true


## 检查字符串是否含有 U+0000 至 U+001F 或 U+007F 控制字符。
## [br]
## @api private
static func _string_has_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return true
	return false


## 移除路径末尾的斜杠，但至少保留一个字符。
## [br]
## @api private
static func _trim_trailing_separators(path: String) -> String:
	var result: String = path
	while result.length() > 1 and result.ends_with("/"):
		result = result.substr(0, result.length() - 1)
	return result


## 读取文件长度；无法打开文件时返回 -1。
## [br]
## @api private
static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


## 从字典字段读取 PackedByteArray；字段类型不匹配时返回空字节数组。
## [br]
## @api private
static func _get_packed_byte_array(
	source: Dictionary,
	key: String
) -> PackedByteArray:
	var value: Variant = source.get(key)
	if value is PackedByteArray:
		var bytes: PackedByteArray = value
		return bytes
	return PackedByteArray()


## 使用 support 脱敏配置转换报告元数据，并将路径脱敏模式设为 basename。
## [br]
## @api private
static func _to_report_metadata(metadata: Dictionary) -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(
		metadata,
		_GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
			_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_SUPPORT,
			{ "path_redaction": "basename" }
		)
	)


## 把单条问题包装成 PackedStringArray，再交给 begin 失败报告构造器。
## [br]
## @api private
static func _make_begin_failure(
	issue: String,
	options: Dictionary
) -> Dictionary:
	return _make_begin_failure_report(
		PackedStringArray([issue]),
		options
	)


## 构建无可用事务身份的初始化失败报告，复制问题列表、规范非负计数并转换元数据；该路径不登记恢复任务。
## [br]
## @api private
static func _make_begin_failure_report(
	issues: PackedStringArray,
	options: Dictionary,
	entry_count: int = 0,
	backup_bytes: int = 0
) -> Dictionary:
	return {
		"ok": false,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "failed",
		"transaction_id": "",
		"transaction_token": "",
		"entry_count": maxi(entry_count, 0),
		"backup_bytes": maxi(backup_bytes, 0),
		"issues": issues.duplicate(),
		"recovery_required": false,
		"recovery_action": &"",
		"recovery_transaction": {},
		"metadata": _to_report_metadata(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				options,
				"metadata"
			)
		),
	}


## 读取 String 或 StringName 键对应的整数；缺键返回 fallback，类型或范围不合法返回 -1，allow_zero 决定下界是零还是一。
## [br]
## @api private
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


## 最多尝试生成八个事务 ID，返回首个非空且未在活动事务表登记的值；全部冲突时返回空字符串。
## [br]
## @api private
static func _make_unique_transaction_id() -> String:
	for _attempt: int in range(8):
		var candidate: String = _make_transaction_id()
		if not candidate.is_empty() and not _active_transactions.has(candidate):
			return candidate
	return ""


## 优先把 16 字节随机数编码为十六进制事务 ID；长度异常时用进程 ID 与微秒计时生成哈希回退值。
## [br]
## @api private
static func _make_transaction_id() -> String:
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if random_bytes.size() == 16:
		return random_bytes.hex_encode()
	var fallback_bytes: PackedByteArray = (
		"%d:%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	).to_utf8_buffer()
	return _sha256_bytes(fallback_bytes).substr(0, 32)


## 计算字节数组的 SHA-256 小写十六进制文本；上下文启动或更新失败时返回空字符串。
## [br]
## @api private
static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


## 检查文本是否为 64 位小写十六进制 SHA-256 值。
## [br]
## @api private
static func _is_sha256(value: String) -> bool:
	return _is_lower_hex(value, 64)


## 检查文本长度是否匹配且所有字符均为 0–9 或 a–f。
## [br]
## @api private
static func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


## 仅在请求扫描且处于编辑器时获取 EditorFileSystem 并触发 scan。
## [br]
## @api private
static func _scan_filesystem_if_needed(scan_filesystem: bool) -> void:
	if not scan_filesystem or not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.scan()
