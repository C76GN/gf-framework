# 空项目初始化的只读计划、设置准入与模板边界。实际写入和启动由隔离编辑器验收覆盖。
extends GutTest


# --- 常量 ---

const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")
const _TEMPLATES_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_templates.gd")
const _GF_AUTOLOAD_PATH: String = "res://addons/gf/kernel/core/gf.gd"


# --- 私有变量 ---

var _settings_before: Dictionary = {}


# --- 公共方法 ---

func before_each() -> void:
	for key: String in ["gf/project/installers", "application/run/main_scene", "autoload/Gf"]:
		_settings_before[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key, null)}
	ProjectSettings.set_setting("gf/project/installers", null)
	ProjectSettings.set_setting("application/run/main_scene", null)
	ProjectSettings.set_setting("autoload/Gf", "*" + _GF_AUTOLOAD_PATH)


func after_each() -> void:
	for key: String in _settings_before:
		var snapshot: Dictionary = _settings_before[key]
		ProjectSettings.set_setting(key, snapshot["value"] if snapshot["exists"] else null)
	_settings_before.clear()
	_GENERATOR_SCRIPT.configure_test_save_error(OK)


func test_default_template_is_empty_project_without_counter_business() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://app")
	assert_false(files.has("counter_model.gd"))
	assert_false(files.has("counter_system.gd"))
	assert_eq(files.size(), 4)
	for file_name: String in ["boot.gd", "boot.tscn", "main.tscn", "project_installer.gd"]:
		assert_true(files.has(file_name), file_name)
	assert_false(files.has("README.md"))


func test_default_plan_initializes_empty_project_without_writing() -> void:
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
	_assert_plan_ok(plan)
	var paths: PackedStringArray = plan["paths"]
	assert_eq(paths.size(), 4)
	var scene_path: String = plan["scene_path"]
	var main_scene_path: String = plan["main_scene_path"]
	var installer_path: String = plan["installer_path"]
	assert_eq(scene_path, "res://app/boot.tscn")
	assert_eq(main_scene_path, "res://app/main.tscn")
	assert_eq(installer_path, "res://app/project_installer.gd")
	var after: Dictionary = plan["settings_after"]
	var planned_main: String = after["application/run/main_scene"]
	var planned_installers: Array = after["gf/project/installers"]
	assert_eq(planned_main, scene_path)
	assert_eq(planned_installers, [installer_path])
	assert_false(ProjectSettings.has_setting("application/run/main_scene"))
	assert_false(ProjectSettings.has_setting("gf/project/installers"))
	assert_eq(FileAccess.get_sha256("res://project.godot"), disk_before)
	for path: String in paths:
		assert_false(FileAccess.file_exists(path))


func test_plan_exposes_normalized_options_and_template_identity() -> void:
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
	_assert_plan_ok(plan)
	var options: Dictionary = plan["options"]
	var mode: String = plan["mode"]
	var status: String = plan["status"]
	var template_id: String = plan["template_id"]
	var template_version: int = plan["template_version"]
	var guidance_only: bool = plan["guidance_only"]
	assert_eq(options, {"mode": "new_project", "create_installer": true, "include_readme": false})
	assert_eq(mode, "new_project")
	assert_eq(status, "planned")
	assert_eq(template_id, "gf.empty_project")
	assert_eq(template_version, 1)
	assert_false(guidance_only)


func test_new_project_rejects_existing_main_or_installers_without_changing_them() -> void:
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")
	var main_ok: bool = _GENERATOR_SCRIPT.get_plan()["ok"]
	assert_false(main_ok)
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(main_scene, "res://existing.tscn")
	ProjectSettings.set_setting("application/run/main_scene", null)
	ProjectSettings.set_setting("gf/project/installers", PackedStringArray(["res://one.gd"]))
	var installer_ok: bool = _GENERATOR_SCRIPT.get_plan()["ok"]
	assert_false(installer_ok)
	var installers: PackedStringArray = ProjectSettings.get_setting("gf/project/installers")
	assert_eq(installers, PackedStringArray(["res://one.gd"]))


