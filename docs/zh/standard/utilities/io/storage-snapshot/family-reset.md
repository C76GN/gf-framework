# 显式重置损坏 Storage family

family reset 是 structural corruption 后的显式、破坏性恢复入口，不是普通删除、格式迁移或“忽略错误继续写入”。调用方必须先保留同一 `GFStorageUtility` 对目标 logical identity 返回的、来源绑定仍有效的 `CORRUPT` 读取结果，再签发一次性授权；缺失、未来格式、迁移失败、普通 IO、合成结果、跨文件或跨 Utility 的证据都不能授权。

## 来源绑定与调用流程

Storage 返回的 `GFStorageReadResult` 可携带不透明、不可序列化的来源绑定，用于证明观察确实来自同一个 Utility、同一冻结 root 与同一 canonical logical identity。只有已经确认当前 layout 后、由目标 family 的 intent、identity 或事务恢复产生的损坏才能取得该绑定；无关的全局 layout 或恢复失败保持 unbound。授权资格字段 `ok`、`error_code` 与 `failure_kind` 仍匹配签发快照时，`duplicate_result()` 会保留该绑定；`to_dict()` / `from_dict()`、`configure_success()`、`configure_failure()` 与 `apply_dict()` 都不会传播它。项目不能自行合成结果或改写授权资格字段来取得破坏性恢复权限。

```gdscript
var observed: GFStorageReadResult = storage.load_data("profile.json")
if not observed.ok and observed.failure_kind == GFStorageReadResult.FailureKind.CORRUPT:
	var authorization: GFStorageFamilyResetAuthorization = \
		storage.create_family_reset_authorization("profile.json", observed)
	var reset_result: GFStorageFamilyResetResult = \
		storage.reset_file_family("profile.json", authorization)
	if reset_result.is_successful():
		var save_error: Error = storage.save_data("profile.json", _build_default_profile())
		if save_error != OK:
			_report_storage_error(save_error)
```

`GFStorageFamilyResetAuthorization` 按 attempt 一次性消费，并冻结 Utility、root、canonical logical identity、私有 family identity 与产生该 `CORRUPT` 结果时的 family 观察快照。授权签发后，任何改变该快照的同 family 较新写入或修复都会让旧授权失效；同步 reset 在等待既有异步工作后重新验证，异步 reset 也会在轮到自己的 FIFO worker 时再次验证，不能用旧恢复决定退休新保存的健康数据。失败后不能重放同一授权。需要重试时，只能从当前来源绑定 `CORRUPT` 结果重新签发。只有 `GFStorageFamilyResetResult.is_successful()` 为真时才能保存默认值；`recreated_member_count` 不是可提交成功的替代判断。

## 收敛协议与结果

执行器先拒绝未知或未来 layout、已存在多个有效 identity、授权不匹配、扫描预算耗尽与 private ancestry 的 link/wrong-type 重定向，并检查其他 family 中仍存活、且声明目标为同一多成员事务成员的反向记录；存在这种记录时不能单独退休目标，反向记录无法读取、类型错误或语义形状不合法时也会零写失败关闭。通过后才持久化 reset intent、把旧 catalog/family identity 移入 retirement staging、发布新的 owner/catalog claim，最后有界清理旧证据。reset 只根据 canonical logical identity 与已经验证的内部 descriptor 修改目标，不收养相邻 family。

intent 是已经提交的授权决定；崩溃或 IO 失败后，同一 family 的后续正常 I/O 会先幂等收敛该 intent，不能越过它写入随后又被旧恢复删除的数据。未发布的 pending staging 无论是截断内容，还是文件名中的 reset/family identity 与正文不匹配，都作为未提交残留有界清理；同样的 exact intent 已经发布，语义不匹配时必须保留证据并失败关闭。损坏的已发布 intent、未知 layout 或歧义 identity 始终失败关闭。`GFStorageFamilyResetResult` 只暴露有界的来源、阶段、成员与 retired/recreated/remaining 计数，不暴露 root、opaque family ID 或私有路径。

## 异步与生命周期

`reset_file_family_request_async()` 使用 `GFStorageAsyncOperation.OPERATION_RESET`，并从 `GFStorageAsyncResult.get_reset_result()` 读取物理终态。它与 save/load/delete 共用同 family FIFO、threaded/cooperative 执行器、取消/deadline、caller/物理双终态、quiesce、dispose 与迟到诊断。

执行器接纳前取消会得到真实物理取消；已接纳 reset 可能已有 retirement 或 recreate 副作用，因此 caller-first 终态为 `GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN`。调用方不能把它解释成磁盘未修改，仍应等待同一个 Operation 的物理结算后对账。

## Settings 恢复

`GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS` 只恢复内存。使用 `GFStorageSettingsStoreUtility` 时，structural-corrupt family 必须先按上述流程完成 reset，再调用 `save_settings()` 持久化默认值；Settings 核心不会解析或删除 `.gf-storage` 私有布局。完整示例见[设置系统](../../runtime/settings-ui-scene/settings-display/settings-utility.md)。
