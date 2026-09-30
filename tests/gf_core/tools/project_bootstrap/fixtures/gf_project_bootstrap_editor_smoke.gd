@tool

# 在隔离项目中操作真实初始化页，验证默认计划、文件/设置提交和失败保护。
extends EditorPlugin


# --- 常量 ---

const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")
const _DOCK_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/editor/gf_project_bootstrap_dock.gd")
const _EXISTING_OPTIONS: Dictionary = {"mode": "existing_project"}


# --- 私有变量 ---

var _assertions: int = 0
var _failed: bool = false
var _filesystem_changes: int = 0
var _retained_scan_synchronous_observed: bool = false


# --- Godot 回调方法 ---

func _enter_tree() -> void:
	_run.call_deferred()


# --- 私有/辅助方法 ---

func _run() -> void:
	var private_root: String = OS.get_environment("GF_PROJECT_BOOTSTRAP_SMOKE_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	_check(not private_root.is_empty() and private_root.is_absolute_path(), "A private runtime root is required.")
	for directory: String in [OS.get_data_dir(), OS.get_config_dir(), OS.get_cache_dir(), OS.get_user_data_dir()]:
		_check(directory.replace("\\", "/").simplify_path().to_lower().begins_with(private_root.to_lower() + "/"), "Native user/config/cache roots must be private.")
	if _failed:
		get_tree().call_deferred(&"quit", 1)
		return
	# 原生编辑器持续读取主场景键，保留存在的空值；缺失主场景键由普通 GUT 覆盖。
	ProjectSettings.set_setting("gf/project/installers", null)
	ProjectSettings.set_setting("application/run/main_scene", "")
	_check(ProjectSettings.save() == OK, "Empty settings must save.")
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var dock: _DOCK_SCRIPT = _new_dock()
	var task_ok: bool = dock.run_workspace_task("new_project")["ok"]
	_check(task_ok, "The existing Workspace task must open the initialization page.")
	var mode: OptionButton = dock.find_child("InitializationMode", true, false)
	var directory: LineEdit = dock.find_child("OutputDirectory", true, false)
	var installer: CheckBox = dock.find_child("CreateInstaller", true, false)
	var readme: CheckBox = dock.find_child("IncludeReadme", true, false)
	_check(mode.selected == 0 and directory.text == "res://app", "New projects must have usable default mode and directory.")
	_check(installer.button_pressed and not readme.button_pressed, "Only the empty Installer is included by default.")
	await _wait_for_create(dock)
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "Opening and automatic preview must not save settings.")
	_check(not FileAccess.file_exists("res://app/boot.tscn"), "Opening and automatic preview must not create files.")
	_press(dock, "InitializeProject")
	for file_name: String in ["boot.gd", "boot.tscn", "main.tscn", "project_installer.gd"]:
		_check(FileAccess.file_exists("res://app/" + file_name), "One click must create the default output: " + file_name)
	_check(not FileAccess.file_exists("res://app/README.md"), "README must remain opt-in.")
	_check(not FileAccess.file_exists("res://app/counter_model.gd") and not FileAccess.file_exists("res://app/counter_system.gd"), "Default initialization must not create business modules.")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	var new_installers: Array = ProjectSettings.get_setting("gf/project/installers")
	_check(main_scene == "res://app/boot.tscn", "New-project initialization must persist the Boot entry scene.")
	_check(new_installers == ["res://app/project_installer.gd"], "Only the generated empty Installer must be registered.")
	dock.free()
	var original_installers: PackedStringArray = PackedStringArray(["res://existing_installer.gd", "res://legacy_counter_installer.gd"])
	ProjectSettings.set_setting("gf/project/installers", original_installers)
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")
	_check(ProjectSettings.save() == OK, "Existing project settings must save.")
	var legacy_hash: String = FileAccess.get_sha256("res://legacy_counter_installer.gd")
	var refused: Dictionary = _GENERATOR_SCRIPT.create("res://must_not_replace")
	var refused_ok: bool = refused["ok"]
	_check(not refused_ok and not FileAccess.file_exists("res://must_not_replace/boot.tscn"), "New-project mode must reject an already configured project.")
	dock = _new_dock()
	_configure_existing(dock, "res://integration")
	_press(dock, "RefreshPlan")
	_press(dock, "InitializeProject")
	_check(FileAccess.file_exists("res://integration/project_installer.gd"), "Existing-project integration must create its selected empty Installer.")
	_check(not FileAccess.file_exists("res://integration/boot.tscn") and not FileAccess.file_exists("res://integration/main.tscn"), "Existing projects must not receive a replacement Boot or Main.")
	main_scene = ProjectSettings.get_setting("application/run/main_scene")
	var appended: PackedStringArray = ProjectSettings.get_setting("gf/project/installers")
	_check(main_scene == "res://existing.tscn", "Existing integration must preserve its actual entry scene.")
	_check(appended == PackedStringArray(["res://existing_installer.gd", "res://legacy_counter_installer.gd", "res://integration/project_installer.gd"]), "Existing Installer order and the old sample must be preserved.")
	_check(original_installers == PackedStringArray(["res://existing_installer.gd", "res://legacy_counter_installer.gd"]), "Planning must not mutate the original Installer array.")
	_check(FileAccess.get_sha256("res://legacy_counter_installer.gd") == legacy_hash, "The initializer must not migrate or delete old sample files.")
	_exercise_refreshed_existing_main(dock)
	dock.free()
	_check_persisted_settings()
	_exercise_guidance_and_readme()
	_exercise_autoload_prerequisites()
	_exercise_retired_dock()
	_exercise_create_only_and_stale_preview()
	var failure: Dictionary = _exercise_save_failure()
	_exercise_recovery_dock(failure)
	await _exercise_retained_sidecar_scan()
	_exercise_installer_opt_out()
	ProjectSettings.set_setting("gf/project/installers", appended)
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray())
	_check(ProjectSettings.save() == OK, "The isolated smoke plugin must be disabled before runtime import.")
	var deadline: int = Time.get_ticks_msec() + 30000
	while EditorInterface.get_resource_filesystem().is_scanning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not EditorInterface.get_resource_filesystem().is_scanning(), "The editor scan must settle within its bounded deadline.")
	if not _failed:
		print("GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_OK " + JSON.stringify({"assertions": _assertions, "native_private_directories_verified": true, "new_project_default_created": true, "existing_preserves_main_and_installers": true, "refreshed_existing_main_is_current": true, "failed_retained_sidecar_scan_requested": true, "failed_creation_does_not_open_scene": true, "retained_scan_synchronous_observed": _retained_scan_synchronous_observed, "guidance_only_no_writes": true, "readme_only_no_settings_save": true, "settings_failure_compensated": true, "create_only_and_preview_stale": true, "retired_callbacks_rejected": true, "recovery_ui_preserved": true, "legacy_sample_preserved": true, "canonical_autoload_guarded": true}))
	get_tree().call_deferred(&"quit", 1 if _failed else 0)


