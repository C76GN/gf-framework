# 测试显式 revision 布局与实际读取代次的公开合同。
extends GutTest


# --- 常量 ---

const _GF_TEST_DIRECTORY_LINK_FIXTURE = preload("res://tests/gf_core/support/gf_test_directory_link_fixture.gd")


# --- 私有变量 ---

var _storage: GFStorageUtility
var _save_dir_name: String = ""
var _storage_root: String = ""
var _resource_loader: _ReentrantResourceLoader


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_save_dir_name = "gf-storage-revisions-" + GFUuid.generate_v4()
	_storage_root = GFStorageFamilyStore.make_storage_root_path_for_framework(_save_dir_name)
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name


func after_each() -> void:
	if _resource_loader != null:
		ResourceLoader.remove_resource_format_loader(_resource_loader)
		_resource_loader = null
	_storage.dispose()
	_storage = null
	assert_true(_storage_root.begins_with("user://gf-storage-revisions-"))
	if _storage_root.begins_with("user://gf-storage-revisions-"):
		assert_eq(_remove_owned_tree(_storage_root), OK)
	_storage_root = ""
	_save_dir_name = ""


# --- 公共方法 ---

func test_revision_api_preserves_schema1_default_and_read_behavior() -> void:
	assert_eq(_storage.save_data("legacy.json", {"value": 1}), OK)
	var layout_path: String = _storage_root.path_join(".gf-storage/v1/layout.json")
	var layout_before: PackedByteArray = FileAccess.get_file_as_bytes(layout_path)
	var read_before: GFStorageReadResult = _storage.load_data("legacy.json")
	assert_true(read_before.ok)
	if not _require_revision_api():
		return
	var revision: GFStorageRevisionResult = _storage.query_committed_revision("legacy.json")
	assert_false(revision.is_successful())
	assert_eq(revision.get_error_code(), ERR_UNAVAILABLE)
	assert_eq(revision.get_revision(), "")
	assert_eq(FileAccess.get_file_as_bytes(layout_path), layout_before, "查询不能暗中迁移旧布局。")
	assert_eq(_storage.save_data("legacy.json", {"value": 2}), OK)
	var read_after: GFStorageReadResult = _storage.load_data("legacy.json")
	assert_true(read_after.ok)
	assert_eq(GFVariantData.get_option_int(read_after.payload, "value"), 2)
	assert_eq(read_after.to_dict().keys(), read_before.to_dict().keys(), "既有 read result schema 保持不变。")


func test_revision_api_explicit_creation_rotates_and_pairs_actual_data_read() -> void:
	if not _require_revision_api():
		return
	assert_eq(_storage.create_revision_storage(), OK)
	var absent: GFStorageRevisionResult = _storage.query_committed_revision("data.json")
	assert_eq(absent.get_error_code(), ERR_FILE_NOT_FOUND)
	assert_eq(_storage.save_data("data.json", {"value": 1}), OK)
	var first: GFStorageRevisionResult = _storage.query_committed_revision("data.json")
	var first_token: String = first.get_revision()
	assert_true(first.is_successful())
	assert_false(first_token.is_empty())
	assert_eq(_storage.save_data("data.json", {"value": 2}), OK)
	var second: GFStorageRevisionResult = _storage.query_committed_revision("data.json")
	var second_token: String = second.get_revision()
	assert_false(second_token.is_empty())
	assert_ne(second_token, first_token)
	var data_result: GFStorageReadResult = _storage.load_data("data.json")
	assert_true(data_result.ok)
	assert_eq(GFVariantData.get_option_int(data_result.payload, "value"), 2)
	var read_revision: GFStorageRevisionResult = data_result.get_committed_revision()
	assert_true(read_revision.is_successful())
	assert_eq(read_revision.get_revision(), second_token)


func test_equal_payload_rewrite_multiple_owners_delete_and_recreate_rotate_tokens() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("same.json", {"value": 1}), OK)
	var first: String = _token("same.json")
	_storage.dispose()
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	assert_eq(_token("same.json"), first, "新 owner 看到同一持久代次。")
	assert_eq(_storage.save_data("same.json", {"value": 1}), OK)
	var second: String = _token("same.json")
	assert_ne(second, first, "同字节也属于新提交。")
	assert_eq(_storage.delete_file("same.json"), OK)
	assert_eq(_storage.query_committed_revision("same.json").get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
	assert_eq(_storage.save_data("same.json", {"value": 1}), OK)
	assert_ne(_token("same.json"), second, "删除重建不能复用旧代次。")


func test_creation_retry_after_interruption_before_pending_write_uses_a_fresh_owner() -> void:
	var interrupted: _CreationBeforePendingFailureStore = _CreationBeforePendingFailureStore.new()
	_storage._family_store = interrupted
	assert_eq(_storage.create_revision_storage(), ERR_FILE_CANT_WRITE)
	assert_true(interrupted.reached_layout_publish, "故障必须发生在真实 ensure 已创建 v1、尚未写 pending 的窗口。")
	var version_root: String = _storage_root.path_join(".gf-storage/v1")
	assert_true(DirAccess.dir_exists_absolute(version_root))
	assert_eq(DirAccess.get_files_at(version_root), PackedStringArray())
	assert_eq(DirAccess.get_directories_at(version_root), PackedStringArray())
	_replace_storage(GFStorageUtility.new())
	assert_eq(_storage.create_revision_storage(), OK, "新 owner 应能显式续建未写入任何 layout 的空前缀。")
	assert_eq(_storage.save_data("resumed.json", {"value": 1}), OK)
	assert_true(_storage.query_committed_revision("resumed.json").is_successful())


func test_creation_retry_accepts_an_empty_private_root() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(_storage_root.path_join(".gf-storage")), OK)
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("resumed.json", {"value": 1}), OK)
	assert_true(_storage.query_committed_revision("resumed.json").is_successful())


