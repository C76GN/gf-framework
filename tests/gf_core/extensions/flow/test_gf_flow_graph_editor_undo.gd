extends GutTest


# --- 内部类 ---

class UndoManagerAdapter extends RefCounted:
	var history: UndoRedo = UndoRedo.new()
	var last_context: Object = null
	var history_ids: Dictionary = {}
	var action_count: int = 0

	func create_action(action_name: String, _merge_mode: int = 0, context: Object = null) -> void:
		last_context = context
		action_count += 1
		history.create_action(action_name)

	func get_object_history_id(target: Object) -> int:
		return GFVariantData.get_option_int(history_ids, target.get_instance_id(), 1)

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


class QueryOverrideGraph extends GFFlowGraph:
	var query_call_count: int = 0

	func get_node(_node_id: StringName) -> GFFlowNode:
		query_call_count += 1
		return null

	func has_node(_node_id: StringName) -> bool:
		query_call_count += 1
		return false


# --- 私有变量 ---

var _docks: Array[GFFlowGraphDock] = []
var _undo: UndoManagerAdapter
var _saved_paths: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_undo = UndoManagerAdapter.new()


func after_each() -> void:
	await get_tree().process_frame
	for dock: GFFlowGraphDock in _docks:
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

func test_prepared_connection_command_reports_actual_execution() -> void:
	var graph: GFFlowGraph = _make_graph()
	var command: GFFlowGraphEditCommand = GFFlowGraphEditCommand.create_connection_edit(graph, &"a", &"", &"b", &"")
	assert_not_null(command)
	if command == null:
		return
	var error: Error = command.execute()
	assert_eq(error, OK, str(command.get_transaction_report()))
	assert_eq(graph.connections.size(), 1)
	assert_eq(command.revert(), OK)
	assert_true(graph.connections.is_empty())

func test_connection_edits_use_resource_history_and_refresh_after_undo_redo() -> void:
	var graph: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(graph)
	_connect_nodes(dock, &"a", &"b")
	assert_true(graph.has_connection(&"a", &"", &"b", &""))
	assert_eq(_undo.last_context, graph)
	assert_eq(_undo.action_count, 1)
	assert_true(_undo.history.undo())
	assert_false(graph.has_connection(&"a", &"", &"b", &""))
	await get_tree().process_frame
	assert_eq(_canvas(dock).get_connection_list().size(), 0)
	assert_true(_undo.history.redo())
	await get_tree().process_frame
	assert_eq(_canvas(dock).get_connection_list().size(), 1)
	var canvas: GraphEdit = _canvas(dock)
	canvas.disconnection_request.emit(_node_control(dock, &"a").name, 0, _node_control(dock, &"b").name, 0)
	assert_false(graph.has_connection(&"a", &"", &"b", &""))
	assert_true(_undo.history.undo())
	assert_true(graph.has_connection(&"a", &"", &"b", &""))


func test_delete_restores_nodes_connections_and_execution_successors_with_identity() -> void:
	var graph: GFFlowGraph = _make_graph()
	var a: GFFlowNode = graph.get_node(&"a")
	var b: GFFlowNode = graph.get_node(&"b")
	a.next_node_ids = PackedStringArray(["b", "c"])
	assert_true(graph.add_connection(&"b", &"", &"c", &"", {"weight": 7}))
	var connections_before: Array[Dictionary] = graph.connections.duplicate(true)
	var dock: GFFlowGraphDock = _make_dock(graph)
	_canvas(dock).delete_nodes_request.emit([_node_control(dock, &"b").name])
	assert_false(graph.has_node(&"b"))
	assert_eq(a.next_node_ids, PackedStringArray(["c"]))
	assert_true(graph.connections.is_empty())
	assert_eq(_undo.action_count, 1)
	assert_true(_undo.history.undo())
	assert_same(graph.get_node(&"b"), b)
	assert_eq(a.next_node_ids, PackedStringArray(["b", "c"]))
	assert_eq(graph.connections, connections_before)
	assert_true(_undo.history.redo())
	assert_false(graph.has_node(&"b"))


func test_drag_is_one_action_and_auto_layout_is_undoable() -> void:
	var graph: GFFlowGraph = _make_graph()
	var a: GFFlowNode = graph.get_node(&"a")
	var b: GFFlowNode = graph.get_node(&"b")
	var dock: GFFlowGraphDock = _make_dock(graph)
	var canvas: GraphEdit = _canvas(dock)
	canvas.begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(80, 90)
	_node_control(dock, &"b").position_offset = Vector2(150, 200)
	assert_eq(a.editor_position, Vector2.ZERO)
	canvas.end_node_move.emit()
	assert_eq(_undo.action_count, 1)
	assert_eq(a.editor_position, Vector2(80, 90))
	assert_eq(b.editor_position, Vector2(150, 200))
	assert_true(_undo.history.undo())
	assert_eq(a.editor_position, Vector2.ZERO)
	assert_eq(b.editor_position, Vector2.ZERO)
	assert_true(_undo.history.redo())
	await get_tree().process_frame
	_button(dock, "自动布局").pressed.emit()
	assert_eq(_undo.action_count, 2)
	assert_true(_undo.history.undo())
	assert_eq(a.editor_position, Vector2(80, 90))
	assert_eq(b.editor_position, Vector2(150, 200))


