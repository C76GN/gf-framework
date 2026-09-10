## GFNetworkRequestTracker: 可选的有界网络请求关联器。
##
## 主线程显式驱动会话、请求与回复，不拥有传输后端，不解释业务成功或自动重试。
## send 回调同步接收必须原样回显的请求 ID；适配器识别回复后传入真实传输 peer。
## 使用独立单调时钟；调用方须定期 tick，并在退出时 dispose。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFNetworkRequestTracker
extends RefCounted


# --- 常量 ---

const _VALUE_VALIDATOR_SCRIPT = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")
const _MAX_PENDING: int = 4096
const _MAX_TIMEOUT_MSEC: int = 86400000
const _MAX_COUNTER: int = 9223372036854775807
const _MAX_RESPONSE_BYTES: int = 65536
const _RESPONSE_LIMITS: Dictionary = {
	"max_depth": 16,
	"max_nodes": 4096,
	"max_bytes": _MAX_RESPONSE_BYTES,
}


# --- 私有变量 ---

var _clock: GFClock
var _max_pending: int
var _namespace: String
var _session_counter: int = 0
var _request_counter: int = 0
var _active: bool = false
var _starting_session: bool = false
var _disposed: bool = false
var _closing_depth: int = 0
var _ticking: bool = false
var _pending: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建关联器；时钟与容量在此生命周期内固定。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param clock: 同步、无副作用的单调时钟；null 使用系统 GFClock。
## [br]
## @param max_pending: 在途上限，必须为 1 至 4096；无效配置无法开始会话。
func _init(clock: GFClock = null, max_pending: int = 64) -> void:
	_clock = clock if clock != null else GFClock.new()
	_max_pending = max_pending
	_namespace = GFUuid.generate_v4()


# --- GF 生命周期方法 ---

## 不可逆地关闭准入并终结所有在途请求，不关闭共享网络工具。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if not Thread.is_main_thread() or _disposed:
		return
	_disposed = true
	_active = false
	_starting_session = false
	_close_pending(GFNetworkRequestResult.STATUS_DISPOSED)


# --- 公共方法 ---

## 开始新会话，先以 session_closed 终结旧请求，再允许新请求。
##
## 清理通知期间不允许重入开启会话；若监听者结束会话或 dispose，本次开启也失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功为 OK；非主线程、已释放或开启期间被关闭为 ERR_UNAVAILABLE，清理中为 ERR_BUSY，无效配置为 ERR_INVALID_PARAMETER。
func begin_session() -> Error:
	if not Thread.is_main_thread() or _disposed:
		return ERR_UNAVAILABLE
	if _closing_depth > 0:
		return ERR_BUSY
	if _max_pending <= 0 or _max_pending > _MAX_PENDING:
		return ERR_INVALID_PARAMETER
	if _session_counter == _MAX_COUNTER:
		return ERR_UNAVAILABLE
	_active = false
	_starting_session = true
	_close_pending(GFNetworkRequestResult.STATUS_SESSION_CLOSED)
	if _disposed or not _starting_session:
		return ERR_UNAVAILABLE
	_starting_session = false
	_session_counter += 1
	_active = true
	return OK


## 结束当前会话；批量提交所有旧终态后才发通知。
## [br]
## @api public
## [br]
## @since unreleased
func end_session() -> void:
	if not Thread.is_main_thread():
		return
	_active = false
	_starting_session = false
	_close_pending(GFNetworkRequestResult.STATUS_SESSION_CLOSED)


## 终结指定 peer 的在途请求，不影响其他 peer。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param peer_id: 实际传输 peer，必须大于 0。
func disconnect_peer(peer_id: int) -> void:
	if not Thread.is_main_thread() or peer_id <= 0:
		return
	_close_pending(GFNetworkRequestResult.STATUS_PEER_DISCONNECTED, peer_id)


