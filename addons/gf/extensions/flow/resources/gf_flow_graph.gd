## GFFlowGraph: 资源化通用流程图。
##
## 只维护节点集合与起始节点，不规定具体编辑器表现或业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFFlowGraph
extends Resource


# --- 常量 ---

const _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT: Script = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _GF_GRAPH_MATH_SCRIPT: Script = preload("res://addons/gf/standard/foundation/math/gf_graph_math.gd")


# --- 导出变量 ---

## 起始节点标识。
## [br]
## @api public
@export var start_node_id: StringName = &""

## 流程节点列表。
## [br]
## @api public
@export var nodes: Array[GFFlowNode] = []

## 节点连接列表。连接结构为 from_node_id/from_port_id/to_node_id/to_port_id/metadata。
## [br]
## @api public
## [br]
## @schema connections: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。
@export var connections: Array[Dictionary] = []

## 校验时是否把端口值类型和类名提示不兼容视为错误。
## [br]
## @api public
@export var validate_port_compatibility: bool = true

## 校验时是否提示从 start_node_id 无法到达的节点。
## [br]
## @api public
@export var warn_unreachable_nodes: bool = true

## 校验时是否提示图中的循环。
## [br]
## @api public
@export var warn_cycles: bool = true

## 校验时是否提示没有后继的终端节点。默认关闭，避免把正常结束节点视为问题。
## [br]
## @api public
@export var warn_terminal_nodes: bool = false

## 编辑器分组数据。结构由编辑器工具解释，运行时不读取。
## [br]
## @api public
## [br]
## @schema editor_groups: 编辑器分组字典数组；字段由 FlowGraph 编辑器或项目工具解释。
@export var editor_groups: Array[Dictionary] = []

## 编辑器或项目工具的附加元数据。
## [br]
## @api public
## [br]
## @schema editor_metadata: 编辑器或项目工具自定义元数据 Dictionary；运行时不解释其中键值。
@export var editor_metadata: Dictionary = {}

## 编辑器或项目工具元数据的轻量 Schema。框架只校验结构，不解释业务含义。
## [br]
## @api public
## [br]
## @schema metadata_schema: 轻量元数据校验规则 Dictionary；键为元数据 key，值为包含 required、allow_null、type、class_name、allowed_values 等字段的规则字典。
@export var metadata_schema: Dictionary = {}


# --- 公共方法 ---

## 设置或替换一个节点。
## [br]
## @api public
## [br]
## @param node: 流程节点。
func set_node(node: GFFlowNode) -> void:
	if node == null or node.node_id == &"":
		return

	for index: int in range(nodes.size()):
		if nodes[index] != null and nodes[index].node_id == node.node_id:
			nodes[index] = node
			return
	nodes.append(node)


## 获取节点。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @return: 流程节点；不存在时返回 null。
func get_node(node_id: StringName) -> GFFlowNode:
	for node: GFFlowNode in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


## 检查节点是否存在。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @return: 存在返回 true。
func has_node(node_id: StringName) -> bool:
	return get_node(node_id) != null


## 移除节点。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
func remove_node(node_id: StringName) -> void:
	for index: int in range(nodes.size() - 1, -1, -1):
		if nodes[index] != null and nodes[index].node_id == node_id:
			nodes.remove_at(index)
	remove_connections_for_node(node_id)
	_remove_node_id_from_next_node_ids(node_id)


## 添加节点连接。
## [br]
## @api public
## [br]
## @param from_node_id: 来源节点。
## [br]
## @param from_port_id: 来源端口；为空时表示节点级执行连接。
## [br]
## @param to_node_id: 目标节点。
## [br]
## @param to_port_id: 目标端口；为空时表示节点级执行连接。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @return: 添加成功返回 true。
## [br]
## @schema metadata: 连接自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
func add_connection(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName,
	metadata: Dictionary = {}
) -> bool:
	if from_node_id == &"" or to_node_id == &"":
		return false
	if has_connection(from_node_id, from_port_id, to_node_id, to_port_id):
		return false
	if not _can_append_connection(from_node_id, from_port_id, to_node_id, to_port_id):
		return false

	connections.append(_make_connection(from_node_id, from_port_id, to_node_id, to_port_id, metadata))
	return true


