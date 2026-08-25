# 测试 Save Profile 活动身份、恢复与切换事务。
extends GutTest


# --- 私有变量 ---

var _clock: GFManualClock
var _storage: GFSaveProfileTransactionTestSupport.ControlledStorage
var _profile_utility: GFSaveProfileUtility
var _coordinator: GFSaveProfileTransactionCoordinator
var _terminal_count: int = 0


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_clock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	_storage = GFSaveProfileTransactionTestSupport.ControlledStorage.new()
	_profile_utility = GFSaveProfileUtility.new().setup(_storage, _clock)
	_storage.driver = _profile_utility
	_coordinator = GFSaveProfileTransactionCoordinator.new().setup(_profile_utility)
	_terminal_count = 0


func after_each() -> void:
	if _coordinator != null:
		_coordinator.dispose()
	_coordinator = null
	if _profile_utility != null:
		_profile_utility.dispose()
	_profile_utility = null
	if _storage != null:
		_storage.driver = null
		_storage.dispose()
	_storage = null
	_clock = null


# --- 公共方法 ---

func test_registration_uses_exact_ordered_provider_topology_and_rejects_overlap() -> void:
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 1)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 2)
	)
	var third: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"third", 3)
	)
	var exact_providers: Array[GFSaveSectionProvider] = [first, second]
	var reversed_providers: Array[GFSaveSectionProvider] = [second, first]
	var partial_providers: Array[GFSaveSectionProvider] = [first, third]
	var first_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.topology.first",
		exact_providers
	)
	var second_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.topology.second",
		exact_providers
	)
	var reversed_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.topology.reversed",
		reversed_providers
	)
	var partial_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.topology.partial",
		partial_providers
	)

	assert_true(_register(first_profile))
	assert_true(_register(second_profile), "完全相同且顺序一致的 Provider 应共享 domain。")
	var first_snapshot: Dictionary = _coordinator.get_domain_state_snapshot(
		first_profile.profile_id
	)
	var second_snapshot: Dictionary = _coordinator.get_domain_state_snapshot(
		second_profile.profile_id
	)
	assert_eq(
		GFVariantData.get_option_int(first_snapshot, "domain_id"),
		GFVariantData.get_option_int(second_snapshot, "domain_id")
	)
	var reversed_report: Dictionary = _coordinator.register_profile(reversed_profile)
	assert_false(
		GFVariantData.get_option_bool(reversed_report, "registered"),
		(
			"同一 Provider 的重排不得伪装成相同 topology；provider ids=%s/%s，report=%s。"
			% [first.get_instance_id(), second.get_instance_id(), reversed_report]
		)
	)
	var partial_report: Dictionary = _coordinator.register_profile(partial_profile)
	assert_false(
		GFVariantData.get_option_bool(partial_report, "registered"),
		"部分重叠必须失败关闭，避免双重权威锁域；report=%s。" % partial_report
	)
	assert_true(
		_profile_utility.get_profile_state_snapshot(reversed_profile.profile_id).is_empty(),
		"Coordinator 注册回滚不得留下低层孤儿 Profile。"
	)
	assert_true(_profile_utility.get_profile_state_snapshot(partial_profile.profile_id).is_empty())


func test_unregister_inactive_profile_after_shared_domain_transaction_settles() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var active_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.unregister.active",
		providers
	)
	var inactive_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.unregister.inactive",
		providers
	)
	assert_true(_register(active_profile))
	assert_true(_register(inactive_profile))

	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		active_profile.profile_id
	)
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_count(), 1)
	assert_false(
		_coordinator.unregister_profile(inactive_profile.profile_id),
		"共享 domain 的事务尚未结算时仍不得注销空闲成员。"
	)
	assert_false(
		_coordinator.get_domain_state_snapshot(inactive_profile.profile_id).is_empty()
	)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			active_profile,
			{ &"state": { "value": 17 } }
		)
	))
	assert_true(activation.is_completed())
	assert_true(activation.get_result().is_successful())

	var domain_before: Dictionary = _coordinator.get_domain_state_snapshot(
		active_profile.profile_id
	)
	var domain_id: int = GFVariantData.get_option_int(domain_before, "domain_id")
	assert_eq(
		_coordinator.get_active_profile_id(inactive_profile.profile_id),
		active_profile.profile_id
	)
	assert_true(
		_coordinator.unregister_profile(inactive_profile.profile_id),
		"活动 sibling 不应阻止注销已空闲的非活动 Profile。"
	)
	assert_true(
		_coordinator.get_domain_state_snapshot(inactive_profile.profile_id).is_empty()
	)
	assert_true(
		_profile_utility.get_profile_state_snapshot(inactive_profile.profile_id).is_empty()
	)
	var domain_after: Dictionary = _coordinator.get_domain_state_snapshot(
		active_profile.profile_id
	)
	assert_eq(GFVariantData.get_option_int(domain_after, "domain_id"), domain_id)
	assert_eq(
		GFVariantData.get_option_string_name(domain_after, "active_profile_id"),
		active_profile.profile_id
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(domain_after, "profile_ids"),
		PackedStringArray([String(active_profile.profile_id)])
	)
	assert_false(
		_coordinator.unregister_profile(active_profile.profile_id),
		"当前活动 Profile 自身仍必须拒绝注销。"
	)
	assert_false(
		_coordinator.get_domain_state_snapshot(active_profile.profile_id).is_empty()
	)
	assert_false(
		_profile_utility.get_profile_state_snapshot(active_profile.profile_id).is_empty()
	)


func test_disjoint_provider_domains_activate_concurrently() -> void:
	var first_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 0)
	)
	var second_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 0)
	)
	var first_providers: Array[GFSaveSectionProvider] = [first_provider]
	var second_providers: Array[GFSaveSectionProvider] = [second_provider]
	var first_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.concurrent.first",
		first_providers
	)
	var second_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.concurrent.second",
		second_providers
	)
	assert_true(_register(first_profile))
	assert_true(_register(second_profile))
	var first_snapshot: Dictionary = _coordinator.get_domain_state_snapshot(
		first_profile.profile_id
	)
	var second_snapshot: Dictionary = _coordinator.get_domain_state_snapshot(
		second_profile.profile_id
	)
	assert_ne(
		GFVariantData.get_option_int(first_snapshot, "domain_id"),
		GFVariantData.get_option_int(second_snapshot, "domain_id")
	)

	var first_operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		first_profile.profile_id
	)
	var second_operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		second_profile.profile_id
	)
	_profile_utility.tick(0.0)

	assert_eq(_storage.get_pending_load_count(), 2)
	assert_eq(_storage.max_active_io_count, 2, "不相交 domain 不应被全局串行锁阻塞。")
	_storage.complete_load_for_file(
		first_profile.file_name,
		GFSaveProfileTransactionTestSupport.read_success(
			GFSaveProfileTransactionTestSupport.make_document(
				first_profile,
				{ &"first": { "value": 11 } }
			)
		)
	)
	_storage.complete_load_for_file(
		second_profile.file_name,
		GFSaveProfileTransactionTestSupport.read_success(
			GFSaveProfileTransactionTestSupport.make_document(
				second_profile,
				{ &"second": { "value": 22 } }
			)
		)
	)

	assert_true(first_operation.get_result().is_successful())
	assert_true(second_operation.get_result().is_successful())
	assert_eq(first_provider.value, 11)
	assert_eq(second_provider.value, 22)


