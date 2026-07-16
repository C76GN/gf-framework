## 测试 GFResourceRegistry 的稳定 ID、字段索引和资源加载衔接。
extends GutTest


func test_entry_configure_duplicates_fields() -> void:
	var tags: Array[String] = ["weapon", "rare"]
	var fields: Dictionary = {
		&"tags": tags,
	}
	var entry: GFResourceRegistryEntry = _make_entry(
		&"sword",
		"res://items/sword.tres",
		fields,
		"Resource"
	)
	tags.append("mutated")

	var stored_tags: Array = GFVariantData.get_option_array(entry.fields, &"tags")

	assert_true(entry.is_valid_entry(), "ID 和路径有效时条目应可用。")
	assert_eq(entry.id, &"sword")
	assert_eq(entry.path, "res://items/sword.tres")
	assert_eq(entry.type_hint, "Resource")
	assert_eq(stored_tags, ["weapon", "rare"], "配置时应复制字段，避免调用方继续修改。")


func test_registry_replaces_entries_by_stable_id() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	var first: GFResourceRegistryEntry = _make_entry(&"item", "res://old.tres", { &"kind": "old" })
	var second: GFResourceRegistryEntry = _make_entry(&"item", "res://new.tres", { &"kind": "new" })

	assert_true(registry.set_entry(first))
	assert_true(registry.set_entry(second))

	assert_eq(registry.get_all_ids(), PackedStringArray(["item"]), "重复 ID 应替换而不是追加。")
	assert_eq(registry.get_entry_path(&"item"), "res://new.tres")
	assert_eq(registry.query(&"kind", "old"), PackedStringArray(), "替换条目后旧字段索引应清理。")
	assert_eq(registry.query(&"kind", "new"), PackedStringArray(["item"]))


func test_registry_entry_uses_resource_identity_cache_key_for_uid_paths() -> void:
	var script_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_identity.gd"
	var uid_path: String = _uid_path_for(script_path)
	assert_false(uid_path.is_empty(), "测试资源应存在 Godot UID。")

	var registry: GFResourceRegistry = GFResourceRegistry.new()
	var entry: GFResourceRegistryEntry = _make_entry(&"identity_script", uid_path, {}, "Script")
	_set_entry(registry, entry)

	var entry_dict: Dictionary = entry.to_dict()
	var identity: GFResourceIdentity = registry.get_entry_resource_identity(&"identity_script")
	var identity_dict: Dictionary = GFVariantData.get_option_dictionary(entry_dict, "resource_identity")
	var cache_key_query: PackedStringArray = registry.query(GFResourceRegistry.GROUP_SOURCE_CACHE_KEY, uid_path)
	var cache_key_groups: Dictionary = registry.group_entry_ids(GFResourceRegistry.GROUP_SOURCE_CACHE_KEY)
	var summary: Dictionary = registry.make_entry_summary(&"identity_script")
	var candidates: Array[Dictionary] = registry.make_search_candidates(PackedStringArray(["identity_script"]))
	assert_eq(candidates.size(), 1, "过滤后的搜索候选应只包含目标条目。")
	if candidates.is_empty():
		return
	var candidate: Dictionary = candidates[0]
	var asset_entries: Array = registry.make_asset_group_entries(PackedStringArray(["identity_script"]))
	assert_eq(asset_entries.size(), 1, "过滤后的 AssetUtility 分组请求应只包含目标条目。")
	if asset_entries.is_empty():
		return
	var asset_entry: Dictionary = GFVariantData.as_dictionary(asset_entries[0])

	assert_eq(entry.path, script_path, "条目应保存 canonical path。")
	assert_eq(entry.get_cache_key(), uid_path, "条目应按资源身份暴露 cache_key。")
	assert_eq(GFVariantData.get_option_string(entry_dict, "cache_key"), uid_path, "序列化字典应包含 cache_key。")
	assert_eq(GFVariantData.get_option_string(identity_dict, "canonical_path"), script_path, "序列化字典应包含资源身份快照。")
	assert_eq(identity.cache_key, uid_path, "注册表应能直接读取资源身份。")
	assert_eq(cache_key_query, PackedStringArray(["identity_script"]), "cache_key 应进入字段索引。")
	assert_eq(GFVariantData.get_option_packed_string_array(cache_key_groups, uid_path), PackedStringArray(["identity_script"]), "注册表应支持按 cache_key 分组。")
	assert_eq(GFVariantData.get_option_string(summary, "cache_key"), uid_path, "条目摘要应包含 cache_key。")
	assert_eq(GFVariantData.get_option_string(candidate, "cache_key"), uid_path, "搜索候选应包含 cache_key。")
	assert_eq(GFVariantData.get_option_string(asset_entry, "cache_key"), uid_path, "AssetUtility 分组请求应包含 cache_key。")


