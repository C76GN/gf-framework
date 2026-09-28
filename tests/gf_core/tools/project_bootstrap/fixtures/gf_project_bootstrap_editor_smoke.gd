@tool

# 在隔离项目中操作真实工作区页，验证文件与设置提交、补偿和默认行为。
extends EditorPlugin


# --- 常量 ---

const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")
const _DOCK_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/editor/gf_project_bootstrap_dock.gd")


# --- 私有变量 ---

var _assertions: int = 0
var _failed: bool = false


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
	var original_installers: PackedStringArray = PackedStringArray(["res://existing_installer.gd"])
	ProjectSettings.set_setting("gf/project/installers", original_installers)
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")
	_check(ProjectSettings.save() == OK, "Seed settings must save.")
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var dock: _DOCK_SCRIPT = _DOCK_SCRIPT.new()
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	EditorInterface.get_base_control().add_child(dock)
	var task_ok: bool = dock.run_workspace_task("new_project")["ok"]
	_check(task_ok, "Workspace entry must open the wizard.")
	var main_node: Node = dock.find_child("SetMainScene", true, false)
	_check(main_node is CheckBox, "Main-scene opt-in must be visible.")
	if main_node is CheckBox:
		var main_checkbox: CheckBox = main_node
		_check(not main_checkbox.button_pressed, "Main-scene replacement defaults off.")
	_press(dock, "预览创建计划")
	_check(FileAccess.get_sha256("res://project.godot") == disk_before, "Preview must not save settings.")
	_check(not FileAccess.file_exists("res://game/bootstrap/bootstrap.tscn"), "Preview must not create files.")
	_press(dock, "创建最小项目")
	_check(FileAccess.file_exists("res://game/bootstrap/bootstrap.tscn"), "The native create button must create the scene.")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	var appended_installers: PackedStringArray = ProjectSettings.get_setting("gf/project/installers")
	_check(main_scene == "res://existing.tscn", "Default creation must retain the main scene.")
	_check(appended_installers == PackedStringArray(["res://existing_installer.gd", "res://game/bootstrap/game_installer.gd"]), "Creation must append without dropping prior installers.")
	_check(original_installers == PackedStringArray(["res://existing_installer.gd"]), "Creation must not mutate the previous array.")
	dock.free()
	_exercise_retired_dock()
	var collision: Dictionary = _GENERATOR_SCRIPT.get_plan("res://other_directory", "GameDemo")
	var collision_ok: bool = collision["ok"]
	_check(not collision_ok, "Pending class names must be reserved before asynchronous import completes.")
	var second: Dictionary = _GENERATOR_SCRIPT.create("res://second_example", "SecondSmoke", true)
	var second_ok: bool = second["ok"]
	_check(second_ok, "Explicit main-scene creation must succeed: " + str(second))
	main_scene = ProjectSettings.get_setting("application/run/main_scene")
	_check(main_scene == "res://second_example/bootstrap.tscn", "Explicit opt-in must set the actual new scene.")
	var persisted: ConfigFile = ConfigFile.new()
	var project_path: String = ProjectSettings.globalize_path("res://project.godot")
	_check(persisted.load(project_path) == OK, "Saved project settings must reload.")
	var persisted_main: String = persisted.get_value("application", "run/main_scene")
	var persisted_matches: bool = persisted.get_value("gf", "project/installers") == ProjectSettings.get_setting("gf/project/installers")
	_check(persisted_main == "res://second_example/bootstrap.tscn", "The main scene must be persisted.")
	_check(persisted_matches, "Installer order must survive save/reload.")
	var before_failure: String = FileAccess.get_sha256("res://project.godot")
	var before_installers: Variant = ProjectSettings.get_setting("gf/project/installers")
	_GENERATOR_SCRIPT.configure_test_save_error(ERR_CANT_CREATE)
	var failure: Dictionary = _GENERATOR_SCRIPT.create("res://failed_example", "FailureSmoke", true)
	var failure_ok: bool = failure["ok"]
	var rolled_back: bool = failure["rolled_back"]
	var recovery_required: bool = failure["recovery_required"]
	_check(not failure_ok and rolled_back, "A failed settings save must compensate owned files: " + str(failure))
	_check(not recovery_required, "Successful compensation must have no recovery debt.")
	_check(FileAccess.get_sha256("res://project.godot") == before_failure, "Failed settings save must retain old project bytes.")
	var installers_restored: bool = ProjectSettings.get_setting("gf/project/installers") == before_installers
	main_scene = ProjectSettings.get_setting("application/run/main_scene")
	_check(installers_restored, "Failed settings save must restore Installer values.")
	_check(main_scene == "res://second_example/bootstrap.tscn", "Failed settings save must restore main scene.")
	_exercise_recovery_dock(failure)
	_exercise_deleted_scripts()
	for path: String in failure["paths"]:
		_check(not FileAccess.file_exists(path), "Compensation must remove only generated files: " + path)
	var fresh_after_failure: Dictionary = _GENERATOR_SCRIPT.get_plan("res://retry_example", "FailureSmoke")
	var fresh_ok: bool = fresh_after_failure["ok"]
	_check(fresh_ok, "A compensated attempt must release class reservations.")
	var stale: Dictionary = _GENERATOR_SCRIPT.get_plan("res://stale_example", "StaleSmoke")
	ProjectSettings.set_setting("gf/project/installers", [])
	var stale_signature: String = stale["signature"]
	var stale_result: Dictionary = _GENERATOR_SCRIPT.create("res://stale_example", "StaleSmoke", false, stale_signature)
	var stale_ok: bool = stale_result["ok"]
	_check(not stale_ok, "Changed project settings must invalidate the preview.")
	_check(not FileAccess.file_exists("res://stale_example/bootstrap.tscn"), "Stale preview must not create files.")
	ProjectSettings.set_setting("gf/project/installers", before_installers)
	var first_hash: String = FileAccess.get_sha256("res://game/bootstrap/counter_model.gd")
	var repeated: Dictionary = _GENERATOR_SCRIPT.create("res://game/bootstrap", "ThirdSmoke")
	var repeated_ok: bool = repeated["ok"]
	_check(not repeated_ok, "Existing files must not be overwritten.")
	_check(FileAccess.get_sha256("res://game/bootstrap/counter_model.gd") == first_hash, "A conflict must preserve original file bytes.")
	ProjectSettings.set_setting("gf/project/installers", PackedStringArray())
	ProjectSettings.set_setting("application/run/main_scene", null)
	var empty_project: Dictionary = _GENERATOR_SCRIPT.create("res://empty_example", "EmptySmoke")
	var empty_ok: bool = empty_project["ok"]
	appended_installers = ProjectSettings.get_setting("gf/project/installers")
	_check(empty_ok, "A project without Installers or a main scene must generate successfully.")
	_check(appended_installers == PackedStringArray(["res://empty_example/game_installer.gd"]), "An empty project must register exactly its new Installer.")
	_check(not ProjectSettings.has_setting("application/run/main_scene"), "Default creation must leave an absent main scene absent.")
	ProjectSettings.set_setting("gf/project/installers", before_installers)
	ProjectSettings.set_setting("application/run/main_scene", "res://second_example/bootstrap.tscn")
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray())
	_check(ProjectSettings.save() == OK, "The isolated smoke plugin must be disabled before runtime import.")
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	if not _failed:
		print("GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_OK " + JSON.stringify({"assertions": _assertions, "native_private_directories_verified": true, "default_preserves_main_and_installers": true, "settings_failure_compensated": true, "create_only_and_preview_stale": true, "empty_project_created": true, "retired_callbacks_rejected": true, "recovery_ui_preserved": true, "deleted_script_reservations_released": true}))
	get_tree().call_deferred(&"quit", 1 if _failed else 0)


