# Network 传输抽象

本组页面说明 `GFNetworkUtility` 如何把消息、序列化、通道校验和后端传输分开。项目仍需自己实现或选择具体连接协议与业务同步规则。

## 阅读入口

- [后端与 Session](backend-session.md)：`GFNetworkUtility`、`GFNetworkBackend`、host/connect 和 session 状态。
- [序列化与消息解码](serialization.md)：`GFNetworkSerializer`、Variant / JSON、typed JSON codec 和拒包详情。
- [WebSocket 后端](websocket.md)：`GFWebSocketNetworkBackend` 的客户端、服务器和 peer id 约定。
- [Channel 与限流](channels-rate-limit.md)：`GFNetworkChannel`、逻辑通道匹配和 `GFNetworkRateLimiter`。
- [服务发现记录](service-discovery.md)：`GFNetworkServiceDiscovery` 的服务广告、JSON bytes 编解码和 TTL 过期管理。

## 使用边界

Network 传输抽象只定义消息、序列化、通道、后端接口和可选服务发现记录。账号、房间、鉴权、服务器权威、实体复制、预测回滚和业务同步协议仍由项目层实现。
