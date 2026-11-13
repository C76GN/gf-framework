## GFStorageTransfer: 通用存储后端传输协调器。
##
## 该工具只协调两个 GFStorageBackend 的字典数据传输、冲突检测和写回策略。
## 普通 Backend 没有 CAS 或跨端原子性；写入可能部分成功，结果始终明确这些能力边界。
## 默认只报告冲突。USE_NEWEST 仅是显式元数据选择规则，不保证并发安全或远端 revision 顺序。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFStorageTransfer
extends GFUtility


# --- 信号 ---

## 检测到存储冲突后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param report: 冲突报告。
signal transfer_conflict_detected(report: GFStorageConflictReport)

## 单个逻辑文件存在未解决冲突时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param result: 传输结果字典。
## [br]
## @schema result: Dictionary，由 transfer_data() 为未解决冲突返回。
signal transfer_conflict_unresolved(file_name: String, result: Dictionary)

## 单个逻辑文件传输完成后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param result: 传输结果字典。
## [br]
## @schema result: Dictionary，由 transfer_data() 为已完成传输返回。
signal transfer_completed(file_name: String, result: Dictionary)

## 单个逻辑文件传输失败后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param result: 传输结果字典。
## [br]
## @schema result: Dictionary，由 transfer_data() 为失败传输返回。
signal transfer_failed(file_name: String, result: Dictionary)


# --- 枚举 ---

## 冲突解决策略。
## [br]
## @api public
## [br]
## @since unreleased
enum ConflictStrategy {
	## 按后端元数据中的有限 revision/timestamp 选择更新的一侧；缺失或非有限值无法判断时保留冲突。
	USE_NEWEST,
	## 冲突时使用 local_backend 的数据。
	USE_LOCAL,
	## 冲突时使用 remote_backend 的数据。
	USE_REMOTE,
	## 只报告冲突，不自动写回。
	MANUAL,
	## 调用 options.resolver 或 options.resolution_callback 生成结果。
	CUSTOM,
}


## 传输结果状态。
## [br]
## @api public
## [br]
## @since unreleased
enum TransferStatus {
	## 已选择候选但没有写入任何后端。
	PREVIEW,
	## 两端数据已经一致。
	UNCHANGED,
	## 已把 local_backend 数据复制到 remote_backend。
	COPIED_LOCAL_TO_REMOTE,
	## 已把 remote_backend 数据复制到 local_backend。
	COPIED_REMOTE_TO_LOCAL,
	## 已用自定义合并结果写回两端。
	MERGED,
	## 存在未解决冲突。
	CONFLICT,
	## 传输失败。
	FAILED,
}


# --- 常量 ---

## 表示记录元数据无法按数值顺序比较的内部哨兵值。
## [br]
## @api private
## [br]
const _COMPARISON_UNORDERED: int = 2


# --- 公共变量 ---

## 默认冲突策略。
## [br]
## @api public
## [br]
## @since unreleased
var default_conflict_strategy: ConflictStrategy = ConflictStrategy.MANUAL

## 默认是否把解析出的结果写回后端。关闭后可用于 dry-run。
## [br]
## @api public
## [br]
## @since unreleased
var write_resolved_by_default: bool = true


# --- 私有变量 ---

## 调试快照中的已完成传输次数。
## [br]
## @api private
## [br]
var _transfer_count: int = 0

## 调试快照中的冲突处理次数。
## [br]
## @api private
## [br]
var _conflict_count: int = 0

## 调试快照中的失败次数。
## [br]
## @api private
## [br]
var _failed_count: int = 0


# --- 公共方法 ---

