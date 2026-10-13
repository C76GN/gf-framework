@tool

# 准备快照与播放时钟分离；使用真实树、公开工具协议和适配器租约。
extends GutTest


func test_native_prepare_allows_seek_without_playing_and_keeps_source_frozen() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0, 1.0)
	var viewport: GFTweenPreviewViewport = _viewport(config)
	if not _prepare(viewport):
		return
	assert_eq(viewport.get_state(), &"ready")
	assert_true(viewport.has_session())
	assert_eq(viewport.get_time_seconds(), 0.0)
	assert_eq(_position(viewport), Vector2.ZERO)
	viewport.advance(0.5)
	assert_eq(viewport.get_time_seconds(), 0.0)
	assert_eq(_position(viewport), Vector2.ZERO)
	config.steps[0].target_value = 100.0
	config.steps[0].duration = 2.0
	assert_true(viewport.play())
	assert_eq(viewport.get_duration_seconds(), 1.0)
	viewport.advance(0.25)
	assert_almost_eq(_position(viewport).x, 2.5, 0.001)
	assert_true(viewport.seek(0.5))
	assert_eq(viewport.get_state(), &"paused")
	assert_almost_eq(_position(viewport).x, 5.0, 0.001)
	assert_true(viewport.play())
	viewport.advance(0.5)
	assert_eq(viewport.get_state(), &"finished")
	assert_eq(_position(viewport), Vector2(10.0, 0.0))
	viewport.dispose_preview()


func test_controlled_prepare_supports_direction_and_curve_snapshot_before_play() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0, 1.0)
	config.enable_playback_control = true
	var curve: Curve = Curve.new()
	var _first_point: int = curve.add_point(Vector2.ZERO)
	var _last_point: int = curve.add_point(Vector2.ONE)
	curve.set_point_right_mode(0, Curve.TANGENT_LINEAR)
	curve.set_point_left_mode(1, Curve.TANGENT_LINEAR)
	config.steps[0].easing_curve = curve
	var viewport: GFTweenPreviewViewport = _viewport(config)
	if not _prepare(viewport):
		return
	assert_true(viewport.is_controlled_session())
	curve.set_point_value(1, 0.0)
	assert_true(viewport.seek(0.5))
	assert_almost_eq(_position(viewport).x, 5.0, 0.02)
	assert_true(viewport.play_direction(true))
	viewport.advance(0.25)
	assert_almost_eq(_position(viewport).x, 2.5, 0.02)
	assert_almost_eq(viewport.get_time_seconds(), 0.25, 0.001)
	viewport.dispose_preview()


func test_positive_prepare_uses_native_zero_delta_or_controlled_time_zero_pose() -> void:
	var native_values: Dictionary = _native_prefix_at_zero()
	var native_scale_value: Variant = native_values.get("scale")
	var native_color_value: Variant = native_values.get("modulate")
	assert_true(native_scale_value is Vector2)
	assert_true(native_color_value is Color)
	if not (native_scale_value is Vector2) or not (native_color_value is Color):
		return
	var native_scale: Vector2 = native_scale_value
	var native_color: Color = native_color_value
	for controlled: bool in [false, true]:
		var config: GFTweenActionConfig = GFTweenActionConfig.new()
		config.enable_playback_control = controlled
		var _initial_scale: GFTweenActionStep = config.add_property_step(^"scale", Vector2(1.12, 1.12), 0.0)
		var initial_alpha: GFTweenActionStep = config.add_property_step(^"modulate:a", 1.0, 0.0)
		initial_alpha.parallel = true
		var scale_step: GFTweenActionStep = config.add_property_step(^"scale", Vector2.ONE, 0.85)
		scale_step.transition_type = Tween.TRANS_LINEAR
		var alpha_step: GFTweenActionStep = config.add_property_step(^"modulate:a", 0.65, 0.85)
		alpha_step.parallel = true
		alpha_step.transition_type = Tween.TRANS_LINEAR
		var viewport: GFTweenPreviewViewport = _viewport(config, 1)
		assert_true(viewport.set_initial_value(&"modulate", Color(1.0, 1.0, 1.0, 0.2)))
		if not _prepare(viewport):
			return
		var prepared_values: Dictionary = viewport.get_current_values()
		var scale_value: Variant = prepared_values.get("scale")
		var color_value: Variant = prepared_values.get("modulate")
		assert_true(scale_value is Vector2)
		assert_true(color_value is Color)
		if scale_value is Vector2 and color_value is Color:
			var ready_scale: Vector2 = scale_value
			var ready_color: Color = color_value
			if controlled:
				assert_eq(ready_scale, Vector2(1.12, 1.12))
				assert_eq(ready_color.a, 1.0)
			else:
				assert_eq(ready_scale, native_scale, "Native prepare matches the independent zero-delta Tween")
				assert_eq(ready_color, native_color)
		assert_eq(viewport.get_state(), &"ready")
		assert_eq(viewport.get_time_seconds(), 0.0)
		viewport.advance(0.4)
		assert_eq(viewport.get_current_values(), prepared_values)
		assert_eq(viewport.get_time_seconds(), 0.0)
		assert_true(viewport.seek(0.0))
		assert_eq(viewport.get_current_values(), prepared_values, "Ready and seek(0) show the same captured pose")
		if not controlled:
			var inspected_values: Dictionary = viewport.get_current_values()
			var inspected_scale_value: Variant = inspected_values.get("scale")
			var inspected_color_value: Variant = inspected_values.get("modulate")
			assert_true(inspected_scale_value is Vector2)
			assert_true(inspected_color_value is Color)
			if inspected_scale_value is Vector2 and inspected_color_value is Color:
				var inspected_scale: Vector2 = inspected_scale_value
				var inspected_color: Color = inspected_color_value
				assert_eq(inspected_scale, native_scale)
				assert_eq(inspected_color, native_color)
		viewport.dispose_preview()


