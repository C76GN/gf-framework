## 测试 GFStorageFamilyStore 的 portable identity、私有布局与 catalog fail-closed 语义。
extends GutTest


# --- 常量 ---

const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)


# --- 私有变量 ---

var _save_dir_name: String = ""
var _storage_root_path: String = ""
var _store: RefCounted


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_save_dir_name = "gf-family-store-" + GFUuid.generate_v4()
	_storage_root_path = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		_save_dir_name
	)
	_store = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	assert_true(
		GFVariantData.to_bool(
			_store.call("configure_for_framework", _storage_root_path)
		),
		"测试 family store 应绑定独立 portable user:// root。"
	)


func after_each() -> void:
	var cleanup_error: Error = _remove_tree(_storage_root_path)
	assert_eq(cleanup_error, OK, "测试结束后应完整删除独立 Storage root。")
	_store = null
	_storage_root_path = ""
	_save_dir_name = ""


# --- 公共方法 ---

func test_portable_logical_file_path_accepts_exact_boundaries() -> void:
	var sixteen_segments: String = "/".join(PackedStringArray([
		"a", "b", "c", "d", "e", "f", "g", "h",
		"i", "j", "k", "l", "m", "n", "o", "p",
	]))
	var sixty_four_byte_segment: String = "a".repeat(64)
	var two_hundred_fifty_five_byte_path: String = "%s/%s/%s/%s" % [
		"a".repeat(64),
		"b".repeat(64),
		"c".repeat(64),
		"d".repeat(60),
	]

	for logical_path: String in [
		"a",
		"a.json",
		"nested/file-name_1.tmp",
		"multiple.dots.are-valid.txn",
		sixteen_segments,
		sixty_four_byte_segment,
		two_hundred_fifty_five_byte_path,
	]:
		assert_true(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_logical_file_path_for_framework(
				logical_path
			),
			"portable file identity 应原样接受合法边界：%s" % logical_path
		)


func test_portable_logical_file_path_rejects_rewriting_and_platform_aliases() -> void:
	var invalid_paths: Array[String] = [
		"",
		"Upper.json",
		"中文.json",
		"nested\\file.json",
		"/leading.json",
		"trailing.json/",
		"double//slash.json",
		"./file.json",
		"nested/../file.json",
		".hidden",
		"trailing.",
		"_leading.json",
		"trailing_",
		"-leading.json",
		"trailing-",
		"stream:alternate",
		"con",
		"con.json",
		"prn.data",
		"aux",
		"nul.save",
		"com1.json",
		"com9.slot",
		"lpt1",
		"lpt9.backup",
		"a".repeat(65),
		"a".repeat(256),
		"/".join(PackedStringArray([
			"a", "b", "c", "d", "e", "f", "g", "h", "i",
			"j", "k", "l", "m", "n", "o", "p", "q",
		])),
	]

	for logical_path: String in invalid_paths:
		assert_false(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_logical_file_path_for_framework(
				logical_path
			),
			"portable file identity 不得改写或接受平台别名：%s" % logical_path
		)


func test_directory_and_extension_selectors_have_distinct_strict_grammars() -> void:
	for directory_name: String in ["", "a", "nested/slot-data"]:
		assert_true(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_logical_directory_path_for_framework(
				directory_name
			),
			"空串仅在 directory selector 表示根，其他目录必须保持 canonical。"
		)
	for directory_name: String in [".", "..", "Nested", "nested/", "nested//child"]:
		assert_false(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_logical_directory_path_for_framework(
				directory_name
			),
			"directory selector 不得折叠、改写或大小写归一化。"
		)

	for extension_filter: String in ["", "j", "json", "save_data", "save-data", "a".repeat(16)]:
		assert_true(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_extension_filter_for_framework(
				extension_filter
			),
			"canonical extension token 应被接受：%s" % extension_filter
		)
	for extension_filter: String in [
		".json", "JSON", "-json", "_json", "json.tmp", "中文", "a".repeat(17),
	]:
		assert_false(
			_GF_STORAGE_FAMILY_STORE_SCRIPT.is_valid_extension_filter_for_framework(
				extension_filter
			),
			"extension filter 不得被隐式 trim、去点或转小写：%s" % extension_filter
		)


