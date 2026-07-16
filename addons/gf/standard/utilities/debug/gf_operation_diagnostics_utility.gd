## GFOperationDiagnosticsUtility: 通用操作诊断时间线。
##
## 记录开发工具、运行时服务或项目流程的操作、阶段耗时和异常事件，并提供有界历史、健康快照和可复制摘要。
## 该工具只保存结构化诊断数据，不绑定编辑器 UI、远程服务、外部协议或业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFOperationDiagnosticsUtility
extends GFUtility


# --- 常量 ---

## 默认保留的已完成操作数量。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_COMPLETED_OPERATIONS: int = 100

## 默认允许同时追踪的活动操作数量。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_ACTIVE_OPERATIONS: int = 100

## 默认保留的异常事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_INCIDENTS: int = 200

## 单个操作默认保留的状态轨迹数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_STATE_TRACE_ENTRIES: int = 64

## 默认保留的采样统计数量。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SAMPLE_STATS: int = 256

## 单个 metadata 默认最多保留的唯一业务键数量。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_METADATA_KEYS: int = 64

## 默认慢操作阈值，单位毫秒。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_SLOW_OPERATION_THRESHOLD_MS: float = 1200.0

const _MAX_DURATION_MS: float = 9_000_000_000_000_000.0
const _DROPPED_METADATA_KEY: StringName = &"__gf_dropped_key_count"

## 信息级事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const SEVERITY_INFO: StringName = &"info"

## 警告级事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const SEVERITY_WARNING: StringName = &"warning"

## 错误级事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const SEVERITY_ERROR: StringName = &"error"

## 严重错误级事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const SEVERITY_CRITICAL: StringName = &"critical"

## 操作状态：等待开始或排队中。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_PENDING: StringName = &"pending"

## 操作状态：正在运行。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_RUNNING: StringName = &"running"

## 操作状态：等待用户或上层流程做出决策。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_WAITING_FOR_USER: StringName = &"waiting_for_user"

## 操作状态：正在重试。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_RETRYING: StringName = &"retrying"

## 操作状态：已成功。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_SUCCEEDED: StringName = &"succeeded"

## 操作状态：已失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_FAILED: StringName = &"failed"

## 操作状态：已取消。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_CANCELLED: StringName = &"cancelled"


# --- 公共变量 ---

## 最多保留的已完成操作数量。设置为 0 时完成结果不会进入历史。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_completed_operations: int = DEFAULT_MAX_COMPLETED_OPERATIONS:
	set(value):
		max_completed_operations = maxi(value, 0)
		_trim_operations()

## 最多同时追踪的活动操作数量。设置为 0 时 begin_operation() 拒绝新操作。
## 已存在的活动操作不会因降低上限而被隐式取消。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_active_operations: int = DEFAULT_MAX_ACTIVE_OPERATIONS:
	set(value):
		max_active_operations = maxi(value, 0)

## 最多保留的异常事件数量。设置为 0 时不保留异常历史。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_incidents: int = DEFAULT_MAX_INCIDENTS:
	set(value):
		max_incidents = maxi(value, 0)
		_trim_incidents()

## 单个操作最多保留的状态轨迹数量。设置为 0 时不保留状态轨迹。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_state_trace_entries: int = DEFAULT_MAX_STATE_TRACE_ENTRIES:
	set(value):
		max_state_trace_entries = maxi(value, 0)
		_trim_operation_state_traces()

## 最多保留的采样统计数量。设置为 0 时不保留采样统计。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_sample_stats: int = DEFAULT_MAX_SAMPLE_STATS:
	set(value):
		max_sample_stats = maxi(value, 0)
		_trim_sample_stats()

## 单个 metadata 最多保留的唯一业务键数量。覆盖已有键不消耗新额度。
## 超额键会被丢弃，并通过 __gf_dropped_key_count 记录累计数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_metadata_keys: int = DEFAULT_MAX_METADATA_KEYS:
	set(value):
		max_metadata_keys = maxi(value, 0)
		_trim_all_metadata()

## 超过该耗时的完成操作会在健康快照中计入慢操作，单位毫秒。小于 0 时禁用慢操作统计。
## [br]
## @api public
## [br]
## @since 7.0.0
var slow_operation_threshold_ms: float = DEFAULT_SLOW_OPERATION_THRESHOLD_MS:
	set(value):
		if is_finite(value):
			slow_operation_threshold_ms = value


# --- 私有变量 ---

var _operations: Array[Dictionary] = []
var _incidents: Array[Dictionary] = []
var _sample_stats: Dictionary = {}
var _next_operation_index: int = 1
var _next_incident_index: int = 1
var _next_sequence: int = 1
var _rejected_active_operation_count: int = 0


# --- GF 生命周期方法 ---

## 清理所有已记录的诊断数据。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


# --- 公共方法 ---

## 清空操作和异常历史，并重置序列。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_operations.clear()
	_incidents.clear()
	_sample_stats.clear()
	_next_operation_index = 1
	_next_incident_index = 1
	_next_sequence = 1
	_rejected_active_operation_count = 0


## 开始记录一个操作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_type: 操作类型，建议使用稳定的命名空间标识。
## [br]
## @param options: 可选参数，支持 operation_id、component、label、metadata 和 started_ticks_usec。
## [br]
## @return 操作 ID；operation_type 为空时返回空 StringName。
## [br]
## @schema options: Dictionary，支持 operation_id、component、label、metadata 和 started_ticks_usec。
func begin_operation(operation_type: StringName, options: Dictionary = {}) -> StringName:
	if operation_type == &"":
		return &""
	if max_active_operations <= 0 or _get_active_operation_count() >= max_active_operations:
		_rejected_active_operation_count += 1
		return &""
	return _begin_operation_unchecked(operation_type, options)


