## 测试小型异步流程辅助。
extends GutTest


func test_async_flow_retry_stops_after_successful_attempt() -> void:
	var state: Dictionary = { "calls": 0 }

	var result: Dictionary = await GFAsyncFlowTools.retry_async(func() -> Dictionary:
		state["calls"] = GFVariantData.get_option_int(state, "calls") + 1
		if GFVariantData.get_option_int(state, "calls") < 2:
			return { "ok": false, "error": "try again" }
		return { "ok": true, "value": "done" }
	, { "attempts": 3 })

	assert_true(GFVariantData.get_option_bool(result, "ok"), "第二次成功后 retry 应完成。")
	assert_eq(GFVariantData.get_option_int(result, "attempts"), 2, "retry 应报告实际尝试次数。")
	assert_eq(GFVariantData.get_option_string(result, "value"), "done", "retry 应返回成功值。")


func test_async_flow_each_collects_values_in_order() -> void:
	var result: Dictionary = await GFAsyncFlowTools.each_async([1, 2, 3], func(item: int) -> Dictionary:
		return { "ok": true, "value": item * 2 }
	)
	var values: Array = GFVariantData.get_option_array(result, "value")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "each_async 全部成功时应成功。")
	assert_eq(values, [2, 4, 6], "each_async 应按输入顺序收集值。")


func test_async_flow_fold_uses_previous_accumulator() -> void:
	var result: Dictionary = await GFAsyncFlowTools.fold_async([1, 2, 3], func(total: int, item: int) -> Dictionary:
		return { "ok": true, "value": total + item }
	, 0)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "fold_async 全部成功时应成功。")
	assert_eq(GFVariantData.get_option_int(result, "value"), 6, "fold_async 应把每次返回值作为下一次累加值。")


func test_async_flow_wait_all_completions_collects_results() -> void:
	var profile: GFAsyncCompletion = GFAsyncCompletion.new()
	var inventory: GFAsyncCompletion = GFAsyncCompletion.new()

	call_deferred("_complete_two_successes", profile, inventory)
	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"profile": profile,
		&"inventory": inventory,
	}, {
		"timeout_seconds": 1.0,
		"tree": get_tree(),
	})
	var values: Dictionary = GFVariantData.get_option_dictionary(result, "value")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "全部 completion 成功时组合等待应成功。")
	assert_eq(GFVariantData.get_option_string(values, &"profile"), "profile_ready", "报告应按 key 保留第一个结果。")
	assert_eq(GFVariantData.get_option_string(values, &"inventory"), "inventory_ready", "报告应按 key 保留第二个结果。")
	assert_eq(GFVariantData.get_option_int(result, "succeeded_count"), 2, "报告应统计成功数量。")


func test_async_flow_wait_any_completion_can_cancel_remaining() -> void:
	var fast: GFAsyncCompletion = GFAsyncCompletion.new()
	var slow: GFAsyncCompletion = GFAsyncCompletion.new()

	call_deferred("_complete_one_success", fast)
	var result: Dictionary = await GFAsyncFlowTools.wait_any_completion_async({
		&"fast": fast,
		&"slow": slow,
	}, {
		"timeout_seconds": 1.0,
		"tree": get_tree(),
		"cancel_remaining_on_finish": true,
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "任一 completion 成功时组合等待应成功。")
	assert_eq(GFVariantData.get_option_string_name(result, "first_success_key"), &"fast", "报告应记录首个成功 key。")
	assert_true(slow.is_cancelled(), "请求取消剩余项时，未完成 completion 应被取消。")
	assert_eq(GFVariantData.get_option_int(result, "cancelled_count"), 1, "返回报告应包含被取消的剩余项。")
	assert_eq(GFVariantData.get_option_array(result, "completion_order").size(), 2, "完成顺序应包含被自动取消的剩余项。")


func test_async_flow_wait_completions_reports_timeout() -> void:
	var pending_completion: GFAsyncCompletion = GFAsyncCompletion.new()

	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"pending": pending_completion,
	}, {
		"timeout_seconds": 0.01,
		"tree": get_tree(),
		"cancel_remaining_on_finish": true,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "等待超时时组合等待不应成功。")
	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncFlowTools.STATUS_CANCELLED, "等待超时应以取消状态返回。")
	assert_true(GFVariantData.get_option_bool(result, "timed_out"), "报告应标记 timed_out。")
	assert_true(pending_completion.is_cancelled(), "请求取消剩余项时，超时应取消仍 pending 的 completion。")


func test_async_flow_wait_completions_zero_timeout_means_no_timeout() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	call_deferred("_complete_one_success", completion)
	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"next_frame": completion,
	}, {
		"timeout_seconds": 0.0,
		"tree": get_tree(),
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "timeout_seconds 为 0 时不应创建立即取消的等待源。")
	assert_false(GFVariantData.get_option_bool(result, "timed_out"), "禁用超时时不应报告 timed_out。")


