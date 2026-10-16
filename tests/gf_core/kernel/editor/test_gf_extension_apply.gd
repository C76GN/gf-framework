@tool

# 保存与应用必须分别成功；报告跟随根宿主而不是短生命周期页面。
extends GutTest


# --- 常量 ---

const APPLY_REPORT = preload("res://addons/gf/kernel/editor/gf_plugin_apply_report.gd")
const PLUGIN_ACTIONS = preload("res://addons/gf/kernel/editor/gf_plugin_actions.gd")
const PRESET_PATH: String = "res://tests/gf_core/kernel/editor/fixtures/save_apply_preset.json"
const TEMPLATE_ACTION_PATH: String = "res://tests/gf_core/kernel/editor/fixtures/gf_template_type_action.gd"


# --- 私有变量 ---

var _settings: Dictionary = {}
var _docks: Array[SaveProbe] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property.get("name", ""))
		if setting_name.begins_with("gf/extensions/"):
			_settings[setting_name] = ProjectSettings.get_setting(setting_name)


func after_each() -> void:
	for dock: SaveProbe in _docks:
		if is_instance_valid(dock):
			dock.free()
	_docks.clear()
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property.get("name", ""))
		if setting_name.begins_with("gf/extensions/"):
			ProjectSettings.set_setting(
				setting_name,
				_settings.get(setting_name)
			)
	_settings.clear()
	await get_tree().process_frame


# --- 测试用例 ---

func test_save_failure_keeps_draft_and_never_requests_application() -> void:
	var host: HostProbe = HostProbe.new()
	var dock: SaveProbe = _new_dock(host)
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock.save_error = ERR_CANT_CREATE
	dock._save_and_apply()
	assert_eq(host.requests, 0)
	assert_eq(dock.saves, 1)
	assert_true(dock.has_unsaved_workspace_changes())
	assert_string_contains(dock._status_label.text, "保存失败")


func test_save_only_then_apply_reports_pending_until_host_finishes() -> void:
	var host: HostProbe = HostProbe.new()
	var dock: SaveProbe = _new_dock(host)
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock._apply_selection()
	assert_eq(host.requests, 0)
	assert_false(dock.has_unsaved_workspace_changes())
	dock._save_and_apply()
	assert_eq(host.requests, 1)
	assert_string_contains(dock._apply_status_label.text, "待应用")
	host.report = {
		"status": "partial",
		"generation": 1,
		"issues": ["broken_plugin"],
	}
	dock._update_apply_status()
	assert_string_contains(dock._apply_status_label.text, "部分应用")
	assert_string_contains(dock._apply_status_label.text, "broken_plugin")
	var recreated: SaveProbe = _new_dock(host)
	assert_string_contains(recreated._apply_status_label.text, "部分应用")
	host.report = {
		"status": "failed",
		"generation": 1,
		"issues": ["scan_timeout"],
	}
	recreated._update_apply_status()
	assert_string_contains(recreated._apply_status_label.text, "应用失败")


func test_revoked_context_cannot_save_or_apply_but_keeps_draft() -> void:
	var host: HostProbe = HostProbe.new()
	var dock: SaveProbe = _new_dock(host)
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock.set_editor_context(null)
	dock._apply_selection()
	dock._save_and_apply()
	assert_true(dock.has_unsaved_workspace_changes())
	assert_true(dock._save_button.disabled)
	assert_true(dock._save_apply_button.disabled)
	assert_eq(dock.saves, 0)
	assert_eq(host.requests, 0)


