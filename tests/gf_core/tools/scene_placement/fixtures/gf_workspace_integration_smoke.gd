@tool

# 隔离编辑器中的真实 Workspace 集成；由现有原生烟测在资源用例后等待执行。
extends RefCounted


# --- 常量 ---

const _DOCK_TOOLS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const _REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_catalog.gd")
const _SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _PREFERENCES_SCRIPT = preload("res://addons/gf/kernel/editor/state/gf_editor_preferences.gd")
const _CONFIG_SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")
const _HOME: String = "res://addons/gf/kernel/editor/workspace/gf_workspace_home.gd"
const _ASSETS: String = "res://addons/gf/tools/asset_browser/editor/gf_asset_browser_dock.gd"
const _PLACEMENT: String = "res://addons/gf/tools/scene_placement/editor/gf_scene_placement_launcher.gd"
const _TWEEN: String = "res://addons/gf/extensions/action_queue/editor/gf_tween_authoring_dock.gd"
const _CONFIG: String = "res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_dock.gd"
const _BOOTSTRAP: String = "res://addons/gf/tools/project_bootstrap/editor/gf_project_bootstrap_dock.gd"
const _ACTION: String = "gf.tool.scene_placement:scene_placement.action.select_scene"


# --- 私有变量 ---

var _tools: _DOCK_TOOLS_SCRIPT = null
var _records: Dictionary = {}
var _report: Dictionary = {"ok": true, "assertions": 0}
var _config_draft_session: _CONFIG_SESSION_SCRIPT = null


# --- 框架内部方法 ---

func run(plugin: EditorPlugin, placement: GFScenePlacementPlugin, scene_path: String, material_path: String) -> Dictionary:
	var old_mode: Variant = ProjectSettings.get_setting(_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING, null)
	var old_enabled: Variant = ProjectSettings.get_setting(_SETTINGS_SCRIPT.ENABLED_EXTENSIONS_SETTING, null)
	_SETTINGS_SCRIPT.set_enabled_extension_ids(["gf.action_queue"])
	_SETTINGS_SCRIPT.clear_manifest_cache()
	_PREFERENCES_SCRIPT.set_value("startup_mode", "manual")
	_PREFERENCES_SCRIPT.set_value("selected_page", "gf.kernel.home")
	await _run_cases(plugin, placement, scene_path, material_path)
	if GFVariantData.get_option_bool(_report, "ok"):
		await _verify_root_plugin_refresh(plugin, scene_path, material_path)
	if _tools != null:
		_tools.cleanup(plugin)
	_tools = null
	ProjectSettings.set_setting(_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING, old_mode)
	ProjectSettings.set_setting(_SETTINGS_SCRIPT.ENABLED_EXTENSIONS_SETTING, old_enabled)
	_SETTINGS_SCRIPT.clear_manifest_cache()
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	return _report.duplicate(true)


# --- 私有/辅助方法 ---

