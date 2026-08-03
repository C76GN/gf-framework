# 测试 Save Profile 类型化 section mutation、回滚与 outcome-unknown 对账。
extends GutTest


# --- 私有变量 ---

var _clock: GFManualClock
var _storage: GFSaveProfileTransactionTestSupport.ControlledStorage
var _profile_utility: GFSaveProfileUtility
var _coordinator: GFSaveProfileTransactionCoordinator


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_clock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	_storage = GFSaveProfileTransactionTestSupport.ControlledStorage.new()
	_profile_utility = GFSaveProfileUtility.new().setup(_storage, _clock)
	_storage.driver = _profile_utility
	_coordinator = GFSaveProfileTransactionCoordinator.new().setup(_profile_utility)


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

func test_mutation_uses_registered_provider_order_and_persists_candidate() -> void:
	var events: Array[String] = []
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 1, events)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 2, events)
	)
	var providers: Array[GFSaveSectionProvider] = [first, second]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.success",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, {
		&"first": { "value": 1 },
		&"second": { "value": 2 },
	})
	events.clear()
	var first_mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"first",
		1,
		{ "value": 10 }
	)
	var second_mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"second",
		1,
		{ "value": 20 }
	)
	var mutations: Array[GFSaveSectionMutation] = [second_mutation, first_mutation]
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.take_ownership(
		mutations,
		{ "source": "test" },
		{ "reason": "stable-order" },
		{ "trace": 1 }
	)

	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	_tick_queued_mutation()
	assert_true(request.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_lt(events.find("capture:first"), events.find("capture:second"))
	assert_lt(events.find("apply:first"), events.find("apply:second"))
	_storage.complete_next_save(OK)

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_true(result.is_successful())
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_MUTATED)
	assert_eq(first.value, 10)
	assert_eq(second.value, 20)
	assert_eq(
		GFSaveProfileTransactionTestSupport.get_saved_value(_storage.save_calls[0], &"first"),
		10
	)
	assert_eq(
		GFSaveProfileTransactionTestSupport.get_saved_value(_storage.save_calls[0], &"second"),
		20
	)


func test_apply_failure_rolls_back_attempted_providers_in_reverse_order() -> void:
	var events: Array[String] = []
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 3, events)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 4, events)
	)
	var providers: Array[GFSaveSectionProvider] = [first, second]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.apply_failure",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, {
		&"first": { "value": 3 },
		&"second": { "value": 4 },
	})
	events.clear()
	second.fail_apply = true
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"first", 30),
		_make_mutation(&"second", 40),
	])

	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	_tick_queued_mutation()

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_eq(_storage.get_pending_save_count(), 0)
	assert_eq(first.value, 3)
	assert_eq(second.value, 4)
	assert_true(events.has("rollback:second"))
	assert_true(events.has("rollback:first"))
	assert_lt(events.find("rollback:second"), events.find("rollback:first"))


func test_known_save_failure_rollback_dispose_keeps_persist_failed_once() -> void:
	var events: Array[String] = []
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 6, events)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.save_failure",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 6 } })
	events.clear()
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 60),
	])

	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = operation.completed.connect(
		func(terminal_result: GFSaveProfileTransactionResult) -> void:
			terminal_statuses.append(terminal_result.get_status())
	) as Error
	_tick_queued_mutation()
	assert_eq(provider.value, 60)
	assert_eq(_storage.get_pending_save_count(), 1)
	provider.rollback_callback = func() -> void:
		_coordinator.dispose()
	_storage.complete_next_save(ERR_FILE_CANT_WRITE)
	provider.rollback_callback = Callable()

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_false(result.is_successful())
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED)
	assert_eq(terminal_statuses, [GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED])
	assert_eq(provider.value, 6)
	assert_true(events.has("rollback:state"))
	assert_eq(_storage.save_calls.size(), 1, "已知未提交失败不应扩大为补偿写窗口。")
	assert_true(result.get_rollback_errors().is_empty())
	_coordinator.dispose()
	assert_eq(terminal_statuses.size(), 1)


