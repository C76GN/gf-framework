@tool
extends GutTest


const _INDEX_SCRIPT = preload("res://addons/gf/tools/scene_groups/gf_scene_group_index.gd")
const _FIXTURE_ROOT: String = "res://tests/gf_core/tools/scene_groups/fixtures/scenes"
const _INSTANTIATED_MARKER: StringName = &"gf_scene_group_index_node_instantiated"
const _READY_MARKER: StringName = &"gf_scene_group_index_node_ready"

var _temporary_root: String = ""
var _temporary_files: PackedStringArray = PackedStringArray()
var _temporary_directories: PackedStringArray = PackedStringArray()


func before_each() -> void:
	Engine.remove_meta(_INSTANTIATED_MARKER)
	Engine.remove_meta(_READY_MARKER)
	_temporary_root = "res://tests/gf_core/tools/scene_groups/fixtures/temporary_%d_%d" % [get_instance_id(), Time.get_ticks_usec()]
	_temporary_files.clear()
	_temporary_directories.clear()


func after_each() -> void:
	for file_path: String in _temporary_files:
		if FileAccess.file_exists(file_path):
			assert_eq(DirAccess.remove_absolute(file_path), OK)
	_temporary_directories.reverse()
	for directory_path: String in _temporary_directories:
		if DirAccess.dir_exists_absolute(directory_path):
			assert_eq(DirAccess.remove_absolute(directory_path), OK)
	Engine.remove_meta(_INSTANTIATED_MARKER)
	Engine.remove_meta(_READY_MARKER)


func test_indexes_only_local_saved_declarations_without_instantiating_nodes() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	_finish(index)
	var snapshot: Dictionary = index.get_snapshot()
	assert_eq(_string_field(snapshot, "status"), "complete")
	assert_eq(_int_field(snapshot, "scene_count"), 4)
	assert_eq(_int_field(snapshot, "row_count"), 7)
	assert_false(snapshot.has("rows"), "摘要不复制整个索引。")
	assert_false(Engine.has_meta(_INSTANTIATED_MARKER))
	assert_false(Engine.has_meta(_READY_MARKER))
	assert_eq(_rows(index.query("shared")), [{
		"group": "shared",
		"scene_path": _FIXTURE_ROOT.path_join("base.tscn"),
		"node_path": "Child",
	}])
	assert_eq(_rows(index.query("parent.tscn")).size(), 1)
	assert_eq(_rows(index.query("derived.tscn")).size(), 2)
	assert_eq(_rows(index.query("placeholder.tscn")).size(), 1)
	assert_eq(_rows(index.query("Actors")).size(), 2, "同名大小写不同的组保留不同身份。")
	var actor_rows: Array[Dictionary] = _rows(index.query("Actors"))
	if not actor_rows.is_empty():
		assert_eq(_string_field(actor_rows[0], "node_path"), ".")


func test_query_filters_pages_sorts_and_returns_defensive_copies() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	_finish(index)
	var page: Dictionary = index.query("", 1, 2)
	assert_eq(_int_field(page, "total"), 7)
	assert_eq(_int_field(page, "offset"), 1)
	assert_eq(_int_field(page, "limit"), 2)
	assert_eq(_rows(page).size(), 2)
	assert_eq(_int_field(index.query("CHILD"), "total"), 2)
	var rows: Array[Dictionary] = _rows(page)
	if not rows.is_empty():
		rows[0]["group"] = "corrupted"
	assert_eq(_int_field(index.query("corrupted"), "total"), 0)
	assert_eq(_int_field(index.query("", -8, 900), "offset"), 0)
	assert_eq(_int_field(index.query("", -8, 900), "limit"), 200)
	assert_eq(_rows(index.query("", 999)).size(), 0)
	var baseline: Array[Dictionary] = _rows(index.query())
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	_finish(index, 1)
	assert_eq(_rows(index.query()), baseline, "不同步进量不改变排序。")


func test_each_hard_budget_reports_partial_instead_of_empty_success() -> void:
	for option: Dictionary in [
		{ "max_entries": 1 },
		{ "max_scenes": 1 },
		{ "max_rows": 1 },
		{ "max_scene_bytes": 1 },
	]:
		var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
		assert_eq(index.begin_scan(_FIXTURE_ROOT, option), OK)
		_finish(index)
		var snapshot: Dictionary = index.get_snapshot()
		assert_eq(_string_field(snapshot, "status"), "partial", str(option))
		assert_gt(_issues(snapshot).size(), 0)


func test_depth_budget_and_ignored_directories_have_different_meanings() -> void:
	_make_directory(_temporary_root)
	_make_directory(_temporary_root.path_join("nested"))
	_write_scene(_temporary_root.path_join("nested/member.tscn"), "nested")
	var limited: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(limited.begin_scan(_temporary_root, { "max_depth": 0 }), OK)
	_finish(limited)
	assert_eq(_string_field(limited.get_snapshot(), "status"), "partial")
	assert_eq(_int_field(limited.get_snapshot(), "row_count"), 0)
	_write_text(_temporary_root.path_join("nested/.gdignore"), "")
	_make_directory(_temporary_root.path_join(".hidden"))
	_write_scene(_temporary_root.path_join(".hidden/member.tscn"), "hidden")
	var scoped: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(scoped.begin_scan(_temporary_root), OK)
	_finish(scoped)
	assert_eq(_string_field(scoped.get_snapshot(), "status"), "complete")
	assert_eq(_int_field(scoped.get_snapshot(), "row_count"), 0)


