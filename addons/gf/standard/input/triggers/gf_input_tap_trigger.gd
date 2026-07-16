## GFInputTapTrigger: 短按触发器。
##
## 输入按下后在指定时间窗口内释放时触发一次。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputTapTrigger
extends GFInputTrigger


# --- 导出变量 ---

## 最短按住时间。
## [br]
## @api public
@export var min_tap_seconds: float = 0.0:
	set(value):
		min_tap_seconds = maxf(value, 0.0)
		if max_tap_seconds < min_tap_seconds:
			max_tap_seconds = min_tap_seconds

## 最长按住时间。
## [br]
## @api public
@export var max_tap_seconds: float = 0.25:
	set(value):
		max_tap_seconds = maxf(value, min_tap_seconds)


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
## @param delta: 本帧时间增量（秒）。
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema _value: Variant，由当前输入映射产生的动作值。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。
## [br]
## @return 触发状态。
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
	var was_active: bool = GFVariantData.get_option_bool(state, "was_active", false)
	var elapsed: float = GFVariantData.get_option_float(state, "elapsed", 0.0)

	if raw_active:
		elapsed = 0.0 if not was_active else elapsed + maxf(delta, 0.0)
		state["elapsed"] = elapsed
		state["was_active"] = true
		return TriggerState.ONGOING

	if was_active:
		elapsed += maxf(delta, 0.0)
	state["was_active"] = false
	state["elapsed"] = 0.0
	if was_active and elapsed >= min_tap_seconds and elapsed <= max_tap_seconds:
		return TriggerState.TRIGGERED
	return TriggerState.INACTIVE
