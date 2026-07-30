## 测试 GFAssetUtility 的缓存、异步加载与失败回调行为。
extends GutTest


var _utility: GFAssetUtility


func before_each() -> void:
	_utility = GFAssetUtility.new()
	_utility.max_cache_size = 3
	_utility.init()
	var _broker: GFResourceBroker = _utility.setup_standalone_resource_broker()


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null
	await get_tree().process_frame


func test_put_and_get_cached() -> void:
	var res: Resource = Resource.new()
	_utility.put_cache("res://test.tres", res)
	var cached: Resource = _utility.get_cached("res://test.tres")
	assert_eq(cached, res, "写入缓存后应能正常读取。")


func test_get_uncached_returns_null() -> void:
	var cached: Resource = _utility.get_cached("res://nonexistent.tres")
	assert_null(cached, "未缓存的路径应返回 null。")


func test_is_cached() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	assert_true(_utility.is_cached("res://a.tres"), "已缓存路径应返回 true。")
	assert_false(_utility.is_cached("res://b.tres"), "未缓存路径应返回 false。")


func test_get_cache_count() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())
	assert_eq(_utility.get_cache_count(), 2, "缓存数量应为 2。")


func test_cache_uses_resource_identity_key_for_uid_and_canonical_path() -> void:
	var script_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_identity.gd"
	var uid_path: String = _uid_path_for(script_path)
	var resource: Resource = Resource.new()

	_utility.put_cache(uid_path, resource)
	var cached_by_path: Resource = _utility.get_cached(script_path)
	var snapshot: Dictionary = _utility.get_debug_snapshot()
	var cache_keys: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "cache_keys")
	var identities: Dictionary = GFVariantData.get_option_dictionary(snapshot, "resource_identities")
	var identity: Dictionary = GFVariantData.get_option_dictionary(identities, uid_path)

	assert_false(uid_path.is_empty(), "测试资源应存在 Godot UID。")
	assert_eq(cached_by_path, resource, "uid:// 与 canonical res:// 应命中同一个缓存项。")
	assert_true(_utility.is_cached(uid_path), "uid:// 路径应可查询缓存命中。")
	assert_true(_utility.is_cached(script_path), "canonical res:// 路径应可查询缓存命中。")
	assert_true(cache_keys.has(uid_path), "诊断快照应以资源身份 cache_key 暴露缓存键。")
	assert_eq(GFVariantData.get_option_string(identity, "canonical_path"), script_path, "资源身份快照应保留 canonical path。")


func test_lru_eviction() -> void:
	_utility.put_cache("res://1.tres", Resource.new())
	_utility.put_cache("res://2.tres", Resource.new())
	_utility.put_cache("res://3.tres", Resource.new())
	_utility.put_cache("res://4.tres", Resource.new())

	assert_eq(_utility.get_cache_count(), 3, "超过容量后应自动淘汰最旧资源。")
	assert_false(_utility.is_cached("res://1.tres"), "最旧资源应被淘汰。")
	assert_true(_utility.is_cached("res://4.tres"), "最新资源应保留。")


func test_lru_access_refreshes_order() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())
	_utility.put_cache("res://c.tres", Resource.new())

	var _get_cached_result_61: Variant = _utility.get_cached("res://a.tres")
	_utility.put_cache("res://d.tres", Resource.new())

	assert_true(_utility.is_cached("res://a.tres"), "最近访问的资源不应被淘汰。")
	assert_false(_utility.is_cached("res://b.tres"), "最长时间未访问的资源应被淘汰。")
	assert_true(_utility.is_cached("res://c.tres"), "其他新资源应保留。")
	assert_true(_utility.is_cached("res://d.tres"), "刚写入的资源应保留。")


func test_remove_cache() -> void:
	_utility.put_cache("res://x.tres", Resource.new())
	_utility.remove_cache("res://x.tres")
	assert_false(_utility.is_cached("res://x.tres"), "remove_cache 后应不存在该条目。")
	assert_eq(_utility.get_cache_count(), 0, "移除后缓存数量应归零。")


