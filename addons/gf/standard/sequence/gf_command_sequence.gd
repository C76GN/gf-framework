## GFCommandSequence: 通用顺序指令执行器。
##
## 可运行 `GFSequenceStep`、`GFCommand` 或任何实现 `execute()` / `resolve()`
## 的对象。它只负责顺序、等待和架构注入，不规定具体业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCommandSequence
extends RefCounted


# --- 信号 ---

## 序列开始执行时发出。
## [br]
## @api public
signal sequence_started

## 步骤开始执行时发出。
## [br]
## @api public
## [br]
## @param index: 步骤索引。
## [br]
## @param step: 步骤对象、命令或 Callable。
## [br]
## @schema step: Variant sequence step value.
signal step_started(index: int, step: Variant)

## 步骤执行完毕时发出。
## [br]
## @api public
## [br]
## @param index: 步骤索引。
## [br]
## @param step: 步骤对象、命令或 Callable。
## [br]
## @schema step: Variant sequence step value.
signal step_completed(index: int, step: Variant)

## 步骤报告失败时发出。
## [br]
## @api public
## [br]
## @param index: 步骤索引。
## [br]
## @param step: 步骤对象、命令或 Callable。
## [br]
## @param error: 错误消息。
## [br]
## @schema step: Variant sequence step value.
signal step_failed(index: int, step: Variant, error: String)

## 序列全部执行完成时发出。
## [br]
## @api public
signal sequence_completed

## 序列因步骤失败而停止时发出。
## [br]
## @api public
## [br]
## @param report: 运行报告。
## [br]
## @schema report: Dictionary run report.
signal sequence_failed(report: Dictionary)

## 序列被取消时发出。
## [br]
## @api public
signal sequence_cancelled


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共变量 ---

## 默认步骤列表。
## [br]
## @api public
## [br]
## @schema steps: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().
var steps: Array = []

## 序列上下文。
## [br]
## @api public
var context: GFSequenceContext

## 当前是否正在执行。
## [br]
## @api public
var is_running: bool = false

## 等待步骤 Signal 的超时时间（秒）。小于等于 0 时表示不启用超时。
## [br]
## @api public
var signal_timeout_seconds: float = 30.0

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
var signal_timeout_respects_time_scale: bool = true

## 步骤返回失败结果时是否停止后续步骤。
## [br]
## @api public
var stop_on_error: bool = false

## stop_on_error 生效后，是否对已完成且实现 undo() 的步骤逆序回滚。
## [br]
## @api public
var rollback_on_failure: bool = false

## 最近一次运行报告。
## [br]
## @api public
## [br]
## @schema last_run_report: Dictionary run report from the most recent run().
var last_run_report: Dictionary = {}


# --- 私有变量 ---

var _cancel_requested: bool = false
var _architecture_ref: WeakRef = null
var _current_step: Variant = null
var _last_wait_result: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建指令序列。
## [br]
## @api public
## [br]
## @param p_steps: 初始步骤列表。
## [br]
## @param p_context: 初始序列上下文；为空时自动创建。
## [br]
## @schema p_steps: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().
func _init(p_steps: Array = [], p_context: GFSequenceContext = null) -> void:
	steps = p_steps.duplicate()
	context = p_context if p_context != null else GFSequenceContext.new()


# --- 公共方法 ---

## 注入架构。通常由 GFArchitecture 创建或注册时自动调用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null
	if context != null:
		context.set_architecture(architecture)


