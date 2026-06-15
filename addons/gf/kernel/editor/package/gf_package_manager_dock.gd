@tool

# GF 包管理器工作区页面。
#
# 通过 Godot 原生后端读取 registry / lockfile 状态，并执行安装、卸载和预览。
extends VBoxContainer


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PACKAGE_MANAGER_BACKEND = preload("res://addons/gf/kernel/package/gf_package_manager_backend.gd")
const _MAX_UNINSTALL_BLOCKER_DETAIL_LINES: int = 5

## 工作区 UI 辅助脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorWorkspaceUI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 包状态行最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PACKAGE_ROW_MIN_HEIGHT: float = 30.0

## 包详情区最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DETAILS_MIN_HEIGHT: float = 180.0

## 默认本地 registry source manifest 相对路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_LOCAL_REGISTRY_SOURCE_PATH: String = "build/registry/gf-registry-source.json"

## 默认本地 registry index 相对路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_LOCAL_REGISTRY_PATH: String = "build/registry/index.json"

## 默认包 lockfile 相对项目路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_LOCKFILE_PATH: String = ".gf/packages.lock.json"

## 推荐组合视图过滤值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VIEW_FILTER_PRESETS: String = "presets"

## 扩展包视图过滤值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VIEW_FILTER_EXTENSIONS: String = "extensions"

## 标准包视图过滤值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VIEW_FILTER_STANDARD: String = "standard"

## 全部包视图过滤值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VIEW_FILTER_ALL: String = "all"


# --- 私有变量 ---

