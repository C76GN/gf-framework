@tool
extends RefCounted

# 缩略图的原生视觉快照构建器，不复制场景执行状态。
# @api layer_internal
# @layer kernel/editor


# --- 常量 ---

const _VISUAL_CLASSES: Array[StringName] = [
	&"Node", &"Node2D", &"Node3D", &"CanvasGroup",
	&"Sprite2D", &"AnimatedSprite2D", &"Polygon2D", &"Line2D",
	&"MeshInstance2D",
	&"Sprite3D", &"AnimatedSprite3D", &"MeshInstance3D",
	&"Label3D", &"DirectionalLight3D", &"OmniLight3D", &"SpotLight3D",
	&"Control", &"ColorRect", &"TextureRect", &"NinePatchRect", &"Panel",
	&"Label", &"Button", &"CheckBox", &"CheckButton", &"TextureButton",
	&"ProgressBar", &"TextureProgressBar",
	&"Container", &"BoxContainer", &"HBoxContainer", &"VBoxContainer",
	&"FlowContainer", &"HFlowContainer", &"VFlowContainer", &"GridContainer",
	&"MarginContainer", &"CenterContainer", &"PanelContainer", &"AspectRatioContainer",
	&"ScrollContainer", &"SplitContainer", &"HSplitContainer", &"VSplitContainer",
	&"FoldableContainer",
]
const _BEHAVIOR_CLASSES: Array[StringName] = [
	&"Timer", &"AnimationPlayer", &"AnimationTree", &"AudioStreamPlayer",
	&"AudioStreamPlayer2D", &"AudioStreamPlayer3D",
	&"RemoteTransform2D", &"RemoteTransform3D",
	&"Area2D", &"Area3D", &"StaticBody2D", &"StaticBody3D",
	&"AnimatableBody2D", &"AnimatableBody3D", &"CharacterBody2D", &"CharacterBody3D",
	&"RigidBody2D", &"RigidBody3D", &"CollisionShape2D", &"CollisionShape3D",
	&"CollisionPolygon2D", &"CollisionPolygon3D", &"Marker2D", &"Marker3D",
	&"RayCast2D", &"RayCast3D", &"ShapeCast2D", &"ShapeCast3D",
	&"Camera2D", &"Camera3D", &"NavigationAgent2D", &"NavigationAgent3D",
	&"NavigationRegion2D", &"NavigationRegion3D",
]
const _SKIPPED_PROPERTIES: Array[StringName] = [
	&"script", &"owner", &"unique_name_in_owner", &"process_mode", &"process_thread_group",
	&"autoplay", &"playing", &"editor_description", &"button_group", &"foldable_group",
]
const _MAX_NODES: int = 4096
const _MAX_DEPTH: int = 128


# --- 私有变量 ---

var _error: String = ""
var _node_count: int = 0


# --- 层内方法 ---

## 创建未入树的静态视觉副本。
## [br]
## @api layer_internal
## [br]
## @layer kernel/editor
## [br]
## @param source: 已存在的来源节点；仅读取原生视觉属性。
## [br]
## @return 调用方拥有的副本；不支持的输入返回 null，可读取 get_error()。
func create_static_copy(source: Node) -> Node:
	_error = ""
	_node_count = 0
	if not is_instance_valid(source):
		_error = "Static thumbnail source is no longer valid."
		return null
	return _copy_node(source)


## 返回最近一次静态副本构建错误。
## [br]
## @api layer_internal
## [br]
## @layer kernel/editor
## [br]
## @return 构建错误；成功时为空字符串。
func get_error() -> String:
	return _error


# --- 私有/辅助方法 ---

func _copy_node(source: Node, depth: int = 0) -> Node:
	_node_count += 1
	if _node_count > _MAX_NODES or depth > _MAX_DEPTH:
		_error = "Static thumbnail exceeded its node count or hierarchy depth limit."
		return null
	var native_class: StringName = source.get_class()
	var copy_class: StringName = _get_copy_class(source, native_class)
	if copy_class.is_empty():
		_error = "Static thumbnail does not support native node '%s' (%s)." % [source.name, native_class]
		return null
	var created: Variant = ClassDB.instantiate(copy_class)
	if not created is Node:
		if created is Object and not created is RefCounted:
			var invalid_object: Object = created
			invalid_object.free()
		_error = "Static thumbnail could not create native node '%s'." % copy_class
		return null
	var copy: Node = created
	if not source.name.is_empty():
		copy.name = source.name
	copy.set_block_signals(true)
	if not _copy_native_properties(source, copy, copy_class):
		copy.free()
		return null
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	copy.set_process_internal(false)
	copy.set_physics_process_internal(false)
	for child: Node in source.get_children():
		var child_copy: Node = _copy_node(child, depth + 1)
		if child_copy == null:
			copy.free()
			return null
		copy.add_child(child_copy)
	return copy


func _get_copy_class(source: Node, native_class: StringName) -> StringName:
	if ClassDB.class_get_api_type(native_class) != ClassDB.API_CORE:
		return &""
	if native_class in _VISUAL_CLASSES:
		return native_class
	if native_class in _BEHAVIOR_CLASSES:
		if source is Node3D:
			return &"Node3D"
		if source is Node2D:
			return &"Node2D"
		return &"Node"
	return &""


func _copy_native_properties(source: Node, copy: Node, copy_class: StringName) -> bool:
	# 不能使用 source.get_property_list/get/duplicate：源脚本的导出 getter 和
	# _get_property_list 会执行；只访问 ClassDB 注册的无参原生 getter。
	for property: Dictionary in ClassDB.class_get_property_list(copy_class):
		var usage: int = property.get("usage", 0)
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name: StringName = property.get("name", &"")
		if property_name in _SKIPPED_PROPERTIES:
			continue
		var property_type: int = property.get("type", TYPE_NIL)
		if property_type in [TYPE_NODE_PATH, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
			continue
		var getter: StringName = ClassDB.class_get_property_getter(copy_class, property_name)
		var setter: StringName = ClassDB.class_get_property_setter(copy_class, property_name)
		if getter.is_empty() or setter.is_empty():
			continue
		if ClassDB.class_get_method_argument_count(copy_class, getter) != 0:
			continue
		var value: Variant = ClassDB.class_get_property(source, property_name)
		if value is Object and not value is Resource:
			continue
		if value is Resource:
			var resource: Resource = value
			if resource.get_script() != null or ClassDB.class_get_api_type(resource.get_class()) != ClassDB.API_CORE:
				_error = "Static thumbnail requires a native resource at '%s.%s'." % [source.name, property_name]
				return false
		var set_error: Error = ClassDB.class_set_property(copy, property_name, value)
		if set_error != OK:
			_error = "Static thumbnail could not copy '%s.%s'." % [source.name, property_name]
			return false
	if source is Control and copy is Control:
		# 布局 anchor/offset 使用带索引 getter；快照保存已解析的矩形，
		# 不读取源脚本或重建外部父布局。
		for property_name: StringName in [&"position", &"size", &"rotation", &"scale", &"pivot_offset"]:
			var value: Variant = ClassDB.class_get_property(source, property_name)
			var _set_layout: Error = ClassDB.class_set_property(copy, property_name, value)
	return true
