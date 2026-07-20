## GFClock: 单调运行时与 Unix 墙上时钟协议。
##
## 单调时间只用于耗时、截止时间和运行时排序；Unix 时间只用于持久化时间戳与
## 跨进程交换。默认实现直接读取 Godot 系统时钟，测试或模拟环境可以继承并
## 覆写读取方法。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 9.0.0
class_name GFClock
extends RefCounted


# --- 公共方法 ---

## 获取自进程启动后单调递增的微秒数。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 单调时钟微秒值，不可作为持久化时间戳。
func get_monotonic_usec() -> int:
	return Time.get_ticks_usec()


## 获取自进程启动后单调递增的毫秒数。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 单调时钟毫秒值，不可作为持久化时间戳。
func get_monotonic_msec() -> int:
	return Time.get_ticks_msec()


## 获取 Unix epoch 毫秒时间戳。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 可持久化的 Unix epoch 毫秒时间戳；该值可能因系统校时跳变。
func get_unix_time_msec() -> int:
	var unix_time_seconds: float = Time.get_unix_time_from_system()
	return floori(unix_time_seconds * 1000.0)


## 获取 Unix epoch 秒时间戳。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 可持久化的 Unix epoch 秒时间戳；该值可能因系统校时跳变。
func get_unix_time_seconds() -> int:
	var unix_time_seconds: float = Time.get_unix_time_from_system()
	return floori(unix_time_seconds)
