## GFVisualActionGroup: 动作组复合节点 (Composite Pattern)
## 
## 继承自 GFVisualAction。允许将一组子动作打包，按并行（全部一起发出并按策略等待）
## 或顺序（逐个执行并等待各自完成）两种模式执行。
## 子动作可以继承 GFVisualAction，也可以直接实现动作协议方法。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFVisualActionGroup
extends GFVisualAction


# --- 信号 ---

## 并行动作组满足完成策略时发出的内部等待信号。
## [br]
## @api private
signal _parallel_completed

## 顺序动作组执行完毕或被终止时发出的内部等待信号。
## [br]
## @api private
signal _sequence_completed

## 暂停状态变化时唤醒等待中的动作组循环。
## [br]
## @api private
signal _state_changed


# --- 枚举 ---

## 并行动作组何时视为完成。
## [br]
## @api public
## [br]
## @since 3.24.0
enum ParallelCompletionPolicy {
	## 等待所有需要等待的子动作完成。
	WAIT_FOR_ALL,
	## 任一子动作完成后就结束动作组。
	FIRST_COMPLETED,
}


# --- 常量 ---

## 子动作有效性、执行和控制操作协议。
## [br]
## @api private
const _ACTION_PROTOCOL = preload("res://addons/gf/extensions/action_queue/core/gf_action_protocol.gd")

## 并行动作等待任务的 detached 异步调用器。
## [br]
## @api private
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 公共变量 ---

## 包含的子动作列表。execute() 会冻结当前列表供本轮使用，运行期修改只影响下一轮；
## 并行计划不接受重复的同一动作实例。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @schema actions: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。
var actions: Array[Object] = []

## 是否并行执行。为 true 时，并行触发所有子动作并按 parallel_completion_policy 完成；
## 为 false 时，按数组顺序依次执行并等待各自完成。
## [br]
## @api public
var is_parallel: bool = true

## 并行动作组完成策略。
## [br]
## @api public
## [br]
## @since 3.24.0
var parallel_completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL

## FIRST_COMPLETED 完成策略触发后，是否取消仍在等待的子动作。
## [br]
## @api public
## [br]
## @since 3.24.0
var cancel_remaining_on_first_completed: bool = true


# --- 私有变量 ---

## 每次启动或终止执行递增，用于停止旧异步循环。
## [br]
## @api private
var _execution_serial: int = 0

## 标记动作组当前是否有活动执行。
## [br]
## @api private
var _is_executing: bool = false

## 标记动作组是否暂停。
## [br]
## @api private
var _paused: bool = false

## 当前执行轮次冻结的并行/顺序模式。
## [br]
## @api private
var _active_is_parallel: bool = true

## 当前并行轮次冻结的完成策略。
## [br]
## @api private
var _active_parallel_completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL

## FIRST_COMPLETED 策略完成时是否取消未结束子动作。
## [br]
## @api private
var _active_cancel_remaining_on_first_completed: bool = true

## 当前已启动且尚未从动作组记录中移除的子动作。
## [br]
## @api private
var _active_actions: Array[Object] = []

## 阻止动作控制回调期间重入控制流程。
## [br]
## @api private
var _control_callback_in_progress: bool = false


# --- Godot 生命周期方法 ---

func _init(
	actions_list: Array = [],
	parallel: bool = true,
	completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL
) -> void:
	actions.clear()
	for action: Variant in actions_list:
		var action_object: Object = _get_object_value(action)
		if action_object != null:
			actions.append(action_object)
	is_parallel = parallel
	parallel_completion_policy = completion_policy


# --- 公共方法 ---

## 添加一个子动作。
## [br]
## @api public
## [br]
## @param action: 动作对象。
func add(action: Object) -> void:
	if is_instance_valid(action):
		actions.append(action)