func test_descriptor_uses_exact_domain_hash_and_uuid_v8_bits() -> void:
	var logical_path: String = "slots/player.json"
	var descriptor: Dictionary = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		logical_path
	)
	var expected_digest: String = _make_expected_identity_digest(logical_path)
	var expected_family_id: String = _make_expected_uuid_v8(expected_digest)

	assert_false(descriptor.is_empty())
	assert_eq(GFVariantData.get_option_string(descriptor, "logical_path"), logical_path)
	assert_eq(
		GFVariantData.get_option_string(descriptor, "logical_sha256"),
		expected_digest,
		"identity hash 必须精确绑定 domain、NUL 分隔符与原样 logical path。"
	)
	assert_eq(
		GFVariantData.get_option_string(descriptor, "family_id"),
		expected_family_id,
		"UUID v8 只应覆盖 version/variant 位并保留其余 digest 位。"
	)
	var family_id: String = GFVariantData.get_option_string(descriptor, "family_id")
	assert_eq(family_id.substr(14, 1), "8")
	assert_true("89ab".contains(family_id.substr(19, 1)))
	assert_true(
		GFVariantData.get_option_string(descriptor, "catalog_relative_path").begins_with(
			".gf-storage/v1/catalog/%s/%s/" % [
				expected_digest.substr(0, 2),
				expected_digest.substr(2, 2),
			]
		)
	)
	assert_true(
		GFVariantData.get_option_string(descriptor, "family_relative_path").begins_with(
			".gf-storage/v1/families/"
		)
	)


func test_descriptor_is_deterministic_and_suffix_names_own_distinct_families() -> void:
	var logical_paths: Array[String] = [
		"family.json",
		"family.json.tmp",
		"family.json.bak",
		"family.json.txn",
	]
	var family_ids: Dictionary = {}
	var catalog_paths: Dictionary = {}
	var family_paths: Dictionary = {}

	for logical_path: String in logical_paths:
		var first: Dictionary = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
			_storage_root_path,
			logical_path
		)
		var second: Dictionary = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
			_storage_root_path,
			logical_path
		)
		assert_eq(first, second, "descriptor 必须是无磁盘副作用的确定性纯计算。")
		family_ids[GFVariantData.get_option_string(first, "family_id")] = true
		catalog_paths[GFVariantData.get_option_string(first, "catalog_path")] = true
		family_paths[GFVariantData.get_option_string(first, "family_path")] = true

	assert_eq(family_ids.size(), logical_paths.size(), "sidecar 样式名称必须拥有独立 UUID family。")
	assert_eq(catalog_paths.size(), logical_paths.size())
	assert_eq(family_paths.size(), logical_paths.size())
	assert_false(DirAccess.dir_exists_absolute(_storage_root_path), "纯 descriptor 计算不得创建 root。")


func test_layout_and_family_claim_are_idempotent() -> void:
	var descriptor: Dictionary = _descriptor("slots/idempotent.json")

	assert_eq(_ensure_layout(), OK)
	assert_eq(_ensure_layout(), OK)
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_validate_family(descriptor), OK)
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")))
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "owner_path")))
	assert_false(
		FileAccess.file_exists(_storage_root_path.path_join("slots/idempotent.json")),
		"logical path 不得成为 root 下的可见物理 payload。"
	)