func test_remove_cache_removes_path_from_groups() -> void:
	_utility.put_cache("res://grouped.tres", Resource.new())
	_utility.register_group_path(&"items", "res://grouped.tres", true)

	_utility.remove_cache("res://grouped.tres")

	assert_false(_utility.get_group_paths(&"items").has("res://grouped.tres"), "remove_cache 应同步移除分组路径。")
	assert_false(_utility.is_cache_pinned("res://grouped.tres"), "remove_cache 应同步清理分组 pin 状态。")


func test_remove_cache_releases_handles_for_path() -> void:
	var held_resource: Resource = Resource.new()
	var handle: GFAssetHandle = _utility.acquire_handle("res://held_remove.tres", null, &"", "", held_resource)

	_utility.remove_cache("res://held_remove.tres")

	assert_true(handle.is_released(), "remove_cache 应释放对应路径的外部句柄。")
	assert_false(handle.is_valid(), "remove_cache 后旧句柄不应继续暴露资源。")
	assert_eq(_utility.get_asset_reference_count("res://held_remove.tres"), 0, "remove_cache 应清理路径引用计数。")
	assert_false(_utility.is_cache_pinned("res://held_remove.tres"), "remove_cache 应清理句柄 pin 状态。")


func test_dispose_releases_tracked_asset_handles() -> void:
	var handle: GFAssetHandle = _utility.acquire_handle("res://held_dispose.tres", null, &"", "", Resource.new())

	_utility.dispose()

	assert_true(handle.is_released(), "dispose 应释放所有已追踪句柄。")
	assert_false(handle.is_valid(), "dispose 后外部句柄不应继续有效。")


func test_clear_cache() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())
	_utility.clear_cache()
	assert_eq(_utility.get_cache_count(), 0, "clear_cache 后缓存数量应为 0。")


func test_zero_cache_size_disables_caching() -> void:
	_utility.max_cache_size = 0
	_utility.put_cache("res://x.tres", Resource.new())
	assert_eq(_utility.get_cache_count(), 0, "max_cache_size 为 0 时不应缓存。")


func test_reducing_cache_size_evicts_immediately() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())
	_utility.put_cache("res://c.tres", Resource.new())

	_utility.max_cache_size = 1

	assert_eq(_utility.get_cache_count(), 1, "缩小缓存上限后应立即执行 LRU 淘汰。")
	assert_true(_utility.is_cached("res://c.tres"), "最近访问的缓存项应被保留。")
	assert_false(_utility.is_cached("res://a.tres"), "较旧的缓存项应被淘汰。")
	assert_false(_utility.is_cached("res://b.tres"), "较旧的缓存项应被淘汰。")


func test_pinned_cache_entry_is_not_lru_evicted() -> void:
	_utility.max_cache_size = 2
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())
	_utility.pin_cache("res://a.tres")
	_utility.put_cache("res://c.tres", Resource.new())

	assert_true(_utility.is_cached("res://a.tres"), "被 pin 的缓存项不应参与 LRU 淘汰。")
	assert_false(_utility.is_cached("res://b.tres"), "未 pin 的最旧缓存项应被淘汰。")
	assert_true(_utility.is_cache_pinned("res://a.tres"), "pin 状态应可查询。")

	_utility.unpin_cache("res://a.tres")
	assert_false(_utility.is_cache_pinned("res://a.tres"), "unpin 后应移除锁定状态。")


func test_asset_handle_pins_cache_until_release() -> void:
	_utility.max_cache_size = 1
	var held_resource: Resource = Resource.new()
	var handle: GFAssetHandle = _utility.acquire_handle("res://held.tres", null, &"", "", held_resource)

	assert_not_null(handle, "资源可用时应创建句柄。")
	assert_eq(_utility.get_asset_reference_count("res://held.tres"), 1, "句柄应增加路径引用计数。")
	assert_true(_utility.is_cache_pinned("res://held.tres"), "句柄持有期间缓存应被锁定。")

	_utility.put_cache("res://other.tres", Resource.new())

	assert_true(_utility.is_cached("res://held.tres"), "被句柄持有的资源不应被 LRU 淘汰。")
	assert_false(_utility.is_cached("res://other.tres"), "容量不足时应淘汰未锁定的新缓存。")
	assert_true(handle.release(), "第一次释放句柄应成功。")
	assert_eq(_utility.get_asset_reference_count("res://held.tres"), 0, "释放后引用计数应归零。")
	assert_false(_utility.is_cache_pinned("res://held.tres"), "释放后应解除缓存锁定。")
	assert_false(handle.is_valid(), "释放后的句柄不应继续暴露资源。")


