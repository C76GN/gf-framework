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


# --- 常量 ---

const _GF_DECISION_NUMERIC_POLICY = preload("res://addons/gf/extensions/decision/runtime/gf_decision_numeric_policy.gd")


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
	if decision == null or decision.decision_id == &"":
		return false
	if has_decision(decision.decision_id):
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
	for index: int in range(decisions.size()):
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
	var seen_decisions: Dictionary = {}
	for index: int in range(decisions.size()):
		var decision: GFDecisionOption = decisions[index]
		if decision == null:
			continue
		if decision.decision_id == &"" or seen_decisions.has(decision.decision_id):
			continue
		seen_decisions[decision.decision_id] = true
		if not decision.enabled and not include_disabled_in_reports:
			continue
		var candidate_score: GFDecisionScore = decision.score(context)
		candidate_score.decision_order = index
		scores.append(candidate_score)
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
	return select_best_from_scores(scores)


## 从已计算评分中选择分数最高的候选决策。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scores: 已计算的候选评分。
## [br]
## @return: 最佳评分结果；没有可选候选时返回 rejected score。
## [br]
## @schema scores: Array[GFDecisionScore]，通常来自 score_all() 或 GFDecisionEvaluation.scores。
func select_best_from_scores(scores: Array[GFDecisionScore]) -> GFDecisionScore:
	var required_score: float = _normalized_minimum_score()
	for candidate_score: GFDecisionScore in scores:
		if candidate_score != null and candidate_score.accepted and candidate_score.score >= required_score:
			return candidate_score
	return GFDecisionScore.new(null, 0.0, [], false)


## 一次性评价集合并返回评分、最佳候选和调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: 决策上下文。
## [br]
## @return: 决策评价结果。
func evaluate(context: GFDecisionContext) -> GFDecisionEvaluation:
	var scores: Array[GFDecisionScore] = score_all(context)
	var best_score: GFDecisionScore = select_best_from_scores(scores)
	var snapshot: Dictionary = get_debug_snapshot(null, scores)
	var evaluation: GFDecisionEvaluation = GFDecisionEvaluation.new()
	return evaluation.configure(decision_set_id, scores, best_score, snapshot)


## 获取集合调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 决策上下文；scores 为 null 时用于现场评分。
## [br]
## @param scores: 已计算的评分快照；显式传入空数组也不会重新评分。
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 decision_set_id、decision_count、minimum_score、scores 和 metadata 字段的 Dictionary。
## [br]
## @schema scores: Variant，可为 null 或 Array[GFDecisionScore]；null 表示按 context 现场评分，Array 表示完整预计算结果。
func get_debug_snapshot(context: GFDecisionContext = null, scores: Variant = null) -> Dictionary:
	var resolved_scores: Array[GFDecisionScore] = _resolve_score_snapshot(context, scores)
	var score_dictionaries: Array[Dictionary] = []
	for candidate_score: GFDecisionScore in resolved_scores:
		if candidate_score != null:
			score_dictionaries.append(candidate_score.to_dictionary())
	return GFReportValueCodec.to_report_dictionary({
		"decision_set_id": decision_set_id,
		"decision_count": decisions.size(),
		"minimum_score": _normalized_minimum_score(),
		"scores": score_dictionaries,
		"metadata": metadata.duplicate(true),
	})


## 获取集合资源的 authoring 校验报告。
## [br]
## @api public
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, healthy, decision_set_id, issues, summary, and next_action.
func get_validation_report() -> Dictionary:
	var report: Dictionary = {
		"subject": "Decision set",
		"decision_set_id": decision_set_id,
		"issues": [],
	}
	if decision_set_id == &"":
		_append_validation_issue(report, &"missing_decision_set_id", "decision_set_id is required", "decision_set_id")
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_score(minimum_score):
		_append_validation_issue(report, &"invalid_minimum_score", "minimum_score must be finite and within 0 to 1", "minimum_score")

	var seen_ids: Dictionary = {}
	for index: int in range(decisions.size()):
		var decision: GFDecisionOption = decisions[index]
		if decision == null:
			_append_validation_issue(report, &"missing_decision", "decision is null", "decisions[%d]" % index)
			continue
		if decision.decision_id == &"":
			_append_validation_issue(report, &"missing_decision_id", "decision_id is required", "decisions[%d].decision_id" % index)
		elif seen_ids.has(decision.decision_id):
			_append_validation_issue(report, &"duplicate_decision_id", "decision_id is duplicated", "decisions[%d].decision_id" % index)
		else:
			seen_ids[decision.decision_id] = true
		_append_option_validation_issues(report, decision, index)

	return GFValidationReportDictionary.finalize_report(report, "Decision set", {
		"fallback_action": "Review the first decision set issue.",
		"no_action": "Decision set is valid.",
	})


# --- 私有/辅助方法 ---

func _sort_score_desc(left: GFDecisionScore, right: GFDecisionScore) -> bool:
	if left == null:
		return false
	if right == null:
		return true
	if left.score != right.score:
		return left.score > right.score
	return _normalized_order(left.decision_order) < _normalized_order(right.decision_order)


func _normalized_order(order: int) -> int:
	if order < 0:
		return 999999
	return order


func _normalized_minimum_score() -> float:
	return _GF_DECISION_NUMERIC_POLICY.normalize_score(minimum_score, 1.0)


func _resolve_score_snapshot(context: GFDecisionContext, scores: Variant) -> Array[GFDecisionScore]:
	if scores == null:
		return score_all(context) if context != null else []
	var result: Array[GFDecisionScore] = []
	if not scores is Array:
		return result
	var score_values: Array = scores
	for score_value: Variant in score_values:
		if score_value is GFDecisionScore:
			var candidate_score: GFDecisionScore = score_value
			result.append(candidate_score)
	return result


func _append_option_validation_issues(
	report: Dictionary,
	decision: GFDecisionOption,
	index: int
) -> void:
	var option_report: Dictionary = decision.get_validation_report()
	for issue_value: Variant in GFVariantData.get_option_array(option_report, "issues"):
		var issue: Dictionary = GFValidationReportDictionary.issue_to_dict(issue_value)
		var option_path: String = GFVariantData.get_option_string(issue, "path")
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			GFVariantData.get_option_string(issue, "severity", "error"),
			GFVariantData.get_option_string_name(issue, "kind", &"invalid_decision"),
			GFVariantData.get_option_string(issue, "message", "decision is invalid"),
			{
				"key": decision.decision_id,
				"row_index": index,
				"path": "decisions[%d].%s" % [index, option_path],
			}
		)


func _append_validation_issue(
	report: Dictionary,
	kind: StringName,
	message: String,
	path: String
) -> void:
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		{
			"key": decision_set_id,
			"path": path,
		}
	)
