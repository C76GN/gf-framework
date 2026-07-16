## GFSubscriptionToken: 可取消订阅的通用运行时句柄。
##
## 订阅创建方应返回该句柄，由调用方在不再需要监听时调用 cancel()。
## cancel() 是幂等的，首次取消会执行注册的清理回调，后续调用只返回 false。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFSubscriptionToken
extends RefCounted


# --- 私有变量 ---

var _cancel_callback: Callable = Callable()
var _active: bool = false
var _debug_label: String = ""


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cancel_callback: 首次取消时执行的无参清理回调。
## [br]
## @param debug_label: 可选诊断标签。
func _init(cancel_callback: Callable = Callable(), debug_label: String = "") -> void:
	_cancel_callback = cancel_callback
	_debug_label = debug_label
	_active = _cancel_callback.is_valid()


# --- 公共方法 ---

## 取消订阅并执行清理回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 本次调用是否首次取消了活动订阅。
func cancel() -> bool:
	if not _active:
		return false

	_active = false
	var callback: Callable = _cancel_callback
	_cancel_callback = Callable()
	if callback.is_valid():
		var _cancel_result: Variant = callback.call()
	return true


## 返回订阅是否仍处于活动状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 活动时返回 true。
func is_active() -> bool:
	return _active


## 返回诊断标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 创建订阅时传入的诊断标签。
func get_debug_label() -> String:
	return _debug_label
