# 公共纯数值 facade 的冻结、预算与原生 Tween 一致性；不依赖内部计划字段。
extends GutTest


func test_delay_single_loop_and_relative_loops_match_independent_native_tween() -> void:
	_assert_native_relative_samples(0.25, 1, [0.0, 0.125, 0.25, 0.5, 1.25])
	_assert_native_relative_samples(0.0, 3, [0.0, 0.25, 0.5, 1.0, 1.25, 2.0, 2.5, 3.0])


func test_relative_delay_loops_preserve_frozen_group_baselines() -> void:
	var definition: Dictionary = {"steps": [_step(4.0, 1.0, 0.25, true)], "loop_count": 3}
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture(definition, _properties())
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.get_duration_seconds(), 3.75)
	var times: Array[float] = [0.0, 0.125, 0.25, 0.5, 1.25, 1.5, 2.0, 3.0, 3.75]
	var expected: Array[float] = [0.0, 0.0, 0.0, 1.0, 4.0, 4.0, 6.0, 9.0, 12.0]
	for index: int in range(times.size()):
		assert_eq(timeline.sample(times[index]), {"progress": expected[index]}, "GF controlled from is frozen before delay")


func test_native_easing_conformance_for_every_transition_and_direction() -> void:
	for transition: int in range(Tween.TRANS_LINEAR, Tween.TRANS_SPRING + 1):
		for ease_mode: int in range(Tween.EASE_IN, Tween.EASE_OUT_IN + 1):
			var step: Dictionary = _step(1.0)
			step["transition_type"] = transition
			step["ease_type"] = ease_mode
			var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [step]}, _properties())
			assert_eq(timeline.get_error(), "")
			for seconds: float in [0.1, 0.25, 0.5, 0.75, 0.9]:
				var probe: NumericProbe = NumericProbe.new()
				var native: Tween = create_tween()
				native.pause()
				var _property: PropertyTweener = native.tween_property(probe, ^"progress", 1.0, 1.0).set_trans(transition as Tween.TransitionType).set_ease(ease_mode as Tween.EaseType)
				var _playing: bool = native.custom_step(seconds)
				assert_almost_eq(GFVariantData.get_option_float(timeline.sample(seconds), "progress"), probe.progress, 0.00001)
				native.kill()


func test_parallel_distinct_roots_and_serial_steps_share_one_timeline() -> void:
	var properties: Array[Dictionary] = _properties()
	properties.append({"name": "other", "type": TYPE_FLOAT, "initial": 2.0, "minimum": -100.0, "maximum": 100.0})
	var parallel: Dictionary = _step(6.0, 0.5)
	parallel["property_name"] = ^"other"
	parallel["parallel"] = true
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(8.0), parallel, _step(12.0)]}, properties)
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.get_duration_seconds(), 2.0)
	assert_eq(timeline.sample(0.25), {"progress": 2.0, "other": 4.0})
	assert_eq(timeline.sample(1.5), {"progress": 10.0, "other": 6.0})


func test_integer_rounding_matches_native_property_tweener() -> void:
	var properties: Array[Dictionary] = [{"name": "count", "type": TYPE_INT, "initial": 0, "minimum": -100, "maximum": 100}]
	var step: Dictionary = _step(7.9)
	step["property_name"] = ^"count"
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [step]}, properties)
	assert_eq(timeline.get_error(), "")
	for seconds: float in [0.0, 0.1, 0.5, 0.9, 1.0]:
		var probe: NumericProbe = NumericProbe.new()
		var native: Tween = create_tween()
		native.pause()
		var _property: PropertyTweener = native.tween_property(probe, ^"count", 7.9, 1.0).set_trans(Tween.TRANS_LINEAR)
		var _playing: bool = native.custom_step(seconds)
		assert_eq(GFVariantData.get_option_int(timeline.sample(seconds), "count"), probe.count)
		assert_eq(typeof(timeline.sample(seconds)["count"]), TYPE_INT)
		native.kill()


func test_ping_pong_returns_baseline_without_accumulating_relative_loops() -> void:
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(4.0, 1.0, 0.0, true)], "loop_count": 2, "ping_pong": true}, _properties())
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.get_duration_seconds(), 4.0)
	assert_eq(timeline.sample(0.5), {"progress": 2.0})
	assert_eq(timeline.sample(1.5), {"progress": 2.0})
	assert_eq(timeline.sample(2.5), {"progress": 2.0})
	assert_eq(timeline.sample(4.0), {"progress": 0.0})


