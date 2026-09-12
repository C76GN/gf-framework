# 验证独立 Tween 样机的手动播放、时间定位、输入边界与生命周期。
extends GutTest


# --- 公共方法 ---

func test_preview_starts_idle_and_uses_only_its_own_target() -> void:
	var scene_target: Node2D = Node2D.new()
	add_child_autofree(scene_target)
	scene_target.position = Vector2(77.0, -19.0)
	var config: GFTweenActionConfig = _config(^"position", Vector2(10.0, 20.0))
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_eq(preview.get_state(), &"idle")
	assert_eq(preview.get_error(), "")
	assert_true(preview.set_initial_value(&"position", Vector2.ZERO))
	assert_true(preview.play())
	preview.advance(0.5)
	assert_eq(_vector2(preview, "position"), Vector2(5.0, 10.0))
	assert_eq(scene_target.position, Vector2(77.0, -19.0))
	var target_value: Variant = config.steps[0].target_value
	assert_true(target_value is Vector2)
	if target_value is Vector2:
		var vector: Vector2 = target_value
		assert_eq(vector, Vector2(10.0, 20.0))
	preview.dispose_preview()


func test_pause_stop_reset_and_replay_have_distinct_observable_effects() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_true(preview.set_initial_value(&"position", Vector2.ZERO))
	assert_true(preview.play())
	preview.advance(0.25)
	preview.pause()
	assert_eq(preview.get_state(), &"paused")
	preview.advance(0.5)
	assert_almost_eq(_vector2(preview, "position").x, 2.5, 0.001)
	assert_true(preview.play())
	preview.advance(0.25)
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	preview.stop()
	assert_eq(preview.get_state(), &"idle")
	preview.advance(1.0)
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	assert_true(preview.play())
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	preview.advance(1.1)
	assert_eq(preview.get_state(), &"finished")
	assert_almost_eq(_vector2(preview, "position").x, 10.0, 0.001)
	preview.reset_preview()
	assert_eq(preview.get_state(), &"idle")
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	preview.dispose_preview()


func test_serial_parallel_relative_steps_keep_native_tween_topology() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	var parallel_step: GFTweenActionStep = _step(^"position:y", 20.0, 2.0)
	parallel_step.parallel = true
	config.steps.append(parallel_step)
	var relative_step: GFTweenActionStep = _step(^"position:x", 5.0, 1.0)
	relative_step.as_relative = true
	config.steps.append(relative_step)
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2.ZERO))
	assert_true(preview.play())
	preview.advance(1.5)
	assert_eq(_vector2(preview, "position"), Vector2(10.0, 15.0))
	preview.advance(1.0)
	assert_eq(_vector2(preview, "position"), Vector2(12.5, 20.0))
	preview.advance(1.0)
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(15.0, 20.0))
	preview.dispose_preview()


func test_ui_and_3d_component_paths_preserve_other_components() -> void:
	var ui_preview: GFTweenPreviewViewport = _preview(_config(^"modulate:a", 0.25), 1)
	assert_true(ui_preview.set_initial_value(&"modulate", Color(0.25, 0.5, 0.75, 1.0)))
	assert_true(ui_preview.play())
	ui_preview.advance(1.1)
	assert_eq(_color(ui_preview, "modulate"), Color(0.25, 0.5, 0.75, 0.25))
	ui_preview.dispose_preview()
	var spatial_preview: GFTweenPreviewViewport = _preview(_config(^"position:z", -4.0), 2)
	assert_true(spatial_preview.set_initial_value(&"position", Vector3(1.0, 2.0, 3.0)))
	assert_true(spatial_preview.play())
	spatial_preview.advance(1.1)
	assert_eq(_vector3(spatial_preview, "position"), Vector3(1.0, 2.0, -4.0))
	spatial_preview.dispose_preview()


func test_delay_and_duration_scale_control_actual_manual_progress() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0, 0.5)
	config.steps[0].delay = 0.25
	config.duration_scale = 2.0
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.play())
	preview.advance(0.25)
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	preview.advance(0.75)
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	preview.advance(0.6)
	assert_eq(preview.get_state(), &"finished")
	assert_almost_eq(_vector2(preview, "position").x, 10.0, 0.001)
	preview.dispose_preview()