func test_known_save_failure_reports_provider_rollback_failure() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 9)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.rollback_failure",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 9 } })
	provider.fail_rollback = true
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 90),
	])

	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	_tick_queued_mutation()
	_storage.complete_next_save(ERR_FILE_CANT_WRITE)

	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_false(result.is_successful())
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED)
	assert_false(result.get_rollback_errors().is_empty())
	assert_eq(provider.value, 90, "回滚失败不得伪装成旧内存状态。")


func test_non_active_profile_rejects_mutation_without_claiming_request() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 1)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.inactive",
		providers
	)
	assert_true(_register(profile))
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 2),
	])

	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	_profile_utility.tick(0.0)

	assert_true(operation.is_completed())
	assert_false(operation.get_result().is_successful())
	assert_false(request.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 0)


func test_unknown_write_fences_domain_until_late_evidence_is_reloaded() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 7)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.reconcile",
		providers,
		10
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 7 } })
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 70),
	])
	var mutation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	_tick_queued_mutation()
	assert_eq(_storage.get_pending_save_count(), 1)
	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)

	var unknown_result: GFSaveProfileTransactionResult = mutation.get_result()
	var reconcile_lease: GFSaveProfileReconcileLease = unknown_result.get_reconcile_lease()
	assert_eq(unknown_result.get_status(), GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN)
	assert_not_null(reconcile_lease)
	assert_true(reconcile_lease.is_waiting())
	assert_eq(
		GFVariantData.get_option_string_name(
			_coordinator.get_domain_state_snapshot(profile.profile_id),
			"state"
		),
		GFSaveProfileTransactionCoordinator.DOMAIN_STATE_RECONCILIATION_REQUIRED
	)
	var blocked_request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 71),
	])
	var blocked: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		blocked_request
	)
	assert_true(blocked.is_completed())
	assert_false(blocked_request.is_claimed(), "fence 拒绝必须发生在 move-only claim 之前。")

	var reconcile_request: GFSaveProfileReconcileRequest = (
		GFSaveProfileReconcileRequest.take_ownership(
			{ "evidence": "pending" },
			{ "trace": 9 }
		)
	)
	var pending_operation: GFSaveProfileTransactionOperation = _coordinator.reconcile_profile(
		reconcile_lease,
		reconcile_request
	)
	assert_true(pending_operation.is_completed())
	assert_eq(
		pending_operation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_RECONCILE_PENDING
	)
	assert_false(reconcile_request.is_claimed())
	assert_true(reconcile_lease.is_waiting())

	var settled_reconcile_operations: Array[GFSaveProfileTransactionOperation] = []
	var settled_request_availability: Array[bool] = []
	var _settled_connected: Error = reconcile_lease.settled.connect(
		func(
			settled_lease: GFSaveProfileReconcileLease,
			_state: StringName
		) -> void:
			settled_reconcile_operations.append(
				_coordinator.reconcile_profile(settled_lease, reconcile_request)
			)
			settled_request_availability.append(reconcile_request.is_available())
	) as Error
	_storage.complete_next_save(OK)
	assert_true(reconcile_lease.is_ready(), "迟到成功只能开放显式 reconcile，不能自动解锁。")
	assert_eq(settled_reconcile_operations.size(), 1)
	assert_eq(settled_request_availability, [true])
	assert_true(settled_reconcile_operations[0].is_completed())
	assert_eq(
		settled_reconcile_operations[0].get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BUSY
	)
	assert_false(reconcile_request.is_claimed(), "settled 回调内 BUSY 拒绝必须先于 request claim。")
	assert_eq(
		mutation.get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN,
		"原终态必须保持不可变。"
	)
	var reconcile: GFSaveProfileTransactionOperation = _coordinator.reconcile_profile(
		reconcile_lease,
		reconcile_request
	)
	_profile_utility.tick(0.0)
	assert_true(reconcile_request.is_claimed())
	assert_eq(_storage.get_pending_load_file_name(), profile.file_name)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{ &"state": { "value": 70 } }
		)
	))

	assert_true(reconcile.get_result().is_successful())
	assert_eq(reconcile.get_result().get_status(), GFSaveProfileTransactionResult.STATUS_RECONCILED)
	assert_true(reconcile_lease.is_terminal())
	assert_eq(_coordinator.get_active_profile_id(profile.profile_id), profile.profile_id)
	assert_eq(
		GFVariantData.get_option_string_name(
			_coordinator.get_domain_state_snapshot(profile.profile_id),
			"state"
		),
		GFSaveProfileTransactionCoordinator.DOMAIN_STATE_ACTIVE
	)
	assert_eq(provider.value, 70)


