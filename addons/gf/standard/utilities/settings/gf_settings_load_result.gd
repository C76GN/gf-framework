## GFSettingsLoadResult: 设置加载操作的不可变终态快照。
##
## 结果将“合法空设置”与缺失、损坏、未来版本和底层存储失败明确区分，
## 并保留实际应用状态、恢复动作和底层读取证据。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFSettingsLoadResult
extends RefCounted


# --- 常量 ---

## 持久化设置已成功读取并应用。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_LOADED: StringName = &"loaded"

## 调用方选择的显式恢复动作已完成。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_RECOVERED: StringName = &"recovered"

## 文件名、路径或读取请求无效。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## 设置文件不存在。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_MISSING: StringName = &"missing"

## 设置文件格式、载荷或完整性损坏。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CORRUPT: StringName = &"corrupt"

## 设置文件来自当前运行时无法读取的未来 schema。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"

## 设置文件的迁移链缺失或迁移失败。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"

## 底层存储读取失败或不可用。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_STORAGE_FAILED: StringName = &"storage_failed"


# --- 私有变量 ---

var _configured: bool = false
var _ok: bool = false
var _status: StringName = &""
var _file_name: String = ""
var _applied: bool = false
var _recovered: bool = false
var _recovery_action: StringName = &""
var _error_code: Error = FAILED
var _error: String = ""
var _storage_result: GFStorageReadResult = null


# --- 公共方法 ---

## 检查加载是否进入成功终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 设置已加载或已按显式策略恢复时返回 true。
func is_successful() -> bool:
	return _ok


## 获取稳定加载状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取本次加载使用的文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 解析默认值后的设置文件名。
func get_file_name() -> String:
	return _file_name


## 检查本次操作是否替换了有效设置状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已应用持久化载荷或默认值恢复时返回 true。
func was_applied() -> bool:
	return _applied


## 检查本次操作是否执行了显式恢复动作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 使用恢复策略完成时返回 true。
func was_recovered() -> bool:
	return _recovered


## 获取实际恢复动作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 未恢复时为空，否则为 `GFSettingsRecoveryPolicy.ACTION_*` 常量之一。
func get_recovery_action() -> StringName:
	return _recovery_action


## 获取 Godot Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取稳定错误描述。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为空。
func get_error() -> String:
	return _error


## 获取底层存储读取结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 原始读取证据的隔离副本；读取未启动时为 null。
func get_storage_result() -> GFStorageReadResult:
	return _storage_result.duplicate_result() if _storage_result != null else null


## 创建结果的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象。
func duplicate_result() -> GFSettingsLoadResult:
	var copy: GFSettingsLoadResult = GFSettingsLoadResult.new()
	var _copy_configured: bool = copy.configure_for_framework(
		_ok,
		_status,
		_file_name,
		_applied,
		_recovered,
		_recovery_action,
		_error_code,
		_error,
		_storage_result
	)
	return copy


## 转换为不包含设置载荷的报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 加载终态摘要。
## [br]
## @schema return: Dictionary with ok, status, file_name, applied, recovered, recovery_action, error_code, error, and payload-free storage_result fields.
func to_dict() -> Dictionary:
	return {
		"ok": _ok,
		"status": _status,
		"file_name": _file_name,
		"applied": _applied,
		"recovered": _recovered,
		"recovery_action": _recovery_action,
		"error_code": int(_error_code),
		"error": _error,
		"storage_result": _get_storage_result_summary(),
	}


# --- 框架内部方法 ---

