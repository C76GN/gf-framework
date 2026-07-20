extends GutTest


# --- 常量 ---

const GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT = preload("res://addons/gf/standard/common/gf_async_progress_aggregator.gd")


# --- 测试方法 ---

func test_cancel_source_cancels_token_once_with_metadata() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var signal_state: Dictionary = {}
	var connect_error: Error = source.get_token().cancel_requested.connect(func(reason: StringName) -> void:
		signal_state["reason"] = reason
		signal_state["metadata"] = source.get_token().get_cancel_metadata()
	) as Error
	assert_eq(connect_error, OK, "测试应能监听 token 取消信号。")

	assert_true(source.cancel(&"user_cancelled", { "scope": "menu" }), "首次取消应成功。")
	assert_false(source.cancel(&"late"), "重复取消不应覆盖第一次状态。")

	var metadata: Dictionary = source.get_token().get_cancel_metadata()
	var emitted_metadata: Dictionary = GFVariantData.get_option_dictionary(signal_state, "metadata")
	assert_true(source.get_token().is_cancel_requested(), "token 应进入取消状态。")
	assert_eq(source.get_token().get_cancel_reason(), &"user_cancelled", "token 应保留首次取消原因。")
	assert_eq(GFVariantData.get_option_string(metadata, "scope"), "menu", "token 应保留取消元数据。")
	assert_eq(GFVariantData.get_option_string_name(signal_state, "reason"), &"user_cancelled", "取消信号应发出原因。")
	assert_eq(GFVariantData.get_option_string(emitted_metadata, "scope"), "menu", "取消信号应复制元数据。")


func test_cancel_source_links_upstream_and_timeout() -> void:
	var upstream: GFCancellationSource = GFCancellationSource.new()
	var linked: GFCancellationSource = GFCancellationSource.create_linked(
		[upstream.get_token()],
		&"linked_cancelled",
		{ "child": true }
	)

	assert_true(upstream.cancel(&"upstream_cancelled", { "origin": "test" }), "上游取消应成功。")

	var linked_metadata: Dictionary = linked.get_token().get_cancel_metadata()
	assert_true(linked.get_token().is_cancel_requested(), "linked source 应跟随上游取消。")
	assert_eq(linked.get_token().get_cancel_reason(), &"linked_cancelled", "linked source 应可覆盖取消原因。")
	assert_eq(GFVariantData.get_option_string(linked_metadata, "origin"), "test", "linked source 应保留上游元数据。")
	assert_true(GFVariantData.get_option_bool(linked_metadata, "child"), "linked source 应合并本地元数据。")

	var timeout_source: GFCancellationSource = GFCancellationSource.new()
	assert_true(timeout_source.cancel_after_seconds(0.01, get_tree()), "应能设置 SceneTree 超时取消。")
	await timeout_source.get_token().cancel_requested

	assert_true(timeout_source.get_token().is_cancel_requested(), "超时后 token 应取消。")
	assert_eq(timeout_source.get_token().get_cancel_reason(), &"timeout", "默认超时原因应为 timeout。")


func test_cancel_source_tracks_node_lifetime() -> void:
	var node: Node = Node.new()
	add_child(node)
	var source: GFCancellationSource = GFCancellationSource.new()

	assert_true(source.cancel_when_node_exits(node, &"owner_released"), "应能绑定节点离树取消。")
	node.queue_free()
	await get_tree().process_frame

	assert_true(source.is_cancel_requested(), "节点离树后 source 应取消。")
	assert_eq(source.get_token().get_cancel_reason(), &"owner_released", "节点生命周期取消应保留原因。")


