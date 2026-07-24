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
## @since 3.17.0
## [br]
## @param event_name: 事件名。
## [br]
## @param event_data: 已入队事件数据。
## [br]
## @schema event_data: Dictionary with `event`, `client_id`, `session_id`, `timestamp`, `properties`, optional `context`, and for versioned events `event_id` plus `schema_version`.
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
## @since 3.17.0
## [br]
## @param result: flush 结果。
## [br]
## @schema result: Dictionary with `success`; may include `accepted`, `error`, `dry_run`, `dropped`, `retained`, `drop_reason`, or transport-specific fields.
signal flush_completed(result: Dictionary)

## flush 失败时额外发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param result: 失败结果。
## [br]
## @schema result: Dictionary with `success: false`; may include `error`, `dropped`, `retained`, `drop_reason`, and payload budget fields.
signal flush_failed(result: Dictionary)


# --- 常量 ---

const _GF_UUID = preload("res://addons/gf/standard/foundation/identity/gf_uuid.gd")
const _MAX_CLIENT_ID_LENGTH: int = 4096
const _MAX_SCHEMA_VERSION: int = 2_147_483_647
const _MAX_PLANNER_EVALUATIONS: int = 64
const _PLANNER_WORK_MULTIPLIER: int = 8


# --- 公共变量 ---

## 当前配置。
## [br]
## @api public
## [br]
## @since 3.17.0
var config: GFAnalyticsConfig:
	get:
		if _config == null:
			_config = GFAnalyticsConfig.new()
		return _config
	set(value):
		_config = value if value != null else GFAnalyticsConfig.new()

## 版本化事件 Schema 注册表。
##
## 注册表始终可用；赋值 null 会恢复为空注册表。Schema 只约束编码前的 properties，
## 不替代最终 JSON-safe 载荷预算或项目侧隐私、同意与业务策略。
## [br]
## @api public
## [br]
## @since unreleased
var schema_registry: GFAnalyticsSchemaRegistry:
	get:
		if _schema_registry == null:
			_schema_registry = GFAnalyticsSchemaRegistry.new()
		return _schema_registry
	set(value):
		_schema_registry = value if value != null else GFAnalyticsSchemaRegistry.new()

## 可选载荷信封构建回调。签名为 func(batch: Array) -> Dictionary。
## batch 是隔离副本；返回值中的 events 会被忽略，以保持已编码事件批次的完整性。
## flush 按最终信封字节预算从最大前缀向下有界校验时可能多次调用该回调，因此实现必须
## 无副作用且结果确定；若评估工作预算耗尽，完整队列会保留并报告 planner_budget_exceeded。
## [br]
## @api public
## [br]
## @since 3.17.0
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
var _pending_payload: Dictionary = {}
var _pending_payload_text: String = ""
var _shutdown: bool = false
var _is_draining: bool = false
var _drain_loop_active: bool = false
var _dropped_event_count: int = 0
var _explicit_client_id: bool = false
var _shutdown_watcher: _GFAnalyticsShutdownWatcher = null
var _shutdown_watcher_attach_serial: int = 0
var _config: GFAnalyticsConfig = GFAnalyticsConfig.new()
var _schema_registry: GFAnalyticsSchemaRegistry = GFAnalyticsSchemaRegistry.new()
var _is_initialized: bool = false
var _reported_invalid_storage_path: bool = false
var _flush_generation: int = 0
var _active_http_generation: int = -1
var _is_notifying_flush: bool = false
var _is_planning: bool = false
var _queue_generation: int = 0


# --- GF 生命周期方法 ---

## 初始化事件队列、会话 ID 和关闭监听。
## [br]
## @api public
func init() -> void:
	if _is_initialized:
		return
	var should_keep_explicit_client_id: bool = _explicit_client_id and not _client_id.is_empty()
	ignore_pause = true
	_queue.clear()
	_queue_generation += 1
	_elapsed_since_flush = 0.0
	_is_flushing = false
	_flush_generation += 1
	_active_http_generation = -1
	_is_notifying_flush = false
	_is_planning = false
	_shutdown = false
	_is_draining = false
	_drain_loop_active = false
	_dropped_event_count = 0
	_pending_payload.clear()
	_pending_payload_text = ""
	if should_keep_explicit_client_id:
		if _should_persist_client_id():
			_save_client_id(_client_id)
	else:
		_client_id = _load_or_create_client_id()
	_explicit_client_id = should_keep_explicit_client_id
	_session_id = _generate_id()
	_ensure_shutdown_watcher()
	_is_initialized = true


