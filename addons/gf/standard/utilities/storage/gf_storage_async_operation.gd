## GFStorageAsyncOperation: 单次异步存储请求句柄。
##
## 句柄同时表达单个 consumer 的 caller 终态与共享物理请求终态。既有
## `completed/is_completed/get_result` 始终表示物理终态；caller 可通过独立查询和
## `caller_completed` 提前结束观察，而不会伪造磁盘工作已经停止。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 10.0.0
class_name GFStorageAsyncOperation
extends RefCounted


# --- 信号 ---

## 物理请求进入终态时发出一次；caller 提前结束观察不会触发该信号。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求 ID 匹配的隔离结果。
signal completed(result: GFStorageAsyncResult)

## 当前 consumer 进入 caller 终态时发出一次。
##
## owner 已释放时框架可抑制该信号；终态仍可通过 `get_caller_result()` 查询。该信号
## 不代表物理工作已结束。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result: 与当前 consumer ID 匹配的隔离 caller 结果。
signal caller_completed(result: GFStorageAsyncCallerResult)


# --- 常量 ---

## 异步写入请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_SAVE: StringName = &"save"

## 异步读取请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_LOAD: StringName = &"load"

## 异步删除请求。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_DELETE: StringName = &"delete"

## 异步破坏性 family reset/recreate 请求。
## [br]
## @api public
## [br]
## @since 11.0.0
const OPERATION_RESET: StringName = &"reset"


# --- 私有变量 ---

var _state: GFStorageAsyncRequestState = GFStorageAsyncRequestState.new()
var _result: GFStorageAsyncResult = null
var _caller_result: GFStorageAsyncCallerResult = null
var _late_settlement_diagnostic: Dictionary = {}
var _late_settlement_diagnostic_taken: bool = false
var _payload_transfer: GFStoragePayloadTransfer = null
var _payload_attempt_id: int = 0
var _payload_attempt_finished: bool = false
var _failed_payload_reclaimed: bool = false


# --- 公共方法 ---

## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 大于零的请求 ID。
func get_request_id() -> int:
	return _state.get_request_id()


## 获取当前 consumer 的 Utility 内唯一 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 大于零的 consumer ID；尚未配置时返回 0。
func get_consumer_id() -> int:
	return _state.get_consumer_id()


## 获取请求类型。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `OPERATION_SAVE`、`OPERATION_LOAD`、`OPERATION_DELETE` 或 `OPERATION_RESET`。
func get_operation() -> StringName:
	return _state.get_operation()


## 获取规范化存储文件名。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已通过路径校验的请求返回规范相对文件名；校验前被拒绝时返回空字符串。
func get_file_name() -> String:
	return _state.get_file_name()


## 检查物理请求是否等待终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已配置且未完成时返回 true。
func is_pending() -> bool:
	return _state.is_pending()


## 检查物理请求是否已有终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _state.is_completed()


## 获取物理终态结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFStorageAsyncResult:
	return _result.duplicate_result() if _result != null else null


## 检查当前 consumer 是否仍等待 caller 终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已配置且 caller 尚未完成时返回 true。
func is_caller_pending() -> bool:
	return _state.is_caller_pending()


## 检查当前 consumer 是否已有 caller 终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return caller 已完成时返回 true。
func is_caller_completed() -> bool:
	return _state.is_caller_completed()


## 获取 caller 终态结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return caller 已完成时返回隔离结果；等待中返回 null。
func get_caller_result() -> GFStorageAsyncCallerResult:
	return _caller_result.duplicate_result() if _caller_result != null else null


## 显式结束当前 consumer 对物理请求的观察。
##
## 返回 true 只表示 caller 终态已被 Utility 线性化，不保证物理 worker 已取消。
## save/delete/reset 已接纳时可能进入 `OUTCOME_UNKNOWN`，物理终态仍通过 `completed` 到达。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param reason: 最长保留 128 字符的稳定原因；空值规范化为 `cancelled`。
## [br]
## @return 本次调用首次结束 caller 观察时返回 true。
func cancel_observation(reason: StringName = &"cancelled") -> bool:
	return _state.cancel_observation(reason)


## 获取当前请求关联的 opaque payload transfer。
##
## 该句柄不公开 payload，可在当前 attempt 仍运行时交给同一 Storage 和规范文件
## 发起 timeout retry。调用方完成整个重试 generation 后必须显式 `release()`。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 等待中的 transfer-backed save 请求返回句柄；终态及普通 save/load/delete/reset 请求返回 null。
func get_payload_transfer() -> GFStoragePayloadTransfer:
	if not is_pending():
		return null
	return _payload_transfer


