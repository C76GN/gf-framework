extends GutTest


func test_configure_copies_topology_and_replaces_state_atomically() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()

	assert_true(node.configure(definition))
	assert_eq(node.get_animation_names(), [&"idle", &"run"])
	assert_eq(node.get_layer_ids(), [&"back", &"front"])
	assert_eq(node.get_layer_variant(&"front"), &"base")

	definition.timeline_frames.remove_animation(&"run")
	definition.layers[1].variants[0].sprite_frames.remove_animation(&"run")
	assert_true(node.play(&"run"), "配置快照不能受外部 SpriteFrames 后续突变影响。")

	var invalid_definition: GFLayeredSpriteDefinition = _make_definition()
	invalid_definition.layers[0].variants[0].sprite_frames.remove_animation(&"run")
	assert_false(node.configure(invalid_definition))
	assert_eq(node.get_last_rejection_reason(), &"variant_topology_mismatch")
	assert_eq(node.get_layer_ids(), [&"back", &"front"], "失败配置必须完整保留旧状态。")
	assert_true(node.play(&"idle"), "失败配置不得破坏旧时间轴。")

	node.free()


func test_variant_visibility_modulate_and_offset_are_layer_scoped() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))

	assert_true(node.set_layer_variant(&"front", &"alternate"))
	assert_eq(node.get_layer_variant(&"front"), &"alternate")
	assert_eq(node.get_layer_variant(&"back"), &"base")
	assert_true(node.set_layer_visible(&"front", false))
	assert_false(node.is_layer_visible(&"front"))
	assert_true(node.set_layer_modulate(&"front", Color(0.5, 0.75, 1.0, 0.8)))
	assert_true(node.set_layer_offset(&"front", Vector2(3.0, -2.0)))
	assert_false(node.set_layer_variant(&"front", &"missing"))
	assert_eq(node.get_last_rejection_reason(), &"unknown_variant")

	node.free()


func test_shared_timeline_advances_all_layers_from_one_clock() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	assert_true(node.play(&"run"))
	assert_eq(node.get_current_frame(), 0)

	assert_true(node.advance(0.5), "2 FPS、相对时长 1 的一帧应在 0.5 秒后推进。")
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 0.0)
	assert_true(node.advance(0.5))
	assert_false(node.is_playing(), "非循环动画到达末尾后应停止。")
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 1.0)

	assert_true(node.play(&"run", -1.0, true))
	assert_true(node.advance(0.5))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 1.0)

	node.free()


func test_default_animation_first_reverse_play_starts_from_end() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.default_animation = &"run"
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(definition))

	assert_true(node.play(&"run", -1.0))
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 1.0)
	assert_true(node.advance(0.25))
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 0.5)
	assert_true(node.is_playing())

	node.free()


func test_finished_animation_restarts_when_played_again() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.default_animation = &"run"
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(definition))
	assert_true(node.play(&"run"))
	assert_true(node.advance(1.0))
	assert_false(node.is_playing())

	assert_true(node.play(&"run"))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.0)
	assert_true(node.advance(0.25))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.5)
	assert_true(node.is_playing())

	node.free()


func test_paused_animation_resumes_from_preserved_cursor() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	assert_true(node.play(&"run"))
	assert_true(node.advance(0.25))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.5)

	node.pause()
	assert_true(node.play(&"run"))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.5)
	assert_true(node.advance(0.25))
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 0.0)

	node.free()


func test_stopped_animation_restarts_from_requested_direction_boundary() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	assert_true(node.play(&"run"))
	assert_true(node.advance(0.25))
	node.stop(false)

	assert_true(node.play(&"run"))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.0)
	node.stop(false)
	assert_true(node.play(&"run", -1.0))
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 1.0)

	node.free()


func test_explicit_seek_cursor_is_resumed_when_played() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.default_animation = &"run"
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(definition))
	assert_true(node.seek(1, 0.25))

	assert_true(node.play(&"run"))
	assert_eq(node.get_current_frame(), 1)
	assert_eq(node.get_frame_progress(), 0.25)

	node.free()


