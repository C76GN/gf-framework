# GFHttpClientUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_http_client_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.1.0`

有界并发 HTTPRequest 客户端池。 负责复制请求快照、限制并发和等待队列、复用 HTTPRequest worker， 并把排队、活动、取消和释放统一收敛到 GFHttpResponse。 不内置远端服务、鉴权、重试、分页或业务 DTO。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`request_queued`](#member-gfhttpclientutility-signals-request_queued) | `signal request_queued(response: GFHttpResponse)` |
| 信号 | [`request_started`](#member-gfhttpclientutility-signals-request_started) | `signal request_started(response: GFHttpResponse)` |
| 常量 | [`DEFAULT_MAX_RESPONSE_BYTES`](#member-gfhttpclientutility-constants-default_max_response_bytes) | `const DEFAULT_MAX_RESPONSE_BYTES: int = 16 * 1024 * 1024` |
| 方法 | [`init`](#member-gfhttpclientutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfhttpclientutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfhttpclientutility-methods-configure) | `func configure( max_concurrent_requests: int = 4, max_pending_requests: int = 256, request_parent: Node = null, default_max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES ) -> void:` |
| 方法 | [`execute`](#member-gfhttpclientutility-methods-execute) | `func execute(builder: GFHttpRequestBuilder) -> GFHttpResponse:` |
| 方法 | [`cancel_all`](#member-gfhttpclientutility-methods-cancel_all) | `func cancel_all(reason: String = "cancelled") -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfhttpclientutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_start_request`](#member-gfhttpclientutility-methods-_start_request) | `func _start_request( worker: HTTPRequest, builder: GFHttpRequestBuilder, response: GFHttpResponse ) -> Error:` |
| 方法 | [`_complete_request`](#member-gfhttpclientutility-methods-_complete_request) | `func _complete_request( worker: HTTPRequest, builder: GFHttpRequestBuilder, response: GFHttpResponse, result_code: int, status_code: int, response_headers: PackedStringArray, body: PackedByteArray ) -> void:` |

## 信号

<a id="member-gfhttpclientutility-signals-request_queued"></a>

### `request_queued`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
signal request_queued(response: GFHttpResponse)
```

请求进入等待队列后发出。

参数：

| 名称 | 说明 |
|---|---|
| `response` | 请求响应句柄。 |

<a id="member-gfhttpclientutility-signals-request_started"></a>

### `request_started`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
signal request_started(response: GFHttpResponse)
```

请求取得 worker 并开始执行后发出。

参数：

| 名称 | 说明 |
|---|---|
| `response` | 请求响应句柄。 |

## 常量

<a id="member-gfhttpclientutility-constants-default_max_response_bytes"></a>

### `DEFAULT_MAX_RESPONSE_BYTES`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
const DEFAULT_MAX_RESPONSE_BYTES: int = 16 * 1024 * 1024
```

客户端池继承请求预算时使用的默认单响应上限。

## 方法

<a id="member-gfhttpclientutility-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func init() -> void:
```

激活客户端池。重复调用不会重置正在执行的请求。

<a id="member-gfhttpclientutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func dispose() -> void:
```

取消所有请求并释放池中的 HTTPRequest worker。

<a id="member-gfhttpclientutility-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func configure( max_concurrent_requests: int = 4, max_pending_requests: int = 256, request_parent: Node = null, default_max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES ) -> void:
```

配置并发、等待队列预算和可选请求节点父级。

参数：

| 名称 | 说明 |
|---|---|
| `max_concurrent_requests` | 同时活动的最大请求数，最小为 1。 |
| `max_pending_requests` | 等待 worker 的最大请求数，可为 0。 |
| `request_parent` | worker 挂载父节点；为空时使用 SceneTree.root。 |
| `default_max_response_bytes` | builder 选择继承传输预算时采用的上限；-1 表示无限制。 |

<a id="member-gfhttpclientutility-methods-execute"></a>

### `execute`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func execute(builder: GFHttpRequestBuilder) -> GFHttpResponse:
```

提交一个 HTTP 请求。

参数：

| 名称 | 说明 |
|---|---|
| `builder` | 请求构建器；客户端会立即复制其状态。 |

返回：可观察和取消的响应句柄。

<a id="member-gfhttpclientutility-methods-cancel_all"></a>

### `cancel_all`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func cancel_all(reason: String = "cancelled") -> void:
```

取消所有活动和排队请求，但保留 worker 供后续复用。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 写入响应句柄的取消原因。 |

<a id="member-gfhttpclientutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取客户端池诊断快照。

返回：池状态和容量计数。

结构：

- `return`: Dictionary，包含 active、max_concurrent_requests、max_pending_requests、default_max_response_bytes、active_count、pending_count、idle_worker_count 和 worker_count。

<a id="member-gfhttpclientutility-methods-_start_request"></a>

### `_start_request`

- API：`protected`
- 首次版本：`8.1.0`

```gdscript
func _start_request( worker: HTTPRequest, builder: GFHttpRequestBuilder, response: GFHttpResponse ) -> Error:
```

使用指定 worker 启动请求。子类可替换该入口以接入可控测试传输。

参数：

| 名称 | 说明 |
|---|---|
| `worker` | 当前请求独占的 HTTPRequest worker。 |
| `builder` | 不再被调用方修改的请求快照。 |
| `response` | 当前响应句柄。 |

返回：Godot 请求启动错误码。

<a id="member-gfhttpclientutility-methods-_complete_request"></a>

### `_complete_request`

- API：`protected`
- 首次版本：`8.1.0`

```gdscript
func _complete_request( worker: HTTPRequest, builder: GFHttpRequestBuilder, response: GFHttpResponse, result_code: int, status_code: int, response_headers: PackedStringArray, body: PackedByteArray ) -> void:
```

完成当前 worker 对应的请求并将 worker 归还池。

参数：

| 名称 | 说明 |
|---|---|
| `worker` | 完成请求的 worker。 |
| `builder` | 请求快照。 |
| `response` | 响应句柄。 |
| `result_code` | Godot HTTPRequest 结果码。 |
| `status_code` | HTTP 状态码。 |
| `response_headers` | 原始响应头。 |
| `body` | 原始响应体。 |
