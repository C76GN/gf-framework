# 存储后端与同步

`GFStorageBackend` 是可选的后端扩展接口，默认不参与 `GFStorageUtility` 的本地读写流程，避免把云同步、平台 SDK 或账号体系写进框架核心。

普通 Backend 的读写能力与远端版本同步分开：`GFStorageTransfer` 搬运两个 Backend 的数据；`GFStorageSyncUtility` 通过 `GFStorageSyncTransport` 与持久化 Journal 实现条件提交和查证。两者都可以独立于 Save 扩展使用。

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

读取始终按优先级尝试到首个成功后端。

若全部读取失败，逻辑读取结果保留最后一个非 missing 错误，后续不存在结果不能掩盖先前的超时、权限或损坏故障；cooldown / unsupported 等未读后端也按未知状态处理。只有所有已配置后端都实际读取且明确不存在时，总结果才报告 missing，使同步器能够安全区分逻辑记录缺失与读取故障。逐后端尝试报告保持完整；此分类不提供副本一致性或多后端事务保证。

写入和删除有两种明确语义：

- `PRIMARY_ONLY`：只访问第一个后端，适合不允许离线分叉的权威数据；失败会原样返回。
- `FIRST_SUCCESS`：失败后访问下一个后端，适合平台 SDK 暂时不可用时保存到本地等可接受离线分叉的场景；首次成功后停止。

冷却只统计 `ERR_UNAVAILABLE`、连接失败、超时和忙碌等明确暂时性错误；普通文件不存在或数据错误不会把后端误判为离线。达到阈值的后端会在冷却窗口中被跳过，窗口结束后自动允许一次正常探测。`get_last_operation_report()` 最多记录 32 个后端的成功、失败或跳过原因、错误码和健康计数，不记录保存数据或后端私有 metadata。

`configure_backends()` 会事务式校验选项：`mutation_policy` 必须是已声明枚举，`failure_threshold` 必须在 0 至 1000，`cooldown_msec` 必须在 0 至 86400000。非法配置返回 `false`，不会部分替换既有后端或静默改变写入策略；完整重新配置省略选项时恢复默认的 `FIRST_SUCCESS`、阈值 2 和 30 秒冷却。

故障转移不保证两个后端内容一致，也不提供跨后端原子写入。离线副本的后续合并应由项目明确发起：普通后端使用 Transfer；支持条件提交和查证的服务使用版本同步协议。

## 远端版本同步

`GFStorageSyncRequest` 冻结 namespace、记录 key、operation_id、候选数据、预期 revision 和本地 generation。revision 是不透明文本，只能比较相等；空文本表示预期记录不存在。本地 generation 只标识这次候选，不能与远端版本比较大小。每次新提交使用新的操作 ID；查证原提交必须沿用原 ID、候选与预期 revision。

`GFStorageSyncTransport` 声明 read、conditional_write 和 probe 能力。写入必须由远端原子比较 revision，并按 namespace/key/operation_id 幂等记录结果；probe 返回该操作的历史结果，不能通过“当前数据看起来一样”推断提交成功。账号凭证由适配器冻结，namespace 本身不等于服务端授权。框架没有内置 HTTP、平台 SDK 或生产云服务。

`GFStorageSyncJournal` 的成功完成表示已经持久化。引擎依次执行：

1. 查询未解决意图并读取远端单一版本。
2. 比较版本并处理明确选择。
3. 持久化包含精确候选与预期 revision 的意图。
4. 发起一次远端条件写入。
5. 持久化已查证结果，才返回 committed。

同记录存在未解决意图时，新的 push 返回 recovery_pending；不能用新请求覆盖恢复责任。多个引擎共享同一日志时，Journal 仍须原子拒绝另一条未解决意图。引擎自身只保证本实例的记录准入。

`GFStorageSyncOperation` 表达一次观察的身份、等待和取消；它只产生一个 `GFStorageSyncResult`。
结果封存后不会被迟到回调改写。诊断摘要不携带业务载荷，需要处理远端候选或冲突时，
通过结果及冲突报告的显式数据访问器取得隔离副本。

```gdscript
var engine: GFStorageSyncUtility = GFStorageSyncUtility.new()
var configured: bool = engine.setup(transport, journal)
if not configured:
	return

var request: GFStorageSyncRequest = GFStorageSyncRequest.create(
	"account-stable-id",
	"profile-main",
	operation_id,
	candidate,
	{
		"expected_revision": known_revision,
		"local_generation": captured_generation,
	}
)
var operation: GFStorageSyncOperation = engine.synchronize(request)
var result: GFStorageSyncResult = await operation.wait_result_async()
if result.get_status() == GFStorageSyncResult.Status.COMMITTED:
	acknowledge_generation(result.get_request().get_local_generation())
elif result.requires_recovery():
	show_recovery_pending()
```

独立使用者须持续调用 `tick(delta)` 处理单调时钟超时，并在结束时 `dispose()`；注册到 Architecture 后由生命周期驱动。操作可能同步完成，因此使用 `wait_result_async()` 或先检查 `is_completed()`，不能无条件只等待 completed 信号。

