## 测试 GFResourceBroker 的共享 admission、复用和 drain 语义。
extends GutTest


const ASSET_UTILITY_PATH: String = "res://addons/gf/standard/utilities/assets/gf_asset_utility.gd"
const JOB_UTILITY_PATH: String = "res://addons/gf/standard/utilities/jobs/gf_background_work_utility.gd"
const SCENE_UTILITY_PATH: String = "res://addons/gf/standard/utilities/scene/gf_scene_utility.gd"
const NORMAL_GUI_SCENE: String = "res://addons/gut/gui/NormalGui.tscn"


# --- 测试用例 ---

func test_same_path_reuses_underlying_request_with_independent_leases() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var first: GFResourceLease = broker.request(
		"res://shared_resource.tres",
		"Resource",
		{ "consumer_id": &"first" }
	)
	var second: GFResourceLease = broker.request(
		"res://shared_resource.tres",
		"Resource",
		{ "consumer_id": &"second" }
	)

	assert_eq(broker.requested_paths.size(), 1, "同路径应只发起一次底层请求。")
	first.cancel(&"first_cancelled")
	var loaded_resource: Resource = Resource.new()
	broker.complete_path("res://shared_resource.tres", loaded_resource)
	broker.pump()

	assert_eq(first.get_status(), GFResourceLease.STATUS_CANCELLED, "取消只应影响当前 Lease。")
	assert_null(first.get_resource(), "取消的消费者不得收到资源。")
	assert_eq(second.get_status(), GFResourceLease.STATUS_COMPLETED, "另一消费者应正常完成。")
	assert_same(second.get_resource(), loaded_resource, "复用请求应交付同一个 Resource。")
	second.release()


func test_exclusive_request_preserves_fifo_and_blocks_later_shared_work() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.max_active_requests = 2
	broker.init()
	var first: GFResourceLease = broker.request("res://first.tres")
	var second: GFResourceLease = broker.request("res://second.tres")
	var exclusive: GFResourceLease = broker.request(
		"res://exclusive.tres",
		"",
		{ "exclusive": true, "require_idle": true }
	)
	var later: GFResourceLease = broker.request("res://later.tres")

	assert_eq(
		broker.requested_paths,
		PackedStringArray(["res://first.tres", "res://second.tres"]),
		"独占请求应等待已有活动请求完成。"
	)
	broker.complete_path("res://first.tres", Resource.new())
	broker.complete_path("res://second.tres", Resource.new())
	broker.pump()

	assert_eq(exclusive.get_status(), GFResourceLease.STATUS_LOADING, "队首独占请求应在 idle 边界 admission。")
	assert_eq(later.get_status(), GFResourceLease.STATUS_QUEUED, "后续共享请求不得绕过独占请求。")
	assert_eq(broker.requested_paths[-1], "res://exclusive.tres")

	broker.complete_path("res://exclusive.tres", Resource.new())
	broker.pump()
	assert_eq(later.get_status(), GFResourceLease.STATUS_LOADING, "独占完成后应继续 FIFO admission。")
	assert_eq(broker.requested_paths[-1], "res://later.tres")
	first.release()
	second.release()
	exclusive.release()
	later.cancel()


func test_queued_same_path_lease_upgrades_admission_constraints() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.max_active_requests = 1
	broker.init()
	var blocker: GFResourceLease = broker.request("res://blocker.tres")
	var shared: GFResourceLease = broker.request("res://upgrade.tres")
	var exclusive: GFResourceLease = broker.request(
		"res://upgrade.tres",
		"",
		{ "exclusive": true, "require_idle": true }
	)
	var later: GFResourceLease = broker.request("res://after_upgrade.tres")

	broker.complete_path("res://blocker.tres", Resource.new())
	broker.pump()

	assert_eq(shared.get_status(), GFResourceLease.STATUS_LOADING, "同路径共享 Lease 应复用升级后的请求。")
	assert_eq(exclusive.get_status(), GFResourceLease.STATUS_LOADING, "后加入的独占 Lease 应升级 queued record。")
	assert_eq(later.get_status(), GFResourceLease.STATUS_QUEUED, "升级后的独占请求应阻塞后续工作。")
	assert_true(GFVariantData.get_option_bool(broker.get_debug_snapshot(), "active_exclusive"), "活动请求应保留升级后的独占约束。")
	blocker.release()
	shared.cancel()
	exclusive.cancel()
	later.cancel()


