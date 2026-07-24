# GFAnalyticsConfig

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/analytics/gf_analytics_config.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用事件分析配置。 默认不开启网络依赖；若未配置 endpoint，flush 会以 dry-run 成功完成， 便于项目在本地或测试环境中保持同一套调用路径。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`enabled`](#member-gfanalyticsconfig-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`endpoint_url`](#member-gfanalyticsconfig-properties-endpoint_url) | `var endpoint_url: String = ""` |
| 属性 | [`flush_interval_seconds`](#member-gfanalyticsconfig-properties-flush_interval_seconds) | `var flush_interval_seconds: float = 5.0:` |
| 属性 | [`batch_size`](#member-gfanalyticsconfig-properties-batch_size) | `var batch_size: int = 20:` |
| 属性 | [`max_queue_size`](#member-gfanalyticsconfig-properties-max_queue_size) | `var max_queue_size: int = 1000:` |
| 属性 | [`max_event_name_length`](#member-gfanalyticsconfig-properties-max_event_name_length) | `var max_event_name_length: int = 128:` |
| 属性 | [`max_property_count`](#member-gfanalyticsconfig-properties-max_property_count) | `var max_property_count: int = 128:` |
| 属性 | [`max_string_length`](#member-gfanalyticsconfig-properties-max_string_length) | `var max_string_length: int = 4096:` |
| 属性 | [`max_collection_items`](#member-gfanalyticsconfig-properties-max_collection_items) | `var max_collection_items: int = 256:` |
| 属性 | [`max_total_nodes`](#member-gfanalyticsconfig-properties-max_total_nodes) | `var max_total_nodes: int = 8192:` |
| 属性 | [`max_payload_bytes`](#member-gfanalyticsconfig-properties-max_payload_bytes) | `var max_payload_bytes: int = 256 * 1024:` |
| 属性 | [`auto_capture_context`](#member-gfanalyticsconfig-properties-auto_capture_context) | `var auto_capture_context: bool = true` |
| 属性 | [`app_version`](#member-gfanalyticsconfig-properties-app_version) | `var app_version: String = ""` |
| 属性 | [`persist_client_id`](#member-gfanalyticsconfig-properties-persist_client_id) | `var persist_client_id: bool = true` |
| 属性 | [`client_id_storage_path`](#member-gfanalyticsconfig-properties-client_id_storage_path) | `var client_id_storage_path: String = "user://gf_analytics_client.cfg"` |
| 属性 | [`flush_on_shutdown`](#member-gfanalyticsconfig-properties-flush_on_shutdown) | `var flush_on_shutdown: bool = true` |
| 属性 | [`compress_payload`](#member-gfanalyticsconfig-properties-compress_payload) | `var compress_payload: bool = false` |
| 属性 | [`headers`](#member-gfanalyticsconfig-properties-headers) | `var headers: Dictionary = {}` |
| 方法 | [`build_headers`](#member-gfanalyticsconfig-methods-build_headers) | `func build_headers() -> PackedStringArray:` |

## 属性

<a id="member-gfanalyticsconfig-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用事件收集。

<a id="member-gfanalyticsconfig-properties-endpoint_url"></a>

### `endpoint_url`

- API：`public`

```gdscript
var endpoint_url: String = ""
```

HTTP 上报地址。为空时不会发起网络请求。

<a id="member-gfanalyticsconfig-properties-flush_interval_seconds"></a>

### `flush_interval_seconds`

- API：`public`

```gdscript
var flush_interval_seconds: float = 5.0:
```

上报间隔，单位秒。小于等于 0 时不自动上报。

<a id="member-gfanalyticsconfig-properties-batch_size"></a>

### `batch_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var batch_size: int = 20:
```

单批最大事件数；直接赋值会钳制到 1..500。

<a id="member-gfanalyticsconfig-properties-max_queue_size"></a>

### `max_queue_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_queue_size: int = 1000:
```

本地队列最大事件数；直接赋值会钳制到 1..100_000。

<a id="member-gfanalyticsconfig-properties-max_event_name_length"></a>

### `max_event_name_length`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_event_name_length: int = 128:
```

单个事件名允许的最大字符数。

<a id="member-gfanalyticsconfig-properties-max_property_count"></a>

### `max_property_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_property_count: int = 128:
```

单个事件允许的顶层属性数量。

<a id="member-gfanalyticsconfig-properties-max_string_length"></a>

### `max_string_length`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_string_length: int = 4096:
```

单个报告字符串允许的最大字符数。

<a id="member-gfanalyticsconfig-properties-max_collection_items"></a>

### `max_collection_items`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_collection_items: int = 256:
```

单个报告集合允许编码的最大元素数。

<a id="member-gfanalyticsconfig-properties-max_total_nodes"></a>

### `max_total_nodes`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_total_nodes: int = 8192:
```

单次报告编码允许遍历的最大节点数。

<a id="member-gfanalyticsconfig-properties-max_payload_bytes"></a>

### `max_payload_bytes`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_payload_bytes: int = 256 * 1024:
```

transport 接收的单批 JSON 最大字节数。

<a id="member-gfanalyticsconfig-properties-auto_capture_context"></a>

### `auto_capture_context`

- API：`public`

```gdscript
var auto_capture_context: bool = true
```

是否自动附加运行环境上下文。

<a id="member-gfanalyticsconfig-properties-app_version"></a>

### `app_version`

- API：`public`

```gdscript
var app_version: String = ""
```

可选应用版本。

<a id="member-gfanalyticsconfig-properties-persist_client_id"></a>

### `persist_client_id`

- API：`public`

```gdscript
var persist_client_id: bool = true
```

是否持久化匿名 client id。

<a id="member-gfanalyticsconfig-properties-client_id_storage_path"></a>

### `client_id_storage_path`

- API：`public`

```gdscript
var client_id_storage_path: String = "user://gf_analytics_client.cfg"
```

client id 持久化文件路径。

<a id="member-gfanalyticsconfig-properties-flush_on_shutdown"></a>

### `flush_on_shutdown`

- API：`public`

```gdscript
var flush_on_shutdown: bool = true
```

应用关闭通知到来时是否尝试 flush 剩余事件。

<a id="member-gfanalyticsconfig-properties-compress_payload"></a>

### `compress_payload`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
var compress_payload: bool = false
```

是否使用 gzip 压缩 HTTP 上报请求体。

<a id="member-gfanalyticsconfig-properties-headers"></a>

### `headers`

- API：`public`

```gdscript
var headers: Dictionary = {}
```

自定义 HTTP Header。

结构：

- `headers`: Dictionary[String, String] mapping header names to header values.

## 方法

<a id="member-gfanalyticsconfig-methods-build_headers"></a>

### `build_headers`

- API：`public`

```gdscript
func build_headers() -> PackedStringArray:
```

构建 HTTP Header 数组。

返回：Header 字符串数组。