func test_positive_numeric_prepare_samples_instant_prefix_using_frozen_initials() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("prepare_instant_prefix"), RecordingAdapter.new())
	assert_not_null(handle)
	var config: GFTweenActionConfig = _config(^"progress", 0.25, 0.0)
	config.steps[0].as_relative = true
	var step: GFTweenActionStep = config.add_property_step(^"progress", 1.0, 1.0)
	step.transition_type = Tween.TRANS_LINEAR
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(config, &"prepare_instant_prefix"))
	assert_true(viewport.set_initial_value(&"progress", 0.25))
	if not _prepare(viewport):
		handle.release()
		return
	assert_eq(_progress(viewport), 0.5)
	assert_eq(viewport.get_state(), &"ready")
	assert_eq(viewport.get_time_seconds(), 0.0)
	viewport.advance(0.4)
	assert_eq(_progress(viewport), 0.5)
	assert_eq(viewport.get_time_seconds(), 0.0)
	assert_true(viewport.seek(0.0))
	assert_eq(_progress(viewport), 0.5)
	assert_true(viewport.play())
	viewport.advance(0.5)
	assert_almost_eq(_progress(viewport), 0.75, 0.001)
	viewport.dispose_preview()
	handle.release()


func test_stop_and_reset_can_prepare_new_source_without_starting_clock() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 10.0, 1.0)
	var viewport: GFTweenPreviewViewport = _viewport(config)
	if not _prepare(viewport):
		return
	assert_true(viewport.seek(0.5))
	viewport.stop()
	config.steps[0].target_value = 20.0
	assert_true(_prepare(viewport))
	assert_eq(viewport.get_state(), &"ready")
	assert_eq(_position(viewport), Vector2.ZERO)
	assert_true(viewport.seek(0.5))
	assert_almost_eq(_position(viewport).x, 10.0, 0.001)
	viewport.reset_preview()
	assert_false(viewport.has_session())
	assert_true(_prepare(viewport))
	assert_eq(viewport.get_time_seconds(), 0.0)
	assert_eq(viewport.get_state(), &"ready")
	viewport.dispose_preview()


func test_numeric_prepare_captures_overridden_initials_without_advancing() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("prepare_initials"), adapter)
	assert_not_null(handle)
	var viewport: GFTweenPreviewViewport = _viewport()
	var config: GFTweenActionConfig = _config(^"progress", 1.0, 1.0)
	assert_true(viewport.configure_adapter(config, &"prepare_initials"))
	assert_true(viewport.set_initial_value(&"progress", 0.25))
	if not _prepare(viewport):
		handle.release()
		return
	assert_eq(viewport.get_state(), &"ready")
	assert_true(viewport.has_session())
	assert_eq(_progress(viewport), 0.25)
	viewport.advance(0.5)
	assert_eq(_progress(viewport), 0.25)
	config.steps[0].target_value = 0.5
	assert_true(viewport.seek(0.5))
	assert_almost_eq(_progress(viewport), 0.625, 0.001)
	assert_true(viewport.play())
	viewport.advance(0.5)
	assert_eq(_progress(viewport), 1.0)
	viewport.dispose_preview()
	handle.release()