func test_without_editor_context_requests_do_not_modify_the_graph() -> void:
	var graph: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(graph, false)
	_connect_nodes(dock, &"a", &"b")
	assert_true(graph.connections.is_empty())
	_button(dock, "自动布局").pressed.emit()
	assert_eq(graph.get_node(&"b").editor_position, Vector2.ZERO)
	assert_eq(_undo.action_count, 0)


func test_history_does_not_hold_the_dock_or_apply_old_graph_state_to_a_new_graph() -> void:
	var first: GFFlowGraph = _make_graph()
	var second: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(first)
	_connect_nodes(dock, &"a", &"b")
	dock.set_graph(second)
	assert_true(_undo.history.undo())
	await get_tree().process_frame
	assert_eq(_canvas(dock).get_connection_list().size(), 0)
	assert_true(second.connections.is_empty())
	_docks.erase(dock)
	var dock_ref: WeakRef = weakref(dock)
	dock.free()
	assert_true(dock_ref.get_ref() == null)
	assert_true(_undo.history.redo())
	assert_true(first.has_connection(&"a", &"", &"b", &""))
	assert_true(second.connections.is_empty())


func test_rejected_duplicate_connection_and_unchanged_drag_do_not_create_history() -> void:
	var graph: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(graph)
	_connect_nodes(dock, &"a", &"b")
	_connect_nodes(dock, &"a", &"b")
	assert_eq(_undo.action_count, 1)
	assert_eq(graph.connections.size(), 1)
	_canvas(dock).begin_node_move.emit()
	_canvas(dock).end_node_move.emit()
	assert_eq(_undo.action_count, 1)
	assert_true(_undo.history.undo())
	assert_true(graph.connections.is_empty())


func test_cross_history_layout_rejects_the_whole_action() -> void:
	var graph: GFFlowGraph = _make_graph()
	var a: GFFlowNode = graph.get_node(&"a")
	var b: GFFlowNode = graph.get_node(&"b")
	_undo.history_ids[b.get_instance_id()] = 2
	var dock: GFFlowGraphDock = _make_dock(graph)
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(12, 34)
	_node_control(dock, &"b").position_offset = Vector2(56, 78)
	_canvas(dock).end_node_move.emit()
	assert_eq(a.editor_position, Vector2.ZERO)
	assert_eq(b.editor_position, Vector2.ZERO)
	assert_eq(_undo.action_count, 0)
	assert_false(_undo.history.has_undo())
	assert_eq(_node_control(dock, &"a").position_offset, Vector2.ZERO)


func test_context_revocation_cancels_unsubmitted_drag() -> void:
	var graph: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(graph)
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(15, 30)
	dock.set_editor_context(null)
	_canvas(dock).end_node_move.emit()
	assert_eq(graph.get_node(&"a").editor_position, Vector2.ZERO)
	assert_eq(_undo.action_count, 0)
	assert_true(_button(dock, "自动布局").disabled)
	assert_true(_button(dock, "保存").disabled)
	assert_false(_node_control(dock, &"a").draggable)


func test_resource_switch_discards_unsubmitted_layout_and_start_removal_is_undoable() -> void:
	var first: GFFlowGraph = _make_graph()
	var second: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(first)
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(17, 38)
	dock.set_graph(second)
	_canvas(dock).end_node_move.emit()
	assert_eq(first.get_node(&"a").editor_position, Vector2.ZERO)
	assert_eq(second.get_node(&"a").editor_position, Vector2.ZERO)
	assert_eq(_undo.action_count, 0)
	_canvas(dock).delete_nodes_request.emit([_node_control(dock, &"a").name])
	assert_eq(second.start_node_id, &"")
	assert_true(_undo.history.undo())
	assert_eq(second.start_node_id, &"a")
	assert_true(second.has_node(&"a"))


func test_save_writes_committed_layout_and_keeps_undo_history() -> void:
	var graph: GFFlowGraph = _make_graph()
	var path: String = "res://tests/gf_core/extensions/flow/_editor_save_%d_%d.tres" % [Time.get_ticks_usec(), get_instance_id()]
	assert_eq(ResourceSaver.save(graph, path), OK)
	var _appended: bool = _saved_paths.append(path)
	var dock: GFFlowGraphDock = _make_dock(graph)
	dock.set_graph(graph, path)
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(42, 64)
	_canvas(dock).end_node_move.emit()
	_button(dock, "保存").pressed.emit()
	assert_eq(_read_saved_position(path), Vector2(42, 64))
	assert_true(_undo.history.undo())
	assert_eq(graph.get_node(&"a").editor_position, Vector2.ZERO)
	assert_eq(_read_saved_position(path), Vector2(42, 64), "撤销不应隐式改写已保存的磁盘资源。")
	await get_tree().process_frame
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(99, 100)
	_button(dock, "保存").pressed.emit()
	assert_eq(_read_saved_position(path), Vector2.ZERO, "保存不能旁路命令提交进行中的画布拖动。")
	assert_eq(_undo.action_count, 1)


