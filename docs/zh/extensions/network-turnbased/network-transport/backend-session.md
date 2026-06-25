# 后端与 Session

`GFNetworkUtility` 把消息编码、后端传输和运行时信号分开。框架提供 `GFNetworkMessage`、`GFNetworkSerializer`、`GFNetworkBackend`、`GFNetworkRateLimiter`、`GFNetworkSession`、`GFNetworkChannel`、`GFNetworkMessageValidator`、可选 `GFENetNetworkBackend` 与 `GFWebSocketNetworkBackend`，但不内置具体服务器、房间、平台账号或业务同步规则。

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

`GFNetworkSession` 只记录后端连接意图和状态快照。`host()` 会在后端真正返回成功或报告 connected 后再标记 `has_connection`；如果后端启动失败，会关闭本次会话而不会短暂发出 connected 状态。

`options.metadata` 必须是 `Dictionary`，传入其他类型会被忽略并输出 warning，避免把错误配置静默保存到会话快照里。替换或清空 backend 时，`GFNetworkUtility` 会关闭旧后端并清理旧会话，避免把底层连接资源留给已失效的 backend。

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