func test_activate_strictly_loads_existing_profile_before_publishing_identity() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 3)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.activate",
		providers
	)
	assert_true(_register(profile))

	var operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id,
		{ "source": "test" },
		{ "trace": 17 }
	)
	_profile_utility.tick(0.0)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), &"")
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{ &"state": { "value": 41 } }
		)
	))

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_ACTIVATED)
	assert_eq(result.get_active_profile_before(), &"")
	assert_eq(result.get_active_profile_after(), profile.profile_id)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), profile.profile_id)
	assert_eq(provider.value, 41)


func test_missing_activate_requires_lease_before_bootstrap_can_activate() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 7)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap",
		providers
	)
	profile.recovery_policy.missing_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	assert_true(_register(profile))

	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_failure(
		ERR_FILE_NOT_FOUND,
		"Injected missing profile.",
		GFStorageReadResult.FailureKind.NOT_FOUND
	))
	var activation_result: GFSaveProfileTransactionResult = activation.get_result()
	var recovery_lease: GFSaveProfileRecoveryLease = activation_result.get_recovery_lease()
	assert_eq(
		activation_result.get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED
	)
	assert_not_null(recovery_lease, "严格激活不得走 use-current-state 隐式恢复。")
	assert_eq(recovery_lease.get_reason(), GFSaveProfileRecoveryLease.REASON_MISSING)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), &"")
	var epoch_before_invalid_request: int = GFVariantData.get_option_int(
		_coordinator.get_domain_state_snapshot(profile.profile_id),
		"transaction_epoch"
	)
	var uninitialized_request: GFSaveProfileRequest = GFSaveProfileRequest.new()
	var rejected_bootstrap: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_profile(recovery_lease, uninitialized_request)
	)
	assert_eq(
		rejected_bootstrap.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST
	)
	assert_false(uninitialized_request.is_claimed())
	assert_true(recovery_lease.is_available())
	assert_eq(
		GFVariantData.get_option_int(
			_coordinator.get_domain_state_snapshot(profile.profile_id),
			"transaction_epoch"
		),
		epoch_before_invalid_request,
		"无效 request 必须在 lease claim 与 domain epoch 推进前失败。"
	)

	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{ "reason": "bootstrap" },
		{},
		{ "trace": 1 }
	)
	var bootstrap: GFSaveProfileTransactionOperation = _coordinator.bootstrap_profile(
		recovery_lease,
		request
	)
	_profile_utility.tick(0.0)
	assert_true(request.is_claimed())
	assert_true(recovery_lease.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), &"")
	_storage.complete_next_save(OK)

	assert_true(bootstrap.get_result().is_successful())
	assert_eq(
		bootstrap.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BOOTSTRAPPED
	)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), profile.profile_id)
	assert_eq(
		GFSaveProfileTransactionTestSupport.get_saved_value(_storage.save_calls[0], &"state"),
		7
	)
	var retained_activation_result: GFSaveProfileTransactionResult = activation.get_result()
	assert_eq(
		retained_activation_result.get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED
	)
	assert_same(retained_activation_result.get_recovery_lease(), recovery_lease)
	assert_true(retained_activation_result.get_recovery_lease().is_claimed())


func test_missing_activate_bounds_stage_error_and_preserves_recovery_lease() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 7)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.long_missing_error",
		providers
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	_profile_utility.tick(0.0)
	var storage_error: String = "missing-profile-prefix:" + "x".repeat(4_096)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_failure(
		ERR_FILE_NOT_FOUND,
		storage_error,
		GFStorageReadResult.FailureKind.NOT_FOUND
	))

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(
		result.get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED,
		"超长底层错误不得使事务结果契约降级为 disposed。"
	)
	var recovery_lease: GFSaveProfileRecoveryLease = result.get_recovery_lease()
	assert_not_null(recovery_lease)
	if recovery_lease == null:
		return
	assert_true(recovery_lease.is_available(), "有界化证据后仍必须保留显式恢复能力。")
	var evidence_error: String = GFVariantData.get_option_string(
		result.get_stage_evidence(),
		"error"
	)
	assert_eq(evidence_error.length(), 2_048)
	assert_eq(evidence_error, storage_error.left(2_048), "证据截断必须稳定保留错误前缀。")


