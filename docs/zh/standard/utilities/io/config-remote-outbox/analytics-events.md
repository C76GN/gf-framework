# 通用分析事件

这一页说明 `GFAnalyticsUtility` 的本地队列、版本化事件 Schema、dry-run、批量 flush，以及如何把批次交给专用请求 Outbox。事件分类、字段含义、兼容策略、隐私与用户同意、鉴权和服务端协议仍由项目层负责。

## 通用分析事件 (`GFAnalyticsUtility`)

**应用场景：** 当你需要在项目内统一记录调试指标、玩家流程节点或运行时事件，并希望先在本地 dry-run，之后再按需接入 HTTP 端点时，可以使用该工具。

`GFAnalyticsUtility` 默认不会在 endpoint 为空时访问网络，`flush()` 会以 dry-run 成功完成，便于测试和本地开发保持同一套调用路径。它会为设备生成并持久化匿名 client id，同时每次运行生成新的 session id。

```gdscript
var analytics := Gf.get_utility(GFAnalyticsUtility) as GFAnalyticsUtility
analytics.config.auto_capture_context = true
analytics.config.batch_size = 20

analytics.identify("client-id")
analytics.track(&"screen_opened", {
	"screen": "inventory",
})

# endpoint_url 为空时为本地 dry-run；配置后会按 JSON 批量 POST
analytics.config.endpoint_url = "https://example.com/events"
analytics.flush()
```

`GFAnalyticsConfig.batch_size` 会把 Inspector 和运行时直接赋值都钳制到 `1..500`，`max_queue_size` 会钳制到 `1..100_000`；不能再用 `0` 或负数表达“禁用批次/无限队列”。`identify(client_id)` 只接受 `1..4096` 字符且不含 C0 控制字符（U+0000..U+001F）或 DEL（U+007F）的 ID；非法输入会被拒绝，不会覆盖当前 client id。`track()` / `track_versioned()` 的事件名还必须满足 `max_event_name_length`（配置范围 `1..4096`，默认 `128`），同样拒绝 C0/DEL，避免能在 Analytics 进入队列、却在持久化 Adapter 处永久失败的事件。

## 版本化事件 Schema

需要长期统计、跨版本聚合或由多个模块共同生产的事件，不应只靠事件名和约定俗成的字段。`GFAnalyticsEventSchema` 把一个稳定事件名、`1..2_147_483_647` 范围内的 `schema_version` 和 `GFDictionarySchema` 属性契约绑定在一起；`GFAnalyticsSchemaRegistry` 负责按 `(event_name, schema_version)` 注册和查询 Schema。这个上界与 `PackedInt32` 可表达的正整数范围一致，Registry 与 Adapter 都会拒绝越界版本。

Schema 校验的输入只包含调用方提交的 `properties`。`event`、`event_id`、`schema_version`、`client_id`、`session_id`、`timestamp` 和 `context` 等最终事件信封字段由 `GFAnalyticsUtility` 生成，不应重复写入属性 Schema，也不能借属性覆盖。项目可以用既有 `GFDictionarySchema` / `GFSchemaField` 声明必需字段、值类型和是否允许额外字段：

```gdscript
var properties_schema := GFDictionarySchema.new().configure(
	&"checkout_completed.properties.v1",
	[
		GFSchemaField.new().configure(
			&"order_id",
			GFSchemaField.ValueType.STRING,
			{ "required": true, "allow_null": false }
		),
		GFSchemaField.new().configure(
			&"amount",
			GFSchemaField.ValueType.FLOAT,
			{ "required": true, "allow_null": false }
		),
	],
	{ "allow_extra_fields": false }
)

var event_schema := GFAnalyticsEventSchema.new().configure(
	&"checkout_completed",
	1,
	properties_schema
)
var registration_report := analytics.schema_registry.register_schema(event_schema)
if not registration_report.get("ok", false):
	push_warning("Analytics schema rejected: %s" % registration_report.get("reason", "unknown"))

var track_report := analytics.track_versioned(
	&"checkout_completed",
	1,
	{
		"order_id": "order-42",
		"amount": 18.5,
	}
)
if not track_report.get("ok", false):
	push_warning("Analytics event rejected: %s" % track_report.get("reason", "unknown"))
```

`track_versioned(event_name, schema_version, properties)` 返回结构化报告。找不到精确版本、Schema 定义非法或属性不符合契约时，事件不会进入队列。Registry 不会把 v1 输入自动提升为 v2，也不会猜测字段重命名或默认值迁移；新增或修改事件字段时，应显式注册新版本，并由项目决定旧客户端、服务端聚合和数据仓库如何兼容。

