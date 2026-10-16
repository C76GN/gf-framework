## GFSaveProfileReconcileLease: outcome_unknown 的持续所有权与对账围栏。
##
## Lease 保留同一对象身份，直到所有相关底层请求 late-settle 并由显式 reconcile
## 操作解除 domain 围栏。结果副本不会复制 Lease；因此调用方连接 `settled`、
## 轮询状态和提交对账时观察的是同一条生命周期。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFSaveProfileReconcileLease
extends RefCounted


# --- 信号 ---

## Lease 首次离开 waiting 时发出。
##
## 正常 late settlement 进入 ready；Utility 先释放则进入 disposed_unresolved。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param lease: 当前同一身份 Lease。
## [br]
## @param state: `STATE_READY` 或 `STATE_DISPOSED_UNRESOLVED`。
signal settled(lease: GFSaveProfileReconcileLease, state: StringName)


# --- 常量 ---

## 仍在等待至少一个底层请求 late-settle。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_WAITING: StringName = &"waiting"

## 已取得有界 settlement evidence，可以开始显式对账。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_READY: StringName = &"ready"

## 一个 reconcile 操作已经接管 Lease。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_RECONCILING: StringName = &"reconciling"

## 对账已经完成，Provider domain 围栏可以释放。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_RESOLVED: StringName = &"resolved"

## Utility 已释放，但不确定副作用尚未完成对账。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_DISPOSED_UNRESOLVED: StringName = &"disposed_unresolved"

## 复用本扩展的有界 evidence 校验，不共享调用期计数状态。
## [br]
## @api private
## [br]
const _GF_SAVE_PROFILE_EVIDENCE_VALIDATION_SCRIPT = preload("res://addons/gf/extensions/save/profile/gf_save_profile_evidence_validation.gd")


# --- 私有变量 ---

## 标记框架配置是否已经写入该 Lease。
## [br]
## @api private
## [br]
var _configured: bool = false

## 本次对账 Lease 的标识。
## [br]
## @api private
## [br]
var _lease_id: int = 0

## 创建该 Lease 的事务标识。
## [br]
## @api private
## [br]
var _transaction_id: int = 0

## 产生不确定结果的原操作标识。
## [br]
## @api private
## [br]
var _operation: StringName = &""

## 执行对账的 Profile ID。
## [br]
## @api private
## [br]
var _reconcile_profile_id: StringName = &""

## 不确定结果涉及的源 Profile ID。
## [br]
## @api private
## [br]
var _source_profile_id: StringName = &""

## 不确定结果涉及的目标 Profile ID。
## [br]
## @api private
## [br]
var _target_profile_id: StringName = &""

## 创建 Lease 时记录的 Storage domain ID。
## [br]
## @api private
## [br]
var _domain_id: int = 0

## 创建 Lease 时记录的 domain generation。
## [br]
## @api private
## [br]
var _domain_generation: int = 0

## 创建 Lease 时记录的操作 epoch。
## [br]
## @api private
## [br]
var _epoch: int = 0

## 与不确定 Storage 操作关联的请求 ID 列表。
## [br]
## @api private
## [br]
var _storage_request_ids: PackedInt64Array = PackedInt64Array()

## 当前对账 Lease 状态。
## [br]
## @api private
## [br]
var _state: StringName = STATE_DISPOSED_UNRESOLVED

## late settlement 阶段提交的证据字典。
## [br]
## @api private
## [br]
var _settlement_evidence: Dictionary = {}

## 对账完成时提交的 resolution 证据字典。
## [br]
## @api private
## [br]
var _resolution_evidence: Dictionary = {}

## 标记 settled 信号是否已发出。
## [br]
## @api private
## [br]
var _settled_signal_emitted: bool = false


# --- 公共方法 ---

## 获取 Utility 生命周期内唯一的 Lease ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数 Lease ID；未配置时为 0。
func get_lease_id() -> int:
	return _lease_id


## 获取产生当前 Lease 的事务 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数事务 ID；未配置时为 0。
func get_transaction_id() -> int:
	return _transaction_id


## 获取产生 outcome_unknown 的事务类型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `GFSaveProfileTransactionOperation.OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取显式对账应重新读取的 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非空 Profile ID。
func get_reconcile_profile_id() -> StringName:
	return _reconcile_profile_id


## 获取原事务来源 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 来源 Profile ID；不适用时为空。
func get_source_profile_id() -> StringName:
	return _source_profile_id


