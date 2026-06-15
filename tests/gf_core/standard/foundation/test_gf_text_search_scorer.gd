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


# --- 私有/辅助方法 ---

func _get_matched_tokens(report: Dictionary) -> PackedStringArray:
	var value: Variant = GFVariantData.get_option_value(report, "matched_tokens", PackedStringArray())
	if value is PackedStringArray:
		var tokens: PackedStringArray = value
		return tokens
	return PackedStringArray()
