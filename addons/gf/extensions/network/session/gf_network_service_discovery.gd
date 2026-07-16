## GFNetworkServiceDiscovery: 传输无关的网络服务发现记录器。
##
## 负责生成服务广告字典、JSON bytes 编解码、接收入站广告并维护带 TTL 的服务列表。
## 它不打开 socket、不决定广播地址，也不规定房间、账号、鉴权或同步协议。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFNetworkServiceDiscovery
extends RefCounted


# --- 信号 ---

## 首次看到某个服务 endpoint 时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 服务发现内部稳定 key。
## [br]
## @param record: 服务记录副本。
## [br]
## @schema record: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.
signal service_found(service_key: String, record: Dictionary)

## 已知服务 endpoint 被新广告刷新时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 服务发现内部稳定 key。
## [br]
## @param record: 服务记录副本。
## [br]
## @schema record: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.
signal service_updated(service_key: String, record: Dictionary)

## 服务过期、被清空或被手动移除时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 服务发现内部稳定 key。
## [br]
## @param record: 服务记录副本。
## [br]
## @param reason: 移除原因。
## [br]
## @schema record: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.
signal service_lost(service_key: String, record: Dictionary, reason: String)


# --- 常量 ---

## 服务广告消息类型标记。
## [br]
## @api public
## [br]
## @since 8.0.0
const MESSAGE_KIND: String = "gf.service.discovery"

## 当前服务广告 schema 版本。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEMA_VERSION: int = 1
const _TRANSPORT_VALUE_VALIDATOR = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")
const _DEFAULT_MAX_ADVERTISEMENT_BYTES: int = GFNetworkMessageValidator.DEFAULT_MAX_PACKET_SIZE
const _DEFAULT_MAX_METADATA_DEPTH: int = 16
const _DEFAULT_MAX_METADATA_ENTRIES: int = 1024


# --- 公共变量 ---

## 缺省服务广告 TTL，单位秒。
## [br]
## @api public
## [br]
## @since 8.0.0
var default_ttl_seconds: float = 5.0:
	set(value):
		default_ttl_seconds = _normalize_positive_seconds(value, 5.0)


# --- 私有变量 ---

var _elapsed_seconds: float = 0.0
var _services: Dictionary = {}


# --- 公共方法 ---