## 释放事件队列、HTTP 节点、关闭监听和项目注入的回调。
## [br]
## @api public
## [br]
## @since 3.17.0
func dispose() -> void:
	if not _is_initialized:
		_release_injected_callbacks()
		return
	_shutdown_watcher_attach_serial += 1
	_flush_generation += 1
	_active_http_generation = -1
	_shutdown = true
	_is_draining = false
	if is_instance_valid(_http_request):
		_http_request.cancel_request()
	if _is_flushing:
		var interrupted_batch: Array = _duplicate_batch(_pending_batch)
		_finish_flush({
			"success": false,
			"error": "analytics disposed while flush was in flight",
		}, interrupted_batch)
	_queue.clear()
	_queue_generation += 1
	_pending_batch.clear()
	_pending_payload.clear()
	_pending_payload_text = ""
	_is_flushing = false
	if is_instance_valid(_http_request):
		_http_request.queue_free()
	_http_request = null
	if is_instance_valid(_shutdown_watcher):
		_free_shutdown_watcher(_shutdown_watcher)
	_shutdown_watcher = null
	_is_initialized = false
	_release_injected_callbacks()


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
	_reported_invalid_storage_path = false
	config.batch_size = config.batch_size
	config.max_queue_size = config.max_queue_size
	config.flush_interval_seconds = config.flush_interval_seconds
	config.max_event_name_length = config.max_event_name_length
	config.max_property_count = config.max_property_count
	config.max_string_length = config.max_string_length
	config.max_collection_items = config.max_collection_items
	config.max_total_nodes = config.max_total_nodes
	config.max_payload_bytes = config.max_payload_bytes
	if not _explicit_client_id:
		_client_id = _load_or_create_client_id()


## 设置稳定客户端标识。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param client_id: 1..4096 字符且不含 C0/DEL 控制字符的客户端标识；非法值会被拒绝并保留原标识。
func identify(client_id: String) -> void:
	if not _is_valid_client_id(client_id):
		push_warning("[GFAnalyticsUtility] client_id must contain 1..4096 characters without C0/DEL controls.")
		return
	_client_id = client_id
	_explicit_client_id = true
	if _should_persist_client_id():
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
	var _track_result: Dictionary = _track_event(event_name, properties)


## 按精确 Schema 版本记录事件。
##
## 该入口在 JSON-safe 编码前执行有界输入校验；不会回退到其他版本，也不会自动迁移
## 旧事件。成功只表示事件已被 Analytics 接受，自动 flush 可能已同步完成或失败回灌。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event_name: 已注册的事件名。
## [br]
## @param schema_version: 已注册且位于 1..2_147_483_647 的 Schema 版本。
## [br]
## @param properties: 编码前的事件属性。
## [br]
## @return 结构化记录结果。
## [br]
## @schema properties: Dictionary[String, Variant] validated against the exact registered analytics input schema.
## [br]
## @schema return: Dictionary with ok, accepted, reason, event_name, schema_version, event_id, and validation.
func track_versioned(
	event_name: StringName,
	schema_version: int,
	properties: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"accepted": false,
		"reason": &"",
		"event_name": event_name,
		"schema_version": schema_version,
		"event_id": "",
		"validation": null,
	}
	if _shutdown:
		result["reason"] = &"analytics_shutdown"
		return result
	if not config.enabled:
		result["reason"] = &"analytics_disabled"
		return result
	if event_name == &"":
		result["reason"] = &"invalid_event_name"
		return result
	if schema_version <= 0 or schema_version > _MAX_SCHEMA_VERSION:
		result["reason"] = &"invalid_schema_version"
		return result
	if not schema_registry.has_schema(event_name, schema_version):
		result["reason"] = &"schema_not_registered"
		return result

	var validation: GFValidationReport = schema_registry.validate(
		event_name,
		schema_version,
		properties,
		{
			"subject": "%s@%d" % [String(event_name), schema_version],
			"max_depth": 16,
			"max_property_count": config.max_property_count,
			"max_string_length": config.max_string_length,
			"max_collection_items": config.max_collection_items,
			"max_total_nodes": config.max_total_nodes,
			"max_total_bytes": config.max_payload_bytes,
		}
	)
	result["validation"] = validation
	if validation == null or not validation.is_ok():
		result["reason"] = (
			&"validation_budget_exceeded"
			if _validation_has_budget_issue(validation)
			else &"properties_invalid"
		)
		return result

	var event_id: String = _GF_UUID.generate_v7()
	var track_result: Dictionary = _track_event(
		event_name,
		properties,
		{
			"event_id": event_id,
			"schema_version": schema_version,
		}
	)
	if not GFVariantData.get_option_bool(track_result, "ok"):
		result["reason"] = GFVariantData.get_option_string_name(track_result, "reason")
		return result

	result["ok"] = true
	result["accepted"] = true
	result["reason"] = &"tracked"
	result["event_id"] = event_id
	return result


