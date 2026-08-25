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
	scene_utility.init()
	scene_utility.configure_scene_preload_map(preload_map, 1, false)

	var result: Dictionary = scene_utility.preload_scene_map_for(NORMAL_GUI_SCENE)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效图谱路径应能发起预加载。")
	assert_eq(GFVariantData.get_option_packed_string_array(result, "fixed_requested"), PackedStringArray([GUT_RUNNER_SCENE]), "固定路径应以固定缓存预加载。")
	assert_eq(GFVariantData.get_option_packed_string_array(result, "temporary_requested"), PackedStringArray([MIN_GUI_SCENE]), "相邻路径应以临时缓存预加载。")
	assert_eq(
		scene_utility.get_requested_paths(),
		PackedStringArray([GUT_RUNNER_SCENE, MIN_GUI_SCENE]),
		"图谱路径应通过共享 Broker 发起。"
	)
	scene_utility.dispose()


func test_scene_utility_auto_preloads_neighbors_after_successful_switch() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	var _load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)

	assert_eq(scene_utility.packed_scene_changes, 1, "缓存命中应完成场景切换。")
	assert_eq(scene_utility.get_requested_paths(), PackedStringArray([MIN_GUI_SCENE]), "target scene_changed 与 settle 后才应自动预加载相邻场景。")
	assert_true(scene_utility.last_request_was_exclusive(), "自动相邻预载应使用独占 admission。")
	assert_true(scene_utility.last_request_required_idle(), "自动相邻预载应从 idle 边界 admission。")
	scene_utility.dispose()


func test_auto_neighbor_batch_stops_when_started_signal_reconfigures_generation() -> void:
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(
			NORMAL_GUI_SCENE,
			PackedStringArray([MIN_GUI_SCENE, GUT_RUNNER_SCENE])
		),
	]
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())
	var started_paths: PackedStringArray = PackedStringArray()
	var connect_error: Error = scene_utility.scene_preload_started.connect(
		func(path: String) -> void:
			var _appended: bool = started_paths.append(path)
			if started_paths.size() == 1:
				scene_utility.configure_scene_preload_map(null, -1, false),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	assert_eq(load_error, OK)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)

	assert_eq(
		started_paths,
		PackedStringArray([MIN_GUI_SCENE]),
		"同步重配 generation 后外层批次必须停止登记后续邻居。"
	)
	assert_eq(
		scene_utility.get_requested_paths(),
		PackedStringArray([MIN_GUI_SCENE]),
		"旧 generation 不得为第二个邻居创建底层请求。"
	)
	assert_false(scene_utility.is_scene_preloading(MIN_GUI_SCENE))
	assert_false(scene_utility.is_scene_preloading(GUT_RUNNER_SCENE))

	scene_utility.complete_path(MIN_GUI_SCENE, _make_empty_scene())
	scene_utility.tick(0.0)
	scene_utility.dispose()


func test_auto_neighbor_waits_for_active_asset_warmup_before_broker_admission() -> void:
	var broker: SceneResourceBrokerProbe = SceneResourceBrokerProbe.new()
	broker.max_active_requests = 2
	broker.init()
	var assets: GFAssetUtility = GFAssetUtility.new()
	assets.init()
	var asset_bind_error: Error = assets.set_resource_broker(broker)
	assert_eq(asset_bind_error, OK)
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	var scene_bind_error: Error = scene_utility.set_probe_broker(broker)
	assert_eq(scene_bind_error, OK)
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	assets.load_async(
		"res://addons/gf/standard/utilities/assets/gf_asset_utility.gd",
		func(_resource: Resource) -> void:
			pass,
		"Script"
	)
	var _load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)

	assert_eq(
		broker.requested_paths,
		PackedStringArray([
			"res://addons/gf/standard/utilities/assets/gf_asset_utility.gd",
		]),
		"asset warmup 活动时 auto neighbor 只能排队，不能发起底层请求。"
	)
	assert_true(scene_utility.is_scene_preloading(MIN_GUI_SCENE))

	broker.complete_path(
		"res://addons/gf/standard/utilities/assets/gf_asset_utility.gd",
		Resource.new()
	)
	assets.tick(0.0)

	assert_eq(
		broker.requested_paths[-1],
		MIN_GUI_SCENE,
		"warmup 完成并回到 idle 后才应 admission auto neighbor。"
	)
	scene_utility.dispose()
	assets.dispose()
	broker.complete_path(MIN_GUI_SCENE, _make_empty_scene())
	broker.pump()
	broker.dispose()


