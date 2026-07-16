## 测试 GFJobQueueUtility 的通用任务队列行为。
extends GutTest


const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


func test_job_queue_lifecycle_progress_and_snapshot() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	watch_signals(utility)

	var job: GFJob = utility.enqueue(&"import", {"path": "res://data.json"}, {"kind": "json"})
	assert_eq(job.status, GFJob.Status.WAITING, "新任务应进入 waiting 状态。")
	assert_signal_emitted(utility, "job_enqueued", "入队时应发出信号。")

	var started: GFJob = utility.start_next_job(&"import")
	assert_same(started, job, "start_next_job 应取出队列头任务。")
	assert_eq(job.status, GFJob.Status.ACTIVE, "启动后任务应进入 active 状态。")
	assert_signal_emitted(utility, "job_started", "启动时应发出信号。")

	assert_true(utility.update_job_progress(job.job_id, 0.5, "half"), "执行中任务应允许更新进度。")
	assert_almost_eq(job.progress, 0.5, 0.001, "进度应写入任务。")
	assert_signal_emitted(utility, "job_progressed", "更新进度时应发出信号。")

	assert_true(utility.complete_job(job.job_id, {"ok": true}), "执行中任务应允许完成。")
	assert_eq(job.status, GFJob.Status.COMPLETED, "完成后任务应进入 completed 状态。")
	assert_true(job.is_finished(), "完成任务应进入终态。")
	assert_signal_emitted(utility, "job_completed", "完成时应发出信号。")

	var snapshot: Dictionary = utility.get_debug_snapshot()
	var job_data: Dictionary = job.to_dict()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(job_data, "metadata")
	assert_eq(GFVariantData.get_option_int(snapshot, "completed_count"), 1, "调试快照应统计完成任务。")
	assert_eq(GFVariantData.get_option_string(metadata, "kind"), "json", "任务字典应保留 metadata。")
	utility.dispose()