func test_creation_retry_preserves_all_agreeing_complete_pending_incarnations() -> void:
	var version_root: String = _storage_root.path_join(".gf-storage/v1")
	assert_eq(DirAccess.make_dir_recursive_absolute(version_root), OK)
	var layout: Dictionary = GFStorageFamilyStore.make_revision_upgrade_layout_for_framework(GFUuid.generate_v4())
	var expected: PackedByteArray = JSON.stringify(layout, "\t").to_utf8_buffer()
	var pending_paths: Array[String] = []
	for _index: int in range(2):
		var pending_path: String = version_root.path_join("layout.json.pending-" + GFUuid.generate_v4())
		pending_paths.append(pending_path)
		assert_eq(_write_bytes(pending_path, expected), OK)
		if OS.get_name() == "Windows":
			assert_eq(FileAccess.set_hidden_attribute(pending_path, true), OK)
			assert_true(FileAccess.get_hidden_attribute(pending_path))
	assert_eq(_storage.create_revision_storage(), OK)
	var layout_path: String = version_root.path_join("layout.json")
	assert_true(FileAccess.file_exists(layout_path))
	if FileAccess.file_exists(layout_path):
		assert_eq(FileAccess.get_file_as_bytes(layout_path), expected, "续建必须复用已有 incarnation。")
	for pending_path: String in pending_paths:
		assert_false(FileAccess.file_exists(pending_path))
	assert_eq(_storage.save_data("resumed.json", {"value": 1}), OK)
	assert_true(_storage.query_committed_revision("resumed.json").is_successful())


func test_empty_creation_prefix_does_not_change_ordinary_schema1_initialization() -> void:
	for prefix: String in [".gf-storage", ".gf-storage/v1"]:
		assert_eq(DirAccess.make_dir_recursive_absolute(_storage_root.path_join(prefix)), OK)
		assert_eq(_storage.save_data("default.json", {"value": 1}), OK)
		assert_eq(_storage.query_committed_revision("default.json").get_status(), GFStorageRevisionResult.Status.UNSUPPORTED)
		assert_eq(_storage.create_revision_storage(), ERR_ALREADY_EXISTS)
		_replace_storage(GFStorageUtility.new())
		assert_eq(_remove_owned_tree(_storage_root), OK)


func test_creation_retry_rejects_established_layouts_without_changing_data_or_incarnation() -> void:
	for use_revisions: bool in [false, true]:
		if use_revisions:
			assert_eq(_storage.create_revision_storage(), OK)
		assert_eq(_storage.save_data("existing.json", {"value": 7}), OK)
		var layout_path: String = _storage_root.path_join(".gf-storage/v1/layout.json")
		var layout_before: PackedByteArray = FileAccess.get_file_as_bytes(layout_path)
		var revision_before: String = _storage.query_committed_revision("existing.json").get_revision()
		_replace_storage(GFStorageUtility.new())
		assert_eq(_storage.create_revision_storage(), ERR_ALREADY_EXISTS)
		assert_eq(FileAccess.get_file_as_bytes(layout_path), layout_before)
		assert_eq(_storage.query_committed_revision("existing.json").get_revision(), revision_before)
		assert_eq(GFVariantData.get_option_int(_storage.load_data("existing.json").payload, "value"), 7)
		_replace_storage(GFStorageUtility.new())
		assert_eq(_remove_owned_tree(_storage_root), OK)


func test_creation_retry_rejects_nonempty_or_mistyped_prefixes_without_removing_evidence() -> void:
	for entry: String in [
		".gf-storage", ".gf-storage/v1", ".gf-storage/unknown", ".gf-storage/.hidden",
		".gf-storage/v1/unknown", ".gf-storage/v1/.hidden",
		".gf-storage/v1/catalog/", ".gf-storage/v1/families/", ".gf-storage/v1/layout.json/",
	]:
		var entry_path: String = _storage_root.path_join(entry.trim_suffix("/"))
		var is_directory: bool = entry.ends_with("/")
		assert_eq(DirAccess.make_dir_recursive_absolute(entry_path if is_directory else entry_path.get_base_dir()), OK)
		if not is_directory:
			assert_eq(_write_text(entry_path, "unclaimed-evidence"), OK)
			if entry_path.get_file() == ".hidden" and OS.get_name() == "Windows":
				assert_eq(FileAccess.set_hidden_attribute(entry_path, true), OK)
				assert_true(FileAccess.get_hidden_attribute(entry_path))
		assert_ne(_storage.create_revision_storage(), OK, "不能接管 %s。" % entry)
		if is_directory:
			assert_true(DirAccess.dir_exists_absolute(entry_path))
			assert_eq(DirAccess.get_files_at(entry_path), PackedStringArray())
			assert_eq(DirAccess.get_directories_at(entry_path), PackedStringArray())
		else:
			assert_true(FileAccess.file_exists(entry_path))
			assert_eq(FileAccess.get_file_as_string(entry_path), "unclaimed-evidence")
		assert_false(FileAccess.file_exists(_storage_root.path_join(".gf-storage/v1/layout.json")))
		_replace_storage(GFStorageUtility.new())
		assert_eq(_remove_owned_tree(_storage_root), OK)


