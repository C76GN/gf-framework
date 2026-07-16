## GFBackgroundWorkUtility: 纯数据后台工作协调器。
##
## 统一协调 CPU/IO 线程工作、ResourceLoader 线程加载和主线程应用回调。
## 默认只允许纯 Variant 输入数据，避免后台线程直接触碰 Node、Resource 或 Callable。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFBackgroundWorkUtility
extends GFUtility


# --- 信号 ---

## 工作进入等待队列时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_queued(task: GFBackgroundWorkTask)

## 工作开始执行时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_started(task: GFBackgroundWorkTask)

## 工作进度变化时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
## [br]
## @param progress: 当前进度。
## [br]
## @param message: 进度说明。
signal work_progressed(task: GFBackgroundWorkTask, progress: float, message: String)

## 工作完成时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_completed(task: GFBackgroundWorkTask)

## 工作失败时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_failed(task: GFBackgroundWorkTask)

## 工作取消时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_cancelled(task: GFBackgroundWorkTask)

## 工作结果已在主线程应用时发出。
## [br]
## @api public
## [br]
## @param task: 工作记录。
signal work_applied(task: GFBackgroundWorkTask)


# --- 常量 ---

const _MAX_PAYLOAD_DEPTH: int = 64
const _GF_PRIORITY_QUEUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_priority_queue.gd")
const _THREADED_RESOURCE_LOAD_ADAPTER = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")
const _THREADED_RESOURCE_COORDINATOR_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_coordinator.gd")
const _THREADED_RESOURCE_OPERATION_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_operation.gd")


# --- 公共变量 ---

## 同时运行的 CPU/IO 线程任务上限。
## [br]
## @api public
var max_threaded_tasks: int = 2:
	set(value):
		max_threaded_tasks = maxi(value, 1)
		_start_queued_thread_tasks()

## 单帧最多执行多少个主线程应用回调。
## [br]
## @api public
var max_apply_per_tick: int = 8:
	set(value):
		max_apply_per_tick = maxi(value, 1)

## 单帧主线程应用回调的最大秒数。小于等于 0 时不启用时间预算；启用时每帧仍至少尝试一个应用回调。
## [br]
## @api public
var max_apply_seconds_per_tick: float = 0.0:
	set(value):
		max_apply_seconds_per_tick = maxf(value, 0.0)

## 最多保留多少个终态任务用于调试快照；设为 0 时不保留历史。
## [br]
## @api public
var max_finished_tasks: int = 128:
	set(value):
		max_finished_tasks = maxi(value, 0)
		_trim_finished_tasks()

## 是否默认允许 Object、Resource、Callable、Signal 或 RID 进入线程 payload。
## 仅迁移旧项目或明确自行保证线程安全时才建议开启。
## [br]
## @api public
var allow_object_payloads: bool = false


# --- 私有变量 ---

var _work_serial: int = 0
var _tasks: Dictionary = {}
var _queued_thread_tasks: _GF_PRIORITY_QUEUE_SCRIPT = _GF_PRIORITY_QUEUE_SCRIPT.new()
var _active_thread_tasks: Dictionary = {}
var _resource_requests: Dictionary = {}
var _apply_queue: Array = []
var _finished_tasks: Array = []
var _paused: bool = false
var _threaded_resource_coordinator: _THREADED_RESOURCE_COORDINATOR_SCRIPT = _THREADED_RESOURCE_COORDINATOR_SCRIPT.new()


# --- GF 生命周期方法 ---

## 初始化后台工作协调器并启用暂停无关处理。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	_threaded_resource_coordinator.configure(
		Callable(self, "_request_threaded_resource"),
		Callable(self, "_poll_threaded_resource")
	)
	clear_all()


## 推进后台工作完成检查与主线程应用。
## [br]
## @api public
## [br]
## @param _delta: 为兼容统一 tick 签名而保留的参数。
func tick(_delta: float = 0.0) -> void:
	_poll_thread_tasks()
	_poll_resource_requests()
	_drain_cancelled_threaded_operations()
	_process_apply_queue()
	_start_queued_thread_tasks()


## 取消未完成工作、等待线程结束并清理运行时状态。
## [br]
## @api public
func dispose() -> void:
	cancel_all()
	_wait_for_active_thread_tasks()
	clear_all()


# --- 公共方法 ---

