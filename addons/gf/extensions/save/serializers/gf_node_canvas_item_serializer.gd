## GFNodeCanvasItemSerializer: CanvasItem 通用显示状态序列化器。
##
## 保存可见性与颜色调制等通用表现状态，不保存具体业务字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeCanvasItemSerializer
extends GFNodeSerializer


# --- 常量 ---

const _PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "visible", "kind": &"bool" },
	{ "key": "modulate", "kind": &"color" },
	{ "key": "self_modulate", "kind": &"color" },
	{ "key": "show_behind_parent", "kind": &"bool" },
	{ "key": "top_level", "kind": &"bool" },
	{ "key": "z_as_relative", "kind": &"bool" },
	{ "key": "z_index", "kind": &"int" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.canvas_item"
	display_name = "Canvas Item"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 CanvasItem。
func supports_node(node: Node) -> bool:
	return node is CanvasItem


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return CanvasItem 显示状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 visible、modulate、self_modulate、show_behind_parent、top_level、z_as_relative 与 z_index。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var canvas_item: CanvasItem = _get_canvas_item(node)
	if canvas_item == null:
		return {}

	return _gather_property_specs(canvas_item, _PROPERTY_SPECS)


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: CanvasItem 显示状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 visible、modulate、self_modulate、show_behind_parent、top_level、z_as_relative 与 z_index。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var canvas_item: CanvasItem = _get_canvas_item(node)
	if canvas_item == null:
		return make_result(false, "Node is not CanvasItem.")

	var errors: Array[String] = _apply_property_specs(canvas_item, payload, _PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_canvas_item(node: Node) -> CanvasItem:
	if node is CanvasItem:
		var canvas_item: CanvasItem = node
		return canvas_item
	return null
