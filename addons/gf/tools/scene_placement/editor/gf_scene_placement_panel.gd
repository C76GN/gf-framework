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

## 当前显式选择的源场景资源。
## [br]
## @api private
## [br]
var _source: PackedScene = null

## 已选父节点的弱引用。
## [br]
## @api private
## [br]
var _parent_ref: WeakRef = null

## 显示源场景路径的只读输入控件。
## [br]
## @api private
## [br]
var _source_path: LineEdit = null

## 显示父节点路径的只读输入控件。
## [br]
## @api private
## [br]
var _parent_path: LineEdit = null

## 平面或表面摆放模式选择控件。
## [br]
## @api private
## [br]
var _mode: OptionButton = null

## 法线对齐选项控件。
## [br]
## @api private
## [br]
var _align: CheckBox = null

## 默认关闭的连续摆放选项控件。
## [br]
## @api private
## [br]
var _continuous: CheckBox = null

## 按参数名索引的 SpinBox 控件表。
## [br]
## @api private
## [br]
var _numbers: Dictionary[StringName, SpinBox] = {}

## 按参数名索引的三轴 SpinBox 控件表。
## [br]
## @api private
## [br]
var _vectors: Dictionary[StringName, Array] = {}

## 状态提示标签。
## [br]
## @api private
## [br]
var _status: Label = null

## 源场景选择对话框。
## [br]
## @api private
## [br]
var _file_dialog: FileDialog = null

## 摆放参数表单容器。
## [br]
## @api private
## [br]
var _fields: VBoxContainer = null


# --- Godot 生命周期方法 ---

## 设置侧栏标识与最小宽度，并立即构建参数表单和场景选择对话框。
## [br]
## @api private
func _init() -> void:
	name = "GFScenePlacementPanel"
	custom_minimum_size.x = 270.0
	_build_ui()


# --- 框架内部方法 ---

## 接收原生文件拖拽或宿主资源动作，只更新来源并取消旧预览，不开始摆放。
## [br]
## @api framework_internal
## [br]
## @param paths: 恰好一个项目内 PackedScene 路径。
## [br]
## @return 接收结果。
## [br]
## @schema return: Dictionary with ok, status and path.
func receive_resource_paths(paths: PackedStringArray) -> Dictionary:
	if paths.size() != 1:
		return {"ok": false, "status": "select_one_scene", "path": ""}
	var path: String = paths[0]
	if not path.begins_with("res://") or path.contains("..") or path.contains("::") or not ResourceLoader.exists(path):
		return {"ok": false, "status": "invalid_scene_path", "path": path}
	var resource: Resource = ResourceLoader.load(path)
	if not resource is PackedScene:
		return {"ok": false, "status": "not_packed_scene", "path": path}
	var scene: PackedScene = resource
	set_source_scene(scene)
	show_status("已接收场景；选择父 Node3D 后点击开始摆放。")
	return {"ok": true, "status": "source_selected", "path": path}


## 从 Godot 原生 files/resource 拖拽载荷提取有限的项目资源路径。
## [br]
## @api framework_internal
## [br]
## @param data: Godot 拖拽数据。
## [br]
## @schema data: Dictionary with type=files and files, or type=resource and resource.
## [br]
## @return 不超过一个项目路径，其他载荷返回空数组。
static func get_drag_resource_paths(data: Variant) -> PackedStringArray:
	if not data is Dictionary:
		return PackedStringArray()
	var payload: Dictionary = data
	var drag_type: Variant = payload.get("type")
	if drag_type == "resource":
		var resource_value: Variant = payload.get("resource")
		if resource_value is PackedScene:
			var scene: PackedScene = resource_value
			return PackedStringArray([scene.resource_path]) if scene.resource_path.begins_with("res://") else PackedStringArray()
	if drag_type == "files":
		var raw_paths: Variant = payload.get("files")
		if raw_paths is PackedStringArray:
			var paths: PackedStringArray = raw_paths
			if paths.size() == 1 and paths[0].begins_with("res://"):
				return paths.duplicate()
		elif raw_paths is Array:
			var values: Array = raw_paths
			if values.size() == 1 and values[0] is String:
				var path: String = values[0]
				if path.begins_with("res://"):
					return PackedStringArray([path])
	return PackedStringArray()


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


## 获取本次交互是否需要在成功确认后继续拾取。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 默认 false；此选项不属于单次 Operation 的 options。
func is_continuous_placement_enabled() -> bool:
	return _continuous.button_pressed


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


