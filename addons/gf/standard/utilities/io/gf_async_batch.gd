## GFAsyncBatch: 通用异步结果批处理器。
##
## 用于等待一组 [GFHttpResponse] 或手动标记的异步条目，并统一汇总成功、失败、
## 取消、超时和首个完成项。它不负责调度具体任务，只观察任务何时进入终态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFAsyncBatch
extends RefCounted


# --- 信号 ---

## 单个条目成功完成后发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param key: 条目标识。
## [br]
## @param result: 条目结果。
## [br]
## @schema key: Variant，调用方持有的条目标识，会作为结果字典的键。
## [br]
## @schema result: Variant，已完成条目的结果。
signal item_completed(key: Variant, result: Variant)

## 单个条目进入任意终态后发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 条目标识。
## [br]
## @param result: 条目结果。
## [br]
## @param state: 条目终态。
## [br]
## @schema key: Variant，调用方持有的条目标识。
## [br]
## @schema result: Variant，调用方定义的条目结果。
signal item_settled(key: Variant, result: Variant, state: StringName)

## 全部或策略要求的条目完成后发出旧式结果字典。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param results: 批处理结果字典。
## [br]
## @schema results: Dictionary，将每个被等待的 key 映射到对应完成结果。
signal completed(results: Dictionary)

## 批处理进入终态后发出结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param report: 批处理终态报告。
## [br]
## @schema report: Dictionary，包含 policy、success、cancelled、timed_out、counts、items、results、completion_order 和 first_completed_key。
signal settled(report: Dictionary)

## 批处理被外部取消时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @schema metadata: Dictionary，调用方定义的取消上下文。
signal cancelled(reason: StringName, metadata: Dictionary)


# --- 枚举 ---

## 批处理完成策略。
## [br]
## @api public
## [br]
## @since 7.0.0
enum CompletionPolicy {
	## 所有条目都成功时批处理成功；失败或取消可按 fail_fast 提前结束。
	ALL,
	## 任一条目成功时批处理成功；所有条目都失败或取消时批处理失败。
	ANY,
	## 等待每个条目进入任意终态，适合 all-settled 汇总。
	EACH,
}

## 条目状态。
## [br]
## @api public
## [br]
## @since 7.0.0
enum ItemState {
	## 条目仍在等待。
	PENDING,
	## 条目成功完成。
	SUCCEEDED,
	## 条目失败。
	FAILED,
	## 条目被取消。
	CANCELLED,
}


# --- 公共变量 ---

## 批处理完成策略。
## [br]
## @api public
## [br]
## @since 7.0.0
var completion_policy: CompletionPolicy = CompletionPolicy.ALL

## ALL / ANY 策略遇到失败或取消时是否提前结束。
## [br]
## @api public
## [br]
## @since 7.0.0
var fail_fast: bool = true

## 批处理终态确定后是否取消仍在等待的条目。
## [br]
## @api public
## [br]
## @since 7.0.0
var cancel_remaining_on_finish: bool = false


# --- 私有变量 ---

var _items: Dictionary = {}
var _completed: bool = false
var _watched_responses: Dictionary = {}
var _watched_completions: Dictionary = {}
var _completion_order: Array = []
var _first_completed_key: Variant = null
var _first_success_key: Variant = null
var _cancel_token_callbacks: Dictionary = {}
var _timeout_source: GFCancellationSource = null
var _cancelled: bool = false
var _timed_out: bool = false
var _cancel_reason: StringName = &""
var _cancel_metadata: Dictionary = {}
var _finalizing: bool = false


# --- 公共方法 ---

## 添加一个等待条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param key: 条目标识。
## [br]
## @param metadata: 条目元数据。
## [br]
## @return 是否添加成功。
## [br]
## @schema key: Variant，调用方持有的条目标识，会作为结果字典的键。
## [br]
## @schema metadata: Dictionary，调用方持有并关联到该条目的元数据。
func add_item(key: Variant, metadata: Dictionary = {}) -> bool:
	if _items.has(key):
		return false
	if _completed:
		return false

	_items[key] = {
		"state": ItemState.PENDING,
		"done": false,
		"result": null,
		"error": "",
		"cancel_reason": &"",
		"metadata": metadata.duplicate(true),
		"cancel_callback": Callable(),
	}
	return true


