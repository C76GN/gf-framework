@tool
extends GutTest


# --- 常量 ---

const COMMAND_SCRIPT: Script = preload("res://addons/gf/extensions/flow/editor/gf_flow_graph_edit_command.gd")
const TEMPLATE_SCRIPT = preload("res://tests/gf_core/extensions/flow/fixtures/gf_flow_clipboard_node.gd")


# --- 内部类 ---

class QueryOverrideGraph extends GFFlowGraph:
	var query_count: int = 0

	func get_node(_node_id: StringName) -> GFFlowNode:
		query_count += 1
		return null

	func set_node(_node: GFFlowNode) -> void:
		query_count += 1

	func add_connection(_from: StringName, _from_port: StringName, _to: StringName, _to_port: StringName, _metadata: Dictionary = {}) -> bool:
		query_count += 1
		return false


class CopyMutationNode extends GFFlowNode:
	var copy_callback: Callable = Callable()

	@export var copy_probe: int = 1:
		get:
			var callback: Callable = copy_callback
			copy_callback = Callable()
			if callback.is_valid():
				callback.call()
			return 1
		set(_value):
			pass


class UndoManagerAdapter extends RefCounted:
	var history: UndoRedo = UndoRedo.new()
	var last_context: Object = null
	var action_count: int = 0

	func create_action(action_name: String, _merge_mode: int = 0, context: Object = null) -> void:
		last_context = context
		action_count += 1
		history.create_action(action_name)

	func get_object_history_id(_target: Object) -> int:
		return 1

	func add_do_method(target: Object, method_name: String) -> void:
		history.add_do_method(Callable(target, method_name))

	func add_undo_method(target: Object, method_name: String) -> void:
		history.add_undo_method(Callable(target, method_name))

	func add_do_reference(target: Object) -> void:
		history.add_do_reference(target)

	func add_undo_reference(target: Object) -> void:
		history.add_undo_reference(target)

	func commit_action(execute_immediately: bool = true) -> void:
		history.commit_action(execute_immediately)


# --- 私有变量 ---

var _docks: Array[GFFlowGraphDock] = []
var _undo: UndoManagerAdapter = null
var _saved_paths: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_undo = UndoManagerAdapter.new()


func after_each() -> void:
	for dock: GFFlowGraphDock in _docks:
		if is_instance_valid(dock):
			dock.free()
	_docks.clear()
	_undo.history.clear_history()
	_undo.history.free()
	_undo = null
	await get_tree().process_frame
	for path: String in _saved_paths:
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)
	_saved_paths.clear()


# --- 公共方法 ---

func test_copy_reads_exported_graph_without_project_queries() -> void:
	var graph: QueryOverrideGraph = QueryOverrideGraph.new()
	graph.nodes = [_node(&"a"), _node(&"b")]
	graph.start_node_id = &"a"
	graph.nodes[0].next_node_ids = PackedStringArray(["b", "outside"])
	var package: Dictionary = GFFlowGraphEditorModel.new().build_selection_package(graph, PackedStringArray(["a", "b"]))
	assert_true(GFVariantData.get_option_bool(package, "ok"))
	assert_eq(GFVariantData.get_option_int(package, "node_count"), 2)
	assert_eq(graph.query_count, 0)
	var copied: Array = GFVariantData.get_option_array(package, "nodes")
	if copied.size() == 2 and copied[0] is GFFlowNode:
		var first: GFFlowNode = copied[0]
		assert_not_same(first, graph.nodes[0])
		assert_eq(first.next_node_ids, PackedStringArray(["b"]))


func test_invalid_connection_rejects_paste_without_a_valid_prefix() -> void:
	var target: GFFlowGraph = GFFlowGraph.new()
	var old_node: GFFlowNode = _node(&"old")
	target.nodes = [old_node]
	var report: Dictionary = GFFlowGraphEditorModel.new().paste_selection_package(target, {
		"nodes": [_node(&"a")],
		"connections": [{"from_node_id": &"a", "from_port_id": &"", "to_node_id": &"missing", "to_port_id": &"", "metadata": {}}],
	})
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(target.nodes.size(), 1)
	assert_same(target.nodes[0], old_node)
	assert_true(target.connections.is_empty())


