## GFAsyncTrackerUtility: 可选异步句柄追踪工具。
##
## 默认关闭。启用后可登记异步完成源、通道、超时控制器或项目自定义句柄，
## 并通过弱引用生成活动句柄快照，帮助诊断未完成、未释放或异常停留的异步流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFAsyncTrackerUtility
extends GFUtility


# --- 信号 ---

## 句柄被登记时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param tracking_id: 追踪 ID。
## [br]
## @param label: 追踪标签。
signal async_handle_tracked(tracking_id: int, label: StringName)

## 句柄被移除追踪时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param tracking_id: 追踪 ID。
## [br]
## @param label: 追踪标签。
signal async_handle_untracked(tracking_id: int, label: StringName)


# --- 常量 ---

## 默认堆栈文本最大长度。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_STACK_TRACE_CHARS: int = 4000


# --- 公共变量 ---

## 是否启用追踪。关闭时 track_handle 直接返回 0。
## [br]
## @api public
## [br]
## @since 7.0.0
var tracking_enabled: bool = false

## 是否在登记时捕获调用堆栈。
## [br]
## @api public
## [br]
## @since 7.0.0
var stack_trace_enabled: bool = false

## 单条堆栈文本最大长度。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_stack_trace_chars: int = DEFAULT_MAX_STACK_TRACE_CHARS:
	set(value):
		max_stack_trace_chars = maxi(value, 0)


# --- 私有变量 ---

var _records: Dictionary = {}
var _next_tracking_id: int = 1
var _dirty: bool = false


# --- GF 生命周期方法 ---

## 清除所有追踪记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


# --- 公共方法 ---

## 登记一个异步句柄。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: 待追踪对象。
## [br]
## @param label: 稳定标签；为空时使用 handle.get_class()。
## [br]
## @param metadata: 追踪上下文。
## [br]
## @param snapshot_provider: 可选无参快照回调；返回值会收窄为 Dictionary。
## [br]
## @return 追踪 ID；未启用或 handle 为空时返回 0。
## [br]
## @schema metadata: Dictionary，包含调用方定义的追踪上下文。
func track_handle(
	handle: Object,
	label: StringName = &"",
	metadata: Dictionary = {},
	snapshot_provider: Callable = Callable()
) -> int:
	if not tracking_enabled or handle == null:
		return 0

	var tracking_id: int = _next_tracking_id
	_next_tracking_id += 1
	var resolved_label: StringName = label if label != &"" else StringName(handle.get_class())
	_records[tracking_id] = {
		"tracking_id": tracking_id,
		"label": resolved_label,
		"handle_ref": weakref(handle),
		"handle_instance_id": handle.get_instance_id(),
		"created_msec": Time.get_ticks_msec(),
		"metadata": metadata.duplicate(true),
		"snapshot_provider": snapshot_provider,
		"stack_trace": _capture_stack_trace() if stack_trace_enabled else "",
	}
	_dirty = true
	async_handle_tracked.emit(tracking_id, resolved_label)
	return tracking_id


## 按追踪 ID 取消登记。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param tracking_id: 追踪 ID。
## [br]
## @return 成功移除时返回 true。
func untrack_id(tracking_id: int) -> bool:
	if not _records.has(tracking_id):
		return false
	var record: Dictionary = GFVariantData.as_dictionary(_records[tracking_id])
	var label: StringName = GFVariantData.get_option_string_name(record, "label")
	var _erased: bool = _records.erase(tracking_id)
	_dirty = true
	async_handle_untracked.emit(tracking_id, label)
	return true


## 移除指定对象的所有追踪记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: 待移除对象。
## [br]
## @return 移除数量。
func untrack_handle(handle: Object) -> int:
	if handle == null:
		return 0
	var removed_count: int = 0
	for tracking_id: int in _records.keys():
		var record: Dictionary = GFVariantData.as_dictionary(_records[tracking_id])
		if GFVariantData.get_option_int(record, "handle_instance_id", -1) != handle.get_instance_id():
			continue
		if untrack_id(tracking_id):
			removed_count += 1
	return removed_count


## 清除已经失效的弱引用记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 清除数量。
func clear_invalid() -> int:
	var removed_count: int = 0
	for tracking_id: int in _records.keys():
		var record: Dictionary = GFVariantData.as_dictionary(_records[tracking_id])
		if _record_handle_is_valid(record):
			continue
		var _removed: bool = untrack_id(tracking_id)
		removed_count += 1
	return removed_count


