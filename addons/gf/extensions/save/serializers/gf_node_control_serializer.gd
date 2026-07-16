## GFNodeControlSerializer: Control 通用布局状态序列化器。
##
## 保存 Control 的锚点、偏移、尺寸和交互开关，适合简单 UI 状态恢复。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeControlSerializer
extends GFNodeSerializer


# --- 常量 ---

const _PROPERTY_SPECS: Array[Dictionary] = [
	{ "key": "anchor_left", "kind": &"float" },
	{ "key": "anchor_top", "kind": &"float" },
	{ "key": "anchor_right", "kind": &"float" },
	{ "key": "anchor_bottom", "kind": &"float" },
	{ "key": "offset_left", "kind": &"float" },
	{ "key": "offset_top", "kind": &"float" },
	{ "key": "offset_right", "kind": &"float" },
	{ "key": "offset_bottom", "kind": &"float" },
	{ "key": "pivot_offset", "kind": &"vector2" },
	{ "key": "rotation", "kind": &"float" },
	{ "key": "scale", "kind": &"vector2" },
	{ "key": "mouse_filter", "kind": &"int" },
	{ "key": "focus_mode", "kind": &"int" },
]


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.control"
	display_name = "Control"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 Control。
func supports_node(node: Node) -> bool:
	return node is Control


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return Control 布局状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 anchor_*、offset_*、pivot_offset、rotation、scale、mouse_filter 与 focus_mode。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var control: Control = _get_control(node)
	if control == null:
		return {}

	return _gather_property_specs(control, _PROPERTY_SPECS)


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Control 布局状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 anchor_*、offset_*、pivot_offset、rotation、scale、mouse_filter 与 focus_mode。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var control: Control = _get_control(node)
	if control == null:
		return make_result(false, "Node is not Control.")

	var errors: Array[String] = _apply_property_specs(control, payload, _PROPERTY_SPECS)
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_control(node: Node) -> Control:
	if node is Control:
		var control: Control = node
		return control
	return null
