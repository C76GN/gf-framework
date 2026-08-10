# 查询签名与缓存诊断

`GFQuerySignature` 用于把一组查询条件整理成稳定签名。调用方按领域名追加值或布尔开关，签名会保留领域隔离、值类型和排序后的文本表示，适合用作查询缓存 key、调试日志或测试断言。

```gdscript
var signature := GFQuerySignature.new()
signature.add_value(&"tag", "visible")
signature.add_values(&"layer", [1, 2])
signature.add_flag(&"include_hidden", false)

var cache_key := signature.to_text()
var cache_hash := signature.to_hash()
```

签名只描述“哪些条件参与了查询”，不解释字段来源、权限、缓存失效策略或项目业务语义。需要跨进程或写入文件时，可使用 `to_dictionary()` 和 `from_dictionary()` 保留同一结构。

`GFCacheDiagnostics` 是轻量缓存计数器，可记录命中、未命中、写入、淘汰和失效原因，并输出 `get_debug_snapshot()`。它不持有缓存内容，也不会决定何时淘汰；实际策略仍由调用方实现。

所有计数使用 int64 饱和加法：达到上界后保持 `INT64_MAX`，不会回绕为负数。发生无法表示的继续增长时，快照中的 `counter_saturated` 为 `true`；`reset()` 会同时清除计数与该诊断标记。

```gdscript
var diagnostics := GFCacheDiagnostics.new()
diagnostics.cache_id = &"thumbnail_cache"

diagnostics.record_miss("res://icons/a.png")
diagnostics.record_write("res://icons/a.png")
diagnostics.record_hit("res://icons/a.png")

print(diagnostics.get_hit_ratio())
print(diagnostics.get_debug_snapshot())
```

`GFAssetUtility` 已接入这套诊断计数，资源缓存命中率、写入、手动清理和 LRU 淘汰会出现在资源工具的调试快照中。其他缓存可以复用同一类，以便诊断面板用统一字段读取。
