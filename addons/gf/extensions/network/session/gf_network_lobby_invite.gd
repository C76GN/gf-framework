## GFNetworkLobbyInvite: 平台中立的 lobby 邀请事件。
##
## 邀请只表达发送方、目标方和 lobby 入口信息。好友 UI、每日任务、奖励等业务策略
## 必须留在项目层或外部 adapter 中。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 8.0.0
class_name GFNetworkLobbyInvite
extends Resource


# --- 导出变量 ---

## 邀请 ID。没有平台邀请 ID 时可为空。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var invite_id: String = ""

## 相关 lobby ID。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var lobby_id: String = ""

## 提供邀请的 backend 标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var backend_id: StringName = &""

## 邀请发送方身份。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var sender: GFNetworkPeerIdentity = null

## 邀请目标身份。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var target: GFNetworkPeerIdentity = null

## 人读说明或平台侧附带消息。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var message: String = ""

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined invite metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 邀请字典。
## [br]
## @schema return: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.
func to_dict() -> Dictionary:
	return {
		"invite_id": invite_id,
		"lobby_id": lobby_id,
		"backend_id": backend_id,
		"sender": sender.to_dict() if sender != null else {},
		"target": target.to_dict() if target != null else {},
		"message": message,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用邀请字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 邀请字典。
## [br]
## @schema data: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.
func apply_dict(data: Dictionary) -> void:
	invite_id = GFVariantData.get_option_string(data, "invite_id").strip_edges()
	lobby_id = GFVariantData.get_option_string(data, "lobby_id").strip_edges()
	backend_id = GFVariantData.get_option_string_name(data, "backend_id")
	var sender_data: Dictionary = GFVariantData.get_option_dictionary(data, "sender")
	var target_data: Dictionary = GFVariantData.get_option_dictionary(data, "target")
	sender = GFNetworkPeerIdentity.from_dict(sender_data) if not sender_data.is_empty() else null
	target = GFNetworkPeerIdentity.from_dict(target_data) if not target_data.is_empty() else null
	message = GFVariantData.get_option_string(data, "message")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建邀请深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新邀请。
func duplicate_invite() -> GFNetworkLobbyInvite:
	var result: GFNetworkLobbyInvite = GFNetworkLobbyInvite.new()
	result.apply_dict(to_dict())
	return result


## 从字典创建邀请。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 邀请字典。
## [br]
## @schema data: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.
## [br]
## @return 新邀请。
static func from_dict(data: Dictionary) -> GFNetworkLobbyInvite:
	var result: GFNetworkLobbyInvite = GFNetworkLobbyInvite.new()
	result.apply_dict(data)
	return result
