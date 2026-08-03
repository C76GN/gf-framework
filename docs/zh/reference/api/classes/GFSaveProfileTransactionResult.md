# GFSaveProfileTransactionResult

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_transaction_result.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

Profile 事务的不可变终态快照。 结果不保留文档、section、Provider snapshot 或候选 payload，只保留有界阶段 证据、类型化回滚失败、调用方元数据和必要的 Lease。`duplicate_result()` 会 隔离复制集合，但刻意保留 Recovery/Reconcile Lease 的同一对象身份。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_ACTIVATED`](#member-gfsaveprofiletransactionresult-constants-status_activated) | `const STATUS_ACTIVATED: StringName = &"activated"` |
| 常量 | [`STATUS_SWITCHED`](#member-gfsaveprofiletransactionresult-constants-status_switched) | `const STATUS_SWITCHED: StringName = &"switched"` |
| 常量 | [`STATUS_BOOTSTRAPPED`](#member-gfsaveprofiletransactionresult-constants-status_bootstrapped) | `const STATUS_BOOTSTRAPPED: StringName = &"bootstrapped"` |
| 常量 | [`STATUS_ADOPTED`](#member-gfsaveprofiletransactionresult-constants-status_adopted) | `const STATUS_ADOPTED: StringName = &"adopted"` |
| 常量 | [`STATUS_MUTATED`](#member-gfsaveprofiletransactionresult-constants-status_mutated) | `const STATUS_MUTATED: StringName = &"mutated"` |
| 常量 | [`STATUS_RECONCILED`](#member-gfsaveprofiletransactionresult-constants-status_reconciled) | `const STATUS_RECONCILED: StringName = &"reconciled"` |
| 常量 | [`STATUS_INVALID_PROFILE`](#member-gfsaveprofiletransactionresult-constants-status_invalid_profile) | `const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfsaveprofiletransactionresult-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_INVALID_LEASE`](#member-gfsaveprofiletransactionresult-constants-status_invalid_lease) | `const STATUS_INVALID_LEASE: StringName = &"invalid_lease"` |
| 常量 | [`STATUS_INACTIVE`](#member-gfsaveprofiletransactionresult-constants-status_inactive) | `const STATUS_INACTIVE: StringName = &"inactive"` |
| 常量 | [`STATUS_ALREADY_ACTIVE`](#member-gfsaveprofiletransactionresult-constants-status_already_active) | `const STATUS_ALREADY_ACTIVE: StringName = &"already_active"` |
| 常量 | [`STATUS_BUSY`](#member-gfsaveprofiletransactionresult-constants-status_busy) | `const STATUS_BUSY: StringName = &"busy"` |
| 常量 | [`STATUS_UNSUPPORTED_OPERATION`](#member-gfsaveprofiletransactionresult-constants-status_unsupported_operation) | `const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"` |
| 常量 | [`STATUS_RECOVERY_REQUIRED`](#member-gfsaveprofiletransactionresult-constants-status_recovery_required) | `const STATUS_RECOVERY_REQUIRED: StringName = &"recovery_required"` |
| 常量 | [`STATUS_SOURCE_FLUSH_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_source_flush_failed) | `const STATUS_SOURCE_FLUSH_FAILED: StringName = &"source_flush_failed"` |
| 常量 | [`STATUS_TARGET_LOAD_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_target_load_failed) | `const STATUS_TARGET_LOAD_FAILED: StringName = &"target_load_failed"` |
| 常量 | [`STATUS_SNAPSHOT_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_snapshot_failed) | `const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"` |
| 常量 | [`STATUS_APPLY_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_apply_failed) | `const STATUS_APPLY_FAILED: StringName = &"apply_failed"` |
| 常量 | [`STATUS_ROLLBACK_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_rollback_failed) | `const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"` |
| 常量 | [`STATUS_PERSIST_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_persist_failed) | `const STATUS_PERSIST_FAILED: StringName = &"persist_failed"` |
| 常量 | [`STATUS_OUTCOME_UNKNOWN`](#member-gfsaveprofiletransactionresult-constants-status_outcome_unknown) | `const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"` |
| 常量 | [`STATUS_RECONCILE_PENDING`](#member-gfsaveprofiletransactionresult-constants-status_reconcile_pending) | `const STATUS_RECONCILE_PENDING: StringName = &"reconcile_pending"` |
| 常量 | [`STATUS_RECONCILE_FAILED`](#member-gfsaveprofiletransactionresult-constants-status_reconcile_failed) | `const STATUS_RECONCILE_FAILED: StringName = &"reconcile_failed"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfsaveprofiletransactionresult-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 方法 | [`is_successful`](#member-gfsaveprofiletransactionresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfsaveprofiletransactionresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_operation`](#member-gfsaveprofiletransactionresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_transaction_id`](#member-gfsaveprofiletransactionresult-methods-get_transaction_id) | `func get_transaction_id() -> int:` |
| 方法 | [`get_source_profile_id`](#member-gfsaveprofiletransactionresult-methods-get_source_profile_id) | `func get_source_profile_id() -> StringName:` |
| 方法 | [`get_target_profile_id`](#member-gfsaveprofiletransactionresult-methods-get_target_profile_id) | `func get_target_profile_id() -> StringName:` |
| 方法 | [`get_active_profile_before`](#member-gfsaveprofiletransactionresult-methods-get_active_profile_before) | `func get_active_profile_before() -> StringName:` |
| 方法 | [`get_active_profile_after`](#member-gfsaveprofiletransactionresult-methods-get_active_profile_after) | `func get_active_profile_after() -> StringName:` |
| 方法 | [`get_phase`](#member-gfsaveprofiletransactionresult-methods-get_phase) | `func get_phase() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfsaveprofiletransactionresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsaveprofiletransactionresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_failed_section_id`](#member-gfsaveprofiletransactionresult-methods-get_failed_section_id) | `func get_failed_section_id() -> StringName:` |
| 方法 | [`get_rollback_errors`](#member-gfsaveprofiletransactionresult-methods-get_rollback_errors) | `func get_rollback_errors() -> Array[GFSaveRollbackFailure]:` |
| 方法 | [`get_stage_evidence`](#member-gfsaveprofiletransactionresult-methods-get_stage_evidence) | `func get_stage_evidence() -> Dictionary:` |
| 方法 | [`get_recovery_lease`](#member-gfsaveprofiletransactionresult-methods-get_recovery_lease) | `func get_recovery_lease() -> GFSaveProfileRecoveryLease:` |
| 方法 | [`get_reconcile_lease`](#member-gfsaveprofiletransactionresult-methods-get_reconcile_lease) | `func get_reconcile_lease() -> GFSaveProfileReconcileLease:` |
| 方法 | [`get_metadata`](#member-gfsaveprofiletransactionresult-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_started_at_msec`](#member-gfsaveprofiletransactionresult-methods-get_started_at_msec) | `func get_started_at_msec() -> int:` |
| 方法 | [`get_completed_at_msec`](#member-gfsaveprofiletransactionresult-methods-get_completed_at_msec) | `func get_completed_at_msec() -> int:` |
| 方法 | [`get_duration_msec`](#member-gfsaveprofiletransactionresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`duplicate_result`](#member-gfsaveprofiletransactionresult-methods-duplicate_result) | `func duplicate_result() -> GFSaveProfileTransactionResult:` |
| 方法 | [`to_dict`](#member-gfsaveprofiletransactionresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfsaveprofiletransactionresult-constants-status_activated"></a>

### `STATUS_ACTIVATED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_ACTIVATED: StringName = &"activated"
```

已存在 Profile 已成功激活。

<a id="member-gfsaveprofiletransactionresult-constants-status_switched"></a>

### `STATUS_SWITCHED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SWITCHED: StringName = &"switched"
```

活跃身份已成功切换。

<a id="member-gfsaveprofiletransactionresult-constants-status_bootstrapped"></a>

### `STATUS_BOOTSTRAPPED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_BOOTSTRAPPED: StringName = &"bootstrapped"
```

缺失 Profile 已从当前状态显式创建并激活。

<a id="member-gfsaveprofiletransactionresult-constants-status_adopted"></a>

### `STATUS_ADOPTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_ADOPTED: StringName = &"adopted"
```

当前状态已被显式采用为恢复后的活跃 Profile。

<a id="member-gfsaveprofiletransactionresult-constants-status_mutated"></a>

### `STATUS_MUTATED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_MUTATED: StringName = &"mutated"
```

候选 sections 已应用并持久化。

<a id="member-gfsaveprofiletransactionresult-constants-status_reconciled"></a>

### `STATUS_RECONCILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECONCILED: StringName = &"reconciled"
```

outcome_unknown 已通过显式重新读取完成对账。

<a id="member-gfsaveprofiletransactionresult-constants-status_invalid_profile"></a>

### `STATUS_INVALID_PROFILE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"
```

Profile ID、Provider topology 或事务身份无效。

<a id="member-gfsaveprofiletransactionresult-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

一次性请求无效、已被 claim 或含不支持的数据。

<a id="member-gfsaveprofiletransactionresult-constants-status_invalid_lease"></a>

### `STATUS_INVALID_LEASE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_LEASE: StringName = &"invalid_lease"
```

Recovery/Reconcile Lease 无效、已消费或绑定已经过期。

<a id="member-gfsaveprofiletransactionresult-constants-status_inactive"></a>

### `STATUS_INACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INACTIVE: StringName = &"inactive"
```

请求要求活跃 Profile，但当前 Provider domain 未激活。

<a id="member-gfsaveprofiletransactionresult-constants-status_already_active"></a>

### `STATUS_ALREADY_ACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_ALREADY_ACTIVE: StringName = &"already_active"
```

activate/bootstrap/adopt 的目标 domain 已有活跃 Profile。

<a id="member-gfsaveprofiletransactionresult-constants-status_busy"></a>

### `STATUS_BUSY`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_BUSY: StringName = &"busy"
```

Provider domain 正在执行互斥事务或发生不安全回调重入。

<a id="member-gfsaveprofiletransactionresult-constants-status_unsupported_operation"></a>

### `STATUS_UNSUPPORTED_OPERATION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"
```

Profile 配置不支持请求的读取或写入阶段。

<a id="member-gfsaveprofiletransactionresult-constants-status_recovery_required"></a>

### `STATUS_RECOVERY_REQUIRED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECOVERY_REQUIRED: StringName = &"recovery_required"
```

activate 检测到缺失或损坏文档，必须显式选择 bootstrap 或 adopt。

<a id="member-gfsaveprofiletransactionresult-constants-status_source_flush_failed"></a>

### `STATUS_SOURCE_FLUSH_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SOURCE_FLUSH_FAILED: StringName = &"source_flush_failed"
```

switch 无法把来源 Profile flush 到调用时 generation barrier。

<a id="member-gfsaveprofiletransactionresult-constants-status_target_load_failed"></a>

### `STATUS_TARGET_LOAD_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_TARGET_LOAD_FAILED: StringName = &"target_load_failed"
```

switch 已 flush 来源，但无法读取或应用目标 Profile。

<a id="member-gfsaveprofiletransactionresult-constants-status_snapshot_failed"></a>

### `STATUS_SNAPSHOT_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"
```

Provider 回滚或候选应用前的快照采集失败。

<a id="member-gfsaveprofiletransactionresult-constants-status_apply_failed"></a>

### `STATUS_APPLY_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_APPLY_FAILED: StringName = &"apply_failed"
```

至少一个候选 section 应用失败，且内存回滚成功。

<a id="member-gfsaveprofiletransactionresult-constants-status_rollback_failed"></a>

### `STATUS_ROLLBACK_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"
```

恢复来源或候选内存状态时至少一个 Provider 回滚失败。

<a id="member-gfsaveprofiletransactionresult-constants-status_persist_failed"></a>

### `STATUS_PERSIST_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_PERSIST_FAILED: StringName = &"persist_failed"
```

候选持久化确定失败，且内存回滚已成功。

<a id="member-gfsaveprofiletransactionresult-constants-status_outcome_unknown"></a>

### `STATUS_OUTCOME_UNKNOWN`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"
```

写请求已进入底层，但其最终物理副作用无法确认。

<a id="member-gfsaveprofiletransactionresult-constants-status_reconcile_pending"></a>

### `STATUS_RECONCILE_PENDING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECONCILE_PENDING: StringName = &"reconcile_pending"
```

Reconcile Lease 仍在等待 late settlement evidence。

<a id="member-gfsaveprofiletransactionresult-constants-status_reconcile_failed"></a>

### `STATUS_RECONCILE_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECONCILE_FAILED: StringName = &"reconcile_failed"
```

显式重新读取或证据校验未能完成对账。

<a id="member-gfsaveprofiletransactionresult-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

Utility 释放时事务仍未完成。

## 方法

<a id="member-gfsaveprofiletransactionresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查事务是否成功。

返回：终态属于成功状态时返回 true。

<a id="member-gfsaveprofiletransactionresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定终态状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfsaveprofiletransactionresult-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_operation() -> StringName:
```

获取事务类型。

返回：`GFSaveProfileTransactionOperation.OPERATION_*` 常量之一。

<a id="member-gfsaveprofiletransactionresult-methods-get_transaction_id"></a>

### `get_transaction_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_transaction_id() -> int:
```

获取 Utility 生命周期内唯一的事务 ID。

返回：正整数事务 ID。

<a id="member-gfsaveprofiletransactionresult-methods-get_source_profile_id"></a>

### `get_source_profile_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_profile_id() -> StringName:
```

获取事务来源 Profile ID。

返回：来源 Profile ID；不适用时为空。

<a id="member-gfsaveprofiletransactionresult-methods-get_target_profile_id"></a>

### `get_target_profile_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_profile_id() -> StringName:
```

获取事务目标 Profile ID。

返回：目标 Profile ID；不适用时为空。

<a id="member-gfsaveprofiletransactionresult-methods-get_active_profile_before"></a>

### `get_active_profile_before`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_profile_before() -> StringName:
```

获取事务开始前的活跃 Profile ID。

返回：开始前活跃身份；domain 未激活时为空。

<a id="member-gfsaveprofiletransactionresult-methods-get_active_profile_after"></a>

### `get_active_profile_after`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_profile_after() -> StringName:
```

获取事务终态后的活跃 Profile ID。

返回：终态活跃身份；未激活或身份未知时为空。

<a id="member-gfsaveprofiletransactionresult-methods-get_phase"></a>

### `get_phase`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_phase() -> StringName:
```

获取失败或成功发生的稳定阶段名。

返回：协调器定义的 payload-free 阶段名。

<a id="member-gfsaveprofiletransactionresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取 Godot Error 码。

返回：成功时为 OK。

<a id="member-gfsaveprofiletransactionresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取稳定错误描述。

返回：成功时为空；失败说明最多 2048 个字符。

<a id="member-gfsaveprofiletransactionresult-methods-get_failed_section_id"></a>

### `get_failed_section_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_section_id() -> StringName:
```

获取首个失败 section ID。

返回：非 section 失败时为空。

<a id="member-gfsaveprofiletransactionresult-methods-get_rollback_errors"></a>

### `get_rollback_errors`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_rollback_errors() -> Array[GFSaveRollbackFailure]:
```

获取类型化 Provider 回滚失败证据。

返回：按回滚顺序排列的隔离副本。

<a id="member-gfsaveprofiletransactionresult-methods-get_stage_evidence"></a>

### `get_stage_evidence`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stage_evidence() -> Dictionary:
```

获取不含文档、section 或 Provider payload 的阶段证据。

返回：有界 evidence 副本。

结构：

- `return`: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.

<a id="member-gfsaveprofiletransactionresult-methods-get_recovery_lease"></a>

### `get_recovery_lease`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_recovery_lease() -> GFSaveProfileRecoveryLease:
```

获取显式 bootstrap/adopt 所需的同一身份 Recovery Lease。

返回：recovery_required 结果中的 Lease；其他结果通常为 null。

<a id="member-gfsaveprofiletransactionresult-methods-get_reconcile_lease"></a>

### `get_reconcile_lease`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reconcile_lease() -> GFSaveProfileReconcileLease:
```

获取持续围栏 outcome_unknown 的同一身份 Reconcile Lease。

返回：需要或正在对账时的 Lease；不适用时为 null。

<a id="member-gfsaveprofiletransactionresult-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metadata() -> Dictionary:
```

获取调用方结果元数据副本。

返回：调用方在一次性请求中移交的结果元数据。

结构：

- `return`: Dictionary with caller-defined result metadata.

<a id="member-gfsaveprofiletransactionresult-methods-get_started_at_msec"></a>

### `get_started_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_started_at_msec() -> int:
```

获取事务开始时间。

返回：非负单调毫秒时间。

<a id="member-gfsaveprofiletransactionresult-methods-get_completed_at_msec"></a>

### `get_completed_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_completed_at_msec() -> int:
```

获取事务完成时间。

返回：不早于开始时间的单调毫秒时间。

<a id="member-gfsaveprofiletransactionresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_msec() -> int:
```

获取事务耗时。

返回：非负单调毫秒耗时。

<a id="member-gfsaveprofiletransactionresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFSaveProfileTransactionResult:
```

创建隔离结果副本。 Recovery/Reconcile Lease 不复制，以维持原始恢复授权和持续对账生命周期。

返回：新结果对象。

<a id="member-gfsaveprofiletransactionresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不包含持久化 payload 或 Lease 对象的报告字典。

返回：事务身份、终态、阶段证据、Lease 摘要、错误与时间信息。

结构：

- `return`: Payload-free Dictionary with transaction identity, status, active identities, phase, rollback failures, evidence, lease summaries, metadata, errors, and timing.
