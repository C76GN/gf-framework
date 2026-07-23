## GFNetworkLobbyService: 平台中立 Lobby 操作协调服务。
##
## Service 统一生成请求 ID、管理单调超时、取消 Backend 替换时的等待操作，并维护
## Lobby 快照。Steam、小游戏、LAN 或自建服务 API 只能存在于外部 Backend Adapter。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFNetworkLobbyService
extends GFUtility


# --- 信号 ---

## 操作提交给 Backend 前发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 请求副本。
signal operation_started(request: GFNetworkLobbyOperationRequest)

## 任意 Lobby 操作进入终态后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 终态结果副本。
signal operation_completed(result: GFNetworkLobbyOperationResult)

## 创建 Lobby 操作完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 创建操作终态。
signal lobby_created(result: GFNetworkLobbyOperationResult)

## 查询 Lobby 操作完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 查询操作终态。
signal lobbies_queried(result: GFNetworkLobbyOperationResult)

## 加入 Lobby 操作完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 加入操作终态。
signal lobby_joined(result: GFNetworkLobbyOperationResult)

## 离开 Lobby 操作完成后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 离开操作终态。
signal lobby_left(result: GFNetworkLobbyOperationResult)

## Lobby metadata 操作完成后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: Metadata 操作终态。
signal lobby_metadata_set(result: GFNetworkLobbyOperationResult)

## 成员 metadata 操作完成后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: Metadata 操作终态。
signal member_metadata_set(result: GFNetworkLobbyOperationResult)

## Lobby 快照发生非请求驱动的更新后发出。
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
## @param peer_id: 成员 peer ID。
## [br]
## @param reason: 离开原因。
signal member_left(lobby_id: String, peer_id: int, reason: String)

## 收到 Lobby 邀请后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param invite: 邀请事件。
signal invite_received(invite: GFNetworkLobbyInvite)

## Backend 出现不属于具体请求的错误时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param operation: 操作标识。
## [br]
## @param error: 错误标识。
## [br]
## @param details: 已脱敏错误详情。
## [br]
## @schema details: Dictionary backend-defined error metadata.
signal backend_error(operation: StringName, error: StringName, details: Dictionary)


# --- 公共变量 ---

## 当前 Lobby Backend。
## [br]
## @api public
## [br]
## @since 8.0.0
var backend: GFNetworkLobbyBackend:
	get:
		return _backend
	set(value):
		var _accepted: bool = set_backend(value)

## 当前已加入 Lobby；未加入时为 null。
## [br]
## @api public
## [br]
## @since 8.0.0
var current_lobby: GFNetworkLobbyDescriptor = null

## 未显式传入 timeout_msec 时的操作超时；0 表示不限制。
## [br]
## @api public
## [br]
## @since unreleased
var default_timeout_msec: int = 15000


# --- 私有变量 ---

var _clock: GFClock = null
var _clock_explicit: bool = false
var _backend: GFNetworkLobbyBackend = null
var _backend_generation: int = 0
var _known_lobbies: Dictionary = {}
var _pending_operations: Dictionary = {}
var _request_serial: int = 0


# --- Godot 生命周期方法 ---

func _init(clock: GFClock = null) -> void:
	_clock = clock if clock != null else GFClock.new()
	_clock_explicit = clock != null
	tick_enabled = true
	ignore_pause = true
	ignore_time_scale = true


# --- GF 生命周期方法 ---

## 在架构中自动采用已注册 GFTimeProvider 的底层时钟。
## [br]
## @api public
## [br]
## @since unreleased
func ready() -> void:
	if _clock_explicit:
		return
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	var provider_value: Variant = architecture.get_utility(GFTimeProvider)
	if provider_value is GFTimeProvider:
		var provider: GFTimeProvider = provider_value
		var _clock_applied: bool = _apply_clock(provider.get_clock(), false)


## 推进 Backend callback pump 并处理操作超时。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta: 引擎原始帧间隔。
func tick(delta: float) -> void:
	_expire_operations(_clock.get_monotonic_msec())
	if _backend != null:
		_backend.poll(delta)
	_expire_operations(_clock.get_monotonic_msec())


## 取消全部操作、关闭 Backend 并清理快照。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	_cancel_pending_operations(&"service_disposed")
	var _backend_cleared: bool = set_backend(null)
	current_lobby = null
	_known_lobbies.clear()
	_pending_operations.clear()


