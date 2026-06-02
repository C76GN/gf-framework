@tool

# GF Flow Graph Inspector: 在 Inspector 中辅助检查资源化流程图。
extends EditorInspectorPlugin


# --- 常量 ---

const _FLOW_EXTENSION_ID: String = "gf.flow"
const _GF_FLOW_GRAPH_SCRIPT_PATH: String = "res://addons/gf/extensions/flow/resources/gf_flow_graph.gd"
const _GF_EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	if not _GF_EXTENSION_SETTINGS_SCRIPT.is_extension_enabled(_FLOW_EXTENSION_ID):
		return false

	var resource: Resource = _get_resource_value(object)
	if resource == null:
		return false

	var flow_graph_script: Script = _get_flow_graph_script()
	var script: Script = _get_script_value(resource.get_script())
	return (
		flow_graph_script != null
		and script != null
		and _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(script, flow_graph_script)
	)


func _parse_begin(object: Object) -> void:
	var graph: Resource = _get_resource_value(object)
	if graph == null:
		return

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GFFlowGraphInspector"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_custom_control(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "GF Flow Graph"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var validate_button: Button = Button.new()
	validate_button.text = "校验"
	validate_button.tooltip_text = "校验流程图节点、端口与连接"
	header.add_child(validate_button)

	var start_row: HBoxContainer = HBoxContainer.new()
	start_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(start_row)

	var start_label: Label = Label.new()
	start_label.text = "起始节点"
	start_label.custom_minimum_size = Vector2(72.0, 0.0)
	start_row.add_child(start_label)

	var start_option: OptionButton = OptionButton.new()
	start_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_option.tooltip_text = "从当前流程图节点中选择 start_node_id"
	start_row.add_child(start_option)
	_populate_start_options(start_option, graph)
	_connect_signal(start_option.item_selected, _on_start_node_selected.bind(start_option, graph), CONNECT_DEFERRED)

	var summary_label: Label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	root.add_child(summary_label)
	_update_summary(summary_label, graph)
	_connect_signal(validate_button.pressed, _on_validate_pressed.bind(summary_label, graph), CONNECT_DEFERRED)


# --- 私有/辅助方法 ---

func _populate_start_options(option: OptionButton, graph: Resource) -> void:
	option.clear()
	option.add_item("未设置", 0)
	option.set_item_metadata(0, &"")
	option.select(0)

	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var catalog: Dictionary = editor_model.build_editor_catalog(graph)
	var nodes: Array = GFVariantData.get_option_array(catalog, "nodes")
	if nodes.is_empty():
		return

	var entries: Array[Dictionary] = []
	for node_variant: Variant in nodes:
		var node: Dictionary = GFVariantData.as_dictionary(node_variant)
		if node.is_empty():
			continue
		var node_id: StringName = GFVariantData.get_option_string_name(node, "node_id", &"")
		if node_id == &"":
			continue
		entries.append({
			"node_id": node_id,
			"display_name": GFVariantData.get_option_string(node, "display_name", String(node_id)),
		})

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "display_name") < GFVariantData.get_option_string(right, "display_name")
	)

	var current_start: StringName = GFVariantData.to_string_name(GFObjectPropertyTools.read_property(graph, NodePath("start_node_id")))
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		option.add_item(GFVariantData.get_option_string(entry, "display_name"), index + 1)
		option.set_item_metadata(index + 1, entry["node_id"])
		if entry["node_id"] == current_start:
			option.select(index + 1)


func _get_flow_graph_script() -> Script:
	if not ResourceLoader.exists(_GF_FLOW_GRAPH_SCRIPT_PATH):
		return null
	var resource: Resource = load(_GF_FLOW_GRAPH_SCRIPT_PATH)
	return _get_script_value(resource)


func _set_start_node(graph: Resource, node_id: StringName) -> void:
	var old_value: StringName = GFVariantData.to_string_name(GFObjectPropertyTools.read_property(graph, NodePath("start_node_id")))
	if old_value == node_id:
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("设置 GF FlowGraph 起始节点")
	undo_redo.add_do_property(graph, "start_node_id", node_id)
	undo_redo.add_undo_property(graph, "start_node_id", old_value)
	undo_redo.commit_action()


func _update_summary(label: Label, graph: Resource) -> void:
	if label == null or graph == null:
		return

	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var report: Dictionary = editor_model.build_editor_report(graph)
	var validation: Dictionary = GFVariantData.get_option_dictionary(report, "validation")
	label.text = "%s\nNext: %s" % [
		GFVariantData.get_option_string(report, "summary"),
		GFVariantData.get_option_string(report, "next_action"),
	]
	if GFVariantData.get_option_int(validation, "error_count") > 0:
		label.modulate = Color(1.0, 0.45, 0.35)
	elif GFVariantData.get_option_int(validation, "warning_count") > 0:
		label.modulate = Color(1.0, 0.75, 0.25)
	else:
		label.modulate = Color(0.55, 0.9, 0.65)


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _connect_signal(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	var connected: int = source_signal.connect(callback, flags as Object.ConnectFlags)
	if connected == OK:
		return


# --- 信号处理函数 ---

func _on_validate_pressed(summary_label: Label, graph: Resource) -> void:
	_update_summary(summary_label, graph)


func _on_start_node_selected(index: int, option: OptionButton, graph: Resource) -> void:
	if graph == null:
		return

	var node_id: StringName = GFVariantData.to_string_name(option.get_item_metadata(index))
	_set_start_node(graph, node_id)
