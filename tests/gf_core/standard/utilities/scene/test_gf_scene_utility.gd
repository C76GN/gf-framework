## 测试 GFSceneUtility 的瞬态清理与失败回退流程。
extends GutTest


# --- 常量 ---

const _SCENE_OPERATION_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/scene/gf_scene_operation.gd"
)
const _SCENE_RESULT_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/scene/gf_scene_operation_result.gd"
)


# --- 私有变量 ---

var _scene_util: SampleSceneUtility


# --- Godot 生命周期方法 ---

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


# --- 公共方法（行为测试） ---

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


func test_preload_scene_upgrades_cached_temporary_entry_to_fixed() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())

	var error: Error = _scene_util.preload_scene(scene_path, true)

	assert_eq(error, OK, "缓存命中时 fixed 请求应成功。")
	assert_true(_scene_util.is_preloaded_scene_fixed(scene_path), "fixed=true 必须单调升级已有临时缓存。")


func test_preload_scene_upgrades_inflight_request_to_fixed() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var first_error: Error = _scene_util.preload_scene(scene_path, false)
	var second_error: Error = _scene_util.preload_scene(scene_path, true)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	assert_eq(first_error, OK, "临时预加载应成功发起。")
	assert_eq(second_error, OK, "在途 fixed 升级应合并到同一请求。")
	assert_eq(_scene_util.threaded_requested_paths.size(), 1, "合并升级不得重复发起底层加载。")
	assert_true(_scene_util.is_preloaded_scene_fixed(scene_path), "完成时必须兑现合并后的 fixed=true。")
	_scene_util.threaded_resource = null


func test_scene_path_normalization_rejects_parent_escape_above_res_root() -> void:
	var error: Error = _scene_util.preload_scene("res://../../addons/gut/gui/NormalGui.tscn")

	assert_eq(error, ERR_INVALID_PARAMETER, "越过 res:// 根的路径应 fail closed。")
	assert_true(_scene_util.threaded_requested_paths.is_empty(), "根逃逸路径不得发起底层加载。")
	assert_push_error("[GFSceneUtility] preload_scene 失败：path 为空。")


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
	_scene_util.confirm_target_scene_commit()

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
	_scene_util.confirm_target_scene_commit()

	assert_eq(_scene_util.packed_scene_changes, 1, "Broker 完成后应在安全 tick 切换 PackedScene。")
	assert_false(_is_scene_utility_loading(_scene_util))
	assert_signal_emitted(_scene_util, "scene_load_completed")


func test_failure_restore_after_loading_scene_is_deferred_until_safe_tick() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loading_scene_path: String = "res://addons/gut/gui/MinGui.tscn"

	var load_generation: int = _scene_util._begin_loading_state(
		scene_path,
		loading_scene_path,
		true,
		{},
		-1.0
	)
	assert_gt(load_generation, 0)
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
	_scene_util.confirm_target_scene_commit()

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


func test_repeated_scene_preload_cancel_emits_once_before_drain() -> void:
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var error: Error = _scene_util.preload_scene(scene_path)
	_scene_util.cancel_scene_preload(scene_path)
	_scene_util.cancel_scene_preload(scene_path)

	assert_eq(error, OK, "模拟预加载应成功发起。")
	assert_signal_emit_count(
		_scene_util,
		"scene_preload_cancelled",
		1,
		"同一路径在 drain 前重复取消只应发出一次取消信号。"
	)
	assert_false(_scene_util.is_scene_preloading(scene_path), "首次取消后请求不应再对外显示为进行中。")

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	assert_signal_emit_count(
		_scene_util,
		"scene_preload_cancelled",
		1,
		"迟到完成 drain 不应补发取消信号。"
	)
	assert_false(_scene_util.is_scene_preloaded(scene_path), "重复取消后的迟到完成不应写入缓存。")
	_scene_util.threaded_resource = null


func test_cancel_all_reentry_does_not_repeat_first_path_cancel_signal() -> void:
	var first_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var second_path: String = "res://addons/gut/gui/GutRunner.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var first_error: Error = _scene_util.preload_scene(first_path)
	var second_error: Error = _scene_util.preload_scene(second_path)
	var cancel_all_on_first: Callable = func(_cancelled_path: String) -> void:
		_scene_util.cancel_all_scene_preloads()
	var connect_error: Error = _scene_util.scene_preload_cancelled.connect(
		cancel_all_on_first,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.cancel_scene_preload(first_path)

	assert_eq(first_error, OK, "第一个模拟预加载应成功发起。")
	assert_eq(second_error, OK, "第二个模拟预加载应成功发起。")
	assert_eq(connect_error, OK, "一次性取消回调应成功连接。")
	assert_signal_emit_count(
		_scene_util,
		"scene_preload_cancelled",
		2,
		"取消信号中的 cancel_all 重入应让两个路径各终止一次。"
	)
	assert_signal_emitted_with_parameters(
		_scene_util,
		"scene_preload_cancelled",
		[first_path],
		0
	)
	assert_signal_emitted_with_parameters(
		_scene_util,
		"scene_preload_cancelled",
		[second_path],
		1
	)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	assert_signal_emit_count(
		_scene_util,
		"scene_preload_cancelled",
		2,
		"两个已取消请求 drain 后不应补发取消信号。"
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
	_scene_util.confirm_target_scene_commit()
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
	_scene_util.confirm_target_scene_commit()

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


func test_scene_request_public_contract_is_frozen() -> void:
	_assert_method_signature(
		_scene_util,
		&"load_scene_request_async",
		6,
		5,
		&"GFSceneOperation"
	)
	_assert_method_signature(
		_scene_util,
		&"preload_scene_request_async",
		4,
		3,
		&"GFSceneOperation"
	)
	assert_true(
		ResourceLoader.exists(_SCENE_OPERATION_SCRIPT_PATH, "Script"),
		"#95 必须提供共享的 GFSceneOperation 公开句柄。"
	)
	assert_true(
		ResourceLoader.exists(_SCENE_RESULT_SCRIPT_PATH, "Script"),
		"#95 必须提供共享的 GFSceneOperationResult 公开终态。"
	)
	assert_true(
		_global_script_class_exists(&"GFSceneOperation"),
		"GFSceneOperation 必须作为全局公开脚本类完成导入。"
	)
	assert_true(
		_global_script_class_exists(&"GFSceneOperationResult"),
		"GFSceneOperationResult 必须作为全局公开脚本类完成导入。"
	)
	if not _typed_scene_contract_runtime_ready():
		return

	var operation_script: GDScript = _load_gdscript(_SCENE_OPERATION_SCRIPT_PATH)
	var result_script: GDScript = _load_gdscript(_SCENE_RESULT_SCRIPT_PATH)
	assert_not_null(operation_script)
	assert_not_null(result_script)
	if operation_script == null or result_script == null:
		return

	assert_eq(String(operation_script.get_global_name()), "GFSceneOperation")
	assert_eq(String(result_script.get_global_name()), "GFSceneOperationResult")
	_assert_script_enum(operation_script, "Kind", {
		"LOAD": 0,
		"PRELOAD": 1,
	})
	_assert_script_enum(result_script, "Status", {
		"COMPLETED": 0,
		"REJECTED": 1,
		"FAILED": 2,
		"CANCELLED": 3,
		"DISPOSED": 4,
	})
	_assert_script_string_name_constants(result_script, {
		"REASON_SCENE_LOADED": &"scene_loaded",
		"REASON_SCENE_PRELOADED": &"scene_preloaded",
		"REASON_CACHE_HIT": &"cache_hit",
		"REASON_INVALID_PATH": &"invalid_path",
		"REASON_OWNER_UNAVAILABLE": &"owner_unavailable",
		"REASON_LOAD_BUSY": &"load_busy",
		"REASON_BROKER_REJECTED": &"broker_rejected",
		"REASON_RESOURCE_LOAD_FAILED": &"resource_load_failed",
		"REASON_RESOURCE_TYPE_MISMATCH": &"resource_type_mismatch",
		"REASON_SCENE_CHANGE_FAILED": &"scene_change_failed",
		"REASON_CALLER_CANCELLED": &"caller_cancelled",
		"REASON_TOKEN_CANCELLED": &"token_cancelled",
		"REASON_OWNER_RELEASED": &"owner_released",
		"REASON_PATH_CANCELLED": &"path_cancelled",
		"REASON_EXTERNAL_CANCELLED": &"external_cancelled",
		"REASON_BROKER_DISPOSED": &"broker_disposed",
		"REASON_BROKER_CANCELLED": &"broker_cancelled",
		"REASON_UTILITY_DISPOSED": &"utility_disposed",
	})

	var operation_value: Variant = operation_script.new()
	var result_value: Variant = result_script.new()
	assert_true(operation_value is RefCounted)
	assert_true(result_value is RefCounted)
	if not operation_value is Object or not result_value is Object:
		return

	var operation: Object = operation_value
	var result: Object = result_value
	_assert_object_surface(operation, [
		&"get_request_id",
		&"get_kind",
		&"get_scene_identity",
		&"get_progress_ratio",
		&"is_pending",
		&"is_completed",
		&"get_result",
		&"cancel",
	])
	assert_true(operation.has_signal(&"progressed"), "Operation 必须提供逐请求 progress 通知。")
	assert_true(operation.has_signal(&"completed"), "Operation 必须提供 exactly-once completed(result)。")
	_assert_object_surface(result, [
		&"get_status",
		&"is_successful",
		&"get_request_id",
		&"get_kind",
		&"get_scene_identity",
		&"get_scene",
		&"get_reason",
		&"get_error_code",
		&"duplicate_result",
		&"to_dict",
	])


func test_typed_scene_requests_reject_worker_thread_before_dispatch() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var caller: ThreadedSceneRequestCaller = ThreadedSceneRequestCaller.new(
		_scene_util,
		scene_path
	)
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(caller, &"call_public_requests")
	)
	assert_eq(start_error, OK, "真实 worker 应能启动。")
	if start_error != OK:
		return

	var worker_value: Variant = worker.wait_to_finish()
	assert_true(worker_value is Array, "worker 应返回两次请求结果。")
	if not worker_value is Array:
		return
	var request_values: Array = worker_value
	assert_eq(request_values.size(), 2)
	if request_values.size() != 2:
		return
	assert_true(request_values[0] == null, "off-main load 不得返回半配置句柄。")
	assert_true(request_values[1] == null, "off-main preload 不得返回半配置句柄。")
	assert_true(
		_scene_util.lease_requested_paths.is_empty(),
		"配置失败不得向 Broker 派发 Lease。"
	)


func test_typed_preload_consumers_share_physical_request_but_settle_independently() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var canonical_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var raw_path: String = " res://addons/gut/gui/../gui/NormalGui.tscn "
	var scene: PackedScene = _make_empty_scene()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = scene
	watch_signals(_scene_util)

	var first: Object = _request_typed_preload(raw_path)
	var second: Object = _request_typed_preload(canonical_path)
	if first == null or second == null:
		return
	watch_signals(first)
	watch_signals(second)

	assert_gt(_call_int(first, &"get_request_id", 0), 0)
	assert_gt(_call_int(second, &"get_request_id", 0), 0)
	assert_ne(
		_call_int(first, &"get_request_id", 0),
		_call_int(second, &"get_request_id", 0),
		"同一路径 consumer 必须拥有独立 request ID。"
	)
	_assert_operation_kind(first, "PRELOAD")
	_assert_operation_kind(second, "PRELOAD")
	_assert_scene_identity(first, canonical_path)
	_assert_scene_identity(second, canonical_path)
	assert_eq(
		_scene_util.lease_requested_paths,
		PackedStringArray([canonical_path, canonical_path]),
		"每个 typed consumer 必须向 Broker 获取独立 Lease。"
	)
	assert_eq(
		_scene_util.threaded_requested_paths,
		PackedStringArray([canonical_path]),
		"独立 Lease 必须继续共享一个物理资源请求。"
	)
	assert_signal_emit_count(
		_scene_util,
		"scene_preload_started",
		1,
		"旧 path signal 应观察聚合物理请求，而不是重复 consumer。"
	)

	assert_true(_cancel_operation(first), "首次 caller cancel 必须只终止自身 consumer。")
	assert_false(_cancel_operation(first), "重复 caller cancel 必须幂等返回 false。")
	_assert_typed_terminal(first, "CANCELLED", "REASON_CALLER_CANCELLED", ERR_SKIP)
	assert_signal_emit_count(first, "completed", 1, "caller cancel 必须 exactly-once。")
	assert_true(_call_bool(second, &"is_pending"), "peer consumer 必须继续等待物理完成。")
	assert_signal_not_emitted(
		_scene_util,
		"scene_preload_cancelled",
		"仍有 live consumer 时不得把聚合 path 生命周期报告为 cancelled。"
	)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	var second_result: Object = _assert_typed_terminal_result(
		second,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_signal_emit_count(second, "completed", 1)
	assert_true(_scene_util.is_scene_preloaded(canonical_path))
	assert_eq(_call_object(second_result, &"get_scene"), scene)
	_assert_scene_identity(second_result, canonical_path)
	assert_signal_emit_count(_scene_util, "scene_preload_completed", 1)


func test_typed_preload_all_cancelled_consumers_ignore_late_physical_completion() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var first: Object = _request_typed_preload(scene_path)
	var second: Object = _request_typed_preload(scene_path)
	if first == null or second == null:
		return
	watch_signals(first)
	watch_signals(second)

	assert_true(_cancel_operation(first))
	assert_true(_cancel_operation(second))
	_assert_typed_terminal(first, "CANCELLED", "REASON_CALLER_CANCELLED", ERR_SKIP)
	_assert_typed_terminal(second, "CANCELLED", "REASON_CALLER_CANCELLED", ERR_SKIP)
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)
	assert_signal_emit_count(
		_scene_util,
		"scene_preload_cancelled",
		1,
		"最后 consumer 结束时聚合 path 只应取消一次。"
	)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_scene_util.tick(0.0)
	var snapshot: Dictionary = _scene_util.get_scene_cache_debug_snapshot()
	var broker_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"resource_broker"
	)

	assert_false(_scene_util.is_scene_preloaded(scene_path), "无 live consumer 的迟到完成不得写缓存。")
	assert_signal_emit_count(first, "completed", 1, "迟到物理完成不得二次结算。")
	assert_signal_emit_count(second, "completed", 1, "迟到物理完成不得二次结算。")
	assert_eq(GFVariantData.get_option_int(broker_snapshot, "active_count"), 0)


