@tool

# 只能由隔离工程启用，验证真实 EditorPlugin、指针入口与 EditorUndoRedoManager。
extends EditorPlugin


# --- 常量 ---

const _FIXTURE_ROOT: String = "res://tests/gf_core/tools/scene_placement/fixtures/"
const _SCENE_A: String = _FIXTURE_ROOT + "placement_scene_a.tscn"
const _SCENE_B: String = _FIXTURE_ROOT + "placement_scene_b.tscn"
const _ASSET: String = _FIXTURE_ROOT + "placement_asset.tscn"
const _SCRIPTED_ASSET: String = _FIXTURE_ROOT + "placement_scripted_asset.tscn"
const _SAVED_SCENE: String = "res://scene_placement_saved.tscn"
const _CANARY_KEY: StringName = &"gf_placement_canary_instances"
const _PLUGIN_NAME: String = "gf/tools/scene_placement"
const _DEADLINE_MSEC: int = 90000


# --- 私有变量 ---

var _phase: StringName = &"startup"
var _deadline: int = 0
var _frames: int = 0
var _finished: bool = false
var _assertions: int = 0
var _results: Dictionary = {}
var _placement_plugin: GFScenePlacementPlugin = null
var _panel: GFScenePlacementPanel = null
var _scene: Node3D = null
var _parent: Node3D = null
var _camera: Camera3D = null
var _history: UndoRedo = null
var _scene_history_id: int = 0
var _native_node: Node3D = null
var _native_node_id: int = 0
var _expected_world: Transform3D = Transform3D.IDENTITY
var _pointer_world: Vector3 = Vector3.ZERO
var _pointer_position: Vector2 = Vector2.ZERO
var _parent_count: int = 0
var _mesh_count: int = 0
var _plugin_ref: WeakRef = null
var _panel_ref: WeakRef = null
var _native_viewport: SubViewport = null
var _native_input_before: int = 0
var _launcher: GFScenePlacementLauncher = null
var _launcher_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_deadline = Time.get_ticks_msec() + _DEADLINE_MSEC
	Engine.set_meta(_CANARY_KEY, 0)
	var connect_error: int = get_tree().process_frame.connect(_on_frame)
	if connect_error != OK:
		_fail("Cannot observe the native editor lifecycle.")


func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.disconnect(_on_frame)
	Engine.remove_meta(_CANARY_KEY)


# --- 私有/辅助方法 ---

func _startup() -> void:
	if not _require(Engine.is_editor_hint(), "The fixture requires a real editor."):
		return
	var private_root: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	if not _require(not private_root.is_empty() and private_root.is_absolute_path(), "The private smoke root was not supplied."):
		return
	for directory: String in [OS.get_data_dir(), OS.get_config_dir(), OS.get_cache_dir(), OS.get_user_data_dir()]:
		var normalized: String = directory.replace("\\", "/").simplify_path()
		if not _require(normalized.to_lower().begins_with(private_root.to_lower() + "/"), "Native Godot data/config/cache/user directory escaped the smoke root: " + normalized):
			return
	_results["native_private_directories_verified"] = true
	for candidate: Node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate is GFScenePlacementPlugin:
			_placement_plugin = candidate
			break
	if not _require(_placement_plugin != null, "The declared native scene placement plugin was not activated."):
		return
	_panel = _placement_plugin.get_panel()
	if not _require(_panel != null and _panel.is_inside_tree(), "The native placement panel is missing."):
		return
	_phase = &"scene_a"
	EditorInterface.open_scene_from_path(_SCENE_A)


func _wait_scene_a() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_A:
		return
	_phase = &"running"
	_scene = _node_3d(root)
	if not _require(_scene != null, "Scene A must expose a 3D root."):
		return
	_parent = _node_3d(_scene.get_node_or_null(^"PlacementParent"))
	var camera_value: Node = _scene.get_node_or_null(^"PointerCamera")
	if not _require(_parent != null and camera_value is Camera3D, "Scene A is missing its parent or pointer camera."):
		return
	if camera_value is Camera3D:
		_camera = camera_value
	_camera.current = true
	var manager: EditorUndoRedoManager = get_undo_redo()
	_scene_history_id = manager.get_object_history_id(_scene)
	_history = manager.get_history_undo_redo(_scene_history_id)
	if not _require(_scene_history_id > 0 and _history != null, "The actual edited scene did not receive a native history."):
		return
	_results["scene_history_id"] = _scene_history_id
	_run_native_operation_cases()


