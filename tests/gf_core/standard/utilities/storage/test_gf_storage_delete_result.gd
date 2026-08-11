# 测试异步 Storage 删除结果的公开值对象契约与判别联合边界。
extends GutTest


const _DELETE_RESULT_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/storage/gf_storage_delete_result.gd"
)


func test_delete_result_exposes_frozen_success_contract() -> void:
	assert_true(
		ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH),
		"#87 必须提供 GFStorageDeleteResult 脚本。"
	)
	if not ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH):
		return

	var script_resource: Resource = load(_DELETE_RESULT_SCRIPT_PATH)
	assert_true(script_resource is GDScript, "删除结果必须是可实例化的 GDScript 值对象。")
	if not script_resource is GDScript:
		return
	var delete_result_script: GDScript = script_resource
	var script_constants: Dictionary = delete_result_script.get_script_constant_map()
	var failure_kinds: Dictionary = GFVariantData.get_option_dictionary(
		script_constants,
		"FailureKind"
	)
	var family_members: Dictionary = GFVariantData.get_option_dictionary(
		script_constants,
		"FamilyMember"
	)
	assert_eq(
		failure_kinds.keys(),
		[
			"NONE",
			"INVALID_REQUEST",
			"NOT_FOUND",
			"CONFLICT",
			"THREAD_START_FAILED",
			"UNAVAILABLE",
			"IO_FAILED",
		],
		"FailureKind 必须保持冻结顺序。"
	)
	assert_eq(
		family_members.keys(),
		[
			"NONE",
			"FAMILY_METADATA",
			"BACKUP",
			"TRANSACTION_EVIDENCE",
			"CANDIDATE",
			"RESOURCE_STAGE",
			"FINAL",
		],
		"FamilyMember 必须保持冻结顺序。"
	)

	var instance_value: Variant = delete_result_script.new()
	assert_true(instance_value is GFStorageDeleteResult, "删除结果必须继承 RefCounted。")
	if not instance_value is GFStorageDeleteResult:
		return
	var delete_result: GFStorageDeleteResult = instance_value
	for method_name: StringName in [
		&"is_configured_for_framework",
		&"is_successful",
		&"get_error_code",
		&"get_failure_kind",
		&"get_existing_member_count",
		&"get_removed_member_count",
		&"get_remaining_member_count",
		&"get_failed_member",
		&"duplicate_result",
		&"to_dict",
		&"configure_for_framework",
	]:
		assert_true(delete_result.has_method(method_name), "缺少冻结方法：%s" % method_name)
		if not delete_result.has_method(method_name):
			return

	var configured_value: bool = delete_result.configure_for_framework(
		OK,
		GFVariantData.get_option_int(failure_kinds, "NONE", -1) as GFStorageDeleteResult.FailureKind,
		8,
		8,
		0,
		GFVariantData.get_option_int(family_members, "NONE", -1) as GFStorageDeleteResult.FamilyMember
	)
	assert_true(configured_value, "合法成功终态必须可配置。")
	assert_true(delete_result.is_configured_for_framework())
	assert_true(delete_result.is_successful())
	assert_eq(delete_result.get_error_code(), OK)
	assert_eq(
		delete_result.get_failure_kind(),
		GFVariantData.get_option_int(failure_kinds, "NONE", -1)
	)
	assert_eq(delete_result.get_existing_member_count(), 8)
	assert_eq(delete_result.get_removed_member_count(), 8)
	assert_eq(delete_result.get_remaining_member_count(), 0)
	assert_eq(
		delete_result.get_failed_member(),
		GFVariantData.get_option_int(family_members, "NONE", -1)
	)


