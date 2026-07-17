# GFRequestEnvelope

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_request_envelope.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

通用可重放请求描述。 只保存请求方法、地址、载荷、Header、重试与元数据，不绑定具体服务端、 账号、鉴权或业务协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`request_id`](#member-gfrequestenvelope-properties-request_id) | `var request_id: StringName = &""` |
| 属性 | [`method`](#member-gfrequestenvelope-properties-method) | `var method: int = HTTPClient.METHOD_GET` |
| 属性 | [`url`](#member-gfrequestenvelope-properties-url) | `var url: String = ""` |
| 属性 | [`body`](#member-gfrequestenvelope-properties-body) | `var body: Dictionary = {}` |
| 属性 | [`headers`](#member-gfrequestenvelope-properties-headers) | `var headers: PackedStringArray = PackedStringArray()` |
| 属性 | [`idempotency_key`](#member-gfrequestenvelope-properties-idempotency_key) | `var idempotency_key: String = ""` |
| 属性 | [`created_at_unix`](#member-gfrequestenvelope-properties-created_at_unix) | `var created_at_unix: int = 0` |
| 属性 | [`attempt_count`](#member-gfrequestenvelope-properties-attempt_count) | `var attempt_count: int = 0` |
| 属性 | [`max_attempts`](#member-gfrequestenvelope-properties-max_attempts) | `var max_attempts: int = 3` |
| 属性 | [`next_attempt_at_unix_msec`](#member-gfrequestenvelope-properties-next_attempt_at_unix_msec) | `var next_attempt_at_unix_msec: int = 0` |
| 属性 | [`last_error`](#member-gfrequestenvelope-properties-last_error) | `var last_error: String = ""` |
| 属性 | [`metadata`](#member-gfrequestenvelope-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfrequestenvelope-methods-configure) | `func configure( p_method: int, p_url: String, p_body: Dictionary = {}, p_headers: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFRequestEnvelope:` |
| 方法 | [`is_valid`](#member-gfrequestenvelope-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`can_attempt`](#member-gfrequestenvelope-methods-can_attempt) | `func can_attempt(now_unix_msec: int = -1) -> bool:` |
| 方法 | [`is_exhausted`](#member-gfrequestenvelope-methods-is_exhausted) | `func is_exhausted() -> bool:` |
| 方法 | [`mark_attempt`](#member-gfrequestenvelope-methods-mark_attempt) | `func mark_attempt() -> void:` |
| 方法 | [`mark_failure`](#member-gfrequestenvelope-methods-mark_failure) | `func mark_failure( error: String, retry_delay_msec: int = 0, now_unix_msec: int = -1 ) -> void:` |
| 方法 | [`mark_success`](#member-gfrequestenvelope-methods-mark_success) | `func mark_success() -> void:` |
| 方法 | [`duplicate_request`](#member-gfrequestenvelope-methods-duplicate_request) | `func duplicate_request() -> GFRequestEnvelope:` |
| 方法 | [`to_dict`](#member-gfrequestenvelope-methods-to_dict) | `func to_dict(json_compatible: bool = false) -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfrequestenvelope-methods-apply_dict) | `func apply_dict(data: Dictionary, json_compatible: bool = false) -> void:` |
| 方法 | [`get_method_name`](#member-gfrequestenvelope-methods-get_method_name) | `func get_method_name() -> String:` |
| 方法 | [`from_dict`](#member-gfrequestenvelope-methods-from_dict) | `static func from_dict(data: Dictionary, json_compatible: bool = false) -> GFRequestEnvelope:` |

## 属性

<a id="member-gfrequestenvelope-properties-request_id"></a>

### `request_id`

- API：`public`

```gdscript
var request_id: StringName = &""
```

请求稳定标识；为空时由 Outbox 入队时生成。

<a id="member-gfrequestenvelope-properties-method"></a>

### `method`

- API：`public`

```gdscript
var method: int = HTTPClient.METHOD_GET
```

HTTPClient.Method 数值。即使传输层不是 HTTP，也可把它当作通用动作类型使用。

<a id="member-gfrequestenvelope-properties-url"></a>

### `url`

- API：`public`

```gdscript
var url: String = ""
```

请求目标地址或项目自定义端点。

<a id="member-gfrequestenvelope-properties-body"></a>

### `body`

- API：`public`

```gdscript
var body: Dictionary = {}
```

请求载荷。框架不解释字段含义。

结构：

- `body`: Dictionary，项目传输层持有的请求载荷。

<a id="member-gfrequestenvelope-properties-headers"></a>

### `headers`

- API：`public`

```gdscript
var headers: PackedStringArray = PackedStringArray()
```

请求 Header，使用 Godot HTTPRequest 兼容的 `Name: Value` 字符串格式。

<a id="member-gfrequestenvelope-properties-idempotency_key"></a>

### `idempotency_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var idempotency_key: String = ""
```

幂等键；直接创建时可为空，进入 GFRequestOutboxUtility 时会用 request_id 补齐。

<a id="member-gfrequestenvelope-properties-created_at_unix"></a>

### `created_at_unix`

- API：`public`

```gdscript
var created_at_unix: int = 0
```

创建时间，Unix 秒。

<a id="member-gfrequestenvelope-properties-attempt_count"></a>

### `attempt_count`

- API：`public`

```gdscript
var attempt_count: int = 0
```

已尝试次数。

<a id="member-gfrequestenvelope-properties-max_attempts"></a>

### `max_attempts`

- API：`public`

```gdscript
var max_attempts: int = 3
```

最大尝试次数；小于等于 0 表示不限制。

<a id="member-gfrequestenvelope-properties-next_attempt_at_unix_msec"></a>

### `next_attempt_at_unix_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var next_attempt_at_unix_msec: int = 0
```

下一次允许重试的 Unix 毫秒时间戳；可跨进程重启持久化。

<a id="member-gfrequestenvelope-properties-last_error"></a>

### `last_error`

- API：`public`

```gdscript
var last_error: String = ""
```

最近一次失败原因。

<a id="member-gfrequestenvelope-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，随请求持久化的项目侧元数据。

## 方法

<a id="member-gfrequestenvelope-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_method: int, p_url: String, p_body: Dictionary = {}, p_headers: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFRequestEnvelope:
```

配置请求并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_method` | HTTPClient.Method 数值。 |
| `p_url` | 请求目标地址或项目自定义端点。 |
| `p_body` | 请求载荷。 |
| `p_headers` | 请求 Header。 |
| `p_metadata` | 项目自定义元数据。 |

返回：当前请求描述。

结构：

- `p_body`: Dictionary，项目传输层持有的请求载荷。
- `p_metadata`: Dictionary，随请求持久化的项目侧元数据。

<a id="member-gfrequestenvelope-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
func is_valid() -> bool:
```

检查请求是否具备最小有效信息。

返回：有效时返回 true。

<a id="member-gfrequestenvelope-methods-can_attempt"></a>

### `can_attempt`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func can_attempt(now_unix_msec: int = -1) -> bool:
```

检查当前时刻是否允许再次尝试。

参数：

| 名称 | 说明 |
|---|---|
| `now_unix_msec` | 当前 Unix 毫秒时间戳；小于 0 时自动读取系统时间。 |

返回：可尝试时返回 true。

<a id="member-gfrequestenvelope-methods-is_exhausted"></a>

### `is_exhausted`

- API：`public`

```gdscript
func is_exhausted() -> bool:
```

检查是否已耗尽尝试次数。

返回：已耗尽时返回 true。

<a id="member-gfrequestenvelope-methods-mark_attempt"></a>

### `mark_attempt`

- API：`public`

```gdscript
func mark_attempt() -> void:
```

记录一次发送尝试。

<a id="member-gfrequestenvelope-methods-mark_failure"></a>

### `mark_failure`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func mark_failure( error: String, retry_delay_msec: int = 0, now_unix_msec: int = -1 ) -> void:
```

记录失败并安排下一次重试。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 失败原因。 |
| `retry_delay_msec` | 从现在起等待多少毫秒后可重试。 |
| `now_unix_msec` | 当前 Unix 毫秒时间戳；小于 0 时自动读取系统时间。 |

<a id="member-gfrequestenvelope-methods-mark_success"></a>

### `mark_success`

- API：`public`

```gdscript
func mark_success() -> void:
```

记录成功状态。

<a id="member-gfrequestenvelope-methods-duplicate_request"></a>

### `duplicate_request`

- API：`public`

```gdscript
func duplicate_request() -> GFRequestEnvelope:
```

复制请求描述。

返回：新请求描述。

<a id="member-gfrequestenvelope-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func to_dict(json_compatible: bool = false) -> Dictionary:
```

转为字典。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时会把载荷与元数据转换为 JSON 兼容值。 |

返回：请求字典。

结构：

- `return`: Dictionary，包含 request_id、method、method_name、url、body、headers、idempotency_key、created_at_unix、attempt_count、max_attempts、next_attempt_at_unix_msec、last_error 和 metadata。

<a id="member-gfrequestenvelope-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func apply_dict(data: Dictionary, json_compatible: bool = false) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 请求字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

结构：

- `data`: Dictionary，包含 request_id、method、url、body、headers、idempotency_key、created_at_unix、attempt_count、max_attempts、next_attempt_at_unix_msec、last_error 和 metadata。

<a id="member-gfrequestenvelope-methods-get_method_name"></a>

### `get_method_name`

- API：`public`

```gdscript
func get_method_name() -> String:
```

获取方法名称。

返回：方法名称。

<a id="member-gfrequestenvelope-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func from_dict(data: Dictionary, json_compatible: bool = false) -> GFRequestEnvelope:
```

从字典创建请求描述。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 请求字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

返回：请求描述。

结构：

- `data`: Dictionary，包含 request_id、method、url、body、headers、idempotency_key、created_at_unix、attempt_count、max_attempts、next_attempt_at_unix_msec、last_error 和 metadata。
