# 取消与诊断

`cancel()` 只取消 GF 侧的回调分发并把请求标记为已取消，不会中止 Godot 已发起的 `ResourceLoader` 线程请求。取消后的底层 threaded request 会进入 drain 状态；如果 Godot 之后返回成功或失败，GF 会消费这个迟到结果并把它标记为 suppressed，不再写入缓存或触发原请求 callback。

```gdscript
if assets.is_loading("res://ui/inventory_panel.tscn", "PackedScene"):
	assets.cancel("res://ui/inventory_panel.tscn", "PackedScene")
```

如果资源随后成功完成，已取消请求不会再写入缓存，避免项目显式取消后又被迟到结果重新命中。若同一路径在底层 request 终止前再次发起加载，GF 会复用仍在进行的 operation 并重新持有消费者引用；若迟到结果已经被 drain 完成，后续请求会重新发起新的 threaded load。

`get_debug_snapshot()` 会报告缓存、pending、queued、pending 进度、pinned 路径、引用计数、资源分组数量、加载通道活跃数、缓存诊断计数和 `threaded_resource_operations`，便于诊断面板或测试读取。`pending_progress` 是按资源路径索引的 `Dictionary[String, float]`；`queued_paths` 列出尚未开始的资源请求；`cache_diagnostics` 包含命中、未命中、写入、淘汰和失效原因统计；`threaded_resource_operations` 可观察正在加载、draining、已 suppress 的底层 ResourceLoader operation。诊断面板可以用这些字段展示当前队列，也可以对单个路径调用 `get_load_progress(path)`。
