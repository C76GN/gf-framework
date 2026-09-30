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

## 规范化查询文本时替换为空格的分隔字符集合。
## [br]
## @api private
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

## 查询短语完全匹配时使用的分数。
## [br]
## @api private
const _EXACT_QUERY_SCORE: float = 1000.0

## 查询短语前缀匹配时使用的分数。
## [br]
## @api private
const _PREFIX_QUERY_SCORE: float = 700.0

## 查询短语出现在候选文本中时使用的基础分数。
## [br]
## @api private
const _CONTAINS_QUERY_SCORE: float = 500.0

## 单词完全匹配时使用的分数。
## [br]
## @api private
const _EXACT_WORD_SCORE: float = 300.0

## 单词前缀匹配时使用的分数。
## [br]
## @api private
const _PREFIX_WORD_SCORE: float = 220.0

## 单词包含 token 时使用的分数。
## [br]
## @api private
const _CONTAINS_WORD_SCORE: float = 120.0

## 未命中单词但字符构成子序列时使用的分数。
## [br]
## @api private
const _SUBSEQUENCE_SCORE: float = 40.0

## 候选值遍历栈中的普通值帧标记。
## [br]
## @api private
const _TRAVERSAL_VALUE: int = 0

## 候选值遍历栈中的数组退出帧标记。
## [br]
## @api private
const _TRAVERSAL_EXIT_ARRAY: int = 1


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
	var tokens: PackedStringArray = PackedStringArray()
	var tokens_value: Variant = GFVariantData.get_option_value(context, "tokens")
	if tokens_value is PackedStringArray:
		tokens = tokens_value
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


# --- 框架内部方法 ---

## 构建由调用方独占的纯数据评分上下文，供分批查询复用相同规范化规则。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param query: 查询文本。
## [br]
## @param options: 与 rank_candidates 相同的评分选项。
## [br]
## @schema options: Dictionary with optional fields, require_all_tokens, case_sensitive and duplicate_candidate.
## [br]
## @return 本次查询独占的上下文；调用方不得在评分中修改它。
## [br]
## @schema return: Dictionary with case_sensitive: bool, tokens: PackedStringArray, normalized_query: String, require_all_tokens: bool, duplicate_candidate: bool and fields: Array[Dictionary].
static func create_ranking_context(query: String, options: Dictionary = {}) -> Dictionary:
	return _make_query_context(query, options)


## 使用已经规范化的上下文评分一个候选，并保留过滤后全局位置。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param candidate: 本次查询的候选数据。
## [br]
## @schema candidate: Dictionary with fields referenced by context.fields.
## [br]
## @param context: create_ranking_context 创建的未修改上下文。
## [br]
## @schema context: Dictionary returned by create_ranking_context.
## [br]
## @param index: 过滤后的全局候选索引。
## [br]
## @return 与同步评分相同的报告，另带全局索引。
## [br]
## @schema return: Dictionary with matched, score, matched_tokens, field_scores, candidate and index.
static func score_ranking_candidate(candidate: Dictionary, context: Dictionary, index: int) -> Dictionary:
	var report: Dictionary = _score_candidate_with_context(candidate, context)
	report["index"] = index
	return report


## 比较两份评分报告，复用同步排名的分数、标题和全局索引规则。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param left: 左侧评分报告。
## [br]
## @schema left: Dictionary returned by score_ranking_candidate or rank_candidates.
## [br]
## @param right: 右侧评分报告。
## [br]
## @schema right: Dictionary returned by score_ranking_candidate or rank_candidates.
## [br]
## @return 左侧应排在右侧之前时为 true。
static func is_ranked_report_before(left: Dictionary, right: Dictionary) -> bool:
	return _sort_reports_descending(left, right)


