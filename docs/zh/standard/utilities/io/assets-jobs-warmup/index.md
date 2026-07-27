# 资源加载、下载、任务队列与预热总览

这一组 Utility 覆盖资源生命周期、文件下载、任务队列、后台纯数据工作和渲染资源预热等 IO 与后台工作流程。它们提供通用状态、队列和诊断边界，不规定项目资源包、导入流水线、加载界面或业务对象生命周期。

## 阅读入口

- [异步资源加载与缓存](asset-utility/index.md)：`GFAssetUtility`、并发加载合并、LRU 缓存、pin、资源句柄、显式 Live Asset Slot 和资源分组。
- [通用文件下载队列](download-utility.md)：`GFDownloadUtility`、清单批量入队、聚合进度、临时文件提交、续传、校验、暂停、取消和重试。
- [通用任务队列](job-queue.md)：`GFJobQueueUtility`、`GFJob`、队列状态、同步处理器和 `GFJobWorker`。
- [后台工作协调器](background-work.md)：`GFBackgroundWorkUtility`、纯数据线程任务、资源线程加载和主线程应用回调。
- [渲染资源预热](render-warmup.md)：`GFRenderWarmupManifest`、`GFRenderWarmupUtility`、渲染资源扫描、分帧预算和临时渲染节点。

## 使用边界

`GFPathEnumerationTools` 提供只读文件枚举 primitive，统一递归、隐藏文件、扩展名、排除路径、深度和数量上限。`GFDirectoryWatchUtility` 与 `GFDirectoryChangeSet` 在此基础上提供调用方驱动的目录快照差异检测，可用于编辑器工具或资产索引器判断何时刷新生成物。`GFResourceRegistryTools.scan_resource_paths()` 也复用同一枚举底座，只在资源注册表层额外处理 glob 模式、`.import` sidecar 和进入注册表的资源路径数量上限。目录监听只报告 created / modified / deleted 路径，不负责导入资源、保存注册表或调度后台任务。

资源实例化、加载界面、导入规则、线程任务内容、业务对象创建和预热时机由项目层决定。需要场景切换时使用 `GFSceneUtility`；需要轻量远程文本或 JSON TTL 缓存时使用 `GFRemoteCacheUtility`；需要离线请求重放时使用 `GFRequestOutboxUtility`。