func _new_dock() -> _DOCK_SCRIPT:
	var dock: _DOCK_SCRIPT = _DOCK_SCRIPT.new()
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	EditorInterface.get_base_control().add_child(dock)
	return dock


func _configure_existing(dock: _DOCK_SCRIPT, path: String) -> void:
	var mode: OptionButton = dock.find_child("InitializationMode", true, false)
	var directory: LineEdit = dock.find_child("OutputDirectory", true, false)
	mode.select(1)
	mode.item_selected.emit(1)
	directory.text = path
	directory.text_changed.emit(path)


func _wait_for_create(dock: _DOCK_SCRIPT) -> void:
	var button: Button = dock.find_child("InitializeProject", true, false)
	var deadline: int = Time.get_ticks_msec() + 10000
	while button.disabled and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not button.disabled, "Automatic read-only preview must enable valid default initialization.")


func _press(node: Node, control_name: String) -> void:
	var button: Button = node.find_child(control_name, true, false)
	_check(button != null and not button.disabled, "Action must be enabled: " + control_name)
	if button != null and not button.disabled:
		button.pressed.emit()


func _check_persisted_settings() -> void:
	var persisted: ConfigFile = ConfigFile.new()
	_check(persisted.load(ProjectSettings.globalize_path("res://project.godot")) == OK, "Saved project settings must reload.")
	var persisted_main: String = persisted.get_value("application", "run/main_scene")
	var installers_match: bool = persisted.get_value("gf", "project/installers") == ProjectSettings.get_setting("gf/project/installers")
	_check(persisted_main == "res://existing.tscn" and installers_match, "Actual disk settings must match the preserved entry and appended Installer order.")