## 执行动作组逻辑。根据 is_parallel 决定并发还是串行。
## [br]
## @api public
## [br]
## @return 需要等待则返回内部完成信号，否则返回 null。
## [br]
## @schema return: Variant，动作组为空时返回 null；否则返回内部完成 Signal。
func execute() -> Variant:
	if _control_callback_in_progress:
		return null
	var action_plan: Array[Object] = _snapshot_actions()
	if action_plan.is_empty():
		return null
	var run_in_parallel: bool = is_parallel
	if run_in_parallel and _has_duplicate_action_instance(action_plan):
		push_error("[GFVisualActionGroup][visual_action_group.duplicate_parallel_action] The parallel execution plan contains a duplicate action instance.")
		return null

	_control_callback_in_progress = true
	if _is_executing:
		_execution_serial += 1
		_set_paused(false)
		_cancel_active_actions()
		_emit_active_completion()

	_execution_serial += 1
	var current_serial: int = _execution_serial
	_is_executing = true
	_set_paused(false)
	_clear_active_actions()
	_active_is_parallel = run_in_parallel
	_active_parallel_completion_policy = parallel_completion_policy
	_active_cancel_remaining_on_first_completed = cancel_remaining_on_first_completed
	_control_callback_in_progress = false

	if _active_is_parallel:
		return _run_parallel(current_serial, action_plan)
	return _run_sequence(current_serial, action_plan)


## 请求取消当前动作组执行。
## [br]
## @api public
func cancel() -> void:
	if _control_callback_in_progress:
		return
	_execution_serial += 1
	_control_callback_in_progress = true
	_set_paused(false)
	_cancel_active_actions()
	_emit_active_completion()
	_control_callback_in_progress = false


## 暂停当前已启动子动作，并阻止后续子动作启动。
## [br]
## @api public
## [br]
## @since 6.0.0
func pause() -> void:
	if _control_callback_in_progress:
		return
	_control_callback_in_progress = true
	_set_paused(true)
	_pause_active_actions()
	_control_callback_in_progress = false


## 恢复当前已启动子动作，并允许后续子动作继续启动。
## [br]
## @api public
## [br]
## @since 6.0.0
func resume() -> void:
	if _control_callback_in_progress:
		return
	_control_callback_in_progress = true
	_resume_active_actions()
	_set_paused(false)
	_control_callback_in_progress = false


## 立即完成所有有效子动作并释放等待者。
## [br]
## @api public
func finish() -> void:
	if _control_callback_in_progress:
		return
	_execution_serial += 1
	_control_callback_in_progress = true
	_set_paused(false)
	_finish_active_actions()
	_emit_active_completion()
	_control_callback_in_progress = false


# --- 私有/辅助方法 ---

## 将并行执行器排入 deferred 调用，并返回并行组完成信号。
## [br]
## @api private
func _run_parallel(current_serial: int, action_plan: Array[Object]) -> Variant:
	call_deferred("_do_parallel_async", current_serial, action_plan)
	return _parallel_completed


## 将顺序执行器排入 deferred 调用，并返回顺序组完成信号。
## [br]
## @api private
func _run_sequence(current_serial: int, action_plan: Array[Object]) -> Variant:
	call_deferred("_do_sequence_async", current_serial, action_plan)
	return _sequence_completed


## 按冻结动作计划启动有效并行动作，并独立等待需要阻塞的子动作。
## 启动阶段结束后依据冻结完成策略判断是否完成。
## [br]
## @api private
func _do_parallel_async(current_serial: int, action_plan: Array[Object]) -> void:
	if current_serial != _execution_serial:
		return
	await _wait_until_resumed(current_serial)
	if current_serial != _execution_serial:
		return

	var pending_state: Dictionary = {
		"count": 0,
		"completed_count": 0,
		"launching": true,
		"emitted": false,
		"actions": [],
	}
	for action: Object in action_plan:
		await _wait_until_resumed(current_serial)
		if current_serial != _execution_serial:
			return

		var action_valid: bool = _ACTION_PROTOCOL.is_action_valid(action)
		if current_serial != _execution_serial:
			return
		if not action_valid:
			continue

		_inject_action_dependencies(action)
		if current_serial != _execution_serial:
			return
		var action_can_execute: bool = _ACTION_PROTOCOL.can_execute(action)
		if current_serial != _execution_serial:
			return
		if not action_can_execute:
			continue

		_mark_action_active(action)
		var result: Variant = _ACTION_PROTOCOL.execute(action)
		if current_serial != _execution_serial:
			return
		var should_wait: bool = _ACTION_PROTOCOL.should_wait_for_result(action, result)
		if current_serial != _execution_serial:
			return
		if should_wait:
			pending_state["count"] = GFVariantData.get_option_int(pending_state, "count") + 1
			var pending_actions: Array = _get_pending_actions(pending_state)
			pending_actions.append(action)
			_GF_ASYNC_CALL_SCRIPT.run_detached(
				Callable(self, &"_wait_parallel_action"),
				[action, result, pending_state, current_serial]
			)
		elif _active_parallel_completion_policy == ParallelCompletionPolicy.FIRST_COMPLETED:
			_unmark_action_active(action)
			pending_state["completed_count"] = GFVariantData.get_option_int(pending_state, "completed_count") + 1
		else:
			_unmark_action_active(action)

	if current_serial != _execution_serial:
		return
	pending_state["launching"] = false
	_try_emit_parallel_completed(pending_state, current_serial)


