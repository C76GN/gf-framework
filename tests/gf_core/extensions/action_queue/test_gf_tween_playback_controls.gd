# 验证配置化 Tween 的播放控制与原生 Tween 末态一致。
extends GutTest


# --- 公共方法 ---

func test_finish_relative_step_uses_run_start_instead_of_partial_value() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(0.5)
	assert_almost_eq(target.position.x, 5.0, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 10.0, 0.0001)


func test_finish_consecutive_relative_steps_preserves_each_step_start() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0, true)
	_add_step(config, ^"position:x", 5.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(1.5)
	assert_almost_eq(target.position.x, 12.5, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 15.0, 0.0001)


func test_finish_parallel_independent_properties_uses_original_bases() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0, true)
	_add_step(config, ^"rotation", 2.0, true, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(0.5)
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_almost_eq(target.rotation, 1.0, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 10.0, 0.0001)
	assert_almost_eq(target.rotation, 2.0, 0.0001)


func test_finish_overlapping_vector_and_component_paths_preserves_sequence() -> void:
	var target: Node2D = _make_target()
	target.position = Vector2(2.0, 3.0)
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position", Vector2(10.0, 20.0), true)
	_add_step(config, ^"position:x", 5.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(1.5)
	assert_almost_eq(target.position.x, 14.5, 0.0001)
	assert_almost_eq(target.position.y, 23.0, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 17.0, 0.0001)
	assert_almost_eq(target.position.y, 23.0, 0.0001)


func test_finish_finite_relative_loops_matches_native_natural_completion() -> void:
	var expected_target: Node2D = _make_target()
	var native: Tween = expected_target.create_tween()
	var _loops: Tween = native.set_loops(3)
	var first: PropertyTweener = native.tween_property(expected_target, ^"position:x", 10.0, 1.0)
	var _first_relative: PropertyTweener = first.as_relative().set_trans(Tween.TRANS_LINEAR)
	var second: PropertyTweener = native.tween_property(expected_target, ^"position:x", 5.0, 1.0)
	var _second_relative: PropertyTweener = second.as_relative().set_trans(Tween.TRANS_LINEAR)
	watch_signals(native)
	native.pause()
	for _index: int in range(16):
		var advancing: bool = native.custom_step(0.5)
		if not advancing:
			break
	assert_signal_emit_count(native, "finished", 1)

	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.loop_count = 3
	_add_step(config, ^"position:x", 10.0, true)
	_add_step(config, ^"position:x", 5.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(2.5)

	action.finish()

	assert_almost_eq(target.position.x, expected_target.position.x, 0.0001)


func test_finish_skips_pending_markers_and_completes_exactly_once() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0, true)
	config.steps[0].marker_id = &"arrived"
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(0.5)

	action.finish()
	action.finish()

	assert_signal_emit_count(action, "marker_reached", 0)
	assert_signal_emit_count(action, "_action_completed", 1)
	assert_almost_eq(target.position.x, 10.0, 0.0001)
	assert_false(tween.is_valid())


func test_finish_setter_restart_keeps_new_tween_and_stops_old_terminal_writes() -> void:
	var host: Node2D = _make_target()
	var target: ReentrantTweenTarget = ReentrantTweenTarget.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"value", 10.0)
	_add_step(config, ^"other_value", 20.0)
	var replacement_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(replacement_config, ^"value", 100.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, host)
	var original: Tween = _execute_paused(action)
	if original == null:
		return
	var _advanced_original: bool = original.custom_step(0.5)
	target.on_terminal = func() -> void:
		action.config = replacement_config
		var _result: Variant = action.execute()
		action.pause()

	action.finish()

	var replacement: Tween = _get_paused_tween(action)
	if replacement == null:
		return
	assert_ne(replacement, original)
	assert_true(replacement.is_valid())
	assert_almost_eq(target.other_value, 0.0, 0.0001)
	var _advanced_replacement: bool = replacement.custom_step(0.5)
	assert_almost_eq(target.value, 55.0, 0.0001)
	action.finish()
	assert_almost_eq(target.value, 100.0, 0.0001)


func test_finish_called_from_native_property_setter_settles_once_after_callback() -> void:
	var host: Node2D = _make_target()
	var target: ReentrantTweenTarget = ReentrantTweenTarget.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"value", 10.0)
	_add_step(config, ^"other_value", 20.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, host)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	target.on_terminal = action.finish

	var _advanced: bool = tween.custom_step(1.0)
	await get_tree().process_frame

	assert_almost_eq(target.value, 10.0, 0.0001)
	assert_almost_eq(target.other_value, 20.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)
	assert_false(tween.is_valid())


