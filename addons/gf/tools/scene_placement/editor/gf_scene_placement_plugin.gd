@tool

## GFScenePlacementPlugin: Godot 原生注册的 3D 指针摆放子插件。
##
## 所有预览绘制由本插件拥有的 RenderingServer RID 完成，不向编辑场景添加预览节点。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFScenePlacementPlugin
extends EditorPlugin


# --- 私有变量 ---

var _panel: GFScenePlacementPanel = null
var _operation: GFScenePlacementOperation = null
var _scene_ref: WeakRef = null
var _options: Dictionary = {}
var _last_report: Dictionary = {}
var _preview_mesh: ImmediateMesh = null
var _preview_instance: RID = RID()
var _input_count: int = 0
var _editor_base_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	GFScenePlacementLauncher.notify_plugin_lifecycle(self, true)
	_editor_base_ref = weakref(EditorInterface.get_base_control())
	_panel = GFScenePlacementPanel.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)
	var _start_connected: int = _panel.placement_requested.connect(_on_placement_requested)
	var _cancel_connected: int = _panel.cancel_requested.connect(cancel_placement)
	var _parent_connected: int = _panel.parent_pick_requested.connect(_on_parent_pick_requested)
	var _configuration_connected: int = _panel.configuration_changed.connect(cancel_placement)
	var _close_connected: int = _panel.close_requested.connect(_on_close_requested)
	var _visibility_connected: int = _panel.visibility_changed.connect(_on_visibility_changed)
	var _scene_connected: int = scene_changed.connect(_on_scene_changed)
	set_input_event_forwarding_always_enabled()
	set_process(true)


func _process(_delta: float) -> void:
	if _operation == null:
		return
	if not _operation.is_destination_valid() or _get_scene_root() != EditorInterface.get_edited_scene_root():
		cancel_placement()
		_panel.show_status("场景或父节点已失效，请重新选择。")


func _exit_tree() -> void:
	GFScenePlacementLauncher.notify_plugin_lifecycle(self, false)
	cancel_placement()
	if is_instance_valid(_panel):
		remove_control_from_docks(_panel)
		_panel.queue_free()
	_panel = null
	_editor_base_ref = null
	_last_report.clear()


# --- Godot 回调方法 ---

func _get_plugin_name() -> String:
	return "GF Scene Placement"


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return process_pointer(camera, event)


# --- 框架内部方法 ---

## 获取当前原生侧栏；普通 GUT 不应实例化该插件。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 活动面板或 null。
func get_panel() -> GFScenePlacementPanel:
	return _panel


## 处理由 Godot 3D 编辑器转发的输入。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param camera: 当前 3D 编辑器视口相机。
## [br]
## @param event: 视口原生输入事件。
## [br]
## @return EditorPlugin.AfterGUIInput；非活动/导航事件保持 PASS。
func process_pointer(camera: Camera3D, event: InputEvent) -> int:
	_input_count += 1
	if _operation == null or not is_instance_valid(camera):
		return AFTER_GUI_INPUT_PASS
	if _get_scene_root() != EditorInterface.get_edited_scene_root() or not _operation.is_destination_valid():
		cancel_placement()
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
				cancel_placement()
				return AFTER_GUI_INPUT_STOP
			if key_event.keycode == KEY_ENTER or key_event.physical_keycode == KEY_ENTER:
				_confirm_placement()
				return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_RIGHT and button_event.pressed:
			cancel_placement()
			return AFTER_GUI_INPUT_STOP
		if button_event.button_index == MOUSE_BUTTON_LEFT and not button_event.alt_pressed:
			if button_event.pressed:
				_update_pointer(camera, button_event.position)
				_confirm_placement()
			return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if motion_event.alt_pressed or motion_event.button_mask != 0:
			return AFTER_GUI_INPUT_PASS
		_update_pointer(camera, motion_event.position)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


## 取消活动操作并释放所有临时绘制 RID。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func cancel_placement() -> void:
	if _operation != null:
		_operation.cancel()
	_operation = null
	_scene_ref = null
	_options.clear()
	_clear_preview()
	if is_instance_valid(_panel):
		_panel.show_status("预览已停止。修改参数后可重新开始。")


## 获取不含引擎对象的当前交互摘要。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 工具当前状态。
## [br]
## @schema return: Dictionary，包含 active/preview_visible: bool、state/input_count: int、last_error: int。
func get_snapshot() -> Dictionary:
	var last_error: int = OK
	var error_value: Variant = _last_report.get("error_code", OK)
	if error_value is int:
		last_error = error_value
	return {
		"active": _operation != null,
		"preview_visible": _preview_instance.is_valid(),
		"state": _operation.get_state() if _operation != null else GFEditorPickOperation.State.IDLE,
		"input_count": _input_count,
		"last_error": last_error,
	}


# --- 私有/辅助方法 ---

