@tool
extends GutTest


const _PRESETS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/presets/gf_tween_authoring_presets.gd")


func test_effect_catalog_explains_targets_and_initial_value_requirements() -> void:
	for kind: int in range(3):
		var records: Array[Dictionary] = _PRESETS_SCRIPT.get_records(kind)
		var found: Array[String] = []
		for record: Dictionary in records:
			assert_eq(record.size(), 5, "The UI receives a complete, closed recipe record.")
			assert_true(record.get("id") is String)
			assert_true(record.get("label") is String)
			assert_true(record.get("description") is String)
			assert_true(record.get("target_kinds") is Array)
			assert_true(record.get("initial_values") is Dictionary)
			var recipe_id: String = _string(record.get("id"))
			found.append(recipe_id)
			assert_false(_string(record.get("description")).is_empty())
			var kinds_value: Variant = record.get("target_kinds")
			if kinds_value is Array:
				var kinds: Array = kinds_value
				assert_true(kinds.has(kind))
		assert_true(found.has("emphasis"))
		assert_true(found.has("pulse"))
		assert_eq(found.has("fade_in"), kind != 2)


func test_recipe_catalog_rejects_unknown_target_kind() -> void:
	assert_true(_PRESETS_SCRIPT.get_records(-1).is_empty())
	assert_true(_PRESETS_SCRIPT.get_records(3).is_empty())


func test_fade_in_declares_transparent_sample_without_mutating_a_live_target() -> void:
	var target: Control = Control.new()
	target.modulate = Color(0.2, 0.4, 0.6, 0.75)
	var original: Color = target.modulate
	var record: Dictionary = _find_record("fade_in", 1)
	var requirements: Dictionary = _dictionary(record.get("initial_values"))
	assert_true(requirements.get("modulate") is Color)
	var required_color: Variant = requirements.get("modulate")
	if required_color is Color:
		var color: Color = required_color
		assert_eq(color, Color(1.0, 1.0, 1.0, 0.0))
	var steps: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps("fade_in", 1)
	assert_eq(steps.size(), 1)
	assert_eq(target.modulate, original)
	if not steps.is_empty():
		assert_eq(steps[0].property_name, ^"modulate:a")
		var fades_to_opaque: bool = steps[0].target_value == 1.0
		assert_true(fades_to_opaque)
		assert_gt(steps[0].duration, 0.0)
	assert_true(_PRESETS_SCRIPT.create_steps("fade_in", 2).is_empty())
	target.free()


func test_emphasis_and_pulse_have_multiple_named_steps_and_return_to_unit_scale() -> void:
	for kind: int in range(3):
		for recipe_id: String in ["emphasis", "pulse"]:
			var steps: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps(recipe_id, kind)
			assert_gte(steps.size(), 2)
			if steps.is_empty():
				continue
			var record: Dictionary = _find_record(recipe_id, kind)
			var requirements: Dictionary = _dictionary(record.get("initial_values"))
			assert_true(_is_unit_scale(requirements.get("scale"), kind))
			var last_step: GFTweenActionStep = steps[steps.size() - 1]
			assert_true(_is_unit_scale(last_step.target_value, kind))
			for step: GFTweenActionStep in steps:
				assert_eq(step.property_name, ^"scale")
				assert_false(step.as_relative)
				assert_false(step.resource_name.is_empty())
				assert_gt(step.duration, 0.0)
				assert_true(_PRESETS_SCRIPT.get_overrides(step).is_empty())


func test_effect_step_restore_preserves_custom_curve_and_source_step() -> void:
	var steps: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps("emphasis", 1)
	assert_eq(steps.size(), 3)
	if steps.is_empty():
		return
	var source: GFTweenActionStep = steps[1]
	var original_duration: float = source.duration
	var curve: Curve = Curve.new()
	var _first_point: int = curve.add_point(Vector2.ZERO)
	var _last_point: int = curve.add_point(Vector2.ONE)
	source.easing_curve = curve
	source.duration = 0.9
	var restored: GFTweenActionStep = _PRESETS_SCRIPT.restore_step(source, &"duration")
	assert_not_null(restored)
	if restored == null:
		return
	assert_almost_eq(restored.duration, original_duration, 0.000001)
	assert_eq(source.duration, 0.9)
	assert_not_null(restored.easing_curve)
	assert_ne(restored.easing_curve, curve)
	assert_almost_eq(restored.easing_curve.sample_baked(0.5), curve.sample_baked(0.5), 0.000001)
	assert_true(_PRESETS_SCRIPT.get_overrides(restored).is_empty())


func test_effect_steps_and_catalog_records_are_independent_copies() -> void:
	var first: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps("pulse", 2)
	var second: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps("pulse", 2)
	assert_eq(first.size(), 2)
	assert_eq(second.size(), 2)
	if first.is_empty() or second.is_empty():
		return
	first[0].target_value = Vector3.ONE * 2.0
	var independent_target_value: bool = second[0].target_value != first[0].target_value
	assert_true(independent_target_value)
	var record: Dictionary = _find_record("pulse", 2)
	var requirements: Dictionary = _dictionary(record.get("initial_values"))
	requirements["scale"] = Vector3.ZERO
	var later: Dictionary = _find_record("pulse", 2)
	var later_requirements: Dictionary = _dictionary(later.get("initial_values"))
	assert_true(_is_unit_scale(later_requirements.get("scale"), 2))


func test_effect_provenance_survives_save_and_load_for_every_step() -> void:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps = _PRESETS_SCRIPT.create_steps("emphasis", 1)
	assert_eq(config.steps.size(), 3)
	if config.steps.is_empty():
		return
	var path: String = "user://gf_tween_authoring_effect_roundtrip.tres"
	assert_eq(ResourceSaver.save(config, path), OK)
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(resource is GFTweenActionConfig)
	if resource is GFTweenActionConfig:
		var reloaded: GFTweenActionConfig = resource
		assert_eq(reloaded.steps.size(), config.steps.size())
		for index: int in range(reloaded.steps.size()):
			var provenance: Dictionary = _PRESETS_SCRIPT.get_provenance(reloaded.steps[index])
			var expected_recipe_id: bool = provenance.get("preset_id") == "emphasis"
			assert_true(expected_recipe_id)
			assert_true(_PRESETS_SCRIPT.get_overrides(reloaded.steps[index]).is_empty())
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _is_unit_scale(value: Variant, kind: int) -> bool:
	if kind == 2:
		if value is Vector3:
			var scale_3d: Vector3 = value
			return scale_3d == Vector3.ONE
		return false
	if value is Vector2:
		var scale_2d: Vector2 = value
		return scale_2d == Vector2.ONE
	return false


func _find_record(recipe_id: String, kind: int) -> Dictionary:
	for record: Dictionary in _PRESETS_SCRIPT.get_records(kind):
		if record.get("id") == recipe_id:
			return record
	return {}


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = value
		return result
	return {}


func _string(value: Variant) -> String:
	if value is String:
		var result: String = value
		return result
	return ""