func test_finish_parallel_setter_restart_blocks_remaining_native_tweeners() -> void:
	var host: Node2D = _make_target()
	var target: ReentrantTweenTarget = ReentrantTweenTarget.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"value", 10.0)
	_add_step(config, ^"other_value", 20.0, false, true)
	var replacement_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(replacement_config, ^"value", 100.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, host)
	var original: Tween = _execute_paused(action)
	if original == null:
		return
	var _advanced_original: bool = original.custom_step(0.5)
	assert_almost_eq(target.other_value, 10.0, 0.0001)
	target.on_terminal = func() -> void:
		action.config = replacement_config
		var _result: Variant = action.execute()
		action.pause()

	action.finish()

	var replacement: Tween = _get_paused_tween(action)
	if replacement == null:
		return
	assert_ne(replacement, original)
	assert_true(replacement.is_valid())
	assert_almost_eq(target.other_value, 10.0, 0.0001)
	var _advanced_replacement: bool = replacement.custom_step(0.5)
	assert_almost_eq(target.value, 55.0, 0.0001)
	action.finish()
	assert_almost_eq(target.value, 100.0, 0.0001)


func test_playback_control_requires_an_active_opted_in_run() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	_assert_controls_unavailable(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	_assert_controls_unavailable(action)
	assert_almost_eq(target.position.x, 0.0, 0.0001)
	action.cancel()

	config.enable_playback_control = true
	var controlled: Tween = _execute_paused(action)
	if controlled == null:
		return
	assert_true(action.can_control_playback())
	action.cancel()
	_assert_controls_unavailable(action)


func test_seek_pauses_without_markers_or_completion_even_at_endpoint() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	config.steps[0].marker_id = &"arrived"
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	assert_almost_eq(action.get_duration_seconds(), 1.0, 0.0001)
	assert_true(action.seek(0.75))
	assert_almost_eq(target.position.x, 7.5, 0.0001)
	assert_almost_eq(action.get_time_seconds(), 0.75, 0.0001)
	await get_tree().process_frame
	assert_almost_eq(target.position.x, 7.5, 0.0001)
	assert_almost_eq(action.get_time_seconds(), 0.75, 0.0001)
	assert_true(action.seek(1.0))
	assert_almost_eq(target.position.x, 10.0, 0.0001)
	assert_true(action.can_control_playback())
	assert_signal_emit_count(action, "marker_reached", 0)
	assert_signal_emit_count(action, "_action_completed", 0)

	action.finish()

	assert_signal_emit_count(action, "marker_reached", 0)
	assert_signal_emit_count(action, "_action_completed", 1)
	_assert_controls_unavailable(action)


func test_reverse_progress_and_finish_use_the_start_boundary() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var initial: Tween = _execute_paused(action)
	if initial == null:
		return
	assert_true(action.seek(0.8))
	assert_true(action.play_backward())
	var reverse_tween: Tween = _get_paused_tween(action)
	if reverse_tween == null:
		return
	var _advanced: bool = reverse_tween.custom_step(0.3)
	assert_almost_eq(action.get_time_seconds(), 0.5, 0.0001)
	assert_almost_eq(target.position.x, 5.0, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 0.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)
	_assert_controls_unavailable(action)


func test_tiny_controlled_duration_remains_active_and_seekable() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	config.steps[0].duration = 0.000001
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	assert_true(action.can_control_playback())
	assert_signal_emit_count(action, "_action_completed", 0)
	assert_almost_eq(action.get_duration_seconds(), 0.000001, 0.000000000001)

	assert_true(action.seek(0.0000005))

	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_almost_eq(action.get_time_seconds(), 0.0000005, 0.000000000001)
	assert_signal_emit_count(action, "_action_completed", 0)
	action.finish()
	assert_almost_eq(target.position.x, 10.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)


func test_seek_writes_only_final_sample_to_the_property_setter() -> void:
	var host: Node2D = _make_target()
	var target: RecordingTweenTarget = RecordingTweenTarget.new()
	target.value = 3.0
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"value", 13.0)
	_add_step(config, ^"value", 23.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, host)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	target.writes.clear()

	assert_true(action.seek(1.5))

	assert_eq(target.writes.size(), 1)
	assert_almost_eq(target.value, 18.0, 0.0001)
	if not target.writes.is_empty():
		assert_almost_eq(target.writes[0], 18.0, 0.0001)
	action.cancel()


