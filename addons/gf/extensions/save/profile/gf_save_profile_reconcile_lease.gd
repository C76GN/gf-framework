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
## @since unreleased
class_name GFSaveProfileReconcileLease
extends RefCounted


# --- 信号 ---

## Lease 首次离开 waiting 时发出。
##
## 正常 late settlement 进入 ready；Utility 先释放则进入 disposed_unresolved。
## [br]
## @api public
## [br]
## @since unreleased
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
## @since unreleased
const STATE_WAITING: StringName = &"waiting"

## 已取得有界 settlement evidence，可以开始显式对账。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_READY: StringName = &"ready"

## 一个 reconcile 操作已经接管 Lease。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_RECONCILING: StringName = &"reconciling"

## 对账已经完成，Provider domain 围栏可以释放。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_RESOLVED: StringName = &"resolved"

## Utility 已释放，但不确定副作用尚未完成对账。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_DISPOSED_UNRESOLVED: StringName = &"disposed_unresolved"

const _MAX_EVIDENCE_DEPTH: int = 16
const _MAX_EVIDENCE_ITEMS: int = 2048
const _MAX_EVIDENCE_STRING_LENGTH: int = 2048


# --- 私有变量 ---

var _configured: bool = false
var _lease_id: int = 0
var _transaction_id: int = 0
var _operation: StringName = &""
var _reconcile_profile_id: StringName = &""
var _source_profile_id: StringName = &""
var _target_profile_id: StringName = &""
var _domain_id: int = 0
var _domain_generation: int = 0
var _epoch: int = 0
var _storage_request_ids: PackedInt64Array = PackedInt64Array()
var _state: StringName = STATE_DISPOSED_UNRESOLVED
var _settlement_evidence: Dictionary = {}
var _resolution_evidence: Dictionary = {}
var _settled_signal_emitted: bool = false


# --- 公共方法 ---

## 获取 Utility 生命周期内唯一的 Lease ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 Lease ID；未配置时为 0。
func get_lease_id() -> int:
	return _lease_id


## 获取产生当前 Lease 的事务 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数事务 ID；未配置时为 0。
func get_transaction_id() -> int:
	return _transaction_id


## 获取产生 outcome_unknown 的事务类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `GFSaveProfileTransactionOperation.OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取显式对账应重新读取的 Profile ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非空 Profile ID。
func get_reconcile_profile_id() -> StringName:
	return _reconcile_profile_id


## 获取原事务来源 Profile ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 来源 Profile ID；不适用时为空。
func get_source_profile_id() -> StringName:
	return _source_profile_id


## 获取原事务目标 Profile ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 目标 Profile ID；不适用时为空。
func get_target_profile_id() -> StringName:
	return _target_profile_id


## 获取运行时 Provider domain ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Utility 生命周期内唯一的正整数 domain ID。
func get_domain_id() -> int:
	return _domain_id


## 获取 Lease 创建时的 domain generation。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 domain generation。
func get_domain_generation() -> int:
	return _domain_generation


## 获取 Lease 创建时的 Utility lifecycle epoch。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 lifecycle epoch。
func get_epoch() -> int:
	return _epoch


## 获取支撑 outcome_unknown 的底层 Storage 请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 按发起顺序排列的正整数请求 ID。
func get_storage_request_ids() -> PackedInt64Array:
	return _storage_request_ids.duplicate()


## 获取当前 Lease 状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATE_*` 常量之一。
func get_state() -> StringName:
	return _state


## 检查 Lease 是否仍等待 late settlement。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return waiting 时返回 true。
func is_waiting() -> bool:
	return _configured and _state == STATE_WAITING


## 检查 Lease 是否可由 reconcile 操作接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return ready 时返回 true。
func is_ready() -> bool:
	return _state == STATE_READY


## 检查 Lease 是否已进入不可再对账的终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return resolved 或 disposed_unresolved 时返回 true。
func is_terminal() -> bool:
	return _state in [STATE_RESOLVED, STATE_DISPOSED_UNRESOLVED]


## 获取不含文档或 Provider payload 的 settlement evidence。
## [br]
## @api public
## [br]
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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
## @since unreleased
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

static func _has_only_positive_request_ids(request_ids: PackedInt64Array) -> bool:
	for request_id: int in request_ids:
		if request_id <= 0:
			return false
	return true


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


func _emit_settled_for_framework() -> void:
	if _settled_signal_emitted:
		return
	_settled_signal_emitted = true
	settled.emit(self, _state)
