## GFHttpRequestBuilder: 通用 HTTP 请求构建器。
##
## 负责整理 URL、query、headers、body、timeout 和响应解析策略。
## 它只封装 Godot HTTPRequest 的通用流程，不内置任何具体服务、鉴权或业务接口。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFHttpRequestBuilder
extends RefCounted


# --- 枚举 ---

## HTTP 请求方法。
## [br]
## @api public
enum Method {
	## HTTP GET。
	GET,
	## HTTP POST。
	POST,
	## HTTP PUT。
	PUT,
	## HTTP PATCH。
	PATCH,
	## HTTP DELETE。
	DELETE,
	## HTTP HEAD。
	HEAD,
}

## 响应体解析模式。
## [br]
## @api public
enum ParseMode {
	## 不解析响应体。
	NONE,
	## 按 UTF-8 文本解析。
	TEXT,
	## 按 JSON 解析。
	JSON,
}

# --- 公共变量 ---

## 请求 URL。
## [br]
## @api public
var url: String = ""

## HTTP 方法。
## [br]
## @api public
var method: Method = Method.GET

## 响应解析模式。
## [br]
## @api public
var parse_mode: ParseMode = ParseMode.TEXT

## 请求超时时间，单位秒。
## [br]
## @api public
var timeout_seconds: float = 20.0

## 调用方附加元数据，会复制到 GFHttpResponse。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，复制到 GFHttpResponse 的调用方元数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _headers: Dictionary = {}
var _query_parameters: Array[Dictionary] = []
var _body_text: String = ""


# --- 公共方法 ---

## 设置请求 URL。
## [br]
## @api public
## [br]
## @param next_url: 新 URL。
## [br]
## @return 当前构建器。
func set_url(next_url: String) -> GFHttpRequestBuilder:
	url = next_url
	return self


## 设置 HTTP 方法。
## [br]
## @api public
## [br]
## @param next_method: HTTP 方法枚举。
## [br]
## @return 当前构建器。
func set_method(next_method: Method) -> GFHttpRequestBuilder:
	method = next_method
	return self


## 设置响应解析模式。
## [br]
## @api public
## [br]
## @param next_parse_mode: 解析模式。
## [br]
## @return 当前构建器。
func set_parse_mode(next_parse_mode: ParseMode) -> GFHttpRequestBuilder:
	parse_mode = next_parse_mode
	return self


## 设置请求超时时间。
## [br]
## @api public
## [br]
## @param seconds: 超时秒数。
## [br]
## @return 当前构建器。
func set_timeout(seconds: float) -> GFHttpRequestBuilder:
	timeout_seconds = maxf(0.0, seconds)
	return self


## 设置或覆盖请求头。
## [br]
## @api public
## [br]
## @param key: 请求头名称。
## [br]
## @param value: 请求头值。
## [br]
## @return 当前构建器。
func set_header(key: String, value: String) -> GFHttpRequestBuilder:
	if key.strip_edges().is_empty():
		return self
	_headers[key.strip_edges()] = value
	return self


## 移除请求头。
## [br]
## @api public
## [br]
## @param key: 请求头名称。
## [br]
## @return 当前构建器。
func remove_header(key: String) -> GFHttpRequestBuilder:
	var _erase_result_158: Variant = _headers.erase(key.strip_edges())
	return self


## 添加 query 参数。
## [br]
## @api public
## [br]
## @param key: 参数名。
## [br]
## @param value: 参数值。
## [br]
## @return 当前构建器。
## [br]
## @schema value: Variant，URI 编码前会转换为文本的查询参数值。
func add_query_parameter(key: String, value: Variant) -> GFHttpRequestBuilder:
	if key.strip_edges().is_empty():
		return self
	_query_parameters.append({
		"key": key,
		"value": value,
	})
	return self


## 设置文本请求体。
## [br]
## @api public
## [br]
## @param text: 请求体文本。
## [br]
## @param content_type: 可选 Content-Type。
## [br]
## @return 当前构建器。
func set_text_body(text: String, content_type: String = "text/plain; charset=utf-8") -> GFHttpRequestBuilder:
	_body_text = text
	if not content_type.is_empty():
		var _set_header_result_195: Variant = set_header("Content-Type", content_type)
	return self


## 设置 JSON 请求体。
## [br]
## @api public
## [br]
## @param value: 可被 JSON.stringify() 序列化的数据。
## [br]
## @return 当前构建器。
## [br]
## @schema value: Variant，兼容 JSON.stringify 的请求体载荷。
func set_json_body(value: Variant) -> GFHttpRequestBuilder:
	_body_text = GFVariantJsonCodec.stringify_json_compatible(value, "", false, {
		"unsupported": "string",
	})
	var _set_header_result_210: Variant = set_header("Content-Type", "application/json")
	return self