func test_rotation_degrees_replays_and_resets_through_canonical_rotation() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"rotation_degrees", 90.0))
	assert_true(preview.set_initial_value(&"rotation", PI / 4.0))
	assert_true(preview.play())
	preview.advance(1.1)
	assert_almost_eq(_number(preview, "rotation"), PI / 2.0, 0.001)
	preview.reset_preview()
	assert_almost_eq(_number(preview, "rotation"), PI / 4.0, 0.001)
	assert_false(preview.get_initial_values().has("rotation_degrees"))
	preview.configure(_config(^"rotation_degrees:y", 90.0), 2)
	assert_true(preview.set_initial_value(&"rotation", Vector3(0.25, 0.5, 0.75)))
	assert_true(preview.play())
	preview.advance(1.1)
	assert_almost_eq(_vector3(preview, "rotation").y, PI / 2.0, 0.001)
	preview.reset_preview()
	assert_eq(_vector3(preview, "rotation"), Vector3(0.25, 0.5, 0.75))
	preview.dispose_preview()


func test_active_snapshot_is_read_only_and_replay_reads_later_source_edits() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	config.steps[0].marker_id = &"project_marker"
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2.ZERO))
	assert_true(preview.play())
	preview.advance(0.25)
	config.steps[0].target_value = 20.0
	preview.advance(1.0)
	assert_almost_eq(_vector2(preview, "position").x, 10.0, 0.001)
	assert_true(preview.play())
	preview.advance(1.1)
	assert_almost_eq(_vector2(preview, "position").x, 20.0, 0.001)
	preview.stop()
	preview.reset_preview()
	preview.dispose_preview()
	assert_eq(config.steps.size(), 1)
	var target_value: Variant = config.steps[0].target_value
	assert_true(target_value is float)
	if target_value is float:
		var number: float = target_value
		assert_eq(number, 20.0)
	assert_eq(config.steps[0].duration, 1.0)
	assert_eq(config.steps[0].marker_id, &"project_marker")
	assert_eq(config.loop_count, 1)
	assert_eq(config.duration_scale, 1.0)


func test_finish_restore_policy_is_honored_without_changing_source() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	config.restore_initial_values_on_finish = true
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 3.0)))
	assert_true(preview.play())
	preview.advance(1.1)
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	assert_true(config.restore_initial_values_on_finish)
	preview.dispose_preview()


func test_step_and_loop_caps_accept_boundaries_and_reject_excess() -> void:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	for index: int in range(128):
		config.steps.append(_step(^"position:x", float(index), 0.0))
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.play())
	preview.advance(0.1)
	assert_eq(preview.get_state(), &"finished")
	assert_almost_eq(_vector2(preview, "position").x, 127.0, 0.001)
	config.steps.append(_step(^"position:x", 128.0, 0.0))
	preview.configure(config)
	assert_false(preview.play())
	assert_eq(preview.get_state(), &"error")
	assert_false(preview.get_error().is_empty())
	config = _config(^"position:x", 1.0, 0.25)
	config.loop_count = 32
	preview.configure(config)
	assert_true(preview.play())
	preview.stop()
	for loops: int in [0, 33]:
		config.loop_count = loops
		preview.configure(config)
		assert_false(preview.play())
		assert_eq(preview.get_state(), &"error")
	preview.dispose_preview()


func test_finite_relative_loops_progress_to_completion_and_reset() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	config.steps[0].as_relative = true
	config.loop_count = 2
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 4.0)))
	assert_true(preview.play())
	preview.advance(1.5)
	assert_eq(preview.get_state(), &"playing")
	assert_almost_eq(_vector2(preview, "position").x, 17.0, 0.001)
	preview.advance(0.6)
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(22.0, 4.0))
	preview.reset_preview()
	assert_eq(preview.get_state(), &"idle")
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 4.0))
	preview.dispose_preview()


func test_zero_time_relative_steps_apply_one_round_without_unbounded_looping() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.0)
	config.steps[0].as_relative = true
	config.loop_count = 32
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 4.0)))
	assert_true(preview.play())
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(5.0, 4.0))
	preview.advance(100.0)
	assert_eq(_vector2(preview, "position"), Vector2(5.0, 4.0))
	preview.dispose_preview()


func test_missing_steps_and_invalid_target_kind_fail_before_any_playback() -> void:
	var preview: GFTweenPreviewViewport = _preview(null)
	assert_false(preview.play())
	preview.configure(GFTweenActionConfig.new())
	assert_false(preview.play())
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps.append(null)
	preview.configure(config)
	assert_false(preview.play())
	preview.configure(_config(^"position:x", 1.0), 3)
	assert_false(preview.play())
	assert_true(preview.get_current_values().is_empty())
	preview.dispose_preview()