func _exercise_refreshed_existing_main(dock: _DOCK_SCRIPT) -> void:
	var completed: Dictionary = dock.get("_last_report")
	var completed_report_matches: bool = completed.get("ok") == true and completed.get("main_scene_path") == "res://existing.tscn"
	_check(completed_report_matches, "Main refresh must start from the actual successful integration report.")
	_check(ResourceLoader.exists("res://other_existing.tscn", "PackedScene"), "The changed main scene must be a real project resource.")
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var open_main: Button = dock.find_child("OpenMain", true, false)
	ProjectSettings.set_setting("application/run/main_scene", "res://other_existing.tscn")
	_press(dock, "RefreshPlan")
	var conflicting_plan: Dictionary = dock.get("_plan")
	var conflicting_plan_blocked: bool = conflicting_plan.get("ok") == false
	_check(conflicting_plan_blocked, "The existing generated Installer must keep repeated creation blocked during Main refresh.")
	var selected_path: Variant = dock.call(&"_main_path")
	var selected_main_current: bool = selected_path is String and selected_path == "res://other_existing.tscn" and not open_main.disabled
	_check(selected_main_current, "Refreshing an existing project must locate its current Main even when creation is blocked.")
	ProjectSettings.set_setting("application/run/main_scene", "")
	_press(dock, "RefreshPlan")
	selected_path = dock.call(&"_main_path")
	var selected_main_cleared: bool = selected_path is String and selected_path == "" and open_main.disabled
	_check(selected_main_cleared, "Clearing the current Main must disable OpenMain without falling back to the previous success report.")
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "Refreshing Main navigation must not save external in-memory settings.")
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")


func _exercise_guidance_and_readme() -> void:
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var options: Dictionary = {"mode": "existing_project", "create_installer": false}
	var report: Dictionary = _GENERATOR_SCRIPT.create("res://guidance_only", options)
	var report_ok: bool = report["ok"]
	var files_created: bool = report["files_created"]
	var settings_saved: bool = report["settings_saved"]
	var transactions: Array = report["transactions"]
	_check(report_ok and not files_created and not settings_saved and transactions.is_empty(), "Guidance-only execution must have no file transaction or settings save.")
	_check(not DirAccess.dir_exists_absolute("res://guidance_only"), "Guidance-only execution must not even create its output directory.")
	var dock: _DOCK_SCRIPT = _new_dock()
	_configure_existing(dock, "res://guidance_only")
	var installer: CheckBox = dock.find_child("CreateInstaller", true, false)
	installer.button_pressed = false
	_press(dock, "RefreshPlan")
	var create_button: Button = dock.find_child("InitializeProject", true, false)
	var copy_button: Button = dock.find_child("CopyIntegrationSnippet", true, false)
	_check(create_button.disabled and not copy_button.disabled, "Guidance-only UI must expose the snippet without offering a write action.")
	create_button.pressed.emit()
	_check(not DirAccess.dir_exists_absolute("res://guidance_only"), "A queued guidance-only create callback must remain read-only.")
	dock.free()
	options["include_readme"] = true
	report = _GENERATOR_SCRIPT.create("res://readme_only", options)
	report_ok = report["ok"]
	settings_saved = report["settings_saved"]
	_check(report_ok and not settings_saved, "README-only creation must not save project settings.")
	_check(FileAccess.file_exists("res://readme_only/README.md") and not FileAccess.file_exists("res://readme_only/project_installer.gd"), "README-only creation must own exactly the selected output.")
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "Guidance and README-only operations must preserve saved project bytes.")


