## GFCancellationToken: 表示异步流程是否已被请求取消的只读令牌。
##
## 长时间运行的安装器、后台任务或分帧流程应在 await 或外部回调之间检查该令牌，
## 并在收到取消请求后停止继续写回已失效的生命周期。取消只能由拥有者对象触发，
## 调用方通过 token 读取原因、元数据和取消时间。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFCancellationToken
extends RefCounted


# --- 信号 ---

## 当取消请求首次到达时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 稳定取消原因。
signal cancel_requested(reason: StringName)


# --- 私有变量 ---

var _cancel_requested: bool = false
var _cancel_reason: StringName = &""
var _cancel_metadata: Dictionary = {}
var _cancel_requested_msec: int = 0


# --- 公共方法 ---

## 返回是否已经收到取消请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	return _cancel_requested


## 返回取消原因。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 首次取消请求提供的原因；未取消时为空 StringName。
func get_cancel_reason() -> StringName:
	return _cancel_reason


## 返回取消元数据副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 取消元数据副本。
## [br]
## @schema return: Dictionary，包含取消拥有者提供的上下文。
func get_cancel_metadata() -> Dictionary:
	return _cancel_metadata.duplicate(true)


## 返回取消请求发生时的 Time.get_ticks_msec()。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 取消请求发生时的毫秒 tick；未取消时为 0。
func get_cancel_requested_msec() -> int:
	return _cancel_requested_msec


## 获取取消状态快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 取消状态快照。
## [br]
## @schema return: Dictionary，包含 cancel_requested、reason、metadata 和 cancel_requested_msec。
func get_debug_snapshot() -> Dictionary:
	return {
		"cancel_requested": _cancel_requested,
		"reason": _cancel_reason,
		"metadata": _cancel_metadata.duplicate(true),
		"cancel_requested_msec": _cancel_requested_msec,
	}


# --- 框架内部方法 ---

## 标记取消请求。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 首次取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含取消拥有者提供的上下文。
func request_cancel_internal(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	if _cancel_requested:
		return false
	_cancel_requested = true
	_cancel_reason = reason if reason != &"" else &"cancelled"
	_cancel_metadata = metadata.duplicate(true)
	_cancel_requested_msec = Time.get_ticks_msec()
	cancel_requested.emit(_cancel_reason)
	return true
