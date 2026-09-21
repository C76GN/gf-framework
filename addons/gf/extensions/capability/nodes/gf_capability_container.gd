## GFCapabilityContainer: 场景树中的能力组件容器。
##
## 将该节点作为某个 Node 的子节点后，容器内带脚本的子节点会被注册为父节点的能力。
## 需要在当前架构中注册 GFCapabilityUtility。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFCapabilityContainer
extends Node


# --- 常量 ---

const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _GF_CAPABILITY_UTILITY_BASE = preload("res://addons/gf/extensions/capability/core/gf_capability_utility.gd")


# --- 导出变量 ---

## 是否在进入场景树后自动注册已有子节点。
## [br]
## @api public
@export var auto_register_children: bool = true

## 是否在子节点顺序变化时自动注册新增子节点。
## [br]
## @api public
@export var watch_child_changes: bool = true


# --- 私有变量 ---

var _registered_children: Dictionary = {}
var _is_registering_children: bool = false
var _register_children_deferred_queued: bool = false


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	if not child_order_changed.is_connected(_on_child_order_changed):
		_connect_signal(child_order_changed, _on_child_order_changed)

	if auto_register_children:
		_register_children(false)
		_queue_register_children()


func _exit_tree() -> void:
	_unregister_registered_children()
	if child_order_changed.is_connected(_on_child_order_changed):
		child_order_changed.disconnect(_on_child_order_changed)
	_registered_children.clear()
	_is_registering_children = false
	_register_children_deferred_queued = false


# --- 公共方法 ---

## 获取容器服务的能力接收者。
## [br]
## @api public
## [br]
## @return: 容器的父节点；容器尚未挂载时返回 null。
func get_receiver() -> Node:
	return get_parent()


## 立即扫描并注册容器中的子节点能力。
## [br]
## @api public
func register_children_now() -> void:
	_register_children()


# --- 私有/辅助方法 ---

func _on_child_order_changed() -> void:
	if watch_child_changes and is_inside_tree():
		_register_children(false)
		_queue_register_children()


func _queue_register_children() -> void:
	if _register_children_deferred_queued:
		return

	_register_children_deferred_queued = true
	call_deferred("_register_children_deferred")


func _register_children_deferred() -> void:
	_register_children_deferred_queued = false
	if not is_inside_tree():
		return

	_register_children(true)


func _register_children(warn_if_missing_utility: bool = true) -> void:
	if _is_registering_children:
		return

	var receiver: Node = get_receiver()
	if not is_instance_valid(receiver):
		return

	var capability_utility: GFCapabilityUtility = _get_capability_utility()
	if capability_utility == null:
		if warn_if_missing_utility:
			push_warning("[GFCapabilityContainer][capability_container.missing_capability_utility] Cannot register child node capabilities: GFCapabilityUtility is not registered in the current architecture.")
		return

	_is_registering_children = true
	for child: Node in get_children():
		if _registered_children.has(child.get_instance_id()):
			continue

		var child_script: Script = _get_node_script(child)
		if child_script == null:
			continue

		var capability: Object = capability_utility.add_capability_instance(receiver, child, child_script)
		if capability == child:
			var child_id: int = child.get_instance_id()
			var exiting_callback: Callable = _on_registered_child_tree_exiting.bind(child_id)
			if not child.tree_exiting.is_connected(exiting_callback):
				_connect_signal(child.tree_exiting, exiting_callback)
			_registered_children[child_id] = {
				"script": child_script,
				"ref": weakref(child),
				"tree_exiting": exiting_callback,
			}
	_is_registering_children = false


func _unregister_registered_children() -> void:
	if _registered_children.is_empty():
		return

	var receiver: Node = get_receiver()
	if not is_instance_valid(receiver):
		return

	var capability_utility: GFCapabilityUtility = _get_capability_utility()
	if capability_utility == null:
		return

	var child_ids: Array = _registered_children.keys()
	for child_id_variant: Variant in child_ids:
		_unregister_child_record(GFVariantData.to_int(child_id_variant), receiver, capability_utility)


func _get_capability_utility() -> GFCapabilityUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null

	var utility: Object = architecture.get_utility(_GF_CAPABILITY_UTILITY_BASE)
	if utility is GFCapabilityUtility:
		var capability_utility: GFCapabilityUtility = utility
		return capability_utility
	return null


func _get_architecture_or_null() -> GFArchitecture:
	var current_node: Node = self
	while current_node != null:
		if current_node is GFNodeContext:
			var context: GFNodeContext = current_node
			var context_architecture: GFArchitecture = context.get_architecture()
			if context_architecture != null:
				return context_architecture
		current_node = current_node.get_parent()

	return GFAutoload.get_architecture_or_null()


func _unregister_child_record(child_id: int, receiver: Node, capability_utility: GFCapabilityUtility) -> void:
	if not _registered_children.has(child_id):
		return

	var record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_registered_children, child_id, {}))
	_erase_dictionary_key(_registered_children, child_id)
	if record.is_empty():
		return

	var child_ref: WeakRef = _get_weak_ref_value(GFVariantData.get_option_value(record, "ref"))
	var child: Node = _get_live_node_from_ref(child_ref)
	var exiting_callback: Callable = _get_callable_value(GFVariantData.get_option_value(record, "tree_exiting"))
	if child != null and exiting_callback.is_valid() and child.tree_exiting.is_connected(exiting_callback):
		child.tree_exiting.disconnect(exiting_callback)

	var child_script: Script = _get_script_value(GFVariantData.get_option_value(record, "script"))
	if child_script == null:
		return
	if is_instance_valid(receiver) and capability_utility != null:
		if capability_utility.get_capability(receiver, child_script) == child:
			capability_utility.unregister_capability(receiver, child_script)


func _on_registered_child_tree_exiting(child_id: int) -> void:
	var receiver: Node = get_receiver()
	if not is_instance_valid(receiver):
		_erase_dictionary_key(_registered_children, child_id)
		return

	var capability_utility: GFCapabilityUtility = _get_capability_utility()
	if capability_utility == null:
		_erase_dictionary_key(_registered_children, child_id)
		return
	_unregister_child_record(child_id, receiver, capability_utility)


func _get_node_script(node: Node) -> Script:
	var script_value: Variant = node.get_script()
	return _get_script_value(script_value)


func _get_live_node_from_ref(source_ref: WeakRef) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node_from_ref", source_ref)
	if result is Node:
		var node: Node = result
		return node
	return null


func _get_weak_ref_value(value: Variant) -> WeakRef:
	if value is WeakRef:
		var source_ref: WeakRef = value
		return source_ref
	return null


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _connect_signal(source_signal: Signal, callback: Callable) -> void:
	var connected: int = source_signal.connect(callback)
	if connected == OK:
		return


func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var erased: bool = source.erase(key)
	if erased:
		return