func _exercise_autoload_prerequisites() -> void:
	var original: Variant = ProjectSettings.get_setting("autoload/Gf")
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var preview: Dictionary = _GENERATOR_SCRIPT.get_plan("res://autoload_guard", _EXISTING_OPTIONS)
	var preview_ok: bool = preview["ok"]
	_check(preview_ok, "The canonical enabled Gf singleton must permit a preview.")
	var signature: String = preview["signature"]
	for conflicting: String in ["*res://other_gf_singleton.gd", "res://addons/gf/kernel/core/gf.gd"]:
		ProjectSettings.set_setting("autoload/Gf", conflicting)
		var rejected: Dictionary = _GENERATOR_SCRIPT.create("res://autoload_guard", _EXISTING_OPTIONS, signature)
		var rejected_ok: bool = rejected["ok"]
		var transactions: Array = rejected["transactions"]
		_check(not rejected_ok and transactions.is_empty(), "A conflicting or disabled Gf must reject creation before any transaction.")
		var unchanged: bool = ProjectSettings.get_setting("autoload/Gf") == conflicting
		_check(unchanged, "The initializer must not repair or compensate a user-owned AutoLoad setting.")
	var uid: int = ResourceLoader.get_resource_uid("res://addons/gf/kernel/core/gf.gd")
	_check(uid != ResourceUID.INVALID_ID, "The canonical Gf script must have an imported UID.")
	if uid != ResourceUID.INVALID_ID:
		ProjectSettings.set_setting("autoload/Gf", "*" + ResourceUID.id_to_text(uid))
		var stale: Dictionary = _GENERATOR_SCRIPT.create("res://autoload_guard", _EXISTING_OPTIONS, signature)
		var stale_ok: bool = stale["ok"]
		_check(not stale_ok, "A valid changed in-memory AutoLoad must invalidate an earlier preview.")
	_check(not FileAccess.file_exists("res://autoload_guard/project_installer.gd"), "Rejected AutoLoad prerequisites must not create files.")
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "Rejected prerequisites must not save settings.")
	ProjectSettings.set_setting("autoload/Gf", original)


func _exercise_retired_dock() -> void:
	var dock: _DOCK_SCRIPT = _new_dock()
	_configure_existing(dock, "res://retired_integration")
	_press(dock, "RefreshPlan")
	var old_preview: Button = dock.find_child("RefreshPlan", true, false)
	var old_create: Button = dock.find_child("InitializeProject", true, false)
	_check(not old_create.disabled, "A live preview must allow creation before retirement.")
	var before_hash: String = FileAccess.get_sha256("res://project.godot")
	var before_installers: Variant = ProjectSettings.get_setting("gf/project/installers")
	dock.set_editor_context(null)
	old_create.pressed.emit()
	old_preview.pressed.emit()
	old_create.pressed.emit()
	var task_ok: bool = dock.run_workspace_task("new_project")["ok"]
	_check(not task_ok, "A revoked page must reject task dispatch.")
	_check(not FileAccess.file_exists("res://retired_integration/project_installer.gd"), "Revoked buttons must not create files.")
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	_press(dock, "RefreshPlan")
	_check(not old_create.disabled, "A rebound live context must permit a fresh plan.")
	dock.get_parent().remove_child(dock)
	old_preview.pressed.emit()
	old_create.pressed.emit()
	task_ok = dock.run_workspace_task("new_project")["ok"]
	_check(not task_ok and not FileAccess.file_exists("res://retired_integration/project_installer.gd"), "Detached callbacks must reject dispatch and writes.")
	_check(FileAccess.get_sha256("res://project.godot") == before_hash, "Retired callbacks must preserve saved settings.")
	var unchanged: bool = ProjectSettings.get_setting("gf/project/installers") == before_installers
	_check(unchanged, "Retired callbacks must preserve live Installer settings.")
	dock.free()


