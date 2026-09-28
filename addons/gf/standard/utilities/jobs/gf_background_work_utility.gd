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

## 线程 payload 递归检查允许的最大深度。
## [br]
## @api private
## [br]
const _MAX_PAYLOAD_DEPTH: int = 64

## 提供 CPU/IO 等待任务优先级队列实现的脚本。
## [br]
## @api private
## [br]
const _GF_PRIORITY_WORK_QUEUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_priority_work_queue.gd")

## 创建或类型检查 GFResourceBroker 所用的脚本。
## [br]
## @api private
## [br]
const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_broker.gd")

## Resource 请求记录中 operation 字段的类型脚本。
## [br]
## @api private
## [br]
const _RESOURCE_LEASE_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_lease.gd")


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

## 等待中的 CPU/IO 工作每经过多少毫秒增加一次有效优先级。
## [br]
## @api public
## [br]
## @since 9.0.0
var priority_aging_interval_msec: int = 1000:
	set(value):
		priority_aging_interval_msec = maxi(value, 1)
		_configure_priority_work_queue()

## 每个等待区间增加的有效优先级；正值且不设总加成上限。
## [br]
## @api public
## [br]
## @since 9.0.0
var priority_aging_step: float = 1.0:
	set(value):
		priority_aging_step = value if is_finite(value) and value > 0.0 else 1.0
		_configure_priority_work_queue()


# --- 私有变量 ---

## 为缺少显式 ID 的新任务递增的序号。
## [br]
## @api private
## [br]
var _work_serial: int = 0

## 以 work_id 为键保存当前可查询的任务记录。
## [br]
## @api private
## [br]
var _tasks: Dictionary = {}

## 等待启动的 CPU/IO 任务优先级队列。
## [br]
## @api private
## [br]
var _queued_thread_tasks: _GF_PRIORITY_WORK_QUEUE_SCRIPT = _GF_PRIORITY_WORK_QUEUE_SCRIPT.new()

## 以 work_id 为键保存正在运行的 Thread 和对应任务。
## [br]
## @api private
## [br]
var _active_thread_tasks: Dictionary = {}

## 按资源路径分组的 Resource 请求、Lease 和消费者任务记录。
## [br]
## @api private
## [br]
var _resource_requests: Dictionary = {}

## 等待主线程执行 apply_callback 的任务队列。
## [br]
## @api private
## [br]
var _apply_queue: Array = []

## 为调试保留的终态任务历史。
## [br]
## @api private
## [br]
var _finished_tasks: Array = []

## 是否暂停启动新的 CPU/IO 等待任务。
## [br]
## @api private
## [br]
var _paused: bool = false

## 当前注入或由本工具建立的共享资源 Broker。
## [br]
## @api private
## [br]
var _resource_broker: GFResourceBroker = null

## 标记当前 Broker 是否由本工具建立并由本工具负责 dispose。
## [br]
## @api private
## [br]
var _owns_resource_broker: bool = false


# --- GF 生命周期方法 ---

## 初始化后台工作协调器并启用暂停无关处理。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	clear_all()


## 从所属架构解析显式注册的共享 GFResourceBroker。
## [br]
## @api public
## [br]
## @since 11.0.0
func ready() -> void:
	if _resource_broker != null:
		return
	var utility: Object = get_utility(_RESOURCE_BROKER_SCRIPT)
	if utility is GFResourceBroker:
		var broker: GFResourceBroker = utility
		var _bind_error: Error = set_resource_broker(broker)


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
	_cancel_all_with_reason(GFBackgroundWorkContext.CancellationReason.UTILITY_DISPOSED)
	_wait_for_active_thread_tasks()
	clear_all()
	if _owns_resource_broker and _resource_broker != null:
		_resource_broker.dispose()


## 释放共享 Broker 引用和架构依赖作用域。
## [br]
## @api public
## [br]
## @since 11.0.0
func release_dependencies() -> void:
	_resource_broker = null
	_owns_resource_broker = false
	super.release_dependencies()


# --- 公共方法 ---

## 注入共享 Resource Broker。
##
## 重复绑定当前 Broker 幂等成功；存在活动资源请求时拒绝替换，以保证每个消费者
## Lease 始终由同一 Broker 管理。当前 Broker 由本 Utility 私有拥有时，还必须等待
## 它完成 drain 并进入 idle，才能替换为其它 Broker。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param broker: 要共享的 Broker。
## [br]
## @return 绑定结果；请求尚未收敛或私有 Broker 尚未 idle 时返回 `ERR_BUSY`。
func set_resource_broker(broker: GFResourceBroker) -> Error:
	if broker == null:
		return ERR_INVALID_PARAMETER
	if _resource_broker == broker:
		return OK
	if not _resource_requests.is_empty():
		return ERR_BUSY
	if _owns_resource_broker and _resource_broker != null and _resource_broker != broker:
		if not _resource_broker.is_idle():
			return ERR_BUSY
		_resource_broker.dispose()
	_resource_broker = broker
	_owns_resource_broker = false
	return OK


