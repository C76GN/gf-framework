## GFNetworkLobbyOperationHandle: Lobby 操作运行时句柄。
##
## 句柄保证请求只能进入一个终态，并把取消、超时、Backend 失败和 SDK 回调统一为
## `GFNetworkLobbyOperationResult`。调用方不能直接完成句柄。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFNetworkLobbyOperationHandle
extends RefCounted


# --- 信号 ---

## 操作进入终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 终态结果副本。
signal completed(result: GFNetworkLobbyOperationResult)

## 操作取消或超时时发出，供 Backend 停止底层调用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 取消原因。
signal cancel_requested(reason: StringName)


# --- 私有变量 ---

var _request: GFNetworkLobbyOperationRequest = null
var _result: GFNetworkLobbyOperationResult = null
var _clock: GFClock = null
var _started_at_msec: int = -1
var _deadline_msec: int = -1
var _initialized: bool = false


# --- 公共方法 ---

## 获取请求副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求副本。
func get_request() -> GFNetworkLobbyOperationRequest:
	return _request.duplicate_request() if _request != null else null


## 获取请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求 ID。
func get_request_id() -> StringName:
	return _request.request_id if _request != null else &""


## 检查操作是否仍在等待终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 等待中返回 true。
func is_pending() -> bool:
	return _initialized and _result == null


## 检查操作是否已经完成。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已有终态结果时返回 true。
func is_completed() -> bool:
	return _result != null


## 检查操作是否成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 终态存在且成功时返回 true。
func is_successful() -> bool:
	return _result != null and _result.ok


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 终态结果副本；等待中返回 null。
func get_result() -> GFNetworkLobbyOperationResult:
	return _result.duplicate_result() if _result != null else null


## 取消操作。
##
## 取消立即成为本地终态。Backend 会先收到 cancel_requested，但迟到 SDK 回调不能覆盖结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 取消原因。
## [br]
## @return 首次取消成功返回 true。
func cancel(reason: StringName = &"cancelled") -> bool:
	if _has_expired():
		return timeout_from_network_layer()
	var normalized_reason: StringName = reason if reason != &"" else &"cancelled"
	return _finish_failure(
		normalized_reason,
		"Lobby operation cancelled.",
		{},
		true
	)


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求和终态摘要。
## [br]
## @schema return: Dictionary lobby operation handle snapshot.
func get_debug_snapshot() -> Dictionary:
	return {
		"request": _make_request_debug_summary(),
		"pending": is_pending(),
		"completed": is_completed(),
		"successful": is_successful(),
		"result": _make_result_debug_summary(),
	}


# --- 层内方法 ---

## 初始化 Lobby 操作句柄。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @param request: 已校验请求。
## [br]
## @param clock: 单调时钟。
## [br]
## @param started_at_msec: 已捕获起始时间；负数表示立即采样。
## [br]
## @return 首次初始化成功返回 true。
func configure_from_network_layer(
	request: GFNetworkLobbyOperationRequest,
	clock: GFClock,
	started_at_msec: int = -1
) -> bool:
	if _initialized or request == null or not request.is_valid() or clock == null:
		return false
	_request = request.duplicate_request()
	_clock = clock
	_started_at_msec = started_at_msec if started_at_msec >= 0 else _clock.get_monotonic_msec()
	_deadline_msec = (
		_started_at_msec + _request.timeout_msec
		if _request.timeout_msec > 0
		else -1
	)
	_initialized = true
	return true


## 创建拒绝终态。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @param request: 原请求，可为空。
## [br]
## @param status: 稳定失败状态。
## [br]
## @param message: 人读说明。
## [br]
## @param clock: 单调时钟。
## [br]
## @return 首次拒绝成功返回 true。
func reject_from_network_layer(
	request: GFNetworkLobbyOperationRequest,
	status: StringName,
	message: String,
	clock: GFClock
) -> bool:
	if _initialized or clock == null:
		return false
	_request = (
		request.duplicate_request()
		if request != null
		else GFNetworkLobbyOperationRequest.new()
	)
	_clock = clock
	_started_at_msec = _clock.get_monotonic_msec()
	_deadline_msec = -1
	_initialized = true
	return _finish_failure(status, message, {}, false)


## 提交并校验成功终态。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @param options: Backend 结果字段。
## [br]
## @schema options: Dictionary lobby operation success fields.
## [br]
## @return 首次完成成功返回 true。
func succeed_from_network_layer(options: Dictionary = {}) -> bool:
	if not is_pending():
		return false
	if _has_expired():
		return timeout_from_network_layer()
	var result_options: Dictionary = options.duplicate(true)
	result_options["started_at_msec"] = _started_at_msec
	result_options["completed_at_msec"] = _clock.get_monotonic_msec()
	var result: GFNetworkLobbyOperationResult = (
		GFNetworkLobbyOperationResult.new().configure_success(_request, result_options)
	)
	if not result.is_valid():
		return _finish_failure(
			&"invalid_backend_result",
			"Lobby backend returned an invalid success result.",
			{},
			false
		)
	return resolve_from_network_layer(result)


## 提交失败终态。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @param status: 稳定失败状态。
## [br]
## @param message: 人读说明。
## [br]
## @param metadata: Backend 失败元数据。
## [br]
## @schema metadata: Dictionary lobby backend failure metadata.
## [br]
## @return 首次完成成功返回 true。
func fail_from_network_layer(
	status: StringName,
	message: String,
	metadata: Dictionary = {}
) -> bool:
	if status != &"timed_out" and _has_expired():
		return timeout_from_network_layer()
	return _finish_failure(status, message, metadata, false)


## 提交超时终态并通知 Backend 取消。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @return 首次超时成功返回 true。
func timeout_from_network_layer() -> bool:
	return _finish_failure(&"timed_out", "Lobby operation timed out.", {}, true)


## 提交已经构造的终态结果。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @param result: 与当前请求匹配的结果。
## [br]
## @return 首次完成成功返回 true。
func resolve_from_network_layer(result: GFNetworkLobbyOperationResult) -> bool:
	if not is_pending() or result == null or not result.matches_request(_request):
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true


# --- 私有/辅助方法 ---

func _finish_failure(
	status: StringName,
	message: String,
	metadata: Dictionary,
	emit_cancellation: bool
) -> bool:
	if not is_pending():
		return false
	var normalized_status: StringName = status if status != &"" else &"failed"
	_result = GFNetworkLobbyOperationResult.new().configure_failure(
		_request,
		normalized_status,
		message,
		{
			"status": normalized_status,
			"started_at_msec": _started_at_msec,
			"completed_at_msec": _clock.get_monotonic_msec(),
			"metadata": metadata,
		}
	)
	if emit_cancellation:
		cancel_requested.emit(normalized_status)
	completed.emit(_result.duplicate_result())
	return true


func _has_expired() -> bool:
	return (
		is_pending()
		and _deadline_msec >= 0
		and _clock.get_monotonic_msec() >= _deadline_msec
	)


func _make_request_debug_summary() -> Dictionary:
	if _request == null:
		return {}
	return {
		"request_id": _request.request_id,
		"operation": _request.operation,
		"lobby_id": _request.lobby_id,
		"peer_id": _request.peer_id,
		"timeout_msec": _request.timeout_msec,
	}


func _make_result_debug_summary() -> Dictionary:
	if _result == null:
		return {}
	return {
		"request_id": _result.request_id,
		"operation": _result.operation,
		"ok": _result.ok,
		"status": _result.status,
		"lobby_id": _result.lobby_id,
		"error": _result.error,
		"duration_msec": _result.get_duration_msec(),
	}
