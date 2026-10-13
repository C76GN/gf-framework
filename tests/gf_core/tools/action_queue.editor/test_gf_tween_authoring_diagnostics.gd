@tool

# 可导航错误使用稳定位置字段，显示文案及人类步骤编号不能成为控制协议。
extends GutTest


func test_property_failure_locates_the_second_source_step() -> void:
	var config: GFTweenActionConfig = _config()
	var _bad: GFTweenActionStep = config.add_property_step(^"reveal_progress", 1.0, 0.2)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	assert_false(plan.error.is_empty())
	assert_true(plan.error.contains("步骤 2"))
	_assert_location(plan, 1, &"property_name", &"unsupported_property")
	assert_eq(plan.steps.size(), 0)


func test_target_type_failure_is_not_misreported_as_a_property_error() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0].target_value = "unsupported"
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	_assert_location(plan, 0, &"target_value", &"invalid_target_value")


func test_curve_failure_locates_the_curve_field() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0].easing_curve = Curve.new()
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	_assert_location(plan, 0, &"easing_curve", &"invalid_curve")


func test_missing_step_has_a_row_but_no_field_to_focus() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0] = null
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	_assert_location(plan, 0, &"", &"invalid_step")


func test_global_failure_does_not_offer_a_false_step_navigation() -> void:
	var config: GFTweenActionConfig = _config()
	config.loop_count = 0
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	_assert_location(plan, -1, &"loop_count", &"invalid_loop_count")


func test_success_has_an_empty_diagnostic() -> void:
	var config: GFTweenActionConfig = _config()
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	var diagnostic: Variant = plan.get("diagnostic")
	assert_true(diagnostic is Dictionary)
	if diagnostic is Dictionary:
		var fields: Dictionary = diagnostic
		assert_eq(fields.size(), 0)


func test_viewport_returns_a_copy_and_clears_old_locations_after_valid_preparation() -> void:
	var config: GFTweenActionConfig = _config()
	config.steps[0].property_name = ^"reveal_progress"
	var preview: GFTweenPreviewViewport = GFTweenPreviewViewport.new()
	add_child_autofree(preview)
	preview.configure(config, 0)
	assert_false(preview.prepare())
	var diagnostic: Dictionary = preview.get_diagnostic()
	var initial_location_matches: bool = diagnostic.get("step_index") is int and diagnostic.get("step_index") == 0
	assert_true(initial_location_matches)
	diagnostic["step_index"] = 100
	var retained_location_matches: bool = preview.get_diagnostic().get("step_index") is int and preview.get_diagnostic().get("step_index") == 0
	assert_true(retained_location_matches)
	config.steps[0].property_name = ^"position:x"
	preview.configure(config, 0)
	assert_true(preview.prepare())
	assert_eq(preview.get_diagnostic(), {})
	preview.dispose_preview()


func _config() -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _step: GFTweenActionStep = config.add_property_step(^"position:x", 10.0, 0.2)
	return config


func _assert_location(plan: GFTweenPreviewPlan, step_index: int, field: StringName, error_kind: StringName) -> void:
	var value: Variant = plan.get("diagnostic")
	assert_true(value is Dictionary, "A rejected preview plan must retain a structured authoring location.")
	if not value is Dictionary:
		return
	var diagnostic: Dictionary = value
	assert_eq(diagnostic.size(), 4)
	var step_matches: bool = diagnostic.get("step_index") is int and diagnostic.get("step_index") == step_index
	var field_matches: bool = diagnostic.get("field") is StringName and diagnostic.get("field") == field
	var kind_matches: bool = diagnostic.get("error_kind") is StringName and diagnostic.get("error_kind") == error_kind
	var message_matches: bool = diagnostic.get("message") is String and diagnostic.get("message") == plan.error
	assert_true(step_matches)
	assert_true(field_matches)
	assert_true(kind_matches)
	assert_true(message_matches)