## 构造服务广告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_id: 服务类型或协议标识。
## [br]
## @param endpoint: 项目可连接的 endpoint 文本。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @param options: 可选项，支持 display_name、tags、ttl_seconds、sequence 和 time_msec。
## [br]
## @return 服务广告字典。
## [br]
## @schema metadata: Dictionary[String, Variant] copied into the advertisement without GF interpreting project fields.
## [br]
## @schema options: Dictionary with display_name: String, tags: PackedStringArray|Array[String], ttl_seconds: float, sequence: int, and time_msec: int.
## [br]
## @schema return: Dictionary with kind, schema_version, service_id, endpoint, display_name, tags, metadata, ttl_seconds, sequence, and time_msec.
func make_advertisement(
	service_id: StringName,
	endpoint: String,
	metadata: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var ttl_seconds: float = _normalize_positive_seconds(
		GFVariantData.get_option_float(options, "ttl_seconds", default_ttl_seconds),
		default_ttl_seconds
	)
	return {
		"kind": MESSAGE_KIND,
		"schema_version": SCHEMA_VERSION,
		"service_id": String(service_id).strip_edges(),
		"endpoint": endpoint.strip_edges(),
		"display_name": GFVariantData.get_option_string(options, "display_name"),
		"tags": _normalize_tags(GFVariantData.get_option_value(options, "tags", PackedStringArray())),
		"metadata": GFVariantData.to_dictionary(metadata),
		"ttl_seconds": ttl_seconds,
		"sequence": GFVariantData.get_option_int(options, "sequence"),
		"time_msec": GFVariantData.get_option_int(options, "time_msec", Time.get_ticks_msec()),
	}


## 接收已解码的服务广告并更新本地服务列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param advertisement: 服务广告字典。
## [br]
## @param options: 可选项，支持 remote_address、remote_port 和 now_seconds。
## [br]
## @return 接收报告。
## [br]
## @schema advertisement: Dictionary produced by make_advertisement() or decode_advertisement().
## [br]
## @schema options: Dictionary with remote_address: String, remote_port: int, and now_seconds: float.
## [br]
## @schema return: Dictionary with ok, status, service_key, record, error, issues, issue_count, and next_action.
func accept_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:
	var validation: Dictionary = validate_advertisement(advertisement)
	if not GFVariantData.get_option_bool(validation, "ok"):
		return validation

	var normalized: Dictionary = GFVariantData.get_option_dictionary(validation, "data")
	var service_id: StringName = GFVariantData.get_option_string_name(normalized, "service_id")
	var endpoint: String = GFVariantData.get_option_string(normalized, "endpoint")
	var service_key: String = make_service_key(service_id, endpoint)
	var now_seconds: float = _normalize_now_seconds(
		GFVariantData.get_option_float(options, "now_seconds", _elapsed_seconds)
	)
	var ttl_seconds: float = GFVariantData.get_option_float(normalized, "ttl_seconds", default_ttl_seconds)
	var existed: bool = _services.has(service_key)
	var previous_record: Dictionary = GFVariantData.get_option_dictionary(_services, service_key)
	if existed and _is_stale_advertisement(normalized, previous_record):
		return _make_accept_report("ignored_stale", service_key, previous_record)

	var first_seen_seconds: float = GFVariantData.get_option_float(
		previous_record,
		"first_seen_seconds",
		now_seconds
	)

	var record: Dictionary = normalized.duplicate(true)
	record["service_key"] = service_key
	record["service_id"] = service_id
	record["first_seen_seconds"] = first_seen_seconds
	record["last_seen_seconds"] = now_seconds
	record["expires_at_seconds"] = now_seconds + ttl_seconds
	record["remote_address"] = GFVariantData.get_option_string(options, "remote_address")
	record["remote_port"] = GFVariantData.get_option_int(options, "remote_port")
	_services[service_key] = record

	var report: Dictionary = _make_accept_report("updated" if existed else "found", service_key, record)
	if existed:
		service_updated.emit(service_key, record.duplicate(true))
	else:
		service_found.emit(service_key, record.duplicate(true))
	return report


## 解码并接收服务广告 bytes。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bytes: UTF-8 JSON bytes。
## [br]
## @param remote_address: 底层传输报告的远端地址。
## [br]
## @param remote_port: 底层传输报告的远端端口。
## [br]
## @param options: 可选项，支持 json_codec_options、now_seconds 和广告结构预算。
## [br]
## @return 接收报告。
## [br]
## @schema options: Dictionary with json_codec_options, now_seconds, max_advertisement_bytes, max_metadata_depth, and max_metadata_entries.
## [br]
## @schema return: Dictionary with ok, status, service_key, record, error, issues, issue_count, and next_action.
func accept_packet(
	bytes: PackedByteArray,
	remote_address: String = "",
	remote_port: int = 0,
	options: Dictionary = {}
) -> Dictionary:
	var decoded: Dictionary = decode_advertisement(bytes, options)
	if not GFVariantData.get_option_bool(decoded, "ok"):
		return decoded

	return accept_advertisement(GFVariantData.get_option_dictionary(decoded, "data"), {
		"remote_address": remote_address,
		"remote_port": remote_port,
		"now_seconds": GFVariantData.get_option_float(options, "now_seconds", _elapsed_seconds),
	})


## 推进发现列表时间并移除过期服务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta: 本帧时间增量，单位秒。
func tick(delta: float) -> void:
	if delta <= 0.0 or is_nan(delta) or is_inf(delta):
		return
	_elapsed_seconds += delta
	_prune_expired_services()


## 获取指定服务记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 服务发现内部稳定 key。
## [br]
## @return 服务记录副本；不存在时返回空字典。
## [br]
## @schema return: Dictionary service record or empty Dictionary.
func get_service(service_key: String) -> Dictionary:
	if not _services.has(service_key):
		return {}
	return GFVariantData.get_option_dictionary(_services, service_key)


## 获取当前服务 key 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 排序后的服务 key。
func get_service_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _services.keys():
		var _append_result: bool = result.append(GFVariantData.to_text(key))
	result.sort()
	return result


## 获取当前服务记录列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_id: 可选服务类型过滤；为空时返回全部。
## [br]
## @return 服务记录副本数组。
## [br]
## @schema return: Array[Dictionary] of service records.
func get_services(service_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service_key: String in get_service_keys():
		var record: Dictionary = get_service(service_key)
		if service_id != &"" and GFVariantData.get_option_string_name(record, "service_id") != service_id:
			continue
		result.append(record)
	return result


## 手动移除服务记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 服务发现内部稳定 key。
## [br]
## @param reason: 移除原因。
## [br]
## @return 成功移除返回 true。
func remove_service(service_key: String, reason: String = "removed") -> bool:
	return _remove_service(service_key, reason)


## 清空服务列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 移除原因。
func clear_services(reason: String = "cleared") -> void:
	for service_key: String in get_service_keys():
		var _removed: bool = _remove_service(service_key, reason)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试状态字典。
## [br]
## @schema return: Dictionary with service_count, service_keys, default_ttl_seconds, and elapsed_seconds.
func get_debug_snapshot() -> Dictionary:
	return GFNetworkDebugTools.sanitize_debug_dictionary({
		"service_count": _services.size(),
		"service_keys": get_service_keys(),
		"default_ttl_seconds": default_ttl_seconds,
		"elapsed_seconds": _elapsed_seconds,
	})


## 编码服务广告为 UTF-8 JSON bytes。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param advertisement: 服务广告字典。
## [br]
## @param options: 可选项，支持 json_codec_options 和广告结构预算。
## [br]
## @return UTF-8 JSON bytes。
## [br]
## @schema advertisement: Dictionary produced by make_advertisement().
## [br]
## @schema options: Dictionary with json_codec_options, max_advertisement_bytes, max_metadata_depth, and max_metadata_entries.
static func encode_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> PackedByteArray:
	var validation: Dictionary = validate_advertisement(advertisement, options)
	if not GFVariantData.get_option_bool(validation, "ok", false):
		push_error(
			"[GFNetworkServiceDiscovery] 广告编码失败：%s。" %
			GFVariantData.get_option_string(validation, "error", "invalid_advertisement")
		)
		return PackedByteArray()
	var codec_options: Dictionary = GFVariantData.get_option_dictionary(options, "json_codec_options")
	var normalized: Dictionary = GFVariantData.get_option_dictionary(validation, "data")
	var encoded: PackedByteArray = GFVariantJsonCodec.stringify_json_compatible(
		normalized,
		"",
		false,
		codec_options
	).to_utf8_buffer()
	var max_advertisement_bytes: int = maxi(
		GFVariantData.get_option_int(options, "max_advertisement_bytes", _DEFAULT_MAX_ADVERTISEMENT_BYTES),
		1
	)
	if encoded.size() > max_advertisement_bytes:
		push_error("[GFNetworkServiceDiscovery] 广告编码失败：advertisement_too_large。")
		return PackedByteArray()
	return encoded


## 解码 UTF-8 JSON bytes 为服务广告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bytes: UTF-8 JSON bytes。
## [br]
## @param options: 可选项，支持 json_codec_options。
## [br]
## @return 解码报告。
## [br]
## @schema options: Dictionary with json_codec_options: Dictionary passed to GFVariantJsonCodec.
## [br]
## @schema return: Dictionary with ok, data, error, issues, issue_count, and next_action.
static func decode_advertisement(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:
	if bytes.is_empty():
		return _make_failure("empty_bytes", "Provide non-empty advertisement bytes.")
	var max_advertisement_bytes: int = maxi(
		GFVariantData.get_option_int(options, "max_advertisement_bytes", _DEFAULT_MAX_ADVERTISEMENT_BYTES),
		1
	)
	if bytes.size() > max_advertisement_bytes:
		return _make_failure("advertisement_too_large", "Reduce the advertisement packet size before decoding.")

	var json: JSON = JSON.new()
	var error: Error = json.parse(bytes.get_string_from_utf8())
	if error != OK:
		return _make_failure("invalid_json", json.get_error_message())

	var codec_options: Dictionary = GFVariantData.get_option_dictionary(options, "json_codec_options")
	var decoded: Variant = GFVariantJsonCodec.json_compatible_to_variant(json.data, codec_options)
	if not (decoded is Dictionary):
		return _make_failure("json_not_dictionary", "Service advertisement payload must be a Dictionary.")
	var decoded_dictionary: Dictionary = GFVariantData.to_dictionary(decoded)
	return validate_advertisement(decoded_dictionary, options)


## 校验并规范化服务广告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param advertisement: 服务广告字典。
## [br]
## @param options: 与 encode_advertisement()/decode_advertisement() 共享的结构预算。
## [br]
## @return 校验报告。
## [br]
## @schema advertisement: Dictionary service advertisement payload.
## [br]
## @schema options: Dictionary with max_metadata_depth and max_metadata_entries.
## [br]
## @schema return: Dictionary with ok, data, error, issues, issue_count, and next_action.
static func validate_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var normalized: Dictionary = _normalize_advertisement(advertisement, issues, options)
	if not issues.is_empty():
		var first_issue: Dictionary = issues[0]
		return {
			"ok": false,
			"data": {},
			"normalized": normalized,
			"error": GFVariantData.get_option_string(first_issue, "kind"),
			"issues": issues,
			"issue_count": issues.size(),
			"next_action": "Use make_advertisement() or provide a valid GF service advertisement dictionary.",
		}

	return {
		"ok": true,
		"data": normalized,
		"normalized": normalized,
		"error": "",
		"issues": issues,
		"issue_count": 0,
		"next_action": "",
	}


## 生成服务发现内部稳定 key。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_id: 服务类型或协议标识。
## [br]
## @param endpoint: 项目可连接的 endpoint 文本。
## [br]
## @return 服务 key。
static func make_service_key(service_id: StringName, endpoint: String) -> String:
	var service_text: String = String(service_id).strip_edges()
	var endpoint_text: String = GFNetworkDebugTools.sanitize_endpoint(endpoint.strip_edges())
	return "%s@%s" % [service_text, endpoint_text.sha256_text()]


# --- 私有/辅助方法 ---

static func _normalize_advertisement(
	advertisement: Dictionary,
	issues: Array[Dictionary],
	options: Dictionary
) -> Dictionary:
	var metadata_value: Variant = GFVariantData.get_option_value(advertisement, "metadata", {})
	var tags_value: Variant = GFVariantData.get_option_value(advertisement, "tags", PackedStringArray())
	var kind: String = GFVariantData.get_option_string(advertisement, "kind")
	var schema_version: int = GFVariantData.get_option_int(advertisement, "schema_version")
	var service_id: StringName = GFVariantData.get_option_string_name(advertisement, "service_id")
	var endpoint: String = GFVariantData.get_option_string(advertisement, "endpoint").strip_edges()
	var ttl_seconds: float = GFVariantData.get_option_float(advertisement, "ttl_seconds")

	if kind != MESSAGE_KIND:
		issues.append(_make_issue("invalid_kind", "Advertisement kind must be %s." % MESSAGE_KIND))
	if schema_version != SCHEMA_VERSION:
		issues.append(_make_issue("unsupported_schema_version", "Advertisement schema_version is not supported."))
	if service_id == &"":
		issues.append(_make_issue("missing_service_id", "Advertisement service_id must be non-empty."))
	if endpoint.is_empty():
		issues.append(_make_issue("missing_endpoint", "Advertisement endpoint must be non-empty."))
	if ttl_seconds <= 0.0 or is_nan(ttl_seconds) or is_inf(ttl_seconds):
		issues.append(_make_issue("invalid_ttl_seconds", "Advertisement ttl_seconds must be a positive finite number."))
	if not (metadata_value is Dictionary):
		issues.append(_make_issue("metadata_not_dictionary", "Advertisement metadata must be a Dictionary."))
	else:
		var metadata_report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(metadata_value, {
			"max_depth": maxi(
				GFVariantData.get_option_int(options, "max_metadata_depth", _DEFAULT_MAX_METADATA_DEPTH),
				0
			),
			"max_nodes": maxi(
				GFVariantData.get_option_int(options, "max_metadata_entries", _DEFAULT_MAX_METADATA_ENTRIES),
				1
			),
		})
		if not GFVariantData.get_option_bool(metadata_report, "ok"):
			issues.append(_make_issue(
				"metadata_%s" % GFVariantData.get_option_string(metadata_report, "error", "invalid_value"),
				"Advertisement metadata is not transport-safe."
			))
	if not (tags_value is PackedStringArray) and not (tags_value is Array):
		issues.append(_make_issue("tags_not_array", "Advertisement tags must be PackedStringArray or Array."))

	var metadata: Dictionary = GFVariantData.to_dictionary(metadata_value)
	return {
		"kind": kind,
		"schema_version": schema_version,
		"service_id": service_id,
		"endpoint": endpoint,
		"display_name": GFVariantData.get_option_string(advertisement, "display_name"),
		"tags": _normalize_tags(tags_value),
		"metadata": metadata,
		"ttl_seconds": ttl_seconds,
		"sequence": GFVariantData.get_option_int(advertisement, "sequence"),
		"time_msec": GFVariantData.get_option_int(advertisement, "time_msec"),
	}


static func _is_stale_advertisement(normalized: Dictionary, previous_record: Dictionary) -> bool:
	if previous_record.is_empty():
		return false
	var incoming_sequence: int = GFVariantData.get_option_int(normalized, "sequence", 0)
	var previous_sequence: int = GFVariantData.get_option_int(previous_record, "sequence", 0)
	if incoming_sequence < previous_sequence:
		return true
	if incoming_sequence > previous_sequence:
		return false
	var incoming_time_msec: int = GFVariantData.get_option_int(normalized, "time_msec", 0)
	var previous_time_msec: int = GFVariantData.get_option_int(previous_record, "time_msec", 0)
	return incoming_time_msec < previous_time_msec


static func _normalize_tags(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_tags: PackedStringArray = value
		for tag: String in packed_tags:
			_append_tag(result, tag)
	elif value is Array:
		var array_tags: Array = value
		for tag_value: Variant in array_tags:
			_append_tag(result, GFVariantData.to_text(tag_value))
	result.sort()
	return result


static func _append_tag(tags: PackedStringArray, tag: String) -> void:
	var normalized: String = tag.strip_edges()
	if normalized.is_empty() or tags.has(normalized):
		return
	var _append_result: bool = tags.append(normalized)


static func _make_issue(kind: String, message: String) -> Dictionary:
	return {
		"kind": kind,
		"message": message,
	}


static func _make_failure(error: String, next_action: String = "") -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"normalized": {},
		"error": error,
		"issues": [_make_issue(error, next_action)],
		"issue_count": 1,
		"next_action": next_action,
	}


static func _normalize_positive_seconds(value: float, fallback: float) -> float:
	if value > 0.0 and not is_nan(value) and not is_inf(value):
		return value
	if fallback > 0.0 and not is_nan(fallback) and not is_inf(fallback):
		return fallback
	return 5.0


func _make_accept_report(status: String, service_key: String, record: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"status": status,
		"service_key": service_key,
		"record": record.duplicate(true),
		"error": "",
		"issues": [],
		"issue_count": 0,
		"next_action": "",
	}


func _normalize_now_seconds(value: float) -> float:
	if value >= 0.0 and not is_nan(value) and not is_inf(value):
		return value
	return _elapsed_seconds


func _prune_expired_services() -> void:
	var expired_keys: PackedStringArray = PackedStringArray()
	for key: Variant in _services.keys():
		var service_key: String = GFVariantData.to_text(key)
		var record: Dictionary = GFVariantData.get_option_dictionary(_services, service_key)
		var expires_at_seconds: float = GFVariantData.get_option_float(record, "expires_at_seconds", -1.0)
		if expires_at_seconds >= 0.0 and expires_at_seconds <= _elapsed_seconds:
			var _append_result: bool = expired_keys.append(service_key)

	for service_key: String in expired_keys:
		var _removed: bool = _remove_service(service_key, "expired")


func _remove_service(service_key: String, reason: String) -> bool:
	var normalized_key: String = service_key.strip_edges()
	if normalized_key.is_empty() or not _services.has(normalized_key):
		return false

	var record: Dictionary = get_service(normalized_key)
	var erased: bool = _services.erase(normalized_key)
	if erased:
		service_lost.emit(normalized_key, record, reason)
	return erased
