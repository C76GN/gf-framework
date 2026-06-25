## GFState: 纯代码状态机的状态抽象基类。
##
## 继承自 RefCounted，不依赖 Node 树，可在任何逻辑层使用。
## 通过持有对所属 GFStateMachine 的弱引用，间接访问框架的
## Model、System、Utility 层，实现状态与框架的解耦。
## 子类必须重写 enter()、update()、exit() 以实现具体状态逻辑。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFState
extends RefCounted


# --- 私有变量 ---

# 持有对所属状态机的弱引用，用于访问框架上下文和切换状态。
var _machine_ref: WeakRef = null
var _state_name: StringName = &""


# --- 公共方法 ---

## 由 GFStateMachine 在内部调用，用于注入机器引用。
## [br]
## @api framework_internal
## [br]
## @param machine: 拥有此状态的 GFStateMachine 实例。
## [br]
## @param state_name: 该状态在状态机中的注册名。
func setup(machine: GFStateMachine, state_name: StringName = &"") -> void:
	_machine_ref = weakref(machine) if machine != null else null
	_state_name = state_name


## 释放对状态机的引用，避免 RefCounted 环状引用。
## [br]
## @api framework_internal
func dispose() -> void:
	unregister_owner_events()
	_machine_ref = null
	_state_name = &""


## 进入此状态时调用。子类可重写以执行进入逻辑（如初始化动画）。
## [br]
## @api public
## [br]
## @param _msg: 从上一个状态或调用方传递过来的可选参数字典。
## [br]
## @schema _msg: Dictionary state transition payload.
func enter(_msg: Dictionary = {}) -> void:
	pass


## 每帧更新时调用，用于处理持续性逻辑（如计时、轮询）。
## [br]
## @api public
## [br]
## @param _delta: 上一帧的时间间隔（秒）。
func update(_delta: float) -> void:
	pass


## 退出此状态时调用。子类可重写以执行清理逻辑（如停止动画）。
## [br]
## @api public
func exit() -> void:
	pass


## 获取该状态在状态机中的注册名。
## [br]
## @api public
## [br]
## @return 注册名；未加入状态机时为空 StringName。
func get_state_name() -> StringName:
	return _state_name


## 判断是否允许进入状态。用于 GFStateMachine 分层切换守卫。
## [br]
## @api public
## [br]
## @param _previous_state: 来源叶子状态名。
## [br]
## @param _msg: 状态切换参数。
## [br]
## @return 允许进入返回 true。
## [br]
## @schema _msg: Dictionary state transition payload.
func can_enter(_previous_state: StringName = &"", _msg: Dictionary = {}) -> bool:
	return true


## 判断是否允许离开状态。用于 GFStateMachine 分层切换守卫。
## [br]
## @api public
## [br]
## @param _next_state: 目标叶子状态名。
## [br]
## @param _msg: 状态切换参数。
## [br]
## @return 允许离开返回 true。
## [br]
## @schema _msg: Dictionary state transition payload.
func can_exit(_next_state: StringName = &"", _msg: Dictionary = {}) -> bool:
	return true


## 处理状态事件。返回 false 时事件会继续向父状态上抛。
## [br]
## @api public
## [br]
## @param _event_id: 状态事件标识。
## [br]
## @param _payload: 状态事件载荷。
## [br]
## @return 已处理返回 true。
## [br]
## @schema _payload: Variant state event payload.
func handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:
	return false


## 获取框架内的 Model 实例（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param model_type: 模型的脚本类型。
## [br]
## @return 模型实例。
func get_model(model_type: Script) -> Object:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return null
	return machine.get_model(model_type)


## 获取框架内的 System 实例（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param system_type: 系统的脚本类型。
## [br]
## @return 系统实例。
func get_system(system_type: Script) -> Object:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return null
	return machine.get_system(system_type)


## 获取框架内的 Utility 实例（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param utility_type: 工具的脚本类型。
## [br]
## @return 工具实例。
func get_utility(utility_type: Script) -> Object:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return null
	return machine.get_utility(utility_type)


## 向框架发送命令（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return 命令执行结果；未绑定状态机时返回 null。
## [br]
## @schema return: Variant command result, Signal, or null.
func send_command(command: Object) -> Variant:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return null
	return machine.send_command(command)


## 向框架发送查询（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param query: 要发送的查询实例。
## [br]
## @return 查询结果；未绑定状态机时返回 null。
## [br]
## @schema return: Variant query result or null.
func send_query(query: Object) -> Variant:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return null
	return machine.send_query(query)


## 发送类型事件（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.send_event(event_instance)


## 发送轻量级 StringName 事件（委托给所属状态机）。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: Variant event payload.
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.send_simple_event(event_id, payload)


## 注册类型事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param callback: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event(event_type: Script, callback: Callable, priority: int = 0) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.register_event_owned(self, event_type, callback, priority)


## 注销类型事件监听器。
## [br]
## @api public
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param callback: 要移除的回调函数。
func unregister_event(event_type: Script, callback: Callable) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.unregister_event(event_type, callback, self)


## 注册可赋值类型事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param callback: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event(base_event_type: Script, callback: Callable, priority: int = 0) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.register_assignable_event_owned(self, base_event_type, callback, priority)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param callback: 要移除的回调函数。
func unregister_assignable_event(base_event_type: Script, callback: Callable) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.unregister_assignable_event(base_event_type, callback, self)


## 注册轻量级 StringName 事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param callback: 回调函数，签名为 func(payload: Variant)。
func register_simple_event(event_id: StringName, callback: Callable) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.register_simple_event_owned(self, event_id, callback)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param callback: 要移除的回调函数。
func unregister_simple_event(event_id: StringName, callback: Callable) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.unregister_simple_event(event_id, callback, self)


## 注销当前状态通过事件代理注册过的全部监听器。
## [br]
## @api public
func unregister_owner_events() -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.unregister_owner_events(self)


## 请求状态机切换到指定状态。
## [br]
## @api public
## [br]
## @param state_name: 目标状态的注册名。
## [br]
## @param msg: 传递给目标状态 enter() 的可选参数字典。
## [br]
## @schema msg: Dictionary state transition payload.
func change_state(state_name: StringName, msg: Dictionary = {}) -> void:
	var machine: GFStateMachine = _get_machine()
	if machine != null:
		machine.change_state(state_name, msg)


## 从所属状态机派发状态事件。
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
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return false
	return machine.dispatch_state_event(event_id, payload)


## 获取当前状态在所属状态机中的父状态名。
## [br]
## @api public
## [br]
## @return 父状态名；未绑定状态机或没有父级时返回空 StringName。
func get_parent_state_name() -> StringName:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return &""
	return machine.get_parent_state_name(_state_name)


## 判断指定状态是否在所属状态机当前激活路径中。
## [br]
## @api public
## [br]
## @param state_name: 要查询的状态名。
## [br]
## @return 处于激活路径中返回 true。
func is_in_state(state_name: StringName) -> bool:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return false
	return machine.is_in_state(state_name)


## 获取所属状态机共享黑板。
## [br]
## @api public
## [br]
## @return 黑板字典；未绑定状态机时返回空字典。
## [br]
## @schema return: Dictionary shared blackboard.
func get_blackboard() -> Dictionary:
	var machine: GFStateMachine = _get_machine()
	if machine == null:
		return {}
	return machine.get_blackboard()


# --- 私有/辅助方法 ---

func _get_machine() -> GFStateMachine:
	if _machine_ref == null:
		return null
	var machine_value: Variant = _machine_ref.get_ref()
	if machine_value is GFStateMachine:
		var machine: GFStateMachine = machine_value
		return machine
	return null
