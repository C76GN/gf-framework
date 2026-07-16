@tool

# GF 扩展管理器工作区页面。
#
# 展示 `gf_extension.json` 元数据，并把扩展启用状态保存到 ProjectSettings。
extends VBoxContainer


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")

## 扩展引用审计脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionUsageAuditBase = preload("res://addons/gf/kernel/extension/gf_extension_usage_audit.gd")

## 工作区 UI 辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorWorkspaceUI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 扩展行最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EXTENSION_ROW_MIN_HEIGHT: float = 32.0

## 详情区最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DETAILS_MIN_HEIGHT: float = 160.0

## 启用列宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const CHECK_COLUMN_WIDTH: float = 40.0

## 类型列宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const KIND_COLUMN_WIDTH: float = 72.0

## 发行版本列宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VERSION_COLUMN_WIDTH: float = 72.0

## 扩展版本列宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EXTENSION_VERSION_COLUMN_WIDTH: float = 72.0

## 状态列宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const STATUS_COLUMN_WIDTH: float = 72.0

## 扩展面板导出风险扫描忽略根目录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const USAGE_AUDIT_IGNORED_ROOTS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.gf",
	"res://addons/gf",
	"res://ai_analysis",
	"res://build",
	"res://packages",
	"res://site",
	"res://tests/gf_core",
]


# --- 私有变量 ---

var _extension_rows: VBoxContainer
var _details_output: RichTextLabel
var _status_label: Label
var _auto_install_check: CheckBox
var _export_exclude_check: CheckBox
var _export_fail_check: CheckBox
var _preset_option: OptionButton
var _preset_file_dialog: FileDialog
var _search_field: LineEdit
var _extension_checks: Dictionary = {}
var _selection_by_id: Dictionary = {}
var _selection_mode: String = GFExtensionSettingsBase.SELECTION_MODE_DEFAULT
var _manifests: Array[GFExtensionManifest] = []
var _selected_manifest_id: String = ""
var _usage_report: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Extensions"
	GFEditorWorkspaceUI.apply_page_root(self)
	_build_ui()
	call_deferred("_refresh_extensions")


# --- 私有/辅助方法 ---