func test_looping_timeline_and_seek_are_deterministic() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	assert_true(node.play(&"idle"))
	assert_true(node.seek(1, 0.5))
	assert_true(node.advance(0.25))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.0)
	assert_true(node.is_playing())

	assert_false(node.seek(99))
	assert_eq(node.get_last_rejection_reason(), &"frame_out_of_range")
	assert_false(node.play(&"idle", INF))
	assert_eq(node.get_last_rejection_reason(), &"invalid_speed_scale")

	node.free()


func test_invalid_ids_duplicates_and_draw_state_fail_closed() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.layers[1].layer_id = definition.layers[0].layer_id
	assert_false(node.configure(definition))
	assert_eq(node.get_last_rejection_reason(), &"invalid_layer_id")
	assert_false(node.is_configured())

	definition = _make_definition()
	definition.layers[0].offset = Vector2(NAN, 0.0)
	assert_false(node.configure(definition))
	assert_eq(node.get_last_rejection_reason(), &"invalid_layer_draw_state")

	node.free()


func test_definition_rejects_variant_frame_count_drift() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.layers[0].variants[0].sprite_frames.add_frame(&"idle", null)

	assert_false(node.configure(definition))
	assert_eq(node.get_last_rejection_reason(), &"variant_topology_mismatch")
	assert_false(node.is_configured())

	node.free()


func test_snapshot_isolates_sprite_frames_but_shares_texture_assets() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	var source_frames: SpriteFrames = definition.layers[0].variants[0].sprite_frames
	var texture: GradientTexture1D = GradientTexture1D.new()
	source_frames.set_frame(&"idle", 0, texture, 1.0)
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()

	assert_true(node.configure(definition))
	var snapshot_frames: SpriteFrames = _get_snapshot_variant_frames(node, &"front", &"base")
	assert_not_null(snapshot_frames)
	if snapshot_frames != null:
		assert_false(snapshot_frames == source_frames, "SpriteFrames 拓扑必须隔离。")
		assert_same(
			snapshot_frames.get_frame_texture(&"idle", 0),
			texture,
			"纹理资产必须按引用共享，不能随拓扑深复制。"
		)

	node.free()


func test_reentrant_configuration_wins_without_stale_outer_frame_signal() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	var replacement: GFLayeredSpriteDefinition = _make_definition()
	replacement.default_animation = &"run"
	var reentered: Array[bool] = [false]
	var reentry_results: Array[bool] = []
	var frame_events: Array[StringName] = []
	var configuration_connection: int = node.configuration_changed.connect(func() -> void:
		if reentered[0]:
			return
		reentered[0] = true
		reentry_results.append(node.configure(replacement))
	)
	var frame_connection: int = node.frame_changed.connect(func(animation: StringName, _frame: int) -> void:
		frame_events.append(animation)
	)
	assert_eq(configuration_connection, OK)
	assert_eq(frame_connection, OK)

	assert_true(node.configure(_make_definition()))
	assert_eq(reentry_results, [true])
	assert_eq(node.get_current_animation(), &"run")
	assert_eq(frame_events, [&"run"], "外层 configure 不得在重入提交后补发陈旧帧事件。")

	node.free()


## 验证 animation_started 中仅改变播放态不会吞掉已提交帧身份的通知。
func test_playback_only_started_reentry_preserves_committed_frame_signal() -> void:
	for reentry_mode: StringName in [&"pause", &"stop", &"replay"]:
		var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
		assert_true(node.configure(_make_definition()))
		var reentered: Array[bool] = [false]
		var replay_results: Array[bool] = []
		var frame_events: Array[StringName] = []
		var started_connection: int = node.animation_started.connect(func(
			animation: StringName
		) -> void:
			if reentered[0]:
				return
			reentered[0] = true
			match reentry_mode:
				&"pause":
					node.pause()
				&"stop":
					node.stop(false)
				&"replay":
					replay_results.append(node.play(animation, 2.0))
		)
		var frame_connection: int = node.frame_changed.connect(func(
			animation: StringName,
			_frame: int
		) -> void:
			frame_events.append(animation)
		)
		assert_eq(started_connection, OK)
		assert_eq(frame_connection, OK)

		assert_true(node.play(&"run"))
		assert_eq(node.get_current_animation(), &"run")
		assert_eq(node.get_current_frame(), 0)
		assert_eq(frame_events, [&"run"], "%s 重入仍应保留 run/0 通知。" % reentry_mode)
		if reentry_mode == &"replay":
			assert_eq(replay_results, [true])

		node.free()


