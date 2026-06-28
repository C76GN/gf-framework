## GFDecisionScore: 单个候选决策的评分结果。
##
## 保存候选 ID、最终分数、考虑项明细、排序序号和元数据，便于测试、调试面板或导演系统审计。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 4.3.0
class_name GFDecisionScore
extends RefCounted


# --- 公共变量 ---

## 候选决策标识。
## [br]
## @api public
## [br]
## @since 7.0.0
var decision_id: StringName = &""

## 候选在所属集合中的原始顺序。独立候选评分时为 -1。
## [br]
## @api public
## [br]
## @since 7.0.0
var decision_order: int = -1

## 最终分数。
## [br]
## @api public
var score: float = 0.0

## 该候选是否可被选择。
## [br]
## @api public
var accepted: bool = false

## 考虑项评分明细。
## [br]
## @api public
## [br]
## @schema consideration_scores: Array[Dictionary]，每项包含 consideration_id、score、weight 和 weighted_score 字段。
var consideration_scores: Array[Dictionary] = []

## 候选决策元数据副本。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[StringName, Variant] copied from the scored decision option.
var metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	source_decision: GFDecisionOption = null,
	final_score: float = 0.0,
	details: Array[Dictionary] = [],
	is_accepted: bool = false,
	source_order: int = -1
) -> void:
	score = final_score
	accepted = is_accepted
	decision_order = source_order
	consideration_scores = details.duplicate(true)
	if source_decision != null:
		decision_id = source_decision.decision_id
		metadata = source_decision.metadata.duplicate(true)


# --- 公共方法 ---

## 转换为字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 评分结果字典。
## [br]
## @schema return: 包含 decision_id、decision_order、score、accepted、consideration_scores 和 metadata 字段的 Dictionary。
func to_dictionary() -> Dictionary:
	return {
		"decision_id": decision_id,
		"decision_order": decision_order,
		"score": score,
		"accepted": accepted,
		"consideration_scores": consideration_scores.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 与 to_dictionary() 相同的评分结果 Dictionary。
func get_debug_snapshot() -> Dictionary:
	return to_dictionary()
