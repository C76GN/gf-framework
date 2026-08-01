# GFSaveProfileResult

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_result.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

Save Profile 操作的不可变终态快照。 结果同时保留 profile generation、底层存储结果、迁移/校验证据和回滚错误， 调用方无需从错误文本反推失败阶段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_SAVED`](#member-gfsaveprofileresult-constants-status_saved) | `const STATUS_SAVED: StringName = &"saved"` |
| 常量 | [`STATUS_LOADED`](#member-gfsaveprofileresult-constants-status_loaded) | `const STATUS_LOADED: StringName = &"loaded"` |
| 常量 | [`STATUS_FLUSHED`](#member-gfsaveprofileresult-constants-status_flushed) | `const STATUS_FLUSHED: StringName = &"flushed"` |
| 常量 | [`STATUS_RECOVERED`](#member-gfsaveprofileresult-constants-status_recovered) | `const STATUS_RECOVERED: StringName = &"recovered"` |
| 常量 | [`STATUS_INVALID_PROFILE`](#member-gfsaveprofileresult-constants-status_invalid_profile) | `const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfsaveprofileresult-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_UNSUPPORTED_OPERATION`](#member-gfsaveprofileresult-constants-status_unsupported_operation) | `const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"` |
| 常量 | [`STATUS_BUSY`](#member-gfsaveprofileresult-constants-status_busy) | `const STATUS_BUSY: StringName = &"busy"` |
| 常量 | [`STATUS_PREPARATION_FAILED`](#member-gfsaveprofileresult-constants-status_preparation_failed) | `const STATUS_PREPARATION_FAILED: StringName = &"preparation_failed"` |
| 常量 | [`STATUS_SNAPSHOT_FAILED`](#member-gfsaveprofileresult-constants-status_snapshot_failed) | `const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"` |
| 常量 | [`STATUS_STORAGE_FAILED`](#member-gfsaveprofileresult-constants-status_storage_failed) | `const STATUS_STORAGE_FAILED: StringName = &"storage_failed"` |
| 常量 | [`STATUS_MISSING`](#member-gfsaveprofileresult-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_CORRUPT`](#member-gfsaveprofileresult-constants-status_corrupt) | `const STATUS_CORRUPT: StringName = &"corrupt"` |
| 常量 | [`STATUS_SCHEMA_MISMATCH`](#member-gfsaveprofileresult-constants-status_schema_mismatch) | `const STATUS_SCHEMA_MISMATCH: StringName = &"schema_mismatch"` |
| 常量 | [`STATUS_FUTURE_SCHEMA`](#member-gfsaveprofileresult-constants-status_future_schema) | `const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"` |
| 常量 | [`STATUS_MIGRATION_FAILED`](#member-gfsaveprofileresult-constants-status_migration_failed) | `const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"` |
| 常量 | [`STATUS_VALIDATION_FAILED`](#member-gfsaveprofileresult-constants-status_validation_failed) | `const STATUS_VALIDATION_FAILED: StringName = &"validation_failed"` |
| 常量 | [`STATUS_APPLY_FAILED`](#member-gfsaveprofileresult-constants-status_apply_failed) | `const STATUS_APPLY_FAILED: StringName = &"apply_failed"` |
| 常量 | [`STATUS_ROLLBACK_FAILED`](#member-gfsaveprofileresult-constants-status_rollback_failed) | `const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfsaveprofileresult-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 常量 | [`STATUS_OUTCOME_UNKNOWN`](#member-gfsaveprofileresult-constants-status_outcome_unknown) | `const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"` |
| 方法 | [`is_successful`](#member-gfsaveprofileresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfsaveprofileresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_operation`](#member-gfsaveprofileresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_profile_id`](#member-gfsaveprofileresult-methods-get_profile_id) | `func get_profile_id() -> StringName:` |
| 方法 | [`get_requested_generation`](#member-gfsaveprofileresult-methods-get_requested_generation) | `func get_requested_generation() -> int:` |
| 方法 | [`get_persisted_generation`](#member-gfsaveprofileresult-methods-get_persisted_generation) | `func get_persisted_generation() -> int:` |
| 方法 | [`get_attempt_count`](#member-gfsaveprofileresult-methods-get_attempt_count) | `func get_attempt_count() -> int:` |
| 方法 | [`was_coalesced`](#member-gfsaveprofileresult-methods-was_coalesced) | `func was_coalesced() -> bool:` |
| 方法 | [`was_recovered`](#member-gfsaveprofileresult-methods-was_recovered) | `func was_recovered() -> bool:` |
| 方法 | [`get_recovery_action`](#member-gfsaveprofileresult-methods-get_recovery_action) | `func get_recovery_action() -> StringName:` |
| 方法 | [`get_failed_section_id`](#member-gfsaveprofileresult-methods-get_failed_section_id) | `func get_failed_section_id() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfsaveprofileresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfsaveprofileresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_document`](#member-gfsaveprofileresult-methods-get_document) | `func get_document() -> GFSaveDocument:` |
| 方法 | [`get_storage_result`](#member-gfsaveprofileresult-methods-get_storage_result) | `func get_storage_result() -> GFStorageReadResult:` |
| 方法 | [`get_migration_result`](#member-gfsaveprofileresult-methods-get_migration_result) | `func get_migration_result() -> GFSaveMigrationResult:` |
| 方法 | [`get_validation_report`](#member-gfsaveprofileresult-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |
| 方法 | [`get_rollback_errors`](#member-gfsaveprofileresult-methods-get_rollback_errors) | `func get_rollback_errors() -> Array[GFSaveRollbackFailure]:` |
| 方法 | [`get_duration_msec`](#member-gfsaveprofileresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`get_preparation_duration_msec`](#member-gfsaveprofileresult-methods-get_preparation_duration_msec) | `func get_preparation_duration_msec() -> int:` |
| 方法 | [`get_storage_duration_msec`](#member-gfsaveprofileresult-methods-get_storage_duration_msec) | `func get_storage_duration_msec() -> int:` |
| 方法 | [`get_preparation_work_units`](#member-gfsaveprofileresult-methods-get_preparation_work_units) | `func get_preparation_work_units() -> int:` |
| 方法 | [`get_metadata`](#member-gfsaveprofileresult-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_storage_request_ids`](#member-gfsaveprofileresult-methods-get_storage_request_ids) | `func get_storage_request_ids() -> PackedInt64Array:` |
| 方法 | [`to_dict`](#member-gfsaveprofileresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfsaveprofileresult-methods-duplicate_result) | `func duplicate_result() -> GFSaveProfileResult:` |

## 常量

<a id="member-gfsaveprofileresult-constants-status_saved"></a>

### `STATUS_SAVED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_SAVED: StringName = &"saved"
```

保存 generation 已持久化。

<a id="member-gfsaveprofileresult-constants-status_loaded"></a>

### `STATUS_LOADED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_LOADED: StringName = &"loaded"
```

文档已迁移、校验并应用。

<a id="member-gfsaveprofileresult-constants-status_flushed"></a>

### `STATUS_FLUSHED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_FLUSHED: StringName = &"flushed"
```

flush 目标 generation 已持久化。

<a id="member-gfsaveprofileresult-constants-status_recovered"></a>

### `STATUS_RECOVERED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_RECOVERED: StringName = &"recovered"
```

恢复政策保留了当前内存状态。

<a id="member-gfsaveprofileresult-constants-status_invalid_profile"></a>

### `STATUS_INVALID_PROFILE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVALID_PROFILE: StringName = &"invalid_profile"
```

Profile 配置或请求无效。

<a id="member-gfsaveprofileresult-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

保存请求句柄无效或已经被接管。

<a id="member-gfsaveprofileresult-constants-status_unsupported_operation"></a>

### `STATUS_UNSUPPORTED_OPERATION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_UNSUPPORTED_OPERATION: StringName = &"unsupported_operation"
```

当前 Profile 不支持请求的操作。

<a id="member-gfsaveprofileresult-constants-status_busy"></a>

### `STATUS_BUSY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_BUSY: StringName = &"busy"
```

请求与正在执行的加载或 Provider 回调冲突。

<a id="member-gfsaveprofileresult-constants-status_preparation_failed"></a>

### `STATUS_PREPARATION_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_PREPARATION_FAILED: StringName = &"preparation_failed"
```

section Snapshot 准备或 worker 载荷预检失败。

<a id="member-gfsaveprofileresult-constants-status_snapshot_failed"></a>

### `STATUS_SNAPSHOT_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_SNAPSHOT_FAILED: StringName = &"snapshot_failed"
```

section 应用前快照采集失败。

<a id="member-gfsaveprofileresult-constants-status_storage_failed"></a>

### `STATUS_STORAGE_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_STORAGE_FAILED: StringName = &"storage_failed"
```

底层存储启动或执行失败。

<a id="member-gfsaveprofileresult-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

存档文件不存在。

<a id="member-gfsaveprofileresult-constants-status_corrupt"></a>

### `STATUS_CORRUPT`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_CORRUPT: StringName = &"corrupt"
```

存档文档损坏或完整性失败。

<a id="member-gfsaveprofileresult-constants-status_schema_mismatch"></a>

### `STATUS_SCHEMA_MISMATCH`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_SCHEMA_MISMATCH: StringName = &"schema_mismatch"
```

文档 schema ID 与 profile 不匹配。

<a id="member-gfsaveprofileresult-constants-status_future_schema"></a>

### `STATUS_FUTURE_SCHEMA`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_FUTURE_SCHEMA: StringName = &"future_schema"
```

文档或 section 来自未来 schema。

<a id="member-gfsaveprofileresult-constants-status_migration_failed"></a>

### `STATUS_MIGRATION_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_MIGRATION_FAILED: StringName = &"migration_failed"
```

旧版本文档迁移失败或缺少迁移链。

<a id="member-gfsaveprofileresult-constants-status_validation_failed"></a>

### `STATUS_VALIDATION_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_VALIDATION_FAILED: StringName = &"validation_failed"
```

当前版本文档校验失败。

<a id="member-gfsaveprofileresult-constants-status_apply_failed"></a>

### `STATUS_APPLY_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_APPLY_FAILED: StringName = &"apply_failed"
```

section provider 应用失败且回滚成功。

<a id="member-gfsaveprofileresult-constants-status_rollback_failed"></a>

### `STATUS_ROLLBACK_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_ROLLBACK_FAILED: StringName = &"rollback_failed"
```

section provider 应用失败且至少一个回滚失败。

<a id="member-gfsaveprofileresult-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

Utility 释放时操作仍未完成。

<a id="member-gfsaveprofileresult-constants-status_outcome_unknown"></a>

### `STATUS_OUTCOME_UNKNOWN`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_OUTCOME_UNKNOWN: StringName = &"outcome_unknown"
```

写入已提交到底层但无法确认最终磁盘副作用。

## 方法

<a id="member-gfsaveprofileresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查操作是否成功。

返回：成功终态返回 true。

<a id="member-gfsaveprofileresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_status() -> StringName:
```

获取稳定终态状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfsaveprofileresult-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_operation() -> StringName:
```

获取操作类型。

返回：save、load 或 flush。

<a id="member-gfsaveprofileresult-methods-get_profile_id"></a>

### `get_profile_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_profile_id() -> StringName:
```

获取 profile ID。

返回：profile ID。

<a id="member-gfsaveprofileresult-methods-get_requested_generation"></a>

### `get_requested_generation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_requested_generation() -> int:
```

获取调用方请求时的 generation。

返回：非负 generation。

<a id="member-gfsaveprofileresult-methods-get_persisted_generation"></a>

### `get_persisted_generation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_persisted_generation() -> int:
```

获取终态时已持久化的 generation。

返回：非负 generation。

<a id="member-gfsaveprofileresult-methods-get_attempt_count"></a>

### `get_attempt_count`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_attempt_count() -> int:
```

获取底层 IO 尝试次数。

返回：未启动 IO 时为 0。

<a id="member-gfsaveprofileresult-methods-was_coalesced"></a>

### `was_coalesced`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func was_coalesced() -> bool:
```

检查保存请求是否由更新 generation 的写入覆盖完成。

返回：被合并时返回 true。

<a id="member-gfsaveprofileresult-methods-was_recovered"></a>

### `was_recovered`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func was_recovered() -> bool:
```

检查是否通过恢复政策保留了当前状态。

返回：使用恢复动作时返回 true。

<a id="member-gfsaveprofileresult-methods-get_recovery_action"></a>

### `get_recovery_action`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_recovery_action() -> StringName:
```

获取实际恢复动作。

返回：未恢复时为空。

<a id="member-gfsaveprofileresult-methods-get_failed_section_id"></a>

### `get_failed_section_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_failed_section_id() -> StringName:
```

获取首个失败 section ID。

返回：非 section 失败时为空。

<a id="member-gfsaveprofileresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_error_code() -> Error:
```

获取 Godot Error 码。

返回：成功时为 OK。

<a id="member-gfsaveprofileresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_error() -> String:
```

获取稳定错误描述。

返回：成功时为空。

<a id="member-gfsaveprofileresult-methods-get_document"></a>

### `get_document`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_document() -> GFSaveDocument:
```

获取读取流程的最终文档副本。 Save 操作使用单所有者 Storage 交接，不再为结果额外复制完整文档，因此只在 load 结果中提供文档。

返回：load 操作已迁移和校验的文档；其他操作返回 null。

<a id="member-gfsaveprofileresult-methods-get_storage_result"></a>

### `get_storage_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_storage_result() -> GFStorageReadResult:
```

获取底层读取结果副本。

返回：load 操作的原始读取结果；其他操作或读取未启动时为 null。

<a id="member-gfsaveprofileresult-methods-get_migration_result"></a>

### `get_migration_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_migration_result() -> GFSaveMigrationResult:
```

获取迁移结果副本。

返回：执行迁移时的结果；否则为 null。

<a id="member-gfsaveprofileresult-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取最终校验报告副本。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report or an empty Dictionary.

<a id="member-gfsaveprofileresult-methods-get_rollback_errors"></a>

### `get_rollback_errors`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_rollback_errors() -> Array[GFSaveRollbackFailure]:
```

获取回滚失败证据副本。

返回：按回滚顺序记录的类型化失败证据。

<a id="member-gfsaveprofileresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_duration_msec() -> int:
```

获取操作耗时。

返回：单调毫秒耗时。

<a id="member-gfsaveprofileresult-methods-get_preparation_duration_msec"></a>

### `get_preparation_duration_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_preparation_duration_msec() -> int:
```

获取保存准备阶段耗时。 该值只覆盖 Provider Snapshot 与交接准备，不包含 Storage IO；非 Save 操作为 0。

返回：单调毫秒耗时。

<a id="member-gfsaveprofileresult-methods-get_storage_duration_msec"></a>

### `get_storage_duration_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_storage_duration_msec() -> int:
```

获取活跃 Storage attempt 累计耗时。 重试等待时间不计入该值；非 IO 操作为 0。

返回：单调毫秒耗时。

<a id="member-gfsaveprofileresult-methods-get_preparation_work_units"></a>

### `get_preparation_work_units`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_preparation_work_units() -> int:
```

获取保存准备累计消费的 work units。

返回：非负 work units。

<a id="member-gfsaveprofileresult-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取调用方元数据副本。

返回：调用方定义的临时结果元数据。

结构：

- `return`: Dictionary with caller-defined operation metadata.

<a id="member-gfsaveprofileresult-methods-get_storage_request_ids"></a>

### `get_storage_request_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_storage_request_ids() -> PackedInt64Array:
```

获取支撑当前终态的底层 Storage 请求 ID。

返回：按发起顺序排列的请求 ID；没有底层 IO 时为空。

<a id="member-gfsaveprofileresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可报告字典。

返回：不包含完整文档载荷的结果摘要。

结构：

- `return`: Dictionary with ok, status, operation, profile_id, generation, timing, recovery, error, validation, rollback, and metadata fields.

<a id="member-gfsaveprofileresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_result() -> GFSaveProfileResult:
```

创建隔离结果副本。

返回：新结果对象。
