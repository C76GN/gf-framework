## GFMutationBatch: 通用变更批次。
##
## 把一组 Callable 作为可提交、可回滚的批次执行。它只管理执行顺序、
## 结果归一化和回滚栈，不绑定资源、存档、网络或编辑器事务。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFMutationBatch
extends RefCounted


# --- 信号 ---

## 操作加入批次后发出。
## [br]
## @api public
## [br]
## @param operation_id: 操作标识。
signal operation_added(operation_id: int)

## 单个操作提交成功后发出。
## [br]
## @api public
## [br]
## @param operation_id: 操作标识。
## [br]
## @param result: 操作结果。
## [br]
## @schema result: Dictionary normalized operation result.
signal operation_committed(operation_id: int, result: Dictionary)

## 批次提交结束后发出。
## [br]
## @api public
## [br]
## @param summary: 提交摘要。
## [br]
## @schema summary: Dictionary commit summary.
signal batch_committed(summary: Dictionary)

## 已提交操作回滚结束后发出。
## [br]
## @api public
## [br]
## @param summary: 回滚摘要。
## [br]
## @schema summary: Dictionary rollback summary.
signal batch_rolled_back(summary: Dictionary)

## 批次清空后发出。
## [br]
## @api public
signal cleared


# --- 常量 ---

const _GF_DEQUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_deque.gd")


# --- 公共变量 ---

## 提交遇到失败时是否停止后续操作。
## [br]
## @api public
var stop_on_error: bool = true

## 全部提交成功后是否自动清空 committed 栈。
## [br]
## @api public
var auto_clear_committed_on_success: bool = false


# --- 私有变量 ---

var _pending_operations: GFDeque = _GF_DEQUE_SCRIPT.new()
var _committed_operations: Array[Dictionary] = []
var _next_operation_id: int = 1


# --- 公共方法 ---

## 添加一个批次操作。
## [br]
## @api public
## [br]
## @param operation: 提交回调。
## [br]
## @param rollback: 可选回滚回调。
## [br]
## @param metadata: 操作元数据。
## [br]
## @return 操作标识；失败返回 -1。
## [br]
## @schema metadata: Dictionary copied into the normalized operation result.
func add_operation(operation: Callable, rollback: Callable = Callable(), metadata: Dictionary = {}) -> int:
	if not operation.is_valid():
		return -1

	var operation_id: int = _next_operation_id
	_next_operation_id += 1
	_pending_operations.push_back({
		"operation_id": operation_id,
		"operation": operation,
		"rollback": rollback,
		"metadata": metadata.duplicate(true),
	})
	operation_added.emit(operation_id)
	return operation_id


## 提交待处理操作。
## [br]
## @api public
## [br]
## @param max_operations: 最多提交数量；小于 0 表示处理全部。
## [br]
## @return 提交摘要。
## [br]
## @schema return: Dictionary commit summary.
func commit(max_operations: int = -1) -> Dictionary:
	var committed_count: int = 0
	var failed_count: int = 0
	var errors: Array[Dictionary] = []
	while not _pending_operations.is_empty() and (max_operations < 0 or committed_count + failed_count < max_operations):
		var entry: Dictionary = _get_pending_operation()
		var operation: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "operation", Callable()))
		if not operation.is_valid():
			var invalid_result: Dictionary = _make_invalid_callable_result(entry)
			failed_count += 1
			errors.append(invalid_result)
			if stop_on_error:
				break
			var _removed_invalid_operation: Variant = _pending_operations.pop_front()
			continue
		var operation_result: Dictionary = _normalize_operation_result(operation.call(), entry)
		if GFVariantData.get_option_bool(operation_result, "ok"):
			var _removed_pending_operation: Variant = _pending_operations.pop_front()
			_committed_operations.append(entry)
			committed_count += 1
			operation_committed.emit(GFVariantData.get_option_int(entry, "operation_id", -1), operation_result)
			continue

		failed_count += 1
		errors.append(operation_result)
		if stop_on_error:
			break
		var _removed_failed_operation: Variant = _pending_operations.pop_front()

	var commit_succeeded: bool = failed_count == 0
	if commit_succeeded and auto_clear_committed_on_success:
		_committed_operations.clear()
	var summary: Dictionary = _make_commit_summary(committed_count, failed_count, errors)
	batch_committed.emit(summary)
	return summary