func test_recovery_save_rejection_preserves_lease_request_and_domain_epoch() -> void:
	var active_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"active", 11)
	)
	var recovery_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"recovery", 22)
	)
	var active_providers: Array[GFSaveSectionProvider] = [active_provider]
	var recovery_providers: Array[GFSaveSectionProvider] = [recovery_provider]
	var active_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.recovery_admission.active",
		active_providers
	)
	var recovery_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.recovery_admission.target",
		recovery_providers
	)
	assert_true(_register(active_profile))
	assert_true(_register(recovery_profile))
	_activate_existing(active_profile, { &"active": { "value": 11 } })

	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		recovery_profile.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_load_for_file(
		recovery_profile.file_name,
		GFSaveProfileTransactionTestSupport.read_failure(
			ERR_FILE_NOT_FOUND,
			"Injected missing recovery target.",
			GFStorageReadResult.FailureKind.NOT_FOUND
		)
	)
	var recovery_lease: GFSaveProfileRecoveryLease = (
		activation.get_result().get_recovery_lease()
	)
	assert_not_null(recovery_lease)
	assert_true(recovery_lease.is_available())
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "attempt": "retryable" }
	)
	var epoch_before_rejection: int = GFVariantData.get_option_int(
		_coordinator.get_domain_state_snapshot(recovery_profile.profile_id),
		"transaction_epoch"
	)
	var domain_before_rejection: Dictionary = _coordinator.get_domain_state_snapshot(
		recovery_profile.profile_id
	)
	var profile_before_rejection: Dictionary = (
		_profile_utility.get_profile_state_snapshot(recovery_profile.profile_id)
	)
	var rejected_operations: Array[GFSaveProfileTransactionOperation] = []
	active_provider.save_snapshot_callback = func() -> void:
		rejected_operations.append(_coordinator.bootstrap_profile(
			recovery_lease,
			request
		))
	active_provider.value = 12
	var active_save: GFSaveProfileOperation = _profile_utility.save_profile(
		active_profile.profile_id
	)

	_profile_utility.tick(0.0)
	active_provider.save_snapshot_callback = Callable()

	assert_eq(rejected_operations.size(), 1)
	if rejected_operations.is_empty():
		return
	assert_true(rejected_operations[0].is_completed())
	assert_eq(
		rejected_operations[0].get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BUSY
	)
	assert_false(request.is_claimed(), "底层准入拒绝不得消费恢复保存 request。")
	assert_true(recovery_lease.is_available(), "底层准入拒绝不得烧毁 Recovery Lease。")
	var domain_after_rejection: Dictionary = _coordinator.get_domain_state_snapshot(
		recovery_profile.profile_id
	)
	assert_eq(
		GFVariantData.get_option_int(
			domain_after_rejection,
			"transaction_epoch"
		),
		epoch_before_rejection,
		"未接纳的恢复保存不得推进 domain epoch。"
	)
	assert_eq(
		GFVariantData.get_option_int(domain_after_rejection, "domain_generation"),
		GFVariantData.get_option_int(domain_before_rejection, "domain_generation")
	)
	assert_eq(GFVariantData.get_option_int(domain_after_rejection, "transaction_id"), 0)
	assert_eq(
		GFVariantData.get_option_string_name(domain_after_rejection, "active_profile_id"),
		&""
	)
	var profile_after_rejection: Dictionary = (
		_profile_utility.get_profile_state_snapshot(recovery_profile.profile_id)
	)
	assert_eq(
		GFVariantData.get_option_int(profile_after_rejection, "generation"),
		GFVariantData.get_option_int(profile_before_rejection, "generation"),
		"未接纳的恢复保存不得分配底层 generation。"
	)
	assert_eq(_storage.get_pending_save_count(), 1, "只有回调外层 domain A 可以进入存储。")

	var retry: GFSaveProfileTransactionOperation = _coordinator.bootstrap_profile(
		recovery_lease,
		request
	)
	_profile_utility.tick(0.0)
	assert_true(request.is_claimed(), "同一 request 应可在回调退出后重试。")
	assert_true(recovery_lease.is_claimed(), "同一 Recovery Lease 应在实际准入后提交。")
	assert_eq(
		GFVariantData.get_option_int(
			_coordinator.get_domain_state_snapshot(recovery_profile.profile_id),
			"transaction_epoch"
		),
		epoch_before_rejection + 1
	)
	assert_eq(_storage.get_pending_save_count(), 2)
	_storage.complete_next_save(OK)
	assert_true(active_save.get_result().is_successful())
	_storage.complete_next_save(OK)
	assert_true(retry.get_result().is_successful(), "回调退出后的同 Lease/Request 重试应成功。")
	assert_eq(
		_coordinator.get_active_profile_id(recovery_profile.profile_id),
		recovery_profile.profile_id
	)
	assert_eq(
		rejected_operations[0].get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BUSY,
		"后续成功不得改写先前准入拒绝终态。"
	)


func test_recovery_result_remains_copyable_after_later_transaction_stales_lease() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 8)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.recovery_stale_copy",
		providers
	)
	assert_true(_register(profile))
	var first_activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_failure(
		ERR_FILE_NOT_FOUND,
		"Injected first missing profile.",
		GFStorageReadResult.FailureKind.NOT_FOUND
	))
	var first_result: GFSaveProfileTransactionResult = first_activation.get_result()
	var first_lease: GFSaveProfileRecoveryLease = first_result.get_recovery_lease()
	assert_not_null(first_lease)
	assert_true(first_lease.is_available())

	var second_activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	assert_true(first_lease.is_stale(), "后续 domain 事务必须使旧恢复能力失效。")
	var copied_after_stale: GFSaveProfileTransactionResult = first_activation.get_result()
	assert_not_null(copied_after_stale)
	assert_eq(
		copied_after_stale.get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED
	)
	assert_same(copied_after_stale.get_recovery_lease(), first_lease)
	assert_true(copied_after_stale.get_recovery_lease().is_stale())
	_profile_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_failure(
		ERR_FILE_NOT_FOUND,
		"Injected second missing profile.",
		GFStorageReadResult.FailureKind.NOT_FOUND
	))
	assert_eq(
		second_activation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED
	)


func test_corrupt_activate_requires_lease_before_adopt_can_activate() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 13)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.adopt",
		providers
	)
	profile.recovery_policy.corrupt_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
	assert_true(_register(profile))

	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_failure(
		ERR_FILE_CORRUPT,
		"Injected corrupt profile.",
		GFStorageReadResult.FailureKind.CORRUPT
	))
	var activation_result: GFSaveProfileTransactionResult = activation.get_result()
	var recovery_lease: GFSaveProfileRecoveryLease = activation_result.get_recovery_lease()
	assert_eq(
		activation_result.get_status(),
		GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED
	)
	assert_not_null(recovery_lease)
	assert_eq(recovery_lease.get_reason(), GFSaveProfileRecoveryLease.REASON_CORRUPT)
	var epoch_before_invalid_request: int = GFVariantData.get_option_int(
		_coordinator.get_domain_state_snapshot(profile.profile_id),
		"transaction_epoch"
	)
	var uninitialized_request: GFSaveProfileRequest = GFSaveProfileRequest.new()
	var rejected_adopt: GFSaveProfileTransactionOperation = _coordinator.adopt_profile(
		recovery_lease,
		uninitialized_request
	)
	assert_eq(
		rejected_adopt.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST
	)
	assert_false(uninitialized_request.is_claimed())
	assert_true(recovery_lease.is_available())
	assert_eq(
		GFVariantData.get_option_int(
			_coordinator.get_domain_state_snapshot(profile.profile_id),
			"transaction_epoch"
		),
		epoch_before_invalid_request
	)

	var adopt: GFSaveProfileTransactionOperation = _coordinator.adopt_profile(recovery_lease)
	_profile_utility.tick(0.0)
	assert_true(recovery_lease.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), &"")
	_storage.complete_next_save(OK)

	assert_true(adopt.get_result().is_successful())
	assert_eq(adopt.get_result().get_status(), GFSaveProfileTransactionResult.STATUS_ADOPTED)
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), profile.profile_id)


