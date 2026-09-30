@tool

# GF SaveGraph 工作区页面。
#
# 查看当前场景中的 GFSaveScope/GFSaveSource 结构，执行健康检查并按需采集预览载荷。
extends Control


# --- 常量 ---

## 创建 SaveGraph 检查与预览工具的脚本资源。
## [br]
## @api private
## [br]
const _GF_SAVE_GRAPH_UTILITY_SCRIPT = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")

## 获取 WeakRef 对应存活节点的实例守卫脚本资源。
## [br]
## @api private
## [br]
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")

## 创建工作区工具栏、详情控件和报告状态样式的脚本资源。
## [br]
## @api private
## [br]
const _GF_EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

## 当前 SaveGraph 根节点的弱引用。
## [br]
## @api private
## [br]
var _root_ref: WeakRef = null

## 最近一次刷新收集的 Scope 节点。
## [br]
## @api private
## [br]
var _scopes: Array[Node] = []

## 运行 SaveGraph 检查与采集预览的工具对象。
## [br]
## @api private
## [br]
var _utility: GFSaveGraphUtility = null

## 最近一次 Scope 健康检查报告。
## [br]
## @api private
## [br]
var _last_scope_report: Dictionary = {}

## 最近一次采集的预览载荷。
## [br]
## @api private
## [br]
var _last_payload: Dictionary = {}

## 最近一次预览载荷校验报告。
## [br]
## @api private
## [br]
var _last_payload_report: Dictionary = {}

## 选择当前 Scope 的下拉控件。
## [br]
## @api private
## [br]
var _scope_option: OptionButton = null

## 控制预览载荷是否严格校验的复选框。
## [br]
## @api private
## [br]
var _strict_payload_check: CheckBox = null

## 控制预览是否包含 pipeline trace 的复选框。
## [br]
## @api private
## [br]
var _include_trace_check: CheckBox = null

## 在编辑器场景树中选择当前 Scope 的按钮。
## [br]
## @api private
## [br]
var _select_button: Button = null

## 显示摘要、下一步和检查状态的标签。
## [br]
## @api private
## [br]
var _summary_label: Label = null

## 当前没有 Scope 或结果时显示的标签。
## [br]
## @api private
## [br]
var _empty_label: Label = null

## 包含 Scope 树与详情页签的分栏容器。
## [br]
## @api private
## [br]
var _content_split: HSplitContainer = null

## 显示 Scope、Source 与问题条目的树控件。
## [br]
## @api private
## [br]
var _tree: Tree = null

## 显示报告和预览载荷的页签容器。
## [br]
## @api private
## [br]
var _tabs: TabContainer = null

## 保留详情与载荷内容的展开开关。
## [br]
## @api private
var _details_toggle: CheckButton = null

## 显示所选树条目详情的文本控件。
## [br]
## @api private
## [br]
var _details: TextEdit = null

## 显示预览载荷与其校验结果的文本控件。
## [br]
## @api private
## [br]
var _payload_output: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Save"
	_GF_EDITOR_WORKSPACE_UI.apply_page_root(self)
	_utility = _GF_SAVE_GRAPH_UTILITY_SCRIPT.new()
	_build_ui()
	call_deferred("refresh")


# --- 框架内部方法 ---

## 设置要扫描的场景根节点。
## [br]
## @api framework_internal
## [br]
## @param root: 场景根节点。
func set_save_graph_source(root: Node) -> void:
	_root_ref = weakref(root) if root != null else null
	refresh(root)


## 刷新 SaveGraph 结构与健康报告。
## [br]
## @api framework_internal
## [br]
## @param root: 可选场景根节点。
func refresh(root: Node = null) -> void:
	_build_ui()
	var source_root: Node = root if root != null else _resolve_root()
	_scopes.clear()
	if source_root != null:
		_root_ref = weakref(source_root)
		_collect_scopes(source_root, _scopes)
	_populate_scope_options()
	_render_selected_scope()


## 获取最近一次 Scope 健康报告。
## [br]
## @api framework_internal
## [br]
## @return 报告副本。
## [br]
## @schema return: Dictionary，包含 ok、summary、next_action、scopes、sources 与 issues 等健康报告字段。
func get_last_scope_report() -> Dictionary:
	return _last_scope_report.duplicate(true)


