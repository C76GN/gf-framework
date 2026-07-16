# GFThreadedResourceCoordinator: threaded ResourceLoader 请求的内部协调器。
#
# Asset、Jobs 与 Scene 工具通过这里统一请求、复用、取消和 drain Godot threaded loader。
extends RefCounted


# --- 常量 ---

const _THREADED_RESOURCE_LOAD_ADAPTER = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")
const _THREADED_RESOURCE_OPERATION_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_operation.gd")


# --- 私有变量 ---

var _operations: Dictionary = {}
var _request_callback: Callable = Callable()
var _poll_callback: Callable = Callable()


# --- 框架内部方法 ---

## 配置底层请求与轮询回调。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param request_callback: 可选请求回调，签名为 `func(path: String, type_hint: String) -> Error`。
## [br]
## @param poll_callback: 可选轮询回调，签名为 `func(path: String, previous_progress: float) -> Dictionary`。
func configure(request_callback: Callable = Callable(), poll_callback: Callable = Callable()) -> void:
	_request_callback = request_callback
	_poll_callback = poll_callback


## 发起或复用 threaded resource operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @return 请求 operation；发起失败时 operation 会处于 failed 终态。
func request(path: String, type_hint: String = "") -> _THREADED_RESOURCE_OPERATION_SCRIPT:
	if path.is_empty():
		return _make_failed_operation(path, type_hint, ERR_INVALID_PARAMETER)

	var existing: _THREADED_RESOURCE_OPERATION_SCRIPT = get_operation(path)
	if existing != null and not existing.is_terminal():
		if not _type_hints_are_compatible(existing.get_type_hint(), type_hint):
			return _make_failed_operation(path, type_hint, ERR_ALREADY_IN_USE)
		var _existing_ref_count: int = existing.retain()
		existing.resume_delivery()
		return existing

	if existing != null and existing.is_terminal():
		forget_operation(existing)

	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _THREADED_RESOURCE_OPERATION_SCRIPT.new()
	operation.configure(path, type_hint)
	var _ref_count: int = operation.retain()
	var request_error: Error = _request_threaded_resource(path, type_hint)
	operation.mark_requested(request_error)
	if request_error == OK:
		_operations[path] = operation
	return operation


## 取得指定路径的 operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @return 当前 operation；不存在时返回 null。
func get_operation(path: String) -> _THREADED_RESOURCE_OPERATION_SCRIPT:
	var value: Variant = GFVariantData.get_option_value(_operations, path)
	if value is _THREADED_RESOURCE_OPERATION_SCRIPT:
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = value
		return operation
	return null


## 增加 operation 消费者引用。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param operation: 目标 operation。
## [br]
## @return 当前引用数量。
func retain_operation(operation: _THREADED_RESOURCE_OPERATION_SCRIPT) -> int:
	if operation == null or operation.is_terminal():
		return 0
	var ref_count: int = operation.retain()
	operation.resume_delivery()
	return ref_count


## 释放 operation 消费者引用。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param operation: 目标 operation。
## [br]
## @return 当前引用数量。
func release_operation(operation: _THREADED_RESOURCE_OPERATION_SCRIPT) -> int:
	if operation == null:
		return 0
	return operation.release()


## 请求取消 operation，并保留底层请求用于 drain。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param operation: 目标 operation。
## [br]
## @param reason: 取消原因。
## [br]
## @param release_consumer: 是否同时释放一个消费者引用。
func cancel_operation(
	operation: _THREADED_RESOURCE_OPERATION_SCRIPT,
	reason: StringName = &"cancelled",
	release_consumer: bool = true
) -> void:
	if operation == null or operation.is_terminal():
		return
	if release_consumer:
		var _ref_count: int = operation.release()
	operation.request_cancel(reason, true)


## 轮询 operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param operation: 目标 operation。
## [br]
## @return 结构化轮询结果。
## [br]
## @schema return: Dictionary，包含 status、progress、resource、has_resource、error、cancel_requested、suppressed 和 ref_count。
func poll_operation(operation: _THREADED_RESOURCE_OPERATION_SCRIPT) -> Dictionary:
	if operation == null:
		return _make_invalid_poll_result()
	if operation.is_terminal():
		return operation.to_poll_result()

	var poll_result: Dictionary = _poll_threaded_resource(operation.get_path(), operation.get_progress())
	operation.apply_poll_result(poll_result)
	return operation.to_poll_result()


