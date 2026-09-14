# 测试 catalog 结果的状态不变量和隔离复制。
extends GutTest


# --- 公共方法 ---

func test_unconfigured_result_cannot_be_mistaken_for_empty_success() -> void:
	var result: GFStorageCatalogResult = GFStorageCatalogResult.new()
	assert_false(result.is_successful())
	assert_false(result.is_complete())
	assert_eq(result.get_error_code(), FAILED)
	assert_true(result.get_files().is_empty())


func test_catalog_result_owns_files_and_returns_isolated_snapshots() -> void:
	var files: PackedStringArray = PackedStringArray(["a.json", "nested/b.json"])
	var result: GFStorageCatalogResult = GFStorageCatalogResult.new()
	assert_true(result.configure_for_framework(OK, GFStorageCatalogResult.FailureKind.NONE, files, true))
	files[0] = "input-mutated.json"
	var returned_files: PackedStringArray = result.get_files()
	returned_files[0] = "getter-mutated.json"
	var snapshot: Dictionary = result.to_dict()
	var snapshot_files_value: Variant = snapshot.get("files")
	assert_true(snapshot_files_value is PackedStringArray)
	if not snapshot_files_value is PackedStringArray:
		return
	var snapshot_files: PackedStringArray = snapshot_files_value
	snapshot_files[0] = "snapshot-mutated.json"
	snapshot["files"] = snapshot_files
	snapshot["complete"] = false
	assert_eq(result.get_files(), PackedStringArray(["a.json", "nested/b.json"]))
	assert_true(result.is_complete())
	assert_false(result.configure_for_framework(ERR_UNAVAILABLE, GFStorageCatalogResult.FailureKind.UNAVAILABLE))
	assert_true(result.is_successful(), "已发布结果不可被再次配置。")
	var fresh_snapshot: Dictionary = result.to_dict()
	assert_eq(fresh_snapshot.size(), 5)
	assert_true(fresh_snapshot.has_all(["ok", "error_code", "failure_kind", "complete", "files"]))
	assert_true(fresh_snapshot["ok"] is bool)
	assert_true(fresh_snapshot["error_code"] is int)
	assert_true(fresh_snapshot["failure_kind"] is int)
	assert_true(fresh_snapshot["complete"] is bool)
	assert_true(fresh_snapshot["files"] is PackedStringArray)


func test_result_rejects_inconsistent_terminal_states_without_partial_configuration() -> void:
	var cases: Array[Dictionary] = [
		{"error": OK, "kind": GFStorageCatalogResult.FailureKind.UNAVAILABLE, "complete": true},
		{"error": ERR_UNAVAILABLE, "kind": GFStorageCatalogResult.FailureKind.NONE},
		{"error": ERR_UNAVAILABLE, "kind": GFStorageCatalogResult.FailureKind.UNAVAILABLE, "complete": true},
		{"error": ERR_BUSY, "kind": GFStorageCatalogResult.FailureKind.UNAVAILABLE},
		{"error": ERR_UNAVAILABLE, "kind": GFStorageCatalogResult.FailureKind.BUSY},
		{"error": ERR_FILE_CORRUPT, "kind": GFStorageCatalogResult.FailureKind.INVALID_REQUEST},
		{"error": OK, "kind": GFStorageCatalogResult.FailureKind.NONE},
	]
	for case_data: Dictionary in cases:
		var result: GFStorageCatalogResult = GFStorageCatalogResult.new()
		assert_false(result.configure_for_framework(
			GFVariantData.get_option_int(case_data, "error", FAILED) as Error,
			GFVariantData.get_option_int(case_data, "kind", -1) as GFStorageCatalogResult.FailureKind,
			PackedStringArray(), GFVariantData.get_option_bool(case_data, "complete", false)
		), "不一致终态必须拒绝：%s" % [case_data])
		assert_eq(result.get_error_code(), FAILED)
		assert_true(result.configure_for_framework(OK, GFStorageCatalogResult.FailureKind.NONE, PackedStringArray(), true))
		assert_true(result.is_complete(), "非法配置不能提前占用一次性配置权。")


func test_result_rejects_partial_failure_and_noncanonical_file_sequences() -> void:
	var failed_result: GFStorageCatalogResult = GFStorageCatalogResult.new()
	assert_false(failed_result.configure_for_framework(
		ERR_FILE_CANT_READ, GFStorageCatalogResult.FailureKind.CATALOG_FAILED,
		PackedStringArray(["a.json"]), false
	))
	for files: PackedStringArray in [
		PackedStringArray(["b.json", "a.json"]), PackedStringArray(["a.json", "a.json"]),
		PackedStringArray(["../a.json"]), PackedStringArray(["C:/a.json"]),
	]:
		var result: GFStorageCatalogResult = GFStorageCatalogResult.new()
		assert_false(result.configure_for_framework(OK, GFStorageCatalogResult.FailureKind.NONE, files, true))
		assert_false(result.is_successful())
		assert_true(result.get_files().is_empty())


func test_successful_truncation_and_failed_queries_remain_distinct() -> void:
	var limited_result: GFStorageCatalogResult = GFStorageCatalogResult.new()
	assert_true(limited_result.configure_for_framework(
		OK, GFStorageCatalogResult.FailureKind.NONE, PackedStringArray(["a.json"]), false
	))
	assert_true(limited_result.is_successful())
	assert_false(limited_result.is_complete())
	assert_eq(limited_result.get_files(), PackedStringArray(["a.json"]))
	var failed_result: GFStorageCatalogResult = GFStorageCatalogResult.new()
	assert_true(failed_result.configure_for_framework(ERR_FILE_CANT_READ, GFStorageCatalogResult.FailureKind.CATALOG_FAILED))
	assert_false(failed_result.is_successful())
	assert_false(failed_result.is_complete())
	assert_true(failed_result.get_files().is_empty())
	assert_eq(failed_result.get_error_code(), ERR_FILE_CANT_READ)
