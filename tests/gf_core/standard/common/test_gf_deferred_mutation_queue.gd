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


func test_deferred_mutation_queue_cancels_pending_mutation() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []

	var cancelled_handle: int = queue.record(func() -> void:
		events.append("cancelled")
	)
	assert_true(queue.cancel(cancelled_handle), "未应用变更应可取消。")

	var report: Dictionary = queue.playback()
	var snapshot: Dictionary = queue.get_debug_snapshot()

	assert_eq(events, [], "取消的变更不应执行。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_owner_count"), 0, "普通 Callable 不应具有 owner 生命周期。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancelled_count"), 1, "快照应统计取消数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "skipped_owner_count"), 0, "快照不应产生 owner 跳过统计。")


func test_playback_snapshot_prevents_reentrant_low_sort_key_from_preempting_tail() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var events: Array[String] = []
	var reentrant_state: Dictionary = {}
	var _first_handle: int = queue.record(func() -> void:
		events.append("first")
		var _reentrant_handle: int = queue.record(func() -> void:
			events.append("reentrant")
		, { "sort_key": -100 })
		reentrant_state["report"] = queue.playback()
	, { "sort_key": 0 })
	var _tail_handle: int = queue.record(func() -> void:
		events.append("tail")
	, { "sort_key": 10 })

	var first_report: Dictionary = queue.playback()

	assert_eq(
		events,
		["first", "tail"],
		"本轮开始后记录的低 sort_key 变更不得越过已经接受的尾部记录。"
	)
	assert_eq(
		GFVariantData.get_option_int(first_report, "applied_count"),
		2
	)
	assert_eq(queue.get_pending_count(), 1)
	assert_eq(
		GFVariantData.get_option_string_name(
			GFVariantData.get_option_dictionary(reentrant_state, "report"),
			"status"
		),
		GF_DEFERRED_MUTATION_QUEUE_SCRIPT.STATUS_BUSY,
		"同步重入 playback 必须失败关闭，不能绕过外层工作预算。"
	)

	var _second_report: Dictionary = queue.playback()
	assert_eq(events, ["first", "tail", "reentrant"])


func test_phase_playback_indexes_large_non_matching_prefix_once() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.max_pending_mutations = 1024
	queue.max_mutations_per_playback = 256
	queue.init()
	var prefix_count: int = 512
	var target_count: int = 256
	var target_values: Array[int] = []
	var prefix_mutation: Callable = func() -> void:
		pass
	var target_mutation: Callable = func(value: int) -> void:
		target_values.append(value)

	for prefix_index: int in range(prefix_count):
		var _prefix_handle: int = queue.record(prefix_mutation, {
			"phase": &"a_prefix",
			"sort_key": prefix_index,
		})
	for target_index: int in range(target_count):
		var _target_handle: int = queue.record(
			target_mutation.bind(target_index),
			{
				"phase": &"z_target",
				"sort_key": target_index,
			}
		)

	var report: Dictionary = queue.playback({
		"phase": &"z_target",
		"max_count": target_count,
	})

	assert_eq(
		GFVariantData.get_option_int(report, "applied_count"),
		target_count
	)
	assert_eq(target_values.size(), target_count)
	assert_eq(target_values[0], 0)
	assert_eq(target_values[target_values.size() - 1], target_count - 1)
	assert_eq(
		queue.get_pending_count(),
		prefix_count,
		"大量非匹配 phase 前缀不得被消费或重复混入目标快照。"
	)
	assert_eq(
		queue.preview({
			"phase": &"a_prefix",
			"limit": prefix_count,
		}).size(),
		prefix_count
	)
	var _cleanup_report: Dictionary = queue.playback({
		"phase": &"a_prefix",
		"max_count": prefix_count,
	})
	assert_true(queue.is_empty())


func test_playback_and_preview_use_bounded_default_and_keep_handles_unique_after_clear() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.max_mutations_per_playback = 2
	queue.init()
	var events: Array[int] = []
	for index: int in range(3):
		var mutation: Callable = func(value: int) -> void:
			events.append(value)
		var _handle: int = queue.record(mutation.bind(index))

	assert_eq(queue.preview().size(), 2, "默认 preview 必须遵守同一有界记录预算。")
	var report: Dictionary = queue.playback()

	assert_eq(events, [0, 1])
	assert_eq(queue.get_pending_count(), 1)
	assert_true(
		GFVariantData.get_option_bool(report, "budget_exhausted"),
		"未显式给出 max_count 时必须使用有界默认预算。"
	)

	var stale_handle: int = queue.record(func() -> void:
		events.append(99)
	)
	queue.clear()
	var current_handle: int = queue.record(func() -> void:
		events.append(4)
	)

	assert_ne(current_handle, stale_handle, "clear 后不得复用旧句柄。")
	assert_false(queue.cancel(stale_handle), "旧句柄不得命中新记录。")
	assert_eq(queue.get_pending_count(), 1)
	var _final_report: Dictionary = queue.playback()
	assert_eq(events, [0, 1, 4])


