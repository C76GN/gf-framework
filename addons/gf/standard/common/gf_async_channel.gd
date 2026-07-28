## GFAsyncChannel: 轻量异步事件通道。
##
## 提供多逻辑生产者、单消费者的有界环形队列语义，可同步写入，也可异步等待下一条数据。
## 通道只允许在主线程使用；后台线程应先通过 GFMainThreadDispatchQueue 回到主线程。
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

## 写入已被通道接受。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_WRITTEN: StringName = &"written"

## 写入因容量策略被拒绝。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_REJECTED: StringName = &"rejected"

## 新写入项因容量策略被丢弃。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DROPPED: StringName = &"dropped"

## 操作在非主线程被拒绝。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_WRONG_THREAD: StringName = &"wrong_thread"

## 默认最多缓冲的数据数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_BUFFERED_ITEMS: int = 256

## 最多允许配置的缓冲数据数量。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_BUFFERED_ITEMS: int = 65_536

## 容量满时拒绝新写入。
## [br]
## @api public
## [br]
## @since unreleased
const OVERFLOW_REJECT: StringName = &"reject"

## 容量满时丢弃最早缓冲项，再接受新写入。
## [br]
## @api public
## [br]
## @since unreleased
const OVERFLOW_DROP_OLDEST: StringName = &"drop_oldest"

## 容量满时丢弃新写入项。
## [br]
## @api public
## [br]
## @since unreleased
const OVERFLOW_DROP_NEWEST: StringName = &"drop_newest"


# --- 私有变量 ---

var _items: Array = []
var _item_head: int = 0
var _item_count: int = 0
var _closed: bool = false
var _close_reason: StringName = &""
var _close_metadata: Dictionary = {}
var _written_count: int = 0
var _read_count: int = 0
var _max_buffered_items: int = DEFAULT_MAX_BUFFERED_ITEMS
var _overflow_policy: StringName = OVERFLOW_REJECT
var _high_watermark: int = 0
var _rejected_count: int = 0
var _dropped_count: int = 0


# --- 公共方法 ---

## 配置有界缓冲和容量满时的处理策略。
##
## 该配置不会驱逐现有数据；max_buffered_items 小于当前缓冲数量时配置失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param max_buffered_items: 最大缓冲数量，必须位于 1..ABSOLUTE_MAX_BUFFERED_ITEMS。
## [br]
## @param overflow_policy: OVERFLOW_REJECT、OVERFLOW_DROP_OLDEST 或 OVERFLOW_DROP_NEWEST。
## [br]
## @return 配置被接受时返回 true。
func configure_ingress(
	max_buffered_items: int,
	overflow_policy: StringName = OVERFLOW_REJECT
) -> bool:
	if not Thread.is_main_thread():
		return false
	if (
		max_buffered_items <= 0
		or max_buffered_items > ABSOLUTE_MAX_BUFFERED_ITEMS
	):
		return false
	if max_buffered_items < _item_count:
		return false
	if not _is_supported_overflow_policy(overflow_policy):
		return false
	if max_buffered_items != _max_buffered_items:
		_resize_item_storage(max_buffered_items)
	_max_buffered_items = max_buffered_items
	_overflow_policy = overflow_policy
	return true


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
## @return 写入被通道接受时返回 true；关闭、拒绝或丢弃新项时返回 false。
func try_write(item: Variant) -> bool:
	var result: Dictionary = try_write_detailed(item)
	return GFVariantData.get_option_bool(result, "accepted")


## 写入一条数据并返回结构化背压结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param item: 待写入的数据。
## [br]
## @schema item: Variant 待写入通道的数据。
## [br]
## @return 写入结果。
## [br]
## @schema return: Dictionary，包含 ok、status、accepted、dropped、dropped_item、reason、count、max_buffered_items 和 overflow_policy。
func try_write_detailed(item: Variant) -> Dictionary:
	if not Thread.is_main_thread():
		return {
			"ok": false,
			"status": STATUS_WRONG_THREAD,
			"accepted": false,
			"dropped": false,
			"dropped_item": null,
			"reason": STATUS_WRONG_THREAD,
			"count": -1,
			"max_buffered_items": 0,
			"overflow_policy": &"",
		}
	if _closed:
		return _make_write_result(STATUS_CLOSED, false, false, null, STATUS_CLOSED)

	var dropped: bool = false
	var dropped_item: Variant = null
	if _item_count >= _max_buffered_items:
		match _overflow_policy:
			OVERFLOW_DROP_OLDEST:
				dropped_item = _take_buffered_item()
				dropped = true
				_dropped_count += 1
			OVERFLOW_DROP_NEWEST:
				_dropped_count += 1
				return _make_write_result(
					STATUS_DROPPED,
					false,
					true,
					item,
					&"capacity"
				)
			_:
				_rejected_count += 1
				return _make_write_result(
					STATUS_REJECTED,
					false,
					false,
					null,
					&"capacity"
				)

	var stored_item: Variant = GFVariantData.duplicate_variant(item)
	_append_buffered_item(stored_item)
	_written_count += 1
	_high_watermark = maxi(_high_watermark, _item_count)
	item_written.emit(GFVariantData.duplicate_variant(stored_item))
	return _make_write_result(
		STATUS_WRITTEN,
		true,
		dropped,
		dropped_item,
		&"capacity" if dropped else &""
	)


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
	if not Thread.is_main_thread():
		return false
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
	if not Thread.is_main_thread():
		return _make_read_result(
			STATUS_WRONG_THREAD,
			false,
			default_value,
			false,
			STATUS_WRONG_THREAD
		)
	if _item_count > 0:
		var item: Variant = _take_buffered_item()
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
	if not Thread.is_main_thread():
		return _make_wrong_thread_ready_result()
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
	if not Thread.is_main_thread():
		return result
	var take_count: int = (
		_item_count
		if max_items < 0
		else mini(_item_count, maxi(0, max_items))
	)
	var _resize_result: int = result.resize(take_count)
	for index: int in range(take_count):
		var item: Variant = _take_buffered_item()
		_read_count += 1
		result[index] = GFVariantData.duplicate_variant(item)
	return result


