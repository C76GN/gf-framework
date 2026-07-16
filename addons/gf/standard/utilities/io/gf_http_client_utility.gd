## GFHttpClientUtility: 有界并发 HTTPRequest 客户端池。
##
## 负责复制请求快照、限制并发和等待队列、复用 HTTPRequest worker，
## 并把排队、活动、取消和释放统一收敛到 GFHttpResponse。
## 不内置远端服务、鉴权、重试、分页或业务 DTO。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.1.0
class_name GFHttpClientUtility
extends GFUtility


# --- 信号 ---

## 请求进入等待队列后发出。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param response: 请求响应句柄。
signal request_queued(response: GFHttpResponse)

## 请求取得 worker 并开始执行后发出。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param response: 请求响应句柄。
signal request_started(response: GFHttpResponse)


# --- 常量 ---

## 客户端池继承请求预算时使用的默认单响应上限。
## [br]
## @api public
## [br]
## @since 8.1.0
const DEFAULT_MAX_RESPONSE_BYTES: int = 16 * 1024 * 1024


# --- 私有变量 ---

var _max_concurrent_requests: int = 4
var _max_pending_requests: int = 256
var _default_max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES
var _request_parent_ref: WeakRef = null
var _pending_requests: Array[Dictionary] = []
var _active_requests: Dictionary = {}
var _workers: Array[HTTPRequest] = []
var _idle_workers: Array[HTTPRequest] = []
var _is_active: bool = false


# --- GF 生命周期方法 ---

## 激活客户端池。重复调用不会重置正在执行的请求。
## [br]
## @api public
## [br]
## @since 8.1.0
func init() -> void:
	if _is_active:
		return
	_is_active = true
	_pending_requests.clear()
	_active_requests.clear()
	_workers.clear()
	_idle_workers.clear()


## 取消所有请求并释放池中的 HTTPRequest worker。
## [br]
## @api public
## [br]
## @since 8.1.0
func dispose() -> void:
	_is_active = false

	var pending_snapshot: Array[Dictionary] = _pending_requests.duplicate()
	_pending_requests.clear()
	for entry: Dictionary in pending_snapshot:
		var response: GFHttpResponse = _get_entry_response(entry)
		_cancel_response_without_callback(response, "client_disposed")

	var active_snapshot: Array[Dictionary] = []
	for entry_value: Variant in _active_requests.values():
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			active_snapshot.append(entry)
	_active_requests.clear()
	for entry: Dictionary in active_snapshot:
		var worker: HTTPRequest = _get_entry_worker(entry)
		_disconnect_entry_completion(entry)
		if is_instance_valid(worker):
			worker.cancel_request()
		var response: GFHttpResponse = _get_entry_response(entry)
		_cancel_response_without_callback(response, "client_disposed")

	var worker_snapshot: Array[HTTPRequest] = []
	for worker: HTTPRequest in _workers:
		worker_snapshot.append(worker)
	_workers.clear()
	_idle_workers.clear()
	for worker: HTTPRequest in worker_snapshot:
		_free_worker(worker)
	_request_parent_ref = null


# --- 公共方法 ---

## 配置并发、等待队列预算和可选请求节点父级。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param max_concurrent_requests: 同时活动的最大请求数，最小为 1。
## [br]
## @param max_pending_requests: 等待 worker 的最大请求数，可为 0。
## [br]
## @param request_parent: worker 挂载父节点；为空时使用 SceneTree.root。
## [br]
## @param default_max_response_bytes: builder 选择继承传输预算时采用的上限；-1 表示无限制。
func configure(
	max_concurrent_requests: int = 4,
	max_pending_requests: int = 256,
	request_parent: Node = null,
	default_max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES
) -> void:
	_max_concurrent_requests = maxi(1, max_concurrent_requests)
	_max_pending_requests = maxi(0, max_pending_requests)
	_default_max_response_bytes = (
		GFHttpRequestBuilder.UNLIMITED_MAX_RESPONSE_BYTES
		if default_max_response_bytes < 0
		else maxi(1, default_max_response_bytes)
	)
	_request_parent_ref = weakref(request_parent) if request_parent != null else null
	_retire_idle_workers_with_stale_parent()
	_trim_idle_workers_to_limit()
	_pump_queue()