## 立即上报最终信封字节预算内的最大事件前缀。
##
## Planner 不假设 payload_builder 的大小随批次单调变化，而是从最大候选前缀向下
## 有界校验。评估次数或累计编码工作达到预算时，会通过 flush_failed 和
## flush_completed 返回 retained=true、dropped=false、drop_reason=planner_budget_exceeded，
## 并保持完整队列；调用方应降低 batch_size 或简化 payload_builder 后再重试。只有已经
## 证明单个事件无法放入最终信封时，才会以 dropped=true 明确丢弃。
## [br]
## @api public
## [br]
## @since 3.17.0
func flush() -> void:
	_flush_next(false)


## 停止继续接收事件，并可选进入 draining 状态直到队列完成或某一批明确失败。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param flush_remaining: 是否尝试 flush 剩余事件。
func shutdown(flush_remaining: bool = true) -> void:
	if _shutdown:
		return
	_shutdown = true
	_is_draining = flush_remaining and config.flush_on_shutdown and (
		_is_flushing or not _queue.is_empty()
	)
	if not _is_draining:
		return
	_drain_remaining()


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
	_queue_generation += 1


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

func _track_event(
	event_name: StringName,
	properties: Dictionary,
	trusted_fields: Dictionary = {}
) -> Dictionary:
	if _shutdown:
		return { "ok": false, "reason": &"analytics_shutdown" }
	if not config.enabled:
		return { "ok": false, "reason": &"analytics_disabled" }
	if event_name == &"":
		return { "ok": false, "reason": &"invalid_event_name" }
	var event_name_text: String = String(event_name)
	if event_name_text.length() > config.max_event_name_length:
		push_warning("[GFAnalyticsUtility] event_name exceeds max_event_name_length.")
		return { "ok": false, "reason": &"invalid_event_name" }
	if _contains_control_character(event_name_text):
		push_warning("[GFAnalyticsUtility] event_name contains control characters.")
		return { "ok": false, "reason": &"invalid_event_name" }
	if properties.size() > config.max_property_count:
		push_warning("[GFAnalyticsUtility] properties exceed max_property_count.")
		return { "ok": false, "reason": &"validation_budget_exceeded" }

	var encoded_properties: Dictionary = _encode_event_properties(properties)
	var trusted_event_id: String = GFVariantData.get_option_string(trusted_fields, "event_id")
	var trusted_schema_version: int = GFVariantData.get_option_int(trusted_fields, "schema_version")
	if (
		not trusted_event_id.is_empty()
		and trusted_schema_version > 0
		and _contains_report_budget_marker(encoded_properties)
	):
		return { "ok": false, "reason": &"validation_budget_exceeded" }
	var event_data: Dictionary = {
		"event": event_name_text,
		"client_id": _client_id,
		"session_id": _session_id,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"properties": encoded_properties,
	}
	if not trusted_event_id.is_empty() and trusted_schema_version > 0:
		event_data["event_id"] = trusted_event_id
		event_data["schema_version"] = trusted_schema_version

	if config.auto_capture_context:
		var event_context: Dictionary = capture_context()
		if not config.app_version.is_empty():
			event_context["app_version"] = config.app_version
		event_data["context"] = _json_safe_dictionary(event_context)
	if JSON.stringify(event_data).to_utf8_buffer().size() > config.max_payload_bytes:
		push_warning("[GFAnalyticsUtility] event exceeds max_payload_bytes after report encoding.")
		return { "ok": false, "reason": &"payload_too_large" }

	var max_queue_size: int = _get_max_queue_size()
	while _queue.size() >= max_queue_size:
		var _dropped_event: Variant = _queue.pop_front()
	_queue.append(event_data)
	_queue_generation += 1
	event_tracked.emit(event_name, event_data.duplicate(true))

	if _queue.size() >= _get_batch_size():
		flush()
	return { "ok": true, "reason": &"tracked" }


