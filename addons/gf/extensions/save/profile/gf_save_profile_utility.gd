## GFSaveProfileUtility: 多 section 存档的异步协调器。
##
## 每个 profile 只串行推进一个当前 IO；超时后无法取消的写入会 detached 保留路径所有权。
## 连续保存通过 generation 合并为最新后续写入；读取在保存屏障后执行，并在主线程完成迁移、校验和 provider 事务化应用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFSaveProfileUtility
extends GFUtility


# --- 信号 ---

## 任一 profile 操作进入终态时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 隔离终态结果。
signal profile_operation_completed(result: GFSaveProfileResult)

## profile 状态机发生变化时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
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
## @since 10.0.0
const STATE_IDLE: StringName = &"idle"

## 正在主线程分片准备 section Snapshot。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_PREPARING: StringName = &"preparing"

## 正在等待保存 IO。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATE_SAVING: StringName = &"saving"

## 正在等待读取 IO。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATE_LOADING: StringName = &"loading"

## 正在等待有界重试截止时间。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATE_RETRY_WAIT: StringName = &"retry_wait"

## 正在迁移、校验或事务化应用 section。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATE_APPLYING: StringName = &"applying"

## Utility 已释放。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATE_DISPOSED: StringName = &"disposed"

const _PREPARATION_PHASE_PROVIDER_SCAN: StringName = &"provider_scan"
const _PREPARATION_PHASE_PROVIDER_BEGIN: StringName = &"provider_begin"
const _PREPARATION_PHASE_PRESERVED: StringName = &"preserved"
const _PREPARATION_PHASE_FINALIZE: StringName = &"finalize"
const _PAYLOAD_VALIDATION_ADAPTER = preload(
	"res://addons/gf/extensions/save/profile/gf_save_payload_validation_adapter.gd"
)


# --- 公共变量 ---

## 每帧全部 Profile 共享的保存准备 work-unit 预算。
##
## 该预算是协作式上界；框架无法抢占单次 Provider 回调，因此 Provider 必须保证
## 每个 work unit 的成本有界。
## [br]
## @api public
## [br]
## @since unreleased
var save_preparation_work_budget_per_tick: int = 64:
	set(value):
		save_preparation_work_budget_per_tick = maxi(value, 1)

## 单个 Profile 每次轮转最多获得的准备 work units。
## [br]
## @api public
## [br]
## @since unreleased
var save_preparation_slice_budget: int = 8:
	set(value):
		save_preparation_slice_budget = maxi(value, 1)

## 每帧保存准备的软时间预算（微秒）；为 0 时只使用确定性 work-unit 预算。
##
## 时间预算只能阻止开始下一个协作式 slice，不能抢占正在运行的 Provider 回调。
## [br]
## @api public
## [br]
## @since unreleased
var save_preparation_time_budget_usec: int = 2000:
	set(value):
		save_preparation_time_budget_usec = maxi(value, 0)


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
var _pending_schedule_head: ProfileState = null
var _pending_schedule_tail: ProfileState = null
var _active_preparation_head: ProfileState = null
var _active_preparation_tail: ProfileState = null
var _admission_open: bool = true
var _quiesce_completion: GFAsyncCompletion = null


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
## @since 10.0.0
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


## 声明架构模式下必须显式注册的 Storage 依赖。
##
## `setup()` 仍可用于 standalone 测试与非 Architecture 所有权场景；进入 Architecture
## 生命周期时不会因此绕过 GFStorageUtility 的显式注册要求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅包含 GFStorageUtility 的依赖声明。
func get_required_utilities() -> Array[Script]:
	var dependencies: Array[Script] = [GFStorageUtility]
	return dependencies


## 激活 Profile 服务；底层 Storage 未配置时失败，不创建业务 profile。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _scope: 当前 Profile 服务激活阶段的取消作用域。
## [br]
## @return Storage 可用时成功，否则返回失败终态。
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _disposed:
		var _failed_disposed: bool = completion.fail("Save Profile Utility is disposed.")
		return completion
	if _quiesce_completion != null:
		var _failed_quiesced: bool = completion.fail(
			"Save Profile Utility cannot reactivate after quiesce."
		)
		return completion
	if _storage == null:
		var _failed_storage: bool = completion.fail(
			"GFStorageUtility must be configured before activation."
		)
		return completion
	_quiesce_completion = null
	_admission_open = true
	var _succeeded: bool = completion.succeed()
	return completion


## 关闭新 profile 工作准入，并等待已接纳 operation、preparation、retry 与 detached 写入收敛。
##
## 静默期间不会注册业务 profile，也不会取消已接纳工作；这些工作继续由 lifecycle tick
## 和底层 Storage 完成回调推进。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scope: 当前 Profile 服务静默阶段的取消作用域。
## [br]
## @return 所有已接纳工作进入终态后成功的一次性完成源。
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	_admission_open = false
	if _quiesce_completion != null:
		return _quiesce_completion
	_quiesce_completion = GFAsyncCompletion.new()
	if scope != null:
		var _bound: bool = _quiesce_completion.bind_cancel_token(scope)
	_try_complete_quiesce()
	return _quiesce_completion


## 推进到期重试。
## [br]
## @api public
## [br]
## @since 10.0.0
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
	if not _disposed and not _dispose_requested:
		_drain_pending_schedule_queue()
	if not _disposed and not _dispose_requested:
		_advance_save_preparations()
	_end_processing()


