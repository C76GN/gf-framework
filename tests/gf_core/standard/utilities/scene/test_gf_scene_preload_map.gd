## 测试 GFScenePreloadMap 与 GFSceneUtility 的图谱预加载流程。
extends GutTest


const NORMAL_GUI_SCENE: String = "res://addons/gut/gui/NormalGui.tscn"
const MIN_GUI_SCENE: String = "res://addons/gut/gui/MinGui.tscn"
const GUT_RUNNER_SCENE: String = "res://addons/gut/gui/GutRunner.tscn"


func test_preload_map_collects_neighbors_by_radius() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry("res://hub.tscn", PackedStringArray(["res://a.tscn", "res://b.tscn"])),
		_make_entry("res://a.tscn", PackedStringArray(["res://c.tscn"])),
	]

	assert_eq(
		preload_map.get_neighbor_scene_paths("res://hub.tscn", 1),
		PackedStringArray(["res://a.tscn", "res://b.tscn"]),
		"半径 1 应只返回直接相邻场景。"
	)
	assert_eq(
		preload_map.get_neighbor_scene_paths("res://hub.tscn", 2),
		PackedStringArray(["res://a.tscn", "res://b.tscn", "res://c.tscn"]),
		"半径 2 应包含下一层相邻场景。"
	)


func test_preload_map_normalizes_paths_for_lookup_and_plan() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.fixed_scene_paths = PackedStringArray([" res://ui/../global.tscn "])
	preload_map.entries = [
		_make_entry(
			"res://levels/./hub.tscn",
			PackedStringArray([
				"res://levels\\a.tscn",
				"res://levels/zone/../b.tscn",
				"res://levels/hub.tscn",
			])
		),
	]

	var entry: GFScenePreloadEntry = preload_map.get_entry(" res://levels/hub.tscn ")
	var plan: Dictionary = preload_map.get_preload_plan("res://levels/./hub.tscn", 1)

	assert_not_null(entry, "规范化后的路径应能命中条目。")
	assert_eq(
		preload_map.get_neighbor_scene_paths("res://levels/hub.tscn", 1),
		PackedStringArray(["res://levels/a.tscn", "res://levels/b.tscn"]),
		"相邻路径应统一为 canonical res:// 路径并去掉自引用。"
	)
	assert_eq(GFVariantData.get_option_string(plan, "source_path"), "res://levels/hub.tscn", "计划源路径应规范化。")
	assert_eq(GFVariantData.get_option_packed_string_array(plan, "fixed_paths"), PackedStringArray(["res://global.tscn"]), "固定路径应规范化。")


func test_preload_map_uses_resource_identity_cache_key_for_uid_aliases() -> void:
	var normal_uid_path: String = _uid_path_for(NORMAL_GUI_SCENE)
	var min_uid_path: String = _uid_path_for(MIN_GUI_SCENE)
	assert_false(normal_uid_path.is_empty(), "测试场景应存在 Godot UID。")
	assert_false(min_uid_path.is_empty(), "相邻测试场景应存在 Godot UID。")

	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.fixed_scene_paths = PackedStringArray([min_uid_path, MIN_GUI_SCENE])
	preload_map.entries = [
		_make_entry(
			normal_uid_path,
			PackedStringArray([
				MIN_GUI_SCENE,
				min_uid_path,
				NORMAL_GUI_SCENE,
			])
		),
		_make_entry(NORMAL_GUI_SCENE),
	]

	var entry: GFScenePreloadEntry = preload_map.get_entry(NORMAL_GUI_SCENE)
	var neighbors: PackedStringArray = preload_map.get_neighbor_scene_paths(NORMAL_GUI_SCENE, 1)
	var plan: Dictionary = preload_map.get_preload_plan(normal_uid_path, 1)
	var fixed_cache_keys: PackedStringArray = GFVariantData.get_option_packed_string_array(plan, "fixed_cache_keys")
	var cache_keys: PackedStringArray = GFVariantData.get_option_packed_string_array(plan, "cache_keys")
	var identities: Dictionary = GFVariantData.get_option_dictionary(plan, "resource_identities")
	var min_identity: Dictionary = GFVariantData.get_option_dictionary(identities, min_uid_path)
	var validation: Dictionary = preload_map.validate_map()
	var issue_counts_by_kind: Dictionary = GFVariantData.get_option_dictionary(validation, "issue_counts_by_kind")

	assert_not_null(entry, "canonical path 应能命中 uid:// 登记的条目。")
	assert_eq(entry.get_cache_key(), normal_uid_path, "条目应暴露统一 cache_key。")
	assert_eq(neighbors, PackedStringArray([MIN_GUI_SCENE]), "uid:// 与 canonical res:// 相邻项应按资源身份去重并剔除自引用。")
	assert_eq(GFVariantData.get_option_string(plan, "source_path"), NORMAL_GUI_SCENE, "计划源路径应返回 canonical path。")
	assert_eq(GFVariantData.get_option_string(plan, "source_cache_key"), normal_uid_path, "计划应包含源 cache_key。")
	assert_eq(GFVariantData.get_option_packed_string_array(plan, "fixed_paths"), PackedStringArray([MIN_GUI_SCENE]), "固定路径应按资源身份去重。")
	assert_true(fixed_cache_keys.has(min_uid_path), "固定路径 cache key 列表应包含 uid://。")
	assert_true(cache_keys.has(min_uid_path), "总 cache key 列表应包含 uid://。")
	assert_eq(GFVariantData.get_option_string(min_identity, "canonical_path"), MIN_GUI_SCENE, "计划身份快照应保留 canonical path。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, "duplicate_scene_path"), 1, "uid:// 和 canonical res:// 重复条目应按同一身份报告。")


func test_preload_plan_separates_fixed_and_temporary_paths() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.fixed_scene_paths = PackedStringArray(["res://global.tscn"])
	preload_map.entries = [
		_make_entry("res://hub.tscn", PackedStringArray(["res://a.tscn", "res://b.tscn"])),
		_make_entry("res://b.tscn", PackedStringArray(), true),
	]

	var plan: Dictionary = preload_map.get_preload_plan("res://hub.tscn", 1)

	assert_eq(GFVariantData.get_option_packed_string_array(plan, "fixed_paths"), PackedStringArray(["res://global.tscn", "res://b.tscn"]), "固定路径应单独归类。")
	assert_eq(GFVariantData.get_option_packed_string_array(plan, "temporary_paths"), PackedStringArray(["res://a.tscn"]), "非固定相邻场景应进入临时路径。")
	assert_eq(GFVariantData.get_option_packed_string_array(plan, "paths"), PackedStringArray(["res://global.tscn", "res://b.tscn", "res://a.tscn"]), "总路径应固定优先并去重。")


func test_preload_map_validation_reports_duplicates_and_missing_resources() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry("res://missing_scene.tscn"),
		_make_entry("res://missing_scene.tscn"),
	]

	var report: Dictionary = preload_map.validate_map({ "check_exists": true })
	var issue_counts_by_kind: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "healthy"), "重复和缺失资源应让报告不健康。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, "duplicate_scene_path"), 1, "应报告重复场景路径。")
	assert_true(issue_counts_by_kind.has("missing_scene_resource"), "应报告缺失资源。")


