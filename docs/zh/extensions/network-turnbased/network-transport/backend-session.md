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

`GFNetworkBackend.get_transport_metrics()` 返回 `GFNetworkTransportMetrics`。基础 Backend 统一统计成功发送和已派发接收的 bytes/packet 数；具体实现可以补充 RTT、jitter、丢包率和队列。指标只有在 `has_metric()` 为 true 时才已知，未支持的 RTT 不会伪装成 `0`。单个快照最多包含 64 个指标，其中最多 48 个自定义指标，指标 ID 最多 64 个字符；达到上限后的新指标由 `set_metric()` 失败关闭，既有指标仍可更新。

`GFNetworkUtility` 默认每秒采样一次并最多保存 120 个快照。可以修改 `transport_metrics_sample_interval_msec` 和 `max_transport_metric_samples`，也可以调用 `capture_transport_metrics()` 手动采样。历史始终返回深拷贝，诊断快照只包含当前指标和样本数量，不把整段序列无限写入支持报告。

## Headless 服务健康与探针组合配方

Headless 服务可以把网络会话和当前传输指标作为健康判断的证据，但 GF 不规定 liveness、readiness 或部署平台协议。项目应通过[惰性诊断 Provider](../../../standard/utilities/runtime/debug-observability/runtime-telemetry/build-diagnostics/diagnostics-commands/lazy-providers.md)按请求读取一份同步、只读、有界的白名单快照，再由独立 HTTP、Kubernetes 或监控 Adapter 应用项目策略。

`get_transport_metrics()` 只允许 Backend 通过 `_enrich_transport_metrics(metrics, budget)` 读取已经在内存中的传输状态。Hook 每尝试写入一个可选指标前必须消费一步 `GFExecutionBudget`，并在预算或 `set_metric()` 拒绝时立即停止；模板方法会比较新增指标数与已消费步数，未消费预算的新增指标、超过协作式步数或耗时预算的结果都会回退为基础指标。预算不能抢占已经阻塞的调用，所以网络、磁盘、锁等待、项目业务查询和其他不可中断 I/O 从契约上禁止进入 Hook。Adapter 应在自己的可执行验收中验证这一点，而不能把返回后的耗时检查描述成硬中断能力。

下面的项目 Provider 只公开后端、会话和一个可选队列指标。它捕获当前 backend 和 session 引用，只读取固定数量的类型化字段，并只消费受绝对容量和 Backend 协作预算保护的当前指标；不会调用会遍历 channels、validator 和自定义后端调试数据的完整 `get_debug_snapshot()`，也不会调用会追加采样历史并发出信号的 `capture_transport_metrics()`：

```gdscript
class HeadlessNetworkHealthProvider extends GFDiagnosticSnapshotProvider:
	var network: GFNetworkUtility

	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		if network == null:
			return GFDiagnosticProviderResult.failed(
				&"network_unavailable",
				"Network utility is not available."
			)

		var current_backend: GFNetworkBackend = network.backend
		var current_session: GFNetworkSession = network.session
		var evidence: Dictionary = {
			"backend_configured": current_backend != null,
			"session_active": current_session != null and current_session.is_active,
			"has_connection": current_session != null and current_session.has_connection,
		}
		if current_backend == null:
			return GFDiagnosticProviderResult.succeeded(evidence)

		var metrics: GFNetworkTransportMetrics = (
			current_backend.get_transport_metrics()
		)
		var queue_metric: StringName = (
			GFNetworkTransportMetrics.SEND_QUEUE_PACKETS
		)
		if metrics != null and metrics.has_metric(queue_metric):
			evidence[String(queue_metric)] = metrics.get_metric(queue_metric)
		return GFDiagnosticProviderResult.succeeded(evidence)


var provider := HeadlessNetworkHealthProvider.new()
provider.network = network
var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(
	&"service.headless_network",
	{"max_duration_usec": 20_000}
)
var registered: bool = diagnostics.register_diagnostic_provider(self, provider)
if not registered:
	push_error("Headless network health provider registration failed.")
```

项目 Adapter 只在处理探针请求时显式采集 `service.headless_network`。示例固定读取三个标量和至多一个受控指标，不触碰 endpoint、metadata、channel 列表或自定义 backend debug snapshot。`GFNetworkTransportMetrics` 中缺失的指标表示后端未提供、被容量拒绝或本次补充预算失败，不能按 `0` 或故障处理。liveness 应只证明进程和最小事件循环仍可响应，不应因为没有 peer、RTT 升高或业务依赖失败而触发重启；readiness 才可以按服务角色检查预期 host 会话、依赖、容量和队列阈值。

GF 不提供探针 HTTP 路径、状态码、端口、TLS、鉴权、缓存、限流、Prometheus 名称或 Kubernetes 重启政策。Adapter 也不应直接返回完整网络快照；即使 GF 已执行技术脱敏，endpoint、自由 metadata、房间、账号和玩家数据仍应从探针白名单中排除。

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
