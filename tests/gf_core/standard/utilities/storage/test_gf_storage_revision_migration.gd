# 测试显式离线 revision 升级的屏障、持久代次及逐阶段故障恢复。
extends GutTest


# --- 私有变量 ---

var _storage: GFStorageUtility
var _save_dir_name: String = ""
var _storage_root: String = ""
var _version_root: String = ""


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_save_dir_name = "gf-revision-upgrade-" + GFUuid.generate_v4()
	_storage_root = GFStorageFamilyStore.make_storage_root_path_for_framework(_save_dir_name)
	_version_root = _storage_root.path_join(".gf-storage/v1")
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name


func after_each() -> void:
	_storage.dispose()
	_storage = null
	assert_true(_storage_root.begins_with("user://gf-revision-upgrade-"))
	if _storage_root.begins_with("user://gf-revision-upgrade-"):
		assert_eq(_remove_owned_tree(_storage_root), OK)
	_storage_root = ""
	_version_root = ""
	_save_dir_name = ""


# --- 公共方法 ---

func test_upgrade_preserves_payload_claims_and_existing_empty_families() -> void:
	assert_eq(_storage.save_data("data.json", {"value": 7}), OK)
	assert_eq(_storage.save_resource("asset.tres", Resource.new()), OK)
	assert_eq(_storage.save_data("empty.json", {"value": 0}), OK)
	assert_eq(_storage.delete_file("empty.json"), OK)
	_storage.dispose()
	var payload_before: PackedByteArray = FileAccess.get_file_as_bytes(_payload_path("data.json"))
	var resource_before: PackedByteArray = FileAccess.get_file_as_bytes(_payload_path("asset.tres"))
	var descriptor: Dictionary = _descriptor("data.json")
	var owner_path: String = GFVariantData.get_option_string(descriptor, "owner_path")
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var owner_before: PackedByteArray = FileAccess.get_file_as_bytes(owner_path)
	var catalog_before: PackedByteArray = FileAccess.get_file_as_bytes(catalog_path)
	var migration: GFStorageRevisionMigration = GFStorageRevisionMigration.new()

	assert_eq(migration.upgrade(_save_dir_name), OK)

	assert_eq(FileAccess.get_file_as_bytes(_payload_path("data.json")), payload_before)
	assert_eq(FileAccess.get_file_as_bytes(_payload_path("asset.tres")), resource_before)
	assert_eq(FileAccess.get_file_as_bytes(owner_path), owner_before)
	assert_eq(FileAccess.get_file_as_bytes(catalog_path), catalog_before)
	assert_true(_revision("data.json").is_successful())
	assert_true(_revision("asset.tres").is_successful())
	assert_eq(_revision("empty.json").get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
	assert_false(FileAccess.file_exists(_state_path("empty.json")))
	_assert_complete_layout()
	assert_false(_old_runtime_accepts_version_root())
	var revision_before: String = _revision("data.json").get_revision()
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(_revision("data.json").get_revision(), revision_before)


func test_missing_or_invalid_root_is_not_created() -> void:
	var migration: GFStorageRevisionMigration = GFStorageRevisionMigration.new()
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_NOT_FOUND)
	assert_false(DirAccess.dir_exists_absolute(_storage_root))
	assert_eq(migration.upgrade("../outside"), ERR_INVALID_PARAMETER)


func test_truncated_intent_blocks_every_runtime_and_is_not_guessed_on_retry() -> void:
	_seed_two_files()
	var layout_before: PackedByteArray = FileAccess.get_file_as_bytes(_layout_path())
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.intent.json"
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var intent_before: PackedByteArray = FileAccess.get_file_as_bytes(_intent_path())
	_assert_runtime_blocked()
	assert_false(FileAccess.file_exists(_state_path("a.json")))
	assert_false(FileAccess.file_exists(_state_path("b.json")))

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_bytes(_intent_path()), intent_before)
	assert_eq(FileAccess.get_file_as_bytes(_layout_path()), layout_before)


func test_fully_persisted_intent_can_resume_after_reported_write_failure() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.intent.json"
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var intent: Dictionary = _read_dictionary(_intent_path())
	var incarnation: String = GFVariantData.get_option_string(intent, "storage_incarnation")
	assert_true(GFUuid.is_valid(incarnation, 4))
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(GFVariantData.get_option_string(_read_dictionary(_layout_path()), "storage_incarnation"), incarnation)
	_assert_complete_layout()


