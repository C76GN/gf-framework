@tool

# GF 资源路径输入与文件选择控件。
#
# 使用当前 Inspector 窗口下的 EditorFileDialog，避免独占编辑器窗口中打开全局 Quick Open。
extends HBoxContainer


# --- 信号 ---

## 用户提交新的资源路径后发出。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: 规范化后的 res://、uid:// 或空路径。
signal path_changed(path: String)


# --- 常量 ---

const _BROWSE_BUTTON_NAME: StringName = &"ResourcePathBrowseButton"
const _CLEAR_BUTTON_NAME: StringName = &"ResourcePathClearButton"
const _FILE_DIALOG_NAME: StringName = &"ResourcePathFileDialog"
const _BUTTON_MIN_WIDTH: float = 28.0
const _RESOURCE_PREFIX: String = "res://"
const _UID_PREFIX: String = "uid://"


# --- 私有变量 ---

var _path_edit: LineEdit
var _browse_button: Button
var _clear_button: Button
var _file_dialog: EditorFileDialog
var _committed_path: String = ""
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.placeholder_text = "res:// 或 uid://"
	var _text_submitted_connected: Error = _path_edit.text_submitted.connect(
		_on_text_submitted
	) as Error
	var _focus_exited_connected: Error = _path_edit.focus_exited.connect(
		_on_path_edit_focus_exited
	) as Error
	add_child(_path_edit)

	_browse_button = Button.new()
	_browse_button.name = _BROWSE_BUTTON_NAME
	_browse_button.text = "..."
	_browse_button.tooltip_text = "浏览项目资源"
	_browse_button.custom_minimum_size.x = _BUTTON_MIN_WIDTH
	var _browse_pressed_connected: Error = _browse_button.pressed.connect(
		_on_browse_pressed
	) as Error
	add_child(_browse_button)

	_clear_button = Button.new()
	_clear_button.name = _CLEAR_BUTTON_NAME
	_clear_button.text = "x"
	_clear_button.tooltip_text = "清除资源路径"
	_clear_button.custom_minimum_size.x = _BUTTON_MIN_WIDTH
	var _clear_pressed_connected: Error = _clear_button.pressed.connect(
		_on_clear_pressed
	) as Error
	add_child(_clear_button)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.name = _FILE_DIALOG_NAME
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.mode_overrides_title = false
	_file_dialog.title = "选择项目资源"
	_file_dialog.transient = true
	_file_dialog.exclusive = true
	var _file_selected_connected: Error = _file_dialog.file_selected.connect(
		_on_file_selected
	) as Error
	add_child(_file_dialog)

	_update_clear_button()


# --- Godot 回调方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_editor_icons()


# --- 框架内部方法 ---

## 配置文件选择器允许显示的资源扩展名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param filters: FileDialog 过滤器列表。
func setup(filters: PackedStringArray = PackedStringArray()) -> void:
	_file_dialog.filters = filters.duplicate()
	_apply_editor_icons()


## 同步当前资源路径，不触发用户变更信号。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: 当前 res://、uid:// 或空路径。
func set_path(path: String) -> void:
	var normalized_path: String = path.strip_edges()
	_is_updating = true
	_committed_path = normalized_path
	_path_edit.text = normalized_path
	_update_clear_button()
	_is_updating = false


# --- 私有/辅助方法 ---

func _commit_path(path: String) -> void:
	if _is_updating:
		return
	var normalized_path: String = path.strip_edges()
	_path_edit.text = normalized_path
	if normalized_path == _committed_path:
		_update_clear_button()
		return
	_committed_path = normalized_path
	_update_clear_button()
	path_changed.emit(normalized_path)


func _apply_editor_icons() -> void:
	if _browse_button == null or _clear_button == null:
		return
	_browse_button.text = "..."
	_clear_button.text = "x"
	var editor_root: Control = EditorInterface.get_base_control()
	if editor_root == null:
		return
	var browse_icon: Texture2D = editor_root.get_theme_icon(&"Load", &"EditorIcons")
	if browse_icon != null:
		_browse_button.icon = browse_icon
		_browse_button.text = ""
	var clear_icon: Texture2D = editor_root.get_theme_icon(&"Clear", &"EditorIcons")
	if clear_icon != null:
		_clear_button.icon = clear_icon
		_clear_button.text = ""


func _prepare_dialog_path() -> void:
	var resolved_path: String = _resolve_resource_path(_committed_path)
	if resolved_path.is_empty() or not resolved_path.begins_with(_RESOURCE_PREFIX):
		return
	_file_dialog.current_dir = resolved_path.get_base_dir()
	_file_dialog.current_file = resolved_path.get_file()


func _resolve_resource_path(path: String) -> String:
	if path.begins_with(_RESOURCE_PREFIX):
		return path
	if not path.begins_with(_UID_PREFIX):
		return ""
	var uid: int = ResourceUID.text_to_id(path)
	if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
		return ""
	return ResourceUID.get_id_path(uid)


func _update_clear_button() -> void:
	if _clear_button != null:
		_clear_button.disabled = _committed_path.is_empty()


# --- 信号处理函数 ---

func _on_text_submitted(text: String) -> void:
	_commit_path(text)


func _on_path_edit_focus_exited() -> void:
	_commit_path(_path_edit.text)


func _on_browse_pressed() -> void:
	_prepare_dialog_path()
	_file_dialog.popup_file_dialog()


func _on_clear_pressed() -> void:
	_commit_path("")


func _on_file_selected(path: String) -> void:
	_commit_path(path)
