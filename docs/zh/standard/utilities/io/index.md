# 资源、存储与 IO

本组文档覆盖标准库里和资源、文件、配置、远程缓存、同步和请求队列相关的 Utility。它们提供通用基础设施，不规定平台账号、云服务 SDK、业务 DTO、隐私策略、资源包发布策略或场景树级存档图。

场景树级存档图不在本组展开，主说明见 [Save 场景存档图](../../../extensions/save-graph/index.md)。

## 阅读入口

- [资源加载、下载、任务队列与预热](assets-jobs-warmup/index.md)：资源生命周期、下载、任务队列、后台工作和渲染预热。
- [本地存储、编码、同步与快照](storage-snapshot/index.md)：本地存档、编码、完整性校验、迁移、同步后端和快照历史。
- [导表、分析、远程缓存与请求](config-remote-outbox/index.md)：配置表、版本化分析事件、远程缓存、HTTP 请求、专用 Analytics Adapter 和离线请求 Outbox。

## 使用边界

- 本组 Utility 只负责资源、文件、配置和请求流程的通用机制。
- 项目资源包发布、账号系统、云端协议、PII 与用户同意、鉴权、业务 DTO 和服务器错误语义应由项目层或外部 SDK 适配。
- 场景树级状态采集、实体恢复和存档图应用应使用 [Save 场景存档图](../../../extensions/save-graph/index.md)。
- 纯数据结构、数值、标签、校验报告和 Variant 转换应放在 [Foundation](../../foundation/index.md)。

## API Reference

完整类、方法和信号列表见 [Standard API Reference](../../../reference/api/standard.md)。
