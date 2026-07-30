## 测试 GFSceneUtility 的瞬态清理与失败回退流程。
extends GutTest


var _scene_util: SampleSceneUtility


func before_each() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch

	_scene_util = SampleSceneUtility.new()
	await Gf.register_utility(_scene_util)

	await Gf.set_architecture(arch)


func after_each() -> void:
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())
	_scene_util = null
	await get_tree().process_frame


func test_transient_cleanup() -> void:
	var model: DummyModel = DummyModel.new()
	await Gf.register_model(model)
	var utility: DummyUtility = DummyUtility.new()
	await Gf.register_utility(utility)

	_scene_util.mark_transient(DummyModel)
	_scene_util.mark_transient(DummyUtility)
	_scene_util.cleanup_transients()

	var arch: GFArchitecture = Gf.get_architecture()
	assert_null(arch.get_model(DummyModel), "标记为瞬态的 Model 应在清理后注销。")
	assert_true(model.disposed, "注销 Model 时应调用 dispose()。")
	assert_null(arch.get_utility(DummyUtility), "标记为瞬态的 Utility 应在清理后注销。")
	assert_true(utility.disposed, "注销 Utility 时应调用 dispose()。")


func test_transient_cleanup_uses_injected_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var scene_util: SampleSceneUtility = SampleSceneUtility.new()
	var local_model: DummyModel = DummyModel.new()

	await child_arch.register_utility_instance(scene_util)
	await child_arch.register_model_instance(local_model)

	scene_util.mark_transient(DummyModel)
	scene_util.cleanup_transients()

	assert_null(child_arch.get_model(DummyModel), "瞬态清理应优先作用于 Utility 注入的局部架构。")
	assert_true(local_model.disposed, "局部架构中的瞬态 Model 应被释放。")

	child_arch.dispose()
	parent_arch.dispose()


func test_unmark_transient() -> void:
	var model: DummyModel = DummyModel.new()
	await Gf.register_model(model)

	_scene_util.mark_transient(DummyModel)
	_scene_util.unmark_transient(DummyModel)
	_scene_util.cleanup_transients()

	var arch: GFArchitecture = Gf.get_architecture()
	assert_not_null(arch.get_model(DummyModel), "取消瞬态标记后不应再被清理。")
	assert_false(model.disposed, "取消标记后的 Model 不应触发 dispose()。")


func test_failed_load_restores_previous_scene_after_loading_scene() -> void:
	var loading_scene_path: String = "res://addons/gut/gui/NormalGui.tscn"

	var _load_error: Error = _scene_util.load_scene_async("res://icon.svg", loading_scene_path)

	assert_push_error("[GFSceneUtility] load_scene_async 失败：资源不是 PackedScene：res://icon.svg")
	assert_false(_is_scene_utility_loading(_scene_util), "前置校验失败后不应进入 loading 状态。")
	assert_eq(_scene_util.sync_scene_changes.size(), 0, "前置校验失败不应切到 loading scene。")
	assert_eq(_scene_util.packed_scene_changes, 0, "错误资源不应触发正式场景切换。")


func test_failed_load_preserves_transients() -> void:
	var scene_util: SampleSceneUtility = SampleSceneUtility.new()
	var model: DummyModel = DummyModel.new()
	await Gf.register_model(model)
	scene_util.mark_transient(DummyModel)

	var _load_error: Error = scene_util.load_scene_async("res://icon.svg", "res://addons/gut/gui/NormalGui.tscn")

	var arch: GFArchitecture = Gf.get_architecture()
	assert_eq(arch.get_model(DummyModel), model, "异步切场失败后不应清理仍属于当前场景的瞬态 Model。")
	assert_false(model.disposed, "异步切场失败不应触发瞬态 Model 的 dispose()。")
	assert_push_error("[GFSceneUtility] load_scene_async 失败：资源不是 PackedScene：res://icon.svg")


