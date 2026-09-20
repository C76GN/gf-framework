## GFStorageAsyncRequestState: Storage 请求共用的无载荷生命周期记录。
##
## 只冻结请求身份、caller 与物理终态，不保存或发布领域载荷。
## 结果适配层在通知前完成自己的投影，通知后释放等待期 owner 快照。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFStorageAsyncRequestState
extends RefCounted


# --- 常量 ---

const _MAX_REASON_CHARACTERS: int = 128
const _MAX_INT64: int = 9_223_372_036_854_775_807


# --- 私有变量 ---

var _request_id: int = 0
var _consumer_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _clock: GFClock = null
var _request_options: GFStorageAsyncRequestOptions = null
var _cancel_delegate: GFWeakMethodInvocation = null
var _cancel_subject_ref: WeakRef = null
var _cancel_token: GFCancellationToken = null
var _cancel_token_callback: Callable = Callable()
var _deadline_msec: int = 0
var _consumer_configured: bool = false
var _worker_accepted: bool = false
var _physical_cancel_requested: bool = false
var _physical_snapshot: Dictionary = {}
var _caller_snapshot: Dictionary = {}
var _late_settlement_diagnostic: Dictionary = {}
var _late_settlement_diagnostic_taken: bool = false


# --- 框架内部方法 ---

## 获取物理请求 ID。
## [br]
## @api framework_internal
## [br]
## @return 未配置时为 0。
func get_request_id() -> int:
	return _request_id


## 获取 caller ID。
## [br]
## @api framework_internal
## [br]
## @return 未配置时为 0。
func get_consumer_id() -> int:
	return _consumer_id


## 获取 I/O 类型，不包含交付模式。
## [br]
## @api framework_internal
## [br]
## @return save、load、delete 或 reset；未配置时为空。
func get_operation() -> StringName:
	return _operation


## 获取已验证的逻辑文件身份。
## [br]
## @api framework_internal
## [br]
## @return 准入校验前允许为空。
func get_file_name() -> String:
	return _file_name


## 检查物理终态是否仍待提交。
## [br]
## @api framework_internal
## [br]
## @return 已配置且没有物理终态时为 true。
func is_pending() -> bool:
	return _request_id > 0 and _physical_snapshot.is_empty()


## 检查物理终态是否已经冻结。
## [br]
## @api framework_internal
## [br]
## @return 已有物理终态时为 true。
func is_completed() -> bool:
	return not _physical_snapshot.is_empty()


## 检查 caller 是否仍在等待。
## [br]
## @api framework_internal
## [br]
## @return 已配置身份且尚无 caller 终态时为 true。
func is_caller_pending() -> bool:
	return _consumer_id > 0 and _caller_snapshot.is_empty()


## 检查 caller 终态是否已经冻结。
## [br]
## @api framework_internal
## [br]
## @return 已有 caller 终态时为 true。
func is_caller_completed() -> bool:
	return not _caller_snapshot.is_empty()


## 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @param request_id: 大于零的 Utility 请求 ID。
## [br]
## @param operation: 既有 I/O 类型。
## [br]
## @param file_name: 已验证逻辑文件身份；准入前可为空。
## [br]
## @return 首次合法配置成功时为 true。
func configure_for_framework(request_id: int, operation: StringName, file_name: String) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	if operation not in [&"save", &"load", &"delete", &"reset"]:
		return false
	_request_id = request_id
	_consumer_id = request_id
	_operation = operation
	_file_name = file_name
	_clock = GFClock.new()
	return true