func test_controlled_run_freezes_source_steps_config_and_curve() -> void:
	var target: Node2D = _make_target()
	var curve: Curve = Curve.new()
	var _first_point: int = curve.add_point(Vector2.ZERO)
	var _middle_point: int = curve.add_point(Vector2(0.5, 0.25))
	var _last_point: int = curve.add_point(Vector2.ONE)
	var original_midpoint: float = curve.sample_baked(0.5)
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	var step: GFTweenActionStep = config.steps[0]
	step.easing_curve = curve
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	step.target_value = 999.0
	step.duration = 20.0
	step.delay = 2.0
	curve.set_point_value(1, 0.75)
	config.duration_scale = 2.0
	config.loop_count = 3
	config.enable_playback_control = false
	config.restore_initial_values_on_finish = true
	config.steps.clear()

	assert_true(action.seek(0.5))

	assert_almost_eq(action.get_duration_seconds(), 1.0, 0.0001)
	assert_almost_eq(target.position.x, original_midpoint * 10.0, 0.0001)
	action.finish()
	assert_almost_eq(target.position.x, 10.0, 0.0001)


func test_forward_marker_crossing_occurs_once_per_execution_generation() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	_add_step(config, ^"position:x", 20.0)
	config.steps[0].marker_id = &"first"
	config.steps[1].marker_id = &"last"
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var initial: Tween = _execute_paused(action)
	if initial == null:
		return
	assert_true(action.seek(0.5))
	_advance_forward(action, 0.75)
	assert_signal_emit_count(action, "marker_reached", 1)
	assert_true(action.seek(0.25))
	_advance_forward(action, 1.0)
	assert_signal_emit_count(action, "marker_reached", 1)
	assert_true(action.play_backward())
	var reverse_tween: Tween = _get_paused_tween(action)
	if reverse_tween == null:
		return
	var _advanced_reverse: bool = reverse_tween.custom_step(0.5)
	assert_signal_emit_count(action, "marker_reached", 1)
	action.finish()
	assert_signal_emit_count(action, "marker_reached", 1)

	var restarted: Tween = _execute_paused(action)
	if restarted == null:
		return
	_advance_forward(action, 1.25)
	assert_signal_emit_count(action, "marker_reached", 2)
	action.cancel()


func test_seek_past_marker_skips_it_even_after_seeking_back() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	_add_step(config, ^"position:x", 10.0)
	_add_step(config, ^"position:x", 20.0)
	config.steps[0].marker_id = &"first"
	config.steps[1].marker_id = &"last"
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var initial: Tween = _execute_paused(action)
	if initial == null:
		return
	assert_true(action.seek(1.25))
	assert_true(action.seek(0.0))
	_advance_forward(action, 1.5)
	assert_signal_emit_count(action, "marker_reached", 0)
	action.finish()
	assert_signal_emit_count(action, "marker_reached", 0)
	assert_almost_eq(target.position.x, 20.0, 0.0001)


func test_ping_pong_loop_includes_both_directions_and_finishes_at_initial_value() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = _make_controlled_config()
	config.ping_pong = true
	config.loop_count = 2
	_add_step(config, ^"position:x", 10.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	assert_almost_eq(action.get_duration_seconds(), 4.0, 0.0001)
	assert_true(action.seek(1.5))
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_true(action.seek(3.5))
	assert_almost_eq(target.position.x, 5.0, 0.0001)

	action.finish()

	assert_almost_eq(target.position.x, 0.0, 0.0001)
	_assert_controls_unavailable(action)


func test_scope_replacement_preserves_current_value_and_releases_old_controls() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"position:x", 10.0)
	old_config.restore_initial_values_on_cancel = true
	old_config.restore_initial_values_on_finish = true
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config)
	old_action.replacement_scope = scope
	var original: Tween = _execute_paused(old_action)
	if original == null:
		return
	assert_true(old_action.can_control_playback())
	assert_true(old_action.seek(0.5))
	var new_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(new_config, ^"position:x", 20.0)
	var replacement: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, new_config)
	replacement.replacement_scope = scope
	var replacement_tween: Tween = _execute_paused(replacement)
	if replacement_tween == null:
		return

	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_false(original.is_valid())
	_assert_controls_unavailable(old_action)
	assert_true(replacement.seek(0.5))
	assert_almost_eq(target.position.x, 12.5, 0.0001)
	old_action.cancel()
	old_action.finish()
	assert_almost_eq(target.position.x, 12.5, 0.0001)
	replacement.finish()
	assert_almost_eq(target.position.x, 20.0, 0.0001)