func test_registry_set_entry_collapses_preexisting_duplicate_ids() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.entries = [
		_make_entry(&"item", "res://old_a.tres", { &"kind": "old_a" }),
		_make_entry(&"item", "res://old_b.tres", { &"kind": "old_b" }),
	]
	registry.mark_index_dirty()

	assert_true(registry.set_entry(_make_entry(&"item", "res://new.tres", { &"kind": "new" })), "set_entry 应能替换脏数据中的重复 ID。")

	assert_eq(registry.entries.size(), 1, "set_entry 应清理所有旧重复 ID 条目。")
	assert_eq(registry.get_entry_path(&"item"), "res://new.tres", "重复 ID 清理后新条目应成为有效条目。")
	assert_eq(registry.query(&"kind", "old_a"), PackedStringArray(), "旧重复条目的字段索引应清理。")
	assert_eq(registry.query(&"kind", "old_b"), PackedStringArray(), "后出现旧重复条目的字段索引也应清理。")
	assert_eq(registry.query(&"kind", "new"), PackedStringArray(["item"]), "新条目字段应进入索引。")


func test_query_supports_multi_value_fields_and_many_criteria() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://sword.tres", {
		&"kind": "weapon",
		&"tags": ["sharp", "metal"],
		&"rarity": "rare",
	}))
	_set_entry(registry, _make_entry(&"shield", "res://shield.tres", {
		&"kind": "armor",
		&"tags": ["metal"],
		&"rarity": "rare",
	}))

	assert_eq(registry.query(&"tags", "metal"), PackedStringArray(["shield", "sword"]))
	assert_eq(registry.query_many({ &"kind": "weapon", &"rarity": "rare" }), PackedStringArray(["sword"]))
	assert_eq(registry.query_many({ &"kind": "weapon", &"kind_alt": "armor" }, false), PackedStringArray(["sword"]))


func test_direct_entry_mutation_can_rebuild_index() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"item", "res://item.tres", { &"tier": 1 }))
	assert_eq(registry.query(&"tier", 1), PackedStringArray(["item"]))

	var entry: GFResourceRegistryEntry = registry.entries[0]
	entry.fields = { &"tier": 2 }
	registry.mark_index_dirty()

	assert_eq(registry.query(&"tier", 1), PackedStringArray())
	assert_eq(registry.query(&"tier", 2), PackedStringArray(["item"]))


func test_make_asset_group_entries_uses_registered_type_hints() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"a", "res://a.tres", { &"group": "one" }, "PackedScene"))
	_set_entry(registry, _make_entry(&"b", "res://b.tres", { &"group": "two" }, "Resource"))

	var entries: Array = registry.make_asset_group_entries(PackedStringArray(["b"]))
	var entry: Dictionary = GFVariantData.as_dictionary(entries[0])

	assert_eq(entries.size(), 1)
	assert_eq(GFVariantData.get_option_string(entry, "path"), "res://b.tres")
	assert_eq(GFVariantData.get_option_string(entry, "type_hint"), "Resource")


func test_search_ranks_entries_by_id_path_type_and_fields() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://items/silver_sword.tres", {
		&"kind": "weapon",
		&"tags": ["sharp", "metal"],
	}, "Resource"))
	_set_entry(registry, _make_entry(&"shield", "res://items/round_shield.tres", {
		&"kind": "armor",
		&"tags": ["metal"],
	}, "Resource"))

	var results: Array[Dictionary] = registry.search("sharp sword")
	var candidate: Dictionary = GFVariantData.get_option_dictionary(results[0], "candidate")

	assert_eq(results.size(), 1, "默认应只返回命中的候选。")
	assert_eq(GFVariantData.get_option_string(candidate, "id"), "sword")
	assert_eq(GFVariantData.get_option_string(candidate, "path"), "res://items/silver_sword.tres")
	assert_eq(GFVariantData.get_option_dictionary(candidate, "fields"), {
		&"kind": "weapon",
		&"tags": ["sharp", "metal"],
	})


