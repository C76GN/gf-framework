## GFResourceRegistryAssetSourceProvider: 从 GFResourceRegistry 生成资产目录的 provider。
##
## 该 provider 把已有资源注册表条目适配为 `GFAssetCatalogEntry`，用于项目从
## “稳定资源 ID -> 资源路径” 平滑过渡到更高层的资产目录。字段含义仍由项目定义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFResourceRegistryAssetSourceProvider
extends GFAssetCatalogSourceProvider


# --- 公共变量 ---

## 作为来源的资源注册表。
## [br]
## @api public
## [br]
## @since 8.0.0
var registry: GFResourceRegistry = null

## 转换字段选项，传给 GFAssetCatalogEntry.from_resource_registry_entry()。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema entry_options: Dictionary with optional title_fields, description_fields, tag_fields, category_fields, and preview_path_fields.
var entry_options: Dictionary = {}


# --- 公共方法 ---

## 配置资源注册表来源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_registry: 资源注册表。
## [br]
## @param p_source_id: 来源稳定 ID。
## [br]
## @param options: 可选项，支持 priority 和 entry_options。
## [br]
## @schema options: Dictionary with optional priority: int and entry_options: Dictionary.
## [br]
## @return 当前 provider。
func configure_registry(
	p_registry: GFResourceRegistry,
	p_source_id: StringName = &"resource_registry",
	options: Dictionary = {}
) -> GFResourceRegistryAssetSourceProvider:
	registry = p_registry
	var _configured: GFAssetCatalogSourceProvider = configure(p_source_id, options)
	entry_options = GFVariantData.get_option_dictionary(options, "entry_options").duplicate(true)
	return self


## 构建资产目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 可选项，支持 asset_ids、entry_ids 和 entry_options。
## [br]
## @schema options: Dictionary with optional asset_ids, entry_ids, and entry_options.
## [br]
## @return 来源导出的资产目录。
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	if registry == null:
		return catalog

	var selected_entry_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"entry_ids",
		PackedStringArray()
	)
	var selected_asset_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"asset_ids",
		PackedStringArray()
	)
	var resolved_entry_options: Dictionary = _resolve_entry_options(options)
	resolved_entry_options["source_id"] = get_source_id()

	for entry_id_text: String in registry.get_all_ids():
		if not selected_entry_ids.is_empty() and not selected_entry_ids.has(entry_id_text):
			continue
		if not selected_asset_ids.is_empty() and not selected_asset_ids.has(entry_id_text):
			continue
		var registry_entry_value: Resource = registry.get_entry(StringName(entry_id_text))
		var registry_entry: GFResourceRegistryEntry = _get_registry_entry(registry_entry_value)
		var asset_entry: GFAssetCatalogEntry = GFAssetCatalogEntry.from_resource_registry_entry(
			registry_entry,
			resolved_entry_options
		)
		if asset_entry != null:
			var _stored: bool = catalog.set_entry(asset_entry)
	return catalog


## 获取来源诊断快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 来源诊断字典。
## [br]
## @schema return: Dictionary with source_id, priority, provider_class, registry_entry_count, and has_registry.
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.get_debug_snapshot()
	snapshot["has_registry"] = registry != null
	snapshot["registry_entry_count"] = registry.get_all_ids().size() if registry != null else 0
	return snapshot


# --- 私有/辅助方法 ---

func _resolve_entry_options(options: Dictionary) -> Dictionary:
	var resolved: Dictionary = entry_options.duplicate(true)
	var override_options: Dictionary = GFVariantData.get_option_dictionary(options, "entry_options")
	var _merged: Dictionary = GFVariantData.merge_dictionary(resolved, override_options, true, true)
	return resolved


func _get_registry_entry(value: Variant) -> GFResourceRegistryEntry:
	if value is GFResourceRegistryEntry:
		var entry: GFResourceRegistryEntry = value
		return entry
	return null