## 移除指定节点连接。
## [br]
## @api public
## [br]
## @param from_node_id: 连接起点节点标识。
## [br]
## @param from_port_id: 连接起点端口标识。
## [br]
## @param to_node_id: 目标标识。
## [br]
## @param to_port_id: 目标标识。
## [br]
## @return: 移除成功返回 true。
func remove_connection(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> bool:
	for index: int in range(connections.size() - 1, -1, -1):
		if _connection_matches(connections[index], from_node_id, from_port_id, to_node_id, to_port_id):
			connections.remove_at(index)
			return true
	return false


## 移除与指定节点相关的所有连接。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
func remove_connections_for_node(node_id: StringName) -> void:
	for index: int in range(connections.size() - 1, -1, -1):
		var connection: Dictionary = connections[index]
		if _get_connection_from_node_id(connection) == node_id or _get_connection_to_node_id(connection) == node_id:
			connections.remove_at(index)


## 检查连接是否存在。
## [br]
## @api public
## [br]
## @param from_node_id: 连接起点节点标识。
## [br]
## @param from_port_id: 连接起点端口标识。
## [br]
## @param to_node_id: 目标标识。
## [br]
## @param to_port_id: 目标标识。
## [br]
## @return: 存在返回 true。
func has_connection(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> bool:
	for connection: Dictionary in connections:
		if _connection_matches(connection, from_node_id, from_port_id, to_node_id, to_port_id):
			return true
	return false


## 获取从指定节点或端口发出的连接。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @param port_id: 端口标识；为空时返回该节点所有输出连接。
## [br]
## @return: 连接副本列表。
## [br]
## @schema return: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。
func get_connections_from(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection: Dictionary in connections:
		if _get_connection_from_node_id(connection) != node_id:
			continue
		if port_id != &"" and _get_connection_from_port_id(connection) != port_id:
			continue
		result.append(connection.duplicate(true))
	return result


## 获取指向指定节点或端口的连接。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @param port_id: 端口标识；为空时返回该节点所有输入连接。
## [br]
## @return: 连接副本列表。
## [br]
## @schema return: 连接字典数组；每项包含 from_node_id、from_port_id、to_node_id、to_port_id 和 metadata 字段。
func get_connections_to(node_id: StringName, port_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection: Dictionary in connections:
		if _get_connection_to_node_id(connection) != node_id:
			continue
		if port_id != &"" and _get_connection_to_port_id(connection) != port_id:
			continue
		result.append(connection.duplicate(true))
	return result


## 获取指定节点或端口连接到的目标节点。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @param port_id: 端口标识；为空时返回该节点所有输出目标。
## [br]
## @return: 目标节点标识列表。
func get_connected_node_ids_from(node_id: StringName, port_id: StringName = &"") -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for connection: Dictionary in get_connections_from(node_id, port_id):
		var target_id: String = String(_get_connection_to_node_id(connection))
		if target_id.is_empty() or result.has(target_id):
			continue
		_append_packed_string(result, target_id)
	return result


## 检查指定连接端口的兼容性。
## [br]
## @api public
## [br]
## @param from_node_id: 来源节点。
## [br]
## @param from_port_id: 来源端口。
## [br]
## @param to_node_id: 目标节点。
## [br]
## @param to_port_id: 目标端口。
## [br]
## @return: 兼容性报告。
## [br]
## @schema return: 包含 ok、reason、message、from_node_id、from_port_id、to_node_id 和 to_port_id 等字段的 Dictionary。
func check_connection_compatibility(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> Dictionary:
	var from_node: GFFlowNode = _find_node_by_id(from_node_id)
	var to_node: GFFlowNode = _find_node_by_id(to_node_id)
	if from_node == null:
		return _make_connection_compatibility_report(false, "missing_from_node", "Connection source node does not exist.")
	if to_node == null:
		return _make_connection_compatibility_report(false, "missing_to_node", "Connection target node does not exist.")
	if _has_mixed_connection_ports(from_port_id, to_port_id):
		return _make_connection_compatibility_report(false, "invalid_mixed_connection_ports", "Connection must use either two node-level endpoints or two explicit ports.")
	if from_port_id == &"" or to_port_id == &"":
		return _make_connection_compatibility_report(true, "", "")

	var output_port: GFFlowPort = _find_output_port(from_node, from_port_id)
	var input_port: GFFlowPort = _find_input_port(to_node, to_port_id)
	if output_port == null:
		return _make_connection_compatibility_report(false, "missing_output_port", "Connection output port does not exist.")
	if input_port == null:
		return _make_connection_compatibility_report(false, "missing_input_port", "Connection input port does not exist.")

	var report: Dictionary = _get_port_compatibility_report(output_port, input_port)
	report["from_node_id"] = from_node_id
	report["from_port_id"] = from_port_id
	report["to_node_id"] = to_node_id
	report["to_port_id"] = to_port_id
	return report


## 获取所有连接的兼容性报告。
## [br]
## @api public
## [br]
## @return: 兼容性报告列表。
## [br]
## @schema return: 兼容性报告字典数组；每项结构同 check_connection_compatibility() 返回值。
func get_connection_compatibility_report() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection: Dictionary in connections:
		result.append(check_connection_compatibility(
			_get_connection_from_node_id(connection),
			_get_connection_from_port_id(connection),
			_get_connection_to_node_id(connection),
			_get_connection_to_port_id(connection)
		))
	return result


## 设置节点编辑器位置。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @param position: 编辑器坐标。
## [br]
## @return: 设置成功返回 true。
func set_node_editor_position(node_id: StringName, position: Vector2) -> bool:
	var node: GFFlowNode = get_node(node_id)
	if node == null:
		return false
	node.editor_position = position
	return true


## 设置节点编辑器布局。
## [br]
## @api public
## [br]
## @param node_id: 节点标识。
## [br]
## @param position: 编辑器坐标。
## [br]
## @param size: 编辑器尺寸；Vector2.ZERO 表示由编辑器自行决定。
## [br]
## @param collapsed: 是否折叠显示。
## [br]
## @return: 设置成功返回 true。
func set_node_editor_layout(
	node_id: StringName,
	position: Vector2,
	size: Vector2 = Vector2.ZERO,
	collapsed: bool = false
) -> bool:
	var node: GFFlowNode = get_node(node_id)
	if node == null:
		return false
	node.editor_position = position
	node.editor_size = size
	node.editor_collapsed = collapsed
	return true


## 获取编辑器或可视化工具可消费的节点目录。
## [br]
## @api public
## [br]
## @return: 节点目录字典。
## [br]
## @schema return: 包含 node_count、nodes 和 categories 字段的 Dictionary；nodes 为节点目录条目数组，categories 按分类名分组。
func get_editor_catalog() -> Dictionary:
	var node_entries: Array[Dictionary] = []
	var categories: Dictionary = {}
	for node: GFFlowNode in nodes:
		if node == null:
			continue

		var category: String = String(node.category)
		if category.is_empty():
			category = "Flow"
		var entry: Dictionary = {
			"node_id": node.node_id,
			"display_name": _get_node_display_name(node),
			"category": category,
			"ports": _describe_node_ports(node),
			"editor": _describe_node_editor(node),
			"metadata": node.metadata.duplicate(true),
		}
		node_entries.append(entry)
		_append_dictionary_array_field(categories, category, entry)

	node_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_category: String = GFVariantData.get_option_string(left, "category", "")
		var right_category: String = GFVariantData.get_option_string(right, "category", "")
		if left_category != right_category:
			return left_category < right_category
		return GFVariantData.get_option_string(left, "display_name", "") < GFVariantData.get_option_string(right, "display_name", "")
	)
	return {
		"node_count": node_entries.size(),
		"nodes": node_entries,
		"categories": categories,
	}


## 描述流程图结构。
## [br]
## @api public
## [br]
## @return: 图描述字典。
## [br]
## @schema return: 包含 start_node_id、node_count、nodes、connection_count、connections、validate_port_compatibility、diagnostics 和 editor 字段的 Dictionary。
func describe_graph() -> Dictionary:
	var node_descriptions: Array[Dictionary] = []
	for node: GFFlowNode in nodes:
		if node != null:
			node_descriptions.append(_describe_node(node))
	return {
		"start_node_id": start_node_id,
		"node_count": node_descriptions.size(),
		"nodes": node_descriptions,
		"connection_count": connections.size(),
		"connections": _describe_connections(),
		"validate_port_compatibility": validate_port_compatibility,
		"diagnostics": {
			"warn_unreachable_nodes": warn_unreachable_nodes,
			"warn_cycles": warn_cycles,
			"warn_terminal_nodes": warn_terminal_nodes,
		},
		"editor": {
			"groups": editor_groups.duplicate(true),
			"metadata": editor_metadata.duplicate(true),
			"metadata_schema": metadata_schema.duplicate(true),
		},
	}


## 创建可运行的流程图副本。
## [br]
## @api public
## [br]
## @param options: 可选参数，支持 clear_runtime_state。
## [br]
## @return: 流程图副本；复制失败时返回 null。
## [br]
## @schema options: 可选项 Dictionary；支持 clear_runtime_state: bool。
func instantiate_graph(options: Dictionary = {}) -> GFFlowGraph:
	var graph: GFFlowGraph = _get_flow_graph_value(duplicate(true))
	if graph != null and GFVariantData.get_option_bool(options, "clear_runtime_state", true):
		graph.clear_runtime_state()
	return graph


## 序列化图内节点运行态。
## [br]
## @api public
## [br]
## @return: 运行态快照。
## [br]
## @schema return: 包含 nodes 字段的 Dictionary；nodes 按 node_id 保存节点运行态 Dictionary。
func serialize_runtime_state() -> Dictionary:
	var node_states: Dictionary = {}
	for node: GFFlowNode in nodes:
		if node == null or node.node_id == &"":
			continue
		var state: Dictionary = node.serialize_runtime_state()
		if not state.is_empty():
			node_states[node.node_id] = state
	return {
		"nodes": node_states,
	}


## 反序列化图内节点运行态。
## [br]
## @api public
## [br]
## @param data: 运行态快照。
## [br]
## @schema data: serialize_runtime_state() 返回的运行态快照 Dictionary。
func deserialize_runtime_state(data: Dictionary) -> void:
	var node_states_value: Variant = GFVariantData.get_option_value(data, "nodes", {})
	if not (node_states_value is Dictionary):
		return

	var node_states: Dictionary = node_states_value
	for node_id_variant: Variant in node_states.keys():
		var node: GFFlowNode = get_node(_get_string_name_value(node_id_variant))
		var state_value: Variant = node_states[node_id_variant]
		if not (state_value is Dictionary):
			continue
		var state: Dictionary = state_value
		if node != null:
			node.deserialize_runtime_state(state)


## 清空图内所有节点运行态。
## [br]
## @api public
func clear_runtime_state() -> void:
	for node: GFFlowNode in nodes:
		if node != null:
			node.clear_runtime_state()


## 校验元数据是否符合轻量 Schema。
## [br]
## @api public
## [br]
## @param target_metadata: 待校验元数据。
## [br]
## @param schema: 可选 Schema；为空时使用 metadata_schema。
## [br]
## @return: 校验报告。
## [br]
## @schema target_metadata: 待校验的元数据 Dictionary。
## [br]
## @schema schema: 可选轻量 Schema Dictionary；为空时使用 metadata_schema。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count 和 warning_count 等字段。
func validate_metadata(target_metadata: Dictionary, schema: Dictionary = {}) -> Dictionary:
	var active_schema: Dictionary = schema if not schema.is_empty() else metadata_schema
	var report: Dictionary = {
		"ok": true,
		"healthy": true,
		"error_count": 0,
		"warning_count": 0,
		"issue_counts_by_kind": {},
		"summary": "",
		"next_action": "",
		"issues": [],
	}
	_validate_metadata_against_schema(report, target_metadata, active_schema, "metadata")
	return _finalize_validation_report(report, "Flow metadata", {
		"next_actions": _get_metadata_validation_next_actions(),
		"fallback_action": "Review the reported metadata issue before saving or running this graph.",
	})


## 校验当前图编辑器元数据。
## [br]
## @api public
## [br]
## @return: 校验报告。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count 和 warning_count 等字段。
func validate_graph_metadata() -> Dictionary:
	return validate_metadata(editor_metadata, metadata_schema)


## 校验流程图结构。
## [br]
## @api public
## [br]
## @return: 校验报告。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、node_count、connection_count、summary、issues 和 next_action 等字段。
func validate_graph() -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"healthy": true,
		"node_count": nodes.size(),
		"connection_count": connections.size(),
		"error_count": 0,
		"warning_count": 0,
		"issue_counts_by_kind": {},
		"summary": "",
		"next_action": "",
		"issues": [],
	}
	var node_ids: Dictionary = {}
	for index: int in range(nodes.size()):
		var node: GFFlowNode = nodes[index]
		if node == null:
			_append_validation_issue(report, "warning", "null_node", "", "Node at index %d is null." % index)
			continue

		var node_id: StringName = node.node_id
		if node_id == &"":
			_append_validation_issue(report, "error", "empty_node_id", "", "Flow node id is empty.")
			continue
		if node_ids.has(node_id):
			_append_validation_issue(report, "error", "duplicate_node_id", String(node_id), "Duplicate flow node id.")
		node_ids[node_id] = true
		_validate_node_ports(node, report)

	if start_node_id != &"" and not node_ids.has(start_node_id):
		_append_validation_issue(report, "error", "missing_start_node", String(start_node_id), "Start node does not exist.")

	for node: GFFlowNode in nodes:
		if node == null:
			continue
		for next_id: String in node.next_node_ids:
			if StringName(next_id) == &"":
				continue
			if not node_ids.has(StringName(next_id)):
				_append_validation_issue(report, "error", "missing_next_node", String(node.node_id), "Next node does not exist: %s" % next_id)

	_validate_connections(report, node_ids)
	_validate_topology_diagnostics(report, node_ids)
	if not metadata_schema.is_empty():
		_validate_metadata_against_schema(report, editor_metadata, metadata_schema, "editor_metadata")
	return _finalize_validation_report(report, "Flow graph", {
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first reported flow graph issue before using this graph.",
	})


## 构建面向编辑器和可视化工具的流程图报告。
## [br]
## @api public
## [br]
## @return: 包含校验、目录和编辑器元数据的报告。
## [br]
## @schema return: 包含 ok、healthy、summary、next_action、validation、catalog 和 editor 字段的 Dictionary。
func build_editor_report() -> Dictionary:
	var validation: Dictionary = validate_graph()
	return {
		"ok": GFVariantData.get_option_bool(validation, "ok", false),
		"healthy": GFVariantData.get_option_bool(validation, "healthy", false),
		"summary": GFVariantData.get_option_string(validation, "summary", ""),
		"next_action": GFVariantData.get_option_string(validation, "next_action", ""),
		"validation": validation,
		"catalog": get_editor_catalog(),
		"editor": {
			"groups": editor_groups.duplicate(true),
			"metadata": editor_metadata.duplicate(true),
			"metadata_schema": metadata_schema.duplicate(true),
			"metadata_validation": validate_graph_metadata(),
		},
	}


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


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		return value
	return null


func _get_flow_graph_value(value: Variant) -> GFFlowGraph:
	if value is GFFlowGraph:
		return value
	return null


func _get_flow_port_value(value: Variant) -> GFFlowPort:
	if value is GFFlowPort:
		return value
	return null


func _append_dictionary_array_field(target: Dictionary, field_name: Variant, value: Variant) -> void:
	var values: Array = GFVariantData.as_array(GFVariantData.get_option_value(target, field_name, []))
	values.append(value)
	target[field_name] = values


func _get_connection_from_node_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "from_node_id", &"")


func _get_connection_from_port_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "from_port_id", &"")


func _get_connection_to_node_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "to_node_id", &"")


