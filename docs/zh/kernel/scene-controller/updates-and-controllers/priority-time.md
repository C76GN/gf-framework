# 优先级与时间缩放

将 System 解耦到纯代码架构容器后，核心更新顺序、暂停和时间缩放可以集中处理。

## Tick 优先级

默认情况下，模块会按注册进入 tick 缓存的顺序转发更新，并在 tick 遍历期间延迟刷新缓存，避免动态注销模块破坏本轮遍历。

需要表达明确依赖时，可以设置 `GFSystem.tick_priority` / `GFUtility.tick_priority` 或 `physics_tick_priority`。数值越大越早执行，默认 `0` 表示同优先级下继续按注册顺序执行。

```gdscript
var input_system := InputCollectSystem.new()
input_system.tick_priority = 100

var battle_system := BattleSystem.new()
battle_system.tick_priority = 0

assert(await Gf.register_system(input_system))
assert(await Gf.register_system(battle_system))
```

未重写 `tick()` / `physics_tick()` 且未显式启用对应标记的 System 不会进入缓存。这能减少空模板调用，同时让诊断快照中的 `has_tick` / `has_physics_tick` 更接近真实热路径。

生命周期顺序首先由声明依赖 DAG 决定。`lifecycle_priority` 只在多个依赖已经满足的节点之间破平：数值越大，`init()`、`async_init()`、`ready()` 和 `begin_activation()` 越早执行；正常关闭按同一计划严格逆序执行 `begin_quiesce()`，随后同步释放。优先级不能覆盖依赖边，也不应替代项目自己的流程状态机或命令队列。

## 时间缩放

注册 `GFTimeUtility` 后，表现层动画可以继续利用真实时间正常播放，而底层 `GFSystem` 与参与 tick 的 `GFUtility` 会统一接受受缩放系数调整的 `delta`。如果将缩放系数设为 `0`，核心逻辑即可全局暂停，适合 Hit Stop 或子弹时间。