## 终止所有未完成操作并释放底层信号连接。
## [br]
## @api public
## [br]
## @since 10.0.0
func dispose() -> void:
	if _disposed:
		return
	_admission_open = false
	if _processing_depth > 0:
		_dispose_requested = true
		return
	_dispose_now()
	_drain_completion_events()
	_try_complete_quiesce()


# --- 公共方法 ---

## 显式注入底层存储和可选时钟。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param storage: 底层事务存储工具。
## [br]
## @param clock: 可选单调时钟；为空时保留当前时钟。
## [br]
## @return 当前 Utility；参数无效、已释放或已有注册 profile 时返回 null。
func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveProfileUtility:
	if (
		not _admission_open
		or _disposed
		or _unsafe_callback_depth > 0
		or storage == null
		or not _states.is_empty()
	):
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
## @since 10.0.0
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
	if not _admission_open and not _disposed:
		_append_registration_issue(
			report,
			&"utility_quiescing",
			"Save Profile Utility is not accepting new registrations.",
			"utility"
		)
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
		state.provider_ids[provider.section_id] = true
	state.migrations = migrations
	_states[profile.profile_id] = state
	return _finalize_registration_report(report, profile, canonical_file_name, true)


## 注销空闲 profile。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param profile_id: profile ID。
## [br]
## @return profile 存在且没有未完成操作时返回 true。
func unregister_profile(profile_id: StringName) -> bool:
	var state: ProfileState = _get_state(profile_id)
	if (
		not _admission_open
		or _dispose_requested
		or _unsafe_callback_depth > 0
		or state == null
		or state.mode != STATE_IDLE
		or _has_pending_operations(state)
		or not state.detached_write_operations.is_empty()
		or state.pending_schedule_enqueued
		or state.active_preparation_enqueued
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
## @since 10.0.0
## [br]
## @param profile_id: profile ID。
## [br]
## @param request: 一次性保存请求；null 表示三个元数据字典均为空。
## [br]
## @return 保存操作句柄；无效请求返回已失败句柄。
func save_profile(
	profile_id: StringName,
	request: GFSaveProfileRequest = null
) -> GFSaveProfileOperation:
	if not _admission_open:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Save Profile Utility is quiescing."
		)
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
	var owned_request: GFSaveProfileRequest = request
	if owned_request == null:
		owned_request = GFSaveProfileRequest.take_ownership({}, {}, {})
	var claim: Dictionary = owned_request.claim_for_framework()
	if claim.is_empty():
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_PARAMETER,
			"Save request is invalid or already claimed."
		)
	var document_metadata_value: Variant = claim.get("document_metadata")
	var context_value: Variant = claim.get("context")
	var result_metadata_value: Variant = claim.get("result_metadata")
	if (
		not document_metadata_value is Dictionary
		or not context_value is Dictionary
		or not result_metadata_value is Dictionary
	):
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_SAVE,
			profile_id,
			GFSaveProfileResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_DATA,
			"Save request ownership record is invalid."
		)
	var document_metadata: Dictionary = document_metadata_value
	var context: Dictionary = context_value
	var result_metadata: Dictionary = result_metadata_value
	_begin_processing()
	state.generation += 1
	state.latest_save_metadata = document_metadata
	state.latest_save_context = context
	var operation: GFSaveProfileOperation = _make_save_operation(
		profile_id,
		state.generation,
		result_metadata
	)
	state.save_operations.append(operation)
	_enqueue_schedule(state)
	_end_processing()
	return operation


## 请求异步读取、迁移、校验并应用 profile。
##
## 调用时捕获当前 generation 作为写入屏障；相关保存失败时读取不会静默读取旧文件。
## [br]
## @api public
## [br]
## @since 10.0.0
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
	if not _admission_open:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_LOAD,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Save Profile Utility is quiescing."
		)
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
	_enqueue_schedule(state)
	_end_processing()
	return operation


## 等待调用时可见的最新 generation 持久化。
## [br]
## @api public
## [br]
## @since 10.0.0
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
	if not _admission_open:
		return _make_rejected_operation(
			GFSaveProfileOperation.OPERATION_FLUSH,
			profile_id,
			GFSaveProfileResult.STATUS_BUSY,
			ERR_BUSY,
			"Save Profile Utility is quiescing."
		)
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
	if not operation.is_completed():
		_enqueue_schedule(state)
	_end_processing()
	return operation


## 获取已成功持久化的 generation。
## [br]
## @api public
## [br]
## @since 10.0.0
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
## @since 10.0.0
## [br]
## @param profile_id: profile ID。
## [br]
## @return profile 状态摘要；未注册时为空字典。
## [br]
## @schema return: Dictionary with profile_id, schema_id, state, generation, persisted_generation, failed_generation, save_queue_size, load_queue_size, flush_queue_size, current_generation, attempt_count, schedule_enqueued, preparation_enqueued, preparation_phase, preparation_provider_index, preparation_section_id, preparation_work_units, preparation_duration_msec, storage_duration_msec, write_outcome_unknown, unknown_write_generations, detached_write_count, and detached_storage_request_ids.
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
		"schedule_enqueued": state.pending_schedule_enqueued,
		"preparation_enqueued": state.active_preparation_enqueued,
		"preparation_phase": state.current_preparation_phase,
		"preparation_provider_index": state.current_preparation_provider_index,
		"preparation_section_id": state.current_preparation_section_id,
		"preparation_work_units": state.current_preparation_work_units,
		"preparation_duration_msec": _get_current_preparation_duration(state),
		"storage_duration_msec": _get_current_storage_duration(state),
		"write_outcome_unknown": not state.unknown_write_generations.is_empty(),
		"unknown_write_generations": _get_sorted_generation_keys(state.unknown_write_generations),
		"detached_write_count": state.detached_write_operations.size(),
		"detached_storage_request_ids": _get_sorted_request_ids(state.detached_write_operations),
	}


