## 测试 GFStorageUtility 的显式 logical-family reset 授权、隔离与终态契约。
extends GutTest


# --- 常量 ---

const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)
const _GF_TEST_DIRECTORY_LINK_FIXTURE = preload(
	"res://tests/gf_core/support/gf_test_directory_link_fixture.gd"
)
const _PUMP_FRAME_LIMIT: int = 300
const _OVERSIZED_RESET_INTENT_BYTES: int = 16 * 1024 + 1


# --- 私有变量 ---

var _storage: GFStorageUtility = null
var _save_dir_name: String = ""
var _storage_root_path: String = ""
var _architectures: Array[GFArchitecture] = []
var _external_fixture_roots: Array[String] = []
var _completion_listener_quiesce: GFAsyncCompletion = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_completion_listener_quiesce = null
	_save_dir_name = "gf-storage-family-reset-" + GFUuid.generate_v4()
	_storage_root_path = (
		_GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
			_save_dir_name
		)
	)
	assert_true(
		_storage_root_path.begins_with("user://gf-storage-family-reset-"),
		"family reset 测试必须使用 UUID 独占 Storage root。"
	)
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0
	_storage.init()


func after_each() -> void:
	for architecture: GFArchitecture in _architectures:
		if is_instance_valid(architecture):
			architecture.dispose()
	_architectures.clear()
	if _storage != null:
		if _storage is GatedThreadedResetStorageUtility:
			var gated_storage: GatedThreadedResetStorageUtility = _storage
			gated_storage.release_all_for_test()
		_storage.dispose()
		_storage = null
	if _storage_root_path.begins_with("user://gf-storage-family-reset-"):
		assert_eq(_remove_owned_test_tree(_storage_root_path), OK)
	for external_root: String in _external_fixture_roots:
		if external_root.begins_with(
			"user://gf-storage-family-reset-sentinel-"
		):
			assert_eq(_remove_owned_test_tree(external_root), OK)
	_external_fixture_roots.clear()
	_completion_listener_quiesce = null
	_save_dir_name = ""
	_storage_root_path = ""


# --- 公共方法 ---

func test_reset_public_contract_is_typed_and_explicit() -> void:
	assert_true(_storage.has_method(&"create_family_reset_authorization"))
	assert_true(_storage.has_method(&"reset_file_family"))
	assert_true(_storage.has_method(&"reset_file_family_request_async"))
	assert_eq(_get_method_argument_count(_storage, &"create_family_reset_authorization"), 2)
	assert_eq(_get_method_argument_count(_storage, &"reset_file_family"), 2)
	assert_eq(_get_method_argument_count(_storage, &"reset_file_family_request_async"), 3)
	assert_eq(GFStorageAsyncOperation.OPERATION_RESET, &"reset")
	assert_true(GFStorageAsyncResult.new().has_method(&"get_reset_result"))


func test_authorization_requires_bound_unmodified_corrupt_read_evidence() -> void:
	var file_name: String = "authorization/evidence.json"
	var rejected_results: Array[GFStorageReadResult] = [
		GFStorageReadResult.new().configure_success({ "value": 1 }),
		_make_read_failure(
			GFStorageReadResult.FailureKind.NOT_FOUND,
			ERR_FILE_NOT_FOUND
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.FUTURE_VERSION,
			ERR_UNAVAILABLE
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.MIGRATION_FAILED,
			ERR_INVALID_DATA
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.IO_FAILED,
			ERR_FILE_CANT_READ
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			OK
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_FILE_CORRUPT
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_INVALID_DATA
		),
		_make_read_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_PARSE_ERROR
		),
	]

	for observed_result: GFStorageReadResult in rejected_results:
		_assert_stale_authorization(
			_storage.create_family_reset_authorization(
				file_name,
				observed_result
			)
		)

	_assert_stale_authorization(
		_storage.create_family_reset_authorization(file_name, null)
	)

	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var accepted: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	assert_eq(accepted.get_logical_path(), file_name)
	assert_eq(
		accepted.get_reason(),
		GFStorageFamilyResetAuthorization.REASON_CORRUPT
	)
	var duplicated_result: GFStorageReadResult = observed_result.duplicate_result()
	var duplicate_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, duplicated_result)
	)
	assert_ne(
		duplicate_authorization.get_authorization_id(),
		accepted.get_authorization_id()
	)

	_assert_stale_authorization(
		_storage.create_family_reset_authorization(
			"authorization/other.json",
			observed_result
		)
	)
	var foreign_storage: GFStorageUtility = GFStorageUtility.new()
	foreign_storage.save_dir_name = _save_dir_name
	foreign_storage.encrypt_key = 0
	_assert_stale_authorization(
		foreign_storage.create_family_reset_authorization(
			file_name,
			observed_result
		)
	)
	foreign_storage.dispose()

	_assert_stale_authorization(
		_storage.create_family_reset_authorization(
			file_name,
			GFStorageReadResult.from_dict(observed_result.to_dict())
		)
	)
	var reapplied_result: GFStorageReadResult = observed_result.duplicate_result()
	reapplied_result.apply_dict(reapplied_result.to_dict())
	_assert_stale_authorization(
		_storage.create_family_reset_authorization(file_name, reapplied_result)
	)
	var reconfigured_result: GFStorageReadResult = observed_result.duplicate_result()
	var _reconfigured: GFStorageReadResult = reconfigured_result.configure_failure(
		observed_result.error,
		observed_result.error_code,
		observed_result.metadata,
		observed_result.integrity_status,
		observed_result.document_schema_version,
		observed_result.failure_kind
	)
	_assert_stale_authorization(
		_storage.create_family_reset_authorization(file_name, reconfigured_result)
	)
	var rewritten_result: GFStorageReadResult = observed_result.duplicate_result()
	rewritten_result.error_code = (
		ERR_INVALID_DATA
		if rewritten_result.error_code != ERR_INVALID_DATA
		else ERR_PARSE_ERROR
	)
	_assert_stale_authorization(
		_storage.create_family_reset_authorization(file_name, rewritten_result)
	)


func test_reset_rejects_missing_or_stale_authorization_without_touching_family() -> void:
	var file_name: String = "authorization/required.json"
	assert_eq(_storage.save_data(file_name, { "generation": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var payload_path: String = GFVariantData.get_option_string(descriptor, "payload_path")
	assert_eq(_write_text(payload_path, "{"), OK)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var missing_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		null
	)
	_assert_reset_failure(
		missing_result,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)

	var stale_authorization: GFStorageFamilyResetAuthorization = (
		GFStorageFamilyResetAuthorization.new()
	)
	var stale_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		stale_authorization
	)
	_assert_reset_failure(
		stale_result,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_payload_only_corruption_is_retired_and_recreated() -> void:
	var file_name: String = "payload/corrupt.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	assert_true(authorization.is_claimed())
	assert_false(_storage.has_file(file_name), "recreate 后的新 family 不应保留旧 payload。")
	assert_eq(_storage.save_data(file_name, { "generation": 2 }), OK)
	var loaded: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "generation"), 2)


func test_corrupt_catalog_is_retired_without_affecting_unrelated_family() -> void:
	var target_file_name: String = "structural/catalog.json"
	var unrelated_file_name: String = "structural/unrelated.json"
	assert_eq(_storage.save_data(target_file_name, { "target": true }), OK)
	assert_eq(_storage.save_data(unrelated_file_name, { "preserved": 73 }), OK)
	var descriptor: Dictionary = _descriptor(target_file_name)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "catalog_path"),
			'{"schema":"gf.storage.family-catalog","schema_version":1}'
		),
		OK
	)
	var observed_result: GFStorageReadResult = _assert_corrupt_read(target_file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(target_file_name, observed_result)
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		target_file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
	)
	assert_false(_storage.has_file(target_file_name))
	var unrelated_result: GFStorageReadResult = _storage.load_data(unrelated_file_name)
	assert_true(unrelated_result.ok, "reset 必须保留其他 logical family。")
	assert_eq(GFVariantData.get_option_int(unrelated_result.payload, "preserved"), 73)


func test_corrupt_owner_is_retired_and_recreated() -> void:
	var file_name: String = "structural/owner.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "owner_path"),
			'{"schema":"gf.storage.family-owner","schema_version":1}'
		),
		OK
	)
	var observed_result: GFStorageReadResult = _assert_corrupt_read(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
	)
	assert_false(_storage.has_file(file_name))
	assert_eq(_storage.save_data(file_name, { "recovered": true }), OK)


func test_malformed_transaction_identity_is_retired_and_recreated() -> void:
	var file_name: String = "structural/transaction.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "transaction_path"),
			'{"schema":"gf.storage.transaction","transaction_id":7}'
		),
		OK
	)
	var observed_result: GFStorageReadResult = _assert_corrupt_read(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
	)
	assert_false(_storage.has_file(file_name))


func test_valid_multi_member_transactions_block_reset_without_writing() -> void:
	for committed: bool in [false, true]:
		var phase_name: String = "commit" if committed else "prepare"
		var file_name: String = "conflict/%s-target.json" % phase_name
		var companion_file_name: String = "conflict/%s-companion.json" % phase_name
		var observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		assert_eq(
			_storage.save_data(companion_file_name, { "preserved": phase_name }),
			OK
		)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var descriptor: Dictionary = _descriptor(file_name)
		var file_names: Array[String] = [file_name, companion_file_name]
		var had_final_by_file: Dictionary = {}
		had_final_by_file[file_name] = true
		had_final_by_file[companion_file_name] = true
		var marker: Dictionary = GFStorageUtility._make_transaction_marker(
			file_names,
			file_name,
			"reset-conflict:%s" % phase_name,
			committed,
			had_final_by_file
		)
		var marker_path: String = GFVariantData.get_option_string(
			descriptor,
			"transaction_commit_path" if committed else "transaction_path"
		)
		assert_eq(_write_json(marker_path, marker), OK)
		var before_digest: String = _snapshot_tree_digest(_storage_root_path)

		var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
			file_name,
			authorization
		)

		_assert_reset_failure(
			reset_result,
			GFStorageFamilyResetResult.FailureKind.CONFLICT,
			GFStorageFamilyResetResult.Phase.PREFLIGHT
		)
		assert_eq(reset_result.get_error_code(), ERR_BUSY)
		assert_eq(
			reset_result.get_source_kind(),
			GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
		)
		assert_eq(
			reset_result.get_failed_member(),
			GFStorageFamilyResetResult.FamilyMember.MUTABLE_EVIDENCE
		)
		assert_eq(reset_result.get_retired_member_count(), 0)
		assert_eq(reset_result.get_recreated_member_count(), 0)
		assert_true(authorization.is_claimed())
		assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_pending_reset_intent_is_promoted_and_fully_converged() -> void:
	var file_name: String = "recovery/pending-intent.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var pending_path: String = intent_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(
		_write_json(
			pending_path,
			_make_reset_intent_fixture(
				descriptor,
				reset_id,
				GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
			)
		),
		OK
	)
	assert_false(FileAccess.file_exists(intent_path))
	assert_true(FileAccess.file_exists(pending_path))

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	_assert_reset_residue_absent(descriptor, reset_id, pending_path)


