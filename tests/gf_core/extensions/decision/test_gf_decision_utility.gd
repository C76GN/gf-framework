## 测试 Decision 扩展的黑板、效用评分和运行时服务注册。
extends GutTest


# --- 常量 ---

const GF_DECISION_EXTENSION = preload("res://addons/gf/extensions/decision/extension.gd")


# --- 辅助类型 ---

class DecisionSubject extends RefCounted:
	var readiness: float = 0.75
	var focus: float = 0.8

	func get_decision_value(key: StringName, fallback: Variant = null) -> Variant:
		if key == &"focus":
			return focus
		return fallback

	func get_decision_snapshot() -> Dictionary:
		return {
			&"focus": focus,
			&"readiness": readiness,
		}


class SnapshotOnlySubject extends RefCounted:
	var secret: float = 1.0
	var exposed: float = 0.5

	func get_decision_snapshot() -> Dictionary:
		return {
			&"exposed": exposed,
		}


class CountingSnapshotSubject extends RefCounted:
	var snapshot_count: int = 0
	var value: float = 0.4

	func get_decision_snapshot() -> Dictionary:
		snapshot_count += 1
		return {
			&"value": value,
		}


class NullDecisionSubject extends RefCounted:
	var focus: float = 0.75

	func get_decision_value(key: StringName, fallback: Variant = null) -> Variant:
		if key == &"focus":
			return null
		return fallback


class LazyDecisionSubject extends RefCounted:
	var call_count: int = 0

	func get_decision_snapshot() -> Dictionary:
		return {
			&"captured": 0.2,
		}

	func get_decision_value(key: StringName, fallback: Variant = null) -> Variant:
		if key != &"virtual":
			return fallback
		call_count += 1
		return 0.9


class BadScoreConsideration extends GFDecisionConsideration:
	var raw_score: float = 0.0

	func _score(_context: GFDecisionContext) -> float:
		return raw_score


class CountingConsideration extends GFDecisionConsideration:
	var call_count: int = 0

	func _score(_context: GFDecisionContext) -> float:
		call_count += 1
		return 0.5


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


func test_blackboard_canonicalizes_string_and_string_name_keys() -> void:
	var blackboard: GFDecisionBlackboard = GFDecisionBlackboard.new()
	blackboard.values["mode"] = "string"

	blackboard.set_value(&"mode", "string_name")
	var data: Dictionary = blackboard.to_dictionary()
	var has_string_alias: bool = false
	for key: Variant in data.keys():
		if typeof(key) == TYPE_STRING:
			has_string_alias = true

	var mode_value: String = GFVariantData.to_text(blackboard.get_value(&"mode"))
	assert_eq(mode_value, "string_name", "set_value 应覆盖 String/StringName 别名，而不是保留两份键。")
	assert_true(data.has(&"mode"), "to_dictionary 应输出规范 StringName 键。")
	assert_false(has_string_alias, "to_dictionary 不应继续输出 String 别名。")

	var removed: bool = blackboard.erase_value(&"mode")
	assert_true(removed, "erase_value 应能移除规范键。")
	assert_false(blackboard.has_value(&"mode"), "erase_value 应同时清理 String 与 StringName 键。")


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


func test_context_subject_and_target_values_are_snapshots() -> void:
	var subject: DecisionSubject = DecisionSubject.new()
	var target: DecisionSubject = DecisionSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new(), subject, target)

	subject.focus = 0.1
	target.readiness = 0.2
	var duplicated: GFDecisionContext = context.duplicate_context()
	subject.focus = 0.3
	target.readiness = 0.4

	assert_almost_eq(GFVariantData.to_float(context.get_subject_value(&"focus")), 0.8, 0.001, "主体值应使用构造时快照。")
	assert_almost_eq(GFVariantData.to_float(context.get_target_value(&"readiness")), 0.75, 0.001, "目标值应使用构造时快照。")
	assert_almost_eq(GFVariantData.to_float(duplicated.get_subject_value(&"focus")), 0.8, 0.001, "复制上下文不应重新捕获已变化的主体值。")
	assert_almost_eq(GFVariantData.to_float(duplicated.get_target_value(&"readiness")), 0.75, 0.001, "复制上下文不应重新捕获已变化的目标值。")


