# 优先队列

`GFPriorityQueue` 是稳定优先队列，适合任务启动顺序、通知候选、编辑器批处理、AI 候选或其它只需要“按优先级取下一个值”的通用场景。

```gdscript
var queue := GFPriorityQueue.new()
queue.push("normal", 0)
queue.push("urgent", 10)
queue.push("front", 0, true)

var next := queue.pop()
```

默认是高 `priority` 先弹出；构造时传 `false` 可改为低 `priority` 先弹出。`priority` 使用数值比较，整数和浮点代价都可直接入队。相同优先级保持稳定顺序，`front=true` 可把新条目插到同优先级既有条目前面。

## 常用操作

`push()` 写入值和数值优先级；`push_with_order()` 允许调用方显式指定同优先级下的稳定顺序，适合寻路、最小生成树或其它已有 sequence 的算法复用同一队列。`peek()` / `peek_priority()` 查看当前顶部；`pop()` 弹出当前顶部。`remove_value()`、`remove_all()` 和 `set_priority()` 用于取消或调整已排队条目。

```gdscript
queue.push(task, task.priority)
queue.set_priority(task, 20)

if queue.has_value(task):
	queue.remove_value(task)
```

`to_array()` 和 `to_entry_array()` 会按弹出顺序导出副本，不会修改当前队列。`duplicate_priority_queue(true)` 可复制队列和嵌套值。

## 长时间运行的工作队列

如果队列会持续收到更高优先级工作，静态优先级可能让早期低优先级项一直排不到。此时使用 `GFPriorityWorkQueue`：它在基础优先级上按等待时间增加无上限的 aging 加成，同时保留稳定同优先级顺序。

```gdscript
var work_queue := GFPriorityWorkQueue.new()
work_queue.aging_interval_msec = 500
work_queue.aging_step = 1.0
work_queue.max_size = 256

work_queue.push(background_task, 0.0)
work_queue.push(player_visible_task, 10.0)
var next_task := work_queue.pop()
```

例如资源预处理队列里，玩家当前可见资源可以保持较高基础优先级，而早先排入的缓存维护工作会随等待逐步追上，不会因为新资源不断到来而永久饥饿。这个保证成立的前提是调用方持续消费队列，且后来任务的基础优先级存在有限上界；项目若不断写入无限增大的优先级，任何通用队列都无法保证旧任务先执行。

`push_at()`、`pop_at()` 与 `peek_at()` 接受显式单调毫秒时间，适合确定性测试、模拟和恢复同一进程时间域内的调度状态。`to_entry_array()` / `get_debug_snapshot()` 会返回指定时刻的 `priority`、`effective_priority`、`waited_msec` 和稳定 `order`；排序会随时间变化，因此这些结果是诊断快照，不是持久化后的固定执行计划。

## 使用边界

`GFPriorityQueue` 与 `GFPriorityWorkQueue` 都不管理任务状态、线程安全、生命周期、去重策略或业务执行结果。前者适合算法或一次性批次中的静态顺序，后者适合持续消费且需要防饥饿的运行队列。需要两端队列时使用 `GFDeque`；需要字段查询时使用 `GFValueIndex`；需要后台线程、资源加载或主线程 apply 队列时使用对应 Utility。