## 为单个独立 BackgroundWork Utility 显式创建私有 Resource Broker。
##
## 需要与 Asset 或 Scene 协调时，应由项目创建一个共享 Broker 并分别注入。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param max_active_requests: Broker 同时活动的底层请求上限。
## [br]
## @param max_pending_requests: Broker 等待 admission 的不同请求上限。
## [br]
## @return 创建的 Broker；存在活动资源请求时返回 null。
func setup_standalone_resource_broker(
	max_active_requests: int = 4,
	max_pending_requests: int = 256
) -> GFResourceBroker:
	if not _resource_requests.is_empty():
		return null
	var broker: GFResourceBroker = _RESOURCE_BROKER_SCRIPT.new()
	broker.max_active_requests = max_active_requests
	broker.max_pending_requests = max_pending_requests
	broker.init()
	var bind_error: Error = set_resource_broker(broker)
	if bind_error != OK:
		return null
	_owns_resource_broker = true
	return broker


## 获取当前注入的 Resource Broker。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已绑定的 Broker；未配置时返回 null。
func get_resource_broker() -> GFResourceBroker:
	return _resource_broker

## 提交 CPU 纯数据后台工作。
## [br]
## @param worker: 后台线程回调。默认签名为 func(input_data: Variant) -> Variant；启用协作取消上下文时为 func(input_data: Variant, context: GFBackgroundWorkContext) -> Variant。
## [br]
## @param input_data: 输入数据。默认只允许纯 Variant 容器和值。
## [br]
## @param apply_callback: 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。
## [br]
## @param options: 可选配置，支持 id、priority、metadata、front、allow_object_payloads、pass_cancellation_context。
## [br]
## @return 工作记录；参数无效时返回 failed 状态任务。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema input_data: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
## [br]
## @schema options: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool、allow_object_payloads: bool 和 pass_cancellation_context: bool；后者为 true 时 worker 必须精确接收 input_data 与只读 context 两个参数。
func submit_cpu_work(
	worker: Callable,
	input_data: Variant = null,
	apply_callback: Callable = Callable(),
	options: Dictionary = {}
) -> GFBackgroundWorkTask:
	return _submit_threaded_work(GFBackgroundWorkTask.Kind.CPU, worker, input_data, apply_callback, options)


## 提交 IO 纯数据后台工作。
## [br]
## @param worker: 后台线程回调。默认签名为 func(input_data: Variant) -> Variant；启用协作取消上下文时为 func(input_data: Variant, context: GFBackgroundWorkContext) -> Variant。
## [br]
## @param input_data: 输入数据。默认只允许纯 Variant 容器和值。
## [br]
## @param apply_callback: 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。
## [br]
## @param options: 可选配置，支持 id、priority、metadata、front、allow_object_payloads、pass_cancellation_context。
## [br]
## @return 工作记录；参数无效时返回 failed 状态任务。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema input_data: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
## [br]
## @schema options: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool、allow_object_payloads: bool 和 pass_cancellation_context: bool；后者为 true 时 worker 必须精确接收 input_data 与只读 context 两个参数。
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
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.resource_path_empty] Cannot submit_resource_load: resource path is empty.")
		return task

	if not _register_task(task):
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.resource_work_id_duplicate] Cannot submit_resource_load: work ID already exists.")
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
## @since 3.17.0
## [br]
## @return 取消成功返回 true。
func cancel_work(work_id: StringName) -> bool:
	return _cancel_work_with_reason(
		work_id,
		GFBackgroundWorkContext.CancellationReason.CANCEL_WORK
	)


