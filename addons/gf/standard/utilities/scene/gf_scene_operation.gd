## GFSceneOperation: 单次类型化场景加载或预加载请求的 caller Operation。
##
## 每个请求持有独立 ID、资源身份快照与取消能力。同一路径请求可以共享 Broker
## 的物理加载，但每个 Operation 只观察并终结自己的 consumer Lease。
## Operation 只能由 [method GFSceneUtility.load_scene_request_async] 或
## [method GFSceneUtility.preload_scene_request_async] 取得。它是可由 caller 保留的
## RefCounted handle，无需显式 release，也不拥有 Utility、Broker 或底层 Lease。
## 进入终态或 Utility dispose 后，身份、最终进度与结果快照仍可读取；pending 期间
## 只有 [method cancel] 能力依赖创建它的 Utility 仍然存活。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/scene
class_name GFSceneOperation
extends RefCounted


# --- 信号 ---

## 当前 consumer 的加载进度发生变化时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param progress_ratio: 当前进度，范围为 `0.0` 到 `1.0`。
signal progressed(progress_ratio: float)

## 当前 consumer 进入唯一终态时发出一次。
##
## 同步 validation、cache hit 或生命周期拒绝可能在 request 方法返回前完成；调用方
## 必须先查询 `is_completed()`，只在仍 pending 时连接该信号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 当前请求的隔离终态结果。
signal completed(result: GFSceneOperationResult)


# --- 枚举 ---

## 类型化场景请求的执行种类。
## [br]
## @api public
## [br]
## @since unreleased
enum Kind {
	## 加载资源并在安全帧切换场景。
	LOAD,
	## 预加载场景资源；是否继续保留在缓存由容量与 fixed 策略决定。
	PRELOAD,
}


# --- 私有变量 ---

var _request_id: int = 0
var _kind: Kind = Kind.LOAD
var _scene_identity: GFResourceIdentity = null
var _progress_ratio: float = 0.0
var _result: GFSceneOperationResult = null
var _cancel_delegate: GFWeakMethodInvocation = null
var _cancel_requested: bool = false
var _completed_signal_emitted: bool = false
var _final_progress_signal_pending: bool = false


# --- 公共方法 ---

## 获取 Scene Utility 分配的请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取请求执行种类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `LOAD` 或 `PRELOAD`。
func get_kind() -> Kind:
	return _kind


## 获取请求冻结的资源身份副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 隔离的 GFResourceIdentity 快照；尚未配置时返回 null。
func get_scene_identity() -> GFResourceIdentity:
	return _scene_identity.duplicate_identity() if _scene_identity != null else null


## 获取当前 consumer 的进度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 范围为 `0.0` 到 `1.0` 的进度。
func get_progress_ratio() -> float:
	return _progress_ratio


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
func get_result() -> GFSceneOperationResult:
	return _result.duplicate_result() if _result != null else null


## 取消当前 caller 仍在等待的请求。
##
## preload 取消只释放当前 consumer Lease；同路径的其它 consumer 继续等待。load
## 取消只终结当前切换请求，不会替换或接纳另一个 load。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Scene Utility 首次接受当前 caller 的取消 intent 时返回 true。
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

## 由 Scene Utility 初始化请求身份与弱取消委托。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @param request_id: Utility 内唯一且大于零的请求 ID。
## [br]
## @param kind: 请求执行种类。
## [br]
## @param scene_identity: 请求冻结的资源身份。
## [br]
## @param cancel_delegate: 无绑定参数的 Utility 对象方法，签名为 `(operation) -> bool`。
## [br]
## @return 首次完整配置成功返回 true。
func configure_for_framework(
	request_id: int,
	kind: Kind,
	scene_identity: GFResourceIdentity,
	cancel_delegate: Callable
) -> bool:
	if (
		not Thread.is_main_thread()
		or _request_id != 0
		or request_id <= 0
		or not Kind.values().has(int(kind))
		or scene_identity == null
	):
		return false
	var invocation: GFWeakMethodInvocation = _make_weak_invocation(cancel_delegate)
	if invocation == null:
		return false
	_request_id = request_id
	_kind = kind
	_scene_identity = scene_identity.duplicate_identity()
	_cancel_delegate = invocation
	return true


## 更新当前 consumer 的进度并在实际变化时发出通知。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @param progress_ratio: 最新进度，写入前会限制到 `0.0` 到 `1.0`。
## [br]
## @return pending 且进度实际变化时返回 true。
func update_progress_for_framework(progress_ratio: float) -> bool:
	if not Thread.is_main_thread() or not is_pending():
		return false
	var next_ratio: float = clampf(progress_ratio, 0.0, 1.0)
	if is_equal_approx(next_ratio, _progress_ratio):
		return false
	_progress_ratio = next_ratio
	progressed.emit(_progress_ratio)
	return true


## 冻结当前 consumer 的唯一终态。
##
## 方法先复制结果并清除取消委托，再选择是否发出公开信号；Utility 可先冻结一批
## Operation，再统一通知，避免首个 listener 重入观察到半结算状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @param result: 与当前请求身份匹配的闭合终态结果。
## [br]
## @param should_emit_signal: false 时只冻结终态，稍后显式通知。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(
	result: GFSceneOperationResult,
	should_emit_signal: bool = true
) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_pending()
		or result == null
		or not result.is_configured_for_framework()
		or result.get_request_id() != _request_id
		or result.get_kind() != int(_kind)
	):
		return false
	var result_copy: GFSceneOperationResult = result.duplicate_result()
	if not result_copy.is_configured_for_framework():
		return false
	var should_emit_final_progress: bool = (
		result_copy.is_successful()
		and _progress_ratio < 1.0
	)
	_result = result_copy
	_cancel_delegate = null
	if result_copy.is_successful():
		_progress_ratio = 1.0
	_final_progress_signal_pending = should_emit_final_progress
	if should_emit_signal:
		var _emitted: bool = emit_completed_for_framework()
	return true


## 发出已经冻结的唯一终态通知。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
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
	# 先占住唯一 terminal notification，避免 final-progress listener 重入二次发布。
	_completed_signal_emitted = true
	if _final_progress_signal_pending:
		_final_progress_signal_pending = false
		progressed.emit(_progress_ratio)
	completed.emit(_result.duplicate_result())
	return true


## 检查 Operation 是否已经由 Scene Utility 完整配置。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/scene
## [br]
## @since unreleased
## [br]
## @return 请求身份与取消能力均已冻结时返回 true。
func is_configured_for_framework() -> bool:
	return _request_id > 0 and _scene_identity != null


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
