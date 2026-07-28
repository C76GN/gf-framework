## GFNetworkInputFrame: 网络同步输入帧值对象。
##
## 保存目标 tick、来源 peer、单调序号和项目输入载荷。该类型只负责值语义；
## 非可信消息仍必须由 GFNetworkSyncCoordinator 结合实际传输 peer 校验。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFNetworkInputFrame
extends RefCounted


# --- 常量 ---

const _TRANSPORT_VALUE_VALIDATOR = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")


# --- 公共变量 ---

## 输入应被模拟的目标 tick。
## [br]
## @api public
## [br]
## @since 10.0.0
var tick: int = 0

## 输入来源 peer。
## [br]
## @api public
## [br]
## @since 10.0.0
var peer_id: int = -1

## 来源 peer 内严格单调的输入序号。
## [br]
## @api public
## [br]
## @since 10.0.0
var sequence: int = 0

## 项目定义的输入载荷。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema payload: Dictionary[StringName|String, Variant]，只允许网络传输安全值。
var payload: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_tick: int = 0,
	p_peer_id: int = -1,
	p_sequence: int = 0,
	p_payload: Dictionary = {}
) -> void:
	tick = p_tick
	peer_id = p_peer_id
	sequence = p_sequence
	payload = p_payload.duplicate(true)


# --- 公共方法 ---

## 转为字典副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 输入帧字典。
## [br]
## @schema return: Dictionary { tick: int, peer_id: int, sequence: int, payload: Dictionary }.
func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"peer_id": peer_id,
		"sequence": sequence,
		"payload": payload.duplicate(true),
	}


## 从已由调用方校验的字典恢复。
##
## 该便利方法不建立传输身份或防重放边界；非可信数据应交给
## GFNetworkSyncCoordinator.handle_message()。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 输入帧字典。
## [br]
## @schema data: Dictionary { tick: int, peer_id: int, sequence: int, payload: Dictionary }.
func from_dict(data: Dictionary) -> void:
	tick = GFVariantData.get_option_int(data, "tick")
	peer_id = GFVariantData.get_option_int(data, "peer_id", -1)
	sequence = GFVariantData.get_option_int(data, "sequence")
	payload = GFVariantData.get_option_dictionary(data, "payload")


## 复制输入帧。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 独立输入帧副本。
func duplicate_frame() -> GFNetworkInputFrame:
	return GFNetworkInputFrame.new(tick, peer_id, sequence, payload)


## 校验值对象的基础字段和载荷预算。
##
## 该方法不校验 authority、epoch、顺序窗口或项目实体所有权。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param options: 结构预算；支持 max_depth、max_nodes 和 max_payload_bytes。
## [br]
## @schema options: Dictionary { max_depth?: int, max_nodes?: int, max_payload_bytes?: int }.
## [br]
## @return 统一校验报告。
## [br]
## @schema return: Dictionary { ok: bool, error: String, path: String, payload_bytes: int }.
func validate_frame(options: Dictionary = {}) -> Dictionary:
	if tick < 0:
		return _make_validation_report(false, "tick_out_of_range")
	if peer_id < 0:
		return _make_validation_report(false, "peer_id_out_of_range")
	if sequence <= 0:
		return _make_validation_report(false, "sequence_out_of_range")
	var value_report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(payload, options)
	if not GFVariantData.get_option_bool(value_report, "ok"):
		return _make_validation_report(
			false,
			GFVariantData.get_option_string(value_report, "error"),
			GFVariantData.get_option_string(value_report, "path")
		)
	var payload_bytes: int = var_to_bytes(payload).size()
	var max_payload_bytes: int = GFVariantData.get_option_int(options, "max_payload_bytes", 64 * 1024)
	if max_payload_bytes <= 0 or payload_bytes > max_payload_bytes:
		return _make_validation_report(false, "payload_budget_exceeded", "", payload_bytes)
	return _make_validation_report(true, "", "", payload_bytes)


# --- 私有/辅助方法 ---

func _make_validation_report(
	ok: bool,
	error: String,
	path: String = "",
	payload_bytes: int = 0
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"path": path,
		"payload_bytes": payload_bytes,
	}