func test_search_accepts_entry_id_filter() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://items/sword.tres", {
		&"tags": ["metal"],
	}))
	_set_entry(registry, _make_entry(&"shield", "res://items/shield.tres", {
		&"tags": ["metal"],
	}))

	var results: Array[Dictionary] = registry.search("metal", {
		"entry_ids": PackedStringArray(["shield"]),
	})
	var candidate: Dictionary = GFVariantData.get_option_dictionary(results[0], "candidate")

	assert_eq(results.size(), 1)
	assert_eq(GFVariantData.get_option_string(candidate, "id"), "shield")


func test_make_entry_summary_uses_generic_display_preview_and_tags() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://items/sword.tres", {
		&"display_name": "Silver Sword",
		&"description": "Sharp enough for tests.",
		&"preview_path": "res://thumbs/sword.png",
		&"tags": ["weapon", "rare", "weapon"],
		&"category": "items",
	}, "Resource"))

	var summary: Dictionary = registry.make_entry_summary(&"sword")

	assert_eq(GFVariantData.get_option_string(summary, "id"), "sword")
	assert_eq(GFVariantData.get_option_string(summary, "entry_id"), "sword")
	assert_eq(GFVariantData.get_option_string(summary, "title"), "Silver Sword")
	assert_eq(GFVariantData.get_option_string(summary, "path"), "res://items/sword.tres")
	assert_eq(GFVariantData.get_option_string(summary, "path_basename"), "sword")
	assert_eq(GFVariantData.get_option_string(summary, "type_hint"), "Resource")
	assert_eq(GFVariantData.get_option_string(summary, "description"), "Sharp enough for tests.")
	assert_eq(GFVariantData.get_option_string(summary, "preview_path"), "res://thumbs/sword.png")
	assert_eq(GFVariantData.get_option_string(summary, "category"), "items")
	assert_eq(
		GFVariantData.get_option_packed_string_array(summary, "tags"),
		PackedStringArray(["rare", "weapon"]),
		"摘要标签应去重并稳定排序，方便工具层展示。"
	)
	assert_true(summary.has("fields"), "默认摘要应保留 fields 副本，便于工具面板读取通用字段。")


func test_make_entry_summary_accepts_custom_field_options() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"lantern", "res://items/lantern.tres", {
		&"label": "Traveler Lantern",
		&"brief": "Portable light.",
		&"thumb": "res://thumbs/lantern.png",
		&"keywords": PackedStringArray(["tool", "light"]),
	}, "Resource"))

	var summary: Dictionary = registry.make_entry_summary(&"lantern", {
		"title_fields": PackedStringArray(["label"]),
		"description_fields": PackedStringArray(["brief"]),
		"preview_path_fields": PackedStringArray(["thumb"]),
		"tag_fields": PackedStringArray(["keywords"]),
		"include_fields": false,
	})

	assert_eq(GFVariantData.get_option_string(summary, "title"), "Traveler Lantern")
	assert_eq(GFVariantData.get_option_string(summary, "description"), "Portable light.")
	assert_eq(GFVariantData.get_option_string(summary, "preview_path"), "res://thumbs/lantern.png")
	assert_eq(GFVariantData.get_option_packed_string_array(summary, "tags"), PackedStringArray(["light", "tool"]))
	assert_false(summary.has("fields"), "工具需要轻量列表时应可关闭 fields 输出。")


