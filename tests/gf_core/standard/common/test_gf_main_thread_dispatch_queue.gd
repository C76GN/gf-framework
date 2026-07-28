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


func test_dispatch_queue_cancels_pending_callback() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var cancelled_handle: int = queue.post(func() -> void:
		events.append("cancelled")
	)
	assert_true(queue.cancel(cancelled_handle), "未执行回调应可取消。")

	var report: Dictionary = queue.dispatch()
	var snapshot: Dictionary = queue.get_debug_snapshot()
	assert_eq(events, [], "取消的回调不应执行。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 0, "无 owner 回调不应产生 owner 跳过。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1, "快照应统计取消数量。")


func test_dispatch_snapshot_prevents_reentrant_front_post_from_starving_tail() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []
	var reentrant_state: Dictionary = {}
	var _first_handle: int = queue.post(func() -> void:
		events.append("first")
		var _reentrant_handle: int = queue.post(func() -> void:
			events.append("reentrant_front")
		, { "front": true })
		reentrant_state["report"] = queue.dispatch()
	)
	var _tail_handle: int = queue.post(func() -> void:
		events.append("tail")
	)

	var first_report: Dictionary = queue.dispatch()

	assert_eq(
		events,
		["first", "tail"],
		"本轮开始后进入 front 的回调不得越过已经接受的尾部记录。"
	)
	assert_eq(
		GFVariantData.get_option_int(first_report, "dispatched_count"),
		2
	)
	assert_eq(queue.get_pending_count(), 1)
	assert_eq(
		GFVariantData.get_option_string_name(
			GFVariantData.get_option_dictionary(reentrant_state, "report"),
			"status"
		),
		GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.STATUS_BUSY,
		"同步重入派发必须失败关闭，不能绕过外层工作预算。"
	)

	var _second_report: Dictionary = queue.dispatch()
	assert_eq(events, ["first", "tail", "reentrant_front"])


func test_dispatch_snapshot_partitions_large_reentrant_front_prefix_once() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.max_pending_callbacks = 1024
	queue.init()
	var original_count: int = 256
	var front_count: int = 512
	var events: Array[String] = []
	var tail_handles: Array[int] = []
	var reentrant_state: Dictionary = {}
	var original_callback: Callable = func(value: int) -> void:
		events.append("old_%d" % value)
	var front_callback: Callable = func(value: int) -> void:
		events.append("front_%d" % value)

	var _first_handle: int = queue.post(func() -> void:
		events.append("old_0")
		for front_index: int in range(front_count):
			var _front_handle: int = queue.post(
				front_callback.bind(front_index),
				{ "front": true }
			)
		var cancel_index: int = tail_handles.size() - 1
		reentrant_state["cancelled"] = queue.cancel(
			tail_handles[cancel_index]
		)
	)
	for original_index: int in range(1, original_count):
		tail_handles.append(
			queue.post(original_callback.bind(original_index))
		)

	var first_report: Dictionary = queue.dispatch(original_count)
	var first_round_front_count: int = 0
	for event_label: String in events:
		if event_label.begins_with("front_"):
			first_round_front_count += 1

	assert_true(
		GFVariantData.get_option_bool(reentrant_state, "cancelled"),
		"入口快照分离后仍必须允许取消尚未执行的旧记录。"
	)
	assert_eq(first_round_front_count, 0)
	assert_eq(
		GFVariantData.get_option_int(first_report, "dispatched_count"),
		original_count - 1
	)
	assert_eq(queue.get_pending_count(), front_count)

	var second_report: Dictionary = queue.dispatch(front_count)
	assert_eq(
		GFVariantData.get_option_int(second_report, "dispatched_count"),
		front_count
	)
	assert_eq(events.size(), original_count - 1 + front_count)
	assert_eq(
		events[original_count - 1],
		"front_%d" % (front_count - 1),
		"大量重入 front 记录应在下一轮按既有 LIFO front 语义执行。"
	)
	assert_true(queue.is_empty())


func test_dispatch_uses_bounded_default_and_preserves_handle_identity_across_clear() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.max_callbacks_per_tick = 2
	queue.init()
	var events: Array[int] = []
	for index: int in range(3):
		var callback: Callable = func(value: int) -> void:
			events.append(value)
		var _handle: int = queue.post(callback.bind(index))

	var report: Dictionary = queue.dispatch()

	assert_eq(events, [0, 1])
	assert_eq(queue.get_pending_count(), 1)
	assert_true(
		GFVariantData.get_option_bool(report, "budget_exhausted"),
		"未显式给出 max_count 时必须使用有界默认预算。"
	)

	var stale_handle: int = queue.post(func() -> void:
		events.append(99)
	)
	queue.clear()
	var current_handle: int = queue.post(func() -> void:
		events.append(4)
	)

	assert_ne(current_handle, stale_handle, "clear 后不得复用旧句柄。")
	assert_false(queue.cancel(stale_handle), "旧句柄不得命中新记录。")
	assert_eq(queue.get_pending_count(), 1)
	var _final_report: Dictionary = queue.dispatch()
	assert_eq(events, [0, 1, 4])