| 结果 | 已确认的事实 |
|---|---|
| preview | 已比较候选，没有发起写入 |
| unchanged | 观察版本被接受且数据相同，没有写入；调用方仍决定如何更新自己的确认状态 |
| remote_selected | 已取得远端候选，尚未应用到本地业务状态 |
| committed | 远端提交和 Journal 结果均持久化确认 |
| conflict | 预期版本不匹配，或条件提交时发生竞争 |
| not_committed | 未发送，或已经查证本次没有提交 |
| outcome_unknown | 可能已提交，须按原操作 ID 查证 |
| recovery_required | 已有远端结果，本地 Journal 确认失败；可单独查询 is_remote_committed() |
| rejected | 输入、能力、记录准入或恢复身份未通过检查 |

默认 resolution 为 report。local 选择先接受读到的版本，再执行一次条件提交；这一步仍可能因新竞争返回 conflict。remote 或 pull 返回候选，不替项目修改本地业务。preview 不写 Journal 或远端。自定义合并从冲突报告显式读取两端数据，构建新候选、新操作 ID 和报告中的实际 revision，再调用 synchronize()；再次竞争仍会失败，不自动重试覆盖。

调用 `cancel_wait()`、超时或 dispose 仅结束本次观察。发送前可返回 not_committed；发送后通常为 outcome_unknown；已取得远端结果而本地确认未完成则为 recovery_required。迟到响应不会改变已返回的终态。发送前取消也可能留下迟到落盘的意图，仍须查证并清理，不能直接覆盖日志。

恢复时从 Journal 读取原记录，用 `GFStorageSyncRequest.from_record()` 验证后调用 `recover(request)`。引擎再次比对持久化意图，只调用 probe，不重发写入。服务无法证明历史结果时保持 unknown，不能用本地时间戳选“较新”数据。

`synchronize_many()` 最多接纳256项，逐项独立终结，无跨记录原子性。请求与协议结果采用有界纯原生数据：深度64、100000节点、16MiB规范编码；对象、循环和非有限数被拒绝。捕获、验证和复制是同步有界处理，并非帧耗时承诺。同步结果、请求和冲突报告的诊断摘要不含业务载荷、账号身份或 revision；显式载荷 getter 与 `to_record()` 仍包含业务数据，不应用于日志。

## 普通 Backend 传输

`GFStorageTransfer.transfer_data()` 读取两个 Backend 并按明确策略写回，保留比较预览、单向复制、自定义合并和批量结果。默认 MANUAL；两端不同即报告冲突。只有明确的不存在错误才允许从另一端填充，超时、权限或损坏不能当成空记录。

```gdscript
var transfer: GFStorageTransfer = GFStorageTransfer.new()
var preview: Dictionary = transfer.transfer_data(
	"profile.json",
	local_backend,
	remote_backend,
	{
		"strategy": GFStorageTransfer.ConflictStrategy.USE_LOCAL,
		"write_resolved": false,
	}
)
var copied: Dictionary = transfer.transfer_data(
	"profile.json",
	local_backend,
	remote_backend,
	{
		"strategy": GFStorageTransfer.ConflictStrategy.USE_LOCAL,
		"write_to_local": false,
		"write_to_remote": true,
	}
)
```

未实际写入的选择返回 preview；相同数据返回 unchanged。方向选项同样约束“目标不存在”的复制。CUSTOM resolver 接收冻结报告、两端记录和选项，返回 data、metadata、resolution；UNRESOLVED/SKIPPED 不可作为可写候选。批量上限256项，结果分别报告成功、冲突与失败；一个后端写入成功、另一个失败不提供回滚或跨后端事务。

USE_NEWEST 仅是项目明确启用的元数据排序启发式：双方 int 保持精确 Int64 比较，非有限值拒绝排序。它不提供远端 CAS，也不能用于解释版本同步协议的不透明 revision。返回值明确包含 `concurrent_write_protection=false` 和 `cross_backend_atomic=false`。

`GFStorageConflictReport` 是冻结值对象；get_local_data()/get_remote_data()/get_resolved_data() 返回隔离副本，with_resolution() 创建新报告。to_dict() 只返回诊断摘要。Transfer 的完整结果仍显式包含所选 data 与 metadata，调用方不能把它当作已脱敏日志。

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


## 准入诊断与迁移

`GFStorageSyncRequest.get_limits()` 返回完整请求封套的固定规范编码预算；
`validate_input(namespace, key, operation_id, data, options)` 复用 `create()` 的实际验证路径，
只返回 `ok/error_kind/path/layer/limits/observed`，不复制未验收载荷、不发起 IO。
报告不包含账号身份或业务值，也不能作为之后已修改数据的验收凭据。`create()` 仍在失败时返回 null。
`observed` 中成功计数精确；失败计数只描述已遍历部分。`limit_kind` 表示实际触发的限制，
`limit` 是数值上限，`observed_is_lower_bound=true` 时 `observed` 仅为已知下界，不是完整大小。

配置引擎后，可用 `inspect_support(mode, resolution)` 查看所需/缺少的能力和日志要求。
`push/report`、`push/local` 需要 read、conditional_write、probe 及 Journal；
`pull`、`preview`、`push/remote` 只需要 read；`probe` 需要 probe 及 Journal。
预检不发送网络请求，实际操作仍重新检查。能力声明不替代服务端 CAS、幂等历史结果和真正落盘的契约。

普通文件搬运的 `GFStorageTransfer` 继续支持全部明确冲突策略，但现在拒绝非整数或枚举范围外的
`strategy`，返回 `error_kind=invalid_strategy`、`path=options.strategy`，且不会读取或写入后端。
不要用 -1 表示“沿用默认”；省略该选项即可。有效的整数枚举和 StringName 选项键保持可用。