## 清空当前缓冲区。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	if not Thread.is_main_thread():
		return
	_items.clear()
	_item_head = 0
	_item_count = 0


## 判断通道是否已经关闭。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已关闭时返回 true。
func is_closed() -> bool:
	if not Thread.is_main_thread():
		return false
	return _closed


## 判断通道是否仍可写入。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 可写入时返回 true。
func is_open() -> bool:
	if not Thread.is_main_thread():
		return false
	return not _closed


## 判断缓冲区中是否存在可读数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 存在可读数据时返回 true。
func has_items() -> bool:
	if not Thread.is_main_thread():
		return false
	return _item_count > 0


## 获取当前缓冲数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前缓冲数量。
func get_count() -> int:
	if not Thread.is_main_thread():
		return -1
	return _item_count


## 获取最大缓冲数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前最大缓冲数量；非主线程返回 0。
func get_max_buffered_items() -> int:
	if not Thread.is_main_thread():
		return 0
	return _max_buffered_items


## 获取容量满时的处理策略。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 overflow policy；非主线程返回空 StringName。
func get_overflow_policy() -> StringName:
	if not Thread.is_main_thread():
		return &""
	return _overflow_policy


## 获取通道调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 ok、status、closed、count、max_buffered_items、overflow_policy、high_watermark、written_count、read_count、rejected_count、dropped_count、reason 和 metadata；非主线程只返回 wrong_thread 终态。
func get_debug_snapshot() -> Dictionary:
	if not Thread.is_main_thread():
		return {
			"ok": false,
			"status": STATUS_WRONG_THREAD,
			"reason": STATUS_WRONG_THREAD,
		}
	return {
		"ok": true,
		"status": STATUS_COMPLETED,
		"closed": _closed,
		"count": _item_count,
		"max_buffered_items": _max_buffered_items,
		"overflow_policy": _overflow_policy,
		"high_watermark": _high_watermark,
		"written_count": _written_count,
		"read_count": _read_count,
		"rejected_count": _rejected_count,
		"dropped_count": _dropped_count,
		"reason": _close_reason,
		"metadata": _close_metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _resize_item_storage(new_capacity: int) -> void:
	var resized_items: Array = []
	var _resize_result: int = resized_items.resize(new_capacity)
	if _item_count > 0:
		var old_storage_size: int = _items.size()
		for offset: int in range(_item_count):
			var old_index: int = (_item_head + offset) % old_storage_size
			resized_items[offset] = _items[old_index]
	_items = resized_items
	_item_head = 0


func _ensure_item_storage() -> void:
	if _items.size() == _max_buffered_items:
		return
	_resize_item_storage(_max_buffered_items)


func _append_buffered_item(item: Variant) -> void:
	_ensure_item_storage()
	var tail_index: int = (
		(_item_head + _item_count) % _items.size()
	)
	_items[tail_index] = item
	_item_count += 1


func _take_buffered_item() -> Variant:
	if _item_count <= 0 or _items.is_empty():
		return null
	var item: Variant = _items[_item_head]
	_items[_item_head] = null
	_item_count -= 1
	if _item_count <= 0:
		_item_head = 0
	else:
		_item_head = (_item_head + 1) % _items.size()
	return item


func _make_write_result(
	status: StringName,
	accepted: bool,
	dropped: bool,
	dropped_item: Variant,
	reason: StringName
) -> Dictionary:
	return {
		"ok": accepted,
		"status": status,
		"accepted": accepted,
		"dropped": dropped,
		"dropped_item": GFVariantData.duplicate_variant(dropped_item),
		"reason": reason,
		"count": _item_count,
		"max_buffered_items": _max_buffered_items,
		"overflow_policy": _overflow_policy,
	}


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
	result["count"] = _item_count
	_merge_extra(result, extra)
	return result


func _make_wrong_thread_ready_result() -> Dictionary:
	var result: Dictionary = _GF_ASYNC_RESULT_SUPPORT.make_operation_result(
		STATUS_WRONG_THREAD,
		false,
		STATUS_WRONG_THREAD
	)
	var _erased_ok: bool = result.erase("ok")
	result["readable"] = false
	result["closed"] = false
	result["count"] = -1
	return result


func _merge_extra(result: Dictionary, extra: Dictionary) -> void:
	_GF_ASYNC_RESULT_SUPPORT.merge_extra(result, extra)


func _is_supported_overflow_policy(policy: StringName) -> bool:
	return (
		policy == OVERFLOW_REJECT
		or policy == OVERFLOW_DROP_OLDEST
		or policy == OVERFLOW_DROP_NEWEST
	)
