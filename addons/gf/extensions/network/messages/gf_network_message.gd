## GFNetworkMessage: 通用网络消息载体。
##
## 只描述传输元信息和字典载荷，不绑定具体协议、后端或业务消息类型。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFNetworkMessage
extends RefCounted


# --- 公共变量 ---

## 消息类型标识。
## [br]
## @api public
var message_type: StringName = &""

## 发送端自增序号。
##
## 该字段只是项目层可序列化 metadata；GF Network 不基于它提供 ACK、重试或去重。
## [br]
## @api public
## [br]
## @since 7.0.0
var sequence: int = 0

## 逻辑 tick 或帧号。
## [br]
## @api public
var tick: int = 0

## 发送者标识。
## [br]
## @api public
var sender_id: int = -1

## 逻辑网络通道标识。为空时入站侧可按 message_type 匹配同名通道。
## [br]
## @api public
var channel_id: StringName = &""

## 消息载荷。
## [br]
## @api public
## [br]
## @schema payload: Dictionary[StringName|String, Variant]，保存消息业务载荷。
var payload: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_message_type: StringName = &"",
	p_payload: Dictionary = {},
	p_sequence: int = 0,
	p_tick: int = 0,
	p_sender_id: int = -1,
	p_channel_id: StringName = &""
) -> void:
	message_type = p_message_type
	payload = p_payload.duplicate(true)
	sequence = p_sequence
	tick = p_tick
	sender_id = p_sender_id
	channel_id = p_channel_id


# --- 公共方法 ---

## 转为可序列化字典。
## [br]
## @api public
## [br]
## @return 字典载荷。
## [br]
## @schema return: Dictionary，包含 type、sequence、tick、sender_id、channel_id、payload。
func to_dict() -> Dictionary:
	return {
		"type": message_type,
		"sequence": sequence,
		"tick": tick,
		"sender_id": sender_id,
		"channel_id": channel_id,
		"payload": payload.duplicate(true),
	}


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: 字典载荷。
## [br]
## @schema data: Dictionary，包含 type、sequence、tick、sender_id、channel_id、payload。
func from_dict(data: Dictionary) -> void:
	message_type = GFVariantData.get_option_string_name(data, "type")
	sequence = GFVariantData.get_option_int(data, "sequence")
	tick = GFVariantData.get_option_int(data, "tick")
	sender_id = GFVariantData.get_option_int(data, "sender_id", -1)
	channel_id = GFVariantData.get_option_string_name(data, "channel_id")
	payload = GFVariantData.get_option_dictionary(data, "payload")