## 一次性取回失败请求关联的 opaque payload transfer。
##
## 仅请求进入失败终态且 attempt lease 已结束后可取回。返回值仍不公开 payload，
## 但可直接用于同一冻结 Storage、文件名和 codec options 的重试。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 首次取回失败 transfer 时返回原句柄；其他情况返回 null。
func reclaim_failed_payload() -> GFStoragePayloadTransfer:
	if (
		_result == null
		or _result.is_successful()
		or _payload_transfer == null
		or not _payload_attempt_finished
		or _failed_payload_reclaimed
	):
		return null
	_failed_payload_reclaimed = true
	return _payload_transfer


# --- 框架内部方法 ---

## 获取同一请求的无载荷生命周期记录，供 executor 统一仲裁。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @return 本 Operation 持有的内部记录；不包含领域结果。
func get_request_state_for_framework() -> GFStorageAsyncRequestState:
	return _state


## 由 Storage Utility 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 10.0.0
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param operation: 请求类型。
## [br]
## @param file_name: 当前 Storage root 内的规范相对文件名；校验前初始化请求身份时允许为空。
## [br]
## @return 首次配置成功返回 true。
func configure_for_framework(request_id: int, operation: StringName, file_name: String) -> bool:
	return _state.configure_for_framework(request_id, operation, file_name)


## 配置当前 consumer 的生命周期观察与弱取消委托。
##
## 方法只建立配置和 token 连接，不立即终结预先取消的 token；Utility 应在写入规范
## logical path 后调用 `poll_caller_lifecycle_for_framework()`，以保留稳定请求身份。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param consumer_id: Utility 内唯一 consumer ID。
## [br]
## @param options: 可选 owner/token/timeout 快照；null 表示无自动观察边界。
## [br]
## @param clock: 用于 caller deadline 与诊断时间的单调时钟。
## [br]
## @param cancel_delegate: 无绑定参数的 Utility 对象方法，签名为 `(operation, end_kind, reason) -> bool`。
## [br]
## @return 首次完整配置成功返回 true。
func configure_consumer_for_framework(
	consumer_id: int,
	options: GFStorageAsyncRequestOptions,
	clock: GFClock,
	cancel_delegate: Callable
) -> bool:
	return _state.configure_consumer_for_framework(
		consumer_id, options, clock, cancel_delegate, self
	)


## 按 token、owner、deadline 的固定优先级轮询 caller 生命周期。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 本次轮询的 lifecycle cause 被 Utility 接受并线性化时返回 true。
func poll_caller_lifecycle_for_framework() -> bool:
	return _state.poll_caller_lifecycle_for_framework()


## 标记物理 worker 已接纳请求。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 首次在物理终态前标记成功返回 true。
func mark_worker_accepted_for_framework() -> bool:
	return _state.mark_worker_accepted_for_framework()


## 标记 Utility 已请求在安全点终止物理工作。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return worker 尚未接纳且请求仍可安全结算取消时返回 true；重复标记保持幂等。
func mark_physical_cancel_requested_for_framework() -> bool:
	return _state.mark_physical_cancel_requested_for_framework()


## 写入 caller-first 终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param status: `CANCELLED` 或 `OUTCOME_UNKNOWN`。
## [br]
## @param end_kind: 非 `PHYSICAL_SETTLEMENT` 的 first-terminal 来源。
## [br]
## @param reason: 最长保留 128 字符的稳定原因。
## [br]
## @param emit_caller_signal: false 时只写入可查询终态，不调用 caller listeners。
## [br]
## @return 首次写入合法 caller 终态时返回 true。
func complete_caller_for_framework(
	status: GFStorageAsyncCallerResult.Status,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName = &"",
	emit_caller_signal: bool = true
) -> bool:
	if not Thread.is_main_thread() or not is_caller_pending():
		return false
	var error_code: Error = (
		ERR_BUSY if status == GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN else ERR_SKIP
	)
	var completed_at_msec: int = _state.get_monotonic_msec_for_framework()
	var caller_result_value: GFStorageAsyncCallerResult = _make_caller_result(
		status, end_kind, reason, error_code, null, completed_at_msec
	)
	if caller_result_value == null:
		return false
	if not _state.commit_caller_for_framework(status, end_kind, reason, completed_at_msec):
		return false
	_caller_result = caller_result_value
	if emit_caller_signal and _state.can_emit_caller_signal_for_framework():
		caller_completed.emit(_caller_result.duplicate_result())
	_state.finish_caller_notification_for_framework()
	return true