Registry 只接受 GF 内置的声明式 `GFAnalyticsEventSchema`、`GFDictionarySchema`、`GFSchemaField` 和约束规则脚本，不执行派生 Resource 覆写或运行时 `Callable`。单个 Registry 最多保存 `1024` 个 Schema，同一事件最多保存 `32` 个精确版本；累计定义图最多 `65_536` 个节点、辅助值最多 `131_072` 个节点、文本最多 `16 MiB`。单个 Schema 定义图也受深度 `64`、节点 `4096`、单集合 `4096`、每字段规则 `64`、辅助值深度 `32` / 节点 `8192` 和文本 `4 MiB` 的不可放宽上限约束。

属性校验选项默认是深度 `16`、根属性 `128`、字符串 `4096` 字符、单集合 `256` 项、累计 `8192` 个节点和 `256 KiB` 估算工作量；项目可以降低，或在硬上限内提高到深度 `64`、根属性 `4096`、字符串 `65_536` 字符、单集合 `4096` 项、累计 `1_000_000` 个节点和 `16 MiB`。这些限制是客户端资源边界，不代替服务端重新校验。

`track()` 仍适合不需要版本承诺的本地诊断或临时事件，但它不会隐式选择 Registry 中的“最新版本”。需要稳定分析契约时，应明确调用 `track_versioned()`。

如果项目需要接入自定义 SDK 或不同服务端协议，可以使用传输 hook，而不是修改工具内部：

```gdscript
analytics.payload_builder = func(batch: Array) -> Dictionary:
	return {
		"events": batch,
		"schema": "v1",
	}

analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
	# 项目层自行发送 payload，也可以只写入本地调试管线。
	return { "success": true, "accepted": (payload["events"] as Array).size() }
```

`payload_builder` 会收到隔离批次，返回值中的 `events` 会被 GF 的已编码事件覆盖。Planner 不假设最终信封大小随批次单调变化，而是从最大候选前缀向下做有界校验，因此回调可能被调用多次，必须无副作用且对同一输入返回确定结果。

配置项放在 `GFAnalyticsConfig` 中，包括 `endpoint_url`、`headers`、`batch_size`、`max_queue_size`、`flush_interval_seconds`、`app_version`、`persist_client_id`、`client_id_storage_path`、`flush_on_shutdown` 和 `compress_payload`。`compress_payload` 为 `true` 时，内置 HTTP 上报会使用 gzip 压缩 JSON 请求体并添加 `Content-Encoding: gzip`；项目自己的服务端必须支持该编码。自定义 `headers` 会过滤空 header 名和包含 CR/LF 的键值，避免把外部字符串直接拼成非法 HTTP 头；启用压缩时，自定义 `Content-Encoding` 会被忽略，以保证 header 与请求体一致。`transport_callback` 是同步 hook，必须直接返回结果字典；如需异步 SDK，应在项目层做缓冲，再把 GF 队列视为本地入口。项目层仍然负责决定事件命名、字段规范和隐私策略。

transport 或响应失败时，本批事件会按原顺序放回队列前端，并发出 `flush_failed` / `flush_completed`；失败回灌后仍会重新执行 `max_queue_size` 限制。Planner 的评估次数或累计编码工作达到预算时，不会发送或丢弃事件，而会保留完整队列并返回 `retained = true`、`dropped = false`、`drop_reason = "planner_budget_exceeded"`。相同配置下反复调用 `flush()` 不会改善结果，应先降低 `batch_size` 或简化 `payload_builder`。只有已经证明单个事件无法放入最终信封时，该事件才会以 `dropped = true` 和 `final_envelope_too_large` 明确丢弃。正常 `track()` 超过上限时会丢弃最早事件；失败批次回灌超过上限时会优先保留刚失败的批次。关闭时的 `flush_on_shutdown` 是尽力触发，不会等待 HTTP 请求完成；关键埋点应由项目层在重要流程点主动 `flush()` 并监听结果。Gf AutoLoad 的 `_exit_tree()` 正在同步释放架构时，Analytics 关闭监听会登记延迟释放而不重入修改 `SceneTree.root`。`capture_context()` 只采集平台、Godot 版本、屏幕尺寸、语言和时区等通用信息，涉及账号、设备指纹或隐私字段的内容必须由项目层显式添加。

## 交给专用 Outbox

需要在离线、退出或临时传输失败后继续重放时，可用 `GFAnalyticsOutboxAdapter` 把 Analytics payload 转成 `GFRequestEnvelope`。Adapter 属于 `gf.standard.assets`，因为它依赖同包的 `GFRequestOutboxUtility`；事件 Schema、Registry 和 Analytics Utility 属于 `gf.standard.base`。这个方向保持 `base <- assets`，不会让基础包反向依赖 IO 包。

