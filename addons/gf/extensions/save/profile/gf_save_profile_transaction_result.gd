## GFSaveProfileTransactionResult: Profile 事务的不可变终态快照。
##
## 结果不保留文档、section、Provider snapshot 或候选 payload，只保留有界阶段
## 证据、类型化回滚失败、调用方元数据和必要的 Lease。`duplicate_result()` 会
## 隔离复制集合，但刻意保留 Recovery/Reconcile Lease 的同一对象身份。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFSaveProfileTransactionResult
extends RefCounted


# --- 常量 ---

## 已存在 Profile 已成功激活。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_ACTIVATED: StringName = &"activated"

## 活跃身份已成功切换。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_SWITCHED: StringName = &"switched"

## 缺失 Profile 已从当前状态显式创建并激活。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_BOOTSTRAPPED: StringName = &"bootstrapped"

## 当前状态已被显式采用为恢复后的活跃 Profile。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_ADOPTED: StringName = &"adopted"

## 缺失目标已持久化，活动身份随后从来源原子切换到目标。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_BOOTSTRAPPED_AND_SWITCHED: StringName = &"bootstrapped_and_switched"

## 损坏目标已显式恢复并持久化，活动身份随后从来源原子切换到目标。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_ADOPTED_AND_SWITCHED: StringName = &"adopted_and_switched"

## 候选 sections 已应用并持久化。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_MUTATED: StringName = &"mutated"

## outcome_unknown 已通过显式重新读取完成对账。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_RECONCILED: StringName = &"reconciled"

## Profile ID、Provider topology 或事务身份无效。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"

## 一次性请求无效、已被 claim 或含不支持的数据。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## Recovery/Reconcile Lease 无效、已消费或绑定已经过期。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_LEASE: StringName = &"invalid_lease"

## 请求要求活跃 Profile，但当前 Provider domain 未激活。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INACTIVE: StringName = &"inactive"

## activate/bootstrap/adopt 的目标 domain 已有活跃 Profile。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_ALREADY_ACTIVE: StringName = &"already_active"

## Provider domain 正在执行互斥事务或发生不安全回调重入。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_BUSY: StringName = &"busy"

## Profile 配置不支持请求的读取或写入阶段。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"

## activate 或 switch 检测到可恢复的缺失/损坏目标，必须显式选择对应恢复入口。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_RECOVERY_REQUIRED: StringName = &"recovery_required"

## switch 无法把来源 Profile flush 到调用时 generation barrier。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_SOURCE_FLUSH_FAILED: StringName = &"source_flush_failed"

## switch 已 flush 来源，但无法读取或应用目标 Profile。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_TARGET_LOAD_FAILED: StringName = &"target_load_failed"

## Provider 回滚或候选应用前的快照采集失败。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"

## 至少一个候选 section 应用失败，且内存回滚成功。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_APPLY_FAILED: StringName = &"apply_failed"

## 恢复来源或候选内存状态时至少一个 Provider 回滚失败。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"

## 候选持久化确定失败，且内存回滚已成功。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_PERSIST_FAILED: StringName = &"persist_failed"

## 写请求已进入底层，但其最终物理副作用无法确认。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"

## Reconcile Lease 仍在等待 late settlement evidence。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_RECONCILE_PENDING: StringName = &"reconcile_pending"

## 显式重新读取或证据校验未能完成对账。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_RECONCILE_FAILED: StringName = &"reconcile_failed"

## Utility 释放时事务仍未完成。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_DISPOSED: StringName = &"disposed"

const _MAX_EVIDENCE_DEPTH: int = 16
const _MAX_EVIDENCE_ITEMS: int = 2048
const _MAX_EVIDENCE_STRING_LENGTH: int = 2048
const _MAX_ERROR_LENGTH: int = 2048


# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = &""
var _operation: StringName = &""
var _transaction_id: int = 0
var _source_profile_id: StringName = &""
var _target_profile_id: StringName = &""
var _active_profile_before: StringName = &""
var _active_profile_after: StringName = &""
var _phase: StringName = &""
var _error_code: Error = FAILED
var _error: String = ""
var _failed_section_id: StringName = &""
var _rollback_errors: Array[GFSaveRollbackFailure] = []
var _stage_evidence: Dictionary = {}
var _recovery_lease: GFSaveProfileRecoveryLease = null
var _reconcile_lease: GFSaveProfileReconcileLease = null
var _metadata: Dictionary = {}
var _started_at_msec: int = 0
var _completed_at_msec: int = 0


