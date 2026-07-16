@tool

# GF Project Settings 分区树的多语言展示适配器。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_setting_presentation_catalog.gd")
const _PROJECT_SETTINGS_EDITOR_CLASS: String = "ProjectSettingsEditor"
const _REFRESH_INTERVAL_MSEC: int = 100


# --- 私有变量 ---

var _catalog: RefCounted = null
var _scene_tree: SceneTree = null
var _dialog: Window = null
var _section_tree: Tree = null
var _presentation_locale: String = ""
var _next_refresh_msec: int = 0


# --- 框架内部方法 ---

## 开始维护 Project Settings 左侧 GF 分区的标签和悬浮说明。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param setting_records: 已校验的项目设置展示记录。
## [br]
## @schema setting_records: Array[Dictionary]，每项可包含设置注册字段与展示映射。
## [br]
## @param section_records: 已校验的项目设置分区展示记录。
## [br]
## @schema section_records: Array[Dictionary]，每项包含 path、editor_labels 与 editor_descriptions。
## [br]
## @param locale: 展示语言覆盖；留空时跟随 Godot 当前工具语言。
func setup(
	setting_records: Array[Dictionary] = [],
	section_records: Array[Dictionary] = [],
	locale: String = ""
) -> void:
	cleanup()
	var catalog_value: Variant = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	if not catalog_value is RefCounted:
		return
	_catalog = catalog_value
	_presentation_locale = locale.strip_edges()
	var _configure_result: Variant = _catalog.call(
		&"configure",
		setting_records,
		section_records
	)

	var editor_root: Control = EditorInterface.get_base_control()
	if editor_root == null:
		return
	_scene_tree = editor_root.get_tree()
	if _scene_tree == null:
		return
	var process_frame_signal: Signal = _scene_tree.process_frame
	if not process_frame_signal.is_connected(_on_process_frame):
		var _connect_result: Error = process_frame_signal.connect(_on_process_frame) as Error


## 停止分区展示维护并释放编辑器对象引用。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func cleanup() -> void:
	if is_instance_valid(_scene_tree):
		var process_frame_signal: Signal = _scene_tree.process_frame
		if process_frame_signal.is_connected(_on_process_frame):
			process_frame_signal.disconnect(_on_process_frame)
	_catalog = null
	_scene_tree = null
	_dialog = null
	_section_tree = null
	_presentation_locale = ""
	_next_refresh_msec = 0


# --- 私有/辅助方法 ---

func _refresh_visible_dialog() -> void:
	if not is_instance_valid(_dialog):
		_dialog = _find_project_settings_dialog(EditorInterface.get_base_control())
		_section_tree = null
	if _dialog == null or not _dialog.visible:
		return
	if not is_instance_valid(_section_tree):
		_section_tree = _find_section_tree(_dialog)
	if _section_tree == null:
		return
	_apply_section_presentations(_section_tree.get_root())


func _find_project_settings_dialog(root: Node) -> Window:
	if root == null:
		return null
	if root is Window and root.get_class() == _PROJECT_SETTINGS_EDITOR_CLASS:
		var project_settings_dialog: Window = root
		return project_settings_dialog
	for child: Node in root.get_children():
		var nested_dialog: Window = _find_project_settings_dialog(child)
		if nested_dialog != null:
			return nested_dialog
	return null


func _find_section_tree(root: Node) -> Tree:
	if root is Tree:
		var tree: Tree = root
		if _tree_contains_presented_section(tree):
			return tree
	for child: Node in root.get_children():
		var nested_tree: Tree = _find_section_tree(child)
		if nested_tree != null:
			return nested_tree
	return null


func _tree_contains_presented_section(tree: Tree) -> bool:
	if tree == null:
		return false
	return _item_contains_presented_section(tree.get_root())


func _item_contains_presented_section(item: TreeItem) -> bool:
	if item == null:
		return false
	if not _get_section_presentation(_get_item_section_path(item)).is_empty():
		return true
	var child: TreeItem = item.get_first_child()
	while child != null:
		if _item_contains_presented_section(child):
			return true
		child = child.get_next()
	return false


func _apply_section_presentations(item: TreeItem) -> void:
	if item == null:
		return
	var presentation: Dictionary = _get_section_presentation(_get_item_section_path(item))
	if not presentation.is_empty():
		item.set_text(0, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "label"))
		item.set_tooltip_text(
			0,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "tooltip")
		)
	var child: TreeItem = item.get_first_child()
	while child != null:
		_apply_section_presentations(child)
		child = child.get_next()


func _get_item_section_path(item: TreeItem) -> String:
	if item == null:
		return ""
	var metadata: Variant = item.get_metadata(0)
	if metadata is String:
		var path: String = metadata
		return path.strip_edges().trim_suffix("/")
	if metadata is StringName:
		var path_name: StringName = metadata
		return String(path_name).strip_edges().trim_suffix("/")
	return ""


func _get_section_presentation(section_path: String) -> Dictionary:
	if section_path.is_empty() or _catalog == null:
		return {}
	var presentation_value: Variant = _catalog.call(
		&"get_section_presentation",
		section_path,
		_presentation_locale
	)
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(presentation_value)


# --- 信号处理函数 ---

func _on_process_frame() -> void:
	var current_msec: int = Time.get_ticks_msec()
	if current_msec < _next_refresh_msec:
		return
	_next_refresh_msec = current_msec + _REFRESH_INTERVAL_MSEC
	_refresh_visible_dialog()
