## GFNetworkLobbyJoinResult: Lobby 创建或加入结果。
##
## 该值对象统一表达同步或异步 backend 的最终结果，避免项目代码直接依赖
## 平台 SDK 的错误码枚举。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFNetworkLobbyJoinResult
extends RefCounted


# --- 公共变量 ---

## 操作是否成功。
## [br]
## @api public
## [br]
## @since 8.0.0
var ok: bool = false

## 相关 lobby ID。
## [br]
## @api public
## [br]
## @since 8.0.0
var lobby_id: String = ""

## 成功时的 lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
var lobby: GFNetworkLobbyDescriptor = null

## 失败原因标识。
## [br]
## @api public
## [br]
## @since 8.0.0
var error: StringName = &""

## 人读说明。
## [br]
## @api public
## [br]
## @since 8.0.0
var message: String = ""

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined result metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置成功结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_lobby: Lobby 快照。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined result metadata.
## [br]
## @return 当前结果。
func configure_success(p_lobby: GFNetworkLobbyDescriptor, p_metadata: Dictionary = {}) -> GFNetworkLobbyJoinResult:
	ok = true
	lobby = p_lobby.duplicate_lobby() if p_lobby != null else null
	lobby_id = lobby.lobby_id if lobby != null else ""
	error = &""
	message = ""
	metadata = p_metadata.duplicate(true)
	return self


## 配置失败结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_lobby_id: 相关 lobby ID。
## [br]
## @param p_error: 失败原因标识。
## [br]
## @param p_message: 人读说明。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined result metadata.
## [br]
## @return 当前结果。
func configure_failure(
	p_lobby_id: String,
	p_error: StringName,
	p_message: String = "",
	p_metadata: Dictionary = {}
) -> GFNetworkLobbyJoinResult:
	ok = false
	lobby_id = p_lobby_id.strip_edges()
	lobby = null
	error = p_error
	message = p_message.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 结果字典。
## [br]
## @schema return: Dictionary with ok, lobby_id, lobby, error, message, and metadata.
func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"lobby_id": lobby_id,
		"lobby": lobby.to_dict() if lobby != null else {},
		"error": error,
		"message": message,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用结果字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 结果字典。
## [br]
## @schema data: Dictionary with ok, lobby_id, lobby, error, message, and metadata.
func apply_dict(data: Dictionary) -> void:
	ok = GFVariantData.get_option_bool(data, "ok", false)
	lobby_id = GFVariantData.get_option_string(data, "lobby_id").strip_edges()
	var lobby_data: Dictionary = GFVariantData.get_option_dictionary(data, "lobby")
	lobby = GFNetworkLobbyDescriptor.from_dict(lobby_data) if not lobby_data.is_empty() else null
	error = GFVariantData.get_option_string_name(data, "error")
	message = GFVariantData.get_option_string(data, "message").strip_edges()
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建结果深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新结果。
func duplicate_result() -> GFNetworkLobbyJoinResult:
	var result: GFNetworkLobbyJoinResult = GFNetworkLobbyJoinResult.new()
	result.apply_dict(to_dict())
	return result


## 创建成功结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_value: Lobby 快照。
## [br]
## @param metadata_value: 调用方元数据。
## [br]
## @schema metadata_value: Dictionary caller-defined result metadata.
## [br]
## @return 成功结果。
static func success(lobby_value: GFNetworkLobbyDescriptor, metadata_value: Dictionary = {}) -> GFNetworkLobbyJoinResult:
	return GFNetworkLobbyJoinResult.new().configure_success(lobby_value, metadata_value)


## 创建失败结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id_value: 相关 lobby ID。
## [br]
## @param error_value: 失败原因标识。
## [br]
## @param message_value: 人读说明。
## [br]
## @param metadata_value: 调用方元数据。
## [br]
## @schema metadata_value: Dictionary caller-defined result metadata.
## [br]
## @return 失败结果。
static func failure(
	lobby_id_value: String,
	error_value: StringName,
	message_value: String = "",
	metadata_value: Dictionary = {}
) -> GFNetworkLobbyJoinResult:
	return GFNetworkLobbyJoinResult.new().configure_failure(lobby_id_value, error_value, message_value, metadata_value)


## 从字典创建结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 结果字典。
## [br]
## @schema data: Dictionary with ok, lobby_id, lobby, error, message, and metadata.
## [br]
## @return 新结果。
static func from_dict(data: Dictionary) -> GFNetworkLobbyJoinResult:
	var result: GFNetworkLobbyJoinResult = GFNetworkLobbyJoinResult.new()
	result.apply_dict(data)
	return result
