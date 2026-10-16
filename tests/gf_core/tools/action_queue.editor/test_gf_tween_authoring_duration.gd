@tool
extends GutTest

const _DURATION_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_duration.gd")
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")


func test_target_total_seconds_uses_parallel_delays_loops_and_ping_pong() -> void:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var move: GFTweenActionStep = config.add_property_step(
		^"position:x",
		10.0,
		1.0
	)
	move.delay = 0.5
	var alpha: GFTweenActionStep = config.add_property_step(
		^"modulate:a",
		0.4,
		2.0
	)
	alpha.parallel = true
	alpha.delay = 0.25
	var scale: GFTweenActionStep = config.add_property_step(
		^"scale",
		Vector2.ONE * 1.1,
		0.75
	)
	scale.delay = 0.25
	config.duration_scale = 2.0
	config.loop_count = 2
	config.ping_pong = true
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 1)
	assert_eq(plan.error, "")
	assert_almost_eq(
		plan.duration_seconds,
		26.0,
		0.000001
	)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	var result: Dictionary = _DURATION_SCRIPT.calculate(
		plan,
		2.0,
		signature,
		signature,
		6.5
	)
	_assert_success(
		result,
		0.5,
		6.5
	)
	assert_eq(
		config.duration_scale,
		2.0,
		"Calculating does not submit a resource edit."
	)
	assert_eq(move.duration, 1.0)
	assert_eq(alpha.delay, 0.25)
	assert_almost_eq(
		plan.duration_seconds,
		26.0,
		0.000001
	)
	config.duration_scale = _number(result.get("duration_scale"))
	var adjusted: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 1)
	assert_eq(adjusted.error, "")
	assert_almost_eq(
		adjusted.duration_seconds,
		6.5,
		0.000001
	)
	assert_eq(config.loop_count, 2)
	assert_true(config.ping_pong)


func test_numeric_adapter_plan_uses_the_same_total_seconds_calculation() -> void:
	var config: GFTweenActionConfig = _config(
		^"progress",
		1.0,
		0.6
	)
	var properties: Array[Dictionary] = [
		{
			"name": "progress",
			"type": TYPE_FLOAT,
			"initial": 0.0,
			"minimum": 0.0,
			"maximum": 1.0,
		},
	]
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture_numeric(config, properties)
	assert_eq(plan.error, "")
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	var result: Dictionary = _DURATION_SCRIPT.calculate(
		plan,
		1.0,
		signature,
		signature,
		1.2
	)
	_assert_success(
		result,
		2.0,
		1.2
	)
	assert_eq(config.duration_scale, 1.0)


func test_exact_time_budget_is_accepted_and_one_more_fraction_is_rejected() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		1.0,
		1.0
	)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_success(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			120.0
		),
		120.0,
		120.0
	)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			120.000001
		)
	)
	assert_eq(config.duration_scale, 1.0)


func test_parallel_actual_total_cannot_bypass_cumulative_time_budget() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		1.0,
		1.0
	)
	var scale: GFTweenActionStep = config.add_property_step(
		^"scale",
		Vector2.ONE * 1.1,
		1.0
	)
	scale.parallel = true
	var alpha: GFTweenActionStep = config.add_property_step(
		^"modulate:a",
		0.5,
		1.0
	)
	alpha.parallel = true
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 1)
	assert_eq(plan.error, "")
	assert_eq(plan.duration_seconds, 1.0)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_success(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			40.0
		),
		40.0,
		40.0
	)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			45.0
		)
	)
	assert_eq(config.duration_scale, 1.0)


func test_nonpositive_and_nonfinite_target_seconds_never_return_a_candidate_scale() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		1.0,
		1.0
	)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	for seconds: float in [
		0.0,
		-1.0,
		NAN,
		INF,
	]:
		_assert_rejected(
			_DURATION_SCRIPT.calculate(
				plan,
				1.0,
				signature,
				signature,
				seconds
			)
		)
	assert_eq(config.duration_scale, 1.0)