func test_delete_result_accepts_missing_conflict_and_partial_terminal_states() -> void:
	var delete_result_script: GDScript = _load_delete_result_script()
	if delete_result_script == null:
		return
	var failure_kinds: Dictionary = _enum_values(delete_result_script, "FailureKind")
	var family_members: Dictionary = _enum_values(delete_result_script, "FamilyMember")
	var cases: Array[Dictionary] = [
		{
			"error_code": ERR_FILE_NOT_FOUND,
			"failure_kind": GFVariantData.get_option_int(failure_kinds, "NOT_FOUND", -1),
			"existing": 0,
			"removed": 0,
			"remaining": 0,
			"failed_member": GFVariantData.get_option_int(family_members, "NONE", -1),
		},
		{
			"error_code": ERR_FILE_CORRUPT,
			"failure_kind": GFVariantData.get_option_int(failure_kinds, "CONFLICT", -1),
			"existing": 3,
			"removed": 0,
			"remaining": 3,
			"failed_member": GFVariantData.get_option_int(
				family_members,
				"TRANSACTION_EVIDENCE",
				-1
			),
		},
		{
			"error_code": ERR_FILE_CANT_WRITE,
			"failure_kind": GFVariantData.get_option_int(failure_kinds, "IO_FAILED", -1),
			"existing": 8,
			"removed": 3,
			"remaining": 5,
			"failed_member": GFVariantData.get_option_int(
				family_members,
				"TRANSACTION_EVIDENCE",
				-1
			),
		},
		{
			"error_code": ERR_BUG,
			"failure_kind": GFVariantData.get_option_int(failure_kinds, "IO_FAILED", -1),
			"existing": 0,
			"removed": 0,
			"remaining": 0,
			"failed_member": GFVariantData.get_option_int(
				family_members,
				"FAMILY_METADATA",
				-1
			),
		},
		{
			"error_code": ERR_FILE_CANT_WRITE,
			"failure_kind": GFVariantData.get_option_int(failure_kinds, "IO_FAILED", -1),
			"existing": 1,
			"removed": 1,
			"remaining": 0,
			"failed_member": GFVariantData.get_option_int(family_members, "FINAL", -1),
		},
	]
	for case_data: Dictionary in cases:
		var delete_result: GFStorageDeleteResult = _new_delete_result(delete_result_script)
		if delete_result == null:
			return
		var configured_value: bool = delete_result.configure_for_framework(
			GFVariantData.get_option_int(case_data, "error_code", ERR_BUG) as Error,
			GFVariantData.get_option_int(
				case_data,
				"failure_kind",
				-1
			) as GFStorageDeleteResult.FailureKind,
			GFVariantData.get_option_int(case_data, "existing", -1),
			GFVariantData.get_option_int(case_data, "removed", -1),
			GFVariantData.get_option_int(case_data, "remaining", -1),
			GFVariantData.get_option_int(
				case_data,
				"failed_member",
				-1
			) as GFStorageDeleteResult.FamilyMember
		)
		assert_eq(configured_value, true, "合法删除失败终态必须可表达：%s" % [case_data])
		assert_false(delete_result.is_successful())
		assert_eq(
			delete_result.get_error_code(),
			GFVariantData.get_option_int(case_data, "error_code", ERR_BUG)
		)
		assert_eq(
			delete_result.get_existing_member_count(),
			GFVariantData.get_option_int(case_data, "existing", -1)
		)
		assert_eq(
			delete_result.get_removed_member_count(),
			GFVariantData.get_option_int(case_data, "removed", -1)
		)
		assert_eq(
			delete_result.get_remaining_member_count(),
			GFVariantData.get_option_int(case_data, "remaining", -1)
		)


