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


# --- 常量 ---

const _INT64_MAX: int = 9_223_372_036_854_775_807


# --- 私有变量 ---

var _request: GFPlatformBridgeRequest = null
var _result: GFPlatformBridgeResult = null
var _clock: GFClock = null
var _started_at_msec: int = -1
var _deadline_msec: int = -1
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
	if _has_expired():
		return timeout_from_platform_layer()
	var normalized_reason: StringName = reason if reason != &"" else &"cancelled"
	return _finish_failure(normalized_reason, "Platform request cancelled.", {}, true)


## 获取稳定调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 包含 request、pending、completed、successful 和脱敏 result 的字典；失败只公开 status 与 has_error，不公开原始 error 或 metadata。
## [br]
## @schema return: Dictionary with request, pending, completed, successful, and redacted result fields.
func get_debug_snapshot() -> Dictionary:
	return {
		"request": _make_request_debug_summary(),
		"pending": is_pending(),
		"completed": is_completed(),
		"successful": is_successful(),
		"result": _make_result_debug_summary(),
	}


# --- 层内方法 ---

## 由 Platform 层初始化句柄。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param request: 已校验请求。
## [br]
## @param clock: 单调时钟。
## [br]
## @param started_at_msec: Runtime 捕获的起点；负数表示立即采样。
## [br]
## @return 首次初始化成功返回 true。
func configure_from_platform_layer(
	request: GFPlatformBridgeRequest,
	clock: GFClock,
	started_at_msec: int = -1
) -> bool:
	if _initialized or request == null or request.is_empty() or clock == null:
		return false
	_request = request.duplicate_request()
	_clock = clock
	_started_at_msec = started_at_msec if started_at_msec >= 0 else _clock.get_monotonic_msec()
	_deadline_msec = _make_deadline_msec(_started_at_msec, _request.timeout_msec)
	_initialized = true
	return true


## 获取由 Handle 单一计算的请求截止时间。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @return: 正 timeout 的饱和单调截止时间；无 timeout 时返回 -1。
func get_deadline_msec_from_platform_layer() -> int:
	return _deadline_msec


## 由 Platform 层创建输入或路由拒绝终态。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param request: 原请求，可为空。
## [br]
## @param status: 稳定失败状态。
## [br]
## @param error: 人读失败说明。
## [br]
## @param clock: 单调时钟。
## [br]
## @return 首次拒绝成功返回 true。
func reject_from_platform_layer(
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
	_deadline_msec = -1
	_initialized = true
	return _finish_failure(status, error, {}, false)


## 由 Platform 层提交已构造结果。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求匹配且终态字段、时间戳内部一致的结果。
## [br]
## @return: 首次合法完成成功返回 true；非法结果不会消费 pending 终态。
func resolve_from_platform_layer(result: GFPlatformBridgeResult) -> bool:
	if not is_pending() or not _is_valid_terminal_result(result):
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true


## 由 Platform 层提交成功终态。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param value: Adapter 返回值。
## [br]
## @param status: 稳定成功状态。
## [br]
## @param metadata: 已脱敏结果元数据。
## [br]
## @schema value: Adapter-defined result value.
## [br]
## @schema metadata: Dictionary adapter-defined result metadata.
## [br]
## @return 首次完成成功返回 true。
func succeed_from_platform_layer(
	value: Variant = null,
	status: StringName = &"ok",
	metadata: Dictionary = {}
) -> bool:
	if not is_pending():
		return false
	if _has_expired():
		return timeout_from_platform_layer()
	var result: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_success(
		_request,
		value,
		status,
		_started_at_msec,
		_clock.get_monotonic_msec(),
		metadata
	)
	return resolve_from_platform_layer(result)


## 由 Platform 层提交失败终态。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param status: 稳定失败状态。
## [br]
## @param error: 人读失败说明。
## [br]
## @param metadata: 已脱敏失败元数据。
## [br]
## @schema metadata: Dictionary adapter-defined failure metadata.
## [br]
## @return 首次完成成功返回 true。
func fail_from_platform_layer(
	status: StringName,
	error: String,
	metadata: Dictionary = {}
) -> bool:
	if status != &"timed_out" and _has_expired():
		return timeout_from_platform_layer()
	return _finish_failure(status, error, metadata, false)


## 由 Platform 层提交超时终态。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @return 首次超时完成返回 true。
func timeout_from_platform_layer() -> bool:
	return _finish_failure(&"timed_out", "Platform request timed out.", {}, true)


# --- 私有/辅助方法 ---

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
		"contract_id": _request.contract_id,
		"method_id": _request.method_id,
		"timeout_msec": _request.timeout_msec,
	}


func _make_result_debug_summary() -> Dictionary:
	if _result == null:
		return {}
	return {
		"request_id": _result.request_id,
		"contract_id": _result.contract_id,
		"method_id": _result.method_id,
		"ok": _result.ok,
		"status": _result.status,
		"has_error": not _result.error.is_empty(),
		"duration_msec": _result.get_duration_msec(),
	}


static func _make_deadline_msec(started_at_msec: int, timeout_msec: int) -> int:
	if timeout_msec <= 0:
		return -1
	var safe_started_at_msec: int = maxi(started_at_msec, 0)
	if timeout_msec > _INT64_MAX - safe_started_at_msec:
		return _INT64_MAX
	return safe_started_at_msec + timeout_msec


func _matches_request(result: GFPlatformBridgeResult) -> bool:
	return (
		result.request_id == _request.request_id
		and result.contract_id == _request.contract_id
		and result.method_id == _request.method_id
	)


func _is_valid_terminal_result(result: GFPlatformBridgeResult) -> bool:
	if result == null or not _matches_request(result) or result.status == &"":
		return false
	if result.started_at_msec != _started_at_msec:
		return false
	if result.completed_at_msec < result.started_at_msec:
		return false
	if result.completed_at_msec > _clock.get_monotonic_msec():
		return false
	if result.ok:
		return result.error.strip_edges().is_empty()
	return result.value == null and not result.error.strip_edges().is_empty()