## 提交 CPU 纯数据后台工作。
## [br]
## @param worker: 后台线程回调，签名推荐为 func(input_data: Variant) -> Variant。
## [br]
## @param input_data: 输入数据。默认只允许纯 Variant 容器和值。
## [br]
## @param apply_callback: 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。
## [br]
## @param options: 可选配置，支持 id、priority、metadata、front、allow_object_payloads。
## [br]
## @return 工作记录；参数无效时返回 failed 状态任务。
## [br]
## @api public
## [br]
## @schema input_data: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
## [br]
## @schema options: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool 和 allow_object_payloads: bool。
func submit_cpu_work(
	worker: Callable,
	input_data: Variant = null,
	apply_callback: Callable = Callable(),
	options: Dictionary = {}
) -> GFBackgroundWorkTask:
	return _submit_threaded_work(GFBackgroundWorkTask.Kind.CPU, worker, input_data, apply_callback, options)


## 提交 IO 纯数据后台工作。
## [br]
## @param worker: 后台线程回调，签名推荐为 func(input_data: Variant) -> Variant。
## [br]
## @param input_data: 输入数据。默认只允许纯 Variant 容器和值。
## [br]
## @param apply_callback: 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。
## [br]
## @param options: 可选配置，支持 id、priority、metadata、front、allow_object_payloads。
## [br]
## @return 工作记录；参数无效时返回 failed 状态任务。
## [br]
## @api public
## [br]
## @schema input_data: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
## [br]
## @schema options: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool 和 allow_object_payloads: bool。
func submit_io_work(
	worker: Callable,
	input_data: Variant = null,
	apply_callback: Callable = Callable(),
	options: Dictionary = {}
) -> GFBackgroundWorkTask:
	return _submit_threaded_work(GFBackgroundWorkTask.Kind.IO, worker, input_data, apply_callback, options)


## 提交 ResourceLoader 后台资源加载。
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选资源类型提示。
## [br]
## @param apply_callback: 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。
## [br]
## @param options: 可选配置，支持 id、priority、metadata。
## [br]
## @return 工作记录；参数无效或请求失败时返回 failed 状态任务。
## [br]
## @api public
## [br]
## @schema options: Dictionary，包含 id: StringName/String、priority: int 和 metadata: Dictionary。
func submit_resource_load(
	path: String,
	type_hint: String = "",
	apply_callback: Callable = Callable(),
	options: Dictionary = {}
) -> GFBackgroundWorkTask:
	var task: GFBackgroundWorkTask = _create_task(GFBackgroundWorkTask.Kind.RESOURCE, Callable(), apply_callback, options)
	task.resource_path = path
	task.resource_type_hint = type_hint

	if path.is_empty():
		_fail_task(task, "[GFBackgroundWorkUtility] submit_resource_load 失败：资源路径为空。")
		return task

	if not _register_task(task):
		_fail_task(task, "[GFBackgroundWorkUtility] submit_resource_load 失败：工作 ID 已存在。")
		return task

	work_queued.emit(task)
	_start_resource_task(task)
	return task


## 取消指定工作。
## [br]
## @api public
## [br]
## @param work_id: 工作 ID。
## [br]
## @return 取消成功返回 true。
func cancel_work(work_id: StringName) -> bool:
	var task: GFBackgroundWorkTask = get_task(work_id)
	if task == null or task.is_finished():
		return false

	task.cancel_requested = true
	if task.kind == GFBackgroundWorkTask.Kind.RESOURCE and task.status == GFBackgroundWorkTask.Status.RUNNING:
		_release_resource_operation_for_task(task, &"resource_work_cancelled")
		return true
	if task.status == GFBackgroundWorkTask.Status.QUEUED:
		var _removed_queued_task: bool = _queued_thread_tasks.remove_value(task)
		_cancel_task(task)
		return true

	if task.status == GFBackgroundWorkTask.Status.APPLYING:
		_apply_queue.erase(task)
		_cancel_task(task)
		return true

	return true


## 取消全部未完成工作。
## [br]
## @api public
func cancel_all() -> void:
	var task_values: Array = _tasks.values()
	for task_variant: Variant in task_values:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.is_finished():
			var _cancelled: bool = cancel_work(task.work_id)


## 暂停启动新的 CPU/IO 线程工作；已运行和资源加载中的工作会继续推进。
## [br]
## @api public
func pause() -> void:
	_paused = true


