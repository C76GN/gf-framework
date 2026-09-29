@tool

# 由隔离工程中的真实 EditorPlugin 生命周期验证配置贡献、窗口与用户操作。
extends EditorPlugin


# --- 常量 ---

const _DOCK_TOOLS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const _REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _WORKSPACE_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_dock.gd")
const _MANIFEST: String = "res://addons/gf/tools/config_pipeline/editor/gf_editor_contributions.json"
const _CONFIG_DOCK_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_dock.gd")
const _PRESET_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_preset.gd")


# --- 私有变量 ---

var _tools: _DOCK_TOOLS_SCRIPT
var _assertions: int = 0


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	call_deferred("_run")


func _exit_tree() -> void:
	if _tools != null:
		_tools.cleanup(self)
		_tools = null


# --- 私有/辅助方法 ---

func _run() -> void:
	for _frame: int in range(10):
		await get_tree().process_frame
	var records: Dictionary = _REGISTRY_SCRIPT.load_manifest_records(_MANIFEST)
	var docks: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(records, "dock_records"):
		docks.append(GFVariantData.as_dictionary(value))
	if not _check(docks.size() == 1, "The real contribution registry must expose one configuration page."):
		return
	_tools = _DOCK_TOOLS_SCRIPT.new()
	_tools.setup(self, docks)
	_tools.show_workspace()
	await get_tree().process_frame
	var window: Window = _tools.get_workspace_window()
	var workspace: _WORKSPACE_SCRIPT = _find_workspace(window)
	if not _check(workspace != null and workspace.select_page("GF Config Workbench"), "Native workspace must select the contributed page."):
		return
	await get_tree().process_frame
	var create: Button = workspace.find_child("CreateSample", true, false)
	if not _check(create != null and create.is_visible_in_tree(), "Create sample must be visible in the native page."):
		return
	create.pressed.emit()
	await get_tree().process_frame
	var sample_dialog: ConfirmationDialog = _find_dialog(workspace, "创建样例（已有文件不会覆盖）")
	if not _check(sample_dialog != null and sample_dialog.visible, "Create sample must open a real confirmation dialog."):
		return
	var sample_fields: Array[Node] = sample_dialog.find_children("*", "LineEdit", true, false)
	var sample_root: LineEdit = sample_fields[0]
	sample_root.text = "res://tests/gf_core/generated/config_workbench"
	sample_dialog.confirmed.emit()
	await get_tree().process_frame
	if not _check(FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/config/build/main.tres"), "Sample confirmation must save the user-owned Profile."):
		return
	var export_button: Button = workspace.find_child("Export", true, false)
	export_button.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 20000
	while not FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/generated/config/main.tres") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/generated/config/main.tres.manifest.json"), "UI export must finish background preflight and commit the database plus manifest."):
		return
	var database: GFConfigDatabaseResource = load("res://tests/gf_core/generated/config_workbench/generated/config/main.tres")
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(database)
	if not _check(GFVariantData.get_option_string(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "name") == "Potion", "The native UI output must be readable through the runtime provider."):
		return
	var config_dock: _CONFIG_DOCK_SCRIPT = _find_config_dock(workspace)
	var session: RefCounted = config_dock.get("_session")
	var draft: GFConfigPipelineProfile = session.call("get_profile")
	var disk_digest: String = FileAccess.get_sha256("res://tests/gf_core/generated/config_workbench/config/build/main.tres")
	draft.sources.append(null)
	session.call("mark_changed")
	config_dock.set("_selected_source", 1)
	config_dock.call("_refresh_profile")
	var remove_source: Button = config_dock.find_child("RemoveSource", true, false)
	remove_source.pressed.emit()
	var admission: Dictionary = session.call("get_admission_report")
	if not _check(draft.sources.size() == 1 and GFVariantData.get_option_bool(admission, "success"), "The real Remove Source button must repair a null source slot."):
		return
	if not _check(config_dock.has_unsaved_workspace_changes() and FileAccess.get_sha256("res://tests/gf_core/generated/config_workbench/config/build/main.tres") == disk_digest, "Removing an invalid source must retain a draft without saving the Profile."):
		return
	var version: GFEditorValueField = workspace.find_child("Version", true, false)
	version.value_changed.emit("smoke edit")
	var close_task: Button = workspace.find_child("CloseTask", true, false)
	close_task.pressed.emit()
	var discard: ConfirmationDialog = _find_dialog(workspace, "未保存的 Profile 草稿")
	if not _check(discard != null and discard.visible, "Closing a dirty task must ask to save, discard or cancel."):
		return
	discard.canceled.emit()
	discard.hide()
	var status: Label = workspace.find_child("Status", true, false)
	if not _check(status.text.contains("未保存草稿"), "Cancel must retain the working draft."):
		return
	close_task.pressed.emit()
	discard.confirmed.emit()
	discard.hide()
	var save: Button = workspace.find_child("SaveProfile", true, false)
	if not _check(save.disabled, "Discard must close the task without rewriting its Profile."):
		return
	var saved: GFConfigPipelineProfile = load("res://tests/gf_core/generated/config_workbench/config/build/main.tres")
	if not _check(saved.version.is_empty(), "Unsaved edits must not escape into the user Profile."):
		return
	if not await _run_xlsx_wizard(workspace, export_button):
		return
	if not await _run_lifecycle_regressions(workspace):
		return
	_tools.cleanup(self)
	_tools = null
	var scan_deadline: int = Time.get_ticks_msec() + 20000
	var idle_frames: int = 0
	while idle_frames < 30 and Time.get_ticks_msec() < scan_deadline:
		await get_tree().process_frame
		idle_frames = 0 if EditorInterface.get_resource_filesystem().is_scanning() else idle_frames + 1
	if not _check(idle_frames == 30, "Editor filesystem work must finish before plugin shutdown is accepted."):
		return
	print("GF_CONFIG_WORKBENCH_EDITOR_SMOKE_OK assertions=%d" % _assertions)
	get_tree().quit(0)


