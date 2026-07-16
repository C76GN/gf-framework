## GFConfiguredTweenAction: 由 GFTweenActionConfig 驱动的通用 Tween 动作。
##
## 允许项目把表现动画拆成 Resource 配置，再交给 GFActionQueueSystem 编排。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFConfiguredTweenAction
extends GFVisualAction


# --- 信号 ---

## Tween 步骤标记到达后发出。
## [br]
## @api public
## [br]
## @param marker_id: 标记标识。
## [br]
## @param step_index: 步骤索引。
## [br]
## @param target: 被缓动目标。
signal marker_reached(marker_id: StringName, step_index: int, target: Object)


# --- 公共变量 ---

## 被缓动的目标对象。
## [br]
## @api public
var target: Object

## Tween 配置。
## [br]
## @api public
var config: GFTweenActionConfig

## 可选 Tween 宿主节点。目标不是 Node 时必须提供。
## [br]
## @api public
var host_node: Node


# --- 私有变量 ---

var _active_tween: Tween = null
var _initial_values: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_target: Object = null,
	p_config: GFTweenActionConfig = null,
	p_host_node: Node = null
) -> void:
	target = p_target
	config = p_config
	host_node = p_host_node


# --- 公共方法 ---

## 执行配置化 Tween。
## [br]
## @api public
## [br]
## @return 需要等待时返回内部完成 Signal；配置无效、目标无效或瞬时写入时返回 null。
## [br]
## @schema return: Variant，返回内部完成 Signal 或 null。
func execute() -> Variant:
	if config == null or config.is_empty() or not is_instance_valid(target):
		return null

	_clear_active_tween()
	_reset_completion_state()
	_capture_initial_values()
	if not config.has_timed_steps():
		config.apply_instant(target)
		_restore_initial_values_on_finish()
		return null

	var tween_host: Node = _get_tween_host()
	if tween_host == null:
		push_warning("[GFConfiguredTweenAction] 缺少有效 Tween 宿主节点。")
		return null

	_active_tween = tween_host.create_tween()
	var _set_ignore_time_scale_result_91: Variant = _active_tween.set_ignore_time_scale(config.ignore_time_scale)
	var _set_process_mode_result_92: Variant = _active_tween.set_process_mode(config.process_mode)
	var _set_pause_mode_result_93: Variant = _active_tween.set_pause_mode(config.pause_mode)
	if config.loop_count != 1:
		var _set_loops_result_95: Variant = _active_tween.set_loops(config.loop_count)

	var appended_count: int = 0
	for step_index: int in range(config.steps.size()):
		var step: GFTweenActionStep = config.steps[step_index]
		if step == null:
			continue
		if step.append_to_tween(_active_tween, target, config.duration_scale) != null:
			appended_count += 1
			_append_marker_callback(step, step_index)

	if appended_count <= 0:
		_clear_active_tween()
		return null
	var _finished_connected: Error = _active_tween.finished.connect(
		_on_active_tween_finished,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return _action_completed


## 取消当前 Tween，并按配置恢复初始值。
## [br]
## @api public
func cancel() -> void:
	_clear_active_tween()
	_restore_initial_values_on_cancel()
	_emit_completed_once()


## 暂停当前 Tween。
## [br]
## @api public
func pause() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.pause()


## 恢复当前 Tween。
## [br]
## @api public
func resume() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.play()


## 立即完成当前 Tween，并按配置恢复初始值。
## [br]
## @api public
func finish() -> void:
	if is_instance_valid(_active_tween):
		_clear_active_tween()
		if config != null and config.loop_count != 0 and is_instance_valid(target):
			config.apply_instant(target)
		_restore_initial_values_on_finish()
		_emit_completed_once()
		return
	_clear_active_tween()
	_restore_initial_values_on_finish()
	_emit_completed_once()


## 获取用于保护等待生命周期的 Tween 宿主节点。
## [br]
## @api public
## [br]
## @return 有效宿主节点；无效时返回 null。
func get_wait_guard_node() -> Node:
	var tween_host: Node = _get_tween_host()
	return tween_host if is_instance_valid(tween_host) else null


# --- 私有/辅助方法 ---

func _get_tween_host() -> Node:
	if is_instance_valid(host_node) and host_node.is_inside_tree():
		return host_node
	if target is Node and is_instance_valid(target):
		var target_node: Node = _get_node_value(target)
		if target_node != null and target_node.is_inside_tree():
			return target_node
	return null


func _clear_active_tween() -> void:
	if is_instance_valid(_active_tween):
		if _active_tween.finished.is_connected(_on_active_tween_finished):
			_active_tween.finished.disconnect(_on_active_tween_finished)
		_active_tween.kill()
	_active_tween = null


func _append_marker_callback(step: GFTweenActionStep, step_index: int) -> void:
	if step.marker_id == &"" or not is_instance_valid(_active_tween):
		return
	var _tween_callback_result_188: Variant = _active_tween.tween_callback(
		Callable(self, "_on_step_marker_reached").bind(step.marker_id, step_index)
	)


func _capture_initial_values() -> void:
	_initial_values.clear()
	if config == null or not (config.restore_initial_values_on_cancel or config.restore_initial_values_on_finish):
		return
	_initial_values = config.capture_initial_values(target)


func _restore_initial_values_on_cancel() -> void:
	if config == null or not config.restore_initial_values_on_cancel:
		return
	config.restore_initial_values(target, _initial_values)


func _restore_initial_values_on_finish() -> void:
	if config == null or not config.restore_initial_values_on_finish:
		return
	config.restore_initial_values(target, _initial_values)


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


# --- 信号处理函数 ---

func _on_active_tween_finished() -> void:
	_active_tween = null
	_restore_initial_values_on_finish()
	_emit_completed_once()


func _on_step_marker_reached(marker_id: StringName, step_index: int) -> void:
	marker_reached.emit(marker_id, step_index, target)
