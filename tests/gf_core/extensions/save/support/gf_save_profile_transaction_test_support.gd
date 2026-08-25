## GFSaveProfileTransactionTestSupport: Save Profile 事务测试的受控存储与内存 Provider 夹具。
class_name GFSaveProfileTransactionTestSupport
extends RefCounted


# --- 公共方法 ---

static func make_provider(
	section_id: StringName,
	initial_value: int,
	shared_events: Array[String] = []
) -> MemorySectionProvider:
	var provider: MemorySectionProvider = MemorySectionProvider.new()
	provider.section_id = section_id
	provider.schema_version = 1
	provider.required_on_load = true
	provider.value = initial_value
	provider.shared_events = shared_events
	return provider


static func make_profile(
	profile_id: StringName,
	providers: Array[GFSaveSectionProvider],
	io_timeout_msec: int = 30_000
) -> GFSaveProfile:
	var profile: GFSaveProfile = GFSaveProfile.new()
	profile.profile_id = profile_id
	profile.file_name = "%s.sav" % String(profile_id)
	profile.schema_version = 1
	profile.providers = providers
	profile.recovery_policy.io_timeout_msec = io_timeout_msec
	return profile


static func make_document(profile: GFSaveProfile, payloads: Dictionary) -> GFSaveDocument:
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		profile.get_effective_schema_id(),
		profile.schema_version
	)
	for provider: GFSaveSectionProvider in profile.providers:
		var payload: Variant = GFVariantData.get_option_value(payloads, provider.section_id)
		var _section_set: bool = document.set_section(GFSaveSection.new().configure(
			provider.section_id,
			provider.schema_version,
			payload
		))
	return document


static func read_success(document: GFSaveDocument) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_success(document.to_dict())


