## GFSnapshotHistoryUtility: 通用快照历史与回滚工具。
##
## 管理一组有序快照，支持捕获、前后跳转、按 ID 恢复和调试快照。
## 默认会使用注入架构的 `get_global_snapshot()` / `restore_global_snapshot()`，
## 也可以通过回调接入任意项目自定义状态。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSnapshotHistoryUtility
extends GFUtility


# --- 信号 ---

## 捕获或推入快照后发出。
## [br]
## @api public
## [br]
## @param snapshot_id: 快照 ID。
## [br]
## @param metadata: 快照元数据副本。
## [br]
## @schema metadata: Dictionary[String, Variant] snapshot metadata copied from capture() or push_snapshot().
signal snapshot_recorded(snapshot_id: int, metadata: Dictionary)

## 恢复快照后发出。
## [br]
## @api public
## [br]
## @param snapshot_id: 快照 ID。
## [br]
## @param index: 恢复后的当前位置。
signal snapshot_restored(snapshot_id: int, index: int)

## 历史内容或当前位置变化后发出。
## [br]
## @api public
## [br]
## @param snapshot: 调试快照。
## [br]
## @schema snapshot: Dictionary produced by get_debug_snapshot().
signal history_changed(snapshot: Dictionary)


# --- 公共变量 ---

## 最多保留的快照数量；为 0 时不限制。
## [br]
## @api public
var max_history_size: int:
	get:
		return _max_history_size
	set(value):
		_max_history_size = maxi(value, 0)
		if _trim_history():
			_emit_history_changed()

## 当前快照索引；没有快照时为 -1。
## [br]
## @api public
var current_index: int:
	get:
		return _current_index

## 当前快照数量。
## [br]
## @api public
var snapshot_count: int:
	get:
		return _snapshots.size()


# --- 私有变量 ---

var _max_history_size: int = 64
var _snapshots: Array[Dictionary] = []
var _current_index: int = -1
var _next_snapshot_id: int = 1
var _capture_callback: Callable = Callable()
var _restore_callback: Callable = Callable()
var _restore_command_builder: Callable = Callable()


# --- GF 生命周期方法 ---

## 释放快照历史并清理捕获、恢复回调。
## [br]
## @api public
func dispose() -> void:
	clear()
	_capture_callback = Callable()
	_restore_callback = Callable()
	_restore_command_builder = Callable()


# --- 公共方法 ---

## 配置快照捕获与恢复回调。
## [br]
## @api public
## [br]
## @param capture_callback: 可选捕获回调，签名为 func() -> Variant。
## [br]
## @param restore_callback: 可选恢复回调，签名为 func(data: Variant) -> void。
## [br]
## @param options: 可选设置，支持 max_history_size、restore_command_builder。
## [br]
## @schema options: Dictionary with max_history_size: int and restore_command_builder: Callable.
func configure(
	capture_callback: Callable = Callable(),
	restore_callback: Callable = Callable(),
	options: Dictionary = {}
) -> void:
	_capture_callback = capture_callback
	_restore_callback = restore_callback
	_restore_command_builder = _get_callable_option(options, "restore_command_builder")
	if options.has("max_history_size"):
		max_history_size = GFVariantData.to_int(options["max_history_size"])


## 捕获当前状态并写入历史。
## [br]
## @api public
## [br]
## @param metadata: 快照元数据。
## [br]
## @schema metadata: Dictionary[String, Variant] copied into the snapshot record.
## [br]
## @return 快照 ID；捕获失败时返回 0。
func capture(metadata: Dictionary = {}) -> int:
	var data: Variant = _capture_data()
	if data == null:
		return 0
	return push_snapshot(data, metadata)


