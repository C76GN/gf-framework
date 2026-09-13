## GFInputPulseTrigger: 周期脉冲触发器。
##
## 输入持续活跃时按固定间隔触发一次，可用于连发、菜单重复导航等通用场景。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputPulseTrigger
extends GFInputTrigger


# --- 导出变量 ---

## 脉冲间隔秒数。非有限赋值会被拒绝并保留最后有效值。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var interval_seconds: float = 0.1:
	set(value):
		if not is_finite(value):
			return
		interval_seconds = maxf(value, 0.001)

## 首次周期脉冲的等待秒数，从输入激活时开始计时；有限负值统一存为 -1，表示使用 interval_seconds。
## 0 表示激活时触发一次，并与 trigger_immediately 的脉冲合并，随后等待完整周期。
## 非有限赋值会被拒绝并保留最后有效值。
## [br]
## @api public
## [br]
## @since unreleased
@export var initial_delay_seconds: float = -1.0:
	set(value):
		if not is_finite(value):
			return
		initial_delay_seconds = -1.0 if value < 0.0 else value

## 输入首次变为活跃时是否立即触发；initial_delay_seconds 为 0 时始终在激活时触发一次。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var trigger_immediately: bool = true


# --- 公共方法 ---

## 重置输入触发器运行时状态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时按动作和玩家隔离持有，包含 was_active: bool、initial_wait_pending: bool 和 elapsed: float。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()
	state["was_active"] = false
	state["initial_wait_pending"] = true
	state["elapsed"] = 0.0


## 更新运行时状态；每次最多返回一个脉冲，跨期只保留周期余数，不补发历史脉冲。
## 激活时产生即时脉冲会忽略当次 delta；否则首次等待消费当次 delta。
## 持续活跃期间只有有限正 delta 才能触发新的脉冲，事件刷新不会重复触发。
## 首次等待仅在等待阶段读取，周期每次读取；修改共享配置会影响引用它的动作，但不会共享计时进度。
## [br]
## @api public
## [br]
## @param raw_active: 原始输入是否处于激活状态。
## [br]
## @param _value: 输入值，默认实现不直接使用。
## [br]
## @param delta: 本帧时间增量（秒）；NaN/Infinity 或负数按 0 处理，不污染状态。
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema _value: Variant，由当前输入映射产生的动作值。
## [br]
## @schema state: Dictionary，由输入运行时按动作和玩家隔离持有，包含 was_active: bool、initial_wait_pending: bool 和 elapsed: float；elapsed 表示首次等待已用时间或周期余数。
## [br]
## @return 触发状态。
## [br]
## @since 11.0.0
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
	if not raw_active:
		state["was_active"] = false
		state["initial_wait_pending"] = true
		state["elapsed"] = 0.0
		return TriggerState.INACTIVE

	var safe_interval: float = interval_seconds if is_finite(interval_seconds) else 0.001
	safe_interval = maxf(safe_interval, 0.001)
	var first_delay: float = initial_delay_seconds
	if not is_finite(first_delay) or first_delay < 0.0:
		first_delay = safe_interval
	if not GFVariantData.get_option_bool(state, "was_active", false):
		state["was_active"] = true
		state["initial_wait_pending"] = first_delay > 0.0
		state["elapsed"] = 0.0
		if trigger_immediately or first_delay == 0.0:
			return TriggerState.TRIGGERED

	var initial_wait_pending: bool = GFVariantData.get_option_bool(state, "initial_wait_pending", true)
	var elapsed: float = GFVariantData.get_option_float(state, "elapsed", 0.0)
	if not is_finite(elapsed) or elapsed < 0.0:
		elapsed = 0.0
	elif not initial_wait_pending and elapsed >= safe_interval:
		elapsed = fmod(elapsed, safe_interval)
	state["elapsed"] = elapsed
	var safe_delta: float = delta if is_finite(delta) and delta > 0.0 else 0.0
	if safe_delta == 0.0:
		return TriggerState.ONGOING

	if initial_wait_pending:
		var remaining_initial_wait: float = maxf(first_delay - elapsed, 0.0)
		if safe_delta < remaining_initial_wait:
			state["elapsed"] = elapsed + safe_delta
			return TriggerState.ONGOING
		state["initial_wait_pending"] = false
		var overdue: float = maxf(elapsed - first_delay, 0.0)
		state["elapsed"] = _wrap_elapsed(overdue, safe_delta - remaining_initial_wait, safe_interval)
		return TriggerState.TRIGGERED

	var remaining_until_pulse: float = safe_interval - elapsed
	if safe_delta >= remaining_until_pulse:
		state["elapsed"] = _wrap_elapsed(elapsed, safe_delta, safe_interval)
		return TriggerState.TRIGGERED

	state["elapsed"] = elapsed + safe_delta
	return TriggerState.ONGOING


# --- 私有/辅助方法 ---

func _wrap_elapsed(elapsed: float, delta: float, interval: float) -> float:
	var elapsed_remainder: float = fmod(elapsed, interval)
	var delta_remainder: float = fmod(delta, interval)
	var remaining: float = interval - elapsed_remainder
	# 先比较再相加，避免两个巨大但有限的余数相加溢出。
	if delta_remainder >= remaining:
		return delta_remainder - remaining
	return elapsed_remainder + delta_remainder
