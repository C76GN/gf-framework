# 后端与 Session

`GFNetworkUtility` 把消息编码、后端传输和运行时信号分开。框架提供 `GFNetworkMessage`、`GFNetworkSerializer`、`GFNetworkBackend`、`GFNetworkRateLimiter`、`GFNetworkSession`、`GFNetworkChannel`、`GFNetworkMessageValidator`、`GFMultiplayerPeerNetworkBackend`、可选 `GFENetNetworkBackend` 与 `GFWebSocketNetworkBackend`，但不内置具体服务器、房间、平台账号或业务同步规则。

Backend 是平台中立传输适配点，不要求远端也运行 Godot。项目可以接入 Godot ENet/WebSocket 服务端、其他语言实现的兼容服务、自定义原生 SDK 或平台 peer；边界只要求连接状态、peer 身份和 bytes 收发语义可被可靠映射。

```gdscript
class_name GameNetworkBackend
extends GFNetworkBackend


func send_bytes(peer_id: int, bytes: PackedByteArray, options: Dictionary = {}) -> Error:
	# 交给项目选择的底层传输实现。
	return OK
```

```gdscript
var network := Gf.get_utility(GFNetworkUtility) as GFNetworkUtility
network.set_backend(GFENetNetworkBackend.new())
network.host({ "port": 24567 })

var message := GFNetworkMessage.new(&"player_ready", { "slot": 1 })
network.send_message(-1, message)
```

如果外部 SDK 已经提供 Godot `MultiplayerPeer`，不要再为每个平台复制一套 bytes pump。Adapter 先创建并初始化 Peer，再显式声明生命周期所有权：

```gdscript
var backend := GFMultiplayerPeerNetworkBackend.new()
var error := backend.adopt_peer(provider_peer, {
	"ownership": GFMultiplayerPeerNetworkBackend.Ownership.OWNED,
	"role": GFMultiplayerPeerNetworkBackend.Role.CLIENT,
	"endpoint": "provider://lobby",
	"supports_channels": true,
	"supports_transfer_modes": true,
})
if error == OK:
	network.set_backend(backend)
```

`OWNED` 表示 Backend 释放时关闭 Peer；`BORROWED` 只断开 GF 信号和引用，外部 Adapter 继续拥有连接。Backend 独占 Peer 的 poll 与 packet 数据面，`get_peer()` 只用于 Provider 状态检查，不能同时装配到 `SceneTree.multiplayer`；要交给 `SceneMultiplayer` 时先调用 `take_peer()`，再停止使用该 Backend。不支持 channel 或 transfer mode 的 Peer 必须在 adopt 时声明，相关发送选项会明确返回 `ERR_UNAVAILABLE`。

`GFNetworkSession` 只记录后端连接意图和状态快照。`host()` 会在后端真正返回成功或报告 connected 后再标记 `has_connection`；如果后端启动失败，会关闭本次会话而不会短暂发出 connected 状态。接管已连接 Peer 时，Backend 的显式 `role`、endpoint 和本地 peer ID 会通过 `get_session_bootstrap()` 初始化 Session；因此先 `adopt_peer()` 再 `set_backend()` 也不会丢失早到的 connected 事件。

`options.metadata` 必须是 `Dictionary`，传入其他类型会被忽略并输出 warning，避免把错误配置静默保存到会话快照里。替换或清空 backend 时，`GFNetworkUtility` 会关闭旧后端并清理旧会话，避免把底层连接资源留给已失效的 backend。

`GFNetworkUtility`、`GFNetworkSession`、`GFNetworkChannel` 和内置后端返回的调试快照会经过 `GFNetworkDebugTools` 脱敏处理。常见 token、secret、password、authorization、cookie、session 等字段会替换为占位文本，endpoint 会保留协议与主机但隐藏路径、查询和片段。项目如果把额外敏感信息放进自定义 metadata，应在进入网络快照前先转换为可公开的诊断值。

## 传输指标

`GFNetworkBackend.get_transport_metrics()` 返回 `GFNetworkTransportMetrics`。基础 Backend 统一统计成功发送和已派发接收的 bytes/packet 数；具体实现可以补充 RTT、jitter、丢包率和队列。指标只有在 `has_metric()` 为 true 时才已知，未支持的 RTT 不会伪装成 `0`。

`GFNetworkUtility` 默认每秒采样一次并最多保存 120 个快照。可以修改 `transport_metrics_sample_interval_msec` 和 `max_transport_metric_samples`，也可以调用 `capture_transport_metrics()` 手动采样。历史始终返回深拷贝，诊断快照只包含当前指标和样本数量，不把整段序列无限写入支持报告。

## 服务端权威请求

GF 网络层不会规定房间、实体归属或玩法权限；这些规则应留在项目服务器或项目后端中。但入站消息进入 `message_received` 前，`GFNetworkUtility` 会用底层 backend 报告的 `peer_id` 覆盖 `GFNetworkMessage.sender_id`，项目不要信任客户端 payload 中自报的身份字段。

```gdscript
func _on_message_received(peer_id: int, message: GFNetworkMessage) -> void:
	if message.message_type != &"request_state_change":
		return

	var report := request_contract.validate_message(message)
	if not GFVariantData.get_option_bool(report, "ok", false):
		return

	var entity_id := GFVariantData.get_option_string_name(message.payload, "entity_id")
	if not _peer_can_modify_entity(peer_id, entity_id):
		return

	_apply_authoritative_change(entity_id, message.payload)
```

推荐流程是：先用 `GFNetworkMessageValidator` / `GFNetworkContractMessage` 拒绝结构错误，再用项目自己的 owner、权限、冷却和数量范围规则拒绝越权请求，最后只把确认后的结果同步给应看到该结果的 peer。GF 只提供消息载体、传输 peer、结构校验和通道限制；“谁可以改什么”必须由项目侧显式表达。
