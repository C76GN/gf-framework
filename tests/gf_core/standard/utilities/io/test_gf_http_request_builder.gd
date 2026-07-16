## 测试通用 HTTP 请求构建、响应对象与异步批处理。
extends GutTest


# --- 测试 ---

func test_http_builder_composes_query_headers_and_json_body() -> void:
	var builder: GFHttpRequestBuilder = GFHttpRequestBuilder.new()
	assert_eq(
		builder.max_response_bytes,
		GFHttpRequestBuilder.DEFAULT_MAX_RESPONSE_BYTES,
		"新 builder 应继承执行传输的响应体预算。"
	)
	assert_eq(
		GFHttpRequestBuilder.DEFAULT_MAX_RESPONSE_BYTES,
		0,
		"继承传输预算必须使用稳定的 0 sentinel。"
	)
	assert_eq(
		GFHttpRequestBuilder.UNLIMITED_MAX_RESPONSE_BYTES,
		-1,
		"显式无限制必须沿用 HTTPRequest 的 -1 语义。"
	)
	builder = builder.set_url("https://example.invalid/api")
	builder = builder.set_method(GFHttpRequestBuilder.Method.POST)
	builder = builder.add_query_parameter("q", "hello world")
	builder = builder.set_header("Accept", "application/json")
	builder = builder.set_max_response_bytes(4096)
	builder = builder.set_json_body({ "ok": true })

	var request: Dictionary = builder.build_request()
	var headers: PackedStringArray = GFVariantData.get_option_packed_string_array(request, "headers")

	assert_true(GFVariantData.get_option_string(request, "url").contains("q=hello%20world"), "query 参数应被 URL encode。")
	assert_true(headers.has("Accept: application/json"), "请求头应按 HTTPRequest 格式输出。")
	assert_true(headers.has("Content-Type: application/json"), "JSON body 应设置 Content-Type。")
	assert_eq(GFVariantData.get_option_int(request, "method"), GFHttpRequestBuilder.Method.POST, "请求方法应进入快照。")
	assert_eq(GFVariantData.get_option_int(request, "max_response_bytes"), 4096, "响应体预算应进入请求快照。")
	assert_true(GFVariantData.get_option_string(request, "body").contains("\"ok\":true"), "JSON body 应序列化。")


func test_http_builder_json_body_encodes_non_finite_values() -> void:
	var builder: GFHttpRequestBuilder = GFHttpRequestBuilder.new()
	builder = builder.set_json_body({
		"value": NAN,
		"position": Vector2(1.0, 2.0),
	})
	var request: Dictionary = builder.build_request()
	var body: String = GFVariantData.get_option_string(request, "body")

	assert_true(body.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "JSON body 应使用 GF Variant JSON 编码非 JSON 原生值。")
	assert_false(body.contains("\"value\":null"), "JSON body 不应把 NaN 退化为 null。")


func test_http_builder_parses_json_body() -> void:
	var builder: GFHttpRequestBuilder = GFHttpRequestBuilder.new()
	builder = builder.set_parse_mode(GFHttpRequestBuilder.ParseMode.JSON)

	var parsed: Dictionary = builder.parse_body("{\"value\":3}".to_utf8_buffer())
	var data: Dictionary = GFVariantData.get_option_dictionary(parsed, "data")

	assert_true(GFVariantData.get_option_bool(parsed, "ok"), "合法 JSON 应解析成功。")
	assert_eq(GFVariantData.get_option_int(data, "value"), 3, "解析结果应保留 JSON 字段。")


func test_http_response_and_async_batch_complete_together() -> void:
	var response: GFHttpResponse = GFHttpResponse.new()
	response.url = "https://example.invalid/api"
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	var completed_state: CompletionState = CompletionState.new()
	var connect_error: int = batch.completed.connect(func(_results: Dictionary) -> void:
		completed_state.completed = true
	)
	assert_true(connect_error == OK, "测试应能监听批处理完成信号。")

	assert_true(batch.watch_response(response, &"main"), "批处理应能监听响应对象。")
	response.complete_success({
		"status_code": 200,
		"text": "ok",
		"data": "ok",
	})

	assert_true(completed_state.completed, "响应完成后批处理应完成。")
	assert_true(response.is_successful(), "2xx 成功响应应标记为 successful。")
	assert_eq(batch.get_completed_count(), 1, "批处理完成数量应更新。")


