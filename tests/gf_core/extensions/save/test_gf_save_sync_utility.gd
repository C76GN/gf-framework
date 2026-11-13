extends GutTest


const TRANSPORT_SCRIPT = preload("res://tests/gf_core/standard/utilities/storage/fixtures/controlled_storage_sync_transport.gd")
var _storage: GFSaveProfileTransactionTestSupport.ControlledStorage
var _profiles: GFSaveProfileUtility
var _coordinator: GFSaveProfileTransactionCoordinator
var _sync: GFSaveSyncUtility
var _provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider
var _profile: GFSaveProfile
var _transport: TRANSPORT_SCRIPT
var _clock: ManualClock


func before_each() -> void:
	_transport = TRANSPORT_SCRIPT.new()
	_create_runtime()
	_activate()
	assert_true(
		_sync.open_session(
			_profile.profile_id,
			"account-a",
			"profile",
			_transport
		)
	)


func after_each() -> void:
	_dispose_runtime()
	_transport.pending.clear()


func test_upload_budget_failure_is_distinct_from_projection_failure_without_remote_io() -> void:
	var payload: Dictionary = { "value": 1 }
	var cursor: Dictionary = payload
	for index: int in range(62):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	var oversized: GFSaveDocument = GFSaveDocument.new().configure(
		_profile.get_effective_schema_id(),
		1,
		[
			GFSaveSection.new().configure(
				&"state",
				1,
				payload
			),
		]
	)
	assert_true(
		GFVariantData.get_option_bool(
			oversized.validate_document(),
			"ok"
		)
	)
	var projection: OversizedProjection = OversizedProjection.new()
	projection.candidate = oversized
	_sync.dispose()
	_sync = GFSaveSyncUtility.new()
	assert_true(
		_sync.setup(
			_profiles,
			_coordinator,
			projection,
			_clock
		)
	)
	assert_true(
		_sync.open_session(
			_profile.profile_id,
			"account-a",
			"profile",
			_transport
		)
	)
	var completion: GFAsyncCompletion = _sync.synchronize("oversized")
	var result: Dictionary = _result(completion)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		&"upload_budget_exceeded"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "error_kind"),
		&"request_budget_exceeded"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "layer"),
		&"storage_sync_request"
	)
	assert_true(_transport.calls.is_empty())
	assert_eq(
		_storage.get_pending_save_count(),
		0
	)


func test_push_uses_two_local_transactions_and_upload_projection_excludes_checkpoint() -> void:
	var completion: GFAsyncCompletion = _sync.synchronize("upload")
	assert_false(completion.is_completed())
	_complete_local()
	assert_eq(
		_transport.calls,
		[&"read", &"write"]
	)
	assert_false(completion.is_completed())
	_complete_local()
	var result: Dictionary = _result(completion)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		&"committed"
	)
	assert_eq(
		_storage.save_calls.size(),
		2,
		"意图和确认复用两个本地事务，不增加网络等待中的业务锁。"
	)
	var history: Dictionary = _transport.history.values()[0]
	var uploaded: GFSaveDocument = GFSaveDocument.from_dict(GFVariantData.get_option_dictionary(history, "candidate"))
	assert_false(uploaded.get_metadata().has("_gf_sync"))
	assert_false(uploaded.get_metadata().has("local_only"))
	var snapshot: Dictionary = _profiles.get_sync_snapshot_for_framework(_profile.profile_id)
	var local_document: GFSaveDocument = snapshot["document"]
	assert_eq(
		GFVariantData.get_option_string(
			local_document.get_metadata(),
			"local_only"
		),
		"device"
	)
	assert_true(
		GFVariantData.get_option_dictionary(
			_checkpoint(),
			"intent"
		).is_empty()
	)


