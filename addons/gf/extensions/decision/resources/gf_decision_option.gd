## GFDecisionOption: 可评分的候选决策资源。
##
## 候选决策由一组 GFDecisionConsideration 评分，并按聚合策略得到最终效用分数。
## 它描述“如何比较候选”，不执行具体业务动作。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.3.0
class_name GFDecisionOption
extends Resource


# --- 枚举 ---

## 候选分数聚合策略。
## [br]
## @api public
enum Aggregation {
	## 将 base_score 与各考虑项分数相乘，权重作为指数影响。
	MULTIPLY,
	## 按考虑项权重计算平均值，再乘以 base_score。
	WEIGHTED_AVERAGE,
	## 将 base_score 与加权分数相加，并钳制到 0 到 1。
	SUM,
	## 使用所有考虑项中的最低分。
	MIN,
	## 使用所有考虑项中的最高分。
	MAX,
}


# --- 常量 ---

const _GF_DECISION_NUMERIC_POLICY = preload("res://addons/gf/extensions/decision/runtime/gf_decision_numeric_policy.gd")


# --- 导出变量 ---

## 候选决策标识。
## [br]
## @api public
@export var decision_id: StringName = &""

## 编辑器或调试显示名。
## [br]
## @api public
@export var display_name: String = ""

## 是否启用该候选。
## [br]
## @api public
@export var enabled: bool = true

## 基础分数，范围 0 到 1。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var base_score: float = 1.0

## 分数聚合策略。
## [br]
## @api public
@export var aggregation: Aggregation = Aggregation.MULTIPLY

## 候选考虑项列表。
## [br]
## @api public
## [br]
## @schema considerations: Array[GFDecisionConsideration]，按顺序参与评分。
@export var considerations: Array[GFDecisionConsideration] = []

## 项目自定义元数据，框架不解释其中内容。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[StringName, Variant] project-defined decision metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加考虑项。
## [br]
## @api public
## [br]
## @param consideration: 要添加的考虑项。
## [br]
## @return: 添加成功返回 true。
func add_consideration(consideration: GFDecisionConsideration) -> bool:
	if consideration == null or consideration.consideration_id == &"":
		return false
	if has_consideration(consideration.consideration_id):
		return false
	considerations.append(consideration)
	return true


## 获取考虑项。
## [br]
## @api public
## [br]
## @param consideration_id: 考虑项标识。
## [br]
## @return: 找到的考虑项；不存在时返回 null。
func get_consideration(consideration_id: StringName) -> GFDecisionConsideration:
	for consideration: GFDecisionConsideration in considerations:
		if consideration != null and consideration.consideration_id == consideration_id:
			return consideration
	return null


## 检查考虑项是否存在。
## [br]
## @api public
## [br]
## @param consideration_id: 考虑项标识。
## [br]
## @return: 存在返回 true。
func has_consideration(consideration_id: StringName) -> bool:
	return get_consideration(consideration_id) != null


## 移除考虑项。
## [br]
## @api public
## [br]
## @param consideration_id: 考虑项标识。
## [br]
## @return: 移除成功返回 true。
func remove_consideration(consideration_id: StringName) -> bool:
	for index: int in range(considerations.size()):
		var consideration: GFDecisionConsideration = considerations[index]
		if consideration != null and consideration.consideration_id == consideration_id:
			considerations.remove_at(index)
			return true
	return false


## 清空考虑项。
## [br]
## @api public
func clear_considerations() -> void:
	considerations.clear()


## 计算候选决策分数。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 评分结果。
func score(context: GFDecisionContext) -> GFDecisionScore:
	if not enabled:
		return GFDecisionScore.new(self, 0.0, [], false)

	var details: Array[Dictionary] = _score_considerations(context)
	var final_score: float = _aggregate_scores(details)
	return GFDecisionScore.new(self, final_score, details, true)


## 获取候选决策调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param score_snapshot: 已计算的评分快照；为空时 score 字段返回空字典。
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 decision_id、display_name、enabled、aggregation、base_score 和 score 字段的 Dictionary。
func get_debug_snapshot(score_snapshot: GFDecisionScore = null) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary({
		"decision_id": decision_id,
		"display_name": display_name,
		"enabled": enabled,
		"aggregation": aggregation,
		"base_score": _normalized_score(base_score),
		"score": score_snapshot.to_dictionary() if score_snapshot != null else {},
	})


## 获取候选资源的 authoring 校验报告。
## [br]
## @api public
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, healthy, decision_id, issues, summary, and next_action.
func get_validation_report() -> Dictionary:
	var report: Dictionary = {
		"subject": "Decision option",
		"decision_id": decision_id,
		"issues": [],
	}
	if decision_id == &"":
		_append_validation_issue(report, &"missing_decision_id", "decision_id is required", "decision_id")
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_score(base_score):
		_append_validation_issue(report, &"invalid_base_score", "base_score must be finite and within 0 to 1", "base_score")
	if aggregation < Aggregation.MULTIPLY or aggregation > Aggregation.MAX:
		_append_validation_issue(report, &"invalid_aggregation", "aggregation is not supported", "aggregation")

	var seen_ids: Dictionary = {}
	for index: int in range(considerations.size()):
		var consideration: GFDecisionConsideration = considerations[index]
		if consideration == null:
			_append_validation_issue(report, &"missing_consideration", "consideration is null", "considerations[%d]" % index)
			continue
		if consideration.consideration_id == &"":
			_append_validation_issue(report, &"missing_consideration_id", "consideration_id is required", "considerations[%d].consideration_id" % index)
		elif seen_ids.has(consideration.consideration_id):
			_append_validation_issue(report, &"duplicate_consideration_id", "consideration_id is duplicated", "considerations[%d].consideration_id" % index)
		else:
			seen_ids[consideration.consideration_id] = true
		_append_consideration_configuration_issues(report, consideration, index)

	return GFValidationReportDictionary.finalize_report(report, "Decision option", {
		"fallback_action": "Review the first decision option issue.",
		"no_action": "Decision option is valid.",
	})


