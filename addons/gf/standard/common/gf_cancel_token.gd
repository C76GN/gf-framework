## GFCancelToken: 只读取消状态句柄。
##
## 取消 token 用于把“用户主动取消、生命周期结束、超时或上游取消”传递给异步流程。
## 调用方只能观察状态；实际取消由 [GFCancelSource] 负责触发。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFCancelToken
extends RefCounted


# --- 信号 ---

## token 首次进入取消状态时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 调用方附加的取消上下文。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
signal cancelled(reason: StringName, metadata: Dictionary)


# --- 私有变量 ---

var _cancelled: bool = false
var _reason: StringName = &""
var _metadata: Dictionary = {}
var _cancelled_msec: int = 0


# --- 公共方法 ---

## 判断 token 是否已经取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已取消时返回 true。
func is_cancelled() -> bool:
	return _cancelled


## 获取取消原因。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消原因；未取消时为空 StringName。
func get_reason() -> StringName:
	return _reason


## 获取取消元数据副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消元数据副本。
## [br]
## @schema return: Dictionary，包含调用方传入的取消上下文。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取取消发生时的 Time.get_ticks_msec()。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消发生时的毫秒 tick；未取消时为 0。
func get_cancelled_msec() -> int:
	return _cancelled_msec


## 获取取消状态快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消状态快照。
## [br]
## @schema return: Dictionary，包含 cancelled、reason、metadata 和 cancelled_msec。
func get_debug_snapshot() -> Dictionary:
	return {
		"cancelled": _cancelled,
		"reason": _reason,
		"metadata": _metadata.duplicate(true),
		"cancelled_msec": _cancelled_msec,
	}


# --- 框架内部方法 ---

## 由 [GFCancelSource] 触发取消。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 首次取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel_from_source(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	if _cancelled:
		return false

	_cancelled = true
	_reason = reason if reason != &"" else &"cancelled"
	_metadata = metadata.duplicate(true)
	_cancelled_msec = Time.get_ticks_msec()
	cancelled.emit(_reason, _metadata.duplicate(true))
	return true
