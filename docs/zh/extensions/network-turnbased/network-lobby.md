# Network Lobby 与平台 Adapter 边界

`GFNetworkLobbyService` 和 `GFNetworkLobbyBackend` 描述平台中立的房间生命周期。它们只表达创建、查询、加入、离开、metadata 更新、成员变化、邀请和错误，不内置 Steam、微信、Epic、主机平台、LAN 或自建匹配服 SDK。

## 类型化操作模型

- `GFNetworkLobbyOperationRequest`：唯一 `request_id`、操作类型、目标 Lobby、查询、载荷、超时和 Provider 选项。
- `GFNetworkLobbyOperationHandle`：调用方持有的一次性句柄。成功、失败、取消和超时只能产生一个终态。
- `GFNetworkLobbyOperationResult`：保留请求关联、稳定状态、耗时、单个 Lobby 或查询列表。
- `GFNetworkLobbyBackend`：Adapter 实现 `_dispatch_operation()`，把 Provider callback 按请求 ID 映射回句柄。
- `GFNetworkLobbyService`：生成请求 ID、执行单调超时、协调取消和 Backend 替换，并维护当前与已知 Lobby 快照。
- `GFNetworkLobbyDescriptor`、`GFNetworkLobbyMember`、`GFNetworkPeerIdentity`、`GFNetworkLobbyQuery` 和 `GFNetworkLobbyInvite`：平台中立的数据边界。

```gdscript
var lobby_service := Gf.get_utility(GFNetworkLobbyService) as GFNetworkLobbyService
if not lobby_service.set_backend(project_lobby_backend):
	push_error("Lobby backend rejected the service clock.")
	return

var handle := lobby_service.create_lobby({
	"max_members": 4,
	"metadata": {"mode": "duel"},
	"timeout_msec": 15_000,
})
if handle.is_pending():
	await handle.completed

var result := handle.get_result()
if not result.ok:
	push_error("Lobby create failed: %s" % result.status)
	return
var lobby := result.lobby
```

`request_id`、`timeout_msec` 和调用方 `metadata` 由 Service 消费；其余 `options` 进入 `request.provider_options`，供 Adapter 映射 Provider 参数。项目业务字段不应被提升为 GF 固定属性。

查询和更新同样返回句柄：

```gdscript
var query := GFNetworkLobbyQuery.new()
query.required_tags = PackedStringArray(["ranked"])
query.required_metadata = {"mode": "duel"}

var query_handle := lobby_service.query_lobbies(query, {
	"request_id": &"ranked_rooms_refresh",
})
```

## Backend 实现规则

Adapter 只重写 `_dispatch_operation()`、`_cancel_operation()`、`_poll()` 和 `_close()`。必须先保存 Provider call ID 与 Handle 的关联，再发起可能同步回调的 SDK 调用：

```gdscript
func _dispatch_operation(
	request: GFNetworkLobbyOperationRequest,
	handle: GFNetworkLobbyOperationHandle
) -> bool:
	var provider_call_id := String(request.request_id)
	_calls[provider_call_id] = handle
	_start_provider_call(provider_call_id, request)
	return true


func _on_provider_completed(provider_call_id: String, lobby: GFNetworkLobbyDescriptor) -> void:
	var handle: GFNetworkLobbyOperationHandle = _take_handle(provider_call_id)
	if handle != null:
		var _completed := _succeed_operation(handle, {"lobby": lobby})
```

Adapter 应遵守以下约束：

- Provider Lobby ID 转为 `GFNetworkLobbyDescriptor.lobby_id`，账号 ID 转为 `GFNetworkPeerIdentity.platform_user_id`；`peer_id` 仍是传输连接身份，两者不得混用。
- Provider 错误映射为稳定 `StringName`，原始且已脱敏的诊断信息放入 result metadata 或 `backend_error.details`。
- 取消与超时先形成本地终态，再通知 Provider；迟到或重复 callback 不得覆盖结果。
- Handle 终态不等于 Provider 已停止；同步取消完成时调用 `_release_operation()`，否则让迟到成功/失败回调释放 request ID 租约。
- `set_backend()` 会取消等待操作、断开旧事件并关闭旧 Backend。Adapter 不得把底层调用留给已失效实例。
- `lobby_updated`、`member_joined`、`member_left`、`invite_received` 只表达非请求驱动事件；请求完成必须通过对应 Handle 关联。
- `current_lobby` 只在成功的 create/join/leave 结果后变化，失败请求不得伪造状态变化。

## Activation Intent

平台启动参数、好友邀请和外部 Join 回调属于 `GFPlatformActivationIntent`。Adapter 应生成 Provider 稳定的 `intent_id` 并通过 `GFPlatformAdapter._publish_activation_intent()` 发布；`GFPlatformRuntime` 会去重、限制队列容量，并允许项目显式消费或确认。Lobby Backend 不应直接打开 UI 或切换场景。

## 与传输层组合

Lobby 不负责打开 socket，也不替代 `GFNetworkUtility`：

1. 使用 `GFNetworkLobbyService` 完成 Lobby 操作。
2. 根据成功结果选择项目认可的传输实现。
3. Provider 已返回 Godot `MultiplayerPeer` 时，使用 `GFMultiplayerPeerNetworkBackend.adopt_peer()` 并明确 `OWNED` 或 `BORROWED`。
4. 使用 `GFNetworkUtility`、`GFNetworkMessage` 与项目协议处理鉴权、同步、权限和重连。

玩家准备、队伍、角色选择、匹配算法、服务器权威、房间 UI、奖励、商店和平台回退仍由项目拥有。Adapter 只翻译能力，不决定产品行为。

## 迁移

旧的“请求立即返回 accepted `Dictionary`，最终结果再从多个信号接收”模式已移除。迁移时保存每次调用返回的 `GFNetworkLobbyOperationHandle`，从 `get_result()` 读取 `GFNetworkLobbyOperationResult`；`lobby_created`、`lobbies_queried`、`lobby_joined` 和 `lobby_left` 仍保留，但参数统一改为该类型化 Result。`set_backend()` 现在返回 `bool`，调用方必须处理时钟注入失败。删除 `GFNetworkLobbyJoinResult` 与旧 Backend 公共操作覆写，改为实现 `_dispatch_operation()`。
