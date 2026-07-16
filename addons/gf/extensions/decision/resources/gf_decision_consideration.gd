## GFDecisionConsideration: 单个效用评分考虑项。
##
## 从决策上下文读取一个输入值，将它映射为 0 到 1 的效用分数。
## 子类可以重写 `_score()` 扩展项目自己的评分逻辑。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 4.3.0
class_name GFDecisionConsideration
extends Resource


# --- 枚举 ---

## 考虑项读取输入值的位置。
## [br]
## @api public
enum InputSource {
	## 从 GFDecisionContext 黑板读取。
	BLACKBOARD,
	## 从 GFDecisionContext metadata 读取。
	METADATA,
	## 从 GFDecisionContext subject 读取。
	SUBJECT,
	## 从 GFDecisionContext target 读取。
	TARGET,
}


# --- 常量 ---

const _GF_DECISION_NUMERIC_POLICY = preload("res://addons/gf/extensions/decision/runtime/gf_decision_numeric_policy.gd")


# --- 导出变量 ---

## 考虑项标识，用于调试报告。
## [br]
## @api public
@export var consideration_id: StringName = &""

## 是否启用该考虑项。禁用时返回中性分数 1.0。
## [br]
## @api public
@export var enabled: bool = true

## 考虑项权重。具体聚合方式由 GFDecisionOption 决定。
## [br]
## @api public
@export_range(0.0, 100.0, 0.001, "or_greater") var weight: float = 1.0

## 输入来源。
## [br]
## @api public
@export var input_source: InputSource = InputSource.BLACKBOARD

## 输入键。为空时使用 default_input。
## [br]
## @api public
@export var input_key: StringName = &""

## 缺失或没有输入键时使用的默认输入值。
## [br]
## @api public
@export var default_input: float = 0.0

## 输入最小值，映射为 0。
## [br]
## @api public
@export var input_min: float = 0.0

## 输入最大值，映射为 1。
## [br]
## @api public
@export var input_max: float = 1.0

## 输入存在但无法转换为数字时返回的分数。输入缺失时优先使用 default_input。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var missing_score: float = 0.0

## 可选响应曲线。为空时使用线性归一化值。
## [br]
## @api public
@export var response_curve: Curve = null

## 是否反转最终分数。
## [br]
## @api public
@export var invert: bool = false


# --- 公共方法 ---

## 计算考虑项分数。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 0 到 1 之间的效用分数。
func score(context: GFDecisionContext) -> float:
	if not enabled:
		return 1.0

	var raw_score: float = _score(context)
	raw_score = _GF_DECISION_NUMERIC_POLICY.normalize_score(raw_score, missing_score)
	if invert:
		raw_score = 1.0 - raw_score
	return _GF_DECISION_NUMERIC_POLICY.normalize_score(raw_score)


## 获取考虑项调试快照。
## [br]
## @api public
## [br]
## @param context: 决策上下文。
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 consideration_id、enabled、score、weight、input_source 和 input_key 字段的 Dictionary。
func get_debug_snapshot(context: GFDecisionContext) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary({
		"consideration_id": consideration_id,
		"enabled": enabled,
		"score": score(context),
		"weight": _GF_DECISION_NUMERIC_POLICY.normalize_weight(weight),
		"input_source": input_source,
		"input_key": input_key,
	})


## 获取考虑项 authoring 校验报告。
## [br]
## @api public
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @since 8.0.0
## [br]
## @schema return: Dictionary with ok, healthy, consideration_id, issues, summary, and next_action.
func get_validation_report() -> Dictionary:
	var report: Dictionary = {
		"subject": "Decision consideration",
		"consideration_id": consideration_id,
		"issues": [],
	}
	if consideration_id == &"":
		_append_validation_issue(report, &"missing_consideration_id", "consideration_id is required", "consideration_id")
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_weight(weight):
		_append_validation_issue(report, &"invalid_consideration_weight", "weight must be finite and non-negative", "weight")
	if input_source < InputSource.BLACKBOARD or input_source > InputSource.TARGET:
		_append_validation_issue(report, &"invalid_input_source", "input_source is not supported", "input_source")
	if not is_finite(default_input):
		_append_validation_issue(report, &"invalid_default_input", "default_input must be finite", "default_input")
	if not is_finite(input_min) or not is_finite(input_max):
		_append_validation_issue(report, &"invalid_input_range", "input range must be finite", "input_range")
	if not _GF_DECISION_NUMERIC_POLICY.is_valid_score(missing_score):
		_append_validation_issue(report, &"invalid_missing_score", "missing_score must be finite and within 0 to 1", "missing_score")
	return GFValidationReportDictionary.finalize_report(report, "Decision consideration", {
		"fallback_action": "Review the first decision consideration issue.",
		"no_action": "Decision consideration is valid.",
	})


# --- 可重写钩子 / 虚方法 ---

## 自定义考虑项评分。
##
## 默认实现从 context 读取 input_key，并按 input_min/input_max 归一化。
## 子类重写时仍应返回 0 到 1 之间的值。
## [br]
## @api protected
## [br]
## @param context: 决策上下文。
## [br]
## @return: 0 到 1 之间的原始效用分数。
func _score(context: GFDecisionContext) -> float:
	var input: Variant = _resolve_input(context)
	if not _is_numeric(input):
		return missing_score

	var normalized: float = _normalize_input(GFVariantData.to_float(input))
	if response_curve != null:
		return response_curve.sample_baked(normalized)
	return normalized


# --- 私有/辅助方法 ---

func _resolve_input(context: GFDecisionContext) -> Variant:
	if input_key == &"":
		return default_input
	if context == null:
		return default_input

	match input_source:
		InputSource.METADATA:
			return context.get_metadata_value(input_key, default_input)
		InputSource.SUBJECT:
			return context.get_subject_value(input_key, default_input)
		InputSource.TARGET:
			return context.get_target_value(input_key, default_input)
		_:
			return context.get_value(input_key, default_input)


func _normalize_input(value: float) -> float:
	var safe_min: float = _finite_or_default(input_min, 0.0)
	var safe_max: float = _finite_or_default(input_max, 1.0)
	var safe_value: float = _finite_or_default(value, safe_min)
	if is_equal_approx(safe_min, safe_max):
		return 1.0 if safe_value >= safe_max else 0.0
	return clampf(inverse_lerp(safe_min, safe_max, safe_value), 0.0, 1.0)


func _is_numeric(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _finite_or_default(value: float, default_value: float) -> float:
	return value if not is_nan(value) and not is_inf(value) else default_value


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
			"key": consideration_id,
			"path": path,
		}
	)
