## GFAssetCatalog: 通用资产目录。
##
## 用稳定 asset_id 管理 `GFAssetCatalogEntry`，提供标签、分类、文本搜索、
## 摘要、分页和序列化能力。目录只保存可重建的资产索引，不规定项目目录、
## 内容包、业务分类或导出策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFAssetCatalog
extends Resource


# --- 常量 ---

## 按资产 ID 分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_ID: StringName = &"asset_id"

## 按资产来源分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_SOURCE_ID: StringName = &"source_id"

## 按分类分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_CATEGORY: StringName = &"category"

## 按标签分组。一个资产可进入多个标签组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_TAGS: StringName = &"tags"

## 按主资源类型提示分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_TYPE_HINT: StringName = &"type_hint"

## 按主资源路径分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_PRIMARY_PATH: StringName = &"primary_path"

## 按主资源身份缓存键分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_CACHE_KEY: StringName = &"cache_key"

## 按关联资源注册表条目 ID 分组。
## [br]
## @api public
## [br]
## @since 8.0.0
const GROUP_SOURCE_RESOURCE_ENTRY_ID: StringName = &"resource_entry_id"

const _DEFAULT_SEARCH_FIELDS: Array[Dictionary] = [
	{ "key": "title", "weight": 4.0 },
	{ "key": "asset_id", "weight": 3.0 },
	{ "key": "tags", "weight": 2.0 },
	{ "key": "category", "weight": 2.0 },
	{ "key": "description", "weight": 1.5 },
	{ "key": "primary_path", "weight": 1.0 },
	{ "key": "type_hint", "weight": 1.0 },
	{ "key": "metadata_keywords", "weight": 0.5 },
]


# --- 导出变量 ---

## 资产目录条目。重复 asset_id 会以后出现的有效条目为准。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema entries: Array[GFAssetCatalogEntry] asset catalog entries.
@export var entries: Array[GFAssetCatalogEntry] = []


# --- 私有变量 ---

var _entry_lookup: Dictionary = {}
var _index: GFValueIndex = GFValueIndex.new()
var _index_dirty: bool = true


# --- 公共方法 ---

## 添加或替换资产条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entry: 要写入的资产条目。
## [br]
## @return 写入成功返回 true。
func set_entry(entry: GFAssetCatalogEntry) -> bool:
	if not _is_valid_entry(entry):
		return false

	var stored_entry: GFAssetCatalogEntry = entry.duplicate_entry()
	for index: int in range(entries.size() - 1, -1, -1):
		var existing: GFAssetCatalogEntry = entries[index]
		if _is_valid_entry(existing) and existing.asset_id == stored_entry.asset_id:
			entries.remove_at(index)

	entries.append(stored_entry)
	mark_index_dirty()
	return true


## 移除资产条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_id: 资产稳定 ID。
## [br]
## @return 移除成功返回 true。
func remove_entry(asset_id: StringName) -> bool:
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: GFAssetCatalogEntry = entries[index]
		if _is_valid_entry(entry) and entry.asset_id == asset_id:
			entries.remove_at(index)
			mark_index_dirty()
			return true
	return false


## 清空目录。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear() -> void:
	entries.clear()
	mark_index_dirty()


## 标记运行时索引需要重建。
## [br]
## @api public
## [br]
## @since 8.0.0
func mark_index_dirty() -> void:
	_index_dirty = true


## 立即重建运行时索引。
## [br]
## @api public
## [br]
## @since 8.0.0
func rebuild_index() -> void:
	_entry_lookup.clear()
	_index.clear()
	for entry: GFAssetCatalogEntry in entries:
		if not _is_valid_entry(entry):
			continue
		var stored_entry: GFAssetCatalogEntry = entry.duplicate_entry()
		_entry_lookup[stored_entry.asset_id] = stored_entry
		var _indexed: bool = _index.set_item(
			stored_entry.asset_id,
			String(stored_entry.asset_id),
			_make_index_fields(stored_entry)
		)
	_index_dirty = false


## 检查资产是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_id: 资产稳定 ID。
## [br]
## @return 存在时返回 true。
func has_entry(asset_id: StringName) -> bool:
	_ensure_index()
	return _entry_lookup.has(asset_id)


