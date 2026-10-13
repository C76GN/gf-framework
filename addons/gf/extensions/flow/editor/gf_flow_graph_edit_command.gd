@tool

## Flow 编辑操作的属性事务与资源通知适配。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFFlowGraphEditCommand
extends GFEditorPropertyBatchCommand


# --- 私有变量 ---

## 保存流程图编辑器内部的流程图。
## [br]
## @api private
var _graph: GFFlowGraph = null

## 保存流程图编辑器内部的观察者。
## [br]
## @api private
var _observer: WeakRef = null

## 插入前的图库存快照；插入候选不得覆盖准备后发生的外部结构编辑。
## [br]
## @api private
var _insert_before: Dictionary = {}

## 成功插入后的图库存快照；撤销只接管仍与该命令对应的结构。
## [br]
## @api private
var _insert_after: Dictionary = {}

## 成功插入节点的标识；页面可在提交后选择这些节点，不持有旧控件。
## [br]
## @api private
var _inserted_ids: PackedStringArray = PackedStringArray()

## 仅持有本命令新增的节点；不读取目标旧节点的端口或项目业务字段。
## [br]
## @api private
var _insert_nodes: Array[GFFlowNode] = []

## 新增节点通过准入时的原生连接依赖；每次执行/重做复核，撤销不要求端口保持原值。
## [br]
## @api private
var _insert_dependencies: Array = []


## 当前操作命中的零写入结构守卫；预检本身不发布页面结果。
## [br]
## @api private
var _guard_reason: StringName = &""

## 基类完成错误码和执行状态更新后保存的独立 Flow 结果；不改写属性事务报告。
## [br]
## @api private
var _last_flow_edit_result: Dictionary = {}


## 已写入实际原生历史的共享门禁；历史强持有状态，命令不得反向形成强引用环。
## [br]
## @api private
var _history_state_ref: WeakRef = null


# --- 公共方法 ---

## 注册原生命令前绑定同历史的共享门禁；兼容 Object 沿用基类协议，不猜测清除接口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param undo_manager: 实际 EditorUndoRedoManager 或既有兼容对象。
## [br]
## @param execute_immediately: 是否立即执行已注册动作。
## [br]
## @return: 基类注册结果；实际原生历史已暂停或拥有关系变更时拒绝注册。
func add_to_undo_manager(undo_manager: Object, execute_immediately: bool = true) -> Error:
	var previous_ref: WeakRef = _history_state_ref
	var previous: GFFlowEditorHistoryState = _get_history_state()
	if undo_manager is EditorUndoRedoManager:
		var manager: EditorUndoRedoManager = undo_manager
		if manager.is_committing_action():
			return ERR_BUSY
		var state: GFFlowEditorHistoryState = GFFlowEditorHistoryState.acquire(manager, get_graph_for_editor())
		if state == null or (is_sealed() and previous != null and previous != state):
			return ERR_UNAVAILABLE
		if state.is_blocked() or GFVariantData.get_option_bool(state.get_status(), "busy"):
			return ERR_BUSY
		_history_state_ref = weakref(state)
	elif is_sealed() and previous != null:
		return ERR_UNAVAILABLE
	var error: Error = super.add_to_undo_manager(undo_manager, execute_immediately)
	if error != OK:
		_history_state_ref = previous_ref
	return error


## 继承命令执行合同；在基类缓存真实错误后通知页面，包括重做的预检拒绝。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 基类的实际执行错误码；失败不会冒充原生历史回调成功。
func execute() -> Error:
	_guard_reason = &""
	var error: Error = super.execute()
	_record_flow_edit_result(&"execute", error)
	_notify_observer()
	return error


## 继承撤销合同；零写入拒绝仍通知页面，原生 Undo 不会因该错误停止历史游标。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 基类的实际撤销错误码，失败保留命令执行状态与外部资源值。
func revert() -> Error:
	_guard_reason = &""
	var error: Error = super.revert()
	_record_flow_edit_result(&"revert", error)
	_notify_observer()
	return error


