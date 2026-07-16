# GFThreadedResourceOperation: 单个 threaded ResourceLoader 请求的内部生命周期句柄。
#
# 该对象不发起加载，只记录请求路径、引用计数、取消、drain 和终态结果。
extends RefCounted


# --- 常量 ---

## 请求正在等待 Godot threaded loader 完成。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_IN_PROGRESS: StringName = &"in_progress"

## 上层已经取消并等待底层请求自然完成。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_DRAINING: StringName = &"draining"

## 请求成功完成，结果仍允许交给当前消费者。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_COMPLETED: StringName = &"completed"

## 请求失败，结果仍允许交给当前消费者。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_FAILED: StringName = &"failed"

## 请求目标无效，结果仍允许交给当前消费者。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_INVALID: StringName = &"invalid"

## 请求已经 drain 到终态，但结果被上层取消策略抑制。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_SUPPRESSED: StringName = &"suppressed"


# --- 私有变量 ---

var _path: String = ""
var _type_hint: String = ""
var _status: StringName = STATUS_IN_PROGRESS
var _progress: float = 0.0
var _resource: Resource = null
var _error_message: String = ""
var _request_error: Error = OK
var _ref_count: int = 0
var _cancel_requested: bool = false
var _cancel_reason: StringName = &""
var _suppress_result: bool = false
var _drained_resource: bool = false
var _started_msec: int = 0
var _finished_msec: int = 0


# --- 框架内部方法 ---

## 配置请求身份。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选 ResourceLoader 类型提示。
func configure(path: String, type_hint: String = "") -> void:
	_path = path
	_type_hint = type_hint
	_status = STATUS_IN_PROGRESS
	_progress = 0.0
	_resource = null
	_error_message = ""
	_request_error = OK
	_ref_count = 0
	_cancel_requested = false
	_cancel_reason = &""
	_suppress_result = false
	_drained_resource = false
	_started_msec = 0
	_finished_msec = 0


## 标记 Godot threaded request 已经发起或发起失败。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param error: `ResourceLoader.load_threaded_request()` 返回值。
func mark_requested(error: Error) -> void:
	_request_error = error
	_started_msec = Time.get_ticks_msec()
	if error != OK:
		_status = STATUS_FAILED
		_error_message = "threaded_request_failed:%d" % error
		_finished_msec = _started_msec
		return

	_status = STATUS_IN_PROGRESS


## 增加一个上层消费者引用。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 当前引用数量。
func retain() -> int:
	_ref_count += 1
	return _ref_count


## 释放一个上层消费者引用。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 当前引用数量。
func release() -> int:
	_ref_count = maxi(_ref_count - 1, 0)
	if _ref_count == 0 and not is_terminal():
		_status = STATUS_DRAINING
		_suppress_result = true
	return _ref_count


## 请求取消并进入 drain 语义。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param reason: 取消原因。
## [br]
## @param suppress_result: 为 true 时终态结果不再交给上层消费者。
func request_cancel(reason: StringName = &"cancelled", suppress_result: bool = true) -> void:
	if is_terminal():
		return
	_cancel_requested = true
	_cancel_reason = reason
	_suppress_result = _suppress_result or suppress_result
	_status = STATUS_DRAINING


## 重新允许消费者接收结果，用于取消后同一路径重试复用底层请求。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
func resume_delivery() -> void:
	if is_terminal():
		return
	_cancel_requested = false
	_cancel_reason = &""
	_suppress_result = false
	_status = STATUS_IN_PROGRESS


## 应用一次底层 ResourceLoader 轮询结果。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param poll_result: 由 threaded resource adapter 返回的结构化结果。
## [br]
## @schema poll_result: Dictionary，包含 status、progress、resource、has_resource 和 error。
func apply_poll_result(poll_result: Dictionary) -> void:
	if is_terminal():
		return

	var poll_status: StringName = GFVariantData.get_option_string_name(poll_result, "status", STATUS_INVALID)
	_progress = clampf(GFVariantData.get_option_float(poll_result, "progress", _progress), 0.0, 1.0)

	match poll_status:
		&"in_progress":
			_status = STATUS_DRAINING if _should_suppress_terminal_result() else STATUS_IN_PROGRESS

		&"loaded":
			_progress = 1.0
			_finish_loaded(poll_result)

		&"failed":
			_finish_failed(GFVariantData.get_option_string(poll_result, "error", "thread_load_failed"), STATUS_FAILED)

		&"invalid":
			_finish_failed(GFVariantData.get_option_string(poll_result, "error", "invalid_resource"), STATUS_INVALID)

		_:
			_finish_failed("unknown_thread_status", STATUS_INVALID)