## 恢复启动新的 CPU/IO 线程工作。
## [br]
## @api public
func resume() -> void:
	_paused = false
	_start_queued_thread_tasks()


## 检查是否暂停。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_paused() -> bool:
	return _paused


## 更新工作进度。
## [br]
## @api public
## [br]
## @param work_id: 工作 ID。
## [br]
## @param progress: 当前进度。
## [br]
## @param message: 进度说明。
## [br]
## @return 更新成功返回 true。
func update_work_progress(work_id: StringName, progress: float, message: String = "") -> bool:
	var task: GFBackgroundWorkTask = get_task(work_id)
	if task == null or task.is_finished():
		return false
	task.progress = clampf(progress, 0.0, 1.0)
	work_progressed.emit(task, task.progress, message)
	return true


## 获取工作。
## [br]
## @api public
## [br]
## @param work_id: 工作 ID。
## [br]
## @return 工作记录；不存在时返回 null。
func get_task(work_id: StringName) -> GFBackgroundWorkTask:
	return _as_task(GFVariantData.get_option_value(_tasks, work_id))


## 清理已完成的历史工作记录。
## [br]
## @api public
func clear_finished_tasks() -> void:
	for task: Variant in _finished_tasks:
		var finished_task: GFBackgroundWorkTask = _as_task(task)
		if finished_task != null:
			var _removed_task: bool = _tasks.erase(finished_task.work_id)
	_finished_tasks.clear()


## 清空全部工作。若仍有线程任务运行，会先请求取消并等待线程结束。
## [br]
## @api public
func clear_all() -> void:
	if not _active_thread_tasks.is_empty():
		cancel_all()
		_wait_for_active_thread_tasks()
	for task_variant: Variant in _tasks.values():
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.is_finished():
			task.cancel_requested = true
			if task.kind == GFBackgroundWorkTask.Kind.RESOURCE:
				_release_resource_operation_for_task(task, &"background_work_clear_all")
			_cancel_task(task)
	_work_serial = 0
	_tasks.clear()
	_queued_thread_tasks.clear()
	_active_thread_tasks.clear()
	_resource_requests.clear()
	_threaded_resource_coordinator.cancel_all(&"background_work_clear_all")
	_apply_queue.clear()
	_finished_tasks.clear()
	_paused = false


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary，包含任务计数、queued_ids、running_thread_ids、resource_paths、resource_draining_count、threaded_resource_operations、apply_ids、finished_ids、暂停状态和 apply 时间预算。
func get_debug_snapshot() -> Dictionary:
	return {
		"task_count": _tasks.size(),
		"queued_count": _queued_thread_tasks.size(),
		"running_thread_count": _active_thread_tasks.size(),
		"resource_request_count": _resource_requests.size(),
		"resource_draining_count": GFVariantData.get_option_int(
			_threaded_resource_coordinator.get_debug_snapshot(),
			"draining_count",
			0
		),
		"apply_count": _apply_queue.size(),
		"finished_count": _finished_tasks.size(),
		"is_paused": _paused,
		"queued_ids": _task_ids(_queued_thread_tasks.to_array(false)),
		"running_thread_ids": _active_thread_task_ids(),
		"resource_paths": PackedStringArray(_resource_requests.keys()),
		"threaded_resource_operations": _threaded_resource_coordinator.get_debug_snapshot(),
		"apply_ids": _task_ids(_apply_queue),
		"finished_ids": _task_ids(_finished_tasks),
		"max_apply_seconds_per_tick": max_apply_seconds_per_tick,
	}


# --- 私有/辅助方法 ---

func _submit_threaded_work(
	kind: GFBackgroundWorkTask.Kind,
	worker: Callable,
	input_data: Variant,
	apply_callback: Callable,
	options: Dictionary
) -> GFBackgroundWorkTask:
	var task: GFBackgroundWorkTask = _create_task(kind, worker, apply_callback, options)
	if not worker.is_valid():
		_fail_task(task, "[GFBackgroundWorkUtility] 提交后台工作失败：worker 无效。")
		return task

	var allow_payload_objects: bool = allow_object_payloads or GFVariantData.get_option_bool(options, "allow_object_payloads", false)
	if not allow_payload_objects and not _is_thread_payload_safe(input_data):
		_fail_task(task, "[GFBackgroundWorkUtility] 提交后台工作失败：payload 只能包含纯 Variant 数据。")
		return task

	task.input_data = GFVariantData.duplicate_variant(input_data)
	if not _register_task(task):
		_fail_task(task, "[GFBackgroundWorkUtility] 提交后台工作失败：工作 ID 已存在。")
		return task

	_insert_queued_thread_task(task, GFVariantData.get_option_bool(options, "front", false))
	work_queued.emit(task)
	_start_queued_thread_tasks()
	return task


