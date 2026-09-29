## 测试 GFTextSearchScorer 的 token 规范化、候选评分和排序行为。
extends GutTest


# --- 常量 ---

const GFTextSearchScorerBase = preload("res://addons/gf/standard/foundation/collections/gf_text_search_scorer.gd")


# --- 测试方法 ---

## 验证 tokenize 会按常见分隔符拆分、转小写并去重。
func test_tokenize_normalizes_separators_and_duplicates() -> void:
	var tokens: PackedStringArray = GFTextSearchScorerBase.tokenize("  Audio-Bank/audio_bank  AUDIO ")

	assert_eq(tokens, PackedStringArray(["audio", "bank"]), "查询 token 应按首次出现顺序去重。")


## 验证完整文本匹配的得分高于前缀和子序列匹配。
func test_score_text_prefers_stronger_matches() -> void:
	var exact: Dictionary = GFTextSearchScorerBase.score_text("audio bank", "audio bank")
	var prefix: Dictionary = GFTextSearchScorerBase.score_text("audio", "audio bank importer")
	var subsequence: Dictionary = GFTextSearchScorerBase.score_text("abk", "audio bank")

	assert_true(GFVariantData.get_option_bool(exact, "matched", false), "完整匹配应命中。")
	assert_true(GFVariantData.get_option_float(exact, "score", 0.0) > GFVariantData.get_option_float(prefix, "score", 0.0), "完整短语匹配应高于前缀匹配。")
	assert_true(GFVariantData.get_option_float(prefix, "score", 0.0) > GFVariantData.get_option_float(subsequence, "score", 0.0), "前缀匹配应高于子序列匹配。")


## 验证评分器可按需启用大小写敏感匹配。
func test_score_text_can_be_case_sensitive() -> void:
	var insensitive: Dictionary = GFTextSearchScorerBase.score_text("audio", "Audio")
	var sensitive: Dictionary = GFTextSearchScorerBase.score_text("audio", "Audio", {
		"case_sensitive": true,
	})

	assert_true(GFVariantData.get_option_bool(insensitive, "matched", false), "默认大小写不敏感。")
	assert_false(GFVariantData.get_option_bool(sensitive, "matched", true), "启用 case_sensitive 后大小写不同不应命中。")


## 验证候选评分可以跨多个字段满足 token 要求。
func test_score_candidate_combines_tokens_across_fields() -> void:
	var candidate: Dictionary = {
		"title": "Audio Tools",
		"keywords": ["bank", "import"],
	}

	var report: Dictionary = GFTextSearchScorerBase.score_candidate("audio bank", candidate)

	assert_true(GFVariantData.get_option_bool(report, "matched", false), "title 和 keywords 应共同满足查询。")
	assert_eq(_get_matched_tokens(report), PackedStringArray(["audio", "bank"]), "匹配 token 应按查询顺序返回。")


## 验证字段权重会影响候选排序。
func test_rank_candidates_respects_field_weights() -> void:
	var candidates: Array[Dictionary] = [
		{
			"title": "Importer",
			"detail": "Audio bank workflow",
		},
		{
			"title": "Audio Bank",
			"detail": "Importer",
		},
	]

	var reports: Array[Dictionary] = GFTextSearchScorerBase.rank_candidates("audio bank", candidates)
	var first_candidate: Dictionary = GFVariantData.get_option_dictionary(reports[0], "candidate", {})

	assert_eq(GFVariantData.get_option_string(first_candidate, "title"), "Audio Bank", "title 字段权重更高时应排在前面。")


## 验证默认只返回命中的候选，并支持 limit。
func test_rank_candidates_filters_unmatched_and_limits_results() -> void:
	var candidates: Array[Dictionary] = [
		{ "title": "Audio Bank" },
		{ "title": "Audio Import" },
		{ "title": "Save Slot" },
	]

	var reports: Array[Dictionary] = GFTextSearchScorerBase.rank_candidates("audio", candidates, {
		"limit": 1,
	})
	var first_candidate: Dictionary = GFVariantData.get_option_dictionary(reports[0], "candidate", {})

	assert_eq(reports.size(), 1, "limit 应限制返回数量。")
	assert_eq(GFVariantData.get_option_string(first_candidate, "title"), "Audio Bank", "未命中候选不应进入默认结果。")


