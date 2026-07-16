## 测试 GFAssetCatalog 的资产条目、查询和来源 provider 汇聚契约。
extends GutTest


const GF_ASSET_CATALOG_ENTRY_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_asset_catalog_entry.gd")
const GF_ASSET_CATALOG_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_asset_catalog.gd")
const GF_ASSET_CATALOG_SOURCE_REGISTRY_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_asset_catalog_source_registry.gd")
const GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_registry_asset_source_provider.gd")


func test_asset_catalog_entry_preserves_generic_fields_and_identity() -> void:
	var metadata: Dictionary = {
		"license": "CC0",
	}
	var entry: GF_ASSET_CATALOG_ENTRY_SCRIPT = GF_ASSET_CATALOG_ENTRY_SCRIPT.new().configure(&"ui.icon.save", "res://ui/save.png", {
		"title": "Save Icon",
		"description": "Toolbar icon",
		"tags": PackedStringArray(["ui", "icon", "ui"]),
		"category": "interface",
		"type_hint": "Texture2D",
		"preview_path": "res://ui/save_preview.png",
		"resource_entry_ids": PackedStringArray(["ui.save"]),
		"source_id": &"manual",
		"metadata": metadata,
	})
	metadata["license"] = "mutated"

	var data: Dictionary = entry.to_dict()
	var restored: GF_ASSET_CATALOG_ENTRY_SCRIPT = GF_ASSET_CATALOG_ENTRY_SCRIPT.from_dict(data)

	assert_true(entry.is_valid_entry(), "asset_id 有效时条目应可用于目录。")
	assert_eq(entry.asset_id, &"ui.icon.save")
	assert_eq(entry.title, "Save Icon")
	assert_eq(entry.tags, PackedStringArray(["icon", "ui"]), "标签应去重并稳定排序。")
	assert_eq(entry.category, &"interface")
	assert_eq(entry.type_hint, "Texture2D")
	assert_eq(entry.preview_path, "res://ui/save_preview.png")
	assert_eq(entry.resource_entry_ids, PackedStringArray(["ui.save"]))
	assert_eq(GFVariantData.get_option_string(entry.metadata, "license"), "CC0", "配置时应复制 metadata。")
	assert_eq(GFVariantData.get_option_string(data, "cache_key"), "res://ui/save.png")
	assert_eq(restored.asset_id, entry.asset_id)
	assert_eq(restored.tags, entry.tags)


func test_asset_catalog_indexes_searches_groups_and_pages_assets() -> void:
	var catalog: GF_ASSET_CATALOG_SCRIPT = GF_ASSET_CATALOG_SCRIPT.new()
	_set_asset_entry(catalog, _make_asset_entry(&"hero.idle", "res://characters/hero_idle.png", {
		"title": "Hero Idle",
		"tags": PackedStringArray(["character", "sprite"]),
		"category": "characters",
		"type_hint": "Texture2D",
		"metadata": { "author": "team" },
	}))
	_set_asset_entry(catalog, _make_asset_entry(&"ui.save", "res://ui/save.png", {
		"title": "Save Icon",
		"tags": PackedStringArray(["ui", "icon"]),
		"category": "interface",
		"type_hint": "Texture2D",
	}))

	var sprite_ids: PackedStringArray = catalog.query(GF_ASSET_CATALOG_SCRIPT.GROUP_SOURCE_TAGS, "sprite")
	var category_groups: Dictionary = catalog.group_asset_ids(GF_ASSET_CATALOG_SCRIPT.GROUP_SOURCE_CATEGORY)
	var search_results: Array[Dictionary] = catalog.search("hero sprite")
	var page: Dictionary = catalog.search_page("", 1, 1)
	var page_asset_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(page, "asset_ids")
	var summaries: Array = GFVariantData.get_option_array(page, "summaries")
	var first_summary: Dictionary = GFVariantData.as_dictionary(summaries[0])

	assert_eq(sprite_ids, PackedStringArray(["hero.idle"]))
	assert_eq(
		GFVariantData.get_option_packed_string_array(category_groups, "characters"),
		PackedStringArray(["hero.idle"])
	)
	assert_eq(search_results.size(), 1)
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.get_option_dictionary(search_results[0], "candidate"), "asset_id"),
		"hero.idle"
	)
	assert_eq(GFVariantData.get_option_int(page, "total_count"), 2)
	assert_eq(GFVariantData.get_option_int(page, "page_count"), 2)
	assert_eq(page_asset_ids.size(), 1)
	assert_eq(GFVariantData.get_option_string(first_summary, "asset_id"), page_asset_ids[0])


