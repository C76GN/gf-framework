## GFJobWorker: 通用任务队列消费节点。
##
## 从 `GFJobQueueUtility` 中按批次取出等待任务，并交给项目提供的 Callable 处理。
## Worker 只管理执行节奏和完成/失败写回，不规定任务数据结构或业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFJobWorker
extends Node


# --- 信号 ---

## Worker 开始运行时发出。
## [br]
## @api public
signal worker_started

## Worker 停止运行时发出。
## [br]
## @api public
signal worker_stopped

## 任务处理完成时发出。
## [br]
## @api public
## [br]
## @param job: 被处理的任务。
signal job_processed(job: GFJob)

## 没有可处理任务时发出。
## [br]
## @api public
signal worker_idle


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 导出变量 ---

## 消费的队列名。
## [br]
## @api public
@export var queue_name: StringName = &"default"

## 每次处理的最大任务数量。
## [br]
## @api public
@export_range(1, 1024, 1, "or_greater") var batch_size: int = 1

## ready 后是否自动开始。
## [br]
## @api public
@export var auto_start: bool = true

## 是否在 physics process 中消费任务。
## [br]
## @api public
@export var process_in_physics: bool = false

## SceneTree 暂停时是否继续处理。
## [br]
## @api public
@export var process_while_paused: bool = false

## 等待异步任务处理器 Signal 的最长秒数。小于等于 0 时不启用超时。
## [br]
## @api public
@export var signal_timeout_seconds: float = 30.0

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
@export var signal_timeout_respects_time_scale: bool = true


# --- 公共变量 ---

## 可选任务队列工具实例；为空时从全局架构查询。
## [br]
## @api public
var queue_utility: GFJobQueueUtility = null

## 任务处理器，签名推荐为 `func(job: GFJob) -> Variant`。
## [br]
## @api public
var processor: Callable = Callable()


# --- 私有变量 ---

var _running: bool = false
var _processing: bool = false
var _next_job_in_flight: bool = false
var _active_wait_source: GFCancellationSource = null


# --- Godot 生命周期方法 ---

func _ready() -> void:
	process_mode = (
		Node.PROCESS_MODE_ALWAYS as Node.ProcessMode
		if process_while_paused
		else Node.PROCESS_MODE_INHERIT as Node.ProcessMode
	)
	if auto_start:
		start()


func _process(_delta: float) -> void:
	if not process_in_physics:
		_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"process_batch"))


func _physics_process(_delta: float) -> void:
	if process_in_physics:
		_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"process_batch"))


func _exit_tree() -> void:
	_cancel_active_wait(&"worker_exited_tree")


# --- 公共方法 ---

## 设置任务队列工具实例。
## [br]
## @api public
## [br]
## @param utility: 任务队列工具实例。
func set_queue_utility(utility: GFJobQueueUtility) -> void:
	queue_utility = utility


## 设置任务处理器。
## [br]
## @api public
## [br]
## @param job_processor: 任务处理器。
func set_processor(job_processor: Callable) -> void:
	processor = job_processor


## 开始消费任务。
## [br]
## @api public
func start() -> void:
	if _running:
		return
	_running = true
	worker_started.emit()


## 停止消费任务。
## [br]
## @api public
func stop() -> void:
	var was_running: bool = _running
	_running = false
	_cancel_active_wait(&"worker_stopped")
	if was_running:
		worker_stopped.emit()


## 检查 Worker 是否正在运行。
## [br]
## @api public
## [br]
## @return 正在运行返回 true。
func is_running() -> bool:
	return _running


## 处理一个任务。
## [br]
## @api public
## [br]
## @return 被处理的任务；没有任务或不可处理时返回 null。
func process_next_job() -> GFJob:
	if _next_job_in_flight:
		return null

	_next_job_in_flight = true
	var job: GFJob = await _process_next_job_once()
	_next_job_in_flight = false
	return job


## 按 batch_size 处理一批任务。
## [br]
## @api public
## [br]
## @return 实际处理数量。
func process_batch() -> int:
	if not _running or _processing or _next_job_in_flight:
		return 0
	if is_inside_tree() and get_tree().paused and not process_while_paused:
		return 0

	_processing = true
	var processed_count: int = 0
	for _index: int in range(maxi(batch_size, 1)):
		if not _running:
			break
		var job: GFJob = await process_next_job()
		if job == null:
			break
		processed_count += 1
	_processing = false
	if processed_count == 0:
		worker_idle.emit()
	return processed_count


## 获取 Worker 调试快照。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 running、processing、processing_next_job、waiting_for_processor、queue_name、batch_size、has_processor 和 has_queue_utility。
func get_debug_snapshot() -> Dictionary:
	return {
		"running": _running,
		"processing": _processing,
		"processing_next_job": _next_job_in_flight,
		"waiting_for_processor": _active_wait_source != null,
		"queue_name": String(queue_name),
		"batch_size": batch_size,
		"has_processor": processor.is_valid(),
		"has_queue_utility": _get_queue_utility() != null,
	}


# --- 私有/辅助方法 ---