func test_context_explicit_snapshot_is_authoritative() -> void:
	var subject: SnapshotOnlySubject = SnapshotOnlySubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new(), subject)
	var secret_value: String = GFVariantData.to_text(context.get_subject_value(&"secret", "fallback"))

	assert_almost_eq(GFVariantData.to_float(context.get_subject_value(&"exposed")), 0.5, 0.001, "显式 get_decision_snapshot 字段应进入快照。")
	assert_eq(secret_value, "fallback", "存在显式 get_decision_snapshot 时不应再扫描同对象属性。")


func test_duplicate_context_does_not_resample_subject_or_target() -> void:
	var subject: CountingSnapshotSubject = CountingSnapshotSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new(), subject)

	var duplicated: GFDecisionContext = context.duplicate_context()

	assert_eq(subject.snapshot_count, 1, "duplicate_context 应复制已有快照，不应再次调用 get_decision_snapshot。")
	assert_almost_eq(GFVariantData.to_float(duplicated.get_subject_value(&"value")), 0.4, 0.001, "复制后的上下文应保留原始快照值。")


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


func test_decision_set_never_treats_nearby_unequal_scores_as_tied() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"lower": 0.5,
		&"higher": 0.5000001,
	}))
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [
		_make_option(&"lower", &"lower"),
		_make_option(&"higher", &"higher"),
	]

	var best: GFDecisionScore = decision_set.select_best(context)

	assert_eq(best.decision_id, &"higher", "只要分数严格更高，就不能由原始顺序覆盖。")


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


func test_decision_scores_reject_non_finite_base_weight_and_minimum() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"value": 0.9,
	}))
	var consideration: GFDecisionConsideration = _make_consideration(&"value", &"value", INF)
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"unsafe"
	decision.base_score = NAN
	decision.considerations = [consideration]

	var score: GFDecisionScore = decision.score(context)
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.minimum_score = INF
	decision_set.decisions = [_make_option(&"high", &"value")]
	var best: GFDecisionScore = decision_set.select_best(context)

	assert_eq(score.score, 0.0, "非有限 base_score 应失败闭合为有限分数。")
	assert_false(best.accepted, "非有限 minimum_score 应收紧为最高门槛，而不是放宽选择。")


func test_all_weighted_aggregations_normalize_non_finite_weights() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({ &"value": 0.75 }))
	for aggregation: GFDecisionOption.Aggregation in [
		GFDecisionOption.Aggregation.WEIGHTED_AVERAGE,
		GFDecisionOption.Aggregation.SUM,
	]:
		for invalid_weight: float in [NAN, INF, -INF]:
			var consideration: GFDecisionConsideration = _make_consideration(&"value", &"value", invalid_weight)
			var decision: GFDecisionOption = GFDecisionOption.new()
			decision.decision_id = &"finite"
			decision.base_score = 0.25
			decision.aggregation = aggregation
			decision.considerations = [consideration]

			var score: GFDecisionScore = decision.score(context)

			assert_true(is_finite(score.score), "所有聚合结果都必须保持有限。")
			assert_true(score.score >= 0.0 and score.score <= 1.0)
			assert_eq(GFVariantData.get_option_float(score.consideration_scores[0], "weight"), 0.0)


func test_decision_score_is_value_object_without_resource_reference() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({ &"utility": 0.6 }))
	var decision: GFDecisionOption = _make_option(&"inspect", &"utility")

	var score: GFDecisionScore = decision.score(context)
	decision.metadata[&"changed"] = true

	assert_eq(score.decision_id, &"inspect", "评分应保留候选 ID。")
	assert_eq(score.decision_order, -1, "独立候选评分不应伪造集合顺序。")
	assert_false(score.metadata.has(&"changed"), "评分结果应复制元数据，不能持有候选 Resource 状态。")


func test_disabled_considerations_are_ignored_by_aggregations() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"low": 0.2,
		&"high": 1.0,
	}))
	var low: GFDecisionConsideration = _make_consideration(&"low", &"low", 1.0)
	var disabled: GFDecisionConsideration = _make_consideration(&"disabled", &"high", 100.0)
	disabled.enabled = false
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"utility"
	decision.considerations = [low, disabled]

	decision.aggregation = GFDecisionOption.Aggregation.WEIGHTED_AVERAGE
	assert_almost_eq(decision.score(context).score, 0.2, 0.001, "禁用考虑项不应污染加权平均。")

	decision.aggregation = GFDecisionOption.Aggregation.SUM
	decision.base_score = 0.0
	assert_almost_eq(decision.score(context).score, 0.2, 0.001, "禁用考虑项不应被 SUM 当作 1.0 叠加。")

	decision.aggregation = GFDecisionOption.Aggregation.MAX
	decision.base_score = 1.0
	assert_almost_eq(decision.score(context).score, 0.2, 0.001, "禁用考虑项不应被 MAX 当作最高分。")


