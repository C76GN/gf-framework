## GFNodeState: 基于场景树的状态节点。
##
## 适合需要直接访问动画、碰撞、输入或子节点的状态逻辑。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNodeState
extends Node


# --- 信号 ---

## 状态请求切换时发出，由所属状态组或状态机处理。
## [br]
## @api public
## [br]
## @param group_name: 目标状态组名。
## [br]
## @param state_name: 目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)


# --- 常量 ---

const _PHASE_ENTER: StringName = &"enter"
const _PHASE_EXIT: StringName = &"exit"


# --- 导出变量 ---

## 状态注册名。为空时使用节点名称。
## [br]
## @api public
@export var state_name: StringName = &""

@export_group("Resource Hooks")
## 进入状态前需要全部通过的条件资源。
## [br]
## @api public
## [br]
## @schema enter_conditions: 元素为 GFNodeStateCondition 或兼容 evaluate() 入口的 Resource 列表。
@export var enter_conditions: Array[Resource] = []

## 离开状态前需要全部通过的条件资源。
## [br]
## @api public
## [br]
## @schema exit_conditions: 元素为 GFNodeStateCondition 或兼容 evaluate() 入口的 Resource 列表。
@export var exit_conditions: Array[Resource] = []

## 进入、退出、暂停、恢复和事件处理时调用的可复用行为资源。
## [br]
## @api public
## [br]
## @schema behaviors: 元素为 GFNodeStateBehavior 或兼容状态生命周期入口的 Resource 列表。
@export var behaviors: Array[Resource] = []

@export_group("")


# --- 公共变量 ---

## 状态机宿主节点。通常是 GFNodeStateMachine 的父节点。
## [br]
## @api public
var host: Node:
	get:
		return get_host()


# --- 私有变量 ---

var _machine_ref: WeakRef = null
var _group_ref: WeakRef = null
var _event_architectures: Array[WeakRef] = []
var _original_process_mode: int = Node.PROCESS_MODE_INHERIT


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_original_process_mode = process_mode
	_set_state_enabled(false)


func _exit_tree() -> void:
	unregister_owner_events()


# --- 公共方法 ---

## 获取所属状态机。
## [br]
## @api public
## [br]
## @return: 所属 GFNodeStateMachine；尚未挂入状态组时返回 null。
func get_machine() -> Object:
	if _machine_ref == null:
		return null
	return _machine_ref.get_ref()


## 获取所属状态组。
## [br]
## @api public
## [br]
## @return: 所属 GFNodeStateGroup；尚未挂入状态组时返回 null。
func get_group() -> Object:
	if _group_ref == null:
		return null
	return _group_ref.get_ref()


## 获取状态机宿主节点。若无状态机，则退回到状态组父节点或当前父节点。
## [br]
## @api public
## [br]
## @return: 状态机宿主节点；不可用时返回当前父节点或 null。
func get_host() -> Node:
	var machine: Node = _variant_to_node(get_machine())
	if machine != null and machine.get_parent() != null:
		return machine.get_parent()

	var group: Node = _variant_to_node(get_group())
	if group != null and group.get_parent() != null:
		return group.get_parent()

	return get_parent()


## 获取实际注册名。
## [br]
## @api public
## [br]
## @return: 非空 state_name，或节点名称转换出的 StringName。
func get_state_name() -> StringName:
	if state_name != &"":
		return state_name
	return StringName(name)


## 进入状态。
## [br]
## @api public
## [br]
## @param previous_state: 上一个状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
	_set_state_enabled(true)
	_enter(previous_state, args)
	_run_behaviors_enter(previous_state, args)


## 离开状态。
## [br]
## @api public
## [br]
## @param next_state: 下一个状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func exit(next_state: StringName = &"", args: Dictionary = {}) -> void:
	_exit(next_state, args)
	_run_behaviors_exit(next_state, args)
	unregister_owner_events()
	_set_state_enabled(false)


