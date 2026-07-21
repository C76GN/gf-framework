## GFSaveProfileUtility: 多 section 存档的异步协调器。
##
## 每个 profile 独立串行 IO；连续保存通过 generation 合并为最新后续写入。
## 读取在保存屏障后执行，并在主线程完成迁移、校验和 provider 事务化应用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSaveProfileUtility
extends GFUtility


# --- 信号 ---

## 任一 profile 操作进入终态时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 隔离终态结果。
signal profile_operation_completed(result: GFSaveProfileResult)

## profile 状态机发生变化时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @param previous_state: 变化前状态。
## [br]
## @param current_state: 变化后状态。
signal profile_state_changed(profile_id: StringName, previous_state: StringName, current_state: StringName)


# --- 常量 ---

## Profile 空闲。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_IDLE: StringName = &"idle"

## 正在同步采集 section。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_GATHERING: StringName = &"gathering"

## 正在等待保存 IO。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_SAVING: StringName = &"saving"

## 正在等待读取 IO。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_LOADING: StringName = &"loading"

## 正在等待有界重试截止时间。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_RETRY_WAIT: StringName = &"retry_wait"

## 正在迁移、校验或事务化应用 section。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_APPLYING: StringName = &"applying"

## Utility 已释放。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_DISPOSED: StringName = &"disposed"


# --- 私有变量 ---

var _storage: GFStorageUtility = null
var _clock: GFClock = null
var _clock_explicit: bool = false
var _storage_explicit: bool = false
var _states: Dictionary = {}
var _disposed: bool = false
var _dispose_requested: bool = false
var _processing_depth: int = 0
var _unsafe_callback_depth: int = 0
var _pending_completion_operations: Array[GFSaveProfileOperation] = []
var _emitting_completions: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_clock = GFClock.new()
	tick_enabled = true
	ignore_pause = true
	ignore_time_scale = true


# --- GF 生命周期方法 ---

## 在架构 ready 阶段采用已注册的 Storage 和 Time 服务。
##
## `setup()` 显式注入的依赖不会被覆盖。
## [br]
## @api public
## [br]
## @since unreleased
func ready() -> void:
	if not _storage_explicit:
		var storage_value: Variant = get_utility(GFStorageUtility)
		if storage_value is GFStorageUtility:
			var architecture_storage: GFStorageUtility = storage_value
			_set_storage(architecture_storage)
	if not _clock_explicit:
		var time_value: Variant = get_utility(GFTimeProvider)
		if time_value is GFTimeProvider:
			var time_provider: GFTimeProvider = time_value
			_clock = time_provider.get_clock()


## 推进到期重试。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 未使用；重试只读取注入时钟的单调时间。
func tick(_delta: float) -> void:
	if _disposed:
		return
	_begin_processing()
	var now_msec: int = _clock.get_monotonic_msec()
	for state_value: Variant in _states.values():
		var state: ProfileState = _get_state_value(state_value)
		if state == null:
			continue
		if state.mode == STATE_RETRY_WAIT and now_msec >= state.retry_due_msec:
			_retry_current_io(state)
		elif (
			state.mode in [STATE_SAVING, STATE_LOADING]
			and state.current_storage_operation != null
			and not state.current_storage_operation.is_completed()
			and now_msec >= state.current_io_deadline_msec
		):
			_handle_current_io_timeout(state)
	_end_processing()


## 终止所有未完成操作并释放底层信号连接。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	if _processing_depth > 0:
		_dispose_requested = true
		return
	_dispose_now()
	_drain_completion_events()


# --- 公共方法 ---

## 显式注入底层存储和可选时钟。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param storage: 底层事务存储工具。
## [br]
## @param clock: 可选单调时钟；为空时保留当前时钟。
## [br]
## @return 当前 Utility；参数无效、已释放或已有注册 profile 时返回 null。
func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveProfileUtility:
	if _disposed or _unsafe_callback_depth > 0 or storage == null or not _states.is_empty():
		return null
	_storage_explicit = true
	_set_storage(storage)
	if clock != null:
		_clock = clock
		_clock_explicit = true
	return self


## 注册一个 profile 及其可选迁移注册表。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile: profile 声明和 section providers。
## [br]
## @param migrations: 该 profile 的迁移注册表。
## [br]
## @return 包含 registered、规范文件名和全部校验问题的结构化报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with registered, profile_id, schema_id, canonical_file_name, issues, counts, summary, and next_actions.
func register_profile(
	profile: GFSaveProfile,
	migrations: GFSaveMigrationRegistry = null
) -> Dictionary:
	var report: Dictionary = {"issues": []}
	if profile != null:
		_append_report_issues(report, profile.validate_profile())
	else:
		_append_registration_issue(report, &"missing_profile", "Profile is required.", "profile")
	if _disposed:
		_append_registration_issue(report, &"utility_disposed", "Save Profile Utility is disposed.", "utility")
	if _unsafe_callback_depth > 0:
		_append_registration_issue(report, &"reentrant_registration", "Profile registration is not allowed from a Provider or state callback.", "utility")
	if _storage == null:
		_append_registration_issue(report, &"storage_unconfigured", "GFStorageUtility must be configured before registration.", "storage")
	var canonical_file_name: String = ""
	if profile != null and _storage != null and not profile.file_name.is_empty():
		canonical_file_name = _storage.canonicalize_data_file_name(profile.file_name)
		if canonical_file_name.is_empty():
			_append_registration_issue(report, &"invalid_storage_path", "Profile file name violates the active Storage path policy.", "file_name")
	if profile != null and _states.has(profile.profile_id):
		_append_registration_issue(report, &"duplicate_profile_id", "Profile id is already registered.", "profile_id")
	for state_value: Variant in _states.values():
		var existing: ProfileState = _get_state_value(state_value)
		if existing != null and not canonical_file_name.is_empty() and existing.file_name == canonical_file_name:
			_append_registration_issue(report, &"duplicate_storage_target", "Canonical storage target is already owned by another Profile.", "file_name")
	if not GFVariantData.get_option_array(report, "issues").is_empty():
		return _finalize_registration_report(report, profile, canonical_file_name, false)
	var state: ProfileState = ProfileState.new()
	state.profile_id = profile.profile_id
	state.schema_id = profile.get_effective_schema_id()
	state.file_name = canonical_file_name
	state.schema_version = profile.schema_version
	state.schema = profile.build_schema()
	state.providers = profile.get_providers()
	state.recovery_policy = _duplicate_recovery_policy(profile.recovery_policy)
	state.save_enabled = profile.save_enabled
	state.load_enabled = profile.load_enabled
	state.unknown_section_policy = profile.unknown_section_policy
	for provider: GFSaveSectionProvider in state.providers:
		if provider == null or not provider.lock_definition_for_framework():
			_append_registration_issue(report, &"provider_lock_failed", "Provider could not be locked for runtime ownership.", "providers")
			return _finalize_registration_report(report, profile, canonical_file_name, false)
	state.migrations = migrations
	_states[profile.profile_id] = state
	return _finalize_registration_report(report, profile, canonical_file_name, true)


## 注销空闲 profile。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @return profile 存在且没有未完成操作时返回 true。
func unregister_profile(profile_id: StringName) -> bool:
	var state: ProfileState = _get_state(profile_id)
	if (
		_dispose_requested
		or _unsafe_callback_depth > 0
		or state == null
		or state.mode != STATE_IDLE
		or _has_pending_operations(state)
		or not state.detached_write_operations.is_empty()
	):
		return false
	var _erased: bool = _states.erase(profile_id)
	return true


