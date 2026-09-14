# 独立真实渲染验收；通过受管 Godot 进程以 --script 启动，不在 headless GUT 中计为绘图证据。
extends SceneTree


# --- 常量 ---

const _IMAGE_SIZE: Vector2i = Vector2i(256, 256)
const _OUTLINE_SAMPLE: Rect2i = Rect2i(48, 38, 12, 4)
const _GRID_SAMPLE: Rect2i = Rect2i(94, 80, 4, 8)
const _PLACEMENT_SAMPLE: Rect2i = Rect2i(164, 38, 12, 4)
const _DRAG_SAMPLE: Rect2i = Rect2i(44, 150, 16, 4)


# --- 私有变量 ---

var _viewport: SubViewport = null
var _failures: PackedStringArray = PackedStringArray()
var _observations: Dictionary = {}


# --- Godot 生命周期方法 ---

func _initialize() -> void:
	_run.call_deferred()


# --- 私有/辅助方法 ---

func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_video_adapter_name().is_empty():
		_record_failure("A real rendering backend is required; headless output is not visual evidence.")
		_finish()
		return
	_viewport = SubViewport.new()
	_viewport.size = _IMAGE_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var canvas: GFSpatialCanvas2D = GFSpatialCanvas2D.new()
	canvas.size = Vector2(_IMAGE_SIZE)
	_viewport.add_child(canvas)
	var configured: bool = canvas.set_view(Vector2(128.0, 128.0), 1.0)
	configured = canvas.configure_grid(Vector2.ZERO, Vector2(32.0, 32.0), { "visible": false }) and configured
	configured = canvas.upsert_item(&"selected", Rect2(40.0, 40.0, 32.0, 32.0)) and configured
	if not configured or canvas.set_selection(PackedStringArray(["selected"])) != PackedStringArray(["selected"]):
		_record_failure("The owned canvas fixture could not establish its selected item.")
		_finish()
		return
	var default_frame: Image = await _capture_frame("default")
	if default_frame == null:
		_finish()
		return
	_expect_visible(default_frame, _OUTLINE_SAMPLE, "default_outline")
	_expect_clear(default_frame, Rect2i(48, 48, 8, 8), "outline_interior")
	if not canvas.has_method("set_selected_item_outlines_visible"):
		_record_failure("The selected item is drawn, but no public option can hide only its outline.")
		_finish()
		return
	var _hidden: Variant = canvas.call("set_selected_item_outlines_visible", false)
	var hidden_frame: Image = await _capture_frame("hidden")
	if hidden_frame == null:
		_finish()
		return
	_expect_clear(hidden_frame, _OUTLINE_SAMPLE, "hidden_outline")
	var _shown: Variant = canvas.call("set_selected_item_outlines_visible", true)
	var restored_frame: Image = await _capture_frame("restored")
	if restored_frame == null:
		_finish()
		return
	_expect_visible(restored_frame, _OUTLINE_SAMPLE, "restored_outline")
	if canvas.get_selection() != PackedStringArray(["selected"]):
		_record_failure("Changing outline visibility changed the selected IDs.")
	var grid_configured: bool = canvas.configure_grid(
		Vector2.ZERO, Vector2(32.0, 32.0), { "visible": true }
	)
	var placement_id: int = canvas.begin_placement(
		&"preview",
		Rect2(0.0, 0.0, 32.0, 32.0),
		{ "initial_world_position": Vector2(152.0, 40.0), "snap_to_grid": false }
	)
	if not grid_configured or placement_id <= 0:
		_record_failure("The grid and placement fixture could not be established.")
		_finish()
		return
	var overlays_frame: Image = await _capture_frame("overlays_visible")
	if overlays_frame == null:
		_finish()
		return
	_expect_visible(overlays_frame, _GRID_SAMPLE, "grid_before_hide")
	_expect_visible(overlays_frame, _PLACEMENT_SAMPLE, "placement_before_hide")
	var _hidden_with_overlays: Variant = canvas.call("set_selected_item_outlines_visible", false)
	var hidden_overlays_frame: Image = await _capture_frame("overlays_hidden")
	if hidden_overlays_frame == null:
		_finish()
		return
	_expect_clear(hidden_overlays_frame, _OUTLINE_SAMPLE, "outline_hidden_with_overlays")
	_expect_visible(hidden_overlays_frame, _GRID_SAMPLE, "grid_after_hide")
	_expect_visible(hidden_overlays_frame, _PLACEMENT_SAMPLE, "placement_after_hide")
	if not canvas.has_active_placement():
		_record_failure("Hiding selected-item outlines canceled the placement session.")
	var _cancel_report: Dictionary = canvas.cancel_placement()
	var press: InputEventMouseButton = _mouse_button(Vector2(24.0, 152.0), true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(104.0, 224.0)
	if (
		canvas.handle_input_event(press) != GFSpatialCanvas2D.InputDisposition.CONSUMED
		or canvas.handle_input_event(motion) != GFSpatialCanvas2D.InputDisposition.CONSUMED
	):
		_record_failure("Hidden selected-item outlines prevented drag-box input.")
	var drag_frame: Image = await _capture_frame("drag_hidden")
	if drag_frame == null:
		_finish()
		return
	_expect_visible(drag_frame, _DRAG_SAMPLE, "drag_box_while_outlines_hidden")
	_expect_clear(drag_frame, _OUTLINE_SAMPLE, "outline_hidden_during_drag")
	var _shown_during_drag: Variant = canvas.call("set_selected_item_outlines_visible", true)
	var shown_drag_frame: Image = await _capture_frame("drag_shown")
	if shown_drag_frame == null:
		_finish()
		return
	_expect_visible(shown_drag_frame, _DRAG_SAMPLE, "drag_box_after_show")
	_expect_visible(shown_drag_frame, _OUTLINE_SAMPLE, "outline_restored_during_drag")
	var _released: GFSpatialCanvas2D.InputDisposition = canvas.handle_input_event(
		_mouse_button(motion.position, false)
	)
	_finish()


func _capture_frame(frame_name: String) -> Image:
	# 让真实 overlay._draw 消费 queue_redraw；不覆写或直接调用任何被测绘图函数。
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var frame: Image = _viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.get_size() != _IMAGE_SIZE:
		_record_failure("The real SubViewport returned no complete image: %s" % frame_name)
		return null
	var image_directory: String = OS.get_environment("GF_SPATIAL_CANVAS_SMOKE_IMAGE_DIR")
	if not image_directory.is_empty():
		var save_error: Error = frame.save_png(image_directory.path_join("%s.png" % frame_name))
		if save_error != OK:
			_record_failure("Could not save the owned rendered image: %s" % frame_name)
	return frame


func _expect_visible(frame: Image, region: Rect2i, label: String) -> void:
	var maximum_alpha: float = _maximum_alpha(frame, region)
	_observations[label] = maximum_alpha
	if maximum_alpha <= 0.1:
		_record_failure("Expected visible pixels in %s, observed alpha %s." % [label, maximum_alpha])


func _expect_clear(frame: Image, region: Rect2i, label: String) -> void:
	var maximum_alpha: float = _maximum_alpha(frame, region)
	_observations[label] = maximum_alpha
	if maximum_alpha >= 0.02:
		_record_failure("Expected a clear region in %s, observed alpha %s." % [label, maximum_alpha])


func _maximum_alpha(frame: Image, region: Rect2i) -> float:
	var maximum_alpha: float = 0.0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			maximum_alpha = maxf(maximum_alpha, frame.get_pixel(x, y).a)
	return maximum_alpha


func _mouse_button(canvas_position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = canvas_position
	event.pressed = pressed
	return event


func _record_failure(message: String) -> void:
	var _added: bool = _failures.append(message)


func _finish() -> void:
	if is_instance_valid(_viewport):
		_viewport.free()
		_viewport = null
	print("GF_SPATIAL_CANVAS_OUTLINE_RENDER_SMOKE ", JSON.stringify({
		"ok": _failures.is_empty(),
		"failures": _failures,
		"observations": _observations,
	}))
	quit(0 if _failures.is_empty() else 1)