func test_new_project_accepts_empty_present_settings_and_preserves_snapshot_identity() -> void:
	ProjectSettings.set_setting("application/run/main_scene", "")
	ProjectSettings.set_setting("gf/project/installers", PackedStringArray())
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan()
	_assert_plan_ok(plan)
	var before: Dictionary = plan["settings_before"]
	var main_before: Dictionary = before["application/run/main_scene"]
	var installers_before: Dictionary = before["gf/project/installers"]
	assert_eq(main_before, {"exists": true, "value": ""})
	assert_eq(installers_before, {"exists": true, "value": PackedStringArray()})
	var after: Dictionary = plan["settings_after"]
	assert_true(after["gf/project/installers"] is PackedStringArray)


func test_existing_project_preserves_main_and_appends_only_empty_installer() -> void:
	_seed_existing_project()
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://integration", {"mode": "existing_project"})
	_assert_plan_ok(plan)
	var paths: PackedStringArray = plan["paths"]
	var scene_path: String = plan["scene_path"]
	var main_scene_path: String = plan["main_scene_path"]
	var snippet: String = plan["integration_snippet"]
	assert_eq(paths, PackedStringArray(["res://integration/project_installer.gd"]))
	assert_eq(scene_path, "")
	assert_eq(main_scene_path, "res://existing.tscn")
	assert_true(snippet.contains("await Gf.init()"))
	var after: Dictionary = plan["settings_after"]
	assert_false(after.has("application/run/main_scene"))
	assert_false(after.has("autoload/Gf"))
	var planned: PackedStringArray = after["gf/project/installers"]
	assert_eq(planned, PackedStringArray(["res://one.gd", "res://two.gd", "res://integration/project_installer.gd"]))
	var actual: PackedStringArray = ProjectSettings.get_setting("gf/project/installers")
	assert_eq(actual, PackedStringArray(["res://one.gd", "res://two.gd"]))


func test_array_installer_type_and_existing_order_are_preserved() -> void:
	var existing: Array = [&"res://one.gd", "uid://b123", "res://two.gd"]
	ProjectSettings.set_setting("gf/project/installers", existing)
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://integration", {"mode": "existing_project"})
	_assert_plan_ok(plan)
	var after: Dictionary = plan["settings_after"]
	var planned: Array = after["gf/project/installers"]
	assert_eq(planned, [&"res://one.gd", "uid://b123", "res://two.gd", "res://integration/project_installer.gd"])
	assert_eq(existing.size(), 3)


func test_guidance_only_plan_has_no_files_or_setting_changes() -> void:
	_seed_existing_project()
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://integration", {"mode": "existing_project", "create_installer": false})
	_assert_plan_ok(plan)
	var paths: PackedStringArray = plan["paths"]
	var after: Dictionary = plan["settings_after"]
	var entries: Array = plan["entries"]
	var guidance_only: bool = plan["guidance_only"]
	var status: String = plan["status"]
	var installer_path: String = plan["installer_path"]
	assert_true(guidance_only)
	assert_eq(status, "guidance_only")
	assert_true(paths.is_empty())
	assert_true(entries.is_empty())
	assert_true(after.is_empty())
	assert_eq(installer_path, "")


func test_readme_only_plan_does_not_save_project_settings() -> void:
	_seed_existing_project()
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://integration", {"mode": "existing_project", "create_installer": false, "include_readme": true})
	_assert_plan_ok(plan)
	var paths: PackedStringArray = plan["paths"]
	var after: Dictionary = plan["settings_after"]
	var guidance_only: bool = plan["guidance_only"]
	assert_eq(paths, PackedStringArray(["res://integration/README.md"]))
	assert_true(after.is_empty())
	assert_false(guidance_only)


