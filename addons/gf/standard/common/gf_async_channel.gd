## GFAsyncChannel: 轻量异步事件通道。
##
## 提供多生产者、单消费者的无界队列语义，可同步写入，也可异步等待下一条数据。
## 它不负责调度任务、流式转换或业务协议，只在生产者和消费者之间传递 Variant 事件。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFAsyncChannel
extends RefCounted


# --- 信号 ---

## 成功写入一条数据时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param item: 写入的数据副本。
## [br]
## @schema item: Variant 写入通道的数据副本。
signal item_written(item: Variant)

## 通道关闭时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 关闭原因。
## [br]
## @param metadata: 关闭上下文。
## [br]
## @schema metadata: Dictionary，包含调用方定义的关闭上下文。
signal closed(reason: StringName, metadata: Dictionary)


# --- 常量 ---

const _GF_ASYNC_RESULT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_result_support.gd")

## 读取已完成。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_COMPLETED: StringName = GFAsyncWaitUtility.STATUS_COMPLETED

## 读取等待被取消。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_CANCELLED: StringName = GFAsyncWaitUtility.STATUS_CANCELLED

## 读取等待超时。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_TIMEOUT: StringName = GFAsyncWaitUtility.STATUS_TIMEOUT

## 读取等待因上下文失效结束。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVALID: StringName = GFAsyncWaitUtility.STATUS_INVALID

## 通道已关闭且没有可读数据。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_CLOSED: StringName = &"closed"

## 通道当前没有可读数据。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_PENDING: StringName = &"pending"


# --- 私有变量 ---

var _items: Array = []
var _closed: bool = false
var _close_reason: StringName = &""
var _close_metadata: Dictionary = {}
var _written_count: int = 0
var _read_count: int = 0


# --- 公共方法 ---

## 写入一条数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param item: 待写入的数据。
## [br]
## @schema item: Variant 待写入通道的数据。
## [br]
## @return 写入成功时返回 true；关闭后返回 false。
func try_write(item: Variant) -> bool:
	if _closed:
		return false
	var stored_item: Variant = GFVariantData.duplicate_variant(item)
	_items.append(stored_item)
	_written_count += 1
	item_written.emit(GFVariantData.duplicate_variant(stored_item))
	return true


## 关闭通道。已缓冲的数据仍可继续读出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 关闭原因。
## [br]
## @param metadata: 关闭上下文。
## [br]
## @return 首次关闭时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的关闭上下文。
func close(reason: StringName = STATUS_CLOSED, metadata: Dictionary = {}) -> bool:
	if _closed:
		return false
	_closed = true
	_close_reason = reason if reason != &"" else STATUS_CLOSED
	_close_metadata = metadata.duplicate(true)
	closed.emit(_close_reason, _close_metadata.duplicate(true))
	return true


## 同步尝试读取一条数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param default_value: 无可读数据时返回的兜底 item。
## [br]
## @schema default_value: Variant 无可读数据时写入返回结果 item 的兜底值。
## [br]
## @return 读取结果。
## [br]
## @schema return: Dictionary，包含 status、ok、item、closed、reason 和 metadata。
func try_read(default_value: Variant = null) -> Dictionary:
	if not _items.is_empty():
		var item: Variant = _items.pop_front()
		_read_count += 1
		return _make_read_result(STATUS_COMPLETED, true, item)
	if _closed:
		return _make_read_result(STATUS_CLOSED, false, default_value, true, _close_reason, _close_metadata)
	return _make_read_result(STATUS_PENDING, false, default_value)


## 等待并读取下一条数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 等待选项，透传给 GFAsyncWaitUtility.wait_until。
## [br]
## @param default_value: 无可读数据时返回的兜底 item。
## [br]
## @schema default_value: Variant 无可读数据时写入返回结果 item 的兜底值。
## [br]
## @return 读取结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @schema return: Dictionary，包含 status、ok、item、closed、reason、metadata 和 wait_result。
func read_async(options: Dictionary = {}, default_value: Variant = null) -> Dictionary:
	while true:
		var immediate: Dictionary = try_read(default_value)
		var immediate_status: StringName = GFVariantData.get_option_string_name(immediate, "status")
		if immediate_status != STATUS_PENDING:
			return immediate

		var wait_result: Dictionary = await GFAsyncWaitUtility.wait_until(
			func() -> bool:
				return has_items() or is_closed(),
			options
		)
		var wait_status: StringName = GFVariantData.get_option_string_name(wait_result, "status")
		if wait_status != GFAsyncWaitUtility.STATUS_COMPLETED:
			return _make_read_result(
				wait_status,
				false,
				default_value,
				false,
				GFVariantData.get_option_string_name(wait_result, "reason"),
				GFVariantData.get_option_dictionary(wait_result, "metadata"),
				{ "wait_result": wait_result }
			)
	return _make_read_result(STATUS_INVALID, false, default_value)