## 建立等待期生命周期与弱取消委托，不立即仲裁预取消 token。
## [br]
## @api framework_internal
## [br]
## @param consumer_id: 大于零的 Utility consumer ID。
## [br]
## @param options: 等待期不可变选项，或 null。
## [br]
## @param clock: 单调时钟。
## [br]
## @param cancel_delegate: 无绑定参数的对象方法，接收 subject、EndKind 整数和 reason。
## [br]
## @param cancel_subject: 弱持有的旧句柄；null 表示委托接收本记录。
## [br]
## @return 首次完整配置成功时为 true。
func configure_consumer_for_framework(
	consumer_id: int,
	options: GFStorageAsyncRequestOptions,
	clock: GFClock,
	cancel_delegate: Callable,
	cancel_subject: Object = null
) -> bool:
	if (
		not is_pending() or is_caller_completed() or _consumer_configured
		or consumer_id <= 0 or clock == null
		or (options != null and not options.is_valid())
		or not cancel_delegate.is_valid() or cancel_delegate.get_bound_arguments_count() != 0
	):
		return false
	var delegate_target: Object = cancel_delegate.get_object()
	var delegate_method: StringName = cancel_delegate.get_method()
	if not is_instance_valid(delegate_target) or delegate_method.is_empty():
		return false
	if cancel_subject != null and not is_instance_valid(cancel_subject):
		return false
	var cancellation_token: GFCancellationToken = (
		options.get_cancel_token_for_framework() if options != null else null
	)
	var token_callback: Callable = Callable()
	if cancellation_token != null:
		var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_cancel_token_requested")
		token_callback = func(reason: StringName) -> void:
			var _invocation_result: Dictionary = invocation.invoke([reason])
		var connect_error: int = cancellation_token.cancel_requested.connect(token_callback, CONNECT_ONE_SHOT)
		if connect_error != OK:
			return false
	_consumer_id = consumer_id
	_clock = clock
	_request_options = options
	_cancel_delegate = GFWeakMethodInvocation.new(delegate_target, delegate_method)
	_cancel_subject_ref = weakref(cancel_subject if cancel_subject != null else self)
	_cancel_token = cancellation_token
	_cancel_token_callback = token_callback
	_deadline_msec = _calculate_deadline_msec(
		clock.get_monotonic_msec(), options.get_timeout_msec_for_framework() if options != null else 0
	)
	_consumer_configured = true
	return true


## 按 token、owner、deadline 的既有优先级请求 Utility 仲裁。
## [br]
## @api framework_internal
## [br]
## @return Utility 接受本次 caller 终结请求时为 true。
func poll_caller_lifecycle_for_framework() -> bool:
	if not Thread.is_main_thread() or not is_caller_pending() or not _consumer_configured:
		return false
	if _cancel_token != null and _cancel_token.is_cancel_requested():
		return _request_caller_terminal(
			GFStorageAsyncCallerResult.EndKind.TOKEN_CANCELLED,
			_normalize_reason(_cancel_token.get_cancel_reason(), &"token_cancelled")
		)
	if _request_options != null and _request_options.owner_is_released_for_framework():
		return _request_caller_terminal(GFStorageAsyncCallerResult.EndKind.OWNER_RELEASED, &"owner_released")
	if _deadline_msec > 0 and _clock != null and _clock.get_monotonic_msec() >= _deadline_msec:
		return _request_caller_terminal(GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED, &"deadline_expired")
	return false


## 显式请求 Utility 结束 caller 等待。
## [br]
## @api framework_internal
## [br]
## @param reason: 有界稳定原因。
## [br]
## @return 本次请求已被 Utility 线性化时为 true。
func cancel_observation(reason: StringName = &"cancelled") -> bool:
	if not Thread.is_main_thread() or not is_caller_pending():
		return false
	return _request_caller_terminal(
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL, _normalize_reason(reason, &"cancelled")
	)


## 标记 worker 接纳，不改变 caller 等待状态。
## [br]
## @api framework_internal
## [br]
## @return 首次在物理取消之前标记时为 true。
func mark_worker_accepted_for_framework() -> bool:
	if not is_pending() or _worker_accepted or _physical_cancel_requested:
		return false
	_worker_accepted = true
	return true


## 标记接纳前物理取消意图。
## [br]
## @api framework_internal
## [br]
## @return 等待中且 worker 未接纳时为 true，重复标记幂等。
func mark_physical_cancel_requested_for_framework() -> bool:
	if not is_pending() or _worker_accepted:
		return false
	_physical_cancel_requested = true
	return true


## 获取 worker 是否已接纳。
## [br]
## @api framework_internal
## [br]
## @return 已接纳时为 true。
func is_worker_accepted_for_framework() -> bool:
	return _worker_accepted