func test_duration_budget_counts_delays_scale_parallel_groups_and_loops() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 1.0, 0.5)
	config.steps[0].delay = 0.875
	config.duration_scale = 2.0
	config.loop_count = 32
	var parallel_step: GFTweenActionStep = _step(^"position:y", 2.0, 0.5)
	parallel_step.parallel = true
	config.steps.append(parallel_step)
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.play(), "120 seconds, including loop and delay, is accepted")
	preview.stop()
	config.steps[0].delay = 1.0
	preview.configure(config)
	assert_false(preview.play(), "128 seconds is rejected before playback")
	assert_eq(preview.get_state(), &"error")
	preview.dispose_preview()


func test_preview_rejects_non_finite_non_value_and_unknown_paths_atomically() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 1.0))
	var invalid_values: Array[Variant] = [NAN, INF, 1000001.0, Vector2(INF, 0.0), Resource.new(), [1.0], { "x": 1.0 }]
	for value: Variant in invalid_values:
		var config: GFTweenActionConfig = _config(^"position:x", value)
		preview.configure(config)
		var baseline: Dictionary = preview.get_initial_values()
		assert_false(preview.play())
		assert_eq(preview.get_state(), &"error")
		assert_eq(preview.get_current_values(), baseline)
	for property_path: NodePath in [^"script", ^"owner", ^"position:x:y", ^"../position", ^"global_position"]:
		preview.configure(_config(property_path, 1.0))
		assert_false(preview.play())
		assert_false(preview.get_error().is_empty())
	preview.dispose_preview()


func test_exact_scripts_reject_business_subclasses_without_calling_overrides() -> void:
	var custom_config: RejectedConfig = RejectedConfig.new()
	custom_config.steps.append(_step(^"position:x", 1.0))
	var preview: GFTweenPreviewViewport = _preview(custom_config)
	assert_false(preview.play())
	assert_eq(custom_config.invocations, 0)
	var custom_step: RejectedStep = RejectedStep.new()
	custom_step.target_value = Vector2.ONE
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps.append(custom_step)
	preview.configure(config)
	assert_false(preview.play())
	assert_eq(custom_step.invocations, 0)
	preview.dispose_preview()


func test_vector_color_components_and_invalid_enums_are_checked_before_start() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position", Vector2(1.0, INF)))
	assert_false(preview.play())
	preview.configure(_config(^"position", Vector3(1.0, 2.0, NAN)), 2)
	assert_false(preview.play())
	preview.configure(_config(^"modulate", Color(0.25, 0.5, 0.75, INF)), 1)
	assert_false(preview.play())
	var config: GFTweenActionConfig = _config(^"position:x", 2.0)
	config.steps[0].set(&"transition_type", 999)
	preview.configure(config)
	assert_false(preview.play())
	config.steps[0].transition_type = Tween.TRANS_LINEAR
	config.steps[0].set(&"ease_type", 999)
	preview.configure(config)
	assert_false(preview.play())
	config.steps[0].ease_type = Tween.EASE_IN_OUT
	preview.configure(config)
	assert_true(preview.play())
	preview.dispose_preview()


func test_invalid_manual_delta_aborts_and_restores_initial_values() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	for invalid_delta: float in [-1.0, INF, NAN]:
		assert_true(preview.play())
		preview.advance(0.25)
		preview.advance(invalid_delta)
		assert_eq(preview.get_state(), &"error")
		assert_eq(preview.get_current_values(), preview.get_initial_values())
	preview.dispose_preview()


func test_initial_values_are_detached_and_reject_unsafe_writes() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 3.0)))
	var values: Dictionary = preview.get_initial_values()
	values["position"] = Vector2(99.0, 99.0)
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	assert_false(preview.set_initial_value(&"script", Resource.new()))
	assert_false(preview.set_initial_value(&"position", Vector2(INF, 0.0)))
	assert_false(preview.set_initial_value(&"position", Vector3.ZERO))
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	preview.dispose_preview()