## 获取资产条目副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_id: 资产稳定 ID。
## [br]
## @return 条目副本；不存在时返回 null。
func get_entry(asset_id: StringName) -> GFAssetCatalogEntry:
	_ensure_index()
	var entry: GFAssetCatalogEntry = _get_entry_value(GFVariantData.get_option_value(_entry_lookup, asset_id))
	if entry == null:
		return null
	return entry.duplicate_entry()


## 获取全部有效资产 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 排序后的资产 ID 列表。
func get_all_ids() -> PackedStringArray:
	_ensure_index()
	var result: PackedStringArray = PackedStringArray()
	for asset_id_value: Variant in _entry_lookup.keys():
		var _appended: bool = result.append(GFVariantData.to_text(asset_id_value))
	result.sort()
	return result


## 按单个字段值查询资产 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param field_id: 字段标识。
## [br]
## @param field_value: 字段值。
## [br]
## @return 匹配的资产 ID。
## [br]
## @schema field_value: Variant indexed field value.
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
	_ensure_index()
	return _index.query(field_id, field_value)


## 按多个字段查询资产 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param criteria: 字段到值的查询条件。
## [br]
## @param match_all: true 表示交集查询，false 表示并集查询。
## [br]
## @return 匹配的资产 ID。
## [br]
## @schema criteria: Dictionary from field id to query value.
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
	_ensure_index()
	return _index.query_many(criteria, match_all)


## 合并另一份目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param catalog: 要合并的资产目录。
## [br]
## @param options: 可选项，支持 overwrite。
## [br]
## @schema options: Dictionary with optional overwrite: bool.
## [br]
## @return 合并报告。
## [br]
## @schema return: Dictionary with added_count, replaced_count, skipped_count, and duplicate_ids.
func merge_catalog(catalog: GFAssetCatalog, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"added_count": 0,
		"replaced_count": 0,
		"skipped_count": 0,
		"duplicate_ids": PackedStringArray(),
	}
	if catalog == null:
		return report

	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", true)
	for asset_id_text: String in catalog.get_all_ids():
		var entry: GFAssetCatalogEntry = catalog.get_entry(StringName(asset_id_text))
		if entry == null:
			continue
		var exists: bool = has_entry(entry.asset_id)
		if exists and not overwrite:
			report["skipped_count"] = GFVariantData.get_option_int(report, "skipped_count") + 1
			var duplicate_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
				report,
				"duplicate_ids",
				PackedStringArray()
			)
			if not duplicate_ids.has(asset_id_text):
				var _duplicate_appended: bool = duplicate_ids.append(asset_id_text)
			report["duplicate_ids"] = duplicate_ids
			continue
		if set_entry(entry):
			report["replaced_count" if exists else "added_count"] = GFVariantData.get_option_int(
				report,
				"replaced_count" if exists else "added_count"
			) + 1
	return report


## 构建可交给 GFTextSearchScorer 的搜索候选。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_ids: 要导出的资产 ID；为空时导出全部有效条目。
## [br]
## @return 搜索候选字典数组。
## [br]
## @schema asset_ids: PackedStringArray selected asset ids.
## [br]
## @schema return: Array[Dictionary] where each candidate contains id, asset_id, title, description, tags, category, primary_path, preview_path, type_hint, source_id, resource_entry_ids, cache_key, and metadata_keywords.
func make_search_candidates(asset_ids: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	_ensure_index()
	var include_all: bool = asset_ids.is_empty()
	var result: Array[Dictionary] = []
	for asset_id_text: String in get_all_ids():
		if not include_all and not asset_ids.has(asset_id_text):
			continue
		var entry: GFAssetCatalogEntry = _get_entry_value(
			GFVariantData.get_option_value(_entry_lookup, StringName(asset_id_text))
		)
		if entry == null:
			continue
		result.append(_make_search_candidate(entry))
	return result


## 用通用文本评分器搜索资产。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param query_text: 查询文本。
## [br]
## @param options: 可选项，支持 GFTextSearchScorer.rank_candidates() 的选项，并额外支持 asset_ids。
## [br]
## @schema options: Dictionary with optional asset_ids plus GFTextSearchScorer rank options.
## [br]
## @return 排序后的匹配报告数组。
## [br]
## @schema return: Array[Dictionary] from GFTextSearchScorer.rank_candidates().
func search(query_text: String, options: Dictionary = {}) -> Array[Dictionary]:
	var asset_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"asset_ids",
		PackedStringArray()
	)
	var candidates: Array[Dictionary] = make_search_candidates(asset_ids)
	var scorer_options: Dictionary = options.duplicate(true)
	if not scorer_options.has("fields"):
		scorer_options["fields"] = _DEFAULT_SEARCH_FIELDS.duplicate(true)
	return GFTextSearchScorer.rank_candidates(query_text, candidates, scorer_options)