func test_delete_result_configuration_is_one_shot_and_rejects_impossible_states() -> void:
	var delete_result_script: GDScript = _load_delete_result_script()
	if delete_result_script == null:
		return
	var failure_kinds: Dictionary = _enum_values(delete_result_script, "FailureKind")
	var family_members: Dictionary = _enum_values(delete_result_script, "FamilyMember")
	var none_failure: GFStorageDeleteResult.FailureKind = GFVariantData.get_option_int(
		failure_kinds,
		"NONE",
		-1
	) as GFStorageDeleteResult.FailureKind
	var io_failure: GFStorageDeleteResult.FailureKind = GFVariantData.get_option_int(
		failure_kinds,
		"IO_FAILED",
		-1
	) as GFStorageDeleteResult.FailureKind
	var conflict_failure: GFStorageDeleteResult.FailureKind = GFVariantData.get_option_int(
		failure_kinds,
		"CONFLICT",
		-1
	) as GFStorageDeleteResult.FailureKind
	var none_member: GFStorageDeleteResult.FamilyMember = GFVariantData.get_option_int(
		family_members,
		"NONE",
		-1
	) as GFStorageDeleteResult.FamilyMember
	var final_member: GFStorageDeleteResult.FamilyMember = GFVariantData.get_option_int(
		family_members,
		"FINAL",
		-1
	) as GFStorageDeleteResult.FamilyMember
	var invalid_cases: Array[Array] = [
		[OK, io_failure, 1, 1, 0, none_member],
		[ERR_FILE_CANT_WRITE, none_failure, 1, 0, 1, final_member],
		[OK, none_failure, 0, 0, 0, none_member],
		[OK, none_failure, 2, 1, 1, none_member],
		[ERR_FILE_CANT_WRITE, io_failure, 2, 3, 0, final_member],
		[ERR_FILE_CANT_WRITE, io_failure, 2, 1, 0, final_member],
		[ERR_FILE_CANT_WRITE, io_failure, -1, 0, 0, final_member],
		[ERR_FILE_CANT_WRITE, io_failure, 0, 0, 0, final_member],
		[ERR_FILE_CORRUPT, conflict_failure, 1, 0, 1, final_member],
	]
	for arguments: Array in invalid_cases:
		var invalid_result: GFStorageDeleteResult = _new_delete_result(delete_result_script)
		if invalid_result == null:
			return
		var configured_value: Variant = invalid_result.callv(
			"configure_for_framework",
			arguments
		)
		assert_true(configured_value is bool)
		if not configured_value is bool:
			return
		var configured: bool = configured_value
		assert_false(configured, "不可能的删除终态必须被拒绝：%s" % [arguments])
		assert_false(invalid_result.is_configured_for_framework())

	var valid_result: GFStorageDeleteResult = _new_delete_result(delete_result_script)
	if valid_result == null:
		return
	assert_true(
		valid_result.configure_for_framework(
			OK,
			none_failure,
			1,
			1,
			0,
			none_member
		)
	)
	assert_false(
		valid_result.configure_for_framework(
			ERR_FILE_CANT_WRITE,
			io_failure,
			1,
			0,
			1,
			final_member
		),
		"配置后的值对象不得被第二次改写。"
	)
	assert_true(valid_result.is_successful())
	assert_eq(valid_result.get_error_code(), OK)


func test_delete_result_duplicate_and_dictionary_are_isolated() -> void:
	var delete_result_script: GDScript = _load_delete_result_script()
	if delete_result_script == null:
		return
	var failure_kinds: Dictionary = _enum_values(delete_result_script, "FailureKind")
	var family_members: Dictionary = _enum_values(delete_result_script, "FamilyMember")
	var delete_result: GFStorageDeleteResult = _new_delete_result(delete_result_script)
	if delete_result == null:
		return
	assert_true(
		delete_result.configure_for_framework(
			ERR_FILE_CANT_WRITE,
			GFVariantData.get_option_int(
				failure_kinds,
				"IO_FAILED",
				-1
			) as GFStorageDeleteResult.FailureKind,
			8,
			3,
			5,
			GFVariantData.get_option_int(
				family_members,
				"TRANSACTION_EVIDENCE",
				-1
			) as GFStorageDeleteResult.FamilyMember
		)
	)
	var duplicate_result: GFStorageDeleteResult = delete_result.duplicate_result()
	assert_not_same(duplicate_result, delete_result)
	assert_eq(duplicate_result.get_existing_member_count(), 8)
	assert_eq(duplicate_result.get_removed_member_count(), 3)
	assert_eq(duplicate_result.get_remaining_member_count(), 5)

	var result_dictionary: Dictionary = delete_result.to_dict()
	var expected_keys: Array[String] = [
		"ok",
		"error_code",
		"failure_kind",
		"existing_member_count",
		"removed_member_count",
		"remaining_member_count",
		"failed_member",
	]
	assert_eq(result_dictionary.size(), expected_keys.size(), "删除结果字典必须恰好包含 7 个字段。")
	assert_true(result_dictionary.has_all(expected_keys), "删除结果字典不得缺少冻结字段。")
	assert_true(result_dictionary["ok"] is bool)
	for integer_key: String in expected_keys.slice(1):
		assert_true(result_dictionary[integer_key] is int, "%s 必须序列化为 int。" % integer_key)
	assert_eq(GFVariantData.get_option_bool(result_dictionary, "ok", true), false)
	assert_eq(
		GFVariantData.get_option_int(result_dictionary, "error_code", OK),
		ERR_FILE_CANT_WRITE
	)
	assert_eq(
		GFVariantData.get_option_int(result_dictionary, "failure_kind", -1),
		GFVariantData.get_option_int(failure_kinds, "IO_FAILED", -1)
	)
	assert_eq(GFVariantData.get_option_int(result_dictionary, "existing_member_count", -1), 8)
	assert_eq(GFVariantData.get_option_int(result_dictionary, "removed_member_count", -1), 3)
	assert_eq(GFVariantData.get_option_int(result_dictionary, "remaining_member_count", -1), 5)
	assert_eq(
		GFVariantData.get_option_int(result_dictionary, "failed_member", -1),
		GFVariantData.get_option_int(family_members, "TRANSACTION_EVIDENCE", -1)
	)
	result_dictionary["existing_member_count"] = 99
	assert_eq(delete_result.get_existing_member_count(), 8)
	assert_eq(duplicate_result.get_existing_member_count(), 8)