func test_typed_preload_pre_cancelled_token_settles_before_broker_dispatch() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	var _cancelled: bool = cancellation_source.cancel(&"pre_cancelled")

	var operation: Object = _request_typed_preload(
		scene_path,
		false,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		cancellation_source.dispose()
		return

	assert_gt(_call_int(operation, &"get_request_id", 0), 0)
	_assert_scene_identity(operation, scene_path)
	_assert_typed_terminal(operation, "CANCELLED", "REASON_TOKEN_CANCELLED", ERR_SKIP)
	assert_true(_scene_util.lease_requested_paths.is_empty(), "pre-cancel 不得取得 Broker Lease。")
	cancellation_source.dispose()


func test_typed_preload_token_cancel_does_not_cancel_peer_consumer() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var token_operation: Object = _request_typed_preload(
		scene_path,
		false,
		null,
		cancellation_source.get_token()
	)
	var peer_operation: Object = _request_typed_preload(scene_path)
	if token_operation == null or peer_operation == null:
		cancellation_source.dispose()
		return
	watch_signals(token_operation)
	watch_signals(peer_operation)

	var _cancelled: bool = cancellation_source.cancel(&"test_token_cancelled")
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		token_operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(token_operation, "completed", 1)
	assert_true(_call_bool(peer_operation, &"is_pending"))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		peer_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	cancellation_source.dispose()


func test_typed_preload_limit_zero_completes_without_retaining_temporary_cache() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loaded_scene: PackedScene = _make_empty_scene()
	_scene_util.max_preloaded_scene_resources = 0
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = loaded_scene

	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)

	var result: Object = _assert_typed_terminal_result(
		operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	if result == null:
		return
	assert_signal_emit_count(operation, "completed", 1)
	assert_false(
		_scene_util.is_scene_preloaded(scene_path),
		"容量 0 只禁用临时缓存，不应把已完成的资源加载伪装成失败。"
	)
	assert_eq(
		_call_object(result, &"get_scene"),
		loaded_scene,
		"未保留到缓存时，typed Result 仍必须交付已加载的 PackedScene。"
	)

	var duplicate_result: Object = _call_object(result, &"duplicate_result")
	assert_not_null(duplicate_result)
	if duplicate_result == null:
		return
	assert_ne(duplicate_result, result, "duplicate_result() 必须返回新的 value 对象。")
	assert_eq(
		_call_object(duplicate_result, &"get_scene"),
		loaded_scene,
		"结果副本应共享规范 PackedScene 引用，不复制资源内容。"
	)
	_assert_scene_identity(result, scene_path)
	_assert_scene_identity(duplicate_result, scene_path)
	var original_identity: Object = _call_object(result, &"get_scene_identity")
	var duplicate_identity: Object = _call_object(
		duplicate_result,
		&"get_scene_identity"
	)
	assert_not_null(original_identity)
	assert_not_null(duplicate_identity)
	assert_ne(original_identity, duplicate_identity, "结果副本必须隔离资源身份快照。")

	var dict_value: Variant = result.call(&"to_dict")
	var duplicate_dict_value: Variant = duplicate_result.call(&"to_dict")
	assert_true(dict_value is Dictionary)
	assert_true(duplicate_dict_value is Dictionary)
	if not dict_value is Dictionary or not duplicate_dict_value is Dictionary:
		return
	var result_dict: Dictionary = dict_value
	var duplicate_dict: Dictionary = duplicate_dict_value
	var actual_keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in result_dict.keys():
		assert_true(key_value is String, "to_dict() schema key 必须是 String。")
		if key_value is String:
			var key_text: String = key_value
			var _appended: bool = actual_keys.append(key_text)
	actual_keys.sort()
	assert_eq(
		actual_keys,
		PackedStringArray([
			"error_code",
			"has_scene",
			"kind",
			"reason",
			"request_id",
			"scene",
			"scene_identity",
			"status",
			"successful",
		]),
		"to_dict() 必须冻结 exact 9-key schema。"
	)
	assert_eq(
		GFVariantData.get_option_int(result_dict, "status", -1),
		_enum_value(_SCENE_RESULT_SCRIPT_PATH, "Status", "COMPLETED")
	)
	assert_true(GFVariantData.get_option_bool(result_dict, "successful"))
	assert_eq(
		GFVariantData.get_option_int(result_dict, "request_id"),
		_call_int(operation, &"get_request_id")
	)
	assert_eq(
		GFVariantData.get_option_int(result_dict, "kind", -1),
		_enum_value(_SCENE_OPERATION_SCRIPT_PATH, "Kind", "PRELOAD")
	)
	assert_true(
		GFVariantData.get_option_value(result_dict, "scene_identity") is Dictionary
	)
	var scene_value: Variant = GFVariantData.get_option_value(result_dict, "scene")
	assert_true(scene_value is PackedScene)
	if scene_value is PackedScene:
		var result_scene: PackedScene = scene_value
		assert_eq(result_scene, loaded_scene)
	assert_true(GFVariantData.get_option_bool(result_dict, "has_scene"))
	assert_eq(
		GFVariantData.get_option_string_name(result_dict, "reason"),
		_script_string_name_constant(
			_SCENE_RESULT_SCRIPT_PATH,
			"REASON_SCENE_PRELOADED"
		)
	)
	assert_eq(GFVariantData.get_option_int(result_dict, "error_code", -1), OK)
	assert_eq(duplicate_dict, result_dict, "结果副本的诊断投影必须与原结果一致。")


func test_typed_preload_owner_release_cancels_only_owned_consumer_once() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var request_owner: Node = Node.new()
	add_child(request_owner)
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var owner_operation: Object = _request_typed_preload(
		scene_path,
		false,
		request_owner
	)
	var peer_operation: Object = _request_typed_preload(scene_path)
	if owner_operation == null or peer_operation == null:
		request_owner.queue_free()
		return
	watch_signals(owner_operation)

	request_owner.queue_free()
	await get_tree().process_frame
	_scene_util.tick(0.0)
	await get_tree().process_frame

	_assert_typed_terminal(
		owner_operation,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	assert_signal_emit_count(owner_operation, "completed", 1)
	assert_true(_call_bool(peer_operation, &"is_pending"), "owner 不得强保活或取消 peer。")

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		peer_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)


func test_typed_scene_dispose_prefreezes_all_terminals_and_rejects_reentry() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var first: Object = _request_typed_preload(scene_path)
	var second: Object = _request_typed_preload(scene_path)
	if first == null or second == null:
		return
	watch_signals(first)
	watch_signals(second)
	var reentrant_cancel_results: Array[bool] = []
	var first_completed: Callable = func(_result: Variant) -> void:
		reentrant_cancel_results.append(
			_cancel_operation(second)
		)
	var connect_error: Error = first.connect(
		&"completed",
		first_completed,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)

	_scene_util.dispose()

	_assert_typed_terminal(first, "DISPOSED", "REASON_UTILITY_DISPOSED", ERR_UNAVAILABLE)
	_assert_typed_terminal(second, "DISPOSED", "REASON_UTILITY_DISPOSED", ERR_UNAVAILABLE)
	assert_eq(
		reentrant_cancel_results,
		[false],
		"dispose 必须先冻结全部终态，再允许 completed observer 重入。"
	)
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)

	var last_disposed_request_id: int = _call_int(second, &"get_request_id", 0)
	var after_dispose: Object = _request_typed_preload(scene_path)
	if after_dispose != null:
		assert_gt(
			_call_int(after_dispose, &"get_request_id", 0),
			last_disposed_request_id,
			"dispose 后的同步终态仍必须取得唯一且单调的 request ID。"
		)
		_assert_typed_terminal(
			after_dispose,
			"DISPOSED",
			"REASON_UTILITY_DISPOSED",
			ERR_UNAVAILABLE
		)
	assert_eq(_scene_util.lease_requested_paths.size(), 2, "dispose 后不得再取得 Lease。")

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))


func test_typed_preload_invalid_path_is_synchronously_rejected_with_request_id() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var operation: Object = _request_typed_preload(
		"res://../../addons/gut/gui/NormalGui.tscn"
	)
	if operation == null:
		return

	assert_gt(_call_int(operation, &"get_request_id", 0), 0)
	_assert_typed_terminal(operation, "REJECTED", "REASON_INVALID_PATH", ERR_INVALID_PARAMETER)
	assert_true(_scene_util.lease_requested_paths.is_empty(), "invalid path 不得进入 Broker。")


func test_typed_preload_broker_admission_rejection_is_synchronous() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_request_error = ERR_CANT_OPEN

	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return

	_assert_typed_terminal(operation, "REJECTED", "REASON_BROKER_REJECTED", ERR_CANT_OPEN)
	assert_eq(_scene_util.lease_requested_paths, PackedStringArray([scene_path]))
	assert_eq(_scene_util.threaded_requested_paths, PackedStringArray([scene_path]))


func test_typed_preload_runtime_broker_failure_is_failed_once() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	watch_signals(_scene_util)

	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	assert_true(_call_bool(operation, &"is_pending"))

	_scene_util.threaded_failed = true
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_failed", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))


func test_typed_preload_resource_type_mismatch_is_failed_once() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = Resource.new()
	watch_signals(_scene_util)
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	watch_signals(operation)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_RESOURCE_TYPE_MISMATCH",
		ERR_INVALID_DATA
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_failed", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))


