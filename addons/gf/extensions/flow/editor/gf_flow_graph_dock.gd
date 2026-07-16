@tool

## GFFlowGraphDock: FlowGraph 图形化编辑与结构检查工作区页面。
##
## 为资源化流程图提供路径加载、GraphEdit 预览/连线、校验摘要、节点/连接清单
## 和通用自动布局，不提供业务节点库，也不解释项目自定义元数据。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFFlowGraphDock
extends Control


# --- 常量 ---

const _DEFAULT_LAYOUT_OPTIONS: Dictionary = {
	"x_spacing": 280.0,
	"y_spacing": 160.0,
}
const _DEFAULT_NODE_COLOR: Color = Color(0.52, 0.68, 0.92)
const _EXECUTION_PORT_COLOR: Color = Color(0.95, 0.78, 0.38)
const _SIDE_PANEL_MIN_WIDTH: float = 320.0
const _DETAIL_MIN_HEIGHT: float = 112.0
const _GF_EDITOR_WORKSPACE_UI_SCRIPT: Script = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _graph: GFFlowGraph = null
var _graph_path: String = ""
var _last_view_model: Dictionary = {}
var _node_controls_by_id: Dictionary = {}
var _node_ids_by_control_name: Dictionary = {}
var _selected_node_id: StringName = &""
var _path_edit: LineEdit = null
var _summary_label: Label = null
var _empty_label: Label = null
var _content_split: HSplitContainer = null
var _graph_edit: GraphEdit = null
var _tree: Tree = null
var _details: TextEdit = null
var _file_dialog: FileDialog = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Flow Tools"
	_apply_page_root(self)
	_build_ui()
	refresh()


# --- 公共方法 ---

## 设置当前查看的 FlowGraph。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param graph: 流程图资源。
## [br]
## @param path: 可选资源路径。
func set_graph(graph: GFFlowGraph, path: String = "") -> void:
	_graph = graph
	var candidate_path: String = path if not path.is_empty() else (graph.resource_path if graph != null else "")
	_graph_path = candidate_path if candidate_path.is_empty() or _is_project_resource_path(candidate_path) else ""
	if _path_edit != null:
		_path_edit.text = _graph_path
	refresh()


## 设置并加载当前 FlowGraph 资源路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: `res://` 资源路径。
func set_graph_path(path: String) -> void:
	var candidate_path: String = path.strip_edges()
	_graph_path = candidate_path if _is_project_resource_path(candidate_path) else ""
	if _graph_path.is_empty():
		_graph = null
	if _path_edit != null:
		_path_edit.text = _graph_path
	_load_graph_from_path()
	refresh()


## 刷新当前 FlowGraph 视图。
## [br]
## @api public
## [br]
## @since 3.17.0
func refresh() -> void:
	_build_ui()
	if _graph == null and not _graph_path.is_empty():
		_load_graph_from_path()
	_render_graph()


## 获取最近一次 FlowGraph 视图模型。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 视图模型字典副本。
## [br]
## @schema return: Dictionary，由 GFFlowGraphEditorModel.build_view_model() 生成的视图模型副本。
func get_last_view_model() -> Dictionary:
	return _last_view_model.duplicate(true)


# --- 私有/辅助方法 ---

func _get_string_name_value(value: Variant, default_value: StringName = &"") -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return default_value if string_name_value == &"" else string_name_value
	if value is String:
		var text_value: String = value
		var trimmed_value: String = text_value.strip_edges()
		return default_value if trimmed_value.is_empty() else StringName(trimmed_value)
	return default_value


func _get_color_value(value: Variant, default_value: Color = Color.TRANSPARENT) -> Color:
	if value is Color:
		return value
	return default_value


func _get_connection_from_node_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "from_node_id", &"")


func _get_connection_from_port_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "from_port_id", &"")


func _get_connection_to_node_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "to_node_id", &"")


func _get_connection_to_port_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "to_port_id", &"")


func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		return value
	return null


func _get_flow_graph_value(value: Variant) -> GFFlowGraph:
	if value is GFFlowGraph:
		return value
	return null


func _get_graph_node_value(value: Variant) -> GraphNode:
	if value is GraphNode:
		return value
	return null