## 请求异步保存 profile。
##
## 在途写入期间的新请求只保留最新 generation；每个句柄在覆盖自身 generation
## 的写入成功或失败后完成。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @param metadata: 写入文档的持久化元数据。
## [br]
## @param context: provider 采集使用的临时上下文。
## [br]
## @schema metadata: Dictionary with caller-defined persisted document metadata.
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return 保存操作句柄；无效请求返回已失败句柄。
func save_profile(
	profile_id: StringName,
	metadata: Dictionary = {},
	context: Dictionary = {}
) -> GFSaveProfileOperation:
	var state: ProfileState = _get_state(profile_id)
	if state == null or _disposed:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Save profile is not registered."
		)
	if not state.save_enabled:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Save is disabled for this Profile."
		)
	if _unsafe_callback_depth > 0 or _is_load_active(state):
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Save is not accepted during load/apply or a Provider callback."
		)
	_begin_processing()
	state.generation += 1
	state.latest_save_metadata = metadata.duplicate(true)
	state.latest_save_context = context.duplicate(true)
	var operation: GFSaveProfileOperation = _make_operation(
		GFSaveProfileOperation.OPERATION_SAVE,
		profile_id,
		state.generation,
		context,
		metadata
	)
	state.save_operations.append(operation)
	_schedule(state)
	_end_processing()
	return operation


## 请求异步读取、迁移、校验并应用 profile。
##
## 调用时捕获当前 generation 作为写入屏障；相关保存失败时读取不会静默读取旧文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @param context: 迁移和 provider 应用使用的临时上下文。
## [br]
## @param metadata: 仅写入终态结果的调用方元数据。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @schema metadata: Dictionary with caller-defined result metadata.
## [br]
## @return 读取操作句柄；无效请求返回已失败句柄。
func load_profile(
	profile_id: StringName,
	context: Dictionary = {},
	metadata: Dictionary = {}
) -> GFSaveProfileOperation:
	var state: ProfileState = _get_state(profile_id)
	if state == null or _disposed:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_LOAD,
			profile_id,
			GFSaveProfileResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Save profile is not registered."
		)
	if not state.load_enabled:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_LOAD,
			profile_id,
			GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Load is disabled for this Profile."
		)
	if _unsafe_callback_depth > 0:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_LOAD,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Load is not accepted from a Provider or state callback."
		)
	_begin_processing()
	var operation: GFSaveProfileOperation = _make_operation(
		GFSaveProfileOperation.OPERATION_LOAD,
		profile_id,
		state.generation,
		context,
		metadata
	)
	state.load_operations.append(operation)
	_schedule(state)
	_end_processing()
	return operation


## 等待调用时可见的最新 generation 持久化。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @param metadata: 仅写入终态结果的调用方元数据。
## [br]
## @schema metadata: Dictionary with caller-defined result metadata.
## [br]
## @return flush 操作句柄；没有待保存 generation 时立即成功。
func flush_profile(
	profile_id: StringName,
	metadata: Dictionary = {}
) -> GFSaveProfileOperation:
	var state: ProfileState = _get_state(profile_id)
	if state == null or _disposed:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_FLUSH,
			profile_id,
			GFSaveProfileResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Save profile is not registered."
		)
	if not state.save_enabled:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_FLUSH,
			profile_id,
			GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Flush is disabled for this Profile."
		)
	if _unsafe_callback_depth > 0:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_FLUSH,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Flush is not accepted from a Provider or state callback."
		)
	_begin_processing()
	var operation: GFSaveProfileOperation = _make_operation(
		GFSaveProfileOperation.OPERATION_FLUSH,
		profile_id,
		state.generation,
		{},
		metadata
	)
	state.flush_operations.append(operation)
	_complete_ready_flushes(state)
	_schedule(state)
	_end_processing()
	return operation


## 获取已成功持久化的 generation。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @return 未注册或从未保存时返回 0。
func get_persisted_generation(profile_id: StringName) -> int:
	var state: ProfileState = _get_state(profile_id)
	return state.persisted_generation if state != null else 0


## 获取稳定状态机快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: profile ID。
## [br]
## @return profile 状态摘要；未注册时为空字典。
## [br]
## @schema return: Dictionary with profile identity, generation evidence, detached writes, and queue counts.
func get_profile_state_snapshot(profile_id: StringName) -> Dictionary:
	var state: ProfileState = _get_state(profile_id)
	if state == null:
		return {}
	return {
		"profile_id": profile_id,
		"schema_id": state.schema_id,
		"state": state.mode,
		"generation": state.generation,
		"persisted_generation": state.persisted_generation,
		"failed_generation": state.last_failed_generation,
		"save_queue_size": state.save_operations.size(),
		"load_queue_size": state.load_operations.size(),
		"flush_queue_size": state.flush_operations.size(),
		"current_generation": state.current_generation,
		"attempt_count": state.current_attempt_count,
		"write_outcome_unknown": not state.unknown_write_generations.is_empty(),
		"unknown_write_generations": _get_sorted_generation_keys(state.unknown_write_generations),
		"detached_write_count": state.detached_write_operations.size(),
		"detached_storage_request_ids": _get_sorted_request_ids(state.detached_write_operations),
	}


# --- 私有/辅助方法 ---

func _schedule(state: ProfileState) -> void:
	if _disposed or _dispose_requested or state == null:
		return
	if state.is_scheduling:
		state.schedule_requested = true
		return
	state.is_scheduling = true
	state.schedule_requested = true
	while state.schedule_requested and not _disposed and not _dispose_requested:
		state.schedule_requested = false
		while state.mode == STATE_IDLE and not _disposed and not _dispose_requested:
			_complete_ready_flushes(state)
			if not state.save_operations.is_empty():
				_start_save(state)
				if state.mode != STATE_IDLE:
					break
				continue
			if state.load_operations.is_empty():
				break
			var load_operation: GFSaveProfileOperation = state.load_operations.pop_front()
			var barrier_failure: Dictionary = _get_barrier_failure(
				state,
				load_operation.get_requested_generation()
			)
			if not barrier_failure.is_empty():
				_complete_operation(
					state,
					load_operation,
					false,
					GFVariantData.get_option_string_name(barrier_failure, "status"),
					_get_error_code(barrier_failure, "error_code", FAILED),
					"Load barrier failed: %s" % GFVariantData.get_option_string(
						barrier_failure,
						"error"
					),
					barrier_failure
				)
				continue
			_start_load(state, load_operation)
			break
	state.is_scheduling = false


func _start_save(state: ProfileState) -> void:
	state.current_kind = GFSaveProfileOperation.OPERATION_SAVE
	state.current_generation = state.generation
	state.current_attempt_count = 0
	state.current_storage_request_ids = PackedInt64Array()
	state.current_context = state.latest_save_context.duplicate(true)
	state.current_metadata = state.latest_save_metadata.duplicate(true)
	_mark_save_operations_running(state, state.current_generation)
	_set_mode(state, STATE_GATHERING)
	var gather_result: Dictionary = _gather_document(state)
	if _dispose_requested:
		return
	var document: GFSaveDocument = _get_document_value(
		GFVariantData.get_option_value(gather_result, "document")
	)
	if document == null:
		var failed_section_id: StringName = GFVariantData.get_option_string_name(
			gather_result,
			"failed_section_id"
		)
		_finish_save_failure(
			state,
			_get_error_code(gather_result, "error_code", ERR_INVALID_DATA),
			GFVariantData.get_option_string(gather_result, "error", "Save section gathering failed."),
			GFSaveProfileResult.STATUS_GATHER_FAILED,
			failed_section_id
		)
		return
	state.current_document = document
	_set_mode(state, STATE_SAVING)
	_start_current_save_io(state)


func _start_load(state: ProfileState, operation: GFSaveProfileOperation) -> void:
	state.current_kind = GFSaveProfileOperation.OPERATION_LOAD
	state.current_load_operation = operation
	state.current_generation = operation.get_requested_generation()
	state.current_attempt_count = 0
	state.current_storage_request_ids = PackedInt64Array()
	state.current_context = operation.get_context_for_framework()
	state.current_metadata = operation.get_metadata_for_framework()
	var _started: bool = operation.start_for_framework()
	_set_mode(state, STATE_LOADING)
	if _dispose_requested:
		return
	_start_current_load_io(state)


