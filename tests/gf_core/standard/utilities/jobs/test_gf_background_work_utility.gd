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
