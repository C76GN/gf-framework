## 测试 GFShaderParameterProfile 与 GFShaderParameterUtility 的参数声明、插值和应用行为。
extends GutTest


func test_profile_normalizes_keys_and_deep_copies_values() -> void:
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var nested_value: Dictionary = { "curve": [1, 2, 3] }

	var _set_parameter_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", nested_value)
	var source_curve_value: Variant = nested_value["curve"]
	if source_curve_value is Array:
		var source_curve: Array = source_curve_value
		source_curve.append(4)

	var stored_value: Dictionary = GFVariantData.as_dictionary(profile.get_parameter(&"storm_pressure"))
	var stored_curve: Array = GFVariantData.as_array(stored_value["curve"])

	assert_true(profile.has_parameter(&"storm_pressure"))
	assert_eq(stored_curve.size(), 3, "Profile 应复制集合值，避免外部修改污染参数。")
	assert_eq(profile.get_parameter_names(), [&"storm_pressure"])


func test_profile_merge_respects_overwrite_flag() -> void:
	var base: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var source: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _base_storm_result: GFShaderParameterProfile = base.set_parameter(&"storm_pressure", 0.2)
	var _source_storm_result: GFShaderParameterProfile = source.set_parameter(&"storm_pressure", 0.8)
	var _source_rain_result: GFShaderParameterProfile = source.set_parameter(&"rain_amount", 0.4)

	var _merge_result: GFShaderParameterProfile = base.merge_from(source, false)

	assert_almost_eq(GFVariantData.to_float(base.get_parameter(&"storm_pressure")), 0.2, 0.001)
	assert_almost_eq(GFVariantData.to_float(base.get_parameter(&"rain_amount")), 0.4, 0.001)


func test_profile_blend_interpolates_supported_values() -> void:
	var calm: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var storm: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _calm_pressure_result: GFShaderParameterProfile = calm.set_parameter(&"storm_pressure", 0.0)
	var _calm_tint_result: GFShaderParameterProfile = calm.set_parameter(&"atmosphere_tint", Color(0.0, 0.0, 0.0, 0.0))
	var _calm_wind_result: GFShaderParameterProfile = calm.set_parameter(&"wind_direction", Vector2.RIGHT)
	var _storm_pressure_result: GFShaderParameterProfile = storm.set_parameter(&"storm_pressure", 1.0)
	var _storm_tint_result: GFShaderParameterProfile = storm.set_parameter(&"atmosphere_tint", Color(0.2, 0.4, 0.6, 0.8))
	var _storm_wind_result: GFShaderParameterProfile = storm.set_parameter(&"wind_direction", Vector2.DOWN)

	var blended: GFShaderParameterProfile = calm.blend_with(storm, 0.5)
	var tint: Color = _variant_to_color(blended.get_parameter(&"atmosphere_tint"))
	var wind: Vector2 = _variant_to_vector2(blended.get_parameter(&"wind_direction"))

	assert_almost_eq(GFVariantData.to_float(blended.get_parameter(&"storm_pressure")), 0.5, 0.001)
	assert_almost_eq(tint.r, 0.1, 0.001)
	assert_almost_eq(tint.g, 0.2, 0.001)
	assert_almost_eq(tint.b, 0.3, 0.001)
	assert_almost_eq(tint.a, 0.4, 0.001)
	assert_almost_eq(wind.x, 0.5, 0.001)
	assert_almost_eq(wind.y, 0.5, 0.001)


func test_profile_roundtrips_dictionary() -> void:
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _set_parameter_result: GFShaderParameterProfile = profile.set_parameter(&"fog_amount", 0.25)
	profile.metadata = { "source": "test" }

	var restored: GFShaderParameterProfile = GFShaderParameterProfile.from_dict(profile.to_dict())

	assert_true(restored.has_parameter(&"fog_amount"))
	assert_almost_eq(GFVariantData.to_float(restored.get_parameter(&"fog_amount")), 0.25, 0.001)
	assert_eq(GFVariantData.get_option_string(restored.metadata, "source"), "test")


func test_profile_emits_changed_when_public_methods_mutate_parameters() -> void:
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var counter: Dictionary = { "count": 0 }
	var _changed_connected: Error = profile.changed.connect(func() -> void:
		counter["count"] = GFVariantData.get_option_int(counter, "count") + 1
	) as Error

	var _set_parameter_result: GFShaderParameterProfile = profile.set_parameter(&"fog_amount", 0.25)
	var _erase_result: bool = profile.erase_parameter(&"fog_amount")

	assert_eq(GFVariantData.get_option_int(counter, "count"), 2)


