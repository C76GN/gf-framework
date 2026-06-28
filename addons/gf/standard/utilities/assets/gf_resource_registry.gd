## GFResourceRegistry: 通用资源注册表。
##
## 通过稳定 ID 管理资源路径、类型提示和字段索引，便于项目用统一方式查询、
## 预加载或加载资源定义。注册表只描述资源位置和通用字段，不规定物品、技能、
## 关卡、UI 或其他业务规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.21.0
class_name GFResourceRegistry
extends Resource


# --- 常量 ---

## 按条目 ID 分组。
## [br]
## @api public
## [br]
## @since 6.0.0
const GROUP_SOURCE_ID: StringName = &"id"

## 按完整资源路径分组。
## [br]
## @api public
## [br]
## @since 6.0.0
const GROUP_SOURCE_PATH: StringName = &"path"

## 按资源路径文件名去扩展名分组。
## [br]
## @api public
## [br]
## @since 6.0.0
const GROUP_SOURCE_PATH_BASENAME: StringName = &"path_basename"

## 按资源类型提示分组。
## [br]
## @api public
## [br]
## @since 6.0.0
const GROUP_SOURCE_TYPE_HINT: StringName = &"type_hint"

## 按条目 fields 中的字段值分组。字段名由 options.field_id 指定。
## [br]
## @api public
## [br]
## @since 6.0.0
const GROUP_SOURCE_FIELD: StringName = &"field"

const _DEFAULT_SUMMARY_TITLE_FIELDS: PackedStringArray = [
	"display_name",
	"name",
	"title",
]
const _DEFAULT_SUMMARY_DESCRIPTION_FIELDS: PackedStringArray = [
	"description",
	"summary",
]
const _DEFAULT_SUMMARY_PREVIEW_PATH_FIELDS: PackedStringArray = [
	"preview_path",
	"image_path",
	"thumbnail_path",
	"icon_path",
]
const _DEFAULT_SUMMARY_TAG_FIELDS: PackedStringArray = [
	"tags",
]
const _DEFAULT_SUMMARY_CATEGORY_FIELDS: PackedStringArray = [
	"category",
]


# --- 导出变量 ---

## 注册表条目列表。重复 ID 会以后出现的有效条目为准。
## [br]
## @api public
## [br]
## @schema entries: Array[GFResourceRegistryEntry] resource registry entries.
@export var entries: Array[GFResourceRegistryEntry] = []


# --- 私有变量 ---

var _entry_lookup: Dictionary = {}
var _index: GFValueIndex = GFValueIndex.new()
var _index_dirty: bool = true


# --- 公共方法 ---

## 添加或替换条目。
## [br]
## @api public
## [br]
## @param entry: 要写入的注册表条目。
## [br]
## @return 写入成功返回 true。
func set_entry(entry: Resource) -> bool:
	var source_entry: GFResourceRegistryEntry = _get_registry_entry_value(entry)
	if not _is_valid_registry_entry(source_entry):
		return false

	var stored_entry: GFResourceRegistryEntry = _duplicate_registry_entry(source_entry)
	var stored_entry_id: StringName = _get_entry_id(stored_entry)
	for index: int in range(entries.size() - 1, -1, -1):
		var existing: GFResourceRegistryEntry = entries[index]
		if _is_valid_registry_entry(existing) and _get_entry_id(existing) == stored_entry_id:
			entries.remove_at(index)

	entries.append(stored_entry)
	mark_index_dirty()
	return true


## 移除条目。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 移除成功返回 true。
func remove_entry(entry_id: StringName) -> bool:
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: GFResourceRegistryEntry = entries[index]
		if _is_valid_registry_entry(entry) and _get_entry_id(entry) == entry_id:
			entries.remove_at(index)
			mark_index_dirty()
			return true
	return false


## 清空注册表。
## [br]
## @api public
func clear() -> void:
	entries.clear()
	mark_index_dirty()


## 标记运行时索引需要重建。
## 直接修改 entries 数组或条目字段后，应调用本方法。
## [br]
## @api public
func mark_index_dirty() -> void:
	_index_dirty = true


## 立即重建运行时索引。
## [br]
## @api public
func rebuild_index() -> void:
	_entry_lookup.clear()
	_index.clear()
	for entry: GFResourceRegistryEntry in entries:
		if not _is_valid_registry_entry(entry):
			continue
		var stored_entry: GFResourceRegistryEntry = _duplicate_registry_entry(entry)
		var entry_id: StringName = _get_entry_id(stored_entry)
		_entry_lookup[entry_id] = stored_entry
		var _indexed: bool = _index.set_item(entry_id, _get_entry_path(stored_entry), _get_entry_fields(stored_entry))
	_index_dirty = false