func test_malformed_pending_reset_intents_are_discarded_without_touching_family() -> void:
	var malformed_contents: Array[String] = [
		"",
		"{",
		"x".repeat(_OVERSIZED_RESET_INTENT_BYTES),
	]
	for scenario_index: int in range(malformed_contents.size()):
		if scenario_index > 0:
			_recreate_storage_fixture_root()
		var file_name: String = "recovery/malformed-pending-%d.json" % scenario_index
		var _observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		var descriptor: Dictionary = _descriptor(file_name)
		var family_path: String = GFVariantData.get_option_string(
			descriptor,
			"family_path"
		)
		var catalog_path: String = GFVariantData.get_option_string(
			descriptor,
			"catalog_path"
		)
		var family_digest: String = _snapshot_tree_digest(family_path)
		var catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
			catalog_path
		)
		var pending_path: String = (
			_reset_intent_path(descriptor, GFUuid.generate_v4())
			+ ".pending-"
			+ GFUuid.generate_v4()
		)
		assert_eq(
			_write_text(pending_path, malformed_contents[scenario_index]),
			OK
		)

		_replace_storage(_make_integrity_storage())

		_assert_absolute_leaf_absent(pending_path)
		assert_eq(_snapshot_tree_digest(family_path), family_digest)
		assert_eq(FileAccess.get_file_as_bytes(catalog_path), catalog_bytes)
		var reobserved_result: GFStorageReadResult = _assert_corrupt_read(file_name)
		_assert_expected_integrity_warning(descriptor)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, reobserved_result)
		)
		assert_true(authorization.is_available())


func test_malformed_exact_reset_intent_fails_closed_without_writing() -> void:
	var file_name: String = "recovery/malformed-exact.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var intent_path: String = _reset_intent_path(
		descriptor,
		GFUuid.generate_v4()
	)
	assert_eq(_write_text(intent_path, ""), OK)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.CONFLICT,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.UNKNOWN
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
	)
	assert_true(authorization.is_claimed())
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_wrong_shape_pending_reset_intent_fails_closed_without_writing() -> void:
	for pending_is_directory: bool in [false, true]:
		if pending_is_directory:
			_recreate_storage_fixture_root()
		var file_name: String = (
			"recovery/wrong-shape-pending-%s.json"
			% ("directory" if pending_is_directory else "file")
		)
		var observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var descriptor: Dictionary = _descriptor(file_name)
		var pending_path: String = (
			_reset_intent_path(descriptor, GFUuid.generate_v4())
			+ ".pending-not-a-uuid"
		)
		var fixture_error: Error = (
			DirAccess.make_dir_recursive_absolute(pending_path)
			if pending_is_directory
			else _write_text(pending_path, "{}")
		)
		assert_eq(fixture_error, OK)
		var before_digest: String = _snapshot_tree_digest(_storage_root_path)

		var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
			file_name,
			authorization
		)

		_assert_reset_failure(
			reset_result,
			GFStorageFamilyResetResult.FailureKind.CONFLICT,
			GFStorageFamilyResetResult.Phase.PREFLIGHT
		)
		assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
		assert_eq(
			reset_result.get_source_kind(),
			GFStorageFamilyResetResult.SourceKind.UNKNOWN
		)
		assert_eq(reset_result.get_retired_member_count(), 0)
		assert_eq(reset_result.get_recreated_member_count(), 0)
		assert_eq(
			reset_result.get_failed_member(),
			GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
		)
		assert_true(authorization.is_claimed())
		assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_owner_only_recreate_state_resumes_without_losing_retired_evidence() -> void:
	var file_name: String = "recovery/owner-only.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	assert_eq(
		_write_json(
			intent_path,
			_make_reset_intent_fixture(
				descriptor,
				reset_id,
				GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
			)
		),
		OK
	)
	var retired_family_path: String = _retired_family_path(descriptor, reset_id)
	var retired_catalog_path: String = _retired_catalog_path(descriptor, reset_id)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "family_path"),
			retired_family_path
		),
		OK
	)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "catalog_path"),
			retired_catalog_path
		),
		OK
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(
			GFVariantData.get_option_string(descriptor, "family_path")
		),
		OK
	)
	assert_eq(
		_write_json(
			GFVariantData.get_option_string(descriptor, "owner_path"),
			_make_family_owner_fixture(descriptor)
		),
		OK
	)
	assert_false(
		FileAccess.file_exists(
			GFVariantData.get_option_string(descriptor, "catalog_path")
		)
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	assert_false(_storage.has_file(file_name))
	_assert_reset_residue_absent(descriptor, reset_id)


func test_owner_only_recreate_discards_malformed_catalog_pending_and_resumes() -> void:
	var file_name: String = "recovery/owner-only-catalog-pending.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	assert_eq(
		_write_json(
			_reset_intent_path(descriptor, reset_id),
			_make_reset_intent_fixture(
				descriptor,
				reset_id,
				GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY,
				2
			)
		),
		OK
	)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "family_path"),
			_retired_family_path(descriptor, reset_id)
		),
		OK
	)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "catalog_path"),
			_retired_catalog_path(descriptor, reset_id)
		),
		OK
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(
			GFVariantData.get_option_string(descriptor, "family_path")
		),
		OK
	)
	assert_eq(
		_write_json(
			GFVariantData.get_option_string(descriptor, "owner_path"),
			_make_family_owner_fixture(descriptor)
		),
		OK
	)
	var catalog_pending_path: String = (
		GFVariantData.get_option_string(descriptor, "catalog_path")
		+ ".pending-"
		+ GFUuid.generate_v4()
	)
	assert_eq(_write_text(catalog_pending_path, ""), OK)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	_assert_absolute_leaf_absent(catalog_pending_path)
	_assert_reset_residue_absent(descriptor, reset_id)
	assert_false(_storage.has_file(file_name))


func test_sync_write_converges_completed_reset_with_only_intent_remaining() -> void:
	var file_name: String = "recovery/intent-before-write.json"
	var _observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(descriptor, "payload_path")
		),
		OK
	)
	var reset_id: String = GFUuid.generate_v4()
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	assert_eq(
		_write_json(
			intent_path,
			_make_reset_intent_fixture(
				descriptor,
				reset_id,
				GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
			)
		),
		OK
	)
	assert_true(FileAccess.file_exists(intent_path))
	_replace_storage(GFStorageUtility.new())
	_assert_reset_residue_absent(descriptor, reset_id)
	assert_true(
		DirAccess.dir_exists_absolute(
			GFVariantData.get_option_string(descriptor, "family_path")
		)
	)
	assert_true(
		FileAccess.file_exists(
			GFVariantData.get_option_string(descriptor, "owner_path")
		)
	)
	assert_true(
		FileAccess.file_exists(
			GFVariantData.get_option_string(descriptor, "catalog_path")
		)
	)
	_assert_absolute_leaf_absent(
		GFVariantData.get_option_string(descriptor, "transaction_path")
	)
	_assert_absolute_leaf_absent(
		GFVariantData.get_option_string(descriptor, "transaction_commit_path")
	)

	assert_eq(_storage.save_data(file_name, { "generation": 2 }), OK)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "generation"), 2)
	_assert_reset_residue_absent(descriptor, reset_id)


func test_cleanup_resume_preserves_initial_retired_count() -> void:
	for retired_catalog_remains: bool in [true, false]:
		var scenario_name: String = (
			"catalog-remains" if retired_catalog_remains else "intent-only"
		)
		var file_name: String = "recovery/cleanup-%s.json" % scenario_name
		var observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var descriptor: Dictionary = _descriptor(file_name)
		var reset_id: String = GFUuid.generate_v4()
		assert_eq(
			_write_json(
				_reset_intent_path(descriptor, reset_id),
				_make_reset_intent_fixture(
					descriptor,
					reset_id,
					GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY,
					2
				)
			),
			OK
		)
		var retired_family_path: String = _retired_family_path(
			descriptor,
			reset_id
		)
		var retired_catalog_path: String = _retired_catalog_path(
			descriptor,
			reset_id
		)
		assert_eq(
			DirAccess.rename_absolute(
				GFVariantData.get_option_string(descriptor, "family_path"),
				retired_family_path
			),
			OK
		)
		assert_eq(
			DirAccess.rename_absolute(
				GFVariantData.get_option_string(descriptor, "catalog_path"),
				retired_catalog_path
			),
			OK
		)
		var family_store: GFStorageFamilyStore = (
			_GF_STORAGE_FAMILY_STORE_SCRIPT.new()
		)
		assert_true(family_store.configure_for_framework(_storage_root_path))
		assert_eq(family_store.claim_family_for_framework(descriptor), OK)
		assert_eq(_remove_owned_test_tree(retired_family_path), OK)
		if not retired_catalog_remains:
			assert_eq(DirAccess.remove_absolute(retired_catalog_path), OK)

		var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
			file_name,
			authorization
		)

		_assert_successful_reset(
			reset_result,
			GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
		)
		assert_eq(reset_result.get_retired_member_count(), 2)
		_assert_reset_residue_absent(descriptor, reset_id)