## 获取接纳前物理取消是否已被请求。
## [br]
## @api framework_internal
## [br]
## @return 已标记时为 true。
func is_physical_cancel_requested_for_framework() -> bool:
	return _physical_cancel_requested


## 在入队前补充规范逻辑文件身份。
## [br]
## @api framework_internal
## [br]
## @param file_name: 非空规范身份。
## [br]
## @return 请求仍等待且原身份为空时为 true。
func set_file_name_for_framework(file_name: String) -> bool:
	if not is_pending() or not _file_name.is_empty() or file_name.is_empty():
		return false
	_file_name = file_name
	return true


## 提交 caller-first 终态，不发布通知或触碰领域载荷。
## [br]
## @api framework_internal
## [br]
## @param status: load 使用 CANCELLED；有写副作用的请求使用 OUTCOME_UNKNOWN。
## [br]
## @param end_kind: 非 PHYSICAL_SETTLEMENT 的合法来源。
## [br]
## @param reason: 有界稳定原因。
## [br]
## @param completed_at_msec: 适配层准备投影的单调时间；-1 使用当前时钟。
## [br]
## @return 首次合法提交成功时为 true。
func commit_caller_for_framework(
	status: GFStorageAsyncCallerResult.Status,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName = &"",
	completed_at_msec: int = -1
) -> bool:
	if not Thread.is_main_thread() or not is_caller_pending():
		return false
	if not GFStorageAsyncCallerResult.EndKind.values().has(int(end_kind)):
		return false
	if end_kind == GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT or completed_at_msec < -1:
		return false
	if (
		(status == GFStorageAsyncCallerResult.Status.CANCELLED and _operation != &"load")
		or (status == GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN and _operation == &"load")
		or status not in [GFStorageAsyncCallerResult.Status.CANCELLED, GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN]
	):
		return false
	_store_caller(
		status, end_kind, reason,
		ERR_BUSY if status == GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN else ERR_SKIP,
		get_monotonic_msec_for_framework() if completed_at_msec < 0 else completed_at_msec
	)
	_disconnect_consumer_lifecycle()
	return true


## 校验无载荷物理终态的生命周期条件。
## [br]
## @api framework_internal
## [br]
## @param settlement_kind: 领域结果或接纳前取消。
## [br]
## @param end_kind: 领域结果必须为 PHYSICAL_SETTLEMENT。
## [br]
## @return 允许提交时为 true；不改变状态。
func can_commit_physical_for_framework(
	settlement_kind: GFStorageAsyncResult.SettlementKind,
	end_kind: GFStorageAsyncCallerResult.EndKind
) -> bool:
	if not is_pending() or not GFStorageAsyncCallerResult.EndKind.values().has(int(end_kind)):
		return false
	if settlement_kind == GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT:
		return end_kind == GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
	return (
		settlement_kind == GFStorageAsyncResult.SettlementKind.CANCELLED
		and end_kind != GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
		and not _worker_accepted and _physical_cancel_requested
	)


## 原子冻结物理终态，并在 caller 未提前完成时同时冻结 caller 终态。
## [br]
## @api framework_internal
## [br]
## @param settlement_kind: 领域结果或接纳前取消。
## [br]
## @param ok: 领域操作是否成功。
## [br]
## @param error_code: 与 ok 闭合一致的 Error。
## [br]
## @param end_kind: caller 来源。
## [br]
## @param reason: 有界稳定原因。
## [br]
## @param completed_at_msec: 投影准备时间；-1 使用当前时钟。
## [br]
## @param read_failure_kind: 读取失败分类；非读取或未提供时为 -1。
## [br]
## @return 首次合法提交成功时为 true，不发布任何用户通知。
func commit_physical_for_framework(
	settlement_kind: GFStorageAsyncResult.SettlementKind,
	ok: bool,
	error_code: Error,
	end_kind: GFStorageAsyncCallerResult.EndKind = GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT,
	reason: StringName = &"",
	completed_at_msec: int = -1,
	read_failure_kind: int = -1
) -> bool:
	if not can_commit_physical_for_framework(settlement_kind, end_kind) or completed_at_msec < -1:
		return false
	if ok != (error_code == OK):
		return false
	if settlement_kind == GFStorageAsyncResult.SettlementKind.CANCELLED and error_code != ERR_SKIP:
		return false
	var timestamp: int = get_monotonic_msec_for_framework() if completed_at_msec < 0 else completed_at_msec
	_physical_snapshot = {
		"settlement_kind": int(settlement_kind), "ok": ok, "error_code": int(error_code),
		"completed_at_msec": timestamp,
	}
	if not is_caller_completed():
		_store_caller(GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED, end_kind, reason, error_code, timestamp)
		_disconnect_consumer_lifecycle()
	else:
		_late_settlement_diagnostic = _make_late_settlement_diagnostic(read_failure_kind)
	return true


