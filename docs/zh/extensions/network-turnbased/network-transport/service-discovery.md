# 服务发现记录

## 核心模型

`GFNetworkServiceDiscovery` 提供传输无关的服务广告、JSON bytes 编解码和 TTL 过期管理。它不打开 UDP socket，不规定广播地址，也不定义房间、账号、鉴权或同步规则；项目可以把 LAN 广播、WebRTC signaling、平台大厅或自定义发现通道收到的 bytes 交给它统一解析和维护。

## 使用示例

```gdscript
var discovery := GFNetworkServiceDiscovery.new()
var advertisement := discovery.make_advertisement(
	&"lobby",
	"enet://192.168.1.12:24567",
	{ "players": 2 },
	{ "ttl_seconds": 3.0, "tags": PackedStringArray(["lan"]) }
)

var packet := GFNetworkServiceDiscovery.encode_advertisement(advertisement)
var report := discovery.accept_packet(packet, "192.168.1.12", 49000)
```

## 记录与身份

广告记录包含 `service_id`、`endpoint`、`display_name`、`tags`、`metadata`、`ttl_seconds` 和 `sequence`。`metadata` 完全由项目解释，GF 只复制和编码，不把玩家数、房间名、模式、版本兼容或权限规则写成框架语义。

服务索引 key 使用 `service_id` 加脱敏 endpoint 摘要生成；调试快照不会把 endpoint 的 userinfo、path、query 或 fragment 直接写进 service key。当前 identity 摘要会先移除 userinfo、query 与 fragment，所以只在这些部分不同的 endpoint 会被视为同一服务并形成 `updated`；如果 shard、region 或 lobby ID 属于服务身份，应把它放在 `service_id`、host 或 path，而不是 query。接收广告时，低 sequence 或相同 sequence 但更旧 `time_msec` 的记录会被忽略，避免旧广播刷新 TTL 或回滚 metadata。

## 生命周期与信任边界

运行时每帧或按固定间隔调用 `tick(delta)`，过期服务会从列表移除并发出 `service_lost`：

```gdscript
discovery.tick(delta)
for service in discovery.get_services(&"lobby"):
	print(GFVariantData.get_option_string(service, "endpoint"))
```

`accept_advertisement()` / `accept_packet()` 的 `now_seconds` 只控制 `first_seen_seconds`、`last_seen_seconds` 与公开 `expires_at_seconds` 的记录时间域；真正的 TTL deadline 始终按该 discovery 实例自己的 `tick(delta)` 累积时钟计算。因此传入 OS monotonic epoch 或测试时间不会把 1 秒 TTL 意外延长成数百秒，但项目仍必须持续推进 `tick()`。

当前版本只限制单个广告和 metadata 的结构预算，不替项目定义最大服务数量、TTL ceiling、per-address quota 或 eviction policy。把不可信 LAN/relay 输入交给 discovery 前，项目必须在传输入口执行速率、来源和容量 admission；框架级默认配额仍需根据目标部署规模决定。

如果项目需要真正的 LAN 发现，可以在项目侧用 `PacketPeerUDP` 定时发送 `encode_advertisement()` 的结果，并把接收端收到的 packet 交给 `accept_packet()`。如果发现通道来自 WebSocket、平台 SDK 或编辑器工具，也复用同一套广告 schema 和过期逻辑即可。
