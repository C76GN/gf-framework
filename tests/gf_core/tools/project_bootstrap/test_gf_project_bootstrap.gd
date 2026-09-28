# 最小项目的只读计划、类型/路径准入与模板边界。实际写入和运行由隔离编辑器验收覆盖。
extends GutTest


# --- 常量 ---

const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")
const _TEMPLATES_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_templates.gd")


# --- 私有变量 ---

var _installers_existed: bool = false
var _installers: Variant = null
var _main_existed: bool = false
var _main_scene: Variant = null


# --- 公共方法 ---

func before_each() -> void:
	_installers_existed = ProjectSettings.has_setting("gf/project/installers")
	_installers = ProjectSettings.get_setting("gf/project/installers", null)
	_main_existed = ProjectSettings.has_setting("application/run/main_scene")
	_main_scene = ProjectSettings.get_setting("application/run/main_scene", null)
	ProjectSettings.set_setting("gf/project/installers", PackedStringArray(["res://existing_installer.gd"]))
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")


func after_each() -> void:
	ProjectSettings.set_setting("gf/project/installers", _installers if _installers_existed else null)
	ProjectSettings.set_setting("application/run/main_scene", _main_scene if _main_existed else null)
	_GENERATOR_SCRIPT.configure_test_save_error(OK)


func test_default_plan_is_create_only_and_preserves_main_scene() -> void:
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
	var plan_ok: bool = plan["ok"]
	assert_true(plan_ok, str(plan["issues"]))
	var paths: PackedStringArray = plan["paths"]
	assert_eq(paths.size(), 6)
	var scene_path: String = plan["scene_path"]
	assert_eq(scene_path, "res://game/bootstrap/bootstrap.tscn")
	var after: Dictionary = plan["settings_after"]
	assert_false(after.has("application/run/main_scene"))
	var planned_installers: PackedStringArray = after["gf/project/installers"]
	var current_installers: PackedStringArray = ProjectSettings.get_setting("gf/project/installers")
	assert_eq(planned_installers, PackedStringArray(["res://existing_installer.gd", "res://game/bootstrap/game_installer.gd"]))
	assert_eq(current_installers, PackedStringArray(["res://existing_installer.gd"]))
	assert_eq(FileAccess.get_sha256("res://project.godot"), disk_before)
	for path: String in paths:
		assert_false(FileAccess.file_exists(path))


func test_explicit_main_scene_and_custom_names_are_in_preview() -> void:
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://custom/demo", "CustomDemo", true)
	var plan_ok: bool = plan["ok"]
	var classes: Array = plan["classes"]
	assert_true(plan_ok, str(plan["issues"]))
	assert_eq(classes, ["CustomDemoCounterModel", "CustomDemoCounterSystem", "CustomDemoInstaller"])
	var after: Dictionary = plan["settings_after"]
	var planned_main_scene: String = after["application/run/main_scene"]
	var current_main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(planned_main_scene, "res://custom/demo/bootstrap.tscn")
	assert_eq(current_main_scene, "res://existing.tscn")


func test_array_installer_type_and_existing_order_are_preserved() -> void:
	var existing: Array = [&"res://one.gd", "uid://b123", "res://two.gd"]
	ProjectSettings.set_setting("gf/project/installers", existing)
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
	var plan_ok: bool = plan["ok"]
	assert_true(plan_ok, str(plan["issues"]))
	var after: Dictionary = plan["settings_after"]
	var planned_installers: Array = after["gf/project/installers"]
	assert_eq(planned_installers, [&"res://one.gd", "uid://b123", "res://two.gd", "res://game/bootstrap/game_installer.gd"])
	assert_eq(existing.size(), 3)


func test_invalid_installer_config_is_rejected_without_repairing_it() -> void:
	for value: Variant in ["res://one.gd", [1], {"path": "res://one.gd"}]:
		ProjectSettings.set_setting("gf/project/installers", value)
		var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
		var plan_ok: bool = plan["ok"]
		var setting_preserved: bool = ProjectSettings.get_setting("gf/project/installers") == value
		assert_false(plan_ok)
		assert_true(setting_preserved)


