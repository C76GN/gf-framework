## GFObservableDictionaryResource: 可观察字典资源。
##
## 保存一份 Dictionary 数据，并通过显式方法发出键值变更和批量变更信号。
## 它不尝试模拟 Dictionary 的全部接口，避免把业务状态模型写死到框架层。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFObservableDictionaryResource
extends Resource


# --- 信号 ---

## 非 batch 模式下单个键值变更后发出。batch 内变更只在 end_batch() 时汇总到 entries_changed。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param operation: 操作类型。
## [br]
## @param entry_key: 变更键。
## [br]
## @param old_value: 旧值。
## [br]
## @param new_value: 新值。
## [br]
## @param metadata: 调用方元数据。
## [br]
## @schema entry_key: Variant dictionary key.
## [br]
## @schema old_value: Variant copied from the dictionary before mutation.
## [br]
## @schema new_value: Variant copied into the dictionary after mutation.
## [br]
## @schema metadata: Dictionary copied from the mutation call.
signal entry_changed(operation: StringName, entry_key: Variant, old_value: Variant, new_value: Variant, metadata: Dictionary)

## 一批键值变更完成后发出；非 batch 单项变更也会作为单元素 changes 发出。
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
signal entries_changed(changes: Array[Dictionary], metadata: Dictionary)


# --- 常量 ---

## 设置键值。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_SET: StringName = &"set"

## 移除键值。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_ERASE: StringName = &"erase"

## 清空字典。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_CLEAR: StringName = &"clear"

## 替换全部字典内容。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_REPLACE: StringName = &"replace"


# --- 导出变量 ---

## 当前字典数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema entries: Dictionary caller-owned values; mutate through methods to emit reports.
@export var entries: Dictionary = {}

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary caller-defined resource metadata.
@export var metadata: Dictionary = {}


# --- 私有变量 ---

## 当前嵌套批量变更的深度。
## [br]
## @api private
var _batch_depth: int = 0

## 当前批次累计的元数据。
## [br]
## @api private
var _batch_metadata: Dictionary = {}

## 批次结束时待发布的键值变更报告。
## [br]
## @api private
var _pending_changes: Array[Dictionary] = []

## 等待按序派发的变更通知项。
## [br]
## @api private
var _change_emission_queue: Array[Dictionary] = []

## 指示变更通知队列当前是否正在派发。
## [br]
## @api private
var _is_emitting_changes: bool = false


# --- 公共方法 ---

## 替换全部字典内容。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param values: 新字典数据。
## [br]
## @param emit_change: 是否发出变更信号。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema values: Dictionary copied into entries.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and count.
func set_entries(values: Dictionary, emit_change: bool = true, change_metadata: Dictionary = {}) -> Dictionary:
	var old_entries: Dictionary = entries.duplicate(true)
	entries = values.duplicate(true)
	var change: Dictionary = _make_change(OPERATION_REPLACE, null, old_entries, entries, change_metadata)
	change["count"] = entries.size()
	if emit_change:
		_record_change(change)
	return change


## 获取字典副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 字典副本。
## [br]
## @schema return: Dictionary duplicated from entries.
func get_entries() -> Dictionary:
	return entries.duplicate(true)


## 设置键值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_key: 目标键。
## [br]
## @param value: 新值。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema entry_key: Variant dictionary key.
## [br]
## @schema value: Variant copied into the dictionary.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and existed.
func set_value(entry_key: Variant, value: Variant, change_metadata: Dictionary = {}) -> Dictionary:
	var existed: bool = entries.has(entry_key)
	var old_value: Variant = GFVariantData.duplicate_variant(entries[entry_key], true, true) if existed else null
	var copied_value: Variant = GFVariantData.duplicate_variant(value, true, true)
	entries[entry_key] = copied_value
	var change: Dictionary = _make_change(OPERATION_SET, entry_key, old_value, copied_value, change_metadata)
	change["existed"] = existed
	_record_change(change)
	return change


## 移除键值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_key: 目标键。
## [br]
## @param change_metadata: 调用方元数据。
## [br]
## @schema entry_key: Variant dictionary key.
## [br]
## @schema change_metadata: Dictionary copied into the change report.
## [br]
## @return 变更报告。
## [br]
## @schema return: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and optional error.
func erase_value(entry_key: Variant, change_metadata: Dictionary = {}) -> Dictionary:
	if not entries.has(entry_key):
		return _make_failure(OPERATION_ERASE, entry_key, "entry_key does not exist.")
	var old_value: Variant = GFVariantData.duplicate_variant(entries[entry_key], true, true)
	var _erased: bool = entries.erase(entry_key)
	var change: Dictionary = _make_change(OPERATION_ERASE, entry_key, old_value, null, change_metadata)
	_record_change(change)
	return change


## 清空字典。
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
## @schema return: Dictionary with ok, operation, entry_key, old_value, new_value, metadata, and count.
func clear_entries(change_metadata: Dictionary = {}) -> Dictionary:
	var old_entries: Dictionary = entries.duplicate(true)
	entries.clear()
	var change: Dictionary = _make_change(OPERATION_CLEAR, null, old_entries, {}, change_metadata)
	change["count"] = old_entries.size()
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
		_enqueue_change_emission(changes, batch_metadata, false)
	return {
		"ok": true,
		"change_count": changes.size(),
		"changes": changes,
		"metadata": batch_metadata,
	}


