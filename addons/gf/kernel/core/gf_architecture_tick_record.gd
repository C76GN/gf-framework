## GFArchitectureTickRecord: 架构 tick 热路径的缓存调度记录。
##
## 记录模块实例、已验证 Callable、排序优先级和 delta 策略，避免每帧通过
## 字符串方法名和 Object.callv() 重新反射调用。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 4.4.0
## [br]
## @layer kernel/core
class_name GFArchitectureTickRecord
extends RefCounted


# --- 公共变量 ---

## 参与 tick 的模块实例。
## [br]
## @api framework_internal
var module: Object = null

## 已缓存的 tick 或 physics_tick 回调。
## [br]
## @api framework_internal
var callback: Callable = Callable()

## tick 优先级。数值越大越早执行。
## [br]
## @api framework_internal
var priority: int = 0

## 同优先级下的稳定注册顺序。
## [br]
## @api framework_internal
var order: int = 0

## 是否在全局暂停时接收原始 delta。
## [br]
## @api framework_internal
var ignore_pause: bool = false

## 是否在非暂停状态下跳过时间缩放。
## [br]
## @api framework_internal
var ignore_time_scale: bool = false


# --- 框架内部方法 ---

## 配置 tick 调度记录并返回自身，便于构建缓存数组。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param p_module: 参与 tick 的模块实例。
## [br]
## @param p_callback: 已验证的 tick 或 physics_tick 回调。
## [br]
## @param p_priority: tick 优先级，数值越大越早执行。
## [br]
## @param p_order: 同优先级下的稳定注册顺序。
## [br]
## @param p_ignore_pause: 是否在全局暂停时接收原始 delta。
## [br]
## @param p_ignore_time_scale: 是否在非暂停状态下跳过时间缩放。
## [br]
## @return: 当前记录实例。
func configure(
	p_module: Object,
	p_callback: Callable,
	p_priority: int,
	p_order: int,
	p_ignore_pause: bool,
	p_ignore_time_scale: bool
) -> GFArchitectureTickRecord:
	module = p_module
	callback = p_callback
	priority = p_priority
	order = p_order
	ignore_pause = p_ignore_pause
	ignore_time_scale = p_ignore_time_scale
	return self


## 返回记录是否仍指向有效模块和可调用回调。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @return: 记录是否可用于本帧 tick 调用。
func is_valid_record() -> bool:
	return module != null and is_instance_valid(module) and callback.is_valid()


## 根据暂停和时间缩放策略计算本次 tick 应传入的 delta。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param raw_delta: Godot 原始帧 delta。
## [br]
## @param scaled_delta: 已由时间提供者缩放后的 delta。
## [br]
## @param time_paused: 当前全局时间是否暂停。
## [br]
## @return: 传给模块回调的最终 delta。
func get_tick_delta(raw_delta: float, scaled_delta: float, time_paused: bool) -> float:
	if time_paused:
		return raw_delta if ignore_pause else 0.0
	if ignore_time_scale:
		return raw_delta
	return scaled_delta


## 如果记录仍然有效，则调用缓存回调。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param raw_delta: Godot 原始帧 delta。
## [br]
## @param scaled_delta: 已由时间提供者缩放后的 delta。
## [br]
## @param time_paused: 当前全局时间是否暂停。
func invoke(raw_delta: float, scaled_delta: float, time_paused: bool) -> void:
	if not is_valid_record():
		return
	callback.call(get_tick_delta(raw_delta, scaled_delta, time_paused))
