extends GutTest

const _AUTHORED: GFUIMotionRecipe = preload("res://tests/gf_core/extensions/action_queue/fixtures/independent_tracks.tres")
const _CANCEL_EFFECT = preload("res://tests/gf_core/extensions/action_queue/fixtures/cancel_during_sample.gd")
const _LIVE_EFFECT = preload("res://tests/gf_core/extensions/action_queue/fixtures/recorded_live_effect.gd")
const _METER = preload("res://tests/gf_core/extensions/action_queue/fixtures/live_meter.gd")
const _LABEL = preload("res://tests/gf_core/extensions/action_queue/fixtures/decode_label.gd")
const _ROUTED_PAGE: String = "res://tests/gf_core/extensions/action_queue/fixtures/routed_motion_page.tscn"
const _ROUTE_LAYER: int = GFUIUtility.Layer.POPUP
const STAR = preload("res://tests/gf_core/extensions/action_queue/fixtures/route_illumination.gd")


func _slide(
	target: StringName,
	delta: Vector2,
	clock: GFUIMotionTrack.Clock
) -> GFUIMotionTrack:
	var property: GFUIPropertyMotion = GFUIPropertyMotion.new()
	property.property = ^"position"
	property.start_value = delta
	property.end_value = Vector2.ZERO
	property.relative = true
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.clock = clock
	track.target = target
	track.effect = property
	return track


func test_independent_clocks_cancel_and_retime() -> void:
	for seconds: float in [0.4, 0.8]:
		var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
		var old: Control = add_child_autofree(Control.new())
		var page: Control = add_child_autofree(Control.new())
		var row: Control = Control.new()
		page.add_child(row)
		var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
		recipe.enter_seconds = seconds
		var local: GFUIMotionTrack = _slide(
			&"row",
			Vector2(50, 0),
			GFUIMotionTrack.Clock.ENTER
		)
		local.at = 0.5
		local.duration = 0.9
		local.relative_duration = false
		local.cue = &"half"
		recipe.tracks = [
			_slide(
				&"outgoing",
				Vector2(-100, 0),
				GFUIMotionTrack.Clock.EXIT
			),
			_slide(
				&"incoming",
				Vector2(0, 150),
				GFUIMotionTrack.Clock.ENTER
			),
			local,
		]
		var events: Array[StringName] = []
		var capture: Callable = func(cue: StringName, _target: Object) -> void:
			events.append(cue)
		var _observed: int = player.cue_reached.connect(capture)
		assert_eq(
			player.play(
				recipe,
				{
					&"outgoing": old,
					&"incoming": page,
					&"row": row,
				},
				{},
				true
			),
			OK
		)
		assert_true(player.seek(seconds * 0.5))
		assert_almost_eq(
			page.position.y,
			75.0,
			0.001
		)
		assert_eq(row.position.x, 50.0)
		assert_true(events.is_empty())
		assert_true(player.seek(seconds))
		assert_gt(row.position.x, 0.0)
		assert_true(player.is_active())
		player.cancel()
		assert_eq(page.position, Vector2.ZERO)
		assert_eq(row.position, Vector2.ZERO)
		assert_false(player.is_processing())


func test_external_typed_effect_seek_and_independent_sessions() -> void:
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = STAR.new()
	track.at = 0.35
	recipe.tracks = [track]
	var a: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var b: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var first: Node2D = add_child_autofree(Node2D.new())
	var second: Node2D = add_child_autofree(Node2D.new())
	var graph: PackedFloat32Array = PackedFloat32Array(
		[
			0,
			2,
			-1,
			2,
			0,
			3,
			-1,
			3,
			0,
		]
	)
	assert_eq(
		a.play(
			recipe,
			{ "incoming": first },
			{ "routes": graph, "source": 0 },
			true
		),
		OK
	)
	assert_eq(
		b.play(
			recipe,
			{ "incoming": second },
			{ "routes": graph, "source": 2 },
			true
		),
		OK
	)
	assert_true(a.seek(0.45))
	assert_true(a.seek(0.29))
	assert_true(b.seek(0.29))
	var appearance: PackedColorArray = first.get_meta(&"route_glow")
	var second_colors: PackedColorArray = second.get_meta(&"route_glow")
	assert_ne(appearance, second_colors)
	assert_true(a.seek(0.14))
	assert_true(a.seek(0.29))
	var replayed_colors: PackedColorArray = first.get_meta(&"route_glow")
	assert_eq(appearance, replayed_colors)
	assert_eq(
		a.play(
			recipe,
			{ "incoming": first },
			{ "routes": "bad", "source": 0 }
		),
		ERR_INVALID_DATA
	)
	assert_true(a.is_active())
	assert_string_contains(
		a.get_diagnostic(),
		"routes"
	)
	a.cancel()
	assert_false(first.has_meta(&"route_glow"))
	assert_true(b.is_active())


