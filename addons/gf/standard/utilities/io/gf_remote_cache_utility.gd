## GFRemoteCacheUtility: 通用远程文本与 JSON 缓存工具。
##
## 提供 URL 请求、本地 TTL 缓存、失败时陈旧缓存回退和队列化 HTTP 访问。
## 具体内容类型、字段结构和业务策略由项目层自行决定。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRemoteCacheUtility
extends GFUtility


# --- 信号 ---

## 请求成功完成时发出。成功使用陈旧缓存回退时也会发出。
## [br]
## @api public
## [br]
## @param url: 请求 URL。
## [br]
## @param result: 请求结果字典。
## [br]
## @schema result: Dictionary，包含 success、url、content、data、from_cache、stale、response_code 和 error。
signal fetch_completed(url: String, result: Dictionary)

## 请求失败且没有可用缓存时发出。
## [br]
## @api public
## [br]
## @param url: 请求 URL。
## [br]
## @param result: 请求结果字典。
## [br]
## @schema result: Dictionary，包含 success、url、content、data、from_cache、stale、response_code 和 error。
signal fetch_failed(url: String, result: Dictionary)


# --- 常量 ---

## cache_dir_name 无效时使用的默认 user:// 子目录名。
## [br]
## @api private
## [br]
const _DEFAULT_CACHE_DIR_NAME: String = "gf_remote_cache"

## 远程响应与缓存内容的默认字节上限（16 MiB）。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_RESPONSE_BYTES: int = 16 * 1024 * 1024


# --- 公共变量 ---

## user:// 下的缓存子目录名。
## [br]
## @api public
## [br]
## @since 3.17.0
var cache_dir_name: String = _DEFAULT_CACHE_DIR_NAME:
	set(value):
		cache_dir_name = _sanitize_cache_dir_name(value)

## 默认缓存有效期，单位秒。单次请求可覆盖。
## [br]
## @api public
var default_ttl_seconds: int = 86400

## HTTP 请求超时时间，单位秒。
## [br]
## @api public
var timeout_seconds: float = 20.0

## 最大缓存条目数，超过后会按修改时间清理最旧条目。
## [br]
## @api public
var max_cache_entries: int = 128

## 最大等待队列长度。小于等于 0 表示不限制。
## [br]
## @api public
var max_pending_requests: int = 64

## 单个远程响应及缓存条目的最大 UTF-8 字节数。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_response_bytes: int = _DEFAULT_MAX_RESPONSE_BYTES:
	set(value):
		max_response_bytes = maxi(value, 1)

## 自定义缓存 key 构造器。签名为 `func(url: String, headers: PackedStringArray, format: StringName) -> String`。
## [br]
## @api public
var cache_key_builder: Callable = Callable()


# --- 私有变量 ---

## 按加入顺序等待处理的请求数据。
## [br]
## @api private
## [br]
var _pending_requests: Array[Dictionary] = []

## 当前唯一正在处理的请求数据；为空字典时没有活动请求。
## [br]
## @api private
## [br]
var _active_request: Dictionary = {}

## 执行活动请求的 HTTPRequest 节点；不存在或已释放时为 null。
## [br]
## @api private
## [br]
var _http_request: HTTPRequest = null


# --- GF 生命周期方法 ---

## 初始化远程缓存目录并启用暂停无关处理。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	_ensure_cache_dir()


## 取消等待请求、释放 HTTPRequest 并清理运行时状态。
## [br]
## @api public
func dispose() -> void:
	_pending_requests.clear()
	_active_request.clear()
	if is_instance_valid(_http_request):
		_http_request.cancel_request()
		_http_request.queue_free()
	_http_request = null


# --- 公共方法 ---

## 获取远程文本。callback 签名为 `func(result: Dictionary) -> void`。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param ttl_seconds: 缓存有效期（秒）。
## [br]
## @param force_refresh: 为 true 时忽略现有缓存并重新请求。
## [br]
## @param headers: HTTP 请求头数组。
func fetch_text(
	url: String,
	callback: Callable = Callable(),
	ttl_seconds: int = -1,
	force_refresh: bool = false,
	headers: PackedStringArray = PackedStringArray()
) -> void:
	_queue_fetch(url, callback, ttl_seconds, force_refresh, headers, &"text")


