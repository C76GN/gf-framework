## GFNodeTransform3DSerializer: Node3D Transform 序列化器。
##
## 以 JSON 友好的标量数组保存 position、rotation 与 scale。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeTransform3DSerializer
extends GFNodeSerializer


# --- 常量 ---

const _PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "position", "kind": &"vector3" },
	{ "key": "rotation", "kind": &"vector3" },
	{ "key": "scale", "kind": &"vector3" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.transform_3d"
	display_name = "Transform 3D"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 Node3D。
func supports_node(node: Node) -> bool:
	return node is Node3D


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return Node3D transform 载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 position: Array[float]、rotation: Array[float] 与 scale: Array[float]。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var node_3d: Node3D = _get_node_3d(node)
	if node_3d == null:
		return {}

	return _gather_property_specs(node_3d, _PROPERTY_SPECS)


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Node3D transform 载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 position: Array[float]、rotation: Array[float] 与 scale: Array[float]。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var node_3d: Node3D = _get_node_3d(node)
	if node_3d == null:
		return make_result(false, "Node is not Node3D.")

	var errors: Array[String] = _apply_property_specs(node_3d, payload, _PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_node_3d(node: Node) -> Node3D:
	if node is Node3D:
		var node_3d: Node3D = node
		return node_3d
	return null
