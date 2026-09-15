# 测试 Storage 读取结果复制、规范化与异步快照隔离。
extends GutTest


# --- 公共方法 ---

func test_duplicate_keeps_nested_payload_and_metadata_isolated() -> void:
	var original: GFStorageReadResult = _make_read_result()
	var revision: GFStorageRevisionResult = GFStorageRevisionResult.available("captured-read-revision")
	original.capture_revision_for_framework(revision)
	var copied: GFStorageReadResult = original.duplicate_result()
	assert_eq(copied.get_committed_revision().get_status(), GFStorageRevisionResult.Status.AVAILABLE)
	assert_eq(copied.get_committed_revision().get_revision(), revision.get_revision())
	_mutate_read_result(copied)
	_assert_original_values(original)
	assert_ne(copied.payload, original.payload)
	assert_ne(copied.metadata, original.metadata)
	var exported: Dictionary = copied.to_dict()
	assert_eq(exported.size(), 11)
	for field: String in [
		"ok", "payload", "metadata", "integrity_status", "error_code", "error", "failure_kind",
		"document_schema_version", "source_data_version", "data_version", "migrated",
	]:
		assert_true(exported.has(field), "The public dictionary schema must retain %s." % field)
	var roundtrip: GFStorageReadResult = GFStorageReadResult.from_dict(exported)
	assert_eq(roundtrip.get_committed_revision().get_status(), GFStorageRevisionResult.Status.UNSUPPORTED)
	original.payload.clear()
	original.metadata.clear()
	assert_false(copied.payload.is_empty())
	assert_false(copied.metadata.is_empty())
	assert_eq(copied.get_committed_revision().get_revision(), revision.get_revision())


func test_dictionary_exports_and_imports_keep_independent_nested_values() -> void:
	var original: GFStorageReadResult = _make_read_result()
	var exported: Dictionary = original.to_dict()
	var imported: GFStorageReadResult = GFStorageReadResult.from_dict(exported)
	var applied: GFStorageReadResult = GFStorageReadResult.new()
	applied.apply_dict(exported)
	_mutate_read_result(imported)
	_assert_original_values(original)
	_assert_original_values(applied)
	var exported_payload: Dictionary = GFVariantData.as_dictionary(exported.get("payload"))
	var exported_metadata: Dictionary = GFVariantData.as_dictionary(exported.get("metadata"))
	exported_payload.clear()
	exported_metadata.clear()
	_assert_original_values(original)
	_assert_original_values(applied)