# --- 公共方法 ---

## 设置 Lobby Backend。
##
## 替换前会先取消旧 Backend 的全部等待操作，再断开事件并关闭旧资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param next_backend: 新 Backend；null 表示清除。
## [br]
## @return Backend 可采用当前时钟并已设置时返回 true。
func set_backend(next_backend: GFNetworkLobbyBackend) -> bool:
	if _backend == next_backend:
		return true
	if next_backend != null and not next_backend.set_service_clock(_clock):
		return false
	_cancel_pending_operations(&"backend_replaced")
	if _backend != null:
		_disconnect_backend_signals(_backend)
		_backend.close()
	_backend = next_backend
	_backend_generation += 1
	current_lobby = null
	_known_lobbies.clear()
	if _backend != null:
		_connect_backend_signals(_backend)
	return true


## 设置操作超时和耗时使用的统一单调时钟。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param clock: 新时钟。
## [br]
## @return 时钟有效且当前没有等待操作时返回 true。
func set_clock(clock: GFClock) -> bool:
	return _apply_clock(clock, true)


## 获取当前时钟。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前时钟。
func get_clock() -> GFClock:
	return _clock


## 创建 Lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema options: Dictionary lobby create options.
## [br]
## @return 一次性操作句柄。
func create_lobby(options: Dictionary = {}) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY,
		options
	))


## 查询 Lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param query: 查询条件。
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema options: Dictionary lobby query options.
## [br]
## @return 一次性操作句柄。
func query_lobbies(
	query: GFNetworkLobbyQuery = null,
	options: Dictionary = {}
) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES,
		options,
		{"query": query}
	))


## 加入 Lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema options: Dictionary lobby join options.
## [br]
## @return 一次性操作句柄。
func join_lobby(
	lobby_id: String,
	options: Dictionary = {}
) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY,
		options,
		{"lobby_id": lobby_id.strip_edges()}
	))


## 离开当前或指定 Lobby。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema options: Dictionary lobby leave options.
## [br]
## @return 一次性操作句柄。
func leave_lobby(
	lobby_id: String = "",
	options: Dictionary = {}
) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_LEAVE_LOBBY,
		options,
		{"lobby_id": _resolve_lobby_id(lobby_id)}
	))


## 更新当前或指定 Lobby metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param metadata_patch: Metadata patch。
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema metadata_patch: Dictionary lobby metadata patch.
## [br]
## @schema options: Dictionary lobby metadata options.
## [br]
## @return 一次性操作句柄。
func set_lobby_metadata(
	metadata_patch: Dictionary,
	lobby_id: String = "",
	options: Dictionary = {}
) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_SET_LOBBY_METADATA,
		options,
		{
			"lobby_id": _resolve_lobby_id(lobby_id),
			"payload": metadata_patch,
		}
	))


## 更新当前或指定 Lobby 的成员 metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param peer_id: 成员 peer ID。
## [br]
## @param metadata_patch: Metadata patch。
## [br]
## @param lobby_id: Lobby ID；为空时使用 current_lobby。
## [br]
## @param options: Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。
## [br]
## @schema metadata_patch: Dictionary member metadata patch.
## [br]
## @schema options: Dictionary member metadata options.
## [br]
## @return 一次性操作句柄。
func set_member_metadata(
	peer_id: int,
	metadata_patch: Dictionary,
	lobby_id: String = "",
	options: Dictionary = {}
) -> GFNetworkLobbyOperationHandle:
	return invoke_operation(_make_request(
		GFNetworkLobbyOperationRequest.OP_SET_MEMBER_METADATA,
		options,
		{
			"lobby_id": _resolve_lobby_id(lobby_id),
			"peer_id": peer_id,
			"payload": metadata_patch,
		}
	))


