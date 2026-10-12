@tool

# 作者导航经共享上下文联动；真实引擎执行由维护入口统一隔离，不绕过播放或编辑资格。
extends GutTest


const _TIMELINE_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_timeline.gd")
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")


func test_time_blocks_explain_property_direction_loop_and_actual_seconds() -> void:
	var config: GFTweenActionConfig = _config()
	config.enable_playback_control = true
	config.loop_count = 2
	config.ping_pong = true
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	assert_eq(plan.error, "")
	assert_eq(plan.duration_seconds, 4.0)
	var timeline: Control = _TIMELINE_SCRIPT.new()
	add_child_autofree(timeline)
	timeline.size = Vector2(800.0, 30.0)
	timeline.call(&"configure", plan)
	var first_text: String = timeline.get_tooltip(Vector2(150.0, 10.0))
	assert_true(first_text.contains("position:x"))
	assert_true(first_text.contains("循环 1"))
	assert_true(first_text.contains("正向"))
	assert_true(first_text.contains("0.000"))
	assert_true(first_text.contains("1.000"))
	var last_text: String = timeline.get_tooltip(Vector2(750.0, 10.0))
	assert_true(last_text.contains("循环 2"))
	assert_true(last_text.contains("反向"))
	assert_true(last_text.contains("3.000"))
	assert_true(last_text.contains("4.000"))
	assert_eq(timeline.get_tooltip(Vector2(150.0, 200.0)), "")


