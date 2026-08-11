# 完整性校验与版本迁移

这一组文档说明 `GFStorageUtility` 的写入策略、完整性校验、旧存档兼容和版本迁移链。

`GFStorageUtility` 的 logical identity、family claim、文件操作和事务提交/恢复共用同一套内部策略。槽位存档、纯字典存档和异步纯字典存档都会先通过相同的 portable path admission，再写入 catalog 授权的私有 family，并使用不可变 prepare/commit evidence 收敛事务。

## 阅读入口

- [完整性校验](integrity-checksum.md)：codec 元信息、checksum、旧 checksum 迁移和 JSON 语义归一化。
- [兼容旧存档](legacy-compatibility.md)：旧版纯 JSON 回退、数字归一、绝对路径、槽位结果和异步收敛。
- [迁移链](migration-chain.md)：`migrate_data()`、`register_migration()` 和严格 schema 迁移。

## 使用边界

`.tmp`、`.bak`、`.txn` 是合法的普通 logical leaf 后缀，各自映射到独立 family；项目层不能把它们解释成物理事务 sidecar。真正的 candidate、backup、resource stage 与 prepare/commit evidence 只存在于 `.gf-storage/v1` 私有 namespace，恢复流程会在 activation、后续读写或 committed-view 枚举前收敛。