func _get_button_value(value: Variant) -> Button:
	if value is Button:
		return value
	return null


func _get_label_value(value: Variant) -> Label:
	if value is Label:
		return value
	return null


func _get_hbox_container_value(value: Variant) -> HBoxContainer:
	if value is HBoxContainer:
		return value
	return null


func _get_text_edit_value(value: Variant) -> TextEdit:
	if value is TextEdit:
		return value
	return null


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _apply_page_root(page: Control) -> void:
	var result: Variant = _GF_EDITOR_WORKSPACE_UI_SCRIPT.call("apply_page_root", page)
	if result != null:
		return


func _make_toolbar() -> HBoxContainer:
	var toolbar: HBoxContainer = _get_hbox_container_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("make_toolbar"))
	return toolbar if toolbar != null else HBoxContainer.new()


func _make_workspace_button(text: String, tooltip: String, handler: Callable) -> Button:
	var button: Button = _get_button_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("make_button", text, tooltip, handler))
	return button if button != null else Button.new()


func _make_summary_label() -> Label:
	var label: Label = _get_label_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("make_summary_label"))
	return label if label != null else Label.new()


func _make_empty_label() -> Label:
	var label: Label = _get_label_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("make_empty_label"))
	return label if label != null else Label.new()


func _make_details_output(min_height: float) -> TextEdit:
	var output: TextEdit = _get_text_edit_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("make_details_output", min_height))
	return output if output != null else TextEdit.new()


func _set_status(label: Label, text: String) -> void:
	var result: Variant = _GF_EDITOR_WORKSPACE_UI_SCRIPT.call("set_status", label, text)
	if result != null:
		return


func _get_report_color(report: Dictionary) -> Color:
	return _get_color_value(_GF_EDITOR_WORKSPACE_UI_SCRIPT.call("get_report_color", report), Color.WHITE)


