## 测试 GFQuietWindowCoalescer 的按 key 静默窗口合并行为。
extends GutTest


# --- 常量 ---

const GF_QUIET_WINDOW_COALESCER_SCRIPT = preload("res://addons/gf/standard/common/gf_quiet_window_coalescer.gd")


# --- 测试方法 ---

func test_quiet_window_extends_after_each_message_and_emits_one_batch() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.quiet_window_msec = 100
	coalescer.max_window_msec = 500

	var _chat_batch_id: int = coalescer.submit_at(&"chat", "one", 1000)
	var _same_chat_batch_id: int = coalescer.submit_at(&"chat", "two", 1090)

	assert_true(coalescer.flush_ready(1189).is_empty(), "最后一条消息后的静默窗口结束前不得发出批次。")
	var reports: Array[Dictionary] = coalescer.flush_ready(1190)
	var report: Dictionary = reports[0]

	assert_eq(reports.size(), 1, "静默窗口结束时只应关闭一个批次。")
	assert_eq(GFVariantData.get_option_string(report, "key"), "chat", "批次应保留稳定 key。")
	assert_eq(GFVariantData.get_option_array(report, "messages"), ["one", "two"], "消息应保持到达顺序。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "quiet_window", "关闭原因应可诊断。")


func test_quiet_window_max_window_prevents_continuous_stream_from_growing_forever() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.quiet_window_msec = 100
	coalescer.max_window_msec = 250

	var _stream_batch_id: int = coalescer.submit_at(&"stream", 1, 1000)
	var _same_stream_batch_id_2: int = coalescer.submit_at(&"stream", 2, 1090)
	var _same_stream_batch_id_3: int = coalescer.submit_at(&"stream", 3, 1180)
	var _same_stream_batch_id_4: int = coalescer.submit_at(&"stream", 4, 1240)
	var reports: Array[Dictionary] = coalescer.flush_ready(1250)

	assert_eq(reports.size(), 1, "持续消息应在最大窗口到达时强制关闭。")
	assert_eq(GFVariantData.get_option_string(reports[0], "reason"), "max_window", "报告应区分最大窗口关闭。")
	assert_eq(GFVariantData.get_option_int(reports[0], "message_count"), 4, "最大窗口关闭前的消息都应进入同一批。")


func test_quiet_window_supports_project_owned_merge_callback_and_batch_limit() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_messages_per_batch = 2
	coalescer.merge_callback = func(key: StringName, messages: Array) -> Variant:
		return {
			"channel": String(key),
			"text": " ".join(PackedStringArray(messages)),
		}
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听 batch_closed。")

	var _dialogue_batch_id: int = coalescer.submit_at(&"dialogue", "hello", 1000)
	var _same_dialogue_batch_id: int = coalescer.submit_at(&"dialogue", "world", 1001)
	var merged: Dictionary = GFVariantData.get_option_dictionary(emitted[0], "merged_value")

	assert_eq(emitted.size(), 1, "达到消息上限时应立即关闭批次。")
	assert_eq(GFVariantData.get_option_string(emitted[0], "reason"), "batch_limit", "批次上限应有稳定原因。")
	assert_eq(GFVariantData.get_option_string(merged, "channel"), "dialogue", "合并回调应收到 key。")
	assert_eq(GFVariantData.get_option_string(merged, "text"), "hello world", "合并语义应由项目回调决定。")


func test_zero_quiet_window_auto_flushes_without_retaining_a_timer_batch() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.quiet_window_msec = 0
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听零窗口批次。")

	var _immediate_batch_id: int = coalescer.submit(&"immediate", { "value": 1 })

	assert_eq(emitted.size(), 1, "零静默窗口应在提交调用内关闭批次。")
	assert_eq(coalescer.get_pending_batch_count(), 0, "零窗口不得留下待处理计时批次。")
	assert_eq(GFVariantData.get_option_string(emitted[0], "reason"), "quiet_window", "零窗口仍应使用稳定关闭原因。")


func test_pending_key_limit_closes_oldest_batch_before_opening_new_key() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_pending_batches = 2
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听容量关闭批次。")

	var _first_batch_id: int = coalescer.submit_at(&"first", 1, 1000)
	var _second_batch_id: int = coalescer.submit_at(&"second", 2, 1001)
	var _third_batch_id: int = coalescer.submit_at(&"third", 3, 1002)

	assert_eq(coalescer.get_pending_batch_count(), 2, "同时打开的 key 数不得超过上限。")
	assert_eq(emitted.size(), 1, "打开第三个 key 前应关闭一个旧批次。")
	assert_eq(GFVariantData.get_option_string(emitted[0], "key"), "first", "容量压力应先关闭最早批次。")
	assert_eq(GFVariantData.get_option_string(emitted[0], "reason"), "pending_limit", "容量关闭应有稳定原因。")


func test_reducing_pending_limit_closes_surplus_batches_immediately() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_pending_batches = 3
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听运行时容量收缩。")

	var _first_batch_id: int = coalescer.submit_at(&"first", 1, 1000)
	var _second_batch_id: int = coalescer.submit_at(&"second", 2, 1001)
	var _third_batch_id: int = coalescer.submit_at(&"third", 3, 1002)
	coalescer.max_pending_batches = 1

	assert_eq(coalescer.get_pending_batch_count(), 1, "降低容量后应立即收缩到新上限。")
	assert_eq(emitted.size(), 0, "容量 setter 不应同步派发全部收缩通知。")
	var _fourth_batch_id: int = coalescer.submit_at(&"fourth", 4, 1003)
	assert_eq(coalescer.get_pending_batch_count(), 1, "收缩后的后续提交仍不得突破新上限。")
	assert_eq(emitted.size(), 0, "已有积压时的新淘汰通知不得越过 FIFO 同步发出。")
	for _frame_index: int in range(10):
		if emitted.size() >= 3:
			break
		await get_tree().process_frame
	assert_eq(emitted.size(), 3, "降低容量与同帧后续淘汰通知应按帧预算完整送达。")
	var first_report: Dictionary = emitted[0] if emitted.size() > 0 else {}
	var second_report: Dictionary = emitted[1] if emitted.size() > 1 else {}
	var third_report: Dictionary = emitted[2] if emitted.size() > 2 else {}
	assert_eq(GFVariantData.get_option_string(first_report, "key"), "first", "容量收缩应先关闭最早批次。")
	assert_eq(GFVariantData.get_option_string(second_report, "key"), "second", "容量收缩应按稳定顺序继续关闭。")
	assert_eq(GFVariantData.get_option_string(third_report, "key"), "third", "同帧后续淘汰不得越过已有通知。")


func test_pending_limit_reserves_target_before_reentrant_same_key_submit() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_pending_batches = 2
	var callback_state: Dictionary = { "reentered": false }
	var on_batch_closed: Callable = func(report: Dictionary) -> void:
		if (
			GFVariantData.get_option_string(report, "reason") == "pending_limit"
			and not GFVariantData.get_option_bool(callback_state, "reentered")
		):
			callback_state["reentered"] = true
			var _reentrant_batch_id: int = coalescer.submit_at(&"target", "callback", 1002)
	var connect_error: Error = coalescer.batch_closed.connect(on_batch_closed) as Error
	assert_eq(connect_error, OK, "测试应能监听同 key 重入提交。")

	var _first_batch_id: int = coalescer.submit_at(&"first", 1, 1000)
	var _second_batch_id: int = coalescer.submit_at(&"second", 2, 1001)
	var target_batch_id: int = coalescer.submit_at(&"target", "outer", 1002)
	var target_report: Dictionary = coalescer.flush(&"target")

	assert_gt(target_batch_id, 0, "外层提交应获得稳定批次 ID。")
	assert_eq(coalescer.get_pending_batch_count(), 1, "关闭目标批次后应只保留未被淘汰的批次。")
	assert_eq(
		GFVariantData.get_option_array(target_report, "messages"),
		["outer", "callback"],
		"容量回调提交到目标 key 时不得覆盖或丢失任一消息。"
	)
	coalescer.batch_closed.disconnect(on_batch_closed)


func test_pending_limit_defers_reentrant_capacity_notifications() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_pending_batches = 1
	var callback_state: Dictionary = { "notification_count": 0 }
	var on_batch_closed: Callable = func(report: Dictionary) -> void:
		if GFVariantData.get_option_string(report, "reason") != "pending_limit":
			return
		var notification_count: int = GFVariantData.get_option_int(
			callback_state,
			"notification_count"
		) + 1
		callback_state["notification_count"] = notification_count
		if notification_count < 3:
			var reentrant_key: StringName = StringName("reentrant_%d" % notification_count)
			var _reentrant_batch_id: int = coalescer.submit_at(
				reentrant_key,
				notification_count,
				1000 + notification_count
			)
	var connect_error: Error = coalescer.batch_closed.connect(on_batch_closed) as Error
	assert_eq(connect_error, OK, "测试应能监听容量通知重入。")

	var _initial_batch_id: int = coalescer.submit_at(&"initial", 0, 1000)
	var _outer_batch_id: int = coalescer.submit_at(&"outer", 1, 1001)

	assert_eq(
		GFVariantData.get_option_int(callback_state, "notification_count"),
		1,
		"一次提交只能同步派发最外层容量通知。"
	)
	assert_eq(coalescer.get_pending_batch_count(), 1, "回调重入后仍必须遵守待处理批次数量上限。")
	for _frame_index: int in range(10):
		if GFVariantData.get_option_int(callback_state, "notification_count") >= 3:
			break
		await get_tree().process_frame
	assert_eq(
		GFVariantData.get_option_int(callback_state, "notification_count"),
		3,
		"重入产生的容量通知应在后续 idle 周期完整送达。"
	)
	assert_eq(coalescer.get_pending_batch_count(), 1, "延迟派发完成后仍必须遵守容量上限。")
	coalescer.batch_closed.disconnect(on_batch_closed)


func test_capacity_notification_budget_spans_multiple_process_frames() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.auto_flush = false
	coalescer.max_pending_batches = 1
	var emission_frames: Array[int] = []
	var on_batch_closed: Callable = func(report: Dictionary) -> void:
		if GFVariantData.get_option_string(report, "reason") != "pending_limit":
			return
		emission_frames.append(Engine.get_process_frames())
		if emission_frames.size() != 1:
			return
		for index: int in range(70):
			var reentrant_key: StringName = StringName("bulk_%d" % index)
			var _reentrant_batch_id: int = coalescer.submit_at(
				reentrant_key,
				index,
				1002 + index
			)
	var connect_error: Error = coalescer.batch_closed.connect(on_batch_closed) as Error
	assert_eq(connect_error, OK, "测试应能监听跨帧容量通知。")

	var _initial_batch_id: int = coalescer.submit_at(&"initial", 0, 1000)
	var _outer_batch_id: int = coalescer.submit_at(&"outer", 1, 1001)
	assert_eq(emission_frames.size(), 1, "批量重入不得在外层提交调用栈内递归派发。")

	for _frame_index: int in range(10):
		if emission_frames.size() >= 71:
			break
		await get_tree().process_frame
	assert_eq(emission_frames.size(), 71, "70 条延迟容量通知最终都应送达。")
	assert_eq(coalescer.get_pending_batch_count(), 1, "跨帧派发期间仍必须维持严格容量上限。")

	var counts_by_frame: Dictionary = {}
	var max_notifications_in_frame: int = 0
	for frame_index: int in emission_frames:
		var frame_count: int = GFVariantData.get_option_int(counts_by_frame, frame_index) + 1
		counts_by_frame[frame_index] = frame_count
		max_notifications_in_frame = maxi(max_notifications_in_frame, frame_count)
	assert_gte(counts_by_frame.size(), 3, "首层通知与 70 条积压至少应分布在三个 process frame。")
	assert_lte(max_notifications_in_frame, 64, "任一 process frame 不得派发超过固定容量预算。")
	coalescer.batch_closed.disconnect(on_batch_closed)


func test_nonzero_auto_flush_closes_batch_exactly_once() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.quiet_window_msec = 10
	coalescer.max_window_msec = 0
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听自动关闭批次。")

	var _auto_batch_id: int = coalescer.submit(&"auto", "message")
	await _wait_until_batch_count(emitted, 1)
	await _wait_real_msec(20)

	assert_eq(emitted.size(), 1, "非零静默窗口到期后只应关闭一次。")
	assert_eq(coalescer.get_pending_batch_count(), 0, "自动关闭后不应残留批次。")
	assert_eq(GFVariantData.get_option_string(emitted[0], "reason"), "quiet_window", "自动关闭应报告静默窗口原因。")


func test_switching_auto_flush_rearms_existing_batch_without_stale_close() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.quiet_window_msec = 15
	coalescer.max_window_msec = 0
	var emitted: Array[Dictionary] = []
	var connect_error: Error = coalescer.batch_closed.connect(func(report: Dictionary) -> void:
		emitted.append(report)
	) as Error
	assert_eq(connect_error, OK, "测试应能监听动态自动关闭批次。")

	var _toggle_batch_id: int = coalescer.submit(&"toggle", 1)
	coalescer.auto_flush = false
	await _wait_real_msec(40)

	assert_eq(emitted.size(), 0, "关闭 auto_flush 后旧计时任务不得迟到关闭批次。")
	assert_eq(coalescer.get_pending_batch_count(), 1, "关闭自动推进时应保留待处理批次。")

	coalescer.auto_flush = true
	await get_tree().process_frame

	assert_eq(emitted.size(), 1, "重新启用 auto_flush 应立即处理已经到期的批次。")
	assert_eq(coalescer.get_pending_batch_count(), 0, "重新启用后不应残留已到期批次。")


func test_cancel_clear_and_flush_all_are_bounded_against_late_or_reentrant_timers() -> void:
	var coalescer: GF_QUIET_WINDOW_COALESCER_SCRIPT = GF_QUIET_WINDOW_COALESCER_SCRIPT.new()
	coalescer.quiet_window_msec = 10
	var emitted: Array[Dictionary] = []
	var on_batch_closed: Callable = func(report: Dictionary) -> void:
		emitted.append(report)
		if GFVariantData.get_option_string(report, "key") == "first":
			var _reentrant_batch_id: int = coalescer.submit(&"reentrant", 3)
	var connect_error: Error = coalescer.batch_closed.connect(on_batch_closed) as Error
	assert_eq(connect_error, OK, "测试应能监听清理与重入边界。")

	var _cancelled_batch_id: int = coalescer.submit(&"cancelled", 0)
	assert_true(coalescer.cancel(&"cancelled"), "已打开批次应可取消。")
	var _cleared_batch_id: int = coalescer.submit(&"cleared", 0)
	coalescer.clear()
	await _wait_real_msec(30)
	assert_eq(emitted.size(), 0, "cancel 与 clear 后迟到计时任务不得发出批次。")

	coalescer.auto_flush = false
	var _manual_first_batch_id: int = coalescer.submit(&"first", 1)
	var _manual_second_batch_id: int = coalescer.submit(&"second", 2)
	var reports: Array[Dictionary] = coalescer.flush_all()

	assert_eq(reports.size(), 2, "flush_all 只应关闭调用开始时存在的两个批次。")
	assert_eq(emitted.size(), 2, "初始批次应各发出一次关闭事件。")
	assert_eq(coalescer.get_pending_batch_count(), 1, "关闭回调重入提交的新批次应留给下一轮处理。")
	var reentrant_report: Dictionary = coalescer.flush(&"reentrant")
	assert_eq(GFVariantData.get_option_string(reentrant_report, "key"), "reentrant", "显式 flush 应关闭重入批次。")
	coalescer.batch_closed.disconnect(on_batch_closed)


func _wait_until_batch_count(
	emitted: Array[Dictionary],
	expected_count: int,
	timeout_msec: int = 500
) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + timeout_msec
	while emitted.size() < expected_count and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame


func _wait_real_msec(duration_msec: int) -> void:
	var deadline_msec: int = Time.get_ticks_msec() + maxi(duration_msec, 0)
	while Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