## 检查条目是否存在。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 条目存在时返回 true。
func has_entry(entry_id: StringName) -> bool:
	_ensure_index()
	return _entry_lookup.has(entry_id)


## 获取条目副本。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 条目副本；不存在时返回 null。
func get_entry(entry_id: StringName) -> Resource:
	_ensure_index()
	var entry: GFResourceRegistryEntry = _get_registry_entry_value(GFVariantData.get_option_value(_entry_lookup, entry_id))
	if entry == null:
		return null
	return _duplicate_registry_entry(entry)


## 获取条目资源路径。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 资源路径；不存在时返回空字符串。
func get_entry_path(entry_id: StringName) -> String:
	_ensure_index()
	var entry: GFResourceRegistryEntry = _get_registry_entry_value(GFVariantData.get_option_value(_entry_lookup, entry_id))
	if entry == null:
		return ""
	return _get_entry_path(entry)


## 获取条目类型提示。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 类型提示；不存在时返回空字符串。
func get_entry_type_hint(entry_id: StringName) -> String:
	_ensure_index()
	var entry: GFResourceRegistryEntry = _get_registry_entry_value(GFVariantData.get_option_value(_entry_lookup, entry_id))
	if entry == null:
		return ""
	return _get_entry_type_hint(entry)


## 获取条目字段副本。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @return 字段字典副本。
## [br]
## @schema return: Dictionary indexed field values.
func get_entry_fields(entry_id: StringName) -> Dictionary:
	_ensure_index()
	var entry: GFResourceRegistryEntry = _get_registry_entry_value(GFVariantData.get_option_value(_entry_lookup, entry_id))
	if entry == null:
		return {}
	return _get_entry_fields(entry)


## 获取全部有效条目 ID。
## [br]
## @api public
## [br]
## @return 排序后的条目 ID 列表。
func get_all_ids() -> PackedStringArray:
	_ensure_index()
	var result: PackedStringArray = PackedStringArray()
	for entry_id_value: Variant in _entry_lookup.keys():
		var entry_id: StringName = GFVariantData.to_string_name(entry_id_value)
		var _appended: bool = result.append(String(entry_id))
	result.sort()
	return result


## 获取全部有效资源路径。
## [br]
## @api public
## [br]
## @return 排序后的资源路径列表。
func get_all_paths() -> PackedStringArray:
	_ensure_index()
	var lookup: Dictionary = {}
	for entry_value: Variant in _entry_lookup.values():
		var entry: GFResourceRegistryEntry = _get_registry_entry_value(entry_value)
		if entry == null:
			continue
		lookup[_get_entry_path(entry)] = true

	var result: PackedStringArray = PackedStringArray()
	for path_value: Variant in lookup.keys():
		var path: String = GFVariantData.to_text(path_value)
		var _appended: bool = result.append(path)
	result.sort()
	return result


## 按单个字段值查询条目 ID。
## [br]
## @api public
## [br]
## @param field_id: 字段标识。
## [br]
## @param field_value: 字段值。
## [br]
## @return 匹配的条目 ID。
## [br]
## @schema field_value: Variant indexed field value.
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
	_ensure_index()
	return _index.query(field_id, field_value)


## 按多个字段查询条目 ID。
## [br]
## @api public
## [br]
## @param criteria: 字段到值的查询条件。
## [br]
## @param match_all: true 表示交集查询，false 表示并集查询。
## [br]
## @return 匹配的条目 ID。
## [br]
## @schema criteria: Dictionary from field id to query value.
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
	_ensure_index()
	return _index.query_many(criteria, match_all)