func test_release_owner_releases_owned_asset_handles() -> void:
	var handle_owner: Node = Node.new()
	var handle: GFAssetHandle = _utility.acquire_handle("res://owned.tres", handle_owner, &"", "", Resource.new())

	var released_count: int = _utility.release_owner(handle_owner)

	assert_eq(released_count, 1, "release_owner 应释放该 owner 持有的句柄引用。")
	assert_eq(_utility.get_asset_reference_count("res://owned.tres"), 0, "owner 释放后路径引用计数应归零。")
	assert_true(handle.is_released(), "owner 释放后对应句柄也应失效。")

	handle_owner.free()


func test_preload_group_async_registers_and_unloads_group() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	completing.complete = true
	var reports: Array[Dictionary] = []

	_utility.preload_group_async(
		&"items",
		[{ "path": "res://item_a.tres", "type_hint": "Resource" }],
		func(report: Dictionary) -> void:
			reports.append(report),
		{ "pin_cache": true }
	)
	_utility.tick()

	assert_eq(reports.size(), 1, "分组预加载完成后应回调一次。")
	assert_true(_utility.get_group_paths(&"items").has("res://item_a.tres"), "预加载成功的路径应注册到分组。")
	assert_true(_utility.is_cache_pinned("res://item_a.tres"), "开启 pin_cache 时分组资源应被锁定。")

	_utility.unload_group(&"items", true)

	assert_true(_utility.get_group_paths(&"items").is_empty(), "卸载分组后路径列表应清空。")
	assert_false(_utility.is_cache_pinned("res://item_a.tres"), "卸载分组后应解除分组锁定。")
	assert_false(_utility.is_cached("res://item_a.tres"), "remove_unreferenced_cache 开启时无引用缓存应移除。")


func test_setting_cache_size_to_zero_clears_existing_cache() -> void:
	_utility.put_cache("res://a.tres", Resource.new())
	_utility.put_cache("res://b.tres", Resource.new())

	_utility.max_cache_size = 0

	assert_eq(_utility.get_cache_count(), 0, "运行中将缓存上限设为 0 时应立即清空现有缓存。")


func test_pending_load_keeps_multiple_callbacks() -> void:
	var state: CallbackState = CallbackState.new()
	var callback: Callable = func(_res: Resource) -> void:
		state.count += 1

	_utility.load_async("res://icon.svg", callback)
	_utility.load_async("res://icon.svg", func(_res: Resource) -> void:
		state.count += 1
	)

	for _i: int in range(60):
		_utility.tick()
		if state.count >= 2:
			break
		await get_tree().process_frame

	assert_eq(state.count, 2, "同一路径的并发加载请求应回调所有监听者。")


func test_load_progress_updates_signal_query_and_cache_completion() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var progress_values: Array[float] = []
	var _progress_connected: Error = _utility.asset_load_progress.connect(func(path: String, progress: float) -> void:
		if path == "res://progress_resource.tres":
			progress_values.append(progress)
	) as Error

	var loaded_resource: Array[Resource] = []
	_utility.load_async("res://progress_resource.tres", func(res: Resource) -> void:
		loaded_resource.append(res)
	)

	completing.progress = 0.35
	_utility.tick()

	assert_almost_eq(_utility.get_load_progress("res://progress_resource.tres"), 0.35, 0.001, "轮询后应能查询 pending 加载进度。")
	assert_true(_float_array_has_approx(progress_values, 0.0), "发起请求时应发出初始进度。")
	assert_true(_float_array_has_approx(progress_values, 0.35), "进度变化时应发出更新信号。")

	completing.complete = true
	_utility.tick()

	assert_eq(loaded_resource.size(), 1, "加载完成应触发回调。")
	assert_eq(loaded_resource[0], completing.loaded_resource, "完成回调应收到加载资源。")
	assert_almost_eq(_utility.get_load_progress("res://progress_resource.tres"), 1.0, 0.001, "已缓存资源进度应返回 1.0。")
	assert_true(_float_array_has_approx(progress_values, 1.0), "加载完成应发出 1.0 进度。")


