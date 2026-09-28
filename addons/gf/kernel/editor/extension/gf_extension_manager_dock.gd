@tool

# GF 扩展管理器工作区页面。
#
# 展示 `gf_extension.json` 元数据，并把扩展启用状态保存到 ProjectSettings。
extends VBoxContainer


# --- 常量 ---

## 读取选择表、preset 元数据和审计报告的 Variant 访问辅助脚本。
## [br]
## @api private
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

## 承载扩展列表行的容器。
## [br]
## @api private
var _extension_rows: VBoxContainer

## 显示扩展详细信息与引用风险的文本控件。
## [br]
## @api private
var _details_output: RichTextLabel

## 显示选择与引用审计状态的标签。
## [br]
## @api private
var _status_label: Label

## 自动装配启用扩展 installer 的复选框。
## [br]
## @api private
var _auto_install_check: CheckBox

## 导出时排除禁用扩展的复选框。
## [br]
## @api private
var _export_exclude_check: CheckBox

## 项目仍引用禁用扩展时阻止导出的复选框。
## [br]
## @api private
var _export_fail_check: CheckBox

## 显示可用扩展组合的下拉框。
## [br]
## @api private
var _preset_option: OptionButton

## 选择项目扩展组合 JSON 文件的对话框。
## [br]
## @api private
var _preset_file_dialog: FileDialog

## 过滤扩展列表的搜索输入框。
## [br]
## @api private
var _search_field: LineEdit

## 按扩展 ID 索引当前列表中的 CheckBox。
## [br]
## @api private
var _extension_checks: Dictionary = {}

## 按扩展 ID 保存当前选择布尔值的字典。
## [br]
## @api private
var _selection_by_id: Dictionary = {}

## 当前采用默认选择还是显式选择的模式。
## [br]
## @api private
var _selection_mode: String = GFExtensionSettingsBase.SELECTION_MODE_DEFAULT

## 当前载入的扩展清单。
## [br]
## @api private
var _manifests: Array[GFExtensionManifest] = []

## 当前详情区展示的扩展 ID。
## [br]
## @api private
var _selected_manifest_id: String = ""

## 最近一次禁用扩展引用审计报告。
## [br]
## @api private
var _usage_report: Dictionary = {}

## 标记当前引用审计报告已失效。
## [br]
## @api private
var _usage_report_stale: bool = false

## 输入变更时递增的引用审计代数。
## [br]
## @api private
var _usage_input_generation: int = 0

## 在编辑器环境中连接文件变更信号的文件系统对象。
## [br]
## @api private
var _editor_filesystem: EditorFileSystem = null


# --- Godot 生命周期方法 ---

## 设置扩展面板名称和页面布局，建立界面，并延迟执行首次刷新。
## [br]
## @api private
func _init() -> void:
	name = "GF Extensions"
	GFEditorWorkspaceUI.apply_page_root(self)
	_build_ui()
	call_deferred("_refresh_extensions")


## 订阅项目设置变化；在编辑器中同时监听文件系统、资源重导入与脚本类更新，以使使用扫描结果及时失效。
## [br]
## @api private
func _enter_tree() -> void:
	_connect_signal_checked(ProjectSettings.settings_changed, _on_audit_inputs_changed)
	if not Engine.is_editor_hint():
		return
	_editor_filesystem = EditorInterface.get_resource_filesystem()
	if _editor_filesystem == null:
		return
	_connect_signal_checked(_editor_filesystem.filesystem_changed, _on_audit_inputs_changed)
	_connect_signal_checked(_editor_filesystem.resources_reimported, _on_audit_resources_changed)
	_connect_signal_checked(_editor_filesystem.resources_reload, _on_audit_resources_changed)
	_connect_signal_checked(_editor_filesystem.script_classes_updated, _on_audit_inputs_changed)


