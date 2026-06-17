# 取消与诊断

`cancel()` 只取消 GF 侧的回调分发并把请求标记为已取消，不会中止 Godot 已发起的 `ResourceLoader` 线程请求。

```gdscript
if assets.is_loading("res://ui/inventory_panel.tscn", "PackedScene"):
	assets.cancel("res://ui/inventory_panel.tscn", "PackedScene")
```

如果资源随后成功完成，已取消请求不会再写入缓存，避免项目显式取消后又被迟到结果重新命中。需要重新使用该资源时，发起新的加载请求即可。

`get_debug_snapshot()` 会报告缓存、pending、pending 进度、pinned 路径、引用计数和资源分组数量，便于诊断面板或测试读取。`pending_progress` 是按资源路径索引的 `Dictionary[String, float]`；诊断面板可以用它展示当前队列，也可以对单个路径调用 `get_load_progress(path)`。
