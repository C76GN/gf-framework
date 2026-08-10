extends GutTest

const GF_MANUAL_TIMER_QUEUE_SCRIPT = preload("res://addons/gf/standard/utilities/time/gf_manual_timer_queue.gd")


func test_manual_timer_queue_runs_same_tick_in_stable_order() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var events: Array[String] = []

	var first_handle: int = queue.schedule_at(5, func() -> void:
		events.append("first")
	)
	var front_handle: int = queue.schedule_at(5, func() -> void:
		events.append("front")
	, { "front": true })

	assert_gt(first_handle, 0, "第一个计时器应返回句柄。")
	assert_gt(front_handle, 0, "front 计时器应返回句柄。")
	var report: Dictionary = queue.advance_to(5)

	assert_eq(events, ["front", "first"], "同 tick 下 front 应先执行，普通计时器保持插入顺序。")
	assert_eq(GFVariantData.get_option_int(report, "executed_count"), 2, "推进报告应统计执行数量。")
	assert_eq(queue.get_current_tick(), 5, "推进完成后 current_tick 应到达目标。")


func test_manual_timer_queue_truncates_recursive_same_tick_work() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var events: Array[String] = []

	var first_handle: int = queue.schedule_at(1, func() -> void:
		events.append("first")
		var _second_handle: int = queue.schedule_at(queue.get_current_tick(), func() -> void:
			events.append("second")
		)
	)
	assert_gt(first_handle, 0, "递归计时器测试应能排入第一个回调。")

	var truncated_report: Dictionary = queue.advance_to(1, { "max_callbacks": 1 })
	assert_true(GFVariantData.get_option_bool(truncated_report, "truncated"), "达到最大回调数时应报告 truncated。")
	assert_eq(events, ["first"], "截断时只执行一个回调。")
	assert_eq(queue.get_pending_count(), 1, "递归排队的同 tick 回调应留待下一次推进。")

	var final_report: Dictionary = queue.advance_to(1)
	assert_false(GFVariantData.get_option_bool(final_report, "truncated"), "再次推进应能清空剩余同 tick 回调。")
	assert_eq(events, ["first", "second"], "第二次推进应执行剩余回调。")


func test_manual_timer_queue_rejects_nested_advance_without_time_regression() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var observed_ticks: Array[int] = []
	var nested_reports: Array[Dictionary] = []

	var handle: int = queue.schedule_at(1, func() -> void:
		observed_ticks.append(queue.get_current_tick())
		nested_reports.append(queue.advance_to(10))
		observed_ticks.append(queue.get_current_tick())
	)
	assert_gt(handle, 0, "嵌套推进测试应能排入回调。")

	var outer_report: Dictionary = queue.advance_to(2)
	observed_ticks.append(queue.get_current_tick())

	assert_eq(nested_reports.size(), 1, "回调应收到一份嵌套推进报告。")
	assert_false(
		GFVariantData.get_option_bool(nested_reports[0], "ok", true),
		"同一队列正在推进时，嵌套 advance 必须被稳定拒绝。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(nested_reports[0], "status"),
		&"advance_in_progress",
		"嵌套推进应返回可诊断的稳定状态。"
	)
	assert_eq(observed_ticks, [1, 1, 2], "嵌套调用不能先推进到未来再由外层把时钟写回。")
	assert_true(GFVariantData.get_option_bool(outer_report, "ok"), "外层推进应正常完成。")


func test_manual_timer_queue_nested_advance_cannot_bypass_outer_callback_budget() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var events: Array[String] = []
	var nested_reports: Array[Dictionary] = []

	var first_handle: int = queue.schedule_at(1, func() -> void:
		events.append("first")
		nested_reports.append(queue.advance_to(1, { "max_callbacks": 32 }))
	)
	var second_handle: int = queue.schedule_at(1, func() -> void:
		events.append("second")
	)
	assert_gt(first_handle, 0, "预算测试应能排入第一个回调。")
	assert_gt(second_handle, 0, "预算测试应能排入第二个回调。")

	var outer_report: Dictionary = queue.advance_to(1, { "max_callbacks": 1 })

	assert_eq(events, ["first"], "嵌套 advance 不得越过外层统一回调预算执行第二项。")
	assert_eq(queue.get_pending_count(), 1, "未执行的同 tick 回调应留在队列中。")
	assert_true(
		GFVariantData.get_option_bool(outer_report, "truncated"),
		"外层达到预算且仍有到期任务时应报告 truncated。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(nested_reports[0], "status"),
		&"advance_in_progress",
		"同 tick 嵌套推进也必须使用相同的稳定拒绝状态。"
	)


func test_manual_timer_queue_clear_during_callback_cancels_outer_advance_generation() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var events: Array[String] = []

	var clear_handle: int = queue.schedule_at(1, func() -> void:
		events.append("clear")
		queue.clear()
		var _replacement_handle: int = queue.schedule_at(3, func() -> void:
			events.append("replacement")
		)
	)
	assert_gt(clear_handle, 0, "clear generation 测试应能排入回调。")

	var cancelled_report: Dictionary = queue.advance_to(2)

	assert_false(
		GFVariantData.get_option_bool(cancelled_report, "ok", true),
		"callback 清空队列后，旧 advance generation 不得继续提交。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(cancelled_report, "status"),
		&"cleared_during_advance",
		"旧推进应明确报告被 clear 取消。"
	)
	assert_eq(queue.get_current_tick(), 0, "clear 的最后写入必须获胜，外层不得再写入旧 target。")
	assert_eq(queue.get_pending_count(), 1, "clear 后新一代调度的任务必须保留。")

	var replacement_report: Dictionary = queue.advance_to(3)
	assert_true(GFVariantData.get_option_bool(replacement_report, "ok"), "新一代推进应可正常执行。")
	assert_eq(events, ["clear", "replacement"], "旧 advance 不得吞掉 clear 后的新一代任务。")


func test_manual_timer_queue_cancels_owner_bound_work() -> void:
	var queue: GF_MANUAL_TIMER_QUEUE_SCRIPT = GF_MANUAL_TIMER_QUEUE_SCRIPT.new()
	var events: Array[String] = []
	var timer_owner: RefCounted = RefCounted.new()

	var owned_handle: int = queue.schedule_at_owned(timer_owner, 2, func() -> void:
		events.append("owned")
	)
	assert_gt(owned_handle, 0, "owner 绑定计时器应返回句柄。")
	timer_owner = null

	var report: Dictionary = queue.advance_to(2)
	assert_eq(events, [], "owner 释放后计时器不应执行。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 1, "推进报告应统计 owner 跳过。")