func _run_cases(plugin: EditorPlugin, placement: GFScenePlacementPlugin, scene_path: String, material_path: String) -> void:
	var standard: Dictionary = _REGISTRY_SCRIPT.load_manifest_report("res://addons/gf/standard/editor/gf_editor_contributions.json")
	var catalog: Dictionary = _CATALOG_SCRIPT.load_catalog_report("res://addons/gf/gf_builtin_tool_contributions.json", GFVariantData.get_option_dictionary(standard, "records"))
	if not _check(GFVariantData.get_option_string(standard, "state") == "valid" and GFVariantData.get_option_string(catalog, "state") == "valid", "Workspace contribution sources did not load as valid pure data."):
		return
	_records = GFVariantData.get_option_dictionary(catalog, "records")
	_tools = _DOCK_TOOLS_SCRIPT.new()
	_setup(plugin)
	var context: GFEditorToolContext = _context()
	if not _check(context != null and context.undo_manager == plugin.get_undo_redo(), "Workspace did not retain the real editor Undo manager."):
		return
	var tasks: Array[Dictionary] = context.get_workspace_tasks()
	var actions: Array[Dictionary] = context.get_resource_actions(PackedStringArray([scene_path]))
	if not _check(not tasks.is_empty() and not actions.is_empty() and _tools.get_workspace_window() == null, "Querying tasks/actions constructed a Workspace or tool page."):
		return
	_report["workspace_task_discovery_lazy"] = true
	_tools.show_workspace()
	var window: Window = _tools.get_workspace_window()
	var workspace: Control = _workspace(window)
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	var home: Control = _find_page(workspace, _HOME)
	if not _check(home != null and _find_page(workspace, _ASSETS) == null and _find_page(workspace, _PLACEMENT) == null and _find_page(workspace, _TWEEN) == null and _find_page(workspace, _CONFIG) == null and _find_page(workspace, _BOOTSTRAP) == null, "Showing Home eagerly instantiated an unrelated tool page."):
		return
	var search: Node = home.find_child("TaskSearch", true, false)
	if not _check(search is LineEdit and home.get_window() == window and home.is_visible_in_tree() and home.size.x > 200.0 and home.get_theme_default_font() != null, "The actual Workspace Home GUI/theme is not usable in its native Window."):
		return
	if not await _capture(window, "workspace_home.png"):
		return
	var asset_task: Dictionary = _find_task(tasks, _ASSETS)
	if not _check(not asset_task.is_empty() and _press_task(home, asset_task), "The native Home task button did not expose the asset workbench."):
		return
	var asset_page: Control = _find_page(workspace, _ASSETS)
	if not _check(asset_page != null, "The Home task did not create the registered asset page."):
		return
	if not await _wait_fresh(plugin, asset_page):
		return
	var grid_node: Node = asset_page.find_child("AssetGrid", true, false)
	var menu_node: Node = asset_page.find_child("ResourceActions", true, false)
	if not _check(grid_node is ItemList and menu_node is MenuButton, "The actual asset page does not expose its native grid and resource menu."):
		return
	var grid: ItemList = grid_node
	var menu: MenuButton = menu_node
	if not await _verify_query_lifecycle(plugin, window, workspace, asset_page, grid, menu, scene_path):
		return
	if not _check(_select_path(grid, material_path), "The Workspace index omitted the source material."):
		return
	menu.show_popup()
	var popup: PopupMenu = menu.get_popup()
	var index: int = _action_index(popup)
	if not _check(index >= 0 and popup.is_item_disabled(index) and not popup.get_item_tooltip(index).is_empty(), "A non-PackedScene selection did not disable placement with a reason."):
		return
	popup.hide()
	if not _check(_select_path(grid, scene_path), "The Workspace index omitted the placement scene."):
		return
	if not await _capture(window, "workspace_assets.png"):
		return
	var manager: EditorUndoRedoManager = plugin.get_undo_redo()
	var edited_scene: Node = EditorInterface.get_edited_scene_root()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(edited_scene))
	var global_history: UndoRedo = manager.get_history_undo_redo(0)
	var scene_version: int = history.get_version()
	var global_version: int = global_history.get_version()
	var child_count: int = edited_scene.get_child_count()
	menu.show_popup()
	index = _action_index(popup)
	if not _check(index >= 0 and not popup.is_item_disabled(index), "The native resource menu did not enable the selected PackedScene action."):
		return
	var retired_menu_id: int = popup.get_item_id(index)
	popup.hide()
	if not _check(_select_path(grid, material_path), "Cannot change the selection for the queued-menu regression."):
		return
	popup.id_pressed.emit(retired_menu_id)
	if not _check(_find_page(workspace, _PLACEMENT) == null and history.get_version() == scene_version, "A queued old menu ID routed a replacement selection."):
		return
	if not _check(_select_path(grid, scene_path), "Cannot restore the scene selection for native routing."):
		return
	menu.show_popup()
	index = _action_index(popup)
	if not _check(index >= 0 and popup.get_item_id(index) != retired_menu_id, "A refreshed resource menu reused a retired item ID."):
		return
	var action_menu_id: int = popup.get_item_id(index)
	popup.hide()
	popup.id_pressed.emit(action_menu_id)
	await plugin.get_tree().process_frame
	if not _check(_find_page(workspace, _PLACEMENT) != null and placement.get_panel().get_source_scene().resource_path == scene_path and not GFVariantData.get_option_bool(placement.get_snapshot(), "active"), "Native resource-menu routing did not select the source without starting placement."):
		return
	if not _check(history.get_version() == scene_version and global_history.get_version() == global_version and edited_scene.get_child_count() == child_count, "Workspace navigation or source handoff wrote Undo or instantiated a scene."):
		return
	_report["workspace_resource_action_handoff"] = true
	_report["workspace_native_ui"] = true
	var selected_id: String = str(workspace.call("get_selected_page_id"))
	window.call("hide_workspace")
	_tools.show_workspace()
	if not _check(_tools.get_workspace_window() == window and str(workspace.call("get_selected_page_id")) == selected_id, "Hiding/reopening Workspace changed its stable selected page."):
		return
	var old_asset: WeakRef = weakref(asset_page)
	_setup(plugin)
	if not _check(context.get_workspace_tasks().is_empty() and not GFVariantData.get_option_bool(context.request_resource_action(_ACTION, PackedStringArray([scene_path])), "ok"), "A replaced context retained routing authority."):
		return
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	if not _check(old_asset.get_ref() == null and str(workspace.call("get_selected_page_id")) == selected_id, "Contribution refresh retained an old asset page or lost its stable page ID."):
		return
	context = _context()
	if not _check_onboarding_tasks(context, workspace):
		return
	var tween_task: Dictionary = _find_task(context.get_workspace_tasks(), _TWEEN, "new_resource")
	if not _check(not tween_task.is_empty(), "The enabled Tween extension did not publish its new-resource task."):
		return
	var root_files: PackedStringArray = DirAccess.get_files_at("res://")
	var task_report: Dictionary = context.request_workspace_task(str(tween_task.get("source_id")))
	var dialog_node: Node = EditorInterface.get_base_control().find_child("GFTweenCreateDialog", true, false)
	if not _check(GFVariantData.get_option_bool(task_report, "ok") and dialog_node is EditorFileDialog and DirAccess.get_files_at("res://") == root_files, "The Tween task did not open only a native creation dialog."):
		return
	var dialog: EditorFileDialog = dialog_node
	if not _check(dialog.visible, "Tween creation dialog is not visible."):
		return
	var dialog_ref: WeakRef = weakref(dialog)
	dialog.hide()
	_report["workspace_tween_task_dialog"] = true
	var window_ref: WeakRef = weakref(window)
	var workspace_ref: WeakRef = weakref(workspace)
	_tools.cleanup(plugin)
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	if not _check(window_ref.get_ref() == null and workspace_ref.get_ref() == null and dialog_ref.get_ref() == null and context.get_workspace_tasks().is_empty(), "Workspace cleanup left windows/pages/dialogs or a live routing context."):
		return
	_report["workspace_context_and_window_lifecycle"] = true