## 取消全部未完成工作。
## [br]
## @api public
func cancel_all() -> void:
	_cancel_all_with_reason(GFBackgroundWorkContext.CancellationReason.CANCEL_ALL)


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
		_cancel_all_with_reason(GFBackgroundWorkContext.CancellationReason.CLEAR_ALL)
		_wait_for_active_thread_tasks()
	for task_variant: Variant in _tasks.values():
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.is_finished():
			_request_task_cancellation(
				task,
				GFBackgroundWorkContext.CancellationReason.CLEAR_ALL
			)
			task.cancel_requested = true
			if task.kind == GFBackgroundWorkTask.Kind.RESOURCE:
				_release_resource_operation_for_task(task, &"background_work_clear_all")
			_cancel_task(task)
	_work_serial = 0
	_tasks.clear()
	_queued_thread_tasks.clear()
	_active_thread_tasks.clear()
	_resource_requests.clear()
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
## @schema return: Dictionary，包含任务计数、queued_ids、queued_priority_entries、优先级老化配置、running_thread_ids、resource_paths、resource_draining_count、resource_broker configured/error/admission、apply_ids、finished_ids、暂停状态和 apply 时间预算。
func get_debug_snapshot() -> Dictionary:
	var now_msec: int = _get_now_msec()
	var queued_entries: Array[Dictionary] = _queued_thread_tasks.to_entry_array(now_msec)
	var broker_snapshot: Dictionary = _get_resource_broker_debug_snapshot()
	return {
		"task_count": _tasks.size(),
		"queued_count": _queued_thread_tasks.size(),
		"running_thread_count": _active_thread_tasks.size(),
		"resource_request_count": _resource_requests.size(),
		"resource_draining_count": GFVariantData.get_option_int(broker_snapshot, "draining_count", 0),
		"apply_count": _apply_queue.size(),
		"finished_count": _finished_tasks.size(),
		"is_paused": _paused,
		"queued_ids": _queued_task_ids(queued_entries),
		"queued_priority_entries": _queued_priority_summaries(queued_entries),
		"priority_aging_interval_msec": priority_aging_interval_msec,
		"priority_aging_step": priority_aging_step,
		"running_thread_ids": _active_thread_task_ids(),
		"resource_paths": PackedStringArray(_resource_requests.keys()),
		"resource_broker": broker_snapshot,
		"apply_ids": _task_ids(_apply_queue),
		"finished_ids": _task_ids(_finished_tasks),
		"max_apply_seconds_per_tick": max_apply_seconds_per_tick,
	}


# --- 私有/辅助方法 ---

## 校验线程回调与 payload，准备取消上下文、登记任务并加入优先级队列。
## 输入无效或登记失败时返回已标记失败的任务记录。
## [br]
## @api private
## [br]
func _submit_threaded_work(
	kind: GFBackgroundWorkTask.Kind,
	worker: Callable,
	input_data: Variant,
	apply_callback: Callable,
	options: Dictionary
) -> GFBackgroundWorkTask:
	var task: GFBackgroundWorkTask = _create_task(kind, worker, apply_callback, options)
	if not worker.is_valid():
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.worker_invalid] Cannot submit background work: worker is invalid.")
		return task

	var allow_payload_objects: bool = allow_object_payloads or GFVariantData.get_option_bool(options, "allow_object_payloads", false)
	if not allow_payload_objects and not _is_thread_payload_safe(input_data):
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.payload_not_plain] Cannot submit background work: payload must contain only plain Variant data.")
		return task
	var pass_cancellation_context: bool = GFVariantData.get_option_bool(
		options,
		"pass_cancellation_context",
		false
	)
	if pass_cancellation_context and worker.get_argument_count() != 2:
		_fail_task(
			task,
			"[GFBackgroundWorkUtility][background_work_utility.cancellation_worker_arity] Cannot submit background work: worker must accept two arguments when cancellation context is enabled."
		)
		return task
	var cancellation_context: GFBackgroundWorkContext = GFBackgroundWorkContext.new()
	var context_error: Error = cancellation_context.configure_for_framework(task.work_id)
	if context_error != OK:
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.cancellation_context_creation_failed] Cannot create cancellation context: %d." % context_error)
		return task
	task.input_data = GFVariantData.duplicate_variant(input_data)
	if not _register_task(task):
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.work_id_duplicate] Cannot submit background work: work ID already exists.")
		return task
	task.set_cancellation_context_for_framework(
		cancellation_context,
		pass_cancellation_context
	)

	_insert_queued_thread_task(task, GFVariantData.get_option_bool(options, "front", false))
	work_queued.emit(task)
	_start_queued_thread_tasks()
	return task


## 创建任务记录，设置 kind、ID、优先级、元数据、创建 tick 和回调。
## [br]
## @api private
## [br]
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
	task.created_msec = _get_now_msec()
	task.set_internal_callbacks(worker, apply_callback)
	return task


## 仅登记 ID 非空且尚未占用的任务。
## [br]
## @api private
## [br]
func _register_task(task: GFBackgroundWorkTask) -> bool:
	if task == null or task.work_id == &"" or _tasks.has(task.work_id):
		return false
	_tasks[task.work_id] = task
	return true


