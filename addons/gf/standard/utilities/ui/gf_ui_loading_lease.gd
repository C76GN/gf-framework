## GFUILoadingLease: 单次等待请求的幂等释放句柄。
##
## 由 GFUILoadingUtility 持有至释放；owner 与 scope 使用弱引用，不能延长业务生命周期。
## 进度达到 1 不自动释放，调用方仍需在业务结束时 release。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFUILoadingLease
extends RefCounted


# --- 私有变量 ---

## 服务内唯一身份；0 表示尚未配置。
## [br]
## @api private
var _id: int = 0

## 等待服务弱引用，避免句柄形成服务环。
## [br]
## @api private
var _service_ref: WeakRef = null

## 可选进度对象，不对其完成语义作业务推断。
## [br]
## @api private
var _progress: GFAsyncProgress = null

## owner 生命周期监听；释放时先断开，再通知服务。
## [br]
## @api private
var _lifetime: GFLifetimeSubscription = null

## 请求作用域不由等待服务持有。
## [br]
## @api private
var _scope_ref: WeakRef = null

## 用于精确断开作用域取消回调。
## [br]
## @api private
var _scope_callback: Callable = Callable()

## 失效是单向状态，不能再次配置或激活。
## [br]
## @api private
var _active: bool = false


# --- 公共方法 ---

## 获取服务内唯一请求身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正数身份；未配置为 0。
func get_id() -> int:
	return _id


## 检查等待请求是否仍有效。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 服务仍存在且尚未释放时为 true。
func is_active() -> bool:
	return _active and _get_service() != null


## 获取关联的既有进度对象。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 无进度时为 null。
func get_progress() -> GFAsyncProgress:
	return _progress


## 结束本次等待，不取消业务操作，也不等待最短显示时间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次释放活动请求时为 true。
func release() -> bool:
	if not _active:
		return false
	var service: GFUILoadingUtility = _get_service()
	if service == null:
		deactivate_for_framework()
		return false
	return service.release_for_framework(self)


# --- 框架内部方法 ---

## 绑定单次请求与生命周期；调用前服务必须已经登记该句柄。
## [br]
## @api framework_internal
## [br]
## @param service: 管理当前请求的服务。
## [br]
## @param identity: 服务分配的唯一 ID。
## [br]
## @param owner: 已验证的可选 owner。
## [br]
## @param scope: 已验证的可选作用域。
## [br]
## @param progress: 可选业务进度。
func configure_for_framework(
	service: GFUILoadingUtility,
	identity: int,
	owner: Object,
	scope: GFAsyncScope,
	progress: GFAsyncProgress
) -> void:
	if (
		_id != 0
		or service == null
		or identity <= 0
	):
		return
	_id = identity
	_service_ref = weakref(service)
	_progress = progress
	_active = true
	if owner != null:
		var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"release")
		var callback: Callable = func() -> void:
			var _result: Dictionary = invocation.invoke([])
		_lifetime = GFLifetimeSubscription.new(owner, callback)
	if scope != null:
		_scope_ref = weakref(scope)
		_scope_callback = _on_scope_cancelled
		var _connected: int = scope.cancel_requested.connect(_scope_callback)


## 检查需要由服务 tick 清理的普通 Object 或已正常结束作用域。
## [br]
## @api framework_internal
## [br]
## @return owner 失效、scope 已结束或已销毁时为 true。
func is_expired_for_framework() -> bool:
	if _lifetime != null and not _lifetime.is_active():
		return true
	if _scope_ref != null:
		var value: Variant = _scope_ref.get_ref()
		if not value is GFAsyncScope:
			return true
		var scope: GFAsyncScope = value
		return not scope.is_active()
	return false


## 清除监听和进度引用，不回调服务。
## [br]
## @api framework_internal
func deactivate_for_framework() -> void:
	_active = false
	if _lifetime != null:
		var _deactivated: bool = _lifetime._deactivate_from_source()
	_lifetime = null
	if _scope_ref != null:
		var value: Variant = _scope_ref.get_ref()
		if value is GFAsyncScope:
			var scope: GFAsyncScope = value
			if scope.cancel_requested.is_connected(_scope_callback):
				scope.cancel_requested.disconnect(_scope_callback)
	_scope_ref = null
	_scope_callback = Callable()
	_progress = null
	_service_ref = null


# --- 私有/辅助方法 ---

## 收窄弱引用目标，已销毁服务不可再接收释放请求。
## [br]
## @api private
func _get_service() -> GFUILoadingUtility:
	var value: Variant = _service_ref.get_ref() if _service_ref != null else null
	return value if value is GFUILoadingUtility else null


# --- 信号处理函数 ---

## 取消作用域只结束等待反馈，业务取消由该作用域的其他消费者处理。
## [br]
## @api private
func _on_scope_cancelled(_reason: StringName) -> void:
	var _released: bool = release()
