# GFInstanceGuard: 内部实例生命周期守卫工具。
#
# 用于从 Variant、WeakRef 或 instance_id 中安全解析仍有效的 Object / Node / Control。
# 该脚本不声明 class_name，作为 kernel 内部基础 helper 由上层模块按需 preload。
extends RefCounted


# --- 框架内部方法 ---

## 仅在 Variant 为仍有效的 Object 实例时返回对象。
## [br]
## @api framework_internal
## [br]
## @param value: 调用方持有的任意值，不假设对象引用仍有效。
## [br]
## @return: 仍有效的 Object；非对象或已释放对象返回 null。
## [br]
## @schema value: {"type":"Variant","description":"允许任意类型；仅有效 Object 会被接受。"}
static func _get_live_object(value: Variant) -> Object:
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	var object: Object = value
	return object


## 从 Variant 解析有效 Object，并仅在其为 Node 时返回。
## [br]
## @api framework_internal
## [br]
## @param value: 待收窄的任意值。
## [br]
## @return: 有效 Node；非 Node 或已释放对象返回 null。
## [br]
## @schema value: {"type":"Variant","description":"允许任意类型；仅有效 Node 会被接受。"}
static func _get_live_node(value: Variant) -> Node:
	var object: Object = _get_live_object(value)
	if object == null or not (object is Node):
		return null
	var node: Node = object
	return node


## 从非空 WeakRef 解析仍有效的 Object。
## [br]
## @api framework_internal
## [br]
## @param object_ref: 可为空或已失效的弱引用。
## [br]
## @return: 弱引用指向的有效 Object；否则为 null。
static func _get_live_object_from_ref(object_ref: WeakRef) -> Object:
	if object_ref == null:
		return null
	return _get_live_object(object_ref.get_ref())


## 从非空 WeakRef 解析仍有效的 Node。
## [br]
## @api framework_internal
## [br]
## @param object_ref: 可为空或已失效的弱引用。
## [br]
## @return: 弱引用指向的有效 Node；否则为 null。
static func _get_live_node_from_ref(object_ref: WeakRef) -> Node:
	if object_ref == null:
		return null
	return _get_live_node(object_ref.get_ref())


## 从非空 WeakRef 解析仍有效的 Control。
## [br]
## @api framework_internal
## [br]
## @param object_ref: 可为空或已失效的弱引用。
## [br]
## @return: 弱引用指向的有效 Control；否则为 null。
static func _get_live_control_from_ref(object_ref: WeakRef) -> Control:
	if object_ref == null:
		return null
	return _get_live_control(object_ref.get_ref())


## 从 instance_id 解析仍有效的 Node。
## [br]
## @api framework_internal
## [br]
## @param instance_id: 引擎对象实例 ID；不持有该对象的强引用。
## [br]
## @return: ID 对应的有效 Node；找不到对象或类型不匹配时为 null。
static func _get_live_node_from_id(instance_id: int) -> Node:
	return _get_live_node(instance_from_id(instance_id))


# --- 私有/辅助方法 ---

## 从 Variant 解析有效 Node，并仅在其为 Control 时返回。
## [br]
## @api private
static func _get_live_control(value: Variant) -> Control:
	var node: Node = _get_live_node(value)
	if node == null or not (node is Control):
		return null
	var control: Control = node
	return control


## 从 instance_id 解析仍有效的 Object。
## [br]
## @api private
static func _get_live_object_from_id(instance_id: int) -> Object:
	return _get_live_object(instance_from_id(instance_id))
