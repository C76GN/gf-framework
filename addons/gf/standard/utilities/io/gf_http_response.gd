## GFHttpResponse: 通用 HTTP 请求结果。
##
## 以对象形式表达 pending、completed、failed、cancelled 等状态，便于请求构建器、
## 批处理器和项目侧工具统一观察异步结果。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFHttpResponse
extends RefCounted


# --- 信号 ---

## 响应完成、失败或取消时发出。
## [br]
## @api public
## [br]
## @param response: 当前响应对象。
signal completed(response: GFHttpResponse)


# --- 枚举 ---

## HTTP 响应句柄状态。
## [br]
## @api public
enum State {
	## 请求仍在等待完成。
	PENDING,
	## 请求成功完成。
	COMPLETED,
	## 请求失败。
	FAILED,
	## 请求被取消。
	CANCELLED,
}


# --- 公共变量 ---

## 响应状态。
## [br]
## @api public
var state: State = State.PENDING

## 原始 URL。
## [br]
## @api public
var url: String = ""

## HTTP 状态码。
## [br]
## @api public
var status_code: int = 0

## Godot HTTPRequest 结果码。
## [br]
## @api public
var result_code: int = HTTPRequest.RESULT_SUCCESS

## 响应头。
## [br]
## @api public
var headers: PackedStringArray = PackedStringArray()

## 响应文本。
## [br]
## @api public
var text: String = ""

## 响应原始 bytes。
## [br]
## @api public
var body: PackedByteArray = PackedByteArray()

## 解析后的数据，例如 JSON 结果。
## [br]
## @api public
## [br]
## @schema data: Variant，解析后的响应载荷，例如 JSON 数据、文本数据或 null。
var data: Variant = null

## 错误说明。
## [br]
## @api public
var error: String = ""

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，从请求构建器复制的调用方元数据。
var metadata: Dictionary = {}

## 取消请求时执行的底层取消回调。
## [br]
## @api public
var cancel_callback: Callable = Callable()


# --- 公共方法 ---

## 请求是否仍在等待。
## [br]
## @api public
## [br]
## @return 仍在等待时返回 true。
func is_pending() -> bool:
	return state == State.PENDING


## 请求是否成功。
## [br]
## @api public
## [br]
## @return 请求以 2xx HTTP 状态码完成且没有错误时返回 true。
func is_successful() -> bool:
	return state == State.COMPLETED and status_code >= 200 and status_code < 300 and error.is_empty()


## 请求是否已结束。
## [br]
## @api public
## [br]
## @return 请求完成、失败或取消时返回 true。
func is_finished() -> bool:
	return state != State.PENDING


## 读取第一个匹配的响应头。
## [br]
## @api public
## [br]
## @param header_name: 响应头名称，按大小写不敏感方式匹配。
## [br]
## @param default_value: 没有匹配响应头时返回的默认值。
## [br]
## @return 响应头值；没有匹配项时返回 default_value。
func get_header(header_name: String, default_value: String = "") -> String:
	var values: PackedStringArray = get_header_values(header_name)
	if values.is_empty():
		return default_value
	return values[0]


## 读取所有匹配的响应头值。
## [br]
## @api public
## [br]
## @param header_name: 响应头名称，按大小写不敏感方式匹配。
## [br]
## @return 匹配的响应头值列表，保留原始出现顺序。
func get_header_values(header_name: String) -> PackedStringArray:
	var normalized_name: String = _normalize_header_name(header_name)
	if normalized_name.is_empty():
		return PackedStringArray()

	var result: PackedStringArray = PackedStringArray()
	for raw_header: String in headers:
		var parsed_header: Dictionary = _parse_header(raw_header)
		if parsed_header.is_empty():
			continue
		if GFVariantData.get_option_string(parsed_header, "name") != normalized_name:
			continue
		var _append_result: bool = result.append(GFVariantData.get_option_string(parsed_header, "value"))
	return result


## 生成大小写规范化的响应头字典。
## [br]
## @api public
## [br]
## @return 响应头字典。
## [br]
## @schema return: Dictionary，键为小写 header 名称，值为 PackedStringArray，重复响应头会按出现顺序保留。
func get_headers_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for raw_header: String in headers:
		var parsed_header: Dictionary = _parse_header(raw_header)
		if parsed_header.is_empty():
			continue

		var header_name: String = GFVariantData.get_option_string(parsed_header, "name")
		var values: PackedStringArray = PackedStringArray()
		if result.has(header_name):
			values = _variant_to_packed_string_array(result[header_name])
		var _append_result: bool = values.append(GFVariantData.get_option_string(parsed_header, "value"))
		result[header_name] = values
	return result