func _connect_signal_checked(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	if source_signal.is_null() or not callback.is_valid():
		return
	if source_signal.is_connected(callback):
		return

	var error: Error = source_signal.connect(callback, flags as Object.ConnectFlags) as Error
	if error != OK:
		push_warning("[GFExtensionManagerDock] Signal 连接失败：%s" % error_string(error))


func _save_project_settings() -> void:
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("[GFExtensionManagerDock] 保存 ProjectSettings 失败：%s" % error_string(error))


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _build_ui() -> void:
	var toolbar: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(toolbar)

	toolbar.add_child(GFEditorWorkspaceUI.make_button("重新加载", "重新读取所有 gf_extension.json。", _reload_extensions))
	toolbar.add_child(GFEditorWorkspaceUI.make_button("扫描引用", "检查当前禁用扩展是否仍被项目文件直接引用。", _scan_disabled_extension_references))
	toolbar.add_child(GFEditorWorkspaceUI.make_button("恢复默认", "恢复 GF 默认扩展选择。", _restore_default_selection))
	toolbar.add_child(GFEditorWorkspaceUI.make_button("启用全部", "勾选当前发现的所有扩展。", _set_all_enabled.bind(true)))
	toolbar.add_child(GFEditorWorkspaceUI.make_button("禁用全部", "取消勾选当前发现的所有扩展。", _set_all_enabled.bind(false)))
	toolbar.add_child(GFEditorWorkspaceUI.make_button("保存设置", "写入 ProjectSettings 并保存 project.godot。", _apply_selection))

	var preset_row: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(preset_row)

	var preset_label: Label = Label.new()
	preset_label.text = "扩展组合"
	preset_label.custom_minimum_size = Vector2(72.0, 0.0)
	preset_row.add_child(preset_label)

	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.tooltip_text = "从 GF 内置动态组合或项目 preset JSON 中选择扩展启用组合。"
	preset_row.add_child(_preset_option)

	preset_row.add_child(GFEditorWorkspaceUI.make_button("应用组合", "把所选组合写入当前勾选状态。", _apply_selected_preset))
	preset_row.add_child(GFEditorWorkspaceUI.make_button("添加组合文件", "把项目中的 preset JSON 文件加入扩展组合列表。", _open_preset_file_dialog))
	preset_row.add_child(GFEditorWorkspaceUI.make_button("移除组合文件", "移除当前项目 preset JSON 路径；内置动态组合不会被移除。", _remove_selected_preset_path))

	var option_row: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(option_row)

	_auto_install_check = CheckBox.new()
	_auto_install_check.text = "自动装配启用扩展 Installer"
	_auto_install_check.tooltip_text = "初始化 GF 时自动执行启用扩展 manifest 中声明的 installer_paths"
	option_row.add_child(_auto_install_check)

	_export_exclude_check = CheckBox.new()
	_export_exclude_check.text = "导出时排除禁用扩展"
	_export_exclude_check.tooltip_text = "项目导出阶段跳过禁用扩展根目录下的文件"
	option_row.add_child(_export_exclude_check)

	_export_fail_check = CheckBox.new()
	_export_fail_check.text = "引用禁用扩展时阻止导出"
	_export_fail_check.tooltip_text = "导出审计发现项目仍引用禁用扩展时，以错误形式报告，适合发布前检查"
	option_row.add_child(_export_fail_check)

	var filter_row: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(filter_row)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "搜索名称、ID、标签"
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_signal_checked(_search_field.text_changed, _on_search_changed)
	filter_row.add_child(_search_field)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var list_panel: VBoxContainer = VBoxContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(list_panel)

	list_panel.add_child(_create_header_row())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)

	_extension_rows = VBoxContainer.new()
	_extension_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_extension_rows)

	_details_output = RichTextLabel.new()
	_details_output.custom_minimum_size = Vector2(0.0, DETAILS_MIN_HEIGHT)
	_details_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	_details_output.selection_enabled = true
	_details_output.scroll_active = true
	split.add_child(_details_output)

	_status_label = GFEditorWorkspaceUI.make_summary_label()
	add_child(_status_label)


func _create_header_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(_create_header_label("启用", CHECK_COLUMN_WIDTH))
	var name_label: Label = _create_header_label("扩展", 0.0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_create_header_label("类型", KIND_COLUMN_WIDTH))
	row.add_child(_create_header_label("发行版", VERSION_COLUMN_WIDTH))
	row.add_child(_create_header_label("扩展版本", EXTENSION_VERSION_COLUMN_WIDTH))
	row.add_child(_create_header_label("状态", STATUS_COLUMN_WIDTH))
	return row


func _create_header_label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = Color(0.75, 0.75, 0.75)
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0.0)
	return label


func _refresh_extensions() -> void:
	_extension_checks.clear()
	_selection_by_id.clear()
	_clear_extension_rows()

	_manifests = GFExtensionSettingsBase.get_all_manifests()
	_selection_mode = GFExtensionSettingsBase.get_extension_selection_mode()
	_refresh_preset_options()
	var enabled_ids: Array[String] = GFExtensionSettingsBase.resolve_extension_dependencies(
		GFExtensionSettingsBase.get_enabled_extension_ids(),
		_manifests
	)
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = enabled_ids.has(manifest.id)

	_auto_install_check.button_pressed = GFExtensionSettingsBase.should_auto_install_enabled_installers()
	_export_exclude_check.button_pressed = GFExtensionSettingsBase.should_export_exclude_disabled_extensions()
	_export_fail_check.button_pressed = GFExtensionSettingsBase.should_fail_export_on_disabled_extension_references()
	_refresh_usage_report()

	_refresh_visible_extension_rows()

	if not _manifests.is_empty():
		_show_manifest_details(_manifests[0])
	else:
		_details_output.text = "没有发现 GF 扩展。"
	_set_selection_status()


