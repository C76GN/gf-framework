## 测试 GFBackgroundWorkUtility 的纯数据后台工作协调行为。
extends GutTest


# --- 私有变量 ---

var _applied_value: int = 0
var _applied_resource: Resource = null
var _slow_apply_count: int = 0


# --- 测试生命周期方法 ---

func before_each() -> void:
	_applied_value = 0
	_applied_resource = null
	_slow_apply_count = 0


# --- 测试用例 ---

func test_cpu_work_runs_on_thread_and_applies_on_tick() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	watch_signals(utility)

	var worker: PureWorker = PureWorker.new()
	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{"value": 21},
		Callable(self, "_apply_value")
	)

	await _pump_until_finished(utility, task)

	assert_eq(task.status, GFBackgroundWorkTask.Status.COMPLETED, "CPU 工作应完成。")
	assert_eq(_applied_value, 42, "主线程应用回调应读取后台结果。")
	assert_signal_emitted(utility, "work_started", "线程工作启动时应发出信号。")
	assert_signal_emitted(utility, "work_applied", "主线程应用完成时应发出信号。")
	utility.dispose()


func test_paused_task_retains_scoped_ref_counted_callbacks_until_terminal() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.pause()

	var submission: ScopedCallbackSubmission = _submit_scoped_callbacks(utility)

	assert_eq(submission.task.status, GFBackgroundWorkTask.Status.QUEUED, "暂停期间任务应保持 queued。")
	assert_true(_weak_ref_is_alive(submission.worker_weak_ref), "已接受任务应强持有局部 worker target。")
	assert_true(_weak_ref_is_alive(submission.apply_weak_ref), "已接受任务应强持有局部 apply target。")

	utility.resume()
	await _pump_until_finished(utility, submission.task)

	assert_eq(submission.task.status, GFBackgroundWorkTask.Status.COMPLETED, "作用域退出后 worker 仍应能完成。")
	assert_true(_variant_is_true(submission.task.apply_result), "作用域退出后 apply callback 仍应能执行。")
	assert_false(_weak_ref_is_alive(submission.worker_weak_ref), "线程 join 后应释放 worker target。")
	assert_false(_weak_ref_is_alive(submission.apply_weak_ref), "任务进入终态后应释放 apply target。")
	utility.dispose()