func test_missing_family_race_returns_not_found_without_writing() -> void:
	var file_name: String = "preflight/missing-race.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		_remove_owned_test_tree(
			GFVariantData.get_option_string(descriptor, "family_path")
		),
		OK
	)
	assert_eq(
		DirAccess.remove_absolute(
			GFVariantData.get_option_string(descriptor, "catalog_path")
		),
		OK
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.NOT_FOUND,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.MISSING
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(reset_result.get_remaining_evidence_count(), 0)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_future_layout_fails_closed_without_writing() -> void:
	var file_name: String = "preflight/future-layout.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var future_root: String = _storage_root_path.path_join(".gf-storage/v2")
	assert_eq(DirAccess.make_dir_recursive_absolute(future_root), OK)
	assert_eq(
		_write_text(
			future_root.path_join("layout.json"),
			'{"schema":"gf.storage.layout","schema_version":2}'
		),
		OK
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.UNSUPPORTED_LAYOUT,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_storage_ancestry_links_fail_closed_without_crossing_boundary() -> void:
	var scenarios: Array[StringName] = [
		&"private_root",
		&"version_root",
		&"family_shard",
		&"catalog_shard",
	]
	for scenario_index: int in range(scenarios.size()):
		if scenario_index > 0:
			_recreate_storage_fixture_root()
		var scenario: StringName = scenarios[scenario_index]
		var file_name: String = "boundary/%s.json" % scenario
		var observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var descriptor: Dictionary = _descriptor(file_name)
		var link_path: String = ""
		match scenario:
			&"private_root":
				link_path = _storage_root_path.path_join(".gf-storage")
			&"version_root":
				link_path = _storage_root_path.path_join(".gf-storage/v1")
			&"family_shard":
				link_path = GFVariantData.get_option_string(
					descriptor,
					"family_path"
				).get_base_dir()
			&"catalog_shard":
				link_path = GFVariantData.get_option_string(
					descriptor,
					"catalog_path"
				).get_base_dir()
		assert_false(link_path.is_empty())
		if link_path.is_empty():
			continue
		assert_eq(_remove_owned_test_tree(link_path), OK)
		var sentinel_root: String = _make_external_fixture_root(String(scenario))
		assert_eq(
			_write_text(sentinel_root.path_join("sentinel.txt"), "preserved"),
			OK
		)
		var sentinel_digest: String = _snapshot_tree_digest(sentinel_root)
		var link_error: Error = _GF_TEST_DIRECTORY_LINK_FIXTURE.create(
			ProjectSettings.globalize_path(sentinel_root),
			ProjectSettings.globalize_path(link_path)
		)
		assert_eq(
			link_error,
			OK,
			"受支持平台必须建立 symlink 或 Windows directory junction 夹具。"
		)
		if link_error != OK:
			continue

		var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
			file_name,
			authorization
		)

		_assert_reset_failure(
			reset_result,
			GFStorageFamilyResetResult.FailureKind.CONFLICT,
			GFStorageFamilyResetResult.Phase.PREFLIGHT
		)
		assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
		assert_eq(
			reset_result.get_source_kind(),
			GFStorageFamilyResetResult.SourceKind.UNKNOWN
		)
		assert_eq(reset_result.get_retired_member_count(), 0)
		assert_eq(reset_result.get_recreated_member_count(), 0)
		assert_eq(
			reset_result.get_failed_member(),
			GFStorageFamilyResetResult.FamilyMember.LAYOUT
		)
		assert_true(authorization.is_claimed())
		assert_eq(_snapshot_tree_digest(sentinel_root), sentinel_digest)

		_replace_storage(GFStorageUtility.new())
		assert_push_error(
			"[GFStorageUtility] 无法初始化私有 Storage layout，错误码：16"
		)
		var save_error: Error = _storage.save_data(
			"boundary/readiness-probe.json",
			{ "value": 1 }
		)
		assert_push_error(
			"[GFStorageUtility] 无法初始化私有 Storage layout，错误码：16"
		)
		assert_eq(save_error, ERR_FILE_CORRUPT)
		assert_eq(_snapshot_tree_digest(sentinel_root), sentinel_digest)
		assert_eq(DirAccess.remove_absolute(link_path), OK)


func test_exact_family_directory_link_is_structural_and_reset_never_crosses_boundary() -> void:
	var file_name: String = "boundary/exact-family-link.json"
	var companion_file_name: String = "boundary/exact-family-link-companion.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	assert_eq(
		_storage.save_data(companion_file_name, { "preserved": true }),
		OK
	)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var family_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	)
	assert_eq(_remove_owned_test_tree(family_path), OK)
	var sentinel_root: String = _make_external_fixture_root("exact-family-link")
	assert_eq(
		_write_text(sentinel_root.path_join("sentinel.txt"), "preserved"),
		OK
	)
	var file_names: Array[String] = [file_name, companion_file_name]
	var had_final_by_file: Dictionary = {}
	had_final_by_file[file_name] = true
	had_final_by_file[companion_file_name] = true
	var external_marker: Dictionary = GFStorageUtility._make_transaction_marker(
		file_names,
		file_name,
		"external-junction-prepare",
		false,
		had_final_by_file
	)
	var external_marker_path: String = sentinel_root.path_join(
		GFVariantData.get_option_string(
			descriptor,
			"transaction_path"
		).get_file()
	)
	assert_eq(_write_json(external_marker_path, external_marker), OK)
	var sentinel_digest: String = _snapshot_tree_digest(sentinel_root)
	var link_error: Error = _GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(sentinel_root),
		ProjectSettings.globalize_path(family_path)
	)
	assert_eq(link_error, OK)
	if link_error != OK:
		return
	assert_true(_absolute_path_is_link(family_path))

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
	)
	assert_eq(_snapshot_tree_digest(sentinel_root), sentinel_digest)
	assert_false(_absolute_path_is_link(family_path))
	_assert_valid_family_claim(descriptor)
	assert_false(_storage.has_file(file_name))


func test_allowed_payload_file_link_is_structural_and_reset_never_crosses_boundary() -> void:
	var file_name: String = "boundary/payload-file-link.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var payload_path: String = GFVariantData.get_option_string(
		descriptor,
		"payload_path"
	)
	assert_eq(DirAccess.remove_absolute(payload_path), OK)
	var sentinel_root: String = _make_external_fixture_root("payload-file-link")
	var sentinel_path: String = sentinel_root.path_join("sentinel.json")
	assert_eq(_write_text(sentinel_path, "preserved"), OK)
	var sentinel_digest: String = _snapshot_tree_digest(sentinel_root)
	var link_error: Error = _create_file_link(sentinel_path, payload_path)
	if link_error != OK and OS.get_name() == "Windows":
		assert_false(_absolute_path_is_link(payload_path))
		return
	assert_eq(link_error, OK, "POSIX 必须能够建立 file symlink 夹具。")
	if link_error != OK:
		return
	assert_true(_absolute_path_is_link(payload_path))

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
	)
	assert_eq(_snapshot_tree_digest(sentinel_root), sentinel_digest)
	assert_false(_absolute_path_is_link(payload_path))
	_assert_valid_family_claim(descriptor)


func test_mismatched_layout_publish_pending_fails_before_reset_mutation() -> void:
	var file_name: String = "preflight/mismatched-layout-pending.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var pending_path: String = (
		_storage_root_path.path_join(".gf-storage/v1/layout.json.pending-")
		+ GFUuid.generate_v4()
	)
	assert_eq(
		_write_json(
			pending_path,
			{
				"schema": "gf.storage.layout",
				"schema_version": 1,
				"unexpected": true,
			}
		),
		OK
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.CONFLICT,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.UNKNOWN
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.LAYOUT
	)
	assert_true(authorization.is_claimed())
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_existing_intent_rejects_conflicting_fresh_claim_and_preserves_evidence() -> void:
	var file_name: String = "recovery/conflicting-fresh-claim.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		descriptor,
		reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	assert_true(family_store.configure_for_framework(_storage_root_path))
	assert_eq(family_store.claim_family_for_framework(descriptor), OK)
	var family_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	)
	var extra_error: Error = OK
	for entry_index: int in range(1):
		extra_error = _write_text(
			family_path.path_join("unexpected-%02d.txt" % entry_index),
			"conflict"
		)
		if extra_error != OK:
			break
	assert_eq(extra_error, OK)
	var claim_state: Dictionary = family_store.inspect_reset_claim_for_framework(
		descriptor
	)
	assert_eq(GFVariantData.get_option_int(claim_state, "error"), OK)
	assert_eq(
		GFVariantData.get_option_string_name(claim_state, "state"),
		&"conflict"
	)
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var retired_family_path: String = GFVariantData.get_option_string(
		retired_paths,
		"family_path"
	)
	var retired_catalog_path: String = GFVariantData.get_option_string(
		retired_paths,
		"catalog_path"
	)
	var intent_bytes: PackedByteArray = FileAccess.get_file_as_bytes(intent_path)
	var retired_family_digest: String = _snapshot_tree_digest(retired_family_path)
	var retired_catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		retired_catalog_path
	)
	var exact_claim_digest: String = _snapshot_tree_digest(family_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.CONFLICT,
		GFStorageFamilyResetResult.Phase.RECREATE
	)
	assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	assert_eq(reset_result.get_retired_member_count(), 2)
	assert_eq(reset_result.get_recreated_member_count(), 3)
	assert_gt(reset_result.get_remaining_evidence_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)
	assert_eq(FileAccess.get_file_as_bytes(intent_path), intent_bytes)
	assert_eq(_snapshot_tree_digest(retired_family_path), retired_family_digest)
	assert_eq(
		FileAccess.get_file_as_bytes(retired_catalog_path),
		retired_catalog_bytes
	)
	assert_eq(_snapshot_tree_digest(family_path), exact_claim_digest)


func test_existing_intent_caps_overfull_exact_claim_without_mutating_evidence() -> void:
	var file_name: String = "capacity/overfull-exact-claim.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		descriptor,
		reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	assert_true(family_store.configure_for_framework(_storage_root_path))
	assert_eq(family_store.claim_family_for_framework(descriptor), OK)
	var family_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	)
	var extra_error: Error = OK
	for entry_index: int in range(16):
		extra_error = _write_text(
			family_path.path_join("bounded-extra-%02d.txt" % entry_index),
			"capacity"
		)
		if extra_error != OK:
			break
	assert_eq(extra_error, OK)
	var claim_state: Dictionary = family_store.inspect_reset_claim_for_framework(
		descriptor
	)
	assert_eq(
		GFVariantData.get_option_int(claim_state, "error"),
		ERR_OUT_OF_MEMORY
	)
	assert_eq(
		GFVariantData.get_option_string_name(claim_state, "state"),
		&"conflict"
	)
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var retired_family_path: String = GFVariantData.get_option_string(
		retired_paths,
		"family_path"
	)
	var retired_catalog_path: String = GFVariantData.get_option_string(
		retired_paths,
		"catalog_path"
	)
	var intent_bytes: PackedByteArray = FileAccess.get_file_as_bytes(intent_path)
	var retired_family_digest: String = _snapshot_tree_digest(retired_family_path)
	var retired_catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		retired_catalog_path
	)
	var exact_claim_digest: String = _snapshot_tree_digest(family_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.RECREATE
	)
	assert_eq(reset_result.get_error_code(), ERR_OUT_OF_MEMORY)
	assert_eq(reset_result.get_retired_member_count(), 2)
	assert_eq(reset_result.get_recreated_member_count(), 3)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)
	assert_eq(FileAccess.get_file_as_bytes(intent_path), intent_bytes)
	assert_eq(_snapshot_tree_digest(retired_family_path), retired_family_digest)
	assert_eq(
		FileAccess.get_file_as_bytes(retired_catalog_path),
		retired_catalog_bytes
	)
	assert_eq(_snapshot_tree_digest(family_path), exact_claim_digest)


func test_claim_staging_directory_link_fails_closed_and_preserves_evidence() -> void:
	var file_name: String = "boundary/claim-staging-link.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		descriptor,
		reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var external_root: String = _make_external_fixture_root("claim-staging-link")
	assert_eq(
		_write_json(
			external_root.path_join("owner.json"),
			_make_family_owner_fixture(descriptor)
		),
		OK
	)
	assert_eq(_write_text(external_root.path_join("sentinel.txt"), "preserved"), OK)
	var external_digest: String = _snapshot_tree_digest(external_root)
	var staging_path: String = (
		GFVariantData.get_option_string(descriptor, "family_path")
		+ ".claim-"
		+ GFUuid.generate_v4()
	)
	var link_error: Error = _GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(external_root),
		ProjectSettings.globalize_path(staging_path)
	)
	assert_eq(link_error, OK)
	if link_error != OK:
		return
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var retired_family_path: String = GFVariantData.get_option_string(
		retired_paths,
		"family_path"
	)
	var retired_catalog_path: String = GFVariantData.get_option_string(
		retired_paths,
		"catalog_path"
	)
	var intent_bytes: PackedByteArray = FileAccess.get_file_as_bytes(intent_path)
	var retired_family_digest: String = _snapshot_tree_digest(retired_family_path)
	var retired_catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		retired_catalog_path
	)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.CONFLICT,
		GFStorageFamilyResetResult.Phase.RECREATE
	)
	assert_eq(reset_result.get_error_code(), ERR_FILE_CORRUPT)
	assert_eq(reset_result.get_retired_member_count(), 2)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)
	assert_true(_absolute_path_is_link(staging_path))
	assert_eq(_snapshot_tree_digest(external_root), external_digest)
	assert_eq(FileAccess.get_file_as_bytes(intent_path), intent_bytes)
	assert_eq(_snapshot_tree_digest(retired_family_path), retired_family_digest)
	assert_eq(
		FileAccess.get_file_as_bytes(retired_catalog_path),
		retired_catalog_bytes
	)


