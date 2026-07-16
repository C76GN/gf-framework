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


func test_pause_and_cancel_waiting_thread_task() -> void:
	var utility: GFBackgroundWorkUtility = GFBackgroundWorkUtility.new()
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
	var queued_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(utility.get_debug_snapshot(), "queued_ids")

	assert_eq(first.status, GFBackgroundWorkTask.Status.QUEUED, "暂停时 CPU 工作应留在等待队列。")
	assert_eq(queued_ids, PackedStringArray(["high", "front", "first"]), "等待队列应按 priority 和 front 排序。")
	assert_same(high_priority, utility.get_task(&"high"), "自定义 ID 应可取回对应任务。")
	assert_true(utility.cancel_work(front.work_id), "等待任务应可取消。")
	assert_eq(front.status, GFBackgroundWorkTask.Status.CANCELLED, "取消后应进入 cancelled。")
	assert_eq(GFVariantData.get_option_int(utility.get_debug_snapshot(), "queued_count"), 2, "取消等待任务后队列应移除该任务。")
	utility.cancel_all()
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


func _make_apply_task(work_id: StringName) -> GFBackgroundWorkTask:
	var task: GFBackgroundWorkTask = GFBackgroundWorkTask.new()
	task.work_id = work_id
	task.kind = GFBackgroundWorkTask.Kind.CPU
	task.status = GFBackgroundWorkTask.Status.APPLYING
	task.set_internal_callbacks(Callable(), Callable(self, "_apply_slow_task"))
	return task


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


class SimulatedResourceBackgroundWorkUtility extends GFBackgroundWorkUtility:
	var requested_count: int = 0
	var complete: bool = false
	var loaded_resource: Resource = Resource.new()

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