func _reload_extensions() -> void:
	GFExtensionSettingsBase.clear_manifest_cache()
	_refresh_extensions()


func _refresh_visible_extension_rows() -> void:
	_extension_checks.clear()
	_clear_extension_rows()

	var visible_manifests: Array[GFExtensionManifest] = _get_visible_manifests()
	var last_kind: String = ""
	for manifest: GFExtensionManifest in visible_manifests:
		if manifest.kind != last_kind:
			_add_group_header(manifest.kind)
			last_kind = manifest.kind
		_add_extension_row(manifest, _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false))

	if visible_manifests.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "没有匹配的扩展。"
		empty_label.modulate = Color(0.65, 0.65, 0.65)
		_extension_rows.add_child(empty_label)


func _clear_extension_rows() -> void:
	for child: Node in _extension_rows.get_children():
		_extension_rows.remove_child(child)
		child.queue_free()


func _add_group_header(kind: String) -> void:
	var label: Label = Label.new()
	label.text = _format_kind(kind)
	label.modulate = Color(0.85, 0.85, 0.85)
	label.custom_minimum_size = Vector2(0.0, 28.0)
	_extension_rows.add_child(label)


func _add_extension_row(manifest: GFExtensionManifest, enabled: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, EXTENSION_ROW_MIN_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extension_rows.add_child(row)

	var check: CheckBox = CheckBox.new()
	check.button_pressed = enabled
	check.tooltip_text = manifest.id
	check.custom_minimum_size = Vector2(CHECK_COLUMN_WIDTH, 0.0)
	_connect_signal_checked(check.toggled, _on_extension_toggled.bind(manifest.id))
	row.add_child(check)
	_extension_checks[manifest.id] = check

	var name_button: Button = Button.new()
	name_button.flat = true
	name_button.text = manifest.display_name
	name_button.tooltip_text = "%s\n%s" % [manifest.id, manifest.description]
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_signal_checked(name_button.pressed, _show_manifest_details.bind(manifest))
	row.add_child(name_button)

	var kind_label: Label = Label.new()
	kind_label.text = _format_kind(manifest.kind)
	kind_label.custom_minimum_size = Vector2(KIND_COLUMN_WIDTH, 0.0)
	row.add_child(kind_label)

	var version_label: Label = Label.new()
	version_label.text = manifest.version
	version_label.custom_minimum_size = Vector2(VERSION_COLUMN_WIDTH, 0.0)
	row.add_child(version_label)

	var extension_version_label: Label = Label.new()
	extension_version_label.text = manifest.extension_version if not manifest.extension_version.is_empty() else "-"
	extension_version_label.custom_minimum_size = Vector2(EXTENSION_VERSION_COLUMN_WIDTH, 0.0)
	row.add_child(extension_version_label)

	var status_label: Label = Label.new()
	status_label.text = "有效" if manifest.is_valid() else "无效"
	status_label.tooltip_text = _join_strings(manifest.get_validation_errors())
	status_label.custom_minimum_size = Vector2(STATUS_COLUMN_WIDTH, 0.0)
	row.add_child(status_label)


func _apply_selection() -> void:
	_write_selection_to_project_settings()
	_save_project_settings()
	_refresh_usage_report()
	_refresh_extensions()
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_usage_report, "reference_count", 0) > 0:
		_set_status("扩展设置已保存，但发现禁用扩展仍被引用，请检查详情。")
	else:
		_set_status("扩展设置已保存。")


func _write_selection_to_project_settings() -> void:
	if _selection_mode == GFExtensionSettingsBase.SELECTION_MODE_DEFAULT:
		GFExtensionSettingsBase.use_default_extension_selection()
	else:
		GFExtensionSettingsBase.set_enabled_extension_ids(_get_selected_enabled_ids(), true)
	GFExtensionSettingsBase.set_auto_install_enabled_installers(_auto_install_check.button_pressed)
	GFExtensionSettingsBase.set_export_exclude_disabled_extensions(_export_exclude_check.button_pressed)
	GFExtensionSettingsBase.set_fail_export_on_disabled_extension_references(_export_fail_check.button_pressed)