func test_later_local_mutation_is_not_acknowledged_by_earlier_remote_commit() -> void:
	_transport.held = [&"write"]
	var completion: GFAsyncCompletion = _sync.synchronize("old-upload")
	_complete_local()
	var mutation: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create(
		[
			GFSaveSectionMutation.take_ownership(
				&"state",
				1,
				{ "value": 9 }
			),
		]
	)
	var business: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile.profile_id, mutation)
	_complete_local()
	assert_true(business.get_result().is_successful())
	assert_eq(_provider.value, 9)
	assert_eq(
		_profiles.get_sync_generation_for_framework(_profile.profile_id),
		1
	)
	var _delivered: Dictionary = _transport.execute()
	_complete_local()
	assert_true(
		GFVariantData.get_option_bool(
			_result(completion),
			"ok"
		)
	)
	assert_eq(
		GFVariantData.get_option_int(
			_checkpoint(),
			"acknowledged_generation"
		),
		0
	)
	assert_eq(
		GFVariantData.get_option_int(
			_checkpoint(),
			"local_generation"
		),
		1
	)
	assert_eq(_provider.value, 9)


func test_restart_probes_persisted_original_intent_without_resending_upload() -> void:
	_transport.held = [&"write"]
	var completion: GFAsyncCompletion = _sync.synchronize("lost-response")
	_complete_local()
	var _undelivered: Dictionary = _transport.execute(0, false)
	assert_true(_sync.cancel_wait())
	assert_true(
		GFVariantData.get_option_bool(
			_result(completion),
			"requires_recovery"
		)
	)
	var saved: Dictionary = GFVariantData.get_option_dictionary(
		_storage.save_calls[-1],
		"data"
	).duplicate(true)
	_dispose_runtime()
	_create_runtime()
	_activate(GFSaveDocument.from_dict(saved))
	assert_true(
		_sync.open_session(
			_profile.profile_id,
			"account-a",
			"profile",
			_transport
		)
	)
	var recovery: GFAsyncCompletion = _sync.recover_pending()
	_complete_local()
	assert_true(
		GFVariantData.get_option_bool(
			_result(recovery),
			"ok"
		)
	)
	assert_eq(
		_transport.calls.count(&"write"),
		1
	)
	assert_eq(
		_transport.calls.count(&"probe"),
		1
	)
	assert_true(
		GFVariantData.get_option_dictionary(
			_checkpoint(),
			"intent"
		).is_empty()
	)


func test_checkpoint_failure_reports_remote_commit_and_keeps_recovery_intent() -> void:
	var completion: GFAsyncCompletion = _sync.synchronize("checkpoint-failure")
	_complete_local()
	_complete_local(ERR_INVALID_DATA)
	var result: Dictionary = _result(completion)
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		&"recovery_required"
	)
	var remote: GFStorageSyncResult = result["sync_result"]
	assert_true(remote.is_remote_committed())
	var recover_local: GFSaveProfileOperation = _profiles.save_profile(_profile.profile_id)
	_complete_local()
	assert_true(recover_local.get_result().is_successful())
	var recovery: GFAsyncCompletion = _sync.recover_pending()
	_complete_local()
	assert_true(
		GFVariantData.get_option_bool(
			_result(recovery),
			"ok"
		)
	)
	assert_eq(
		_transport.calls.count(&"write"),
		1
	)


func test_unknown_local_checkpoint_exposes_profile_reconcile_lease() -> void:
	var completion: GFAsyncCompletion = _sync.synchronize("local-unknown")
	_complete_local()
	assert_eq(
		_storage.get_pending_save_count(),
		1
	)
	_clock.now = 31000
	_pump()
	var result: Dictionary = _result(completion)
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		&"recovery_required"
	)
	var remote: GFStorageSyncResult = result["sync_result"]
	assert_true(remote.is_remote_committed())
	var local_result: GFSaveProfileTransactionResult = result["local_result"]
	assert_not_null(local_result)
	assert_eq(
		local_result.get_status(),
		GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN
	)
	var lease: GFSaveProfileReconcileLease = local_result.get_reconcile_lease()
	assert_not_null(lease, "远端结果不能吞掉本地对账所需的精确 lease。")
	var saved: GFSaveDocument = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(
			_storage.save_calls[-1],
			"data"
		)
	)
	_storage.complete_next_save(OK)
	_pump()
	var reconciled: GFSaveProfileTransactionOperation = _coordinator.reconcile_profile(lease)
	_profiles.tick(0.0)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(saved))
	assert_true(reconciled.get_result().is_successful())
	assert_eq(
		GFVariantData.get_option_string_name(
			_result(_sync.recover_pending()),
			"status"
		),
		&"no_pending_intent"
	)
	assert_eq(
		_transport.calls.count(&"write"),
		1
	)


