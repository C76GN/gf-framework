# 命名队列与生命周期

默认队列适合单条表现流。如果战斗、对白、教程提示需要互不阻塞，可以使用命名队列。

## 命名队列

```gdscript
var q_sys := Gf.get_system(GFActionQueueSystem) as GFActionQueueSystem

q_sys.enqueue_to(&"battle", PlayHitAction.new(enemy))
q_sys.enqueue_to(&"dialogue", ShowLineAction.new("hello"))
q_sys.enqueue_parallel_to(&"tutorial", [
	HighlightAction.new(button),
	TooltipAction.new(button),
])
```

命名队列由创建它的 `GFActionQueueSystem` 拥有。父队列或所属架构销毁时，会递归取消命名子队列中的等待动作并释放依赖作用域。

项目层不应长期缓存已被父队列销毁后的命名队列引用。后续需要同名表现流时，重新通过 `get_named_queue()` 或 `get_linked_queue()` 获取。`clear_all_named_queues(stop_current)` 会取消并释放当前父队列拥有的命名流；调用后旧子队列引用视为失效。

## 节点绑定队列

临时 UI 或实体可以创建绑定节点生命周期的队列。绑定节点释放后，队列会取消当前动作并清空待执行动作：

```gdscript
var popup_queue := q_sys.get_linked_queue(&"popup_intro", popup_node)
popup_queue.enqueue(FadeInAction.new(popup_node))
```

## 队列控制

如需跳过当前表现动作并继续后续队列，可以调用：

```gdscript
q_sys.skip_current_action()
```

运行时如果需要控制当前表现，可调用 `pause_current_action()`、`resume_current_action()`、`finish_current_action()` 或 `skip_current_action()`。自定义动作可以重写 `pause()`、`resume()`、`finish()` 和 `cancel()` 响应这些控制。

队列控制只表达表现时序，不应承担回合结算、伤害结果或剧情状态修改。
