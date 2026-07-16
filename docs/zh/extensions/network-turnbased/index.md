# Network 与 TurnBased

Network 扩展提供传输抽象、消息载体、序列化、通道、校验、同步快照、脏字段跟踪和契约生成。TurnBased 扩展提供通用阶段推进和行动解析流程。它们都只定义框架级基础设施，不内置服务器、房间、账号、鉴权、同步策略、参与者字段或行动效果。

## 阅读入口

- [Network 传输抽象](network-transport/index.md)：`GFNetworkUtility`、后端、session、serializer、WebSocket、channel 和 rate limiter。
- [Network 固定 tick、快照与历史](network-snapshots.md)：`GFFixedTickClock`、`GFNetworkSnapshot`、`GFNetworkHistoryBuffer`、`GFNetworkDirtyStateTracker` 和字段序列化 schema。
- [Network 契约、生成器与重连策略](network-contracts.md)：`GFNetworkContract`、消息契约、辅助类生成、契约审计、strict validator、重连退避和包体大小限制。
- [Network Lobby 与平台 Adapter 边界](network-lobby.md)：`GFNetworkLobbyService`、lobby backend、peer identity、邀请事件和平台中立 adapter 规则。
- [TurnBased 通用回合流程](turn-flow.md)：`GFTurnFlowSystem`、阶段、行动队列、排序和异步阶段安全等待。

## 使用边界

Network 只提供可替换传输边界、通用消息结构和平台中立 lobby 抽象。项目层负责鉴权、presence、服务器权威、预测、回滚、实体复制、安全过滤和具体房间玩法。TurnBased 只提供阶段与行动解析骨架，不定义卡牌、战棋、回合制 RPG 或任何具体玩法规则。

## API Reference

完整 API 见 [Network API Reference](../../reference/api/extensions-network.md) 与 [TurnBased API Reference](../../reference/api/extensions-turn-based.md)。