func test_last_consumer_cancel_keeps_active_request_draining() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var lease: GFResourceLease = broker.request("res://drain.tres")

	lease.cancel(&"abandoned")
	var snapshot: Dictionary = broker.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "draining_count"), 1, "最后消费者取消后底层请求应进入 drain。")

	broker.complete_path("res://drain.tres", Resource.new())
	broker.pump()
	assert_true(broker.is_idle(), "drain 到 ResourceLoader 终态后 Broker 应回到 idle。")
	assert_eq(lease.get_status(), GFResourceLease.STATUS_CANCELLED)
	assert_null(lease.get_resource(), "drain 结果不得交付给已取消消费者。")
	assert_gt(broker.get_poll_count("res://drain.tres"), 0, "取消后仍应轮询底层请求。")


func test_release_immediately_drops_local_reference_and_remains_idempotent() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var lease: GFResourceLease = broker.request("res://released_while_loading.tres")

	lease.release()
	var first_snapshot: Dictionary = broker.get_debug_snapshot()
	lease.release()
	var second_snapshot: Dictionary = broker.get_debug_snapshot()

	assert_true(lease.is_released(), "首次 release 应立即释放 Lease 本地引用。")
	assert_eq(lease.get_status(), GFResourceLease.STATUS_CANCELLED)
	assert_eq(
		GFVariantData.get_option_int(first_snapshot, "draining_count"),
		1,
		"活动底层请求仍应由 Broker drain。"
	)
	assert_eq(second_snapshot, first_snapshot, "重复 release 不得重复变更 Broker 状态。")

	broker.complete_path("res://released_while_loading.tres", Resource.new())
	broker.pump()
	assert_true(broker.is_idle())


func test_disposed_broker_can_finish_draining_but_rejects_new_requests() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var active: GFResourceLease = broker.request("res://dispose_drain.tres")
	broker.dispose()

	var rejected: GFResourceLease = broker.request("res://rejected.tres")
	assert_eq(rejected.get_status(), GFResourceLease.STATUS_FAILED)
	assert_eq(rejected.get_request_error(), ERR_UNAVAILABLE)

	broker.complete_path("res://dispose_drain.tres", Resource.new())
	broker.pump()
	assert_true(broker.is_idle(), "dispose 后显式 pump 仍应收敛 draining 请求。")
	assert_eq(active.get_status(), GFResourceLease.STATUS_CANCELLED)


func test_architecture_ready_injects_one_registered_broker_into_consumers() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var broker: GFResourceBroker = GFResourceBroker.new()
	var assets: GFAssetUtility = GFAssetUtility.new()
	var scenes: GFSceneUtility = GFSceneUtility.new()
	var jobs: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	await architecture.register_utility_instance(broker)
	await architecture.register_utility_instance(assets)
	await architecture.register_utility_instance(scenes)
	await architecture.register_utility_instance(jobs)

	await architecture.init()

	assert_same(assets.get_resource_broker(), broker, "Asset 应解析架构注册的共享 Broker。")
	assert_same(scenes.get_resource_broker(), broker, "Scene 应解析架构注册的共享 Broker。")
	assert_same(jobs.get_resource_broker(), broker, "BackgroundWork 应解析架构注册的共享 Broker。")
	architecture.dispose()


func test_standalone_setup_is_explicit_and_owned_by_consumer() -> void:
	var assets: GFAssetUtility = GFAssetUtility.new()
	assets.init()
	assert_null(assets.get_resource_broker(), "独立 Utility 不应隐式创建 Broker。")

	var broker: GFResourceBroker = assets.setup_standalone_resource_broker(2, 8)

	assert_not_null(broker)
	assert_same(assets.get_resource_broker(), broker)
	assert_eq(broker.max_active_requests, 2)
	assert_eq(broker.max_pending_requests, 8)
	assets.dispose()