## 运行序列。
## [br]
## @api public
## [br]
## @param p_steps: 可选临时步骤列表；为空时使用 `steps`。
## [br]
## @schema p_steps: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().
func run(p_steps: Array = []) -> void:
	if is_running:
		push_warning("[GFCommandSequence] 序列正在执行，忽略重复 run()。")
		return

	var run_steps: Array = p_steps if not p_steps.is_empty() else steps
	is_running = true
	_cancel_requested = false
	var completed_steps: Array = []
	var results: Array[Dictionary] = []
	var failed: bool = false
	var failed_index: int = -1
	var failed_error: String = ""
	sequence_started.emit()

	for index: int in range(run_steps.size()):
		_last_wait_result.clear()
		if _cancel_requested:
			break

		var step: Variant = run_steps[index]
		if step == null:
			continue

		_current_step = step
		step_started.emit(index, step)
		var result: Variant = _execute_step(step)
		if _cancel_requested:
			break
		if _should_wait_for_step(step, result):
			var result_signal: Signal = result
			result = await _await_signal_result_safely(result_signal)
			if _cancel_requested:
				break
		var step_error: String = _get_step_error(result)
		if not step_error.is_empty():
			failed = true
			failed_index = index
			failed_error = step_error
			results.append(_make_step_report(index, false, step_error, result))
			step_failed.emit(index, step, step_error)
			if stop_on_error:
				break
			_current_step = null
			continue

		step_completed.emit(index, step)
		completed_steps.append(step)
		results.append(_make_step_report(index, true, "", result))
		_current_step = null

	_current_step = null
	var rolled_back: bool = false
	var rollback_errors: Array[Dictionary] = []
	if failed and stop_on_error and rollback_on_failure:
		rollback_errors = await _rollback_steps(completed_steps)
		rolled_back = true
	is_running = false

	last_run_report = {
		"cancelled": _cancel_requested,
		"failed": failed,
		"failed_index": failed_index,
		"error": failed_error,
		"succeeded": completed_steps.size(),
		"rolled_back": rolled_back,
		"rollback_failed": not rollback_errors.is_empty(),
		"rollback_errors": rollback_errors,
		"results": results,
	}
	if _cancel_requested:
		sequence_cancelled.emit()
	elif failed and stop_on_error:
		sequence_failed.emit(last_run_report)
	else:
		sequence_completed.emit()


## 请求取消序列。当前步骤实现取消入口时会先收到取消请求，正在等待的 Signal 会在下一帧取消检查后停止。
## [br]
## @api public
func cancel() -> void:
	if _cancel_requested:
		return
	_cancel_requested = true
	_cancel_current_step()


## 设置等待 Signal 的超时时间，并返回自身以便链式调用。
## [br]
## @api public
## [br]
## @param seconds: 超时时间；小于等于 0 时表示不启用超时。
## [br]
## @param respect_time_scale: 是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @return 当前序列。
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFCommandSequence:
	signal_timeout_seconds = maxf(seconds, 0.0)
	signal_timeout_respects_time_scale = respect_time_scale
	return self


## 设置失败处理策略，并返回自身以便链式调用。
## [br]
## @api public
## [br]
## @param should_stop_on_error: 是否在失败结果后停止。
## [br]
## @param should_rollback_on_failure: 是否逆序调用已完成步骤 undo()。
## [br]
## @return 当前序列。
func with_failure_policy(
	should_stop_on_error: bool = true,
	should_rollback_on_failure: bool = false
) -> GFCommandSequence:
	stop_on_error = should_stop_on_error
	rollback_on_failure = should_rollback_on_failure
	return self


# --- 私有/辅助方法 ---

func _execute_step(step: Variant) -> Variant:
	var step_object: Object = _get_valid_step_object(step)
	if step_object != null:
		_inject_step(step_object)
		if step_object is GFSequenceStep:
			var sequence_step: GFSequenceStep = step_object
			return sequence_step.execute(context)
		if step_object.has_method("execute"):
			return step_object.call("execute")
		if step_object.has_method("resolve"):
			return step_object.call("resolve")
	if step is Callable:
		var callable: Callable = step
		if callable.is_valid():
			return callable.call()
	return _make_unsupported_step_result(step)


func _cancel_current_step() -> void:
	if _current_step == null:
		return

	var step_object: Object = _get_valid_step_object(_current_step)
	if step_object == null:
		return

	if step_object is GFSequenceStep:
		var sequence_step: GFSequenceStep = step_object
		sequence_step.cancel(context)
		return

	if step_object.has_method("cancel"):
		var _cancel_result: Variant = step_object.call("cancel")


func _get_step_error(result: Variant) -> String:
	if not (result is Dictionary):
		return ""

	var data: Dictionary = result
	var failed: bool = false
	if data.has("ok") and not GFVariantData.get_option_bool(data, "ok", true):
		failed = true
	if data.has("success") and not GFVariantData.get_option_bool(data, "success", true):
		failed = true

	var status: String = GFVariantData.get_option_string(data, "status").to_lower()
	if status == "error" or status == "failed" or status == "failure":
		failed = true

	if not failed:
		return ""

	var error_value: Variant = GFVariantData.get_option_value(
		data,
		"error",
		GFVariantData.get_option_value(
			data,
			"message",
			GFVariantData.get_option_value(data, "reason", "")
		)
	)
	if error_value is Dictionary or error_value is Array:
		return JSON.stringify(error_value)

	var error: String = GFVariantData.to_text(error_value)
	return error if not error.is_empty() else "Step failed."