## 标记请求成功完成。
## [br]
## @api public
## [br]
## @param fields: 需要写入响应对象的字段。
## [br]
## @schema fields: Dictionary，可包含 url、status_code、result_code、headers、text、body、data 和 metadata。
func complete_success(fields: Dictionary = {}) -> void:
	if is_finished():
		return

	_apply_fields(fields)
	state = State.COMPLETED
	error = GFVariantData.get_option_string(fields, "error", error)
	cancel_callback = Callable()
	completed.emit(self)


## 标记请求失败。
## [br]
## @api public
## [br]
## @param message: 错误说明。
## [br]
## @param fields: 需要写入响应对象的字段。
## [br]
## @schema fields: Dictionary，可包含 url、status_code、result_code、headers、text、body、data 和 metadata。
func complete_failure(message: String, fields: Dictionary = {}) -> void:
	if is_finished():
		return

	_apply_fields(fields)
	state = State.FAILED
	error = message
	cancel_callback = Callable()
	completed.emit(self)


## 取消请求。
## [br]
## @api public
## [br]
## @param reason: 取消原因。
func cancel(reason: String = "cancelled") -> void:
	if is_finished():
		return

	var callback: Callable = cancel_callback
	cancel_callback = Callable()
	if callback.is_valid():
		callback.call()

	state = State.CANCELLED
	error = reason
	completed.emit(self)


## 转为普通字典。
## [br]
## @api public
## [br]
## @return 响应快照。
## [br]
## @schema return: Dictionary，包含响应状态、URL、HTTP 状态、解析数据、错误信息和 metadata。
func to_dictionary() -> Dictionary:
	return {
		"state": state,
		"state_name": State.keys()[state],
		"ok": is_successful(),
		"url": url,
		"status_code": status_code,
		"result_code": result_code,
		"headers": headers,
		"text": text,
		"body": body,
		"data": data,
		"error": error,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 仅更新字段字典中显式提供且类型可转换的响应属性。
## [br]
## @api private
## [br]
func _apply_fields(fields: Dictionary) -> void:
	if fields.has("url"):
		url = GFVariantData.get_option_string(fields, "url", url)
	if fields.has("status_code"):
		status_code = GFVariantData.get_option_int(fields, "status_code", status_code)
	if fields.has("result_code"):
		result_code = GFVariantData.get_option_int(fields, "result_code", result_code)
	if fields.has("headers"):
		headers = _variant_to_packed_string_array(GFVariantData.get_option_value(fields, "headers", headers))
	if fields.has("text"):
		text = GFVariantData.get_option_string(fields, "text", text)
	if fields.has("body"):
		body = _variant_to_packed_byte_array(GFVariantData.get_option_value(fields, "body", body))
	if fields.has("data"):
		data = GFVariantData.get_option_value(fields, "data")
	if fields.has("metadata") and fields["metadata"] is Dictionary:
		metadata = GFVariantData.to_dictionary(GFVariantData.get_option_value(fields, "metadata", metadata))


## 仅接受 PackedStringArray 响应头值，其余类型返回空数组。
## [br]
## @api private
## [br]
func _variant_to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed
	return PackedStringArray()


## 仅接受 PackedByteArray 响应体，其余类型返回空数组。
## [br]
## @api private
## [br]
func _variant_to_packed_byte_array(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		var packed: PackedByteArray = value
		return packed
	return PackedByteArray()


## 按首个冒号拆分 Header 行，规范化名称并裁剪值的首尾空白。
## [br]
## @api private
## [br]
func _parse_header(raw_header: String) -> Dictionary:
	var colon_index: int = raw_header.find(":")
	if colon_index <= 0:
		return {}

	var header_name: String = _normalize_header_name(raw_header.substr(0, colon_index))
	if header_name.is_empty():
		return {}

	return {
		"name": header_name,
		"value": raw_header.substr(colon_index + 1).strip_edges(),
	}


## 去除 Header 名称首尾空白并转成小写。
## [br]
## @api private
## [br]
func _normalize_header_name(header_name: String) -> String:
	return header_name.strip_edges().to_lower()