func test_block_click_seeks_the_frozen_plan_and_selects_the_current_step() -> void:
	var config: GFTweenActionConfig = _config()
	var context: GFTweenPreviewContext = _context(config)
	if not _has_navigation(context):
		return
	var selected: Array[Dictionary] = []
	var _connected: int = context.connect(&"step_selection_requested", func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	var panel: GFTweenPreviewPanel = _panel(config, context)
	var viewport: GFTweenPreviewViewport = _viewport(panel)
	assert_eq(viewport.get_state(), &"ready")
	var timeline: Control = _timeline(panel)
	timeline.size = Vector2(800.0, 30.0)
	_click(timeline, Vector2(400.0, 10.0))
	assert_eq(viewport.get_state(), &"paused")
	assert_gt(viewport.get_time_seconds(), 0.0)
	assert_lt(viewport.get_time_seconds(), 1.0)
	assert_almost_eq(_position(viewport).x, 10.0 * viewport.get_time_seconds(), 0.001)
	assert_eq(selected.size(), 1)
	if selected.size() == 1:
		var request: Dictionary = selected[0]
		var step_value: Variant = request.get("step_index")
		assert_true(step_value is int)
		if step_value is int:
			var index: int = step_value
			assert_eq(index, 0)
	panel.dispose_preview()


func test_stale_blocks_remain_seekable_without_selecting_reordered_source() -> void:
	var config: GFTweenActionConfig = _config()
	var second: GFTweenActionStep = config.add_property_step(^"position:y", 20.0, 1.0)
	second.transition_type = Tween.TRANS_LINEAR
	var context: GFTweenPreviewContext = _context(config)
	if not _has_navigation(context):
		return
	var selected: Array[Dictionary] = []
	var _connected: int = context.connect(&"step_selection_requested", func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	var panel: GFTweenPreviewPanel = _panel(config, context)
	var viewport: GFTweenPreviewViewport = _viewport(panel)
	assert_true(viewport.seek(0.25))
	var initial_step: GFTweenActionStep = config.steps[0]
	config.steps = [second, initial_step]
	config.emit_changed()
	var timeline: Control = _timeline(panel)
	timeline.size = Vector2(800.0, 60.0)
	_click(timeline, Vector2(250.0, 10.0))
	assert_eq(viewport.get_state(), &"paused")
	assert_gt(viewport.get_time_seconds(), 0.25)
	assert_almost_eq(_position(viewport).x, 10.0 * viewport.get_time_seconds(), 0.001)
	assert_eq(selected.size(), 0, "The old index must never address the new source order")
	assert_eq(config.steps, [second, initial_step])
	panel.dispose_preview()


func test_same_value_replacement_and_invalid_fields_revoke_navigation() -> void:
	var config: GFTweenActionConfig = _config()
	var context: GFTweenPreviewContext = _context(config)
	if not _has_navigation(context):
		return
	var snapshot: Dictionary = _navigation_snapshot(context)
	var replacement: GFTweenActionStep = GFTweenActionStep.new()
	replacement.property_name = ^"position:x"
	replacement.target_value = 10.0
	replacement.duration = 1.0
	replacement.transition_type = Tween.TRANS_LINEAR
	config.steps = [replacement]
	assert_false(_request_selection(context, 0, &"duration", snapshot))
	assert_eq(config.steps[0], replacement)
	var selected: Array[Dictionary] = []
	var _connected: int = context.connect(&"step_selection_requested", func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	assert_false(_request_selection(context, -1, &"duration", _navigation_snapshot(context)))
	assert_false(_request_selection(context, 1, &"duration", _navigation_snapshot(context)))
	assert_false(_request_selection(context, 0, &"not_a_field", _navigation_snapshot(context)))
	assert_eq(selected.size(), 0)


func test_navigation_notification_reentry_cannot_report_the_old_request_as_current() -> void:
	var config: GFTweenActionConfig = _config()
	var context: GFTweenPreviewContext = _context(config)
	if not _has_navigation(context):
		return
	var snapshot: Dictionary = _navigation_snapshot(context)
	var delivered: Array[Dictionary] = []
	var _connected: int = context.connect(&"step_selection_requested", func(request: Dictionary) -> void:
		delivered.append(request.duplicate(true))
		config.steps[0].duration = 2.0
	)
	assert_false(_request_selection(context, 0, &"duration", snapshot))
	assert_eq(delivered.size(), 1)
	assert_eq(config.steps[0].duration, 2.0)
	if delivered.size() == 1:
		var value: Variant = context.call(&"is_navigation_request_current", delivered[0])
		assert_true(value is bool)
		if value is bool:
			var current: bool = value
			assert_false(current)


func test_name_budget_rejects_authoring_identity_without_changing_playback_or_source() -> void:
	var config: GFTweenActionConfig = _config()
	var context: GFTweenPreviewContext = _context(config)
	if not _has_navigation(context):
		return
	var playback: Array = _SNAPSHOT_SCRIPT.capture(config)
	config.steps[0].resource_name = "x".repeat(256)
	var accepted: Dictionary = _navigation_snapshot(context)
	assert_false(accepted.is_empty())
	config.steps[0].resource_name = "x".repeat(257)
	assert_true(_navigation_snapshot(context).is_empty())
	assert_false(_request_selection(context, 0, &"resource_name", accepted))
	assert_eq(config.steps[0].resource_name.length(), 257)
	assert_eq(_SNAPSHOT_SCRIPT.capture(config), playback, "Names do not modify the playback signature")
	config.steps[0].resource_name = "已修复名称"
	assert_false(_navigation_snapshot(context).is_empty())
	assert_true(_request_selection(context, 0, &"resource_name", _navigation_snapshot(context)))


func test_context_diagnostic_locates_the_actual_field_without_parsing_text() -> void:
	var config: GFTweenActionConfig = _config()
	var invalid: GFTweenActionStep = config.add_property_step(^"position:y", 20.0, 1.0)
	invalid.target_value = "invalid"
	var context: GFTweenPreviewContext = _context(config)
	assert_true(context.has_method(&"get_diagnostic"), "Errors must carry a structured editing location")
	if not context.has_method(&"get_diagnostic"):
		return
	var value: Variant = context.call(&"get_diagnostic")
	assert_true(value is Dictionary)
	if value is Dictionary:
		var diagnostic: Dictionary = value
		assert_eq(diagnostic.size(), 4)
		assert_eq(GFVariantData.get_option_int(diagnostic, "step_index", -1), 1)
		assert_eq(_string_name(diagnostic, "field"), &"target_value")
		assert_ne(_string_name(diagnostic, "error_kind"), &"")
	if not _has_navigation(context):
		return
	assert_true(_request_selection(context, 1, &"target_value", _navigation_snapshot(context)))
	var source_value: Variant = config.steps[1].target_value
	var preserved: bool = false
	if source_value is String:
		var source_text: String = source_value
		preserved = source_text == "invalid"
	assert_true(source_value is String)
	assert_true(preserved, "Navigation does not repair or write the source value")


func test_error_button_recompiles_silent_source_changes_before_selecting_a_field() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0].target_value = "old invalid"
	var second: GFTweenActionStep = config.add_property_step(^"position:y", 20.0, 1.0)
	var context: GFTweenPreviewContext = _context(config)
	var panel: GFTweenPreviewPanel = _panel(config, context)
	assert_eq(GFVariantData.get_option_int(context.get_diagnostic(), "step_index", -1), 0)
	var selected: Array[Dictionary] = []
	var _connected: int = context.step_selection_requested.connect(func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	# No changed signal and no frame: the button must not authorize the cached old error with new values.
	config.steps[0].target_value = 10.0
	second.target_value = "new invalid"
	var snapshot: Dictionary = _navigation_snapshot(context)
	var button: Button = _error_button(panel)
	if button == null:
		panel.dispose_preview()
		return
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(selected.size(), 1)
	if selected.size() == 1:
		var request: Dictionary = selected[0]
		assert_eq(GFVariantData.get_option_int(request, "step_index", -1), 1)
		assert_eq(_string_name(request, "field"), &"target_value")
		assert_eq(GFVariantData.get_option_dictionary(request, "snapshot"), snapshot)
	var source_value: Variant = second.target_value
	var preserved: bool = false
	if source_value is String:
		var source_text: String = source_value
		preserved = source_text == "new invalid"
	assert_true(source_value is String)
	assert_true(preserved)
	panel.dispose_preview()


func test_error_button_rejects_source_mutation_during_refresh_notification() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0].target_value = "old invalid"
	var second: GFTweenActionStep = config.add_property_step(^"position:y", 20.0, 1.0)
	var context: GFTweenPreviewContext = _context(config)
	var panel: GFTweenPreviewPanel = _panel(config, context)
	var selected: Array[Dictionary] = []
	var changed: Array[bool] = []
	var _selection_connected: int = context.step_selection_requested.connect(func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	var _changed_connected: int = context.changed.connect(func() -> void:
		changed.append(true)
		config.steps[0].duration = 2.0
	, CONNECT_ONE_SHOT)
	config.steps[0].target_value = 10.0
	second.target_value = "new invalid"
	var button: Button = _error_button(panel)
	if button == null:
		panel.dispose_preview()
		return
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(changed.size(), 1, "The actual compile refresh must notify the changed error context")
	assert_eq(selected.size(), 0, "The refreshed error cannot authorize a source changed by that notification")
	assert_eq(config.steps[0].duration, 2.0)
	var source_value: Variant = second.target_value
	var preserved: bool = false
	if source_value is String:
		var source_text: String = source_value
		preserved = source_text == "new invalid"
	assert_true(source_value is String)
	assert_true(preserved)
	panel.dispose_preview()


func test_lease_withdrawal_invalidates_block_input_before_any_seek_or_selection() -> void:
	var config: GFTweenActionConfig = _config()
	config.resource_path = "res://navigation_lease.tres"
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var binding: GFTweenPreviewRegistration = registry.register_binding(registration_owner, config.resource_path, &"gf.preview.2d")
	assert_not_null(binding)
	if binding == null:
		return
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	if not _has_navigation(context):
		binding.release()
		return
	var selected: Array[Dictionary] = []
	var _connected: int = context.connect(&"step_selection_requested", func(request: Dictionary) -> void: selected.append(request.duplicate(true)))
	var panel: GFTweenPreviewPanel = _panel(config, context)
	var viewport: GFTweenPreviewViewport = _viewport(panel)
	assert_true(viewport.seek(0.25))
	binding.release()
	var timeline: Control = _timeline(panel)
	timeline.size = Vector2(800.0, 30.0)
	_click(timeline, Vector2(400.0, 10.0))
	assert_false(viewport.has_session())
	assert_true(viewport.get_current_values().is_empty())
	assert_eq(selected.size(), 0)
	panel.dispose_preview()


func _config() -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = config.add_property_step(^"position:x", 10.0, 1.0)
	step.transition_type = Tween.TRANS_LINEAR
	return config


func _context(config: GFTweenActionConfig) -> GFTweenPreviewContext:
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, GFTweenPreviewRegistry.new())
	assert_true(context.select_target(&"gf.preview.2d"))
	return context


func _panel(config: GFTweenActionConfig, context: GFTweenPreviewContext) -> GFTweenPreviewPanel:
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(config, context)
	add_child_autofree(panel)
	panel.set_process(false)
	return panel


func _viewport(panel: GFTweenPreviewPanel) -> GFTweenPreviewViewport:
	var node: Node = panel.find_child("PreviewViewport", true, false)
	assert_true(node is GFTweenPreviewViewport)
	if node is GFTweenPreviewViewport:
		var viewport: GFTweenPreviewViewport = node
		return viewport
	return null


func _timeline(panel: GFTweenPreviewPanel) -> Control:
	for node: Node in panel.find_children("*", "Control", true, false):
		if node.get_script() == _TIMELINE_SCRIPT:
			var timeline: Control = node
			return timeline
	fail_test("The prepared panel must show its frozen step timeline")
	return null


func _error_button(panel: GFTweenPreviewPanel) -> Button:
	var node: Node = panel.find_child("LocateError", true, false)
	assert_true(node is Button)
	if node is Button:
		var button: Button = node
		return button
	return null


func _click(timeline: Control, point: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	timeline.gui_input.emit(event)


func _has_navigation(context: GFTweenPreviewContext) -> bool:
	var available: bool = context.has_signal(&"step_selection_requested") and context.has_method(&"get_navigation_snapshot") and context.has_method(&"request_step_selection")
	assert_true(available, "The panel and Steps must use one guarded authoring navigation protocol")
	return available


func _navigation_snapshot(context: GFTweenPreviewContext) -> Dictionary:
	var value: Variant = context.call(&"get_navigation_snapshot")
	assert_true(value is Dictionary)
	if value is Dictionary:
		var snapshot: Dictionary = value
		return snapshot
	return {}


func _request_selection(context: GFTweenPreviewContext, index: int, field_name: StringName, snapshot: Dictionary) -> bool:
	var value: Variant = context.call(&"request_step_selection", index, field_name, snapshot)
	assert_true(value is bool)
	if value is bool:
		var accepted: bool = value
		return accepted
	return false


func _position(viewport: GFTweenPreviewViewport) -> Vector2:
	var value: Variant = viewport.get_current_values().get("position")
	assert_true(value is Vector2)
	if value is Vector2:
		var position_value: Vector2 = value
		return position_value
	return Vector2.ZERO


func _string_name(record: Dictionary, key: String) -> StringName:
	var value: Variant = record.get(key)
	assert_true(value is StringName)
	if value is StringName:
		var text_value: StringName = value
		return text_value
	return &""