func test_missing_broker_is_explicit_in_consumer_diagnostics() -> void:
	var assets: GFAssetUtility = GFAssetUtility.new()
	var scenes: GFSceneUtility = GFSceneUtility.new()
	var jobs: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	assets.init()
	scenes.init()
	jobs.init()

	var snapshots: Array[Dictionary] = [
		GFVariantData.get_option_dictionary(
			assets.get_debug_snapshot(),
			"resource_broker"
		),
		GFVariantData.get_option_dictionary(
			scenes.get_scene_cache_debug_snapshot(),
			"resource_broker"
		),
		GFVariantData.get_option_dictionary(
			jobs.get_debug_snapshot(),
			"resource_broker"
		),
	]
	for snapshot: Dictionary in snapshots:
		assert_false(
			GFVariantData.get_option_bool(snapshot, "configured", true),
			"未注册 Broker 不得伪装成可用配置。"
		)
		assert_eq(
			GFVariantData.get_option_string(snapshot, "error"),
			"resource_broker_not_configured"
		)
		assert_eq(
			GFVariantData.get_option_int(snapshot, "request_error"),
			ERR_UNCONFIGURED,
			"未配置状态应暴露与真实请求一致的错误码。"
		)
	assets.dispose()
	scenes.dispose()
	jobs.dispose()


func test_missing_broker_real_requests_fail_closed_with_unconfigured() -> void:
	var assets: GFAssetUtility = GFAssetUtility.new()
	var scenes: GFSceneUtility = GFSceneUtility.new()
	var jobs: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	assets.init()
	scenes.init()
	jobs.init()
	var asset_callbacks: Array = []

	assets.load_async(
		ASSET_UTILITY_PATH,
		func(resource: Resource) -> void:
			asset_callbacks.append(resource),
		"Script"
	)
	assert_push_error(
		"[GFAssetUtility] 无法发起异步加载请求：%s (错误码：%d)"
		% [ASSET_UTILITY_PATH, ERR_UNCONFIGURED]
	)
	var task: GFBackgroundWorkTask = jobs.submit_resource_load(
		JOB_UTILITY_PATH,
		"Script"
	)
	var scene_error: Error = scenes.load_scene_async(NORMAL_GUI_SCENE)
	assert_push_error(
		"[GFSceneUtility] 无法发起场景异步加载：%s (错误码：%d)"
		% [NORMAL_GUI_SCENE, ERR_UNCONFIGURED]
	)

	assert_eq(asset_callbacks.size(), 1, "Asset 失败回调必须同步且只执行一次。")
	var asset_callback_value: Variant = asset_callbacks[0]
	assert_true(asset_callback_value == null, "Asset 缺 Broker 时以 null 回调失败关闭。")
	assert_false(assets.is_loading(ASSET_UTILITY_PATH, "Script"))
	assert_eq(task.status, GFBackgroundWorkTask.Status.FAILED)
	assert_true(task.result is Dictionary)
	assert_eq(
		GFVariantData.get_option_int(GFVariantData.as_dictionary(task.result), "request_error"),
		ERR_UNCONFIGURED
	)
	assert_eq(scene_error, ERR_UNCONFIGURED, "Scene 在 headless 也必须经过 Broker admission。")
	assert_false(
		GFVariantData.get_option_bool(
			scenes.get_scene_cache_debug_snapshot(),
			"is_loading",
			true
		)
	)

	assets.dispose()
	scenes.dispose()
	jobs.dispose()


func test_asset_dispose_closes_admission_before_reentrant_callbacks() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var assets: GFAssetUtility = GFAssetUtility.new()
	assets.init()
	var bind_error: Error = assets.set_resource_broker(broker)
	assert_eq(bind_error, OK)
	var callback_values: Array = []

	assets.load_async(
		ASSET_UTILITY_PATH,
		func(resource: Resource) -> void:
			callback_values.append(resource)
			assets.load_async(
				SCENE_UTILITY_PATH,
				func(reentrant_resource: Resource) -> void:
					callback_values.append(reentrant_resource),
				"Script"
			),
		"Script"
	)
	assets.dispose()

	assert_eq(callback_values.size(), 2, "dispose 回调重入应立即收到一次失败结果。")
	var dispose_callback_value: Variant = callback_values[0]
	var reentrant_callback_value: Variant = callback_values[1]
	assert_true(dispose_callback_value == null)
	assert_true(reentrant_callback_value == null)
	assert_eq(
		broker.requested_paths,
		PackedStringArray([ASSET_UTILITY_PATH]),
		"dispose 期间不得为重入请求创建新 Lease。"
	)
	broker.complete_path(ASSET_UTILITY_PATH, Resource.new())
	broker.pump()
	assert_true(broker.is_idle())


