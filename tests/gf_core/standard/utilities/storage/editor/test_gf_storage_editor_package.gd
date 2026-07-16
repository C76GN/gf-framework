extends GutTest


# --- 测试方法 ---

func test_storage_editor_package_loads_viewer_dock_script() -> void:
	var script: GDScript = _load_script("res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd")
	if script == null:
		return

	assert_eq(script.get_instance_base_type(), "VBoxContainer")
	var dock: GFStorageViewerDock = GFStorageViewerDock.new()
	assert_not_null(dock)
	dock.free()


func test_storage_viewer_formats_decoded_data_with_variant_json_codec() -> void:
	var dock: GFStorageViewerDock = GFStorageViewerDock.new()
	var output: String = dock._format_decoded_data_for_display({
		"position": Vector2(1.0, 2.0),
		"values": PackedFloat32Array([NAN, INF]),
	})
	dock.free()

	assert_true(output.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "Viewer 输出应保留 Godot Variant 类型标记。")
	assert_true(output.contains("NaN"), "Viewer 输出应保留 NaN 语义。")
	assert_true(output.contains("INF"), "Viewer 输出应保留 INF 语义。")
	assert_false(output.contains("null"), "Viewer 输出不应依赖 JSON.stringify 把非有限值降级为 null。")


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
