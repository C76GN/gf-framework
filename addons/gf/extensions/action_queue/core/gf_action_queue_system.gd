## GFActionQueueSystem: 逻辑与表现解耦的动作队列系统。
## 负责串行或并行消费动作对象，并在等待 Signal 时对发射源失效做防死锁保护。
## 动作可继承 `GFVisualAction`，也可直接实现 execute()/can_execute()/cancel() 等同名协议方法。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFActionQueueSystem
extends GFSystem


# --- 信号 ---

## 当队列从有内容变为全部执行完毕时发出。
## [br]
## @api public
signal queue_drained

# 内部使用：暂停状态变化时唤醒队列处理协程。
signal _pause_state_changed


# --- 常量 ---

const _ACTION_PROTOCOL = preload("res://addons/gf/extensions/action_queue/core/gf_action_protocol.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const _DEBUG_SNAPSHOT_MAX_DEPTH: int = 8


# --- 公共变量 ---

## 是否正在处理队列。
## [br]
## @api public
var is_processing: bool = false

## 单个处理切片最多消费的即时动作数；达到上限后让出到下一 process frame。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_immediate_actions_per_slice: int:
	get:
		return _max_immediate_actions_per_slice
	set(value):
		_max_immediate_actions_per_slice = maxi(value, 1)

## 调试快照最多展开的直接命名队列数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_debug_named_queue_entries: int:
	get:
		return _max_debug_named_queue_entries
	set(value):
		_max_debug_named_queue_entries = maxi(value, 0)


# --- 私有变量 ---

# 内部动作队列。
var _queue: Array[Object] = []

# 当前队头索引，避免消费队列时频繁 pop_front() 触发数组搬移。
var _queue_head_index: int = 0

# 当前处理轮次，用于取消正在等待 Signal 的旧消费协程。
var _processing_serial: int = 0

# 当前正在执行或等待的动作。
var _current_action: Object = null

# 按名称分流的子队列。
var _named_queues: Dictionary = {}

# 当前队列绑定节点的弱引用。
var _linked_node_ref: WeakRef = null

# 当前队列绑定节点；用于主动断开 tree_exited。
var _linked_node: Node = null

# 动作执行拦截器。
var _interceptors: Array[GFActionInterceptor] = []

# 当前队列暂停状态。
var _is_paused: bool = false

# 当前队列是否已经释放。
var _is_disposed: bool = false

# 单帧同步消费预算的受控存储。
var _max_immediate_actions_per_slice: int = 256
var _max_debug_named_queue_entries: int = 64


# --- GF 生命周期方法 ---

## 初始化主队列、命名队列和拦截器状态。
## [br]
## @api public
func init() -> void:
	if is_processing or is_instance_valid(_current_action) or not _queue.is_empty() or not _named_queues.is_empty():
		clear_queue(true)
		_dispose_all_named_queues()

	_is_disposed = false
	_processing_serial += 1
	_queue.clear()
	_queue_head_index = 0
	_current_action = null
	_named_queues.clear()
	_disconnect_linked_node()
	_linked_node_ref = null
	_interceptors.clear()
	_set_paused(false)
	is_processing = false


## 注册诊断工具快照。
## [br]
## @api public
func ready() -> void:
	_register_diagnostics_contribution()


## 释放当前队列、命名队列和诊断注册。
## [br]
## @api public
func dispose() -> void:
	if _is_disposed:
		return
	_is_disposed = true
	_unregister_diagnostics_contribution()
	clear_queue(true)
	_disconnect_linked_node()
	_linked_node_ref = null
	_dispose_all_named_queues()
	_interceptors.clear()


# --- 公共方法 ---

## 注入当前队列所属架构，并同步给已注册拦截器。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	super.inject_dependencies(architecture)
	for interceptor: GFActionInterceptor in _interceptors:
		_inject_interceptor_dependencies(interceptor)


## 将一个动作加入顺序队列。
## [br]
## @api public
## [br]
## @param action: 要处理的动作对象。
func enqueue(action: Object) -> void:
	if _is_disposed:
		return
	if not is_instance_valid(action):
		return

	_queue.push_back(action)
	_try_start_processing()


## 将一个动作以显式 fire-and-forget 模式加入队列。
## [br]
## @api public
## [br]
## @param action: 要处理的动作对象。
func enqueue_fire_and_forget(action: Object) -> void:
	if _is_disposed:
		return
	if not is_instance_valid(action):
		return

	_ACTION_PROTOCOL.set_fire_and_forget(action)
	enqueue(action)


## 将一批动作加入队列并并行执行。
## [br]
## @api public
## [br]
## @param actions: 要处理的动作对象列表。
## [br]
## @schema actions: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。
func enqueue_parallel(actions: Array) -> void:
	if _is_disposed:
		return
	if actions.is_empty():
		return

	var group: GFVisualActionGroup = GFVisualActionGroup.new(actions, true)
	_queue.push_back(group)
	_try_start_processing()


## 将一个动作插入队列头部。
## [br]
## @api public
## [br]
## @param action: 要处理的动作对象。
func push_front(action: Object) -> void:
	if _is_disposed:
		return
	if not is_instance_valid(action):
		return

	_push_front_action(action)
	_try_start_processing()


## 将一个动作以显式 fire-and-forget 模式插入队列头部。
## [br]
## @api public
## [br]
## @param action: 要处理的动作对象。
func push_front_fire_and_forget(action: Object) -> void:
	if _is_disposed:
		return
	if not is_instance_valid(action):
		return

	_ACTION_PROTOCOL.set_fire_and_forget(action)
	push_front(action)


## 将一批并行动作插入队列头部。
## [br]
## @api public
## [br]
## @param actions: 要处理的动作对象列表。
## [br]
## @schema actions: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。
func push_front_parallel(actions: Array) -> void:
	if _is_disposed:
		return
	if actions.is_empty():
		return

	var group: GFVisualActionGroup = GFVisualActionGroup.new(actions, true)
	_push_front_action(group)
	_try_start_processing()


## 清空队列中尚未执行的动作。
## [br]
## @api public
## [br]
## @param stop_current: 为 true 时同时取消当前正在等待 Signal 的动作队列消费。
func clear_queue(stop_current: bool = false) -> void:
	var was_processing: bool = is_processing
	_queue.clear()
	_queue_head_index = 0
	if stop_current:
		_processing_serial += 1
		_set_paused(false)
		_cancel_current_action()
		is_processing = false
		if was_processing:
			queue_drained.emit()
	_publish_diagnostics_contribution()


## 获取或创建一个命名动作队列。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @return 命名队列；queue_name 为空时返回 null。
func get_named_queue(queue_name: StringName) -> GFActionQueueSystem:
	if _is_disposed:
		return null
	if queue_name == &"":
		push_error("[GFActionQueueSystem] get_named_queue 失败：queue_name 为空。")
		return null
	if _named_queues.has(queue_name):
		return _get_named_queue_value(queue_name)

	var queue: GFActionQueueSystem = GFActionQueueSystem.new()
	var architecture: GFArchitecture = _get_architecture_or_null()
	queue.init()
	queue.max_immediate_actions_per_slice = max_immediate_actions_per_slice
	queue.max_debug_named_queue_entries = max_debug_named_queue_entries
	if architecture != null:
		queue.inject_dependencies(architecture)
	_named_queues[queue_name] = queue
	_publish_diagnostics_contribution()
	return queue


## 创建或获取一个绑定到节点生命周期的命名队列。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param linked_node: 与队列生命周期绑定的节点。
## [br]
## @return 绑定后的命名队列；queue_name 为空时返回 null。
func get_linked_queue(queue_name: StringName, linked_node: Node) -> GFActionQueueSystem:
	var queue: GFActionQueueSystem = get_named_queue(queue_name)
	if queue == null:
		return null
	queue.bind_to_node(linked_node)
	return queue


## 将当前队列绑定到节点生命周期；节点失效后队列会停止并清空。
## [br]
## @api public
## [br]
## @param linked_node: 与队列生命周期绑定的节点。
func bind_to_node(linked_node: Node) -> void:
	_disconnect_linked_node()
	_linked_node_ref = weakref(linked_node) if linked_node != null else null
	_linked_node = linked_node
	if linked_node != null:
		var _tree_exited_connected: Error = linked_node.tree_exited.connect(
			_on_linked_node_tree_exited,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error


## 添加动作执行拦截器。
## [br]
## @api public
## [br]
## @param interceptor: 拦截器实例。
## [br]
## @return 添加成功返回 true。
func add_interceptor(interceptor: GFActionInterceptor) -> bool:
	if interceptor == null:
		return false
	if _interceptors.has(interceptor):
		return false

	_interceptors.append(interceptor)
	_sort_interceptors()
	_inject_interceptor_dependencies(interceptor)
	_publish_diagnostics_contribution()
	return true


## 移除动作执行拦截器。
## [br]
## @api public
## [br]
## @param interceptor: 拦截器实例。
## [br]
## @return 移除成功返回 true。
func remove_interceptor(interceptor: GFActionInterceptor) -> bool:
	if interceptor == null or not _interceptors.has(interceptor):
		return false
	_interceptors.erase(interceptor)
	_publish_diagnostics_contribution()
	return true


## 批量替换动作执行拦截器。
## [br]
## @api public
## [br]
## @param interceptors: 新拦截器列表。
func set_interceptors(interceptors: Array[GFActionInterceptor]) -> void:
	_interceptors.clear()
	for interceptor: GFActionInterceptor in interceptors:
		var _interceptor_added: bool = add_interceptor(interceptor)


## 清空动作执行拦截器。
## [br]
## @api public
func clear_interceptors() -> void:
	_interceptors.clear()
	_publish_diagnostics_contribution()


## 获取动作执行拦截器副本。
## [br]
## @api public
## [br]
## @return 拦截器列表副本。
func get_interceptors() -> Array[GFActionInterceptor]:
	var result: Array[GFActionInterceptor] = []
	result.assign(_interceptors)
	return result


## 将动作加入指定命名队列。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param action: 要处理的动作对象。
func enqueue_to(queue_name: StringName, action: Object) -> void:
	var queue: GFActionQueueSystem = get_named_queue(queue_name)
	if queue != null:
		queue.enqueue(action)


## 将动作以 fire-and-forget 模式加入指定命名队列。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param action: 要处理的动作对象。
func enqueue_fire_and_forget_to(queue_name: StringName, action: Object) -> void:
	var queue: GFActionQueueSystem = get_named_queue(queue_name)
	if queue != null:
		queue.enqueue_fire_and_forget(action)


## 将一批动作加入指定命名队列并行执行。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param actions: 要处理的动作对象列表。
## [br]
## @schema actions: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。
func enqueue_parallel_to(queue_name: StringName, actions: Array) -> void:
	var queue: GFActionQueueSystem = get_named_queue(queue_name)
	if queue != null:
		queue.enqueue_parallel(actions)


## 将动作插入指定命名队列头部。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param action: 要处理的动作对象。
func push_front_to(queue_name: StringName, action: Object) -> void:
	var queue: GFActionQueueSystem = get_named_queue(queue_name)
	if queue != null:
		queue.push_front(action)


## 清理指定命名队列。
## [br]
## @api public
## [br]
## @param queue_name: 动作队列名称。
## [br]
## @param stop_current: 是否停止当前正在执行的动作。
func clear_named_queue(queue_name: StringName, stop_current: bool = false) -> void:
	var queue: GFActionQueueSystem = _get_named_queue_value(queue_name)
	if queue != null:
		queue.clear_queue(stop_current)


## 清理所有命名队列。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param stop_current: 兼容参数；命名队列由父队列拥有，清理时总会释放子队列并停止其当前动作。
func clear_all_named_queues(stop_current: bool = false) -> void:
	var _stop_current_value: bool = stop_current
	_dispose_all_named_queues()
	_publish_diagnostics_contribution()


## 跳过当前动作并继续消费后续动作。
## [br]
## @api public
func skip_current_action() -> void:
	if _is_disposed:
		return
	_processing_serial += 1
	_set_paused(false)
	_cancel_current_action()
	is_processing = false
	_try_start_processing()


## 暂停当前动作。
## [br]
## @api public
## [br]
## @return 存在当前动作时返回 true。
func pause_current_action() -> bool:
	if not is_instance_valid(_current_action):
		return false
	_set_paused(true)
	_ACTION_PROTOCOL.pause(_current_action)
	return true


## 恢复当前动作。
## [br]
## @api public
## [br]
## @return 存在当前动作时返回 true。
func resume_current_action() -> bool:
	if not is_instance_valid(_current_action):
		return false
	_ACTION_PROTOCOL.resume(_current_action)
	_set_paused(false)
	return true


## 将当前动作标记为立即完成并继续消费后续动作。
## [br]
## @api public
func finish_current_action() -> void:
	_processing_serial += 1
	_set_paused(false)
	if is_instance_valid(_current_action):
		_ACTION_PROTOCOL.finish(_current_action)
	_current_action = null
	is_processing = false
	_try_start_processing()


## 获取当前正在执行或等待的动作。
## [br]
## @api public
## [br]
## @return 当前动作；没有动作时返回 null。
func get_current_action() -> Object:
	return _current_action if is_instance_valid(_current_action) else null


## 获取动作队列诊断快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 诊断快照字典。
## [br]
## @schema return: Dictionary，包含 is_processing、is_paused、queued_count、has_current_action、processing_serial、max_immediate_actions_per_slice、named_queue_count、named_queue_snapshot_count、named_queues_truncated、named_queues、linked_node_alive 和 interceptor_count。
func get_debug_snapshot() -> Dictionary:
	return _build_debug_snapshot(_DEBUG_SNAPSHOT_MAX_DEPTH)


## 驱动命名队列的生命周期清理。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func tick(_delta: float) -> void:
	if _linked_node_ref != null and _linked_node_ref.get_ref() == null:
		clear_queue(true)
	for queue_name: StringName in _named_queues.keys():
		var queue: GFActionQueueSystem = _get_named_queue_value(queue_name)
		if queue == null:
			var _queue_erased: bool = _named_queues.erase(queue_name)
			continue
		queue.tick(_delta)


# --- 私有/辅助方法 ---

func _build_debug_snapshot(remaining_depth: int) -> Dictionary:
	var named_snapshots: Dictionary = {}
	var queue_names: Array[StringName] = []
	for queue_name_value: Variant in _named_queues.keys():
		queue_names.append(GFVariantData.to_string_name(queue_name_value))
	queue_names.sort()
	var named_queues_truncated: bool = remaining_depth <= 0 and not queue_names.is_empty()
	var snapshot_count: int = mini(queue_names.size(), max_debug_named_queue_entries)
	if snapshot_count < queue_names.size():
		named_queues_truncated = true
	if remaining_depth > 0:
		for index: int in snapshot_count:
			var queue_name: StringName = queue_names[index]
			var queue: GFActionQueueSystem = _get_named_queue_value(queue_name)
			if queue != null:
				named_snapshots[queue_name] = queue._build_debug_snapshot(remaining_depth - 1)

	return {
		"is_processing": is_processing,
		"is_paused": _is_paused,
		"queued_count": maxi(_queue.size() - _queue_head_index, 0),
		"has_current_action": is_instance_valid(_current_action),
		"processing_serial": _processing_serial,
		"max_immediate_actions_per_slice": max_immediate_actions_per_slice,
		"named_queue_count": _named_queues.size(),
		"named_queue_snapshot_count": named_snapshots.size(),
		"named_queues_truncated": named_queues_truncated,
		"named_queues": named_snapshots,
		"linked_node_alive": _linked_node_ref != null and _linked_node_ref.get_ref() != null,
		"interceptor_count": _interceptors.size(),
	}

func _try_start_processing() -> void:
	if _is_disposed:
		return
	if not is_processing:
		_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_process_queue"))
	_publish_diagnostics_contribution()


func _process_queue() -> void:
	if _is_disposed:
		return
	if not _has_queued_actions():
		return

	is_processing = true
	var current_serial: int = _processing_serial
	var immediate_action_count: int = 0

	while not _is_disposed and current_serial == _processing_serial and _has_queued_actions():
		if immediate_action_count >= max_immediate_actions_per_slice:
			var resumed: bool = await _wait_for_next_processing_slice(current_serial)
			if not resumed:
				if current_serial == _processing_serial:
					is_processing = false
				return
			immediate_action_count = 0
		await _wait_until_resumed(current_serial)
		if _is_disposed or current_serial != _processing_serial:
			return

		var action: Object = _dequeue_action()
		immediate_action_count += 1
		if not _ACTION_PROTOCOL.is_action_valid(action):
			continue

		_inject_action_dependencies(action)
		if _is_disposed or current_serial != _processing_serial:
			return
		var before_result: GFActionInterceptionResult = _apply_before_interceptors(action)
		if _is_disposed or current_serial != _processing_serial:
			return
		if before_result.is_stop_queue():
			_stop_processing_from_interceptor(false)
			return
		if before_result.is_skip():
			continue
		if before_result.is_replace():
			action = before_result.replacement_action
			_inject_action_dependencies(action)
			if _is_disposed or current_serial != _processing_serial:
				return
		if not is_instance_valid(action):
			continue

		_current_action = action
		_publish_diagnostics_contribution()
		var can_execute: bool = _ACTION_PROTOCOL.can_execute(action)
		if _is_disposed or current_serial != _processing_serial:
			return
		if not can_execute:
			_current_action = null
			continue

		var result: Variant = _ACTION_PROTOCOL.execute(action)
		if _is_disposed or current_serial != _processing_serial:
			return
		var should_wait: bool = _ACTION_PROTOCOL.should_wait_for_result(action, result)
		if should_wait:
			await _ACTION_PROTOCOL.await_result_safely(
				action,
				result,
				_is_processing_serial_current.bind(current_serial),
				_is_wait_timeout_paused.bind(current_serial),
				_get_architecture_or_null()
			)
			immediate_action_count = 0

		if _is_disposed or current_serial != _processing_serial:
			return
		await _wait_until_resumed(current_serial)
		if _is_disposed or current_serial != _processing_serial:
			return
		var after_result: GFActionInterceptionResult = _apply_after_interceptors(action, result)
		if _is_disposed or current_serial != _processing_serial:
			return
		if after_result.is_stop_queue():
			_stop_processing_from_interceptor(false)
			return
		if _current_action == action:
			_current_action = null
		_publish_diagnostics_contribution()

	_current_action = null
	_set_paused(false)
	is_processing = false
	_publish_diagnostics_contribution()
	queue_drained.emit()


func _has_queued_actions() -> bool:
	return _queue_head_index < _queue.size()


func _dequeue_action() -> Object:
	var action: Object = _variant_to_action(_queue[_queue_head_index])
	_queue[_queue_head_index] = null
	_queue_head_index += 1
	_compact_queue_if_needed()
	_publish_diagnostics_contribution()
	return action


func _push_front_action(action: Object) -> void:
	if _queue_head_index > 0:
		_queue_head_index -= 1
		_queue[_queue_head_index] = action
	else:
		var _insert_result: int = _queue.insert(0, action)


func _compact_queue_if_needed() -> void:
	if _queue_head_index < 64 or _queue_head_index * 2 < _queue.size():
		return

	_queue = _queue.slice(_queue_head_index)
	_queue_head_index = 0


func _inject_action_dependencies(action: Object) -> void:
	_ACTION_PROTOCOL.inject_dependencies(action, _get_architecture_or_null())


func _inject_interceptor_dependencies(interceptor: GFActionInterceptor) -> void:
	if interceptor != null and interceptor.has_method("inject_dependencies"):
		interceptor.call("inject_dependencies", _get_architecture_or_null())


func _sort_interceptors() -> void:
	_interceptors.sort_custom(func(left: GFActionInterceptor, right: GFActionInterceptor) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return left.priority > right.priority
	)


func _apply_before_interceptors(action: Object) -> GFActionInterceptionResult:
	var current_action: Object = action
	for interceptor: GFActionInterceptor in _get_enabled_interceptors():
		var result: GFActionInterceptionResult = interceptor._before_execute(current_action, self)
		result = _normalize_interception_result(result)
		if result.is_replace():
			current_action = result.replacement_action
			_inject_action_dependencies(current_action)
			continue
		if not result.is_continue():
			return result
	return GFActionInterceptionResult.replace_with(current_action) if current_action != action else GFActionInterceptionResult.continue_action()


func _apply_after_interceptors(
	action: Object,
	execute_result: Variant
) -> GFActionInterceptionResult:
	for interceptor: GFActionInterceptor in _get_enabled_interceptors():
		var result: GFActionInterceptionResult = _normalize_interception_result(interceptor._after_execute(action, self, execute_result))
		if result.is_stop_queue():
			return result
	return GFActionInterceptionResult.continue_action()


func _get_enabled_interceptors() -> Array[GFActionInterceptor]:
	var result: Array[GFActionInterceptor] = []
	for interceptor: GFActionInterceptor in _interceptors:
		if interceptor != null and interceptor.enabled:
			result.append(interceptor)
	return result


func _normalize_interception_result(result: GFActionInterceptionResult) -> GFActionInterceptionResult:
	if result == null:
		return GFActionInterceptionResult.continue_action()
	return result


func _is_processing_serial_current(serial: int) -> bool:
	return serial == _processing_serial


func _is_wait_timeout_paused(serial: int) -> bool:
	return serial == _processing_serial and _is_paused


func _wait_until_resumed(serial: int) -> void:
	while serial == _processing_serial and _is_paused:
		await _pause_state_changed


func _wait_for_next_processing_slice(serial: int) -> bool:
	var main_loop: Variant = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return false
	var tree: SceneTree = main_loop
	await tree.process_frame
	return not _is_disposed and serial == _processing_serial


func _set_paused(paused: bool) -> void:
	if _is_paused == paused:
		return
	_is_paused = paused
	_publish_diagnostics_contribution()
	_pause_state_changed.emit()


func _cancel_current_action() -> void:
	if is_instance_valid(_current_action):
		_ACTION_PROTOCOL.cancel(_current_action)
	_current_action = null
	_publish_diagnostics_contribution()


func _dispose_all_named_queues() -> void:
	var queues: Array = _named_queues.values()
	_named_queues.clear()
	for queue_value: Variant in queues:
		var queue: GFActionQueueSystem = _variant_to_action_queue(queue_value)
		if queue == null:
			continue
		queue.dispose()
		queue._release_dependency_scope()


func _get_named_queue_value(queue_name: StringName) -> GFActionQueueSystem:
	return _variant_to_action_queue(GFVariantData.get_option_value(_named_queues, queue_name))


func _variant_to_action_queue(value: Variant) -> GFActionQueueSystem:
	if value is GFActionQueueSystem:
		var queue: GFActionQueueSystem = value
		return queue
	return null


func _variant_to_action(value: Variant) -> Object:
	if value is Object:
		var action: Object = value
		return action
	return null


func _get_diagnostics_utility() -> GFDiagnosticsUtility:
	var utility: Object = get_utility(GFDiagnosticsUtility)
	if utility is GFDiagnosticsUtility:
		var diagnostics: GFDiagnosticsUtility = utility
		return diagnostics
	return null


func _register_diagnostics_contribution() -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility()
	if diagnostics == null:
		return

	var _monitor_registered: bool = diagnostics.register_monitor(self, &"tools.action_queue", {
		"label": "Action Queue",
		"group": "Tools",
	})
	var _preset_updated: bool = diagnostics.add_monitor_to_preset(&"tools", &"tools.action_queue")
	_publish_diagnostics_contribution()


func _unregister_diagnostics_contribution() -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility()
	if diagnostics == null:
		return

	var _snapshot_removed: bool = diagnostics.remove_tool_snapshot(self, &"action_queue")
	var _monitor_unregistered: bool = diagnostics.unregister_monitor(self, &"tools.action_queue")


func _publish_diagnostics_contribution() -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility()
	if diagnostics == null:
		return
	var snapshot: Dictionary = get_debug_snapshot()
	var _tool_snapshot_published: bool = diagnostics.publish_tool_snapshot(self, &"action_queue", snapshot)
	var _monitor_sample_published: bool = diagnostics.publish_monitor_sample(
		self,
		&"tools.action_queue",
		snapshot
	)


func _stop_processing_from_interceptor(cancel_current: bool) -> void:
	var was_processing: bool = is_processing
	_processing_serial += 1
	_queue.clear()
	_queue_head_index = 0
	_set_paused(false)
	if cancel_current:
		_cancel_current_action()
	else:
		_current_action = null
	is_processing = false
	if was_processing:
		queue_drained.emit()


func _disconnect_linked_node() -> void:
	if is_instance_valid(_linked_node) and _linked_node.tree_exited.is_connected(_on_linked_node_tree_exited):
		_linked_node.tree_exited.disconnect(_on_linked_node_tree_exited)
	_linked_node = null


# --- 信号处理函数 ---

func _on_linked_node_tree_exited() -> void:
	_linked_node_ref = null
	_linked_node = null
	clear_queue(true)
