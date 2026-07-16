@tool

# GF 插件 Inspector 与导出插件管理辅助。
extends RefCounted


# --- 常量 ---

## 扩展导出过滤插件脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EXTENSION_EXPORT_PLUGIN_SCRIPT_PATH: String = "res://addons/gf/kernel/editor/extension/gf_extension_export_plugin.gd"

## GF 通用资源路径 Inspector 脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const RESOURCE_PATH_INSPECTOR_PLUGIN_SCRIPT_PATH: String = "res://addons/gf/kernel/editor/gf_resource_path_inspector_plugin.gd"

## GF ProjectSettings 本地化 Inspector 脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PROJECT_SETTINGS_INSPECTOR_PLUGIN_SCRIPT_PATH: String = "res://addons/gf/kernel/editor/gf_project_settings_inspector_plugin.gd"

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PROJECT_SETTINGS_SECTION_PRESENTER_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_settings_section_presenter.gd")


# --- 私有变量 ---

var _inspector_plugins: Array[EditorInspectorPlugin] = []
var _standard_export_plugins: Array[EditorExportPlugin] = []
var _extension_export_plugin: EditorExportPlugin
var _extension_export_plugins: Array[EditorExportPlugin] = []
var _standard_inspector_records: Array[Dictionary] = []
var _standard_export_records: Array[Dictionary] = []
var _project_setting_records: Array[Dictionary] = []
var _project_setting_section_records: Array[Dictionary] = []
var _project_settings_section_presenter: RefCounted = null
var _presentation_locale: String = ""


# --- 公共方法 ---

## 安装 GF Inspector 与导出插件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
## [br]
## @param editor_records: 组合入口传入的 Inspector、导出插件与项目设置记录。
## [br]
## @schema editor_records: Dictionary containing inspector_plugin_records, export_plugin_records, project_setting_records, and project_setting_section_records arrays.
## [br]
## @param presentation_locale: 展示语言覆盖；留空时跟随 Godot 当前工具语言。
func setup(
	plugin: EditorPlugin,
	editor_records: Dictionary = {},
	presentation_locale: String = ""
) -> void:
	if plugin == null:
		return
	cleanup(plugin)
	_standard_inspector_records = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(editor_records, "inspector_plugin_records", [])
	)
	_standard_export_records = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(editor_records, "export_plugin_records", [])
	)
	_project_setting_records = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(editor_records, "project_setting_records", [])
	)
	_project_setting_section_records = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			editor_records,
			"project_setting_section_records",
			[]
		)
	)
	_presentation_locale = presentation_locale.strip_edges()
	_setup_inspector_tools(plugin)
	_setup_standard_export_plugins(plugin)
	_setup_extension_export_plugin(plugin)
	_setup_enabled_extension_export_plugins(plugin)


## 移除 GF Inspector 与导出插件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func cleanup(plugin: EditorPlugin) -> void:
	if plugin == null:
		return
	_cleanup_project_settings_section_presenter()
	_cleanup_enabled_extension_export_plugins(plugin)
	_cleanup_extension_export_plugin(plugin)
	_cleanup_standard_export_plugins(plugin)
	_cleanup_inspector_tools(plugin)
	_presentation_locale = ""


# --- 私有/辅助方法 ---

func _setup_inspector_tools(plugin: EditorPlugin) -> void:
	_add_inspector_plugin(
		plugin,
		RESOURCE_PATH_INSPECTOR_PLUGIN_SCRIPT_PATH,
		"Resource Path Inspector"
	)
	for record: Dictionary in _standard_inspector_records:
		_add_inspector_plugin(
			plugin,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label")
		)
	for record: Dictionary in _collect_enabled_extension_inspector_records():
		_add_inspector_plugin(
			plugin,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label")
		)
	_add_project_settings_inspector_plugin(plugin)
	_setup_project_settings_section_presenter()


func _add_project_settings_inspector_plugin(plugin: EditorPlugin) -> void:
	var inspector_plugin: EditorInspectorPlugin = _load_inspector_plugin(
		PROJECT_SETTINGS_INSPECTOR_PLUGIN_SCRIPT_PATH,
		"GF ProjectSettings Inspector"
	)
	if inspector_plugin == null:
		return
	if not inspector_plugin.has_method(&"configure"):
		push_error("[GF Framework] ProjectSettings Inspector 缺少 configure()。")
		return

	var _configure_result: Variant = inspector_plugin.call(
		&"configure",
		_project_setting_records,
		_project_setting_section_records,
		_presentation_locale
	)
	plugin.add_inspector_plugin(inspector_plugin)
	_inspector_plugins.append(inspector_plugin)


func _setup_project_settings_section_presenter() -> void:
	var presenter_value: Variant = _GF_PROJECT_SETTINGS_SECTION_PRESENTER_SCRIPT.new()
	if not presenter_value is RefCounted:
		push_error("[GF Framework] ProjectSettings 分区展示器实例化失败。")
		return
	_project_settings_section_presenter = presenter_value
	var _setup_result: Variant = _project_settings_section_presenter.call(
		&"setup",
		_project_setting_records,
		_project_setting_section_records,
		_presentation_locale
	)


func _cleanup_project_settings_section_presenter() -> void:
	if _project_settings_section_presenter != null:
		var _cleanup_result: Variant = _project_settings_section_presenter.call(&"cleanup")
	_project_settings_section_presenter = null


