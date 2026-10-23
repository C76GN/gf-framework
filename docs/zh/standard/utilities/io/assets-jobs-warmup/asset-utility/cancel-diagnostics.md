# 取消与诊断

`GFAssetLoadOperation.cancel()` 只撤销当前消费者的 pending 请求，立即提交 `CANCELLED` 并唤醒等待者。重复取消或成功、失败之后取消返回 false；成功后取消不会释放句柄。释放成功资源应关闭 scope 或调用句柄的 `release()`。

```gdscript
var scope: GFAssetScope = assets.create_scope(self)
var operation: GFAssetLoadOperation = assets.load_async(
	"res://ui/inventory_panel.tscn", scope, "PackedScene"
)
var cancelled: bool = operation.cancel()
var result: GFAssetLoadResult = await operation.wait_result_async()
scope.close()
```

同一路径的另一个 operation 保持有效。最后一个 Asset 消费者离开后，Asset 归还其 Broker lease；若底层也没有其他消费者，已发起的 Godot threaded request 进入 drain。逻辑取消不承诺中止物理加载。Broker 消费迟到结果，但不再交付给已取消消费者；无人消费的迟到结果也不重新填充 Asset 缓存。

scope 关闭会取消全部 pending operation，并释放全部成功句柄。完成是历史事实：已成功结果仍为成功，`result.get_handle().is_valid()` 则在释放后为 false。另一 scope 要延长持有，应独立 `load_async()` 或 `acquire_handle()`；没有默认所有权转移或单次领取协议。

使用[资源服务域](../resource-service-domain.md)时，operation 在接纳时已经绑定请求代次。保存旧 operation 后直接取消它，不需要再次提供路径和 generation，也不会误取消新代同路径请求。未取消的迟到结果仍按原请求代次交付。

`get_debug_snapshot()` 报告缓存、pending、queued、进度、pinned 路径、引用计数、分组数量、lane 活跃数、缓存诊断和 `resource_broker`。`pending_progress` 按路径索引，`queued_paths` 列出尚未进入 Asset lane 的请求，`cache_diagnostics` 汇总命中、写入、淘汰和失效。Broker 快照可观察 active、pending、draining 和共享预算。诊断路径描述物理工作，operation 描述消费者自己的请求。
