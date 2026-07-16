## GFNetworkMessageValidator: 通用网络消息校验器。
##
## 校验消息类型、包体大小和可选必需载荷字段，避免后端收到明显无效数据。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNetworkMessageValidator
extends RefCounted


# --- 常量 ---

## 默认全局最大包体大小，单位 bytes。
## [br]
## @api public
const DEFAULT_MAX_PACKET_SIZE: int = 64 * 1024


# --- 公共变量 ---

## 是否允许空 message_type。
## [br]
## @api public
var allow_empty_message_type: bool = false

## 最小包体大小。小于等于 0 表示不限制。
## [br]
## @api public
var min_packet_size: int = 1

## 最大包体大小。小于等于 0 表示不限制。
## [br]
## @api public
var max_packet_size: int = DEFAULT_MAX_PACKET_SIZE

## 所有消息都必须包含的 payload key。
## [br]
## @api public
var required_payload_keys: PackedStringArray = PackedStringArray()

## 允许的 message_type 列表。为空时不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var allowed_message_types: PackedStringArray = PackedStringArray()

## 显式拒绝的 message_type 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
var blocked_message_types: PackedStringArray = PackedStringArray()

## 可选网络契约。设置后可用字段契约校验消息 payload。
## [br]
## @api public
## [br]
## @since 8.0.0
var contract: GFNetworkContract = null

## 是否要求 message_type 必须存在于 contract 中。
## [br]
## @api public
## [br]
## @since 8.0.0
var require_contract_message: bool = false

## 已知逻辑 channel_id 列表。为空时不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var known_channel_ids: PackedStringArray = PackedStringArray()

## 通过 validate_message_for_peer() 校验时，是否要求 sender_id 与实际 peer_id 一致。
## [br]
## @api public
## [br]
## @since 8.0.0
var enforce_sender_id_matches_peer: bool = false

## 是否要求消息显式携带 sender_id。
## [br]
## @api public
## [br]
## @since 8.0.0
var require_sender_id: bool = false

## 最小允许 sequence。小于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var min_sequence: int = -1

## 最大允许 sequence。小于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_sequence: int = -1

## 最小允许 tick。小于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var min_tick: int = -1

## 最大允许 tick。小于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_tick: int = -1


# --- 公共方法 ---

## 校验消息对象。
## [br]
## @api public
## [br]
## @param message: 消息。
## [br]
## @return 统一校验报告。
## [br]
## @schema return: Dictionary，包含 ok 和 errors。
func validate_message(message: GFNetworkMessage) -> Dictionary:
	return _validate_message_internal(message, -1, false)


## 按实际 peer 上下文校验消息对象。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param message: 消息。
## [br]
## @param peer_id: 实际传输 peer 标识。
## [br]
## @return 统一校验报告。
## [br]
## @schema return: Dictionary，包含 ok 和 errors。
func validate_message_for_peer(message: GFNetworkMessage, peer_id: int) -> Dictionary:
	return _validate_message_internal(message, peer_id, true)


## 添加允许的 message_type。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param message_type: 消息类型。
## [br]
## @return 成功添加或已存在时返回 true。
func allow_message_type(message_type: StringName) -> bool:
	return _append_unique_string(allowed_message_types, String(message_type))


## 添加已知 channel_id。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param channel_id: 通道标识。
## [br]
## @return 成功添加或已存在时返回 true。
func register_known_channel(channel_id: StringName) -> bool:
	return _append_unique_string(known_channel_ids, String(channel_id))


## 从网络契约同步允许消息和已知通道。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param network_contract: 网络契约。
## [br]
## @param options: 同步选项，支持 include_channels。
## [br]
## @schema options: Dictionary sync options.
func configure_from_contract(network_contract: GFNetworkContract, options: Dictionary = {}) -> void:
	contract = network_contract
	allowed_message_types.clear()
	if GFVariantData.get_option_bool(options, "include_channels", true):
		known_channel_ids.clear()
	if contract == null:
		return
	for message_contract: GFNetworkContractMessage in contract.messages:
		if message_contract == null:
			continue
		var _allowed_added: bool = allow_message_type(message_contract.message_type)
		if GFVariantData.get_option_bool(options, "include_channels", true):
			var _channel_added: bool = register_known_channel(message_contract.channel_id)


