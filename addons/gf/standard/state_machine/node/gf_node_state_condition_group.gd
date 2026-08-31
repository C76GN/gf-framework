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


# --- 常量 ---

const _MAX_EVALUATION_DEPTH: int = 64
const _MAX_EVALUATED_CONDITIONS: int = 4096


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


# --- 公共方法 ---

## 评估条件组。递归条件图出现循环、超过深度或工作量上限时始终失败，invert 不会反转该失败。
## [br]
## @api public
## [br]
## @since 11.0.0
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
## @return: 条件图有效且组合结果通过时返回 true。
func evaluate(
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName = &"",
	args: Dictionary = {}
) -> bool:
	var result: Dictionary = _evaluate_with_context(
		state,
		phase,
		peer_state,
		args,
		_make_evaluation_context(),
		0
	)
	if not GFVariantData.get_option_bool(result, "valid", false):
		return false
	var accepted: bool = GFVariantData.get_option_bool(result, "accepted", false)
	return not accepted if invert else accepted


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
	var result: Dictionary = _evaluate_with_context(
		state,
		phase,
		peer_state,
		args,
		_make_evaluation_context(),
		0
	)
	return (
		GFVariantData.get_option_bool(result, "valid", false)
		and GFVariantData.get_option_bool(result, "accepted", false)
	)


# --- 私有/辅助方法 ---

func _evaluate_with_context(
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName,
	args: Dictionary,
	context: Dictionary,
	depth: int
) -> Dictionary:
	if depth >= _MAX_EVALUATION_DEPTH or not _consume_evaluation_budget(context):
		return { "valid": false, "accepted": false }

	var active_group_ids: Dictionary = context["active_group_ids"]
	var instance_id: int = get_instance_id()
	if active_group_ids.has(instance_id):
		return { "valid": false, "accepted": false }

	active_group_ids[instance_id] = true
	var result: Dictionary = _evaluate_conditions(
		state,
		phase,
		peer_state,
		args,
		context,
		depth
	)
	var _erased_active_group: bool = active_group_ids.erase(instance_id)
	return result


func _evaluate_conditions(
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName,
	args: Dictionary,
	context: Dictionary,
	depth: int
) -> Dictionary:
	var evaluated_count: int = 0
	match mode:
		MatchMode.ANY:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				var child_result: Dictionary = _evaluate_child_with_context(
					condition,
					state,
					phase,
					peer_state,
					args,
					context,
					depth + 1
				)
				if not GFVariantData.get_option_bool(child_result, "valid", false):
					return child_result
				if GFVariantData.get_option_bool(child_result, "accepted", false):
					return { "valid": true, "accepted": true }
			return { "valid": true, "accepted": empty_result if evaluated_count == 0 else false }
		MatchMode.NONE:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				var child_result: Dictionary = _evaluate_child_with_context(
					condition,
					state,
					phase,
					peer_state,
					args,
					context,
					depth + 1
				)
				if not GFVariantData.get_option_bool(child_result, "valid", false):
					return child_result
				if GFVariantData.get_option_bool(child_result, "accepted", false):
					return { "valid": true, "accepted": false }
			return { "valid": true, "accepted": empty_result if evaluated_count == 0 else true }
		_:
			for condition: Resource in conditions:
				if not _is_valid_condition(condition):
					continue
				evaluated_count += 1
				var child_result: Dictionary = _evaluate_child_with_context(
					condition,
					state,
					phase,
					peer_state,
					args,
					context,
					depth + 1
				)
				if not GFVariantData.get_option_bool(child_result, "valid", false):
					return child_result
				if not GFVariantData.get_option_bool(child_result, "accepted", false):
					return { "valid": true, "accepted": false }
			return { "valid": true, "accepted": empty_result if evaluated_count == 0 else true }

func _is_valid_condition(condition: Resource) -> bool:
	return condition != null and condition.has_method("evaluate")


func _evaluate_child_with_context(
	condition: Resource,
	state: GFNodeState,
	phase: StringName,
	peer_state: StringName,
	args: Dictionary,
	context: Dictionary,
	depth: int
) -> Dictionary:
	if condition is GFNodeStateConditionGroup:
		var condition_group: GFNodeStateConditionGroup = condition
		var group_result: Dictionary = condition_group._evaluate_with_context(
			state,
			phase,
			peer_state,
			args,
			context,
			depth
		)
		if not GFVariantData.get_option_bool(group_result, "valid", false):
			return group_result
		var group_accepted: bool = GFVariantData.get_option_bool(group_result, "accepted", false)
		return {
			"valid": true,
			"accepted": not group_accepted if condition_group.invert else group_accepted,
		}

	if not _consume_evaluation_budget(context):
		return { "valid": false, "accepted": false }
	var result: Variant = condition.call("evaluate", state, phase, peer_state, args)
	return {
		"valid": true,
		"accepted": GFVariantData.to_bool(result, false),
	}


func _make_evaluation_context() -> Dictionary:
	return {
		"active_group_ids": {},
		"evaluated_count": 0,
	}


func _consume_evaluation_budget(context: Dictionary) -> bool:
	var evaluated_count: int = GFVariantData.get_option_int(context, "evaluated_count") + 1
	context["evaluated_count"] = evaluated_count
	return evaluated_count <= _MAX_EVALUATED_CONDITIONS
