## GFAnalyticsOutboxAdapter: Analytics 批次到通用请求 Outbox 的有界持久交接适配器。
##
## 把 GFAnalyticsUtility 的 JSON-safe events 封装为固定、版本化的中立请求信封，
## 并在确认 GFRequestOutboxUtility 已可靠持久化后才接受整批事件。适配器不接管
## Outbox 的 transport_callback 或 replay_filter，也不持久化鉴权 Header；项目应在
## 实际重放时根据当前会话动态注入鉴权、同意与供应商协议。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFAnalyticsOutboxAdapter
extends RefCounted


# --- 常量 ---

## 持久化批次协议标识。
## [br]
## @api public
## [br]
## @since unreleased
const SCHEMA_ID: StringName = &"gf.analytics.outbox"

## 持久化批次协议版本。
## [br]
## @api public
## [br]
## @since unreleased
const PROTOCOL_VERSION: int = 1

## 默认逻辑端点。它不是供应商 URL，也不包含账号或鉴权信息。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_ENDPOINT_URL: String = "gf://analytics/events"

const _GF_UUID = preload("res://addons/gf/standard/foundation/identity/gf_uuid.gd")
const _MIN_PAYLOAD_BYTES: int = 1024
const _MAX_PAYLOAD_BYTES: int = 16 * 1024 * 1024
const _MAX_EVENTS_HARD_LIMIT: int = 500
const _MAX_ATTEMPTS_HARD_LIMIT: int = 64
const _MAX_SCHEMA_VERSION: int = 2_147_483_647
const _MAX_DEPTH_HARD_LIMIT: int = 32
const _MAX_COLLECTION_ITEMS_HARD_LIMIT: int = 4096
const _MAX_STRING_LENGTH_HARD_LIMIT: int = 65_536
const _MAX_TOTAL_NODES_HARD_LIMIT: int = 1_000_000


# --- 公共变量 ---

## 专用于 Analytics 的请求 Outbox。
##
## 建议使用独立实例和 `user://gf_analytics_outbox.json`，避免与其他业务共享单一
## transport/filter 入口及存储生命周期。
## [br]
## @api public
## [br]
## @since unreleased
var outbox: GFRequestOutboxUtility = null

## 写入请求信封的非敏感逻辑端点。
##
## 该值会持久化并参与协议身份校验，不得包含 userinfo、凭据、query 或 fragment；
## 不得为空、超过 2048 字符或包含空白、控制字符。供应商路由和鉴权应由 replay
## transport 动态注入。
## [br]
## @api public
## [br]
## @since unreleased
var endpoint_url: String = DEFAULT_ENDPOINT_URL

## 单个持久化批次的最终 JSON 字节上限；直接赋值会钳制到 1024..16 MiB。
## [br]
## @api public
## [br]
## @since unreleased
var max_payload_bytes: int = 256 * 1024:
	set(value):
		max_payload_bytes = clampi(value, _MIN_PAYLOAD_BYTES, _MAX_PAYLOAD_BYTES)

## 单个持久化批次的事件数量上限；直接赋值会钳制到 1..500。
## [br]
## @api public
## [br]
## @since unreleased
var max_events_per_request: int = 500:
	set(value):
		max_events_per_request = clampi(value, 1, _MAX_EVENTS_HARD_LIMIT)

## 请求重放最大尝试次数；直接赋值和 configure() 都会钳制到 1..64。
## [br]
## @api public
## [br]
## @since unreleased
var max_attempts: int = 3:
	set(value):
		max_attempts = clampi(value, 1, _MAX_ATTEMPTS_HARD_LIMIT)

## 单个事件嵌套深度上限；直接赋值会钳制到 1..32。
## [br]
## @api public
## [br]
## @since unreleased
var max_depth: int = 16:
	set(value):
		max_depth = clampi(value, 1, _MAX_DEPTH_HARD_LIMIT)

## 单个嵌套集合的元素上限；直接赋值会钳制到 1..4096。
## [br]
## @api public
## [br]
## @since unreleased
var max_collection_items: int = 256:
	set(value):
		max_collection_items = clampi(value, 1, _MAX_COLLECTION_ITEMS_HARD_LIMIT)

## 单个字符串的字符上限；直接赋值会钳制到 1..65_536。
## [br]
## @api public
## [br]
## @since unreleased
var max_string_length: int = 4096:
	set(value):
		max_string_length = clampi(value, 1, _MAX_STRING_LENGTH_HARD_LIMIT)

