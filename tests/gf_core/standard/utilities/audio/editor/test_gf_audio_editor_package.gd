extends GutTest


# --- 测试方法 ---

func test_audio_editor_package_loads_inspector_script() -> void:
	var script: GDScript = _load_script("res://addons/gf/standard/utilities/audio/editor/gf_audio_bank_inspector_plugin.gd")
	if script == null:
		return

	assert_eq(script.get_instance_base_type(), "EditorInspectorPlugin")


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
