## GFConfigPipelineCommitStage: Config Pipeline 的文件提交事务阶段。
##
## 在目标写入前捕获路径状态，并负责成功提交后的快照清理或失败后的逆序回滚。
## 该阶段不解释产物内容，也不决定输出路径策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineCommitStage
extends RefCounted


# --- 常量 ---

## Commit 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.commit.filesystem"

## Commit 阶段的实现版本；改变事务或回滚语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 1

const _TRANSACTION_FORMAT: String = "gf.config_pipeline.commit_transaction"
const _TRANSACTION_VERSION: int = 1
const _COPY_BUFFER_BYTES: int = 64 * 1024


# --- 公共方法 ---

## 捕获待写入路径的事务前状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param paths: 本次事务可能创建或覆盖的完整路径集合。
## [br]
## @return: 提交事务。
## [br]
## @schema return: Dictionary，包含 success、format、format_version、state、entries、error_kind 和 error。
func begin(paths: PackedStringArray) -> Dictionary:
	var entries: Array[Dictionary] = []
	var seen_paths: Dictionary = {}
	var transaction_id: String = "%d-%d" % [Time.get_ticks_usec(), get_instance_id()]
	for path: String in paths:
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		var existed: bool = FileAccess.file_exists(path)
		var backup_path: String = ""
		if existed:
			backup_path = "%s.gf-config-transaction-%s-%d.bak" % [path, transaction_id, entries.size()]
			var copy_error: Error = _copy_file(path, backup_path)
			if copy_error != OK:
				var cleanup_issues: PackedStringArray = _discard_backups(entries)
				return _make_begin_failure(
					"snapshot_failed",
					"无法为导表事务创建回滚快照：%s (%s)。" % [path, error_string(copy_error)],
					cleanup_issues
				)
		entries.append({
			"path": path,
			"existed": existed,
			"backup_path": backup_path,
		})
	return {
		"success": true,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "open",
		"entries": entries,
		"error_kind": "",
		"error": "",
	}


## 逆序恢复事务前状态；已存在文件恢复快照，事务中新建文件被删除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的事务。
## [br]
## @schema transaction: Dictionary，符合 gf.config_pipeline.commit_transaction@1。
## [br]
## @return: 回滚结果。
## [br]
## @schema return: Dictionary，包含 success、phase、restored_paths、failed_paths、issues、error_kind 和 error。
func rollback(transaction: Dictionary) -> Dictionary:
	var validation_error: String = _get_transaction_validation_error(transaction)
	if not validation_error.is_empty():
		return _make_operation_failure("invalid_transaction", validation_error)

	var restored_paths: PackedStringArray = PackedStringArray()
	var failed_paths: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	var entries: Array = GFVariantData.get_option_array(transaction, "entries")
	for entry_index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = GFVariantData.as_dictionary(entries[entry_index])
		var path: String = GFVariantData.get_option_string(entry, "path")
		var existed: bool = GFVariantData.get_option_bool(entry, "existed")
		var backup_path: String = GFVariantData.get_option_string(entry, "backup_path")
		var operation_error: Error = OK
		if existed:
			operation_error = _remove_file_path(path)
			if operation_error == OK:
				operation_error = DirAccess.rename_absolute(
					ProjectSettings.globalize_path(backup_path),
					ProjectSettings.globalize_path(path)
				)
		else:
			operation_error = _remove_file_path(path)

		if operation_error == OK:
			var _restored_appended: bool = restored_paths.append(path)
		else:
			var _failed_appended: bool = failed_paths.append(path)
			var action: String = "恢复" if existed else "删除新增"
			var _issue_appended: bool = issues.append("无法%s产物 %s：%s" % [action, path, error_string(operation_error)])

	transaction["state"] = "rolled_back" if failed_paths.is_empty() else "rollback_failed"
	return {
		"success": failed_paths.is_empty(),
		"phase": "commit",
		"restored_paths": restored_paths,
		"failed_paths": failed_paths,
		"issues": issues,
		"error_kind": "" if failed_paths.is_empty() else "rollback_failed",
		"error": "" if failed_paths.is_empty() else "导表事务回滚未能恢复全部路径。",
	}