func _run_xlsx_wizard(workspace: Control, export_button: Button) -> bool:
	var packer: ZIPPacker = ZIPPacker.new()
	if not _check(packer.open("res://tests/gf_core/generated/config_workbench/data/config/items.xlsx") == OK, "XLSX source fixture must be writable."):
		return false
	var entries: Dictionary = {
		"xl/workbook.xml": '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Balance" sheetId="1" r:id="rId1"/></sheets></workbook>',
		"xl/_rels/workbook.xml.rels": '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
		"xl/worksheets/sheet1.xml": '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>id:int!</t></is></c><c r="B1" t="inlineStr"><is><t>power:int</t></is></c></row><row r="2"><c r="A2"><v>1</v></c><c r="B2"><f>2+2</f><v>4</v></c></row></sheetData></worksheet>',
	}
	for path: String in entries:
		var entry_error: Error = packer.start_file(path)
		var write_error: Error = packer.write_file(GFVariantData.to_text(entries[path]).to_utf8_buffer())
		var close_error: Error = packer.close_file()
		if not _check(entry_error == OK and write_error == OK and close_error == OK, "XLSX fixture entries must be complete."):
			return false
	if not _check(packer.close() == OK, "XLSX archive must close successfully."):
		return false
	var new_profile: Button = workspace.find_child("NewProfile", true, false)
	new_profile.pressed.emit()
	var wizard: ConfirmationDialog = _find_dialog(workspace, "新建导表任务")
	if not _check(wizard != null and wizard.visible, "New task must open the native wizard."):
		return false
	var fields: Array[Node] = wizard.find_children("*", "LineEdit", true, false)
	if not _check(fields.size() == 3, "The initial wizard must need only source, name and output."):
		return false
	var source: LineEdit = fields[0]
	var database_name: LineEdit = fields[1]
	var output_root: LineEdit = fields[2]
	source.text = "res://tests/gf_core/generated/config_workbench/data/config/items.xlsx"
	database_name.text = "xlsx"
	output_root.text = "res://tests/gf_core/generated/config_workbench/generated"
	wizard.confirmed.emit()
	await get_tree().process_frame
	if not _check(export_button.text == "保存并导出", "New XLSX task must explicitly save before export."):
		return false
	export_button.pressed.emit()
	var dialogs: Array[Node] = workspace.find_children("*", "FileDialog", true, false)
	var saver: FileDialog = dialogs[0] if not dialogs.is_empty() else null
	if not _check(saver != null and saver.visible, "Save and export must request the Profile path."):
		return false
	saver.file_selected.emit("res://tests/gf_core/generated/config_workbench/config/build/xlsx.tres")
	saver.hide()
	var deadline: int = Time.get_ticks_msec() + 20000
	while not FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/generated/config/xlsx.tres") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/generated/config/xlsx.tres.manifest.json"), "XLSX wizard export must commit its manifest."):
		return false
	var database: GFConfigDatabaseResource = load("res://tests/gf_core/generated/config_workbench/generated/config/xlsx.tres")
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(database)
	if not _check(GFVariantData.get_option_int(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "power") == 4, "XLSX wizard output must expose the saved formula cache through Provider."):
		return false
	return true


