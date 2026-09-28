@tool
extends GutTest


const SOURCE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_source.gd")
const SNAPSHOT_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_snapshot.gd")
const PREFERENCES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_preferences.gd")
const GRID_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_grid.gd")
const TABLES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_resource_tables.gd")
const COMMAND_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_catalog_edit_command.gd")


func test_path_identity_keeps_directory_and_extension() -> void:
	var left: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://one/shared.tres", "Resource")
	var right: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://two/shared.tres", "Resource")
	var image: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://one/shared.png", "Texture2D")
	assert_ne(left.asset_id, right.asset_id)
	assert_ne(left.asset_id, image.asset_id)
	assert_eq(String(left.asset_id), "res://one/shared.tres")
	assert_eq(GFVariantData.get_option_string(left.metadata, "identity_kind"), "path")


func test_existing_uid_survives_a_path_move_without_registering_it() -> void:
	var existed_before: bool = ResourceUID.has_id(12345678)
	var first: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://one.tres", "Resource", 12345678)
	var moved: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://two.tres", "Resource", 12345678)
	assert_eq(first.asset_id, moved.asset_id)
	assert_ne(first.primary_path, moved.primary_path)
	assert_eq(ResourceUID.has_id(12345678), existed_before)


func test_snapshot_capacity_rejects_the_entire_candidate_catalog() -> void:
	var snapshot: SNAPSHOT_SCRIPT = SNAPSHOT_SCRIPT.new()
	for index: int in range(10_000):
		var accepted: bool = snapshot.append_entry(SOURCE_SCRIPT.make_entry("res://assets/%d.tres" % index, "Resource"))
		if not accepted:
			fail_test("The documented capacity must accept all 10,000 entries.")
			return
	assert_false(snapshot.append_entry(SOURCE_SCRIPT.make_entry("res://overflow.tres", "Resource")))
	var report: Dictionary = snapshot.finish()
	assert_eq(GFVariantData.get_option_string(report, "status"), "capacity_exceeded")
	assert_true(report.get("catalog") == null)
	assert_eq(GFVariantData.get_option_int(report, "count"), 10_000)


func test_snapshot_rejects_duplicate_uid_instead_of_retargeting() -> void:
	var snapshot: SNAPSHOT_SCRIPT = SNAPSHOT_SCRIPT.new()
	assert_true(snapshot.append_entry(SOURCE_SCRIPT.make_entry("res://one.tres", "Resource", 1234)))
	assert_false(snapshot.append_entry(SOURCE_SCRIPT.make_entry("res://two.tres", "Resource", 1234)))
	var report: Dictionary = snapshot.finish()
	assert_eq(GFVariantData.get_option_string(report, "status"), "duplicate_identity")
	assert_true(report.get("catalog") == null)


func test_empty_snapshot_is_complete_and_cannot_be_reused() -> void:
	var snapshot: SNAPSHOT_SCRIPT = SNAPSHOT_SCRIPT.new()
	var report: Dictionary = snapshot.finish()
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(report.get("catalog") is GFAssetCatalog)
	assert_false(snapshot.append_entry(SOURCE_SCRIPT.make_entry("res://one.tres", "Resource")))


func test_preferences_are_bounded_deduplicated_pure_data() -> void:
	var values: Array = [null, 22, "res://one.tres", "res://one.tres"]
	for index: int in range(1200):
		values.append("uid://%d" % index)
	var state: Dictionary = PREFERENCES_SCRIPT.normalize_state({"favorites": values, "recent": values, "scope": "C:/outside", "unknown": RefCounted.new()})
	var favorites: PackedStringArray = GFVariantData.get_option_packed_string_array(state, "favorites")
	var recent: PackedStringArray = GFVariantData.get_option_packed_string_array(state, "recent")
	assert_eq(favorites.size(), 1000)
	assert_eq(recent.size(), 100)
	assert_eq(favorites[0], "res://one.tres")
	assert_eq(GFVariantData.get_option_string(state, "scope"), "res://")
	assert_false(state.has("unknown"))


func test_grid_exposes_only_selected_project_paths() -> void:
	var grid: GRID_SCRIPT = GRID_SCRIPT.new()
	add_child_autofree(grid)
	grid.select_mode = ItemList.SELECT_MULTI
	var first: int = grid.add_item("one")
	grid.set_item_metadata(first, "res://one.tres")
	var second: int = grid.add_item("two")
	grid.set_item_metadata(second, "user://two.tres")
	grid.select(first, false)
	grid.select(second, false)
	assert_eq(grid.get_selected_resource_paths(), PackedStringArray(["res://one.tres"]))


func test_table_source_filter_rejects_scene_import_and_subresources() -> void:
	assert_true(TABLES_SCRIPT.is_editable_source_path("res://materials/main.tres"))
	assert_true(TABLES_SCRIPT.is_editable_source_path("res://materials/main.res"))
	assert_false(TABLES_SCRIPT.is_editable_source_path("res://main.tscn"))
	assert_false(TABLES_SCRIPT.is_editable_source_path("res://main.glb"))
	assert_false(TABLES_SCRIPT.is_editable_source_path("res://main.tres::Nested"))
	assert_false(TABLES_SCRIPT.is_editable_source_path("user://main.tres"))


func test_table_save_button_tracks_context_release_and_rebind() -> void:
	var tables: TABLES_SCRIPT = TABLES_SCRIPT.new()
	add_child_autofree(tables)
	var save_button: Button = tables.get_child(1)
	assert_true(save_button.disabled)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	tables.set_editor_context(context)
	assert_false(save_button.disabled)
	tables.release_context()
	assert_true(save_button.disabled)
	tables.set_editor_context(context)
	assert_false(save_button.disabled)
	tables.release_context()


func test_shared_catalog_command_updates_index_during_execute_and_undo() -> void:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	var before: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry("res://one.tres", "Resource")
	before.tags = PackedStringArray(["before"])
	assert_true(catalog.set_entry(before))
	assert_eq(catalog.get_entry(before.asset_id).tags, PackedStringArray(["before"]))
	var after: GFAssetCatalogEntry = before.duplicate_entry()
	after.tags = PackedStringArray(["after"])
	var command: COMMAND_SCRIPT = COMMAND_SCRIPT.new()
	command.configure_catalog(catalog, [after])
	assert_eq(command.execute(), OK)
	assert_eq(catalog.get_entry(before.asset_id).tags, PackedStringArray(["after"]))
	assert_eq(command.revert(), OK)
	assert_eq(catalog.get_entry(before.asset_id).tags, PackedStringArray(["before"]))
	assert_eq(before.tags, PackedStringArray(["before"]))