func test_prepare_uses_explicit_registry_and_rejects_replacement_lease() -> void:
	var viewport: GFTweenPreviewViewport = _viewport()
	if not _has_prepare(viewport):
		return
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("isolated_prepare"), adapter)
	assert_not_null(handle)
	var configured: Variant = viewport.call(&"configure_adapter", _config(^"progress", 1.0, 1.0), &"isolated_prepare", registry)
	assert_true(configured is bool)
	if not (configured is bool):
		handle.release()
		return
	var accepted: bool = configured
	assert_true(accepted)
	assert_true(_prepare(viewport))
	handle.release()
	var replacement: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("isolated_prepare"), RecordingAdapter.new())
	assert_not_null(replacement)
	assert_false(viewport.seek(0.5))
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	assert_true(viewport.get_current_values().is_empty())
	viewport.dispose_preview()
	replacement.release()


func test_numeric_prepare_does_not_publish_ready_after_hook_reconfigures() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("prepare_reentry"), adapter)
	assert_not_null(handle)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(_config(^"progress", 1.0, 1.0), &"prepare_reentry"))
	if not _has_prepare(viewport):
		handle.release()
		return
	adapter.callback = func() -> void: viewport.configure(_config(^"position:x", 20.0, 1.0))
	assert_false(_prepare_result(viewport))
	assert_eq(viewport.get_state(), &"idle")
	assert_false(viewport.has_session())
	assert_eq(_position(viewport), Vector2.ZERO)
	viewport.dispose_preview()
	handle.release()


func test_prepare_returns_false_when_ready_notification_changes_source() -> void:
	var viewport: GFTweenPreviewViewport = _viewport(_config(^"position:x", 10.0, 1.0))
	if not _has_prepare(viewport):
		return
	var armed: Array[bool] = [true]
	var _connected: int = viewport.state_changed.connect(func() -> void:
		if armed[0] and viewport.get_state() == &"ready":
			armed[0] = false
			viewport.configure(_config(^"position:x", 20.0, 1.0))
	)
	assert_false(_prepare_result(viewport))
	assert_eq(viewport.get_state(), &"idle")
	assert_false(viewport.has_session())
	viewport.dispose_preview()


func test_numeric_seek_revoked_by_state_notification_rejects_and_releases_sample() -> void:
	await _check_numeric_notification_revocation(&"seek")


func test_numeric_direction_revoked_by_state_notification_rejects_and_releases_sample() -> void:
	await _check_numeric_notification_revocation(&"direction")


func test_numeric_play_revoked_by_state_notification_rejects_and_releases_sample() -> void:
	await _check_numeric_notification_revocation(&"play")


func test_controlled_rotation_degrees_prepare_uses_nonzero_2d_initial_pose() -> void:
	var config: GFTweenActionConfig = _config(^"rotation_degrees", 90.0, 1.0)
	config.enable_playback_control = true
	var target: Node2D = Node2D.new()
	target.rotation = deg_to_rad(30.0)
	add_child_autofree(target)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, target)
	var completion: Variant = action.execute()
	assert_true(completion is Signal)
	action.pause()
	var viewport: GFTweenPreviewViewport = _viewport(config)
	assert_true(viewport.set_initial_value(&"rotation", deg_to_rad(30.0)))
	if not _prepare(viewport):
		action.cancel()
		return
	assert_almost_eq(_rotation_2d(viewport), target.rotation, 0.00001, "Prepared pose matches the real runtime target")
	assert_true(action.seek(0.5))
	assert_true(viewport.seek(0.5))
	assert_almost_eq(target.rotation_degrees, 60.0, 0.001)
	assert_almost_eq(_rotation_2d(viewport), target.rotation, 0.00001)
	viewport.dispose_preview()
	action.cancel()