func _exercise_create_only_and_stale_preview() -> void:
	var original_hash: String = FileAccess.get_sha256("res://integration/project_installer.gd")
	var repeated: Dictionary = _GENERATOR_SCRIPT.create("res://integration", _EXISTING_OPTIONS)
	var repeated_ok: bool = repeated["ok"]
	_check(not repeated_ok and FileAccess.get_sha256("res://integration/project_installer.gd") == original_hash, "Repeated creation must preserve existing bytes and reject duplication.")
	var before_installers: Variant = ProjectSettings.get_setting("gf/project/installers")
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://stale_integration", _EXISTING_OPTIONS)
	var signature: String = plan["signature"]
	ProjectSettings.set_setting("gf/project/installers", [])
	var stale: Dictionary = _GENERATOR_SCRIPT.create("res://stale_integration", _EXISTING_OPTIONS, signature)
	var stale_ok: bool = stale["ok"]
	_check(not stale_ok and not FileAccess.file_exists("res://stale_integration/project_installer.gd"), "Changed in-memory settings must reject a stale preview before writing.")
	ProjectSettings.set_setting("gf/project/installers", before_installers)
	plan = _GENERATOR_SCRIPT.get_plan("res://stale_options", _EXISTING_OPTIONS)
	signature = plan["signature"]
	stale = _GENERATOR_SCRIPT.create("res://stale_options", {"mode": "existing_project", "include_readme": true}, signature)
	stale_ok = stale["ok"]
	_check(not stale_ok and not FileAccess.file_exists("res://stale_options/README.md"), "Changed generation options must invalidate the preview.")
	plan = _GENERATOR_SCRIPT.get_plan("res://stale_disk", _EXISTING_OPTIONS)
	signature = plan["signature"]
	ProjectSettings.set_setting("bootstrap_smoke/disk_revision", 1)
	_check(ProjectSettings.save() == OK, "An unrelated persisted setting must create a real disk-baseline change.")
	stale = _GENERATOR_SCRIPT.create("res://stale_disk", _EXISTING_OPTIONS, signature)
	stale_ok = stale["ok"]
	_check(not stale_ok and not FileAccess.file_exists("res://stale_disk/project_installer.gd"), "Changed project.godot bytes must reject an old preview even when relevant settings match.")
	ProjectSettings.set_setting("bootstrap_smoke/disk_revision", null)
	_check(ProjectSettings.save() == OK, "The disk-baseline fixture setting must be removed before further scenarios.")


func _exercise_save_failure() -> Dictionary:
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var installers_before: Variant = ProjectSettings.get_setting("gf/project/installers")
	_GENERATOR_SCRIPT.configure_test_save_error(ERR_CANT_CREATE)
	var report: Dictionary = _GENERATOR_SCRIPT.create("res://failed_integration", _EXISTING_OPTIONS)
	var report_ok: bool = report["ok"]
	var rolled_back: bool = report["rolled_back"]
	var recovery_required: bool = report["recovery_required"]
	_check(not report_ok and rolled_back and not recovery_required, "A failed settings save must compensate owned files without recovery debt: " + str(report))
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "A failed save must preserve old project bytes.")
	var restored: bool = ProjectSettings.get_setting("gf/project/installers") == installers_before
	_check(restored, "A failed save must restore the original Installer settings.")
	for path: String in report["paths"]:
		_check(not FileAccess.file_exists(path), "Compensation must remove only its own new output: " + path)
	var retry_ok: bool = _GENERATOR_SCRIPT.get_plan("res://failed_integration", _EXISTING_OPTIONS)["ok"]
	_check(retry_ok, "A fully compensated operation must allow a fresh plan at the same path.")
	return report