func _build_ui() -> void:
	if _graph_edit != null:
		return

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _make_toolbar()
	root_box.add_child(toolbar)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "res://path/to/flow_graph.tres"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path_connect_error: int = _path_edit.text_submitted.connect(_on_path_submitted)
	if path_connect_error != OK:
		return
	toolbar.add_child(_path_edit)

	toolbar.add_child(_make_workspace_button("...", "选择 FlowGraph 资源。", _on_browse_pressed))
	toolbar.add_child(_make_workspace_button("刷新", "重新加载并校验当前 FlowGraph。", _on_refresh_pressed))
	toolbar.add_child(_make_workspace_button("自动布局", "按通用分层布局写入节点 editor_position。", _on_auto_layout_pressed))
	toolbar.add_child(_make_workspace_button("保存", "保存当前 FlowGraph 资源。", _on_save_pressed))

	_summary_label = _make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _make_empty_label()
	root_box.add_child(_empty_label)

	_content_split = HSplitContainer.new()
	_content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_content_split)

	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_connect_graph_edit_signal("connection_request", _on_connection_request)
	_connect_graph_edit_signal("disconnection_request", _on_disconnection_request)
	_connect_graph_edit_signal("delete_nodes_request", _on_delete_nodes_request)
	_connect_graph_edit_signal("node_selected", _on_node_selected)
	_connect_graph_edit_signal("end_node_move", _on_end_node_move)
	_content_split.add_child(_graph_edit)

	var side_panel: VBoxContainer = VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(_SIDE_PANEL_MIN_WIDTH, 0.0)
	side_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_split.add_child(side_panel)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "类型")
	_tree.set_column_title(1, "标识")
	_tree.set_column_title(2, "连接/分类")
	_tree.set_column_title(3, "说明")
	_tree.set_column_expand(3, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tree_connect_error: int = _tree.item_selected.connect(_on_item_selected)
	if tree_connect_error != OK:
		return
	side_panel.add_child(_tree)

	_details = _make_details_output(_DETAIL_MIN_HEIGHT)
	side_panel.add_child(_details)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.tres, *.res ; Godot Resources"])
	var file_dialog_connect_error: int = _file_dialog.file_selected.connect(_on_file_selected)
	if file_dialog_connect_error != OK:
		return
	add_child(_file_dialog)


func _connect_graph_edit_signal(signal_name: StringName, handler: Callable) -> void:
	if _graph_edit != null and _graph_edit.has_signal(signal_name):
		var error: int = _graph_edit.connect(signal_name, handler)
		if error != OK:
			return


func _load_graph_from_path() -> void:
	if not _is_project_resource_path(_graph_path):
		_graph_path = ""
		if _path_edit != null:
			_path_edit.text = ""
		_graph = null
		return
	if not ResourceLoader.exists(_graph_path):
		_graph = null
		return

	var resource: Resource = _get_resource_value(load(_graph_path))
	_graph = _get_flow_graph_value(resource)
	if _graph != null and _graph.resource_path.is_empty():
		_graph.resource_path = _graph_path


func _is_project_resource_path(path: String) -> bool:
	var normalized_path: String = path.strip_edges()
	return normalized_path.begins_with("res://") and normalized_path.length() > "res://".length()


func _render_graph() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = ""
	_clear_graph_canvas()
	if _graph == null:
		_last_view_model = {}
		_set_status(_summary_label, "未加载 FlowGraph。")
		_empty_label.text = "输入或选择一个 GFFlowGraph 资源路径后点击刷新。"
		_empty_label.visible = true
		_tree.visible = false
		_content_split.visible = false
		return

	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	_last_view_model = editor_model.build_view_model(_graph)
	var validation: Dictionary = GFVariantData.get_option_dictionary(_last_view_model, "validation")
	_summary_label.text = "%s\n节点：%d  连接：%d  下一步：%s" % [
		GFVariantData.get_option_string(validation, "summary", ""),
		GFVariantData.get_option_int(_last_view_model, "node_count", 0),
		GFVariantData.get_option_int(_last_view_model, "connection_count", 0),
		GFVariantData.get_option_string(validation, "next_action", ""),
	]
	_summary_label.modulate = _get_report_color(validation)
	_content_split.visible = true
	_graph_edit.visible = true
	_render_graph_canvas(_last_view_model)
	_render_entries(_last_view_model)


func _render_graph_canvas(view_model: Dictionary) -> void:
	var nodes: Array = GFVariantData.get_option_array(view_model, "nodes")

	for index: int in range(nodes.size()):
		var node: Dictionary = GFVariantData.as_dictionary(nodes[index])
		if node.is_empty():
			continue
		var graph_node: GraphNode = _make_graph_node(node, index)
		_graph_edit.add_child(graph_node)
		var node_id: StringName = GFVariantData.get_option_string_name(node, "node_id", &"")
		_node_controls_by_id[node_id] = graph_node
		_node_ids_by_control_name[StringName(graph_node.name)] = node_id

	var connections: Array = GFVariantData.get_option_array(view_model, "connections")
	for connection_variant: Variant in connections:
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if not connection.is_empty() and GFVariantData.get_option_bool(connection, "valid", false):
			_connect_graph_edit_nodes(connection)


func _make_graph_node(node_entry: Dictionary, index: int) -> GraphNode:
	var graph_node: GraphNode = GraphNode.new()
	var node_id: StringName = GFVariantData.get_option_string_name(node_entry, "node_id", &"")
	var display_name: String = GFVariantData.get_option_string(node_entry, "display_name", "")
	graph_node.name = "FlowNode%d" % index
	graph_node.title = "%s  [%s]" % [display_name, String(node_id)]
	graph_node.position_offset = GFVariantData.to_vector2(GFVariantData.get_option_value(node_entry, "position", Vector2.ZERO))
	graph_node.custom_minimum_size = GFVariantData.to_vector2(
		GFVariantData.get_option_value(node_entry, "size", Vector2(220.0, 120.0)),
		Vector2(220.0, 120.0)
	)
	graph_node.set_meta("node_id", node_id)
	_add_execution_slot(graph_node)
	_add_data_port_slots(graph_node, node_entry)
	return graph_node


func _add_execution_slot(graph_node: GraphNode) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_make_slot_label("in", HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_make_slot_label("flow", HORIZONTAL_ALIGNMENT_RIGHT))
	graph_node.add_child(row)
	graph_node.set_slot(0, true, 0, _EXECUTION_PORT_COLOR, true, 0, _EXECUTION_PORT_COLOR)


func _add_data_port_slots(graph_node: GraphNode, node_entry: Dictionary) -> void:
	var input_ports: Array = GFVariantData.get_option_array(node_entry, "input_ports")
	var output_ports: Array = GFVariantData.get_option_array(node_entry, "output_ports")

	var row_count: int = maxi(input_ports.size(), output_ports.size())
	for index: int in range(row_count):
		var input_entry: Dictionary = GFVariantData.as_dictionary(input_ports[index]) if index < input_ports.size() else {}
		var output_entry: Dictionary = GFVariantData.as_dictionary(output_ports[index]) if index < output_ports.size() else {}
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_make_slot_label(_get_port_label(input_entry), HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(_make_slot_label(_get_port_label(output_entry), HORIZONTAL_ALIGNMENT_RIGHT))
		graph_node.add_child(row)
		graph_node.set_slot(
			index + 1,
			not input_entry.is_empty(),
			0,
			_get_port_color(input_entry),
			not output_entry.is_empty(),
			0,
			_get_port_color(output_entry)
		)


func _make_slot_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _get_port_label(port_entry: Dictionary) -> String:
	if port_entry == null or port_entry.is_empty():
		return ""
	var display_name: String = GFVariantData.get_option_string(port_entry, "display_name", "")
	if not display_name.is_empty():
		return display_name
	return GFVariantData.get_option_string(port_entry, "port_id", "")


func _get_port_color(port_entry: Dictionary) -> Color:
	if port_entry == null or port_entry.is_empty():
		return _DEFAULT_NODE_COLOR
	var color: Color = _get_color_value(GFVariantData.get_option_value(port_entry, "editor_color", Color.TRANSPARENT))
	if color.a > 0.0:
		return color
	return _DEFAULT_NODE_COLOR


func _connect_graph_edit_nodes(connection: Dictionary) -> void:
	var from_node_id: StringName = _get_connection_from_node_id(connection)
	var to_node_id: StringName = _get_connection_to_node_id(connection)
	var from_node: GraphNode = _get_graph_node_value(GFVariantData.get_option_value(_node_controls_by_id, from_node_id))
	var to_node: GraphNode = _get_graph_node_value(GFVariantData.get_option_value(_node_controls_by_id, to_node_id))
	if from_node == null or to_node == null:
		return

	var from_slot: int = GFVariantData.get_option_int(connection, "from_graph_slot_index", GFVariantData.get_option_int(connection, "from_port_index", 0))
	var to_slot: int = GFVariantData.get_option_int(connection, "to_graph_slot_index", GFVariantData.get_option_int(connection, "to_port_index", 0))
	if from_slot < 0 or to_slot < 0:
		return
	_graph_edit.call("connect_node", from_node.name, from_slot, to_node.name, to_slot)


func _clear_graph_canvas() -> void:
	_node_controls_by_id.clear()
	_node_ids_by_control_name.clear()
	_selected_node_id = &""
	if _graph_edit == null:
		return

	if _graph_edit.has_method("clear_connections"):
		_graph_edit.call("clear_connections")
	for child: Node in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()


func _render_entries(view_model: Dictionary) -> void:
	var root_item: TreeItem = _tree.create_item()
	var visible_count: int = 0
	for node_variant: Variant in GFVariantData.get_option_array(view_model, "nodes"):
		var node: Dictionary = GFVariantData.as_dictionary(node_variant)
		if node.is_empty():
			continue
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, "节点")
		item.set_text(1, GFVariantData.get_option_string(node, "node_id", ""))
		item.set_text(2, GFVariantData.get_option_string(node, "category", ""))
		item.set_text(3, "%s  @ %s" % [GFVariantData.get_option_string(node, "display_name", ""), str(GFVariantData.get_option_value(node, "position", Vector2.ZERO))])
		item.set_metadata(0, node.duplicate(true))
		visible_count += 1

	for connection_variant: Variant in GFVariantData.get_option_array(view_model, "connections"):
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if connection.is_empty():
			continue
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, "连接")
		item.set_text(1, "%s -> %s" % [String(_get_connection_from_node_id(connection)), String(_get_connection_to_node_id(connection))])
		item.set_text(2, "%s -> %s" % [String(_get_connection_from_port_id(connection)), String(_get_connection_to_port_id(connection))])
		item.set_text(3, "valid=%s" % str(GFVariantData.get_option_bool(connection, "valid", false)))
		item.set_metadata(0, connection.duplicate(true))
		visible_count += 1

	var validation: Dictionary = GFVariantData.get_option_dictionary(view_model, "validation")
	for issue_variant: Variant in GFVariantData.get_option_array(validation, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if issue.is_empty():
			continue
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, GFVariantData.get_option_string(issue, "severity", ""))
		item.set_text(1, GFVariantData.get_option_string(issue, "kind", ""))
		item.set_text(2, GFVariantData.get_option_string(issue, "key", ""))
		item.set_text(3, GFVariantData.get_option_string(issue, "message", ""))
		item.set_metadata(0, issue.duplicate(true))
		visible_count += 1

	_tree.visible = visible_count > 0
	_empty_label.visible = visible_count == 0
	_empty_label.text = "当前 FlowGraph 没有节点、连接或校验问题。" if visible_count == 0 else ""