## 只恢复基类未完整补偿的 attempt guard，不把结构冲突当作可写回的补偿任务。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return: 基类的真实恢复结果；没有补偿任务时沿用 ERR_UNAVAILABLE。
func recover() -> Error:
	_guard_reason = &""
	var error: Error = super.recover()
	_record_flow_edit_result(&"recover", error)
	_notify_observer()
	return error


## 初次提交及重做前复核图策略和本命令新增节点的连接依赖；其它编辑沿用属性事务预检。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return: 当前库存与候选匹配且属性事务可执行时为 true。
func can_execute() -> bool:
	if _history_is_blocked():
		_guard_reason = &"history_blocked"
		return false
	if not _insert_before.is_empty():
		_guard_reason = _insertion_guard_reason()
		if _guard_reason != &"":
			return false
	return super.can_execute()


# --- 可重写钩子 / 虚方法 ---

func _do_it() -> Error:
	if _history_is_blocked():
		_guard_reason = &"history_blocked"
		return ERR_BUSY
	if not _insert_before.is_empty():
		_guard_reason = _insertion_guard_reason()
		if _guard_reason != &"":
			return ERR_BUSY
	var error: Error = super._do_it()
	if error == OK and _graph != null:
		_graph.emit_changed()
	return error


func _undo_it() -> Error:
	if _history_is_blocked():
		_guard_reason = &"history_blocked"
		return ERR_BUSY
	if not _insert_after.is_empty() and not GFVariantData.get_option_bool(get_transaction_report(), "recovery_required") and not _inventory_matches(_insert_after):
		_guard_reason = &"source_mismatch"
		return ERR_BUSY
	var error: Error = super._undo_it()
	if error == OK and _graph != null:
		_graph.emit_changed()
	return error


func _get_undo_context() -> Object:
	return _graph


# --- 框架内部方法 ---

## 读取最近完整操作的真实错误及结构守卫；底层事务报告保持独立，不能据旧 committed 当作撤销成功。
## [br]
## @api framework_internal
## [br]
## @return: 结果容器副本；尚未操作时为 pending，补偿资格只由 transaction.recovery_required 提供。
## [br]
## @schema return: Dictionary，固定 ok: bool、operation: StringName（pending/execute/revert/recover）、error: int（Error）、guard_reason: StringName（空/source_mismatch/candidate_mismatch/history_blocked）、zero_write: bool（结构或历史守卫的零写拒绝）、transaction: Dictionary（同 GFEditorPropertyBatchCommand.get_transaction_report）。不授权清除或修改原生历史。
func get_flow_edit_result() -> Dictionary:
	if _last_flow_edit_result.is_empty():
		return {
			"ok": true, "operation": &"pending", "error": OK,
			"guard_reason": &"", "zero_write": false, "transaction": get_transaction_report(),
		}
	return _last_flow_edit_result.duplicate(true)


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


## 返回本次插入的稳定标识，用于提交后选择新节点；不返回控件或可变资源集合。
## [br]
## @api framework_internal
## [br]
## @return: 插入标识副本；其它命令为空。
func get_inserted_node_ids() -> PackedStringArray:
	return _inserted_ids.duplicate()


