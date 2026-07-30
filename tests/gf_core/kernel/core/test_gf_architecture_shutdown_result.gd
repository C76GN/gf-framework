# GFArchitectureShutdownResult 有界不可变快照回归测试。
extends GutTest


# --- 测试用例 ---

func test_create_normalizes_timing_and_module_schema() -> void:
	var module_results: Array[Dictionary] = [
		{
			"kind": &"utility",
			"script": "res://tests/test_shutdown_utility.gd",
			"instance_id": 42,
			"status": &"succeeded",
			"reason": "drained",
			"duration_msec": 7,
			"untrusted_extra": {"payload": "must not escape"},
		},
	]

	var result: GFArchitectureShutdownResult = GFArchitectureShutdownResult.create(
		GFArchitectureShutdownResult.Status.SUCCEEDED,
		20,
		10,
		module_results,
		[],
		-3,
		ERR_CANT_CREATE,
		"ignored for successful status"
	)
	module_results[0]["reason"] = "mutated after create"

	assert_true(result.is_successful())
	assert_eq(result.get_status_name(), &"succeeded")
	assert_eq(result.get_started_at_msec(), 20)
	assert_eq(result.get_completed_at_msec(), 20)
	assert_eq(result.get_duration_msec(), 0)
	assert_eq(result.get_duplicate_request_count(), 0)
	assert_eq(result.get_error_code(), OK)
	var stored_results: Array[Dictionary] = result.get_module_results()
	assert_eq(stored_results.size(), 1)
	assert_eq(stored_results[0].size(), 6)
	assert_eq(_get_string_field(stored_results[0], "reason"), "drained")
	assert_false(stored_results[0].has("untrusted_extra"))


func test_collection_getters_to_dict_and_duplicate_result_are_copy_safe() -> void:
	var module_results: Array[Dictionary] = [
		{
			"kind": &"system",
			"script": "res://tests/test_shutdown_system.gd",
			"instance_id": 73,
			"status": &"failed",
			"reason": "injected",
			"duration_msec": 12,
		},
	]
	var unfinished_modules: Array[Dictionary] = [
		{
			"kind": &"model",
			"script": "res://tests/test_shutdown_model.gd",
			"instance_id": 91,
			"status": &"pending",
			"reason": "deadline",
			"duration_msec": 15,
		},
	]
	var result: GFArchitectureShutdownResult = GFArchitectureShutdownResult.failed(
		ERR_CANT_CREATE,
		"injected failure",
		module_results,
		unfinished_modules,
		100,
		140,
		2
	)

	var first_results: Array[Dictionary] = result.get_module_results()
	first_results[0]["reason"] = "caller mutation"
	var first_unfinished: Array[Dictionary] = result.get_unfinished_modules()
	first_unfinished.clear()
	var report: Dictionary = result.to_dict()
	var report_results_value: Variant = report.get("module_results")
	assert_true(report_results_value is Array)
	if report_results_value is Array:
		var report_results: Array = report_results_value
		var report_entry_value: Variant = report_results[0]
		if report_entry_value is Dictionary:
			var report_entry: Dictionary = report_entry_value
			report_entry["reason"] = "report mutation"

	var duplicated_result: GFArchitectureShutdownResult = result.duplicate_result()

	assert_not_same(duplicated_result, result)
	assert_eq(_get_string_field(result.get_module_results()[0], "reason"), "injected")
	assert_eq(result.get_unfinished_modules().size(), 1)
	assert_eq(
		_get_string_field(duplicated_result.get_module_results()[0], "reason"),
		"injected"
	)
	assert_eq(
		_get_string_field(duplicated_result.get_unfinished_modules()[0], "reason"),
		"deadline"
	)
	assert_eq(duplicated_result.get_duplicate_request_count(), 2)
	assert_eq(duplicated_result.get_duration_msec(), 40)


func test_module_result_collections_are_bounded() -> void:
	var module_results: Array[Dictionary] = []
	var _resize_error: Error = module_results.resize(300) as Error
	for index: int in range(300):
		module_results[index] = {
			"kind": &"utility",
			"script": "res://tests/bounded.gd",
			"instance_id": index,
			"status": &"succeeded",
			"reason": "",
			"duration_msec": index,
		}

	var result: GFArchitectureShutdownResult = GFArchitectureShutdownResult.succeeded(
		module_results
	)

	assert_eq(result.get_module_results().size(), 256)


func test_status_factories_preserve_typed_terminal_meaning() -> void:
	var cancelled_result: GFArchitectureShutdownResult = (
		GFArchitectureShutdownResult.cancelled("caller_cancelled")
	)
	var timed_out_result: GFArchitectureShutdownResult = (
		GFArchitectureShutdownResult.timed_out("deadline")
	)
	var forced_result: GFArchitectureShutdownResult = (
		GFArchitectureShutdownResult.forced("forced fallback")
	)
	var disposed_result: GFArchitectureShutdownResult = (
		GFArchitectureShutdownResult.already_disposed(10, 11, 3)
	)

	assert_eq(cancelled_result.get_status(), GFArchitectureShutdownResult.Status.CANCELLED)
	assert_eq(cancelled_result.get_cancel_reason(), "caller_cancelled")
	assert_eq(cancelled_result.get_error_code(), ERR_SKIP)
	assert_eq(timed_out_result.get_status(), GFArchitectureShutdownResult.Status.TIMED_OUT)
	assert_eq(timed_out_result.get_error_code(), ERR_TIMEOUT)
	assert_eq(forced_result.get_status(), GFArchitectureShutdownResult.Status.FORCED)
	assert_false(forced_result.is_successful())
	assert_eq(disposed_result.get_status(), GFArchitectureShutdownResult.Status.ALREADY_DISPOSED)
	assert_true(disposed_result.is_successful())
	assert_eq(disposed_result.get_duplicate_request_count(), 3)


func test_cancel_reason_is_bounded_before_result_storage() -> void:
	var unbounded_reason: String = "x".repeat(2048)
	var result: GFArchitectureShutdownResult = (
		GFArchitectureShutdownResult.cancelled(unbounded_reason)
	)

	assert_eq(result.get_cancel_reason().length(), 1024)
	assert_eq(result.get_cancel_reason(), unbounded_reason.left(1024))
	assert_true(result.to_dict().get("cancel_reason") is String)


# --- 私有/辅助方法 ---

func _get_string_field(entry: Dictionary, key: String) -> String:
	var value: Variant = entry.get(key)
	if value is String:
		var text: String = value
		return text
	return ""