func test_manual_interest_promotes_auto_neighbor_before_config_cancellation() -> void:
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	var _load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)
	var manual_error: Error = scene_utility.preload_scene(MIN_GUI_SCENE)
	assert_eq(manual_error, OK)

	scene_utility.configure_scene_preload_map(null, -1, false)

	assert_true(
		scene_utility.is_scene_preloading(MIN_GUI_SCENE),
		"手动兴趣提升后，旧 auto generation 取消不得误杀同路径请求。"
	)
	scene_utility.complete_path(MIN_GUI_SCENE, _make_empty_scene())
	scene_utility.tick(0.0)
	assert_true(scene_utility.is_scene_preloaded(MIN_GUI_SCENE))
	scene_utility.dispose()


func test_auto_interest_joining_manual_preload_has_independent_cancellation() -> void:
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	var manual_error: Error = scene_utility.preload_scene(MIN_GUI_SCENE)
	assert_eq(manual_error, OK)
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	var _load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)
	scene_utility.configure_scene_preload_map(null, -1, false)

	assert_true(
		scene_utility.is_scene_preloading(MIN_GUI_SCENE),
		"auto 加入既有手动请求后，取消 auto Lease 不得取消手动 Lease。"
	)
	assert_eq(
		scene_utility.get_requested_paths(),
		PackedStringArray([MIN_GUI_SCENE]),
		"手动与 auto 兴趣应复用同一个底层请求。"
	)
	scene_utility.complete_path(MIN_GUI_SCENE, _make_empty_scene())
	scene_utility.tick(0.0)
	assert_true(scene_utility.is_scene_preloaded(MIN_GUI_SCENE))
	scene_utility.dispose()


func test_auto_neighbor_joins_external_active_preload_without_retroactive_admission() -> void:
	await _assert_auto_neighbor_joins_external_active_preload("PackedScene")
	await _assert_auto_neighbor_joins_external_active_preload("")


func test_auto_neighbor_generation_wraps_to_positive_value() -> void:
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	scene_utility.set_auto_neighbor_generation_for_test(9_223_372_036_854_775_807)

	scene_utility.configure_scene_preload_map(null, -1, false)

	assert_eq(
		scene_utility.get_auto_neighbor_generation_for_test(),
		1,
		"generation 溢出后应回正，不能进入零或负值保留区间。"
	)
	scene_utility.dispose()


# --- 私有/辅助方法 ---