func _flush_next(allow_shutdown: bool) -> void:
	if (
		(_shutdown and not allow_shutdown)
		or _is_flushing
		or _is_notifying_flush
		or _is_planning
		or _queue.is_empty()
	):
		return
	while not _queue.is_empty() and not _is_flushing:
		if _shutdown and not allow_shutdown:
			return
		var planning_queue_generation: int = _queue_generation
		var planning_flush_generation: int = _flush_generation
		_is_planning = true
		var plan: Dictionary = _make_next_batch_plan()
		_is_planning = false
		if (
			not _is_initialized
			or planning_queue_generation != _queue_generation
			or planning_flush_generation != _flush_generation
			or (_shutdown and not allow_shutdown)
		):
			return
		if not GFVariantData.get_option_bool(plan, "success"):
			if not GFVariantData.get_option_bool(plan, "drop_event", true):
				_emit_planner_failure(plan)
				return
			var queue_size_before_drop: int = _queue.size()
			var dropped_event: Dictionary = GFVariantData.as_dictionary(_queue.pop_front()).duplicate(true)
			_queue_generation += 1
			_emit_oversized_event_drop(dropped_event, plan)
			if (
				(not _is_initialized)
				or (_shutdown and not allow_shutdown)
				or _queue.size() >= queue_size_before_drop
			):
				return
			continue
		var batch: Array = GFVariantData.get_option_array(plan, "batch")
		for _index: int in range(batch.size()):
			var _removed_event: Variant = _queue.pop_front()
		_queue_generation += 1
		_pending_batch = _duplicate_batch(batch)
		_pending_payload = GFVariantData.get_option_dictionary(plan, "payload").duplicate(true)
		_pending_payload_text = GFVariantData.get_option_string(plan, "payload_text")
		_is_flushing = true
		_flush_generation += 1
		var flush_generation: int = _flush_generation
		flush_started.emit(_duplicate_batch(batch))
		if not _is_flushing or flush_generation != _flush_generation:
			return
		_send_batch(batch)
		return
	if _queue.is_empty() and not _is_flushing:
		_is_draining = false