## 获取原事务目标 Profile ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 目标 Profile ID；不适用时为空。
func get_target_profile_id() -> StringName:
	return _target_profile_id


## 获取运行时 Provider domain ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Utility 生命周期内唯一的正整数 domain ID。
func get_domain_id() -> int:
	return _domain_id


## 获取 Lease 创建时的 domain generation。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数 domain generation。
func get_domain_generation() -> int:
	return _domain_generation


## 获取 Lease 创建时的 Utility lifecycle epoch。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数 lifecycle epoch。
func get_epoch() -> int:
	return _epoch


## 获取支撑 outcome_unknown 的底层 Storage 请求 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 按发起顺序排列的正整数请求 ID。
func get_storage_request_ids() -> PackedInt64Array:
	return _storage_request_ids.duplicate()


## 获取当前 Lease 状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `STATE_*` 常量之一。
func get_state() -> StringName:
	return _state


## 检查 Lease 是否仍等待 late settlement。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return waiting 时返回 true。
func is_waiting() -> bool:
	return _configured and _state == STATE_WAITING


## 检查 Lease 是否可由 reconcile 操作接管。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return ready 时返回 true。
func is_ready() -> bool:
	return _state == STATE_READY


## 检查 Lease 是否已进入不可再对账的终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return resolved 或 disposed_unresolved 时返回 true。
func is_terminal() -> bool:
	return _state in [STATE_RESOLVED, STATE_DISPOSED_UNRESOLVED]


## 获取不含文档或 Provider payload 的 settlement evidence。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 有界 evidence 副本。
## [br]
## @schema return: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
func get_settlement_evidence() -> Dictionary:
	return _settlement_evidence.duplicate(true)


## 获取成功对账后提交的最终证据。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return resolved 前为空；resolved 后返回有界 evidence 副本。
## [br]
## @schema return: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
func get_resolution_evidence() -> Dictionary:
	return _resolution_evidence.duplicate(true)


# --- 框架内部方法 ---

## 由 Save Profile 事务协调器一次性绑定不确定写入身份。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param lease_id: Utility 生命周期内唯一的正整数 Lease ID。
## [br]
## @param transaction_id: 产生该 Lease 的正整数事务 ID。
## [br]
## @param operation: 产生 outcome_unknown 的事务类型。
## [br]
## @param reconcile_profile_id: 对账时必须重新读取的 Profile ID。
## [br]
## @param source_profile_id: 原事务来源 Profile ID；不适用时为空。
## [br]
## @param target_profile_id: 原事务目标 Profile ID；不适用时为空。
## [br]
## @param domain_id: Utility 生命周期内唯一的正整数 Provider domain ID。
## [br]
## @param domain_generation: 创建时的正整数 domain generation。
## [br]
## @param epoch: 创建时的正整数 Utility lifecycle epoch。
## [br]
## @param storage_request_ids: 支撑不确定结果的正整数 Storage 请求 ID；纯内存故障围栏可为空。
## [br]
## @return 输入合法且首次配置时返回 true。
func configure_for_framework(
	lease_id: int,
	transaction_id: int,
	operation: StringName,
	reconcile_profile_id: StringName,
	source_profile_id: StringName,
	target_profile_id: StringName,
	domain_id: int,
	domain_generation: int,
	epoch: int,
	storage_request_ids: PackedInt64Array
) -> bool:
	if _configured:
		return false
	if (
		lease_id <= 0
		or transaction_id <= 0
		or operation == &""
		or operation == GFSaveProfileTransactionOperation.OPERATION_RECONCILE
		or reconcile_profile_id == &""
		or domain_id <= 0
		or domain_generation <= 0
		or epoch <= 0
		or not _has_only_positive_request_ids(storage_request_ids)
	):
		return false
	_configured = true
	_lease_id = lease_id
	_transaction_id = transaction_id
	_operation = operation
	_reconcile_profile_id = reconcile_profile_id
	_source_profile_id = source_profile_id
	_target_profile_id = target_profile_id
	_domain_id = domain_id
	_domain_generation = domain_generation
	_epoch = epoch
	_storage_request_ids = storage_request_ids.duplicate()
	_state = STATE_WAITING
	return true


