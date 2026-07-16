# 服务发现记录

`GFNetworkServiceDiscovery` 提供传输无关的服务广告、JSON bytes 编解码和 TTL 过期管理。它不打开 UDP socket，不规定广播地址，也不定义房间、账号、鉴权或同步规则；项目可以把 LAN 广播、WebRTC signaling、平台大厅或自定义发现通道收到的 bytes 交给它统一解析和维护。

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

广告记录包含 `service_id`、`endpoint`、`display_name`、`tags`、`metadata`、`ttl_seconds` 和 `sequence`。`metadata` 完全由项目解释，GF 只复制和编码，不把玩家数、房间名、模式、版本兼容或权限规则写成框架语义。

服务索引 key 使用 `service_id` 加脱敏 endpoint 摘要生成；调试快照不会把 endpoint 的 userinfo、path、query 或 fragment 直接写进 service key。接收广告时，低 sequence 或相同 sequence 但更旧 `time_msec` 的记录会被忽略，避免旧广播刷新 TTL 或回滚 metadata。

运行时每帧或按固定间隔调用 `tick(delta)`，过期服务会从列表移除并发出 `service_lost`：

```gdscript
discovery.tick(delta)
for service in discovery.get_services(&"lobby"):
	print(GFVariantData.get_option_string(service, "endpoint"))
```

如果项目需要真正的 LAN 发现，可以在项目侧用 `PacketPeerUDP` 定时发送 `encode_advertisement()` 的结果，并把接收端收到的 packet 交给 `accept_packet()`。如果发现通道来自 WebSocket、平台 SDK 或编辑器工具，也复用同一套广告 schema 和过期逻辑即可。
