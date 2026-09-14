# 已提交版本与摘要缓存

`GFStorageUtility` 可为每次提交提供不透明的 committed revision，让项目判断缓存的槽位摘要是否需要重建。它只支持等值比较，不支持大小排序、时间推断或解析内部结构。

这项能力需要显式选择 Storage layout schema 2。普通初始化、现有 schema 1 读写与默认创建方式保持原样，不会因读取而升级格式。它不改变业务 payload、codec 文档 schema、业务 `data_version` 或 metadata 的 `revision` 字段。

## 创建与离线升级

新存储在第一次初始化或 I/O 前显式创建：

```gdscript
var storage := GFStorageUtility.new()
storage.save_dir_name = "profiles"
var create_error := storage.create_revision_storage()
if create_error != OK:
	_report_storage_error(create_error)
```

已有 private root 返回 `ERR_ALREADY_EXISTS`，不会被这个入口改写。已有 schema 1 必须先停止该 root 的全部 Utility、进程和外部写入者，再用 `GFStorageRevisionMigration` 离线执行升级：

```gdscript
var migration := GFStorageRevisionMigration.new()
var upgrade_error := migration.upgrade("profiles")
if upgrade_error != OK:
	_report_storage_error(upgrade_error)
# 升级成功后重新创建正常运行所需的 Utility。
```

升级保留 payload、Resource、catalog 和 owner 的原有字节。已有文件取得初始 committed revision；已 claim 但没有 payload 的 family 仍为缺失。重复升级健康的 schema 2 不改变 token。

升级先持久化 intent，使旧版本和新版本的普通 I/O 都拒绝进入，再逐个安装状态，最后发布 schema 2 layout 并移除 intent。当前文件的提交标识先保存在有界 cursor 中，状态写入中断后可用同一标识重试。layout 替换间隙也始终被 intent 隔离。非权威暂存文件的部分写入可在旧 layout 和已发布状态证明充分时安全重试，不会替换已经发布的 token；完整但冲突的记录、超限记录及主 cursor 损坏仍被拒绝。状态已经写入后不支持任意回退到 schema 1，应保持离线并重试同一升级。损坏的 intent、没有匹配证据的损坏状态或已完成文件丢失状态都失败关闭，需要项目从可信备份恢复完整存储。

schema 2 会被旧 runtime 拒绝。升级前应部署支持该格式的 runtime，并安排项目自己的备份与版本回退流程；不能只回滚应用程序后继续打开已经升级的 root。

## 查询与实际读取配对

```gdscript
var revision := storage.query_committed_revision("slot-1.json")
match revision.get_status():
	GFStorageRevisionResult.Status.AVAILABLE:
		if cached_revision != revision.get_revision():
			_request_summary_reload()
	GFStorageRevisionResult.Status.NOT_FOUND:
		_clear_cached_summary()
	GFStorageRevisionResult.Status.UNSUPPORTED:
		_reload_without_revision_cache()
	_:
		_report_storage_error(revision.get_error_code())
```

查询返回 `GFStorageRevisionResult`，会排空本 Utility 的目标任务并恢复目标事务；稳定状态下只读取有界的状态记录，不读取 payload 内容。同 family 重入可返回 `BUSY`。其他状态包括 `INVALID_REQUEST`、`UNAVAILABLE`、`CORRUPT` 和 `IO_FAILED`。成功必须带非空 revision，失败永远不带 revision。`to_dict()` 只包含 `status`、`error_code` 与 `revision`。

一次查询得到 A 后，文件可能已被提交为 B，不能把之后读取到的 B 摘要标记为 A。同步和异步 JSON 都应从实际读取结果取得 token：

```gdscript
var operation := storage.load_data_request_async("slot-1.json")
if not operation.is_completed():
	await operation.completed
var read := operation.get_result().get_read_result()
if read == null or not read.ok:
	return
var source_revision := read.get_committed_revision()
if source_revision.is_successful():
	cached_summary = _build_summary(read.payload)
	cached_revision = source_revision.get_revision()
```

`load_data()` 同样返回携带实际读取来源的 `GFStorageReadResult`。业务 schema migration 可以转换 payload，甚至按原有策略另行保存迁移结果；读取 token 仍表示最初读取的物理提交，后续查询会观察新提交。项目改变摘要算法或业务 schema 时，应同时更新自己的缓存版本。

`duplicate_result()` 保留捕获的 token，原有 `to_dict()` schema 不变。Dictionary 往返、手工构造及重新配置的成功读取结果没有捕获来源，getter 返回 `UNSUPPORTED`。修改返回 payload 不会改变来源快照，缓存应在自行修改载荷之前建立。

Resource 使用 `load_resource_with_revision(file_name, type_hint)`，从成功的 `GFStorageResourceReadResult` 取 `get_resource()` 与 `get_committed_revision()`。它保留 opt-in、扩展名、类型 allowlist 和 `CACHE_MODE_IGNORE`，在读取期间持有同 family ownership。初始化回调中对同一文件的同步读写会被拒绝；排队写入或 Utility 生命周期改变会使外层读取失败，失败结果不携带 Resource/token。返回 Resource 是同一对象引用，token 只描述顶层文件，不覆盖外部依赖或返回后属性变化。旧 `load_resource()` 保留原签名与行为。

## 提交、删除与恢复

| 操作 | revision 行为 |
| --- | --- |
| 只读、重新创建 Utility、重启进程 | 保持同一 token |
| 再次成功保存完全相同的值 | 产生新 token |
| 多文件事务完整提交 | 每个成员取得对应的新 token |
| 未完成提交恢复到旧 payload | 保持旧 token |
| 删除文件 | 查询为 `NOT_FOUND` |
| 删除重建，或显式 family reset 后保存 | 产生新 token |

状态只在全组 commit 成立后、任何事务证据清理之前发布。状态发布失败时保存返回错误，但 payload 可能已经提交；后续查询或读取必须先利用保留证据恢复同一 token，不能把失败解释为“磁盘未变化”。部分证据清理后的恢复还要求所有成员状态与剩余提交证据一致。

正常删除保留内部状态而移除 payload，不把状态计入既有八成员计数。schema 2 存在未收敛事务证据时，删除返回 `ERR_BUSY` 并保留全部证据；先完成查询或读取的恢复，再重试删除。family reset 把状态随整个旧 family 一并退休，新 claim 不继承旧 token；状态单独改变也会让原 reset 观察及授权失效。

## 能力边界

本地 Storage 仍采用 single-writer root 合同：多个 Utility 或进程可以依次接手，不能并发写同一个 root。revision 不提供跨进程锁、条件写入或 compare-and-swap。

token 不检测框架之外的 payload 改写，不替代 checksum、完整性校验、云端 ETag、内容哈希或防回滚存储。恢复整个旧 root 备份也会恢复其中的 token。跨 provider 同步继续使用原有业务冲突策略，不应把 opaque token 写入 metadata 的 `revision` 键或交给 `USE_NEWEST` 排序。同步后端版本、分页 catalog 与条件读取需要各自的能力合同。