## 获取最近一次预览载荷。
## [br]
## @api framework_internal
## [br]
## @return 载荷副本。
## [br]
## @schema return: Dictionary，包含 format、format_version、scope_key、sources、children 与可选 pipeline_trace。
func get_last_payload() -> Dictionary:
	return _last_payload.duplicate(true)


# --- 私有/辅助方法 ---

## 首次构造工具栏、Scope 树和详情页签；已构造时直接返回。
## [br]
## @api private
## [br]
func _build_ui() -> void:
	if _tree != null:
		return

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _GF_EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_GF_EDITOR_WORKSPACE_UI.make_button("刷新", "扫描当前场景中的 GFSaveScope。", refresh))

	_scope_option = OptionButton.new()
	_scope_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scope_option.tooltip_text = "选择一个 GFSaveScope。"
	var _scope_selected_connected: int = _scope_option.item_selected.connect(_on_scope_selected)
	toolbar.add_child(_scope_option)

	_strict_payload_check = CheckBox.new()
	_strict_payload_check.text = "严格载荷"
	_strict_payload_check.tooltip_text = "校验预览载荷时把缺失 Source/Scope 视为错误。"
	var _strict_toggled_connected: int = _strict_payload_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_strict_payload_check)

	_include_trace_check = CheckBox.new()
	_include_trace_check.text = "跟踪"
	_include_trace_check.tooltip_text = "采集预览载荷时包含 pipeline trace。"
	toolbar.add_child(_include_trace_check)

	_select_button = _GF_EDITOR_WORKSPACE_UI.make_button("定位作用域", "在编辑器场景树中选中当前 Scope。", _on_select_pressed)
	toolbar.add_child(_select_button)

	toolbar.add_child(_GF_EDITOR_WORKSPACE_UI.make_button("预览载荷", "采集当前 Scope 的 SaveGraph 预览载荷。", _on_preview_payload_pressed))
	toolbar.add_child(_GF_EDITOR_WORKSPACE_UI.make_button("复制报告", "复制当前 SaveGraph 报告 JSON。", _on_copy_report_pressed))

	_summary_label = _GF_EDITOR_WORKSPACE_UI.make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _GF_EDITOR_WORKSPACE_UI.make_empty_label()
	root_box.add_child(_empty_label)

	_content_split = HSplitContainer.new()
	_content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_content_split)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "类型")
	_tree.set_column_title(1, "标识")
	_tree.set_column_title(2, "状态")
	_tree.set_column_title(3, "说明")
	_tree.set_column_expand(3, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tree_item_selected_connected: int = _tree.item_selected.connect(_on_tree_item_selected)
	_content_split.add_child(_tree)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_split.add_child(_tabs)
	_details_toggle = _GF_EDITOR_WORKSPACE_UI.make_details_toggle(_tabs)
	toolbar.add_child(_details_toggle)

	_details = _GF_EDITOR_WORKSPACE_UI.make_details_output()
	_details.name = "高级详情"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(_details)

	_payload_output = _GF_EDITOR_WORKSPACE_UI.make_details_output()
	_payload_output.name = "载荷"
	_payload_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_payload_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(_payload_output)


## 依次尝试弱引用节点、编辑器场景根节点和 SceneTree 根节点。
## [br]
## @api private
## [br]
func _resolve_root() -> Node:
	if _root_ref != null:
		var root: Node = _INSTANCE_GUARD._get_live_node_from_ref(_root_ref)
		if root != null:
			return root

	if Engine.is_editor_hint():
		var edited_root: Node = EditorInterface.get_edited_scene_root()
		if edited_root != null:
			return edited_root

	var tree: SceneTree = _get_scene_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## 递归收集给定节点子树中的 GFSaveScope。
## [br]
## @api private
## [br]
func _collect_scopes(node: Node, result: Array[Node]) -> void:
	if node is GFSaveScope:
		result.append(node)

	for child: Node in node.get_children():
		_collect_scopes(child, result)


## 根据已收集 Scope 列表刷新选择下拉框和按钮状态。
## [br]
## @api private
## [br]
func _populate_scope_options() -> void:
	if _scope_option == null:
		return

	var previous_index: int = _scope_option.selected
	_scope_option.clear()
	for index: int in range(_scopes.size()):
		var scope: Node = _scopes[index]
		_scope_option.add_item(_get_node_path_text(scope), index)
		_scope_option.set_item_metadata(index, index)

	if _scopes.is_empty():
		_scope_option.add_item("未找到 GFSaveScope", 0)
		_scope_option.disabled = true
		_select_button.disabled = true
	else:
		_scope_option.disabled = false
		_select_button.disabled = false
		_scope_option.select(clampi(previous_index, 0, _scopes.size() - 1))


## 清空当前视图，检查所选 Scope 并显示报告或空状态。
## [br]
## @api private
## [br]
func _render_selected_scope() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = ""
	_payload_output.text = ""
	_last_payload = {}
	_last_payload_report = {}
	if _scopes.is_empty():
		_last_scope_report = {}
		_render_empty(
			"未找到 GFSaveScope。",
			"当前场景没有 GFSaveScope。打开或添加保存作用域后点击刷新。"
		)
		return

	var scope: GFSaveScope = _get_selected_scope()
	if scope == null:
		_last_scope_report = {}
		_render_empty("选择无效。", "当前 GFSaveScope 选择无效，请刷新后重试。")
		return

	_last_scope_report = _utility.inspect_scope(scope)
	_render_report(scope)


## 将 Scope 健康报告渲染为摘要、详情 JSON 和树条目。
## [br]
## @api private
## [br]
func _render_report(scope: GFSaveScope) -> void:
	_empty_label.visible = false
	_content_split.visible = true
	_tree.visible = true
	_payload_output.text = "点击“预览载荷”采集当前 GFSaveScope 的 SaveGraph payload。"
	_summary_label.text = "%s\n下一步：%s" % [
		_get_report_text("summary"),
		_get_report_text("next_action"),
	]
	_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, _summary_label.text, _GF_EDITOR_WORKSPACE_UI.get_report_color(_last_scope_report))
	_details.text = _safe_json(_last_scope_report)

	var root_item: TreeItem = _tree.create_item()
	var root_scope_entry: Dictionary = _get_root_scope_entry()
	var scope_item: TreeItem = _tree.create_item(root_item)
	scope_item.set_text(0, "Root")
	scope_item.set_text(1, _get_entry_text(root_scope_entry, "key"))
	scope_item.set_text(2, _get_save_load_state(
		_get_entry_bool(root_scope_entry, "can_save"),
		_get_entry_bool(root_scope_entry, "can_load")
	))
	scope_item.set_text(3, _get_entry_text(root_scope_entry, "path", _get_node_path_text(scope)))
	scope_item.set_metadata(0, root_scope_entry.duplicate(true))

	for scope_entry: Dictionary in _get_report_entries("scopes"):
		_add_scope_item(root_item, scope_entry)

	for source_entry: Dictionary in _get_report_entries("sources"):
		_add_source_item(root_item, source_entry)

	for issue: Dictionary in _get_report_entries("issues"):
		_add_issue_item(root_item, issue)