func _update_pointer(camera: Camera3D, position: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(position)
	var direction: Vector3 = camera.project_ray_normal(position)
	var input_data: Dictionary = { "ray_origin": origin, "ray_direction": direction }
	if _options.get("mode") == "surface":
		var world: World3D = camera.get_world_3d()
		var distance: float = 10000.0
		var distance_value: Variant = _options.get("max_distance")
		if distance_value is float:
			distance = distance_value
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + direction * distance, _panel.get_collision_mask()
		)
		query.collide_with_areas = false
		if world != null and world.direct_space_state != null:
			input_data["hit"] = world.direct_space_state.intersect_ray(query)
	var state: GFEditorPickOperation.State = _operation.pick(input_data)
	if state != GFEditorPickOperation.State.READY:
		_clear_preview()
		_panel.show_status("没有有效命中；平面需在射线前方，表面需有碰撞体。")
		return
	var preview: Dictionary = _operation.get_preview()
	var transform_value: Variant = preview.get("world_transform")
	if not transform_value is Transform3D:
		_clear_preview()
		return
	var world_transform: Transform3D = transform_value
	_draw_preview(camera, world_transform)
	_panel.show_status("左键 / Enter 确认；Esc / 右键取消。")


func _confirm_placement() -> void:
	if _operation == null or not _operation.can_apply():
		return
	var operation: GFScenePlacementOperation = _operation
	var report: Dictionary = operation.apply()
	if _operation != operation or not is_instance_valid(_panel):
		return
	_last_report = report
	var success_value: Variant = _last_report.get("ok")
	var succeeded: bool = success_value is bool and success_value == true
	if not succeeded:
		cancel_placement()
		_panel.show_status("摆放失败（错误码 %s）。" % _last_report.get("error_code", ERR_CANT_CREATE))
		return
	var node_value: Variant = _last_report.get("node")
	if node_value is Node3D and is_instance_valid(node_value):
		var node: Node3D = node_value
		var selection: EditorSelection = EditorInterface.get_selection()
		selection.clear()
		selection.add_node(node)
		EditorInterface.edit_node(node)
	cancel_placement()
	_panel.show_status("已摆放一个实例。使用编辑器 Undo / Redo 撤销或重做。")


func _draw_preview(camera: Camera3D, transform: Transform3D) -> void:
	if not _preview_instance.is_valid():
		_preview_mesh = ImmediateMesh.new()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.2, 0.8, 1.0)
		material.no_depth_test = true
		_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
		var bounds: AABB = AABB(-_panel.get_proxy_size() * 0.5, _panel.get_proxy_size())
		for axis: int in range(3):
			for corner: int in range(8):
				var paired: int = corner ^ (1 << axis)
				if corner < paired:
					_preview_mesh.surface_add_vertex(bounds.get_endpoint(corner))
					_preview_mesh.surface_add_vertex(bounds.get_endpoint(paired))
		_preview_mesh.surface_end()
		_preview_instance = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_preview_instance, _preview_mesh.get_rid())
	RenderingServer.instance_set_scenario(_preview_instance, camera.get_world_3d().scenario)
	RenderingServer.instance_set_transform(_preview_instance, transform)


func _clear_preview() -> void:
	if _preview_instance.is_valid():
		RenderingServer.free_rid(_preview_instance)
	_preview_instance = RID()
	_preview_mesh = null


func _get_scene_root() -> Node:
	if _scene_ref != null:
		var value: Variant = _scene_ref.get_ref()
		if value is Node:
			var root: Node = value
			return root
	return null


# --- 信号处理函数 ---

func _on_placement_requested() -> void:
	cancel_placement()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	_options = _panel.get_options()
	var error: Error = operation.configure(
		_panel.get_source_scene(), _panel.get_parent_node(), scene_root, _options
	)
	if error != OK:
		_last_report = { "ok": false, "error_code": error }
		_panel.show_status("无法开始：请选择 3D 场景及当前场景中的有效父节点，并检查参数。")
		return
	var context: GFEditorToolContext = GFEditorToolContext.from_plugin(self)
	if not operation.begin(context):
		_panel.show_status("无法开始拾取。")
		return
	_operation = operation
	_scene_ref = weakref(scene_root)
	_last_report.clear()
	_panel.show_status("移动 3D 视口指针预览；左键确认，Esc / 右键取消。")


func _on_parent_pick_requested() -> void:
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is Node3D:
		var parent: Node3D = selected[0]
		_panel.set_parent_node(parent)
	else:
		_panel.show_status("请在场景树中仅选择一个 Node3D，再点击此按钮。")


func _on_scene_changed(_scene_root: Node) -> void:
	cancel_placement()
	if is_instance_valid(_panel):
		_panel.set_parent_node(null)
		_panel.show_status("已切换场景，请重新选择父 Node3D。")


func _on_visibility_changed() -> void:
	if is_instance_valid(_panel) and not _panel.is_visible_in_tree():
		cancel_placement()


func _on_close_requested() -> void:
	cancel_placement()
	if _editor_base_ref == null:
		return
	var value: Variant = _editor_base_ref.get_ref()
	if value is Control:
		var editor_base: Control = value
		GFScenePlacementLauncher.request_plugin_close(editor_base)
