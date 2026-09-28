@tool

# GFSaveEditorActions: Save 扩展编辑器菜单动作。
extends RefCounted


# --- 常量 ---

## 校验当前 SaveGraph 菜单动作的 ID。
## [br]
## @api private
## [br]
const _MENU_ACTION_VALIDATE_SAVE_GRAPH: StringName = &"validate_save_graph"

## SaveGraph 诊断对话框的最小尺寸。
## [br]
## @api private
## [br]
const _DIAGNOSTIC_DIALOG_MIN_SIZE: Vector2 = Vector2(720.0, 460.0)

## 创建 SaveGraph 诊断工具的脚本资源。
## [br]
## @api private
## [br]
const _GF_SAVE_GRAPH_UTILITY_SCRIPT = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")


# --- 私有变量 ---

## 当前显示的诊断对话框。
## [br]
## @api private
## [br]
var _diagnostic_dialog: AcceptDialog

## 诊断报告正文控件。
## [br]
## @api private
## [br]
var _diagnostic_output: TextEdit


# --- 框架内部方法 ---

## 获取 Save 扩展贡献的 GF 工具菜单项。
## [br]
## @api framework_internal
## [br]
## @return 菜单项记录列表。
## [br]
## @schema return: Array[Dictionary]，每项包含 id: StringName、label: String 与 section: String。
func get_menu_entries() -> Array[Dictionary]:
	return [
		{
			"id": _MENU_ACTION_VALIDATE_SAVE_GRAPH,
			"label": "校验当前场景 SaveGraph",
			"section": "诊断",
		},
	]


## 执行 Save 扩展菜单动作。
## [br]
## @api framework_internal
## [br]
## @param action_id: 菜单动作 ID。
func handle_menu_action(action_id: StringName) -> void:
	match action_id:
		_MENU_ACTION_VALIDATE_SAVE_GRAPH:
			_validate_current_scene_save_graph()


## 清理菜单动作持有的 UI。
## [br]
## @api framework_internal
func cleanup() -> void:
	_cleanup_diagnostic_dialog()


# --- 私有/辅助方法 ---

## 收集当前编辑场景中的 Scope 并显示 SaveGraph 检查摘要。
## [br]
## @api private
## [br]
func _validate_current_scene_save_graph() -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_show_diagnostic_dialog("GF SaveGraph Health", "当前没有正在编辑的场景。")
		return

	var scopes: Array[GFSaveScope] = []
	_collect_save_scopes(scene_root, scopes)
	if scopes.is_empty():
		_show_diagnostic_dialog("GF SaveGraph Health", "当前场景未找到 GFSaveScope。")
		return

	var utility: GFSaveGraphUtility = _make_save_graph_utility()
	if utility == null:
		_show_diagnostic_dialog("GF SaveGraph Health", "SaveGraph 工具无法创建。")
		return

	var lines: PackedStringArray = PackedStringArray()
	var _append_result_77: Variant = lines.append("Scene: %s" % scene_root.scene_file_path)
	var _append_result_78: Variant = lines.append("Scope count: %d" % scopes.size())
	var _append_result_79: Variant = lines.append("")
	for scope: GFSaveScope in scopes:
		var report: Dictionary = utility.inspect_scope(scope)
		var _append_result_82: Variant = lines.append("[%s] %s" % [String(scope.get_path()), GFVariantData.get_option_string(report, "summary")])
		var _append_result_83: Variant = lines.append("Next: %s" % GFVariantData.get_option_string(report, "next_action"))
		for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
			var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
			if issue.is_empty():
				continue
			var _append_result_88: Variant = lines.append("- %s %s %s: %s" % [
				GFVariantData.get_option_string(issue, "severity"),
				GFVariantData.get_option_string(issue, "kind"),
				GFVariantData.get_option_string(issue, "path"),
				GFVariantData.get_option_string(issue, "message"),
			])
		var _append_result_94: Variant = lines.append("")

	_show_diagnostic_dialog("GF SaveGraph Health", "\n".join(lines))


## 递归收集节点子树中的 GFSaveScope。
## [br]
## @api private
## [br]
func _collect_save_scopes(node: Node, result: Array[GFSaveScope]) -> void:
	if node is GFSaveScope:
		var scope: GFSaveScope = node
		result.append(scope)

	for child: Node in node.get_children():
		_collect_save_scopes(child, result)


## 创建或复用诊断对话框并显示标题和正文。
## [br]
## @api private
## [br]
func _show_diagnostic_dialog(title: String, text: String) -> void:
	if not is_instance_valid(_diagnostic_dialog):
		_diagnostic_dialog = AcceptDialog.new()
		var dialog_min_size: Vector2i = Vector2i(
			int(_DIAGNOSTIC_DIALOG_MIN_SIZE.x),
			int(_DIAGNOSTIC_DIALOG_MIN_SIZE.y)
		)
		_diagnostic_dialog.min_size = dialog_min_size
		_diagnostic_output = TextEdit.new()
		_diagnostic_output.editable = false
		_diagnostic_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_diagnostic_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_diagnostic_dialog.add_child(_diagnostic_output)
		EditorInterface.get_base_control().add_child(_diagnostic_dialog)

	_diagnostic_dialog.title = title
	if is_instance_valid(_diagnostic_output):
		_diagnostic_output.text = text
	_diagnostic_dialog.popup_centered(Vector2i(
		int(_DIAGNOSTIC_DIALOG_MIN_SIZE.x),
		int(_DIAGNOSTIC_DIALOG_MIN_SIZE.y)
	))


## 实例化诊断工具脚本并检查返回对象类型。
## [br]
## @api private
## [br]
func _make_save_graph_utility() -> GFSaveGraphUtility:
	var value: Variant = _GF_SAVE_GRAPH_UTILITY_SCRIPT.new()
	if value is GFSaveGraphUtility:
		var utility: GFSaveGraphUtility = value
		return utility
	return null


## 释放诊断对话框并清空控件引用。
## [br]
## @api private
## [br]
func _cleanup_diagnostic_dialog() -> void:
	if is_instance_valid(_diagnostic_dialog):
		_diagnostic_dialog.queue_free()
	_diagnostic_dialog = null
	_diagnostic_output = null