func test_pending_load_rejects_same_path_with_different_type_hint() -> void:
	var tracking: TrackingAssetUtility = TrackingAssetUtility.new()
	_replace_utility(tracking)

	var results: Array[Variant] = []
	var first_callback: Callable = func(res: Resource) -> void:
		results.append(res)
	var second_callback: Callable = func(res: Resource) -> void:
		results.append(res)

	_utility.load_async("res://same_path.tres", first_callback, "Resource")
	_utility.load_async("res://same_path.tres", second_callback, "PackedScene")

	var expected_type_hints: Array[String] = ["Resource"]
	assert_push_warning("[GFAssetUtility] 已存在相同资源身份但 type_hint 不同的加载请求，已拒绝新请求：res://same_path.tres (Resource -> PackedScene)")
	assert_eq(results.size(), 1, "不同 type_hint 的第二个请求应立即回调。")
	assert_true(_is_null(results[0]), "被拒绝的 type_hint 冲突请求应收到 null。")
	assert_true(_utility.is_loading("res://same_path.tres", "Resource"), "原请求应继续保留。")
	assert_false(_utility.is_loading("res://same_path.tres", "PackedScene"), "冲突请求不应进入 pending。")
	assert_eq(tracking.requested_type_hints, expected_type_hints, "同一路径冲突请求不应重复发起 threaded request。")


func test_pending_load_allows_empty_type_hint_with_strong_type_hint() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var results: Array[Dictionary] = []

	_utility.load_async("res://compatible_path.tres", func(res: Resource) -> void:
		results.append({ "generic": res })
	)
	var packed_callback: Callable = func(res: Resource) -> void:
		results.append({ "packed": res })
	_utility.load_async("res://compatible_path.tres", packed_callback, "PackedScene")
	completing.complete = true
	_utility.tick()

	assert_eq(completing.requested_count, 1, "兼容 type_hint 的并发请求不应重复发起 threaded request。")
	assert_eq(results.size(), 2, "兼容 type_hint 的并发请求应保留各自回调。")
	assert_eq(_resource_option(results[0], "generic"), completing.loaded_resource, "空 type_hint 回调应收到加载资源。")
	assert_true(_is_null(GFVariantData.get_option_value(results[1], "packed")), "强 type_hint 回调应按自身类型要求校验资源。")


func test_failed_load_notifies_callback_with_null() -> void:
	var failing: FailingAssetUtility = FailingAssetUtility.new()
	_replace_utility(failing)
	failing.fail_path("res://simulated_failure.tres")

	var state: CallbackState = CallbackState.new()

	_utility.load_async("res://simulated_failure.tres", func(res: Resource) -> void:
		state.called = true
		state.resource = res
	)

	for _i: int in range(20):
		_utility.tick()
		if state.called:
			break
		await get_tree().process_frame

	assert_push_error("[GFAssetUtility] 异步加载失败：res://simulated_failure.tres")
	assert_true(state.called, "加载失败时也应触发回调。")
	assert_null(state.resource, "失败回调应收到 null 资源。")


