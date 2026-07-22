# Save Profile 运行时

`GFSaveProfileUtility` 用于协调一个项目存档中的多个独立模块。每个模块只实现
自己的 `GFSaveSectionProvider`，Profile 从 provider 清单派生当前文档 schema，
Storage 继续负责物理事务、编码和后台 IO。

适合使用 Save Profile 的场景包括自动保存、账号进度、背包、任务和设置等多个
长期维护边界需要共享一个版本化文档。只保存单个缓存字典时直接使用
`GFStorageUtility`；需要遍历场景节点时由 provider 把 `GFSaveGraphUtility.gather_section()`
接入一个 section，不要复制 Save Graph 格式。

## 定义 section provider

Provider 必须拥有稳定 `section_id` 和正数 `schema_version`。采集返回当前版本
`GFSaveSection`；应用失败时，Utility 会把失败 provider 和此前已尝试 provider
按逆序恢复到应用前快照。

```gdscript
class_name ProjectProgressSectionProvider
extends GFSaveSectionProvider

var progress: ProjectProgress


func _gather_section(_context: Dictionary = {}) -> GFSaveSection:
	if progress == null:
		return null
	return make_section(progress.to_dict())


func _apply_section(section: GFSaveSection, _context: Dictionary = {}) -> Error:
	if progress == null:
		return ERR_UNCONFIGURED
	var payload_value: Variant = section.get_payload()
	if not payload_value is Dictionary:
		return ERR_INVALID_DATA
	progress.apply_dict(GFVariantData.as_dictionary(payload_value))
	return OK
```

默认 `_rollback_section()` 会复用 `_apply_section()`。如果应用过程涉及额外缓存或
可撤销外部状态，应重写该钩子；不可回滚的网络请求、支付或平台副作用不能放进
普通 section 应用。终态中的每个 `GFSaveRollbackFailure` 都分别保存 section ID 和
Godot `Error`，调用方不应解析错误字符串来定位回滚失败。

## 注册 Profile

Save 扩展安装器会注册 `GFSaveProfileUtility`。项目在架构初始化完成后创建并注册
Profile；同一个 Utility 内的 profile ID 和文件名都必须唯一。

```gdscript
var profile := GFSaveProfile.new()
profile.profile_id = &"project.player"
profile.schema_id = &"project.player.document"
profile.file_name = "player/profile.sav"
profile.schema_version = 3
profile.providers = [progress_provider, inventory_provider, quest_provider]

var save_profiles := Gf.get_utility(GFSaveProfileUtility) as GFSaveProfileUtility
if save_profiles == null:
	push_error("Save Profile Utility is unavailable.")
	return
var registration: Dictionary = save_profiles.register_profile(profile, migrations)
if not GFVariantData.get_option_bool(registration, "registered"):
	push_error("Player save profile registration failed.")
```

注册成功后，Utility 会编译并持有 profile ID、schema、规范存储路径、provider 清单和
恢复政策。之后修改 `GFSaveProfile` 不会改变运行时定义；provider 的身份和能力字段也
会被永久锁定。需要变更契约时，应等待 profile 空闲后注销，并使用新的
`GFSaveProfile` 与新的 Provider 实例重新注册，而不是复用或修改已锁定 Resource。
注册报告保留完整校验问题以及最终 `canonical_file_name`，可直接写入诊断。

`GFSaveMigrationRegistry` 仍是唯一迁移引擎。Profile 不提供字段级兼容回退；文档或
section 版本落后时必须存在完整迁移链，未来版本始终拒绝读取。

## 保存、flush 与读取屏障

每次保存请求获得递增 generation。同一 profile 只推进一个当前 IO；在途写入期间的
多个请求会合并为一次最新 generation 写入。较早句柄只有在覆盖其 generation 的写入
完成后才进入终态。物理写入超时后无法可靠取消时，原请求会 detached 并继续保有路径
所有权，因此它可能与后续重试短暂物理并存，但不再作为状态机的当前 IO。

```gdscript
var operation := save_profiles.save_profile(&"project.player", {
	"slot_kind": "auto",
})
var result: GFSaveProfileResult
if operation.is_completed():
	result = operation.get_result()
else:
	result = await operation.completed
if not result.is_successful():
	push_warning(result.get_error())
```

`flush_profile()` 捕获调用时可见的 generation，只在该 generation 或更新 generation
真实持久化后成功。`load_profile()` 同样捕获写入屏障；屏障写入失败时不会静默读取
旧文件。最老读取的屏障一旦满足，就会先获得一个调度轮次，避免持续自动保存让已就绪
读取长期饥饿；如果仍有保存等待，服务一个读取后会把下一轮交给保存，避免大量读取反向
饿死保存和 flush。尚未满足的读取仍等待能够覆盖其 generation 的保存。加载、迁移、应用
期间的保存请求会以 `busy` 明确拒绝，避免旧文件覆盖刚应用到内存的新状态。provider 和
状态变更回调中的重入请求会被拒绝；完成信号在状态稳定后发出，因此完成回调可以发起一个
新的非递归操作。

Profile 层使用 `GFStorageAsyncOperation` 的 request ID 观察自己的底层请求，不依赖
“文件名相同”的全局完成信号。因此其他调用方同时读写同一文件也不会完成错误句柄。
完成信号只在状态机恢复稳定状态后发出，回调可以安全查询快照或释放 Utility。

## 恢复政策

`GFSaveRecoveryPolicy` 默认对缺失和损坏文件返回失败。项目可以显式选择
`ACTION_USE_CURRENT_STATE`，此时读取成功终态会标记 recovered，但只保留当前内存
状态，不删除、替换或自动覆盖原文件。

```gdscript
var policy := GFSaveRecoveryPolicy.new()
policy.missing_file_action = GFSaveRecoveryPolicy.ACTION_USE_CURRENT_STATE
policy.retry_delays_msec = PackedInt32Array([50, 250, 1000])
policy.io_timeout_msec = 10_000
profile.recovery_policy = policy
```

重试只处理策略中列出的临时 `Error`，并使用有限延迟序列和单调时钟。未来 schema、
schema ID 不匹配、迁移失败和 provider 应用失败不进入损坏恢复。读取超时可以安全失败；
写入无法可靠取消，因此超时或写入期间释放会返回 `outcome_unknown`，调用方不得假定磁盘
未发生提交。未知证据按 generation 保存，结果中的 `storage_request_ids` 可用于对账；
超时请求迟到完成前，Profile 继续占有规范路径，注销和同路径重新注册都会被拒绝。
迟到的完成回调不会改变已经进入终态的操作句柄；如果同一逻辑保存仍在等待或执行重试，
任一覆盖其 generation 的物理写入成功会立即完成该句柄并取消尚未启动的重试。已经启动的
其他写请求继续由 Profile 保有路径直到物理终态，但其后续失败不会翻转已确认的保存成功。

未知 section 默认采用 `GFSaveProfile.UNKNOWN_SECTION_REJECT`，避免旧客户端读取后保存时
静默删除新客户端数据。只有明确拥有向前兼容要求时才选择 `UNKNOWN_SECTION_PRESERVE`；
选择 `UNKNOWN_SECTION_DROP` 等同于显式接受数据丢弃。

完整状态机、不变量和失败矩阵见 [Save Profile 运行时编排决策](save-profile-adr.md)。