func test_async_result_enforces_delete_discriminated_union() -> void:
	var contract: Dictionary = _delete_async_contract()
	if contract.is_empty():
		return
	var delete_operation: StringName = GFVariantData.get_option_string_name(
		contract,
		"delete_operation"
	)
	var delete_result_script_value: Variant = contract.get("delete_result_script")
	if not delete_result_script_value is GDScript:
		return
	var delete_result_script: GDScript = delete_result_script_value
	var delete_result: GFStorageDeleteResult = _make_missing_delete_result(delete_result_script)
	if delete_result == null:
		return

	var valid_async_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(
		valid_async_result.configure_for_framework(
			41,
			delete_operation,
			"union/missing.json",
			false,
			ERR_FILE_NOT_FOUND,
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			delete_result
		)
	)
	var nested_value: Variant = valid_async_result.call("get_delete_result")
	assert_true(nested_value is RefCounted)
	assert_eq(valid_async_result.get_read_result(), null)
	assert_eq(valid_async_result.get_write_failure_kind(), GFStorageAsyncResult.WriteFailureKind.NONE)
	assert_true(valid_async_result.get_write_validation_report().is_empty())
	var valid_delete_dictionary: Dictionary = valid_async_result.to_dict()
	assert_false(
		GFVariantData.get_option_dictionary(valid_delete_dictionary, "delete_result").is_empty()
	)

	var read_failure: GFStorageReadResult = GFStorageReadResult.new().configure_failure(
		"missing",
		ERR_FILE_NOT_FOUND,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)
	var valid_save_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(
		valid_save_result.configure_for_framework(
			42,
			GFStorageAsyncOperation.OPERATION_SAVE,
			"union/save.json",
			true,
			OK
		)
	)
	var valid_save_dictionary: Dictionary = valid_save_result.to_dict()
	assert_true(valid_save_dictionary.has("delete_result"))
	assert_true(
		GFVariantData.get_option_dictionary(valid_save_dictionary, "delete_result").is_empty(),
		"save 结果必须使用空字典表达不适用的 delete_result。"
	)

	var valid_load_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(
		valid_load_result.configure_for_framework(
			43,
			GFStorageAsyncOperation.OPERATION_LOAD,
			"union/missing.json",
			false,
			ERR_FILE_NOT_FOUND,
			read_failure
		)
	)
	var valid_load_dictionary: Dictionary = valid_load_result.to_dict()
	assert_true(valid_load_dictionary.has("delete_result"))
	assert_true(
		GFVariantData.get_option_dictionary(valid_load_dictionary, "delete_result").is_empty(),
		"load 结果必须使用空字典表达不适用的 delete_result。"
	)

	var invalid_cases: Array[Dictionary] = [
		{
			"name": "save 不得携带 delete payload",
			"operation": GFStorageAsyncOperation.OPERATION_SAVE,
			"ok": false,
			"error_code": ERR_FILE_NOT_FOUND,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			"write_report": {},
			"delete_result": delete_result,
		},
		{
			"name": "save 失败必须携带非 NONE write failure",
			"operation": GFStorageAsyncOperation.OPERATION_SAVE,
			"ok": false,
			"error_code": ERR_FILE_CANT_WRITE,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": null,
		},
		{
			"name": "save 成功不得携带 write failure",
			"operation": GFStorageAsyncOperation.OPERATION_SAVE,
			"ok": true,
			"error_code": OK,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			"write_report": {},
			"delete_result": null,
		},
		{
			"name": "load 不得携带 delete payload",
			"operation": GFStorageAsyncOperation.OPERATION_LOAD,
			"ok": false,
			"error_code": ERR_FILE_NOT_FOUND,
			"read_result": read_failure,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": delete_result,
		},
		{
			"name": "load 外层 error 必须匹配 read result",
			"operation": GFStorageAsyncOperation.OPERATION_LOAD,
			"ok": false,
			"error_code": ERR_FILE_CANT_READ,
			"read_result": read_failure,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": null,
		},
		{
			"name": "delete 必须携带 delete payload",
			"operation": delete_operation,
			"ok": false,
			"error_code": ERR_FILE_NOT_FOUND,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": null,
		},
		{
			"name": "delete 不得携带 read payload",
			"operation": delete_operation,
			"ok": false,
			"error_code": ERR_FILE_NOT_FOUND,
			"read_result": read_failure,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": delete_result,
		},
		{
			"name": "delete 不得携带 write payload",
			"operation": delete_operation,
			"ok": false,
			"error_code": ERR_FILE_NOT_FOUND,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			"write_report": { "unexpected": true },
			"delete_result": delete_result,
		},
		{
			"name": "delete 外层 error 必须匹配 delete result",
			"operation": delete_operation,
			"ok": false,
			"error_code": ERR_FILE_CANT_READ,
			"read_result": null,
			"write_failure": GFStorageAsyncResult.WriteFailureKind.NONE,
			"write_report": {},
			"delete_result": delete_result,
		},
	]
	var request_id: int = 100
	for case_data: Dictionary in invalid_cases:
		var aggregate: GFStorageAsyncResult = GFStorageAsyncResult.new()
		var case_read_result: GFStorageReadResult = null
		var read_result_value: Variant = case_data.get("read_result")
		if read_result_value is GFStorageReadResult:
			case_read_result = read_result_value
		else:
			assert_true(read_result_value == null)
			if read_result_value != null:
				return
		var case_delete_result: GFStorageDeleteResult = null
		var delete_result_value: Variant = case_data.get("delete_result")
		if delete_result_value is GFStorageDeleteResult:
			case_delete_result = delete_result_value
		else:
			assert_true(delete_result_value == null)
			if delete_result_value != null:
				return
		var case_write_failure: GFStorageAsyncResult.WriteFailureKind = (
			GFVariantData.get_option_int(case_data, "write_failure", 0)
			as GFStorageAsyncResult.WriteFailureKind
		)
		var configured_value: bool = aggregate.configure_for_framework(
			request_id,
			GFVariantData.get_option_string_name(case_data, "operation"),
			"union/missing.json",
			GFVariantData.get_option_bool(case_data, "ok", false),
			GFVariantData.get_option_int(case_data, "error_code", ERR_BUG) as Error,
			case_read_result,
			case_write_failure,
			GFVariantData.get_option_dictionary(case_data, "write_report"),
			case_delete_result
		)
		assert_eq(
			configured_value,
			false,
			"判别联合不得接受非法终态：%s" % GFVariantData.get_option_string(case_data, "name")
		)
		assert_eq(aggregate.get_request_id(), 0, "拒绝必须发生在写入身份之前。")
		request_id += 1