func test_async_completion_succeeds_once_and_binds_cancel_token() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var signal_state: Dictionary = {}
	var connect_error: Error = completion.succeeded.connect(func(success_result: Variant, success_metadata: Dictionary) -> void:
		signal_state["result"] = success_result
		signal_state["metadata"] = success_metadata.duplicate(true)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听成功信号。")

	assert_true(completion.succeed({ "value": 3 }, { "phase": "load" }), "首次成功应进入终态。")
	assert_false(completion.fail("late"), "终态完成源不应再次失败。")

	var result: Dictionary = GFVariantData.as_dictionary(completion.get_result())
	var emitted_metadata: Dictionary = GFVariantData.get_option_dictionary(signal_state, "metadata")
	assert_true(completion.is_successful(), "完成源应标记为 successful。")
	assert_eq(GFVariantData.get_option_int(result, "value"), 3, "完成源应保留成功结果。")
	assert_eq(GFVariantData.get_option_string(emitted_metadata, "phase"), "load", "成功信号应携带元数据。")
	assert_eq(completion.get_cancel_reason(), &"", "成功完成源不应带 cancelled 取消原因。")

	var source: GFCancellationSource = GFCancellationSource.new()
	var cancelled_completion: GFAsyncCompletion = GFAsyncCompletion.new()
	assert_true(cancelled_completion.bind_cancel_token(source.get_token()), "完成源应能绑定取消 token。")
	assert_true(source.cancel(&"timeout"), "source 取消应成功。")
	assert_true(cancelled_completion.is_cancelled(), "token 取消后完成源应取消。")
	assert_eq(cancelled_completion.get_cancel_reason(), &"timeout", "完成源应保留 token 取消原因。")


func test_async_completion_failure_does_not_report_cancel_reason() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	assert_true(completion.fail("broken"), "失败完成源应进入终态。")

	assert_true(completion.is_failed(), "完成源应标记为 failed。")
	assert_eq(completion.get_error(), "broken", "失败完成源应保留错误文本。")
	assert_eq(completion.get_cancel_reason(), &"", "失败完成源不应带 cancelled 取消原因。")


func test_async_wait_utility_wait_completion_reports_timeout_without_completion() -> void:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	var result: Dictionary = await GFAsyncWaitUtility.wait_completion_async(completion, {
		"tree": get_tree(),
		"timeout_seconds": 0.01,
	})

	assert_true(completion.is_pending(), "等待超时不应把完成源改成终态。")
	assert_eq(GFVariantData.get_option_string_name(result, "wait_status"), GFAsyncWaitUtility.STATUS_TIMEOUT, "完成源等待超时应报告 wait_status。")


func test_async_wait_utility_captures_payload_and_times_out() -> void:
	var emitter: PayloadEmitter = PayloadEmitter.new()
	add_child_autofree(emitter)

	emitter.call_deferred("emit_payload_ready")
	var result: Dictionary = await GFAsyncWaitUtility.await_signal_payload(emitter.payload_ready, {
		"timeout_seconds": 1.0,
	})
	var args: Array = GFVariantData.get_option_array(result, "args")

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "Signal 发出后等待应成功。")
	assert_eq(args, [7, "ready"], "等待工具应捕获 Signal payload。")

	var timeout_result: Dictionary = await GFAsyncWaitUtility.await_signal(emitter.payload_ready, {
		"timeout_seconds": 0.01,
	})
	assert_eq(GFVariantData.get_option_string_name(timeout_result, "status"), GFAsyncWaitUtility.STATUS_TIMEOUT, "未发出 Signal 时应超时。")
	assert_true(GFVariantData.get_option_bool(timeout_result, "timed_out"), "超时结果应标记 timed_out。")


func test_async_wait_utility_delegates_signal_control_flow_to_support() -> void:
	var source: String = _read_text_file("res://addons/gf/standard/common/gf_async_wait_utility.gd")

	assert_true(source.contains("await_signal_state(result_signal"), "公共等待工具应委托 GFAsyncWaitSupport 处理 Signal 等待。")
	assert_false(source.contains("static func _wait_loop("), "公共等待工具不应保留重复 Signal 等待循环。")
	assert_false(source.contains("static func _make_signal_capture_callable("), "公共等待工具不应保留重复 Signal payload 捕获器。")


