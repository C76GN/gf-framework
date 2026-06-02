## GFAnalyticsUtility: 通用事件分析与批量上报工具。
##
## 负责事件排队、环境上下文采集、批量 flush 与失败重排。
## endpoint 为空时不会访问网络，可作为本地事件汇聚或测试通道使用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFAnalyticsUtility
extends GFUtility


# --- 信号 ---

## 事件进入队列时发出。
## [br]
## @api public
## [br]
## @param event_name: 事件名。
## [br]
## @param event_data: 已入队事件数据。
## [br]
## @schema event_data: Dictionary with `event`, `client_id`, `session_id`, `timestamp`, `properties`, and optional `context`.
signal event_tracked(event_name: StringName, event_data: Dictionary)

## 开始 flush 时发出。
## [br]
## @api public
## [br]
## @param batch: 本次 flush 的事件批次。
## [br]
## @schema batch: Array[Dictionary] of queued analytics events.
signal flush_started(batch: Array)

## flush 完成时发出。失败结果也会通过该信号通知。
## [br]
## @api public
## [br]
## @param result: flush 结果。
## [br]
## @schema result: Dictionary with at least `success: bool`; may include `accepted`, `error`, `dry_run`, or transport-specific fields.
signal flush_completed(result: Dictionary)

## flush 失败时额外发出。
## [br]
## @api public
## [br]
## @param result: 失败结果。
## [br]
## @schema result: Dictionary with `success: false` and an optional `error` field.
signal flush_failed(result: Dictionary)


# --- 常量 ---

const _GF_UUID = preload("res://addons/gf/standard/foundation/identity/gf_uuid.gd")


# --- 公共变量 ---

## 当前配置。
## [br]
## @api public
var config: GFAnalyticsConfig = GFAnalyticsConfig.new()

## 可选载荷构建回调。签名为 func(batch: Array) -> Dictionary。
## [br]
## @api public
var payload_builder: Callable = Callable()

## 可选自定义传输回调。签名为 func(payload: Dictionary) -> Dictionary。
## [br]
## @api public
var transport_callback: Callable = Callable()

## 可选响应解析回调。签名为 func(response_code: int, body: PackedByteArray, fallback_accepted: int) -> Dictionary。
## [br]
## @api public
var response_parser: Callable = Callable()


# --- 私有变量 ---

var _queue: Array[Dictionary] = []
var _client_id: String = ""
var _session_id: String = ""
var _elapsed_since_flush: float = 0.0
var _is_flushing: bool = false
var _http_request: HTTPRequest = null
var _pending_batch: Array = []
var _shutdown: bool = false
var _explicit_client_id: bool = false
var _shutdown_watcher: _GFAnalyticsShutdownWatcher = null
var _shutdown_watcher_attach_serial: int = 0


# --- GF 生命周期方法 ---

## 初始化事件队列、会话 ID 和关闭监听。
## [br]
## @api public
func init() -> void:
	var should_keep_explicit_client_id: bool = _explicit_client_id and not _client_id.is_empty()
	ignore_pause = true
	_queue.clear()
	_elapsed_since_flush = 0.0
	_is_flushing = false
	_shutdown = false
	if should_keep_explicit_client_id:
		if config.persist_client_id:
			_save_client_id(_client_id)
	else:
		_client_id = _load_or_create_client_id()
	_explicit_client_id = should_keep_explicit_client_id
	_session_id = _generate_id()
	_ensure_shutdown_watcher()


## 释放事件队列、HTTP 节点和关闭监听。
## [br]
## @api public
func dispose() -> void:
	_shutdown_watcher_attach_serial += 1
	shutdown(false)
	_queue.clear()
	_pending_batch.clear()
	_is_flushing = false
	if is_instance_valid(_http_request):
		_http_request.queue_free()
	_http_request = null
	if is_instance_valid(_shutdown_watcher):
		_free_shutdown_watcher(_shutdown_watcher)
	_shutdown_watcher = null


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if _shutdown or not config.enabled or config.flush_interval_seconds <= 0.0 or delta <= 0.0:
		return
	_elapsed_since_flush += delta
	if _elapsed_since_flush >= config.flush_interval_seconds:
		_elapsed_since_flush = 0.0
		flush()


# --- 公共方法 ---

## 替换分析配置。
## [br]
## @api public
## [br]
## @param analytics_config: 新配置。
func configure(analytics_config: GFAnalyticsConfig) -> void:
	config = analytics_config if analytics_config != null else GFAnalyticsConfig.new()
	config.batch_size = config.batch_size
	config.max_queue_size = config.max_queue_size
	config.flush_interval_seconds = config.flush_interval_seconds
	if not _explicit_client_id:
		_client_id = _load_or_create_client_id()


## 设置稳定客户端标识。
## [br]
## @api public
## [br]
## @param client_id: 客户端标识。
func identify(client_id: String) -> void:
	if client_id.is_empty():
		return
	_client_id = client_id
	_explicit_client_id = true
	if config.persist_client_id:
		_save_client_id(_client_id)