func test_job_queue_pause_cancel_and_run_failure() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()

	var waiting: GFJob = utility.enqueue(&"main", null)
	utility.pause_queue(&"main")
	assert_null(utility.start_next_job(&"main"), "暂停队列不应启动任务。")
	utility.resume_queue(&"main")
	assert_true(utility.cancel_job(waiting.job_id), "等待任务应可取消。")
	assert_eq(waiting.status, GFJob.Status.CANCELLED, "取消后任务应进入 cancelled 状态。")

	var failed: GFJob = utility.enqueue(&"main", null)
	var processed: GFJob = utility.run_next_job(&"main", func(_job: GFJob) -> Dictionary:
		return {"ok": false, "error": "failed"}
	)

	assert_same(processed, failed, "run_next_job 应处理下一个任务。")
	assert_eq(failed.status, GFJob.Status.FAILED, "处理器返回 ok=false 时应标记失败。")
	assert_eq(failed.error_message, "failed", "失败错误文本应写入任务。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "failed_count"), 1, "调试快照应统计失败任务。")
	utility.dispose()


func test_clear_all_cancels_active_jobs_before_dropping_registry() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	watch_signals(utility)
	var job: GFJob = utility.enqueue(&"main", null)
	var started: GFJob = utility.start_next_job(&"main")

	utility.clear_all()

	assert_same(started, job, "测试应先启动同一个任务。")
	assert_eq(job.status, GFJob.Status.CANCELLED, "clear_all 应把 active job 标记为 cancelled。")
	assert_true(job.is_finished(), "clear_all 后调用方持有的 active job 应进入终态。")
	assert_signal_emitted(utility, "job_cancelled", "clear_all 取消 active job 时应发出终态信号。")
	assert_null(utility.get_job(job.job_id), "clear_all 后 registry 应清空。")
	utility.dispose()


func test_job_worker_processes_queue_batch() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var first: GFJob = utility.enqueue(&"main", { "value": 1 })
	var second: GFJob = utility.enqueue(&"main", { "value": 2 })

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.batch_size = 2
	worker.set_queue_utility(utility)
	worker.set_processor(func(job: GFJob) -> Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(job.data)
		return {
			"ok": true,
			"value": GFVariantData.get_option_int(data, "value") * 2,
		}
	)
	worker.start()

	var processed_count: int = await worker.process_batch()

	assert_eq(processed_count, 2, "Worker 应按 batch_size 消费等待任务。")
	assert_eq(first.status, GFJob.Status.COMPLETED, "第一个任务应完成。")
	assert_eq(second.status, GFJob.Status.COMPLETED, "第二个任务应完成。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.as_dictionary(second.result), "value"), 4, "处理器结果应写回任务。")
	worker.free()
	utility.dispose()


func test_job_worker_applies_async_processor_result() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var job: GFJob = utility.enqueue(&"main", { "value": 1 })
	var processor: AsyncFailingProcessor = AsyncFailingProcessor.new()

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.set_queue_utility(utility)
	worker.set_processor(Callable(processor, "process"))

	var processed_job: GFJob = await worker.process_next_job()

	assert_same(processed_job, job, "Worker 应等待异步处理器完成当前任务。")
	assert_eq(job.status, GFJob.Status.FAILED, "异步处理器返回 ok=false 时应标记失败。")
	assert_eq(job.error_message, "async_failed", "异步失败原因应写入任务。")
	worker.free()
	utility.dispose()


func test_job_worker_times_out_stuck_async_processor() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var job: GFJob = utility.enqueue(&"main", { "value": 1 })
	var processor: NeverFinishingProcessor = NeverFinishingProcessor.new()

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.signal_timeout_seconds = 0.001
	worker.set_queue_utility(utility)
	worker.set_processor(Callable(processor, "process"))

	var processed_job: GFJob = await worker.process_next_job()

	assert_same(processed_job, job, "Worker 超时后仍应返回当前任务。")
	assert_eq(job.status, GFJob.Status.FAILED, "处理器 Signal 超时应把任务标记失败，避免队列永久卡住。")
	assert_eq(job.error_message, "processor_signal_timeout", "超时失败原因应稳定可诊断。")
	assert_push_warning("[GFJobWorker] 等待任务处理器 Signal 超时，任务将标记为失败。")
	worker.free()
	utility.dispose()


func test_job_worker_stop_cancels_unbounded_processor_wait() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var job: GFJob = utility.enqueue(&"main", { "value": 1 })
	var processor: NeverFinishingProcessor = NeverFinishingProcessor.new()

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.signal_timeout_seconds = 0.0
	worker.set_queue_utility(utility)
	worker.set_processor(Callable(processor, "process"))
	add_child(worker)
	worker.start()
	worker.call_deferred("stop")

	var processed_count: int = await worker.process_batch()

	assert_eq(processed_count, 1, "停止时应结束当前等待并返回已取出的任务数量。")
	assert_eq(job.status, GFJob.Status.CANCELLED, "停止 worker 应取消仍在等待处理器 Signal 的任务。")
	assert_false(GFVariantData.get_option_bool(worker.get_debug_snapshot(), "processing", true), "停止后不得残留 processing 状态。")
	remove_child(worker)
	worker.free()
	utility.dispose()


func test_job_worker_rejects_concurrent_process_next_job_without_losing_wait_owner() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var first_job: GFJob = utility.enqueue(&"main", { "value": 1 })
	var second_job: GFJob = utility.enqueue(&"main", { "value": 2 })
	var processor: NeverFinishingProcessor = NeverFinishingProcessor.new()

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.signal_timeout_seconds = 0.0
	worker.set_queue_utility(utility)
	worker.set_processor(Callable(processor, "process"))
	add_child(worker)
	worker.start()
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(worker, "process_next_job"))

	for _active_frame_index: int in range(10):
		if GFVariantData.get_option_bool(worker.get_debug_snapshot(), "processing_next_job"):
			break
		await get_tree().process_frame
	var concurrent_result: GFJob = await worker.process_next_job()
	worker.stop()
	for _completion_frame_index: int in range(10):
		if not GFVariantData.get_option_bool(worker.get_debug_snapshot(), "processing_next_job"):
			break
		await get_tree().process_frame

	assert_null(concurrent_result, "同一个 worker 的并发 process_next_job 应被 single-flight guard 拒绝。")
	assert_eq(first_job.status, GFJob.Status.CANCELLED, "stop 应取消唯一在途等待。")
	assert_eq(second_job.status, GFJob.Status.WAITING as GFJob.Status, "被拒绝的并发调用不得领取第二个任务。")
	assert_false(GFVariantData.get_option_bool(worker.get_debug_snapshot(), "processing_next_job", true), "取消完成后不得残留在途标记。")
	remove_child(worker)
	worker.free()
	utility.dispose()


func test_job_worker_does_not_emit_processed_for_cancelled_async_job() -> void:
	var utility: GFJobQueueUtility = GFJobQueueUtility.new()
	utility.init()
	var job: GFJob = utility.enqueue(&"main", { "value": 1 })
	var processor: ManualAsyncProcessor = ManualAsyncProcessor.new()

	var worker: GFJobWorker = GFJobWorker.new()
	worker.auto_start = false
	worker.queue_name = &"main"
	worker.set_queue_utility(utility)
	worker.set_processor(Callable(processor, "process"))
	watch_signals(worker)
	add_child(worker)
	worker.start()

	for _active_frame_index: int in range(10):
		if job.status == GFJob.Status.ACTIVE:
			break
		await get_tree().process_frame
	assert_eq(job.status, GFJob.Status.ACTIVE, "异步处理器等待期间任务应处于 active。")

	assert_true(utility.cancel_job(job.job_id), "active 异步任务应可取消。")
	processor.complete({ "ok": true })
	for _completion_frame_index: int in range(10):
		if not GFVariantData.get_option_bool(worker.get_debug_snapshot(), "processing", false):
			break
		await get_tree().process_frame

	assert_eq(job.status, GFJob.Status.CANCELLED, "迟到 signal 不应覆盖 cancelled 终态。")
	assert_signal_emit_count(worker, "job_processed", 0, "取消任务不应再发 job_processed。")
	worker.stop()
	remove_child(worker)
	worker.free()
	utility.dispose()


# --- 内部类 ---

class AsyncFailingProcessor:
	extends RefCounted

	signal finished(result: Dictionary)

	func process(_job: GFJob) -> Signal:
		call_deferred("_emit_failure")
		return finished

	func _emit_failure() -> void:
		finished.emit({ "ok": false, "error": "async_failed" })


class NeverFinishingProcessor:
	extends RefCounted

	signal finished(result: Dictionary)

	func process(_job: GFJob) -> Signal:
		return finished


class ManualAsyncProcessor:
	extends RefCounted

	signal finished(result: Dictionary)

	func process(_job: GFJob) -> Signal:
		return finished

	func complete(result: Dictionary) -> void:
		finished.emit(result)