# --- 私有/辅助方法 ---

func _enqueue_schedule(state: ProfileState) -> void:
	if (
		_disposed
		or _dispose_requested
		or state == null
		or not _has_pending_operations(state)
	):
		return
	if state.is_scheduling:
		state.schedule_requested = true
		return
	if state.pending_schedule_enqueued:
		return
	state.pending_schedule_enqueued = true
	state.pending_schedule_next = null
	if _pending_schedule_tail != null:
		_pending_schedule_tail.pending_schedule_next = state
	else:
		_pending_schedule_head = state
	_pending_schedule_tail = state


func _pop_pending_schedule() -> ProfileState:
	var state: ProfileState = _pending_schedule_head
	if state == null:
		return null
	_pending_schedule_head = state.pending_schedule_next
	if _pending_schedule_head == null:
		_pending_schedule_tail = null
	state.pending_schedule_next = null
	state.pending_schedule_enqueued = false
	return state


func _drain_pending_schedule_queue() -> void:
	while _pending_schedule_head != null and not _disposed and not _dispose_requested:
		var state: ProfileState = _pop_pending_schedule()
		if (
			state != null
			and state.mode == STATE_IDLE
			and _has_pending_operations(state)
		):
			_schedule(state)


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
			if state.save_turn_due:
				state.save_turn_due = false
				if not state.save_operations.is_empty():
					_start_save(state)
					if state.mode != STATE_IDLE:
						break
					continue
			if not state.load_operations.is_empty():
				var oldest_load: GFSaveProfileOperation = state.load_operations.front()
				var target_generation: int = oldest_load.get_requested_generation()
				var waiting_for_save: bool = (
					target_generation > state.persisted_generation
					and _has_pending_save_covering_generation(state, target_generation)
				)
				if not waiting_for_save:
					var _removed_load: GFSaveProfileOperation = state.load_operations.pop_front()
					state.save_turn_due = not state.save_operations.is_empty()
					var barrier_failure: Dictionary = _get_barrier_failure(
						state,
						target_generation
					)
					if not barrier_failure.is_empty():
						_complete_operation(
							state,
							oldest_load,
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
					_start_load(state, oldest_load)
					break
			if not state.save_operations.is_empty():
				state.save_turn_due = false
				_start_save(state)
				if state.mode != STATE_IDLE:
					break
				continue
			break
	state.is_scheduling = false


func _enqueue_active_preparation(state: ProfileState) -> void:
	if (
		_disposed
		or _dispose_requested
		or state == null
		or state.mode != STATE_PREPARING
		or state.active_preparation_enqueued
	):
		return
	state.active_preparation_enqueued = true
	state.active_preparation_next = null
	if _active_preparation_tail != null:
		_active_preparation_tail.active_preparation_next = state
	else:
		_active_preparation_head = state
	_active_preparation_tail = state


func _pop_active_preparation() -> ProfileState:
	var state: ProfileState = _active_preparation_head
	if state == null:
		return null
	_active_preparation_head = state.active_preparation_next
	if _active_preparation_head == null:
		_active_preparation_tail = null
	state.active_preparation_next = null
	state.active_preparation_enqueued = false
	return state


func _advance_save_preparations() -> void:
	if _active_preparation_head == null:
		return
	var remaining_work_units: int = maxi(save_preparation_work_budget_per_tick, 1)
	var started_at_usec: int = Time.get_ticks_usec()
	while remaining_work_units > 0 and _active_preparation_head != null:
		var state: ProfileState = _pop_active_preparation()
		if state == null:
			return
		if state.mode != STATE_PREPARING:
			continue
		var slice_budget: int = mini(
			maxi(save_preparation_slice_budget, 1),
			remaining_work_units
		)
		var consumed: int = _advance_save_preparation(state, slice_budget)
		remaining_work_units -= maxi(consumed, 1)
		if (
			not _disposed
			and not _dispose_requested
			and state.mode == STATE_PREPARING
		):
			_enqueue_active_preparation(state)
		if _disposed or _dispose_requested:
			return
		if (
			save_preparation_time_budget_usec > 0
			and Time.get_ticks_usec() - started_at_usec >= save_preparation_time_budget_usec
		):
			return


func _start_save(state: ProfileState) -> void:
	state.current_kind = GFSaveProfileOperation.OPERATION_SAVE
	state.current_generation = state.generation
	state.current_attempt_count = 0
	state.current_storage_request_ids = PackedInt64Array()
	state.current_context = state.latest_save_context
	state.current_metadata = state.latest_save_metadata
	state.latest_save_context = {}
	state.latest_save_metadata = {}
	state.current_preparation_provider_index = 0
	state.current_preserved_section_index = 0
	state.current_preparation_phase = _PREPARATION_PHASE_PROVIDER_SCAN
	state.current_preparation_provider = null
	state.current_preparation_operation = null
	state.current_preparation_section_id = &""
	state.current_preparation_work_units = 0
	state.current_preparation_started_at_msec = _clock.get_monotonic_msec()
	state.current_preparation_duration_msec = 0
	state.current_storage_duration_msec = 0
	state.current_io_started_at_msec = -1
	state.current_section_records = {}
	state.current_section_ids_by_entry_index = []
	state.current_sections_entry_index = -1
	state.current_payload_transfer = null
	_mark_save_operations_running(state, state.current_generation)
	_set_mode(state, STATE_PREPARING)
	_enqueue_active_preparation(state)


func _advance_save_preparation(state: ProfileState, work_budget: int) -> int:
	if state == null or state.mode != STATE_PREPARING or work_budget <= 0:
		return 0
	var consumed: int = 0
	while consumed < work_budget and state.mode == STATE_PREPARING:
		if state.current_preparation_operation != null:
			var operation: GFSaveSectionSnapshotOperation = state.current_preparation_operation
			if operation.is_pending():
				var operation_budget: int = work_budget - consumed
				_enter_unsafe_callback()
				var operation_units: int = operation.advance_for_framework(operation_budget)
				_exit_unsafe_callback()
				var charged_units: int = maxi(operation_units, 1)
				consumed += charged_units
				state.current_preparation_work_units += charged_units
				if _dispose_requested:
					break
			if operation.is_pending():
				break
			if not operation.is_successful():
				_finish_save_failure(
					state,
					operation.get_error_code(),
					operation.get_error(),
					GFSaveProfileResult.STATUS_PREPARATION_FAILED,
					state.current_preparation_section_id
				)
				break
			var snapshot: GFSaveSectionSnapshot = operation.take_snapshot_for_framework()
			var snapshot_record: Dictionary = (
				snapshot.claim_for_framework()
				if snapshot != null
				else {}
			)
			if snapshot_record.is_empty():
				_finish_save_failure(
					state,
					ERR_INVALID_DATA,
					"Save section Snapshot ownership could not be claimed.",
					GFSaveProfileResult.STATUS_PREPARATION_FAILED,
					state.current_preparation_section_id
				)
				break
			_store_current_section_record(
				state,
				state.current_preparation_section_id,
				snapshot_record
			)
			state.current_preparation_operation = null
			state.current_preparation_section_id = &""
			continue

		match state.current_preparation_phase:
			_PREPARATION_PHASE_PROVIDER_SCAN:
				if state.current_preparation_provider_index >= state.providers.size():
					state.current_preparation_phase = _PREPARATION_PHASE_PRESERVED
					continue
				var provider: GFSaveSectionProvider = state.providers[
					state.current_preparation_provider_index
				]
				state.current_preparation_provider_index += 1
				consumed += 1
				state.current_preparation_work_units += 1
				if provider == null or not provider.save_enabled:
					continue
				state.current_preparation_provider = provider
				state.current_preparation_section_id = provider.section_id
				state.current_preparation_phase = _PREPARATION_PHASE_PROVIDER_BEGIN
			_PREPARATION_PHASE_PROVIDER_BEGIN:
				var provider: GFSaveSectionProvider = state.current_preparation_provider
				if provider == null:
					_finish_save_failure(
						state,
						ERR_BUG,
						"Save preparation lost its current Provider.",
						GFSaveProfileResult.STATUS_PREPARATION_FAILED,
						state.current_preparation_section_id
					)
					break
				consumed += 1
				state.current_preparation_work_units += 1
				_enter_unsafe_callback()
				var preparation: GFSaveSectionSnapshotOperation = (
					provider.begin_save_snapshot(state.current_context)
				)
				_exit_unsafe_callback()
				state.current_preparation_provider = null
				state.current_preparation_operation = preparation
				state.current_preparation_phase = _PREPARATION_PHASE_PROVIDER_SCAN
				if _dispose_requested:
					break
				if preparation == null:
					_finish_save_failure(
						state,
						ERR_INVALID_DATA,
						"Save section Provider failed to create a Snapshot Operation.",
						GFSaveProfileResult.STATUS_PREPARATION_FAILED,
						provider.section_id
					)
					break
			_PREPARATION_PHASE_PRESERVED:
				if (
					state.current_preserved_section_index
					>= state.preserved_unknown_sections.size()
				):
					state.current_preparation_phase = _PREPARATION_PHASE_FINALIZE
					continue
				var section: GFSaveSection = state.preserved_unknown_sections[
					state.current_preserved_section_index
				]
				state.current_preserved_section_index += 1
				consumed += 1
				state.current_preparation_work_units += 1
				if section == null:
					continue
				var section_id: StringName = section.get_section_id()
				if state.provider_ids.has(section_id):
					continue
				var preserved_record: Dictionary = (
					section.get_transfer_record_for_framework()
				)
				if preserved_record.is_empty():
					_finish_save_failure(
						state,
						ERR_INVALID_DATA,
						"Preserved unknown section could not enter the save transfer.",
						GFSaveProfileResult.STATUS_PREPARATION_FAILED,
						section_id
					)
					break
				_store_current_section_record(
					state,
					section_id,
					preserved_record
				)
			_PREPARATION_PHASE_FINALIZE:
				consumed += 1
				state.current_preparation_work_units += 1
				_complete_save_preparation(state)
				break
			_:
				_finish_save_failure(
					state,
					ERR_BUG,
					"Save preparation entered an invalid phase.",
					GFSaveProfileResult.STATUS_PREPARATION_FAILED,
					state.current_preparation_section_id
				)
				break
	return consumed


func _complete_save_preparation(state: ProfileState) -> void:
	var document_data: Dictionary = {}
	document_data["format"] = GFSaveDocument.FORMAT_ID
	document_data["format_version"] = GFSaveDocument.FORMAT_VERSION
	document_data["schema_id"] = state.schema_id
	document_data["schema_version"] = state.schema_version
	state.current_sections_entry_index = document_data.size()
	document_data["sections"] = state.current_section_records
	document_data["metadata"] = state.current_metadata
	state.current_section_records = {}
	state.current_metadata = {}
	state.current_context = {}
	state.current_payload_transfer = GFStoragePayloadTransfer.take_ownership(
		document_data
	)
	if state.current_payload_transfer == null:
		_finish_save_failure(
			state,
			ERR_INVALID_DATA,
			"Save document could not enter the Storage transfer boundary.",
			GFSaveProfileResult.STATUS_PREPARATION_FAILED
		)
		return
	_complete_current_preparation_timing(state)
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
	if state.current_payload_transfer == null:
		_finish_save_failure(
			state,
			ERR_INVALID_DATA,
			"Storage payload transfer is unavailable.",
			GFSaveProfileResult.STATUS_STORAGE_FAILED
		)
		return
	state.current_attempt_count += 1
	_begin_current_io_timing(state)
	var operation: GFStorageAsyncOperation = _storage.save_payload_request_async(
		state.file_name,
		state.current_payload_transfer
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
	_begin_current_io_timing(state)
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
	_complete_current_io_timing(state)
	_clear_current_storage_operation(state)
	if result.get_operation() == GFStorageAsyncOperation.OPERATION_SAVE:
		if not result.is_successful():
			if (
				result.get_write_failure_kind()
					== GFStorageAsyncResult.WriteFailureKind.PAYLOAD_INVALID
			):
				var adapted_validation: Dictionary = (
					_PAYLOAD_VALIDATION_ADAPTER.adapt_for_framework(
						result.get_write_validation_report(),
						state.current_sections_entry_index,
						state.current_section_ids_by_entry_index
					)
				)
				_finish_save_failure(
					state,
					result.get_error_code(),
					"Storage worker rejected the prepared Save payload.",
					GFSaveProfileResult.STATUS_PREPARATION_FAILED,
					GFVariantData.get_option_string_name(
						adapted_validation,
						"failed_section_id"
					),
					GFVariantData.get_option_dictionary(
						adapted_validation,
						"validation_report"
					)
				)
			else:
				_handle_save_failure(state, result.get_error_code(), "Storage save failed.")
		else:
			_finalize_save_timing_for_terminal(state)
			state.persisted_generation = maxi(state.persisted_generation, state.current_generation)
			_clear_generation_evidence_through(state, state.current_generation)
			_complete_save_operations_success(state)
			_clear_current(state)
			_set_mode(state, STATE_IDLE)
			_complete_ready_flushes(state)
			_enqueue_schedule(state)
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
	_complete_save_operations_success_through(
		state,
		state.current_generation,
		state.current_attempt_count,
		state.current_storage_request_ids,
		state.current_preparation_duration_msec,
		state.current_storage_duration_msec,
		state.current_preparation_work_units
	)


func _complete_save_operations_success_through(
	state: ProfileState,
	generation: int,
	attempt_count: int,
	storage_request_ids: PackedInt64Array,
	preparation_duration_msec: int,
	storage_duration_msec: int,
	preparation_work_units: int
) -> void:
	var remaining: Array[GFSaveProfileOperation] = []
	for operation: GFSaveProfileOperation in state.save_operations:
		if operation.get_requested_generation() <= generation:
			_complete_operation(
				state,
				operation,
				true,
				GFSaveProfileResult.STATUS_SAVED,
				OK,
				"",
				{
					"attempt_count": attempt_count,
					"coalesced": operation.get_requested_generation() < generation,
					"storage_request_ids": storage_request_ids,
					"preparation_duration_msec": preparation_duration_msec,
					"storage_duration_msec": storage_duration_msec,
					"preparation_work_units": preparation_work_units,
				}
			)
		else:
			remaining.append(operation)
	state.save_operations = remaining
	if generation >= state.generation:
		state.latest_save_context = {}
		state.latest_save_metadata = {}


func _finish_save_failure(
	state: ProfileState,
	error_code: Error,
	error: String,
	status: StringName,
	failed_section_id: StringName = &"",
	validation_report: Dictionary = {}
) -> void:
	_finalize_save_timing_for_terminal(state)
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
					"attempt_count": state.current_attempt_count,
					"failed_section_id": failed_section_id,
					"storage_request_ids": state.current_storage_request_ids,
					"preparation_duration_msec": state.current_preparation_duration_msec,
					"storage_duration_msec": state.current_storage_duration_msec,
					"preparation_work_units": state.current_preparation_work_units,
					"validation_report": validation_report,
				}
			)
		else:
			remaining.append(operation)
	state.save_operations = remaining
	if state.current_generation >= state.generation:
		state.latest_save_context = {}
		state.latest_save_metadata = {}
	_clear_current(state)
	_set_mode(state, STATE_IDLE)
	_complete_ready_flushes(state)
	_enqueue_schedule(state)


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
	_enqueue_schedule(state)


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
	_enqueue_schedule(state)


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
		_get_request_id_array(GFVariantData.get_option_value(options, "storage_request_ids")),
		GFVariantData.get_option_int(options, "preparation_duration_msec"),
		GFVariantData.get_option_int(options, "storage_duration_msec"),
		GFVariantData.get_option_int(options, "preparation_work_units")
	)
	if operation.complete_for_framework(result):
		_pending_completion_operations.append(operation)