## 提交一个 HTTP 请求。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param builder: 请求构建器；客户端会立即复制其状态。
## [br]
## @return 可观察和取消的响应句柄。
func execute(builder: GFHttpRequestBuilder) -> GFHttpResponse:
	var response: GFHttpResponse = GFHttpResponse.new()
	if not _is_active:
		response.complete_failure("client_not_initialized")
		return response
	if builder == null or builder.url.strip_edges().is_empty():
		response.complete_failure("invalid_request")
		return response

	var request_snapshot: GFHttpRequestBuilder = builder.duplicate_builder()
	if request_snapshot.max_response_bytes == GFHttpRequestBuilder.DEFAULT_MAX_RESPONSE_BYTES:
		request_snapshot.max_response_bytes = _default_max_response_bytes
	response.url = request_snapshot.build_url()
	response.metadata = request_snapshot.metadata.duplicate(true)
	if _active_requests.size() >= _max_concurrent_requests and _pending_requests.size() >= _max_pending_requests:
		response.complete_failure("queue_full")
		return response

	response.cancel_callback = _cancel_response.bind(response)
	_pending_requests.append({
		"builder": request_snapshot,
		"response": response,
	})
	request_queued.emit(response)
	_pump_queue()
	return response


## 取消所有活动和排队请求，但保留 worker 供后续复用。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param reason: 写入响应句柄的取消原因。
func cancel_all(reason: String = "cancelled") -> void:
	var responses: Array[GFHttpResponse] = []
	for entry: Dictionary in _pending_requests:
		var response: GFHttpResponse = _get_entry_response(entry)
		if response != null:
			responses.append(response)
	for entry_value: Variant in _active_requests.values():
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var response: GFHttpResponse = _get_entry_response(entry)
		if response != null:
			responses.append(response)
	for response: GFHttpResponse in responses:
		response.cancel(reason)


## 获取客户端池诊断快照。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @return 池状态和容量计数。
## [br]
## @schema return: Dictionary，包含 active、max_concurrent_requests、max_pending_requests、default_max_response_bytes、active_count、pending_count、idle_worker_count 和 worker_count。
func get_debug_snapshot() -> Dictionary:
	_prune_workers()
	return {
		"active": _is_active,
		"max_concurrent_requests": _max_concurrent_requests,
		"max_pending_requests": _max_pending_requests,
		"default_max_response_bytes": _default_max_response_bytes,
		"active_count": _active_requests.size(),
		"pending_count": _pending_requests.size(),
		"idle_worker_count": _idle_workers.size(),
		"worker_count": _workers.size(),
	}


# --- 可重写钩子 / 虚方法 ---