func _start_current_save_io(state: ProfileState) -> void:
	if _disposed or _dispose_requested:
		return
	if _storage == null:
		_finish_save_failure(
			state,
			ERR_UNCONFIGURED,
			"GFStorageUtility is not configured.",
			GFSaveProfileResult.STATUS_STORAGE_FAILED
		)
		return
	state.current_attempt_count += 1
	var operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		state.file_name,
		state.current_document.to_dict()
	)
	_observe_storage_operation(state, operation)


func _start_current_load_io(state: ProfileState) -> void:
	if _disposed or _dispose_requested:
		return
	if _storage == null:
		_finish_load_failure(
			state,
			GFSaveProfileResult.STATUS_STORAGE_FAILED,
			ERR_UNCONFIGURED,
			"GFStorageUtility is not configured."
		)
		return
	state.current_attempt_count += 1
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(state.file_name)
	_observe_storage_operation(state, operation)


func _retry_current_io(state: ProfileState) -> void:
	if _disposed or _dispose_requested:
		return
	state.retry_due_msec = 0
	if state.current_kind == GFSaveProfileOperation.OPERATION_SAVE:
		_set_mode(state, STATE_SAVING)
		_start_current_save_io(state)
	elif state.current_kind == GFSaveProfileOperation.OPERATION_LOAD:
		_set_mode(state, STATE_LOADING)
		_start_current_load_io(state)


func _schedule_retry(state: ProfileState, error_code: Error) -> bool:
	var policy: GFSaveRecoveryPolicy = state.recovery_policy
	if policy == null or not policy.can_retry(error_code, state.current_attempt_count):
		return false
	var delay_msec: int = policy.get_retry_delay_msec(state.current_attempt_count)
	if delay_msec <= 0:
		return false
	state.retry_due_msec = _clock.get_monotonic_msec() + delay_msec
	_set_mode(state, STATE_RETRY_WAIT)
	return true


# 存储终态

func _on_storage_operation_completed(
	result: GFStorageAsyncResult,
	profile_id: StringName,
	request_id: int
) -> void:
	if _disposed:
		return
	_begin_processing()
	var state: ProfileState = _get_state(profile_id)
	if (
		state == null
		or state.current_storage_operation == null
		or state.current_storage_operation.get_request_id() != request_id
		or result == null
		or result.get_request_id() != request_id
	):
		_end_processing()
		return
	_clear_current_storage_operation(state)
	if result.get_operation() == GFStorageAsyncOperation.OPERATION_SAVE:
		if not result.is_successful():
			_handle_save_failure(state, result.get_error_code(), "Storage save failed.")
		else:
			state.persisted_generation = maxi(state.persisted_generation, state.current_generation)
			_clear_generation_evidence_through(state, state.current_generation)
			_complete_save_operations_success(state)
			_clear_current(state)
			_set_mode(state, STATE_IDLE)
			_complete_ready_flushes(state)
			_schedule(state)
	elif result.get_operation() == GFStorageAsyncOperation.OPERATION_LOAD:
		var read_result: GFStorageReadResult = result.get_read_result()
		if read_result == null:
			_handle_load_failure(
				state,
				GFStorageReadResult.new().configure_failure(
					"Storage returned no read result.",
					FAILED,
					{},
					GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
					0,
					GFStorageReadResult.FailureKind.IO_FAILED
				)
			)
		elif not read_result.ok or not read_result.is_integrity_accepted():
			_handle_load_failure(state, read_result)
		else:
			_process_loaded_document(state, read_result)
	_end_processing()


func _handle_save_failure(state: ProfileState, error_code: Error, error: String) -> void:
	if _schedule_retry(state, error_code):
		return
	_finish_save_failure(
		state,
		error_code,
		error,
		(
			GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN
			if state.unknown_write_generations.has(state.current_generation)
			else GFSaveProfileResult.STATUS_STORAGE_FAILED
		)
	)


func _handle_load_failure(state: ProfileState, result: GFStorageReadResult) -> void:
	if _schedule_retry(state, result.error_code):
		return
	var status: StringName = GFSaveProfileResult.STATUS_STORAGE_FAILED
	var recovery_action: StringName = GFSaveRecoveryPolicy.ACTION_FAIL
	if result.failure_kind == GFStorageReadResult.FailureKind.FUTURE_VERSION:
		status = GFSaveProfileResult.STATUS_FUTURE_SCHEMA
	elif result.failure_kind == GFStorageReadResult.FailureKind.MIGRATION_FAILED:
		status = GFSaveProfileResult.STATUS_MIGRATION_FAILED
	elif result.failure_kind == GFStorageReadResult.FailureKind.NOT_FOUND:
		status = GFSaveProfileResult.STATUS_MISSING
		recovery_action = state.recovery_policy.missing_file_action
	elif (
		result.failure_kind == GFStorageReadResult.FailureKind.CORRUPT
		or not result.is_integrity_accepted()
	):
		status = GFSaveProfileResult.STATUS_CORRUPT
		recovery_action = state.recovery_policy.corrupt_file_action
	if recovery_action == GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE:
		_finish_load_success(
			state,
			GFSaveProfileResult.STATUS_RECOVERED,
			{
				"recovered": true,
				"recovery_action": recovery_action,
				"storage_result": result,
			}
		)
		return
	_finish_load_failure(
		state,
		status,
		result.error_code,
		result.error,
		{"storage_result": result}
	)


# 文档与 provider 事务

func _gather_document(state: ProfileState) -> Dictionary:
	var sections: Array[GFSaveSection] = []
	for provider: GFSaveSectionProvider in state.providers:
		if provider == null or not provider.save_enabled:
			continue
		_enter_unsafe_callback()
		var section: GFSaveSection = provider.gather_section(state.current_context)
		_exit_unsafe_callback()
		if section == null:
			return {
				"error_code": ERR_INVALID_DATA,
				"error": "Save section provider failed to gather a valid section.",
				"failed_section_id": provider.section_id,
			}
		sections.append(section)
	if state.unknown_section_policy == GFSaveProfile.UNKNOWN_SECTION_PRESERVE:
		for preserved: GFSaveSection in state.preserved_unknown_sections:
			if preserved != null:
				sections.append(preserved.duplicate_section())
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		state.schema_id,
		state.schema_version,
		sections,
		state.current_metadata
	)
	var validation: Dictionary = state.schema.validate_document(document, true)
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return {
			"error_code": ERR_INVALID_DATA,
			"error": _get_first_validation_message(validation, "Gathered save document is invalid."),
			"validation_report": validation,
		}
	return {"document": document}


