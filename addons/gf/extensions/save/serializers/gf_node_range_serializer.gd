## GFNodeRangeSerializer: Range 通用数值状态序列化器。
##
## 保存滑条、进度条等 Range 派生控件的通用数值参数。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeRangeSerializer
extends GFNodeSerializer


# --- 常量 ---

const _PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "min_value", "kind": &"float" },
	{ "key": "max_value", "kind": &"float" },
	{ "key": "step", "kind": &"float" },
	{ "key": "page", "kind": &"float" },
	{ "key": "rounded", "kind": &"bool" },
	{ "key": "allow_greater", "kind": &"bool" },
	{ "key": "allow_lesser", "kind": &"bool" },
	{ "key": "value", "kind": &"float" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.range"
	display_name = "Range"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 Range。
func supports_node(node: Node) -> bool:
	return node is Range


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return Range 状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 min_value、max_value、step、page、rounded、allow_greater、allow_lesser 与 value。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var range_node: Range = _get_range(node)
	if range_node == null:
		return {}

	return _gather_property_specs(range_node, _PROPERTY_SPECS)


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Range 状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 min_value、max_value、step、page、rounded、allow_greater、allow_lesser 与 value。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var range_node: Range = _get_range(node)
	if range_node == null:
		return make_result(false, "Node is not Range.")

	var errors: Array[String] = _apply_property_specs(range_node, payload, _PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_range(node: Node) -> Range:
	if node is Range:
		var range_node: Range = node
		return range_node
	return null
