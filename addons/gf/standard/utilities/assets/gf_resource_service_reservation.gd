## 服务域已接纳工作的代次保留票据。仅供框架把 Asset 的本地队列绑定到原代。
## [br]
## @api framework_internal
class_name GFResourceServiceReservation
extends RefCounted


# --- 私有变量 ---

## 票据持有域，域只弱引用票据；架构放弃注册表后句柄仍保留原代所有者。
## [br]
## @api private
var _domain: GFResourceServiceDomain = null

## 接纳后不可变的代次。
## [br]
## @api private
var _generation: int = 0

## 已释放后不再阻止代次退出。
## [br]
## @api private
var _released: bool = false

## 仅请求票据可发起一次工作，句柄保留票据没有请求载荷。
## [br]
## @api private
var _request: Dictionary = {}


# --- 框架内部方法 ---

## 冻结票据来源和载荷。
## [br]
## @api framework_internal
## [br]
## @param domain: 创建方。
## [br]
## @param generation: 固定代次。
## [br]
## @param request: 请求或空保留票据。
## [br]
## @schema request: Dictionary with optional path: String, type_hint: String, options: Dictionary.
func bind(domain: GFResourceServiceDomain, generation: int, request: Dictionary) -> void:
	_domain = domain
	_generation = generation
	_request = request


## 返回创建代次。
## [br]
## @api framework_internal
## [br]
## @return 固定代次。
func get_generation() -> int:
	return _generation


## 返回票据是否已释放。
## [br]
## @api framework_internal
## [br]
## @return 已释放为 true。
func is_released() -> bool:
	return _released


## 启动已接纳工作一次，即使新入口已经换代仍归原代。
## [br]
## @api framework_internal
## [br]
## @return 已启动或已释放时返回失败租约。
func start() -> GFResourceLease:
	if _released or _request.is_empty() or _domain == null:
		return _rejected_lease()
	var payload: Dictionary = _request
	_request = {}
	return _domain.start_reservation_for_framework(self, payload)


## 解除请求或句柄对本代的保留，不取消其他租约。
## [br]
## @api framework_internal
func release() -> void:
	_released = true
	_request.clear()
	_domain = null


# --- 私有/辅助方法 ---

## 不重复提交已经启动的工作。
## [br]
## @api private
func _rejected_lease() -> GFResourceLease:
	var lease: GFResourceLease = GFResourceLease.new()
	lease.broker_mark_failed(ERR_UNAVAILABLE, "resource_service_reservation_consumed")
	return lease
