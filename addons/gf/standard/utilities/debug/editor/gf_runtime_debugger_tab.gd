@tool

## GFRuntimeDebuggerTab: GF 运行时调试会话页。
##
## 通过 Godot EditorDebuggerSession 向正在运行的游戏请求 GFDiagnosticsUtility 快照，
## 并以只读树和 JSON 详情展示返回数据。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
class_name GFRuntimeDebuggerTab
extends Control


# --- 常量 ---

const _EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _session: EditorDebuggerSession = null
var _session_id: int = -1
var _last_snapshot: Dictionary = {}
var _last_catalog: Dictionary = {}
var _last_command_result: Dictionary = {}
var _preset_option: OptionButton = null
var _include_scene_tree_check: CheckBox = null
var _include_logs_check: CheckBox = null
var _command_edit: LineEdit = null
var _summary_label: Label = null
var _empty_label: Label = null
var _tree: Tree = null
var _details: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Runtime"
	_build_ui()


# --- 公共方法 ---

## 绑定调试会话。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param session: Godot 调试会话。
## [br]
## @param session_id: 会话 ID。
func setup_session(session: EditorDebuggerSession, session_id: int) -> void:
	_session = session
	_session_id = session_id
	_set_status("等待运行中的 GFDiagnosticsUtility 响应。", _EDITOR_WORKSPACE_UI.INFO_TEXT_COLOR)


## 请求运行时诊断快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 消息是否已发送。
func request_snapshot() -> bool:
	return _send_debugger_message(GFDiagnosticsUtility.DEBUGGER_MESSAGE_REQUEST_SNAPSHOT, [_make_snapshot_options()])


## 请求运行时诊断目录。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 消息是否已发送。
func request_catalog() -> bool:
	return _send_debugger_message(GFDiagnosticsUtility.DEBUGGER_MESSAGE_REQUEST_CATALOG, [])


## 执行运行时诊断命令。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param command_name: 命令名。
## [br]
## @param args: 命令参数。
## [br]
## @return 消息是否已发送。
## [br]
## @schema args: Dictionary diagnostic command arguments.
func execute_command(command_name: StringName, args: Dictionary = {}) -> bool:
	if command_name == &"":
		_set_status("诊断命令为空。", _EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)
		return false
	return _send_debugger_message(GFDiagnosticsUtility.DEBUGGER_MESSAGE_EXECUTE_COMMAND, [String(command_name), args])


## 处理运行时快照 payload。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param payload: 运行时返回的快照。
## [br]
## @schema payload: Dictionary snapshot payload.
func handle_snapshot(payload: Dictionary) -> void:
	_last_snapshot = payload.duplicate(true)
	_render_dictionary("snapshot", _last_snapshot)


## 处理运行时目录 payload。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param payload: 运行时返回的目录。
## [br]
## @schema payload: Dictionary catalog payload.
func handle_catalog(payload: Dictionary) -> void:
	_last_catalog = payload.duplicate(true)
	_render_dictionary("catalog", _last_catalog)


## 处理诊断命令结果。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param command_name: 命令名。
## [br]
## @param payload: 命令结果。
## [br]
## @schema payload: Dictionary command result payload.
func handle_command_result(command_name: StringName, payload: Dictionary) -> void:
	_last_command_result = {
		"command_name": command_name,
		"result": payload.duplicate(true),
	}
	_render_dictionary("command", _last_command_result)