func test_reconfigure_and_exit_tree_cancel_old_playback_and_release_targets() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_true(preview.set_initial_value(&"position", Vector2.ZERO))
	assert_true(preview.play())
	preview.advance(0.25)
	preview.configure(_config(^"position:x", 20.0))
	assert_eq(preview.get_state(), &"idle")
	var baseline: Dictionary = preview.get_current_values()
	preview.advance(2.0)
	assert_eq(preview.get_current_values(), baseline)
	assert_true(preview.play())
	preview.advance(0.25)
	remove_child(preview)
	assert_eq(preview.get_state(), &"idle")
	preview.advance(2.0)
	assert_eq(preview.get_current_values(), preview.get_initial_values())
	add_child(preview)
	preview.configure(_config(^"position:x", 20.0))
	assert_true(preview.play())
	preview.dispose_preview()
	preview.dispose_preview()
	assert_eq(preview.get_state(), &"idle")
	assert_false(preview.play())
	var weak_preview: WeakRef = weakref(preview)
	preview.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(weak_preview.get_ref() == null)


func test_panel_buttons_hide_and_rebind_control_only_the_preview() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0))
	add_child_autofree(panel)
	panel.set_process(false)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	var play_button: Button = _button(panel, "Play")
	var pause_button: Button = _button(panel, "Pause")
	assert_false(play_button.disabled)
	assert_true(pause_button.disabled)
	play_button.pressed.emit()
	assert_true(play_button.disabled)
	assert_false(pause_button.disabled)
	preview.advance(0.25)
	pause_button.pressed.emit()
	assert_eq(preview.get_state(), &"paused")
	_button(panel, "Stop").pressed.emit()
	assert_almost_eq(_vector2(preview, "position").x, 2.5, 0.001)
	_button(panel, "Reset").pressed.emit()
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	play_button.pressed.emit()
	preview.advance(0.25)
	panel.hide()
	assert_eq(preview.get_state(), &"idle")
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	panel.show()
	panel.configure(_config(^"position:x", 20.0))
	panel.set_process(false)
	assert_false(play_button.disabled)
	play_button.pressed.emit()
	preview.advance(1.1)
	assert_almost_eq(_vector2(preview, "position").x, 20.0, 0.001)
	panel.dispose_preview()
	assert_true(preview.get_current_values().is_empty())
	assert_false(panel.is_processing())


func test_panel_playback_uses_wall_clock_when_engine_time_scale_is_zero() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0, 10.0))
	add_child_autofree(panel)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	var play_button: Button = _button(panel, "Play")
	var original_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.0
	play_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var current_values: Dictionary = preview.get_current_values()
	Engine.time_scale = original_time_scale
	panel.dispose_preview()
	var raw_position: Variant = current_values.get("position")
	assert_true(raw_position is Vector2)
	if raw_position is Vector2:
		var position: Vector2 = raw_position
		assert_gt(position.x, 0.0, "Panel playback uses elapsed wall time even when engine time scale is zero")


func test_retired_initial_fields_cannot_write_after_rebind_or_kind_change() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0))
	add_child_autofree(panel)
	panel.set_process(false)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	var original_field: GFEditorValueField = _initial_field(panel, "Initial_position")
	panel.configure(_config(^"position:x", 20.0))
	panel.set_process(false)
	original_field.value_changed.emit(Vector2(99.0, 99.0))
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	var replacement_field: GFEditorValueField = _initial_field(panel, "Initial_position")
	var target_kind: OptionButton = _target_kind(panel)
	target_kind.select(1)
	target_kind.item_selected.emit(1)
	replacement_field.value_changed.emit(Vector2(88.0, 88.0))
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	var current_field: GFEditorValueField = _initial_field(panel, "Initial_position")
	current_field.value_changed.emit(Vector2(2.0, 3.0))
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	panel.dispose_preview()


func test_seek_repeats_and_moves_backwards_then_continues_from_the_selected_time() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_false(preview.has_session())
	assert_false(preview.seek(0.5), "Seeking requires a captured playback session")
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	assert_true(preview.play())
	assert_true(preview.has_session())
	assert_eq(preview.get_duration_seconds(), 1.0)
	assert_true(preview.seek(0.75))
	assert_eq(preview.get_state(), &"paused")
	assert_almost_eq(_vector2(preview, "position").x, 7.5, 0.001)
	assert_true(preview.seek(0.25))
	var earlier_values: Dictionary = preview.get_current_values()
	assert_almost_eq(_vector2(preview, "position").x, 2.5, 0.001)
	assert_eq(preview.get_time_seconds(), 0.25)
	assert_true(preview.seek(0.75))
	assert_true(preview.seek(0.25))
	assert_eq(preview.get_current_values(), earlier_values)
	preview.advance(0.5)
	assert_eq(preview.get_current_values(), earlier_values, "A time inspection is paused")
	assert_true(preview.play())
	preview.advance(0.25)
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	assert_eq(preview.get_time_seconds(), 0.5)
	preview.dispose_preview()