func test_controlled_rotation_degrees_component_preserves_nonzero_3d_initial_pose() -> void:
	var config: GFTweenActionConfig = _config(^"rotation_degrees:y", 80.0, 1.0)
	config.enable_playback_control = true
	var initial_rotation: Vector3 = Vector3(deg_to_rad(10.0), deg_to_rad(20.0), deg_to_rad(30.0))
	var target: Node3D = Node3D.new()
	target.rotation = initial_rotation
	add_child_autofree(target)
	var action: GFConfiguredTweenAction = GFConfiguredTweenAction.new(target, config, target)
	var completion: Variant = action.execute()
	assert_true(completion is Signal)
	action.pause()
	var viewport: GFTweenPreviewViewport = _viewport(config, 2)
	assert_true(viewport.set_initial_value(&"rotation", initial_rotation))
	if not _prepare(viewport):
		action.cancel()
		return
	var ready_rotation: Vector3 = _rotation_3d(viewport)
	assert_almost_eq(ready_rotation.x, target.rotation.x, 0.00001)
	assert_almost_eq(ready_rotation.y, target.rotation.y, 0.00001)
	assert_almost_eq(ready_rotation.z, target.rotation.z, 0.00001)
	assert_true(action.seek(0.5))
	assert_true(viewport.seek(0.5))
	var inspected_rotation: Vector3 = _rotation_3d(viewport)
	assert_almost_eq(target.rotation_degrees.y, 50.0, 0.001)
	assert_almost_eq(inspected_rotation.x, target.rotation.x, 0.00001)
	assert_almost_eq(inspected_rotation.y, target.rotation.y, 0.00001)
	assert_almost_eq(inspected_rotation.z, target.rotation.z, 0.00001)
	viewport.dispose_preview()
	action.cancel()


func test_native_zero_time_prepare_keeps_initials_until_inspection_or_play() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.0)
	config.steps[0].as_relative = true
	config.loop_count = 32
	config.restore_initial_values_on_finish = true
	var viewport: GFTweenPreviewViewport = _viewport(config)
	assert_true(viewport.set_initial_value(&"position", Vector2(2.0, 4.0)))
	if not _prepare(viewport):
		return
	assert_eq(viewport.get_state(), &"ready")
	assert_true(viewport.has_session())
	assert_eq(_position(viewport), Vector2(2.0, 4.0))
	viewport.advance(1.0)
	assert_eq(_position(viewport), Vector2(2.0, 4.0))
	assert_true(viewport.seek(0.0))
	assert_eq(_position(viewport), Vector2(5.0, 4.0))
	assert_true(viewport.seek(0.0))
	assert_eq(_position(viewport), Vector2(5.0, 4.0))
	assert_true(viewport.play())
	assert_eq(viewport.get_state(), &"finished")
	assert_eq(_position(viewport), Vector2(2.0, 4.0))
	assert_true(_prepare(viewport))
	assert_true(viewport.play())
	assert_eq(viewport.get_state(), &"finished")
	assert_eq(_position(viewport), Vector2(2.0, 4.0))
	viewport.dispose_preview()


func test_controlled_zero_time_prepare_rejects_without_partial_session() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 3.0, 0.0)
	config.enable_playback_control = true
	var viewport: GFTweenPreviewViewport = _viewport(config)
	if not _has_prepare(viewport):
		return
	assert_false(_prepare_result(viewport))
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	assert_false(viewport.get_error().is_empty())
	assert_eq(_position(viewport), Vector2.ZERO)
	viewport.dispose_preview()


func test_numeric_zero_time_prepare_rejects_without_partial_session() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("prepare_zero"), RecordingAdapter.new())
	assert_not_null(handle)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(_config(^"progress", 1.0, 0.0), &"prepare_zero"))
	if not _has_prepare(viewport):
		handle.release()
		return
	assert_false(_prepare_result(viewport))
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	assert_false(viewport.get_error().is_empty())
	assert_eq(_progress(viewport), 0.0)
	viewport.dispose_preview()
	handle.release()


func test_prepare_property_diagnostics_use_author_numbering_and_preview_scope() -> void:
	var config: GFTweenActionConfig = _config(^"position:x", 1.0, 1.0)
	var _unsupported_step: GFTweenActionStep = config.add_property_step(^"reveal_progress", 1.0, 1.0)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	assert_true(plan.error.begins_with("步骤 2："))
	assert_true(plan.error.contains("当前预览"))
	assert_true(plan.error.contains("reveal_progress"))
	assert_true(plan.steps.is_empty())


