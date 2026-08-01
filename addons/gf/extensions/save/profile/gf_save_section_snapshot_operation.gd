## GFSaveSectionSnapshotOperation: section 主线程协作式快照操作。
##
## Provider 在 `_advance_snapshot()` 中按 work budget 推进一个有界 slice，并通过
## `_complete_snapshot()` 或 `_fail_snapshot()` 进入唯一终态。该操作不会创建线程；
## 所有 Provider 回调仍由 GFSaveProfileUtility 在主线程调度。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveSectionSnapshotOperation
extends RefCounted


# --- 常量 ---

## 尚未执行 Provider slice。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_PENDING: StringName = &"pending"

## 正在等待后续主线程 slice。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_RUNNING: StringName = &"running"

## Snapshot 已准备完成且等待框架接管。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_SUCCEEDED: StringName = &"succeeded"

## Provider 准备失败。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_FAILED: StringName = &"failed"

## 框架停止了未完成准备。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CANCELLED: StringName = &"cancelled"

## 成功 Snapshot 已被框架接管。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CLAIMED: StringName = &"claimed"


# --- 私有变量 ---

var _status: StringName = STATUS_PENDING
var _section_id: StringName = &""
var _schema_version: int = 0
var _snapshot: GFSaveSectionSnapshot = null
var _error_code: Error = OK
var _error: String = ""
var _consumed_work_units: int = 0
var _configured: bool = false


# --- 公共方法 ---

## 创建一个已完成的小型 Snapshot 操作。
##
## 大型 Provider 不应在 begin 回调中调用该便捷方法构造完整数据，而应返回自定义
## Operation，并在 `_advance_snapshot()` 中按预算分片。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param snapshot: 已封存且尚未接管的 Snapshot。
## [br]
## @return 已成功操作；Snapshot 无效时返回已失败操作。
static func completed(snapshot: GFSaveSectionSnapshot) -> GFSaveSectionSnapshotOperation:
	var operation: GFSaveSectionSnapshotOperation = GFSaveSectionSnapshotOperation.new()
	if not operation._complete_snapshot(snapshot):
		var _failed: bool = operation._fail_snapshot(
			ERR_INVALID_DATA,
			"Completed snapshot is invalid or unavailable."
		)
	return operation


## 获取当前稳定状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取绑定的 section ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 配置前为空。
func get_section_id() -> StringName:
	return _section_id


## 获取绑定的 schema 版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 配置前为 0。
func get_schema_version() -> int:
	return _schema_version


## 检查是否仍需主线程推进。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return pending 或 running 时返回 true。
func is_pending() -> bool:
	return _status in [STATUS_PENDING, STATUS_RUNNING]


## 检查操作是否已经进入终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功、失败、取消或已接管时返回 true。
func is_completed() -> bool:
	return not is_pending()


## 检查 Provider 是否成功准备 Snapshot。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功或已接管时返回 true。
func is_successful() -> bool:
	return _status in [STATUS_SUCCEEDED, STATUS_CLAIMED]


## 获取稳定 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 失败或取消时的 Error；其他状态为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取稳定错误描述。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 失败或取消描述。
func get_error() -> String:
	return _error


## 获取框架已计入预算的工作量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负 work units。
func get_consumed_work_units() -> int:
	return _consumed_work_units


# --- 可重写钩子 / 虚方法 ---

## 以唯一成功 Snapshot 完成操作。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param snapshot: 已封存且尚未接管的 Snapshot。
## [br]
## @return 首次成功完成时返回 true。
func _complete_snapshot(snapshot: GFSaveSectionSnapshot) -> bool:
	if not is_pending() or snapshot == null or not snapshot.is_available():
		return false
	if _configured and not _snapshot_matches_definition(snapshot):
		var _failed: bool = _fail_snapshot(
			ERR_INVALID_DATA,
			"Snapshot identity does not match its Provider."
		)
		return false
	_snapshot = snapshot
	_status = STATUS_SUCCEEDED
	_error_code = OK
	_error = ""
	return true


