## GFNetworkLobbyBackend: 平台中立 lobby 后端协议。
##
## 后端负责把 Steam、微信、自建匹配服、LAN 发现或其他平台能力映射到 GF lobby
## 事件与请求报告。该基类不执行任何平台调用。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFNetworkLobbyBackend
extends RefCounted


# --- 信号 ---

## Lobby 创建完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 创建结果。
signal lobby_created(result: GFNetworkLobbyJoinResult)

## Lobby 查询完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobbies: Lobby 快照列表。
## [br]
## @param metadata: 查询元数据。
## [br]
## @schema lobbies: Array[GFNetworkLobbyDescriptor] lobby snapshots.
## [br]
## @schema metadata: Dictionary query metadata.
signal lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary)

## Lobby 加入完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 加入结果。
signal lobby_joined(result: GFNetworkLobbyJoinResult)

## 离开 lobby 后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param reason: 离开原因。
signal lobby_left(lobby_id: String, reason: String)

## Lobby 快照更新后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby: Lobby 快照。
signal lobby_updated(lobby: GFNetworkLobbyDescriptor)

## 成员加入后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param member: 成员快照。
signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)

## 成员离开后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param peer_id: 成员 peer 标识。
## [br]
## @param reason: 离开原因。
signal member_left(lobby_id: String, peer_id: int, reason: String)

## 收到 lobby 邀请后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param invite: 邀请事件。
signal invite_received(invite: GFNetworkLobbyInvite)

## 后端操作失败后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param operation: 操作标识。
## [br]
## @param error: 错误标识。
## [br]
## @param details: 错误详情。
## [br]
## @schema details: Dictionary backend-defined error metadata.
signal backend_error(operation: StringName, error: StringName, details: Dictionary)


# --- 公共变量 ---

## 后端稳定标识。
## [br]
## @api public
## [br]
## @since 8.0.0
var backend_id: StringName = &""


# --- 公共方法 ---

## 创建 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。异步后端应先返回 accepted，再通过信号发出最终结果。
## [br]
## @schema _options: Dictionary backend-defined create options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func create_lobby(_options: Dictionary = {}) -> Dictionary:
	return _make_request_report(false, &"create_lobby", &"unavailable")


## 查询 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _query: 查询条件。
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema _options: Dictionary backend-defined query options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func query_lobbies(_query: GFNetworkLobbyQuery = null, _options: Dictionary = {}) -> Dictionary:
	return _make_request_report(false, &"query_lobbies", &"unavailable")


## 加入 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _lobby_id: Lobby ID。
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema _options: Dictionary backend-defined join options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func join_lobby(_lobby_id: String, _options: Dictionary = {}) -> Dictionary:
	return _make_request_report(false, &"join_lobby", &"unavailable")


## 离开 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _lobby_id: Lobby ID；为空时后端可使用当前 lobby。
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema _options: Dictionary backend-defined leave options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func leave_lobby(_lobby_id: String = "", _options: Dictionary = {}) -> Dictionary:
	return _make_request_report(false, &"leave_lobby", &"unavailable")


## 设置 lobby metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _lobby_id: Lobby ID。
## [br]
## @param _metadata: Metadata 更新。
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema _metadata: Dictionary lobby metadata patch.
## [br]
## @schema _options: Dictionary backend-defined metadata options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func set_lobby_metadata(_lobby_id: String, _metadata: Dictionary, _options: Dictionary = {}) -> Dictionary:
	return _make_request_report(false, &"set_lobby_metadata", &"unavailable")


## 设置成员 metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _lobby_id: Lobby ID。
## [br]
## @param _peer_id: 成员 peer 标识。
## [br]
## @param _metadata: Metadata 更新。
## [br]
## @param _options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema _metadata: Dictionary member metadata patch.
## [br]
## @schema _options: Dictionary backend-defined metadata options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func set_member_metadata(
	_lobby_id: String,
	_peer_id: int,
	_metadata: Dictionary,
	_options: Dictionary = {}
) -> Dictionary:
	return _make_request_report(false, &"set_member_metadata", &"unavailable")


