@tool
extends EditorPlugin


# GF Framework 编辑器插件。
# 在启用/禁用插件时自动注册/注销 Gf AutoLoad 单例，并装配 GF 编辑器工具。

# --- 常量 ---

## AutoLoad 管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginAutoload = preload("res://addons/gf/kernel/editor/gf_plugin_autoload.gd")

## ProjectSettings 注册辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginProjectSettings = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")

## Extension Settings 注册辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")

## Inspector 与导出插件管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginInspectorTools = preload("res://addons/gf/kernel/editor/gf_plugin_inspector_tools.gd")

## 菜单动作管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginActions = preload("res://addons/gf/kernel/editor/gf_plugin_actions.gd")

## 工具菜单管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginMenu = preload("res://addons/gf/kernel/editor/gf_plugin_menu.gd")

## 工作区窗口管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginDockTools = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")

## Debugger 插件管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginDebuggerTools = preload("res://addons/gf/kernel/editor/gf_plugin_debugger_tools.gd")

## 导入插件管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginImportTools = preload("res://addons/gf/kernel/editor/gf_plugin_import_tools.gd")

## Resource 预览生成器管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginPreviewTools = preload("res://addons/gf/kernel/editor/gf_plugin_preview_tools.gd")

## glTF 文档扩展管理辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GFPluginGltfDocumentTools = preload("res://addons/gf/kernel/editor/gf_plugin_gltf_document_tools.gd")

## 编辑器贡献清单读取辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")

## 标准库编辑器贡献清单路径。
## [br]
## @api framework_internal
## [br]
## @layer plugin
const STANDARD_EDITOR_CONTRIBUTIONS_MANIFEST_PATH: String = "res://addons/gf/standard/editor/gf_editor_contributions.json"
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _inspector_tools: GFPluginInspectorTools
var _actions: GFPluginActions
var _menu: GFPluginMenu
var _dock_tools: GFPluginDockTools
var _debugger_tools: GFPluginDebuggerTools
var _import_tools: GFPluginImportTools
var _preview_tools: GFPluginPreviewTools
var _gltf_document_tools: GFPluginGltfDocumentTools
var _plugin_active: bool = false
var _standard_editor_extension_records: Dictionary = {}


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_plugin_active = true
	GFPluginAutoload.ensure(self)
	_standard_editor_extension_records = _collect_standard_editor_extension_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(_standard_editor_extension_records, "project_setting_records"))
	_setup_actions_and_menu()
	var active_editor_records: Dictionary = _make_active_editor_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(active_editor_records, "project_setting_records"))

	_inspector_tools = GFPluginInspectorTools.new()
	_inspector_tools.setup(self, active_editor_records)

	_dock_tools = GFPluginDockTools.new()
	_debugger_tools = GFPluginDebuggerTools.new()
	_debugger_tools.setup(self, _standard_editor_extension_records)

	_import_tools = GFPluginImportTools.new()
	_import_tools.setup(self)
	_preview_tools = GFPluginPreviewTools.new()
	_preview_tools.setup(self)

	_gltf_document_tools = GFPluginGltfDocumentTools.new()
	_gltf_document_tools.setup()
	call_deferred("_setup_dock_tools")


func _exit_tree() -> void:
	_plugin_active = false
	GFPluginAutoload.remove(self)

	if _dock_tools != null:
		_dock_tools.cleanup(self)
		_dock_tools = null
	if _debugger_tools != null:
		_debugger_tools.cleanup(self)
		_debugger_tools = null
	if _import_tools != null:
		_import_tools.cleanup(self)
		_import_tools = null
	if _preview_tools != null:
		_preview_tools.cleanup(self)
		_preview_tools = null
	if _gltf_document_tools != null:
		_gltf_document_tools.cleanup()
		_gltf_document_tools = null
	if _menu != null:
		_menu.cleanup(self)
		_menu = null
	if _actions != null:
		_actions.cleanup()
		_actions = null
	if _inspector_tools != null:
		_inspector_tools.cleanup(self)
		_inspector_tools = null


# --- 私有/辅助方法 ---

func _setup_dock_tools() -> void:
	if not _plugin_active or _dock_tools == null:
		return

	var dock_records: Array[Dictionary] = []
	dock_records.assign(_get_record_array(_standard_editor_extension_records, "dock_records"))
	_dock_tools.setup(self, dock_records)