func _run_native_operation_cases() -> void:
	var parent_count: int = _parent.get_child_count()
	var history_version: int = _history.get_version()
	var rejected: GFScenePlacementOperation = _operation(_SCRIPTED_ASSET)
	if rejected == null:
		return
	if not _require(rejected.pick(_ray(Vector3(3.0, 10.0, 4.0))) == GFEditorPickOperation.State.READY, "Scripted source preview did not become ready."):
		return
	if not _require(_canary_count() == 0 and _parent.get_child_count() == parent_count and _history.get_version() == history_version, "Preview instantiated a source script, changed the scene, or wrote history."):
		return
	rejected.cancel()
	if not _require(not rejected.can_apply() and _canary_count() == 0, "Cancellation executed source code or left a ready operation."):
		return
	rejected = null
	var anchor: Vector3 = Vector3(1.0, 0.5, -2.0)
	var operation: GFScenePlacementOperation = _operation(_ASSET, {
		"anchor": anchor, "yaw_degrees": 90.0, "scale": Vector3(2.0, 3.0, 4.0),
	})
	if operation == null:
		return
	if not _require(operation.pick(_ray(Vector3(5.0, 10.0, 7.0))) == GFEditorPickOperation.State.READY, "Native placement did not produce a ready preview."):
		return
	_expected_world = _transform(operation.get_preview(), "world_transform")
	if not _require((_expected_world * anchor).is_equal_approx(Vector3(5.0, 0.0, 7.0)), "The transformed explicit local anchor missed the plane hit."):
		return
	_parent.position += Vector3(2.0, 3.0, 4.0)
	var applied: Dictionary = operation.apply()
	if not _require(_bool(applied, "ok"), "Native manager confirmation failed: " + str(applied)):
		return
	_native_node = _node_3d(applied.get("node"))
	if not _require(_native_node != null, "Native confirmation did not expose the actual created node."):
		return
	_native_node_id = _native_node.get_instance_id()
	if not _require(_native_node.get_parent() == _parent and _native_node.owner == _scene, "The created instance has wrong parent or scene owner."):
		return
	if not _require(_native_node.global_transform.is_equal_approx(_expected_world), "Confirmation did not recompute local space after the non-unit parent moved."):
		return
	if not _require(_history.get_version() != history_version and _parent.get_child_count() == parent_count + 1, "Confirmation did not create exactly one native action and instance."):
		return
	var operation_ref: WeakRef = weakref(operation)
	operation = null
	if not _require(operation_ref.get_ref() == null, "Native history retained the interactive operation/context."):
		return
	if not _require(_history.undo() and _native_node.get_parent() == null and _parent.get_child_count() == parent_count, "Native undo did not remove the instance."):
		return
	if not _require(_history.redo() and _native_node.get_instance_id() == _native_node_id and _native_node.get_parent() == _parent, "Native redo did not reattach the same instance."):
		return
	if not _require(_native_node.owner == _scene and _native_node.global_transform.is_equal_approx(_expected_world), "Redo lost the saved owner or world transform."):
		return
	if not _save_and_reload():
		return
	_results["native_undo_redo_anchor_parent_transform_save_reload"] = true
	_begin_native_forward()


func _begin_native_forward() -> void:
	EditorInterface.set_main_screen_editor("3D")
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(0)
	if not _press("StartPlacement"):
		return
	_native_viewport = EditorInterface.get_editor_viewport_3d(0)
	if not _require(_native_viewport != null, "The actual editor 3D SubViewport is unavailable."):
		return
	_results["editor_viewport_path"] = str(_native_viewport.get_path())
	_native_input_before = _int(_placement_plugin.get_snapshot(), "input_count")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(_native_viewport.size) * 0.5
	_native_viewport.push_input(motion, true)
	_phase = &"native_forward_wait"
	_frames = 0