## 就地排列调用方独占的纯数据报告；私有排序键不写入报告，仍使用原生 sort_custom。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param reports: 本次排名独占的报告数组；只改变顺序，不复制或修改报告内容。
## [br]
## @schema reports: Array[Dictionary] returned by score_ranking_candidate, with score, candidate and index.
static func sort_ranking_reports(reports: Array[Dictionary]) -> void:
	var scores: PackedFloat64Array = PackedFloat64Array()
	var titles: PackedStringArray = PackedStringArray()
	var indices: PackedInt64Array = PackedInt64Array()
	var order: Array[int] = []
	for position: int in range(reports.size()):
		var report: Dictionary = reports[position]
		var _score_appended: bool = scores.append(GFVariantData.get_option_float(report, "score", 0.0))
		var _title_appended: bool = titles.append(_get_report_sort_title(report))
		var _index_appended: bool = indices.append(GFVariantData.get_option_int(report, "index", 0))
		order.append(position)
	order.sort_custom(_sort_ranking_indices.bind(scores, titles, indices))
	var original: Array[Dictionary] = reports.duplicate()
	for position: int in range(order.size()):
		reports[position] = original[order[position]]


# --- 私有/辅助方法 ---

## 合并查询选项、规范化文本并预先准备候选字段配置。
## [br]
## @api private
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


## 按字段权重累加候选分数，并构建匹配 token 与结果候选项。
## [br]
## @api private
static func _score_candidate_with_context(candidate: Dictionary, context: Dictionary) -> Dictionary:
	var case_sensitive: bool = GFVariantData.get_option_bool(context, "case_sensitive", false)
	var tokens_value: Variant = GFVariantData.get_option_value(context, "tokens")
	var tokens: PackedStringArray = tokens_value if tokens_value is PackedStringArray else PackedStringArray()
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
		if field_key == &"" or not is_finite(field_weight) or field_weight <= 0.0:
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
		if not is_finite(field_score) or field_score <= 0.0:
			continue
		var next_total_score: float = total_score + field_score
		if not is_finite(next_total_score):
			continue

		field_scores[field_key] = field_score
		total_score = next_total_score
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
		"candidate": _duplicate_candidate(candidate) if duplicate_candidate else candidate,
	}


## 评分已规范化的短语与 token，并按 require_all_tokens 决定失败策略。
## [br]
## @api private
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


## 按完全匹配、前缀或包含关系计算查询短语分数。
## [br]
## @api private
static func _score_query_phrase(normalized_query: String, normalized_text: String) -> float:
	if normalized_text == normalized_query:
		return _EXACT_QUERY_SCORE
	if normalized_text.begins_with(normalized_query):
		return _PREFIX_QUERY_SCORE

	var query_position: int = normalized_text.find(normalized_query)
	if query_position >= 0:
		return maxf(_CONTAINS_QUERY_SCORE - float(query_position), _CONTAINS_WORD_SCORE)
	return 0.0


## 对所有文本单词取最佳 token 匹配分；无此类匹配时检查字符子序列。
## [br]
## @api private
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


## 从 options.fields 读取并规范字段配置；空配置时回退到默认字段。
## [br]
## @api private
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


## 从查询上下文取回规范字段配置；缺失或无有效项时使用默认字段。
## [br]
## @api private
static func _get_context_fields(context: Dictionary) -> Array[Dictionary]:
	var fields_value: Variant = GFVariantData.get_option_value(context, "fields", DEFAULT_FIELDS)
	# 创建上下文时已完成规范化；评分期间只读复用，保留字段顺序和重复项。
	if fields_value is Array[Dictionary]:
		var prepared_fields: Array[Dictionary] = fields_value
		if not prepared_fields.is_empty():
			return prepared_fields
	var fields: Array[Dictionary] = []
	if fields_value is Array:
		for field_value: Variant in fields_value:
			var field_entry: Dictionary = _normalize_field_entry(field_value)
			if not field_entry.is_empty():
				fields.append(field_entry)
	if fields.is_empty():
		fields.append_array(DEFAULT_FIELDS)
	return fields


