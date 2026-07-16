## GFNodeStateActiveCondition: 按状态机当前状态判断的节点状态条件。
##
## 用于让状态进入或退出守卫依赖同组、跨组或暂停栈中的状态是否处于激活状态。
## 它只读取状态机运行态，不解释具体业务状态含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFNodeStateActiveCondition
extends GFNodeStateCondition


# --- 枚举 ---

## 状态匹配模式。
## [br]
## @api public
## [br]
## @since 8.0.0
enum MatchMode {
	## 任意状态路径处于激活状态即可。
	ANY,
	## 所有状态路径都必须处于激活状态。
	ALL,
	## 所有状态路径都不能处于激活状态。
	NONE,
}


# --- 导出变量 ---

## 要检查的状态路径。可使用 "State" 指向同组状态，或 "Group/State" 指向指定状态组。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var state_paths: PackedStringArray = PackedStringArray()

## 状态匹配模式。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var mode: MatchMode = MatchMode.ANY

## 没有有效状态路径时返回的结果。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var empty_result: bool = false


# --- 可重写钩子 / 虚方法 ---

## 条件评估扩展点。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param state: 当前条件所属状态。
## [br]
## @param _phase: 条件阶段，通常为 enter 或 exit。
## [br]
## @param _peer_state: 进入时为来源状态名，退出时为目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @return: 状态匹配通过时返回 true。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _evaluate(
	state: GFNodeState,
	_phase: StringName,
	_peer_state: StringName = &"",
	_args: Dictionary = {}
) -> bool:
	if state == null:
		return false

	var checked_count: int = 0
	match mode:
		MatchMode.ALL:
			for state_path: String in state_paths:
				if state_path.strip_edges().is_empty():
					continue
				checked_count += 1
				if not _is_state_active(state, state_path):
					return false
			return empty_result if checked_count == 0 else true
		MatchMode.NONE:
			for state_path: String in state_paths:
				if state_path.strip_edges().is_empty():
					continue
				checked_count += 1
				if _is_state_active(state, state_path):
					return false
			return empty_result if checked_count == 0 else true
		_:
			for state_path: String in state_paths:
				if state_path.strip_edges().is_empty():
					continue
				checked_count += 1
				if _is_state_active(state, state_path):
					return true
			return empty_result if checked_count == 0 else false


# --- 私有/辅助方法 ---

func _is_state_active(state: GFNodeState, state_path: String) -> bool:
	var normalized_path: String = state_path.strip_edges()
	if normalized_path.is_empty():
		return false

	if normalized_path.contains("/"):
		var machine: Object = state.get_machine()
		if machine != null and machine.has_method("is_in_state"):
			return GFVariantData.to_bool(machine.call("is_in_state", StringName(normalized_path)), false)
		return false

	var group: Object = state.get_group()
	if group != null and group.has_method("is_in_state"):
		return GFVariantData.to_bool(group.call("is_in_state", StringName(normalized_path)), false)
	return false
