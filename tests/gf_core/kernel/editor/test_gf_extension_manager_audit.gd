@tool

# 扩展管理页面仅在用户要求时扫描引用，并明确区分未扫描、过期和不完整证据。
extends GutTest


# --- 常量 ---

const _EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

var _docks: Array[AuditProbe] = []
var _settings_restore: Dictionary = {}
var _directory: String = ""
var _files: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_directory = "res://tests/gf_core/kernel/editor/audit_fixture_%d" % Time.get_ticks_usec()
	assert_eq(
		DirAccess.make_dir_recursive_absolute(_directory.path_join("extension")),
		OK
	)
	for setting_path: String in [
		_EXTENSION_SETTINGS_SCRIPT.ENABLED_EXTENSIONS_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXPORT_EXCLUDE_DISABLED_SETTING,
		_EXTENSION_SETTINGS_SCRIPT.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
	]:
		_settings_restore[setting_path] = { "exists": ProjectSettings.has_setting(setting_path), "value": ProjectSettings.get_setting(setting_path), }


func after_each() -> void:
	for dock: AuditProbe in _docks:
		if is_instance_valid(dock):
			dock.free()
	_docks.clear()
	for path: String in _files:
		var _removed: Error = DirAccess.remove_absolute(path)
	_files.clear()
	var _removed_extension: Error = DirAccess.remove_absolute(_directory.path_join("extension"))
	var _removed_directory: Error = DirAccess.remove_absolute(_directory)
	for setting_path: String in _settings_restore:
		var raw_snapshot: Variant = _settings_restore[setting_path]
		if not (raw_snapshot is Dictionary):
			assert_true(false, "设置恢复快照必须是 Dictionary。")
			continue
		var snapshot: Dictionary = raw_snapshot
		var existed: Variant = snapshot.get("exists", false)
		if existed is bool and existed:
			ProjectSettings.set_setting(
				setting_path,
				snapshot["value"]
			)
		else:
			ProjectSettings.set_setting(setting_path, null)
	_settings_restore.clear()
	await get_tree().process_frame


# --- 测试用例 ---

func test_open_refresh_selection_and_save_do_not_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	assert_eq(
		dock.audit_count,
		0,
		"首次打开扩展列表不能同步扫描项目引用。"
	)
	assert_true(
		dock._status_label.text.contains("未扫描"),
		"初次列表不能暗示禁用扩展已经通过审计。"
	)
	dock._refresh_extensions()
	dock._set_all_enabled(true)
	dock._restore_default_selection()
	var preset_applied: bool = dock._apply_extension_preset_by_id(&"gf.none")
	assert_true(preset_applied)
	dock._on_extension_toggled(true, "gf.save")
	dock._apply_selection()
	assert_eq(
		dock.save_count,
		1,
		"保存仍应写入设置。"
	)
	assert_eq(
		dock.audit_count,
		0,
		"刷新、组合、选择与保存必须保持按需审计。"
	)
	assert_true(
		dock._status_label.text.contains("未扫描"),
		"保存成功不等同于引用审计成功。"
	)


func test_scan_button_runs_once_and_search_preserves_report() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	var scan_button: Button = _find_button(dock, "扫描引用")
	assert_not_null(scan_button)
	if scan_button == null:
		return
	scan_button.pressed.emit()
	assert_false(dock._usage_cancel_button.disabled)
	assert_true(
		dock._usage_report.is_empty(),
		"开始扫描不得提前发布报告。"
	)
	_finish_scan(dock)
	assert_eq(
		dock.audit_count,
		1,
		"一次扫描按钮操作只生成一份报告。"
	)
	assert_string_contains(dock._status_label.text, "扫描完成")
	assert_string_contains(dock._status_label.text, "未发现")
	dock._search_field.text = "save"
	dock._search_field.text_changed.emit("save")
	assert_eq(
		dock.audit_count,
		1,
		"筛选扩展列表不能重新扫描项目。"
	)
	assert_true(
		dock._status_label.text.contains("扫描完成"),
		"筛选列表不改变报告所依据的输入。"
	)


func test_selection_marks_prior_report_stale_until_next_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
	dock._on_extension_toggled(true, "gf.save")
	assert_eq(dock.audit_count, 1)
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(
		dock._status_label.text.contains("未发现"),
		"旧报告的零引用不能作为新选择的结论。"
	)
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
	assert_eq(dock.audit_count, 2)
	assert_string_contains(dock._status_label.text, "扫描完成")


