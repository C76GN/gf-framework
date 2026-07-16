## GFAssetCatalogEntry: 通用资产目录条目。
##
## 用稳定 asset_id 描述一个可被项目工具检索、预览和审计的资产。
## 条目可以引用一个主资源、一个预览资源和多条资源注册表条目，但不解释资产业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFAssetCatalogEntry
extends Resource


# --- 导出变量 ---

## 资产稳定 ID。推荐由项目或 source provider 明确生成，不应直接等同资源路径。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var asset_id: StringName = &""

## 面向工具 UI 的显示标题；为空时可回退到 asset_id 或资源 basename。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var title: String = ""

## 面向工具 UI 的简短说明或备注。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_multiline var description: String = ""

## 通用标签。标签只用于检索、筛选和分组，不携带业务含义。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var tags: PackedStringArray = PackedStringArray()

## 通用分类。项目可自行决定分类体系；GF 只按文本索引。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var category: StringName = &""

## 主资源路径。用于预览、打开、加载或关联 GFResourceRegistry 条目。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var primary_path: String = ""

## 主资源类型提示。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var type_hint: String = ""

## 可选预览资源路径。为空时工具可尝试主资源或 preview provider。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var preview_path: String = ""

## 关联的 GFResourceRegistry 条目 ID 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var resource_entry_ids: PackedStringArray = PackedStringArray()

## 资产来源 ID，例如 provider、catalog 文件或项目工具来源。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var source_id: StringName = &""

## 项目自定义元数据。GF 复制和序列化该字典，但不解释字段含义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary with project-defined asset metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置条目并返回自身。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_asset_id: 资产稳定 ID。
## [br]
## @param p_primary_path: 主资源路径。
## [br]
## @param options: 可选项，支持 title、description、tags、category、type_hint、preview_path、resource_entry_ids、source_id 和 metadata。
## [br]
## @schema options: Dictionary with optional title, description, tags, category, type_hint, preview_path, resource_entry_ids, source_id, and metadata.
## [br]
## @return 当前条目。
func configure(
	p_asset_id: StringName,
	p_primary_path: String = "",
	options: Dictionary = {}
) -> GFAssetCatalogEntry:
	asset_id = p_asset_id
	primary_path = _make_resource_identity(p_primary_path, p_asset_id, GFVariantData.get_option_string(options, "type_hint")).canonical_path
	type_hint = GFVariantData.get_option_string(options, "type_hint")
	title = GFVariantData.get_option_string(options, "title")
	description = GFVariantData.get_option_string(options, "description")
	tags = _normalize_tags(GFVariantData.get_option_packed_string_array(options, "tags", PackedStringArray()))
	category = GFVariantData.get_option_string_name(options, "category")
	preview_path = _normalize_optional_path(GFVariantData.get_option_string(options, "preview_path"))
	resource_entry_ids = _normalize_string_array(
		GFVariantData.get_option_packed_string_array(options, "resource_entry_ids", PackedStringArray())
	)
	source_id = GFVariantData.get_option_string_name(options, "source_id")
	metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	return self


## 检查条目是否有稳定资产 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 条目可被 catalog 使用时返回 true。
func is_valid_entry() -> bool:
	return asset_id != &""


## 创建条目副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 条目副本。
func duplicate_entry() -> GFAssetCatalogEntry:
	var entry: GFAssetCatalogEntry = _make_entry_instance()
	entry.asset_id = asset_id
	entry.title = title
	entry.description = description
	entry.tags = tags.duplicate()
	entry.category = category
	entry.primary_path = primary_path
	entry.type_hint = type_hint
	entry.preview_path = preview_path
	entry.resource_entry_ids = resource_entry_ids.duplicate()
	entry.source_id = source_id
	entry.metadata = metadata.duplicate(true)
	return entry


## 获取主资源身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 主资源身份；主路径为空时仍返回以 asset_id 为后备 cache key 的身份。
func get_primary_identity() -> GFResourceIdentity:
	return _make_resource_identity(primary_path, asset_id, type_hint)


## 获取预览资源身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 预览资源身份；预览路径为空时返回 null。
func get_preview_identity() -> GFResourceIdentity:
	if preview_path.is_empty():
		return null
	return _make_resource_identity(preview_path, asset_id, "")


## 获取推荐缓存键。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 主资源身份 cache_key 或 asset_id 后备键。
func get_cache_key() -> String:
	return get_primary_identity().cache_key


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 条目字典。
## [br]
## @schema return: Dictionary with asset_id, title, description, tags, category, primary_path, type_hint, preview_path, resource_entry_ids, source_id, metadata, cache_key, primary_identity, and preview_identity.
func to_dict() -> Dictionary:
	var primary_identity: GFResourceIdentity = get_primary_identity()
	var preview_identity: GFResourceIdentity = get_preview_identity()
	return {
		"asset_id": String(asset_id),
		"title": title,
		"description": description,
		"tags": tags.duplicate(),
		"category": String(category),
		"primary_path": primary_path,
		"type_hint": type_hint,
		"preview_path": preview_path,
		"resource_entry_ids": resource_entry_ids.duplicate(),
		"source_id": String(source_id),
		"metadata": metadata.duplicate(true),
		"cache_key": primary_identity.cache_key,
		"primary_identity": primary_identity.to_dictionary(),
		"preview_identity": preview_identity.to_dictionary() if preview_identity != null else {},
	}