func test_switch_recovery_leases_bind_source_and_reject_legacy_or_wrong_reason_apis() -> void:
	var missing_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"missing", 10)
	)
	var corrupt_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"corrupt", 20)
	)
	var missing_providers: Array[GFSaveSectionProvider] = [missing_provider]
	var corrupt_providers: Array[GFSaveSectionProvider] = [corrupt_provider]
	var missing_source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery.missing_source",
		missing_providers
	)
	var missing_target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery.missing_target",
		missing_providers
	)
	var corrupt_source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery.corrupt_source",
		corrupt_providers
	)
	var corrupt_target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery.corrupt_target",
		corrupt_providers
	)
	assert_true(_register(missing_source))
	assert_true(_register(missing_target))
	assert_true(_register(corrupt_source))
	assert_true(_register(corrupt_target))
	_activate_existing(missing_source, { &"missing": { "value": 10 } })
	_activate_existing(corrupt_source, { &"corrupt": { "value": 20 } })

	var missing_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		missing_target.profile_id
	)
	var missing_lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		missing_switch,
		missing_target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_not_null(missing_lease)
	if missing_lease == null:
		return
	assert_eq(missing_lease.get_source_profile_id(), missing_source.profile_id)
	assert_eq(missing_lease.get_profile_id(), missing_target.profile_id)
	assert_eq(missing_lease.get_transaction_id(), missing_switch.get_transaction_id())
	assert_eq(missing_lease.get_reason(), GFSaveProfileRecoveryLease.REASON_MISSING)
	var missing_report: Dictionary = missing_switch.get_result().to_dict()
	var missing_lease_summary: Dictionary = GFVariantData.get_option_dictionary(
		missing_report,
		"recovery_lease"
	)
	assert_eq(
		GFVariantData.get_option_string_name(missing_lease_summary, "source_profile_id"),
		missing_source.profile_id
	)
	assert_eq(
		_coordinator.get_active_profile_id(missing_target.profile_id),
		missing_source.profile_id
	)

	var corrupt_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		corrupt_target.profile_id
	)
	var corrupt_lease: GFSaveProfileRecoveryLease = _complete_switch_document_corruption(
		corrupt_switch,
		corrupt_target
	)
	assert_not_null(corrupt_lease)
	if corrupt_lease == null:
		return
	assert_eq(corrupt_lease.get_source_profile_id(), corrupt_source.profile_id)
	assert_eq(corrupt_lease.get_profile_id(), corrupt_target.profile_id)
	assert_eq(corrupt_lease.get_transaction_id(), corrupt_switch.get_transaction_id())
	assert_eq(corrupt_lease.get_reason(), GFSaveProfileRecoveryLease.REASON_CORRUPT)
	assert_eq(
		_coordinator.get_active_profile_id(corrupt_target.profile_id),
		corrupt_source.profile_id
	)

	var legacy_missing_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "api": "legacy_bootstrap" }
	)
	var legacy_missing: GFSaveProfileTransactionOperation = _coordinator.bootstrap_profile(
		missing_lease,
		legacy_missing_request
	)
	assert_eq(
		legacy_missing.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(legacy_missing_request.is_claimed())
	assert_true(missing_lease.is_available())
	var wrong_missing_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "api": "wrong_adopt_and_switch" }
	)
	var wrong_missing: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(missing_lease, wrong_missing_request)
	)
	assert_eq(
		wrong_missing.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(wrong_missing_request.is_claimed())
	assert_true(missing_lease.is_available())

	var legacy_corrupt_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "api": "legacy_adopt" }
	)
	var legacy_corrupt: GFSaveProfileTransactionOperation = _coordinator.adopt_profile(
		corrupt_lease,
		legacy_corrupt_request
	)
	assert_eq(
		legacy_corrupt.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(legacy_corrupt_request.is_claimed())
	assert_true(corrupt_lease.is_available())
	var wrong_corrupt_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "api": "wrong_bootstrap_and_switch" }
	)
	var wrong_corrupt: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(
			corrupt_lease,
			wrong_corrupt_request
		)
	)
	assert_eq(
		wrong_corrupt.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(wrong_corrupt_request.is_claimed())
	assert_true(corrupt_lease.is_available())


func test_switch_unbound_structural_corruption_fails_closed() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 33)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_unbound_corrupt.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_unbound_corrupt.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 33 } })

	var operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_load_for_file(
		target.file_name,
		GFSaveProfileTransactionTestSupport.read_failure(
			ERR_FILE_CORRUPT,
			"Injected unbound structural corruption.",
			GFStorageReadResult.FailureKind.CORRUPT
		)
	)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_TARGET_LOAD_FAILED
	)
	assert_null(operation.get_result().get_recovery_lease())
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_eq(_storage.get_pending_save_count(), 0)


func test_adopt_and_switch_resets_structural_family_before_target_save() -> void:
	var fixture: Dictionary = _prepare_structural_switch_recovery(
		"session.adopt_switch_reset.success"
	)
	var source: GFSaveProfile = _fixture_profile(fixture, "source")
	var target: GFSaveProfile = _fixture_profile(fixture, "target")
	var lease: GFSaveProfileRecoveryLease = _fixture_recovery_lease(fixture)
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "recovery": "structural" }
	)

	var operation: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(lease, request)
	)
	assert_true(request.is_claimed())
	assert_true(lease.is_claimed())
	assert_eq(_storage.get_pending_reset_count(), 1)
	assert_eq(_storage.reset_call_count, 1)
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)

	_storage.complete_next_reset()
	assert_eq(_storage.get_pending_reset_count(), 0)
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	_storage.complete_next_save(OK)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_ADOPTED_AND_SWITCHED
	)
	assert_eq(
		operation.get_result().get_operation(),
		GFSaveProfileTransactionOperation.OPERATION_ADOPT_AND_SWITCH
	)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), target.profile_id)
	assert_lt(
		_storage.events.find("reset:%s" % target.file_name),
		_storage.events.find("save:%s" % target.file_name)
	)


func test_adopt_and_switch_revalidates_repaired_target_before_reset() -> void:
	var fixture: Dictionary = _prepare_structural_switch_recovery(
		"session.adopt_switch_reset.repaired_target"
	)
	var source: GFSaveProfile = _fixture_profile(fixture, "source")
	var target: GFSaveProfile = _fixture_profile(fixture, "target")
	var lease: GFSaveProfileRecoveryLease = _fixture_recovery_lease(fixture)
	_storage.family_reset_authorization_current = false

	var operation: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(lease)
	)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED
	)
	assert_eq(operation.get_result().get_error_code(), ERR_UNAUTHORIZED)
	assert_eq(operation.get_result().get_phase(), &"recovery_reset")
	assert_eq(_storage.reset_call_count, 0)
	assert_eq(_storage.get_pending_reset_count(), 0)
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_true(_storage.events.has("revalidate:%s" % target.file_name))


func test_adopt_and_switch_reset_failure_preserves_source_without_target_save() -> void:
	var fixture: Dictionary = _prepare_structural_switch_recovery(
		"session.adopt_switch_reset.failure"
	)
	var source: GFSaveProfile = _fixture_profile(fixture, "source")
	var target: GFSaveProfile = _fixture_profile(fixture, "target")
	var lease: GFSaveProfileRecoveryLease = _fixture_recovery_lease(fixture)
	var operation: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(lease)
	)
	var reset_failure: GFStorageFamilyResetResult = GFStorageFamilyResetResult.new()
	var _configured_failure: bool = reset_failure.configure_for_framework(
		ERR_FILE_CANT_WRITE,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY,
		GFStorageFamilyResetResult.Phase.CLEANUP,
		2,
		3,
		1,
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)

	_storage.complete_next_reset(reset_failure)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED
	)
	assert_eq(operation.get_result().get_phase(), &"recovery_reset")
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	var reset_evidence: Dictionary = GFVariantData.get_option_dictionary(
		operation.get_result().get_stage_evidence(),
		"reset"
	)
	assert_eq(
		GFVariantData.get_option_int(reset_evidence, "failure_kind"),
		int(GFStorageFamilyResetResult.FailureKind.IO_FAILED)
	)