## 记录一个事件。
## [br]
## @api public
## [br]
## @param event_name: 事件名。
## [br]
## @param properties: 事件属性。
## [br]
## @schema properties: Dictionary[String, Variant] copied into the queued event properties.
func track(event_name: StringName, properties: Dictionary = {}) -> void:
	if _shutdown or not config.enabled or event_name == &"":
		return

	var max_queue_size: int = _get_max_queue_size()
	while _queue.size() >= max_queue_size:
		var _dropped_event: Variant = _queue.pop_front()

	var event_data: Dictionary = {
		"event": String(event_name),
		"client_id": _client_id,
		"session_id": _session_id,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"properties": properties.duplicate(true),
	}

	if config.auto_capture_context:
		var event_context: Dictionary = capture_context()
		if not config.app_version.is_empty():
			event_context["app_version"] = config.app_version
		event_data["context"] = event_context

	_queue.append(event_data)
	event_tracked.emit(event_name, event_data)

	if _queue.size() >= _get_batch_size():
		flush()


## 立即上报一批事件。
## [br]
## @api public
func flush() -> void:
	if _is_flushing or _queue.is_empty():
		return

	_is_flushing = true
	var count: int = mini(_get_batch_size(), _queue.size())
	var batch: Array = []
	for _i: int in range(count):
		batch.append(GFVariantData.as_dictionary(_queue.pop_front()))
	_pending_batch = batch.duplicate(true)
	flush_started.emit(batch)
	_send_batch(batch)


## 停止继续接收事件，并可选 flush 当前队列。
## [br]
## @api public
## [br]
## @param flush_remaining: 是否尝试 flush 剩余事件。
func shutdown(flush_remaining: bool = true) -> void:
	if _shutdown:
		return

	if flush_remaining and config.flush_on_shutdown:
		while not _queue.is_empty() and not _is_flushing:
			var queued_before_flush: int = _queue.size()
			flush()
			if _is_flushing or _queue.size() >= queued_before_flush:
				break
	_shutdown = true


## 获取当前队列长度。
## [br]
## @api public
## [br]
## @return 队列长度。
func get_queue_size() -> int:
	return _queue.size()


## 获取当前会话标识。
## [br]
## @api public
## [br]
## @return 会话标识。
func get_session_id() -> String:
	return _session_id


## 获取当前客户端标识。
## [br]
## @api public
## [br]
## @return 客户端标识。
func get_client_id() -> String:
	return _client_id


## 清空本地事件队列。
## [br]
## @api public
func clear_queue() -> void:
	_queue.clear()


## 采集通用运行环境上下文。
## [br]
## @api public
## [br]
## @return 上下文字典。
## [br]
## @schema return: Dictionary with platform, engine, engine_version, screen size, locale, and timezone fields.
func capture_context() -> Dictionary:
	var version_info: Dictionary = Engine.get_version_info()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var timezone: Dictionary = Time.get_time_zone_from_system()
	var timezone_name: String = GFVariantData.get_option_string(timezone, "name")
	if timezone_name.is_empty():
		timezone_name = str(GFVariantData.get_option_int(timezone, "bias"))
	return {
		"platform": OS.get_name(),
		"engine": "Godot",
		"engine_version": "%s.%s.%s.%s" % [
			GFVariantData.get_option_int(version_info, "major"),
			GFVariantData.get_option_int(version_info, "minor"),
			GFVariantData.get_option_int(version_info, "patch"),
			GFVariantData.get_option_string(version_info, "status"),
		],
		"screen_width": screen_size.x,
		"screen_height": screen_size.y,
		"locale": OS.get_locale_language(),
		"timezone": timezone_name,
	}


# --- 私有/辅助方法 ---

func _send_batch(batch: Array) -> void:
	if transport_callback.is_valid():
		var custom_result: Variant = transport_callback.call(_build_payload(batch))
		if custom_result is Dictionary:
			var custom_dictionary: Dictionary = custom_result
			_finish_flush(custom_dictionary, batch)
		else:
			_finish_flush({
				"success": false,
				"error": "transport_callback must return Dictionary",
			}, batch)
		return

	if config.endpoint_url.is_empty():
		_finish_flush({ "success": true, "accepted": batch.size(), "dry_run": true }, batch)
		return

	var request: HTTPRequest = _ensure_http_request()
	if request == null:
		_finish_flush({ "success": false, "error": "HTTPRequest unavailable" }, batch)
		return

	var payload: Dictionary = _build_payload(batch)
	var payload_text: String = JSON.stringify(payload)
	var error: Error = OK
	if config.compress_payload:
		error = request.request_raw(
			config.endpoint_url,
			config.build_headers(),
			HTTPClient.METHOD_POST,
			_compress_payload_text(payload_text)
		)
	else:
		error = request.request(
			config.endpoint_url,
			config.build_headers(),
			HTTPClient.METHOD_POST,
			payload_text
		)
	if error != OK:
		_finish_flush({
			"success": false,
			"error": "Request failed: %s" % error_string(error),
		}, batch)


func _get_batch_size() -> int:
	return maxi(config.batch_size, 1)


func _get_max_queue_size() -> int:
	return maxi(config.max_queue_size, 1)


