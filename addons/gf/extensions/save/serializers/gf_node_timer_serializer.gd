## GFNodeTimerSerializer: Timer 通用状态序列化器。
##
## 保存 Timer 的等待时间、暂停、一次性和当前剩余时间等通用状态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodeTimerSerializer
extends GFNodeSerializer


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.timer"
	display_name = "Timer"


# --- 公共方法 ---

## 判断序列化器是否支持指定节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 节点是否为 Timer。
func supports_node(node: Node) -> bool:
	return node is Timer


## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return Timer 状态载荷。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，可包含 wait_time、one_shot、autostart、paused、time_left 与 stopped。
func gather(node: Node, _context: Dictionary = {}) -> Dictionary:
	var timer: Timer = _get_timer(node)
	if timer == null:
		return {}

	return {
		"wait_time": timer.wait_time,
		"one_shot": timer.one_shot,
		"autostart": timer.autostart,
		"paused": timer.paused,
		"time_left": timer.time_left,
		"stopped": timer.is_stopped(),
	}


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Timer 状态载荷。
## [br]
## @param _context: 操作上下文字典，默认实现不直接使用。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，可包含 wait_time、one_shot、autostart、paused、time_left 与 stopped。
## [br]
## @schema _context: Dictionary，调用方附加上下文；当前实现不读取。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var timer: Timer = _get_timer(node)
	if timer == null:
		return make_result(false, "Node is not Timer.")

	var errors: Array[String] = _validate_property_specs_payload(payload, [
		{ "key": "wait_time", "kind": &"float" },
		{ "key": "one_shot", "kind": &"bool" },
		{ "key": "autostart", "kind": &"bool" },
		{ "key": "paused", "kind": &"bool" },
		{ "key": "time_left", "kind": &"float" },
		{ "key": "stopped", "kind": &"bool" },
	])
	if not errors.is_empty():
		return make_result(false, "; ".join(errors))

	if payload.has("wait_time"):
		timer.wait_time = maxf(GFVariantData.to_float(payload["wait_time"]), 0.0)
	if payload.has("one_shot"):
		timer.one_shot = GFVariantData.to_bool(payload["one_shot"])
	if payload.has("autostart"):
		timer.autostart = GFVariantData.to_bool(payload["autostart"])
	if payload.has("paused"):
		timer.paused = GFVariantData.to_bool(payload["paused"])

	if payload.has("stopped"):
		if GFVariantData.to_bool(payload["stopped"]):
			timer.stop()
		else:
			var time_left: float = GFVariantData.get_option_float(payload, "time_left", timer.wait_time)
			timer.start(time_left if time_left > 0.0 else timer.wait_time)
	return make_result(true)


# --- 私有/辅助方法 ---

func _get_timer(node: Node) -> Timer:
	if node is Timer:
		var timer: Timer = node
		return timer
	return null
