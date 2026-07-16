# Action Queue 内部时间参数策略。
extends RefCounted


# --- 层内方法 ---

## 将秒数收敛为有限非负值；非法输入返回有限 fallback。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param seconds: 待校验秒数。
## [br]
## @param fallback_seconds: 非法输入使用的回退秒数。
## [br]
## @return 有限且不小于零的秒数。
static func sanitize_non_negative_seconds(
	seconds: float,
	fallback_seconds: float = 0.0
) -> float:
	var safe_fallback: float = fallback_seconds
	if not is_finite(safe_fallback) or safe_fallback < 0.0:
		safe_fallback = 0.0
	if not is_finite(seconds) or seconds < 0.0:
		return safe_fallback
	return seconds


## 判断秒数是否为有限非负值。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param seconds: 待校验秒数。
## [br]
## @return 输入有限且不小于零时返回 true。
static func is_valid_non_negative_seconds(seconds: float) -> bool:
	return is_finite(seconds) and seconds >= 0.0