func test_cancel_clears_callbacks_but_reuses_underlying_request_for_retry() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var results: Array[Dictionary] = []

	_utility.load_async("res://retry_resource.tres", func(res: Resource) -> void:
		results.append({ "old": res })
	)
	_utility.cancel("res://retry_resource.tres")

	assert_false(_utility.is_loading("res://retry_resource.tres"), "取消后外部查询不应再视为正在加载。")

	_utility.load_async("res://retry_resource.tres", func(res: Resource) -> void:
		results.append({ "new": res })
	)
	completing.complete = true
	_utility.tick()

	assert_eq(completing.requested_count, 1, "取消后重试应复用仍在进行的底层 threaded request。")
	assert_eq(results.size(), 1, "取消前的旧回调不应再触发。")
	assert_eq(_resource_option(results[0], "new"), completing.loaded_resource, "重试回调应收到完成资源。")
	assert_eq(_utility.get_cached("res://retry_resource.tres"), completing.loaded_resource, "底层请求完成后仍应写入缓存。")


func test_pending_load_coalesces_uid_and_canonical_path() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var script_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_identity.gd"
	var uid_path: String = _uid_path_for(script_path)
	var results: Array[Resource] = []

	_utility.load_async(uid_path, func(resource: Resource) -> void:
		results.append(resource)
	)
	_utility.load_async(script_path, func(resource: Resource) -> void:
		results.append(resource)
	)
	var pending_snapshot: Dictionary = _utility.get_debug_snapshot()
	var pending_cache_keys: PackedStringArray = GFVariantData.get_option_packed_string_array(pending_snapshot, "pending_cache_keys")

	assert_false(uid_path.is_empty(), "测试资源应存在 Godot UID。")
	assert_eq(completing.requested_paths, [script_path], "uid:// 与 canonical res:// 并发请求应共用底层加载。")
	assert_true(pending_cache_keys.has(uid_path), "pending 诊断应暴露统一 cache_key。")

	completing.complete = true
	_utility.tick()

	assert_eq(results.size(), 2, "合并请求完成后应回调所有监听者。")
	assert_true(_utility.is_cached(uid_path), "完成后 uid:// 查询应命中缓存。")
	assert_true(_utility.is_cached(script_path), "完成后 canonical res:// 查询应命中缓存。")


func test_cancelled_load_completion_does_not_populate_cache_without_retry() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	_utility.load_async("res://cancelled_resource.tres", func(_res: Resource) -> void:
		fail_test("取消后的旧回调不应再触发。")
	)

	_utility.cancel("res://cancelled_resource.tres")
	completing.complete = true
	_utility.tick()

	assert_false(_utility.is_cached("res://cancelled_resource.tres"), "取消后底层请求迟到完成不应污染缓存。")


func test_debug_snapshot_reports_cache_pending_and_pinned_state() -> void:
	var tracking: TrackingAssetUtility = TrackingAssetUtility.new()
	_replace_utility(tracking)
	_utility.put_cache("res://cached.tres", Resource.new())
	_utility.pin_cache("res://cached.tres")
	_utility.load_async("res://pending.tres", func(_res: Resource) -> void:
		pass
	)

	var snapshot: Dictionary = _utility.get_debug_snapshot()
	var cached_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "cached_paths")
	var pending_progress: Dictionary = GFVariantData.get_option_dictionary(snapshot, "pending_progress")

	assert_eq(GFVariantData.get_option_int(snapshot, "cache_count"), 1, "快照应报告缓存数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "pending_count"), 1, "快照应报告 pending 数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "pinned_count"), 1, "快照应报告 pinned 数量。")
	assert_true(cached_paths.has("res://cached.tres"), "快照应包含缓存路径。")
	assert_true(pending_progress.has("res://pending.tres"), "快照应包含 pending 路径进度。")
	assert_almost_eq(GFVariantData.get_option_float(pending_progress, "res://pending.tres"), 0.0, 0.001, "新建 pending 进度默认为 0.0。")