func test_claim_staging_bound_ignores_ordinary_siblings_but_caps_target_candidates() -> void:
	var ordinary_file_name: String = "capacity/ordinary-claim-siblings.json"
	var ordinary_observed: GFStorageReadResult = _save_and_corrupt_payload(
		ordinary_file_name
	)
	var ordinary_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(ordinary_file_name, ordinary_observed)
	)
	var ordinary_descriptor: Dictionary = _descriptor(ordinary_file_name)
	var ordinary_reset_id: String = GFUuid.generate_v4()
	var _ordinary_retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		ordinary_descriptor,
		ordinary_reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var ordinary_parent: String = GFVariantData.get_option_string(
		ordinary_descriptor,
		"family_path"
	).get_base_dir()
	var creation_error: Error = OK
	for entry_index: int in range(96):
		creation_error = DirAccess.make_dir_recursive_absolute(
			ordinary_parent.path_join("ordinary-sibling-%03d" % entry_index)
		)
		if creation_error != OK:
			break
	assert_eq(creation_error, OK)
	var ordinary_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		ordinary_file_name,
		ordinary_authorization
	)
	_assert_successful_reset(
		ordinary_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	_assert_reset_residue_absent(ordinary_descriptor, ordinary_reset_id)

	_recreate_storage_fixture_root()
	var bounded_file_name: String = "capacity/bounded-claim-candidates.json"
	var bounded_observed: GFStorageReadResult = _save_and_corrupt_payload(
		bounded_file_name
	)
	var bounded_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(bounded_file_name, bounded_observed)
	)
	var bounded_descriptor: Dictionary = _descriptor(bounded_file_name)
	var bounded_reset_id: String = GFUuid.generate_v4()
	var bounded_retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		bounded_descriptor,
		bounded_reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var family_path: String = GFVariantData.get_option_string(
		bounded_descriptor,
		"family_path"
	)
	creation_error = OK
	for entry_index: int in range(65):
		creation_error = DirAccess.make_dir_recursive_absolute(
			family_path + ".claim-" + GFUuid.generate_v4()
		)
		if creation_error != OK:
			break
	assert_eq(creation_error, OK)
	var intent_path: String = _reset_intent_path(
		bounded_descriptor,
		bounded_reset_id
	)
	var retired_family_path: String = GFVariantData.get_option_string(
		bounded_retired_paths,
		"family_path"
	)
	var retired_catalog_path: String = GFVariantData.get_option_string(
		bounded_retired_paths,
		"catalog_path"
	)
	var intent_bytes: PackedByteArray = FileAccess.get_file_as_bytes(intent_path)
	var retired_family_digest: String = _snapshot_tree_digest(retired_family_path)
	var retired_catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		retired_catalog_path
	)

	var bounded_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		bounded_file_name,
		bounded_authorization
	)
	_assert_reset_failure(
		bounded_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.RECREATE
	)
	assert_eq(bounded_result.get_error_code(), ERR_OUT_OF_MEMORY)
	assert_eq(bounded_result.get_retired_member_count(), 2)
	assert_eq(bounded_result.get_recreated_member_count(), 0)
	assert_eq(
		bounded_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)
	assert_eq(FileAccess.get_file_as_bytes(intent_path), intent_bytes)
	assert_eq(_snapshot_tree_digest(retired_family_path), retired_family_digest)
	assert_eq(
		FileAccess.get_file_as_bytes(retired_catalog_path),
		retired_catalog_bytes
	)


func test_exact_wrong_type_identity_leaves_are_retired_and_recreated() -> void:
	var scenarios: Array[StringName] = [
		&"family_file",
		&"catalog_directory",
	]
	for scenario_index: int in range(scenarios.size()):
		if scenario_index > 0:
			_recreate_storage_fixture_root()
		var scenario: StringName = scenarios[scenario_index]
		var file_name: String = "structural/wrong-type-%s.json" % scenario
		var observed_result: GFStorageReadResult = _save_and_corrupt_payload(
			file_name
		)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var descriptor: Dictionary = _descriptor(file_name)
		if scenario == &"family_file":
			var family_path: String = GFVariantData.get_option_string(
				descriptor,
				"family_path"
			)
			assert_eq(_remove_owned_test_tree(family_path), OK)
			assert_eq(_write_text(family_path, "wrong-type-family"), OK)
		else:
			var catalog_path: String = GFVariantData.get_option_string(
				descriptor,
				"catalog_path"
			)
			assert_eq(DirAccess.remove_absolute(catalog_path), OK)
			assert_eq(DirAccess.make_dir_recursive_absolute(catalog_path), OK)

		var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
			file_name,
			authorization
		)

		_assert_successful_reset(
			reset_result,
			GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
		)
		assert_true(authorization.is_claimed())
		_assert_valid_family_claim(descriptor)
		assert_false(_storage.has_file(file_name))
		assert_eq(_storage.save_data(file_name, { "recovered": scenario }), OK)


func test_reset_layout_inspection_caps_excess_invalid_entries_without_writing() -> void:
	var file_name: String = "capacity/invalid-layout-entries.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var family_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	)
	var version_root: String = _storage_root_path.path_join(".gf-storage/v1")
	var creation_error: Error = OK
	for entry_index: int in range(65):
		creation_error = DirAccess.make_dir_recursive_absolute(
			version_root.path_join("invalid-layout-entry-%02d" % entry_index)
		)
		if creation_error != OK:
			break
	assert_eq(creation_error, OK)
	var family_digest: String = _snapshot_tree_digest(family_path)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_error_code(), ERR_OUT_OF_MEMORY)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.UNKNOWN
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.LAYOUT
	)
	assert_true(authorization.is_claimed())
	assert_eq(_snapshot_tree_digest(family_path), family_digest)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)

	_replace_storage(GFStorageUtility.new())
	assert_push_error(
		"[GFStorageUtility] 无法初始化私有 Storage layout，错误码：6"
	)
	var save_error: Error = _storage.save_data(
		"capacity/invalid-layout-readiness-probe.json",
		{ "value": 1 }
	)
	assert_push_error(
		"[GFStorageUtility] 无法初始化私有 Storage layout，错误码：6"
	)
	assert_eq(save_error, ERR_OUT_OF_MEMORY)
	assert_eq(_snapshot_tree_digest(family_path), family_digest)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_target_pending_intent_candidates_are_bounded_before_reset_mutation() -> void:
	var file_name: String = "capacity/target-pending-intents.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var creation_error: Error = OK
	for _candidate_index: int in range(1025):
		var pending_path: String = (
			intent_path
			+ ".pending-"
			+ GFUuid.generate_v4()
		)
		creation_error = _write_text(pending_path, "{}")
		if creation_error != OK:
			break
	assert_eq(creation_error, OK)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_error_code(), ERR_OUT_OF_MEMORY)
	assert_eq(
		reset_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.UNKNOWN
	)
	assert_eq(reset_result.get_retired_member_count(), 0)
	assert_eq(reset_result.get_recreated_member_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
	)
	assert_true(authorization.is_claimed())
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)


func test_global_reset_discovery_ignores_more_than_1024_normal_family_entries() -> void:
	var family_parent: String = _storage_root_path.path_join(
		".gf-storage/v1/families/aa/bb"
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(family_parent), OK)
	var creation_error: Error = OK
	for entry_index: int in range(1025):
		creation_error = DirAccess.make_dir_recursive_absolute(
			family_parent.path_join("ordinary-family-%04d" % entry_index)
		)
		if creation_error != OK:
			break
	assert_eq(creation_error, OK)

	_replace_storage(GFStorageUtility.new())

	var directory: DirAccess = DirAccess.open(family_parent)
	assert_not_null(directory)
	if directory != null:
		assert_eq(directory.get_directories().size(), 1025)
	assert_eq(
		_storage.save_data("capacity/readiness-probe.json", { "value": 1 }),
		OK
	)


func test_authorization_mismatch_marks_stale_and_successful_claim_cannot_be_reused() -> void:
	var first_file_name: String = "authorization/first.json"
	var second_file_name: String = "authorization/second.json"
	var first_observed: GFStorageReadResult = _save_and_corrupt_payload(first_file_name)
	var second_observed: GFStorageReadResult = _save_and_corrupt_payload(second_file_name)
	var first_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(first_file_name, first_observed)
	)

	var mismatch_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		second_file_name,
		first_authorization
	)
	_assert_reset_failure(
		mismatch_result,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_true(first_authorization.is_stale(), "错配提交必须使旧决定永久失效。")

	var stale_replay: GFStorageFamilyResetResult = _storage.reset_file_family(
		first_file_name,
		first_authorization
	)
	_assert_reset_failure(
		stale_replay,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)

	var second_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(second_file_name, second_observed)
	)
	var successful_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		second_file_name,
		second_authorization
	)
	assert_true(successful_result.is_successful())
	assert_true(second_authorization.is_claimed())

	var claimed_replay: GFStorageFamilyResetResult = _storage.reset_file_family(
		second_file_name,
		second_authorization
	)
	_assert_reset_failure(
		claimed_replay,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)


