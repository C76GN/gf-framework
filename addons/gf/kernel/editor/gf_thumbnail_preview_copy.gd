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
const _MAX_SURFACE_MATERIAL_SLOTS: int = 4096


# --- 私有变量 ---

var _error: String = ""
var _node_count: int = 0
var _surface_material_slot_count: int = 0


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
	_surface_material_slot_count = 0
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
		_error = "Static thumbnail does not support native node '%s' (%s)." % [source.get_name(), native_class]
		return null
	var created: Variant = ClassDB.instantiate(copy_class)
	if not created is Node:
		if created is Object and not created is RefCounted:
			var invalid_object: Object = created
			invalid_object.free()
		_error = "Static thumbnail could not create native node '%s'." % copy_class
		return null
	var copy: Node = created
	var source_name: StringName = source.get_name()
	if not source_name.is_empty():
		copy.name = source_name
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
	# _get_property_list 会执行；ClassDB 的索引 getter 也会经过脚本分派。
	# 常规属性只访问无参原生 getter，索引视觉属性另用固定原生方法。
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
			if not _validate_native_resource(resource, source, property_name):
				return false
		var set_error: Error = ClassDB.class_set_property(copy, property_name, value)
		if set_error != OK:
			_error = "Static thumbnail could not copy '%s.%s'." % [source.get_name(), property_name]
			return false
	_copy_indexed_visual_properties(source, copy)
	if source is MeshInstance3D and copy is MeshInstance3D:
		var mesh_source: MeshInstance3D = source
		var mesh_copy: MeshInstance3D = copy
		if not _copy_surface_materials(mesh_source, mesh_copy):
			return false
	if source is Control and copy is Control:
		# 布局 anchor/offset 使用带索引 getter；快照保存已解析的矩形，
		# 不读取源脚本或重建外部父布局。
		for property_name: StringName in [&"position", &"size", &"rotation", &"scale", &"pivot_offset"]:
			var value: Variant = ClassDB.class_get_property(source, property_name)
			var _set_layout: Error = ClassDB.class_set_property(copy, property_name, value)
	return true


func _copy_indexed_visual_properties(source: Node, copy: Node) -> void:
	# 固定原生类型的方法调用绑定到 native MethodBind，不使用源节点 call/get。
	if source is NinePatchRect and copy is NinePatchRect:
		var patch_source: NinePatchRect = source
		var patch_copy: NinePatchRect = copy
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			patch_copy.set_patch_margin(side, patch_source.get_patch_margin(side))
	if source is TextureProgressBar and copy is TextureProgressBar:
		var progress_source: TextureProgressBar = source
		var progress_copy: TextureProgressBar = copy
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			progress_copy.set_stretch_margin(side, progress_source.get_stretch_margin(side))
	if source is SpriteBase3D and copy is SpriteBase3D:
		var sprite_source: SpriteBase3D = source
		var sprite_copy: SpriteBase3D = copy
		for flag_index: int in SpriteBase3D.FLAG_MAX:
			var flag: SpriteBase3D.DrawFlags = flag_index as SpriteBase3D.DrawFlags
			sprite_copy.set_draw_flag(flag, sprite_source.get_draw_flag(flag))
	if source is Label3D and copy is Label3D:
		var label_source: Label3D = source
		var label_copy: Label3D = copy
		for flag_index: int in Label3D.FLAG_MAX:
			var flag: Label3D.DrawFlags = flag_index as Label3D.DrawFlags
			label_copy.set_draw_flag(flag, label_source.get_draw_flag(flag))
	if source is Light3D and copy is Light3D:
		var light_source: Light3D = source
		var light_copy: Light3D = copy
		for param_index: int in Light3D.PARAM_MAX:
			var param: Light3D.Param = param_index as Light3D.Param
			light_copy.set_param(param, light_source.get_param(param))


func _copy_surface_materials(source: MeshInstance3D, copy: MeshInstance3D) -> bool:
	# 每表面覆盖是 MeshInstance3D 的原生动态属性，不能枚举来源的 property list。
	var surface_count: int = source.get_surface_override_material_count()
	if surface_count > _MAX_SURFACE_MATERIAL_SLOTS - _surface_material_slot_count:
		_error = "Static thumbnail exceeded its surface material slot limit at '%s'." % source.get_name()
		return false
	_surface_material_slot_count += surface_count
	for surface_index: int in surface_count:
		var material: Material = source.get_surface_override_material(surface_index)
		if material == null:
			continue
		var property_name: StringName = StringName("surface_material_override/%d" % surface_index)
		if not _validate_native_resource(material, source, property_name):
			return false
		copy.set_surface_override_material(surface_index, material)
	return true


func _validate_native_resource(resource: Resource, source: Node, property_name: StringName) -> bool:
	if resource.get_script() != null or ClassDB.class_get_api_type(resource.get_class()) != ClassDB.API_CORE:
		_error = "Static thumbnail requires a native resource at '%s.%s'." % [source.get_name(), property_name]
		return false
	return true
