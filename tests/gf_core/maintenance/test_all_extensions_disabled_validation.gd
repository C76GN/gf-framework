## 验证所有 GF 内置扩展禁用时 kernel/standard 仍可独立加载。
extends GutTest


# --- 常量 ---

const SOURCE_ROOTS: Array[String] = [
	"res://addons/gf/kernel",
	"res://addons/gf/standard",
]
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_PLUGIN_ACTIONS = preload("res://addons/gf/kernel/editor/gf_plugin_actions.gd")
const GF_PLUGIN_DOCK_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const GF_PLUGIN_INSPECTOR_TOOLS = preload("res://addons/gf/kernel/editor/gf_plugin_inspector_tools.gd")


# --- 测试用例 ---

func test_all_extensions_disabled_keeps_extension_queries_empty() -> void:
	var restore: Dictionary = _set_enabled_extensions([])
	var enabled_manifests: Array = GFExtensionSettings.get_enabled_manifests()
	var editor_action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()
	var editor_dock_paths: Array[String] = GFExtensionSettings.get_enabled_editor_dock_paths()
	var editor_inspector_paths: Array[String] = GFExtensionSettings.get_enabled_editor_inspector_paths()
	var export_plugin_paths: Array[String] = GFExtensionSettings.get_enabled_export_plugin_paths()
	var gltf_document_paths: Array[String] = GFExtensionSettings.get_enabled_gltf_document_extension_paths()
	var access_extension_paths: Array[String] = GFExtensionSettings.get_enabled_access_generator_extension_paths()
	var debugger_plugin_paths: Array[String] = GFExtensionSettings.get_enabled_debugger_plugin_paths()
	_restore_enabled_extensions(restore)

	assert_true(enabled_manifests.is_empty(), "全禁用时不应解析出启用扩展 manifest。")
	assert_true(editor_action_paths.is_empty(), "全禁用时不应暴露扩展菜单动作。")
	assert_true(editor_dock_paths.is_empty(), "全禁用时不应暴露扩展 Dock。")
	assert_true(editor_inspector_paths.is_empty(), "全禁用时不应暴露扩展 Inspector。")
	assert_true(export_plugin_paths.is_empty(), "全禁用时不应暴露扩展导出插件。")
	assert_true(gltf_document_paths.is_empty(), "全禁用时不应暴露 glTF 文档扩展。")
	assert_true(access_extension_paths.is_empty(), "全禁用时不应暴露扩展访问器扩展。")
	assert_true(debugger_plugin_paths.is_empty(), "全禁用时不应暴露扩展 Debugger 插件。")


func test_all_extensions_disabled_plugin_helpers_discover_no_extension_extensions() -> void:
	var restore: Dictionary = _set_enabled_extensions([])
	var actions: Object = _new_object(GF_PLUGIN_ACTIONS)
	_call_void(actions, &"_load_extension_editor_actions")
	_call_void(actions, &"_register_loaded_extension_action_entries")
	var action_entries: Array[Dictionary] = _filter_extension_menu_entries(
		_call_array(actions, &"get_menu_entries"),
		_read_int(actions, &"EXTENSION_MENU_ID_START")
	)
	_call_void(actions, &"_cleanup_extension_editor_actions")

	var dock_tools: Object = _new_object(GF_PLUGIN_DOCK_TOOLS)
	var dock_records: Array = _call_array(dock_tools, &"_collect_enabled_extension_dock_records")

	var inspector_tools: Object = _new_object(GF_PLUGIN_INSPECTOR_TOOLS)
	var inspector_records: Array = _call_array(inspector_tools, &"_collect_enabled_extension_inspector_records")
	_restore_enabled_extensions(restore)

	assert_true(action_entries.is_empty(), "全禁用时 GF 菜单不应注册扩展级动作。")
	assert_true(dock_records.is_empty(), "全禁用时不应注册扩展级 Dock。")
	assert_true(inspector_records.is_empty(), "全禁用时不应注册扩展级 Inspector。")


func test_kernel_and_standard_scripts_load_with_all_extensions_disabled() -> void:
	var restore: Dictionary = _set_enabled_extensions([])
	var paths: Array[String] = []
	for root: String in SOURCE_ROOTS:
		_collect_gd_files(root, paths)

	var issues: Array[String] = []
	for path: String in paths:
		if load(path) == null:
			issues.append(path)
	_restore_enabled_extensions(restore)

	assert_eq(issues, [], "全禁用时 kernel/standard 脚本仍应可加载：\n%s" % _join_lines(issues))


# --- 私有/辅助方法 ---

func _set_enabled_extensions(extension_ids: Array[String]) -> Dictionary:
	var setting_name: String = GFExtensionSettings.ENABLED_EXTENSIONS_SETTING
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, []),
		"selection_mode_had_setting": ProjectSettings.has_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING
		),
		"selection_mode_value": ProjectSettings.get_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
			null
		),
	}
	ProjectSettings.set_setting(setting_name, extension_ids)
	ProjectSettings.set_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_EXPLICIT
	)
	return restore


func _restore_enabled_extensions(restore: Dictionary) -> void:
	var setting_name: String = GFExtensionSettings.ENABLED_EXTENSIONS_SETTING
	if GF_VARIANT_ACCESS.get_option_bool(restore, "had_setting", false):
		ProjectSettings.set_setting(setting_name, GF_VARIANT_ACCESS.get_option_value(restore, "value", []))
	else:
		ProjectSettings.clear(setting_name)
	if GF_VARIANT_ACCESS.get_option_bool(restore, "selection_mode_had_setting", false):
		ProjectSettings.set_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
			GF_VARIANT_ACCESS.get_option_value(restore, "selection_mode_value", null)
		)
	else:
		ProjectSettings.clear(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING)


func _new_object(script_value: Variant) -> Object:
	assert_true(script_value is Script, "测试工具脚本应可实例化。")
	if script_value is Script:
		var script: Script = script_value
		var instance: Variant = script.call(&"new")
		assert_true(instance is Object, "测试工具脚本应实例化为 Object。")
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _call_void(target: Object, method_name: StringName, args: Array = []) -> void:
	var _call_result: Variant = target.callv(method_name, args)


func _call_array(target: Object, method_name: StringName, args: Array = []) -> Array:
	return GF_VARIANT_ACCESS.as_array(target.callv(method_name, args))


func _read_int(target: Object, property_name: StringName) -> int:
	return GF_VARIANT_ACCESS.to_int(target.get(property_name))


func _collect_gd_files(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_100: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_files(path, result)
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _filter_extension_menu_entries(entries: Array, extension_menu_id_start: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = GF_VARIANT_ACCESS.as_dictionary(entry_variant)
		if GF_VARIANT_ACCESS.get_option_int(entry, "id", -1) >= extension_menu_id_start:
			result.append(entry.duplicate(true))
	return result


func _join_lines(lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var _append_result_127: Variant = packed.append(line)
	return "\n".join(packed)
