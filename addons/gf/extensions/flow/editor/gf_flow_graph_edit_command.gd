@tool

## Flow 编辑操作的属性事务与资源通知适配。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFFlowGraphEditCommand
extends GFEditorPropertyBatchCommand


# --- 私有变量 ---

var _graph: GFFlowGraph = null
var _observer: WeakRef = null


# --- 可重写钩子 / 虚方法 ---

func _do_it() -> Error:
	var error: Error = super._do_it()
	if error == OK and _graph != null:
		_graph.emit_changed()
	_notify_observer()
	return error


func _undo_it() -> Error:
	var error: Error = super._undo_it()
	if error == OK and _graph != null:
		_graph.emit_changed()
	_notify_observer()
	return error


func _get_undo_context() -> Object:
	return _graph


# --- 框架内部方法 ---

## 只弱引用当前页面，历史命令不会延长页面生命周期。
## [br]
## @api framework_internal
## [br]
## @param page: 接收编辑结果的页面；null 清除观察者，已封存命令不再变更观察者。
func observe_page(page: Node) -> void:
	if not is_sealed():
		_observer = weakref(page) if page != null else null


## 返回当前事务归属的图资源。
## [br]
## @api framework_internal
## [br]
## @return: 当前事务归属的图资源；未配置时为 null。
func get_graph_for_editor() -> GFFlowGraph:
	return _graph


## 为图连接创建零写入候选；无变化或无效请求返回 null。
## [br]
## @api framework_internal
## [br]
## @param graph: 连接所属图资源；构建候选期间不修改该资源。
## [br]
## @param from_node_id: 源节点标识。
## [br]
## @param from_port_id: 源端口标识；执行连接的两端端口标识均为空。
## [br]
## @param to_node_id: 目标节点标识。
## [br]
## @param to_port_id: 目标端口标识；执行连接的两端端口标识均为空。
## [br]
## @param remove: true 构建删除连接命令，false 构建添加连接命令。
## [br]
## @return: 尚未执行的连接编辑命令；图为空、请求无效或没有变化时为 null。
static func create_connection_edit(
	graph: GFFlowGraph,
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName,
	remove: bool = false
) -> GFFlowGraphEditCommand:
	if graph == null:
		return null
	var candidate: GFFlowGraph = GFFlowGraph.new()
	candidate.nodes = graph.nodes.duplicate()
	candidate.connections = graph.connections.duplicate(true)
	candidate.validate_port_compatibility = graph.validate_port_compatibility
	var changed: bool = false
	if remove:
		changed = candidate.remove_connection(from_node_id, from_port_id, to_node_id, to_port_id)
	else:
		changed = candidate.add_connection(from_node_id, from_port_id, to_node_id, to_port_id)
	if not changed:
		return null
	return _create(graph, [{
		"target": graph, "property_name": &"connections", "new_value": candidate.connections,
	}], "删除 Flow 连接" if remove else "添加 Flow 连接")


## 以一个事务删除节点及其显式连接和执行后继引用，保留资源身份以便撤销。
## [br]
## @api framework_internal
## [br]
## @param graph: 待删除节点所属图资源；构建候选期间不修改该资源。
## [br]
## @param node_ids: 待删除节点标识列表，不存在的标识会被忽略。
## [br]
## @return: 尚未执行的节点删除命令；图为空或没有匹配节点时为 null。
static func create_node_removal(graph: GFFlowGraph, node_ids: PackedStringArray) -> GFFlowGraphEditCommand:
	if graph == null or node_ids.is_empty():
		return null
	var removed: Dictionary = {}
	for node_id: String in node_ids:
		if _find_node(graph, StringName(node_id)) != null:
			removed[StringName(node_id)] = true
	if removed.is_empty():
		return null
	var remaining: Array[GFFlowNode] = []
	var changes: Array[Dictionary] = []
	for node: GFFlowNode in graph.nodes:
		if node == null:
			remaining.append(node)
			continue
		if removed.has(node.node_id):
			continue
		remaining.append(node)
		var successors: PackedStringArray = PackedStringArray()
		for successor: String in node.next_node_ids:
			if not removed.has(StringName(successor)):
				var _appended: bool = successors.append(successor)
		if successors != node.next_node_ids:
			changes.append({"target": node, "property_name": &"next_node_ids", "new_value": successors})
	var connections: Array[Dictionary] = []
	for connection: Dictionary in graph.connections:
		var from_id: StringName = GFVariantData.get_option_string_name(connection, "from_node_id")
		var to_id: StringName = GFVariantData.get_option_string_name(connection, "to_node_id")
		if not removed.has(from_id) and not removed.has(to_id):
			connections.append(connection.duplicate(true))
	changes.append({"target": graph, "property_name": &"nodes", "new_value": remaining})
	if graph.connections != connections:
		changes.append({"target": graph, "property_name": &"connections", "new_value": connections})
	if removed.has(graph.start_node_id):
		changes.append({"target": graph, "property_name": &"start_node_id", "new_value": &""})
	return _create(graph, changes, "删除 Flow 节点")


## 为一次拖动或自动布局构建多节点位置事务；拒绝无效节点或非有限位置。
## [br]
## @api framework_internal
## [br]
## @param graph: 布局所属图资源；构建候选期间不修改节点资源。
## [br]
## @param positions: 节点标识到候选位置的映射，可使用 GFFlowGraphEditorModel.build_layout_positions() 的结果。
## [br]
## @schema positions: Dictionary，键为现有节点的 String 或 StringName 标识，值为有限 Vector2 位置。
## [br]
## @param action_name: 撤销历史中显示的操作名称。
## [br]
## @return: 尚未执行的布局编辑命令；图为空、候选无效或所有位置均未变化时为 null。
static func create_layout_edit(graph: GFFlowGraph, positions: Dictionary, action_name: String) -> GFFlowGraphEditCommand:
	if graph == null:
		return null
	var changes: Array[Dictionary] = []
	for key: Variant in positions:
		if not key is String and not key is StringName:
			return null
		var node_id: StringName = StringName(str(key))
		var node: GFFlowNode = _find_node(graph, node_id)
		var value: Variant = positions[key]
		if node == null or not value is Vector2:
			return null
		var position: Vector2 = value
		if not position.is_finite():
			return null
		if node.editor_position != position:
			changes.append({"target": node, "property_name": &"editor_position", "new_value": position})
	if changes.is_empty():
		return null
	return _create(graph, changes, action_name)


# --- 私有/辅助方法 ---

static func _find_node(graph: GFFlowGraph, node_id: StringName) -> GFFlowNode:
	for node: GFFlowNode in graph.nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func _notify_observer() -> void:
	if _observer == null:
		return
	var value: Variant = _observer.get_ref()
	if value is Object and is_instance_valid(value):
		var page: Object = value
		if page.has_method("accept_flow_edit_result"):
			var _result: Variant = page.call("accept_flow_edit_result", self)


static func _create(graph: GFFlowGraph, changes: Array[Dictionary], action_name: String) -> GFFlowGraphEditCommand:
	var command: GFFlowGraphEditCommand = GFFlowGraphEditCommand.new()
	command._graph = graph
	var _configured: GFEditorPropertyBatchCommand = command.configure(changes, {"command_name": action_name})
	return command