func test_seek_uses_parallel_group_duration_with_delays_and_relative_loops() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0, 0.5)
	config.steps[0].delay = 0.25
	var parallel_step: GFTweenActionStep = _step(^"position:y", 20.0, 1.0)
	parallel_step.parallel = true
	config.steps.append(parallel_step)
	var relative_step: GFTweenActionStep = _step(^"position:x", 4.0, 0.5)
	relative_step.delay = 0.25
	relative_step.as_relative = true
	config.steps.append(relative_step)
	config.duration_scale = 2.0
	config.loop_count = 2
	var preview: GFTweenPreviewViewport = _preview(config)
	var native_target: Node2D = Node2D.new()
	add_child_autofree(native_target)
	var native_reference: Tween = _native_parallel_relative_tween(native_target)
	assert_true(preview.play())
	assert_eq(preview.get_duration_seconds(), 7.0, "Two loops of max(1.5, 2.0) + 1.5")
	assert_true(preview.seek(2.5))
	assert_eq(_vector2(preview, "position"), Vector2(10.0, 20.0))
	assert_true(preview.seek(3.0))
	# 首轮与次轮的初值语义可能不同，使用独立原生分步推进作基线，而非推算 relative 起点。
	for _index: int in range(6):
		var _reference_running: bool = native_reference.custom_step(0.5)
	assert_eq(_vector2(preview, "position"), native_target.position)
	assert_true(preview.seek(6.5))
	for _index: int in range(7):
		var _reference_running: bool = native_reference.custom_step(0.5)
	assert_eq(_vector2(preview, "position"), native_target.position)
	assert_true(preview.seek(0.25))
	assert_almost_eq(_vector2(preview, "position").x, 0.0, 0.001)
	assert_almost_eq(_vector2(preview, "position").y, 2.5, 0.001)
	assert_true(preview.seek(7.0))
	assert_eq(_vector2(preview, "position"), Vector2(14.0, 20.0))
	native_reference.kill()
	preview.dispose_preview()


func test_seek_relative_loop_values_match_forward_native_playback() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.25)
	config.steps[0].as_relative = true
	config.loop_count = 32
	var preview: GFTweenPreviewViewport = _preview(config)
	var forward_preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 4.0)))
	assert_true(forward_preview.set_initial_value(&"position", Vector2(2.0, 4.0)))
	assert_true(preview.play())
	assert_true(forward_preview.play())
	forward_preview.advance(7.875)
	assert_true(preview.seek(7.875))
	assert_eq(preview.get_current_values(), forward_preview.get_current_values())
	assert_almost_eq(_vector2(preview, "position").x, 96.5, 0.001)
	assert_true(preview.seek(0.0))
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 4.0))
	assert_true(preview.seek(8.0))
	assert_eq(_vector2(preview, "position"), Vector2(98.0, 4.0))
	preview.dispose_preview()
	forward_preview.dispose_preview()


func test_seek_end_keeps_final_pose_until_continue_applies_finish_restore() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	config.restore_initial_values_on_finish = true
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 3.0)))
	assert_true(preview.play())
	assert_true(preview.seek(1.0))
	assert_eq(preview.get_state(), &"paused")
	assert_eq(_vector2(preview, "position"), Vector2(10.0, 3.0))
	assert_true(preview.play(), "Continuing an inspected endpoint completes the existing session")
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	assert_true(preview.has_session())
	assert_true(preview.seek(1.0), "Finished sessions retain their captured inspection data")
	assert_eq(_vector2(preview, "position"), Vector2(10.0, 3.0))
	preview.dispose_preview()


func test_seek_does_not_read_changed_source_and_invalid_times_preserve_the_session() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0)
	config.steps[0].marker_id = &"project_marker"
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.play())
	config.steps[0].target_value = 100.0
	config.steps[0].duration = 10.0
	config.loop_count = 2
	assert_true(preview.seek(0.5))
	assert_eq(preview.get_duration_seconds(), 1.0)
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	var inspected_values: Dictionary = preview.get_current_values()
	for invalid_time: float in [-1.0, 1.0001, INF, NAN]:
		assert_false(preview.seek(invalid_time))
		assert_eq(preview.get_state(), &"paused")
		assert_eq(preview.get_time_seconds(), 0.5)
		assert_eq(preview.get_current_values(), inspected_values)
		assert_false(preview.get_error().is_empty())
	preview.stop()
	assert_true(preview.seek(0.25), "Stop keeps the snapshot available for inspection")
	assert_almost_eq(_vector2(preview, "position").x, 2.5, 0.001)
	preview.reset_preview()
	assert_false(preview.has_session())
	assert_false(preview.seek(0.25))
	assert_true(preview.play())
	assert_eq(preview.get_duration_seconds(), 20.0)
	assert_true(preview.seek(0.5))
	assert_almost_eq(_vector2(preview, "position").x, 5.0, 0.001)
	assert_eq(config.steps[0].marker_id, &"project_marker")
	assert_eq(config.steps[0].duration, 10.0)
	preview.dispose_preview()


