# GFAnalyticsUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/analytics/gf_analytics_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用事件分析与批量上报工具。 负责事件排队、环境上下文采集、批量 flush 与失败重排。 endpoint 为空时不会访问网络，可作为本地事件汇聚或测试通道使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`event_tracked`](#member-gfanalyticsutility-signals-event_tracked) | `signal event_tracked(event_name: StringName, event_data: Dictionary)` |
| 信号 | [`flush_started`](#member-gfanalyticsutility-signals-flush_started) | `signal flush_started(batch: Array)` |
| 信号 | [`flush_completed`](#member-gfanalyticsutility-signals-flush_completed) | `signal flush_completed(result: Dictionary)` |
| 信号 | [`flush_failed`](#member-gfanalyticsutility-signals-flush_failed) | `signal flush_failed(result: Dictionary)` |
| 属性 | [`config`](#member-gfanalyticsutility-properties-config) | `var config: GFAnalyticsConfig = GFAnalyticsConfig.new()` |
| 属性 | [`payload_builder`](#member-gfanalyticsutility-properties-payload_builder) | `var payload_builder: Callable = Callable()` |
| 属性 | [`transport_callback`](#member-gfanalyticsutility-properties-transport_callback) | `var transport_callback: Callable = Callable()` |
| 属性 | [`response_parser`](#member-gfanalyticsutility-properties-response_parser) | `var response_parser: Callable = Callable()` |
| 方法 | [`init`](#member-gfanalyticsutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfanalyticsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfanalyticsutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`configure`](#member-gfanalyticsutility-methods-configure) | `func configure(analytics_config: GFAnalyticsConfig) -> void:` |
| 方法 | [`identify`](#member-gfanalyticsutility-methods-identify) | `func identify(client_id: String) -> void:` |
| 方法 | [`track`](#member-gfanalyticsutility-methods-track) | `func track(event_name: StringName, properties: Dictionary = {}) -> void:` |
| 方法 | [`flush`](#member-gfanalyticsutility-methods-flush) | `func flush() -> void:` |
| 方法 | [`shutdown`](#member-gfanalyticsutility-methods-shutdown) | `func shutdown(flush_remaining: bool = true) -> void:` |
| 方法 | [`get_queue_size`](#member-gfanalyticsutility-methods-get_queue_size) | `func get_queue_size() -> int:` |
| 方法 | [`get_session_id`](#member-gfanalyticsutility-methods-get_session_id) | `func get_session_id() -> String:` |
| 方法 | [`get_client_id`](#member-gfanalyticsutility-methods-get_client_id) | `func get_client_id() -> String:` |
| 方法 | [`clear_queue`](#member-gfanalyticsutility-methods-clear_queue) | `func clear_queue() -> void:` |
| 方法 | [`capture_context`](#member-gfanalyticsutility-methods-capture_context) | `func capture_context() -> Dictionary:` |

## 信号

<a id="member-gfanalyticsutility-signals-event_tracked"></a>

### `event_tracked`

- API：`public`

```gdscript
signal event_tracked(event_name: StringName, event_data: Dictionary)
```

事件进入队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 事件名。 |
| `event_data` | 已入队事件数据。 |

结构：

- `event_data`: Dictionary with `event`, `client_id`, `session_id`, `timestamp`, `properties`, and optional `context`.

<a id="member-gfanalyticsutility-signals-flush_started"></a>

### `flush_started`

- API：`public`

```gdscript
signal flush_started(batch: Array)
```

开始 flush 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `batch` | 本次 flush 的事件批次。 |

结构：

- `batch`: Array[Dictionary] of queued analytics events.

<a id="member-gfanalyticsutility-signals-flush_completed"></a>

### `flush_completed`

- API：`public`

```gdscript
signal flush_completed(result: Dictionary)
```

flush 完成时发出。失败结果也会通过该信号通知。

参数：

| 名称 | 说明 |
|---|---|
| `result` | flush 结果。 |

结构：

- `result`: Dictionary with at least `success: bool`; may include `accepted`, `error`, `dry_run`, or transport-specific fields.

<a id="member-gfanalyticsutility-signals-flush_failed"></a>

### `flush_failed`

- API：`public`

```gdscript
signal flush_failed(result: Dictionary)
```

flush 失败时额外发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 失败结果。 |

结构：

- `result`: Dictionary with `success: false` and an optional `error` field.

## 属性

<a id="member-gfanalyticsutility-properties-config"></a>

### `config`

- API：`public`

```gdscript
var config: GFAnalyticsConfig = GFAnalyticsConfig.new()
```

当前配置。

<a id="member-gfanalyticsutility-properties-payload_builder"></a>

### `payload_builder`

- API：`public`

```gdscript
var payload_builder: Callable = Callable()
```

可选载荷构建回调。签名为 func(batch: Array) -> Dictionary。

<a id="member-gfanalyticsutility-properties-transport_callback"></a>

### `transport_callback`

- API：`public`

```gdscript
var transport_callback: Callable = Callable()
```

可选自定义传输回调。签名为 func(payload: Dictionary) -> Dictionary。

<a id="member-gfanalyticsutility-properties-response_parser"></a>

### `response_parser`

- API：`public`

```gdscript
var response_parser: Callable = Callable()
```

可选响应解析回调。签名为 func(response_code: int, body: PackedByteArray, fallback_accepted: int) -> Dictionary。

## 方法

<a id="member-gfanalyticsutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化事件队列、会话 ID 和关闭监听。

<a id="member-gfanalyticsutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放事件队列、HTTP 节点和关闭监听。

<a id="member-gfanalyticsutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfanalyticsutility-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(analytics_config: GFAnalyticsConfig) -> void:
```

替换分析配置。

参数：

| 名称 | 说明 |
|---|---|
| `analytics_config` | 新配置。 |

<a id="member-gfanalyticsutility-methods-identify"></a>

### `identify`

- API：`public`

```gdscript
func identify(client_id: String) -> void:
```

设置稳定客户端标识。

参数：

| 名称 | 说明 |
|---|---|
| `client_id` | 客户端标识。 |

<a id="member-gfanalyticsutility-methods-track"></a>

### `track`

- API：`public`

```gdscript
func track(event_name: StringName, properties: Dictionary = {}) -> void:
```

记录一个事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 事件名。 |
| `properties` | 事件属性。 |

结构：

- `properties`: Dictionary[String, Variant] copied into the queued event properties.

<a id="member-gfanalyticsutility-methods-flush"></a>

### `flush`

- API：`public`

```gdscript
func flush() -> void:
```

立即上报一批事件。

<a id="member-gfanalyticsutility-methods-shutdown"></a>

### `shutdown`

- API：`public`

```gdscript
func shutdown(flush_remaining: bool = true) -> void:
```

停止继续接收事件，并可选 flush 当前队列。

参数：

| 名称 | 说明 |
|---|---|
| `flush_remaining` | 是否尝试 flush 剩余事件。 |

<a id="member-gfanalyticsutility-methods-get_queue_size"></a>

### `get_queue_size`

- API：`public`

```gdscript
func get_queue_size() -> int:
```

获取当前队列长度。

返回：队列长度。

<a id="member-gfanalyticsutility-methods-get_session_id"></a>

### `get_session_id`

- API：`public`

```gdscript
func get_session_id() -> String:
```

获取当前会话标识。

返回：会话标识。

<a id="member-gfanalyticsutility-methods-get_client_id"></a>

### `get_client_id`

- API：`public`

```gdscript
func get_client_id() -> String:
```

获取当前客户端标识。

返回：客户端标识。

<a id="member-gfanalyticsutility-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue() -> void:
```

清空本地事件队列。

<a id="member-gfanalyticsutility-methods-capture_context"></a>

### `capture_context`

- API：`public`

```gdscript
func capture_context() -> Dictionary:
```

采集通用运行环境上下文。

返回：上下文字典。

结构：

- `return`: Dictionary with platform, engine, engine_version, screen size, locale, and timezone fields.