## 为条目设置取消回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 条目标识。
## [br]
## @param callback: 取消回调，签名推荐为 func(key: Variant, reason: StringName)。
## [br]
## @return 设置成功时返回 true。
## [br]
## @schema key: Variant，调用方持有的条目标识。
func set_item_cancel_callback(key: Variant, callback: Callable) -> bool:
	if not _items.has(key) or _completed:
		return false
	var item: Dictionary = _get_item(key)
	item["cancel_callback"] = callback
	_items[key] = item
	return true


## 监听 GFHttpResponse。
## [br]
## @api public
## [br]
## @param response: 响应对象。
## [br]
## @param key: 条目标识；为空时使用响应 URL。
## [br]
## @return 是否开始监听。
## [br]
## @schema key: Variant，调用方持有的条目标识；为 null 时使用 response.url。
func watch_response(response: GFHttpResponse, key: Variant = null) -> bool:
	if response == null:
		return false

	var item_key: Variant = key
	if item_key == null:
		item_key = response.url
	if not add_item(item_key, response.metadata):
		return false

	var _cancel_callback_result: bool = set_item_cancel_callback(
		item_key,
		func(cancel_key: Variant, reason: StringName) -> void:
			var _unused_key: Variant = cancel_key
			if response.is_pending():
				response.cancel(String(reason))
	)

	if response.is_finished():
		_mark_response_completed(response, item_key)
	else:
		var callback: Callable = _on_response_completed.bind(item_key)
		_watched_responses[item_key] = {
			"response": response,
			"callback": callback,
		}
		var _connect_error: Error = response.completed.connect(
			callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
	return true


## 监听 GFAsyncCompletion。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param completion: 完成源。
## [br]
## @param key: 条目标识；为空时使用 completion 的 instance_id。
## [br]
## @param metadata: 条目元数据。
## [br]
## @return 是否开始监听。
## [br]
## @schema key: Variant，调用方持有的条目标识；为 null 时使用 completion.get_instance_id()。
## [br]
## @schema metadata: Dictionary，调用方持有并关联到该条目的元数据。
func watch_completion(completion: GFAsyncCompletion, key: Variant = null, metadata: Dictionary = {}) -> bool:
	if completion == null:
		return false

	var item_key: Variant = key
	if item_key == null:
		item_key = completion.get_instance_id()
	if not add_item(item_key, metadata):
		return false

	var _cancel_callback_result: bool = set_item_cancel_callback(
		item_key,
		func(cancel_key: Variant, reason: StringName) -> void:
			var _unused_key: Variant = cancel_key
			if completion.is_pending():
				var _cancelled_completion: bool = completion.cancel(reason)
	)

	if completion.is_completed():
		_mark_completion_completed(completion, item_key)
	else:
		var callback: Callable = _on_completion_completed.bind(item_key)
		_watched_completions[item_key] = {
			"completion": completion,
			"callback": callback,
		}
		var _connect_error: Error = completion.completed.connect(
			callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
	return true


## 手动标记条目成功完成。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param key: 条目标识。
## [br]
## @param result: 条目结果。
## [br]
## @return 是否成功标记。
## [br]
## @schema key: Variant，调用方持有的条目标识，会作为结果字典的键。
## [br]
## @schema result: Variant，已完成条目的结果。
func mark_completed(key: Variant, result: Variant = null) -> bool:
	return _mark_item_terminal(key, ItemState.SUCCEEDED, result, "", &"")


## 手动标记条目失败。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 条目标识。
## [br]
## @param error: 失败说明。
## [br]
## @param result: 可选失败结果。
## [br]
## @return 是否成功标记。
## [br]
## @schema key: Variant，调用方持有的条目标识。
## [br]
## @schema result: Variant，调用方定义的失败载荷。
func mark_failed(key: Variant, error: String = "", result: Variant = null) -> bool:
	return _mark_item_terminal(key, ItemState.FAILED, result, error, &"")


## 手动标记条目取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 条目标识。
## [br]
## @param reason: 取消原因。
## [br]
## @param result: 可选取消结果。
## [br]
## @return 是否成功标记。
## [br]
## @schema key: Variant，调用方持有的条目标识。
## [br]
## @schema result: Variant，调用方定义的取消载荷。
func mark_cancelled(key: Variant, reason: StringName = &"cancelled", result: Variant = null) -> bool:
	return _mark_item_terminal(key, ItemState.CANCELLED, result, "", reason)


## 取消整个批处理，并取消仍在等待的条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 首次取消批处理时返回 true。
## [br]
## @schema metadata: Dictionary，调用方定义的取消上下文。
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	if _completed:
		return false

	_cancelled = true
	_timed_out = reason == &"timeout"
	_cancel_reason = reason if reason != &"" else &"cancelled"
	_cancel_metadata = metadata.duplicate(true)
	_finalizing = true
	_cancel_pending_items(_cancel_reason)
	_finalizing = false
	_completed = true
	_disconnect_all_watched_responses()
	_disconnect_all_watched_completions()
	_disconnect_cancel_token()
	_dispose_timeout_source()
	cancelled.emit(_cancel_reason, _cancel_metadata.duplicate(true))
	settled.emit(get_report())
	completed.emit(get_results())
	return true


## 绑定取消 token；token 取消时取消整个批处理。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param token: 取消 token。
## [br]
## @return 成功绑定或 token 已触发取消时返回 true。
func bind_cancel_token(token: GFCancellationToken) -> bool:
	if token == null or _completed:
		return false
	var token_key: int = token.get_instance_id()
	if _cancel_token_callbacks.has(token_key):
		return true
	if token.is_cancel_requested():
		var _cancelled_now: bool = cancel(token.get_cancel_reason(), token.get_cancel_metadata())
		return true

	var callback: Callable = func(reason: StringName) -> void:
		var _cancelled_from_token: bool = cancel(reason, token.get_cancel_metadata())
	var connect_error: Error = token.cancel_requested.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return false
	_cancel_token_callbacks[token_key] = {
		"token": token,
		"callback": callback,
	}
	return true


## 设置批处理超时。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param seconds: 超时时间；小于等于 0 时立即取消。
## [br]
## @param tree: 可选 SceneTree；为空时使用当前主循环。
## [br]
## @param reason: 超时取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 成功安排或立即触发取消时返回 true。
## [br]
## @schema metadata: Dictionary，调用方定义的取消上下文。
func set_timeout(
	seconds: float,
	tree: SceneTree = null,
	reason: StringName = &"timeout",
	metadata: Dictionary = {}
) -> bool:
	if _completed:
		return false
	_dispose_timeout_source()
	_timeout_source = GFCancellationSource.new()
	if not bind_cancel_token(_timeout_source.get_token()):
		_timeout_source = null
		return false
	return _timeout_source.cancel_after_seconds(seconds, tree, reason, metadata)


## 是否批处理已经进入终态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 批处理完成、失败或取消时返回 true。
func is_completed() -> bool:
	return _completed


## 批处理是否以成功状态结束。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 成功结束时返回 true。
func is_successful() -> bool:
	return _completed and _compute_success()


## 获取条目数量。
## [br]
## @api public
## [br]
## @return 当前批处理中的条目数量。
func get_count() -> int:
	return _items.size()


## 获取已进入终态的条目数量。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 已进入终态的条目数量。
func get_completed_count() -> int:
	var count: int = 0
	for item_variant: Variant in _items.values():
		var item: Dictionary = GFVariantData.as_dictionary(item_variant)
		if _is_item_done(item):
			count += 1
	return count


## 获取等待中的条目数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 等待中的条目数量。
func get_pending_count() -> int:
	return get_count() - get_completed_count()


## 获取失败条目数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 失败条目数量。
func get_failed_count() -> int:
	return _count_items_with_state(ItemState.FAILED)


## 获取取消条目数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 取消条目数量。
func get_cancelled_count() -> int:
	return _count_items_with_state(ItemState.CANCELLED)


## 获取结果字典。
## [br]
## @api public
## [br]
## @return key -> result 的字典副本。
## [br]
## @schema return: Dictionary，将每个被等待的 key 映射到对应完成结果或 null。
func get_results() -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in _items.keys():
		var item: Dictionary = _get_item(key)
		result[key] = _get_item_result(item)
	return result


## 获取结构化批处理报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 批处理报告。
## [br]
## @schema return: Dictionary，包含 policy、completed、success、cancelled、timed_out、counts、items、results、completion_order、first_completed_key、first_success_key、cancel_reason 和 cancel_metadata。
func get_report() -> Dictionary:
	return {
		"policy": completion_policy,
		"policy_name": CompletionPolicy.keys()[completion_policy],
		"completed": _completed,
		"success": _completed and _compute_success(),
		"cancelled": _cancelled,
		"timed_out": _timed_out,
		"count": get_count(),
		"completed_count": get_completed_count(),
		"pending_count": get_pending_count(),
		"succeeded_count": _count_items_with_state(ItemState.SUCCEEDED),
		"failed_count": get_failed_count(),
		"cancelled_count": get_cancelled_count(),
		"results": get_results(),
		"items": _get_items_report(),
		"completion_order": _completion_order.duplicate(true),
		"first_completed_key": GFVariantData.duplicate_variant(_first_completed_key),
		"first_success_key": GFVariantData.duplicate_variant(_first_success_key),
		"cancel_reason": _cancel_reason,
		"cancel_metadata": _cancel_metadata.duplicate(true),
	}


## 清空批处理。
## [br]
## @api public
func clear() -> void:
	_disconnect_all_watched_responses()
	_disconnect_all_watched_completions()
	_disconnect_cancel_token()
	_dispose_timeout_source()
	_items.clear()
	_completion_order.clear()
	_first_completed_key = null
	_first_success_key = null
	_completed = false
	_cancelled = false
	_timed_out = false
	_cancel_reason = &""
	_cancel_metadata.clear()
	_finalizing = false


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 count、completed_count、completed、success、policy_name、keys 和 counts。
func get_debug_snapshot() -> Dictionary:
	return {
		"count": get_count(),
		"completed_count": get_completed_count(),
		"pending_count": get_pending_count(),
		"failed_count": get_failed_count(),
		"cancelled_count": get_cancelled_count(),
		"completed": _completed,
		"success": _completed and _compute_success(),
		"policy": completion_policy,
		"policy_name": CompletionPolicy.keys()[completion_policy],
		"cancelled": _cancelled,
		"timed_out": _timed_out,
		"keys": _items.keys(),
	}


# --- 私有/辅助方法 ---

func _mark_item_terminal(
	key: Variant,
	state: ItemState,
	result: Variant,
	error: String,
	cancel_reason: StringName,
	terminal_metadata: Dictionary = {}
) -> bool:
	if not _items.has(key):
		return false

	var item: Dictionary = _get_item(key)
	if _is_item_done(item):
		return false

	item["state"] = state
	item["done"] = true
	item["result"] = GFVariantData.duplicate_variant(result)
	item["error"] = error
	item["cancel_reason"] = cancel_reason
	if not terminal_metadata.is_empty():
		item["metadata"] = _merge_item_metadata(item, terminal_metadata)
	_items[key] = item
	_disconnect_watched_response(key)
	_disconnect_watched_completion(key)
	if _first_completed_key == null:
		_first_completed_key = GFVariantData.duplicate_variant(key)
	if state == ItemState.SUCCEEDED and _first_success_key == null:
		_first_success_key = GFVariantData.duplicate_variant(key)
	_completion_order.append(GFVariantData.duplicate_variant(key))

	if state == ItemState.CANCELLED:
		_call_item_cancel_callback(key, cancel_reason)
	if state == ItemState.SUCCEEDED:
		item_completed.emit(key, result)
	item_settled.emit(key, result, _state_to_name(state))
	_emit_completed_if_ready()
	return true


func _emit_completed_if_ready() -> void:
	if _completed or _finalizing:
		return
	if _items.is_empty():
		return

	match completion_policy:
		CompletionPolicy.ANY:
			if _first_success_key != null:
				_finalize_batch()
				return
			if fail_fast and _has_failed_or_cancelled_item():
				_finalize_batch()
				return
			if get_completed_count() == get_count():
				_finalize_batch()
		CompletionPolicy.EACH:
			if get_completed_count() == get_count():
				_finalize_batch()
		_:
			if fail_fast and _has_failed_or_cancelled_item():
				_finalize_batch()
				return
			if get_completed_count() == get_count():
				_finalize_batch()


func _finalize_batch() -> void:
	if _completed:
		return
	_finalizing = true
	if cancel_remaining_on_finish:
		_cancel_pending_items(&"batch_completed")
	_finalizing = false
	_completed = true
	_disconnect_cancel_token()
	_dispose_timeout_source()
	settled.emit(get_report())
	completed.emit(get_results())


func _cancel_pending_items(reason: StringName) -> void:
	for key: Variant in _items.keys():
		var item: Dictionary = _get_item(key)
		if _is_item_done(item):
			continue
		var _cancelled_item: bool = mark_cancelled(key, reason)


func _mark_response_completed(response: GFHttpResponse, key: Variant) -> void:
	if response.state == GFHttpResponse.State.CANCELLED:
		var _cancelled_item: bool = mark_cancelled(key, StringName(response.error), response)
		return
	if response.state == GFHttpResponse.State.FAILED or not response.is_successful():
		var _failed_item: bool = mark_failed(key, response.error, response)
		return
	var _completed_item: bool = mark_completed(key, response)


func _mark_completion_completed(completion: GFAsyncCompletion, key: Variant) -> void:
	var terminal_metadata: Dictionary = completion.get_metadata()
	if completion.is_cancelled():
		var _cancelled_item: bool = _mark_item_terminal(
			key,
			ItemState.CANCELLED,
			completion.get_result(),
			"",
			completion.get_cancel_reason(),
			terminal_metadata
		)
		return
	if completion.is_failed():
		var _failed_item: bool = _mark_item_terminal(
			key,
			ItemState.FAILED,
			completion.get_result(),
			completion.get_error(),
			&"",
			terminal_metadata
		)
		return
	var _completed_item: bool = _mark_item_terminal(
		key,
		ItemState.SUCCEEDED,
		completion.get_result(),
		"",
		&"",
		terminal_metadata
	)


func _compute_success() -> bool:
	if _cancelled:
		return false
	match completion_policy:
		CompletionPolicy.ANY:
			return _first_success_key != null
		_:
			return get_count() > 0 and get_completed_count() == get_count() and not _has_failed_or_cancelled_item()


func _has_failed_or_cancelled_item() -> bool:
	return get_failed_count() > 0 or get_cancelled_count() > 0


func _count_items_with_state(state: ItemState) -> int:
	var count: int = 0
	for item_variant: Variant in _items.values():
		var item: Dictionary = GFVariantData.as_dictionary(item_variant)
		if _get_item_state(item) == state:
			count += 1
	return count


func _get_items_report() -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in _items.keys():
		var item: Dictionary = _get_item(key)
		var state: ItemState = _get_item_state(item)
		result[key] = {
			"state": state,
			"state_name": _state_to_name(state),
			"done": _is_item_done(item),
			"success": state == ItemState.SUCCEEDED,
			"result": GFVariantData.duplicate_variant(_get_item_result(item)),
			"error": GFVariantData.get_option_string(item, "error"),
			"cancel_reason": GFVariantData.get_option_string_name(item, "cancel_reason"),
			"metadata": GFVariantData.get_option_dictionary(item, "metadata"),
		}
	return result


func _disconnect_watched_response(key: Variant) -> void:
	var entry: Dictionary = _get_watched_response_entry(key)
	var _erase_result: bool = _watched_responses.erase(key)
	if entry.is_empty():
		return

	var response: GFHttpResponse = _get_entry_response(entry)
	var callback: Callable = _get_entry_callback(entry)
	if response != null and callback.is_valid() and response.completed.is_connected(callback):
		response.completed.disconnect(callback)


func _disconnect_watched_completion(key: Variant) -> void:
	var entry: Dictionary = _get_watched_completion_entry(key)
	var _erase_result: bool = _watched_completions.erase(key)
	if entry.is_empty():
		return

	var completion: GFAsyncCompletion = _get_entry_completion(entry)
	var callback: Callable = _get_entry_callback(entry)
	if completion != null and callback.is_valid() and completion.completed.is_connected(callback):
		completion.completed.disconnect(callback)


func _disconnect_all_watched_responses() -> void:
	for key: Variant in _watched_responses.keys():
		_disconnect_watched_response(key)
	_watched_responses.clear()


func _disconnect_all_watched_completions() -> void:
	for key: Variant in _watched_completions.keys():
		_disconnect_watched_completion(key)
	_watched_completions.clear()


func _disconnect_cancel_token() -> void:
	for entry_value: Variant in _cancel_token_callbacks.values():
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var token: GFCancellationToken = _variant_to_cancel_token(GFVariantData.get_option_value(entry, "token"))
		var callback: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "callback", Callable()))
		if token != null and callback.is_valid() and token.cancel_requested.is_connected(callback):
			token.cancel_requested.disconnect(callback)
	_cancel_token_callbacks.clear()