## 断开已连接的设置与文件系统信号，清除文件系统引用并使使用扫描结果失效。
## [br]
## @api private
func _exit_tree() -> void:
	_disconnect_signal_checked(ProjectSettings.settings_changed, _on_audit_inputs_changed)
	if _editor_filesystem != null and is_instance_valid(_editor_filesystem):
		_disconnect_signal_checked(_editor_filesystem.filesystem_changed, _on_audit_inputs_changed)
		_disconnect_signal_checked(_editor_filesystem.resources_reimported, _on_audit_resources_changed)
		_disconnect_signal_checked(_editor_filesystem.resources_reload, _on_audit_resources_changed)
		_disconnect_signal_checked(_editor_filesystem.script_classes_updated, _on_audit_inputs_changed)
	_editor_filesystem = null
	_invalidate_usage_report()


# --- 私有/辅助方法 ---

## 在信号和回调有效且尚未连接时尝试连接；失败时发出警告。
## [br]
## @api private
func _connect_signal_checked(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	if source_signal.is_null() or not callback.is_valid():
		return
	if source_signal.is_connected(callback):
		return

	var error: Error = source_signal.connect(callback, flags as Object.ConnectFlags) as Error
	if error != OK:
		push_warning("[GFExtensionManagerDock][extension_manager_dock.signal_connection_failed] Signal connection failed: %s." % error_string(error))


## 仅在信号非空且已连接给定回调时断开连接。
## [br]
## @api private
func _disconnect_signal_checked(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_null() and source_signal.is_connected(callback):
		source_signal.disconnect(callback)


## 保存 ProjectSettings，并在返回错误码非 OK 时发出错误信息。
## [br]
## @api private
func _save_project_settings() -> Error:
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("[GFExtensionManagerDock][extension_manager_dock.settings_save_failed] Could not save ProjectSettings: %s." % error_string(error))
	return error


## 将字符串追加到 PackedStringArray；返回类型为 void，不传递 append 的结果。
## [br]
## @api private
func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


## 构建工具栏、组合和导出选项、搜索框、扩展列表、详情区及状态标签。
## [br]
## @api private
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


## 创建包含启用、名称、类型、发行版、扩展版本和状态列标题的行。
## [br]
## @api private
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


## 创建表头标签，并在 width 大于零时设置其最小列宽。
## [br]
## @api private
func _create_header_label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = Color(0.75, 0.75, 0.75)
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0.0)
	return label


## 重载清单、选择模式与扩展设置，更新 preset、列表、详情和状态显示。
## [br]
## @api private
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
	_invalidate_usage_report()

	_refresh_visible_extension_rows()

	if not _manifests.is_empty():
		_show_manifest_details(_manifests[0])
	else:
		_details_output.text = "没有发现 GF 扩展。"
	_set_selection_status()


## 清除扩展清单缓存，再重新载入并刷新面板。
## [br]
## @api private
func _reload_extensions() -> void:
	GFExtensionSettingsBase.clear_manifest_cache()
	_refresh_extensions()


## 按当前搜索过滤清单并重建可见扩展行；无匹配项时显示提示标签。
## [br]
## @api private
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


## 从列表容器移除所有行子节点并排队释放。
## [br]
## @api private
func _clear_extension_rows() -> void:
	for child: Node in _extension_rows.get_children():
		_extension_rows.remove_child(child)
		child.queue_free()


## 向列表添加显示指定扩展类型名称的分组标题。
## [br]
## @api private
func _add_group_header(kind: String) -> void:
	var label: Label = Label.new()
	label.text = _format_kind(kind)
	label.modulate = Color(0.85, 0.85, 0.85)
	label.custom_minimum_size = Vector2(0.0, 28.0)
	_extension_rows.add_child(label)


## 创建扩展行控件并连接选择、详情按钮，记录对应的启用复选框。
## [br]
## @api private
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


## 写入当前选择与选项并保存；保存失败时显示错误且不刷新面板状态。
## [br]
## @api private
func _apply_selection() -> void:
	_write_selection_to_project_settings()
	var save_error: Error = _save_project_settings()
	if save_error != OK:
		_set_status("保存失败（%s），内存设置尚未写入 project.godot，请重试。" % error_string(save_error))
		return
	_refresh_extensions()
	_set_status("扩展设置已保存。")


## 按默认或显式选择模式写入扩展 ID，并写入 installer 与导出选项。
## [br]
## @api private
func _write_selection_to_project_settings() -> void:
	if _selection_mode == GFExtensionSettingsBase.SELECTION_MODE_DEFAULT:
		GFExtensionSettingsBase.use_default_extension_selection()
	else:
		GFExtensionSettingsBase.set_enabled_extension_ids(_get_selected_enabled_ids(), true)
	GFExtensionSettingsBase.set_auto_install_enabled_installers(_auto_install_check.button_pressed)
	GFExtensionSettingsBase.set_export_exclude_disabled_extensions(_export_exclude_check.button_pressed)
	GFExtensionSettingsBase.set_fail_export_on_disabled_extension_references(_export_fail_check.button_pressed)


## 将当前所有清单项设为给定启用值并切换到显式选择模式。
## [br]
## @api private
func _set_all_enabled(enabled: bool) -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_EXPLICIT
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = enabled
	_invalidate_usage_report()
	_refresh_visible_extension_rows()
	_refresh_selected_manifest_details()
	_set_status("选择已更新，点击“保存设置”后生效。")


## 将选择模式切回默认，并按默认启用 ID 更新当前清单选择。
## [br]
## @api private
func _restore_default_selection() -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_DEFAULT
	var default_ids: Array[String] = GFExtensionSettingsBase.get_default_enabled_extension_ids()
	for manifest: GFExtensionManifest in _manifests:
		_selection_by_id[manifest.id] = default_ids.has(manifest.id)
	_invalidate_usage_report()
	_refresh_visible_extension_rows()
	_refresh_selected_manifest_details()
	_set_status("已恢复默认选择，点击“保存设置”后生效。")


## 重新填充组合下拉框的名称、ID 元数据与说明提示，并按条目数设置禁用状态。
## [br]
## @api private
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


## 读取当前组合 ID；无可选 ID 时显示提示，否则应用该组合。
## [br]
## @api private
func _apply_selected_preset() -> void:
	var preset_id: StringName = _get_selected_preset_id()
	if preset_id == &"":
		_set_status("没有可应用的扩展组合。")
		return

	var _applied: bool = _apply_extension_preset_by_id(preset_id)


## 确保组合文件对话框存在后打开它；创建失败时更新状态文本。
## [br]
## @api private
func _open_preset_file_dialog() -> void:
	_ensure_preset_file_dialog()
	if _preset_file_dialog == null:
		_set_status("无法打开扩展组合文件选择器。")
		return

	_preset_file_dialog.popup_centered_ratio(0.5)


## 在对话框尚不可用时创建 JSON 文件选择器并连接 file_selected 信号。
## [br]
## @api private
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


## 将项目 preset 路径交给扩展设置服务；成功后刷新组合列表并更新状态。
## [br]
## @api private
func _add_extension_preset_path(path: String) -> bool:
	if not GFExtensionSettingsBase.add_extension_preset_path(path):
		_set_status("扩展组合文件无效或已存在。")
		return false

	_refresh_preset_options()
	_set_status("已添加扩展组合文件，点击“保存设置”后生效。")
	return true


## 移除当前选择的项目 preset 路径；空选择、内置组合或移除失败时返回 false。
## [br]
## @api private
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


## 读取并校验组合、解析其依赖选择，再更新当前选择图和详情显示。
## [br]
## @api private
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
	_invalidate_usage_report()
	_refresh_visible_extension_rows()
	_refresh_selected_manifest_details()
	_set_status("已应用扩展组合“%s”，点击“保存设置”后生效。" % preset.display_name)
	return true


## 将指定清单的元数据、校验错误和可用引用风险写入详情文本。
## [br]
## @api private
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
	_append_packed_string(lines, "工作区短标签：%s" % (manifest.editor_dock_short_label if not manifest.editor_dock_short_label.is_empty() else "-"))
	_append_packed_string(lines, "工作区排序：%d" % manifest.editor_dock_order)
	_append_packed_string(
		lines,
		"编辑器工具贡献：editor/gf_tool_contribution.json（如存在则独立校验）"
	)
	_append_packed_string(lines, "标签：%s" % _format_string_array(manifest.tags))
	_append_usage_warning_lines(lines, manifest)

	var errors: Array[String] = manifest.get_validation_errors()
	if not errors.is_empty():
		_append_packed_string(lines, "")
		_append_packed_string(lines, "校验问题：")
		for error: String in errors:
			_append_packed_string(lines, "- %s" % error)

	_details_output.text = "\n".join(lines)


## 返回通过当前搜索条件的清单子集，保持原清单顺序。
## [br]
## @api private
func _get_visible_manifests() -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in _manifests:
		if not _matches_search(manifest):
			continue
		result.append(manifest)
	return result


## 将名称、ID、说明、类型和标签拼合后与去空格转小写的查询文本比较。
## [br]
## @api private
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


## 收集当前选择字典中已启用的清单 ID，并按字母顺序排序。
## [br]
## @api private
func _get_selected_enabled_ids() -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in _manifests:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
			ids.append(manifest.id)
	ids.sort()
	return ids


## 当前组合选择无效时返回空 StringName，否则将选中项元数据转换为 ID。
## [br]
## @api private
func _get_selected_preset_id() -> StringName:
	if _preset_option == null or _preset_option.item_count == 0 or _preset_option.selected < 0:
		return &""

	var raw_id: Variant = _preset_option.get_item_metadata(_preset_option.selected)
	return StringName(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_id))


