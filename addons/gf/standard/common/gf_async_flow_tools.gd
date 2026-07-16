## GFAsyncFlowTools: 小型异步流程辅助。
##
## 在现有 GFAsyncCompletion / GFAsyncWaitUtility 之上提供重试、顺序遍历、折叠和 completion 组合。
## 它不引入 Promise 类型，不调度后台线程，也不规定业务任务模型；调用方只需要
## 提供 Callable，并接收稳定的结果字典。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFAsyncFlowTools
extends RefCounted


# --- 常量 ---

## 流程成功完成。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_SUCCEEDED: StringName = &"succeeded"

## 流程失败。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_FAILED: StringName = &"failed"

## 流程被取消。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_CANCELLED: StringName = &"cancelled"


# --- 公共方法 ---

## 重试执行一个操作。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param operation: 要执行的操作。
## [br]
## @param options: 重试选项。
## [br]
## @schema options: Dictionary，可包含 attempts、delay_seconds、tree、cancel_token、operation_options、pass_attempt 和 metadata。
## [br]
## @return 流程报告。
## [br]
## @schema return: Dictionary with ok, status, value, error, attempts, history, metadata, and optional cancel_reason.
static func retry_async(operation: Callable, options: Dictionary = {}) -> Dictionary:
	if not operation.is_valid():
		return _make_report(false, STATUS_FAILED, null, "operation is invalid.", 0, [], options)

	var max_attempts: int = maxi(GFVariantData.get_option_int(options, "attempts", 1), 1)
	var delay_seconds: float = maxf(GFVariantData.get_option_float(options, "delay_seconds", 0.0), 0.0)
	var history: Array[Dictionary] = []
	for attempt_index: int in range(max_attempts):
		var cancel_result: Dictionary = _get_cancel_result(options, attempt_index, history)
		if not cancel_result.is_empty():
			return cancel_result

		var raw_result: Variant = operation.callv(_make_operation_args(options, attempt_index, null))
		var normalized: Dictionary = await _normalize_async_result(raw_result, options)
		normalized["attempt"] = attempt_index + 1
		history.append(normalized.duplicate(true))
		if GFVariantData.get_option_bool(normalized, "ok"):
			return _make_report(
				true,
				STATUS_SUCCEEDED,
				GFVariantData.get_option_value(normalized, "value"),
				"",
				attempt_index + 1,
				history,
				options
			)

		if attempt_index + 1 < max_attempts and delay_seconds > 0.0:
			var wait_result: Dictionary = await GFAsyncWaitUtility.delay_seconds(delay_seconds, options)
			if GFVariantData.get_option_string_name(wait_result, "status") == GFAsyncWaitUtility.STATUS_CANCELLED:
				return _make_cancelled_report(options, attempt_index + 1, history)

	var last_error: String = _get_last_error(history)
	return _make_report(false, STATUS_FAILED, null, last_error, max_attempts, history, options)


## 顺序处理数组项。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param items: 要处理的项目列表。
## [br]
## @param operation: 项目处理回调。
## [br]
## @param options: 遍历选项。
## [br]
## @schema items: Array input items.
## [br]
## @schema options: Dictionary，可包含 stop_on_failure、cancel_token、operation_options、pass_index 和 metadata。
## [br]
## @return 流程报告。
## [br]
## @schema return: Dictionary with ok, status, value, error, attempts, history, metadata, succeeded_count, and failed_count.
static func each_async(items: Array, operation: Callable, options: Dictionary = {}) -> Dictionary:
	if not operation.is_valid():
		return _make_report(false, STATUS_FAILED, null, "operation is invalid.", 0, [], options)

	var history: Array[Dictionary] = []
	var values: Array = []
	var failed_count: int = 0
	var stop_on_failure: bool = GFVariantData.get_option_bool(options, "stop_on_failure", true)
	for index: int in range(items.size()):
		var cancel_result: Dictionary = _get_cancel_result(options, index, history)
		if not cancel_result.is_empty():
			return cancel_result

		var raw_result: Variant = operation.callv(_make_operation_args(options, index, items[index]))
		var normalized: Dictionary = await _normalize_async_result(raw_result, options)
		normalized["index"] = index
		history.append(normalized.duplicate(true))
		if GFVariantData.get_option_bool(normalized, "ok"):
			values.append(GFVariantData.get_option_value(normalized, "value"))
			continue

		failed_count += 1
		if stop_on_failure:
			break

	var ok: bool = failed_count == 0
	var report: Dictionary = _make_report(
		ok,
		STATUS_SUCCEEDED if ok else STATUS_FAILED,
		values,
		"" if ok else _get_last_error(history),
		history.size(),
		history,
		options
	)
	report["succeeded_count"] = values.size()
	report["failed_count"] = failed_count
	return report