func test_scope_rejects_empty_replacement_without_stopping_current_run() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	var current: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	current.replacement_scope = scope
	var original: Tween = _execute_paused(current)
	if original == null:
		return
	assert_true(current.seek(0.25))
	var rejected: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, GFTweenActionConfig.new())
	rejected.replacement_scope = scope

	var result: Variant = rejected.execute()

	assert_true(result == null)
	assert_true(current.can_control_playback())
	assert_almost_eq(current.get_time_seconds(), 0.25, 0.0001)
	assert_true(current.seek(0.75))
	assert_almost_eq(target.position.x, 7.5, 0.0001)
	current.cancel()


func test_scope_rejects_unbounded_replacement_before_retiring_current_run() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	var current: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	current.replacement_scope = scope
	var initial: Tween = _execute_paused(current)
	if initial == null:
		return
	assert_true(current.seek(0.25))
	var invalid_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(invalid_config, ^"position:x", 20.0)
	invalid_config.loop_count = 0
	var rejected: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, invalid_config)
	rejected.replacement_scope = scope

	var result: Variant = rejected.execute()

	assert_true(result == null)
	assert_push_warning_count(1)
	assert_true(current.can_control_playback())
	assert_true(current.seek(0.75))
	assert_almost_eq(target.position.x, 7.5, 0.0001)
	current.cancel()


func test_scope_component_replacement_stops_root_writer_and_preserves_other_components() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var root_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(root_config, ^"position", Vector2(10.0, 20.0))
	var root_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, root_config)
	root_action.replacement_scope = scope
	var initial: Tween = _execute_paused(root_action)
	if initial == null:
		return
	assert_true(root_action.seek(0.5))
	var component_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(component_config, ^"position:x", 20.0)
	var component: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, component_config)
	component.replacement_scope = scope
	var replacement: Tween = _execute_paused(component)
	if replacement == null:
		return

	_assert_controls_unavailable(root_action)
	assert_true(component.seek(0.5))
	assert_almost_eq(target.position.x, 12.5, 0.0001)
	assert_almost_eq(target.position.y, 10.0, 0.0001)
	component.finish()


func test_scope_keeps_distinct_property_roots_independently_controllable() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var position_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(position_config, ^"position:x", 10.0)
	var position_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, position_config)
	position_action.replacement_scope = scope
	var position_tween: Tween = _execute_paused(position_action)
	if position_tween == null:
		return
	var rotation_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(rotation_config, ^"rotation", 2.0)
	var rotation_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, rotation_config)
	rotation_action.replacement_scope = scope
	var rotation_tween: Tween = _execute_paused(rotation_action)
	if rotation_tween == null:
		return

	assert_true(position_action.seek(0.75))
	assert_true(rotation_action.seek(0.5))
	assert_almost_eq(target.position.x, 7.5, 0.0001)
	assert_almost_eq(target.rotation, 1.0, 0.0001)
	position_action.finish()
	assert_true(rotation_action.can_control_playback())
	rotation_action.finish()


func test_scope_dispose_stops_real_actions_without_restoring_captured_values() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	config.restore_initial_values_on_cancel = true
	config.restore_initial_values_on_finish = true
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	action.replacement_scope = scope
	watch_signals(action)
	var initial: Tween = _execute_paused(action)
	if initial == null:
		return
	assert_true(action.seek(0.5))

	scope.dispose()
	scope.dispose()

	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)
	assert_eq(scope.get_active_count(), 0)
	_assert_controls_unavailable(action)
	action.finish()
	assert_almost_eq(target.position.x, 5.0, 0.0001)


