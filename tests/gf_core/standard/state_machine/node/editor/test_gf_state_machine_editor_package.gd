extends GutTest


# --- 测试方法 ---

func test_state_machine_editor_package_loads_editor_scripts() -> void:
	var dock_script: GDScript = _load_script("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd")
	var inspector_script: GDScript = _load_script("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_inspector_plugin.gd")
	if dock_script == null or inspector_script == null:
		return

	assert_eq(dock_script.get_instance_base_type(), "Control")
	assert_eq(inspector_script.get_instance_base_type(), "EditorInspectorPlugin")


func test_state_machine_dock_uses_report_codec_for_details_json() -> void:
	var dock: GFNodeStateMachineDock = GFNodeStateMachineDock.new()
	var payload: Resource = Resource.new()
	payload.take_over_path("res://private/state_payload.tres")
	var json_text: String = dock.call("_safe_json", {
		"color": Color.RED,
		"resource": payload,
	})
	var parsed: Variant = JSON.parse_string(json_text)

	assert_true(parsed is Dictionary, "详情文本应始终是可解析 JSON。")
	var parsed_dictionary: Dictionary = GFVariantData.as_dictionary(parsed)
	assert_true(GFVariantData.get_option_value(parsed_dictionary, "color") is Dictionary, "Color 应经统一报告 codec 编码。")
	assert_true(GFVariantData.get_option_value(parsed_dictionary, "resource") is Dictionary, "Resource 应经统一报告 codec 编码。")

	dock.free()


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