## 推入一份外部快照数据。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param data: 快照数据。
## [br]
## @schema data: Pure Variant snapshot payload; Object and Resource references are rejected.
## [br]
## @param metadata: 快照元数据。
## [br]
## @schema metadata: Dictionary[String, Variant] copied into the snapshot record.
## [br]
## @return 快照 ID。
func push_snapshot(data: Variant, metadata: Dictionary = {}) -> int:
	if not _is_snapshot_payload_allowed(data, 0):
		push_error("[GFSnapshotHistoryUtility] push_snapshot 失败：快照数据不能包含 Object 或 Resource 引用。")
		return 0
	if not _is_snapshot_payload_allowed(metadata, 0):
		push_error("[GFSnapshotHistoryUtility] push_snapshot 失败：快照元数据不能包含 Object 或 Resource 引用。")
		return 0

	if _current_index < _snapshots.size() - 1:
		_snapshots = _snapshots.slice(0, _current_index + 1)

	var snapshot_id: int = _next_snapshot_id
	_next_snapshot_id += 1
	var record: Dictionary = _make_record(snapshot_id, data, metadata)
	_snapshots.append(record)
	_current_index = _snapshots.size() - 1
	var _trim_history_result_162: Variant = _trim_history()
	snapshot_recorded.emit(snapshot_id, GFVariantData.as_dictionary(record["metadata"]).duplicate(true))
	_emit_history_changed()
	return snapshot_id


## 按相对偏移恢复快照。
## [br]
## @api public
## [br]
## @param offset: 相对当前位置的偏移，负数向旧快照移动，正数向新快照移动。
## [br]
## @return 成功恢复时返回 true。
func step(offset: int) -> bool:
	if offset == 0:
		return false
	return restore_index(_current_index + offset)


## 恢复到上一份快照。
## [br]
## @api public
## [br]
## @return 成功恢复时返回 true。
func step_back() -> bool:
	return step(-1)


## 恢复到下一份快照。
## [br]
## @api public
## [br]
## @return 成功恢复时返回 true。
func step_forward() -> bool:
	return step(1)


## 按索引恢复快照。
## [br]
## @api public
## [br]
## @param index: 快照索引。
## [br]
## @return 成功恢复时返回 true。
func restore_index(index: int) -> bool:
	if index < 0 or index >= _snapshots.size():
		return false

	var record: Dictionary = _snapshots[index]
	if not _restore_data(_get_record_data(record)):
		return false

	_current_index = index
	snapshot_restored.emit(_get_record_id(record), _current_index)
	_emit_history_changed()
	return true


## 按快照 ID 恢复快照。
## [br]
## @api public
## [br]
## @param snapshot_id: 快照 ID。
## [br]
## @return 成功恢复时返回 true。
func restore_snapshot_id(snapshot_id: int) -> bool:
	var index: int = _find_snapshot_index(snapshot_id)
	if index < 0:
		return false
	return restore_index(index)


## 是否可以恢复到上一份快照。
## [br]
## @api public
## [br]
## @return 可以后退时返回 true。
func can_step_back() -> bool:
	return _current_index > 0


## 是否可以恢复到下一份快照。
## [br]
## @api public
## [br]
## @return 可以前进时返回 true。
func can_step_forward() -> bool:
	return _current_index >= 0 and _current_index < _snapshots.size() - 1


## 获取当前快照副本。
## [br]
## @api public
## [br]
## @return 当前快照记录；没有快照时返回空字典。
## [br]
## @schema return: Dictionary with id, created_at_unix, metadata, and data.
func get_current_snapshot() -> Dictionary:
	if _current_index < 0 or _current_index >= _snapshots.size():
		return {}
	return _duplicate_record(_snapshots[_current_index])


## 获取全部历史副本。
## [br]
## @api public
## [br]
## @return 快照记录数组。
## [br]
## @schema return: Array[Dictionary] of snapshot records with id, created_at_unix, metadata, and data.
func get_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _snapshots:
		result.append(_duplicate_record(record))
	return result


## 清空历史。
## [br]
## @api public
func clear() -> void:
	_snapshots.clear()
	_current_index = -1
	_emit_history_changed()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 工具状态字典。