func test_cross_graph_paste_cannot_bind_an_external_successor_by_name() -> void:
	var source: GFFlowGraph = _source_graph()
	var package: Dictionary = GFFlowGraphEditorModel.new().build_selection_package(source, PackedStringArray(["a", "b"]))
	var target: QueryOverrideGraph = QueryOverrideGraph.new()
	target.nodes = [_node(&"outside")]
	target.start_node_id = &"outside"
	var report: Dictionary = GFFlowGraphEditorModel.new().paste_selection_package(target, package, Vector2(20, 30))
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(target.query_count, 0)
	assert_eq(target.start_node_id, &"outside")
	var pasted: GFFlowNode = _find_node(target, &"a")
	assert_not_null(pasted)
	if pasted != null:
		assert_eq(pasted.next_node_ids, PackedStringArray(["b"]))
		assert_eq(pasted.editor_position, Vector2(24, 38))


func test_paste_to_empty_graph_adopts_only_the_copied_source_start() -> void:
	var source: GFFlowGraph = _source_graph()
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var target: GFFlowGraph = GFFlowGraph.new()
	var report: Dictionary = model.paste_selection_package(target, model.build_selection_package(source, PackedStringArray(["a", "b"])))
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(target.start_node_id, &"a")
	var partial: GFFlowGraph = GFFlowGraph.new()
	var partial_report: Dictionary = model.paste_selection_package(partial, model.build_selection_package(source, PackedStringArray(["b"])))
	assert_true(GFVariantData.get_option_bool(partial_report, "ok"))
	assert_eq(partial.start_node_id, &"")


func test_prepared_paste_is_zero_write_and_restores_the_same_resources() -> void:
	var graph: GFFlowGraph = _source_graph()
	var original: Array[GFFlowNode] = graph.nodes.duplicate()
	var package: Dictionary = GFFlowGraphEditorModel.new().build_selection_package(graph, PackedStringArray(["a", "b"]))
	var command: GFFlowGraphEditCommand = _paste_command(graph, package)
	if command == null:
		return
	assert_eq(graph.nodes, original)
	assert_eq(command.execute(), OK)
	assert_eq(graph.nodes.size(), 5)
	var first_copy: GFFlowNode = _find_node(graph, &"a_2")
	var second_copy: GFFlowNode = _find_node(graph, &"b_2")
	assert_not_null(first_copy)
	assert_not_same(first_copy, original[0])
	assert_eq(command.revert(), OK)
	assert_eq(graph.nodes, original)
	assert_eq(graph.connections.size(), 1)
	assert_eq(command.execute(), OK)
	assert_same(_find_node(graph, &"a_2"), first_copy)
	assert_same(_find_node(graph, &"b_2"), second_copy)


func test_prepared_paste_rejects_changed_target_inventory() -> void:
	var graph: GFFlowGraph = _source_graph()
	var package: Dictionary = GFFlowGraphEditorModel.new().build_selection_package(graph, PackedStringArray(["a"]))
	var command: GFFlowGraphEditCommand = _paste_command(graph, package)
	if command == null:
		return
	var external: GFFlowNode = _node(&"a_2")
	graph.nodes.append(external)
	assert_ne(command.execute(), OK)
	assert_eq(graph.nodes.size(), 4)
	assert_same(graph.nodes[3], external)


func test_toolbar_duplicate_is_one_native_history_action() -> void:
	var graph: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(graph)
	var button: Button = _button(dock, "重复")
	assert_not_null(button)
	if button == null:
		return
	_select(dock, [&"a", &"b"])
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(_undo.action_count, 1)
	assert_same(_undo.last_context, graph)
	assert_eq(graph.nodes.size(), 5)
	var copied: GFFlowNode = _find_node(graph, &"a_2")
	assert_not_null(copied)
	assert_true(_undo.history.undo())
	assert_eq(graph.nodes.size(), 3)
	assert_true(_undo.history.redo())
	assert_same(_find_node(graph, &"a_2"), copied)