## 获取远程 JSON。成功时 result["data"] 为解析结果。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param callback: 操作完成或事件触发时执行的回调。
## [br]
## @param ttl_seconds: 缓存有效期（秒）。
## [br]
## @param force_refresh: 为 true 时忽略现有缓存并重新请求。
## [br]
## @param headers: HTTP 请求头数组。
func fetch_json(
	url: String,
	callback: Callable = Callable(),
	ttl_seconds: int = -1,
	force_refresh: bool = false,
	headers: PackedStringArray = PackedStringArray()
) -> void:
	_queue_fetch(url, callback, ttl_seconds, force_refresh, headers, &"json")


## 判断 URL 当前是否存在有效缓存。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param ttl_seconds: 缓存有效期（秒）。
## [br]
## @param headers: HTTP 请求头。
## [br]
## @param format: 缓存格式标识。
## [br]
## @return 存在有效缓存时返回 true。
func has_valid_cache(
	url: String,
	ttl_seconds: int = -1,
	headers: PackedStringArray = PackedStringArray(),
	format: StringName = &"text"
) -> bool:
	if url.is_empty():
		return false

	var path: String = _get_cache_path(_build_cache_key(url, headers, format))
	if not FileAccess.file_exists(path):
		return false

	var ttl: int = _resolve_ttl(ttl_seconds)
	if ttl <= 0:
		return false

	var modified_time: int = FileAccess.get_modified_time(path)
	var now: int = int(Time.get_unix_time_from_system())
	return now - modified_time <= ttl


## 读取有效文本缓存；不存在或过期时返回空字符串。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param ttl_seconds: 缓存有效期（秒）。
## [br]
## @param headers: HTTP 请求头。
## [br]
## @return 有效缓存文本；不存在或过期时返回空字符串。
func get_cached_text(
	url: String,
	ttl_seconds: int = -1,
	headers: PackedStringArray = PackedStringArray()
) -> String:
	if not has_valid_cache(url, ttl_seconds, headers, &"text"):
		return ""
	return _read_cache_text(_build_cache_key(url, headers, &"text"))


## 移除指定 URL 的缓存。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param headers: HTTP 请求头。
## [br]
## @param format: 缓存格式标识。
## [br]
## @return Godot 错误码。
func remove_cache(
	url: String,
	headers: PackedStringArray = PackedStringArray(),
	format: StringName = &"text"
) -> Error:
	var path: String = _get_cache_path(_build_cache_key(url, headers, format))
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


## 取消匹配 URL、headers 与 format 的等待或进行中请求，返回取消数量。
## [br]
## @api public
## [br]
## @param url: 远程资源 URL。
## [br]
## @param headers: HTTP 请求头。
## [br]
## @param format: 缓存格式标识。
## [br]
## @return 已取消的回调数量。
func cancel(
	url: String,
	headers: PackedStringArray = PackedStringArray(),
	format: StringName = &"text"
) -> int:
	if url.is_empty():
		return 0

	return _cancel_by_cache_key(_build_cache_key(url, headers, format))


## 取消所有等待或进行中请求，返回取消数量。
## [br]
## @api public
## [br]
## @return 已取消的回调数量。
func cancel_all() -> int:
	var cancelled: int = _pending_requests.size()
	_pending_requests.clear()
	if not _active_request.is_empty():
		cancelled += _get_request_callbacks(_active_request).size()
		_cancel_http_request()
		_active_request.clear()
	_process_next_request()
	return cancelled


## 清空当前缓存目录。
## [br]
## @api public
func clear_cache() -> void:
	var dir_path: String = _get_cache_dir_path()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		return

	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var path: String = "%s/%s" % [dir_path, file_name]
			var _remove_error: Error = DirAccess.remove_absolute(path)
		file_name = dir.get_next()
	dir.list_dir_end()


