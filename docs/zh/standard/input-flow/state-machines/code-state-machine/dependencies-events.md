# 依赖代理与事件监听

状态内部访问框架依赖时，应使用 `get_model()`、`get_system()`、`get_utility()`、`send_command()`、`send_query()` 这些状态机代理。

这些代理会沿着创建 `GFStateMachine.new(context)` 时传入的上下文解析架构，适配局部 `GFNodeContext`；只有明确要访问全局架构时才直接调用 `Gf`。

对于每帧移动输入、速度、冷却这类简单热路径读取，优先在 `enter()` 或状态持有者初始化时缓存 Model/Utility，再直接读取；Query 更适合封装跨模块派生结果或表现层不应理解的组合读取。

## 切换优先级

`change_state()` 只负责请求状态机切换，不能替调用它的 `update()` 自动结束后续代码。一个状态内同时判断移动、攻击、受击等条件时，应按优先级使用 `return` 或 `elif`，避免同一帧连续触发多个切换：

```gdscript
## 同一帧优先响应攻击；提交切换后立即结束本状态的后续判断。
func update(_delta: float) -> void:
	if _input_map_util.consume_action(&"light_attack"):
		change_state(&"Attack")
		return

	if _input_model.move_value.x != 0:
		change_state(&"Run")
		return
```

## 事件监听

`GFState` 也提供和 `GFSystem` / `GFUtility` / `GFController` 风格一致的事件代理：`register_event()`、`register_assignable_event()`、`register_simple_event()` 会以当前状态作为 owner 注册监听；`dispose()` 会做最终兜底清理。

若监听只在该状态激活期间有效，应在 `exit()` 里调用 `unregister_owner_events()`：

```gdscript
## 将动画监听绑定到本次激活期间，owner 为当前状态实例。
func enter(_msg: Dictionary = {}) -> void:
	register_event(AnimFinishedPayload, GFEventListener.from_method(self, &"_on_anim_finished", 1))


## 退出即撤销监听，防止非激活状态响应后续动画事件。
func exit() -> void:
	unregister_owner_events()


## 只把本次攻击动画的结束解释为返回待机。
func _on_anim_finished(payload: AnimFinishedPayload) -> void:
	if payload.animation_name == &"attack":
		change_state(&"Idle")
```
