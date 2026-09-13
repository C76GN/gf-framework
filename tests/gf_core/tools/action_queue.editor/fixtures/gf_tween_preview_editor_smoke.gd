@tool

# 真实 EditorPlugin 生命周期下验证非 tool 资源字段与原生 Tween 构造。
extends EditorPlugin


# --- 常量 ---

const _INSPECTOR_PLUGIN_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_preview_inspector_plugin.gd")
const _SCENE_PATH: String = "res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_scene.tscn"
const _CONFIG_PATH: String = "res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_saved_config.tres"
const _RELOAD_PATH: String = "user://gf_tween_preview_reloaded.tres"
const _CURVE_RELOAD_PATH: String = "user://gf_tween_preview_curve_reloaded.tres"
const _DEADLINE_MSEC: int = 60000


# --- 私有变量 ---

var _deadline: int = 0
var _stable_frames: int = 0
var _finished: bool = false
var _phase: StringName = &"probe"
var _source: Resource = null
var _reloaded: Resource = null
var _inspector_plugin: EditorInspectorPlugin = null
var _old_panel: WeakRef = null
var _old_target: WeakRef = null
var _current_panel: WeakRef = null
var _current_target: WeakRef = null
var _render_panel: WeakRef = null
var _render_index: int = 0
var _render_wait_frames: int = 0
var _scene_history: UndoRedo = null
var _source_history: UndoRedo = null
var _scene_history_version: int = 0
var _source_history_version: int = 0
var _scene_digest: String = ""
var _config_digest: String = ""


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_deadline = Time.get_ticks_msec() + _DEADLINE_MSEC
	var connect_error: Error = get_tree().process_frame.connect(_on_process_frame) as Error
	if connect_error != OK:
		_fail("Cannot observe editor process frames.")


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if get_tree().process_frame.is_connected(_on_process_frame):
		get_tree().process_frame.disconnect(_on_process_frame)


# --- 私有/辅助方法 ---