func test_empty_scene_path_fails_before_loading_state_changes() -> void:
	watch_signals(_scene_util)

	var _load_error: Error = _scene_util.load_scene_async("")

	assert_false(_is_scene_utility_loading(_scene_util), "空路径不应进入 loading 状态。")
	assert_signal_emitted(_scene_util, "scene_load_failed", "前置校验失败仍应发出失败信号。")
	assert_push_error("[GFSceneUtility] load_scene_async 失败：path 为空。")


func test_preloaded_scene_cache_uses_lru_eviction() -> void:
	_scene_util.max_preloaded_scene_resources = 2
	_scene_util.put_preloaded_scene("res://addons/gut/gui/NormalGui.tscn", _make_empty_scene())
	_scene_util.put_preloaded_scene("res://addons/gut/gui/MinGui.tscn", _make_empty_scene())

	var _get_preloaded_scene_result_114: Variant = _scene_util.get_preloaded_scene("res://addons/gut/gui/NormalGui.tscn")
	_scene_util.put_preloaded_scene("res://addons/gut/gui/GutRunner.tscn", _make_empty_scene())

	assert_true(_scene_util.is_scene_preloaded("res://addons/gut/gui/NormalGui.tscn"), "最近访问的预加载场景应保留。")
	assert_false(_scene_util.is_scene_preloaded("res://addons/gut/gui/MinGui.tscn"), "最久未访问的预加载场景应被淘汰。")
	assert_true(_scene_util.is_scene_preloaded("res://addons/gut/gui/GutRunner.tscn"), "新写入的预加载场景应保留。")


func test_preloaded_scene_cache_normalizes_scene_paths() -> void:
	var canonical_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var raw_path: String = " res://addons/gut/gui/../gui/NormalGui.tscn "
	var scene: PackedScene = _make_empty_scene()

	_scene_util.put_preloaded_scene(raw_path, scene)
	var snapshot: Dictionary = _scene_util.get_scene_cache_debug_snapshot()
	var preload_cache: Dictionary = GFVariantData.get_option_dictionary(snapshot, "preload_cache")

	assert_true(_scene_util.is_scene_preloaded(canonical_path), "缓存查询应接受 canonical 路径。")
	assert_eq(_scene_util.get_preloaded_scene(canonical_path), scene, "缓存读取应使用同一份 PackedScene。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(preload_cache, "temporary_paths"),
		PackedStringArray([canonical_path]),
		"缓存快照不应泄漏原始路径写法。"
	)


func test_fixed_preloaded_scene_survives_lru_eviction() -> void:
	_scene_util.max_preloaded_scene_resources = 1
	_scene_util.put_preloaded_scene("res://addons/gut/gui/NormalGui.tscn", _make_empty_scene(), true)
	_scene_util.put_preloaded_scene("res://addons/gut/gui/MinGui.tscn", _make_empty_scene())
	_scene_util.put_preloaded_scene("res://addons/gut/gui/GutRunner.tscn", _make_empty_scene())

	var snapshot: Dictionary = _scene_util.get_scene_cache_debug_snapshot()
	var preload_cache: Dictionary = GFVariantData.get_option_dictionary(snapshot, "preload_cache")

	assert_true(_scene_util.is_scene_preloaded("res://addons/gut/gui/NormalGui.tscn"), "固定缓存不应被 LRU 淘汰。")
	assert_true(_scene_util.is_preloaded_scene_fixed("res://addons/gut/gui/NormalGui.tscn"), "固定缓存状态应可查询。")
	assert_false(_scene_util.is_scene_preloaded("res://addons/gut/gui/MinGui.tscn"), "临时缓存仍应按 LRU 淘汰。")
	assert_true(GFVariantData.get_option_packed_string_array(preload_cache, "fixed_paths").has("res://addons/gut/gui/NormalGui.tscn"), "快照应包含固定缓存路径。")


func test_setting_preloaded_scene_limit_to_zero_clears_cache() -> void:
	_scene_util.put_preloaded_scene("res://addons/gut/gui/NormalGui.tscn", _make_empty_scene())

	_scene_util.max_preloaded_scene_resources = 0

	assert_false(_scene_util.is_scene_preloaded("res://addons/gut/gui/NormalGui.tscn"), "容量设为 0 时应清空预加载缓存。")


