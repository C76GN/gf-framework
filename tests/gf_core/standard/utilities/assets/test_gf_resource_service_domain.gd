extends GutTest

const ASSET_REQUEST_DRIVER_SCRIPT = preload("res://tests/gf_core/standard/utilities/assets/asset_request_test_driver.gd")
var _asset_requests: ASSET_REQUEST_DRIVER_SCRIPT = ASSET_REQUEST_DRIVER_SCRIPT.new()
const RESOURCE_PATH: String = "res://service_domain/value.tres"
const SECOND_PATH: String = "res://service_domain/second.tres"


func test_default_mode_is_fixed_and_configuration_cannot_change() -> void:
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	var first: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_eq(
		domain.configure(first),
		OK
	)
	assert_eq(
		domain.get_mode(),
		GFResourceServiceDomain.Mode.STABLE
	)
	var candidate: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_false(domain.begin_switch(candidate).is_successful())
	assert_eq(
		domain.configure(candidate, GFResourceServiceDomain.Mode.IN_FLIGHT),
		ERR_ALREADY_IN_USE
	)
	assert_true(
		candidate.can_claim_service_domain(),
		"拒绝切换不能消费候选所有权。"
	)
	domain.dispose()
	candidate.dispose()


func test_native_threaded_broker_cannot_claim_in_flight_isolation() -> void:
	var native_broker: GFResourceBroker = GFResourceBroker.new()
	native_broker.init()
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(native_broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		ERR_UNAVAILABLE
	)
	assert_eq(
		domain.get_current_generation(),
		0
	)
	assert_eq(
		domain.configure(native_broker, GFResourceServiceDomain.Mode.CONTROLLED),
		OK
	)
	domain.dispose()


func test_fixed_consumers_prevent_later_domain_claim_even_before_first_request() -> void:
	var broker: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var assets: GFAssetUtility = GFAssetUtility.new()
	assets.init()
	assert_eq(
		assets.set_resource_broker(broker),
		OK
	)
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		ERR_ALREADY_IN_USE
	)
	assets.dispose()
	broker.dispose()


func test_cold_architecture_registration_and_service_domain_cannot_share_lifecycle_ownership() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var registered: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_true(await architecture.register_utility_instance(registered))
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(registered, GFResourceServiceDomain.Mode.IN_FLIGHT),
		ERR_ALREADY_IN_USE
	)
	architecture.dispose()
	var owned: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_eq(
		domain.configure(owned, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var other_architecture: GFArchitecture = GFArchitecture.new()
	assert_false(await other_architecture.register_utility_instance(owned))
	assert_push_error("[GFArchitecture][architecture.utility_registration_ownership_refused]")
	assert_true(domain.is_accepting_requests())
	var lease: GFResourceLease = domain.request(RESOURCE_PATH)
	domain.pump()
	assert_not_null(
		lease.get_resource(),
		"拒绝架构接管不能处置由域拥有的实例。"
	)
	lease.release()
	domain.dispose()
	other_architecture.dispose()


func test_domain_owner_rejects_raw_consumers_and_raw_requests() -> void:
	var broker: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var assets: GFAssetUtility = GFAssetUtility.new()
	var scenes: GFSceneUtility = GFSceneUtility.new()
	var jobs: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	assets.init()
	scenes.init()
	jobs.init()
	assert_eq(
		assets.set_resource_broker(broker),
		ERR_ALREADY_IN_USE
	)
	assert_eq(
		scenes.set_resource_broker(broker),
		ERR_ALREADY_IN_USE
	)
	assert_eq(
		jobs.set_resource_broker(broker),
		ERR_ALREADY_IN_USE
	)
	var rejected: GFResourceLease = broker.request(RESOURCE_PATH)
	assert_eq(
		rejected.get_request_error(),
		ERR_UNAUTHORIZED
	)
	rejected.release()
	assets.dispose()
	scenes.dispose()
	jobs.dispose()
	domain.dispose()


func test_shared_assets_use_one_domain_mode_and_reject_divergent_rebinding() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var other: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.STABLE,
		Resource.new()
	)
	var first: GFAssetUtility = _assets(domain)
	var second: GFAssetUtility = _assets(domain)
	assert_eq(
		first.set_resource_service_domain(domain),
		OK
	)
	assert_eq(
		second.set_resource_service_domain(other),
		ERR_ALREADY_IN_USE
	)
	assert_null(first.get_resource_broker())
	first.dispose()
	second.dispose()
	domain.dispose()
	other.dispose()


func test_controlled_switch_rejects_new_work_until_completed_lease_is_released() -> void:
	var old_resource: Resource = Resource.new()
	var new_resource: Resource = Resource.new()
	var domain: GFResourceServiceDomain = _domain(GFResourceServiceDomain.Mode.CONTROLLED, old_resource)
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	assert_false(domain.is_accepting_requests())
	var rejected: GFResourceLease = domain.request(RESOURCE_PATH)
	assert_eq(
		rejected.get_status(),
		GFResourceLease.STATUS_FAILED
	)
	rejected.release()
	domain.pump()
	assert_same(
		old_lease.get_resource(),
		old_resource
	)
	assert_true(
		completion.is_pending(),
		"Broker idle 不等于已交付资源租约释放。"
	)
	assert_eq(
		domain.get_current_generation(),
		1
	)
	old_lease.release()
	domain.pump()
	assert_true(completion.is_successful())
	assert_true(domain.is_accepting_requests())
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	domain.pump()
	assert_same(
		new_lease.get_resource(),
		new_resource
	)
	assert_eq(
		new_lease.get_service_generation(),
		2
	)
	new_lease.release()
	domain.dispose()


func test_controlled_invalid_candidate_does_not_pause_or_take_ownership() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.CONTROLLED,
		Resource.new()
	)
	var uninitialized: GFResourceBroker = GFResourceBroker.new()
	var completion: GFAsyncCompletion = domain.begin_switch(uninitialized)
	assert_false(completion.is_successful())
	assert_true(domain.is_accepting_requests())
	assert_eq(
		domain.get_current_generation(),
		1
	)
	domain.dispose()