func test_http_response_reads_headers_case_insensitively_and_preserves_duplicates() -> void:
	var response: GFHttpResponse = GFHttpResponse.new()
	response.headers = PackedStringArray([
		"Content-Type: application/json; charset=utf-8",
		"set-cookie: a=1",
		"Set-Cookie: b=2",
		"ETag: \"v1:stable\"",
		"invalid-header",
	])

	var cookie_values: PackedStringArray = response.get_header_values("SET-cookie")
	var header_dictionary: Dictionary = response.get_headers_dictionary()
	var dictionary_cookie_values: PackedStringArray = GFVariantData.get_option_packed_string_array(
		header_dictionary,
		"set-cookie"
	)

	assert_eq(
		response.get_header("content-type"),
		"application/json; charset=utf-8",
		"单值响应头应支持大小写不敏感读取。"
	)
	assert_eq(cookie_values.size(), 2, "重复响应头应保留所有值。")
	assert_eq(cookie_values[0], "a=1", "重复响应头应保留出现顺序。")
	assert_eq(cookie_values[1], "b=2", "重复响应头应保留出现顺序。")
	assert_eq(response.get_header("etag"), "\"v1:stable\"", "响应头值中的冒号不应被截断。")
	assert_eq(response.get_header("missing", "fallback"), "fallback", "缺失响应头应返回默认值。")
	assert_false(header_dictionary.has("invalid-header"), "非法响应头行不应进入规范化字典。")
	assert_eq(dictionary_cookie_values.size(), 2, "规范化字典也应保留重复响应头。")


func test_http_response_cancel_runs_callback_once_and_ignores_late_completion() -> void:
	var response: GFHttpResponse = GFHttpResponse.new()
	var cancel_count: CounterState = CounterState.new()
	response.cancel_callback = func() -> void:
		cancel_count.value += 1

	response.cancel("user_cancelled")
	response.cancel("late_cancel")
	response.complete_success({
		"status_code": 200,
		"text": "late",
	})

	assert_eq(cancel_count.value, 1, "取消回调应只执行一次。")
	assert_eq(response.state, GFHttpResponse.State.CANCELLED, "取消后的响应状态不应被后续完成覆盖。")
	assert_eq(response.error, "user_cancelled", "取消原因应保留第一次完成状态。")


func test_async_batch_clear_disconnects_watched_response() -> void:
	var response: GFHttpResponse = GFHttpResponse.new()
	response.url = "https://example.invalid/api"
	var batch: GFAsyncBatch = GFAsyncBatch.new()
	var completed_state: CompletionState = CompletionState.new()
	var connect_error: int = batch.completed.connect(func(_results: Dictionary) -> void:
		completed_state.completed = true
	)
	assert_true(connect_error == OK, "测试应能监听批处理完成信号。")

	assert_true(batch.watch_response(response, &"main"), "批处理应能监听响应对象。")
	batch.clear()
	response.complete_success({
		"status_code": 200,
		"text": "late",
	})

	assert_false(completed_state.completed, "清空批处理后旧响应不应再完成批处理。")
	assert_eq(batch.get_count(), 0, "清空后不应保留条目。")


func test_http_client_pool_bounds_concurrency_and_reuses_workers() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 8)
	client.init()
	var first: GFHttpResponse = client.execute(_make_builder("first"))
	var second: GFHttpResponse = client.execute(_make_builder("second"))
	var third: GFHttpResponse = client.execute(_make_builder("third"))

	assert_eq(client.started_urls, ["https://example.invalid/first"], "并发上限为 1 时只应启动首个请求。")
	assert_eq(GFVariantData.get_option_int(client.get_debug_snapshot(), "pending_count"), 2, "其余请求应进入有界队列。")
	var first_worker_id: int = client.started_worker_ids[0]
	assert_eq(
		client.started_response_limits[0],
		GFHttpClientUtility.DEFAULT_MAX_RESPONSE_BYTES,
		"客户端池应把继承预算解析为自身的有界默认值。"
	)

	client.complete_next(200, "first")
	await get_tree().process_frame
	assert_true(first.is_successful(), "首个请求应按标准响应协议完成。")
	assert_eq(client.started_urls.size(), 2, "释放 worker 后应启动下一个请求。")
	assert_eq(client.started_worker_ids[1], first_worker_id, "空闲 HTTPRequest worker 应被复用。")

	second.cancel("skip_second")
	await get_tree().process_frame
	assert_eq(second.state, GFHttpResponse.State.CANCELLED, "活动请求应可取消。")
	assert_eq(client.started_urls.size(), 3, "取消活动请求后应继续泵送队列。")
	assert_eq(client.started_worker_ids[2], first_worker_id, "取消后释放的 worker 应继续复用。")

	client.complete_next(200, "third")
	await get_tree().process_frame
	assert_true(third.is_successful(), "队尾请求应最终完成。")
	assert_eq(GFVariantData.get_option_int(client.get_debug_snapshot(), "worker_count"), 1, "池不应超出并发上限创建 worker。")
	client.dispose()
	await get_tree().process_frame