## 验证 include_unmatched 可保留未命中候选用于调用方展示空分数。
func test_rank_candidates_can_include_unmatched_reports() -> void:
	var candidates: Array[Dictionary] = [
		{ "title": "Save Slot" },
	]

	var reports: Array[Dictionary] = GFTextSearchScorerBase.rank_candidates("audio", candidates, {
		"include_unmatched": true,
	})

	assert_eq(reports.size(), 1, "include_unmatched 应保留未命中候选。")
	assert_false(GFVariantData.get_option_bool(reports[0], "matched", true), "未命中报告应明确标记 matched=false。")


func test_score_candidate_handles_cyclic_and_deep_arrays_without_recursion_failure() -> void:
	var self_cycle: Array = []
	self_cycle.append(self_cycle)
	var left_cycle: Array = []
	var right_cycle: Array = [left_cycle, "needle"]
	left_cycle.append(right_cycle)
	var deep_value: Array = ["needle"]
	for _depth: int in range(2000):
		deep_value = [deep_value]

	var self_report: Dictionary = GFTextSearchScorerBase.score_candidate("needle", { "title": self_cycle })
	var linked_report: Dictionary = GFTextSearchScorerBase.score_candidate("needle", { "title": left_cycle })
	var deep_report: Dictionary = GFTextSearchScorerBase.score_candidate("needle", { "title": deep_value })

	assert_false(GFVariantData.get_option_bool(self_report, "matched", true), "纯 self-cycle 应有限返回未命中。")
	assert_true(GFVariantData.get_option_bool(linked_report, "matched"), "跳过循环边后仍应处理同数组中的有限文本。")
	assert_true(GFVariantData.get_option_bool(deep_report, "matched"), "深无环数组应由迭代遍历处理，不依赖调用栈。")
	assert_true(is_finite(GFVariantData.get_option_float(self_report, "score")), "循环输入的 score 必须有限。")
	assert_true(is_finite(GFVariantData.get_option_float(deep_report, "score")), "深输入的 score 必须有限。")


func test_score_candidate_rejects_nonfinite_or_overflowing_field_weights() -> void:
	var candidate: Dictionary = {
		"title": "needle",
	}
	var invalid_weights: Array[float] = [NAN, INF, 1.0e308]
	for field_weight: float in invalid_weights:
		var report: Dictionary = GFTextSearchScorerBase.score_candidate("needle", candidate, {
			"fields": [{
				"key": "title",
				"weight": field_weight,
			}],
		})
		assert_false(GFVariantData.get_option_bool(report, "matched", true), "无效或会使派生 score 溢出的权重应失败关闭。")
		assert_eq(GFVariantData.get_option_float(report, "score", -1.0), 0.0, "被拒绝的权重不得污染总分。")
		assert_true(is_finite(GFVariantData.get_option_float(report, "score")), "评分报告不得包含非有限 score。")