## 由 Settings Utility 一次性配置终态。
##
## 同一实例只能成功配置一次；不一致的状态组合会被拒绝。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param p_ok: 是否成功。
## [br]
## @param p_status: 稳定终态状态。
## [br]
## @param p_file_name: 实际设置文件名。
## [br]
## @param p_applied: 是否替换了有效设置状态。
## [br]
## @param p_recovered: 是否执行了恢复动作。
## [br]
## @param p_recovery_action: 实际恢复动作。
## [br]
## @param p_error_code: Godot Error 码。
## [br]
## @param p_error: 稳定错误描述。
## [br]
## @param p_storage_result: 底层读取证据。
## [br]
## @return 配置成功时返回 true。
func configure_for_framework(
	p_ok: bool,
	p_status: StringName,
	p_file_name: String,
	p_applied: bool,
	p_recovered: bool,
	p_recovery_action: StringName = &"",
	p_error_code: Error = OK,
	p_error: String = "",
	p_storage_result: GFStorageReadResult = null
) -> bool:
	if _configured:
		push_error("[GFSettingsLoadResult] 结果已经配置，不能重复修改。")
		return false
	if not _is_valid_configuration(
		p_ok,
		p_status,
		p_applied,
		p_recovered,
		p_recovery_action,
		p_storage_result
	):
		push_error("[GFSettingsLoadResult] 已拒绝不一致的加载终态配置。")
		return false

	_configured = true
	_ok = p_ok
	_status = p_status
	_file_name = p_file_name
	_applied = p_applied
	_recovered = p_recovered
	_recovery_action = p_recovery_action
	_error_code = OK if p_ok else (p_error_code if p_error_code != OK else FAILED)
	_error = "" if p_ok else p_error.strip_edges()
	_storage_result = p_storage_result.duplicate_result() if p_storage_result != null else null
	return true


# --- 私有/辅助方法 ---

func _is_valid_configuration(
	p_ok: bool,
	p_status: StringName,
	p_applied: bool,
	p_recovered: bool,
	p_recovery_action: StringName,
	p_storage_result: GFStorageReadResult
) -> bool:
	if not _is_known_status(p_status) or p_storage_result == null:
		return false

	if p_status == STATUS_LOADED:
		return (
			p_ok
			and p_applied
			and not p_recovered
			and p_recovery_action == &""
			and p_storage_result.ok
			and p_storage_result.is_integrity_accepted()
		)

	if p_status == STATUS_RECOVERED:
		return (
			p_ok
			and p_recovered
			and _is_recoverable_storage_result(p_storage_result)
			and (
				(
					p_recovery_action == GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE
					and not p_applied
				)
				or (
					p_recovery_action == GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
					and p_applied
				)
			)
		)

	return (
		not p_ok
		and not p_applied
		and not p_recovered
		and p_recovery_action == &""
		and _storage_result_matches_failure_status(p_status, p_storage_result)
	)


func _is_known_status(status: StringName) -> bool:
	return status in [
		STATUS_LOADED,
		STATUS_RECOVERED,
		STATUS_INVALID_REQUEST,
		STATUS_MISSING,
		STATUS_CORRUPT,
		STATUS_FUTURE_SCHEMA,
		STATUS_MIGRATION_FAILED,
		STATUS_STORAGE_FAILED,
	]


func _is_recoverable_storage_result(storage_result: GFStorageReadResult) -> bool:
	if storage_result.ok:
		return not storage_result.is_integrity_accepted()
	return storage_result.failure_kind in [
		GFStorageReadResult.FailureKind.NOT_FOUND,
		GFStorageReadResult.FailureKind.CORRUPT,
	]


func _storage_result_matches_failure_status(
	status: StringName,
	storage_result: GFStorageReadResult
) -> bool:
	var failure_kind: int = storage_result.failure_kind
	match status:
		STATUS_INVALID_REQUEST:
			return (
				not storage_result.ok
				and failure_kind == GFStorageReadResult.FailureKind.INVALID_REQUEST
			)
		STATUS_MISSING:
			return (
				not storage_result.ok
				and failure_kind == GFStorageReadResult.FailureKind.NOT_FOUND
			)
		STATUS_CORRUPT:
			return (
				(
					storage_result.ok
					and not storage_result.is_integrity_accepted()
				)
				or (
					not storage_result.ok
					and failure_kind == GFStorageReadResult.FailureKind.CORRUPT
				)
			)
		STATUS_FUTURE_SCHEMA:
			return (
				not storage_result.ok
				and failure_kind == GFStorageReadResult.FailureKind.FUTURE_VERSION
			)
		STATUS_MIGRATION_FAILED:
			return (
				not storage_result.ok
				and failure_kind == GFStorageReadResult.FailureKind.MIGRATION_FAILED
			)
		STATUS_STORAGE_FAILED:
			return (
				not storage_result.ok
				and failure_kind in [
					GFStorageReadResult.FailureKind.IO_FAILED,
					GFStorageReadResult.FailureKind.UNAVAILABLE,
				]
			)
		_:
			return false


func _get_storage_result_summary() -> Dictionary:
	if _storage_result == null:
		return {}
	var summary: Dictionary = _storage_result.to_dict()
	var _payload_erased: bool = summary.erase("payload")
	return summary
