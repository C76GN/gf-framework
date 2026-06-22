# 输入缓冲与宽容窗口

如果项目需要“提前输入仍能在短时间内执行”或“状态刚刚失效后仍保留一个宽容窗口”这类手感规则，可以注册 `GFInputAssistUtility`。它的 API 会明确写出 `buffered` 和 `grace_window`，避免和 `GFInputMappingUtility.consume_action()` 的“消费本帧刚触发动作”混淆。

```gdscript
var input_map := Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
var input_assist := Gf.get_utility(GFInputAssistUtility) as GFInputAssistUtility

if input_map.consume_action(&"jump"):
	input_assist.buffer_action(&"jump", 0.15)

if can_jump_now and input_assist.consume_buffered_action(&"jump"):
	perform_jump()

input_assist.start_grace_window(&"grounded", 0.1)
if input_assist.is_grace_window_active(&"grounded"):
	# 项目层自行决定这个窗口能放宽哪些动作。
	pass
```

如果项目需要在宽容窗口自然倒计时结束时执行一次性逻辑，可以监听 `grace_window_expired(window_id, player_index)`。`cancel_grace_window()`、`clear_player()` 和 `clear_all()` 属于显式清理，不会触发这个自然过期信号。

本地多人项目可以传入 `player_index` 让动作缓冲和宽容窗口按玩家隔离；全局输入辅助则继续使用默认的 `-1`。