## 获取页面调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 页面调试快照。
## [br]
## @schema return: Dictionary containing session_id, last_snapshot, last_catalog, last_command_result, and ui fields.
func get_debug_snapshot() -> Dictionary:
	_build_ui()
	return {
		"session_id": _session_id,
		"last_snapshot": _last_snapshot.duplicate(true),
		"last_catalog": _last_catalog.duplicate(true),
		"last_command_result": _last_command_result.duplicate(true),
		"ui": {
			"summary": _summary_label.text if _summary_label != null else "",
			"details": _details.text if _details != null else "",
			"tree_visible": _tree != null and _tree.visible,
			"empty_visible": _empty_label != null and _empty_label.visible,
		},
	}


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	if _tree != null:
		return

	_EDITOR_WORKSPACE_UI.apply_page_root(self)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("快照", "请求运行时 GF 诊断快照。", request_snapshot))
	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("目录", "请求运行时诊断命令和监控目录。", request_catalog))

	_preset_option = OptionButton.new()
	_preset_option.tooltip_text = "选择运行时监控预设。"
	_preset_option.add_item("全部", 0)
	_preset_option.set_item_metadata(0, &"")
	_add_monitor_preset_option(&"minimal", "Minimal")
	_add_monitor_preset_option(&"performance", "Performance")
	_add_monitor_preset_option(&"architecture", "Architecture")
	_add_monitor_preset_option(&"tools", "Tools")
	toolbar.add_child(_preset_option)

	_include_scene_tree_check = CheckBox.new()
	_include_scene_tree_check.text = "场景树"
	_include_scene_tree_check.tooltip_text = "请求运行时场景树摘要。"
	toolbar.add_child(_include_scene_tree_check)

	_include_logs_check = CheckBox.new()
	_include_logs_check.text = "日志"
	_include_logs_check.button_pressed = true
	_include_logs_check.tooltip_text = "请求最近日志。"
	toolbar.add_child(_include_logs_check)

	_command_edit = LineEdit.new()
	_command_edit.placeholder_text = "diagnostics.performance"
	_command_edit.tooltip_text = "输入已注册诊断命令名。"
	_command_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_command_edit)
	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("执行", "执行输入的诊断命令。", _on_execute_pressed))
	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("复制", "复制当前详情 JSON。", _on_copy_pressed))

	_summary_label = _EDITOR_WORKSPACE_UI.make_summary_label("等待运行时连接。")
	root_box.add_child(_summary_label)

	_empty_label = _EDITOR_WORKSPACE_UI.make_empty_label("运行游戏后点击“快照”或“目录”。项目需要启用并初始化 GFDiagnosticsUtility。")
	root_box.add_child(_empty_label)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "字段")
	_tree.set_column_title(1, "类型")
	_tree.set_column_title(2, "摘要")
	_tree.set_column_expand(2, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tree_connected: Error = _tree.item_selected.connect(_on_tree_item_selected) as Error
	split.add_child(_tree)

	_details = _EDITOR_WORKSPACE_UI.make_details_output()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_details)


func _add_monitor_preset_option(preset_id: StringName, label: String) -> void:
	var index: int = _preset_option.item_count
	_preset_option.add_item(label, index)
	_preset_option.set_item_metadata(index, preset_id)


func _make_snapshot_options() -> Dictionary:
	var preset_id: StringName = _get_selected_preset_id()
	var options: Dictionary = {
		"include_scene_tree": _include_scene_tree_check != null and _include_scene_tree_check.button_pressed,
		"include_recent_logs": _include_logs_check == null or _include_logs_check.button_pressed,
	}
	if preset_id != &"":
		options["monitor_preset"] = preset_id
	return options


func _get_selected_preset_id() -> StringName:
	if _preset_option == null:
		return &""
	var metadata: Variant = _preset_option.get_item_metadata(_preset_option.selected)
	return GFVariantData.to_string_name(metadata)


func _send_debugger_message(message: String, data: Array) -> bool:
	if _session == null or not _session.is_debuggable():
		_set_status("没有可用的运行时调试会话。", _EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)
		return false
	_session.send_message(message, data)
	_set_status("已发送请求：%s" % message, _EDITOR_WORKSPACE_UI.INFO_TEXT_COLOR)
	return true