func test_load_scene_async_uses_preloaded_scene() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(_scene_util)

	var _load_error: Error = _scene_util.load_scene_async(scene_path)

	assert_eq(_scene_util.packed_scene_changes, 0, "命中预加载缓存时也不应在调用栈内同步切场。")
	assert_true(_is_scene_utility_loading(_scene_util), "安全帧切场前应保持 loading 状态。")
	assert_signal_not_emitted(_scene_util, "scene_load_completed", "安全帧切场前不应提前发出完成信号。")

	_scene_util.tick(0.0)

	assert_eq(_scene_util.packed_scene_changes, 1, "安全帧后应切换 PackedScene。")
	assert_false(_is_scene_utility_loading(_scene_util), "缓存命中完成切场后应重置 loading 状态。")
	assert_signal_emitted(_scene_util, "scene_load_completed", "缓存命中也应发出加载完成信号。")


func test_loading_scene_change_is_deferred_until_safe_tick() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loading_scene_path: String = "res://addons/gut/gui/MinGui.tscn"
	watch_signals(_scene_util)

	var _load_error: Error = _scene_util.load_scene_async(scene_path, loading_scene_path)

	assert_eq(_scene_util.sync_scene_changes.size(), 0, "loading scene 不应在调用栈内同步切换。")
	assert_signal_not_emitted(_scene_util, "loading_scene_shown", "安全帧切换前不应发出 loading scene 显示信号。")

	_scene_util.tick(0.0)

	assert_eq(_scene_util.sync_scene_changes, [loading_scene_path], "安全帧后应切到 loading scene。")
	assert_signal_emitted(_scene_util, "loading_scene_shown", "loading scene 切入后应发出显示信号。")


func test_headless_active_load_still_uses_resource_broker_and_safe_scene_change() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var load_error: Error = _scene_util.load_scene_async(scene_path)

	assert_eq(load_error, OK)
	assert_eq(
		_scene_util.threaded_requested_paths,
		PackedStringArray([scene_path]),
		"headless 活动场景加载也必须经过共享 Broker。"
	)
	assert_true(_is_scene_utility_loading(_scene_util))
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_not_emitted(_scene_util, "scene_load_completed", "安全切场前不应发出完成信号。")

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	assert_eq(_scene_util.packed_scene_changes, 1, "Broker 完成后应在安全 tick 切换 PackedScene。")
	assert_false(_is_scene_utility_loading(_scene_util))
	assert_signal_emitted(_scene_util, "scene_load_completed")


func test_failure_restore_after_loading_scene_is_deferred_until_safe_tick() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loading_scene_path: String = "res://addons/gut/gui/MinGui.tscn"

	_scene_util._begin_loading_state(scene_path, loading_scene_path, true, {}, -1.0)
	_scene_util._is_showing_loading_scene = true
	_scene_util.current_scene_path = loading_scene_path
	_scene_util.sync_scene_changes.append(loading_scene_path)

	_scene_util._fail_loading(scene_path, "[test] failed")

	assert_push_error("[test] failed")
	assert_eq(_scene_util.sync_scene_changes, [loading_scene_path], "失败恢复不应在失败调用栈内同步切回旧场景。")
	assert_true(_is_scene_utility_loading(_scene_util), "等待恢复切场时应保持 loading 状态，避免新切场插队。")

	_scene_util.tick(0.0)

	assert_eq(
		_scene_util.sync_scene_changes,
		[loading_scene_path, "res://tests/current_scene.tscn"],
		"安全帧后应恢复上一场景。"
	)
	assert_false(_is_scene_utility_loading(_scene_util), "恢复上一场景后应重置 loading 状态。")