func test_exact_layout_and_catalog_pending_files_are_promoted_idempotently() -> void:
	assert_eq(_ensure_layout(), OK)
	var layout_path: String = _storage_root_path.path_join(
		".gf-storage/v1/layout.json"
	)
	var layout_pending_path: String = layout_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(DirAccess.rename_absolute(layout_path, layout_pending_path), OK)

	assert_eq(_ensure_layout(), OK)
	assert_true(FileAccess.file_exists(layout_path))
	assert_false(FileAccess.file_exists(layout_pending_path))

	var descriptor: Dictionary = _descriptor("slots/pending-catalog.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var catalog_pending_path: String = catalog_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(DirAccess.rename_absolute(catalog_path, catalog_pending_path), OK)

	_assert_list_result(
		"",
		"",
		true,
		0,
		0,
		PackedStringArray(["slots/pending-catalog.json"])
	)
	assert_true(FileAccess.file_exists(catalog_path))
	assert_false(FileAccess.file_exists(catalog_pending_path))


func test_invalid_exact_pending_files_fail_closed_without_cleanup_or_adoption() -> void:
	assert_eq(_ensure_layout(), OK)
	var layout_path: String = _storage_root_path.path_join(
		".gf-storage/v1/layout.json"
	)
	var invalid_layout_pending: String = layout_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(_write_text(invalid_layout_pending, "{}"), OK)

	assert_eq(_ensure_layout(), ERR_FILE_CORRUPT)
	assert_true(FileAccess.file_exists(layout_path))
	assert_true(
		FileAccess.file_exists(invalid_layout_pending),
		"损坏 pending 必须保留为可诊断冲突，不得静默删除。"
	)
	assert_eq(DirAccess.remove_absolute(invalid_layout_pending), OK)
	assert_eq(_ensure_layout(), OK)

	var descriptor: Dictionary = _descriptor("slots/invalid-pending.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var invalid_catalog_pending: String = catalog_path + ".pending-" + GFUuid.generate_v4()
	assert_eq(_write_text(invalid_catalog_pending, "{}"), OK)

	var list_result: Dictionary = _list_files("", "", true, 0, 0)
	assert_eq(GFVariantData.get_option_int(list_result, "error", OK), ERR_FILE_CORRUPT)
	assert_eq(GFVariantData.get_option_packed_string_array(list_result, "files"), PackedStringArray())
	assert_true(FileAccess.file_exists(catalog_path))
	assert_true(FileAccess.file_exists(invalid_catalog_pending))


func test_claim_staging_recovers_owner_only_and_rejects_physical_work() -> void:
	var recoverable: Dictionary = _descriptor("slots/recover-staging.json")
	assert_eq(_claim_family(recoverable), OK)
	var recoverable_catalog_path: String = GFVariantData.get_option_string(
		recoverable,
		"catalog_path"
	)
	var recoverable_family_path: String = GFVariantData.get_option_string(
		recoverable,
		"family_path"
	)
	var recoverable_staging_path: String = (
		recoverable_family_path + ".claim-" + GFUuid.generate_v4()
	)
	assert_eq(DirAccess.remove_absolute(recoverable_catalog_path), OK)
	assert_eq(
		DirAccess.rename_absolute(recoverable_family_path, recoverable_staging_path),
		OK
	)

	assert_eq(_claim_family(recoverable), OK)
	assert_true(DirAccess.dir_exists_absolute(recoverable_family_path))
	assert_false(DirAccess.dir_exists_absolute(recoverable_staging_path))
	assert_true(FileAccess.file_exists(recoverable_catalog_path))

	var blocked: Dictionary = _descriptor("slots/blocked-staging.json")
	assert_eq(_claim_family(blocked), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(blocked, "payload_path"), "payload"), OK)
	var blocked_catalog_path: String = GFVariantData.get_option_string(blocked, "catalog_path")
	var blocked_family_path: String = GFVariantData.get_option_string(blocked, "family_path")
	var blocked_staging_path: String = blocked_family_path + ".claim-" + GFUuid.generate_v4()
	assert_eq(DirAccess.remove_absolute(blocked_catalog_path), OK)
	assert_eq(DirAccess.rename_absolute(blocked_family_path, blocked_staging_path), OK)

	assert_eq(_claim_family(blocked), ERR_FILE_CORRUPT)
	assert_false(DirAccess.dir_exists_absolute(blocked_family_path))
	assert_true(DirAccess.dir_exists_absolute(blocked_staging_path))
	assert_false(FileAccess.file_exists(blocked_catalog_path))


func test_owner_and_catalog_records_fail_closed_on_reciprocal_corruption() -> void:
	var descriptor: Dictionary = _descriptor("slots/corrupt-owner.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "owner_path"),
			'{"schema":"gf.storage.family-owner","unknown":true}'
		),
		OK
	)

	assert_eq(_validate_family(descriptor), ERR_FILE_CORRUPT)
	assert_false(_has_file(descriptor))
	var list_result: Dictionary = _list_files("", "", true, 0, 0)
	assert_eq(GFVariantData.get_option_int(list_result, "error", OK), ERR_FILE_CORRUPT)
	assert_eq(GFVariantData.get_option_packed_string_array(list_result, "files"), PackedStringArray())


