# GFHttpResponse

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_http_response.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 HTTP 请求结果。 以对象形式表达 pending、completed、failed、cancelled 等状态，便于请求构建器、 批处理器和项目侧工具统一观察异步结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfhttpresponse-signals-completed) | `signal completed(response: GFHttpResponse)` |
| 枚举 | [`State`](#member-gfhttpresponse-enums-state) | `enum State` |
| 属性 | [`state`](#member-gfhttpresponse-properties-state) | `var state: State = State.PENDING` |
| 属性 | [`url`](#member-gfhttpresponse-properties-url) | `var url: String = ""` |
| 属性 | [`status_code`](#member-gfhttpresponse-properties-status_code) | `var status_code: int = 0` |
| 属性 | [`result_code`](#member-gfhttpresponse-properties-result_code) | `var result_code: int = HTTPRequest.RESULT_SUCCESS` |
| 属性 | [`headers`](#member-gfhttpresponse-properties-headers) | `var headers: PackedStringArray = PackedStringArray()` |
| 属性 | [`text`](#member-gfhttpresponse-properties-text) | `var text: String = ""` |
| 属性 | [`body`](#member-gfhttpresponse-properties-body) | `var body: PackedByteArray = PackedByteArray()` |
| 属性 | [`data`](#member-gfhttpresponse-properties-data) | `var data: Variant = null` |
| 属性 | [`error`](#member-gfhttpresponse-properties-error) | `var error: String = ""` |
| 属性 | [`metadata`](#member-gfhttpresponse-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`cancel_callback`](#member-gfhttpresponse-properties-cancel_callback) | `var cancel_callback: Callable = Callable()` |
| 方法 | [`is_pending`](#member-gfhttpresponse-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_successful`](#member-gfhttpresponse-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`is_finished`](#member-gfhttpresponse-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`get_header`](#member-gfhttpresponse-methods-get_header) | `func get_header(header_name: String, default_value: String = "") -> String:` |
| 方法 | [`get_header_values`](#member-gfhttpresponse-methods-get_header_values) | `func get_header_values(header_name: String) -> PackedStringArray:` |
| 方法 | [`get_headers_dictionary`](#member-gfhttpresponse-methods-get_headers_dictionary) | `func get_headers_dictionary() -> Dictionary:` |
| 方法 | [`complete_success`](#member-gfhttpresponse-methods-complete_success) | `func complete_success(fields: Dictionary = {}) -> void:` |
| 方法 | [`complete_failure`](#member-gfhttpresponse-methods-complete_failure) | `func complete_failure(message: String, fields: Dictionary = {}) -> void:` |
| 方法 | [`cancel`](#member-gfhttpresponse-methods-cancel) | `func cancel(reason: String = "cancelled") -> void:` |
| 方法 | [`to_dictionary`](#member-gfhttpresponse-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 信号

<a id="member-gfhttpresponse-signals-completed"></a>

### `completed`

- API：`public`

```gdscript
signal completed(response: GFHttpResponse)
```

响应完成、失败或取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `response` | 当前响应对象。 |

## 枚举

<a id="member-gfhttpresponse-enums-state"></a>

### `State`

- API：`public`

```gdscript
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
```

HTTP 响应句柄状态。

## 属性

<a id="member-gfhttpresponse-properties-state"></a>

### `state`

- API：`public`

```gdscript
var state: State = State.PENDING
```

响应状态。

<a id="member-gfhttpresponse-properties-url"></a>

### `url`

- API：`public`

```gdscript
var url: String = ""
```

原始 URL。

<a id="member-gfhttpresponse-properties-status_code"></a>

### `status_code`

- API：`public`

```gdscript
var status_code: int = 0
```

HTTP 状态码。

<a id="member-gfhttpresponse-properties-result_code"></a>

### `result_code`

- API：`public`

```gdscript
var result_code: int = HTTPRequest.RESULT_SUCCESS
```

Godot HTTPRequest 结果码。

<a id="member-gfhttpresponse-properties-headers"></a>

### `headers`

- API：`public`

```gdscript
var headers: PackedStringArray = PackedStringArray()
```

响应头。

<a id="member-gfhttpresponse-properties-text"></a>

### `text`

- API：`public`

```gdscript
var text: String = ""
```

响应文本。

<a id="member-gfhttpresponse-properties-body"></a>

### `body`

- API：`public`

```gdscript
var body: PackedByteArray = PackedByteArray()
```

响应原始 bytes。

<a id="member-gfhttpresponse-properties-data"></a>

### `data`

- API：`public`

```gdscript
var data: Variant = null
```

解析后的数据，例如 JSON 结果。

结构：

- `data`: Variant，解析后的响应载荷，例如 JSON 数据、文本数据或 null。

<a id="member-gfhttpresponse-properties-error"></a>

### `error`

- API：`public`

```gdscript
var error: String = ""
```

错误说明。

<a id="member-gfhttpresponse-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary，从请求构建器复制的调用方元数据。

<a id="member-gfhttpresponse-properties-cancel_callback"></a>

### `cancel_callback`

- API：`public`

```gdscript
var cancel_callback: Callable = Callable()
```

取消请求时执行的底层取消回调。

## 方法

<a id="member-gfhttpresponse-methods-is_pending"></a>

### `is_pending`

- API：`public`

```gdscript
func is_pending() -> bool:
```

请求是否仍在等待。

返回：仍在等待时返回 true。

<a id="member-gfhttpresponse-methods-is_successful"></a>

### `is_successful`

- API：`public`

```gdscript
func is_successful() -> bool:
```

请求是否成功。

返回：请求以 2xx HTTP 状态码完成且没有错误时返回 true。

<a id="member-gfhttpresponse-methods-is_finished"></a>

### `is_finished`

- API：`public`

```gdscript
func is_finished() -> bool:
```

请求是否已结束。

返回：请求完成、失败或取消时返回 true。

<a id="member-gfhttpresponse-methods-get_header"></a>

### `get_header`

- API：`public`

```gdscript
func get_header(header_name: String, default_value: String = "") -> String:
```

读取第一个匹配的响应头。

参数：

| 名称 | 说明 |
|---|---|
| `header_name` | 响应头名称，按大小写不敏感方式匹配。 |
| `default_value` | 没有匹配响应头时返回的默认值。 |

返回：响应头值；没有匹配项时返回 default_value。

<a id="member-gfhttpresponse-methods-get_header_values"></a>

### `get_header_values`

- API：`public`

```gdscript
func get_header_values(header_name: String) -> PackedStringArray:
```

读取所有匹配的响应头值。

参数：

| 名称 | 说明 |
|---|---|
| `header_name` | 响应头名称，按大小写不敏感方式匹配。 |

返回：匹配的响应头值列表，保留原始出现顺序。

<a id="member-gfhttpresponse-methods-get_headers_dictionary"></a>

### `get_headers_dictionary`

- API：`public`

```gdscript
func get_headers_dictionary() -> Dictionary:
```

生成大小写规范化的响应头字典。

返回：响应头字典。

结构：

- `return`: Dictionary，键为小写 header 名称，值为 PackedStringArray，重复响应头会按出现顺序保留。

<a id="member-gfhttpresponse-methods-complete_success"></a>

### `complete_success`

- API：`public`

```gdscript
func complete_success(fields: Dictionary = {}) -> void:
```

标记请求成功完成。

参数：

| 名称 | 说明 |
|---|---|
| `fields` | 需要写入响应对象的字段。 |

结构：

- `fields`: Dictionary，可包含 url、status_code、result_code、headers、text、body、data 和 metadata。

<a id="member-gfhttpresponse-methods-complete_failure"></a>

### `complete_failure`

- API：`public`

```gdscript
func complete_failure(message: String, fields: Dictionary = {}) -> void:
```

标记请求失败。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 错误说明。 |
| `fields` | 需要写入响应对象的字段。 |

结构：

- `fields`: Dictionary，可包含 url、status_code、result_code、headers、text、body、data 和 metadata。

<a id="member-gfhttpresponse-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel(reason: String = "cancelled") -> void:
```

取消请求。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

<a id="member-gfhttpresponse-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转为普通字典。

返回：响应快照。

结构：

- `return`: Dictionary，包含响应状态、URL、HTTP 状态、解析数据、错误信息和 metadata。
