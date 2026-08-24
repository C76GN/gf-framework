# 本地存储、编码、同步与快照

本组文档聚焦标准库的本地读写、编码、同步和快照历史；项目如何采集业务对象或场景状态不属于标准存储层职责。

## 阅读入口

- [本地存档管理器](storage-utility.md)：`GFStorageUtility` 的字典、事务组、Resource 和通用文件读写。
- [显式重置损坏 Storage family](family-reset.md)：来源绑定授权、retirement/recreate 协议、崩溃恢复与 Settings 默认值持久化。
- [完整性校验与版本迁移](integrity-migrations/index.md)：codec 元信息、checksum、事务恢复、旧存档兼容和迁移链。
- [存储后端与同步](backends-sync.md)：`GFStorageBackend`、`GFStorageSyncUtility` 和冲突报告。
- [快照历史与查看器](snapshot-history-viewer.md)：`GFSnapshotHistoryUtility` 与 `GF Storage Viewer`。

## 使用边界

`GFStorageUtility` 基于 Godot `user://` 提供本地持久化能力。它不负责云同步、业务 schema 设计、玩家账号隔离或安全加密。多端同步、平台 SDK、账号体系和业务冲突策略应由项目层或独立插件接入。