## 返回当前选择字典中未启用的清单。
## [br]
## @api private
func _get_disabled_manifests_from_selection() -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in _manifests:
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
			manifests.append(manifest)
	return manifests


## 构造管理面板引用审计参数，包含忽略根目录与每个扩展的引用上限。
## [br]
## @api private
func _make_usage_audit_options() -> Dictionary:
	return {
		"ignored_roots": USAGE_AUDIT_IGNORED_ROOTS,
		"max_references_per_extension": 20,
	}


## 使用当前禁用清单和审计选项重新计算引用报告。
## [br]
## @api private
func _refresh_usage_report() -> void:
	_usage_report = GFExtensionUsageAuditBase.audit_disabled_extensions(
		_get_disabled_manifests_from_selection(),
		_make_usage_audit_options()
	)


## 推进扫描输入代次；已有报告首次过期时更新过期标记、选中扩展详情与状态。
## [br]
## @api private
func _invalidate_usage_report() -> void:
	_usage_input_generation += 1
	if _usage_report.is_empty() or _usage_report_stale:
		return
	_usage_report_stale = true
	_refresh_selected_manifest_details()
	_set_selection_status()


## 根据报告缺失、失效、扫描不完整或引用计数生成状态说明。
## [br]
## @api private
func _format_usage_status() -> String:
	if _usage_report.is_empty():
		return "引用审计未扫描；点击“扫描引用”检查当前选择。"
	if _usage_report_stale:
		return "引用审计已失效；选择、设置或项目文件已变化，请重新扫描。"
	var reference_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_usage_report, "reference_count", 0)
	if (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_usage_report, "partial_scan")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_usage_report, "budget_exceeded")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_usage_report, "issue_count") > 0
		or (not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_usage_report, "ok") and reference_count == 0)
	):
		return "引用审计扫描不完整：已发现 %d 处禁用扩展引用，不能据此确认排除安全。" % reference_count
	if reference_count > 0:
		return "引用审计扫描完成：发现 %d 处禁用扩展引用，请检查详情。" % reference_count
	return "引用审计扫描完成：本次扫描范围内未发现禁用扩展的直接引用。"