func test_cancelled_task_releases_scoped_ref_counted_callbacks() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.pause()
	var submission: ScopedCallbackSubmission = _submit_scoped_callbacks(utility)

	assert_true(_weak_ref_is_alive(submission.worker_weak_ref))
	assert_true(_weak_ref_is_alive(submission.apply_weak_ref))
	assert_true(utility.cancel_work(submission.task.work_id))

	assert_eq(submission.task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_false(_weak_ref_is_alive(submission.worker_weak_ref))
	assert_false(_weak_ref_is_alive(submission.apply_weak_ref))
	utility.dispose()


func test_failed_task_releases_scoped_ref_counted_callbacks() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var submission: ScopedCallbackSubmission = _submit_scoped_failure(utility)

	assert_true(_weak_ref_is_alive(submission.worker_weak_ref))
	assert_true(_weak_ref_is_alive(submission.apply_weak_ref))
	await _pump_until_finished(utility, submission.task)

	assert_eq(submission.task.status, GFBackgroundWorkTask.Status.FAILED)
	assert_false(_weak_ref_is_alive(submission.worker_weak_ref))
	assert_false(_weak_ref_is_alive(submission.apply_weak_ref))
	utility.dispose()


func test_shared_ref_counted_callback_target_survives_worker_release_window() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.pause()
	var submission: ScopedCallbackSubmission = _submit_shared_callback_target(
		utility
	)

	assert_true(_weak_ref_is_alive(submission.worker_weak_ref))
	utility.resume()
	await _pump_until_finished(utility, submission.task)

	assert_eq(submission.task.status, GFBackgroundWorkTask.Status.COMPLETED)
	assert_true(_variant_is_true(submission.task.apply_result))
	assert_false(_weak_ref_is_alive(submission.worker_weak_ref))
	utility.dispose()


func test_failed_worker_marks_task_failed() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: PureWorker = PureWorker.new()

	var task: GFBackgroundWorkTask = utility.submit_io_work(Callable(worker, "fail_work"))

	await _pump_until_finished(utility, task)

	assert_eq(task.status, GFBackgroundWorkTask.Status.FAILED, "ok=false 的后台结果应转为 failed。")
	assert_eq(task.error_message, "worker_failed", "失败原因应写入任务。")
	utility.dispose()


func test_failed_worker_uses_standard_result_message_fallback() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: PureWorker = PureWorker.new()

	var task: GFBackgroundWorkTask = utility.submit_io_work(Callable(worker, "fail_work_with_message"))

	await _pump_until_finished(utility, task)

	assert_eq(task.status, GFBackgroundWorkTask.Status.FAILED, "ok=false 的后台结果应转为 failed。")
	assert_eq(task.error_message, "message_failed", "缺少 error 时应读取标准 message。")
	utility.dispose()


func test_object_payload_is_rejected_by_default() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: PureWorker = PureWorker.new()
	var node: Node = Node.new()

	var task: GFBackgroundWorkTask = utility.submit_cpu_work(Callable(worker, "double_value"), {"node": node})

	assert_eq(task.status, GFBackgroundWorkTask.Status.FAILED, "默认不应允许 Object 进入线程 payload。")
	assert_string_contains(task.error_message, "payload", "失败原因应说明 payload 不安全。")
	node.free()
	utility.dispose()


func test_explicit_context_worker_keeps_input_payload_pure_and_receives_identity() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: CooperativeWorker = CooperativeWorker.new()
	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "return_with_context"),
		{ "value": 23 },
		Callable(),
		{
			"id": &"context_identity",
			"pass_cancellation_context": true,
		}
	)

	await _pump_until_finished(utility, task)

	assert_eq(task.status, GFBackgroundWorkTask.Status.COMPLETED)
	assert_false(_contains_object(task.input_data), "Context 必须独立于纯 Variant input_data 传入。")
	assert_eq(worker.get_last_work_id(), &"context_identity")
	assert_eq(worker.get_call_count(), 1)
	var context: GFBackgroundWorkContext = task.get_cancellation_context()
	assert_not_null(context)
	assert_eq(context.get_work_id(), &"context_identity")
	assert_false(context.is_cancel_requested())
	assert_eq(context.get_cancel_requested_msec(), 0)
	var snapshot: Dictionary = context.get_debug_snapshot()
	assert_eq(
		snapshot.keys(),
		[
			"work_id",
			"cancel_requested",
			"cancel_reason",
			"cancel_reason_name",
			"cancel_requested_msec",
		],
		"Context 快照必须保持精确 5 字段 schema。"
	)
	assert_eq(GFVariantData.get_option_string(snapshot, "work_id"), "context_identity")
	assert_false(GFVariantData.get_option_bool(snapshot, "cancel_requested", true))
	assert_eq(
		GFVariantData.get_option_int(snapshot, "cancel_reason", -1),
		GFBackgroundWorkContext.CancellationReason.NONE
	)
	assert_eq(GFVariantData.get_option_string(snapshot, "cancel_reason_name"), "none")
	assert_eq(GFVariantData.get_option_int(snapshot, "cancel_requested_msec", -1), 0)
	assert_eq(
		GFBackgroundWorkContext.cancellation_reason_name(
			GFBackgroundWorkContext.CancellationReason.NONE
		),
		"none"
	)
	assert_eq(
		GFBackgroundWorkContext.cancellation_reason_name(
			GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
		),
		"cancel_work"
	)
	assert_eq(
		GFBackgroundWorkContext.cancellation_reason_name(
			GFBackgroundWorkContext.CancellationReason.CANCEL_ALL
		),
		"cancel_all"
	)
	assert_eq(
		GFBackgroundWorkContext.cancellation_reason_name(
			GFBackgroundWorkContext.CancellationReason.CLEAR_ALL
		),
		"clear_all"
	)
	assert_eq(
		GFBackgroundWorkContext.cancellation_reason_name(
			GFBackgroundWorkContext.CancellationReason.UTILITY_DISPOSED
		),
		"utility_disposed"
	)
	utility.dispose()


func test_context_opt_in_rejects_one_argument_worker_before_queueing() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: PureWorker = PureWorker.new()

	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{ "value": 3 },
		Callable(),
		{ "pass_cancellation_context": true }
	)

	assert_eq(task.status, GFBackgroundWorkTask.Status.FAILED)
	assert_string_contains(task.error_message, "两个参数")
	assert_null(task.get_cancellation_context())
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "queued_count"), 0)
	utility.dispose()


func test_duplicate_id_rejection_does_not_publish_cancellation_context() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.pause()
	var worker: CooperativeWorker = CooperativeWorker.new()
	var accepted: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "wait_for_cancel"),
		{},
		Callable(),
		{
			"id": &"duplicate_context",
			"pass_cancellation_context": true,
		}
	)
	var rejected: GFBackgroundWorkTask = utility.submit_io_work(
		Callable(worker, "wait_for_cancel"),
		{},
		Callable(),
		{
			"id": &"duplicate_context",
			"pass_cancellation_context": true,
		}
	)

	assert_eq(accepted.status, GFBackgroundWorkTask.Status.QUEUED)
	assert_not_null(accepted.get_cancellation_context())
	assert_eq(rejected.status, GFBackgroundWorkTask.Status.FAILED)
	assert_null(rejected.get_cancellation_context(), "接纳失败不得发布伪造的同 ID Context。")
	assert_eq(worker.get_call_count(), 0)
	utility.clear_all()
	utility.dispose()