func test_controlled_timeout_stays_paused_and_requires_explicit_new_switch() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.CONTROLLED,
		Resource.new()
	)
	var lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var completion: GFAsyncCompletion = domain.begin_switch(
		_snapshot(Resource.new()),
		1
	)
	var latest_deadline_msec: int = Time.get_ticks_msec() + 1
	await _wait_past_monotonic_deadline(latest_deadline_msec)
	domain.pump()
	assert_false(completion.is_successful())
	assert_eq(
		completion.get_error(),
		"resource_service_retirement_timeout"
	)
	assert_false(domain.is_accepting_requests())
	lease.release()
	domain.pump()
	assert_eq(
		domain.get_current_generation(),
		1,
		"失败后不能迟到自动提交。"
	)
	var retry: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	domain.pump()
	assert_true(retry.is_successful())
	assert_true(domain.is_accepting_requests())
	domain.dispose()


func test_in_flight_new_requests_and_late_results_keep_separate_generations() -> void:
	var old_resource: Resource = Resource.new()
	var new_resource: Resource = Resource.new()
	var domain: GFResourceServiceDomain = _domain(GFResourceServiceDomain.Mode.IN_FLIGHT, old_resource)
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	domain.pump()
	assert_eq(
		old_lease.get_service_generation(),
		1
	)
	assert_eq(
		new_lease.get_service_generation(),
		2
	)
	assert_same(
		old_lease.get_resource(),
		old_resource
	)
	assert_same(
		new_lease.get_resource(),
		new_resource
	)
	assert_true(completion.is_pending())
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		2
	)
	old_lease.release()
	domain.pump()
	assert_true(completion.is_successful())
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		1
	)
	new_lease.release()
	domain.dispose()


func test_broker_queue_admitted_before_switch_stays_on_old_generation() -> void:
	var old_resource: Resource = Resource.new()
	var old_second: Resource = Resource.new()
	var broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		broker.configure({ RESOURCE_PATH: old_resource, SECOND_PATH: old_second }),
		OK
	)
	broker.max_active_requests = 1
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var first: GFResourceLease = domain.request(RESOURCE_PATH)
	var queued: GFResourceLease = domain.request(SECOND_PATH)
	assert_eq(
		queued.get_status(),
		GFResourceLease.STATUS_QUEUED
	)
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	domain.pump()
	domain.pump()
	assert_same(
		queued.get_resource(),
		old_second
	)
	assert_eq(
		queued.get_service_generation(),
		1
	)
	first.release()
	queued.release()
	domain.pump()
	assert_true(completion.is_successful())
	domain.dispose()


func test_old_cancellation_never_cancels_same_path_new_generation() -> void:
	var new_resource: Resource = Resource.new()
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var _completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	old_lease.cancel(&"user_cancelled")
	domain.pump()
	assert_eq(
		old_lease.get_status(),
		GFResourceLease.STATUS_CANCELLED
	)
	assert_null(old_lease.get_resource())
	assert_same(
		new_lease.get_resource(),
		new_resource
	)
	old_lease.release()
	new_lease.release()
	domain.dispose()