func test_scene_utility_preloads_map_plan() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.fixed_scene_paths = PackedStringArray([GUT_RUNNER_SCENE])
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.configure_scene_preload_map(preload_map, 1, false)

	var result: Dictionary = scene_utility.preload_scene_map_for(NORMAL_GUI_SCENE)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效图谱路径应能发起预加载。")
	assert_eq(GFVariantData.get_option_packed_string_array(result, "fixed_requested"), PackedStringArray([GUT_RUNNER_SCENE]), "固定路径应以固定缓存预加载。")
	assert_eq(GFVariantData.get_option_packed_string_array(result, "temporary_requested"), PackedStringArray([MIN_GUI_SCENE]), "相邻路径应以临时缓存预加载。")
	assert_eq(scene_utility.requested_fixed_paths, PackedStringArray([GUT_RUNNER_SCENE]), "固定路径应以 fixed=true 发起。")
	assert_eq(scene_utility.requested_temporary_paths, PackedStringArray([MIN_GUI_SCENE]), "相邻路径应以 fixed=false 发起。")
	scene_utility.dispose()


func test_scene_utility_auto_preloads_neighbors_after_successful_switch() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	var _load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	scene_utility.tick(0.0)

	assert_eq(scene_utility.packed_scene_changes, 1, "缓存命中应完成场景切换。")
	assert_eq(scene_utility.requested_temporary_paths, PackedStringArray([MIN_GUI_SCENE]), "切换成功后应自动预加载相邻场景。")
	scene_utility.dispose()


func _make_entry(
	scene_path: String,
	adjacent_paths: PackedStringArray = PackedStringArray(),
	fixed: bool = false
) -> GFScenePreloadEntry:
	var entry: GFScenePreloadEntry = GFScenePreloadEntry.new()
	entry.scene_path = scene_path
	entry.adjacent_scene_paths = adjacent_paths
	entry.fixed = fixed
	return entry


func _make_empty_scene() -> PackedScene:
	var node: Node = Node.new()
	var scene: PackedScene = PackedScene.new()
	var pack_error: Error = scene.pack(node)
	assert_eq(pack_error, OK, "测试应能打包空场景。")
	node.free()
	return scene


func _uid_path_for(path: String) -> String:
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid)


# --- 辅助类型 ---

class SceneUtilityProbe extends GFSceneUtility:
	var packed_scene_changes: int = 0
	var requested_fixed_paths: PackedStringArray = PackedStringArray()
	var requested_temporary_paths: PackedStringArray = PackedStringArray()

	func _do_change_scene(_scene: PackedScene) -> bool:
		packed_scene_changes += 1
		return true

	func preload_scene(path: String, fixed: bool = false) -> Error:
		if fixed:
			var _fixed_appended: bool = requested_fixed_paths.append(path)
		else:
			var _temporary_appended: bool = requested_temporary_paths.append(path)
		return OK
