@tool

## GFScenePlacementPanel: 原生 3D 编辑器摆放侧栏。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFScenePlacementPanel
extends VBoxContainer


# --- 信号 ---

## 用户请求开始一次摆放。
## [br]
## @api framework_internal
signal placement_requested

## 用户请求取消当前预览。
## [br]
## @api framework_internal
signal cancel_requested

## 用户显式选择当前编辑器所选节点作为父节点。
## [br]
## @api framework_internal
signal parent_pick_requested

## 配置变化使已有预览失效。
## [br]
## @api framework_internal
signal configuration_changed

## 用户关闭独立摆放插件。
## [br]
## @api framework_internal
signal close_requested


# --- 私有变量 ---

var _source: PackedScene = null
var _parent_ref: WeakRef = null
var _source_path: LineEdit = null
var _parent_path: LineEdit = null
var _mode: OptionButton = null
var _align: CheckBox = null
var _numbers: Dictionary[StringName, SpinBox] = {}
var _vectors: Dictionary[StringName, Array] = {}
var _status: Label = null
var _file_dialog: FileDialog = null
var _fields: VBoxContainer = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GFScenePlacementPanel"
	custom_minimum_size.x = 270.0
	_build_ui()


# --- 框架内部方法 ---

## 设置显式选择的源场景，不生成预览实例。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param scene: 源场景；null 清除选择。
func set_source_scene(scene: PackedScene) -> void:
	_source = scene
	_source_path.text = scene.resource_path if scene != null else ""
	if scene != null and scene.resource_path.is_empty():
		_source_path.text = "[PackedScene]"
	configuration_changed.emit()


## 设置用户显式选择的父节点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param parent: 父节点；null 清除选择。
func set_parent_node(parent: Node3D) -> void:
	_parent_ref = weakref(parent) if is_instance_valid(parent) else null
	_parent_path.text = str(parent.get_path()) if is_instance_valid(parent) and parent.is_inside_tree() else ""
	configuration_changed.emit()


## 获取源场景。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 当前显式选择的场景。
func get_source_scene() -> PackedScene:
	return _source


## 获取仍存活的父节点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 父节点或 null。
func get_parent_node() -> Node3D:
	if _parent_ref != null:
		var value: Variant = _parent_ref.get_ref()
		if value is Node3D:
			var parent: Node3D = value
			return parent
	return null


## 读取当前纯值摆放参数。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return GFScenePlacementOperation.configure 的 options。
## [br]
## @schema return: Dictionary，包含 mode、plane_normal、plane_origin、grid_step、align_normal、anchor、yaw_degrees、scale、surface_offset、max_distance。
func get_options() -> Dictionary:
	return {
		"mode": "plane" if _mode.selected == 0 else "surface",
		"plane_normal": _get_vector(&"PlaneNormal"),
		"plane_origin": _get_vector(&"PlaneOrigin"),
		"grid_step": _numbers[&"GridStep"].value,
		"align_normal": _align.button_pressed,
		"anchor": _get_vector(&"LocalAnchor"),
		"yaw_degrees": _numbers[&"YawDegrees"].value,
		"scale": _get_vector(&"PlacementScale"),
		"surface_offset": _numbers[&"SurfaceOffset"].value,
		"max_distance": _numbers[&"MaxDistance"].value,
	}


## 获取用户声明的线框代理尺寸。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 源根本地空间的代理尺寸，不是实际模型 bounds。
func get_proxy_size() -> Vector3:
	return _get_vector(&"ProxySize")


## 获取碰撞查询掩码。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 原生 PhysicsRayQueryParameters3D 的 collision_mask。
func get_collision_mask() -> int:
	return int(_numbers[&"CollisionMask"].value)


