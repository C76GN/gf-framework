## 测试 Decision 扩展的黑板、效用评分和运行时服务注册。
extends GutTest


# --- 常量 ---

const GF_DECISION_EXTENSION = preload("res://addons/gf/extensions/decision/extension.gd")


# --- 辅助类型 ---

class DecisionSubject extends RefCounted:
	var readiness: float = 0.75

	func get_decision_value(key: StringName, fallback: Variant = null) -> Variant:
		if key == &"focus":
			return 0.8
		return fallback


# --- 测试方法 ---

func test_blackboard_tracks_values_and_emits_changes() -> void:
	var blackboard: GFDecisionBlackboard = GFDecisionBlackboard.new({ &"pressure": 0.25 })
	watch_signals(blackboard)

	blackboard.set_value(&"pressure", 0.5)
	var removed: bool = blackboard.erase_value(&"pressure")

	assert_true(removed, "已有键应可被移除。")
	assert_false(blackboard.has_value(&"pressure"), "移除后不应继续报告存在。")
	assert_signal_emitted(blackboard, "value_changed", "设置新值应发出变更信号。")
	assert_signal_emitted(blackboard, "value_removed", "移除值应发出移除信号。")


func test_context_reads_blackboard_metadata_subject_and_target() -> void:
	var subject: DecisionSubject = DecisionSubject.new()
	var target: DecisionSubject = DecisionSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(
		GFDecisionBlackboard.new({ &"distance": 6.0 }),
		subject,
		target,
		{ &"phase": &"plan" }
	)

	var metadata_phase: StringName = GFVariantData.to_string_name(context.get_metadata_value(&"phase"))

	assert_eq(GFVariantData.to_float(context.get_value(&"distance")), 6.0, "上下文应读取黑板值。")
	assert_eq(metadata_phase, &"plan", "上下文应读取元数据。")
	assert_eq(GFVariantData.to_float(context.get_subject_value(&"focus")), 0.8, "主体可通过 get_decision_value 提供决策值。")
	assert_eq(GFVariantData.to_float(context.get_target_value(&"readiness")), 0.75, "目标可通过属性提供决策值。")


func test_consideration_scores_normalized_input_and_inversion() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({ &"distance": 4.0 }))
	var consideration: GFDecisionConsideration = GFDecisionConsideration.new()
	consideration.consideration_id = &"nearby"
	consideration.input_key = &"distance"
	consideration.input_min = 0.0
	consideration.input_max = 10.0

	assert_almost_eq(consideration.score(context), 0.4, 0.001, "线性考虑项应按 min/max 归一化。")

	consideration.invert = true

	assert_almost_eq(consideration.score(context), 0.6, 0.001, "invert 应反转最终效用分数。")


func test_consideration_uses_default_input_before_missing_score() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"bad_value": "not-number",
	}))
	var consideration: GFDecisionConsideration = GFDecisionConsideration.new()
	consideration.input_key = &"missing"
	consideration.default_input = 0.7
	consideration.input_min = 0.0
	consideration.input_max = 1.0
	consideration.missing_score = 0.2

	assert_almost_eq(consideration.score(context), 0.7, 0.001, "缺失输入应优先使用 default_input。")

	consideration.input_key = &"bad_value"

	assert_almost_eq(consideration.score(context), 0.2, 0.001, "非数字输入应使用 missing_score。")


func test_decision_set_selects_highest_scored_option() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"pressure": 0.8,
		&"stability": 0.3,
	}))
	var stabilize: GFDecisionOption = _make_option(&"stabilize", &"pressure")
	var inspect: GFDecisionOption = _make_option(&"inspect", &"stability")
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [inspect, stabilize]

	var best: GFDecisionScore = decision_set.select_best(context)

	assert_eq(best.decision_id, &"stabilize", "最高分候选应被选中。")
	assert_almost_eq(best.score, 0.8, 0.001, "选择结果应保留最终分数。")


func test_weighted_average_uses_consideration_weights() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"first": 1.0,
		&"second": 0.0,
	}))
	var first: GFDecisionConsideration = _make_consideration(&"first", &"first", 2.0)
	var second: GFDecisionConsideration = _make_consideration(&"second", &"second", 1.0)
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"weighted"
	decision.aggregation = GFDecisionOption.Aggregation.WEIGHTED_AVERAGE
	decision.considerations = [first, second]

	var score: GFDecisionScore = decision.score(context)

	assert_almost_eq(score.score, 0.666, 0.01, "加权平均应按权重计算候选分数。")


func test_decision_utility_registers_sets_and_selects_best() -> void:
	var utility: GFDecisionUtility = GFDecisionUtility.new()
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [
		_make_option(&"low", &"low_value"),
		_make_option(&"high", &"high_value"),
	]

	assert_true(utility.register_decision_set(&"default", decision_set), "有效集合应可注册。")

	var context: GFDecisionContext = utility.make_context({
		&"low_value": 0.1,
		&"high_value": 0.9,
	})
	var best: GFDecisionScore = utility.select_best(&"default", context)

	assert_eq(best.decision_id, &"high", "Utility 应从注册集合中返回最佳候选。")
	assert_true(utility.get_decision_set_ids().has("default"), "注册 ID 应进入快照列表。")


func test_decision_extension_installer_registers_utility() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer: GFInstaller = GF_DECISION_EXTENSION.new()

	installer.install(architecture)

	assert_not_null(architecture.get_local_utility(GFDecisionUtility), "启用 Decision 扩展应注册 GFDecisionUtility。")
	architecture.dispose()


# --- 私有/辅助方法 ---

func _make_option(decision_id: StringName, input_key: StringName) -> GFDecisionOption:
	var option: GFDecisionOption = GFDecisionOption.new()
	option.decision_id = decision_id
	option.considerations = [_make_consideration(input_key, input_key)]
	return option


func _make_consideration(
	consideration_id: StringName,
	input_key: StringName,
	weight: float = 1.0
) -> GFDecisionConsideration:
	var consideration: GFDecisionConsideration = GFDecisionConsideration.new()
	consideration.consideration_id = consideration_id
	consideration.input_key = input_key
	consideration.input_min = 0.0
	consideration.input_max = 1.0
	consideration.weight = weight
	return consideration
