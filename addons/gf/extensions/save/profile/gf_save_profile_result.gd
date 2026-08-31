## GFSaveProfileResult: Save Profile 操作的不可变终态快照。
##
## 结果同时保留 profile generation、底层存储结果、迁移/校验证据和回滚错误，
## 调用方无需从错误文本反推失败阶段。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFSaveProfileResult
extends RefCounted


# --- 常量 ---

## 保存 generation 已持久化。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_SAVED: StringName = &"saved"

## 文档已迁移、校验并应用。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_LOADED: StringName = &"loaded"

## flush 目标 generation 已持久化。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_FLUSHED: StringName = &"flushed"

## 恢复政策保留了当前内存状态。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_RECOVERED: StringName = &"recovered"

## Profile 配置或请求无效。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"

## 保存请求句柄无效或已经被接管。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## 当前 Profile 不支持请求的操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"

## 请求与正在执行的加载或 Provider 回调冲突。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_BUSY: StringName = &"busy"

## section Snapshot 准备或 worker 载荷预检失败。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_PREPARATION_FAILED: StringName = &"preparation_failed"

## section 应用前快照采集失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"

## 底层存储启动或执行失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_STORAGE_FAILED: StringName = &"storage_failed"

## 存档文件不存在。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MISSING: StringName = &"missing"

## 存档文档损坏或完整性失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_CORRUPT: StringName = &"corrupt"

## 文档 schema ID 与 profile 不匹配。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_SCHEMA_MISMATCH: StringName = &"schema_mismatch"

## 文档或 section 来自未来 schema。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"

## 旧版本文档迁移失败或缺少迁移链。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"

## 当前版本文档校验失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_VALIDATION_FAILED: StringName = &"validation_failed"

## section provider 应用失败且回滚成功。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_APPLY_FAILED: StringName = &"apply_failed"

## section provider 应用失败且至少一个回滚失败。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"

## Utility 释放时操作仍未完成。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_DISPOSED: StringName = &"disposed"

## 写入已提交到底层但无法确认最终磁盘副作用。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"


# --- 私有变量 ---

var _ok: bool = false
var _status: StringName = &""
var _operation: StringName = &""
var _profile_id: StringName = &""
var _requested_generation: int = 0
var _persisted_generation: int = 0
var _attempt_count: int = 0
var _started_at_msec: int = 0
var _completed_at_msec: int = 0
var _coalesced: bool = false
var _recovered: bool = false
var _recovery_action: StringName = &""
var _failed_section_id: StringName = &""
var _error_code: Error = FAILED
var _error: String = ""
var _document: GFSaveDocument = null
var _storage_result: GFStorageReadResult = null
var _migration_result: GFSaveMigrationResult = null
var _validation_report: Dictionary = {}
var _rollback_errors: Array[GFSaveRollbackFailure] = []
var _metadata: Dictionary = {}
var _storage_request_ids: PackedInt64Array = PackedInt64Array()
var _preparation_duration_msec: int = 0
var _storage_duration_msec: int = 0
var _preparation_work_units: int = 0


# --- 公共方法 ---

## 检查操作是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功终态返回 true。
func is_successful() -> bool:
	return _ok


## 获取稳定终态状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取操作类型。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return save、load 或 flush。
func get_operation() -> StringName:
	return _operation


## 获取 profile ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return profile ID。
func get_profile_id() -> StringName:
	return _profile_id


## 获取调用方请求时的 generation。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 非负 generation。
func get_requested_generation() -> int:
	return _requested_generation


## 获取终态时已持久化的 generation。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 非负 generation。
func get_persisted_generation() -> int:
	return _persisted_generation


## 获取底层 IO 尝试次数。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 未启动 IO 时为 0。
func get_attempt_count() -> int:
	return _attempt_count


## 检查保存请求是否由更新 generation 的写入覆盖完成。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 被合并时返回 true。
func was_coalesced() -> bool:
	return _coalesced


## 检查是否通过恢复政策保留了当前状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 使用恢复动作时返回 true。
func was_recovered() -> bool:
	return _recovered


## 获取实际恢复动作。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 未恢复时为空。
func get_recovery_action() -> StringName:
	return _recovery_action


## 获取首个失败 section ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 非 section 失败时为空。
func get_failed_section_id() -> StringName:
	return _failed_section_id


## 获取 Godot Error 码。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功时为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取稳定错误描述。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功时为空。
func get_error() -> String:
	return _error


## 获取读取流程的最终文档副本。
##
## Save 操作使用单所有者 Storage 交接，不再为结果额外复制完整文档，因此只在
## load 结果中提供文档。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return load 操作已迁移和校验的文档；其他操作返回 null。
func get_document() -> GFSaveDocument:
	return _document.duplicate_document() if _document != null else null