## 未暂停时按优先队列顺序启动任务，直到达到并发上限或队列为空。
## 已取消及状态不再为 QUEUED 的条目会跳过或直接转为取消终态。
## [br]
## @api private
## [br]
func _start_queued_thread_tasks() -> void:
	if _paused:
		return

	while _active_thread_tasks.size() < max_threaded_tasks and not _queued_thread_tasks.is_empty():
		var task: GFBackgroundWorkTask = _as_task(_queued_thread_tasks.pop_at(_get_now_msec()))
		if task == null or task.status != GFBackgroundWorkTask.Status.QUEUED:
			continue
		if task.cancel_requested:
			_cancel_task(task)
			continue
		_start_thread_task(task)


## 按任务优先级、创建 tick 和 front 选项插入等待队列。
## [br]
## @api private
## [br]
func _insert_queued_thread_task(task: GFBackgroundWorkTask, front: bool) -> void:
	var _task_queued: bool = _queued_thread_tasks.push_at(
		task,
		float(task.priority),
		task.created_msec,
		front
	)


## 将公开配置的 aging 间隔和步长同步到优先队列。
## [br]
## @api private
## [br]
func _configure_priority_work_queue() -> void:
	if _queued_thread_tasks == null:
		return
	_queued_thread_tasks.aging_interval_msec = priority_aging_interval_msec
	_queued_thread_tasks.aging_step = priority_aging_step


## 从优先队列条目中收集有效任务的 ID，保持条目顺序。
## [br]
## @api private
## [br]
func _queued_task_ids(entries: Array[Dictionary]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var task: GFBackgroundWorkTask = _as_task(GFVariantData.get_option_value(entry, "value"))
		if task != null:
			_append_packed_string(result, String(task.work_id))
	return result


## 为有效等待任务提取 ID、原始与有效优先级、等待时长和顺序号。
## [br]
## @api private
## [br]
func _queued_priority_summaries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var task: GFBackgroundWorkTask = _as_task(GFVariantData.get_option_value(entry, "value"))
		if task == null:
			continue
		summaries.append({
			"work_id": String(task.work_id),
			"priority": GFVariantData.get_option_float(entry, "priority"),
			"effective_priority": GFVariantData.get_option_float(entry, "effective_priority"),
			"waited_msec": GFVariantData.get_option_int(entry, "waited_msec"),
			"order": GFVariantData.get_option_int(entry, "order"),
		})
	return summaries


## 返回当前单调毫秒 tick。
## [br]
## @api private
## [br]
func _get_now_msec() -> int:
	return Time.get_ticks_msec()


## 启动绑定 worker 参数的 Thread；成功后记录活动线程和开始时间并发出开始信号。
## 线程启动错误会将任务转为失败终态。
## [br]
## @api private
## [br]
func _start_thread_task(task: GFBackgroundWorkTask) -> void:
	var thread: Thread = Thread.new()
	var error: Error = thread.start(Callable(self, "_run_threaded_task").bind(
		task.get_worker_callback(),
		task.input_data,
		task.get_cancellation_context(),
		task.worker_receives_cancellation_context_for_framework()
	))
	if error != OK:
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.thread_start_failed] Cannot start thread: %d." % error)
		return

	task.status = GFBackgroundWorkTask.Status.RUNNING
	task.started_msec = Time.get_ticks_msec()
	_active_thread_tasks[task.work_id] = {
		"task": task,
		"thread": thread,
	}
	work_started.emit(task)


## 检查活动线程；线程结束后等待结果、释放 worker 回调目标并处理结果。
## [br]
## @api private
## [br]
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
		_release_worker_callback_after_join(task)
		_finish_thread_task(task, result_variant)


## 丢弃无效终态任务；取消、非字典或拒绝结果分别取消或失败，否则提取 result 并排入应用阶段。
## [br]
## @api private
## [br]
func _finish_thread_task(task: GFBackgroundWorkTask, result_variant: Variant) -> void:
	if task == null or task.is_finished():
		return
	if task.cancel_requested:
		_cancel_task(task)
		return

	if not result_variant is Dictionary:
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.work_result_invalid] Background work returned an invalid result.", result_variant)
		return
	var result: Dictionary = GFVariantData.as_dictionary(result_variant)
	var normalized_result: Dictionary = GFResultDictionary.normalize(result, false)
	if not GFResultDictionary.is_ok(normalized_result):
		_fail_task(task, _get_result_error_text(normalized_result, "background work failed"), _get_failure_result_payload(normalized_result))
		return

	task.result = _get_result_payload(normalized_result)
	_queue_apply_or_complete(task)