func test_authored_route_scene_samples_the_map_and_legend() -> void:
	var scene: PackedScene = load("res://tests/gf_core/extensions/action_queue/fixtures/route_illumination.tscn")
	var view: Node2D = add_child_autofree(scene.instantiate())
	var legend: Label = view.get_node(^"Legend")
	view.call(&"sample_ui_review", 0.4)
	var early_opacity: float = legend.modulate.a
	view.call(&"sample_ui_review", 0.8)
	var colors: PackedColorArray = view.get_meta(
		&"route_glow",
		PackedColorArray()
	)
	assert_eq(
		colors.size(),
		4
	)
	if colors.size() == 4:
		assert_gt(
			colors[0].a,
			colors[2].a
		)
	assert_gt(legend.modulate.a, early_opacity)


func test_one_recipe_combines_arbitrary_displacement_with_fade() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var origin: Vector2 = Vector2(12, 24)
	page.position = origin
	var recipe: GFUIMotionRecipe = _AUTHORED.duplicate_recipe()
	var move: GFUIMotionTrack = recipe.tracks[0]
	var displacement: GFUIPropertyMotion = move.effect
	displacement.in_parent_units = false
	var fade: GFUIMotionTrack = GFUIMotionTrack.new()
	fade.target = move.target
	fade.clock = move.clock
	var opacity: GFUIPropertyMotion = GFUIPropertyMotion.new()
	opacity.start_value = 1.0
	opacity.end_value = 0.0
	fade.effect = opacity
	recipe.tracks = [move, fade]
	for delta: Vector2 in [Vector2(-142, 0), Vector2(67.25, -113.5)]:
		displacement.end_value = delta
		for seconds: float in [0.24, 0.91]:
			recipe.exit_seconds = seconds
			assert_eq(
				player.play(
					recipe,
					{ &"outgoing": page },
					{},
					true
				),
				OK
			)
			assert_true(player.seek(seconds * 0.25))
			assert_almost_eq(
				page.position,
				origin + delta * 0.25,
				Vector2.ONE * 0.001
			)
			assert_almost_eq(
				page.modulate.a,
				0.75,
				0.001
			)
			player.cancel()
			assert_eq(page.position, origin)
			assert_eq(page.modulate.a, 1.0)
	var original: GFUIPropertyMotion = _AUTHORED.tracks[0].effect
	var original_end: Vector2 = original.end_value
	assert_eq(original_end, Vector2.LEFT)
	assert_true(original.in_parent_units)


func test_cue_starts_page_owned_native_animation() -> void:
	var coordinator: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var animator: AnimationPlayer = AnimationPlayer.new()
	page.add_child(animator)
	var clip: Animation = Animation.new()
	clip.length = 1.0
	var index: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(index, ^".:rotation")
	var _start: int = clip.track_insert_key(
		index,
		0.0,
		0.0
	)
	var _end: int = clip.track_insert_key(
		index,
		1.0,
		1.0
	)
	var library: AnimationLibrary = AnimationLibrary.new()
	assert_eq(
		library.add_animation(&"open_list", clip),
		OK
	)
	assert_eq(
		animator.add_animation_library(&"", library),
		OK
	)
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.at = 0.5
	track.cue = &"show_list"
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	var events: Array[StringName] = []
	var start_clip: Callable = func(cue: StringName, target: Object) -> void:
		var local: AnimationPlayer = target as AnimationPlayer
		events.append(cue)
		local.play(&"open_list")
	var _connected: int = coordinator.cue_reached.connect(start_clip)
	var targets: Dictionary = { &"incoming": animator }
	assert_eq(
		coordinator.play(
			recipe,
			targets,
			{},
			true
		),
		OK
	)
	assert_true(coordinator.seek(0.25))
	coordinator.finish()
	assert_true(events.is_empty())
	recipe.enter_seconds = 0.8
	assert_eq(
		coordinator.play(recipe, targets),
		OK
	)
	var interval: Dictionary = coordinator.get_track_intervals()[0]
	var start_time: float = interval.start_seconds
	var end_time: float = interval.end_seconds
	assert_eq(start_time, end_time)
	coordinator.call("_process", 0.3)
	assert_false(animator.is_playing())
	coordinator.call("_process", 0.11)
	assert_eq(
		events,
		[&"show_list"]
	)
	coordinator.cancel()
	assert_true(animator.is_playing())
	animator.advance(0.25)
	assert_almost_eq(
		page.rotation,
		0.25,
		0.001
	)
	track.cue = &""
	assert_eq(
		coordinator.play(recipe, targets),
		ERR_INVALID_DATA
	)


