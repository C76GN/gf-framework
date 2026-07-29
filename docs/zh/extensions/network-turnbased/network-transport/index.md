# Network 传输抽象

本组页面说明 `GFNetworkUtility` 如何把消息、序列化、通道校验和后端传输分开。它不是“Godot 服务端专用网络层”：客户端和服务端可以都使用 Godot，也可以由 Godot 客户端连接非 Godot 服务；只要项目 backend/adapter 能把底层传输映射到 `GFNetworkBackend` 契约即可。

## 阅读入口

- [后端与 Session](backend-session.md)：`GFNetworkUtility`、`GFNetworkBackend`、host/connect、session 状态、传输指标和 Headless 健康探针组合。
- [序列化与消息解码](serialization.md)：`GFNetworkSerializer`、Variant / JSON、typed JSON codec 和拒包详情。
- [WebSocket 后端](websocket.md)：`GFWebSocketNetworkBackend` 的客户端、服务器和 peer id 约定。
- [Channel 与限流](channels-rate-limit.md)：`GFNetworkChannel`、逻辑通道匹配和 `GFNetworkRateLimiter`。
- [服务发现记录](service-discovery.md)：`GFNetworkServiceDiscovery` 的服务广告、JSON bytes 编解码和 TTL 过期管理。
- [权威快照同步协调器](../network-sync-coordinator.md)：建立在 transport 之上的独立全量快照、输入 ack 与预测纠偏流程。

## 使用边界

Network 传输抽象只定义消息、序列化、通道、后端接口和可选服务发现记录，本身不执行权威、预测或回滚。Network 扩展另有可选协调器编排通用全量权威快照，但账号、房间、鉴权、authority 选择、实体控制权、状态 Schema 和业务复制语义仍由项目层实现。

普通 HTTP API 不属于多人传输扩展。单次请求使用标准库 `GFHttpRequestBuilder`，需要有界并发与节点复用时使用 `GFHttpClientUtility`；平台 SDK、REST 服务或自建后端 adapter 可以在项目层组合它们，但不应把 HTTP 业务端点写进 Network 核心。
