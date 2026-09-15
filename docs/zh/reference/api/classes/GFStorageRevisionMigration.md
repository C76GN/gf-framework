# GFStorageRevisionMigration

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_revision_migration.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

把现有 Storage schema 1 显式离线升级为 schema 2。 调用前必须停止该 root 的全部其他 Utility、进程与外部文件写入者。 迁移 intent 存在期间普通运行时拒绝 I/O；失败后应在同一离线条件下重试。 开始发布 state 后不能任意回滚到 schema 1；损坏的 intent 需要从可信备份恢复。 本类型不解释业务载荷，不触发业务 schema migration，也不自动迁移默认存储。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`upgrade`](#member-gfstoragerevisionmigration-methods-upgrade) | `func upgrade(save_dir_name: String) -> Error:` |

## 方法

<a id="member-gfstoragerevisionmigration-methods-upgrade"></a>

### `upgrade`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func upgrade(save_dir_name: String) -> Error:
```

在调用方已建立的离线单写入者边界内升级或继续升级一个已有 Storage root。

参数：

| 名称 | 说明 |
|---|---|
| `save_dir_name` | 与 GFStorageUtility.save_dir_name 相同的合法存储目录配置。 |

返回：完整 schema 2 验收成功返回 OK；失败保留恢复证据，不创建缺失的存储 root。