## 进入栈式子状态时暂停当前状态。
## [br]
## @api public
## [br]
## @param next_state: 下一个状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func pause(next_state: StringName = &"", args: Dictionary = {}) -> void:
	_pause(next_state, args)
	_run_behaviors_pause(next_state, args)
	_set_state_enabled(false)


## 弹出栈式子状态后恢复当前状态。
## [br]
## @api public
## [br]
## @param previous_state: 上一个状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func resume(previous_state: StringName = &"", args: Dictionary = {}) -> void:
	_set_state_enabled(true)
	_resume(previous_state, args)
	_run_behaviors_resume(previous_state, args)


## 请求切换状态。path 可为 "State" 或 "Group/State"。
## [br]
## @api public
## [br]
## @param path: 资源路径或状态路径。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func transition_to(path: StringName, args: Dictionary = {}) -> void:
	var text: String = String(path)
	var parts: PackedStringArray = text.split("/", false)
	if parts.size() == 1:
		var group: Object = get_group()
		var group_name: StringName = &""
		if group != null and group.has_method("get_group_name"):
			group_name = GFVariantData.to_string_name(group.call("get_group_name"))
		requested_transition.emit(group_name, StringName(parts[0]), args)
	elif parts.size() == 2:
		requested_transition.emit(StringName(parts[0]), StringName(parts[1]), args)
	else:
		push_error("[GFNodeState] transition_to 失败：路径格式无效。")


## 状态初始化 Hook。状态加入状态组时调用一次。
## [br]
## @api public
func initialize() -> void:
	_initialize()
	_run_behaviors_initialize()


## 判断是否允许进入状态。
## [br]
## @api public
## [br]
## @param previous_state: 来源状态名。
## [br]
## @param args: 切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 允许进入返回 true。
func can_enter(previous_state: StringName = &"", args: Dictionary = {}) -> bool:
	if not _can_enter(previous_state, args):
		return false
	return _evaluate_conditions(enter_conditions, _PHASE_ENTER, previous_state, args)


## 判断是否允许离开状态。
## [br]
## @api public
## [br]
## @param next_state: 目标状态名。
## [br]
## @param args: 切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 允许离开返回 true。
func can_exit(next_state: StringName = &"", args: Dictionary = {}) -> bool:
	if not _can_exit(next_state, args):
		return false
	return _evaluate_conditions(exit_conditions, _PHASE_EXIT, next_state, args)


## 获取状态组共享黑板。
## [br]
## @api public
## [br]
## @return: 黑板字典；没有状态组时返回空字典。
## [br]
## @schema return: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定。
func get_blackboard() -> Dictionary:
	var group: Object = get_group()
	if group != null and group.has_method("get_blackboard"):
		return GFVariantData.as_dictionary(group.call("get_blackboard"))
	return {}


## 处理状态事件。返回 false 时事件会继续交给同组的暂停栈状态。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。
## [br]
## @return: 已处理返回 true。
func handle_state_event(event_id: StringName, payload: Variant = null) -> bool:
	if _handle_state_event(event_id, payload):
		return true
	return _run_behaviors_handle_state_event(event_id, payload)


## 获取当前状态可用的架构实例。
## [br]
## @api public
## [br]
## @return: 架构实例；状态未挂入可解析上下文时返回 null。
func get_architecture_or_null() -> GFArchitecture:
	return _get_architecture_or_null()


## 通过当前状态上下文获取 Model。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 模型实例；不可用时返回 null。
func get_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_model(model_type, require_ready)


## 通过当前状态上下文获取 System。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 系统实例；不可用时返回 null。
func get_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_system(system_type, require_ready)


## 通过当前状态上下文获取 Utility。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 工具实例；不可用时返回 null。
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_utility(utility_type, require_ready)


## 仅从当前状态所属架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的模型实例；不可用时返回 null。
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_model(model_type, require_ready)


## 仅从当前状态所属架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的系统实例；不可用时返回 null。
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_system(system_type, require_ready)


