## GFContentPackageQuery: 内容包目录的确定性通用查询条件。
##
## 查询只描述 package、content type、依赖、资源键、安全分类和 metadata 约束，
## 不解释项目业务语义。所有非空条件采用 AND 语义，列表条件要求 manifest 包含全部值。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFContentPackageQuery
extends Resource


# --- 导出变量 ---

## 查询稳定标识，仅用于诊断和追踪。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var query_id: StringName = &""

## 允许返回的 package ID；为空表示不限制。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var package_ids: PackedStringArray = PackedStringArray()

## 在 package ID、显示名、版本和 content type 中匹配的大小写无关文本。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var search_text: String = ""

## manifest 必须包含的全部 content type。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var required_content_types: PackedStringArray = PackedStringArray()

## manifest 必须声明的全部直接依赖 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var required_dependencies: PackedStringArray = PackedStringArray()

## manifest 必须声明的全部资源键。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var required_resource_keys: PackedStringArray = PackedStringArray()

## 允许的安全分类；为空表示不限制。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var allowed_safety_kinds: PackedStringArray = PackedStringArray()

## manifest metadata 必须精确匹配的键值。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema required_metadata: Dictionary with exact manifest metadata key/value filters.
@export var required_metadata: Dictionary = {}

## 是否把直接命中包的传递依赖加入结果。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var include_dependencies: bool = false

## 直接命中包的最大数量；小于等于 0 表示不限制。依赖闭包不计入该限制。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var max_results: int = 0

## 调用方自定义查询元数据；GF 只负责复制和序列化。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @schema metadata: Dictionary with caller-defined query metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查 manifest 是否满足全部非空查询条件。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param manifest: 要检查的内容包 manifest。
## [br]
## @return 满足查询条件返回 true。
func matches(manifest: GFContentPackageManifest) -> bool:
	if manifest == null:
		return false
	var normalized_package_ids: PackedStringArray = _normalize_string_set(package_ids)
	if not normalized_package_ids.is_empty() and not normalized_package_ids.has(String(manifest.package_id)):
		return false
	if not _matches_search_text(manifest):
		return false
	if not _contains_all(manifest.content_types, _normalize_string_set(required_content_types)):
		return false
	if not _contains_all(manifest.dependencies, _normalize_string_set(required_dependencies)):
		return false
	if not _contains_all(manifest.get_resource_keys(), _normalize_string_set(required_resource_keys)):
		return false
	var normalized_safety_kinds: PackedStringArray = _normalize_string_set(allowed_safety_kinds)
	if not normalized_safety_kinds.is_empty() and not normalized_safety_kinds.has(String(manifest.safety_kind)):
		return false
	for metadata_key: Variant in required_metadata.keys():
		if not manifest.metadata.has(metadata_key) or manifest.metadata[metadata_key] != required_metadata[metadata_key]:
			return false
	return true


## 从字典应用查询字段并执行集合归一化。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 查询字典。
## [br]
## @schema data: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.
func apply_dict(data: Dictionary) -> void:
	query_id = GFVariantData.get_option_string_name(data, "query_id")
	package_ids = _normalize_string_set(GFVariantData.get_option_packed_string_array(data, "package_ids"))
	search_text = GFVariantData.get_option_string(data, "search_text").strip_edges()
	required_content_types = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(data, "required_content_types")
	)
	required_dependencies = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(data, "required_dependencies")
	)
	required_resource_keys = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(data, "required_resource_keys")
	)
	allowed_safety_kinds = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(data, "allowed_safety_kinds")
	)
	required_metadata = _duplicate_dictionary(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(data, "required_metadata", {}))
	)
	include_dependencies = GFVariantData.get_option_bool(data, "include_dependencies", false)
	max_results = maxi(0, GFVariantData.get_option_int(data, "max_results", 0))
	metadata = _duplicate_dictionary(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(data, "metadata", {}))
	)


## 转换为归一化字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 查询字典副本。
## [br]
## @schema return: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.
func to_dict() -> Dictionary:
	return _make_dictionary(true)


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return: 查询报告字典。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on the normalized query state.
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(_make_dictionary(false), options)


## 创建查询深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新查询。
func duplicate_query() -> GFContentPackageQuery:
	return GFContentPackageQuery.from_dict(to_dict())


## 从字典创建查询。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 查询字典。
## [br]
## @schema data: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.
## [br]
## @return 新查询。
static func from_dict(data: Dictionary) -> GFContentPackageQuery:
	var result: GFContentPackageQuery = GFContentPackageQuery.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

func _make_dictionary(copy_nested_values: bool) -> Dictionary:
	return {
		"query_id": query_id,
		"package_ids": _normalize_string_set(package_ids),
		"search_text": search_text.strip_edges(),
		"required_content_types": _normalize_string_set(required_content_types),
		"required_dependencies": _normalize_string_set(required_dependencies),
		"required_resource_keys": _normalize_string_set(required_resource_keys),
		"allowed_safety_kinds": _normalize_string_set(allowed_safety_kinds),
		"required_metadata": (
			_duplicate_dictionary(required_metadata) if copy_nested_values else required_metadata
		),
		"include_dependencies": include_dependencies,
		"max_results": maxi(0, max_results),
		"metadata": _duplicate_dictionary(metadata) if copy_nested_values else metadata,
	}


func _matches_search_text(manifest: GFContentPackageManifest) -> bool:
	var normalized_search: String = search_text.strip_edges().to_lower()
	if normalized_search.is_empty():
		return true
	var candidates: PackedStringArray = PackedStringArray([
		String(manifest.package_id),
		manifest.display_name,
		manifest.version,
	])
	for content_type: String in manifest.content_types:
		var _content_type_appended: bool = candidates.append(content_type)
	for candidate: String in candidates:
		if candidate.to_lower().contains(normalized_search):
			return true
	return false


static func _contains_all(source: PackedStringArray, required: PackedStringArray) -> bool:
	for item: String in required:
		if not source.has(item):
			return false
	return true


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized_item: String = item.strip_edges()
		if normalized_item.is_empty() or result.has(normalized_item):
			continue
		var _item_appended: bool = result.append(normalized_item)
	result.sort()
	return result


static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value, true, false))