func test_intent_unknown_fields_and_oversized_records_fail_closed() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.intent.json"
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var intent: Dictionary = _read_dictionary(_intent_path())
	intent["unexpected"] = "untrusted"
	assert_eq(_write_text(_intent_path(), JSON.stringify(intent)), OK)
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_false(FileAccess.file_exists(_state_path("a.json")))
	assert_eq(_write_text(_intent_path(), " ".repeat(4097)), OK)
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	_assert_runtime_blocked()


func test_truncated_state_recovers_only_the_persisted_cursor_commit_id() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_state_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var first_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	var cursor: Dictionary = _read_dictionary(_cursor_path())
	assert_eq(GFVariantData.get_option_string(cursor, "logical_path"), "b.json")
	var expected_commit_id: String = GFVariantData.get_option_string(cursor, "commit_id")
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), first_state)
	assert_eq(GFVariantData.get_option_string(_read_dictionary(_state_path("b.json")), "commit_id"), expected_commit_id)
	_assert_complete_layout()


func test_valid_state_is_reused_after_writer_reports_failure() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_state_write_number = 1
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var state_before: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), state_before)
	_assert_complete_layout()


func test_corrupt_completed_state_without_cursor_evidence_is_not_replaced() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_state_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_eq(_write_text(_state_path("a.json"), "{"), OK)
	var cursor_before: PackedByteArray = FileAccess.get_file_as_bytes(_cursor_path())

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), "{")
	assert_eq(FileAccess.get_file_as_bytes(_cursor_path()), cursor_before)
	_assert_runtime_blocked()


func test_missing_completed_state_does_not_mint_a_replacement_token() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_state_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_eq(DirAccess.remove_absolute(_state_path("a.json")), OK)

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_false(FileAccess.file_exists(_state_path("a.json")))
	_assert_runtime_blocked()


func test_cursor_rename_gap_resumes_from_complete_pending_record() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_install_number = 2
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_false(FileAccess.file_exists(_cursor_path()))
	var pending_path: String = _version_root.path_join("upgrade.cursor.pending.json")
	var pending_record: Dictionary = _read_dictionary(pending_path)
	var first_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), first_state)
	assert_eq(
		GFVariantData.get_option_string(_read_dictionary(_state_path("b.json")), "commit_id"),
		GFVariantData.get_option_string(pending_record, "commit_id")
	)
	_assert_complete_layout()


func test_truncated_layout_staging_is_rebuilt_from_intent_without_changing_committed_states() -> void:
	_seed_two_files()
	var layout_before: PackedByteArray = FileAccess.get_file_as_bytes(_layout_path())
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.layout.json"
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var first_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	var second_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("b.json"))
	var intent: Dictionary = _read_dictionary(_intent_path())
	assert_eq(FileAccess.get_file_as_bytes(_layout_path()), layout_before)
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), first_state)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("b.json")), second_state)
	assert_eq(
		GFVariantData.get_option_string(_read_dictionary(_layout_path()), "storage_incarnation"),
		GFVariantData.get_option_string(intent, "storage_incarnation")
	)
	_assert_complete_layout()


func test_truncated_first_cursor_staging_can_restart_before_any_state_is_published() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.cursor.pending.json"
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_false(FileAccess.file_exists(_cursor_path()))
	assert_false(FileAccess.file_exists(_state_path("a.json")))
	assert_false(FileAccess.file_exists(_state_path("b.json")))
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	_assert_complete_layout()


func test_truncated_next_cursor_staging_preserves_previous_published_state() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var first_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	assert_false(first_state.is_empty())
	assert_false(FileAccess.file_exists(_state_path("b.json")))
	var cursor: Dictionary = _read_dictionary(_cursor_path())
	assert_eq(GFVariantData.get_option_string(cursor, "logical_path"), "a.json")
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), first_state)
	_assert_complete_layout()


func test_truncated_cursor_staging_requires_the_current_published_state() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var cursor_before: String = FileAccess.get_file_as_string(_cursor_path())
	var state_before: String = FileAccess.get_file_as_string(_state_path("a.json"))
	var changed_state: Dictionary = _read_dictionary(_state_path("a.json"))
	changed_state["commit_id"] = GFUuid.generate_v4()
	for invalid_state: String in ["", "{", JSON.stringify(changed_state)]:
		if invalid_state.is_empty():
			assert_eq(DirAccess.remove_absolute(_state_path("a.json")), OK)
		else:
			assert_eq(_write_text(_state_path("a.json"), invalid_state), OK)
		assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
		assert_eq(FileAccess.get_file_as_string(_cursor_path()), cursor_before)
		assert_eq(FileAccess.get_file_as_string(_version_root.path_join("upgrade.cursor.pending.json")), "{")
		assert_eq(_write_text(_state_path("a.json"), state_before), OK)
	assert_eq(_write_text(_cursor_path(), "{"), OK)
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_string(_cursor_path()), "{")
	assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), state_before)
	_assert_runtime_blocked()


