# GFAnalyticsOutboxAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_analytics_outbox_adapter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

Analytics 批次到通用请求 Outbox 的有界持久交接适配器。 把 GFAnalyticsUtility 的 JSON-safe events 封装为固定、版本化的中立请求信封， 并在确认 GFRequestOutboxUtility 已可靠持久化后才接受整批事件。适配器不接管 Outbox 的 transport_callback 或 replay_filter，也不持久化鉴权 Header；项目应在 实际重放时根据当前会话动态注入鉴权、同意与供应商协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCHEMA_ID`](#member-gfanalyticsoutboxadapter-constants-schema_id) | `const SCHEMA_ID: StringName = &"gf.analytics.outbox"` |
| 常量 | [`PROTOCOL_VERSION`](#member-gfanalyticsoutboxadapter-constants-protocol_version) | `const PROTOCOL_VERSION: int = 1` |
| 常量 | [`DEFAULT_ENDPOINT_URL`](#member-gfanalyticsoutboxadapter-constants-default_endpoint_url) | `const DEFAULT_ENDPOINT_URL: String = "gf://analytics/events"` |
| 属性 | [`outbox`](#member-gfanalyticsoutboxadapter-properties-outbox) | `var outbox: GFRequestOutboxUtility = null` |
| 属性 | [`endpoint_url`](#member-gfanalyticsoutboxadapter-properties-endpoint_url) | `var endpoint_url: String = DEFAULT_ENDPOINT_URL` |
| 属性 | [`max_payload_bytes`](#member-gfanalyticsoutboxadapter-properties-max_payload_bytes) | `var max_payload_bytes: int = 256 * 1024:` |
| 属性 | [`max_events_per_request`](#member-gfanalyticsoutboxadapter-properties-max_events_per_request) | `var max_events_per_request: int = 500:` |
| 属性 | [`max_attempts`](#member-gfanalyticsoutboxadapter-properties-max_attempts) | `var max_attempts: int = 3:` |
| 属性 | [`max_depth`](#member-gfanalyticsoutboxadapter-properties-max_depth) | `var max_depth: int = 16:` |
| 属性 | [`max_collection_items`](#member-gfanalyticsoutboxadapter-properties-max_collection_items) | `var max_collection_items: int = 256:` |
| 属性 | [`max_string_length`](#member-gfanalyticsoutboxadapter-properties-max_string_length) | `var max_string_length: int = 4096:` |
| 属性 | [`max_total_nodes`](#member-gfanalyticsoutboxadapter-properties-max_total_nodes) | `var max_total_nodes: int = 8192:` |
| 方法 | [`configure`](#member-gfanalyticsoutboxadapter-methods-configure) | `func configure( p_outbox: GFRequestOutboxUtility, options: Dictionary = {} ) -> GFAnalyticsOutboxAdapter:` |
| 方法 | [`enqueue_payload`](#member-gfanalyticsoutboxadapter-methods-enqueue_payload) | `func enqueue_payload(payload: Dictionary) -> Dictionary:` |
| 方法 | [`handles_request`](#member-gfanalyticsoutboxadapter-methods-handles_request) | `func handles_request(envelope: GFRequestEnvelope) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfanalyticsoutboxadapter-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfanalyticsoutboxadapter-constants-schema_id"></a>

### `SCHEMA_ID`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const SCHEMA_ID: StringName = &"gf.analytics.outbox"
```

持久化批次协议标识。

<a id="member-gfanalyticsoutboxadapter-constants-protocol_version"></a>

### `PROTOCOL_VERSION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const PROTOCOL_VERSION: int = 1
```

持久化批次协议版本。

<a id="member-gfanalyticsoutboxadapter-constants-default_endpoint_url"></a>

### `DEFAULT_ENDPOINT_URL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_ENDPOINT_URL: String = "gf://analytics/events"
```

默认逻辑端点。它不是供应商 URL，也不包含账号或鉴权信息。

## 属性

<a id="member-gfanalyticsoutboxadapter-properties-outbox"></a>

### `outbox`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var outbox: GFRequestOutboxUtility = null
```

专用于 Analytics 的请求 Outbox。 建议使用独立实例和 `user://gf_analytics_outbox.json`，避免与其他业务共享单一 transport/filter 入口及存储生命周期。

<a id="member-gfanalyticsoutboxadapter-properties-endpoint_url"></a>

