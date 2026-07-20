## GFPlatformRequestHandle: 平台桥接请求运行时句柄。
##
## 句柄保证一次请求只进入一个终态，并把取消、超时和 adapter 返回统一为
## `GFPlatformBridgeResult`。项目代码只读取句柄，不负责完成句柄。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 9.0.0
class_name GFPlatformRequestHandle
extends RefCounted


# --- 信号 ---

## 请求进入终态时发出一次。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param result: 请求终态结果。
signal completed(result: GFPlatformBridgeResult)

## 请求取消或超时时发出，供 adapter 停止底层调用。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param reason: 取消原因。
signal cancel_requested(reason: StringName)


# --- 私有变量 ---

var _request: GFPlatformBridgeRequest = null
var _result: GFPlatformBridgeResult = null
var _clock: GFClock = null
var _started_at_msec: int = 0
var _initialized: bool = false


# --- 公共方法 ---

## 获取请求数据副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 请求数据副本。
func get_request() -> GFPlatformBridgeRequest:
	return _request.duplicate_request() if _request != null else null


## 获取请求 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 请求 ID。
func get_request_id() -> StringName:
	return _request.request_id if _request != null else &""


## 检查请求是否仍在等待终态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 等待中返回 true。
func is_pending() -> bool:
	return _initialized and _result == null


## 检查请求是否已经完成。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 已有终态结果时返回 true。
func is_completed() -> bool:
	return _result != null


## 检查请求是否成功。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 终态存在且成功时返回 true。
func is_successful() -> bool:
	return _result != null and _result.ok


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 终态结果副本；等待中返回 null。
func get_result() -> GFPlatformBridgeResult:
	return _result.duplicate_result() if _result != null else null


## 取消请求。
##
## 取消立即成为本地终态；adapter 会在 `completed` 前收到 `cancel_requested`，
## 但不能用迟到回调覆盖取消结果。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @return 首次取消成功返回 true。
func cancel(reason: StringName = &"cancelled") -> bool:
	var normalized_reason: StringName = reason if reason != &"" else &"cancelled"
	return _finish_failure(normalized_reason, "Platform request cancelled.", {}, true)


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 包含 request、pending、completed、successful 和 result 的字典。
## [br]
## @schema return: Dictionary with request, pending, completed, successful, and result fields.
func get_debug_snapshot() -> Dictionary:
	return {
		"request": _request.to_dict() if _request != null else {},
		"pending": is_pending(),
		"completed": is_completed(),
		"successful": is_successful(),
		"result": _result.to_dict() if _result != null else {},
	}


# --- 私有/辅助方法 ---

# 由 platform 层初始化句柄。
func _gf_configure(
	request: GFPlatformBridgeRequest,
	clock: GFClock,
	started_at_msec: int = -1
) -> bool:
	if _initialized or request == null or request.is_empty() or clock == null:
		return false
	_request = request.duplicate_request()
	_clock = clock
	_started_at_msec = started_at_msec if started_at_msec >= 0 else _clock.get_monotonic_msec()
	_initialized = true
	return true


# 由 platform 层创建输入或路由拒绝终态。
func _gf_reject(
	request: GFPlatformBridgeRequest,
	status: StringName,
	error: String,
	clock: GFClock
) -> bool:
	if _initialized or clock == null:
		return false
	_request = request.duplicate_request() if request != null else GFPlatformBridgeRequest.new()
	_clock = clock
	_started_at_msec = _clock.get_monotonic_msec()
	_initialized = true
	return _finish_failure(status, error, {}, false)


# 由 platform 层提交 adapter 结果。
func _gf_resolve(result: GFPlatformBridgeResult) -> bool:
	if not is_pending() or result == null or not _matches_request(result):
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true


# 由 platform 层提交成功终态。
func _gf_succeed(
	value: Variant = null,
	status: StringName = &"ok",
	metadata: Dictionary = {}
) -> bool:
	if not is_pending():
		return false
	var result: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_success(
		_request,
		value,
		status,
		_started_at_msec,
		_clock.get_monotonic_msec(),
		metadata
	)
	return _gf_resolve(result)


# 由 platform 层提交失败终态。
func _gf_fail(status: StringName, error: String, metadata: Dictionary = {}) -> bool:
	return _finish_failure(status, error, metadata, false)


# 由 platform 层提交超时终态。
func _gf_timeout() -> bool:
	return _finish_failure(&"timed_out", "Platform request timed out.", {}, true)

func _finish_failure(
	status: StringName,
	error: String,
	metadata: Dictionary,
	emit_cancellation: bool
) -> bool:
	if not is_pending():
		return false
	var normalized_status: StringName = status if status != &"" else &"failed"
	_result = GFPlatformBridgeResult.new().configure_failure(
		_request,
		error,
		normalized_status,
		_started_at_msec,
		_clock.get_monotonic_msec(),
		metadata
	)
	if emit_cancellation:
		cancel_requested.emit(normalized_status)
	completed.emit(_result.duplicate_result())
	return true


func _matches_request(result: GFPlatformBridgeResult) -> bool:
	return (
		result.request_id == _request.request_id
		and result.contract_id == _request.contract_id
		and result.method_id == _request.method_id
	)