func _make_next_batch_plan() -> Dictionary:
	var starting_queue_generation: int = _queue_generation
	var starting_flush_generation: int = _flush_generation
	var maximum_count: int = mini(_get_batch_size(), _queue.size())
	if maximum_count <= 0:
		return {
			"success": false,
			"error": "analytics batch planner produced no candidate",
			"drop_reason": "empty_batch_plan",
			"payload_bytes": 0,
			"max_payload_bytes": config.max_payload_bytes,
		}

	var estimated_bytes: int = 13
	var candidate_count: int = 0
	for index: int in range(maximum_count):
		var event: Dictionary = GFVariantData.as_dictionary(_queue[index])
		var event_bytes: int = JSON.stringify(event).to_utf8_buffer().size()
		var separator_bytes: int = 1 if candidate_count > 0 else 0
		if (
			candidate_count > 0
			and estimated_bytes + event_bytes + separator_bytes > config.max_payload_bytes
		):
			break
		candidate_count += 1
		estimated_bytes += event_bytes + separator_bytes
		if estimated_bytes > config.max_payload_bytes:
			break

	var planner_work_bytes: int = 0
	var evaluation_count: int = 0
	var planner_work_budget: int = config.max_payload_bytes * _PLANNER_WORK_MULTIPLIER
	for prefix_count: int in range(candidate_count, 0, -1):
		if (
			evaluation_count >= _MAX_PLANNER_EVALUATIONS
			or planner_work_bytes >= planner_work_budget
		):
			return {
				"success": false,
				"drop_event": false,
				"error": "analytics batch planner work budget exhausted",
				"drop_reason": "planner_budget_exceeded",
				"payload_bytes": planner_work_bytes,
				"max_payload_bytes": config.max_payload_bytes,
			}
		var prefix_plan: Dictionary = _evaluate_batch_prefix(prefix_count)
		if (
			starting_queue_generation != _queue_generation
			or starting_flush_generation != _flush_generation
			or not _is_initialized
		):
			return prefix_plan
		evaluation_count += 1
		planner_work_bytes += maxi(
			GFVariantData.get_option_int(prefix_plan, "payload_bytes"),
			1
		)
		if GFVariantData.get_option_bool(prefix_plan, "success"):
			return prefix_plan
		if prefix_count == 1:
			prefix_plan["drop_event"] = true
			return prefix_plan
	return {
		"success": false,
		"drop_event": false,
		"error": "analytics batch planner produced no candidate",
		"drop_reason": "empty_batch_plan",
		"payload_bytes": planner_work_bytes,
		"max_payload_bytes": config.max_payload_bytes,
	}


func _evaluate_batch_prefix(count: int) -> Dictionary:
	var candidate: Array = []
	for index: int in range(mini(count, _queue.size())):
		candidate.append(GFVariantData.as_dictionary(_queue[index]).duplicate(true))
	if candidate.is_empty():
		return {
			"success": false,
			"error": "analytics batch planner produced no candidate",
			"drop_reason": "empty_batch_plan",
			"payload_bytes": 0,
			"max_payload_bytes": config.max_payload_bytes,
		}
	var payload: Dictionary = _build_payload(candidate)
	var payload_text: String = JSON.stringify(payload)
	var payload_bytes: int = payload_text.to_utf8_buffer().size()
	if payload_bytes <= config.max_payload_bytes:
		return {
			"success": true,
			"batch": _duplicate_batch(candidate),
			"payload": payload.duplicate(true),
			"payload_text": payload_text,
			"payload_bytes": payload_bytes,
		}
	return {
		"success": false,
		"drop_event": count <= 1,
		"error": "single analytics event cannot fit final envelope",
		"drop_reason": "final_envelope_too_large",
		"payload_bytes": payload_bytes,
		"max_payload_bytes": config.max_payload_bytes,
	}


func _emit_planner_failure(plan: Dictionary) -> void:
	var result: Dictionary = GFReportValueCodec.to_report_dictionary({
		"success": false,
		"error": GFVariantData.get_option_string(plan, "error"),
		"dropped": false,
		"retained": true,
		"drop_reason": GFVariantData.get_option_string(plan, "drop_reason"),
		"planner_work_bytes": GFVariantData.get_option_int(plan, "payload_bytes"),
		"max_payload_bytes": GFVariantData.get_option_int(plan, "max_payload_bytes"),
	}, _make_report_options())
	result["success"] = false
	result["dropped"] = false
	result["retained"] = true
	_is_notifying_flush = true
	flush_failed.emit(result.duplicate(true))
	flush_completed.emit(result.duplicate(true))
	_is_notifying_flush = false
	if _is_draining:
		_is_draining = false


