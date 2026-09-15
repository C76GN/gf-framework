# 测试 Resource 读取结果的成功配对、共享对象引用与失败隔离。
extends GutTest


# --- 公共方法 ---

func test_success_preserves_resource_reference_and_source_revision() -> void:
	var resource: Resource = Resource.new()
	resource.resource_name = "before"
	var revision: GFStorageRevisionResult = GFStorageRevisionResult.available("rev-a")
	var result: GFStorageResourceReadResult = GFStorageResourceReadResult.success(
		resource,
		revision
	)

	assert_true(result.is_successful())
	assert_eq(result.get_error_code(), OK)
	assert_true(result.get_resource() == resource)
	assert_true(result.get_committed_revision() == revision)
	resource.resource_name = "after"
	assert_eq(result.get_resource().resource_name, "after")
	assert_eq(result.get_committed_revision().get_revision(), "rev-a")
	var revision_copy: Dictionary = result.get_committed_revision().to_dict()
	revision_copy["revision"] = "rev-b"
	assert_eq(result.get_committed_revision().get_revision(), "rev-a")


func test_failure_preserves_error_without_resource_or_revision() -> void:
	var errors: Array[Error] = [
		ERR_FILE_NOT_FOUND,
		ERR_UNAVAILABLE,
		ERR_BUSY,
		ERR_FILE_CORRUPT,
		ERR_FILE_CANT_READ,
	]
	for error_code: Error in errors:
		_assert_failure(GFStorageResourceReadResult.failure(error_code), error_code)


func test_success_rejects_missing_or_failed_pair_members() -> void:
	var resource: Resource = Resource.new()
	var revision: GFStorageRevisionResult = GFStorageRevisionResult.available("rev-a")
	var failed_revision: GFStorageRevisionResult = GFStorageRevisionResult.failure(
		GFStorageRevisionResult.Status.NOT_FOUND,
		ERR_FILE_NOT_FOUND
	)
	var results: Array[GFStorageResourceReadResult] = [
		GFStorageResourceReadResult.success(null, revision),
		GFStorageResourceReadResult.success(resource, null),
		GFStorageResourceReadResult.success(null, null),
		GFStorageResourceReadResult.success(resource, failed_revision),
		GFStorageResourceReadResult.success(resource, GFStorageRevisionResult.new()),
	]
	for result: GFStorageResourceReadResult in results:
		_assert_failure(result, ERR_INVALID_PARAMETER)
	assert_eq(resource.resource_name, "")
	assert_true(revision.is_successful())
	assert_eq(revision.get_revision(), "rev-a")


func test_invalid_failure_and_direct_construction_never_report_success() -> void:
	_assert_failure(GFStorageResourceReadResult.failure(OK), ERR_INVALID_PARAMETER)
	_assert_failure(GFStorageResourceReadResult.new(), ERR_INVALID_PARAMETER)


# --- 私有/辅助方法 ---

func _assert_failure(result: GFStorageResourceReadResult, expected_error: Error) -> void:
	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), expected_error)
	assert_null(result.get_resource())
	assert_null(result.get_committed_revision())
