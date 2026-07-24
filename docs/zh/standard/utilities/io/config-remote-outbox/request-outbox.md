# 通用请求 Outbox

这一页说明如何把失败请求持久化到本地，并在项目自己的网络层或平台 SDK 可用时重放。Outbox 只负责请求描述、重试状态和队列持久化，不决定请求是否可重放或如何签名。

## 通用请求 Outbox (`GFRequestEnvelope` / `GFRequestOutboxUtility`)

当项目需要把失败请求先落到本地、稍后再由自己的网络层或平台 SDK 重放时，可以注册 `GFRequestOutboxUtility`。它只负责请求描述、持久化、重试次数、重试延迟和失败列表，不内置任何账号、排行榜、云存档、鉴权或业务协议。

```gdscript
var outbox := Gf.get_utility(GFRequestOutboxUtility) as GFRequestOutboxUtility
outbox.transport_callback = func(envelope: GFRequestEnvelope) -> Dictionary:
	# 项目层自行发送 envelope，可以走 HTTP、平台 SDK 或本地工具桥。
	return { "ok": true }

outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.com/api/events", {
	"event": "checkpoint",
	"position": Vector2(12.0, 4.0),
})

await outbox.replay()
```

`GFRequestEnvelope` 保存 `method`、`url`、`body`、`headers`、`idempotency_key`、`attempt_count`、`max_attempts`、`next_attempt_at_unix_msec`、`last_error` 和 `metadata`。进入 Outbox 时，空的 `request_id` 会生成稳定身份，空的 `idempotency_key` 会默认使用同一个 ID；后续保存、加载和重放都不会重建该键。重试截止时间使用 Unix 毫秒而不是进程启动后的 ticks，因此退出游戏、设备休眠或编辑器重启后仍能判断何时允许下一次尝试。

队列写入 `storage_path` 时会使用 `GFVariantJsonCodec` 的类型化 JSON codec，因此 `Vector2`、`Color`、PackedArray 以及可编码的类型化 Dictionary 键等 Godot 值可以无损往返。保存流程先写同目录 `.tmp`，刷新并完整解析校验，再把现有正式文件移动为 `.bak`，最后以重命名提交新文件；加载时按正式文件、临时文件、备份的顺序选择第一个完整有效的事务并清理残留。这样进程在替换窗口退出时，下一次启动仍能从最后一个完整候选恢复，而不会把半截 JSON 当成空队列。

`max_storage_bytes` 默认是 16 MiB，限制保存结果和所有恢复候选的 UTF-8 JSON 字节数；小于等于 0 只关闭这项可配置的最终文件字节限制，不会关闭不可配置的 `512 MiB` 原始 UTF-8 输入硬上限。恢复候选会先按文件长度拒绝超限输入，再执行有界读取与解码；保存结果超限会在事务提交前失败。保存超限返回 `ERR_OUT_OF_MEMORY`，不可无损编码的值图返回 `ERR_INVALID_DATA`，两者都不会覆盖之前的有效文件；加载候选超限、长度在读取期间变化、UTF-8 非法、损坏或 schema 非法时，也不会替换当前内存状态。JSON 编码前始终限制嵌套深度 64、单集合 65,536 项、单字符串 65,536 字符、累计 1,000,000 节点和 64 MiB 估算工作量，避免外部数据先触发无界复制或遍历。

`transport_callback` 可以同步返回结果，也可以返回会发出结果值的 `Signal`；结果为 `{ "ok": true }` 或 `{ "success": true }` 时请求会从等待队列移除；失败时按 `retry_delays_msec` 安排下一次尝试，耗尽次数后可进入失败列表。所有请求信号、`transport_callback` 和 `replay_filter` 收到的 `envelope` 都是隔离副本，监听器或回调修改其字段、body、metadata 不会写回内部队列。启用 `auto_persist` 时，每个请求的成功、可重试失败或耗尽转移都会在处理下一个请求前持久化；检查点失败会立即停止本轮重放，报告返回 `reason = "persistence_failed"` 与 `persistence_error`，同时发出 `persistence_failed`，避免内存继续前进而磁盘仍停在旧状态。若进程恰好在“尝试次数已递增到上限、终态尚未写回”的窄窗口退出，下一次 `replay()` 会把该请求直接迁入 failed store，并通过 `recovered_exhausted` 计数说明修复数量，不会把它再次发给 transport。