func _process_loaded_document(state: ProfileState, storage_result: GFStorageReadResult) -> void:
	_set_mode(state, STATE_APPLYING)
	var inspection: Dictionary = GFSaveDocument.inspect_dict(storage_result.payload)
	if not GFVariantData.get_option_bool(inspection, "ok", false):
		_handle_corrupt_document(state, storage_result, inspection)
		return
	var document: GFSaveDocument = GFSaveDocument.from_dict(storage_result.payload)
	if document == null:
		_handle_corrupt_document(state, storage_result, inspection)
		return
	if document.get_schema_id() != state.schema_id:
		_finish_load_failure(
			state,
			GFSaveProfileResult.STATUS_SCHEMA_MISMATCH,
			ERR_INVALID_DATA,
			"Save document schema id does not match the profile.",
			{"document": document, "storage_result": storage_result, "validation_report": inspection}
		)
		return
	if _has_future_schema(state, document):
		_finish_load_failure(
			state,
			GFSaveProfileResult.STATUS_FUTURE_SCHEMA,
			ERR_INVALID_DATA,
			"Save document uses a newer schema version.",
			{"document": document, "storage_result": storage_result, "validation_report": inspection}
		)
		return
	var schema: GFSaveDocumentSchema = state.schema
	var migration_result: GFSaveMigrationResult = null
	if _needs_migration(state, document):
		if state.migrations == null:
			_finish_load_failure(
				state,
				GFSaveProfileResult.STATUS_MIGRATION_FAILED,
				ERR_DOES_NOT_EXIST,
				"Save document requires a migration registry.",
				{"document": document, "storage_result": storage_result}
			)
			return
		migration_result = state.migrations.migrate(document, schema, state.current_context)
		if migration_result == null or not migration_result.is_successful():
			_finish_load_failure(
				state,
				GFSaveProfileResult.STATUS_MIGRATION_FAILED,
				migration_result.get_error_code() if migration_result != null else FAILED,
				migration_result.get_error() if migration_result != null else "Save migration returned no result.",
				{
					"document": document,
					"storage_result": storage_result,
					"migration_result": migration_result,
				}
			)
			return
		document = migration_result.get_document()
	var validation: Dictionary = schema.validate_document(document, true)
	if not GFVariantData.get_option_bool(validation, "ok", false):
		var status: StringName = (
			GFSaveProfileResult.STATUS_FUTURE_SCHEMA
			if _report_has_issue(validation, &"future_schema_version")
			else GFSaveProfileResult.STATUS_VALIDATION_FAILED
		)
		_finish_load_failure(
			state,
			status,
			ERR_INVALID_DATA,
			_get_first_validation_message(validation, "Save document validation failed."),
			{
				"document": document,
				"storage_result": storage_result,
				"migration_result": migration_result,
				"validation_report": validation,
			}
		)
		return
	var apply_result: Dictionary = _apply_document_transactionally(
		state,
		document,
		state.current_context
	)
	if not GFVariantData.get_option_bool(apply_result, "ok", false):
		var rollback_errors: Array[GFSaveRollbackFailure] = _get_rollback_failure_array(
			GFVariantData.get_option_value(apply_result, "rollback_errors", [])
		)
		var failure_stage: StringName = GFVariantData.get_option_string_name(
			apply_result,
			"failure_stage"
		)
		var status: StringName = GFSaveProfileResult.STATUS_APPLY_FAILED
		if failure_stage == &"snapshot":
			status = GFSaveProfileResult.STATUS_SNAPSHOT_FAILED
		elif not rollback_errors.is_empty():
			status = GFSaveProfileResult.STATUS_ROLLBACK_FAILED
		_finish_load_failure(
			state,
			status,
			_get_error_code(apply_result, "error_code", ERR_INVALID_DATA),
			GFVariantData.get_option_string(apply_result, "error", "Save section apply failed."),
			{
				"document": document,
				"storage_result": storage_result,
				"migration_result": migration_result,
				"validation_report": validation,
				"failed_section_id": GFVariantData.get_option_string_name(
					apply_result,
					"failed_section_id"
				),
				"rollback_errors": rollback_errors,
			}
		)
		return
	_update_preserved_unknown_sections(state, document)
	_finish_load_success(
		state,
		GFSaveProfileResult.STATUS_LOADED,
		{
			"document": document,
			"storage_result": storage_result,
			"migration_result": migration_result,
			"validation_report": validation,
		}
	)


func _apply_document_transactionally(
	state: ProfileState,
	document: GFSaveDocument,
	context: Dictionary
) -> Dictionary:
	var providers: Array[GFSaveSectionProvider] = []
	var snapshots: Dictionary = {}
	for provider: GFSaveSectionProvider in state.providers:
		if provider == null or not provider.load_enabled or not document.has_section(provider.section_id):
			continue
		_enter_unsafe_callback()
		var snapshot: GFSaveSection = provider.capture_section(context)
		_exit_unsafe_callback()
		if snapshot == null:
			return {
				"ok": false,
				"error_code": ERR_INVALID_DATA,
				"error": "Save section provider failed to capture a rollback snapshot.",
				"failed_section_id": provider.section_id,
				"rollback_errors": [],
				"failure_stage": &"snapshot",
			}
		providers.append(provider)
		snapshots[provider.section_id] = snapshot
	var attempted: Array[GFSaveSectionProvider] = []
	for provider: GFSaveSectionProvider in providers:
		attempted.append(provider)
		_enter_unsafe_callback()
		var apply_error: Error = provider.apply_section(
			document.get_section(provider.section_id),
			context
		)
		_exit_unsafe_callback()
		if apply_error == OK:
			continue
		var rollback_errors: Array[GFSaveRollbackFailure] = _rollback_providers(
			attempted,
			snapshots,
			context
		)
		return {
			"ok": false,
			"error_code": apply_error,
			"error": "Save section provider failed to apply its section.",
			"failed_section_id": provider.section_id,
			"rollback_errors": rollback_errors,
		}
	return {"ok": true}


func _rollback_providers(
	attempted: Array[GFSaveSectionProvider],
	snapshots: Dictionary,
	context: Dictionary
) -> Array[GFSaveRollbackFailure]:
	var errors: Array[GFSaveRollbackFailure] = []
	for index: int in range(attempted.size() - 1, -1, -1):
		var provider: GFSaveSectionProvider = attempted[index]
		var snapshot: GFSaveSection = _get_section_value(
			GFVariantData.get_option_value(snapshots, provider.section_id)
		)
		_enter_unsafe_callback()
		var rollback_error: Error = provider.rollback_section(snapshot, context)
		_exit_unsafe_callback()
		if rollback_error != OK:
			var failure: GFSaveRollbackFailure = GFSaveRollbackFailure.new()
			var _configured: bool = failure.configure_for_framework(provider.section_id, rollback_error)
			errors.append(failure)
	return errors


func _handle_corrupt_document(
	state: ProfileState,
	storage_result: GFStorageReadResult,
	validation_report: Dictionary
) -> void:
	var action: StringName = state.recovery_policy.corrupt_file_action
	if action == GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE:
		_finish_load_success(
			state,
			GFSaveProfileResult.STATUS_RECOVERED,
			{
				"recovered": true,
				"recovery_action": action,
				"storage_result": storage_result,
				"validation_report": validation_report,
			}
		)
		return
	_finish_load_failure(
		state,
		GFSaveProfileResult.STATUS_CORRUPT,
		ERR_FILE_CORRUPT,
		_get_first_validation_message(validation_report, "Save document is malformed."),
		{"storage_result": storage_result, "validation_report": validation_report}
	)


# 完成与清理

func _complete_save_operations_success(state: ProfileState) -> void:
	var remaining: Array[GFSaveProfileOperation] = []
	for operation: GFSaveProfileOperation in state.save_operations:
		if operation.get_requested_generation() <= state.current_generation:
			_complete_operation(
				state,
				operation,
				true,
				GFSaveProfileResult.STATUS_SAVED,
				OK,
				"",
				{
					"document": state.current_document,
					"attempt_count": state.current_attempt_count,
					"coalesced": operation.get_requested_generation() < state.current_generation,
					"storage_request_ids": state.current_storage_request_ids,
				}
			)
		else:
			remaining.append(operation)
	state.save_operations = remaining
	if state.current_generation >= state.generation:
		state.latest_save_context.clear()
		state.latest_save_metadata.clear()


func _finish_save_failure(
	state: ProfileState,
	error_code: Error,
	error: String,
	status: StringName,
	failed_section_id: StringName = &""
) -> void:
	_record_generation_failure(
		state,
		state.current_generation,
		status,
		error_code,
		error,
		failed_section_id,
		state.current_storage_request_ids
	)
	state.last_failed_generation = maxi(state.last_failed_generation, state.current_generation)
	state.last_failure_status = status
	state.last_failure_error_code = error_code
	state.last_failure_error = error
	state.last_failure_section_id = failed_section_id
	var remaining: Array[GFSaveProfileOperation] = []
	for operation: GFSaveProfileOperation in state.save_operations:
		if operation.get_requested_generation() <= state.current_generation:
			_complete_operation(
				state,
				operation,
				false,
				status,
				error_code,
				error,
				{
					"document": state.current_document,
					"attempt_count": state.current_attempt_count,
					"failed_section_id": failed_section_id,
					"storage_request_ids": state.current_storage_request_ids,
				}
			)
		else:
			remaining.append(operation)
	state.save_operations = remaining
	if state.current_generation >= state.generation:
		state.latest_save_context.clear()
		state.latest_save_metadata.clear()
	_clear_current(state)
	_set_mode(state, STATE_IDLE)
	_complete_ready_flushes(state)
	_schedule(state)


