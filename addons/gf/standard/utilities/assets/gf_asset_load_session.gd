## GFAssetLoadSession: 资产预加载事务句柄。
##
## 会话先把资源加载到唯一 staging group，只有全部成功后才提交目标 group。
## 失败或主动回滚只撤销 staging 所有权，不调用破坏共享句柄的 remove_cache()。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 9.0.0
class_name GFAssetLoadSession
extends RefCounted


# --- 信号 ---

## 会话状态变化后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param previous_state: 变化前状态。
## [br]
## @param current_state: 变化后状态。
signal state_changed(previous_state: State, current_state: State)

## 全部资源已加载且等待手动提交时发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param session: 当前会话。
signal ready_to_commit(session: GFAssetLoadSession)

## 会话进入 committed、failed 或 rolled_back 终态时发出一次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param result: 隔离终态结果。
signal completed(result: GFAssetLoadSessionResult)


# --- 枚举 ---

## 资产加载会话状态。
## [br]
## @api public
## [br]
## @since 9.0.0
enum State {
	## 已创建但未开始。
	CREATED,
	## 正在加载 staging group。
	LOADING,
	## 已加载并等待提交或回滚。
	READY,
	## 加载中收到回滚请求，等待在途回调收敛。
	ROLLBACK_PENDING,
	## 已提交目标 group。
	COMMITTED,
	## 加载或校验失败。
	FAILED,
	## 已由调用方回滚。
	ROLLED_BACK,
}


# --- 私有变量 ---

var _session_id: StringName = &""
var _staging_group_id: StringName = &""
var _plan: GFAssetPreloadPlan = null
var _utility_ref: WeakRef = null
var _state: State = State.CREATED
var _result: GFAssetLoadSessionResult = null
var _load_report: Dictionary = {}
var _auto_commit: bool = true
var _rollback_reason: StringName = &""
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 获取会话 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 会话 ID。
func get_session_id() -> StringName:
	return _session_id


## 获取目标分组 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 目标分组 ID。
func get_group_id() -> StringName:
	return _plan.group_id if _plan != null else &""


## 获取会话状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前状态。
func get_state() -> State:
	return _state


## 检查会话是否处于任一终态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return committed、failed 或 rolled_back 时返回 true。
func is_completed() -> bool:
	return _state in [State.COMMITTED, State.FAILED, State.ROLLED_BACK]


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 终态结果；尚未完成时返回 null。
func get_result() -> GFAssetLoadSessionResult:
	return _result.duplicate_result() if _result != null else null


## 获取底层加载报告副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return `preload_group_async` 报告副本。
## [br]
## @schema return: Dictionary with ok, group_id, paths, failed_paths, total, and completed.
func get_load_report() -> Dictionary:
	return _load_report.duplicate(true)


## 把已加载 staging 路径提交到目标 group。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return READY 状态首次提交成功返回 true。
func commit() -> bool:
	if _state != State.READY:
		return false
	var utility: GFAssetUtility = _get_utility()
	if utility == null:
		_finish_failure("Asset utility is no longer available.", &"utility_unavailable")
		return false
	var loaded_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(_load_report, "paths")
	for path: String in loaded_paths:
		utility.register_group_path(_plan.group_id, path, _plan.pin_cache)
	utility.unload_group(_staging_group_id, false)
	_set_state(State.COMMITTED)
	_finish_result(GFAssetLoadSessionResult.STATUS_COMMITTED, "", &"", false)
	return true


## 回滚会话。
##
## READY 状态立即撤销 staging group；LOADING 状态只记录意图，等待在途回调
## 收敛后再进入 rolled_back，避免迟到回调重新写入 staging group。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param reason: 回滚原因。
## [br]
## @return 首次接受回滚请求返回 true。
func rollback(reason: StringName = &"caller_requested") -> bool:
	if _state == State.LOADING:
		_rollback_reason = reason if reason != &"" else &"caller_requested"
		_set_state(State.ROLLBACK_PENDING)
		return true
	if _state != State.READY:
		return false
	_rollback_reason = reason if reason != &"" else &"caller_requested"
	_cleanup_staging_group()
	_set_state(State.ROLLED_BACK)
	_finish_result(GFAssetLoadSessionResult.STATUS_ROLLED_BACK, "", _rollback_reason, true)
	return true