func test_async_wait_utility_reports_target_tree_exit() -> void:
	var emitter: PayloadEmitter = PayloadEmitter.new()
	add_child(emitter)
	var state: Dictionary = {}
	var wait_callable: Callable = func() -> void:
		state["result"] = await GFAsyncWaitUtility.await_signal(emitter.payload_ready, {
			"tree": get_tree(),
			"timeout_seconds": 1.0,
		})

	@warning_ignore("missing_await")
	wait_callable.call()
	await get_tree().process_frame
	emitter.queue_free()
	await get_tree().process_frame

	var result: Dictionary = GFVariantData.get_option_dictionary(state, "result")
	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_INVALID, "目标离树应返回 invalid。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"target_exited", "目标离树应给出稳定原因。")


func test_async_wait_utility_reports_guard_tree_exit() -> void:
	var emitter: PayloadEmitter = PayloadEmitter.new()
	var guard: Node = Node.new()
	add_child_autofree(emitter)
	add_child(guard)
	var timer: SceneTreeTimer = get_tree().create_timer(0.01)
	var _connect_result: Error = timer.timeout.connect(func() -> void:
		guard.queue_free()
	) as Error

	assert_eq(_connect_result, OK, "测试应能延迟释放 guard。")
	var result: Dictionary = await GFAsyncWaitUtility.await_signal(emitter.payload_ready, {
		"guard_node": guard,
		"tree": get_tree(),
		"timeout_seconds": 1.0,
	})
	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_INVALID, "guard 离树应返回 invalid。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"guard_exited", "guard 离树应给出稳定原因。")