func test_serial_load_lane_queues_until_active_request_finishes() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var results: Array[String] = []
	var queued_paths: Array[String] = []
	var _queued_connected: Error = _utility.asset_load_queued.connect(func(path: String, _lane_id: StringName) -> void:
		queued_paths.append(path)
	) as Error

	_utility.load_async("res://lane_a.tres", func(_res: Resource) -> void:
		results.append("a")
	, "", { "serial_lane_id": &"level" })
	_utility.load_async("res://lane_b.tres", func(_res: Resource) -> void:
		results.append("b")
	, "", { "serial_lane_id": &"level" })

	var queued_snapshot: Dictionary = _utility.get_debug_snapshot()
	var queued_snapshot_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(queued_snapshot, "queued_paths")

	assert_eq(completing.requested_count, 1, "同一 serial lane 同时只应启动一个 threaded request。")
	assert_eq(queued_paths, ["res://lane_b.tres"], "第二个请求应进入队列。")
	assert_true(_utility.is_loading("res://lane_b.tres"), "排队请求也应被视为正在加载。")
	assert_eq(GFVariantData.get_option_int(queued_snapshot, "queued_count"), 1, "诊断快照应报告排队数量。")
	assert_true(queued_snapshot_paths.has("res://lane_b.tres"), "诊断快照应报告排队路径。")

	completing.complete = true
	_utility.tick()

	assert_eq(results, ["a"], "第一帧完成时只应回调已完成的请求。")
	assert_eq(completing.requested_count, 2, "释放 lane 后应启动下一个排队请求。")

	_utility.tick()

	assert_eq(results, ["a", "b"], "排队请求随后应正常完成。")


func test_cancel_queued_serial_load_prevents_callback_and_start() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var state: CallbackState = CallbackState.new()

	_utility.load_async("res://active.tres", func(_res: Resource) -> void:
		state.count += 1
	, "", { "serial_lane_id": &"level" })
	_utility.load_async("res://queued.tres", func(_res: Resource) -> void:
		state.count += 10
	, "", { "serial_lane_id": &"level" })
	_utility.cancel("res://queued.tres")

	assert_false(_utility.is_loading("res://queued.tres"), "取消后的排队请求不应再被视为加载中。")

	completing.complete = true
	_utility.tick()
	_utility.tick()

	assert_eq(state.count, 1, "取消后的排队请求不应触发回调。")
	assert_eq(completing.requested_paths, ["res://active.tres"], "取消后的排队请求不应启动底层 threaded request。")


func test_cache_diagnostics_are_reported_in_asset_snapshot() -> void:
	_utility.put_cache("res://cached.tres", Resource.new())
	var _hit_result: Resource = _utility.get_cached("res://cached.tres")
	var _miss_result: Resource = _utility.get_cached("res://missing.tres")

	var snapshot: Dictionary = _utility.get_debug_snapshot()
	var diagnostics: Dictionary = GFVariantData.get_option_dictionary(snapshot, "cache_diagnostics")

	assert_eq(GFVariantData.get_option_int(diagnostics, "write_count"), 1, "写入缓存应被诊断统计记录。")
	assert_eq(GFVariantData.get_option_int(diagnostics, "hit_count"), 1, "缓存命中应被诊断统计记录。")
	assert_eq(GFVariantData.get_option_int(diagnostics, "miss_count"), 1, "缓存未命中应被诊断统计记录。")


func test_preload_session_atomically_commits_target_group() -> void:
	_utility.put_cache("res://session_commit.tres", Resource.new())
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"session_target",
		[{ "path": "res://session_commit.tres" }],
		{ "plan_id": &"commit_plan", "pin_cache": true }
	)

	var session: GFAssetLoadSession = _utility.start_preload_session(asset_plan)
	var result: GFAssetLoadSessionResult = session.get_result()

	assert_not_null(result, "同步缓存命中后会话应立即产生终态结果。")
	if result == null:
		return
	assert_eq(session.get_state(), GFAssetLoadSession.State.COMMITTED)
	assert_true(result.is_successful(), "全部资源加载成功后应提交会话。")
	assert_eq(result.get_plan_id(), &"commit_plan")
	assert_eq(result.get_group_id(), &"session_target")
	assert_eq(result.get_loaded_paths(), PackedStringArray(["res://session_commit.tres"]))
	assert_eq(_utility.get_group_paths(&"session_target"), PackedStringArray(["res://session_commit.tres"]))
	assert_true(_utility.is_cache_pinned("res://session_commit.tres"), "目标计划的 pin 策略应在提交时生效。")
	assert_eq(_utility.get_active_preload_session_count(), 0, "终态会话应从 utility 活跃集合移除。")