func _check_native_forward() -> void:
	_phase = &"running"
	if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
		_results["native_input_route"] = "Editor 3D SubViewport.push_input"
	else:
		var container_root: Node = _native_viewport.get_parent().get_parent()
		var candidates: Array[String] = []
		for node: Node in container_root.find_children("*", "Control", true, false):
			if not node is Control:
				continue
			var control: Control = node
			for connection: Dictionary in control.get_signal_connection_list(&"gui_input"):
				var callback_value: Variant = connection.get("callable")
				if not callback_value is Callable:
					continue
				var callback: Callable = callback_value
				var receiver: Object = callback.get_object()
				if not is_instance_valid(receiver):
					continue
				candidates.append("%s -> %s.%s" % [control.get_path(), receiver.get_class(), callback.get_method()])
				if not String(receiver.get_class()).contains("Node3DEditorViewport"):
					continue
				var motion: InputEventMouseMotion = InputEventMouseMotion.new()
				motion.position = control.size * 0.5
				control.gui_input.emit(motion)
				if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
					_results["native_input_route"] = "Registered editor Control.gui_input -> native Node3DEditorViewport -> plugin forwarding"
					break
			if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
				break
		_results["editor_gui_connections"] = candidates
	if not _require(_int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before, "Native editor GUI input did not reach the registered _forward_3d_gui_input callback."):
		return
	if not _require(_bool(_placement_plugin.get_snapshot(), "preview_visible"), "Forwarded editor input did not create a visible preview candidate."):
		return
	_results["native_gui_forwarded"] = true
	_phase = &"native_render_wait"
	_frames = 0


func _complete_native_forward() -> void:
	_phase = &"running"
	var image_directory: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR")
	if not image_directory.is_empty():
		RenderingServer.force_draw(false)
		var texture: Texture2D = _native_viewport.get_texture()
		var frame: Image = texture.get_image() if texture != null else null
		if not _require(frame != null and not frame.is_empty(), "The rendered native editor viewport returned no image."):
			return
		var image_path: String = image_directory.path_join("scene_placement_preview.png")
		if not _require(frame.save_png(image_path) == OK, "Could not save the native placement preview image."):
			return
		_results["rendered_preview_image"] = image_path
	_placement_plugin.cancel_placement()
	_begin_pointer_plane()


