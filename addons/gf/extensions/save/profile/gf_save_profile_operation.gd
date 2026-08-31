## GFSaveProfileOperation: Save Profile 异步操作句柄。
##
## 句柄由 `GFSaveProfileUtility` 完成一次且只完成一次。调用方可在连接信号前检查
## `is_completed()`，避免立即拒绝或同步恢复结果造成竞态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 10.0.0
class_name GFSaveProfileOperation
extends RefCounted


# --- 信号 ---

## 操作进入终态时发出一次。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 隔离终态结果。
signal completed(result: GFSaveProfileResult)


# --- 常量 ---

## 保存操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_SAVE: StringName = &"save"

## 读取操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_LOAD: StringName = &"load"

## flush 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_FLUSH: StringName = &"flush"


# --- 私有变量 ---

var _operation: StringName = &""
var _profile_id: StringName = &""
var _requested_generation: int = 0
var _started_at_msec: int = 0
var _running: bool = false
var _result: GFSaveProfileResult = null
var _completion_emitted: bool = false
var _context: Dictionary = {}
var _result_metadata: Dictionary = {}
var _strict_recovery: bool = false
var _manager_permit: RefCounted = null


# --- 公共方法 ---

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


## 获取调用时捕获的 generation。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 非负 generation。
func get_requested_generation() -> int:
	return _requested_generation


## 检查操作是否等待调度。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 尚未运行或完成时返回 true。
func is_pending() -> bool:
	return not _running and _result == null


## 检查操作是否正在运行。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已启动但无终态时返回 true。
func is_running() -> bool:
	return _running and _result == null


## 检查操作是否已有终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFSaveProfileResult:
	return _result.duplicate_result() if _result != null else null


# --- 框架内部方法 ---

## 由 Save Profile Utility 配置 load 或 flush 句柄。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param operation: 操作类型。
## [br]
## @param profile_id: Profile ID。
## [br]
## @param requested_generation: 调用时捕获的 generation。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param context: Provider 临时上下文。
## [br]
## @param result_metadata: 调用方结果元数据。
## [br]
## @param strict_recovery: 仅 load 可设为 true；忽略保留当前状态的低层恢复动作。
## [br]
## @param manager_permit: 可选受管 load capability；Utility 会在应用 Provider 前复核。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @schema result_metadata: Dictionary with caller-defined result metadata.
## [br]
## @return 首次配置成功返回 true。
func configure_for_framework(
	operation: StringName,
	profile_id: StringName,
	requested_generation: int,
	started_at_msec: int,
	context: Dictionary = {},
	result_metadata: Dictionary = {},
	strict_recovery: bool = false,
	manager_permit: RefCounted = null
) -> bool:
	if (
		_operation != &""
		or operation not in [OPERATION_LOAD, OPERATION_FLUSH]
		or (strict_recovery and operation != OPERATION_LOAD)
		or (manager_permit != null and operation != OPERATION_LOAD)
	):
		return false
	_operation = operation
	_profile_id = profile_id
	_requested_generation = maxi(requested_generation, 0)
	_started_at_msec = maxi(started_at_msec, 0)
	_context = context.duplicate(true)
	_result_metadata = result_metadata.duplicate(true)
	_strict_recovery = strict_recovery
	_manager_permit = manager_permit
	return true


## 由 Save Profile Utility 以所有权转移方式配置 save 句柄。
##
## `result_metadata` 已由 `GFSaveProfileRequest` 一次性 claim；本方法只接管引用，
## 不遍历或深复制集合。Save 句柄不会持有文档元数据或 Provider context。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param profile_id: Profile ID。
## [br]
## @param requested_generation: 调用时捕获的 generation。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param result_metadata: 已移交所有权的调用方结果元数据。
## [br]
## @schema result_metadata: Dictionary whose source and nested aliases were abandoned by the request owner.
## [br]
## @return 首次配置成功返回 true。
func configure_save_ownership_for_framework(
	profile_id: StringName,
	requested_generation: int,
	started_at_msec: int,
	result_metadata: Dictionary
) -> bool:
	if _operation != &"":
		return false
	_operation = OPERATION_SAVE
	_profile_id = profile_id
	_requested_generation = maxi(requested_generation, 0)
	_started_at_msec = maxi(started_at_msec, 0)
	_result_metadata = result_metadata
	return true


## 由 Save Profile Utility 标记为运行中。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return 从 pending 转为 running 时返回 true。
func start_for_framework() -> bool:
	if not is_pending():
		return false
	_running = true
	return true


## 由 Save Profile Utility 写入唯一终态，但暂不发出外部信号。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param result: 唯一终态结果。
## [br]
## @return 首次写入终态成功返回 true。
func complete_for_framework(result: GFSaveProfileResult) -> bool:
	if _result != null or result == null:
		return false
	_running = false
	_result = result.duplicate_result()
	_context = {}
	_result_metadata = {}
	_manager_permit = null
	return true


## 在协调器提交稳定状态后发出终态信号。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return 首次发出终态信号时返回 true。
func emit_completed_for_framework() -> bool:
	if _result == null or _completion_emitted:
		return false
	_completion_emitted = true
	completed.emit(_result.duplicate_result())
	return true


## 获取操作开始时间。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return 单调开始时间。
func get_started_at_msec_for_framework() -> int:
	return _started_at_msec


## 获取 Provider 临时上下文副本。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return Provider 临时上下文副本。
## [br]
## @schema return: Dictionary with caller-defined ephemeral operation data.
func get_context_for_framework() -> Dictionary:
	return _context.duplicate(true)


## 获取调用方结果元数据副本。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return 调用方结果元数据副本。
## [br]
## @schema return: Dictionary with caller-defined result metadata.
func get_metadata_for_framework() -> Dictionary:
	return _result_metadata.duplicate(true)


## 检查读取是否必须忽略保留当前状态的恢复策略。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 受管事务要求严格读取时返回 true。
func requires_strict_recovery_for_framework() -> bool:
	return _operation == OPERATION_LOAD and _strict_recovery


## 获取受管 load 绑定的 opaque capability。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 非受管 load 返回 null；调用方只能执行对象身份复核。
func get_manager_permit_for_framework() -> RefCounted:
	return _manager_permit if _operation == OPERATION_LOAD else null