## 构建可交给 GFTextSearchScorer 的搜索候选。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_ids: 要导出的条目 ID；为空时导出全部有效条目。
## [br]
## @return 搜索候选字典数组。
## [br]
## @schema entry_ids: PackedStringArray selected entry ids.
## [br]
## @schema return: Array[Dictionary] where each candidate contains id, entry_id, title, name, path, type_hint, keywords, and fields.
func make_search_candidates(entry_ids: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	_ensure_index()
	var include_all: bool = entry_ids.is_empty()
	var result: Array[Dictionary] = []
	for entry_id_string: String in get_all_ids():
		if not include_all and not entry_ids.has(entry_id_string):
			continue
		var entry_id: StringName = StringName(entry_id_string)
		var entry: GFResourceRegistryEntry = _get_registry_entry_value(
			GFVariantData.get_option_value(_entry_lookup, entry_id)
		)
		if entry == null:
			continue
		result.append(_make_search_candidate(entry))
	return result


## 用通用文本评分器搜索注册表条目。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param query_text: 查询文本。
## [br]
## @param options: 可选项，支持 GFTextSearchScorer.rank_candidates() 的选项，并额外支持 entry_ids。
## [br]
## @schema options: Dictionary with optional entry_ids: PackedStringArray or Array[String], plus GFTextSearchScorer rank options.
## [br]
## @return 排序后的匹配报告数组。
## [br]
## @schema return: Array[Dictionary] from GFTextSearchScorer.rank_candidates().
func search(query_text: String, options: Dictionary = {}) -> Array[Dictionary]:
	var entry_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"entry_ids",
		PackedStringArray()
	)
	var candidates: Array[Dictionary] = make_search_candidates(entry_ids)
	var scorer_options: Dictionary = options.duplicate(true)
	if not scorer_options.has("fields"):
		scorer_options["fields"] = [
			{ "key": "title", "weight": 4.0 },
			{ "key": "name", "weight": 3.0 },
			{ "key": "keywords", "weight": 2.0 },
			{ "key": "type_hint", "weight": 1.0 },
			{ "key": "path", "weight": 1.0 },
		]
	return GFTextSearchScorer.rank_candidates(query_text, candidates, scorer_options)


## 构建单个条目的工具层摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @param options: 可选项，支持 title_fields、description_fields、preview_path_fields、tag_fields、category_fields 和 include_fields。
## [br]
## @schema options: Dictionary where field list options are PackedStringArray or Array[String], and include_fields controls whether fields is copied into the summary.
## [br]
## @return 条目摘要；条目不存在时返回空字典。
## [br]
## @schema return: Dictionary with id, entry_id, title, path, path_basename, type_hint, description, preview_path, tags, category, and optional fields.
func make_entry_summary(entry_id: StringName, options: Dictionary = {}) -> Dictionary:
	_ensure_index()
	var entry: GFResourceRegistryEntry = _get_registry_entry_value(GFVariantData.get_option_value(_entry_lookup, entry_id))
	if entry == null:
		return {}

	var fields: Dictionary = _get_entry_fields(entry)
	var entry_path: String = _get_entry_path(entry)
	var id_text: String = String(_get_entry_id(entry))
	var title: String = _get_first_entry_field_text(
		fields,
		_get_summary_field_ids(options, "title_fields", _DEFAULT_SUMMARY_TITLE_FIELDS)
	)
	if title.is_empty():
		title = id_text
	if title.is_empty():
		title = entry_path.get_file().get_basename()

	var summary: Dictionary = {
		"id": id_text,
		"entry_id": id_text,
		"title": title,
		"path": entry_path,
		"path_basename": entry_path.get_file().get_basename(),
		"type_hint": _get_entry_type_hint(entry),
		"description": _get_first_entry_field_text(
			fields,
			_get_summary_field_ids(options, "description_fields", _DEFAULT_SUMMARY_DESCRIPTION_FIELDS)
		),
		"preview_path": _get_first_entry_field_text(
			fields,
			_get_summary_field_ids(options, "preview_path_fields", _DEFAULT_SUMMARY_PREVIEW_PATH_FIELDS)
		),
		"tags": _get_entry_summary_tags(
			fields,
			_get_summary_field_ids(options, "tag_fields", _DEFAULT_SUMMARY_TAG_FIELDS)
		),
		"category": _get_first_entry_field_text(
			fields,
			_get_summary_field_ids(options, "category_fields", _DEFAULT_SUMMARY_CATEGORY_FIELDS)
		),
	}
	if GFVariantData.get_option_bool(options, "include_fields", true):
		summary["fields"] = fields
	return summary