func _check_onboarding_tasks(context: GFEditorToolContext, workspace: Control) -> bool:
	var tasks: Array[Dictionary] = context.get_workspace_tasks()
	var config_task: Dictionary = _find_task(tasks, _CONFIG)
	var bootstrap_task: Dictionary = _find_task(tasks, _BOOTSTRAP, "new_project")
	if not _check(not config_task.is_empty() and not bootstrap_task.is_empty(), "Configuration and minimal-project tasks must be contributed by their own tools."):
		return false
	var root_files: PackedStringArray = DirAccess.get_files_at("res://")
	var settings_digest: String = FileAccess.get_sha256("res://project.godot")
	var config_report: Dictionary = context.request_workspace_task(str(config_task.get("source_id")))
	var config_page: Control = _find_page(workspace, _CONFIG)
	if not _check(GFVariantData.get_option_bool(config_report, "ok") and config_page != null and config_page.is_visible_in_tree() and config_page.find_child("NewProfile", true, false) is Button, "The configuration task did not open the real workbench with its first-use action."):
		return false
	var bootstrap_report: Dictionary = context.request_workspace_task(str(bootstrap_task.get("source_id")))
	var bootstrap_page: Control = _find_page(workspace, _BOOTSTRAP)
	if not _check(GFVariantData.get_option_bool(bootstrap_report, "ok") and bootstrap_page != null and bootstrap_page.is_visible_in_tree() and bootstrap_page.find_child("OutputDirectory", true, false) is LineEdit, "The minimal-project task did not open the real wizard."):
		return false
	if not _check(DirAccess.get_files_at("res://") == root_files and FileAccess.get_sha256("res://project.godot") == settings_digest and not DirAccess.dir_exists_absolute("res://game/bootstrap") and not DirAccess.dir_exists_absolute("res://config"), "Opening onboarding tasks created default project files or saved project settings."):
		return false
	_report["workspace_onboarding_tasks"] = true
	return true


