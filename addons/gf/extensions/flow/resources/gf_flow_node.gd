## GFFlowNode: 通用流程图节点基类。
##
## 节点只描述执行入口和默认后继节点。具体条件、命令、等待逻辑由项目继承实现。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFFlowNode
extends Resource


# --- 导出变量 ---

## 节点稳定标识。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var node_id: StringName = &""

## 节点显示名；为空时回退到 node_id。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var display_name: String = ""

## 节点分类，仅供编辑器、搜索或项目工具使用。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var category: StringName = &""

## 默认后继节点列表。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var next_node_ids: PackedStringArray = PackedStringArray()

## 返回 Signal 时是否等待。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var wait_for_result: bool = true

## 输入端口描述。仅用于编辑器、校验和项目层数据连接。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var input_ports: Array[GFFlowPort] = []

## 输出端口描述。仅用于编辑器、校验和项目层数据连接。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var output_ports: Array[GFFlowPort] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
@export var metadata: Dictionary = {}

## 编辑器中的节点位置。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var editor_position: Vector2 = Vector2.ZERO

## 编辑器中的节点尺寸；为 ZERO 时表示由编辑器自行决定。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var editor_size: Vector2 = Vector2.ZERO

## 编辑器中是否折叠显示。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var editor_collapsed: bool = false


# --- 私有变量 ---

## 保存节点运行时状态租约的运行时状态租约序号。
## [br]
## @api private
var _runtime_state_lease_serial: int = 0

## 保存节点运行时状态租约的运行时状态租约ID。
## [br]
## @api private
var _runtime_state_lease_id: int = 0


# --- 公共方法 ---

## 执行节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _context: 各次流程运行可共享的业务上下文。
## [br]
## @param _execution: 当前帧本次节点调用独有的运行状态写入句柄。
## [br]
## @return: 可返回 null 或 Signal。
## [br]
## @schema return: null、Signal 或项目节点实现约定的结果值。
func execute(_context: GFFlowContext, _execution: GFFlowNodeExecution) -> Variant:
	return null


## 获取执行完成后的后继节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _context: 调度默认后继时可读取的业务上下文。
## [br]
## @return: 后继节点标识列表。
func get_next_nodes(_context: GFFlowContext) -> PackedStringArray:
	return next_node_ids.duplicate()


## 获取节点显示名。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 显示名。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if node_id != &"":
		return String(node_id)
	return "Flow Node"


## 获取输入端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 输入端口数组。
func get_input_ports() -> Array[GFFlowPort]:
	return input_ports.duplicate()


## 获取输出端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 输出端口数组。
func get_output_ports() -> Array[GFFlowPort]:
	return output_ports.duplicate()


## 按端口标识查找输入端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param port_id: 端口标识。
## [br]
## @return: 输入端口；不存在时返回 null。
func get_input_port(port_id: StringName) -> GFFlowPort:
	return _find_port(input_ports, port_id)


## 按端口标识查找输出端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param port_id: 端口标识。
## [br]
## @return: 输出端口；不存在时返回 null。
func get_output_port(port_id: StringName) -> GFFlowPort:
	return _find_port(output_ports, port_id)


## 描述节点端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 端口描述字典。
## [br]
## @schema return: 包含 inputs 和 outputs 字段的 Dictionary；每个字段为端口描述数组。
func describe_ports() -> Dictionary:
	return { "inputs": _describe_ports(input_ports), "outputs": _describe_ports(output_ports), }


## 描述节点编辑器元数据。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 编辑器元数据字典。
## [br]
## @schema return: 包含 display_name、category、position、size 和 collapsed 字段的 Dictionary。
func describe_editor() -> Dictionary:
	return {
		"display_name": get_display_name(),
		"category": category,
		"position": editor_position,
		"size": editor_size,
		"collapsed": editor_collapsed,
	}


## 描述节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 节点描述字典。
## [br]
## @schema return: 包含 node_id、display_name、category、next_node_ids、wait_for_result、ports、editor 和 metadata 字段的 Dictionary。
func describe_node() -> Dictionary:
	return {
		"node_id": node_id,
		"display_name": get_display_name(),
		"category": category,
		"next_node_ids": next_node_ids.duplicate(),
		"wait_for_result": wait_for_result,
		"ports": describe_ports(),
		"editor": describe_editor(),
		"metadata": metadata.duplicate(true),
	}


# --- 框架内部方法 ---

## 原子取得共享节点运行态的独占租约。
##
## Runner 必须在发出 node_started 或调用 execute() 之前取得租约。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @return: 正整数租约 ID；节点正被其他执行占用时返回 -1。
func acquire_runtime_state_lease() -> int:
	if _runtime_state_lease_id > 0:
		return -1
	_runtime_state_lease_serial += 1
	if _runtime_state_lease_serial <= 0:
		_runtime_state_lease_serial = 1
	_runtime_state_lease_id = _runtime_state_lease_serial
	return _runtime_state_lease_id


## 释放共享节点运行态租约。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param lease_id: 当前租约 ID。
## [br]
## @return: 成功释放时返回 true。
func release_runtime_state_lease(lease_id: int) -> bool:
	if lease_id <= 0 or lease_id != _runtime_state_lease_id:
		return false
	_runtime_state_lease_id = 0
	return true


## 查询共享节点运行态是否已被执行租约占用。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @return: 存在活动租约时返回 true。
func is_runtime_state_leased() -> bool:
	return _runtime_state_lease_id > 0


# --- 私有/辅助方法 ---

## 按端口 ID 在指定端口数组中查找端口。
## [br]
## @api private
func _find_port(ports: Array[GFFlowPort], port_id: StringName) -> GFFlowPort:
	for port: GFFlowPort in ports:
		if port != null and _get_port_id(port) == port_id:
			return port
	return null


## 将非空端口资源转换为描述字典数组。
## [br]
## @api private
func _describe_ports(ports: Array[GFFlowPort]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for port: GFFlowPort in ports:
		if port != null:
			result.append(_describe_port(port))
	return result


## 提取端口属性并构造描述字典。
## [br]
## @api private
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


## 读取端口稳定 ID。
## [br]
## @api private
func _get_port_id(port: GFFlowPort) -> StringName:
	if port == null:
		return &""
	if port.port_id != &"":
		return port.port_id
	return &""


## 读取端口显示名，缺省时回退到端口 ID、资源名或通用名称。
## [br]
## @api private
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
