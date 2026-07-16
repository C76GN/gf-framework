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

普通模块应优先使用 owner 绑定监听，详见 [监听器所有权与生命周期](owner-lifecycle.md)。
