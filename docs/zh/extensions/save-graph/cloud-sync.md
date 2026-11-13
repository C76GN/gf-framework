# Profile 云端同步

`GFSaveSyncUtility` 将一个受管 Profile 的完整文档作为远端记录，组合 Standard 的版本同步引擎与现有 Profile 事务。远端冲突、CAS、取消等待与提交查证只有一套实现；Save 额外管理账号会话、文档投影、本地内容代际和持久化 checkpoint。

框架提供协议及测试适配器，不内置 HTTP 服务、平台 SDK、账号登录或服务端持久化。生产适配器必须满足 [通用版本同步契约](../../standard/utilities/io/storage-snapshot/backends-sync.md)。远端 namespace 是记录身份，服务端仍必须验证账号权限。

## 接线与所有权

先注册 Profile，再调用 prepare_profile()，随后成功激活或保存目标 Profile。同步快照只为明确准备的 Profile 保留；已经完成的旧加载不会被追溯捕获。prepare_profile() 不替项目创建、加载或切换档位。

启用同步捕获的 Profile 在复制待存文档前执行有界校验：最多128层、1000000个值、64MiB规范编码和单字符串16777216字符；循环、非有限数、不可持久化值或超限会使本轮准备失败，尚未写入 Storage。这一步是同步准备成本，不承诺逐节点分帧。远端投影载荷仍受通用同步协议的更小预算限制。

下载在调用项目投影前拒绝未来文档 schema 版本；投影不能将尚不认识的高版本文档重新标成本地版本后应用。

```gdscript
var sync: GFSaveSyncUtility = GFSaveSyncUtility.new()
var configured: bool = sync.setup(profiles, coordinator, project_projection)
if not configured:
	return
var prepared: bool = sync.prepare_profile(profile_id)
if not prepared:
	return

var activation: GFSaveProfileTransactionOperation = coordinator.activate_profile(profile_id)
var activated: GFSaveProfileTransactionResult = await activation.wait_result_async()
if not activated.is_successful():
	# 复用项目已有的 missing/corrupt 恢复流程。
	return
var bound: bool = sync.open_session(
	profile_id,
	account_namespace,
	"profile-main",
	account_transport
)
if not bound:
	return

var completion: GFAsyncCompletion = sync.synchronize(new_operation_id)
if not completion.is_completed():
	await completion.completed
var result: Dictionary = GFVariantData.as_dictionary(completion.get_result())
if GFVariantData.get_option_bool(result, "ok"):
	show_sync_result(GFVariantData.get_option_string_name(result, "status"))
```

独立使用者持续驱动 Profile、Coordinator 和 Sync 的 tick；注册到 Architecture 后由各自生命周期驱动。Sync 不释放借用的本地服务。dispose()/close_session() 结束会话观察，已准入的本地事务仍由 Coordinator 排空。

同步使用最近已确认的文档。业务修改须通过 mutate_and_persist() 或 save_profile() 登记并持久化；不能直接修改 Provider 后便假定同步会发现变化。存在排队、失败或未知本地写入时，同步准入拒绝，项目先完成本地保存恢复或对账。

## 显式字段投影

项目继承 `GFSaveSyncProjection`：

- `_project_upload(document)` 选择允许上传的分区、字段与项目元数据，返回完整文档封套。默认实现拒绝上传。
- `_prepare_download(remote, current)` 根据字段所有权，将远端投影与本地专用状态合成为完整本地候选。默认实现拒绝应用。

两个回调收到隔离副本，不包含框架 checkpoint。回调应是有界纯数据转换，不执行 IO、不修改 Provider，不隐式上传认证凭证或本地设备字段。服务端权威字段的接收和忽略规则也由项目明确写在投影内。

上传候选必须保留本地文档 schema 身份与版本。下载先验证远端封套和身份，再由项目投影构造当前版本候选，最后通过 Profile 完整 schema 与 Provider 验证。未来格式不能靠宽容读取绕过验证。项目可以在明确理解旧业务版本时显式转换，但同步器不会猜迁移政策。

完整下载与 checkpoint 在一个本地事务中保存：已知分区、payload 保留基线、允许保留的未知分区同时接收，失败同时回滚。下载候选必须包含所有可修改 Provider；不可修改 Provider 的内容只能保持相同。项目投影负责决定本地字段与未知内容如何组合，框架不把本地旧保留字段重新合入一个已经明确构造的完整下载候选。