func test_duplicate_terminal_delivery_cannot_replace_first_resource_or_failure() -> void:
	var first: Resource = Resource.new()
	var domain: GFResourceServiceDomain = _domain(GFResourceServiceDomain.Mode.IN_FLIGHT, first)
	var lease: GFResourceLease = domain.request(RESOURCE_PATH)
	domain.pump()
	lease.broker_mark_completed(Resource.new())
	lease.broker_mark_failed(ERR_BUG, "duplicate")
	lease.broker_mark_loading()
	assert_same(
		lease.get_resource(),
		first
	)
	assert_eq(
		lease.get_status(),
		GFResourceLease.STATUS_COMPLETED
	)
	lease.release()
	domain.dispose()


func test_second_switch_is_rejected_while_old_generation_remains_alive() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var first: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	var third: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_eq(
		domain.begin_switch(third).get_error(),
		"resource_service_switch_busy"
	)
	assert_true(third.can_claim_service_domain())
	domain.pump()
	lease.release()
	domain.pump()
	assert_true(first.is_successful())
	var next: GFAsyncCompletion = domain.begin_switch(third)
	domain.pump()
	assert_true(next.is_successful())
	domain.dispose()


func test_reentrant_switch_from_generation_notification_is_rejected() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var third: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var observed: Array[String] = []
	var callback: Callable = func(_old_generation: int, _new_generation: int) -> void:
		observed.append(domain.begin_switch(third).get_error())
	var _connected: Error = domain.generation_changed.connect(callback) as Error
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	assert_eq(
		observed,
		["resource_service_switch_busy"]
	)
	domain.generation_changed.disconnect(callback)
	domain.pump()
	assert_true(completion.is_successful())
	domain.dispose()
	third.dispose()


func test_completed_switch_notification_reentry_cannot_replace_returned_completion() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var third: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var reentrant_completions: Array[GFAsyncCompletion] = []
	var callback: Callable = func(_old_generation: int, new_generation: int) -> void:
		if new_generation == 2:
			domain.pump()
			reentrant_completions.append(domain.begin_switch(third))
	var _connected: Error = domain.generation_changed.connect(callback) as Error
	var first: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	domain.generation_changed.disconnect(callback)
	assert_eq(
		reentrant_completions.size(),
		1
	)
	assert_true(
		first.is_successful(),
		"外层调用必须返回已经完成的第一切换。"
	)
	assert_ne(
		first,
		reentrant_completions[0],
		"同步重入不能把第二任务的完成对象交给第一调用者。"
	)
	assert_true(reentrant_completions[0].is_pending())
	assert_eq(
		domain.get_current_generation(),
		3
	)
	domain.pump()
	assert_true(reentrant_completions[0].is_successful())
	domain.dispose()


func test_in_flight_timeout_keeps_new_entry_and_continues_old_retirement() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var new_resource: Resource = Resource.new()
	var completion: GFAsyncCompletion = domain.begin_switch(
		_snapshot(new_resource),
		1
	)
	var latest_deadline_msec: int = Time.get_ticks_msec() + 1
	await _wait_past_monotonic_deadline(latest_deadline_msec)
	domain.pump()
	assert_eq(
		completion.get_error(),
		"resource_service_retirement_timeout"
	)
	assert_true(domain.is_accepting_requests())
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	domain.pump()
	assert_same(
		new_lease.get_resource(),
		new_resource
	)
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		2
	)
	old_lease.release()
	domain.pump()
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		1
	)
	assert_false(
		completion.is_successful(),
		"迟到物理收尾不改写已报告的期限失败。"
	)
	new_lease.release()
	domain.dispose()


