## GFStateMachine: 纯代码分层有限状态机。
##
## 继承自 RefCounted，不依赖 Node 树，可在 GFSystem 或 GFUtility 中直接持有。
## 支持平铺 FSM，也支持通过 parent_state_name 组成父子状态层级；切换时会
## 按最近公共祖先执行退出/进入链，并允许事件从当前叶子状态向父状态上抛。
## context 通常是拥有它的 GFSystem/GFUtility 实例，仅用于生命周期守卫；
## 未传入 context 时，状态机仍可通过全局 Gf 访问框架依赖。
##
## 使用示例：
##   var _fsm := GFStateMachine.new(self)
##   _fsm.add_state(&"Grounded", GroundedState.new())
##   _fsm.add_state(&"Idle", IdleState.new(), &"Grounded")
##   _fsm.add_state(&"Run", RunState.new(), &"Grounded")
##   _fsm.start(&"Idle")
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFStateMachine
extends RefCounted


# --- 信号 ---

## 当状态成功切换后发出。
## [br]
## @api public
## [br]
## @param from_state: 离开的叶子状态名，初始切换时为空字符串。
## [br]
## @param to_state: 进入的新叶子状态名。
signal state_changed(from_state: StringName, to_state: StringName)

## 当状态守卫阻止切换时发出。
## [br]
## @api public
## [br]
## @param from_state: 当前叶子状态名。
## [br]
## @param to_state: 请求进入的目标叶子状态名。
## [br]
## @param msg: 状态切换参数。
## [br]
## @param reason: 阻止原因，常见为 exit_guard 或 enter_guard。
## [br]
## @schema msg: Dictionary state transition payload.
signal transition_blocked(from_state: StringName, to_state: StringName, msg: Dictionary, reason: StringName)

## 当状态事件被某个激活状态处理后发出。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param handler_state: 处理该事件的状态名。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: Variant state event payload.
signal state_event_handled(event_id: StringName, handler_state: StringName, payload: Variant)


# --- 公共变量 ---

## 当前激活的叶子状态注册名。
## [br]
## @api public
var current_state_name: StringName = &""

## 状态机共享黑板。框架不解释其中字段。
## [br]
## @api public
## [br]
## @schema blackboard: Dictionary shared state machine data.
var blackboard: Dictionary = {}


# --- 私有变量 ---

# 已注册的所有状态，Key 为 StringName，Value 为 GFState 实例。
var _states: Dictionary = {}

# 状态父级索引，Key 为子状态名，Value 为父状态名。
var _state_parents: Dictionary = {}

# 当前激活状态路径，按 root -> leaf 排列。
var _active_path: Array[StringName] = []

# 当前激活的叶子状态实例。
var _current_state: GFState = null

# 用于守卫框架依赖访问的上下文对象弱引用。
# 使用弱引用避免 RefCounted 环状引用。
var _context_ref: WeakRef = null
var _event_architecture_refs: Array[WeakRef] = []
var _transition_serial: int = 0
var _is_exiting_current_state: bool = false
var _has_queued_exit_transition: bool = false
var _queued_exit_state_name: StringName = &""
var _queued_exit_msg: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建状态机并注入框架上下文。
## [br]
## @api public
## [br]
## @param context: 可选上下文对象，用于守卫 get_model/get_system/get_utility 调用。
func _init(context: Object = null) -> void:
	_context_ref = weakref(context) if context != null else null


# --- 公共方法 ---

## 注册一个状态。注册后，状态机会自动注入自身引用。
## [br]
## @api public
## [br]
## @param state_name: 用于标识和切换该状态的唯一名称。
## [br]
## @param state: GFState 实例。
## [br]
## @param parent_state_name: 可选父状态名；为空表示根状态。
func add_state(state_name: StringName, state: GFState, parent_state_name: StringName = &"") -> void:
	if state_name == &"":
		push_warning("[GFStateMachine] 注册状态失败，state_name 为空。")
		return
	if state == null:
		push_warning("[GFStateMachine] 注册状态失败，state 为空：%s" % state_name)
		return

	var normalized_parent: StringName = _normalize_parent_state_name(state_name, parent_state_name)
	var old_state: GFState = _get_registered_state(state_name)
	var is_replacing_current: bool = old_state != null and old_state == _current_state and old_state != state
	var is_replacing_active_ancestor: bool = (
		old_state != null
		and old_state != state
		and _active_path.has(state_name)
		and not is_replacing_current
	)

	if is_replacing_active_ancestor:
		stop()
	elif is_replacing_current:
		old_state.exit()

	if old_state != null and old_state != state:
		old_state.dispose()

	state.setup(self, state_name)
	_states[state_name] = state
	_set_parent_state_name(state_name, normalized_parent)

	if is_replacing_current:
		_active_path = _build_state_path(state_name)
		_set_current_from_active_path()
		state.enter()