func test_adopt_and_switch_reset_success_then_target_save_failure_preserves_source() -> void:
	var fixture: Dictionary = _prepare_structural_switch_recovery(
		"session.adopt_switch_reset.target_save_failure"
	)
	var source: GFSaveProfile = _fixture_profile(fixture, "source")
	var target: GFSaveProfile = _fixture_profile(fixture, "target")
	var lease: GFSaveProfileRecoveryLease = _fixture_recovery_lease(fixture)
	var operation: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(lease)
	)
	assert_eq(_storage.get_pending_reset_count(), 1)
	assert_eq(_storage.get_pending_save_count(), 0)

	_storage.complete_next_reset()
	assert_false(operation.is_completed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	_storage.complete_next_save(ERR_FILE_CANT_WRITE)

	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_operation(),
		GFSaveProfileTransactionOperation.OPERATION_ADOPT_AND_SWITCH
	)
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED
	)
	assert_eq(operation.get_result().get_phase(), &"recovery_target_save")
	assert_eq(operation.get_result().get_active_profile_after(), source.profile_id)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	var reset_evidence: Dictionary = GFVariantData.get_option_dictionary(
		operation.get_result().get_stage_evidence(),
		"reset"
	)
	assert_true(GFVariantData.get_option_bool(reset_evidence, "ok"))
	assert_eq(
		GFVariantData.get_option_int(reset_evidence, "failure_kind"),
		int(GFStorageFamilyResetResult.FailureKind.NONE)
	)
	assert_lt(
		_storage.events.find("reset:%s" % target.file_name),
		_storage.events.find("save:%s" % target.file_name)
	)


func test_dispose_during_switch_reset_fences_request_and_waits_for_physical_tail() -> void:
	var fixture: Dictionary = _prepare_structural_switch_recovery(
		"session.adopt_switch_reset.dispose"
	)
	var target: GFSaveProfile = _fixture_profile(fixture, "target")
	var lease: GFSaveProfileRecoveryLease = _fixture_recovery_lease(fixture)
	var operation: GFSaveProfileTransactionOperation = (
		_coordinator.adopt_and_switch_profile(lease)
	)
	var request_id: int = _storage.get_pending_reset_request_id()
	var _connected: Error = operation.completed.connect(_on_transaction_completed) as Error
	assert_gt(request_id, 0)

	_coordinator.dispose()
	assert_true(operation.is_completed())
	assert_eq(
		operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN
	)
	var reconcile_lease: GFSaveProfileReconcileLease = (
		operation.get_result().get_reconcile_lease()
	)
	assert_not_null(reconcile_lease)
	if reconcile_lease != null:
		assert_true(reconcile_lease.get_storage_request_ids().has(request_id))
	var quiesce: GFAsyncCompletion = _profile_utility.begin_quiesce(GFAsyncScope.new())
	assert_false(quiesce.is_completed())

	_storage.complete_next_reset()
	assert_true(quiesce.is_successful())
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_terminal_count, 1)
	assert_eq(operation.get_result().get_target_profile_id(), target.profile_id)


func test_switch_recovery_reservation_blocks_synchronous_flush_callback_save() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 41)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_reservation.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_reservation.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 41 } })
	var switch_operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		switch_operation,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	var reentrant_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "source": "flush_callback" }
	)
	var callback_state: Dictionary = {}
	var callback: Callable = func(_result: GFSaveProfileResult) -> void:
		if not callback_state.is_empty():
			return
		callback_state["operation"] = _profile_utility.save_profile(
			source.profile_id,
			reentrant_request
		)
	var connected: Error = _profile_utility.profile_operation_completed.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connected, OK)

	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease)
	)
	assert_false(
		recovery.is_completed(),
		"同步 flush callback 后 recovery 不得在 target save 前失败：%s" % [
			recovery.get_result().to_dict() if recovery.get_result() != null else {}
		]
	)
	assert_false(reentrant_request.is_claimed())
	var reentrant_value: Variant = GFVariantData.get_option_value(
		callback_state,
		"operation"
	)
	assert_true(reentrant_value is GFSaveProfileOperation)
	if reentrant_value is GFSaveProfileOperation:
		var reentrant_operation: GFSaveProfileOperation = reentrant_value
		assert_true(reentrant_operation.is_completed())
		assert_eq(reentrant_operation.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	_storage.complete_next_save(OK)
	assert_true(recovery.get_result().is_successful())


func test_switch_recovery_source_flush_unknown_fences_source() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 61)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_unknown.source",
		providers,
		10
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_unknown.target",
		providers,
		10
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 61 } })
	var switch_operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		switch_operation,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	provider.value = 62
	var source_save: GFSaveProfileOperation = _profile_utility.save_profile(
		source.profile_id
	)
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_count(), 1)
	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease)
	)
	assert_false(recovery.is_completed())
	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)

	assert_eq(source_save.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_true(recovery.is_completed())
	assert_eq(
		recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN
	)
	var reconcile_lease: GFSaveProfileReconcileLease = (
		recovery.get_result().get_reconcile_lease()
	)
	assert_not_null(reconcile_lease)
	if reconcile_lease != null:
		assert_eq(reconcile_lease.get_reconcile_profile_id(), source.profile_id)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), source.file_name)
	_storage.complete_next_save(OK)
	assert_eq(_storage.get_pending_save_count(), 0)


func test_switch_recovery_target_save_unknown_fences_target_without_identity_commit() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 71)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_target_unknown.source",
		providers,
		10
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_target_unknown.target",
		providers,
		10
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 71 } })
	var switch_operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		switch_operation,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	var identity_changes: Dictionary = { "count": 0 }
	var callback: Callable = func(
		_previous_profile_id: StringName,
		_current_profile_id: StringName
	) -> void:
		identity_changes["count"] = GFVariantData.get_option_int(
			identity_changes,
			"count"
		) + 1
	var connected: Error = _coordinator.active_profile_changed.connect(callback) as Error
	assert_eq(connected, OK)
	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease)
	)
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)

	assert_true(recovery.is_completed())
	assert_eq(
		recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN
	)
	var reconcile_lease: GFSaveProfileReconcileLease = (
		recovery.get_result().get_reconcile_lease()
	)
	assert_not_null(reconcile_lease)
	if reconcile_lease != null:
		assert_eq(reconcile_lease.get_reconcile_profile_id(), target.profile_id)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_eq(GFVariantData.get_option_int(identity_changes, "count"), 0)
	_storage.complete_next_save(OK)
	assert_eq(GFVariantData.get_option_int(identity_changes, "count"), 0)
	if _coordinator.active_profile_changed.is_connected(callback):
		_coordinator.active_profile_changed.disconnect(callback)


