## GFAsyncScope: 由生命周期拥有者控制的可取消异步作用域。
##
## 作用域继承自 GFCancellationToken，可直接传给需要只读取消检查的流程。
## 注册的清理回调会在 cancel() 时按后进先出顺序执行；complete() 表示流程正常结束并清空清理回调。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFAsyncScope
extends GFCancellationToken


# --- 私有变量 ---

var _cleanup_callbacks: Array[Callable] = []
var _completed: bool = false


# --- 公共方法 ---

## 返回当前作用域的只读取消令牌视图。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前作用域自身，可作为 GFCancellationToken 使用。
func get_token() -> GFCancellationToken:
	return self


## 返回作用域是否仍处于活动状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 未 complete 且未 cancel 时返回 true。
func is_active() -> bool:
	return not _completed and not is_cancel_requested()


## 返回作用域是否已经正常完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return complete() 被调用后返回 true。
func is_completed() -> bool:
	return _completed


## 注册取消时执行的清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cleanup_callback: 取消时执行的无参 Callable。
## [br]
## @return 注册成功、或已取消时即时执行成功，返回 true；无效回调或已完成作用域返回 false。
func register_cleanup(cleanup_callback: Callable) -> bool:
	if _completed:
		return false
	if not cleanup_callback.is_valid():
		push_error("[GFAsyncScope] register_cleanup 失败：cleanup_callback 无效。")
		return false
	if is_cancel_requested():
		var _cleanup_result: Variant = cleanup_callback.call()
		return true
	if _cleanup_callbacks.has(cleanup_callback):
		return true
	_cleanup_callbacks.append(cleanup_callback)
	return true


## 注销取消清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cleanup_callback: 要移除的清理回调。
func unregister_cleanup(cleanup_callback: Callable) -> void:
	var callback_index: int = _cleanup_callbacks.find(cleanup_callback)
	if callback_index >= 0:
		_cleanup_callbacks.remove_at(callback_index)


## 请求取消当前作用域，并执行已注册的清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 本次调用是否首次触发取消。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel(reason: String = "", metadata: Dictionary = {}) -> bool:
	if _completed:
		return false
	var cancel_reason: StringName = StringName(reason) if not reason.is_empty() else &"cancelled"
	if not request_cancel_internal(cancel_reason, metadata):
		return false
	_run_cleanup_callbacks()
	return true


## 标记异步作用域已正常完成，并丢弃取消清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
func complete() -> void:
	if is_cancel_requested():
		return
	_completed = true
	_cleanup_callbacks.clear()


# --- 私有/辅助方法 ---

func _run_cleanup_callbacks() -> void:
	var callbacks: Array[Callable] = _cleanup_callbacks.duplicate()
	_cleanup_callbacks.clear()
	for index: int in range(callbacks.size() - 1, -1, -1):
		var cleanup_callback: Callable = callbacks[index]
		if cleanup_callback.is_valid():
			var _cleanup_result: Variant = cleanup_callback.call()
