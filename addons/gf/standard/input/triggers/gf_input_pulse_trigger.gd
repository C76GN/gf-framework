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

## 输入首次变为活跃时是否立即触发。
## [br]
## @api public
@export var trigger_immediately: bool = true


# --- 公共方法 ---

## 重置输入触发器运行时状态。
## [br]
## @api public
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()
	state["was_active"] = false
	state["elapsed"] = 0.0


## 更新运行时状态。
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
## @schema state: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。
## [br]
## @return 触发状态。
## [br]
## @since 11.0.0
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
	var was_active: bool = GFVariantData.get_option_bool(state, "was_active", false)
	if not raw_active:
		state["was_active"] = false
		state["elapsed"] = 0.0
		return TriggerState.INACTIVE

	if trigger_immediately and not was_active:
		state["was_active"] = true
		state["elapsed"] = 0.0
		return TriggerState.TRIGGERED

	var safe_interval: float = interval_seconds if is_finite(interval_seconds) else 0.001
	safe_interval = maxf(safe_interval, 0.001)
	var elapsed: float = GFVariantData.get_option_float(state, "elapsed", 0.0)
	if not is_finite(elapsed) or elapsed < 0.0:
		elapsed = 0.0
	elif elapsed >= safe_interval:
		elapsed = fmod(elapsed, safe_interval)
	var safe_delta: float = delta if is_finite(delta) and delta > 0.0 else 0.0
	var remaining_until_pulse: float = safe_interval - elapsed
	if safe_delta >= remaining_until_pulse:
		var delta_remainder: float = fmod(safe_delta, safe_interval)
		state["elapsed"] = fmod(elapsed + delta_remainder, safe_interval)
		state["was_active"] = true
		return TriggerState.TRIGGERED

	state["elapsed"] = elapsed + safe_delta
	state["was_active"] = true
	return TriggerState.ONGOING