## 批量构建条目摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_ids: 要导出的条目 ID；为空时导出全部有效条目。
## [br]
## @param options: 传给 make_entry_summary() 的摘要选项。
## [br]
## @schema entry_ids: PackedStringArray selected entry ids.
## [br]
## @schema options: Dictionary summary options.
## [br]
## @return 条目摘要数组。
## [br]
## @schema return: Array[Dictionary] where each item is make_entry_summary() output.
func make_entry_summaries(entry_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_entry_ids: PackedStringArray = entry_ids
	if selected_entry_ids.is_empty():
		selected_entry_ids = get_all_ids()

	var lookup: Dictionary = {}
	for entry_id_string: String in selected_entry_ids:
		if lookup.has(entry_id_string):
			continue
		lookup[entry_id_string] = true
		var summary: Dictionary = make_entry_summary(StringName(entry_id_string), options)
		if not summary.is_empty():
			result.append(summary)
	return result


## 搜索条目并返回分页报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param query_text: 查询文本；为空时默认按当前候选顺序列出条目。
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
## @schema return: Dictionary with query, page, page_size, page_count, total_count, start_index, end_index, has_previous, has_next, results, entry_ids, and summaries.
func search_page(
	query_text: String,
	page: int = 1,
	page_size: int = 50,
	options: Dictionary = {}
) -> Dictionary:
	var reports: Array[Dictionary] = _get_search_page_reports(query_text, options)
	var total_count: int = reports.size()
	var normalized_page_size: int = maxi(page_size, 1)
	var page_count: int = 0
	if total_count > 0:
		page_count = ceili(float(total_count) / float(normalized_page_size))

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
	var page_entry_ids: PackedStringArray = PackedStringArray()
	for index: int in range(start_index, end_index):
		var report: Dictionary = reports[index]
		page_results.append(report)
		var report_entry_id: String = _get_search_report_entry_id(report)
		if not report_entry_id.is_empty():
			var _append_entry_id: bool = page_entry_ids.append(report_entry_id)

	var summaries: Array[Dictionary] = []
	if GFVariantData.get_option_bool(options, "include_summaries", true):
		summaries = make_entry_summaries(
			page_entry_ids,
			GFVariantData.get_option_dictionary(options, "summary_options", {})
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
		"entry_ids": page_entry_ids,
		"summaries": summaries,
	}


## 按通用来源把条目 ID 分组。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param group_source: 分组来源，支持 GROUP_SOURCE_ID、GROUP_SOURCE_PATH、GROUP_SOURCE_PATH_BASENAME、GROUP_SOURCE_TYPE_HINT 与 GROUP_SOURCE_FIELD。
## [br]
## @param options: 可选项，支持 entry_ids、field_id、include_empty 和 empty_key。
## [br]
## @schema options: Dictionary with optional entry_ids, field_id, include_empty, and empty_key.
## [br]
## @return 分组字典，key 为分组文本，value 为排序后的条目 ID 列表。
## [br]
## @schema return: Dictionary[String, PackedStringArray] grouped entry ids.
func group_entry_ids(group_source: StringName = GROUP_SOURCE_ID, options: Dictionary = {}) -> Dictionary:
	_ensure_index()
	var selected_entry_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"entry_ids",
		PackedStringArray()
	)
	var include_all: bool = selected_entry_ids.is_empty()
	var field_id: StringName = GFVariantData.get_option_string_name(options, "field_id")
	var include_empty: bool = GFVariantData.get_option_bool(options, "include_empty", false)
	var empty_key: String = GFVariantData.get_option_string(options, "empty_key")
	var groups: Dictionary = {}

	for entry_id_string: String in get_all_ids():
		if not include_all and not selected_entry_ids.has(entry_id_string):
			continue
		var entry_id: StringName = StringName(entry_id_string)
		var entry: GFResourceRegistryEntry = _get_registry_entry_value(
			GFVariantData.get_option_value(_entry_lookup, entry_id)
		)
		if entry == null:
			continue

		for group_key: String in _get_entry_group_keys(entry, group_source, field_id, include_empty, empty_key):
			var group_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
				groups,
				group_key,
				PackedStringArray()
			)
			if not group_ids.has(entry_id_string):
				var _append_group_id: bool = group_ids.append(entry_id_string)
			groups[group_key] = group_ids
	return _sort_entry_id_groups(groups)