func test_post_rejects_removed_owner_option() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var legacy_owner: _MethodOwner = _MethodOwner.new()

	var string_key_handle: int = queue.post(func() -> bool:
		return legacy_owner.record_tail()
	, { "owner": legacy_owner })

	assert_push_error("[GFMainThreadDispatchQueue] post 失败：owner 选项已移除，请使用 post_method()。")
	var string_name_key_handle: int = queue.post(func() -> bool:
		return legacy_owner.record_tail()
	, { &"owner": legacy_owner })
	assert_push_error("[GFMainThreadDispatchQueue] post 失败：owner 选项已移除，请使用 post_method()。")

	assert_eq(string_key_handle, 0, "String owner 选项必须 fail closed。")
	assert_eq(string_name_key_handle, 0, "StringName owner 选项必须 fail closed。")
	assert_true(queue.is_empty(), "被拒绝的旧式 owner 回调不得进入队列。")


func test_post_method_preserves_order_and_owner_cancellation() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var method_owner: _MethodOwner = _MethodOwner.new()
	var cancelled_owner: _MethodOwner = _MethodOwner.new()

	var tail_handle: int = queue.post_method(method_owner, &"record_tail")
	var front_handle: int = queue.post_method(
		method_owner,
		&"record_front",
		{ "front": true }
	)
	var cancelled_handle: int = queue.post_method(cancelled_owner, &"record_cancelled")

	assert_gt(tail_handle, 0, "弱方法调用应返回句柄。")
	assert_gt(front_handle, 0, "front 弱方法调用应返回句柄。")
	assert_gt(cancelled_handle, 0, "可取消的弱方法调用应返回句柄。")
	assert_eq(queue.cancel_owner(cancelled_owner), 1, "cancel_owner 应识别弱方法调用的初始 owner。")

	var report: Dictionary = queue.dispatch()
	var snapshot: Dictionary = queue.get_debug_snapshot()
	assert_eq(method_owner.events, ["front", "tail"], "弱方法调用应保留 front 顺序。")
	assert_eq(GFVariantData.get_option_int(report, "dispatched_count"), 2, "成功的弱方法调用应计为 dispatched。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1, "弱方法取消应进入既有统计。")


func test_post_method_does_not_retain_ref_counted_owner() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var method_owner: _MethodOwner = _MethodOwner.new()
	var owner_ref: WeakRef = weakref(method_owner)
	var options: Dictionary = { "metadata": { "owner": method_owner } }

	var handle: int = queue.post_method(method_owner, &"record_tail", options)
	assert_gt(handle, 0, "RefCounted owner 的弱方法调用应成功入队。")
	options.clear()
	method_owner = null

	assert_true(owner_ref.get_ref() == null, "安全入口不得通过 Callable 或未声明 metadata 强持有 RefCounted owner。")
	var report: Dictionary = queue.dispatch()
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 1, "已释放 RefCounted owner 应计为 skipped。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 0, "owner 释放不应计为调用失败。")


func test_post_method_skips_freed_node_owner() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var node_owner: Node = Node.new()
	var owner_ref: WeakRef = weakref(node_owner)

	var handle: int = queue.post_method(node_owner, &"get_name")
	assert_gt(handle, 0, "Node owner 的弱方法调用应成功入队。")
	node_owner.free()
	node_owner = null

	assert_true(owner_ref.get_ref() == null, "free 后 WeakRef 不应继续解析 Node。")
	var report: Dictionary = queue.dispatch()
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 1, "已 free 的 Node owner 应计为 skipped。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 0, "Node owner 释放不应计为调用失败。")


func test_post_method_maps_missing_and_failure_results_to_failed_count() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var method_owner: _MethodOwner = _MethodOwner.new()

	var missing_handle: int = queue.post_method(method_owner, &"missing_method")
	var argument_mismatch_handle: int = queue.post_method(method_owner, &"requires_argument")
	var false_handle: int = queue.post_method(method_owner, &"return_false")
	var report_handle: int = queue.post_method(method_owner, &"return_failed_report")
	assert_gt(missing_handle, 0, "缺失方法应延迟到派发时判定。")
	assert_gt(argument_mismatch_handle, 0, "参数数量不匹配应延迟到派发时判定。")
	assert_gt(false_handle, 0, "返回 false 的方法应成功入队。")
	assert_gt(report_handle, 0, "返回失败报告的方法应成功入队。")

	var report: Dictionary = queue.dispatch()
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 4, "method_missing、原语 failed、false 和 ok=false 都应进入既有失败统计。")
	assert_eq(GFVariantData.get_option_int(report, "dispatched_count"), 0, "失败结果不应计为成功派发。")
	assert_eq(method_owner.invoked_count, 2, "缺失方法不应调用 owner，两个显式失败方法应各调用一次。")