## 轮询所有已经取消且需要 drain 的 operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 本次到达终态并被清理的 operation 数量。
func drain_cancelled_operations() -> int:
	var drained_count: int = 0
	var paths: Array = _operations.keys()
	for path: String in paths:
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = get_operation(path)
		if operation == null:
			continue
		if not operation.is_draining() and not operation.is_cancel_requested():
			continue
		var result: Dictionary = poll_operation(operation)
		var status: StringName = GFVariantData.get_option_string_name(result, "status", _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_INVALID)
		if _is_terminal_status(status):
			forget_operation(operation)
			drained_count += 1
	return drained_count


## 取消所有未完成 operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param reason: 取消原因。
func cancel_all(reason: StringName = &"cancelled") -> void:
	for path: String in _operations.keys():
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = get_operation(path)
		if operation != null and not operation.is_terminal():
			while operation.get_ref_count() > 0:
				var _ref_count: int = operation.release()
			operation.request_cancel(reason, true)


## 清理一个已到终态的 operation。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param operation: 目标 operation。
func forget_operation(operation: _THREADED_RESOURCE_OPERATION_SCRIPT) -> void:
	if operation == null:
		return
	if not operation.is_terminal():
		return
	var path: String = operation.get_path()
	if get_operation(path) == operation:
		var _removed: bool = _operations.erase(path)


## 清空 operation 表。调用方应只在没有未完成底层请求时使用。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
func clear() -> void:
	_operations.clear()


## 导出调试快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 operation_count、active_paths、draining_paths、terminal_paths 和 operations。
func get_debug_snapshot() -> Dictionary:
	var active_paths: PackedStringArray = PackedStringArray()
	var draining_paths: PackedStringArray = PackedStringArray()
	var terminal_paths: PackedStringArray = PackedStringArray()
	var operation_snapshots: Array[Dictionary] = []

	for path: String in _operations.keys():
		var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = get_operation(path)
		if operation == null:
			continue
		operation_snapshots.append(operation.to_dictionary())
		if operation.is_terminal():
			_append_packed_string(terminal_paths, path)
		elif operation.is_draining() or operation.is_cancel_requested():
			_append_packed_string(draining_paths, path)
		else:
			_append_packed_string(active_paths, path)

	active_paths.sort()
	draining_paths.sort()
	terminal_paths.sort()
	return {
		"operation_count": _operations.size(),
		"active_count": active_paths.size(),
		"draining_count": draining_paths.size(),
		"terminal_count": terminal_paths.size(),
		"active_paths": active_paths,
		"draining_paths": draining_paths,
		"terminal_paths": terminal_paths,
		"operations": operation_snapshots,
	}


# --- 私有/辅助方法 ---

func _request_threaded_resource(path: String, type_hint: String) -> Error:
	if _request_callback.is_valid():
		var callback_result: Variant = _request_callback.call(path, type_hint)
		return _to_error(callback_result, ERR_CANT_CREATE)
	return _THREADED_RESOURCE_LOAD_ADAPTER.request(path, type_hint)


func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
	if _poll_callback.is_valid():
		var callback_result: Variant = _poll_callback.call(path, previous_progress)
		if callback_result is Dictionary:
			var result: Dictionary = callback_result
			return result
		return {
			"status": _THREADED_RESOURCE_LOAD_ADAPTER.STATUS_INVALID,
			"progress": previous_progress,
			"resource": null,
			"has_resource": false,
			"error": "invalid_poll_callback_result",
		}
	return _THREADED_RESOURCE_LOAD_ADAPTER.poll(path, previous_progress)


func _make_failed_operation(
	path: String,
	type_hint: String,
	error: Error
) -> _THREADED_RESOURCE_OPERATION_SCRIPT:
	var operation: _THREADED_RESOURCE_OPERATION_SCRIPT = _THREADED_RESOURCE_OPERATION_SCRIPT.new()
	operation.configure(path, type_hint)
	operation.mark_requested(error)
	return operation


func _make_invalid_poll_result() -> Dictionary:
	return {
		"status": _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_INVALID,
		"progress": 0.0,
		"resource": null,
		"has_resource": false,
		"error": "missing_operation",
		"cancel_requested": false,
		"suppressed": false,
		"ref_count": 0,
	}


func _type_hints_are_compatible(left: String, right: String) -> bool:
	return left.is_empty() or right.is_empty() or left == right


func _is_terminal_status(status: StringName) -> bool:
	return (
		status == _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_COMPLETED
		or status == _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_FAILED
		or status == _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_INVALID
		or status == _THREADED_RESOURCE_OPERATION_SCRIPT.STATUS_SUPPRESSED
	)


static func _to_error(value: Variant, fallback: Error) -> Error:
	var fallback_code: int = int(fallback)
	var error_code: int = GFVariantData.to_int(value, fallback_code)
	return error_code as Error


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _appended: bool = target.append(value)