## 同步加载条目资源。
## [br]
## @api public
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @param type_hint_override: 可选类型提示覆盖；为空时使用条目自己的 type_hint。
## [br]
## @param cache_mode: ResourceLoader 缓存模式。
## [br]
## @return 加载到的资源；不存在或加载失败时返回 null。
func load_entry(
	entry_id: StringName,
	type_hint_override: String = "",
	cache_mode: int = ResourceLoader.CACHE_MODE_REUSE
) -> Resource:
	var path: String = get_entry_path(entry_id)
	if path.is_empty():
		return null

	var resolved_type_hint: String = _resolve_type_hint(entry_id, type_hint_override)
	if not ResourceLoader.exists(path, resolved_type_hint):
		return null
	return ResourceLoader.load(path, resolved_type_hint, cache_mode)


## 通过 GFAssetUtility 异步加载条目资源。
## [br]
## @api public
## [br]
## @param asset_utility: 资源加载工具。
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @param on_loaded: 加载完成回调，签名为 func(resource: Resource)。
## [br]
## @param type_hint_override: 可选类型提示覆盖；为空时使用条目自己的 type_hint。
func request_entry_async(
	asset_utility: GFAssetUtility,
	entry_id: StringName,
	on_loaded: Callable,
	type_hint_override: String = ""
) -> void:
	if asset_utility == null or not on_loaded.is_valid():
		push_error("[GFResourceRegistry] request_entry_async 失败：asset_utility 或 on_loaded 无效。")
		if on_loaded.is_valid():
			on_loaded.call(null)
		return

	var path: String = get_entry_path(entry_id)
	if path.is_empty():
		on_loaded.call(null)
		return

	asset_utility.load_async(path, on_loaded, _resolve_type_hint(entry_id, type_hint_override))


## 通过 GFAssetUtility 异步加载条目资源并返回所有权句柄。
## [br]
## @api public
## [br]
## @param asset_utility: 资源加载工具。
## [br]
## @param entry_id: 条目稳定 ID。
## [br]
## @param on_loaded: 加载完成回调，签名为 func(handle: GFAssetHandle)。
## [br]
## @param owner: 可选拥有者。
## [br]
## @param group_id: 可选资源分组。
## [br]
## @param type_hint_override: 可选类型提示覆盖；为空时使用条目自己的 type_hint。
func request_entry_handle_async(
	asset_utility: GFAssetUtility,
	entry_id: StringName,
	on_loaded: Callable,
	owner: Object = null,
	group_id: StringName = &"",
	type_hint_override: String = ""
) -> void:
	if asset_utility == null or not on_loaded.is_valid():
		push_error("[GFResourceRegistry] request_entry_handle_async 失败：asset_utility 或 on_loaded 无效。")
		if on_loaded.is_valid():
			on_loaded.call(null)
		return

	var path: String = get_entry_path(entry_id)
	if path.is_empty():
		on_loaded.call(null)
		return

	asset_utility.load_handle_async(
		path,
		on_loaded,
		_resolve_type_hint(entry_id, type_hint_override),
		owner,
		group_id
	)