## 调用 worker 并包装结果；字典 ok=false 或直接返回 false 时生成失败结果。
## worker 启用取消契约时附带 context，其余情况仅传 input_data。
## [br]
## @api private
## [br]
func _run_threaded_task(
	worker: Callable,
	input_data: Variant,
	cancellation_context: GFBackgroundWorkContext,
	worker_receives_context: bool
) -> Dictionary:
	var value: Variant = (
		worker.call(input_data, cancellation_context)
		if worker_receives_context
		else worker.call(input_data)
	)
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


## 按资源路径合并消费者；类型提示冲突时失败，否则向 Broker 获取新的 Lease。
## 若已有 Lease 已取消，先退役该请求记录再为仍有效的任务重试。
## [br]
## @api private
## [br]
func _start_resource_task(task: GFBackgroundWorkTask) -> void:
	var path: String = task.resource_path
	if _resource_requests.has(path):
		var request: Dictionary = _get_resource_request(path)
		var existing_operation: _RESOURCE_LEASE_SCRIPT = _get_resource_request_operation(
			request
		)
		# 已取消的 Lease 不会向后来消费者交付结果；先退役本地记录，再重新取得 Lease。
		if (
			existing_operation != null
			and existing_operation.get_status() == _RESOURCE_LEASE_SCRIPT.STATUS_CANCELLED
		):
			_retire_cancelled_resource_request(path, request, existing_operation)
			if not task.is_finished():
				_start_resource_task(task)
			return
		var pending_type_hint: String = GFVariantData.get_option_string(request, "type_hint")
		if not _type_hints_are_compatible(pending_type_hint, task.resource_type_hint):
			_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.resource_type_hint_conflict] A load request with a different type_hint already exists for this resource path: %s." % path)
			return

		var tasks: Array = _get_resource_request_tasks(request)
		tasks.append(task)
		_start_task_without_thread(task)
		return

	var operation: _RESOURCE_LEASE_SCRIPT = null
	if _resource_broker != null:
		operation = _resource_broker.request(
			path,
			task.resource_type_hint,
			{ "consumer_id": &"background_work" }
		)
	var error: Error = operation.get_request_error() if operation != null else ERR_UNCONFIGURED
	if error != OK:
		_fail_task(
			task,
			"[GFBackgroundWorkUtility][background_work_utility.resource_load_request_failed] Cannot start threaded resource loading: %s (%d)." % [path, error],
			{
				"request_error": error,
				"reason": (
					"resource_broker_not_configured"
					if error == ERR_UNCONFIGURED
					else "resource_request_rejected"
				),
			}
		)
		return

	_resource_requests[path] = {
		"type_hint": task.resource_type_hint,
		"progress": 0.0,
		"tasks": [task],
		"operation": operation,
		"released_task_ids": {},
	}
	_start_task_without_thread(task)


## 将不经 Thread 执行的资源任务标记为运行并记录开始 tick。
## [br]
## @api private
## [br]
func _start_task_without_thread(task: GFBackgroundWorkTask) -> void:
	task.status = GFBackgroundWorkTask.Status.RUNNING
	task.started_msec = Time.get_ticks_msec()
	work_started.emit(task)


## 轮询每个资源 Lease，更新有效消费者进度，并按 queued/loading/completed/failed/cancelled 分发处理。
## 终态分支会移除路径记录并调用 Lease.release()。
## [br]
## @api private
## [br]
func _poll_resource_requests() -> void:
	var paths: Array = _resource_requests.keys()
	for path: String in paths:
		if not _resource_requests.has(path):
			continue

		var request: Dictionary = _get_resource_request(path)
		var operation: _RESOURCE_LEASE_SCRIPT = _get_resource_request_operation(request)
		var load_result: Dictionary = (
			_resource_broker.poll_lease(operation)
			if _resource_broker != null
			else _make_missing_resource_broker_result()
		)
		var status: StringName = GFVariantData.get_option_string_name(
			load_result,
			"status",
			_RESOURCE_LEASE_SCRIPT.STATUS_FAILED
		)
		var ratio: float = GFVariantData.get_option_float(load_result, "progress", 0.0)
		request["progress"] = ratio
		var tasks: Array = _get_resource_request_tasks(request)
		for task_variant: Variant in tasks:
			var task: GFBackgroundWorkTask = _as_task(task_variant)
			if task != null and not task.cancel_requested and not task.is_finished():
				var _progress_updated: bool = update_work_progress(task.work_id, ratio)

		match status:
			_RESOURCE_LEASE_SCRIPT.STATUS_QUEUED, _RESOURCE_LEASE_SCRIPT.STATUS_LOADING:
				pass

			_RESOURCE_LEASE_SCRIPT.STATUS_COMPLETED:
				var resource: Resource = _get_load_result_resource(load_result)
				var _removed_loaded_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					_finish_resource_task(task, resource)
				operation.release()

			_RESOURCE_LEASE_SCRIPT.STATUS_FAILED:
				var _removed_failed_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					if task != null and task.cancel_requested:
						_cancel_task(task)
					else:
						_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.resource_load_failed] Threaded resource loading failed: %s." % path)
				operation.release()

			_RESOURCE_LEASE_SCRIPT.STATUS_CANCELLED:
				var _removed_suppressed_request: bool = _resource_requests.erase(path)
				for task_variant: Variant in tasks:
					var task: GFBackgroundWorkTask = _as_task(task_variant)
					if task != null and not task.is_finished():
						_cancel_task(task)
				operation.release()