func test_cancel_closes_incremental_work_and_restart_discards_partial_rows() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	assert_true(index.advance(1))
	index.cancel()
	assert_eq(_string_field(index.get_snapshot(), "status"), "cancelled")
	assert_false(index.advance())
	index.cancel()
	assert_eq(_string_field(index.get_snapshot(), "status"), "cancelled")
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	assert_eq(_int_field(index.get_snapshot(), "row_count"), 0)
	_finish(index)
	assert_eq(_string_field(index.get_snapshot(), "status"), "complete")


func test_refresh_reads_disk_without_replacing_cached_scene_state() -> void:
	_make_directory(_temporary_root)
	var scene_path: String = _temporary_root.path_join("fresh.tscn")
	_write_scene(scene_path, "old")
	var cached_resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
	assert_true(cached_resource is PackedScene)
	_write_scene(scene_path, "new")
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root), OK)
	_finish(index)
	assert_eq(_int_field(index.query("new"), "total"), 1)
	assert_eq(_int_field(index.query("old"), "total"), 0)
	if cached_resource is PackedScene:
		var cached_scene: PackedScene = cached_resource
		assert_eq(cached_scene.get_state().get_node_groups(0), PackedStringArray(["old"]))


func test_binary_saved_scenes_are_indexed() -> void:
	_make_directory(_temporary_root)
	var root_node: Node = Node.new()
	root_node.name = "Binary"
	root_node.add_to_group(&"binary", true)
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(root_node), OK)
	root_node.free()
	var scene_path: String = _temporary_root.path_join("binary.scn")
	var _tracked: bool = _temporary_files.append(scene_path)
	assert_eq(ResourceSaver.save(scene, scene_path), OK)
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root), OK)
	_finish(index)
	assert_eq(_int_field(index.query("binary"), "total"), 1)


func test_missing_root_and_invalid_contracts_are_explicit_failures() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	for invalid_path: String in ["", "user://", "../", "res://../outside", "res://a/../b", "res://a\\b"]:
		assert_eq(index.begin_scan(invalid_path), ERR_INVALID_PARAMETER, invalid_path)
		assert_eq(_string_field(index.get_snapshot(), "status"), "failed")
		assert_false(index.advance())
	for invalid_options: Dictionary in [
		{ "unknown": 1 }, { "max_rows": 0 }, { "max_rows": 50_001 },
		{ "max_depth": -1 }, { "max_depth": 33 }, { "max_scenes": 1.0 },
	]:
		assert_eq(index.begin_scan(_FIXTURE_ROOT, invalid_options), ERR_INVALID_PARAMETER)
		assert_eq(_string_field(index.get_snapshot(), "status"), "failed")
	assert_eq(index.begin_scan(_temporary_root), ERR_CANT_OPEN)
	assert_eq(_string_field(index.get_snapshot(), "status"), "failed")


func test_missing_file_after_discovery_is_reported_without_resource_loader_errors() -> void:
	_make_directory(_temporary_root)
	var scene_path: String = _temporary_root.path_join("removed.tscn")
	_write_scene(scene_path, "removed")
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root), OK)
	for _iteration: int in range(32):
		if _int_field(index.get_snapshot(), "entry_count") > 0:
			break
		var _active: bool = index.advance(1)
	assert_eq(DirAccess.remove_absolute(scene_path), OK)
	_finish(index)
	assert_eq(_string_field(index.get_snapshot(), "status"), "partial")
	assert_gt(_issues(index.get_snapshot()).size(), 0)


func test_exact_budgets_complete_and_duplicate_declarations_do_not_consume_rows() -> void:
	_make_directory(_temporary_root)
	var text: String = '[gd_scene format=3]\n\n[node name="Root" type="Node" groups=["only", "only"]]\n'
	_write_text(_temporary_root.path_join("exact.tscn"), text)
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root, {
		"max_depth": 0, "max_entries": 1, "max_scenes": 1, "max_rows": 1,
		"max_scene_bytes": text.to_utf8_buffer().size(),
	}), OK)
	_finish(index, 1)
	assert_eq(_string_field(index.get_snapshot(), "status"), "complete")
	assert_eq(_int_field(index.get_snapshot(), "entry_count"), 1)
	assert_eq(_int_field(index.get_snapshot(), "scene_count"), 1)
	assert_eq(_int_field(index.query(), "total"), 1)
	assert_eq(_issues(index.get_snapshot()).size(), 0)