var _registry_field: LineEdit
var _channel_field: LineEdit
var _view_filter_option: OptionButton
var _search_field: LineEdit
var _package_rows: VBoxContainer
var _details_output: TextEdit
var _registry_diagnostics_label: Label
var _status_label: Label
var _install_plan_button: Button
var _install_button: Button
var _uninstall_plan_button: Button
var _uninstall_button: Button
var _confirm_dialog: ConfirmationDialog
var _confirm_operation: String = ""
var _packages: Array[Dictionary] = []
var _selected_package_id: String = ""
var _last_status: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Package Manager"
	GFEditorWorkspaceUI.apply_page_root(self)
	_build_ui()
	call_deferred("_refresh_status")


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var registry_row: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(registry_row)

	var registry_label: Label = _make_fixed_label("Registry", 64.0)
	registry_row.add_child(registry_label)

	_registry_field = LineEdit.new()
	_registry_field.text = _get_default_registry_value()
	_registry_field.placeholder_text = "留空使用默认在线源；也可填写本地 index.json、offline bundle zip 或 HTTPS URL"
	_registry_field.tooltip_text = "支持默认 GF release registry source、本地 index.json、offline bundle zip、source manifest 或 HTTP(S) URL。"
	_registry_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	registry_row.add_child(_registry_field)

	var channel_label: Label = _make_fixed_label("Channel", 62.0)
	registry_row.add_child(channel_label)

	_channel_field = LineEdit.new()
	_channel_field.placeholder_text = "默认"
	_channel_field.tooltip_text = "当 Registry 指向 source manifest 时使用；留空表示 default_channel。"
	_channel_field.custom_minimum_size = Vector2(92.0, 0.0)
	registry_row.add_child(_channel_field)

	registry_row.add_child(GFEditorWorkspaceUI.make_button("刷新", "重新读取 package registry 和项目 lockfile。", _refresh_status))

	_registry_diagnostics_label = GFEditorWorkspaceUI.make_summary_label()
	add_child(_registry_diagnostics_label)

	var action_row: HBoxContainer = GFEditorWorkspaceUI.make_toolbar()
	add_child(action_row)

	_view_filter_option = OptionButton.new()
	_view_filter_option.tooltip_text = "切换推荐组合、扩展包、标准包或全部包。"
	_view_filter_option.custom_minimum_size = Vector2(112.0, 0.0)
	_view_filter_option.add_item("推荐组合")
	_view_filter_option.set_item_metadata(0, VIEW_FILTER_PRESETS)
	_view_filter_option.add_item("扩展包")
	_view_filter_option.set_item_metadata(1, VIEW_FILTER_EXTENSIONS)
	_view_filter_option.add_item("标准包")
	_view_filter_option.set_item_metadata(2, VIEW_FILTER_STANDARD)
	_view_filter_option.add_item("全部包")
	_view_filter_option.set_item_metadata(3, VIEW_FILTER_ALL)
	_connect_signal_checked(_view_filter_option.item_selected, _on_view_filter_selected)
	action_row.add_child(_view_filter_option)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "搜索包 ID、名称、描述"
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_signal_checked(_search_field.text_changed, _on_search_changed)
	action_row.add_child(_search_field)

	_install_plan_button = GFEditorWorkspaceUI.make_button("预览安装", "对选中包执行 dry-run install。", _preview_install)
	action_row.add_child(_install_plan_button)

	_install_button = GFEditorWorkspaceUI.make_button("安装", "安装选中包及依赖。", _request_install)
	action_row.add_child(_install_button)

	_uninstall_plan_button = GFEditorWorkspaceUI.make_button("预览卸载", "对选中包执行 dry-run uninstall。", _preview_uninstall)
	action_row.add_child(_uninstall_plan_button)

	_uninstall_button = GFEditorWorkspaceUI.make_button("卸载", "卸载选中包，保留共享依赖和被引用包。", _request_uninstall)
	action_row.add_child(_uninstall_button)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var list_panel: VBoxContainer = VBoxContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(list_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)

	_package_rows = VBoxContainer.new()
	_package_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_package_rows)

	_details_output = GFEditorWorkspaceUI.make_details_output(DETAILS_MIN_HEIGHT)
	_details_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_details_output)

	_status_label = GFEditorWorkspaceUI.make_summary_label()
	add_child(_status_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "确认包操作"
	add_child(_confirm_dialog)
	_connect_signal_checked(_confirm_dialog.confirmed, _on_confirmed)
	_update_action_buttons()


func _make_fixed_label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	return label


func _connect_signal_checked(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	if source_signal.is_null() or not callback.is_valid():
		return
	if source_signal.is_connected(callback):
		return

	var error: Error = source_signal.connect(callback, flags as Object.ConnectFlags) as Error
	if error != OK:
		push_warning("[GFPackageManagerDock] Signal 连接失败：%s" % error_string(error))


func _get_project_root() -> String:
	return ProjectSettings.globalize_path("res://")


func _get_default_registry_value() -> String:
	var local_source_path: String = ProjectSettings.globalize_path("res://" + DEFAULT_LOCAL_REGISTRY_SOURCE_PATH)
	if FileAccess.file_exists(local_source_path):
		return local_source_path
	var local_path: String = ProjectSettings.globalize_path("res://" + DEFAULT_LOCAL_REGISTRY_PATH)
	if FileAccess.file_exists(local_path):
		return local_path
	var default_source: String = _GF_PACKAGE_MANAGER_BACKEND.get_default_registry_source_url()
	if not default_source.is_empty():
		return default_source
	return ""


func _get_channel_value() -> String:
	if _channel_field == null:
		return ""
	return _channel_field.text.strip_edges()


func _make_backend_options() -> Dictionary:
	var options: Dictionary = {}
	var channel: String = _get_channel_value()
	if not channel.is_empty():
		options["channel"] = channel
	return options


func _refresh_status() -> void:
	var result: Dictionary = _run_package_status(_registry_field.text.strip_edges())
	_last_status = result
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false):
		_packages.clear()
		_clear_package_rows()
		_details_output.text = _format_command_result(result)
		_update_registry_diagnostics(result)
		_set_status("包状态读取失败。", GFEditorWorkspaceUI.ERROR_TEXT_COLOR)
		_update_action_buttons()
		return

	_packages = _read_package_entries(result)
	_render_package_rows()
	_select_first_visible_package()
	_update_registry_diagnostics(result)
	var backend_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "backend", "godot")
	_set_status(
		"包状态已更新（%s）：%d 个包，已安装 %d 个。" % [
			backend_label,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "package_count", 0),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(result, "installed_count", 0),
		],
		GFEditorWorkspaceUI.OK_TEXT_COLOR
	)