func test_record_rejects_removed_owner_option() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var legacy_owner: MutationTarget = MutationTarget.new()

	var string_key_handle: int = queue.record(func() -> bool:
		return legacy_owner.apply()
	, { "owner": legacy_owner })

	assert_push_error("[GFDeferredMutationQueue] record 失败：owner 选项已移除，请使用 record_method()。")
	var string_name_key_handle: int = queue.record(func() -> bool:
		return legacy_owner.apply()
	, { &"owner": legacy_owner })
	assert_push_error("[GFDeferredMutationQueue] record 失败：owner 选项已移除，请使用 record_method()。")

	assert_eq(string_key_handle, 0, "String owner 选项必须 fail closed。")
	assert_eq(string_name_key_handle, 0, "StringName owner 选项必须 fail closed。")
	assert_true(queue.is_empty(), "被拒绝的旧式 owner 变更不得进入队列。")


func test_record_method_invokes_live_owner_without_persisting_metadata() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var mutation_target: MutationTarget = MutationTarget.new()

	var handle: int = queue.record_method(mutation_target, &"apply", {
		"phase": &"physics",
		"sort_key": 4,
		"label": "safe_method",
		"metadata": {
			"owner": mutation_target,
		},
	})
	var preview_records: Array[Dictionary] = queue.preview({ "phase": &"physics" })
	var report: Dictionary = queue.playback({ "phase": &"physics" })

	assert_gt(handle, 0, "安全方法变更应返回句柄。")
	assert_eq(preview_records.size(), 1, "安全方法变更应保留 phase 等排序选项。")
	assert_eq(
		GFVariantData.get_option_string(preview_records[0], "label"),
		"safe_method",
		"安全方法变更应保留诊断 label。"
	)
	assert_true(
		GFVariantData.get_option_dictionary(preview_records[0], "metadata").is_empty(),
		"安全方法变更不应持久化可能强引用 owner 的 metadata。"
	)
	assert_eq(mutation_target.invocation_count, 1, "存活 owner 的目标方法应执行一次。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1, "成功方法调用应计为 applied。")


func test_record_method_does_not_retain_released_ref_counted_owner() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var mutation_target: MutationTarget = MutationTarget.new()
	var target_ref: WeakRef = weakref(mutation_target)
	var options: Dictionary = {
		"metadata": {
			"owner": mutation_target,
		},
	}

	var handle: int = queue.record_method(mutation_target, &"apply", options)
	options.clear()
	mutation_target = null

	assert_gt(handle, 0, "RefCounted owner 的安全方法变更应入队。")
	assert_true(target_ref.get_ref() == null, "队列和被忽略的 metadata 都不应强持有 RefCounted owner。")

	var report: Dictionary = queue.playback()

	assert_eq(
		GFVariantData.get_option_int(report, "skipped_owner_count"),
		1,
		"释放的 RefCounted owner 应映射为 skipped owner。"
	)
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 0, "owner 释放不应计为调用失败。")


func test_record_method_skips_freed_node_owner() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var mutation_target: MutationNodeTarget = MutationNodeTarget.new()
	var target_instance_id: int = mutation_target.get_instance_id()

	var handle: int = queue.record_method(mutation_target, &"apply")
	mutation_target.free()
	mutation_target = null
	var report: Dictionary = queue.playback()

	assert_gt(handle, 0, "Node owner 的安全方法变更应入队。")
	assert_false(is_instance_id_valid(target_instance_id), "测试 Node 应已同步释放。")
	assert_eq(
		GFVariantData.get_option_int(report, "skipped_owner_count"),
		1,
		"已 free 的 Node owner 应映射为 skipped owner。"
	)
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 0, "Node 释放不应计为调用失败。")