func test_truncated_cursor_staging_in_a_rename_gap_never_discards_published_identity() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_install_number = 2
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var staged_path: String = _version_root.path_join("upgrade.cursor.pending.json")
	assert_eq(_write_text(staged_path, "{"), OK)
	assert_false(FileAccess.file_exists(_cursor_path()))
	var first_state: String = FileAccess.get_file_as_string(_state_path("a.json"))
	for preserved_state: String in [first_state, "{"]:
		assert_eq(_write_text(_state_path("a.json"), preserved_state), OK)
		assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
		assert_eq(FileAccess.get_file_as_string(staged_path), "{")
		assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), preserved_state)
		assert_false(FileAccess.file_exists(_cursor_path()))
		assert_false(FileAccess.file_exists(_state_path("b.json")))
	_assert_runtime_blocked()


func test_cursor_staging_cleanup_failure_preserves_evidence_and_can_retry() -> void:
	_seed_two_files()
	var writer: FaultMigration = FaultMigration.new()
	writer.fail_write_leaf = "upgrade.cursor.pending.json"
	writer.truncate_failed_write = true
	assert_eq(writer.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var remover: FaultMigration = FaultMigration.new()
	remover.fail_remove_leaf = "upgrade.cursor.pending.json"
	assert_eq(remover.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_eq(FileAccess.get_file_as_string(_version_root.path_join("upgrade.cursor.pending.json")), "{")
	assert_false(FileAccess.file_exists(_state_path("a.json")))
	_assert_runtime_blocked()
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	_assert_complete_layout()


func test_complete_or_oversized_cursor_staging_is_not_treated_as_a_partial_write() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var cursor_before: String = FileAccess.get_file_as_string(_cursor_path())
	var state_before: String = FileAccess.get_file_as_string(_state_path("a.json"))
	var invalid_record: Dictionary = _read_dictionary(_cursor_path())
	invalid_record["unexpected"] = true
	var staged_path: String = _version_root.path_join("upgrade.cursor.pending.json")
	for invalid_text: String in [JSON.stringify(invalid_record), "[]", " ".repeat(4097)]:
		assert_eq(_write_text(staged_path, invalid_text), OK)
		assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
		assert_eq(FileAccess.get_file_as_string(staged_path), invalid_text)
		assert_eq(FileAccess.get_file_as_string(_cursor_path()), cursor_before)
		assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), state_before)
	assert_eq(DirAccess.remove_absolute(staged_path), OK)
	assert_eq(DirAccess.make_dir_absolute(staged_path), OK)
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_true(DirAccess.dir_exists_absolute(staged_path))
	_assert_runtime_blocked()


func test_conflicting_valid_cursor_staging_is_rejected_before_replacing_current_cursor() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_cursor_write_number = 2
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var cursor_before: String = FileAccess.get_file_as_string(_cursor_path())
	var state_before: String = FileAccess.get_file_as_string(_state_path("a.json"))
	var conflicting: Dictionary = _read_dictionary(_cursor_path())
	conflicting["commit_id"] = GFUuid.generate_v4()
	var staged_path: String = _version_root.path_join("upgrade.cursor.pending.json")
	var staged_text: String = JSON.stringify(conflicting)
	assert_eq(_write_text(staged_path, staged_text), OK)
	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_string(_cursor_path()), cursor_before)
	assert_eq(FileAccess.get_file_as_string(staged_path), staged_text)
	assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), state_before)
	_assert_runtime_blocked()


