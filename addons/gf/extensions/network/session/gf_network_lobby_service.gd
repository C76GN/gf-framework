## GFNetworkLobbyService: 平台中立 lobby 协调服务。
##
## 该服务只管理 backend 请求、当前 lobby 快照和信号转发。Steam、微信、LAN 或自建服务
## 的具体 API 必须由外部或可选 adapter 通过 GFNetworkLobbyBackend 实现。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFNetworkLobbyService
extends GFUtility


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

## 当前 lobby 后端。
## [br]
## @api public
## [br]
## @since 8.0.0
var backend: GFNetworkLobbyBackend = null

## 当前已加入 lobby。未加入时为 null。
## [br]
## @api public
## [br]
## @since 8.0.0
var current_lobby: GFNetworkLobbyDescriptor = null


# --- 私有变量 ---

var _known_lobbies: Dictionary = {}


# --- GF 生命周期方法 ---

## 推进 lobby 后端轮询。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if backend != null:
		backend.poll(delta)


## 关闭后端并清理 lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	set_backend(null)
	current_lobby = null
	_known_lobbies.clear()


# --- 公共方法 ---

## 设置 lobby 后端。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param next_backend: 新后端。
func set_backend(next_backend: GFNetworkLobbyBackend) -> void:
	if backend == next_backend:
		return
	if backend != null:
		_disconnect_backend_signals(backend)
		backend.close()
	backend = next_backend
	if backend != null:
		_connect_backend_signals(backend)


## 创建 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema options: Dictionary backend-defined create options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func create_lobby(options: Dictionary = {}) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"create_lobby")
	return backend.create_lobby(options)


## 查询 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param query: 查询条件。
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema options: Dictionary backend-defined query options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func query_lobbies(query: GFNetworkLobbyQuery = null, options: Dictionary = {}) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"query_lobbies")
	return backend.query_lobbies(query, options)


## 加入 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema options: Dictionary backend-defined join options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func join_lobby(lobby_id: String, options: Dictionary = {}) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"join_lobby")
	return backend.join_lobby(lobby_id, options)


## 离开 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema options: Dictionary backend-defined leave options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func leave_lobby(lobby_id: String = "", options: Dictionary = {}) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"leave_lobby")
	var resolved_lobby_id: String = lobby_id.strip_edges()
	if resolved_lobby_id.is_empty() and current_lobby != null:
		resolved_lobby_id = current_lobby.lobby_id
	return backend.leave_lobby(resolved_lobby_id, options)


## 设置当前或指定 lobby metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param metadata_patch: Metadata 更新。
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema metadata_patch: Dictionary lobby metadata patch.
## [br]
## @schema options: Dictionary backend-defined metadata options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func set_lobby_metadata(
	metadata_patch: Dictionary,
	lobby_id: String = "",
	options: Dictionary = {}
) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"set_lobby_metadata")
	var resolved_lobby_id: String = _resolve_lobby_id(lobby_id)
	if resolved_lobby_id.is_empty():
		return _make_request_report(false, &"set_lobby_metadata", &"missing_lobby_id")
	return backend.set_lobby_metadata(resolved_lobby_id, metadata_patch, options)


## 设置当前或指定 lobby 的成员 metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param peer_id: 成员 peer 标识。
## [br]
## @param metadata_patch: Metadata 更新。
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: 后端选项。
## [br]
## @return 请求报告。
## [br]
## @schema metadata_patch: Dictionary member metadata patch.
## [br]
## @schema options: Dictionary backend-defined metadata options.
## [br]
## @schema return: Dictionary with ok, status, operation, request_id, and error.
func set_member_metadata(
	peer_id: int,
	metadata_patch: Dictionary,
	lobby_id: String = "",
	options: Dictionary = {}
) -> Dictionary:
	if backend == null:
		return _make_unconfigured_report(&"set_member_metadata")
	var resolved_lobby_id: String = _resolve_lobby_id(lobby_id)
	if resolved_lobby_id.is_empty():
		return _make_request_report(false, &"set_member_metadata", &"missing_lobby_id")
	return backend.set_member_metadata(resolved_lobby_id, peer_id, metadata_patch, options)