func test_copy_and_paste_toolbar_share_a_frozen_cross_graph_clipboard() -> void:
	var source: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(source)
	var copy_button: Button = _button(dock, "复制")
	var paste_button: Button = _button(dock, "粘贴")
	assert_not_null(copy_button)
	assert_not_null(paste_button)
	if copy_button == null or paste_button == null:
		return
	_select(dock, [&"a", &"b"])
	copy_button.pressed.emit()
	assert_eq(_undo.action_count, 0)
	source.nodes[0].display_name = "Edited after copy"
	var target: GFFlowGraph = GFFlowGraph.new()
	dock.set_graph(target)
	assert_false(paste_button.disabled)
	paste_button.pressed.emit()
	assert_eq(_undo.action_count, 1)
	assert_eq(target.nodes.size(), 2)
	assert_eq(target.nodes[0].display_name, "Original")
	assert_eq(target.start_node_id, &"a")
	assert_true(_undo.history.undo())
	assert_true(target.nodes.is_empty())
	assert_eq(target.start_node_id, &"")
	assert_eq(source.nodes.size(), 3)


func test_cut_and_native_duplicate_requests_use_the_same_resource_history() -> void:
	var graph: GFFlowGraph = _source_graph()
	var first: GFFlowNode = graph.nodes[0]
	var dock: GFFlowGraphDock = _dock(graph)
	var canvas: GraphEdit = _canvas(dock)
	_select(dock, [&"a"])
	canvas.cut_nodes_request.emit()
	assert_eq(graph.nodes.size(), 2)
	assert_eq(graph.start_node_id, &"")
	assert_eq(_undo.action_count, 1)
	assert_true(_undo.history.undo())
	assert_same(graph.nodes[0], first)
	assert_eq(graph.start_node_id, &"a")
	await get_tree().process_frame
	_select(dock, [&"a"])
	canvas.duplicate_nodes_request.emit()
	assert_eq(graph.nodes.size(), 4)
	assert_eq(_undo.action_count, 2)


func test_old_popup_and_retired_selection_cannot_edit_another_graph() -> void:
	var first: GFFlowGraph = _source_graph()
	var second: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(first)
	_select(dock, [&"a"])
	var canvas: GraphEdit = _canvas(dock)
	var retired: GraphNode = _node_control(dock, &"a")
	canvas.popup_request.emit(Vector2(80, 80))
	var menu: PopupMenu = _menu(dock)
	assert_not_null(menu)
	dock.set_graph(second)
	canvas.node_selected.emit(retired)
	if menu != null:
		menu.id_pressed.emit(3)
	assert_eq(first.nodes.size(), 3)
	assert_eq(second.nodes.size(), 3)
	assert_eq(_undo.action_count, 0)
	var button: Button = _button(dock, "重复")
	if button != null:
		assert_true(button.disabled)


func test_popup_becomes_stale_after_external_graph_change() -> void:
	var graph: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(graph)
	_select(dock, [&"a"])
	_canvas(dock).popup_request.emit(Vector2.ZERO)
	var menu: PopupMenu = _menu(dock)
	graph.nodes.append(_node(&"external"))
	graph.emit_changed()
	if menu != null:
		menu.id_pressed.emit(3)
	assert_eq(graph.nodes.size(), 4)
	assert_eq(_undo.action_count, 0)


