## GFController: 连接 UI/输入与架构的控制器基类。
##
## 提供访问架构的便捷代理。这里不缓存 Model/System/Utility 引用，
## 以避免架构切换或模块注销后保留过期对象。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFController
extends Node


# --- 常量 ---

## 局部节点上下文脚本类型缓存。
## [br]
## @api framework_internal
const GFNodeContextBase = preload("res://addons/gf/kernel/core/gf_node_context.gd")
const _EVENT_BINDING_KIND_TYPE: StringName = &"type"
const _EVENT_BINDING_KIND_ASSIGNABLE: StringName = &"assignable"
const _EVENT_BINDING_KIND_SIMPLE: StringName = &"simple"
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 导出变量 ---

## Controller 控制的宿主节点路径。默认指向父节点。
##
## 当 Controller 不是宿主节点的直接子节点时，可在 Inspector 中改为目标节点路径。
## [br]
## @api public
@export var host_node_path: NodePath = NodePath("..")


# --- 公共变量 ---

## Controller 控制的宿主节点。
## [br]
## @api public
var host: Node:
	get:
		return get_host()


# --- 私有变量 ---

var _event_architectures: Array[GFArchitecture] = []
var _event_bindings: Array[Dictionary] = []
var _events_paused_by_pool: bool = false


# --- Godot 生命周期方法 ---

func _exit_tree() -> void:
	if _events_paused_by_pool:
		return
	_remember_event_architecture(_get_architecture_or_null())
	_unregister_all_tracked_owner_events()
	_event_bindings.clear()


# --- 公共方法（获取） ---

## 获取当前 Controller 所属的架构。
##
## 优先沿场景树向上寻找 GFNodeContext；若未找到，则回退到全局 Gf 架构。
## [br]
## @api public
## [br]
## @return 当前可用的架构实例。
func get_architecture() -> GFArchitecture:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		return architecture
	return GFAutoload.get_architecture()


## 获取当前 Controller 所属的架构，找不到时返回 null 且不触发全局错误。
## [br]
## @api public
## [br]
## @return 当前可用的架构实例。
func get_architecture_or_null() -> GFArchitecture:
	return _get_architecture_or_null()


## 等待最近的 GFNodeContext 完成初始化并返回可用架构。
## 若当前节点不在上下文子树下，则直接返回全局架构。
## [br]
## @api public
## [br]
## @return 当前 Controller 可用的架构实例。
func wait_for_context_ready() -> GFArchitecture:
	var context: GFNodeContextBase = _find_nearest_context()
	if context != null:
		return await context.wait_until_ready()

	return get_architecture()


## 获取当前 Controller 控制的宿主节点。
##
## 默认返回父节点。若宿主不是父节点，可通过 host_node_path 指定。
## [br]
## @api public
## [br]
## @return 当前宿主节点；路径为空或目标不存在时返回 null。
func get_host() -> Node:
	if host_node_path.is_empty():
		return null
	return get_node_or_null(host_node_path)


## 判断当前 Controller 是否能解析到有效宿主节点。
## [br]
## @api public
## [br]
## @return 能解析到宿主节点时返回 true。
func has_host() -> bool:
	return get_host() != null


## 获取指定类型的宿主节点。
##
## 可传入项目脚本类型或 Godot 原生类型。
## [br]
## @api public
## [br]
## @param host_type: 宿主节点类型。
## [br]
## @return 匹配类型的宿主节点；未找到或类型不匹配时返回 null。
## [br]
## @schema host_type {
##   "type": "Variant",
##   "description": "Script、ClassDB 原生类型或 null。"
## }
func get_host_as(host_type: Variant) -> Node:
	var current_host: Node = get_host()
	if current_host == null:
		return null
	if host_type == null:
		return current_host
	if is_instance_of(current_host, host_type):
		return current_host
	return null


