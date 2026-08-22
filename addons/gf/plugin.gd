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
const _GF_EDITOR_CONTRIBUTION_CATALOG_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_contribution_catalog.gd"
)
const _GF_PLUGIN_REFRESH_STATE_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_refresh_state.gd")
const _BUILTIN_TOOL_CONTRIBUTIONS_CATALOG_PATH: String = (
	"res://addons/gf/gf_builtin_tool_contributions.json"
)
const _EDITOR_CONTRIBUTION_REFRESH_TIMEOUT_MSEC: int = 120_000
const _EDITOR_CONTRIBUTION_DIAGNOSTIC_KIND_LIMIT: int = 16


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
var _editor_contribution_records: Dictionary = {}
var _standard_editor_contribution_report: Dictionary = {}
var _builtin_tool_editor_contribution_report: Dictionary = {}
var _refresh_state: _GF_PLUGIN_REFRESH_STATE_SCRIPT = _GF_PLUGIN_REFRESH_STATE_SCRIPT.new()


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_plugin_active = true
	GFPluginAutoload.ensure(self)
	_reload_editor_contribution_reports()
	GFPluginProjectSettings.ensure_all(_get_record_array(_editor_contribution_records, "project_setting_records"))
	_setup_actions_and_menu()
	var active_editor_records: Dictionary = _make_active_editor_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(active_editor_records, "project_setting_records"))

	_inspector_tools = GFPluginInspectorTools.new()
	_inspector_tools.setup(self, active_editor_records)

	_dock_tools = GFPluginDockTools.new()
	_debugger_tools = GFPluginDebuggerTools.new()
	_debugger_tools.setup(
		self,
		_editor_contribution_records,
		GFExtensionSettingsBase.get_enabled_debugger_plugin_paths()
	)

	_import_tools = GFPluginImportTools.new()
	_import_tools.setup(self)
	_preview_tools = GFPluginPreviewTools.new()
	_preview_tools.setup(self)

	_gltf_document_tools = GFPluginGltfDocumentTools.new()
	_gltf_document_tools.setup()
	call_deferred("_setup_dock_tools")


func _exit_tree() -> void:
	_plugin_active = false
	_cancel_editor_contribution_refresh()
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
	_editor_contribution_records = {}
	_standard_editor_contribution_report = {}
	_builtin_tool_editor_contribution_report = {}


# --- 私有/辅助方法 ---

func _setup_dock_tools() -> void:
	if not _plugin_active or _dock_tools == null:
		return

	var dock_records: Array[Dictionary] = []
	dock_records.assign(_get_record_array(_editor_contribution_records, "dock_records"))
	_dock_tools.setup(self, dock_records)


func _setup_actions_and_menu() -> void:
	if _actions == null:
		_actions = GFPluginActions.new()
	_actions.setup(_get_record_array(_editor_contribution_records, "template_records"))
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
	if _refresh_state.request(
		_refresh_now_msec(),
		_EDITOR_CONTRIBUTION_REFRESH_TIMEOUT_MSEC
	):
		call_deferred("_begin_editor_contribution_refresh")


func _begin_editor_contribution_refresh() -> void:
	if not _plugin_active or not _refresh_state.is_pending():
		return
	_execute_editor_contribution_refresh_action(
		_refresh_state.begin(_is_editor_filesystem_scanning())
	)