## 请求是否已经进入终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 请求处于 completed、failed、invalid 或 suppressed 时返回 true。
func is_terminal() -> bool:
	return (
		_status == STATUS_COMPLETED
		or _status == STATUS_FAILED
		or _status == STATUS_INVALID
		or _status == STATUS_SUPPRESSED
	)


## 请求是否正在 drain。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 上层已取消且底层仍需轮询到终态时返回 true。
func is_draining() -> bool:
	return _status == STATUS_DRAINING


## 终态结果是否应该交给上层消费者。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 有活跃引用且未被抑制时返回 true。
func can_deliver_result() -> bool:
	return is_terminal() and _status != STATUS_SUPPRESSED and not _suppress_result and _ref_count > 0


## 获取资源路径。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 资源路径。
func get_path() -> String:
	return _path


## 获取类型提示。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return ResourceLoader 类型提示。
func get_type_hint() -> String:
	return _type_hint


## 获取当前状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 当前状态常量。
func get_status() -> StringName:
	return _status


## 获取当前进度。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 当前进度。
func get_progress() -> float:
	return _progress


## 获取加载结果资源。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 加载成功且未被抑制时返回资源。
func get_resource() -> Resource:
	return _resource


## 获取错误文本。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 错误文本。
func get_error_message() -> String:
	return _error_message


## 获取请求发起错误码。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return Godot Error。
func get_request_error() -> Error:
	return _request_error


## 获取消费者引用数量。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 引用数量。
func get_ref_count() -> int:
	return _ref_count


## 检查是否请求取消。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	return _cancel_requested


## 导出轮询结果。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 结构化轮询结果。
## [br]
## @schema return: Dictionary，包含 status、progress、resource、has_resource、error、cancel_requested、cancel_reason、suppressed、ref_count 和 drained_resource。
func to_poll_result() -> Dictionary:
	return {
		"status": _status,
		"progress": _progress,
		"resource": _resource,
		"has_resource": _resource != null,
		"error": _error_message,
		"cancel_requested": _cancel_requested,
		"cancel_reason": _cancel_reason,
		"suppressed": _status == STATUS_SUPPRESSED or _suppress_result,
		"ref_count": _ref_count,
		"drained_resource": _drained_resource,
		"request_error": _request_error,
	}


## 导出调试快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 path、type_hint、status、progress、ref_count、cancel、suppress 和时间戳。
func to_dictionary() -> Dictionary:
	return {
		"path": _path,
		"type_hint": _type_hint,
		"status": _status,
		"progress": _progress,
		"error": _error_message,
		"request_error": _request_error,
		"ref_count": _ref_count,
		"cancel_requested": _cancel_requested,
		"cancel_reason": _cancel_reason,
		"suppress_result": _suppress_result,
		"has_resource": _resource != null,
		"drained_resource": _drained_resource,
		"started_msec": _started_msec,
		"finished_msec": _finished_msec,
	}


# --- 私有/辅助方法 ---

func _finish_loaded(poll_result: Dictionary) -> void:
	var loaded_resource: Resource = _get_resource_value(GFVariantData.get_option_value(poll_result, "resource"))
	_drained_resource = loaded_resource != null
	_finished_msec = Time.get_ticks_msec()
	if _should_suppress_terminal_result():
		_resource = null
		_status = STATUS_SUPPRESSED
		return

	_resource = loaded_resource
	_status = STATUS_COMPLETED


func _finish_failed(message: String, failed_status: StringName) -> void:
	_error_message = message
	_finished_msec = Time.get_ticks_msec()
	if _should_suppress_terminal_result():
		_status = STATUS_SUPPRESSED
		return

	_status = failed_status


func _should_suppress_terminal_result() -> bool:
	return _suppress_result or _cancel_requested or _ref_count <= 0


static func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null