## 设置已注册状态的父状态。
## [br]
## @api public
## [br]
## @param state_name: 要调整父级的状态名。
## [br]
## @param parent_state_name: 新父状态名；为空表示根状态。
## [br]
## @return 设置成功返回 true。
func set_state_parent(state_name: StringName, parent_state_name: StringName = &"") -> bool:
	if not _states.has(state_name):
		push_warning("[GFStateMachine] 设置父状态失败，未找到状态：%s" % state_name)
		return false

	var normalized_parent: StringName = _normalize_parent_state_name(state_name, parent_state_name)
	if normalized_parent != parent_state_name:
		return false

	_set_parent_state_name(state_name, normalized_parent)
	if _active_path.has(state_name):
		_active_path = _build_state_path(current_state_name)
	return true


## 启动状态机并进入初始状态。
## [br]
## @api public
## [br]
## @param initial_state_name: 首个要进入的状态名。
## [br]
## @param msg: 传递给初始状态 enter() 的可选参数字典。
## [br]
## @param emit_changed: 是否发出 state_changed 信号；默认为 true，from_state 为空字符串。
## [br]
## @schema msg: Dictionary state transition payload.
func start(initial_state_name: StringName, msg: Dictionary = {}, emit_changed: bool = true) -> void:
	if not _states.has(initial_state_name):
		push_warning("[GFStateMachine] 启动失败，未找到状态：%s" % initial_state_name)
		return

	_clear_queued_exit_transition()
	_transition_to_state(initial_state_name, msg, emit_changed)


