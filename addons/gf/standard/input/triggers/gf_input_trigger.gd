## GFInputTrigger: 输入动作触发器基类。
##
## 触发器只决定“原始输入活跃后何时视为动作活跃”，不修改输入值。运行时状态由
## GFInputMappingUtility 传入的 Dictionary 保存，因此同一资源可被多个上下文复用。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFInputTrigger
extends Resource


# --- 枚举 ---

## 触发器本次更新后的动作状态。
## [br]
## @api public
enum TriggerState {
	## 输入未达到触发条件。
	INACTIVE,
	## 输入正在等待触发条件，例如长按计时中。
	ONGOING,
	## 输入已满足触发条件。
	TRIGGERED,
}


# --- 公共方法 ---

## 重置运行时状态。
## [br]
## @api public
## [br]
## @param state: 由调用方保存的状态字典。
## [br]
## @schema state: Dictionary，由输入运行时为当前 trigger 实例持有。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()


## 更新前注入运行时上下文。
## [br]
## @api public
## [br]
## @param _action_id: 当前动作标识。
## [br]
## @param _input_runtime: 输入映射运行时。
## [br]
## @param _player_index: 玩家索引；全局动作传 -1。
## [br]
## @param _state: 该触发器的运行时状态。
## [br]
## @schema _state: Dictionary，由输入运行时为当前 trigger 实例持有。
func prepare_runtime(
	_action_id: StringName,
	_input_runtime: Object,
	_player_index: int,
	_state: Dictionary
) -> void:
	pass


## 更新触发器状态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param raw_active: 原始输入是否活跃。
## [br]
## @param _value: 当前动作值。
## [br]
## @param _delta: 本次更新经过的秒数；事件驱动刷新时可能为 0。
## [br]
## @param _state: 该触发器的运行时状态。
## [br]
## @schema _value: Variant，由当前输入映射产生的动作值。
## [br]
## @schema _state: Dictionary，由输入运行时为当前 trigger 实例持有。
## [br]
## @return 触发状态。
func update(
	raw_active: bool,
	_value: Variant,
	_delta: float,
	_state: Dictionary
) -> TriggerState:
	return TriggerState.TRIGGERED if raw_active else TriggerState.INACTIVE


## 创建运行时副本。
## [br]
## @api public
## [br]
## @return 触发器副本。
func duplicate_trigger() -> GFInputTrigger:
	var trigger: Resource = duplicate(true)
	if trigger is GFInputTrigger:
		var input_trigger: GFInputTrigger = trigger
		return input_trigger
	return null