func test_catalog_identity_mismatch_never_adopts_the_family_owner() -> void:
	var descriptor: Dictionary = _descriptor("slots/corrupt-catalog.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	assert_true(catalog_value is Dictionary, "claim 生成的 catalog 应是 JSON Dictionary。")
	if not catalog_value is Dictionary:
		return
	var catalog: Dictionary = catalog_value
	catalog["family_id"] = "00000000-0000-8000-8000-000000000000"
	assert_eq(_write_text(catalog_path, JSON.stringify(catalog, "\t")), OK)

	assert_eq(_validate_family(descriptor), ERR_FILE_CORRUPT)
	assert_false(_has_file(descriptor))
	var list_result: Dictionary = _list_files("", "", true, 0, 0)
	assert_eq(GFVariantData.get_option_int(list_result, "error", OK), ERR_FILE_CORRUPT)
	assert_eq(GFVariantData.get_option_packed_string_array(list_result, "files"), PackedStringArray())


func test_wrong_catalog_shard_and_unknown_catalog_entry_fail_closed() -> void:
	var descriptor: Dictionary = _descriptor("slots/wrong-shard.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var logical_sha256: String = GFVariantData.get_option_string(descriptor, "logical_sha256")
	var wrong_first_shard: String = "ff" if logical_sha256.substr(0, 2) != "ff" else "ee"
	var wrong_catalog_path: String = (
		_storage_root_path
		.path_join(".gf-storage/v1/catalog")
		.path_join(wrong_first_shard)
		.path_join(logical_sha256.substr(2, 2))
		.path_join(logical_sha256 + ".json")
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(wrong_catalog_path.get_base_dir()), OK)
	assert_eq(DirAccess.rename_absolute(catalog_path, wrong_catalog_path), OK)

	var wrong_shard_result: Dictionary = _list_files("", "", true, 0, 0)
	assert_eq(GFVariantData.get_option_int(wrong_shard_result, "error", OK), ERR_FILE_CORRUPT)
	assert_eq(GFVariantData.get_option_packed_string_array(wrong_shard_result, "files"), PackedStringArray())

	assert_eq(DirAccess.rename_absolute(wrong_catalog_path, catalog_path), OK)
	var catalog_leaf_directory: String = catalog_path.get_base_dir()
	assert_eq(
		_write_text(catalog_leaf_directory.path_join("unknown.pending-entry"), "{}"),
		OK
	)
	var unknown_entry_result: Dictionary = _list_files(
		"", "", true, 0, 0
	)
	assert_eq(
		GFVariantData.get_option_int(unknown_entry_result, "error", OK),
		ERR_FILE_CORRUPT,
		"catalog namespace 的未知条目不得被静默跳过。"
	)
	assert_eq(GFVariantData.get_option_packed_string_array(unknown_entry_result, "files"), PackedStringArray())


func test_unknown_family_entry_invalidates_catalog_authority() -> void:
	var descriptor: Dictionary = _descriptor("slots/unknown-family-entry.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), "payload"), OK)
	assert_eq(
		_write_text(
			GFVariantData.get_option_string(descriptor, "family_path").path_join("intruder.bin"),
			"unknown"
		),
		OK
	)

	assert_eq(_validate_family(descriptor), ERR_FILE_CORRUPT)
	assert_false(_has_file(descriptor))
	var list_result: Dictionary = _list_files("", "", true, 0, 0)
	assert_eq(GFVariantData.get_option_int(list_result, "error", OK), ERR_FILE_CORRUPT)


func test_claim_recovers_only_clean_owner_without_catalog() -> void:
	var recoverable: Dictionary = _descriptor("slots/recover-owner.json")
	assert_eq(_claim_family(recoverable), OK)
	assert_eq(DirAccess.remove_absolute(GFVariantData.get_option_string(recoverable, "catalog_path")), OK)

	assert_eq(
		_claim_family(recoverable),
		OK,
		"只有 owner 且尚无 payload/sidecar 时可以补回 catalog。"
	)
	assert_eq(_validate_family(recoverable), OK)

	var blocked: Dictionary = _descriptor("slots/blocked-owner.json")
	assert_eq(_claim_family(blocked), OK)
	assert_eq(_write_text(GFVariantData.get_option_string(blocked, "payload_path"), "payload"), OK)
	assert_eq(DirAccess.remove_absolute(GFVariantData.get_option_string(blocked, "catalog_path")), OK)
	assert_eq(
		_claim_family(blocked),
		ERR_FILE_CORRUPT,
		"owner-only 恢复不得采用已经出现物理工作的 family。"
	)


func test_catalog_without_family_is_never_adopted() -> void:
	var descriptor: Dictionary = _descriptor("slots/catalog-only.json")
	assert_eq(_claim_family(descriptor), OK)
	assert_eq(DirAccess.remove_absolute(GFVariantData.get_option_string(descriptor, "owner_path")), OK)
	assert_eq(DirAccess.remove_absolute(GFVariantData.get_option_string(descriptor, "family_path")), OK)

	assert_eq(_claim_family(descriptor), ERR_FILE_CORRUPT)
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "catalog_path")))