## 按冻结计划逐项检查、注入依赖并执行；需要等待时先等动作结果再继续。
## 每次异步等待或用户回调后检查执行序号，旧轮次不会继续消费计划。
## [br]
## @api private
func _do_sequence_async(current_serial: int, action_plan: Array[Object]) -> void:
	if current_serial != _execution_serial:
		return

	for action: Object in action_plan:
		await _wait_until_resumed(current_serial)
		if current_serial != _execution_serial:
			return

		var action_valid: bool = _ACTION_PROTOCOL.is_action_valid(action)
		if current_serial != _execution_serial:
			return
		if not action_valid:
			continue

		_inject_action_dependencies(action)
		if current_serial != _execution_serial:
			return
		var action_can_execute: bool = _ACTION_PROTOCOL.can_execute(action)
		if current_serial != _execution_serial:
			return
		if not action_can_execute:
			continue

		_mark_action_active(action)
		var result: Variant = _ACTION_PROTOCOL.execute(action)
		if current_serial != _execution_serial:
			return
		var should_wait: bool = _ACTION_PROTOCOL.should_wait_for_result(action, result)
		if current_serial != _execution_serial:
			return
		if should_wait:
			await _ACTION_PROTOCOL.await_result_safely(
				action,
				result,
				_is_execution_serial_current.bind(current_serial),
				_is_timeout_paused.bind(current_serial),
				_get_architecture_or_null()
			)
			if current_serial != _execution_serial:
				return
			await _wait_until_resumed(current_serial)
			if current_serial != _execution_serial:
				return
		_unmark_action_active(action)

		if current_serial != _execution_serial:
			return

	_is_executing = false
	_clear_active_actions()
	_sequence_completed.emit()


## 安全等待一个并行动作并更新待完成计数；无效实例也作为完成项收敛。
## [br]
## @api private
func _wait_parallel_action(
	action: Object,
	result: Variant,
	pending_state: Dictionary,
	current_serial: int,
) -> void:
	if current_serial != _execution_serial:
		return
	if not is_instance_valid(action):
		_unmark_action_active(action)
		pending_state["count"] = GFVariantData.get_option_int(pending_state, "count") - 1
		pending_state["completed_count"] = GFVariantData.get_option_int(pending_state, "completed_count") + 1
		_try_emit_parallel_completed(pending_state, current_serial)
		return

	await _ACTION_PROTOCOL.await_result_safely(
		action,
		result,
		_is_execution_serial_current.bind(current_serial),
		_is_timeout_paused.bind(current_serial),
		_get_architecture_or_null()
	)

	if current_serial != _execution_serial:
		return
	_unmark_action_active(action)

	pending_state["count"] = GFVariantData.get_option_int(pending_state, "count") - 1
	pending_state["completed_count"] = GFVariantData.get_option_int(pending_state, "completed_count") + 1
	_try_emit_parallel_completed(pending_state, current_serial, action)


## 通过动作协议向子动作注入当前架构实例。
## [br]
## @api private
func _inject_action_dependencies(action: Object) -> void:
	_ACTION_PROTOCOL.inject_dependencies(action, _get_architecture_or_null())