## 提交完整 Lobby 操作请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 完整请求。
## [br]
## @return 一次性操作句柄。
func invoke_operation(
	request: GFNetworkLobbyOperationRequest
) -> GFNetworkLobbyOperationHandle:
	if request == null or not request.is_valid():
		var invalid_handle: GFNetworkLobbyOperationHandle = _make_rejected_handle(
			request,
			&"invalid_request",
			"Lobby operation request is incomplete."
		)
		_finalize_handle(invalid_handle)
		return invalid_handle
	var request_key: String = String(request.request_id)
	if _pending_operations.has(request_key):
		var duplicate_handle: GFNetworkLobbyOperationHandle = _make_rejected_handle(
			request,
			&"duplicate_request_id",
			"Lobby request ID is already pending."
		)
		_finalize_handle(duplicate_handle)
		return duplicate_handle
	var target_backend: GFNetworkLobbyBackend = _backend
	if target_backend == null:
		var missing_handle: GFNetworkLobbyOperationHandle = _make_rejected_handle(
			request,
			&"backend_unconfigured",
			"Lobby backend is not configured."
		)
		_finalize_handle(missing_handle)
		return missing_handle
	var effective_request: GFNetworkLobbyOperationRequest = request.duplicate_request()
	var timeout_msec: int = (
		effective_request.timeout_msec
		if effective_request.timeout_msec > 0
		else maxi(default_timeout_msec, 0)
	)
	effective_request.timeout_msec = timeout_msec
	var started_at_msec: int = _clock.get_monotonic_msec()
	var deadline_msec: int = (
		started_at_msec + timeout_msec
		if timeout_msec > 0
		else -1
	)
	var target_generation: int = _backend_generation
	_pending_operations[request_key] = {
		"backend_generation": target_generation,
		"deadline_msec": deadline_msec,
		"handle": null,
		"reserved": true,
	}
	operation_started.emit(effective_request.duplicate_request())
	if target_backend != _backend or target_generation != _backend_generation:
		var _reservation_erased: bool = _pending_operations.erase(request_key)
		var replaced_handle: GFNetworkLobbyOperationHandle = _make_rejected_handle(
			effective_request,
			&"backend_replaced_before_dispatch",
			"Lobby backend changed while the operation was starting."
		)
		_finalize_handle(replaced_handle)
		return replaced_handle
	var handle: GFNetworkLobbyOperationHandle = target_backend.invoke_from_service(
		effective_request,
		started_at_msec
	)
	if not handle.is_pending():
		var _completed_reservation_erased: bool = _pending_operations.erase(request_key)
		_finalize_handle(handle)
		return handle
	_pending_operations[request_key] = {
		"backend_generation": target_generation,
		"deadline_msec": deadline_msec,
		"handle": handle,
		"reserved": false,
	}
	var completed_callback: Callable = _on_operation_completed.bind(effective_request.request_id)
	var connect_error: Error = handle.completed.connect(
		completed_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		var _tracking_failed: bool = handle.cancel(&"signal_connection_failed")
		var _erased: bool = _pending_operations.erase(request_key)
		_finalize_handle(handle)
	elif deadline_msec >= 0 and _clock.get_monotonic_msec() >= deadline_msec:
		var _expired_before_return: bool = handle.timeout_from_network_layer()
	return handle


## 取消等待中的操作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request_id: 请求 ID。
## [br]
## @param reason: 取消原因。
## [br]
## @return 找到并首次取消返回 true。
func cancel_operation(
	request_id: StringName,
	reason: StringName = &"cancelled"
) -> bool:
	var handle: GFNetworkLobbyOperationHandle = _get_pending_handle(request_id)
	return handle != null and handle.cancel(reason)


## 获取已知 Lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @return 找到时返回快照副本，否则返回 null。
func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
	return _get_stored_lobby(lobby_id)


## 获取全部已知 Lobby 快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 按 Lobby ID 排序的快照副本。
## [br]
## @schema return: Array[GFNetworkLobbyDescriptor] known lobby snapshots.
func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:
	var lobby_ids: PackedStringArray = PackedStringArray()
	for key: Variant in _known_lobbies.keys():
		var _appended: bool = lobby_ids.append(str(key))
	lobby_ids.sort()
	var result: Array[GFNetworkLobbyDescriptor] = []
	for lobby_id: String in lobby_ids:
		var lobby: GFNetworkLobbyDescriptor = _get_stored_lobby(lobby_id)
		if lobby != null:
			result.append(lobby)
	return result


## 获取 Service 调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 不包含 provider 选项和 metadata 的摘要。
## [br]
## @schema return: Dictionary lobby service debug snapshot.
func get_debug_snapshot() -> Dictionary:
	return {
		"backend_configured": _backend != null,
		"backend": _backend.get_debug_snapshot() if _backend != null else {},
		"backend_generation": _backend_generation,
		"current_lobby_id": current_lobby.lobby_id if current_lobby != null else "",
		"known_lobby_count": _known_lobbies.size(),
		"pending_operation_count": _pending_operations.size(),
		"default_timeout_msec": default_timeout_msec,
	}


# --- 私有/辅助方法 ---

func _make_request(
	operation: StringName,
	options: Dictionary,
	fields: Dictionary = {}
) -> GFNetworkLobbyOperationRequest:
	var request_id: StringName = GFVariantData.get_option_string_name(options, "request_id")
	if request_id == &"":
		_request_serial += 1
		request_id = StringName("gf_lobby_%d" % _request_serial)
	var provider_options: Dictionary = options.duplicate(true)
	var _request_id_erased: bool = provider_options.erase("request_id")
	var _timeout_erased: bool = provider_options.erase("timeout_msec")
	var _metadata_erased: bool = provider_options.erase("metadata")
	var request_options: Dictionary = fields.duplicate(true)
	request_options["provider_options"] = provider_options
	request_options["timeout_msec"] = GFVariantData.get_option_int(options, "timeout_msec")
	request_options["metadata"] = GFVariantData.get_option_dictionary(options, "metadata")
	return GFNetworkLobbyOperationRequest.new().configure(
		request_id,
		operation,
		request_options
	)


func _make_rejected_handle(
	request: GFNetworkLobbyOperationRequest,
	status: StringName,
	message: String
) -> GFNetworkLobbyOperationHandle:
	var handle: GFNetworkLobbyOperationHandle = GFNetworkLobbyOperationHandle.new()
	var _rejected: bool = handle.reject_from_network_layer(
		request,
		status,
		message,
		_clock
	)
	return handle


func _connect_backend_signals(target_backend: GFNetworkLobbyBackend) -> void:
	var _lobby_connected: Error = target_backend.lobby_updated.connect(
		_on_backend_lobby_updated
	) as Error
	var _member_joined_connected: Error = target_backend.member_joined.connect(
		_on_backend_member_joined
	) as Error
	var _member_left_connected: Error = target_backend.member_left.connect(
		_on_backend_member_left
	) as Error
	var _invite_connected: Error = target_backend.invite_received.connect(
		_on_backend_invite_received
	) as Error
	var _error_connected: Error = target_backend.backend_error.connect(
		_on_backend_error
	) as Error


func _disconnect_backend_signals(target_backend: GFNetworkLobbyBackend) -> void:
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


func _get_pending_handle(
	request_id: StringName
) -> GFNetworkLobbyOperationHandle:
	var record_value: Variant = GFVariantData.get_option_value(
		_pending_operations,
		String(request_id)
	)
	if not (record_value is Dictionary):
		return null
	var record: Dictionary = record_value
	var handle_value: Variant = GFVariantData.get_option_value(record, "handle")
	if handle_value is GFNetworkLobbyOperationHandle:
		var handle: GFNetworkLobbyOperationHandle = handle_value
		return handle
	return null


func _expire_operations(now_msec: int) -> void:
	for request_key: Variant in _pending_operations.keys().duplicate():
		var record_value: Variant = GFVariantData.get_option_value(
			_pending_operations,
			request_key
		)
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var deadline_msec: int = GFVariantData.get_option_int(record, "deadline_msec")
		if deadline_msec < 0 or now_msec < deadline_msec:
			continue
		var handle: GFNetworkLobbyOperationHandle = _get_pending_handle(
			StringName(str(request_key))
		)
		if handle != null:
			var _timed_out: bool = handle.timeout_from_network_layer()


func _cancel_pending_operations(reason: StringName) -> void:
	for request_key: Variant in _pending_operations.keys().duplicate():
		var handle: GFNetworkLobbyOperationHandle = _get_pending_handle(
			StringName(str(request_key))
		)
		if handle != null:
			var _cancelled: bool = handle.cancel(reason)


func _apply_clock(clock: GFClock, explicit: bool) -> bool:
	if clock == null or not _pending_operations.is_empty():
		return false
	if backend != null and not backend.set_service_clock(clock):
		return false
	_clock = clock
	if explicit:
		_clock_explicit = true
	return true


func _on_operation_completed(
	result: GFNetworkLobbyOperationResult,
	request_id: StringName
) -> void:
	var _erased: bool = _pending_operations.erase(String(request_id))
	_finalize_result(result)


func _finalize_handle(handle: GFNetworkLobbyOperationHandle) -> void:
	if handle == null:
		return
	var result: GFNetworkLobbyOperationResult = handle.get_result()
	if result != null:
		_finalize_result(result)


func _finalize_result(result: GFNetworkLobbyOperationResult) -> void:
	if result == null:
		return
	var copy: GFNetworkLobbyOperationResult = result.duplicate_result()
	if copy.ok:
		_apply_successful_result(copy)
	operation_completed.emit(copy.duplicate_result())
	match copy.operation:
		GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY:
			lobby_created.emit(copy.duplicate_result())
		GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES:
			lobbies_queried.emit(copy.duplicate_result())
		GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY:
			lobby_joined.emit(copy.duplicate_result())
		GFNetworkLobbyOperationRequest.OP_LEAVE_LOBBY:
			lobby_left.emit(copy.duplicate_result())
		GFNetworkLobbyOperationRequest.OP_SET_LOBBY_METADATA:
			lobby_metadata_set.emit(copy.duplicate_result())
		GFNetworkLobbyOperationRequest.OP_SET_MEMBER_METADATA:
			member_metadata_set.emit(copy.duplicate_result())


func _apply_successful_result(result: GFNetworkLobbyOperationResult) -> void:
	if result.lobby != null:
		_store_lobby(result.lobby)
	for lobby: GFNetworkLobbyDescriptor in result.lobbies:
		_store_lobby(lobby)
	match result.operation:
		GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY, GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY:
			current_lobby = result.lobby.duplicate_lobby() if result.lobby != null else null
		GFNetworkLobbyOperationRequest.OP_LEAVE_LOBBY:
			if current_lobby != null and current_lobby.lobby_id == result.lobby_id:
				current_lobby = null


func _on_backend_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
	if lobby == null:
		return
	_store_lobby(lobby)
	if current_lobby != null and current_lobby.lobby_id == lobby.lobby_id:
		current_lobby = lobby.duplicate_lobby()
	lobby_updated.emit(lobby.duplicate_lobby())


func _on_backend_member_joined(
	lobby_id: String,
	member: GFNetworkLobbyMember
) -> void:
	var lobby: GFNetworkLobbyDescriptor = _get_stored_lobby(lobby_id)
	if lobby != null and member != null:
		lobby.set_member(member)
		_store_lobby(lobby)
		if current_lobby != null and current_lobby.lobby_id == lobby_id:
			current_lobby = lobby.duplicate_lobby()
	member_joined.emit(
		lobby_id,
		member.duplicate_member() if member != null else null
	)


func _on_backend_member_left(
	lobby_id: String,
	peer_id: int,
	reason: String
) -> void:
	var lobby: GFNetworkLobbyDescriptor = _get_stored_lobby(lobby_id)
	if lobby != null:
		var _member_removed: bool = lobby.remove_member(peer_id)
		_store_lobby(lobby)
		if current_lobby != null and current_lobby.lobby_id == lobby_id:
			current_lobby = lobby.duplicate_lobby()
	member_left.emit(lobby_id, peer_id, reason)


func _on_backend_invite_received(invite: GFNetworkLobbyInvite) -> void:
	invite_received.emit(invite.duplicate_invite() if invite != null else null)


func _on_backend_error(
	operation: StringName,
	error: StringName,
	details: Dictionary
) -> void:
	backend_error.emit(operation, error, details.duplicate(true))


func _store_lobby(lobby: GFNetworkLobbyDescriptor) -> void:
	if lobby != null and not lobby.lobby_id.is_empty():
		_known_lobbies[lobby.lobby_id] = lobby.duplicate_lobby()


func _get_stored_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
	var value: Variant = GFVariantData.get_option_value(
		_known_lobbies,
		lobby_id.strip_edges()
	)
	if value is GFNetworkLobbyDescriptor:
		var lobby: GFNetworkLobbyDescriptor = value
		return lobby.duplicate_lobby()
	return null


func _resolve_lobby_id(lobby_id: String) -> String:
	var resolved_lobby_id: String = lobby_id.strip_edges()
	if resolved_lobby_id.is_empty() and current_lobby != null:
		resolved_lobby_id = current_lobby.lobby_id
	return resolved_lobby_id