## 在请求入队前写入 Storage 规范化后的文件名。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 10.0.0
## [br]
## @param file_name: 当前 Storage root 内的规范相对文件名。
## [br]
## @return 请求仍在等待、尚无文件名且新文件名非空时返回 true。
func set_file_name_for_framework(file_name: String) -> bool:
	return _state.set_file_name_for_framework(file_name)


## 关联一次 transfer-backed Storage attempt。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param transfer: 已取得 attempt lease 的 opaque transfer。
## [br]
## @param attempt_id: transfer 分配的活动 attempt ID。
## [br]
## @return save 请求首次关联合法 attempt 时返回 true。
func configure_payload_attempt_for_framework(
	transfer: GFStoragePayloadTransfer,
	attempt_id: int
) -> bool:
	if (
		not is_pending()
		or get_operation() != OPERATION_SAVE
		or transfer == null
		or attempt_id <= 0
		or _payload_transfer != null
	):
		return false
	_payload_transfer = transfer
	_payload_attempt_id = attempt_id
	return true


## 结束当前请求持有的 transfer attempt lease。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 首次结束关联 attempt 时返回 true。
func finish_payload_attempt_for_framework() -> bool:
	if (
		_payload_transfer == null
		or _payload_attempt_id <= 0
		or _payload_attempt_finished
	):
		return false
	if not _payload_transfer.finish_attempt_for_framework(_payload_attempt_id):
		return false
	_payload_attempt_finished = true
	return true


## 检查 payload attempt lease 是否允许物理终态结算。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 没有关联 transfer，或已通过 `finish_payload_attempt_for_framework()` 结束 attempt 时返回 true。
func is_payload_attempt_ready_for_settlement_for_framework() -> bool:
	return _payload_transfer == null or _payload_attempt_finished


## 由 Storage Utility 写入并发出唯一物理终态。
##
## 物理先完成时先原子写入两套终态，再依次发出 `completed` 与
## `caller_completed`；caller 已提前完成时只发出物理信号并冻结 late diagnostic。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求身份一致的结果。
## [br]
## @param end_kind: 领域结果使用 `PHYSICAL_SETTLEMENT`；queued cancellation 使用其真实 caller cause。
## [br]
## @param reason: caller 终态的有界稳定原因。
## [br]
## @param emit_caller_signal: false 时写入 caller 终态但抑制 caller 信号。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(
	result: GFStorageAsyncResult,
	end_kind: GFStorageAsyncCallerResult.EndKind = (
		GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT
	),
	reason: StringName = &"",
	emit_caller_signal: bool = true
) -> bool:
	if not is_pending() or result == null:
		return false
	if (
		result.get_request_id() != get_request_id()
		or result.get_operation() != get_operation()
		or result.get_file_name() != get_file_name()
	):
		return false
	if not is_payload_attempt_ready_for_settlement_for_framework():
		return false
	if not _state.can_commit_physical_for_framework(result.get_settlement_kind(), end_kind):
		return false
	var caller_was_completed: bool = is_caller_completed()
	var completed_at_msec: int = _state.get_monotonic_msec_for_framework()
	var physical_copy: GFStorageAsyncResult = result.duplicate_result()
	var physical_caller_result: GFStorageAsyncCallerResult = null
	if not caller_was_completed:
		physical_caller_result = _make_caller_result(
			GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED,
			end_kind, reason, physical_copy.get_error_code(), physical_copy, completed_at_msec
		)
		if physical_caller_result == null:
			return false
	if not _state.commit_physical_for_framework(
		physical_copy.get_settlement_kind(), physical_copy.is_successful(),
		physical_copy.get_error_code(), end_kind, reason, completed_at_msec,
		physical_copy.get_read_failure_kind_for_framework()
	):
		return false
	_result = physical_copy
	if not caller_was_completed:
		_caller_result = physical_caller_result
	else:
		_late_settlement_diagnostic = _make_late_settlement_diagnostic()
	completed.emit(_result.duplicate_result())
	if not caller_was_completed and emit_caller_signal and _state.can_emit_caller_signal_for_framework():
		caller_completed.emit(_caller_result.duplicate_result())
	if not caller_was_completed:
		_state.finish_caller_notification_for_framework()
	return true