## 在树中新增一个 Scope 报告项。
## [br]
## @api private
## [br]
func _add_scope_item(parent: TreeItem, scope_entry: Dictionary) -> void:
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, "Scope")
	item.set_text(1, _get_entry_text(scope_entry, "key"))
	item.set_text(2, _get_save_load_state(_get_entry_bool(scope_entry, "can_save"), _get_entry_bool(scope_entry, "can_load")))
	item.set_text(3, _get_entry_text(scope_entry, "path"))
	item.set_metadata(0, scope_entry.duplicate(true))


## 在树中新增一个 Source 报告项和序列化器 ID 描述。
## [br]
## @api private
## [br]
func _add_source_item(parent: TreeItem, source_entry: Dictionary) -> void:
	var serializer_ids: PackedStringArray = _get_entry_packed_string_array(source_entry, "serializer_ids")
	var serializer_text: String = ", ".join(serializer_ids) if not serializer_ids.is_empty() else "无 serializer"
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, "Source")
	item.set_text(1, _get_entry_text(source_entry, "key"))
	item.set_text(2, _get_save_load_state(_get_entry_bool(source_entry, "can_save"), _get_entry_bool(source_entry, "can_load")))
	item.set_text(3, "%s -> %s · %s" % [
		_get_entry_text(source_entry, "path"),
		_get_entry_text(source_entry, "target_path"),
		serializer_text,
	])
	item.set_metadata(0, _sanitize_for_display(source_entry))


