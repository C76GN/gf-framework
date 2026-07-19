## GFManualClock: 可确定推进的测试与模拟时钟。
##
## 单调时间只能向前推进；墙上时钟可通过 `set_unix_time_msec()` 模拟校时跳变。
## 该类型不自动读取系统时间，也不会随帧更新。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFManualClock
extends GFClock


# --- 私有变量 ---

var _monotonic_usec: int = 0
var _unix_time_msec: int = 0
var _wall_remainder_usec: int = 0


# --- Godot 生命周期方法 ---

## 创建手动时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param monotonic_usec: 初始单调微秒值。
## [br]
## @param unix_time_msec: 初始 Unix epoch 毫秒值。
func _init(monotonic_usec: int = 0, unix_time_msec: int = 0) -> void:
	_monotonic_usec = maxi(monotonic_usec, 0)
	_unix_time_msec = maxi(unix_time_msec, 0)


# --- 公共方法 ---

## 获取当前手动单调微秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前单调微秒值。
func get_monotonic_usec() -> int:
	return _monotonic_usec


## 获取当前手动单调毫秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前单调毫秒值。
func get_monotonic_msec() -> int:
	return floori(float(_monotonic_usec) / 1000.0)


## 获取当前手动 Unix epoch 毫秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前 Unix epoch 毫秒值。
func get_unix_time_msec() -> int:
	return _unix_time_msec


## 获取当前手动 Unix epoch 秒值。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前 Unix epoch 秒值。
func get_unix_time_seconds() -> int:
	return floori(float(_unix_time_msec) / 1000.0)


## 同时向前推进单调时钟和墙上时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param delta_usec: 非负推进微秒数。
## [br]
## @return 参数合法并完成推进时返回 true。
func advance_usec(delta_usec: int) -> bool:
	if delta_usec < 0:
		return false
	_monotonic_usec += delta_usec
	var wall_delta_usec: int = _wall_remainder_usec + delta_usec
	_unix_time_msec += floori(float(wall_delta_usec) / 1000.0)
	_wall_remainder_usec = wall_delta_usec % 1000
	return true


## 同时向前推进单调时钟和墙上时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param delta_msec: 非负推进毫秒数。
## [br]
## @return 参数合法并完成推进时返回 true。
func advance_msec(delta_msec: int) -> bool:
	if delta_msec < 0:
		return false
	_monotonic_usec += delta_msec * 1000
	_unix_time_msec += delta_msec
	return true


## 显式设置墙上时钟，用于模拟系统校时或恢复持久化时间。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param unix_time_msec: 非负 Unix epoch 毫秒值。
## [br]
## @return 参数合法并完成设置时返回 true。
func set_unix_time_msec(unix_time_msec: int) -> bool:
	if unix_time_msec < 0:
		return false
	_unix_time_msec = unix_time_msec
	_wall_remainder_usec = 0
	return true