func _save_graph() -> Error:
	if _graph == null:
		return ERR_UNCONFIGURED

	_apply_canvas_layout_to_graph()
	var output_path: String = _graph_path
	if output_path.is_empty():
		output_path = _graph.resource_path
	if output_path.is_empty():
		return ERR_FILE_BAD_PATH

	var error: Error = ResourceSaver.save(_graph, output_path)
	if error == OK and Engine.is_editor_hint():
		var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
		if filesystem != null:
			filesystem.scan()
	return error


func _apply_canvas_layout_to_graph() -> void:
	if _graph == null:
		return

	for node_id_variant: Variant in _node_controls_by_id.keys():
		var node_id: StringName = _get_string_name_value(node_id_variant)
		var graph_node: GraphNode = _get_graph_node_value(GFVariantData.get_option_value(_node_controls_by_id, node_id))
		if graph_node != null:
			var applied: bool = _graph.set_node_editor_position(node_id, graph_node.position_offset)
			if applied:
				continue


func _get_node_id_for_control(control_name: StringName) -> StringName:
	return _get_string_name_value(GFVariantData.get_option_value(_node_ids_by_control_name, control_name, &""))


func _get_port_lookup_for_slot(node_id: StringName, ports_key: String, slot_index: int) -> Dictionary:
	if slot_index <= 0:
		return {
			"ok": true,
			"port_id": &"",
		}

	var node_entry: Dictionary = _get_node_entry(node_id)
	var ports: Array = GFVariantData.get_option_array(node_entry, ports_key)

	for port_variant: Variant in ports:
		var port: Dictionary = GFVariantData.as_dictionary(port_variant)
		if not port.is_empty() and GFVariantData.get_option_int(port, "graph_slot_index", -1) == slot_index:
			return {
				"ok": true,
				"port_id": GFVariantData.get_option_string_name(port, "port_id", &""),
			}
	return _make_port_lookup(false)