func _set_all_enabled(enabled: bool) -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_EXPLICIT
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = enabled
	_refresh_usage_report()
	_refresh_visible_extension_rows()
	_set_status("选择已更新，点击“保存设置”后生效。")


func _restore_default_selection() -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_DEFAULT
	var default_ids: Array[String] = GFExtensionSettingsBase.get_default_enabled_extension_ids()
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = default_ids.has(manifest.id)
	_refresh_usage_report()
	_refresh_visible_extension_rows()
	_set_status("已恢复默认选择，点击“保存设置”后生效。")


func _refresh_preset_options() -> void:
	if _preset_option == null:
		return

	_preset_option.clear()
	for preset: GFExtensionPreset in GFExtensionSettingsBase.get_extension_presets():
		var item_index: int = _preset_option.item_count
		_preset_option.add_item(preset.display_name)
		_preset_option.set_item_metadata(item_index, String(preset.id))
		_preset_option.set_item_tooltip(item_index, preset.description)
	_preset_option.disabled = _preset_option.item_count == 0


func _apply_selected_preset() -> void:
	var preset_id: StringName = _get_selected_preset_id()
	if preset_id == &"":
		_set_status("没有可应用的扩展组合。")
		return

	var _applied: bool = _apply_extension_preset_by_id(preset_id)


func _open_preset_file_dialog() -> void:
	_ensure_preset_file_dialog()
	if _preset_file_dialog == null:
		_set_status("无法打开扩展组合文件选择器。")
		return

	_preset_file_dialog.popup_centered_ratio(0.5)


func _ensure_preset_file_dialog() -> void:
	if _preset_file_dialog != null and is_instance_valid(_preset_file_dialog):
		return

	_preset_file_dialog = FileDialog.new()
	_preset_file_dialog.title = "选择 GF 扩展组合 JSON"
	_preset_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_preset_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_preset_file_dialog.filters = PackedStringArray(["*.json ; JSON 文件"])
	add_child(_preset_file_dialog)
	_connect_signal_checked(_preset_file_dialog.file_selected, _on_preset_file_selected)


func _on_preset_file_selected(path: String) -> void:
	var _added: bool = _add_extension_preset_path(path)


func _add_extension_preset_path(path: String) -> bool:
	if not GFExtensionSettingsBase.add_extension_preset_path(path):
		_set_status("扩展组合文件无效或已存在。")
		return false

	_refresh_preset_options()
	_set_status("已添加扩展组合文件，点击“保存设置”后生效。")
	return true


func _remove_selected_preset_path() -> bool:
	var preset_id: StringName = _get_selected_preset_id()
	if preset_id == &"":
		_set_status("没有可移除的扩展组合。")
		return false

	var preset: GFExtensionPreset = GFExtensionSettingsBase.get_extension_preset_by_id(preset_id)
	if preset == null or preset.source_path.is_empty():
		_set_status("内置动态扩展组合不能移除。")
		return false

	if not GFExtensionSettingsBase.remove_extension_preset_path(preset.source_path):
		_set_status("扩展组合文件路径不存在。")
		return false

	_refresh_preset_options()
	_set_status("已移除扩展组合文件，点击“保存设置”后生效。")
	return true


func _apply_extension_preset_by_id(preset_id: StringName) -> bool:
	var preset: GFExtensionPreset = GFExtensionSettingsBase.get_extension_preset_by_id(preset_id)
	if preset == null:
		_set_status("扩展组合不存在或未通过校验。")
		return false

	var enabled_ids: Array[String] = GFExtensionSettingsBase.resolve_extension_dependencies(
		preset.extension_ids,
		_manifests
	)
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_EXPLICIT
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = enabled_ids.has(manifest.id)
	_refresh_usage_report()
	_refresh_visible_extension_rows()
	_refresh_selected_manifest_details()
	_set_status("已应用扩展组合“%s”，点击“保存设置”后生效。" % preset.display_name)
	return true


