## GFNetworkRequestHandle: 网络请求关联的本地等待句柄。
##
## 句柄弱引用关联器，只允许关联器提交终态。批量清理可以先提交全部结果，
## 再逐个发布 completed；取消只结束本地等待，不撤销服务器操作。
## 状态变更和信号发布只允许在主线程执行。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFNetworkRequestHandle
extends RefCounted


# --- 信号 ---

## 关联器发布已提交的终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 不可变的请求终态，回复通过 getter 取得隔离副本。
signal completed(result: GFNetworkRequestResult)


# --- 私有变量 ---

var _configured: bool = false
var _request_id: String = ""
var _peer_id: int = -1
var _tracker_ref: WeakRef = null
var _result: GFNetworkRequestResult = null
var _published: bool = false


# --- 公共方法 ---

## 获取关联请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求 ID；尚未配置时为空。
func get_request_id() -> String:
	return _request_id


## 获取请求绑定的目标 peer。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求的目标 peer；尚未配置时为 -1。
func get_peer_id() -> int:
	return _peer_id


## 检查请求是否仍在等待终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已配置且尚未提交终态时返回 true。
func is_pending() -> bool:
	return _configured and _result == null


## 检查请求是否已提交终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已提交结果时返回 true；不表示 completed 已经派发。
func is_completed() -> bool:
	return _result != null


## 检查请求是否收到匹配回复。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已提交 received 终态时返回 true；不判断业务成功。
func is_successful() -> bool:
	return _result != null and _result.is_successful()


## 获取不可变的终态结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已提交的同一结果对象；尚未提交时为 null。
func get_result() -> GFNetworkRequestResult:
	return _result


## 取消本地请求等待。
##
## 关联器负责截止时间优先级及 pending 移除。关联器已经不存在时提交 disposed，
## 不发送任何远程取消消息；已提交终态或非主线程调用不产生变化。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 本次调用首次终结等待时返回 true。
func cancel() -> bool:
	if not Thread.is_main_thread() or not is_pending():
		return false
	var tracker_value: Variant = _tracker_ref.get_ref() if _tracker_ref != null else null
	if tracker_value is GFNetworkRequestTracker:
		var tracker: GFNetworkRequestTracker = tracker_value
		return tracker.cancel_from_handle(self)
	var disposed_result: GFNetworkRequestResult = GFNetworkRequestResult.new()
	disposed_result.configure_from_network_layer(
		_request_id,
		_peer_id,
		GFNetworkRequestResult.STATUS_DISPOSED
	)
	if not commit_from_network_layer(disposed_result):
		return false
	publish_from_network_layer()
	return true


# --- 层内方法 ---

## 一次性绑定请求身份与关联器，只允许主线程调用。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since unreleased
## [br]
## @param request_id: 关联器分配的请求 ID。
## [br]
## @param peer_id: 请求绑定的目标 peer。
## [br]
## @param tracker: 所属 GFNetworkRequestTracker，仅保留弱引用；可为空。
func configure_from_network_layer(
	request_id: String,
	peer_id: int,
	tracker: RefCounted
) -> void:
	if not Thread.is_main_thread() or _configured:
		return
	_request_id = request_id
	_peer_id = peer_id
	_tracker_ref = weakref(tracker) if tracker != null else null
	_configured = true


## 提交匹配请求身份的终态，不派发信号。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since unreleased
## [br]
## @param result: 关联器已配置的不可变结果，必须匹配请求 ID 与目标 peer。
## [br]
## @return: 主线程首次提交匹配结果时返回 true。
func commit_from_network_layer(result: GFNetworkRequestResult) -> bool:
	if not Thread.is_main_thread() or not is_pending() or result == null:
		return false
	if result.get_request_id() != _request_id or result.get_peer_id() != _peer_id:
		return false
	_result = result
	_tracker_ref = null
	return true


## 主线程发布已提交的终态，重复调用不再派发。
##
## 发布标记先于信号提交，监听者重入本方法不会重复通知。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since unreleased
func publish_from_network_layer() -> void:
	if not Thread.is_main_thread() or _result == null or _published:
		return
	_published = true
	completed.emit(_result)