## 获取远程缓存工具诊断快照。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 诊断快照字典。
## [br]
## @schema return: Dictionary，包含缓存设置、响应预算、pending_count、active_url、active_cache_key 和 has_active_request。
func get_debug_snapshot() -> Dictionary:
	return {
		"cache_dir_name": cache_dir_name,
		"cache_dir_path": _get_cache_dir_path(),
		"default_ttl_seconds": default_ttl_seconds,
		"timeout_seconds": timeout_seconds,
		"max_cache_entries": max_cache_entries,
		"max_pending_requests": max_pending_requests,
		"max_response_bytes": max_response_bytes,
		"pending_count": _pending_requests.size(),
		"active_url": GFVariantData.get_option_string(_active_request, "url"),
		"active_cache_key": GFVariantData.get_option_string(_active_request, "cache_key"),
		"has_active_request": not _active_request.is_empty(),
	}


# --- 可重写钩子 / 虚方法 ---

## 启动底层 HTTP 请求。
## [br]
## @api protected
## [br]
## @param request_data: 请求数据。
## [br]
## @return Godot 错误码。
## [br]
## @schema request_data: Dictionary，包含 url、headers、ttl_seconds、format、cache_key 和 callbacks。
func _start_http_request(request_data: Dictionary) -> Error:
	var request: HTTPRequest = _ensure_http_request()
	if request == null:
		return ERR_UNAVAILABLE

	request.timeout = timeout_seconds
	request.body_size_limit = max_response_bytes
	return request.request(
		GFVariantData.get_option_string(request_data, "url"),
		GFVariantData.get_option_packed_string_array(request_data, "headers")
	)


## 完成当前活动请求，并写入缓存、回退陈旧缓存或分发失败结果。
## [br]
## @api protected
## [br]
## @param success: 底层请求是否成功。
## [br]
## @param response_code: HTTP 响应码。
## [br]
## @param content: 响应文本内容。
## [br]
## @param error: 失败原因。
func _complete_active_request(
	success: bool,
	response_code: int,
	content: String,
	error: String
) -> void:
	if _active_request.is_empty():
		return

	var request_data: Dictionary = _active_request.duplicate(true)
	_active_request.clear()

	var url: String = GFVariantData.get_option_string(request_data, "url")
	var format: StringName = GFVariantData.get_option_string_name(request_data, "format", &"text")
	var callbacks: Array[Callable] = _get_request_callbacks(request_data)
	var cache_key: String = GFVariantData.get_option_string(request_data, "cache_key")
	var result: Dictionary
	if success and content.to_utf8_buffer().size() > max_response_bytes:
		success = false
		content = ""
		error = _get_response_budget_error()

	if success:
		result = _build_success(url, content, false, false, response_code, format)
		if GFVariantData.get_option_bool(result, "success"):
			var _cache_write_error: Error = _write_cache_text(cache_key, content)
		elif _has_cache_file(cache_key):
			var parse_error: String = GFVariantData.get_option_string(result, "error")
			result = _build_success(url, _read_cache_text(cache_key), true, true, response_code, format)
			result["error"] = parse_error
	else:
		result = _build_failure(url, response_code, error)
		if _has_cache_file(cache_key):
			result = _build_success(url, _read_cache_text(cache_key), true, true, response_code, format)
			result["error"] = error

	_finish_callbacks(callbacks, result)
	_process_next_request()


# --- 私有/辅助方法 ---

## 检查缓存、合并相同 key 的回调，并在队列容量允许时登记远程请求。
## [br]
## @api private
## [br]
func _queue_fetch(
	url: String,
	callback: Callable,
	ttl_seconds: int,
	force_refresh: bool,
	headers: PackedStringArray,
	format: StringName
) -> void:
	if url.is_empty():
		_finish_immediate(callback, _build_failure(url, 0, "URL is empty"))
		return

	var ttl: int = _resolve_ttl(ttl_seconds)
	var cache_key: String = _build_cache_key(url, headers, format)
	if not force_refresh and _has_valid_cache_key(cache_key, ttl):
		var cached_result: Dictionary = _build_success(url, _read_cache_text(cache_key), true, false, 200, format)
		_finish_immediate(callback, cached_result)
		return

	if _append_callback_to_existing_request(cache_key, callback):
		return

	if max_pending_requests > 0 and _pending_requests.size() >= max_pending_requests:
		_finish_immediate(callback, _build_failure(url, 0, "Pending request limit exceeded"))
		return

	var callbacks: Array[Callable] = []
	callbacks.append(callback)
	_pending_requests.append({
		"url": url,
		"callbacks": callbacks,
		"ttl_seconds": ttl,
		"headers": headers,
		"format": format,
		"cache_key": cache_key,
	})
	_process_next_request()