func test_zero_baseline_zero_scale_and_infinite_loops_are_rejected() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		1.0,
		0.0
	)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	assert_eq(
		plan.error,
		"",
		"Native instantaneous preview is valid, but cannot define a new total duration."
	)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			1.0
		)
	)
	config.steps[0].duration = 1.0
	config.duration_scale = 0.0
	plan = GFTweenPreviewPlan.capture(config, 0)
	signature = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			0.0,
			signature,
			signature,
			1.0
		)
	)
	config.duration_scale = 1.0
	config.loop_count = 0
	plan = GFTweenPreviewPlan.capture(config, 0)
	assert_false(plan.error.is_empty())
	signature = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			1.0
		)
	)


func test_failed_empty_and_over_budget_captures_cannot_be_used_for_duration_edits() -> void:
	var config: GFTweenActionConfig = _config(
		^"unsupported_property",
		1.0,
		1.0
	)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	var signature: Array = _SNAPSHOT_SCRIPT.capture(config)
	assert_false(plan.error.is_empty())
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			1.0
		)
	)
	config.steps.clear()
	plan = GFTweenPreviewPlan.capture(config, 0)
	signature = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			1.0
		)
	)
	for index: int in range(129):
		var _step: GFTweenActionStep = config.add_property_step(
			^"position:x",
			float(index),
			0.01
		)
	plan = GFTweenPreviewPlan.capture(config, 0)
	signature = _SNAPSHOT_SCRIPT.capture(config)
	assert_false(plan.error.is_empty())
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			signature,
			signature,
			1.0
		)
	)


func test_in_place_source_edits_reject_the_old_frozen_plan_without_changing_it() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		10.0,
		1.0
	)
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	var captured: Array = _SNAPSHOT_SCRIPT.capture(config)
	config.steps[0].duration = 2.0
	var current: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			captured,
			current,
			3.0
		)
	)
	assert_eq(
		config.steps[0].duration,
		2.0
	)
	assert_eq(plan.duration_seconds, 1.0)
	assert_ne(captured, current)


func test_in_place_curve_edits_and_mismatched_capture_scale_are_rejected() -> void:
	var config: GFTweenActionConfig = _config(
		^"position:x",
		10.0,
		1.0
	)
	var curve: Curve = Curve.new()
	var _first_point: int = curve.add_point(Vector2.ZERO)
	var _last_point: int = curve.add_point(Vector2.ONE)
	config.steps[0].easing_curve = curve
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.capture(config, 0)
	assert_eq(plan.error, "")
	var captured: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			2.0,
			captured,
			captured,
			1.0
		)
	)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			[],
			[],
			1.0
		)
	)
	var _middle_point: int = curve.add_point(Vector2(0.5, 0.7))
	var current: Array = _SNAPSHOT_SCRIPT.capture(config)
	_assert_rejected(
		_DURATION_SCRIPT.calculate(
			plan,
			1.0,
			captured,
			current,
			2.0
		)
	)
	assert_eq(
		curve.get_point_count(),
		3
	)
	assert_eq(plan.duration_seconds, 1.0)


func _assert_success(
	result: Dictionary,
	expected_scale: float,
	expected_seconds: float
) -> void:
	assert_eq(
		result.size(),
		4
	)
	var accepted: bool = result.get("ok") == true
	var error_is_empty: bool = result.get("error") == ""
	assert_true(accepted)
	assert_true(error_is_empty)
	assert_almost_eq(
		_number(result.get("duration_scale")),
		expected_scale,
		0.000001
	)
	assert_almost_eq(
		_number(result.get("total_seconds")),
		expected_seconds,
		0.000001
	)


func _assert_rejected(result: Dictionary) -> void:
	assert_eq(
		result.size(),
		4
	)
	var rejected: bool = result.get("ok") == false
	assert_true(rejected)
	var error_value: Variant = result.get("error")
	assert_true(error_value is String)
	if error_value is String:
		var message: String = error_value
		assert_false(message.is_empty())
	assert_true(result.get("duration_scale") is float)
	assert_true(result.get("total_seconds") is float)
	var scale_is_zero: bool = result.get("duration_scale") == 0.0
	var seconds_are_zero: bool = result.get("total_seconds") == 0.0
	assert_true(scale_is_zero)
	assert_true(seconds_are_zero)


func _config(
	property_path: NodePath,
	target_value: Variant,
	duration: float
) -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var _step: GFTweenActionStep = config.add_property_step(
		property_path,
		target_value,
		duration
	)
	return config


func _number(value: Variant) -> float:
	if value is float:
		var result: float = value
		return result
	if value is int:
		var result: int = value
		return float(result)
	return NAN