func _show_manifest_details(manifest: GFExtensionManifest) -> void:
	_selected_manifest_id = manifest.id

	var lines: PackedStringArray = PackedStringArray()
	_append_packed_string(lines, "名称：%s" % manifest.display_name)
	_append_packed_string(lines, "ID：%s" % manifest.id)
	_append_packed_string(lines, "发行版本：%s" % manifest.version)
	_append_packed_string(lines, "扩展版本：%s" % (manifest.extension_version if not manifest.extension_version.is_empty() else "-"))
	_append_packed_string(lines, "类型：%s" % _format_kind(manifest.kind))
	_append_packed_string(lines, "默认启用：%s" % ("是" if manifest.enabled_by_default else "否"))
	_append_packed_string(lines, "当前启用：%s" % ("是" if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false) else "否"))
	_append_packed_string(lines, "状态：%s" % ("有效" if manifest.is_valid() else "无效"))
	_append_packed_string(lines, "根目录：%s" % manifest.root_path)
	_append_packed_string(lines, "")
	_append_packed_string(lines, manifest.description)
	_append_packed_string(lines, "")
	_append_packed_string(lines, "依赖：%s" % _format_dependencies(manifest.dependencies))
	_append_packed_string(lines, "Installer：%s" % _format_string_array(manifest.installer_paths))
	_append_packed_string(lines, "菜单动作：%s" % _format_string_array(manifest.editor_action_paths))
	_append_packed_string(lines, "工作区页面：%s" % _format_string_array(manifest.editor_dock_paths))
	_append_packed_string(lines, "工作区短标签：%s" % (manifest.editor_dock_short_label if not manifest.editor_dock_short_label.is_empty() else "-"))
	_append_packed_string(lines, "工作区排序：%d" % manifest.editor_dock_order)
	_append_packed_string(lines, "Inspector：%s" % _format_string_array(manifest.editor_inspector_paths))
	_append_packed_string(lines, "导入插件：%s" % _format_string_array(manifest.import_plugin_paths))
	_append_packed_string(lines, "导出插件：%s" % _format_string_array(manifest.export_plugin_paths))
	_append_packed_string(lines, "glTF 文档扩展：%s" % _format_string_array(manifest.gltf_document_extension_paths))
	_append_packed_string(lines, "访问器扩展：%s" % _format_string_array(manifest.access_generator_extension_paths))
	_append_packed_string(lines, "标签：%s" % _format_string_array(manifest.tags))
	_append_usage_warning_lines(lines, manifest)

	var errors: Array[String] = manifest.get_validation_errors()
	if not errors.is_empty():
		_append_packed_string(lines, "")
		_append_packed_string(lines, "校验问题：")
		for error: String in errors:
			_append_packed_string(lines, "- %s" % error)

	_details_output.text = "\n".join(lines)


func _get_visible_manifests() -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in _manifests:
		if not _matches_search(manifest):
			continue
		result.append(manifest)
	return result


func _matches_search(manifest: GFExtensionManifest) -> bool:
	if _search_field == null:
		return true

	var query: String = _search_field.text.strip_edges().to_lower()
	if query.is_empty():
		return true

	var haystack: String = "%s %s %s %s %s" % [
		manifest.display_name,
		manifest.id,
		manifest.description,
		manifest.kind,
		_join_strings(manifest.tags),
	]
	return haystack.to_lower().contains(query)


func _get_selected_enabled_ids() -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in _manifests:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
			ids.append(manifest.id)
	ids.sort()
	return ids


func _get_selected_preset_id() -> StringName:
	if _preset_option == null or _preset_option.item_count == 0 or _preset_option.selected < 0:
		return &""

	var raw_id: Variant = _preset_option.get_item_metadata(_preset_option.selected)
	return StringName(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_id))


func _get_disabled_manifests_from_selection() -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in _manifests:
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
			manifests.append(manifest)
	return manifests