func test_pull_is_atomic_and_preserves_local_only_metadata() -> void:
	_transport.put(
		"account-a",
		"profile",
		_remote_document(12).to_dict(),
		"remote-revision"
	)
	var completion: GFAsyncCompletion = _sync.synchronize(
		"download",
		{ "mode": &"pull" }
	)
	_pump()
	assert_eq(_provider.value, 12)
	assert_false(completion.is_completed())
	_storage.complete_next_save(OK)
	_pump()
	var result: Dictionary = _result(completion)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_true(GFVariantData.get_option_bool(result, "local_applied"))
	assert_eq(
		GFVariantData.get_option_int(
			_checkpoint(),
			"local_generation"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(
			_checkpoint(),
			"acknowledged_generation"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_string(
			_checkpoint(),
			"revision"
		),
		"remote-revision"
	)
	assert_false(_transport.calls.has(&"write"))
	var document: GFSaveDocument = _profiles.get_sync_snapshot_for_framework(_profile.profile_id)["document"]
	assert_eq(
		GFVariantData.get_option_string(
			document.get_metadata(),
			"local_only"
		),
		"device"
	)


func test_future_document_version_is_rejected_before_download_projection() -> void:
	var remote: Dictionary = _remote_document(12).to_dict()
	remote["schema_version"] = 2
	_transport.put(
		"account-a",
		"profile",
		remote,
		"future-revision"
	)
	var completion: GFAsyncCompletion = _sync.synchronize(
		"future",
		{ "mode": &"pull" }
	)
	_pump()
	assert_true(completion.is_completed())
	assert_eq(_provider.value, 1)
	assert_eq(
		_storage.save_calls.size(),
		0
	)
	if completion.is_completed():
		assert_false(
			GFVariantData.get_option_bool(
				_result(completion),
				"ok"
			)
		)
	if _storage.get_pending_save_count() > 0:
		_storage.complete_next_save(OK)
		_pump()


func test_download_does_not_overwrite_local_change_made_while_remote_was_pending() -> void:
	_transport.held = [&"read"]
	_transport.put(
		"account-a",
		"profile",
		_remote_document(12).to_dict(),
		"remote-revision"
	)
	var completion: GFAsyncCompletion = _sync.synchronize(
		"download",
		{ "mode": &"pull" }
	)
	var business: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(
		_profile.profile_id,
		GFSaveProfileMutationRequest.create(
			[
				GFSaveSectionMutation.take_ownership(
					&"state",
					1,
					{ "value": 6 }
				),
			]
		)
	)
	_complete_local()
	assert_true(business.get_result().is_successful())
	var _delivered: Dictionary = _transport.execute()
	assert_eq(
		GFVariantData.get_option_string_name(
			_result(completion),
			"status"
		),
		&"local_generation_changed"
	)
	assert_eq(_provider.value, 6)
	assert_eq(
		_storage.get_pending_save_count(),
		0
	)


func test_closed_session_late_response_cannot_write_into_new_account() -> void:
	_transport.held = [&"write"]
	var completion: GFAsyncCompletion = _sync.synchronize("old-account")
	_complete_local()
	_sync.close_session()
	assert_true(
		GFVariantData.get_option_bool(
			_result(completion),
			"requires_recovery"
		)
	)
	assert_false(
		_sync.open_session(
			_profile.profile_id,
			"account-b",
			"profile",
			_transport
		)
	)
	var _delivered: Dictionary = _transport.execute()
	_pump()
	assert_eq(
		_storage.save_calls.size(),
		1
	)
	assert_eq(
		GFVariantData.get_option_string(
			_checkpoint(),
			"namespace"
		),
		"account-a"
	)


func test_switch_to_isolated_account_profile_ignores_old_response() -> void:
	_transport.held = [&"write"]
	var old: GFAsyncCompletion = _sync.synchronize("account-a-upload")
	_complete_local()
	var other_provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider = GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	var other_profile: GFSaveProfile = GFSaveProfileTransactionTestSupport.make_profile(
		&"account_b",
		[other_provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_coordinator.register_profile(other_profile),
			"registered"
		)
	)
	assert_true(_sync.prepare_profile(other_profile.profile_id))
	var activated: GFSaveProfileTransactionOperation = _coordinator.activate_profile(other_profile.profile_id)
	_profiles.tick(0.0)
	_storage.complete_next_load(
		GFSaveProfileTransactionTestSupport.read_success(
			GFSaveProfileTransactionTestSupport.make_document(
				other_profile,
				{
					"state": { "value": 20 },
				}
			)
		)
	)
	assert_true(activated.get_result().is_successful())
	assert_true(
		_sync.open_session(
			other_profile.profile_id,
			"account-b",
			"profile",
			_transport
		)
	)
	assert_true(old.is_completed())
	var _late: Dictionary = _transport.execute()
	_pump()
	assert_eq(other_provider.value, 20)
	var other_snapshot: Dictionary = _profiles.get_sync_snapshot_for_framework(other_profile.profile_id)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(other_snapshot, "checkpoint"),
			"namespace"
		),
		""
	)
	_transport.held.clear()
	var next: GFAsyncCompletion = _sync.synchronize("account-b-upload")
	_complete_local()
	_complete_local()
	assert_true(
		GFVariantData.get_option_bool(
			_result(next),
			"ok"
		)
	)
	other_snapshot = _profiles.get_sync_snapshot_for_framework(other_profile.profile_id)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(other_snapshot, "checkpoint"),
			"namespace"
		),
		"account-b"
	)
	assert_eq(
		GFVariantData.get_option_string(
			_checkpoint(),
			"namespace"
		),
		"account-a"
	)