func test_decision_and_consideration_helpers_enforce_unique_ids() -> void:
	var first_decision: GFDecisionOption = GFDecisionOption.new()
	first_decision.decision_id = &"same"
	var duplicate_decision: GFDecisionOption = GFDecisionOption.new()
	duplicate_decision.decision_id = &"same"
	var decision_set: GFDecisionSet = GFDecisionSet.new()

	assert_true(decision_set.add_decision(first_decision), "首个候选应可添加。")
	assert_false(decision_set.add_decision(duplicate_decision), "重复候选 ID 应被拒绝。")
	assert_true(decision_set.remove_decision(&"same"), "移除应删除唯一匹配项。")
	assert_false(decision_set.has_decision(&"same"), "移除后不应残留同 ID 候选。")

	var first_consideration: GFDecisionConsideration = _make_consideration(&"same", &"low")
	var duplicate_consideration: GFDecisionConsideration = _make_consideration(&"same", &"high")
	var decision: GFDecisionOption = GFDecisionOption.new()

	assert_true(decision.add_consideration(first_consideration), "首个考虑项应可添加。")
	assert_false(decision.add_consideration(duplicate_consideration), "重复考虑项 ID 应被拒绝。")
	assert_true(decision.remove_consideration(&"same"), "移除应删除唯一匹配项。")
	assert_false(decision.has_consideration(&"same"), "移除后不应残留同 ID 考虑项。")


func test_decision_set_ignores_duplicate_exported_decision_ids() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"first": 0.2,
		&"second": 1.0,
	}))
	var first: GFDecisionOption = _make_option(&"same", &"first")
	var duplicate_decision: GFDecisionOption = _make_option(&"same", &"second")
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [first, duplicate_decision]

	var scores: Array[GFDecisionScore] = decision_set.score_all(context)

	assert_eq(scores.size(), 1, "直接编辑 exported decisions 形成重复 ID 时，score_all 应只接受第一项。")
	assert_eq(scores[0].decision_id, &"same", "保留项应使用原始候选 ID。")
	assert_almost_eq(scores[0].score, 0.2, 0.001, "重复项不应覆盖第一项评分。")


func test_decision_option_ignores_duplicate_exported_consideration_ids() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new({
		&"first": 0.2,
		&"second": 1.0,
	}))
	var first: GFDecisionConsideration = _make_consideration(&"same", &"first")
	var duplicate_consideration: GFDecisionConsideration = _make_consideration(&"same", &"second")
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"option"
	decision.aggregation = GFDecisionOption.Aggregation.WEIGHTED_AVERAGE
	decision.considerations = [first, duplicate_consideration]

	var score: GFDecisionScore = decision.score(context)

	assert_almost_eq(score.score, 0.2, 0.001, "直接编辑 exported considerations 形成重复 ID 时，应只接受第一项。")
	assert_eq(score.consideration_scores.size(), 1, "重复考虑项不应进入评分明细。")


func test_decision_authoring_validation_reports_duplicate_ids_and_invalid_numbers() -> void:
	var first: GFDecisionOption = _make_option(&"same", &"first")
	var duplicate_option: GFDecisionOption = _make_option(&"same", &"second")
	first.base_score = NAN
	first.considerations[0].weight = INF
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decision_set_id = &"validation"
	decision_set.decisions = [first, duplicate_option]

	var report: Dictionary = decision_set.get_validation_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_false(_find_issue(report, &"duplicate_decision_id").is_empty())
	assert_false(_find_issue(report, &"invalid_base_score").is_empty())
	assert_false(_find_issue(report, &"invalid_consideration_weight").is_empty())


func test_decision_set_debug_snapshot_reuses_scores_without_rescoring() -> void:
	var context: GFDecisionContext = GFDecisionContext.new()
	var consideration: CountingConsideration = CountingConsideration.new()
	consideration.consideration_id = &"counted"
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"once"
	decision.considerations = [consideration]
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [decision]

	var scores: Array[GFDecisionScore] = decision_set.score_all(context)
	var snapshot: Dictionary = decision_set.get_debug_snapshot(null, scores)

	assert_eq(consideration.call_count, 1, "调试快照复用已计算评分时不应再次评分。")
	assert_eq(GFVariantData.as_array(GFVariantData.get_option_value(snapshot, "scores")).size(), 1, "调试快照应包含传入评分。")