## 后端轮询入口。需要平台 callback pump 的后端可重写。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _delta: 帧间隔。
func poll(_delta: float) -> void:
	pass


## 关闭后端资源。
## [br]
## @api public
## [br]
## @since 8.0.0
func close() -> void:
	pass


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary backend debug snapshot.
func get_debug_snapshot() -> Dictionary:
	return {
		"backend_id": backend_id,
		"backend": get_script().resource_path if get_script() != null else "",
		"available": false,
	}


# --- 可重写钩子 / 虚方法 ---

## 构建请求报告。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param ok: 请求是否被接受。
## [br]
## @param operation: 操作标识。
## [br]
## @param error: 错误标识。
## [br]
## @param options: 附加字段。
## [br]
## @schema options: Dictionary request report fields.
## [br]
## @return 请求报告。
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func _make_request_report(
	ok: bool,
	operation: StringName,
	error: StringName = &"",
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = options.duplicate(true)
	report["ok"] = ok
	report["status"] = GFVariantData.get_option_string_name(options, "status", &"accepted" if ok else &"failed")
	report["operation"] = operation
	report["request_id"] = GFVariantData.get_option_string(options, "request_id")
	report["error"] = error
	return report


## 发出 lobby_created 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param result: 创建结果。
func _emit_lobby_created(result: GFNetworkLobbyJoinResult) -> void:
	lobby_created.emit(result)


## 发出 lobbies_queried 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobbies: Lobby 快照列表。
## [br]
## @param metadata: 查询元数据。
## [br]
## @schema lobbies: Array[GFNetworkLobbyDescriptor] lobby snapshots.
## [br]
## @schema metadata: Dictionary query metadata.
func _emit_lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary = {}) -> void:
	lobbies_queried.emit(_copy_lobbies(lobbies), metadata.duplicate(true))


## 发出 lobby_joined 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param result: 加入结果。
func _emit_lobby_joined(result: GFNetworkLobbyJoinResult) -> void:
	lobby_joined.emit(result)


## 发出 lobby_left 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param reason: 离开原因。
func _emit_lobby_left(lobby_id: String, reason: String = "left") -> void:
	lobby_left.emit(lobby_id, reason)


## 发出 lobby_updated 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby: Lobby 快照。
func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
	lobby_updated.emit(lobby.duplicate_lobby() if lobby != null else null)


## 发出 member_joined 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param member: 成员快照。
func _emit_member_joined(lobby_id: String, member: GFNetworkLobbyMember) -> void:
	member_joined.emit(lobby_id, member.duplicate_member() if member != null else null)


## 发出 member_left 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param peer_id: 成员 peer 标识。
## [br]
## @param reason: 离开原因。
func _emit_member_left(lobby_id: String, peer_id: int, reason: String = "left") -> void:
	member_left.emit(lobby_id, peer_id, reason)


## 发出 invite_received 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param invite: 邀请事件。
func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:
	invite_received.emit(invite.duplicate_invite() if invite != null else null)


## 发出 backend_error 信号。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param operation: 操作标识。
## [br]
## @param error: 错误标识。
## [br]
## @param details: 错误详情。
## [br]
## @schema details: Dictionary backend-defined error metadata.
func _emit_backend_error(operation: StringName, error: StringName, details: Dictionary = {}) -> void:
	backend_error.emit(operation, error, details.duplicate(true))


# --- 私有/辅助方法 ---

func _copy_lobbies(source_lobbies: Array[GFNetworkLobbyDescriptor]) -> Array[GFNetworkLobbyDescriptor]:
	var result: Array[GFNetworkLobbyDescriptor] = []
	for lobby: GFNetworkLobbyDescriptor in source_lobbies:
		if lobby != null:
			result.append(lobby.duplicate_lobby())
	return result
