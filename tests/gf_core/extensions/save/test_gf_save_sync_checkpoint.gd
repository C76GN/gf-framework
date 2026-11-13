extends GutTest


const CHECKPOINT_SCRIPT = preload("res://addons/gf/extensions/save/sync/gf_save_sync_checkpoint.gd")
var _storage: GFSaveProfileTransactionTestSupport.ControlledStorage
var _utility: GFSaveProfileUtility
var _coordinator: GFSaveProfileTransactionCoordinator
var _provider: GFSaveProfileTransactionTestSupport.MemorySectionProvider
var _profile: GFSaveProfile


func before_each() -> void:
	_storage = GFSaveProfileTransactionTestSupport.ControlledStorage.new()
	_utility = GFSaveProfileUtility.new().setup(_storage)
	_storage.driver = _utility
	_coordinator = GFSaveProfileTransactionCoordinator.new().setup(_utility)
	_provider = GFSaveProfileTransactionTestSupport.MemorySectionProvider.new()
	_provider.section_id = &"state"
	_profile = GFSaveProfileTransactionTestSupport.make_profile(
		&"sync_profile",
		[_provider]
	)
	_profile.preserved_sections = PackedStringArray(["future"])
	assert_true(
		GFVariantData.get_option_bool(
			_coordinator.register_profile(_profile),
			"registered"
		)
	)
	assert_true(_utility.enable_sync_snapshot_for_framework(_profile.profile_id))


func after_each() -> void:
	_coordinator.dispose()
	_utility.dispose()
	_storage.driver = null
	_storage.dispose()


func test_public_requests_cannot_write_reserved_checkpoint_or_empty_mutations() -> void:
	assert_null(
		GFSaveProfileRequest.create(
			{ "_gf_sync": {} },
			{},
			{}
		)
	)
	var mutation: GFSaveSectionMutation = GFSaveSectionMutation.take_ownership(
		&"state",
		1,
		{ "value": 2 }
	)
	assert_null(
		GFSaveProfileMutationRequest.create(
			[mutation],
			{ "_gf_sync": {} }
		)
	)
	assert_true(mutation.is_available())
	assert_null(GFSaveProfileMutationRequest.create([]))
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["unexpected"] = true
	assert_false(CHECKPOINT_SCRIPT.validate(checkpoint))


func test_checkpoint_only_transaction_and_ordinary_save_preserve_account_and_ack() -> void:
	_activate()
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["namespace"] = "account-a"
	checkpoint["record_key"] = "profile"
	var operation: GFSaveProfileTransactionOperation = _checkpoint(checkpoint, 0)
	assert_eq(
		_utility.get_sync_generation_for_framework(_profile.profile_id),
		0
	)
	assert_false(operation.is_completed())
	_storage.complete_next_save(OK)
	assert_true(operation.get_result().is_successful())
	var saved: Dictionary = _snapshot_checkpoint()
	assert_eq(
		GFVariantData.get_option_string(saved, "namespace"),
		"account-a"
	)
	_provider.value = 8
	var ordinary: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	assert_eq(
		_utility.get_sync_generation_for_framework(_profile.profile_id),
		1
	)
	_storage.complete_next_save(OK)
	assert_true(ordinary.get_result().is_successful())
	saved = _snapshot_checkpoint()
	assert_eq(
		GFVariantData.get_option_string(saved, "namespace"),
		"account-a"
	)
	assert_eq(
		GFVariantData.get_option_int(saved, "local_generation"),
		1
	)
	assert_eq(
		GFVariantData.get_option_int(saved, "acknowledged_generation"),
		0
	)


func test_failed_checkpoint_does_not_become_confirmed_after_recovery_save() -> void:
	_activate()
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["namespace"] = "unconfirmed-account"
	checkpoint["record_key"] = "profile"
	var failed: GFSaveProfileTransactionOperation = _checkpoint(checkpoint, 0)
	_storage.complete_next_save(ERR_INVALID_DATA)
	assert_false(failed.get_result().is_successful())
	assert_true(_utility.get_sync_snapshot_for_framework(_profile.profile_id).is_empty())
	var recovery: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(recovery.get_result().is_successful())
	assert_eq(
		GFVariantData.get_option_string(
			_snapshot_checkpoint(),
			"namespace"
		),
		""
	)


func test_stale_download_generation_is_rejected_before_provider_apply() -> void:
	_activate()
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["local_generation"] = 1
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_for_framework(
		[
			GFSaveSectionMutation.take_ownership(
				&"state",
				1,
				{ "value": 999 }
			),
		],
		checkpoint,
		0,
		{}
	)
	_provider.value = 3
	var ordinary: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(ordinary.get_result().is_successful())
	var rejected: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile.profile_id, request)
	_utility.tick(0.0)
	_coordinator.tick(0.0)
	assert_true(rejected.is_completed())
	assert_false(rejected.get_result().is_successful())
	assert_eq(_provider.value, 3)
	assert_eq(
		_storage.get_pending_save_count(),
		0
	)


func test_download_candidate_and_checkpoint_rollback_as_one_transaction() -> void:
	_activate()
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["namespace"] = "account"
	checkpoint["record_key"] = "profile"
	checkpoint["revision"] = "remote-revision"
	checkpoint["local_generation"] = 1
	checkpoint["acknowledged_generation"] = 1
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_for_framework(
		[
			GFSaveSectionMutation.take_ownership(
				&"state",
				1,
				{ "value": 8 }
			),
		],
		checkpoint,
		0,
		{}
	)
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile.profile_id, request)
	_pump()
	assert_eq(_provider.value, 8)
	_storage.complete_next_save(ERR_INVALID_DATA)
	assert_false(operation.get_result().is_successful())
	assert_eq(_provider.value, 1)
	var recovery: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(recovery.get_result().is_successful())
	assert_eq(
		GFVariantData.get_option_string(
			_snapshot_checkpoint(),
			"revision"
		),
		""
	)