```gdscript
var outbox := GFRequestOutboxUtility.new()
outbox.storage_path = "user://analytics_outbox.json"
outbox.auto_persist = true

# 项目拥有实际发送、鉴权与重放许可。
outbox.transport_callback = Callable(self, "_send_analytics_request")
outbox.replay_filter = Callable(self, "_allow_analytics_replay")
outbox.init()

var adapter := GFAnalyticsOutboxAdapter.new().configure(
	outbox,
	{
		"endpoint_url": "https://example.com/events",
		"max_payload_bytes": analytics.config.max_payload_bytes,
	}
)
analytics.transport_callback = Callable(adapter, "enqueue_payload")
```

Adapter 使用固定的 v1 协议 Schema：`schema_id = "gf.analytics.outbox"`、`protocol_version = 1`。v1 payload 必须精确只有 `{ "events": [...] }`；自定义 `payload_builder` 添加任何其他顶层字段都会以 `unsupported_payload_fields` 失败关闭，不会被 Adapter 静默丢弃。每个 legacy 事件必须精确包含 `event`、`client_id`、`session_id`、`timestamp`、`properties`，并且只能可选增加 `context`；版本化事件必须在同一组字段上同时增加 `event_id` 与 `schema_version`。`properties` / `context` 必须是 Dictionary，`event`、client/session ID 与 timestamp 必须是非空文本且不含 C0/DEL；版本化 `event_id` 必须是批内唯一 UUID，版本必须在 `1..2_147_483_647`。缺字段、多字段、字段类型不符或只提供版本身份的一半都会拒绝整批。

`configure()` 可设置以下有界预算：最终 JSON `max_payload_bytes = 1024..16 MiB`、`max_events_per_request = 1..500`、`max_attempts = 1..64`、`max_depth = 1..32`、`max_collection_items = 1..4096`、`max_string_length = 1..65_536` 和 `max_total_nodes = 1..1_000_000`。事件数组不能为空，所有值必须是有限、JSON-safe 的标量、Array 或文本键 Dictionary，循环集合和非有限浮点数会被拒绝。

`endpoint_url` 会进入请求信封并参与协议身份校验，只能使用 `1..2048` 字符的稳定、非敏感逻辑路由；它不得带首尾空白、任意空白或控制字符，也不得包含 userinfo/凭据、query 或 fragment（`@`、`?`、`#`）。供应商路由与认证应由 replay transport 动态处理。Adapter 只负责把已生成的 Analytics payload 交给 Outbox，不覆盖项目设置的 `transport_callback` 或 `replay_filter`，也不拥有鉴权 token，安全调试快照不会返回 endpoint。项目也可以在自己的过滤策略中调用 `adapter.handles_request(envelope)` 验证是否为该协议的合法请求。建议为 Analytics 使用独立的 `GFRequestOutboxUtility`、独立 `storage_path` 和独立重放策略，不要与购买、云存档、客服工单等不同隐私、授权和幂等要求的请求共用队列。

`enqueue_payload()` 返回 `success`、`accepted`、`queued`、`persisted`、`reason`、`request_id`、`idempotency_key` 和 `persistence_error`。Adapter 固定通过 `enqueue_with_report(envelope, true)` 要求耐久移交：只有入队且持久化成功后，`success` / `queued` / `persisted` 才会为 `true`，Analytics 才会释放原批次；磁盘失败会作为失败报告返回。精确匹配且尚可尝试的 pending 请求也必须再次 `save_queue()` 并重新查询确认，才返回 `already_queued`；已经耗尽但尚未由 Outbox 迁入 failed store 的 pending 返回 `success = false`、`accepted = 0`、`reason = "exhausted_pending"`。相同幂等身份已经进入 failed store 时返回 `reason = "already_failed"`；Adapter 不会自动复活、覆盖或复制这些请求，项目应先显式审查、清理或重新授权。若其他通用 Outbox 调用方有意接受仅内存所有权，可直接使用 `enqueue_with_report(envelope, false)`，但这不是 Analytics Adapter 的语义。

Outbox 提供的是 at-least-once 尝试，而不是 exactly-once 交付。远端已经接受、但客户端尚未来得及记录成功时，同一请求可能再次发送；接收端必须按稳定 `idempotency_key` 去重。Schema version 只解释事件属性结构，不是请求认证、用户授权或重放许可。

## 隐私与安全边界

- Schema 只验证结构和类型，不会自动识别或删除 PII，也不会替项目取得用户同意。
- 项目必须决定哪些事件允许采集、何时启用 Analytics、保留多久、如何响应撤回同意和数据删除请求。
- endpoint、认证 header、token 刷新、TLS/证书策略和服务端授权属于项目 transport；不要把长期凭据写入事件 properties、Outbox body、metadata、日志或调试快照。
- Adapter 不会把 Schema 版本当作迁移许可，也不会把队列存在当作发送许可。账号切换、退出登录、同意状态变化后，项目应显式清理、隔离或重新授权待发送请求。
- Schema 与客户端预算不能证明服务端可信。服务端仍需执行 Schema、大小、身份、幂等和权限校验。