## 顺序折叠数组项。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param items: 要处理的项目列表。
## [br]
## @param reducer: 折叠回调。
## [br]
## @param initial_value: 初始累加值。
## [br]
## @param options: 折叠选项。
## [br]
## @schema items: Array input items.
## [br]
## @schema initial_value: Variant accumulator seed.
## [br]
## @schema options: Dictionary，可包含 stop_on_failure、cancel_token、operation_options、pass_index 和 metadata。
## [br]
## @return 流程报告。
## [br]
## @schema return: Dictionary with ok, status, value, error, attempts, history, and metadata.
static func fold_async(items: Array, reducer: Callable, initial_value: Variant, options: Dictionary = {}) -> Dictionary:
	if not reducer.is_valid():
		return _make_report(false, STATUS_FAILED, initial_value, "reducer is invalid.", 0, [], options)

	var history: Array[Dictionary] = []
	var accumulator: Variant = GFVariantData.duplicate_variant(initial_value, true, true)
	var stop_on_failure: bool = GFVariantData.get_option_bool(options, "stop_on_failure", true)
	for index: int in range(items.size()):
		var cancel_result: Dictionary = _get_cancel_result(options, index, history)
		if not cancel_result.is_empty():
			cancel_result["value"] = GFVariantData.duplicate_variant(accumulator, true, true)
			return cancel_result

		var args: Array = [accumulator, items[index]]
		if GFVariantData.get_option_bool(options, "pass_index", false):
			args.append(index)
		var raw_result: Variant = reducer.callv(args)
		var normalized: Dictionary = await _normalize_async_result(raw_result, options)
		normalized["index"] = index
		history.append(normalized.duplicate(true))
		if GFVariantData.get_option_bool(normalized, "ok"):
			accumulator = GFVariantData.duplicate_variant(GFVariantData.get_option_value(normalized, "value"), true, true)
			continue
		if stop_on_failure:
			return _make_report(false, STATUS_FAILED, accumulator, _get_last_error(history), history.size(), history, options)

	return _make_report(true, STATUS_SUCCEEDED, accumulator, "", history.size(), history, options)


## 等待所有完成源进入终态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param completions: key -> GFAsyncCompletion 的字典。
## [br]
## @param options: 组合等待选项。
## [br]
## @schema completions: Dictionary，key 为调用方定义的稳定标识，value 必须是 GFAsyncCompletion。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、tree、cancel_token、guard_node、time_utility、respect_time_scale、process_in_physics、fail_fast、cancel_remaining_on_finish 和 metadata。
## [br]
## @return 组合等待报告。
## [br]
## @schema return: Dictionary，包含 ok、status、value、error、metadata、count、completed_count、pending_count、succeeded_count、failed_count、cancelled_count、items、results、completion_order、first_completed_key、first_success_key、cancel_reason、cancel_metadata 和 timed_out。
static func wait_all_completions_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:
	return await _wait_completions_async(completions, false, options)


## 等待任一完成源成功。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param completions: key -> GFAsyncCompletion 的字典。
## [br]
## @param options: 组合等待选项。
## [br]
## @schema completions: Dictionary，key 为调用方定义的稳定标识，value 必须是 GFAsyncCompletion。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、tree、cancel_token、guard_node、time_utility、respect_time_scale、process_in_physics、fail_fast、cancel_remaining_on_finish 和 metadata。
## [br]
## @return 组合等待报告。
## [br]
## @schema return: Dictionary，包含 ok、status、value、error、metadata、count、completed_count、pending_count、succeeded_count、failed_count、cancelled_count、items、results、completion_order、first_completed_key、first_success_key、cancel_reason、cancel_metadata 和 timed_out。
static func wait_any_completion_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:
	return await _wait_completions_async(completions, true, options)


# --- 私有/辅助方法 ---