func _assert_auto_neighbor_joins_external_active_preload(external_type_hint: String) -> void:
	var broker: SceneResourceBrokerProbe = SceneResourceBrokerProbe.new()
	broker.init()
	var external_lease: GFResourceLease = broker.request(
		MIN_GUI_SCENE,
		external_type_hint,
		{ "consumer_id": &"external_preload" }
	)
	assert_eq(external_lease.get_status(), GFResourceLease.STATUS_LOADING)
	var scene_utility: SceneUtilityProbe = SceneUtilityProbe.new()
	scene_utility.init()
	var bind_error: Error = scene_utility.set_probe_broker(broker)
	assert_eq(bind_error, OK)
	var preload_map: GFScenePreloadMap = GFScenePreloadMap.new()
	preload_map.entries = [
		_make_entry(NORMAL_GUI_SCENE, PackedStringArray([MIN_GUI_SCENE])),
	]
	scene_utility.configure_scene_preload_map(preload_map)
	scene_utility.put_preloaded_scene(NORMAL_GUI_SCENE, _make_empty_scene())

	var load_error: Error = scene_utility.load_scene_async(NORMAL_GUI_SCENE)
	assert_eq(load_error, OK)
	scene_utility.tick(0.0)
	await get_tree().process_frame
	await get_tree().create_timer(0.0).timeout
	scene_utility.tick(0.0)

	var auto_lease: GFResourceLease = scene_utility.get_last_lease_for_consumer(
		&"scene_auto_neighbor"
	)
	assert_not_null(auto_lease, "自动相邻兴趣应加入外部消费者的活动请求。")
	if auto_lease != null:
		assert_eq(
			auto_lease.get_request_error(),
			OK,
			"同路径已开始加载后，admission/type_hint 约束不得让自动相邻兴趣永久失败。"
		)
		assert_eq(auto_lease.get_status(), GFResourceLease.STATUS_LOADING)
		var lease_snapshot: Dictionary = auto_lease.to_poll_result()
		assert_false(
			GFVariantData.get_option_bool(lease_snapshot, "exclusive", true),
			"已开始的共享请求不能追溯升级为独占。"
		)
		assert_false(
			GFVariantData.get_option_bool(lease_snapshot, "require_idle", true),
			"已开始的共享请求不能追溯声称从 idle admission。"
		)
	assert_eq(
		scene_utility.get_requested_paths(),
		PackedStringArray([MIN_GUI_SCENE]),
		"加入同路径请求不得重复发起底层加载。"
	)

	scene_utility.complete_path(MIN_GUI_SCENE, _make_empty_scene())
	scene_utility.tick(0.0)
	scene_utility.tick(0.0)
	assert_true(scene_utility.is_scene_preloaded(MIN_GUI_SCENE))
	external_lease.release()
	scene_utility.dispose()
	broker.dispose()


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
	var _broker: SceneResourceBrokerProbe = SceneResourceBrokerProbe.new()
	var packed_scene_changes: int = 0

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)

	func set_probe_broker(broker: SceneResourceBrokerProbe) -> Error:
		_broker = broker
		return set_resource_broker(broker)

	func complete_path(path: String, resource: Resource) -> void:
		_broker.complete_path(path, resource)

	func _do_change_scene(_scene: PackedScene) -> bool:
		packed_scene_changes += 1
		var _callback_result: Variant = (
			_auto_neighbor_scene_changed_callback.call()
			if _auto_neighbor_scene_changed_callback.is_valid()
			else null
		)
		var _confirmed: bool = _confirm_target_scene_commit()
		return true

	func _scene_root_matches_target(_scene_root: Node, _target_scene_path: String) -> bool:
		return true

	func get_requested_paths() -> PackedStringArray:
		return _broker.requested_paths

	func last_request_was_exclusive() -> bool:
		return GFVariantData.get_option_bool(_broker.last_options, "exclusive", false)

	func last_request_required_idle() -> bool:
		return GFVariantData.get_option_bool(_broker.last_options, "require_idle", false)

	func set_auto_neighbor_generation_for_test(value: int) -> void:
		_auto_neighbor_generation = value

	func get_auto_neighbor_generation_for_test() -> int:
		return _auto_neighbor_generation

	func get_last_lease_for_consumer(consumer_id: StringName) -> GFResourceLease:
		return _broker.get_last_lease_for_consumer(consumer_id)


class SceneResourceBrokerProbe extends GFResourceBroker:
	var requested_paths: PackedStringArray = PackedStringArray()
	var last_options: Dictionary = {}
	var requested_leases: Array[GFResourceLease] = []
	var _poll_results: Dictionary = {}

	func complete_path(path: String, resource: Resource) -> void:
		_poll_results[path] = {
			"status": &"loaded",
			"progress": 1.0,
			"resource": resource,
			"has_resource": resource != null,
			"error": "",
		}

	func request(path: String, type_hint: String = "", options: Dictionary = {}) -> GFResourceLease:
		last_options = options.duplicate(true)
		var lease: GFResourceLease = super.request(path, type_hint, options)
		requested_leases.append(lease)
		return lease

	func get_last_lease_for_consumer(consumer_id: StringName) -> GFResourceLease:
		for index: int in range(requested_leases.size() - 1, -1, -1):
			var lease: GFResourceLease = requested_leases[index]
			if lease != null and lease.get_consumer_id() == consumer_id:
				return lease
		return null

	func _request_threaded_resource(path: String, _type_hint: String) -> Error:
		var _appended: bool = requested_paths.append(path)
		return OK

	func _poll_threaded_resource(_path: String, previous_progress: float) -> Dictionary:
		var value: Variant = GFVariantData.get_option_value(_poll_results, _path)
		if value is Dictionary:
			var result: Dictionary = value
			return result
		return {
			"status": &"in_progress",
			"progress": previous_progress,
			"resource": null,
			"has_resource": false,
			"error": "",
		}