## 获取底层读取结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return load 操作的原始读取结果；其他操作或读取未启动时为 null。
func get_storage_result() -> GFStorageReadResult:
	return _storage_result.duplicate_result() if _storage_result != null else null


## 获取迁移结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 执行迁移时的结果；否则为 null。
func get_migration_result() -> GFSaveMigrationResult:
	return _migration_result.duplicate_result() if _migration_result != null else null


## 获取最终校验报告副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report or an empty Dictionary.
func get_validation_report() -> Dictionary:
	return _validation_report.duplicate(true)


## 获取回滚失败证据副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 按回滚顺序记录的类型化失败证据。
func get_rollback_errors() -> Array[GFSaveRollbackFailure]:
	return _duplicate_rollback_errors(_rollback_errors)


## 获取操作耗时。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 单调毫秒耗时。
func get_duration_msec() -> int:
	return maxi(_completed_at_msec - _started_at_msec, 0)


## 获取保存准备阶段耗时。
##
## 该值只覆盖 Provider Snapshot 与交接准备，不包含 Storage IO；非 Save 操作为 0。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 单调毫秒耗时。
func get_preparation_duration_msec() -> int:
	return _preparation_duration_msec


## 获取活跃 Storage attempt 累计耗时。
##
## 重试等待时间不计入该值；非 IO 操作为 0。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 单调毫秒耗时。
func get_storage_duration_msec() -> int:
	return _storage_duration_msec


## 获取保存准备累计消费的 work units。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负 work units。
func get_preparation_work_units() -> int:
	return _preparation_work_units


## 获取调用方元数据副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 调用方定义的临时结果元数据。
## [br]
## @schema return: Dictionary with caller-defined operation metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取支撑当前终态的底层 Storage 请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 按发起顺序排列的请求 ID；没有底层 IO 时为空。
func get_storage_request_ids() -> PackedInt64Array:
	return _storage_request_ids.duplicate()


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 不包含完整文档载荷的结果摘要。
## [br]
## @schema return: Dictionary with ok, status, operation, profile_id, generation, timing, recovery, error, validation, rollback, and metadata fields.
func to_dict() -> Dictionary:
	return {
		"ok": _ok,
		"status": _status,
		"operation": _operation,
		"profile_id": _profile_id,
		"requested_generation": _requested_generation,
		"persisted_generation": _persisted_generation,
		"attempt_count": _attempt_count,
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
		"duration_msec": get_duration_msec(),
		"preparation_duration_msec": _preparation_duration_msec,
		"storage_duration_msec": _storage_duration_msec,
		"preparation_work_units": _preparation_work_units,
		"coalesced": _coalesced,
		"recovered": _recovered,
		"recovery_action": _recovery_action,
		"failed_section_id": _failed_section_id,
		"error_code": int(_error_code),
		"error": _error,
		"has_document": _document != null,
		"storage_result": _get_storage_result_summary(),
		"migration_result": _get_migration_result_summary(),
		"validation_report": _validation_report.duplicate(true),
		"rollback_errors": _rollback_errors_to_dicts(),
		"metadata": _metadata.duplicate(true),
		"storage_request_ids": _storage_request_ids.duplicate(),
	}


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新结果对象。
func duplicate_result() -> GFSaveProfileResult:
	var copy: GFSaveProfileResult = GFSaveProfileResult.new()
	copy.configure_for_framework(
		_ok,
		_status,
		_operation,
		_profile_id,
		_requested_generation,
		_persisted_generation,
		_attempt_count,
		_started_at_msec,
		_completed_at_msec,
		_coalesced,
		_recovered,
		_recovery_action,
		_failed_section_id,
		_error_code,
		_error,
		_document,
		_storage_result,
		_migration_result,
		_validation_report,
		_rollback_errors,
		_metadata,
		_storage_request_ids,
		_preparation_duration_msec,
		_storage_duration_msec,
		_preparation_work_units
	)
	return copy


# --- 框架内部方法 ---

