# Save Profile 运行时

`GFSaveProfileUtility` 用于协调一个项目存档中的多个独立模块。每个模块只实现
自己的 `GFSaveSectionProvider`，Profile 从 provider 清单派生当前文档 schema，
Provider 在主线程协作式生成一次性 Snapshot，Storage worker 继续负责载荷预检、
物化、编码和物理 IO。

适合使用 Save Profile 的场景包括自动保存、账号进度、背包、任务和设置等多个
长期维护边界需要共享一个版本化文档。只保存单个缓存字典时直接使用
`GFStorageUtility`；需要遍历场景节点时由 provider 把 `GFSaveGraphUtility.gather_section()`
接入一个 section，不要复制 Save Graph 格式。

## 定义 section provider

Provider 必须拥有稳定 `section_id` 和正数 `schema_version`。保存入口实现
`_begin_save_snapshot()` 并返回 `GFSaveSectionSnapshotOperation`；Utility 在主线程
按预算调用 Operation 的 `_advance_snapshot()`。应用失败时，Utility 会把失败
provider 和此前已尝试 provider 按逆序恢复到应用前快照。

```gdscript
class_name ProjectProgressSectionProvider
extends GFSaveSectionProvider

var progress: ProjectProgress


func _begin_save_snapshot(
	_context: Dictionary = {}
) -> GFSaveSectionSnapshotOperation:
	if progress == null:
		return null
	# 仅适用于固定且很小的载荷。大型载荷必须返回自定义 Operation，
	# 在 _advance_snapshot(step_budget) 中分片构造。
	var owned_payload: Dictionary = progress.to_small_dict()
	return make_completed_snapshot(owned_payload)


func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
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

`begin_save_snapshot()` / `_begin_save_snapshot()` 只允许捕获稳定根引用或创建
Operation，不能同步遍历大型对象图。大型 Provider 应继承
`GFSaveSectionSnapshotOperation`，让每次 `_advance_snapshot(step_budget)` 最多消费
传入的 work units，完成后调用 `_complete_snapshot(make_snapshot(payload, metadata))`。
框架无法抢占一次已经开始的 Provider 回调，因此 Provider 还必须保证每个 work unit
本身具有明确上界；不能把全部工作放进一个 unit 后仅返回 `1`。

`make_snapshot()`、`make_completed_snapshot()` 与
`GFSaveSectionSnapshot.take_ownership()` 都采用逻辑 move，不会深复制。成功调用后，
Provider 必须立即放弃源 payload、metadata 及所有嵌套 `Dictionary` / `Array` alias，
不能再读取、修改或提交给其他线程。GDScript 没有语言级 move，违反该协议会破坏
Snapshot 的只读跨线程不变量。`make_completed_snapshot()` 只适合已经独占且固定成本
可移交的小型载荷，不是大型 Provider 的兼容捷径。

默认 `_rollback_section()` 会复用 `_apply_section()`。如果应用过程涉及额外缓存或
可撤销外部状态，应重写该钩子；不可回滚的网络请求、支付或平台副作用不能放进
普通 section 应用。终态中的每个 `GFSaveRollbackFailure` 都分别保存 section ID 和
Godot `Error`，调用方不应解析错误字符串来定位回滚失败。

保存协议不再提供 `_gather_section()` 回退，读取前回滚快照也不再隐式复用保存实现。
需要读取能力的 Provider 必须单独实现 `_capture_section()`；这是为了把协作式保存
Snapshot 与读取事务回滚分成两个清晰的一致性边界。

## 注册 Profile

Save 扩展安装器会先复用架构中已有的 `GFStorageUtility`，或在缺失时注册一个共享
Storage，再注册 `GFSaveGraphUtility` 与 `GFSaveProfileUtility`。Profile Utility 通过
类型化依赖声明绑定这份 Storage；安装器路径不需要也不应额外调用 `setup()`。只有
脱离 Architecture 独立使用 Profile Utility 时，调用方才通过 `setup(storage)` 显式
交付自有 Storage。项目可以在自己的 Installer 中准备 Profile 定义，再由声明依赖
该 Utility 的项目 System 在第三阶段 `ready()` 注册；如果 Profile 不参与启动
bootstrap，也可以在架构 READY 后显式注册。同一个 Utility 内的 profile ID 和
文件名都必须唯一。

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

## 与 Architecture Activation 组合

需要在首个运行场景开放前恢复存档或确认既有 generation 已落盘时，由项目
`GFSystem` 声明 `GFSaveProfileUtility` 为必需依赖，并在
`begin_activation(scope)` 中把 `load_profile()` 或 `flush_profile()` 的类型化终态
桥接到 `GFAsyncCompletion`。不要把项目 slot、账号选择或恢复决策写入框架 Utility，
也不要在 System 中手动轮询 `architecture.tick()`：

```gdscript
extends GFSystem