## 取消已请求取消的任务，拒绝空资源结果，否则保存资源并排入应用阶段。
## [br]
## @api private
## [br]
func _finish_resource_task(task: GFBackgroundWorkTask, resource: Resource) -> void:
	if task == null or task.is_finished():
		return
	if task.cancel_requested:
		_cancel_task(task)
		return
	if resource == null:
		_fail_task(task, "[GFBackgroundWorkUtility][background_work_utility.resource_load_result_null] Threaded resource loading completed with a null result: %s." % task.resource_path)
		return

	task.result = resource
	task.progress = 1.0
	_queue_apply_or_complete(task)


## 已请求取消时结束为取消；有 apply 回调则排入主线程队列，否则直接完成。
## [br]
## @api private
## [br]
func _queue_apply_or_complete(task: GFBackgroundWorkTask) -> void:
	if task.cancel_requested:
		_cancel_task(task)
		return
	if task.get_apply_callback().is_valid():
		task.status = GFBackgroundWorkTask.Status.APPLYING
		_apply_queue.append(task)
		return
	_complete_task(task)


## 按单帧数量和时间预算执行主线程 apply 回调，并处理其成功或失败结果。
## 失败字典的 ok=false 或直接返回 false 会使任务失败。
## [br]
## @api private
## [br]
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


## 设置完成状态、进度与结束 tick，释放回调，加入终态历史并发出完成信号。
## [br]
## @api private
## [br]
func _complete_task(task: GFBackgroundWorkTask) -> void:
	if task == null or task.is_finished():
		return
	task.status = GFBackgroundWorkTask.Status.COMPLETED
	task.progress = 1.0
	task.finished_msec = Time.get_ticks_msec()
	_release_task_callbacks_at_terminal(task)
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_completed.emit(task)


## 从等待及应用队列移除任务，写入错误和结果后加入终态历史并发出失败信号。
## [br]
## @api private
## [br]
func _fail_task(task: GFBackgroundWorkTask, error_message: String = "", result: Variant = null) -> void:
	if task == null or task.is_finished():
		return
	var _removed_queued_task: bool = _queued_thread_tasks.remove_value(task)
	_apply_queue.erase(task)
	task.status = GFBackgroundWorkTask.Status.FAILED
	task.error_message = error_message
	task.result = result
	task.finished_msec = Time.get_ticks_msec()
	_release_task_callbacks_at_terminal(task)
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_failed.emit(task)


## 依次取 error、message、reason 文本；均为空时返回 fallback。
## [br]
## @api private
## [br]
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


## 从等待及应用队列移除任务并写入取消终态、结束 tick 和历史记录。
## [br]
## @api private
## [br]
func _cancel_task(task: GFBackgroundWorkTask) -> void:
	if task == null or task.is_finished():
		return
	var _removed_queued_task: bool = _queued_thread_tasks.remove_value(task)
	_apply_queue.erase(task)
	task.status = GFBackgroundWorkTask.Status.CANCELLED
	task.finished_msec = Time.get_ticks_msec()
	_release_task_callbacks_at_terminal(task)
	_finished_tasks.append(task)
	_trim_finished_tasks()
	work_cancelled.emit(task)


## 记录取消原因并按任务阶段处理；运行中的 Thread 保留至 worker 返回后再收尾。
## [br]
## @api private
## [br]
func _cancel_work_with_reason(
	work_id: StringName,
	reason: GFBackgroundWorkContext.CancellationReason
) -> bool:
	var task: GFBackgroundWorkTask = get_task(work_id)
	if task == null or task.is_finished():
		return false

	_request_task_cancellation(task, reason)
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