func test_utility_applies_profile_to_shader_material() -> void:
	var utility: GFShaderParameterUtility = GFShaderParameterUtility.new()
	var material: ShaderMaterial = _make_test_shader_material()
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _set_storm_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", 0.75)
	var _set_tint_result: GFShaderParameterProfile = profile.set_parameter(&"atmosphere_tint", Color(0.1, 0.2, 0.3, 0.4))

	var applied_count: int = utility.apply_profile(material, profile)

	assert_eq(applied_count, 2)
	assert_almost_eq(GFVariantData.to_float(material.get_shader_parameter(&"storm_pressure")), 0.75, 0.001)
	assert_eq(_variant_to_color(material.get_shader_parameter(&"atmosphere_tint")), Color(0.1, 0.2, 0.3, 0.4))


func test_utility_skips_missing_declared_parameters_by_default() -> void:
	var utility: GFShaderParameterUtility = GFShaderParameterUtility.new()
	var material: ShaderMaterial = _make_test_shader_material()
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _set_storm_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", 0.5)
	var _set_missing_result: GFShaderParameterProfile = profile.set_parameter(&"missing_parameter", 1.0)

	var applied_count: int = utility.apply_profile(material, profile, {
		"warn_on_missing_parameters": false,
	})

	assert_eq(applied_count, 1)
	assert_almost_eq(GFVariantData.to_float(material.get_shader_parameter(&"storm_pressure")), 0.5, 0.001)


func test_utility_duplicates_target_material_when_requested() -> void:
	var utility: GFShaderParameterUtility = GFShaderParameterUtility.new()
	var original_material: ShaderMaterial = _make_test_shader_material()
	var rect: ColorRect = ColorRect.new()
	rect.material = original_material
	add_child_autofree(rect)
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _set_storm_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", 0.9)

	var applied_count: int = utility.apply_profile(rect, profile, {
		"duplicate_material": true,
	})

	assert_eq(applied_count, 1)
	assert_ne(rect.material, original_material, "复制模式应避免修改共享材质资源。")
	var duplicated_material: ShaderMaterial = _variant_to_shader_material(rect.material)
	assert_almost_eq(GFVariantData.to_float(original_material.get_shader_parameter(&"storm_pressure")), 0.0, 0.001)
	assert_almost_eq(GFVariantData.to_float(duplicated_material.get_shader_parameter(&"storm_pressure")), 0.9, 0.001)


func test_utility_reports_shader_uniform_names() -> void:
	var utility: GFShaderParameterUtility = GFShaderParameterUtility.new()
	var material: ShaderMaterial = _make_test_shader_material()
	var names: Array[StringName] = utility.get_shader_parameter_names(material)

	assert_true(names.has(&"storm_pressure"))
	assert_true(names.has(&"atmosphere_tint"))
	assert_true(utility.has_shader_parameter(material, &"wind_direction"))


func test_binder_applies_profile_to_parent_on_ready() -> void:
	var rect: ColorRect = ColorRect.new()
	rect.material = _make_test_shader_material()
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var _set_storm_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", 0.65)
	var binder: GFShaderParameterBinder = GFShaderParameterBinder.new()
	binder.profile = profile
	rect.add_child(binder)

	add_child_autofree(rect)

	var material: ShaderMaterial = _variant_to_shader_material(rect.material)
	assert_almost_eq(GFVariantData.to_float(material.get_shader_parameter(&"storm_pressure")), 0.65, 0.001)


func test_binder_reapplies_when_profile_changes() -> void:
	var rect: ColorRect = ColorRect.new()
	rect.material = _make_test_shader_material()
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	var binder: GFShaderParameterBinder = GFShaderParameterBinder.new()
	binder.apply_on_ready = false
	binder.profile = profile
	rect.add_child(binder)
	add_child_autofree(rect)

	var _set_storm_result: GFShaderParameterProfile = profile.set_parameter(&"storm_pressure", 0.55)

	var material: ShaderMaterial = _variant_to_shader_material(rect.material)
	assert_almost_eq(GFVariantData.to_float(material.get_shader_parameter(&"storm_pressure")), 0.55, 0.001)


func _make_test_shader_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = "\n".join(PackedStringArray([
		"shader_type canvas_item;",
		"uniform float storm_pressure = 0.0;",
		"uniform float rain_amount = 0.0;",
		"uniform vec2 wind_direction = vec2(1.0, 0.0);",
		"uniform vec4 atmosphere_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);",
		"void fragment() {",
		"	COLOR = atmosphere_tint;",
		"}",
	]))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _variant_to_color(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT


func _variant_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	return Vector2.ZERO


func _variant_to_shader_material(value: Variant) -> ShaderMaterial:
	if value is ShaderMaterial:
		var material: ShaderMaterial = value
		return material
	return null