func _emit_oversized_event_drop(event: Dictionary, plan: Dictionary) -> void:
	_dropped_event_count += 1
	var batch: Array = [event.duplicate(true)]
	var result: Dictionary = GFReportValueCodec.to_report_dictionary({
		"success": false,
		"error": GFVariantData.get_option_string(plan, "error"),
		"dropped": true,
		"dropped_count": 1,
		"total_dropped_count": _dropped_event_count,
		"drop_reason": GFVariantData.get_option_string(plan, "drop_reason"),
		"payload_bytes": GFVariantData.get_option_int(plan, "payload_bytes"),
		"max_payload_bytes": GFVariantData.get_option_int(plan, "max_payload_bytes"),
	}, _make_report_options())
	result["success"] = false
	result["dropped"] = true
	_is_notifying_flush = true
	flush_started.emit(_duplicate_batch(batch))
	flush_failed.emit(result.duplicate(true))
	flush_completed.emit(result.duplicate(true))
	_is_notifying_flush = false
	if _is_draining and _is_initialized:
		_drain_remaining()


func _drain_remaining() -> void:
	if not _is_draining or _drain_loop_active or _is_notifying_flush:
		return
	_drain_loop_active = true
	while _is_draining and not _is_flushing and not _queue.is_empty():
		var previous_queue_size: int = _queue.size()
		var previous_flush_generation: int = _flush_generation
		_flush_next(true)
		if (
			not _is_flushing
			and previous_queue_size == _queue.size()
			and previous_flush_generation == _flush_generation
		):
			_is_draining = false
			break
	if _queue.is_empty() and not _is_flushing:
		_is_draining = false
	_drain_loop_active = false


func _send_batch(batch: Array) -> void:
	if not _is_flushing:
		return
	var flush_generation: int = _flush_generation
	var payload: Dictionary = _pending_payload.duplicate(true)
	var payload_text: String = _pending_payload_text
	if payload.is_empty() and payload_text.is_empty():
		payload = _build_payload(batch)
		payload_text = JSON.stringify(payload)
	if payload_text.to_utf8_buffer().size() > config.max_payload_bytes:
		_finish_flush({
			"success": false,
			"error": "planned analytics payload exceeds max_payload_bytes",
		}, batch)
		return
	if transport_callback.is_valid():
		var custom_result: Variant = transport_callback.call(payload.duplicate(true))
		if not _is_flushing or flush_generation != _flush_generation:
			return
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
	request.body_size_limit = config.max_payload_bytes

	var error: Error = OK
	_active_http_generation = flush_generation
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
		if not _is_flushing or flush_generation != _flush_generation:
			return
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
	if (
		not _is_flushing
		or _active_http_generation < 0
		or _active_http_generation != _flush_generation
	):
		return
	var completion_generation: int = _flush_generation
	var completion_batch: Array = _duplicate_batch(_pending_batch)
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_flush({
			"success": false,
			"error": "HTTP request result: %d" % result,
		}, completion_batch)
		return

	if response_code < 200 or response_code >= 300:
		_finish_flush({
			"success": false,
			"error": "HTTP %d: %s" % [response_code, body.get_string_from_utf8()],
		}, completion_batch)
		return

	var accepted: int = completion_batch.size()
	if response_parser.is_valid():
		var parsed_result: Variant = response_parser.call(response_code, body, accepted)
		if (
			not _is_flushing
			or completion_generation != _flush_generation
			or _active_http_generation != completion_generation
		):
			return
		if parsed_result is Dictionary:
			var parsed_result_dictionary: Dictionary = parsed_result
			_finish_flush(parsed_result_dictionary, completion_batch)
			return
		_finish_flush({
			"success": false,
			"error": "response_parser must return Dictionary",
		}, completion_batch)
		return
	else:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var parsed_dictionary: Dictionary = parsed
			accepted = GFVariantData.get_option_int(parsed_dictionary, "accepted", accepted)

	_finish_flush({ "success": true, "accepted": accepted }, completion_batch)