func test_creation_retry_preserves_every_pending_when_any_candidate_is_invalid_or_conflicting() -> void:
	for scenario: String in ["schema1", "malformed", "oversized", "extra-field", "conflicting", "invalid-leaf", "directory"]:
		var version_root: String = _storage_root.path_join(".gf-storage/v1")
		assert_eq(DirAccess.make_dir_recursive_absolute(version_root), OK)
		var layout: Dictionary = GFStorageFamilyStore.make_revision_upgrade_layout_for_framework(GFUuid.generate_v4())
		var first_path: String = version_root.path_join("layout.json.pending-00000000-0000-4000-8000-000000000001")
		var first_bytes: PackedByteArray = JSON.stringify(layout, "\t").to_utf8_buffer()
		assert_eq(_write_bytes(first_path, first_bytes), OK)
		var second_path: String = version_root.path_join("layout.json.pending-00000000-0000-4000-8000-000000000002")
		var second_text: String = ""
		match scenario:
			"schema1":
				var _incarnation_erased: bool = layout.erase("storage_incarnation")
				layout["schema_version"] = 1
			"malformed":
				second_text = "{"
			"oversized":
				second_text = "x".repeat(16 * 1024 + 1)
			"extra-field":
				layout["unknown"] = true
			"conflicting":
				layout["storage_incarnation"] = GFUuid.generate_v4()
			"invalid-leaf":
				second_path = version_root.path_join("layout.json.pending-not-a-uuid")
		if second_text.is_empty():
			second_text = JSON.stringify(layout, "\t")
		if scenario == "directory":
			assert_eq(DirAccess.make_dir_recursive_absolute(second_path), OK)
		else:
			assert_eq(_write_text(second_path, second_text), OK)
		assert_ne(_storage.create_revision_storage(), OK, scenario)
		assert_false(FileAccess.file_exists(version_root.path_join("layout.json")))
		assert_eq(FileAccess.get_file_as_bytes(first_path), first_bytes, "不能先发布首条有效 pending 再处理后续冲突。")
		if scenario == "directory":
			assert_true(DirAccess.dir_exists_absolute(second_path))
		else:
			assert_eq(FileAccess.get_file_as_string(second_path), second_text)
		assert_false(DirAccess.dir_exists_absolute(version_root.path_join("catalog")))
		assert_false(DirAccess.dir_exists_absolute(version_root.path_join("families")))
		_replace_storage(GFStorageUtility.new())
		assert_eq(_remove_owned_tree(_storage_root), OK)


func test_creation_retry_fails_closed_when_pending_inventory_exceeds_its_bound() -> void:
	var version_root: String = _storage_root.path_join(".gf-storage/v1")
	assert_eq(DirAccess.make_dir_recursive_absolute(version_root), OK)
	var layout: Dictionary = GFStorageFamilyStore.make_revision_upgrade_layout_for_framework(GFUuid.generate_v4())
	var expected: PackedByteArray = JSON.stringify(layout, "\t").to_utf8_buffer()
	var pending_paths: Array[String] = []
	for _index: int in range(65):
		var pending_path: String = version_root.path_join("layout.json.pending-" + GFUuid.generate_v4())
		pending_paths.append(pending_path)
		assert_eq(_write_bytes(pending_path, expected), OK)
	assert_eq(_storage.create_revision_storage(), ERR_OUT_OF_MEMORY)
	assert_false(FileAccess.file_exists(version_root.path_join("layout.json")))
	assert_eq(DirAccess.get_files_at(version_root).size(), 65)
	for pending_path: String in pending_paths:
		assert_eq(FileAccess.get_file_as_bytes(pending_path), expected)