func _verify_root_plugin_refresh(plugin: EditorPlugin, scene_path: String, material_path: String) -> void:
	_tools = null
	EditorInterface.set_plugin_enabled("gf", true)
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	var root_plugin: EditorPlugin = null
	for node: Node in plugin.get_tree().root.find_children("*", "EditorPlugin", true, false):
		var script: Script = node.get_script()
		if script != null and script.resource_path == "res://addons/gf/plugin.gd" and node is EditorPlugin:
			root_plugin = node
	if _check(root_plugin != null, "The real GF root EditorPlugin was not enabled."):
		await _run_root_refresh_case(plugin, root_plugin, scene_path, material_path)
	if _config_draft_session != null:
		_config_draft_session.clear_profile()
		_config_draft_session = null
	EditorInterface.set_plugin_enabled("gf", false)
	_tools = null
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame


func _run_root_refresh_case(plugin: EditorPlugin, root_plugin: EditorPlugin, scene_path: String, material_path: String) -> void:
	var tools_value: Variant = root_plugin.get("_dock_tools")
	if not _check(tools_value is _DOCK_TOOLS_SCRIPT, "The real root plugin did not initialize its Workspace host."):
		return
	_tools = tools_value
	var config_page: Control = _tools.open_workspace_page(_CONFIG)
	var config_session_value: Variant = config_page.get("_session") if config_page != null else null
	if not _check(config_session_value is _CONFIG_SESSION_SCRIPT, "The real root did not expose the configuration workbench session."):
		return
	_config_draft_session = config_session_value
	_config_draft_session.create_profile("res://tests/gf_core/tools/config_pipeline/fixtures/items.csv", "review_dirty_config", "res://generated/config")
	var config_profile: GFConfigPipelineProfile = _config_draft_session.get_profile()
	config_profile.version = "review-draft"
	_config_draft_session.mark_changed()
	var config_reference: WeakRef = weakref(config_page)
	var page: Control = _tools.open_workspace_page(_ASSETS)
	if not _check(page != null, "The real root plugin could not open Asset Browser.") or not await _wait_fresh(plugin, page):
		return
	var grid: ItemList = page.find_child("AssetGrid", true, false)
	if not _check(_select_path(grid, material_path), "The real root index omitted the source resource."):
		return
	var _opened: Variant = page.call("_open_tables")
	var table: GFResourceTableEditor = null
	for child: Node in page.find_children("*", "", true, false):
		if child is GFResourceTableEditor:
			table = child
	if not _check(table != null and table.get_resources().size() == 1, "The real root page did not create a source table."):
		return
	var resource: Resource = table.get_resources()[0]
	var original: float = GFVariantData.to_float(resource.get("roughness"))
	var edited: float = 0.75 if not is_equal_approx(original, 0.75) else 0.25
	var before_disk: String = FileAccess.get_sha256(material_path)
	var changed: Dictionary = _edit_roughness(table, edited)
	if not _check(GFVariantData.get_option_bool(changed, "ok") and FileAccess.get_sha256(material_path) == before_disk, "The dirty-table edit must not save implicitly: %s / disk_equal=%s" % [JSON.stringify(changed), FileAccess.get_sha256(material_path) == before_disk]):
		return
	var old_page: WeakRef = weakref(page)
	var old_context: GFEditorToolContext = _context()
	var _requested: Variant = root_plugin.call("_on_editor_contributions_refresh_requested")
	var deadline: int = Time.get_ticks_msec() + 15000
	while _context() == old_context and Time.get_ticks_msec() < deadline:
		await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	if not _check(_context() != old_context and old_context.get_workspace_tasks().is_empty(), "The real root contribution refresh did not revoke its old context."):
		return
	page = _tools.open_workspace_page(_ASSETS)
	var source_draft_retained: bool = old_page.get_ref() != null and page == old_page.get_ref() and is_instance_valid(table)
	if not _check(source_draft_retained, "The real root contribution refresh discarded an unsaved source table."):
		return
	var config_draft_retained: bool = config_reference.get_ref() != null and config_reference.get_ref() == _find_page(_workspace(_tools.get_workspace_window()), _CONFIG) and _config_draft_session.get_profile() == config_profile and config_profile.version == "review-draft"
	if not _check(config_draft_retained, "Real contribution refresh discarded the unsaved Config profile or its instance."):
		return
	if not await _wait_fresh(plugin, page):
		return
	if not _check(FileAccess.get_sha256(material_path) == before_disk, "Retaining a dirty page must not save implicitly."):
		return
	var tables_value: Variant = page.get("_tables")
	if not _check(tables_value is Control, "The retained page lost its table owner."):
		return
	var tables: Control = tables_value
	var baseline_still_dirty: bool = tables.call("has_unsaved_changes") == true
	if not _check(baseline_still_dirty, "Refresh replaced the dirty fingerprint with a new saved baseline."):
		return
	var workspace: Control = _workspace(_tools.get_workspace_window())
	var remaining: Array[Dictionary] = []
	var records_value: Variant = workspace.get("_dock_records")
	if records_value is Array:
		var current_records: Array = records_value
		for value: Variant in current_records:
			if value is Dictionary:
				var record: Dictionary = value
				if record.get("path") != _ASSETS:
					remaining.append(record)
	# 注入撤销后的贡献快照，随后由真正根插件刷新恢复正式贡献。
	var _revoked: Variant = workspace.call("setup", remaining, _context())
	var _context_reset: Variant = workspace.call("set_editor_context", _context())
	var notice: Label = workspace.find_child("WorkspaceDraftNotice", true, false)
	var revoked_draft_readonly: bool = page.is_inside_tree() and page.get("_context") == null and _tools.open_workspace_page(_ASSETS) == null and notice != null and notice.visible and tables.call("has_unsaved_changes") == true
	if not _check(revoked_draft_readonly, "The revoked contribution did not retain a visible read-only draft with routing denied."):
		return
	var _rejected_save: Variant = tables.call("_save_resources")
	var revoked_actions_denied: bool = FileAccess.get_sha256(material_path) == before_disk and page.call("get_selected_resource_paths") == PackedStringArray()
	if not _check(revoked_actions_denied, "A revoked draft saved or exposed actionable resources."):
		return
	if not await _capture(_tools.get_workspace_window(), "workspace_draft_readonly.png"):
		return
	old_context = _context()
	var _restore_requested: Variant = root_plugin.call("_on_editor_contributions_refresh_requested")
	deadline = Time.get_ticks_msec() + 15000
	while _context() == old_context and Time.get_ticks_msec() < deadline:
		await plugin.get_tree().process_frame
	page = _tools.open_workspace_page(_ASSETS)
	var source_draft_restored: bool = page == old_page.get_ref() and page.get("_context") == _context() and not notice.visible
	if not _check(source_draft_restored, "Restoring the exact contribution did not rebind the original draft.") or not await _wait_fresh(plugin, page):
		return
	var _saved: Variant = tables.call("_save_resources")
	var disk: Resource = ResourceLoader.load(material_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var pending_edit_saved: bool = disk != null and is_equal_approx(GFVariantData.to_float(disk.get("roughness")), edited) and tables.call("has_unsaved_changes") == false
	if not _check(pending_edit_saved, "Explicit save after contribution refresh skipped the pending resource edit."):
		return
	var manager: EditorUndoRedoManager = root_plugin.get_undo_redo()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(resource))
	var undone: bool = history.undo()
	disk = ResourceLoader.load(material_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var undo_kept_disk_separate: bool = undone and is_equal_approx(GFVariantData.to_float(resource.get("roughness")), original) and tables.call("has_unsaved_changes") == true and is_equal_approx(GFVariantData.to_float(disk.get("roughness")), edited)
	if not _check(undo_kept_disk_separate, "Native Undo after retained-table save did not preserve separate memory/disk state."):
		return
	var _redone: bool = history.redo()
	if not _check_onboarding_tasks(_context(), workspace):
		return
	page = _tools.open_workspace_page(_ASSETS)
	if not await _wait_fresh(plugin, page) or not _check(_select_path(grid, scene_path), "The refreshed asset source omitted the PackedScene."):
		return
	var menu: MenuButton = page.find_child("ResourceActions", true, false)
	menu.show_popup()
	var popup: PopupMenu = menu.get_popup()
	var action_index: int = _action_index(popup)
	if not _check(action_index >= 0 and not popup.is_item_disabled(action_index), "Real root refresh lost the native asset resource menu action."):
		return
	var action_menu_id: int = popup.get_item_id(action_index)
	popup.hide()
	popup.id_pressed.emit(action_menu_id)
	if not _check(_find_page(workspace, _PLACEMENT) != null, "The native asset menu did not hand off after real root refresh."):
		return
	var routed: Dictionary = _context().request_resource_action(_ACTION, PackedStringArray([scene_path]))
	if not _check(GFVariantData.get_option_bool(routed, "ok") and GFVariantData.get_option_string(routed, "status") == "source_selected", "Real root refresh lost the resource action or its receiver status."):
		return
	var message: String = GFVariantData.get_option_string(routed, "message")
	if not _check(not message.is_empty() and message != GFVariantData.get_option_string(routed, "status"), "The actual source-selection receiver must provide readable UI feedback, not its status code."):
		return
	_report["workspace_root_refresh_preserves_resource_draft"] = true
	_report["workspace_root_refresh_preserves_config_draft"] = true
	_report["workspace_revoked_draft_readonly_and_restored"] = true
	_report["workspace_root_refresh_preserves_tasks_and_actions"] = true


func _edit_roughness(table: GFResourceTableEditor, value: float) -> Dictionary:
	var tree: Tree = table.find_child("ResourceTree", true, false)
	var picker: OptionButton = table.find_child("MultiPropertyPicker", true, false)
	if tree == null or picker == null:
		return {"ok": false, "status": "missing_table_controls"}
	var row: TreeItem = tree.get_root().get_first_child()
	row.select(0)
	tree.multi_selected.emit(row, 0, true)
	for index: int in range(picker.item_count):
		if picker.get_item_text(index) == "roughness":
			picker.select(index)
			picker.item_selected.emit(index)
	var component: Node = table.find_child("Component_value", true, false)
	if component != null:
		for child: Node in component.get_children():
			if child is SpinBox:
				var spin: SpinBox = child
				spin.value = value
				return table.apply_selected_property()
	return {"ok": false, "status": "missing_roughness_component"}


func _setup(plugin: EditorPlugin) -> void:
	_tools.setup(plugin, _record_array("dock_records"), _record_array("task_records"), _record_array("resource_action_records"))


func _record_array(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(_records, key):
		if value is Dictionary:
			result.append(value)
	return result


func _context() -> GFEditorToolContext:
	var value: Variant = _tools.get("_editor_context")
	return value if value is GFEditorToolContext else null


func _workspace(window: Window) -> Control:
	var value: Variant = window.call("get_workspace")
	return value if value is Control else null


func _find_page(workspace: Control, path: String) -> Control:
	for node: Node in workspace.find_children("*", "Control", true, false):
		var script: Script = node.get_script()
		if script != null and script.resource_path == path and node is Control:
			return node
	return null


func _find_task(tasks: Array[Dictionary], path: String, action: String = "") -> Dictionary:
	for task: Dictionary in tasks:
		if task.get("page_path") == path and str(task.get("action_id", "")) == action:
			return task
	return {}


func _press_task(home: Control, task: Dictionary) -> bool:
	var title: String = str(task.get("title", ""))
	for node: Node in home.find_children("*", "Button", true, false):
		if node is Button:
			var button: Button = node
			if button.text.ends_with(" · " + title):
				button.pressed.emit()
				return true
	return false


func _select_path(grid: ItemList, path: String) -> bool:
	grid.deselect_all()
	for index: int in range(grid.item_count):
		if grid.get_item_metadata(index) == path:
			grid.select(index)
			grid.multi_selected.emit(index, true)
			return true
	return false


func _action_index(popup: PopupMenu) -> int:
	for index: int in range(popup.item_count):
		if popup.get_item_metadata(index) == _ACTION:
			return index
	return -1


func _verify_query_lifecycle(plugin: EditorPlugin, window: Window, workspace: Control, page: Control, grid: ItemList, menu: MenuButton, scene_path: String) -> bool:
	var search_node: Node = page.find_child("AssetSearch", true, false)
	if not _check(search_node is LineEdit and _select_path(grid, scene_path), "Query lifecycle requires a real search field and old scene selection."):
		return false
	var search: LineEdit = search_node
	menu.show_popup()
	var popup: PopupMenu = menu.get_popup()
	var action_index: int = _action_index(popup)
	if not _check(action_index >= 0, "Query lifecycle requires an old open action menu."):
		return false
	var old_action_id: int = popup.get_item_id(action_index)
	search.text = "unmatchablequartz"
	search.text_changed.emit(search.text)
	var pending: Dictionary = GFVariantData.as_dictionary(page.call("get_snapshot"))
	popup.id_pressed.emit(old_action_id)
	var _old_open: Variant = page.call("_open_selected")
	var drag: Variant = grid.call("_get_drag_data", Vector2.ZERO)
	if not _check(GFVariantData.get_option_bool(pending, "query_pending") and not popup.visible and menu.disabled and GFVariantData.get_option_packed_string_array(pending, "selected_paths").is_empty() and drag == null and _find_page(workspace, _PLACEMENT) == null, "Pending input permitted a retired menu/button/drag resource action."):
		return false
	window.hide()
	await plugin.get_tree().process_frame
	await plugin.get_tree().process_frame
	var hidden: Dictionary = GFVariantData.as_dictionary(page.call("get_snapshot"))
	if not _check(not window.visible and not GFVariantData.get_option_bool(hidden, "query_pending") and not GFVariantData.get_option_bool(hidden, "page_ready") and GFVariantData.get_option_bool(hidden, "stale"), "Hiding the actual Workspace Window did not cancel its resource query."):
		return false
	_tools.show_workspace()
	if not await _wait_fresh(plugin, page):
		return false
	if not _check(grid.item_count == 0 and menu.disabled and GFVariantData.get_option_packed_string_array(GFVariantData.as_dictionary(page.call("get_snapshot")), "selected_paths").is_empty(), "A no-match query restored old results or resource actions."):
		return false
	search.text = "outdated"
	search.text_changed.emit(search.text)
	search.text = ""
	search.text_changed.emit(search.text)
	if not await _wait_fresh(plugin, page):
		return false
	if not _check(_select_path(grid, scene_path) and not menu.disabled, "Replacing pending input did not restore the latest complete page."):
		return false
	if not await _verify_worker_generation_retirement(plugin, page, search):
		return false
	_report["workspace_query_cancellation_and_window_hide"] = true
	return true


func _verify_worker_generation_retirement(plugin: EditorPlugin, page: Control, search: LineEdit) -> bool:
	var model_value: Variant = page.get("_model")
	if not _check(model_value is GFAssetBrowserModel, "Worker regression requires the real asset page model."):
		return false
	var model: GFAssetBrowserModel = model_value
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	for index: int in range(2048):
		catalog.entries.append(GFAssetCatalogEntry.new().configure(StringName("worker_%04d" % index), "", {"title": "Hero %02d" % [index % 7]}))
	var replacement: Dictionary = model.replace_catalog(catalog)
	if not _check(GFVariantData.get_option_bool(replacement, "ok"), "Worker regression catalog was rejected."):
		return false
	search.text = "hero"
	search.text_changed.emit(search.text)
	var deadline: int = Time.get_ticks_msec() + 15000
	var snapshot: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		snapshot = GFVariantData.as_dictionary(page.call("get_snapshot"))
		if GFVariantData.get_option_string(GFVariantData.get_option_dictionary(snapshot, "query_progress"), "worker_phase") == "score":
			break
		await plugin.get_tree().process_frame
	if not _check(GFVariantData.get_option_int(snapshot, "worker_count") == 1, "Worker regression did not enter active scoring."):
		return false
	var _changed: Dictionary = model.set_query("revoked_generation")
	var _processed: Variant = page.call("_process", 0.016)
	snapshot = GFVariantData.as_dictionary(page.call("get_snapshot"))
	if not _check(not GFVariantData.get_option_bool(snapshot, "query_pending") and GFVariantData.get_option_int(snapshot, "worker_count") == 1, "Model generation revocation lost the owned worker before retirement."):
		return false
	while GFVariantData.get_option_int(GFVariantData.as_dictionary(page.call("get_snapshot")), "worker_count") != 0 and Time.get_ticks_msec() < deadline:
		await plugin.get_tree().process_frame
	if not _check(GFVariantData.get_option_int(GFVariantData.as_dictionary(page.call("get_snapshot")), "worker_count") == 0, "Retired worker was not joined by the native page."):
		return false
	search.text = ""
	search.text_changed.emit(search.text)
	var _refreshed: Variant = page.call("_refresh")
	_report["workspace_worker_generation_retired"] = true
	return await _wait_fresh(plugin, page)


func _wait_fresh(plugin: EditorPlugin, page: Control) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var value: Variant = page.call("get_snapshot")
		if value is Dictionary:
			var snapshot: Dictionary = value
			if snapshot.get("stale") == false and snapshot.get("query_pending") == false and snapshot.get("page_ready") == true:
				return true
		await plugin.get_tree().process_frame
	return _check(false, "Workspace asset index did not become fresh within its deadline.")


func _capture(window: Window, filename: String) -> bool:
	var directory: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR")
	if directory.is_empty():
		return true
	await window.get_tree().process_frame
	await window.get_tree().process_frame
	var frame: Image = window.get_texture().get_image()
	if not _check(frame != null and not frame.is_empty(), "The actual Workspace Window did not render an image."):
		return false
	var path: String = directory.path_join(filename)
	if not _check(frame.save_png(path) == OK, "Cannot save the actual Workspace image."):
		return false
	_report[filename.get_basename() + "_image"] = path
	return true


func _check(condition: bool, message: String) -> bool:
	_report["assertions"] = GFVariantData.get_option_int(_report, "assertions") + 1
	if not condition:
		_report["ok"] = false
		_report["message"] = message
	return condition
