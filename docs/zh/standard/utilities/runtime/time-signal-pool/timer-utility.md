# 逻辑延迟定时器

Godot 的 `get_tree().create_timer(1.0).timeout` 与场景树绑定。如果等待期间切换场景，临时节点或控制器容易留下失效回调。需要受 `GFTimeUtility` 控制、可按 owner 自动清理的逻辑计时时，使用 `GFTimerUtility`。

## 基础用法

```gdscript
var timer_util := Gf.get_utility(GFTimerUtility) as GFTimerUtility

# 延迟 1.5 秒后执行一次回调
timer_util.execute_after(1.5, func() -> void:
	print("1.5秒逻辑时间后触发")
)

var handle := timer_util.execute_repeating(0.25, func() -> void:
	print("tick")
, 4)

timer_util.execute_after_owned(self, 2.0, func() -> void:
	print("owner 仍然存在时才会触发")
)
```

`execute_after()` 处理一次性延迟任务；`execute_repeating()` 处理固定间隔任务，`repeat_count < 0` 表示无限重复。

`execute_after_owned()` / `execute_repeating_owned()` 会用弱引用追踪 owner，owner 释放后任务自动丢弃，适合 UI、临时场景对象或短生命周期控制器注册逻辑计时。

排队成功时会返回大于 `0` 的句柄，可用 `cancel(handle)` 取消，或用 `cancel_owner(owner)` 批量取消同一 owner 的任务。

所有秒数输入都必须是有限浮点数。一次性任务的有限 `delay <= 0` 会同步执行并返回 `0`；重复任务要求 `interval > 0`，有限 `initial_delay < 0` 表示使用 `interval`。`NaN`、`+INF` 和 `-INF` 会在创建任务前被拒绝并返回 `0`，不会留下永久 pending 记录。

同一次 `tick()` 中，到期任务在各自回调真正开始前仍可取消。较早回调调用 `cancel(handle)`、`cancel_owner(owner)`、`init()` 或 `dispose()` 时，尚未进入回调的同批到期任务不会继续执行；生命周期重置也不会让旧任务借助重新使用的句柄进入新队列。

它由架构 tick 传入的逻辑 delta 推进；通常会自然受到 `GFTimeUtility` 的缩放和暂停结果影响，但如果项目手动调用 `timer_util.tick(delta)`，传入什么 delta 就按什么时间推进。

`get_debug_snapshot()` 可查看 pending 数量、句柄和 owner 绑定任务数量；框架 `dispose()` 时会清空尚未触发的任务。

## 手动整数 Tick

测试、回放或服务器模拟需要完全确定的整数时间时，使用 `GFManualTimerQueue`。`advance_to()` / `advance_by()` 是队列唯一的 drain 边界；回调中再次推进同一队列会立即返回 `status = advance_in_progress`，不会绕过外层的 `max_callbacks` 预算。回调调用 `clear()` 时会使本轮旧生命周期失效，外层推进不会再把旧目标 tick 写回已经清空的队列。