func _create_task(
	kind: GFBackgroundWorkTask.Kind,
	worker: Callable,
	apply_callback: Callable,
	options: Dictionary
) -> GFBackgroundWorkTask:
	_work_serial += 1
	var task: GFBackgroundWorkTask = GFBackgroundWorkTask.new()
	task.kind = kind
	task.work_id = GFVariantData.get_option_string_name(options, "id")
	if task.work_id == &"":
		task.work_id = StringName("%s:%d" % [GFBackgroundWorkTask.kind_name(kind), _work_serial])
	task.priority = GFVariantData.get_option_int(options, "priority", 0)
	task.metadata = GFVariantData.get_option_dictionary(options, "metadata")
	task.created_msec = Time.get_ticks_msec()
	task.set_internal_callbacks(worker, apply_callback)
	return task


func _register_task(task: GFBackgroundWorkTask) -> bool:
	if task == null or task.work_id == &"" or _tasks.has(task.work_id):
		return false
	_tasks[task.work_id] = task
	return true


func _start_queued_thread_tasks() -> void:
	if _paused:
		return

	while _active_thread_tasks.size() < max_threaded_tasks and not _queued_thread_tasks.is_empty():
		var task: GFBackgroundWorkTask = _as_task(_queued_thread_tasks.pop())
		if task == null or task.status != GFBackgroundWorkTask.Status.QUEUED:
			continue
		if task.cancel_requested:
			_cancel_task(task)
			continue
		_start_thread_task(task)


func _insert_queued_thread_task(task: GFBackgroundWorkTask, front: bool) -> void:
	var _task_queued: bool = _queued_thread_tasks.push(task, task.priority, front)


func _start_thread_task(task: GFBackgroundWorkTask) -> void:
	var thread: Thread = Thread.new()
	var error: Error = thread.start(Callable(self, "_run_threaded_task").bind(task.get_worker_callback(), task.input_data))
	if error != OK:
		_fail_task(task, "[GFBackgroundWorkUtility] 启动线程失败：%d。" % error)
		return

	task.status = GFBackgroundWorkTask.Status.RUNNING
	task.started_msec = Time.get_ticks_msec()
	_active_thread_tasks[task.work_id] = {
		"task": task,
		"thread": thread,
	}
	work_started.emit(task)


func _poll_thread_tasks() -> void:
	var active_ids: Array = _active_thread_tasks.keys()
	for work_id: StringName in active_ids:
		var entry: Dictionary = _get_active_thread_entry(work_id)
		if entry.is_empty():
			continue
		var thread: Thread = _get_thread_entry_thread(entry)
		if thread == null or thread.is_alive():
			continue

		var result_variant: Variant = thread.wait_to_finish()
		var _removed_active: bool = _active_thread_tasks.erase(work_id)
		var task: GFBackgroundWorkTask = _get_thread_entry_task(entry)
		_finish_thread_task(task, result_variant)


func _finish_thread_task(task: GFBackgroundWorkTask, result_variant: Variant) -> void:
	if task == null or task.is_finished():
		return
	if task.cancel_requested:
		_cancel_task(task)
		return

	if not result_variant is Dictionary:
		_fail_task(task, "[GFBackgroundWorkUtility] 后台工作返回了无效结果。", result_variant)
		return
	var result: Dictionary = GFVariantData.as_dictionary(result_variant)
	var normalized_result: Dictionary = GFResultDictionary.normalize(result, false)
	if not GFResultDictionary.is_ok(normalized_result):
		_fail_task(task, _get_result_error_text(normalized_result, "background work failed"), _get_failure_result_payload(normalized_result))
		return

	task.result = _get_result_payload(normalized_result)
	_queue_apply_or_complete(task)