func _run_lifecycle_regressions(workspace: Control) -> bool:
	var dock: _CONFIG_DOCK_SCRIPT = _find_config_dock(workspace)
	var context: GFEditorToolContext = GFEditorToolContext.from_plugin(self)
	var old_copy: Button = dock.find_child("CopyInferredSchema", true, false)
	dock.set_editor_context(null)
	dock.set_editor_context(context)
	old_copy.pressed.emit()
	var schema_picker: EditorResourcePicker = dock.find_child("ExplicitSchema", true, false)
	if not _check(schema_picker.edited_resource == null, "A detached copy-schema control must not modify the retained draft after rebind."):
		return false
	var options_field: GFEditorValueField = dock.find_child("SchemaOptions", true, false)
	options_field.value_changed.emit({ "typed_headers": true, "id_field": "id", "require_unique_id": false })
	var preset_button: Button = dock.find_child("ReapplyPreset", true, false)
	preset_button.pressed.emit()
	var preset_dialog: ConfirmationDialog = _find_dialog(dock, "预设 gf.config.basic / v1")
	dock.set_editor_context(null)
	dock.set_editor_context(context)
	preset_dialog.confirmed.emit()
	options_field = dock.find_child("SchemaOptions", true, false)
	if not _check(not GFVariantData.get_option_bool(GFVariantData.as_dictionary(options_field.get_value()), "require_unique_id"), "A revoked preset dialog must not reset the retained draft."):
		return false
	var close_task: Button = dock.find_child("CloseTask", true, false)
	close_task.pressed.emit()
	var discard: ConfirmationDialog = _find_dialog(dock, "未保存的 Profile 草稿")
	discard.confirmed.emit()
	discard.hide()
	var profile: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile("res://tests/gf_core/generated/config_workbench/data/config/items.csv", "revoked", "res://tests/gf_core/generated/revoked_generated")
	if not _check(ResourceSaver.save(profile, "res://tests/gf_core/generated/config_workbench/config/build/revoked.tres") == OK, "Revocation fixture Profile must save independently of its outputs."):
		return false
	var open_button: Button = dock.find_child("OpenProfile", true, false)
	open_button.pressed.emit()
	var picker: FileDialog = _find_file_dialog(dock)
	picker.file_selected.emit("res://tests/gf_core/generated/config_workbench/config/build/revoked.tres")
	picker.hide()
	var export_button: Button = dock.find_child("Export", true, false)
	var old_default: Button = dock.find_child("SetProjectDefault", true, false)
	var settings_before: String = FileAccess.get_sha256("res://project.godot")
	export_button.pressed.emit()
	var cancel: Button = dock.find_child("CancelPreview", true, false)
	if not _check(not cancel.disabled, "Export must have entered cancellable background preflight before revocation."):
		return false
	dock.set_editor_context(null)
	dock.set_editor_context(context)
	old_default.pressed.emit()
	export_button.pressed.emit()
	export_button = dock.find_child("Export", true, false)
	var deadline: int = Time.get_ticks_msec() + 20000
	while export_button.disabled and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(not FileAccess.file_exists(profile.output_path) and not DirAccess.dir_exists_absolute("res://tests/gf_core/generated/revoked_generated"), "Revoked preflight and detached Export must produce no outputs."):
		return false
	if not _check(FileAccess.get_sha256("res://project.godot") == settings_before, "Detached default action must not save project settings."):
		return false
	var sample: Button = dock.find_child("CreateSample", true, false)
	sample.pressed.emit()
	var sample_dialog: ConfirmationDialog = _find_dialog(dock, "创建样例（已有文件不会覆盖）")
	var sample_fields: Array[Node] = sample_dialog.find_children("*", "LineEdit", true, false)
	var sample_root: LineEdit = sample_fields[0]
	sample_root.text = "res://tests/gf_core/generated/revoked_sample"
	dock.set_editor_context(null)
	dock.set_editor_context(context)
	sample_dialog.confirmed.emit()
	if not _check(not DirAccess.dir_exists_absolute("res://tests/gf_core/generated/revoked_sample"), "Revoked sample confirmation must create no user files."):
		return false
	close_task = dock.find_child("CloseTask", true, false)
	close_task.pressed.emit()
	var create: Button = dock.find_child("NewProfile", true, false)
	create.pressed.emit()
	var wizard: ConfirmationDialog = _find_dialog(dock, "新建导表任务")
	var wizard_fields: Array[Node] = wizard.find_children("*", "LineEdit", true, false)
	var source_field: LineEdit = wizard_fields[0]
	source_field.text = "res://tests/gf_core/generated/config_workbench/data/config/items.csv"
	wizard.confirmed.emit()
	await get_tree().process_frame
	var save: Button = dock.find_child("SaveProfile", true, false)
	var old_version: GFEditorValueField = dock.find_child("Version", true, false)
	save.pressed.emit()
	var old_saver: FileDialog = _find_file_dialog(dock)
	dock.set_editor_context(null)
	dock.set_editor_context(context)
	old_saver.file_selected.emit("res://tests/gf_core/generated/config_workbench/config/build/revoked-save.tres")
	old_version.value_changed.emit("late callback")
	var version: GFEditorValueField = dock.find_child("Version", true, false)
	if not _check(not FileAccess.file_exists("res://tests/gf_core/generated/config_workbench/config/build/revoked-save.tres") and GFVariantData.to_text(version.get_value()).is_empty(), "Revoked Save dialog and old value control must preserve the draft without writing."):
		return false
	if not await _run_preview_freshness(dock):
		return false
	return true


