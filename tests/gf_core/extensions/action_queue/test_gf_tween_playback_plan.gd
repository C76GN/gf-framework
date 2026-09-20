# 验证可定位播放计划的纯值语义，并用独立原生 Tween 对照插值和循环。
extends GutTest


const _PLAN_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_playback_plan.gd")


func test_capture_and_sample_never_write_target_and_freeze_source() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 1.0)
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	step.target_value = 100.0
	config.steps.clear()
	plan.initial_values["number"] = 50.0
	var values: Dictionary = plan.sample(0.5)
	assert_almost_eq(GFVariantData.get_option_float(values, "number"), 5.0, 0.00001)
	values["number"] = 60.0
	assert_eq(plan.sample(0.0), {"number": 0.0})
	assert_eq(target.write_count, 0)
	assert_eq(target.number, 0.0)
	assert_eq(plan.property_names, [^"number"])


func test_serial_root_and_component_steps_compose_from_group_state() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _root_step: GFTweenActionStep = _linear_step(config, ^"position", Vector2(10.0, 20.0), 1.0)
	var component_step: GFTweenActionStep = _linear_step(config, ^"position:x", 4.0, 1.0)
	component_step.as_relative = true
	component_step.delay = 0.5
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	assert_eq(plan.duration_seconds, 2.5)
	assert_eq(plan.sample(1.25), {"position": Vector2(10.0, 20.0)})
	assert_eq(plan.sample(2.0), {"position": Vector2(12.0, 20.0)})
	assert_eq(plan.sample(2.5), {"position": Vector2(14.0, 20.0)})
	assert_eq(target.position, Vector2(2.0, 4.0))
	assert_eq(plan.property_names, [^"position"])


func test_parallel_groups_duration_and_marker_order() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var first: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 2.0)
	first.marker_id = &"long"
	var second: GFTweenActionStep = _linear_step(config, ^"position:x", 6.0, 1.0)
	second.parallel = true
	second.marker_id = &"short"
	var third: GFTweenActionStep = _linear_step(config, ^"number", 20.0, 1.0)
	third.marker_id = &"tail"
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	assert_eq(plan.duration_seconds, 3.0)
	assert_eq(plan.sample(0.5), {"number": 2.5, "position": Vector2(4.0, 4.0)})
	assert_eq(plan.sample(2.5), {"number": 15.0, "position": Vector2(6.0, 4.0)})
	assert_eq(plan.markers, [
		{"time_seconds": 1.0, "index": 1, "marker_id": &"short"},
		{"time_seconds": 2.0, "index": 0, "marker_id": &"long"},
		{"time_seconds": 3.0, "index": 2, "marker_id": &"tail"},
	])


func test_relative_loops_accumulate_and_match_independent_native_tween() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.loop_count = 3
	var step: GFTweenActionStep = _linear_step(config, ^"position:x", 10.0, 1.0)
	step.as_relative = true
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	assert_eq(plan.sample(2.5), {"position": Vector2(27.0, 4.0)})
	for sample_time: float in [0.0, 0.5, 1.0, 1.25, 2.5, 3.0]:
		var oracle: PropertyProbe = PropertyProbe.new()
		var native: Tween = create_tween()
		native.pause()
		var _looped: Tween = native.set_loops(3)
		var _property: PropertyTweener = native.tween_property(oracle, ^"position:x", 10.0, 1.0).as_relative().set_trans(Tween.TRANS_LINEAR)
		var _playing: bool = native.custom_step(sample_time)
		assert_eq(plan.sample(sample_time), {"position": oracle.position}, "Native relative loop at %s" % sample_time)
		native.kill()