## 构建资产摘要。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_id: 资产稳定 ID。
## [br]
## @param options: 可选项，支持 include_metadata。
## [br]
## @schema options: Dictionary with optional include_metadata: bool.
## [br]
## @return 资产摘要；不存在时返回空字典。
## [br]
## @schema return: Dictionary with id, asset_id, title, description, tags, category, primary_path, type_hint, preview_path, source_id, resource_entry_ids, cache_key, primary_identity, preview_identity, and optional metadata.
func make_asset_summary(asset_id: StringName, options: Dictionary = {}) -> Dictionary:
	_ensure_index()
	var entry: GFAssetCatalogEntry = _get_entry_value(GFVariantData.get_option_value(_entry_lookup, asset_id))
	if entry == null:
		return {}

	var primary_identity: GFResourceIdentity = entry.get_primary_identity()
	var preview_identity: GFResourceIdentity = entry.get_preview_identity()
	var title_text: String = entry.title.strip_edges()
	if title_text.is_empty():
		title_text = String(entry.asset_id)
	if title_text.is_empty():
		title_text = entry.primary_path.get_file().get_basename()

	var summary: Dictionary = {
		"id": String(entry.asset_id),
		"asset_id": String(entry.asset_id),
		"title": title_text,
		"description": entry.description,
		"tags": entry.tags.duplicate(),
		"category": String(entry.category),
		"primary_path": entry.primary_path,
		"type_hint": entry.type_hint,
		"preview_path": entry.preview_path,
		"source_id": String(entry.source_id),
		"resource_entry_ids": entry.resource_entry_ids.duplicate(),
		"cache_key": primary_identity.cache_key,
		"primary_identity": primary_identity.to_dictionary(),
		"preview_identity": preview_identity.to_dictionary() if preview_identity != null else {},
	}
	if GFVariantData.get_option_bool(options, "include_metadata", true):
		summary["metadata"] = entry.metadata.duplicate(true)
	return summary


## 批量构建资产摘要。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param asset_ids: 要导出的资产 ID；为空时导出全部有效条目。
## [br]
## @param options: 传给 make_asset_summary() 的摘要选项。
## [br]
## @schema asset_ids: PackedStringArray selected asset ids.
## [br]
## @schema options: Dictionary summary options.
## [br]
## @return 资产摘要数组。
## [br]
## @schema return: Array[Dictionary] where each item is make_asset_summary() output.
func make_asset_summaries(asset_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {}) -> Array[Dictionary]:
	var selected_asset_ids: PackedStringArray = asset_ids
	if selected_asset_ids.is_empty():
		selected_asset_ids = get_all_ids()

	var result: Array[Dictionary] = []
	var lookup: Dictionary = {}
	for asset_id_text: String in selected_asset_ids:
		if lookup.has(asset_id_text):
			continue
		lookup[asset_id_text] = true
		var summary: Dictionary = make_asset_summary(StringName(asset_id_text), options)
		if not summary.is_empty():
			result.append(summary)
	return result


