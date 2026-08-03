## GFVirtualInputPulseOperation: 单次虚拟输入脉冲的类型化运行时句柄。
##
## 句柄冻结创建时的 Mapping、source_id、player_index 与 action_id，并由
## GFInputMappingUtility 的权威 lease 保证旧定时器不会释放后续脉冲。owner 与
## cancellation_token 均为可选锚点；同时提供时，任一先结束都会取消脉冲。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFVirtualInputPulseOperation
extends RefCounted


# --- 信号 ---

## 脉冲首次进入终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param operation: 已进入终态的当前句柄。
signal completed(operation: GFVirtualInputPulseOperation)


# --- 枚举 ---

## 脉冲操作状态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 等待定时、生命周期或显式终止。
	PENDING,
	## 到达脉冲时长并完成匹配释放。
	COMPLETED,
	## 被调用方、owner、token 或状态清理取消。
	CANCELLED,
	## 被同一稳定输入键上的新脉冲替换。
	REPLACED,
	## 因同一稳定输入键已有脉冲而拒绝启动。
	REJECTED,
	## 输入或运行时依赖无效，未能启动。
	FAILED,
}


# --- 私有变量 ---

var _status: Status = Status.PENDING
var _terminal_reason: StringName = &""
var _generation: int = 0
var _source_id: StringName = &""
var _player_index: int = -1
var _action_id: StringName = &""
var _duration_seconds: float = 0.0
var _started_at_msec: int = 0
var _completed_at_msec: int = 0
var _release_count: int = 0
var _lease_acquired: bool = false
var _mapping_ref: WeakRef = null
var _source_completion_invocation: GFWeakMethodInvocation = null
var _timer_ref: WeakRef = null
var _timer_handle: int = 0
var _owner_lifetime: GFLifetimeSubscription = null
var _cancel_token: GFCancellationToken = null
var _cancel_token_callback: Callable = Callable()


# --- 公共方法 ---

## 取消仍在等待的脉冲。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 稳定取消原因；空值会规范化为 cancelled。
## [br]
## @return: 本次调用是否首次使操作进入终态。
func cancel(reason: StringName = &"cancelled") -> bool:
	return _request_terminal(Status.CANCELLED, reason if reason != &"" else &"cancelled")


## 获取 Source 分配的单调 generation。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 大于零的 generation；配置失败前可能为 0。
func get_generation() -> int:
	return _generation


## 获取冻结的虚拟输入源标识。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 创建脉冲时的 source_id。
func get_source_id() -> StringName:
	return _source_id


## 获取冻结的玩家索引。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 创建脉冲时的 player_index。
func get_player_index() -> int:
	return _player_index


## 获取冻结的动作标识。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 创建脉冲时的 action_id。
func get_action_id() -> StringName:
	return _action_id


## 获取规范化脉冲时长。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 秒数。
func get_duration_seconds() -> float:
	return _duration_seconds


## 获取当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: Status 枚举值。
func get_status() -> Status:
	return _status


## 获取终态原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 等待中为空 StringName；终态时为稳定原因。
func get_terminal_reason() -> StringName:
	return _terminal_reason


## 返回操作是否仍在等待。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 等待中返回 true。
func is_pending() -> bool:
	return _status == Status.PENDING


## 返回操作是否已经进入任意终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已完成、取消、替换、拒绝或失败时返回 true。
func is_completed() -> bool:
	return _status != Status.PENDING


## 获取该脉冲完成的匹配释放次数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 仅当前 lease 实际清除动作贡献时为 1；无释放交接、未取得 lease 或未释放时为 0。
func get_release_count() -> int:
	return _release_count


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 冻结身份、状态、时长、时间戳与释放证明。
## [br]
## @schema return: Dictionary，包含 generation、source_id、player_index、action_id、duration_seconds、status、status_name、terminal_reason、pending、completed、started_at_msec、completed_at_msec、release_count、lease_acquired 和 timer_handle。
func get_debug_snapshot() -> Dictionary:
	return {
		"generation": _generation,
		"source_id": _source_id,
		"player_index": _player_index,
		"action_id": _action_id,
		"duration_seconds": _duration_seconds,
		"status": _status,
		"status_name": Status.keys()[_status],
		"terminal_reason": _terminal_reason,
		"pending": is_pending(),
		"completed": is_completed(),
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
		"release_count": _release_count,
		"lease_acquired": _lease_acquired,
		"timer_handle": _timer_handle,
	}


# --- 框架内部方法 ---