func test_bootstrap_and_switch_reflushes_latest_source_before_atomic_commit() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 5)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 5 } })
	var failed_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		failed_switch,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_not_null(lease)
	if lease == null:
		return

	provider.value = 31
	var source_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "generation": "latest_source" }
	)
	var source_save: GFSaveProfileOperation = _profile_utility.save_profile(
		source.profile_id,
		source_request
	)
	var recovery_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{ "recovery": "missing_switch" },
		{},
		{ "trace": 89 }
	)
	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease, recovery_request)
	)
	assert_true(recovery_request.is_claimed(), "已接纳事务必须同步接管一次性 request。")
	assert_true(lease.is_claimed(), "已接纳事务必须同步消费 switch Recovery Lease。")
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)

	_profile_utility.tick(0.0)
	assert_true(source_request.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), source.file_name)
	assert_eq(_storage.save_calls.size(), 1, "target save 必须等待 recovery-time source flush。")
	_storage.complete_next_save(OK)
	_profile_utility.tick(0.0)
	assert_true(source_save.is_completed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	assert_eq(_storage.save_calls.size(), 2)
	assert_eq(
		GFSaveProfileTransactionTestSupport.get_saved_value(
			_storage.save_calls[1],
			&"state"
		),
		31,
		"target 必须持久化 recovery 调用时重新 flush 的最新 source 状态。"
	)
	assert_eq(
		_coordinator.get_active_profile_id(target.profile_id),
		source.profile_id,
		"target save 获得确定成功前不得提交活动身份。"
	)
	_storage.complete_next_save(OK)

	assert_true(recovery.get_result().is_successful())
	assert_eq(
		recovery.get_operation(),
		GFSaveProfileTransactionOperation.OPERATION_BOOTSTRAP_AND_SWITCH
	)
	assert_eq(
		recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BOOTSTRAPPED_AND_SWITCHED
	)
	assert_eq(recovery.get_result().get_source_profile_id(), source.profile_id)
	assert_eq(recovery.get_result().get_target_profile_id(), target.profile_id)
	assert_eq(recovery.get_result().get_active_profile_before(), source.profile_id)
	assert_eq(recovery.get_result().get_active_profile_after(), target.profile_id)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), target.profile_id)


func test_switch_recovery_stale_and_replayed_leases_do_not_claim_requests() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 7)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery_lease.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_recovery_lease.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 7 } })
	var first_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var stale_lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		first_switch,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_not_null(stale_lease)
	if stale_lease == null:
		return

	var second_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var current_lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		second_switch,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_true(stale_lease.is_stale())
	assert_not_null(current_lease)
	if current_lease == null:
		return
	var stale_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "lease": "stale" }
	)
	var stale_recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(stale_lease, stale_request)
	)
	assert_eq(
		stale_recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(stale_request.is_claimed())

	var accepted_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "lease": "accepted" }
	)
	var accepted: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(current_lease, accepted_request)
	)
	assert_true(current_lease.is_claimed())
	assert_true(accepted_request.is_claimed())
	var replay_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "lease": "replay" }
	)
	var replay: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(current_lease, replay_request)
	)
	assert_eq(
		replay.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_INVALID_LEASE
	)
	assert_false(replay_request.is_claimed())

	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	_storage.complete_next_save(OK)
	assert_true(accepted.get_result().is_successful())
	assert_eq(
		accepted.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BOOTSTRAPPED_AND_SWITCHED
	)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), target.profile_id)


func test_bootstrap_and_switch_source_flush_failure_preserves_source() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 11)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch_flush_failure.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch_flush_failure.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 11 } })
	var failed_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		failed_switch,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_not_null(lease)
	if lease == null:
		return

	provider.value = 12
	var source_save: GFSaveProfileOperation = _profile_utility.save_profile(source.profile_id)
	var recovery_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "failure": "source_flush" }
	)
	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease, recovery_request)
	)
	assert_true(recovery_request.is_claimed())
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_file_name(), source.file_name)
	_storage.complete_next_save(ERR_FILE_CANT_WRITE)

	assert_true(source_save.is_completed())
	assert_true(recovery.is_completed())
	assert_eq(
		recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_SOURCE_FLUSH_FAILED
	)
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_storage.save_calls.size(), 1, "source flush 失败后不得触碰 target 持久化。")
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_eq(recovery.get_result().get_active_profile_after(), source.profile_id)


func test_bootstrap_and_switch_target_save_failure_preserves_source() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 13)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch_save_failure.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.bootstrap_switch_save_failure.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 13 } })
	var failed_switch: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		failed_switch,
		target,
		ERR_FILE_NOT_FOUND,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	assert_not_null(lease)
	if lease == null:
		return
	var recovery_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "failure": "target_save" }
	)
	var recovery: GFSaveProfileTransactionOperation = (
		_coordinator.bootstrap_and_switch_profile(lease, recovery_request)
	)
	assert_true(recovery_request.is_claimed())
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(_storage.get_pending_save_file_name(), target.file_name)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	_storage.complete_next_save(ERR_FILE_CANT_WRITE)

	assert_true(recovery.is_completed())
	assert_eq(
		recovery.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED
	)
	assert_eq(_coordinator.get_active_profile_id(target.profile_id), source.profile_id)
	assert_eq(recovery.get_result().get_active_profile_after(), source.profile_id)


func test_switch_waits_for_source_generation_before_loading_target() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 5 } })

	provider.value = 8
	var save_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership({}, {}, {})
	var source_save: GFSaveProfileOperation = _profile_utility.save_profile(
		source.profile_id,
		save_request
	)
	_profile_utility.tick(0.0)
	assert_true(
		save_request.is_claimed(),
		"活动 Profile 的直接 save 应获准；result=%s。" % source_save.get_result()
	)
	assert_eq(_storage.get_pending_save_count(), 1)

	var switch_operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_count(), 0, "源 generation 未确认前不得读取目标。")
	_storage.complete_next_save(OK)
	_profile_utility.tick(0.0)
	assert_true(source_save.is_completed())
	assert_eq(_storage.get_pending_load_file_name(), target.file_name)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			target,
			{ &"state": { "value": 21 } }
		)
	))

	var result: GFSaveProfileTransactionResult = switch_operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_SWITCHED)
	assert_eq(result.get_source_profile_id(), source.profile_id)
	assert_eq(result.get_target_profile_id(), target.profile_id)
	assert_eq(result.get_active_profile_after(), target.profile_id)
	assert_eq(provider.value, 21)