func test_pending_intent_blocks_download_from_discarding_recovery_and_preview_stays_readonly() -> void:
	_transport.held = [&"write"]
	var original: GFAsyncCompletion = _sync.synchronize("unknown")
	_complete_local()
	assert_true(_sync.cancel_wait())
	assert_true(original.is_completed())
	var blocked: GFAsyncCompletion = _sync.synchronize(
		"pull",
		{ "mode": &"pull" }
	)
	assert_eq(
		GFVariantData.get_option_string_name(
			_result(blocked),
			"status"
		),
		&"recovery_pending"
	)
	var preview: GFAsyncCompletion = _sync.synchronize(
		"preview",
		{ "mode": &"preview" }
	)
	assert_true(
		GFVariantData.get_option_bool(
			_result(preview),
			"ok"
		)
	)
	assert_eq(
		_storage.save_calls.size(),
		1
	)
	assert_false(
		GFVariantData.get_option_dictionary(
			_checkpoint(),
			"intent"
		).is_empty()
	)


func test_remote_checkpoint_injection_is_rejected_before_local_apply() -> void:
	var remote: GFSaveDocument = _remote_document(99)
	remote = GFSaveDocument.new().configure(
		remote.get_schema_id(),
		1,
		remote.get_sections(),
		{
			"_gf_sync": { "namespace": "attacker" },
		}
	)
	_transport.put(
		"account-a",
		"profile",
		remote.to_dict(),
		"injected"
	)
	var completion: GFAsyncCompletion = _sync.synchronize(
		"pull",
		{ "mode": &"pull" }
	)
	assert_eq(
		GFVariantData.get_option_string_name(
			_result(completion),
			"status"
		),
		&"invalid_remote_document"
	)
	assert_eq(_provider.value, 1)
	assert_true(_storage.save_calls.is_empty())