func test_cancel_before_start_records_reason_without_invoking_worker() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.pause()
	var worker: CooperativeWorker = CooperativeWorker.new()
	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var context: GFBackgroundWorkContext = task.get_cancellation_context()

	assert_not_null(context)
	assert_true(utility.cancel_work(task.work_id))

	assert_eq(task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(worker.get_call_count(), 0)
	assert_true(context.is_cancel_requested())
	assert_eq(
		context.get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
	)
	assert_false(utility.cancel_work(task.work_id), "终态任务不得重复取消。")
	utility.dispose()


func test_running_cpu_cancel_releases_single_slot_for_successor() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.max_threaded_tasks = 1
	utility.init()
	watch_signals(utility)
	var worker: CooperativeWorker = CooperativeWorker.new()
	var pure_worker: PureWorker = PureWorker.new()
	var first: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "wait_for_cancel"),
		{ "value": 1 },
		Callable(),
		{
			"id": &"cooperative_first",
			"pass_cancellation_context": true,
		}
	)
	var successor: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(pure_worker, "double_value"),
		{ "value": 5 },
		Callable(),
		{ "id": &"successor" }
	)

	assert_true(await _wait_for_worker_entry(worker), "首个 worker 应进入协作循环。")
	assert_eq(first.status, GFBackgroundWorkTask.Status.RUNNING)
	assert_eq(successor.status, GFBackgroundWorkTask.Status.QUEUED)
	assert_true(utility.cancel_work(first.work_id))

	await _pump_until_finished(utility, first)
	await _pump_until_finished(utility, successor)

	assert_eq(first.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_false(worker.did_time_out(), "协作 worker 应观察 Context 后主动退出。")
	assert_eq(
		worker.get_observed_reason(),
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
	)
	assert_eq(successor.status, GFBackgroundWorkTask.Status.COMPLETED)
	assert_signal_emit_count(utility, "work_cancelled", 1, "取消终态必须恰好发出一次。")
	assert_signal_emit_count(utility, "work_completed", 1, "只有 successor 可以完成。")
	assert_signal_not_emitted(utility, "work_applied", "取消任务不得进入 apply 终态。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "running_thread_count"), 0)
	utility.dispose()


func test_running_io_worker_observes_cancel_and_repeated_requests_keep_first_reason() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	watch_signals(utility)
	var worker: CooperativeWorker = CooperativeWorker.new()
	var task: GFBackgroundWorkTask = utility.submit_io_work(
		Callable(worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var context: GFBackgroundWorkContext = task.get_cancellation_context()

	assert_true(await _wait_for_worker_entry(worker))
	assert_true(utility.cancel_work(task.work_id))
	var requested_msec: int = context.get_cancel_requested_msec()
	assert_gt(requested_msec, 0, "首次取消必须冻结非零毫秒 tick。")
	var snapshot: Dictionary = context.get_debug_snapshot()
	assert_true(GFVariantData.get_option_bool(snapshot, "cancel_requested"))
	assert_eq(
		GFVariantData.get_option_int(snapshot, "cancel_reason", -1),
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
	)
	assert_eq(GFVariantData.get_option_string(snapshot, "cancel_reason_name"), "cancel_work")
	assert_eq(
		GFVariantData.get_option_int(snapshot, "cancel_requested_msec", -1),
		requested_msec
	)
	utility.cancel_all()
	assert_eq(
		context.get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK,
		"后续 cancel_all 不得覆盖首次取消原因。"
	)
	assert_eq(
		context.get_cancel_requested_msec(),
		requested_msec,
		"重复取消不得覆盖首次请求时间。"
	)

	await _pump_until_finished(utility, task)

	assert_eq(task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(worker.get_observed_reason(), GFBackgroundWorkContext.CancellationReason.CANCEL_WORK)
	assert_signal_emit_count(utility, "work_cancelled", 1)
	assert_signal_not_emitted(utility, "work_completed")
	assert_signal_not_emitted(utility, "work_applied")
	utility.dispose()


func test_cancel_after_worker_return_before_join_wins_completion_race() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: CooperativeWorker = CooperativeWorker.new()
	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "return_with_context"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)

	assert_true(await _wait_for_worker_return(worker), "worker 应在 Utility tick 前物理返回。")
	assert_eq(task.status, GFBackgroundWorkTask.Status.RUNNING, "join 前任务仍由 Utility 持有运行态。")
	assert_true(utility.cancel_work(task.work_id))
	utility.tick()

	assert_eq(task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(
		task.get_cancellation_context().get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
	)
	assert_false(utility.cancel_work(task.work_id), "终态后的取消不得改变结果。")
	utility.dispose()


func test_cancel_all_publishes_cancel_all_reason_to_each_running_context() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.max_threaded_tasks = 2
	utility.init()
	var first_worker: CooperativeWorker = CooperativeWorker.new()
	var second_worker: CooperativeWorker = CooperativeWorker.new()
	var first: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(first_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var second: GFBackgroundWorkTask = utility.submit_io_work(
		Callable(second_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)

	assert_true(await _wait_for_worker_entry(first_worker))
	assert_true(await _wait_for_worker_entry(second_worker))
	utility.cancel_all()
	await _pump_until_finished(utility, first)
	await _pump_until_finished(utility, second)

	assert_eq(first_worker.get_observed_reason(), GFBackgroundWorkContext.CancellationReason.CANCEL_ALL)
	assert_eq(second_worker.get_observed_reason(), GFBackgroundWorkContext.CancellationReason.CANCEL_ALL)
	assert_eq(first.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(second.status, GFBackgroundWorkTask.Status.CANCELLED)
	utility.dispose()


func test_clear_all_and_dispose_publish_distinct_reasons_before_join() -> void:
	var clear_utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	clear_utility.max_threaded_tasks = 1
	clear_utility.init()
	var clear_worker: CooperativeWorker = CooperativeWorker.new()
	var clear_queued_worker: CooperativeWorker = CooperativeWorker.new()
	var clear_task: GFBackgroundWorkTask = clear_utility.submit_cpu_work(
		Callable(clear_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var clear_queued_task: GFBackgroundWorkTask = clear_utility.submit_io_work(
		Callable(clear_queued_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var clear_context: GFBackgroundWorkContext = clear_task.get_cancellation_context()
	var clear_queued_context: GFBackgroundWorkContext = clear_queued_task.get_cancellation_context()
	assert_true(await _wait_for_worker_entry(clear_worker))
	assert_eq(clear_queued_task.status, GFBackgroundWorkTask.Status.QUEUED)

	clear_utility.clear_all()

	assert_eq(clear_task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_false(clear_worker.did_time_out(), "clear_all 必须先发布取消，再等待 worker join。")
	assert_eq(
		clear_worker.get_observed_reason(),
		GFBackgroundWorkContext.CancellationReason.CLEAR_ALL
	)
	assert_eq(clear_context.get_cancel_reason(), GFBackgroundWorkContext.CancellationReason.CLEAR_ALL)
	assert_eq(clear_queued_task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(clear_queued_worker.get_call_count(), 0, "排队 worker 不得被启动。")
	assert_eq(
		clear_queued_context.get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.CLEAR_ALL
	)
	assert_eq(GFVariantData.get_option_int(clear_utility.get_debug_snapshot(), "task_count"), 0)
	clear_utility.dispose()

	var dispose_utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	dispose_utility.max_threaded_tasks = 1
	dispose_utility.init()
	var dispose_worker: CooperativeWorker = CooperativeWorker.new()
	var dispose_queued_worker: CooperativeWorker = CooperativeWorker.new()
	var dispose_task: GFBackgroundWorkTask = dispose_utility.submit_io_work(
		Callable(dispose_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var dispose_queued_task: GFBackgroundWorkTask = dispose_utility.submit_cpu_work(
		Callable(dispose_queued_worker, "wait_for_cancel"),
		{},
		Callable(),
		{ "pass_cancellation_context": true }
	)
	var dispose_context: GFBackgroundWorkContext = dispose_task.get_cancellation_context()
	var dispose_queued_context: GFBackgroundWorkContext = dispose_queued_task.get_cancellation_context()
	assert_true(await _wait_for_worker_entry(dispose_worker))
	assert_eq(dispose_queued_task.status, GFBackgroundWorkTask.Status.QUEUED)

	dispose_utility.dispose()

	assert_eq(dispose_task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_false(dispose_worker.did_time_out(), "dispose 必须先发布取消，再等待 worker join。")
	assert_eq(
		dispose_worker.get_observed_reason(),
		GFBackgroundWorkContext.CancellationReason.UTILITY_DISPOSED
	)
	assert_eq(
		dispose_context.get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.UTILITY_DISPOSED
	)
	assert_eq(dispose_queued_task.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(dispose_queued_worker.get_call_count(), 0, "排队 worker 不得被启动。")
	assert_eq(
		dispose_queued_context.get_cancel_reason(),
		GFBackgroundWorkContext.CancellationReason.UTILITY_DISPOSED
	)


func test_pause_and_cancel_waiting_thread_task() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.priority_aging_interval_msec = 250
	utility.priority_aging_step = 2.0
	utility.init()
	utility.pause()
	var worker: PureWorker = PureWorker.new()

	var first: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{"value": 1},
		Callable(),
		{&"id": "first"}
	)
	var high_priority: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{"value": 2},
		Callable(),
		{&"id": "high", &"priority": 10}
	)
	var front: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{"value": 3},
		Callable(),
		{&"id": "front", &"front": "on"}
	)
	var snapshot: Dictionary = utility.get_debug_snapshot()
	var queued_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "queued_ids")
	var priority_entries: Array = GFVariantData.get_option_array(snapshot, "queued_priority_entries")

	assert_eq(first.status, GFBackgroundWorkTask.Status.QUEUED, "暂停时 CPU 工作应留在等待队列。")
	assert_eq(queued_ids, PackedStringArray(["high", "front", "first"]), "等待队列应按 priority 和 front 排序。")
	assert_eq(priority_entries.size(), 3, "调试快照应提供不含任务对象的优先级摘要。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(priority_entries[0]), "work_id"), "high", "优先级摘要应与当前仲裁顺序一致。")
	assert_eq(GFVariantData.get_option_int(snapshot, "priority_aging_interval_msec"), 250, "调试快照应公开实际老化区间。")
	assert_eq(GFVariantData.get_option_float(snapshot, "priority_aging_step"), 2.0, "调试快照应公开实际老化步长。")
	assert_same(high_priority, utility.get_task(&"high"), "自定义 ID 应可取回对应任务。")
	assert_true(utility.cancel_work(front.work_id), "等待任务应可取消。")
	assert_eq(front.status, GFBackgroundWorkTask.Status.CANCELLED, "取消后应进入 cancelled。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "queued_count"), 2, "取消等待任务后队列应移除该任务。")
	utility.cancel_all()
	utility.dispose()


func test_background_dispatch_ages_old_work_and_snapshot_is_pure_and_time_consistent() -> void:
	var utility: SimulatedTimeBackgroundWorkUtility = SimulatedTimeBackgroundWorkUtility.new()
	utility.max_threaded_tasks = 1
	utility.priority_aging_interval_msec = 1000
	utility.priority_aging_step = 10.0
	utility.init()
	utility.pause()
	var worker: PureWorker = PureWorker.new()
	var started_ids: Array[String] = []
	var connect_error: Error = utility.work_started.connect(func(task: GFBackgroundWorkTask) -> void:
		started_ids.append(String(task.work_id))
	) as Error
	assert_eq(connect_error, OK, "测试应能观察实际调度顺序。")

	utility.now_msec = 0
	var old_low: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{ "value": 1 },
		Callable(),
		{ &"id": "old-low", &"priority": 0 }
	)
	utility.now_msec = 2000
	var new_high: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "double_value"),
		{ "value": 2 },
		Callable(),
		{ &"id": "new-high", &"priority": 15 }
	)
	utility.now_call_count = 0
	var snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(utility.now_call_count, 1, "单份调试快照应只采样一次仲裁时间。")
	assert_eq(GFVariantData.get_option_packed_string_array(snapshot, "queued_ids"), PackedStringArray(["old-low", "new-high"]), "快照应反映老化后的实际调度顺序。")
	assert_false(_contains_object(snapshot), "公开调试快照不得泄漏任务、线程或其它 Object。")
	assert_false(JSON.stringify(snapshot).is_empty(), "纯数据调试快照应可直接编码为 JSON。")

	utility.resume()

	assert_eq(started_ids, ["old-low"], "长期等待的低优先工作应在实际后台调度中先获得执行机会。")
	assert_eq(old_low.status, GFBackgroundWorkTask.Status.RUNNING, "老化胜出的任务应进入运行状态。")
	assert_eq(new_high.status, GFBackgroundWorkTask.Status.QUEUED, "较新的高优先任务应继续等待当前槽位。")

	await _pump_until_finished(utility, old_low)
	await _pump_until_finished(utility, new_high)
	assert_eq(started_ids, ["old-low", "new-high"], "释放槽位后应继续执行剩余任务。")
	utility.dispose()


func test_clear_all_waits_for_active_thread_task() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var worker: PureWorker = PureWorker.new()

	var task: GFBackgroundWorkTask = utility.submit_cpu_work(
		Callable(worker, "slow_value"),
		{"value": 7}
	)
	assert_eq(task.status, GFBackgroundWorkTask.Status.RUNNING, "提交后线程工作应立即进入运行状态。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "running_thread_count"), 1, "清理前应保留 active thread 句柄。")

	utility.clear_all()

	assert_eq(task.status, GFBackgroundWorkTask.Status.CANCELLED, "clear_all 应先取消并等待 active thread 完成。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "running_thread_count"), 0, "clear_all 后不应残留 active thread。")
	utility.dispose()


func test_resource_load_uses_threaded_resource_loader_and_applies_on_tick() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	var _broker: GFResourceBroker = utility.setup_standalone_resource_broker()

	var task: GFBackgroundWorkTask = utility.submit_resource_load(
		"res://addons/gf/standard/utilities/jobs/gf_job.gd",
		"Script",
		Callable(self, "_apply_resource")
	)

	await _pump_until_finished(utility, task, 180)

	assert_eq(task.status, GFBackgroundWorkTask.Status.COMPLETED, "资源线程加载应完成。")
	assert_false(_is_null(task.result), "资源加载结果不应为空。")
	assert_true(task.result is Script, "测试资源应作为 Script 加载。")
	assert_same(_applied_resource, _resource_value(task.result), "主线程应用应收到同一资源。")
	utility.dispose()


func test_cancelled_resource_load_drains_late_completion_without_apply() -> void:
	var utility: SimulatedResourceBackgroundWorkUtility = SimulatedResourceBackgroundWorkUtility.new()
	utility.init()
	var task: GFBackgroundWorkTask = utility.submit_resource_load(
		"res://simulated_resource.tres",
		"Resource",
		Callable(self, "_apply_resource")
	)

	assert_true(utility.cancel_work(task.work_id), "运行中的资源任务应接受取消请求。")
	assert_eq(task.status, GFBackgroundWorkTask.Status.RUNNING, "底层请求完成前任务仍等待 drain。")

	utility.complete = true
	utility.tick()
	var snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(task.status, GFBackgroundWorkTask.Status.CANCELLED, "迟到完成 drain 后任务应进入 cancelled。")
	assert_null(_applied_resource, "取消后的资源任务不应执行主线程 apply。")
	assert_eq(utility.requested_count, 1, "取消不应重复发起底层请求。")
	assert_eq(GFVariantData.get_option_int(snapshot, "resource_request_count"), 0, "drain 后不应残留资源请求。")
	utility.dispose()


func test_same_path_submission_reacquires_lease_after_previous_task_cancels() -> void:
	var utility: SimulatedResourceBackgroundWorkUtility = SimulatedResourceBackgroundWorkUtility.new()
	utility.init()
	var first: GFBackgroundWorkTask = utility.submit_resource_load(
		"res://simulated_resource.tres",
		"Resource",
		Callable(),
		{ "id": &"cancelled_resource" }
	)
	assert_true(utility.cancel_work(first.work_id))

	var second: GFBackgroundWorkTask = utility.submit_resource_load(
		"res://simulated_resource.tres",
		"Resource",
		Callable(self, "_apply_resource"),
		{ "id": &"replacement_resource" }
	)

	assert_eq(
		utility.lease_request_count,
		2,
		"本地 request 尚未由 tick 清除时，新任务仍必须取得独立的新 Lease。"
	)
	assert_eq(second.status, GFBackgroundWorkTask.Status.RUNNING)

	utility.complete = true
	utility.tick()
	utility.tick()

	assert_eq(first.status, GFBackgroundWorkTask.Status.CANCELLED)
	assert_eq(second.status, GFBackgroundWorkTask.Status.COMPLETED)
	assert_same(_applied_resource, utility.loaded_resource)
	assert_eq(utility.requested_count, 1, "重新取得 Lease 应继续复用同一个底层请求。")
	utility.dispose()


func test_apply_queue_respects_time_budget_after_first_callback() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
	utility.init()
	utility.max_apply_per_tick = 8
	utility.max_apply_seconds_per_tick = 0.000001

	var first: GFBackgroundWorkTask = _make_apply_task(&"first")
	var second: GFBackgroundWorkTask = _make_apply_task(&"second")
	utility._tasks[first.work_id] = first
	utility._tasks[second.work_id] = second
	utility._apply_queue.append(first)
	utility._apply_queue.append(second)

	utility.tick()

	assert_eq(_slow_apply_count, 1, "时间预算启用时同一帧至少执行一个 apply。")
	assert_eq(first.status, GFBackgroundWorkTask.Status.COMPLETED, "第一个 apply 应完成。")
	assert_eq(second.status, GFBackgroundWorkTask.Status.APPLYING, "超出时间预算后应保留后续 apply。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "apply_count"), 1, "后续 apply 应留在队列中。")

	utility.max_apply_seconds_per_tick = 0.0
	utility.tick()

	assert_eq(_slow_apply_count, 2, "关闭时间预算后应继续处理剩余 apply。")
	assert_eq(second.status, GFBackgroundWorkTask.Status.COMPLETED, "第二个 apply 应完成。")
	utility.dispose()


# --- 私有/辅助方法 ---

func _apply_value(task: GFBackgroundWorkTask) -> bool:
	var result: Dictionary = GFVariantData.as_dictionary(task.result)
	_applied_value = GFVariantData.get_option_int(result, "value")
	return true


func _apply_slow_task(_task: Variant) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started_usec < 2000:
		pass
	_slow_apply_count += 1
	return true


func _apply_resource(task: GFBackgroundWorkTask) -> bool:
	if task.result is Resource:
		_applied_resource = task.result
	else:
		_applied_resource = null
	return _applied_resource != null


func _resource_value(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _is_null(value: Variant) -> bool:
	return value == null


func _variant_is_true(value: Variant) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false


func _weak_ref_is_alive(weak_ref_value: WeakRef) -> bool:
	var target: Variant = weak_ref_value.get_ref()
	return target is Object


func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Array:
		for item: Variant in GFVariantData.as_array(value):
			if _contains_object(item):
				return true
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		for key: Variant in dictionary.keys():
			if _contains_object(key) or _contains_object(dictionary[key]):
				return true
	return false


func _make_apply_task(work_id: StringName) -> GFBackgroundWorkTask:
	var task: GFBackgroundWorkTask = GFBackgroundWorkTask.new()
	task.work_id = work_id
	task.kind = GFBackgroundWorkTask.Kind.CPU
	task.status = GFBackgroundWorkTask.Status.APPLYING
	task.set_internal_callbacks(Callable(), Callable(self, "_apply_slow_task"))
	return task


func _submit_scoped_callbacks(utility: GFBackgroundWorkUtility) -> ScopedCallbackSubmission:
	var worker: ScopedWorker = ScopedWorker.new()
	var apply_receiver: ScopedApplyReceiver = ScopedApplyReceiver.new()
	var submission: ScopedCallbackSubmission = ScopedCallbackSubmission.new()
	submission.worker_weak_ref = weakref(worker)
	submission.apply_weak_ref = weakref(apply_receiver)
	submission.task = utility.submit_io_work(
		Callable(worker, "produce_value"),
		{ "value": 31 },
		Callable(apply_receiver, "apply_value")
	)
	return submission


func _submit_scoped_failure(
	utility: GFBackgroundWorkUtility
) -> ScopedCallbackSubmission:
	var worker: ScopedFailingWorker = ScopedFailingWorker.new()
	var apply_receiver: ScopedApplyReceiver = ScopedApplyReceiver.new()
	var submission: ScopedCallbackSubmission = ScopedCallbackSubmission.new()
	submission.worker_weak_ref = weakref(worker)
	submission.apply_weak_ref = weakref(apply_receiver)
	submission.task = utility.submit_io_work(
		Callable(worker, "fail_value"),
		{},
		Callable(apply_receiver, "apply_value")
	)
	return submission


func _submit_shared_callback_target(
	utility: GFBackgroundWorkUtility
) -> ScopedCallbackSubmission:
	var target: ScopedDualCallbackTarget = ScopedDualCallbackTarget.new()
	var submission: ScopedCallbackSubmission = ScopedCallbackSubmission.new()
	submission.worker_weak_ref = weakref(target)
	submission.apply_weak_ref = submission.worker_weak_ref
	submission.task = utility.submit_io_work(
		Callable(target, "produce_value"),
		{ "value": 31 },
		Callable(target, "apply_value")
	)
	return submission


func _pump_until_finished(
	utility: GFBackgroundWorkUtility,
	task: GFBackgroundWorkTask,
	max_frames: int = 120
) -> void:
	for _frame: int in range(max_frames):
		utility.tick()
		if task.is_finished():
			return
		await get_tree().process_frame
	utility.tick()


func _wait_for_worker_entry(worker: CooperativeWorker, max_frames: int = 120) -> bool:
	for _frame: int in range(max_frames):
		if worker.has_entered():
			return true
		await get_tree().process_frame
	return worker.has_entered()


func _wait_for_worker_return(worker: CooperativeWorker, max_frames: int = 120) -> bool:
	for _frame: int in range(max_frames):
		if worker.has_returned():
			return true
		await get_tree().process_frame
	return worker.has_returned()


# --- 内部类 ---

class PureWorker:
	extends RefCounted

	func double_value(data: Variant) -> Dictionary:
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return {
			"value": GFVariantData.get_option_int(input, "value") * 2,
		}

	func fail_work(_data: Variant) -> Dictionary:
		return {
			"ok": false,
			"error": "worker_failed",
		}

	func fail_work_with_message(_data: Variant) -> Dictionary:
		return {
			"ok": false,
			"message": "message_failed",
		}

	func slow_value(data: Variant) -> Dictionary:
		OS.delay_msec(20)
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return {
			"value": GFVariantData.get_option_int(input, "value"),
		}


class CooperativeWorker:
	extends RefCounted

	const _FALLBACK_MSEC: int = 2000

	var _mutex: Mutex = Mutex.new()
	var _entered: bool = false
	var _returned: bool = false
	var _timed_out: bool = false
	var _call_count: int = 0
	var _last_work_id: StringName = &""
	var _observed_reason: GFBackgroundWorkContext.CancellationReason = (
		GFBackgroundWorkContext.CancellationReason.NONE
	)

	func return_with_context(
		data: Variant,
		context: GFBackgroundWorkContext
	) -> Dictionary:
		_record_entry(context)
		_record_return(false, context.get_cancel_reason())
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return { "value": GFVariantData.get_option_int(input, "value") }

	func wait_for_cancel(
		data: Variant,
		context: GFBackgroundWorkContext
	) -> Dictionary:
		_record_entry(context)
		var deadline_msec: int = Time.get_ticks_msec() + _FALLBACK_MSEC
		while not context.is_cancel_requested() and Time.get_ticks_msec() < deadline_msec:
			OS.delay_msec(1)
		var timed_out: bool = not context.is_cancel_requested()
		_record_return(timed_out, context.get_cancel_reason())
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return { "value": GFVariantData.get_option_int(input, "value") }

	func has_entered() -> bool:
		_mutex.lock()
		var entered: bool = _entered
		_mutex.unlock()
		return entered

	func has_returned() -> bool:
		_mutex.lock()
		var returned: bool = _returned
		_mutex.unlock()
		return returned

	func did_time_out() -> bool:
		_mutex.lock()
		var timed_out: bool = _timed_out
		_mutex.unlock()
		return timed_out

	func get_call_count() -> int:
		_mutex.lock()
		var call_count: int = _call_count
		_mutex.unlock()
		return call_count

	func get_last_work_id() -> StringName:
		_mutex.lock()
		var work_id: StringName = _last_work_id
		_mutex.unlock()
		return work_id

	func get_observed_reason() -> GFBackgroundWorkContext.CancellationReason:
		_mutex.lock()
		var reason: GFBackgroundWorkContext.CancellationReason = _observed_reason
		_mutex.unlock()
		return reason

	func _record_entry(context: GFBackgroundWorkContext) -> void:
		_mutex.lock()
		_entered = true
		_call_count += 1
		_last_work_id = context.get_work_id()
		_mutex.unlock()

	func _record_return(
		timed_out: bool,
		reason: GFBackgroundWorkContext.CancellationReason
	) -> void:
		_mutex.lock()
		_timed_out = timed_out
		_observed_reason = reason
		_returned = true
		_mutex.unlock()


class ScopedCallbackSubmission:
	extends RefCounted

	var task: GFBackgroundWorkTask
	var worker_weak_ref: WeakRef
	var apply_weak_ref: WeakRef


class ScopedWorker:
	extends RefCounted

	func produce_value(data: Variant) -> Dictionary:
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return {
			"value": GFVariantData.get_option_int(input, "value"),
		}


class ScopedFailingWorker:
	extends RefCounted

	func fail_value(_data: Variant) -> Dictionary:
		return {
			"ok": false,
			"error": "scoped_worker_failed",
		}


class ScopedApplyReceiver:
	extends RefCounted

	func apply_value(task: GFBackgroundWorkTask) -> bool:
		var result: Dictionary = GFVariantData.as_dictionary(task.result)
		return GFVariantData.get_option_int(result, "value") == 31


class ScopedDualCallbackTarget:
	extends RefCounted

	func produce_value(data: Variant) -> Dictionary:
		var input: Dictionary = GFVariantData.as_dictionary(data)
		return {
			"value": GFVariantData.get_option_int(input, "value"),
		}

	func apply_value(task: GFBackgroundWorkTask) -> bool:
		var result: Dictionary = GFVariantData.as_dictionary(task.result)
		return GFVariantData.get_option_int(result, "value") == 31


class SimulatedResourceBackgroundWorkUtility extends GFBackgroundWorkUtility:
	var _broker: SimulatedResourceBroker = SimulatedResourceBroker.new()
	var requested_count: int:
		get:
			return _broker.requested_count
	var lease_request_count: int:
		get:
			return _broker.lease_request_count
	var complete: bool:
		get:
			return _broker.complete
		set(value):
			_broker.complete = value
	var loaded_resource: Resource:
		get:
			return _broker.loaded_resource
		set(value):
			_broker.loaded_resource = value

	func init() -> void:
		super.init()
		_broker.init()
		var _bind_error: Error = set_resource_broker(_broker)


class SimulatedResourceBroker extends GFResourceBroker:
	var requested_count: int = 0
	var lease_request_count: int = 0
	var complete: bool = false
	var loaded_resource: Resource = Resource.new()

	func request(path: String, type_hint: String = "", options: Dictionary = {}) -> GFResourceLease:
		lease_request_count += 1
		return super.request(path, type_hint, options)

	func _request_threaded_resource(_path: String, _type_hint: String) -> Error:
		requested_count += 1
		return OK

	func _poll_threaded_resource(_path: String, previous_progress: float) -> Dictionary:
		return {
			"status": &"loaded" if complete else &"in_progress",
			"progress": 1.0 if complete else previous_progress,
			"resource": loaded_resource if complete else null,
			"has_resource": complete,
			"error": "",
		}


class SimulatedTimeBackgroundWorkUtility extends GFBackgroundWorkUtility:
	var now_msec: int = 0
	var now_call_count: int = 0

	func _get_now_msec() -> int:
		now_call_count += 1
		return now_msec