## [br]
## @schema return: Dictionary with snapshot_count, current_index, current_snapshot_id, max_history_size, can_step_back, can_step_forward, and ids.
func get_debug_snapshot() -> Dictionary:
	return {
		"snapshot_count": _snapshots.size(),
		"current_index": _current_index,
		"current_snapshot_id": _get_current_snapshot_id(),
		"max_history_size": max_history_size,
		"can_step_back": can_step_back(),
		"can_step_forward": can_step_forward(),
		"ids": _get_snapshot_ids(),
	}


# --- 私有/辅助方法 ---

func _capture_data() -> Variant:
	if _capture_callback.is_valid():
		return _capture_callback.call()

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null and architecture.has_method("get_global_snapshot"):
		return architecture.get_global_snapshot()

	push_warning("[GFSnapshotHistoryUtility] capture() 失败：未配置捕获回调，且没有可用架构快照。")
	return null


func _get_callable_option(options: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, key, Callable())
	if value is Callable:
		return value
	return Callable()


func _restore_data(data: Variant) -> bool:
	if _restore_callback.is_valid():
		var result: Variant = _restore_callback.call(_duplicate_snapshot_payload(data))
		return result != false

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null and architecture.has_method("restore_global_snapshot") and data is Dictionary:
		var snapshot_data: Dictionary = GFVariantData.as_dictionary(data)
		architecture.restore_global_snapshot(snapshot_data, _restore_command_builder)
		return true

	push_warning("[GFSnapshotHistoryUtility] restore 失败：未配置恢复回调，且没有可用架构快照。")
	return false


func _make_record(snapshot_id: int, data: Variant, metadata: Dictionary) -> Dictionary:
	return {
		"id": snapshot_id,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"metadata": _duplicate_snapshot_payload(metadata),
		"data": _duplicate_snapshot_payload(data),
	}


func _duplicate_record(record: Dictionary) -> Dictionary:
	return {
		"id": _get_record_id(record),
		"created_at_unix": _get_record_created_at_unix(record),
		"metadata": _duplicate_snapshot_payload(_get_record_metadata(record)),
		"data": _duplicate_snapshot_payload(_get_record_data(record)),
	}


func _duplicate_snapshot_payload(value: Variant) -> Variant:
	return GFVariantData.duplicate_variant(value, true, true)


func _is_snapshot_payload_allowed(value: Variant, depth: int) -> bool:
	if depth > 64:
		return false
	if value is Object:
		return false
	if typeof(value) == TYPE_CALLABLE or typeof(value) == TYPE_SIGNAL or typeof(value) == TYPE_RID:
		return false
	if value is Array:
		var source_array: Array = value
		for item: Variant in source_array:
			if not _is_snapshot_payload_allowed(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		for key: Variant in source_dictionary.keys():
			if not _is_snapshot_payload_allowed(key, depth + 1):
				return false
			if not _is_snapshot_payload_allowed(source_dictionary[key], depth + 1):
				return false
	return true


func _trim_history() -> bool:
	if max_history_size <= 0:
		return false

	var changed: bool = false
	while _snapshots.size() > max_history_size:
		_snapshots.pop_front()
		_current_index -= 1
		changed = true

	var previous_index: int = _current_index
	if _snapshots.is_empty():
		_current_index = -1
	else:
		_current_index = clampi(_current_index, 0, _snapshots.size() - 1)
	return changed or previous_index != _current_index


func _find_snapshot_index(snapshot_id: int) -> int:
	for index: int in range(_snapshots.size()):
		if _get_record_id(_snapshots[index]) == snapshot_id:
			return index
	return -1


func _get_snapshot_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for record: Dictionary in _snapshots:
		var _appended: bool = ids.append(_get_record_id(record))
	return ids


func _get_current_snapshot_id() -> int:
	if _current_index < 0 or _current_index >= _snapshots.size():
		return 0
	return _get_record_id(_snapshots[_current_index])


func _get_record_id(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "id", 0)


func _get_record_created_at_unix(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "created_at_unix", 0)


func _get_record_metadata(record: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(record, "metadata", {}))


func _get_record_data(record: Dictionary) -> Variant:
	return GFVariantData.get_option_value(record, "data")


func _emit_history_changed() -> void:
	history_changed.emit(get_debug_snapshot())