## 为完整选择包构建零写入插入命令；所有新资源由命令持有，Undo/Redo保持同一身份。
## [br]
## @api framework_internal
## [br]
## @param graph: 目标图，作为原生资源历史上下文。
## [br]
## @param selection_package: GFFlowGraphEditorModel 的选择包。
## [br]
## @param offset: 新节点的有限位置偏移。
## [br]
## @param action_name: 原生历史中的操作名称。
## [br]
## @return: 完整插入命令；无效包、端口或预算失败返回 null，图不变。
## [br]
## @schema selection_package: Dictionary，包含 nodes: Array、connections: Array 和可选 start_node_id: StringName。
static func create_selection_paste(graph: GFFlowGraph, selection_package: Dictionary, offset: Vector2 = Vector2(30, 30), action_name: String = "粘贴 Flow 节点") -> GFFlowGraphEditCommand:
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var plan: Dictionary = model.build_selection_paste_plan(graph, selection_package, offset)
	if not GFVariantData.get_option_bool(plan, "ok"):
		return null
	var added_ids_value: Variant = plan["added_node_ids"]
	if not (added_ids_value is PackedStringArray):
		return null
	var added_ids: PackedStringArray = added_ids_value
	var inserted: Array[GFFlowNode] = []
	for value: Variant in GFVariantData.get_option_array(plan, "nodes"):
		if value is GFFlowNode:
			var node: GFFlowNode = value
			if added_ids.has(String(node.node_id)):
				inserted.append(node)
	var dependencies: Array = _capture_insert_dependencies(inserted)
	var command: GFFlowGraphEditCommand = _create(graph, [
		{"target": graph, "property_name": &"nodes", "new_value": plan["nodes"]},
		{"target": graph, "property_name": &"connections", "new_value": plan["connections"]},
		{"target": graph, "property_name": &"start_node_id", "new_value": plan["start_node_id"]},
	], action_name)
	command._insert_before = GFVariantData.get_option_dictionary(plan, "before_state")
	command._inserted_ids = added_ids
	command._insert_nodes = inserted
	command._insert_dependencies = dependencies
	var planned: GFFlowGraph = GFFlowGraph.new()
	planned.validate_port_compatibility = GFVariantData.get_option_bool(command._insert_before, "validate_port_compatibility")
	var nodes_value: Variant = plan["nodes"]
	if nodes_value is Array:
		for value: Variant in nodes_value:
			if value is GFFlowNode:
				var node: GFFlowNode = value
				planned.nodes.append(node)
			elif value == null:
				planned.nodes.append(null)
	var connections_value: Variant = plan["connections"]
	if connections_value is Array:
		for value: Variant in connections_value:
			if value is Dictionary:
				var connection: Dictionary = value
				planned.connections.append(connection)
	var start_value: Variant = plan["start_node_id"]
	if start_value is StringName:
		planned.start_node_id = start_value
	command._insert_after = GFFlowGraphEditorModel.capture_edit_state(planned)
	return command


## 从已保存的节点资源生成独立插入候选；起点由明确选项决定，已有图起点不改变。
## 不调用项目工厂、节点执行或描述方法，原生资源复制仍遵守项目存储属性的语义。
## [br]
## @api framework_internal
## [br]
## @param graph: 目标图。
## [br]
## @param template: 已保存到 res:// 的 GFFlowNode 资源，保留子类和端口类型。
## [br]
## @param position: 新节点的有限画布位置。
## [br]
## @param set_as_start: 空图时允许新节点成为起点。
## [br]
## @return: 零写入命令；未保存、位置或端口无效时为 null。
static func create_template_insertion(graph: GFFlowGraph, template: GFFlowNode, position: Vector2, set_as_start: bool = false) -> GFFlowGraphEditCommand:
	if template == null or not position.is_finite():
		return null
	var path: String = template.resource_path
	if not path.begins_with("res://") or path.contains("::") or path != path.simplify_path():
		return null
	if path.get_extension().to_lower() not in ["tres", "res"] or not FileAccess.file_exists(path):
		return null
	var duplicated_resource: Resource = template.duplicate(true)
	if not (duplicated_resource is GFFlowNode):
		return null
	var copied: GFFlowNode = duplicated_resource
	if copied.node_id == &"":
		copied.node_id = StringName(template.resource_path.get_file().get_basename())
	copied.editor_position = position
	copied.next_node_ids = PackedStringArray()
	return create_selection_paste(graph, {
		"nodes": [copied], "connections": [], "start_node_id": copied.node_id if set_as_start else &"",
	}, Vector2.ZERO, "添加 Flow 节点模板")


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

