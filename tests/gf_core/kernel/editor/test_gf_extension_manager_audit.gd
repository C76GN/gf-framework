@tool

# 扩展管理页面仅在用户要求时扫描引用，并明确区分未扫描、过期和不完整证据。
extends GutTest


# --- 常量 ---

const _EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

var _docks: Array[AuditProbe] = []
var _settings_restore: Dictionary = {}


# --- Godot 生命周期方法 ---

func before_each() -> void:
	for setting_path: String in [
		_EXTENSION_SETTINGS_SCRIPT.ENABLED_EXTENSIONS_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXPORT_EXCLUDE_DISABLED_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
	]:
		_settings_restore[setting_path] = {
			"exists": ProjectSettings.has_setting(setting_path),
			"value": ProjectSettings.get_setting(setting_path),
		}


func after_each() -> void:
	for dock: AuditProbe in _docks:
		if is_instance_valid(dock):
			dock.free()
	_docks.clear()
	for setting_path: String in _settings_restore:
		var raw_snapshot: Variant = _settings_restore[setting_path]
		if not (raw_snapshot is Dictionary):
			assert_true(false, "设置恢复快照必须是 Dictionary。")
			continue
		var snapshot: Dictionary = raw_snapshot
		var existed: Variant = snapshot.get("exists", false)
		if existed is bool and existed:
			ProjectSettings.set_setting(setting_path, snapshot["value"])
		else:
			ProjectSettings.set_setting(setting_path, null)
	_settings_restore.clear()
	await get_tree().process_frame


# --- 测试用例 ---

func test_open_refresh_selection_and_save_do_not_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	assert_eq(dock.audit_count, 0, "首次打开扩展列表不能同步扫描项目引用。")
	assert_true(dock._status_label.text.contains("未扫描"), "初次列表不能暗示禁用扩展已经通过审计。")
	dock._refresh_extensions()
	dock._set_all_enabled(true)
	dock._restore_default_selection()
	var preset_applied: bool = dock._apply_extension_preset_by_id(&"gf.none")
	assert_true(preset_applied)
	dock._on_extension_toggled(true, "gf.save")
	dock._apply_selection()
	assert_eq(dock.save_count, 1, "保存仍应写入设置。")
	assert_eq(dock.audit_count, 0, "刷新、组合、选择与保存必须保持按需审计。")
	assert_true(dock._status_label.text.contains("未扫描"), "保存成功不等同于引用审计成功。")


func test_scan_button_runs_once_and_search_preserves_report() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	var scan_button: Button = _find_button(dock, "扫描引用")
	assert_not_null(scan_button)
	if scan_button == null:
		return
	scan_button.pressed.emit()
	assert_eq(dock.audit_count, 1, "一次扫描按钮操作只生成一份报告。")
	assert_string_contains(dock._status_label.text, "扫描完成")
	assert_string_contains(dock._status_label.text, "未发现")
	dock._search_field.text = "save"
	dock._search_field.text_changed.emit("save")
	assert_eq(dock.audit_count, 1, "筛选扩展列表不能重新扫描项目。")
	assert_true(dock._status_label.text.contains("扫描完成"), "筛选列表不改变报告所依据的输入。")


func test_selection_marks_prior_report_stale_until_next_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	dock._on_extension_toggled(true, "gf.save")
	assert_eq(dock.audit_count, 1)
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(dock._status_label.text.contains("未发现"), "旧报告的零引用不能作为新选择的结论。")
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 2)
	assert_string_contains(dock._status_label.text, "扫描完成")


func test_partial_zero_reference_report_does_not_claim_complete() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock.next_report["partial_scan"] = true
	dock.next_report["ok"] = false
	dock._scan_disabled_extension_references()
	assert_string_contains(dock._status_label.text, "扫描不完整")
	assert_false(dock._status_label.text.contains("未发现"))
	assert_false(dock._status_label.text.contains("扫描完成"))
	assert_true(dock._details_output.text.contains("扫描不完整"), "详情也必须说明扫描范围不完整。")


func test_reference_report_shows_findings_and_discards_stale_details() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._set_all_enabled(false)
	var manifest: GFExtensionManifest = dock._manifests[0]
	dock._show_manifest_details(manifest)
	dock.next_report["reference_count"] = 1
	dock.next_report["extensions"] = {
		manifest.id: {
			"reference_count": 1,
			"references": [{ "path": "res://game/example.gd", "line": 7 }],
		},
	}
	dock._scan_disabled_extension_references()
	assert_string_contains(dock._status_label.text, "发现 1 处")
	assert_string_contains(dock._details_output.text, "res://game/example.gd:7")
	dock._refresh_extensions()
	assert_eq(dock.audit_count, 1, "重新加载只使报告失效。")
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(dock._details_output.text.contains("res://game/example.gd:7"), "旧扫描明细不得伪装成当前引用。")


func test_project_settings_signal_invalidates_without_scanning_and_disconnects() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	ProjectSettings.settings_changed.emit()
	assert_eq(dock.audit_count, 1)
	assert_string_contains(dock._status_label.text, "已失效")
	remove_child(dock)
	assert_false(
		ProjectSettings.settings_changed.is_connected(Callable(dock, "_on_audit_inputs_changed")),
		"页面离树后必须释放全局设置订阅。"
	)
	add_child(dock)
	assert_true(ProjectSettings.settings_changed.is_connected(Callable(dock, "_on_audit_inputs_changed")))
	assert_eq(dock.audit_count, 1, "重新挂载不能自动补扫。")


func test_file_change_invalidates_report_without_repeating_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	dock._on_audit_resources_changed(PackedStringArray(["res://game/changed.gd"]))
	assert_eq(dock.audit_count, 1)
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(dock._status_label.text.contains("未发现"))
	dock._on_audit_resources_changed(PackedStringArray(["res://game/changed.gd"]))
	assert_eq(dock.audit_count, 1, "连续文件通知只使缓存失效，不启动新扫描。")


func test_input_changes_during_initial_scan_and_rescan_keep_report_stale() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock.during_scan = func() -> void:
		ProjectSettings.settings_changed.emit()
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 1)
	assert_true(dock._status_label.text.contains("已失效"), "首次扫描途中改变输入也不能产生有效报告。")
	assert_false(dock._status_label.text.contains("未发现"))
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 2)
	assert_true(dock._status_label.text.contains("已失效"), "旧报告已经失效时，也必须记录本轮扫描期间的输入变化。")
	dock.during_scan = Callable()
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 3)
	assert_string_contains(dock._status_label.text, "扫描完成")


# --- 私有/辅助方法 ---

func _new_dock() -> AuditProbe:
	var dock: AuditProbe = AuditProbe.new()
	_docks.append(dock)
	add_child(dock)
	return dock


func _find_button(root: Node, button_text: String) -> Button:
	for child: Node in root.get_children():
		if child is Button:
			var button: Button = child
			if button.text == button_text:
				return button
		var nested: Button = _find_button(child, button_text)
		if nested != null:
			return nested
	return null


# --- 内部类 ---

class AuditProbe:
	extends "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd"

	var audit_count: int = 0
	var save_count: int = 0
	var during_scan: Callable = Callable()
	var next_report: Dictionary = {
		"ok": true,
		"partial_scan": false,
		"budget_exceeded": false,
		"reference_count": 0,
		"issue_count": 0,
		"extensions": {},
	}


	func _refresh_usage_report() -> void:
		audit_count += 1
		if during_scan.is_valid():
			var _callback_result: Variant = during_scan.call()
		_usage_report = next_report.duplicate(true)


	func _save_project_settings() -> Error:
		save_count += 1
		return OK