## 显示确认失败的原因、排查建议和原始诊断标识。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param report: GFScenePlacementOperation.apply 返回的失败报告。
## [br]
## @schema report: Dictionary，reason 接受 StringName/String，error_code 接受 int；未知原因使用通用建议，缺失或错误类型的错误码显示未知。
func show_placement_failure(report: Dictionary) -> void:
	var reason: String = ""
	var reason_value: Variant = report.get("reason")
	if reason_value is String:
		reason = reason_value
	elif reason_value is StringName:
		var reason_name: StringName = reason_value
		reason = String(reason_name)
	var error_text: String = "未知"
	var error_value: Variant = report.get("error_code")
	if error_value is int:
		error_text = str(error_value)
	var cause: String = "未能完成本次摆放。"
	var suggestion: String = "请检查编辑器输出、源场景和目标状态，再重新开始。"
	match reason:
		"undo_manager_required":
			cause = "缺少可用的编辑器撤销管理器。"
			suggestion = "请检查编辑器插件状态，再重新打开 3D 摆放工具。"
		"undo_manager_incompatible":
			cause = "撤销管理器不支持本次操作。"
			suggestion = "请检查编辑器插件与撤销管理器的兼容性。"
		"destination_unavailable":
			cause = "场景或父节点已失效。"
			suggestion = "请在当前场景重新选择父 Node3D，再开始摆放。"
		"invalid_transform":
			cause = "摆放变换无效。"
			suggestion = "请检查父节点缩放与摆放参数是否有效，再重新开始。"
		"creation_failed":
			cause = "未能创建场景实例。"
			suggestion = "请检查源场景及其工具脚本，并确认父节点仍可用。"
		"operation_interrupted":
			cause = "摆放在确认期间被中断。"
			suggestion = "请确认当前场景和父节点，检查工具脚本是否取消了操作，再重新开始。"
		"history_rejected":
			cause = "编辑器未接受本次撤销记录。"
			suggestion = "请检查当前场景与编辑器输出，再重新开始摆放。"
	var diagnostics: String = "错误码 %s" % error_text
	if not reason.is_empty():
		diagnostics += "；原因 %s" % reason
	show_status("摆放失败：%s\n建议：%s\n%s" % [cause, suggestion, diagnostics])


# --- 私有/辅助方法 ---

## 建立纯参数控件、操作按钮与项目场景文件选择器；参数变化统一发出使预览失效的信号。
## [br]
## @api private
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
	_source_path.tooltip_text = "拖入项目中的场景资源，或使用文件选择按钮。"
	_source_path.set_drag_forwarding(Callable(), _can_drop_scene, _drop_scene)
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
	_continuous = CheckBox.new()
	_continuous.name = "ContinuousPlacement"
	_continuous.text = "连续摆放"
	_continuous.tooltip_text = "每次确认后继续拾取；每个实例可独立撤销。Esc / 右键结束。"
	_fields.add_child(_continuous)
	var _continuous_connected: int = _continuous.toggled.connect(_on_configuration_changed.unbind(1))
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


## 在参数容器中添加标签和只读路径输入框。
## [br]
## @api private
## [br]
func _add_path(node_name: String, label_text: String) -> LineEdit:
	var label_node: Label = Label.new()
	label_node.text = label_text
	_fields.add_child(label_node)
	var field: LineEdit = LineEdit.new()
	field.name = node_name
	field.editable = false
	_fields.add_child(field)
	return field


## 创建指定名称和文本的按钮，并连接 pressed 回调。
## [br]
## @api private
## [br]
func _add_button(node_name: String, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	_fields.add_child(button)
	var _connected: int = button.pressed.connect(callback)


## 添加数值标签及 SpinBox，并按 key 保存控件引用。
## [br]
## @api private
## [br]
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


## 添加三轴 SpinBox 行，并按 key 保存控件数组。
## [br]
## @api private
## [br]
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


## 构造配置范围、初值和步长并连接变化信号的 SpinBox。
## [br]
## @api private
## [br]
func _new_number(key: StringName, value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.name = key
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	var _connected: int = field.value_changed.connect(_on_configuration_changed.unbind(1))
	return field


## 从指定三轴 SpinBox 控件读取 Vector3 值。
## [br]
## @api private
## [br]
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

func _can_drop_scene(_position: Vector2, data: Variant) -> bool:
	var paths: PackedStringArray = get_drag_resource_paths(data)
	return paths.size() == 1 and not paths[0].contains("..") and ResourceLoader.exists(paths[0], "PackedScene")


func _drop_scene(_position: Vector2, data: Variant) -> void:
	var report: Dictionary = receive_resource_paths(get_drag_resource_paths(data))
	if report.get("ok") != true:
		show_status("无法接收场景：%s" % str(report.get("status")))

## 打开已有场景选择对话框，不加载或实例化当前选择。
## [br]
## @api private
func _on_choose_scene() -> void:
	_file_dialog.popup_centered_ratio(0.7)


## 只接收项目内可加载的 PackedScene；失败显示提示，成功更新源场景并触发配置变化。
## [br]
## @api private
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


## 把参数控件变化转发为统一配置变化信号，由插件取消已有预览。
## [br]
## @api private
func _on_configuration_changed() -> void:
	configuration_changed.emit()
