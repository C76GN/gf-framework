extends GutTest


# --- 测试方法 ---

func test_async_batch_any_policy_cancels_remaining_items() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	batch.completion_policy = GFAsyncBatch.CompletionPolicy.ANY
	batch.cancel_remaining_on_finish = true
	var cancelled_keys: Array = []
	var report_state: Dictionary = {
		"report": {},
	}
	var connect_error: Error = batch.settled.connect(func(report: Dictionary) -> void:
		report_state["report"] = report.duplicate(true)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听 settled 信号。")

	assert_true(batch.add_item(&"fast"), "应能添加 fast 条目。")
	assert_true(batch.add_item(&"slow"), "应能添加 slow 条目。")
	assert_true(batch.set_item_cancel_callback(&"slow", func(key: Variant, _reason: StringName) -> void:
		cancelled_keys.append(key)
	), "应能设置条目取消回调。")

	assert_true(batch.mark_completed(&"fast", "ok"), "ANY 策略下首个成功条目应完成批处理。")

	assert_true(batch.is_completed(), "ANY 策略首个成功后应完成。")
	assert_true(batch.is_successful(), "ANY 策略有成功条目时批处理应成功。")
	assert_eq(cancelled_keys, [&"slow"], "终态后应取消剩余条目。")
	var settled_report: Dictionary = GFVariantData.get_option_dictionary(report_state, "report")
	assert_eq(GFVariantData.get_option_int(settled_report, "cancelled_count"), 1, "报告应统计被取消条目。")
	assert_eq(GFVariantData.get_option_string_name(settled_report, "first_success_key"), &"fast", "报告应记录首个成功 key。")


func test_async_batch_fail_fast_records_failed_report() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	batch.fail_fast = true
	assert_true(batch.add_item("a"), "应能添加 a。")
	assert_true(batch.add_item("b"), "应能添加 b。")

	assert_true(batch.mark_failed("a", "network"), "失败条目应可标记。")
	var report: Dictionary = batch.get_report()
	var items: Dictionary = GFVariantData.get_option_dictionary(report, "items")
	var item_a: Dictionary = GFVariantData.get_option_dictionary(items, "a")

	assert_true(batch.is_completed(), "fail_fast 下失败应结束批处理。")
	assert_false(batch.is_successful(), "存在失败条目时批处理不应成功。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 1, "报告应统计失败条目。")
	assert_eq(GFVariantData.get_option_int(report, "pending_count"), 1, "未取消剩余条目时仍应保留 pending 统计。")
	assert_eq(GFVariantData.get_option_string(item_a, "error"), "network", "条目报告应保留失败说明。")


func test_async_batch_timeout_uses_cancel_token_path() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	assert_true(batch.add_item("slow"), "应能添加慢条目。")
	assert_true(batch.set_timeout(0.01, get_tree()), "应能设置批处理超时。")

	var wait_result: Dictionary = await GFAsyncWaitUtility.await_signal_payload(batch.settled, {
		"timeout_seconds": 1.0,
	})
	var args: Array = GFVariantData.get_option_array(wait_result, "args")
	var report: Dictionary = GFVariantData.as_dictionary(args[0]) if args.size() > 0 else {}

	assert_true(batch.is_completed(), "超时后批处理应进入终态。")
	assert_true(GFVariantData.get_option_bool(report, "cancelled"), "超时报表应标记 cancelled。")
	assert_true(GFVariantData.get_option_bool(report, "timed_out"), "超时报表应标记 timed_out。")
	assert_eq(GFVariantData.get_option_int(report, "cancelled_count"), 1, "等待中的条目应被取消。")


func test_async_batch_timeout_keeps_existing_cancel_token() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(batch.add_item("slow"), "应能添加慢条目。")
	assert_true(batch.bind_cancel_token(source.get_token()), "应能绑定外部取消 token。")
	assert_true(batch.set_timeout(1.0, get_tree()), "设置超时不应移除外部取消 token。")

	assert_true(source.cancel(&"user_cancelled"), "外部取消应成功。")
	var report: Dictionary = batch.get_report()

	assert_true(batch.is_completed(), "外部 token 取消后批处理应完成。")
	assert_eq(GFVariantData.get_option_string_name(report, "cancel_reason"), &"user_cancelled", "批处理应保留外部取消原因。")
	assert_eq(GFVariantData.get_option_int(report, "cancelled_count"), 1, "外部取消应取消等待条目。")


func test_async_batch_watch_completion_any_policy_cancels_remaining_completion() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	batch.completion_policy = GFAsyncBatch.CompletionPolicy.ANY
	batch.cancel_remaining_on_finish = true
	var fast: GFAsyncCompletion = GFAsyncCompletion.new()
	var slow: GFAsyncCompletion = GFAsyncCompletion.new()

	assert_true(batch.watch_completion(fast, &"fast"), "应能监听 fast completion。")
	assert_true(batch.watch_completion(slow, &"slow"), "应能监听 slow completion。")

	var _fast_completed: bool = fast.succeed("ok")
	var report: Dictionary = batch.get_report()
	var results: Dictionary = GFVariantData.get_option_dictionary(report, "results")

	assert_true(batch.is_completed(), "ANY 策略应在首个成功 completion 后完成。")
	assert_true(batch.is_successful(), "ANY 策略存在成功 completion 时应成功。")
	assert_true(slow.is_cancelled(), "终态后应取消剩余 completion。")
	assert_eq(GFVariantData.get_option_string_name(report, "first_success_key"), &"fast", "报告应记录首个成功 completion key。")
	assert_eq(GFVariantData.get_option_string(results, &"fast"), "ok", "结果字典应保留 completion 成功值。")
	assert_eq(GFVariantData.get_option_int(report, "cancelled_count"), 1, "报告应统计被取消 completion。")


func test_async_batch_watch_completion_each_policy_preserves_terminal_metadata() -> void:
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	batch.completion_policy = GFAsyncBatch.CompletionPolicy.EACH
	var successful: GFAsyncCompletion = GFAsyncCompletion.new()
	var failed: GFAsyncCompletion = GFAsyncCompletion.new()

	assert_true(batch.watch_completion(successful, &"successful", { "slot": "a" }), "应能监听成功 completion。")
	assert_true(batch.watch_completion(failed, &"failed"), "应能监听失败 completion。")

	var _successful_completed: bool = successful.succeed("done", { "source": "completion" })
	var _failed_completed: bool = failed.fail("network", { "code": 500 })
	var report: Dictionary = batch.get_report()
	var items: Dictionary = GFVariantData.get_option_dictionary(report, "items")
	var successful_item: Dictionary = GFVariantData.get_option_dictionary(items, &"successful")
	var failed_item: Dictionary = GFVariantData.get_option_dictionary(items, &"failed")
	var successful_metadata: Dictionary = GFVariantData.get_option_dictionary(successful_item, "metadata")
	var failed_metadata: Dictionary = GFVariantData.get_option_dictionary(failed_item, "metadata")

	assert_true(batch.is_completed(), "EACH 策略应等待所有 completion 进入终态。")
	assert_false(batch.is_successful(), "EACH 策略存在失败 completion 时不应成功。")
	assert_eq(GFVariantData.get_option_string(successful_item, "result"), "done", "成功条目应保留 completion 结果。")
	assert_eq(GFVariantData.get_option_string(failed_item, "error"), "network", "失败条目应保留 completion 错误。")
	assert_eq(GFVariantData.get_option_string(successful_metadata, "slot"), "a", "条目 metadata 应保留调用方上下文。")
	assert_eq(GFVariantData.get_option_string(successful_metadata, "source"), "completion", "条目 metadata 应合并终态 metadata。")
	assert_eq(GFVariantData.get_option_int(failed_metadata, "code"), 500, "失败条目应合并 completion metadata。")


func test_async_batch_watched_response_failure_marks_item_failed() -> void:
	var response: GFHttpResponse = GFHttpResponse.new()
	response.url = "https://example.invalid/config"
	var batch: GFAsyncBatch = GFAsyncBatch.new()

	assert_true(batch.watch_response(response, &"request"), "批处理应能监听响应。")
	response.complete_failure("HTTP 500", {
		"status_code": 500,
	})

	var report: Dictionary = batch.get_report()
	var items: Dictionary = GFVariantData.get_option_dictionary(report, "items")
	var request_item: Dictionary = GFVariantData.get_option_dictionary(items, &"request")

	assert_true(batch.is_completed(), "默认 ALL + fail_fast 下响应失败应结束批处理。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 1, "响应失败应统计为 failed。")
	assert_eq(GFVariantData.get_option_string(request_item, "error"), "HTTP 500", "条目应保留响应错误。")
