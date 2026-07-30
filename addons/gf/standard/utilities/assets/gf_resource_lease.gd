## GFResourceLease: 共享资源 Broker 返回的消费者所有权句柄。
##
## 每次请求都会得到独立 Lease；同一路径可以复用同一个底层 threaded load，
## 但取消或释放只影响当前消费者。未完成时释放最后一个 Lease 会让 Broker
## 继续 drain 已经发起且无法中止的 ResourceLoader 请求。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFResourceLease
extends RefCounted


# --- 常量 ---

## 请求正在等待 Broker admission。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_QUEUED: StringName = &"queued"

## 底层 threaded resource request 已经开始。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_LOADING: StringName = &"loading"

## 资源已经成功交付给当前消费者。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_COMPLETED: StringName = &"completed"

## 资源请求失败。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_FAILED: StringName = &"failed"

## 当前消费者已经取消请求。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CANCELLED: StringName = &"cancelled"


# --- 私有变量 ---

var _broker_ref: WeakRef = null
var _request_key: String = ""
var _path: String = ""
var _type_hint: String = ""
var _consumer_id: StringName = &""
var _status: StringName = STATUS_QUEUED
var _progress: float = 0.0
var _resource: Resource = null
var _error_message: String = ""
var _request_error: Error = OK
var _cancel_reason: StringName = &""
var _released: bool = false
var _exclusive: bool = false
var _require_idle: bool = false


# --- 公共方法 ---

## 取消当前消费者的请求。
##
## 取消不会影响复用同一底层请求的其他 Lease。若当前 Lease 是最后一个消费者，
## Broker 会继续 drain 已经开始的底层请求，但不会交付其结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 用于诊断的稳定取消原因。
func cancel(reason: StringName = &"cancelled") -> void:
	if _released:
		return
	if is_terminal():
		_release_local_reference()
		return

	var broker: Object = _get_broker()
	if broker == null:
		broker_mark_cancelled(reason)
		return
	if not broker.has_method(&"release_lease"):
		broker_mark_cancelled(reason)
		return
	var _release_result: Variant = broker.call(&"release_lease", self, reason)


## 释放当前 Lease 持有的消费者引用和已交付资源。
## [br]
## @api public
## [br]
## @since unreleased
func release() -> void:
	if _released:
		return
	cancel(&"released")
	_release_local_reference()


## 请求是否已经到达终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return completed、failed 或 cancelled 时返回 true。
func is_terminal() -> bool:
	return (
		_status == STATUS_COMPLETED
		or _status == STATUS_FAILED
		or _status == STATUS_CANCELLED
	)


## Lease 是否已经释放。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已释放时返回 true。
func is_released() -> bool:
	return _released


## 获取当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 状态常量。
func get_status() -> StringName:
	return _status


## 获取当前加载进度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 范围为 0.0 到 1.0 的进度值。
func get_progress() -> float:
	return _progress


## 获取加载成功的资源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功且尚未释放时返回资源，否则返回 null。
func get_resource() -> Resource:
	return _resource if not _released else null


## 获取资源路径。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Broker 使用的规范化加载路径。
func get_path() -> String:
	return _path


## 获取请求类型提示。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return ResourceLoader 类型提示。
func get_type_hint() -> String:
	return _type_hint


## 获取消费者标识。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 调用方提供的诊断标识。
func get_consumer_id() -> StringName:
	return _consumer_id


## 获取请求错误码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return admission 或底层请求失败的 Godot Error。
func get_request_error() -> Error:
	return _request_error


## 获取失败说明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 失败或取消说明。
func get_error_message() -> String:
	return _error_message


## 导出当前消费者视角的结构化状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Lease 状态字典。
## [br]
## @schema return: Dictionary with status, progress, resource, has_resource, error, request_error, path, type_hint, consumer_id, exclusive, require_idle, cancel_reason, and released.
func to_poll_result() -> Dictionary:
	var delivered_resource: Resource = get_resource()
	return {
		"status": _status,
		"progress": _progress,
		"resource": delivered_resource,
		"has_resource": delivered_resource != null,
		"error": _error_message,
		"request_error": _request_error,
		"path": _path,
		"type_hint": _type_hint,
		"consumer_id": _consumer_id,
		"exclusive": _exclusive,
		"require_idle": _require_idle,
		"cancel_reason": _cancel_reason,
		"released": _released,
	}


# --- 框架内部方法 ---

## 绑定 Lease 与 Broker 请求身份。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param broker: 创建当前 Lease 的 Broker。
## [br]
## @param request_key: Broker 内部请求键。
## [br]
## @param path: 规范化加载路径。
## [br]
## @param type_hint: ResourceLoader 类型提示。
## [br]
## @param consumer_id: 消费者诊断标识。
## [br]
## @param exclusive: 是否使用独占 admission。
## [br]
## @param require_idle: 是否要求从 idle 状态 admission。
func broker_bind(
	broker: Object,
	request_key: String,
	path: String,
	type_hint: String,
	consumer_id: StringName,
	exclusive: bool,
	require_idle: bool
) -> void:
	_broker_ref = weakref(broker) if broker != null else null
	_request_key = request_key
	_path = path
	_type_hint = type_hint
	_consumer_id = consumer_id
	_exclusive = exclusive
	_require_idle = require_idle


## 标记请求已经 admission。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
func broker_mark_loading() -> void:
	if _released or _status == STATUS_CANCELLED:
		return
	_status = STATUS_LOADING


## 更新加载进度。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param progress: 最新加载进度。
func broker_update_progress(progress: float) -> void:
	if _released or is_terminal():
		return
	_progress = clampf(progress, 0.0, 1.0)


## 交付完成资源。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param resource: 加载完成的资源。
func broker_mark_completed(resource: Resource) -> void:
	if _released or _status == STATUS_CANCELLED:
		return
	_progress = 1.0
	_resource = resource
	_status = STATUS_COMPLETED


## 标记请求失败。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param request_error: Godot Error。
## [br]
## @param message: 稳定失败说明。
func broker_mark_failed(request_error: Error, message: String) -> void:
	if _released or _status == STATUS_CANCELLED:
		return
	_request_error = request_error
	_error_message = message
	_resource = null
	_status = STATUS_FAILED


## 标记当前消费者取消。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param reason: 取消原因。
func broker_mark_cancelled(reason: StringName) -> void:
	if _released or is_terminal():
		return
	_cancel_reason = reason
	_error_message = String(reason)
	_resource = null
	_status = STATUS_CANCELLED


## 获取 Broker 内部请求键。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @return 请求键。
func broker_get_request_key() -> String:
	return _request_key


# --- 私有/辅助方法 ---

func _get_broker() -> Object:
	if _broker_ref == null:
		return null
	var value: Variant = _broker_ref.get_ref()
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		var broker: Object = value
		return broker
	return null


func _release_local_reference() -> void:
	_resource = null
	_broker_ref = null
	_released = true