func test_creation_retry_rejects_links_at_every_ancestry_and_pending_boundary() -> void:
	for scenario: String in ["ancestor", "storage", "private", "version", "pending"]:
		var target_root: String = _storage_root.path_join("target")
		assert_eq(DirAccess.make_dir_recursive_absolute(target_root), OK)
		var sentinel_path: String = target_root.path_join("sentinel.txt")
		assert_eq(_write_text(sentinel_path, "preserved"), OK)
		var relative_link: String = ""
		match scenario:
			"ancestor", "storage":
				relative_link = "linked"
				_storage.save_dir_name = _save_dir_name + "/linked" + ("/child" if scenario == "ancestor" else "")
			"private":
				relative_link = ".gf-storage"
			"version":
				relative_link = ".gf-storage/v1"
			"pending":
				relative_link = ".gf-storage/v1/layout.json.pending-" + GFUuid.generate_v4()
		var link_path: String = _storage_root.path_join(relative_link)
		assert_eq(DirAccess.make_dir_recursive_absolute(link_path.get_base_dir()), OK)
		var link_error: Error = _GF_TEST_DIRECTORY_LINK_FIXTURE.create(
			ProjectSettings.globalize_path(target_root), ProjectSettings.globalize_path(link_path)
		)
		assert_eq(link_error, OK, "受支持平台必须能建立 symlink 或 directory junction 夹具。")
		if link_error == OK:
			assert_eq(_storage.create_revision_storage(), ERR_FILE_CORRUPT, scenario)
			var parent: DirAccess = DirAccess.open(link_path.get_base_dir())
			assert_true(parent != null and parent.is_link(link_path.get_file()))
			assert_eq(FileAccess.get_file_as_string(sentinel_path), "preserved")
			assert_eq(DirAccess.get_files_at(target_root), PackedStringArray(["sentinel.txt"]))
			assert_eq(DirAccess.get_directories_at(target_root), PackedStringArray())
			assert_eq(DirAccess.remove_absolute(link_path), OK)
		_replace_storage(GFStorageUtility.new())
		assert_eq(_remove_owned_tree(_storage_root), OK)


func test_completed_creation_pending_recovers_the_same_explicit_schema2_incarnation() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	var layout_path: String = _storage_root.path_join(".gf-storage/v1/layout.json")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(layout_path)
	var pending_path: String = layout_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(DirAccess.rename_absolute(layout_path, pending_path), OK)
	_storage.dispose()
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	assert_eq(_storage.query_committed_revision("pending.json").get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
	assert_eq(FileAccess.get_file_as_bytes(layout_path), before)
	assert_false(FileAccess.file_exists(pending_path))
	assert_eq(_storage.save_data("pending.json", {"value": 1}), OK)
	assert_false(_token("pending.json").is_empty())


func test_existing_schema1_is_not_upgraded_by_a_foreign_schema2_pending_manifest() -> void:
	assert_eq(_storage.save_data("legacy.json", {"value": 1}), OK)
	var layout_path: String = _storage_root.path_join(".gf-storage/v1/layout.json")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(layout_path)
	var pending_path: String = layout_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(_write_text(pending_path, JSON.stringify(
		GFStorageFamilyStore.make_revision_upgrade_layout_for_framework(GFUuid.generate_v4())
	)), OK)
	assert_eq(_storage.query_committed_revision("legacy.json").get_status(), GFStorageRevisionResult.Status.CORRUPT)
	assert_eq(FileAccess.get_file_as_bytes(layout_path), before)
	assert_true(FileAccess.file_exists(pending_path))


func test_state_publish_failure_preserves_evidence_and_same_owner_query_recovers() -> void:
	var failing: _RevisionWriteFailureStorage = _RevisionWriteFailureStorage.new()
	_replace_storage(failing)
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("state.json", {"value": 1}), OK)
	var old_token: String = _token("state.json")
	failing.fail_state_write = true
	assert_eq(_storage.save_data("state.json", {"value": 2}), ERR_CANT_CREATE)
	var descriptor: Dictionary = _descriptor("state.json")
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "transaction_commit_path")))
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "transaction_path")))
	var failed: GFStorageRevisionResult = _storage.query_committed_revision("state.json")
	assert_false(failed.is_successful())
	assert_eq(failed.get_revision(), "")
	failing.fail_state_write = false
	var recovered: String = _token("state.json")
	assert_ne(recovered, old_token)
	var read: GFStorageReadResult = _storage.load_data("state.json")
	assert_eq(GFVariantData.get_option_int(read.payload, "value"), 2)
	assert_eq(read.get_committed_revision().get_revision(), recovered)
	_assert_no_transaction_evidence(["state.json"])


func test_corrupt_state_without_commit_evidence_is_never_replaced_by_a_guess() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("corrupt.json", {"value": 1}), OK)
	var state_path: String = _state_path("corrupt.json")
	assert_eq(_write_text(state_path, "{"), OK)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(state_path)
	var revision: GFStorageRevisionResult = _storage.query_committed_revision("corrupt.json")
	assert_eq(revision.get_status(), GFStorageRevisionResult.Status.CORRUPT)
	assert_eq(FileAccess.get_file_as_bytes(state_path), before)
	assert_eq(_storage.save_data("corrupt.json", {"value": 2}), ERR_FILE_CORRUPT)
	assert_eq(FileAccess.get_file_as_bytes(state_path), before)


func test_partial_commit_rolls_back_payload_and_preserves_old_revision_for_entire_group() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	var names: Array[String] = ["a.json", "b.json"]
	assert_eq(_storage.save_data_group({"a.json": {"value": 1}, "b.json": {"value": 1}}), OK)
	var old_tokens: Array[String] = [_token("a.json"), _token("b.json")]
	_stage_fully_committed_group(names, 2)
	assert_eq(DirAccess.remove_absolute(GFVariantData.get_option_string(_descriptor("b.json"), "transaction_commit_path")), OK)
	for index: int in range(names.size()):
		assert_eq(_token(names[index]), old_tokens[index])
		assert_eq(GFVariantData.get_option_int(_storage.load_data(names[index]).payload, "value"), 1)
	_assert_no_transaction_evidence(names)


