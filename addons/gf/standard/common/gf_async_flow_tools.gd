## GFAsyncFlowTools: 小型异步流程辅助。
##
## 在现有 GFAsyncCompletion / GFAsyncWaitUtility 之上提供重试、顺序遍历和折叠。
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


# --- 私有/辅助方法 ---

static func _normalize_async_result(raw_result: Variant, options: Dictionary) -> Dictionary:
	if raw_result is GFAsyncCompletion:
		var completion: GFAsyncCompletion = raw_result
		var snapshot: Dictionary = await completion.wait_async(GFVariantData.get_option_dictionary(options, "operation_options"))
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
	var token: GFCancelToken = _get_cancel_token(options)
	if token == null or not token.is_cancelled():
		return {}
	var report: Dictionary = _make_cancelled_report(options, attempt_index, history)
	report["cancel_reason"] = token.get_reason()
	report["cancel_metadata"] = token.get_metadata()
	return report


static func _make_cancelled_report(options: Dictionary, attempt_index: int, history: Array[Dictionary]) -> Dictionary:
	var token: GFCancelToken = _get_cancel_token(options)
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
		report["cancel_reason"] = token.get_reason()
		report["cancel_metadata"] = token.get_metadata()
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


static func _get_cancel_token(options: Dictionary) -> GFCancelToken:
	var value: Variant = GFVariantData.get_option_value(options, "cancel_token")
	if value is GFCancelToken:
		var token: GFCancelToken = value
		return token
	return null