func test_frame_signal_reentry_does_not_spend_remaining_delta_on_new_animation() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	var switched: Array[bool] = [false]
	var switch_results: Array[bool] = []
	var frame_connection: int = node.frame_changed.connect(func(
		animation: StringName,
		frame: int
	) -> void:
		if animation == &"run" and frame == 1 and not switched[0]:
			switched[0] = true
			switch_results.append(node.play(&"idle"))
	)
	assert_eq(frame_connection, OK)

	assert_true(node.play(&"run"))
	assert_true(node.advance(1.0))
	assert_eq(switch_results, [true])
	assert_eq(node.get_current_animation(), &"idle")
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.0)

	node.free()


func test_finished_signal_can_replay_without_consuming_stale_remaining_delta() -> void:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.default_animation = &"run"
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(definition))
	var replayed: Array[bool] = [false]
	var replay_results: Array[bool] = []
	var finished_connection: int = node.animation_finished.connect(func(
		animation: StringName
	) -> void:
		if replayed[0]:
			return
		replayed[0] = true
		replay_results.append(node.play(animation))
	)
	assert_eq(finished_connection, OK)
	assert_true(node.play(&"run"))

	assert_true(node.advance(2.0))
	assert_eq(replay_results, [true])
	assert_true(node.is_playing())
	assert_eq(node.get_current_animation(), &"run")
	assert_eq(node.get_current_frame(), 0)
	assert_eq(node.get_frame_progress(), 0.0)

	node.free()


func test_single_frame_loop_does_not_emit_false_frame_identity_change() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_single_frame_definition()))
	var frame_events: Array[int] = []
	var frame_connection: int = node.frame_changed.connect(func(
		_animation: StringName,
		frame: int
	) -> void:
		frame_events.append(frame)
	)
	assert_eq(frame_connection, OK)

	assert_true(node.play(&"idle"))
	assert_true(node.advance(0.5))
	assert_eq(node.get_current_frame(), 0)
	assert_eq(frame_events, [], "单帧循环跨边界时帧身份未变化。")

	node.free()


func test_single_frame_non_loop_restarts_in_both_directions() -> void:
	var definition: GFLayeredSpriteDefinition = _make_single_frame_definition()
	definition.timeline_frames.set_animation_loop(&"idle", false)
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(definition))
	assert_true(node.play(&"idle"))
	assert_true(node.advance(0.5))
	assert_false(node.is_playing())

	assert_true(node.play(&"idle"))
	assert_eq(node.get_frame_progress(), 0.0)
	assert_true(node.advance(0.25))
	assert_eq(node.get_frame_progress(), 0.5)
	assert_true(node.is_playing())

	node.stop(false)
	assert_true(node.play(&"idle", -1.0))
	assert_eq(node.get_frame_progress(), 1.0)
	assert_true(node.advance(0.25))
	assert_eq(node.get_frame_progress(), 0.5)
	assert_true(node.is_playing())

	node.free()


func test_stop_reset_emits_frame_change_when_identity_changes() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	assert_true(node.seek(1))
	var frame_events: Array[int] = []
	var frame_connection: int = node.frame_changed.connect(func(
		_animation: StringName,
		frame: int
	) -> void:
		frame_events.append(frame)
	)
	assert_eq(frame_connection, OK)

	node.stop(true)
	assert_eq(node.get_current_frame(), 0)
	assert_eq(frame_events, [0])

	node.free()