# --- 私有/辅助方法 ---

func _score_considerations(context: GFDecisionContext) -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	var seen_considerations: Dictionary = {}
	for consideration: GFDecisionConsideration in considerations:
		if consideration == null or not consideration.enabled:
			continue
		if consideration.consideration_id == &"" or seen_considerations.has(consideration.consideration_id):
			continue
		seen_considerations[consideration.consideration_id] = true
		var raw_score: float = consideration.score(context)
		var normalized_score: float = _normalized_score(raw_score)
		var normalized_weight: float = _GF_DECISION_NUMERIC_POLICY.normalize_weight(consideration.weight)
		var weighted_score: float = _apply_weight(normalized_score, normalized_weight)
		details.append({
			"consideration_id": consideration.consideration_id,
			"score": normalized_score,
			"weight": normalized_weight,
			"weighted_score": weighted_score,
		})
	return details


func _aggregate_scores(details: Array[Dictionary]) -> float:
	if details.is_empty():
		return _normalized_score(base_score)

	match aggregation:
		Aggregation.WEIGHTED_AVERAGE:
			return _aggregate_weighted_average(details)
		Aggregation.SUM:
			return _aggregate_sum(details)
		Aggregation.MIN:
			return _aggregate_min(details)
		Aggregation.MAX:
			return _aggregate_max(details)
		_:
			return _aggregate_multiply(details)


func _aggregate_multiply(details: Array[Dictionary]) -> float:
	var result: float = _normalized_score(base_score)
	for detail: Dictionary in details:
		result = _normalized_score(result * _normalized_score(GFVariantData.get_option_float(detail, "weighted_score", 1.0)))
	return result


func _aggregate_weighted_average(details: Array[Dictionary]) -> float:
	var maximum_weight: float = 0.0
	for detail: Dictionary in details:
		maximum_weight = maxf(
			maximum_weight,
			_GF_DECISION_NUMERIC_POLICY.normalize_weight(GFVariantData.get_option_float(detail, "weight"))
		)
	if maximum_weight <= 0.0:
		return _normalized_score(base_score)

	var normalized_total: float = 0.0
	var normalized_weight_total: float = 0.0
	for detail: Dictionary in details:
		var normalized_weight: float = (
			_GF_DECISION_NUMERIC_POLICY.normalize_weight(GFVariantData.get_option_float(detail, "weight"))
			/ maximum_weight
		)
		if normalized_weight <= 0.0:
			continue
		normalized_total += _normalized_score(GFVariantData.get_option_float(detail, "score")) * normalized_weight
		normalized_weight_total += normalized_weight
	if normalized_weight_total <= 0.0 or not is_finite(normalized_weight_total):
		return _normalized_score(base_score)
	return _normalized_score(_normalized_score(base_score) * (normalized_total / normalized_weight_total))


func _aggregate_sum(details: Array[Dictionary]) -> float:
	var result: float = _normalized_score(base_score)
	for detail: Dictionary in details:
		result = _normalized_score(result + _GF_DECISION_NUMERIC_POLICY.saturating_contribution(
			GFVariantData.get_option_float(detail, "score"),
			GFVariantData.get_option_float(detail, "weight")
		))
	return result


func _aggregate_min(details: Array[Dictionary]) -> float:
	var result: float = 1.0
	for detail: Dictionary in details:
		result = minf(result, _normalized_score(GFVariantData.get_option_float(detail, "score")))
	return _normalized_score(_normalized_score(base_score) * result)


func _aggregate_max(details: Array[Dictionary]) -> float:
	var result: float = 0.0
	for detail: Dictionary in details:
		result = maxf(result, _normalized_score(GFVariantData.get_option_float(detail, "score")))
	return _normalized_score(_normalized_score(base_score) * result)


func _apply_weight(raw_score: float, raw_weight: float) -> float:
	var normalized_score: float = _normalized_score(raw_score)
	var normalized_weight: float = _GF_DECISION_NUMERIC_POLICY.normalize_weight(raw_weight)
	if normalized_weight <= 0.0:
		return 1.0
	return _normalized_score(pow(normalized_score, normalized_weight))


func _normalized_score(value: float) -> float:
	return _GF_DECISION_NUMERIC_POLICY.normalize_score(value)


func _append_consideration_configuration_issues(
	report: Dictionary,
	consideration: GFDecisionConsideration,
	index: int
) -> void:
	var base_path: String = "considerations[%d]" % index
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_weight(consideration.weight):
		_append_validation_issue(report, &"invalid_consideration_weight", "weight must be finite and non-negative", "%s.weight" % base_path)
	if not is_finite(consideration.default_input):
		_append_validation_issue(report, &"invalid_default_input", "default_input must be finite", "%s.default_input" % base_path)
	if not is_finite(consideration.input_min) or not is_finite(consideration.input_max):
		_append_validation_issue(report, &"invalid_input_range", "input range must be finite", "%s.input_range" % base_path)
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_score(consideration.missing_score):
		_append_validation_issue(report, &"invalid_missing_score", "missing_score must be finite and within 0 to 1", "%s.missing_score" % base_path)
	if consideration.input_source < GFDecisionConsideration.InputSource.BLACKBOARD or consideration.input_source > GFDecisionConsideration.InputSource.TARGET:
		_append_validation_issue(report, &"invalid_input_source", "input_source is not supported", "%s.input_source" % base_path)


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
			"key": decision_id,
			"path": path,
		}
	)