func test_asset_lane_queue_and_late_handle_preserve_old_generation() -> void:
	var old_resource: Resource = Resource.new()
	var old_second: Resource = Resource.new()
	var old_broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		old_broker.configure({ RESOURCE_PATH: old_resource, SECOND_PATH: old_second }),
		OK
	)
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(old_broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var assets: GFAssetUtility = _assets(domain)
	var handles: Array[GFAssetHandle] = []
	var callback: Callable = func(handle: GFAssetHandle) -> void:
		handles.append(handle)
	_asset_requests.request_handle(
		assets,
		RESOURCE_PATH,
		callback,
		"",
		null,
		&"",
		{ "serial_lane_id": &"lane" }
	)
	_asset_requests.request_handle(
		assets,
		SECOND_PATH,
		callback,
		"",
		null,
		&"",
		{ "serial_lane_id": &"lane" }
	)
	assert_eq(
		GFVariantData.get_option_int(
			assets.get_debug_snapshot(),
			"queued_count"
		),
		1
	)
	var new_resource: Resource = Resource.new()
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	var new_handles: Array[GFAssetHandle] = []
	_asset_requests.request_handle(
		assets,
		RESOURCE_PATH,
		func(handle: GFAssetHandle) -> void:
			new_handles.append(handle)
	)
	for _iteration: int in range(5):
		assets.tick()
	assert_eq(
		handles.size(),
		2
	)
	assert_same(
		handles[0].get_resource(),
		old_resource
	)
	assert_same(
		handles[1].get_resource(),
		old_second
	)
	assert_eq(
		handles[0].get_service_generation(),
		1
	)
	assert_eq(
		handles[1].get_service_generation(),
		1
	)
	assert_eq(
		new_handles.size(),
		1
	)
	assert_eq(
		new_handles[0].get_service_generation(),
		2
	)
	assert_same(
		new_handles[0].get_resource(),
		new_resource
	)
	assert_same(
		assets.get_cached(RESOURCE_PATH),
		new_resource
	)
	assert_true(
		completion.is_pending(),
		"已完成 Asset 句柄仍须保留旧代。"
	)
	for handle: GFAssetHandle in handles:
		assert_true(handle.release())
	domain.pump()
	assert_true(completion.is_successful())
	assert_true(new_handles[0].release())
	assets.dispose()
	domain.dispose()


func test_asset_path_reference_counts_and_release_signals_include_both_generations() -> void:
	for release_new_generation_first: bool in [true, false]:
		var old_resource: Resource = Resource.new()
		var new_resource: Resource = Resource.new()
		var domain: GFResourceServiceDomain = _domain(GFResourceServiceDomain.Mode.IN_FLIGHT, old_resource)
		var assets: GFAssetUtility = _assets(domain)
		var alias_path: String = "res://service_domain/./value.tres"
		var old_handles: Array[GFAssetHandle] = [
			_asset_requests.acquire(
				assets,
				RESOURCE_PATH,
				null,
				&"",
				"",
				old_resource
			),
			_asset_requests.acquire(assets, alias_path),
		]
		assert_eq(
			assets.get_asset_reference_count(RESOURCE_PATH),
			2
		)
		var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
		assert_eq(
			assets.get_asset_reference_count(RESOURCE_PATH),
			2,
			"换代后尚未获取新句柄时，公开路径仍须计入旧代的两个句柄。"
		)
		var new_handles: Array[GFAssetHandle] = [
			_asset_requests.acquire(
				assets,
				RESOURCE_PATH,
				null,
				&"",
				"",
				new_resource
			),
			_asset_requests.acquire(assets, RESOURCE_PATH),
		]
		assert_eq(
			assets.get_asset_reference_count(RESOURCE_PATH),
			4,
			"同路径引用须聚合两代。"
		)
		assert_eq(
			assets.get_asset_reference_count(alias_path),
			4,
			"查询别名须采用同一规范公开路径。"
		)
		assert_true(
			completion.is_pending(),
			"旧代句柄仍持有资源时不能完成收尾。"
		)
		for old_handle: GFAssetHandle in old_handles:
			assert_same(
				old_handle.get_resource(),
				old_resource
			)
			assert_eq(
				old_handle.get_service_generation(),
				1
			)
		for new_handle: GFAssetHandle in new_handles:
			assert_same(
				new_handle.get_resource(),
				new_resource
			)
			assert_eq(
				new_handle.get_service_generation(),
				2
			)

		var observed_counts: Array[int] = []
		var on_released: Callable = func(released_path: String, reference_count: int) -> void:
			var released_identity: GFResourceIdentity = GFResourceIdentity.from_path(
				released_path,
				&"",
				"",
				{ "check_exists": false }
			)
			assert_eq(released_identity.canonical_path, RESOURCE_PATH)
			observed_counts.append(reference_count)
		var connect_error: Error = assets.asset_handle_released.connect(on_released) as Error
		assert_eq(connect_error, OK)
		var release_order: Array[GFAssetHandle] = []
		release_order.append_array(new_handles if release_new_generation_first else old_handles)
		release_order.append_array(old_handles if release_new_generation_first else new_handles)
		var expected_counts: Array[int] = []
		for handle_index: int in range(release_order.size()):
			assert_true(release_order[handle_index].release())
			var expected_remaining: int = release_order.size() - handle_index - 1
			expected_counts.append(expected_remaining)
			assert_eq(
				assets.get_asset_reference_count(RESOURCE_PATH),
				expected_remaining,
				"任一代的归还只能扣减该句柄，路径查询仍须包括另一代。"
			)
			assert_eq(
				observed_counts,
				expected_counts,
				"释放信号须报告同路径全部代次的剩余引用。"
			)
		assets.asset_handle_released.disconnect(on_released)
		domain.pump()
		assert_true(completion.is_successful())
		assets.dispose()
		domain.dispose()


func test_asset_registered_uid_and_resource_path_share_cross_generation_reference_counts() -> void:
	var resource_path: String = "res://addons/gf/standard/utilities/assets/gf_resource_identity.gd"
	var registered_uid: int = ResourceLoader.get_resource_uid(resource_path)
	assert_ne(
		registered_uid,
		ResourceUID.INVALID_ID,
		"已有脚本 fixture 必须提供可用的导入 UID。"
	)
	if registered_uid == ResourceUID.INVALID_ID:
		return
	assert_true(
		ResourceUID.has_id(registered_uid),
		"测试仅使用已有 UID 登记，不改写全局表。"
	)
	var uid_path: String = ResourceUID.id_to_text(registered_uid)
	var old_resource: Resource = Resource.new()
	var new_resource: Resource = Resource.new()
	var old_broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		old_broker.configure({ resource_path: old_resource }),
		OK
	)
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(old_broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var assets: GFAssetUtility = _assets(domain)
	var old_handle: GFAssetHandle = _asset_requests.acquire(
		assets,
		uid_path,
		null,
		&"",
		"",
		old_resource
	)
	var new_broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		new_broker.configure({ uid_path: new_resource }),
		OK
	)
	var completion: GFAsyncCompletion = domain.begin_switch(new_broker)
	var new_handle: GFAssetHandle = _asset_requests.acquire(
		assets,
		resource_path,
		null,
		&"",
		"",
		new_resource
	)
	assert_eq(
		assets.get_asset_reference_count(uid_path),
		2
	)
	assert_eq(
		assets.get_asset_reference_count(resource_path),
		2,
		"已登记 UID 与 res:// 查询须合并全部代次。"
	)
	watch_signals(assets)

	assert_true(old_handle.release())
	assert_signal_emitted_with_parameters(
		assets,
		"asset_handle_released",
		[uid_path, 1]
	)
	assert_eq(
		assets.get_asset_reference_count(uid_path),
		1
	)
	assert_eq(
		assets.get_asset_reference_count(resource_path),
		1
	)
	assert_same(
		new_handle.get_resource(),
		new_resource
	)
	assert_true(new_handle.release())
	assert_signal_emitted_with_parameters(
		assets,
		"asset_handle_released",
		[resource_path, 0]
	)
	assert_eq(
		assets.get_asset_reference_count(uid_path),
		0
	)
	assert_eq(
		assets.get_asset_reference_count(resource_path),
		0
	)
	domain.pump()
	assert_true(completion.is_successful())
	assert_true(
		ResourceUID.has_id(registered_uid),
		"归还句柄不应删除已有的全局 UID 登记。"
	)
	assets.dispose()
	domain.dispose()