func test_serial_parallel_and_ease_match_independent_native_tween() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var first: GFTweenActionStep = _linear_step(config, ^"position", Vector2(10.0, 20.0), 1.0)
	first.transition_type = Tween.TRANS_CUBIC
	first.ease_type = Tween.EASE_IN_OUT
	var second: GFTweenActionStep = _linear_step(config, ^"number", 9.0, 0.5)
	second.parallel = true
	second.delay = 0.25
	var last: GFTweenActionStep = _linear_step(config, ^"position:x", 4.0, 1.0)
	last.as_relative = true
	last.delay = 0.5
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	for sample_time: float in [0.125, 0.5, 1.25, 1.75, 2.5]:
		var oracle: PropertyProbe = PropertyProbe.new()
		var native: Tween = create_tween()
		native.pause()
		var _first: PropertyTweener = native.tween_property(oracle, ^"position", Vector2(10.0, 20.0), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var _second: PropertyTweener = native.parallel().tween_property(oracle, ^"number", 9.0, 0.5).set_delay(0.25).set_trans(Tween.TRANS_LINEAR)
		# 可控计划的延迟步骤固定组起点；原生 oracle 显式 from，避免延迟的动态读取。
		var _last: PropertyTweener = native.tween_property(oracle, ^"position:x", 4.0, 1.0).from(10.0).as_relative().set_delay(0.5).set_trans(Tween.TRANS_LINEAR)
		var _playing: bool = native.custom_step(sample_time)
		assert_eq(plan.sample(sample_time), {"position": oracle.position, "number": oracle.number})
		native.kill()


func test_curve_is_frozen_and_reverse_samples_same_asymmetric_path() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 1.0)
	var curve: Curve = Curve.new()
	var _first: int = curve.add_point(Vector2.ZERO)
	var _middle: int = curve.add_point(Vector2(0.5, 0.2))
	var _last: int = curve.add_point(Vector2.ONE)
	step.easing_curve = curve
	var expected: float = curve.sample_baked(0.5) * 10.0
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target, true)
	assert_eq(plan.error, "")
	curve.set_point_value(1, 0.9)
	assert_almost_eq(GFVariantData.get_option_float(plan.sample(0.5), "number"), expected, 0.00001)
	assert_eq(plan.sample(0.5), plan.sample(1.5))
	assert_eq(plan.sample(2.0), {"number": 0.0})


func test_ping_pong_cycles_do_not_accumulate_and_only_forward_markers_expand() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.loop_count = 2
	var step: GFTweenActionStep = _linear_step(config, ^"position:x", 10.0, 1.0)
	step.as_relative = true
	step.marker_id = &"arrived"
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target, true)
	assert_eq(plan.error, "")
	assert_eq(plan.duration_seconds, 4.0)
	assert_eq(plan.sample(0.75), plan.sample(1.25))
	assert_eq(plan.sample(0.75), plan.sample(2.75))
	assert_eq(plan.sample(4.0), {"position": Vector2(2.0, 4.0)})
	assert_eq(plan.markers, [
		{"time_seconds": 1.0, "index": 0, "marker_id": &"arrived"},
		{"time_seconds": 3.0, "index": 0, "marker_id": &"arrived"},
	])


func test_curve_overshoot_with_large_finite_duration_keeps_finite_sample() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 1.0e308)
	var curve: Curve = Curve.new()
	curve.max_value = 2.0
	var _first: int = curve.add_point(Vector2.ZERO)
	var _middle: int = curve.add_point(Vector2(0.5, 2.0))
	var _last: int = curve.add_point(Vector2.ONE)
	step.easing_curve = curve
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	var sampled: Dictionary = plan.sample(5.0e307)
	assert_false(sampled.is_empty(), "Finite output must not fail because eased progress times duration overflows.")
	assert_almost_eq(GFVariantData.get_option_float(sampled, "number"), 10.0 * curve.sample_baked(0.5), 0.00001)
	assert_eq(target.write_count, 0)


func test_integer_color_and_vector3_values_match_native_types() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _integer_step: GFTweenActionStep = _linear_step(config, ^"integer", 7, 1.0)
	var color_step: GFTweenActionStep = _linear_step(config, ^"tint:a", 0.25, 1.0)
	color_step.parallel = true
	var vector_step: GFTweenActionStep = _linear_step(config, ^"direction", Vector3(2.0, 4.0, 8.0), 1.0)
	vector_step.parallel = true
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	var oracle: PropertyProbe = PropertyProbe.new()
	var native: Tween = create_tween()
	var _integer: PropertyTweener = native.tween_property(oracle, ^"integer", 7, 1.0).set_trans(Tween.TRANS_LINEAR)
	var _color: PropertyTweener = native.parallel().tween_property(oracle, ^"tint:a", 0.25, 1.0).set_trans(Tween.TRANS_LINEAR)
	var _vector: PropertyTweener = native.parallel().tween_property(oracle, ^"direction", Vector3(2.0, 4.0, 8.0), 1.0).set_trans(Tween.TRANS_LINEAR)
	native.pause()
	var _playing: bool = native.custom_step(0.5)
	assert_eq(plan.sample(0.5), {"integer": oracle.integer, "tint": oracle.tint, "direction": oracle.direction})
	native.kill()


func test_invalid_plans_reject_without_partial_data_or_target_writes() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 1.0)
	step.target_value = NAN
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.target_value = 10.0
	step.property_name = ^"position:x:bad"
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.property_name = ^"position:q"
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.property_name = ^"missing"
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.property_name = ^"number"
	step.duration = 0.0
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.duration = 1.0
	config.loop_count = 0
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	config.loop_count = 257
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	config.loop_count = 1
	config.steps.append(null)
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	assert_eq(target.write_count, 0)