func _dispose_timeout_source() -> void:
	if _timeout_source != null:
		_timeout_source.dispose()
	_timeout_source = null


func _call_item_cancel_callback(key: Variant, reason: StringName) -> void:
	var item: Dictionary = _get_item(key)
	var callback: Callable = _get_item_cancel_callback(item)
	if callback.is_valid():
		callback.call(key, reason)


func _get_item(key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_items, key, {}))


func _is_item_done(item: Dictionary) -> bool:
	return GFVariantData.get_option_bool(item, "done", false)


func _get_item_state(item: Dictionary) -> ItemState:
	var state_value: int = GFVariantData.get_option_int(item, "state", ItemState.PENDING)
	match state_value:
		ItemState.SUCCEEDED:
			return ItemState.SUCCEEDED
		ItemState.FAILED:
			return ItemState.FAILED
		ItemState.CANCELLED:
			return ItemState.CANCELLED
		_:
			return ItemState.PENDING


func _get_item_result(item: Dictionary) -> Variant:
	return GFVariantData.get_option_value(item, "result")


func _get_item_cancel_callback(item: Dictionary) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(item, "cancel_callback", Callable()))


func _get_watched_response_entry(key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_watched_responses, key, {}))


func _get_watched_completion_entry(key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_watched_completions, key, {}))