func test_decision_set_debug_snapshot_treats_explicit_empty_scores_as_complete() -> void:
	var context: GFDecisionContext = GFDecisionContext.new()
	var consideration: CountingConsideration = CountingConsideration.new()
	consideration.consideration_id = &"counted"
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"once"
	decision.considerations = [consideration]
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decisions = [decision]

	var snapshot: Dictionary = decision_set.get_debug_snapshot(context, [])

	assert_eq(consideration.call_count, 0, "显式空评分是合法预计算结果，不能被解释为重新评分。")
	assert_true(GFVariantData.get_option_array(snapshot, "scores").is_empty())


func test_debug_snapshots_are_json_safe() -> void:
	var context: GFDecisionContext = GFDecisionContext.new(
		GFDecisionBlackboard.new({ &"position": Vector2(1.0, 2.0) }),
		null,
		null,
		{ &"heat": NAN }
	)
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.metadata = { &"limit": INF }
	var option: GFDecisionOption = GFDecisionOption.new()
	option.decision_id = &"unsafe_metadata"
	option.metadata = {
		&"resource": Resource.new(),
		&"heat": NAN,
	}
	var score: GFDecisionScore = GFDecisionScore.new(option, INF, [{
		"consideration_id": &"unsafe",
		"score": NAN,
		"weight": INF,
		"weighted_score": NAN,
	}], true)

	var context_text: String = JSON.stringify(context.get_debug_snapshot())
	var set_text: String = JSON.stringify(decision_set.get_debug_snapshot(null, [score]))
	var score_text: String = JSON.stringify(score.get_debug_snapshot())

	assert_true(context_text.contains("__gf_variant__"), "上下文调试快照应把 Godot/非有限 Variant 编码为 JSON-safe 标记。")
	assert_true(set_text.contains("__gf_variant__"), "集合调试快照 metadata 应可安全 JSON.stringify。")
	assert_true(set_text.contains("__gf_report_value__"), "评分 metadata 中的 Resource 必须经过统一报告编码。")
	assert_true(score_text.contains("__gf_report_value__"), "GFDecisionScore 调试快照必须是报告安全边界。")


func test_context_get_decision_value_can_return_explicit_null() -> void:
	var subject: NullDecisionSubject = NullDecisionSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new(), subject)
	var focus_value: Variant = context.get_subject_value(&"focus", "fallback")

	assert_true(focus_value == null, "显式 null 应作为有效决策值返回，不能回退到同名属性。")


func test_context_lazily_reads_virtual_decision_values_and_caches_them() -> void:
	var subject: LazyDecisionSubject = LazyDecisionSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(GFDecisionBlackboard.new(), subject)

	var first_value: Variant = context.get_subject_value(&"virtual", "fallback")
	var second_value: Variant = context.get_subject_value(&"virtual", "fallback")
	var snapshot: Dictionary = context.get_debug_snapshot()
	var subject_values: Dictionary = GFVariantData.get_option_dictionary(snapshot, "subject_values")

	assert_almost_eq(GFVariantData.to_float(first_value), 0.9, 0.001, "快照未包含的虚拟决策值应可从 provider 懒加载。")
	assert_almost_eq(GFVariantData.to_float(second_value), 0.9, 0.001, "懒加载值应写回快照供后续读取。")
	assert_eq(subject.call_count, 1, "虚拟决策值被缓存后不应重复调用 provider。")
	assert_almost_eq(GFVariantData.get_option_float(subject_values, "virtual"), 0.9, 0.001, "调试快照应包含已缓存的虚拟值。")


func test_context_capture_budget_blocks_unbounded_lazy_provider_reads() -> void:
	var subject: LazyDecisionSubject = LazyDecisionSubject.new()
	var context: GFDecisionContext = GFDecisionContext.new(
		GFDecisionBlackboard.new(),
		subject,
		null,
		{},
		{ "max_snapshot_entries": 0 }
	)

	var value: Variant = context.get_subject_value(&"virtual", "fallback")
	var snapshot: Dictionary = context.get_debug_snapshot()
	var diagnostics: Dictionary = GFVariantData.get_option_dictionary(snapshot, "capture_diagnostics")
	var subject_diagnostics: Dictionary = GFVariantData.get_option_dictionary(diagnostics, "subject")

	assert_eq(GFVariantData.to_text(value), "fallback")
	assert_eq(subject.call_count, 0, "捕获预算耗尽时不应继续调用有副作用的 provider。")
	assert_true(GFVariantData.get_option_bool(subject_diagnostics, "truncated"))