func test_saved_template_preserves_subclass_and_ports_without_business_queries() -> void:
	var template: GFFlowNode = TEMPLATE_SCRIPT.new()
	template.node_id = &"template"
	var port: GFFlowPort = GFFlowPort.new()
	port.port_id = &"input"
	port.direction = GFFlowPort.Direction.INPUT
	port.value_type = GFFlowPort.ValueType.NUMBER
	template.input_ports = [port]
	var path: String = _save_template(template)
	assert_true(FileAccess.file_exists(path))
	var graph: GFFlowGraph = GFFlowGraph.new()
	var command: GFFlowGraphEditCommand = _template_command(graph, template, true)
	if command == null:
		return
	assert_true(graph.nodes.is_empty())
	assert_eq(command.execute(), OK)
	var copied: GFFlowNode = graph.nodes[0]
	assert_not_same(copied, template)
	var copied_script_value: Variant = copied.get_script()
	var template_script_value: Variant = template.get_script()
	assert_true(copied_script_value is Script)
	assert_true(template_script_value is Script)
	if copied_script_value is Script and template_script_value is Script:
		var copied_script: Script = copied_script_value
		var template_script: Script = template_script_value
		assert_same(copied_script, template_script)
	assert_not_same(copied.input_ports[0], port)
	assert_eq(copied.input_ports[0].value_type, GFFlowPort.ValueType.NUMBER)
	assert_eq(graph.start_node_id, &"template")
	var count_value: Variant = template.get("query_count")
	assert_true(count_value is int)
	if count_value is int:
		var count: int = count_value
		assert_eq(count, 0)
	assert_eq(command.revert(), OK)
	assert_true(graph.nodes.is_empty())
	assert_eq(graph.start_node_id, &"")
	assert_eq(command.execute(), OK)
	assert_same(graph.nodes[0], copied)


func test_template_start_is_explicit_and_existing_start_is_not_changed() -> void:
	var template: GFFlowNode = _node(&"template")
	var _path: String = _save_template(template)
	var empty_graph: GFFlowGraph = GFFlowGraph.new()
	var command: GFFlowGraphEditCommand = _template_command(empty_graph, template, false)
	if command == null:
		return
	assert_eq(command.execute(), OK)
	assert_eq(empty_graph.start_node_id, &"")
	var existing: GFFlowGraph = _source_graph()
	var second: GFFlowGraphEditCommand = _template_command(existing, template, true)
	if second != null:
		assert_eq(second.execute(), OK)
		assert_eq(existing.start_node_id, &"a")


func test_template_dialog_result_is_discarded_after_graph_switch() -> void:
	var template: GFFlowNode = _node(&"template")
	var path: String = _save_template(template)
	var first: GFFlowGraph = _source_graph()
	var second: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(first)
	var button: Button = _button(dock, "添加节点模板…")
	assert_not_null(button)
	if button == null:
		return
	button.pressed.emit()
	var dialog: FileDialog = _template_dialog(dock)
	assert_not_null(dialog)
	dock.set_graph(second)
	if dialog != null:
		dialog.file_selected.emit(path)
	assert_eq(first.nodes.size(), 3)
	assert_eq(second.nodes.size(), 3)
	assert_eq(_undo.action_count, 0)


func test_paste_rejects_typed_port_mismatch_without_writing_nodes() -> void:
	var source: GFFlowGraph = _source_graph()
	var out_port: GFFlowPort = GFFlowPort.new()
	out_port.port_id = &"out"
	out_port.direction = GFFlowPort.Direction.OUTPUT
	out_port.value_type = GFFlowPort.ValueType.NUMBER
	var in_port: GFFlowPort = GFFlowPort.new()
	in_port.port_id = &"in"
	in_port.direction = GFFlowPort.Direction.INPUT
	in_port.value_type = GFFlowPort.ValueType.STRING
	source.nodes[0].output_ports = [out_port]
	source.nodes[1].input_ports = [in_port]
	source.connections = [{"from_node_id": &"a", "from_port_id": &"out", "to_node_id": &"b", "to_port_id": &"in", "metadata": {}}]
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var package: Dictionary = model.build_selection_package(source, PackedStringArray(["a", "b"]))
	var target: GFFlowGraph = GFFlowGraph.new()
	var report: Dictionary = model.paste_selection_package(target, package)
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_true(target.nodes.is_empty())
	assert_true(target.connections.is_empty())


func test_read_only_view_can_copy_but_cannot_cut_paste_or_duplicate() -> void:
	var graph: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(graph)
	dock.set_editor_context(null)
	_select(dock, [&"a"])
	var copy_button: Button = _button(dock, "复制")
	var paste_button: Button = _button(dock, "粘贴")
	assert_not_null(copy_button)
	assert_not_null(paste_button)
	if copy_button != null and paste_button != null:
		assert_false(copy_button.disabled)
		copy_button.pressed.emit()
		assert_true(paste_button.disabled)
	_canvas(dock).cut_nodes_request.emit()
	_canvas(dock).duplicate_nodes_request.emit()
	_canvas(dock).paste_nodes_request.emit()
	assert_eq(graph.nodes.size(), 3)
	assert_eq(_undo.action_count, 0)