## 更新操作提示。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param message: 当前操作的用户提示。
func show_status(message: String) -> void:
	_status.text = message


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var title: Label = Label.new()
	title.text = "3D 场景摆放"
	add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 360.0
	add_child(scroll)
	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_source_path = _add_path("SourceScenePath", "PackedScene")
	_add_button("ChooseScene", "选择场景…", _on_choose_scene)
	_parent_path = _add_path("ParentNodePath", "父 Node3D")
	_add_button("UseSelectedParent", "使用当前所选 Node3D", parent_pick_requested.emit)
	_mode = OptionButton.new()
	_mode.name = "PlacementMode"
	_mode.add_item("平面")
	_mode.add_item("碰撞表面")
	_fields.add_child(_mode)
	var _mode_connected: int = _mode.item_selected.connect(_on_configuration_changed.unbind(1))
	_add_vector(&"PlaneNormal", "平面法线", Vector3.UP)
	_add_vector(&"PlaneOrigin", "平面 / 网格原点", Vector3.ZERO)
	_add_number(&"GridStep", "切向网格（0 关闭）", 0.0, 0.0, 1000000.0)
	_align = CheckBox.new()
	_align.name = "AlignNormal"
	_align.text = "局部 Y 轴对齐命中法线"
	_fields.add_child(_align)
	var _align_connected: int = _align.toggled.connect(_on_configuration_changed.unbind(1))
	_add_number(&"YawDegrees", "偏航（度）", 0.0, -1000000.0, 1000000.0)
	_add_vector(&"PlacementScale", "局部缩放倍数", Vector3.ONE)
	_add_vector(&"LocalAnchor", "源根本地锚点", Vector3.ZERO)
	_add_number(&"SurfaceOffset", "沿法线偏移", 0.0, -1000000.0, 1000000.0)
	_add_vector(&"ProxySize", "线框代理尺寸", Vector3.ONE, 0.001)
	_add_number(&"MaxDistance", "最大拾取距离", 10000.0, 0.001, 100000.0)
	_add_number(&"CollisionMask", "碰撞掩码", 4294967295.0, 1.0, 4294967295.0, 1.0)
	var note: Label = Label.new()
	note.text = "线框是尺寸代理。确认会实例化所选场景。\n开始后移动 3D 视口指针，左键确认；Esc / 右键取消。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fields.add_child(note)
	_add_button("StartPlacement", "开始摆放", placement_requested.emit)
	_add_button("CancelPlacement", "取消预览", cancel_requested.emit)
	_add_button("ClosePlacementPlugin", "关闭摆放工具", close_requested.emit)
	_status = Label.new()
	_status.name = "PlacementStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "请选择源场景和当前场景中的父 Node3D。"
	add_child(_status)
	_file_dialog = FileDialog.new()
	_file_dialog.name = "SceneFileDialog"
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.tscn,*.scn ; PackedScene"])
	add_child(_file_dialog)
	var _file_connected: int = _file_dialog.file_selected.connect(_on_scene_file_selected)


func _add_path(node_name: String, label_text: String) -> LineEdit:
	var label_node: Label = Label.new()
	label_node.text = label_text
	_fields.add_child(label_node)
	var field: LineEdit = LineEdit.new()
	field.name = node_name
	field.editable = false
	_fields.add_child(field)
	return field


func _add_button(node_name: String, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	_fields.add_child(button)
	var _connected: int = button.pressed.connect(callback)


func _add_number(
	key: StringName, label_text: String, value: float,
	minimum: float, maximum: float, step: float = 0.1
) -> void:
	var label_node: Label = Label.new()
	label_node.text = label_text
	_fields.add_child(label_node)
	var field: SpinBox = _new_number(key, value, minimum, maximum, step)
	_numbers[key] = field
	_fields.add_child(field)


func _add_vector(key: StringName, label_text: String, value: Vector3, minimum: float = -1000000.0) -> void:
	var label_node: Label = Label.new()
	label_node.text = label_text
	_fields.add_child(label_node)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = key
	_fields.add_child(row)
	var fields: Array[SpinBox] = []
	for axis: int in range(3):
		var field: SpinBox = _new_number("XYZ"[axis], value[axis], minimum, 1000000.0, 0.1)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		fields.append(field)
	_vectors[key] = fields


func _new_number(key: StringName, value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.name = key
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	var _connected: int = field.value_changed.connect(_on_configuration_changed.unbind(1))
	return field


func _get_vector(key: StringName) -> Vector3:
	var fields: Array = _vectors[key]
	var result: Vector3 = Vector3.ZERO
	for axis: int in range(3):
		var field_value: Variant = fields[axis]
		if field_value is SpinBox:
			var field: SpinBox = field_value
			result[axis] = field.value
	return result


# --- 信号处理函数 ---

func _on_choose_scene() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_scene_file_selected(path: String) -> void:
	if not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
		show_status("请选择项目内的 PackedScene。")
		return
	var resource: Resource = ResourceLoader.load(path, "PackedScene")
	if resource is PackedScene:
		var scene: PackedScene = resource
		set_source_scene(scene)
	else:
		show_status("所选资源不是 PackedScene。")


func _on_configuration_changed() -> void:
	configuration_changed.emit()
