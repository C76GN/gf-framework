## 使用 Callable 描述生命周期的运行时任务。
##
## [br]
## 适合把轻量项目逻辑注入 [GFRuntimeTaskScheduler]，而不必为一次性任务创建脚本类。
## 所有回调都接收当前任务和调度器，便于在闭包之外保持可测试的上下文。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 6.0.0
class_name GFCallableRuntimeTask
extends GFRuntimeTask


# --- 公共变量 ---

## 初始化回调，签名为 [code]func(task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。
##
## [br]
## @api public
## [br]
## @category callback
## [br]
## @since 6.0.0
var initialize_callable: Callable = Callable()

## 帧推进回调，签名为 [code]func(delta: float, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。
##
## [br]
## @api public
## [br]
## @category callback
## [br]
## @since 6.0.0
var tick_callable: Callable = Callable()

## 物理帧推进回调，签名为 [code]func(delta: float, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。
##
## [br]
## @api public
## [br]
## @category callback
## [br]
## @since 6.0.0
var physics_tick_callable: Callable = Callable()

## 完成判断回调，签名为 [code]func(task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> bool[/code]。
##
## [br]
## @api public
## [br]
## @category callback
## [br]
## @since 6.0.0
var finished_callable: Callable = Callable()

## 结束回调，签名为 [code]func(interrupted: bool, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。
##
## [br]
## @api public
## [br]
## @category callback
## [br]
## @since 6.0.0
var end_callable: Callable = Callable()

## 是否在初始化后立即完成。
##
## [br]
## 设为 [code]false[/code] 时，任务会持续运行直到 [member finished_callable] 返回 [code]true[/code]。
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
var finish_after_initialize: bool = true


# --- 私有变量 ---

var _scheduler_ref: WeakRef = null


# --- Godot 生命周期方法 ---

## 创建 Callable 运行时任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param p_initialize_callable: 初始化回调。
## [br]
## @param p_tick_callable: 帧推进回调。
## [br]
## @param p_finished_callable: 完成判断回调。
## [br]
## @param p_end_callable: 结束回调。
## [br]
## @param p_requirements: 初始占用对象列表。
## [br]
## @param p_interruptible: 任务是否允许被其他任务中断。
func _init(
	p_initialize_callable: Callable = Callable(),
	p_tick_callable: Callable = Callable(),
	p_finished_callable: Callable = Callable(),
	p_end_callable: Callable = Callable(),
	p_requirements: Array[Object] = [],
	p_interruptible: bool = true
) -> void:
	super._init(p_requirements, p_interruptible)
	initialize_callable = p_initialize_callable
	tick_callable = p_tick_callable
	finished_callable = p_finished_callable
	end_callable = p_end_callable


# --- 公共方法 ---

## 设置物理帧推进回调。
##
## [br]
## @api public
## [br]
## @category config
## [br]
## @since 6.0.0
## [br]
## @param p_physics_tick_callable: 物理帧推进回调。
## [br]
## @return 当前 Callable 任务。
func with_physics_tick(p_physics_tick_callable: Callable) -> GFCallableRuntimeTask:
	physics_tick_callable = p_physics_tick_callable
	return self


## 初始化任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param scheduler: 当前调度器。
func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
	_scheduler_ref = weakref(scheduler) if scheduler != null else null
	if initialize_callable.is_valid():
		var _call_result: Variant = initialize_callable.call(self, scheduler)


## 按帧推进任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param delta: 帧间隔秒数。
func tick(delta: float) -> void:
	if tick_callable.is_valid():
		var _call_result: Variant = tick_callable.call(delta, self, _get_scheduler_or_null())


## 按物理帧推进任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param delta: 物理帧间隔秒数。
func physics_tick(delta: float) -> void:
	if physics_tick_callable.is_valid():
		var _call_result: Variant = physics_tick_callable.call(delta, self, _get_scheduler_or_null())


## 判断任务是否已经完成。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @return 任务已完成时返回 true。
func is_finished() -> bool:
	if finish_after_initialize and has_initialized():
		return true
	if finished_callable.is_valid():
		var finished_value: Variant = finished_callable.call(self, _get_scheduler_or_null())
		if finished_value is bool:
			var finished_bool: bool = finished_value
			return finished_bool
		if finished_value is int:
			var finished_int: int = finished_value
			return finished_int != 0
		if finished_value is float:
			var finished_float: float = finished_value
			return not is_zero_approx(finished_float)
	return false


## 结束任务。
##
## [br]
## @api public
## [br]
## @category lifecycle
## [br]
## @since 6.0.0
## [br]
## @param interrupted: 为 true 时表示任务被其他任务或调度器取消。
func end(interrupted: bool) -> void:
	if end_callable.is_valid():
		var _call_result: Variant = end_callable.call(interrupted, self, _get_scheduler_or_null())


# --- 私有/辅助方法 ---

func _get_scheduler_or_null() -> GFRuntimeTaskScheduler:
	if _scheduler_ref == null:
		return null
	var scheduler: Variant = _scheduler_ref.get_ref()
	if scheduler is GFRuntimeTaskScheduler:
		return scheduler
	return null