func _make_port_lookup(ok: bool) -> Dictionary:
	return {
		"ok": ok,
		"port_id": &"",
	}


func _get_node_entry(node_id: StringName) -> Dictionary:
	var lookup: Dictionary = GFVariantData.get_option_dictionary(_last_view_model, "node_lookup")
	if lookup.has(node_id):
		return GFVariantData.as_dictionary(GFVariantData.get_option_value(lookup, node_id, {}))
	return {}


func _show_details(value: Variant) -> void:
	_details.text = _safe_json(value)


func _safe_json(value: Variant) -> String:
	return GFReportValueCodec.stringify_json_compatible(value, "\t", false, {
		"path_redaction": "basename",
	})


# --- 信号处理函数 ---

func _on_path_submitted(path: String) -> void:
	set_graph_path(path)


func _on_browse_pressed() -> void:
	if is_instance_valid(_file_dialog):
		_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	set_graph_path(path)


func _on_refresh_pressed() -> void:
	_graph_path = _path_edit.text.strip_edges() if _path_edit != null else _graph_path
	_load_graph_from_path()
	refresh()


func _on_auto_layout_pressed() -> void:
	if _graph == null:
		return

	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var report: Dictionary = editor_model.auto_layout(_graph, _DEFAULT_LAYOUT_OPTIONS)
	refresh()
	_show_details(report)