## 获取无载荷物理终态副本。
## [br]
## @api framework_internal
## [br]
## @return 等待中为空。
## [br]
## @schema return: Dictionary，完成时精确包含 settlement_kind: int、ok: bool、error_code: int、completed_at_msec: int。
func get_physical_snapshot_for_framework() -> Dictionary:
	return _physical_snapshot.duplicate()


## 获取无载荷 caller 终态副本。
## [br]
## @api framework_internal
## [br]
## @return 等待中为空。
## [br]
## @schema return: Dictionary，完成时精确包含 status: int、end_kind: int、reason: StringName、error_code: int、completed_at_msec: int。
func get_caller_snapshot_for_framework() -> Dictionary:
	return _caller_snapshot.duplicate()


## 一次性取得 caller-first 的无载荷 late 诊断；适配层可补领域标量。
## [br]
## @api framework_internal
## [br]
## @return 尚无晚到结果或已经取走时为空。
## [br]
## @schema return: Dictionary，包含请求和 caller 身份、caller_status、caller_end_kind、caller_reason、caller_completed_msec、worker_accepted、physical_cancel_requested、settlement_kind、physical_ok、physical_error_code、physical_completed_msec、late_duration_msec、read_failure_kind；write/delete/reset 分类及计数使用既有固定字段并默认 -1。
func take_late_settlement_diagnostic_for_framework() -> Dictionary:
	if _late_settlement_diagnostic.is_empty() or _late_settlement_diagnostic_taken:
		return {}
	_late_settlement_diagnostic_taken = true
	return _late_settlement_diagnostic.duplicate()


## 在实际发出 caller 通知前复核等待期 owner。
## [br]
## @api framework_internal
## [br]
## @return 未绑定 owner 或 owner 仍存活时为 true。
func can_emit_caller_signal_for_framework() -> bool:
	return _request_options == null or not _request_options.owner_is_released_for_framework()


## 完成 caller 通知后释放等待期 owner 快照。
## [br]
## @api framework_internal
## [br]
## @return 无返回值；caller 尚未完成时不清理。
func finish_caller_notification_for_framework() -> void:
	if is_caller_completed():
		_request_options = null


## 获取规范化单调时间供适配层先准备结果投影。
## [br]
## @api framework_internal
## [br]
## @return 非负毫秒时间。
func get_monotonic_msec_for_framework() -> int:
	return maxi(_clock.get_monotonic_msec(), 0) if _clock != null else Time.get_ticks_msec()


# --- 私有/辅助方法 ---