## 将字段字典、StringName 或 String 转为 key/weight 字典。
## [br]
## @api private
static func _normalize_field_entry(field_variant: Variant) -> Dictionary:
	if field_variant is Dictionary:
		var field_dictionary: Dictionary = field_variant
		var field_key: StringName = GFVariantData.to_string_name(GFVariantData.get_option_value(field_dictionary, "key"))
		if field_key == &"":
			return {}
		var field_weight: float = GFVariantData.get_option_float(field_dictionary, "weight", 1.0)
		return {
			"key": field_key,
			"weight": field_weight if is_finite(field_weight) else 0.0,
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


## 优先按 StringName 键取值，再尝试对应的 String 键。
## [br]
## @api private
static func _get_candidate_value(candidate: Dictionary, field_key: StringName) -> Variant:
	if candidate.has(field_key):
		return candidate[field_key]
	var text_key: String = String(field_key)
	if candidate.has(text_key):
		return candidate[text_key]
	return null


## 按原顺序展开嵌套 Array，以空格连接非空文本；null 跳过，PackedStringArray 直接拼接。
## 仅跳过当前访问路径上的数组循环，同一数组在不同分支仍可贡献文本；其他值交给 to_text。
## [br]
## @api private
static func _value_to_search_text(value: Variant) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var active_arrays: Array = []
	var pending: Array[Dictionary] = [{
		"kind": _TRAVERSAL_VALUE,
		"value": value,
	}]
	while not pending.is_empty():
		var frame: Dictionary = pending.pop_back()
		var frame_value: Variant = GFVariantData.get_option_value(frame, "value")
		if GFVariantData.get_option_int(frame, "kind") == _TRAVERSAL_EXIT_ARRAY:
			if not active_arrays.is_empty():
				var _removed_active_array: Variant = active_arrays.pop_back()
			continue
		if frame_value == null:
			continue
		if frame_value is PackedStringArray:
			var packed_text: PackedStringArray = frame_value
			var joined_text: String = " ".join(packed_text)
			if not joined_text.is_empty():
				var _packed_text_appended: bool = parts.append(joined_text)
			continue
		if frame_value is Array:
			var array_value: Array = frame_value
			if _contains_active_array(active_arrays, array_value):
				continue
			active_arrays.append(array_value)
			pending.append({
				"kind": _TRAVERSAL_EXIT_ARRAY,
				"value": array_value,
			})
			for index: int in range(array_value.size() - 1, -1, -1):
				pending.append({
					"kind": _TRAVERSAL_VALUE,
					"value": array_value[index],
				})
			continue
		var text: String = GFVariantData.to_text(frame_value)
		if not text.is_empty():
			var _text_appended: bool = parts.append(text)
	return " ".join(parts)


## 检查数组引用是否已在当前遍历路径的活动数组列表中。
## [br]
## @api private
static func _contains_active_array(active_arrays: Array, value: Array) -> bool:
	for active_value: Variant in active_arrays:
		if is_same(active_value, value):
			return true
	return false


## 迭代复制候选的 Dictionary/Array 图，保留容器类型约束、共享引用和循环关系。
## 非容器值按 Variant helper 的非 Resource 复制模式处理，Object/Resource 身份不因此隔离。
## [br]
## @api private
static func _duplicate_candidate(candidate: Dictionary) -> Dictionary:
	var candidate_copy: Dictionary = candidate.duplicate(false)
	candidate_copy.clear()
	var visited: Array[Dictionary] = [{
		"source": candidate,
		"copy": candidate_copy,
	}]
	var pending: Array[Dictionary] = [{
		"source": candidate,
		"copy": candidate_copy,
	}]
	while not pending.is_empty():
		var frame: Dictionary = pending.pop_back()
		var source: Variant = GFVariantData.get_option_value(frame, "source")
		var target: Variant = GFVariantData.get_option_value(frame, "copy")
		if source is Dictionary and target is Dictionary:
			var source_dictionary: Dictionary = source
			var target_dictionary: Dictionary = target
			for key: Variant in source_dictionary.keys():
				var copied_key: Variant = _get_or_create_candidate_copy(key, visited, pending)
				var copied_value: Variant = _get_or_create_candidate_copy(
					source_dictionary[key],
					visited,
					pending
				)
				target_dictionary[copied_key] = copied_value
		elif source is Array and target is Array:
			var source_array: Array = source
			var target_array: Array = target
			for item: Variant in source_array:
				target_array.append(_get_or_create_candidate_copy(item, visited, pending))
	return candidate_copy


## 按容器身份复用已登记副本；新容器先登记空壳再排队填充，令循环引用能指回同一副本。
## [br]
## @api private
static func _get_or_create_candidate_copy(
	value: Variant,
	visited: Array[Dictionary],
	pending: Array[Dictionary]
) -> Variant:
	if not (value is Dictionary or value is Array):
		return GFVariantData.duplicate_variant(value, true, false)
	for record: Dictionary in visited:
		if is_same(GFVariantData.get_option_value(record, "source"), value):
			return GFVariantData.get_option_value(record, "copy")
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		var dictionary_copy: Dictionary = source_dictionary.duplicate(false)
		dictionary_copy.clear()
		visited.append({
			"source": source_dictionary,
			"copy": dictionary_copy,
		})
		pending.append({
			"source": source_dictionary,
			"copy": dictionary_copy,
		})
		return dictionary_copy
	var source_array: Array = value
	var array_copy: Array = source_array.duplicate(false)
	array_copy.clear()
	visited.append({
		"source": source_array,
		"copy": array_copy,
	})
	pending.append({
		"source": source_array,
		"copy": array_copy,
	})
	return array_copy


## 去除首尾空白、按需转小写，并将分隔字符合并为空格。
## [br]
## @api private
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


## 判断 needle 中的字符能否按顺序在 haystack 中找到。
## [br]
## @api private
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


## 创建包含 matched、score 与 matched_tokens 的文本评分报告。
## [br]
## @api private
static func _make_text_score_report(matched: bool, score: float, matched_tokens: PackedStringArray) -> Dictionary:
	return {
		"matched": matched,
		"score": score,
		"matched_tokens": matched_tokens,
	}


## 从评分报告读取匹配 token，并兼容 PackedStringArray 与普通 Array。
## [br]
## @api private
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


## 按查询 token 的原始次序筛选候选中已匹配的 token。
## [br]
## @api private
static func _collect_tokens_in_query_order(tokens: PackedStringArray, matched_lookup: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for token: String in tokens:
		if matched_lookup.has(token):
			var _append_result: bool = result.append(token)
	return result


## 依次按分数降序、标题升序和原始候选索引升序排列报告。
## [br]
## @api private
static func _sort_reports_descending(left: Dictionary, right: Dictionary) -> bool:
	var left_score: float = GFVariantData.get_option_float(left, "score", 0.0)
	var right_score: float = GFVariantData.get_option_float(right, "score", 0.0)
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score

	var left_title: String = _get_report_sort_title(left)
	var right_title: String = _get_report_sort_title(right)
	return _compare_rank_values(left_score, right_score, left_title, right_title, GFVariantData.get_option_int(left, "index", 0), GFVariantData.get_option_int(right, "index", 0))


## 私有独立排序键只读引用；索引数组与报告数组使用相同的原生排序算法和初始顺序。
## [br]
## @api private
static func _sort_ranking_indices(left: int, right: int, scores: PackedFloat64Array, titles: PackedStringArray, indices: PackedInt64Array) -> bool:
	return _compare_rank_values(scores[left], scores[right], titles[left], titles[right], indices[left], indices[right])


## 共享近似分数、标题和全局索引比较规则；不修改近似相等关系。
## [br]
## @api private
static func _compare_rank_values(left_score: float, right_score: float, left_title: String, right_title: String, left_index: int, right_index: int) -> bool:
	if not is_equal_approx(left_score, right_score):
		return left_score > right_score
	if left_title != right_title:
		return left_title < right_title
	return left_index < right_index


## 从 title 或备用 name 字段构造小写排序文本。
## [br]
## @api private
static func _get_report_sort_title(report: Dictionary) -> String:
	var candidate: Dictionary = {}
	var candidate_value: Variant = GFVariantData.get_option_value(report, "candidate")
	if candidate_value is Dictionary:
		candidate = candidate_value
	var title: String = _value_to_search_text(_get_candidate_value(candidate, &"title"))
	if title.is_empty():
		title = _value_to_search_text(_get_candidate_value(candidate, &"name"))
	return title.to_lower()
