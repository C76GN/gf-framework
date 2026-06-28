## GFInteractionContext: 一次交互流程的轻量上下文。
##
## 用于在 Command、事件或项目自定义方法之间传递 sender、target、payload 与可选分组信息。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFInteractionContext
extends RefCounted


# --- 公共变量 ---

## 交互发起者。
## [br]
## @api public
## [br]
## @since 7.0.0
var sender: Object:
	get:
		return get_sender_or_null()
	set(value):
		_set_sender(value)

## 交互目标。
## [br]
## @api public
## [br]
## @since 7.0.0
var target: Object:
	get:
		return get_target_or_null()
	set(value):
		_set_target(value)

## 交互发起者实例 ID 快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var sender_instance_id: int = 0

## 交互目标实例 ID 快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_instance_id: int = 0

## 交互发起者节点路径快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var sender_path: NodePath = NodePath("")

## 交互目标节点路径快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_path: NodePath = NodePath("")

## 交互发起者类名快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var sender_class: String = ""

## 交互目标类名快照。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_class: String = ""

## 交互携带的数据。
## [br]
## @api public
## [br]
## @schema payload: 交互携带的任意项目载荷；框架只透传，不解释其中结构。
var payload: Variant = null

## 交互所属的可选分组。
## [br]
## @api public
var group_name: StringName = &""


# --- 私有变量 ---

var _sender_ref: WeakRef = null
var _target_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _init(
	p_sender: Object = null,
	p_target: Object = null,
	p_payload: Variant = null,
	p_group_name: StringName = &""
) -> void:
	_set_sender(p_sender)
	_set_target(p_target)
	payload = p_payload
	group_name = p_group_name


# --- 公共方法 ---

## 设置 sender 并返回自身，便于链式构造。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @return: 当前上下文。
func with_sender(value: Object) -> GFInteractionContext:
	_set_sender(value)
	return self


## 设置 target 并返回自身，便于链式构造。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @return: 当前上下文。
func with_target(value: Object) -> GFInteractionContext:
	_set_target(value)
	return self


## 设置 payload 并返回自身，便于链式构造。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @schema value: 要写入 payload 的任意项目载荷。
## [br]
## @return: 当前上下文。
func with_payload(value: Variant) -> GFInteractionContext:
	payload = value
	return self


## 设置 group_name 并返回自身，便于链式构造。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @return: 当前上下文。
func with_group(value: StringName) -> GFInteractionContext:
	group_name = value
	return self


## 获取当前 sender；对象已释放时返回 null。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 当前 sender 或 null。
func get_sender_or_null() -> Object:
	if _sender_ref == null:
		return null
	var value: Variant = _sender_ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object_value: Object = value
		return object_value
	return null


## 获取当前 target；对象已释放时返回 null。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 当前 target 或 null。
func get_target_or_null() -> Object:
	if _target_ref == null:
		return null
	var value: Variant = _target_ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object_value: Object = value
		return object_value
	return null


# --- 私有/辅助方法 ---

func _set_sender(value: Object) -> void:
	_sender_ref = weakref(value) if value != null else null
	sender_instance_id = value.get_instance_id() if value != null and is_instance_valid(value) else 0
	sender_path = _get_node_path_snapshot(value)
	sender_class = value.get_class() if value != null and is_instance_valid(value) else ""


func _set_target(value: Object) -> void:
	_target_ref = weakref(value) if value != null else null
	target_instance_id = value.get_instance_id() if value != null and is_instance_valid(value) else 0
	target_path = _get_node_path_snapshot(value)
	target_class = value.get_class() if value != null and is_instance_valid(value) else ""


func _get_node_path_snapshot(value: Object) -> NodePath:
	if value is Node:
		var node_value: Node = value
		if node_value.is_inside_tree():
			return node_value.get_path()
	return NodePath("")