func test_asset_owner_release_reports_remaining_path_references_across_generations() -> void:
	var old_resource: Resource = Resource.new()
	var new_resource: Resource = Resource.new()
	var domain: GFResourceServiceDomain = _domain(GFResourceServiceDomain.Mode.IN_FLIGHT, old_resource)
	var assets: GFAssetUtility = _assets(domain)
	var handle_owner: RefCounted = RefCounted.new()
	var owned_handles: Array[GFAssetHandle] = [
		_asset_requests.acquire(
			assets,
			RESOURCE_PATH,
			handle_owner,
			&"",
			"",
			old_resource
		),
		_asset_requests.acquire(
			assets,
			RESOURCE_PATH,
			handle_owner
		),
	]
	var old_survivor: GFAssetHandle = _asset_requests.acquire(assets, RESOURCE_PATH)
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	owned_handles.append(
		_asset_requests.acquire(
			assets,
			RESOURCE_PATH,
			handle_owner,
			&"",
			"",
			new_resource
		)
	)
	owned_handles.append(
		_asset_requests.acquire(
			assets,
			RESOURCE_PATH,
			handle_owner
		)
	)
	var new_survivor: GFAssetHandle = _asset_requests.acquire(assets, RESOURCE_PATH)
	assert_eq(
		assets.get_asset_reference_count(RESOURCE_PATH),
		6
	)

	var observed_counts: Array[int] = []
	var on_released: Callable = func(released_path: String, reference_count: int) -> void:
		assert_eq(released_path, RESOURCE_PATH)
		var public_counts: Dictionary = GFVariantData.get_option_dictionary(
			assets.get_debug_snapshot(),
			"reference_counts"
		)
		assert_eq(
			reference_count,
			GFVariantData.get_option_int(public_counts, released_path),
			"owner 释放中的每次信号都须与已提交的同路径总引用数一致。"
		)
		observed_counts.append(reference_count)
	var connect_error: Error = assets.asset_handle_released.connect(on_released) as Error
	assert_eq(connect_error, OK)
	assert_eq(
		assets.release_owner(handle_owner),
		4,
		"owner 释放须消费两代中的四个所属句柄。"
	)
	assert_eq(
		assets.get_asset_reference_count(RESOURCE_PATH),
		2,
		"两代各自未归属该 owner 的句柄必须保留。"
	)
	assert_false(
		observed_counts.is_empty(),
		"owner 释放须通知路径剩余引用。"
	)
	if not observed_counts.is_empty():
		assert_eq(
			observed_counts[observed_counts.size() - 1],
			2
		)
	assets.asset_handle_released.disconnect(on_released)
	for owned_handle: GFAssetHandle in owned_handles:
		assert_true(owned_handle.is_released())
	assert_true(old_survivor.is_valid())
	assert_true(new_survivor.is_valid())
	assert_true(old_survivor.release())
	assert_eq(
		assets.get_asset_reference_count(RESOURCE_PATH),
		1
	)
	assert_true(new_survivor.release())
	assert_eq(
		assets.get_asset_reference_count(RESOURCE_PATH),
		0
	)
	domain.pump()
	assert_true(completion.is_successful())
	assets.dispose()
	domain.dispose()