func test_invalid_options_and_nonfinite_layout_reject_without_partial_data() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var package: Dictionary = {"nodes": [_node(&"a")], "connections": []}
	var bad_options: Dictionary = model.paste_selection_package(graph, package, Vector2.ZERO, {"keep_original_ids": "true"})
	assert_false(GFVariantData.get_option_bool(bad_options, "ok"))
	var bad_position: Dictionary = model.paste_selection_package(graph, package, Vector2(INF, 0))
	assert_false(GFVariantData.get_option_bool(bad_position, "ok"))
	assert_true(graph.nodes.is_empty())
	assert_true(graph.connections.is_empty())


func test_template_selection_before_hide_cannot_commit_after_show() -> void:
	var template: GFFlowNode = _node(&"template")
	var path: String = _save_template(template)
	var graph: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(graph)
	var button: Button = _button(dock, "添加节点模板…")
	assert_not_null(button)
	if button == null:
		return
	button.pressed.emit()
	var dialog: FileDialog = _template_dialog(dock)
	assert_not_null(dialog)
	dock.hide()
	dock.show()
	if dialog != null:
		dialog.file_selected.emit(path)
	assert_eq(graph.nodes.size(), 3)
	assert_eq(_undo.action_count, 0)


func test_menu_before_hide_is_stale_after_show_but_completed_copy_remains() -> void:
	var graph: GFFlowGraph = _source_graph()
	var dock: GFFlowGraphDock = _dock(graph)
	_select(dock, [&"a"])
	var copy_button: Button = _button(dock, "复制")
	assert_not_null(copy_button)
	if copy_button == null:
		return
	copy_button.pressed.emit()
	_canvas(dock).popup_request.emit(Vector2.ZERO)
	var menu: PopupMenu = _menu(dock)
	assert_not_null(menu)
	dock.hide()
	dock.show()
	if menu != null:
		menu.id_pressed.emit(3)
	assert_eq(graph.nodes.size(), 3)
	assert_eq(_undo.action_count, 0)
	var paste_button: Button = _button(dock, "粘贴")
	assert_not_null(paste_button)
	if paste_button != null and graph.nodes.size() == 3:
		assert_false(paste_button.disabled)
		paste_button.pressed.emit()
		assert_eq(graph.nodes.size(), 4)
		assert_eq(_undo.action_count, 1)


func test_prepared_paste_rejects_changed_port_compatibility_without_writing_or_history() -> void:
	var graph: GFFlowGraph = _source_graph()
	graph.validate_port_compatibility = false
	var original_nodes: Array[GFFlowNode] = graph.nodes.duplicate()
	var original_connections: Array[Dictionary] = graph.connections.duplicate(true)
	var original_start: StringName = graph.start_node_id
	var command: GFFlowGraphEditCommand = _paste_command(graph, _incompatible_port_package(_node(&"a")))
	if command == null:
		return
	assert_true(command.can_execute(), "The prepared false policy permits the typed mismatch")
	graph.validate_port_compatibility = true
	assert_false(command.can_execute())
	assert_ne(command.execute(), OK)
	assert_eq(graph.nodes, original_nodes)
	assert_same(graph.nodes[0], original_nodes[0])
	assert_eq(graph.connections, original_connections)
	assert_eq(graph.start_node_id, original_start)
	assert_true(graph.validate_port_compatibility)
	assert_eq(_undo.action_count, 0)
	assert_false(_undo.history.has_undo())


