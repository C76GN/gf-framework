@tool

## GFThumbnailRenderTask: 一次缩略图渲染任务句柄。
##
## 任务持有请求、运行状态、取消 token 和完成源；GFThumbnailRenderer 负责串行执行任务。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFThumbnailRenderTask
extends RefCounted


# --- 信号 ---

## 任务进入任意终态时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task: 当前任务。
signal completed(task: GFThumbnailRenderTask)

## 任务成功完成时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task: 当前任务。
## [br]
## @param result: 成功结果。
## [br]
## @schema result: Variant，Image、ImageTexture 或 MeshLibrary 预览计划 Dictionary。
signal succeeded(task: GFThumbnailRenderTask, result: Variant)

## 任务失败时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task: 当前任务。
## [br]
## @param error: 失败说明。
signal failed(task: GFThumbnailRenderTask, error: String)

## 任务取消完成时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task: 当前任务。
## [br]
## @param reason: 取消原因。
signal cancelled(task: GFThumbnailRenderTask, reason: StringName)


# --- 枚举 ---

## 缩略图渲染任务状态。
## [br]
## @api public
## [br]
## @since 8.0.0
enum State {
	## 等待执行。
	PENDING,
	## 正在执行。
	RUNNING,
	## 已成功完成。
	SUCCEEDED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}


# --- 私有变量 ---

var _task_id: int = 0
var _request: GFThumbnailRenderRequest = null
var _running: bool = false
var _cancel_source: GFCancellationSource = GFCancellationSource.new()
var _completion: GFAsyncCompletion = GFAsyncCompletion.new()


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param request: 要执行的缩略图渲染请求。
## [br]
## @param task_id: 可选任务 ID。
func _init(request: GFThumbnailRenderRequest = null, task_id: int = 0) -> void:
	_request = request
	_task_id = task_id
	var _completed_connected: Error = _completion.completed.connect(_on_completion_completed) as Error
	var _succeeded_connected: Error = _completion.succeeded.connect(_on_completion_succeeded) as Error
	var _failed_connected: Error = _completion.failed.connect(_on_completion_failed) as Error
	var _cancelled_connected: Error = _completion.cancelled.connect(_on_completion_cancelled) as Error


# --- 公共方法 ---

## 请求取消任务。
##
## 等待中的任务会立即进入取消终态；正在执行的任务会在下一个渲染检查点取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @return 本次调用是否发出了新的取消请求。
func cancel(reason: StringName = &"cancelled") -> bool:
	if is_finished():
		return false
	var cancel_requested: bool = _cancel_source.cancel(reason)
	if not cancel_requested:
		return false
	if not _running:
		return finish_cancelled(reason)
	return true


## 等待任务完成并返回最终结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 任务结果；失败时通常为 null，取消的 MeshLibrary 计划任务可返回部分计划。
## [br]
## @schema return: Variant，Image、ImageTexture、MeshLibrary 预览计划 Dictionary 或 null。
func wait_completed() -> Variant:
	if not is_finished():
		await _completion.completed
	return _completion.get_result()


## 返回任务 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 任务 ID。
func get_task_id() -> int:
	return _task_id


## 返回任务请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 任务请求。
func get_request() -> GFThumbnailRenderRequest:
	return _request


## 返回任务状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前任务状态。
func get_state() -> State:
	if _completion.is_successful():
		return State.SUCCEEDED
	if _completion.is_failed():
		return State.FAILED
	if _completion.is_cancelled():
		return State.CANCELLED
	if _running:
		return State.RUNNING
	return State.PENDING


## 返回是否仍在等待执行。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 等待执行时返回 true。
func is_pending() -> bool:
	return get_state() == State.PENDING


## 返回是否正在执行。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 正在执行时返回 true。
func is_running() -> bool:
	return get_state() == State.RUNNING


## 返回是否已经进入任意终态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已完成、失败或取消时返回 true。
func is_finished() -> bool:
	return _completion.is_completed()


## 返回是否成功完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 成功完成时返回 true。
func is_succeeded() -> bool:
	return _completion.is_successful()


## 返回是否失败。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 失败时返回 true。
func is_failed() -> bool:
	return _completion.is_failed()


## 返回是否取消完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 取消完成时返回 true。
func is_cancelled() -> bool:
	return _completion.is_cancelled()


## 返回是否已经请求取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已请求取消但可能尚未完成时返回 true。
func is_cancel_requested() -> bool:
	return _cancel_source.get_token().is_cancel_requested()


## 返回任务结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 任务结果。
## [br]
## @schema return: Variant，Image、ImageTexture、MeshLibrary 预览计划 Dictionary 或 null。
func get_result() -> Variant:
	return _completion.get_result()


## 返回失败说明。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 失败说明；非失败状态返回空字符串。
func get_error() -> String:
	return _completion.get_error()


## 返回取消原因。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 取消原因；未取消时返回空 StringName。
func get_cancel_reason() -> StringName:
	if _completion.is_cancelled():
		return _completion.get_cancel_reason()
	return _cancel_source.get_token().get_cancel_reason()


## 返回任务取消 token。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前任务的只读取消 token。
func get_cancel_token() -> GFCancellationToken:
	return _cancel_source.get_token()


## 返回任务完成源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前任务的完成源。
func get_completion() -> GFAsyncCompletion:
	return _completion


# --- 框架内部方法 ---

## 标记任务开始执行。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 标记成功时返回 true。
func mark_running() -> bool:
	if not is_pending():
		return false
	_running = true
	return true


## 标记任务成功完成。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param result: 成功结果。
## [br]
## @return 首次进入成功终态时返回 true。
## [br]
## @schema result: Variant，Image、ImageTexture 或 MeshLibrary 预览计划 Dictionary。
func succeed(result: Variant = null) -> bool:
	if is_cancel_requested():
		return finish_cancelled(get_cancel_reason(), result)
	_running = false
	return _completion.succeed(result)


## 标记任务失败。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param error: 失败说明。
## [br]
## @return 首次进入失败终态时返回 true。
func fail(error: String) -> bool:
	_running = false
	return _completion.fail(error)


## 标记任务取消完成。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param reason: 取消原因。
## [br]
## @param result: 可选部分结果。
## [br]
## @return 首次进入取消终态时返回 true。
## [br]
## @schema result: Variant，取消时保留的部分结果或 null。
func finish_cancelled(reason: StringName = &"cancelled", result: Variant = null) -> bool:
	if not _cancel_source.get_token().is_cancel_requested():
		var _cancel_requested_now: bool = _cancel_source.cancel(reason)
	_running = false
	return _completion.cancel(reason, {}, result)


# --- 信号处理函数 ---

func _on_completion_completed(_completion_source: GFAsyncCompletion) -> void:
	completed.emit(self)


func _on_completion_succeeded(result: Variant, _metadata: Dictionary) -> void:
	succeeded.emit(self, result)


func _on_completion_failed(error: String, _metadata: Dictionary) -> void:
	failed.emit(self, error)


func _on_completion_cancelled(reason: StringName, _metadata: Dictionary) -> void:
	cancelled.emit(self, reason)