func test_controlled_switch_waits_for_asset_handle_and_rejects_cached_new_loads() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.CONTROLLED,
		Resource.new()
	)
	var assets: GFAssetUtility = _assets(domain)
	var handles: Array[GFAssetHandle] = []
	_asset_requests.request_handle(
		assets,
		RESOURCE_PATH,
		func(handle: GFAssetHandle) -> void:
			handles.append(handle)
	)
	assets.tick()
	assert_eq(
		handles.size(),
		1
	)
	var completion: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	var rejected: Array[Resource] = []
	_asset_requests.request(
		assets,
		RESOURCE_PATH,
		func(resource: Resource) -> void:
			rejected.append(resource)
	)
	assert_eq(
		rejected.size(),
		1
	)
	assert_null(rejected[0])
	domain.pump()
	assert_true(completion.is_pending())
	assert_true(handles[0].release())
	domain.pump()
	assert_true(completion.is_successful())
	assets.dispose()
	domain.dispose()


func test_asset_generation_cancellation_does_not_drop_new_generation_callback() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var assets: GFAssetUtility = _assets(domain)
	var old_results: Array[Resource] = []
	var new_results: Array[Resource] = []
	_asset_requests.request(
		assets,
		RESOURCE_PATH,
		func(resource: Resource) -> void:
			old_results.append(resource)
	)
	var new_resource: Resource = Resource.new()
	var _completion: GFAsyncCompletion = domain.begin_switch(_snapshot(new_resource))
	_asset_requests.request(
		assets,
		RESOURCE_PATH,
		func(resource: Resource) -> void:
			new_results.append(resource)
	)
	_asset_requests.cancel(
		assets,
		RESOURCE_PATH,
		"",
		1
	)
	assets.tick()
	assert_true(old_results.is_empty())
	assert_eq(
		new_results.size(),
		1
	)
	assert_same(
		new_results[0],
		new_resource
	)
	assets.dispose()
	domain.dispose()


func test_close_during_switch_drains_both_generations_without_replay() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var switching: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var closing: GFAsyncCompletion = domain.begin_quiesce(scope)
	assert_false(switching.is_successful())
	assert_false(domain.is_accepting_requests())
	var candidate: GFResourceSnapshotBroker = _snapshot(Resource.new())
	assert_eq(
		domain.begin_switch(candidate).get_error(),
		"resource_service_domain_closing_or_unconfigured"
	)
	assert_true(closing.is_pending())
	assert_eq(
		old_lease.get_status(),
		GFResourceLease.STATUS_COMPLETED
	)
	assert_eq(
		new_lease.get_status(),
		GFResourceLease.STATUS_COMPLETED
	)
	old_lease.release()
	domain.pump()
	assert_true(closing.is_pending())
	new_lease.release()
	domain.pump()
	assert_true(closing.is_successful())
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		0
	)
	candidate.dispose()


