# Simple Event

Simple Event 使用非空 `StringName` 作为稳定事件 ID，可以不带 payload，也可以携带少量 `Variant` 数据。它适合轻量状态通知，例如菜单打开、玩家跳跃或分数变化。

如果事件需要消费拦截、序列化、校验或复杂上下文，请改用 [Type Event](type-events/index.md)。

## 发送事件

```gdscript
# 发出简单无参数的事件通知，耗时极低
Gf.send_simple_event(&"EVENT_PLAYER_JUMPED")

# 也可以携带少量 Variant payload
Gf.send_simple_event(&"EVENT_SCORE_CHANGED", { "score": 1200 })
```

## 接收事件

```gdscript
func ready() -> void:
	# 注册监听，并绑定到自身的回调函数
	register_simple_event(&"EVENT_PLAYER_JUMPED", GFEventListener.from_method(self, &"_on_player_jumped", 1))

func _on_player_jumped(_payload: Variant) -> void:
	print("UI 显示：成功跳跃！")

func dispose() -> void:
	unregister_simple_event(&"EVENT_PLAYER_JUMPED", GFEventListener.from_method(self, &"_on_player_jumped", 1))
```

## 命名约束

简单事件 ID 必须稳定且非空，空 `StringName` 会被拒绝。建议使用能表达来源和语义的事件名，例如 `&"ui_opened"` 或 `&"combat_hit_resolved"`，不要把临时通知塞进无名通道。

Simple Event 不直接接受整数 key。这是有意的契约：`StringName` 可以表达来源和语义，跨日志、诊断和模块边界仍可读；裸整数容易与其他协议域碰撞，也会在 enum 重排后改变含义。

项目确实需要把固定协议号映射为事件时，应在协议适配层集中规范化，并保证发送与监听复用同一个函数：

```gdscript
static func protocol_event_id(message_code: int) -> StringName:
	return StringName("protocol.message:%d" % message_code)


var event_id: StringName = protocol_event_id(MessageType.RES_NPC_CHAT)
Gf.listen_simple(event_id, GFEventListener.from_method(self, &"_on_receive_chatnpc", 1))
Gf.send_simple_event(event_id, payload)
```

协议 enum 应显式固定数值，不能依赖声明顺序。需要结构校验、来源身份、序列号或网络拒包原因时，不应继续扩张 Simple Event，而应使用 Type Event 或项目协议分发层。

普通模块应优先使用 owner 绑定监听，详见 [监听器所有权与生命周期](owner-lifecycle.md)。