static func _wait_completions_async(completions: Dictionary, wait_for_any_success: bool, options: Dictionary) -> Dictionary:
	var entries: Dictionary = {}
	for key: Variant in completions.keys():
		var completion_value: Variant = completions[key]
		if not (completion_value is GFAsyncCompletion):
			return _make_completion_wait_invalid_report("completion is invalid.", key, options)
		var completion: GFAsyncCompletion = completion_value
		entries[GFVariantData.duplicate_variant(key)] = completion

	var completion_order: Array = []
	_append_precompleted_keys(entries, completion_order)
	if entries.is_empty():
		return _make_completion_wait_report(entries, completion_order, wait_for_any_success, options)

	var channel: GFAsyncChannel = GFAsyncChannel.new()
	var callbacks: Dictionary = {}
	var connect_report: Dictionary = _connect_pending_completions(entries, channel, callbacks)
	if not GFVariantData.get_option_bool(connect_report, "ok"):
		return _make_completion_wait_invalid_report(
			GFVariantData.get_option_string(connect_report, "error", "completion connect failed."),
			GFVariantData.get_option_value(connect_report, "key"),
			options
		)

	var wait_source: GFCancellationSource = _make_completion_wait_cancel_source(options)
	var wait_options: Dictionary = _make_completion_wait_options(options, wait_source)
	var fail_fast: bool = GFVariantData.get_option_bool(options, "fail_fast", false)
	while true:
		var report: Dictionary = _make_completion_wait_report(entries, completion_order, wait_for_any_success, options)
		if _is_completion_wait_finished(report, wait_for_any_success, fail_fast):
			_cancel_remaining_completions_if_requested(entries, options)
			_append_precompleted_keys(entries, completion_order)
			var final_report: Dictionary = _make_completion_wait_report(entries, completion_order, wait_for_any_success, options)
			_disconnect_completion_callbacks(callbacks)
			if wait_source != null:
				wait_source.dispose()
			return _finalize_completion_wait_report(final_report)

		var read_result: Dictionary = await channel.read_async(wait_options)
		var read_status: StringName = GFVariantData.get_option_string_name(read_result, "status")
		if read_status != GFAsyncChannel.STATUS_COMPLETED:
			var cancelled_report: Dictionary = _make_completion_wait_report(entries, completion_order, wait_for_any_success, options)
			var wait_reason: StringName = GFVariantData.get_option_string_name(read_result, "reason", read_status)
			cancelled_report["ok"] = false
			cancelled_report["status"] = STATUS_CANCELLED
			cancelled_report["error"] = String(wait_reason)
			cancelled_report["cancel_reason"] = wait_reason
			cancelled_report["cancel_metadata"] = GFVariantData.get_option_dictionary(read_result, "metadata")
			cancelled_report["timed_out"] = wait_reason == &"timeout" or read_status == GFAsyncChannel.STATUS_TIMEOUT
			_cancel_remaining_completions_if_requested(entries, options)
			_append_precompleted_keys(entries, completion_order)
			cancelled_report = _make_completion_wait_report(entries, completion_order, wait_for_any_success, options)
			cancelled_report["ok"] = false
			cancelled_report["status"] = STATUS_CANCELLED
			cancelled_report["error"] = String(wait_reason)
			cancelled_report["cancel_reason"] = wait_reason
			cancelled_report["cancel_metadata"] = GFVariantData.get_option_dictionary(read_result, "metadata")
			cancelled_report["timed_out"] = wait_reason == &"timeout" or read_status == GFAsyncChannel.STATUS_TIMEOUT
			_disconnect_completion_callbacks(callbacks)
			if wait_source != null:
				wait_source.dispose()
			return cancelled_report

		var event: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(read_result, "item"))
		_append_completion_order(completion_order, GFVariantData.get_option_value(event, "key"))
	return _make_completion_wait_invalid_report("completion wait ended unexpectedly.", null, options)