func test_group_publication_interruption_and_partial_cleanup_reuse_the_committed_token() -> void:
	var failing: _RevisionWriteFailureStorage = _RevisionWriteFailureStorage.new()
	_replace_storage(failing)
	assert_eq(_storage.create_revision_storage(), OK)
	var names: Array[String] = ["a.json", "b.json"]
	assert_eq(_storage.save_data_group({"a.json": {"value": 1}, "b.json": {"value": 1}}), OK)
	var old_states: Array[PackedByteArray] = [FileAccess.get_file_as_bytes(_state_path("a.json")), FileAccess.get_file_as_bytes(_state_path("b.json"))]
	_stage_fully_committed_group(names, 2)
	var commit_path: String = GFVariantData.get_option_string(_descriptor("b.json"), "transaction_commit_path")
	var retained_commit: PackedByteArray = FileAccess.get_file_as_bytes(commit_path)
	failing.fail_state_path = _state_path("b.json")
	assert_false(_storage.query_committed_revision("a.json").is_successful())
	assert_ne(FileAccess.get_file_as_bytes(_state_path("a.json")), old_states[0])
	assert_true(FileAccess.file_exists(commit_path))
	failing.fail_state_path = ""
	var tokens: Array[String] = [_token("a.json"), _token("b.json")]
	assert_eq(_write_bytes(commit_path, retained_commit), OK, "复现commit清理到一半后重启。")
	_storage.dispose()
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	assert_eq(_token("b.json"), tokens[1])
	assert_eq(_token("a.json"), tokens[0])
	_assert_no_transaction_evidence(names)
	assert_eq(_write_bytes(commit_path, retained_commit), OK)
	assert_eq(_write_bytes(_state_path("a.json"), old_states[0]), OK)
	assert_eq(_storage.query_committed_revision("b.json").get_status(), GFStorageRevisionResult.Status.CORRUPT,
		"仅有剩余commit且一个state不匹配，不能推测已完成全组发布。")
	assert_true(FileAccess.file_exists(commit_path))


func test_delete_refuses_unpublished_commit_without_destroying_rollback_evidence() -> void:
	var failing: _RevisionWriteFailureStorage = _RevisionWriteFailureStorage.new()
	_replace_storage(failing)
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("keep.json", {"value": 1}), OK)
	failing.fail_state_write = true
	assert_eq(_storage.save_data("keep.json", {"value": 2}), ERR_CANT_CREATE)
	var descriptor: Dictionary = _descriptor("keep.json")
	var marker_path: String = GFVariantData.get_option_string(descriptor, "transaction_commit_path")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(marker_path)
	assert_eq(_storage.delete_file("keep.json"), ERR_BUSY)
	assert_eq(FileAccess.get_file_as_bytes(marker_path), before)
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "backup_path")))
	failing.fail_state_write = false
	assert_false(_token("keep.json").is_empty())
	assert_eq(_storage.delete_file("keep.json"), OK)


func test_json_async_read_pairs_actual_source_and_duplicate_preserves_but_dictionary_drops_token() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("async.json", {"value": 1}), OK)
	var first: String = _token("async.json")
	var save: GFStorageAsyncOperation = _storage.save_data_request_async("async.json", {"value": 2})
	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async("async.json")
	_storage.wait_for_async_tasks()
	assert_true(save.is_completed())
	assert_true(load_operation.is_completed())
	var read: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_true(read.ok)
	assert_eq(GFVariantData.get_option_int(read.payload, "value"), 2)
	var actual: String = read.get_committed_revision().get_revision()
	assert_ne(actual, first, "不能把查询A之后读到的B绑定A。")
	assert_eq(actual, _token("async.json"))
	assert_eq(read.duplicate_result().get_committed_revision().get_revision(), actual)
	assert_eq(GFStorageReadResult.from_dict(read.to_dict()).get_committed_revision().get_status(), GFStorageRevisionResult.Status.UNSUPPORTED)
	assert_eq(read.to_dict().size(), 11)


func test_sync_and_async_migrations_keep_read_token_when_signal_persists_a_new_commit() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	_storage.save_version = 1
	assert_eq(_storage.save_data("sync-migrate.json", {"value": 1}), OK)
	assert_eq(_storage.save_data("async-migrate.json", {"value": 1}), OK)
	var sync_source: String = _token("sync-migrate.json")
	var async_source: String = _token("async-migrate.json")
	_storage.save_version = 2
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["value"] = 2
		return data
	))
	var persisted_errors: Array[Error] = []
	var connect_error: int = _storage.data_migrated.connect(func(file_name: String, _from: int, _to: int) -> void:
		persisted_errors.append(_storage.save_data(file_name, {"value": 2}))
	)
	assert_eq(connect_error, OK)
	var sync_read: GFStorageReadResult = _storage.load_data("sync-migrate.json")
	assert_true(sync_read.ok)
	assert_true(sync_read.migrated)
	assert_eq(GFVariantData.get_option_int(sync_read.payload, "value"), 2)
	assert_eq(sync_read.get_committed_revision().get_revision(), sync_source)
	assert_ne(_token("sync-migrate.json"), sync_source, "迁移信号保存的新提交不能替代实际读取来源。")
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async("async-migrate.json")
	_storage.wait_for_async_tasks()
	assert_true(operation.is_completed())
	var async_read: GFStorageReadResult = operation.get_result().get_read_result()
	assert_true(async_read.ok)
	assert_true(async_read.migrated)
	assert_eq(GFVariantData.get_option_int(async_read.payload, "value"), 2)
	assert_eq(async_read.get_committed_revision().get_revision(), async_source)
	assert_ne(_token("async-migrate.json"), async_source, "异步完成后的迁移保存不能改变已捕获的来源。")
	assert_eq(persisted_errors, [OK, OK])