func test_record_method_maps_missing_failed_and_business_false_to_failure() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var mutation_target: MutationTarget = MutationTarget.new()

	var missing_handle: int = queue.record_method(mutation_target, &"missing_method", {
		"sort_key": 1,
	})
	var invalid_arguments_handle: int = queue.record_method(mutation_target, &"requires_value", {
		"sort_key": 2,
	})
	var rejected_handle: int = queue.record_method(mutation_target, &"reject", {
		"sort_key": 3,
	})
	var report: Dictionary = queue.playback()
	var snapshot: Dictionary = queue.get_debug_snapshot()

	assert_gt(missing_handle, 0, "缺失方法应在 playback 时按状态判定，记录阶段仍返回句柄。")
	assert_gt(invalid_arguments_handle, 0, "参数数量不匹配应在 playback 时映射为 failed。")
	assert_gt(rejected_handle, 0, "返回 false 的业务方法应正常入队。")
	assert_eq(
		mutation_target.invocation_count,
		1,
		"缺失方法和参数预检失败不得执行，业务拒绝方法应执行一次。"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "failed_count"),
		3,
		"method_missing、failed 预检与 invoked false 都应映射为 failed。"
	)
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 0, "失败记录不应计为 applied。")
	assert_eq(
		GFVariantData.get_option_int(snapshot, "failed_count"),
		3,
		"累计调试快照应保留安全方法调用失败数。"
	)


func test_deferred_mutation_queue_rejects_capacity_overflow_without_eviction() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.max_pending_mutations = 2_147_483_647
	assert_eq(
		queue.max_pending_mutations,
		GF_DEFERRED_MUTATION_QUEUE_SCRIPT.ABSOLUTE_MAX_PENDING_MUTATIONS,
		"延迟变更队列容量必须钳制到绝对上限。"
	)
	queue.max_mutations_per_playback = 2_147_483_647
	assert_eq(
		queue.max_mutations_per_playback,
		GF_DEFERRED_MUTATION_QUEUE_SCRIPT.ABSOLUTE_MAX_MUTATIONS_PER_PLAYBACK,
		"单次 playback 预算必须钳制到绝对上限。"
	)
	queue.max_pending_mutations = 2
	queue.init()
	var events: Array[String] = []

	var late_handle: int = queue.record(func() -> void:
		events.append("late")
	, { "sort_key": 20 })
	var early_handle: int = queue.record(func() -> void:
		events.append("early")
	, { "sort_key": 10 })
	var rejected_handle: int = queue.record(func() -> void:
		events.append("rejected")
	, { "sort_key": 0 })
	var snapshot: Dictionary = queue.get_debug_snapshot()

	assert_gt(late_handle, 0, "容量内第一条变更应被记录。")
	assert_gt(early_handle, 0, "容量内第二条变更应被记录。")
	assert_eq(rejected_handle, 0, "容量满后 record 应返回稳定失败句柄 0。")
	assert_eq(GFVariantData.get_option_int(snapshot, "pending_count"), 2, "拒绝不得驱逐既有变更。")
	assert_eq(GFVariantData.get_option_int(snapshot, "high_watermark"), 2, "快照应记录待应用高水位。")
	assert_eq(GFVariantData.get_option_int(snapshot, "rejected_count"), 1, "快照应统计容量拒绝。")
	assert_eq(GFVariantData.get_option_int(snapshot, "dropped_count"), 0, "变更队列不得静默丢弃记录。")

	var _report: Dictionary = queue.playback()
	assert_eq(events, ["early", "late"], "被接受的变更仍应按确定性顺序应用。")


func test_deferred_mutation_queue_rejects_worker_thread_playback() -> void:
	var queue: GF_DEFERRED_MUTATION_QUEUE_SCRIPT = GF_DEFERRED_MUTATION_QUEUE_SCRIPT.new()
	queue.init()
	var applied: Array[bool] = []
	var _handle: int = queue.record(func() -> void:
		applied.append(true)
	)
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(
		Callable(self, &"_playback_from_worker").bind(queue)
	)
	assert_eq(start_error, OK, "测试 worker 应能启动。")
	var worker_value: Variant = worker.wait_to_finish()
	var report: Dictionary = GFVariantData.as_dictionary(worker_value)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "worker 不得应用延迟变更。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_DEFERRED_MUTATION_QUEUE_SCRIPT.STATUS_WRONG_THREAD,
		"worker playback 应返回稳定线程错误。"
	)
	assert_eq(queue.get_pending_count(), 1, "被拒绝的 worker playback 不得消费变更。")
	assert_true(applied.is_empty(), "被拒绝的 worker playback 不得执行变更。")

	var _main_report: Dictionary = queue.playback()
	assert_eq(applied, [true], "回到主线程后应能正常应用变更。")


# --- 私有/辅助方法 ---

func _playback_from_worker(queue: GFDeferredMutationQueue) -> Dictionary:
	return queue.playback()


# --- 内部类 ---

class MutationTarget extends RefCounted:
	var invocation_count: int = 0


	func apply() -> bool:
		invocation_count += 1
		return true


	func reject() -> bool:
		invocation_count += 1
		return false


	func requires_value(_value: int) -> bool:
		invocation_count += 1
		return true


class MutationNodeTarget extends Node:
	var invocation_count: int = 0


	func apply() -> bool:
		invocation_count += 1
		return true