func _run_threaded_task(worker: Callable, input_data: Variant) -> Dictionary:
	var value: Variant = worker.call(input_data)
	if value is Dictionary:
		var value_dictionary: Dictionary = value
		if not GFVariantData.get_option_bool(value_dictionary, GFResultDictionary.KEY_OK, true):
			var result: Dictionary = GFResultDictionary.normalize(value_dictionary, false)
			return GFResultDictionary.make_failure(_get_result_error_text(result), {
				"result": value,
			})
	if value is bool:
		var bool_value: bool = value
		if not bool_value:
			return GFResultDictionary.make_failure("", {
				"result": value,
			})
	return GFResultDictionary.make_success({
		"result": value,
	})


func _start_resource_task(task: GFBackgroundWorkTask) -> void:
	var path: String = task.resource_path
	if _resource_requests.has(path):
		var request: Dictionary = _get_resource_request(path)
		var pending_type_hint: String = GFVariantData.get_option_string(request, "type_hint")
		if not _type_hints_are_compatible(pending_type_hint, task.resource_type_hint):
			_fail_task(task, "[GFBackgroundWorkUtility] 相同资源路径已有不同 type_hint 的加载请求：%s。" % path)
			return

		var tasks: Array = _get_resource_request_tasks(request)
		tasks.append(task)
		_retain_resource_operation(request)
		_start_task_without_thread(task)
		return

	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _threaded_resource_coordinator.request(path, task.resource_type_hint)
	var error: Error = operation.get_request_error() if operation != null else ERR_CANT_CREATE
	if error != OK:
		_fail_task(task, "[GFBackgroundWorkUtility] 发起资源线程加载失败：%s (%d)。" % [path, error])
		return

	_resource_requests[path] = {
		"type_hint": task.resource_type_hint,
		"progress": 0.0,
		"tasks": [task],
		"operation": operation,
		"released_task_ids": {},
	}
	_start_task_without_thread(task)


func _start_task_without_thread(task: GFBackgroundWorkTask) -> void:
	task.status = GFBackgroundWorkTask.Status.RUNNING
	task.started_msec = Time.get_ticks_msec()
	work_started.emit(task)


func _poll_resource_requests() -> void:
	var paths: Array = _resource_requests.keys()
	for path: String in paths:
		if not _resource_requests.has(path):
			continue

		var request: Dictionary = _get_resource_request(path)
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _get_resource_request_operation(request)
		var load_result: Dictionary = _threaded_resource_coordinator.poll_operation(operation)
		var status: StringName = GFVariantData.get_option_string_name(
			load_result,
			"status",
			_THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_INVALID
		)
		var ratio: float = GFVariantData.get_option_float(load_result, "progress", 0.0)
		request["progress"] = ratio
		var tasks: Array = _get_resource_request_tasks(request)
		for task_variant: Variant in tasks:
			var task: GFBackgroundWorkTask = _as_task(task_variant)
			if task != null and not task.cancel_requested and not task.is_finished():
				var _progress_updated: bool = update_work_progress(task.work_id, ratio)

		match status:
			_THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_IN_PROGRESS, _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_DRAINING:
				pass

			_THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_COMPLETED:
				var resource: Resource = _get_load_result_resource(load_result)
				var _removed_loaded_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					_finish_resource_task(task, resource)
				_threaded_resource_coordinator.forget_operation(operation)

			_THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_FAILED, _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_INVALID:
				var _removed_failed_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					if task != null and task.cancel_requested:
						_cancel_task(task)
					else:
						_fail_task(task, "[GFBackgroundWorkUtility] 资源线程加载失败：%s。" % path)
				_threaded_resource_coordinator.forget_operation(operation)

			_THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_SUPPRESSED:
				var _removed_suppressed_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					if task != null and not task.is_finished():
						_cancel_task(task)
				_threaded_resource_coordinator.forget_operation(operation)


func _finish_resource_task(task: GFBackgroundWorkTask, resource: Resource) -> void:
	if task == null or task.is_finished():
		return
	if task.cancel_requested:
		_cancel_task(task)
		return
	if resource == null:
		_fail_task(task, "[GFBackgroundWorkUtility] 资源线程加载完成但结果为空：%s。" % task.resource_path)
		return

	task.result = resource
	task.progress = 1.0
	_queue_apply_or_complete(task)


func _queue_apply_or_complete(task: GFBackgroundWorkTask) -> void:
	if task.cancel_requested:
		_cancel_task(task)
		return
	if task.get_apply_callback().is_valid():
		task.status = GFBackgroundWorkTask.Status.APPLYING
		_apply_queue.append(task)
		return
	_complete_task(task)