func _make_step_report(index: int, ok: bool, error: String, result: Variant) -> Dictionary:
	var report: Dictionary = {
		"index": index,
		"ok": ok,
		"error": error,
		"result": result,
	}
	if not _last_wait_result.is_empty():
		report["wait_result"] = _last_wait_result.duplicate(true)
		report["wait_status"] = _get_last_wait_status()
		report["wait_completed"] = GFVariantData.get_option_bool(_last_wait_result, "completed")
	return report


func _make_unsupported_step_result(step: Variant) -> Dictionary:
	return {
		"ok": false,
		"status": "failed",
		"error": "unsupported_step",
		"type": type_string(typeof(step)),
	}


func _rollback_steps(completed_steps: Array) -> Array[Dictionary]:
	var rollback_errors: Array[Dictionary] = []
	var previous_wait_result: Dictionary = _last_wait_result.duplicate(true)
	for index: int in range(completed_steps.size() - 1, -1, -1):
		var step: Object = _get_valid_step_object(completed_steps[index])
		if step == null or not step.has_method("undo"):
			continue
		_inject_step(step)
		var result: Variant = step.call("undo")
		if result is Signal:
			var result_signal: Signal = result
			result = await _await_signal_result_safely(result_signal)
		var step_error: String = _get_step_error(result)
		if not step_error.is_empty():
			var rollback_report: Dictionary = {
				"index": index,
				"error": step_error,
				"result": result,
			}
			if not _last_wait_result.is_empty():
				rollback_report["wait_result"] = _last_wait_result.duplicate(true)
				rollback_report["wait_status"] = _get_last_wait_status()
			rollback_errors.append(rollback_report)
	_last_wait_result = previous_wait_result
	return rollback_errors


func _inject_step(step: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	if step.has_method("inject_dependencies"):
		var _dependencies_injected: Variant = step.call("inject_dependencies", architecture)
	if step.has_method("inject"):
		var _injected: Variant = step.call("inject", architecture)


func _should_wait_for_step(step: Variant, result: Variant) -> bool:
	if not (result is Signal):
		return false
	var step_object: Object = _get_valid_step_object(step)
	if step_object is GFSequenceStep:
		var sequence_step: GFSequenceStep = step_object
		return sequence_step.wait_for_result
	return true


func _get_valid_step_object(step: Variant) -> Object:
	return _INSTANCE_GUARD._get_live_object(step)


func _await_signal_result_safely(result_signal: Signal) -> Variant:
	var wait_result: Dictionary = await _GF_ASYNC_WAIT_SUPPORT.await_signal_payload_safely(
		result_signal,
		_should_continue_waiting,
		_get_time_utility(),
		signal_timeout_seconds,
		signal_timeout_respects_time_scale,
		"[GFCommandSequence] 等待 Signal 超时，序列将继续执行后续步骤。"
	)
	_last_wait_result = wait_result.duplicate(true)
	if not GFVariantData.get_option_bool(wait_result, "completed"):
		return null
	return _normalize_signal_result(GFVariantData.get_option_array(wait_result, "args"))


func _get_last_wait_status() -> StringName:
	var status: StringName = GFVariantData.get_option_string_name(_last_wait_result, "status")
	if status != &"":
		return status
	if GFVariantData.get_option_bool(_last_wait_result, "completed"):
		return GFAsyncWaitUtility.STATUS_COMPLETED
	if _cancel_requested:
		return GFAsyncWaitUtility.STATUS_CANCELLED
	return GFAsyncWaitUtility.STATUS_TIMEOUT


func _normalize_signal_result(args: Variant) -> Variant:
	if not (args is Array):
		return args
	var values: Array = args
	if values.is_empty():
		return null
	if values.size() == 1:
		return values[0]
	return values


func _get_time_utility() -> GFTimeUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	var utility: Object = architecture.get_utility(GFTimeUtility)
	if utility is GFTimeUtility:
		var time_utility: GFTimeUtility = utility
		return time_utility
	return null


func _should_continue_waiting() -> bool:
	return not _cancel_requested


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	if context != null:
		return context.get_architecture()
	return GFAutoload.get_architecture_or_null()