func test_list_projects_only_valid_claimed_families_with_committed_payloads() -> void:
	var payload_paths: Array[String] = [
		"a.json",
		"nested/c.json",
		"nested/deeper/d.tmp",
	]
	for logical_path: String in payload_paths:
		var descriptor: Dictionary = _descriptor(logical_path)
		assert_eq(_claim_family(descriptor), OK)
		assert_eq(_write_text(GFVariantData.get_option_string(descriptor, "payload_path"), logical_path), OK)
	var empty_family: Dictionary = _descriptor("b.tres")
	assert_eq(_claim_family(empty_family), OK)
	assert_eq(_write_text(_storage_root_path.path_join("legacy.json"), "legacy"), OK)

	_assert_list_result("", "", false, 0, 0, PackedStringArray(["a.json"]))
	_assert_list_result(
		"",
		"",
		true,
		0,
		0,
		PackedStringArray(["a.json", "nested/c.json", "nested/deeper/d.tmp"])
	)
	_assert_list_result(
		"nested",
		"",
		false,
		0,
		0,
		PackedStringArray(["nested/c.json"])
	)
	_assert_list_result(
		"",
		"json",
		true,
		0,
		0,
		PackedStringArray(["a.json", "nested/c.json"])
	)
	_assert_list_result(
		"",
		"",
		true,
		1,
		0,
		PackedStringArray(["a.json", "nested/c.json"])
	)
	_assert_list_result(
		"",
		"",
		true,
		0,
		2,
		PackedStringArray(["a.json", "nested/c.json"])
	)


# --- 私有/辅助方法 ---

func _ensure_layout() -> Error:
	var result: Variant = _store.call("ensure_layout_for_framework")
	return GFVariantData.to_exact_int(result, ERR_BUG) as Error


func _claim_family(descriptor: Dictionary) -> Error:
	var result: Variant = _store.call("claim_family_for_framework", descriptor)
	return GFVariantData.to_exact_int(result, ERR_BUG) as Error


func _validate_family(descriptor: Dictionary) -> Error:
	var result: Variant = _store.call("validate_family_for_framework", descriptor)
	return GFVariantData.to_exact_int(result, ERR_BUG) as Error


func _list_files(
	directory_name: String,
	extension_filter: String,
	recursive: bool,
	max_scan_depth: int,
	max_file_count: int
) -> Dictionary:
	return GFVariantData.as_dictionary(
		_store.call(
			"list_files_for_framework",
			directory_name,
			extension_filter,
			recursive,
			max_scan_depth,
			max_file_count
		)
	)


func _has_file(descriptor: Dictionary) -> bool:
	return GFVariantData.to_bool(_store.call("has_file_for_framework", descriptor))


func _descriptor(logical_path: String) -> Dictionary:
	return _GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
		_storage_root_path,
		logical_path
	)


func _make_expected_uuid_v8(digest: String) -> String:
	var raw: String = digest.substr(0, 32)
	var variant_value: int = ("0123456789abcdef".find(raw.substr(16, 1)) & 0x3) | 0x8
	return "%s-%s-8%s-%s%s-%s" % [
		raw.substr(0, 8),
		raw.substr(8, 4),
		raw.substr(13, 3),
		"0123456789abcdef".substr(variant_value, 1),
		raw.substr(17, 3),
		raw.substr(20, 12),
	]


func _make_expected_identity_digest(logical_path: String) -> String:
	var hashing_context: HashingContext = HashingContext.new()
	assert_eq(hashing_context.start(HashingContext.HASH_SHA256), OK)
	assert_eq(
		hashing_context.update("gf.storage.family/v1".to_utf8_buffer()),
		OK
	)
	assert_eq(hashing_context.update(PackedByteArray([0])), OK)
	assert_eq(hashing_context.update(logical_path.to_utf8_buffer()), OK)
	return hashing_context.finish().hex_encode()


func _assert_list_result(
	directory_name: String,
	extension_filter: String,
	recursive: bool,
	max_scan_depth: int,
	max_file_count: int,
	expected_files: PackedStringArray
) -> void:
	var result: Dictionary = _list_files(
		directory_name,
		extension_filter,
		recursive,
		max_scan_depth,
		max_file_count
	)
	assert_eq(GFVariantData.get_option_int(result, "error", ERR_BUG), OK)
	assert_eq(GFVariantData.get_option_packed_string_array(result, "files"), expected_files)


func _write_text(path: String, text: String) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(text) != null
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error


func _remove_tree(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return ERR_FILE_CANT_OPEN
	directory.include_hidden = true
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return begin_error
	var entries: Array[String] = []
	var entry: String = directory.get_next()
	while not entry.is_empty():
		entries.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	for child_name: String in entries:
		var child_error: Error = _remove_tree(path.path_join(child_name))
		if child_error != OK:
			return child_error
	return DirAccess.remove_absolute(path)
