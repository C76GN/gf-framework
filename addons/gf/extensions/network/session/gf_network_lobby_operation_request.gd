## GFNetworkLobbyOperationRequest: Lobby 操作请求。
##
## 将创建、查询、加入、离开和 metadata 更新统一为可关联、可复制的请求值对象。
## Provider 专属参数只能放入 provider_options，不能泄漏到项目领域模型。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 10.0.0
class_name GFNetworkLobbyOperationRequest
extends RefCounted


# --- 常量 ---

## 创建 Lobby 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_CREATE_LOBBY: StringName = &"create_lobby"

## 查询 Lobby 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_QUERY_LOBBIES: StringName = &"query_lobbies"

## 加入 Lobby 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_JOIN_LOBBY: StringName = &"join_lobby"

## 离开 Lobby 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_LEAVE_LOBBY: StringName = &"leave_lobby"

## 更新 Lobby metadata 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_SET_LOBBY_METADATA: StringName = &"set_lobby_metadata"

## 更新成员 metadata 操作。
## [br]
## @api public
## [br]
## @since 10.0.0
const OP_SET_MEMBER_METADATA: StringName = &"set_member_metadata"


# --- 公共变量 ---

## 请求稳定 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var request_id: StringName = &""

## 操作类型。
## [br]
## @api public
## [br]
## @since 10.0.0
var operation: StringName = &""

## 目标 Lobby ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var lobby_id: String = ""

## 目标成员 peer ID。
## [br]
## @api public
## [br]
## @since 10.0.0
var peer_id: int = 0

## 查询操作的过滤条件。
## [br]
## @api public
## [br]
## @since 10.0.0
var query: GFNetworkLobbyQuery = null

## 操作载荷，例如 metadata patch。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema payload: Dictionary operation payload.
var payload: Dictionary = {}

## Provider 专属调用选项。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema provider_options: Dictionary external provider options.
var provider_options: Dictionary = {}

## 超时时间，单位毫秒；0 表示由 Service 默认值决定或不限制。
## [br]
## @api public
## [br]
## @since 10.0.0
var timeout_msec: int = 0

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary caller-defined request metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 Lobby 操作请求。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param p_request_id: 请求 ID。
## [br]
## @param p_operation: 操作类型常量。
## [br]
## @param options: 可包含 lobby_id、peer_id、query、payload、provider_options、timeout_msec 和 metadata。
## [br]
## @schema options: Dictionary lobby operation request fields.
## [br]
## @return 当前请求。
func configure(
	p_request_id: StringName,
	p_operation: StringName,
	options: Dictionary = {}
) -> GFNetworkLobbyOperationRequest:
	request_id = StringName(String(p_request_id).strip_edges())
	operation = StringName(String(p_operation).strip_edges())
	lobby_id = GFVariantData.get_option_string(options, "lobby_id").strip_edges()
	peer_id = GFVariantData.get_option_int(options, "peer_id")
	query = _get_query(options)
	payload = GFVariantData.get_option_dictionary(options, "payload")
	provider_options = GFVariantData.get_option_dictionary(options, "provider_options")
	timeout_msec = maxi(GFVariantData.get_option_int(options, "timeout_msec"), 0)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 检查请求字段是否满足对应操作的最小契约。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 请求可派发时返回 true。
func is_valid() -> bool:
	if request_id == &"" or not get_supported_operations().has(String(operation)):
		return false
	match operation:
		OP_JOIN_LOBBY, OP_LEAVE_LOBBY:
			return not lobby_id.is_empty()
		OP_SET_LOBBY_METADATA:
			return not lobby_id.is_empty() and not payload.is_empty()
		OP_SET_MEMBER_METADATA:
			return not lobby_id.is_empty() and peer_id > 0 and not payload.is_empty()
		_:
			return true


## 转换为字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Lobby 操作请求字典。
## [br]
## @schema return: Dictionary lobby operation request.
func to_dict() -> Dictionary:
	return {
		"request_id": request_id,
		"operation": operation,
		"lobby_id": lobby_id,
		"peer_id": peer_id,
		"query": query.to_dict() if query != null else {},
		"payload": payload.duplicate(true),
		"provider_options": provider_options.duplicate(true),
		"timeout_msec": timeout_msec,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用请求字段。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: Lobby 操作请求字典。
## [br]
## @schema data: Dictionary lobby operation request.
func apply_dict(data: Dictionary) -> void:
	request_id = GFVariantData.get_option_string_name(data, "request_id")
	operation = GFVariantData.get_option_string_name(data, "operation")
	lobby_id = GFVariantData.get_option_string(data, "lobby_id").strip_edges()
	peer_id = GFVariantData.get_option_int(data, "peer_id")
	var query_data: Dictionary = GFVariantData.get_option_dictionary(data, "query")
	query = GFNetworkLobbyQuery.from_dict(query_data) if not query_data.is_empty() else null
	payload = GFVariantData.get_option_dictionary(data, "payload")
	provider_options = GFVariantData.get_option_dictionary(data, "provider_options")
	timeout_msec = maxi(GFVariantData.get_option_int(data, "timeout_msec"), 0)
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建请求深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新请求。
func duplicate_request() -> GFNetworkLobbyOperationRequest:
	return from_dict(to_dict())


## 获取全部支持的操作 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 固定操作 ID 集合。
static func get_supported_operations() -> PackedStringArray:
	return PackedStringArray([
		OP_CREATE_LOBBY,
		OP_QUERY_LOBBIES,
		OP_JOIN_LOBBY,
		OP_LEAVE_LOBBY,
		OP_SET_LOBBY_METADATA,
		OP_SET_MEMBER_METADATA,
	])


## 从字典创建请求。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: Lobby 操作请求字典。
## [br]
## @schema data: Dictionary lobby operation request.
## [br]
## @return 新请求。
static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationRequest:
	var request: GFNetworkLobbyOperationRequest = GFNetworkLobbyOperationRequest.new()
	request.apply_dict(data)
	return request


# --- 私有/辅助方法 ---

func _get_query(options: Dictionary) -> GFNetworkLobbyQuery:
	var value: Variant = GFVariantData.get_option_value(options, "query")
	if value is GFNetworkLobbyQuery:
		var query_value: GFNetworkLobbyQuery = value
		return query_value.duplicate_query()
	return null