## 传输一个逻辑文件。非法 strategy 在任何后端读取前拒绝；只有确认不存在才填充缺失端。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param local_backend: 本地或主后端。
## [br]
## @param remote_backend: 远端或副后端。
## [br]
## @param options: 传输选项，支持 strategy、write_resolved、write_to_local、write_to_remote、resolver、revision_keys、timestamp_keys。
## [br]
## @return 传输结果字典。
## [br]
## @schema options: Dictionary，包含 strategy: ConflictStrategy、write_resolved: bool、write_to_local: bool、write_to_remote: bool、resolver: Callable、resolution_callback: Callable、revision_keys: Array[String] 和 timestamp_keys: Array[String]。
## [br]
## @schema return: Dictionary，包含 ok、file_name、status、status_name、selected_source、written_backends、conflicts、errors、error、error_kind、path、data、metadata、local、remote，以及恒为 false 的 concurrent_write_protection、cross_backend_atomic。
func transfer_data(
	file_name: String,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend,
	options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _make_base_result(file_name)
	var strategy: Variant = GFVariantData.get_option_value(
		options,
		"strategy",
		default_conflict_strategy
	)
	if (
		not strategy is int
		or strategy < ConflictStrategy.USE_NEWEST
		or strategy > ConflictStrategy.CUSTOM
	):
		result["error_kind"] = &"invalid_strategy"
		result["path"] = "options.strategy"
		return _finish_failed(result, "Transfer strategy must be a declared ConflictStrategy integer.")
	options = options.duplicate()
	options["strategy"] = strategy
	if file_name.is_empty():
		return _finish_failed(result, "file_name is empty")
	if local_backend == null or remote_backend == null:
		return _finish_failed(result, "Storage backend is null.")

	var local_record: Dictionary = _load_record(
		&"local",
		local_backend,
		file_name
	)
	var remote_record: Dictionary = _load_record(
		&"remote",
		remote_backend,
		file_name
	)
	result["local"] = _summarize_record(local_record)
	result["remote"] = _summarize_record(remote_record)

	var local_ok: bool = GFResultDictionary.is_ok(local_record)
	var remote_ok: bool = GFResultDictionary.is_ok(remote_record)
	if not local_ok and not _is_missing_record(local_record):
		return _finish_failed(result, "Local backend data could not be read; transfer was not written.")
	if not remote_ok and not _is_missing_record(remote_record):
		return _finish_failed(result, "Remote backend data could not be read; transfer was not written.")
	if not local_ok and not remote_ok:
		return _finish_failed(result, "No readable data in either backend.")
	if local_ok and not remote_ok:
		return _copy_record_to_backend(
			result,
			local_record,
			remote_backend,
			&"remote",
			TransferStatus.COPIED_LOCAL_TO_REMOTE,
			options
		)
	if remote_ok and not local_ok:
		return _copy_record_to_backend(
			result,
			remote_record,
			local_backend,
			&"local",
			TransferStatus.COPIED_REMOTE_TO_LOCAL,
			options
		)
	if _records_have_same_data(local_record, remote_record):
		result["ok"] = true
		result["status"] = TransferStatus.UNCHANGED
		result["status_name"] = _get_status_name(TransferStatus.UNCHANGED)
		result["data"] = _get_record_data(local_record)
		result["metadata"] = _get_record_metadata(local_record)
		return _finish_completed(result)

	return _resolve_and_write_conflict(
		result,
		local_record,
		remote_record,
		local_backend,
		remote_backend,
		options
	)


## 批量传输多个逻辑文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_names: 最多256个逻辑文件名；超限不开始任何传输。
## [br]
## @param local_backend: 本地或主后端。
## [br]
## @param remote_backend: 远端或副后端。
## [br]
## @param options: 传给 transfer_data() 的传输选项。
## [br]
## @return 批量结果字典。
## [br]
## @schema options: Dictionary，支持字段与 transfer_data() 相同。
## [br]
## @schema return: Dictionary，包含 ok: bool、count: int、results: Array[Dictionary] 和 status_counts: Dictionary；批量超限还包含 error:String，count 为0。
func transfer_many(
	file_names: PackedStringArray,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend,
	options: Dictionary = {}
) -> Dictionary:
	if file_names.size() > 256:
		return {
			"ok": false,
			"count": 0,
			"results": [],
			"status_counts": {},
			"error": "Transfer batch exceeds 256 records.",
		}
	var results: Array[Dictionary] = []
	var status_counts: Dictionary = {}
	var all_ok: bool = true
	for file_name: String in file_names:
		var item_result: Dictionary = transfer_data(
			file_name,
			local_backend,
			remote_backend,
			options
		)
		results.append(item_result)
		all_ok = all_ok and GFVariantData.get_option_bool(item_result, GFResultDictionary.KEY_OK)
		var status_name: String = GFVariantData.get_option_string(
			item_result,
			"status_name",
			"unknown"
		)
		status_counts[status_name] = GFVariantData.get_option_int(status_counts, status_name) + 1

	return {
		"ok": all_ok,
		"count": results.size(),
		"results": results,
		"status_counts": status_counts,
	}


## 获取传输工具调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary，包含 transfer_count、conflict_count、failed_count、default_conflict_strategy 和 write_resolved_by_default。
func get_debug_snapshot() -> Dictionary:
	return {
		"transfer_count": _transfer_count,
		"conflict_count": _conflict_count,
		"failed_count": _failed_count,
		"default_conflict_strategy": default_conflict_strategy,
		"write_resolved_by_default": write_resolved_by_default,
	}


# --- 私有/辅助方法 ---

## 从后端读取逻辑文件并规范化为内部记录字典。
## [br]
## @api private
## [br]
func _load_record(
	source: StringName,
	backend: GFStorageBackend,
	file_name: String
) -> Dictionary:
	var load_result: Dictionary = backend.load_data(file_name)
	var data_value: Variant = GFVariantData.get_option_value(
		load_result,
		"data",
		{}
	)
	var metadata_value: Variant = GFVariantData.get_option_value(
		load_result,
		"metadata",
		{}
	)
	var ok: bool = GFResultDictionary.is_ok(load_result)
	var error_code_value: Variant = load_result.get("error_code")
	var error_code: int = error_code_value if error_code_value is int else ERR_CANT_OPEN
	var error: String = GFVariantData.get_option_string(
		load_result,
		GFResultDictionary.KEY_ERROR,
		""
	)
	if ok and not (data_value is Dictionary):
		ok = false
		error_code = ERR_INVALID_DATA
		error = "Backend returned non-Dictionary data."
	if not ok and error_code == OK:
		error_code = ERR_CANT_OPEN

	var record: Dictionary = { "source": source, }
	record["error_code"] = error_code
	record[GFResultDictionary.KEY_DATA] = GFVariantData.to_dictionary(data_value)
	record[GFResultDictionary.KEY_METADATA] = GFVariantData.to_dictionary(metadata_value)
	record[GFResultDictionary.KEY_ERROR] = error
	return GFResultDictionary.make(ok, record)


## 只接受后端读取明确给出的不存在错误；探针布尔值和错误文本不能授权覆盖。
## [br]
## @api private
func _is_missing_record(record: Dictionary) -> bool:
	return (
		not GFResultDictionary.is_ok(record)
		and GFVariantData.get_option_int(
			record,
			"error_code",
			ERR_CANT_OPEN
		) in [ERR_DOES_NOT_EXIST, ERR_FILE_NOT_FOUND]
	)


## 生成不含数据正文的记录摘要供传输结果返回。
## [br]
## @api private
## [br]
func _summarize_record(record: Dictionary) -> Dictionary:
	var summary: Dictionary = { "source": GFVariantData.get_option_string_name(record, "source"), }
	summary[GFResultDictionary.KEY_OK] = GFResultDictionary.is_ok(record)
	summary["error_code"] = GFVariantData.get_option_int(
		record,
		"error_code",
		ERR_CANT_OPEN
	)
	summary[GFResultDictionary.KEY_METADATA] = _get_record_metadata(record)
	summary[GFResultDictionary.KEY_ERROR] = GFVariantData.get_option_string(
		record,
		GFResultDictionary.KEY_ERROR,
		""
	)
	return summary


## 判断两条记录的数据字典是否相等。
## [br]
## @api private
## [br]
func _records_have_same_data(local_record: Dictionary, remote_record: Dictionary) -> bool:
	return _get_record_data(local_record) == _get_record_data(remote_record)


## 生成冲突报告、应用选定策略并按选项写回已解决的数据。
## [br]
## @api private
## [br]
func _resolve_and_write_conflict(
	result: Dictionary,
	local_record: Dictionary,
	remote_record: Dictionary,
	local_backend: GFStorageBackend,
	remote_backend: GFStorageBackend,
	options: Dictionary
) -> Dictionary:
	var report: GFStorageConflictReport = _make_conflict_report(
		_get_result_file_name(result),
		local_record,
		remote_record
	)
	if report == null:
		return _finish_failed(result, "Invalid conflict payload.")
	_conflict_count += 1
	transfer_conflict_detected.emit(report)

	var resolution: Dictionary = _resolve_conflict(
		report,
		local_record,
		remote_record,
		options
	)
	var resolved_report: GFStorageConflictReport = _get_conflict_report(
		resolution,
		"report",
		report
	)
	if resolved_report != null:
		_append_result_conflict(result, resolved_report)

	if not GFResultDictionary.is_ok(resolution):
		result["status"] = TransferStatus.CONFLICT
		result["status_name"] = _get_status_name(TransferStatus.CONFLICT)
		result["error"] = GFVariantData.get_option_string(
			resolution,
			GFResultDictionary.KEY_ERROR,
			"Storage conflict is unresolved."
		)
		return _finish_conflict(result)

	var selected_source: StringName = GFVariantData.get_option_string_name(
		resolution,
		"source",
		&"custom"
	)
	var data: Dictionary = _get_record_data(resolution)
	var metadata: Dictionary = _get_record_metadata(resolution)
	result["selected_source"] = selected_source
	result["data"] = data
	result["metadata"] = metadata

	var write_local: bool = _should_write_to_backend(
		options,
		"write_to_local",
		selected_source != &"local"
	)
	var write_remote: bool = _should_write_to_backend(
		options,
		"write_to_remote",
		selected_source != &"remote"
	)
	if selected_source == &"custom":
		write_local = _should_write_to_backend(
			options,
			"write_to_local",
			true
		)
		write_remote = _should_write_to_backend(
			options,
			"write_to_remote",
			true
		)

	if not _write_resolved_enabled(options):
		write_local = false
		write_remote = false

	if write_local:
		_write_backend(
			result,
			local_backend,
			&"local",
			data,
			metadata
		)
	if write_remote:
		_write_backend(
			result,
			remote_backend,
			&"remote",
			data,
			metadata
		)
	if _has_result_errors(result):
		return _finish_failed(result, "One or more backend writes failed.")

	result["ok"] = true
	if selected_source == &"local":
		result["status"] = TransferStatus.COPIED_LOCAL_TO_REMOTE
	elif selected_source == &"remote":
		result["status"] = TransferStatus.COPIED_REMOTE_TO_LOCAL
	else:
		result["status"] = TransferStatus.MERGED
	result["status_name"] = _get_status_name(
		GFVariantData.get_option_int(
			result,
			"status",
			TransferStatus.FAILED
		)
	)
	return _finish_completed(result)


## 按配置策略选择本地、远端、最新记录、自定义结果或未解决状态。
## [br]
## @api private
## [br]
func _resolve_conflict(
	report: GFStorageConflictReport,
	local_record: Dictionary,
	remote_record: Dictionary,
	options: Dictionary
) -> Dictionary:
	var strategy: ConflictStrategy = _get_strategy(options)
	match strategy:
		ConflictStrategy.USE_LOCAL:
			return _make_record_resolution(
				report,
				local_record,
				GFStorageConflictReport.Resolution.USE_LOCAL
			)
		ConflictStrategy.USE_REMOTE:
			return _make_record_resolution(
				report,
				remote_record,
				GFStorageConflictReport.Resolution.USE_REMOTE
			)
		ConflictStrategy.USE_NEWEST:
			var comparison: int = _compare_records(
				local_record,
				remote_record,
				options
			)
			if comparison == _COMPARISON_UNORDERED:
				return _make_unresolved_resolution(report, "Cannot determine newest storage record because comparison metadata is non-finite.")
			if comparison > 0:
				return _make_record_resolution(
					report,
					local_record,
					GFStorageConflictReport.Resolution.USE_LOCAL
				)
			if comparison < 0:
				return _make_record_resolution(
					report,
					remote_record,
					GFStorageConflictReport.Resolution.USE_REMOTE
				)
			return _make_unresolved_resolution(report, "Cannot determine newest storage record.")
		ConflictStrategy.CUSTOM:
			return _resolve_with_callback(
				report,
				local_record,
				remote_record,
				options
			)
		_:
			return _make_unresolved_resolution(report, "Manual storage conflict resolution required.")


## 将指定记录包装为冲突解决结果并更新报告的解决值。
## [br]
## @api private
## [br]
func _make_record_resolution(
	report: GFStorageConflictReport,
	record: Dictionary,
	resolution: GFStorageConflictReport.Resolution
) -> Dictionary:
	var data: Dictionary = _get_record_data(record)
	var metadata: Dictionary = _get_record_metadata(record)
	var resolved: GFStorageConflictReport = report.with_resolution(resolution, data)
	if resolved == null:
		return _make_unresolved_resolution(report, "Invalid resolution payload.")
	var result: Dictionary = { "source": GFVariantData.get_option_string_name(record, "source"), "report": resolved, }
	result[GFResultDictionary.KEY_DATA] = data
	result[GFResultDictionary.KEY_METADATA] = metadata
	return GFResultDictionary.make_success(result)


## 调用自定义解析器并校验其返回的数据与元数据字典。
## [br]
## @api private
## [br]
func _resolve_with_callback(
	report: GFStorageConflictReport,
	local_record: Dictionary,
	remote_record: Dictionary,
	options: Dictionary
) -> Dictionary:
	var resolver_value: Variant = GFVariantData.get_option_value(
		options,
		"resolver",
		GFVariantData.get_option_value(
			options,
			"resolution_callback",
			Callable()
		)
	)
	var resolver: Callable = _variant_to_callable(resolver_value)
	if not resolver.is_valid():
		return _make_unresolved_resolution(report, "Custom resolver is invalid.")

	var value: Variant = resolver.call(
		report.duplicate_report(),
		_make_callback_record(local_record),
		_make_callback_record(remote_record),
		GFVariantData.to_dictionary(options)
	)
	if not (value is Dictionary):
		return _make_unresolved_resolution(report, "Custom resolver must return a Dictionary.")

	var dictionary: Dictionary = GFVariantData.to_dictionary(value)
	var data_value: Variant = GFVariantData.get_option_value(
		dictionary,
		GFResultDictionary.KEY_DATA,
		{}
	)
	if not (data_value is Dictionary):
		return _make_unresolved_resolution(report, "Custom resolver returned non-Dictionary data.")

	var metadata_value: Variant = GFVariantData.get_option_value(
		dictionary,
		GFResultDictionary.KEY_METADATA,
		{}
	)
	var data: Dictionary = GFVariantData.to_dictionary(data_value)
	var metadata: Dictionary = GFVariantData.to_dictionary(metadata_value)
	var selected_resolution: GFStorageConflictReport.Resolution = _to_conflict_resolution(
		GFVariantData.get_option_int(
			dictionary,
			"resolution",
			GFStorageConflictReport.Resolution.MERGED
		)
	)
	if selected_resolution in [GFStorageConflictReport.Resolution.UNRESOLVED, GFStorageConflictReport.Resolution.SKIPPED]:
		return _make_unresolved_resolution(report, "Custom resolver did not select a writable candidate.")
	var resolved: GFStorageConflictReport = report.with_resolution(selected_resolution, data)
	if resolved == null:
		return _make_unresolved_resolution(report, "Invalid resolution payload.")
	var result: Dictionary = { "source": &"custom", "report": resolved, }
	result[GFResultDictionary.KEY_DATA] = data
	result[GFResultDictionary.KEY_METADATA] = metadata
	return GFResultDictionary.make_success(result)


## 标记报告为未解决并生成失败结果。
## [br]
## @api private
## [br]
func _make_unresolved_resolution(report: GFStorageConflictReport, error: String) -> Dictionary:
	return GFResultDictionary.make_failure(
		error,
		{ "report": report, }
	)


## 构造传给自定义解析器的来源、数据和元数据快照字典。
## [br]
## @api private
## [br]
func _make_callback_record(record: Dictionary) -> Dictionary:
	var callback_record: Dictionary = { "source": GFVariantData.get_option_string_name(record, "source"), }
	callback_record[GFResultDictionary.KEY_DATA] = _get_record_data(record)
	callback_record[GFResultDictionary.KEY_METADATA] = _get_record_metadata(record)
	return callback_record


## 使用两端记录生成初始冲突报告。
## [br]
## @api private
## [br]
func _make_conflict_report(
	file_name: String,
	local_record: Dictionary,
	remote_record: Dictionary
) -> GFStorageConflictReport:
	return GFStorageConflictReport.create(
		"backend",
		file_name,
		_get_record_data(local_record),
		_get_record_data(remote_record)
	)


## 将可读记录作为选定来源，并按写回选项复制到目标后端。
## [br]
## @api private
## [br]
func _copy_record_to_backend(
	result: Dictionary,
	source_record: Dictionary,
	target_backend: GFStorageBackend,
	target_name: StringName,
	status: TransferStatus,
	options: Dictionary
) -> Dictionary:
	var data: Dictionary = _get_record_data(source_record)
	var metadata: Dictionary = _get_record_metadata(source_record)
	result["selected_source"] = GFVariantData.get_option_string_name(source_record, "source")
	result["data"] = data
	result["metadata"] = metadata
	if _write_resolved_enabled(options) and _should_write_to_backend(
		options,
		"write_to_" + String(target_name),
		true
	):
		_write_backend(
			result,
			target_backend,
			target_name,
			data,
			metadata
		)
	if _has_result_errors(result):
		return _finish_failed(result, "One or more backend writes failed.")

	result["ok"] = true
	result["status"] = status
	result["status_name"] = _get_status_name(status)
	return _finish_completed(result)


## 保存传输数据到一个后端并记录成功目标或错误。
## [br]
## @api private
## [br]
func _write_backend(
	result: Dictionary,
	backend: GFStorageBackend,
	backend_name: StringName,
	data: Dictionary,
	metadata: Dictionary
) -> void:
	var error: Error = backend.save_data(
		_get_result_file_name(result),
		data,
		metadata
	)
	if error == OK:
		_append_written_backend(result, backend_name)
		return

	_set_result_error(
		result,
		backend_name,
		error_string(error)
	)


## 先按版本键比较记录，结果相同时再按时间戳键比较。
## [br]
## @api private
## [br]
func _compare_records(
	local_record: Dictionary,
	remote_record: Dictionary,
	options: Dictionary
) -> int:
	var revision_comparison: int = _compare_metadata_by_keys(
		local_record,
		remote_record,
		_get_string_array_option(
			options,
			"revision_keys",
			[
				"revision",
				"updated_revision",
				"sync_revision",
				"modified_revision",
			]
		)
	)
	if revision_comparison != 0:
		return revision_comparison

	return _compare_metadata_by_keys(
		local_record,
		remote_record,
		_get_string_array_option(
			options,
			"timestamp_keys",
			[
				"timestamp_unix",
				"modified_unix",
				"updated_unix",
				"saved_unix",
				"modified_time",
				"mtime",
				"timestamp",
			]
		)
	)


## 按给定顺序查找两端共有的元数据键并返回首个非零比较结果。
## [br]
## @api private
## [br]
func _compare_metadata_by_keys(
	local_record: Dictionary,
	remote_record: Dictionary,
	keys: Array[String]
) -> int:
	var local_metadata: Dictionary = _get_record_metadata(local_record)
	var remote_metadata: Dictionary = _get_record_metadata(remote_record)

	for key: String in keys:
		if not local_metadata.has(key) or not remote_metadata.has(key):
			continue
		var comparison: int = _compare_metadata_values(
			local_metadata[key],
			remote_metadata[key]
		)
		if comparison != 0:
			return comparison
	return 0


## 比较元数据值；有限数值按数值比较，其余值按字符串比较。
## [br]
## @api private
## [br]
func _compare_metadata_values(left: Variant, right: Variant) -> int:
	if left is int and right is int:
		if left == right:
			return 0
		return 1 if left > right else -1
	if _is_numeric_value(left) and _is_numeric_value(right):
		var left_number: float = GFVariantData.to_float(left)
		var right_number: float = GFVariantData.to_float(right)
		if not is_finite(left_number) or not is_finite(right_number):
			return _COMPARISON_UNORDERED
		if is_equal_approx(left_number, right_number):
			return 0
		return 1 if left_number > right_number else -1

	var left_text: String = str(left)
	var right_text: String = str(right)
	if left_text == right_text:
		return 0
	return 1 if left_text > right_text else -1


## 判断值是否为数值或可解析为浮点数的字符串。
## [br]
## @api private
## [br]
func _is_numeric_value(value: Variant) -> bool:
	if value is int or value is float:
		return true
	if value is String:
		var text_value: String = value
		return text_value.is_valid_float()
	return false


## 从记录中读取并规范化数据字典。
## [br]
## @api private
## [br]
static func _get_record_data(record: Dictionary) -> Dictionary:
	return GFVariantData.to_dictionary(
		GFVariantData.get_option_value(
			record,
			GFResultDictionary.KEY_DATA,
			{}
		)
	)


## 从记录中读取并规范化元数据字典。
## [br]
## @api private
## [br]
static func _get_record_metadata(record: Dictionary) -> Dictionary:
	return GFVariantData.to_dictionary(
		GFVariantData.get_option_value(
			record,
			GFResultDictionary.KEY_METADATA,
			{}
		)
	)


## 从传输结果中读取逻辑文件名。
## [br]
## @api private
## [br]
static func _get_result_file_name(result: Dictionary) -> String:
	return GFVariantData.get_option_string(result, "file_name")


## 判断传输结果的错误字典是否非空。
## [br]
## @api private
## [br]
static func _has_result_errors(result: Dictionary) -> bool:
	return not (
		GFVariantData.as_dictionary(
			GFVariantData.get_option_value(
				result,
				GFResultDictionary.KEY_ERRORS,
				{}
			)
		).is_empty()
	)


## 将冲突报告序列化后追加到结果的冲突列表。
## [br]
## @api private
## [br]
static func _append_result_conflict(result: Dictionary, report: GFStorageConflictReport) -> void:
	var conflicts: Array = GFVariantData.as_array(
		GFVariantData.get_option_value(
			result,
			"conflicts",
			[]
		)
	)
	conflicts.append(report.to_dict())
	result["conflicts"] = conflicts


## 将成功写回的后端名称追加到结果列表。
## [br]
## @api private
## [br]
static func _append_written_backend(result: Dictionary, backend_name: StringName) -> void:
	var written_backends: Array = GFVariantData.as_array(
		GFVariantData.get_option_value(
			result,
			"written_backends",
			[]
		)
	)
	written_backends.append(String(backend_name))
	result["written_backends"] = written_backends


## 在结果错误字典中记录指定后端的写入错误。
## [br]
## @api private
## [br]
static func _set_result_error(
	result: Dictionary,
	backend_name: StringName,
	error: String
) -> void:
	var errors: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(
			result,
			GFResultDictionary.KEY_ERRORS,
			{}
		)
	)
	errors[backend_name] = error
	result[GFResultDictionary.KEY_ERRORS] = errors