func test_coordinator_dispose_abandons_inflight_write_until_late_settlement() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 4)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.dispose_inflight",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 4 } })
	var request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 40),
	])
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		request
	)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = operation.completed.connect(
		func(terminal_result: GFSaveProfileTransactionResult) -> void:
			terminal_statuses.append(terminal_result.get_status())
	) as Error
	_tick_queued_mutation()
	assert_true(request.is_claimed())
	assert_eq(_storage.get_pending_save_count(), 1)
	assert_eq(provider.value, 40)

	_coordinator.dispose()
	assert_true(operation.is_completed())
	if not operation.is_completed():
		return
	assert_eq(terminal_statuses, [GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN])
	var result: GFSaveProfileTransactionResult = operation.get_result()
	assert_eq(result.get_status(), GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN)
	assert_not_null(result.get_reconcile_lease())
	assert_true(result.get_reconcile_lease().is_terminal())
	var direct_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		{},
		{},
		{ "source": "after-abandon" }
	)
	var rejected_direct: GFSaveProfileOperation = _profile_utility.save_profile(
		profile.profile_id,
		direct_request
	)
	assert_true(rejected_direct.is_completed())
	assert_eq(rejected_direct.get_result().get_status(), GFSaveProfileResult.STATUS_BUSY)
	assert_false(direct_request.is_claimed())
	assert_false(_profile_utility.unregister_profile(profile.profile_id))

	_storage.complete_next_save(OK)
	assert_eq(terminal_statuses.size(), 1, "迟到低层写终态不得重写外层 disposal 结果。")
	assert_eq(operation.get_result().get_status(), GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN)
	assert_true(_profile_utility.unregister_profile(profile.profile_id))
	assert_true(_profile_utility.get_profile_state_snapshot(profile.profile_id).is_empty())


func test_reconcile_load_dispose_ignores_late_document() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 7)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.reconcile_dispose",
		providers,
		10
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 7 } })
	var mutation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		_make_request([_make_mutation(&"state", 70)])
	)
	_tick_queued_mutation()
	assert_eq(_storage.get_pending_save_count(), 1)
	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)
	var unknown_result: GFSaveProfileTransactionResult = mutation.get_result()
	assert_eq(unknown_result.get_status(), GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN)
	var lease: GFSaveProfileReconcileLease = unknown_result.get_reconcile_lease()
	assert_not_null(lease)
	assert_true(lease.is_waiting())
	_storage.complete_next_save(OK)
	assert_true(lease.is_ready())

	var reconcile: GFSaveProfileTransactionOperation = _coordinator.reconcile_profile(lease)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = reconcile.completed.connect(
		func(terminal_result: GFSaveProfileTransactionResult) -> void:
			terminal_statuses.append(terminal_result.get_status())
	) as Error
	_profile_utility.tick(0.0)
	assert_eq(_storage.get_pending_load_file_name(), profile.file_name)
	_coordinator.dispose()
	assert_true(reconcile.is_completed())
	var disposed_result: GFSaveProfileTransactionResult = reconcile.get_result()
	assert_eq(disposed_result.get_status(), GFSaveProfileTransactionResult.STATUS_DISPOSED)
	assert_same(disposed_result.get_reconcile_lease(), lease)
	assert_true(lease.is_terminal())
	assert_eq(terminal_statuses, [GFSaveProfileTransactionResult.STATUS_DISPOSED])
	assert_eq(provider.value, 70)

	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(
		GFSaveProfileTransactionTestSupport.make_document(
			profile,
			{ &"state": { "value": 99 } }
		)
	))
	assert_eq(provider.value, 70, "关闭后的 reconcile 严格读取不得迟到应用。")
	assert_eq(terminal_statuses.size(), 1)