func _read_package_entries(status_data: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var raw_packages: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(status_data.get("packages", []))
	for raw_package: Variant in raw_packages:
		if raw_package is Dictionary:
			var package_entry: Dictionary = raw_package
			entries.push_back(package_entry.duplicate(true))
	entries.sort_custom(Callable(self, "_sort_package_entries"))
	return entries


func _render_package_rows() -> void:
	_clear_package_rows()
	for package_entry: Dictionary in _get_visible_packages():
		_package_rows.add_child(_create_package_row(package_entry))
	_update_action_buttons()


func _create_package_row(package_entry: Dictionary) -> Control:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(0.0, PACKAGE_ROW_MIN_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = _format_package_row_text(package_entry)
	row.tooltip_text = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "description", "")
	var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", "")
	var _connect_result: Variant = row.pressed.connect(_select_package.bind(package_id))
	return row


func _format_package_row_text(package_entry: Dictionary) -> String:
	var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", "")
	var kind: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "kind", "")
	var state: String = "已安装" if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(package_entry, "installed", false) else "可安装"
	var display_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "display_name", package_id)
	return "[%s] %s | %s | %s" % [state, kind, package_id, display_name]


func _get_visible_packages() -> Array[Dictionary]:
	var needle: String = _search_field.text.strip_edges().to_lower()
	var view_filter: String = _get_view_filter()
	var result: Array[Dictionary] = []
	for package_entry: Dictionary in _packages:
		if _package_matches_view_filter(package_entry, view_filter) and (needle.is_empty() or _package_matches_search(package_entry, needle)):
			result.push_back(package_entry)
	return result


func _package_matches_search(package_entry: Dictionary, needle: String) -> bool:
	var haystack: String = " ".join(PackedStringArray([
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", ""),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "display_name", ""),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "description", ""),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "kind", ""),
	])).to_lower()
	return haystack.contains(needle)


func _clear_package_rows() -> void:
	for child: Node in _package_rows.get_children():
		_package_rows.remove_child(child)
		child.queue_free()


func _select_first_visible_package() -> void:
	var visible_packages: Array[Dictionary] = _get_visible_packages()
	if visible_packages.is_empty():
		_selected_package_id = ""
		_details_output.text = ""
		_update_action_buttons()
		return

	if _selected_package_id.is_empty() or not _package_id_is_visible(_selected_package_id, visible_packages):
		_selected_package_id = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(visible_packages[0], "id", "")
	_show_selected_package_details()


func _select_package(package_id: String) -> void:
	_selected_package_id = package_id
	_show_selected_package_details()


func _show_selected_package_details() -> void:
	var package_entry: Dictionary = _get_package_entry(_selected_package_id)
	if package_entry.is_empty():
		_details_output.text = ""
		_update_action_buttons()
		return

	_details_output.text = _format_package_details(package_entry)
	_update_action_buttons()


func _get_package_entry(package_id: String) -> Dictionary:
	for package_entry: Dictionary in _packages:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", "") == package_id:
			return package_entry
	return {}


func _format_package_details(package_entry: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", "")
	var display_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "display_name", package_id)
	var _added_title: bool = lines.append("%s (%s)" % [display_name, package_id])
	var _added_kind: bool = lines.append("kind: %s" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "kind", ""))
	var _added_version: bool = lines.append("version: %s" % _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "version", ""))
	var _added_installed: bool = lines.append("installed: %s" % _GF_VARIANT_ACCESS_SCRIPT.to_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(package_entry, "installed", false)))
	_append_line_array(lines, "reason", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "reason"))
	_append_line_array(lines, "required_by", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "required_by"))
	_append_line_array(lines, "dependencies", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "dependencies"))
	_append_line_array(lines, "preset packages", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "packages"))
	_append_line_array(lines, "paths", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "paths"))
	var install_preview: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(package_entry, "install_preview", {})
	var uninstall_preview: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(package_entry, "uninstall_preview", {})
	_append_package_risk_summary(lines, package_entry, install_preview, uninstall_preview)
	var _added_install_preview: bool = lines.append("")
	var _added_install_header: bool = lines.append("install preview:")
	_append_line_array(lines, "  install_order", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "install_order"))
	_append_line_array(lines, "  to_install", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "to_install"))
	_append_line_array(lines, "  to_update", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "to_update"))
	if not uninstall_preview.is_empty():
		var _added_uninstall_preview: bool = lines.append("")
		var _added_uninstall_header: bool = lines.append("uninstall preview:")
		_append_line_array(lines, "  to_remove", _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(uninstall_preview, "to_remove"))
		var blocked_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(uninstall_preview, "blocked")
		var _added_blockers: bool = lines.append("  blockers: %d" % blocked_entries.size())
		_append_uninstall_blocker_lines(lines, blocked_entries)
	return "\n".join(lines)


