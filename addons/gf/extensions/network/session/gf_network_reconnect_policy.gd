## GFNetworkReconnectPolicy: 通用重连退避策略。
##
## 记录重连尝试次数，并按预设延迟序列返回下一次等待时间。它不依赖具体网络后端。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFNetworkReconnectPolicy
extends RefCounted


# --- 公共变量 ---

## 重连延迟序列，单位毫秒。
## [br]
## @api public
## [br]
## @schema delays_msec: Array[int]，按尝试次数索引的重连延迟毫秒数。
var delays_msec: Array[int] = [500, 1000, 2000, 5000]

## 最大尝试次数。小于等于 0 表示无限尝试。
## [br]
## @api public
var max_attempts: int = 0

## 抖动比例。0 表示不抖动，0.2 表示在 ±20% 内随机偏移。
## [br]
## @api public
var jitter_ratio: float = 0.0:
	set(value):
		jitter_ratio = clampf(value, 0.0, 1.0)


# --- 私有变量 ---

var _attempt_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# --- Godot 生命周期方法 ---

func _init() -> void:
	_rng.randomize()


# --- 公共方法 ---

## 重置尝试计数。
## [br]
## @api public
func reset() -> void:
	_attempt_count = 0


## 检查是否还允许继续尝试。
## [br]
## @api public
## [br]
## @return 允许返回 true。
func has_attempts_remaining() -> bool:
	return max_attempts <= 0 or _attempt_count < max_attempts


## 记录一次失败并返回下一次等待时长。
## [br]
## @api public
## [br]
## @return 下一次等待时长；没有尝试空间时返回 -1。
func get_next_delay_msec() -> int:
	if not has_attempts_remaining():
		return -1

	var delay: int = _get_delay_for_attempt(_attempt_count)
	_attempt_count += 1
	return _apply_jitter(delay)


## 记录一次成功并清空尝试计数。
## [br]
## @api public
func record_success() -> void:
	reset()


## 获取已经消费的失败尝试次数。
## [br]
## @api public
## [br]
## @return 尝试次数。
func get_attempt_count() -> int:
	return _attempt_count


# --- 私有/辅助方法 ---

func _get_delay_for_attempt(attempt_index: int) -> int:
	if delays_msec.is_empty():
		return 0
	var index: int = mini(attempt_index, delays_msec.size() - 1)
	return maxi(delays_msec[index], 0)


func _apply_jitter(delay_msec: int) -> int:
	if delay_msec <= 0 or jitter_ratio <= 0.0:
		return delay_msec

	var jitter_amount: float = delay_msec * jitter_ratio
	var offset: float = _rng.randf_range(-jitter_amount, jitter_amount)
	return maxi(roundi(float(delay_msec) + offset), 0)