func test_resource_read_has_same_source_revision_and_retains_opt_in_policy() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	var source: Gradient = Gradient.new()
	source.set_color(0, Color.RED)
	assert_eq(_storage.save_resource("gradient.tres", source), OK)
	assert_false(_storage.load_resource_with_revision("gradient.tres", "Gradient").is_successful())
	_storage.allow_resource_loads = true
	_storage.allowed_resource_load_type_hints = PackedStringArray(["Gradient"])
	assert_eq(_storage.load_resource_with_revision("no-extension", "Gradient").get_error_code(), ERR_INVALID_PARAMETER)
	var result: GFStorageResourceReadResult = _storage.load_resource_with_revision("gradient.tres", "Gradient")
	assert_true(result.is_successful(), "Resource配对应成功：%s" % result.get_error_code())
	if not result.is_successful():
		return
	assert_true(result.get_resource() is Gradient)
	assert_eq(result.get_committed_revision().get_revision(), _token("gradient.tres"))
	var first_token: String = result.get_committed_revision().get_revision()
	source.set_color(0, Color.BLUE)
	assert_eq(_storage.save_resource("gradient.tres", source), OK)
	var second: GFStorageResourceReadResult = _storage.load_resource_with_revision("gradient.tres", "Gradient")
	assert_true(second.is_successful())
	if second.get_resource() is Gradient:
		var gradient: Gradient = second.get_resource()
		assert_eq(gradient.get_color(0), Color.BLUE, "CACHE_MODE_IGNORE必须读取新Resource。")
	assert_ne(second.get_committed_revision().get_revision(), first_token)


func test_resource_initialization_reentry_cannot_change_or_read_guarded_family() -> void:
	_prepare_resource_loader()
	var before: String = _token("guard.tres")
	var operations: Dictionary = {}
	_resource_loader.on_load = func() -> void:
		operations["save"] = _storage.save_data("guard.tres", {"unexpected": true})
		operations["group"] = _storage.save_data_group({"guard.tres": {"unexpected": true}})
		operations["delete"] = _storage.delete_file("guard.tres")
		operations["query"] = _storage.query_committed_revision("guard.tres").get_error_code()
		operations["read"] = _storage.load_resource_with_revision("guard.tres", "Gradient").get_error_code()
	var result: GFStorageResourceReadResult = _storage.load_resource_with_revision("guard.tres", "Gradient")
	assert_eq(_resource_loader.load_count, 1)
	assert_true(result.is_successful())
	for key: String in ["save", "group", "delete", "query", "read"]:
		assert_eq(GFVariantData.get_option_int(operations, key, ERR_BUG), ERR_BUSY, key)
	assert_eq(result.get_committed_revision().get_revision(), before)
	assert_eq(_token("guard.tres"), before)


func test_resource_initialization_queued_write_returns_busy_without_a_cacheable_pair() -> void:
	_prepare_resource_loader()
	var queued: Array[GFStorageAsyncOperation] = []
	_resource_loader.on_load = func() -> void:
		queued.append(_storage.save_data_request_async("guard.tres", {"value": 7}))
	var result: GFStorageResourceReadResult = _storage.load_resource_with_revision("guard.tres", "Gradient")
	assert_eq(_resource_loader.load_count, 1)
	assert_eq(result.get_error_code(), ERR_BUSY)
	assert_null(result.get_resource())
	assert_null(result.get_committed_revision())
	_storage.wait_for_async_tasks()
	assert_eq(queued.size(), 1)
	assert_eq(queued[0].get_result().get_error_code(), OK)
	assert_eq(GFVariantData.get_option_int(_storage.load_data("guard.tres").payload, "value"), 7)


func test_resource_initialization_dispose_and_reactivate_invalidates_the_read() -> void:
	_prepare_resource_loader()
	_resource_loader.on_load = func() -> void:
		_storage.dispose()
		var activation: GFAsyncCompletion = _storage.begin_activation(null)
		assert_true(activation.is_completed())
	var result: GFStorageResourceReadResult = _storage.load_resource_with_revision("guard.tres", "Gradient")
	assert_eq(_resource_loader.load_count, 1)
	assert_eq(result.get_error_code(), ERR_UNAVAILABLE)
	assert_null(result.get_resource())
	assert_null(result.get_committed_revision())