func test_background_scene_load_can_activate_cached_scene_with_params() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())

	var preload_error: Error = _scene_util.begin_background_scene_load(scene_path, { "spawn": "door_b" })
	var activate_error: Error = _scene_util.activate_background_scene(scene_path)

	assert_eq(preload_error, OK, "后台加载应复用已有预加载缓存。")
	assert_eq(activate_error, OK, "已缓存后台场景应可激活。")

	_scene_util.tick(0.0)

	assert_eq(_scene_util.packed_scene_changes, 1, "激活后台场景应切换 PackedScene。")
	assert_eq(GFVariantData.get_option_string(_scene_util.get_current_scene_params(), "spawn"), "door_b", "激活时应应用后台加载记录的参数。")
	assert_true(_scene_util.get_background_scene_params(scene_path).is_empty(), "激活完成后应清理后台参数记录。")


func test_cancelled_scene_preload_drains_late_completion_without_cache() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var error: Error = _scene_util.preload_scene(scene_path)
	_scene_util.cancel_scene_preload(scene_path)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	var snapshot: Dictionary = _scene_util.get_scene_cache_debug_snapshot()
	var broker_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"resource_broker"
	)

	assert_eq(error, OK, "模拟预加载应成功发起。")
	assert_signal_emitted(_scene_util, "scene_preload_cancelled", "取消预加载应发出取消信号。")
	assert_false(_scene_util.is_scene_preloading(scene_path), "取消后的预加载不应再对外显示为进行中。")
	assert_false(_scene_util.is_scene_preloaded(scene_path), "取消后的迟到完成不应写入场景预加载缓存。")
	assert_eq(
		GFVariantData.get_option_int(broker_snapshot, "active_count"),
		0,
		"drain 后 Broker 不应残留活动底层请求。"
	)
	_scene_util.threaded_resource = null


func test_scene_load_completed_is_not_emitted_when_scene_change_fails() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	_scene_util.packed_scene_change_error = true
	watch_signals(_scene_util)

	var _load_error: Error = _scene_util.load_scene_async(scene_path)
	_scene_util.tick(0.0)

	assert_signal_not_emitted(_scene_util, "scene_load_completed", "切场失败时不应发出完成信号。")
	assert_signal_emitted(_scene_util, "scene_load_failed", "切场失败应发出失败信号。")


func test_scene_transition_config_can_drive_scene_load() -> void:
	var config: GFSceneTransitionConfig = GFSceneTransitionConfig.new()
	config.target_scene_path = "res://addons/gut/gui/NormalGui.tscn"
	config.cache_loaded_scene = false
	config.params = { "spawn": "door_a" }
	config.minimum_duration_seconds = 0.25
	_scene_util.put_preloaded_scene(config.target_scene_path, _make_empty_scene())

	var error: Error = _scene_util.load_scene_with_transition(config)

	assert_eq(error, OK, "场景切换配置应能发起加载。")
	var transition: Dictionary = _get_scene_utility_transition(_scene_util)
	var transition_params: Dictionary = GFVariantData.get_option_dictionary(transition, "params")

	assert_true(_is_scene_utility_loading(_scene_util), "配置化场景切换应进入加载状态。")
	assert_false(GFVariantData.get_option_bool(transition, "cache_loaded_scene"), "配置化场景切换应应用本次缓存策略。")
	assert_eq(GFVariantData.get_option_string(transition_params, "spawn"), "door_a", "配置化场景切换应应用切换参数。")
	assert_almost_eq(GFVariantData.get_option_float(transition, "minimum_duration_seconds"), 0.25, 0.001, "配置化场景切换应应用最短时长。")


func test_scene_transition_reports_immediate_target_validation_failure() -> void:
	var config: GFSceneTransitionConfig = GFSceneTransitionConfig.new()
	config.target_scene_path = "res://icon.svg"

	var error: Error = _scene_util.load_scene_with_transition(config)

	assert_eq(error, ERR_INVALID_PARAMETER, "配置入口不得把同步校验失败伪装成已成功发起。")
	assert_false(_is_scene_utility_loading(_scene_util), "校验失败不得留下活动加载状态。")
	assert_push_error("[GFSceneUtility] load_scene_async 失败：资源不是 PackedScene：res://icon.svg")


