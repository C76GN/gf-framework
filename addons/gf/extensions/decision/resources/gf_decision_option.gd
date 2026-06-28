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
	return {
		"decision_id": decision_id,
		"display_name": display_name,
		"enabled": enabled,
		"aggregation": aggregation,
		"base_score": base_score,
		"score": score_snapshot.to_dictionary() if score_snapshot != null else {},
	}


# --- 私有/辅助方法 ---

func _score_considerations(context: GFDecisionContext) -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	for consideration: GFDecisionConsideration in considerations:
		if consideration == null or not consideration.enabled:
			continue
		var raw_score: float = consideration.score(context)
		var weighted_score: float = _apply_weight(raw_score, consideration.weight)
		details.append({
			"consideration_id": consideration.consideration_id,
			"score": raw_score,
			"weight": consideration.weight,
			"weighted_score": weighted_score,
		})
	return details


func _aggregate_scores(details: Array[Dictionary]) -> float:
	if details.is_empty():
		return clampf(base_score, 0.0, 1.0)

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
	var result: float = clampf(base_score, 0.0, 1.0)
	for detail: Dictionary in details:
		result *= GFVariantData.get_option_float(detail, "weighted_score", 1.0)
	return clampf(result, 0.0, 1.0)


func _aggregate_weighted_average(details: Array[Dictionary]) -> float:
	var total: float = 0.0
	var total_weight: float = 0.0
	for detail: Dictionary in details:
		var weight: float = maxf(GFVariantData.get_option_float(detail, "weight", 1.0), 0.0)
		if weight <= 0.0:
			continue
		total += GFVariantData.get_option_float(detail, "score", 0.0) * weight
		total_weight += weight
	if total_weight <= 0.0:
		return clampf(base_score, 0.0, 1.0)
	return clampf(clampf(base_score, 0.0, 1.0) * (total / total_weight), 0.0, 1.0)


func _aggregate_sum(details: Array[Dictionary]) -> float:
	var result: float = clampf(base_score, 0.0, 1.0)
	for detail: Dictionary in details:
		result += GFVariantData.get_option_float(detail, "score", 0.0) * maxf(GFVariantData.get_option_float(detail, "weight", 1.0), 0.0)
	return clampf(result, 0.0, 1.0)


func _aggregate_min(details: Array[Dictionary]) -> float:
	var result: float = 1.0
	for detail: Dictionary in details:
		result = minf(result, GFVariantData.get_option_float(detail, "score", 0.0))
	return clampf(clampf(base_score, 0.0, 1.0) * result, 0.0, 1.0)


func _aggregate_max(details: Array[Dictionary]) -> float:
	var result: float = 0.0
	for detail: Dictionary in details:
		result = maxf(result, GFVariantData.get_option_float(detail, "score", 0.0))
	return clampf(clampf(base_score, 0.0, 1.0) * result, 0.0, 1.0)


func _apply_weight(raw_score: float, raw_weight: float) -> float:
	var normalized_score: float = clampf(raw_score, 0.0, 1.0)
	var normalized_weight: float = maxf(raw_weight, 0.0)
	if normalized_weight <= 0.0:
		return 1.0
	return clampf(pow(normalized_score, normalized_weight), 0.0, 1.0)