func _render_dictionary(kind: String, payload: Dictionary) -> void:
	_build_ui()
	_tree.clear()
	_tree.visible = true
	_empty_label.visible = false
	_details.text = _safe_json(payload)
	_set_status(_make_summary(kind, payload), _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)

	var root_item: TreeItem = _tree.create_item()
	for key_text: String in _get_sorted_keys(payload):
		var value: Variant = payload[key_text]
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, key_text)
		item.set_text(1, _get_value_kind(value))
		item.set_text(2, _make_value_summary(value))
		item.set_metadata(0, _sanitize_for_display(value))
		_add_child_items(item, value)


func _add_child_items(parent: TreeItem, value: Variant) -> void:
	if not value is Dictionary:
		return
	var dictionary: Dictionary = value
	for key_text: String in _get_sorted_keys(dictionary):
		var child_value: Variant = dictionary[key_text]
		var item: TreeItem = _tree.create_item(parent)
		item.set_text(0, key_text)
		item.set_text(1, _get_value_kind(child_value))
		item.set_text(2, _make_value_summary(child_value))
		item.set_metadata(0, _sanitize_for_display(child_value))


func _make_summary(kind: String, payload: Dictionary) -> String:
	if kind == "snapshot":
		var architecture: Dictionary = GFVariantData.get_option_dictionary(payload, "architecture")
		var performance: Dictionary = GFVariantData.get_option_dictionary(payload, "performance")
		return "Snapshot  FPS：%.1f  Models：%d  Systems：%d  Utilities：%d" % [
			GFVariantData.get_option_float(performance, "fps", 0.0),
			GFVariantData.get_option_dictionary(architecture, "models").size(),
			GFVariantData.get_option_dictionary(architecture, "systems").size(),
			GFVariantData.get_option_dictionary(architecture, "utilities").size(),
		]
	if kind == "catalog":
		return "Catalog  Commands：%d  Monitors：%d" % [
			GFVariantData.get_option_dictionary(payload, "commands").size(),
			GFVariantData.get_option_dictionary(payload, "monitors").size(),
		]
	if kind == "command":
		var result: Dictionary = GFVariantData.get_option_dictionary(payload, "result")
		return "Command %s  %s" % [
			GFVariantData.get_option_string(payload, "command_name"),
			"OK" if GFVariantData.get_option_bool(result, "ok") else "Failed",
		]
	return "%s  %d fields" % [kind.capitalize(), payload.size()]


func _set_status(text: String, color: Color) -> void:
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, text, color)


func _get_sorted_keys(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var _key_appended: bool = keys.append(str(key))
	keys.sort()
	return keys


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
		var dictionary: Dictionary = value
		return "%d keys" % dictionary.size()
	if value is Array:
		var array: Array = value
		return "%d items" % array.size()
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return "%d items" % packed_strings.size()
	var text: String = str(value)
	return text.substr(0, 120) if text.length() > 120 else text


func _safe_json(value: Variant) -> String:
	return JSON.stringify(_sanitize_for_display(value), "\t")


func _sanitize_for_display(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var result: Dictionary = {}
		for key: Variant in dictionary.keys():
			result[str(key)] = _sanitize_for_display(dictionary[key])
		return result
	if value is Array:
		var array: Array = value
		var array_result: Array = []
		for item: Variant in array:
			array_result.append(_sanitize_for_display(item))
		return array_result
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		var string_array: Array[String] = []
		for item: String in packed_strings:
			string_array.append(item)
		return string_array
	if value is Object:
		return str(value)
	return value


# --- 信号处理函数 ---

func _on_execute_pressed() -> void:
	if _command_edit == null:
		return
	var command_name: StringName = StringName(_command_edit.text.strip_edges())
	var _sent: bool = execute_command(command_name)


func _on_copy_pressed() -> void:
	if _details == null or _details.text.is_empty():
		return
	DisplayServer.clipboard_set(_details.text)
	_set_status("已复制当前详情。", _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	_details.text = _safe_json(item.get_metadata(0))