## 构建最终 URL。
## [br]
## @api public
## [br]
## @return 拼接 query 后的 URL。
func build_url() -> String:
	if _query_parameters.is_empty():
		return url

	var pairs: PackedStringArray = PackedStringArray()
	for parameter: Dictionary in _query_parameters:
		var _pair_appended: bool = pairs.append("%s=%s" % [
			GFVariantData.get_option_string(parameter, "key", "").uri_encode(),
			str(GFVariantData.get_option_value(parameter, "value", "")).uri_encode(),
		])

	var separator: String = "&" if url.contains("?") else "?"
	return "%s%s%s" % [url, separator, "&".join(pairs)]


## 构建 Godot HTTPRequest 可用的请求头数组。
## [br]
## @api public
## [br]
## @return Header 数组。
func build_headers() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: String in _headers.keys():
		var _header_appended: bool = result.append("%s: %s" % [key, GFVariantData.to_text(_headers[key])])
	return result


## 构建普通请求字典，适合测试、日志或项目自定义传输层使用。
## [br]
## @api public
## [br]
## @return 请求快照。
## [br]
## @schema return: Dictionary，包含 url、method、method_name、headers、body、timeout_seconds、parse_mode、parse_mode_name 和 metadata。
func build_request() -> Dictionary:
	return {
		"url": build_url(),
		"method": method,
		"method_name": Method.keys()[method],
		"headers": build_headers(),
		"body": _body_text,
		"timeout_seconds": timeout_seconds,
		"parse_mode": parse_mode,
		"parse_mode_name": ParseMode.keys()[parse_mode],
		"metadata": metadata.duplicate(true),
	}


## 使用 HTTPRequest 执行请求。
## [br]
## @api public
## [br]
## @param parent: HTTPRequest 节点的父节点；为空时尝试挂到当前 SceneTree root。
## [br]
## @return 响应对象，可监听 completed。
func execute(parent: Node = null) -> GFHttpResponse:
	var response: GFHttpResponse = GFHttpResponse.new()
	response.url = build_url()
	response.metadata = metadata.duplicate(true)

	var host: Node = parent if parent != null else _resolve_default_parent()
	if host == null:
		response.complete_failure("missing_request_parent")
		return response

	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.timeout = timeout_seconds
	host.add_child(request_node)
	response.cancel_callback = func() -> void:
		if is_instance_valid(request_node):
			request_node.cancel_request()
			request_node.queue_free()

	var _completion_connect_error: Error = request_node.request_completed.connect(
		func(
			result_code: int,
			status_code: int,
			response_headers: PackedStringArray,
			body: PackedByteArray
		) -> void:
			_complete_response(response, request_node, result_code, status_code, response_headers, body),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	var error: Error = request_node.request(build_url(), build_headers(), _to_http_client_method(method), _body_text)
	if error != OK:
		request_node.queue_free()
		response.complete_failure(error_string(error), {
			"result_code": error,
		})
	return response


## 按当前 parse_mode 解析响应体。
## [br]
## @api public
## [br]
## @param body: 响应 bytes。
## [br]
## @return 解析结果字典。
## [br]
## @schema return: Dictionary，包含 ok、text、data 和可选 error。
func parse_body(body: PackedByteArray) -> Dictionary:
	var text: String = body.get_string_from_utf8()
	match parse_mode:
		ParseMode.NONE:
			return {
				"ok": true,
				"text": "",
				"data": null,
			}
		ParseMode.TEXT:
			return {
				"ok": true,
				"text": text,
				"data": text,
			}
		ParseMode.JSON:
			var parsed: Variant = JSON.parse_string(text)
			if parsed == null and text.strip_edges() != "null":
				return {
					"ok": false,
					"text": text,
					"data": null,
					"error": "invalid_json",
				}
			return {
				"ok": true,
				"text": text,
				"data": parsed,
			}
		_:
			return {
				"ok": false,
				"text": text,
				"data": null,
				"error": "unknown_parse_mode",
			}


# --- 私有/辅助方法 ---

func _complete_response(
	response: GFHttpResponse,
	request_node: HTTPRequest,
	result_code: int,
	status_code: int,
	response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response.is_finished():
		if is_instance_valid(request_node):
			request_node.queue_free()
		return

	if is_instance_valid(request_node):
		request_node.queue_free()

	var parsed: Dictionary = parse_body(body)
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
	if result_code != HTTPRequest.RESULT_SUCCESS:
		response.complete_failure("request_failed", fields)
		return
	if status_code < 200 or status_code >= 300:
		response.complete_failure("http_status_%d" % status_code, fields)
		return
	if not GFVariantData.get_option_bool(parsed, "ok", false):
		response.complete_failure(GFVariantData.get_option_string(parsed, "error", "parse_failed"), fields)
		return
	response.complete_success(fields)


func _resolve_default_parent() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop
	if tree == null:
		return null
	return tree.root


func _to_http_client_method(next_method: Method) -> int:
	match next_method:
		Method.GET:
			return HTTPClient.METHOD_GET
		Method.POST:
			return HTTPClient.METHOD_POST
		Method.PUT:
			return HTTPClient.METHOD_PUT
		Method.PATCH:
			return HTTPClient.METHOD_PATCH
		Method.DELETE:
			return HTTPClient.METHOD_DELETE
		Method.HEAD:
			return HTTPClient.METHOD_HEAD
		_:
			return HTTPClient.METHOD_GET