func _press(node: Node, text: String) -> void:
	var button: Button = _find_button(node, text)
	_check(button != null and not button.disabled, "Action must be enabled: " + text)
	if button != null and not button.disabled:
		button.pressed.emit()


func _exercise_retired_dock() -> void:
	var dock: _DOCK_SCRIPT = _DOCK_SCRIPT.new()
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	EditorInterface.get_base_control().add_child(dock)
	var directory: LineEdit = dock.find_child("OutputDirectory", true, false)
	var prefix: LineEdit = dock.find_child("ClassPrefix", true, false)
	directory.text = "res://retired_example"
	prefix.text = "RetiredSmoke"
	_press(dock, "预览创建计划")
	var old_preview: Button = _find_button(dock, "预览创建计划")
	var old_create: Button = _find_button(dock, "创建最小项目")
	_check(not old_create.disabled, "A live preview must enable creation before retirement.")
	var before_hash: String = FileAccess.get_sha256("res://project.godot")
	var before_installers: Variant = ProjectSettings.get_setting("gf/project/installers")
	dock.set_editor_context(null)
	old_create.pressed.emit()
	old_preview.pressed.emit()
	old_create.pressed.emit()
	var task_ok: bool = dock.run_workspace_task("new_project")["ok"]
	_check(not task_ok, "A revoked workspace page must reject task dispatch.")
	_check(not FileAccess.file_exists("res://retired_example/bootstrap.tscn"), "Revoked buttons must never create files while still attached.")
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	_press(dock, "预览创建计划")
	_check(not old_create.disabled, "A renewed live context must allow a fresh preview before detachment.")
	dock.get_parent().remove_child(dock)
	old_preview.pressed.emit()
	old_create.pressed.emit()
	task_ok = dock.run_workspace_task("new_project")["ok"]
	_check(not task_ok, "A detached workspace page must reject task dispatch.")
	_check(not FileAccess.file_exists("res://retired_example/bootstrap.tscn"), "Detached buttons must never create files.")
	_check(FileAccess.get_sha256("res://project.godot") == before_hash, "Retired callbacks must preserve saved settings.")
	var installers_unchanged: bool = ProjectSettings.get_setting("gf/project/installers") == before_installers
	_check(installers_unchanged, "Retired callbacks must preserve live Installer settings.")
	dock.free()


