## GFTextSearchScorer: 通用文本检索评分器。
##
## 对标题、关键字、路径、说明等候选字段进行轻量 token 匹配、相似度评分和排序。
## 它不读取文件系统、不创建 UI，也不规定候选数据来自资源、命令、设置还是项目内容。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFTextSearchScorer
extends RefCounted


# --- 常量 ---

## 默认候选字段权重。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @schema DEFAULT_FIELDS: Array[Dictionary]，每个条目包含 key 和 weight 字段。
const DEFAULT_FIELDS: Array[Dictionary] = [
	{ "key": "title", "weight": 4.0 },
	{ "key": "name", "weight": 3.0 },
	{ "key": "keywords", "weight": 2.0 },
	{ "key": "detail", "weight": 1.0 },
	{ "key": "path", "weight": 1.0 },
]

const _SEPARATORS: Array[String] = [
	" ",
	"\t",
	"\n",
	"\r",
	"_",
	"-",
	".",
	"/",
	"\\",
	":",
	";",
	",",
	"(",
	")",
	"[",
	"]",
	"{",
	"}",
]

const _EXACT_QUERY_SCORE: float = 1000.0
const _PREFIX_QUERY_SCORE: float = 700.0
const _CONTAINS_QUERY_SCORE: float = 500.0
const _EXACT_WORD_SCORE: float = 300.0
const _PREFIX_WORD_SCORE: float = 220.0
const _CONTAINS_WORD_SCORE: float = 120.0
const _SUBSEQUENCE_SCORE: float = 40.0


# --- 公共方法 ---

## 把查询文本规范化为去重 token 列表。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param query: 查询文本。
## [br]
## @param options: 可选项；case_sensitive 默认为 false。
## [br]
## @return 去重后的 token 列表，保留首次出现顺序。
## [br]
## @schema options: Dictionary，支持 case_sensitive。
static func tokenize(query: String, options: Dictionary = {}) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	var normalized_query: String = _normalize_search_text(
		query,
		GFVariantData.get_option_bool(options, "case_sensitive", false)
	)
	for token: String in normalized_query.split(" ", false):
		if token.is_empty() or tokens.has(token):
			continue
		var _append_result: bool = tokens.append(token)
	return tokens


## 计算查询文本与单段候选文本的匹配报告。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param query: 查询文本。
## [br]
## @param text: 候选文本。
## [br]
## @param options: 可选项；require_all_tokens 默认为 true，case_sensitive 默认为 false。
## [br]
## @schema options: Dictionary，支持 require_all_tokens、case_sensitive。
## [br]
## @return 匹配报告。
## [br]
## @schema return: Dictionary，包含 matched、score 和 matched_tokens。
static func score_text(query: String, text: String, options: Dictionary = {}) -> Dictionary:
	var context: Dictionary = _make_query_context(query, options)
	var case_sensitive: bool = GFVariantData.get_option_bool(context, "case_sensitive", false)
	var tokens: PackedStringArray = GFVariantData.get_option_packed_string_array(context, "tokens")
	var normalized_query: String = GFVariantData.get_option_string(context, "normalized_query")
	var normalized_text: String = _normalize_search_text(text, case_sensitive)
	var require_all_tokens: bool = GFVariantData.get_option_bool(context, "require_all_tokens", true)
	return _score_normalized_text(normalized_query, tokens, normalized_text, require_all_tokens)