## 遍历当前任务值快照，对每个未结束任务调用带指定原因的取消流程。
## [br]
## @api private
## [br]
func _cancel_all_with_reason(
	reason: GFBackgroundWorkContext.CancellationReason
) -> void:
	var task_values: Array = _tasks.values()
	for task_variant: Variant in task_values:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.is_finished():
			var _cancelled: bool = _cancel_work_with_reason(task.work_id, reason)


## 存在协作取消上下文时向其发布指定原因；缺少上下文时不操作。
## [br]
## @api private
## [br]
func _request_task_cancellation(
	task: GFBackgroundWorkTask,
	reason: GFBackgroundWorkContext.CancellationReason
) -> void:
	if task == null:
		return
	var context: GFBackgroundWorkContext = task.get_cancellation_context()
	if context != null:
		var _requested: bool = context.request_cancel_for_framework(reason)


## 同步等待所有活动 Thread，释放 worker 回调目标并处理返回值，然后清空活动表。
## [br]
## @api private
## [br]
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
		_release_worker_callback_after_join(task)
		_finish_thread_task(task, result_variant)
	_active_thread_tasks.clear()


## Thread join 后清除 worker 回调及其目标引用，同时保留 apply 回调。
## [br]
## @api private
## [br]
func _release_worker_callback_after_join(task: GFBackgroundWorkTask) -> void:
	if task == null:
		return
	task.set_internal_callbacks(Callable(), task.get_apply_callback())


## 任务进入终态时清除 worker 与 apply 回调及其目标引用。
## [br]
## @api private
## [br]
func _release_task_callbacks_at_terminal(task: GFBackgroundWorkTask) -> void:
	if task == null:
		return
	task.set_internal_callbacks(Callable(), Callable())


## 按 max_finished_tasks 移除最旧终态记录，并同步删除任务索引。
## [br]
## @api private
## [br]
func _trim_finished_tasks() -> void:
	var limit: int = maxi(max_finished_tasks, 0)
	while _finished_tasks.size() > limit:
		var removed: GFBackgroundWorkTask = _as_task(_finished_tasks.pop_front())
		if removed != null and removed.is_finished():
			var _removed_task: bool = _tasks.erase(removed.work_id)


## 仅在预算为正且本帧已执行至少一个回调后比较经过秒数。
## [br]
## @api private
## [br]
func _is_apply_time_budget_exhausted(started_usec: int, applied_count: int) -> bool:
	if max_apply_seconds_per_tick <= 0.0 or applied_count <= 0:
		return false
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return elapsed_seconds >= max_apply_seconds_per_tick


## 限深递归允许纯值、数学值、NodePath、packed 数组、Array 与 Dictionary。
## 其他 Variant 类型或超过最大深度的容器返回 false。
## [br]
## @api private
## [br]
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


## 记录此任务已释放，再无有效消费者时向路径对应 Lease 请求取消。
## 重复调用同一任务不会再次执行取消请求。
## [br]
## @api private
## [br]
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

	var operation: _RESOURCE_LEASE_SCRIPT = _get_resource_request_operation(request)
	if operation == null:
		return
	if not _resource_request_has_live_consumers(request):
		operation.cancel(reason)


## 移除已取消的路径请求，取消其未结束任务并释放旧 Lease。
## [br]
## @api private
## [br]
func _retire_cancelled_resource_request(
	path: String,
	request: Dictionary,
	operation: _RESOURCE_LEASE_SCRIPT
) -> void:
	var _removed_request: bool = _resource_requests.erase(path)
	for task_variant: Variant in _get_resource_request_tasks(request):
		var request_task: GFBackgroundWorkTask = _as_task(task_variant)
		if request_task != null and not request_task.is_finished():
			_cancel_task(request_task)
	operation.release()


## 只要有非空、未请求取消且未结束的消费者任务就返回 true。
## [br]
## @api private
## [br]
func _resource_request_has_live_consumers(request: Dictionary) -> bool:
	var tasks: Array = _get_resource_request_tasks(request)
	for task_variant: Variant in tasks:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null and not task.cancel_requested and not task.is_finished():
			return true
	return false


## 已配置 Broker 时调用 pump 推进其后台操作收敛。
## [br]
## @api private
## [br]
func _drain_cancelled_threaded_operations() -> void:
	if _resource_broker != null:
		_resource_broker.pump()


## 构造未配置 Broker 时使用的 failed 状态、零进度和 ERR_UNCONFIGURED 结果。
## [br]
## @api private
## [br]
func _make_missing_resource_broker_result() -> Dictionary:
	return {
		"status": _RESOURCE_LEASE_SCRIPT.STATUS_FAILED,
		"progress": 0.0,
		"resource": null,
		"has_resource": false,
		"error": "resource_broker_not_configured",
		"request_error": ERR_UNCONFIGURED,
	}