## 使用指定 worker 启动请求。子类可替换该入口以接入可控测试传输。
## [br]
## @api protected
## [br]
## @since 8.1.0
## [br]
## @param worker: 当前请求独占的 HTTPRequest worker。
## [br]
## @param builder: 不再被调用方修改的请求快照。
## [br]
## @param response: 当前响应句柄。
## [br]
## @return Godot 请求启动错误码。
func _start_request(
	worker: HTTPRequest,
	builder: GFHttpRequestBuilder,
	response: GFHttpResponse
) -> Error:
	worker.timeout = builder.timeout_seconds
	worker.body_size_limit = builder.max_response_bytes
	var completion: Callable = func(
		result_code: int,
		status_code: int,
		response_headers: PackedStringArray,
		body: PackedByteArray
	) -> void:
		_complete_request(
			worker,
			builder,
			response,
			result_code,
			status_code,
			response_headers,
			body
		)
	var entry: Dictionary = _get_active_entry(worker)
	entry["completion"] = completion
	_active_requests[worker.get_instance_id()] = entry
	var connect_error: Error = worker.request_completed.connect(
		completion,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return connect_error

	var request: Dictionary = builder.build_request()
	return worker.request(
		GFVariantData.get_option_string(request, "url"),
		GFVariantData.get_option_packed_string_array(request, "headers"),
		_to_http_client_method(builder.method),
		GFVariantData.get_option_string(request, "body")
	)


## 完成当前 worker 对应的请求并将 worker 归还池。
## [br]
## @api protected
## [br]
## @since 8.1.0
## [br]
## @param worker: 完成请求的 worker。
## [br]
## @param builder: 请求快照。
## [br]
## @param response: 响应句柄。
## [br]
## @param result_code: Godot HTTPRequest 结果码。
## [br]
## @param status_code: HTTP 状态码。
## [br]
## @param response_headers: 原始响应头。
## [br]
## @param body: 原始响应体。
func _complete_request(
	worker: HTTPRequest,
	builder: GFHttpRequestBuilder,
	response: GFHttpResponse,
	result_code: int,
	status_code: int,
	response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var entry: Dictionary = _get_active_entry(worker)
	if entry.is_empty() or _get_entry_response(entry) != response:
		return

	_disconnect_entry_completion(entry)
	var _active_erased: bool = _active_requests.erase(worker.get_instance_id())
	_release_worker(worker)
	if response == null or response.is_finished():
		_pump_queue()
		return

	var parsed: Dictionary = builder.parse_body(body)
	var fields: Dictionary = {
		"url": response.url,
		"result_code": result_code,
		"status_code": status_code,
		"headers": response_headers,
		"body": body,
		"text": GFVariantData.get_option_string(parsed, "text", ""),
		"data": GFVariantData.get_option_value(parsed, "data"),
		"metadata": response.metadata,
	}
	if result_code == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		response.complete_failure("response_body_too_large", fields)
	elif result_code != HTTPRequest.RESULT_SUCCESS:
		response.complete_failure("request_failed", fields)
	elif status_code < 200 or status_code >= 300:
		response.complete_failure("http_status_%d" % status_code, fields)
	elif not GFVariantData.get_option_bool(parsed, "ok", false):
		response.complete_failure(GFVariantData.get_option_string(parsed, "error", "parse_failed"), fields)
	else:
		response.complete_success(fields)
	_pump_queue()


# --- 私有/辅助方法 ---

func _pump_queue() -> void:
	if not _is_active:
		return
	while not _pending_requests.is_empty() and _active_requests.size() < _max_concurrent_requests:
		var entry: Dictionary = _pending_requests.pop_front()
		var builder: GFHttpRequestBuilder = _get_entry_builder(entry)
		var response: GFHttpResponse = _get_entry_response(entry)
		if builder == null or response == null or response.is_finished():
			continue

		var worker: HTTPRequest = _acquire_worker()
		if worker == null:
			response.complete_failure("missing_request_parent")
			continue

		entry["worker"] = worker
		entry["completion"] = Callable()
		_active_requests[worker.get_instance_id()] = entry
		request_started.emit(response)
		var error: Error = _start_request(worker, builder, response)
		if error != OK:
			_fail_request_start(worker, response, error)


func _fail_request_start(worker: HTTPRequest, response: GFHttpResponse, error: Error) -> void:
	var entry: Dictionary = _get_active_entry(worker)
	_disconnect_entry_completion(entry)
	var _active_erased: bool = _active_requests.erase(worker.get_instance_id())
	_release_worker(worker)
	if response != null and not response.is_finished():
		response.complete_failure(error_string(error), {
			"result_code": error,
		})


func _cancel_response(response: GFHttpResponse) -> void:
	for index: int in range(_pending_requests.size() - 1, -1, -1):
		if _get_entry_response(_pending_requests[index]) == response:
			_pending_requests.remove_at(index)
			return

	for worker_id: int in _active_requests.keys():
		var entry: Dictionary = _get_active_entry_by_id(worker_id)
		if _get_entry_response(entry) != response:
			continue
		var worker: HTTPRequest = _get_entry_worker(entry)
		_disconnect_entry_completion(entry)
		var _active_erased: bool = _active_requests.erase(worker_id)
		if is_instance_valid(worker):
			worker.cancel_request()
		_release_worker(worker)
		call_deferred("_pump_queue")
		return


func _cancel_response_without_callback(response: GFHttpResponse, reason: String) -> void:
	if response == null or response.is_finished():
		return
	response.cancel_callback = Callable()
	response.cancel(reason)


func _acquire_worker() -> HTTPRequest:
	_prune_workers()
	_retire_idle_workers_with_stale_parent()
	_trim_idle_workers_to_limit()
	while not _idle_workers.is_empty():
		var idle_worker: HTTPRequest = _idle_workers.pop_back()
		if _worker_has_current_parent(idle_worker):
			return idle_worker
	if _workers.size() >= _max_concurrent_requests:
		return null

	var parent: Node = _get_request_parent()
	if parent == null:
		return null
	var worker: HTTPRequest = HTTPRequest.new()
	parent.add_child(worker)
	var _tree_exited_connected: Error = worker.tree_exited.connect(
		_on_worker_tree_exited.bind(worker.get_instance_id()),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	_workers.append(worker)
	return worker


func _release_worker(worker: HTTPRequest) -> void:
	if not _is_active or not is_instance_valid(worker):
		return
	if not _worker_has_current_parent(worker) or _workers.size() > _max_concurrent_requests:
		_retire_worker(worker)
		return
	if not _idle_workers.has(worker):
		_idle_workers.append(worker)
	_trim_idle_workers_to_limit()


func _retire_idle_workers_with_stale_parent() -> void:
	for index: int in range(_idle_workers.size() - 1, -1, -1):
		var worker: HTTPRequest = _idle_workers[index]
		if not _worker_has_current_parent(worker):
			_retire_worker(worker)


func _trim_idle_workers_to_limit() -> void:
	while _workers.size() > _max_concurrent_requests and not _idle_workers.is_empty():
		var worker: HTTPRequest = _idle_workers.back()
		_retire_worker(worker)


func _retire_worker(worker: HTTPRequest) -> void:
	if not is_instance_valid(worker):
		return
	_remove_worker_reference(worker.get_instance_id())
	_free_worker(worker)


func _worker_has_current_parent(worker: HTTPRequest) -> bool:
	if not is_instance_valid(worker) or worker.is_queued_for_deletion():
		return false
	var expected_parent: Node = _get_request_parent()
	return expected_parent != null and worker.get_parent() == expected_parent


func _free_worker(worker: HTTPRequest) -> void:
	if not is_instance_valid(worker):
		return
	var parent: Node = worker.get_parent()
	if parent != null and not GFAutoload.is_tree_exit_in_progress():
		parent.remove_child(worker)
	worker.queue_free()


func _prune_workers() -> void:
	for index: int in range(_workers.size() - 1, -1, -1):
		if not is_instance_valid(_workers[index]):
			_workers.remove_at(index)
	for index: int in range(_idle_workers.size() - 1, -1, -1):
		if not is_instance_valid(_idle_workers[index]):
			_idle_workers.remove_at(index)


func _get_request_parent() -> Node:
	if _request_parent_ref != null:
		var value: Variant = _request_parent_ref.get_ref()
		if value is Node:
			var request_parent: Node = value
			if is_instance_valid(request_parent) and request_parent.is_inside_tree():
				return request_parent
		return null

	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	var scene_tree: SceneTree = main_loop
	return scene_tree.root


func _disconnect_entry_completion(entry: Dictionary) -> void:
	var worker: HTTPRequest = _get_entry_worker(entry)
	var completion: Callable = _get_entry_completion(entry)
	if is_instance_valid(worker) and completion.is_valid() and worker.request_completed.is_connected(completion):
		worker.request_completed.disconnect(completion)


func _get_active_entry(worker: HTTPRequest) -> Dictionary:
	if not is_instance_valid(worker):
		return {}
	return _get_active_entry_by_id(worker.get_instance_id())


func _get_active_entry_by_id(worker_id: int) -> Dictionary:
	return GFVariantData.get_option_dictionary(_active_requests, worker_id)


func _get_entry_builder(entry: Dictionary) -> GFHttpRequestBuilder:
	var value: Variant = GFVariantData.get_option_value(entry, "builder")
	if value is GFHttpRequestBuilder:
		var builder: GFHttpRequestBuilder = value
		return builder
	return null


func _get_entry_response(entry: Dictionary) -> GFHttpResponse:
	var value: Variant = GFVariantData.get_option_value(entry, "response")
	if value is GFHttpResponse:
		var response: GFHttpResponse = value
		return response
	return null


func _get_entry_worker(entry: Dictionary) -> HTTPRequest:
	var value: Variant = GFVariantData.get_option_value(entry, "worker")
	if value is HTTPRequest:
		var worker: HTTPRequest = value
		return worker
	return null


func _get_entry_completion(entry: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(entry, "completion")
	if value is Callable:
		var completion: Callable = value
		return completion
	return Callable()


func _remove_worker_reference(worker_id: int) -> void:
	for index: int in range(_workers.size() - 1, -1, -1):
		var worker: HTTPRequest = _workers[index]
		if is_instance_valid(worker) and worker.get_instance_id() == worker_id:
			_workers.remove_at(index)
	for index: int in range(_idle_workers.size() - 1, -1, -1):
		var idle_worker: HTTPRequest = _idle_workers[index]
		if is_instance_valid(idle_worker) and idle_worker.get_instance_id() == worker_id:
			_idle_workers.remove_at(index)


static func _to_http_client_method(method: GFHttpRequestBuilder.Method) -> int:
	match method:
		GFHttpRequestBuilder.Method.GET:
			return HTTPClient.METHOD_GET
		GFHttpRequestBuilder.Method.POST:
			return HTTPClient.METHOD_POST
		GFHttpRequestBuilder.Method.PUT:
			return HTTPClient.METHOD_PUT
		GFHttpRequestBuilder.Method.PATCH:
			return HTTPClient.METHOD_PATCH
		GFHttpRequestBuilder.Method.DELETE:
			return HTTPClient.METHOD_DELETE
		GFHttpRequestBuilder.Method.HEAD:
			return HTTPClient.METHOD_HEAD
		_:
			return HTTPClient.METHOD_GET


# --- 信号处理函数 ---

func _on_worker_tree_exited(worker_id: int) -> void:
	_remove_worker_reference(worker_id)
	var entry: Dictionary = _get_active_entry_by_id(worker_id)
	if entry.is_empty():
		return

	var _active_erased: bool = _active_requests.erase(worker_id)
	var response: GFHttpResponse = _get_entry_response(entry)
	if _is_active and response != null and not response.is_finished():
		response.complete_failure("request_worker_lost")
		call_deferred("_pump_queue")