## 切换到指定状态。分层状态会按最近公共祖先执行退出/进入链。
## [br]
## @api public
## [br]
## @param state_name: 目标状态的注册名。
## [br]
## @param msg: 传递给目标状态 enter() 的可选参数字典。
## [br]
## @schema msg: Dictionary state transition payload.
func change_state(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_warning("[GFStateMachine] 切换失败，未找到状态：%s" % state_name)
		return

	if _is_exiting_current_state:
		_transition_serial += 1
		_queue_exit_transition(state_name, msg)
		return

	_transition_to_state(state_name, msg, true)


## 驱动当前状态的 update() 逻辑，应在宿主的 _process() 中调用。
## [br]
## @api public
## [br]
## @param delta: 上一帧的时间间隔（秒）。
## [br]
## @param include_ancestors: 为 true 时按 root -> leaf 顺序更新整条激活路径。
func update(delta: float, include_ancestors: bool = false) -> void:
	if include_ancestors:
		for state_name: StringName in _active_path:
			var state: GFState = _get_registered_state(state_name)
			if state != null:
				state.update(delta)
		return

	if _current_state != null:
		_current_state.update(delta)


## 从当前叶子状态开始向父状态上抛事件，直到某个状态返回 true。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @return 有状态处理该事件时返回 true。
## [br]
## @schema payload: Variant state event payload.
func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:
	for index: int in range(_active_path.size() - 1, -1, -1):
		var state_name: StringName = _active_path[index]
		var state: GFState = _get_registered_state(state_name)
		if state != null and state.handle_state_event(event_id, payload):
			state_event_handled.emit(event_id, state_name, payload)
			return true
	return false


## 停止状态机，按 leaf -> root 顺序调用当前激活路径的 exit() 并清空状态。
## [br]
## @api public
func stop() -> void:
	var _exit_finished: bool = _exit_active_path_to(0, false)
	_active_path.clear()
	_set_current_from_active_path()
	_clear_queued_exit_transition()


## 释放状态机持有的所有引用，避免 RefCounted 环状引用。
## [br]
## @api public
func dispose() -> void:
	stop()

	for state_name: StringName in _states.keys():
		var state: GFState = _get_registered_state(state_name)
		if state != null:
			state.dispose()

	_states.clear()
	_state_parents.clear()
	blackboard.clear()
	_event_architecture_refs.clear()
	_context_ref = null


## 获取状态实例。
## [br]
## @api public
## [br]
## @param state_name: 要查询的状态名。
## [br]
## @return 已注册状态实例；不存在时返回 null。
func get_state(state_name: StringName) -> GFState:
	return _get_registered_state(state_name)


## 获取当前叶子状态实例。
## [br]
## @api public
## [br]
## @return 当前叶子状态；未启动时返回 null。
func get_current_state() -> GFState:
	return _current_state


## 判断状态是否已注册。
## [br]
## @api public
## [br]
## @param state_name: 要查询的状态名。
## [br]
## @return 已注册返回 true。
func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


## 获取已注册状态名列表。
## [br]
## @api public
## [br]
## @return 状态名列表副本。
func get_state_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for state_name: StringName in _states.keys():
		result.append(state_name)
	return result


## 获取指定状态的父状态名。
## [br]
## @api public
## [br]
## @param state_name: 要查询的状态名。
## [br]
## @return 父状态名；没有父级或状态不存在时返回空 StringName。
func get_parent_state_name(state_name: StringName) -> StringName:
	return _get_parent_state_name(state_name)


## 获取当前激活状态路径，按 root -> leaf 排列。
## [br]
## @api public
## [br]
## @return 激活状态路径副本。
func get_active_state_path() -> Array[StringName]:
	return _copy_path(_active_path)


## 判断指定状态是否在当前激活路径中。
## [br]
## @api public
## [br]
## @param state_name: 要查询的状态名。
## [br]
## @return 处于当前激活路径中返回 true。
func is_in_state(state_name: StringName) -> bool:
	return _active_path.has(state_name)


## 获取共享黑板。
## [br]
## @api public
## [br]
## @return 状态机黑板字典。
## [br]
## @schema return: Dictionary shared blackboard.
func get_blackboard() -> Dictionary:
	return blackboard


## 获取状态机调试快照。
## [br]
## @api public
## [br]
## @return 包含当前状态、激活路径、父子关系和黑板副本的字典。
## [br]
## @schema return: Dictionary with current_state, active_path, states, parents, and blackboard.
func get_state_snapshot() -> Dictionary:
	return {
		"current_state": current_state_name,
		"active_path": get_active_state_path(),
		"states": get_state_names(),
		"parents": _state_parents.duplicate(true),
		"blackboard": blackboard.duplicate(true),
	}


## 代理获取框架内的 Model 实例。
## [br]
## @api public
## [br]
## @param model_type: 模型的脚本类型。
## [br]
## @return 模型实例，若上下文或架构无效则返回 null。
func get_model(model_type: Script) -> Object:
	var architecture: GFArchitecture = _get_available_architecture("Model")
	if architecture == null:
		return null
	return architecture.get_model(model_type)


## 代理获取框架内的 System 实例。
## [br]
## @api public
## [br]
## @param system_type: 系统的脚本类型。
## [br]
## @return 系统实例，若上下文或架构无效则返回 null。
func get_system(system_type: Script) -> Object:
	var architecture: GFArchitecture = _get_available_architecture("System")
	if architecture == null:
		return null
	return architecture.get_system(system_type)


## 代理获取框架内的 Utility 实例。
## [br]
## @api public
## [br]
## @param utility_type: 工具的脚本类型。
## [br]
## @return 工具实例，若上下文或架构无效则返回 null。
func get_utility(utility_type: Script) -> Object:
	var architecture: GFArchitecture = _get_available_architecture("Utility")
	if architecture == null:
		return null
	return architecture.get_utility(utility_type)


## 代理向框架发送命令。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return 命令执行结果；上下文或架构无效时返回 null。
## [br]
## @schema return: Variant command result, Signal, or null.
func send_command(command: Object) -> Variant:
	var architecture: GFArchitecture = _get_available_architecture("Command")
	if architecture == null:
		return null
	return architecture.send_command(command)


## 代理向框架发送查询。
## [br]
## @api public
## [br]
## @param query: 要发送的查询实例。
## [br]
## @return 查询结果；上下文或架构无效时返回 null。
## [br]
## @schema return: Variant query result or null.
func send_query(query: Object) -> Variant:
	var architecture: GFArchitecture = _get_available_architecture("Query")
	if architecture == null:
		return null
	return architecture.send_query(query)


## 代理发送类型事件。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var architecture: GFArchitecture = _get_available_architecture("Event")
	if architecture != null:
		architecture.send_event(event_instance)


## 代理发送轻量级 StringName 事件。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: Variant event payload.
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var architecture: GFArchitecture = _get_available_architecture("Event")
	if architecture != null:
		architecture.send_simple_event(event_id, payload)


## 注册带拥有者的类型事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param callback: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event_owned(owner: Object, event_type: Script, callback: Callable, priority: int = 0) -> void:
	var architecture: GFArchitecture = _get_available_architecture("Event")
	if architecture != null:
		architecture.register_event_owned(owner, event_type, callback, priority)
		_remember_event_architecture(architecture)


## 注销类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param callback: 要移除的回调函数。
## [br]
## @param owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_event(event_type: Script, callback: Callable, owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if owner != null:
			architecture.unregister_event_owned(owner, event_type, callback)
		else:
			architecture.unregister_event(event_type, callback)


## 注册带拥有者的可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param callback: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event_owned(
	owner: Object,
	base_event_type: Script,
	callback: Callable,
	priority: int = 0
) -> void:
	var architecture: GFArchitecture = _get_available_architecture("Event")
	if architecture != null:
		architecture.register_assignable_event_owned(owner, base_event_type, callback, priority)
		_remember_event_architecture(architecture)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param callback: 要移除的回调函数。
