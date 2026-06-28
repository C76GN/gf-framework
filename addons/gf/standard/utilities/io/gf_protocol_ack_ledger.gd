## GFProtocolAckLedger: 通用协议确认账本。
##
## 记录任意协议的待确认 packet/request ID、确认结果、失败和过期状态。
## 它不实现具体网络协议，也不规定 ID 生成、重传策略或连接生命周期。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFProtocolAckLedger
extends RefCounted


# --- 常量 ---

## 条目等待确认。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_PENDING: StringName = &"pending"

## 条目已经确认。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_ACKED: StringName = &"acked"

## 条目失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_FAILED: StringName = &"failed"

## 条目等待超时。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_EXPIRED: StringName = &"expired"


# --- 公共变量 ---

## 新条目的默认等待超时；小于等于 0 时不自动过期。
## [br]
## @api public
## [br]
## @since 7.0.0
var timeout_msec: int = 0:
	set(value):
		timeout_msec = maxi(value, 0)

## 最大记录数量；小于等于 0 时不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_entries: int = 256

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary[String, Variant] copied into debug snapshots.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _records: Dictionary = {}
var _order: Array = []


# --- 公共方法 ---

## 清空全部记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_records.clear()
	_order.clear()


## 注册一个待确认条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @param now_msec: 当前时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema packet_id: Variant used as dictionary key; null and empty text keys are rejected.
## [br]
## @schema entry_metadata: Dictionary copied into the ledger entry.
func register_packet(packet_id: Variant, entry_metadata: Dictionary = {}, now_msec: int = -1) -> bool:
	if not _is_valid_packet_id(packet_id):
		return false
	if _records.has(packet_id):
		return false

	_prune_for_capacity()
	var timestamp_msec: int = _normalize_time_msec(now_msec)
	var deadline_msec: int = timestamp_msec + timeout_msec if timeout_msec > 0 else -1
	_records[packet_id] = {
		"id": GFVariantData.duplicate_variant(packet_id),
		"state": STATE_PENDING,
		"created_msec": timestamp_msec,
		"updated_msec": timestamp_msec,
		"deadline_msec": deadline_msec,
		"result": null,
		"error": "",
		"metadata": entry_metadata.duplicate(true),
	}
	_order.append(GFVariantData.duplicate_variant(packet_id))
	return true


## 标记条目确认成功。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @param result: 确认结果。
## [br]
## @param now_msec: 当前时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 状态成功变更时返回 true。
## [br]
## @schema result: Variant copied into the ledger entry.
func acknowledge_packet(packet_id: Variant, result: Variant = null, now_msec: int = -1) -> bool:
	return _mark_terminal(packet_id, STATE_ACKED, result, "", now_msec)


## 标记条目失败。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @param error: 失败说明。
## [br]
## @param result: 失败结果。
## [br]
## @param now_msec: 当前时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 状态成功变更时返回 true。
## [br]
## @schema result: Variant copied into the ledger entry.
func fail_packet(packet_id: Variant, error: String = "", result: Variant = null, now_msec: int = -1) -> bool:
	return _mark_terminal(packet_id, STATE_FAILED, result, error, now_msec)


## 让超过 deadline 的待确认条目进入 expired 状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param now_msec: 当前时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 过期报告。
## [br]
## @schema return: Dictionary with expired_count, expired_ids, pending_count, and state_counts.
func expire_pending(now_msec: int = -1) -> Dictionary:
	var timestamp_msec: int = _normalize_time_msec(now_msec)
	var expired_ids: Array = []
	for packet_id: Variant in _records.keys():
		var record: Dictionary = _get_record(packet_id)
		if _get_record_state(record) != STATE_PENDING:
			continue
		var deadline_msec: int = GFVariantData.get_option_int(record, "deadline_msec", -1)
		if deadline_msec < 0 or timestamp_msec < deadline_msec:
			continue
		record["state"] = STATE_EXPIRED
		record["updated_msec"] = timestamp_msec
		record["error"] = "timeout"
		_records[packet_id] = record
		expired_ids.append(GFVariantData.duplicate_variant(packet_id))
	return {
		"expired_count": expired_ids.size(),
		"expired_ids": expired_ids,
		"pending_count": get_pending_count(),
		"state_counts": _get_state_counts(),
	}


## 移除指定条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @return 移除成功返回 true。
func remove_packet(packet_id: Variant) -> bool:
	if not _records.has(packet_id):
		return false
	var removed: bool = _records.erase(packet_id)
	_remove_from_order(packet_id)
	return removed


## 检查条目是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @return 存在返回 true。
func has_packet(packet_id: Variant) -> bool:
	return _records.has(packet_id)


