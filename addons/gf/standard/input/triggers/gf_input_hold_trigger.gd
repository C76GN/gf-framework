## GFInputHoldTrigger: 长按触发器。
##
## 输入持续活跃达到 hold_seconds 后，动作才进入活跃状态。释放输入会重置计时。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputHoldTrigger
extends GFInputTrigger


# --- 导出变量 ---

## 需要持续按住的秒数。
## [br]
## @api public
@export var hold_seconds: float = 0.25:
	set(value):
		hold_seconds = maxf(value, 0.0)


# --- 公共方法 ---

## 重置输入触发器运行时状态。
## [br]
## @api public
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 elapsed: float。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()
	state["elapsed"] = 0.0


## 更新运行时状态。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @schema state: Dictionary，由输入运行时持有，包含 elapsed: float。
## [br]
## @return 触发状态。
func update(
	raw_active: bool,
	_value: Variant,
	delta: float,
	state: Dictionary
) -> TriggerState:
	if not raw_active:
		state["elapsed"] = 0.0
		return TriggerState.INACTIVE

	var elapsed: float = GFVariantData.get_option_float(
		state,
		"elapsed",
		0.0
	)
	elapsed += maxf(delta, 0.0)
	state["elapsed"] = elapsed
	if elapsed >= hold_seconds:
		return TriggerState.TRIGGERED
	return TriggerState.ONGOING