func test_dispatch_queue_rejects_capacity_overflow_without_eviction() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.max_pending_callbacks = 2_147_483_647
	assert_eq(
		queue.max_pending_callbacks,
		GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.ABSOLUTE_MAX_PENDING_CALLBACKS,
		"派发队列容量必须钳制到绝对上限。"
	)
	queue.max_callbacks_per_tick = 2_147_483_647
	assert_eq(
		queue.max_callbacks_per_tick,
		GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.ABSOLUTE_MAX_CALLBACKS_PER_DISPATCH,
		"单次派发预算必须钳制到绝对上限。"
	)
	queue.max_pending_callbacks = 2
	queue.init()
	var events: Array[String] = []

	var first_handle: int = queue.post(func() -> void:
		events.append("first")
	)
	var second_handle: int = queue.post(func() -> void:
		events.append("second")
	)
	var rejected_handle: int = queue.post(func() -> void:
		events.append("rejected")
	, { "front": true })
	var snapshot: Dictionary = queue.get_debug_snapshot()

	assert_gt(first_handle, 0, "容量内第一条回调应入队。")
	assert_gt(second_handle, 0, "容量内第二条回调应入队。")
	assert_eq(rejected_handle, 0, "容量满后 post 应返回稳定失败句柄 0。")
	assert_eq(GFVariantData.get_option_int(snapshot, "pending_count"), 2, "拒绝不得驱逐既有回调。")
	assert_eq(GFVariantData.get_option_int(snapshot, "high_watermark"), 2, "快照应记录待派发高水位。")
	assert_eq(GFVariantData.get_option_int(snapshot, "rejected_count"), 1, "快照应统计容量拒绝。")
	assert_eq(GFVariantData.get_option_int(snapshot, "dropped_count"), 0, "派发队列不得静默丢弃回调。")

	var _report: Dictionary = queue.dispatch()
	assert_eq(events, ["first", "second"], "容量拒绝不得改变已接受回调的顺序。")
	assert_gt(queue.post(func() -> void:
		events.append("after_drain")
	), 0, "释放容量后应能继续入队。")


func test_dispatch_queue_rejects_worker_thread_dispatch() -> void:
	var queue: GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT = GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.new()
	queue.init()
	var invoked: Array[bool] = []
	var _handle: int = queue.post(func() -> void:
		invoked.append(true)
	)
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(self, &"_dispatch_from_worker").bind(queue)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	var worker_value: Variant = worker.wait_to_finish()
	var report: Dictionary = GFVariantData.as_dictionary(worker_value)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "worker 不得消费主线程派发队列。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_MAIN_THREAD_DISPATCH_QUEUE_SCRIPT.STATUS_WRONG_THREAD,
		"worker 派发应返回稳定线程错误。"
	)
	assert_eq(queue.get_pending_count(), 1, "被拒绝的 worker 派发不得消费回调。")
	assert_true(invoked.is_empty(), "被拒绝的 worker 派发不得执行回调。")

	var _main_report: Dictionary = queue.dispatch()
	assert_eq(invoked, [true], "回到主线程后应能正常派发。")


# --- 私有/辅助方法 ---

func _dispatch_from_worker(queue: GFMainThreadDispatchQueue) -> Dictionary:
	return queue.dispatch()


# --- 内部类 ---

class _MethodOwner:
	extends RefCounted

	var events: Array[String] = []
	var invoked_count: int = 0


	func record_front() -> bool:
		events.append("front")
		return true


	func record_tail() -> bool:
		events.append("tail")
		return true


	func record_cancelled() -> bool:
		events.append("cancelled")
		return true


	func requires_argument(_value: String) -> bool:
		invoked_count += 1
		return true


	func return_false() -> bool:
		invoked_count += 1
		return false


	func return_failed_report() -> Dictionary:
		invoked_count += 1
		return { "ok": false }