func _make_usage_audit_options() -> Dictionary:
	return {
		"ignored_roots": USAGE_AUDIT_IGNORED_ROOTS,
		"max_references_per_extension": 20,
	}


func _refresh_usage_report() -> void:
	_usage_report = GFExtensionUsageAuditBase.audit_disabled_extensions(
		_get_disabled_manifests_from_selection(),
		_make_usage_audit_options()
	)


func _append_usage_warning_lines(lines: PackedStringArray, manifest: GFExtensionManifest) -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
		return

	var extensions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(_usage_report, "extensions", {})
	)
	if not extensions.has(manifest.id):
		return

	var extension_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(extensions[manifest.id])
	if extension_report.is_empty():
		return

	_append_packed_string(lines, "")
	_append_packed_string(lines, "引用风险：发现 %d 处项目文件仍直接引用该禁用扩展。" % _GF_VARIANT_ACCESS_SCRIPT.get_option_int(extension_report, "reference_count", 0))
	var references: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(extension_report, "references", [])
	)
	for i: int in range(mini(references.size(), 8)):
		var reference: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(references[i])
		if reference.is_empty():
			continue
		_append_packed_string(lines, "- %s:%d" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference, "path", ""),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(reference, "line", 0),
		])
	if references.size() > 8:
		_append_packed_string(lines, "- 还有 %d 处未显示。" % (references.size() - 8))


func _format_kind(kind: String) -> String:
	match kind:
		GFExtensionManifest.KIND_EXTENSION:
			return "扩展"
		GFExtensionManifest.KIND_STANDARD:
			return "标准"
		_:
			return kind


func _format_dependencies(values: Array[String]) -> String:
	if values.is_empty():
		return "无"

	var labels: PackedStringArray = PackedStringArray()
	for value: String in values:
		match value:
			"gf.kernel":
				_append_packed_string(labels, "GF Kernel")
			"gf.standard":
				_append_packed_string(labels, "GF Standard")
			_:
				_append_packed_string(labels, value)
	return ", ".join(labels)


func _format_string_array(values: Array[String]) -> String:
	if values.is_empty():
		return "无"
	return _join_strings(values)


func _join_strings(values: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for value: String in values:
		_append_packed_string(packed, value)
	return ", ".join(packed)


func _set_selection_status() -> void:
	var enabled_count: int = _get_selected_enabled_ids().size()
	var reference_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_usage_report, "reference_count", 0)
	var mode_label: String = "默认" if _selection_mode == GFExtensionSettingsBase.SELECTION_MODE_DEFAULT else "显式"
	if reference_count > 0:
		_set_status("%s模式：已选择 %d / %d 个扩展；发现 %d 处禁用扩展引用。" % [
			mode_label,
			enabled_count,
			_manifests.size(),
			reference_count,
		])
	else:
		_set_status("%s模式：已选择 %d / %d 个扩展。禁用扩展可在导出阶段排除。" % [
			mode_label,
			enabled_count,
			_manifests.size(),
		])


func _set_status(message: String) -> void:
	GFEditorWorkspaceUI.set_status(_status_label, message)


func _scan_disabled_extension_references() -> void:
	_refresh_usage_report()
	_refresh_selected_manifest_details()
	_set_selection_status()


func _refresh_selected_manifest_details() -> void:
	if _selected_manifest_id.is_empty():
		return

	for manifest: GFExtensionManifest in _manifests:
		if manifest.id == _selected_manifest_id:
			_show_manifest_details(manifest)
			return


func _on_search_changed(_new_text: String) -> void:
	_refresh_visible_extension_rows()
	_set_selection_status()


func _on_extension_toggled(enabled: bool, extension_id: String) -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_EXPLICIT
	_selection_by_id[extension_id] = enabled
	_refresh_usage_report()
	if extension_id == _selected_manifest_id:
		for manifest: GFExtensionManifest in _manifests:
			if manifest.id == extension_id:
				_show_manifest_details(manifest)
				break
	_set_status("选择已更新，点击“保存设置”后生效。")