## 搜索资产并返回分页报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param query_text: 查询文本；为空时默认按资产 ID 列出资产。
## [br]
## @param page: 页码，从 1 开始。
## [br]
## @param page_size: 每页数量，会被规整为至少 1。
## [br]
## @param options: 可选项，支持 search() 选项，并额外支持 empty_query_returns_all、include_summaries 和 summary_options。
## [br]
## @schema options: Dictionary with search options, empty_query_returns_all: bool, include_summaries: bool, and summary_options: Dictionary.
## [br]
## @return 分页搜索报告。
## [br]
## @schema return: Dictionary with query, page, page_size, page_count, total_count, start_index, end_index, has_previous, has_next, results, asset_ids, and summaries.
func search_page(
	query_text: String,
	page: int = 1,
	page_size: int = 50,
	options: Dictionary = {}
) -> Dictionary:
	var reports: Array[Dictionary] = _get_search_page_reports(query_text, options)
	var total_count: int = reports.size()
	var normalized_page_size: int = maxi(page_size, 1)
	var page_count: int = ceili(float(total_count) / float(normalized_page_size)) if total_count > 0 else 0
	var normalized_page: int = maxi(page, 1)
	if page_count > 0:
		normalized_page = mini(normalized_page, page_count)
	else:
		normalized_page = 1

	var start_index: int = 0
	var end_index: int = 0
	if total_count > 0:
		start_index = (normalized_page - 1) * normalized_page_size
		end_index = mini(start_index + normalized_page_size, total_count)

	var page_results: Array[Dictionary] = []
	var page_asset_ids: PackedStringArray = PackedStringArray()
	for index: int in range(start_index, end_index):
		var report: Dictionary = reports[index]
		page_results.append(report)
		var report_asset_id: String = _get_search_report_asset_id(report)
		if not report_asset_id.is_empty():
			var _asset_id_appended: bool = page_asset_ids.append(report_asset_id)

	var summaries: Array[Dictionary] = []
	if GFVariantData.get_option_bool(options, "include_summaries", true):
		summaries = make_asset_summaries(
			page_asset_ids,
			GFVariantData.get_option_dictionary(options, "summary_options")
		)

	return {
		"query": query_text,
		"page": normalized_page,
		"page_size": normalized_page_size,
		"page_count": page_count,
		"total_count": total_count,
		"start_index": start_index,
		"end_index": end_index,
		"has_previous": normalized_page > 1 and total_count > 0,
		"has_next": page_count > 0 and normalized_page < page_count,
		"results": page_results,
		"asset_ids": page_asset_ids,
		"summaries": summaries,
	}


## 按通用来源把资产 ID 分组。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param group_source: 分组来源。
## [br]
## @param options: 可选项，支持 asset_ids、include_empty 和 empty_key。
## [br]
## @schema options: Dictionary with optional asset_ids, include_empty, and empty_key.
## [br]
## @return 分组字典，key 为分组文本，value 为排序后的资产 ID 列表。
## [br]
## @schema return: Dictionary[String, PackedStringArray] grouped asset ids.
func group_asset_ids(group_source: StringName = GROUP_SOURCE_ID, options: Dictionary = {}) -> Dictionary:
	_ensure_index()
	var selected_asset_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"asset_ids",
		PackedStringArray()
	)
	var include_all: bool = selected_asset_ids.is_empty()
	var include_empty: bool = GFVariantData.get_option_bool(options, "include_empty", false)
	var empty_key: String = GFVariantData.get_option_string(options, "empty_key")
	var groups: Dictionary = {}

	for asset_id_text: String in get_all_ids():
		if not include_all and not selected_asset_ids.has(asset_id_text):
			continue
		var entry: GFAssetCatalogEntry = _get_entry_value(
			GFVariantData.get_option_value(_entry_lookup, StringName(asset_id_text))
		)
		if entry == null:
			continue
		for group_key: String in _get_entry_group_keys(entry, group_source, include_empty, empty_key):
			var group_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
				groups,
				group_key,
				PackedStringArray()
			)
			if not group_ids.has(asset_id_text):
				var _group_id_appended: bool = group_ids.append(asset_id_text)
			groups[group_key] = group_ids
	return _sort_id_groups(groups)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 资产目录诊断信息。