func _setup_actions_and_menu() -> void:
	if _actions == null:
		_actions = GFPluginActions.new()
	_actions.setup(_get_record_array(_standard_editor_extension_records, "template_records"))
	_connect_action_signals()

	if _menu == null:
		_menu = GFPluginMenu.new()
	else:
		_menu.cleanup(self)
	_menu.setup(self, Callable(_actions, "handle_menu_id"), _actions.get_menu_entries())


func _connect_action_signals() -> void:
	if _actions == null:
		return

	var workspace_callable: Callable = Callable(self, "_on_workspace_requested")
	var workspace_signal: Signal = Signal(_actions, &"workspace_requested")
	if not workspace_signal.is_connected(workspace_callable):
		var _workspace_requested_connected: int = workspace_signal.connect(workspace_callable)

	var refresh_callable: Callable = Callable(self, "_on_editor_contributions_refresh_requested")
	var refresh_signal: Signal = Signal(_actions, &"editor_contributions_refresh_requested")
	if not refresh_signal.is_connected(refresh_callable):
		var _refresh_requested_connected: int = refresh_signal.connect(refresh_callable)


func _refresh_editor_contributions() -> void:
	if not _plugin_active:
		return

	_scan_editor_filesystem()
	GFExtensionSettingsBase.clear_manifest_cache()
	_standard_editor_extension_records = _collect_standard_editor_extension_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(_standard_editor_extension_records, "project_setting_records"))

	if _inspector_tools != null:
		_inspector_tools.cleanup(self)

	_setup_actions_and_menu()
	var active_editor_records: Dictionary = _make_active_editor_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(active_editor_records, "project_setting_records"))
	if _inspector_tools != null:
		_inspector_tools.setup(self, active_editor_records)

	if _debugger_tools != null:
		_debugger_tools.cleanup(self)
		_debugger_tools.setup(self, _standard_editor_extension_records)

	if _import_tools != null:
		_import_tools.cleanup(self)
		_import_tools.setup(self)

	if _gltf_document_tools != null:
		_gltf_document_tools.cleanup()
		_gltf_document_tools.setup()

	if _dock_tools != null:
		var dock_records: Array[Dictionary] = []
		dock_records.assign(_get_record_array(_standard_editor_extension_records, "dock_records"))
		_dock_tools.setup(self, dock_records)

	print("[GF Framework] 已刷新 GF 编辑器贡献记录。")


func _scan_editor_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.scan()


func _collect_standard_editor_extension_records() -> Dictionary:
	return GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_records(STANDARD_EDITOR_CONTRIBUTIONS_MANIFEST_PATH)


func _make_active_editor_records() -> Dictionary:
	var records: Dictionary = _standard_editor_extension_records.duplicate(true)
	if _actions == null:
		return records
	_append_unique_records(
		records,
		"project_setting_records",
		_actions.get_project_setting_records(),
		"name"
	)
	_append_unique_records(
		records,
		"project_setting_section_records",
		_actions.get_project_setting_section_records(),
		"path"
	)
	return records


func _append_unique_records(
	records: Dictionary,
	record_key: String,
	additional_records: Array[Dictionary],
	identity_key: String
) -> void:
	var merged_records: Array[Dictionary] = _get_record_array(records, record_key)
	var used_identities: Dictionary = {}
	for record: Dictionary in merged_records:
		var identity: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, identity_key).strip_edges()
		if not identity.is_empty():
			used_identities[identity] = true
	for record: Dictionary in additional_records:
		var identity: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, identity_key).strip_edges()
		if identity.is_empty() or used_identities.has(identity):
			continue
		used_identities[identity] = true
		merged_records.append(record.duplicate(true))
	records[record_key] = merged_records


func _get_record_array(records: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = records.get(key, [])
	if not value is Array:
		return result
	for record_variant: Variant in value:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			result.append(record.duplicate(true))
	return result


# --- 信号处理函数 ---

func _on_workspace_requested() -> void:
	if _dock_tools != null:
		_dock_tools.show_workspace()


func _on_editor_contributions_refresh_requested() -> void:
	call_deferred("_refresh_editor_contributions")