func test_layout_uses_independently_supplied_rectangles() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var item: Control = add_child_autofree(Control.new())
	var baseline: Rect2 = item.get_rect()
	var first: Rect2 = Rect2(
		10,
		50,
		80,
		40
	)
	var last: Rect2 = Rect2(
		35,
		80,
		120,
		60
	)
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = GFUILayoutMotion.new()
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	var inputs: Dictionary = {
		&"from_rects": { item: first },
		&"to_rects": { item: last },
	}
	assert_eq(
		player.play(
			recipe,
			{ &"incoming": item },
			inputs,
			true
		),
		OK
	)
	assert_true(player.seek(recipe.enter_seconds * 0.5))
	assert_eq(
		item.position,
		first.position.lerp(last.position, 0.5)
	)
	assert_eq(
		item.size,
		first.size.lerp(last.size, 0.5)
	)
	player.cancel()
	assert_eq(
		item.get_rect(),
		baseline
	)


func test_page_arrival_tail_reentrant_finish_and_freed_target() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var row: Control = Control.new()
	page.add_child(row)
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var track: GFUIMotionTrack = _slide(
		&"row",
		Vector2(90, 0),
		GFUIMotionTrack.Clock.ENTER
	)
	track.at = 0.5
	track.relative_duration = false
	track.duration = 0.9
	track.cue = &"half"
	recipe.tracks = [track]
	var calls: Array[String] = []
	var cue: Callable = func(marker: StringName, _target: Object) -> void:
		calls.append(String(marker))
	var arrived: Callable = func() -> void:
		calls.append("entered")
	var ended: Callable = func(reason: int) -> void:
		calls.append(str(reason))
	var _cue_connected: int = player.cue_reached.connect(cue)
	var _page_connected: int = player.page_entered.connect(arrived)
	var _end_connected: int = player.ended.connect(ended)
	assert_eq(
		player.play(
			recipe,
			{ "row": row }
		),
		OK
	)
	player.pause()
	assert_false(player.is_processing())
	player.resume()
	player.call("_process", 0.41)
	assert_eq(
		calls,
		["half", "entered"]
	)
	assert_true(player.is_active())
	var next: Callable = func(_reason: int) -> void:
		assert_eq(
			player.play(
				recipe,
				{ "row": row },
				{},
				true
			),
			OK
		)
	var _chained: int = player.ended.connect(next, CONNECT_ONE_SHOT)
	player.call("_process", 1.0)
	assert_true(player.is_active())
	assert_eq(
		player.get_time_seconds(),
		0.0
	)
	player.finish()
	assert_false(player.is_active())
	assert_eq(row.position, Vector2.ZERO)
	assert_eq(
		calls,
		[
			"half",
			"entered",
			str(GFUIMotionBinding.EndReason.COMPLETED),
			str(GFUIMotionBinding.EndReason.FINISHED),
		]
	)
	assert_eq(
		player.play(
			recipe,
			{ "row": row }
		),
		OK
	)
	page.remove_child(row)
	row.free()
	assert_false(player.is_active())
	assert_eq(
		calls[-1],
		str(GFUIMotionBinding.EndReason.CANCELLED)
	)


func test_live_only_action_capabilities_and_early_completion() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var effect: _LIVE_EFFECT = _LIVE_EFFECT.new()
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.at = 0.5
	track.effect = effect
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	assert_eq(
		player.play(
			recipe,
			{ "incoming": page },
			{},
			true
		),
		OK
	)
	assert_false(player.can_seek())
	assert_false(player.seek(0.22))
	player.finish()
	assert_eq(effect.events, [])
	assert_eq(
		player.play(
			recipe,
			{ "incoming": page }
		),
		OK
	)
	player.call("_process", 0.21)
	player.pause()
	player.resume()
	player.cancel()
	assert_eq(
		effect.events,
		[
			"start",
			"pause",
			"resume",
			"cancel",
		]
	)
	effect.events.clear()
	assert_eq(
		player.play(
			recipe,
			{ "incoming": page }
		),
		OK
	)
	player.call("_process", 0.24)
	effect.current.completed.emit("early")
	player.finish()
	assert_eq(
		effect.events,
		["start"]
	)
	assert_true(effect.current.completed.get_connections().is_empty())