## 登记请求，再同步调用 send(request_id) 进行项目编码与发送。
##
## 回调只在本次调用栈内使用，返回 Godot Error。同步回复可能使返回句柄已经完成；
## 已提交的终态优先于回调随后返回的错误。准入失败不调用 send。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param peer_id: 单一目标 peer，必须大于 0，不接受广播。
## [br]
## @param send: 同步 Callable，接收不透明 String 请求 ID 并返回 Error；不得 await。
## [br]
## @param timeout_msec: 单调超时，1 至 86400000 毫秒，不允许无限等待。
## [br]
## @return: 在途或已完成句柄；非主线程返回 null 且不发送。
func request(
	peer_id: int,
	send: Callable,
	timeout_msec: int = 10000
) -> GFNetworkRequestHandle:
	if not Thread.is_main_thread():
		return null
	if _disposed:
		return _reject(peer_id, GFNetworkRequestResult.STATUS_DISPOSED, ERR_UNAVAILABLE)
	if _closing_depth > 0 or _pending.size() >= _max_pending:
		return _reject(peer_id, GFNetworkRequestResult.STATUS_REJECTED, ERR_BUSY)
	if not _active:
		return _reject(peer_id, GFNetworkRequestResult.STATUS_REJECTED, ERR_UNCONFIGURED)
	if peer_id <= 0 or not send.is_valid() or timeout_msec <= 0 or timeout_msec > _MAX_TIMEOUT_MSEC:
		return _reject(peer_id, GFNetworkRequestResult.STATUS_REJECTED, ERR_INVALID_PARAMETER)
	var now: int = _clock.get_monotonic_msec()
	if now < 0 or now > _MAX_COUNTER - timeout_msec or _request_counter == _MAX_COUNTER:
		return _reject(peer_id, GFNetworkRequestResult.STATUS_REJECTED, ERR_INVALID_PARAMETER)
	_request_counter += 1
	var request_id: String = "%s:%d:%d" % [_namespace, _session_counter, _request_counter]
	var handle: GFNetworkRequestHandle = GFNetworkRequestHandle.new()
	handle.configure_from_network_layer(request_id, peer_id, self)
	_pending[request_id] = { "handle": handle, "deadline": now + timeout_msec }
	var send_result: Variant = send.call(request_id)
	if _get_handle(request_id) != handle:
		return handle
	if _expire(handle):
		return handle
	var send_error: Error = ERR_INVALID_DATA
	if typeof(send_result) == TYPE_INT:
		var error_code: int = send_result
		if error_code >= OK and error_code <= ERR_PRINTER_ON_FIRE:
			send_error = error_code as Error
	if send_error != OK:
		var _finished: bool = _finish(handle, GFNetworkRequestResult.STATUS_SEND_FAILED, null, send_error)
	return handle


## 接收适配器已识别的回复，不处理普通广播、业务错误码或协议字段。
##
## 错 peer、未知或重复 ID 不改变请求。截止时刻已到则先超时。
## 无效回复终结为 invalid_response；不会保留部分值或截断后冒充成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param peer_id: 来自传输回调的真实 peer，不使用载荷自报身份。
## [br]
## @param request_id: 协议原样回显的完整请求 ID。
## [br]
## @param response: 需要保留的回复值，可为 null。
## [br]
## @return: 本次提交 received 终态时为 true；其他情况为 false。
## [br]
## @schema response: Variant，传输安全纯值；拒绝 Object、Callable、Signal、RID、循环和非有限数，限制深度 16、节点 4096、估算传输字节 65536。
func receive_reply(peer_id: int, request_id: String, response: Variant = null) -> bool:
	if not Thread.is_main_thread() or not _active or _disposed:
		return false
	if request_id.is_empty() or request_id.length() > 78:
		return false
	var handle: GFNetworkRequestHandle = _get_handle(request_id)
	if handle == null or handle.get_peer_id() != peer_id:
		return false
	if _expire(handle):
		return false
	var report: Dictionary = _VALUE_VALIDATOR_SCRIPT.validate(response, _RESPONSE_LIMITS)
	if _expire(handle):
		return false
	if not GFVariantData.get_option_bool(report, "ok"):
		var _finished: bool = _finish(handle, GFNetworkRequestResult.STATUS_INVALID_RESPONSE)
		return false
	var result: GFNetworkRequestResult = GFNetworkRequestResult.new()
	result.configure_from_network_layer(request_id, peer_id, GFNetworkRequestResult.STATUS_RECEIVED, response)
	# 隔离副本准备完成后再判截止时间，提交时不再复制回复。
	if _expire(handle) or not _commit_result(handle, result):
		return false
	handle.publish_from_network_layer()
	return true


## 按单调截止时间终结到期请求；不推进传输或时钟，不重入驱动。
##
## 本次到期集合在通知前全部提交；监听者新建的请求留待下一次 tick。
## [br]
## @api public
## [br]
## @since unreleased
func tick() -> void:
	if not Thread.is_main_thread() or _disposed or _ticking or _closing_depth > 0:
		return
	_ticking = true
	var now: int = _clock.get_monotonic_msec()
	var completed: Array[GFNetworkRequestHandle] = []
	for key: Variant in _pending.keys():
		var request_id: String = key
		if now < _get_deadline(request_id):
			continue
		var handle: GFNetworkRequestHandle = _get_handle(request_id)
		if handle != null and _commit(handle, GFNetworkRequestResult.STATUS_TIMED_OUT):
			completed.append(handle)
	for handle: GFNetworkRequestHandle in completed:
		handle.publish_from_network_layer()
	_ticking = false