## 仅从当前状态所属架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的工具实例；不可用时返回 null。
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_utility(utility_type, require_ready)


## 向当前状态上下文发送命令。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return: 命令执行结果；无可用架构时返回 null。
## [br]
## @schema return: 命令返回值；具体结构由 GFCommand 实现决定。
func send_command(command: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_command(command)


## 向当前状态上下文发送查询。
## [br]
## @api public
## [br]
## @param query: 要发送的查询实例。
## [br]
## @return: 查询结果；无可用架构时返回 null。
## [br]
## @schema return: 查询返回值；具体结构由 GFQuery 实现决定。
func send_query(query: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_query(query)


## 发送类型事件。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_event(event_instance)


## 发送轻量级 StringName 事件。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: 轻量事件载荷；具体结构由 event_id 和项目逻辑约定。
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_simple_event(event_id, payload)


## 注册类型事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_event_owned(self, event_type, listener, priority)
		_remember_event_architecture(architecture)


## 注销类型事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_event_owned(self, event_type, listener)


## 注册可赋值类型事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_assignable_event_owned(self, base_event_type, listener, priority)
		_remember_event_architecture(architecture)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_assignable_event_owned(self, base_event_type, listener)


## 注册轻量级 StringName 事件监听器，默认以当前状态作为 owner。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_simple_event_owned(self, event_id, listener)
		_remember_event_architecture(architecture)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 要移除的简单事件监听器契约。
func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_simple_event_owned(self, event_id, listener)


## 注销当前状态通过事件代理注册过的全部监听器。
## [br]
## @api public
func unregister_owner_events() -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_owner_events(self)
	_event_architectures.clear()


# --- 可重写钩子 / 虚方法 ---

## 状态初始化扩展点。
## [br]
## @api protected
func _initialize() -> void:
	pass


## 状态进入守卫扩展点。
## [br]
## @api protected
## [br]
## @param _previous_state: 来源状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 允许进入返回 true。
func _can_enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> bool:
	return true


## 状态退出守卫扩展点。
## [br]
## @api protected
## [br]
## @param _next_state: 目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 允许退出返回 true。
func _can_exit(_next_state: StringName = &"", _args: Dictionary = {}) -> bool:
	return true


## 状态进入扩展点。
## [br]
## @api protected
## [br]
## @param _previous_state: 来源状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


## 状态退出扩展点。
## [br]
## @api protected
## [br]
## @param _next_state: 目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


## 状态被栈式子状态覆盖时的扩展点。
## [br]
## @api protected
## [br]
## @param _next_state: 目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _pause(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


## 状态从栈式子状态恢复时的扩展点。
## [br]
## @api protected
## [br]
## @param _previous_state: 来源状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _resume(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


## 状态事件处理扩展点。
## [br]
## @api protected
## [br]
## @param _event_id: 状态事件标识。
## [br]
## @param _payload: 状态事件载荷。
## [br]
## @schema _payload: 状态事件载荷；具体结构由 _event_id 和项目逻辑约定。
## [br]
## @return: 已处理返回 true。
func _handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:
	return false


# --- 框架内部方法 ---

## 由状态组调用，注入状态机与状态组引用。
## [br]
## @api framework_internal
## [br]
## @param machine: 关联的节点状态机。
## [br]
## @param group: 所属状态组。
func setup(machine: Object, group: Object) -> void:
	_machine_ref = weakref(machine) if machine != null else null
	_group_ref = weakref(group) if group != null else null


# --- 私有/辅助方法 ---

func _evaluate_conditions(
	conditions: Array[Resource],
	phase: StringName,
	peer_state: StringName,
	args: Dictionary
) -> bool:
	for condition: Resource in conditions:
		if condition == null or not condition.has_method("evaluate"):
			continue
		var result: Variant = condition.call("evaluate", self, phase, peer_state, args)
		if not GFVariantData.to_bool(result):
			return false
	return true


func _run_behaviors_initialize() -> void:
	for behavior: Resource in behaviors:
		if behavior != null and behavior.has_method("initialize"):
			var _result: Variant = behavior.call("initialize", self)


func _run_behaviors_enter(previous_state: StringName, args: Dictionary) -> void:
	for behavior: Resource in behaviors:
		if behavior != null and behavior.has_method("enter"):
			var _result: Variant = behavior.call("enter", self, previous_state, args)


func _run_behaviors_exit(next_state: StringName, args: Dictionary) -> void:
	for behavior: Resource in behaviors:
		if behavior != null and behavior.has_method("exit"):
			var _result: Variant = behavior.call("exit", self, next_state, args)


func _run_behaviors_pause(next_state: StringName, args: Dictionary) -> void:
	for behavior: Resource in behaviors:
		if behavior != null and behavior.has_method("pause"):
			var _result: Variant = behavior.call("pause", self, next_state, args)


func _run_behaviors_resume(previous_state: StringName, args: Dictionary) -> void:
	for behavior: Resource in behaviors:
		if behavior != null and behavior.has_method("resume"):
			var _result: Variant = behavior.call("resume", self, previous_state, args)


func _run_behaviors_handle_state_event(event_id: StringName, payload: Variant) -> bool:
	for behavior: Resource in behaviors:
		if behavior == null or not behavior.has_method("handle_state_event"):
			continue
		var result: Variant = behavior.call("handle_state_event", self, event_id, payload)
		if GFVariantData.to_bool(result):
			return true
	return false


func _set_state_enabled(enabled: bool) -> void:
	if enabled:
		process_mode = _to_process_mode(_original_process_mode)
	else:
		process_mode = Node.PROCESS_MODE_DISABLED as Node.ProcessMode


func _get_architecture_or_null() -> GFArchitecture:
	var machine: Object = get_machine()
	if machine != null and machine.has_method("get_architecture_or_null"):
		var machine_architecture: GFArchitecture = _variant_to_architecture(machine.call("get_architecture_or_null"))
		if machine_architecture != null:
			return machine_architecture

	var context: GFNodeContext = _find_nearest_context()
	if context != null:
		var context_architecture: GFArchitecture = context.get_architecture()
		if context_architecture != null:
			return context_architecture

	return GFAutoload.get_architecture_or_null()


func _find_nearest_context() -> GFNodeContext:
	var current_node: Node = self
	while current_node != null:
		if current_node is GFNodeContext:
			var context: GFNodeContext = current_node
			return context
		current_node = current_node.get_parent()
	return null


func _to_process_mode(value: int) -> ProcessMode:
	match value:
		Node.PROCESS_MODE_PAUSABLE:
			return Node.PROCESS_MODE_PAUSABLE
		Node.PROCESS_MODE_WHEN_PAUSED:
			return Node.PROCESS_MODE_WHEN_PAUSED
		Node.PROCESS_MODE_ALWAYS:
			return Node.PROCESS_MODE_ALWAYS
		Node.PROCESS_MODE_DISABLED:
			return Node.PROCESS_MODE_DISABLED
		_:
			return Node.PROCESS_MODE_INHERIT


func _remember_event_architecture(architecture: GFArchitecture) -> void:
	if architecture == null or not is_instance_valid(architecture):
		return
	for architecture_ref: WeakRef in _event_architectures:
		if architecture_ref.get_ref() == architecture:
			return
	_event_architectures.append(weakref(architecture))


func _get_tracked_event_architectures() -> Array[GFArchitecture]:
	var result: Array[GFArchitecture] = []
	var live_architectures: Array[WeakRef] = []
	for architecture_ref: WeakRef in _event_architectures:
		var architecture: GFArchitecture = _variant_to_architecture(architecture_ref.get_ref())
		if architecture != null and is_instance_valid(architecture):
			result.append(architecture)
			live_architectures.append(architecture_ref)
	_event_architectures = live_architectures
	return result


func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null
