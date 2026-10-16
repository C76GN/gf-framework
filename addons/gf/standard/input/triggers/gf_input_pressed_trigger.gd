## GFInputPressedTrigger: 按下瞬间触发器。
##
## 只在输入从非活跃变为活跃的那一次更新中触发，适合确认、跳跃等一次性动作。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputPressedTrigger
extends GFInputTrigger


# --- 公共方法 ---

## 重置输入触发器运行时状态。
## [br]
## @api public
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 was_active: bool。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()
	state["was_active"] = false


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
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema _value: Variant，由当前输入映射产生的动作值。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 was_active: bool。
## [br]
## @return 触发状态。
func update(
	raw_active: bool,
	_value: Variant,
	_delta: float,
	state: Dictionary
) -> TriggerState:
	var was_active: bool = GFVariantData.get_option_bool(
		state,
		"was_active",
		false
	)
	state["was_active"] = raw_active
	if raw_active and not was_active:
		return TriggerState.TRIGGERED
	return TriggerState.ONGOING if raw_active else TriggerState.INACTIVE