func test_non_finite_consideration_scores_fall_back_to_missing_score() -> void:
	var context: GFDecisionContext = GFDecisionContext.new()
	var consideration: BadScoreConsideration = BadScoreConsideration.new()
	consideration.missing_score = 0.25

	consideration.raw_score = NAN
	assert_almost_eq(consideration.score(context), 0.25, 0.001, "NaN 分数应失败闭合到 missing_score。")

	consideration.raw_score = INF
	assert_almost_eq(consideration.score(context), 0.25, 0.001, "INF 分数应失败闭合到 missing_score。")


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


func test_decision_set_evaluate_reuses_single_score_pass() -> void:
	var context: GFDecisionContext = GFDecisionContext.new()
	var consideration: CountingConsideration = CountingConsideration.new()
	consideration.consideration_id = &"counted"
	var decision: GFDecisionOption = GFDecisionOption.new()
	decision.decision_id = &"once"
	decision.considerations = [consideration]
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decision_set_id = &"evaluation"
	decision_set.decisions = [decision]

	var evaluation_value: Variant = decision_set.call(&"evaluate", context)
	assert_true(evaluation_value is Object, "evaluate 应返回评价对象。")
	var evaluation: Object = evaluation_value
	var data: Dictionary = GFVariantData.as_dictionary(evaluation.call(&"to_dictionary"))
	var score_items: Array = GFVariantData.get_option_array(data, "scores")
	var best_score: Dictionary = GFVariantData.get_option_dictionary(data, "best_score")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(data, "debug_snapshot")

	assert_eq(consideration.call_count, 1, "evaluate 应只执行一次评分。")
	assert_eq(GFVariantData.get_option_string_name(best_score, "decision_id"), &"once", "评价结果应保留最佳候选。")
	assert_eq(score_items.size(), 1, "评价字典应包含本次评分列表。")
	assert_eq(GFVariantData.get_option_string_name(best_score, "decision_id"), &"once", "评价字典应包含最佳评分快照。")
	assert_eq(GFVariantData.get_option_array(snapshot, "scores").size(), 1, "调试快照应复用同一份评分。")


func test_decision_utility_rejects_duplicate_sets_and_clear_emits_unregister() -> void:
	var utility: GFDecisionUtility = GFDecisionUtility.new()
	var first: GFDecisionSet = GFDecisionSet.new()
	var duplicate_set: GFDecisionSet = GFDecisionSet.new()
	watch_signals(utility)

	assert_true(utility.register_decision_set(&"default", first), "首个集合应可注册。")
	assert_false(utility.register_decision_set(&"default", duplicate_set), "重复集合 ID 应被拒绝，避免静默替换。")
	assert_eq(utility.get_decision_set(&"default"), first, "重复注册不应替换原始集合。")

	utility.clear_decision_sets()

	assert_signal_emitted_with_parameters(utility, "decision_set_unregistered", [&"default"])
	assert_false(utility.has_decision_set(&"default"), "清空后集合应注销。")


func test_decision_utility_rejects_mismatched_decision_set_id() -> void:
	var utility: GFDecisionUtility = GFDecisionUtility.new()
	var decision_set: GFDecisionSet = GFDecisionSet.new()
	decision_set.decision_set_id = &"inner"

	assert_false(utility.register_decision_set(&"outer", decision_set), "注册 ID 与资源自身 ID 不一致时应拒绝。")
	assert_false(utility.has_decision_set(&"outer"), "拒绝后不应留下注册项。")


func test_decision_extension_installer_registers_utility() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer: GFInstaller = GF_DECISION_EXTENSION.new()

	installer.install(architecture, GFAsyncScope.new())

	assert_not_null(architecture.get_local_utility(GFDecisionUtility), "启用 Decision 扩展应注册 GFDecisionUtility。")
	architecture.dispose()


# --- 私有/辅助方法 ---

func _find_issue(report: Dictionary, kind: StringName) -> Dictionary:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFValidationReportDictionary.issue_to_dict(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == kind:
			return issue
	return {}


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
