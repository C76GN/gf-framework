extends GutTest


# --- 测试方法 ---

func test_spatial_editor_package_loads_editor_scripts() -> void:
	var property_script: GDScript = _load_script("res://addons/gf/standard/foundation/math/editor/gf_pattern_2d_editor_property.gd")
	var inspector_script: GDScript = _load_script("res://addons/gf/standard/foundation/math/editor/gf_pattern_2d_inspector_plugin.gd")
	if property_script == null or inspector_script == null:
		return

	assert_eq(property_script.get_instance_base_type(), "EditorProperty")
	assert_eq(inspector_script.get_instance_base_type(), "EditorInspectorPlugin")
	assert_not_null(GFTileMetadataPaintTool.new())


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