## 对禁用清单追加审计状态及其引用明细，最多列出前 8 条路径和行号。
## [br]
## @api private
func _append_usage_warning_lines(lines: PackedStringArray, manifest: GFExtensionManifest) -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(_selection_by_id, manifest.id, false):
		return
	_append_packed_string(lines, "")
	_append_packed_string(lines, _format_usage_status())
	if _usage_report.is_empty() or _usage_report_stale:
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


## 将 GF 标准类型和扩展类型映射为界面中文标签。
## [br]
## @api private
func _format_kind(kind: String) -> String:
	match kind:
		GFExtensionManifest.KIND_EXTENSION:
			return "扩展"
		GFExtensionManifest.KIND_STANDARD:
			return "标准"
		_:
			return kind


## 将依赖 ID 转为显示名称；空数组显示“无”。
## [br]
## @api private
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


## 将字符串数组以逗号和空格连接；空数组显示“无”。
## [br]
## @api private
func _format_string_array(values: Array[String]) -> String:
	if values.is_empty():
		return "无"
	return _join_strings(values)


## 复制字符串数组到 PackedStringArray 后以逗号和空格连接。
## [br]
## @api private
func _join_strings(values: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for value: String in values:
		_append_packed_string(packed, value)
	return ", ".join(packed)


## 汇总当前模式、已启用数量和清单总数并更新状态标签。
## [br]
## @api private
func _set_selection_status() -> void:
	var enabled_count: int = _get_selected_enabled_ids().size()
	var mode_label: String = "默认" if _selection_mode == GFExtensionSettingsBase.SELECTION_MODE_DEFAULT else "显式"
	_set_status("%s模式：已选择 %d / %d 个扩展。" % [
		mode_label,
		enabled_count,
		_manifests.size(),
	])


## 将指定消息与当前引用审计状态组合后交给工作区 UI 设置状态标签。
## [br]
## @api private
func _set_status(message: String) -> void:
	GFEditorWorkspaceUI.set_status(_status_label, "%s %s" % [message, _format_usage_status()])


## 记录扫描前的输入代次并刷新禁用扩展引用报告；扫描期间输入改变时将报告标为过期，随后刷新详情与状态。
## [br]
## @api private
func _scan_disabled_extension_references() -> void:
	var input_generation: int = _usage_input_generation
	_refresh_usage_report()
	_usage_report_stale = input_generation != _usage_input_generation
	_refresh_selected_manifest_details()
	_set_selection_status()


## 当前所选 ID 非空且仍在清单中时刷新对应详情文本。
## [br]
## @api private
func _refresh_selected_manifest_details() -> void:
	if _selected_manifest_id.is_empty():
		return

	for manifest: GFExtensionManifest in _manifests:
		if manifest.id == _selected_manifest_id:
			_show_manifest_details(manifest)
			return


# --- 信号处理函数 ---

## 将选择的文件路径登记为扩展预设路径。
## [br]
## @api private
func _on_preset_file_selected(path: String) -> void:
	var _added: bool = _add_extension_preset_path(path)


## 按最新搜索条件重建可见扩展行并更新状态。
## [br]
## @api private
func _on_search_changed(_new_text: String) -> void:
	_refresh_visible_extension_rows()
	_set_selection_status()


## 将当前扩展使用报告标记为需要重新扫描。
## [br]
## @api private
func _on_audit_inputs_changed() -> void:
	_invalidate_usage_report()


## 资源重导入或重载后使整份使用报告失效，不按传入路径缩小失效范围。
## [br]
## @api private
func _on_audit_resources_changed(_paths: PackedStringArray) -> void:
	_invalidate_usage_report()


## 更新扩展的显式启用选择并使引用报告失效；选中扩展受影响时刷新详情，提示设置保存后生效。
## [br]
## @api private
func _on_extension_toggled(enabled: bool, extension_id: String) -> void:
	_selection_mode = GFExtensionSettingsBase.SELECTION_MODE_EXPLICIT
	_selection_by_id[extension_id] = enabled
	_invalidate_usage_report()
	if extension_id == _selected_manifest_id:
		for manifest: GFExtensionManifest in _manifests:
			if manifest.id == extension_id:
				_show_manifest_details(manifest)
				break
	_set_status("选择已更新，点击“保存设置”后生效。")