## 账号、代际和恢复

一个会话冻结到 Profile、namespace、record key 和 Transport。账号切换使旧会话回调失效；新的账号使用隔离 Profile。已有 checkpoint 绑定其他账号或记录时，open_session() 拒绝；不会隐式改绑、清空恢复意图或将游客文档合入登录账号。

本地内容代际与物理保存 generation 分开。普通保存和业务事务推进内容代际，纯 checkpoint 事务保持它不变；失败可能留下代际空洞，它不表示修改次数。代际保存在文档中，重启继续使用。上传返回后只确认请求冻结的代际，网络等待期间后来保存的修改保持未确认。下载在网络返回、投影之后、事务 flush 之后分别检查代际，避免覆盖新状态。

文档 metadata 的 `_gf_sync` 是框架保留键，保存绑定身份、内容代际、已确认 revision/代际和未解决意图。普通项目请求不能写这个键，普通保存会保留它；文档迁移必须完整保留它。远端文档携带该键会被拒绝，本地上传前始终剥离。

标准上传有两次额外本地事务：先保存精确意图，再保存已查证结果。两次之间不占有业务事务锁。相同远端数据返回 unchanged 时仍会写入本地确认；pull/remote 的成功状态为 applied，必须等下载候选和 checkpoint 一起持久化后才返回。

`GFAsyncCompletion` 成功只表示观察产生了完整结果；业务结果读取 result.ok 和 result.status。记录还包含 sync_result、local_result、local_applied、acknowledged_generation、requires_recovery。sync_result 是通用同步不可变终态；local_result 保留 Profile 事务结果，包括需要时的 Reconcile Lease。

| 情况 | 项目处理 |
|---|---|
| conflict | 展示冲突；明确选择本地/远端，或先用项目事务持久化合并候选 |
| outcome_unknown | 保留原意图，调用 recover_pending() 查证原 operation_id |
| recovery_required | 远端已有结果，本地确认未完成；检查 sync_result.is_remote_committed() 和 local_result |
| local_generation_changed | 下载未覆盖新本地状态；以当前版本重新比较 |
| local_persist_failed | 检查 local_result；确定失败已回滚，未知或回滚失败按现有 Profile 对账流程处理 |
| recovery_pending | 旧意图尚未解决，不能用新 push 或 pull 清除；只读 preview 仍可使用 |

本地结果未知时，先使用 local_result.get_reconcile_lease() 完成既有 Coordinator 对账，再恢复远端查证。已知本地保存失败仍遵守原有保存屏障恢复要求。recover_pending() 只 probe 原操作，不能用新 operation_id 盲目重发。适配器无法证明历史提交时继续保持未知。

cancel_wait() 或取消完成源只结束观察，不能撤销已发送提交或本地事务。取消完成源后不再保证业务结果记录可取；应通过持久化意图和本地事务通知恢复。关闭会话也不能把正在提交的数据报告成“没有保存”。

## 成本和能力迁移

准备同步会保留一份已确认完整文档；在途文档、上传投影和持久化意图会增加复制与内存。原生数据验证和投影是同步有界工作，不提供单帧耗时保证；大型文档应按项目实测预算控制。请求受 Standard 的16MiB规范预算限制，checkpoint 还有独立边界，最终嵌入文档仍须通过 Save 和 Storage 的完整载荷预算，不能把各层上限简单相加。

不使用 Save 的独立记录继续使用 GFStorageSyncUtility。普通 Backend 的文件复制、单向搬运和批量合并使用 GFStorageTransfer；[槽位文档](serializers-slots.md)给出文件计划组合。旧 SlotSyncBridge 已删除，Slot Card、Metadata、Storage Adapter 和 Workflow 的本地职责保留。


上传投影合法但完整请求超过深度、节点、字符串或规范字节预算时，结果状态为
`upload_budget_exceeded`，`error_kind=request_budget_exceeded`；`layer/limits/observed` 指明实际请求层的
限制和有界计量，`path` 指向被拒绝的请求。结构错误仍与预算错误区分。此类拒绝发生在远端/意图 IO 前。
成功路径不增加一次重复计量；失败时只读复查同一候选以取得诊断。请求硬预算保持不变，上传内容可通过
项目 Projection 裁剪，不能凭修改诊断报告提高限制。
