extends GutTest


# --- 测试方法 ---

func test_state_machine_editor_package_loads_editor_scripts() -> void:
	var dock_script: GDScript = _load_script("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd")
	var inspector_script: GDScript = _load_script("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_inspector_plugin.gd")
	if dock_script == null or inspector_script == null:
		return

	assert_eq(dock_script.get_instance_base_type(), "Control")
	assert_eq(inspector_script.get_instance_base_type(), "EditorInspectorPlugin")


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
