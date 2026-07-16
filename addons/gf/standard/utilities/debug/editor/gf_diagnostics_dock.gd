@tool

## GFDiagnosticsDock: GF 诊断工作区页面。
##
## 采集通用运行时、性能、监控和场景树诊断快照，供编辑器内只读查看。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFDiagnosticsDock
extends Control


# --- 常量 ---

const _EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _diagnostics: GFDiagnosticsUtility = null
var _last_snapshot: Dictionary = {}
var _preset_option: OptionButton = null
var _include_scene_tree_check: CheckBox = null
var _include_logs_check: CheckBox = null
var _summary_label: Label = null
var _empty_label: Label = null
var _tree: Tree = null
var _details: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Diagnostics"
	_EDITOR_WORKSPACE_UI.apply_page_root(self)
	_diagnostics = GFDiagnosticsUtility.new()
	_diagnostics.init()
	_build_ui()
	call_deferred("collect_snapshot")


func _exit_tree() -> void:
	if _diagnostics != null:
		_diagnostics.dispose()
	_diagnostics = null


# --- 公共方法 ---

## 采集诊断快照。
## [br]
## @api public
func collect_snapshot() -> void:
	_build_ui()
	if _diagnostics == null:
		_render_empty("诊断工具不可用。")
		return

	_last_snapshot = _diagnostics.collect_snapshot({
		"include_scene_tree": _include_scene_tree_check != null and _include_scene_tree_check.button_pressed,
		"include_recent_logs": _include_logs_check == null or _include_logs_check.button_pressed,
		"monitor_preset": _get_selected_preset_id(),
	})
	_render_snapshot()


## 获取最近一次诊断快照。
## [br]
## @api public
## [br]
## @return 快照副本。
## [br]
## @schema return: Dictionary，包含 GFDiagnosticsUtility.collect_snapshot() 返回的诊断分区。
func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


## 获取面板调试快照。
## [br]
## @api public
## [br]
## @return 面板调试快照。
## [br]
## @schema return: Dictionary，包含 last_snapshot、summary_text、details_text 和 ui 分区。
func get_debug_snapshot() -> Dictionary:
	_build_ui()
	return {
		"last_snapshot": get_last_snapshot(),
		"summary_text": _summary_label.text if _summary_label != null else "",
		"details_text": _details.text if _details != null else "",
		"ui": {
			"tree_visible": _tree != null and _tree.visible,
			"empty_visible": _empty_label != null and _empty_label.visible,
			"empty_text": _empty_label.text if _empty_label != null else "",
			"include_scene_tree": _include_scene_tree_check != null and _include_scene_tree_check.button_pressed,
			"include_logs": _include_logs_check == null or _include_logs_check.button_pressed,
			"selected_preset": _get_selected_preset_id(),
		},
	}


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	if _tree != null:
		return

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("采集", "采集当前诊断快照。", collect_snapshot))

	_preset_option = OptionButton.new()
	_preset_option.tooltip_text = "选择诊断监控预设。"
	_preset_option.add_item("全部监控", 0)
	_preset_option.set_item_metadata(0, &"")
	_add_monitor_preset_option(&"minimal", "Minimal")
	_add_monitor_preset_option(&"performance", "Performance")
	_add_monitor_preset_option(&"architecture", "Architecture")
	_add_monitor_preset_option(&"tools", "Tools")
	_add_monitor_preset_option(&"overlay", "Overlay")
	var _preset_connected: int = _preset_option.item_selected.connect(_on_option_selected)
	toolbar.add_child(_preset_option)

	_include_scene_tree_check = CheckBox.new()
	_include_scene_tree_check.text = "场景树"
	_include_scene_tree_check.tooltip_text = "采集只读场景树摘要。"
	var _scene_tree_connected: int = _include_scene_tree_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_include_scene_tree_check)

	_include_logs_check = CheckBox.new()
	_include_logs_check.text = "最近日志"
	_include_logs_check.button_pressed = true
	_include_logs_check.tooltip_text = "快照中包含最近内存日志条目。"
	var _logs_connected: int = _include_logs_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_include_logs_check)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("复制快照", "复制当前诊断快照 JSON。", _on_copy_pressed))

	_summary_label = _EDITOR_WORKSPACE_UI.make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _EDITOR_WORKSPACE_UI.make_empty_label()
	root_box.add_child(_empty_label)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "分区")
	_tree.set_column_title(1, "项目")
	_tree.set_column_title(2, "摘要")
	_tree.set_column_expand(2, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tree_connected: int = _tree.item_selected.connect(_on_tree_item_selected)
	split.add_child(_tree)

	_details = _EDITOR_WORKSPACE_UI.make_details_output()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_details)