func test_async_operation_delete_completion_checks_file_identity_and_emits_once() -> void:
	var contract: Dictionary = _delete_async_contract()
	if contract.is_empty():
		return
	var delete_operation: StringName = GFVariantData.get_option_string_name(
		contract,
		"delete_operation"
	)
	var delete_result_script_value: Variant = contract.get("delete_result_script")
	if not delete_result_script_value is GDScript:
		return
	var delete_result_script: GDScript = delete_result_script_value
	var delete_result: GFStorageDeleteResult = _make_missing_delete_result(delete_result_script)
	if delete_result == null:
		return

	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_eq(
		operation.configure_for_framework(701, delete_operation, "identity/expected.json"),
		true
	)
	var signal_results: Array[GFStorageAsyncResult] = []
	var connect_error: Error = operation.completed.connect(
		func(result: GFStorageAsyncResult) -> void:
			signal_results.append(result)
	) as Error
	assert_eq(connect_error, OK)
	var mismatched_result: GFStorageAsyncResult = _make_delete_async_result(
		701,
		delete_operation,
		"identity/other.json",
		delete_result
	)
	assert_false(operation.complete_for_framework(mismatched_result))
	assert_true(operation.is_pending())
	assert_eq(signal_results.size(), 0)

	var matching_result: GFStorageAsyncResult = _make_delete_async_result(
		701,
		delete_operation,
		"identity/expected.json",
		delete_result
	)
	assert_true(operation.complete_for_framework(matching_result))
	assert_true(operation.is_completed())
	assert_eq(signal_results.size(), 1)
	assert_false(operation.complete_for_framework(matching_result))
	assert_eq(signal_results.size(), 1, "operation 只能发布一个终态。")