func test_async_flow_requires_worker_completion_to_use_main_thread_dispatch_queue() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var dispatch_queue: GFMainThreadDispatchQueue = GFMainThreadDispatchQueue.new()
	var worker_state: Dictionary = {}
	dispatch_queue.init()

	call_deferred(
		"_route_completion_from_worker",
		completion,
		dispatch_queue,
		worker_state
	)
	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"worker": completion,
	}, {
		"timeout_seconds": 1.0,
		"tree": get_tree(),
	})

	assert_false(
		GFVariantData.get_option_bool(worker_state, "direct_completion"),
		"worker 直接终结 completion 必须 fail closed。"
	)
	assert_gt(
		GFVariantData.get_option_int(worker_state, "dispatch_handle"),
		0,
		"worker 应能把主线程终态提交加入显式调度队列。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(worker_state, "dispatch_status"),
		GFMainThreadDispatchQueue.STATUS_COMPLETED,
		"显式主线程派发应成功执行终态提交。"
	)
	assert_true(GFVariantData.get_option_bool(result, "ok"), "主线程终态信号应进入有界通道。")
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(result, "value"),
			&"worker"
		),
		"worker_ready",
		"主线程调度不得改变 completion 结果。"
	)
	assert_push_error_count(1, "worker 直接终结 completion 应报告一次线程契约错误。")


func test_async_flow_rejects_worker_emitted_terminal_signal() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	call_deferred("_emit_completion_signal_from_worker", completion)
	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"spoofed_worker": completion,
	}, {
		"timeout_seconds": 0.02,
		"tree": get_tree(),
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_true(GFVariantData.get_option_bool(result, "timed_out"))
	assert_true(completion.is_pending(), "伪造 worker signal 不得改变 completion 状态。")
	assert_true(
		GFVariantData.get_option_array(result, "completion_order").is_empty(),
		"非主线程终态 signal 不得进入 bounded channel。"
	)


func test_async_flow_wait_completions_rejects_oversized_input() -> void:
	var first: GFAsyncCompletion = GFAsyncCompletion.new()
	var second: GFAsyncCompletion = GFAsyncCompletion.new()

	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"first": first,
		&"second": second,
	}, {
		"max_completions": 1,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "超出组合等待预算时必须 fail closed。")
	assert_eq(
		GFVariantData.get_option_string_name(result, "status"),
		GFAsyncFlowTools.STATUS_FAILED,
		"超限输入应返回稳定失败状态。"
	)
	assert_eq(GFVariantData.get_option_int(result, "input_count"), 2, "报告应包含实际输入规模。")
	assert_eq(GFVariantData.get_option_int(result, "max_completions"), 1, "报告应包含生效预算。")
	assert_true(first.is_pending() and second.is_pending(), "拒绝输入不得连接、完成或取消调用方 completion。")


func test_async_flow_rejects_completion_budget_above_absolute_limit() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	var result: Dictionary = await GFAsyncFlowTools.wait_all_completions_async({
		&"only": completion,
	}, {
		"max_completions": GFAsyncFlowTools.ABSOLUTE_MAX_COMPLETIONS + 1,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		GFVariantData.get_option_int(result, "absolute_max_completions"),
		GFAsyncFlowTools.ABSOLUTE_MAX_COMPLETIONS
	)
	assert_true(
		completion.is_pending(),
		"非法伪有界预算必须在连接 completion 信号前失败。"
	)


func _complete_two_successes(profile: GFAsyncCompletion, inventory: GFAsyncCompletion) -> void:
	var _profile_completed: bool = profile.succeed("profile_ready")
	var _inventory_completed: bool = inventory.succeed("inventory_ready")


func _complete_one_success(completion: GFAsyncCompletion) -> void:
	var _completed: bool = completion.succeed("fast_ready")


func _route_completion_from_worker(
	completion: GFAsyncCompletion,
	dispatch_queue: GFMainThreadDispatchQueue,
	worker_state: Dictionary
) -> void:
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(self, &"_post_completion_from_worker").bind(
			completion,
			dispatch_queue
		)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	if start_error == OK:
		var worker_value: Variant = worker.wait_to_finish()
		var worker_result: Dictionary = GFVariantData.as_dictionary(worker_value)
		worker_state["direct_completion"] = GFVariantData.get_option_bool(
			worker_result,
			"direct_completion"
		)
		worker_state["dispatch_handle"] = GFVariantData.get_option_int(
			worker_result,
			"dispatch_handle"
		)
		var dispatch_report: Dictionary = dispatch_queue.dispatch(1)
		worker_state["dispatch_status"] = GFVariantData.get_option_string_name(
			dispatch_report,
			"status"
		)


func _post_completion_from_worker(
	completion: GFAsyncCompletion,
	dispatch_queue: GFMainThreadDispatchQueue
) -> Dictionary:
	var direct_completion: bool = completion.succeed("worker_rejected")
	var dispatch_handle: int = dispatch_queue.post(
		Callable(completion, &"succeed").bind("worker_ready"),
		{ "label": "complete_async_flow" }
	)
	return {
		"direct_completion": direct_completion,
		"dispatch_handle": dispatch_handle,
	}


func _emit_completion_signal_from_worker(completion: GFAsyncCompletion) -> void:
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		func() -> void:
			completion.completed.emit(completion)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	if start_error == OK:
		var _worker_result: Variant = worker.wait_to_finish()