func _exercise_recovery_dock(failure_report: Dictionary) -> void:
	var dock: _DOCK_SCRIPT = _new_dock()
	_configure_existing(dock, "res://recovery_ui")
	# 只注入 UI 恢复报告；真实保存失败与补偿已在前一段验证。
	var report: Dictionary = failure_report.duplicate(true)
	report["recovery_required"] = true
	report["rolled_back"] = false
	report["status"] = "recovery_required"
	dock.set("_last_report", report)
	var _shown: Variant = dock.call(&"_show_report", report)
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	var directory: LineEdit = dock.find_child("OutputDirectory", true, false)
	var mode: OptionButton = dock.find_child("InitializationMode", true, false)
	var installer: CheckBox = dock.find_child("CreateInstaller", true, false)
	var readme: CheckBox = dock.find_child("IncludeReadme", true, false)
	var details: RichTextLabel = dock.find_child("CreationDetails", true, false)
	var preserved_text: String = details.text
	var before_hash: String = FileAccess.get_sha256("res://project.godot")
	_check(not directory.editable and mode.disabled and installer.disabled and readme.disabled, "Recovery must lock all initialization inputs.")
	directory.text_changed.emit("res://recovery_ui")
	mode.item_selected.emit(0)
	installer.toggled.emit(false)
	readme.toggled.emit(true)
	var preview: Button = dock.find_child("RefreshPlan", true, false)
	var create_button: Button = dock.find_child("InitializeProject", true, false)
	preview.pressed.emit()
	create_button.pressed.emit()
	_check(details.text == preserved_text and details.text.contains("需要检查并恢复"), "Queued callbacks must preserve recovery instructions.")
	_check(not FileAccess.file_exists("res://recovery_ui/project_installer.gd"), "Recovery callbacks must not create files.")
	_check(FileAccess.get_sha256("res://project.godot") == before_hash, "Recovery callbacks must not save settings.")
	dock.free()


func _exercise_retained_sidecar_scan() -> void:
	var dock: _DOCK_SCRIPT = _new_dock()
	_configure_existing(dock, "res://retained_sidecar")
	_press(dock, "RefreshPlan")
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var previous_auto_import: Variant = settings.get_setting("interface/editor/behavior/import_resources_when_unfocused")
	settings.set_setting("interface/editor/behavior/import_resources_when_unfocused", false)
	var _connected: int = filesystem.filesystem_changed.connect(_on_filesystem_changed)
	await _wait_for_filesystem_idle()
	_check(DisplayServer.get_name() == "headless", "The scan observation must run without window-focus-triggered scans.")
	var auto_scan_disabled: bool = settings.get_setting("interface/editor/behavior/import_resources_when_unfocused") == false
	_check(auto_scan_disabled, "The isolated editor must disable periodic scans during the product scan observation.")
	_check(filesystem.get_filesystem_path("res://retained_sidecar") == null, "The retained-output directory must not already exist in the editor filesystem index.")
	var scene_before: Node = EditorInterface.get_edited_scene_root()
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var installers_before: Variant = ProjectSettings.get_setting("gf/project/installers")
	var changes_before: int = _filesystem_changes
	# 既有事务 seam 在实际 staging 写入后失败并保留自有 sidecar，不替换生成器或扫描 API。
	GFArtifactWriteTransaction._configure_test_owned_write_failures(0, 1, 2)
	_press(dock, "InitializeProject")
	_retained_scan_synchronous_observed = filesystem.is_scanning() or _filesystem_changes > changes_before
	GFArtifactWriteTransaction._reset_test_owned_write_failures()
	var report: Dictionary = dock.get("_last_report")
	var retained_failure: bool = report.get("ok") == false and report.get("status") == "file_commit_failed" and report.get("files_created") == true and report.get("recovery_required") == true
	_check(retained_failure, "The actual failed transaction must retain owned staging output and report recovery debt.")
	var sidecars: PackedStringArray = _retained_staging_paths("res://retained_sidecar")
	_check(sidecars.size() == 1 and FileAccess.file_exists(sidecars[0]), "The failed transaction must leave its actual staging sidecar on disk.")
	_check(not FileAccess.file_exists("res://retained_sidecar/project_installer.gd"), "A retained staging sidecar must not be described as a published Installer.")
	_check(EditorInterface.get_edited_scene_root() == scene_before, "Failed creation must not automatically open a scene.")
	await _wait_for_filesystem_idle()
	_check(_filesystem_changes > changes_before, "The requested scan must produce an actual filesystem change observation.")
	_check(filesystem.get_filesystem_path("res://retained_sidecar") != null, "Failed creation with retained output must refresh its new directory into the editor filesystem index.")
	_check(EditorInterface.get_edited_scene_root() == scene_before, "Finishing the failed-output scan must preserve the current editor scene.")
	filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
	var preserved_settings: bool = FileAccess.get_sha256("res://project.godot") == disk_before and ProjectSettings.get_setting("gf/project/installers") == installers_before
	_check(preserved_settings, "A failed staging commit must preserve both saved and live project settings.")
	var transactions: Array = report["transactions"]
	var recovered_count: int = 0
	for transaction: Dictionary in transactions:
		if transaction.get("recovery_required") != true or transaction.get("recovery_action") != &"complete":
			continue
		var recovery: Dictionary = transaction["recovery_transaction"]
		var recovered: Dictionary = GFArtifactWriteTransaction.complete(recovery)
		var recovery_complete: bool = recovered.get("ok") == true
		_check(recovery_complete, "The retained staging sidecar must be cleaned with its original owned recovery handle.")
		recovered_count += 1
	_check(recovered_count == 1, "The staging failure must expose exactly one owned cleanup obligation.")
	for path: String in sidecars:
		_check(not FileAccess.file_exists(path), "Completing recovery must remove the exact retained sidecar.")
	settings.set_setting("interface/editor/behavior/import_resources_when_unfocused", previous_auto_import)
	dock.free()