func _complete_all_pending_as_disposed(state: ProfileState) -> void:
	if state.current_kind == GFSaveProfileOperation.OPERATION_SAVE:
		_finalize_save_timing_for_terminal(state)
	for operation: GFSaveProfileOperation in state.save_operations:
		var covered_by_current: bool = (
			state.current_kind == GFSaveProfileOperation.OPERATION_SAVE
			and state.current_generation > 0
			and operation.get_requested_generation() <= state.current_generation
		)
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
				"attempt_count": state.current_attempt_count if covered_by_current else 0,
				"storage_request_ids": unknown_request_ids,
				"preparation_duration_msec": (
					state.current_preparation_duration_msec
					if covered_by_current
					else 0
				),
				"storage_duration_msec": (
					state.current_storage_duration_msec
					if covered_by_current
					else 0
				),
				"preparation_work_units": (
					state.current_preparation_work_units
					if covered_by_current
					else 0
				),
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
	_complete_current_io_timing(state)
	_clear_current_storage_operation(state)
	if state.current_preparation_operation != null:
		var _cancelled: bool = state.current_preparation_operation.cancel_for_framework()
	state.current_preparation_operation = null
	state.current_preparation_provider = null
	state.current_preparation_phase = _PREPARATION_PHASE_PROVIDER_SCAN
	state.current_preparation_provider_index = 0
	state.current_preserved_section_index = 0
	state.current_preparation_section_id = &""
	state.current_preparation_work_units = 0
	state.current_preparation_started_at_msec = -1
	state.current_preparation_duration_msec = 0
	state.current_storage_duration_msec = 0
	state.current_section_records = {}
	state.current_section_ids_by_entry_index = []
	state.current_sections_entry_index = -1
	state.current_load_operation = null
	state.current_kind = &""
	state.current_generation = 0
	state.current_attempt_count = 0
	if state.current_payload_transfer != null:
		var _released: bool = state.current_payload_transfer.release()
	state.current_payload_transfer = null
	state.current_context = {}
	state.current_metadata = {}
	state.retry_due_msec = 0
	state.current_io_deadline_msec = 0
	state.current_io_started_at_msec = -1
	state.current_storage_request_ids = PackedInt64Array()