func _finish_load_success(
	state: ProfileState,
	status: StringName,
	options: Dictionary = {}
) -> void:
	var operation: GFSaveProfileOperation = state.current_load_operation
	var result_options: Dictionary = options.duplicate(true)
	result_options["attempt_count"] = state.current_attempt_count
	result_options["storage_request_ids"] = state.current_storage_request_ids
	_complete_operation(state, operation, true, status, OK, "", result_options)
	_clear_current(state)
	_set_mode(state, STATE_IDLE)
	_schedule(state)


func _finish_load_failure(
	state: ProfileState,
	status: StringName,
	error_code: Error,
	error: String,
	options: Dictionary = {}
) -> void:
	var operation: GFSaveProfileOperation = state.current_load_operation
	var result_options: Dictionary = options.duplicate(true)
	result_options["attempt_count"] = state.current_attempt_count
	result_options["storage_request_ids"] = state.current_storage_request_ids
	_complete_operation(state, operation, false, status, error_code, error, result_options)
	_clear_current(state)
	_set_mode(state, STATE_IDLE)
	_schedule(state)


func _complete_ready_flushes(state: ProfileState) -> void:
	var remaining: Array[GFSaveProfileOperation] = []
	for operation: GFSaveProfileOperation in state.flush_operations:
		var target: int = operation.get_requested_generation()
		if target <= state.persisted_generation:
			var _started: bool = operation.start_for_framework()
			_complete_operation(
				state,
				operation,
				true,
				GFSaveProfileResult.STATUS_FLUSHED,
				OK,
				""
			)
		elif _has_pending_save_covering_generation(state, target):
			remaining.append(operation)
		else:
			var barrier_failure: Dictionary = _get_barrier_failure(state, target)
			if barrier_failure.is_empty():
				remaining.append(operation)
				continue
			var _started: bool = operation.start_for_framework()
			_complete_operation(
				state,
				operation,
				false,
				GFVariantData.get_option_string_name(barrier_failure, "status"),
				_get_error_code(barrier_failure, "error_code", FAILED),
				"Flush target generation failed: %s" % GFVariantData.get_option_string(
					barrier_failure,
					"error"
				),
				barrier_failure
			)
	state.flush_operations = remaining


func _complete_operation(
	state: ProfileState,
	operation: GFSaveProfileOperation,
	ok: bool,
	status: StringName,
	error_code: Error,
	error: String,
	options: Dictionary = {}
) -> void:
	if operation == null or operation.is_completed():
		return
	var result: GFSaveProfileResult = GFSaveProfileResult.new()
	result.configure_for_framework(
		ok,
		status,
		operation.get_operation(),
		operation.get_profile_id(),
		operation.get_requested_generation(),
		state.persisted_generation if state != null else 0,
		GFVariantData.get_option_int(options, "attempt_count"),
		operation.get_started_at_msec_for_framework(),
		_clock.get_monotonic_msec(),
		GFVariantData.get_option_bool(options, "coalesced"),
		GFVariantData.get_option_bool(options, "recovered"),
		GFVariantData.get_option_string_name(options, "recovery_action"),
		GFVariantData.get_option_string_name(options, "failed_section_id"),
		error_code,
		error,
		_get_document_value(GFVariantData.get_option_value(options, "document")),
		_get_storage_result_value(GFVariantData.get_option_value(options, "storage_result")),
		_get_migration_result_value(GFVariantData.get_option_value(options, "migration_result")),
		GFVariantData.get_option_dictionary(options, "validation_report"),
		_get_rollback_failure_array(GFVariantData.get_option_value(options, "rollback_errors", [])),
		operation.get_metadata_for_framework(),
		_get_request_id_array(GFVariantData.get_option_value(options, "storage_request_ids"))
	)
	if operation.complete_for_framework(result):
		_pending_completion_operations.append(operation)


func _complete_all_pending_as_disposed(state: ProfileState) -> void:
	for operation: GFSaveProfileOperation in state.save_operations:
		var unknown_request_ids: PackedInt64Array = _get_disposal_unknown_request_ids(
			state,
			operation.get_requested_generation()
		)
		var unknown: bool = not unknown_request_ids.is_empty()
		_complete_operation(
			state,
			operation,
			false,
			GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN if unknown else GFSaveProfileResult.STATUS_DISPOSED,
			ERR_BUSY if unknown else ERR_UNAVAILABLE,
			"Storage write outcome is unknown after disposal." if unknown else "Save profile utility was disposed.",
			{
				"attempt_count": state.current_attempt_count,
				"storage_request_ids": unknown_request_ids,
			}
		)
	for operation: GFSaveProfileOperation in state.load_operations:
		_complete_operation(state, operation, false, GFSaveProfileResult.STATUS_DISPOSED, ERR_UNAVAILABLE, "Save profile utility was disposed.")
	for operation: GFSaveProfileOperation in state.flush_operations:
		var unknown_request_ids: PackedInt64Array = _get_disposal_unknown_request_ids(
			state,
			operation.get_requested_generation()
		)
		var unknown: bool = not unknown_request_ids.is_empty()
		_complete_operation(
			state,
			operation,
			false,
			GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN if unknown else GFSaveProfileResult.STATUS_DISPOSED,
			ERR_BUSY if unknown else ERR_UNAVAILABLE,
			"Flush target may still reach storage after disposal." if unknown else "Save profile utility was disposed.",
			{"storage_request_ids": unknown_request_ids}
		)
	if state.current_load_operation != null:
		_complete_operation(state, state.current_load_operation, false, GFSaveProfileResult.STATUS_DISPOSED, ERR_UNAVAILABLE, "Save profile utility was disposed.")
	state.save_operations.clear()
	state.load_operations.clear()
	state.flush_operations.clear()
	_disconnect_detached_writes(state)
	_clear_current(state)


func _clear_current(state: ProfileState) -> void:
	_clear_current_storage_operation(state)
	state.current_load_operation = null
	state.current_kind = &""
	state.current_generation = 0
	state.current_attempt_count = 0
	state.current_document = null
	state.current_context.clear()
	state.current_metadata.clear()
	state.retry_due_msec = 0
	state.current_io_deadline_msec = 0
	state.current_storage_request_ids = PackedInt64Array()


# 对象与校验

func _make_operation(
	operation_kind: StringName,
	profile_id: StringName,
	generation: int,
	context: Dictionary,
	metadata: Dictionary
) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = GFSaveProfileOperation.new()
	var _configured: bool = operation.configure_for_framework(
		operation_kind,
		profile_id,
		generation,
		_clock.get_monotonic_msec(),
		context,
		metadata
	)
	return operation


func _make_rejected_operation(
	operation_kind: StringName,
	profile_id: StringName,
	status: StringName,
	error_code: Error,
	error: String
) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = _make_operation(
		operation_kind,
		profile_id,
		0,
		{},
		{}
	)
	var _started: bool = operation.start_for_framework()
	_complete_operation(null, operation, false, status, error_code, error)
	if _processing_depth == 0:
		_drain_completion_events()
	return operation


func _begin_processing() -> void:
	_processing_depth += 1


func _end_processing() -> void:
	_processing_depth = maxi(_processing_depth - 1, 0)
	if _processing_depth > 0:
		return
	if _dispose_requested:
		_dispose_now()
	_drain_completion_events()


func _enter_unsafe_callback() -> void:
	_unsafe_callback_depth += 1


func _exit_unsafe_callback() -> void:
	_unsafe_callback_depth = maxi(_unsafe_callback_depth - 1, 0)


func _dispose_now() -> void:
	if _disposed:
		return
	_disposed = true
	_dispose_requested = false
	for state_value: Variant in _states.values():
		var state: ProfileState = _get_state_value(state_value)
		if state == null:
			continue
		_set_mode(state, STATE_DISPOSED)
		_complete_all_pending_as_disposed(state)
	_states.clear()
	_disconnect_storage()


