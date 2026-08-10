# 可观察集合资源

`GFObservableArrayResource` 与 `GFObservableDictionaryResource` 适合把资源化集合暴露给 UI、编辑器工具、轻量状态同步或诊断面板。它们不会伪装成完整的 `Array` / `Dictionary`，也不会拦截直接字段写入；需要通知观察者时，应通过 `append_item()`、`set_item()`、`set_value()`、`erase_value()`、`clear_*()` 等显式方法提交变更。

```gdscript
var items := GFObservableArrayResource.new()
items.items_changed.connect(func(changes: Array[Dictionary], metadata: Dictionary) -> void:
	print(changes.size(), metadata)
)

items.begin_batch({ "source": "inventory-import" })
items.append_item({ "id": "potion", "count": 3 })
items.append_item({ "id": "key", "count": 1 })
items.end_batch()
```

单项变更会发出 `item_changed` / `entry_changed`，同时也会发出一次批量信号，方便只关心“集合已变化”的调用方统一监听。`begin_batch()` / `end_batch()` 期间会暂存变更，最终只发出一次 `items_changed` / `entries_changed`；batch 内不会在结束时补发每个单项的 `item_changed` / `entry_changed`。需要高效刷新列表、表格或 Inspector 时，监听 aggregate signal；需要即时响应单项变更时，只在非 batch 路径监听 item-level signal。

两种资源的单项和 batch aggregate 通知都经过同一 FIFO 派发队列。同步监听器可以立即修改集合，但由该修改产生的下一组通知会等当前细粒度/aggregate/Resource `changed` 序列完成后再派发；有限层数的 aggregate 重入不会转化为同等深度的调用栈。

这两个资源只描述“集合内容发生了什么变化”。字段含义、冲突合并、撤销历史、网络同步协议、UI 渲染和持久化策略都应由项目层或上层 Utility 组合。