static func _normalize_async_result(raw_result: Variant, options: Dictionary) -> Dictionary:
	if raw_result is GFAsyncCompletion:
		var completion: GFAsyncCompletion = raw_result
		var snapshot: Dictionary = await GFAsyncWaitUtility.wait_completion_async(
			completion,
			GFVariantData.get_option_dictionary(options, "operation_options")
		)
		if GFVariantData.get_option_bool(snapshot, "successful"):
			return _make_operation_result(true, GFVariantData.get_option_value(snapshot, "result"), "")
		if GFVariantData.get_option_bool(snapshot, "cancelled"):
			return _make_operation_result(false, null, "cancelled", {
				"cancelled": true,
				"cancel_reason": GFVariantData.get_option_string_name(snapshot, "cancel_reason"),
			})
		return _make_operation_result(false, null, GFVariantData.get_option_string(snapshot, "error", "operation failed."))

	if raw_result is Dictionary:
		var data: Dictionary = raw_result
		if data.has("ok"):
			return _make_operation_result(
				GFVariantData.get_option_bool(data, "ok"),
				GFVariantData.get_option_value(data, "value", GFVariantData.get_option_value(data, "data")),
				GFVariantData.get_option_string(data, "error"),
				GFVariantData.get_option_dictionary(data, "metadata")
			)
	return _make_operation_result(true, raw_result, "")


static func _make_operation_args(options: Dictionary, index: int, item: Variant) -> Array:
	var args: Array = []
	if item != null or GFVariantData.get_option_bool(options, "pass_null_item", false):
		args.append(item)
	if GFVariantData.get_option_bool(options, "pass_index", false) or GFVariantData.get_option_bool(options, "pass_attempt", false):
		args.append(index)
	return args


static func _get_cancel_result(options: Dictionary, attempt_index: int, history: Array[Dictionary]) -> Dictionary:
	var token: GFCancellationToken = _get_cancel_token(options)
	if token == null or not token.is_cancel_requested():
		return {}
	var report: Dictionary = _make_cancelled_report(options, attempt_index, history)
	report["cancel_reason"] = token.get_cancel_reason()
	report["cancel_metadata"] = token.get_cancel_metadata()
	return report


static func _make_cancelled_report(options: Dictionary, attempt_index: int, history: Array[Dictionary]) -> Dictionary:
	var token: GFCancellationToken = _get_cancel_token(options)
	var report: Dictionary = _make_report(
		false,
		STATUS_CANCELLED,
		null,
		"cancelled",
		attempt_index,
		history,
		options
	)
	if token != null:
		report["cancel_reason"] = token.get_cancel_reason()
		report["cancel_metadata"] = token.get_cancel_metadata()
	return report


static func _make_operation_result(ok: bool, value: Variant, error: String, metadata: Dictionary = {}) -> Dictionary:
	return {
		"ok": ok,
		"value": GFVariantData.duplicate_variant(value, true, true),
		"error": error,
		"metadata": metadata.duplicate(true),
	}


static func _make_report(
	ok: bool,
	status: StringName,
	value: Variant,
	error: String,
	attempts: int,
	history: Array[Dictionary],
	options: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"value": GFVariantData.duplicate_variant(value, true, true),
		"error": error,
		"attempts": attempts,
		"history": _copy_history(history),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}