func _append_package_risk_summary(
	lines: PackedStringArray,
	package_entry: Dictionary,
	install_preview: Dictionary,
	uninstall_preview: Dictionary
) -> void:
	var to_install: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "to_install")
	var to_update: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "to_update")
	var install_order: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(install_preview, "install_order")
	var _added_blank: bool = lines.append("")
	var _added_header: bool = lines.append("risk summary:")
	var _added_install: bool = lines.append("  install: %d new, %d update, order %d" % [
		to_install.size(),
		to_update.size(),
		install_order.size(),
	])
	var protection_summary: String = _format_package_protection_summary(package_entry)
	if protection_summary.is_empty():
		var _added_unprotected: bool = lines.append("  protected: -")
	else:
		var _added_protected: bool = lines.append("  protected: %s" % protection_summary)
	if uninstall_preview.is_empty():
		var _added_no_uninstall: bool = lines.append("  uninstall: no preview")
		return

	var to_remove: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(uninstall_preview, "to_remove")
	var blocked_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(uninstall_preview, "blocked")
	var uninstall_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(uninstall_preview, "ok", blocked_entries.is_empty())
	if not blocked_entries.is_empty():
		var _added_blocked: bool = lines.append("  uninstall: blocked %d, remove %d" % [
			blocked_entries.size(),
			to_remove.size(),
		])
	elif uninstall_ok:
		var _added_remove: bool = lines.append("  uninstall: remove %d" % to_remove.size())
	else:
		var _added_rejected: bool = lines.append("  uninstall: rejected, remove %d" % to_remove.size())


func _format_package_protection_summary(package_entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var reasons: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "reason")
	for reason: String in reasons:
		if reason == "manual" or reason == "preset" or reason == "bundled" or reason == "dev":
			_append_unique_text(parts, reason)
	var required_by: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(package_entry, "required_by")
	if not required_by.is_empty():
		_append_unique_text(parts, "required_by: %s" % _join_string_array(required_by))
	if parts.is_empty():
		return ""
	return ", ".join(parts)


func _append_uninstall_blocker_lines(lines: PackedStringArray, blocked_entries: Array) -> void:
	var limit: int = mini(blocked_entries.size(), _MAX_UNINSTALL_BLOCKER_DETAIL_LINES)
	for index: int in range(limit):
		var blocker: Variant = blocked_entries[index]
		var blocker_text: String = _format_uninstall_blocker(blocker)
		if not blocker_text.is_empty():
			var _added_blocker: bool = lines.append("  blocker: %s" % blocker_text)
	if blocked_entries.size() > limit:
		var _added_more: bool = lines.append("  blocker: +%d more" % (blocked_entries.size() - limit))


func _format_uninstall_blocker(blocker: Variant) -> String:
	if blocker is Dictionary:
		var blocker_data: Dictionary = blocker
		var parts: PackedStringArray = PackedStringArray()
		var reason: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(blocker_data, "reason")
		var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			blocker_data,
			"id",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(blocker_data, "package_id")
		)
		_append_unique_text(parts, reason)
		_append_unique_text(parts, package_id)
		var required_by: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(blocker_data, "required_by")
		if not required_by.is_empty():
			_append_unique_text(parts, "required_by: %s" % _join_string_array(required_by))
		var protected_reasons: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(blocker_data, "protected_reasons")
		if not protected_reasons.is_empty():
			_append_unique_text(parts, "protected: %s" % _join_string_array(protected_reasons))
		var references: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(blocker_data, "references")
		var reference_summary: String = _format_uninstall_reference_summary(references)
		_append_unique_text(parts, reference_summary)
		if not parts.is_empty():
			return " ".join(parts)
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(blocker)


func _format_uninstall_reference_summary(references: Array) -> String:
	if references.is_empty():
		return ""
	var first_reference: Variant = references[0]
	var summary: String = ""
	if first_reference is Dictionary:
		var reference_data: Dictionary = first_reference
		var path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_data, "path")
		var match_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_data, "match")
		if not path.is_empty() and not match_text.is_empty():
			summary = "%s (%s)" % [path, match_text]
		elif not path.is_empty():
			summary = path
		elif not match_text.is_empty():
			summary = match_text
	else:
		summary = _GF_VARIANT_ACCESS_SCRIPT.to_text(first_reference)
	if summary.is_empty():
		return ""
	if references.size() > 1:
		return "references: %s (+%d more)" % [summary, references.size() - 1]
	return "references: %s" % summary


