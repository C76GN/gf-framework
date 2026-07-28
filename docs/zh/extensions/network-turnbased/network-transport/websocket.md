# WebSocket 后端

需要浏览器、工具链或 WebSocket 网关时，可以换成 WebSocket 后端。它仍然只收发 `PackedByteArray`，上层继续复用 `GFNetworkMessage` / channel / validator。

```gdscript
var client_network := Gf.get_utility(GFNetworkUtility) as GFNetworkUtility
client_network.set_backend(GFWebSocketNetworkBackend.new())
client_network.connect_to_endpoint("wss://example.invalid/session")

# 本地工具或原生端也可启动一个简单 WebSocket host。
var host_network := GFNetworkUtility.new()
host_network.set_backend(GFWebSocketNetworkBackend.new())
host_network.host({
	"port": 19090,
	"bind_address": "127.0.0.1",
	"max_clients": 32,
	"handshake_timeout_msec": 5000,
})
```

`GFWebSocketNetworkBackend` 使用 `WebSocketPeer`，客户端发送时可把目标 peer 传 `GFWebSocketNetworkBackend.SERVER_PEER_ID` 或 `-1`；服务器模式下 `-1` 表示广播。

主机把握手中 peer 和已打开 peer 一起计入 `max_clients`，并为 accept、服务 peer、单 peer 收包和全局收包分别执行不可关闭的每轮预算。慢握手只会在公平轮转的 peer 服务预算内检查，超过有界 `handshake_timeout_msec` 后释放容量；调试快照会区分容量拒绝、普通握手失败和握手超时。项目可按承载能力调小公开预算，但不能把它们设为无界值。

`connected`、`peer_connected`、`message_received`、`peer_disconnected` 和 `disconnected` 都是同步信号，回调可以立即断开、重新 host 或重连。后端为每次生命周期分配单调递增的会话 generation，并在每次外部回调后同时复核 generation、模式和 WebSocket/peer 对象身份；一旦发现会话已被替换，当轮旧工作立即退出，不再派发后续旧信号、消费后续旧包或把旧统计写进新会话。`message_received` 回调触发重配置时，当前已交付的包已经离开旧队列，但同批后续包不会继续处理。轮询开始时冻结的 accept、服务 peer 与收包预算不受回调中配置变更影响；同一后端在这些同步回调内再次调用 `poll()` 是无副作用 no-op，不能借嵌套轮询重置统计、扩大预算或重复派发生命周期信号。

它不负责鉴权、心跳、房间、重连恢复或消息压缩，这些仍应由项目后端或更高层协议决定。
