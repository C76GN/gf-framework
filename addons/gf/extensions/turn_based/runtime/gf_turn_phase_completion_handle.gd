## GFTurnPhaseCompletionHandle: 单次阶段运行的完成能力句柄。
##
## 有效句柄只会由 GFTurnFlowSystem 传给当前 GFTurnPhase._execute() 调用；项目手工 new() 的实例没有完成权限。
## 首次对有效运行调用 try_complete() 会完成该阶段；停止、超时、释放、dispose、重启后的旧句柄及重复调用都返回 false，不影响其他代际。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFTurnPhaseCompletionHandle
extends RefCounted


# --- 私有变量 ---

var _runtime_ref: WeakRef = null
var _configured: bool = false


# --- 公共方法 ---

## 尝试完成创建此句柄的精确阶段运行。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前主线程首次完成仍有效的精确运行时返回 true；失效、重复或非主线程调用返回 false。
func try_complete() -> bool:
	if not Thread.is_main_thread() or _runtime_ref == null:
		return false
	var runtime_value: Variant = _runtime_ref.get_ref()
	if not (runtime_value is RefCounted):
		return false
	var runtime: RefCounted = runtime_value
	if not runtime.has_method(&"try_complete_from_turn_based"):
		return false
	var completion_result: Variant = runtime.call(&"try_complete_from_turn_based", self)
	if completion_result is bool:
		return completion_result
	return false


# --- 层内方法 ---

## 绑定精确的阶段运行态。句柄只允许初始化一次。
## [br]
## @api layer_internal
## [br]
## @layer extensions/turn_based
## [br]
## @param runtime: 创建此 handle 的精确阶段运行态。
## [br]
## @return: 首次成功绑定时返回 true。
func configure_from_turn_based(runtime: RefCounted) -> bool:
	if _configured or runtime == null:
		return false
	_runtime_ref = weakref(runtime)
	_configured = true
	return true


## 仅由绑定的阶段运行态撤销此句柄。
## [br]
## @api layer_internal
## [br]
## @layer extensions/turn_based
## [br]
## @param runtime: 请求撤销的精确阶段运行态。
## [br]
## @return: 绑定的 runtime 首次成功撤销时返回 true。
func invalidate_from_turn_based(runtime: RefCounted) -> bool:
	if runtime == null or _runtime_ref == null:
		return false
	if _runtime_ref.get_ref() != runtime:
		return false
	_runtime_ref = null
	return true