func test_search_page_returns_page_metadata_and_summaries() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"axe", "res://items/axe.tres", {
		&"display_name": "Axe",
		&"tags": ["metal"],
	}))
	_set_entry(registry, _make_entry(&"shield", "res://items/shield.tres", {
		&"display_name": "Shield",
		&"tags": ["metal"],
	}))
	_set_entry(registry, _make_entry(&"sword", "res://items/sword.tres", {
		&"display_name": "Sword",
		&"tags": ["metal"],
	}))

	var page: Dictionary = registry.search_page("metal", 1, 2)
	var page_entry_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(page, "entry_ids")
	var summaries: Array = GFVariantData.get_option_array(page, "summaries")
	var summary: Dictionary = GFVariantData.as_dictionary(summaries[0])
	var second_summary: Dictionary = GFVariantData.as_dictionary(summaries[1])

	assert_eq(GFVariantData.get_option_int(page, "page"), 1)
	assert_eq(GFVariantData.get_option_int(page, "page_size"), 2)
	assert_eq(GFVariantData.get_option_int(page, "page_count"), 2)
	assert_eq(GFVariantData.get_option_int(page, "total_count"), 3)
	assert_eq(GFVariantData.get_option_int(page, "start_index"), 0)
	assert_eq(GFVariantData.get_option_int(page, "end_index"), 2)
	assert_false(GFVariantData.get_option_bool(page, "has_previous"))
	assert_true(GFVariantData.get_option_bool(page, "has_next"))
	assert_eq(page_entry_ids.size(), 2)
	assert_eq(summaries.size(), 2)
	assert_eq(GFVariantData.get_option_string(summary, "entry_id"), page_entry_ids[0])
	assert_eq(GFVariantData.get_option_string(second_summary, "entry_id"), page_entry_ids[1])
	assert_false(GFVariantData.get_option_string(summary, "title").is_empty())


func test_search_page_empty_query_lists_all_entries_without_resource_loads() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://items/sword.tres"))
	_set_entry(registry, _make_entry(&"shield", "res://items/shield.tres"))
	_set_entry(registry, _make_entry(&"axe", "res://items/axe.tres"))

	var page: Dictionary = registry.search_page("", 1, 2, {
		"include_summaries": false,
	})
	var results: Array = GFVariantData.get_option_array(page, "results")
	var first_report: Dictionary = GFVariantData.as_dictionary(results[0])

	assert_eq(GFVariantData.get_option_int(page, "total_count"), 3)
	assert_eq(GFVariantData.get_option_int(page, "page_count"), 2)
	assert_eq(
		GFVariantData.get_option_packed_string_array(page, "entry_ids"),
		PackedStringArray(["axe", "shield"])
	)
	assert_true(GFVariantData.get_option_array(page, "summaries").is_empty())
	assert_false(GFVariantData.get_option_bool(first_report, "matched"), "空查询列表报告不伪装成文本命中。")


func test_group_entry_ids_groups_by_field_values_and_path_basename() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"sword", "res://items/silver_sword.tres", {
		&"kind": "weapon",
		&"tags": ["sharp", "metal"],
	}, "Resource"))
	_set_entry(registry, _make_entry(&"shield", "res://items/round_shield.tres", {
		&"kind": "armor",
		&"tags": ["metal"],
	}, "Resource"))

	var tag_groups: Dictionary = registry.group_entry_ids(GFResourceRegistry.GROUP_SOURCE_FIELD, {
		"field_id": &"tags",
	})
	var path_groups: Dictionary = registry.group_entry_ids(GFResourceRegistry.GROUP_SOURCE_PATH_BASENAME, {
		"entry_ids": PackedStringArray(["sword"]),
	})

	assert_eq(GFVariantData.get_option_packed_string_array(tag_groups, "metal"), PackedStringArray(["shield", "sword"]), "字段数组值应产生非唯一分组。")
	assert_eq(GFVariantData.get_option_packed_string_array(tag_groups, "sharp"), PackedStringArray(["sword"]))
	assert_eq(GFVariantData.get_option_packed_string_array(path_groups, "silver_sword"), PackedStringArray(["sword"]), "路径 basename 分组应可配合 entry_ids 过滤。")
	assert_false(path_groups.has("round_shield"), "entry_ids 过滤外的条目不应进入分组。")


func test_load_entry_uses_resource_loader_path_and_type_hint() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(
		&"index_script",
		"res://addons/gf/standard/foundation/collections/gf_value_index.gd",
		{},
		"Script"
	))

	var resource: Resource = registry.load_entry(&"index_script")

	assert_not_null(resource, "注册表应能同步加载已登记的资源。")
	assert_true(resource is Script, "type_hint 为 Script 时应返回脚本资源。")


