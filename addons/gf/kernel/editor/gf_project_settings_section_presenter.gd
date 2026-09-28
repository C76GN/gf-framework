@tool

# GF Project Settings 分区树的多语言展示适配器。
extends RefCounted


# --- 常量 ---

## 展示记录字段读取辅助脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 负责解析标签、说明和 Tooltip 的项目设置展示目录脚本。
## [br]
## @api private
const _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_setting_presentation_catalog.gd")

## Godot 项目设置编辑器内部窗口的类名。
## [br]
## @api private
const _PROJECT_SETTINGS_EDITOR_CLASS: String = "ProjectSettingsEditor"

## 分区树重扫之间的最小间隔，单位为毫秒。
## [br]
## @api private
const _REFRESH_INTERVAL_MSEC: int = 100


# --- 私有变量 ---

## setup() 创建的展示目录实例；cleanup() 后置空。
## [br]
## @api private
var _catalog: RefCounted = null

## setup() 获取并连接 process_frame 的 SceneTree；cleanup() 后置空。
## [br]
## @api private
var _scene_tree: SceneTree = null

## 最近一次查找到的 Project Settings 窗口引用。
## [br]
## @api private
var _dialog: Window = null

## 当前窗口中最近一次查找到的分区 Tree 引用。
## [br]
## @api private
var _section_tree: Tree = null

## 传给展示目录的语言覆盖值；setup() 会去除首尾空白。
## [br]
## @api private
var _presentation_locale: String = ""

## 下一次允许刷新分区树的单调时钟毫秒值。
## [br]
## @api private
var _next_refresh_msec: int = 0

## 按 TreeItem 实例 ID 保存弱引用、原始文本与提示，以及本展示器最后写入的值；恢复时据此避免覆盖外部后续修改。
## [br]
## @api private
var _original_presentations: Dictionary = {}


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
	_restore_original_presentations()
	_catalog = null
	_scene_tree = null
	_dialog = null
	_section_tree = null
	_presentation_locale = ""
	_next_refresh_msec = 0


# --- 私有/辅助方法 ---

## 失去对话框引用时先恢复旧展示并重新查找原生项目设置窗口；仅在窗口可见且找到分区树时应用展示。
## [br]
## @api private
func _refresh_visible_dialog() -> void:
	if not is_instance_valid(_dialog):
		_restore_original_presentations()
		_dialog = _find_project_settings_dialog(EditorInterface.get_base_control())
		_section_tree = null
	if _dialog == null or not _dialog.visible:
		return
	if not is_instance_valid(_section_tree):
		_section_tree = _find_section_tree(_dialog)
	if _section_tree == null:
		return
	_apply_section_presentations(_section_tree.get_root())


## 从给定节点开始深度优先查找原生项目设置窗口；空根或未找到时返回 null。
## [br]
## @api private
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


## 递归查找包含受管分区的第一棵 Tree，未找到时返回 null；调用方须提供有效根节点。
## [br]
## @api private
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


## 判断 Tree 的根项目中是否存在可从展示目录解析的分区。
## [br]
## @api private
func _tree_contains_presented_section(tree: Tree) -> bool:
	if tree == null:
		return false
	return _item_contains_presented_section(tree.get_root())


## 深度遍历 TreeItem 子项，遇到可解析的分区路径时返回 true。
## [br]
## @api private
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


## 遍历分区树，为有展示定义的条目记录原值并按需更新文本与提示，同时保存本次写入值以便条件恢复。
## [br]
## @api private
func _apply_section_presentations(item: TreeItem) -> void:
	if item == null:
		return
	var presentation: Dictionary = _get_section_presentation(_get_item_section_path(item))
	if not presentation.is_empty():
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			presentation,
			"label"
		)
		var tooltip: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			presentation,
			"tooltip"
		)
		_capture_original_presentation(item)
		if item.get_text(0) != label:
			item.set_text(0, label)
		if item.get_tooltip_text(0) != tooltip:
			item.set_tooltip_text(0, tooltip)
		_update_applied_presentation(item, label, tooltip)
	var child: TreeItem = item.get_first_child()
	while child != null:
		_apply_section_presentations(child)
		child = child.get_next()


## 每个条目实例只捕获一次原始展示，并以弱引用保存条目，避免延长树项生命周期。
## [br]
## @api private
func _capture_original_presentation(item: TreeItem) -> void:
	var instance_id: int = item.get_instance_id()
	if _original_presentations.has(instance_id):
		return
	_original_presentations[instance_id] = {
		"item": weakref(item),
		"text": item.get_text(0),
		"tooltip": item.get_tooltip_text(0),
		"applied_text": "",
		"applied_tooltip": "",
	}


## 更新已保存展示记录中的应用标签与 Tooltip；目标记录不是字典时不处理。
## [br]
## @api private
func _update_applied_presentation(
	item: TreeItem,
	label: String,
	tooltip: String
) -> void:
	var instance_id: int = item.get_instance_id()
	var record_value: Variant = _original_presentations.get(instance_id, {})
	if not record_value is Dictionary:
		return
	var record: Dictionary = record_value
	record["applied_text"] = label
	record["applied_tooltip"] = tooltip
	_original_presentations[instance_id] = record


## 对仍存活的条目分别恢复文本与提示，且只恢复当前值仍等于本展示器最后写入值的部分；随后清空记录。
## [br]
## @api private
func _restore_original_presentations() -> void:
	for record_value: Variant in _original_presentations.values():
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var item_reference_value: Variant = record.get("item")
		if not item_reference_value is WeakRef:
			continue
		var item_reference: WeakRef = item_reference_value
		var item_value: Variant = item_reference.get_ref()
		if not item_value is TreeItem or not is_instance_valid(item_value):
			continue
		var item: TreeItem = item_value
		var applied_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"applied_text"
		)
		var applied_tooltip: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"applied_tooltip"
		)
		if item.get_text(0) == applied_text:
			item.set_text(
				0,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "text")
			)
		if item.get_tooltip_text(0) == applied_tooltip:
			item.set_tooltip_text(
				0,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "tooltip")
			)
	_original_presentations.clear()


## 从 TreeItem 元数据读取 String 或 StringName 路径，修剪首尾空白和一个末尾斜线。
## 其他元数据类型或空项返回空字符串。
## [br]
## @api private
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


## 向目录请求分区展示字典；路径为空、目录缺失或结果非字典时返回空字典。
## [br]
## @api private
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

## 按毫秒刷新间隔节流项目设置展示检查，到期后推进下次刷新时间并检查可见对话框。
## [br]
## @api private
func _on_process_frame() -> void:
	var current_msec: int = Time.get_ticks_msec()
	if current_msec < _next_refresh_msec:
		return
	_next_refresh_msec = current_msec + _REFRESH_INTERVAL_MSEC
	_refresh_visible_dialog()
