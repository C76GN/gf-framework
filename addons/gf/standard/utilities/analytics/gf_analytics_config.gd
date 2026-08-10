## GFAnalyticsConfig: 通用事件分析配置。
##
## 默认不开启网络依赖；若未配置 endpoint，flush 会以 dry-run 成功完成，
## 便于项目在本地或测试环境中保持同一套调用路径。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFAnalyticsConfig
extends Resource


# --- 常量 ---

const _MAX_CUSTOM_HEADER_COUNT: int = 64
const _MAX_HEADER_CANDIDATE_COUNT: int = 256
const _MAX_HEADER_NAME_BYTES: int = 256
const _MAX_HEADER_VALUE_BYTES: int = 8192
const _MAX_TOTAL_HEADER_BYTES: int = 64 * 1024
const _HTTP_TOKEN_PUNCTUATION: String = "!#$%&'*+-.^_`|~"


# --- 导出变量 ---

## 是否启用事件收集。
## [br]
## @api public
@export var enabled: bool = true

## HTTP 上报地址。为空时不会发起网络请求。
## [br]
## @api public
@export var endpoint_url: String = ""

## 上报间隔，单位秒。小于等于 0 时不自动上报。
## [br]
## @api public
@export var flush_interval_seconds: float = 5.0:
	set(value):
		flush_interval_seconds = maxf(value, 0.0)

## 单批最大事件数；直接赋值会钳制到 1..500。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 500, 1) var batch_size: int = 20:
	set(value):
		batch_size = clampi(value, 1, 500)

## 本地队列最大事件数；直接赋值会钳制到 1..100_000。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 100000, 1) var max_queue_size: int = 1000:
	set(value):
		max_queue_size = clampi(value, 1, 100000)

## 单个事件名允许的最大字符数。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 4096, 1) var max_event_name_length: int = 128:
	set(value):
		max_event_name_length = clampi(value, 1, 4096)

## 单个事件允许的顶层属性数量。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 4096, 1) var max_property_count: int = 128:
	set(value):
		max_property_count = clampi(value, 1, 4096)

## 单个报告字符串允许的最大字符数。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 65536, 1) var max_string_length: int = 4096:
	set(value):
		max_string_length = clampi(value, 1, 65536)

## 单个报告集合允许编码的最大元素数。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 4096, 1) var max_collection_items: int = 256:
	set(value):
		max_collection_items = clampi(value, 1, 4096)

## 单次报告编码允许遍历的最大节点数。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 1000000, 1) var max_total_nodes: int = 8192:
	set(value):
		max_total_nodes = clampi(value, 1, 1000000)

## transport 接收的单批 JSON 最大字节数。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1024, 16777216, 1024) var max_payload_bytes: int = 256 * 1024:
	set(value):
		max_payload_bytes = clampi(value, 1024, 16 * 1024 * 1024)

## 是否自动附加运行环境上下文。
## [br]
## @api public
@export var auto_capture_context: bool = true

## 可选应用版本。
## [br]
## @api public
@export var app_version: String = ""

## 是否持久化匿名 client id。
## [br]
## @api public
@export var persist_client_id: bool = true

## client id 持久化文件路径。
## [br]
## @api public
@export var client_id_storage_path: String = "user://gf_analytics_client.cfg"

## 应用关闭通知到来时是否尝试 flush 剩余事件。
## [br]
## @api public
@export var flush_on_shutdown: bool = true

## 是否使用 gzip 压缩 HTTP 上报请求体。
## [br]
## @api public
## [br]
## @since 3.20.0
@export var compress_payload: bool = false

## 自定义 HTTP Header。字段名必须符合 HTTP token grammar，字段值不得包含非法控制字符；
## 构建时还会执行字段数量、单字段 UTF-8 字节数和总字节数预算。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @schema headers: Dictionary[String, String] mapping header names to header values.
@export var headers: Dictionary = {}


# --- 公共方法 ---

