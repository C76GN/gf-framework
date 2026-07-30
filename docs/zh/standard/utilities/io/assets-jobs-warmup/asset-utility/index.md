# 异步资源加载与缓存

`GFAssetUtility` 统一处理 `ResourceLoader` 请求、并发加载合并、缓存、取消、资源句柄和资源分组；底层 threaded request 由显式注入的 `GFResourceBroker` admission。需要把一组资源预热清单保存成项目资源时，可以用 `GFAssetPreloadPlan` 描述路径、分组、pin 策略和加载约束，再交给 `GFAssetUtility.preload_plan_async()` 执行。需要把加载状态传给 UI、日志或项目自定义资源流程时，可以用 `GFResourceLoadState` 表达资源键、路径、状态、进度、错误、资源身份和弱/强引用模式。

## 阅读入口

- [异步加载与 LRU 缓存](async-cache.md)：按需加载资源、缓存命中、并发请求合并、`type_hint` 和 LRU 上限。
- [共享 Resource Broker](../resource-broker.md)：显式注入、消费者 Lease、有界 admission、跨 Utility 复用和 drain。
- [取消与诊断](cancel-diagnostics.md)：取消语义、迟到结果处理和 `get_debug_snapshot()`。
- [资源句柄与分组预热](handles-groups.md)：`GFAssetHandle`、owner 释放、缓存 pin、`GFAssetPreloadPlan` 和资源分组预加载。
- [显式 Live Asset Slot](live-asset-slot.md)：`GFAssetSlot`、稳定资源身份、受控替换、generation 与终态释放。
- [通用资源注册表](resource-registry.md)：`GFResourceRegistry`、稳定资源 ID、字段索引、同步加载和与 `GFAssetUtility` 的显式衔接。
- [资产目录与素材库底座](asset-catalog.md)：`GFAssetCatalog`、资产条目、source provider 汇聚、标签/分类查询和素材库索引边界。
- [资源解析器](resource-resolver.md)：`GFResourceResolverUtility`、资源键解析、provider 覆盖链、直接路径回退和 AssetUtility 衔接。
- [资源图、脚本结构、变体、Feature 重映射、Patch、Artifact 与导入计划](resource-graph-variants-artifacts.md)：`GFResourceGraphScanner`、`GFScriptStructureTools`、`GFResourceVariantProvider`、`GFResourceFeatureRemapTools`、`GFResourcePropertyPatch`、`GFRawResourceArtifact` 和 `GFImportPlan`。

## 资源状态快照

`GFResourceLoadState` 不发起加载请求，也不替代 `GFAssetHandle`。它只是一个可复制的状态对象，适合把“请求中、加载中、已加载、失败、释放、过期”这些状态交给 UI、诊断面板或项目侧资源队列：

```gdscript
var state := GFResourceLoadState.new()
state.configure(&"ui.inventory.icon", "res://ui/icons/inventory.png")
state.mark_requested({ "group": "ui" })
state.mark_loading(0.4)

var resource := await load_icon_async()
state.mark_loaded(resource)

var snapshot := state.to_dictionary()
```

`to_dictionary()` 会包含 `resource_identity`，其中记录 raw path、canonical path、`uid://`、scheme、extension、cache key 和存在性。需要单独读取身份时调用 `get_resource_identity()`；`GFResourceIdentity` 不加载资源，也不替代注册表、resolver 或内容包 manifest，但 `GFAssetUtility` 缓存、`GFResourceResolverUtility` 解析报告、`GFResourceRegistry` 条目导出和场景预加载图谱都会用它的 `cache_key` 消除 `res://` / `uid://` / canonical path 混用导致的重复身份。

默认引用模式是弱引用，状态对象不会为了展示进度而延长资源生命周期。确实需要状态对象持有资源时，配置 `REFERENCE_STRONG`；释放或过期时调用 `mark_released()` / `mark_stale()`，不要让状态字典成为隐式缓存策略。

## 使用边界

`GFAssetUtility` 只管理 `ResourceLoader` 请求、回调分发和内存缓存，不负责实例化节点、引用计数之外的资源生命周期或远程下载。