## 由 Save Profile Utility 一次性配置终态。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param p_ok: 是否成功。
## [br]
## @param p_status: 稳定终态状态。
## [br]
## @param p_operation: 操作类型。
## [br]
## @param p_profile_id: Profile ID。
## [br]
## @param p_requested_generation: 请求 generation。
## [br]
## @param p_persisted_generation: 终态时已持久化 generation。
## [br]
## @param p_attempt_count: 底层 IO 尝试次数。
## [br]
## @param p_started_at_msec: 单调开始时间。
## [br]
## @param p_completed_at_msec: 单调完成时间。
## [br]
## @param p_coalesced: 是否由更新 generation 覆盖完成。
## [br]
## @param p_recovered: 是否执行恢复动作。
## [br]
## @param p_recovery_action: 实际恢复动作。
## [br]
## @param p_failed_section_id: 首个失败 section ID。
## [br]
## @param p_error_code: Godot Error 码。
## [br]
## @param p_error: 稳定错误描述。
## [br]
## @param p_document: 最终文档。
## [br]
## @param p_storage_result: 底层读取结果。
## [br]
## @param p_migration_result: 迁移结果。
## [br]
## @param p_validation_report: 结构化校验报告。
## [br]
## @param p_rollback_errors: 回滚失败证据。
## [br]
## @param p_metadata: 调用方结果元数据。
## [br]
## @param p_storage_request_ids: 支撑终态的底层请求 ID。
## [br]
## @param p_preparation_duration_msec: Save 准备阶段耗时。
## [br]
## @param p_storage_duration_msec: 活跃 Storage attempt 累计耗时。
## [br]
## @param p_preparation_work_units: Save 准备累计 work units。
## [br]
## @schema p_validation_report: GFValidationReportDictionary-compatible report or an empty Dictionary.
## [br]
## @schema p_metadata: Dictionary with caller-defined result metadata.
func configure_for_framework(
	p_ok: bool,
	p_status: StringName,
	p_operation: StringName,
	p_profile_id: StringName,
	p_requested_generation: int,
	p_persisted_generation: int,
	p_attempt_count: int,
	p_started_at_msec: int,
	p_completed_at_msec: int,
	p_coalesced: bool = false,
	p_recovered: bool = false,
	p_recovery_action: StringName = &"",
	p_failed_section_id: StringName = &"",
	p_error_code: Error = OK,
	p_error: String = "",
	p_document: GFSaveDocument = null,
	p_storage_result: GFStorageReadResult = null,
	p_migration_result: GFSaveMigrationResult = null,
	p_validation_report: Dictionary = {},
	p_rollback_errors: Array[GFSaveRollbackFailure] = [],
	p_metadata: Dictionary = {},
	p_storage_request_ids: PackedInt64Array = PackedInt64Array(),
	p_preparation_duration_msec: int = 0,
	p_storage_duration_msec: int = 0,
	p_preparation_work_units: int = 0
) -> void:
	_ok = p_ok
	_status = p_status
	_operation = p_operation
	_profile_id = p_profile_id
	_requested_generation = maxi(p_requested_generation, 0)
	_persisted_generation = maxi(p_persisted_generation, 0)
	_attempt_count = maxi(p_attempt_count, 0)
	_started_at_msec = maxi(p_started_at_msec, 0)
	_completed_at_msec = maxi(p_completed_at_msec, _started_at_msec)
	_coalesced = p_coalesced
	_recovered = p_recovered
	_recovery_action = p_recovery_action
	_failed_section_id = p_failed_section_id
	_error_code = OK if p_ok else p_error_code
	_error = "" if p_ok else p_error.strip_edges()
	_document = p_document.duplicate_document() if p_document != null else null
	_storage_result = p_storage_result.duplicate_result() if p_storage_result != null else null
	_migration_result = p_migration_result.duplicate_result() if p_migration_result != null else null
	_validation_report = p_validation_report.duplicate(true)
	_rollback_errors = _duplicate_rollback_errors(p_rollback_errors)
	_metadata = p_metadata.duplicate(true)
	_storage_request_ids = p_storage_request_ids.duplicate()
	_preparation_duration_msec = maxi(p_preparation_duration_msec, 0)
	_storage_duration_msec = maxi(p_storage_duration_msec, 0)
	_preparation_work_units = maxi(p_preparation_work_units, 0)


# --- 私有/辅助方法 ---

func _duplicate_rollback_errors(
	errors: Array[GFSaveRollbackFailure]
) -> Array[GFSaveRollbackFailure]:
	var copies: Array[GFSaveRollbackFailure] = []
	for failure: GFSaveRollbackFailure in errors:
		if failure != null:
			copies.append(failure.duplicate_failure())
	return copies


func _rollback_errors_to_dicts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for failure: GFSaveRollbackFailure in _rollback_errors:
		if failure != null:
			result.append(failure.to_dict())
	return result


func _get_storage_result_summary() -> Dictionary:
	if _storage_result == null:
		return {}
	var summary: Dictionary = _storage_result.to_dict()
	var _payload_erased: bool = summary.erase("payload")
	return summary


func _get_migration_result_summary() -> Dictionary:
	if _migration_result == null:
		return {}
	var summary: Dictionary = _migration_result.to_dict()
	var _document_erased: bool = summary.erase("document")
	return summary