## 构建 HTTP Header 数组。
## [br]
## @api public
## [br]
## @return Header 字符串数组。
func build_headers() -> PackedStringArray:
	var content_type_header: String = "Content-Type: application/json"
	var gzip_header: String = "Content-Encoding: gzip"
	var result: PackedStringArray = PackedStringArray([content_type_header])
	var accepted_custom_count: int = 0
	var examined_candidate_count: int = 0
	var total_header_bytes: int = content_type_header.to_utf8_buffer().size() + 2
	if compress_payload:
		total_header_bytes += gzip_header.to_utf8_buffer().size() + 2
	var seen_header_names: Dictionary = { "content-type": true }
	for key: Variant in headers:
		if examined_candidate_count >= _MAX_HEADER_CANDIDATE_COUNT:
			push_warning("[GFAnalyticsConfig] 自定义 HTTP Header 候选超过 256，已停止扫描。")
			break
		examined_candidate_count += 1
		if accepted_custom_count >= _MAX_CUSTOM_HEADER_COUNT:
			push_warning("[GFAnalyticsConfig] 自定义 HTTP Header 数量超过 64，已忽略剩余字段。")
			break
		var header_name: String = GFVariantData.to_text(key)
		var header_value: String = GFVariantData.to_text(headers[key])
		if not _is_valid_header(header_name, header_value):
			push_warning("[GFAnalyticsConfig] 忽略非法 HTTP Header：%s" % _escape_header_for_log(header_name))
			continue
		if _is_same_header_name(header_name, "Content-Type"):
			push_warning("[GFAnalyticsConfig] 忽略自定义 Content-Type；analytics payload 固定为 application/json。")
			continue
		if compress_payload and _is_same_header_name(header_name, "Content-Encoding"):
			push_warning("[GFAnalyticsConfig] compress_payload 已启用，忽略自定义 Content-Encoding。")
			continue
		var canonical_header_name: String = header_name.to_lower()
		if seen_header_names.has(canonical_header_name):
			push_warning("[GFAnalyticsConfig] 忽略重复 HTTP Header：%s" % _escape_header_for_log(header_name))
			continue
		var header_line: String = "%s: %s" % [header_name, header_value]
		var header_line_bytes: int = header_line.to_utf8_buffer().size() + 2
		if total_header_bytes + header_line_bytes > _MAX_TOTAL_HEADER_BYTES:
			push_warning("[GFAnalyticsConfig] 自定义 HTTP Header 总字节数超过 65536，已忽略剩余字段。")
			break
		var _header_appended: bool = result.append(header_line)
		seen_header_names[canonical_header_name] = true
		accepted_custom_count += 1
		total_header_bytes += header_line_bytes
	if compress_payload:
		var _gzip_header_appended: bool = result.append(gzip_header)
	return result


# --- 私有/辅助方法 ---

func _is_valid_header(header_name: String, header_value: String) -> bool:
	return _is_valid_header_name(header_name) and _is_valid_header_value(header_value)


func _is_valid_header_name(header_name: String) -> bool:
	if (
		header_name.is_empty()
		or header_name.to_utf8_buffer().size() > _MAX_HEADER_NAME_BYTES
	):
		return false
	for index: int in range(header_name.length()):
		if not _is_http_token_codepoint(header_name.unicode_at(index)):
			return false
	return true


func _is_valid_header_value(header_value: String) -> bool:
	if header_value.to_utf8_buffer().size() > _MAX_HEADER_VALUE_BYTES:
		return false
	if not header_value.is_empty():
		var first_codepoint: int = header_value.unicode_at(0)
		var last_codepoint: int = header_value.unicode_at(header_value.length() - 1)
		if first_codepoint == 0x09 or first_codepoint == 0x20:
			return false
		if last_codepoint == 0x09 or last_codepoint == 0x20:
			return false
	for index: int in range(header_value.length()):
		var codepoint: int = header_value.unicode_at(index)
		if (codepoint < 0x20 and codepoint != 0x09) or codepoint == 0x7f:
			return false
	return true


func _is_http_token_codepoint(codepoint: int) -> bool:
	if (
		(codepoint >= 0x30 and codepoint <= 0x39)
		or (codepoint >= 0x41 and codepoint <= 0x5a)
		or (codepoint >= 0x61 and codepoint <= 0x7a)
	):
		return true
	if codepoint < 0x21 or codepoint > 0x7e:
		return false
	return _HTTP_TOKEN_PUNCTUATION.contains(String.chr(codepoint))


func _is_same_header_name(header_name: String, expected_name: String) -> bool:
	return header_name.to_lower() == expected_name.to_lower()


func _escape_header_for_log(header_name: String) -> String:
	var escaped: String = ""
	for index: int in range(header_name.length()):
		var codepoint: int = header_name.unicode_at(index)
		match codepoint:
			0x0d:
				escaped += "\\r"
			0x0a:
				escaped += "\\n"
			_:
				if codepoint < 0x20 or codepoint == 0x7f:
					escaped += "\\u%04x" % codepoint
				else:
					escaped += String.chr(codepoint)
	return escaped