func test_optional_installer_and_readme_change_only_selected_output() -> void:
	var options: Dictionary = {"create_installer": false, "include_readme": true}
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan("res://custom", options)
	_assert_plan_ok(plan)
	var paths: PackedStringArray = plan["paths"]
	var after: Dictionary = plan["settings_after"]
	assert_eq(paths.size(), 4)
	assert_true(paths.has("res://custom/README.md"))
	assert_false(paths.has("res://custom/project_installer.gd"))
	assert_false(after.has("gf/project/installers"))
	assert_eq(options, {"create_installer": false, "include_readme": true})


func test_invalid_or_unknown_options_are_rejected() -> void:
	for options: Dictionary in [{"mode": "demo"}, {"mode": 1}, {"create_installer": "yes"}, {"include_readme": 1}, {"set_main_scene": true}, {"class_prefix": "Game"}]:
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan("res://app", options)["ok"]
		assert_false(plan_ok, str(options))


func test_invalid_installer_config_is_rejected_without_repairing_it() -> void:
	for value: Variant in ["res://one.gd", [1], {"path": "res://one.gd"}]:
		ProjectSettings.set_setting("gf/project/installers", value)
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan("res://app", {"mode": "existing_project"})["ok"]
		var preserved: bool = ProjectSettings.get_setting("gf/project/installers") == value
		assert_false(plan_ok)
		assert_true(preserved)


func test_unsafe_and_framework_directories_are_rejected() -> void:
	for path: String in ["res://", "user://app", "res://../app", "res://addons/gf/app", "res://.godot/app", "res://bad\"/app", "res://one//two", "res://one\\two"]:
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan(path)["ok"]
		assert_false(plan_ok, path)


func test_registered_installer_target_is_not_duplicated() -> void:
	ProjectSettings.set_setting("gf/project/installers", ["res://app/project_installer.gd"])
	var plan_ok: bool = _GENERATOR_SCRIPT.get_plan("res://app", {"mode": "existing_project"})["ok"]
	var installers: Array = ProjectSettings.get_setting("gf/project/installers")
	assert_false(plan_ok)
	assert_eq(installers, ["res://app/project_installer.gd"])


func test_preview_signature_tracks_options_and_raw_setting_existence() -> void:
	var first_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	var repeated_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	assert_eq(first_signature, repeated_signature)
	ProjectSettings.set_setting("gf/project/installers", [])
	var present_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	assert_ne(first_signature, present_signature)
	var readme_signature: String = _GENERATOR_SCRIPT.get_plan("res://app", {"include_readme": true})["signature"]
	assert_ne(present_signature, readme_signature)
	ProjectSettings.set_setting("application/run/main_scene", "")
	var empty_main_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	assert_ne(present_signature, empty_main_signature)


func test_existing_guidance_signature_tracks_preserved_main_scene() -> void:
	_seed_existing_project()
	var options: Dictionary = {"mode": "existing_project", "create_installer": false}
	var first_signature: String = _GENERATOR_SCRIPT.get_plan("res://integration", options)["signature"]
	ProjectSettings.set_setting("application/run/main_scene", "res://other.tscn")
	var second_signature: String = _GENERATOR_SCRIPT.get_plan("res://integration", options)["signature"]
	assert_ne(first_signature, second_signature)


func test_plan_rejects_missing_conflicting_or_disabled_gf_autoload_without_repair() -> void:
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	for value: Variant in [null, "", "*res://project_conflicting_autoload.gd", _GF_AUTOLOAD_PATH, "*uid://invalid", 123]:
		ProjectSettings.set_setting("autoload/Gf", value)
		var plan_ok: bool = _GENERATOR_SCRIPT.get_plan()["ok"]
		assert_false(plan_ok, str(value))
		var current_value: Variant = ProjectSettings.get_setting("autoload/Gf", null)
		var unchanged: bool = typeof(current_value) == typeof(value) and current_value == value
		assert_true(unchanged)
		assert_eq(FileAccess.get_sha256("res://project.godot"), disk_before)
		assert_false(FileAccess.file_exists("res://app/boot.tscn"))