## 读取指定字段中的冲突报告；类型不符时返回备用报告。
## [br]
## @api private
## [br]
static func _get_conflict_report(
	source: Dictionary,
	key: Variant,
	fallback: GFStorageConflictReport
) -> GFStorageConflictReport:
	var value: Variant = GFVariantData.get_option_value(
		source,
		key,
		fallback
	)
	if value is GFStorageConflictReport:
		var report: GFStorageConflictReport = value
		return report
	return fallback


## 将 Variant 转换为 Callable，类型不符时返回无效 Callable。
## [br]
## @api private
## [br]
static func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 将整数限制到冲突解决枚举范围并映射为有效枚举值。
## [br]
## @api private
## [br]
static func _to_conflict_resolution(value: int) -> GFStorageConflictReport.Resolution:
	match clampi(
		value,
		GFStorageConflictReport.Resolution.UNRESOLVED,
		GFStorageConflictReport.Resolution.SKIPPED
	):
		GFStorageConflictReport.Resolution.USE_LOCAL:
			return GFStorageConflictReport.Resolution.USE_LOCAL
		GFStorageConflictReport.Resolution.USE_REMOTE:
			return GFStorageConflictReport.Resolution.USE_REMOTE
		GFStorageConflictReport.Resolution.MERGED:
			return GFStorageConflictReport.Resolution.MERGED
		GFStorageConflictReport.Resolution.SKIPPED:
			return GFStorageConflictReport.Resolution.SKIPPED
		_:
			return GFStorageConflictReport.Resolution.UNRESOLVED