func test_schema2_reset_retires_state_and_invalidates_observation_when_only_state_changes() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("reset.json", {"value": 1}), OK)
	var first: String = _token("reset.json")
	assert_eq(_write_text(GFVariantData.get_option_string(_descriptor("reset.json"), "payload_path"), ""), OK)
	var observed: GFStorageReadResult = _storage.load_data("reset.json")
	assert_eq(observed.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	var stale: GFStorageFamilyResetAuthorization = _storage.create_family_reset_authorization("reset.json", observed)
	assert_true(stale.is_available())
	var old_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("reset.json"))
	assert_eq(_write_text(_state_path("reset.json"), "{"), OK)
	assert_true(_storage.create_family_reset_authorization("reset.json", observed).is_stale())
	assert_false(_storage.reset_file_family("reset.json", stale).is_successful())
	assert_eq(_write_bytes(_state_path("reset.json"), old_state), OK)
	observed = _storage.load_data("reset.json")
	var authorization: GFStorageFamilyResetAuthorization = _storage.create_family_reset_authorization("reset.json", observed)
	var reset: GFStorageFamilyResetResult = _storage.reset_file_family("reset.json", authorization)
	assert_true(reset.is_successful())
	assert_false(FileAccess.file_exists(_state_path("reset.json")), "state必须随整个family退休，不能进入新claim。")
	assert_eq(_storage.query_committed_revision("reset.json").get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
	assert_eq(_storage.save_data("reset.json", {"value": 1}), OK)
	assert_ne(_token("reset.json"), first)


func test_schema2_reset_catalog_retirement_failure_restores_exact_state_and_payload_bytes() -> void:
	var faulty: _RevisionResetFailureStorage = _RevisionResetFailureStorage.new()
	_replace_storage(faulty)
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("reset-fault.json", {"value": 1}), OK)
	var state_before: PackedByteArray = FileAccess.get_file_as_bytes(_state_path("reset-fault.json"))
	var payload_path: String = GFVariantData.get_option_string(_descriptor("reset-fault.json"), "payload_path")
	assert_eq(_write_text(payload_path, ""), OK)
	var observed: GFStorageReadResult = _storage.load_data("reset-fault.json")
	var authorization: GFStorageFamilyResetAuthorization = _storage.create_family_reset_authorization("reset-fault.json", observed)
	faulty.fail_stage = &"retire"
	var result: GFStorageFamilyResetResult = _storage.reset_file_family("reset-fault.json", authorization)
	assert_eq(result.get_error_code(), ERR_FILE_CANT_WRITE)
	assert_eq(result.get_failed_phase(), GFStorageFamilyResetResult.Phase.RETIRE)
	assert_eq(FileAccess.get_file_as_bytes(_state_path("reset-fault.json")), state_before)
	assert_eq(FileAccess.get_file_as_bytes(payload_path), PackedByteArray())
	faulty.fail_stage = &""
	assert_eq(_storage.query_committed_revision("reset-fault.json").get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
	assert_false(FileAccess.file_exists(_state_path("reset-fault.json")))


func test_schema2_reset_recreate_and_cleanup_failures_keep_old_state_in_retirement_only() -> void:
	for phase: StringName in [&"recreate", &"cleanup"]:
		var faulty: _RevisionResetFailureStorage = _RevisionResetFailureStorage.new()
		_replace_storage(faulty)
		if phase == &"recreate":
			assert_eq(_storage.create_revision_storage(), OK)
		var file_name: String = "reset-%s.json" % phase
		assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
		var old_token: String = _token(file_name)
		var old_state: PackedByteArray = FileAccess.get_file_as_bytes(_state_path(file_name))
		assert_eq(_write_text(GFVariantData.get_option_string(_descriptor(file_name), "payload_path"), ""), OK)
		var observed: GFStorageReadResult = _storage.load_data(file_name)
		var authorization: GFStorageFamilyResetAuthorization = _storage.create_family_reset_authorization(file_name, observed)
		faulty.fail_stage = phase
		var result: GFStorageFamilyResetResult = _storage.reset_file_family(file_name, authorization)
		assert_eq(result.get_error_code(), ERR_FILE_CANT_WRITE)
		assert_eq(result.get_retired_member_count(), 2)
		assert_gt(result.get_remaining_evidence_count(), 0)
		assert_false(FileAccess.file_exists(_state_path(file_name)))
		assert_eq(FileAccess.get_file_as_bytes(faulty.retired_state_path), old_state)
		faulty.fail_stage = &""
		assert_eq(_storage.query_committed_revision(file_name).get_status(), GFStorageRevisionResult.Status.NOT_FOUND)
		assert_false(FileAccess.file_exists(faulty.retired_state_path))
		assert_eq(_storage.save_data(file_name, {"value": 1}), OK)
		assert_ne(_token(file_name), old_token)


# --- 私有/辅助方法 ---

func _prepare_resource_loader() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_resource("guard.tres", Gradient.new()), OK)
	_storage.allow_resource_loads = true
	_storage.allowed_resource_load_type_hints = PackedStringArray(["Gradient"])
	_resource_loader = _ReentrantResourceLoader.new()
	_resource_loader.target_path = GFVariantData.get_option_string(_descriptor("guard.tres"), "payload_path")
	ResourceLoader.add_resource_format_loader(_resource_loader, true)


func _token(file_name: String) -> String:
	var result: GFStorageRevisionResult = _storage.query_committed_revision(file_name)
	assert_true(result.is_successful(), "revision查询必须成功：%s，%s" % [file_name, result.get_error_code()])
	return result.get_revision()