func test_switch_apply_failure_restores_source_state_and_identity() -> void:
	var events: Array[String] = []
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 0, events)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 0, events)
	)
	var providers: Array[GFSaveSectionProvider] = [first, second]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.rollback.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.rollback.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, {
		&"first": { "value": 10 },
		&"second": { "value": 11 },
	})
	events.clear()
	second.fail_apply = true

	var operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			target,
			{
				&"first": { "value": 20 },
				&"second": { "value": 21 },
			}
		)
	))

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_false(result.is_successful())
	assert_eq(_coordinator.get_active_profile_id(source.profile_id), source.profile_id)
	assert_eq(first.value, 10)
	assert_eq(second.value, 11)
	assert_lt(events.find("rollback:second"), events.find("rollback:first"))


func test_switch_target_load_dispose_ignores_late_document() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_dispose.source",
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.switch_dispose.target",
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 10 } })
	var operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = operation.completed.connect(
		func(terminal_result: GFSaveProfileTransactionResult) -> void:
			terminal_statuses.append(terminal_result.get_status())
	) as Error
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_file_name(), target.file_name)

	_coordinator.dispose()
	assert_true(operation.is_completed())
	var disposed_result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(disposed_result.get_status(), GFSaveProfileTransactionResult.STATUS_DISPOSED)
	assert_not_null(disposed_result.get_reconcile_lease())
	assert_true(disposed_result.get_reconcile_lease().is_terminal())
	assert_eq(terminal_statuses, [GFSaveProfileTransactionResult.STATUS_DISPOSED])
	assert_eq(provider.value, 10)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			target,
			{ &"state": { "value": 99 } }
		)
	))
	assert_eq(provider.value, 10, "关闭后的目标读取不得迟到应用到共享 Provider。")
	assert_eq(terminal_statuses.size(), 1)


func test_inactive_managed_profile_rejects_direct_bypass_without_claiming_request() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 1)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.managed_gate",
		providers
	)
	assert_true(_register(profile))
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{ "document": 1 },
		{ "context": 2 },
		{ "result": 3 }
	)

	var save_operation: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		request
	)
	var load_operation: GFSaveProfileOperation = _profile_utility.load_profile(
		profile.profile_id
	)
	var flush_operation: GFSaveProfileOperation = _profile_utility.flush_profile(
		profile.profile_id
	)

	assert_true(save_operation.is_completed())
	assert_true(load_operation.is_completed())
	assert_true(flush_operation.is_completed())
	assert_false(request.is_claimed(), "前置 managed gate 必须先于 move-only request claim。")
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_storage.get_pending_load_count(), 0)


func test_utility_quiesce_rejects_manager_operations_before_claiming_save_request() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 1)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.manager_quiesce",
		providers
	)
	assert_true(GFVariantData.get_option_bool(
		_profile_utility.register_profile(profile),
		"registered"
	))
	var manager_owner: RefCounted = RefCounted.new()
	var permit: RefCounted = _profile_utility.claim_profile_management_for_framework(
		profile.profile_id,
		manager_owner
	)
	assert_not_null(permit)
	var _quiesce: GFAsyncCompletion = _profile_utility.begin_quiesce(GFAsyncScope.new())
	var request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{ "document": 1 },
		{ "context": 2 },
		{ "result": 3 }
	)

	var save_operation: GFSaveProfileOperation = (
		_profile_utility.save_profile_for_manager_for_framework(
			profile.profile_id,
			request,
			permit
		)
	)
	var load_operation: GFSaveProfileOperation = (
		_profile_utility.load_profile_strict_for_manager_for_framework(
			profile.profile_id,
			{},
			{},
			permit
		)
	)
	var flush_operation: GFSaveProfileOperation = (
		_profile_utility.flush_profile_for_manager_for_framework(
			profile.profile_id,
			{},
			permit
		)
	)

	assert_true(save_operation.is_completed())
	assert_true(load_operation.is_completed())
	assert_true(flush_operation.is_completed())
	assert_eq(save_operation.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_eq(load_operation.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_eq(flush_operation.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(request.is_claimed(), "quiesce 准入门禁必须先于 manager request claim。")
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(_storage.get_pending_load_count(), 0)


func test_provider_capture_quiesce_revokes_active_direct_save_access_immediately() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 1)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.capture_quiesce",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 1 } })
	var completions: Array[GFAsyncCompletion] = []
	provider.save_snapshot_callback = func() -> void:
		completions.append(_coordinator.begin_quiesce(GFAsyncScope.new()))
	provider.value = 2
	var accepted_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "source": "accepted" }
	)
	var accepted: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		accepted_request
	)

	_profile_utility.tick(0.0)

	assert_true(accepted_request.is_claimed())
	assert_eq(completions.size(), 1)
	assert_false(completions[0].is_completed())
	assert_eq(_storage.get_pending_save_count(), 1)
	var blocked_during_request: GFSaveProfileRequest = (
		GFSaveProfileRequest.take_ownership({}, {}, { "source": "during" })
	)
	var blocked_during: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		blocked_during_request
	)
	assert_true(blocked_during.is_completed())
	assert_eq(blocked_during.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(
		blocked_during_request.is_claimed(),
		"capture 回调返回后，单调撤权必须先于 direct save request claim。"
	)

	_storage.complete_next_save(OK)

	assert_true(accepted.get_result().is_successful())
	assert_true(completions[0].is_successful())
	var blocked_after_request: GFSaveProfileRequest = (
		GFSaveProfileRequest.take_ownership({}, {}, { "source": "after" })
	)
	var blocked_after: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		blocked_after_request
	)
	assert_true(blocked_after.is_completed())
	assert_eq(blocked_after.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(
		blocked_after_request.is_claimed(),
		"Coordinator quiesce 收敛后不得重新放宽 active Profile 的 direct save。"
	)


func test_coordinator_quiesce_blocks_direct_save_and_waits_for_detached_tail() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 1)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.quiesce_direct_tail",
		providers,
		10
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 1 } })
	provider.value = 2
	var accepted_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "source": "accepted" }
	)
	var accepted: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		accepted_request
	)
	_profile_utility.tick(0.0)
	assert_true(accepted_request.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)

	var completion: GFAsyncCompletion = _coordinator.begin_quiesce(GFAsyncScope.new())
	assert_false(completion.is_completed())
	var blocked_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "source": "blocked" }
	)
	var blocked: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		blocked_request
	)
	assert_true(blocked.is_completed())
	assert_eq(blocked.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(blocked_request.is_claimed())

	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)
	assert_eq(accepted.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_false(completion.is_completed(), "逻辑超时后仍须等待 detached 物理写尾部。")
	assert_eq(
		GFVariantData.get_option_int(
			_profile_utility.get_profile_state_snapshot(profile.profile_id),
			"detached_write_count"
		),
		1
	)

	_storage.complete_next_save(OK)
	assert_true(completion.is_successful())
	assert_eq(
		GFVariantData.get_option_int(
			_profile_utility.get_profile_state_snapshot(profile.profile_id),
			"detached_write_count"
		),
		0
	)


func test_managed_strict_load_owner_dispose_maps_rollback_failure_once() -> void:
	var events: Array[String] = []
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 1, events)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 2, events)
	)
	var providers: Array[GFSaveSectionProvider] = [first, second]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.strict_load_owner_dispose",
		providers
	)
	assert_true(GFVariantData.get_option_bool(
		_profile_utility.register_profile(profile),
		"registered"
	))
	var manager_owner: Node = Node.new()
	var permit: RefCounted = _profile_utility.claim_profile_management_for_framework(
		profile.profile_id,
		manager_owner
	)
	assert_not_null(permit)
	first.fail_rollback = true
	first.apply_callback = func() -> void:
		manager_owner.free()
	var operation: GFSaveProfileOperation = (
		_profile_utility.load_profile_strict_for_manager_for_framework(
			profile.profile_id,
			{},
			{},
			permit
		)
	)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = operation.completed.connect(
		func(terminal_result: GFSaveProfileResult) -> void:
			terminal_statuses.append(terminal_result.get_status())
	) as Error
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_count(), 1)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{
				&"first": { "value": 10 },
				&"second": { "value": 20 },
			}
		)
	))
	first.apply_callback = Callable()

	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_ROLLBACK_FAILED)
	assert_eq(terminal_statuses, [GFSaveProfileResult.STATUS_ROLLBACK_FAILED])
	assert_eq(operation.get_result().get_failed_section_id(), &"first")
	assert_eq(operation.get_result().get_rollback_errors().size(), 1)
	assert_eq(first.value, 10, "rollback failure 必须显式保留不确定的已应用 section。")
	assert_eq(second.value, 2, "permit 撤销后不得继续应用后续 section。")
	assert_eq(first.apply_count, 1)
	assert_eq(second.apply_count, 0)
	assert_eq(first.rollback_count, 1)
	assert_eq(events, [
		"capture:first",
		"capture:second",
		"apply:first",
		"rollback:first",
	])
	assert_eq(_storage.load_calls.size(), 1)
	assert_eq(_storage.save_calls.size(), 0)
	assert_eq(_storage.get_pending_load_count(), 0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{
				&"first": { "value": 99 },
				&"second": { "value": 99 },
			}
		)
	))
	assert_eq(first.value, 10)
	assert_eq(second.value, 2)
	assert_eq(terminal_statuses.size(), 1)
	assert_true(_profile_utility.unregister_profile(profile.profile_id))