## 将整数限制到冲突策略枚举范围并映射为有效策略。
## [br]
## @api private
## [br]
static func _to_conflict_strategy(value: int) -> ConflictStrategy:
	match clampi(
		value,
		ConflictStrategy.USE_NEWEST,
		ConflictStrategy.CUSTOM
	):
		ConflictStrategy.USE_LOCAL:
			return ConflictStrategy.USE_LOCAL
		ConflictStrategy.USE_REMOTE:
			return ConflictStrategy.USE_REMOTE
		ConflictStrategy.MANUAL:
			return ConflictStrategy.MANUAL
		ConflictStrategy.CUSTOM:
			return ConflictStrategy.CUSTOM
		_:
			return ConflictStrategy.USE_NEWEST


## 从选项读取策略并转换为有效冲突策略。
## [br]
## @api private
## [br]
func _get_strategy(options: Dictionary) -> ConflictStrategy:
	return _to_conflict_strategy(
		GFVariantData.get_option_int(
			options,
			"strategy",
			default_conflict_strategy
		)
	)


## 读取是否启用冲突解决结果的写回。
## [br]
## @api private
## [br]
func _write_resolved_enabled(options: Dictionary) -> bool:
	return GFVariantData.get_option_bool(
		options,
		"write_resolved",
		write_resolved_by_default
	)