## [br]
## @param owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_assignable_event(base_event_type: Script, callback: Callable, owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if owner != null:
			architecture.unregister_assignable_event_owned(owner, base_event_type, callback)
		else:
			architecture.unregister_assignable_event(base_event_type, callback)


## 注册带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param callback: 回调函数，签名为 func(payload: Variant)。
func register_simple_event_owned(owner: Object, event_id: StringName, callback: Callable) -> void:
	var architecture: GFArchitecture = _get_available_architecture("Event")
	if architecture != null:
		architecture.register_simple_event_owned(owner, event_id, callback)
		_remember_event_architecture(architecture)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param callback: 要移除的回调函数。
## [br]
## @param owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_simple_event(event_id: StringName, callback: Callable, owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if owner != null:
			architecture.unregister_simple_event_owned(owner, event_id, callback)
		else:
			architecture.unregister_simple_event(event_id, callback)


## 注销指定拥有者通过状态机事件代理注册过的全部监听器。
## [br]
## @api public
## [br]
## @param owner: 要清理监听器的拥有者。
func unregister_owner_events(owner: Object) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_owner_events(owner)


# --- 私有/辅助方法 ---

func _transition_to_state(state_name: StringName, msg: Dictionary, emit_changed: bool) -> void:
	var target_path: Array[StringName] = _build_state_path(state_name)
	if target_path.is_empty():
		return

	var common_count: int = _get_common_prefix_count(_active_path, target_path)
	if _paths_equal(_active_path, target_path) and common_count > 0:
		common_count -= 1

	var block_reason: StringName = _get_transition_block_reason(target_path, common_count, msg)
	if block_reason != &"":
		transition_blocked.emit(current_state_name, state_name, msg.duplicate(true), block_reason)
		return

	_transition_serial += 1
	var current_serial: int = _transition_serial
	var from_name: StringName = current_state_name

	if not _exit_active_path_to(common_count):
		return

	for index: int in range(common_count, target_path.size()):
		var entering_state_name: StringName = target_path[index]
		var entering_state: GFState = _get_registered_state(entering_state_name)
		if entering_state == null:
			return

		_active_path.append(entering_state_name)
		_set_current_from_active_path()
		entering_state.enter(msg)
		if current_serial != _transition_serial or current_state_name != entering_state_name:
			return

	if emit_changed and current_serial == _transition_serial and current_state_name == state_name:
		state_changed.emit(from_name, state_name)