func test_panel_reprepare_retries_a_transient_factory_without_switching_target() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: TransientFactoryAdapter = TransientFactoryAdapter.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("prepare_panel_factory_retry"), adapter)
	assert_not_null(handle)
	if handle == null:
		return
	var config: GFTweenActionConfig = _config(^"progress", 1.0, 1.0)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(config, context)
	add_child_autofree(panel)
	assert_eq(adapter.factory_calls, 1)
	var target_selected: bool = context.get_target().get("id") == &"prepare_panel_factory_retry"
	assert_true(target_selected)
	var viewport_node: Node = panel.find_child("PreviewViewport", true, false)
	var button_node: Node = panel.find_child("Recapture", true, false)
	assert_true(viewport_node is GFTweenPreviewViewport)
	assert_true(button_node is Button)
	if not viewport_node is GFTweenPreviewViewport or not button_node is Button:
		panel.dispose_preview()
		handle.release()
		return
	var viewport: GFTweenPreviewViewport = viewport_node
	var button: Button = button_node
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	assert_true(button.is_visible_in_tree())
	assert_eq(button.text, "重新准备")
	assert_false(button.disabled, "A transient sample failure must leave an explicit retry available")
	await get_tree().create_timer(0.65).timeout
	panel.set_process(false)
	assert_eq(adapter.factory_calls, 1, "Background refresh must not loop the failing factory")
	adapter.factory_available = true
	button.pressed.emit()
	assert_eq(adapter.factory_calls, 2, "The actual reprepare button must retry the same selected factory")
	assert_true(viewport.has_session())
	assert_eq(viewport.get_state(), &"ready")
	assert_eq(viewport.get_time_seconds(), 0.0)
	assert_eq(_progress(viewport), 0.0)
	var target_preserved: bool = context.get_target().get("id") == &"prepare_panel_factory_retry"
	assert_true(target_preserved, "Retry must not require a target selection change")
	var sample_reference: WeakRef = adapter.sample_reference
	assert_not_null(sample_reference)
	panel.dispose_preview()
	handle.release()
	await get_tree().process_frame
	if sample_reference != null:
		var sample_released: bool = sample_reference.get_ref() == null
		assert_true(sample_released, "The recovered sample must be released with its panel")


func _has_prepare(viewport: GFTweenPreviewViewport) -> bool:
	var available: bool = viewport.has_method(&"prepare")
	assert_true(available, "Preparing a frozen inspection session must not require Play")
	return available


func _check_numeric_notification_revocation(operation: StringName) -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var id_text: String = "prepare_notification_" + String(operation)
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor(id_text), adapter)
	assert_not_null(handle)
	if handle == null:
		return
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(_config(^"progress", 1.0, 1.0), StringName(id_text)))
	if not _prepare(viewport):
		handle.release()
		return
	var sample_reference: WeakRef = adapter.sample_reference
	assert_not_null(sample_reference)
	var armed: Array[bool] = [true]
	var expected_state: StringName = &"paused" if operation == &"seek" else &"playing"
	var _connected: int = viewport.state_changed.connect(func() -> void:
		if armed[0] and viewport.get_state() == expected_state:
			armed[0] = false
			handle.release()
	)
	var accepted: bool = false
	match operation:
		&"seek":
			accepted = viewport.seek(0.5)
		&"direction":
			accepted = viewport.play_direction(false)
		&"play":
			accepted = viewport.play()
	assert_false(accepted, "An accepted state notification can revoke the current adapter lease")
	assert_false(handle.is_active())
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	assert_true(viewport.get_current_values().is_empty())
	await get_tree().process_frame
	var sample_released: bool = sample_reference.get_ref() == null
	assert_true(sample_released, "The invalidated owned sample must actually leave the tree")
	viewport.dispose_preview()
	handle.release()


