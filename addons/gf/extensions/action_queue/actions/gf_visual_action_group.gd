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

# 内部使用：并行执行全部完成时发出。
signal _parallel_completed

# 内部使用：顺序执行全部完成时发出。
signal _sequence_completed

# 内部使用：暂停、取消或完成时唤醒内部等待。
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

const _ACTION_PROTOCOL = preload("res://addons/gf/extensions/action_queue/core/gf_action_protocol.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 公共变量 ---

## 包含的子动作列表。
## [br]
## @api public
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

var _execution_serial: int = 0
var _is_executing: bool = false
var _paused: bool = false
var _active_is_parallel: bool = true
var _active_parallel_completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL
var _active_cancel_remaining_on_first_completed: bool = true
var _active_actions: Array[Object] = []


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
	if actions.is_empty():
		return null

	_execution_serial += 1
	var current_serial: int = _execution_serial
	_is_executing = true
	_set_paused(false)
	_clear_active_actions()
	_active_is_parallel = is_parallel
	_active_parallel_completion_policy = parallel_completion_policy
	_active_cancel_remaining_on_first_completed = cancel_remaining_on_first_completed

	if is_parallel:
		return _run_parallel(current_serial)
	return _run_sequence(current_serial)


## 请求取消当前动作组执行。
## [br]
## @api public
func cancel() -> void:
	_execution_serial += 1
	_set_paused(false)
	_cancel_active_actions()
	_emit_active_completion()


## 暂停当前已启动子动作，并阻止后续子动作启动。
## [br]
## @api public
## [br]
## @since 6.0.0
func pause() -> void:
	_set_paused(true)
	_pause_active_actions()


## 恢复当前已启动子动作，并允许后续子动作继续启动。
## [br]
## @api public
## [br]
## @since 6.0.0
func resume() -> void:
	_resume_active_actions()
	_set_paused(false)


## 立即完成所有有效子动作并释放等待者。
## [br]
## @api public
func finish() -> void:
	_execution_serial += 1
	_set_paused(false)
	_finish_active_actions()
	_emit_active_completion()


# --- 私有/辅助方法 ---

func _run_parallel(current_serial: int) -> Variant:
	call_deferred("_do_parallel_async", current_serial)
	return _parallel_completed


func _run_sequence(current_serial: int) -> Variant:
	call_deferred("_do_sequence_async", current_serial)
	return _sequence_completed


func _do_parallel_async(current_serial: int) -> void:
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
	for action: Object in actions:
		if not _ACTION_PROTOCOL.is_action_valid(action):
			continue

		_inject_action_dependencies(action)
		if not _ACTION_PROTOCOL.can_execute(action):
			continue

		_mark_action_active(action)
		var result: Variant = _ACTION_PROTOCOL.execute(action)
		if _ACTION_PROTOCOL.should_wait_for_result(action, result):
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

	pending_state["launching"] = false
	_try_emit_parallel_completed(pending_state, current_serial)


func _do_sequence_async(current_serial: int) -> void:
	if current_serial != _execution_serial:
		return

	for action: Object in actions:
		await _wait_until_resumed(current_serial)
		if current_serial != _execution_serial:
			return

		if not _ACTION_PROTOCOL.is_action_valid(action):
			continue

		_inject_action_dependencies(action)
		if not _ACTION_PROTOCOL.can_execute(action):
			continue

		_mark_action_active(action)
		var result: Variant = _ACTION_PROTOCOL.execute(action)
		if _ACTION_PROTOCOL.should_wait_for_result(action, result):
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
		_unmark_action_active(action)

		if current_serial != _execution_serial:
			return

	_is_executing = false
	_clear_active_actions()
	_sequence_completed.emit()


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

	_unmark_action_active(action)
	if current_serial != _execution_serial:
		return

	pending_state["count"] = GFVariantData.get_option_int(pending_state, "count") - 1
	pending_state["completed_count"] = GFVariantData.get_option_int(pending_state, "completed_count") + 1
	_try_emit_parallel_completed(pending_state, current_serial, action)


func _inject_action_dependencies(action: Object) -> void:
	_ACTION_PROTOCOL.inject_dependencies(action, _get_architecture_or_null())


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
		_set_paused(false)
		if _active_cancel_remaining_on_first_completed:
			_cancel_pending_parallel_actions(pending_state, completed_action)
	_is_executing = false
	_clear_active_actions()
	_parallel_completed.emit()


func _cancel_pending_parallel_actions(pending_state: Dictionary, completed_action: Object = null) -> void:
	var pending_actions: Array = _get_pending_actions(pending_state)

	for action_variant: Variant in pending_actions:
		var action: Object = _get_object_value(action_variant)
		if action == null or action == completed_action:
			continue
		if is_instance_valid(action):
			_ACTION_PROTOCOL.cancel(action)
			_unmark_action_active(action)


func _is_execution_serial_current(serial: int) -> bool:
	return serial == _execution_serial


func _is_timeout_paused(serial: int) -> bool:
	return serial == _execution_serial and _paused


func _wait_until_resumed(serial: int) -> void:
	while serial == _execution_serial and _paused:
		await _state_changed


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


func _get_pending_actions(pending_state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(pending_state, "actions", []))


func _mark_action_active(action: Object) -> void:
	if is_instance_valid(action) and not _active_actions.has(action):
		_active_actions.append(action)


func _unmark_action_active(action: Object) -> void:
	if _active_actions.has(action):
		_active_actions.erase(action)


func _clear_active_actions() -> void:
	_active_actions.clear()


func _cancel_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	_clear_active_actions()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.cancel(action)


func _finish_active_actions() -> void:
	var active_snapshot: Array[Object] = _active_actions.duplicate()
	_clear_active_actions()
	for action: Object in active_snapshot:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.finish(action)


func _pause_active_actions() -> void:
	for action: Object in _active_actions:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.pause(action)


func _resume_active_actions() -> void:
	for action: Object in _active_actions:
		if is_instance_valid(action):
			_ACTION_PROTOCOL.resume(action)


func _set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	_state_changed.emit()


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