func test_complete_or_oversized_layout_staging_is_preserved_as_conflicting_evidence() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_write_leaf = "upgrade.layout.json"
	migration.truncate_failed_write = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	var layout_before: String = FileAccess.get_file_as_string(_layout_path())
	var first_state: String = FileAccess.get_file_as_string(_state_path("a.json"))
	var staged_path: String = _version_root.path_join("upgrade.layout.json")
	for invalid_text: String in ["{}", "[]", " ".repeat(4097)]:
		assert_eq(_write_text(staged_path, invalid_text), OK)
		assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), ERR_FILE_CORRUPT)
		assert_eq(FileAccess.get_file_as_string(staged_path), invalid_text)
		assert_eq(FileAccess.get_file_as_string(_layout_path()), layout_before)
		assert_eq(FileAccess.get_file_as_string(_state_path("a.json")), first_state)
	_assert_runtime_blocked()


func test_layout_rename_gap_keeps_old_and_new_runtimes_blocked() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_remove_leaf = "layout.json"
	migration.remove_before_failure = true
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_false(FileAccess.file_exists(_layout_path()))
	assert_true(FileAccess.file_exists(_version_root.path_join("upgrade.layout.json")))
	var state_before: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	_assert_runtime_blocked()
	assert_false(FileAccess.file_exists(_layout_path()), "普通 ensure 不能在 rename gap 创建 schema 1。")

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), state_before)
	_assert_complete_layout()


func test_schema2_is_not_admitted_until_final_intent_cleanup() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.fail_remove_leaf = "upgrade.intent.json"
	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CANT_WRITE)
	assert_eq(GFVariantData.to_exact_int(_read_dictionary(_layout_path()).get("schema_version"), -1), 2)
	var state_before: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("a.json"))
	_assert_runtime_blocked()

	assert_eq(GFStorageRevisionMigration.new().upgrade(_save_dir_name), OK)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("a.json")), state_before)
	_assert_complete_layout()


func test_final_state_validation_precedes_layout_replacement() -> void:
	_seed_two_files()
	var migration: FaultMigration = FaultMigration.new()
	migration.corrupt_prior_state_path = _state_path("a.json")
	var layout_before: PackedByteArray = FileAccess.get_file_as_bytes(_layout_path())

	assert_eq(migration.upgrade(_save_dir_name), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_bytes(_layout_path()), layout_before)
	assert_false(FileAccess.file_exists(_version_root.path_join("upgrade.layout.json")))
	_assert_runtime_blocked()


# --- 私有/辅助方法 ---

func _seed_two_files() -> void:
	assert_eq(_storage.save_data("a.json", {"value": 1}), OK)
	assert_eq(_storage.save_data("b.json", {"value": 2}), OK)
	_storage.dispose()
	assert_true(_old_runtime_accepts_version_root())


func _descriptor(logical_path: String) -> Dictionary:
	return GFStorageFamilyStore.make_family_descriptor_for_framework(_storage_root, logical_path)


func _payload_path(logical_path: String) -> String:
	return GFVariantData.get_option_string(_descriptor(logical_path), "payload_path")


func _state_path(logical_path: String) -> String:
	return GFVariantData.get_option_string(_descriptor(logical_path), "family_path").path_join("committed-state.json")


func _layout_path() -> String:
	return _version_root.path_join("layout.json")


func _intent_path() -> String:
	return _version_root.path_join("upgrade.intent.json")


func _cursor_path() -> String:
	return _version_root.path_join("upgrade.cursor.json")


func _revision(logical_path: String) -> GFStorageRevisionResult:
	var incarnation: String = GFVariantData.get_option_string(_read_dictionary(_layout_path()), "storage_incarnation")
	return GFStorageRevisionStore.read_for_framework(
		GFStorageRevisionStore.make_context_for_framework(_descriptor(logical_path), incarnation)
	)


func _assert_runtime_blocked() -> void:
	assert_false(_old_runtime_accepts_version_root())
	var runtime_store: GFStorageFamilyStore = GFStorageFamilyStore.new()
	assert_true(runtime_store.configure_for_framework(_storage_root))
	assert_eq(runtime_store.ensure_layout_for_framework(), ERR_FILE_CORRUPT)
	assert_eq(runtime_store.get_revision_incarnation_for_framework(), "")
	assert_eq(
		GFVariantData.get_option_string_name(runtime_store.inspect_layout_for_reset_for_framework(), "status"),
		&"corrupt"
	)


func _assert_complete_layout() -> void:
	var store: GFStorageFamilyStore = GFStorageFamilyStore.new()
	assert_true(store.configure_for_framework(_storage_root))
	assert_eq(store.ensure_layout_for_framework(), OK)
	assert_true(GFUuid.is_valid(store.get_revision_incarnation_for_framework(), 4))
	var directory: DirAccess = DirAccess.open(_version_root)
	assert_not_null(directory)
	if directory == null:
		return
	assert_eq(directory.get_files(), PackedStringArray(["layout.json"]))