func test_seek_zero_duration_inspects_one_round_without_applying_finish_restore() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.0)
	config.steps[0].as_relative = true
	config.loop_count = 32
	config.restore_initial_values_on_finish = true
	var preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 4.0)))
	assert_true(preview.play())
	assert_eq(preview.get_duration_seconds(), 0.0)
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 4.0))
	assert_true(preview.seek(0.0))
	assert_eq(preview.get_state(), &"paused")
	assert_eq(_vector2(preview, "position"), Vector2(5.0, 4.0))
	assert_true(preview.seek(0.0))
	assert_eq(_vector2(preview, "position"), Vector2(5.0, 4.0))
	assert_true(preview.play())
	assert_eq(preview.get_state(), &"finished")
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 4.0))
	preview.dispose_preview()


func test_seek_exact_end_includes_trailing_instant_steps_and_fractional_group_boundaries() -> void:
	for first_duration: float in [0.5, 0.1]:
		var second_duration: float = 0.5 if first_duration == 0.5 else 0.2
		var config: GFTweenActionConfig = _config(^"position:x", 10.0, first_duration)
		config.steps.append(_step(^"position:x", 20.0, second_duration))
		config.steps.append(_step(^"position:y", 9.0, 0.0))
		config.loop_count = 2
		var preview: GFTweenPreviewViewport = _preview(config)
		assert_true(preview.play())
		assert_true(preview.seek(preview.get_duration_seconds()))
		assert_eq(_vector2(preview, "position"), Vector2(20.0, 9.0))
		assert_eq(preview.get_state(), &"paused")
		assert_true(preview.seek(0.0))
		assert_eq(_vector2(preview, "position"), Vector2.ZERO)
		preview.dispose_preview()


func test_seek_preserves_native_easing_and_overlapping_property_component_order() -> void:
	var config: GFTweenActionConfig = _config(^"position", Vector2(12.0, 8.0), 0.8)
	config.steps[0].transition_type = Tween.TRANS_CUBIC
	config.steps[0].ease_type = Tween.EASE_IN
	var overlapping: GFTweenActionStep = _step(^"position:x", 5.0, 0.5)
	overlapping.parallel = true
	overlapping.as_relative = true
	overlapping.delay = 0.1
	config.steps.append(overlapping)
	var preview: GFTweenPreviewViewport = _preview(config)
	var forward_preview: GFTweenPreviewViewport = _preview(config)
	assert_true(preview.play())
	assert_true(forward_preview.play())
	forward_preview.advance(0.375)
	assert_true(preview.seek(0.75))
	assert_true(preview.seek(0.375))
	assert_eq(preview.get_current_values(), forward_preview.get_current_values())
	assert_true(preview.play())
	preview.advance(0.1)
	forward_preview.advance(0.1)
	assert_eq(preview.get_current_values(), forward_preview.get_current_values())
	preview.dispose_preview()
	forward_preview.dispose_preview()


func test_seek_session_is_invalidated_by_initial_values_configuration_and_disposal() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_true(preview.play())
	assert_true(preview.set_initial_value(&"position", Vector2(2.0, 3.0)))
	assert_false(preview.has_session())
	assert_false(preview.seek(0.5))
	assert_eq(_vector2(preview, "position"), Vector2(2.0, 3.0))
	assert_true(preview.play())
	preview.configure(_config(^"position:z", 5.0), 2)
	assert_false(preview.has_session())
	assert_false(preview.seek(0.5))
	assert_eq(_vector3(preview, "position"), Vector3.ZERO)
	assert_true(preview.play())
	preview.dispose_preview()
	assert_false(preview.has_session())
	assert_false(preview.seek(0.5))
	assert_true(preview.get_current_values().is_empty())