## 一次性取得 caller-first 请求的有界 late-settlement 诊断。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 尚无 late settlement 或已经取走时返回空字典。
## [br]
## @schema return: Exact Dictionary with consumer_id, request_id, operation, file_name, caller_status, caller_end_kind, caller_reason, caller_completed_msec, worker_accepted, physical_cancel_requested, settlement_kind, physical_ok, physical_error_code, physical_completed_msec, late_duration_msec, read_failure_kind, write_failure_kind, delete_failure_kind, delete_existing_member_count, delete_removed_member_count, delete_remaining_member_count, delete_failed_member, reset_failure_kind, reset_source_kind, reset_failed_phase, reset_retired_member_count, reset_recreated_member_count, reset_remaining_evidence_count, and reset_failed_member fields.
func take_late_settlement_diagnostic_for_framework() -> Dictionary:
	if _late_settlement_diagnostic.is_empty() or _late_settlement_diagnostic_taken:
		return {}
	_late_settlement_diagnostic_taken = true
	return _late_settlement_diagnostic.duplicate(true)


# --- 私有/辅助方法 ---

func _make_caller_result(
	status: GFStorageAsyncCallerResult.Status,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName,
	error_code: Error,
	physical_result: GFStorageAsyncResult,
	completed_at_msec: int
) -> GFStorageAsyncCallerResult:
	var caller_result_value: GFStorageAsyncCallerResult = GFStorageAsyncCallerResult.new()
	var configured: bool = caller_result_value.configure_for_framework(
		get_consumer_id(),
		get_request_id(),
		get_operation(),
		get_file_name(),
		status,
		end_kind,
		reason,
		completed_at_msec,
		error_code,
		physical_result
	)
	return caller_result_value if configured else null


func _make_late_settlement_diagnostic() -> Dictionary:
	var read_failure_kind: int = -1
	var write_failure_kind: int = -1
	var delete_failure_kind: int = -1
	var delete_existing_member_count: int = -1
	var delete_removed_member_count: int = -1
	var delete_remaining_member_count: int = -1
	var delete_failed_member: int = -1
	var reset_failure_kind: int = -1
	var reset_source_kind: int = -1
	var reset_failed_phase: int = -1
	var reset_retired_member_count: int = -1
	var reset_recreated_member_count: int = -1
	var reset_remaining_evidence_count: int = -1
	var reset_failed_member: int = -1
	if _result.get_settlement_kind() == GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT:
		match get_operation():
			OPERATION_SAVE:
				write_failure_kind = int(_result.get_write_failure_kind())
			OPERATION_LOAD:
				read_failure_kind = _result.get_read_failure_kind_for_framework()
			OPERATION_DELETE:
				var delete_result: GFStorageDeleteResult = _result.get_delete_result()
				if delete_result != null:
					delete_failure_kind = int(delete_result.get_failure_kind())
					delete_existing_member_count = delete_result.get_existing_member_count()
					delete_removed_member_count = delete_result.get_removed_member_count()
					delete_remaining_member_count = delete_result.get_remaining_member_count()
					delete_failed_member = int(delete_result.get_failed_member())
			OPERATION_RESET:
				var reset_result: GFStorageFamilyResetResult = _result.get_reset_result()
				if reset_result != null:
					reset_failure_kind = int(reset_result.get_failure_kind())
					reset_source_kind = int(reset_result.get_source_kind())
					reset_failed_phase = int(reset_result.get_failed_phase())
					reset_retired_member_count = reset_result.get_retired_member_count()
					reset_recreated_member_count = reset_result.get_recreated_member_count()
					reset_remaining_evidence_count = reset_result.get_remaining_evidence_count()
					reset_failed_member = int(reset_result.get_failed_member())

	var diagnostic: Dictionary = _state.take_late_settlement_diagnostic_for_framework()
	diagnostic.merge({
		"read_failure_kind": read_failure_kind,
		"write_failure_kind": write_failure_kind,
		"delete_failure_kind": delete_failure_kind,
		"delete_existing_member_count": delete_existing_member_count,
		"delete_removed_member_count": delete_removed_member_count,
		"delete_remaining_member_count": delete_remaining_member_count,
		"delete_failed_member": delete_failed_member,
		"reset_failure_kind": reset_failure_kind,
		"reset_source_kind": reset_source_kind,
		"reset_failed_phase": reset_failed_phase,
		"reset_retired_member_count": reset_retired_member_count,
		"reset_recreated_member_count": reset_recreated_member_count,
		"reset_remaining_evidence_count": reset_remaining_evidence_count,
		"reset_failed_member": reset_failed_member,
	}, true)
	return diagnostic