func test_preset_paths_are_drafts_until_saved_and_revocation_rejects_late_dialog() -> void:
	GFExtensionSettings.set_extension_preset_paths([])
	var host: HostProbe = HostProbe.new()
	var dock: SaveProbe = _new_dock(host)
	await get_tree().process_frame
	assert_true(dock._add_extension_preset_path(PRESET_PATH))
	assert_true(dock.has_unsaved_workspace_changes())
	assert_true(GFExtensionSettings.get_extension_preset_paths().is_empty())
	assert_true(dock._save_selection())
	assert_eq(
		GFExtensionSettings.get_extension_preset_paths(),
		[PRESET_PATH]
	)
	for index: int in range(dock._preset_option.item_count):
		if str(dock._preset_option.get_item_metadata(index)) == "project.apply_test":
			dock._preset_option.select(index)
	assert_true(dock._remove_selected_preset_path())
	assert_true(dock.has_unsaved_workspace_changes())
	assert_eq(
		GFExtensionSettings.get_extension_preset_paths(),
		[PRESET_PATH]
	)
	dock._ensure_preset_file_dialog()
	dock.set_editor_context(null)
	dock._preset_file_dialog.file_selected.emit(PRESET_PATH)
	assert_true(
		dock._preset_paths.is_empty(),
		"撤销前打开的选择器不能再提交草稿。"
	)
	assert_false(dock._add_extension_preset_path(PRESET_PATH))
	assert_false(dock._remove_selected_preset_path())
	assert_false(dock._save_selection())
	assert_eq(
		GFExtensionSettings.get_extension_preset_paths(),
		[PRESET_PATH]
	)
	assert_true(dock.has_unsaved_workspace_changes())
	var restored: GFEditorToolContext = GFEditorToolContext.new()
	restored.bind_contribution_refresh_host(host)
	dock.set_editor_context(restored)
	assert_true(dock._save_selection())
	assert_true(GFExtensionSettings.get_extension_preset_paths().is_empty())


func test_settings_changed_during_scan_cannot_claim_applied() -> void:
	var report: APPLY_REPORT = APPLY_REPORT.new()
	var first: Dictionary = {
		"enabled": ["dialogue"],
	}
	var second: Dictionary = {
		"enabled": ["save"],
	}
	report.request(1, first)
	assert_false(report.accepts(1, second))
	report.fail(1, "settings_changed_before_apply")
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(first),
			"status"
		),
		"failed"
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(second),
			"status"
		),
		"pending"
	)
	assert_eq(
		GFVariantData.get_option_dictionary(
			report.get_report(second),
			"installed_settings"
		),
		{}
	)


func test_late_completion_does_not_overwrite_new_request_and_result_is_detached() -> void:
	var report: APPLY_REPORT = APPLY_REPORT.new()
	var first: Dictionary = {
		"enabled": ["dialogue"],
	}
	var second: Dictionary = {
		"enabled": ["save"],
	}
	report.request(1, first)
	report.request(2, second)
	report.complete(
		1,
		first,
		[]
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(second),
			"status"
		),
		"pending"
	)
	assert_eq(
		GFVariantData.get_option_int(
			report.get_report(second),
			"generation"
		),
		2
	)
	report.complete(
		2,
		second,
		["import:load_failed"]
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(second),
			"status"
		),
		"partial"
	)
	var detached: Dictionary = report.get_report(second)
	detached["status"] = "applied"
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(second),
			"status"
		),
		"partial"
	)
	report.request(3, second)
	report.complete(
		3,
		second,
		[]
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report(second),
			"status"
		),
		"applied"
	)


func test_context_revocation_removes_refresh_authority() -> void:
	var context: GFEditorToolContext = GFEditorToolContext.new()
	var host: HostProbe = HostProbe.new()
	context.bind_contribution_refresh_host(host)
	var accepted: Dictionary = context.request_editor_contribution_refresh()
	assert_eq(
		GFVariantData.get_option_string(accepted, "status"),
		"pending"
	)
	context.bind_contribution_refresh_host(null)
	var refused: Dictionary = context.request_editor_contribution_refresh()
	assert_eq(
		GFVariantData.get_option_string(refused, "status"),
		"failed"
	)
	assert_eq(host.requests, 1)


func test_rejected_action_items_produce_partial_application_evidence() -> void:
	var actions: PLUGIN_ACTIONS = PLUGIN_ACTIONS.new()
	var provider: InvalidProvider = InvalidProvider.new()
	var _templates: Variant = actions.call(
		"_register_extension_template_records",
		provider,
		"provider.gd"
	)
	var _settings_result: Variant = actions.call(
		"_register_extension_project_setting_records",
		provider,
		"provider.gd"
	)
	var _sections: Variant = actions.call(
		"_register_extension_project_setting_section_records",
		provider,
		"provider.gd"
	)
	var issues: Array[String] = actions.get_setup_issues()
	assert_eq(
		issues.size(),
		5,
		"逐项非法声明不能静默省略。"
	)
	var report: APPLY_REPORT = APPLY_REPORT.new()
	report.request(1, {})
	report.complete(
		1,
		{},
		issues
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report({}),
			"status"
		),
		"partial"
	)
	actions.cleanup()