func _find_button(node: Node, text: String) -> Button:
	if node is Button:
		var button: Button = node
		if button.text == text:
			return button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _exercise_recovery_dock(failure_report: Dictionary) -> void:
	var dock: _DOCK_SCRIPT = _DOCK_SCRIPT.new()
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	EditorInterface.get_base_control().add_child(dock)
	# 只注入 UI 的恢复报告；保存失败补偿本身由上面的真实事务覆盖，不增加产品测试入口。
	var report: Dictionary = failure_report.duplicate(true)
	report["recovery_required"] = true
	report["rolled_back"] = false
	report["status"] = "recovery_required"
	dock.set("_last_report", report)
	var _shown: Variant = dock.call(&"_show_report", report)
	dock.set_editor_context(GFEditorToolContext.from_plugin(self))
	var directory: LineEdit = dock.find_child("OutputDirectory", true, false)
	var prefix: LineEdit = dock.find_child("ClassPrefix", true, false)
	var main_scene: CheckBox = dock.find_child("SetMainScene", true, false)
	var details: RichTextLabel = dock.find_child("CreationDetails", true, false)
	var preserved_text: String = details.text
	var before_hash: String = FileAccess.get_sha256("res://project.godot")
	_check(not directory.editable and not prefix.editable and main_scene.disabled, "Recovery must lock all creation inputs.")
	directory.text = "res://recovery_ui_example"
	prefix.text = "RecoveryUiSmoke"
	directory.text_changed.emit(directory.text)
	main_scene.toggled.emit(false)
	_find_button(dock, "预览创建计划").pressed.emit()
	_find_button(dock, "创建最小项目").pressed.emit()
	_check(details.text == preserved_text and details.text.contains("需要检查并恢复"), "Queued input signals must preserve recovery instructions.")
	_check(not FileAccess.file_exists("res://recovery_ui_example/bootstrap.tscn"), "Recovery callbacks must never create files.")
	_check(FileAccess.get_sha256("res://project.godot") == before_hash, "Recovery callbacks must never save settings.")
	dock.free()


func _exercise_deleted_scripts() -> void:
	var installers: Variant = ProjectSettings.get_setting("gf/project/installers")
	var report: Dictionary = _GENERATOR_SCRIPT.create("res://deleted_example", "DeletedSmoke")
	var created: bool = report["ok"]
	_check(created, "The script-reservation sample must be created.")
	ProjectSettings.set_setting("gf/project/installers", installers)
	_check(ProjectSettings.save() == OK, "Removed sample settings must no longer reference its scripts.")
	for path: String in report["paths"]:
		_check(DirAccess.remove_absolute(path) == OK, "Remove only this isolated sample file: " + path)
	var fresh: Dictionary = _GENERATOR_SCRIPT.get_plan("res://deleted_retry", "DeletedSmoke")
	var available: bool = fresh["ok"]
	_check(available, "Deleting generated scripts must release pending class-name reservations even if their directory remains.")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		push_error("GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_FAILED: " + message)