func _setup_standard_export_plugins(plugin: EditorPlugin) -> void:
	for record: Dictionary in _standard_export_records:
		var export_plugin: EditorExportPlugin = _load_export_plugin(
			_get_record_string(record, "path"),
			_get_record_string(record, "label")
		)
		if export_plugin == null:
			continue
		plugin.add_export_plugin(export_plugin)
		_standard_export_plugins.append(export_plugin)


func _setup_extension_export_plugin(plugin: EditorPlugin) -> void:
	var export_script: Script = _load_script(EXTENSION_EXPORT_PLUGIN_SCRIPT_PATH)
	if export_script == null or not export_script.can_instantiate():
		push_error("[GF Framework] 扩展导出过滤插件脚本加载失败。")
		return

	_extension_export_plugin = _instantiate_export_plugin(export_script)
	if _extension_export_plugin == null:
		push_error("[GF Framework] 扩展导出过滤插件实例化失败。")
		return

	plugin.add_export_plugin(_extension_export_plugin)


func _setup_enabled_extension_export_plugins(plugin: EditorPlugin) -> void:
	for export_plugin_path: String in GFExtensionSettingsBase.get_enabled_export_plugin_paths():
		var export_plugin: EditorExportPlugin = _load_export_plugin(export_plugin_path, export_plugin_path)
		if export_plugin == null:
			continue
		plugin.add_export_plugin(export_plugin)
		_extension_export_plugins.append(export_plugin)


func _load_inspector_plugin(script_path: String, label: String) -> EditorInspectorPlugin:
	var inspector_script: Script = _load_script(script_path)
	if inspector_script == null or not inspector_script.can_instantiate():
		push_error("[GF Framework] %s 插件脚本加载失败。" % label)
		return null

	var inspector_plugin: EditorInspectorPlugin = _instantiate_inspector_plugin(inspector_script)
	if inspector_plugin == null:
		push_error("[GF Framework] %s 插件实例化失败。" % label)
		return null

	return inspector_plugin


func _load_export_plugin(script_path: String, label: String) -> EditorExportPlugin:
	var export_script: Script = _load_script(script_path)
	if export_script == null or not export_script.can_instantiate():
		push_error("[GF Framework] %s 导出插件脚本加载失败。" % label)
		return null

	var export_plugin: EditorExportPlugin = _instantiate_export_plugin(export_script)
	if export_plugin == null:
		push_error("[GF Framework] %s 导出插件实例化失败。" % label)
		return null

	return export_plugin


func _add_inspector_plugin(plugin: EditorPlugin, script_path: String, label: String) -> void:
	var inspector_plugin: EditorInspectorPlugin = _load_inspector_plugin(script_path, label)
	if inspector_plugin == null:
		return

	plugin.add_inspector_plugin(inspector_plugin)
	_inspector_plugins.append(inspector_plugin)


func _collect_enabled_extension_inspector_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var used_paths: Dictionary = {}
	for manifest: GFExtensionManifest in GFExtensionSettingsBase.get_enabled_manifests():
		for inspector_path: String in manifest.editor_inspector_paths:
			var normalized_path: String = inspector_path.strip_edges()
			if normalized_path.is_empty() or used_paths.has(normalized_path):
				continue

			used_paths[normalized_path] = true
			records.append({
				"path": normalized_path,
				"label": _get_extension_inspector_label(manifest, normalized_path),
			})
	return records


func _get_extension_inspector_label(manifest: GFExtensionManifest, inspector_path: String) -> String:
	var extension_name: String = manifest.display_name
	if extension_name.is_empty():
		extension_name = manifest.id
	var script_name: String = inspector_path.get_file().get_basename().to_pascal_case()
	return "%s %s" % [extension_name, script_name]


func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	for record_variant: Variant in value:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			records.append(record.duplicate(true))
	return records


func _get_record_string(record: Dictionary, key: String) -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, key, "")


func _load_script(script_path: String) -> Script:
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _instantiate_inspector_plugin(script: Script) -> EditorInspectorPlugin:
	var instance: Variant = script.call("new")
	if instance is EditorInspectorPlugin:
		var plugin: EditorInspectorPlugin = instance
		return plugin
	return null


func _instantiate_export_plugin(script: Script) -> EditorExportPlugin:
	var instance: Variant = script.call("new")
	if instance is EditorExportPlugin:
		var plugin: EditorExportPlugin = instance
		return plugin
	return null


func _cleanup_inspector_tools(plugin: EditorPlugin) -> void:
	for inspector_plugin: EditorInspectorPlugin in _inspector_plugins:
		if inspector_plugin != null:
			plugin.remove_inspector_plugin(inspector_plugin)
	_inspector_plugins.clear()


func _cleanup_standard_export_plugins(plugin: EditorPlugin) -> void:
	for export_plugin: EditorExportPlugin in _standard_export_plugins:
		if export_plugin != null:
			plugin.remove_export_plugin(export_plugin)
	_standard_export_plugins.clear()


func _cleanup_extension_export_plugin(plugin: EditorPlugin) -> void:
	if _extension_export_plugin != null:
		plugin.remove_export_plugin(_extension_export_plugin)
		_extension_export_plugin = null


func _cleanup_enabled_extension_export_plugins(plugin: EditorPlugin) -> void:
	for export_plugin: EditorExportPlugin in _extension_export_plugins:
		if export_plugin != null:
			plugin.remove_export_plugin(export_plugin)
	_extension_export_plugins.clear()