func _begin_pointer_plane() -> void:
	_panel.set_source_scene(_load_scene(_SCRIPTED_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(0)
	_parent_count = _parent.get_child_count()
	_mesh_count = _scene.find_children("*", "MeshInstance3D", true, false).size()
	if not _press("StartPlacement"):
		return
	_pointer_position = _camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = _camera.project_ray_origin(_pointer_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(_pointer_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if not _require(hit is Vector3, "Fixture camera does not point at the placement plane."):
		return
	if hit is Vector3:
		_pointer_world = hit
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var consumed: int = _placement_plugin.process_pointer(_camera, move)
	if not _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Active native pointer motion bypassed the placement route."):
		return
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	if not _require(_bool(snapshot, "active") and _bool(snapshot, "preview_visible"), "Valid pointer input did not display the native preview proxy."):
		return
	if not _require(_parent.get_child_count() == _parent_count and _canary_count() == 0, "Pointer preview instantiated the scripted source."):
		return
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	var cancel_consumed: int = _placement_plugin.process_pointer(_camera, escape)
	if not _require(cancel_consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Escape did not cancel active placement."):
		return
	var cancelled: Dictionary = _placement_plugin.get_snapshot()
	if not _require(not _bool(cancelled, "active") and not _bool(cancelled, "preview_visible"), "Cancellation retained an active or visible preview."):
		return
	_phase = &"cancel_settle"
	_frames = 0


func _after_cancel() -> void:
	_phase = &"running"
	if not _require(_scene.find_children("*", "MeshInstance3D", true, false).size() == _mesh_count, "Cancelled preview left a mesh in the edited scene."):
		return
	var clicked: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(clicked == EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == _parent_count and _canary_count() == 0, "A late click after cancel created an instance or executed a script."):
		return
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	if not _press("StartPlacement"):
		return
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var _motion_consumed: int = _placement_plugin.process_pointer(_camera, move)
	var confirm_consumed: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(confirm_consumed != EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == _parent_count + 1, "Native left click did not confirm exactly one placement."):
		return
	var created: Node3D = _last_placed_child()
	if not _require(created != null and created.global_position.is_equal_approx(_pointer_world), "Pointer confirmation did not use the camera-derived world hit."):
		return
	if not _require(_history.undo() and _parent.get_child_count() == _parent_count, "Pointer-created action was not routed to the current scene native history."):
		return
	_results["native_pointer_plane_cancel_and_confirm"] = true
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(1)
	if not _press("StartPlacement"):
		return
	_phase = &"surface_wait"
	_frames = 0


func _surface_pointer() -> void:
	_phase = &"running"
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var consumed: int = _placement_plugin.process_pointer(_camera, move)
	if not _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Surface pointer motion bypassed the tool."):
		return
	if not _require(_bool(_placement_plugin.get_snapshot(), "preview_visible"), "The real editor collision world did not yield a visible surface candidate."):
		return
	var before: int = _parent.get_child_count()
	var confirmed: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(confirmed != EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == before + 1, "Actual editor world ray did not hit StaticBody3D/CollisionShape3D for surface placement."):
		return
	var created: Node3D = _last_placed_child()
	if not _require(created != null and absf(created.global_position.y) < 0.001 and created.global_position.distance_to(_pointer_world) < 0.01, "Surface placement did not land on the fixture's real floor collision."):
		return
	if not _require(_history.undo() and _parent.get_child_count() == before, "Surface confirmation did not produce a reversible native action."):
		return
	_results["actual_editor_world_collision_surface"] = true
	_set_mode(0)
	_panel.set_source_scene(_load_scene(_SCRIPTED_ASSET))
	_panel.set_parent_node(_parent)
	if not _press("StartPlacement"):
		return
	var _preview_consumed: int = _placement_plugin.process_pointer(_camera, move)
	_phase = &"scene_b"
	EditorInterface.open_scene_from_path(_SCENE_B)


func _wait_scene_b() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_B:
		return
	_phase = &"running"
	var manager: EditorUndoRedoManager = get_undo_redo()
	var second_id: int = manager.get_object_history_id(root)
	if not _require(second_id > 0 and second_id != _scene_history_id, "Two opened scenes did not receive distinct native histories."):
		return
	var second_parent: Node3D = _node_3d(root.get_node_or_null(^"PlacementParent"))
	var second_camera_value: Node = root.get_node_or_null(^"PointerCamera")
	if not _require(second_parent != null and second_camera_value is Camera3D, "Scene B fixture is incomplete."):
		return
	var second_camera: Camera3D = null
	if second_camera_value is Camera3D:
		second_camera = second_camera_value
	var children_before: int = second_parent.get_child_count()
	var response: int = _placement_plugin.process_pointer(second_camera, _left_click())
	if not _require(response == EditorPlugin.AFTER_GUI_INPUT_PASS and second_parent.get_child_count() == children_before and _canary_count() == 0, "A scene switch retained an armed pointer operation from the previous scene."):
		return
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	if not _require(not _bool(snapshot, "active") and not _bool(snapshot, "preview_visible"), "Scene switching retained the previous preview proxy."):
		return
	_results["scene_switch_cancels_stale_pointer"] = true
	_results["second_scene_history_id"] = second_id
	_phase = &"return_scene_a"
	EditorInterface.open_scene_from_path(_SCENE_A)


func _return_scene_a() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_A:
		return
	_phase = &"running"
	_plugin_ref = weakref(_placement_plugin)
	_panel_ref = weakref(_panel)
	if not _press("ClosePlacementPlugin"):
		return
	_placement_plugin = null
	_panel = null
	_phase = &"unload_settle"
	_frames = 0


func _after_unload() -> void:
	_phase = &"running"
	if not _require(_plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Plugin disable did not release the plugin and panel."):
		return
	if not _require(_history.redo(), "History could not replay after the placement plugin was unloaded."):
		return
	if not _require(_history.undo(), "History could not undo after the placement plugin was unloaded."):
		return
	if not _require(_native_node.get_instance_id() == _native_node_id and _native_node.global_transform.is_equal_approx(_expected_world), "Unloading the plugin altered the earlier committed instance."):
		return
	_results["unloaded_plugin_history_replay"] = true
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	if not _capture_launched_plugin():
		return
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher.set_editor_context(null)
	_phase = &"independent_context_clear_settle"
	_frames = 0


func _after_independent_context_clear() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_survives_context_clear"] = true
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	_launcher.free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_replacement_settle"
	_frames = 0


func _after_independent_replacement() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_survives_page_replacement"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _press_launcher("CloseScenePlacement"):
		return
	if not _open_launcher():
		return
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_open_settle"
	_frames = 0


func _after_independent_open() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_open_does_not_claim_ownership"] = true
	_results["independent_plugin_close_then_open_preserves_child"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _press_launcher("CloseScenePlacement"):
		return
	_phase = &"independent_close_settle"
	_frames = 0


func _after_independent_close() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Explicit launcher Close did not release the independently enabled plugin and panel."):
		return
	_results["independent_plugin_explicit_close_releases_child"] = true
	_launcher.queue_free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher_ref = weakref(_launcher)
	if not _open_launcher():
		return
	_phase = &"launcher_open_settle"
	_frames = 0


func _open_launcher() -> bool:
	return _press_launcher("OpenScenePlacement")


func _press_launcher(button_name: String) -> bool:
	var button_node: Node = _launcher.get_node_or_null(NodePath(button_name))
	if not _require(button_node is Button, "The launcher has no native plugin control: " + button_name):
		return false
	if button_node is Button:
		var control_button: Button = button_node
		control_button.pressed.emit()
	return true


func _require_independent_plugin() -> bool:
	return _require(
		EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() != null and _panel_ref.get_ref() != null,
		"A launcher lifecycle change closed the independently enabled plugin or replaced its native panel."
	)


func _capture_launched_plugin() -> bool:
	var launched_plugin: GFScenePlacementPlugin = null
	for candidate: Node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate is GFScenePlacementPlugin:
			launched_plugin = candidate
			break
	if not _require(EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and launched_plugin != null, "Launcher activation did not create an engine-owned plugin."):
		return false
	var launched_panel: GFScenePlacementPanel = launched_plugin.get_panel()
	if not _require(launched_panel != null and launched_panel.is_inside_tree(), "Launcher activation did not attach the native placement panel."):
		return false
	_plugin_ref = weakref(launched_plugin)
	_panel_ref = weakref(launched_panel)
	return true


func _after_launcher_open() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_launcher.set_editor_context(null)
	_phase = &"launcher_context_clear_settle"
	_frames = 0


func _after_launcher_context_clear() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Clearing launcher context did not disable and release the child plugin and panel."):
		return
	_results["launcher_context_clear_releases_child"] = true
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	if not _open_launcher():
		return
	_phase = &"launcher_reopen_settle"
	_frames = 0


func _after_launcher_reopen() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_launcher.queue_free()
	_launcher = null
	_phase = &"launcher_exit_settle"
	_frames = 0


func _after_launcher_exit() -> void:
	_phase = &"running"
	if not _require(_launcher_ref.get_ref() == null and not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Destroying the launcher did not release the native child plugin and panel."):
		return
	_results["launcher_exit_releases_child"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher() or not _capture_launched_plugin():
		return
	_launcher.set_editor_context(null)
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	if not _capture_launched_plugin():
		return
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_reenable_settle"
	_frames = 0


func _after_independent_reenable() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_reenabled_plugin_survives_old_owner"] = true
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)
	_phase = &"independent_reenable_cleanup_settle"
	_frames = 0


func _after_independent_reenable_cleanup() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "The independent re-enable fixture did not release its native plugin and panel."):
		return
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher():
		return
	_launcher.free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher():
		return
	_phase = &"launcher_replacement_settle"
	_frames = 0


func _after_launcher_replacement() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_results["launcher_same_frame_replacement_preserves_child"] = true
	if not _require(_launcher.is_inside_tree() and EditorInterface.is_plugin_enabled(_PLUGIN_NAME), "The editor exit probe must retain an active launcher and child plugin until shutdown."):
		return
	_results["launcher_left_enabled_for_editor_exit"] = true
	_phase = &"finish_settle"
	_frames = 0


func _save_and_reload() -> bool:
	var packed: PackedScene = PackedScene.new()
	if not _require(packed.pack(_scene) == OK and ResourceSaver.save(packed, _SAVED_SCENE) == OK, "The placed scene could not be saved to isolated output."):
		return false
	var reloaded: PackedScene = _load_scene(_SAVED_SCENE)
	if reloaded == null:
		return false
	var clone: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not _require(clone is Node3D, "Saved scene reload has the wrong root type."):
		if clone != null:
			clone.free()
		return false
	var cloned_parent: Node3D = _node_3d(clone.get_node_or_null(^"PlacementParent"))
	var cloned_node: Node3D = null
	if cloned_parent != null:
		cloned_node = _node_3d(cloned_parent.get_node_or_null(NodePath(String(_native_node.name))))
	var valid: bool = _require(cloned_parent != null and cloned_node != null, "Saved scene omitted the placed instance.")
	if valid:
		valid = _require((cloned_parent.transform * cloned_node.transform).is_equal_approx(_expected_world), "Save/reload changed the placed transform under a non-unit parent.")
		valid = _require(cloned_node.owner == clone, "Saved scene did not preserve owner routing.") and valid
	clone.free()
	return valid


func _operation(path: String, options: Dictionary = {}) -> GFScenePlacementOperation:
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	if not _require(operation.configure(_load_scene(path), _parent, _scene, options) == OK, "Could not configure the native placement operation."):
		return null
	if not _require(operation.begin(GFEditorToolContext.from_plugin(self)), "Could not begin native placement with editor context."):
		return null
	return operation


func _load_scene(path: String) -> PackedScene:
	var loaded: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var _valid: bool = _require(loaded is PackedScene, "Expected a saved PackedScene: " + path)
	if loaded is PackedScene:
		var scene: PackedScene = loaded
		return scene
	return null


func _set_mode(index: int) -> void:
	var node: Node = _panel.find_child("PlacementMode", true, false)
	var _valid: bool = _require(node is OptionButton, "Placement mode control is missing.")
	if node is OptionButton:
		var picker: OptionButton = node
		picker.select(index)
		picker.item_selected.emit(index)


func _press(name_value: String) -> bool:
	var node: Node = _panel.find_child(name_value, true, false)
	var _valid: bool = _require(node is Button, "Missing placement control: " + name_value)
	if node is Button:
		var button: Button = node
		if not _require(not button.disabled, "Placement control is unexpectedly disabled: " + name_value):
			return false
		button.pressed.emit()
		return true
	return false


func _left_click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _pointer_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _ray(origin: Vector3) -> Dictionary:
	return { "ray_origin": origin, "ray_direction": Vector3.DOWN }


func _node_3d(value: Variant) -> Node3D:
	if value is Node3D:
		var node: Node3D = value
		return node
	return null


func _last_placed_child() -> Node3D:
	if _parent.get_child_count() == 0:
		return null
	return _node_3d(_parent.get_child(_parent.get_child_count() - 1))


func _transform(report: Dictionary, key: String) -> Transform3D:
	var value: Variant = report.get(key)
	if value is Transform3D:
		var transform_value: Transform3D = value
		return transform_value
	_fail("Missing or wrongly typed transform: " + key)
	return Transform3D.IDENTITY


func _bool(report: Dictionary, key: String) -> bool:
	var value: Variant = report.get(key)
	if value is bool:
		var boolean: bool = value
		return boolean
	_fail("Missing or wrongly typed bool: " + key)
	return false


func _int(report: Dictionary, key: String) -> int:
	var value: Variant = report.get(key)
	if value is int:
		var integer: int = value
		return integer
	_fail("Missing or wrongly typed int: " + key)
	return -1


func _canary_count() -> int:
	var value: Variant = Engine.get_meta(_CANARY_KEY, -1)
	if value is int:
		var count: int = value
		return count
	return -1


func _require(condition: bool, message: String) -> bool:
	_assertions += 1
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_FAILED " + message)
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_DETAILS " + JSON.stringify(_results))
	get_tree().quit(1)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_results["assertions"] = _assertions
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_OK " + JSON.stringify(_results))
	get_tree().quit(0)


# --- 信号处理函数 ---

func _on_frame() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() > _deadline:
		_fail("Editor smoke exceeded its deadline in phase " + String(_phase))
		return
	_frames += 1
	match _phase:
		&"startup":
			if _frames >= 12:
				_phase = &"running"
				_startup()
		&"scene_a":
			_wait_scene_a()
		&"native_forward_wait":
			if _frames >= 3:
				_check_native_forward()
		&"native_render_wait":
			if _frames >= 6:
				_complete_native_forward()
		&"cancel_settle":
			if _frames >= 5:
				_after_cancel()
		&"surface_wait":
			if _frames >= 12:
				_surface_pointer()
		&"scene_b":
			_wait_scene_b()
		&"return_scene_a":
			_return_scene_a()
		&"unload_settle":
			if _frames >= 8:
				_after_unload()
		&"independent_context_clear_settle":
			if _frames >= 8:
				_after_independent_context_clear()
		&"independent_replacement_settle":
			if _frames >= 8:
				_after_independent_replacement()
		&"independent_open_settle":
			if _frames >= 8:
				_after_independent_open()
		&"independent_close_settle":
			if _frames >= 8:
				_after_independent_close()
		&"launcher_open_settle":
			if _frames >= 8:
				_after_launcher_open()
		&"launcher_context_clear_settle":
			if _frames >= 8:
				_after_launcher_context_clear()
		&"launcher_reopen_settle":
			if _frames >= 8:
				_after_launcher_reopen()
		&"launcher_exit_settle":
			if _frames >= 8:
				_after_launcher_exit()
		&"independent_reenable_settle":
			if _frames >= 8:
				_after_independent_reenable()
		&"independent_reenable_cleanup_settle":
			if _frames >= 8:
				_after_independent_reenable_cleanup()
		&"launcher_replacement_settle":
			if _frames >= 8:
				_after_launcher_replacement()
		&"finish_settle":
			if _frames >= 8:
				_finish()
