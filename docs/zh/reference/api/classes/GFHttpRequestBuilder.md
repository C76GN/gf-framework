# GFHttpRequestBuilder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_http_request_builder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 HTTP 请求构建器。 负责整理 URL、query、headers、body、timeout 和响应解析策略。 它只封装 Godot HTTPRequest 的通用流程，不内置任何具体服务、鉴权或业务接口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Method`](#member-gfhttprequestbuilder-enums-method) | `enum Method` |
| 枚举 | [`ParseMode`](#member-gfhttprequestbuilder-enums-parsemode) | `enum ParseMode` |
| 常量 | [`DEFAULT_MAX_RESPONSE_BYTES`](#member-gfhttprequestbuilder-constants-default_max_response_bytes) | `const DEFAULT_MAX_RESPONSE_BYTES: int = 0` |
| 常量 | [`UNLIMITED_MAX_RESPONSE_BYTES`](#member-gfhttprequestbuilder-constants-unlimited_max_response_bytes) | `const UNLIMITED_MAX_RESPONSE_BYTES: int = -1` |
| 属性 | [`url`](#member-gfhttprequestbuilder-properties-url) | `var url: String = ""` |
| 属性 | [`method`](#member-gfhttprequestbuilder-properties-method) | `var method: Method = Method.GET` |
| 属性 | [`parse_mode`](#member-gfhttprequestbuilder-properties-parse_mode) | `var parse_mode: ParseMode = ParseMode.TEXT` |
| 属性 | [`timeout_seconds`](#member-gfhttprequestbuilder-properties-timeout_seconds) | `var timeout_seconds: float = 20.0` |
| 属性 | [`max_response_bytes`](#member-gfhttprequestbuilder-properties-max_response_bytes) | `var max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES:` |
| 属性 | [`metadata`](#member-gfhttprequestbuilder-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_url`](#member-gfhttprequestbuilder-methods-set_url) | `func set_url(next_url: String) -> GFHttpRequestBuilder:` |
| 方法 | [`set_method`](#member-gfhttprequestbuilder-methods-set_method) | `func set_method(next_method: Method) -> GFHttpRequestBuilder:` |
| 方法 | [`set_parse_mode`](#member-gfhttprequestbuilder-methods-set_parse_mode) | `func set_parse_mode(next_parse_mode: ParseMode) -> GFHttpRequestBuilder:` |
| 方法 | [`set_timeout`](#member-gfhttprequestbuilder-methods-set_timeout) | `func set_timeout(seconds: float) -> GFHttpRequestBuilder:` |
| 方法 | [`set_max_response_bytes`](#member-gfhttprequestbuilder-methods-set_max_response_bytes) | `func set_max_response_bytes(bytes: int) -> GFHttpRequestBuilder:` |
| 方法 | [`set_header`](#member-gfhttprequestbuilder-methods-set_header) | `func set_header(key: String, value: String) -> GFHttpRequestBuilder:` |
| 方法 | [`remove_header`](#member-gfhttprequestbuilder-methods-remove_header) | `func remove_header(key: String) -> GFHttpRequestBuilder:` |
| 方法 | [`add_query_parameter`](#member-gfhttprequestbuilder-methods-add_query_parameter) | `func add_query_parameter(key: String, value: Variant) -> GFHttpRequestBuilder:` |
| 方法 | [`set_text_body`](#member-gfhttprequestbuilder-methods-set_text_body) | `func set_text_body(text: String, content_type: String = "text/plain; charset=utf-8") -> GFHttpRequestBuilder:` |
| 方法 | [`set_json_body`](#member-gfhttprequestbuilder-methods-set_json_body) | `func set_json_body(value: Variant) -> GFHttpRequestBuilder:` |
| 方法 | [`build_url`](#member-gfhttprequestbuilder-methods-build_url) | `func build_url() -> String:` |
| 方法 | [`build_headers`](#member-gfhttprequestbuilder-methods-build_headers) | `func build_headers() -> PackedStringArray:` |
| 方法 | [`build_request`](#member-gfhttprequestbuilder-methods-build_request) | `func build_request() -> Dictionary:` |
| 方法 | [`duplicate_builder`](#member-gfhttprequestbuilder-methods-duplicate_builder) | `func duplicate_builder() -> GFHttpRequestBuilder:` |
| 方法 | [`execute`](#member-gfhttprequestbuilder-methods-execute) | `func execute(parent: Node = null) -> GFHttpResponse:` |
| 方法 | [`parse_body`](#member-gfhttprequestbuilder-methods-parse_body) | `func parse_body(body: PackedByteArray) -> Dictionary:` |

## 枚举

<a id="member-gfhttprequestbuilder-enums-method"></a>

### `Method`

- API：`public`

```gdscript
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
```

HTTP 请求方法。

<a id="member-gfhttprequestbuilder-enums-parsemode"></a>

### `ParseMode`

- API：`public`

```gdscript
enum ParseMode {
	## 不解析响应体。
	NONE,
	## 按 UTF-8 文本解析。
	TEXT,
	## 按 JSON 解析。
	JSON,
}
```

响应体解析模式。

## 常量

<a id="member-gfhttprequestbuilder-constants-default_max_response_bytes"></a>

### `DEFAULT_MAX_RESPONSE_BYTES`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
const DEFAULT_MAX_RESPONSE_BYTES: int = 0
```

响应体预算默认交给执行传输决定。一次性 HTTPRequest 因此保留 Godot 的无限制默认值。

<a id="member-gfhttprequestbuilder-constants-unlimited_max_response_bytes"></a>

### `UNLIMITED_MAX_RESPONSE_BYTES`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
const UNLIMITED_MAX_RESPONSE_BYTES: int = -1
```

显式关闭响应体大小限制时使用的值。

## 属性

<a id="member-gfhttprequestbuilder-properties-url"></a>

### `url`

- API：`public`

```gdscript
var url: String = ""
```

请求 URL。

<a id="member-gfhttprequestbuilder-properties-method"></a>

### `method`

- API：`public`

```gdscript
var method: Method = Method.GET
```

HTTP 方法。

<a id="member-gfhttprequestbuilder-properties-parse_mode"></a>

### `parse_mode`

- API：`public`

```gdscript
var parse_mode: ParseMode = ParseMode.TEXT
```

响应解析模式。

<a id="member-gfhttprequestbuilder-properties-timeout_seconds"></a>

### `timeout_seconds`

- API：`public`

```gdscript
var timeout_seconds: float = 20.0
```

请求超时时间，单位秒。

<a id="member-gfhttprequestbuilder-properties-max_response_bytes"></a>

### `max_response_bytes`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
var max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES:
```

单个响应体允许进入内存的最大字节数。0 表示继承执行传输默认值，-1 表示无限制。

<a id="member-gfhttprequestbuilder-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据，会复制到 GFHttpResponse。

结构：

- `metadata`: Dictionary，复制到 GFHttpResponse 的调用方元数据。

## 方法

<a id="member-gfhttprequestbuilder-methods-set_url"></a>

### `set_url`

- API：`public`

```gdscript
func set_url(next_url: String) -> GFHttpRequestBuilder:
```

设置请求 URL。

参数：

| 名称 | 说明 |
|---|---|
| `next_url` | 新 URL。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_method"></a>

### `set_method`

- API：`public`

```gdscript
func set_method(next_method: Method) -> GFHttpRequestBuilder:
```

设置 HTTP 方法。

参数：

| 名称 | 说明 |
|---|---|
| `next_method` | HTTP 方法枚举。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_parse_mode"></a>

### `set_parse_mode`

- API：`public`

```gdscript
func set_parse_mode(next_parse_mode: ParseMode) -> GFHttpRequestBuilder:
```

设置响应解析模式。

参数：

| 名称 | 说明 |
|---|---|
| `next_parse_mode` | 解析模式。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_timeout"></a>

### `set_timeout`

- API：`public`

```gdscript
func set_timeout(seconds: float) -> GFHttpRequestBuilder:
```

设置请求超时时间。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时秒数。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_max_response_bytes"></a>

### `set_max_response_bytes`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func set_max_response_bytes(bytes: int) -> GFHttpRequestBuilder:
```

设置单个响应体允许进入内存的最大字节数。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 最大响应字节数；0 继承执行传输默认值，-1 关闭限制，正数设置明确上限。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_header"></a>

### `set_header`

- API：`public`

```gdscript
func set_header(key: String, value: String) -> GFHttpRequestBuilder:
```

设置或覆盖请求头。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 请求头名称。 |
| `value` | 请求头值。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-remove_header"></a>

### `remove_header`

- API：`public`

```gdscript
func remove_header(key: String) -> GFHttpRequestBuilder:
```

移除请求头。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 请求头名称。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-add_query_parameter"></a>

### `add_query_parameter`

- API：`public`

```gdscript
func add_query_parameter(key: String, value: Variant) -> GFHttpRequestBuilder:
```

添加 query 参数。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 参数名。 |
| `value` | 参数值。 |

返回：当前构建器。

结构：

- `value`: Variant，URI 编码前会转换为文本的查询参数值。

<a id="member-gfhttprequestbuilder-methods-set_text_body"></a>

### `set_text_body`

- API：`public`

```gdscript
func set_text_body(text: String, content_type: String = "text/plain; charset=utf-8") -> GFHttpRequestBuilder:
```

设置文本请求体。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 请求体文本。 |
| `content_type` | 可选 Content-Type。 |

返回：当前构建器。

<a id="member-gfhttprequestbuilder-methods-set_json_body"></a>

### `set_json_body`

- API：`public`

```gdscript
func set_json_body(value: Variant) -> GFHttpRequestBuilder:
```

设置 JSON 请求体。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 可被 JSON.stringify() 序列化的数据。 |

返回：当前构建器。

结构：

- `value`: Variant，兼容 JSON.stringify 的请求体载荷。

<a id="member-gfhttprequestbuilder-methods-build_url"></a>

### `build_url`

- API：`public`

```gdscript
func build_url() -> String:
```

构建最终 URL。

返回：拼接 query 后的 URL。

<a id="member-gfhttprequestbuilder-methods-build_headers"></a>

### `build_headers`

- API：`public`

```gdscript
func build_headers() -> PackedStringArray:
```

构建 Godot HTTPRequest 可用的请求头数组。

返回：Header 数组。

<a id="member-gfhttprequestbuilder-methods-build_request"></a>

### `build_request`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_request() -> Dictionary:
```

构建普通请求字典，适合测试、日志或项目自定义传输层使用。

返回：请求快照。

结构：

- `return`: Dictionary，包含 url、method、method_name、headers、body、timeout_seconds、max_response_bytes、parse_mode、parse_mode_name 和 metadata。

<a id="member-gfhttprequestbuilder-methods-duplicate_builder"></a>

### `duplicate_builder`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func duplicate_builder() -> GFHttpRequestBuilder:
```

创建不共享可变请求状态的构建器副本。

返回：当前请求配置的独立副本。

<a id="member-gfhttprequestbuilder-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute(parent: Node = null) -> GFHttpResponse:
```

使用 HTTPRequest 执行请求。

参数：

| 名称 | 说明 |
|---|---|
| `parent` | HTTPRequest 节点的父节点；为空时尝试挂到当前 SceneTree root。 |

返回：响应对象，可监听 completed。

<a id="member-gfhttprequestbuilder-methods-parse_body"></a>

### `parse_body`

- API：`public`

```gdscript
func parse_body(body: PackedByteArray) -> Dictionary:
```

按当前 parse_mode 解析响应体。

参数：

| 名称 | 说明 |
|---|---|
| `body` | 响应 bytes。 |

返回：解析结果字典。

结构：

- `return`: Dictionary，包含 ok、text、data 和可选 error。