## 在树中新增一个校验问题项。
## [br]
## @api private
## [br]
func _add_issue_item(parent: TreeItem, issue: Dictionary) -> void:
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, _get_entry_text(issue, "severity"))
	item.set_text(1, _get_entry_text(issue, "kind"))
	item.set_text(2, _get_entry_text(issue, "key"))
	item.set_text(3, _get_entry_text(issue, "message"))
	item.set_metadata(0, issue.duplicate(true))


## 显示空状态消息，并隐藏报告树和载荷输出。
## [br]
## @api private
## [br]
func _render_empty(message: String, hint: String = "") -> void:
	if _tree != null:
		_tree.clear()
		_tree.visible = false
	if _content_split != null:
		_content_split.visible = false
	if _details != null:
		_details.text = hint if not hint.is_empty() else message
	if _payload_output != null:
		_payload_output.text = ""
	if _empty_label != null:
		_empty_label.text = hint if not hint.is_empty() else message
		_empty_label.visible = true
	_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, message, _GF_EDITOR_WORKSPACE_UI.INFO_TEXT_COLOR)


## 从最近一次 Scope 报告中返回第一个 Scope 条目。
## [br]
## @api private
## [br]
func _get_root_scope_entry() -> Dictionary:
	for scope_entry: Dictionary in _get_report_entries("scopes"):
		return scope_entry
	return {}


## 按当前下拉框索引获取有效的 GFSaveScope。
## [br]
## @api private
## [br]
func _get_selected_scope() -> GFSaveScope:
	if _scope_option == null or _scopes.is_empty():
		return null
	var index: int = _scope_option.selected
	if index < 0 or index >= _scopes.size():
		return null
	var scope: GFSaveScope = _get_save_scope_value(_scopes[index])
	return scope if is_instance_valid(scope) else null


## 采集所选 Scope 的预览载荷、按选项校验并更新输出页签。
## [br]
## @api private
## [br]
func _preview_payload() -> void:
	var scope: GFSaveScope = _get_selected_scope()
	if scope == null:
		_render_empty("选择无效。", "当前 GFSaveScope 选择无效，请刷新后重试。")
		return

	_last_payload = _utility.gather_scope(scope, {
		"include_pipeline_trace": _include_trace_check != null and _include_trace_check.button_pressed,
	})
	if _last_payload.is_empty():
		_payload_output.text = ""
		_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, "预览载荷为空。", _GF_EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)
		return

	_last_payload_report = _utility.validate_payload_for_scope(
		scope,
		_last_payload,
		_strict_payload_check != null and _strict_payload_check.button_pressed
	)
	_payload_output.text = _safe_json({
		"payload": _last_payload,
		"payload_report": _last_payload_report,
	})
	_tabs.current_tab = 1
	_details_toggle.button_pressed = true
	_GF_EDITOR_WORKSPACE_UI.set_status(
		_summary_label,
		"%s\nPayload：%s" % [
			_get_report_text("summary"),
			GFVariantData.get_option_string(_last_payload_report, "summary"),
		],
		_GF_EDITOR_WORKSPACE_UI.get_report_color(_last_payload_report)
	)


## 将可保存、可加载布尔值组合为状态文本。
## [br]
## @api private
## [br]
func _get_save_load_state(can_save: bool, can_load: bool) -> String:
	if can_save and can_load:
		return "保存/加载"
	if can_save:
		return "保存"
	if can_load:
		return "加载"
	return "禁用"