## 整批遍历的节点上限；直接赋值会钳制到 1..1_000_000。
## [br]
## @api public
## [br]
## @since unreleased
var max_total_nodes: int = 8192:
	set(value):
		max_total_nodes = clampi(value, 1, _MAX_TOTAL_NODES_HARD_LIMIT)


# --- 私有变量 ---

var _last_reason: StringName = &"not_configured"


# --- 公共方法 ---

## 配置适配器。
##
## 本方法只保存 Outbox 引用和有界选项，不修改 Outbox 的 transport_callback、
## replay_filter、storage_path 或生命周期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_outbox: 项目配置并拥有生命周期的专用 Outbox。
## [br]
## @param options: 可选 endpoint_url、max_payload_bytes、max_events_per_request、max_attempts、max_depth、max_collection_items、max_string_length 和 max_total_nodes。
## [br]
## @return 当前适配器。
## [br]
## @schema options: Dictionary of bounded adapter configuration overrides.
func configure(
	p_outbox: GFRequestOutboxUtility,
	options: Dictionary = {}
) -> GFAnalyticsOutboxAdapter:
	outbox = p_outbox
	if options.has("endpoint_url") or options.has(&"endpoint_url"):
		var configured_endpoint: Variant = GFVariantData.get_option_value(
			options,
			"endpoint_url"
		)
		endpoint_url = (
			GFVariantData.to_text(configured_endpoint)
			if _is_text_value(configured_endpoint)
			else ""
		)
	max_payload_bytes = clampi(
		GFVariantData.get_option_int(options, "max_payload_bytes", max_payload_bytes),
		_MIN_PAYLOAD_BYTES,
		_MAX_PAYLOAD_BYTES
	)
	max_events_per_request = clampi(
		GFVariantData.get_option_int(
			options,
			"max_events_per_request",
			max_events_per_request
		),
		1,
		_MAX_EVENTS_HARD_LIMIT
	)
	max_attempts = clampi(
		GFVariantData.get_option_int(options, "max_attempts", max_attempts),
		1,
		_MAX_ATTEMPTS_HARD_LIMIT
	)
	max_depth = clampi(
		GFVariantData.get_option_int(options, "max_depth", max_depth),
		1,
		_MAX_DEPTH_HARD_LIMIT
	)
	max_collection_items = clampi(
		GFVariantData.get_option_int(
			options,
			"max_collection_items",
			max_collection_items
		),
		1,
		_MAX_COLLECTION_ITEMS_HARD_LIMIT
	)
	max_string_length = clampi(
		GFVariantData.get_option_int(options, "max_string_length", max_string_length),
		1,
		_MAX_STRING_LENGTH_HARD_LIMIT
	)
	max_total_nodes = clampi(
		GFVariantData.get_option_int(options, "max_total_nodes", max_total_nodes),
		1,
		_MAX_TOTAL_NODES_HARD_LIMIT
	)
	_last_reason = &"configured" if outbox != null else &"missing_outbox"
	return self