func test_native_copy_policy_mutation_invalidates_the_whole_insert_plan() -> void:
	var graph: QueryOverrideGraph = QueryOverrideGraph.new()
	graph.nodes = [_node(&"existing")]
	graph.start_node_id = &"existing"
	graph.validate_port_compatibility = false
	var existing: GFFlowNode = graph.nodes[0]
	var source: CopyMutationNode = CopyMutationNode.new()
	source.node_id = &"a"
	var copy_calls: Array[int] = []
	source.copy_callback = func() -> void:
		copy_calls.append(1)
		graph.validate_port_compatibility = true
	var package: Dictionary = _incompatible_port_package(source)
	var value: Variant = COMMAND_SCRIPT.call("create_selection_paste", graph, package, Vector2(30, 30))
	var rejected: bool = value == null
	assert_true(rejected, "A real storage getter during native duplicate changed admission policy")
	assert_eq(copy_calls.size(), 1, "The native copy actually reached the controlled fixture getter")
	assert_eq(graph.nodes.size(), 1)
	assert_same(graph.nodes[0], existing)
	assert_true(graph.connections.is_empty())
	assert_eq(graph.start_node_id, &"existing")
	assert_true(graph.validate_port_compatibility, "The external policy mutation is not rolled back")
	assert_eq(graph.query_count, 0)
	assert_eq(_undo.action_count, 0)
	assert_false(_undo.history.has_undo())


func test_mutated_incoming_port_can_be_undone_but_cannot_redo_until_repaired() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var original: GFFlowNode = _node(&"existing")
	graph.nodes = [original]
	graph.start_node_id = &"existing"
	var package: Dictionary = _incompatible_port_package(_node(&"a"))
	var nodes: Array = GFVariantData.get_option_array(package, "nodes")
	var second_value: Variant = nodes[1]
	assert_true(second_value is GFFlowNode)
	if not (second_value is GFFlowNode):
		return
	var second: GFFlowNode = second_value
	second.input_ports[0].value_type = GFFlowPort.ValueType.NUMBER
	var command: GFFlowGraphEditCommand = _paste_command(graph, package)
	if command == null:
		return
	assert_eq(command.execute(), OK)
	var inserted: GFFlowNode = _find_node(graph, &"b")
	assert_not_null(inserted)
	if inserted == null:
		return
	var port: GFFlowPort = inserted.input_ports[0]
	port.value_type = GFFlowPort.ValueType.STRING
	assert_eq(command.revert(), OK, "Undo may still remove its insertion after a port mutation")
	assert_eq(graph.nodes, [original])
	assert_true(graph.connections.is_empty())
	assert_false(command.can_execute(), "The shared new_value resource no longer has admitted ports")
	assert_ne(command.execute(), OK)
	assert_eq(graph.nodes, [original])
	assert_same(graph.nodes[0], original)
	assert_true(graph.connections.is_empty())
	assert_eq(graph.start_node_id, &"existing")
	port.value_type = GFFlowPort.ValueType.NUMBER
	assert_true(command.can_execute(), "Repairing the admitted candidate allows retry")
	assert_eq(command.execute(), OK)
	assert_same(_find_node(graph, &"b"), inserted)
	assert_same(_find_node(graph, &"b").input_ports[0], port)


# --- 私有/辅助方法 ---

func _incompatible_port_package(first: GFFlowNode) -> Dictionary:
	var second: GFFlowNode = _node(&"b")
	var output: GFFlowPort = GFFlowPort.new()
	output.port_id = &"out"
	output.direction = GFFlowPort.Direction.OUTPUT
	output.value_type = GFFlowPort.ValueType.NUMBER
	var input: GFFlowPort = GFFlowPort.new()
	input.port_id = &"in"
	input.direction = GFFlowPort.Direction.INPUT
	input.value_type = GFFlowPort.ValueType.STRING
	first.output_ports = [output]
	second.input_ports = [input]
	return {"nodes": [first, second], "connections": [{"from_node_id": &"a", "from_port_id": &"out", "to_node_id": &"b", "to_port_id": &"in", "metadata": {}}]}

func _template_command(graph: GFFlowGraph, template: GFFlowNode, set_as_start: bool) -> GFFlowGraphEditCommand:
	assert_true(COMMAND_SCRIPT.has_method("create_template_insertion"))
	if not COMMAND_SCRIPT.has_method("create_template_insertion"):
		return null
	var value: Variant = COMMAND_SCRIPT.call("create_template_insertion", graph, template, Vector2(40, 50), set_as_start)
	assert_true(value is GFFlowGraphEditCommand)
	if value is GFFlowGraphEditCommand:
		return value
	return null