func test_unrelated_reset_conflict_readiness_failure_stays_unbound_and_unqueued() -> void:
	var healthy_file_name: String = "provenance/healthy-target.json"
	assert_eq(_storage.save_data(healthy_file_name, { "generation": 1 }), OK)
	var conflict_file_name: String = "provenance/unrelated-conflict.json"
	var _conflict_observed: GFStorageReadResult = _save_and_corrupt_payload(
		conflict_file_name
	)
	var conflict_descriptor: Dictionary = _descriptor(conflict_file_name)
	var reset_id: String = GFUuid.generate_v4()
	var _retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		conflict_descriptor,
		reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	assert_true(family_store.configure_for_framework(_storage_root_path))
	assert_eq(
		family_store.claim_family_for_framework(conflict_descriptor),
		OK
	)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(
				conflict_descriptor,
				"family_path"
			).path_join("unexpected.txt"),
			"conflict"
		),
		OK
	)
	var cold_storage: ColdCooperativeResetStorageUtility = (
		ColdCooperativeResetStorageUtility.new()
	)
	_replace_storage_without_init(cold_storage)
	cold_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var sync_result: GFStorageReadResult = _storage.load_data(healthy_file_name)
	assert_false(sync_result.ok)
	assert_eq(sync_result.error_code, ERR_FILE_CORRUPT)
	assert_eq(sync_result.failure_kind, GFStorageReadResult.FailureKind.IO_FAILED)
	_assert_read_result_origin(sync_result, healthy_file_name, false)
	_assert_stale_authorization(
		_storage.create_family_reset_authorization(
			healthy_file_name,
			sync_result
		)
	)

	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		healthy_file_name,
		{ "generation": 2 }
	)
	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		healthy_file_name
	)
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"generation": 3,
	})
	var payload_operation: GFStorageAsyncOperation = (
		_storage.save_payload_request_async(healthy_file_name, transfer)
	)
	var failed_operations: Array[GFStorageAsyncOperation] = [
		save_operation,
		load_operation,
		payload_operation,
	]
	for operation: GFStorageAsyncOperation in failed_operations:
		assert_not_null(operation)
		if operation != null:
			assert_true(operation.is_completed())
			assert_eq(operation.get_result().get_error_code(), ERR_FILE_CORRUPT)
	assert_eq(
		save_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.IO_FAILED
	)
	assert_eq(
		payload_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.IO_FAILED
	)
	var async_read_result: GFStorageReadResult = (
		load_operation.get_result().get_read_result()
	)
	assert_not_null(async_read_result)
	if async_read_result != null:
		assert_false(async_read_result.ok)
		assert_eq(async_read_result.error_code, ERR_FILE_CORRUPT)
		assert_eq(
			async_read_result.failure_kind,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
		_assert_read_result_origin(
			async_read_result,
			healthy_file_name,
			false
		)
		_assert_stale_authorization(
			_storage.create_family_reset_authorization(
				healthy_file_name,
				async_read_result
			)
		)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.READY)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_null(payload_operation.get_payload_transfer())
	assert_true(_storage._async_queue.is_empty())
	assert_true(_storage._async_tasks.is_empty())
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	assert_true(transfer.release())
	assert_eq(cold_storage.thread_start_call_count, 0)


func test_async_target_identity_failures_preserve_corrupt_provenance_for_reset() -> void:
	var identity_keys: Array[String] = [
		"catalog_path",
		"owner_path",
		"transaction_path",
	]
	for scenario_index: int in range(identity_keys.size()):
		if scenario_index > 0:
			_recreate_storage_fixture_root()
		var cooperative_storage: CooperativeResetStorageUtility = (
			CooperativeResetStorageUtility.new()
		)
		_replace_storage(cooperative_storage)
		cooperative_storage.async_execution_mode = (
			GFStorageUtility.AsyncExecutionMode.COOPERATIVE
		)
		var identity_key: String = identity_keys[scenario_index]
		var file_name: String = "provenance/target-%s.json" % identity_key
		assert_eq(_storage.save_data(file_name, { "generation": 1 }), OK)
		assert_true(_storage._storage_reconciled)
		var descriptor: Dictionary = _descriptor(file_name)
		assert_eq(
			_write_text(
				GFVariantData.get_option_string(descriptor, identity_key),
				"{"
			),
			OK
		)

		var operation: GFStorageAsyncOperation = (
			_storage.load_data_request_async(file_name)
		)
		assert_not_null(operation)
		if operation == null:
			continue
		var operations: Array[GFStorageAsyncOperation] = [operation]
		assert_true(await _pump_until_operations_complete(operations))
		assert_false(operation.get_result().is_successful())
		assert_eq(operation.get_result().get_error_code(), ERR_FILE_CORRUPT)
		var observed_result: GFStorageReadResult = (
			operation.get_result().get_read_result()
		)
		assert_not_null(observed_result)
		if observed_result == null:
			continue
		assert_false(observed_result.ok)
		assert_eq(observed_result.error_code, ERR_FILE_CORRUPT)
		assert_eq(
			observed_result.failure_kind,
			GFStorageReadResult.FailureKind.CORRUPT
		)
		_assert_read_result_origin(observed_result, file_name, true)
		var authorization: GFStorageFamilyResetAuthorization = (
			_create_available_authorization(file_name, observed_result)
		)
		var reset_result: GFStorageFamilyResetResult = (
			_storage.reset_file_family(file_name, authorization)
		)
		_assert_successful_reset(
			reset_result,
			GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
		)
		_assert_valid_family_claim(descriptor)
		assert_false(_storage.has_file(file_name))
		assert_eq(cooperative_storage.thread_start_call_count, 0)
		assert_push_error(
			"[GFStorageUtility] 异步读取失败：%s，原因：Transaction recovery failed，错误码：%s"
			% [file_name, ERR_FILE_CORRUPT]
		)


func test_sync_reset_rechecks_admission_after_same_file_async_completion() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	)
	var file_name: String = "lifecycle/quiesce-during-reset-wait.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		file_name
	)
	assert_not_null(operation)
	if operation == null:
		return
	var connect_error: Error = operation.completed.connect(
		Callable(self, &"_begin_quiesce_from_async_completion"),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.UNAVAILABLE,
		GFStorageFamilyResetResult.Phase.PREFLIGHT
	)
	assert_eq(reset_result.get_error_code(), ERR_UNAVAILABLE)
	assert_true(authorization.is_available())
	assert_false(authorization.is_claimed())
	assert_true(operation.is_completed())
	assert_not_null(_completion_listener_quiesce)
	if _completion_listener_quiesce != null:
		assert_true(_completion_listener_quiesce.is_completed())
		assert_true(_completion_listener_quiesce.is_successful())
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	assert_eq(cooperative_storage.thread_start_call_count, 0)


func test_async_reset_save_delete_share_same_file_fifo() -> void:
	var gated_storage: GatedThreadedResetStorageUtility = (
		GatedThreadedResetStorageUtility.new()
	)
	_replace_storage(gated_storage)
	gated_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.THREADED
	)
	gated_storage.max_async_thread_count = 4
	var file_name: String = "async/fifo.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var completion_order: Array[StringName] = []

	var reset_operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization)
	)
	assert_not_null(reset_operation)
	if reset_operation == null:
		gated_storage.release_all_for_test()
		return
	assert_true(await _wait_for_gated_reset_worker_started(gated_storage))
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "generation": 2 }
	)
	var delete_operation: GFStorageAsyncOperation = (
		_storage.delete_file_request_async(file_name)
	)
	assert_not_null(save_operation)
	assert_not_null(delete_operation)
	if save_operation == null or delete_operation == null:
		gated_storage.release_all_for_test()
		return
	assert_eq(reset_operation.get_operation(), GFStorageAsyncOperation.OPERATION_RESET)
	assert_eq(save_operation.get_operation(), GFStorageAsyncOperation.OPERATION_SAVE)
	assert_eq(delete_operation.get_operation(), GFStorageAsyncOperation.OPERATION_DELETE)
	_connect_completion_label(reset_operation, completion_order, &"reset")
	_connect_completion_label(save_operation, completion_order, &"save")
	_connect_completion_label(delete_operation, completion_order, &"delete")
	var operations: Array[GFStorageAsyncOperation] = [
		reset_operation,
		save_operation,
		delete_operation,
	]
	assert_eq(gated_storage.thread_start_call_count, 1)
	assert_eq(_storage._async_tasks.size(), 1)
	assert_eq(_storage._async_queue.size(), 2)
	if _storage._async_tasks.size() == 1 and _storage._async_queue.size() == 2:
		var reset_task: Dictionary = GFVariantData.as_dictionary(
			_storage._async_tasks.front()
		)
		var save_task: Dictionary = GFVariantData.as_dictionary(_storage._async_queue[0])
		var delete_task: Dictionary = GFVariantData.as_dictionary(_storage._async_queue[1])
		var reset_file_key: String = GFVariantData.get_option_string(reset_task, "file_key")
		assert_false(reset_file_key.is_empty())
		assert_eq(GFVariantData.get_option_string(save_task, "file_key"), reset_file_key)
		assert_eq(GFVariantData.get_option_string(delete_task, "file_key"), reset_file_key)
		assert_eq(GFVariantData.get_option_string_name(reset_task, "type"), &"reset")
		assert_eq(GFVariantData.get_option_string_name(save_task, "type"), &"save")
		assert_eq(GFVariantData.get_option_string_name(delete_task, "type"), &"delete")
		assert_true(_storage._async_file_locks.has(reset_file_key))
		assert_eq(
			GFVariantData.to_exact_int(_storage._async_file_locks.get(reset_file_key), 0),
			GFVariantData.get_option_int(reset_task, "record_id")
		)
	gated_storage.release_all_for_test()

	assert_true(await _pump_until_operations_complete(operations))

	assert_eq(completion_order, [&"reset", &"save", &"delete"])
	var async_reset_result: GFStorageFamilyResetResult = (
		reset_operation.get_result().get_reset_result()
	)
	assert_not_null(async_reset_result)
	assert_true(async_reset_result.is_successful())
	assert_true(save_operation.get_result().is_successful())
	assert_true(delete_operation.get_result().is_successful())
	assert_false(_storage.has_file(file_name), "FIFO 中最后的 delete 应决定最终状态。")
	assert_eq(gated_storage.thread_start_call_count, 3)


func test_cold_async_save_then_load_resumes_same_family_intent_before_io() -> void:
	var file_name: String = "async/cold-pending-intent.json"
	var _observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var descriptor: Dictionary = _descriptor(file_name)
	var reset_id: String = GFUuid.generate_v4()
	var _retired_paths: Dictionary = _install_reset_intent_and_retire_exact(
		descriptor,
		reset_id,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var cold_storage: ColdCooperativeResetStorageUtility = (
		ColdCooperativeResetStorageUtility.new()
	)
	_replace_storage_without_init(cold_storage)
	cold_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	var completion_order: Array[StringName] = []
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "generation": 2 }
	)
	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		file_name
	)
	assert_not_null(save_operation)
	assert_not_null(load_operation)
	if save_operation == null or load_operation == null:
		return
	_connect_completion_label(save_operation, completion_order, &"save")
	_connect_completion_label(load_operation, completion_order, &"load")
	var operations: Array[GFStorageAsyncOperation] = [
		save_operation,
		load_operation,
	]

	assert_true(await _pump_until_operations_complete(operations))

	assert_eq(completion_order, [&"save", &"load"])
	assert_true(save_operation.get_result().is_successful())
	assert_true(load_operation.get_result().is_successful())
	var loaded: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_not_null(loaded)
	if loaded != null:
		assert_true(loaded.ok)
		assert_eq(GFVariantData.get_option_int(loaded.payload, "generation"), 2)
	_assert_reset_residue_absent(descriptor, reset_id)
	_assert_valid_family_claim(descriptor)
	assert_eq(cold_storage.thread_start_call_count, 0)