func _exit_active_path_to(
	common_count: int,
	process_queued_transition: bool = true
) -> bool:
	if _active_path.size() <= common_count:
		return true

	_is_exiting_current_state = true
	var keep_count: int = common_count
	for index: int in range(_active_path.size() - 1, common_count - 1, -1):
		var exiting_state_name: StringName = _active_path[index]
		var exiting_state: GFState = _get_registered_state(exiting_state_name)
		if exiting_state != null:
			exiting_state.exit()
			exiting_state.unregister_owner_events()
		if _has_queued_exit_transition:
			keep_count = index
			break
	_is_exiting_current_state = false

	_active_path = _copy_path_prefix(_active_path, keep_count)
	_set_current_from_active_path()

	if not _has_queued_exit_transition:
		return true
	if not process_queued_transition:
		_clear_queued_exit_transition()
		return true

	var queued_transition: _QueuedExitTransition = _take_queued_exit_transition(&"", {})
	var queued_state_name: StringName = queued_transition._state_name
	var queued_msg: Dictionary = queued_transition._msg
	_transition_to_state(queued_state_name, queued_msg, true)
	return false


func _get_transition_block_reason(
	target_path: Array[StringName],
	common_count: int,
	msg: Dictionary
) -> StringName:
	var target_state_name: StringName = target_path[target_path.size() - 1]
	for index: int in range(_active_path.size() - 1, common_count - 1, -1):
		var active_state: GFState = _get_registered_state(_active_path[index])
		if active_state != null and not active_state.can_exit(target_state_name, msg):
			return &"exit_guard"

	var previous_state_name: StringName = current_state_name
	for index: int in range(common_count, target_path.size()):
		var target_state: GFState = _get_registered_state(target_path[index])
		if target_state != null and not target_state.can_enter(previous_state_name, msg):
			return &"enter_guard"

	return &""


func _normalize_parent_state_name(state_name: StringName, parent_state_name: StringName) -> StringName:
	if parent_state_name == &"":
		return &""
	if parent_state_name == state_name:
		push_error("[GFStateMachine] 父状态不能指向自身：%s" % state_name)
		return &""
	if not _states.has(parent_state_name):
		push_warning("[GFStateMachine] 父状态尚未注册，已按根状态注册：%s -> %s" % [state_name, parent_state_name])
		return &""
	if _creates_parent_cycle(state_name, parent_state_name):
		push_error("[GFStateMachine] 检测到循环状态父级：%s -> %s" % [state_name, parent_state_name])
		return &""
	return parent_state_name


func _set_parent_state_name(state_name: StringName, parent_state_name: StringName) -> void:
	if parent_state_name == &"":
		var _erased_parent: bool = _state_parents.erase(state_name)
	else:
		_state_parents[state_name] = parent_state_name


func _creates_parent_cycle(state_name: StringName, parent_state_name: StringName) -> bool:
	var current_name: StringName = parent_state_name
	var visited: Dictionary = {}
	while current_name != &"":
		if current_name == state_name:
			return true
		if visited.has(current_name):
			return true
		visited[current_name] = true
		current_name = _get_parent_state_name(current_name)
	return false


func _build_state_path(state_name: StringName) -> Array[StringName]:
	var reversed_path: Array[StringName] = []
	var current_name: StringName = state_name
	var visited: Dictionary = {}
	while current_name != &"":
		if visited.has(current_name):
			push_error("[GFStateMachine] 检测到循环状态父级，无法构建状态路径：%s" % state_name)
			reversed_path.clear()
			return reversed_path
		if not _states.has(current_name):
			push_warning("[GFStateMachine] 状态路径包含未注册状态：%s" % current_name)
			reversed_path.clear()
			return reversed_path

		reversed_path.append(current_name)
		visited[current_name] = true
		current_name = _get_parent_state_name(current_name)

	var result: Array[StringName] = []
	for index: int in range(reversed_path.size() - 1, -1, -1):
		result.append(reversed_path[index])
	return result


func _get_common_prefix_count(left: Array[StringName], right: Array[StringName]) -> int:
	var count: int = mini(left.size(), right.size())
	for index: int in range(count):
		if left[index] != right[index]:
			return index
	return count


