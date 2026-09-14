# Catalog 查询状态与完整性

需要区分“确认没有文件”和“未能完成查询”的界面或缓存，应使用 `GFStorageUtility.query_catalog()`：

```gdscript
var catalog: GFStorageCatalogResult = storage.query_catalog(
	"archives", "json", true, {"max_scan_depth": 0, "max_file_count": 200}
)
if not catalog.is_successful():
	show_catalog_error(catalog.get_error_code(), catalog.get_failure_kind())
	return
var files: PackedStringArray = catalog.get_files()
show_archive_files(files)
if not catalog.is_complete():
	show_more_files_notice()
```

`GFStorageCatalogResult` 配置后不再改变。`get_files()` 与 `to_dict()` 返回隔离副本，文件按 logical identity 排序且不重复。结果没有 payload、物理路径或 revision。

## 完整性与查询边界

| 结果 | `is_successful()` | `is_complete()` | 文件集合 |
| --- | --- | --- | --- |
| 查询范围内没有 committed 文件 | `true` | `true` | 空 |
| 查询范围内的文件全部返回 | `true` | `true` | 完整有序集合 |
| `max_file_count` 实际截断 | `true` | `false` | 有序前缀 |
| 请求、生命周期、恢复或枚举失败 | `false` | `false` | 空，不发布部分结果 |

完整性只相对于本次调用的 directory、extension、recursive 与 logical depth selector。`max_scan_depth` 沿用原选项名，表示相对目录的逻辑深度：文件本身深度为 0，直接子目录内为 1；值为 0 表示不限。`recursive=false`、扩展名过滤或有限深度排除的文件不属于请求范围，因此不使结果变为不完整。请保留原查询范围；有限范围的 `is_complete() == true` 不能用于推断整个 Storage root 中的文件已删除。

`max_file_count` 只限制返回数量，0 表示不限。恰好有 N 个匹配文件且上限为 N 时仍完整，有 N+1 个才报告截断。两个选项均不限制扫描时间、磁盘读取量或内存：当前仍校验全 catalog 并执行 root recovery，查询范围外的损坏也可能使本次查询失败。查询会同步 drain 异步任务；完成回调关闭或更换 Utility 生命周期时返回 `UNAVAILABLE`，重入且仍有排队任务或文件锁时返回 `BUSY`。

新入口只接受这两个选项的非负 `int`，拒绝未知键、浮点数、字符串和布尔值。`list_files()` 保留原签名、宽松选项转换、负上限按 0 处理和失败返回空数组的行为。失败阶段通过 `FailureKind` 表达：`INVALID_REQUEST`、`UNAVAILABLE`、`BUSY`、`PREPARATION_FAILED`、`RECOVERY_FAILED` 和 `CATALOG_FAILED`；后面三个标识失败发生在哪个准备、恢复或枚举阶段，具体底层原因结合 Error 码判断，不据此猜测损坏的物理成员。

catalog 成功只证明本次可观察的 catalog/owner 与 committed 文件存在关系，不验证 payload 可解码、checksum 或项目 schema。加载列表项时仍须检查实际读取结果；项目摘要缓存的解释版本和刷新策略由项目维护。[本地存档管理器](storage-utility.md) 说明逻辑身份、事务和 single-writer 边界。

显式 schema 2 存储沿用相同查询合同：查询先收敛已提交事务及其 revision，删除后留下的历史 state 不会让文件重新出现在列表中。列表结果不携带 token；摘要应绑定实际读取结果的 `get_committed_revision()`，避免把先前查询的版本与随后读到的新内容混配。详见[已提交版本与摘要缓存](committed-revisions.md)。
