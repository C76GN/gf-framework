# 测试 committed revision 结果的状态不变量、工厂边界与字典隔离。
extends GutTest


# --- 公共方法 ---

func test_available_preserves_opaque_revision_without_normalization() -> void:
	var token: String = "  opaque:revision/九\n"
	var result: GFStorageRevisionResult = GFStorageRevisionResult.available(token)

	assert_true(result.is_successful())
	assert_eq(result.get_status(), GFStorageRevisionResult.Status.AVAILABLE)
	assert_eq(result.get_error_code(), OK)
	assert_eq(result.get_revision(), token)
	assert_eq(result.to_dict(), {
		"status": int(GFStorageRevisionResult.Status.AVAILABLE),
		"error_code": int(OK),
		"revision": token,
	})


func test_failure_statuses_preserve_error_and_never_expose_revision() -> void:
	assert_eq(GFStorageRevisionResult.Status.keys(), [
		"AVAILABLE",
		"NOT_FOUND",
		"UNSUPPORTED",
		"INVALID_REQUEST",
		"UNAVAILABLE",
		"BUSY",
		"CORRUPT",
		"IO_FAILED",
	])
	for status_value: int in GFStorageRevisionResult.Status.values():
		if status_value == GFStorageRevisionResult.Status.AVAILABLE:
			continue
		var failure_status: GFStorageRevisionResult.Status = (
			status_value as GFStorageRevisionResult.Status
		)
		var result: GFStorageRevisionResult = GFStorageRevisionResult.failure(
			failure_status,
			ERR_FILE_CANT_READ
		)

		_assert_failure(result, failure_status, ERR_FILE_CANT_READ)
		assert_eq(result.to_dict(), {
			"status": status_value,
			"error_code": int(ERR_FILE_CANT_READ),
			"revision": "",
		})


func test_invalid_factories_and_direct_construction_fail_closed() -> void:
	var invalid_status_value: int = -1
	var invalid_status: GFStorageRevisionResult.Status = (
		invalid_status_value as GFStorageRevisionResult.Status
	)
	var results: Array[GFStorageRevisionResult] = [
		GFStorageRevisionResult.new(),
		GFStorageRevisionResult.available(""),
		GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.AVAILABLE, FAILED),
		GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.AVAILABLE, OK),
		GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.NOT_FOUND, OK),
		GFStorageRevisionResult.failure(invalid_status, FAILED),
	]
	for result: GFStorageRevisionResult in results:
		_assert_failure(
			result,
			GFStorageRevisionResult.Status.INVALID_REQUEST,
			ERR_INVALID_PARAMETER
		)


func test_dictionary_copies_do_not_modify_result_or_other_copies() -> void:
	var result: GFStorageRevisionResult = GFStorageRevisionResult.available("rev-a")
	var first_copy: Dictionary = result.to_dict()
	var second_copy: Dictionary = result.to_dict()
	first_copy["status"] = int(GFStorageRevisionResult.Status.NOT_FOUND)
	first_copy["error_code"] = int(ERR_FILE_NOT_FOUND)
	first_copy["revision"] = "rev-b"
	first_copy["unexpected"] = true

	assert_true(result.is_successful())
	assert_eq(result.get_revision(), "rev-a")
	assert_eq(second_copy, result.to_dict())
	assert_eq(second_copy.size(), 3)
	assert_eq(GFVariantData.get_option_string(second_copy, "revision"), "rev-a")


# --- 私有/辅助方法 ---

func _assert_failure(
	result: GFStorageRevisionResult,
	expected_status: GFStorageRevisionResult.Status,
	expected_error: Error
) -> void:
	assert_false(result.is_successful())
	assert_eq(result.get_status(), expected_status)
	assert_eq(result.get_error_code(), expected_error)
	assert_eq(result.get_revision(), "")
