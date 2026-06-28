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
	var errors: PackedStringArray = PackedStringArray()
	if message == null:
		var _append_result_59: Variant = errors.append("message_is_null")
		return _make_report(errors)

	if message.message_type == &"" and not allow_empty_message_type:
		var _append_result_63: Variant = errors.append("empty_message_type")
	for key: String in required_payload_keys:
		if not _payload_has_key(message.payload, key):
			var _append_result_66: Variant = errors.append("missing_payload_key:%s" % key)
	return _make_report(errors)


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
## @return 校验器状态。
## [br]
## @schema return: Dictionary，包含 allow_empty_message_type、min_packet_size、max_packet_size、required_payload_keys。
func get_debug_snapshot() -> Dictionary:
	return {
		"allow_empty_message_type": allow_empty_message_type,
		"min_packet_size": min_packet_size,
		"max_packet_size": max_packet_size,
		"required_payload_keys": required_payload_keys.duplicate(),
	}


# --- 私有/辅助方法 ---

func _make_report(errors: PackedStringArray) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
	}


func _payload_has_key(payload: Dictionary, key: String) -> bool:
	if payload.has(key):
		return true
	return payload.has(StringName(key))