func _finish_flush(result: Dictionary, batch: Array) -> void:
	if not _is_flushing:
		return
	var success: bool = GFVariantData.get_option_bool(result, "success")
	var accepted_count: int = 0
	if success:
		accepted_count = clampi(
			GFVariantData.get_option_int(result, "accepted", batch.size()),
			0,
			batch.size()
		)
		if not batch.is_empty() and accepted_count == 0:
			success = false
	var safe_result: Dictionary = GFReportValueCodec.to_report_dictionary(result, _make_report_options())
	safe_result["success"] = success
	if success:
		safe_result["accepted"] = accepted_count
	elif (
		GFVariantData.get_option_bool(result, "success")
		and not batch.is_empty()
		and accepted_count == 0
	):
		safe_result["error"] = "analytics transport accepted zero events"
	if not success:
		for index: int in range(batch.size() - 1, -1, -1):
			_queue.push_front(GFVariantData.as_dictionary(batch[index]).duplicate(true))
		if not batch.is_empty():
			_queue_generation += 1
		_trim_queue_to_max_size()
	else:
		if accepted_count < batch.size():
			for index: int in range(batch.size() - 1, accepted_count - 1, -1):
				_queue.push_front(GFVariantData.as_dictionary(batch[index]).duplicate(true))
			_queue_generation += 1
			_trim_queue_to_max_size()

	_pending_batch.clear()
	_pending_payload.clear()
	_pending_payload_text = ""
	_is_flushing = false
	_active_http_generation = -1
	if _is_draining:
		if not success:
			_is_draining = false

	_is_notifying_flush = true
	if not success:
		flush_failed.emit(safe_result.duplicate(true))
	flush_completed.emit(safe_result.duplicate(true))
	_is_notifying_flush = false
	if _is_draining and _is_initialized:
		_drain_remaining()


func _trim_queue_to_max_size() -> void:
	var max_queue_size: int = _get_max_queue_size()
	var trimmed: bool = false
	while _queue.size() > max_queue_size:
		var _dropped_event: Variant = _queue.pop_back()
		_dropped_event_count += 1
		trimmed = true
	if trimmed:
		_queue_generation += 1


func _release_injected_callbacks() -> void:
	payload_builder = Callable()
	transport_callback = Callable()
	response_parser = Callable()


func _validation_has_budget_issue(report: GFValidationReport) -> bool:
	if report == null:
		return false
	var budget_kinds: Dictionary = {
		&"properties_too_wide": true,
		&"property_depth_exceeded": true,
		&"property_collection_too_large": true,
		&"property_node_budget_exceeded": true,
		&"property_string_too_long": true,
		&"property_byte_budget_exceeded": true,
	}
	for issue_ref: RefCounted in report.issues:
		if not (issue_ref is GFValidationIssue):
			continue
		var issue: GFValidationIssue = issue_ref
		if budget_kinds.has(issue.kind):
			return true
	return false


func _generate_id() -> String:
	return _GF_UUID.generate_v4()


func _build_payload(batch: Array) -> Dictionary:
	if payload_builder.is_valid():
		var payload: Variant = payload_builder.call(_duplicate_batch(batch))
		if payload is Dictionary:
			var payload_dictionary: Dictionary = payload
			var payload_without_events: Dictionary = payload_dictionary.duplicate(false)
			var _events_removed: bool = payload_without_events.erase("events")
			var safe_payload: Dictionary = _json_safe_dictionary(payload_without_events)
			safe_payload["events"] = _duplicate_batch(batch)
			return safe_payload
	return { "events": _duplicate_batch(batch) }


func _compress_payload_text(payload_text: String) -> PackedByteArray:
	return payload_text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)


func _load_or_create_client_id() -> String:
	if not _should_persist_client_id():
		return _generate_id()

	var loaded_id: String = _load_client_id()
	if not loaded_id.is_empty():
		return loaded_id

	var generated_id: String = _generate_id()
	_save_client_id(generated_id)
	return generated_id


func _should_persist_client_id() -> bool:
	return config.persist_client_id and config.enabled and (not config.endpoint_url.is_empty() or transport_callback.is_valid())