func _process_apply_queue() -> void:
	var remaining: int = maxi(max_apply_per_tick, 1)
	var started_usec: int = Time.get_ticks_usec()
	var applied_count: int = 0
	while remaining > 0 and not _apply_queue.is_empty():
		if _is_apply_time_budget_exhausted(started_usec, applied_count):
			break

		remaining -= 1
		var task: GFBackgroundWorkTask = _as_task(_apply_queue.pop_front())
		if task == null or task.is_finished():
			continue
		if task.cancel_requested:
			_cancel_task(task)
			continue

		var apply_callback: Callable = task.get_apply_callback()
		var value: Variant = apply_callback.call(task)
		applied_count += 1
		task.apply_result = value
		if value is Dictionary:
			var value_dictionary: Dictionary = value
			if not GFVariantData.get_option_bool(value_dictionary, GFResultDictionary.KEY_OK, true):
				var normalized_result: Dictionary = GFResultDictionary.normalize(value_dictionary, false)
				_fail_task(task, _get_result_error_text(normalized_result), normalized_result)
				continue
		if value is bool:
			var bool_value: bool = value
			if not bool_value:
				_fail_task(task, "", value)
				continue

		work_applied.emit(task)
		_complete_task(task)


func _complete_task(task: GFBackgroundWorkTask) -> void:
	if task == null or task.is_finished():
		return
	task.status = GFBackgroundWorkTask.Status.COMPLETED
	task.progress = 1.0
	task.finished_msec = Time.get_ticks_msec()
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_completed.emit(task)


func _fail_task(task: GFBackgroundWorkTask, error_message: String = "", result: Variant = null) -> void:
	if task == null or task.is_finished():
		return
	var _removed_queued_task: bool = _queued_thread_tasks.remove_value(task)
	_apply_queue.erase(task)
	task.status = GFBackgroundWorkTask.Status.FAILED
	task.error_message = error_message
	task.result = result
	task.finished_msec = Time.get_ticks_msec()
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_failed.emit(task)


func _get_result_error_text(result: Dictionary, fallback: String = "") -> String:
	var error_text: String = GFVariantData.get_option_string(result, GFResultDictionary.KEY_ERROR)
	if not error_text.is_empty():
		return error_text
	error_text = GFVariantData.get_option_string(result, GFResultDictionary.KEY_MESSAGE)
	if not error_text.is_empty():
		return error_text
	error_text = GFVariantData.get_option_string(result, GFResultDictionary.KEY_REASON)
	if not error_text.is_empty():
		return error_text
	return fallback


func _cancel_task(task: GFBackgroundWorkTask) -> void:
	if task == null or task.is_finished():
		return
	var _removed_queued_task: bool = _queued_thread_tasks.remove_value(task)
	_apply_queue.erase(task)
	task.status = GFBackgroundWorkTask.Status.CANCELLED
	task.finished_msec = Time.get_ticks_msec()
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_cancelled.emit(task)


func _wait_for_active_thread_tasks() -> void:
	for work_id: StringName in _active_thread_tasks.keys():
		var entry: Dictionary = _get_active_thread_entry(work_id)
		if entry.is_empty():
			continue
		var thread: Thread = _get_thread_entry_thread(entry)
		var result_variant: Variant = null
		if thread != null:
			result_variant = thread.wait_to_finish()
		var task: GFBackgroundWorkTask = _get_thread_entry_task(entry)
		_finish_thread_task(task, result_variant)
	_active_thread_tasks.clear()


func _trim_finished_tasks() -> void:
	var limit: int = maxi(max_finished_tasks, 0)
	while _finished_tasks.size() > limit:
		var removed: GFBackgroundWorkTask = _as_task(_finished_tasks.pop_front())
		if removed != null and removed.is_finished():
			var _removed_task: bool = _tasks.erase(removed.work_id)


func _is_apply_time_budget_exhausted(started_usec: int, applied_count: int) -> bool:
	if max_apply_seconds_per_tick <= 0.0 or applied_count <= 0:
		return false
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return elapsed_seconds >= max_apply_seconds_per_tick