func test_asset_source_registry_keeps_high_priority_asset_on_duplicate_id() -> void:
	var registry: GF_ASSET_CATALOG_SOURCE_REGISTRY_SCRIPT = GF_ASSET_CATALOG_SOURCE_REGISTRY_SCRIPT.new()
	var low_resource_registry: GFResourceRegistry = GFResourceRegistry.new()
	var high_resource_registry: GFResourceRegistry = GFResourceRegistry.new()
	var _low_stored: bool = low_resource_registry.set_entry(
		_make_registry_entry(&"shared.icon", "res://low.png", {
			&"display_name": "Low",
		})
	)
	var _high_stored: bool = high_resource_registry.set_entry(
		_make_registry_entry(&"shared.icon", "res://high.png", {
			&"display_name": "High",
		})
	)
	var low_provider: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT.new()
	var _low_configured: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = low_provider.configure_registry(low_resource_registry, &"low")
	var high_provider: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT.new()
	var _high_configured: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = high_provider.configure_registry(high_resource_registry, &"high")

	assert_true(registry.register_source(low_provider, { "source_id": &"low", "priority": 1 }))
	assert_true(registry.register_source(high_provider, { "source_id": &"high", "priority": 100 }))

	var merged: GF_ASSET_CATALOG_SCRIPT = registry.build_catalog()
	var entry: GF_ASSET_CATALOG_ENTRY_SCRIPT = merged.get_entry(&"shared.icon")
	var report: Dictionary = registry.build_catalog_report()

	assert_not_null(entry, "重复 ID 合并后仍应保留一个条目。")
	if entry == null:
		return
	assert_eq(entry.title, "High", "默认合并应让高优先级来源胜出。")
	assert_eq(entry.primary_path, "res://high.png")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 1)
	assert_true(GFVariantData.get_option_bool(report, "ok"), "低优先级重复只应成为 warning，不应让 snapshot 失败。")


func test_resource_registry_asset_source_provider_converts_registry_entries() -> void:
	var resource_registry: GFResourceRegistry = GFResourceRegistry.new()
	var registry_entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new().configure(
		&"audio.click",
		"res://audio/click.ogg",
		"AudioStream",
		{
			&"display_name": "Click",
			&"description": "UI click sound",
			&"tags": PackedStringArray(["audio", "ui"]),
			&"category": "sfx",
			&"preview_path": "res://audio/click_preview.png",
		}
	)
	var _stored: bool = resource_registry.set_entry(registry_entry)
	var provider: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT.new()
	var _configured: GF_RESOURCE_REGISTRY_ASSET_SOURCE_PROVIDER_SCRIPT = provider.configure_registry(
		resource_registry,
		&"registry"
	)

	var catalog: GF_ASSET_CATALOG_SCRIPT = provider.build_catalog()
	var entry: GF_ASSET_CATALOG_ENTRY_SCRIPT = catalog.get_entry(&"audio.click")
	var snapshot: Dictionary = provider.get_debug_snapshot()

	assert_not_null(entry, "资源注册表条目应转换为资产条目。")
	if entry == null:
		return
	assert_eq(entry.asset_id, &"audio.click")
	assert_eq(entry.title, "Click")
	assert_eq(entry.description, "UI click sound")
	assert_eq(entry.tags, PackedStringArray(["audio", "ui"]))
	assert_eq(entry.category, &"sfx")
	assert_eq(entry.primary_path, "res://audio/click.ogg")
	assert_eq(entry.type_hint, "AudioStream")
	assert_eq(entry.preview_path, "res://audio/click_preview.png")
	assert_eq(entry.resource_entry_ids, PackedStringArray(["audio.click"]))
	assert_eq(entry.source_id, &"registry")
	assert_eq(GFVariantData.get_option_int(snapshot, "registry_entry_count"), 1)


# --- 私有/辅助方法 ---

func _set_asset_entry(catalog: GF_ASSET_CATALOG_SCRIPT, entry: GF_ASSET_CATALOG_ENTRY_SCRIPT) -> void:
	assert_true(catalog.set_entry(entry), "测试资产条目应可写入。")


func _make_asset_entry(asset_id: StringName, primary_path: String, options: Dictionary = {}) -> GF_ASSET_CATALOG_ENTRY_SCRIPT:
	return GF_ASSET_CATALOG_ENTRY_SCRIPT.new().configure(asset_id, primary_path, options)


func _make_registry_entry(
	entry_id: StringName,
	resource_path: String,
	fields: Dictionary = {},
	type_hint: String = ""
) -> GFResourceRegistryEntry:
	var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
	var _configured: Resource = entry.configure(entry_id, resource_path, type_hint, fields)
	return entry
