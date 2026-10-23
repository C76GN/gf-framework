## 每个消费者独立的资源请求。完成通知无条件发生，取消只影响本请求。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFAssetLoadOperation
extends RefCounted


# --- 信号 ---

## 终态提交后恰好发出一次，与 owner 是否存活无关。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 稳定的终态结果。
signal completed(result: GFAssetLoadResult)


# --- 私有变量 ---

## 终态结果，pending 时为 null。
## [br]
## @api private
var _result: GFAssetLoadResult

## 请求所在 scope 的弱引用。
## [br]
## @api private
var _scope_ref: WeakRef

## 取消入口，不持有 utility 强引用。
## [br]
## @api private
var _utility_ref: WeakRef


# --- 公共方法 ---

## 等待并返回类型化结果，同时覆盖缓存命中的即时完成。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 同一个结果对象；重复等待不创建新句柄。
func wait_result_async() -> GFAssetLoadResult:
	if _result == null:
		await completed
	return _result


## 查看已提交结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return pending 为 null，否则为稳定终态。
func get_result() -> GFAssetLoadResult:
	return _result


## 判断请求是否已完成。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已进入终态时为 true。
func is_completed() -> bool:
	return _result != null


## 撤销本消费者的 pending 请求。终态后返回 false，不释放成功句柄。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次取消生效时为 true。
func cancel() -> bool:
	if _result != null:
		return false
	var utility_value: Object = _utility_ref.get_ref() if _utility_ref != null else null
	if utility_value is GFAssetUtility:
		var utility: GFAssetUtility = utility_value
		utility.cancel_operation_for_framework(self)
	complete_for_framework(
		GFAssetLoadResult.new(
			GFAssetLoadResult.Status.CANCELLED,
			null,
			ERR_SKIP
		)
	)
	return true


# --- 框架内部方法 ---

## 绑定请求所属服务与 scope。
## [br]
## @api framework_internal
## [br]
## @param utility: 资源服务。
## [br]
## @param scope: 资源生命周期。
func bind_for_framework(utility: GFAssetUtility, scope: GFAssetScope) -> void:
	_utility_ref = weakref(utility) if utility != null else null
	_scope_ref = weakref(scope) if scope != null else null


## 提交终态并无条件唤醒所有等待者。
## [br]
## @api framework_internal
## [br]
## @param result: 不可变终态。
func complete_for_framework(result: GFAssetLoadResult) -> void:
	if _result != null or result == null:
		return
	_result = result
	var scope_value: Object = _scope_ref.get_ref() if _scope_ref != null else null
	if scope_value is GFAssetScope:
		var scope: GFAssetScope = scope_value
		scope.finish_for_framework(self)
	completed.emit(_result)


## 返回仍有效的 scope。
## [br]
## @api framework_internal
## [br]
## @return 所属 scope 或 null。
func get_scope_for_framework() -> GFAssetScope:
	var scope: Object = _scope_ref.get_ref() if _scope_ref != null else null
	return scope if scope is GFAssetScope else null