func _replace_storage(storage: GFStorageUtility) -> void:
	_storage.dispose()
	_storage = storage
	_storage.save_dir_name = _save_dir_name


func _descriptor(file_name: String) -> Dictionary:
	return GFStorageFamilyStore.make_family_descriptor_for_framework(_storage_root, file_name)


func _state_path(file_name: String) -> String:
	return GFVariantData.get_option_string(_descriptor(file_name), "family_path").path_join("committed-state.json")


func _stage_fully_committed_group(file_names: Array[String], value: int) -> void:
	assert_eq(_storage._write_transaction_markers(file_names, false), OK)
	for file_name: String in file_names:
		assert_eq(_storage._write_json(_storage._get_temp_filename(file_name), {"value": value}), OK)
		var descriptor: Dictionary = _descriptor(file_name)
		assert_eq(DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "payload_path"),
			GFVariantData.get_option_string(descriptor, "backup_path")
		), OK)
		assert_eq(DirAccess.rename_absolute(
			GFVariantData.get_option_string(descriptor, "candidate_path"),
			GFVariantData.get_option_string(descriptor, "payload_path")
		), OK)
	assert_eq(_storage._write_transaction_markers(file_names, true), OK)


func _assert_no_transaction_evidence(file_names: Array[String]) -> void:
	for file_name: String in file_names:
		for path_key: String in ["transaction_path", "transaction_pending_path", "transaction_commit_path", "transaction_commit_pending_path", "backup_path", "candidate_path"]:
			assert_false(FileAccess.file_exists(GFVariantData.get_option_string(_descriptor(file_name), path_key)))


func _write_text(path: String, value: String) -> Error:
	return _write_bytes(path, value.to_utf8_buffer())


func _write_bytes(path: String, value: PackedByteArray) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _written: bool = file.store_buffer(value) != null
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error


func _require_revision_api() -> bool:
	for method_name: String in [
		"create_revision_storage", "query_committed_revision",
		"load_resource_with_revision",
	]:
		assert_true(_storage.has_method(method_name), "Storage 缺少显式 revision API：%s" % method_name)
		if not _storage.has_method(method_name):
			return false
	var read_result: GFStorageReadResult = GFStorageReadResult.new()
	assert_true(read_result.has_method("get_committed_revision"), "JSON 实际读取结果必须携带捕获的 revision。")
	return read_result.has_method("get_committed_revision")


func _remove_owned_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_file_error != OK:
			return remove_file_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_directory_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	return DirAccess.remove_absolute(path)


# --- 内部类 ---

class _CreationBeforePendingFailureStore extends GFStorageFamilyStore:
	var reached_layout_publish: bool = false

	func _publish_json_if_absent(path: String, data: Dictionary) -> Error:
		if path.ends_with("/layout.json"):
			reached_layout_publish = true
			return ERR_FILE_CANT_WRITE
		return super._publish_json_if_absent(path, data)


class _RevisionWriteFailureStorage extends GFStorageUtility:
	var fail_state_write: bool = false
	var fail_state_path: String = ""

	func _write_plain_json_absolute(path: String, data: Dictionary) -> Error:
		if path.ends_with("/committed-state.json") and (fail_state_write or path == fail_state_path):
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.close()
			return ERR_CANT_CREATE
		return super._write_plain_json_absolute(path, data)


class _ReentrantResourceLoader extends ResourceFormatLoader:
	var target_path: String = ""
	var on_load: Callable
	var load_count: int = 0

	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["tres"])

	func _handles_type(type: StringName) -> bool:
		return type == &"Gradient"

	func _get_resource_type(path: String) -> String:
		return "Gradient" if path == target_path else ""

	func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		if path != target_path:
			return ERR_FILE_UNRECOGNIZED
		load_count += 1
		if on_load.is_valid():
			on_load.call()
		return Gradient.new()


class _RevisionResetFailureStorage extends GFStorageUtility:
	var fail_stage: StringName = &""
	var retired_state_path: String = ""

	func move_reset_family_member_for_framework(member_kind: StringName, source_path: String, target_path: String) -> Error:
		if fail_stage == &"retire" and member_kind == &"catalog":
			return ERR_FILE_CANT_WRITE
		if member_kind == &"family_container" and retired_state_path.is_empty():
			retired_state_path = target_path.path_join("committed-state.json")
		return super.move_reset_family_member_for_framework(member_kind, source_path, target_path)

	func claim_reset_family_for_framework(family_store: GFStorageFamilyStore, descriptor: Dictionary) -> Error:
		var error: Error = super.claim_reset_family_for_framework(family_store, descriptor)
		if error != OK or fail_stage != &"recreate":
			return error
		var removed: Error = DirAccess.remove_absolute(GFVariantData.get_option_string(descriptor, "catalog_path"))
		return ERR_FILE_CANT_WRITE if removed == OK else removed

	func remove_reset_family_member_for_framework(member_kind: StringName, path: String) -> Error:
		if fail_stage == &"cleanup" and member_kind == &"family_container":
			return ERR_FILE_CANT_WRITE
		return super.remove_reset_family_member_for_framework(member_kind, path)