func _schedule_editor_contribution_refresh_poll() -> void:
	if not _plugin_active or not _refresh_state.is_pending():
		return
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		_fail_editor_contribution_refresh("scene_tree_unavailable")
		return
	var poll_callable: Callable = Callable(self, "_poll_editor_contribution_refresh")
	var process_frame_signal: Signal = scene_tree.process_frame
	if process_frame_signal.is_connected(poll_callable):
		return
	var connect_error: Error = process_frame_signal.connect(
		poll_callable,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		_fail_editor_contribution_refresh("poll_connect_failed")


func _poll_editor_contribution_refresh() -> void:
	if not _plugin_active or not _refresh_state.is_pending():
		return
	if _refresh_state.is_expired(_refresh_now_msec()):
		_fail_editor_contribution_refresh("scan_timeout")
		return
	if _is_editor_filesystem_scanning():
		_schedule_editor_contribution_refresh_poll()
		return
	_execute_editor_contribution_refresh_action(_refresh_state.after_scan_idle())


func _execute_editor_contribution_refresh_action(action: Dictionary) -> void:
	var kind: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(action, "kind")
	if kind == _GF_PLUGIN_REFRESH_STATE_SCRIPT.ACTION_WAIT:
		_schedule_editor_contribution_refresh_poll()
		return
	if kind == _GF_PLUGIN_REFRESH_STATE_SCRIPT.ACTION_SCAN:
		if not _scan_editor_filesystem():
			_fail_editor_contribution_refresh("filesystem_unavailable")
			return
		_schedule_editor_contribution_refresh_poll()
		return
	if kind == _GF_PLUGIN_REFRESH_STATE_SCRIPT.ACTION_APPLY:
		var generation: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(action, "generation", 0)
		_apply_editor_contributions_refresh(generation)
		if not _plugin_active:
			_cancel_editor_contribution_refresh()
			return
		_execute_editor_contribution_refresh_action(
			_refresh_state.after_applied(generation)
		)
		return
	if kind == _GF_PLUGIN_REFRESH_STATE_SCRIPT.ACTION_DONE:
		return
	_fail_editor_contribution_refresh("invalid_state_action")


func _apply_editor_contributions_refresh(generation: int) -> void:
	if not _plugin_active:
		return
	GFExtensionSettingsBase.clear_manifest_cache()
	_reload_editor_contribution_reports()
	GFPluginProjectSettings.ensure_all(_get_record_array(_editor_contribution_records, "project_setting_records"))

	if _inspector_tools != null:
		_inspector_tools.cleanup(self)

	_setup_actions_and_menu()
	var active_editor_records: Dictionary = _make_active_editor_records()
	GFPluginProjectSettings.ensure_all(_get_record_array(active_editor_records, "project_setting_records"))
	if _inspector_tools != null:
		_inspector_tools.setup(self, active_editor_records)

	if _debugger_tools != null:
		_debugger_tools.cleanup(self)
		_debugger_tools.setup(
			self,
			_editor_contribution_records,
			GFExtensionSettingsBase.get_enabled_debugger_plugin_paths()
		)

	if _import_tools != null:
		_import_tools.cleanup(self)
		_import_tools.setup(self)

	if _gltf_document_tools != null:
		_gltf_document_tools.cleanup()
		_gltf_document_tools.setup()

	if _dock_tools != null:
		var dock_records: Array[Dictionary] = []
		dock_records.assign(_get_record_array(_editor_contribution_records, "dock_records"))
		_dock_tools.setup(self, dock_records)

	print("[GF Framework] 已刷新 GF 编辑器贡献记录（generation=%d）。" % generation)


func _scan_editor_filesystem() -> bool:
	if not Engine.is_editor_hint():
		return false
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return false
	filesystem.scan()
	return true


func _is_editor_filesystem_scanning() -> bool:
	if not Engine.is_editor_hint():
		return false
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	return filesystem != null and filesystem.is_scanning()


func _refresh_now_msec() -> int:
	return Time.get_ticks_msec()


func _fail_editor_contribution_refresh(kind: String) -> void:
	_report_editor_contribution_refresh_issue(
		kind,
		_refresh_state.get_requested_generation()
	)
	_cancel_editor_contribution_refresh()


func _report_editor_contribution_refresh_issue(kind: String, generation: int) -> void:
	push_warning(
		"[GF Framework][PLUGIN-BOOT-002] 编辑器贡献刷新未应用：kind=%s generation=%d。"
		% [kind, generation]
	)


func _cancel_editor_contribution_refresh() -> void:
	var scene_tree: SceneTree = get_tree()
	var poll_callable: Callable = Callable(self, "_poll_editor_contribution_refresh")
	if scene_tree != null and scene_tree.process_frame.is_connected(poll_callable):
		scene_tree.process_frame.disconnect(poll_callable)
	_refresh_state.cancel()


func _reload_editor_contribution_reports() -> void:
	_standard_editor_contribution_report = _collect_standard_editor_contribution_report()
	var standard_records: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		_standard_editor_contribution_report,
		"records",
		GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records()
	)
	_builtin_tool_editor_contribution_report = _collect_builtin_tool_editor_contribution_report(
		standard_records
	)
	_editor_contribution_records = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		_builtin_tool_editor_contribution_report,
		"records",
		standard_records
	)
	_publish_standard_editor_contribution_diagnostic(_standard_editor_contribution_report)
	_publish_builtin_tool_editor_contribution_diagnostic(
		_builtin_tool_editor_contribution_report
	)


