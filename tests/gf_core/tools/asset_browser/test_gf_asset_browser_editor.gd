@tool
extends GutTest


const SOURCE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_source.gd")
const SNAPSHOT_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_snapshot.gd")
const PREFERENCES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_preferences.gd")
const GRID_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_grid.gd")
const TABLES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_resource_tables.gd")
const COMMAND_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_catalog_edit_command.gd")
const DOCK_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_dock.gd")


var _saved_test_paths: PackedStringArray = PackedStringArray()


func after_each() -> void:
	for path: String in _saved_test_paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(path)
	_saved_test_paths.clear()
	await get_tree().process_frame


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


func test_shared_catalog_selection_uses_asset_ids_for_details_favorites_and_recent() -> void:
	var first: GFAssetCatalogEntry = _rich_shared_entry(&"alias_a")
	var second: GFAssetCatalogEntry = _rich_shared_entry(&"alias_b")
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	catalog.entries = [first, second]
	var dock: AssetDockProbe = _new_asset_dock(catalog, catalog, true)
	dock.select_identity(second.asset_id)
	var selected: Array[GFAssetCatalogEntry] = dock._selected_entries()
	assert_eq(selected.size(), 1, "一个卡片只能选择其 asset_id，不能扩展成同路径的其他条目。")
	if not selected.is_empty():
		assert_eq(selected[0].asset_id, second.asset_id)
	assert_eq(dock._selected_id, second.asset_id)
	var details: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(dock._details.text))
	assert_eq(GFVariantData.get_option_string(details, "asset_id"), String(second.asset_id))
	assert_eq(dock._tags.text, ", ".join(second.tags))
	assert_eq(dock._notes.text, second.description)
	dock._toggle_favorites()
	dock._record_recent()
	assert_eq(GFVariantData.get_option_packed_string_array(dock._state, "favorites"), PackedStringArray([String(second.asset_id)]))
	assert_eq(GFVariantData.get_option_packed_string_array(dock._state, "recent"), PackedStringArray([String(second.asset_id)]))
	dock._toggle_favorites()
	assert_true(GFVariantData.get_option_packed_string_array(dock._state, "favorites").is_empty())
	dock.select_identity(first.asset_id, false)
	assert_eq(dock._selected_entries().size(), 2, "两个显式选择仍分别保留资产身份。")
	assert_eq(dock.get_selected_resource_paths(), PackedStringArray([first.primary_path]), "仅原生资源动作按路径去重。")


func test_shared_catalog_tag_edit_leaves_unselected_same_path_alias_unchanged() -> void:
	var first: GFAssetCatalogEntry = _rich_shared_entry(&"alias_a")
	var second: GFAssetCatalogEntry = _rich_shared_entry(&"alias_b")
	first.source_id = &"shared_catalog"
	second.source_id = &"shared_catalog"
	var before_first: Dictionary = first.to_dict()
	var expected_second: GFAssetCatalogEntry = second.duplicate_entry()
	expected_second.tags = PackedStringArray(["edited"])
	expected_second.description = "only the selected alias"
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	catalog.entries = [second, first]
	var dock: AssetDockProbe = _new_asset_dock(catalog, catalog, true)
	dock.select_identity(second.asset_id)
	dock._tags.text = "edited"
	dock._notes.text = expected_second.description
	dock._apply_shared_fields()
	assert_eq(catalog.get_entry(first.asset_id).to_dict(), before_first, "同路径但未选中的 alias 不得被共享标签编辑修改。")
	assert_eq(catalog.get_entry(second.asset_id).to_dict(), expected_second.to_dict())
	assert_eq(catalog.entries[0].asset_id, second.asset_id, "更新已有条目保留显式共享目录的原始顺序。")


