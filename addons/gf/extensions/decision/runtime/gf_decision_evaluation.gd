## GFDecisionEvaluation: 一次决策集合评价的结果快照。
##
## 保存同一次评分产生的 scores、best_score 和调试快照，避免调用方为了选择、
## 诊断和记录日志重复触发评分。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFDecisionEvaluation
extends RefCounted


# --- 公共变量 ---

## 决策集合标识。
## [br]
## @api public
## [br]
## @since 8.0.0
var decision_set_id: StringName = &""

## 本次评价的评分结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema scores: Array[GFDecisionScore] copied from one score_all() pass.
var scores: Array[GFDecisionScore] = []

## 本次评价选出的最佳分数。
## [br]
## @api public
## [br]
## @since 8.0.0
var best_score: GFDecisionScore = null

## 本次评价的调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema debug_snapshot: Dictionary copied from GFDecisionSet.get_debug_snapshot().
var debug_snapshot: Dictionary = {}


# --- 公共方法 ---

## 配置评价结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_decision_set_id: 决策集合标识。
## [br]
## @param p_scores: 本次评分结果。
## [br]
## @param p_best_score: 本次最佳分数。
## [br]
## @param p_debug_snapshot: 本次调试快照。
## [br]
## @return 当前评价对象。
## [br]
## @schema p_scores: Array[GFDecisionScore] copied into the evaluation.
## [br]
## @schema p_debug_snapshot: Dictionary copied from GFDecisionSet.get_debug_snapshot().
func configure(
	p_decision_set_id: StringName,
	p_scores: Array[GFDecisionScore],
	p_best_score: GFDecisionScore,
	p_debug_snapshot: Dictionary = {}
) -> GFDecisionEvaluation:
	decision_set_id = p_decision_set_id
	scores = _copy_scores(p_scores)
	best_score = _copy_best_score(p_best_score, scores)
	debug_snapshot = p_debug_snapshot.duplicate(true)
	return self


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 评价结果字典。
## [br]
## @schema return: Dictionary with decision_set_id, scores, best_score, and debug_snapshot.
func to_dictionary() -> Dictionary:
	var score_dictionaries: Array[Dictionary] = []
	for candidate_score: GFDecisionScore in scores:
		if candidate_score != null:
			score_dictionaries.append(candidate_score.to_dictionary())
	return {
		"decision_set_id": decision_set_id,
		"scores": score_dictionaries,
		"best_score": best_score.to_dictionary() if best_score != null else {},
		"debug_snapshot": debug_snapshot.duplicate(true),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 评价结果调试快照。
## [br]
## @schema return: 基于 to_dictionary() 编码的 JSON-safe 评价结果 Dictionary。
func get_debug_snapshot() -> Dictionary:
	return to_report_dictionary()


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 评价报告字典。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dictionary().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dictionary(), options)


# --- 私有/辅助方法 ---

func _copy_scores(source_scores: Array[GFDecisionScore]) -> Array[GFDecisionScore]:
	var result: Array[GFDecisionScore] = []
	for candidate_score: GFDecisionScore in source_scores:
		var copied_score: GFDecisionScore = _copy_score(candidate_score)
		if copied_score != null:
			result.append(copied_score)
	return result


func _copy_best_score(source_score: GFDecisionScore, copied_scores: Array[GFDecisionScore]) -> GFDecisionScore:
	if source_score == null:
		return GFDecisionScore.new(null, 0.0, [], false)
	for copied_score: GFDecisionScore in copied_scores:
		if (
			copied_score != null
			and copied_score.decision_id == source_score.decision_id
			and copied_score.decision_order == source_score.decision_order
		):
			return copied_score
	return _copy_score(source_score)


func _copy_score(source_score: GFDecisionScore) -> GFDecisionScore:
	if source_score == null:
		return null
	var copied_score: GFDecisionScore = GFDecisionScore.new()
	copied_score.decision_id = source_score.decision_id
	copied_score.decision_order = source_score.decision_order
	copied_score.score = source_score.score
	copied_score.accepted = source_score.accepted
	copied_score.consideration_scores = source_score.consideration_scores.duplicate(true)
	copied_score.metadata = source_score.metadata.duplicate(true)
	return copied_score