func test_input_and_output_snapshots_are_independent() -> void:
	var step: Dictionary = _step(10.0)
	var definition: Dictionary = {"steps": [step]}
	var properties: Array[Dictionary] = _properties()
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture(definition, properties)
	step["target_value"] = 100.0
	definition.clear()
	properties[0]["initial"] = 20.0
	properties.clear()
	var initial: Dictionary = timeline.get_initial_values()
	initial["progress"] = 99.0
	var sampled: Dictionary = timeline.sample(0.5)
	sampled["progress"] = 99.0
	assert_eq(timeline.get_initial_values(), {"progress": 0.0})
	assert_eq(timeline.sample(0.5), {"progress": 5.0})


func test_unused_declared_values_remain_present_in_every_snapshot() -> void:
	var properties: Array[Dictionary] = _properties()
	properties.append({"name": "count", "type": TYPE_INT, "initial": 3, "minimum": 0, "maximum": 10})
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(10.0)]}, properties)
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.sample(0.5), {"progress": 5.0, "count": 3})


func test_zero_step_and_scaled_delay_preserve_explicit_time_semantics() -> void:
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(4.0, 0.0), _step(8.0, 1.0, 0.25)], "duration_scale": 2.0}, _properties())
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.get_duration_seconds(), 2.5)
	assert_eq(timeline.sample(0.0), {"progress": 4.0})
	assert_eq(timeline.sample(0.25), {"progress": 4.0})
	assert_eq(timeline.sample(1.5), {"progress": 6.0})
	_assert_rejected({"steps": [_step(4.0, 0.0)]}, _properties())
	_assert_rejected({"steps": [_step(4.0)], "duration_scale": 0.0}, _properties())


func test_hard_bounds_reject_relative_accumulation_and_nonmonotonic_easing() -> void:
	var properties: Array[Dictionary] = [{"name": "progress", "type": TYPE_FLOAT, "initial": 0.0, "minimum": 0.0, "maximum": 1.0}]
	var legal: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(1.0)]}, properties)
	assert_eq(legal.get_error(), "")
	assert_eq(legal.sample(1.0), {"progress": 1.0})
	_assert_rejected({"steps": [_step(0.6, 1.0, 0.0, true)], "loop_count": 2}, properties)
	var overshoot: Dictionary = _step(1.0)
	overshoot["transition_type"] = Tween.TRANS_BACK
	_assert_rejected({"steps": [overshoot]}, properties)


func test_curve_data_is_frozen_and_overshoot_must_fit_hard_bounds() -> void:
	var curve_data: Dictionary = {
		"positions": PackedVector2Array([Vector2.ZERO, Vector2(0.5, 1.5), Vector2.ONE]),
		"tangents": PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]),
		"modes": PackedInt32Array([0, 0, 0, 0, 0, 0]),
		"bake_resolution": 101, "value_range": Vector2(0.0, 2.0),
	}
	var step: Dictionary = _step(1.0)
	step["easing_curve_data"] = curve_data
	var narrow: Array[Dictionary] = [{"name": "progress", "type": TYPE_FLOAT, "initial": 0.0, "minimum": 0.0, "maximum": 1.0}]
	_assert_rejected({"steps": [step]}, narrow)
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [step]}, _properties())
	assert_eq(timeline.get_error(), "")
	assert_almost_eq(GFVariantData.get_option_float(timeline.sample(0.5), "progress"), 1.5, 0.00001)
	curve_data.clear()
	step.clear()
	assert_almost_eq(GFVariantData.get_option_float(timeline.sample(0.5), "progress"), 1.5, 0.00001)


func test_unknown_objects_methods_markers_and_paths_are_atomic_rejections() -> void:
	for field: String in ["target", "source", "callback", "marker_id", "restore_on_finish"]:
		var step: Dictionary = _step(1.0)
		step[field] = RefCounted.new()
		_assert_rejected({"steps": [step]}, _properties())
	for path: NodePath in [^"progress:x", ^"other", ^"child/progress", ^"progress:resource:value"]:
		var step: Dictionary = _step(1.0)
		step["property_name"] = path
		_assert_rejected({"steps": [step]}, _properties())
	_assert_rejected({"steps": [_step(1.0)], "source": RefCounted.new()}, _properties())


func test_invalid_descriptors_types_and_unknown_fields_are_rejected() -> void:
	for field: String in ["name", "type", "initial", "minimum", "maximum"]:
		var properties: Array[Dictionary] = _properties()
		var _removed: bool = properties[0].erase(field)
		_assert_rejected({"steps": [_step(1.0)]}, properties)
	var duplicates: Array[Dictionary] = _properties()
	duplicates.append(duplicates[0].duplicate())
	_assert_rejected({"steps": [_step(1.0)]}, duplicates)
	var wrong_type: Array[Dictionary] = _properties()
	wrong_type[0]["initial"] = 0
	_assert_rejected({"steps": [_step(1.0)]}, wrong_type)
	wrong_type[0]["initial"] = 0.0
	wrong_type[0]["extra"] = "unsupported"
	_assert_rejected({"steps": [_step(1.0)]}, wrong_type)