func _save_template(template: GFFlowNode) -> String:
	var path: String = "res://tests/gf_core/extensions/flow/_clipboard_template_%d_%d.tres" % [Time.get_ticks_usec(), _saved_paths.size()]
	var error: Error = ResourceSaver.save(template, path, ResourceSaver.FLAG_CHANGE_PATH)
	assert_eq(error, OK)
	if error == OK:
		template.take_over_path(path)
		assert_eq(template.resource_path, path)
	var _appended: bool = _saved_paths.append(path)
	return path


func _canvas(dock: GFFlowGraphDock) -> GraphEdit:
	for node: Node in dock.find_children("*", "GraphEdit", true, false):
		if node is GraphEdit:
			return node
	return null


func _node_control(dock: GFFlowGraphDock, identifier: StringName) -> GraphNode:
	for node: Node in _canvas(dock).get_children():
		if node is GraphNode:
			var control: GraphNode = node
			if control.get_meta("node_id", &"") == identifier:
				return control
	return null


func _menu(dock: GFFlowGraphDock) -> PopupMenu:
	for node: Node in dock.get_children():
		if node is PopupMenu:
			return node
	return null


func _template_dialog(dock: GFFlowGraphDock) -> FileDialog:
	for node: Node in dock.get_children():
		if node is FileDialog:
			var dialog: FileDialog = node
			if dialog.title == "选择已保存的 Flow 节点模板":
				return dialog
	return null


func _paste_command(graph: GFFlowGraph, package: Dictionary) -> GFFlowGraphEditCommand:
	assert_true(COMMAND_SCRIPT.has_method("create_selection_paste"), "粘贴必须有零写入的属性事务候选入口。")
	if not COMMAND_SCRIPT.has_method("create_selection_paste"):
		return null
	var value: Variant = COMMAND_SCRIPT.call("create_selection_paste", graph, package, Vector2(30, 30), "粘贴 Flow 节点")
	assert_true(value is GFFlowGraphEditCommand)
	if value is GFFlowGraphEditCommand:
		return value
	return null


func _node(identifier: StringName) -> GFFlowNode:
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = identifier
	return node


func _source_graph() -> GFFlowGraph:
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.nodes = [_node(&"a"), _node(&"b"), _node(&"outside")]
	graph.start_node_id = &"a"
	graph.nodes[0].display_name = "Original"
	graph.nodes[0].editor_position = Vector2(4, 8)
	graph.nodes[0].next_node_ids = PackedStringArray(["b", "outside"])
	graph.connections = [{"from_node_id": &"a", "from_port_id": &"", "to_node_id": &"b", "to_port_id": &"", "metadata": {"weight": 4}}]
	return graph


func _find_node(graph: GFFlowGraph, identifier: StringName) -> GFFlowNode:
	for node: GFFlowNode in graph.nodes:
		if node != null and node.node_id == identifier:
			return node
	return null


func _dock(graph: GFFlowGraph) -> GFFlowGraphDock:
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.undo_manager = _undo
	dock.set_editor_context(context)
	add_child(dock)
	_docks.append(dock)
	dock.set_graph(graph)
	return dock


func _button(dock: GFFlowGraphDock, text: String) -> Button:
	for node: Node in dock.find_children("*", "Button", true, false):
		if node is Button:
			var button: Button = node
			if button.text == text:
				return button
	return null


func _select(dock: GFFlowGraphDock, identifiers: Array[StringName]) -> void:
	for node: Node in dock.find_children("*", "GraphNode", true, false):
		if node is GraphNode:
			var graph_node: GraphNode = node
			var value: Variant = graph_node.get_meta("node_id", &"")
			if value is StringName:
				var identifier: StringName = value
				graph_node.selected = identifiers.has(identifier)
				var parent: Node = graph_node.get_parent()
				if graph_node.selected and parent is GraphEdit:
					var canvas: GraphEdit = parent
					canvas.node_selected.emit(graph_node)