## 把 Analytics payload 可靠交接给 Outbox。
##
## v1 采用整批成功或整批失败语义。版本化事件按有序 event_id 列表派生稳定
## batch/idempotency identity；legacy 事件使用持久化在信封内的随机 batch identity。
## 精确匹配且尚可尝试的 pending 只有在重新保存并复核后才返回 already_queued；
## 已耗尽但尚未迁移的 pending 返回 exhausted_pending，相同身份若已进入 failed
## store 则返回 already_failed。项目必须显式审查、清理或重新授权，Adapter 不会
## 自动复活 dead-letter。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: GFAnalyticsUtility transport_callback 提供的 JSON-safe payload。
## v1 只接受唯一的 events 字段；payload_builder 添加其他顶层字段时会失败关闭，
## 避免 Adapter 静默丢弃项目协议数据。
## [br]
## @return 整批交接结果。
## [br]
## @schema payload: Dictionary with an events Array[Dictionary].
## [br]
## @schema return: Dictionary with success, accepted, queued, persisted, reason, request_id, idempotency_key, and persistence_error.
func enqueue_payload(payload: Dictionary) -> Dictionary:
	if outbox == null:
		return _make_result(false, 0, &"missing_outbox")
	if not _is_valid_endpoint_url(endpoint_url):
		return _make_result(false, 0, &"invalid_endpoint")

	var validation: Dictionary = _validate_payload(payload)
	if not GFVariantData.get_option_bool(validation, "ok"):
		return _make_result(
			false,
			0,
			GFVariantData.get_option_string_name(validation, "reason", &"invalid_payload")
		)
	var events: Array = GFVariantData.get_option_array(validation, "events")
	var identity: Dictionary = _make_batch_identity(events)
	if not GFVariantData.get_option_bool(identity, "ok"):
		return _make_result(
			false,
			0,
			GFVariantData.get_option_string_name(identity, "reason", &"invalid_payload")
		)

	var batch_id: String = GFVariantData.get_option_string(identity, "batch_id")
	var idempotency_key: String = "gf-analytics-v1:%s" % batch_id
	var request_id: StringName = StringName("analytics_%s" % batch_id)
	var body: Dictionary = {
		"schema_id": String(SCHEMA_ID),
		"protocol_version": PROTOCOL_VERSION,
		"batch_id": batch_id,
		"events": events.duplicate(true),
	}
	var payload_bytes: int = _get_json_bytes(body)
	if payload_bytes < 0:
		return _make_result(false, 0, &"invalid_payload")
	if payload_bytes > max_payload_bytes:
		return _make_result(false, 0, &"payload_too_large")

	var metadata: Dictionary = {
		"request_kind": "analytics_batch",
		"schema_id": String(SCHEMA_ID),
		"protocol_version": PROTOCOL_VERSION,
		"batch_id": batch_id,
		"event_count": events.size(),
	}
	var envelope: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		endpoint_url,
		body,
		PackedStringArray(),
		metadata
	)
	envelope.request_id = request_id
	envelope.idempotency_key = idempotency_key
	envelope.max_attempts = max_attempts

	var existing_report: Dictionary = _find_existing_requests(idempotency_key)
	var pending_match_count: int = GFVariantData.get_option_int(
		existing_report,
		"pending_count"
	)
	var failed_match_count: int = GFVariantData.get_option_int(
		existing_report,
		"failed_count"
	)
	if pending_match_count > 1 or failed_match_count > 1 or (
		pending_match_count > 0 and failed_match_count > 0
	):
		return _make_result(
			false,
			0,
			&"idempotency_conflict",
			request_id,
			idempotency_key
		)
	var failed_existing: GFRequestEnvelope = _get_existing_envelope(existing_report, "failed")
	if failed_existing != null:
		if (
			not _validate_envelope(failed_existing)
			or not _envelopes_match(failed_existing, envelope)
		):
			return _make_result(
				false,
				0,
				&"idempotency_conflict",
				request_id,
				idempotency_key
			)
		return _make_result(
			false,
			0,
			&"already_failed",
			failed_existing.request_id,
			failed_existing.idempotency_key,
			false,
			OK
		)
	var pending_existing: GFRequestEnvelope = _get_existing_envelope(existing_report, "pending")
	if pending_existing != null:
		if (
			not _validate_envelope(pending_existing)
			or not _envelopes_match(pending_existing, envelope)
		):
			return _make_result(
				false,
				0,
				&"idempotency_conflict",
				request_id,
				idempotency_key
			)
		if pending_existing.is_exhausted():
			return _make_result(
				false,
				0,
				&"exhausted_pending",
				pending_existing.request_id,
				pending_existing.idempotency_key,
				false,
				OK
			)
		var existing_save_error: Error = outbox.save_queue()
		if existing_save_error != OK:
			return _make_result(
				false,
				0,
				&"persistence_failed",
				pending_existing.request_id,
				pending_existing.idempotency_key,
				false,
				existing_save_error
			)
		var verified_report: Dictionary = _find_existing_requests(idempotency_key)
		var verified_existing: GFRequestEnvelope = _get_existing_envelope(
			verified_report,
			"pending"
		)
		if (
			GFVariantData.get_option_int(verified_report, "pending_count") != 1
			or GFVariantData.get_option_int(verified_report, "failed_count") != 0
			or verified_existing == null
			or not _validate_envelope(verified_existing)
			or not _envelopes_match(verified_existing, envelope)
		):
			return _make_result(
				false,
				0,
				&"enqueue_invalidated",
				request_id,
				idempotency_key
			)
		if verified_existing.is_exhausted():
			return _make_result(
				false,
				0,
				&"exhausted_pending",
				verified_existing.request_id,
				verified_existing.idempotency_key,
				false,
				OK
			)
		if not GFVariantData.get_option_bool(outbox.get_debug_snapshot(), "is_persisted"):
			return _make_result(
				false,
				0,
				&"persistence_failed",
				verified_existing.request_id,
				verified_existing.idempotency_key,
				false,
				ERR_CANT_CREATE
			)
		return _make_result(
			true,
			events.size(),
			&"already_queued",
			verified_existing.request_id,
			verified_existing.idempotency_key,
			true,
			OK
		)

	var enqueue_report: Dictionary = outbox.enqueue_with_report(envelope, true)
	if not GFVariantData.get_option_bool(enqueue_report, "ok"):
		var enqueue_reason: StringName = GFVariantData.get_option_string_name(
			enqueue_report,
			"reason",
			&"outbox_rejected"
		)
		if enqueue_reason == &"persistence_failed":
			enqueue_reason = &"persistence_failed"
		elif enqueue_reason == &"queue_full":
			enqueue_reason = &"outbox_rejected"
		return _make_result(
			false,
			0,
			enqueue_reason,
			request_id,
			idempotency_key,
			false,
			GFVariantData.get_option_int(enqueue_report, "persistence_error", OK) as Error
		)
	if not GFVariantData.get_option_bool(enqueue_report, "persisted"):
		return _make_result(
			false,
			0,
			&"persistence_failed",
			request_id,
			idempotency_key,
			false,
			GFVariantData.get_option_int(enqueue_report, "persistence_error", ERR_CANT_CREATE) as Error
		)

	var stored_envelope: GFRequestEnvelope = _get_report_envelope(enqueue_report)
	if stored_envelope != null:
		request_id = stored_envelope.request_id
		idempotency_key = stored_envelope.idempotency_key
	return _make_result(
		true,
		events.size(),
		&"queued",
		request_id,
		idempotency_key,
		true,
		OK
	)