func test_scene_dispose_closes_admission_before_reentrant_signals() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var scenes: GFSceneUtility = GFSceneUtility.new()
	scenes.init()
	var bind_error: Error = scenes.set_resource_broker(broker)
	assert_eq(bind_error, OK)
	var reentrant_errors: Array[Error] = []
	var connect_error: Error = scenes.scene_preload_cancelled.connect(
		func(_path: String) -> void:
			reentrant_errors.append(scenes.preload_scene(NORMAL_GUI_SCENE)),
		CONNECT_ONE_SHOT
	) as Error
	assert_eq(connect_error, OK)

	var preload_error: Error = scenes.preload_scene(
		"res://addons/gut/gui/MinGui.tscn"
	)
	assert_eq(preload_error, OK)
	scenes.dispose()

	assert_eq(reentrant_errors, [ERR_UNAVAILABLE])
	assert_eq(
		broker.requested_paths,
		PackedStringArray(["res://addons/gut/gui/MinGui.tscn"]),
		"dispose 信号重入不得创建新 Lease。"
	)
	broker.complete_path("res://addons/gut/gui/MinGui.tscn", Resource.new())
	broker.pump()
	assert_true(broker.is_idle())


func test_consumer_public_signatures_reference_gf_resource_broker_class() -> void:
	for path: String in [
		ASSET_UTILITY_PATH,
		JOB_UTILITY_PATH,
		SCENE_UTILITY_PATH,
	]:
		var source: String = FileAccess.get_file_as_string(path)
		assert_string_contains(
			source,
			"func set_resource_broker(broker: GFResourceBroker) -> Error:",
			"%s 应公开稳定的 Broker 参数类型。" % path
		)
		assert_string_contains(
			source,
			"func get_resource_broker() -> GFResourceBroker:",
			"%s 应公开稳定的 Broker 返回类型。" % path
		)
		assert_false(
			source.contains("func set_resource_broker(broker: _RESOURCE_BROKER_SCRIPT)"),
			"%s 的公开签名不得泄漏私有 preload 常量。" % path
		)


func test_request_budgets_are_clamped_to_public_absolute_limits() -> void:
	var broker: GFResourceBroker = GFResourceBroker.new()
	var script_value: Variant = broker.get_script()
	assert_true(script_value is Script, "Broker 应保留可检查的脚本 API。")
	if not script_value is Script:
		return
	var broker_script: Script = script_value
	var script_constants: Dictionary = broker_script.get_script_constant_map()
	var absolute_active_limit: int = GFVariantData.get_option_int(
		script_constants,
		"ABSOLUTE_MAX_ACTIVE_REQUESTS"
	)
	var absolute_pending_limit: int = GFVariantData.get_option_int(
		script_constants,
		"ABSOLUTE_MAX_PENDING_REQUESTS"
	)
	assert_eq(absolute_active_limit, 64, "应公开稳定的活动请求绝对上限。")
	assert_eq(absolute_pending_limit, 4096, "应公开稳定的等待请求绝对上限。")

	broker.max_active_requests = absolute_active_limit + 1
	broker.max_pending_requests = absolute_pending_limit + 1

	assert_eq(
		broker.max_active_requests,
		absolute_active_limit,
		"活动请求预算不得超过公开绝对上限。"
	)
	assert_eq(
		broker.max_pending_requests,
		absolute_pending_limit,
		"等待请求预算不得超过公开绝对上限。"
	)

	broker.max_active_requests = 0
	broker.max_pending_requests = 0
	assert_eq(broker.max_active_requests, 1, "活动请求预算至少为 1。")
	assert_eq(broker.max_pending_requests, 1, "等待请求预算至少为 1。")


