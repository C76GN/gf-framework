@tool

## GFStorageViewerDock: 开发期本地存档查看面板。
##
## 用 GFStorageCodec 解码本地存档字节，便于编辑器内排查存档内容与完整性状态。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFStorageViewerDock
extends VBoxContainer


# --- 常量 ---

const _SAVE_VIEWER_FORMAT_JSON: int = 0
const _SAVE_VIEWER_FORMAT_BINARY: int = 1
const _SAVE_VIEWER_LABEL_WIDTH: float = 72.0
const _GFEditorWorkspaceUI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _path_edit: LineEdit
var _format_option: OptionButton
var _obfuscation_key_spin: SpinBox
var _compression_check: CheckBox
var _checksum_check: CheckBox
var _strict_check: CheckBox
var _status_label: Label
var _output: TextEdit
var _file_dialog: FileDialog


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Storage Viewer"
	_GFEditorWorkspaceUI.apply_page_root(self)
	_build_ui()


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var path_row: HBoxContainer = _GFEditorWorkspaceUI.make_toolbar()
	add_child(path_row)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "user://saves/slot_1_data.sav 或本地绝对路径"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_path_edit)

	path_row.add_child(_GFEditorWorkspaceUI.make_button("...", "选择存档文件。", _on_browse_pressed))

	_format_option = OptionButton.new()
	_format_option.add_item("JSON", _SAVE_VIEWER_FORMAT_JSON)
	_format_option.add_item("二进制", _SAVE_VIEWER_FORMAT_BINARY)
	_format_option.selected = 0
	add_child(_make_labeled_row("格式", _format_option))

	_obfuscation_key_spin = SpinBox.new()
	_obfuscation_key_spin.min_value = 0.0
	_obfuscation_key_spin.max_value = 255.0
	_obfuscation_key_spin.step = 1.0
	_obfuscation_key_spin.value = 42.0
	add_child(_make_labeled_row("XOR 密钥", _obfuscation_key_spin))

	_compression_check = CheckBox.new()
	_compression_check.text = "压缩"
	add_child(_compression_check)

	_checksum_check = CheckBox.new()
	_checksum_check.text = "校验 checksum"
	add_child(_checksum_check)

	_strict_check = CheckBox.new()
	_strict_check.text = "严格完整性"
	_strict_check.button_pressed = true
	add_child(_strict_check)

	var button_row: HBoxContainer = _GFEditorWorkspaceUI.make_toolbar()
	add_child(button_row)

	button_row.add_child(_GFEditorWorkspaceUI.make_button("加载", "读取并解码当前存档文件。", _on_load_pressed))
	button_row.add_child(_GFEditorWorkspaceUI.make_button("复制", "复制解码后的 JSON。", _on_copy_pressed))

	_status_label = _GFEditorWorkspaceUI.make_summary_label("选择存档文件和匹配的 codec 选项。")
	add_child(_status_label)

	_output = _GFEditorWorkspaceUI.make_details_output()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_output)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	var _connect_result_100: Variant = _file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _make_labeled_row(label_text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(_SAVE_VIEWER_LABEL_WIDTH, 0.0)
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _create_codec() -> GFStorageCodec:
	return GFStorageCodec.new()


func _get_selected_format() -> int:
	return _format_option.get_selected_id()


func _set_status(message: String, is_error: bool) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
		_status_label.modulate = _GFEditorWorkspaceUI.ERROR_TEXT_COLOR if is_error else _GFEditorWorkspaceUI.OK_TEXT_COLOR
	if is_error:
		push_warning("[GF Storage Viewer] " + message)


func _format_decoded_data_for_display(data: Dictionary) -> String:
	return GFVariantJsonCodec.stringify_json_compatible(data, "\t", true, {
		"unsupported": "string",
	})


# --- 信号处理函数 ---

func _on_browse_pressed() -> void:
	if is_instance_valid(_file_dialog):
		_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	if is_instance_valid(_path_edit):
		_path_edit.text = path


func _on_load_pressed() -> void:
	var path: String = _path_edit.text.strip_edges()
	if path.is_empty():
		_set_status("路径为空。", true)
		return
	if not FileAccess.file_exists(path):
		_set_status("文件不存在：%s" % path, true)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("无法打开文件：%s" % error_string(FileAccess.get_open_error()), true)
		return

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var codec: GFStorageCodec = _create_codec()
	if codec == null:
		_output.text = ""
		_set_status("Storage codec 不可用。", true)
		return

	var result: GFStorageReadResult = codec.decode(bytes, {
		"format": _get_selected_format(),
		"obfuscation_key": int(_obfuscation_key_spin.value),
		"use_compression": _compression_check.button_pressed,
		"use_integrity_checksum": _checksum_check.button_pressed,
		"strict_integrity": _strict_check.button_pressed,
	})

	if not result.ok:
		_output.text = ""
		_set_status(result.error if not result.error.is_empty() else "解码失败。", true)
		return

	var data: Dictionary = result.payload.duplicate(true)
	_output.text = _format_decoded_data_for_display(data)
	_set_status(
		"已加载：%d bytes，%d 个顶层键，完整性=%s" % [
			bytes.size(),
			data.size(),
			str(result.is_integrity_accepted()),
		],
		false
	)


func _on_copy_pressed() -> void:
	if _output == null or _output.text.is_empty():
		return
	DisplayServer.clipboard_set(_output.text)
	_set_status("已复制 JSON 到剪贴板。", false)