func test_preload_session_manual_rollback_keeps_shared_cache() -> void:
	_utility.put_cache("res://session_rollback.tres", Resource.new())
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"rollback_target",
		[{ "path": "res://session_rollback.tres" }]
	)

	var session: GFAssetLoadSession = _utility.start_preload_session(
		asset_plan,
		{ "auto_commit": false, "metadata": { "request": "preview" } }
	)

	assert_eq(session.get_state(), GFAssetLoadSession.State.READY, "关闭自动提交后应停留在 READY。")
	assert_true(_utility.get_group_paths(&"rollback_target").is_empty(), "READY 前后都不应提前暴露目标分组。")
	assert_eq(_utility.get_active_preload_session_count(), 1)
	assert_true(session.rollback(&"preview_cancelled"), "READY 会话应接受首次回滚。")
	var result: GFAssetLoadSessionResult = session.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), GFAssetLoadSessionResult.STATUS_ROLLED_BACK)
	assert_eq(result.get_rollback_reason(), &"preview_cancelled")
	assert_true(result.is_cache_retained_on_rollback(), "回滚只应撤销会话分组所有权。")
	assert_true(_utility.is_cached("res://session_rollback.tres"), "共享缓存必须保留。")
	assert_true(_utility.get_group_paths(&"rollback_target").is_empty())
	assert_eq(_utility.get_active_preload_session_count(), 0)


func test_preload_session_partial_failure_never_commits_target_group() -> void:
	_utility.put_cache("res://session_valid.tres", Resource.new())
	_utility.put_cache("res://session_wrong_type.tres", Resource.new())
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"failure_target",
		[
			{ "path": "res://session_valid.tres" },
			{ "path": "res://session_wrong_type.tres", "type_hint": "Texture2D" },
		]
	)

	var session: GFAssetLoadSession = _utility.start_preload_session(asset_plan)
	assert_push_warning("[GFAssetUtility] 缓存资源类型与请求 type_hint 不匹配：res://session_wrong_type.tres (Texture2D)")
	var result: GFAssetLoadSessionResult = session.get_result()

	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), GFAssetLoadSessionResult.STATUS_FAILED)
	assert_eq(result.get_rollback_reason(), &"load_failed")
	assert_eq(result.get_loaded_paths(), PackedStringArray(["res://session_valid.tres"]))
	assert_eq(result.get_failed_paths(), PackedStringArray(["res://session_wrong_type.tres"]))
	assert_true(_utility.get_group_paths(&"failure_target").is_empty(), "部分失败不得提交目标分组。")
	assert_true(_utility.is_cached("res://session_valid.tres"), "回滚不得删除其他 owner 可能共享的缓存。")
	assert_eq(_utility.get_active_preload_session_count(), 0)


func test_preload_session_null_plan_fails_without_leaking_active_session() -> void:
	var session: GFAssetLoadSession = _utility.start_preload_session(null)
	var result: GFAssetLoadSessionResult = session.get_result()

	assert_not_null(result, "空计划应形成明确失败终态。")
	if result == null:
		return
	assert_eq(result.get_status(), GFAssetLoadSessionResult.STATUS_FAILED)
	assert_eq(result.get_rollback_reason(), &"invalid_plan")
	assert_eq(_utility.get_active_preload_session_count(), 0, "空计划不得泄漏活跃会话。")


func test_dispose_aborts_active_preload_session() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"dispose_target",
		[{ "path": "res://session_pending.tres" }]
	)
	var session: GFAssetLoadSession = _utility.start_preload_session(asset_plan)

	assert_eq(session.get_state(), GFAssetLoadSession.State.LOADING)
	assert_eq(_utility.get_active_preload_session_count(), 1)
	_utility.dispose()
	var result: GFAssetLoadSessionResult = session.get_result()

	assert_not_null(result, "dispose 应终止仍在加载的会话。")
	if result == null:
		return
	assert_eq(result.get_status(), GFAssetLoadSessionResult.STATUS_FAILED)
	assert_eq(result.get_rollback_reason(), &"asset_utility_disposed")
	assert_eq(_utility.get_active_preload_session_count(), 0)