func test_pending_budget_rejects_new_identity_but_allows_same_key_lease() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.max_active_requests = 1
	broker.max_pending_requests = 1
	broker.init()
	var active: GFResourceLease = broker.request("res://active_budget.tres")
	var queued: GFResourceLease = broker.request("res://queued_budget.tres")
	var joined: GFResourceLease = broker.request(
		"res://queued_budget.tres",
		"Resource"
	)
	var rejected: GFResourceLease = broker.request("res://rejected_budget.tres")

	assert_eq(queued.get_status(), GFResourceLease.STATUS_QUEUED)
	assert_eq(joined.get_status(), GFResourceLease.STATUS_QUEUED)
	assert_eq(
		rejected.get_request_error(),
		ERR_BUSY,
		"等待容量只拒绝新的资源身份，同 key Lease 不额外占用配额。"
	)

	broker.complete_path("res://active_budget.tres", Resource.new())
	broker.pump()
	assert_eq(queued.get_status(), GFResourceLease.STATUS_LOADING)
	assert_eq(joined.get_status(), GFResourceLease.STATUS_LOADING)
	assert_eq(
		broker.requested_paths,
		PackedStringArray([
			"res://active_budget.tres",
			"res://queued_budget.tres",
		]),
		"同 key 消费者应只产生一个底层请求。"
	)
	active.release()
	queued.cancel()
	joined.cancel()


func test_active_request_rejects_stronger_admission_constraints() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.init()
	var shared: GFResourceLease = broker.request("res://active_shared.tres")

	var exclusive: GFResourceLease = broker.request(
		"res://active_shared.tres",
		"",
		{ "exclusive": true }
	)
	var require_idle: GFResourceLease = broker.request(
		"res://active_shared.tres",
		"",
		{ "require_idle": true }
	)

	assert_eq(exclusive.get_status(), GFResourceLease.STATUS_FAILED)
	assert_eq(exclusive.get_request_error(), ERR_BUSY)
	assert_eq(
		exclusive.get_error_message(),
		"active_admission_constraints_not_satisfied"
	)
	assert_eq(require_idle.get_status(), GFResourceLease.STATUS_FAILED)
	assert_eq(require_idle.get_request_error(), ERR_BUSY)
	assert_eq(broker.requested_paths.size(), 1)
	shared.cancel()


func test_queued_request_tightens_type_hint_but_active_request_rejects_it() -> void:
	var broker: ResourceBrokerProbe = ResourceBrokerProbe.new()
	broker.max_active_requests = 1
	broker.init()
	var blocker: GFResourceLease = broker.request("res://type_blocker.tres")
	var loose: GFResourceLease = broker.request("res://typed_later.tres")
	var tightened: GFResourceLease = broker.request(
		"res://typed_later.tres",
		"Resource"
	)

	broker.complete_path("res://type_blocker.tres", Resource.new())
	broker.pump()
	assert_eq(loose.get_status(), GFResourceLease.STATUS_LOADING)
	assert_eq(tightened.get_status(), GFResourceLease.STATUS_LOADING)
	assert_eq(
		broker.requested_type_hints[-1],
		"Resource",
		"queued record 应在 admission 前采用更强 type_hint。"
	)

	var late_strong: GFResourceLease = broker.request(
		"res://active_untyped.tres"
	)
	broker.complete_path("res://typed_later.tres", Resource.new())
	broker.pump()
	var unsatisfied: GFResourceLease = broker.request(
		"res://active_untyped.tres",
		"Resource"
	)
	assert_eq(late_strong.get_status(), GFResourceLease.STATUS_LOADING)
	assert_eq(unsatisfied.get_status(), GFResourceLease.STATUS_FAILED)
	assert_eq(unsatisfied.get_request_error(), ERR_ALREADY_IN_USE)
	assert_eq(unsatisfied.get_error_message(), "active_type_hint_not_satisfied")
	blocker.release()
	loose.release()
	tightened.release()
	late_strong.cancel()


# --- 内部类 ---

class ResourceBrokerProbe extends GFResourceBroker:
	var requested_paths: PackedStringArray = PackedStringArray()
	var requested_type_hints: PackedStringArray = PackedStringArray()
	var _poll_results: Dictionary = {}
	var _poll_counts: Dictionary = {}

	func complete_path(path: String, resource: Resource) -> void:
		_poll_results[path] = {
			"status": &"loaded",
			"progress": 1.0,
			"resource": resource,
			"has_resource": resource != null,
			"error": "",
		}

	func get_poll_count(path: String) -> int:
		return GFVariantData.get_option_int(_poll_counts, path, 0)

	func _request_threaded_resource(path: String, type_hint: String) -> Error:
		var _appended: bool = requested_paths.append(path)
		var _hint_appended: bool = requested_type_hints.append(type_hint)
		return OK

	func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
		_poll_counts[path] = get_poll_count(path) + 1
		var value: Variant = GFVariantData.get_option_value(_poll_results, path)
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