### `endpoint_url`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var endpoint_url: String = DEFAULT_ENDPOINT_URL
```

写入请求信封的非敏感逻辑端点。 该值会持久化并参与协议身份校验，不得包含 userinfo、凭据、query 或 fragment； 不得为空、超过 2048 字符或包含空白、控制字符。供应商路由和鉴权应由 replay transport 动态注入。

<a id="member-gfanalyticsoutboxadapter-properties-max_payload_bytes"></a>

### `max_payload_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_payload_bytes: int = 256 * 1024:
```

单个持久化批次的最终 JSON 字节上限；直接赋值会钳制到 1024..16 MiB。

<a id="member-gfanalyticsoutboxadapter-properties-max_events_per_request"></a>

### `max_events_per_request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_events_per_request: int = 500:
```

单个持久化批次的事件数量上限；直接赋值会钳制到 1..500。

<a id="member-gfanalyticsoutboxadapter-properties-max_attempts"></a>

### `max_attempts`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_attempts: int = 3:
```

请求重放最大尝试次数；直接赋值和 configure() 都会钳制到 1..64。

<a id="member-gfanalyticsoutboxadapter-properties-max_depth"></a>

### `max_depth`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_depth: int = 16:
```

单个事件嵌套深度上限；直接赋值会钳制到 1..32。

<a id="member-gfanalyticsoutboxadapter-properties-max_collection_items"></a>

### `max_collection_items`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_collection_items: int = 256:
```

单个嵌套集合的元素上限；直接赋值会钳制到 1..4096。

<a id="member-gfanalyticsoutboxadapter-properties-max_string_length"></a>

### `max_string_length`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_string_length: int = 4096:
```

单个字符串的字符上限；直接赋值会钳制到 1..65_536。

<a id="member-gfanalyticsoutboxadapter-properties-max_total_nodes"></a>

### `max_total_nodes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_total_nodes: int = 8192:
```

整批遍历的节点上限；直接赋值会钳制到 1..1_000_000。

## 方法

<a id="member-gfanalyticsoutboxadapter-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( p_outbox: GFRequestOutboxUtility, options: Dictionary = {} ) -> GFAnalyticsOutboxAdapter:
```

配置适配器。 本方法只保存 Outbox 引用和有界选项，不修改 Outbox 的 transport_callback、 replay_filter、storage_path 或生命周期。

参数：

| 名称 | 说明 |
|---|---|
| `p_outbox` | 项目配置并拥有生命周期的专用 Outbox。 |
| `options` | 可选 endpoint_url、max_payload_bytes、max_events_per_request、max_attempts、max_depth、max_collection_items、max_string_length 和 max_total_nodes。 |

返回：当前适配器。

结构：

- `options`: Dictionary of bounded adapter configuration overrides.

<a id="member-gfanalyticsoutboxadapter-methods-enqueue_payload"></a>

### `enqueue_payload`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func enqueue_payload(payload: Dictionary) -> Dictionary:
```

把 Analytics payload 可靠交接给 Outbox。 v1 采用整批成功或整批失败语义。版本化事件按有序 event_id 列表派生稳定 batch/idempotency identity；legacy 事件使用持久化在信封内的随机 batch identity。 精确匹配且尚可尝试的 pending 只有在重新保存并复核后才返回 already_queued； 已耗尽但尚未迁移的 pending 返回 exhausted_pending，相同身份若已进入 failed store 则返回 already_failed。项目必须显式审查、清理或重新授权，Adapter 不会 自动复活 dead-letter。 v1 只接受唯一的 events 字段；payload_builder 添加其他顶层字段时会失败关闭， 避免 Adapter 静默丢弃项目协议数据。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | GFAnalyticsUtility transport_callback 提供的 JSON-safe payload。 |

返回：整批交接结果。

结构：

- `payload`: Dictionary with an events Array[Dictionary].
- `return`: Dictionary with success, accepted, queued, persisted, reason, request_id, idempotency_key, and persistence_error.

<a id="member-gfanalyticsoutboxadapter-methods-handles_request"></a>

### `handles_request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func handles_request(envelope: GFRequestEnvelope) -> bool:
```

判断恢复出的请求是否属于当前 Adapter 且仍满足 v1 固定协议。 项目 transport 可在路由后动态注入鉴权并发送；本方法不会调用 transport。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 待路由的请求信封。 |

返回：身份、协议、预算和 body/metadata 一致时返回 true。

<a id="member-gfanalyticsoutboxadapter-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不包含事件、请求 body、业务字段或鉴权数据的调试快照。

返回：安全调试快照。

结构：

- `return`: Dictionary with schema_id, protocol_version, configuration budgets, outbox availability, pending/failed counts, and last_reason.