func test_prepared_context_preserves_full_reports_and_duplicate_field_accumulation() -> void:
	var candidate: Dictionary = { "title": "Needle", "detail": "needle", "metadata": { "nested": [1, 2] } }
	var fields: Array[Dictionary] = [
		{ "key": "title", "weight": 1.0 }, { "key": "title", "weight": 2.0 },
		{ "key": "detail", "weight": 0.5 }, { "key": "", "weight": 3.0 },
	]
	var options: Dictionary = { "fields": fields }
	var context: Dictionary = GFTextSearchScorerBase.create_ranking_context("needle", options)
	var before: Dictionary = context.duplicate(true)
	var report: Dictionary = GFTextSearchScorerBase.score_ranking_candidate(candidate, context, 9)
	var exact_score: float = GFVariantData.get_option_float(GFTextSearchScorerBase.score_text("needle", "needle"), "score")
	assert_eq(report, {
		"matched": true, "score": exact_score * 3.5, "matched_tokens": PackedStringArray(["needle"]),
		"field_scores": { &"title": exact_score * 2.0, &"detail": exact_score * 0.5 },
		"candidate": candidate, "index": 9,
	})
	assert_eq(context, before, "评分不得修改预备上下文。")
	for field_options: Variant in [[], "invalid", PackedStringArray(["title", "detail"])]:
		var fallback_options: Dictionary = { "fields": field_options, "case_sensitive": true, "require_all_tokens": false }
		var fallback_context: Dictionary = GFTextSearchScorerBase.create_ranking_context("Needle other", fallback_options)
		var expected: Dictionary = GFTextSearchScorerBase.score_candidate("Needle other", candidate, fallback_options)
		expected["index"] = 3
		assert_eq(GFTextSearchScorerBase.score_ranking_candidate(candidate, fallback_context, 3), expected)
	var copied_candidate: Dictionary = GFVariantData.as_dictionary(report.get("candidate"))
	var nested: Dictionary = GFVariantData.as_dictionary(copied_candidate.get("metadata"))
	nested["mutated"] = true
	assert_false(GFVariantData.as_dictionary(candidate.get("metadata")).has("mutated"))


func test_rank_comparator_keeps_approximate_score_title_fallback_and_global_index() -> void:
	var payload: Dictionary = { "nested": [{ "license": "CC0" }] }
	var reports: Array[Dictionary] = [
		{ "score": 1.0, "candidate": { "title": "Beta", "metadata": payload }, "index": 0 },
		{ "score": 1.00000001, "candidate": { "title": "", "name": "alpha", "metadata": payload }, "index": 3 },
		{ "score": 1.0, "candidate": { "title": "ALPHA", "metadata": payload }, "index": 1 },
		{ "score": 2.0, "candidate": { "title": "zulu", "metadata": payload }, "index": 2 },
	]
	var before: Array[Dictionary] = reports.duplicate(true)
	reports.sort_custom(GFTextSearchScorerBase.is_ranked_report_before)
	assert_eq(reports, [before[3], before[2], before[1], before[0]])
	assert_eq(payload, { "nested": [{ "license": "CC0" }] }, "比较器只读访问候选。")


func test_cached_sort_keys_match_original_sort_full_reports_at_approximate_score_edges() -> void:
	var scores: Array[float] = [1.0, 1.000005, 1.00001, 1.000015, 1.000020, 2.0]
	var titles: Array[Variant] = ["alpha", "ALPHA", "Beta", "", ["nested", ["Title"]], PackedStringArray(["packed", "title"])]
	for offset: int in range(6):
		var reports: Array[Dictionary] = []
		for index: int in range(257):
			reports.append({
				"matched": true, "score": scores[(index + offset) % scores.size()],
				"index": index % 17, "field_scores": {"title": 1.0}, "matched_tokens": PackedStringArray(["needle"]),
				"candidate": {"title": titles[(index * 7 + offset) % titles.size()], "name": "fallback", "metadata": {"nested": [index]}},
			})
		var expected: Array[Dictionary] = reports.duplicate(true)
		expected.sort_custom(GFTextSearchScorerBase.is_ranked_report_before)
		GFTextSearchScorerBase.sort_ranking_reports(reports)
		assert_eq(reports, expected, "缓存排序键必须保留原生算法在近似比较、相同标题和相同索引下的完整排列。")
		for report: Dictionary in reports:
			assert_eq(report.size(), 6, "私有排序键不得进入报告。")


# --- 私有/辅助方法 ---

func _get_matched_tokens(report: Dictionary) -> PackedStringArray:
	var value: Variant = GFVariantData.get_option_value(report, "matched_tokens", PackedStringArray())
	if value is PackedStringArray:
		var tokens: PackedStringArray = value
		return tokens
	return PackedStringArray()