## 判断恢复出的请求是否属于当前 Adapter 且仍满足 v1 固定协议。
##
## 项目 transport 可在路由后动态注入鉴权并发送；本方法不会调用 transport。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param envelope: 待路由的请求信封。
## [br]
## @return 身份、协议、预算和 body/metadata 一致时返回 true。
func handles_request(envelope: GFRequestEnvelope) -> bool:
	return _validate_envelope(envelope)


## 获取不包含事件、请求 body、业务字段或鉴权数据的调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 安全调试快照。
## [br]
## @schema return: Dictionary with schema_id, protocol_version, configuration budgets, outbox availability, pending/failed counts, and last_reason.
func get_debug_snapshot() -> Dictionary:
	return {
		"schema_id": String(SCHEMA_ID),
		"protocol_version": PROTOCOL_VERSION,
		"max_payload_bytes": max_payload_bytes,
		"max_events_per_request": max_events_per_request,
		"max_attempts": max_attempts,
		"max_depth": max_depth,
		"max_collection_items": max_collection_items,
		"max_string_length": max_string_length,
		"max_total_nodes": max_total_nodes,
		"has_outbox": outbox != null,
		"pending_count": outbox.get_queue_size() if outbox != null else 0,
		"failed_count": outbox.get_failed_request_count() if outbox != null else 0,
		"last_reason": _last_reason,
	}


# --- 私有/辅助方法 ---