## 直接记录一个已完成操作。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_type: 操作类型。
## [br]
## @param duration_ms: 操作耗时，单位毫秒。
## [br]
## @param success: 操作是否成功。
## [br]
## @param options: 可选参数，支持 operation_id、component、label、metadata、anomaly_codes、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @return 操作记录副本；operation_type 为空时返回空字典。
## [br]
## @schema options: Dictionary，支持 operation_id、component、label、metadata、anomaly_codes、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @schema return: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。
func record_completed_operation(
	operation_type: StringName,
	duration_ms: float,
	success: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	return _record_completed_operation_with_terminal_state(
		operation_type,
		duration_ms,
		success,
		options,
		_get_default_terminal_operation_state(success),
		_get_default_terminal_state_status(success)
	)


## 为已有操作记录一个阶段耗时。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: begin_operation() 返回的操作 ID。
## [br]
## @param phase_id: 阶段标识。
## [br]
## @param duration_ms: 阶段耗时，单位毫秒。
## [br]
## @param options: 可选参数，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @return 阶段记录副本；操作或阶段不存在时返回空字典。
## [br]
## @schema options: Dictionary，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @schema return: Dictionary，包含 phase_id、component、label、duration_ms、started_ticks_usec、ended_ticks_usec 和 metadata。
func record_phase(
	operation_id: StringName,
	phase_id: StringName,
	duration_ms: float,
	options: Dictionary = {}
) -> Dictionary:
	if operation_id == &"" or phase_id == &"" or not _duration_is_valid(duration_ms):
		return {}

	var index: int = _find_operation_index(operation_id)
	if index < 0:
		return {}

	var operation: Dictionary = _operations[index]
	var sequence: int = _take_sequence()
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var safe_duration_ms: float = maxf(duration_ms, 0.0)
	var started_ticks_usec: int = GFVariantData.get_option_int(
		options,
		"started_ticks_usec",
		ended_ticks_usec - roundi(safe_duration_ms * 1000.0)
	)
	var phase: Dictionary = {
		"phase_id": phase_id,
		"component": GFVariantData.get_option_string_name(
			options,
			"component",
			GFVariantData.get_option_string_name(operation, "component")
		),
		"label": GFVariantData.get_option_string(options, "label", String(phase_id)),
		"duration_ms": safe_duration_ms,
		"started_ticks_usec": started_ticks_usec,
		"ended_ticks_usec": ended_ticks_usec,
		"sequence": sequence,
		"metadata": _merge_metadata({}, GFVariantData.get_option_dictionary(options, "metadata")),
	}
	var phases: Array[Dictionary] = _get_dictionary_array(operation, "phases")
	phases.append(phase)
	operation["phases"] = phases
	operation["last_sequence"] = sequence
	_operations[index] = operation
	return phase.duplicate(true)


## 使用 Godot tick 起点记录一个阶段耗时。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: begin_operation() 返回的操作 ID。
## [br]
## @param phase_id: 阶段标识。
## [br]
## @param started_ticks_usec: 阶段开始时的 Time.get_ticks_usec()。
## [br]
## @param options: 可选参数，支持 component、label、metadata 和 ended_ticks_usec。
## [br]
## @return 阶段记录副本；操作或阶段不存在时返回空字典。
## [br]
## @schema options: Dictionary，支持 component、label、metadata 和 ended_ticks_usec。
## [br]
## @schema return: Dictionary，包含 phase_id、component、label、duration_ms、started_ticks_usec、ended_ticks_usec 和 metadata。
func record_phase_from_ticks(
	operation_id: StringName,
	phase_id: StringName,
	started_ticks_usec: int,
	options: Dictionary = {}
) -> Dictionary:
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var duration_ms: float = maxf(float(ended_ticks_usec - started_ticks_usec) / 1000.0, 0.0)
	var phase_options: Dictionary = options.duplicate(true)
	phase_options["started_ticks_usec"] = started_ticks_usec
	phase_options["ended_ticks_usec"] = ended_ticks_usec
	return record_phase(operation_id, phase_id, duration_ms, phase_options)


## 为已有操作记录一个状态快照。
## [br]
## 状态快照用于表达长流程当前阶段、重试次数、进度、是否等待用户决策和错误信息。
## 它只写入结构化诊断，不决定业务如何重试、下载、弹窗或恢复。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: begin_operation() 返回的操作 ID。
## [br]
## @param state_id: 调用方定义的稳定状态 ID。
## [br]
## @param status: 状态，建议使用 STATE_* 常量。
## [br]
## @param options: 可选参数，支持 component、label、attempt、max_attempts、progress、progress_current、progress_total、user_action_required、error、metadata、seen_ticks_usec。
## [br]
## @return 状态快照副本；操作或状态不存在时返回空字典。
## [br]
## @schema options: Dictionary，支持 component、label、attempt、max_attempts、progress、progress_current、progress_total、user_action_required、error、metadata、seen_ticks_usec。
## [br]
## @schema return: Dictionary，包含 state_id、status、attempt、max_attempts、progress、user_action_required、error 和 metadata。
func record_state_snapshot(
	operation_id: StringName,
	state_id: StringName,
	status: StringName = STATE_RUNNING,
	options: Dictionary = {}
) -> Dictionary:
	if operation_id == &"" or state_id == &"":
		return {}

	var index: int = _find_operation_index(operation_id)
	if index < 0:
		return {}

	var operation: Dictionary = _operations[index]
	var sequence: int = _take_sequence()
	var seen_ticks_usec: int = GFVariantData.get_option_int(options, "seen_ticks_usec", Time.get_ticks_usec())
	var seen_at_unix: float = Time.get_unix_time_from_system()
	var normalized_status: StringName = _normalize_state_status(status)
	var attempt: int = maxi(GFVariantData.get_option_int(options, "attempt", GFVariantData.get_option_int(operation, "attempt", 0)), 0)
	var max_attempts: int = maxi(GFVariantData.get_option_int(options, "max_attempts", GFVariantData.get_option_int(operation, "max_attempts", 0)), 0)
	var progress: float = GFVariantData.get_option_float(options, "progress", GFVariantData.get_option_float(operation, "progress", 0.0))
	var progress_current: float = GFVariantData.get_option_float(options, "progress_current", -1.0)
	var progress_total: float = GFVariantData.get_option_float(options, "progress_total", -1.0)
	if not is_finite(progress) or not is_finite(progress_current) or not is_finite(progress_total):
		return {}
	progress = clampf(progress, 0.0, 1.0)
	var error_text: String = GFVariantData.get_option_string(options, "error")
	var state_record: Dictionary = {
		"state_id": state_id,
		"status": normalized_status,
		"sequence": sequence,
		"component": GFVariantData.get_option_string_name(options, "component", GFVariantData.get_option_string_name(operation, "component")),
		"label": GFVariantData.get_option_string(options, "label", String(state_id)),
		"attempt": attempt,
		"max_attempts": max_attempts,
		"progress": progress,
		"progress_current": progress_current,
		"progress_total": progress_total,
		"user_action_required": GFVariantData.get_option_bool(options, "user_action_required", normalized_status == STATE_WAITING_FOR_USER),
		"error": error_text,
		"seen_ticks_usec": seen_ticks_usec,
		"seen_at_unix": seen_at_unix,
		"seen_at_iso": _datetime_from_unix(seen_at_unix),
		"metadata": _merge_metadata({}, GFVariantData.get_option_dictionary(options, "metadata")),
	}

	var state_trace: Array[Dictionary] = _get_dictionary_array(operation, "state_trace")
	state_trace.append(state_record)
	_trim_state_trace(state_trace)
	operation["state_trace"] = state_trace
	operation["current_state_id"] = state_id
	operation["current_state_status"] = normalized_status
	operation["progress"] = progress
	operation["attempt"] = attempt
	operation["max_attempts"] = max_attempts
	operation["user_action_required"] = GFVariantData.get_option_bool(state_record, "user_action_required")
	if not error_text.is_empty():
		operation["last_error"] = error_text
	operation["last_sequence"] = sequence
	_operations[index] = operation
	return state_record.duplicate(true)


## 结束一个操作并写入最终状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: begin_operation() 返回的操作 ID。
## [br]
## @param success: 操作是否成功。
## [br]
## @param options: 可选参数，支持 metadata、anomaly_codes、ended_ticks_usec 和 duration_ms。
## [br]
## @return 完整操作记录副本；操作不存在时返回空字典。
## [br]
## @schema options: Dictionary，支持 metadata、anomaly_codes、ended_ticks_usec 和 duration_ms。
## [br]
## @schema return: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。
func finish_operation(operation_id: StringName, success: bool = true, options: Dictionary = {}) -> Dictionary:
	return _finish_operation_with_terminal_state(
		operation_id,
		success,
		options,
		_get_default_terminal_operation_state(success),
		_get_default_terminal_state_status(success)
	)


## 记录一个异常事件；同类事件会聚合 occurrence_count 并更新时间。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param severity: 事件等级，建议使用 SEVERITY_INFO / WARNING / ERROR / CRITICAL。
## [br]
## @param code: 稳定事件代码。
## [br]
## @param message: 面向维护者的简短说明。
## [br]
## @param options: 可选参数，支持 category、component、phase、recoverable、suggested_action 和 metadata。
## [br]
## @return 异常事件记录副本；code 为空时返回空字典。
## [br]
## @schema options: Dictionary，支持 category、component、phase、recoverable、suggested_action 和 metadata。
## [br]
## @schema return: Dictionary，包含 incident_id、severity、category、code、message、component、phase、occurrence_count、recoverable、suggested_action 和 metadata。
func record_incident(
	severity: StringName,
	code: StringName,
	message: String = "",
	options: Dictionary = {}
) -> Dictionary:
	if code == &"":
		return {}

	var normalized_severity: StringName = _normalize_severity(severity)
	var category: StringName = GFVariantData.get_option_string_name(options, "category", &"runtime")
	var component: StringName = GFVariantData.get_option_string_name(options, "component")
	var phase: StringName = GFVariantData.get_option_string_name(options, "phase")
	var existing_index: int = _find_incident_index(normalized_severity, category, code, component, phase, message)
	if existing_index >= 0:
		return _update_incident(existing_index, options)

	var sequence: int = _take_sequence()
	var now_unix: float = Time.get_unix_time_from_system()
	var incident_id: StringName = _make_incident_id(code)
	var incident: Dictionary = {
		"entry_type": &"incident",
		"incident_id": incident_id,
		"sequence": sequence,
		"last_sequence": sequence,
		"severity": normalized_severity,
		"category": category,
		"code": code,
		"message": message,
		"component": component,
		"phase": phase,
		"occurrence_count": 1,
		"recoverable": GFVariantData.get_option_bool(options, "recoverable", true),
		"suggested_action": GFVariantData.get_option_string(options, "suggested_action"),
		"first_seen_unix": now_unix,
		"last_seen_unix": now_unix,
		"first_seen_iso": _datetime_from_unix(now_unix),
		"last_seen_iso": _datetime_from_unix(now_unix),
		"metadata": _merge_metadata({}, GFVariantData.get_option_dictionary(options, "metadata")),
	}
	_incidents.append(incident)
	_trim_incidents()
	return incident.duplicate(true)


## 将异步对象的状态快照记录为操作诊断。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_type: 操作类型，建议使用稳定的命名空间标识。
## [br]
## @param snapshot: 异步对象提供的状态快照。
## [br]
## @param options: 可选参数，支持 operation_id、component、label、metadata、duration_ms 和 incident_message。
## [br]
## @return 操作记录副本；operation_type 为空时返回空字典。
## [br]
## @schema snapshot: Dictionary，可包含 completed、success、failed、cancelled、timed_out、status、status_name、duration_msec、duration_ms、error、reason、cancel_reason 和 metadata。
## [br]
## @schema options: Dictionary，支持 operation_id、component、label、metadata、duration_ms 和 incident_message。
## [br]
## @schema return: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。
func record_async_snapshot(
	operation_type: StringName,
	snapshot: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if operation_type == &"":
		return {}

	var operation_options: Dictionary = options.duplicate(true)
	operation_options["metadata"] = _merge_metadata(
		GFVariantData.get_option_dictionary(options, "metadata"),
		{
			"async_snapshot": snapshot.duplicate(true),
		}
	)

	if not _async_snapshot_is_terminal(snapshot):
		var pending_operation_id: StringName = GFVariantData.get_option_string_name(operation_options, "operation_id")
		if pending_operation_id != &"" and has_operation(pending_operation_id):
			var state_options: Dictionary = operation_options.duplicate(true)
			state_options["progress"] = GFVariantData.get_option_float(snapshot, "progress", GFVariantData.get_option_float(snapshot, "ratio", 0.0))
			var _state_record: Dictionary = record_state_snapshot(
				pending_operation_id,
				&"async",
				_get_async_operation_state_status(snapshot),
				state_options
			)
			return get_operation(pending_operation_id)
		return get_operation(begin_operation(operation_type, operation_options))

	var success: bool = _async_snapshot_is_successful(snapshot)
	var terminal_state: StringName = _get_async_terminal_operation_state(snapshot, success)
	var terminal_state_status: StringName = _get_async_terminal_state_status(snapshot, success)
	var duration_ms: float = _get_async_snapshot_duration_ms(snapshot, options)
	var anomaly_codes: PackedStringArray = _get_async_snapshot_anomaly_codes(snapshot)
	if not anomaly_codes.is_empty():
		operation_options["anomaly_codes"] = anomaly_codes
	var existing_operation_id: StringName = GFVariantData.get_option_string_name(operation_options, "operation_id")
	if existing_operation_id != &"" and has_operation(existing_operation_id):
		var finished_operation: Dictionary = _finish_operation_with_terminal_state(
			existing_operation_id,
			success,
			{
				"duration_ms": duration_ms,
				"metadata": GFVariantData.get_option_dictionary(operation_options, "metadata"),
				"anomaly_codes": anomaly_codes,
			},
			terminal_state,
			terminal_state_status
		)
		_record_async_snapshot_incident(snapshot, options)
		return finished_operation
	var operation: Dictionary = _record_completed_operation_with_terminal_state(
		operation_type,
		duration_ms,
		success,
		operation_options,
		terminal_state,
		terminal_state_status
	)
	_record_async_snapshot_incident(snapshot, options)
	return operation


## 记录一次命名耗时采样并更新聚合统计。
## [br]
## 采样统计适合记录高频、短生命周期或不需要完整 begin/finish 生命周期的诊断点。
## GF 只聚合调用次数、耗时和 metadata，不解释 sample_id 的业务含义。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param sample_id: 采样点 ID，建议使用稳定命名空间标识。
## [br]
## @param duration_ms: 本次采样耗时，单位毫秒。
## [br]
## @param options: 可选参数，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @return 更新后的采样统计副本；sample_id 为空或采样统计被禁用时返回空字典。
## [br]
## @schema options: Dictionary，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。
## [br]
## @schema return: Dictionary，包含 sample_id、component、sample_count、total_duration_ms、average_duration_ms、min_duration_ms、max_duration_ms、slow_sample_count 和 metadata。
func record_sample(sample_id: StringName, duration_ms: float, options: Dictionary = {}) -> Dictionary:
	if sample_id == &"" or max_sample_stats <= 0 or not _duration_is_valid(duration_ms):
		return {}

	var safe_duration_ms: float = maxf(duration_ms, 0.0)
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var started_ticks_usec: int = GFVariantData.get_option_int(
		options,
		"started_ticks_usec",
		ended_ticks_usec - roundi(safe_duration_ms * 1000.0)
	)
	var sequence: int = _take_sequence()
	var now_unix: float = Time.get_unix_time_from_system()
	var stat: Dictionary = _get_or_create_sample_stat(sample_id, sequence, now_unix)
	var previous_count: int = GFVariantData.get_option_int(stat, "sample_count", 0)
	var sample_count: int = previous_count + 1
	var total_duration_ms: float = GFVariantData.get_option_float(stat, "total_duration_ms", 0.0) + safe_duration_ms
	var slow_sample_count: int = GFVariantData.get_option_int(stat, "slow_sample_count", 0)
	if _is_slow_operation_duration(safe_duration_ms):
		slow_sample_count += 1

	stat["component"] = GFVariantData.get_option_string_name(options, "component", GFVariantData.get_option_string_name(stat, "component"))
	stat["label"] = GFVariantData.get_option_string(options, "label", GFVariantData.get_option_string(stat, "label", String(sample_id)))
	stat["sample_count"] = sample_count
	stat["total_duration_ms"] = total_duration_ms
	stat["average_duration_ms"] = total_duration_ms / float(sample_count)
	stat["last_duration_ms"] = safe_duration_ms
	stat["min_duration_ms"] = safe_duration_ms if previous_count == 0 else minf(GFVariantData.get_option_float(stat, "min_duration_ms", safe_duration_ms), safe_duration_ms)
	stat["max_duration_ms"] = safe_duration_ms if previous_count == 0 else maxf(GFVariantData.get_option_float(stat, "max_duration_ms", safe_duration_ms), safe_duration_ms)
	stat["slow_sample_count"] = slow_sample_count
	stat["last_started_ticks_usec"] = started_ticks_usec
	stat["last_ended_ticks_usec"] = ended_ticks_usec
	stat["last_seen_unix"] = now_unix
	stat["last_seen_iso"] = _datetime_from_unix(now_unix)
	stat["last_sequence"] = sequence
	stat["metadata"] = _merge_metadata(GFVariantData.get_option_dictionary(stat, "metadata"), GFVariantData.get_option_dictionary(options, "metadata"))
	_sample_stats[sample_id] = stat
	_trim_sample_stats()
	return stat.duplicate(true)


## 使用 Godot tick 起点记录一次命名耗时采样。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param sample_id: 采样点 ID。
## [br]
## @param started_ticks_usec: 采样开始时的 Time.get_ticks_usec()。
## [br]
## @param options: 可选参数，支持 component、label、metadata 和 ended_ticks_usec。
## [br]
## @return 更新后的采样统计副本；sample_id 为空或采样统计被禁用时返回空字典。
## [br]
## @schema options: Dictionary，支持 component、label、metadata 和 ended_ticks_usec。
## [br]
## @schema return: Dictionary，包含 sample_id、sample_count、total_duration_ms、average_duration_ms、min_duration_ms、max_duration_ms 和 slow_sample_count。
func record_sample_from_ticks(sample_id: StringName, started_ticks_usec: int, options: Dictionary = {}) -> Dictionary:
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var duration_ms: float = maxf(float(ended_ticks_usec - started_ticks_usec) / 1000.0, 0.0)
	var sample_options: Dictionary = options.duplicate(true)
	sample_options["started_ticks_usec"] = started_ticks_usec
	sample_options["ended_ticks_usec"] = ended_ticks_usec
	return record_sample(sample_id, duration_ms, sample_options)


## 清理采样统计。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param sample_id: 采样点 ID；为空时清空全部采样统计。
## [br]
## @return 实际移除的采样统计数量。
func clear_sample_stats(sample_id: StringName = &"") -> int:
	if sample_id == &"":
		var removed_count: int = _sample_stats.size()
		_sample_stats.clear()
		return removed_count
	if _sample_stats.erase(sample_id):
		return 1
	return 0


## 检查操作是否仍在历史中。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: 操作 ID。
## [br]
## @return 存在返回 true。
func has_operation(operation_id: StringName) -> bool:
	return _find_operation_index(operation_id) >= 0


## 获取单个操作记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: 操作 ID。
## [br]
## @return 操作记录副本；不存在时返回空字典。
## [br]
## @schema return: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。
func get_operation(operation_id: StringName) -> Dictionary:
	var index: int = _find_operation_index(operation_id)
	if index < 0:
		return {}
	return _operations[index].duplicate(true)


## 获取单个操作的状态轨迹。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param operation_id: 操作 ID。
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部状态。
## [br]
## @return 状态快照数组，按记录顺序返回。
## [br]
## @schema return: Array[Dictionary] state snapshot records.
func get_operation_state_trace(operation_id: StringName, limit: int = 0) -> Array[Dictionary]:
	var operation: Dictionary = get_operation(operation_id)
	if operation.is_empty():
		return []
	var state_trace: Array[Dictionary] = _get_dictionary_array(operation, "state_trace")
	if limit <= 0 or state_trace.size() <= limit:
		return state_trace
	var result: Array[Dictionary] = []
	var start_index: int = maxi(state_trace.size() - limit, 0)
	for index: int in range(start_index, state_trace.size()):
		result.append(state_trace[index])
	return result


## 获取单个采样统计副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param sample_id: 采样点 ID。
## [br]
## @return 采样统计副本；不存在时返回空字典。
## [br]
## @schema return: Dictionary，包含 sample_id、component、sample_count、total_duration_ms、average_duration_ms、min_duration_ms、max_duration_ms、slow_sample_count 和 metadata。
func get_sample_stat(sample_id: StringName) -> Dictionary:
	if not _sample_stats.has(sample_id):
		return {}
	return GFVariantData.as_dictionary(_sample_stats[sample_id]).duplicate(true)


## 获取采样统计列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部匹配统计。
## [br]
## @param filters: 过滤条件，支持 sample_id 和 component。
## [br]
## @return 采样统计数组，按最近更新倒序排列。
## [br]
## @schema filters: Dictionary，支持 sample_id 和 component。
## [br]
## @schema return: Array[Dictionary]，每个元素是采样统计副本。
func get_sample_stats(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stat_value: Variant in _sample_stats.values():
		var stat: Dictionary = GFVariantData.as_dictionary(stat_value)
		if _sample_stat_matches_filters(stat, filters):
			result.append(stat.duplicate(true))
	result.sort_custom(Callable(self, "_sort_records_desc"))
	return _limit_records(result, limit)


## 获取操作历史。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部匹配记录。
## [br]
## @param filters: 过滤条件，支持 operation_type、component、state 和 success。
## [br]
## @return 操作记录数组，按最近更新倒序排列。
## [br]
## @schema filters: Dictionary，支持 operation_type、component、state 和 success。
## [br]
## @schema return: Array[Dictionary]，每个元素是操作记录副本。
func get_operations(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operation: Dictionary in _operations:
		if _operation_matches_filters(operation, filters):
			result.append(operation.duplicate(true))
	result.sort_custom(Callable(self, "_sort_records_desc"))
	return _limit_records(result, limit)


## 获取异常事件历史。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部匹配记录。
## [br]
## @param filters: 过滤条件，支持 severity、category、component、phase 和 code。
## [br]
## @return 异常事件数组，按最近更新倒序排列。
## [br]
## @schema filters: Dictionary，支持 severity、category、component、phase 和 code。
## [br]
## @schema return: Array[Dictionary]，每个元素是异常事件记录副本。
func get_incidents(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for incident: Dictionary in _incidents:
		if _incident_matches_filters(incident, filters):
			result.append(incident.duplicate(true))
	result.sort_custom(Callable(self, "_sort_records_desc"))
	return _limit_records(result, limit)


## 获取合并后的操作和异常时间线。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部匹配记录。
## [br]
## @param filters: 过滤条件，支持 entry_type、operation_type、severity、category、component、phase、state、success 和 code。
## [br]
## @return 时间线记录数组，按最近更新倒序排列。
## [br]
## @schema filters: Dictionary，支持 entry_type、operation_type、severity、category、component、phase、state、success 和 code。
## [br]
## @schema return: Array[Dictionary]，每个元素是操作或异常事件记录副本。
func get_timeline(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operation: Dictionary in _operations:
		if _record_matches_filters(operation, filters):
			result.append(operation.duplicate(true))
	for incident: Dictionary in _incidents:
		if _record_matches_filters(incident, filters):
			result.append(incident.duplicate(true))
	result.sort_custom(Callable(self, "_sort_records_desc"))
	return _limit_records(result, limit)


## 生成健康快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: recent_operations 与 recent_incidents 的最大数量。
## [br]
## @return 健康快照字典。
## [br]
## @schema return: Dictionary，包含 status、operation_count、active_operation_count、completed_operation_count、rejected_active_operation_count、incident_count、sample_stat_count、failed_operation_count、slow_operation_count、slow_sample_count、recent_operations、recent_incidents、recent_sample_stats、slowest_operation 和 slowest_sample。
func get_health_snapshot(limit: int = 5) -> Dictionary:
	var recent_limit: int = maxi(limit, 0)
	var open_operation_count: int = 0
	var failed_operation_count: int = 0
	var slow_operation_count: int = 0
	var slow_sample_count: int = 0
	var user_action_required_count: int = 0
	var slowest_operation: Dictionary = {}
	var slowest_sample: Dictionary = {}
	var status: StringName = &"ok"

	for operation: Dictionary in _operations:
		var state: StringName = GFVariantData.get_option_string_name(operation, "state")
		if state == &"running":
			open_operation_count += 1
		if state == &"failed":
			failed_operation_count += 1
			status = _max_status(status, &"error")
		var duration_ms: float = GFVariantData.get_option_float(operation, "duration_ms", 0.0)
		if _is_slow_operation_duration(duration_ms):
			slow_operation_count += 1
			status = _max_status(status, &"warning")
		if GFVariantData.get_option_bool(operation, "user_action_required", false):
			user_action_required_count += 1
			status = _max_status(status, &"warning")
		if slowest_operation.is_empty() or duration_ms > GFVariantData.get_option_float(slowest_operation, "duration_ms", -1.0):
			slowest_operation = operation

	for stat_value: Variant in _sample_stats.values():
		var sample_stat: Dictionary = GFVariantData.as_dictionary(stat_value)
		var sample_slow_count: int = GFVariantData.get_option_int(sample_stat, "slow_sample_count", 0)
		slow_sample_count += sample_slow_count
		if sample_slow_count > 0:
			status = _max_status(status, &"warning")
		var sample_max_duration_ms: float = GFVariantData.get_option_float(sample_stat, "max_duration_ms", 0.0)
		if slowest_sample.is_empty() or sample_max_duration_ms > GFVariantData.get_option_float(slowest_sample, "max_duration_ms", -1.0):
			slowest_sample = sample_stat

	for incident: Dictionary in _incidents:
		var incident_severity: StringName = GFVariantData.get_option_string_name(incident, "severity", SEVERITY_INFO)
		status = _max_status(status, _severity_to_status(incident_severity))
	if _rejected_active_operation_count > 0 or open_operation_count > max_active_operations:
		status = _max_status(status, &"warning")

	return {
		"status": status,
		"operation_count": _operations.size(),
		"active_operation_count": open_operation_count,
		"completed_operation_count": _get_completed_operation_count(),
		"rejected_active_operation_count": _rejected_active_operation_count,
		"incident_count": _incidents.size(),
		"sample_stat_count": _sample_stats.size(),
		"open_operation_count": open_operation_count,
		"failed_operation_count": failed_operation_count,
		"slow_operation_count": slow_operation_count,
		"slow_sample_count": slow_sample_count,
		"user_action_required_count": user_action_required_count,
		"slow_operation_threshold_ms": slow_operation_threshold_ms,
		"recent_operations": get_operations(recent_limit),
		"recent_incidents": get_incidents(recent_limit),
		"recent_sample_stats": get_sample_stats(recent_limit),
		"slowest_operation": slowest_operation.duplicate(true),
		"slowest_sample": slowest_sample.duplicate(true),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary，包含 history 上限、计数、健康快照、最近时间线和采样统计。
func get_debug_snapshot() -> Dictionary:
	return {
		"max_completed_operations": max_completed_operations,
		"max_active_operations": max_active_operations,
		"max_incidents": max_incidents,
		"max_state_trace_entries": max_state_trace_entries,
		"max_sample_stats": max_sample_stats,
		"max_metadata_keys": max_metadata_keys,
		"slow_operation_threshold_ms": slow_operation_threshold_ms,
		"operation_count": _operations.size(),
		"active_operation_count": _get_active_operation_count(),
		"completed_operation_count": _get_completed_operation_count(),
		"rejected_active_operation_count": _rejected_active_operation_count,
		"incident_count": _incidents.size(),
		"sample_stat_count": _sample_stats.size(),
		"health": get_health_snapshot(3),
		"timeline": get_timeline(8),
		"sample_stats": get_sample_stats(8),
	}


## 将操作诊断记录或快照转换为 JSON-safe 结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param record: 操作、异常、健康快照或调试快照。
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return JSON-safe 诊断记录。
## [br]
## @schema record: Dictionary，来自本工具的 raw 诊断记录或快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary，已脱敏 Object、Callable、RID 和非 JSON 原生值。
func to_json_compatible_record(record: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _to_json_compatible_dictionary(record, options)


## 获取 JSON-safe 健康快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param limit: recent_operations 与 recent_incidents 的最大数量。
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return JSON-safe 健康快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary，包含 JSON-safe health snapshot 字段。
func get_json_compatible_health_snapshot(limit: int = 5, options: Dictionary = {}) -> Dictionary:
	return _to_json_compatible_dictionary(get_health_snapshot(limit), options)


## 获取 JSON-safe 调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return JSON-safe 调试快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary，包含 JSON-safe debug snapshot 字段。
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
	return _to_json_compatible_dictionary(get_debug_snapshot(), options)


## 构建适合复制到 issue、日志或支持报告的纯文本摘要。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param snapshot: 可选健康快照；为空时现场采集 get_health_snapshot()。
## [br]
## @return 纯文本摘要。
## [br]
## @schema snapshot: Dictionary，get_health_snapshot() 返回结构。
func build_copy_text(snapshot: Dictionary = {}) -> String:
	var source: Dictionary = snapshot.duplicate(true) if not snapshot.is_empty() else get_health_snapshot()
	var lines: PackedStringArray = PackedStringArray()
	_append_line(lines, "GF operation diagnostics")
	_append_line(lines, "status=%s operations=%d incidents=%d failed=%d slow=%d samples=%d slow_samples=%d" % [
		String(GFVariantData.get_option_string_name(source, "status", &"ok")),
		GFVariantData.get_option_int(source, "operation_count"),
		GFVariantData.get_option_int(source, "incident_count"),
		GFVariantData.get_option_int(source, "failed_operation_count"),
		GFVariantData.get_option_int(source, "slow_operation_count"),
		GFVariantData.get_option_int(source, "sample_stat_count"),
		GFVariantData.get_option_int(source, "slow_sample_count"),
	])
	var slowest_operation: Dictionary = GFVariantData.get_option_dictionary(source, "slowest_operation")
	if not slowest_operation.is_empty():
		_append_line(lines, "slowest=%s %.2fms" % [
			String(GFVariantData.get_option_string_name(slowest_operation, "operation_type")),
			GFVariantData.get_option_float(slowest_operation, "duration_ms", 0.0),
		])
	var slowest_sample: Dictionary = GFVariantData.get_option_dictionary(source, "slowest_sample")
	if not slowest_sample.is_empty():
		_append_line(lines, "slowest_sample=%s %.2fms" % [
			String(GFVariantData.get_option_string_name(slowest_sample, "sample_id")),
			GFVariantData.get_option_float(slowest_sample, "max_duration_ms", 0.0),
		])
	var incidents: Array = GFVariantData.get_option_array(source, "recent_incidents")
	for incident_value: Variant in incidents:
		var incident: Dictionary = GFVariantData.as_dictionary(incident_value)
		if incident.is_empty():
			continue
		_append_line(lines, "- %s:%s %s x%d" % [
			String(GFVariantData.get_option_string_name(incident, "severity", SEVERITY_INFO)),
			String(GFVariantData.get_option_string_name(incident, "code")),
			GFVariantData.get_option_string(incident, "message"),
			GFVariantData.get_option_int(incident, "occurrence_count", 1),
		])
	return "\n".join(lines)


# --- 私有/辅助方法 ---

func _make_operation_id(operation_type: StringName) -> StringName:
	var operation_id: StringName = StringName("%s:%d" % [String(operation_type), _next_operation_index])
	_next_operation_index += 1
	return operation_id


func _make_incident_id(code: StringName) -> StringName:
	var incident_id: StringName = StringName("%s:%d" % [String(code), _next_incident_index])
	_next_incident_index += 1
	return incident_id


func _take_sequence() -> int:
	var result: int = _next_sequence
	_next_sequence += 1
	return result


func _begin_operation_unchecked(operation_type: StringName, options: Dictionary) -> StringName:
	var operation_id: StringName = GFVariantData.get_option_string_name(options, "operation_id")
	if operation_id == &"" or has_operation(operation_id):
		operation_id = _make_operation_id(operation_type)

	var sequence: int = _take_sequence()
	var started_ticks_usec: int = GFVariantData.get_option_int(options, "started_ticks_usec", Time.get_ticks_usec())
	var started_at_unix: float = Time.get_unix_time_from_system()
	var operation: Dictionary = {
		"entry_type": &"operation",
		"operation_id": operation_id,
		"operation_type": operation_type,
		"sequence": sequence,
		"last_sequence": sequence,
		"component": GFVariantData.get_option_string_name(options, "component"),
		"label": GFVariantData.get_option_string(options, "label", String(operation_type)),
		"state": &"running",
		"success": false,
		"started_ticks_usec": started_ticks_usec,
		"ended_ticks_usec": 0,
		"duration_ms": 0.0,
		"started_at_unix": started_at_unix,
		"ended_at_unix": 0.0,
		"started_at_iso": _datetime_from_unix(started_at_unix),
		"ended_at_iso": "",
		"phases": [],
		"state_trace": [],
		"current_state_id": &"",
		"current_state_status": STATE_RUNNING,
		"progress": 0.0,
		"attempt": 0,
		"max_attempts": 0,
		"user_action_required": false,
		"last_error": "",
		"anomaly_codes": PackedStringArray(),
		"metadata": _merge_metadata({}, GFVariantData.get_option_dictionary(options, "metadata")),
	}
	_operations.append(operation)
	return operation_id


func _record_completed_operation_with_terminal_state(
	operation_type: StringName,
	duration_ms: float,
	success: bool,
	options: Dictionary,
	terminal_state: StringName,
	terminal_state_status: StringName
) -> Dictionary:
	if operation_type == &"" or not _duration_is_valid(duration_ms):
		return {}
	var safe_duration_ms: float = maxf(duration_ms, 0.0)
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var started_ticks_usec: int = GFVariantData.get_option_int(
		options,
		"started_ticks_usec",
		ended_ticks_usec - roundi(safe_duration_ms * 1000.0)
	)
	var operation_options: Dictionary = options.duplicate(true)
	operation_options["started_ticks_usec"] = started_ticks_usec
	var operation_id: StringName = _begin_operation_unchecked(operation_type, operation_options)
	if operation_id == &"":
		return {}

	var finish_options: Dictionary = options.duplicate(true)
	finish_options["ended_ticks_usec"] = ended_ticks_usec
	finish_options["duration_ms"] = safe_duration_ms
	return _finish_operation_with_terminal_state(operation_id, success, finish_options, terminal_state, terminal_state_status)


func _finish_operation_with_terminal_state(
	operation_id: StringName,
	success: bool,
	options: Dictionary,
	terminal_state: StringName,
	terminal_state_status: StringName
) -> Dictionary:
	if operation_id == &"":
		return {}

	var index: int = _find_operation_index(operation_id)
	if index < 0:
		return {}

	var operation: Dictionary = _operations[index]
	var ended_ticks_usec: int = GFVariantData.get_option_int(options, "ended_ticks_usec", Time.get_ticks_usec())
	var started_ticks_usec: int = GFVariantData.get_option_int(operation, "started_ticks_usec", ended_ticks_usec)
	var duration_ms: float = GFVariantData.get_option_float(
		options,
		"duration_ms",
		maxf(float(ended_ticks_usec - started_ticks_usec) / 1000.0, 0.0)
	)
	if not _duration_is_valid(duration_ms):
		return {}
	var ended_at_unix: float = Time.get_unix_time_from_system()

	operation["success"] = success
	operation["state"] = _normalize_terminal_operation_state(terminal_state, success)
	operation["current_state_status"] = _normalize_terminal_state_status(terminal_state_status, success)
	operation["user_action_required"] = false
	operation["ended_ticks_usec"] = ended_ticks_usec
	operation["duration_ms"] = maxf(duration_ms, 0.0)
	operation["ended_at_unix"] = ended_at_unix
	operation["ended_at_iso"] = _datetime_from_unix(ended_at_unix)
	operation["last_sequence"] = _take_sequence()
	operation["metadata"] = _merge_metadata(GFVariantData.get_option_dictionary(operation, "metadata"), GFVariantData.get_option_dictionary(options, "metadata"))
	operation["anomaly_codes"] = _merge_string_arrays(
		GFVariantData.get_option_packed_string_array(operation, "anomaly_codes"),
		GFVariantData.get_option_packed_string_array(options, "anomaly_codes")
	)
	_operations[index] = operation
	_trim_operations()
	return operation.duplicate(true)


func _find_operation_index(operation_id: StringName) -> int:
	for index: int in range(_operations.size()):
		if GFVariantData.get_option_string_name(_operations[index], "operation_id") == operation_id:
			return index
	return -1


func _find_incident_index(
	severity: StringName,
	category: StringName,
	code: StringName,
	component: StringName,
	phase: StringName,
	message: String
) -> int:
	for index: int in range(_incidents.size()):
		var incident: Dictionary = _incidents[index]
		if (
			GFVariantData.get_option_string_name(incident, "severity") == severity
			and GFVariantData.get_option_string_name(incident, "category") == category
			and GFVariantData.get_option_string_name(incident, "code") == code
			and GFVariantData.get_option_string_name(incident, "component") == component
			and GFVariantData.get_option_string_name(incident, "phase") == phase
			and GFVariantData.get_option_string(incident, "message") == message
		):
			return index
	return -1


func _get_or_create_sample_stat(sample_id: StringName, sequence: int, now_unix: float) -> Dictionary:
	if _sample_stats.has(sample_id):
		return GFVariantData.as_dictionary(_sample_stats[sample_id])
	return {
		"entry_type": &"sample_stat",
		"sample_id": sample_id,
		"sequence": sequence,
		"last_sequence": sequence,
		"component": &"",
		"label": String(sample_id),
		"sample_count": 0,
		"total_duration_ms": 0.0,
		"average_duration_ms": 0.0,
		"last_duration_ms": 0.0,
		"min_duration_ms": 0.0,
		"max_duration_ms": 0.0,
		"slow_sample_count": 0,
		"first_seen_unix": now_unix,
		"last_seen_unix": now_unix,
		"first_seen_iso": _datetime_from_unix(now_unix),
		"last_seen_iso": _datetime_from_unix(now_unix),
		"last_started_ticks_usec": 0,
		"last_ended_ticks_usec": 0,
		"metadata": {},
	}


func _update_incident(index: int, options: Dictionary) -> Dictionary:
	var incident: Dictionary = _incidents[index]
	var now_unix: float = Time.get_unix_time_from_system()
	incident["occurrence_count"] = GFVariantData.get_option_int(incident, "occurrence_count", 1) + 1
	incident["last_seen_unix"] = now_unix
	incident["last_seen_iso"] = _datetime_from_unix(now_unix)
	incident["last_sequence"] = _take_sequence()
	incident["recoverable"] = GFVariantData.get_option_bool(
		options,
		"recoverable",
		GFVariantData.get_option_bool(incident, "recoverable", true)
	)
	var suggested_action: String = GFVariantData.get_option_string(options, "suggested_action")
	if not suggested_action.is_empty():
		incident["suggested_action"] = suggested_action
	incident["metadata"] = _merge_metadata(GFVariantData.get_option_dictionary(incident, "metadata"), GFVariantData.get_option_dictionary(options, "metadata"))
	_incidents[index] = incident
	return incident.duplicate(true)


func _merge_metadata(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var dropped_count: int = _get_dropped_metadata_key_count(base)
	var business_key_count: int = 0
	for key: Variant in base.keys():
		if _metadata_key_is_reserved(key):
			continue
		if business_key_count >= max_metadata_keys:
			dropped_count += 1
			continue
		result[key] = GFVariantData.duplicate_variant(base[key])
		business_key_count += 1
	for key: Variant in extra.keys():
		if _metadata_key_is_reserved(key):
			continue
		if not result.has(key) and business_key_count >= max_metadata_keys:
			dropped_count += 1
			continue
		result[key] = GFVariantData.duplicate_variant(extra[key])
		if not base.has(key):
			business_key_count += 1
	if dropped_count > 0:
		result[_DROPPED_METADATA_KEY] = dropped_count
	return result


func _get_dropped_metadata_key_count(metadata: Dictionary) -> int:
	for key: Variant in metadata.keys():
		if _metadata_key_is_reserved(key):
			return maxi(GFVariantData.to_int(metadata[key]), 0)
	return 0


func _metadata_key_is_reserved(key: Variant) -> bool:
	return StringName(GFVariantData.to_text(key)) == _DROPPED_METADATA_KEY


func _duration_is_valid(duration_ms: float) -> bool:
	return is_finite(duration_ms) and duration_ms <= _MAX_DURATION_MS


func _to_json_compatible_dictionary(value: Dictionary, options: Dictionary) -> Dictionary:
	var codec_options: Dictionary = options.duplicate(true)
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(value, codec_options))


func _merge_string_arrays(base: PackedStringArray, extra: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = base.duplicate()
	for value: String in extra:
		if not result.has(value):
			var _appended: bool = result.append(value)
	return result


func _get_dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = GFVariantData.get_option_value(source, key, [])
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if item is Dictionary:
				var item_dictionary: Dictionary = item
				result.append(item_dictionary.duplicate(true))
	return result


func _operation_matches_filters(operation: Dictionary, filters: Dictionary) -> bool:
	if not _matches_string_name_filter(operation, filters, "operation_type"):
		return false
	if not _matches_string_name_filter(operation, filters, "component"):
		return false
	if not _matches_string_name_filter(operation, filters, "state"):
		return false
	if filters.has("success") and GFVariantData.get_option_bool(operation, "success") != GFVariantData.get_option_bool(filters, "success"):
		return false
	return true


func _incident_matches_filters(incident: Dictionary, filters: Dictionary) -> bool:
	if not _matches_string_name_filter(incident, filters, "severity"):
		return false
	if not _matches_string_name_filter(incident, filters, "category"):
		return false
	if not _matches_string_name_filter(incident, filters, "component"):
		return false
	if not _matches_string_name_filter(incident, filters, "phase"):
		return false
	if not _matches_string_name_filter(incident, filters, "code"):
		return false
	return true


func _sample_stat_matches_filters(sample_stat: Dictionary, filters: Dictionary) -> bool:
	if not _matches_string_name_filter(sample_stat, filters, "sample_id"):
		return false
	if not _matches_string_name_filter(sample_stat, filters, "component"):
		return false
	return true


func _record_matches_filters(record: Dictionary, filters: Dictionary) -> bool:
	if not _matches_string_name_filter(record, filters, "entry_type"):
		return false
	var entry_type: StringName = GFVariantData.get_option_string_name(record, "entry_type")
	if entry_type == &"operation":
		return _operation_matches_filters(record, filters)
	if entry_type == &"incident":
		return _incident_matches_filters(record, filters)
	return false


func _async_snapshot_is_terminal(snapshot: Dictionary) -> bool:
	if GFVariantData.get_option_bool(snapshot, "completed"):
		return true
	if GFVariantData.get_option_bool(snapshot, "failed"):
		return true
	if GFVariantData.get_option_bool(snapshot, "cancelled"):
		return true
	if GFVariantData.get_option_bool(snapshot, "timed_out"):
		return true
	var status_name: StringName = _get_async_snapshot_status(snapshot)
	return status_name == &"succeeded" or status_name == &"completed" or status_name == &"failed" or status_name == &"cancelled" or status_name == &"timeout"


func _async_snapshot_is_successful(snapshot: Dictionary) -> bool:
	var status_name: StringName = _get_async_snapshot_status(snapshot)
	if status_name == &"failed" or status_name == &"cancelled" or status_name == &"timeout":
		return false
	if GFVariantData.get_option_bool(snapshot, "failed"):
		return false
	if GFVariantData.get_option_bool(snapshot, "cancelled"):
		return false
	if GFVariantData.get_option_bool(snapshot, "timed_out"):
		return false
	if GFVariantData.get_option_bool(snapshot, "success"):
		return true
	if GFVariantData.get_option_bool(snapshot, "successful"):
		return true
	return status_name == &"succeeded" or status_name == &"completed"


func _get_async_operation_state_status(snapshot: Dictionary) -> StringName:
	var status_name: StringName = _get_async_snapshot_status(snapshot)
	match status_name:
		&"pending":
			return STATE_PENDING
		&"waiting", &"waiting_for_user":
			return STATE_WAITING_FOR_USER
		&"retrying":
			return STATE_RETRYING
		_:
			return STATE_RUNNING


func _get_async_terminal_operation_state(snapshot: Dictionary, success: bool) -> StringName:
	if success:
		return &"completed"
	var status_name: StringName = _get_async_snapshot_status(snapshot)
	if status_name == &"cancelled":
		return &"cancelled"
	return &"failed"


func _get_async_terminal_state_status(snapshot: Dictionary, success: bool) -> StringName:
	if success:
		return STATE_SUCCEEDED
	var status_name: StringName = _get_async_snapshot_status(snapshot)
	if status_name == &"cancelled":
		return STATE_CANCELLED
	return STATE_FAILED


func _get_async_snapshot_status(snapshot: Dictionary) -> StringName:
	var status_name: StringName = GFVariantData.get_option_string_name(snapshot, "status_name")
	if status_name != &"":
		return StringName(String(status_name).to_snake_case())
	status_name = GFVariantData.get_option_string_name(snapshot, "status")
	if status_name != &"":
		return StringName(String(status_name).to_snake_case())
	if GFVariantData.get_option_bool(snapshot, "timed_out"):
		return &"timeout"
	if GFVariantData.get_option_bool(snapshot, "cancelled"):
		return &"cancelled"
	if GFVariantData.get_option_bool(snapshot, "failed"):
		return &"failed"
	if GFVariantData.get_option_bool(snapshot, "completed"):
		return &"completed"
	return &"pending"


func _get_async_snapshot_duration_ms(snapshot: Dictionary, options: Dictionary) -> float:
	var configured_duration_ms: float = GFVariantData.get_option_float(options, "duration_ms", -1.0)
	if configured_duration_ms >= 0.0:
		return configured_duration_ms
	var duration_ms: float = GFVariantData.get_option_float(snapshot, "duration_ms", -1.0)
	if duration_ms >= 0.0:
		return duration_ms
	var duration_msec: int = GFVariantData.get_option_int(snapshot, "duration_msec", -1)
	if duration_msec >= 0:
		return float(duration_msec)
	return 0.0


func _get_async_snapshot_anomaly_codes(snapshot: Dictionary) -> PackedStringArray:
	var codes: PackedStringArray = PackedStringArray()
	if GFVariantData.get_option_bool(snapshot, "timed_out") or _get_async_snapshot_status(snapshot) == &"timeout":
		var _timeout_append: bool = codes.append("async_timeout")
	if GFVariantData.get_option_bool(snapshot, "cancelled") or _get_async_snapshot_status(snapshot) == &"cancelled":
		var _cancel_append: bool = codes.append("async_cancelled")
	if GFVariantData.get_option_bool(snapshot, "failed") or _get_async_snapshot_status(snapshot) == &"failed":
		var _failed_append: bool = codes.append("async_failed")
	return codes


func _record_async_snapshot_incident(snapshot: Dictionary, options: Dictionary) -> void:
	var codes: PackedStringArray = _get_async_snapshot_anomaly_codes(snapshot)
	if codes.is_empty():
		return

	var status_name: StringName = _get_async_snapshot_status(snapshot)
	var severity: StringName = SEVERITY_WARNING if status_name == &"cancelled" else SEVERITY_ERROR
	var code: StringName = StringName(codes[0])
	var message: String = GFVariantData.get_option_string(options, "incident_message")
	if message.is_empty():
		message = GFVariantData.get_option_string(snapshot, "error")
	if message.is_empty():
		message = String(GFVariantData.get_option_string_name(snapshot, "reason", GFVariantData.get_option_string_name(snapshot, "cancel_reason")))
	if message.is_empty():
		message = String(code)

	var incident_options: Dictionary = {
		"category": &"async",
		"component": GFVariantData.get_option_string_name(options, "component"),
		"metadata": {
			"async_snapshot": snapshot.duplicate(true),
		},
	}
	var _incident: Dictionary = record_incident(severity, code, message, incident_options)


func _matches_string_name_filter(record: Dictionary, filters: Dictionary, key: String) -> bool:
	if not filters.has(key):
		return true
	var expected: StringName = GFVariantData.get_option_string_name(filters, key)
	if expected == &"":
		return true
	return GFVariantData.get_option_string_name(record, key) == expected


func _sort_records_desc(a: Variant, b: Variant) -> bool:
	var left: Dictionary = GFVariantData.as_dictionary(a)
	var right: Dictionary = GFVariantData.as_dictionary(b)
	return GFVariantData.get_option_int(left, "last_sequence") > GFVariantData.get_option_int(right, "last_sequence")


func _limit_records(records: Array[Dictionary], limit: int) -> Array[Dictionary]:
	if limit <= 0 or records.size() <= limit:
		return records
	var result: Array[Dictionary] = []
	for index: int in range(limit):
		result.append(records[index])
	return result


func _trim_operations() -> void:
	while _get_completed_operation_count() > max_completed_operations:
		var terminal_index: int = _find_oldest_terminal_operation_index()
		if terminal_index < 0:
			return
		_operations.remove_at(terminal_index)


func _find_oldest_terminal_operation_index() -> int:
	var oldest_index: int = -1
	var oldest_sequence: int = 0
	for index: int in range(_operations.size()):
		var operation: Dictionary = _operations[index]
		if not _operation_is_terminal(operation):
			continue
		var sequence: int = GFVariantData.get_option_int(operation, "last_sequence")
		if oldest_index < 0 or sequence < oldest_sequence:
			oldest_index = index
			oldest_sequence = sequence
	return oldest_index


func _get_active_operation_count() -> int:
	var count: int = 0
	for operation: Dictionary in _operations:
		if not _operation_is_terminal(operation):
			count += 1
	return count


func _get_completed_operation_count() -> int:
	var count: int = 0
	for operation: Dictionary in _operations:
		if _operation_is_terminal(operation):
			count += 1
	return count


func _operation_is_terminal(operation: Dictionary) -> bool:
	if GFVariantData.get_option_int(operation, "ended_ticks_usec", 0) > 0:
		return true
	var state: StringName = GFVariantData.get_option_string_name(operation, "state")
	return state == &"completed" or state == &"failed" or state == &"cancelled"


func _trim_incidents() -> void:
	while _incidents.size() > max_incidents:
		_incidents.pop_front()


func _trim_sample_stats() -> void:
	if max_sample_stats <= 0:
		_sample_stats.clear()
		return
	while _sample_stats.size() > max_sample_stats:
		var oldest_sample_id: StringName = _find_oldest_sample_stat_id()
		if oldest_sample_id == &"":
			return
		var _sample_erased: bool = _sample_stats.erase(oldest_sample_id)


func _find_oldest_sample_stat_id() -> StringName:
	var has_oldest: bool = false
	var oldest_sample_id: StringName = &""
	var oldest_sequence: int = 0
	for sample_id_variant: Variant in _sample_stats.keys():
		var sample_id: StringName = GFVariantData.to_string_name(sample_id_variant)
		if sample_id == &"":
			continue
		var sample_stat: Dictionary = GFVariantData.as_dictionary(_sample_stats[sample_id_variant])
		var sequence: int = GFVariantData.get_option_int(sample_stat, "last_sequence", 0)
		if not has_oldest or sequence < oldest_sequence:
			has_oldest = true
			oldest_sample_id = sample_id
			oldest_sequence = sequence
	return oldest_sample_id


func _trim_operation_state_traces() -> void:
	for index: int in range(_operations.size()):
		var operation: Dictionary = _operations[index]
		var state_trace: Array[Dictionary] = _get_dictionary_array(operation, "state_trace")
		_trim_state_trace(state_trace)
		operation["state_trace"] = state_trace
		_operations[index] = operation


func _trim_all_metadata() -> void:
	for operation_index: int in range(_operations.size()):
		var operation: Dictionary = _operations[operation_index]
		operation["metadata"] = _merge_metadata({}, GFVariantData.get_option_dictionary(operation, "metadata"))
		var phases: Array[Dictionary] = _get_dictionary_array(operation, "phases")
		for phase_index: int in range(phases.size()):
			var phase: Dictionary = phases[phase_index]
			phase["metadata"] = _merge_metadata({}, GFVariantData.get_option_dictionary(phase, "metadata"))
			phases[phase_index] = phase
		operation["phases"] = phases
		var state_trace: Array[Dictionary] = _get_dictionary_array(operation, "state_trace")
		for state_index: int in range(state_trace.size()):
			var state_record: Dictionary = state_trace[state_index]
			state_record["metadata"] = _merge_metadata({}, GFVariantData.get_option_dictionary(state_record, "metadata"))
			state_trace[state_index] = state_record
		operation["state_trace"] = state_trace
		_operations[operation_index] = operation
	for incident_index: int in range(_incidents.size()):
		var incident: Dictionary = _incidents[incident_index]
		incident["metadata"] = _merge_metadata({}, GFVariantData.get_option_dictionary(incident, "metadata"))
		_incidents[incident_index] = incident
	for sample_id: Variant in _sample_stats.keys():
		var stat: Dictionary = GFVariantData.as_dictionary(_sample_stats[sample_id])
		stat["metadata"] = _merge_metadata({}, GFVariantData.get_option_dictionary(stat, "metadata"))
		_sample_stats[sample_id] = stat


func _trim_state_trace(state_trace: Array[Dictionary]) -> void:
	if max_state_trace_entries <= 0:
		state_trace.clear()
		return
	while state_trace.size() > max_state_trace_entries:
		state_trace.pop_front()


func _normalize_severity(severity: StringName) -> StringName:
	match severity:
		SEVERITY_WARNING, SEVERITY_ERROR, SEVERITY_CRITICAL:
			return severity
		_:
			return SEVERITY_INFO


func _normalize_state_status(status: StringName) -> StringName:
	match status:
		STATE_PENDING, STATE_RUNNING, STATE_WAITING_FOR_USER, STATE_RETRYING, STATE_SUCCEEDED, STATE_FAILED, STATE_CANCELLED:
			return status
		_:
			return STATE_RUNNING


func _get_default_terminal_operation_state(success: bool) -> StringName:
	return &"completed" if success else &"failed"


func _get_default_terminal_state_status(success: bool) -> StringName:
	return STATE_SUCCEEDED if success else STATE_FAILED


func _normalize_terminal_operation_state(terminal_state: StringName, success: bool) -> StringName:
	match terminal_state:
		&"completed", &"failed", &"cancelled":
			return terminal_state
		_:
			return _get_default_terminal_operation_state(success)


func _normalize_terminal_state_status(terminal_state_status: StringName, success: bool) -> StringName:
	match terminal_state_status:
		STATE_SUCCEEDED, STATE_FAILED, STATE_CANCELLED:
			return terminal_state_status
		_:
			return _get_default_terminal_state_status(success)


func _severity_to_status(severity: StringName) -> StringName:
	match severity:
		SEVERITY_CRITICAL:
			return &"critical"
		SEVERITY_ERROR:
			return &"error"
		SEVERITY_WARNING:
			return &"warning"
		_:
			return &"ok"


func _max_status(left: StringName, right: StringName) -> StringName:
	if _status_rank(right) > _status_rank(left):
		return right
	return left


func _status_rank(status: StringName) -> int:
	match status:
		&"critical":
			return 3
		&"error":
			return 2
		&"warning":
			return 1
		_:
			return 0


func _is_slow_operation_duration(duration_ms: float) -> bool:
	return slow_operation_threshold_ms >= 0.0 and duration_ms >= slow_operation_threshold_ms


func _datetime_from_unix(timestamp_unix: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(timestamp_unix), true)


func _append_line(lines: PackedStringArray, value: String) -> void:
	var _appended: bool = lines.append(value)
