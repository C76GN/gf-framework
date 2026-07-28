## GFNetworkLobbyBackend: 平台中立 Lobby 后端协议。
##
## 后端只负责把 Steam、小游戏、自建匹配服、LAN 或其他 provider 的异步调用
## 映射到强类型操作句柄。请求 ID、单终态、取消和迟到回调保护由基类统一拥有。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFNetworkLobbyBackend
extends RefCounted


# --- 信号 ---

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

## 后端出现不属于具体请求的错误时发出。
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

## 后端稳定标识。
## [br]
## @api public
## [br]
## @since 8.0.0
var backend_id: StringName = &""


# --- 私有变量 ---

var _clock: GFClock = GFClock.new()
var _active_handles: Dictionary = {}
var _closed: bool = false
var _ignored_terminal_count: int = 0


# --- 公共方法 ---

## 提交 Lobby 操作。
##
## 外部 Adapter 不得重写该入口，只实现 `_dispatch_operation`。基类会在调用
## provider 前建立取消与完成监听，保证同步回调也不会逃逸生命周期管理。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param request: 完整操作请求。
## [br]
## @return 一次性操作句柄；输入和派发失败也返回终态句柄。
func invoke_operation(
	request: GFNetworkLobbyOperationRequest
) -> GFNetworkLobbyOperationHandle:
	return invoke_from_service(request, -1)


## 推进需要 callback pump 的平台 SDK。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta: 未缩放帧间隔。
func poll(delta: float) -> void:
	if not _closed:
		_poll(maxf(delta, 0.0))


## 取消全部等待操作并关闭 provider 资源。
## [br]
## @api public
## [br]
## @since 8.0.0
func close() -> void:
	if _closed:
		return
	_closed = true
	for request_key: Variant in _active_handles.keys().duplicate():
		var handle: GFNetworkLobbyOperationHandle = _get_active_handle(
			StringName(str(request_key))
		)
		if handle != null:
			var _cancelled: bool = handle.cancel(&"backend_closed")
	_close()
	_active_handles.clear()


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 不包含请求载荷的后端摘要。
## [br]
## @schema return: Dictionary lobby backend debug snapshot.
func get_debug_snapshot() -> Dictionary:
	return {
		"backend_id": backend_id,
		"backend": get_script().resource_path if get_script() != null else "",
		"closed": _closed,
		"active_operation_count": _active_handles.size(),
		"ignored_terminal_count": _ignored_terminal_count,
	}


# --- 可重写钩子 / 虚方法 ---

## 派发 provider 操作。
##
## 实现应保存 request_id 与底层调用的关联，并在回调中调用 `_succeed_operation`
## 或 `_fail_operation`。返回 false 表示请求未被接受。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _request: 请求副本。
## [br]
## @param _handle: 由基类拥有的操作句柄。
## [br]
## @return 请求被 provider 接受时返回 true。
func _dispatch_operation(
	_request: GFNetworkLobbyOperationRequest,
	_handle: GFNetworkLobbyOperationHandle
) -> bool:
	return false


## 处理取消或超时通知。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _handle: 已进入取消或超时终态的句柄。
## [br]
## @param _reason: 取消原因。
func _cancel_operation(
	_handle: GFNetworkLobbyOperationHandle,
	_reason: StringName
) -> void:
	pass


## 确认底层 Provider 操作已经停止并释放请求租约。
##
## Handle 本地取消或超时不会提前释放 request_id。Backend 应在 Provider 确认
## 取消后调用本方法；迟到成功或失败回调会自动释放。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param handle: 底层工作已经停止的操作句柄。
## [br]
## @return 当前 Backend 仍持有该租约并已释放时返回 true。
func _release_operation(handle: GFNetworkLobbyOperationHandle) -> bool:
	if handle == null:
		return false
	var active_handle: GFNetworkLobbyOperationHandle = _get_active_handle(
		handle.get_request_id()
	)
	if active_handle != handle:
		return false
	return _active_handles.erase(String(handle.get_request_id()))


## 推进底层 callback pump。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _delta: 未缩放帧间隔。
func _poll(_delta: float) -> void:
	pass


## 释放底层 provider 资源。
## [br]
## @api protected
## [br]
## @since 10.0.0
func _close() -> void:
	pass


## 成功完成操作。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param handle: 待完成句柄。
## [br]
## @param options: 可包含 status、lobby、lobbies、lobby_id 和 metadata。
## [br]
## @schema options: Dictionary successful lobby operation fields.
## [br]
## @return 首次完成成功返回 true；迟到或重复回调返回 false。
func _succeed_operation(
	handle: GFNetworkLobbyOperationHandle,
	options: Dictionary = {}
) -> bool:
	var completed: bool = (
		handle != null
		and handle.succeed_from_network_layer(options)
	)
	var _released: bool = _release_operation(handle)
	if completed:
		return true
	_ignored_terminal_count += 1
	return false