func test_async_save_and_load_reject_linked_ancestor_without_crossing_boundary() -> void:
	var file_name: String = "async/linked-ancestor.json"
	assert_eq(_storage.save_data(file_name, { "generation": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var linked_shard_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	).get_base_dir()
	assert_eq(_remove_owned_test_tree(linked_shard_path), OK)
	var external_root: String = _make_external_fixture_root("async-linked-ancestor")
	assert_eq(_write_text(external_root.path_join("sentinel.txt"), "preserved"), OK)
	var external_digest: String = _snapshot_tree_digest(external_root)
	var link_error: Error = _GF_TEST_DIRECTORY_LINK_FIXTURE.create(
		ProjectSettings.globalize_path(external_root),
		ProjectSettings.globalize_path(linked_shard_path)
	)
	assert_eq(link_error, OK)
	if link_error != OK:
		return
	var cold_storage: ColdCooperativeResetStorageUtility = (
		ColdCooperativeResetStorageUtility.new()
	)
	_replace_storage_without_init(cold_storage)
	cold_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		file_name,
		{ "generation": 2 }
	)
	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		file_name
	)
	assert_not_null(save_operation)
	assert_not_null(load_operation)
	if save_operation == null or load_operation == null:
		return
	var operations: Array[GFStorageAsyncOperation] = [
		save_operation,
		load_operation,
	]

	assert_true(await _pump_until_operations_complete(operations))

	assert_false(save_operation.get_result().is_successful())
	assert_eq(save_operation.get_result().get_error_code(), ERR_FILE_CORRUPT)
	assert_false(load_operation.get_result().is_successful())
	assert_eq(load_operation.get_result().get_error_code(), ERR_FILE_CORRUPT)
	var read_result: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_not_null(read_result)
	if read_result != null:
		assert_false(read_result.ok)
		assert_eq(read_result.error_code, ERR_FILE_CORRUPT)
		assert_eq(
			read_result.failure_kind,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
		_assert_read_result_origin(read_result, file_name, false)
		_assert_stale_authorization(
			_storage.create_family_reset_authorization(file_name, read_result)
		)
	assert_true(_absolute_path_is_link(linked_shard_path))
	assert_eq(_snapshot_tree_digest(external_root), external_digest)


func test_queued_reset_explicit_cancel_is_physical_cancel_without_write() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var file_name: String = "async/queued-cancel.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization)
	)
	assert_true(authorization.is_claimed())
	assert_true(operation.cancel_observation())

	_assert_pre_accept_reset_cancelled(
		operation,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL
	)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	_storage.tick(0.0)
	_storage.tick(0.0)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	assert_eq(cooperative_storage.thread_start_call_count, 0)


func test_queued_reset_deadline_is_physical_cancel_without_write() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var manual_clock: GFManualClock = GFManualClock.new(
		1_000_000,
		1_700_000_000_000
	)
	assert_true(cooperative_storage.set_async_clock_for_framework(manual_clock))
	var file_name: String = "async/queued-deadline.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)
	var options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.create(
		self,
		null,
		10
	)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization, options)
	)
	assert_true(authorization.is_claimed())
	assert_true(manual_clock.advance_msec(10))
	_storage.tick(0.0)

	_assert_pre_accept_reset_cancelled(
		operation,
		GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED
	)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	assert_eq(cooperative_storage.thread_start_call_count, 0)


func test_queued_reset_dispose_is_physical_cancel_without_write() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var file_name: String = "async/queued-dispose.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var before_digest: String = _snapshot_tree_digest(_storage_root_path)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization)
	)
	assert_true(authorization.is_claimed())

	cooperative_storage.dispose()

	_assert_pre_accept_reset_cancelled(
		operation,
		GFStorageAsyncCallerResult.EndKind.UTILITY_DISPOSED
	)
	assert_eq(_snapshot_tree_digest(_storage_root_path), before_digest)
	assert_eq(cooperative_storage.thread_start_call_count, 0)


func test_accepted_reset_cancel_reports_unknown_then_late_typed_success() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var file_name: String = "async/accepted-cancel.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization)
	)
	_storage.tick(0.0)
	assert_true(operation.is_pending())
	assert_true(operation.is_caller_pending())
	assert_true(authorization.is_claimed())

	assert_true(operation.cancel_observation())
	_assert_reset_caller_unknown(
		operation,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL
	)
	assert_true(operation.is_pending())
	_storage.tick(0.0)

	var reset_result: GFStorageFamilyResetResult = _assert_successful_async_reset(
		operation
	)
	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	_assert_reset_caller_unknown(
		operation,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL
	)
	_assert_reset_late_diagnostic(
		cooperative_storage,
		operation,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
		reset_result
	)


func test_accepted_reset_deadline_reports_unknown_then_late_typed_success() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var manual_clock: GFManualClock = GFManualClock.new(
		1_000_000,
		1_700_000_000_000
	)
	assert_true(cooperative_storage.set_async_clock_for_framework(manual_clock))
	var file_name: String = "async/accepted-deadline.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.create(
		self,
		null,
		10
	)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization, options)
	)
	_storage.tick(0.0)
	assert_true(operation.is_pending())
	assert_true(operation.is_caller_pending())
	assert_true(authorization.is_claimed())
	assert_true(manual_clock.advance_msec(10))

	_storage.tick(0.0)

	var reset_result: GFStorageFamilyResetResult = _assert_successful_async_reset(
		operation
	)
	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	_assert_reset_caller_unknown(
		operation,
		GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED
	)
	_assert_reset_late_diagnostic(
		cooperative_storage,
		operation,
		GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED,
		reset_result
	)


func test_accepted_reset_dispose_joins_to_normal_physical_settlement() -> void:
	var cooperative_storage: CooperativeResetStorageUtility = (
		CooperativeResetStorageUtility.new()
	)
	_replace_storage(cooperative_storage)
	cooperative_storage.async_execution_mode = (
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	)
	var file_name: String = "async/accepted-dispose.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var operation: GFStorageAsyncOperation = (
		_storage.reset_file_family_request_async(file_name, authorization)
	)
	_storage.tick(0.0)
	assert_true(operation.is_pending())
	assert_true(operation.is_caller_pending())
	assert_true(authorization.is_claimed())

	cooperative_storage.dispose()

	var reset_result: GFStorageFamilyResetResult = _assert_successful_async_reset(
		operation
	)
	_assert_successful_reset(
		reset_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	var caller_result: GFStorageAsyncCallerResult = operation.get_caller_result()
	assert_not_null(caller_result)
	if caller_result != null:
		assert_eq(
			caller_result.get_status(),
			GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED
		)
		assert_eq(
			caller_result.get_end_kind(),
			GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
		)
		assert_true(caller_result.is_successful())
	assert_true(cooperative_storage.get_late_settlement_diagnostics().is_empty())
	assert_eq(cooperative_storage.thread_start_call_count, 0)


func test_partial_recreate_catalog_failure_reports_progress_and_retries() -> void:
	var faulty_storage: ClaimFailureStorageUtility = ClaimFailureStorageUtility.new()
	_replace_storage(faulty_storage)
	var file_name: String = "failure/recreate-catalog.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	faulty_storage.fail_catalog_claim = true

	var failed_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		failed_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.RECREATE
	)
	assert_eq(failed_result.get_error_code(), ERR_FILE_CANT_WRITE)
	assert_eq(
		failed_result.get_source_kind(),
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	assert_eq(failed_result.get_retired_member_count(), 2)
	assert_eq(failed_result.get_recreated_member_count(), 2)
	assert_gt(failed_result.get_remaining_evidence_count(), 0)
	assert_eq(
		failed_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.CATALOG
	)
	assert_true(authorization.is_claimed())

	faulty_storage.fail_catalog_claim = false
	var retry_authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(
			file_name,
			observed_result.duplicate_result()
		)
	)
	var retry_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		retry_authorization
	)

	_assert_successful_reset(
		retry_result,
		GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
	)
	assert_true(retry_authorization.is_claimed())
	assert_false(_storage.has_file(file_name))
	assert_eq(_storage.save_data(file_name, { "recovered": true }), OK)


func test_partial_cleanup_failure_returns_bounded_evidence_without_private_paths() -> void:
	var faulty_storage: CleanupFailureStorageUtility = (
		CleanupFailureStorageUtility.new()
	)
	_replace_storage(faulty_storage)
	var file_name: String = "failure/cleanup.json"
	var observed_result: GFStorageReadResult = _save_and_corrupt_payload(file_name)
	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	faulty_storage.fail_family_container_cleanup = true

	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)

	_assert_reset_failure(
		reset_result,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.Phase.CLEANUP
	)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
	)
	assert_eq(reset_result.get_retired_member_count(), 2)
	assert_eq(reset_result.get_recreated_member_count(), 3)
	assert_gt(reset_result.get_remaining_evidence_count(), 0)
	var report_text: String = JSON.stringify(reset_result.to_dict())
	assert_false(report_text.contains("user://"))
	assert_false(report_text.contains(".gf-storage"))
	assert_false(report_text.contains("reset-"))


func test_settings_defaults_can_persist_after_explicit_storage_reset() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	_architectures.append(architecture)
	var adapter: GFStorageSettingsStoreUtility = GFStorageSettingsStoreUtility.new()
	var settings_utility: GFSettingsUtility = GFSettingsUtility.new()
	settings_utility.persistence_enabled = true
	settings_utility.auto_load_on_init = false
	settings_utility.auto_save_on_change = false
	var file_name: String = "settings/recovered-defaults.json"
	settings_utility.storage_file_name = file_name

	assert_true(await architecture.register_utility_instance(_storage))
	assert_true(
		await architecture.register_utility_instance_as(
			adapter,
			GFSettingsStoreUtility
		)
	)
	assert_true(await architecture.register_utility_instance(settings_utility))
	assert_true(await architecture.init())
	var registered_definition: GFSettingDefinition = settings_utility.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	assert_not_null(registered_definition)
	assert_eq(
		_storage.save_data(
			file_name,
			{
				"audio/master": 0.25,
				"legacy/flag": true,
			}
		),
		OK
	)
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "owner_path"),
			'{"schema":"gf.storage.family-owner","schema_version":1}'
		),
		OK
	)
	settings_utility.set_value(&"audio/master", 0.5, false)
	settings_utility.set_value(&"runtime/marker", "current", false)
	settings_utility.stage_value(&"audio/master", 0.75)
	var recovery_policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	recovery_policy.corrupt_file_action = (
		GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
	)

	var settings_load_result: GFSettingsLoadResult = settings_utility.load_settings(
		file_name,
		recovery_policy
	)
	var observed_result: GFStorageReadResult = (
		settings_load_result.get_storage_result()
	)
	assert_true(settings_load_result.is_successful())
	assert_eq(settings_load_result.get_status(), GFSettingsLoadResult.STATUS_RECOVERED)
	assert_eq(
		settings_load_result.get_recovery_action(),
		GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
	)
	assert_not_null(observed_result)
	if observed_result == null:
		return
	assert_eq(observed_result.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	var master_value: Variant = settings_utility.get_value(&"audio/master")
	assert_true(master_value is float)
	if master_value is float:
		var master_float: float = master_value
		assert_eq(master_float, 1.0)
	assert_false(settings_utility.has_setting(&"legacy/flag"))

	var authorization: GFStorageFamilyResetAuthorization = (
		_create_available_authorization(file_name, observed_result)
	)
	var reset_result: GFStorageFamilyResetResult = _storage.reset_file_family(
		file_name,
		authorization
	)
	assert_true(reset_result.is_successful())
	assert_eq(settings_utility.save_settings(file_name), OK)

	var persisted: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(persisted.ok)
	assert_eq(GFVariantData.get_option_float(persisted.payload, "audio/master"), 1.0)
	assert_false(persisted.payload.has("legacy/flag"))


# --- 私有/辅助方法 ---

func _replace_storage(replacement: GFStorageUtility) -> void:
	assert_not_null(replacement)
	if replacement == null:
		return
	if _storage != null:
		_storage.dispose()
	_storage = replacement
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0
	_storage.init()


func _replace_storage_without_init(replacement: GFStorageUtility) -> void:
	assert_not_null(replacement)
	if replacement == null:
		return
	if _storage != null:
		_storage.dispose()
	_storage = replacement
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0


func _make_integrity_storage() -> GFStorageUtility:
	var replacement: GFStorageUtility = GFStorageUtility.new()
	replacement.include_storage_metadata = true
	replacement.use_integrity_checksum = true
	replacement.strict_integrity = true
	return replacement


func _recreate_storage_fixture_root() -> void:
	if _storage != null:
		_storage.dispose()
		_storage = null
	assert_eq(_remove_owned_test_tree(_storage_root_path), OK)
	_replace_storage(GFStorageUtility.new())


func _make_external_fixture_root(label: String) -> String:
	var external_root: String = (
		"user://gf-storage-family-reset-sentinel-"
		+ GFUuid.generate_v4()
		+ "-"
		+ label
	)
	_external_fixture_roots.append(external_root)
	assert_eq(DirAccess.make_dir_recursive_absolute(external_root), OK)
	return external_root


func _descriptor(file_name: String) -> Dictionary:
	return _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		file_name
	)