func test_scene_transition_config_serializes_params_and_minimum_duration() -> void:
	var config: GFSceneTransitionConfig = GFSceneTransitionConfig.new()
	config.target_scene_path = "res://target.tscn"
	config.params = {
		"spawn": "door_a",
		"nested": {
			"value": 1,
		},
	}
	config.minimum_duration_seconds = 0.5

	var copy: GFSceneTransitionConfig = GFSceneTransitionConfig.from_dict(config.to_dict())
	var copy_nested: Dictionary = GFVariantData.as_dictionary(copy.params["nested"])
	copy_nested["value"] = 2
	var config_nested: Dictionary = GFVariantData.as_dictionary(config.params["nested"])

	assert_eq(GFVariantData.get_option_string(copy.params, "spawn"), "door_a", "切换参数应可序列化。")
	assert_almost_eq(copy.minimum_duration_seconds, 0.5, 0.001, "最短时长应可序列化。")
	assert_eq(GFVariantData.get_option_int(config_nested, "value"), 1, "切换参数应深拷贝。")


func test_minimum_transition_duration_delays_cached_completion_and_sets_params() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	_scene_util.default_transition_minimum_seconds = 1.0

	var _load_error: Error = _scene_util.load_scene_async(scene_path, "", { "spawn": "door_a" })

	assert_true(_is_scene_utility_loading(_scene_util), "最短时长未到时应保持 loading 状态。")
	assert_eq(_scene_util.packed_scene_changes, 0, "最短时长未到时不应切换目标场景。")
	assert_true(GFVariantData.get_option_bool(_get_scene_utility_transition(_scene_util), "pending_completion"), "已加载场景应等待最短时长结束。")

	_scene_util._active_transition_started_msec = Time.get_ticks_msec() - 2000
	_scene_util.tick(0.0)
	var history: Array[Dictionary] = _scene_util.get_scene_history()
	var first_history: Dictionary = history[0]

	assert_false(_is_scene_utility_loading(_scene_util), "最短时长结束后应完成切换。")
	assert_eq(_scene_util.packed_scene_changes, 1, "应切换目标场景。")
	assert_eq(GFVariantData.get_option_string(_scene_util.get_current_scene_params(), "spawn"), "door_a", "完成后应保存当前场景参数。")
	assert_eq(history.size(), 1, "成功切换后应记录上一场景。")
	assert_eq(GFVariantData.get_option_string(first_history, "path"), "res://tests/current_scene.tscn", "历史应记录切换前场景路径。")


func test_load_previous_scene_uses_history_params() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	_scene_util._scene_history.append({
		"path": scene_path,
		"params": {
			"return_to": "hub",
		},
	})

	var error: Error = _scene_util.load_previous_scene()

	assert_eq(error, OK, "有历史场景时应能发起返回切换。")

	_scene_util.tick(0.0)

	assert_eq(_scene_util.packed_scene_changes, 1, "命中缓存的历史场景应完成切换。")
	assert_eq(GFVariantData.get_option_string(_scene_util.get_current_scene_params(), "return_to"), "hub", "返回上一场景应使用历史参数。")


func test_scene_cache_debug_snapshot_reports_cached_paths() -> void:
	_scene_util.put_preloaded_scene("res://addons/gut/gui/NormalGui.tscn", _make_empty_scene())

	var snapshot: Dictionary = _scene_util.get_scene_cache_debug_snapshot()
	var preload_cache: Dictionary = GFVariantData.get_option_dictionary(snapshot, "preload_cache")

	assert_eq(GFVariantData.get_option_int(preload_cache, "size"), 1, "调试快照应包含预加载缓存数量。")
	assert_true(GFVariantData.get_option_packed_string_array(preload_cache, "paths").has("res://addons/gut/gui/NormalGui.tscn"), "调试快照应包含缓存路径。")


