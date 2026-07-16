## GFNetworkRateLimiter: 通用令牌桶限流器。
##
## 可用于限制消息发送频率，避免某类同步或 RPC 过量发送。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFNetworkRateLimiter
extends RefCounted


# --- 公共变量 ---

## 令牌桶容量。
## [br]
## @api public
var capacity: float = 10.0:
	set(value):
		capacity = _normalize_non_negative_finite(value)
		_tokens = minf(_tokens, capacity)

## 每秒恢复令牌数。
## [br]
## @api public
var refill_per_second: float = 10.0:
	set(value):
		refill_per_second = _normalize_non_negative_finite(value)


# --- 私有变量 ---

var _tokens: float = capacity


# --- Godot 生命周期方法 ---

func _init(p_capacity: float = 10.0, p_refill_per_second: float = 10.0) -> void:
	capacity = p_capacity
	refill_per_second = p_refill_per_second
	_tokens = capacity


# --- 公共方法 ---

## 推进限流器时间。
## [br]
## @api public
## [br]
## @param delta: 秒数。
func tick(delta: float) -> void:
	if delta <= 0.0 or is_nan(delta) or is_inf(delta):
		return
	_tokens = minf(capacity, _tokens + delta * refill_per_second)


## 尝试消费令牌。
## [br]
## @api public
## [br]
## @param amount: 令牌数量。
## [br]
## @return 成功消费返回 true。
func consume(amount: float = 1.0) -> bool:
	if is_nan(amount) or is_inf(amount):
		return false
	var safe_amount: float = maxf(amount, 0.0)
	if _tokens < safe_amount:
		return false
	_tokens -= safe_amount
	return true


## 获取当前令牌数。
## [br]
## @api public
## [br]
## @return 令牌数。
func get_tokens() -> float:
	return _tokens


## 重置令牌桶。
## [br]
## @api public
func reset() -> void:
	_tokens = capacity


# --- 私有/辅助方法 ---

func _normalize_non_negative_finite(value: float) -> float:
	if value < 0.0 or is_nan(value) or is_inf(value):
		return 0.0
	return value