func _wait_for_filesystem_idle() -> void:
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var idle_frames: int = 0
	var previous_changes: int = _filesystem_changes
	var deadline: int = Time.get_ticks_msec() + 30000
	while idle_frames < 5 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		idle_frames = idle_frames + 1 if not filesystem.is_scanning() and not filesystem.is_importing() and _filesystem_changes == previous_changes else 0
		previous_changes = _filesystem_changes
	_check(idle_frames == 5, "The real editor filesystem must reach five consecutive idle frames within the deadline.")


func _retained_staging_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var access: DirAccess = DirAccess.open(directory)
	if access == null:
		return paths
	access.include_hidden = true
	for file_name: String in access.get_files():
		if file_name.begins_with(".gf-artifact-staging-"):
			var _appended: bool = paths.append(directory.path_join(file_name))
	return paths


func _exercise_installer_opt_out() -> void:
	ProjectSettings.set_setting("gf/project/installers", null)
	ProjectSettings.set_setting("application/run/main_scene", "")
	_check(ProjectSettings.save() == OK, "Optional-output scenario must begin from saved empty settings.")
	var empty_disk: String = FileAccess.get_sha256("res://project.godot")
	_GENERATOR_SCRIPT.configure_test_save_error(ERR_CANT_CREATE)
	var failed: Dictionary = _GENERATOR_SCRIPT.create("res://failed_new_project")
	var failed_ok: bool = failed["ok"]
	var rolled_back: bool = failed["rolled_back"]
	_check(not failed_ok and rolled_back, "A failed new-project settings save must compensate the whole default output.")
	var restored_main: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(ProjectSettings.has_setting("application/run/main_scene") and restored_main.is_empty() and not ProjectSettings.has_setting("gf/project/installers"), "Compensation must restore the editor's empty main-scene value and the absent Installer setting.")
	_check(FileAccess.get_sha256("res://project.godot") == empty_disk, "New-project save failure must preserve the old disk baseline.")
	for path: String in failed["paths"]:
		_check(not FileAccess.file_exists(path), "New-project compensation must remove its owned output: " + path)
	var report: Dictionary = _GENERATOR_SCRIPT.create("res://without_installer", {"create_installer": false})
	var report_ok: bool = report["ok"]
	var paths: PackedStringArray = report["paths"]
	_check(report_ok and paths.size() == 3, "Installer opt-out must generate only Boot script, Boot scene and Main scene.")
	_check(not ProjectSettings.has_setting("gf/project/installers"), "Installer opt-out must preserve an absent Installer setting.")
	_check(not FileAccess.file_exists("res://without_installer/project_installer.gd"), "Installer opt-out must not leave an unregistered Installer file.")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		push_error("GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_FAILED: " + message)


# --- 信号处理函数 ---

func _on_filesystem_changed() -> void:
	_filesystem_changes += 1