func test_loading_screen_protocol_receives_progress_and_exit() -> void:
	var loading_scene: FakeLoadingScene = FakeLoadingScene.new()
	_scene_util.loading_scene_node = loading_scene
	_scene_util._loading_scene_path = "res://tests/loading.tscn"
	_scene_util._is_showing_loading_scene = true
	watch_signals(_scene_util)

	_scene_util._call_loading_scene_optional_method(_scene_util.loading_screen_fade_in_method)
	_scene_util._emit_scene_load_progress("res://tests/target.tscn", 0.5)
	_scene_util._notify_loading_scene_exit_if_needed()

	assert_true(loading_scene.faded_in, "loading scene 应收到 fade_in。")
	assert_eq(loading_scene.progress_values, [0.5], "loading scene 应收到进度回调。")
	assert_true(loading_scene.faded_out, "loading scene 应收到 fade_out。")
	assert_signal_emitted(_scene_util, "loading_scene_hidden", "退出 loading scene 应发出信号。")

	loading_scene.free()


func _make_empty_scene() -> PackedScene:
	var node: Node = Node.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


func _is_scene_utility_loading(scene_util: GFSceneUtility) -> bool:
	return GFVariantData.get_option_bool(scene_util.get_scene_cache_debug_snapshot(), "is_loading")


func _get_scene_utility_transition(scene_util: GFSceneUtility) -> Dictionary:
	return GFVariantData.get_option_dictionary(scene_util.get_scene_cache_debug_snapshot(), "transition")


# --- 内部类 ---

class DummyModel extends GFModel:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true


class DummyUtility extends GFUtility:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true


class SampleSceneUtility extends GFSceneUtility:
	var _broker: SampleSceneResourceBroker = SampleSceneResourceBroker.new()
	var current_scene_path: String = "res://tests/current_scene.tscn"
	var sync_scene_changes: Array[String] = []
	var packed_scene_changes: int = 0
	var packed_scene_change_error: bool = false
	var loading_scene_node: Node = null
	var use_fake_threaded_resource: bool:
		get:
			return _broker.use_fake_threaded_resource
		set(value):
			_broker.use_fake_threaded_resource = value
	var threaded_complete: bool:
		get:
			return _broker.threaded_complete
		set(value):
			_broker.threaded_complete = value
	var threaded_resource: Resource:
		get:
			return _broker.threaded_resource
		set(value):
			_broker.threaded_resource = value
	var threaded_requested_paths: PackedStringArray:
		get:
			return _broker.threaded_requested_paths

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)

	func _get_current_scene_path() -> String:
		return current_scene_path

	func _do_change_scene_sync(path: String) -> Error:
		sync_scene_changes.append(path)
		current_scene_path = path
		return OK

	func _do_change_scene(_scene: PackedScene) -> bool:
		if packed_scene_change_error:
			return false
		packed_scene_changes += 1
		return true

	func _get_loading_scene_node() -> Node:
		return loading_scene_node

class SampleSceneResourceBroker extends GFResourceBroker:
	var use_fake_threaded_resource: bool = false
	var threaded_complete: bool = false
	var threaded_resource: Resource = null
	var threaded_requested_paths: PackedStringArray = PackedStringArray()

	func _request_threaded_resource(path: String, type_hint: String) -> Error:
		if use_fake_threaded_resource:
			var _appended: bool = threaded_requested_paths.append(path)
			return OK
		return super._request_threaded_resource(path, type_hint)

	func _poll_threaded_resource(_path: String, previous_progress: float) -> Dictionary:
		if not use_fake_threaded_resource:
			return super._poll_threaded_resource(_path, previous_progress)
		return {
			"status": &"loaded" if threaded_complete else &"in_progress",
			"progress": 1.0 if threaded_complete else previous_progress,
			"resource": threaded_resource if threaded_complete else null,
			"has_resource": threaded_complete and threaded_resource != null,
			"error": "",
		}


class FakeLoadingScene extends Node:
	var faded_in: bool = false
	var faded_out: bool = false
	var progress_values: Array[float] = []

	func fade_in() -> void:
		faded_in = true

	func fade_out() -> void:
		faded_out = true

	func set_progress(value: float) -> void:
		progress_values.append(value)