func _get_connection_to_port_id(connection: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(connection, "to_port_id", &"")


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _finalize_validation_report(report: Dictionary, subject: String, options: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.call("finalize_report", report, subject, options))


func _find_reachable_nodes(root_node_id: StringName, node_ids: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_GRAPH_MATH_SCRIPT.call(
		"find_reachable",
		root_node_id,
		INF,
		func(node_id: Variant) -> Array:
			return _get_successor_node_ids(_get_string_name_value(node_id), node_ids)
	))


func _find_node_by_id(node_id: StringName) -> GFFlowNode:
	for node: GFFlowNode in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func _get_node_display_name(node: GFFlowNode) -> String:
	if node == null:
		return "Flow Node"
	if not node.display_name.is_empty():
		return node.display_name
	if node.node_id != &"":
		return String(node.node_id)
	return "Flow Node"


func _describe_node(node: GFFlowNode) -> Dictionary:
	return {
		"node_id": node.node_id,
		"display_name": _get_node_display_name(node),
		"category": node.category,
		"next_node_ids": node.next_node_ids.duplicate(),
		"wait_for_result": node.wait_for_result,
		"ports": _describe_node_ports(node),
		"editor": _describe_node_editor(node),
		"metadata": node.metadata.duplicate(true),
	}


func _describe_node_ports(node: GFFlowNode) -> Dictionary:
	return {
		"inputs": _describe_ports(node.input_ports),
		"outputs": _describe_ports(node.output_ports),
	}


func _describe_node_editor(node: GFFlowNode) -> Dictionary:
	return {
		"display_name": _get_node_display_name(node),
		"category": node.category,
		"position": node.editor_position,
		"size": node.editor_size,
		"collapsed": node.editor_collapsed,
	}


func _describe_ports(ports: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for port_variant: Variant in ports:
		var port: GFFlowPort = _get_flow_port_value(port_variant)
		if port != null:
			result.append(_describe_port(port))
	return result


func _describe_port(port: GFFlowPort) -> Dictionary:
	var port_id: StringName = _get_port_id(port)
	return {
		"port_id": port_id,
		"display_name": _get_port_display_name(port, port_id),
		"direction": port.direction,
		"value_type": port.value_type,
		"allow_multiple": port.allow_multiple,
		"editor_color": port.editor_color,
		"type_hint": port.type_hint,
		"class_name_hint": port.class_name_hint,
		"semantic_tags": port.semantic_tags.duplicate(),
		"metadata": port.metadata.duplicate(true),
	}


func _get_port_id(port: GFFlowPort) -> StringName:
	if port == null:
		return &""
	if port.port_id != &"":
		return port.port_id
	if not port.resource_path.is_empty():
		return StringName(port.resource_path)
	return &""


func _get_port_display_name(port: GFFlowPort, port_id: StringName) -> String:
	if port == null:
		return "Flow Port"
	if not port.display_name.is_empty():
		return port.display_name
	if port_id != &"":
		return String(port_id)
	if not port.resource_path.is_empty():
		return port.resource_path.get_file().get_basename().capitalize()
	return "Flow Port"


func _find_input_port(node: GFFlowNode, port_id: StringName) -> GFFlowPort:
	return _find_port(node.input_ports, port_id) if node != null else null


func _find_output_port(node: GFFlowNode, port_id: StringName) -> GFFlowPort:
	return _find_port(node.output_ports, port_id) if node != null else null


func _find_port(ports: Array, port_id: StringName) -> GFFlowPort:
	for port_variant: Variant in ports:
		var port: GFFlowPort = _get_flow_port_value(port_variant)
		if port != null and _get_port_id(port) == port_id:
			return port
	return null


func _get_port_compatibility_report(source_port: GFFlowPort, target_port: GFFlowPort) -> Dictionary:
	if target_port == null:
		return _make_port_compatibility_report(source_port, null, false, "missing_target_port", "Target port is null.")

	var output_port: GFFlowPort = source_port
	var input_port: GFFlowPort = target_port
	if source_port != null and source_port.direction == GFFlowPort.Direction.INPUT and target_port.direction == GFFlowPort.Direction.OUTPUT:
		output_port = target_port
		input_port = source_port

	if output_port == null or output_port.direction != GFFlowPort.Direction.OUTPUT or input_port.direction != GFFlowPort.Direction.INPUT:
		return _make_port_compatibility_report(output_port, input_port, false, "invalid_direction", "Connections require an output port and an input port.")
	if not _value_types_are_compatible(output_port.value_type, input_port.value_type):
		return _make_port_compatibility_report(output_port, input_port, false, "value_type_mismatch", "Port value types are not compatible.")
	if not _class_hints_are_compatible(output_port, input_port):
		return _make_port_compatibility_report(output_port, input_port, false, "class_hint_mismatch", "Port class hints are not compatible.")

	return _make_port_compatibility_report(output_port, input_port, true, "", "")


func _value_types_are_compatible(source_type: GFFlowPort.ValueType, target_type: GFFlowPort.ValueType) -> bool:
	if source_type == GFFlowPort.ValueType.ANY or target_type == GFFlowPort.ValueType.ANY:
		return true
	return source_type == target_type


func _class_hints_are_compatible(source_port: GFFlowPort, target_port: GFFlowPort) -> bool:
	if source_port.value_type != GFFlowPort.ValueType.OBJECT or target_port.value_type != GFFlowPort.ValueType.OBJECT:
		return true
	if source_port.class_name_hint == &"" or target_port.class_name_hint == &"":
		return true
	return source_port.class_name_hint == target_port.class_name_hint


func _make_port_compatibility_report(
	source_port: GFFlowPort,
	target_port: GFFlowPort,
	ok: bool,
	reason: String,
	message: String
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"message": message,
		"source_port_id": _get_port_id(source_port) if source_port != null else &"",
		"source_value_type": source_port.value_type if source_port != null else GFFlowPort.ValueType.ANY,
		"target_port_id": _get_port_id(target_port) if target_port != null else &"",
		"target_value_type": target_port.value_type if target_port != null else GFFlowPort.ValueType.ANY,
	}

func _get_validation_next_actions() -> Dictionary:
	return {
		"null_node": "Remove the null entry or replace it with a valid GFFlowNode resource.",
		"empty_node_id": "Assign a stable node_id to every flow node.",
		"duplicate_node_id": "Rename one of the duplicated flow node ids.",
		"missing_start_node": "Set start_node_id to an existing node or leave it empty for manual runner selection.",
		"missing_next_node": "Create the referenced next node or remove it from next_node_ids.",
		"invalid_connection": "Fill both from_node_id and to_node_id for every flow connection.",
		"invalid_mixed_connection_ports": "Use either a node-level connection with both port ids empty, or a port-level connection with both port ids set.",
		"duplicate_connection": "Remove the duplicated flow connection.",
		"missing_connection_from_node": "Create the connection source node or remove the connection.",
		"missing_connection_to_node": "Create the connection target node or remove the connection.",
		"missing_connection_input_port": "Update the connection port id or add the missing port to the node.",
		"missing_connection_output_port": "Update the connection port id or add the missing port to the node.",
		"input_port_allows_single_connection": "Enable allow_multiple on the port or keep only one connection.",
		"output_port_allows_single_connection": "Enable allow_multiple on the port or keep only one connection.",
		"incompatible_connection_ports": "Update the connected port value types or disable strict compatibility validation for this graph.",
		"unreachable_node": "Connect the node from start_node_id or remove it from this graph resource.",
		"cycle_detected": "Review the reported cycle and make sure the runner loop guard is intentional for this graph.",
		"terminal_node": "Connect a successor, disable warn_terminal_nodes, or keep the node intentionally terminal.",
		"metadata_missing_required": "Add the required metadata key or relax the metadata schema.",
		"metadata_null_not_allowed": "Provide a non-null metadata value or allow null in the schema.",
		"metadata_type_mismatch": "Update the metadata value type or the schema type hint.",
		"metadata_class_mismatch": "Update the metadata object class or the schema class_name hint.",
		"metadata_value_not_allowed": "Use one of the schema allowed_values or remove the restriction.",
		"metadata_invalid_rule": "Replace the metadata schema entry with a Dictionary rule.",
	}


func _get_metadata_validation_next_actions() -> Dictionary:
	return {
		"metadata_missing_required": "Add the required metadata key or relax the metadata schema.",
		"metadata_null_not_allowed": "Provide a non-null metadata value or allow null in the schema.",
		"metadata_type_mismatch": "Update the metadata value type or the schema type hint.",
		"metadata_class_mismatch": "Update the metadata object class or the schema class_name hint.",
		"metadata_value_not_allowed": "Use one of the schema allowed_values or remove the restriction.",
		"metadata_invalid_rule": "Replace the metadata schema entry with a Dictionary rule.",
	}


func _validate_node_ports(node: GFFlowNode, report: Dictionary) -> void:
	_validate_ports(node.node_id, "input", node.input_ports, report)
	_validate_ports(node.node_id, "output", node.output_ports, report)


func _validate_ports(node_id: StringName, label: String, ports: Array, report: Dictionary) -> void:
	var port_ids: Dictionary = {}
	for port_variant: Variant in ports:
		var port: GFFlowPort = _get_flow_port_value(port_variant)
		if port == null:
			_append_validation_issue(report, "warning", "null_%s_port" % label, String(node_id), "Flow node contains a null %s port." % label)
			continue

		var port_id: StringName = _get_port_id(port)
		if port_id == &"":
			_append_validation_issue(report, "error", "empty_%s_port_id" % label, String(node_id), "Flow node contains an empty %s port id." % label)
			continue
		if port_ids.has(port_id):
			_append_validation_issue(report, "error", "duplicate_%s_port_id" % label, String(node_id), "Duplicate %s port id: %s" % [label, String(port_id)])
		port_ids[port_id] = true


func _validate_connections(report: Dictionary, node_ids: Dictionary) -> void:
	var connection_keys: Dictionary = {}
	var input_counts: Dictionary = {}
	var output_counts: Dictionary = {}
	for index: int in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_node_id: StringName = _get_connection_from_node_id(connection)
		var from_port_id: StringName = _get_connection_from_port_id(connection)
		var to_node_id: StringName = _get_connection_to_node_id(connection)
		var to_port_id: StringName = _get_connection_to_port_id(connection)
		var connection_key: String = _get_connection_key(from_node_id, from_port_id, to_node_id, to_port_id)

		if from_node_id == &"" or to_node_id == &"":
			_append_validation_issue(report, "error", "invalid_connection", str(index), "Flow connection requires from_node_id and to_node_id.")
			continue
		if _has_mixed_connection_ports(from_port_id, to_port_id):
			_append_validation_issue(report, "error", "invalid_mixed_connection_ports", String(from_node_id), "Flow connection must use either two node-level endpoints or two explicit ports.")
			continue
		if connection_keys.has(connection_key):
			_append_validation_issue(report, "error", "duplicate_connection", String(from_node_id), "Duplicate flow connection.")
		connection_keys[connection_key] = true

		var from_node: GFFlowNode = _find_node_by_id(from_node_id)
		var to_node: GFFlowNode = _find_node_by_id(to_node_id)
		if from_node == null or not node_ids.has(from_node_id):
			_append_validation_issue(report, "error", "missing_connection_from_node", String(from_node_id), "Connection source node does not exist.")
		if to_node == null or not node_ids.has(to_node_id):
			_append_validation_issue(report, "error", "missing_connection_to_node", String(to_node_id), "Connection target node does not exist.")

		var output_port: GFFlowPort = _validate_connection_port(from_node, from_port_id, false, report)
		var input_port: GFFlowPort = _validate_connection_port(to_node, to_port_id, true, report)
		_count_connection_port(output_counts, from_node_id, from_port_id, output_port, false, report)
		_count_connection_port(input_counts, to_node_id, to_port_id, input_port, true, report)
		if validate_port_compatibility and output_port != null and input_port != null:
			var compatibility: Dictionary = _get_port_compatibility_report(output_port, input_port)
			if not GFVariantData.get_option_bool(compatibility, "ok", false):
				_append_validation_issue(report, "error", "incompatible_connection_ports", String(from_node_id), GFVariantData.get_option_string(compatibility, "message", ""))


func _validate_topology_diagnostics(report: Dictionary, node_ids: Dictionary) -> void:
	if node_ids.is_empty():
		return
	if warn_unreachable_nodes:
		_validate_unreachable_nodes(report, node_ids)
	if warn_cycles:
		_validate_cycles(report, node_ids)
	if warn_terminal_nodes:
		_validate_terminal_nodes(report, node_ids)


func _validate_unreachable_nodes(report: Dictionary, node_ids: Dictionary) -> void:
	if start_node_id == &"" or not node_ids.has(start_node_id):
		return

	var reachable: Dictionary = _find_reachable_nodes(start_node_id, node_ids)
	for node_id: StringName in _get_sorted_node_ids(node_ids):
		if not reachable.has(node_id):
			_append_validation_issue(report, "warning", "unreachable_node", String(node_id), "Node is not reachable from start_node_id: %s" % String(node_id))


func _validate_cycles(report: Dictionary, node_ids: Dictionary) -> void:
	var states: Dictionary = {}
	var reported_cycles: Dictionary = {}
	for node_id: StringName in _get_sorted_node_ids(node_ids):
		if GFVariantData.get_option_int(states, node_id, 0) == 0:
			_visit_node_for_cycles_iterative(node_id, node_ids, states, reported_cycles, report)


func _visit_node_for_cycles_iterative(
	p_start_node_id: StringName,
	node_ids: Dictionary,
	states: Dictionary,
	reported_cycles: Dictionary,
	report: Dictionary
) -> void:
	var node_stack: Array[StringName] = [p_start_node_id]
	var successor_stack: Array = [_get_successor_node_ids(p_start_node_id, node_ids)]
	var index_stack: Array[int] = [0]
	states[p_start_node_id] = 1

	while not node_stack.is_empty():
		var stack_index: int = node_stack.size() - 1
		var current_node_id: StringName = node_stack[stack_index]
		var successors: Array = GFVariantData.as_array(successor_stack[stack_index])
		var successor_index: int = index_stack[stack_index]
		if successor_index >= successors.size():
			states[current_node_id] = 2
			node_stack.pop_back()
			successor_stack.pop_back()
			index_stack.pop_back()
			continue

		var successor_id: StringName = GFVariantData.to_string_name(successors[successor_index])
		index_stack[stack_index] = successor_index + 1
		var successor_state: int = GFVariantData.get_option_int(states, successor_id, 0)
		if successor_state == 1:
			var cycle_key: String = _make_cycle_key(successor_id, node_stack)
			if not reported_cycles.has(cycle_key):
				reported_cycles[cycle_key] = true
				_append_validation_issue(report, "warning", "cycle_detected", cycle_key, "Flow graph contains a cycle: %s" % cycle_key)
			continue
		if successor_state == 0:
			states[successor_id] = 1
			node_stack.append(successor_id)
			successor_stack.append(_get_successor_node_ids(successor_id, node_ids))
			index_stack.append(0)


func _validate_terminal_nodes(report: Dictionary, node_ids: Dictionary) -> void:
	for node_id: StringName in _get_sorted_node_ids(node_ids):
		if _get_successor_node_ids(node_id, node_ids).is_empty():
			_append_validation_issue(report, "warning", "terminal_node", String(node_id), "Node has no outgoing successor: %s" % String(node_id))


func _validate_metadata_against_schema(
	report: Dictionary,
	target_metadata: Dictionary,
	schema: Dictionary,
	label: String
) -> void:
	for key_variant: Variant in schema.keys():
		var key: StringName = _get_string_name_value(key_variant)
		var rule_value: Variant = schema[key_variant]
		if not (rule_value is Dictionary):
			_append_validation_issue(report, "warning", "metadata_invalid_rule", String(key), "%s schema rule must be a Dictionary: %s" % [label, String(key)])
			continue

		var rule: Dictionary = rule_value
		var has_key: bool = _metadata_has_key(target_metadata, key)
		var required: bool = GFVariantData.get_option_bool(rule, "required", false)
		if required and not has_key:
			_append_validation_issue(report, "error", "metadata_missing_required", String(key), "%s is missing required metadata: %s" % [label, String(key)])
			continue
		if not has_key:
			continue

		var value: Variant = _metadata_get_value(target_metadata, key)
		if value == null:
			if not GFVariantData.get_option_bool(rule, "allow_null", true):
				_append_validation_issue(report, "error", "metadata_null_not_allowed", String(key), "%s metadata does not allow null: %s" % [label, String(key)])
			continue

		if rule.has("type"):
			var expected_type: int = GFVariantData.get_option_int(rule, "type", TYPE_NIL)
			if expected_type != TYPE_NIL and typeof(value) != expected_type:
				_append_validation_issue(report, "error", "metadata_type_mismatch", String(key), "%s metadata type does not match schema: %s" % [label, String(key)])

		var expected_class: String = GFVariantData.get_option_string(rule, "class_name", "")
		var object_value: Object = _get_object_value(value)
		if not expected_class.is_empty() and not (object_value != null and object_value.is_class(expected_class)):
			_append_validation_issue(report, "error", "metadata_class_mismatch", String(key), "%s metadata class does not match schema: %s" % [label, String(key)])

		var allowed_values: Array = GFVariantData.get_option_array(rule, "allowed_values")
		if not allowed_values.is_empty() and not allowed_values.has(value):
			_append_validation_issue(report, "error", "metadata_value_not_allowed", String(key), "%s metadata value is not allowed: %s" % [label, String(key)])


func _metadata_has_key(target_metadata: Dictionary, key: StringName) -> bool:
	return target_metadata.has(key) or target_metadata.has(String(key))


func _metadata_get_value(target_metadata: Dictionary, key: StringName) -> Variant:
	if target_metadata.has(key):
		return target_metadata[key]
	return GFVariantData.get_option_value(target_metadata, String(key), null)


func _get_successor_node_ids(node_id: StringName, node_ids: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var node: GFFlowNode = _find_node_by_id(node_id)
	if node != null:
		for next_id_text: String in node.next_node_ids:
			_append_successor_id(result, StringName(next_id_text), node_ids)

	for connection: Dictionary in connections:
		if _get_connection_from_node_id(connection) != node_id:
			continue
		_append_successor_id(result, _get_connection_to_node_id(connection), node_ids)
	return result


func _append_successor_id(result: Array[StringName], node_id: StringName, node_ids: Dictionary) -> void:
	if node_id == &"" or not node_ids.has(node_id) or result.has(node_id):
		return
	result.append(node_id)


func _get_sorted_node_ids(node_ids: Dictionary) -> Array[StringName]:
	var values: PackedStringArray = PackedStringArray()
	for node_id_variant: Variant in node_ids.keys():
		_append_packed_string(values, GFVariantData.to_text(node_id_variant))
	values.sort()

	var result: Array[StringName] = []
	for node_id_text: String in values:
		result.append(StringName(node_id_text))
	return result


func _make_cycle_key(first_repeated_node_id: StringName, stack: Array[StringName]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var include: bool = false
	for node_id: StringName in stack:
		if node_id == first_repeated_node_id:
			include = true
		if include:
			_append_packed_string(parts, String(node_id))
	_append_packed_string(parts, String(first_repeated_node_id))
	return " -> ".join(parts)


func _validate_connection_port(
	node: GFFlowNode,
	port_id: StringName,
	is_input: bool,
	report: Dictionary
) -> GFFlowPort:
	if node == null or port_id == &"":
		return null

	var port: GFFlowPort = _find_input_port(node, port_id) if is_input else _find_output_port(node, port_id)
	if port == null:
		var kind: String = "missing_connection_input_port" if is_input else "missing_connection_output_port"
		var label: String = "input" if is_input else "output"
		_append_validation_issue(report, "error", kind, String(node.node_id), "Connection %s port does not exist: %s" % [label, String(port_id)])
	return port


func _count_connection_port(
	counts: Dictionary,
	node_id: StringName,
	port_id: StringName,
	port: GFFlowPort,
	is_input: bool,
	report: Dictionary
) -> void:
	if port_id == &"" or port == null:
		return

	var key: String = "%s:%s" % [String(node_id), String(port_id)]
	counts[key] = GFVariantData.get_option_int(counts, key, 0) + 1
	if GFVariantData.get_option_int(counts, key, 0) <= 1 or port.allow_multiple:
		return

	var kind: String = "input_port_allows_single_connection" if is_input else "output_port_allows_single_connection"
	_append_validation_issue(report, "error", kind, String(node_id), "Flow port allows only one connection: %s" % String(port_id))


func _can_append_connection(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> bool:
	var from_node: GFFlowNode = _find_node_by_id(from_node_id)
	var to_node: GFFlowNode = _find_node_by_id(to_node_id)
	if from_node == null or to_node == null:
		return false
	if _has_mixed_connection_ports(from_port_id, to_port_id):
		return false

	var output_port: GFFlowPort = _find_output_port(from_node, from_port_id) if from_port_id != &"" else null
	var input_port: GFFlowPort = _find_input_port(to_node, to_port_id) if to_port_id != &"" else null
	if from_port_id != &"" and output_port == null:
		return false
	if to_port_id != &"" and input_port == null:
		return false
	if input_port != null and not input_port.allow_multiple and not get_connections_to(to_node_id, to_port_id).is_empty():
		return false
	if output_port != null and not output_port.allow_multiple and not get_connections_from(from_node_id, from_port_id).is_empty():
		return false
	if validate_port_compatibility and output_port != null and input_port != null and not GFVariantData.get_option_bool(_get_port_compatibility_report(output_port, input_port), "ok", false):
		return false
	return true


func _make_connection(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName,
	metadata: Dictionary
) -> Dictionary:
	return {
		"from_node_id": from_node_id,
		"from_port_id": from_port_id,
		"to_node_id": to_node_id,
		"to_port_id": to_port_id,
		"metadata": metadata.duplicate(true),
	}


func _remove_node_id_from_next_node_ids(node_id: StringName) -> void:
	if node_id == &"":
		return
	for node: GFFlowNode in nodes:
		if node == null:
			continue
		var next_node_ids: PackedStringArray = PackedStringArray()
		for next_id_text: String in node.next_node_ids:
			if StringName(next_id_text) == node_id:
				continue
			_append_packed_string(next_node_ids, next_id_text)
		node.next_node_ids = next_node_ids


func _has_mixed_connection_ports(from_port_id: StringName, to_port_id: StringName) -> bool:
	return (from_port_id == &"" and to_port_id != &"") or (from_port_id != &"" and to_port_id == &"")


func _connection_matches(
	connection: Dictionary,
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> bool:
	return (
		_get_connection_from_node_id(connection) == from_node_id
		and _get_connection_from_port_id(connection) == from_port_id
		and _get_connection_to_node_id(connection) == to_node_id
		and _get_connection_to_port_id(connection) == to_port_id
	)


func _get_connection_key(
	from_node_id: StringName,
	from_port_id: StringName,
	to_node_id: StringName,
	to_port_id: StringName
) -> String:
	return "%s:%s>%s:%s" % [
		String(from_node_id),
		String(from_port_id),
		String(to_node_id),
		String(to_port_id),
	]


func _describe_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection: Dictionary in connections:
		result.append(connection.duplicate(true))
	return result


func _append_validation_issue(report: Dictionary, severity: String, kind: String, key: String, message: String) -> void:
	var issue: Dictionary = GFVariantData.as_dictionary(_GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.call("append_issue", report, severity, StringName(kind), message, { "key": key }))
	if not issue.is_empty():
		return


func _make_connection_compatibility_report(ok: bool, reason: String, message: String) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"message": message,
	}
