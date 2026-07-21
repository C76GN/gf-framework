## GFContentPackageAssetCatalogProvider: 内容包目录到通用资产目录的适配器。
##
## Provider 持有内容包目录快照，通过可选 GFContentPackageQuery 选择 manifest，
## 再把资源映射转换为 GFAssetCatalogEntry。它不挂载目录、不下载内容，也不解释业务分类。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFContentPackageAssetCatalogProvider
extends GFAssetCatalogSourceProvider


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 私有变量 ---

var _content_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
var _query: GFContentPackageQuery = GFContentPackageQuery.new()


# --- 公共方法 ---

## 配置内容包目录快照和可选查询。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param catalog: 内容包目录；Provider 保存其深拷贝。
## [br]
## @param p_source_id: 资产来源 ID。
## [br]
## @param query: 可选内容包查询；为空时选择全部有效包。
## [br]
## @param options: Provider 配置选项，支持 priority。
## [br]
## @schema options: Dictionary with optional priority: int.
## [br]
## @return 当前 Provider。
func configure_catalog(
	catalog: GFContentPackageCatalog,
	p_source_id: StringName = &"content_packages",
	query: GFContentPackageQuery = null,
	options: Dictionary = {}
) -> GFContentPackageAssetCatalogProvider:
	_content_catalog = catalog.duplicate_catalog() if catalog != null else GFContentPackageCatalog.new()
	_query = query.duplicate_query() if query != null else GFContentPackageQuery.new()
	var _base_configured: GFAssetCatalogSourceProvider = configure(p_source_id, options)
	return self


## 构建资产目录快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 可选字段映射，支持 title_fields、description_fields、tag_fields、category_fields 和 preview_path_fields。
## [br]
## @schema options: Dictionary with optional PackedStringArray field-name lists for title_fields, description_fields, tag_fields, category_fields, and preview_path_fields.
## [br]
## @return 转换后的资产目录；内容包目录无效时返回 null。
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
	var query_result: GFContentPackageQueryResult = _content_catalog.query_packages(_query)
	if not query_result.is_successful():
		return null
	var result: GFAssetCatalog = GFAssetCatalog.new()
	for manifest: GFContentPackageManifest in query_result.get_manifests():
		for resource_record: Dictionary in manifest.get_normalized_resources():
			var entry: GFAssetCatalogEntry = _make_asset_entry(manifest, resource_record, options)
			if entry == null:
				continue
			var _entry_set: bool = result.set_entry(entry)
	return result


## 获取 Provider 诊断快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 来源、内容包目录和查询摘要。
## [br]
## @schema return: Dictionary with source_id, priority, provider_class, content_catalog, and query.
func get_debug_snapshot() -> Dictionary:
	var result: Dictionary = super.get_debug_snapshot()
	result["content_catalog"] = _content_catalog.get_debug_snapshot()
	result["query"] = _query.to_dict()
	return result


# --- 私有/辅助方法 ---

func _make_asset_entry(
	manifest: GFContentPackageManifest,
	resource_record: Dictionary,
	options: Dictionary
) -> GFAssetCatalogEntry:
	var resource_key: StringName = GFVariantData.get_option_string_name(resource_record, "key")
	if resource_key == &"":
		return null
	var resource_metadata: Dictionary = GFVariantData.get_option_dictionary(resource_record, "metadata").duplicate(true)
	var asset_metadata: Dictionary = resource_metadata.duplicate(true)
	asset_metadata["content_package_id"] = manifest.package_id
	asset_metadata["content_package_version"] = manifest.version
	asset_metadata["content_package_resource_key"] = resource_key
	asset_metadata["content_package_root_path"] = manifest.root_path
	asset_metadata["content_package_source_path"] = manifest.source_path
	asset_metadata["_gf_content_package_asset"] = true
	var preview_path: String = _get_first_text(
		resource_metadata,
		_get_field_names(options, "preview_path_fields", ["preview_path", "thumbnail_path", "icon_path"])
	)
	preview_path = _normalize_package_optional_path(preview_path, manifest.root_path)
	var entry_options: Dictionary = {
		"title": _get_first_text(resource_metadata, _get_field_names(options, "title_fields", ["title", "display_name", "name"])),
		"description": _get_first_text(resource_metadata, _get_field_names(options, "description_fields", ["description", "summary", "notes"])),
		"tags": _get_tags(resource_metadata, _get_field_names(options, "tag_fields", ["tags", "keywords"])),
		"category": _get_first_text(resource_metadata, _get_field_names(options, "category_fields", ["category", "group"])),
		"type_hint": GFVariantData.get_option_string(resource_record, "type_hint"),
		"preview_path": preview_path,
		"resource_entry_ids": PackedStringArray([String(resource_key)]),
		"source_id": get_source_id(),
		"metadata": asset_metadata,
	}
	var asset_id: StringName = StringName("%s/%s" % [String(manifest.package_id), String(resource_key)])
	return GFAssetCatalogEntry.new().configure(
		asset_id,
		GFVariantData.get_option_string(resource_record, "path"),
		entry_options
	)


static func _get_field_names(options: Dictionary, key: String, defaults: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = GFVariantData.get_option_packed_string_array(options, key)
	if not result.is_empty():
		return result
	for default_field: String in defaults:
		var _field_appended: bool = result.append(default_field)
	return result


static func _get_first_text(metadata: Dictionary, field_names: PackedStringArray) -> String:
	for field_name: String in field_names:
		if not metadata.has(field_name):
			continue
		var field_value: Variant = metadata[field_name]
		if field_value is String or field_value is StringName:
			var text_value: String = _text_from_variant(field_value).strip_edges()
			if not text_value.is_empty():
				return text_value
	return ""


static func _get_tags(metadata: Dictionary, field_names: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for field_name: String in field_names:
		if not metadata.has(field_name):
			continue
		var field_value: Variant = metadata[field_name]
		if field_value is PackedStringArray:
			var packed_tags: PackedStringArray = field_value
			_append_tags(result, packed_tags)
		elif field_value is Array:
			var tag_values: Array = field_value
			for tag_value: Variant in tag_values:
				if tag_value is String or tag_value is StringName:
					_append_tag(result, _text_from_variant(tag_value))
	result.sort()
	return result


static func _append_tags(result: PackedStringArray, tags: PackedStringArray) -> void:
	for tag: String in tags:
		_append_tag(result, tag)


static func _append_tag(result: PackedStringArray, tag: String) -> void:
	var normalized_tag: String = tag.strip_edges()
	if normalized_tag.is_empty() or result.has(normalized_tag):
		return
	var _tag_appended: bool = result.append(normalized_tag)


static func _text_from_variant(value: Variant) -> String:
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var text_name: StringName = value
		return String(text_name)
	return ""


static func _normalize_package_optional_path(path: String, root_path: String) -> String:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
	if normalized_path.is_empty() or root_path.is_empty():
		return ""
	if not normalized_path.begins_with("res://") and not normalized_path.begins_with("user://"):
		normalized_path = _GF_PATH_TOOLS.normalize_resource_path(root_path.path_join(normalized_path))
	if not _GF_PATH_TOOLS.is_path_under_root(normalized_path, root_path):
		return ""
	return normalized_path