func test_live_action_takeover_requires_a_pose_preserving_stop() -> void:
	var first: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var next: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	next.take_over_properties = true
	var page: Control = add_child_autofree(Control.new())
	var roles: Dictionary = { &"incoming": page }
	var live: _LIVE_EFFECT = _LIVE_EFFECT.new()
	live.properties = [^"position"]
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = live
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	var successor: GFUIMotionRecipe = GFUIMotionRecipe.new()
	successor.tracks = [
		_slide(
			&"incoming",
			Vector2.ZERO,
			GFUIMotionTrack.Clock.ENTER
		),
	]
	assert_eq(
		first.play(recipe, roles),
		OK
	)
	assert_eq(
		next.play(successor, roles),
		ERR_BUSY
	)
	assert_true(first.is_active())
	assert_eq(
		live.events,
		["start"]
	)
	first.cancel()
	live.config = GFTweenActionConfig.new()
	live.config.restore_initial_values_on_cancel = true
	var _step: GFTweenActionStep = live.config.add_property_step(
		^"position",
		Vector2(100, 0),
		1.0
	)
	assert_eq(
		first.play(recipe, roles),
		OK
	)
	first.pause()
	var pose: Vector2 = Vector2(30, 0)
	page.position = pose
	assert_eq(
		next.play(successor, roles),
		OK
	)
	assert_eq(page.position, pose)
	first.cancel()
	next.cancel()
	assert_eq(page.position, pose)


func test_material_replacement_preserves_the_material_and_visibility_for_the_next_binding() -> void:
	var canvas: ColorRect = add_child_autofree(ColorRect.new())
	canvas.hide()
	var effect: GFUIMaterialMotion = GFUIMaterialMotion.new()
	effect.material = preload("res://tests/gf_core/extensions/action_queue/fixtures/reveal_material.tres")
	var first: GFUIMotionBinding = effect.bind_target(canvas, {})
	first.sample.call(0.5)
	var pose: ShaderMaterial = canvas.material
	first.release.call(GFUIMotionBinding.EndReason.REPLACED)
	assert_eq(canvas.material, pose)
	assert_true(canvas.visible)
	var next: GFUIMotionBinding = effect.bind_target(canvas, {})
	next.sample.call(0.25)
	assert_ne(canvas.material, pose)
	next.release.call(GFUIMotionBinding.EndReason.CANCELLED)
	assert_true(canvas.visible)
	assert_eq(canvas.material, pose)
	var progress: float = pose.get_shader_parameter(&"progress")
	assert_eq(progress, 0.5)


func test_replacement_conflict_and_root_relative_viewport_geometry() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var parent: Control = add_child_autofree(Control.new())
	parent.size = Vector2(400, 300)
	var page: Control = Control.new()
	parent.add_child(page)
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var track: GFUIMotionTrack = _slide(
		&"incoming",
		Vector2.ONE,
		GFUIMotionTrack.Clock.ENTER
	)
	var movement: GFUIPropertyMotion = track.effect
	movement.in_parent_units = true
	recipe.tracks = [track]
	assert_eq(
		player.play(
			recipe,
			{ "incoming": page },
			{},
			true
		),
		OK
	)
	assert_true(player.seek(0.2))
	assert_eq(
		page.position,
		Vector2(200, 150)
	)
	parent.size = Vector2(500, 220)
	assert_true(player.seek(0.2))
	assert_eq(
		page.position,
		Vector2(250, 110)
	)
	var broken: GFUIMotionRecipe = recipe.duplicate_recipe()
	var component: GFUIPropertyMotion = GFUIPropertyMotion.new()
	component.property = ^"position:x"
	var extra: GFUIMotionTrack = GFUIMotionTrack.new()
	extra.effect = component
	broken.tracks.append(extra)
	assert_eq(
		player.play(
			broken,
			{ "incoming": page }
		),
		ERR_INVALID_DATA
	)
	assert_eq(
		page.position,
		Vector2(250, 110)
	)
	assert_string_contains(
		player.get_diagnostic(),
		"position:x"
	)
	player.cancel()
	assert_eq(page.position, Vector2.ZERO)


func test_display_reveals_current_project_values() -> void:
	var meter: _METER = _METER.new()
	var label: _LABEL = _LABEL.new()
	add_child_autofree(meter)
	add_child_autofree(label)
	meter.reveal_progress = 0.5
	meter.target_value = 96.0
	assert_eq(meter.value, 48.0)
	meter.reveal_progress = 1.0
	assert_eq(meter.value, 96.0)
	label.decode_progress = 0.5
	label.source_text = "NOVA 701"
	assert_string_starts_with(label.text, "NOVA")
	label.decode_progress = 1.0
	assert_eq(label.text, "NOVA 701")
	label.source_text = "NOVA 702"
	assert_eq(label.text, "NOVA 702")