## 读取指定后端写回选项，并使用调用方给定的默认值。
## [br]
## @api private
## [br]
func _should_write_to_backend(
	options: Dictionary,
	key: String,
	fallback: bool
) -> bool:
	return GFVariantData.get_option_bool(
		options,
		key,
		fallback
	)


## 从选项读取字符串数组；缺少该项时使用给定默认数组。
## [br]
## @api private
## [br]
func _get_string_array_option(
	options: Dictionary,
	key: String,
	fallback: Array[String]
) -> Array[String]:
	return GFVariantData.get_option_string_array(
		options,
		key,
		fallback
	)


## 构造带默认状态、两端摘要字段及空数据的传输结果。
## [br]
## @api private
## [br]
func _make_base_result(file_name: String) -> Dictionary:
	var result: Dictionary = {
		"file_name": file_name,
		"error_kind": &"",
		"path": "",
		"status": TransferStatus.FAILED,
		"status_name": _get_status_name(TransferStatus.FAILED),
		"selected_source": &"",
		"written_backends": [],
		"concurrent_write_protection": false,
		"cross_backend_atomic": false,
		"conflicts": [],
		"local": {},
		"remote": {},
	}
	result[GFResultDictionary.KEY_ERRORS] = {}
	result[GFResultDictionary.KEY_ERROR] = ""
	result[GFResultDictionary.KEY_DATA] = {}
	result[GFResultDictionary.KEY_METADATA] = {}
	return GFResultDictionary.make(false, result)