## 清空所有追踪记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	if _records.is_empty():
		return
	for tracking_id: int in _records.keys():
		var _untracked: bool = untrack_id(tracking_id)


## 判断是否存在未读取的追踪变更，并重置 dirty 标记。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 自上次调用以来有追踪变化时返回 true。
func check_and_reset_dirty() -> bool:
	var was_dirty: bool = _dirty
	_dirty = false
	return was_dirty


## 获取活动追踪记录快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param include_invalid: 是否包含弱引用已失效的记录。
## [br]
## @return 追踪记录数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 tracking_id、label、valid、age_msec、metadata 和可选 snapshot / stack_trace。
func get_active_records(include_invalid: bool = false) -> Array[Dictionary]:
	if not include_invalid:
		var _cleared_invalid_count: int = clear_invalid()
	var result: Array[Dictionary] = []
	var tracking_ids: Array = _records.keys()
	tracking_ids.sort()
	for tracking_id: int in tracking_ids:
		var record: Dictionary = GFVariantData.as_dictionary(_records[tracking_id])
		var is_valid_record: bool = _record_handle_is_valid(record)
		if not include_invalid and not is_valid_record:
			continue
		result.append(_record_to_snapshot(record, is_valid_record))
	return result


## 获取追踪调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 enabled、active_count、invalid_count、dirty 和 records。
func get_debug_snapshot() -> Dictionary:
	var active_records: Array[Dictionary] = get_active_records(false)
	return {
		"enabled": tracking_enabled,
		"stack_trace_enabled": stack_trace_enabled,
		"active_count": active_records.size(),
		"invalid_count": _get_invalid_count(),
		"dirty": _dirty,
		"records": active_records,
	}


# --- 私有/辅助方法 ---

func _record_to_snapshot(record: Dictionary, is_valid_record: bool) -> Dictionary:
	var created_msec: int = GFVariantData.get_option_int(record, "created_msec", Time.get_ticks_msec())
	var result: Dictionary = {
		"tracking_id": GFVariantData.get_option_int(record, "tracking_id"),
		"label": GFVariantData.get_option_string_name(record, "label"),
		"valid": is_valid_record,
		"age_msec": maxi(Time.get_ticks_msec() - created_msec, 0),
		"handle_instance_id": GFVariantData.get_option_int(record, "handle_instance_id"),
		"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
	}

	var stack_trace: String = GFVariantData.get_option_string(record, "stack_trace")
	if not stack_trace.is_empty():
		result["stack_trace"] = stack_trace

	var snapshot_provider: Callable = _variant_to_callable(GFVariantData.get_option_value(record, "snapshot_provider", Callable()))
	if is_valid_record and snapshot_provider.is_valid():
		var snapshot_value: Variant = snapshot_provider.call()
		var snapshot: Dictionary = GFVariantData.to_dictionary(snapshot_value)
		if not snapshot.is_empty():
			result["snapshot"] = snapshot
	return result


func _record_handle_is_valid(record: Dictionary) -> bool:
	return _weak_ref_to_object(_variant_to_weak_ref(GFVariantData.get_option_value(record, "handle_ref"))) != null


func _get_invalid_count() -> int:
	var invalid_count: int = 0
	for record_value: Variant in _records.values():
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if not _record_handle_is_valid(record):
			invalid_count += 1
	return invalid_count


func _capture_stack_trace() -> String:
	if max_stack_trace_chars <= 0:
		return ""
	var stack_entries: Array = get_stack()
	var text: String = ""
	for entry_value: Variant in stack_entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var source: String = GFVariantData.get_option_string(entry, "source")
		var function_name: String = GFVariantData.get_option_string(entry, "function")
		var line_number: int = GFVariantData.get_option_int(entry, "line")
		var line_text: String = "%s:%d %s" % [source, line_number, function_name]
		text = line_text if text.is_empty() else "%s\n%s" % [text, line_text]
		if text.length() >= max_stack_trace_chars:
			return text.substr(0, max_stack_trace_chars)
	return text


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


func _weak_ref_to_object(weak_ref: WeakRef) -> Object:
	if weak_ref == null:
		return null
	var value: Variant = weak_ref.get_ref()
	if value is Object:
		var object_value: Object = value
		return object_value
	return null
