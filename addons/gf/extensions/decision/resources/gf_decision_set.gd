## GFDecisionSet: 候选决策集合。
##
## 负责对多个 GFDecisionOption 统一评分、排序并选择分数最高的候选。
## 集合只返回评分结果，不直接执行业务动作。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.3.0
class_name GFDecisionSet
extends Resource


# --- 导出变量 ---

## 候选决策集合标识。
## [br]
## @api public
@export var decision_set_id: StringName = &""

## 候选决策列表。
## [br]
## @api public
## [br]
## @schema decisions: Array[GFDecisionOption]，按顺序评分并用于同分时稳定排序。
@export var decisions: Array[GFDecisionOption] = []

## 可被选择的最低分数。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var minimum_score: float = 0.0

## 是否在 score_all() 中包含禁用候选。
## [br]
## @api public
@export var include_disabled_in_reports: bool = false

## 项目自定义元数据，框架不解释其中内容。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[StringName, Variant] project-defined decision-set metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加候选决策。
## [br]
## @api public
## [br]
## @param decision: 要添加的候选决策。
## [br]
## @return: 添加成功返回 true。
func add_decision(decision: GFDecisionOption) -> bool:
	if decision == null:
		return false
	decisions.append(decision)
	return true


## 获取候选决策。
## [br]
## @api public
## [br]
## @param decision_id: 候选决策标识。
## [br]
## @return: 找到的候选决策；不存在时返回 null。
func get_decision(decision_id: StringName) -> GFDecisionOption:
	for decision: GFDecisionOption in decisions:
		if decision != null and decision.decision_id == decision_id:
			return decision
	return null


## 检查候选决策是否存在。
## [br]
## @api public
## [br]
## @param decision_id: 候选决策标识。
## [br]
## @return: 存在返回 true。
func has_decision(decision_id: StringName) -> bool:
	return get_decision(decision_id) != null


## 移除候选决策。
## [br]
## @api public
## [br]
## @param decision_id: 候选决策标识。
## [br]
## @return: 移除成功返回 true。
func remove_decision(decision_id: StringName) -> bool:
	for index: int in range(decisions.size() - 1, -1, -1):
		var decision: GFDecisionOption = decisions[index]
		if decision != null and decision.decision_id == decision_id:
			decisions.remove_at(index)
			return true
	return false


## 清空候选决策。
## [br]
## @api public
func clear_decisions() -> void:
	decisions.clear()


## 计算所有候选决策分数。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 按分数降序排列的评分结果。
## [br]
## @schema return: Array[GFDecisionScore]，每个候选的评分结果。
func score_all(context: GFDecisionContext) -> Array[GFDecisionScore]:
	var scores: Array[GFDecisionScore] = []
	for decision: GFDecisionOption in decisions:
		if decision == null:
			continue
		if not decision.enabled and not include_disabled_in_reports:
			continue
		scores.append(decision.score(context))
	scores.sort_custom(_sort_score_desc)
	return scores


## 选择分数最高的候选决策。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 最佳评分结果；没有可选候选时返回 rejected score。
func select_best(context: GFDecisionContext) -> GFDecisionScore:
	var scores: Array[GFDecisionScore] = score_all(context)
	for candidate_score: GFDecisionScore in scores:
		if candidate_score != null and candidate_score.accepted and candidate_score.score >= minimum_score:
			return candidate_score
	return GFDecisionScore.new(null, 0.0, [], false)


## 获取集合调试快照。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 decision_set_id、decision_count、minimum_score、scores 和 metadata 字段的 Dictionary。
func get_debug_snapshot(context: GFDecisionContext) -> Dictionary:
	var score_dictionaries: Array[Dictionary] = []
	for candidate_score: GFDecisionScore in score_all(context):
		if candidate_score != null:
			score_dictionaries.append(candidate_score.to_dictionary())
	return {
		"decision_set_id": decision_set_id,
		"decision_count": decisions.size(),
		"minimum_score": minimum_score,
		"scores": score_dictionaries,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _sort_score_desc(left: GFDecisionScore, right: GFDecisionScore) -> bool:
	if left == null:
		return false
	if right == null:
		return true
	if not is_equal_approx(left.score, right.score):
		return left.score > right.score
	return _decision_index(left.decision) < _decision_index(right.decision)


func _decision_index(decision: GFDecisionOption) -> int:
	if decision == null:
		return 999999
	for index: int in range(decisions.size()):
		if decisions[index] == decision:
			return index
	return 999999