func _update_registry_diagnostics(status_data: Dictionary) -> void:
	if _registry_diagnostics_label == null:
		return
	_registry_diagnostics_label.text = _format_registry_diagnostics(status_data)
	_registry_diagnostics_label.tooltip_text = _format_registry_diagnostics_tooltip(status_data)


func _format_registry_diagnostics(status_data: Dictionary) -> String:
	var source: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_source")
	var registry: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry")
	var offline_bundle: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_offline_bundle")
	var channel: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_channel")
	var mirror_index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(status_data, "registry_mirror_index", -2)
	var parts: PackedStringArray = PackedStringArray()
	var source_text: String = source if not source.is_empty() else registry
	if source_text.is_empty():
		var _append_empty_source: bool = parts.append("source: -")
	else:
		var _append_source: bool = parts.append("source: %s" % _shorten_middle(source_text, 84))
	if not channel.is_empty():
		var _append_channel: bool = parts.append("channel: %s" % channel)
	if mirror_index >= 0:
		var _append_mirror: bool = parts.append("mirror: #%d" % mirror_index)
	elif mirror_index == -1:
		var _append_primary: bool = parts.append("mirror: primary")
	if not offline_bundle.is_empty():
		var _append_offline: bool = parts.append("offline bundle")
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(status_data, "registry_remote", false):
		var _append_remote: bool = parts.append("remote")
	if parts.is_empty():
		return "Registry: -"
	return "Registry: %s" % " | ".join(parts)