# --- 私有/辅助方法 ---

func _replace_utility(utility: GFAssetUtility) -> void:
	if _utility != null:
		_utility.dispose()
	_utility = utility
	_utility.init()


func _resource_option(options: Dictionary, key: Variant) -> Resource:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _is_null(value: Variant) -> bool:
	return value == null


func _float_array_has_approx(values: Array[float], expected: float, tolerance: float = 0.001) -> bool:
	for value: float in values:
		if absf(value - expected) <= tolerance:
			return true
	return false


func _uid_path_for(path: String) -> String:
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid)


# --- 内部类 ---

class FailingAssetUtility extends GFAssetUtility:
	var _broker: FailingResourceBroker = FailingResourceBroker.new()

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)

	func fail_path(path: String) -> void:
		_broker.fail_path(path)


class TrackingAssetUtility extends GFAssetUtility:
	var _broker: TrackingResourceBroker = TrackingResourceBroker.new()
	var requested_type_hints: Array[String]:
		get:
			return _broker.requested_type_hints
	var progress: float:
		get:
			return _broker.progress
		set(value):
			_broker.progress = value

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)


class CompletingAssetUtility extends GFAssetUtility:
	var _broker: CompletingResourceBroker = CompletingResourceBroker.new()
	var requested_count: int:
		get:
			return _broker.requested_count
	var requested_paths: Array[String]:
		get:
			return _broker.requested_paths
	var complete: bool:
		get:
			return _broker.complete
		set(value):
			_broker.complete = value
	var progress: float:
		get:
			return _broker.progress
		set(value):
			_broker.progress = value
	var loaded_resource: Resource:
		get:
			return _broker.loaded_resource
		set(value):
			_broker.loaded_resource = value

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)


class FailingResourceBroker extends ResourceBrokerFixture:
	var _should_fail_paths: Dictionary = {}

	func fail_path(path: String) -> void:
		_should_fail_paths[path] = true

	func _request_threaded_resource(_path: String, _type_hint: String) -> Error:
		return OK

	func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
		if _should_fail_paths.has(path):
			return _make_poll_result(&"failed", previous_progress, null, "thread_load_failed")
		return _make_poll_result(&"in_progress", previous_progress)


class TrackingResourceBroker extends ResourceBrokerFixture:
	var requested_type_hints: Array[String] = []
	var progress: float = 0.0

	func _request_threaded_resource(_path: String, type_hint: String) -> Error:
		requested_type_hints.append(type_hint)
		return OK

	func _poll_threaded_resource(_path: String, _previous_progress: float) -> Dictionary:
		return _make_poll_result(&"in_progress", progress)


class CompletingResourceBroker extends ResourceBrokerFixture:
	var requested_count: int = 0
	var requested_paths: Array[String] = []
	var complete: bool = false
	var progress: float = 0.0
	var loaded_resource: Resource = Resource.new()

	func _request_threaded_resource(path: String, _type_hint: String) -> Error:
		requested_count += 1
		requested_paths.append(path)
		return OK

	func _poll_threaded_resource(_path: String, _previous_progress: float) -> Dictionary:
		if complete:
			return _make_poll_result(&"loaded", 1.0, loaded_resource)
		return _make_poll_result(&"in_progress", progress)


class ResourceBrokerFixture extends GFResourceBroker:
	func _make_poll_result(
		status: StringName,
		progress: float,
		resource: Resource = null,
		error: String = ""
	) -> Dictionary:
		return {
			"status": status,
			"progress": progress,
			"resource": resource,
			"has_resource": resource != null,
			"error": error,
		}


class CallbackState:
	extends RefCounted

	var count: int = 0
	var called: bool = false
	var resource: Resource = null