func test_duplicate_preserves_success_field_normalization_without_mutating_source() -> void:
	var original: GFStorageReadResult = _make_read_result()
	original.failure_kind = GFStorageReadResult.FailureKind.CORRUPT
	var invalid_integrity_status: int = 99
	original.integrity_status = invalid_integrity_status as GFStorageReadResult.IntegrityStatus
	original.error = "  diagnostic\n"
	original.document_schema_version = -3
	original.source_data_version = -2
	original.data_version = -1
	original.migrated = true
	var copied: GFStorageReadResult = original.duplicate_result()
	assert_true(copied.ok)
	assert_eq(copied.failure_kind, GFStorageReadResult.FailureKind.NONE)
	assert_eq(copied.integrity_status, GFStorageReadResult.IntegrityStatus.NOT_CHECKED)
	assert_eq(copied.error, "diagnostic")
	assert_eq(copied.document_schema_version, 0)
	assert_eq(copied.source_data_version, 1)
	assert_eq(copied.data_version, 1)
	assert_true(copied.migrated)
	_assert_original_values(copied)
	assert_eq(original.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(original.error, "  diagnostic\n")
	assert_eq(original.document_schema_version, -3)


func test_duplicate_clears_failure_payload_and_normalizes_failure_kind() -> void:
	for invalid_kind: int in [int(GFStorageReadResult.FailureKind.NONE), 99]:
		var original: GFStorageReadResult = _make_read_result()
		original.ok = false
		original.error_code = ERR_FILE_CANT_READ
		original.failure_kind = invalid_kind as GFStorageReadResult.FailureKind
		var copied: GFStorageReadResult = original.duplicate_result()
		assert_false(copied.ok)
		assert_true(copied.payload.is_empty())
		assert_eq(copied.error_code, ERR_FILE_CANT_READ)
		assert_eq(copied.failure_kind, GFStorageReadResult.FailureKind.IO_FAILED)
		assert_false(original.payload.is_empty())
		copied.metadata.clear()
		assert_false(original.metadata.is_empty())


func test_empty_success_remains_successful_through_duplicate_and_dictionary() -> void:
	var original: GFStorageReadResult = GFStorageReadResult.new().configure_success({})
	var copies: Array[GFStorageReadResult] = [
		original.duplicate_result(),
		GFStorageReadResult.from_dict(original.to_dict()),
	]
	for copied: GFStorageReadResult in copies:
		assert_true(copied.ok)
		assert_true(copied.payload.is_empty())
		assert_eq(copied.error_code, OK)


func test_duplicate_preserves_current_origin_but_dictionary_roundtrip_drops_it() -> void:
	var original: GFStorageReadResult = GFStorageReadResult.new().configure_failure(
		"corrupt", ERR_FILE_CORRUPT, {},
		GFStorageReadResult.IntegrityStatus.INVALID, 1,
		GFStorageReadResult.FailureKind.CORRUPT
	)
	assert_true(original.bind_origin_for_framework(7, "slot.json", "family", "origin", "observed"))
	var copied: GFStorageReadResult = original.duplicate_result()
	assert_true(copied.matches_origin_for_framework(7, "slot.json", "family", "origin"))
	assert_eq(
		copied.get_origin_observation_token_for_framework(7, "slot.json", "family", "origin"),
		"observed"
	)
	var roundtrip: GFStorageReadResult = GFStorageReadResult.from_dict(original.to_dict())
	assert_false(roundtrip.matches_origin_for_framework(7, "slot.json", "family", "origin"))
	copied.apply_dict(copied.to_dict())
	assert_false(copied.matches_origin_for_framework(7, "slot.json", "family", "origin"))
	original.error_code = ERR_INVALID_DATA
	var changed_copy: GFStorageReadResult = original.duplicate_result()
	assert_false(changed_copy.matches_origin_for_framework(7, "slot.json", "family", "origin"))


func test_async_physical_and_caller_exports_keep_read_payloads_isolated() -> void:
	var original: GFStorageReadResult = _make_read_result()
	var physical: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(physical.configure_for_framework(1, &"load", "slot.json", true, OK, original))
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(operation.configure_for_framework(1, &"load", "slot.json"))
	assert_true(operation.configure_consumer_for_framework(
		1, null, GFClock.new(), Callable(self, &"_reject_cancel")
	))
	var physical_signals: Array[GFStorageAsyncResult] = []
	var caller_signals: Array[GFStorageAsyncCallerResult] = []
	var physical_callback: Callable = func(result: GFStorageAsyncResult) -> void:
		physical_signals.append(result)
	var caller_callback: Callable = func(result: GFStorageAsyncCallerResult) -> void:
		caller_signals.append(result)
	assert_eq(operation.completed.connect(physical_callback), OK)
	assert_eq(operation.caller_completed.connect(caller_callback), OK)
	assert_true(operation.complete_for_framework(physical))
	assert_eq(physical_signals.size(), 1)
	assert_eq(caller_signals.size(), 1)
	_mutate_read_result(original)
	var physical_copy: GFStorageAsyncResult = operation.get_result()
	var caller_copy: GFStorageAsyncCallerResult = operation.get_caller_result()
	var read_copy: GFStorageReadResult = physical_copy.get_read_result()
	_assert_original_values(read_copy)
	_mutate_read_result(read_copy)
	_assert_original_values(physical.get_read_result())
	_assert_original_values(operation.get_result().get_read_result())
	_assert_original_values(caller_copy.get_physical_result().get_read_result())
	_assert_original_values(physical_signals[0].get_read_result())
	_assert_original_values(caller_signals[0].get_physical_result().get_read_result())
	operation.completed.disconnect(physical_callback)
	operation.caller_completed.disconnect(caller_callback)


func test_late_read_diagnostic_keeps_failure_kind_and_never_exports_payload() -> void:
	var cases: Array[GFStorageReadResult] = [
		_make_read_result(),
		GFStorageReadResult.new().configure_failure(
			"corrupt", ERR_FILE_CORRUPT, {},
			GFStorageReadResult.IntegrityStatus.INVALID, 1,
			GFStorageReadResult.FailureKind.CORRUPT
		),
	]
	for read_result: GFStorageReadResult in cases:
		var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
		assert_true(operation.configure_for_framework(1, &"load", "slot.json"))
		assert_true(operation.configure_consumer_for_framework(
			1, null, GFClock.new(), Callable(self, &"_reject_cancel")
		))
		assert_true(operation.complete_caller_for_framework(
			GFStorageAsyncCallerResult.Status.CANCELLED,
			GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL
		))
		var physical: GFStorageAsyncResult = GFStorageAsyncResult.new()
		assert_true(physical.configure_for_framework(
			1, &"load", "slot.json", read_result.ok, read_result.error_code, read_result
		))
		assert_true(operation.complete_for_framework(physical))
		var diagnostic: Dictionary = operation.take_late_settlement_diagnostic_for_framework()
		assert_eq(GFVariantData.get_option_int(diagnostic, "read_failure_kind"), read_result.failure_kind)
		assert_false(diagnostic.has("payload"))
		assert_false(diagnostic.has("read_result"))
		assert_true(operation.take_late_settlement_diagnostic_for_framework().is_empty())
		assert_eq(operation.get_result().get_read_result().payload, read_result.payload)


# --- 私有/辅助方法 ---

func _reject_cancel(
	_operation: GFStorageAsyncOperation,
	_end_kind: GFStorageAsyncCallerResult.EndKind,
	_reason: StringName
) -> bool:
	return false


func _make_read_result() -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_success(
		{"items": [{"value": 7}], "bytes": PackedByteArray([2, 4, 6])},
		{"nested": {"version": 3}}
	)


func _mutate_read_result(result: GFStorageReadResult) -> void:
	var items: Array = GFVariantData.as_array(result.payload.get("items"))
	var item: Dictionary = GFVariantData.as_dictionary(items[0])
	item["value"] = 99
	var bytes: PackedByteArray = result.payload.get("bytes")
	bytes[0] = 99
	result.payload["bytes"] = bytes
	var nested: Dictionary = GFVariantData.as_dictionary(result.metadata.get("nested"))
	nested["version"] = 99


func _assert_original_values(result: GFStorageReadResult) -> void:
	var items: Array = GFVariantData.as_array(result.payload.get("items"))
	assert_eq(items.size(), 1)
	if items.size() != 1:
		return
	var item: Dictionary = GFVariantData.as_dictionary(items[0])
	assert_eq(GFVariantData.get_option_int(item, "value"), 7)
	var bytes: PackedByteArray = result.payload.get("bytes")
	assert_eq(bytes, PackedByteArray([2, 4, 6]))
	var nested: Dictionary = GFVariantData.as_dictionary(result.metadata.get("nested"))
	assert_eq(GFVariantData.get_option_int(nested, "version"), 3)
