# 导表、分析、远程缓存与请求总览

这一组 Utility 面向配置表读取、版本化分析事件、远程文本/JSON 缓存、轻量 HTTP 请求构建和离线请求 Outbox。它们只提供项目常见 IO 流程的基础设施，不内置账号、鉴权、业务协议、隐私与用户同意策略或具体表结构。

## 阅读入口

- [静态导表数据适配器与表校验](config-provider/index.md)：`GFConfigProvider`、表 schema、导入校验、引用、合并、构建 profile 和访问器生成。
- [通用分析事件](analytics-events.md)：`GFAnalyticsEventSchema`、`GFAnalyticsSchemaRegistry`、`GFAnalyticsUtility.track_versioned()`、批量 flush 和专用 `GFAnalyticsOutboxAdapter`。
- [远程文本与 JSON 缓存](remote-cache.md)：`GFRemoteCacheUtility`、TTL 缓存、失败回退、队列合并和调试快照。
- [源码文本加载器](source-text-loader.md)：`GFSourceTextLoader` 的逻辑 key 解析、root 限制、内存文本和内容 hash。
- [HTTP 请求构建与异步批处理](http-async-batch.md)：`GFHttpRequestBuilder`、`GFHttpResponse` 和 `GFAsyncBatch`。
- [通用请求 Outbox](request-outbox.md)：`GFRequestEnvelope`、`GFRequestOutboxUtility.enqueue_with_report()`、持久化请求、at-least-once 重试、重放和 Analytics Adapter。

## 使用边界

这些 Utility 可以统一项目 IO 管线的通用形状，但项目仍应自己决定数据表语义、事件命名和版本演进、PII 与 consent、请求鉴权、幂等策略和冲突处理。Analytics Schema 不执行隐式迁移，Outbox 也只承诺 at-least-once 尝试。需要平台 SDK、账号系统、云存档、排行榜或业务 DTO 时，应在项目层或独立扩展中组合这些基础件。