## 回滚已提交操作。
## [br]
## @api public
## [br]
## @param max_operations: 最多回滚数量；小于 0 表示回滚全部。
## [br]
## @return 回滚摘要。
## [br]
## @schema return: Dictionary rollback summary.
func rollback_committed(max_operations: int = -1) -> Dictionary:
	var rolled_back_count: int = 0
	var failed_count: int = 0
	var skipped_count: int = 0
	var errors: Array[Dictionary] = []
	var failed_entries: Array[Dictionary] = []
	while not _committed_operations.is_empty() and (max_operations < 0 or rolled_back_count + failed_count + skipped_count < max_operations):
		var entry: Dictionary = _committed_operations.pop_back()
		var rollback: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "rollback", Callable()))
		if rollback.is_null():
			skipped_count += 1
			continue
		if not rollback.is_valid():
			var invalid_result: Dictionary = _make_invalid_callable_result(entry)
			failed_count += 1
			errors.append(invalid_result)
			failed_entries.append(entry)
			if stop_on_error:
				break
			continue

		var rollback_result: Dictionary = _normalize_operation_result(rollback.call(), entry)
		if GFVariantData.get_option_bool(rollback_result, "ok"):
			rolled_back_count += 1
		else:
			failed_count += 1
			errors.append(rollback_result)
			failed_entries.append(entry)
			if stop_on_error:
				break

	_restore_failed_rollback_entries(failed_entries)
	var summary: Dictionary = {
		"ok": failed_count == 0,
		"rolled_back_count": rolled_back_count,
		"failed_count": failed_count,
		"skipped_count": skipped_count,
		"pending_count": _pending_operations.size(),
		"committed_count": _committed_operations.size(),
		"errors": errors,
	}
	batch_rolled_back.emit(summary)
	return summary


## 清空批次。
## [br]
## @api public
func clear() -> void:
	_pending_operations.clear()
	_committed_operations.clear()
	cleared.emit()


## 获取待处理操作数量。
## [br]
## @api public
## [br]
## @return 待处理操作数量。
func get_pending_count() -> int:
	return _pending_operations.size()


## 获取已提交操作数量。
## [br]
## @api public
## [br]
## @return 已提交操作数量。
func get_committed_count() -> int:
	return _committed_operations.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary with pending_count, committed_count, next_operation_id, and options.
func get_debug_snapshot() -> Dictionary:
	return {
		"pending_count": _pending_operations.size(),
		"committed_count": _committed_operations.size(),
		"next_operation_id": _next_operation_id,
		"stop_on_error": stop_on_error,
		"auto_clear_committed_on_success": auto_clear_committed_on_success,
	}


# --- 私有/辅助方法 ---

func _normalize_operation_result(raw_result: Variant, entry: Dictionary) -> Dictionary:
	var metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
	if raw_result is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(raw_result)
		if data.has("ok"):
			var result_value: Variant = GFVariantData.get_option_value(data, "value", GFVariantData.get_option_value(data, "data"))
			return {
				"ok": GFVariantData.get_option_bool(data, "ok"),
				"operation_id": GFVariantData.get_option_int(entry, "operation_id", -1),
				"value": result_value,
				"error": GFVariantData.get_option_string(data, "error"),
				"metadata": metadata,
			}
	return {
		"ok": true,
		"operation_id": GFVariantData.get_option_int(entry, "operation_id", -1),
		"value": raw_result,
		"error": "",
		"metadata": metadata,
	}


func _make_commit_summary(committed_count: int, failed_count: int, errors: Array[Dictionary]) -> Dictionary:
	return {
		"ok": failed_count == 0,
		"committed_count": committed_count,
		"failed_count": failed_count,
		"pending_count": _pending_operations.size(),
		"stored_committed_count": _committed_operations.size(),
		"errors": errors,
	}


func _make_invalid_callable_result(entry: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"operation_id": GFVariantData.get_option_int(entry, "operation_id", -1),
		"value": null,
		"error": "invalid_callable",
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}


func _get_pending_operation() -> Dictionary:
	var raw_entry: Variant = _pending_operations.peek_front({})
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		return entry
	return {}


func _restore_failed_rollback_entries(failed_entries: Array[Dictionary]) -> void:
	for index: int in range(failed_entries.size() - 1, -1, -1):
		_committed_operations.append(failed_entries[index])


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()