## 构建可传给 GFAssetUtility.preload_group_async() 的资源请求列表。
## [br]
## @api public
## [br]
## @param entry_ids: 要导出的条目 ID；为空时导出全部有效条目。
## [br]
## @return 资源请求列表。
## [br]
## @schema entry_ids: PackedStringArray selected entry ids.
## [br]
## @schema return: Array[Dictionary] where each item contains path and type_hint.
func make_asset_group_entries(entry_ids: PackedStringArray = PackedStringArray()) -> Array:
	_ensure_index()
	var include_all: bool = entry_ids.is_empty()
	var result: Array[Dictionary] = []
	for entry_id: String in get_all_ids():
		if not include_all and not entry_ids.has(entry_id):
			continue
		var typed_id: StringName = StringName(entry_id)
		result.append({
			"path": get_entry_path(typed_id),
			"type_hint": get_entry_type_hint(typed_id),
		})
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 注册表诊断信息。
## [br]
## @schema return: Dictionary with entry_count, indexed_field_count, and ids.
func get_debug_snapshot() -> Dictionary:
	_ensure_index()
	return {
		"entry_count": _entry_lookup.size(),
		"indexed_field_count": _index.get_index_count(),
		"ids": get_all_ids(),
	}


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @return 注册表字典。
## [br]
## @schema return: Dictionary with entries array.
func to_dict() -> Dictionary:
	var entry_data: Array = []
	for entry: GFResourceRegistryEntry in entries:
		if _is_valid_registry_entry(entry):
			entry_data.append(entry.to_dict())
	return {
		"entries": entry_data,
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 注册表字典。
## [br]
## @schema data: Dictionary with entries array.
func apply_dict(data: Dictionary) -> void:
	entries.clear()
	var raw_entries: Array = GFVariantData.get_option_array(data, "entries")
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			var entry: GFResourceRegistryEntry = _get_registry_entry_value(
				GFResourceRegistryEntry.from_dict(GFVariantData.as_dictionary(raw_entry))
			)
			if _is_valid_registry_entry(entry):
				entries.append(entry)
	mark_index_dirty()


## 从字典创建注册表。
## [br]
## @api public
## [br]
## @param data: 注册表字典。
## [br]
## @schema data: Dictionary with entries array.
## [br]
## @return 新注册表。
static func from_dict(data: Dictionary) -> Resource:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.apply_dict(data)
	return registry


# --- 私有/辅助方法 ---

func _ensure_index() -> void:
	if _index_dirty:
		rebuild_index()


func _resolve_type_hint(entry_id: StringName, type_hint_override: String) -> String:
	if not type_hint_override.is_empty():
		return type_hint_override
	return get_entry_type_hint(entry_id)


func _is_valid_registry_entry(entry: GFResourceRegistryEntry) -> bool:
	return entry != null and entry.is_valid_entry()


func _duplicate_registry_entry(entry: GFResourceRegistryEntry) -> GFResourceRegistryEntry:
	if entry == null:
		return null
	return _get_registry_entry_value(entry.duplicate_entry())


func _get_entry_id(entry: GFResourceRegistryEntry) -> StringName:
	if entry == null:
		return &""
	return entry.id


func _get_entry_path(entry: GFResourceRegistryEntry) -> String:
	if entry == null:
		return ""
	return entry.path


func _get_entry_type_hint(entry: GFResourceRegistryEntry) -> String:
	if entry == null:
		return ""
	return entry.type_hint


func _get_entry_fields(entry: GFResourceRegistryEntry) -> Dictionary:
	if entry == null:
		return {}
	return entry.fields.duplicate(true)


func _get_registry_entry_value(value: Variant) -> GFResourceRegistryEntry:
	if value is GFResourceRegistryEntry:
		var entry: GFResourceRegistryEntry = value
		return entry
	return null


func _get_entry_group_keys(
	entry: GFResourceRegistryEntry,
	group_source: StringName,
	field_id: StringName,
	include_empty: bool,
	empty_key: String
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	match group_source:
		GROUP_SOURCE_ID:
			_append_entry_group_key(result, lookup, _get_entry_id(entry), include_empty, empty_key)
		GROUP_SOURCE_PATH:
			_append_entry_group_key(result, lookup, _get_entry_path(entry), include_empty, empty_key)
		GROUP_SOURCE_PATH_BASENAME:
			_append_entry_group_key(result, lookup, _get_entry_path(entry).get_file().get_basename(), include_empty, empty_key)
		GROUP_SOURCE_TYPE_HINT:
			_append_entry_group_key(result, lookup, _get_entry_type_hint(entry), include_empty, empty_key)
		GROUP_SOURCE_FIELD:
			if field_id != &"":
				_append_entry_group_key(
					result,
					lookup,
					GFVariantData.get_option_value(_get_entry_fields(entry), field_id),
					include_empty,
					empty_key
				)
	result.sort()
	return result


func _append_entry_group_key(
	result: PackedStringArray,
	lookup: Dictionary,
	value: Variant,
	include_empty: bool,
	empty_key: String
) -> void:
	if value == null:
		_append_scalar_entry_group_key(result, lookup, "", include_empty, empty_key)
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_entry_group_key(result, lookup, item, include_empty, empty_key)
	elif value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item: String in packed_values:
			_append_scalar_entry_group_key(result, lookup, item, include_empty, empty_key)
	else:
		_append_scalar_entry_group_key(result, lookup, GFVariantData.to_text(value), include_empty, empty_key)


func _append_scalar_entry_group_key(
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
	var _append_group_key: bool = result.append(group_key)


func _sort_entry_id_groups(groups: Dictionary) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in groups.keys():
		var _append_key: bool = keys.append(GFVariantData.to_text(key_value))
	keys.sort()

	var result: Dictionary = {}
	for key: String in keys:
		var ids: PackedStringArray = GFVariantData.get_option_packed_string_array(groups, key, PackedStringArray())
		ids.sort()
		result[key] = ids
	return result


func _get_summary_field_ids(options: Dictionary, key: String, default_value: PackedStringArray) -> PackedStringArray:
	return GFVariantData.get_option_packed_string_array(options, key, default_value)


func _get_first_entry_field_text(fields: Dictionary, field_ids: PackedStringArray) -> String:
	for field_id: String in field_ids:
		var text: String = GFVariantData.to_text(_get_entry_field_value(fields, StringName(field_id))).strip_edges()
		if not text.is_empty():
			return text
	return ""


func _get_entry_summary_tags(fields: Dictionary, field_ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	for field_id: String in field_ids:
		_append_entry_summary_tags(result, lookup, _get_entry_field_value(fields, StringName(field_id)))
	result.sort()
	return result


func _append_entry_summary_tags(result: PackedStringArray, lookup: Dictionary, value: Variant) -> void:
	if value == null:
		return
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item_text: String in packed_values:
			_append_entry_summary_tag(result, lookup, item_text)
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_entry_summary_tags(result, lookup, item)
	else:
		_append_entry_summary_tag(result, lookup, GFVariantData.to_text(value))


func _append_entry_summary_tag(result: PackedStringArray, lookup: Dictionary, value: String) -> void:
	var tag: String = value.strip_edges()
	if tag.is_empty() or lookup.has(tag):
		return
	lookup[tag] = true
	var _append_tag: bool = result.append(tag)


func _get_entry_field_value(fields: Dictionary, field_id: StringName) -> Variant:
	if fields.has(field_id):
		return fields[field_id]
	var text_key: String = String(field_id)
	if fields.has(text_key):
		return fields[text_key]
	return null


func _get_search_page_reports(query_text: String, options: Dictionary) -> Array[Dictionary]:
	if (
		query_text.strip_edges().is_empty()
		and GFVariantData.get_option_bool(options, "empty_query_returns_all", true)
	):
		var entry_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
			options,
			"entry_ids",
			PackedStringArray()
		)
		return _make_listing_search_reports(make_search_candidates(entry_ids), options)
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


func _get_search_report_entry_id(report: Dictionary) -> String:
	var candidate: Dictionary = GFVariantData.get_option_dictionary(report, "candidate", {})
	var entry_id: String = GFVariantData.get_option_string(candidate, "entry_id")
	if entry_id.is_empty():
		entry_id = GFVariantData.get_option_string(candidate, "id")
	return entry_id


func _make_search_candidate(entry: GFResourceRegistryEntry) -> Dictionary:
	var entry_id: String = String(_get_entry_id(entry))
	var fields: Dictionary = _get_entry_fields(entry)
	return {
		"id": entry_id,
		"entry_id": entry_id,
		"title": entry_id,
		"name": entry_id,
		"path": _get_entry_path(entry),
		"type_hint": _get_entry_type_hint(entry),
		"keywords": _make_entry_search_keywords(entry, fields),
		"fields": fields,
	}


func _make_entry_search_keywords(entry: GFResourceRegistryEntry, fields: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	_append_search_keyword(result, lookup, String(_get_entry_id(entry)))
	var path: String = _get_entry_path(entry)
	_append_search_keyword(result, lookup, path)
	_append_search_keyword(result, lookup, path.get_file())
	_append_search_keyword(result, lookup, path.get_file().get_basename())
	_append_search_keyword(result, lookup, _get_entry_type_hint(entry))
	_append_search_value_keywords(result, lookup, fields)
	return result


func _append_search_value_keywords(
	keywords: PackedStringArray,
	lookup: Dictionary,
	value: Variant
) -> void:
	if value == null:
		return
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary.keys():
			_append_search_keyword(keywords, lookup, GFVariantData.to_text(key))
			_append_search_value_keywords(keywords, lookup, dictionary[key])
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_search_value_keywords(keywords, lookup, item)
	elif value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		for item_text: String in packed_strings:
			_append_search_keyword(keywords, lookup, item_text)
	elif (
		value is String
		or value is StringName
		or value is NodePath
		or value is bool
		or value is int
		or value is float
	):
		_append_search_keyword(keywords, lookup, GFVariantData.to_text(value))


func _append_search_keyword(
	keywords: PackedStringArray,
	lookup: Dictionary,
	keyword: String
) -> void:
	var normalized_keyword: String = keyword.strip_edges()
	if normalized_keyword.is_empty() or lookup.has(normalized_keyword):
		return
	lookup[normalized_keyword] = true
	var _append_result_423: bool = keywords.append(normalized_keyword)