func _on_save_pressed() -> void:
	var error: Error = _save_graph()
	_details.text = "保存结果：%s" % error_string(error)


func _on_connection_request(
	from_control_name: StringName,
	from_port_index: int,
	to_control_name: StringName,
	to_port_index: int
) -> void:
	if _graph == null:
		return

	var from_node_id: StringName = _get_node_id_for_control(from_control_name)
	var to_node_id: StringName = _get_node_id_for_control(to_control_name)
	var from_lookup: Dictionary = _get_port_lookup_for_slot(from_node_id, "output_ports", from_port_index)
	var to_lookup: Dictionary = _get_port_lookup_for_slot(to_node_id, "input_ports", to_port_index)
	if not GFVariantData.get_option_bool(from_lookup, "ok", false) or not GFVariantData.get_option_bool(to_lookup, "ok", false):
		_show_details({
			"ok": false,
			"error": "missing_port_for_slot",
			"from_slot": from_port_index,
			"to_slot": to_port_index,
		})
		return

	var added: bool = _graph.add_connection(
		from_node_id,
		GFVariantData.get_option_string_name(from_lookup, "port_id", &""),
		to_node_id,
		GFVariantData.get_option_string_name(to_lookup, "port_id", &"")
	)
	var report: Dictionary = {
		"ok": added,
		"action": "add_connection",
		"from_node_id": from_node_id,
		"to_node_id": to_node_id,
	}
	refresh()
	_show_details(report)


func _on_disconnection_request(
	from_control_name: StringName,
	from_port_index: int,
	to_control_name: StringName,
	to_port_index: int
) -> void:
	if _graph == null:
		return

	var from_node_id: StringName = _get_node_id_for_control(from_control_name)
	var to_node_id: StringName = _get_node_id_for_control(to_control_name)
	var from_lookup: Dictionary = _get_port_lookup_for_slot(from_node_id, "output_ports", from_port_index)
	var to_lookup: Dictionary = _get_port_lookup_for_slot(to_node_id, "input_ports", to_port_index)
	var removed: bool = false
	if GFVariantData.get_option_bool(from_lookup, "ok", false) and GFVariantData.get_option_bool(to_lookup, "ok", false):
		removed = _graph.remove_connection(
			from_node_id,
			GFVariantData.get_option_string_name(from_lookup, "port_id", &""),
			to_node_id,
			GFVariantData.get_option_string_name(to_lookup, "port_id", &"")
		)
	var report: Dictionary = {
		"ok": removed,
		"action": "remove_connection",
		"from_node_id": from_node_id,
		"to_node_id": to_node_id,
	}
	refresh()
	_show_details(report)


func _on_delete_nodes_request(control_names: Array) -> void:
	if _graph == null:
		return

	var node_ids: PackedStringArray = PackedStringArray()
	for control_name_variant: Variant in control_names:
		var node_id: StringName = _get_node_id_for_control(_get_string_name_value(control_name_variant))
		if node_id != &"":
			_append_packed_string(node_ids, String(node_id))
	if node_ids.is_empty() and _selected_node_id != &"":
		_append_packed_string(node_ids, String(_selected_node_id))

	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var report: Dictionary = editor_model.remove_nodes(_graph, node_ids)
	refresh()
	_show_details(report)


func _on_node_selected(node: Node) -> void:
	if node == null:
		return

	_selected_node_id = _get_string_name_value(node.get_meta("node_id", &""))
	var node_entry: Dictionary = _get_node_entry(_selected_node_id)
	if not node_entry.is_empty():
		_show_details(node_entry)


func _on_end_node_move() -> void:
	_apply_canvas_layout_to_graph()
	refresh()


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return

	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		_show_details(metadata)