func _make_late_settlement_diagnostic(read_failure_kind: int) -> Dictionary:
	var caller_time: int = GFVariantData.get_option_int(_caller_snapshot, "completed_at_msec")
	var physical_time: int = GFVariantData.get_option_int(_physical_snapshot, "completed_at_msec")
	return {
		"consumer_id": _consumer_id, "request_id": _request_id,
		"operation": _operation, "file_name": _file_name,
		"caller_status": GFVariantData.get_option_int(_caller_snapshot, "status"),
		"caller_end_kind": GFVariantData.get_option_int(_caller_snapshot, "end_kind"),
		"caller_reason": GFVariantData.get_option_string_name(_caller_snapshot, "reason"),
		"caller_completed_msec": caller_time,
		"worker_accepted": _worker_accepted,
		"physical_cancel_requested": _physical_cancel_requested,
		"settlement_kind": GFVariantData.get_option_int(_physical_snapshot, "settlement_kind"),
		"physical_ok": GFVariantData.get_option_bool(_physical_snapshot, "ok"),
		"physical_error_code": GFVariantData.get_option_int(_physical_snapshot, "error_code"),
		"physical_completed_msec": physical_time,
		"late_duration_msec": maxi(physical_time - caller_time, 0),
		"read_failure_kind": read_failure_kind,
		"write_failure_kind": -1, "delete_failure_kind": -1,
		"delete_existing_member_count": -1, "delete_removed_member_count": -1,
		"delete_remaining_member_count": -1, "delete_failed_member": -1,
		"reset_failure_kind": -1, "reset_source_kind": -1, "reset_failed_phase": -1,
		"reset_retired_member_count": -1, "reset_recreated_member_count": -1,
		"reset_remaining_evidence_count": -1, "reset_failed_member": -1,
	}


func _store_caller(
	status: GFStorageAsyncCallerResult.Status,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName,
	error_code: Error,
	timestamp: int
) -> void:
	_caller_snapshot = {
		"status": int(status), "end_kind": int(end_kind),
		"reason": _normalize_reason(reason, _default_reason(end_kind)),
		"error_code": int(error_code), "completed_at_msec": timestamp,
	}


func _request_caller_terminal(end_kind: GFStorageAsyncCallerResult.EndKind, reason: StringName) -> bool:
	if not is_caller_pending() or _cancel_delegate == null or _cancel_subject_ref == null:
		return false
	var subject_value: Variant = _cancel_subject_ref.get_ref()
	if not subject_value is Object or not is_instance_valid(subject_value):
		return false
	var subject: Object = subject_value
	var invocation_result: Dictionary = _cancel_delegate.invoke([
		subject, int(end_kind), _normalize_reason(reason, &"cancelled"),
	])
	var status_value: Variant = invocation_result.get("status", &"")
	if not status_value is StringName:
		return false
	var invocation_status: StringName = status_value
	if invocation_status != GFWeakMethodInvocation.STATUS_INVOKED:
		return false
	var result_value: Variant = invocation_result.get("value", false)
	return result_value if result_value is bool else false


func _disconnect_consumer_lifecycle() -> void:
	if _cancel_token != null and _cancel_token_callback.is_valid() and _cancel_token.cancel_requested.is_connected(_cancel_token_callback):
		_cancel_token.cancel_requested.disconnect(_cancel_token_callback)
	_cancel_token = null
	_cancel_token_callback = Callable()
	_cancel_delegate = null
	_cancel_subject_ref = null
	_deadline_msec = 0


func _calculate_deadline_msec(now_msec: int, timeout_msec: int) -> int:
	if timeout_msec <= 0:
		return 0
	var normalized_now: int = maxi(now_msec, 0)
	return _MAX_INT64 if normalized_now >= _MAX_INT64 - timeout_msec else normalized_now + timeout_msec


func _normalize_reason(reason: StringName, fallback: StringName) -> StringName:
	var reason_text: String = String(reason if reason != &"" else fallback)
	return StringName(reason_text.left(_MAX_REASON_CHARACTERS))


func _default_reason(end_kind: GFStorageAsyncCallerResult.EndKind) -> StringName:
	match end_kind:
		GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT:
			return &"physical_settlement"
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL:
			return &"cancelled"
		GFStorageAsyncCallerResult.EndKind.TOKEN_CANCELLED:
			return &"token_cancelled"
		GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED:
			return &"deadline_expired"
		GFStorageAsyncCallerResult.EndKind.OWNER_RELEASED:
			return &"owner_released"
		GFStorageAsyncCallerResult.EndKind.UTILITY_DISPOSED:
			return &"utility_disposed"
	return &"caller_completed"


# --- 信号处理函数 ---

func _on_cancel_token_requested(reason: StringName) -> void:
	if is_caller_pending():
		var _terminal_linearized: bool = _request_caller_terminal(
			GFStorageAsyncCallerResult.EndKind.TOKEN_CANCELLED, _normalize_reason(reason, &"token_cancelled")
		)