# --- 公共方法 ---

## 检查事务是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 终态属于成功状态时返回 true。
func is_successful() -> bool:
	return _status in _get_success_statuses()


## 获取稳定终态状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取事务类型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `GFSaveProfileTransactionOperation.OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取 Utility 生命周期内唯一的事务 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数事务 ID。
func get_transaction_id() -> int:
	return _transaction_id


## 获取事务来源 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 来源 Profile ID；不适用时为空。
func get_source_profile_id() -> StringName:
	return _source_profile_id


## 获取事务目标 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 目标 Profile ID；不适用时为空。
func get_target_profile_id() -> StringName:
	return _target_profile_id


## 获取事务开始前的活跃 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 开始前活跃身份；domain 未激活时为空。
func get_active_profile_before() -> StringName:
	return _active_profile_before


## 获取事务终态后的活跃 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 终态活跃身份；未激活或身份未知时为空。
func get_active_profile_after() -> StringName:
	return _active_profile_after


## 获取失败或成功发生的稳定阶段名。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 协调器定义的 payload-free 阶段名。
func get_phase() -> StringName:
	return _phase


## 获取 Godot Error 码。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功时为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取稳定错误描述。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功时为空；失败说明最多 2048 个字符。
func get_error() -> String:
	return _error


## 获取首个失败 section ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非 section 失败时为空。
func get_failed_section_id() -> StringName:
	return _failed_section_id


## 获取类型化 Provider 回滚失败证据。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 按回滚顺序排列的隔离副本。
func get_rollback_errors() -> Array[GFSaveRollbackFailure]:
	return _duplicate_rollback_errors(_rollback_errors)


## 获取不含文档、section 或 Provider payload 的阶段证据。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 有界 evidence 副本。
## [br]
## @schema return: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
func get_stage_evidence() -> Dictionary:
	return _stage_evidence.duplicate(true)


## 获取显式 bootstrap/adopt 或 bootstrap/adopt-and-switch 所需的同一身份 Recovery Lease。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return recovery_required 结果中的 Lease；其他结果通常为 null。
func get_recovery_lease() -> GFSaveProfileRecoveryLease:
	return _recovery_lease


## 获取持续围栏 outcome_unknown 的同一身份 Reconcile Lease。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 需要或正在对账时的 Lease；不适用时为 null。
func get_reconcile_lease() -> GFSaveProfileReconcileLease:
	return _reconcile_lease


## 获取调用方结果元数据副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 调用方在一次性请求中移交的结果元数据。
## [br]
## @schema return: Dictionary with caller-defined result metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取事务开始时间。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负单调毫秒时间。
func get_started_at_msec() -> int:
	return _started_at_msec


## 获取事务完成时间。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 不早于开始时间的单调毫秒时间。
func get_completed_at_msec() -> int:
	return _completed_at_msec


## 获取事务耗时。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负单调毫秒耗时。
func get_duration_msec() -> int:
	return maxi(_completed_at_msec - _started_at_msec, 0)


## 创建隔离结果副本。
##
## Recovery/Reconcile Lease 不复制，以维持原始恢复授权和持续对账生命周期。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新结果对象。
func duplicate_result() -> GFSaveProfileTransactionResult:
	var copy: GFSaveProfileTransactionResult = GFSaveProfileTransactionResult.new()
	if not _configured:
		return copy
	var _configured_copy: bool = copy.configure_for_framework({
		"status": _status,
		"operation": _operation,
		"transaction_id": _transaction_id,
		"source_profile_id": _source_profile_id,
		"target_profile_id": _target_profile_id,
		"active_profile_before": _active_profile_before,
		"active_profile_after": _active_profile_after,
		"phase": _phase,
		"error_code": int(_error_code),
		"error": _error,
		"failed_section_id": _failed_section_id,
		"rollback_errors": _rollback_errors,
		"stage_evidence": _stage_evidence,
		"recovery_lease": _recovery_lease,
		"reconcile_lease": _reconcile_lease,
		"metadata": _metadata,
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
	})
	assert(
		_configured_copy,
		"GFSaveProfileTransactionResult invariant failed while duplicating a terminal result."
	)
	return copy


