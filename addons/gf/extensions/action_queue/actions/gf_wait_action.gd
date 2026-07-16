## GFWaitAction: 动作队列中的通用等待动作。
##
## 通过可暂停的帧循环表达一段时间等待，不携带业务含义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFWaitAction
extends GFVisualAction


# --- 信号 ---

## 等待完成时发出。取消后的旧计时器不会触发该信号。
## [br]
## @api public
signal wait_completed


# --- 常量 ---

const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 公共变量 ---

## 等待秒数。
## [br]
## @api public
## [br]
## @since 3.17.0
var seconds: float:
	get:
		return _seconds
	set(value):
		_seconds = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(value)

## 可选宿主节点。存在时优先从该节点获取 SceneTree。
## [br]
## @api public
var host_node: Node

## 计时器是否在暂停时继续处理。
## [br]
## @api public
var process_always: bool = true

## 是否按物理帧处理。
## [br]
## @api public
var process_in_physics: bool = false

## 是否忽略 Engine.time_scale。
## [br]
## @api public
var ignore_time_scale: bool = false


# --- 私有变量 ---

var _execution_serial: int = 0
var _seconds: float = 0.0
var _remaining_seconds: float = 0.0
var _paused: bool = false


# --- Godot 生命周期方法 ---

func _init(p_seconds: float = 0.0, p_host_node: Node = null) -> void:
	seconds = p_seconds
	host_node = p_host_node


# --- 公共方法 ---

## 启动等待计时器。
## [br]
## @api public
## [br]
## @return 需要等待时返回 wait_completed Signal；无需等待或无法获取 SceneTree 时返回 null。
## [br]
## @schema return: Variant，返回 wait_completed Signal 或 null。
func execute() -> Variant:
	if seconds <= 0.0:
		return null

	var tree: SceneTree = _get_scene_tree()
	if tree == null:
		return null

	_execution_serial += 1
	_remaining_seconds = seconds
	_paused = false
	_connect_host_guard()
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_complete_after_delay_async"), [tree, _execution_serial])
	return wait_completed


## 取消当前等待。
## [br]
## @api public
func cancel() -> void:
	_execution_serial += 1
	_remaining_seconds = 0.0
	_paused = false


## 暂停当前等待。
## [br]
## @api public
## [br]
## @since 6.0.0
func pause() -> void:
	_paused = true


## 恢复当前等待。
## [br]
## @api public
## [br]
## @since 6.0.0
func resume() -> void:
	_paused = false


## 立即完成当前等待并发出 wait_completed。
## [br]
## @api public
func finish() -> void:
	_execution_serial += 1
	_remaining_seconds = 0.0
	_paused = false
	wait_completed.emit()


## 返回等待宿主节点，用于队列等待时绑定生命周期。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 有效且仍在场景树内的宿主节点；没有宿主时返回 null。
func get_wait_guard_node() -> Node:
	return host_node if is_instance_valid(host_node) and host_node.is_inside_tree() else null


# --- 私有/辅助方法 ---

func _complete_after_delay_async(tree: SceneTree, serial: int) -> void:
	var last_msec: int = Time.get_ticks_msec()
	while serial == _execution_serial and _remaining_seconds > 0.0:
		if tree == null:
			return
		await _await_frame(tree)
		if serial != _execution_serial:
			return
		if not _is_host_guard_alive():
			_execution_serial += 1
			_remaining_seconds = 0.0
			_paused = false
			return

		var current_msec: int = Time.get_ticks_msec()
		var delta_seconds: float = float(current_msec - last_msec) / 1000.0
		last_msec = current_msec
		if _should_pause_countdown(tree):
			continue
		if not ignore_time_scale:
			delta_seconds *= Engine.time_scale
		_remaining_seconds = maxf(_remaining_seconds - delta_seconds, 0.0)

	if serial != _execution_serial:
		return
	if not _is_host_guard_alive():
		_execution_serial += 1
		_remaining_seconds = 0.0
		_paused = false
		return

	_remaining_seconds = 0.0
	_paused = false
	wait_completed.emit()


func _get_scene_tree() -> SceneTree:
	if host_node != null:
		if is_instance_valid(host_node) and host_node.is_inside_tree():
			return host_node.get_tree()
		return null
	return _get_scene_tree_value(Engine.get_main_loop())


func _get_scene_tree_value(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null


func _connect_host_guard() -> void:
	if host_node == null or not is_instance_valid(host_node):
		return
	var guard_callable: Callable = Callable(self, &"_on_host_node_tree_exiting")
	if host_node.tree_exiting.is_connected(guard_callable):
		return
	var _connect_result: Error = host_node.tree_exiting.connect(
		guard_callable,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


func _is_host_guard_alive() -> bool:
	if host_node == null:
		return true
	return is_instance_valid(host_node) and host_node.is_inside_tree()


func _await_frame(tree: SceneTree) -> void:
	if process_in_physics:
		await tree.physics_frame
		return
	await tree.process_frame


func _should_pause_countdown(tree: SceneTree) -> bool:
	if _paused:
		return true
	if process_always:
		return false
	return tree.paused


# --- 信号处理函数 ---

func _on_host_node_tree_exiting() -> void:
	cancel()