# 对象与校验

func _make_operation(
	operation_kind: StringName,
	profile_id: StringName,
	generation: int,
	context: Dictionary,
	result_metadata: Dictionary
) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = GFSaveProfileOperation.new()
	var _configured: bool = operation.configure_for_framework(
		operation_kind,
		profile_id,
		generation,
		_clock.get_monotonic_msec(),
		context,
		result_metadata
	)
	return operation


func _make_save_operation(
	profile_id: StringName,
	generation: int,
	result_metadata: Dictionary
) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = GFSaveProfileOperation.new()
	var _configured: bool = operation.configure_save_ownership_for_framework(
		profile_id,
		generation,
		_clock.get_monotonic_msec(),
		result_metadata
	)
	return operation


func _make_rejected_operation(
	operation_kind: StringName,
	profile_id: StringName,
	status: StringName,
	error_code: Error,
	error: String
) -> GFSaveProfileOperation:
	var operation: GFSaveProfileOperation = (
		_make_save_operation(profile_id, 0, {})
		if operation_kind == GFSaveProfileOperation.OPERATION_SAVE
		else _make_operation(
			operation_kind,
			profile_id,
			0,
			{},
			{}
		)
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
	_try_complete_quiesce()


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
	_pending_schedule_head = null
	_pending_schedule_tail = null
	_active_preparation_head = null
	_active_preparation_tail = null
	_disconnect_storage()
	_try_complete_quiesce()


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
		_complete_current_io_timing(state)
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
	if state.current_kind == GFSaveProfileOperation.OPERATION_SAVE:
		var operation_transfer: GFStoragePayloadTransfer = operation.get_payload_transfer()
		if operation_transfer != null:
			state.current_payload_transfer = operation_transfer
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
		_account_detached_write_tails(state, state.current_generation)
	_complete_current_io_timing(state)
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


func _begin_current_io_timing(state: ProfileState) -> void:
	if state == null:
		return
	_complete_current_io_timing(state)
	state.current_io_started_at_msec = _clock.get_monotonic_msec()
	state.current_io_deadline_msec = (
		state.current_io_started_at_msec + state.recovery_policy.io_timeout_msec
	)


func _complete_current_io_timing(state: ProfileState) -> void:
	if state == null or state.current_io_started_at_msec < 0:
		return
	state.current_storage_duration_msec += maxi(
		_clock.get_monotonic_msec() - state.current_io_started_at_msec,
		0
	)
	state.current_io_started_at_msec = -1


func _complete_current_preparation_timing(state: ProfileState) -> void:
	if state == null or state.current_preparation_started_at_msec < 0:
		return
	state.current_preparation_duration_msec += maxi(
		_clock.get_monotonic_msec() - state.current_preparation_started_at_msec,
		0
	)
	state.current_preparation_started_at_msec = -1


func _store_current_section_record(
	state: ProfileState,
	section_id: StringName,
	record: Dictionary
) -> void:
	if state == null or section_id == &"":
		return
	var section_key: String = String(section_id)
	if not state.current_section_records.has(section_key):
		state.current_section_ids_by_entry_index.append(section_id)
	state.current_section_records[section_key] = record


func _finalize_save_timing_for_terminal(state: ProfileState) -> void:
	if state == null:
		return
	_complete_current_preparation_timing(state)
	_complete_current_io_timing(state)
	_account_detached_write_tails(state, state.current_generation)


func _account_detached_write_tails(
	state: ProfileState,
	generation: int
) -> void:
	if state == null or generation <= 0:
		return
	var now_msec: int = _clock.get_monotonic_msec()
	for request_id_value: Variant in state.detached_write_operations.keys():
		var request_id: int = GFVariantData.to_int(request_id_value, 0)
		var record: Dictionary = GFVariantData.as_dictionary(
			state.detached_write_operations.get(request_id_value)
		)
		if (
			record.is_empty()
			or GFVariantData.get_option_int(record, "generation") != generation
		):
			continue
		var accounted_at_msec: int = GFVariantData.get_option_int(
			record,
			"tail_accounted_at_msec",
			now_msec
		)
		var tail_delta_msec: int = maxi(now_msec - accounted_at_msec, 0)
		if tail_delta_msec > 0:
			state.current_storage_duration_msec += tail_delta_msec
			record["storage_duration_msec"] = (
				GFVariantData.get_option_int(record, "storage_duration_msec")
				+ tail_delta_msec
			)
		record["tail_accounted_at_msec"] = now_msec
		state.detached_write_operations[request_id] = record


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
	var detached_at_msec: int = _clock.get_monotonic_msec()
	state.detached_write_operations[request_id] = {
		"operation": operation,
		"callback": callback,
		"generation": state.current_generation,
		"attempt_count": state.current_attempt_count,
		"preparation_duration_msec": state.current_preparation_duration_msec,
		"storage_duration_msec": state.current_storage_duration_msec,
		"preparation_work_units": state.current_preparation_work_units,
		"storage_request_ids": state.current_storage_request_ids.duplicate(),
		"detached_at_msec": detached_at_msec,
		"tail_accounted_at_msec": detached_at_msec,
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
	var owns_current_retry: bool = (
		state.current_kind == GFSaveProfileOperation.OPERATION_SAVE
		and state.current_generation == generation
		and state.mode != STATE_IDLE
	)
	var record_storage_duration_msec: int = GFVariantData.get_option_int(
		record,
		"storage_duration_msec"
	)
	if owns_current_retry:
		_account_detached_write_tails(state, generation)
		record_storage_duration_msec = state.current_storage_duration_msec
	else:
		var now_msec: int = _clock.get_monotonic_msec()
		record_storage_duration_msec += maxi(
			now_msec - GFVariantData.get_option_int(
				record,
				"tail_accounted_at_msec",
				now_msec
			),
			0
		)
	var _erased: bool = state.detached_write_operations.erase(request_id)
	_remove_unknown_request_id(state, generation, request_id)
	var successful: bool = (
		result != null
		and result.get_request_id() == request_id
		and result.get_operation() == GFStorageAsyncOperation.OPERATION_SAVE
		and result.is_successful()
	)
	if successful:
		var attempt_count: int = GFVariantData.get_option_int(record, "attempt_count")
		var preparation_duration_msec: int = GFVariantData.get_option_int(
			record,
			"preparation_duration_msec"
		)
		var storage_duration_msec: int = record_storage_duration_msec
		var preparation_work_units: int = GFVariantData.get_option_int(
			record,
			"preparation_work_units"
		)
		var request_ids: PackedInt64Array = _get_request_id_array(
			GFVariantData.get_option_value(record, "storage_request_ids", PackedInt64Array())
		)
		if owns_current_retry:
			_complete_current_preparation_timing(state)
			_complete_current_io_timing(state)
			attempt_count = maxi(attempt_count, state.current_attempt_count)
			preparation_duration_msec = maxi(
				preparation_duration_msec,
				state.current_preparation_duration_msec
			)
			storage_duration_msec = state.current_storage_duration_msec
			preparation_work_units = maxi(
				preparation_work_units,
				state.current_preparation_work_units
			)
			for current_request_id: int in state.current_storage_request_ids:
				_append_request_id(request_ids, current_request_id)
			if state.current_storage_operation != null:
				_detach_current_write(state)
		state.persisted_generation = maxi(state.persisted_generation, generation)
		_clear_generation_evidence_through(state, generation)
		_complete_save_operations_success_through(
			state,
			generation,
			attempt_count,
			request_ids,
			preparation_duration_msec,
			storage_duration_msec,
			preparation_work_units
		)
		if owns_current_retry:
			_clear_current(state)
			_set_mode(state, STATE_IDLE)
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
	_enqueue_schedule(state)
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
			"utility_quiescing": "Wait for shutdown or create a new Save Profile Utility.",
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


func _get_current_preparation_duration(state: ProfileState) -> int:
	if state == null:
		return 0
	if state.current_preparation_started_at_msec < 0:
		return state.current_preparation_duration_msec
	return (
		state.current_preparation_duration_msec
		+ maxi(
			_clock.get_monotonic_msec() - state.current_preparation_started_at_msec,
			0
		)
	)


func _get_current_storage_duration(state: ProfileState) -> int:
	if state == null:
		return 0
	var duration_msec: int = state.current_storage_duration_msec
	var now_msec: int = _clock.get_monotonic_msec()
	if state.current_io_started_at_msec >= 0:
		duration_msec += maxi(
			now_msec - state.current_io_started_at_msec,
			0
		)
	if state.current_generation <= 0:
		return duration_msec
	for record_value: Variant in state.detached_write_operations.values():
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if (
			record.is_empty()
			or GFVariantData.get_option_int(record, "generation")
				!= state.current_generation
		):
			continue
		duration_msec += maxi(
			now_msec - GFVariantData.get_option_int(
				record,
				"tail_accounted_at_msec",
				now_msec
			),
			0
		)
	return duration_msec


func _try_complete_quiesce() -> void:
	if (
		_quiesce_completion == null
		or not _quiesce_completion.is_pending()
		or _processing_depth > 0
		or _emitting_completions
		or not _pending_completion_operations.is_empty()
		or _pending_schedule_head != null
		or _active_preparation_head != null
	):
		return
	for state_value: Variant in _states.values():
		var state: ProfileState = _get_state_value(state_value)
		if (
			state != null
			and (
				state.mode != STATE_IDLE
				or _has_pending_operations(state)
				or state.current_storage_operation != null
				or not state.detached_write_operations.is_empty()
				or state.pending_schedule_enqueued
				or state.active_preparation_enqueued
			)
		):
			return
	var _succeeded: bool = _quiesce_completion.succeed()


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
## @since 10.0.0
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

	## 编译后的 Provider ID 集合。
	## [br]
	## @api framework_internal
	## [br]
	## @schema provider_ids: Dictionary keyed by StringName section IDs with boolean membership values.
	var provider_ids: Dictionary = {}

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

	## 当前保存准备 phase。
	## [br]
	## @api framework_internal
	var current_preparation_phase: StringName = _PREPARATION_PHASE_PROVIDER_SCAN

	## Provider scan 已选择、等待 begin 的 Provider。
	## [br]
	## @api framework_internal
	var current_preparation_provider: GFSaveSectionProvider = null

	## 当前保存准备正在推进的 Provider Operation。
	## [br]
	## @api framework_internal
	var current_preparation_operation: GFSaveSectionSnapshotOperation = null

	## 下一个 Provider 索引。
	## [br]
	## @api framework_internal
	var current_preparation_provider_index: int = 0

	## 下一个透明保留 section 索引。
	## [br]
	## @api framework_internal
	var current_preserved_section_index: int = 0

	## 当前准备中的 section ID。
	## [br]
	## @api framework_internal
	var current_preparation_section_id: StringName = &""

	## 当前 generation 已消费的准备 work units。
	## [br]
	## @api framework_internal
	var current_preparation_work_units: int = 0

	## 当前 generation 的准备开始时间。
	## [br]
	## @api framework_internal
	var current_preparation_started_at_msec: int = -1

	## 当前 generation 的准备耗时。
	## [br]
	## @api framework_internal
	var current_preparation_duration_msec: int = 0

	## 当前 generation 已累计的活跃 Storage IO 耗时。
	## [br]
	## @api framework_internal
	var current_storage_duration_msec: int = 0

	## 当前物理 IO attempt 的开始时间。
	## [br]
	## @api framework_internal
	var current_io_started_at_msec: int = -1

	## 准备阶段按 section ID 归集的唯一记录。
	## [br]
	## @api framework_internal
	## [br]
	## @schema current_section_records: Dictionary keyed by section ID with owned section records.
	var current_section_records: Dictionary = {}

	## sections Dictionary 的 entry index 到 section ID 的隔离映射。
	## [br]
	## @api framework_internal
	var current_section_ids_by_entry_index: Array[StringName] = []

	## Save 文档根 Dictionary 中 sections 字段的 entry index。
	## [br]
	## @api framework_internal
	var current_sections_entry_index: int = -1

	## Storage 已接管的当前 generation 不透明 payload lease。
	## [br]
	## @api framework_internal
	var current_payload_transfer: GFStoragePayloadTransfer = null

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
	## @schema detached_write_operations: Dictionary keyed by request ID with operation, callback, generation, attempt_count, timing, and storage_request_ids.
	var detached_write_operations: Dictionary = {}

	## 是否已经进入 O(1) pending schedule 队列。
	## [br]
	## @api framework_internal
	var pending_schedule_enqueued: bool = false

	## pending schedule 侵入式单链后继。
	## [br]
	## @api framework_internal
	var pending_schedule_next: ProfileState = null

	## 是否已经进入 O(1) active preparation 轮转队列。
	## [br]
	## @api framework_internal
	var active_preparation_enqueued: bool = false

	## active preparation 侵入式单链后继。
	## [br]
	## @api framework_internal
	var active_preparation_next: ProfileState = null

	## 是否正在迭代调度当前 profile。
	## [br]
	## @api framework_internal
	var is_scheduling: bool = false

	## 调度期间是否出现新的调度请求。
	## [br]
	## @api framework_internal
	var schedule_requested: bool = false

	## 已服务一个就绪读取后，是否应先给等待保存一个调度轮次。
	## [br]
	## @api framework_internal
	var save_turn_due: bool = false

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
