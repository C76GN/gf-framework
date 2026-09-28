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

## GFAssetUtility 分配给本会话的稳定 ID。
## [br]
## @api private
## [br]
var _session_id: StringName = &""

## 本会话暂存预加载资源时使用的分组 ID。
## [br]
## @api private
## [br]
var _staging_group_id: StringName = &""

## 本会话配置的预加载计划。
## [br]
## @api private
## [br]
var _plan: GFAssetPreloadPlan = null

## 对创建本会话的 GFAssetUtility 的弱引用。
## [br]
## @api private
## [br]
var _utility_ref: WeakRef = null

## 会话当前所处的状态枚举值。
## [br]
## @api private
## [br]
var _state: State = State.CREATED

## 会话完成后构建的终态结果。
## [br]
## @api private
## [br]
var _result: GFAssetLoadSessionResult = null

## 最近一次收到的底层预加载报告。
## [br]
## @api private
## [br]
var _load_report: Dictionary = {}

## 控制会话进入 READY 后是否自动尝试提交。
## [br]
## @api private
## [br]
var _auto_commit: bool = true

## 回滚或中止时记录的原因标识。
## [br]
## @api private
## [br]
var _rollback_reason: StringName = &""

## 传递到会话终态结果中的调用方元数据。
## [br]
## @api private
## [br]
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


# --- 框架内部方法 ---

# 由 GFAssetUtility 配置会话所有权。
## 仅首次配置会话标识、工具弱引用和计划副本；失败时不覆盖已有配置。
## [br]
## @api framework_internal
## [br]
## @param utility: 负责实际预载与分组提交的资源工具，不由会话保持强引用。
## [br]
## @param session_id: 非空且由工具分配的会话标识。
## [br]
## @param plan: 要复制的预载计划；允许为空，启动时会报告无效计划。
## [br]
## @param options: 本次会话的自动提交与元数据选项。
## [br]
## @return 是否成功完成首次配置。
## [br]
## @schema options: Dictionary，读取 auto_commit（默认 true）和 metadata 字典。
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
## 仅在 CREATED 状态启动一次预载；计划验证通过后先切换 LOADING，再交给工具加载临时组。
## [br]
## @api framework_internal
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
## 对未完成会话清理临时组并提交失败结果；已有结果的会话不再改写。
## [br]
## @api framework_internal
## [br]
## @param reason: 中止原因；空值规范化为 aborted。
func _gf_abort(reason: StringName) -> void:
	if is_completed():
		return
	_rollback_reason = reason if reason != &"" else &"aborted"
	_cleanup_staging_group()
	_finish_failure("Asset load session was aborted.", _rollback_reason)



# --- 私有/辅助方法 ---

## 清理临时组后发出 FAILED 状态变更，再尝试产生一次失败结果；状态回调可能同步重入。
## [br]
## @api private
func _finish_failure(error: String, reason: StringName) -> void:
	_cleanup_staging_group()
	_set_state(State.FAILED)
	_finish_result(GFAssetLoadSessionResult.STATUS_FAILED, error, reason, true)


## 只在尚无结果时构造并存储终态结果，再发送结果副本；先保存结果使完成回调重入不能重复完成。
## [br]
## @api private
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


## 工具仍可访问且 staging ID 非空时卸载暂存分组。
## [br]
## @api private
## [br]
func _cleanup_staging_group() -> void:
	var utility: GFAssetUtility = _get_utility()
	if utility != null and _staging_group_id != &"":
		utility.unload_group(_staging_group_id, false)


## 解析弱引用中的 GFAssetUtility；引用失效或类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_utility() -> GFAssetUtility:
	if _utility_ref == null:
		return null
	var value: Object = _utility_ref.get_ref()
	if value is GFAssetUtility:
		var utility: GFAssetUtility = value
		return utility
	return null


## 状态实际变化时先写入新值再同步发信号；回调可以继续推动状态，本方法不锁定后续转换。
## [br]
## @api private
func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	var previous_state: State = _state
	_state = next_state
	state_changed.emit(previous_state, _state)


# --- 信号处理函数 ---

## 保存预载报告副本；已完成或等待回滚时只清理临时组并完成相应终态。
## 加载成功先通知 READY，通知返回后仍处于 READY 才允许自动提交，尊重回调中的提交或回滚。
## [br]
## @api private
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