func _save_and_corrupt_payload(file_name: String) -> GFStorageReadResult:
	_storage.include_storage_metadata = true
	_storage.use_integrity_checksum = true
	_storage.strict_integrity = true
	assert_eq(_storage.save_data(file_name, { "generation": 1 }), OK)
	var descriptor: Dictionary = _descriptor(file_name)
	var payload_path: String = GFVariantData.get_option_string(
		descriptor,
		"payload_path"
	)
	var document_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(payload_path)
	)
	assert_true(document_value is Dictionary)
	if not document_value is Dictionary:
		return _make_read_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_INVALID_DATA
		)
	var document: Dictionary = document_value
	var stored_payload: Dictionary = GFVariantData.get_option_dictionary(
		document,
		GFStorageCodec.PAYLOAD_KEY
	)
	stored_payload["generation"] = 99
	document[GFStorageCodec.PAYLOAD_KEY] = stored_payload
	assert_eq(
		_write_text(
			payload_path,
			JSON.stringify(document)
		),
		OK
	)
	var observed_result: GFStorageReadResult = _assert_corrupt_read(file_name)
	_assert_expected_integrity_warning(descriptor)
	return observed_result


func _assert_expected_integrity_warning(descriptor: Dictionary) -> void:
	assert_push_warning(
		"[GFStorageUtility] 读取数据失败：%s，原因：Integrity checksum mismatch"
		% GFVariantData.get_option_string(descriptor, "payload_path")
	)


func _assert_corrupt_read(file_name: String) -> GFStorageReadResult:
	var observed_result: GFStorageReadResult = _storage.load_data(file_name)
	assert_not_null(observed_result)
	assert_false(observed_result.ok)
	assert_ne(observed_result.error_code, OK)
	assert_eq(observed_result.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	return observed_result


func _make_read_failure(
	failure_kind: GFStorageReadResult.FailureKind,
	error_code: Error
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		"Synthetic Storage read failure.",
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _create_available_authorization(
	file_name: String,
	observed_result: GFStorageReadResult
) -> GFStorageFamilyResetAuthorization:
	var authorization: GFStorageFamilyResetAuthorization = (
		_storage.create_family_reset_authorization(file_name, observed_result)
	)
	assert_not_null(authorization)
	assert_true(authorization.is_available())
	return authorization


func _assert_stale_authorization(
	authorization: GFStorageFamilyResetAuthorization
) -> void:
	assert_not_null(authorization, "拒绝结果仍应返回 typed stale authorization。")
	if authorization == null:
		return
	assert_true(authorization.is_stale())
	assert_false(authorization.is_available())


func _assert_read_result_origin(
	result: GFStorageReadResult,
	file_name: String,
	expected_bound: bool
) -> void:
	assert_not_null(result)
	if result == null:
		return
	var descriptor: Dictionary = _descriptor(file_name)
	assert_eq(
		result.matches_origin_for_framework(
			_storage.get_instance_id(),
			file_name,
			GFVariantData.get_option_string(descriptor, "file_key"),
			_storage._read_result_origin_token
		),
		expected_bound
	)


func _assert_successful_reset(
	reset_result: GFStorageFamilyResetResult,
	expected_source_kind: GFStorageFamilyResetResult.SourceKind
) -> void:
	assert_not_null(reset_result)
	if reset_result == null:
		return
	assert_true(reset_result.is_successful())
	assert_eq(reset_result.get_error_code(), OK)
	assert_eq(reset_result.get_failure_kind(), GFStorageFamilyResetResult.FailureKind.NONE)
	assert_eq(reset_result.get_source_kind(), expected_source_kind)
	assert_eq(reset_result.get_failed_phase(), GFStorageFamilyResetResult.Phase.NONE)
	assert_eq(reset_result.get_retired_member_count(), 2)
	assert_eq(reset_result.get_recreated_member_count(), 3)
	assert_eq(reset_result.get_remaining_evidence_count(), 0)
	assert_eq(
		reset_result.get_failed_member(),
		GFStorageFamilyResetResult.FamilyMember.NONE
	)


func _assert_reset_failure(
	reset_result: GFStorageFamilyResetResult,
	expected_failure_kind: GFStorageFamilyResetResult.FailureKind,
	expected_phase: GFStorageFamilyResetResult.Phase
) -> void:
	assert_not_null(reset_result)
	if reset_result == null:
		return
	assert_false(reset_result.is_successful())
	assert_ne(reset_result.get_error_code(), OK)
	assert_eq(reset_result.get_failure_kind(), expected_failure_kind)
	assert_eq(reset_result.get_failed_phase(), expected_phase)


func _assert_valid_family_claim(descriptor: Dictionary) -> void:
	var family_path: String = GFVariantData.get_option_string(
		descriptor,
		"family_path"
	)
	var catalog_path: String = GFVariantData.get_option_string(
		descriptor,
		"catalog_path"
	)
	assert_true(DirAccess.dir_exists_absolute(family_path))
	assert_false(FileAccess.file_exists(family_path))
	assert_true(FileAccess.file_exists(catalog_path))
	assert_false(DirAccess.dir_exists_absolute(catalog_path))
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	assert_true(family_store.configure_for_framework(_storage_root_path))
	assert_eq(family_store.validate_family_for_framework(descriptor), OK)


func _write_json(path: String, value: Dictionary) -> Error:
	return _write_text(path, JSON.stringify(value, "\t"))


func _reset_intent_path(descriptor: Dictionary, reset_id: String) -> String:
	return (
		GFVariantData.get_option_string(descriptor, "family_path")
		+ ".reset-"
		+ reset_id
		+ ".intent.json"
	)


func _retired_family_path(descriptor: Dictionary, reset_id: String) -> String:
	return (
		GFVariantData.get_option_string(descriptor, "family_path")
		+ ".reset-"
		+ reset_id
	)


func _retired_catalog_path(descriptor: Dictionary, reset_id: String) -> String:
	return (
		GFVariantData.get_option_string(descriptor, "catalog_path")
		+ ".reset-"
		+ reset_id
	)


func _make_reset_intent_fixture(
	descriptor: Dictionary,
	reset_id: String,
	source_kind: GFStorageFamilyResetResult.SourceKind,
	initial_retired_member_count: int = 2
) -> Dictionary:
	return {
		"schema": "gf.storage.family-reset-intent",
		"schema_version": 1,
		"reset_id": reset_id,
		"logical_path": GFVariantData.get_option_string(
			descriptor,
			"logical_path"
		),
		"logical_sha256": GFVariantData.get_option_string(
			descriptor,
			"logical_sha256"
		),
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"source_kind": int(source_kind),
		"initial_retired_member_count": initial_retired_member_count,
	}


func _make_family_owner_fixture(descriptor: Dictionary) -> Dictionary:
	return {
		"schema": "gf.storage.family-owner",
		"schema_version": 1,
		"path_profile": "portable-ascii-v1",
		"identity_algorithm": "sha256-domain-nul-uuidv8-v1",
		"logical_path": GFVariantData.get_option_string(
			descriptor,
			"logical_path"
		),
		"logical_sha256": GFVariantData.get_option_string(
			descriptor,
			"logical_sha256"
		),
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"payload_leaf": GFVariantData.get_option_string(
			descriptor,
			"payload_path"
		).get_file(),
	}


func _install_reset_intent_and_retire_exact(
	descriptor: Dictionary,
	reset_id: String,
	source_kind: GFStorageFamilyResetResult.SourceKind
) -> Dictionary:
	var intent_path: String = _reset_intent_path(descriptor, reset_id)
	var retired_family_path: String = _retired_family_path(descriptor, reset_id)
	var retired_catalog_path: String = _retired_catalog_path(descriptor, reset_id)
	assert_eq(
		_write_json(
			intent_path,
			_make_reset_intent_fixture(descriptor, reset_id, source_kind, 2)
		),
		OK
	)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "family_path"),
			retired_family_path
		),
		OK
	)
	assert_eq(
		DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "catalog_path"),
			retired_catalog_path
		),
		OK
	)
	return {
		"intent_path": intent_path,
		"family_path": retired_family_path,
		"catalog_path": retired_catalog_path,
	}


func _assert_reset_residue_absent(
	descriptor: Dictionary,
	reset_id: String,
	pending_path: String = ""
) -> void:
	_assert_absolute_leaf_absent(_reset_intent_path(descriptor, reset_id))
	_assert_absolute_leaf_absent(_retired_family_path(descriptor, reset_id))
	_assert_absolute_leaf_absent(_retired_catalog_path(descriptor, reset_id))
	if not pending_path.is_empty():
		_assert_absolute_leaf_absent(pending_path)


func _assert_absolute_leaf_absent(path: String) -> void:
	assert_false(FileAccess.file_exists(path))
	assert_false(DirAccess.dir_exists_absolute(path))