## 获取尚未提交终态的请求数；到期请求在 tick 或终态入口处理。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 在途数量。
func get_pending_count() -> int:
	return _pending.size()


## 获取不包含关联 ID、业务载荷或发送回调的诊断快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前关联器状态。
## [br]
## @schema return: Dictionary，包含 active、disposed、pending_count、max_pending。
func get_debug_snapshot() -> Dictionary:
	return {
		"active": _active,
		"disposed": _disposed,
		"pending_count": _pending.size(),
		"max_pending": _max_pending,
	}


# --- 层内方法 ---

## 校验精确句柄身份后取消；截止时刻已到时提交超时。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since unreleased
## [br]
## @param handle: 关联器发出的在途句柄。
## [br]
## @return: 首次提交取消或超时时为 true。
func cancel_from_handle(handle: GFNetworkRequestHandle) -> bool:
	if not Thread.is_main_thread() or handle == null:
		return false
	if _get_handle(handle.get_request_id()) != handle:
		return false
	if _expire(handle):
		return true
	return _finish(handle, GFNetworkRequestResult.STATUS_CANCELLED)


# --- 私有/辅助方法 ---

func _reject(peer_id: int, status: StringName, send_error: Error) -> GFNetworkRequestHandle:
	var handle: GFNetworkRequestHandle = GFNetworkRequestHandle.new()
	handle.configure_from_network_layer("", peer_id, null)
	var result: GFNetworkRequestResult = GFNetworkRequestResult.new()
	result.configure_from_network_layer("", peer_id, status, null, send_error)
	var committed: bool = handle.commit_from_network_layer(result)
	if committed:
		handle.publish_from_network_layer()
	return handle


func _get_handle(request_id: String) -> GFNetworkRequestHandle:
	var record: Dictionary = GFVariantData.get_option_dictionary(_pending, request_id)
	var value: Variant = GFVariantData.get_option_value(record, "handle")
	if value is GFNetworkRequestHandle:
		return value
	return null


func _get_deadline(request_id: String) -> int:
	return GFVariantData.get_option_int(
		GFVariantData.get_option_dictionary(_pending, request_id), "deadline", _MAX_COUNTER
	)


func _expire(handle: GFNetworkRequestHandle) -> bool:
	if _get_handle(handle.get_request_id()) != handle:
		return false
	if _clock.get_monotonic_msec() < _get_deadline(handle.get_request_id()):
		return false
	return _finish(handle, GFNetworkRequestResult.STATUS_TIMED_OUT)


func _commit(
	handle: GFNetworkRequestHandle,
	status: StringName,
	response: Variant = null,
	send_error: Error = OK
) -> bool:
	var result: GFNetworkRequestResult = GFNetworkRequestResult.new()
	result.configure_from_network_layer(handle.get_request_id(), handle.get_peer_id(), status, response, send_error)
	return _commit_result(handle, result)


func _commit_result(handle: GFNetworkRequestHandle, result: GFNetworkRequestResult) -> bool:
	var request_id: String = handle.get_request_id()
	if _get_handle(request_id) != handle:
		return false
	var erased: bool = _pending.erase(request_id)
	if not erased:
		return false
	return handle.commit_from_network_layer(result)


func _finish(
	handle: GFNetworkRequestHandle,
	status: StringName,
	response: Variant = null,
	send_error: Error = OK
) -> bool:
	if not _commit(handle, status, response, send_error):
		return false
	handle.publish_from_network_layer()
	return true


func _close_pending(status: StringName, peer_id: int = -1) -> void:
	_closing_depth += 1
	var completed: Array[GFNetworkRequestHandle] = []
	for key: Variant in _pending.keys():
		var request_id: String = key
		var handle: GFNetworkRequestHandle = _get_handle(request_id)
		if handle == null or (peer_id > 0 and handle.get_peer_id() != peer_id):
			continue
		if _commit(handle, status):
			completed.append(handle)
	for handle: GFNetworkRequestHandle in completed:
		handle.publish_from_network_layer()
	_closing_depth -= 1