func _drain_completion_events() -> void:
	if _processing_depth > 0 or _emitting_completions:
		return
	_emitting_completions = true
	while not _pending_completion_operations.is_empty():
		var batch: Array[GFSaveProfileOperation] = _pending_completion_operations.duplicate()
		_pending_completion_operations.clear()
		for operation: GFSaveProfileOperation in batch:
			if operation == null:
				continue
			var result: GFSaveProfileResult = operation.get_result()
			if result == null:
				continue
			profile_operation_completed.emit(result.duplicate_result())
			var _emitted: bool = operation.emit_completed_for_framework()
	_emitting_completions = false


func _is_load_active(state: ProfileState) -> bool:
	return (
		state != null
		and state.current_kind == GFSaveProfileOperation.OPERATION_LOAD
		and state.mode != STATE_IDLE
	)


func _observe_storage_operation(
	state: ProfileState,
	operation: GFStorageAsyncOperation
) -> void:
	if operation == null:
		if state.current_kind == GFSaveProfileOperation.OPERATION_SAVE:
			_handle_save_failure(state, ERR_CANT_CREATE, "Storage returned no save operation.")
		else:
			_handle_load_failure(
				state,
				GFStorageReadResult.new().configure_failure(
					"Storage returned no load operation.",
					ERR_CANT_CREATE,
					{},
					GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
					0,
					GFStorageReadResult.FailureKind.IO_FAILED
				)
			)
		return
	state.current_storage_operation = operation
	_append_request_id(state.current_storage_request_ids, operation.get_request_id())
	state.current_io_deadline_msec = (
		_clock.get_monotonic_msec() + state.recovery_policy.io_timeout_msec
	)
	var callback: Callable = Callable(self, "_on_storage_operation_completed").bind(
		state.profile_id,
		operation.get_request_id()
	)
	state.current_storage_callback = callback
	if operation.is_completed():
		_on_storage_operation_completed(
			operation.get_result(),
			state.profile_id,
			operation.get_request_id()
		)
	else:
		var _connected: Error = operation.completed.connect(
			callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error


func _clear_current_storage_operation(state: ProfileState) -> void:
	if state.current_storage_operation != null and state.current_storage_callback.is_valid():
		if state.current_storage_operation.completed.is_connected(state.current_storage_callback):
			state.current_storage_operation.completed.disconnect(state.current_storage_callback)
	state.current_storage_operation = null
	state.current_storage_callback = Callable()
	state.current_io_deadline_msec = 0


func _handle_current_io_timeout(state: ProfileState) -> void:
	var operation_kind: StringName = state.current_kind
	if operation_kind == GFSaveProfileOperation.OPERATION_SAVE:
		_detach_current_write(state)
		_handle_save_failure(state, ERR_TIMEOUT, "Storage save completion timed out.")
	else:
		_clear_current_storage_operation(state)
		_handle_load_failure(
			state,
			GFStorageReadResult.new().configure_failure(
				"Storage load completion timed out.",
				ERR_TIMEOUT,
				{},
				GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
				0,
				GFStorageReadResult.FailureKind.IO_FAILED
			)
		)


func _mark_save_operations_running(state: ProfileState, generation: int) -> void:
	for operation: GFSaveProfileOperation in state.save_operations:
		if operation.get_requested_generation() <= generation and operation.is_pending():
			var _started: bool = operation.start_for_framework()


func _has_pending_operations(state: ProfileState) -> bool:
	return (
		not state.save_operations.is_empty()
		or not state.load_operations.is_empty()
		or not state.flush_operations.is_empty()
		or state.current_load_operation != null
	)


func _detach_current_write(state: ProfileState) -> void:
	var operation: GFStorageAsyncOperation = state.current_storage_operation
	if operation == null:
		return
	var request_id: int = operation.get_request_id()
	if state.current_storage_callback.is_valid():
		if operation.completed.is_connected(state.current_storage_callback):
			operation.completed.disconnect(state.current_storage_callback)
	state.current_storage_operation = null
	state.current_storage_callback = Callable()
	state.current_io_deadline_msec = 0
	var request_ids: PackedInt64Array = _get_unknown_request_ids_for_generation(
		state,
		state.current_generation
	)
	_append_request_id(request_ids, request_id)
	state.unknown_write_generations[state.current_generation] = request_ids
	var callback: Callable = Callable(self, "_on_detached_write_completed").bind(
		state.profile_id,
		request_id,
		state.current_generation
	)
	state.detached_write_operations[request_id] = {
		"operation": operation,
		"callback": callback,
		"generation": state.current_generation,
	}
	if operation.is_completed():
		_on_detached_write_completed(
			operation.get_result(),
			state.profile_id,
			request_id,
			state.current_generation
		)
	else:
		var _connected: Error = operation.completed.connect(
			callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error


func _on_detached_write_completed(
	result: GFStorageAsyncResult,
	profile_id: StringName,
	request_id: int,
	generation: int
) -> void:
	if _disposed:
		return
	_begin_processing()
	var state: ProfileState = _get_state(profile_id)
	if state == null or not state.detached_write_operations.has(request_id):
		_end_processing()
		return
	var record: Dictionary = GFVariantData.as_dictionary(
		state.detached_write_operations.get(request_id, {})
	)
	var operation: GFStorageAsyncOperation = _get_storage_operation_value(
		GFVariantData.get_option_value(record, "operation")
	)
	var callback: Callable = _get_callable_value(
		GFVariantData.get_option_value(record, "callback", Callable())
	)
	if operation != null and callback.is_valid() and operation.completed.is_connected(callback):
		operation.completed.disconnect(callback)
	var _erased: bool = state.detached_write_operations.erase(request_id)
	_remove_unknown_request_id(state, generation, request_id)
	if (
		result != null
		and result.get_request_id() == request_id
		and result.get_operation() == GFStorageAsyncOperation.OPERATION_SAVE
		and result.is_successful()
	):
		state.persisted_generation = maxi(state.persisted_generation, generation)
		_clear_generation_evidence_through(state, generation)
	elif generation > state.persisted_generation:
		var error_code: Error = result.get_error_code() if result != null else FAILED
		if not state.unknown_write_generations.has(generation):
			_record_generation_failure(
				state,
				generation,
				GFSaveProfileResult.STATUS_STORAGE_FAILED,
				error_code,
				"Timed-out Storage write later completed with a failure.",
				&"",
				PackedInt64Array([request_id])
			)
	_complete_ready_flushes(state)
	_schedule(state)
	_end_processing()


func _get_barrier_failure(state: ProfileState, target_generation: int) -> Dictionary:
	if target_generation <= state.persisted_generation:
		return {}
	var unknown_ids: PackedInt64Array = _get_unknown_request_ids_covering(
		state,
		target_generation
	)
	if not unknown_ids.is_empty():
		return {
			"status": GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN,
			"error_code": int(ERR_BUSY),
			"error": "A covering Storage write has no confirmed terminal outcome.",
			"failed_section_id": &"",
			"storage_request_ids": unknown_ids,
		}
	var selected_generation: int = -1
	var selected_failure: Dictionary = {}
	for generation_value: Variant in state.generation_failures.keys():
		var generation: int = GFVariantData.to_int(generation_value, -1)
		if generation >= target_generation and generation > selected_generation:
			selected_generation = generation
			selected_failure = GFVariantData.as_dictionary(
				state.generation_failures.get(generation, {})
			).duplicate(true)
	return selected_failure


func _has_pending_save_covering_generation(state: ProfileState, target_generation: int) -> bool:
	if (
		state.current_kind == GFSaveProfileOperation.OPERATION_SAVE
		and state.mode != STATE_IDLE
		and state.current_generation >= target_generation
	):
		return true
	for operation: GFSaveProfileOperation in state.save_operations:
		if not operation.is_completed() and operation.get_requested_generation() >= target_generation:
			return true
	return false


func _record_generation_failure(
	state: ProfileState,
	generation: int,
	status: StringName,
	error_code: Error,
	error: String,
	failed_section_id: StringName,
	storage_request_ids: PackedInt64Array
) -> void:
	state.generation_failures[generation] = {
		"status": status,
		"error_code": int(error_code),
		"error": error,
		"failed_section_id": failed_section_id,
		"storage_request_ids": storage_request_ids.duplicate(),
	}


func _clear_generation_evidence_through(state: ProfileState, generation: int) -> void:
	for key: Variant in state.generation_failures.keys():
		if GFVariantData.to_int(key, generation + 1) <= generation:
			var _erased_failure: bool = state.generation_failures.erase(key)
	for key: Variant in state.unknown_write_generations.keys():
		if GFVariantData.to_int(key, generation + 1) <= generation:
			var _erased_unknown: bool = state.unknown_write_generations.erase(key)


func _get_unknown_request_ids_for_generation(
	state: ProfileState,
	generation: int
) -> PackedInt64Array:
	return _get_request_id_array(state.unknown_write_generations.get(generation, PackedInt64Array()))


func _remove_unknown_request_id(state: ProfileState, generation: int, request_id: int) -> void:
	var remaining: PackedInt64Array = PackedInt64Array()
	for candidate: int in _get_unknown_request_ids_for_generation(state, generation):
		if candidate != request_id:
			var _appended: bool = remaining.append(candidate)
	if remaining.is_empty():
		var _erased: bool = state.unknown_write_generations.erase(generation)
	else:
		state.unknown_write_generations[generation] = remaining


func _get_unknown_request_ids_covering(
	state: ProfileState,
	target_generation: int
) -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	for generation_value: Variant in state.unknown_write_generations.keys():
		var generation: int = GFVariantData.to_int(generation_value, -1)
		if generation < target_generation:
			continue
		for request_id: int in _get_unknown_request_ids_for_generation(state, generation):
			_append_request_id(result, request_id)
	result.sort()
	return result


func _get_disposal_unknown_request_ids(
	state: ProfileState,
	target_generation: int
) -> PackedInt64Array:
	var result: PackedInt64Array = _get_unknown_request_ids_covering(
		state,
		target_generation
	)
	if (
		state.current_kind == GFSaveProfileOperation.OPERATION_SAVE
		and state.current_generation >= target_generation
		and state.current_storage_operation != null
		and not state.current_storage_operation.is_completed()
	):
		for request_id: int in state.current_storage_request_ids:
			_append_request_id(result, request_id)
	result.sort()
	return result


func _disconnect_detached_writes(state: ProfileState) -> void:
	for record_value: Variant in state.detached_write_operations.values():
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		var operation: GFStorageAsyncOperation = _get_storage_operation_value(
			GFVariantData.get_option_value(record, "operation")
		)
		var callback: Callable = _get_callable_value(
			GFVariantData.get_option_value(record, "callback", Callable())
		)
		if operation != null and callback.is_valid() and operation.completed.is_connected(callback):
			operation.completed.disconnect(callback)
	state.detached_write_operations.clear()


func _append_request_id(request_ids: PackedInt64Array, request_id: int) -> void:
	if request_id > 0 and not request_ids.has(request_id):
		var _appended: bool = request_ids.append(request_id)


func _get_request_id_array(value: Variant) -> PackedInt64Array:
	if value is PackedInt64Array:
		var packed_value: PackedInt64Array = value
		return packed_value.duplicate()
	var result: PackedInt64Array = PackedInt64Array()
	if value is Array:
		for item: Variant in value:
			_append_request_id(result, GFVariantData.to_int(item))
	return result


func _get_sorted_generation_keys(source: Dictionary) -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	for key: Variant in source.keys():
		var _appended: bool = result.append(GFVariantData.to_int(key))
	result.sort()
	return result


func _get_sorted_request_ids(source: Dictionary) -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	for key: Variant in source.keys():
		var _appended: bool = result.append(GFVariantData.to_int(key))
	result.sort()
	return result


func _update_preserved_unknown_sections(
	state: ProfileState,
	document: GFSaveDocument
) -> void:
	state.preserved_unknown_sections.clear()
	if state.unknown_section_policy != GFSaveProfile.UNKNOWN_SECTION_PRESERVE:
		return
	for section: GFSaveSection in document.get_sections():
		if section == null or _state_has_provider(state, section.get_section_id()):
			continue
		state.preserved_unknown_sections.append(section.duplicate_section())


func _state_has_provider(state: ProfileState, section_id: StringName) -> bool:
	for provider: GFSaveSectionProvider in state.providers:
		if provider != null and provider.section_id == section_id:
			return true
	return false


func _get_rollback_failure_array(value: Variant) -> Array[GFSaveRollbackFailure]:
	var result: Array[GFSaveRollbackFailure] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry: Variant in values:
		if entry is GFSaveRollbackFailure:
			var failure: GFSaveRollbackFailure = entry
			result.append(failure.duplicate_failure())
	return result


func _duplicate_recovery_policy(source: GFSaveRecoveryPolicy) -> GFSaveRecoveryPolicy:
	var copy: GFSaveRecoveryPolicy = GFSaveRecoveryPolicy.new()
	copy.missing_file_action = source.missing_file_action
	copy.corrupt_file_action = source.corrupt_file_action
	copy.retry_delays_msec = source.retry_delays_msec.duplicate()
	copy.transient_error_codes = source.transient_error_codes.duplicate()
	copy.io_timeout_msec = source.io_timeout_msec
	return copy


func _append_report_issues(target: Dictionary, source: Dictionary) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(source, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var _issue: Variant = GFValidationReportDictionary.append_issue(
			target,
			GFVariantData.get_option_string(issue, "severity", "error"),
			GFVariantData.get_option_string_name(issue, "kind", &"invalid_profile"),
			GFVariantData.get_option_string(issue, "message", "Profile validation failed."),
			issue
		)


func _append_registration_issue(
	report: Dictionary,
	kind: StringName,
	message: String,
	path: String
) -> void:
	var _issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		{"path": path}
	)


func _finalize_registration_report(
	report: Dictionary,
	profile: GFSaveProfile,
	canonical_file_name: String,
	registered: bool
) -> Dictionary:
	report["registered"] = registered
	report["profile_id"] = profile.profile_id if profile != null else &""
	report["schema_id"] = profile.get_effective_schema_id() if profile != null else &""
	report["canonical_file_name"] = canonical_file_name
	return GFValidationReportDictionary.finalize_report(report, "Save profile registration", {
		"include_issue_count": true,
		"next_actions": {
			"missing_profile": "Provide one valid GFSaveProfile.",
			"utility_disposed": "Create a new Save Profile Utility.",
			"reentrant_registration": "Register Profiles outside Provider and state callbacks.",
			"storage_unconfigured": "Call setup or register GFStorageUtility before registration.",
			"invalid_storage_path": "Use one path accepted by the active Storage path policy.",
			"duplicate_profile_id": "Use one unique runtime Profile id.",
			"duplicate_storage_target": "Assign one canonical storage target to exactly one Profile.",
			"provider_lock_failed": "Fix Provider validation before registration.",
		},
		"fallback_action": "Review the first registration issue.",
		"no_action": "Save Profile registration is valid.",
	})


func _needs_migration(state: ProfileState, document: GFSaveDocument) -> bool:
	if document.get_schema_version() < state.schema_version:
		return true
	for provider: GFSaveSectionProvider in state.providers:
		if provider == null or not document.has_section(provider.section_id):
			continue
		var section: GFSaveSection = document.get_section(provider.section_id)
		if section != null and section.get_schema_version() < provider.schema_version:
			return true
	return false


func _has_future_schema(state: ProfileState, document: GFSaveDocument) -> bool:
	if document.get_schema_version() > state.schema_version:
		return true
	for provider: GFSaveSectionProvider in state.providers:
		if provider == null or not document.has_section(provider.section_id):
			continue
		var section: GFSaveSection = document.get_section(provider.section_id)
		if section != null and section.get_schema_version() > provider.schema_version:
			return true
	return false


func _report_has_issue(report: Dictionary, kind: StringName) -> bool:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == kind:
			return true
	return false


func _get_first_validation_message(report: Dictionary, fallback: String) -> String:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	if issues.is_empty():
		return fallback
	return GFVariantData.get_option_string(
		GFVariantData.as_dictionary(issues[0]),
		"message",
		fallback
	)


func _get_error_code(source: Dictionary, key: String, fallback: Error) -> Error:
	return GFVariantData.get_option_int(source, key, int(fallback)) as Error


func _set_storage(storage: GFStorageUtility) -> void:
	if _storage == storage:
		return
	_storage = storage


func _disconnect_storage() -> void:
	_storage = null


func _set_mode(state: ProfileState, mode: StringName) -> void:
	if state.mode == mode:
		return
	var previous: StringName = state.mode
	state.mode = mode
	_enter_unsafe_callback()
	profile_state_changed.emit(state.profile_id, previous, mode)
	_exit_unsafe_callback()


func _get_state(profile_id: StringName) -> ProfileState:
	return _get_state_value(GFVariantData.get_option_value(_states, profile_id))


func _get_state_value(value: Variant) -> ProfileState:
	if value is ProfileState:
		var state: ProfileState = value
		return state
	return null


func _get_document_value(value: Variant) -> GFSaveDocument:
	if value is GFSaveDocument:
		var document: GFSaveDocument = value
		return document
	return null


func _get_section_value(value: Variant) -> GFSaveSection:
	if value is GFSaveSection:
		var section: GFSaveSection = value
		return section
	return null


func _get_storage_result_value(value: Variant) -> GFStorageReadResult:
	if value is GFStorageReadResult:
		var result: GFStorageReadResult = value
		return result
	return null


func _get_storage_operation_value(value: Variant) -> GFStorageAsyncOperation:
	if value is GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = value
		return operation
	return null


func _get_callable_value(value: Variant) -> Callable:
	return value if value is Callable else Callable()


func _get_migration_result_value(value: Variant) -> GFSaveMigrationResult:
	if value is GFSaveMigrationResult:
		var result: GFSaveMigrationResult = value
		return result
	return null


# --- 内部类 ---

## 单个 Save Profile 的隔离调度状态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class ProfileState extends RefCounted:
	## 编译后的运行时 Profile ID。
	## [br]
	## @api framework_internal
	var profile_id: StringName = &""

	## 编译后的文档 schema ID。
	## [br]
	## @api framework_internal
	var schema_id: StringName = &""

	## Storage 规范化文件目标。
	## [br]
	## @api framework_internal
	var file_name: String = ""

	## 编译后的文档 schema 版本。
	## [br]
	## @api framework_internal
	var schema_version: int = 1

	## 编译后的文档 schema。
	## [br]
	## @api framework_internal
	var schema: GFSaveDocumentSchema = null

	## 已锁定定义的 Provider 顺序。
	## [br]
	## @api framework_internal
	var providers: Array[GFSaveSectionProvider] = []

	## 隔离恢复政策副本。
	## [br]
	## @api framework_internal
	var recovery_policy: GFSaveRecoveryPolicy = null

	## 是否接受保存和 flush。
	## [br]
	## @api framework_internal
	var save_enabled: bool = true

	## 是否接受读取。
	## [br]
	## @api framework_internal
	var load_enabled: bool = true

	## 未知 section 政策。
	## [br]
	## @api framework_internal
	var unknown_section_policy: StringName = GFSaveProfile.UNKNOWN_SECTION_REJECT

	## 最近成功读取后需要透明保留的未知 section。
	## [br]
	## @api framework_internal
	var preserved_unknown_sections: Array[GFSaveSection] = []

	## 可选迁移注册表。
	## [br]
	## @api framework_internal
	var migrations: GFSaveMigrationRegistry = null

	## 当前状态机状态。
	## [br]
	## @api framework_internal
	var mode: StringName = STATE_IDLE

	## 最新请求 generation。
	## [br]
	## @api framework_internal
	var generation: int = 0

	## 已持久化 generation。
	## [br]
	## @api framework_internal
	var persisted_generation: int = 0

	## 最近失败 generation。
	## [br]
	## @api framework_internal
	var last_failed_generation: int = 0

	## 最近保存失败的稳定状态。
	## [br]
	## @api framework_internal
	var last_failure_status: StringName = GFSaveProfileResult.STATUS_STORAGE_FAILED

	## 最近保存失败的 Error 码。
	## [br]
	## @api framework_internal
	var last_failure_error_code: Error = FAILED

	## 最近保存失败描述。
	## [br]
	## @api framework_internal
	var last_failure_error: String = ""

	## 最近保存失败 section ID。
	## [br]
	## @api framework_internal
	var last_failure_section_id: StringName = &""

	## 未完成保存句柄。
	## [br]
	## @api framework_internal
	var save_operations: Array[GFSaveProfileOperation] = []

	## 等待读取句柄。
	## [br]
	## @api framework_internal
	var load_operations: Array[GFSaveProfileOperation] = []

	## 等待 generation 屏障的 flush 句柄。
	## [br]
	## @api framework_internal
	var flush_operations: Array[GFSaveProfileOperation] = []

	## 当前读取句柄。
	## [br]
	## @api framework_internal
	var current_load_operation: GFSaveProfileOperation = null

	## 当前 IO 类型。
	## [br]
	## @api framework_internal
	var current_kind: StringName = &""

	## 当前 IO 对应 generation。
	## [br]
	## @api framework_internal
	var current_generation: int = 0

	## 当前 IO 尝试次数。
	## [br]
	## @api framework_internal
	var current_attempt_count: int = 0

	## 当前写入重试复用的不可变文档。
	## [br]
	## @api framework_internal
	var current_document: GFSaveDocument = null

	## 当前底层请求专属句柄。
	## [br]
	## @api framework_internal
	var current_storage_operation: GFStorageAsyncOperation = null

	## 当前底层请求终态回调。
	## [br]
	## @api framework_internal
	var current_storage_callback: Callable = Callable()

	## 当前底层 IO 单调超时截止时间。
	## [br]
	## @api framework_internal
	var current_io_deadline_msec: int = 0

	## 当前操作触发过的底层请求 ID。
	## [br]
	## @api framework_internal
	var current_storage_request_ids: PackedInt64Array = PackedInt64Array()

	## generation 到稳定失败证据的映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema generation_failures: Dictionary keyed by generation with typed failure evidence.
	var generation_failures: Dictionary = {}

	## generation 到未确认写请求 ID 的映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema unknown_write_generations: Dictionary keyed by generation with PackedInt64Array request IDs.
	var unknown_write_generations: Dictionary = {}

	## 超时后仍由当前 profile 保有的底层写请求。
	## [br]
	## @api framework_internal
	## [br]
	## @schema detached_write_operations: Dictionary keyed by request ID with operation, callback, and generation.
	var detached_write_operations: Dictionary = {}

	## 是否正在迭代调度当前 profile。
	## [br]
	## @api framework_internal
	var is_scheduling: bool = false

	## 调度期间是否出现新的调度请求。
	## [br]
	## @api framework_internal
	var schedule_requested: bool = false

	## 当前操作临时上下文。
	## [br]
	## @api framework_internal
	## [br]
	## @schema current_context: Dictionary with caller-defined ephemeral operation data.
	var current_context: Dictionary = {}

	## 当前操作结果元数据或文档元数据。
	## [br]
	## @api framework_internal
	## [br]
	## @schema current_metadata: Dictionary with caller-defined operation metadata.
	var current_metadata: Dictionary = {}

	## 最新待保存 generation 的上下文。
	## [br]
	## @api framework_internal
	## [br]
	## @schema latest_save_context: Dictionary with caller-defined ephemeral operation data.
	var latest_save_context: Dictionary = {}

	## 最新待保存 generation 的文档元数据。
	## [br]
	## @api framework_internal
	## [br]
	## @schema latest_save_metadata: Dictionary with caller-defined persisted document metadata.
	var latest_save_metadata: Dictionary = {}

	## 下一次重试的单调毫秒截止时间。
	## [br]
	## @api framework_internal
	var retry_due_msec: int = 0
