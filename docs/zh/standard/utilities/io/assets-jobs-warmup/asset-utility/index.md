# 异步资源加载与缓存

`GFAssetUtility` 统一处理 `ResourceLoader` 请求、并发加载合并、缓存、取消、资源句柄和资源分组。

## 阅读入口

- [异步加载与 LRU 缓存](async-cache.md)：按需加载资源、缓存命中、并发请求合并、`type_hint` 和 LRU 上限。
- [取消与诊断](cancel-diagnostics.md)：取消语义、迟到结果处理和 `get_debug_snapshot()`。
- [资源句柄与分组预热](handles-groups.md)：`GFAssetHandle`、owner 释放、缓存 pin 和资源分组预加载。
- [通用资源注册表](resource-registry.md)：`GFResourceRegistry`、稳定资源 ID、字段索引、同步加载和与 `GFAssetUtility` 的显式衔接。
- [资源解析器](resource-resolver.md)：`GFResourceResolverUtility`、资源键解析、provider 覆盖链、直接路径回退和 AssetUtility 衔接。

## 使用边界

`GFAssetUtility` 只管理 `ResourceLoader` 请求、回调分发和内存缓存，不负责实例化节点、引用计数之外的资源生命周期或远程下载。