func _ensure_http_request() -> HTTPRequest:
	if is_instance_valid(_http_request):
		return _http_request

	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())
	if tree == null:
		return null

	_http_request = HTTPRequest.new()
	_http_request.name = "GFAnalyticsHTTPRequest"
	var _request_completed_connected: int = _http_request.request_completed.connect(_on_request_completed)
	tree.root.add_child(_http_request)
	return _http_request


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_flush({
			"success": false,
			"error": "HTTP request result: %d" % result,
		}, _pending_batch)
		return

	if response_code < 200 or response_code >= 300:
		_finish_flush({
			"success": false,
			"error": "HTTP %d: %s" % [response_code, body.get_string_from_utf8()],
		}, _pending_batch)
		return

	var accepted: int = _pending_batch.size()
	if response_parser.is_valid():
		var parsed_result: Variant = response_parser.call(response_code, body, accepted)
		if parsed_result is Dictionary:
			var parsed_result_dictionary: Dictionary = parsed_result
			_finish_flush(parsed_result_dictionary, _pending_batch)
			return
	else:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var parsed_dictionary: Dictionary = parsed
			accepted = GFVariantData.get_option_int(parsed_dictionary, "accepted", accepted)

	_finish_flush({ "success": true, "accepted": accepted }, _pending_batch)


func _finish_flush(result: Dictionary, batch: Array) -> void:
	var success: bool = GFVariantData.get_option_bool(result, "success")
	if not success:
		for index: int in range(batch.size() - 1, -1, -1):
			_queue.push_front(GFVariantData.as_dictionary(batch[index]))
		_trim_queue_to_max_size()
		flush_failed.emit(result)

	_pending_batch.clear()
	_is_flushing = false
	flush_completed.emit(result)


func _trim_queue_to_max_size() -> void:
	var max_queue_size: int = _get_max_queue_size()
	while _queue.size() > max_queue_size:
		var _dropped_event: Variant = _queue.pop_back()


func _generate_id() -> String:
	return _GF_UUID.generate_v4()


func _build_payload(batch: Array) -> Dictionary:
	if payload_builder.is_valid():
		var payload: Variant = payload_builder.call(batch)
		if payload is Dictionary:
			var payload_dictionary: Dictionary = payload
			return payload_dictionary
	return { "events": batch }


func _compress_payload_text(payload_text: String) -> PackedByteArray:
	return payload_text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)


func _load_or_create_client_id() -> String:
	if not config.persist_client_id:
		return _generate_id()

	var loaded_id: String = _load_client_id()
	if not loaded_id.is_empty():
		return loaded_id

	var generated_id: String = _generate_id()
	_save_client_id(generated_id)
	return generated_id


func _load_client_id() -> String:
	var config_file: ConfigFile = ConfigFile.new()
	var load_error: Error = config_file.load(config.client_id_storage_path)
	if load_error != OK:
		return ""
	return GFVariantData.to_text(config_file.get_value("analytics", "client_id", ""))


func _save_client_id(client_id: String) -> void:
	if client_id.is_empty():
		return

	var config_file: ConfigFile = ConfigFile.new()
	var _load_error: Error = config_file.load(config.client_id_storage_path)
	config_file.set_value("analytics", "client_id", client_id)
	var _save_error: Error = config_file.save(config.client_id_storage_path)


func _ensure_shutdown_watcher() -> void:
	if is_instance_valid(_shutdown_watcher):
		return

	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())
	if tree == null:
		return

	_shutdown_watcher = _GFAnalyticsShutdownWatcher.new()
	_shutdown_watcher.name = "GFAnalyticsShutdownWatcher"
	_shutdown_watcher._shutdown_callback = Callable(self, "shutdown")
	_shutdown_watcher_attach_serial += 1
	call_deferred("_attach_shutdown_watcher_to_root", _shutdown_watcher, _shutdown_watcher_attach_serial)


func _attach_shutdown_watcher_to_root(watcher_variant: Variant, attach_serial: int) -> void:
	var watcher: Node = _variant_to_node(watcher_variant)
	if attach_serial != _shutdown_watcher_attach_serial or watcher != _shutdown_watcher:
		_free_shutdown_watcher(watcher)
		return

	if (not is_instance_valid(watcher)
		or watcher.is_queued_for_deletion()
		or watcher.is_inside_tree()
	):
		return

	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())
	if tree == null:
		_shutdown_watcher = null
		_free_shutdown_watcher(watcher)
		return

	tree.root.add_child(watcher)


func _free_shutdown_watcher(watcher: Node) -> void:
	if not is_instance_valid(watcher) or watcher.is_queued_for_deletion():
		return
	if watcher.is_inside_tree() and watcher.get_parent() != null:
		watcher.get_parent().remove_child(watcher)
	watcher.free()


func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _variant_to_scene_tree(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null


# --- 内部类 ---

class _GFAnalyticsShutdownWatcher extends Node:
	var _shutdown_callback: Callable = Callable()

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode


	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST and _shutdown_callback.is_valid():
			var _shutdown_result: Variant = _shutdown_callback.call(true)
