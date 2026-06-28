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


# --- 私有/辅助方法 ---

func _load_script(path: String) -> GDScript:
	var resource: Resource = load(path)
	assert_true(resource is GDScript, "%s 应加载为 GDScript。" % path)
	if resource is GDScript:
		var script: GDScript = resource
		return script
	return null