func test_existing_tween_configuration_uses_motion_clock() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = config.add_property_step(
		^"position",
		Vector2(240, 80),
		0.75
	)
	step.transition_type = Tween.TRANS_LINEAR
	var effect: GFUITweenMotion = GFUITweenMotion.new()
	effect.configuration = config
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = effect
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [track]
	assert_eq(
		player.play(
			recipe,
			{ "incoming": page },
			{},
			true
		),
		OK
	)
	assert_true(player.seek(0.2))
	assert_almost_eq(
		page.position.x,
		120.0,
		0.001
	)
	player.cancel()
	assert_eq(page.position, Vector2.ZERO)
	assert_false(config.enable_playback_control)


func test_cancel_during_seek_preserves_reentrant_session_markers() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var first: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var interrupt: GFUIMotionTrack = GFUIMotionTrack.new()
	interrupt.effect = _CANCEL_EFFECT.new()
	first.tracks = [interrupt]
	var next: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var slide: GFUIMotionTrack = _slide(
		&"incoming",
		Vector2(10, 0),
		GFUIMotionTrack.Clock.ENTER
	)
	slide.cue = &"new"
	slide.at = 0.25
	next.tracks = [slide]
	var markers: Array[StringName] = []
	var observe: Callable = func(marker: StringName, _target: Object) -> void:
		markers.append(marker)
	var replace: Callable = func(_reason: int) -> void:
		assert_eq(
			player.play(
				next,
				{ "incoming": page },
				{},
				true
			),
			OK
		)
	var _observed: int = player.cue_reached.connect(observe)
	var _replaced: int = player.ended.connect(replace, CONNECT_ONE_SHOT)
	assert_eq(
		player.play(
			first,
			{ "incoming": page },
			{ "player": player },
			true
		),
		OK
	)
	assert_false(player.seek(0.3))
	assert_eq(
		player.get_time_seconds(),
		0.0
	)
	player.resume()
	player.call("_process", 0.15)
	assert_eq(
		markers,
		[&"new"]
	)


func _setup_navigation(ui: GFUIUtility, router: GFUIRouterUtility) -> void:
	ui.init()
	router.init()
	router.set_ui_utility(ui)
	for route_id: StringName in [
		&"menu",
		&"archive",
		&"settings",
	]:
		var route: GFUIRoute = GFUIRoute.new()
		route.route_id = route_id
		route.scene_path = _ROUTED_PAGE
		route.default_options = {
			"hide_under": true,
			"focus_on_open": true,
			"restore_focus_on_close": true,
		}
		assert_true(router.register_route(route))
	var _opened: int = router.route_opened.connect(_configure_routed_page)


func _configure_routed_page(
	route_id: StringName,
	panel: Node,
	_operation: GFUIRouterUtility.Operation
) -> void:
	var count: int = {
		"menu": 2,
		"archive": 3,
		"settings": 5,
	}[route_id]
	var heading: Label = panel.get_node("Title")
	heading.text = str(route_id)
	var focus_button: Button = panel.get_node("FocusButton")
	focus_button.process_mode = Node.PROCESS_MODE_ALWAYS
	focus_button.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
	focus_button.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	for number: int in count:
		var row: Control = Control.new()
		panel.get_node("Rows").add_child(row)
		row.position = Vector2(
			0,
			20 * number
		)


func _route_roles(old: Control, page: Control) -> Dictionary:
	return {
		&"outgoing": old,
		&"incoming": page,
		&"rows": page.get_node("Rows").get_children(),
		&"meter": page.get_node("Meter"),
		&"title": page.get_node("Title"),
	}


