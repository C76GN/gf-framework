## GFObservableArrayResource: 可观察数组资源。
##
## 保存一份 Array 数据，并通过显式方法发出单项变更和批量变更信号。
## 它不是 Array 的替身，不拦截直接字段修改；调用方应通过方法提交变更，
## 以便 UI、编辑器工具、状态同步或诊断面板接收稳定的变更报告。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFObservableArrayResource
extends Resource


# --- 信号 ---

## 单项变更后发出。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param operation: 操作类型。
## [br]
## @param index: 变更索引。
## [br]
## @param old_value: 旧值。
## [br]
## @param new_value: 新值。
## [br]
## @param metadata: 调用方元数据。
## [br]
## @schema old_value: Variant copied from the array before mutation.
## [br]
## @schema new_value: Variant copied into the array after mutation.
## [br]
## @schema metadata: Dictionary copied from the mutation call.
signal item_changed(operation: StringName, index: int, old_value: Variant, new_value: Variant, metadata: Dictionary)

## 一批变更完成后发出。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param changes: 变更报告列表。
## [br]
## @param metadata: 批量元数据。
## [br]
## @schema changes: Array[Dictionary] mutation reports.
## [br]
## @schema metadata: Dictionary copied from begin_batch()/end_batch().
signal items_changed(changes: Array[Dictionary], metadata: Dictionary)


# --- 常量 ---

## 追加元素。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_APPEND: StringName = &"append"

## 设置元素。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_SET: StringName = &"set"

## 移除元素。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_ERASE: StringName = &"erase"

## 清空数组。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_CLEAR: StringName = &"clear"

## 替换全部数组内容。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_REPLACE: StringName = &"replace"


# --- 导出变量 ---

## 当前数组数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema items: Array caller-owned values; mutate through methods to emit reports.
@export var items: Array = []

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary caller-defined resource metadata.
@export var metadata: Dictionary = {}


# --- 私有变量 ---

var _batch_depth: int = 0
var _batch_metadata: Dictionary = {}
var _pending_changes: Array[Dictionary] = []


# --- 公共方法 ---