## 转换为不包含持久化 payload 或 Lease 对象的报告字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 事务身份、终态、阶段证据、Lease 摘要、错误与时间信息。
## [br]
## @schema return: Payload-free Dictionary with transaction identity, status, active identities, phase, rollback failures, evidence, lease summaries, metadata, errors, and timing.
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"status": _status,
		"operation": _operation,
		"transaction_id": _transaction_id,
		"source_profile_id": _source_profile_id,
		"target_profile_id": _target_profile_id,
		"active_profile_before": _active_profile_before,
		"active_profile_after": _active_profile_after,
		"phase": _phase,
		"error_code": int(_error_code),
		"error": _error,
		"failed_section_id": _failed_section_id,
		"rollback_errors": _rollback_errors_to_dicts(),
		"stage_evidence": _stage_evidence.duplicate(true),
		"recovery_lease": _get_recovery_lease_summary(),
		"reconcile_lease": _get_reconcile_lease_summary(),
		"metadata": _metadata.duplicate(true),
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
		"duration_msec": get_duration_msec(),
	}


# --- 框架内部方法 ---

## 由 Save Profile 事务协调器一次性配置终态。
##
## `stage_evidence` 只接受有界、payload-free 数据；Recovery/Reconcile Lease
## 在写入和结果复制时保留同一对象身份。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param options: 完整终态字段。
## [br]
## @schema options: Dictionary with status, operation, transaction_id, source_profile_id, target_profile_id, active_profile_before, active_profile_after, phase, error_code, error, failed_section_id, rollback_errors, stage_evidence, recovery_lease, reconcile_lease, metadata, started_at_msec, and completed_at_msec.
## [br]
## @return 输入合法且首次配置时返回 true。
func configure_for_framework(options: Dictionary) -> bool:
	if _configured:
		return false
	var status: StringName = GFVariantData.get_option_string_name(options, "status")
	var operation: StringName = GFVariantData.get_option_string_name(options, "operation")
	var transaction_id: int = GFVariantData.get_option_int(options, "transaction_id")
	var stage_evidence: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"stage_evidence"
	)
	if (
		status not in _get_valid_statuses()
		or operation not in _get_valid_operations()
		or transaction_id <= 0
		or not _is_evidence_supported(stage_evidence)
	):
		return false

	var rollback_errors: Array[GFSaveRollbackFailure] = []
	var rollback_value: Variant = GFVariantData.get_option_value(options, "rollback_errors", [])
	if not _read_rollback_errors(rollback_value, rollback_errors):
		return false
	var recovery_lease: GFSaveProfileRecoveryLease = _read_recovery_lease(options)
	var reconcile_lease: GFSaveProfileReconcileLease = _read_reconcile_lease(options)
	if not _leases_match_status(
		status,
		operation,
		transaction_id,
		GFVariantData.get_option_string_name(options, "source_profile_id"),
		GFVariantData.get_option_string_name(options, "target_profile_id"),
		recovery_lease,
		reconcile_lease
	):
		return false

	_configured = true
	_status = status
	_operation = operation
	_transaction_id = transaction_id
	_source_profile_id = GFVariantData.get_option_string_name(options, "source_profile_id")
	_target_profile_id = GFVariantData.get_option_string_name(options, "target_profile_id")
	_active_profile_before = GFVariantData.get_option_string_name(
		options,
		"active_profile_before"
	)
	_active_profile_after = GFVariantData.get_option_string_name(
		options,
		"active_profile_after"
	)
	_phase = GFVariantData.get_option_string_name(options, "phase")
	_error_code = (
		OK
		if is_successful()
		else GFVariantData.get_option_int(options, "error_code", int(FAILED)) as Error
	)
	_error = (
		""
		if is_successful()
		else GFVariantData.get_option_string(options, "error").strip_edges().left(
			_MAX_ERROR_LENGTH
		)
	)
	_failed_section_id = GFVariantData.get_option_string_name(options, "failed_section_id")
	_rollback_errors = _duplicate_rollback_errors(rollback_errors)
	_stage_evidence = stage_evidence.duplicate(true)
	_recovery_lease = recovery_lease
	_reconcile_lease = reconcile_lease
	_metadata = GFVariantData.get_option_dictionary(options, "metadata")
	_started_at_msec = maxi(GFVariantData.get_option_int(options, "started_at_msec"), 0)
	_completed_at_msec = maxi(
		GFVariantData.get_option_int(options, "completed_at_msec"),
		_started_at_msec
	)
	return true


# --- 私有/辅助方法 ---

