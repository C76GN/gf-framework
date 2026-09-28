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

## 浏览按钮的稳定 Node 名。
## [br]
## @api private
const _BROWSE_BUTTON_NAME: StringName = &"ResourcePathBrowseButton"

## 清除按钮的稳定 Node 名。
## [br]
## @api private
const _CLEAR_BUTTON_NAME: StringName = &"ResourcePathClearButton"

## 文件选择对话框的稳定 Node 名。
## [br]
## @api private
const _FILE_DIALOG_NAME: StringName = &"ResourcePathFileDialog"

## 浏览和清除按钮使用的最小宽度。
## [br]
## @api private
const _BUTTON_MIN_WIDTH: float = 28.0

## 项目资源路径前缀。
## [br]
## @api private
const _RESOURCE_PREFIX: String = "res://"

## Godot 资源 UID 路径前缀。
## [br]
## @api private
const _UID_PREFIX: String = "uid://"


# --- 私有变量 ---

## 编辑资源路径文本的 LineEdit。
## [br]
## @api private
var _path_edit: LineEdit

## 打开当前 Inspector 窗口文件选择器的按钮。
## [br]
## @api private
var _browse_button: Button

## 清空当前路径的按钮。
## [br]
## @api private
var _clear_button: Button

## 限定为项目资源并以单文件打开模式工作的文件对话框。
## [br]
## @api private
var _file_dialog: EditorFileDialog

## 当前已提交并用于对话框定位的路径文本。
## [br]
## @api private
var _committed_path: String = ""

## 内部同步控件值时的信号抑制标记。
## [br]
## @api private
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

## 构建路径输入、浏览与清除按钮及项目资源对话框，并绑定提交和选择事件。
## [br]
## @api private
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


## 收到主题变化通知时重新应用编辑器图标。
## [br]
## @api private
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

## 忽略内部同步；否则修剪路径并同步 LineEdit，值发生变化时发出 path_changed。
## [br]
## @api private
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


## 优先使用编辑器主题中的 Load/Clear 图标；图标不可用时保留按钮文字。
## [br]
## @api private
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


## 将当前 UID 路径解析为项目路径并设置对话框目录与文件名。
## 路径无法解析或结果不是 res:// 时不改动对话框位置。
## [br]
## @api private
func _prepare_dialog_path() -> void:
	var resolved_path: String = _resolve_resource_path(_committed_path)
	if resolved_path.is_empty() or not resolved_path.begins_with(_RESOURCE_PREFIX):
		return
	_file_dialog.current_dir = resolved_path.get_base_dir()
	_file_dialog.current_file = resolved_path.get_file()


## 原样返回 res:// 路径；有效且已登记的 uid:// 路径返回其项目路径，其余输入返回空字符串。
## [br]
## @api private
func _resolve_resource_path(path: String) -> String:
	if path.begins_with(_RESOURCE_PREFIX):
		return path
	if not path.begins_with(_UID_PREFIX):
		return ""
	var uid: int = ResourceUID.text_to_id(path)
	if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
		return ""
	return ResourceUID.get_id_path(uid)


## 仅在清除按钮已创建时，根据已提交路径是否为空更新 disabled 状态。
## [br]
## @api private
func _update_clear_button() -> void:
	if _clear_button != null:
		_clear_button.disabled = _committed_path.is_empty()


# --- 信号处理函数 ---

## 将提交的文本交给统一路径提交逻辑。
## [br]
## @api private
func _on_text_submitted(text: String) -> void:
	_commit_path(text)


## 输入框失去焦点时提交其中的当前文本。
## [br]
## @api private
func _on_path_edit_focus_exited() -> void:
	_commit_path(_path_edit.text)


## 先按当前路径定位文件对话框，再打开该对话框。
## [br]
## @api private
func _on_browse_pressed() -> void:
	_prepare_dialog_path()
	_file_dialog.popup_file_dialog()


## 将空路径交给统一提交逻辑，以清除选择。
## [br]
## @api private
func _on_clear_pressed() -> void:
	_commit_path("")


## 将文件对话框选出的路径交给统一提交逻辑。
## [br]
## @api private
func _on_file_selected(path: String) -> void:
	_commit_path(path)