const BOOTSTRAP_PROFILE_ID: StringName = &"project.player"

var _save_profiles: GFSaveProfileUtility = null
var _bootstrap_operation: GFSaveProfileOperation = null

func get_required_utilities() -> Array[Script]:
	return [GFSaveProfileUtility]

func ready() -> void:
	var value: Variant = get_utility(GFSaveProfileUtility, true)
	if value is GFSaveProfileUtility:
		_save_profiles = value
	# 在这里注册项目自己的 GFSaveProfile，并检查 registered 报告。

func begin_activation(scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _bound: bool = completion.bind_cancel_token(scope)
	if not completion.is_pending():
		return completion
	if _save_profiles == null:
		var _failed: bool = completion.fail("Save Profile dependency is unavailable.")
		return completion

	# 恢复启动状态时等待 load；若职责是确认已排队 generation 落盘，
	# 则用 flush_profile(BOOTSTRAP_PROFILE_ID) 并复用同一桥接方法。
	_bootstrap_operation = _save_profiles.load_profile(BOOTSTRAP_PROFILE_ID)
	_bridge_bootstrap_operation(_bootstrap_operation, completion)
	return completion

func _bridge_bootstrap_operation(
	operation: GFSaveProfileOperation,
	completion: GFAsyncCompletion
) -> void:
	if operation == null:
		var _failed: bool = completion.fail("Save Profile bootstrap returned no operation.")
		return
	if operation.is_completed():
		_finish_bootstrap(operation.get_result(), completion)
		return
	var connected: Error = operation.completed.connect(
		Callable(self, &"_finish_bootstrap").bind(completion),
		CONNECT_ONE_SHOT
	)
	if connected != OK:
		var _failed_connect: bool = completion.fail("Bootstrap completion is unavailable.")

func _finish_bootstrap(result: GFSaveProfileResult, completion: GFAsyncCompletion) -> void:
	_bootstrap_operation = null
	if not completion.is_pending():
		return
	if result != null and result.is_successful():
		var _succeeded: bool = completion.succeed()
		return
	var error_message: String = result.get_error() if result != null else "No result."
	var _failed: bool = completion.fail(error_message)
```

依赖 DAG 会先激活 `GFStorageUtility`，再激活 `GFSaveProfileUtility`，最后执行项目
System 的 activation。等待上述 Operation 时，Architecture 只推进当前 System 的
本地依赖闭包，因此 Profile 与 Storage 的 tick-driven 状态机会继续运行，但命令、
事件、普通 tick 和其他外部运行时工作仍保持关闭。Operation 失败、scope 取消或超过
`activation_timeout_seconds` 时，项目 System 必须让 completion 进入非成功终态；
Architecture 随即拒绝 READY，并由 lifecycle generation 防止迟到回调写回。

`load_profile()` 适合恢复并应用启动状态；`flush_profile()` 只保证调用时捕获的
generation 或更新 generation 已经持久化，不能替代读取。是否在 load 后安排一次
save/flush 取决于项目恢复政策，框架不隐式改写文件。

## 保存、flush 与读取屏障

`save_profile()` 接收一次性 opaque `GFSaveProfileRequest`。Request 把持久化
document metadata、Provider context 和只进入终态的 result metadata 分开；Utility
通过 O(1) claim 接管三个引用，不在请求调用栈内深复制、执行 Provider、构造文档或提交
Storage。`request == null` 表示三个字典均为空。

```gdscript
var request := GFSaveProfileRequest.take_ownership(
	{"slot_kind": "auto"},
	{"reason": "checkpoint"},
	{"request_tag": "autosave-ui"},
)
var operation := save_profiles.save_profile(&"project.player", request)
```

如果不是直接传入字面量，`take_ownership()` 成功后必须立即且永久放弃三个源字典及全部
嵌套集合 alias。Request 没有 payload getter，只能被成功 claim 一次；重复提交、直接
`new()` 得到的未初始化 Request 会以 `STATUS_INVALID_REQUEST` 拒绝。Profile 不存在、
操作关闭或当前生命周期不允许保存时，Utility 会先拒绝再 claim，因此同一 Request 仍可
提交到合法边界。

后续 `tick()` 才按所有 Profile 共享的 `save_preparation_work_budget_per_tick` 推进准备；
每个 Profile 一轮最多获得 `save_preparation_slice_budget`。
`save_preparation_time_budget_usec` 是软时间预算，只会阻止开始下一个 slice，不能抢占
正在运行的 Provider 回调；设为 `0` 时只使用确定性 work-unit 预算。

同一 profile 只推进一个当前 IO；在途写入期间的多个请求会合并为一次最新 generation
写入。较早句柄只有在覆盖其 generation 的写入完成后才进入终态。物理写入超时后无法
可靠取消时，原请求会 detached 并继续保有路径所有权，因此它可能与后续重试短暂物理
并存，但不再作为状态机的当前 IO。

```gdscript
save_profiles.save_preparation_work_budget_per_tick = 64
save_profiles.save_preparation_slice_budget = 8
save_profiles.save_preparation_time_budget_usec = 2000

var result: GFSaveProfileResult
if operation.is_completed():
	result = operation.get_result()
else:
	result = await operation.completed
if not result.is_successful():
	push_warning(result.get_error())

print("prepare_ms=", result.get_preparation_duration_msec())
print("storage_ms=", result.get_storage_duration_msec())
print("prepare_units=", result.get_preparation_work_units())
```

准备完成后，Profile 把 section records 和文档头组装成一次性
`GFStoragePayloadTransfer`。Storage 首次 claim 会冻结 Storage 实例、规范文件名、
canonical target file-family identity 与 codec options；写入超时后，同一 generation
的新 attempt 可在旧 detached attempt 尚未结束时从同一个 transfer 取得只读 lease。
所有 attempt 共享同一逻辑 Snapshot，最后一个 lease 结束且 Profile 调用 `release()`
后才释放载荷，重试不会重新遍历 Provider 或重新复制完整文档。

`GFSaveProfileResult` 分开报告 preparation 与活跃 Storage attempt 的累计耗时；重试
等待不计入 Storage 耗时；detached attempt 与重试同时活跃时，各自的活跃区间都会
计入，因此重叠区间会按两个物理 attempt 分别累计。worker 载荷失败由隔离 Adapter
转换为标准校验报告，并只用文档构造时记录的 Dictionary entry index 推断 section，
不复制 key/value 或任何 key 派生摘要。Save 结果不再携带完整 `GFSaveDocument`，
因此 Save 的 `get_document()` 返回 `null`；只有 load 结果会返回迁移、校验后的文档。
调用方审计 Save 时应读取 generation、request IDs、阶段耗时、校验报告和独立
result metadata，而不是依赖一份额外深复制的完整文档。Save Operation 只保留
result metadata，不保留 document metadata 或 Provider context。

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
