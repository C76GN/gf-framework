## GFNetworkLobbyMember: 平台中立的 lobby 成员描述。
##
## 成员只描述 peer 身份、owner/local 标记和 metadata，不承载玩家业务状态、
## 准备状态、角色选择或 UI 信息。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFNetworkLobbyMember
extends Resource


# --- 导出变量 ---

## 成员传输 peer 标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var peer_id: int = -1

## 成员身份描述。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var identity: GFNetworkPeerIdentity = null

## 是否为 lobby owner。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var is_owner: bool = false

## 是否为本地成员。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var is_local: bool = false

## 调用方自定义成员元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined member metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置成员。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_peer_id: 成员传输 peer 标识。
## [br]
## @param p_identity: 成员身份。
## [br]
## @param p_metadata: 成员元数据。
## [br]
## @param options: 可选项，支持 is_owner 和 is_local。
## [br]
## @schema p_metadata: Dictionary caller-defined member metadata.
## [br]
## @schema options: Dictionary member flags.
## [br]
## @return 当前成员。
func configure(
	p_peer_id: int = -1,
	p_identity: GFNetworkPeerIdentity = null,
	p_metadata: Dictionary = {},
	options: Dictionary = {}
) -> GFNetworkLobbyMember:
	peer_id = p_peer_id
	identity = p_identity.duplicate_identity() if p_identity != null else null
	if identity != null and identity.peer_id < 0:
		identity.peer_id = peer_id
	is_owner = GFVariantData.get_option_bool(options, "is_owner", false)
	is_local = GFVariantData.get_option_bool(options, "is_local", false)
	metadata = p_metadata.duplicate(true)
	return self


## 获取展示名称。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 展示名称。
func get_display_name() -> String:
	if identity != null and not identity.display_name.is_empty():
		return identity.display_name
	if peer_id >= 0:
		return "Peer %d" % peer_id
	return "Lobby Member"


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 成员字典。
## [br]
## @schema return: Dictionary with peer_id, identity, is_owner, is_local, and metadata.
func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"identity": identity.to_dict() if identity != null else {},
		"is_owner": is_owner,
		"is_local": is_local,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用成员字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 成员字典。
## [br]
## @schema data: Dictionary with peer_id, identity, is_owner, is_local, and metadata.
func apply_dict(data: Dictionary) -> void:
	peer_id = GFVariantData.get_option_int(data, "peer_id", -1)
	var identity_data: Dictionary = GFVariantData.get_option_dictionary(data, "identity")
	identity = GFNetworkPeerIdentity.from_dict(identity_data) if not identity_data.is_empty() else null
	is_owner = GFVariantData.get_option_bool(data, "is_owner", false)
	is_local = GFVariantData.get_option_bool(data, "is_local", false)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建成员深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新成员。
func duplicate_member() -> GFNetworkLobbyMember:
	var result: GFNetworkLobbyMember = GFNetworkLobbyMember.new()
	result.apply_dict(to_dict())
	return result


## 从字典创建成员。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 成员字典。
## [br]
## @schema data: Dictionary with peer_id, identity, is_owner, is_local, and metadata.
## [br]
## @return 新成员。
static func from_dict(data: Dictionary) -> GFNetworkLobbyMember:
	var result: GFNetworkLobbyMember = GFNetworkLobbyMember.new()
	result.apply_dict(data)
	return result
