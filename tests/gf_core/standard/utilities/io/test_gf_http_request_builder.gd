## 测试通用 HTTP 请求构建、响应对象与异步批处理。
extends GutTest


# --- 测试 ---

func test_http_builder_composes_query_headers_and_json_body() -> void:
	var builder: GFHttpRequestBuilder = GFHttpRequestBuilder.new()
	builder = builder.set_url("https://example.invalid/api")
	builder = builder.set_method(GFHttpRequestBuilder.Method.POST)
	builder = builder.add_query_parameter("q", "hello world")
	builder = builder.set_header("Accept", "application/json")
	builder = builder.set_json_body({ "ok": true })

	var request: Dictionary = builder.build_request()
	var headers: PackedStringArray = GFVariantData.get_option_packed_string_array(request, "headers")

	assert_true(GFVariantData.get_option_string(request, "url").contains("q=hello%20world"), "query 参数应被 URL encode。")
	assert_true(headers.has("Accept: application/json"), "请求头应按 HTTPRequest 格式输出。")
	assert_true(headers.has("Content-Type: application/json"), "JSON body 应设置 Content-Type。")
	assert_eq(GFVariantData.get_option_int(request, "method"), GFHttpRequestBuilder.Method.POST, "请求方法应进入快照。")
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


# --- 辅助类 ---

class CompletionState:
	extends RefCounted

	var completed: bool = false


class CounterState:
	extends RefCounted

	var value: int = 0