func test_scope_later_claim_from_old_completion_wins_over_outer_replacement() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"position:x", 10.0)
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config)
	old_action.replacement_scope = scope
	var original: Tween = _execute_paused(old_action)
	if original == null:
		return
	assert_true(old_action.seek(0.5))
	var outer_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(outer_config, ^"position:x", 20.0)
	var outer: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, outer_config)
	outer.replacement_scope = scope
	var later_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(later_config, ^"position:x", 30.0)
	var later: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, later_config)
	later.replacement_scope = scope
	var _connected: Error = old_action.connect(&"_action_completed", func() -> void:
		var _result: Variant = later.execute()
		later.pause()
	)

	var _outer_result: Variant = outer.execute()

	assert_true(later.can_control_playback())
	_assert_controls_unavailable(outer)
	assert_true(later.seek(0.5))
	assert_almost_eq(target.position.x, 17.5, 0.0001)
	outer.cancel()
	old_action.finish()
	assert_almost_eq(target.position.x, 17.5, 0.0001)
	later.finish()
	assert_almost_eq(target.position.x, 30.0, 0.0001)


func test_scope_takeover_from_setter_stops_remaining_old_root_writes() -> void:
	var host: Node2D = _make_target()
	var target: ReentrantTweenTarget = ReentrantTweenTarget.new()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"value", 10.0)
	_add_step(old_config, ^"other_value", 20.0, false, true)
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config, host)
	old_action.replacement_scope = scope
	var old_tween: Tween = _execute_paused(old_action)
	if old_tween == null:
		return
	assert_true(old_action.seek(0.5))
	var replacement_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(replacement_config, ^"value", 30.0)
	var replacement: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, replacement_config, host)
	replacement.replacement_scope = scope
	target.on_terminal = func() -> void:
		var _result: Variant = replacement.execute()
		replacement.pause()

	assert_false(old_action.seek(1.0))

	_assert_controls_unavailable(old_action)
	assert_almost_eq(target.other_value, 10.0, 0.0001)
	assert_true(replacement.can_control_playback())
	assert_true(replacement.seek(0.5))
	assert_almost_eq(target.value, 20.0, 0.0001)
	replacement.finish()


func test_scope_host_exit_releases_running_action_and_its_lease() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	action.replacement_scope = scope
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	assert_eq(scope.get_active_count(), 1)

	remove_child(target)

	assert_eq(scope.get_active_count(), 0)
	assert_signal_emit_count(action, "_action_completed", 1)
	_assert_controls_unavailable(action)
	assert_false(tween.is_valid())


func test_factory_playback_flags_survive_config_duplication_and_drive_round_trip() -> void:
	var target: Node2D = _make_target()
	var action: GFConfiguredTweenAction = GFAction.tween(target, ^"position:x", 10.0, 1.0, {
		"enable_playback_control": true,
		"ping_pong": true,
		"transition_type": Tween.TRANS_LINEAR,
	})
	assert_not_null(action)
	if action == null:
		return
	var copied: GFTweenActionConfig = action.config.duplicate_config()
	assert_not_null(copied)
	if copied == null:
		return
	assert_true(action.config.enable_playback_control)
	assert_true(action.config.ping_pong)
	assert_true(copied.enable_playback_control)
	assert_true(copied.ping_pong)
	action.config.enable_playback_control = false
	action.config.ping_pong = false
	var copied_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, copied)
	var tween: Tween = _execute_paused(copied_action)
	if tween == null:
		return

	assert_almost_eq(copied_action.get_duration_seconds(), 2.0, 0.0001)
	assert_true(copied_action.seek(1.5))
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	copied_action.finish()
	assert_almost_eq(target.position.x, 0.0, 0.0001)


func test_factory_rejects_invalid_scope_and_scope_option_enables_real_playback() -> void:
	var target: Node2D = _make_target()
	var rejected: GFConfiguredTweenAction = GFAction.tween(target, ^"position:x", 10.0, 1.0, {
		"replacement_scope": RefCounted.new(),
	})
	assert_null(rejected)
	assert_push_warning_count(1)
	assert_almost_eq(target.position.x, 0.0, 0.0001)
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var action: GFConfiguredTweenAction = GFAction.tween(target, ^"position:x", 10.0, 1.0, {
		"replacement_scope": scope,
		"transition_type": Tween.TRANS_LINEAR,
	})
	assert_not_null(action)
	if action == null:
		return
	assert_same(action.replacement_scope, scope)
	assert_false(action.config.enable_playback_control)
	assert_true(action.config.get_validation_report(target).is_ok())
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return

	assert_eq(scope.get_active_count(), 1)
	assert_true(action.can_control_playback())
	assert_true(action.seek(0.5))
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	action.finish()
	assert_eq(scope.get_active_count(), 0)