func test_router_reuses_one_recipe_across_pushes_and_two_immediate_backs() -> void:
	var ui: GFUIUtility = GFUIUtility.new()
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	_setup_navigation(ui, router)
	await get_tree().process_frame
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var present: Callable = player.play_transition.bind(_AUTHORED, _route_roles)
	var menu: Control = router.push_route(&"menu") as Control
	var menu_button: Button = menu.get_node("FocusButton")
	var reasons: Array[int] = []
	var _observed: int = player.ended.connect(
		func(reason: int) -> void:
			reasons.append(reason)
	)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.push_route.bind(&"archive"),
			present
		),
		OK
	)
	var archive: Control = ui.get_top_panel(_ROUTE_LAYER) as Control
	var archive_button: Button = archive.get_node("FocusButton")
	assert_eq(
		archive.get_node("Rows").get_child_count(),
		3
	)
	assert_eq(
		archive.get_viewport().gui_get_focus_owner(),
		archive_button
	)
	assert_eq(
		menu_button.get_mouse_filter_with_override(),
		Control.MOUSE_FILTER_IGNORE
	)
	player.call("_process", 0.08)
	assert_lt(menu.position.x, 0.0)
	assert_true(menu.is_visible_in_tree())
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.push_route.bind(&"settings"),
			present
		),
		OK
	)
	var settings: Control = ui.get_top_panel(_ROUTE_LAYER) as Control
	var settings_button: Button = settings.get_node("FocusButton")
	assert_eq(
		settings.get_node("Rows").get_child_count(),
		5
	)
	assert_eq(
		router.get_route_history().size(),
		3
	)
	assert_eq(
		settings.get_viewport().gui_get_focus_owner(),
		settings_button
	)
	assert_false(menu.visible)
	player.call("_process", 0.07)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.back.bind(_ROUTE_LAYER),
			present
		),
		OK
	)
	assert_eq(
		router.get_current_route_id(),
		&"archive"
	)
	assert_eq(
		ui.get_top_panel(_ROUTE_LAYER),
		archive
	)
	assert_eq(
		archive.get_viewport().gui_get_focus_owner(),
		archive_button
	)
	assert_eq(
		archive_button.get_mouse_filter_with_override(),
		Control.MOUSE_FILTER_STOP
	)
	var presses: Array[String] = []
	var _on_archive: int = archive_button.pressed.connect(
		func() -> void:
			presses.append("archive")
	)
	var _on_settings: int = settings_button.pressed.connect(
		func() -> void:
			presses.append("settings")
	)
	for pressed: bool in [true, false]:
		var accept: InputEventAction = InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = pressed
		archive.get_viewport().push_input(accept, true)
	assert_eq(
		presses,
		["archive"]
	)
	assert_eq(
		settings_button.get_focus_mode_with_override(),
		Control.FOCUS_NONE
	)
	assert_eq(
		router.get_route_history().size(),
		2
	)
	player.call("_process", 0.06)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.back.bind(_ROUTE_LAYER),
			present
		),
		OK
	)
	assert_eq(
		ui.get_top_panel(_ROUTE_LAYER),
		menu
	)
	assert_eq(
		router.get_current_route_id(),
		&"menu"
	)
	assert_eq(
		menu.get_viewport().gui_get_focus_owner(),
		menu_button
	)
	player.call(
		"_process",
		player.get_duration_seconds()
	)
	assert_eq(menu.position, Vector2.ZERO)
	var first_row: Control = menu.get_node("Rows").get_child(0)
	assert_eq(first_row.position.x, 0.0)
	assert_eq(
		reasons,
		[
			GFUIMotionBinding.EndReason.CANCELLED,
			GFUIMotionBinding.EndReason.CANCELLED,
			GFUIMotionBinding.EndReason.CANCELLED,
			GFUIMotionBinding.EndReason.COMPLETED,
		]
	)
	await get_tree().process_frame
	assert_false(is_instance_valid(archive))
	assert_false(is_instance_valid(settings))
	assert_eq(
		ui.get_layer_root(_ROUTE_LAYER).get_child_count(),
		1
	)
	router.dispose()
	ui.dispose()
	await get_tree().process_frame


func test_replace_frees_old_panel_while_new_list_keeps_advancing() -> void:
	var ui: GFUIUtility = GFUIUtility.new()
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	_setup_navigation(ui, router)
	await get_tree().process_frame
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var present: Callable = player.play_transition.bind(_AUTHORED, _route_roles)
	var old: Control = router.push_route(&"menu") as Control
	var previous: WeakRef = weakref(old)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.replace_route.bind(&"settings"),
			present
		),
		OK
	)
	var page: Control = ui.get_top_panel(_ROUTE_LAYER) as Control
	var row: Control = page.get_node("Rows").get_child(4) as Control
	var reasons: Array[int] = []
	var _observed: int = player.ended.connect(
		func(reason: int) -> void:
			reasons.append(reason)
	)
	assert_eq(
		router.get_route_history().size(),
		1
	)
	assert_true(old.is_inside_tree())
	assert_false(old.is_queued_for_deletion())
	assert_eq(
		page.get_viewport().gui_get_focus_owner(),
		page.get_node("FocusButton")
	)
	assert_false(player.seek(0.1))
	player.call("_process", 0.31)
	player.pause()
	assert_true(old.is_queued_for_deletion())
	assert_false(old.is_inside_tree())
	var before: float = row.position.x
	await get_tree().process_frame
	assert_true(previous.get_ref() == null)
	assert_true(player.is_active())
	assert_true(reasons.is_empty())
	assert_lt(before, 0.0)
	player.call("_process", 0.10)
	assert_gt(row.position.x, before)
	assert_lt(row.position.x, 0.0)
	player.call(
		"_process",
		player.get_duration_seconds()
	)
	assert_eq(row.position.x, 0.0)
	assert_eq(
		reasons,
		[GFUIMotionBinding.EndReason.COMPLETED]
	)
	router.dispose()
	ui.dispose()
	await get_tree().process_frame


