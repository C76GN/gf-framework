# 存储后端与同步

`GFStorageBackend` 是可选的后端扩展接口，默认不参与 `GFStorageUtility` 的本地读写流程，避免把云同步、平台 SDK 或账号体系写进框架核心。

项目需要多端同步时，可以继承后端接口并在自己的存储系统里组合使用；遇到本地/远端字段冲突时，用 `GFStorageConflictReport` 描述 `file_name`、`key`、本地值、远端值、解决结果和元数据。

`get_capability_report()` 可把后端声明的 `read/write/delete/list/sync` 能力、可选文件数量和文件名列表整理成普通字典。它适合诊断面板、连接预检或支持报告读取，不替项目判断某个账号、平台或远端服务是否真的可用；这类可用性仍应由具体后端的初始化和项目健康检查报告表达。

```gdscript
var report := backend.get_capability_report({
	"label": "cloud_profile",
	"include_data_names": true,
})
```

## 有序故障转移

当多个后端表达的是同一份逻辑数据、但其中一个可能暂时不可用时，可以用 `GFStorageFailoverBackend` 组合已经创建和初始化的后端。组合器不持有子后端生命周期，也不会自动复制数据。

```gdscript
var backends: Array[GFStorageBackend] = [platform_backend, local_backend]
var failover := GFStorageFailoverBackend.new()
failover.configure_backends(
	backends,
	PackedStringArray(["platform", "local"]),
	{
		"mutation_policy": GFStorageFailoverBackend.MutationPolicy.FIRST_SUCCESS,
		"failure_threshold": 2,
		"cooldown_msec": 30_000,
	}
)

var result := failover.load_data("profile.json")
var operation_report := failover.get_last_operation_report()
```

读取始终按优先级尝试到首个成功后端。写入和删除有两种明确语义：

- `PRIMARY_ONLY`：只访问第一个后端，适合不允许离线分叉的权威数据；失败会原样返回。
- `FIRST_SUCCESS`：失败后访问下一个后端，适合平台 SDK 暂时不可用时保存到本地等可接受离线分叉的场景；首次成功后停止。

冷却只统计 `ERR_UNAVAILABLE`、连接失败、超时和忙碌等明确暂时性错误；普通文件不存在或数据错误不会把后端误判为离线。达到阈值的后端会在冷却窗口中被跳过，窗口结束后自动允许一次正常探测。`get_last_operation_report()` 最多记录 32 个后端的成功、失败或跳过原因、错误码和健康计数，不记录保存数据或后端私有 metadata。

`configure_backends()` 会事务式校验选项：`mutation_policy` 必须是已声明枚举，`failure_threshold` 必须在 0 至 1000，`cooldown_msec` 必须在 0 至 86400000。非法配置返回 `false`，不会部分替换既有后端或静默改变写入策略；完整重新配置省略选项时恢复默认的 `FIRST_SUCCESS`、阈值 2 和 30 秒冷却。

故障转移不保证两个后端内容一致，也不提供跨后端原子写入。项目若在离线期间写入了本地后端，恢复联网后仍应显式使用 `GFStorageSyncUtility` 或项目 resolver 处理版本与冲突。

## 字典同步

需要把两个后端做一次通用字典同步时，可以注册或直接创建 `GFStorageSyncUtility`。它只读取 `GFStorageBackend.load_data()`、调用 `save_data()` 写回，并按策略处理文件级冲突。

默认策略会根据元数据中的 revision 或 timestamp 判断较新记录，无法判断时保留冲突并返回结构化报告。参与排序的数值必须有限；任一实际参与比较的值是 `NaN`、`INF` 或 `-INF` 时，本次冲突保持 unresolved，且不会写回任一后端。项目可以显式选择本地优先、远端优先、手动处理，或提供 resolver 回调生成合并结果：

```gdscript
var sync := Gf.get_utility(GFStorageSyncUtility) as GFStorageSyncUtility
var result := sync.sync_data("profile.json", local_backend, remote_backend, {
	"strategy": GFStorageSyncUtility.ConflictStrategy.USE_NEWEST,
})

if not result["ok"] and result["status_name"] == &"conflict":
	print(result["conflicts"])

var merged := sync.sync_data("profile.json", local_backend, remote_backend, {
	"strategy": GFStorageSyncUtility.ConflictStrategy.CUSTOM,
	"resolver": func(_report: GFStorageConflictReport, local_record: Dictionary, remote_record: Dictionary, _options: Dictionary) -> Dictionary:
		return {
			"data": local_record["data"],
			"metadata": local_record["metadata"],
			"resolution": GFStorageConflictReport.Resolution.MERGED,
		}
})
```

同步器不枚举账号、不自动触发保存、不接入平台云服务，也不理解业务字段。后端元数据的 revision/timestamp 由项目写入；若没有可比较的元数据，应显式选择策略或使用自定义 resolver，避免框架替项目猜测数据所有权。

未解决冲突是独立的终止状态：同步器会发出 `sync_conflict_detected` 和 `sync_conflict_unresolved`，结果中的 `status_name` 为 `conflict`，不会再发出 `sync_completed` 或 `sync_failed`。这样调用方可以明确区分“需要人工或项目策略处理的数据冲突”和“后端读写失败”。

## 分区脏缓存

如果项目的保存聚合器按“设置、进度、库存、场景片段”这类分区更新，可以用 `GFStorageSectionCache` 记录 scope 内哪些分区变脏，再只把脏分区交给存储层或同步层。分区 ID 和字段语义都由项目定义；GF 只负责 `scope_id + section_id` 的缓存、深合并、dirty 标记和 payload 生成。

```gdscript
var cache := GFStorageSectionCache.new()
cache.write_section(&"profile", &"settings", settings_payload)
cache.write_section(&"profile", &"summary", summary_payload, false)

var payload := cache.build_payload(&"profile")
storage.save_data("profile_patch.json", payload)
cache.mark_clean(&"profile", payload["dirty_sections"])
```

scope identity 是每次调用时 `scope_id` 的序列化值，而不是 Array/Dictionary 对象身份；修改复合值内容会形成另一个 scope，原记录仍可通过原值的等价副本定位和驱逐。长期作用域应使用稳定的 `String`、`StringName` 或 `int`，避免调用方遗失旧值。

`build_payload(scope_id, false)` 默认只输出脏分区；`include_clean = true` 时可输出完整 scope 快照。它不替代 `GFStorageUtility.save_data_group()` 的事务语义，也不负责字段冲突解析；需要跨后端同步时仍由 `GFStorageSyncUtility` 或项目 resolver 决定写回策略。