## 由 GFVirtualInputSource 冻结操作身份并绑定可选生命周期锚点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param input_mapping: 创建时的输入映射工具。
## [br]
## @param source: 创建当前 generation 的虚拟输入源。
## [br]
## @param generation: Source 分配的单调 generation。
## [br]
## @param source_id: 冻结的虚拟输入源标识。
## [br]
## @param player_index: 冻结的玩家索引。
## [br]
## @param action_id: 冻结的动作标识。
## [br]
## @param duration_seconds: 有界脉冲时长。
## [br]
## @param owner: 可选生命周期 owner。
## [br]
## @param cancellation_token: 可选取消 token。
## [br]
## @return: 首次配置成功返回 true。
func configure_for_framework(
	input_mapping: GFInputMappingUtility,
	source: GFVirtualInputSource,
	generation: int,
	source_id: StringName,
	player_index: int,
	action_id: StringName,
	duration_seconds: float,
	owner: Object,
	cancellation_token: GFCancellationToken
) -> bool:
	if _generation != 0 or generation <= 0:
		return false
	_generation = generation
	_source_id = source_id
	_player_index = player_index
	_action_id = action_id
	_duration_seconds = duration_seconds
	_started_at_msec = Time.get_ticks_msec()
	_mapping_ref = weakref(input_mapping) if input_mapping != null else null
	_source_completion_invocation = GFWeakMethodInvocation.new(
		source,
		&"notify_pulse_operation_completed_for_framework"
	)
	if not _bind_owner(owner):
		var _failed_owner: bool = _finish(Status.FAILED, &"invalid_owner_lifecycle", false)
		return true
	if (
		cancellation_token != null
		and not cancellation_token.is_cancel_requested()
		and cancellation_token is GFAsyncScope
	):
		var async_scope: GFAsyncScope = cancellation_token
		if async_scope.is_completed():
			var _failed_scope: bool = _finish(
				Status.FAILED,
				&"cancellation_scope_completed",
				false
			)
			return true
	if not _bind_cancellation_token(cancellation_token):
		var _failed_token: bool = _finish(Status.FAILED, &"cancellation_token_bind_failed", false)
	return true


## 由 GFVirtualInputSource 使用注入的 GFTimerUtility 启动有界计时。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param timer_utility: Source 注入的定时器工具。
## [br]
## @return: 已排队、同步完成或已进入其他终态时返回 true。
func arm_timer_for_framework(timer_utility: GFTimerUtility) -> bool:
	if not is_pending() or timer_utility == null:
		return not is_pending()
	_timer_ref = weakref(timer_utility)
	var timer_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		self,
		&"_on_pulse_timer_elapsed"
	)
	var timer_callback: Callable = func() -> void:
		var _invoke_result: Dictionary = timer_invocation.invoke()
	_timer_handle = timer_utility.execute_after_owned(self, _duration_seconds, timer_callback)
	return not is_pending() or _duration_seconds > 0.0 and _timer_handle > 0


## 由 Mapping 在发布 lease 后冻结已取得状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @return: 当前操作首次取得 lease 时返回 true。
func mark_lease_acquired_for_framework() -> bool:
	if not is_pending() or _lease_acquired:
		return false
	_lease_acquired = true
	return true


## 由 Mapping 提交唯一终态并记录是否执行了匹配释放。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param status: 非 PENDING 终态。
## [br]
## @param reason: 稳定终态原因。
## [br]
## @param release_performed: Mapping 是否为当前 lease 执行了匹配释放。
## [br]
## @return: 首次进入终态返回 true。
func finish_from_mapping_for_framework(
	status: Status,
	reason: StringName,
	release_performed: bool
) -> bool:
	return _finish(status, reason, release_performed)


## 由 Mapping tick 检查普通 Object owner 的弱生命周期。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @return: 检查后操作是否仍在等待。
func poll_lifecycle_for_framework() -> bool:
	if not is_pending():
		return false
	var cancellation_scope_completed: bool = false
	if _cancel_token is GFAsyncScope:
		var async_scope: GFAsyncScope = _cancel_token
		cancellation_scope_completed = async_scope.is_completed()
	if _owner_lifetime != null and _owner_lifetime.owner_is_released():
		var _cancelled_for_owner: bool = _request_terminal(Status.CANCELLED, &"owner_released")
	elif _cancel_token != null and _cancel_token.is_cancel_requested():
		var reason: StringName = _cancel_token.get_cancel_reason()
		var _cancelled_for_token: bool = _request_terminal(
			Status.CANCELLED,
			reason if reason != &"" else &"cancellation_requested"
		)
	elif cancellation_scope_completed:
		var _cancelled_for_scope: bool = _request_terminal(
			Status.CANCELLED,
			&"cancellation_scope_completed"
		)
	elif _lease_acquired and _duration_seconds > 0.0:
		var timer_utility: GFTimerUtility = _get_timer_utility()
		if (
			timer_utility == null
			or not timer_utility.has_owned_timer_for_framework(_timer_handle, self)
		):
			var _failed_for_timer: bool = _request_terminal(
				Status.FAILED,
				&"timer_schedule_lost"
			)
	return is_pending()


## 检查当前操作是否由指定 Mapping 创建。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param input_mapping: 待验证的输入映射工具。
## [br]
## @return: 冻结 Mapping 仍存活且身份一致时返回 true。
func matches_mapping_for_framework(input_mapping: GFInputMappingUtility) -> bool:
	return input_mapping != null and _get_input_mapping() == input_mapping


## 在尚未取得 Mapping lease 时提交拒绝或失败终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param status: REJECTED、FAILED 或 CANCELLED。
## [br]
## @param reason: 稳定终态原因。
## [br]
## @return: 首次进入终态返回 true。
func finish_without_lease_for_framework(status: Status, reason: StringName) -> bool:
	if status not in [Status.REJECTED, Status.FAILED, Status.CANCELLED]:
		return false
	return _finish(status, reason, false)