func test_generation_evidence_signal_observes_stabilized_unknown_and_late_state() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 2)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.generation_evidence",
		providers,
		10
	)
	assert_true(GFVariantData.get_option_bool(
		_profile_utility.register_profile(profile),
		"registered"
	))
	var observed_evidence: Array[Dictionary] = []
	var observed_snapshots: Array[Dictionary] = []
	var observed_generations: Array[int] = []
	var _connected: Error = _profile_utility.profile_generation_evidence_changed.connect(
		func(changed_profile_id: StringName, changed_generation: int) -> void:
			if changed_profile_id != profile.profile_id:
				return
			observed_generations.append(changed_generation)
			observed_evidence.append(
				_profile_utility.get_generation_evidence_for_framework(
					changed_profile_id,
					changed_generation
				)
			)
			observed_snapshots.append(
				_profile_utility.get_profile_state_snapshot(changed_profile_id)
			)
	) as Error
	var operation: GFSaveProfileOperation = _profile_utility.save_profile(profile.profile_id)
	_profile_utility.tick(0.0)
	var generation: int = operation.get_requested_generation()
	var _advanced: bool = _clock.advance_msec(11)
	_profile_utility.tick(0.0)

	assert_eq(operation.get_result().get_status(), GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(observed_evidence.size(), 1)
	if observed_evidence.size() != 1:
		return
	var unknown_evidence: Dictionary = observed_evidence[0]
	var unknown_snapshot: Dictionary = observed_snapshots[0]
	assert_eq(observed_generations[0], generation)
	assert_eq(
		GFVariantData.get_option_string_name(unknown_evidence, "state"),
		&"outcome_unknown"
	)
	assert_eq(
		GFVariantData.get_option_string_name(unknown_evidence, "status"),
		GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN
	)
	assert_true(GFVariantData.get_option_bool(unknown_snapshot, "write_outcome_unknown"))
	assert_eq(GFVariantData.get_option_int(unknown_snapshot, "detached_write_count"), 1)
	assert_eq(
		_get_packed_int64_array(unknown_evidence, "storage_request_ids"),
		_get_packed_int64_array(unknown_snapshot, "detached_storage_request_ids")
	)
	assert_eq(
		_get_packed_int64_array(unknown_snapshot, "unknown_write_generations"),
		PackedInt64Array([generation])
	)

	_storage.complete_next_save(OK)
	assert_eq(observed_evidence.size(), 2)
	if observed_evidence.size() != 2:
		return
	var persisted_evidence: Dictionary = observed_evidence[1]
	var persisted_snapshot: Dictionary = observed_snapshots[1]
	assert_eq(observed_generations[1], generation)
	assert_eq(
		GFVariantData.get_option_string_name(persisted_evidence, "state"),
		&"persisted"
	)
	assert_eq(
		GFVariantData.get_option_int(persisted_evidence, "persisted_generation"),
		generation
	)
	assert_eq(
		_get_packed_int64_array(persisted_evidence, "storage_request_ids"),
		PackedInt64Array()
	)
	assert_false(GFVariantData.get_option_bool(persisted_snapshot, "write_outcome_unknown"))
	assert_eq(GFVariantData.get_option_int(persisted_snapshot, "detached_write_count"), 0)
	assert_eq(
		_get_packed_int64_array(persisted_snapshot, "detached_storage_request_ids"),
		PackedInt64Array()
	)


func test_manager_owner_dispose_inside_apply_rechecks_permit_and_rolls_back() -> void:
	var events: Array[String] = []
	var first: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"first", 1, events)
	)
	var second: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"second", 2, events)
	)
	var providers: Array[GFSaveSectionProvider] = [first, second]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.owner_dispose_apply",
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
	var candidates: Array[GFSaveSection] = [
		first.make_section({ "value": 10 }),
		second.make_section({ "value": 20 }),
	]
	second.apply_callback = func() -> void:
		manager_owner.free()
	var apply_result: Dictionary = (
		_profile_utility.apply_profile_candidates_for_manager_for_framework(
			profile.profile_id,
			candidates,
			{},
			permit
		)
	)
	second.apply_callback = Callable()

	assert_false(GFVariantData.get_option_bool(apply_result, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(apply_result, "failure_stage"),
		&"apply"
	)
	assert_eq(GFVariantData.get_option_int(apply_result, "error_code"), int(ERR_UNAUTHORIZED))
	assert_eq(first.value, 1)
	assert_eq(second.value, 2)
	assert_lt(events.find("rollback:second"), events.find("rollback:first"))
	assert_true(
		GFVariantData.get_option_array(apply_result, "rollback_errors").is_empty()
	)
	assert_true(_profile_utility.unregister_profile(profile.profile_id))


func test_mutation_callback_reentry_and_coordinator_dispose_restore_once() -> void:
	var provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = (
		GFSaveProfileTransactionTestSupport.make_provider(&"state", 5)
	)
	var providers: Array[GFSaveSectionProvider] = [provider]
	var profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"mutation.callback_dispose",
		providers
	)
	assert_true(_register(profile))
	_activate_existing(profile, { &"state": { "value": 5 } })
	var nested_request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 51),
	])
	var nested_operations: Array[GFSaveProfileTransactionOperation] = []
	provider.apply_callback = func() -> void:
		nested_operations.append(_coordinator.mutate_and_persist(
			profile.profile_id,
			nested_request
		))
		_coordinator.dispose()
	var outer_request: GFSaveProfileMutationRequest = _make_request([
		_make_mutation(&"state", 50),
	])
	var outer: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		profile.profile_id,
		outer_request
	)
	var terminal_statuses: Array[StringName] = []
	var _connected: Error = outer.completed.connect(
		func(result: GFSaveProfileTransactionResult) -> void:
			terminal_statuses.append(result.get_status())
	) as Error
	_tick_queued_mutation()
	provider.apply_callback = Callable()

	assert_true(outer_request.is_claimed())
	assert_eq(nested_operations.size(), 1)
	assert_true(nested_operations[0].is_completed())
	assert_eq(
		nested_operations[0].get_result().get_status(),
		GFSaveProfileTransactionResult.STATUS_BUSY
	)
	assert_false(nested_request.is_claimed(), "重入准入拒绝不得消费 mutation request。")
	assert_true(outer.is_completed(), "回调内 dispose 不得遗留 pending 外层事务。")
	assert_eq(provider.value, 5, "物理写入前的关闭必须恢复已 apply 的内存状态。")
	assert_eq(provider.rollback_count, 1)
	assert_eq(_storage.get_pending_save_count(), 0)
	if not outer.is_completed():
		return
	assert_eq(outer.get_result().get_status(), GFSaveProfileTransactionResult.STATUS_DISPOSED)
	assert_eq(terminal_statuses, [GFSaveProfileTransactionResult.STATUS_DISPOSED])
	_coordinator.dispose()
	assert_eq(terminal_statuses.size(), 1)


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


func _make_mutation(section_id: StringName, value: int) -> GFSaveSectionMutation:
	return GFSaveSectionMutation.take_ownership(
		section_id,
		1,
		{ "value": value }
	)


func _make_request(
	mutations: Array[GFSaveSectionMutation]
) -> GFSaveProfileMutationRequest:
	return GFSaveProfileMutationRequest.take_ownership(mutations, {}, {}, {})


func _get_packed_int64_array(source: Dictionary, key: String) -> PackedInt64Array:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is PackedInt64Array:
		var values: PackedInt64Array = value
		return values
	return PackedInt64Array()


func _tick_queued_mutation() -> void:
	_profile_utility.tick(0.0)
	_coordinator.tick(0.0)
	_profile_utility.tick(0.0)