func test_http_client_pool_rejects_queue_overflow_and_cancels_pending_on_dispose() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 1)
	client.init()
	var active: GFHttpResponse = client.execute(_make_builder("active"))
	var queued_response: GFHttpResponse = client.execute(_make_builder("pending"))
	var rejected: GFHttpResponse = client.execute(_make_builder("rejected"))

	assert_eq(rejected.state, GFHttpResponse.State.FAILED, "超过队列预算的请求应立即失败。")
	assert_eq(rejected.error, "queue_full", "队列溢出应返回稳定错误码。")

	client.dispose()
	assert_eq(active.state, GFHttpResponse.State.CANCELLED, "dispose 应取消活动请求。")
	assert_eq(queued_response.state, GFHttpResponse.State.CANCELLED, "dispose 应取消排队请求。")
	assert_eq(active.error, "client_disposed", "活动请求应报告统一释放原因。")
	assert_eq(queued_response.error, "client_disposed", "排队请求应报告统一释放原因。")
	await get_tree().process_frame


func test_http_client_pool_snapshots_queued_builder_state() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 2)
	client.init()
	var first: GFHttpResponse = client.execute(_make_builder("first"))
	var queued_builder: GFHttpRequestBuilder = _make_builder("original")
	var _queued_limit_result: GFHttpRequestBuilder = queued_builder.set_max_response_bytes(2048)
	var queued: GFHttpResponse = client.execute(queued_builder)
	var _queued_url_result: GFHttpRequestBuilder = queued_builder.set_url("https://example.invalid/mutated")
	var _mutated_limit_result: GFHttpRequestBuilder = queued_builder.set_max_response_bytes(1)

	client.complete_next(200, "first")
	await get_tree().process_frame
	assert_true(first.is_successful(), "首个请求应正常完成。")
	assert_eq(client.started_urls[1], "https://example.invalid/original", "排队请求必须使用提交时快照。")
	assert_eq(client.started_response_limits[1], 2048, "排队请求的响应体预算也必须使用提交时快照。")
	client.complete_next(200, "queued")
	assert_true(queued.is_successful(), "快照请求应正常完成。")
	client.dispose()
	await get_tree().process_frame


func test_http_client_pool_allows_explicit_unlimited_response_budget() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 1)
	client.init()
	var builder: GFHttpRequestBuilder = _make_builder("unlimited")
	var _unlimited_result: GFHttpRequestBuilder = builder.set_max_response_bytes(
		GFHttpRequestBuilder.UNLIMITED_MAX_RESPONSE_BYTES
	)
	var response: GFHttpResponse = client.execute(builder)

	assert_eq(
		client.started_response_limits[0],
		GFHttpRequestBuilder.UNLIMITED_MAX_RESPONSE_BYTES,
		"项目显式选择无限制时客户端池不应覆盖请求预算。"
	)
	client.complete_next(200, "ok")
	assert_true(response.is_successful(), "显式无限制请求应正常完成。")
	client.dispose()
	await get_tree().process_frame


func test_http_client_pool_fails_active_request_when_explicit_parent_exits_tree() -> void:
	var request_parent: Node = Node.new()
	add_child(request_parent)
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 1, request_parent)
	client.init()
	var response: GFHttpResponse = client.execute(_make_builder("active"))

	remove_child(request_parent)
	await get_tree().process_frame

	assert_eq(response.state, GFHttpResponse.State.FAILED, "worker 随显式父节点退出树时响应必须终结。")
	assert_eq(response.error, "request_worker_lost", "父节点丢失应返回稳定错误码。")
	assert_eq(GFVariantData.get_option_int(client.get_debug_snapshot(), "active_count"), 0, "丢失 worker 后不应保留活动请求。")
	client.dispose()
	request_parent.queue_free()
	await get_tree().process_frame


func test_http_client_pool_reports_response_body_limit() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(1, 1)
	client.init()
	var response: GFHttpResponse = client.execute(_make_builder("oversized"))

	client.complete_next(200, "", HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED)

	assert_eq(response.state, GFHttpResponse.State.FAILED, "响应超过预算时必须失败。")
	assert_eq(response.error, "response_body_too_large", "响应体预算失败应返回稳定错误码。")
	assert_eq(response.result_code, HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, "响应应保留 Godot 原始结果码。")
	client.dispose()
	await get_tree().process_frame