## 获取不含文档或 Provider payload 的 Lease 快照。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return Lease 身份、围栏、状态与 settlement evidence。
## [br]
## @schema return: Payload-free Dictionary with lease identity, transaction identity, profile ids, domain fence, request ids, state, settlement_evidence, and resolution_evidence.
func inspect_for_framework() -> Dictionary:
	return {
		"lease_id": _lease_id,
		"transaction_id": _transaction_id,
		"operation": _operation,
		"reconcile_profile_id": _reconcile_profile_id,
		"source_profile_id": _source_profile_id,
		"target_profile_id": _target_profile_id,
		"domain_id": _domain_id,
		"domain_generation": _domain_generation,
		"epoch": _epoch,
		"storage_request_ids": _storage_request_ids.duplicate(),
		"state": _state,
		"settlement_evidence": _settlement_evidence.duplicate(true),
		"resolution_evidence": _resolution_evidence.duplicate(true),
	}


## 提交全部 late settlement 的有界证据，并开放显式对账。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param settlement_evidence: 不含文档、section 或 Provider payload 的证据。
## [br]
## @schema settlement_evidence: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
## [br]
## @return 首次从 waiting 转为 ready 时返回 true。
func mark_ready_for_framework(settlement_evidence: Dictionary = {}) -> bool:
	if not is_waiting() or not _is_evidence_supported(settlement_evidence):
		return false
	_settlement_evidence = settlement_evidence.duplicate(true)
	_state = STATE_READY
	_emit_settled_for_framework()
	return true


## 在身份和围栏匹配时接管一次对账尝试。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param expected_reconcile_profile_id: 本次对账重新读取的 Profile ID。
## [br]
## @param expected_domain_id: 当前 Provider domain ID。
## [br]
## @param expected_domain_generation: 当前 domain generation。
## [br]
## @param expected_epoch: 当前 Utility lifecycle epoch。
## [br]
## @return 匹配时返回 payload-free Lease 记录并转为 reconciling；否则为空。
## [br]
## @schema return: Payload-free Dictionary with lease identity, transaction identity, profile ids, domain fence, request ids, and settlement_evidence.
func claim_for_framework(
	expected_reconcile_profile_id: StringName,
	expected_domain_id: int,
	expected_domain_generation: int,
	expected_epoch: int
) -> Dictionary:
	if not is_ready():
		return {}
	if (
		expected_reconcile_profile_id != _reconcile_profile_id
		or expected_domain_id != _domain_id
		or expected_domain_generation != _domain_generation
		or expected_epoch != _epoch
	):
		return {}
	_state = STATE_RECONCILING
	return inspect_for_framework()


## 对账尝试失败后把同一 Lease 恢复为 ready，以允许显式重试。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 首次从 reconciling 恢复为 ready 时返回 true。
func release_reconcile_for_framework() -> bool:
	if _state != STATE_RECONCILING:
		return false
	_state = STATE_READY
	return true


## 提交成功对账的有界证据并结束 Lease。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param resolution_evidence: 不含文档、section 或 Provider payload 的最终证据。
## [br]
## @schema resolution_evidence: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
## [br]
## @return 首次从 reconciling 转为 resolved 时返回 true。
func mark_resolved_for_framework(resolution_evidence: Dictionary = {}) -> bool:
	if _state != STATE_RECONCILING or not _is_evidence_supported(resolution_evidence):
		return false
	_resolution_evidence = resolution_evidence.duplicate(true)
	_state = STATE_RESOLVED
	return true


## 在 Utility 释放时保留未完成对账的可诊断终态。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 首次转为 disposed_unresolved 时返回 true。
func mark_disposed_unresolved_for_framework() -> bool:
	if not _configured or is_terminal():
		return false
	var was_waiting: bool = _state == STATE_WAITING
	_state = STATE_DISPOSED_UNRESOLVED
	if was_waiting:
		_emit_settled_for_framework()
	return true


# --- 私有/辅助方法 ---

## 检查请求 ID 数组中的每个值是否都大于零。
## [br]
## @api private
## [br]
static func _has_only_positive_request_ids(request_ids: PackedInt64Array) -> bool:
	for request_id: int in request_ids:
		if request_id <= 0:
			return false
	return true


## 使用共享校验器检查 evidence，保持本调用独立的预算与递归状态。
## [br]
## @api private
## [br]
static func _is_evidence_supported(evidence: Dictionary) -> bool:
	return _GF_SAVE_PROFILE_EVIDENCE_VALIDATION_SCRIPT.is_supported_for_framework(evidence)


## 首次调用时发出当前 Lease 状态的 settled 信号。
## [br]
## @api private
## [br]
func _emit_settled_for_framework() -> void:
	if _settled_signal_emitted:
		return
	_settled_signal_emitted = true
	settled.emit(self, _state)