static func _copy_history(history: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in history:
		result.append(entry.duplicate(true))
	return result


static func _get_last_error(history: Array[Dictionary]) -> String:
	for index: int in range(history.size() - 1, -1, -1):
		var error: String = GFVariantData.get_option_string(history[index], "error")
		if not error.is_empty():
			return error
	return "operation failed."


static func _get_cancel_token(options: Dictionary) -> GFCancellationToken:
	var value: Variant = GFVariantData.get_option_value(options, "cancel_token")
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
		return token
	return null


static func _connect_pending_completions(entries: Dictionary, channel: GFAsyncChannel, callbacks: Dictionary) -> Dictionary:
	for key: Variant in entries.keys():
		var completion: GFAsyncCompletion = _get_completion_entry(entries, key)
		if completion == null or not completion.is_pending():
			continue
		var callback: Callable = _make_completion_channel_callback(channel, key)
		var connect_error: Error = completion.completed.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error
		if connect_error != OK:
			_disconnect_completion_callbacks(callbacks)
			return {
				"ok": false,
				"key": GFVariantData.duplicate_variant(key),
				"error": "completion signal connect failed.",
			}
		callbacks[GFVariantData.duplicate_variant(key)] = {
			"completion": completion,
			"callback": callback,
		}
	return { "ok": true }


static func _make_completion_channel_callback(channel: GFAsyncChannel, key: Variant) -> Callable:
	var stored_key: Variant = GFVariantData.duplicate_variant(key)
	return func(_completion: GFAsyncCompletion) -> void:
		var _write_result: bool = channel.try_write({
			"key": GFVariantData.duplicate_variant(stored_key),
		})


static func _disconnect_completion_callbacks(callbacks: Dictionary) -> void:
	for entry_variant: Variant in callbacks.values():
		var entry: Dictionary = GFVariantData.as_dictionary(entry_variant)
		var completion_value: Variant = GFVariantData.get_option_value(entry, "completion")
		var callback_value: Variant = GFVariantData.get_option_value(entry, "callback")
		if completion_value is GFAsyncCompletion and callback_value is Callable:
			var completion: GFAsyncCompletion = completion_value
			var callback: Callable = callback_value
			if completion.completed.is_connected(callback):
				completion.completed.disconnect(callback)
	callbacks.clear()


static func _make_completion_wait_cancel_source(options: Dictionary) -> GFCancellationSource:
	var token: GFCancellationToken = _get_cancel_token(options)
	var timeout_seconds: float = maxf(GFVariantData.get_option_float(options, "timeout_seconds", 0.0), 0.0)
	var has_timeout: bool = options.has("timeout_seconds") and timeout_seconds > 0.0
	if token == null and not has_timeout:
		return null

	var source: GFCancellationSource = GFCancellationSource.new()
	if token != null:
		var _linked: bool = source.link_token(token)
	if has_timeout:
		var tree: SceneTree = _get_scene_tree_option(options)
		var _timeout: bool = source.cancel_after_seconds(timeout_seconds, tree, &"timeout", {
			"timeout_seconds": timeout_seconds,
		})
	return source


static func _make_completion_wait_options(options: Dictionary, wait_source: GFCancellationSource) -> Dictionary:
	var wait_options: Dictionary = {}
	for option_key: String in ["guard_node", "tree", "time_utility", "respect_time_scale", "process_in_physics"]:
		if options.has(option_key):
			wait_options[option_key] = GFVariantData.get_option_value(options, option_key)
	if wait_source != null:
		wait_options["cancel_token"] = wait_source.get_token()
	else:
		var token: GFCancellationToken = _get_cancel_token(options)
		if token != null:
			wait_options["cancel_token"] = token
	return wait_options


static func _get_scene_tree_option(options: Dictionary) -> SceneTree:
	var tree_value: Variant = GFVariantData.get_option_value(options, "tree")
	if tree_value is SceneTree:
		var tree: SceneTree = tree_value
		return tree
	return null


static func _make_completion_wait_report(
	entries: Dictionary,
	completion_order: Array,
	wait_for_any_success: bool,
	options: Dictionary
) -> Dictionary:
	var items: Dictionary = {}
	var results: Dictionary = {}
	var completed_count: int = 0
	var succeeded_count: int = 0
	var failed_count: int = 0
	var cancelled_count: int = 0
	var first_completed_key: Variant = null
	var first_success_key: Variant = null
	for ordered_key: Variant in completion_order:
		var ordered_completion: GFAsyncCompletion = _get_completion_entry(entries, ordered_key)
		if ordered_completion == null:
			continue
		if first_completed_key == null and ordered_completion.is_completed():
			first_completed_key = GFVariantData.duplicate_variant(ordered_key)
		if first_success_key == null and ordered_completion.is_successful():
			first_success_key = GFVariantData.duplicate_variant(ordered_key)
	for key: Variant in entries.keys():
		var completion: GFAsyncCompletion = _get_completion_entry(entries, key)
		if completion == null:
			continue
		var snapshot: Dictionary = completion.get_debug_snapshot()
		items[GFVariantData.duplicate_variant(key)] = snapshot
		results[GFVariantData.duplicate_variant(key)] = completion.get_result()
		if completion.is_completed():
			completed_count += 1
		if completion.is_successful():
			succeeded_count += 1
			if first_success_key == null:
				first_success_key = GFVariantData.duplicate_variant(key)
		elif completion.is_failed():
			failed_count += 1
		elif completion.is_cancelled():
			cancelled_count += 1
		if first_completed_key == null and completion.is_completed():
			first_completed_key = GFVariantData.duplicate_variant(key)

	var pending_count: int = entries.size() - completed_count
	var ok: bool = (succeeded_count > 0) if wait_for_any_success else (pending_count == 0 and failed_count == 0 and cancelled_count == 0)
	var status: StringName = _get_completion_wait_status(ok, failed_count, cancelled_count)
	var report: Dictionary = {
		"ok": ok,
		"status": status,
		"value": results.duplicate(true),
		"error": "" if ok else _get_completion_wait_error(failed_count, cancelled_count, pending_count),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
		"count": entries.size(),
		"completed_count": completed_count,
		"pending_count": pending_count,
		"succeeded_count": succeeded_count,
		"failed_count": failed_count,
		"cancelled_count": cancelled_count,
		"items": items,
		"results": results,
		"completion_order": completion_order.duplicate(true),
		"first_completed_key": GFVariantData.duplicate_variant(first_completed_key),
		"first_success_key": GFVariantData.duplicate_variant(first_success_key),
		"cancel_reason": &"",
		"cancel_metadata": {},
		"timed_out": false,
	}
	return report


static func _finalize_completion_wait_report(report: Dictionary) -> Dictionary:
	if GFVariantData.get_option_bool(report, "ok"):
		return report
	var cancel_reason: StringName = GFVariantData.get_option_string_name(report, "cancel_reason")
	if cancel_reason == &"" and GFVariantData.get_option_int(report, "failed_count") == 0 and GFVariantData.get_option_int(report, "cancelled_count") > 0:
		report["cancel_reason"] = &"cancelled"
	return report


static func _make_completion_wait_invalid_report(error: String, key: Variant, options: Dictionary) -> Dictionary:
	var report: Dictionary = _make_completion_wait_report({}, [], false, options)
	report["ok"] = false
	report["status"] = STATUS_FAILED
	report["error"] = error
	report["invalid_key"] = GFVariantData.duplicate_variant(key)
	return report


static func _is_completion_wait_finished(report: Dictionary, wait_for_any_success: bool, fail_fast: bool) -> bool:
	if GFVariantData.get_option_int(report, "count") == 0:
		return true
	if wait_for_any_success and GFVariantData.get_option_int(report, "succeeded_count") > 0:
		return true
	if fail_fast and (
		GFVariantData.get_option_int(report, "failed_count") > 0
		or GFVariantData.get_option_int(report, "cancelled_count") > 0
	):
		return true
	return GFVariantData.get_option_int(report, "pending_count") == 0


static func _cancel_remaining_completions_if_requested(entries: Dictionary, options: Dictionary) -> void:
	if not GFVariantData.get_option_bool(options, "cancel_remaining_on_finish", false):
		return
	for key: Variant in entries.keys():
		var completion: GFAsyncCompletion = _get_completion_entry(entries, key)
		if completion != null and completion.is_pending():
			var _cancelled_completion: bool = completion.cancel(&"flow_completed", {
				"key": GFVariantData.duplicate_variant(key),
			})


static func _append_precompleted_keys(entries: Dictionary, completion_order: Array) -> void:
	for key: Variant in entries.keys():
		var completion: GFAsyncCompletion = _get_completion_entry(entries, key)
		if completion != null and completion.is_completed():
			_append_completion_order(completion_order, key)


static func _append_completion_order(completion_order: Array, key: Variant) -> void:
	for existing_key: Variant in completion_order:
		if existing_key == key:
			return
	completion_order.append(GFVariantData.duplicate_variant(key))


static func _get_completion_entry(entries: Dictionary, key: Variant) -> GFAsyncCompletion:
	var value: Variant = GFVariantData.get_option_value(entries, key)
	if value is GFAsyncCompletion:
		var completion: GFAsyncCompletion = value
		return completion
	return null


static func _get_completion_wait_status(ok: bool, failed_count: int, cancelled_count: int) -> StringName:
	if ok:
		return STATUS_SUCCEEDED
	if failed_count == 0 and cancelled_count > 0:
		return STATUS_CANCELLED
	return STATUS_FAILED


static func _get_completion_wait_error(failed_count: int, cancelled_count: int, pending_count: int) -> String:
	if failed_count > 0:
		return "completion failed."
	if cancelled_count > 0:
		return "cancelled"
	if pending_count > 0:
		return "pending"
	return ""