## 检查条目是否仍待确认。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @return 待确认返回 true。
func is_pending(packet_id: Variant) -> bool:
	if not _records.has(packet_id):
		return false
	return _get_record_state(_get_record(packet_id)) == STATE_PENDING


## 获取条目副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param packet_id: 协议层稳定 ID。
## [br]
## @schema packet_id: Variant stable protocol packet id.
## [br]
## @return 条目副本；不存在时返回空字典。
## [br]
## @schema return: Dictionary with id, state, timestamps, deadline_msec, result, error, and metadata.
func get_packet(packet_id: Variant) -> Dictionary:
	if not _records.has(packet_id):
		return {}
	return _get_record(packet_id).duplicate(true)


## 按状态获取条目副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param state_filter: 状态过滤；为空时返回所有条目。
## [br]
## @return 条目数组。
## [br]
## @schema return: Array[Dictionary] of ledger entry copies.
func get_packets(state_filter: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for packet_id: Variant in _order:
		if not _records.has(packet_id):
			continue
		var record: Dictionary = _get_record(packet_id)
		if state_filter != &"" and _get_record_state(record) != state_filter:
			continue
		result.append(record.duplicate(true))
	return result


## 获取待确认 ID 列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 待确认 ID 数组。
## [br]
## @schema return: Array[Variant] copied from pending ledger entries.
func get_pending_ids() -> Array:
	var result: Array = []
	for packet_id: Variant in _order:
		if is_pending(packet_id):
			result.append(GFVariantData.duplicate_variant(packet_id))
	return result


## 获取总记录数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 总记录数。
func get_count() -> int:
	return _records.size()


## 获取待确认记录数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 待确认记录数。
func get_pending_count() -> int:
	return _count_state(STATE_PENDING)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with count, pending_count, state_counts, ids, timeout_msec, max_entries, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"count": get_count(),
		"pending_count": get_pending_count(),
		"state_counts": _get_state_counts(),
		"ids": _order.duplicate(true),
		"timeout_msec": timeout_msec,
		"max_entries": max_entries,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _mark_terminal(
	packet_id: Variant,
	state: StringName,
	result: Variant,
	error: String,
	now_msec: int
) -> bool:
	if not _records.has(packet_id):
		return false
	var record: Dictionary = _get_record(packet_id)
	if _get_record_state(record) != STATE_PENDING:
		return false
	record["state"] = state
	record["updated_msec"] = _normalize_time_msec(now_msec)
	record["result"] = GFVariantData.duplicate_variant(result)
	record["error"] = error
	_records[packet_id] = record
	return true


func _prune_for_capacity() -> void:
	if max_entries <= 0:
		return
	while _records.size() >= max_entries and not _order.is_empty():
		var remove_index: int = _find_first_terminal_order_index()
		if remove_index < 0:
			remove_index = 0
		var packet_id: Variant = _order[remove_index]
		_order.remove_at(remove_index)
		var _removed: bool = _records.erase(packet_id)


func _find_first_terminal_order_index() -> int:
	for index: int in range(_order.size()):
		var packet_id: Variant = _order[index]
		if not _records.has(packet_id):
			return index
		if _get_record_state(_get_record(packet_id)) != STATE_PENDING:
			return index
	return -1


func _remove_from_order(packet_id: Variant) -> void:
	for index: int in range(_order.size() - 1, -1, -1):
		if GFVariantData.values_equal(_order[index], packet_id):
			_order.remove_at(index)


func _get_record(packet_id: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_records, packet_id, {}))


func _get_record_state(record: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(record, "state", STATE_PENDING)


func _count_state(state: StringName) -> int:
	var count: int = 0
	for record_variant: Variant in _records.values():
		var record: Dictionary = GFVariantData.as_dictionary(record_variant)
		if _get_record_state(record) == state:
			count += 1
	return count


func _get_state_counts() -> Dictionary:
	var counts: Dictionary = {}
	counts[STATE_PENDING] = _count_state(STATE_PENDING)
	counts[STATE_ACKED] = _count_state(STATE_ACKED)
	counts[STATE_FAILED] = _count_state(STATE_FAILED)
	counts[STATE_EXPIRED] = _count_state(STATE_EXPIRED)
	return counts


func _normalize_time_msec(now_msec: int) -> int:
	if now_msec >= 0:
		return now_msec
	return Time.get_ticks_msec()


func _is_valid_packet_id(packet_id: Variant) -> bool:
	if packet_id == null:
		return false
	if packet_id is String or packet_id is StringName:
		return not GFVariantData.to_text(packet_id).strip_edges().is_empty()
	return true