func _run_preview_freshness(dock: _CONFIG_DOCK_SCRIPT) -> bool:
	var preview: Button = dock.find_child("PreviewSource", true, false)
	var status: Label = dock.find_child("PreviewStatus", true, false)
	dock.set_process(false)
	preview.pressed.emit()
	var task_value: Variant = dock.get("_task")
	if not (task_value is GFEditorBackgroundRequestTask):
		return _check(false, "Preview must own a background task.")
	var task: GFEditorBackgroundRequestTask = task_value
	var deadline: int = Time.get_ticks_msec() + 20000
	while task.is_running() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(not task.is_running(), "The worker must finish reading before the source is changed."):
		return false
	var file: FileAccess = FileAccess.open("res://tests/gf_core/generated/config_workbench/data/config/items.csv", FileAccess.WRITE)
	var _stored: bool = file.store_string("id:int!,name:string\n1,Changed\n")
	file.close()
	dock.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _check(status.text.contains("预览已过期"), "A receipt mismatch must reject the worker result before showing it as current."):
		return false
	preview.pressed.emit()
	deadline = Time.get_ticks_msec() + 20000
	while not status.text.begins_with("共 1 行") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _check(status.text.begins_with("共 1 行"), "A matching preview receipt must be displayed."):
		return false
	file = FileAccess.open("res://tests/gf_core/generated/config_workbench/data/config/items.csv", FileAccess.WRITE)
	_stored = file.store_string("id:int!,name:string\n1,ChangedAgain\n2,Second\n")
	file.close()
	deadline = Time.get_ticks_msec() + 5000
	while not status.text.contains("预览已过期") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _check(status.text.contains("预览已过期"), "Successful preview freshness must expire independently of any Runner result.")


func _find_file_dialog(node: Node) -> FileDialog:
	var dialogs: Array[Node] = node.find_children("*", "FileDialog", true, false)
	var dialog: FileDialog = dialogs[0] if not dialogs.is_empty() else null
	return dialog


func _find_config_dock(node: Node) -> _CONFIG_DOCK_SCRIPT:
	if node is _CONFIG_DOCK_SCRIPT:
		var dock: _CONFIG_DOCK_SCRIPT = node
		return dock
	for child: Node in node.get_children():
		var found: _CONFIG_DOCK_SCRIPT = _find_config_dock(child)
		if found != null:
			return found
	return null


func _find_workspace(node: Node) -> _WORKSPACE_SCRIPT:
	if node is _WORKSPACE_SCRIPT:
		var workspace: _WORKSPACE_SCRIPT = node
		return workspace
	for child: Node in node.get_children():
		var found: _WORKSPACE_SCRIPT = _find_workspace(child)
		if found != null:
			return found
	return null


func _find_dialog(node: Node, title: String) -> ConfirmationDialog:
	if node is ConfirmationDialog:
		var dialog: ConfirmationDialog = node
		if dialog.title == title:
			return dialog
	for child: Node in node.get_children():
		var found: ConfirmationDialog = _find_dialog(child, title)
		if found != null:
			return found
	return null


func _check(condition: bool, message: String) -> bool:
	if not condition:
		print("GF_CONFIG_WORKBENCH_EDITOR_SMOKE_FAILED " + message)
		get_tree().quit(1)
		return false
	_assertions += 1
	return true