# --- 私有/辅助方法 ---

# 由 GFAssetUtility 配置会话所有权。
func _gf_setup(
	utility: GFAssetUtility,
	session_id: StringName,
	plan: GFAssetPreloadPlan,
	options: Dictionary
) -> bool:
	if _session_id != &"" or utility == null or session_id == &"":
		return false
	_utility_ref = weakref(utility)
	_session_id = session_id
	_staging_group_id = StringName("_gf_staging_%s" % String(session_id))
	_plan = plan.duplicate_plan() if plan != null else null
	_auto_commit = GFVariantData.get_option_bool(options, "auto_commit", true)
	_metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return true


# 由 GFAssetUtility 启动会话。
func _gf_start() -> void:
	if _state != State.CREATED:
		return
	if _plan == null:
		_finish_failure("Asset preload plan is missing.", &"invalid_plan")
		return
	var validation: Dictionary = _plan.validate()
	if not GFVariantData.get_option_bool(validation, "ok"):
		_load_report = {"validation": validation.duplicate(true)}
		_finish_failure("Asset preload plan validation failed.", &"invalid_plan")
		return
	var utility: GFAssetUtility = _get_utility()
	if utility == null:
		_finish_failure("Asset utility is no longer available.", &"utility_unavailable")
		return
	_set_state(State.LOADING)
	var options: Dictionary = _plan.to_preload_options({"pin_cache": false})
	utility.preload_group_async(
		_staging_group_id,
		_plan.get_entries(),
		_on_preload_completed,
		options
	)


# 由 GFAssetUtility 在释放时中止会话。
func _gf_abort(reason: StringName) -> void:
	if is_completed():
		return
	_rollback_reason = reason if reason != &"" else &"aborted"
	_cleanup_staging_group()
	_finish_failure("Asset load session was aborted.", _rollback_reason)
func _on_preload_completed(report: Dictionary) -> void:
	_load_report = report.duplicate(true)
	if is_completed():
		_cleanup_staging_group()
		return
	if _state == State.ROLLBACK_PENDING:
		_cleanup_staging_group()
		_set_state(State.ROLLED_BACK)
		_finish_result(GFAssetLoadSessionResult.STATUS_ROLLED_BACK, "", _rollback_reason, true)
		return
	if not GFVariantData.get_option_bool(report, "ok"):
		_cleanup_staging_group()
		_finish_failure("One or more assets failed to preload.", &"load_failed")
		return
	_set_state(State.READY)
	ready_to_commit.emit(self)
	if _auto_commit and _state == State.READY:
		var _committed: bool = commit()


func _finish_failure(error: String, reason: StringName) -> void:
	_cleanup_staging_group()
	_set_state(State.FAILED)
	_finish_result(GFAssetLoadSessionResult.STATUS_FAILED, error, reason, true)


func _finish_result(
	status: StringName,
	error: String,
	rollback_reason: StringName,
	cache_retained: bool
) -> void:
	if _result != null:
		return
	_result = GFAssetLoadSessionResult.new()
	_result._gf_configure(
		status,
		_session_id,
		_plan.plan_id if _plan != null else &"",
		_plan.group_id if _plan != null else &"",
		GFVariantData.get_option_packed_string_array(_load_report, "paths"),
		GFVariantData.get_option_packed_string_array(_load_report, "failed_paths"),
		error,
		rollback_reason,
		cache_retained,
		_metadata
	)
	completed.emit(_result.duplicate_result())


func _cleanup_staging_group() -> void:
	var utility: GFAssetUtility = _get_utility()
	if utility != null and _staging_group_id != &"":
		utility.unload_group(_staging_group_id, false)


func _get_utility() -> GFAssetUtility:
	if _utility_ref == null:
		return null
	var value: Object = _utility_ref.get_ref()
	if value is GFAssetUtility:
		var utility: GFAssetUtility = value
		return utility
	return null


func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	var previous_state: State = _state
	_state = next_state
	state_changed.emit(previous_state, _state)