func test_property_takeover_leaves_other_targets_running_and_never_rolls_back_new_owner() -> void:
	var first: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var next: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var row: Control = add_child_autofree(Control.new())
	var fade: GFUIMotionTrack = GFUIMotionTrack.new()
	fade.effect = GFUIPropertyMotion.new()
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	recipe.tracks = [fade]
	var both: GFUIMotionRecipe = recipe.duplicate_recipe()
	both.tracks.append(
		_slide(
			&"row",
			Vector2(100, 0),
			GFUIMotionTrack.Clock.ENTER
		)
	)
	assert_eq(
		first.play(
			both,
			{ &"incoming": page, &"row": row },
			{},
			true
		),
		OK
	)
	assert_true(first.seek(0.1))
	var before: float = page.modulate.a
	assert_eq(
		next.play(
			recipe,
			{ &"incoming": page },
			{},
			true
		),
		ERR_BUSY
	)
	assert_eq(page.modulate.a, before)
	next.take_over_properties = true
	assert_eq(
		next.play(
			recipe,
			{ &"incoming": page },
			{},
			true
		),
		OK
	)
	assert_true(next.seek(0.25))
	var taken: float = page.modulate.a
	first.call("_process", 0.12)
	assert_lt(row.position.x, 75.0)
	assert_eq(page.modulate.a, taken)
	first.cancel()
	assert_eq(row.position.x, 0.0)
	assert_eq(page.modulate.a, taken)
	next.cancel()
	assert_almost_eq(
		page.modulate.a,
		before,
		0.0001
	)


func test_detached_visual_and_queued_ancestor_do_not_replace_current_session() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var current: Control = add_child_autofree(Control.new())
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = GFUIPropertyMotion.new()
	recipe.tracks = [track]
	assert_eq(
		player.play(
			recipe,
			{ &"incoming": current },
			{},
			true
		),
		OK
	)
	var parent: Control = Control.new()
	add_child(parent)
	var child: Control = Control.new()
	parent.add_child(child)
	parent.queue_free()
	assert_eq(
		player.play(
			recipe,
			{ &"incoming": child }
		),
		ERR_INVALID_DATA
	)
	remove_child(parent)
	assert_eq(
		player.play(
			recipe,
			{ &"incoming": child }
		),
		ERR_INVALID_DATA
	)
	assert_true(player.seek(0.1))
	player.cancel()
	await get_tree().process_frame


func test_root_writing_tween_cannot_share_sibling_components_but_native_property_tracks_can() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var other: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var page: Control = add_child_autofree(Control.new())
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _x_step: GFTweenActionStep = config.add_property_step(
		^"position:x",
		100.0,
		0.4
	)
	var tween: GFUITweenMotion = GFUITweenMotion.new()
	tween.configuration = config
	var legacy: GFUIMotionTrack = GFUIMotionTrack.new()
	legacy.effect = tween
	var y: GFUIPropertyMotion = GFUIPropertyMotion.new()
	y.property = ^"position:y"
	y.end_value = 100.0
	var vertical: GFUIMotionTrack = GFUIMotionTrack.new()
	vertical.effect = y
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var targets: Dictionary = { &"incoming": page }
	for order: Array in [
		[legacy, vertical],
		[vertical, legacy],
	]:
		recipe.tracks.assign(order)
		assert_eq(
			player.play(recipe, targets),
			ERR_INVALID_DATA
		)
	recipe.tracks = [legacy]
	assert_eq(
		player.play(
			recipe,
			targets,
			{},
			true
		),
		OK
	)
	assert_true(player.seek(0.2))
	var current_x: float = page.position.x
	var direct: GFUIMotionRecipe = GFUIMotionRecipe.new()
	direct.tracks = [vertical]
	assert_eq(
		other.play(direct, targets),
		ERR_BUSY
	)
	other.take_over_properties = true
	assert_eq(
		other.play(
			direct,
			targets,
			{},
			true
		),
		OK
	)
	assert_true(other.seek(0.2))
	assert_eq(page.position.x, current_x)
	assert_false(player.is_active())
	player.cancel()
	assert_almost_eq(
		page.position.y,
		50.0,
		0.001
	)
	other.cancel()
	var x: GFUIPropertyMotion = GFUIPropertyMotion.new()
	x.property = ^"position:x"
	x.end_value = 100.0
	legacy.effect = x
	direct.tracks = [legacy, vertical]
	assert_eq(
		player.play(
			direct,
			targets,
			{},
			true
		),
		OK
	)
	assert_true(player.seek(0.2))
	assert_eq(
		page.position,
		Vector2(50, 50)
	)
	player.cancel()


