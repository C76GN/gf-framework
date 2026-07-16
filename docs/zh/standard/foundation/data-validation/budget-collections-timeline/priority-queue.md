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

## 使用边界

`GFPriorityQueue` 不管理任务状态、线程安全、生命周期、去重策略或业务执行结果。需要两端队列时使用 `GFDeque`；需要字段查询时使用 `GFValueIndex`；需要后台线程、资源加载或主线程 apply 队列时使用对应 Utility。