func _run_probe() -> void:
	if not Engine.is_editor_hint():
		_fail("The probe requires a real editor lifecycle.")
		return
	_scene_digest = FileAccess.get_sha256(_SCENE_PATH)
	_config_digest = FileAccess.get_sha256(_CONFIG_PATH)
	if _scene_digest.is_empty() or _config_digest.is_empty():
		_fail("The original scene and configuration file digests were unavailable.")
		return
	var source: Resource = ResourceLoader.load(_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _validate_saved_fields(source):
		return
	var save_error: Error = ResourceSaver.save(source, _RELOAD_PATH)
	if save_error != OK:
		_fail("Saving the loaded configuration failed: %d" % save_error)
		return
	var reloaded: Resource = ResourceLoader.load(_RELOAD_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _validate_saved_fields(reloaded):
		return
	var target: Node2D = Node2D.new()
	add_child(target)
	var target_ref: WeakRef = weakref(target)
	var tween: Tween = create_tween()
	tween.pause()
	var tweener: PropertyTweener = GFTweenActionStep.append_property_tweener(
		tween, target, ^"position:x", 16.0, 0.5, 0.25,
		false, false, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
	)
	if tweener == null:
		tween.kill()
		target.free()
		_fail("Static Step builder did not return a native PropertyTweener.")
		return
	var first_running: bool = tween.custom_step(0.5)
	var midpoint: float = target.position.x
	var final_running: bool = tween.custom_step(0.5)
	var endpoint: float = target.position.x
	var loops_left: int = tween.get_loops_left()
	var settled_running: bool = tween.custom_step(0.0)
	tween.kill()
	target.free()
	if not first_running or loops_left != 0 or settled_running or not is_equal_approx(midpoint, 8.0) or not is_equal_approx(endpoint, 16.0):
		_fail("Native Tween delay/duration mismatch: first_running=%s final_running=%s loops_left=%d settled_running=%s midpoint=%.9f endpoint=%.9f" % [first_running, final_running, loops_left, settled_running, midpoint, endpoint])
		return
	if target_ref.get_ref() != null:
		_fail("The native probe target survived explicit cleanup.")
		return
	if not _probe_curve():
		return
	_begin_inspector_smoke(source, reloaded)


func _probe_curve() -> bool:
	var source: Resource = ResourceLoader.load(_CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if source == null:
		_fail("The curve probe could not load its independent configuration.")
		return false
	var steps_value: Variant = source.get(&"steps")
	if not steps_value is Array:
		_fail("The curve probe configuration had no steps.")
		return false
	var steps: Array = steps_value
	if steps.size() != 1 or not steps[0] is Resource:
		_fail("The curve probe configuration did not contain one resource step.")
		return false
	var source_step: Resource = steps[0]
	var source_curve: Curve = Curve.new()
	source_curve.bake_resolution = 101
	var _first_point: int = source_curve.add_point(
		Vector2.ZERO, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR
	)
	var _middle_point: int = source_curve.add_point(
		Vector2(0.5, 0.75), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR
	)
	var _last_point: int = source_curve.add_point(
		Vector2.ONE, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR
	)
	source.set(&"duration_scale", 1.0)
	source_step.set(&"duration", 1.0)
	source_step.set(&"delay", 0.0)
	source_step.set(&"property_name", ^"position:x")
	source_step.set(&"target_value", 16.0)
	source_step.set(&"transition_type", Tween.TRANS_QUAD)
	source_step.set(&"ease_type", Tween.EASE_IN)
	source_step.set(&"easing_curve", source_curve)
	var save_error: Error = ResourceSaver.save(source, _CURVE_RELOAD_PATH)
	if save_error != OK:
		_fail("Saving the curve probe configuration failed: %d" % save_error)
		return false
	var reloaded: Resource = ResourceLoader.load(_CURVE_RELOAD_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if reloaded == null or reloaded.get_script() != source.get_script():
		_fail("The curve probe lost its non-tool configuration script after reloading.")
		return false
	var reloaded_steps_value: Variant = reloaded.get(&"steps")
	if not reloaded_steps_value is Array:
		_fail("The reloaded curve probe had no steps.")
		return false
	var reloaded_steps: Array = reloaded_steps_value
	if reloaded_steps.size() != 1 or not reloaded_steps[0] is Resource:
		_fail("The reloaded curve probe lost its one resource step.")
		return false
	var reloaded_step: Resource = reloaded_steps[0]
	var reloaded_curve_value: Variant = reloaded_step.get(&"easing_curve")
	if not reloaded_curve_value is Curve:
		_fail("The saved easing_curve field did not reload as a native Curve.")
		return false
	var reloaded_curve: Curve = reloaded_curve_value
	if (
		reloaded_step.get_script() != source_step.get_script()
		or not _number_equals(reloaded.get(&"duration_scale"), 1.0)
		or not _number_equals(reloaded_step.get(&"duration"), 1.0)
		or not _number_equals(reloaded_step.get(&"delay"), 0.0)
		or reloaded_curve == source_curve or reloaded_curve.get_script() != null
		or reloaded_curve.get_point_count() != 3 or reloaded_curve.bake_resolution != 101
		or reloaded_curve.get_point_position(1) != Vector2(0.5, 0.75)
	):
		_fail("Reloading the curve probe changed its fields or retained the original curve identity.")
		return false
	var saved_digest: String = FileAccess.get_sha256(_CURVE_RELOAD_PATH)
	var probe_root: Node = Node.new()
	add_child(probe_root)
	var preview: GFTweenPreviewViewport = GFTweenPreviewViewport.new()
	probe_root.add_child(preview)
	preview.configure(reloaded)
	var preview_ref: WeakRef = weakref(preview)
	var target: Node = preview.find_child("PreviewTarget", true, false)
	var target_ref: WeakRef = weakref(target) if target != null else null
	var probe_error: String = _check_curve_preview(preview, reloaded_curve)
	preview.dispose_preview()
	probe_root.free()
	if preview_ref.get_ref() != null or (target_ref != null and target_ref.get_ref() != null):
		_fail("The independent curve preview or its target survived explicit cleanup.")
		return false
	if not probe_error.is_empty():
		_fail(probe_error)
		return false
	if saved_digest.is_empty() or FileAccess.get_sha256(_CURVE_RELOAD_PATH) != saved_digest:
		_fail("Curve preview playback or seeking changed its saved configuration file.")
		return false
	if source_curve.get_point_position(1) != Vector2(0.5, 0.75):
		_fail("Editing the reloaded curve also changed the original resource.")
		return false
	return true


func _check_curve_preview(preview: GFTweenPreviewViewport, source_curve: Curve) -> String:
	if not preview.play():
		return "The saved curve configuration could not start in the real editor: " + preview.get_error()
	preview.advance(0.5)
	if not is_equal_approx(_position_x(preview), 12.0):
		return "Native editor preview did not use the saved curve instead of preset/composed easing."
	if not preview.seek(0.5) or preview.get_state() != &"paused":
		return "The native curve preview did not accept time inspection."
	if not is_equal_approx(_position_x(preview), 12.0):
		return "Native curve seeking disagreed with forward playback."
	source_curve.set_point_value(1, 0.25)
	if not preview.seek(0.25) or not preview.seek(0.5):
		return "Source curve editing invalidated an already captured inspection session."
	if not is_equal_approx(_position_x(preview), 12.0):
		return "Source curve editing changed the old seek snapshot."
	preview.stop()
	if not preview.play() or not preview.seek(0.5):
		return "A new curve playback did not capture the edited resource."
	if not is_equal_approx(_position_x(preview), 4.0):
		return "New playback ignored the edited source curve."
	if not preview.seek(1.0) or not is_equal_approx(_position_x(preview), 16.0):
		return "The native curve preview did not preserve its exact endpoint."
	return ""


func _begin_inspector_smoke(source: Resource, reloaded: Resource) -> void:
	_source = source
	_reloaded = reloaded
	GFExtensionSettings.set_enabled_extension_ids(["gf.action_queue"])
	if not GFExtensionSettings.is_extension_enabled("gf.action_queue"):
		_fail("The fixture did not enable the action_queue extension.")
		return
	if source.get_script() != preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd"):
		_fail("Reloaded configuration lost its canonical script identity.")
		return
	_inspector_plugin = _INSPECTOR_PLUGIN_SCRIPT.new()
	add_inspector_plugin(_inspector_plugin)
	_phase = &"scene"
	EditorInterface.open_scene_from_path(_SCENE_PATH)


func _wait_scene() -> void:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != _SCENE_PATH:
		return
	if not _scene_unchanged():
		return
	var undo_manager: EditorUndoRedoManager = get_undo_redo()
	_scene_history = undo_manager.get_history_undo_redo(undo_manager.get_object_history_id(scene))
	_source_history = undo_manager.get_history_undo_redo(undo_manager.get_object_history_id(_source))
	if _scene_history == null or _source_history == null:
		_fail("Native scene and resource histories were unavailable.")
		return
	_scene_history_version = _scene_history.get_version()
	_source_history_version = _source_history.get_version()
	_phase = &"first"
	EditorInterface.edit_resource(_source)


func _wait_first_panel() -> void:
	var panel: GFTweenPreviewPanel = _find_panel()
	if panel == null:
		return
	var preview: GFTweenPreviewViewport = _find_viewport(panel)
	if preview == null:
		return
	panel.set_process(false)
	if not _check_controls(panel, preview):
		return
	if OS.get_environment("GF_TWEEN_PREVIEW_SMOKE_RENDERED") == "1":
		_render_panel = weakref(panel)
		_render_index = 0
		_begin_render_sample(panel)
		_phase = &"render"
		return
	_begin_resource_switch(panel)


func _begin_resource_switch(panel: GFTweenPreviewPanel) -> void:
	var preview: GFTweenPreviewViewport = _find_viewport(panel)
	if preview == null:
		return
	_old_panel = weakref(panel)
	var target: Node = panel.find_child("PreviewTarget", true, false)
	if target == null:
		_fail("The first Inspector panel did not own an isolated target.")
		return
	_old_target = weakref(target)
	if not _press(panel, "Reset") or not _press(panel, "Play"):
		return
	preview.advance(0.5)
	_phase = &"second"
	EditorInterface.edit_resource(_reloaded)


func _begin_render_sample(panel: GFTweenPreviewPanel) -> void:
	var raw_kind: Node = panel.find_child("TargetKind", true, false)
	if not raw_kind is OptionButton:
		_fail("The rendered sample lost its target selector.")
		return
	var target_kind: OptionButton = raw_kind
	target_kind.select(_render_index)
	target_kind.item_selected.emit(_render_index)
	var preview: GFTweenPreviewViewport = _find_viewport(panel)
	if preview == null or not _press(panel, "Play"):
		return
	var time_control: Node = panel.find_child("PreviewTimeInput", true, false)
	if not time_control is SpinBox:
		_fail("The rendered sample lost its time input.")
		return
	var time_input: SpinBox = time_control
	var sample_time: float = 0.325 if _render_index == 2 else 1.375
	var expected_position: float = 0.8 if _render_index == 2 else 12.0
	time_input.value = sample_time
	if (
		preview.get_state() != &"paused" or not is_equal_approx(preview.get_time_seconds(), sample_time)
		or not is_equal_approx(_position_x(preview), expected_position)
	):
		_fail("The rendered sample did not seek through its native time input.")
		return
	_render_wait_frames = 3


func _wait_render_sample() -> void:
	_render_wait_frames -= 1
	if _render_wait_frames > 0:
		return
	var raw_panel: Variant = _render_panel.get_ref()
	if not raw_panel is GFTweenPreviewPanel:
		_fail("The rendered sample panel was freed before capture.")
		return
	var panel: GFTweenPreviewPanel = raw_panel
	var preview: GFTweenPreviewViewport = _find_viewport(panel)
	if preview == null:
		return
	var texture: ViewportTexture = preview.get_texture()
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_fail("The rendered sample produced an empty image.")
		return
	if not _has_visible_sample_pixel(image):
		_fail("The rendered sample did not contain an opaque blue sample within its image budget.")
		return
	var image_directory: String = OS.get_environment("GF_TWEEN_PREVIEW_SMOKE_IMAGE_DIR")
	if image_directory.is_empty():
		_fail("The runner did not provide an owned image output directory.")
		return
	var image_path: String = image_directory.path_join("sample_%d.png" % _render_index)
	var save_error: Error = image.save_png(image_path)
	if save_error != OK:
		_fail("The rendered sample image could not be saved: %d" % save_error)
		return
	if _render_index == 2 and not _save_panel_image(panel, image_directory):
		return
	_render_index += 1
	if _render_index < 3:
		_begin_render_sample(panel)
		return
	_render_panel = null
	_begin_resource_switch(panel)


func _has_visible_sample_pixel(image: Image) -> bool:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width > 2048 or height > 2048:
		return false
	# 三种自有样机都使用蓝色；黑色、灰色或透明清屏不能冒充目标实际可见。
	for y: int in range(height):
		for x: int in range(width):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a >= 0.95 and pixel.b > 0.05 and pixel.b > pixel.r + 0.03:
				return true
	return false


func _save_panel_image(panel: GFTweenPreviewPanel, image_directory: String) -> bool:
	var panel_image: Image = panel.get_viewport().get_texture().get_image()
	if panel_image == null or panel_image.is_empty():
		_fail("The Inspector window produced no image for its time controls.")
		return false
	var image_bounds: Rect2i = Rect2i(Vector2i.ZERO, panel_image.get_size())
	var crop_bounds: Rect2i = Rect2i(panel.get_global_rect()).intersection(image_bounds)
	if not crop_bounds.has_area():
		_fail("The Inspector preview panel was outside its rendered viewport.")
		return false
	var cropped: Image = panel_image.get_region(crop_bounds)
	var save_error: Error = cropped.save_png(image_directory.path_join("panel.png"))
	if save_error != OK:
		_fail("The Inspector preview panel image could not be saved: %d" % save_error)
		return false
	return true


func _wait_second_panel() -> void:
	var panel: GFTweenPreviewPanel = _find_panel()
	if panel == null or panel == _old_panel.get_ref():
		return
	if _old_panel.get_ref() != null or _old_target.get_ref() != null:
		return
	var preview: GFTweenPreviewViewport = _find_viewport(panel)
	if preview == null:
		return
	panel.set_process(false)
	if preview.get_state() != &"idle" or not _press(panel, "Play"):
		_fail("Resource switching did not produce an idle, playable panel.")
		return
	preview.advance(0.5)
	_current_panel = weakref(panel)
	var target: Node = panel.find_child("PreviewTarget", true, false)
	if target == null:
		_fail("The replacement panel did not own an isolated target.")
		return
	_current_target = weakref(target)
	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null
	if not preview.get_current_values().is_empty() or panel.is_processing():
		_fail("Inspector plugin unloading left its preview session active.")
		return
	EditorInterface.edit_resource(Resource.new())
	_phase = &"cleanup"


func _wait_cleanup() -> void:
	if _current_panel.get_ref() != null or _current_target.get_ref() != null:
		return
	if not _scene_unchanged() or not _validate_saved_fields(_source) or not _validate_saved_fields(_reloaded):
		return
	if FileAccess.get_sha256(_SCENE_PATH) != _scene_digest or FileAccess.get_sha256(_CONFIG_PATH) != _config_digest:
		_fail("Preview playback or seeking changed an original scene or configuration file.")
		return
	if _scene_history.get_version() != _scene_history_version or _source_history.get_version() != _source_history_version:
		_fail("Preview operations changed native scene or resource undo history.")
		return
	_scene_history = null
	_source_history = null
	_source = null
	_reloaded = null
	_finished = true
	print("GF_TWEEN_PREVIEW_EDITOR_SMOKE_OK")
	get_tree().call_deferred(&"quit", 0)


func _check_controls(panel: GFTweenPreviewPanel, preview: GFTweenPreviewViewport) -> bool:
	if preview.get_state() != &"idle" or not _press(panel, "Play"):
		_fail("The saved configuration did not start through the Play button.")
		return false
	preview.advance(0.5)
	var first_position: float = _position_x(preview)
	if not first_position > 0.0 or not first_position < 16.0:
		_fail("The Inspector preview did not advance from its initial position.")
		return false
	if not _press(panel, "Pause"):
		return false
	preview.advance(10.0)
	if preview.get_state() != &"paused" or not is_equal_approx(_position_x(preview), first_position):
		_fail("Pause did not freeze the Inspector preview.")
		return false
	if not _press(panel, "Play"):
		return false
	preview.advance(0.25)
	var resumed_position: float = _position_x(preview)
	if resumed_position <= first_position or not _press(panel, "Stop"):
		_fail("Resume did not continue the paused preview.")
		return false
	preview.advance(10.0)
	if preview.get_state() != &"idle" or not is_equal_approx(_position_x(preview), resumed_position):
		_fail("Stop did not preserve the current preview frame.")
		return false
	if not _check_time_controls(panel, preview):
		return false
	if not _press(panel, "Reset") or not is_zero_approx(_position_x(preview)):
		_fail("Reset did not restore the preview baseline.")
		return false
	if not _press(panel, "Play"):
		return false
	preview.advance(0.5)
	panel.hide()
	if preview.get_state() != &"idle" or not is_zero_approx(_position_x(preview)):
		_fail("Hiding the Inspector panel did not reset its preview.")
		return false
	panel.show()
	var raw_kind: Node = panel.find_child("TargetKind", true, false)
	if not raw_kind is OptionButton:
		_fail("The Inspector target selector was unavailable.")
		return false
	var target_kind: OptionButton = raw_kind
	for kind: int in [1, 2, 0]:
		target_kind.select(kind)
		target_kind.item_selected.emit(kind)
		if preview.get_state() != &"idle" or not _press(panel, "Play"):
			_fail("Changing target kind did not create a playable isolated target.")
			return false
		preview.advance(0.5)
		if _position_x(preview) <= 0.0:
			_fail("The selected target kind did not animate.")
			return false
		if not _press(panel, "Reset"):
			return false
	return _scene_unchanged()


func _check_time_controls(panel: GFTweenPreviewPanel, preview: GFTweenPreviewViewport) -> bool:
	var slider_node: Node = panel.find_child("PreviewTimeSlider", true, false)
	var input_node: Node = panel.find_child("PreviewTimeInput", true, false)
	if not slider_node is HSlider or not input_node is SpinBox:
		_fail("The Inspector preview did not expose its native time controls.")
		return false
	var slider: HSlider = slider_node
	var time_input: SpinBox = input_node
	if not slider.editable or not is_equal_approx(slider.max_value, 1.75):
		_fail("The native time slider did not show the captured timeline duration.")
		return false
	slider.value = 0.625
	if preview.get_state() != &"paused" or not is_equal_approx(_position_x(preview), 4.0):
		_fail("Slider input did not locate the captured timeline and pause.")
		return false
	time_input.value = 1.0
	if not is_equal_approx(_position_x(preview), 8.0):
		_fail("The numeric time input did not locate the expected native property value.")
		return false
	slider.value = 0.625
	if not _press(panel, "InspectTime") or not is_equal_approx(_position_x(preview), 4.0):
		_fail("Backward and repeated time inspection did not reproduce the native property value.")
		return false
	slider.value = slider.max_value
	if preview.get_state() != &"paused" or not is_equal_approx(_position_x(preview), 16.0):
		_fail("The exact timeline endpoint did not preserve its final native property value.")
		return false
	if not _press(panel, "Play") or preview.get_state() != &"finished":
		_fail("Continuing an inspected endpoint did not complete the captured session.")
		return false
	if not _press(panel, "Reset"):
		return false
	slider.value_changed.emit(0.625)
	time_input.value_changed.emit(1.0)
	if preview.has_session() or not is_zero_approx(_position_x(preview)):
		_fail("Retired timeline controls could mutate the reset preview.")
		return false
	return _scene_unchanged()


func _scene_unchanged() -> bool:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if not scene is Node2D:
		_fail("The real edited scene was replaced or freed.")
		return false
	var target: Node2D = scene
	if target.position != Vector2(77.0, -19.0) or target.rotation != 0.25 or target.scale != Vector2(2.0, 3.0):
		_fail("The preview changed the real edited scene target.")
		return false
	return true


func _find_panel() -> GFTweenPreviewPanel:
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var candidate: Node = inspector.find_child("TweenPreviewPanel", true, false)
	if candidate is GFTweenPreviewPanel:
		var panel: GFTweenPreviewPanel = candidate
		return panel
	return null


func _find_viewport(panel: GFTweenPreviewPanel) -> GFTweenPreviewViewport:
	var candidate: Node = panel.find_child("PreviewViewport", true, false)
	if candidate is GFTweenPreviewViewport:
		var preview: GFTweenPreviewViewport = candidate
		return preview
	_fail("The Inspector panel is missing its preview viewport.")
	return null


func _press(panel: GFTweenPreviewPanel, control_name: String) -> bool:
	var candidate: Node = panel.find_child(control_name, true, false)
	if not candidate is Button:
		_fail("Missing Inspector control: " + control_name)
		return false
	var button: Button = candidate
	if button.disabled:
		_fail("Inspector control is unexpectedly disabled: " + control_name)
		return false
	button.pressed.emit()
	return true


func _position_x(preview: GFTweenPreviewViewport) -> float:
	var raw_position: Variant = preview.get_current_values().get("position")
	if raw_position is Vector2:
		var position: Vector2 = raw_position
		return position.x
	if raw_position is Vector3:
		var position: Vector3 = raw_position
		return position.x
	_fail("The preview did not expose a native position value.")
	return NAN


func _validate_saved_fields(config: Resource) -> bool:
	if config == null or not _number_equals(config.get(&"duration_scale"), 2.0):
		_fail("Saved configuration duration_scale was not preserved.")
		return false
	var raw_steps: Variant = config.get(&"steps")
	if not raw_steps is Array:
		_fail("Saved configuration steps are not an Array.")
		return false
	var steps: Array = raw_steps
	if steps.size() != 1 or not steps[0] is Resource:
		_fail("Saved configuration must contain its one Step resource.")
		return false
	var step: Resource = steps[0]
	if not _number_equals(step.get(&"duration"), 0.75) or not _number_equals(step.get(&"delay"), 0.125):
		_fail("Saved Step duration and delay were not preserved.")
		return false
	return true


func _number_equals(value: Variant, expected: float) -> bool:
	if value is float:
		var number: float = value
		return is_finite(number) and is_equal_approx(number, expected)
	return false


func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	push_error("GF_TWEEN_PREVIEW_EDITOR_SMOKE_FAILED: " + message)
	get_tree().call_deferred(&"quit", 1)


# --- 信号处理函数 ---

func _on_process_frame() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() > _deadline:
		_fail("Editor smoke exceeded its deadline in phase: %s" % _phase)
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		_stable_frames = 0
		return
	_stable_frames += 1
	if _stable_frames < 5:
		return
	match _phase:
		&"probe":
			_run_probe()
		&"scene":
			_wait_scene()
		&"first":
			_wait_first_panel()
		&"second":
			_wait_second_panel()
		&"render":
			_wait_render_sample()
		&"cleanup":
			_wait_cleanup()