func _is_thread_payload_safe(value: Variant, depth: int = 0) -> bool:
	if depth > _MAX_PAYLOAD_DEPTH:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I:
			return true
		TYPE_TRANSFORM2D, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB:
			return true
		TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_COLOR, TYPE_NODE_PATH:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return true
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			return true
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return true
		TYPE_ARRAY:
			var array: Array = GFVariantData.as_array(value)
			for item: Variant in array:
				if not _is_thread_payload_safe(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var dictionary: Dictionary = GFVariantData.as_dictionary(value)
			for key: Variant in dictionary.keys():
				if not _is_thread_payload_safe(key, depth + 1):
					return false
				if not _is_thread_payload_safe(dictionary[key], depth + 1):
					return false
			return true
	return false


func _request_threaded_resource(path: String, type_hint: String) -> Error:
	return _THREADED_RESOURCE_LOAD_ADAPTER.request(path, type_hint)


func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
	return _THREADED_RESOURCE_LOAD_ADAPTER.poll(path, previous_progress)


func _retain_resource_operation(request: Dictionary) -> void:
	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _get_resource_request_operation(request)
	if operation == null:
		return
	var _ref_count: int = _threaded_resource_coordinator.retain_operation(operation)


func _release_resource_operation_for_task(task: GFBackgroundWorkTask, reason: StringName) -> void:
	if task == null or task.resource_path.is_empty():
		return
	var request: Dictionary = _get_resource_request(task.resource_path)
	if request.is_empty():
		return

	var released_task_ids: Dictionary = GFVariantData.get_option_dictionary(request, "released_task_ids")
	if released_task_ids.has(task.work_id):
		return
	released_task_ids[task.work_id] = true
	request["released_task_ids"] = released_task_ids

	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _get_resource_request_operation(request)
	if operation == null:
		return
	var _ref_count: int = _threaded_resource_coordinator.release_operation(operation)
	if not _resource_request_has_live_consumers(request):
		_threaded_resource_coordinator.cancel_operation(operation, reason, false)


func _resource_request_has_live_consumers(request: Dictionary) -> bool:
	var tasks: Array = _get_resource_request_tasks(request)
	for task_variant: Variant in tasks:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.cancel_requested and not task.is_finished():
			return true
	return false


func _drain_cancelled_threaded_operations() -> void:
	var _drained_count: int = _threaded_resource_coordinator.drain_cancelled_operations()


func _type_hints_are_compatible(left: String, right: String) -> bool:
	return left.is_empty() or right.is_empty() or left == right


func _get_active_thread_entry(work_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_active_thread_tasks, work_id))


func _get_thread_entry_task(entry: Dictionary) -> GFBackgroundWorkTask:
	return _as_task(GFVariantData.get_option_value(entry, "task"))


func _get_thread_entry_thread(entry: Dictionary) -> Thread:
	return _variant_to_thread(GFVariantData.get_option_value(entry, "thread"))


func _get_resource_request(path: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_resource_requests, path))


func _get_resource_request_tasks(request: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(request, "tasks", []))


func _get_resource_request_operation(request: Dictionary) -> _THREADED_RESOURCE_OPERATION_SCRIPT:
	var value: Variant = GFVariantData.get_option_value(request, "operation")
	if value is _THREADED_RESOURCE_OPERATION_SCRIPT:
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = value
		return operation
	return null


func _get_result_payload(result: Dictionary) -> Variant:
	return GFVariantData.get_option_value(result, "result")


func _get_failure_result_payload(result: Dictionary) -> Variant:
	return GFVariantData.get_option_value(result, "result", result)


func _task_ids(tasks: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for task_variant: Variant in tasks:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null:
			_append_packed_string(result, String(task.work_id))
	return result


func _active_thread_task_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for work_id: Variant in _active_thread_tasks.keys():
		var normalized_work_id: StringName = GFVariantData.to_string_name(work_id)
		if normalized_work_id != &"":
			_append_packed_string(result, String(normalized_work_id))
	return result


static func _as_task(value: Variant) -> GFBackgroundWorkTask:
	if value is GFBackgroundWorkTask:
		var task: GFBackgroundWorkTask = value
		return task
	return null


static func _variant_to_thread(value: Variant) -> Thread:
	if value is Thread:
		var thread: Thread = value
		return thread
	return null


static func _get_load_result_resource(load_result: Dictionary) -> Resource:
	var value: Variant = GFVariantData.get_option_value(load_result, "resource")
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _added: bool = target.append(value)
