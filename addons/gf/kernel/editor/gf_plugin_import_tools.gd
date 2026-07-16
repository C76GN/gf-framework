@tool

# GF 插件导入插件管理辅助。
extends RefCounted


# --- 常量 ---

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

var _import_plugins: Array[EditorImportPlugin] = []


# --- 公共方法 ---

## 注册当前启用扩展声明的 EditorImportPlugin。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func setup(plugin: EditorPlugin) -> void:
	if plugin == null:
		return

	cleanup(plugin)
	for import_plugin_path: String in GFExtensionSettingsBase.get_enabled_import_plugin_paths():
		_add_import_plugin(plugin, import_plugin_path)


## 注销已注册的 EditorImportPlugin。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func cleanup(plugin: EditorPlugin) -> void:
	if plugin == null:
		return

	for import_plugin: EditorImportPlugin in _import_plugins:
		if import_plugin != null:
			plugin.remove_import_plugin(import_plugin)
	_import_plugins.clear()


# --- 私有/辅助方法 ---

func _add_import_plugin(plugin: EditorPlugin, script_path: String) -> void:
	var import_plugin: EditorImportPlugin = _load_import_plugin(script_path)
	if import_plugin == null:
		return

	plugin.add_import_plugin(import_plugin)
	_import_plugins.append(import_plugin)


func _load_import_plugin(script_path: String) -> EditorImportPlugin:
	var import_script: Script = _load_script(script_path)
	if import_script == null or not import_script.can_instantiate():
		push_error("[GF Framework] 导入插件脚本加载失败：%s" % script_path)
		return null

	var import_plugin: EditorImportPlugin = _instantiate_import_plugin(import_script)
	if import_plugin == null:
		push_error("[GF Framework] 导入插件实例化失败：%s" % script_path)
		return null

	return import_plugin


func _load_script(script_path: String) -> Script:
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _instantiate_import_plugin(script: Script) -> EditorImportPlugin:
	var instance: Variant = script.call("new")
	if instance is EditorImportPlugin:
		var import_plugin: EditorImportPlugin = instance
		return import_plugin
	return null