func _add_monitor_preset_option(preset_id: StringName, label: String) -> void:
	var index: int = _preset_option.item_count
	_preset_option.add_item(label, index)
	_preset_option.set_item_metadata(index, preset_id)


func _render_snapshot() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = _safe_json(_last_snapshot)
	_empty_label.visible = false
	_tree.visible = true
	_summary_label.text = _make_snapshot_summary(_last_snapshot)
	_summary_label.modulate = _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR

	var root_item: TreeItem = _tree.create_item()
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in _last_snapshot.keys():
		_append_packed_string(keys, GFVariantData.to_text(key))
	keys.sort()
	for key_text: String in keys:
		var value: Variant = _last_snapshot[key_text]
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, key_text)
		item.set_text(1, _get_value_kind(value))
		item.set_text(2, _make_value_summary(value))
		item.set_metadata(0, _sanitize_for_display(value))
		_add_child_items(item, value)


func _add_child_items(parent: TreeItem, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var dictionary: Dictionary = GFVariantData.as_dictionary(value)
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in dictionary.keys():
		_append_packed_string(keys, GFVariantData.to_text(key))
	keys.sort()
	for key_text: String in keys:
		var child_value: Variant = dictionary[key_text]
		var item: TreeItem = _tree.create_item(parent)
		item.set_text(0, key_text)
		item.set_text(1, _get_value_kind(child_value))
		item.set_text(2, _make_value_summary(child_value))
		item.set_metadata(0, _sanitize_for_display(child_value))


func _render_empty(message: String) -> void:
	if _tree != null:
		_tree.clear()
		_tree.visible = false
	if _details != null:
		_details.text = ""
	if _empty_label != null:
		_empty_label.text = message
		_empty_label.visible = true
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, message, _EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)


func _make_snapshot_summary(snapshot: Dictionary) -> String:
	var performance: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "performance", {}))
	var architecture: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "architecture", {}))
	var monitors: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "monitors", {}))
	var fps: float = GFVariantData.get_option_float(performance, "fps", 0.0)
	var model_count: int = _count_dictionary_section(architecture, "models")
	var system_count: int = _count_dictionary_section(architecture, "systems")
	var utility_count: int = _count_dictionary_section(architecture, "utilities")
	var monitor_count: int = GFVariantData.get_option_int(monitors, "monitor_count", 0)
	return "FPS：%.1f  Models：%d  Systems：%d  Utilities：%d  Monitors：%d" % [
		fps,
		model_count,
		system_count,
		utility_count,
		monitor_count,
	]


func _count_dictionary_section(source: Dictionary, key: String) -> int:
	var section: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, {}))
	return section.size()


func _get_selected_preset_id() -> StringName:
	if _preset_option == null:
		return &""
	var metadata: Variant = _preset_option.get_item_metadata(_preset_option.selected)
	return GFVariantData.to_string_name(metadata)


func _get_value_kind(value: Variant) -> String:
	if value is Dictionary:
		return "Dictionary"
	if value is Array:
		return "Array"
	if value is PackedStringArray:
		return "PackedStringArray"
	return type_string(typeof(value))


func _make_value_summary(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		return "%d keys" % dictionary.size()
	if value is Array:
		var array: Array = GFVariantData.as_array(value)
		return "%d items" % array.size()
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return "%d items" % packed_strings.size()
	var text: String = str(value)
	return text.substr(0, 120) if text.length() > 120 else text


func _safe_json(value: Variant) -> String:
	return GFReportValueCodec.stringify_json_compatible(
		value,
		"\t",
		false,
		GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG)
	)


func _sanitize_for_display(value: Variant) -> Variant:
	return GFReportValueCodec.to_json_compatible(
		value,
		GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG)
	)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


# --- 信号处理函数 ---

func _on_option_selected(_index: int) -> void:
	collect_snapshot()


func _on_option_toggled(_pressed: bool) -> void:
	collect_snapshot()


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	_details.text = _safe_json(item.get_metadata(0))


func _on_copy_pressed() -> void:
	if _last_snapshot.is_empty():
		return
	DisplayServer.clipboard_set(_safe_json(_last_snapshot))
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, "已复制诊断快照。", _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)
