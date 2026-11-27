# 实际图形对照、资源回收和帧间隔测量。参数为绝对输出目录。
extends SceneTree

const STAGE = preload("res://addons/gf/extensions/action_queue/editor/preview/gf_ui_motion_preview_stage.gd")
const _PREVIEW = preload("res://addons/gf/extensions/action_queue/editor/preview/gf_ui_motion_preview.gd")
const _ASSETS: PackedScene = preload("res://tests/gf_core/extensions/action_queue/fixtures/motion_render_inputs.tscn")
var _errors: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		_errors.append(message)


func _initialize() -> void:
	call_deferred("_run")


func _image() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _check_exit_preview(output: String) -> int:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(480, 510)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var preview: VBoxContainer = _PREVIEW.new()
	view.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var slide: GFUIPropertyMotion = GFUIPropertyMotion.new()
	slide.property = ^"position"
	slide.start_value = Vector2.ZERO
	slide.end_value = Vector2(-1, -0.3)
	slide.relative = true
	slide.in_parent_units = true
	var fade: GFUIPropertyMotion = GFUIPropertyMotion.new()
	fade.start_value = 1.0
	fade.end_value = 0.0
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	for effect: GFUIMotionEffect in [slide, fade]:
		var track: GFUIMotionTrack = GFUIMotionTrack.new()
		track.target = &"outgoing"
		track.clock = GFUIMotionTrack.Clock.EXIT
		track.effect = effect
		recipe.tracks.append(track)
	preview.call("open_recipe", recipe)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var stage: Control = preview.get("_stage")
	var roi: Rect2i = Rect2i(stage.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, view.size))
	# 仅计样机上部，排除底部的独立进度条及整个时间轴工具栏。
	roi.size.y = floori(roi.size.y * 0.75)
	var first: Image = view.get_texture().get_image().get_region(roi)
	var slider: HSlider = preview.get("_time")
	slider.value = recipe.exit_seconds * 0.5
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var middle: Image = view.get_texture().get_image().get_region(roi)
	var changes: int = 0
	for y: int in first.get_height():
		for x: int in first.get_width():
			if first.get_pixel(x, y) != middle.get_pixel(x, y):
				changes += 1
	_check(
		changes * 8 > roi.get_area(),
		"exit preview did not reveal the outgoing page"
	)
	_check(
		first.save_png(output.path_join("exit-start.png")) == OK,
		"cannot save exit start"
	)
	_check(
		middle.save_png(output.path_join("exit-mid.png")) == OK,
		"cannot save exit midpoint"
	)
	view.queue_free()
	await process_frame
	return changes


func _run() -> void:
	var assets: ResourcePreloader = _ASSETS.instantiate()
	var surface: GFUIMotionRecipe = assets.get_resource(&"surface")
	var cover: GFUIMotionRecipe = assets.get_resource(&"cover")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	var output: String = args[0]
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage: STAGE = STAGE.new()
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	_check(
		stage.present(surface, true) == OK,
		"fixture playback failed"
	)
	_check(
		stage.player.seek(stage.player.get_duration_seconds() * 0.68),
		"cannot seek fixture"
	)
	stage.set_fixture_time(0.04)
	var early: Image = await _image()
	stage.set_fixture_time(0.55)
	var late: Image = await _image()
	var changed: int = 0
	var outside: int = 0
	for y: int in range(
		0,
		early.get_height(),
		3
	):
		for x: int in range(
			0,
			early.get_width(),
			3
		):
			if early.get_pixel(x, y) != late.get_pixel(x, y):
				if float(y) / early.get_height() > 0.82 and float(y) / early.get_height() < 0.92:
					changed += 1
				else:
					outside += 1
	if changed < 12 or outside != 0:
		_errors.append(
			"live page region changed=%d outside=%d"
			% [changed, outside]
		)
	_check(
		early.save_png(output.path_join("live_before.png")) == OK,
		"cannot save first frame"
	)
	_check(
		late.save_png(output.path_join("live_after.png")) == OK,
		"cannot save second frame"
	)
	stage.player.cancel()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if stage.viewport_count() != 0:
		_errors.append("cancel retained surfaces")
	_check(
		stage.present(cover, true) == OK,
		"fixture playback failed"
	)
	_check(
		stage.player.seek(stage.player.get_duration_seconds() / 2.0),
		"cannot seek fixture"
	)
	var dark: Image = await _image()
	if dark.get_pixel(40, 40).v > 0.12 or dark.get_pixel(640, 360).v > 0.12:
		_errors.append("color cover did not reach black")
	var measurements: Array[Dictionary] = []
	for mode: String in [
		"idle",
		"live_controls",
		"solid_cover",
		"frozen_live",
		"two_live",
	]:
		stage.freeze_old = mode != "two_live"
		var id: StringName = &"movement"
		if mode in ["frozen_live", "two_live"]:
			id = &"surface"
		elif mode == "solid_cover":
			id = &"cover"
		var source: GFUIMotionRecipe = assets.get_resource(id)
		var recipe: GFUIMotionRecipe = source.duplicate_recipe()
		recipe.enter_seconds = 30.0
		recipe.exit_seconds = 30.0
		_check(
			stage.present(recipe, true) == OK,
			"fixture playback failed"
		)
		_check(
			stage.player.seek(9.0),
			"cannot seek fixture"
		)
		if mode != "idle":
			stage.player.resume()
			stage.set_process(true)
		for frame: int in 16:
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame: int in 100:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			previous = now
		samples.sort()
		var record: Dictionary = {
			"mode": mode,
			"p50_ms": samples[49],
			"p95_ms": samples[94],
			"views": stage.viewport_count(),
			"source_rgba8_bytes": 1280 * 720 * 4 * stage.viewport_count(),
		}
		stage.player.finish()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		record["views_after_end"] = stage.viewport_count()
		if stage.viewport_count() != 0 or stage.player.is_processing():
			_errors.append("session left work running: " + mode)
		measurements.append(record)
	for index: int in 20:
		_check(
			stage.present(surface, true) == OK,
			"fixture playback failed"
		)
		_check(
			stage.player.seek(0.12),
			"cannot seek fixture"
		)
		stage.player.cancel()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var remaining: int = stage.find_children(
		"*",
		"SubViewport",
		true,
		false
	).size()
	if remaining != 0:
		_errors.append("rapid cancellation retained %d SubViewports" % remaining)
	var exit_changed: int = await _check_exit_preview(output)
	var result: Dictionary = {
		"exit_preview_changed_pixels_outside_meter": exit_changed,
		"adapter": RenderingServer.get_video_adapter_name(),
		"views_after_20_cancellations": remaining,
		"renderer": RenderingServer.get_current_rendering_method(),
		"size": [1280, 720],
		"frames_per_case": 100,
		"live_changed_samples": changed,
		"outside_changed_samples": outside,
		"measurements": measurements,
		"errors": _errors,
	}
	var file: FileAccess = FileAccess.open(
		output.path_join("render-contract.json"),
		FileAccess.WRITE
	)
	_check(
		file.store_string(JSON.stringify(result, "\t")),
		"cannot write contract report"
	)
	file.close()
	print("UI_MOTION_RENDER ", result)
	assets.free()
	stage.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