同一个 outbox 实例同一时间只执行一轮 `replay()`；当异步 `transport_callback` 尚未返回时再次调用，会立即得到 `{ "ok": false, "reason": "replay_in_progress" }`。如果等待期间项目层调用 `remove_request()` 或 `clear_queue()` 改变队列，重放恢复后会重新定位正在处理的请求，避免按过期索引误删后续请求。

Outbox 提供的是“至少一次尝试”边界，不可能在本地进程崩溃与远端提交之间制造分布式原子事务：服务器可能已经接受请求，但客户端还未来得及记录成功。稳定 `idempotency_key` 正是用于这个窗口。比如购买收据、云存档提交或成就解锁不能只因为请求 ID 不同就重复生效；项目 transport 应把该键传给服务端或 SDK，并让接收方按键去重。对于本身不可安全重放的操作，应由 `replay_filter` 拒绝，或使用项目自己的确认协议，而不是依赖重试次数猜测远端状态。

`load_queue()` 会先完整读取、解析和校验持久化队列，再一次性替换内存状态。version 2 外层只接受精确的 `version`、`pending`、`failed` 字段，每个信封也必须具备精确字段集、原始类型、整数值和与 method 一致的 `method_name`；缺字段、额外字段、字符串数字、分数 method、错误 body/metadata/header 类型等损坏输入都不会被 getter 默认值静默归一化后重放。所有候选都损坏或 schema 不合法时，当前待发送队列与失败列表保持不变，不会因为一次失败恢复而丢失仍在内存中的请求。持久化 schema 当前为 version 2；旧版保存的进程内 ticks 不具备跨重启含义，因此不会被静默兼容或猜测转换。

这个工具适合做“通用离线 outbox”边界，例如分析事件、自定义远程配置写入、轻量状态提交或编辑器工具请求。它不替项目决定哪些请求可重放、是否幂等、如何签名、如何脱敏、如何处理冲突；这些策略应放在项目自己的 `transport_callback`、`replay_filter` 或更高层同步系统中。

## 带持久化结果的入队

需要明确区分“进入内存队列”和“已经持久化”时，使用：

```gdscript
var envelope := GFRequestEnvelope.new(
	HTTPClient.METHOD_POST,
	"https://example.com/events",
	{ "events": batch }
)
var report := outbox.enqueue_with_report(envelope, true)
```

`enqueue_with_report(envelope, require_persistence)` 返回 `ok`、`status`、`reason`、`envelope`、`persisted` 和 `persistence_error`。`require_persistence = false` 时，成功进入 Outbox 即表示所有权已经转移，报告会另外说明是否落盘；设为 `true` 时，会在修改队列前验证 `body` 与 `metadata` 可由 codec 无损往返，`Object`、`Callable`、`Signal`、`RID`、循环集合和其他不支持值会以 `non_persistable_envelope` 拒绝，持久化失败也不会被伪装成耐久成功。

成功保存后，入口还会等待同步的 `request_enqueued` / `queue_changed` 监听器返回，再复核内部仍持有本次精确请求且持久化状态有效。耐久证明同时绑定调用开始时捕获的 `storage_path`、精确队列 revision 与规范化持久化内容；路径被切换、队列在保存后又发生变化、既有便捷入口暴露的信封别名被调用方直接修改，或最后成功保存的是另一条 revision/内容时，均不能复用旧的 `is_persisted = true`。同步通知中的路径改写不会重定向本次提交。监听器若同步清空、移除、释放或重新加载而撤销交接，返回 `ok = false`、`reason = "enqueue_invalidated"`，并尽力把当前队列补偿保存到本次事务路径；调用方仍保留原批次所有权。调用方应依据这份单次报告决定是否释放自己的原始批次，不要只读取全局调试快照推断某一次入队结果。

