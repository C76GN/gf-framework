extends GutTest


# --- 测试方法 ---

func test_theme_override_property_list_groups_and_marks_stored_overrides() -> void:
	var control: Control = Control.new()
	control.set("theme_override_colors/accent", Color.RED)
	var definitions: Array = [
		GFThemeOverridePropertyList.make_definition(&"accent", Theme.DATA_TYPE_COLOR),
		GFThemeOverridePropertyList.make_definition(&"padding", Theme.DATA_TYPE_CONSTANT),
		GFThemeOverridePropertyList.make_definition(&"panel", Theme.DATA_TYPE_STYLEBOX),
	]

	var entries: Array[Dictionary] = GFThemeOverridePropertyList.make_property_list(control, definitions)
	var color_entry: Dictionary = _find_entry(entries, "theme_override_colors/accent")
	var style_entry: Dictionary = _find_entry(entries, "theme_override_styles/panel")

	assert_false(color_entry.is_empty(), "颜色 override 应进入属性列表。")
	assert_true((GFVariantData.get_option_int(color_entry, "usage") & PROPERTY_USAGE_STORAGE) != 0, "已设置 override 的属性应带 storage usage。")
	assert_eq(GFVariantData.get_option_int(style_entry, "hint"), PROPERTY_HINT_RESOURCE_TYPE, "StyleBox override 应使用资源类型 hint。")
	assert_eq(GFVariantData.get_option_string(style_entry, "hint_string"), "StyleBox")

	control.free()


func test_theme_override_property_path_and_revert_helpers() -> void:
	var definition: Dictionary = GFThemeOverridePropertyList.make_definition(&"title_font", Theme.DATA_TYPE_FONT)
	var definitions: Array = [definition]

	assert_eq(GFThemeOverridePropertyList.get_property_path(definition), "theme_override_fonts/title_font")
	assert_true(GFThemeOverridePropertyList.has_property_path(&"theme_override_fonts/title_font", definitions))
	assert_true(GFThemeOverridePropertyList.can_revert(&"theme_override_fonts/title_font", definitions))
	var revert_value: Variant = GFThemeOverridePropertyList.get_revert_value(&"theme_override_fonts/title_font")
	assert_true(revert_value == null, "Theme override 属性默认 revert 值应为空。")


func test_collect_clear_and_build_theme_from_overrides() -> void:
	var control: Control = Control.new()
	control.set("theme_override_colors/accent", Color.RED)
	control.set("theme_override_constants/gap", 8)
	var definitions: Array = [
		GFThemeOverridePropertyList.make_definition(&"accent", Theme.DATA_TYPE_COLOR),
		GFThemeOverridePropertyList.make_definition(&"gap", Theme.DATA_TYPE_CONSTANT),
		GFThemeOverridePropertyList.make_definition(&"empty", Theme.DATA_TYPE_COLOR),
	]

	var values: Dictionary = GFThemeOverridePropertyList.collect_override_values(control, definitions)
	var theme: Theme = GFThemeOverridePropertyList.make_theme_from_values(definitions, values, &"Panel")
	var direct_theme: Theme = GFThemeOverridePropertyList.make_theme_from_control(control, definitions, &"Panel")
	var clear_report: Dictionary = GFThemeOverridePropertyList.clear_overrides(control, definitions)
	var accent_value: Variant = GFVariantData.get_option_value(values, "theme_override_colors/accent")

	assert_eq(values.size(), 2, "只应收集已设置的 theme override。")
	assert_true(accent_value is Color, "颜色 override 值应保持 Color。")
	if accent_value is Color:
		var accent_color: Color = accent_value
		assert_eq(accent_color, Color.RED)
	assert_eq(GFVariantData.get_option_int(values, "theme_override_constants/gap"), 8)
	assert_true(theme.has_color(&"accent", &"Panel"), "收集值应能转换为 Theme color。")
	assert_eq(theme.get_color(&"accent", &"Panel"), Color.RED)
	assert_eq(theme.get_constant(&"gap", &"Panel"), 8)
	assert_eq(direct_theme.get_color(&"accent", &"Panel"), Color.RED)
	assert_true(GFVariantData.get_option_bool(clear_report, "ok"), "清空有效 override 不应产生 issue。")
	assert_eq(GFVariantData.get_option_int(clear_report, "cleared_count"), 2)
	assert_eq(GFVariantData.get_option_int(clear_report, "skipped_count"), 1)
	assert_false(control.has_theme_color_override(&"accent"), "清空后颜色 override 应移除。")
	assert_false(control.has_theme_constant_override(&"gap"), "清空后常量 override 应移除。")

	control.free()


# --- 私有/辅助方法 ---

func _find_entry(entries: Array[Dictionary], property_path: String) -> Dictionary:
	for entry: Dictionary in entries:
		if GFVariantData.get_option_string(entry, "name") == property_path:
			return entry
	return {}
