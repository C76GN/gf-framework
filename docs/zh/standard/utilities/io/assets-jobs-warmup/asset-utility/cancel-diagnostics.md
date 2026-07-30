# 取消与诊断

`cancel()` 会释放 Asset Utility 持有的消费者 `GFResourceLease`，停止当前请求的回调分发和缓存写入，但不会中止 Godot 已发起的 `ResourceLoader` 线程请求。若它是最后一个消费者，底层 threaded request 会进入 drain 状态；Godot 之后返回成功或失败时，Broker 会消费迟到结果，但不再交付给已取消消费者。

```gdscript
if assets.is_loading("res://ui/inventory_panel.tscn", "PackedScene"):
	assets.cancel("res://ui/inventory_panel.tscn", "PackedScene")
```

如果资源随后成功完成，已取消请求不会再写入缓存，避免项目显式取消后又被迟到结果重新命中。若同一路径在底层 request 终止前再次发起加载，Broker 会为新请求创建独立 Lease 并复用仍在进行的底层加载；若迟到结果已经 drain 完成，后续请求会重新发起 threaded load。

`get_debug_snapshot()` 会报告缓存、pending、queued、pending 进度、pinned 路径、引用计数、资源分组数量、加载通道活跃数、缓存诊断计数和 `resource_broker`，便于诊断面板或测试读取。`pending_progress` 是按资源路径索引的 `Dictionary[String, float]`；`queued_paths` 列出尚未进入 Asset lane 的资源请求；`cache_diagnostics` 包含命中、未命中、写入、淘汰和失效原因统计；`resource_broker` 可观察 active、pending、draining、独占 admission 和共享预算。诊断面板可以用这些字段展示当前队列，也可以对单个路径调用 `get_load_progress(path)`。