## 仅在没有活动请求时从等待队列取出下一项并启动处理。
## [br]
## @api private
## [br]
func _process_next_request() -> void:
	if not _active_request.is_empty() or _pending_requests.is_empty():
		return

	_active_request = _pending_requests[0]
	_pending_requests.remove_at(0)
	var error: Error = _start_http_request(_active_request)
	if error != OK:
		_complete_active_request(false, 0, "", "Request failed: %s" % error_string(error))


## 将回调并入活动或等待中的同 key 请求，找到请求时返回 true。
## [br]
## @api private
## [br]
func _append_callback_to_existing_request(cache_key: String, callback: Callable) -> bool:
	if not _active_request.is_empty() and GFVariantData.get_option_string(_active_request, "cache_key") == cache_key:
		_append_request_callback(_active_request, callback)
		return true

	for request_data: Dictionary in _pending_requests:
		if GFVariantData.get_option_string(request_data, "cache_key") == cache_key:
			_append_request_callback(request_data, callback)
			return true
	return false


## 移除指定 key 的等待项或取消活动项，并返回被丢弃的回调数量。
## [br]
## @api private
## [br]
func _cancel_by_cache_key(cache_key: String) -> int:
	var cancelled: int = 0
	var next_pending: Array[Dictionary] = []
	for request_data: Dictionary in _pending_requests:
		if GFVariantData.get_option_string(request_data, "cache_key") == cache_key:
			cancelled += _get_request_callbacks(request_data).size()
		else:
			next_pending.append(request_data)
	_pending_requests = next_pending

	if not _active_request.is_empty() and GFVariantData.get_option_string(_active_request, "cache_key") == cache_key:
		cancelled += _get_request_callbacks(_active_request).size()
		_cancel_http_request()
		_active_request.clear()
		_process_next_request()
	return cancelled


## 取消并排队释放当前 HTTPRequest 节点，然后清空节点引用。
## [br]
## @api private
## [br]
func _cancel_http_request() -> void:
	if is_instance_valid(_http_request):
		_http_request.cancel_request()
		_http_request.queue_free()
	_http_request = null


## 从请求字典中筛出 Callable 回调并返回新数组。
## [br]
## @api private
## [br]
func _get_request_callbacks(request_data: Dictionary) -> Array[Callable]:
	var result: Array[Callable] = []
	var callbacks: Variant = GFVariantData.get_option_value(request_data, "callbacks", [])
	if not callbacks is Array:
		return result

	var callback_values: Array = callbacks
	for callback_value: Variant in callback_values:
		if callback_value is Callable:
			var callback: Callable = callback_value
			result.append(callback)
	return result


## 将回调追加到请求字典的 callbacks 数组。
## [br]
## @api private
## [br]
func _append_request_callback(request_data: Dictionary, callback: Callable) -> void:
	var callbacks: Array[Callable] = _get_request_callbacks(request_data)
	callbacks.append(callback)
	request_data["callbacks"] = callbacks


## 复用有效请求节点，或在 SceneTree 根节点创建并连接完成信号。
## [br]
## @api private
## [br]
func _ensure_http_request() -> HTTPRequest:
	if is_instance_valid(_http_request):
		return _http_request

	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null

	var tree: SceneTree = main_loop
	_http_request = HTTPRequest.new()
	_http_request.name = "GFRemoteCacheHTTPRequest"
	var connect_error: Error = _http_request.request_completed.connect(_on_request_completed) as Error
	if connect_error != OK:
		_http_request.queue_free()
		_http_request = null
		return null

	tree.root.add_child(_http_request)
	return _http_request


