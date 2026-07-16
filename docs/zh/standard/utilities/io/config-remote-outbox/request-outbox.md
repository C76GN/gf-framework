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

`GFRequestEnvelope` 保存 `method`、`url`、`body`、`headers`、`idempotency_key`、`attempt_count`、`max_attempts`、`last_error` 和 `metadata`。队列写入 `storage_path` 时会使用 `GFVariantJsonCodec` 的类型化 JSON codec，因此 `Vector2`、`Color`、PackedArray 等常见 Godot 值可以作为普通载荷保存。`transport_callback` 可以同步返回结果，也可以返回会发出结果值的 `Signal`；结果为 `{ "ok": true }` 或 `{ "success": true }` 时请求会从等待队列移除；失败时按 `retry_delays_msec` 安排下一次尝试，耗尽次数后可进入失败列表。

同一个 outbox 实例同一时间只执行一轮 `replay()`；当异步 `transport_callback` 尚未返回时再次调用，会立即得到 `{ "ok": false, "reason": "replay_in_progress" }`。如果等待期间项目层调用 `remove_request()` 或 `clear_queue()` 改变队列，重放恢复后会重新定位正在处理的请求，避免按过期索引误删后续请求；项目自己的 transport 仍应保证请求幂等或能处理重复提交。

`load_queue()` 会先完整读取、解析和校验持久化队列，再一次性替换内存状态。文件损坏或 schema 不合法时，当前待发送队列与失败列表保持不变，不会因为一次失败恢复而丢失仍在内存中的请求。

这个工具适合做“通用离线 outbox”边界，例如分析事件、自定义远程配置写入、轻量状态提交或编辑器工具请求。它不替项目决定哪些请求可重放、是否幂等、如何签名、如何脱敏、如何处理冲突；这些策略应放在项目自己的 `transport_callback`、`replay_filter` 或更高层同步系统中。

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