既有 `enqueue()` / `enqueue_request()` 继续提供只返回内存接受状态的便捷入口；其 `true` 不是耐久回执，即使启用 `auto_persist` 也不会把具体持久化错误返回给调用方。需要把另一条队列可靠桥接到 Outbox、需要在成功后释放上游所有权，或需要把持久化结果传回上游时，必须使用 `enqueue_with_report(..., true)` 并检查单次报告。

## Analytics Outbox Adapter

`GFAnalyticsOutboxAdapter` 把 `GFAnalyticsUtility` 已生成的批次 payload 转成 Outbox 请求，使用固定的 v1 协议 Schema：`schema_id = "gf.analytics.outbox"`、`protocol_version = 1`。典型装配是：

```gdscript
var adapter := GFAnalyticsOutboxAdapter.new().configure(
	analytics_outbox,
	{ "endpoint_url": "https://example.com/events" }
)
analytics.transport_callback = Callable(adapter, "enqueue_payload")
```

Adapter 不会替换 `analytics_outbox.transport_callback` 或 `replay_filter`；如何发送、何时允许重放、如何签名和怎样刷新凭据仍由该 Outbox 的项目配置负责。`configure()` 可设置逻辑端点、批次和 JSON 预算以及最大重试次数，不接收认证 Header；项目应在实际重放时按当前会话动态注入凭据。建议 Analytics 使用专用 Outbox 和专用 `storage_path`，避免不同数据保留期限、用户同意、账号身份和幂等政策在一个队列中互相污染。

Adapter 固定调用 `enqueue_with_report(envelope, true)`，因此只有请求已经进入 Outbox 且持久化成功时，报告中的 `success`、`queued` 和 `persisted` 才会为 `true`，Analytics 批次才完成耐久移交。已有且尚可尝试的 pending 也要重新保存和查询确认；耗尽但尚未迁入 failed store 的 pending 返回 `exhausted_pending`，相同身份已在 failed store 时返回 `already_failed`，两者都不会伪装为成功或自动复活。后续发送仍是 at-least-once；`persisted = true` 只说明本地持久化检查点成功，不表示远端已接收。远端必须使用稳定 `idempotency_key` 去重，并重新验证事件 Schema、身份和授权。

Analytics 的 `schema_version` 只声明事件属性契约。Adapter 不执行 v1→v2 隐式迁移，不会把旧事件改写成最新 Schema，也不会识别 PII 或替项目取得 consent。账号切换、撤回同意或凭据失效时，项目必须通过独立 Outbox 的清理、过滤或重授权策略处理尚未发送的事件。完整说明见 [通用分析事件](analytics-events.md)。

## 协议确认账本 (`GFProtocolAckLedger`)

如果项目自己的协议或 SDK 包装层需要记录“哪些 packet 还在等待 ACK、哪些已经失败或超时”，可以使用 `GFProtocolAckLedger`。它只保存 ID、状态、时间戳、deadline、尝试次数、下一次可重试时间、结果和 metadata，不生成 ID、不发送网络包，也不决定最终重传策略。

```gdscript
var ledger := GFProtocolAckLedger.new()
ledger.timeout_msec = 5000

ledger.register_packet(packet_id, { "channel": "matchmaking" })

if accepted:
	ledger.acknowledge_packet(packet_id, { "code": 200 })
else:
	ledger.fail_packet(packet_id, "rejected")

var expiration := ledger.expire_pending()
```

需要实现可靠消息时，可在发送前调用 `record_packet_attempt()` 递增尝试次数并写入下一次可重试时间，再用 `get_retry_ready_ids()` 取出当前已经允许重试的 packet。入站包可用 `accept_incoming_packet()` 做去重和同 channel 序号顺序检查；返回报告会说明本次是否 accepted、duplicated 或 out-of-order，项目协议层再决定丢弃、补发 ACK 还是进入重同步。

这个账本适合被 WebSocket、蓝牙、本地进程桥接、平台 SDK 或自定义可靠消息层复用。具体协议帧格式、QoS、连接状态、重试节奏和安全策略都应留在项目或独立适配器里。

`packet_id` 是协议身份，只接受可稳定比较的标量值；Array、Dictionary、Object 等可变或进程相关 Variant 会在注册前被拒绝。复杂业务身份应先由协议层编码成稳定字符串或整数。