func test_plan_accepts_enabled_canonical_path_and_uid_and_tracks_autoload_changes() -> void:
	var uid: int = ResourceLoader.get_resource_uid(_GF_AUTOLOAD_PATH)
	assert_ne(uid, ResourceUID.INVALID_ID)
	if uid == ResourceUID.INVALID_ID:
		return
	var disk_before: String = FileAccess.get_sha256("res://project.godot")
	var canonical: Dictionary = _GENERATOR_SCRIPT.get_plan()
	_assert_plan_ok(canonical)
	ProjectSettings.set_setting("autoload/Gf", "*" + ResourceUID.id_to_text(uid))
	var by_uid: Dictionary = _GENERATOR_SCRIPT.get_plan()
	_assert_plan_ok(by_uid)
	var canonical_signature: String = canonical["signature"]
	var uid_signature: String = by_uid["signature"]
	assert_ne(uid_signature, canonical_signature)
	ProjectSettings.set_setting("autoload/Gf", "*res://project_conflicting_autoload.gd")
	var conflicting_signature: String = _GENERATOR_SCRIPT.get_plan()["signature"]
	assert_ne(conflicting_signature, uid_signature)
	assert_eq(FileAccess.get_sha256("res://project.godot"), disk_before)


func test_templates_depend_only_on_kernel_without_global_types_or_business_modules() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://custom")
	for file_name: String in files:
		var content: String = files[file_name]
		assert_false(content.contains("class_name"), file_name)
		assert_false(content.contains("Counter"), file_name)
		assert_false(content.contains("addons/gf/tools/"), file_name)
		assert_false(content.contains("addons/gf/standard/"), file_name)
		assert_false(content.contains("addons/gf/extensions/"), file_name)
		assert_true(content.ends_with("\n"), file_name)
	var installer: String = files["project_installer.gd"]
	assert_true(installer.contains("extends GFInstaller"))
	assert_false(installer.contains("register_model"))
	assert_false(installer.contains("register_system"))
	var boot: String = files["boot.gd"]
	assert_true(boot.contains("await Gf.init()"))
	assert_false(boot.contains(".dispose("))
	var main_scene: String = files["main.tscn"]
	assert_false(main_scene.contains("ext_resource"))
	assert_false(main_scene.contains("Button"))


func test_existing_template_is_only_selected_project_owned_files() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://integration", {"mode": "existing_project", "create_installer": true, "include_readme": true})
	assert_eq(files.size(), 2)
	assert_true(files.has("project_installer.gd"))
	assert_true(files.has("README.md"))
	assert_false(files.has("boot.gd"))
	assert_false(files.has("boot.tscn"))
	assert_false(files.has("main.tscn"))
	var guidance: Dictionary = _TEMPLATES_SCRIPT.render("res://integration", {"mode": "existing_project", "create_installer": false})
	assert_true(guidance.is_empty())


func test_template_substitution_does_not_reinterpret_directory_tokens() -> void:
	var files: Dictionary = _TEMPLATES_SCRIPT.render("res://literal__ROOT__")
	var boot_scene: String = files["boot.tscn"]
	var boot_script: String = files["boot.gd"]
	assert_true(boot_scene.contains("res://literal__ROOT__/boot.gd"))
	assert_true(boot_script.contains("res://literal__ROOT__/main.tscn"))


func test_package_and_task_identity_remain_compatible() -> void:
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


# --- 私有/辅助方法 ---

func _seed_existing_project() -> void:
	ProjectSettings.set_setting("gf/project/installers", PackedStringArray(["res://one.gd", "res://two.gd"]))
	ProjectSettings.set_setting("application/run/main_scene", "res://existing.tscn")


func _assert_plan_ok(plan: Dictionary) -> void:
	var plan_ok: bool = plan["ok"]
	assert_true(plan_ok, str(plan["issues"]))