func test_advance_rejects_invalid_delta_even_while_paused() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_definition()))
	node.pause()

	assert_false(node.advance(NAN))
	assert_eq(node.get_last_rejection_reason(), &"invalid_delta")
	assert_false(node.advance(-0.01))
	assert_eq(node.get_last_rejection_reason(), &"invalid_delta")
	assert_true(node.advance(0.0))
	assert_eq(node.get_last_rejection_reason(), &"")

	node.free()


func test_looping_advance_stops_at_cross_frame_budget() -> void:
	var node: GFLayeredSprite2D = GFLayeredSprite2D.new()
	assert_true(node.configure(_make_single_frame_definition()))
	assert_true(node.play(&"idle"))
	var boundary_count: float = float(GFLayeredSprite2D.MAX_FRAME_ADVANCES_PER_TICK + 1)

	assert_false(node.advance(boundary_count / 2.0))
	assert_eq(node.get_last_rejection_reason(), &"frame_advance_limit")
	assert_true(node.is_playing())
	assert_eq(node.get_current_frame(), 0)

	node.free()


func _make_definition() -> GFLayeredSpriteDefinition:
	var definition: GFLayeredSpriteDefinition = GFLayeredSpriteDefinition.new()
	definition.timeline_frames = _make_frames()
	definition.default_animation = &"idle"

	var front: GFLayeredSpriteLayerDefinition = GFLayeredSpriteLayerDefinition.new()
	front.layer_id = &"front"
	front.default_variant_id = &"base"
	front.draw_order = 10
	front.variants = [
		_make_variant(&"base"),
		_make_variant(&"alternate"),
	]

	var back: GFLayeredSpriteLayerDefinition = GFLayeredSpriteLayerDefinition.new()
	back.layer_id = &"back"
	back.default_variant_id = &"base"
	back.draw_order = -10
	back.variants = [_make_variant(&"base")]
	definition.layers = [front, back]
	return definition


func _make_single_frame_definition() -> GFLayeredSpriteDefinition:
	var definition: GFLayeredSpriteDefinition = _make_definition()
	definition.timeline_frames.remove_frame(&"idle", 1)
	definition.timeline_frames.remove_animation(&"run")
	for layer: GFLayeredSpriteLayerDefinition in definition.layers:
		for variant: GFLayeredSpriteVariant in layer.variants:
			variant.sprite_frames.remove_frame(&"idle", 1)
			variant.sprite_frames.remove_animation(&"run")
	return definition


func _make_variant(variant_id: StringName) -> GFLayeredSpriteVariant:
	var variant: GFLayeredSpriteVariant = GFLayeredSpriteVariant.new()
	variant.variant_id = variant_id
	variant.sprite_frames = _make_frames()
	return variant


func _make_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	for existing_name: StringName in frames.get_animation_names():
		frames.remove_animation(existing_name)
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 2.0)
	frames.set_animation_loop(&"idle", true)
	frames.add_frame(&"idle", null, 1.0)
	frames.add_frame(&"idle", null, 1.0)
	frames.add_animation(&"run")
	frames.set_animation_speed(&"run", 2.0)
	frames.set_animation_loop(&"run", false)
	frames.add_frame(&"run", null, 1.0)
	frames.add_frame(&"run", null, 1.0)
	return frames


func _get_snapshot_variant_frames(
	node: GFLayeredSprite2D,
	layer_id: StringName,
	variant_id: StringName
) -> SpriteFrames:
	var states_value: Variant = node.get("_layer_states")
	if not states_value is Array:
		return null
	var states: Array = states_value
	for state_value: Variant in states:
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		if GFVariantData.get_option_string_name(state, "layer_id") != layer_id:
			continue
		var variants: Dictionary = GFVariantData.as_dictionary(state.get("variants"))
		var frames_value: Variant = variants.get(variant_id)
		if frames_value is SpriteFrames:
			var frames: SpriteFrames = frames_value
			return frames
	return null