func _assert_pre_accept_reset_cancelled(
	operation: GFStorageAsyncOperation,
	expected_end_kind: GFStorageAsyncCallerResult.EndKind
) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_completed())
	assert_false(operation.is_pending())
	var async_result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(async_result)
	if async_result == null:
		return
	assert_eq(async_result.get_operation(), GFStorageAsyncOperation.OPERATION_RESET)
	assert_eq(
		async_result.get_settlement_kind(),
		GFStorageAsyncResult.SettlementKind.CANCELLED
	)
	assert_true(async_result.is_cancelled())
	assert_false(async_result.is_successful())
	assert_eq(async_result.get_error_code(), ERR_SKIP)
	assert_null(async_result.get_reset_result())

	var caller_result: GFStorageAsyncCallerResult = operation.get_caller_result()
	assert_not_null(caller_result)
	if caller_result == null:
		return
	assert_eq(
		caller_result.get_status(),
		GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED
	)
	assert_eq(caller_result.get_end_kind(), expected_end_kind)
	assert_eq(caller_result.get_error_code(), ERR_SKIP)
	assert_false(caller_result.is_outcome_unknown())
	var physical_result: GFStorageAsyncResult = caller_result.get_physical_result()
	assert_not_null(physical_result)
	if physical_result != null:
		assert_eq(physical_result.get_request_id(), async_result.get_request_id())
		assert_eq(
			physical_result.get_settlement_kind(),
			GFStorageAsyncResult.SettlementKind.CANCELLED
		)
		assert_null(physical_result.get_reset_result())


func _assert_reset_caller_unknown(
	operation: GFStorageAsyncOperation,
	expected_end_kind: GFStorageAsyncCallerResult.EndKind
) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	var caller_result: GFStorageAsyncCallerResult = operation.get_caller_result()
	assert_not_null(caller_result)
	if caller_result == null:
		return
	assert_eq(caller_result.get_operation(), GFStorageAsyncOperation.OPERATION_RESET)
	assert_eq(
		caller_result.get_status(),
		GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN
	)
	assert_eq(caller_result.get_end_kind(), expected_end_kind)
	assert_eq(caller_result.get_error_code(), ERR_BUSY)
	assert_true(caller_result.is_outcome_unknown())
	assert_false(caller_result.is_successful())
	assert_null(caller_result.get_physical_result())


func _assert_successful_async_reset(
	operation: GFStorageAsyncOperation
) -> GFStorageFamilyResetResult:
	assert_not_null(operation)
	if operation == null:
		return null
	assert_true(operation.is_completed())
	assert_false(operation.is_pending())
	var async_result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(async_result)
	if async_result == null:
		return null
	assert_eq(async_result.get_operation(), GFStorageAsyncOperation.OPERATION_RESET)
	assert_eq(
		async_result.get_settlement_kind(),
		GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT
	)
	assert_false(async_result.is_cancelled())
	assert_true(async_result.is_successful())
	assert_eq(async_result.get_error_code(), OK)
	var reset_result: GFStorageFamilyResetResult = async_result.get_reset_result()
	assert_not_null(reset_result)
	return reset_result


func _assert_reset_late_diagnostic(
	storage: GFStorageUtility,
	operation: GFStorageAsyncOperation,
	expected_end_kind: GFStorageAsyncCallerResult.EndKind,
	reset_result: GFStorageFamilyResetResult
) -> void:
	assert_not_null(storage)
	assert_not_null(operation)
	assert_not_null(reset_result)
	if storage == null or operation == null or reset_result == null:
		return
	var diagnostics: Array[Dictionary] = storage.get_late_settlement_diagnostics()
	assert_eq(diagnostics.size(), 1)
	if diagnostics.size() != 1:
		return
	var diagnostic: Dictionary = diagnostics[0]
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "request_id"),
		operation.get_request_id()
	)
	assert_eq(
		GFVariantData.get_option_string_name(diagnostic, "operation"),
		GFStorageAsyncOperation.OPERATION_RESET
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "caller_status"),
		int(GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN)
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "caller_end_kind"),
		int(expected_end_kind)
	)
	assert_true(GFVariantData.get_option_bool(diagnostic, "worker_accepted"))
	assert_false(
		GFVariantData.get_option_bool(diagnostic, "physical_cancel_requested")
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "settlement_kind"),
		int(GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT)
	)
	assert_true(GFVariantData.get_option_bool(diagnostic, "physical_ok"))
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "physical_error_code"),
		OK
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "reset_failure_kind"),
		int(reset_result.get_failure_kind())
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "reset_source_kind"),
		int(reset_result.get_source_kind())
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "reset_failed_phase"),
		int(reset_result.get_failed_phase())
	)
	assert_eq(
		GFVariantData.get_option_int(
			diagnostic,
			"reset_retired_member_count"
		),
		reset_result.get_retired_member_count()
	)
	assert_eq(
		GFVariantData.get_option_int(
			diagnostic,
			"reset_recreated_member_count"
		),
		reset_result.get_recreated_member_count()
	)
	assert_eq(
		GFVariantData.get_option_int(
			diagnostic,
			"reset_remaining_evidence_count"
		),
		reset_result.get_remaining_evidence_count()
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "reset_failed_member"),
		int(reset_result.get_failed_member())
	)


func _connect_completion_label(
	operation: GFStorageAsyncOperation,
	completion_order: Array[StringName],
	label: StringName
) -> void:
	var connect_error: Error = operation.completed.connect(
		Callable(self, &"_append_completion_label").bind(completion_order, label),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)


func _append_completion_label(
	_result: GFStorageAsyncResult,
	completion_order: Array[StringName],
	label: StringName
) -> void:
	completion_order.append(label)


func _begin_quiesce_from_async_completion(
	_result: GFStorageAsyncResult
) -> void:
	_completion_listener_quiesce = _storage.begin_quiesce(GFAsyncScope.new())


func _pump_until_operations_complete(
	operations: Array[GFStorageAsyncOperation]
) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		var all_completed: bool = true
		for operation: GFStorageAsyncOperation in operations:
			all_completed = all_completed and operation.is_completed()
		if all_completed:
			return true
		await get_tree().process_frame
	return false


func _wait_for_gated_reset_worker_started(
	storage: GatedThreadedResetStorageUtility
) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		if storage.worker_started.try_wait():
			return true
		await get_tree().process_frame
	return false


func _get_method_argument_count(object_value: Object, method_name: StringName) -> int:
	for method_value: Variant in object_value.get_method_list():
		if not method_value is Dictionary:
			continue
		var method_entry: Dictionary = method_value
		if GFVariantData.get_option_string_name(method_entry, "name") != method_name:
			continue
		var arguments_value: Variant = method_entry.get("args", [])
		if arguments_value is Array:
			var arguments: Array = arguments_value
			return arguments.size()
		return -1
	return -1


func _snapshot_tree_digest(root_path: String) -> String:
	var entries: PackedStringArray = []
	var collect_error: Error = _collect_tree_snapshot_entries(
		root_path,
		root_path,
		entries
	)
	assert_eq(collect_error, OK)
	entries.sort()
	var hashing_context: HashingContext = HashingContext.new()
	assert_eq(hashing_context.start(HashingContext.HASH_SHA256), OK)
	for entry: String in entries:
		assert_eq(hashing_context.update(entry.to_utf8_buffer()), OK)
		assert_eq(hashing_context.update(PackedByteArray([0])), OK)
	return hashing_context.finish().hex_encode()


func _collect_tree_snapshot_entries(
	root_path: String,
	current_path: String,
	entries: PackedStringArray
) -> Error:
	if not DirAccess.dir_exists_absolute(current_path):
		return OK
	var directory: DirAccess = DirAccess.open(current_path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	var file_names: PackedStringArray = directory.get_files()
	var directory_names: PackedStringArray = directory.get_directories()
	file_names.sort()
	directory_names.sort()
	for file_name: String in file_names:
		var file_path: String = current_path.path_join(file_name)
		var relative_path: String = file_path.trim_prefix(root_path + "/")
		var _file_entry_appended: bool = entries.append(
			"f:%s:%s" % [
				relative_path,
				FileAccess.get_file_as_bytes(file_path).hex_encode(),
			]
		)
	for directory_name: String in directory_names:
		var child_path: String = current_path.path_join(directory_name)
		var relative_directory: String = child_path.trim_prefix(root_path + "/")
		var _directory_entry_appended: bool = entries.append("d:%s" % relative_directory)
		var child_error: Error = _collect_tree_snapshot_entries(
			root_path,
			child_path,
			entries
		)
		if child_error != OK:
			return child_error
	return OK


func _write_text(file_path: String, text: String) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		file_path.get_base_dir()
	)
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(text) != null
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error


func _create_file_link(target_path: String, link_path: String) -> Error:
	var link_parent: DirAccess = DirAccess.open(link_path.get_base_dir())
	if link_parent == null:
		return DirAccess.get_open_error()
	return link_parent.create_link(
		ProjectSettings.globalize_path(target_path),
		ProjectSettings.globalize_path(link_path)
	)


func _absolute_path_is_link(path: String) -> bool:
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())


func _remove_owned_test_tree(root_path: String) -> Error:
	if root_path.is_empty():
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(root_path):
		return DirAccess.remove_absolute(root_path)
	if not DirAccess.dir_exists_absolute(root_path):
		return OK
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(
			root_path.path_join(file_name)
		)
		if remove_file_error != OK:
			return remove_file_error
	for directory_name: String in directory.get_directories():
		var child_path: String = root_path.path_join(directory_name)
		var remove_directory_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_test_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	directory = null
	return DirAccess.remove_absolute(root_path)


# --- 内部类 ---

class CooperativeResetStorageUtility extends GFStorageUtility:
	var thread_start_call_count: int = 0

	func has_async_thread_capability_for_framework() -> bool:
		return false

	func start_async_worker_for_framework(
		_task_type: StringName,
		_thread: Thread,
		_callback: Callable
	) -> Error:
		thread_start_call_count += 1
		return ERR_CANT_CREATE


class GatedThreadedResetStorageUtility extends GFStorageUtility:
	var worker_started: Semaphore = Semaphore.new()
	var worker_release: Semaphore = Semaphore.new()
	var thread_start_call_count: int = 0

	func has_async_thread_capability_for_framework() -> bool:
		return true

	func start_async_worker_for_framework(
		_task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		thread_start_call_count += 1
		return thread.start(Callable(self, &"_run_gated_worker").bind(callback))

	func release_all_for_test() -> void:
		for _index: int in range(8):
			worker_release.post()

	func _run_gated_worker(callback: Callable) -> Variant:
		worker_started.post()
		worker_release.wait()
		return callback.call()


class ColdCooperativeResetStorageUtility extends CooperativeResetStorageUtility:
	func init() -> void:
		pass


class CleanupFailureStorageUtility extends GFStorageUtility:
	var fail_family_container_cleanup: bool = false

	func remove_reset_family_member_for_framework(
		member_kind: StringName,
		path: String
	) -> Error:
		if fail_family_container_cleanup and member_kind == &"family_container":
			return ERR_FILE_CANT_WRITE
		return super.remove_reset_family_member_for_framework(member_kind, path)


class ClaimFailureStorageUtility extends GFStorageUtility:
	var fail_catalog_claim: bool = false

	func claim_reset_family_for_framework(
		family_store: GFStorageFamilyStore,
		descriptor: Dictionary
	) -> Error:
		var claim_error: Error = super.claim_reset_family_for_framework(
			family_store,
			descriptor
		)
		if claim_error != OK or not fail_catalog_claim:
			return claim_error
		var catalog_path: String = GFVariantData.get_option_string(
			descriptor,
			"catalog_path"
		)
		var remove_error: Error = DirAccess.remove_absolute(catalog_path)
		return ERR_FILE_CANT_WRITE if remove_error == OK else remove_error