func _native_prefix_at_zero() -> Dictionary:
	var target: ColorRect = ColorRect.new()
	target.scale = Vector2.ONE
	target.modulate = Color(1.0, 1.0, 1.0, 0.2)
	add_child_autofree(target)
	var tween: Tween = target.create_tween()
	tween.pause()
	var _ignore_time_scale: Tween = tween.set_ignore_time_scale(true)
	var _initial_scale: PropertyTweener = tween.tween_property(target, ^"scale", Vector2(1.12, 1.12), 0.0)
	var _initial_alpha: PropertyTweener = tween.parallel().tween_property(target, ^"modulate:a", 1.0, 0.0)
	var _scale_step: PropertyTweener = tween.tween_property(target, ^"scale", Vector2.ONE, 0.85).set_trans(Tween.TRANS_LINEAR)
	var _alpha_step: PropertyTweener = tween.parallel().tween_property(target, ^"modulate:a", 0.65, 0.85).set_trans(Tween.TRANS_LINEAR)
	var _still_playing: bool = tween.custom_step(0.0)
	assert_eq(tween.get_total_elapsed_time(), 0.0)
	assert_false(tween.is_running())
	var values: Dictionary = {"scale": target.scale, "modulate": target.modulate}
	assert_eq(target.scale, Vector2.ONE)
	assert_eq(target.modulate, Color(1.0, 1.0, 1.0, 0.2))
	tween.kill()
	return values


func _prepare(viewport: GFTweenPreviewViewport) -> bool:
	if not _has_prepare(viewport):
		return false
	var accepted: bool = _prepare_result(viewport)
	assert_true(accepted, viewport.get_error())
	return accepted


func _prepare_result(viewport: GFTweenPreviewViewport) -> bool:
	var result: Variant = viewport.call(&"prepare")
	assert_true(result is bool)
	if result is bool:
		var accepted: bool = result
		return accepted
	return false


func _config(path: NodePath, value: float, duration: float) -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = config.add_property_step(path, value, duration)
	step.transition_type = Tween.TRANS_LINEAR
	return config


func _viewport(config: Resource = null, kind: int = 0) -> GFTweenPreviewViewport:
	var viewport: GFTweenPreviewViewport = GFTweenPreviewViewport.new()
	add_child_autofree(viewport)
	if config != null:
		viewport.configure(config, kind)
	return viewport


func _position(viewport: GFTweenPreviewViewport) -> Vector2:
	var value: Variant = viewport.get_current_values().get("position")
	assert_true(value is Vector2)
	if value is Vector2:
		var position_value: Vector2 = value
		return position_value
	return Vector2.ZERO


func _progress(viewport: GFTweenPreviewViewport) -> float:
	var value: Variant = viewport.get_current_values().get("progress")
	assert_true(value is float)
	if value is float:
		var progress_value: float = value
		return progress_value
	return 0.0


func _rotation_2d(viewport: GFTweenPreviewViewport) -> float:
	var value: Variant = viewport.get_current_values().get("rotation")
	assert_true(value is float)
	if value is float:
		var rotation_value: float = value
		return rotation_value
	return 0.0


func _rotation_3d(viewport: GFTweenPreviewViewport) -> Vector3:
	var value: Variant = viewport.get_current_values().get("rotation")
	assert_true(value is Vector3)
	if value is Vector3:
		var rotation_value: Vector3 = value
		return rotation_value
	return Vector3.ZERO


func _descriptor(id: String) -> Dictionary:
	return {"id": id, "revision": 1, "label": "Prepared progress", "properties": [{"name": "progress", "type": TYPE_FLOAT, "initial": 0.0, "minimum": 0.0, "maximum": 1.0}]}


class RecordingAdapter extends GFTweenPreviewAdapter:
	var callback: Callable = Callable()
	var sample_reference: WeakRef = null

	func _create_sample() -> Control:
		var sample: Control = Control.new()
		sample.size = Vector2(32.0, 32.0)
		sample_reference = weakref(sample)
		return sample

	func _apply_sample(sample: Control, values: Dictionary) -> void:
		sample.position.x = GFVariantData.get_option_float(values, "progress") * 100.0
		var next_callback: Callable = callback
		callback = Callable()
		if next_callback.is_valid():
			next_callback.call()


class TransientFactoryAdapter extends GFTweenPreviewAdapter:
	var factory_calls: int = 0
	var factory_available: bool = false
	var sample_reference: WeakRef = null

	func _create_sample() -> Control:
		factory_calls += 1
		if not factory_available:
			return null
		var sample: Control = Control.new()
		sample.size = Vector2(32.0, 32.0)
		sample_reference = weakref(sample)
		return sample

	func _apply_sample(sample: Control, values: Dictionary) -> void:
		sample.position.x = GFVariantData.get_option_float(values, "progress") * 100.0