## 将单个即时结果交给统一的回调和信号分发流程。
## [br]
## @api private
## [br]
func _finish_immediate(callback: Callable, result: Dictionary) -> void:
	var callbacks: Array[Callable] = []
	callbacks.append(callback)
	_finish_callbacks(callbacks, result)


## 依次调用有效回调，再按结果 success 发出完成或失败信号。
## [br]
## @api private
## [br]
func _finish_callbacks(callbacks: Array[Callable], result: Dictionary) -> void:
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call(result)

	var url: String = GFVariantData.get_option_string(result, "url")
	if GFVariantData.get_option_bool(result, "success"):
		fetch_completed.emit(url, result)
	else:
		fetch_failed.emit(url, result)


## 构造成功结果；format 为 json 时解析 content 并填入 data。
## [br]
## @api private
## [br]
func _build_success(
	url: String,
	content: String,
	from_cache: bool,
	stale: bool,
	response_code: int,
	format: StringName
) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"url": url,
		"content": content,
		"data": null,
		"from_cache": from_cache,
		"stale": stale,
		"response_code": response_code,
		"error": "",
	}

	if format == &"json":
		var json: JSON = JSON.new()
		var parse_error: Error = json.parse(content)
		if parse_error != OK:
			result["success"] = false
			result["error"] = "JSON parse failed: %s" % json.get_error_message()
		else:
			result["data"] = json.data

	return result


## 构造 content 为空、data 为 null 的失败结果字典。
## [br]
## @api private
## [br]
func _build_failure(url: String, response_code: int, error: String) -> Dictionary:
	return {
		"success": false,
		"url": url,
		"content": "",
		"data": null,
		"from_cache": false,
		"stale": false,
		"response_code": response_code,
		"error": error,
	}


## 使用非负的单次 TTL；负值时改用非负的默认 TTL。
## [br]
## @api private
## [br]
func _resolve_ttl(ttl_seconds: int) -> int:
	if ttl_seconds >= 0:
		return ttl_seconds
	return maxi(default_ttl_seconds, 0)


## 创建尚不存在的缓存目录，创建失败时记录警告。
## [br]
## @api private
## [br]
func _ensure_cache_dir() -> void:
	var dir_path: String = _get_cache_dir_path()
	if not DirAccess.dir_exists_absolute(dir_path):
		var error: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if error != OK:
			push_warning("[GFRemoteCacheUtility][remote_cache_utility.cache_directory_failed] Cannot create the cache directory: %s, error code: %s." % [dir_path, error])


## 返回由 cache_dir_name 拼成的 user:// 缓存目录路径。
## [br]
## @api private
## [br]
func _get_cache_dir_path() -> String:
	return "user://%s" % cache_dir_name


## 规范化目录名；空值、路径、URI 或含冒号的值回退到默认名。
## [br]
## @api private
## [br]
func _sanitize_cache_dir_name(value: String) -> String:
	var normalized: String = value.replace("\\", "/").strip_edges()
	if normalized.is_empty() or normalized == "." or normalized == "..":
		return _DEFAULT_CACHE_DIR_NAME
	if normalized.begins_with("/") or normalized.contains("://") or normalized.contains(":"):
		return _DEFAULT_CACHE_DIR_NAME
	if normalized.contains("/") or _has_parent_path_segment(normalized):
		return _DEFAULT_CACHE_DIR_NAME
	return normalized


## 检查以斜线分隔的路径片段中是否包含 ..。
## [br]
## @api private
## [br]
func _has_parent_path_segment(path: String) -> bool:
	for segment: String in path.split("/", false):
		if segment == "..":
			return true
	return false


## 优先使用非空自定义 key；否则生成默认 key。
## [br]
## @api private
## [br]
func _build_cache_key(url: String, headers: PackedStringArray, format: StringName) -> String:
	if cache_key_builder.is_valid():
		var custom_key: Variant = cache_key_builder.call(url, headers, format)
		var custom_key_text: String = GFVariantData.to_text(custom_key).strip_edges()
		if not custom_key_text.is_empty():
			return custom_key_text

	return _build_default_cache_key(url, headers, format)