## 返回 Broker 调试快照并补充 configured、error 和 request_error 字段。
## 未配置时返回明确的 ERR_UNCONFIGURED 状态字典。
## [br]
## @api private
## [br]
func _get_resource_broker_debug_snapshot() -> Dictionary:
	if _resource_broker == null:
		return {
			"configured": false,
			"error": "resource_broker_not_configured",
			"request_error": ERR_UNCONFIGURED,
		}
	var snapshot: Dictionary = _resource_broker.get_debug_snapshot()
	snapshot["configured"] = true
	snapshot["error"] = ""
	snapshot["request_error"] = OK
	return snapshot


## 任一类型提示为空或两者相同时视为兼容。
## [br]
## @api private
## [br]
func _type_hints_are_compatible(left: String, right: String) -> bool:
	return left.is_empty() or right.is_empty() or left == right


## 从活动线程表中读取指定 ID 对应的字典条目。
## [br]
## @api private
## [br]
func _get_active_thread_entry(work_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_active_thread_tasks, work_id))


## 从线程条目的 task 字段取值并收窄为任务类型。
## [br]
## @api private
## [br]
func _get_thread_entry_task(entry: Dictionary) -> GFBackgroundWorkTask:
	return _as_task(GFVariantData.get_option_value(entry, "task"))


## 从线程条目的 thread 字段取值并收窄为 Thread 类型。
## [br]
## @api private
## [br]
func _get_thread_entry_thread(entry: Dictionary) -> Thread:
	return _variant_to_thread(GFVariantData.get_option_value(entry, "thread"))


## 从资源请求表中读取指定路径对应的字典记录。
## [br]
## @api private
## [br]
func _get_resource_request(path: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_resource_requests, path))


## 从资源请求记录中读取消费者任务数组，缺失时使用空数组。
## [br]
## @api private
## [br]
func _get_resource_request_tasks(request: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(request, "tasks", []))


## 将请求记录的 operation 字段收窄为 Resource Lease；类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_resource_request_operation(request: Dictionary) -> _RESOURCE_LEASE_SCRIPT:
	var value: Variant = GFVariantData.get_option_value(request, "operation")
	if value is _RESOURCE_LEASE_SCRIPT:
		var operation: _RESOURCE_LEASE_SCRIPT = value
		return operation
	return null


## 读取标准结果中的 result 字段，缺失时返回 null。
## [br]
## @api private
## [br]
func _get_result_payload(result: Dictionary) -> Variant:
	return GFVariantData.get_option_value(result, "result")


## 优先读取失败结果的 result 字段，缺失时返回整个结果字典。
## [br]
## @api private
## [br]
func _get_failure_result_payload(result: Dictionary) -> Variant:
	return GFVariantData.get_option_value(result, "result", result)


## 按输入顺序收集数组中有效任务的工作 ID。
## [br]
## @api private
## [br]
func _task_ids(tasks: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for task_variant: Variant in tasks:
		var task: GFBackgroundWorkTask = _as_task(task_variant)
		if task != null:
			_append_packed_string(result, String(task.work_id))
	return result


## 将活动线程表的键规范为非空 StringName 后收集其字符串形式。
## [br]
## @api private
## [br]
func _active_thread_task_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for work_id: Variant in _active_thread_tasks.keys():
		var normalized_work_id: StringName = GFVariantData.to_string_name(work_id)
		if normalized_work_id != &"":
			_append_packed_string(result, String(normalized_work_id))
	return result


## 仅当 Variant 是 GFBackgroundWorkTask 时返回其强类型引用。
## [br]
## @api private
## [br]
static func _as_task(value: Variant) -> GFBackgroundWorkTask:
	if value is GFBackgroundWorkTask:
		var task: GFBackgroundWorkTask = value
		return task
	return null


## 仅当 Variant 是 Thread 时返回其强类型引用。
## [br]
## @api private
## [br]
static func _variant_to_thread(value: Variant) -> Thread:
	if value is Thread:
		var thread: Thread = value
		return thread
	return null


## 仅当加载结果的 resource 字段为 Resource 时返回该值。
## [br]
## @api private
## [br]
static func _get_load_result_resource(load_result: Dictionary) -> Resource:
	var value: Variant = GFVariantData.get_option_value(load_result, "resource")
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


## 将字符串追加到调试快照使用的 PackedStringArray。
## [br]
## @api private
## [br]
static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _added: bool = target.append(value)
