# GFThreadedResourceLoadAdapter: ResourceLoader threaded API 内部适配层。
#
# 运行时资源、后台工作和场景加载都通过这里访问 Godot threaded ResourceLoader，
# 避免各模块各自维护状态映射、进度读取和结果收窄。
extends RefCounted


# --- 常量 ---

## 线程加载仍在进行。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_IN_PROGRESS: StringName = &"in_progress"

## 线程加载已完成。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_LOADED: StringName = &"loaded"

## 线程加载失败。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_FAILED: StringName = &"failed"

## 线程加载目标无效。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
const STATUS_INVALID: StringName = &"invalid"


# --- 公共方法 ---

## 发起线程资源加载请求。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选资源类型提示。
## [br]
## @return Godot Error。
static func request(path: String, type_hint: String = "") -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if type_hint.is_empty():
		return ResourceLoader.load_threaded_request(path)
	return ResourceLoader.load_threaded_request(path, type_hint)


## 读取线程资源加载状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @param progress: Godot threaded loader 进度输出数组。
## [br]
## @schema progress: Array，Godot `ResourceLoader.load_threaded_get_status()` 使用的单元素进度输出数组。
## [br]
## @return Godot threaded loader 状态。
static func get_status_with_progress(path: String, progress: Array) -> ResourceLoader.ThreadLoadStatus:
	return _to_thread_load_status(ResourceLoader.load_threaded_get_status(path, progress))


## 取走线程资源加载结果。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @return 加载出的资源；结果不是 Resource 时返回 null。
static func take_resource(path: String) -> Resource:
	return _variant_to_resource(ResourceLoader.load_threaded_get(path))


## 轮询线程资源加载，并在 loaded 状态取出资源。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @param path: 资源路径。
## [br]
## @param previous_progress: 没有新进度时沿用的旧进度。
## [br]
## @return 结构化轮询结果。
## [br]
## @schema return: Dictionary，包含 status、thread_status、progress、resource、has_resource 和 error。
static func poll(path: String, previous_progress: float = 0.0) -> Dictionary:
	var progress_values: Array = []
	var thread_status: ResourceLoader.ThreadLoadStatus = get_status_with_progress(path, progress_values)
	var progress: float = _get_progress(progress_values, previous_progress, thread_status)
	var resource: Resource = null

	match thread_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return _make_poll_result(STATUS_IN_PROGRESS, thread_status, progress, null, "")

		ResourceLoader.THREAD_LOAD_LOADED:
			resource = take_resource(path)
			return _make_poll_result(STATUS_LOADED, thread_status, 1.0, resource, "")

		ResourceLoader.THREAD_LOAD_FAILED:
			return _make_poll_result(STATUS_FAILED, thread_status, progress, null, "thread_load_failed")

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return _make_poll_result(STATUS_INVALID, thread_status, progress, null, "invalid_resource")

	return _make_poll_result(STATUS_INVALID, thread_status, progress, null, "unknown_thread_status")


# --- 私有/辅助方法 ---

static func _make_poll_result(
	status: StringName,
	thread_status: ResourceLoader.ThreadLoadStatus,
	progress: float,
	resource: Resource,
	error: String
) -> Dictionary:
	return {
		"status": status,
		"thread_status": thread_status,
		"progress": clampf(progress, 0.0, 1.0),
		"resource": resource,
		"has_resource": resource != null,
		"error": error,
	}


static func _get_progress(
	progress_values: Array,
	previous_progress: float,
	thread_status: ResourceLoader.ThreadLoadStatus
) -> float:
	if thread_status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if not progress_values.is_empty():
		return GFVariantData.to_float(progress_values[0], previous_progress)
	return previous_progress


static func _variant_to_resource(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


static func _to_thread_load_status(value: Variant) -> ResourceLoader.ThreadLoadStatus:
	var status_value: int = GFVariantData.to_int(value, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	match status_value:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return ResourceLoader.THREAD_LOAD_IN_PROGRESS

		ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.THREAD_LOAD_LOADED

		ResourceLoader.THREAD_LOAD_FAILED:
			return ResourceLoader.THREAD_LOAD_FAILED

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

	return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