func test_cancelled_close_wait_does_not_destroy_unreleased_generation() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var scope: GFAsyncScope = GFAsyncScope.new()
	var closing: GFAsyncCompletion = domain.begin_quiesce(scope)
	var _cancelled: bool = scope.cancel(&"deadline")
	domain.dispose()
	assert_false(closing.is_successful())
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		1
	)
	assert_not_null(lease.get_resource())
	lease.release()
	domain.pump()
	assert_eq(
		GFVariantData.get_option_int(
			domain.get_debug_snapshot(),
			"live_generations"
		),
		0
	)
	await get_tree().process_frame
	await get_tree().process_frame


func test_architecture_timeout_preserves_lease_only_owner_and_retires_guard_without_external_pump() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var broker: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var broker_ref: WeakRef = weakref(broker)
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var domain_ref: WeakRef = weakref(domain)
	assert_true(await architecture.register_utility_instance(domain))
	assert_true(await architecture.init())
	var old_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var _switching: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	var new_lease: GFResourceLease = domain.request(RESOURCE_PATH)
	var result: GFArchitectureShutdownResult = await architecture.shutdown_async(null, 0.001)
	assert_eq(
		result.get_status(),
		GFArchitectureShutdownResult.Status.TIMED_OUT
	)
	assert_eq(
		GFVariantData.get_option_string(
			domain.get_debug_snapshot(),
			"retirement_pump"
		),
		"scene_tree"
	)
	var guard_ref: WeakRef = _retirement_guard_reference(domain)
	assert_not_null(guard_ref)
	domain.dispose()
	assert_same(
		_weak_object(_retirement_guard_reference(domain)),
		_weak_object(guard_ref),
		"托管收尾只创建一个推进器。"
	)
	broker = null
	domain = null
	architecture = null
	await get_tree().process_frame
	assert_not_null(_weak_object(domain_ref))
	assert_not_null(_weak_object(broker_ref))
	assert_not_null(old_lease.get_resource())
	assert_not_null(new_lease.get_resource())
	old_lease.release()
	await get_tree().process_frame
	assert_null(
		_weak_object(broker_ref),
		"旧租约归还后旧 Broker 可独立退出。"
	)
	assert_not_null(
		_weak_object(domain_ref),
		"新代租约仍保留域。"
	)
	new_lease.release()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_weak_object(domain_ref))
	assert_null(_weak_object(guard_ref))


func test_asset_handle_only_owner_survives_domain_dispose_until_release() -> void:
	var broker: GFResourceSnapshotBroker = _snapshot(Resource.new())
	var broker_ref: WeakRef = weakref(broker)
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(broker, GFResourceServiceDomain.Mode.IN_FLIGHT),
		OK
	)
	var domain_ref: WeakRef = weakref(domain)
	var assets: GFAssetUtility = _assets(domain)
	var handles: Array[GFAssetHandle] = []
	_asset_requests.request_handle(
		assets,
		RESOURCE_PATH,
		func(handle: GFAssetHandle) -> void:
			handles.append(handle)
	)
	assets.tick()
	assets.release_dependencies()
	assets = null
	domain.dispose()
	var guard_ref: WeakRef = _retirement_guard_reference(domain)
	broker = null
	domain = null
	await get_tree().process_frame
	assert_not_null(_weak_object(domain_ref))
	assert_not_null(_weak_object(broker_ref))
	assert_true(handles[0].is_valid())
	var _released_without_utility: bool = handles[0].release()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_weak_object(domain_ref))
	assert_null(_weak_object(broker_ref))
	assert_null(_weak_object(guard_ref))


func test_late_preload_group_pin_targets_old_generation_cache_only() -> void:
	var domain: GFResourceServiceDomain = _domain(
		GFResourceServiceDomain.Mode.IN_FLIGHT,
		Resource.new()
	)
	var assets: GFAssetUtility = _assets(domain)
	assets.preload_group_async(
		&"old",
		[RESOURCE_PATH]
	)
	var _switching: GFAsyncCompletion = domain.begin_switch(_snapshot(Resource.new()))
	_asset_requests.request(
		assets,
		RESOURCE_PATH,
		func(_resource: Resource) -> void:
			pass
	)
	assets.tick()
	assert_false(
		assets.is_cache_pinned(RESOURCE_PATH),
		"旧代预热回调不得 pin 当前代。"
	)
	assert_eq(
		assets.get_group_paths(&"old"),
		PackedStringArray([RESOURCE_PATH])
	)
	assets.unload_group(&"old", true)
	assert_not_null(
		assets.get_cached(RESOURCE_PATH),
		"卸载旧组不得清掉当前代缓存。"
	)
	assets.dispose()
	domain.dispose()