static func read_failure(
	error_code: Error,
	error_message: String,
	failure_kind: GFStorageReadResult.FailureKind
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


static func get_saved_value(save_call: Dictionary, section_id: StringName) -> int:
	var data: Dictionary = GFVariantData.get_option_dictionary(save_call, "data")
	var document: GFSaveDocument = GFSaveDocument.from_dict(data)
	if document == null:
		return -1
	var section: GFSaveSection = document.get_section(section_id)
	if section == null:
		return -1
	var payload: Variant = section.get_payload()
	if not payload is Dictionary:
		return -1
	var payload_dictionary: Dictionary = payload
	return GFVariantData.get_option_int(payload_dictionary, "value", -1)


# --- 内部类 ---

class ControlledStorage extends GFStorageUtility:
	var save_calls: Array[Dictionary] = []
	var load_calls: PackedStringArray = PackedStringArray()
	var events: Array[String] = []
	var active_io_count: int = 0
	var max_active_io_count: int = 0
	var driver: GFSaveProfileUtility = null
	var enable_family_reset_authorization: bool = false
	var family_reset_authorization_current: bool = true
	var reset_call_count: int = 0
	var _next_request_id: int = 1
	var _next_authorization_id: int = 1
	var _pending_save_operations: Array[GFStorageAsyncOperation] = []
	var _pending_load_operations: Array[GFStorageAsyncOperation] = []
	var _pending_reset_operations: Array[GFStorageAsyncOperation] = []

	func save_data_request_async(
		file_name: String,
		data: Dictionary,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
		_record_save(file_name, data, operation.get_request_id())
		_pending_save_operations.append(operation)
		_begin_io()
		return operation

	func save_payload_request_async(
		file_name: String,
		transfer: GFStoragePayloadTransfer,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_SAVE,
			file_name
		)
		var attempt: Dictionary = (
			transfer.begin_attempt_for_framework(
				get_instance_id(),
				file_name,
				_get_async_file_key(file_name),
				_get_codec_options()
			)
			if transfer != null
			else {}
		)
		if not GFVariantData.get_option_bool(attempt, "ok"):
			_complete_operation(
				operation,
				ERR_INVALID_PARAMETER,
				null,
				GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			)
			return operation
		var attempt_id: int = GFVariantData.get_option_int(attempt, "attempt_id")
		var _configured_transfer: bool = operation.configure_payload_attempt_for_framework(
			transfer,
			attempt_id
		)
		_record_save(
			file_name,
			GFVariantData.get_option_dictionary(attempt, "payload"),
			operation.get_request_id()
		)
		_pending_save_operations.append(operation)
		_begin_io()
		return operation

	func load_data_request_async(
		file_name: String,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_LOAD,
			file_name
		)
		var _appended_load: bool = load_calls.append(file_name)
		events.append("load:%s" % file_name)
		_pending_load_operations.append(operation)
		_begin_io()
		return operation

	func create_family_reset_authorization(
		file_name: String,
		observed_result: GFStorageReadResult
	) -> GFStorageFamilyResetAuthorization:
		if (
			not enable_family_reset_authorization
			or observed_result == null
			or observed_result.ok
			or observed_result.failure_kind != GFStorageReadResult.FailureKind.CORRUPT
		):
			return super.create_family_reset_authorization(file_name, observed_result)
		var authorization: GFStorageFamilyResetAuthorization = (
			GFStorageFamilyResetAuthorization.new()
		)
		var configured: bool = authorization.configure_for_framework(
			_next_authorization_id,
			get_instance_id(),
			file_name,
			_get_async_file_key(file_name),
			"controlled-observation",
			GFStorageFamilyResetAuthorization.REASON_CORRUPT
		)
		if not configured:
			return null
		_next_authorization_id += 1
		return authorization

	func validate_family_reset_authorization_for_framework(
		file_name: String,
		authorization: GFStorageFamilyResetAuthorization
	) -> bool:
		events.append("revalidate:%s" % file_name)
		if not family_reset_authorization_current:
			if authorization != null:
				var _stale: bool = authorization.mark_stale_for_framework()
			return false
		return authorization != null and authorization.is_available()

	func reset_file_family_request_async(
		file_name: String,
		authorization: GFStorageFamilyResetAuthorization,
		options: GFStorageAsyncRequestOptions = null
	) -> GFStorageAsyncOperation:
		var _ignored_options: GFStorageAsyncRequestOptions = options
		var operation: GFStorageAsyncOperation = _make_operation(
			GFStorageAsyncOperation.OPERATION_RESET,
			file_name
		)
		var claimed: bool = (
			authorization != null
			and authorization.claim_for_framework(
				get_instance_id(),
				file_name,
				_get_async_file_key(file_name),
				"controlled-observation"
			)
		)
		if not claimed:
			var unauthorized: GFStorageFamilyResetResult = (
				GFStorageFamilyResetResult.new()
			)
			var _configured_unauthorized: bool = unauthorized.configure_for_framework(
				ERR_UNAUTHORIZED,
				GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				0,
				GFStorageFamilyResetResult.FamilyMember.NONE
			)
			_complete_operation(
				operation,
				ERR_UNAUTHORIZED,
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				unauthorized
			)
			return operation
		reset_call_count += 1
		events.append("reset:%s" % file_name)
		_pending_reset_operations.append(operation)
		_begin_io()
		return operation

	func complete_next_save(error_code: Error = OK) -> void:
		complete_save_at(0, error_code)

	func complete_save_at(index: int, error_code: Error = OK) -> void:
		if index < 0 or index >= _pending_save_operations.size():
			return
		var operation: GFStorageAsyncOperation = _pending_save_operations[index]
		_pending_save_operations.remove_at(index)
		_end_io()
		_complete_operation(operation, error_code, null)
		_tick_driver()

	func complete_next_load(result: GFStorageReadResult) -> void:
		complete_load_at(0, result)

	func complete_next_reset(
		reset_result: GFStorageFamilyResetResult = null
	) -> void:
		if _pending_reset_operations.is_empty():
			return
		var operation: GFStorageAsyncOperation = _pending_reset_operations.pop_front()
		var resolved_result: GFStorageFamilyResetResult = reset_result
		if resolved_result == null:
			resolved_result = GFStorageFamilyResetResult.new()
			var _configured_success: bool = resolved_result.configure_for_framework(
				OK,
				GFStorageFamilyResetResult.FailureKind.NONE,
				GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY,
				GFStorageFamilyResetResult.Phase.NONE,
				2,
				3,
				0,
				GFStorageFamilyResetResult.FamilyMember.NONE
			)
		_end_io()
		_complete_operation(
			operation,
			resolved_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			resolved_result
		)
		_tick_driver()

	func complete_load_at(index: int, result: GFStorageReadResult) -> void:
		if index < 0 or index >= _pending_load_operations.size() or result == null:
			return
		var operation: GFStorageAsyncOperation = _pending_load_operations[index]
		_pending_load_operations.remove_at(index)
		_end_io()
		_complete_operation(operation, result.error_code, result)
		_tick_driver()

	func complete_load_for_file(file_name: String, result: GFStorageReadResult) -> void:
		for index: int in range(_pending_load_operations.size()):
			var operation: GFStorageAsyncOperation = _pending_load_operations[index]
			if operation.get_file_name() == file_name:
				complete_load_at(index, result)
				return

	func get_pending_save_count() -> int:
		return _pending_save_operations.size()

	func get_pending_load_count() -> int:
		return _pending_load_operations.size()

	func get_pending_reset_count() -> int:
		return _pending_reset_operations.size()

	func get_pending_reset_request_id(index: int = 0) -> int:
		if index < 0 or index >= _pending_reset_operations.size():
			return 0
		return _pending_reset_operations[index].get_request_id()

	func get_pending_save_file_name(index: int = 0) -> String:
		if index < 0 or index >= _pending_save_operations.size():
			return ""
		return _pending_save_operations[index].get_file_name()

	func get_pending_load_file_name(index: int = 0) -> String:
		if index < 0 or index >= _pending_load_operations.size():
			return ""
		return _pending_load_operations[index].get_file_name()

	func _record_save(file_name: String, data: Dictionary, request_id: int) -> void:
		save_calls.append({
			"file_name": file_name,
			"data": data.duplicate(true),
			"request_id": request_id,
		})
		events.append("save:%s" % file_name)

	func _begin_io() -> void:
		active_io_count += 1
		max_active_io_count = maxi(max_active_io_count, active_io_count)

	func _end_io() -> void:
		active_io_count = maxi(active_io_count - 1, 0)

	func _tick_driver() -> void:
		if driver != null:
			driver.tick(0.0)

	func _make_operation(
		operation_kind: StringName,
		file_name: String
	) -> GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
		var _configured: bool = operation.configure_for_framework(
			_next_request_id,
			operation_kind,
			file_name
		)
		_next_request_id += 1
		return operation

	func _complete_operation(
		operation: GFStorageAsyncOperation,
		error_code: Error,
		read_result: GFStorageReadResult,
		write_failure_kind: GFStorageAsyncResult.WriteFailureKind = (
			GFStorageAsyncResult.WriteFailureKind.NONE
		),
		reset_result: GFStorageFamilyResetResult = null
	) -> void:
		var _finished_transfer: bool = operation.finish_payload_attempt_for_framework()
		var successful: bool = error_code == OK
		if operation.get_operation() == GFStorageAsyncOperation.OPERATION_LOAD:
			successful = read_result != null and read_result.ok
		var resolved_write_failure_kind: GFStorageAsyncResult.WriteFailureKind = (
			_resolve_write_failure_kind(
				operation.get_operation(),
				error_code,
				write_failure_kind
			)
		)
		var async_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
		var _configured: bool = async_result.configure_for_framework(
			operation.get_request_id(),
			operation.get_operation(),
			operation.get_file_name(),
			successful,
			error_code,
			read_result,
			resolved_write_failure_kind,
			{},
			null,
			GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT,
			reset_result
		)
		var _completed: bool = operation.complete_for_framework(async_result)

	static func _resolve_write_failure_kind(
		operation_kind: StringName,
		error_code: Error,
		requested_failure_kind: GFStorageAsyncResult.WriteFailureKind
	) -> GFStorageAsyncResult.WriteFailureKind:
		if operation_kind != GFStorageAsyncOperation.OPERATION_SAVE or error_code == OK:
			return GFStorageAsyncResult.WriteFailureKind.NONE
		if requested_failure_kind != GFStorageAsyncResult.WriteFailureKind.NONE:
			return requested_failure_kind
		match error_code:
			ERR_INVALID_PARAMETER:
				return GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			ERR_UNAVAILABLE:
				return GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
			ERR_CANT_CREATE:
				return GFStorageAsyncResult.WriteFailureKind.THREAD_START_FAILED
		return GFStorageAsyncResult.WriteFailureKind.IO_FAILED


class MemorySectionProvider extends GFSaveSectionProvider:
	var value: int = 0
	var fail_apply: bool = false
	var fail_rollback: bool = false
	var apply_count: int = 0
	var rollback_count: int = 0
	var shared_events: Array[String] = []
	var save_snapshot_callback: Callable = Callable()
	var apply_callback: Callable = Callable()
	var rollback_callback: Callable = Callable()

	func _begin_save_snapshot(
		_context: Dictionary = {}
	) -> GFSaveSectionSnapshotOperation:
		shared_events.append("prepare:%s" % String(section_id))
		if save_snapshot_callback.is_valid():
			save_snapshot_callback.call()
		return make_completed_snapshot({ "value": value })

	func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
		shared_events.append("capture:%s" % String(section_id))
		return make_section({ "value": value })

	func _apply_section(section: GFSaveSection, _context: Dictionary = {}) -> Error:
		shared_events.append("apply:%s" % String(section_id))
		apply_count += 1
		var payload: Variant = section.get_payload()
		if fail_apply or not payload is Dictionary:
			return ERR_INVALID_DATA
		var payload_dictionary: Dictionary = payload
		value = GFVariantData.get_option_int(payload_dictionary, "value")
		if apply_callback.is_valid():
			apply_callback.call()
		return OK

	func _rollback_section(section: GFSaveSection, _context: Dictionary = {}) -> Error:
		shared_events.append("rollback:%s" % String(section_id))
		rollback_count += 1
		var payload: Variant = section.get_payload()
		if fail_rollback or not payload is Dictionary:
			return ERR_CANT_RESOLVE
		var payload_dictionary: Dictionary = payload
		value = GFVariantData.get_option_int(payload_dictionary, "value")
		if rollback_callback.is_valid():
			rollback_callback.call()
		return OK