## [br]
## @schema return: Dictionary with asset_count, indexed_field_count, and ids.
func get_debug_snapshot() -> Dictionary:
	_ensure_index()
	return {
		"asset_count": _entry_lookup.size(),
		"indexed_field_count": _index.get_index_count(),
		"ids": get_all_ids(),
	}


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 资产目录字典。
## [br]
## @schema return: Dictionary with entries array.
func to_dict() -> Dictionary:
	var entry_data: Array[Dictionary] = []
	for entry: GFAssetCatalogEntry in entries:
		if _is_valid_entry(entry):
			entry_data.append(entry.to_dict())
	return {
		"entries": entry_data,
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 资产目录字典。
## [br]
## @schema data: Dictionary with entries array.
func apply_dict(data: Dictionary) -> void:
	entries.clear()
	var raw_entries: Array = GFVariantData.get_option_array(data, "entries")
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			var entry: GFAssetCatalogEntry = GFAssetCatalogEntry.from_dict(GFVariantData.as_dictionary(raw_entry))
			if _is_valid_entry(entry):
				entries.append(entry)
	mark_index_dirty()


## 从字典创建资产目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 资产目录字典。
## [br]
## @schema data: Dictionary with entries array.
## [br]
## @return 新资产目录。
static func from_dict(data: Dictionary) -> GFAssetCatalog:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	catalog.apply_dict(data)
	return catalog


# --- 私有/辅助方法 ---

func _ensure_index() -> void:
	if _index_dirty:
		rebuild_index()


func _is_valid_entry(entry: GFAssetCatalogEntry) -> bool:
	return entry != null and entry.is_valid_entry()


func _get_entry_value(value: Variant) -> GFAssetCatalogEntry:
	if value is GFAssetCatalogEntry:
		var entry: GFAssetCatalogEntry = value
		return entry
	return null


func _make_index_fields(entry: GFAssetCatalogEntry) -> Dictionary:
	var fields: Dictionary = {
		GROUP_SOURCE_ID: String(entry.asset_id),
		GROUP_SOURCE_SOURCE_ID: String(entry.source_id),
		GROUP_SOURCE_CATEGORY: String(entry.category),
		GROUP_SOURCE_TAGS: entry.tags,
		GROUP_SOURCE_TYPE_HINT: entry.type_hint,
		GROUP_SOURCE_PRIMARY_PATH: entry.primary_path,
		GROUP_SOURCE_CACHE_KEY: entry.get_cache_key(),
		GROUP_SOURCE_RESOURCE_ENTRY_ID: entry.resource_entry_ids,
	}
	if not entry.metadata.is_empty():
		fields[&"metadata"] = _make_metadata_keywords(entry.metadata)
	return fields


func _make_search_candidate(entry: GFAssetCatalogEntry) -> Dictionary:
	var primary_identity: GFResourceIdentity = entry.get_primary_identity()
	var preview_identity: GFResourceIdentity = entry.get_preview_identity()
	return {
		"id": String(entry.asset_id),
		"asset_id": String(entry.asset_id),
		"title": entry.title,
		"description": entry.description,
		"tags": entry.tags.duplicate(),
		"category": String(entry.category),
		"primary_path": entry.primary_path,
		"preview_path": entry.preview_path,
		"type_hint": entry.type_hint,
		"source_id": String(entry.source_id),
		"resource_entry_ids": entry.resource_entry_ids.duplicate(),
		"cache_key": primary_identity.cache_key,
		"primary_identity": primary_identity.to_dictionary(),
		"preview_identity": preview_identity.to_dictionary() if preview_identity != null else {},
		"metadata_keywords": _make_metadata_keywords(entry.metadata),
	}


func _make_metadata_keywords(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	_append_metadata_keywords(result, lookup, value)
	result.sort()
	return result


func _append_metadata_keywords(result: PackedStringArray, lookup: Dictionary, value: Variant) -> void:
	if value == null:
		return
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary.keys():
			_append_metadata_keyword(result, lookup, GFVariantData.to_text(key))
			_append_metadata_keywords(result, lookup, dictionary[key])
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_metadata_keywords(result, lookup, item)
	elif value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item_text: String in packed_values:
			_append_metadata_keyword(result, lookup, item_text)
	elif (
		value is String
		or value is StringName
		or value is NodePath
		or value is bool
		or value is int
		or value is float
	):
		_append_metadata_keyword(result, lookup, GFVariantData.to_text(value))


func _append_metadata_keyword(result: PackedStringArray, lookup: Dictionary, value: String) -> void:
	var keyword: String = value.strip_edges()
	if keyword.is_empty() or lookup.has(keyword):
		return
	lookup[keyword] = true
	var _appended: bool = result.append(keyword)


func _get_search_page_reports(query_text: String, options: Dictionary) -> Array[Dictionary]:
	if (
		query_text.strip_edges().is_empty()
		and GFVariantData.get_option_bool(options, "empty_query_returns_all", true)
	):
		var asset_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
			options,
			"asset_ids",
			PackedStringArray()
		)
		return _make_listing_search_reports(make_search_candidates(asset_ids), options)
	return search(query_text, options)


func _make_listing_search_reports(candidates: Array[Dictionary], options: Dictionary) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var duplicate_candidate: bool = GFVariantData.get_option_bool(options, "duplicate_candidate", true)
	var limit: int = GFVariantData.get_option_int(options, "limit", 0)
	var count: int = candidates.size()
	if limit > 0:
		count = mini(count, limit)

	for index: int in range(count):
		var candidate: Dictionary = candidates[index]
		reports.append({
			"matched": false,
			"score": 0.0,
			"matched_tokens": PackedStringArray(),
			"field_scores": {},
			"candidate": candidate.duplicate(true) if duplicate_candidate else candidate,
			"index": index,
		})
	return reports


func _get_search_report_asset_id(report: Dictionary) -> String:
	var candidate: Dictionary = GFVariantData.get_option_dictionary(report, "candidate", {})
	var asset_id_text: String = GFVariantData.get_option_string(candidate, "asset_id")
	if asset_id_text.is_empty():
		asset_id_text = GFVariantData.get_option_string(candidate, "id")
	return asset_id_text


func _get_entry_group_keys(
	entry: GFAssetCatalogEntry,
	group_source: StringName,
	include_empty: bool,
	empty_key: String
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	match group_source:
		GROUP_SOURCE_ID:
			_append_group_key(result, lookup, String(entry.asset_id), include_empty, empty_key)
		GROUP_SOURCE_SOURCE_ID:
			_append_group_key(result, lookup, String(entry.source_id), include_empty, empty_key)
		GROUP_SOURCE_CATEGORY:
			_append_group_key(result, lookup, String(entry.category), include_empty, empty_key)
		GROUP_SOURCE_TAGS:
			_append_group_value(result, lookup, entry.tags, include_empty, empty_key)
		GROUP_SOURCE_TYPE_HINT:
			_append_group_key(result, lookup, entry.type_hint, include_empty, empty_key)
		GROUP_SOURCE_PRIMARY_PATH:
			_append_group_key(result, lookup, entry.primary_path, include_empty, empty_key)
		GROUP_SOURCE_CACHE_KEY:
			_append_group_key(result, lookup, entry.get_cache_key(), include_empty, empty_key)
		GROUP_SOURCE_RESOURCE_ENTRY_ID:
			_append_group_value(result, lookup, entry.resource_entry_ids, include_empty, empty_key)
	result.sort()
	return result


func _append_group_value(
	result: PackedStringArray,
	lookup: Dictionary,
	value: Variant,
	include_empty: bool,
	empty_key: String
) -> void:
	if value == null:
		_append_group_key(result, lookup, "", include_empty, empty_key)
	elif value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item_text: String in packed_values:
			_append_group_key(result, lookup, item_text, include_empty, empty_key)
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_group_value(result, lookup, item, include_empty, empty_key)
	else:
		_append_group_key(result, lookup, GFVariantData.to_text(value), include_empty, empty_key)


func _append_group_key(
	result: PackedStringArray,
	lookup: Dictionary,
	value: String,
	include_empty: bool,
	empty_key: String
) -> void:
	var group_key: String = value.strip_edges()
	if group_key.is_empty():
		if not include_empty:
			return
		group_key = empty_key
	if lookup.has(group_key):
		return
	lookup[group_key] = true
	var _appended: bool = result.append(group_key)


func _sort_id_groups(groups: Dictionary) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in groups.keys():
		var _key_appended: bool = keys.append(GFVariantData.to_text(key_value))
	keys.sort()

	var result: Dictionary = {}
	for key: String in keys:
		var ids: PackedStringArray = GFVariantData.get_option_packed_string_array(groups, key, PackedStringArray())
		ids.sort()
		result[key] = ids
	return result
