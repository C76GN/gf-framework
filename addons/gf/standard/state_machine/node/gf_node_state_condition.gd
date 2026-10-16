## GFNodeStateCondition: 节点状态的可复用进入/退出条件资源。
##
## 条件只负责判断状态切换是否允许，不直接执行切换或修改状态机结构。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNodeStateCondition
extends Resource


# --- 导出变量 ---

## 条件标识，便于调试或项目工具识别。
## [br]
## @api public
@export var condition_id: StringName = &""

## 是否反转 evaluate() 的结果。
## [br]
## @api public
@export var invert: bool = false

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；键和值由项目侧约定。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 评估条件。
## [br]
## @api public
## [br]
## @param state: 当前条件所属状态。
## [br]
## @param phase: 条件阶段，通常为 enter 或 exit。
## [br]
## @param peer_state: 进入时为来源状态名，退出时为目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return 条件通过时返回 true。
func evaluate(
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName = &"",
	args: Dictionary = {}
) -> bool:
	var accepted: bool = _evaluate(
		state,
		phase,
		peer_state,
		args
	)
	return not accepted if invert else accepted


# --- 可重写钩子 / 虚方法 ---

## 条件评估扩展点。
## [br]
## @api protected
## [br]
## @param _state: 当前条件所属状态。
## [br]
## @param _phase: 条件阶段，通常为 enter 或 exit。
## [br]
## @param _peer_state: 进入时为来源状态名，退出时为目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 条件通过时返回 true。
func _evaluate(
	_state: GFNodeState,
	_phase: StringName,
	_peer_state: StringName = &"",
	_args: Dictionary = {}
) -> bool:
	return true