func test_config_preflight_distinguishes_controlled_limits_from_legacy_step_errors() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(config, ^"position:x", 10.0)
	_add_step(config, ^"position:y", 20.0, false, true)
	assert_true(config.get_validation_report(target).is_ok())
	config.enable_playback_control = true
	_assert_validation_kind(config.get_validation_report(target), "invalid_playback_plan")
	config.enable_playback_control = false
	config.ping_pong = true
	_assert_validation_kind(config.get_validation_report(target), "invalid_playback_plan")
	config.steps[1].parallel = false
	config.loop_count = 0
	_assert_validation_kind(config.get_validation_report(target), "invalid_playback_plan")
	config.loop_count = 1
	assert_true(config.get_validation_report(target).is_ok())
	config.ping_pong = false
	config.steps[1].property_name = ^"missing_property"
	_assert_validation_kind(config.get_validation_report(target), "invalid_step")
	assert_eq(target.position, Vector2.ZERO)


func test_cancel_in_pending_claim_completion_leaves_no_incoming_lease() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"position:x", 10.0)
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config)
	old_action.replacement_scope = scope
	var old_tween: Tween = _execute_paused(old_action)
	if old_tween == null:
		return
	assert_true(old_action.seek(0.5))
	var incoming_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(incoming_config, ^"position:x", 20.0)
	var incoming: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, incoming_config)
	incoming.replacement_scope = scope
	var _connected: Error = old_action.connect(&"_action_completed", incoming.cancel)

	var result: Variant = incoming.execute()

	assert_true(result == null)
	assert_eq(scope.get_active_count(), 0)
	_assert_controls_unavailable(incoming)
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	scope.dispose()


func test_host_exit_in_pending_claim_completion_rejects_without_creating_tween() -> void:
	var old_host: Node2D = _make_target()
	var incoming_host: Node2D = _make_target()
	var target: RecordingTweenTarget = RecordingTweenTarget.new()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"value", 10.0)
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config, old_host)
	old_action.replacement_scope = scope
	var old_tween: Tween = _execute_paused(old_action)
	if old_tween == null:
		return
	assert_true(old_action.seek(0.5))
	var incoming_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(incoming_config, ^"value", 20.0)
	var incoming: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, incoming_config, incoming_host)
	incoming.replacement_scope = scope
	var _connected: Error = old_action.connect(&"_action_completed", func() -> void:
		remove_child(incoming_host)
	)

	var result: Variant = incoming.execute()

	assert_true(result == null)
	assert_eq(scope.get_active_count(), 0)
	assert_true(incoming.get(&"_active_tween") == null)
	assert_almost_eq(target.value, 5.0, 0.0001)
	_assert_controls_unavailable(incoming)
	assert_engine_error_count(0)
	scope.dispose()


func test_reentrant_cancel_completes_after_all_restores_without_overwriting_callback() -> void:
	var host: Node2D = _make_target()
	var target: RestoreOrderTweenTarget = RestoreOrderTweenTarget.new()
	var config: GFTweenActionConfig = _make_controlled_config()
	config.restore_initial_values_on_cancel = true
	_add_step(config, ^"first", 10.0)
	_add_step(config, ^"second", 20.0, false, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, host)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	assert_true(action.seek(0.5))
	assert_almost_eq(target.first, 5.0, 0.0001)
	assert_almost_eq(target.second, 10.0, 0.0001)
	var completion_states: Array[Vector2] = []
	var _connected: Error = action.connect(&"_action_completed", func() -> void:
		completion_states.append(Vector2(target.first, target.second))
		target.second = 99.0
	)
	target.on_write = action.cancel

	action.cancel()

	assert_eq(completion_states, [Vector2.ZERO])
	assert_almost_eq(target.first, 0.0, 0.0001)
	assert_almost_eq(target.second, 99.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)
	_assert_controls_unavailable(action)


