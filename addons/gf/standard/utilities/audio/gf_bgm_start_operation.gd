## GFBgmStartOperation: 单次 BGM start request 的类型化 caller Operation。
##
## Operation 只表达“是否已经提交播放会话”的短生命周期终态。成功返回的
## `GFBgmSessionHandle` 独立表达后续播放会话生命周期；会话结束不会改写 start 结果。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/audio
class_name GFBgmStartOperation
extends RefCounted


# --- 信号 ---

## start request 进入唯一 caller 终态时发出一次。
##
## 同步 validation/backend/local clip 可能在 typed start 方法返回前完成；调用方必须先查询
## `is_completed()`，只在仍 pending 时连接该信号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 当前请求的隔离终态结果。
signal completed(result: GFBgmStartResult)


# --- 私有变量 ---

var _request_id: int = 0
var _result: GFBgmStartResult = null
var _cancel_delegate: GFWeakMethodInvocation = null
var _cancel_requested: bool = false
var _completed_signal_emitted: bool = false


# --- 公共方法 ---

## 获取 Audio Utility 分配的请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 检查请求是否仍等待 caller 终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且尚未完成时返回 true。
func is_pending() -> bool:
	return _request_id > 0 and _result == null


## 检查请求是否已经进入 caller 终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已有终态结果时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取 caller 终态结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成时返回隔离结果；等待中返回 null。
func get_result() -> GFBgmStartResult:
	return _result.duplicate_result() if _result != null else null


## 取消等待中的 start request。
##
## 返回 true 表示 Audio Utility 首次接受取消 intent；backend dispatch 正在进行时，终态可在
## 当前 dispatch 收敛后写入。已提交 Session 不受该 Operation 的后续 cancel 影响，必须通过
## Session Handle 精确停止。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次调用首次取消等待请求时返回 true。
func cancel() -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or _cancel_delegate == null
		or _cancel_requested
	):
		return false
	_cancel_requested = true
	var accepted: bool = _invocation_returned_true(_cancel_delegate.invoke([self]))
	if not accepted and is_pending():
		_cancel_requested = false
	return accepted


# --- 框架内部方法 ---

## 由 Audio Utility 初始化请求身份和弱取消委托。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @param request_id: Utility 内唯一且大于零的请求 ID。
## [br]
## @param cancel_delegate: 无绑定参数的 Utility 对象方法，签名为 `(operation) -> bool`。
## [br]
## @return 首次完整配置成功返回 true。
func configure_for_framework(request_id: int, cancel_delegate: Callable) -> bool:
	if not Thread.is_main_thread() or _request_id != 0 or request_id <= 0:
		return false
	var invocation: GFWeakMethodInvocation = _make_weak_invocation(cancel_delegate)
	if invocation == null:
		return false
	_request_id = request_id
	_cancel_delegate = invocation
	return true


## 由 Audio Utility 写入并发出唯一 caller 终态。
##
## 方法先冻结状态并清除取消委托，再发出公开信号；signal listener 的重入不能覆盖终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @param result: 与当前请求 ID 匹配的闭合终态结果。
## [br]
## @param should_emit_signal: false 时只冻结终态，由 `emit_completed_for_framework()` 延后通知。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(
	result: GFBgmStartResult,
	should_emit_signal: bool = true
) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or result == null
		or not result.is_configured_for_framework()
		or result.get_request_id() != _request_id
	):
		return false
	var result_copy: GFBgmStartResult = result.duplicate_result()
	if not result_copy.is_configured_for_framework():
		return false
	_result = result_copy
	_cancel_delegate = null
	if should_emit_signal:
		var _emitted: bool = emit_completed_for_framework()
	return true


## 发出已经冻结的唯一 start request 终态通知。
##
## Audio Utility 可先用 `complete_for_framework(..., false)` 原子冻结 replacement 涉及的
## start operation 与会话句柄，再调用本方法，避免首个用户回调观察到半提交状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @return 首次发出已冻结终态时返回 true。
func emit_completed_for_framework() -> bool:
	if (
		not Thread.is_main_thread()
		or not is_completed()
		or _completed_signal_emitted
	):
		return false
	_completed_signal_emitted = true
	completed.emit(_result.duplicate_result())
	return true


# --- 私有/辅助方法 ---

static func _make_weak_invocation(method_delegate: Callable) -> GFWeakMethodInvocation:
	if (
		not method_delegate.is_valid()
		or method_delegate.get_bound_arguments_count() != 0
	):
		return null
	var delegate_owner: Object = method_delegate.get_object()
	var delegate_method: StringName = method_delegate.get_method()
	if (
		delegate_owner == null
		or not is_instance_valid(delegate_owner)
		or delegate_method.is_empty()
	):
		return null
	return GFWeakMethodInvocation.new(delegate_owner, delegate_method)


static func _invocation_returned_true(invocation_result: Dictionary) -> bool:
	var invoked_value: Variant = invocation_result.get("invoked", false)
	var return_value: Variant = invocation_result.get("value", false)
	return (
		invoked_value is bool
		and invoked_value
		and return_value is bool
		and return_value
	)