# --- 私有/辅助方法 ---

func _request_terminal(status: Status, reason: StringName) -> bool:
	if not is_pending():
		return false
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping != null:
		var finished_by_mapping: bool = input_mapping.finish_virtual_pulse_lease_for_framework(
			self,
			status,
			reason
		)
		if finished_by_mapping:
			return true
		if _lease_acquired:
			return false
	return _finish(status, reason, false)


func _finish(status: Status, reason: StringName, release_performed: bool) -> bool:
	if not is_pending() or status == Status.PENDING:
		return false
	_status = status
	_terminal_reason = reason if reason != &"" else _default_reason_for_status(status)
	_completed_at_msec = Time.get_ticks_msec()
	_release_count = 1 if release_performed else 0
	_disconnect_runtime_anchors()
	if _source_completion_invocation != null:
		var _source_result: Dictionary = _source_completion_invocation.invoke([_generation, self])
	completed.emit(self)
	return true


func _bind_owner(owner: Object) -> bool:
	if owner == null:
		return true
	if not is_instance_valid(owner):
		return false
	if owner is Node:
		var owner_node: Node = owner
		if not owner_node.is_inside_tree():
			return false
	var owner_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		self,
		&"_on_pulse_owner_released"
	)
	var cancel_callback: Callable = func() -> void:
		var _invoke_result: Dictionary = owner_invocation.invoke()
	_owner_lifetime = GFLifetimeSubscription.new(
		owner,
		cancel_callback,
		"virtual_input_pulse:%s:%s" % [_source_id, _action_id]
	)
	return _owner_lifetime.is_active()


func _bind_cancellation_token(cancellation_token: GFCancellationToken) -> bool:
	if cancellation_token == null:
		return true
	_cancel_token = cancellation_token
	if cancellation_token.is_cancel_requested():
		var reason: StringName = cancellation_token.get_cancel_reason()
		var _cancelled_immediately: bool = _finish(
			Status.CANCELLED,
			reason if reason != &"" else &"cancellation_requested",
			false
		)
		return true
	if cancellation_token is GFAsyncScope:
		var async_scope: GFAsyncScope = cancellation_token
		if async_scope.is_completed():
			_cancel_token = null
			return false
	var token_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		self,
		&"_on_pulse_token_cancelled"
	)
	_cancel_token_callback = func(reason: StringName) -> void:
		var _invoke_result: Dictionary = token_invocation.invoke([reason])
	var connect_error: Error = cancellation_token.cancel_requested.connect(
		_cancel_token_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		_cancel_token = null
		_cancel_token_callback = Callable()
		return false
	if cancellation_token.is_cancel_requested():
		var reason: StringName = cancellation_token.get_cancel_reason()
		_on_pulse_token_cancelled(reason)
	return true


func _disconnect_runtime_anchors() -> void:
	var timer_utility: GFTimerUtility = _get_timer_utility()
	if timer_utility != null and _timer_handle > 0:
		var _cancelled_timer_count: int = timer_utility.cancel_owner(self)
	_timer_handle = 0
	_timer_ref = null
	if _owner_lifetime != null and _owner_lifetime.is_active():
		var _owner_cancelled: bool = _owner_lifetime.cancel()
	_owner_lifetime = null
	if (
		_cancel_token != null
		and _cancel_token_callback.is_valid()
		and _cancel_token.cancel_requested.is_connected(_cancel_token_callback)
	):
		_cancel_token.cancel_requested.disconnect(_cancel_token_callback)
	_cancel_token = null
	_cancel_token_callback = Callable()


func _get_input_mapping() -> GFInputMappingUtility:
	if _mapping_ref == null:
		return null
	var mapping_value: Variant = _mapping_ref.get_ref()
	if mapping_value is GFInputMappingUtility:
		var input_mapping: GFInputMappingUtility = mapping_value
		return input_mapping
	return null


func _get_timer_utility() -> GFTimerUtility:
	if _timer_ref == null:
		return null
	var timer_value: Variant = _timer_ref.get_ref()
	if timer_value is GFTimerUtility:
		var timer_utility: GFTimerUtility = timer_value
		return timer_utility
	return null


func _default_reason_for_status(status: Status) -> StringName:
	match status:
		Status.COMPLETED:
			return &"duration_elapsed"
		Status.CANCELLED:
			return &"cancelled"
		Status.REPLACED:
			return &"replaced"
		Status.REJECTED:
			return &"rejected"
		Status.FAILED:
			return &"failed"
	return &""


func _on_pulse_timer_elapsed() -> void:
	var _completed_now: bool = _request_terminal(Status.COMPLETED, &"duration_elapsed")


func _on_pulse_owner_released() -> void:
	var _cancelled_now: bool = _request_terminal(Status.CANCELLED, &"owner_released")


func _on_pulse_token_cancelled(reason: StringName) -> void:
	var _cancelled_now: bool = _request_terminal(
		Status.CANCELLED,
		reason if reason != &"" else &"cancellation_requested"
	)