func test_layout_planning_rejects_invalid_member_without_partial_writes() -> void:
	var graph: GFFlowGraph = _make_graph()
	var command: GFFlowGraphEditCommand = GFFlowGraphEditCommand.create_layout_edit(graph, {
		&"a": Vector2(12, 34), &"b": Vector2(INF, 0),
	}, "Invalid layout")
	assert_null(command)
	assert_eq(graph.get_node(&"a").editor_position, Vector2.ZERO)
	assert_eq(graph.get_node(&"b").editor_position, Vector2.ZERO)


func test_editor_commands_use_properties_without_calling_graph_query_overrides() -> void:
	var graph: QueryOverrideGraph = QueryOverrideGraph.new()
	graph.nodes = _make_graph().nodes
	graph.start_node_id = &"a"
	var first: GFFlowNode = graph.nodes[0]
	var layout: GFFlowGraphEditCommand = GFFlowGraphEditCommand.create_layout_edit(graph, {
		&"a": Vector2(12, 34),
	}, "Property layout")
	assert_not_null(layout)
	if layout != null:
		assert_eq(layout.execute(), OK)
		assert_eq(first.editor_position, Vector2(12, 34))
		assert_eq(layout.revert(), OK)
		assert_eq(first.editor_position, Vector2.ZERO)
	var removal: GFFlowGraphEditCommand = GFFlowGraphEditCommand.create_node_removal(graph, PackedStringArray(["a"]))
	assert_not_null(removal)
	if removal != null:
		assert_eq(removal.execute(), OK)
		assert_eq(graph.nodes.size(), 2)
		assert_eq(graph.start_node_id, &"")
		assert_eq(removal.revert(), OK)
		assert_eq(graph.start_node_id, &"a")
		assert_same(graph.nodes[0], first)
	assert_eq(graph.query_call_count, 0, "编辑器事务只读取导出属性，不执行项目图脚本的查询方法。")


func test_reentering_with_context_restores_editing_and_graph_change_refresh() -> void:
	var graph: GFFlowGraph = _make_graph()
	var dock: GFFlowGraphDock = _make_dock(graph)
	remove_child(dock)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.undo_manager = _undo
	dock.set_editor_context(context)
	assert_true(_button(dock, "自动布局").disabled)
	assert_false(_node_control(dock, &"a").draggable)
	add_child(dock)
	assert_false(_button(dock, "自动布局").disabled, "重新入树应恢复编辑器命令入口。")
	assert_false(_button(dock, "保存").disabled)
	assert_true(_node_control(dock, &"a").draggable)
	graph.nodes[0].editor_position = Vector2(81, 92)
	graph.emit_changed()
	await get_tree().process_frame
	assert_eq(_node_control(dock, &"a").position_offset, Vector2(81, 92), "重新入树应恢复资源变化订阅。")
	_canvas(dock).begin_node_move.emit()
	_node_control(dock, &"a").position_offset = Vector2(24, 36)
	_canvas(dock).end_node_move.emit()
	assert_eq(graph.nodes[0].editor_position, Vector2(24, 36))
	assert_eq(_undo.action_count, 1)
	assert_true(_undo.history.undo())
	assert_eq(graph.nodes[0].editor_position, Vector2(81, 92))


# --- 私有/辅助方法 ---

func _read_saved_position(path: String) -> Vector2:
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert_true(loaded is GFFlowGraph)
	if loaded is GFFlowGraph:
		var graph: GFFlowGraph = loaded
		return graph.get_node(&"a").editor_position
	return Vector2(INF, INF)

func _make_graph() -> GFFlowGraph:
	var graph: GFFlowGraph = GFFlowGraph.new()
	for node_id: StringName in [&"a", &"b", &"c"]:
		var node: GFFlowNode = GFFlowNode.new()
		node.node_id = node_id
		graph.nodes.append(node)
	graph.start_node_id = &"a"
	return graph


func _make_dock(graph: GFFlowGraph, with_context: bool = true) -> GFFlowGraphDock:
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()
	_docks.append(dock)
	if with_context:
		var context: GFEditorToolContext = GFEditorToolContext.new()
		context.undo_manager = _undo
		dock.set_editor_context(context)
	add_child(dock)
	dock.set_graph(graph)
	return dock


func _canvas(dock: GFFlowGraphDock) -> GraphEdit:
	for node: Node in dock.find_children("*", "GraphEdit", true, false):
		if node is GraphEdit:
			return node
	return null


func _node_control(dock: GFFlowGraphDock, node_id: StringName) -> GraphNode:
	for node: Node in _canvas(dock).get_children():
		if node is GraphNode and node.get_meta("node_id", &"") == node_id:
			return node
	return null


func _button(dock: GFFlowGraphDock, label: String) -> Button:
	for node: Node in dock.find_children("*", "Button", true, false):
		if node is Button:
			var button: Button = node
			if button.text == label:
				return button
	return null


func _connect_nodes(dock: GFFlowGraphDock, from: StringName, to: StringName) -> void:
	_canvas(dock).connection_request.emit(_node_control(dock, from).name, 0, _node_control(dock, to).name, 0)