func test_diagnostics_are_bounded_and_return_defensive_copies() -> void:
	_make_directory(_temporary_root)
	for directory_number: int in range(65):
		_make_directory(_temporary_root.path_join("child_%02d" % directory_number))
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root, { "max_depth": 0 }), OK)
	_finish(index)
	var snapshot: Dictionary = index.get_snapshot()
	assert_eq(_string_field(snapshot, "status"), "partial")
	assert_eq(_issues(snapshot).size(), 64)
	assert_eq(_int_field(snapshot, "omitted_issue_count"), 1)
	var copied_issues: Array = _issues(snapshot)
	copied_issues.clear()
	assert_eq(_issues(index.get_snapshot()).size(), 64)


func test_explicit_ignored_root_is_partial_and_ignored_ancestor_is_rejected() -> void:
	_make_directory(_temporary_root)
	_make_directory(_temporary_root.path_join("nested"))
	_write_text(_temporary_root.path_join(".gdignore"), "")
	_write_scene(_temporary_root.path_join("nested/member.tscn"), "ignored")
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root), OK)
	assert_eq(_string_field(index.get_snapshot(), "status"), "partial")
	assert_false(index.advance())
	assert_eq(_int_field(index.query(), "total"), 0)
	assert_eq(index.begin_scan(_temporary_root.path_join("nested")), ERR_INVALID_PARAMETER)
	assert_eq(_string_field(index.get_snapshot(), "status"), "failed")


func test_invalid_advance_budget_fails_and_can_be_restarted() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	for budget: int in [0, -1, 4_097]:
		assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
		assert_false(index.advance(budget))
		assert_eq(_string_field(index.get_snapshot(), "status"), "failed")
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	_finish(index)
	assert_eq(_string_field(index.get_snapshot(), "status"), "complete")


func test_cancel_retains_available_rows_and_next_scan_clears_them() -> void:
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	for _iteration: int in range(256):
		if _int_field(index.get_snapshot(), "row_count") > 0:
			break
		var _active: bool = index.advance(1)
	assert_eq(_string_field(index.get_snapshot(), "status"), "scanning")
	assert_gt(_int_field(index.query(), "total"), 0)
	var rows_before_cancel: Array[Dictionary] = _rows(index.query())
	index.cancel()
	assert_eq(_string_field(index.get_snapshot(), "status"), "cancelled")
	assert_eq(_rows(index.query()), rows_before_cancel)
	assert_eq(index.begin_scan(_FIXTURE_ROOT), OK)
	assert_eq(_int_field(index.query(), "total"), 0)
	index.cancel()


func test_non_scene_resource_reports_partial_and_retains_other_scene_rows() -> void:
	_make_directory(_temporary_root)
	var wrong_type_path: String = _temporary_root.path_join("wrong_type.tscn")
	_write_text(wrong_type_path, '[gd_resource type="Resource" format=3]\n\n[resource]\n')
	_write_scene(_temporary_root.path_join("valid.tscn"), "valid")
	var index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
	assert_eq(index.begin_scan(_temporary_root), OK)
	_finish(index)
	assert_eq(_string_field(index.get_snapshot(), "status"), "partial")
	assert_eq(_int_field(index.get_snapshot(), "scene_count"), 2)
	assert_eq(_int_field(index.query("valid"), "total"), 1)
	var issues: Array = _issues(index.get_snapshot())
	assert_eq(issues.size(), 1)
	if not issues.is_empty() and issues[0] is Dictionary:
		var issue: Dictionary = issues[0]
		assert_eq(_string_field(issue, "code"), "scene_load_failed")
		assert_eq(_string_field(issue, "path"), wrong_type_path)


func _finish(index: GFSceneGroupIndex, budget: int = 64) -> void:
	for _iteration: int in range(2_000):
		if not index.advance(budget):
			return
	fail_test("扫描未在有界步数内结束。")


func _int_field(result: Dictionary, field: String) -> int:
	var value: Variant = result.get(field)
	assert_true(value is int, "%s 必须保留 int 字段类型。" % field)
	if value is int:
		var typed_value: int = value
		return typed_value
	return -1


func _string_field(result: Dictionary, field: String) -> String:
	var value: Variant = result.get(field)
	assert_true(value is String, "%s 必须保留 String 字段类型。" % field)
	if value is String:
		var typed_value: String = value
		return typed_value
	return ""


func _rows(result: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var value: Variant = result.get("rows", [])
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				rows.append(item)
	return rows


func _issues(result: Dictionary) -> Array:
	var value: Variant = result.get("issues", [])
	if value is Array:
		return value
	return []


func _make_directory(directory_path: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(directory_path), OK)
	if not _temporary_directories.has(directory_path):
		var _tracked: bool = _temporary_directories.append(directory_path)


func _write_scene(scene_path: String, group: String) -> void:
	_write_text(scene_path, '[gd_scene format=3]\n\n[node name="Root" type="Node" groups=["%s"]]\n' % group)


func _write_text(file_path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var _stored: bool = file.store_string(content)
		file.close()
	if not _temporary_files.has(file_path):
		var _tracked: bool = _temporary_files.append(file_path)