static func _get_success_statuses() -> Array[StringName]:
	return [
		STATUS_ACTIVATED,
		STATUS_SWITCHED,
		STATUS_BOOTSTRAPPED,
		STATUS_ADOPTED,
		STATUS_BOOTSTRAPPED_AND_SWITCHED,
		STATUS_ADOPTED_AND_SWITCHED,
		STATUS_MUTATED,
		STATUS_RECONCILED,
	]


static func _get_valid_statuses() -> Array[StringName]:
	return _get_success_statuses() + [
		STATUS_INVALID_PROFILE,
		STATUS_INVALID_REQUEST,
		STATUS_INVALID_LEASE,
		STATUS_INACTIVE,
		STATUS_ALREADY_ACTIVE,
		STATUS_BUSY,
		STATUS_UNSUPPORTED_OPERATION,
		STATUS_RECOVERY_REQUIRED,
		STATUS_SOURCE_FLUSH_FAILED,
		STATUS_TARGET_LOAD_FAILED,
		STATUS_SNAPSHOT_FAILED,
		STATUS_APPLY_FAILED,
		STATUS_ROLLBACK_FAILED,
		STATUS_PERSIST_FAILED,
		STATUS_OUTCOME_UNKNOWN,
		STATUS_RECONCILE_PENDING,
		STATUS_RECONCILE_FAILED,
		STATUS_DISPOSED,
	]


static func _get_valid_operations() -> Array[StringName]:
	return [
		GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
		GFSaveProfileTransactionOperation.OPERATION_SWITCH,
		GFSaveProfileTransactionOperation.OPERATION_BOOTSTRAP,
		GFSaveProfileTransactionOperation.OPERATION_ADOPT,
		GFSaveProfileTransactionOperation.OPERATION_BOOTSTRAP_AND_SWITCH,
		GFSaveProfileTransactionOperation.OPERATION_ADOPT_AND_SWITCH,
		GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
		GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
	]


static func _read_rollback_errors(
	value: Variant,
	output: Array[GFSaveRollbackFailure]
) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	for entry: Variant in values:
		if not entry is GFSaveRollbackFailure:
			return false
		var failure: GFSaveRollbackFailure = entry
		output.append(failure)
	return true


static func _read_recovery_lease(options: Dictionary) -> GFSaveProfileRecoveryLease:
	var value: Variant = GFVariantData.get_option_value(options, "recovery_lease")
	if value is GFSaveProfileRecoveryLease:
		var lease: GFSaveProfileRecoveryLease = value
		return lease
	return null


static func _read_reconcile_lease(options: Dictionary) -> GFSaveProfileReconcileLease:
	var value: Variant = GFVariantData.get_option_value(options, "reconcile_lease")
	if value is GFSaveProfileReconcileLease:
		var lease: GFSaveProfileReconcileLease = value
		return lease
	return null


static func _leases_match_status(
	status: StringName,
	operation: StringName,
	transaction_id: int,
	source_profile_id: StringName,
	target_profile_id: StringName,
	recovery_lease: GFSaveProfileRecoveryLease,
	reconcile_lease: GFSaveProfileReconcileLease
) -> bool:
	if status == STATUS_RECOVERY_REQUIRED:
		if (
			recovery_lease == null
			or operation not in [
				GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
				GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			]
		):
			return false
		if (
			recovery_lease.get_transaction_id() != transaction_id
			or recovery_lease.get_source_profile_id() != source_profile_id
			or recovery_lease.get_profile_id() != target_profile_id
			or recovery_lease.get_reason() not in [
				GFSaveProfileRecoveryLease.REASON_MISSING,
				GFSaveProfileRecoveryLease.REASON_CORRUPT,
			]
		):
			return false
	elif recovery_lease != null:
		return false

	if status == STATUS_OUTCOME_UNKNOWN:
		if reconcile_lease == null:
			return false
		if (
			reconcile_lease.get_transaction_id() != transaction_id
			or reconcile_lease.get_operation() != operation
		):
			return false
	elif (
		reconcile_lease != null
		and status not in [
			STATUS_ROLLBACK_FAILED,
			STATUS_RECONCILE_PENDING,
			STATUS_RECONCILE_FAILED,
			STATUS_RECONCILED,
			STATUS_DISPOSED,
		]
	):
		return false
	return true