func test_delete_operation_rejects_save_only_payload_attempt_binding() -> void:
	var contract: Dictionary = _delete_async_contract()
	if contract.is_empty():
		return
	var delete_operation: StringName = GFVariantData.get_option_string_name(
		contract,
		"delete_operation"
	)
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(operation.configure_for_framework(801, delete_operation, "identity/delete.json"))
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"value": 1,
	})
	assert_false(
		operation.configure_payload_attempt_for_framework(transfer, 1),
		"delete operation 不得关联 save-only payload attempt。"
	)
	assert_null(operation.get_payload_transfer())
	assert_true(transfer.release())


func _load_delete_result_script() -> GDScript:
	assert_true(
		ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH),
		"#87 必须提供 GFStorageDeleteResult 脚本。"
	)
	if not ResourceLoader.exists(_DELETE_RESULT_SCRIPT_PATH):
		return null
	var script_resource: Resource = load(_DELETE_RESULT_SCRIPT_PATH)
	assert_true(script_resource is GDScript)
	if script_resource is GDScript:
		var delete_result_script: GDScript = script_resource
		return delete_result_script
	return null


func _enum_values(script_resource: GDScript, enum_name: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(
		script_resource.get_script_constant_map(),
		enum_name
	)


func _new_delete_result(delete_result_script: GDScript) -> GFStorageDeleteResult:
	var instance_value: Variant = delete_result_script.new()
	assert_true(instance_value is GFStorageDeleteResult)
	if instance_value is GFStorageDeleteResult:
		var delete_result: GFStorageDeleteResult = instance_value
		return delete_result
	return null


func _make_missing_delete_result(delete_result_script: GDScript) -> GFStorageDeleteResult:
	var delete_result: GFStorageDeleteResult = _new_delete_result(delete_result_script)
	if delete_result == null:
		return null
	assert_true(
		delete_result.configure_for_framework(
			ERR_FILE_NOT_FOUND,
			GFStorageDeleteResult.FailureKind.NOT_FOUND,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
	)
	return delete_result


func _delete_async_contract() -> Dictionary:
	var delete_result_script: GDScript = _load_delete_result_script()
	if delete_result_script == null:
		return {}
	var operation_script_value: Variant = GFStorageAsyncOperation.new().get_script()
	assert_true(operation_script_value is GDScript)
	if not operation_script_value is GDScript:
		return {}
	var operation_script: GDScript = operation_script_value
	var operation_constants: Dictionary = operation_script.get_script_constant_map()
	assert_true(operation_constants.has("OPERATION_DELETE"))
	assert_true(GFStorageAsyncResult.new().has_method(&"get_delete_result"))
	if (
		not operation_constants.has("OPERATION_DELETE")
		or not GFStorageAsyncResult.new().has_method(&"get_delete_result")
	):
		return {}
	return {
		"delete_operation": operation_constants["OPERATION_DELETE"],
		"delete_result_script": delete_result_script,
	}


func _make_delete_async_result(
	request_id: int,
	delete_operation: StringName,
	file_name: String,
	delete_result: GFStorageDeleteResult
) -> GFStorageAsyncResult:
	var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(
		result.configure_for_framework(
			request_id,
			delete_operation,
			file_name,
			false,
			ERR_FILE_NOT_FOUND,
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			delete_result
		)
	)
	return result