func _validate_payload(payload: Dictionary) -> Dictionary:
	if not _has_exact_keys(payload, PackedStringArray(["events"])):
		return { "ok": false, "reason": &"unsupported_payload_fields" }
	var events_value: Variant = GFVariantData.get_option_value(payload, "events", null)
	if not (events_value is Array):
		return { "ok": false, "reason": &"invalid_payload" }
	var events: Array = events_value
	if events.is_empty():
		return { "ok": false, "reason": &"empty_events" }
	if events.size() > max_events_per_request:
		return { "ok": false, "reason": &"event_limit_exceeded" }

	var state: Dictionary = {
		"nodes": 0,
		"encoded_bytes": maxi(_get_empty_batch_body_bytes() - 2, 0),
		"active": [],
	}
	var seen_event_ids: Dictionary = {}
	for index: int in range(events.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			return { "ok": false, "reason": &"invalid_payload" }
		var event: Dictionary = event_value
		var event_name_value: Variant = GFVariantData.get_option_value(event, "event", null)
		if not (event_name_value is String or event_name_value is StringName):
			return { "ok": false, "reason": &"invalid_payload" }
		var event_name: String = GFVariantData.to_text(event_name_value)
		if (
			event_name.is_empty()
			or event_name.length() > max_string_length
			or _contains_control_character(event_name)
		):
			return { "ok": false, "reason": &"invalid_payload" }

		var has_event_id: bool = event.has("event_id")
		var has_schema_version: bool = event.has("schema_version")
		if has_event_id != has_schema_version:
			return { "ok": false, "reason": &"invalid_payload" }
		var expected_event_keys: PackedStringArray = PackedStringArray([
			"event",
			"client_id",
			"session_id",
			"timestamp",
			"properties",
		])
		if event.has("context"):
			var _context_key_appended: bool = expected_event_keys.append("context")
		if has_event_id:
			var _event_id_key_appended: bool = expected_event_keys.append("event_id")
			var _schema_version_key_appended: bool = expected_event_keys.append(
				"schema_version"
			)
		if not _has_exact_keys(event, expected_event_keys):
			return { "ok": false, "reason": &"invalid_payload" }
		for required_text_key: String in [
			"client_id",
			"session_id",
			"timestamp",
		]:
			var required_text_value: Variant = event[required_text_key]
			if (
				not _is_text_value(required_text_value)
				or GFVariantData.to_text(required_text_value).is_empty()
				or GFVariantData.to_text(required_text_value).length() > max_string_length
				or _contains_control_character(
					GFVariantData.to_text(required_text_value)
				)
			):
				return { "ok": false, "reason": &"invalid_payload" }
		if not (event["properties"] is Dictionary):
			return { "ok": false, "reason": &"invalid_payload" }
		if event.has("context") and not (event["context"] is Dictionary):
			return { "ok": false, "reason": &"invalid_payload" }
		if has_event_id:
			var event_id_value: Variant = event["event_id"]
			var schema_version_value: Variant = event["schema_version"]
			if not (event_id_value is String or event_id_value is StringName):
				return { "ok": false, "reason": &"invalid_payload" }
			if not _is_integral_number(schema_version_value):
				return { "ok": false, "reason": &"invalid_payload" }
			var event_id: String = GFVariantData.to_text(event_id_value)
			var schema_version: int = GFVariantData.to_int(schema_version_value)
			if (
				not _GF_UUID.is_valid(event_id)
				or schema_version <= 0
				or schema_version > _MAX_SCHEMA_VERSION
			):
				return { "ok": false, "reason": &"invalid_payload" }
			if seen_event_ids.has(event_id):
				return { "ok": false, "reason": &"duplicate_event_id" }
			seen_event_ids[event_id] = true

	var value_report: Dictionary = _validate_json_value(events, 0, state)
	if not GFVariantData.get_option_bool(value_report, "ok"):
		return value_report
	return {
		"ok": true,
		"reason": &"valid",
		"events": events,
	}


func _validate_json_value(value: Variant, depth: int, state: Dictionary) -> Dictionary:
	if depth > max_depth:
		return { "ok": false, "reason": &"payload_depth_exceeded" }
	var node_count: int = GFVariantData.get_option_int(state, "nodes") + 1
	state["nodes"] = node_count
	if node_count > max_total_nodes:
		return { "ok": false, "reason": &"payload_node_budget_exceeded" }

	if value == null or value is bool or value is int:
		return _reserve_payload_scalar_bytes(value, state)
	if value is float:
		var float_value: float = value
		if not is_finite(float_value):
			return { "ok": false, "reason": &"non_finite_value" }
		return _reserve_payload_scalar_bytes(float_value, state)
	if value is String or value is StringName:
		if GFVariantData.to_text(value).length() > max_string_length:
			return { "ok": false, "reason": &"payload_string_too_long" }
		return _reserve_payload_scalar_bytes(value, state)
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.size() > max_collection_items:
			return { "ok": false, "reason": &"payload_collection_too_large" }
		if _is_active_collection(dictionary, state):
			return { "ok": false, "reason": &"circular_payload" }
		if not _reserve_payload_bytes(
			state,
			2 + maxi(dictionary.size() - 1, 0)
		):
			return { "ok": false, "reason": &"payload_too_large" }
		_push_active_collection(dictionary, state)
		var seen_keys: Dictionary = {}
		for key: Variant in dictionary.keys():
			if not (key is String or key is StringName):
				_pop_active_collection(state)
				return { "ok": false, "reason": &"invalid_payload_key" }
			var key_text: String = GFVariantData.to_text(key)
			if key_text.length() > max_string_length or seen_keys.has(key_text):
				_pop_active_collection(state)
				return { "ok": false, "reason": &"invalid_payload_key" }
			seen_keys[key_text] = true
			if not _reserve_payload_bytes(
				state,
				JSON.stringify(key_text).to_utf8_buffer().size() + 1
			):
				_pop_active_collection(state)
				return { "ok": false, "reason": &"payload_too_large" }
			state["nodes"] = GFVariantData.get_option_int(state, "nodes") + 1
			if GFVariantData.get_option_int(state, "nodes") > max_total_nodes:
				_pop_active_collection(state)
				return { "ok": false, "reason": &"payload_node_budget_exceeded" }
			var child_report: Dictionary = _validate_json_value(
				dictionary[key],
				depth + 1,
				state
			)
			if not GFVariantData.get_option_bool(child_report, "ok"):
				_pop_active_collection(state)
				return child_report
		_pop_active_collection(state)
		return { "ok": true }
	if value is Array:
		var array: Array = value
		if array.size() > max_collection_items:
			return { "ok": false, "reason": &"payload_collection_too_large" }
		if _is_active_collection(array, state):
			return { "ok": false, "reason": &"circular_payload" }
		if not _reserve_payload_bytes(
			state,
			2 + maxi(array.size() - 1, 0)
		):
			return { "ok": false, "reason": &"payload_too_large" }
		_push_active_collection(array, state)
		for item: Variant in array:
			var item_report: Dictionary = _validate_json_value(item, depth + 1, state)
			if not GFVariantData.get_option_bool(item_report, "ok"):
				_pop_active_collection(state)
				return item_report
		_pop_active_collection(state)
		return { "ok": true }
	return { "ok": false, "reason": &"unsupported_payload_value" }


func _make_batch_identity(events: Array) -> Dictionary:
	var event_ids: Array[String] = []
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			return { "ok": false, "reason": &"invalid_payload" }
		var event: Dictionary = event_value
		var event_id: String = GFVariantData.get_option_string(event, "event_id")
		if event_id.is_empty():
			return {
				"ok": true,
				"batch_id": _GF_UUID.generate_v7(),
				"versioned": false,
			}
		event_ids.append(event_id)
	var identity_text: String = JSON.stringify({
		"protocol_version": PROTOCOL_VERSION,
		"event_ids": event_ids,
	}, "", true)
	return {
		"ok": true,
		"batch_id": identity_text.sha256_text(),
		"versioned": true,
	}


func _validate_envelope(envelope: GFRequestEnvelope) -> bool:
	if envelope == null or not envelope.is_valid():
		return false
	if not _is_valid_endpoint_url(envelope.url):
		return false
	if envelope.method != HTTPClient.METHOD_POST or envelope.url != endpoint_url:
		return false
	if not envelope.headers.is_empty():
		return false
	if envelope.max_attempts < 1 or envelope.max_attempts > _MAX_ATTEMPTS_HARD_LIMIT:
		return false
	if envelope.attempt_count < 0 or envelope.next_attempt_at_unix_msec < 0:
		return false
	if not _has_exact_keys(
		envelope.body,
		PackedStringArray(["schema_id", "protocol_version", "batch_id", "events"])
	):
		return false
	if not _has_exact_keys(
		envelope.metadata,
		PackedStringArray([
			"request_kind",
			"schema_id",
			"protocol_version",
			"batch_id",
			"event_count",
		])
	):
		return false
	var body_schema_id_value: Variant = envelope.body["schema_id"]
	var body_protocol_version_value: Variant = envelope.body["protocol_version"]
	var body_batch_id_value: Variant = envelope.body["batch_id"]
	var metadata_request_kind_value: Variant = envelope.metadata["request_kind"]
	var metadata_schema_id_value: Variant = envelope.metadata["schema_id"]
	var metadata_protocol_version_value: Variant = envelope.metadata["protocol_version"]
	var metadata_batch_id_value: Variant = envelope.metadata["batch_id"]
	var metadata_event_count_value: Variant = envelope.metadata["event_count"]
	if (
		not _is_text_value(body_schema_id_value)
		or not _is_integral_number(body_protocol_version_value)
		or not _is_text_value(body_batch_id_value)
		or not _is_text_value(metadata_request_kind_value)
		or not _is_text_value(metadata_schema_id_value)
		or not _is_integral_number(metadata_protocol_version_value)
		or not _is_text_value(metadata_batch_id_value)
		or not _is_integral_number(metadata_event_count_value)
	):
		return false
	if GFVariantData.get_option_string(envelope.body, "schema_id") != String(SCHEMA_ID):
		return false
	if GFVariantData.get_option_int(envelope.body, "protocol_version") != PROTOCOL_VERSION:
		return false
	if GFVariantData.get_option_string(envelope.metadata, "request_kind") != "analytics_batch":
		return false
	if GFVariantData.get_option_string(envelope.metadata, "schema_id") != String(SCHEMA_ID):
		return false
	if GFVariantData.get_option_int(envelope.metadata, "protocol_version") != PROTOCOL_VERSION:
		return false

	var batch_id: String = GFVariantData.get_option_string(envelope.body, "batch_id")
	if batch_id.is_empty():
		return false
	if GFVariantData.get_option_string(envelope.metadata, "batch_id") != batch_id:
		return false
	if envelope.request_id != StringName("analytics_%s" % batch_id):
		return false
	if envelope.idempotency_key != "gf-analytics-v1:%s" % batch_id:
		return false

	var payload: Dictionary = {
		"events": GFVariantData.get_option_value(envelope.body, "events", null),
	}
	var payload_report: Dictionary = _validate_payload(payload)
	if not GFVariantData.get_option_bool(payload_report, "ok"):
		return false
	var events: Array = GFVariantData.get_option_array(payload_report, "events")
	if GFVariantData.get_option_int(envelope.metadata, "event_count") != events.size():
		return false
	if _get_json_bytes(envelope.body) > max_payload_bytes:
		return false

	var identity: Dictionary = _make_batch_identity(events)
	if not GFVariantData.get_option_bool(identity, "ok"):
		return false
	if GFVariantData.get_option_bool(identity, "versioned"):
		return GFVariantData.get_option_string(identity, "batch_id") == batch_id
	return _GF_UUID.is_valid(batch_id, 7)


func _find_existing_requests(idempotency_key: String) -> Dictionary:
	var result: Dictionary = {
		"pending": null,
		"pending_count": 0,
		"failed": null,
		"failed_count": 0,
	}
	if outbox == null or idempotency_key.is_empty():
		return result
	for envelope: GFRequestEnvelope in outbox.get_pending_requests():
		if envelope.idempotency_key == idempotency_key:
			result["pending_count"] = GFVariantData.get_option_int(
				result,
				"pending_count"
			) + 1
			if GFVariantData.get_option_value(result, "pending") == null:
				result["pending"] = envelope
	for envelope: GFRequestEnvelope in outbox.get_failed_requests():
		if envelope.idempotency_key == idempotency_key:
			result["failed_count"] = GFVariantData.get_option_int(
				result,
				"failed_count"
			) + 1
			if GFVariantData.get_option_value(result, "failed") == null:
				result["failed"] = envelope
	return result


func _get_existing_envelope(report: Dictionary, key: String) -> GFRequestEnvelope:
	var value: Variant = GFVariantData.get_option_value(report, key, null)
	if value is GFRequestEnvelope:
		var envelope: GFRequestEnvelope = value
		return envelope
	return null


func _envelopes_match(left: GFRequestEnvelope, right: GFRequestEnvelope) -> bool:
	if left == null or right == null:
		return false
	var left_identity: Dictionary = _make_envelope_identity(left)
	var right_identity: Dictionary = _make_envelope_identity(right)
	return _get_canonical_json_text(left_identity) == _get_canonical_json_text(right_identity)


func _make_envelope_identity(envelope: GFRequestEnvelope) -> Dictionary:
	var header_values: Array[String] = []
	for header: String in envelope.headers:
		header_values.append(header)
	return {
		"request_id": String(envelope.request_id),
		"method": envelope.method,
		"url": envelope.url,
		"body": envelope.body.duplicate(true),
		"headers": header_values,
		"idempotency_key": envelope.idempotency_key,
		"max_attempts": envelope.max_attempts,
		"metadata": envelope.metadata.duplicate(true),
	}


func _has_exact_keys(value: Dictionary, expected_keys: PackedStringArray) -> bool:
	if value.size() != expected_keys.size():
		return false
	for expected_key: String in expected_keys:
		if not value.has(expected_key):
			return false
	return true


func _is_active_collection(value: Variant, state: Dictionary) -> bool:
	var active_value: Variant = GFVariantData.get_option_value(state, "active", [])
	if not (active_value is Array):
		return false
	var active: Array = active_value
	for candidate: Variant in active:
		if is_same(candidate, value):
			return true
	return false


func _push_active_collection(value: Variant, state: Dictionary) -> void:
	var active: Array = _get_active_array(state)
	active.append(value)
	state["active"] = active


func _pop_active_collection(state: Dictionary) -> void:
	var active: Array = _get_active_array(state)
	if not active.is_empty():
		var _removed: Variant = active.pop_back()
	state["active"] = active


func _get_active_array(state: Dictionary) -> Array:
	var active_value: Variant = GFVariantData.get_option_value(state, "active", [])
	if active_value is Array:
		var active: Array = active_value
		return active
	var fallback: Array = []
	state["active"] = fallback
	return fallback


func _get_report_envelope(report: Dictionary) -> GFRequestEnvelope:
	var value: Variant = GFVariantData.get_option_value(report, "envelope", null)
	if value is GFRequestEnvelope:
		var envelope: GFRequestEnvelope = value
		return envelope
	return null


func _get_json_bytes(value: Variant) -> int:
	var text: String = _get_json_text(value)
	return -1 if text.is_empty() else text.to_utf8_buffer().size()


func _get_empty_batch_body_bytes() -> int:
	return _get_json_bytes({
		"schema_id": String(SCHEMA_ID),
		"protocol_version": PROTOCOL_VERSION,
		"batch_id": "x".repeat(64),
		"events": [],
	})


func _reserve_payload_scalar_bytes(value: Variant, state: Dictionary) -> Dictionary:
	var scalar_bytes: int = _get_json_bytes(value)
	if scalar_bytes < 0:
		return { "ok": false, "reason": &"invalid_payload" }
	var reserved: bool = _reserve_payload_bytes(state, scalar_bytes)
	return {
		"ok": reserved,
		"reason": &"valid" if reserved else &"payload_too_large",
	}


func _reserve_payload_bytes(state: Dictionary, byte_count: int) -> bool:
	if byte_count < 0:
		return false
	var next_bytes: int = GFVariantData.get_option_int(state, "encoded_bytes") + byte_count
	if next_bytes > max_payload_bytes:
		return false
	state["encoded_bytes"] = next_bytes
	return true


func _get_json_text(value: Variant) -> String:
	var json_value: Variant = GFVariantJsonCodec.variant_to_json_compatible(value)
	return JSON.stringify(json_value, "", true)


func _get_canonical_json_text(value: Variant) -> String:
	var encoded_text: String = _get_json_text(value)
	if encoded_text.is_empty():
		return ""
	var json: JSON = JSON.new()
	if json.parse(encoded_text) != OK:
		return ""
	return JSON.stringify(json.data, "", true)


func _is_valid_endpoint_url(value: String) -> bool:
	if (
		value.is_empty()
		or value.length() > 2048
		or value != value.strip_edges()
		or value.contains("?")
		or value.contains("#")
		or value.contains("@")
	):
		return false
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if _is_endpoint_whitespace_or_control(codepoint):
			return false
	return true


func _is_endpoint_whitespace_or_control(codepoint: int) -> bool:
	return (
		codepoint <= 0x20
		or (codepoint >= 0x7f and codepoint <= 0x9f)
		or codepoint == 0x00a0
		or codepoint == 0x1680
		or (codepoint >= 0x2000 and codepoint <= 0x200a)
		or codepoint == 0x2028
		or codepoint == 0x2029
		or codepoint == 0x202f
		or codepoint == 0x205f
		or codepoint == 0x3000
	)


func _contains_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 0x20 or codepoint == 0x7f:
			return true
	return false


func _is_text_value(value: Variant) -> bool:
	return value is String or value is StringName


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		var int_value: int = value
		return int_value >= -2147483648 and int_value <= _MAX_SCHEMA_VERSION
	if not (value is float):
		return false
	var float_value: float = value
	return (
		is_finite(float_value)
		and float_value >= -2147483648.0
		and float_value <= 2147483647.0
		and floor(float_value) == float_value
	)


func _make_result(
	success: bool,
	accepted: int,
	reason: StringName,
	request_id: StringName = &"",
	idempotency_key: String = "",
	persisted: bool = false,
	persistence_error: Error = OK
) -> Dictionary:
	_last_reason = reason
	return {
		"success": success,
		"accepted": accepted if success else 0,
		"queued": success,
		"persisted": persisted,
		"reason": reason,
		"request_id": String(request_id),
		"idempotency_key": idempotency_key,
		"persistence_error": persistence_error,
	}