func test_unsafe_and_framework_directories_are_rejected() -> void:
	for path: String in ["res://", "user://demo", "res://../demo", "res://addons/gf/demo", "res://.godot/demo", "res://bad\"/demo", "res://one//two", "res://one\\two"]:
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan(path)["ok"]
		assert_false(plan_ok, path)


func test_invalid_class_prefixes_are_rejected() -> void:
	for prefix: String in ["", "1Demo", "a-b", "A\nB", "A".repeat(49), "示例"]:
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan("res://game/bootstrap", prefix)["ok"]
		assert_false(plan_ok, prefix)


func test_registered_installer_target_is_not_duplicated() -> void:
	ProjectSettings.set_setting("gf/project/installers", ["res://game/bootstrap/game_installer.gd"])
	var plan_ok: bool = _GENERATOR_SCRIPT.get_plan()["ok"]
	var current_installers: Array = ProjectSettings.get_setting("gf/project/installers")
	assert_false(plan_ok)
	assert_eq(current_installers, ["res://game/bootstrap/game_installer.gd"])


func test_preview_signature_changes_with_relevant_settings_and_disk_baseline() -> void:
	var first: Dictionary = _GENERATOR_SCRIPT.get_plan()
	ProjectSettings.set_setting("gf/project/installers", [])
	var second: Dictionary = _GENERATOR_SCRIPT.get_plan()
	var first_signature: String = first["signature"]
	var second_signature: String = second["signature"]
	var repeated_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	assert_ne(first_signature, second_signature)
	assert_eq(repeated_signature, second_signature)


func test_templates_depend_only_on_kernel_and_use_actual_bootstrap_contract() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://my/demo", "Example")
	assert_eq(files.size(), 6)
	for file_name: String in files:
		var content: String = files[file_name]
		assert_false(content.contains("__ROOT__"))
		assert_false(content.contains("__PREFIX__"))
		assert_false(content.contains("addons/gf/tools/"))
		assert_false(content.contains("addons/gf/standard/"))
		assert_false(content.contains("addons/gf/extensions/"))
		assert_true(content.ends_with("\n"))
	var installer: String = files["game_installer.gd"]
	assert_true(installer.contains("await architecture.register_model_instance"))
	assert_true(installer.contains("scope.is_cancel_requested()"))
	var bootstrap: String = files["bootstrap.gd"]
	assert_true(bootstrap.contains("await Gf.init()"))
	assert_true(bootstrap.contains("count_changed.disconnect"))
	var system: String = files["counter_system.gd"]
	assert_true(system.contains("get_required_models() -> Array[Script]"))


func test_package_has_only_kernel_dependency_and_editor_contribution() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://packages/tools/gf.tool.project_bootstrap.json"))
	assert_true(value is Dictionary)
	if value is Dictionary:
		var package: Dictionary = value
		var dependencies: Array = package["dependencies"]
		assert_eq(dependencies, ["gf.kernel"])
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://addons/gf/tools/project_bootstrap/editor/gf_editor_contributions.json"))
	assert_true(manifest_value is Dictionary)
	if manifest_value is Dictionary:
		var manifest: Dictionary = manifest_value
		var schema_version: float = manifest["schema_version"]
		var package_id: String = manifest["package_id"]
		assert_eq(schema_version, 5.0)
		assert_eq(package_id, "gf.tool.project_bootstrap")
		var tasks: Array = manifest["task_records"]
		assert_eq(tasks.size(), 1)
		var task: Dictionary = tasks[0]
		var source_id: String = task["source_id"]
		var action_id: String = task["action_id"]
		var page_path: String = task["page_path"]
		assert_eq(source_id, "project_bootstrap.task.create")
		assert_eq(action_id, "new_project")
		assert_eq(page_path, "res://addons/gf/tools/project_bootstrap/editor/gf_project_bootstrap_dock.gd")


func test_template_substitution_never_reinterprets_tokens_in_user_values() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://literal__PREFIX__", "A__ROOT__")
	var system: String = files["counter_system.gd"]
	assert_true(system.contains("class_name A__ROOT__CounterSystem"))
	assert_true(system.contains("res://literal__PREFIX__/counter_model.gd"))
