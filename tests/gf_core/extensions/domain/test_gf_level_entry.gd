## 测试 GFLevelEntry 的稳定 ID 与 duplicate_entry 深拷贝。
extends GutTest


func test_get_level_id_uses_exported_value() -> void:
	var entry: GFLevelEntry = GFLevelEntry.new()
	entry.level_id = &"forest_01"
	assert_eq(entry.get_level_id(), &"forest_01")


func test_get_level_id_does_not_use_resource_path_as_persistent_identity() -> void:
	var entry: GFLevelEntry = GFLevelEntry.new()
	entry.take_over_path("res://tests/gf_core/extensions/domain/unstable_level_path.tres")

	assert_eq(entry.get_level_id(), &"", "资源路径不能替代可持久化的显式关卡 ID。")
	var catalog: GFLevelCatalog = GFLevelCatalog.new()
	catalog.add_entry(entry)
	assert_true(catalog.entries.is_empty(), "目录应拒绝缺少稳定 ID 的条目。")
	assert_push_error("[GFLevelCatalog] add_entry 失败：关卡 ID 为空。")


func test_duplicate_entry_copies_metadata_deeply() -> void:
	var entry: GFLevelEntry = GFLevelEntry.new()
	entry.level_id = &"a"
	entry.sort_order = 5
	entry.metadata = { "n": 1 }
	entry.unlocks_on_complete = [&"b", &"c"]
	var dup: GFLevelEntry = entry.duplicate_entry()
	dup.metadata["n"] = 99
	dup.unlocks_on_complete[0] = &"z"
	assert_eq(GFVariantData.get_option_int(entry.metadata, "n"), 1, "副本不应与原件共享 metadata。")
	assert_eq(entry.unlocks_on_complete[0], &"b", "副本不应与原件共享解锁数组引用。")
	assert_eq(dup.sort_order, 5)
	assert_eq(dup.level_id, &"a")