## 完成事务并删除全部回滚快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的事务。
## [br]
## @schema transaction: Dictionary，符合 gf.config_pipeline.commit_transaction@1。
## [br]
## @return: 提交完成结果。
## [br]
## @schema return: Dictionary，包含 success、phase、restored_paths、failed_paths、issues、error_kind 和 error。
func complete(transaction: Dictionary) -> Dictionary:
	var validation_error: String = _get_transaction_validation_error(transaction)
	if not validation_error.is_empty():
		return _make_operation_failure("invalid_transaction", validation_error)
	var entries: Array[Dictionary] = []
	for entry_value: Variant in GFVariantData.get_option_array(transaction, "entries"):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			entries.append(entry)
	var issues: PackedStringArray = _discard_backups(entries)
	transaction["state"] = "committed" if issues.is_empty() else "cleanup_failed"
	return {
		"success": issues.is_empty(),
		"phase": "commit",
		"restored_paths": PackedStringArray(),
		"failed_paths": PackedStringArray(),
		"issues": issues,
		"error_kind": "" if issues.is_empty() else "snapshot_cleanup_failed",
		"error": "" if issues.is_empty() else "导表事务已提交，但回滚快照清理失败。",
	}


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、input_contract 和 output_contract。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contract": "PackedStringArray",
		"output_contract": "%s@%d" % [_TRANSACTION_FORMAT, _TRANSACTION_VERSION],
	}


# --- 私有/辅助方法 ---

func _get_transaction_validation_error(transaction: Dictionary) -> String:
	if not GFVariantData.get_option_bool(transaction, "success"):
		return "提交事务未成功初始化。"
	if GFVariantData.get_option_string(transaction, "format") != _TRANSACTION_FORMAT:
		return "提交事务格式不受支持。"
	if GFVariantData.get_option_int(transaction, "format_version") != _TRANSACTION_VERSION:
		return "提交事务版本不受支持。"
	if GFVariantData.get_option_string(transaction, "state") != "open":
		return "提交事务不处于 open 状态。"
	return ""


func _discard_backups(entries: Array[Dictionary]) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var backup_path: String = GFVariantData.get_option_string(entry, "backup_path")
		if backup_path.is_empty():
			continue
		var remove_error: Error = _remove_file_path(backup_path)
		if remove_error != OK:
			var _issue_appended: bool = issues.append("无法清理事务快照 %s：%s" % [backup_path, error_string(remove_error)])
	return issues


func _copy_file(source_path: String, target_path: String) -> Error:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		var target_open_error: Error = FileAccess.get_open_error()
		source_file.close()
		return target_open_error
	while source_file.get_position() < source_file.get_length():
		var remaining: int = source_file.get_length() - source_file.get_position()
		var chunk: PackedByteArray = source_file.get_buffer(mini(remaining, _COPY_BUFFER_BYTES))
		if source_file.get_error() != OK:
			var read_error: Error = source_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_partial_error: Error = _remove_file_path(target_path)
			return read_error
		var _store_chunk_result: Variant = target_file.store_buffer(chunk)
		if target_file.get_error() != OK:
			var write_error: Error = target_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_partial_error: Error = _remove_file_path(target_path)
			return write_error
	source_file.close()
	target_file.close()
	return OK


func _remove_file_path(path: String) -> Error:
	if path.is_empty() or not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_begin_failure(
	error_kind: String,
	message: String,
	cleanup_issues: PackedStringArray
) -> Dictionary:
	return {
		"success": false,
		"format": _TRANSACTION_FORMAT,
		"format_version": _TRANSACTION_VERSION,
		"state": "failed",
		"entries": [],
		"cleanup_issues": cleanup_issues,
		"error_kind": error_kind,
		"error": message,
	}


func _make_operation_failure(error_kind: String, message: String) -> Dictionary:
	return {
		"success": false,
		"phase": "commit",
		"restored_paths": PackedStringArray(),
		"failed_paths": PackedStringArray(),
		"issues": PackedStringArray(),
		"error_kind": error_kind,
		"error": message,
	}