## 以稳定错误完成操作。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param error_code: 非 OK 的 Godot Error 码。
## [br]
## @param error: 不含业务载荷的错误描述。
## [br]
## @return 首次失败完成时返回 true。
func _fail_snapshot(error_code: Error, error: String) -> bool:
	if not is_pending():
		return false
	if _snapshot != null:
		var _discarded: bool = _snapshot.discard_for_framework()
	_snapshot = null
	_status = STATUS_FAILED
	_error_code = error_code if error_code != OK else FAILED
	_error = error.strip_edges()
	if _error.is_empty():
		_error = "Save section snapshot preparation failed."
	return true


## 推进一个有界主线程 slice。
##
## 实现必须遵守 step_budget，并返回实际消费的 work units。框架无法抢占单次回调，
## 因此每个 unit 的上界由 Provider 契约保证。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _step_budget: 本次最多可消费的 work units。
## [br]
## @return 实际消费量；框架至少按 1 计费。
func _advance_snapshot(_step_budget: int) -> int:
	var _failed: bool = _fail_snapshot(
		ERR_UNAVAILABLE,
		"Snapshot operation must override _advance_snapshot()."
	)
	return 1


## 响应框架取消。
## [br]
## @api protected
## [br]
## @since unreleased
func _cancel_snapshot() -> void:
	pass


# --- 框架内部方法 ---

## 绑定 Provider 的稳定 section 定义。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param section_id: Provider section ID。
## [br]
## @param schema_version: Provider schema 版本。
## [br]
## @return 首次合法配置时返回 true。
func configure_for_framework(section_id: StringName, schema_version: int) -> bool:
	if _configured or section_id == &"" or schema_version <= 0:
		return false
	_configured = true
	_section_id = section_id
	_schema_version = schema_version
	if _snapshot != null and not _snapshot_matches_definition(_snapshot):
		var _failed: bool = _replace_success_with_failure(
			ERR_INVALID_DATA,
			"Snapshot identity does not match its Provider."
		)
		return false
	return true


## 按框架预算推进一次 Provider slice。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param step_budget: 正数 work-unit 预算。
## [br]
## @return 计入全局预算的 work units。
func advance_for_framework(step_budget: int) -> int:
	if not _configured or not is_pending() or step_budget <= 0:
		return 0
	_status = STATUS_RUNNING
	var reported_units: int = _advance_snapshot(step_budget)
	var charged_units: int = clampi(reported_units, 1, step_budget)
	_consumed_work_units += charged_units
	return charged_units


## 一次性接管成功 Snapshot。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 尚未接管的成功 Snapshot；其他状态返回 null。
func take_snapshot_for_framework() -> GFSaveSectionSnapshot:
	if _status != STATUS_SUCCEEDED or _snapshot == null:
		return null
	var result: GFSaveSectionSnapshot = _snapshot
	_snapshot = null
	_status = STATUS_CLAIMED
	return result


## 取消未完成操作，或释放已成功但尚未接管的 Snapshot。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 本次取消 pending/running 或尚未接管的 succeeded 操作时返回 true。
func cancel_for_framework() -> bool:
	if _status == STATUS_SUCCEEDED:
		if _snapshot != null:
			var _discarded: bool = _snapshot.discard_for_framework()
		_snapshot = null
		_status = STATUS_CANCELLED
		_error_code = ERR_UNAVAILABLE
		_error = "Save section snapshot preparation was cancelled before claim."
		return true
	if not is_pending():
		return false
	_cancel_snapshot()
	if _snapshot != null:
		var _discarded: bool = _snapshot.discard_for_framework()
	_snapshot = null
	_status = STATUS_CANCELLED
	_error_code = ERR_UNAVAILABLE
	_error = "Save section snapshot preparation was cancelled."
	return true


# --- 私有/辅助方法 ---

func _snapshot_matches_definition(snapshot: GFSaveSectionSnapshot) -> bool:
	return (
		snapshot != null
		and snapshot.get_section_id() == _section_id
		and snapshot.get_schema_version() == _schema_version
	)


func _replace_success_with_failure(error_code: Error, error: String) -> bool:
	if _status != STATUS_SUCCEEDED:
		return false
	if _snapshot != null:
		var _discarded: bool = _snapshot.discard_for_framework()
	_snapshot = null
	_status = STATUS_FAILED
	_error_code = error_code if error_code != OK else FAILED
	_error = error.strip_edges()
	return true