func test_same_incoming_restart_during_pending_claim_preserves_new_run() -> void:
	var target: Node2D = _make_target()
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	var old_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(old_config, ^"position:x", 10.0)
	var old_action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, old_config)
	old_action.replacement_scope = scope
	var old_tween: Tween = _execute_paused(old_action)
	if old_tween == null:
		return
	assert_true(old_action.seek(0.5))
	var incoming_config: GFTweenActionConfig = GFTweenActionConfig.new()
	_add_step(incoming_config, ^"position:x", 20.0)
	var incoming: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, incoming_config)
	incoming.replacement_scope = scope
	var nested_results: Array[bool] = []
	var _connected: Error = old_action.connect(&"_action_completed", func() -> void:
		var nested_result: Variant = incoming.execute()
		nested_results.append(nested_result is Signal)
		incoming.pause()
	)

	var outer_result: Variant = incoming.execute()

	assert_true(outer_result == null)
	assert_eq(nested_results, [true])
	assert_eq(scope.get_active_count(), 1)
	assert_true(incoming.can_control_playback())
	assert_true(incoming.seek(0.5))
	assert_almost_eq(target.position.x, 12.5, 0.0001)
	scope.dispose()


func test_native_finish_over_expansion_budget_stops_at_current_value_and_completes_once() -> void:
	var target: Node2D = _make_target()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.loop_count = 4097
	_add_step(config, ^"position:x", 10.0, true)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config)
	watch_signals(action)
	var tween: Tween = _execute_paused(action)
	if tween == null:
		return
	var _advanced: bool = tween.custom_step(0.5)
	assert_almost_eq(target.position.x, 5.0, 0.0001)

	action.finish()
	action.finish()

	assert_push_warning_count(1)
	assert_almost_eq(target.position.x, 5.0, 0.0001)
	assert_signal_emit_count(action, "_action_completed", 1)
	assert_false(tween.is_valid())


# --- 私有/辅助方法 ---

func _make_target() -> Node2D:
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	return target


func _make_controlled_config() -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.enable_playback_control = true
	return config


func _assert_validation_kind(report: GFValidationReport, kind: String) -> void:
	assert_false(report.is_ok())
	assert_eq(GFVariantData.get_option_int(report.get_issue_counts_by_kind(), kind, -1), 1)


func _assert_controls_unavailable(action: GFConfiguredTweenAction) -> void:
	assert_false(action.can_control_playback())
	assert_false(action.seek(0.5))
	assert_false(action.play_forward())
	assert_false(action.play_backward())


func _advance_forward(action: GFConfiguredTweenAction, seconds: float) -> void:
	assert_true(action.play_forward())
	var tween: Tween = _get_paused_tween(action)
	if tween != null:
		var _advanced: bool = tween.custom_step(seconds)


func _add_step(
	config: GFTweenActionConfig,
	property_path: NodePath,
	value: Variant,
	relative: bool = false,
	parallel: bool = false
) -> void:
	var step: GFTweenActionStep = config.add_property_step(property_path, value, 1.0)
	step.as_relative = relative
	step.parallel = parallel
	step.transition_type = Tween.TRANS_LINEAR


func _execute_paused(action: GFConfiguredTweenAction) -> Tween:
	var result: Variant = action.execute()
	assert_true(result is Signal)
	return _get_paused_tween(action)


func _get_paused_tween(action: GFConfiguredTweenAction) -> Tween:
	var tween: Tween = _get_active_tween(action)
	if tween != null:
		tween.pause()
	return tween


func _get_active_tween(action: GFConfiguredTweenAction) -> Tween:
	var active_value: Variant = action.get(&"_active_tween")
	if not (active_value is Tween):
		fail_test("Executing a timed action must create a native Tween.")
		return null
	var tween: Tween = active_value
	return tween


# --- 内部类 ---

class ReentrantTweenTarget:
	extends RefCounted

	var value: float:
		get:
			return _value
		set(next_value):
			_value = next_value
			if is_equal_approx(next_value, 10.0) and on_terminal.is_valid():
				var callback: Callable = on_terminal
				on_terminal = Callable()
				var _result: Variant = callback.call()
	var other_value: float = 0.0
	var on_terminal: Callable
	var _value: float = 0.0


class RecordingTweenTarget:
	extends RefCounted

	var value: float:
		get:
			return _value
		set(next_value):
			_value = next_value
			writes.append(next_value)
	var writes: Array[float] = []
	var _value: float = 0.0


class RestoreOrderTweenTarget:
	extends RefCounted

	var first: float:
		get:
			return _first
		set(next_value):
			_first = next_value
			if on_write.is_valid():
				var callback: Callable = on_write
				on_write = Callable()
				var _result: Variant = callback.call()
	var second: float = 0.0
	var on_write: Callable
	var _first: float = 0.0