func test_seek_endpoint_cannot_complete_successfully_after_the_sample_is_freed() -> void:
	var preview: GFTweenPreviewViewport = _preview(_config(^"position:x", 10.0))
	assert_true(preview.play())
	assert_true(preview.seek(1.0))
	var target: Node = preview.find_child("PreviewTarget", true, false)
	assert_not_null(target)
	if target == null:
		return
	target.free()
	assert_false(preview.play())
	assert_eq(preview.get_state(), &"error")
	assert_false(preview.has_session())
	assert_false(preview.seek(0.5))
	preview.dispose_preview()


func test_panel_time_controls_seek_without_feedback_and_retired_inputs_are_ignored() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0))
	add_child_autofree(panel)
	panel.set_process(false)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	var initial_slider: HSlider = _time_slider(panel)
	assert_false(initial_slider.editable)
	_button(panel, "Play").pressed.emit()
	var slider: HSlider = _time_slider(panel)
	assert_true(slider.editable)
	assert_eq(slider.max_value, 1.0)
	slider.value = 0.25
	assert_eq(preview.get_state(), &"paused")
	assert_almost_eq(_vector2(preview, "position").x, 2.5, 0.001)
	_time_input(panel).value = 0.75
	assert_almost_eq(_vector2(preview, "position").x, 7.5, 0.001)
	assert_eq(slider.value, 0.75)
	_button(panel, "Play").pressed.emit()
	preview.advance(0.1)
	assert_eq(preview.get_state(), &"playing", "Programmatic time refresh must not trigger another seek")
	panel.configure(_config(^"position:x", 20.0))
	panel.set_process(false)
	slider.value_changed.emit(0.5)
	initial_slider.value_changed.emit(0.5)
	assert_false(preview.has_session())
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	_button(panel, "Play").pressed.emit()
	var hidden_slider: HSlider = _time_slider(panel)
	panel.hide()
	hidden_slider.value_changed.emit(0.5)
	assert_false(preview.has_session())
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	panel.show()
	_button(panel, "Play").pressed.emit()
	var disposed_input: SpinBox = _time_input(panel)
	panel.dispose_preview()
	disposed_input.value_changed.emit(0.5)
	assert_false(preview.has_session())
	assert_true(preview.get_current_values().is_empty())


func test_panel_locate_button_can_inspect_the_only_time_of_an_instant_configuration() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.0)
	config.restore_initial_values_on_finish = true
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(config)
	add_child_autofree(panel)
	panel.set_process(false)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	_button(panel, "Play").pressed.emit()
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	assert_false(_button(panel, "InspectTime").disabled)
	_button(panel, "InspectTime").pressed.emit()
	assert_eq(preview.get_state(), &"paused")
	assert_eq(_vector2(preview, "position"), Vector2(3.0, 0.0))
	_button(panel, "InspectTime").pressed.emit()
	assert_eq(_vector2(preview, "position"), Vector2(3.0, 0.0))
	panel.dispose_preview()


func test_panel_retiring_time_controls_cannot_seek_a_new_session_during_visibility_change() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0))
	add_child_autofree(panel)
	panel.set_process(false)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	_button(panel, "Play").pressed.emit()
	var old_slider: HSlider = _time_slider(panel)
	var _visibility_connected: int = old_slider.visibility_changed.connect(func() -> void:
		old_slider.value_changed.emit(0.5)
	)
	_button(panel, "Stop").pressed.emit()
	_button(panel, "Play").pressed.emit()
	assert_eq(preview.get_state(), &"playing")
	assert_eq(preview.get_time_seconds(), 0.0)
	assert_eq(_vector2(preview, "position"), Vector2.ZERO)
	panel.dispose_preview()


func test_disposed_panel_rejects_late_control_signals_without_rebuilding_sample() -> void:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(_config(^"position:x", 10.0))
	add_child_autofree(panel)
	var preview: GFTweenPreviewViewport = _panel_viewport(panel)
	var field: GFEditorValueField = _initial_field(panel, "Initial_position")
	var target_kind: OptionButton = _target_kind(panel)
	panel.dispose_preview()
	target_kind.item_selected.emit(1)
	field.value_changed.emit(Vector2(99.0, 99.0))
	for button_name: String in ["Play", "Pause", "Stop", "Reset"]:
		_button(panel, button_name).pressed.emit()
	assert_true(preview.get_current_values().is_empty())
	assert_true(preview.get_initial_values().is_empty())
	assert_eq(preview.get_state(), &"idle")
	assert_false(panel.is_processing())


# --- 私有/辅助方法 ---

