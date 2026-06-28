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
