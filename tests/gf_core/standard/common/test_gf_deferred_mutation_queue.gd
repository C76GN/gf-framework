extends GutTest

const GF_DEFERRED_MUTATION_QUEUE_SCRIPT = preload("res://addons/gf/standard/common/gf_deferred_mutation_queue.gd")


func test_deferred_mutation_queue_plays_back_deterministic_phase_order() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var late_handle: int = queue.record(func() -> void:
		events.append("late")
	, { "sort_key": 20, "label": "late" })
	var early_handle: int = queue.record(func() -> void:
		events.append("early")
	, { "sort_key": 10, "label": "early" })
	var physics_handle: int = queue.record(func() -> void:
		events.append("physics")
	, {
		"phase": &"physics",
		"sort_key": 0,
	})

	assert_gt(late_handle, 0, "延迟变更应返回句柄。")
	assert_gt(early_handle, 0, "延迟变更应返回句柄。")
	assert_gt(physics_handle, 0, "延迟变更应返回句柄。")

	var default_report: Dictionary = queue.playback({ "phase": GF_DEFERRED_MUTATION_QUEUE_SCRIPT.DEFAULT_PHASE })

	assert_eq(events, ["early", "late"], "同一 phase 内应按 sort_key 与记录顺序执行。")
	assert_eq(GFVariantData.get_option_int(default_report, "applied_count"), 2, "报告应统计已应用变更。")
	assert_eq(queue.get_pending_count(), 1, "phase 过滤不应消费其他 phase。")

	var final_report: Dictionary = queue.playback()

	assert_eq(events, ["early", "late", "physics"], "剩余 phase 应可在后续 playback 执行。")
	assert_eq(GFVariantData.get_option_int(final_report, "applied_count"), 1, "后续 playback 应应用剩余变更。")
	assert_true(queue.is_empty(), "全部 playback 后队列应为空。")


func test_deferred_mutation_queue_cancels_and_skips_released_owner() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var cancelled_handle: int = queue.record(func() -> void:
		events.append("cancelled")
	)
	assert_true(queue.cancel(cancelled_handle), "未应用变更应可取消。")

	var mutation_owner: RefCounted = RefCounted.new()
	var owner_handle: int = queue.record_owned(mutation_owner, func() -> void:
		events.append("owned")
	)
	assert_gt(owner_handle, 0, "owner 绑定变更应返回句柄。")
	mutation_owner = null

	var report: Dictionary = queue.playback()
	var snapshot: Dictionary = queue.get_debug_snapshot()

	assert_eq(events, [], "取消和 owner 释放的变更都不应执行。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 1, "报告应统计 owner 跳过。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1, "快照应统计取消数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "skipped_owner_count"), 1, "快照应统计 owner 跳过数量。")