## 计算查询文本与一个候选字典的匹配报告。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param query: 查询文本。
## [br]
## @param candidate: 候选字典。
## [br]
## @schema candidate: Dictionary，字段由 options.fields 指定，默认读取 title、name、keywords、detail 和 path。
## [br]
## @param options: 可选项；fields 为字段权重数组，require_all_tokens 默认为 true，case_sensitive 默认为 false，duplicate_candidate 默认为 true。
## [br]
## @schema options: Dictionary，支持 fields、require_all_tokens、case_sensitive、duplicate_candidate。
## [br]
## @return 匹配报告。
## [br]
## @schema return: Dictionary，包含 matched、score、matched_tokens、field_scores 和 candidate。
static func score_candidate(query: String, candidate: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _score_candidate_with_context(candidate, _make_query_context(query, options))


## 按查询文本排序候选字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param query: 查询文本。
## [br]
## @param candidates: 候选字典数组。
## [br]
## @schema candidates: Array[Dictionary]，每个候选字段由 options.fields 指定。
## [br]
## @param options: 可选项；include_unmatched 默认为 false，limit 小于等于 0 表示不限制，case_sensitive 默认为 false。
## [br]
## @schema options: Dictionary，支持 fields、require_all_tokens、case_sensitive、duplicate_candidate、include_unmatched、limit。
## [br]
## @return 排序后的匹配报告数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 matched、score、matched_tokens、field_scores、candidate 和 index。
static func rank_candidates(query: String, candidates: Array[Dictionary], options: Dictionary = {}) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var include_unmatched: bool = GFVariantData.get_option_bool(options, "include_unmatched", false)
	var limit: int = GFVariantData.get_option_int(options, "limit", 0)
	var context: Dictionary = _make_query_context(query, options)

	for index: int in range(candidates.size()):
		var report: Dictionary = _score_candidate_with_context(candidates[index], context)
		report["index"] = index
		if GFVariantData.get_option_bool(report, "matched", false) or include_unmatched:
			reports.append(report)

	reports.sort_custom(_sort_reports_descending)
	if limit <= 0 or reports.size() <= limit:
		return reports
	return reports.slice(0, limit)


# --- 私有/辅助方法 ---

static func _make_query_context(query: String, options: Dictionary) -> Dictionary:
	var case_sensitive: bool = GFVariantData.get_option_bool(options, "case_sensitive", false)
	return {
		"case_sensitive": case_sensitive,
		"tokens": tokenize(query, options),
		"normalized_query": _normalize_search_text(query, case_sensitive),
		"require_all_tokens": GFVariantData.get_option_bool(options, "require_all_tokens", true),
		"duplicate_candidate": GFVariantData.get_option_bool(options, "duplicate_candidate", true),
		"fields": _get_fields(options),
	}


static func _score_candidate_with_context(candidate: Dictionary, context: Dictionary) -> Dictionary:
	var case_sensitive: bool = GFVariantData.get_option_bool(context, "case_sensitive", false)
	var tokens: PackedStringArray = GFVariantData.get_option_packed_string_array(context, "tokens")
	var normalized_query: String = GFVariantData.get_option_string(context, "normalized_query")
	var require_all_tokens: bool = GFVariantData.get_option_bool(context, "require_all_tokens", true)
	var duplicate_candidate: bool = GFVariantData.get_option_bool(context, "duplicate_candidate", true)
	var fields: Array[Dictionary] = _get_context_fields(context)
	var matched_lookup: Dictionary = {}
	var field_scores: Dictionary = {}
	var total_score: float = 0.0

	for field_entry: Dictionary in fields:
		var field_key: StringName = GFVariantData.to_string_name(GFVariantData.get_option_value(field_entry, "key"))
		var field_weight: float = GFVariantData.get_option_float(field_entry, "weight", 1.0)
		if field_key == &"" or field_weight <= 0.0:
			continue

		var field_text: String = _value_to_search_text(_get_candidate_value(candidate, field_key))
		if field_text.is_empty():
			continue

		var field_report: Dictionary = _score_normalized_text(
			normalized_query,
			tokens,
			_normalize_search_text(field_text, case_sensitive),
			false
		)
		var field_score: float = GFVariantData.get_option_float(field_report, "score") * field_weight
		if field_score <= 0.0:
			continue

		field_scores[field_key] = field_score
		total_score += field_score
		var field_tokens: PackedStringArray = _get_report_tokens(field_report)
		for matched_token: String in field_tokens:
			matched_lookup[matched_token] = true

	var matched_tokens: PackedStringArray = _collect_tokens_in_query_order(tokens, matched_lookup)
	var matched: bool = not tokens.is_empty() and not matched_tokens.is_empty()
	if matched and require_all_tokens:
		matched = matched_tokens.size() == tokens.size()
	if not matched:
		total_score = 0.0

	return {
		"matched": matched,
		"score": total_score,
		"matched_tokens": matched_tokens,
		"field_scores": field_scores,
		"candidate": candidate.duplicate(true) if duplicate_candidate else candidate,
	}


static func _score_normalized_text(
	normalized_query: String,
	tokens: PackedStringArray,
	normalized_text: String,
	require_all_tokens: bool
) -> Dictionary:
	var matched_tokens: PackedStringArray = PackedStringArray()
	var score: float = 0.0
	if normalized_query.is_empty() or tokens.is_empty() or normalized_text.is_empty():
		return _make_text_score_report(false, 0.0, matched_tokens)

	score += _score_query_phrase(normalized_query, normalized_text)
	for token: String in tokens:
		var token_score: float = _score_token(token, normalized_text)
		if token_score <= 0.0:
			if require_all_tokens:
				return _make_text_score_report(false, 0.0, PackedStringArray())
			continue

		score += token_score
		var _append_result: bool = matched_tokens.append(token)

	var matched: bool = not matched_tokens.is_empty()
	if require_all_tokens and matched_tokens.size() != tokens.size():
		return _make_text_score_report(false, 0.0, PackedStringArray())
	return _make_text_score_report(matched, score if matched else 0.0, matched_tokens)


static func _score_query_phrase(normalized_query: String, normalized_text: String) -> float:
	if normalized_text == normalized_query:
		return _EXACT_QUERY_SCORE
	if normalized_text.begins_with(normalized_query):
		return _PREFIX_QUERY_SCORE

	var query_position: int = normalized_text.find(normalized_query)
	if query_position >= 0:
		return maxf(_CONTAINS_QUERY_SCORE - float(query_position), _CONTAINS_WORD_SCORE)
	return 0.0


static func _score_token(token: String, normalized_text: String) -> float:
	var best_score: float = 0.0
	for word: String in normalized_text.split(" ", false):
		if word == token:
			best_score = maxf(best_score, _EXACT_WORD_SCORE)
		elif word.begins_with(token):
			best_score = maxf(best_score, _PREFIX_WORD_SCORE)
		elif word.contains(token):
			best_score = maxf(best_score, _CONTAINS_WORD_SCORE)

	if best_score <= 0.0 and _is_subsequence(token, normalized_text):
		best_score = _SUBSEQUENCE_SCORE
	return best_score


static func _get_fields(options: Dictionary) -> Array[Dictionary]:
	var fields_value: Variant = GFVariantData.get_option_value(options, "fields", DEFAULT_FIELDS)
	var fields: Array[Dictionary] = []
	if fields_value is Array:
		for field_variant: Variant in fields_value:
			var field_entry: Dictionary = _normalize_field_entry(field_variant)
			if not field_entry.is_empty():
				fields.append(field_entry)
	elif fields_value is PackedStringArray:
		var field_names: PackedStringArray = fields_value
		for field_name: String in field_names:
			var field_entry: Dictionary = _normalize_field_entry(field_name)
			if not field_entry.is_empty():
				fields.append(field_entry)
	if fields.is_empty():
		fields.append_array(DEFAULT_FIELDS)
	return fields


static func _get_context_fields(context: Dictionary) -> Array[Dictionary]:
	var fields_value: Variant = GFVariantData.get_option_value(context, "fields", DEFAULT_FIELDS)
	var fields: Array[Dictionary] = []
	if fields_value is Array:
		for field_value: Variant in fields_value:
			var field_entry: Dictionary = _normalize_field_entry(field_value)
			if not field_entry.is_empty():
				fields.append(field_entry)
	if fields.is_empty():
		fields.append_array(DEFAULT_FIELDS)
	return fields


static func _normalize_field_entry(field_variant: Variant) -> Dictionary:
	if field_variant is Dictionary:
		var field_dictionary: Dictionary = field_variant
		var field_key: StringName = GFVariantData.to_string_name(GFVariantData.get_option_value(field_dictionary, "key"))
		if field_key == &"":
			return {}
		return {
			"key": field_key,
			"weight": GFVariantData.get_option_float(field_dictionary, "weight", 1.0),
		}
	if field_variant is StringName:
		return {
			"key": field_variant,
			"weight": 1.0,
		}
	if field_variant is String:
		var field_text: String = field_variant
		return {
			"key": StringName(field_text),
			"weight": 1.0,
		}
	return {}


static func _get_candidate_value(candidate: Dictionary, field_key: StringName) -> Variant:
	if candidate.has(field_key):
		return candidate[field_key]
	var text_key: String = String(field_key)
	if candidate.has(text_key):
		return candidate[text_key]
	return null


static func _value_to_search_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is PackedStringArray:
		var packed_text: PackedStringArray = value
		return " ".join(packed_text)
	if value is Array:
		var parts: PackedStringArray = PackedStringArray()
		for item: Variant in value:
			var text: String = _value_to_search_text(item)
			if not text.is_empty():
				var _append_result: bool = parts.append(text)
		return " ".join(parts)
	return GFVariantData.to_text(value)


static func _normalize_search_text(text: String, case_sensitive: bool = false) -> String:
	var normalized: String = text.strip_edges()
	if not case_sensitive:
		normalized = normalized.to_lower()
	var result: String = ""
	var previous_was_space: bool = false
	for index: int in range(normalized.length()):
		var character: String = normalized.substr(index, 1)
		if _SEPARATORS.has(character):
			if not previous_was_space:
				result += " "
				previous_was_space = true
			continue

		result += character
		previous_was_space = false
	return result.strip_edges()


static func _is_subsequence(needle: String, haystack: String) -> bool:
	if needle.is_empty():
		return true

	var needle_index: int = 0
	for index: int in range(haystack.length()):
		if haystack.substr(index, 1) != needle.substr(needle_index, 1):
			continue

		needle_index += 1
		if needle_index >= needle.length():
			return true
	return false


static func _make_text_score_report(matched: bool, score: float, matched_tokens: PackedStringArray) -> Dictionary:
	return {
		"matched": matched,
		"score": score,
		"matched_tokens": matched_tokens,
	}


static func _get_report_tokens(report: Dictionary) -> PackedStringArray:
	var tokens_value: Variant = GFVariantData.get_option_value(report, "matched_tokens", PackedStringArray())
	if tokens_value is PackedStringArray:
		var packed_tokens: PackedStringArray = tokens_value
		return packed_tokens
	if tokens_value is Array:
		var result: PackedStringArray = PackedStringArray()
		for token_variant: Variant in tokens_value:
			var token_text: String = GFVariantData.to_text(token_variant)
			if not token_text.is_empty():
				var _append_result: bool = result.append(token_text)
		return result
	return PackedStringArray()


static func _collect_tokens_in_query_order(tokens: PackedStringArray, matched_lookup: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for token: String in tokens:
		if matched_lookup.has(token):
			var _append_result: bool = result.append(token)
	return result


static func _sort_reports_descending(left: Dictionary, right: Dictionary) -> bool:
	var left_score: float = GFVariantData.get_option_float(left, "score", 0.0)
	var right_score: float = GFVariantData.get_option_float(right, "score", 0.0)
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score

	var left_title: String = _get_report_sort_title(left)
	var right_title: String = _get_report_sort_title(right)
	if left_title != right_title:
		return left_title < right_title

	return GFVariantData.get_option_int(left, "index", 0) < GFVariantData.get_option_int(right, "index", 0)


static func _get_report_sort_title(report: Dictionary) -> String:
	var candidate: Dictionary = GFVariantData.get_option_dictionary(report, "candidate", {})
	var title: String = _value_to_search_text(_get_candidate_value(candidate, &"title"))
	if title.is_empty():
		title = _value_to_search_text(_get_candidate_value(candidate, &"name"))
	return title.to_lower()