## 更新成功计数、发出完成信号并返回结果。
## [br]
## @api private
## [br]
func _finish_completed(result: Dictionary) -> Dictionary:
	if GFVariantData.get_option_array(result, "written_backends").is_empty() and GFVariantData.get_option_int(result, "status") != TransferStatus.UNCHANGED:
		result["status"] = TransferStatus.PREVIEW
		result["status_name"] = &"preview"
	_transfer_count += 1
	transfer_completed.emit(
		_get_result_file_name(result),
		result.duplicate(true)
	)
	return result


## 写入失败状态和错误，更新失败计数、发出失败信号并返回结果。
## [br]
## @api private
## [br]
func _finish_failed(result: Dictionary, error: String) -> Dictionary:
	result["ok"] = false
	result["status"] = TransferStatus.FAILED
	result["status_name"] = _get_status_name(TransferStatus.FAILED)
	result["error"] = error
	_failed_count += 1
	transfer_failed.emit(
		_get_result_file_name(result),
		result.duplicate(true)
	)
	return result


## 保持冲突状态，发出未解决信号并返回结果。
## [br]
## @api private
## [br]
func _finish_conflict(result: Dictionary) -> Dictionary:
	result["ok"] = false
	transfer_conflict_unresolved.emit(
		_get_result_file_name(result),
		result.duplicate(true)
	)
	return result


## 将传输状态枚举映射为结果字典使用的稳定名称。
## [br]
## @api private
## [br]
func _get_status_name(status: int) -> StringName:
	match status:
		TransferStatus.PREVIEW:
			return &"preview"
		TransferStatus.UNCHANGED:
			return &"unchanged"
		TransferStatus.COPIED_LOCAL_TO_REMOTE:
			return &"copied_local_to_remote"
		TransferStatus.COPIED_REMOTE_TO_LOCAL:
			return &"copied_remote_to_local"
		TransferStatus.MERGED:
			return &"merged"
		TransferStatus.CONFLICT:
			return &"conflict"
		_:
			return &"failed"