func _create_runtime() -> void:
	_storage = GFSaveProfileTransactionTestSupport.ControlledStorage.new()
	_clock = ManualClock.new()
	_profiles = GFSaveProfileUtility.new().setup(_storage, _clock)
	_storage.driver = _profiles
	_coordinator = GFSaveProfileTransactionCoordinator.new().setup(_profiles)
	_provider = GFSaveProfileTransactionTestSupport.make_provider(&"state", 0)
	_profile = GFSaveProfileTransactionTestSupport.make_profile(
		&"cloud_profile",
		[_provider]
	)
	assert_true(
		GFVariantData.get_option_bool(
			_coordinator.register_profile(_profile),
			"registered"
		)
	)
	_sync = GFSaveSyncUtility.new()
	assert_true(
		_sync.setup(
			_profiles,
			_coordinator,
			ExplicitProjection.new(),
			_clock
		)
	)
	assert_true(_sync.prepare_profile(_profile.profile_id))


func _dispose_runtime() -> void:
	_sync.dispose()
	_coordinator.dispose()
	_profiles.dispose()
	_storage.driver = null
	_storage.dispose()


func _activate(document: GFSaveDocument = null) -> void:
	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(_profile.profile_id)
	_profiles.tick(0.0)
	var candidate: GFSaveDocument = document
	if candidate == null:
		candidate = GFSaveDocument.new().configure(
			_profile.get_effective_schema_id(),
			1,
			[
				GFSaveSection.new().configure(
					&"state",
					1,
					{ "value": 1 }
				),
			],
			{ "local_only": "device" }
		)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(candidate))
	assert_true(
		activation.get_result().is_successful(),
		activation.get_result().get_error()
	)


func _remote_document(value: int) -> GFSaveDocument:
	return GFSaveDocument.new().configure(
		_profile.get_effective_schema_id(),
		1,
		[
			GFSaveSection.new().configure(
				&"state",
				1,
				{ "value": value }
			),
		]
	)


func _pump() -> void:
	for index: int in range(3):
		_profiles.tick(0.0)
		_coordinator.tick(0.0)
		_sync.tick(0.0)


func _complete_local(error: Error = OK) -> void:
	_pump()
	assert_eq(
		_storage.get_pending_save_count(),
		1
	)
	_storage.complete_next_save(error)
	_pump()


func _result(completion: GFAsyncCompletion) -> Dictionary:
	assert_true(completion.is_completed())
	return GFVariantData.as_dictionary(completion.get_result())


func _checkpoint() -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_profiles.get_sync_snapshot_for_framework(_profile.profile_id),
		"checkpoint"
	)


class ExplicitProjection extends GFSaveSyncProjection:
	func _project_upload(document: GFSaveDocument) -> GFSaveDocument:
		return GFSaveDocument.new().configure(
			document.get_schema_id(),
			document.get_schema_version(),
			document.get_sections(),
			{}
		)


	func _prepare_download(remote: GFSaveDocument, current: GFSaveDocument) -> GFSaveDocument:
		return GFSaveDocument.new().configure(
			current.get_schema_id(),
			current.get_schema_version(),
			remote.get_sections(),
			current.get_metadata()
		)


class ManualClock extends GFClock:
	var now: int = 0

	func get_monotonic_msec() -> int:
		return now


class OversizedProjection extends GFSaveSyncProjection:
	var candidate: GFSaveDocument = null


	func _project_upload(_document: GFSaveDocument) -> GFSaveDocument:
		return candidate