func _old_runtime_accepts_version_root() -> bool:
	# 冻结旧 runtime 的版本目录白名单与 schema 1 manifest 形状，不复制旧 runtime。
	var directory: DirAccess = DirAccess.open(_version_root)
	if directory == null:
		return false
	for leaf: String in directory.get_files():
		if leaf != "layout.json":
			return false
	for leaf: String in directory.get_directories():
		if leaf not in ["catalog", "families"]:
			return false
	if not FileAccess.file_exists(_layout_path()):
		return false
	var layout: Dictionary = _read_dictionary(_layout_path())
	return (
		layout.size() == 5
		and GFVariantData.get_option_string(layout, "schema") == "gf.storage.layout"
		and GFVariantData.to_exact_int(layout.get("schema_version"), -1) == 1
		and GFVariantData.get_option_string(layout, "path_profile") == "portable-ascii-v1"
		and GFVariantData.get_option_string(layout, "identity_algorithm") == "sha256-domain-nul-uuidv8-v1"
		and GFVariantData.get_option_string(layout, "private_namespace") == ".gf-storage"
	)


func _read_dictionary(path: String) -> Dictionary:
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(FileAccess.get_file_as_string(path)), OK)
	assert_true(parser.data is Dictionary)
	if parser.data is Dictionary:
		var record: Dictionary = parser.data
		return record
	return {}


func _write_text(path: String, value: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(value) != null
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return result


func _remove_owned_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for leaf: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(path.path_join(leaf))
		if remove_file_error != OK:
			return remove_file_error
	for leaf: String in directory.get_directories():
		var child_path: String = path.path_join(leaf)
		var remove_directory_error: Error = (
			DirAccess.remove_absolute(child_path) if directory.is_link(leaf) else _remove_owned_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	return DirAccess.remove_absolute(path)


# --- 内部类 ---

class FaultMigration extends GFStorageRevisionMigration:
	var fail_write_leaf: String = ""
	var truncate_failed_write: bool = false
	var fail_state_write_number: int = 0
	var fail_cursor_write_number: int = 0
	var fail_cursor_install_number: int = 0
	var fail_remove_leaf: String = ""
	var remove_before_failure: bool = false
	var corrupt_prior_state_path: String = ""
	var _state_write_count: int = 0
	var _cursor_write_count: int = 0
	var _cursor_install_count: int = 0

	func _write_upgrade_record(path: String, record: Dictionary) -> Error:
		var is_state: bool = path.get_file() == "committed-state.json"
		if is_state:
			_state_write_count += 1
		var is_cursor: bool = path.get_file() == "upgrade.cursor.pending.json"
		if is_cursor:
			_cursor_write_count += 1
		var should_fail: bool = (
			path.get_file() == fail_write_leaf
			or (is_state and _state_write_count == fail_state_write_number)
			or (is_cursor and _cursor_write_count == fail_cursor_write_number)
		)
		if should_fail and truncate_failed_write:
			var truncate_error: Error = _truncate_record(path)
			return ERR_FILE_CANT_WRITE if truncate_error == OK else truncate_error
		var result: Error = super._write_upgrade_record(path, record)
		if result != OK:
			return result
		if is_state and _state_write_count == 2 and not corrupt_prior_state_path.is_empty():
			var truncate_error: Error = _truncate_record(corrupt_prior_state_path)
			if truncate_error != OK:
				return truncate_error
		return ERR_FILE_CANT_WRITE if should_fail else OK

	func _remove_upgrade_file(path: String) -> Error:
		if path.get_file() != fail_remove_leaf:
			return super._remove_upgrade_file(path)
		if remove_before_failure:
			var remove_error: Error = super._remove_upgrade_file(path)
			if remove_error != OK:
				return remove_error
		return ERR_FILE_CANT_WRITE

	func _rename_upgrade_file(source_path: String, target_path: String) -> Error:
		if target_path.get_file() == "upgrade.cursor.json":
			_cursor_install_count += 1
			if _cursor_install_count == fail_cursor_install_number:
				return ERR_FILE_CANT_WRITE
		return super._rename_upgrade_file(source_path, target_path)

	func _truncate_record(path: String) -> Error:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		var _stored: bool = file.store_string("{") != null
		file.flush()
		var result: Error = file.get_error()
		file.close()
		return result