func test_snapshot_mapping_is_frozen_but_resource_data_is_not_falsely_claimed_immutable() -> void:
	var original: Resource = Resource.new()
	var mapping: Dictionary = { RESOURCE_PATH: original }
	var broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		broker.configure(mapping),
		OK
	)
	mapping[RESOURCE_PATH] = Resource.new()
	assert_eq(
		broker.configure(mapping),
		ERR_ALREADY_IN_USE
	)
	var lease: GFResourceLease = broker.request(RESOURCE_PATH)
	broker.pump()
	assert_same(
		lease.get_resource(),
		original
	)
	lease.release()
	broker.dispose()


func test_snapshot_mapping_rejects_malformed_uid_without_committing_partial_mapping() -> void:
	var expected_resource: Resource = Resource.new()
	var broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		broker.configure({ RESOURCE_PATH: expected_resource, "uid://bad!uid": Resource.new() }),
		ERR_INVALID_PARAMETER,
		"包含无效 UID 语法的映射必须整体拒绝。"
	)
	assert_false(
		broker.is_configured(),
		"无效后项不能提交此前已准备的正常映射。"
	)
	assert_eq(
		broker.configure({ RESOURCE_PATH: expected_resource }),
		OK,
		"原子拒绝后应允许有效配置重试。"
	)
	var lease: GFResourceLease = broker.request(RESOURCE_PATH)
	broker.pump()
	assert_same(
		lease.get_resource(),
		expected_resource
	)
	lease.release()
	broker.dispose()


func test_snapshot_mapping_accepts_unregistered_logical_uid_without_registration() -> void:
	var logical_uid_id: int = ResourceUID.create_id()
	var logical_uid_path: String = ResourceUID.id_to_text(logical_uid_id)
	assert_ne(logical_uid_id, ResourceUID.INVALID_ID)
	assert_false(
		ResourceUID.has_id(logical_uid_id),
		"逻辑 UID 测试不能依赖全局 ResourceUID 注册。"
	)
	var expected_resource: Resource = Resource.new()
	var broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	var configuration_error: Error = broker.configure({ logical_uid_path: expected_resource })
	assert_eq(
		configuration_error,
		OK,
		"快照映射须允许没有磁盘登记的逻辑 uid:// 身份。"
	)
	if configuration_error != OK:
		broker.dispose()
		return

	var lease: GFResourceLease = broker.request(logical_uid_path, "Resource")
	broker.pump()
	assert_eq(
		lease.get_status(),
		GFResourceLease.STATUS_COMPLETED
	)
	assert_same(
		lease.get_resource(),
		expected_resource,
		"逻辑 UID 应交付冻结映射中的 Resource。"
	)
	assert_false(
		ResourceUID.has_id(logical_uid_id),
		"请求交付不得注册或改写全局 UID。"
	)
	lease.release()
	broker.dispose()


func _snapshot(resource: Resource) -> GFResourceSnapshotBroker:
	var broker: GFResourceSnapshotBroker = GFResourceSnapshotBroker.new()
	assert_eq(
		broker.configure({ RESOURCE_PATH: resource }),
		OK
	)
	return broker


func _domain(mode: GFResourceServiceDomain.Mode, resource: Resource) -> GFResourceServiceDomain:
	var domain: GFResourceServiceDomain = GFResourceServiceDomain.new()
	assert_eq(
		domain.configure(
			_snapshot(resource),
			mode
		),
		OK
	)
	return domain


func _assets(domain: GFResourceServiceDomain) -> GFAssetUtility:
	var assets: GFAssetUtility = GFAssetUtility.new()
	assets.init()
	assert_eq(
		assets.set_resource_service_domain(domain),
		OK
	)
	return assets


func _retirement_guard_reference(domain: GFResourceServiceDomain) -> WeakRef:
	for child: Node in get_tree().root.get_children():
		if child is GFResourceServiceRetirement:
			var guard: GFResourceServiceRetirement = child
			if guard.owns_domain(domain):
				return weakref(guard)
	return null


func _weak_object(reference: WeakRef) -> Object:
	if reference == null:
		return null
	var value: Variant = reference.get_ref()
	return value if value is Object else null


func _wait_past_monotonic_deadline(deadline_msec: int) -> void:
	# Headless 的模拟 delta 可先于真实时钟推进；期限必须与生产逻辑使用同一时钟。
	var wait_limit_msec: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() <= deadline_msec and Time.get_ticks_msec() < wait_limit_msec:
		await get_tree().process_frame
	assert_gt(
		Time.get_ticks_msec(),
		deadline_msec,
		"在有界等待内必须越过真实单调期限后才测试 pump 超时。"
	)


func after_each() -> void:
	_asset_requests.close()