func test_partial_zero_reference_report_does_not_claim_complete() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock._usage_report = { "partial_scan": true, "ok": false }
	dock._refresh_selected_manifest_details()
	dock._set_selection_status()
	assert_string_contains(dock._status_label.text, "扫描不完整")
	assert_false(dock._status_label.text.contains("未发现"))
	assert_false(dock._status_label.text.contains("扫描完成"))
	assert_true(
		dock._details_output.text.contains("扫描不完整"),
		"详情也必须说明扫描范围不完整。"
	)


func test_reference_report_shows_findings_and_discards_stale_details() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._set_all_enabled(false)
	var manifest: GFExtensionManifest = dock._manifests[0]
	dock._show_manifest_details(manifest)
	dock._usage_report = { "ok": false, "reference_count": 1 }
	dock._usage_report["extensions"] = {
		manifest.id: {
			"reference_count": 1,
			"references": [
				{ "path": "res://game/example.gd", "line": 7 },
			],
		},
	}
	dock._refresh_selected_manifest_details()
	dock._set_selection_status()
	assert_string_contains(dock._status_label.text, "发现 1 处")
	assert_string_contains(dock._details_output.text, "res://game/example.gd:7")
	dock._refresh_extensions()
	assert_eq(
		dock.audit_count,
		0,
		"重新加载只使报告失效。"
	)
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(
		dock._details_output.text.contains("res://game/example.gd:7"),
		"旧扫描明细不得伪装成当前引用。"
	)


func test_project_settings_signal_invalidates_without_scanning_and_disconnects() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
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
	assert_eq(
		dock.audit_count,
		1,
		"重新挂载不能自动补扫。"
	)


func test_file_change_invalidates_report_without_repeating_scan() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
	dock._on_audit_resources_changed(PackedStringArray(["res://game/changed.gd"]))
	assert_eq(dock.audit_count, 1)
	assert_string_contains(dock._status_label.text, "已失效")
	assert_false(dock._status_label.text.contains("未发现"))
	dock._on_audit_resources_changed(PackedStringArray(["res://game/changed.gd"]))
	assert_eq(
		dock.audit_count,
		1,
		"连续文件通知只使缓存失效，不启动新扫描。"
	)


func test_input_changes_during_initial_scan_and_rescan_keep_report_stale() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock.during_scan = func() -> void:
		ProjectSettings.settings_changed.emit()
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 1)
	assert_true(
		dock._status_label.text.contains("已失效"),
		"首次扫描途中改变输入也不能产生有效报告。"
	)
	assert_false(dock._status_label.text.contains("未发现"))
	dock._scan_disabled_extension_references()
	assert_eq(dock.audit_count, 2)
	assert_true(
		dock._status_label.text.contains("已失效"),
		"旧报告已经失效时，也必须记录本轮扫描期间的输入变化。"
	)
	dock.during_scan = Callable()
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
	assert_eq(dock.audit_count, 3)
	assert_string_contains(dock._status_label.text, "扫描完成")


func test_real_scan_progress_cancel_and_rescan_use_the_current_input() -> void:
	var source_path: String = _write_reference_source()
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._usage_scan_button.pressed.emit()
	var observed_progress: bool = false
	for index: int in range(4096):
		var finished: bool = dock._usage_task.step(1, 4000)
		assert_false(finished)
		var progress: Dictionary = dock._usage_task.get_progress()
		if GFVariantData.get_option_int(progress, "line_offset") > 0:
			observed_progress = true
			dock._set_selection_status()
			assert_string_contains(dock._status_label.text, "进行中")
			assert_true(dock._usage_report.is_empty())
			break
	assert_true(observed_progress)
	dock._usage_cancel_button.pressed.emit()
	assert_null(dock._usage_task)
	assert_true(dock._usage_cancel_button.disabled)
	assert_true(dock._usage_report.is_empty())
	dock._process(0.0)
	assert_string_contains(dock._status_label.text, "已取消")
	dock._usage_scan_button.pressed.emit()
	_finish_scan(dock)
	assert_eq(dock.audit_count, 2)
	assert_eq(
		GFVariantData.get_option_int(dock._usage_report, "reference_count"),
		1
	)
	var references: Array = GFVariantData.get_option_array(dock._usage_report, "references")
	assert_eq(
		references.size(),
		1
	)
	if references.size() == 1:
		var reference: Dictionary = GFVariantData.as_dictionary(references[0])
		assert_eq(
			GFVariantData.get_option_string(reference, "path"),
			source_path
		)