func test_typed_load_via_preload_shares_resource_type_mismatch_terminal() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = Resource.new()
	watch_signals(_scene_util)
	var preload_operation: Object = _request_typed_preload(scene_path)
	var load_operation: Object = _request_typed_load(scene_path)
	if preload_operation == null or load_operation == null:
		return
	watch_signals(preload_operation)
	watch_signals(load_operation)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_push_error(
		"[GFSceneUtility] 预加载完成，但目标资源不是 PackedScene：%s"
		% scene_path
	)
	_assert_typed_terminal(
		preload_operation,
		"FAILED",
		"REASON_RESOURCE_TYPE_MISMATCH",
		ERR_INVALID_DATA
	)
	_assert_typed_terminal(
		load_operation,
		"FAILED",
		"REASON_RESOURCE_TYPE_MISMATCH",
		ERR_INVALID_DATA
	)
	assert_signal_emit_count(preload_operation, "completed", 1)
	assert_signal_emit_count(load_operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_failed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_eq(_scene_util.threaded_requested_paths, PackedStringArray([scene_path]))
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_typed_load_via_preload_prefreezes_shared_runtime_failure() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	watch_signals(_scene_util)
	var preload_operation: Object = _request_typed_preload(scene_path)
	var load_operation: Object = _request_typed_load(scene_path)
	if preload_operation == null or load_operation == null:
		return
	watch_signals(preload_operation)
	watch_signals(load_operation)

	_scene_util.threaded_failed = true
	_scene_util.tick(0.0)
	assert_push_error(
		"[GFSceneUtility] 场景预加载失败：%s" % scene_path
	)
	_assert_typed_terminal(
		preload_operation,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)
	_assert_typed_terminal(
		load_operation,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)
	assert_signal_emit_count(preload_operation, "completed", 1)
	assert_signal_emit_count(load_operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_failed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_typed_load_busy_rejects_second_request_without_replacing_first() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var first_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var second_path: String = "res://addons/gut/gui/MinGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var first: Object = _request_typed_load(first_path)
	var second: Object = _request_typed_load(second_path)
	if first == null or second == null:
		return
	watch_signals(first)

	assert_true(_call_bool(first, &"is_pending"), "busy rejection 不得取代首个 load。")
	_assert_operation_kind(first, "LOAD")
	_assert_operation_kind(second, "LOAD")
	_assert_typed_terminal(second, "REJECTED", "REASON_LOAD_BUSY", ERR_BUSY)
	assert_lt(
		_call_int(first, &"get_request_id", 0),
		_call_int(second, &"get_request_id", 0),
		"busy request 仍必须在 admission 前取得稳定 ID。"
	)
	assert_eq(
		_scene_util.lease_requested_paths,
		PackedStringArray([first_path]),
		"busy rejection 不得申请第二个 Broker Lease。"
	)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_scene_util.confirm_target_scene_commit()
	_assert_typed_terminal(first, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_signal_emit_count(first, "completed", 1, "被拒绝的 peer 不得破坏首个 load。")


func test_typed_preload_reports_per_consumer_progress() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	watch_signals(operation)

	_scene_util.threaded_progress = 0.35
	_scene_util.tick(0.0)
	assert_almost_eq(_call_float(operation, &"get_progress_ratio"), 0.35, 0.001)
	assert_signal_emitted(operation, "progressed")

	_scene_util.threaded_progress = 0.75
	_scene_util.tick(0.0)
	assert_almost_eq(_call_float(operation, &"get_progress_ratio"), 0.75, 0.001)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_almost_eq(_call_float(operation, &"get_progress_ratio"), 1.0, 0.001)


func test_typed_load_completes_only_after_safe_scene_change() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var scene: PackedScene = _make_empty_scene()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = scene
	watch_signals(_scene_util)

	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	_scene_util.threaded_complete = true

	assert_true(_call_bool(operation, &"is_pending"))
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_not_emitted(operation, "completed", "Broker completion alone 不能终结 load。")

	_scene_util.tick(0.0)
	assert_true(_call_bool(operation, &"is_pending"), "change_scene 接纳后仍须等待 SceneTree.scene_changed。")
	assert_signal_not_emitted(operation, "completed", "scene_changed 前不得提前终结 typed load。")
	assert_signal_not_emitted(_scene_util, "scene_load_completed")
	_scene_util.confirm_target_scene_commit()

	var result: Object = _assert_typed_terminal_result(
		operation,
		"COMPLETED",
		"REASON_SCENE_LOADED",
		OK
	)
	assert_eq(_scene_util.packed_scene_changes, 1)
	assert_eq(_call_object(result, &"get_scene"), scene)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_completed", 1)


func test_typed_load_legacy_synchronous_override_without_hook_completes_after_return() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: SynchronousSceneCommitUtility = (
		SynchronousSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var first: Object = _request_typed_load_from(utility, scene_path)
	if first == null:
		utility.dispose()
		return
	var completion_states: Array[bool] = []
	var _completed_error: Error = first.connect(
		&"completed",
		func(_result: Variant) -> void:
			completion_states.append(utility.override_active),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	utility.tick(0.0)
	_assert_typed_terminal(first, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_eq(completion_states, [false], "legacy fallback 只能在 override 返回后结算。")
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"同步完成的 protected override 不得遗留 scene_changed observer。"
	)
	var second: Object = _request_typed_load_from(utility, scene_path)
	if second != null:
		utility.tick(0.0)
		_assert_typed_terminal(
			second,
			"COMPLETED",
			"REASON_SCENE_LOADED",
			OK
		)
	assert_eq(utility.packed_scene_changes, 2, "首个同步 commit 不得让后续 load 永久 busy。")
	utility.dispose()


func test_typed_load_sync_owner_release_reconciles_commit_without_signal() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var utility: SynchronousOwnerReleaseSceneCommitUtility = (
		SynchronousOwnerReleaseSceneCommitUtility.new()
	)
	utility.owner_to_release = request_owner
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var first: Object = _request_typed_load_from(
		utility,
		scene_path,
		"",
		{},
		-1.0,
		request_owner
	)
	if first == null:
		utility.dispose()
		request_owner.queue_free()
		return

	utility.tick(0.0)

	_assert_typed_terminal(
		first,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"owner 取消调用方后，已同步发生的物理 commit 仍须结算并退休 observer。"
	)
	var second: Object = _request_typed_load_from(utility, scene_path)
	if second != null:
		utility.tick(0.0)
		_assert_typed_terminal(
			second,
			"COMPLETED",
			"REASON_SCENE_LOADED",
			OK
		)
	assert_eq(utility.packed_scene_changes, 2, "stale caller 不得让后续 load 永久 busy。")
	utility.dispose()


func test_typed_load_failed_super_can_fall_back_to_sync_custom_commit() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: FailedSuperFallbackSceneCommitUtility = (
		FailedSuperFallbackSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return

	utility.tick(0.0)

	assert_engine_error(
		"Required object \"rp_scene\" is null.",
		"测试显式接纳 super 使用 null PackedScene 的原生拒绝诊断。"
	)
	assert_push_error("[GFSceneUtility] 切换到目标场景失败，错误码：")
	assert_true(utility.framework_change_failed)
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"失败的 super 不得遗留 wait-signal marker 阻塞后续同步 fallback。"
	)
	utility.dispose()


func test_typed_load_confirm_receipt_is_discarded_when_override_returns_false() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: ConfirmThenRejectSceneCommitUtility = (
		ConfirmThenRejectSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)
	var completion_states: Array[bool] = []
	var _completed_error: Error = operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			completion_states.append(utility.override_active),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	utility.tick(0.0)

	assert_true(utility.confirm_accepted, "有效目标应接受当前 generation 的 confirm 回执。")
	assert_true(
		utility.pending_after_confirm,
		"confirm 在 override 栈内只能记录回执，不能提前断开 observer。"
	)
	assert_eq(completion_states, [false], "失败终态必须在 override 返回后发布。")
	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_sync_scene_changed_waits_for_override_return() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: SynchronousSignalSceneCommitUtility = (
		SynchronousSignalSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	var completion_states: Array[bool] = []
	var _scene_completed_error: Error = utility.scene_load_completed.connect(
		func(_path: String, _scene: PackedScene) -> void:
			completion_states.append(utility.override_active),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var _completed_error: Error = operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			completion_states.append(utility.override_active),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	utility.tick(0.0)

	assert_true(
		utility.pending_after_signal,
		"override 栈内同步 scene_changed 只能留下当前 generation 回执。"
	)
	assert_eq(
		completion_states,
		[false, false],
		"scene 与 Operation 完成通知都必须在 override 返回后发布。"
	)
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_noop_override_does_not_claim_existing_empty_path_root() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var existing_empty_path_root: Node = Node.new()
	existing_empty_path_root.name = "GFExistingEmptyPathRoot"
	scene_tree.root.add_child(existing_empty_path_root)
	scene_tree.current_scene = existing_empty_path_root
	assert_true(existing_empty_path_root.scene_file_path.is_empty())
	var utility: NoOpSceneCommitUtility = NoOpSceneCommitUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		existing_empty_path_root.queue_free()
		return
	watch_signals(operation)

	utility.tick(0.0)

	assert_true(_call_bool(operation, &"is_pending"))
	assert_signal_not_emitted(operation, "completed")
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_true(
		utility.has_pending_target_scene_commit_for_test(),
		"no-op custom override 应继续等待合法异步 commit，不能误收切前空路径 root。"
	)
	utility.dispose()
	scene_tree.scene_changed.emit()
	assert_false(utility.has_pending_target_scene_commit_for_test())
	scene_tree.current_scene = previous_scene
	existing_empty_path_root.queue_free()


func test_typed_load_noop_override_does_not_claim_unchanged_same_path_root() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var existing_target_root: Node = Node.new()
	existing_target_root.name = "GFExistingSamePathRoot"
	scene_tree.root.add_child(existing_target_root)
	scene_tree.current_scene = existing_target_root
	var utility: NoOpSceneCommitUtility = NoOpSceneCommitUtility.new()
	utility.current_scene_path = scene_path
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		existing_target_root.queue_free()
		return
	watch_signals(operation)

	utility.tick(0.0)

	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"same-path no-op override 必须失败并退休 observer。"
	)
	var second: Object = _request_typed_load_from(utility, scene_path)
	if second != null:
		utility.tick(0.0)
		_assert_typed_terminal(
			second,
			"FAILED",
			"REASON_SCENE_CHANGE_FAILED",
			ERR_CANT_CREATE
		)
	assert_eq(utility.packed_scene_changes, 2, "no-op 失败不得让第二个请求永久 busy。")
	utility.dispose()
	scene_tree.current_scene = previous_scene
	existing_target_root.queue_free()


func test_typed_load_same_path_deferred_override_uses_wait_receipt() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = (
		"res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
	)
	var named_scene: PackedScene = load(scene_path) as PackedScene
	assert_not_null(named_scene)
	if named_scene == null:
		return
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var existing_target_root: Node = named_scene.instantiate()
	assert_not_null(existing_target_root)
	if existing_target_root == null:
		return
	existing_target_root.name = "GFDeferredSamePathExistingRoot"
	scene_tree.root.add_child(existing_target_root)
	scene_tree.current_scene = existing_target_root
	assert_eq(existing_target_root.scene_file_path, scene_path)
	var utility: SamePathDeferredSceneCommitUtility = (
		SamePathDeferredSceneCommitUtility.new()
	)
	utility.current_scene_path = scene_path
	utility.init()
	utility.put_preloaded_scene(scene_path, named_scene)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		existing_target_root.queue_free()
		return

	utility.tick(0.0)

	assert_true(utility.defer_accepted)
	assert_true(_call_bool(operation, &"is_pending"))
	assert_true(utility.has_pending_target_scene_commit_for_test())
	await scene_tree.process_frame
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_not_null(utility.committed_root)
	assert_ne(utility.committed_root, existing_target_root)
	if utility.committed_root != null:
		assert_eq(utility.committed_root.scene_file_path, scene_path)
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()
	scene_tree.current_scene = previous_scene
	existing_target_root.queue_free()


func test_typed_load_different_path_async_override_keeps_legacy_observer() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: SampleSceneUtility = SampleSceneUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return

	utility.tick(0.0)

	assert_true(_call_bool(operation, &"is_pending"))
	assert_true(
		utility.has_pending_target_scene_commit_for_test(),
		"不同路径 custom async 不要求新增 defer receipt。"
	)
	utility.confirm_target_scene_commit()
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_custom_override_claims_new_empty_path_root() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var utility: ReplacingEmptyPathSceneCommitUtility = (
		ReplacingEmptyPathSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return

	utility.tick(0.0)

	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_true(
		utility.confirm_accepted,
		"自定义 pathless commit 必须用 protected confirmation receipt 绑定当前 generation。"
	)
	assert_not_null(utility.committed_root)
	if utility.committed_root != null:
		assert_eq(scene_tree.current_scene, utility.committed_root)
		assert_true(utility.committed_root.scene_file_path.is_empty())
	scene_tree.current_scene = previous_scene
	if utility.committed_root != null:
		utility.committed_root.queue_free()
	utility.dispose()


func test_typed_load_pathless_deferred_override_requires_exact_confirm() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: PathlessDeferredSceneCommitUtility = (
		PathlessDeferredSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return

	utility.tick(0.0)

	assert_true(utility.defer_accepted)
	assert_true(_call_bool(operation, &"is_pending"))
	assert_true(utility.has_pending_target_scene_commit_for_test())
	await get_tree().process_frame
	assert_true(utility.confirm_accepted)
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_not_null(utility.committed_root)
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_pathless_wrong_root_signal_fails_without_explicit_receipt() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var requested_scene: PackedScene = _make_empty_scene()
	var wrong_scene: PackedScene = _make_empty_scene()
	assert_true(requested_scene.resource_path.is_empty())
	assert_true(wrong_scene.resource_path.is_empty())
	var utility: WrongPathlessSceneCommitUtility = (
		WrongPathlessSceneCommitUtility.new()
	)
	utility.wrong_scene = wrong_scene
	utility.init()
	utility.put_preloaded_scene(scene_path, requested_scene)
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)

	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_not_null(utility.committed_root)
	assert_eq(get_tree().current_scene, utility.committed_root)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_pathless_confirm_rejects_replaced_proven_root() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: ProvenThenReplaceSceneCommitUtility = (
		ProvenThenReplaceSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)

	assert_true(utility.confirm_accepted)
	assert_not_null(utility.proven_root)
	assert_not_null(utility.replacement_root)
	assert_ne(utility.proven_root, utility.replacement_root)
	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_false(utility.has_pending_target_scene_commit_for_test())
	utility.dispose()


func test_typed_load_sync_override_dispose_preserves_unobserved_commit() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: SynchronousDisposeSceneCommitUtility = (
		SynchronousDisposeSceneCommitUtility.new()
	)
	utility.init()
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)

	_assert_typed_terminal(
		operation,
		"DISPOSED",
		"REASON_UTILITY_DISPOSED",
		ERR_UNAVAILABLE
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_true(
		utility.has_pending_target_scene_commit_for_test(),
		"dispose 后不得用 legacy fallback 消费尚未观察到的物理 commit。"
	)
	var scene_tree: SceneTree = get_tree()
	scene_tree.scene_changed.emit()
	assert_false(utility.has_pending_target_scene_commit_for_test())
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	utility.dispose()


func test_typed_load_scene_change_failure_settles_failed_once() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	_scene_util.packed_scene_change_error = true
	watch_signals(_scene_util)

	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	assert_true(_call_bool(operation, &"is_pending"), "cache hit 也必须等待 safe-frame 切场。")

	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")


func test_typed_preload_cache_hit_is_synchronously_completed_without_lease() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var scene: PackedScene = _make_empty_scene()
	_scene_util.put_preloaded_scene(scene_path, scene)

	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	var result: Object = _assert_typed_terminal_result(
		operation,
		"COMPLETED",
		"REASON_CACHE_HIT",
		OK
	)

	assert_gt(_call_int(operation, &"get_request_id", 0), 0)
	assert_eq(_call_object(result, &"get_scene"), scene)
	assert_true(_scene_util.lease_requested_paths.is_empty())


func test_legacy_path_cancel_cancels_all_typed_consumers_once() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)

	var first: Object = _request_typed_preload(scene_path)
	var second: Object = _request_typed_preload(scene_path)
	if first == null or second == null:
		return
	watch_signals(first)
	watch_signals(second)

	_scene_util.cancel_scene_preload(scene_path)
	_scene_util.cancel_scene_preload(scene_path)

	_assert_typed_terminal(first, "CANCELLED", "REASON_PATH_CANCELLED", ERR_SKIP)
	_assert_typed_terminal(second, "CANCELLED", "REASON_PATH_CANCELLED", ERR_SKIP)
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_cancelled", 1)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_false(_scene_util.is_scene_preloaded(scene_path))
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)


func test_typed_preload_caller_cancel_recomputes_live_fixed_interest_both_ways() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var temporary_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var fixed_path: String = "res://addons/gut/gui/MinGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var cancelled_fixed: Object = _request_typed_preload(temporary_path, true)
	var surviving_temporary: Object = _request_typed_preload(temporary_path, false)
	if cancelled_fixed == null or surviving_temporary == null:
		return
	assert_true(_cancel_operation(cancelled_fixed))
	_assert_typed_terminal(
		cancelled_fixed,
		"CANCELLED",
		"REASON_CALLER_CANCELLED",
		ERR_SKIP
	)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		surviving_temporary,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_false(
		_scene_util.is_preloaded_scene_fixed(temporary_path),
		"已取消的 fixed caller interest 不得继续 pin peer 完成结果。"
	)

	_scene_util.threaded_complete = false
	var cancelled_temporary: Object = _request_typed_preload(fixed_path, false)
	var surviving_fixed: Object = _request_typed_preload(fixed_path, true)
	if cancelled_temporary == null or surviving_fixed == null:
		return
	assert_true(_cancel_operation(cancelled_temporary))
	_assert_typed_terminal(
		cancelled_temporary,
		"CANCELLED",
		"REASON_CALLER_CANCELLED",
		ERR_SKIP
	)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		surviving_fixed,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_true(
		_scene_util.is_preloaded_scene_fixed(fixed_path),
		"仍存活的 fixed peer 必须继续 pin 完成结果。"
	)


func test_typed_preload_token_cancel_recomputes_live_fixed_interest_both_ways() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var temporary_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var fixed_path: String = "res://addons/gut/gui/MinGui.tscn"
	var fixed_source: GFCancellationSource = GFCancellationSource.new()
	var temporary_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var cancelled_fixed: Object = _request_typed_preload(
		temporary_path,
		true,
		null,
		fixed_source.get_token()
	)
	var surviving_temporary: Object = _request_typed_preload(temporary_path, false)
	if cancelled_fixed == null or surviving_temporary == null:
		fixed_source.dispose()
		temporary_source.dispose()
		return
	var _fixed_cancelled: bool = fixed_source.cancel(&"fixed_interest_cancelled")
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		cancelled_fixed,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		surviving_temporary,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_false(_scene_util.is_preloaded_scene_fixed(temporary_path))

	_scene_util.threaded_complete = false
	var cancelled_temporary: Object = _request_typed_preload(
		fixed_path,
		false,
		null,
		temporary_source.get_token()
	)
	var surviving_fixed: Object = _request_typed_preload(fixed_path, true)
	if cancelled_temporary != null and surviving_fixed != null:
		var _temporary_cancelled: bool = temporary_source.cancel(
			&"temporary_interest_cancelled"
		)
		_scene_util.tick(0.0)
		_assert_typed_terminal(
			cancelled_temporary,
			"CANCELLED",
			"REASON_TOKEN_CANCELLED",
			ERR_SKIP
		)
		_scene_util.threaded_complete = true
		_scene_util.tick(0.0)
		_assert_typed_terminal(
			surviving_fixed,
			"COMPLETED",
			"REASON_SCENE_PRELOADED",
			OK
		)
		assert_true(_scene_util.is_preloaded_scene_fixed(fixed_path))
	fixed_source.dispose()
	temporary_source.dispose()


func test_typed_preload_owner_release_recomputes_live_fixed_interest_both_ways() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var temporary_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var fixed_path: String = "res://addons/gut/gui/MinGui.tscn"
	var fixed_owner: Node = Node.new()
	var temporary_owner: Node = Node.new()
	add_child(fixed_owner)
	add_child(temporary_owner)
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()

	var cancelled_fixed: Object = _request_typed_preload(
		temporary_path,
		true,
		fixed_owner
	)
	var surviving_temporary: Object = _request_typed_preload(temporary_path, false)
	if cancelled_fixed == null or surviving_temporary == null:
		fixed_owner.queue_free()
		temporary_owner.queue_free()
		return
	fixed_owner.queue_free()
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		cancelled_fixed,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		surviving_temporary,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_false(_scene_util.is_preloaded_scene_fixed(temporary_path))

	_scene_util.threaded_complete = false
	var cancelled_temporary: Object = _request_typed_preload(
		fixed_path,
		false,
		temporary_owner
	)
	var surviving_fixed: Object = _request_typed_preload(fixed_path, true)
	if cancelled_temporary == null or surviving_fixed == null:
		temporary_owner.queue_free()
		return
	temporary_owner.queue_free()
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		cancelled_temporary,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		surviving_fixed,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_true(_scene_util.is_preloaded_scene_fixed(fixed_path))


func test_typed_preload_peer_survives_promoted_secondary_auto_lease_cancel() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var primary: Object = _request_typed_preload(scene_path)
	if primary == null:
		return
	var request: Dictionary = _scene_util._get_preload_request(scene_path)
	var secondary_lease: GFResourceLease = _scene_util._request_scene_consumer_lease(
		scene_path,
		0,
		&"auto_neighbor"
	)
	assert_not_null(secondary_lease)
	if secondary_lease == null:
		return
	request["secondary_auto_neighbor_leases"] = { "77": secondary_lease }
	request["secondary_auto_neighbor_fixed"] = { "77": false }

	assert_true(_cancel_operation(primary))
	_assert_typed_terminal(
		primary,
		"CANCELLED",
		"REASON_CALLER_CANCELLED",
		ERR_SKIP
	)
	var peer: Object = _request_typed_preload(scene_path)
	if peer == null:
		return
	_scene_util.threaded_complete = true
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return
	broker.pump()
	assert_true(secondary_lease.is_terminal())
	_scene_util._cancel_secondary_auto_neighbor_leases(
		request,
		&"auto_neighbor_generation_superseded"
	)
	assert_true(_call_bool(peer, &"is_pending"))

	_scene_util.tick(0.0)
	_assert_typed_terminal(
		peer,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)


func test_preload_promotion_prefers_fresh_live_lease_over_stale_terminal_reason() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	var stale_operation: Object = _request_typed_preload(scene_path)
	if stale_operation == null:
		return
	var request: Dictionary = _scene_util._get_preload_request(scene_path)
	var stale_lease: GFResourceLease = (
		_scene_util._get_preload_request_operation(request)
	)
	assert_not_null(stale_lease)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if stale_lease == null or broker == null:
		return
	broker.cancel_all(&"external")
	var fresh_lease: GFResourceLease = _scene_util._request_scene_consumer_lease(
		scene_path,
		0,
		&"auto_neighbor"
	)
	assert_not_null(fresh_lease)
	if fresh_lease == null:
		return
	request["secondary_auto_neighbor_leases"] = { "fresh": fresh_lease }

	_scene_util._promote_preload_request_operation(request, null)
	assert_same(
		_scene_util._get_preload_request_operation(request),
		fresh_lease,
		"promotion 必须优先选择 live peer，不能让 stale CANCELLED lease 污染 aggregate。"
	)
	_scene_util.cancel_scene_preload(scene_path)


func test_external_cancelled_aggregate_is_retired_before_later_peer_admission() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var cancelled_operation: Object = _request_typed_preload(scene_path)
	if cancelled_operation == null:
		return
	watch_signals(cancelled_operation)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return

	broker.cancel_all(&"external")
	var later_peer: Object = _request_typed_preload(scene_path)
	if later_peer == null:
		return
	watch_signals(later_peer)
	_assert_typed_terminal(
		cancelled_operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(cancelled_operation, "completed", 1)
	assert_true(
		_call_bool(later_peer, &"is_pending"),
		"external cancel 之后接纳的新 peer 不得继承旧 generation 的取消终态。"
	)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		later_peer,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_signal_emit_count(later_peer, "completed", 1)


func test_cancelled_outer_preload_lease_never_attaches_reentrant_fresh_aggregate() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var inner_operations: Array[Object] = []
	_scene_util._broker.request_callback = func() -> void:
		var broker: GFResourceBroker = _scene_util.get_resource_broker()
		if broker != null:
			broker.cancel_all(&"external")
		inner_operations.append(_request_typed_preload(scene_path))

	var outer_operation: Object = _request_typed_preload(scene_path)
	if outer_operation == null:
		return
	_assert_typed_terminal(
		outer_operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_eq(inner_operations.size(), 1)
	if inner_operations.is_empty():
		return
	var inner_operation: Object = inner_operations[0]
	assert_not_null(inner_operation)
	if inner_operation == null:
		return
	watch_signals(inner_operation)
	assert_true(_call_bool(inner_operation, &"is_pending"))
	var request: Dictionary = _scene_util._get_preload_request(scene_path)
	var aggregate_lease: GFResourceLease = (
		_scene_util._get_preload_request_operation(request)
	)
	assert_not_null(aggregate_lease)
	if aggregate_lease != null:
		assert_true(
			aggregate_lease.get_status() in [
				GFResourceLease.STATUS_QUEUED,
				GFResourceLease.STATUS_LOADING,
			]
		)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		inner_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_signal_emit_count(inner_operation, "completed", 1)


func test_cancelled_outer_load_lease_never_attaches_reentrant_fresh_aggregate() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var original_preload: Object = _request_typed_preload(scene_path)
	if original_preload == null:
		return
	var inner_operations: Array[Object] = []
	_scene_util._broker.request_callback = func() -> void:
		var broker: GFResourceBroker = _scene_util.get_resource_broker()
		if broker != null:
			broker.cancel_all(&"external")
		inner_operations.append(_request_typed_preload(scene_path))

	var load_operation: Object = _request_typed_load(scene_path)
	if load_operation == null:
		return
	_assert_typed_terminal(
		load_operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	_assert_typed_terminal(
		original_preload,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_false(_is_scene_utility_loading(_scene_util))
	assert_eq(inner_operations.size(), 1)
	if inner_operations.is_empty():
		return
	var inner_operation: Object = inner_operations[0]
	assert_not_null(inner_operation)
	if inner_operation == null:
		return
	assert_true(_call_bool(inner_operation, &"is_pending"))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		inner_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)


func test_preload_failure_retires_old_lease_before_listener_retry() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var failed_operation: Object = _request_typed_preload(scene_path)
	if failed_operation == null:
		return
	watch_signals(failed_operation)
	var failed_request: Dictionary = _scene_util._get_preload_request(scene_path)
	var failed_lease: GFResourceLease = (
		_scene_util._get_preload_request_operation(failed_request)
	)
	assert_not_null(failed_lease)
	if failed_lease == null:
		return
	var released_at_signal: Array[bool] = []
	var retry_operations: Array[Object] = []
	var retry_from_failure: Callable = func(_path: String) -> void:
		released_at_signal.append(failed_lease.is_released())
		_scene_util.threaded_failed = false
		retry_operations.append(_request_typed_preload(scene_path))
	var _failed_signal_error: Error = _scene_util.scene_preload_failed.connect(
		retry_from_failure,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	_scene_util.threaded_failed = true

	_scene_util.tick(0.0)
	_assert_typed_terminal(
		failed_operation,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)
	assert_eq(released_at_signal, [true])
	assert_eq(retry_operations.size(), 1)
	if retry_operations.is_empty():
		return
	var retry_operation: Object = retry_operations[0]
	assert_not_null(retry_operation)
	if retry_operation == null:
		return
	watch_signals(retry_operation)
	assert_true(_call_bool(retry_operation, &"is_pending"))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		retry_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_signal_emit_count(retry_operation, "completed", 1)


func test_legacy_fixed_cache_callback_removal_falls_through_to_broker() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	var remove_from_fixed_add: Callable = func(path: String, fixed: bool) -> void:
		if fixed:
			_scene_util.remove_preloaded_scene(path)
	var _cache_added_error: Error = _scene_util.scene_cache_added.connect(
		remove_from_fixed_add,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	assert_eq(_scene_util.preload_scene(scene_path, true), OK)
	assert_false(_scene_util.is_scene_preloaded(scene_path))
	assert_true(_scene_util.is_scene_preloading(scene_path))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_true(_scene_util.is_preloaded_scene_fixed(scene_path))


func test_typed_direct_load_maps_external_broker_cancel_and_drains_late_settlement() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)
	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return

	broker.cancel_all(&"external")
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")
	assert_eq(_scene_util.packed_scene_changes, 0)

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_signal_emit_count(operation, "completed", 1, "Broker 迟到物理完成不得二次结算。")
	assert_eq(_scene_util.packed_scene_changes, 0)
	var snapshot: Dictionary = broker.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 0)


func test_typed_preload_maps_broker_dispose_and_never_caches_late_resource() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return

	broker.dispose()
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_BROKER_DISPOSED",
		ERR_SKIP
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_cancelled", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_signal_emit_count(operation, "completed", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))


func test_typed_load_via_preload_maps_one_external_cancel_for_both_consumers() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)
	var preload_operation: Object = _request_typed_preload(scene_path)
	var load_operation: Object = _request_typed_load(scene_path)
	if preload_operation == null or load_operation == null:
		return
	watch_signals(preload_operation)
	watch_signals(load_operation)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return
	assert_eq(
		_scene_util.threaded_requested_paths,
		PackedStringArray([scene_path]),
		"load-via-preload 必须共享同一路径物理请求。"
	)

	broker.cancel_all(&"external")
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		preload_operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	_assert_typed_terminal(
		load_operation,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(preload_operation, "completed", 1)
	assert_signal_emit_count(load_operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_preload_cancelled", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_signal_emit_count(preload_operation, "completed", 1)
	assert_signal_emit_count(load_operation, "completed", 1)
	assert_false(_scene_util.is_scene_preloaded(scene_path))


func test_external_cancel_reason_survives_aggregate_consumer_cancel_before_poll() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var aggregate_consumer: Object = _request_typed_preload(scene_path)
	var peer: Object = _request_typed_preload(scene_path)
	if aggregate_consumer == null or peer == null:
		return
	watch_signals(aggregate_consumer)
	watch_signals(peer)
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	assert_not_null(broker)
	if broker == null:
		return

	broker.cancel_all(&"external")
	assert_true(_cancel_operation(aggregate_consumer))
	_assert_typed_terminal(
		aggregate_consumer,
		"CANCELLED",
		"REASON_CALLER_CANCELLED",
		ERR_SKIP
	)
	assert_true(_call_bool(peer, &"is_pending"))

	_scene_util.tick(0.0)
	_assert_typed_terminal(
		peer,
		"CANCELLED",
		"REASON_EXTERNAL_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(aggregate_consumer, "completed", 1)
	assert_signal_emit_count(peer, "completed", 1)


func test_typed_unknown_broker_cancel_reason_is_bounded_to_public_fallback() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	var broker: GFResourceBroker = _scene_util.get_resource_broker()
	if broker == null:
		return
	broker.cancel_all(&"arbitrary_untrusted_reason")
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_BROKER_CANCELLED",
		ERR_SKIP
	)


func test_typed_cached_load_polls_token_after_synchronous_final_progress() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(_scene_util)
	var cancel_from_progress: Callable = func(
		_progress_path: String,
		progress: float
	) -> void:
		if progress >= 1.0:
			var _cancelled: bool = cancellation_source.cancel(&"final_progress")
	var _progress_error: Error = _scene_util.scene_load_progress.connect(
		cancel_from_progress,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	var operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	_scene_util.tick(0.0)
	_scene_util.confirm_target_scene_commit()
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")


func test_typed_direct_load_polls_token_after_final_progress_reentry() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	watch_signals(operation)
	var cancel_from_progress: Callable = func(progress: float) -> void:
		if progress >= 1.0:
			var _cancelled: bool = cancellation_source.cancel(&"final_progress")
	var _progress_error: Error = operation.connect(
		&"progressed",
		cancel_from_progress,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_typed_load_via_preload_polls_token_after_final_progress_reentry() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var preload_operation: Object = _request_typed_preload(scene_path)
	var load_operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if preload_operation == null or load_operation == null:
		return
	watch_signals(load_operation)
	var cancel_from_progress: Callable = func(progress: float) -> void:
		if progress >= 1.0:
			var _cancelled: bool = cancellation_source.cancel(&"final_progress")
	var _progress_error: Error = load_operation.connect(
		&"progressed",
		cancel_from_progress,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		preload_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	_assert_typed_terminal(
		load_operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(load_operation, "completed", 1)
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_typed_direct_load_publishes_final_progress_before_terminal_signals() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var order: Array[StringName] = []
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	var _operation_progress_error: Error = operation.connect(
		&"progressed",
		func(_progress: float) -> void:
			order.append(&"operation_progress")
	) as Error
	var _scene_progress_error: Error = _scene_util.scene_load_progress.connect(
		func(_path: String, _progress: float) -> void:
			order.append(&"scene_progress")
	) as Error
	var _scene_completed_error: Error = _scene_util.scene_load_completed.connect(
		func(_path: String, _scene: PackedScene) -> void:
			order.append(&"scene_completed")
	) as Error
	var _operation_completed_error: Error = operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			order.append(&"operation_completed")
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_eq(
		order,
		[&"operation_progress", &"scene_progress"],
		"物理 load 完成必须先发布 1.0 progress，scene_changed 前不得发布终态。"
	)
	_scene_util.confirm_target_scene_commit()
	assert_eq(
		order,
		[
			&"operation_progress",
			&"scene_progress",
			&"scene_completed",
			&"operation_completed",
		]
	)
	assert_almost_eq(_call_float(operation, &"get_progress_ratio"), 1.0, 0.001)


func test_typed_preload_publishes_final_progress_before_terminal_signals() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var order: Array[StringName] = []
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	var _operation_progress_error: Error = operation.connect(
		&"progressed",
		func(_progress: float) -> void:
			order.append(&"operation_progress")
	) as Error
	var _scene_progress_error: Error = _scene_util.scene_preload_progress.connect(
		func(_path: String, _progress: float) -> void:
			order.append(&"scene_progress")
	) as Error
	var _scene_completed_error: Error = _scene_util.scene_preload_completed.connect(
		func(_path: String, _scene: PackedScene) -> void:
			order.append(&"scene_completed")
	) as Error
	var _operation_completed_error: Error = operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			order.append(&"operation_completed")
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_eq(
		order,
		[
			&"operation_progress",
			&"scene_progress",
			&"scene_completed",
			&"operation_completed",
		]
	)
	assert_almost_eq(_call_float(operation, &"get_progress_ratio"), 1.0, 0.001)


func test_typed_preload_terminal_success_reentry_does_not_repoll_aggregate() -> void:
	_assert_terminal_preload_progress_reentry_is_bounded(
		_make_empty_scene(),
		false,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)


func test_typed_preload_terminal_failure_reentry_does_not_repoll_aggregate() -> void:
	_assert_terminal_preload_progress_reentry_is_bounded(
		null,
		true,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)


func test_typed_preload_type_mismatch_reentry_does_not_repoll_aggregate() -> void:
	var wrong_resource: Resource = Resource.new()
	assert_not_null(wrong_resource)
	if wrong_resource == null:
		return
	_assert_terminal_preload_progress_reentry_is_bounded(
		wrong_resource,
		false,
		"FAILED",
		"REASON_RESOURCE_TYPE_MISMATCH",
		ERR_INVALID_DATA
	)


func test_typed_preload_terminal_broker_callback_cannot_repoll_same_aggregate() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	var nested_operations: Array[GFSceneOperation] = []
	_scene_util._broker.poll_lease_callback = func() -> void:
		var nested_operation: GFSceneOperation = (
			_scene_util.preload_scene_request_async(scene_path)
		)
		if nested_operation != null:
			nested_operations.append(nested_operation)
	_scene_util.threaded_complete = true

	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_eq(
		_scene_util._broker.poll_lease_call_count,
		1,
		"terminal broker callback 的同路径 admission 不得递归 poll 同一 aggregate。"
	)
	assert_eq(nested_operations.size(), 1)
	if nested_operations.size() == 1:
		_assert_typed_terminal(
			nested_operations[0],
			"REJECTED",
			"REASON_BROKER_REJECTED",
			ERR_BUSY
		)


func test_typed_load_via_preload_publishes_final_progress_before_load_terminal() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var order: Array[StringName] = []
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var preload_operation: Object = _request_typed_preload(scene_path)
	var load_operation: Object = _request_typed_load(scene_path)
	if preload_operation == null or load_operation == null:
		return
	var _operation_progress_error: Error = load_operation.connect(
		&"progressed",
		func(_progress: float) -> void:
			order.append(&"operation_progress")
	) as Error
	var _scene_progress_error: Error = _scene_util.scene_load_progress.connect(
		func(_path: String, _progress: float) -> void:
			order.append(&"scene_progress")
	) as Error
	var _scene_completed_error: Error = _scene_util.scene_load_completed.connect(
		func(_path: String, _scene: PackedScene) -> void:
			order.append(&"scene_completed")
	) as Error
	var _operation_completed_error: Error = load_operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			order.append(&"operation_completed")
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	assert_eq(order, [&"operation_progress", &"scene_progress"])
	_assert_typed_terminal(
		preload_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_true(_call_bool(load_operation, &"is_pending"))
	_scene_util.confirm_target_scene_commit()
	assert_eq(
		order,
		[
			&"operation_progress",
			&"scene_progress",
			&"scene_completed",
			&"operation_completed",
		]
	)


func test_typed_load_waits_for_real_scene_tree_commit_with_target_current_scene() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
	var scene: PackedScene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	assert_not_null(scene)
	if scene == null:
		return
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var sacrificial_scene: Node = Node.new()
	sacrificial_scene.name = "GFSceneCommitSacrificialRoot"
	scene_tree.root.add_child(sacrificial_scene)
	scene_tree.current_scene = sacrificial_scene
	var utility: GFSceneUtility = GFSceneUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, scene)
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		sacrificial_scene.queue_free()
		return
	watch_signals(operation)
	var observed_current_scene: Array[Node] = []
	var _completed_error: Error = operation.connect(
		&"completed",
		func(_result: Variant) -> void:
			observed_current_scene.append(get_tree().current_scene)
	) as Error

	utility.tick(0.0)
	assert_true(_call_bool(operation, &"is_pending"))
	assert_signal_not_emitted(operation, "completed")
	assert_signal_not_emitted(utility, "scene_load_completed")

	await scene_tree.scene_changed
	var target_scene: Node = scene_tree.current_scene
	assert_not_null(target_scene)
	if target_scene == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		return

	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_eq(observed_current_scene, [target_scene])
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(utility, "scene_load_completed", 1)
	scene_tree.current_scene = previous_scene
	target_scene.queue_free()
	utility.dispose()


func test_typed_load_accepts_committed_runtime_packed_scene_with_empty_path() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
	var in_memory_scene: PackedScene = _make_empty_scene()
	assert_true(in_memory_scene.resource_path.is_empty())
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var sacrificial_scene: Node = Node.new()
	sacrificial_scene.name = "GFInMemoryCommitSacrificialRoot"
	scene_tree.root.add_child(sacrificial_scene)
	scene_tree.current_scene = sacrificial_scene
	var utility: GFSceneUtility = GFSceneUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, in_memory_scene)
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		sacrificial_scene.queue_free()
		return
	watch_signals(operation)

	utility.tick(0.0)
	assert_true(_call_bool(operation, &"is_pending"))
	await scene_tree.scene_changed
	var target_scene: Node = scene_tree.current_scene
	assert_not_null(target_scene)
	if target_scene == null:
		utility.dispose()
		scene_tree.current_scene = previous_scene
		return

	assert_true(
		target_scene.scene_file_path.is_empty(),
		"运行时打包场景的 committed root 应保持空 scene_file_path。"
	)
	_assert_typed_terminal(operation, "COMPLETED", "REASON_SCENE_LOADED", OK)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(utility, "scene_load_completed", 1)
	scene_tree.current_scene = previous_scene
	target_scene.queue_free()
	utility.dispose()


func test_typed_load_pathless_instantiate_owner_release_never_commits_root() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
	var source_root: InstantiateCallbackSceneRoot = InstantiateCallbackSceneRoot.new()
	var in_memory_scene: PackedScene = PackedScene.new()
	var pack_error: Error = in_memory_scene.pack(source_root)
	source_root.free()
	assert_eq(pack_error, OK)
	assert_true(in_memory_scene.resource_path.is_empty())
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var instantiate_callback_count: Array[int] = []
	InstantiateCallbackSceneRoot.instantiate_callback = func() -> void:
		instantiate_callback_count.append(1)
		request_owner.queue_free()
	var scene_tree: SceneTree = get_tree()
	var previous_root: Node = scene_tree.current_scene
	var utility: NativeSceneCommitUtility = NativeSceneCommitUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, in_memory_scene)
	var operation: Object = _request_typed_load_from(
		utility,
		scene_path,
		"",
		{},
		-1.0,
		request_owner
	)
	if operation == null:
		InstantiateCallbackSceneRoot.instantiate_callback = Callable()
		utility.dispose()
		request_owner.queue_free()
		return

	utility.tick(0.0)
	InstantiateCallbackSceneRoot.instantiate_callback = Callable()

	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	assert_eq(instantiate_callback_count.size(), 1)
	assert_eq(scene_tree.current_scene, previous_root)
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"instantiate callback 取消 generation 后不得遗留 commit observer。"
	)
	utility.dispose()


func test_typed_load_pathless_instantiate_signal_never_consumes_future_commit() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
	var source_root: InstantiateCallbackSceneRoot = InstantiateCallbackSceneRoot.new()
	var in_memory_scene: PackedScene = PackedScene.new()
	var pack_error: Error = in_memory_scene.pack(source_root)
	source_root.free()
	assert_eq(pack_error, OK)
	var scene_tree: SceneTree = get_tree()
	var previous_scene: Node = scene_tree.current_scene
	var existing_root: Node = Node.new()
	existing_root.name = "GFInstantiateSignalExistingRoot"
	scene_tree.root.add_child(existing_root)
	scene_tree.current_scene = existing_root
	InstantiateCallbackSceneRoot.instantiate_callback = func() -> void:
		scene_tree.scene_changed.emit()
	var utility: NativeSceneCommitUtility = NativeSceneCommitUtility.new()
	utility.init()
	utility.put_preloaded_scene(scene_path, in_memory_scene)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		InstantiateCallbackSceneRoot.instantiate_callback = Callable()
		utility.dispose()
		scene_tree.current_scene = previous_scene
		existing_root.queue_free()
		return

	utility.tick(0.0)
	InstantiateCallbackSceneRoot.instantiate_callback = Callable()

	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_SCENE_CHANGE_FAILED",
		ERR_CANT_CREATE
	)
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"instantiate 内的提前 signal 不得消费未来物理 commit 的 observer。"
	)
	await scene_tree.process_frame
	assert_eq(
		scene_tree.current_scene,
		existing_root,
		"提前 signal 后必须在 change_scene_to_node 前 fail closed。"
	)
	utility.dispose()
	scene_tree.current_scene = previous_scene
	existing_root.queue_free()


func test_target_change_owner_teardown_reentry_cancels_without_late_success() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var utility: ReentrantSceneCommitUtility = ReentrantSceneCommitUtility.new()
	utility.init()
	utility.owner_to_release = request_owner
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(
		utility,
		scene_path,
		"",
		{},
		-1.0,
		request_owner
	)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")

	utility.confirm_target_scene_commit()
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	utility.dispose()


func test_target_change_owner_teardown_preserves_pending_loading_scene_restore() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loading_scene_path: String = "res://addons/gut/gui/MinGui.tscn"
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var utility: ReentrantSceneCommitUtility = ReentrantSceneCommitUtility.new()
	utility.init()
	utility.owner_to_release = request_owner
	utility.use_fake_threaded_resource = true
	utility.threaded_resource = _make_empty_scene()
	utility._current_scene_params = { "origin": "preserved" }
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(
		utility,
		scene_path,
		loading_scene_path,
		{ "target": "suppressed" },
		-1.0,
		request_owner
	)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)
	utility.threaded_complete = true
	utility.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_OWNER_RELEASED",
		ERR_SKIP
	)
	utility.confirm_target_scene_commit()
	utility.tick(0.0)

	assert_eq(
		utility.current_scene_path,
		"res://tests/current_scene.tscn",
		"loading scene cancel 已排队的 restore 必须最终决定物理与内部当前场景。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			utility.get_current_scene_params(),
			"origin"
		),
		"preserved",
		"late target observation 不得以已取消参数覆盖 restore 后的当前参数。"
	)
	assert_true(utility.get_scene_history().is_empty())
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	utility.dispose()


func test_target_change_utility_dispose_reentry_never_publishes_success() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var utility: ReentrantSceneCommitUtility = ReentrantSceneCommitUtility.new()
	utility.init()
	utility.dispose_during_change = true
	utility.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(utility)
	var operation: Object = _request_typed_load_from(utility, scene_path)
	if operation == null:
		utility.dispose()
		return
	watch_signals(operation)

	utility.tick(0.0)
	_assert_typed_terminal(
		operation,
		"DISPOSED",
		"REASON_UTILITY_DISPOSED",
		ERR_UNAVAILABLE
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_true(
		utility.has_pending_target_scene_commit_for_test(),
		"已接纳切场在同步 dispose 后仍须保留本 generation 的一次性物理观察。"
	)

	utility.confirm_target_scene_commit()
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_not_emitted(utility, "scene_load_completed")
	assert_false(
		utility.has_pending_target_scene_commit_for_test(),
		"scene_changed 回调必须先断开并清空 dispose 后保留的物理观察。"
	)
	utility.dispose()


func test_load_started_token_reentry_stops_before_switch_started() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	watch_signals(_scene_util)
	var cancel_from_started: Callable = func(_path: String) -> void:
		var _cancelled: bool = cancellation_source.cancel(&"load_started")
	var _started_error: Error = _scene_util.scene_load_started.connect(
		cancel_from_started,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	var operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_signal_emit_count(_scene_util, "scene_load_started", 1)
	assert_signal_not_emitted(_scene_util, "scene_switch_started")
	assert_true(_scene_util.threaded_requested_paths.is_empty())


func test_typed_direct_load_cache_callback_token_cancel_stops_target_change() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)
	var operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	var cancel_from_cache: Callable = func(_path: String, _fixed: bool) -> void:
		var _cancelled: bool = cancellation_source.cancel(&"cache_callback")
	var _cache_error: Error = _scene_util.scene_cache_added.connect(
		cancel_from_cache,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")


func test_typed_fixed_cache_hit_rechecks_token_after_cache_callback() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	var cancel_from_fixed_cache: Callable = func(_path: String, fixed: bool) -> void:
		if fixed:
			var _cancelled: bool = cancellation_source.cancel(
				&"fixed_cache_callback"
			)
	var _cache_error: Error = _scene_util.scene_cache_added.connect(
		cancel_from_fixed_cache,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	var operation: Object = _request_typed_preload(
		scene_path,
		true,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)


func test_loading_scene_fade_out_token_reentry_stops_target_change() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var loading_scene_path: String = "res://addons/gut/gui/MinGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	var loading_scene: FakeLoadingScene = FakeLoadingScene.new()
	loading_scene.fade_out_callback = func() -> void:
		var _cancelled: bool = cancellation_source.cancel(&"fade_out")
	_scene_util.loading_scene_node = loading_scene
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	watch_signals(_scene_util)
	var operation: Object = _request_typed_load(
		scene_path,
		loading_scene_path,
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return

	_scene_util.tick(0.0)
	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_true(loading_scene.faded_out)
	assert_signal_emit_count(_scene_util, "loading_scene_hidden", 1)
	assert_eq(_scene_util.packed_scene_changes, 0)
	assert_signal_not_emitted(_scene_util, "scene_load_completed")
	_scene_util.loading_scene_node = null
	loading_scene.free()


func test_load_via_preload_rechecks_token_after_broker_request_callback() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var preload_operation: Object = _request_typed_preload(scene_path)
	if preload_operation == null:
		return
	_scene_util._broker.request_callback = func() -> void:
		var _cancelled: bool = cancellation_source.cancel(&"broker_request")

	var load_operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if load_operation == null:
		return
	_assert_typed_terminal(
		load_operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_true(_call_bool(preload_operation, &"is_pending"))
	assert_false(_is_scene_utility_loading(_scene_util))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		preload_operation,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_broker_poll_token_reentry_precedes_direct_load_failure() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var cancellation_source: GFCancellationSource = GFCancellationSource.new()
	_scene_util.use_fake_threaded_resource = true
	var operation: Object = _request_typed_load(
		scene_path,
		"",
		{},
		-1.0,
		null,
		cancellation_source.get_token()
	)
	if operation == null:
		return
	_scene_util._broker.poll_lease_callback = func() -> void:
		var _cancelled: bool = cancellation_source.cancel(&"broker_poll")
	_scene_util.threaded_failed = true

	_scene_util.tick(0.0)
	_assert_typed_terminal(
		operation,
		"CANCELLED",
		"REASON_TOKEN_CANCELLED",
		ERR_SKIP
	)
	assert_eq(_scene_util.packed_scene_changes, 0)


func test_preload_progress_same_path_replacement_keeps_new_generation_and_load() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var replacement_preloads: Array[Object] = []
	var replacement_loads: Array[Object] = []
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = _make_empty_scene()
	var original: Object = _request_typed_preload(scene_path)
	if original == null:
		return
	var original_request: Dictionary = _scene_util._get_preload_request(scene_path)
	var original_generation: int = _scene_util._get_preload_request_generation(
		original_request
	)
	var replace_from_progress: Callable = func(_path: String, _progress: float) -> void:
		_scene_util.cancel_scene_preload(scene_path)
		replacement_preloads.append(_request_typed_preload(scene_path))
		replacement_loads.append(_request_typed_load(scene_path))
	var _progress_error: Error = _scene_util.scene_preload_progress.connect(
		replace_from_progress,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	_scene_util.threaded_progress = 0.5

	_scene_util.tick(0.0)
	_assert_typed_terminal(
		original,
		"CANCELLED",
		"REASON_PATH_CANCELLED",
		ERR_SKIP
	)
	assert_eq(replacement_preloads.size(), 1)
	assert_eq(replacement_loads.size(), 1)
	if replacement_preloads.is_empty() or replacement_loads.is_empty():
		return
	var replacement_preload: Object = replacement_preloads[0]
	var replacement_load: Object = replacement_loads[0]
	assert_not_null(replacement_preload)
	assert_not_null(replacement_load)
	if replacement_preload == null or replacement_load == null:
		return
	var replacement_request: Dictionary = _scene_util._get_preload_request(scene_path)
	var replacement_generation: int = _scene_util._get_preload_request_generation(
		replacement_request
	)
	assert_ne(replacement_generation, original_generation)
	assert_eq(
		_scene_util._active_load_preload_request_generation,
		replacement_generation
	)
	assert_true(_call_bool(replacement_preload, &"is_pending"))
	assert_true(_call_bool(replacement_load, &"is_pending"))

	_scene_util.threaded_complete = true
	_scene_util.tick(0.0)
	_assert_typed_terminal(
		replacement_preload,
		"COMPLETED",
		"REASON_SCENE_PRELOADED",
		OK
	)
	assert_true(_call_bool(replacement_load, &"is_pending"))
	_scene_util.confirm_target_scene_commit()
	_assert_typed_terminal(
		replacement_load,
		"COMPLETED",
		"REASON_SCENE_LOADED",
		OK
	)


func test_committed_load_listener_dispose_does_not_publish_failure() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.put_preloaded_scene(scene_path, _make_empty_scene())
	watch_signals(_scene_util)
	var dispose_from_completed: Callable = func(
		_path: String,
		_scene: PackedScene
	) -> void:
		_scene_util.dispose()
	var _completed_error: Error = _scene_util.scene_load_completed.connect(
		dispose_from_completed,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	watch_signals(operation)

	_scene_util.tick(0.0)
	_scene_util.confirm_target_scene_commit()
	_assert_typed_terminal(
		operation,
		"COMPLETED",
		"REASON_SCENE_LOADED",
		OK
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_completed", 1)
	assert_signal_emit_count(_scene_util, "scene_switch_completed", 1)
	assert_signal_not_emitted(_scene_util, "scene_load_failed")


func test_failed_load_listener_dispose_does_not_publish_duplicate_failure() -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	watch_signals(_scene_util)
	var dispose_from_failed: Callable = func(_path: String) -> void:
		_scene_util.dispose()
	var _failed_error: Error = _scene_util.scene_load_failed.connect(
		dispose_from_failed,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var operation: Object = _request_typed_load(scene_path)
	if operation == null:
		return
	watch_signals(operation)
	_scene_util.threaded_failed = true

	_scene_util.tick(0.0)
	assert_push_error("[GFSceneUtility] 场景异步加载失败：%s" % scene_path)
	_assert_typed_terminal(
		operation,
		"FAILED",
		"REASON_RESOURCE_LOAD_FAILED",
		ERR_CANT_OPEN
	)
	assert_signal_emit_count(operation, "completed", 1)
	assert_signal_emit_count(_scene_util, "scene_load_failed", 1)
	assert_signal_not_emitted(_scene_util, "scene_switch_failed")


func test_cache_clear_listener_reentry_preserves_new_cache_entry() -> void:
	var fixed_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var temporary_path: String = "res://addons/gut/gui/MinGui.tscn"
	var replacement_path: String = "res://addons/gut/gui/GutRunner.tscn"
	_scene_util.put_preloaded_scene(fixed_path, _make_empty_scene(), true)
	_scene_util.put_preloaded_scene(temporary_path, _make_empty_scene())
	var replace_from_remove: Callable = func(_path: String, _fixed: bool) -> void:
		_scene_util.put_preloaded_scene(replacement_path, _make_empty_scene())
	var _removed_error: Error = _scene_util.scene_cache_removed.connect(
		replace_from_remove,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.clear_preloaded_scenes(true)
	assert_false(_scene_util.is_scene_preloaded(fixed_path))
	assert_false(_scene_util.is_scene_preloaded(temporary_path))
	assert_true(
		_scene_util.is_scene_preloaded(replacement_path),
		"批量 clear 的 removal callback 新增 cache 不得被旧流程后续清理。"
	)


func test_cache_eviction_listener_removal_suppresses_stale_added_signal() -> void:
	var old_path: String = "res://addons/gut/gui/NormalGui.tscn"
	var inserted_path: String = "res://addons/gut/gui/MinGui.tscn"
	_scene_util.max_preloaded_scene_resources = 1
	_scene_util.put_preloaded_scene(old_path, _make_empty_scene())
	var added_paths: PackedStringArray = PackedStringArray()
	var record_added: Callable = func(path: String, _fixed: bool) -> void:
		var _appended: bool = added_paths.append(path)
	var remove_inserted_from_eviction: Callable = func(
		_path: String,
		_fixed: bool
	) -> void:
		_scene_util.remove_preloaded_scene(inserted_path)
	var _added_error: Error = _scene_util.scene_cache_added.connect(record_added) as Error
	var _removed_error: Error = _scene_util.scene_cache_removed.connect(
		remove_inserted_from_eviction,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_scene_util.put_preloaded_scene(inserted_path, _make_empty_scene())
	assert_false(_scene_util.is_scene_preloaded(inserted_path))
	assert_false(
		added_paths.has(inserted_path),
		"eviction listener 已移除本次写入时，外层 put 不得补发 stale cache-added。"
	)


# --- 私有/辅助方法 ---

func _typed_scene_contract_scripts_exist() -> bool:
	return (
		ResourceLoader.exists(_SCENE_OPERATION_SCRIPT_PATH, "Script")
		and ResourceLoader.exists(_SCENE_RESULT_SCRIPT_PATH, "Script")
	)


func _typed_scene_contract_classes_registered() -> bool:
	return (
		_global_script_class_exists(&"GFSceneOperation")
		and _global_script_class_exists(&"GFSceneOperationResult")
	)


func _typed_scene_utility_methods_exist() -> bool:
	return (
		_scene_util != null
		and _scene_util.has_method(&"load_scene_request_async")
		and _scene_util.has_method(&"preload_scene_request_async")
	)


func _typed_scene_contract_runtime_ready() -> bool:
	return (
		_typed_scene_contract_scripts_exist()
		and _typed_scene_contract_classes_registered()
		and _typed_scene_utility_methods_exist()
	)


func _skip_typed_scene_runtime_scenario() -> bool:
	if _typed_scene_contract_runtime_ready():
		return false
	assert_true(true, "公开契约缺失已由结构契约测试报告。")
	return true


func _assert_terminal_preload_progress_reentry_is_bounded(
	resource: Resource,
	threaded_failed: bool,
	expected_status: String,
	expected_reason: String,
	expected_error: Error
) -> void:
	if _skip_typed_scene_runtime_scenario():
		return
	var scene_path: String = "res://addons/gut/gui/NormalGui.tscn"
	_scene_util.use_fake_threaded_resource = true
	_scene_util.threaded_resource = resource
	_scene_util.threaded_failed = threaded_failed
	var operation: Object = _request_typed_preload(scene_path)
	if operation == null:
		return
	var reentry_state: Dictionary = {
		"started": false,
		"progress_call_count": 0,
	}
	var nested_operations: Array[GFSceneOperation] = []
	var callback: Callable = func(_path: String, _progress: float) -> void:
		reentry_state["progress_call_count"] = (
			GFVariantData.get_option_int(reentry_state, "progress_call_count", 0)
			+ 1
		)
		if GFVariantData.get_option_bool(reentry_state, "started", false):
			return
		reentry_state["started"] = true
		var nested_load_operation: GFSceneOperation = (
			_scene_util.load_scene_request_async(scene_path)
		)
		if nested_load_operation != null:
			nested_operations.append(nested_load_operation)
		var nested_preload_operation: GFSceneOperation = (
			_scene_util.preload_scene_request_async(scene_path)
		)
		if nested_preload_operation != null:
			nested_operations.append(nested_preload_operation)
	var connect_error: Error = _scene_util.scene_preload_progress.connect(
		callback
	) as Error
	assert_eq(connect_error, OK)

	_scene_util.threaded_complete = not threaded_failed
	_scene_util.tick(0.0)

	_assert_typed_terminal(
		operation,
		expected_status,
		expected_reason,
		expected_error
	)
	assert_eq(
		GFVariantData.get_option_int(reentry_state, "progress_call_count", 0),
		1,
		"terminal progress listener 的同路径 admission 不得同步重轮询同一 aggregate。"
	)
	assert_eq(nested_operations.size(), 2)
	if nested_operations.size() == 2:
		_assert_typed_terminal(
			nested_operations[0],
			"REJECTED",
			"REASON_LOAD_BUSY",
			ERR_BUSY
		)
		_assert_typed_terminal(
			nested_operations[1],
			"REJECTED",
			"REASON_BROKER_REJECTED",
			ERR_BUSY
		)
	if _scene_util.scene_preload_progress.is_connected(callback):
		_scene_util.scene_preload_progress.disconnect(callback)


func _request_typed_preload(
	path: String,
	fixed: bool = false,
	request_owner: Object = null,
	cancellation_token: GFCancellationToken = null
) -> Object:
	assert_true(
		_scene_util.has_method(&"preload_scene_request_async"),
		"GFSceneUtility 必须公开 preload_scene_request_async。"
	)
	if not _scene_util.has_method(&"preload_scene_request_async"):
		return null
	var operation_value: Variant = _scene_util.call(
		&"preload_scene_request_async",
		path,
		fixed,
		request_owner,
		cancellation_token
	)
	assert_true(operation_value is Object, "typed preload 必须返回 GFSceneOperation。")
	if operation_value is Object:
		var operation: Object = operation_value
		return operation
	return null


func _request_typed_load(
	path: String,
	loading_scene_path: String = "",
	params: Dictionary = {},
	minimum_duration_seconds: float = -1.0,
	request_owner: Object = null,
	cancellation_token: GFCancellationToken = null
) -> Object:
	return _request_typed_load_from(
		_scene_util,
		path,
		loading_scene_path,
		params,
		minimum_duration_seconds,
		request_owner,
		cancellation_token
	)


func _request_typed_load_from(
	scene_util: GFSceneUtility,
	path: String,
	loading_scene_path: String = "",
	params: Dictionary = {},
	minimum_duration_seconds: float = -1.0,
	request_owner: Object = null,
	cancellation_token: GFCancellationToken = null
) -> Object:
	assert_true(
		scene_util != null and scene_util.has_method(&"load_scene_request_async"),
		"GFSceneUtility 必须公开 load_scene_request_async。"
	)
	if scene_util == null or not scene_util.has_method(&"load_scene_request_async"):
		return null
	var operation_value: Variant = scene_util.call(
		&"load_scene_request_async",
		path,
		loading_scene_path,
		params,
		minimum_duration_seconds,
		request_owner,
		cancellation_token
	)
	assert_true(operation_value is Object, "typed load 必须返回 GFSceneOperation。")
	if operation_value is Object:
		var operation: Object = operation_value
		return operation
	return null


func _get_operation_result(operation: Object) -> Object:
	if operation == null or not operation.has_method(&"get_result"):
		return null
	var result_value: Variant = operation.call(&"get_result")
	if result_value is Object:
		var result: Object = result_value
		return result
	return null


func _assert_typed_terminal(
	operation: Object,
	status_name: String,
	reason_constant_name: String,
	expected_error: Error
) -> void:
	var _result: Object = _assert_typed_terminal_result(
		operation,
		status_name,
		reason_constant_name,
		expected_error
	)


func _assert_typed_terminal_result(
	operation: Object,
	status_name: String,
	reason_constant_name: String,
	expected_error: Error
) -> Object:
	assert_not_null(operation)
	if operation == null:
		return null
	assert_false(_call_bool(operation, &"is_pending"))
	assert_true(_call_bool(operation, &"is_completed"))
	var result: Object = _get_operation_result(operation)
	assert_not_null(result)
	if result == null:
		return null
	assert_eq(
		_call_int(result, &"get_status", -1),
		_enum_value(_SCENE_RESULT_SCRIPT_PATH, "Status", status_name)
	)
	assert_eq(
		_call_string_name(result, &"get_reason"),
		_script_string_name_constant(_SCENE_RESULT_SCRIPT_PATH, reason_constant_name)
	)
	assert_eq(_call_int(result, &"get_error_code", -1), expected_error)
	assert_eq(
		_call_int(result, &"get_request_id", 0),
		_call_int(operation, &"get_request_id", -1)
	)
	assert_eq(
		_call_int(result, &"get_kind", -1),
		_call_int(operation, &"get_kind", -2)
	)
	assert_eq(_call_bool(result, &"is_successful"), status_name == "COMPLETED")
	return result


func _assert_operation_kind(operation: Object, kind_name: String) -> void:
	assert_eq(
		_call_int(operation, &"get_kind", -1),
		_enum_value(_SCENE_OPERATION_SCRIPT_PATH, "Kind", kind_name)
	)


func _assert_scene_identity(target: Object, expected_path: String) -> void:
	assert_not_null(target)
	if target == null or not target.has_method(&"get_scene_identity"):
		assert_true(false, "typed scene contract 必须提供 get_scene_identity。")
		return
	var first_value: Variant = target.call(&"get_scene_identity")
	var second_value: Variant = target.call(&"get_scene_identity")
	assert_true(first_value is GFResourceIdentity)
	assert_true(second_value is GFResourceIdentity)
	if not first_value is GFResourceIdentity or not second_value is GFResourceIdentity:
		return
	var first_identity: GFResourceIdentity = first_value
	var second_identity: GFResourceIdentity = second_value
	assert_ne(first_identity, second_identity, "公开 identity getter 必须返回隔离快照。")
	assert_eq(first_identity.canonical_path, expected_path)
	assert_eq(second_identity.canonical_path, expected_path)
	first_identity.canonical_path = "res://tests/mutated_scene_identity.tscn"
	var fresh_value: Variant = target.call(&"get_scene_identity")
	assert_true(fresh_value is GFResourceIdentity)
	if fresh_value is GFResourceIdentity:
		var fresh_identity: GFResourceIdentity = fresh_value
		assert_eq(fresh_identity.canonical_path, expected_path, "调用方不得改写冻结身份。")


func _cancel_operation(operation: Object) -> bool:
	if operation == null or not operation.has_method(&"cancel"):
		return false
	var cancelled_value: Variant = operation.call(&"cancel")
	if cancelled_value is bool:
		var cancelled: bool = cancelled_value
		return cancelled
	return false


func _call_bool(
	target: Object,
	method_name: StringName,
	default_value: bool = false
) -> bool:
	if target == null or not target.has_method(method_name):
		return default_value
	var value: Variant = target.call(method_name)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return default_value


func _call_int(
	target: Object,
	method_name: StringName,
	default_value: int = 0
) -> int:
	if target == null or not target.has_method(method_name):
		return default_value
	var value: Variant = target.call(method_name)
	if value is int:
		var int_value: int = value
		return int_value
	return default_value


func _call_float(
	target: Object,
	method_name: StringName,
	default_value: float = 0.0
) -> float:
	if target == null or not target.has_method(method_name):
		return default_value
	var value: Variant = target.call(method_name)
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return default_value


func _call_string_name(target: Object, method_name: StringName) -> StringName:
	if target == null or not target.has_method(method_name):
		return &""
	var value: Variant = target.call(method_name)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	return &""


func _call_object(target: Object, method_name: StringName) -> Object:
	if target == null or not target.has_method(method_name):
		return null
	var value: Variant = target.call(method_name)
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _assert_method_signature(
	target: Object,
	method_name: StringName,
	expected_argument_count: int,
	expected_default_count: int,
	expected_return_class: StringName
) -> void:
	var method_info: Dictionary = _find_method_info(target, method_name)
	assert_false(method_info.is_empty(), "缺少冻结入口：%s" % method_name)
	if method_info.is_empty():
		return
	var arguments_value: Variant = GFVariantData.get_option_value(method_info, "args")
	var defaults_value: Variant = GFVariantData.get_option_value(method_info, "default_args")
	var return_value: Variant = GFVariantData.get_option_value(method_info, "return")
	assert_true(arguments_value is Array)
	assert_true(defaults_value is Array)
	assert_true(return_value is Dictionary)
	if arguments_value is Array:
		var arguments: Array = arguments_value
		assert_eq(arguments.size(), expected_argument_count)
	if defaults_value is Array:
		var defaults: Array = defaults_value
		assert_eq(defaults.size(), expected_default_count)
	if return_value is Dictionary:
		var return_info: Dictionary = return_value
		assert_eq(
			StringName(GFVariantData.get_option_string(return_info, "class_name")),
			expected_return_class
		)


func _find_method_info(target: Object, method_name: StringName) -> Dictionary:
	if target == null:
		return {}
	for method_value: Variant in target.get_method_list():
		if not method_value is Dictionary:
			continue
		var method_info: Dictionary = method_value
		if GFVariantData.get_option_string_name(method_info, "name") == method_name:
			return method_info
	return {}


func _load_gdscript(path: String) -> GDScript:
	var resource_value: Resource = load(path)
	if resource_value is GDScript:
		return resource_value
	return null


func _assert_script_enum(
	script: GDScript,
	enum_name: String,
	expected: Dictionary
) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	var enum_value: Variant = GFVariantData.get_option_value(constants, enum_name)
	assert_true(enum_value is Dictionary, "缺少冻结枚举：%s" % enum_name)
	if enum_value is Dictionary:
		var actual: Dictionary = enum_value
		assert_eq(actual, expected)


func _assert_script_string_name_constants(
	script: GDScript,
	expected: Dictionary
) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	for constant_name_value: Variant in expected.keys():
		assert_true(constant_name_value is String)
		if not constant_name_value is String:
			continue
		var constant_name: String = constant_name_value
		assert_true(constants.has(constant_name), "缺少冻结常量：%s" % constant_name)
		if not constants.has(constant_name):
			continue
		var actual_value: Variant = GFVariantData.get_option_value(constants, constant_name)
		var expected_value: Variant = GFVariantData.get_option_value(expected, constant_name)
		assert_true(actual_value is StringName)
		assert_true(expected_value is StringName)
		if actual_value is StringName and expected_value is StringName:
			var actual_reason: StringName = actual_value
			var expected_reason: StringName = expected_value
			assert_eq(actual_reason, expected_reason)


func _enum_value(script_path: String, enum_name: String, value_name: String) -> int:
	var script: GDScript = _load_gdscript(script_path)
	if script == null:
		return -1
	var constants: Dictionary = script.get_script_constant_map()
	var enum_value: Variant = GFVariantData.get_option_value(constants, enum_name)
	if enum_value is Dictionary:
		var values: Dictionary = enum_value
		return GFVariantData.get_option_int(values, value_name, -1)
	return -1


func _script_string_name_constant(script_path: String, constant_name: String) -> StringName:
	var script: GDScript = _load_gdscript(script_path)
	if script == null:
		return &""
	var constants: Dictionary = script.get_script_constant_map()
	var value: Variant = GFVariantData.get_option_value(constants, constant_name)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	return &""


func _assert_object_surface(target: Object, method_names: Array[StringName]) -> void:
	for method_name: StringName in method_names:
		assert_true(target.has_method(method_name), "缺少冻结方法：%s" % method_name)


func _global_script_class_exists(class_name_value: StringName) -> bool:
	for class_value: Variant in ProjectSettings.get_global_class_list():
		if not class_value is Dictionary:
			continue
		var class_info: Dictionary = class_value
		if GFVariantData.get_option_string_name(class_info, "class") == class_name_value:
			return true
	return false


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

class ThreadedSceneRequestCaller extends RefCounted:
	var _scene_utility: GFSceneUtility
	var _scene_path: String

	func _init(scene_utility: GFSceneUtility, scene_path: String) -> void:
		_scene_utility = scene_utility
		_scene_path = scene_path

	func call_public_requests() -> Array:
		return [
			_scene_utility.load_scene_request_async(_scene_path),
			_scene_utility.preload_scene_request_async(_scene_path),
		]


class DummyModel extends GFModel:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true


class DummyUtility extends GFUtility:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true


class InstantiateCallbackSceneRoot extends Node:
	static var instantiate_callback: Callable = Callable()

	func _init() -> void:
		if instantiate_callback.is_valid():
			instantiate_callback.call()


class NativeSceneCommitUtility extends GFSceneUtility:
	func has_pending_target_scene_commit_for_test() -> bool:
		return _has_pending_target_scene_commit()


class SampleSceneUtility extends GFSceneUtility:
	var _broker: SampleSceneResourceBroker = SampleSceneResourceBroker.new()
	var _test_scene_tree: SceneTree = null
	var _test_previous_scene_root_ref: WeakRef = null
	var _test_committed_root_refs: Array[WeakRef] = []
	var current_scene_path: String = "res://tests/current_scene.tscn"
	var sync_scene_changes: Array[String] = []
	var packed_scene_changes: int = 0
	var packed_scene_change_error: bool = false
	var pending_fake_target_path: String = ""
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
	var threaded_failed: bool:
		get:
			return _broker.threaded_failed
		set(value):
			_broker.threaded_failed = value
	var threaded_progress: float:
		get:
			return _broker.threaded_progress
		set(value):
			_broker.threaded_progress = value
	var threaded_request_error: Error:
		get:
			return _broker.threaded_request_error
		set(value):
			_broker.threaded_request_error = value
	var threaded_requested_paths: PackedStringArray:
		get:
			return _broker.threaded_requested_paths
	var lease_requested_paths: PackedStringArray:
		get:
			return _broker.lease_requested_paths

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)

	func dispose() -> void:
		_cleanup_test_scene_roots()
		super.dispose()

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
		pending_fake_target_path = _target_path
		return true

	func call_framework_change_scene_for_test(scene: PackedScene) -> bool:
		return super._do_change_scene(scene)

	func confirm_target_scene_commit() -> void:
		if pending_fake_target_path.is_empty():
			return
		if _install_test_scene_root(_target_scene_commit_scene) == null:
			return
		current_scene_path = pending_fake_target_path
		pending_fake_target_path = ""
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree != null:
			scene_tree.scene_changed.emit()

	func has_pending_target_scene_commit_for_test() -> bool:
		return _has_pending_target_scene_commit()

	func _scene_root_matches_target(_scene_root: Node, target_path: String) -> bool:
		return current_scene_path == target_path

	func _get_loading_scene_node() -> Node:
		return loading_scene_node

	func _install_test_scene_root(scene: PackedScene = null) -> Node:
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree == null:
			return null
		if _test_scene_tree == null:
			_test_scene_tree = scene_tree
			if scene_tree.current_scene != null:
				_test_previous_scene_root_ref = weakref(scene_tree.current_scene)
		var committed_root: Node = scene.instantiate() if scene != null else Node.new()
		if committed_root == null:
			return null
		scene_tree.root.add_child(committed_root)
		scene_tree.current_scene = committed_root
		_test_committed_root_refs.append(weakref(committed_root))
		return committed_root

	func _cleanup_test_scene_roots() -> void:
		if _test_scene_tree != null:
			var current_root: Node = _test_scene_tree.current_scene
			for root_ref: WeakRef in _test_committed_root_refs:
				var root_value: Variant = root_ref.get_ref()
				if root_value is Node:
					var committed_root: Node = root_value
					if current_root != committed_root:
						continue
					var previous_value: Variant = (
						_test_previous_scene_root_ref.get_ref()
						if _test_previous_scene_root_ref != null
						else null
					)
					_test_scene_tree.current_scene = (
						previous_value if previous_value is Node else null
					)
					break
		for retired_root_ref: WeakRef in _test_committed_root_refs:
			var retired_root_value: Variant = retired_root_ref.get_ref()
			if retired_root_value is Node:
				var retired_root: Node = retired_root_value
				if not retired_root.is_queued_for_deletion():
					retired_root.queue_free()
		_test_scene_tree = null
		_test_previous_scene_root_ref = null
		_test_committed_root_refs.clear()


class SynchronousSceneCommitUtility extends SampleSceneUtility:
	var override_active: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		override_active = true
		packed_scene_changes += 1
		var committed_root: Node = _install_test_scene_root(scene)
		if committed_root == null:
			override_active = false
			return false
		current_scene_path = _target_path
		override_active = false
		return true


class SynchronousOwnerReleaseSceneCommitUtility extends SynchronousSceneCommitUtility:
	var owner_to_release: Node = null

	func _do_change_scene(scene: PackedScene) -> bool:
		var accepted: bool = super._do_change_scene(scene)
		if accepted and owner_to_release != null:
			owner_to_release.queue_free()
		return accepted


class FailedSuperFallbackSceneCommitUtility extends SampleSceneUtility:
	var framework_change_failed: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		framework_change_failed = not call_framework_change_scene_for_test(null)
		packed_scene_changes += 1
		if _install_test_scene_root(scene) == null:
			return false
		current_scene_path = _target_path
		return true


class ConfirmThenRejectSceneCommitUtility extends SampleSceneUtility:
	var override_active: bool = false
	var confirm_accepted: bool = false
	var pending_after_confirm: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		override_active = true
		packed_scene_changes += 1
		if _install_test_scene_root(scene) == null:
			override_active = false
			return false
		current_scene_path = _target_path
		confirm_accepted = _confirm_target_scene_commit()
		pending_after_confirm = _has_pending_target_scene_commit()
		override_active = false
		return false


class SynchronousSignalSceneCommitUtility extends SampleSceneUtility:
	var override_active: bool = false
	var pending_after_signal: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		override_active = true
		packed_scene_changes += 1
		if _install_test_scene_root(scene) == null:
			override_active = false
			return false
		current_scene_path = _target_path
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree != null:
			scene_tree.scene_changed.emit()
		pending_after_signal = _has_pending_target_scene_commit()
		override_active = false
		return true


class NoOpSceneCommitUtility extends SampleSceneUtility:
	func _do_change_scene(_scene: PackedScene) -> bool:
		packed_scene_changes += 1
		return true


class SamePathDeferredSceneCommitUtility extends SampleSceneUtility:
	var defer_accepted: bool = false
	var committed_root: Node = null

	func _do_change_scene(scene: PackedScene) -> bool:
		packed_scene_changes += 1
		defer_accepted = _defer_target_scene_commit()
		if not defer_accepted:
			return false
		call_deferred(
			"_commit_deferred_scene_for_test",
			scene,
			_target_path
		)
		return true

	func _commit_deferred_scene_for_test(
		scene: PackedScene,
		target_path: String
	) -> void:
		committed_root = _install_test_scene_root(scene)
		if committed_root == null:
			return
		current_scene_path = target_path
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree != null:
			scene_tree.scene_changed.emit()


class ReplacingEmptyPathSceneCommitUtility extends SampleSceneUtility:
	var committed_root: Node = null
	var confirm_accepted: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		packed_scene_changes += 1
		committed_root = _install_test_scene_root(scene)
		if committed_root == null:
			return false
		confirm_accepted = _confirm_target_scene_commit()
		return confirm_accepted


class PathlessDeferredSceneCommitUtility extends SampleSceneUtility:
	var defer_accepted: bool = false
	var confirm_accepted: bool = false
	var committed_root: Node = null

	func _do_change_scene(scene: PackedScene) -> bool:
		packed_scene_changes += 1
		defer_accepted = _defer_target_scene_commit()
		if not defer_accepted:
			return false
		call_deferred("_commit_pathless_scene_for_test", scene)
		return true

	func _commit_pathless_scene_for_test(scene: PackedScene) -> void:
		committed_root = _install_test_scene_root(scene)
		if committed_root == null:
			return
		confirm_accepted = _confirm_target_scene_commit()


class WrongPathlessSceneCommitUtility extends SampleSceneUtility:
	var wrong_scene: PackedScene = null
	var committed_root: Node = null

	func _do_change_scene(_scene: PackedScene) -> bool:
		packed_scene_changes += 1
		committed_root = _install_test_scene_root(wrong_scene)
		if committed_root == null:
			return false
		var scene_tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
		if scene_tree != null:
			scene_tree.scene_changed.emit()
		return true


class ProvenThenReplaceSceneCommitUtility extends SampleSceneUtility:
	var proven_root: Node = null
	var replacement_root: Node = null
	var confirm_accepted: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		packed_scene_changes += 1
		proven_root = _install_test_scene_root(scene)
		if proven_root == null:
			return false
		current_scene_path = _target_path
		confirm_accepted = _confirm_target_scene_commit()
		if not confirm_accepted:
			return false
		replacement_root = _install_test_scene_root(scene)
		return replacement_root != null


class SynchronousDisposeSceneCommitUtility extends SampleSceneUtility:
	func _do_change_scene(_scene: PackedScene) -> bool:
		packed_scene_changes += 1
		current_scene_path = _target_path
		dispose()
		return true


class ReentrantSceneCommitUtility extends SampleSceneUtility:
	var owner_to_release: Node = null
	var dispose_during_change: bool = false

	func _do_change_scene(scene: PackedScene) -> bool:
		var changed: bool = super._do_change_scene(scene)
		if not changed:
			return false
		if owner_to_release != null:
			owner_to_release.queue_free()
		if dispose_during_change:
			dispose()
		return true


class SampleSceneResourceBroker extends GFResourceBroker:
	var use_fake_threaded_resource: bool = false
	var threaded_complete: bool = false
	var threaded_failed: bool = false
	var threaded_progress: float = 0.0
	var threaded_request_error: Error = OK
	var threaded_resource: Resource = null
	var threaded_requested_paths: PackedStringArray = PackedStringArray()
	var lease_requested_paths: PackedStringArray = PackedStringArray()
	var request_callback: Callable = Callable()
	var poll_lease_callback: Callable = Callable()
	var poll_lease_call_count: int = 0

	func request(
		path: String,
		type_hint: String = "",
		options: Dictionary = {}
	) -> GFResourceLease:
		var _appended: bool = lease_requested_paths.append(path)
		var lease: GFResourceLease = super.request(path, type_hint, options)
		if request_callback.is_valid():
			var callback: Callable = request_callback
			request_callback = Callable()
			callback.call()
		return lease

	func poll_lease(lease: GFResourceLease) -> Dictionary:
		poll_lease_call_count += 1
		var result: Dictionary = super.poll_lease(lease)
		if poll_lease_callback.is_valid():
			var callback: Callable = poll_lease_callback
			poll_lease_callback = Callable()
			callback.call()
		return result

	func _request_threaded_resource(path: String, type_hint: String) -> Error:
		if use_fake_threaded_resource:
			var _appended: bool = threaded_requested_paths.append(path)
			return threaded_request_error
		return super._request_threaded_resource(path, type_hint)

	func _poll_threaded_resource(_path: String, previous_progress: float) -> Dictionary:
		if not use_fake_threaded_resource:
			return super._poll_threaded_resource(_path, previous_progress)
		if threaded_failed:
			return {
				"status": &"failed",
				"progress": maxf(previous_progress, threaded_progress),
				"resource": null,
				"has_resource": false,
				"error": "test_threaded_load_failed",
			}
		return {
			"status": &"loaded" if threaded_complete else &"in_progress",
			"progress": (
				1.0
				if threaded_complete
				else maxf(previous_progress, threaded_progress)
			),
			"resource": threaded_resource if threaded_complete else null,
			"has_resource": threaded_complete and threaded_resource != null,
			"error": "",
		}


class FakeLoadingScene extends Node:
	var faded_in: bool = false
	var faded_out: bool = false
	var progress_values: Array[float] = []
	var fade_out_callback: Callable = Callable()

	func fade_in() -> void:
		faded_in = true

	func fade_out() -> void:
		faded_out = true
		if fade_out_callback.is_valid():
			var callback: Callable = fade_out_callback
			fade_out_callback = Callable()
			callback.call()

	func set_progress(value: float) -> void:
		progress_values.append(value)