func test_freeing_completed_outgoing_target_on_arrival_keeps_new_page_track() -> void:
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var old: Control = Control.new()
	add_child(old)
	var page: Control = add_child_autofree(Control.new())
	var recipe: GFUIMotionRecipe = GFUIMotionRecipe.new()
	var tail: GFUIMotionTrack = _slide(
		&"row",
		Vector2(100, 0),
		GFUIMotionTrack.Clock.ENTER
	)
	tail.relative_duration = false
	tail.duration = 1.0
	recipe.tracks = [
		_slide(
			&"old",
			Vector2(0, 50),
			GFUIMotionTrack.Clock.EXIT
		),
		tail,
	]
	var _arrived: int = player.page_entered.connect(old.queue_free)
	assert_eq(
		player.play(
			recipe,
			{ &"old": old, &"row": page }
		),
		OK
	)
	player.call("_process", 0.41)
	player.pause()
	var before: float = page.position.x
	await get_tree().process_frame
	assert_false(is_instance_valid(old))
	assert_true(player.is_active())
	player.call("_process", 0.1)
	assert_lt(page.position.x, before)
	assert_gt(page.position.x, 0.0)
	player.finish()
	assert_eq(page.position, Vector2.ZERO)


func test_reopening_a_retained_panel_invalidates_its_pending_exit() -> void:
	var ui: GFUIUtility = GFUIUtility.new()
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	_setup_navigation(ui, router)
	await get_tree().process_frame
	var _menu: Node = router.push_route(&"menu")
	var panel: Control = router.push_route(&"archive") as Control
	var releases: Array[Callable] = []
	var present: Callable = func(
		_old: Control,
		_new: Control,
		release: Callable
	) -> Error:
		releases.append(release)
		return OK
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.back.bind(_ROUTE_LAYER, false),
			present
		),
		OK
	)
	assert_eq(
		releases.size(),
		1
	)
	assert_true(panel.is_inside_tree())
	ui.push_panel_instance(panel, _ROUTE_LAYER)
	for release: Callable in releases:
		release.call()
		release.call()
	assert_eq(
		ui.get_top_panel(_ROUTE_LAYER),
		panel
	)
	assert_true(panel.is_inside_tree())
	assert_ne(panel.process_mode, Node.PROCESS_MODE_DISABLED)
	router.dispose()
	ui.dispose()
	await get_tree().process_frame


func test_failed_replace_and_successful_last_back_report_distinct_results() -> void:
	var ui: GFUIUtility = GFUIUtility.new()
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	_setup_navigation(ui, router)
	await get_tree().process_frame
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var present: Callable = player.play_transition.bind(_AUTHORED, _route_roles)
	var _menu: Node = router.push_route(&"menu")
	var reject: Callable = func(panel: Node) -> void:
		panel.queue_free()
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.replace_route.bind(
				&"settings",
				{},
				{},
				reject
			),
			present
		),
		FAILED
	)
	assert_push_warning("[GFUIRouterUtility][ui_router_utility.route_open_failed] Cannot open route: settings (panel_open_failed).")
	assert_null(ui.get_top_panel(_ROUTE_LAYER))
	var _archive: Node = router.push_route(&"archive")
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.back.bind(_ROUTE_LAYER),
			present
		),
		OK
	)
	assert_null(ui.get_top_panel(_ROUTE_LAYER))
	assert_false(player.is_active())
	router.dispose()
	ui.dispose()
	await get_tree().process_frame


func test_invalid_binding_after_route_commit_releases_both_handoffs() -> void:
	var ui: GFUIUtility = GFUIUtility.new()
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	_setup_navigation(ui, router)
	await get_tree().process_frame
	var player: GFUIMotionPlayer = add_child_autofree(GFUIMotionPlayer.new())
	var menu: Control = router.push_route(&"menu") as Control
	var valid: Callable = player.play_transition.bind(_AUTHORED, _route_roles)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.push_route.bind(&"archive"),
			valid
		),
		OK
	)
	var archive: WeakRef = weakref(ui.get_top_panel(_ROUTE_LAYER))
	var empty: Callable = func(_old: Control, _new: Control) -> Dictionary:
		return {}
	var invalid: Callable = player.play_transition.bind(_AUTHORED, empty)
	assert_eq(
		ui.navigate_with_presentation(
			_ROUTE_LAYER,
			router.replace_route.bind(&"settings"),
			invalid
		),
		ERR_INVALID_DATA
	)
	assert_eq(
		router.get_current_route_id(),
		&"settings"
	)
	assert_false(player.is_active())
	assert_eq(
		ui.get_layer_root(_ROUTE_LAYER).get_child_count(),
		1
	)
	await get_tree().process_frame
	assert_false(is_instance_valid(menu))
	assert_true(archive.get_ref() == null)
	router.dispose()
	ui.dispose()
	await get_tree().process_frame
