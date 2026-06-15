# 双端队列

`GFDeque` 是轻量双端队列，适合保存短历史、命令缓冲、待处理队列或其它需要从头尾稳定追加和移除的运行时数据。它只维护元素顺序和底层容量，不规定元素含义、排序优先级、任务状态或淘汰策略。

```gdscript
var history := GFDeque.new()
history.push_back({ "tick": 10, "value": player_position })
history.push_back({ "tick": 11, "value": player_position })
history.trim_front(120)

var latest := history.peek_back()
```

## 常用操作

`push_front()` / `push_back()` 从两端追加元素；`pop_front()` / `pop_back()` 从两端移除并返回元素；`peek_front()` / `peek_back()` 只读取不移除。`at()` 和 `set_at()` 按队列顺序访问元素，并支持负索引从队尾倒数。

```gdscript
var queue := GFDeque.from_array(["prepare", "run"])
queue.push_front("warmup")
queue.push_back("cleanup")

var first := queue.pop_front()
var last := queue.peek_back()
```

## 裁剪与复制

`trim_front(max_size)` 会丢弃队头多余元素，常用于保留最近 N 条记录；`trim_back(max_size)` 会丢弃队尾多余元素，常用于保留较早的 N 条记录。`to_array()` 按队列顺序导出数组，`duplicate_deque(true)` 可深拷贝嵌套的 `Array`、`Dictionary` 或可复制资源。

`GFDeque` 不负责优先级排序、去重、生命周期管理或多线程同步。需要按字段查询时使用 `GFValueIndex`；需要批量提交/回滚时使用 `GFMutationBatch`；需要业务任务状态时使用上层队列工具或项目自己的调度层。