func test_integer_rounding_matches_native_for_positive_negative_and_fractional_endpoints() -> void:
	for endpoint: Variant in [7, -7, 7.9, -7.9]:
		var target: PropertyProbe = PropertyProbe.new()
		var config: GFTweenActionConfig = GFTweenActionConfig.new()
		var _step: GFTweenActionStep = _linear_step(config, ^"integer", endpoint, 1.0)
		var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
		assert_eq(plan.error, "")
		for sample_time: float in [0.25, 0.5, 0.9, 1.0]:
			var oracle: PropertyProbe = PropertyProbe.new()
			var native: Tween = create_tween()
			native.pause()
			var _property: PropertyTweener = native.tween_property(oracle, ^"integer", endpoint, 1.0).set_trans(Tween.TRANS_LINEAR)
			var _playing: bool = native.custom_step(sample_time)
			assert_eq(plan.sample(sample_time), {"integer": oracle.integer}, "Endpoint %s at %s" % [endpoint, sample_time])
			native.kill()


func test_parallel_root_overlap_and_known_aliases_reject() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var first: GFTweenActionStep = _linear_step(config, ^"position", Vector2.ONE, 1.0)
	var second: GFTweenActionStep = _linear_step(config, ^"position:x", 10.0, 1.0)
	second.parallel = true
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	first.property_name = ^"position:y"
	first.target_value = 3.0
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	first.property_name = ^"rotation"
	second.property_name = ^"rotation_degrees"
	second.parallel = false
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	assert_eq(target.write_count, 0)


func test_step_and_expansion_budgets_reject_atomically() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	for index: int in range(257):
		var _step: GFTweenActionStep = _linear_step(config, ^"number", float(index), 1.0)
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	var _resized: int = config.steps.resize(17)
	config.loop_count = 256
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	assert_eq(target.write_count, 0)


func test_sample_clamps_finite_times_and_rejects_nonfinite_times() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _step: GFTweenActionStep = _linear_step(config, ^"number", 10.0, 1.0)
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.sample(-1.0), {"number": 0.0})
	assert_eq(plan.sample(2.0), {"number": 10.0})
	assert_eq(plan.sample(NAN), {})
	assert_eq(plan.sample(INF), {})


func test_component_and_relative_endpoint_overflow_reject_before_writes() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = _linear_step(config, ^"position:x", 1.0e100, 1.0)
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.property_name = ^"number"
	step.target_value = 1.0e308
	step.as_relative = true
	config.loop_count = 2
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	step.property_name = ^"integer"
	step.target_value = 9223372036854775807
	_assert_rejected(_PLAN_SCRIPT.capture(config, target))
	assert_eq(target.write_count, 0)


func test_zero_duration_step_and_delay_match_frozen_endpoints() -> void:
	var target: PropertyProbe = PropertyProbe.new()
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var immediate: GFTweenActionStep = _linear_step(config, ^"number", 4.0, 0.0)
	immediate.marker_id = &"instant"
	var delayed: GFTweenActionStep = _linear_step(config, ^"number", 3.0, 0.0)
	delayed.delay = 1.0
	delayed.as_relative = true
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture(config, target)
	assert_eq(plan.error, "")
	assert_eq(plan.sample(0.0), {"number": 4.0})
	assert_eq(plan.sample(0.5), {"number": 4.0})
	assert_eq(plan.sample(1.0), {"number": 7.0})
	assert_eq(plan.markers, [{"time_seconds": 0.0, "index": 0, "marker_id": &"instant"}])


func _linear_step(config: GFTweenActionConfig, path: NodePath, endpoint: Variant, duration: float) -> GFTweenActionStep:
	var step: GFTweenActionStep = config.add_property_step(path, endpoint, duration)
	step.transition_type = Tween.TRANS_LINEAR
	return step


func _assert_rejected(plan: GFTweenPlaybackPlan) -> void:
	assert_false(plan.error.is_empty())
	assert_eq(plan.duration_seconds, 0.0)
	assert_eq(plan.property_names, [])
	assert_eq(plan.initial_values, {})
	assert_eq(plan.markers, [])
	assert_eq(plan.sample(0.5), {})


class PropertyProbe extends RefCounted:
	var write_count: int = 0
	var number: float = 0.0:
		set(value):
			write_count += 1
			number = value
	var integer: int = 0
	var position: Vector2 = Vector2(2.0, 4.0)
	var direction: Vector3 = Vector3.ZERO
	var tint: Color = Color.WHITE
	var rotation: float = 0.0
	var rotation_degrees: float = 0.0