func _collect_standard_editor_contribution_report(
	manifest_path: String = STANDARD_EDITOR_CONTRIBUTIONS_MANIFEST_PATH
) -> Dictionary:
	return GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_report(manifest_path)


func _collect_builtin_tool_editor_contribution_report(
	base_records: Dictionary,
	catalog_path: String = _BUILTIN_TOOL_CONTRIBUTIONS_CATALOG_PATH
) -> Dictionary:
	return _GF_EDITOR_CONTRIBUTION_CATALOG_SCRIPT.load_catalog_report(
		catalog_path,
		base_records
	)


func _publish_standard_editor_contribution_diagnostic(report: Dictionary) -> void:
	var state: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "state")
	if state == "absent" or state == "valid":
		return
	var issue_kinds: Array[String] = []
	_append_report_issue_kinds(
		issue_kinds,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "issues")
	)
	_append_report_issue_kinds(
		issue_kinds,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "skipped_records")
	)
	issue_kinds.sort()
	var kinds_truncated: bool = issue_kinds.size() > _EDITOR_CONTRIBUTION_DIAGNOSTIC_KIND_LIMIT
	if kinds_truncated:
		var _resize_error: Error = issue_kinds.resize(
			_EDITOR_CONTRIBUTION_DIAGNOSTIC_KIND_LIMIT
		) as Error
	var kinds_text: String = ",".join(PackedStringArray(issue_kinds))
	if kinds_text.is_empty():
		kinds_text = "unknown"
	if kinds_truncated:
		kinds_text += ",..."
	push_warning(
		(
			"[GF Framework][PLUGIN-BOOT-001] standard editor contribution manifest "
			+ "state=%s issue_count=%d skipped_record_count=%d issue_kinds=%s。"
		)
		% [
			state if not state.is_empty() else "invalid",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "issue_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "skipped_record_count", 0),
			kinds_text,
		]
	)


func _publish_builtin_tool_editor_contribution_diagnostic(report: Dictionary) -> void:
	var state: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "state")
	if state == "valid":
		return
	var issue_kinds: Array[String] = []
	_append_report_issue_kinds(
		issue_kinds,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "issues")
	)
	for manifest_report_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		report,
		"manifest_reports"
	):
		if not manifest_report_value is Dictionary:
			continue
		var manifest_report: Dictionary = manifest_report_value
		_append_report_issue_kinds(
			issue_kinds,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(manifest_report, "issues")
		)
		_append_report_issue_kinds(
			issue_kinds,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(manifest_report, "skipped_records")
		)
	if state == "absent" and not issue_kinds.has("catalog_absent"):
		issue_kinds.append("catalog_absent")
	issue_kinds.sort()
	var kinds_truncated: bool = issue_kinds.size() > _EDITOR_CONTRIBUTION_DIAGNOSTIC_KIND_LIMIT
	if kinds_truncated:
		var _resize_error: Error = issue_kinds.resize(
			_EDITOR_CONTRIBUTION_DIAGNOSTIC_KIND_LIMIT
		) as Error
	var kinds_text: String = ",".join(PackedStringArray(issue_kinds))
	if kinds_text.is_empty():
		kinds_text = "unknown"
	if kinds_truncated:
		kinds_text += ",..."
	push_warning(
		(
			"[GF Framework][PLUGIN-BOOT-003] built-in tool contribution catalog "
			+ "state=%s issue_count=%d loaded_manifest_count=%d "
			+ "absent_manifest_count=%d skipped_manifest_count=%d issue_kinds=%s。"
		)
		% [
			state if not state.is_empty() else "invalid",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "issue_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "loaded_manifest_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "absent_manifest_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "skipped_manifest_count", 0),
			kinds_text,
		]
	)


func _append_report_issue_kinds(target: Array[String], values: Array) -> void:
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var issue: Dictionary = value
		var kind: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind").strip_edges()
		if not kind.is_empty() and not target.has(kind):
			target.append(kind)


func _make_active_editor_records() -> Dictionary:
	var records: Dictionary = _editor_contribution_records.duplicate(true)
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
	_refresh_editor_contributions()