func test_timeout_controller_reuses_token_and_reports_timeout() -> void:
	var controller: GFTimeoutController = GFTimeoutController.new()
	var timeout_events: Array[StringName] = []
	var connect_error: Error = controller.timed_out.connect(func(reason: StringName, _metadata: Dictionary) -> void:
		timeout_events.append(reason)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听超时信号。")

	var token: GFCancellationToken = controller.start_seconds(0.01, get_tree(), &"operation_timeout", { "scope": "load" })
	await token.cancel_requested

	var metadata: Dictionary = token.get_cancel_metadata()
	assert_true(controller.is_timeout(), "超时控制器应记录最近一次取消来自超时。")
	assert_false(controller.is_active(), "超时触发后不应保持 active。")
	assert_eq(token.get_cancel_reason(), &"operation_timeout", "超时 token 应保留原因。")
	assert_eq(GFVariantData.get_option_string(metadata, "scope"), "load", "超时 token 应保留元数据。")
	assert_eq(timeout_events, [&"operation_timeout"], "超时信号应只发出一次。")

	var reset_token: GFCancellationToken = controller.reset()
	assert_false(reset_token.is_cancel_requested(), "reset 后应换成未取消 token。")

	var stopped_token: GFCancellationToken = controller.start_seconds(0.01, get_tree())
	controller.stop()
	await get_tree().create_timer(0.03).timeout
	assert_false(stopped_token.is_cancel_requested(), "stop 应移除超时计划但不取消 token。")
	controller.dispose()


func test_timeout_controller_elapsed_time_uses_injected_clock() -> void:
	var clock: GFManualClock = GFManualClock.new(0, 1700000000000)
	var controller: GFTimeoutController = GFTimeoutController.new(clock)
	var _token: GFCancellationToken = controller.start_seconds(0.01, get_tree())

	assert_true(clock.advance_msec(125), "测试时钟应确定推进。")
	assert_eq(controller.get_elapsed_msec(), 125, "耗时统计应使用注入的单调时钟。")
	assert_false(controller.set_clock(GFManualClock.new()), "活动计划期间不得替换时钟。")

	controller.stop()
	await get_tree().create_timer(0.02).timeout
	var replacement: GFManualClock = GFManualClock.new(500000, 1700000000500)
	assert_true(controller.set_clock(replacement), "停止计划后应能替换时钟。")
	assert_same(controller.get_clock(), replacement, "控制器应持有替换后的时钟。")
	controller.dispose()


func test_async_wait_utility_waits_for_frames_delay_and_predicates() -> void:
	var next_result: Dictionary = await GFAsyncWaitUtility.next_frame({ "tree": get_tree() })
	assert_eq(GFVariantData.get_option_string_name(next_result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "next_frame 应完成。")

	var delay_result: Dictionary = await GFAsyncWaitUtility.delay_seconds(0.01, {
		"tree": get_tree(),
		"respect_time_scale": false,
	})
	assert_eq(GFVariantData.get_option_string_name(delay_result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "delay_seconds 应在指定时间后完成。")

	var state: Dictionary = {
		"ready": false,
		"busy": true,
	}
	var ready_timer: SceneTreeTimer = get_tree().create_timer(0.01)
	var _ready_connect: Error = ready_timer.timeout.connect(func() -> void:
		state["ready"] = true
	) as Error
	var until_result: Dictionary = await GFAsyncWaitUtility.wait_until(func() -> bool:
		return GFVariantData.get_option_bool(state, "ready")
	, { "tree": get_tree(), "timeout_seconds": 1.0 })
	assert_eq(GFVariantData.get_option_string_name(until_result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "wait_until 应等待条件为 true。")

	var busy_timer: SceneTreeTimer = get_tree().create_timer(0.01)
	var _busy_connect: Error = busy_timer.timeout.connect(func() -> void:
		state["busy"] = false
	) as Error
	var while_result: Dictionary = await GFAsyncWaitUtility.wait_while(func() -> bool:
		return GFVariantData.get_option_bool(state, "busy")
	, { "tree": get_tree(), "timeout_seconds": 1.0 })
	assert_eq(GFVariantData.get_option_string_name(while_result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "wait_while 应等待条件为 false。")


func test_async_wait_utility_detects_value_changes() -> void:
	var state: Dictionary = {
		"value": 1,
	}
	var timer: SceneTreeTimer = get_tree().create_timer(0.01)
	var _connect: Error = timer.timeout.connect(func() -> void:
		state["value"] = 2
	) as Error

	var result: Dictionary = await GFAsyncWaitUtility.wait_until_value_changed(func() -> int:
		return GFVariantData.get_option_int(state, "value")
	, { "tree": get_tree(), "timeout_seconds": 1.0 })

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_COMPLETED, "值变化后等待应完成。")
	assert_eq(GFVariantData.get_option_int(result, "previous_value"), 1, "结果应包含旧值。")
	assert_eq(GFVariantData.get_option_int(result, "value"), 2, "结果应包含新值。")


func test_async_wait_utility_checks_cancel_before_immediate_delay() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var _cancelled: bool = source.cancel(&"already_cancelled")

	var result: Dictionary = await GFAsyncWaitUtility.delay_seconds(0.0, {
		"tree": get_tree(),
		"cancel_token": source.get_token(),
	})

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_CANCELLED, "已取消 token 应优先于立即 delay 完成。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"already_cancelled", "取消结果应保留 token 原因。")


func test_async_wait_utility_checks_cancel_before_value_getter() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var getter_calls: Array[int] = []
	var _cancelled: bool = source.cancel(&"already_cancelled")

	var result: Dictionary = await GFAsyncWaitUtility.wait_until_value_changed(func() -> int:
		getter_calls.append(1)
		return getter_calls.size()
	, {
		"tree": get_tree(),
		"cancel_token": source.get_token(),
	})

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GFAsyncWaitUtility.STATUS_CANCELLED, "已取消 token 应阻止 value getter 执行。")
	assert_true(getter_calls.is_empty(), "取消已发生时不应调用 getter。")


func test_async_channel_reads_written_items_and_closed_state() -> void:
	var channel: GFAsyncChannel = GFAsyncChannel.new()
	assert_true(channel.try_write({ "id": 1 }), "打开通道应允许写入。")

	var first_read: Dictionary = await channel.read_async({ "tree": get_tree() })
	var first_item: Dictionary = GFVariantData.get_option_dictionary(first_read, "item")
	assert_eq(GFVariantData.get_option_string_name(first_read, "status"), GFAsyncChannel.STATUS_COMPLETED, "已缓冲数据应立即读出。")
	assert_eq(GFVariantData.get_option_int(first_item, "id"), 1, "读取结果应包含写入数据。")

	var delayed_channel: GFAsyncChannel = GFAsyncChannel.new()
	var timer: SceneTreeTimer = get_tree().create_timer(0.01)
	var _connect: Error = timer.timeout.connect(func() -> void:
		var _written: bool = delayed_channel.try_write("later")
	) as Error
	var delayed_read: Dictionary = await delayed_channel.read_async({
		"tree": get_tree(),
		"timeout_seconds": 1.0,
	})
	assert_eq(GFVariantData.get_option_string_name(delayed_read, "status"), GFAsyncChannel.STATUS_COMPLETED, "异步写入后 read_async 应恢复。")
	assert_eq(GFVariantData.get_option_string(delayed_read, "item"), "later", "read_async 应返回异步写入数据。")

	assert_true(delayed_channel.close(&"drained", { "done": true }), "通道应能关闭。")
	var closed_read: Dictionary = await delayed_channel.read_async({ "tree": get_tree() }, "fallback")
	var closed_metadata: Dictionary = GFVariantData.get_option_dictionary(closed_read, "metadata")
	assert_eq(GFVariantData.get_option_string_name(closed_read, "status"), GFAsyncChannel.STATUS_CLOSED, "关闭且无缓冲时读取应返回 closed。")
	assert_true(GFVariantData.get_option_bool(closed_read, "closed"), "关闭读取结果应标记 closed。")
	assert_true(GFVariantData.get_option_bool(closed_metadata, "done"), "关闭元数据应保留。")
	assert_false(delayed_channel.try_write("late"), "关闭后不应继续写入。")


func test_async_progress_emits_only_meaningful_changes() -> void:
	var progress: GFAsyncProgress = GFAsyncProgress.new()
	progress.min_delta = 0.25
	var values: Array[float] = []
	var connect_error: Error = progress.progressed.connect(func(value: float, _message: String, _metadata: Dictionary) -> void:
		values.append(value)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听进度信号。")

	assert_true(progress.update(0.1, "start"), "首次更新应发出信号。")
	assert_false(progress.update(0.2, "start"), "小于 min_delta 且消息不变时不应发出信号。")
	assert_true(progress.update(0.2, "decode"), "消息变化时应允许发出信号。")
	assert_true(progress.update(0.55, "decode"), "超过 min_delta 时应发出信号。")
	assert_true(progress.complete("done"), "complete 应强制发出 1.0。")

	assert_eq(values, [0.1, 0.2, 0.55, 1.0], "进度信号应只包含有意义的变化。")


func test_async_progress_aggregator_combines_weighted_tasks() -> void:
	var aggregator: GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT = GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT.new()
	var emitted_values: Array[float] = []
	var emitted_metadata: Array[Dictionary] = []
	var connect_error: Error = aggregator.progressed.connect(func(value: float, _message: String, metadata: Dictionary) -> void:
		emitted_values.append(value)
		emitted_metadata.append(metadata.duplicate(true))
	) as Error
	assert_eq(connect_error, OK, "测试应能监听聚合进度信号。")

	var bundle_index: int = aggregator.add_task(&"bundle", 1.0, { "kind": "bundle" })
	var resources_index: int = aggregator.add_task(&"resources", 3.0)

	assert_eq(aggregator.get_task_count(), 2, "聚合器应记录全部子任务。")
	assert_almost_eq(aggregator.get_total_progress(), 0.0, 0.001, "两个未完成任务的总进度应为 0。")
	assert_true(aggregator.set_task_progress(bundle_index, 1.0, "bundle"), "完成低权重任务应发布总进度。")
	assert_almost_eq(aggregator.get_total_progress(), 0.25, 0.001, "总进度应按权重计算。")
	assert_true(aggregator.set_task_fraction(resources_index, 1.0, 2.0, "resources"), "分数进度应发布总进度。")
	assert_almost_eq(aggregator.get_total_progress(), 0.625, 0.001, "分数进度应折算为权重进度。")
	assert_true(aggregator.complete_task_by_key(&"resources", "done"), "通过 key 完成任务应发布总进度。")
	assert_almost_eq(aggregator.get_total_progress(), 1.0, 0.001, "全部任务完成后总进度应为 1。")
	assert_true(aggregator.is_complete(), "总进度 1.0 时应视为完成。")
	assert_true(emitted_values.size() >= 3, "任务更新应产生聚合进度事件。")
	assert_almost_eq(emitted_values[emitted_values.size() - 1], 1.0, 0.001, "最后一次事件应报告完成。")
	var last_metadata: Dictionary = emitted_metadata[emitted_metadata.size() - 1]
	assert_eq(GFVariantData.get_option_int(last_metadata, "task_index"), resources_index, "事件元数据应包含最近任务索引。")


func test_async_progress_aggregator_is_monotonic_by_default() -> void:
	var aggregator: GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT = GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT.new()
	var task_index: int = aggregator.add_task(&"load")

	assert_true(aggregator.set_task_progress(task_index, 0.8), "首次任务进度应更新。")
	assert_false(aggregator.set_task_progress(task_index, 0.3), "默认不应接受任务进度回退。")
	assert_almost_eq(aggregator.get_total_progress(), 0.8, 0.001, "回退更新不应改变总进度。")

	aggregator.allow_decrease = true
	assert_true(aggregator.set_task_progress(task_index, 0.3), "显式允许后应接受任务进度回退。")
	assert_almost_eq(aggregator.get_total_progress(), 0.3, 0.001, "允许回退时总进度应同步回退。")


func test_async_progress_aggregator_reuses_keyed_task_and_reports_snapshot() -> void:
	var aggregator: GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT = GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT.new()
	var first_index: int = aggregator.add_task(&"same", 2.0, { "label": "first" })
	var second_index: int = aggregator.add_task(&"same", 3.0)

	assert_eq(second_index, first_index, "重复 key 应复用既有任务索引。")
	assert_true(aggregator.has_task(&"same"), "聚合器应能查询 keyed 任务。")
	assert_eq(aggregator.get_task_index(&"same"), first_index, "key 应映射到原任务索引。")

	var snapshot: Dictionary = aggregator.get_task_snapshot(first_index)
	var snapshot_metadata: Dictionary = GFVariantData.get_option_dictionary(snapshot, "metadata")
	assert_eq(GFVariantData.get_option_string(snapshot_metadata, "label"), "first", "重复 add_task 不应覆盖既有元数据。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "weight"), 2.0, 0.001, "重复 add_task 不应覆盖既有权重。")

	var debug_snapshot: Dictionary = aggregator.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(debug_snapshot, "task_count"), 1, "调试快照应包含任务数量。")
	assert_almost_eq(GFVariantData.get_option_float(debug_snapshot, "total_weight"), 2.0, 0.001, "调试快照应包含总权重。")


func test_async_progress_aggregator_rejects_unstable_keyed_tasks() -> void:
	var aggregator: GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT = GF_ASYNC_PROGRESS_AGGREGATOR_SCRIPT.new()
	var unstable_key: Dictionary = { "id": 1 }

	var rejected_index: int = aggregator.add_task(unstable_key)
	var vector_index: int = aggregator.add_task(Vector2i(1, 2), 1.0)
	var snapshot: Dictionary = aggregator.get_task_snapshot(vector_index)
	var json_text: String = JSON.stringify(snapshot)

	assert_eq(rejected_index, -1, "可变 Dictionary key 不应创建任务。")
	assert_eq(aggregator.get_task_count(), 1, "拒绝无效 key 后只应保留有效任务。")
	assert_false(aggregator.has_task(unstable_key), "无效 key 不应可查询。")
	assert_eq(aggregator.get_task_index(Vector2i(1, 2)), vector_index, "稳定数学 key 应可查询。")
	assert_false(json_text.contains(":null"), "任务快照 key 应可安全 JSON.stringify。")


# --- 私有/辅助方法 ---

func _read_text_file(path: String) -> String:
	var read_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var file: FileAccess = FileAccess.open(read_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取文本文件：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


# --- 内部类 ---

class PayloadEmitter:
	extends Node

	signal payload_ready(value: int, label: String)

	func emit_payload_ready() -> void:
		payload_ready.emit(7, "ready")