## 通过类型获取 Model 实例。
## [br]
## @api public
## [br]
## @param model_type: 模型的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例。
func get_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_model(model_type, require_ready)


## 通过类型获取 System 实例。
## [br]
## @api public
## [br]
## @param system_type: 系统的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例。
func get_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_system(system_type, require_ready)


## 通过类型获取 Utility 实例。
## [br]
## @api public
## [br]
## @param utility_type: 工具的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例。
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_utility(utility_type, require_ready)


## 仅从当前 Controller 所属架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param model_type: 模型的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的模型实例。
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_model(model_type, require_ready)


## 仅从当前 Controller 所属架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param system_type: 系统的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的系统实例。
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_system(system_type, require_ready)


## 仅从当前 Controller 所属架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param utility_type: 工具的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的工具实例。
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_utility(utility_type, require_ready)


# --- 公共方法（命令与查询） ---

## 向架构发送命令。支持 await：'await send_command(MyCommand.new())'。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return 命令的执行结果（null 或 Signal）。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "命令执行结果；异步命令可返回 Signal。"
## }
func send_command(command: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_command(command)


## 执行查询并返回结果。
## [br]
## @api public
## [br]
## @param query: 要执行的查询实例。
## [br]
## @return 查询结果。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "查询结果；具体类型由查询对象定义。"
## }
func send_query(query: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_query(query)


# --- 公共方法（事件系统） ---

## 注册类型事件监听器。
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
	_remember_event_binding(_EVENT_BINDING_KIND_TYPE, event_type, listener, priority)
	if _events_paused_by_pool:
		return
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
	_forget_event_binding(_EVENT_BINDING_KIND_TYPE, event_type, listener)
	if not _unregister_event_from_tracked_architectures(event_type, listener):
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture != null:
			architecture.unregister_event_owned(self, event_type, listener)


## 注册可赋值类型事件监听器。
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
	_remember_event_binding(_EVENT_BINDING_KIND_ASSIGNABLE, base_event_type, listener, priority)
	if _events_paused_by_pool:
		return
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
	_forget_event_binding(_EVENT_BINDING_KIND_ASSIGNABLE, base_event_type, listener)
	if not _unregister_assignable_event_from_tracked_architectures(base_event_type, listener):
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture != null:
			architecture.unregister_assignable_event_owned(self, base_event_type, listener)


## 通过事件系统发送类型事件。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_event(event_instance)


## 注册轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
	_remember_event_binding(_EVENT_BINDING_KIND_SIMPLE, event_id, listener, 0)
	if _events_paused_by_pool:
		return
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
	_forget_event_binding(_EVENT_BINDING_KIND_SIMPLE, event_id, listener)
	if not _unregister_simple_event_from_tracked_architectures(event_id, listener):
		var architecture: GFArchitecture = _get_architecture_or_null()
		if architecture != null:
			architecture.unregister_simple_event_owned(self, event_id, listener)


## 发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload {
##   "type": "Variant",
##   "description": "事件附加数据；由事件消费者约定结构。"
## }
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_simple_event(event_id, payload)


# --- 私有/辅助方法 ---

func _gf_on_object_pool_release() -> void:
	if _events_paused_by_pool:
		return
	_remember_event_architecture(_get_architecture_or_null())
	_unregister_all_tracked_owner_events()
	_events_paused_by_pool = true


func _gf_on_object_pool_acquire() -> void:
	if not _events_paused_by_pool:
		return
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return

	for binding: Dictionary in _event_bindings:
		_register_event_binding(architecture, binding)
	_remember_event_architecture(architecture)
	_events_paused_by_pool = false


func _get_architecture_or_null() -> GFArchitecture:
	var context: GFNodeContextBase = _find_nearest_context()
	if context != null:
		var context_architecture: GFArchitecture = context.get_architecture()
		if context_architecture != null:
			return context_architecture

	return GFAutoload.get_architecture_or_null()


func _remember_event_architecture(architecture: GFArchitecture) -> void:
	if architecture == null or not is_instance_valid(architecture):
		return
	if not _event_architectures.has(architecture):
		_event_architectures.append(architecture)


func _remember_event_binding(kind: StringName, event_key: Variant, listener: GFEventListener, priority: int) -> void:
	for binding: Dictionary in _event_bindings:
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(binding, "kind") == kind
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, "event_key") == event_key
			and _listeners_match(_read_binding_listener(binding, "listener"), listener)
		):
			return

	_event_bindings.append({
		"kind": kind,
		"event_key": event_key,
		"listener": listener,
		"priority": priority,
	})