## 在全部动作已启动后检查完成策略，并最多发出一次并行完成信号。
## FIRST_COMPLETED 触发时按配置取消剩余动作后结束本轮。
## [br]
## @api private
func _try_emit_parallel_completed(
	pending_state: Dictionary,
	current_serial: int,
	completed_action: Object = null
) -> void:
	if current_serial != _execution_serial:
		return
	if GFVariantData.get_option_bool(pending_state, "launching"):
		return
	if GFVariantData.get_option_bool(pending_state, "emitted"):
		return

	if _active_parallel_completion_policy == ParallelCompletionPolicy.WAIT_FOR_ALL:
		if GFVariantData.get_option_int(pending_state, "count") > 0:
			return
	else:
		var completed_count: int = GFVariantData.get_option_int(pending_state, "completed_count")
		var pending_count: int = GFVariantData.get_option_int(pending_state, "count")
		if completed_count <= 0 and pending_count > 0:
			return

	pending_state["emitted"] = true
	if _active_parallel_completion_policy == ParallelCompletionPolicy.FIRST_COMPLETED:
		_execution_serial += 1
		_control_callback_in_progress = true
		_set_paused(false)
		if _active_cancel_remaining_on_first_completed:
			_cancel_pending_parallel_actions(pending_state, completed_action)
		_control_callback_in_progress = false
	_is_executing = false
	_clear_active_actions()
	_parallel_completed.emit()


## 取消待处理列表中除已完成动作外的有效对象，并从活动集合移除。
## [br]
## @api private
func _cancel_pending_parallel_actions(pending_state: Dictionary, completed_action: Object = null) -> void:
	var pending_actions: Array = _get_pending_actions(pending_state)

	for action_variant: Variant in pending_actions:
		var action: Object = _get_object_value(action_variant)
		if action == null or action == completed_action:
			continue
		if is_instance_valid(action):
			_ACTION_PROTOCOL.cancel(action)
			_unmark_action_active(action)


## 判断等待回调捕获的序号仍属于当前动作组执行。
## [br]
## @api private
func _is_execution_serial_current(serial: int) -> bool:
	return serial == _execution_serial


## 判断捕获序号仍匹配且动作组处于暂停状态。
## [br]
## @api private
func _is_timeout_paused(serial: int) -> bool:
	return serial == _execution_serial and _paused


## 在匹配执行仍暂停时等待状态变更信号。
## [br]
## @api private
func _wait_until_resumed(serial: int) -> void:
	while serial == _execution_serial and _paused:
		await _state_changed


## 若动作组正在执行，清理活动集合并按模式发出对应完成信号和状态唤醒信号。
## [br]
## @api private
func _emit_active_completion() -> void:
	if not _is_executing:
		return

	_is_executing = false
	_clear_active_actions()
	if _active_is_parallel:
		_parallel_completed.emit()
	else:
		_sequence_completed.emit()
	_state_changed.emit()


## 从并行状态字典读取待处理动作数组；缺失或非数组时返回空数组。
## [br]
## @api private
func _get_pending_actions(pending_state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(pending_state, "actions", []))


## 将公开动作列表复制为本轮使用的类型化执行计划。
## [br]
## @api private
func _snapshot_actions() -> Array[Object]:
	var action_plan: Array[Object] = []
	action_plan.assign(actions)
	return action_plan


## 检查计划中是否重复包含同一个有效动作对象实例。
## [br]
## @api private
func _has_duplicate_action_instance(action_plan: Array[Object]) -> bool:
	var seen_actions: Array[Object] = []
	for action: Object in action_plan:
		if not is_instance_valid(action):
			continue
		if seen_actions.has(action):
			return true
		seen_actions.append(action)
	return false


## 仅将有效且尚未登记的动作加入活动集合。
## [br]
## @api private
func _mark_action_active(action: Object) -> void:
	if is_instance_valid(action) and not _active_actions.has(action):
		_active_actions.append(action)


## 若活动集合包含指定动作则将其移除。
## [br]
## @api private
func _unmark_action_active(action: Object) -> void:
	if _active_actions.has(action):
		_active_actions.erase(action)


## 清空当前活动子动作集合。
## [br]
## @api private
func _clear_active_actions() -> void:
	_active_actions.clear()


## 先快照并清空活动集合，再取消快照中的有效子动作。
## [br]
## @api private
func _cancel_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	_clear_active_actions()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.cancel(action)


## 先快照并清空活动集合，再立即完成快照中的有效子动作。
## [br]
## @api private
func _finish_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	_clear_active_actions()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.finish(action)


## 暂停活动集合快照中的有效子动作。
## [br]
## @api private
func _pause_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.pause(action)


## 恢复活动集合快照中的有效子动作。
## [br]
## @api private
func _resume_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.resume(action)


## 仅在暂停值变化时更新状态并发出唤醒信号。
## [br]
## @api private
func _set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	_state_changed.emit()


## 将 Variant 收窄为 Object；类型不符时返回 null。
## [br]
## @api private
func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
