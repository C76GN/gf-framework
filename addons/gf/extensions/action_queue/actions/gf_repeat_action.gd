## GFRepeatAction: 按工厂重复创建并执行队列动作。
##
## 每轮通过 action_factory 创建一个新的动作对象，避免复用同一个动作实例时
## 残留 Tween、Timer 或节点引用状态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFRepeatAction
extends GFVisualAction


# --- 信号 ---

## 重复流程结束时发出。
## [br]
## @api public
signal repeat_completed


# --- 常量 ---

const _ACTION_PROTOCOL = preload("res://addons/gf/extensions/action_queue/core/gf_action_protocol.gd")

## 单帧最多连续执行的瞬时重复次数，避免无限重复的瞬时动作锁住主线程。
## [br]
## @api public
const DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME: int = 256


# --- 公共变量 ---

## 动作工厂。每次调用应返回一个动作对象；返回 null 会结束重复。
## [br]
## @api public
var action_factory: Callable

## 重复次数。0 表示无限重复，直到 cancel()、finish() 或工厂返回 null。
## [br]
## @api public
var repeat_count: int = 1

## 单帧最多连续执行的瞬时重复次数。小于 1 时按 1 处理。
## [br]
## @api public
var max_immediate_iterations_per_frame: int = DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME


# --- 私有变量 ---

var _execution_serial: int = 0
var _paused: bool = false
var _active_action: Object = null


# --- Godot 生命周期方法 ---

func _init(p_action_factory: Callable = Callable(), p_repeat_count: int = 1) -> void:
	action_factory = p_action_factory
	repeat_count = maxi(p_repeat_count, 0)


# --- 公共方法 ---

## 启动重复执行流程。
## [br]
## @api public
## [br]
## @return action_factory 有效时返回 repeat_completed Signal；无效时返回 null。
## [br]
## @schema return: Variant，返回 repeat_completed Signal 或 null。
func execute() -> Variant:
	if not action_factory.is_valid():
		return null

	if is_instance_valid(_active_action):
		_ACTION_PROTOCOL.cancel(_active_action)
		_active_action = null
		repeat_completed.emit()

	_execution_serial += 1
	call_deferred("_run_repeat_async", _execution_serial)
	return repeat_completed


## 取消重复流程并取消当前动作。
## [br]
## @api public
func cancel() -> void:
	_execution_serial += 1
	_paused = false
	if is_instance_valid(_active_action):
		_ACTION_PROTOCOL.cancel(_active_action)
	_active_action = null


## 暂停重复流程和当前动作。
## [br]
## @api public
func pause() -> void:
	_paused = true
	if is_instance_valid(_active_action):
		_ACTION_PROTOCOL.pause(_active_action)


## 恢复重复流程和当前动作。
## [br]
## @api public
func resume() -> void:
	_paused = false
	if is_instance_valid(_active_action):
		_ACTION_PROTOCOL.resume(_active_action)


## 立即完成重复流程并释放等待者。
## [br]
## @api public
func finish() -> void:
	_execution_serial += 1
	_paused = false
	if is_instance_valid(_active_action):
		_ACTION_PROTOCOL.finish(_active_action)
	_active_action = null
	repeat_completed.emit()


# --- 私有/辅助方法 ---

func _run_repeat_async(current_serial: int) -> void:
	var tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if tree == null:
		return

	var completed_count: int = 0
	var immediate_count: int = 0
	while current_serial == _execution_serial:
		if repeat_count > 0 and completed_count >= repeat_count:
			break

		while _paused and current_serial == _execution_serial:
			await tree.process_frame

		if current_serial != _execution_serial:
			return

		var action: Object = _get_object_value(action_factory.call())
		if not _ACTION_PROTOCOL.is_action_valid(action) or not _ACTION_PROTOCOL.can_execute(action):
			break

		_active_action = action
		_ACTION_PROTOCOL.inject_dependencies(action, _get_architecture_or_null())
		var result: Variant = _ACTION_PROTOCOL.execute(action)
		var waited: bool = false
		if _ACTION_PROTOCOL.should_wait_for_result(action, result):
			waited = true
			immediate_count = 0
			await _ACTION_PROTOCOL.await_result_safely(
				action,
				result,
				_is_execution_serial_current.bind(current_serial),
				_is_timeout_paused.bind(current_serial),
				_get_architecture_or_null()
			)

		if current_serial != _execution_serial:
			return

		_active_action = null
		completed_count += 1
		if waited:
			continue

		immediate_count += 1
		if immediate_count >= maxi(max_immediate_iterations_per_frame, 1):
			immediate_count = 0
			await tree.process_frame

	if current_serial == _execution_serial:
		repeat_completed.emit()


func _is_execution_serial_current(serial: int) -> bool:
	return serial == _execution_serial


func _is_timeout_paused(serial: int) -> bool:
	return serial == _execution_serial and _paused


func _get_scene_tree_value(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