func test_loaded_checkpoint_resumes_generation_and_upload_projection_strips_it() -> void:
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["namespace"] = "account"
	checkpoint["record_key"] = "profile"
	checkpoint["local_generation"] = 20
	checkpoint["acknowledged_generation"] = 18
	checkpoint["revision"] = "r18"
	_activate(checkpoint)
	assert_eq(
		_utility.get_sync_generation_for_framework(_profile.profile_id),
		20
	)
	var snapshot: Dictionary = _utility.get_sync_snapshot_for_framework(_profile.profile_id)
	var document: GFSaveDocument = snapshot["document"]
	assert_false(CHECKPOINT_SCRIPT.project_document(document).get_metadata().has("_gf_sync"))
	assert_true(document.get_metadata().has("_gf_sync"))
	var saved: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(saved.get_result().is_successful())
	assert_eq(
		GFVariantData.get_option_int(
			_snapshot_checkpoint(),
			"local_generation"
		),
		21
	)


func test_complete_download_document_preserves_unknown_sections_and_rolls_back() -> void:
	_activate()
	var checkpoint: Dictionary = CHECKPOINT_SCRIPT.initial()
	checkpoint["namespace"] = "account"
	checkpoint["record_key"] = "profile"
	checkpoint["local_generation"] = 1
	checkpoint["acknowledged_generation"] = 1
	checkpoint["revision"] = "remote"
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		_profile.get_effective_schema_id(),
		1,
		[
			GFSaveSection.new().configure(
				&"state",
				1,
				{ "value": 7 }
			),
			GFSaveSection.new().configure(
				&"future",
				3,
				{
					"content": ["kept"],
				}
			),
		],
		{ "project": "downloaded" }
	)
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_document_for_framework(
		document,
		checkpoint,
		0
	)
	assert_not_null(request)
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile.profile_id, request)
	_pump()
	var written: GFSaveDocument = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(
			_storage.save_calls[-1],
			"data"
		)
	)
	assert_true(written.has_section(&"future"))
	_storage.complete_next_save(ERR_INVALID_DATA)
	assert_false(operation.get_result().is_successful())
	assert_eq(_provider.value, 1)
	var recovery: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(recovery.get_result().is_successful())
	written = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(
			_storage.save_calls[-1],
			"data"
		)
	)
	assert_false(
		written.has_section(&"future"),
		"失败必须回滚未注册但允许保留的分区。"
	)
	var generation: int = _utility.get_sync_generation_for_framework(_profile.profile_id)
	checkpoint["local_generation"] = generation + 1
	checkpoint["acknowledged_generation"] = generation + 1
	request = GFSaveProfileMutationRequest.create_sync_document_for_framework(
		document,
		checkpoint,
		generation
	)
	operation = _coordinator.mutate_and_persist(_profile.profile_id, request)
	_pump()
	_storage.complete_next_save(OK)
	assert_true(operation.get_result().is_successful())
	var ordinary: GFSaveProfileOperation = _utility.save_profile(_profile.profile_id)
	_utility.tick(0.0)
	_storage.complete_next_save(OK)
	assert_true(ordinary.get_result().is_successful())
	written = GFSaveDocument.from_dict(
		GFVariantData.get_option_dictionary(
			_storage.save_calls[-1],
			"data"
		)
	)
	assert_true(
		written.has_section(&"future"),
		"成功下载的保留分区必须在普通保存后继续存在。"
	)


func test_malformed_checkpoint_rejected_before_runtime_apply() -> void:
	_provider.value = 5
	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(_profile.profile_id)
	_utility.tick(0.0)
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		_profile.get_effective_schema_id(),
		_profile.schema_version,
		[
			GFSaveSection.new().configure(
				&"state",
				1,
				{ "value": 99 }
			),
		],
		{
			"_gf_sync": { "namespace": "bad" },
		}
	)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(document))
	assert_false(activation.get_result().is_successful())
	assert_eq(_provider.value, 5)


func _activate(checkpoint: Dictionary = {}) -> void:
	var activation: GFSaveProfileTransactionOperation = _coordinator.activate_profile(_profile.profile_id)
	_utility.tick(0.0)
	var metadata: Dictionary = { "project": "kept" }
	if not checkpoint.is_empty():
		metadata["_gf_sync"] = checkpoint
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		_profile.get_effective_schema_id(),
		_profile.schema_version,
		[
			GFSaveSection.new().configure(
				&"state",
				1,
				{ "value": 1 }
			),
		],
		metadata
	)
	_storage.complete_next_load(GFSaveProfileTransactionTestSupport.read_success(document))
	assert_true(
		activation.get_result().is_successful(),
		activation.get_result().get_error()
	)


func _checkpoint(checkpoint: Dictionary, expected_generation: int) -> GFSaveProfileTransactionOperation:
	var request: GFSaveProfileMutationRequest = GFSaveProfileMutationRequest.create_sync_for_framework(
		[],
		checkpoint,
		expected_generation,
		{ "project": "kept" }
	)
	assert_not_null(request)
	var operation: GFSaveProfileTransactionOperation = _coordinator.mutate_and_persist(_profile.profile_id, request)
	_pump()
	assert_eq(
		_storage.get_pending_save_count(),
		1
	)
	return operation


func _pump() -> void:
	_utility.tick(0.0)
	_coordinator.tick(0.0)
	_utility.tick(0.0)


func _snapshot_checkpoint() -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_utility.get_sync_snapshot_for_framework(_profile.profile_id),
		"checkpoint"
	)