func _get_entry_response(entry: Dictionary) -> GFHttpResponse:
	return _variant_to_http_response(GFVariantData.get_option_value(entry, "response"))


func _get_entry_completion(entry: Dictionary) -> GFAsyncCompletion:
	return _variant_to_async_completion(GFVariantData.get_option_value(entry, "completion"))


func _get_entry_callback(entry: Dictionary) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(entry, "callback", Callable()))


func _merge_item_metadata(item: Dictionary, terminal_metadata: Dictionary) -> Dictionary:
	var result: Dictionary = GFVariantData.get_option_dictionary(item, "metadata")
	for metadata_key: Variant in terminal_metadata.keys():
		result[metadata_key] = GFVariantData.duplicate_variant(terminal_metadata[metadata_key])
	return result


func _variant_to_http_response(value: Variant) -> GFHttpResponse:
	if value is GFHttpResponse:
		var response: GFHttpResponse = value
		return response
	return null


func _variant_to_async_completion(value: Variant) -> GFAsyncCompletion:
	if value is GFAsyncCompletion:
		var completion: GFAsyncCompletion = value
		return completion
	return null


func _variant_to_cancel_token(value: Variant) -> GFCancellationToken:
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
		return token
	return null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _state_to_name(state: ItemState) -> StringName:
	match state:
		ItemState.SUCCEEDED:
			return &"succeeded"
		ItemState.FAILED:
			return &"failed"
		ItemState.CANCELLED:
			return &"cancelled"
		_:
			return &"pending"


# --- 信号处理函数 ---

func _on_response_completed(response: GFHttpResponse, key: Variant) -> void:
	_disconnect_watched_response(key)
	_mark_response_completed(response, key)


func _on_completion_completed(completion: GFAsyncCompletion, key: Variant) -> void:
	_disconnect_watched_completion(key)
	_mark_completion_completed(completion, key)
