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
	if is_nan(raw_score) or is_inf(raw_score):
		raw_score = missing_score
	raw_score = clampf(raw_score, 0.0, 1.0)
	if invert:
		raw_score = 1.0 - raw_score
	return clampf(raw_score, 0.0, 1.0)


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
	return {
		"consideration_id": consideration_id,
		"enabled": enabled,
		"score": score(context),
		"weight": weight,
		"input_source": input_source,
		"input_key": input_key,
	}


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
	if is_equal_approx(input_min, input_max):
		return 1.0 if value >= input_max else 0.0
	return clampf(inverse_lerp(input_min, input_max, value), 0.0, 1.0)


func _is_numeric(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