## 获取已知 lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @return Lobby 快照；不存在时返回 null。
func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
	var value: Variant = GFVariantData.get_option_value(_known_lobbies, lobby_id.strip_edges())
	if value is GFNetworkLobbyDescriptor:
		var lobby: GFNetworkLobbyDescriptor = value
		return lobby.duplicate_lobby()
	return null


## 获取全部已知 lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Lobby 快照列表。
## [br]
## @schema return: Array[GFNetworkLobbyDescriptor] known lobby snapshots.
func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:
	var result: Array[GFNetworkLobbyDescriptor] = []
	for value: Variant in _known_lobbies.values():
		if value is GFNetworkLobbyDescriptor:
			var lobby: GFNetworkLobbyDescriptor = value
			result.append(lobby.duplicate_lobby())
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with backend_configured, backend, current_lobby, and known_lobby_count.
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"backend_configured": backend != null,
		"backend": backend.get_debug_snapshot() if backend != null else {},
		"current_lobby": current_lobby.get_debug_snapshot() if current_lobby != null else {},
		"known_lobby_count": _known_lobbies.size(),
	}
	return GFNetworkDebugTools.sanitize_debug_dictionary(snapshot)


# --- 私有/辅助方法 ---

func _connect_backend_signals(target_backend: GFNetworkLobbyBackend) -> void:
	var _connect_created: Variant = target_backend.lobby_created.connect(_on_backend_lobby_created)
	var _connect_queried: Variant = target_backend.lobbies_queried.connect(_on_backend_lobbies_queried)
	var _connect_joined: Variant = target_backend.lobby_joined.connect(_on_backend_lobby_joined)
	var _connect_left: Variant = target_backend.lobby_left.connect(_on_backend_lobby_left)
	var _connect_updated: Variant = target_backend.lobby_updated.connect(_on_backend_lobby_updated)
	var _connect_member_joined: Variant = target_backend.member_joined.connect(_on_backend_member_joined)
	var _connect_member_left: Variant = target_backend.member_left.connect(_on_backend_member_left)
	var _connect_invite: Variant = target_backend.invite_received.connect(_on_backend_invite_received)
	var _connect_error: Variant = target_backend.backend_error.connect(_on_backend_error)


func _disconnect_backend_signals(target_backend: GFNetworkLobbyBackend) -> void:
	if target_backend.lobby_created.is_connected(_on_backend_lobby_created):
		target_backend.lobby_created.disconnect(_on_backend_lobby_created)
	if target_backend.lobbies_queried.is_connected(_on_backend_lobbies_queried):
		target_backend.lobbies_queried.disconnect(_on_backend_lobbies_queried)
	if target_backend.lobby_joined.is_connected(_on_backend_lobby_joined):
		target_backend.lobby_joined.disconnect(_on_backend_lobby_joined)
	if target_backend.lobby_left.is_connected(_on_backend_lobby_left):
		target_backend.lobby_left.disconnect(_on_backend_lobby_left)
	if target_backend.lobby_updated.is_connected(_on_backend_lobby_updated):
		target_backend.lobby_updated.disconnect(_on_backend_lobby_updated)
	if target_backend.member_joined.is_connected(_on_backend_member_joined):
		target_backend.member_joined.disconnect(_on_backend_member_joined)
	if target_backend.member_left.is_connected(_on_backend_member_left):
		target_backend.member_left.disconnect(_on_backend_member_left)
	if target_backend.invite_received.is_connected(_on_backend_invite_received):
		target_backend.invite_received.disconnect(_on_backend_invite_received)
	if target_backend.backend_error.is_connected(_on_backend_error):
		target_backend.backend_error.disconnect(_on_backend_error)


func _on_backend_lobby_created(result: GFNetworkLobbyJoinResult) -> void:
	var copy: GFNetworkLobbyJoinResult = _copy_result(result)
	if copy != null and copy.ok and copy.lobby != null:
		_store_lobby(copy.lobby)
		current_lobby = copy.lobby.duplicate_lobby()
	lobby_created.emit(copy)


