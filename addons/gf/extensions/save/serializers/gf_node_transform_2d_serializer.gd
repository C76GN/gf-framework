## GFNodeTransform2DSerializer: Node2D Transform 序列化器。
##
## 以 JSON 友好的标量数组保存 position、rotation 与 scale。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeTransform2DSerializer
extends GFNodeSerializer


# --- 常量 ---

const _PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "position", "kind": &"vector2" },
	{ "key": "rotation", "kind": &"float" },
	{ "key": "scale", "kind": &"vector2" },
	{ "key": "z_index", "kind": &"int" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.transform_2d"
	display_name = "Transform 2D"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 Node2D。
func supports_node(node: Node) -> bool:
	return node is Node2D


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return Node2D transform 载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 position: Array[float]、rotation: float、scale: Array[float] 与 z_index: int。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var node_2d: Node2D = _get_node_2d(node)
	if node_2d == null:
		return {}

	return _gather_property_specs(node_2d, _PROPERTY_SPECS)


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Node2D transform 载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 position: Array[float]、rotation: float、scale: Array[float] 与 z_index: int。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var node_2d: Node2D = _get_node_2d(node)
	if node_2d == null:
		return make_result(false, "Node is not Node2D.")

	var errors: Array[String] = _apply_property_specs(node_2d, payload, _PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_node_2d(node: Node) -> Node2D:
	if node is Node2D:
		var node_2d: Node2D = node
		return node_2d
	return null