## 等待通道进入可读或关闭状态，不消费数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 等待选项，透传给 GFAsyncWaitUtility.wait_until。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @return 等待结果。
## [br]
## @schema return: Dictionary，包含 status、readable、closed、reason、metadata 和 count。
func wait_to_read_async(options: Dictionary = {}) -> Dictionary:
	while not has_items() and not _closed:
		var wait_result: Dictionary = await GFAsyncWaitUtility.wait_until(
			func() -> bool:
				return has_items() or is_closed(),
			options
		)
		var wait_status: StringName = GFVariantData.get_option_string_name(wait_result, "status")
		if wait_status != GFAsyncWaitUtility.STATUS_COMPLETED:
			return _make_ready_result(
				wait_status,
				false,
				GFVariantData.get_option_string_name(wait_result, "reason"),
				GFVariantData.get_option_dictionary(wait_result, "metadata"),
				{ "wait_result": wait_result }
			)

	if has_items():
		return _make_ready_result(STATUS_COMPLETED, true)
	return _make_ready_result(STATUS_CLOSED, false, _close_reason, _close_metadata)


## 读出当前缓冲区中的数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param max_items: 最多读出数量；小于 0 时读出全部。
## [br]
## @return 已读出的数据数组。
## [br]
## @schema return: Array[Variant]，包含按 FIFO 顺序读出的数据副本。
func drain(max_items: int = -1) -> Array:
	var result: Array = []
	var remaining: int = max_items
	while not _items.is_empty() and (max_items < 0 or remaining > 0):
		var item: Variant = _items.pop_front()
		_read_count += 1
		result.append(GFVariantData.duplicate_variant(item))
		remaining -= 1
	return result


## 清空当前缓冲区。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_items.clear()


## 判断通道是否已经关闭。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已关闭时返回 true。
func is_closed() -> bool:
	return _closed


## 判断通道是否仍可写入。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 可写入时返回 true。
func is_open() -> bool:
	return not _closed


## 判断缓冲区中是否存在可读数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 存在可读数据时返回 true。
func has_items() -> bool:
	return not _items.is_empty()


## 获取当前缓冲数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前缓冲数量。
func get_count() -> int:
	return _items.size()


## 获取通道调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 closed、count、written_count、read_count、reason 和 metadata。
func get_debug_snapshot() -> Dictionary:
	return {
		"closed": _closed,
		"count": _items.size(),
		"written_count": _written_count,
		"read_count": _read_count,
		"reason": _close_reason,
		"metadata": _close_metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_read_result(
	status: StringName,
	ok: bool,
	item: Variant,
	is_channel_closed: bool = false,
	reason: StringName = &"",
	metadata: Dictionary = {},
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _GF_ASYNC_RESULT_SUPPORT.make_operation_result(status, ok, reason, metadata)
	result["item"] = GFVariantData.duplicate_variant(item)
	result["closed"] = is_channel_closed
	_merge_extra(result, extra)
	return result


func _make_ready_result(
	status: StringName,
	readable: bool,
	reason: StringName = &"",
	metadata: Dictionary = {},
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _GF_ASYNC_RESULT_SUPPORT.make_operation_result(status, readable, reason, metadata)
	var _erased_ok: bool = result.erase("ok")
	result["readable"] = readable
	result["closed"] = _closed and not readable
	result["count"] = _items.size()
	_merge_extra(result, extra)
	return result


func _merge_extra(result: Dictionary, extra: Dictionary) -> void:
	_GF_ASYNC_RESULT_SUPPORT.merge_extra(result, extra)
