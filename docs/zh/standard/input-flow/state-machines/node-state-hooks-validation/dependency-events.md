# 依赖代理与事件注册

`GFNodeState` 与纯代码 `GFState` 保持同一套架构代理。状态可以在进入、退出或事件处理中读取 Model、System、Utility，也可以发送命令、查询和事件。

## 可用代理

- `get_model()`
- `get_system()`
- `get_utility()`
- `send_command()`
- `send_query()`
- `send_event()`
- `send_simple_event()`
- `register_event()`
- `register_assignable_event()`
- `register_simple_event()`
- `unregister_owner_events()`

这些代理会优先解析最近的 `GFNodeContext`，再回退全局 `Gf` 架构。

## 状态内监听

监听只在状态激活期间有效时，应在 `_exit()` 中调用 `unregister_owner_events()`。

```gdscript
class_name AttackState
extends GFNodeState


var _combat_model: CombatModel


func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	_combat_model = get_model(CombatModel) as CombatModel
	register_event(AnimFinishedPayload, GFEventListener.from_method(self, &"_on_anim_finished", 1))


func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	unregister_owner_events()


func _on_anim_finished(payload: AnimFinishedPayload) -> void:
	if payload.animation_name == &"attack":
		transition_to(&"Idle")
```

## 使用边界

状态脚本可以借助代理访问架构，但不应在状态之间共享临时监听所有权。跨状态长期监听更适合放在宿主 Controller、System 或明确的长期模块中。