## 将格式、URL 与排序后的请求头序列化为默认缓存 key。
## [br]
## @api private
## [br]
func _build_default_cache_key(url: String, headers: PackedStringArray, format: StringName) -> String:
	var sorted_headers: PackedStringArray = headers.duplicate()
	sorted_headers.sort()
	return JSON.stringify([String(format), url, sorted_headers])


## 返回缓存 key 对应的 .cache 文件路径，文件名使用 key 的 MD5 文本。
## [br]
## @api private
## [br]
func _get_cache_path(cache_key: String) -> String:
	return "%s/%s.cache" % [_get_cache_dir_path(), cache_key.md5_text()]


## 返回缓存目标旁的 .tmp 临时文件路径。
## [br]
## @api private
## [br]
func _get_cache_temp_path(cache_key: String) -> String:
	return "%s.tmp" % _get_cache_path(cache_key)


## 返回缓存目标旁的 .bak 备份文件路径。
## [br]
## @api private
## [br]
func _get_cache_backup_path(cache_key: String) -> String:
	return "%s.bak" % _get_cache_path(cache_key)


## 检查 key 对应文件在大小限制内且修改时间未超过正 TTL。
## [br]
## @api private
## [br]
func _has_valid_cache_key(cache_key: String, ttl_seconds: int) -> bool:
	if cache_key.is_empty():
		return false

	var path: String = _get_cache_path(cache_key)
	if not _has_cache_file(cache_key):
		return false

	var ttl: int = _resolve_ttl(ttl_seconds)
	if ttl <= 0:
		return false

	var modified_time: int = FileAccess.get_modified_time(path)
	var now: int = int(Time.get_unix_time_from_system())
	return now - modified_time <= ttl


## 检查缓存文件存在且文件大小不超过 max_response_bytes。
## [br]
## @api private
## [br]
func _has_cache_file(cache_key: String) -> bool:
	var path: String = _get_cache_path(cache_key)
	return FileAccess.file_exists(path) and _get_file_size(path) <= max_response_bytes


## 读取符合大小上限的缓存文本；文件无效或无法打开时返回空串。
## [br]
## @api private
## [br]
func _read_cache_text(cache_key: String) -> String:
	if not _has_cache_file(cache_key):
		return ""
	var file: FileAccess = FileAccess.open(_get_cache_path(cache_key), FileAccess.READ)
	if file == null:
		return ""

	var content: String = file.get_as_text()
	file.close()
	return content


## 检查字节上限后写入 .tmp；提交时暂存旧文件，失败会尝试回滚，成功后清理并修剪缓存。
## [br]
## @api private
## [br]
func _write_cache_text(cache_key: String, content: String) -> Error:
	if content.to_utf8_buffer().size() > max_response_bytes:
		return ERR_OUT_OF_MEMORY
	_ensure_cache_dir()
	var path: String = _get_cache_path(cache_key)
	var temp_path: String = _get_cache_temp_path(cache_key)
	var backup_path: String = _get_cache_backup_path(cache_key)

	var _temp_cleanup_error: Error = _remove_absolute_file_if_exists(temp_path)
	var _backup_cleanup_error: Error = _remove_absolute_file_if_exists(backup_path)

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[GFRemoteCacheUtility][remote_cache_utility.cache_write_failed] Cannot write cache: %s." % cache_key)
		return FileAccess.get_open_error()

	_store_string_checked(file, content)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		var _failed_temp_remove_error: Error = _remove_absolute_file_if_exists(temp_path)
		push_warning("[GFRemoteCacheUtility][remote_cache_utility.cache_write_failed] Cannot write cache: %s." % cache_key)
		return write_error

	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.rename_absolute(path, backup_path)
		if backup_error != OK:
			var _backup_failed_temp_remove_error: Error = _remove_absolute_file_if_exists(temp_path)
			push_warning("[GFRemoteCacheUtility][remote_cache_utility.cache_write_failed] Cannot write cache: %s." % cache_key)
			return backup_error

	var commit_error: Error = DirAccess.rename_absolute(temp_path, path)
	if commit_error != OK:
		if FileAccess.file_exists(backup_path):
			var _rollback_error: Error = DirAccess.rename_absolute(backup_path, path)
		var _commit_failed_temp_remove_error: Error = _remove_absolute_file_if_exists(temp_path)
		push_warning("[GFRemoteCacheUtility][remote_cache_utility.cache_write_failed] Cannot write cache: %s." % cache_key)
		return commit_error

	var _stale_backup_remove_error: Error = _remove_absolute_file_if_exists(backup_path)
	_prune_cache()
	return OK


