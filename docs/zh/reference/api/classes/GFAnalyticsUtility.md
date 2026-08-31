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
| 属性 | [`config`](#member-gfanalyticsutility-properties-config) | `var config: GFAnalyticsConfig:` |
| 属性 | [`schema_registry`](#member-gfanalyticsutility-properties-schema_registry) | `var schema_registry: GFAnalyticsSchemaRegistry:` |
| 属性 | [`payload_builder`](#member-gfanalyticsutility-properties-payload_builder) | `var payload_builder: Callable = Callable()` |
| 属性 | [`transport_callback`](#member-gfanalyticsutility-properties-transport_callback) | `var transport_callback: Callable = Callable()` |
| 属性 | [`response_parser`](#member-gfanalyticsutility-properties-response_parser) | `var response_parser: Callable = Callable()` |
| 方法 | [`init`](#member-gfanalyticsutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfanalyticsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfanalyticsutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`configure`](#member-gfanalyticsutility-methods-configure) | `func configure(analytics_config: GFAnalyticsConfig) -> void:` |
| 方法 | [`identify`](#member-gfanalyticsutility-methods-identify) | `func identify(client_id: String) -> void:` |
| 方法 | [`track`](#member-gfanalyticsutility-methods-track) | `func track(event_name: StringName, properties: Dictionary = {}) -> void:` |
| 方法 | [`track_versioned`](#member-gfanalyticsutility-methods-track_versioned) | `func track_versioned( event_name: StringName, schema_version: int, properties: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`flush`](#member-gfanalyticsutility-methods-flush) | `func flush() -> void:` |
| 方法 | [`shutdown`](#member-gfanalyticsutility-methods-shutdown) | `func shutdown(flush_remaining: bool = true) -> void:` |
| 方法 | [`get_queue_size`](#member-gfanalyticsutility-methods-get_queue_size) | `func get_queue_size() -> int:` |
| 方法 | [`get_dropped_event_count`](#member-gfanalyticsutility-methods-get_dropped_event_count) | `func get_dropped_event_count() -> int:` |
| 方法 | [`get_session_id`](#member-gfanalyticsutility-methods-get_session_id) | `func get_session_id() -> String:` |
| 方法 | [`get_client_id`](#member-gfanalyticsutility-methods-get_client_id) | `func get_client_id() -> String:` |
| 方法 | [`clear_queue`](#member-gfanalyticsutility-methods-clear_queue) | `func clear_queue() -> void:` |
| 方法 | [`capture_context`](#member-gfanalyticsutility-methods-capture_context) | `func capture_context() -> Dictionary:` |

## 信号

<a id="member-gfanalyticsutility-signals-event_tracked"></a>

### `event_tracked`

- API：`public`
- 首次版本：`3.17.0`

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

- `event_data`: Dictionary with `event`, `client_id`, `session_id`, `timestamp`, `properties`, optional `context`, and for versioned events `event_id` plus `schema_version`.

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
- 首次版本：`3.17.0`

```gdscript
signal flush_completed(result: Dictionary)
```

flush 完成时发出。失败结果也会通过该信号通知。

参数：

| 名称 | 说明 |
|---|---|
| `result` | flush 结果。 |

结构：

- `result`: Dictionary with `success`; may include `accepted`, `error`, `response_code`, `dry_run`, `dropped`, `retained`, `drop_reason`, or transport-specific fields.

<a id="member-gfanalyticsutility-signals-flush_failed"></a>

### `flush_failed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal flush_failed(result: Dictionary)
```

flush 失败时额外发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 失败结果。 |

结构：

- `result`: Dictionary with `success: false`; may include `error`, `response_code`, `dropped`, `retained`, `drop_reason`, and payload budget fields.

## 属性

<a id="member-gfanalyticsutility-properties-config"></a>

### `config`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var config: GFAnalyticsConfig:
```

当前配置。

<a id="member-gfanalyticsutility-properties-schema_registry"></a>

### `schema_registry`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var schema_registry: GFAnalyticsSchemaRegistry:
```

版本化事件 Schema 注册表。 注册表始终可用；赋值 null 会恢复为空注册表。Schema 只约束编码前的 properties， 不替代最终 JSON-safe 载荷预算或项目侧隐私、同意与业务策略。

<a id="member-gfanalyticsutility-properties-payload_builder"></a>

### `payload_builder`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload_builder: Callable = Callable()
```

可选载荷信封构建回调。签名为 func(batch: Array) -> Dictionary。 batch 是隔离副本；返回值中的 events 会被忽略，以保持已编码事件批次的完整性。 flush 按最终信封字节预算从最大前缀向下有界校验时可能多次调用该回调，因此实现必须 无副作用且结果确定；若评估工作预算耗尽，完整队列会保留并报告 planner_budget_exceeded。

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
- 首次版本：`3.17.0`

```gdscript
func dispose() -> void:
```

释放事件队列、HTTP 节点、关闭监听和项目注入的回调。

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
- 首次版本：`8.0.0`

```gdscript
func identify(client_id: String) -> void:
```

设置稳定客户端标识。

参数：

| 名称 | 说明 |
|---|---|
| `client_id` | 1..4096 字符且不含 C0/DEL 控制字符的客户端标识；非法值会被拒绝并保留原标识。 |

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

<a id="member-gfanalyticsutility-methods-track_versioned"></a>

### `track_versioned`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func track_versioned( event_name: StringName, schema_version: int, properties: Dictionary = {} ) -> Dictionary:
```

按精确 Schema 版本记录事件。 该入口在 JSON-safe 编码前执行有界输入校验；不会回退到其他版本，也不会自动迁移 旧事件。成功只表示事件已被 Analytics 接受，自动 flush 可能已同步完成或失败回灌。

参数：

| 名称 | 说明 |
|---|---|
| `event_name` | 已注册的事件名。 |
| `schema_version` | 已注册且位于 1..2_147_483_647 的 Schema 版本。 |
| `properties` | 编码前的事件属性。 |

返回：结构化记录结果。

结构：

- `properties`: Dictionary[String, Variant] validated against the exact registered analytics input schema.
- `return`: Dictionary with ok, accepted, reason, event_name, schema_version, event_id, and validation.

<a id="member-gfanalyticsutility-methods-flush"></a>

### `flush`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func flush() -> void:
```

立即上报最终信封字节预算内的最大事件前缀。 Planner 不假设 payload_builder 的大小随批次单调变化，而是从最大候选前缀向下 有界校验。评估次数或累计编码工作达到预算时，会通过 flush_failed 和 flush_completed 返回 retained=true、dropped=false、drop_reason=planner_budget_exceeded， 并保持完整队列；调用方应降低 batch_size 或简化 payload_builder 后再重试。只有已经 证明单个事件无法放入最终信封时，才会以 dropped=true 明确丢弃。

<a id="member-gfanalyticsutility-methods-shutdown"></a>

### `shutdown`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func shutdown(flush_remaining: bool = true) -> void:
```

停止继续接收事件，并可选进入 draining 状态直到队列完成或某一批明确失败。

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

<a id="member-gfanalyticsutility-methods-get_dropped_event_count"></a>

### `get_dropped_event_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_dropped_event_count() -> int:
```

获取因队列或载荷预算而丢弃的累计事件数。

返回：当前实例初始化以来的累计丢弃数量。

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