func _json_safe_dictionary(value: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(value, _make_report_options())


func _encode_event_properties(properties: Dictionary) -> Dictionary:
	var options: Dictionary = _make_report_options()
	options["max_collection_items"] = maxi(config.max_collection_items, properties.size())
	return GFReportValueCodec.to_report_dictionary(properties, options)


func _contains_report_budget_marker(value: Variant) -> bool:
	var pending: Array = [value]
	while not pending.is_empty():
		var candidate: Variant = pending.pop_back()
		if candidate is Dictionary:
			var dictionary: Dictionary = candidate
			if _is_report_budget_marker(dictionary):
				return true
			for key: Variant in dictionary.keys():
				pending.append(dictionary[key])
		elif candidate is Array:
			var array: Array = candidate
			for item: Variant in array:
				pending.append(item)
	return false


func _is_report_budget_marker(value: Dictionary) -> bool:
	var marker: Dictionary = GFVariantData.get_option_dictionary(value, "__gf_report_value__")
	var marker_type: String = GFVariantData.get_option_string(marker, "type")
	return marker_type in [
		"ByteBudget",
		"NodeBudget",
		"MaxDepth",
		"CollectionBudget",
	]


func _make_report_options() -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_PRIVACY,
		{
			"max_depth": 16,
			"max_string_length": config.max_string_length,
			"max_collection_items": config.max_collection_items,
			"max_packed_length": config.max_collection_items,
			"max_total_nodes": config.max_total_nodes,
			"max_total_bytes": config.max_payload_bytes,
			"encode_dictionary_keys": false,
		}
	)


func _duplicate_batch(batch: Array) -> Array:
	var result: Array = []
	for item: Variant in batch:
		if item is Dictionary:
			var item_dictionary: Dictionary = item
			result.append(item_dictionary.duplicate(true))
	return result


func _load_client_id() -> String:
	if not _is_valid_client_id_storage_path(config.client_id_storage_path):
		_report_invalid_client_id_storage_path()
		return ""
	var config_file: ConfigFile = ConfigFile.new()
	var load_error: Error = config_file.load(config.client_id_storage_path)
	if load_error == ERR_FILE_NOT_FOUND:
		return ""
	if load_error != OK:
		push_warning("[GFAnalyticsUtility] failed to load client id: %s." % error_string(load_error))
		return ""
	var loaded_id: String = GFVariantData.to_text(
		config_file.get_value("analytics", "client_id", "")
	)
	if not _is_valid_client_id(loaded_id):
		return ""
	return loaded_id


func _save_client_id(client_id: String) -> void:
	if not _is_valid_client_id(client_id):
		return
	if not _is_valid_client_id_storage_path(config.client_id_storage_path):
		_report_invalid_client_id_storage_path()
		return

	var config_file: ConfigFile = ConfigFile.new()
	var load_error: Error = config_file.load(config.client_id_storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("[GFAnalyticsUtility] failed to load client id before save: %s." % error_string(load_error))
		return
	config_file.set_value("analytics", "client_id", client_id)
	var storage_dir: String = ProjectSettings.globalize_path(config.client_id_storage_path.get_base_dir())
	if not DirAccess.dir_exists_absolute(storage_dir):
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(storage_dir)
		if directory_error != OK:
			push_warning("[GFAnalyticsUtility] failed to create client id directory: %s." % error_string(directory_error))
			return
	var save_error: Error = config_file.save(config.client_id_storage_path)
	if save_error != OK:
		push_warning("[GFAnalyticsUtility] failed to save client id: %s." % error_string(save_error))


func _is_valid_client_id_storage_path(path: String) -> bool:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if not normalized.begins_with("user://"):
		return false
	for segment: String in normalized.trim_prefix("user://").split("/", false):
		if segment == "..":
			return false
	return not normalized.trim_prefix("user://").is_empty()


func _is_valid_client_id(client_id: String) -> bool:
	return (
		not client_id.is_empty()
		and client_id.length() <= _MAX_CLIENT_ID_LENGTH
		and not _contains_control_character(client_id)
	)


func _contains_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 0x20 or codepoint == 0x7f:
			return true
	return false


func _report_invalid_client_id_storage_path() -> void:
	if _reported_invalid_storage_path:
		return
	_reported_invalid_storage_path = true
	push_warning("[GFAnalyticsUtility] client_id_storage_path must stay under user:// without parent traversal.")


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
	if GFAutoload.is_tree_exit_in_progress():
		watcher.queue_free()
		return
	if watcher.is_inside_tree() and watcher.get_parent() != null:
		watcher.get_parent().remove_child(watcher)
	watcher.free()


func _variant_to_node(value: Variant) -> Node:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
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
