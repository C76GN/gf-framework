@tool

## GFEditorBackgroundRequestTask: 编辑器后台请求任务句柄。
##
## 该类型把 worker、Thread、取消请求和 wait 结果归属收敛到同一个对象，
## 让 Dock 只处理 UI 状态和业务结果，不直接持有后台线程细节。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFEditorBackgroundRequestTask
extends RefCounted


# --- 私有变量 ---

var _worker: RefCounted = null
var _thread: Object = null
var _worker_method: StringName = &"run_request"
var _request: Dictionary = {}
var _started: bool = false
var _finished: bool = false
var _cancel_requested: bool = false
var _start_error: Error = OK
var _result_value: Variant = null


# --- 框架内部方法 ---

## 配置后台请求任务。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param worker: 执行请求的后台 worker。
## [br]
## @param request: 传给 worker 的请求字典。
## [br]
## @param options: 任务选项。
## [br]
## @return 当前任务句柄。
## [br]
## @schema request: Dictionary copied before the worker thread starts.
## [br]
## @schema options: Dictionary，支持 worker_method 和 thread；thread 仅用于测试或替代执行器注入。
func configure(
	worker: RefCounted,
	request: Dictionary,
	options: Dictionary = {}
) -> GFEditorBackgroundRequestTask:
	if _started:
		push_error("[GFEditorBackgroundRequestTask] 已启动的任务不能重新配置。")
		return self
	_worker = worker
	_request = request.duplicate(true)
	_worker_method = _read_worker_method(options)
	_thread = _read_thread(options)
	_finished = false
	_cancel_requested = false
	_start_error = OK
	_result_value = null
	return self


## 启动后台请求。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return Godot 错误码。
func start() -> Error:
	if _started:
		return ERR_BUSY
	if _worker == null:
		_start_error = ERR_UNCONFIGURED
		_finished = true
		return _start_error
	if not _worker.has_method(_worker_method):
		_start_error = ERR_INVALID_PARAMETER
		_finished = true
		return _start_error
	if _thread == null:
		_thread = Thread.new()
	if not _thread.has_method("start"):
		_start_error = ERR_INVALID_PARAMETER
		_finished = true
		return _start_error

	var work_callable: Callable = Callable(_worker, _worker_method).bind(_request.duplicate(true))
	var start_result: Variant = _thread.call("start", work_callable)
	_start_error = _to_error(start_result, OK)
	if _start_error != OK:
		_finished = true
		return _start_error
	_started = true
	return OK


## 请求取消后台任务。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func request_cancel() -> void:
	_cancel_requested = true
	if _worker == null:
		return
	if not _worker.has_method("cancel"):
		return
	var _cancel_result: Variant = _worker.call("cancel")


## 返回任务是否已请求取消。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	return _cancel_requested


## 返回任务是否已成功启动。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return start() 返回 OK 后返回 true。
func is_started() -> bool:
	return _started


## 返回后台线程是否仍在运行。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 线程仍在运行时返回 true。
func is_running() -> bool:
	if not _started or _finished or _thread == null:
		return false
	if not _thread.has_method("is_alive"):
		return false
	var alive_value: Variant = _thread.call("is_alive")
	if alive_value is bool:
		var alive: bool = alive_value
		return alive
	return false


## 等待后台线程结束并取得 worker 返回值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return worker 返回值。
## [br]
## @schema return: Variant returned by the worker method.
func wait_to_finish() -> Variant:
	if _finished:
		return _result_value
	if _thread == null:
		_finished = true
		return _result_value
	if not _thread.has_method("wait_to_finish"):
		_finished = true
		return _result_value
	_result_value = _thread.call("wait_to_finish")
	_finished = true
	return _result_value


## 返回任务是否已完成。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return wait_to_finish() 已归属结果后返回 true。
func is_finished() -> bool:
	return _finished


## 返回最近一次 start() 错误码。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return Godot 错误码。
func get_start_error() -> Error:
	return _start_error


## 返回任务调试快照。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing lifecycle flags and worker method name.
func get_debug_snapshot() -> Dictionary:
	return {
		"worker_method": String(_worker_method),
		"started": _started,
		"finished": _finished,
		"running": is_running(),
		"cancel_requested": _cancel_requested,
		"start_error": _start_error,
	}


# --- 私有/辅助方法 ---

func _read_worker_method(options: Dictionary) -> StringName:
	if not options.has("worker_method"):
		return &"run_request"
	var value: Variant = options["worker_method"]
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	return &"run_request"


func _read_thread(options: Dictionary) -> Object:
	if not options.has("thread"):
		return null
	var value: Variant = options["thread"]
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _to_error(value: Variant, fallback: Error) -> Error:
	if value is int:
		var error_code: int = value
		return error_code as Error
	return fallback