func _forget_event_binding(kind: StringName, event_key: Variant, listener: GFEventListener) -> void:
	for i: int in range(_event_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _event_bindings[i]
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(binding, "kind") == kind
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, "event_key") == event_key
			and _listeners_match(_read_binding_listener(binding, "listener"), listener)
		):
			_event_bindings.remove_at(i)


func _register_event_binding(architecture: GFArchitecture, binding: Dictionary) -> void:
	if architecture == null or not is_instance_valid(architecture):
		return

	var kind: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(binding, "kind")
	var event_key: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, "event_key")
	var listener: GFEventListener = _read_binding_listener(binding, "listener")
	var priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(binding, "priority")

	if kind == _EVENT_BINDING_KIND_TYPE:
		if event_key is Script:
			var event_type: Script = event_key
			architecture.register_event_owned(self, event_type, listener, priority)
	elif kind == _EVENT_BINDING_KIND_ASSIGNABLE:
		if event_key is Script:
			var base_event_type: Script = event_key
			architecture.register_assignable_event_owned(self, base_event_type, listener, priority)
	elif kind == _EVENT_BINDING_KIND_SIMPLE:
		if event_key is StringName:
			var event_id: StringName = event_key
			architecture.register_simple_event_owned(self, event_id, listener)


func _unregister_all_tracked_owner_events() -> void:
	for architecture: GFArchitecture in _event_architectures:
		if architecture != null and is_instance_valid(architecture):
			architecture.unregister_owner_events(self)
	_event_architectures.clear()


func _read_binding_listener(binding: Dictionary, key: String) -> GFEventListener:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, key)
	if raw_value is GFEventListener:
		var listener: GFEventListener = raw_value
		return listener
	return null


func _listeners_match(left_listener: GFEventListener, right_listener: GFEventListener) -> bool:
	if left_listener == right_listener:
		return true
	if left_listener == null or right_listener == null:
		return false
	return left_listener.get_callback() == right_listener.get_callback()


func _unregister_event_from_tracked_architectures(event_type: Script, listener: GFEventListener) -> bool:
	var handled: bool = false
	for architecture: GFArchitecture in _event_architectures:
		if architecture != null and is_instance_valid(architecture):
			architecture.unregister_event_owned(self, event_type, listener)
			handled = true
	return handled


func _unregister_assignable_event_from_tracked_architectures(
	base_event_type: Script,
	listener: GFEventListener
) -> bool:
	var handled: bool = false
	for architecture: GFArchitecture in _event_architectures:
		if architecture != null and is_instance_valid(architecture):
			architecture.unregister_assignable_event_owned(self, base_event_type, listener)
			handled = true
	return handled


func _unregister_simple_event_from_tracked_architectures(event_id: StringName, listener: GFEventListener) -> bool:
	var handled: bool = false
	for architecture: GFArchitecture in _event_architectures:
		if architecture != null and is_instance_valid(architecture):
			architecture.unregister_simple_event_owned(self, event_id, listener)
			handled = true
	return handled


func _find_nearest_context() -> GFNodeContextBase:
	var current_node: Node = self
	while current_node != null:
		if current_node is GFNodeContextBase:
			var context: GFNodeContextBase = current_node
			return context
		current_node = current_node.get_parent()

	return null
