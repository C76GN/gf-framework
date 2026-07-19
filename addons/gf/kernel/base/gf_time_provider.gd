## GFTimeProvider: 架构 tick 时间缩放与时钟提供协议。
##
## 该基类只定义 `GFArchitecture` 需要理解的时间控制契约。
## 具体时间工具可以继承它来提供暂停、缩放和物理子步能力，并通过独立
## `GFClock` 明确区分单调运行时与 Unix 墙上时间。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFTimeProvider
extends GFUtility


# --- 私有变量 ---

var _clock: GFClock = GFClock.new()


# --- 公共方法 ---

## 设置底层时钟。
##
## 注入只改变后续读取，不修改缩放或暂停状态。传入 null 会被拒绝。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param clock: 系统、测试或模拟时钟。
## [br]
## @return 设置成功返回 true。
func set_clock(clock: GFClock) -> bool:
	if clock == null:
		return false
	_clock = clock
	return true


## 获取当前底层时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前时钟实例。
func get_clock() -> GFClock:
	return _clock


## 获取单调运行时微秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 不受暂停、缩放或系统校时影响的微秒值。
func get_monotonic_usec() -> int:
	return _clock.get_monotonic_usec()


## 获取单调运行时毫秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 不受暂停、缩放或系统校时影响的毫秒值。
func get_monotonic_msec() -> int:
	return _clock.get_monotonic_msec()


## 获取 Unix epoch 毫秒时间戳。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 可持久化、但可能因系统校时跳变的毫秒时间戳。
func get_unix_time_msec() -> int:
	return _clock.get_unix_time_msec()


## 获取 Unix epoch 秒时间戳。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 可持久化、但可能因系统校时跳变的秒时间戳。
func get_unix_time_seconds() -> int:
	return _clock.get_unix_time_seconds()

## 获取普通 tick 使用的 delta。
## [br]
## @api public
## [br]
## @param delta: 引擎原始帧间隔时间。
## [br]
## @return 模块应接收的 delta。
func get_scaled_delta(delta: float) -> float:
	return delta


## 获取 physics_tick 使用的 delta 子步数组。
## [br]
## @api public
## [br]
## @param delta: 引擎原始物理帧间隔时间。
## [br]
## @return 模块应依次接收的 physics delta。
func get_physics_scaled_delta_steps(delta: float) -> Array[float]:
	return [get_scaled_delta(delta)]


## 判断当前物理帧是否需要拆分为多个子步。
## [br]
## @api public
## [br]
## @param delta: 引擎原始物理帧间隔时间。
## [br]
## @return 需要拆分时返回 true。
func should_substep_physics(delta: float) -> bool:
	return get_physics_scaled_delta_steps(delta).size() > 1


## 检查当前时间提供者是否处于全局暂停状态。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_time_paused() -> bool:
	return false