func _native_parallel_relative_tween(target: Node2D) -> Tween:
	var native_tween: Tween = target.create_tween()
	native_tween.pause()
	var _loops: Tween = native_tween.set_loops(2)
	var first: PropertyTweener = native_tween.tween_property(target, ^"position:x", 10.0, 1.0)
	var _first_options: PropertyTweener = first.set_delay(0.5).set_trans(Tween.TRANS_LINEAR)
	var _parallel: Tween = native_tween.parallel()
	var second: PropertyTweener = native_tween.tween_property(target, ^"position:y", 20.0, 2.0)
	var _second_options: PropertyTweener = second.set_trans(Tween.TRANS_LINEAR)
	var relative: PropertyTweener = native_tween.tween_property(target, ^"position:x", 4.0, 1.0)
	var _relative_options: PropertyTweener = relative.set_delay(0.5).set_trans(Tween.TRANS_LINEAR).as_relative()
	return native_tween


func _preview(config: Resource, kind: int = 0) -> GFTweenPreviewViewport:
	var preview: GFTweenPreviewViewport = GFTweenPreviewViewport.new()
	add_child_autofree(preview)
	preview.configure(config, kind)
	return preview


func _config(property_path: NodePath, value: Variant, duration: float = 1.0) -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps.append(_step(property_path, value, duration))
	return config


func _step(property_path: NodePath, value: Variant, duration: float = 1.0) -> GFTweenActionStep:
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = property_path
	step.target_value = value
	step.duration = duration
	step.transition_type = Tween.TRANS_LINEAR
	return step


func _vector2(preview: GFTweenPreviewViewport, key: String) -> Vector2:
	var value: Variant = preview.get_current_values().get(key)
	assert_true(value is Vector2)
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	return Vector2.ZERO


func _vector3(preview: GFTweenPreviewViewport, key: String) -> Vector3:
	var value: Variant = preview.get_current_values().get(key)
	assert_true(value is Vector3)
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


func _color(preview: GFTweenPreviewViewport, key: String) -> Color:
	var value: Variant = preview.get_current_values().get(key)
	assert_true(value is Color)
	if value is Color:
		var color: Color = value
		return color
	return Color.WHITE


func _number(preview: GFTweenPreviewViewport, key: String) -> float:
	var value: Variant = preview.get_current_values().get(key)
	assert_true(value is float)
	if value is float:
		var number: float = value
		return number
	return 0.0


func _panel_viewport(panel: GFTweenPreviewPanel) -> GFTweenPreviewViewport:
	var child: Node = panel.find_child("PreviewViewport", true, false)
	assert_true(child is GFTweenPreviewViewport)
	if child is GFTweenPreviewViewport:
		var viewport: GFTweenPreviewViewport = child
		return viewport
	return null


func _button(panel: GFTweenPreviewPanel, control_name: String) -> Button:
	var child: Node = panel.find_child(control_name, true, false)
	assert_true(child is Button)
	if child is Button:
		var button: Button = child
		return button
	return null


func _initial_field(panel: GFTweenPreviewPanel, control_name: String) -> GFEditorValueField:
	var child: Node = panel.find_child(control_name, true, false)
	assert_true(child is GFEditorValueField)
	if child is GFEditorValueField:
		var field: GFEditorValueField = child
		return field
	return null


func _target_kind(panel: GFTweenPreviewPanel) -> OptionButton:
	var child: Node = panel.find_child("TargetKind", true, false)
	assert_true(child is OptionButton)
	if child is OptionButton:
		var option: OptionButton = child
		return option
	return null


func _time_slider(panel: GFTweenPreviewPanel) -> HSlider:
	var child: Node = panel.find_child("PreviewTimeSlider", true, false)
	assert_true(child is HSlider)
	if child is HSlider:
		var slider: HSlider = child
		return slider
	return null


func _time_input(panel: GFTweenPreviewPanel) -> SpinBox:
	var child: Node = panel.find_child("PreviewTimeInput", true, false)
	assert_true(child is SpinBox)
	if child is SpinBox:
		var spin_box: SpinBox = child
		return spin_box
	return null


# --- 内部类 ---

class RejectedConfig:
	extends GFTweenActionConfig

	var invocations: int = 0

	func duplicate_config() -> GFTweenActionConfig:
		invocations += 1
		return self


class RejectedStep:
	extends GFTweenActionStep

	var invocations: int = 0

	func append_to_tween(_tween: Tween, _target: Object, _duration_scale: float = 1.0) -> Variant:
		invocations += 1
		return null