## 保留至少一个最新缓存条目，按修改时间删除最旧项并清理临时侧文件。
## [br]
## @api private
## [br]
func _prune_cache() -> void:
	var max_entries: int = maxi(max_cache_entries, 1)
	var dir_path: String = _get_cache_dir_path()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	var entries: Array[_CacheEntry] = []
	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		return

	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".cache"):
			var path: String = "%s/%s" % [dir_path, file_name]
			var modified_time: int = FileAccess.get_modified_time(path)
			entries.append(_CacheEntry.new(path, modified_time))
		elif not dir.current_is_dir() and (file_name.ends_with(".cache.tmp") or file_name.ends_with(".cache.bak")):
			var sidecar_path: String = "%s/%s" % [dir_path, file_name]
			var _sidecar_remove_error: Error = _remove_absolute_file_if_exists(sidecar_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	if entries.size() <= max_entries:
		return

	entries.sort_custom(func(left: _CacheEntry, right: _CacheEntry) -> bool:
		return left._modified_time < right._modified_time
	)

	while entries.size() > max_entries:
		var entry: _CacheEntry = entries[0]
		entries.remove_at(0)
		var _remove_error: Error = _remove_absolute_file_if_exists(entry._path)


## 将文本交给 FileAccess.store_string；实际写入错误由调用方读取检查。
## [br]
## @api private
## [br]
func _store_string_checked(file: FileAccess, value: String) -> void:
	var store_result: Variant = file.store_string(value)
	if store_result != null:
		return


## 文件不存在时返回 OK，否则删除绝对路径并返回 Godot 错误码。
## [br]
## @api private
## [br]
func _remove_absolute_file_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


## 生成包含当前 max_response_bytes 值的响应超限错误文本。
## [br]
## @api private
## [br]
func _get_response_budget_error() -> String:
	return "Response body exceeds max_response_bytes=%d" % max_response_bytes


## 打开文件读取长度；无法打开时返回 0。
## [br]
## @api private
## [br]
func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = int(file.get_length())
	file.close()
	return size


# --- 信号处理函数 ---

## 将 HTTPRequest 的响应大小、传输结果与状态码转换为完成结果。
## [br]
## @api private
## [br]
func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		_complete_active_request(false, response_code, "", _get_response_budget_error())
		return
	var content: String = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		_complete_active_request(false, response_code, content, "HTTP request result: %d" % result)
		return

	if response_code < 200 or response_code >= 300:
		_complete_active_request(false, response_code, content, "HTTP %d: %s" % [response_code, content])
		return

	_complete_active_request(true, response_code, content, "")

# --- 内部类 ---

## 缓存修剪时承载文件路径及修改时间的排序条目。
## [br]
## @api private
## [br]
class _CacheEntry:

	# --- 私有变量 ---

	## 本次清理枚举得到的缓存文件路径，供排序后删除使用。
	## [br]
	## @api private
	var _path: String = ""

	## 枚举时读取的修改时间快照，用于优先淘汰较旧文件；删除前不会因此重新读取时间。
	## [br]
	## @api private
	var _modified_time: int = 0


	# --- Godot 生命周期方法 ---

	## 记录同一次枚举取得的路径与修改时间，使清理排序不依赖后续文件变化。
	## [br]
	## @api private
	func _init(entry_path: String, entry_modified_time: int) -> void:
		_path = entry_path
		_modified_time = entry_modified_time