func test_enabled_action_templates_with_missing_or_blank_type_report_partial_application() -> void:
	var actions: PLUGIN_ACTIONS = PLUGIN_ACTIONS.new()
	var dependencies: TemplateActionDependencies = TemplateActionDependencies.new()
	dependencies.action_paths = [TEMPLATE_ACTION_PATH]
	actions.setup([], dependencies)
	var issues: Array[String] = actions.get_setup_issues()
	var expected_issues: Array[String] = [
		"template:type_empty:gf.test.editor:template.type_missing",
		"template:type_empty:gf.test.editor:template.type_empty",
		"template:type_empty:gf.test.editor:template.type_whitespace",
	]
	assert_eq(
		issues,
		expected_issues,
		"缺失、空和空白 type 必须按来源记录稳定失败原因。"
	)
	var menu_labels: Array[String] = []
	for entry: Dictionary in actions.get_menu_entries():
		menu_labels.append(GFVariantData.get_option_string(entry, "label"))
	assert_has(
		menu_labels,
		"合法扩展模板",
		"同一启用动作中的合法模板仍应注册。"
	)
	assert_does_not_have(menu_labels, "缺少类型模板")
	assert_does_not_have(menu_labels, "空类型模板")
	assert_does_not_have(menu_labels, "空白类型模板")
	var report: APPLY_REPORT = APPLY_REPORT.new()
	report.request(1, {})
	report.complete(
		1,
		{},
		issues
	)
	var apply_result: Dictionary = report.get_report({})
	assert_eq(
		GFVariantData.get_option_string(apply_result, "status"),
		"partial",
		"跳过无效模板时不能宣称全部应用。"
	)
	var reported_issues: Array = GFVariantData.get_option_array(apply_result, "issues")
	assert_eq(reported_issues, expected_issues)
	actions.cleanup()


func test_valid_action_template_records_can_report_applied() -> void:
	var actions: PLUGIN_ACTIONS = PLUGIN_ACTIONS.new()
	var dependencies: TemplateActionDependencies = TemplateActionDependencies.new()
	actions.setup(
		[
			{
				"source_id": "gf.test.editor:template.valid",
				"type": "System",
				"label": "合法独立模板",
			},
		],
		dependencies
	)
	var issues: Array[String] = actions.get_setup_issues()
	assert_true(
		issues.is_empty(),
		"合法模板不应被错误记录为部分失败。"
	)
	var menu_labels: Array[String] = []
	for entry: Dictionary in actions.get_menu_entries():
		menu_labels.append(GFVariantData.get_option_string(entry, "label"))
	assert_has(menu_labels, "合法独立模板")
	var report: APPLY_REPORT = APPLY_REPORT.new()
	report.request(1, {})
	report.complete(
		1,
		{},
		issues
	)
	assert_eq(
		GFVariantData.get_option_string(
			report.get_report({}),
			"status"
		),
		"applied"
	)
	actions.cleanup()


# --- 私有/辅助方法 ---

func _new_dock(host: HostProbe) -> SaveProbe:
	var dock: SaveProbe = SaveProbe.new()
	_docks.append(dock)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.bind_contribution_refresh_host(host)
	dock.set_editor_context(context)
	add_child(dock)
	return dock


# --- 内部类 ---

class TemplateActionDependencies extends RefCounted:
	var action_paths: Array[String] = []

	func get_enabled_editor_action_paths() -> Array[String]:
		return action_paths.duplicate()


class InvalidProvider extends RefCounted:
	func get_template_records() -> Array:
		return [42]


	func get_project_setting_records() -> Array:
		return [
			42,
			{ "name": "" },
		]


	func get_project_setting_section_records() -> Array:
		return [
			42,
			{ "path": "" },
		]


class HostProbe extends RefCounted:
	var requests: int = 0
	var report: Dictionary = {
		"status": "pending",
		"generation": 0,
		"issues": [],
	}

	func request_editor_contribution_refresh() -> Dictionary:
		requests += 1
		report["generation"] = requests
		return report


	func get_editor_contribution_apply_report() -> Dictionary:
		return report


class SaveProbe extends "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd":
	var saves: int = 0
	var save_error: Error = OK

	func _save_project_settings() -> Error:
		saves += 1
		return save_error