## 检查键是否存在。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_key: 目标键。
## [br]
## @schema entry_key: Variant dictionary key.
## [br]
## @return 存在时返回 true。
func has_key(entry_key: Variant) -> bool:
	return entries.has(entry_key)


## 获取键值副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param entry_key: 目标键。
## [br]
## @param default_value: 缺失时的默认值。
## [br]
## @schema entry_key: Variant dictionary key.
## [br]
## @schema default_value: Variant fallback returned when the key is absent.
## [br]
## @return 键值副本或默认值。
## [br]
## @schema return: Variant copied from entries or default_value.
func get_value(entry_key: Variant, default_value: Variant = null) -> Variant:
	if not entries.has(entry_key):
		return GFVariantData.duplicate_variant(default_value, true, true)
	return GFVariantData.duplicate_variant(entries[entry_key], true, true)


## 获取键值数量。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 键值数量。
func get_count() -> int:
	return entries.size()


## 判断字典是否为空。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 为空时返回 true。
func is_empty() -> bool:
	return entries.is_empty()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with count, batch_depth, pending_change_count, metadata, and entries.
func get_debug_snapshot() -> Dictionary:
	return {
		"count": entries.size(),
		"batch_depth": _batch_depth,
		"pending_change_count": _pending_changes.size(),
		"metadata": metadata.duplicate(true),
		"entries": entries.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 复制变更报告；批次内暂存，非批次内交给通知队列派发。
## [br]
## @api private
func _record_change(change: Dictionary) -> void:
	var copied_change: Dictionary = change.duplicate(true)
	if _batch_depth > 0:
		_pending_changes.append(copied_change)
		return
	var changes: Array[Dictionary] = [copied_change]
	_enqueue_change_emission(
		changes,
		GFVariantData.get_option_dictionary(copied_change, "metadata"),
		true
	)


## 将变更列表和元数据封装成队列项，并启动通知队列处理。
## [br]
## @api private
func _enqueue_change_emission(
	changes: Array[Dictionary],
	change_metadata: Dictionary,
	emit_entry_detail: bool
) -> void:
	_change_emission_queue.append({
		"changes": _copy_changes(changes),
		"metadata": change_metadata.duplicate(true),
		"emit_entry_detail": emit_entry_detail,
	})
	_drain_change_emission_queue()


## 按 FIFO 依次发送单键详情、批量详情和 Resource.changed；回调追加的新变更在当前项通知结束后处理。
## 发射标记阻止嵌套 drain，不阻止监听器通过公开入口继续修改字典。
## [br]
## @api private
func _drain_change_emission_queue() -> void:
	if _is_emitting_changes:
		return
	_is_emitting_changes = true
	while not _change_emission_queue.is_empty():
		var emission: Dictionary = _change_emission_queue.pop_front()
		var changes: Array[Dictionary] = _get_emission_changes(emission)
		var change_metadata: Dictionary = GFVariantData.get_option_dictionary(emission, "metadata")
		if GFVariantData.get_option_bool(emission, "emit_entry_detail") and not changes.is_empty():
			var change: Dictionary = changes[0]
			entry_changed.emit(
				GFVariantData.get_option_string_name(change, "operation"),
				GFVariantData.get_option_value(change, "entry_key"),
				GFVariantData.get_option_value(change, "old_value"),
				GFVariantData.get_option_value(change, "new_value"),
				GFVariantData.get_option_dictionary(change, "metadata")
			)
		entries_changed.emit(changes, change_metadata)
		emit_changed()
	_is_emitting_changes = false


## 从通知项中筛出 Dictionary 类型的变更报告。
## [br]
## @api private
func _get_emission_changes(emission: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for change_value: Variant in GFVariantData.get_option_array(emission, "changes"):
		if change_value is Dictionary:
			var change: Dictionary = change_value
			result.append(change)
	return result


## 创建成功的键值变更报告，并通过 Variant 辅助函数处理键、旧值和新值。
## [br]
## @api private
func _make_change(
	operation: StringName,
	entry_key: Variant,
	old_value: Variant,
	new_value: Variant,
	change_metadata: Dictionary
) -> Dictionary:
	return {
		"ok": true,
		"operation": operation,
		"entry_key": GFVariantData.duplicate_variant(entry_key, true, false),
		"old_value": GFVariantData.duplicate_variant(old_value, true, true),
		"new_value": GFVariantData.duplicate_variant(new_value, true, true),
		"metadata": change_metadata.duplicate(true),
		"error": "",
	}


## 创建键值操作失败报告；旧值、新值为空且元数据为空字典。
## [br]
## @api private
func _make_failure(operation: StringName, entry_key: Variant, error: String) -> Dictionary:
	return {
		"ok": false,
		"operation": operation,
		"entry_key": GFVariantData.duplicate_variant(entry_key, true, false),
		"old_value": null,
		"new_value": null,
		"metadata": {},
		"error": error,
	}


## 复制变更报告数组中的每个 Dictionary。
## [br]
## @api private
func _copy_changes(source_changes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for change: Dictionary in source_changes:
		result.append(change.duplicate(true))
	return result
