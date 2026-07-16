## GFNodeStateConditionGroup: 节点状态条件组合资源。
##
## 用于把多个 GFNodeStateCondition 或兼容 evaluate() 的 Resource 组合为 ALL / ANY / NONE 判断。
## 条件组只返回布尔结果，不直接切换状态或修改状态机结构。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFNodeStateConditionGroup
extends GFNodeStateCondition


# --- 枚举 ---

## 条件组合模式。
## [br]
## @api public
## [br]
## @since 8.0.0
enum MatchMode {
	## 所有有效条件都必须通过。
	ALL,
	## 任意有效条件通过即可。
	ANY,
	## 所有有效条件都不能通过。
	NONE,
}


# --- 导出变量 ---

## 条件组合模式。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var mode: MatchMode = MatchMode.ALL

## 子条件资源。null 或没有 evaluate() 方法的资源会被忽略。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema conditions: Array[Resource]，元素为 GFNodeStateCondition 或兼容 evaluate(state, phase, peer_state, args) 的 Resource。
@export var conditions: Array[Resource] = []

## 没有有效子条件时返回的结果。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var empty_result: bool = true


# --- 可重写钩子 / 虚方法 ---

## 条件评估扩展点。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param state: 当前条件所属状态。
## [br]
## @param phase: 条件阶段，通常为 enter 或 exit。
## [br]
## @param peer_state: 进入时为来源状态名，退出时为目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @return: 条件组通过时返回 true。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func _evaluate(
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName = &"",
	args: Dictionary = {}
) -> bool:
	var evaluated_count: int = 0
	match mode:
		MatchMode.ANY:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				if _evaluate_child(condition, state, phase, peer_state, args):
					return true
			return empty_result if evaluated_count == 0 else false
		MatchMode.NONE:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				if _evaluate_child(condition, state, phase, peer_state, args):
					return false
			return empty_result if evaluated_count == 0 else true
		_:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				if not _evaluate_child(condition, state, phase, peer_state, args):
					return false
			return empty_result if evaluated_count == 0 else true


# --- 私有/辅助方法 ---

func _is_valid_condition(condition: Resource) -> bool:
	return condition != null and condition.has_method("evaluate")


func _evaluate_child(
	condition: Resource,
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName,
	args: Dictionary
) -> bool:
	var result: Variant = condition.call("evaluate", state, phase, peer_state, args)
	return GFVariantData.to_bool(result, false)