func test_request_entry_async_delegates_to_asset_utility() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"item", "res://item.tres", {}, "Resource"))
	var utility: ManualAssetUtility = ManualAssetUtility.new()
	var loaded_resources: Array[Resource] = []

	registry.request_entry_async(
		utility,
		&"item",
		func(resource: Resource) -> void:
			loaded_resources.append(resource)
	)

	assert_eq(utility.requested_path, "res://item.tres")
	assert_eq(utility.requested_type_hint, "Resource")
	assert_eq(loaded_resources.size(), 1)
	assert_eq(loaded_resources[0], utility.returned_resource)


func test_request_entry_handle_async_delegates_group_and_owner() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"item", "res://item.tres", {}, "Resource"))
	var utility: ManualAssetUtility = ManualAssetUtility.new()
	var request_owner: Node = Node.new()
	var loaded_handles: Array[GFAssetHandle] = []

	registry.request_entry_handle_async(
		utility,
		&"item",
		func(handle: GFAssetHandle) -> void:
			loaded_handles.append(handle),
		request_owner,
		&"items"
	)

	assert_eq(utility.requested_handle_path, "res://item.tres")
	assert_eq(utility.requested_handle_type_hint, "Resource")
	assert_eq(utility.requested_group_id, &"items")
	assert_eq(loaded_handles.size(), 1)
	assert_eq(loaded_handles[0].path, "res://item.tres")
	assert_eq(loaded_handles[0].get_owner_id(), request_owner.get_instance_id())

	request_owner.free()


func test_to_dict_and_from_dict_preserve_entries() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	_set_entry(registry, _make_entry(&"item", "res://item.tres", { &"kind": "test" }, "Resource"))

	var restored: GFResourceRegistry = _registry_from_resource(GFResourceRegistry.from_dict(registry.to_dict()))

	assert_true(restored.has_entry(&"item"))
	assert_eq(restored.get_entry_path(&"item"), "res://item.tres")
	assert_eq(restored.get_entry_type_hint(&"item"), "Resource")
	assert_eq(restored.query(&"kind", "test"), PackedStringArray(["item"]))


# --- 私有/辅助方法 ---

func _set_entry(registry: GFResourceRegistry, entry: GFResourceRegistryEntry) -> void:
	assert_true(registry.set_entry(entry), "测试注册表条目应可写入。")


func _make_entry(
	entry_id: StringName,
	resource_path: String,
	fields: Dictionary = {},
	type_hint: String = ""
) -> GFResourceRegistryEntry:
	return _entry_from_resource(
		GFResourceRegistryEntry.new().configure(entry_id, resource_path, type_hint, fields)
	)


func _entry_from_resource(resource: Resource) -> GFResourceRegistryEntry:
	if resource is GFResourceRegistryEntry:
		var entry: GFResourceRegistryEntry = resource
		return entry
	return null


func _registry_from_resource(resource: Resource) -> GFResourceRegistry:
	if resource is GFResourceRegistry:
		var registry: GFResourceRegistry = resource
		return registry
	return null


func _uid_path_for(path: String) -> String:
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid)


# --- 内部类 ---

class ManualAssetUtility extends GFAssetUtility:
	var requested_path: String = ""
	var requested_type_hint: String = ""
	var requested_handle_path: String = ""
	var requested_handle_type_hint: String = ""
	var requested_group_id: StringName = &""
	var returned_resource: Resource = Resource.new()

	func load_async(path: String, on_loaded: Callable, type_hint: String = "", _options: Dictionary = {}) -> void:
		requested_path = path
		requested_type_hint = type_hint
		var _callback_result: Variant = on_loaded.call(returned_resource)

	func load_handle_async(
		path: String,
		on_loaded: Callable,
		type_hint: String = "",
		owner: Object = null,
		group_id: StringName = &"",
		_options: Dictionary = {}
	) -> void:
		requested_handle_path = path
		requested_handle_type_hint = type_hint
		requested_group_id = group_id
		var handle: GFAssetHandle = GFAssetHandle.new()
		var owner_id: int = owner.get_instance_id() if owner != null else 0
		handle.setup_from_utility(self, path, returned_resource, type_hint, group_id, owner_id)
		var _callback_result: Variant = on_loaded.call(handle)
