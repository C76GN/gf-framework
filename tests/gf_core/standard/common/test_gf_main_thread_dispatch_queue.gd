extends GutTest

const GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = preload("res://addons/gf/standard/common/gf_main_thread_dispatch_queue.gd")


func test_dispatch_queue_orders_front_and_tracks_counts() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var first_handle: int = queue.post(func() -> void:
		events.append("first")
	, { "label": "first" })
	var front_handle: int = queue.post(func() -> void:
		events.append("front")
	, {
		"label": "front",
		"front": true,
	})

	assert_gt(first_handle, 0, "普通回调应返回句柄。")
	assert_gt(front_handle, 0, "front 回调应返回句柄。")
	var report: Dictionary = queue.dispatch()

	assert_eq(events, ["front", "first"], "front 回调应排在相同队列之前执行。")
	assert_eq(GFVariantData.get_option_int(report, "dispatched_count"), 2, "派发报告应统计执行数量。")
	assert_true(queue.is_empty(), "派发后队列应为空。")
	assert_true(queue.has_dispatch_context(), "init 后队列应标记显式派发点。")


func test_dispatch_queue_cancels_and_skips_released_owner() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var cancelled_handle: int = queue.post(func() -> void:
		events.append("cancelled")
	)
	assert_true(queue.cancel(cancelled_handle), "未执行回调应可取消。")

	var callback_owner: RefCounted = RefCounted.new()
	var owner_handle: int = queue.post_owned(callback_owner, func() -> void:
		events.append("owned")
	)
	assert_gt(owner_handle, 0, "owner 回调应返回句柄。")
	callback_owner = null

	var report: Dictionary = queue.dispatch()
	var snapshot: Dictionary = queue.get_debug_snapshot()
	assert_eq(events, [], "取消和 owner 释放的回调都不应执行。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 1, "派发报告应统计 owner 跳过。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1, "快照应统计取消数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "skipped_owner_count"), 1, "快照应统计 owner 跳过数量。")