## 获取节点路径文本；节点不在树中时使用节点名。
## [br]
## @api private
## [br]
func _get_node_path_text(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return String(node.get_path())
	return String(node.name)


## 将值递归规整后转换为缩进 JSON 文本。
## [br]
## @api private
## [br]
func _safe_json(value: Variant) -> String:
	return JSON.stringify(_sanitize_for_display(value), "\t")


## 将字典、数组和 PackedStringArray 转为可显示值，并把 Object 转成文本。
## [br]
## @api private
## [br]
func _sanitize_for_display(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		var result: Dictionary = {}
		for key: Variant in dictionary.keys():
			result[str(key)] = _sanitize_for_display(dictionary[key])
		return result
	if value is Array:
		var array_value: Array = GFVariantData.as_array(value)
		var array_result: Array = []
		for item: Variant in array_value:
			array_result.append(_sanitize_for_display(item))
		return array_result
	if value is PackedStringArray:
		var strings: Array[String] = []
		for item: String in value:
			strings.append(item)
		return strings
	if value is Object:
		return str(value)
	return value


## 从 Variant 数组提取非空字典条目。
## [br]
## @api private
## [br]
func _dictionary_entries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in GFVariantData.as_array(value):
		var dictionary: Dictionary = GFVariantData.as_dictionary(item)
		if not dictionary.is_empty():
			result.append(dictionary)
	return result


## 将 PackedStringArray 或 Variant 数组转换为 PackedStringArray。
## [br]
## @api private
## [br]
func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var string_values: PackedStringArray = value
		return string_values
	if value is Array:
		var result: PackedStringArray = PackedStringArray()
		for item: Variant in GFVariantData.as_array(value):
			var _item_appended: bool = result.append(GFVariantData.to_text(item))
		return result
	return PackedStringArray()


## 从最近一次 Scope 报告中读取指定文本字段。
## [br]
## @api private
## [br]
func _get_report_text(key: String, fallback: String = "") -> String:
	return GFVariantData.get_option_string(_last_scope_report, key, fallback)


## 从最近一次 Scope 报告中读取指定字典条目列表。
## [br]
## @api private
## [br]
func _get_report_entries(key: String) -> Array[Dictionary]:
	return _dictionary_entries(GFVariantData.get_option_value(_last_scope_report, key, []))


## 从条目读取文本字段及回退值。
## [br]
## @api private
## [br]
func _get_entry_text(entry: Dictionary, key: String, fallback: String = "") -> String:
	return GFVariantData.get_option_string(entry, key, fallback)


## 从条目读取布尔字段及回退值。
## [br]
## @api private
## [br]
func _get_entry_bool(entry: Dictionary, key: String, fallback: bool = false) -> bool:
	return GFVariantData.get_option_bool(entry, key, fallback)


## 从条目读取 PackedStringArray 字段。
## [br]
## @api private
## [br]
func _get_entry_packed_string_array(entry: Dictionary, key: String) -> PackedStringArray:
	return _get_packed_string_array_value(GFVariantData.get_option_value(entry, key, PackedStringArray()))


## 返回当前 MainLoop 对应的 SceneTree；不是 SceneTree 时返回 null。
## [br]
## @api private
## [br]
func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


## 将 Variant 转为 GFSaveScope；类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_save_scope_value(value: Variant) -> GFSaveScope:
	if value is GFSaveScope:
		var scope: GFSaveScope = value
		return scope
	return null


# --- 信号处理函数 ---

## Scope 下拉框变化时重新渲染选中项。
## [br]
## @api private
## [br]
func _on_scope_selected(_index: int) -> void:
	_render_selected_scope()


## 选项变化后若已有载荷则重新执行预览。
## [br]
## @api private
## [br]
func _on_option_toggled(_pressed: bool) -> void:
	if not _last_payload.is_empty():
		_preview_payload()


## 在编辑器选择面板中选中当前 Scope 节点。
## [br]
## @api private
## [br]
func _on_select_pressed() -> void:
	if not Engine.is_editor_hint():
		return

	var scope: GFSaveScope = _get_selected_scope()
	if scope == null:
		return

	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		return
	selection.clear()
	selection.add_node(scope)


## 预览按钮回调，采集当前载荷。
## [br]
## @api private
## [br]
func _on_preview_payload_pressed() -> void:
	_preview_payload()


## 将最近一次报告及可用载荷写入系统剪贴板。
## [br]
## @api private
## [br]
func _on_copy_report_pressed() -> void:
	var report: Dictionary = {
		"scope_report": _last_scope_report,
		"payload_report": _last_payload_report,
	}
	if not _last_payload.is_empty():
		report["payload"] = _last_payload
	DisplayServer.clipboard_set(_safe_json(report))
	_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, "已复制 SaveGraph 报告。", _GF_EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)


## 树条目选择变化时显示条目详情。
## [br]
## @api private
## [br]
func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	_details.text = _safe_json(item.get_metadata(0))
	_tabs.current_tab = 0
	_details_toggle.button_pressed = true