## 保存当前操作的真实结果；只包装基类报告，不制造已执行的写入或待补偿状态。
## [br]
## @api private
func _record_flow_edit_result(operation: StringName, error: Error) -> void:
	var reason: StringName = _guard_reason if error != OK else &""
	_last_flow_edit_result = {
		"ok": error == OK, "operation": operation, "error": error,
		"guard_reason": reason, "zero_write": reason != &"",
		"transaction": get_transaction_report(),
	}
	var history_state: GFFlowEditorHistoryState = _get_history_state()
	if history_state != null:
		history_state.record_command_result(self, _last_flow_edit_result)


## 读取仍由实际历史拥有的弱共享状态；未注册的直接命令不引入原生历史策略。
## [br]
## @api private
func _get_history_state() -> GFFlowEditorHistoryState:
	var value: Variant = _history_state_ref.get_ref() if _history_state_ref != null else null
	if value is GFFlowEditorHistoryState:
		return value
	return null


## 已绑定原生历史的执行/撤销遵守共享门禁，恢复仍由基类真实补偿任务授权。
## [br]
## @api private
func _history_is_blocked() -> bool:
	var state: GFFlowEditorHistoryState = _get_history_state()
	return state != null and state.is_blocked()


## 区分目标结构变化与本命令候选依赖变化；两者均拒绝本次写入，不回滚外部编辑。
## [br]
## @api private
func _insertion_guard_reason() -> StringName:
	if not _inventory_matches(_insert_before):
		return &"source_mismatch"
	if not _insert_candidate_matches():
		return &"candidate_mismatch"
	return &""


## 对比命令相关的结构与资源身份，禁止旧候选或旧历史覆盖后来插入的节点。
## [br]
## @api private
func _inventory_matches(expected: Dictionary) -> bool:
	return _graph != null and GFFlowGraphEditorModel.capture_edit_state(_graph) == expected


## 只复核即将写入的新增资源，不扩大图旧节点的保存或撤销所有权。
## [br]
## @api private
func _insert_candidate_matches() -> bool:
	return not _insert_nodes.is_empty() and _capture_insert_dependencies(_insert_nodes) == _insert_dependencies


## 原生连接准入使用节点 ID、执行后继及端口目录；不调用项目描述、查找或兼容性重写。
## [br]
## @api private
static func _capture_insert_dependencies(nodes: Array[GFFlowNode]) -> Array:
	var dependencies: Array = []
	for node: GFFlowNode in nodes:
		if node == null:
			return []
		dependencies.append([
			node.node_id, node.next_node_ids.duplicate(),
			_capture_port_dependencies(node.input_ports), _capture_port_dependencies(node.output_ports),
		])
	return dependencies


## 保存编译器实际读取的端口 ID、方向、值类型、连接数量及类提示；显示信息与业务元数据不参与。
## [br]
## @api private
static func _capture_port_dependencies(ports: Array[GFFlowPort]) -> Array:
	var dependencies: Array = []
	for port: GFFlowPort in ports:
		if port == null:
			dependencies.append(null)
		else:
			dependencies.append([port.port_id, port.direction, port.value_type, port.allow_multiple, port.class_name_hint])
	return dependencies


## 处理func内部数据。
## [br]
## @api private
static func _find_node(graph: GFFlowGraph, node_id: StringName) -> GFFlowNode:
	for node: GFFlowNode in graph.nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


## 通过有效弱引用通知页面接收编辑结果。
## [br]
## @api private
func _notify_observer() -> void:
	if _observer == null:
		return
	var value: Variant = _observer.get_ref()
	if value is Object and is_instance_valid(value):
		var page: Object = value
		if page.has_method("accept_flow_edit_result"):
			var _result: Variant = page.call("accept_flow_edit_result", self)


## 处理func内部数据。
## [br]
## @api private
static func _create(graph: GFFlowGraph, changes: Array[Dictionary], action_name: String) -> GFFlowGraphEditCommand:
	var command: GFFlowGraphEditCommand = GFFlowGraphEditCommand.new()
	command._graph = graph
	var _configured: GFEditorPropertyBatchCommand = command.configure(changes, {"command_name": action_name})
	return command