func test_dispose_keeps_inflight_operation_at_one_terminal_completion() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"session.dispose",
		providers
	)
	assert_true(_register(profile))
	var operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	var _connected: Error = operation.completed.connect(_on_transaction_completed) as Error
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_count(), 1)

	_coordinator.dispose()
	assert_true(operation.is_completed())
	assert_eq(_terminal_count, 1)
	var disposed_result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(disposed_result.get_status(), GFSaveProfileTransactionResult.STATUS_DISPOSED)
	assert_not_null(disposed_result.get_reconcile_lease())
	assert_true(disposed_result.get_reconcile_lease().is_terminal())
	assert_eq(provider.value, 0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{ &"state": { "value": 99 } }
		)
	))
	assert_eq(_terminal_count, 1, "迟到低层终态不得再次完成已释放事务。")
	assert_eq(provider.value, 0, "关闭后的严格读取不得迟到应用 Provider 文档。")


# --- 私有/辅助方法 ---

func _register(profile: GFSaveProfile) -> bool:
	return GFVariantData.get_option_bool(
		_coordinator.register_profile(profile),
		"registered"
	)


func _activate_existing(profile: GFSaveProfile, payloads: Dictionary) -> void:
	var operation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(
		profile.profile_id
	)
	_profile_utility.tick(0.0)
	_storage.complete_load_for_file(
		profile.file_name,
		GFSaveProfileTransactionTestSupport.read_success(
			GFSaveProfileTransactionTestSupport.make_document(profile, payloads)
		)
	)
	assert_true(operation.is_completed())
	assert_true(operation.get_result().is_successful())


func _prepare_structural_switch_recovery(prefix: String) -> Dictionary:
	_storage.enable_family_reset_authorization = true
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 55)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var source: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		StringName("%s.source" % prefix),
		providers
	)
	var target: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		StringName("%s.target" % prefix),
		providers
	)
	assert_true(_register(source))
	assert_true(_register(target))
	_activate_existing(source, { &"state": { "value": 55 } })
	var switch_operation: GFSaveProfileTransactionOperation = _coordinator.switch_profile(
		target.profile_id
	)
	var lease: GFSaveProfileRecoveryLease = _complete_switch_recovery_failure(
		switch_operation,
		target,
		ERR_FILE_CORRUPT,
		GFStorageReadResult.FailureKind.CORRUPT
	)
	assert_not_null(lease)
	return {
		"source": source,
		"target": target,
		"lease": lease,
	}


func _fixture_profile(fixture: Dictionary, key: String) -> GFSaveProfile:
	var value: Variant = fixture.get(key)
	assert_true(value is GFSaveProfile, "结构恢复夹具必须提供强类型 Profile。")
	if value is GFSaveProfile:
		var profile: GFSaveProfile = value
		return profile
	return null


func _fixture_recovery_lease(fixture: Dictionary) -> GFSaveProfileRecoveryLease:
	var value: Variant = fixture.get("lease")
	assert_true(value is GFSaveProfileRecoveryLease, "结构恢复夹具必须提供强类型 Lease。")
	if value is GFSaveProfileRecoveryLease:
		var lease: GFSaveProfileRecoveryLease = value
		return lease
	return null


func _complete_switch_recovery_failure(
	operation: GFSaveProfileTransactionOperation,
	target: GFSaveProfile,
	error_code: Error,
	failure_kind: GFStorageReadResult.FailureKind
) -> GFSaveProfileRecoveryLease:
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_file_name(), target.file_name)
	_storage.complete_load_for_file(
		target.file_name,
		GFSaveProfileTransactionTestSupport.read_failure(
			error_code,
			"Injected switch recovery target failure.",
			failure_kind
		)
	)
	assert_true(operation.is_completed())
	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED)
	return result.get_recovery_lease()


func _complete_switch_document_corruption(
	operation: GFSaveProfileTransactionOperation,
	target: GFSaveProfile
) -> GFSaveProfileRecoveryLease:
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_file_name(), target.file_name)
	_storage.complete_load_for_file(
		target.file_name,
		GFStorageReadResult.new().configure_success({
			"malformed_save_document": true,
		})
	)
	assert_true(operation.is_completed())
	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED)
	return result.get_recovery_lease()


# --- 信号处理函数 ---

func _on_transaction_completed(_result: GFSaveProfileTransactionResult) -> void:
	_terminal_count += 1