## 校验原始包体。
## [br]
## @api public
## [br]
## @param bytes: 包体。
## [br]
## @param channel: 可选通道描述。
## [br]
## @return 统一校验报告。
## [br]
## @schema return: Dictionary，包含 ok 和 errors。
func validate_bytes(bytes: PackedByteArray, channel: GFNetworkChannel = null) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var byte_count: int = bytes.size()
	if min_packet_size > 0 and byte_count < min_packet_size:
		var _append_result_85: Variant = errors.append("packet_too_small")

	var effective_max: int = max_packet_size
	if channel != null and channel.max_packet_size > 0:
		effective_max = channel.max_packet_size if effective_max <= 0 else mini(effective_max, channel.max_packet_size)
	if effective_max > 0 and byte_count > effective_max:
		var _append_result_91: Variant = errors.append("packet_too_large")
	return _make_report(errors)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 校验器状态。
## [br]
## @schema return: Dictionary，包含 allow_empty_message_type、min_packet_size、max_packet_size、required_payload_keys、allowed_message_types、blocked_message_types、require_contract_message、known_channel_ids、enforce_sender_id_matches_peer、require_sender_id、min_sequence、max_sequence、min_tick 和 max_tick。
func get_debug_snapshot() -> Dictionary:
	return {
		"allow_empty_message_type": allow_empty_message_type,
		"min_packet_size": min_packet_size,
		"max_packet_size": max_packet_size,
		"required_payload_keys": required_payload_keys.duplicate(),
		"allowed_message_types": allowed_message_types.duplicate(),
		"blocked_message_types": blocked_message_types.duplicate(),
		"contract_configured": contract != null,
		"require_contract_message": require_contract_message,
		"known_channel_ids": known_channel_ids.duplicate(),
		"enforce_sender_id_matches_peer": enforce_sender_id_matches_peer,
		"require_sender_id": require_sender_id,
		"min_sequence": min_sequence,
		"max_sequence": max_sequence,
		"min_tick": min_tick,
		"max_tick": max_tick,
	}


# --- 私有/辅助方法 ---

func _validate_message_internal(message: GFNetworkMessage, peer_id: int, has_peer_context: bool) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	if message == null:
		var _append_result_59: Variant = errors.append("message_is_null")
		return _make_report(errors)

	if message.message_type == &"" and not allow_empty_message_type:
		var _append_result_63: Variant = errors.append("empty_message_type")
	if _string_set_has(blocked_message_types, String(message.message_type)):
		var _blocked_result: Variant = errors.append("blocked_message_type")
	if not allowed_message_types.is_empty() and not _string_set_has(allowed_message_types, String(message.message_type)):
		var _allowed_result: Variant = errors.append("message_type_not_allowed")
	if not known_channel_ids.is_empty() and message.channel_id != &"" and not _string_set_has(known_channel_ids, String(message.channel_id)):
		var _channel_result: Variant = errors.append("unknown_channel_id")
	if require_sender_id and message.sender_id < 0:
		var _sender_required_result: Variant = errors.append("sender_id_missing")
	if has_peer_context and enforce_sender_id_matches_peer and message.sender_id >= 0 and message.sender_id != peer_id:
		var _sender_mismatch_result: Variant = errors.append("sender_id_mismatch")
	if min_sequence >= 0 and message.sequence < min_sequence:
		var _sequence_min_result: Variant = errors.append("sequence_below_minimum")
	if max_sequence >= 0 and message.sequence > max_sequence:
		var _sequence_max_result: Variant = errors.append("sequence_above_maximum")
	if min_tick >= 0 and message.tick < min_tick:
		var _tick_min_result: Variant = errors.append("tick_below_minimum")
	if max_tick >= 0 and message.tick > max_tick:
		var _tick_max_result: Variant = errors.append("tick_above_maximum")
	for key: String in required_payload_keys:
		if not _payload_has_key(message.payload, key):
			var _append_result_66: Variant = errors.append("missing_payload_key:%s" % key)

	if contract != null:
		var message_contract: GFNetworkContractMessage = contract.get_message_contract(message.message_type)
		if message_contract == null:
			if require_contract_message:
				var _contract_unknown_result: Variant = errors.append("unknown_contract_message_type")
		else:
			_append_contract_errors(errors, message_contract.validate_message(message))
	return _make_report(errors)


func _make_report(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}


func _payload_has_key(payload: Dictionary, key: String) -> bool:
	if payload.has(key):
		return true
	return payload.has(StringName(key))


func _append_unique_string(items: PackedStringArray, value: String) -> bool:
	var normalized: String = value.strip_edges()
	if normalized.is_empty():
		return false
	if not items.has(normalized):
		var _append_result: bool = items.append(normalized)
		items.sort()
	return true


func _string_set_has(items: PackedStringArray, value: String) -> bool:
	return items.has(value.strip_edges())


func _append_contract_errors(errors: PackedStringArray, report: Dictionary) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var kind: String = GFVariantData.get_option_string(issue, "kind")
		if not kind.is_empty():
			var _append_result: bool = errors.append("contract:%s" % kind)
