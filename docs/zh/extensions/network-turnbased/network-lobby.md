# Network Lobby 与平台 Adapter 边界

`GFNetworkLobbyService` 和 `GFNetworkLobbyBackend` 用来描述平台中立的房间生命周期。它们只表达创建、查询、加入、离开、成员变化、metadata、邀请和错误报告，不内置 Steam、微信、Epic、主机平台、自建匹配服或任何具体 SDK。

## 基本模型

- `GFNetworkLobbyBackend`：adapter 实现的协议边界。具体平台在这里把 SDK、局域网发现或服务器 API 映射成 GF 信号和请求报告。
- `GFNetworkLobbyService`：项目侧使用的协调服务。它持有当前 backend、当前 lobby 和已知 lobby 快照，并转发 backend 事件。
- `GFNetworkLobbyDescriptor`：lobby 快照，包含 `lobby_id`、`backend_id`、owner、容量、可见性、成员、tags 和 metadata。
- `GFNetworkLobbyMember`：成员快照，包含 `peer_id`、`GFNetworkPeerIdentity`、owner/local 标记和成员 metadata。
- `GFNetworkPeerIdentity`：传输 peer 与平台账号之间的映射。`platform_id` 可以是 `steam`、`wechat`、`lan` 或项目自定义值；`platform_user_id` 只作为外部 ID 字符串保存。
- `GFNetworkLobbyQuery`：查询过滤条件。backend 可以把它映射到平台查询、LAN 广播过滤或 HTTP 请求参数。
- `GFNetworkLobbyInvite`：平台中立邀请事件。
- `GFNetworkLobbyJoinResult`：创建或加入 lobby 的最终结果。成功时携带 lobby 快照，失败时携带稳定 error 和 metadata。

```gdscript
var lobby_service := GFNetworkLobbyService.new()
lobby_service.set_backend(project_lobby_backend)

var request := lobby_service.create_lobby({
	"max_members": 4,
	"metadata": {
		"mode": "duel",
	},
})

var query := GFNetworkLobbyQuery.new()
query.required_tags = PackedStringArray(["ranked"])
query.required_metadata = { "mode": "duel" }
lobby_service.query_lobbies(query)
```

请求报告只说明 backend 是否接受了请求。异步平台应先返回 accepted，再通过 `lobby_created`、`lobby_joined`、`lobbies_queried` 等信号给出最终结果。

## Adapter 规则

平台 adapter 应只做转换，不应承载项目业务：

- 平台 lobby ID 转成 `GFNetworkLobbyDescriptor.lobby_id`。
- 平台用户 ID 转成 `GFNetworkPeerIdentity.platform_user_id`。
- 平台 owner、成员列表、容量、可见性和 metadata 转成 GF 快照。
- 平台邀请事件转成 `GFNetworkLobbyInvite`。
- 平台错误码转成稳定 `StringName` error，并把原始细节放入 metadata 或 details。

不应写入 adapter 的内容：

- 玩家准备状态、队伍、角色选择、聊天 UI、房间界面。
- 每日分享任务、好友赠送、排行榜 UI、活动奖励。
- 服务器权威、实体复制、预测、回滚或战斗同步策略。
- 任何固定平台 AppID、测试账号、项目场景路径或业务资源路径。

## 身份边界

`peer_id` 是传输层连接标识，`platform_user_id` 是外部平台账号标识。两者不能混用。

```gdscript
var identity := GFNetworkPeerIdentity.new().configure(
	peer_id,
	&"project_platform",
	external_user_id,
	display_name
)
```

项目可以在 identity `metadata` 中保存头像 URI、区域、段位或 adapter 状态，但 GF 不解释这些字段。需要鉴权、实名、封禁、好友关系或账号合并时，应由项目账号系统或外部平台 adapter 自己处理。

## 使用边界

Lobby 层不负责打开底层 socket，也不替代 `GFNetworkUtility` 的消息发送。常见组合是：

1. 用 `GFNetworkLobbyService` 完成 lobby 创建、查询或加入。
2. 从 lobby owner、endpoint 或平台连接信息中选择一个 `GFNetworkBackend`。
3. 用 `GFNetworkUtility` 建立传输并交换 `GFNetworkMessage`。
4. 用项目协议处理鉴权、同步、重连恢复和玩法状态。

这样 GF 保持统一接口，Steam、微信小游戏、LAN 和自建服务都只作为 adapter 挂接在外侧。