func _on_backend_lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary) -> void:
	var copies: Array[GFNetworkLobbyDescriptor] = []
	for lobby: GFNetworkLobbyDescriptor in lobbies:
		if lobby == null:
			continue
		var copy: GFNetworkLobbyDescriptor = lobby.duplicate_lobby()
		_store_lobby(copy)
		copies.append(copy)
	lobbies_queried.emit(copies, metadata.duplicate(true))


func _on_backend_lobby_joined(result: GFNetworkLobbyJoinResult) -> void:
	var copy: GFNetworkLobbyJoinResult = _copy_result(result)
	if copy != null and copy.ok and copy.lobby != null:
		_store_lobby(copy.lobby)
		current_lobby = copy.lobby.duplicate_lobby()
	lobby_joined.emit(copy)


func _on_backend_lobby_left(lobby_id: String, reason: String) -> void:
	if current_lobby != null and current_lobby.lobby_id == lobby_id:
		current_lobby = null
	lobby_left.emit(lobby_id, reason)


func _on_backend_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
	if lobby != null:
		_store_lobby(lobby)
		if current_lobby != null and current_lobby.lobby_id == lobby.lobby_id:
			current_lobby = lobby.duplicate_lobby()
	lobby_updated.emit(lobby.duplicate_lobby() if lobby != null else null)


func _on_backend_member_joined(lobby_id: String, member: GFNetworkLobbyMember) -> void:
	var lobby: GFNetworkLobbyDescriptor = _get_stored_lobby(lobby_id)
	if lobby != null and member != null:
		lobby.set_member(member)
		_store_lobby(lobby)
		if current_lobby != null and current_lobby.lobby_id == lobby_id:
			current_lobby = lobby.duplicate_lobby()
	member_joined.emit(lobby_id, member.duplicate_member() if member != null else null)


func _on_backend_member_left(lobby_id: String, peer_id: int, reason: String) -> void:
	var lobby: GFNetworkLobbyDescriptor = _get_stored_lobby(lobby_id)
	if lobby != null:
		var _removed: bool = lobby.remove_member(peer_id)
		_store_lobby(lobby)
		if current_lobby != null and current_lobby.lobby_id == lobby_id:
			current_lobby = lobby.duplicate_lobby()
	member_left.emit(lobby_id, peer_id, reason)


func _on_backend_invite_received(invite: GFNetworkLobbyInvite) -> void:
	invite_received.emit(invite.duplicate_invite() if invite != null else null)


func _on_backend_error(operation: StringName, error: StringName, details: Dictionary) -> void:
	backend_error.emit(operation, error, details.duplicate(true))


func _store_lobby(lobby: GFNetworkLobbyDescriptor) -> void:
	if lobby == null or lobby.lobby_id.strip_edges().is_empty():
		return
	_known_lobbies[lobby.lobby_id] = lobby.duplicate_lobby()


func _get_stored_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
	var value: Variant = GFVariantData.get_option_value(_known_lobbies, lobby_id.strip_edges())
	if value is GFNetworkLobbyDescriptor:
		var lobby: GFNetworkLobbyDescriptor = value
		return lobby.duplicate_lobby()
	return null


func _resolve_lobby_id(lobby_id: String) -> String:
	var resolved: String = lobby_id.strip_edges()
	if resolved.is_empty() and current_lobby != null:
		resolved = current_lobby.lobby_id
	return resolved


func _copy_result(result: GFNetworkLobbyJoinResult) -> GFNetworkLobbyJoinResult:
	return result.duplicate_result() if result != null else null


func _make_unconfigured_report(operation: StringName) -> Dictionary:
	return _make_request_report(false, operation, &"backend_unconfigured")


func _make_request_report(operation_ok: bool, operation: StringName, error: StringName = &"") -> Dictionary:
	return {
		"ok": operation_ok,
		"status": &"accepted" if operation_ok else &"failed",
		"operation": operation,
		"request_id": "",
		"error": error,
	}
