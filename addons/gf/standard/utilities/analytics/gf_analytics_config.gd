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

## 单批最大事件数。
## [br]
## @api public
@export_range(1, 500, 1) var batch_size: int = 20:
	set(value):
		batch_size = maxi(value, 1)

## 本地队列最大事件数。
## [br]
## @api public
@export_range(1, 100000, 1) var max_queue_size: int = 1000:
	set(value):
		max_queue_size = maxi(value, 1)

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

## 自定义 HTTP Header。
## [br]
## @api public
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
	var result: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	for key: Variant in headers:
		var header_name: String = GFVariantData.to_text(key).strip_edges()
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
		var _header_appended: bool = result.append("%s: %s" % [header_name, header_value])
	if compress_payload:
		var _gzip_header_appended: bool = result.append("Content-Encoding: gzip")
	return result


# --- 私有/辅助方法 ---

func _is_valid_header(header_name: String, header_value: String) -> bool:
	if header_name.is_empty():
		return false
	return (
		not header_name.contains("\r")
		and not header_name.contains("\n")
		and not header_value.contains("\r")
		and not header_value.contains("\n")
	)


func _is_same_header_name(header_name: String, expected_name: String) -> bool:
	return header_name.to_lower() == expected_name.to_lower()


func _escape_header_for_log(header_name: String) -> String:
	return header_name.replace("\r", "\\r").replace("\n", "\\n")