func test_invalid_time_and_parallel_same_root_never_return_partial_values() -> void:
	var parallel: Dictionary = _step(3.0)
	parallel["parallel"] = true
	_assert_rejected({"steps": [_step(1.0), parallel]}, _properties())
	for invalid: float in [-1.0, NAN, INF]:
		var step: Dictionary = _step(1.0)
		step["duration"] = invalid
		_assert_rejected({"steps": [_step(1.0), step]}, _properties())
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(1.0)]}, _properties())
	assert_eq(timeline.sample(NAN), {})
	assert_eq(timeline.sample(INF), {})
	assert_eq(timeline.sample(-1.0), {"progress": 0.0})
	assert_eq(timeline.sample(100.0), {"progress": 1.0})


func test_step_loop_property_and_duration_budgets_fail_closed() -> void:
	var steps: Array[Dictionary] = []
	for _index: int in range(129):
		steps.append(_step(1.0, 0.01))
	_assert_rejected({"steps": steps}, _properties())
	_assert_rejected({"steps": [_step(1.0)], "loop_count": 33}, _properties())
	_assert_rejected({"steps": [_step(1.0, 120.001)]}, _properties())
	var accepted: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(1.0, 120.0)]}, _properties())
	assert_eq(accepted.get_error(), "")
	assert_eq(accepted.get_duration_seconds(), 120.0)
	var properties: Array[Dictionary] = _properties()
	for index: int in range(32):
		properties.append({"name": "value_%d" % index, "type": TYPE_FLOAT, "initial": 0.0, "minimum": -1.0, "maximum": 1.0})
	_assert_rejected({"steps": [_step(1.0)]}, properties)


func test_serialized_omitted_defaults_match_runtime_and_keep_explicit_zero() -> void:
	var omitted: Resource = load("res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_omitted_defaults.tres")
	var zeros: Resource = load("res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_explicit_zero.tres")
	var omitted_scale: Variant = omitted.get(&"duration_scale")
	assert_true(omitted_scale is float)
	if omitted_scale is float:
		var omitted_number: float = omitted_scale
		assert_eq(omitted_number, 1.0)
	var steps_value: Variant = omitted.get(&"steps")
	assert_true(steps_value is Array)
	if steps_value is Array:
		var steps: Array = steps_value
		var step: GFTweenActionStep = steps[0]
		assert_eq(step.duration, 0.2)
		assert_eq(step.delay, 0.0)
	var zero_scale: Variant = zeros.get(&"duration_scale")
	assert_true(zero_scale is float)
	if zero_scale is float:
		var zero_number: float = zero_scale
		assert_eq(zero_number, 0.0)
	var zero_steps: Array = zeros.get(&"steps")
	var zero_step: GFTweenActionStep = zero_steps[0]
	assert_eq(zero_step.duration, 0.0)


func _step(endpoint: float, duration: float = 1.0, delay: float = 0.0, relative: bool = false) -> Dictionary:
	return {"property_name": ^"progress", "target_value": endpoint, "duration": duration, "delay": delay, "as_relative": relative, "transition_type": Tween.TRANS_LINEAR, "ease_type": Tween.EASE_IN}


func _properties() -> Array[Dictionary]:
	return [{"name": "progress", "type": TYPE_FLOAT, "initial": 0.0, "minimum": -100.0, "maximum": 100.0}]


func _assert_rejected(definition: Dictionary, properties: Array[Dictionary]) -> void:
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture(definition, properties)
	assert_false(timeline.get_error().is_empty())
	assert_eq(timeline.get_duration_seconds(), 0.0)
	assert_eq(timeline.get_initial_values(), {})
	assert_eq(timeline.sample(0.0), {})


func _assert_native_relative_samples(delay: float, loops: int, times: Array[float]) -> void:
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.capture({"steps": [_step(4.0, 1.0, delay, true)], "loop_count": loops}, _properties())
	assert_eq(timeline.get_error(), "")
	assert_eq(timeline.get_duration_seconds(), (1.0 + delay) * loops)
	for seconds: float in times:
		var probe: NumericProbe = NumericProbe.new()
		var native: Tween = create_tween()
		native.pause()
		var _looped: Tween = native.set_loops(loops)
		var _property: PropertyTweener = native.tween_property(probe, ^"progress", 4.0, 1.0).as_relative().set_delay(delay).set_trans(Tween.TRANS_LINEAR)
		var _playing: bool = native.custom_step(seconds)
		assert_almost_eq(GFVariantData.get_option_float(timeline.sample(seconds), "progress"), probe.progress, 0.00001, "Native at %s" % seconds)
		native.kill()


class NumericProbe extends RefCounted:
	var progress: float = 0.0
	var count: int = 0