func _paths_equal(left: Array[StringName], right: Array[StringName]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


func _copy_path(path: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for state_name: StringName in path:
		result.append(state_name)
	return result


func _copy_path_prefix(path: Array[StringName], count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var safe_count: int = clampi(count, 0, path.size())
	for index: int in range(safe_count):
		result.append(path[index])
	return result


func _set_current_from_active_path() -> void:
	if _active_path.is_empty():
		_current_state = null
		current_state_name = &""
		return

	current_state_name = _active_path[_active_path.size() - 1]
	_current_state = _get_registered_state(current_state_name)


func _remember_event_architecture(architecture: GFArchitecture) -> void:
	if architecture == null or not is_instance_valid(architecture):
		return

	for architecture_ref: WeakRef in _event_architecture_refs:
		if architecture_ref.get_ref() == architecture:
			return

	_event_architecture_refs.append(weakref(architecture))


func _get_tracked_event_architectures() -> Array[GFArchitecture]:
	var result: Array[GFArchitecture] = []
	var live_refs: Array[WeakRef] = []
	for architecture_ref: WeakRef in _event_architecture_refs:
		var architecture: GFArchitecture = _variant_to_architecture(architecture_ref.get_ref())
		if architecture != null and is_instance_valid(architecture):
			result.append(architecture)
			live_refs.append(architecture_ref)

	_event_architecture_refs = live_refs
	return result


func _get_context() -> Object:
	if _context_ref == null:
		return null
	return _context_ref.get_ref()


func _get_available_architecture(dependency_name: String) -> GFArchitecture:
	var context: Object = _get_context()
	if _context_ref != null and not is_instance_valid(context):
		push_error("[GFStateMachine] 上下文无效，无法获取 %s。" % dependency_name)
		return null

	if context != null:
		var context_architecture: GFArchitecture = _get_context_architecture(context)
		if context_architecture != null:
			return context_architecture

	var global_architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if global_architecture == null:
		push_error("[GFStateMachine] 架构尚未初始化，无法获取 %s。" % dependency_name)
		return null

	return global_architecture


func _get_context_architecture(context: Object) -> GFArchitecture:
	var method_names: Array[StringName] = [
		&"get_architecture_or_null",
		&"_get_architecture_or_null",
		&"get_architecture",
	]
	for method_name: StringName in method_names:
		var architecture: GFArchitecture = _call_context_architecture_method(context, method_name)
		if architecture != null:
			return architecture
	return null


func _get_registered_state(state_name: StringName) -> GFState:
	var state_value: Variant = GFVariantData.get_option_value(_states, state_name)
	if state_value is GFState:
		return state_value
	return null


func _get_parent_state_name(state_name: StringName) -> StringName:
	return GFVariantData.get_option_string_name(_state_parents, state_name)


func _queue_exit_transition(state_name: StringName, msg: Dictionary) -> void:
	_has_queued_exit_transition = true
	_queued_exit_state_name = state_name
	_queued_exit_msg = msg


func _clear_queued_exit_transition() -> void:
	_has_queued_exit_transition = false
	_queued_exit_state_name = &""
	_queued_exit_msg = {}


func _take_queued_exit_transition(default_state_name: StringName, default_msg: Dictionary) -> _QueuedExitTransition:
	if not _has_queued_exit_transition:
		return _QueuedExitTransition.new(default_state_name, default_msg)

	var result: _QueuedExitTransition = _QueuedExitTransition.new(_queued_exit_state_name, _queued_exit_msg)
	_clear_queued_exit_transition()
	return result


func _call_context_architecture_method(context: Object, method_name: StringName) -> GFArchitecture:
	if not context.has_method(method_name):
		return null
	var architecture_value: Variant = context.call(method_name)
	return _variant_to_architecture(architecture_value)


func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		return value
	return null


# --- 内部类 ---

class _QueuedExitTransition:
	var _state_name: StringName = &""
	var _msg: Dictionary = {}

	func _init(p_state_name: StringName = &"", p_msg: Dictionary = {}) -> void:
		_state_name = p_state_name
		_msg = p_msg