func test_project_tag_edit_preserves_full_shared_entry_through_replay_and_save() -> void:
	var original: GFAssetCatalogEntry = _rich_shared_entry(&"project_asset")
	var before: Dictionary = original.to_dict()
	var shared: GFAssetCatalog = GFAssetCatalog.new()
	shared.entries = [original]
	var projected: GFAssetCatalogEntry = SOURCE_SCRIPT.make_entry(original.primary_path, "Resource")
	projected.asset_id = original.asset_id
	var project: GFAssetCatalog = GFAssetCatalog.new()
	project.entries = [projected]
	var dock: AssetDockProbe = _new_asset_dock(project, shared, false)
	dock.select_identity(original.asset_id)
	var expected: GFAssetCatalogEntry = original.duplicate_entry()
	expected.tags = PackedStringArray(["new", "tags"])
	expected.description = "edited notes"
	dock._tags.text = "new, tags"
	dock._notes.text = expected.description
	dock._apply_shared_fields()
	assert_eq(shared.get_entry(original.asset_id).to_dict(), expected.to_dict(), "项目投影只能覆盖 tags/description，不能替换共享条目的其他字段。")
	assert_eq(original.to_dict(), before, "编辑应使用独立副本。")
	var context: CapturingContext = dock.test_context
	assert_not_null(context.command)
	if context.command == null:
		return
	assert_eq(context.command.revert(), OK)
	assert_eq(shared.get_entry(original.asset_id).to_dict(), before)
	assert_eq(context.command.execute(), OK)
	assert_eq(shared.get_entry(original.asset_id).to_dict(), expected.to_dict(), "Redo 不得重新引入项目投影的字段丢失。")
	var save_path: String = "user://gf_asset_browser_editor_%d.tres" % get_instance_id()
	var _path_appended: bool = _saved_test_paths.append(save_path)
	assert_eq(ResourceSaver.save(shared, save_path), OK)
	var saved: Resource = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(saved is GFAssetCatalog)
	if saved is GFAssetCatalog:
		var saved_catalog: GFAssetCatalog = saved
		assert_eq(saved_catalog.get_entry(original.asset_id).to_dict(), expected.to_dict(), "显式保存后的全部字段必须与编辑结果一致。")


func _rich_shared_entry(identity: StringName) -> GFAssetCatalogEntry:
	var entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	entry.asset_id = identity
	entry.primary_path = "res://tests/gf_core/tools/asset_browser/shared_alias.tres"
	entry.title = "Curated " + String(identity)
	entry.description = "Notes " + String(identity)
	entry.tags = PackedStringArray([String(identity), "original"])
	entry.category = &"curated_category"
	entry.type_hint = "Resource"
	entry.preview_path = "res://tests/gf_core/tools/asset_browser/preview.png"
	entry.resource_entry_ids = PackedStringArray(["registry.first", "registry.second"])
	entry.source_id = &"curated_library"
	entry.metadata = {"custom": {"owner": String(identity), "weights": [1, 2, 3]}, "enabled": true}
	return entry


func _new_asset_dock(project: GFAssetCatalog, shared: GFAssetCatalog, shared_source: bool) -> AssetDockProbe:
	var dock: AssetDockProbe = AssetDockProbe.new()
	add_child_autofree(dock)
	dock.configure_catalogs(project, shared, shared_source)
	return dock


class CapturingContext:
	extends GFEditorToolContext

	var command: GFEditorToolContext.GFEditorCommandBase = null

	func commit_command(value: GFEditorCommandBase, _use_undo: bool = true) -> Error:
		command = value
		return value.execute()


class AssetDockProbe:
	extends DOCK_SCRIPT

	var test_context: CapturingContext = CapturingContext.new()

	func configure_catalogs(project: GFAssetCatalog, shared: GFAssetCatalog, shared_source: bool) -> void:
		_project_catalog = project
		_shared_catalog = shared
		_context = test_context
		_scope.text = "res://"
		_sources.select(1 if shared_source else 0)
		_project_snapshot_valid = true
		_publish_catalog()

	func select_identity(identity: StringName, replace: bool = true) -> void:
		var index: int = _card_ids.find(String(identity))
		if replace:
			_grid.deselect_all()
		if index >= 0:
			_grid.select(index, false)
			_on_grid_selected(index, true)

	func _can_update_view() -> bool:
		return _context != null

	func _store_view_state() -> void:
		pass

	# 仅替换异步预览调度；Catalog 发布、模型排序、卡片 ID、选择与编辑仍执行实际产品路径。
	func _render_page() -> void:
		var report: Dictionary = _model.get_page(1, 100)
		_card_ids = GFVariantData.get_option_packed_string_array(report, "asset_ids")
		_grid.clear()
		for identity: String in _card_ids:
			var entry: GFAssetCatalogEntry = _catalog.get_entry(StringName(identity))
			var index: int = _grid.add_item(entry.title)
			_grid.set_item_metadata(index, entry.primary_path)
		_query_pending = false
		_page_ready = true
		_grid.set_resource_actions_enabled(true)