func test_http_client_pool_dispose_releases_every_worker() -> void:
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(3, 0)
	client.init()
	var first: GFHttpResponse = client.execute(_make_builder("first"))
	var second: GFHttpResponse = client.execute(_make_builder("second"))
	var third: GFHttpResponse = client.execute(_make_builder("third"))
	var responses: Array[GFHttpResponse] = [first, second, third]
	var workers: Array[HTTPRequest] = []
	for worker: HTTPRequest in client.started_workers:
		workers.append(worker)

	client.dispose()

	assert_eq(workers.size(), 3, "并发请求应创建三个独立 worker。")
	for worker: HTTPRequest in workers:
		assert_null(worker.get_parent(), "dispose 必须同步移除每个 worker，不能在回调修改数组时跳项。")
	for response: GFHttpResponse in responses:
		assert_eq(response.state, GFHttpResponse.State.CANCELLED, "dispose 必须终结每个活动响应。")
	await get_tree().process_frame
	for worker: HTTPRequest in workers:
		assert_false(is_instance_valid(worker), "所有已摘除 worker 都应完成释放。")


func test_http_client_pool_reconfigure_retires_excess_and_stale_parent_workers() -> void:
	var first_parent: Node = Node.new()
	var second_parent: Node = Node.new()
	add_child(first_parent)
	add_child(second_parent)
	var client: ManualHttpClientUtility = ManualHttpClientUtility.new()
	client.configure(2, 2, first_parent)
	client.init()
	var first: GFHttpResponse = client.execute(_make_builder("first"))
	var second: GFHttpResponse = client.execute(_make_builder("second"))
	client.complete_next(200, "first")
	client.complete_next(200, "second")
	assert_true(first.is_successful() and second.is_successful(), "准备空闲池的请求应成功。")
	assert_eq(GFVariantData.get_option_int(client.get_debug_snapshot(), "worker_count"), 2)

	client.configure(1, 2, second_parent)
	await get_tree().process_frame
	assert_eq(
		GFVariantData.get_option_int(client.get_debug_snapshot(), "worker_count"),
		0,
		"切换父节点后旧父级的空闲 worker 都应退休。"
	)
	var replacement: GFHttpResponse = client.execute(_make_builder("replacement"))
	var replacement_worker: HTTPRequest = client.started_workers.back()
	assert_eq(replacement_worker.get_parent(), second_parent, "新 worker 应挂到最新父节点。")
	client.complete_next(200, "replacement")
	assert_true(replacement.is_successful(), "重新配置后的请求应正常完成。")
	assert_eq(GFVariantData.get_option_int(client.get_debug_snapshot(), "worker_count"), 1)

	client.dispose()
	first_parent.queue_free()
	second_parent.queue_free()
	await get_tree().process_frame


# --- 辅助类 ---

class CompletionState:
	extends RefCounted

	var completed: bool = false


class CounterState:
	extends RefCounted

	var value: int = 0


class ManualHttpClientUtility extends GFHttpClientUtility:
	var started_urls: Array[String] = []
	var started_worker_ids: Array[int] = []
	var started_response_limits: Array[int] = []
	var started_workers: Array[HTTPRequest] = []
	var _manual_requests: Array[Dictionary] = []

	func _start_request(
		worker: HTTPRequest,
		builder: GFHttpRequestBuilder,
		response: GFHttpResponse
	) -> Error:
		started_urls.append(builder.build_url())
		started_worker_ids.append(worker.get_instance_id())
		started_response_limits.append(builder.max_response_bytes)
		started_workers.append(worker)
		_manual_requests.append({
			"worker": worker,
			"builder": builder,
			"response": response,
		})
		return OK

	func complete_next(
		status_code: int,
		text: String,
		result_code: int = HTTPRequest.RESULT_SUCCESS
	) -> void:
		while not _manual_requests.is_empty():
			var request: Dictionary = _manual_requests.pop_front()
			var response: GFHttpResponse = _request_response(request)
			if response == null or response.is_finished():
				continue
			_complete_request(
				_request_worker(request),
				_request_builder(request),
				response,
				result_code,
				status_code,
				PackedStringArray(),
				text.to_utf8_buffer()
			)
			return

	func _request_worker(request: Dictionary) -> HTTPRequest:
		var value: Variant = request.get("worker")
		return value if value is HTTPRequest else null

	func _request_builder(request: Dictionary) -> GFHttpRequestBuilder:
		var value: Variant = request.get("builder")
		return value if value is GFHttpRequestBuilder else null

	func _request_response(request: Dictionary) -> GFHttpResponse:
		var value: Variant = request.get("response")
		return value if value is GFHttpResponse else null


func _make_builder(path_segment: String) -> GFHttpRequestBuilder:
	var builder: GFHttpRequestBuilder = GFHttpRequestBuilder.new()
	return builder.set_url("https://example.invalid/%s" % path_segment)