## 从字典创建条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 条目字典。
## [br]
## @schema data: Dictionary with optional asset_id, id, title, description, tags, category, primary_path, resource_path, type_hint, preview_path, resource_entry_ids, source_id, and metadata.
## [br]
## @return 新条目。
static func from_dict(data: Dictionary) -> GFAssetCatalogEntry:
	var entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	var options: Dictionary = {
		"title": GFVariantData.get_option_string(data, "title"),
		"description": GFVariantData.get_option_string(data, "description"),
		"tags": GFVariantData.get_option_packed_string_array(data, "tags", PackedStringArray()),
		"category": GFVariantData.get_option_string_name(data, "category"),
		"type_hint": GFVariantData.get_option_string(data, "type_hint"),
		"preview_path": GFVariantData.get_option_string(data, "preview_path"),
		"resource_entry_ids": GFVariantData.get_option_packed_string_array(
			data,
			"resource_entry_ids",
			PackedStringArray()
		),
		"source_id": GFVariantData.get_option_string_name(data, "source_id"),
		"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
	}
	var asset_id_text: StringName = GFVariantData.get_option_string_name(
		data,
		"asset_id",
		GFVariantData.get_option_string_name(data, "id")
	)
	var primary_path_text: String = GFVariantData.get_option_string(
		data,
		"primary_path",
		GFVariantData.get_option_string(data, "resource_path")
	)
	return entry.configure(asset_id_text, primary_path_text, options)


## 从资源注册表条目创建资产条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param registry_entry: 资源注册表条目。
## [br]
## @param options: 可选项，支持 source_id、metadata_fields 和 field override。
## [br]
## @schema options: Dictionary with optional source_id and fields used by make_entry_summary().
## [br]
## @return 新资产条目；资源条目无效时返回 null。
static func from_resource_registry_entry(
	registry_entry: GFResourceRegistryEntry,
	options: Dictionary = {}
) -> GFAssetCatalogEntry:
	if registry_entry == null or not registry_entry.is_valid_entry():
		return null
	var fields: Dictionary = registry_entry.fields.duplicate(true)
	var asset_options: Dictionary = {
		"title": _get_first_field_text(fields, _get_field_list(options, "title_fields", ["display_name", "name", "title"])),
		"description": _get_first_field_text(fields, _get_field_list(options, "description_fields", ["description", "summary", "notes"])),
		"tags": _get_field_tags(fields, _get_field_list(options, "tag_fields", ["tags", "keywords"])),
		"category": _get_first_field_text(fields, _get_field_list(options, "category_fields", ["category", "group"])),
		"type_hint": registry_entry.type_hint,
		"preview_path": _get_first_field_text(fields, _get_field_list(options, "preview_path_fields", ["preview_path", "thumbnail_path", "icon_path"])),
		"resource_entry_ids": PackedStringArray([String(registry_entry.id)]),
		"source_id": GFVariantData.get_option_string_name(options, "source_id"),
		"metadata": fields,
	}
	var entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	return entry.configure(registry_entry.id, registry_entry.path, asset_options)


# --- 私有/辅助方法 ---

static func _make_resource_identity(
	path: String,
	resource_key: StringName,
	hint: String
) -> GFResourceIdentity:
	return GFResourceIdentity.from_path(path, resource_key, hint, { "check_exists": false })


static func _normalize_optional_path(path: String) -> String:
	var identity: GFResourceIdentity = _make_resource_identity(path, &"", "")
	return identity.canonical_path if not identity.canonical_path.is_empty() else path.strip_edges()


static func _normalize_tags(values: PackedStringArray) -> PackedStringArray:
	return _normalize_string_array(values)


static func _normalize_string_array(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var text: String = value.strip_edges()
		if not text.is_empty() and not result.has(text):
			var _appended: bool = result.append(text)
	result.sort()
	return result


static func _get_field_list(options: Dictionary, key: String, default_values: Array[String]) -> PackedStringArray:
	var fallback: PackedStringArray = PackedStringArray()
	for value: String in default_values:
		var _fallback_appended: bool = fallback.append(value)
	return GFVariantData.get_option_packed_string_array(options, key, fallback)


static func _get_first_field_text(fields: Dictionary, field_ids: PackedStringArray) -> String:
	for field_id_text: String in field_ids:
		var value: Variant = _get_field_value(fields, StringName(field_id_text))
		var text: String = GFVariantData.to_text(value).strip_edges()
		if not text.is_empty():
			return text
	return ""


static func _get_field_tags(fields: Dictionary, field_ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var lookup: Dictionary = {}
	for field_id_text: String in field_ids:
		_append_tags(result, lookup, _get_field_value(fields, StringName(field_id_text)))
	result.sort()
	return result


static func _append_tags(result: PackedStringArray, lookup: Dictionary, value: Variant) -> void:
	if value == null:
		return
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item_text: String in packed_values:
			_append_tag(result, lookup, item_text)
	elif value is Array:
		var values: Array = value
		for item: Variant in values:
			_append_tags(result, lookup, item)
	else:
		_append_tag(result, lookup, GFVariantData.to_text(value))


static func _append_tag(result: PackedStringArray, lookup: Dictionary, value: String) -> void:
	var tag: String = value.strip_edges()
	if tag.is_empty() or lookup.has(tag):
		return
	lookup[tag] = true
	var _appended: bool = result.append(tag)


static func _get_field_value(fields: Dictionary, field_id: StringName) -> Variant:
	if fields.has(field_id):
		return fields[field_id]
	var text_key: String = String(field_id)
	if fields.has(text_key):
		return fields[text_key]
	return null


func _make_entry_instance() -> GFAssetCatalogEntry:
	var script_value: Variant = get_script()
	if script_value is Script:
		var script: Script = script_value
		var entry_value: Variant = script.call("new")
		if entry_value is GFAssetCatalogEntry:
			var entry: GFAssetCatalogEntry = entry_value
			return entry
	return GFAssetCatalogEntry.new()