static func _duplicate_rollback_errors(
	errors: Array[GFSaveRollbackFailure]
) -> Array[GFSaveRollbackFailure]:
	var copies: Array[GFSaveRollbackFailure] = []
	for failure: GFSaveRollbackFailure in errors:
		if failure != null:
			copies.append(failure.duplicate_failure())
	return copies


func _rollback_errors_to_dicts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for failure: GFSaveRollbackFailure in _rollback_errors:
		if failure != null:
			result.append(failure.to_dict())
	return result


func _get_recovery_lease_summary() -> Dictionary:
	if _recovery_lease == null:
		return {}
	return {
		"lease_id": _recovery_lease.get_lease_id(),
		"transaction_id": _recovery_lease.get_transaction_id(),
		"source_profile_id": _recovery_lease.get_source_profile_id(),
		"profile_id": _recovery_lease.get_profile_id(),
		"reason": _recovery_lease.get_reason(),
		"state": _recovery_lease.get_state(),
	}


func _get_reconcile_lease_summary() -> Dictionary:
	if _reconcile_lease == null:
		return {}
	return {
		"lease_id": _reconcile_lease.get_lease_id(),
		"transaction_id": _reconcile_lease.get_transaction_id(),
		"operation": _reconcile_lease.get_operation(),
		"reconcile_profile_id": _reconcile_lease.get_reconcile_profile_id(),
		"state": _reconcile_lease.get_state(),
		"storage_request_ids": _reconcile_lease.get_storage_request_ids(),
	}


static func _is_evidence_supported(evidence: Dictionary) -> bool:
	var state: Dictionary = {
		"items": 0,
		"visited": [],
	}
	return _is_evidence_value_supported(evidence, 0, state)


static func _is_evidence_value_supported(
	value: Variant,
	depth: int,
	state: Dictionary
) -> bool:
	if depth > _MAX_EVIDENCE_DEPTH:
		return false
	var item_count: int = GFVariantData.get_option_int(state, "items") + 1
	state["items"] = item_count
	if item_count > _MAX_EVIDENCE_ITEMS:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			var number: float = value
			return not is_nan(number) and not is_inf(number)
		TYPE_STRING:
			var text: String = value
			return text.length() <= _MAX_EVIDENCE_STRING_LENGTH
		TYPE_STRING_NAME:
			var identifier: StringName = value
			return String(identifier).length() <= _MAX_EVIDENCE_STRING_LENGTH
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return _consume_packed_items(values.size(), state)
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return _consume_packed_items(values.size(), state)
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return _consume_packed_items(values.size(), state)
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			if not _consume_packed_items(values.size(), state):
				return false
			for number: float in values:
				if is_nan(number) or is_inf(number):
					return false
			return true
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			if not _consume_packed_items(values.size(), state):
				return false
			for number: float in values:
				if is_nan(number) or is_inf(number):
					return false
			return true
		TYPE_PACKED_STRING_ARRAY:
			var values: PackedStringArray = value
			if not _consume_packed_items(values.size(), state):
				return false
			for text: String in values:
				if text.length() > _MAX_EVIDENCE_STRING_LENGTH:
					return false
			return true
		TYPE_ARRAY:
			var array_value: Array = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, array_value):
				return false
			visited.append(array_value)
			for entry: Variant in array_value:
				if not _is_evidence_value_supported(entry, depth + 1, state):
					var _removed_array_failure: Variant = visited.pop_back()
					return false
			var _removed_array: Variant = visited.pop_back()
			return true
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, dictionary_value):
				return false
			visited.append(dictionary_value)
			for key: Variant in dictionary_value.keys():
				if (
					typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]
					or not _is_evidence_value_supported(key, depth + 1, state)
				):
					var _removed_invalid_key: Variant = visited.pop_back()
					return false
				if not _is_evidence_value_supported(dictionary_value[key], depth + 1, state):
					var _removed_dictionary_failure: Variant = visited.pop_back()
					return false
			var _removed_dictionary: Variant = visited.pop_back()
			return true
		_:
			return false


static func _consume_packed_items(item_count: int, state: Dictionary) -> bool:
	var next_count: int = GFVariantData.get_option_int(state, "items") + item_count
	state["items"] = next_count
	return next_count <= _MAX_EVIDENCE_ITEMS


static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(state, "visited"))


static func _contains_collection_identity(collections: Array, candidate: Variant) -> bool:
	for collection: Variant in collections:
		if is_same(collection, candidate):
			return true
	return false
