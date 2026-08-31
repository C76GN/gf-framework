## GFSaveProfileTransactionOperation: Profile 身份与持久化事务的异步句柄。
##
## 句柄由 Save Profile 事务协调器完成一次且只完成一次。调用方可在连接信号前
## 检查 `is_completed()`，避免同步拒绝或立即终态造成竞态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFSaveProfileTransactionOperation
extends RefCounted


# --- 信号 ---

## 事务进入终态时发出一次。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result: 不包含 Provider payload 的隔离终态结果。
signal completed(result: GFSaveProfileTransactionResult)


# --- 常量 ---

## 激活已存在的 Profile 存档。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_ACTIVATE: StringName = &"activate"

## 从当前活跃 Profile 事务切换到另一个已存在 Profile。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_SWITCH: StringName = &"switch"

## 用当前 Provider 状态显式创建缺失 Profile 并激活。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_BOOTSTRAP: StringName = &"bootstrap"

## 显式采用当前 Provider 状态作为恢复后的活跃 Profile。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_ADOPT: StringName = &"adopt"

## 从活动来源重新 flush 后，以当前 Provider 状态创建缺失目标并原子切换。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_BOOTSTRAP_AND_SWITCH: StringName = &"bootstrap_and_switch"

## 从活动来源重新 flush 后，以当前 Provider 状态覆盖损坏目标并原子切换。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_ADOPT_AND_SWITCH: StringName = &"adopt_and_switch"

## 应用完整候选 section 并持久化。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_MUTATE_AND_PERSIST: StringName = &"mutate_and_persist"

## 对账此前 outcome_unknown 的事务。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_RECONCILE: StringName = &"reconcile"


# --- 私有变量 ---

var _operation: StringName = &""
var _transaction_id: int = 0
var _source_profile_id: StringName = &""
var _target_profile_id: StringName = &""
var _started_at_msec: int = 0
var _running: bool = false
var _result: GFSaveProfileTransactionResult = null
var _completion_emitted: bool = false


# --- 公共方法 ---

## 获取事务类型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取 Utility 生命周期内唯一的事务 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数事务 ID；尚未配置时为 0。
func get_transaction_id() -> int:
	return _transaction_id


## 获取事务来源 Profile ID。
##
## activate、bootstrap 与 adopt 没有来源身份；switch、bootstrap/adopt-and-switch、
## mutate-and-persist 和 reconcile 使用当前受管 Profile 作为来源。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 来源 Profile ID；不适用时为空。
func get_source_profile_id() -> StringName:
	return _source_profile_id


## 获取事务目标 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 目标 Profile ID；不适用时为空。
func get_target_profile_id() -> StringName:
	return _target_profile_id


## 检查事务是否等待调度。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 尚未运行或完成时返回 true。
func is_pending() -> bool:
	return not _running and _result == null


## 检查事务是否正在运行。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已启动但无终态时返回 true。
func is_running() -> bool:
	return _running and _result == null


## 检查事务是否已有终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取终态结果副本。
##
## 结果副本中的 Recovery/Reconcile Lease 保留原始句柄身份，其他集合均隔离复制。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFSaveProfileTransactionResult:
	return _result.duplicate_result() if _result != null else null


# --- 框架内部方法 ---

## 由 Save Profile 事务协调器一次性配置句柄身份。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param operation: `OPERATION_*` 常量之一。
## [br]
## @param transaction_id: Utility 生命周期内唯一的正整数事务 ID。
## [br]
## @param source_profile_id: 来源 Profile ID；不适用时为空。
## [br]
## @param target_profile_id: 目标 Profile ID；不适用时为空。
## [br]
## @param started_at_msec: 非负单调开始时间。
## [br]
## @return 输入合法且首次配置时返回 true。
func configure_for_framework(
	operation: StringName,
	transaction_id: int,
	source_profile_id: StringName,
	target_profile_id: StringName,
	started_at_msec: int
) -> bool:
	if _operation != &"" or operation not in _get_valid_operations():
		return false
	if transaction_id <= 0:
		return false
	_operation = operation
	_transaction_id = transaction_id
	_source_profile_id = source_profile_id
	_target_profile_id = target_profile_id
	_started_at_msec = maxi(started_at_msec, 0)
	return true


## 由 Save Profile 事务协调器标记为运行中。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 从 pending 转为 running 时返回 true。
func start_for_framework() -> bool:
	if _operation == &"" or not is_pending():
		return false
	_running = true
	return true


## 写入唯一终态，但暂不发出外部信号。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param result: 与当前句柄事务身份一致的唯一终态结果。
## [br]
## @return 首次写入匹配终态时返回 true。
func complete_for_framework(result: GFSaveProfileTransactionResult) -> bool:
	if _result != null or result == null:
		return false
	if (
		result.get_transaction_id() != _transaction_id
		or result.get_operation() != _operation
		or result.get_source_profile_id() != _source_profile_id
		or result.get_target_profile_id() != _target_profile_id
	):
		return false
	_running = false
	_result = result.duplicate_result()
	return true


## 在协调器提交稳定状态后发出终态信号。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 首次发出终态信号时返回 true。
func emit_completed_for_framework() -> bool:
	if _result == null or _completion_emitted:
		return false
	_completion_emitted = true
	completed.emit(_result.duplicate_result())
	return true


## 获取当前事务开始时间。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 非负单调毫秒时间。
func get_started_at_msec_for_framework() -> int:
	return _started_at_msec


# --- 私有/辅助方法 ---

static func _get_valid_operations() -> Array[StringName]:
	return [
		OPERATION_ACTIVATE,
		OPERATION_SWITCH,
		OPERATION_BOOTSTRAP,
		OPERATION_ADOPT,
		OPERATION_BOOTSTRAP_AND_SWITCH,
		OPERATION_ADOPT_AND_SWITCH,
		OPERATION_MUTATE_AND_PERSIST,
		OPERATION_RECONCILE,
	]