## 替换全部数组内容。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param values: 新数组数据。
## [br]
## @param emit_change: 是否发出变更信号。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema values: Array copied into items.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, index, old_value, new_value, metadata, and count.
func set_items(values: Array, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:
	var old_items: Array = items.duplicate(true)
	items = values.duplicate(true)
	var change: Dictionary = _make_change(OPERATION_REPLACE, -1, old_items, items, change_metadata)
	change["count"] = items.size()
	if emit_change:
		_record_change(change)
	return change


## 获取数组副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 数组副本。
## [br]
## @schema return: Array duplicated from items.
func get_items() -> Array:
	return items.duplicate(true)


## 追加元素。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param value: 新元素。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema value: Variant copied into the array.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, index, old_value, new_value, and metadata.
func append_item(value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
	var copied_value: Variant = GFVariantData.duplicate_variant(value, true, true)
	items.append(copied_value)
	var change: Dictionary = _make_change(OPERATION_APPEND, items.size() - 1, null, copied_value, change_metadata)
	_record_change(change)
	return change


## 设置指定索引的元素。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param index: 目标索引。
## [br]
## @param value: 新元素。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema value: Variant copied into the array.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, index, old_value, new_value, metadata, and optional error.
func set_item(index: int, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
	if index < 0 or index >= items.size():
		return _make_failure(OPERATION_SET, index, "index is outside the array.")
	var old_value: Variant = GFVariantData.duplicate_variant(items[index], true, true)
	var copied_value: Variant = GFVariantData.duplicate_variant(value, true, true)
	items[index] = copied_value
	var change: Dictionary = _make_change(OPERATION_SET, index, old_value, copied_value, change_metadata)
	_record_change(change)
	return change


## 移除指定索引的元素。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param index: 目标索引。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, index, old_value, new_value, metadata, and optional error.
func erase_item_at(index: int, change_metadata: Dictionary = {}) -> Dictionary:
	if index < 0 or index >= items.size():
		return _make_failure(OPERATION_ERASE, index, "index is outside the array.")
	var old_value: Variant = GFVariantData.duplicate_variant(items[index], true, true)
	items.remove_at(index)
	var change: Dictionary = _make_change(OPERATION_ERASE, index, old_value, null, change_metadata)
	_record_change(change)
	return change


## 清空数组。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, index, old_value, new_value, metadata, and count.
func clear_items(change_metadata: Dictionary = {}) -> Dictionary:
	var old_items: Array = items.duplicate(true)
	items.clear()
	var change: Dictionary = _make_change(OPERATION_CLEAR, -1, old_items, [], change_metadata)
	change["count"] = old_items.size()
	_record_change(change)
	return change


## 开始批量变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param change_metadata: 批量元数据。
## [br]
## @schema change_metadata: Dictionary merged into the batch report.
func begin_batch(change_metadata: Dictionary = {}) -> void:
	if _batch_depth == 0:
		_batch_metadata = change_metadata.duplicate(true)
		_pending_changes.clear()
	else:
		_batch_metadata = GFVariantData.merge_dictionary(_batch_metadata, change_metadata, true)
	_batch_depth += 1


## 结束批量变更。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param change_metadata: 批量元数据。
## [br]
## @schema change_metadata: Dictionary merged into the batch report.
## [br]
## @return 批量报告。
## [br]
## @schema return: Dictionary with ok, change_count, changes, and metadata.
func end_batch(change_metadata: Dictionary = {}) -> Dictionary:
	if _batch_depth <= 0:
		return {
			"ok": false,
			"change_count": 0,
			"changes": [],
			"metadata": change_metadata.duplicate(true),
			"error": "No active batch.",
		}

	_batch_depth -= 1
	_batch_metadata = GFVariantData.merge_dictionary(_batch_metadata, change_metadata, true)
	if _batch_depth > 0:
		return {
			"ok": true,
			"change_count": _pending_changes.size(),
			"changes": _copy_changes(_pending_changes),
			"metadata": _batch_metadata.duplicate(true),
		}

	var changes: Array[Dictionary] = _copy_changes(_pending_changes)
	var batch_metadata: Dictionary = _batch_metadata.duplicate(true)
	_pending_changes.clear()
	_batch_metadata.clear()
	if not changes.is_empty():
		items_changed.emit(changes, batch_metadata)
		emit_changed()
	return {
		"ok": true,
		"change_count": changes.size(),
		"changes": changes,
		"metadata": batch_metadata,
	}


## 获取元素数量。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 元素数量。
func get_count() -> int:
	return items.size()


## 判断数组是否为空。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 为空时返回 true。
func is_empty() -> bool:
	return items.is_empty()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with count, batch_depth, pending_change_count, metadata, and items.
func get_debug_snapshot() -> Dictionary:
	return {
		"count": items.size(),
		"batch_depth": _batch_depth,
		"pending_change_count": _pending_changes.size(),
		"metadata": metadata.duplicate(true),
		"items": items.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _record_change(change: Dictionary) -> void:
	var copied_change: Dictionary = change.duplicate(true)
	if _batch_depth > 0:
		_pending_changes.append(copied_change)
		return
	item_changed.emit(
		GFVariantData.get_option_string_name(copied_change, "operation"),
		GFVariantData.get_option_int(copied_change, "index", -1),
		GFVariantData.get_option_value(copied_change, "old_value"),
		GFVariantData.get_option_value(copied_change, "new_value"),
		GFVariantData.get_option_dictionary(copied_change, "metadata")
	)
	items_changed.emit([copied_change], GFVariantData.get_option_dictionary(copied_change, "metadata"))
	emit_changed()


func _make_change(
	operation: StringName,
	index: int,
	old_value: Variant,
	new_value: Variant,
	change_metadata: Dictionary
) -> Dictionary:
	return {
		"ok": true,
		"operation": operation,
		"index": index,
		"old_value": GFVariantData.duplicate_variant(old_value, true, true),
		"new_value": GFVariantData.duplicate_variant(new_value, true, true),
		"metadata": change_metadata.duplicate(true),
		"error": "",
	}


func _make_failure(operation: StringName, index: int, error: String) -> Dictionary:
	return {
		"ok": false,
		"operation": operation,
		"index": index,
		"old_value": null,
		"new_value": null,
		"metadata": {},
		"error": error,
	}


func _copy_changes(source_changes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for change: Dictionary in source_changes:
		result.append(change.duplicate(true))
	return result