func _format_registry_diagnostics_tooltip(status_data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	_append_line_value(lines, "registry", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry"))
	_append_line_value(lines, "source", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_source"))
	_append_line_value(lines, "offline_bundle", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_offline_bundle"))
	_append_line_value(lines, "offline_bundle_extracted", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_offline_bundle_extracted"))
	_append_line_value(lines, "source_manifest", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_source_manifest"))
	_append_line_value(lines, "channel", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_channel"))
	if status_data.has("registry_mirror_index"):
		var _append_mirror: bool = lines.append("mirror_index: %d" % _GF_VARIANT_ACCESS_SCRIPT.get_option_int(status_data, "registry_mirror_index", -2))
	_append_line_value(lines, "cache_dir", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status_data, "registry_cache_dir"))
	if lines.is_empty():
		return ""
	return "\n".join(lines)


func _append_line_value(lines: PackedStringArray, label: String, value: String) -> void:
	if value.is_empty():
		return
	var _append_result: bool = lines.append("%s: %s" % [label, value])


func _shorten_middle(value: String, max_length: int) -> String:
	if max_length <= 0 or value.length() <= max_length:
		return value
	if max_length <= 3:
		return value.substr(0, max_length)
	var left_length: int = maxi(1, floori(float(max_length - 3) / 2.0))
	var right_length: int = maxi(1, max_length - 3 - left_length)
	return "%s...%s" % [
		value.substr(0, left_length),
		value.substr(value.length() - right_length, right_length),
	]


func _append_line_array(lines: PackedStringArray, label: String, values: Array[String]) -> void:
	if values.is_empty():
		var _added_empty: bool = lines.append("%s: -" % label)
		return
	var _added_values: bool = lines.append("%s: %s" % [label, _join_string_array(values)])


func _join_string_array(values: Array[String]) -> String:
	var packed_values: PackedStringArray = PackedStringArray()
	for value: String in values:
		var _added_value: bool = packed_values.append(value)
	return ", ".join(packed_values)


func _append_unique_text(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	for existing_value: String in values:
		if existing_value == value:
			return
	var _added_value: bool = values.append(value)


func _get_view_filter() -> String:
	if _view_filter_option == null:
		return VIEW_FILTER_PRESETS
	var selected_index: int = _view_filter_option.selected
	if selected_index < 0:
		return VIEW_FILTER_PRESETS
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(_view_filter_option.get_item_metadata(selected_index))


func _package_matches_view_filter(package_entry: Dictionary, view_filter: String) -> bool:
	var kind: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "kind", "")
	if view_filter == VIEW_FILTER_PRESETS:
		return kind == "preset"
	if view_filter == VIEW_FILTER_EXTENSIONS:
		return kind == "extension"
	if view_filter == VIEW_FILTER_STANDARD:
		return kind == "standard"
	return true


func _package_id_is_visible(package_id: String, visible_packages: Array[Dictionary]) -> bool:
	for package_entry: Dictionary in visible_packages:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(package_entry, "id", "") == package_id:
			return true
	return false


func _sort_package_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_weight: int = _package_kind_sort_weight(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "kind", ""))
	var right_weight: int = _package_kind_sort_weight(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "kind", ""))
	if left_weight != right_weight:
		return left_weight < right_weight
	var left_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "id", "")
	var right_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "id", "")
	return left_id < right_id


func _package_kind_sort_weight(kind: String) -> int:
	if kind == "preset":
		return 0
	if kind == "extension":
		return 1
	if kind == "standard":
		return 2
	if kind == "kernel":
		return 3
	return 4


func _preview_install() -> void:
	_run_selected_operation("install", true)


func _preview_uninstall() -> void:
	_run_selected_operation("uninstall", true)


func _request_install() -> void:
	_open_confirm_dialog("install")


func _request_uninstall() -> void:
	_open_confirm_dialog("uninstall")


func _open_confirm_dialog(operation: String) -> void:
	if _selected_package_id.is_empty():
		return
	_confirm_operation = operation
	_confirm_dialog.dialog_text = "确认%s包：%s" % [_get_operation_label(operation), _selected_package_id]
	_confirm_dialog.popup_centered()


func _on_confirmed() -> void:
	if _confirm_operation.is_empty():
		return
	_run_selected_operation(_confirm_operation, false)
	_confirm_operation = ""


func _run_selected_operation(operation: String, dry_run: bool) -> void:
	if _selected_package_id.is_empty():
		return
	var result: Dictionary = _run_native_operation(operation, dry_run)
	_details_output.text = _format_command_result(result)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(result, "ok", false):
		_set_status("%s%s完成。" % ["Dry-run " if dry_run else "", _get_operation_label(operation)], GFEditorWorkspaceUI.OK_TEXT_COLOR)
		if not dry_run:
			_refresh_status()
	else:
		_set_status("%s失败。" % _get_operation_label(operation), GFEditorWorkspaceUI.ERROR_TEXT_COLOR)


func _run_native_operation(operation: String, dry_run: bool) -> Dictionary:
	var registry_value: String = _registry_field.text.strip_edges()
	var backend_options: Dictionary = _make_backend_options()
	if operation == "install" and _can_use_native_backend(registry_value):
		return _GF_PACKAGE_MANAGER_BACKEND.install_packages(
			PackedStringArray([_selected_package_id]),
			registry_value,
			_get_project_root(),
			DEFAULT_LOCKFILE_PATH,
			"manual",
			dry_run,
			backend_options
		)
	if operation == "uninstall" and _can_use_native_backend(registry_value):
		return _GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
			PackedStringArray([_selected_package_id]),
			registry_value,
			_get_project_root(),
			DEFAULT_LOCKFILE_PATH,
			false,
			dry_run,
			backend_options
		)
	return {}


func _run_package_status(registry_value: String) -> Dictionary:
	return _GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_value,
		_get_project_root(),
		DEFAULT_LOCKFILE_PATH,
		_make_backend_options()
	)


func _can_use_native_backend(_registry_value: String) -> bool:
	return true


func _get_operation_label(operation: String) -> String:
	if operation == "uninstall":
		return "卸载"
	return "安装"


func _format_command_result(result: Dictionary) -> String:
	return JSON.stringify(result, "\t", false)


func _update_action_buttons() -> void:
	var package_entry: Dictionary = _get_package_entry(_selected_package_id)
	var has_package: bool = not package_entry.is_empty()
	var installed: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(package_entry, "installed", false)
	_install_plan_button.disabled = not has_package
	_install_button.disabled = not has_package
	_uninstall_plan_button.disabled = not has_package or not installed
	_uninstall_button.disabled = not has_package or not installed


func _set_status(message: String, color: Color = GFEditorWorkspaceUI.INFO_TEXT_COLOR) -> void:
	GFEditorWorkspaceUI.set_status(_status_label, message, color)


# --- 信号处理函数 ---

func _on_search_changed(_text: String) -> void:
	_render_package_rows()
	_select_first_visible_package()


func _on_view_filter_selected(_index: int) -> void:
	_render_package_rows()
	_select_first_visible_package()