func _process_next_job_once() -> GFJob:
	var utility: GFJobQueueUtility = _get_queue_utility()
	if utility == null or not processor.is_valid():
		return null
	var job: GFJob = utility.start_next_job(queue_name)
	if job == null:
		return null

	var result: Variant = processor.call(job)
	if result is Signal:
		var result_signal: Signal = _variant_to_signal(result)
		var wait_result: Dictionary = await _await_processor_signal_result(result_signal, job)
		if not GFVariantData.get_option_bool(wait_result, "completed", false):
			if not job.is_finished():
				var wait_status: StringName = GFVariantData.get_option_string_name(wait_result, "status", &"invalid")
				if wait_status == _GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED:
					var _cancel_job_result: Variant = utility.cancel_job(job.job_id)
				else:
					var failure_reason: String = _get_processor_wait_failure_reason(wait_status)
					var _fail_job_result: Variant = utility.fail_job(job.job_id, failure_reason, wait_result)
			_emit_job_processed_if_not_cancelled(job)
			return job
		if job.is_finished():
			_emit_job_processed_if_not_cancelled(job)
			return job
		result = GFVariantData.get_option_value(wait_result, "result")
	_apply_processor_result(utility, job, result)
	_emit_job_processed_if_not_cancelled(job)
	return job

func _get_queue_utility() -> GFJobQueueUtility:
	if queue_utility != null:
		return queue_utility
	var architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _variant_to_job_queue_utility(architecture.get_utility(GFJobQueueUtility))


func _await_processor_signal_result(result_signal: Signal, job: GFJob) -> Dictionary:
	var guard_node: Node = self if is_inside_tree() else null
	var wait_source: GFCancellationSource = GFCancellationSource.new()
	_active_wait_source = wait_source
	var wait_result: Dictionary = await _GF_ASYNC_WAIT_SUPPORT.await_signal_state(result_signal, {
		"should_continue": _should_continue_waiting.bind(job),
		"time_utility": _get_time_utility(),
		"timeout_seconds": signal_timeout_seconds,
		"respect_time_scale": signal_timeout_respects_time_scale,
		"timeout_warning": "[GFJobWorker] 等待任务处理器 Signal 超时，任务将标记为失败。",
		"guard_node": guard_node,
		"cancel_token": wait_source.get_token(),
		"capture_payload": true,
	})
	if _active_wait_source == wait_source:
		_active_wait_source = null
	wait_source.dispose()
	var completed: bool = GFVariantData.get_option_bool(wait_result, "completed", false)
	return {
		"completed": completed,
		"status": GFVariantData.get_option_string_name(wait_result, "status", &"invalid"),
		"result": _normalize_signal_result(GFVariantData.get_option_value(wait_result, "args", [])) if completed else null,
		"reason": GFVariantData.get_option_string_name(wait_result, "reason", &""),
		"metadata": GFVariantData.get_option_dictionary(wait_result, "metadata"),
	}


func _cancel_active_wait(reason: StringName) -> void:
	if _active_wait_source == null:
		return
	var _cancelled: bool = _active_wait_source.cancel(reason)


func _get_processor_wait_failure_reason(status: StringName) -> String:
	match status:
		_GF_ASYNC_WAIT_SUPPORT.STATUS_TIMEOUT:
			return "processor_signal_timeout"
		_GF_ASYNC_WAIT_SUPPORT.STATUS_INVALID:
			return "processor_signal_invalid"
		_:
			return "processor_signal_failed"


func _apply_processor_result(utility: GFJobQueueUtility, job: GFJob, result: Variant) -> void:
	if job == null or job.is_finished():
		return
	if result is Dictionary:
		var result_dictionary: Dictionary = GFVariantData.as_dictionary(result)
		if not GFVariantData.get_option_bool(result_dictionary, "ok", true):
			var _fail_job_result_279: Variant = utility.fail_job(job.job_id, GFVariantData.get_option_string(result_dictionary, "error"), result)
			return
		var _complete_job_result_281: Variant = utility.complete_job(job.job_id, result)
	elif result is bool and not GFVariantData.to_bool(result):
		var _fail_job_result_283: Variant = utility.fail_job(job.job_id, "", result)
	else:
		var _complete_job_result_285: Variant = utility.complete_job(job.job_id, result)


func _emit_job_processed_if_not_cancelled(job: GFJob) -> void:
	if job == null or job.status == GFJob.Status.CANCELLED:
		return
	job_processed.emit(job)


func _normalize_signal_result(result: Variant) -> Variant:
	if not (result is Array):
		return result

	var values: Array = GFVariantData.as_array(result)
	if values.is_empty():
		return null
	if values.size() == 1:
		return values[0]

	var first_value: Variant = values[0]
	if first_value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(GFVariantData.duplicate_variant(first_value))
		data["signal_args"] = GFVariantData.duplicate_variant(values)
		return data
	return values


func _get_time_utility() -> GFTimeUtility:
	var architecture: GFArchitecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _variant_to_time_utility(architecture.get_utility(GFTimeUtility))


func _should_continue_waiting(job: GFJob) -> bool:
	return job != null and not job.is_finished()


static func _variant_to_signal(value: Variant) -> Signal:
	if value is Signal:
		var signal_value: Signal = value
		return signal_value
	return Signal()


static func _variant_to_job_queue_utility(value: Variant) -> GFJobQueueUtility:
	if value is GFJobQueueUtility:
		var utility: GFJobQueueUtility = value
		return utility
	return null


static func _variant_to_time_utility(value: Variant) -> GFTimeUtility:
	if value is GFTimeUtility:
		var utility: GFTimeUtility = value
		return utility
	return null