## 失败完成操作。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param handle: 待完成句柄。
## [br]
## @param error: 稳定失败原因。
## [br]
## @param message: 人读说明。
## [br]
## @param metadata: 已脱敏失败元数据。
## [br]
## @schema metadata: Dictionary backend-defined failure metadata.
## [br]
## @return 首次完成成功返回 true；迟到或重复回调返回 false。
func _fail_operation(
	handle: GFNetworkLobbyOperationHandle,
	error: StringName,
	message: String = "",
	metadata: Dictionary = {}
) -> bool:
	var completed: bool = (
		handle != null
		and handle.fail_from_network_layer(error, message, metadata)
	)
	var _released: bool = _release_operation(handle)
	if completed:
		return true
	_ignored_terminal_count += 1
	return false


## 发出 Lobby 更新事件。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby: Lobby 快照。
func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
	lobby_updated.emit(lobby.duplicate_lobby() if lobby != null else null)


## 发出成员加入事件。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param member: 成员快照。
func _emit_member_joined(
	lobby_id: String,
	member: GFNetworkLobbyMember
) -> void:
	member_joined.emit(
		lobby_id.strip_edges(),
		member.duplicate_member() if member != null else null
	)


## 发出成员离开事件。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param lobby_id: Lobby ID。
## [br]
## @param peer_id: 成员 peer ID。
## [br]
## @param reason: 离开原因。
func _emit_member_left(
	lobby_id: String,
	peer_id: int,
	reason: String = "left"
) -> void:
	member_left.emit(lobby_id.strip_edges(), peer_id, reason.strip_edges())


## 发出邀请事件。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param invite: 邀请事件。
func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:
	invite_received.emit(invite.duplicate_invite() if invite != null else null)


## 发出非请求错误事件。
## [br]
## @api protected
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
func _emit_backend_error(
	operation: StringName,
	error: StringName,
	details: Dictionary = {}
) -> void:
	backend_error.emit(operation, error, details.duplicate(true))


# --- 层内方法 ---

## 使用 Service 已捕获的单调起始时间提交 Lobby 操作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since 10.0.0
## [br]
## @param request: 完整操作请求。
## [br]
## @param started_at_msec: Service 在开始信号前捕获的同时钟域起始时间。
## [br]
## @return 一次性操作句柄。
func invoke_from_service(
	request: GFNetworkLobbyOperationRequest,
	started_at_msec: int
) -> GFNetworkLobbyOperationHandle:
	var handle: GFNetworkLobbyOperationHandle = GFNetworkLobbyOperationHandle.new()
	if request == null or not request.is_valid():
		var _invalid: bool = handle.reject_from_network_layer(
			request,
			&"invalid_request",
			"Lobby operation request is incomplete.",
			_clock
		)
		return handle
	if _closed:
		var _closed_rejection: bool = handle.reject_from_network_layer(
			request,
			&"backend_closed",
			"Lobby backend is closed.",
			_clock
		)
		return handle
	if _active_handles.has(String(request.request_id)):
		var _duplicate: bool = handle.reject_from_network_layer(
			request,
			&"duplicate_request_id",
			"Lobby request ID is already pending.",
			_clock
		)
		return handle
	if not handle.configure_from_network_layer(request, _clock, started_at_msec):
		var _configuration_failed: bool = handle.reject_from_network_layer(
			request,
			&"invalid_request",
			"Lobby operation request could not initialize a handle.",
			_clock
		)
		return handle
	_active_handles[String(request.request_id)] = handle
	var cancel_callback: Callable = _on_handle_cancel_requested.bind(handle)
	var _cancel_connected: Error = handle.cancel_requested.connect(
		cancel_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var accepted: bool = _dispatch_operation(request.duplicate_request(), handle)
	if not accepted and handle.is_pending():
		var _dispatch_rejected: bool = _fail_operation(
			handle,
			&"dispatch_rejected",
			"Lobby backend rejected the operation."
		)
	return handle


## 注入 Lobby Service 的统一单调时钟。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since 10.0.0
## [br]
## @param clock: 新时钟。
## [br]
## @return 时钟有效且没有活跃 Provider 租约时返回 true。
func set_service_clock(clock: GFClock) -> bool:
	if clock == null or not _active_handles.is_empty():
		return false
	_clock = clock
	return true


# --- 私有/辅助方法 ---

func _get_active_handle(
	request_id: StringName
) -> GFNetworkLobbyOperationHandle:
	var value: Variant = GFVariantData.get_option_value(
		_active_handles,
		String(request_id)
	)
	if value is GFNetworkLobbyOperationHandle:
		var handle: GFNetworkLobbyOperationHandle = value
		return handle
	return null


func _on_handle_cancel_requested(
	reason: StringName,
	handle: GFNetworkLobbyOperationHandle
) -> void:
	_cancel_operation(handle, reason)
