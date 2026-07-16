## GFAsyncCompletion: 一次性异步完成源。
##
## 用于把回调、Signal、后台任务或项目侧异步流程归一为 succeeded / failed / cancelled 终态。
## 它只保存结果状态，不调度任务，也不强制规定调用方如何重试或回滚。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
## [br]
## @layer kernel/core
class_name GFAsyncCompletion
extends RefCounted


# --- 信号 ---

## 完成源进入任意终态时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param completion: 当前完成源。
signal completed(completion: GFAsyncCompletion)

## 完成源成功时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param result: 成功结果。
## [br]
## @param metadata: 终态元数据。
## [br]
## @schema result: Variant，调用方定义的成功结果。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
signal succeeded(result: Variant, metadata: Dictionary)

## 完成源失败时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param error: 失败说明。
## [br]
## @param metadata: 终态元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
signal failed(error: String, metadata: Dictionary)

## 完成源取消时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 终态元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
signal cancelled(reason: StringName, metadata: Dictionary)


# --- 枚举 ---

## 完成源状态。
## [br]
## @api public
## [br]
## @since 7.0.0
enum Status {
	## 等待完成。
	PENDING,
	## 已成功完成。
	SUCCEEDED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _status: Status = Status.PENDING
var _result: Variant = null
var _error: String = ""
var _cancel_reason: StringName = &""
var _metadata: Dictionary = {}
var _created_msec: int = Time.get_ticks_msec()
var _completed_msec: int = 0
var _cancel_token: GFCancellationToken = null
var _cancel_callback: Callable = Callable()


# --- 公共方法 ---

## 标记成功完成。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param result: 成功结果。
## [br]
## @param metadata: 终态元数据。
## [br]
## @return 首次进入终态时返回 true。
## [br]
## @schema result: Variant，调用方定义的成功结果。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
func succeed(result: Variant = null, metadata: Dictionary = {}) -> bool:
	return _complete(Status.SUCCEEDED, result, "", &"", metadata)


## 标记失败完成。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param error: 失败说明。
## [br]
## @param metadata: 终态元数据。
## [br]
## @return 首次进入终态时返回 true。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
func fail(error: String = "", metadata: Dictionary = {}) -> bool:
	return _complete(Status.FAILED, null, error, &"", metadata)


## 标记取消完成。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 终态元数据。
## [br]
## @param result: 可选取消结果。
## [br]
## @return 首次进入终态时返回 true。
## [br]
## @schema metadata: Dictionary，调用方定义的终态元数据。
## [br]
## @schema result: Variant，调用方定义的取消结果。
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}, result: Variant = null) -> bool:
	return _complete(Status.CANCELLED, result, "", reason, metadata)


## 绑定取消 token；token 取消时完成源进入 cancelled 终态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param token: 取消 token。
## [br]
## @return 成功绑定或 token 已经触发取消时返回 true。
func bind_cancel_token(token: GFCancellationToken) -> bool:
	if token == null:
		return false
	if not is_pending():
		return false
	_disconnect_cancel_token()
	_cancel_token = token
	if token.is_cancel_requested():
		var _cancelled_now: bool = cancel(token.get_cancel_reason(), token.get_cancel_metadata())
		return true

	_cancel_callback = func(reason: StringName) -> void:
		var _cancelled_from_token: bool = cancel(reason, token.get_cancel_metadata())
	var connect_error: Error = token.cancel_requested.connect(
		_cancel_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return connect_error == OK


## 当前是否仍在等待。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 等待中返回 true。
func is_pending() -> bool:
	return _status == Status.PENDING


## 当前是否已经进入任意终态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已完成、失败或取消时返回 true。
func is_completed() -> bool:
	return _status != Status.PENDING


## 当前是否成功。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 成功完成时返回 true。
func is_successful() -> bool:
	return _status == Status.SUCCEEDED


## 当前是否失败。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 失败时返回 true。
func is_failed() -> bool:
	return _status == Status.FAILED


## 当前是否取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消时返回 true。
func is_cancelled() -> bool:
	return _status == Status.CANCELLED


## 获取当前状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前状态枚举值。
func get_status() -> Status:
	return _status


## 获取成功结果。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 成功结果；未成功时为 null。
## [br]
## @schema return: Variant，调用方定义的成功结果。
func get_result() -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_result)


## 获取失败说明。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 失败说明。
func get_error() -> String:
	return _error


## 获取取消原因。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消原因。
func get_cancel_reason() -> StringName:
	return _cancel_reason


## 获取终态元数据副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 元数据副本。
## [br]
## @schema return: Dictionary，调用方定义的终态元数据。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取完成源状态快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 状态快照。
## [br]
## @schema return: Dictionary，包含 status、status_name、completed、successful、failed、cancelled、result、error、cancel_reason、metadata、created_msec、completed_msec 和 duration_msec。
func get_debug_snapshot() -> Dictionary:
	var duration_msec: int = 0
	if _completed_msec > 0:
		duration_msec = maxi(_completed_msec - _created_msec, 0)
	return {
		"status": _status,
		"status_name": Status.keys()[_status],
		"completed": is_completed(),
		"successful": is_successful(),
		"failed": is_failed(),
		"cancelled": is_cancelled(),
		"result": _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_result),
		"error": _error,
		"cancel_reason": _cancel_reason,
		"metadata": _metadata.duplicate(true),
		"created_msec": _created_msec,
		"completed_msec": _completed_msec,
		"duration_msec": duration_msec,
	}


# --- 私有/辅助方法 ---

func _complete(
	status: Status,
	result: Variant,
	error: String,
	cancel_reason: StringName,
	metadata: Dictionary
) -> bool:
	if _status != Status.PENDING:
		return false

	_disconnect_cancel_token()
	_status = status
	_result = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(result)
	_error = error
	_cancel_reason = cancel_reason if status != Status.CANCELLED or cancel_reason != &"" else &"cancelled"
	_metadata = metadata.duplicate(true)
	_completed_msec = Time.get_ticks_msec()

	match _status:
		Status.SUCCEEDED:
			succeeded.emit(_GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_result), _metadata.duplicate(true))
		Status.FAILED:
			failed.emit(_error, _metadata.duplicate(true))
		Status.CANCELLED:
			cancelled.emit(_cancel_reason, _metadata.duplicate(true))
		_:
			pass

	completed.emit(self)
	return true


func _disconnect_cancel_token() -> void:
	if (
		_cancel_token != null
		and _cancel_callback.is_valid()
		and _cancel_token.cancel_requested.is_connected(_cancel_callback)
	):
		_cancel_token.cancel_requested.disconnect(_cancel_callback)
	_cancel_token = null
	_cancel_callback = Callable()