func test_hidden_exited_and_revoked_pages_cancel_without_publishing() -> void:
	for action: String in [
		"hide",
		"exit",
		"revoke",
	]:
		var dock: AuditProbe = _new_dock()
		await get_tree().process_frame
		dock._scan_disabled_extension_references()
		assert_not_null(dock._usage_task)
		match action:
			"hide":
				dock.hide()
			"exit":
				remove_child(dock)
			"revoke":
				dock.set_editor_context(null)
		assert_null(dock._usage_task)
		assert_true(dock._usage_report.is_empty())
		assert_true(dock._usage_cancel_button.disabled)
		if action == "revoke":
			dock._scan_disabled_extension_references()
			assert_null(dock._usage_task, "权限撤销后旧按钮回调不能启动新任务。")


func test_actual_gdignore_scope_survives_audit_and_is_visible_in_details() -> void:
	var marker_path: String = _directory.path_join(".gdignore")
	var marker: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	assert_not_null(marker)
	if marker != null:
		marker.close()
	var _appended: bool = _files.append(marker_path)
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._set_all_enabled(false)
	dock._show_manifest_details(dock._manifests[0])
	dock._scan_disabled_extension_references()
	_finish_scan(dock)
	var scope: Dictionary = GFVariantData.get_option_dictionary(dock._usage_report, "scope")
	assert_true(GFVariantData.get_option_bool(scope, "respect_gdignore"))
	assert_eq(
		GFVariantData.get_option_string_array(scope, "ignored_directories"),
		[_directory]
	)
	assert_string_contains(dock._details_output.text, "实际跳过目录：1")
	assert_string_contains(dock._details_output.text, _directory)


func test_reentrant_old_step_does_not_cancel_replacement_session() -> void:
	var dock: AuditProbe = _new_dock()
	await get_tree().process_frame
	dock._scan_disabled_extension_references()
	dock._usage_task.cancel()
	var old_task: ReentrantAudit = ReentrantAudit.new()
	old_task.on_step = dock._scan_disabled_extension_references
	dock._usage_task = old_task
	dock._step_usage_scan()
	assert_not_null(dock._usage_task)
	assert_ne(dock._usage_task, old_task)
	assert_false(dock._usage_cancel_button.disabled)
	_finish_scan(dock)
	assert_string_contains(dock._status_label.text, "扫描完成")


# --- 私有/辅助方法 ---

func _write_reference_source() -> String:
	var path: String = _directory.path_join("consumer.gd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var _stored: bool = file.store_string("extends RefCounted\n" + "# scan progress\n".repeat(320) + "var dependency = load(\"%s/extension/unused.tres\")\n" % _directory)
		file.close()
	var _appended: bool = _files.append(path)
	return path


func _new_dock() -> AuditProbe:
	var dock: AuditProbe = AuditProbe.new()
	dock.scan_directory = _directory
	_docks.append(dock)
	add_child(dock)
	return dock


func _finish_scan(dock: AuditProbe) -> void:
	for index: int in range(4096):
		dock._step_usage_scan()
		if dock._usage_task == null:
			return
	fail_test("小目录的真实审计会话应在有限步内完成。")


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

class ReentrantAudit:
	extends GFExtensionUsageAudit

	var on_step: Callable

	func step(_max_items: int = 128, _max_usec: int = 4000) -> bool:
		var _called: Variant = on_step.call()
		return true


class AuditProbe:
	extends "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd"

	var audit_count: int = 0
	var save_count: int = 0
	var during_scan: Callable = Callable()
	var scan_directory: String = ""

	func _refresh_usage_report() -> void:
		audit_count += 1
		super._refresh_usage_report()
		if during_scan.is_valid():
			var _callback_result: Variant = during_scan.call()


	func _get_disabled_manifests_from_selection() -> Array[GFExtensionManifest]:
		var manifest: GFExtensionManifest = GFExtensionManifest.new()
		manifest.id = "fixture.extension"
		manifest.root_path = scan_directory.path_join("extension")
		return [manifest]


	func _make_usage_audit_options() -> Dictionary:
		return {
			"scan_roots": [scan_directory],
			"ignored_roots": [scan_directory.path_join("extension")],
			"max_references_per_extension": 20,
			"respect_gdignore": true,
		}


	func _save_project_settings() -> Error:
		save_count += 1
		return OK
