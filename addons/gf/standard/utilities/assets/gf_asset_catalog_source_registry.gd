## GFAssetCatalogSourceRegistry: 资产目录来源注册表。
##
## 通过显式 provider 汇聚多个资产来源，生成可重建的 `GFAssetCatalog`。
## 它只处理来源注册、优先级、合并和诊断，不规定项目目录结构或素材分类体系。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFAssetCatalogSourceRegistry
extends RefCounted


# --- 私有变量 ---

var _providers: Array[GFAssetCatalogSourceProvider] = []


# --- 公共方法 ---

## 注册资产来源 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 资产来源 provider。
## [br]
## @param options: 可选项，支持 source_id 和 priority 覆盖。
## [br]
## @schema options: Dictionary with optional source_id: StringName/String and priority: int.
## [br]
## @return 注册成功返回 true。
func register_source(provider: GFAssetCatalogSourceProvider, options: Dictionary = {}) -> bool:
	if provider == null:
		return false

	var configured_source_id: StringName = GFVariantData.get_option_string_name(
		options,
		"source_id",
		provider.get_source_id()
	)
	if configured_source_id != &"":
		_set_source_id_if_needed(provider, configured_source_id)
	if options.has("priority"):
		provider.priority = GFVariantData.get_option_int(options, "priority", provider.get_priority())

	var _unregistered_existing: bool = unregister_source(provider)
	_providers.append(provider)
	_sort_providers()
	return true


## 注销资产来源 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 已注册的 provider。
## [br]
## @return 找到并移除时返回 true。
func unregister_source(provider: GFAssetCatalogSourceProvider) -> bool:
	for index: int in range(_providers.size() - 1, -1, -1):
		if _providers[index] == provider:
			_providers.remove_at(index)
			return true
	return false


## 清空全部来源。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_sources() -> void:
	_providers.clear()


## 检查来源 ID 是否已注册。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_id: 来源稳定 ID。
## [br]
## @return 存在返回 true。
func has_source_id(source_id: StringName) -> bool:
	for provider: GFAssetCatalogSourceProvider in _providers:
		if provider.get_source_id() == source_id:
			return true
	return false


## 获取来源摘要记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 来源摘要数组。
## [br]
## @schema return: Array[Dictionary] where each item contains source_id, priority, provider_class, and index.
func get_source_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(_providers.size()):
		var provider: GFAssetCatalogSourceProvider = _providers[index]
		result.append({
			"source_id": String(provider.get_source_id()),
			"priority": provider.get_priority(),
			"provider_class": provider.get_class(),
			"index": index,
		})
	return result


## 构建合并后的资产目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 可选项，支持 provider_options、overwrite 和 source_ids。
## [br]
## @schema options: Dictionary with optional provider_options: Dictionary, overwrite: bool, and source_ids: PackedStringArray.
## [br]
## @return 合并后的资产目录。
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	var provider_options: Dictionary = GFVariantData.get_option_dictionary(options, "provider_options")
	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", false)
	var selected_source_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"source_ids",
		PackedStringArray()
	)

	for provider: GFAssetCatalogSourceProvider in _providers:
		if not _should_include_provider(provider, selected_source_ids):
			continue
		var source_catalog: GFAssetCatalog = provider.build_catalog(provider_options)
		var _merge_report: Dictionary = catalog.merge_catalog(source_catalog, { "overwrite": overwrite })
	return catalog


## 构建 JSON-safe 资产目录诊断报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 可选项，传给 build_catalog()。
## [br]
## @schema options: Dictionary build options.
## [br]
## @return 资产目录报告。
## [br]
## @schema return: Dictionary with ok, source_count, entry_count, sources, catalog_data, and issues.
func build_catalog_report(options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	var provider_options: Dictionary = GFVariantData.get_option_dictionary(options, "provider_options")
	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", false)
	var selected_source_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"source_ids",
		PackedStringArray()
	)

	for provider: GFAssetCatalogSourceProvider in _providers:
		if not _should_include_provider(provider, selected_source_ids):
			continue
		var source_catalog: GFAssetCatalog = provider.build_catalog(provider_options)
		if source_catalog == null:
			issues.append({
				"severity": "error",
				"kind": "null_source_catalog",
				"source_id": String(provider.get_source_id()),
			})
			continue
		var merge_report: Dictionary = catalog.merge_catalog(source_catalog, { "overwrite": overwrite })
		var duplicate_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
			merge_report,
			"duplicate_ids",
			PackedStringArray()
		)
		if not overwrite and not duplicate_ids.is_empty():
			issues.append({
				"severity": "warning",
				"kind": "duplicate_asset_ids",
				"source_id": String(provider.get_source_id()),
				"asset_ids": duplicate_ids,
			})

	return {
		"ok": _has_no_errors(issues),
		"source_count": get_source_records().size(),
		"entry_count": catalog.get_all_ids().size(),
		"sources": get_source_records(),
		"catalog_data": catalog.to_dict(),
		"issues": issues,
	}


# --- 私有/辅助方法 ---

func _set_source_id_if_needed(provider: GFAssetCatalogSourceProvider, source_id: StringName) -> void:
	if provider.get_source_id() == source_id:
		return
	provider.source_id = source_id


func _sort_providers() -> void:
	_providers.sort_custom(_compare_providers)


static func _compare_providers(left: GFAssetCatalogSourceProvider, right: GFAssetCatalogSourceProvider) -> bool:
	if left.get_priority() == right.get_priority():
		return String(left.get_source_id()) < String(right.get_source_id())
	return left.get_priority() > right.get_priority()


func _should_include_provider(
	provider: GFAssetCatalogSourceProvider,
	selected_source_ids: PackedStringArray
) -> bool:
	if selected_source_ids.is_empty():
		return true
	return selected_source_ids.has(String(provider.get_source_id()))


func _has_no_errors(issues: Array[Dictionary]) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "severity") == "error":
			return false
	return true
