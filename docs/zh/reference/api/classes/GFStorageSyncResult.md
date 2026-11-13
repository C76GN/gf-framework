# GFStorageSyncResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

一次同步观察的不可变终态。 COMMITTED 表示远端提交与本地 checkpoint 均已确认。OUTCOME_UNKNOWN 表示无法 查证远端结果；RECOVERY_REQUIRED 可以表示远端已确认而本地 checkpoint 尚未确认。 preview 和 remote_selected 都不表示已写入本地业务状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfstoragesyncresult-enums-status) | `enum Status` |
| 方法 | [`is_valid`](#member-gfstoragesyncresult-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_status`](#member-gfstoragesyncresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_status_name`](#member-gfstoragesyncresult-methods-get_status_name) | `func get_status_name() -> StringName:` |
| 方法 | [`is_successful`](#member-gfstoragesyncresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`requires_recovery`](#member-gfstoragesyncresult-methods-requires_recovery) | `func requires_recovery() -> bool:` |
| 方法 | [`get_request`](#member-gfstoragesyncresult-methods-get_request) | `func get_request() -> GFStorageSyncRequest:` |
| 方法 | [`get_error_kind`](#member-gfstoragesyncresult-methods-get_error_kind) | `func get_error_kind() -> StringName:` |
| 方法 | [`record_exists`](#member-gfstoragesyncresult-methods-record_exists) | `func record_exists() -> bool:` |
| 方法 | [`get_revision`](#member-gfstoragesyncresult-methods-get_revision) | `func get_revision() -> String:` |
| 方法 | [`get_data`](#member-gfstoragesyncresult-methods-get_data) | `func get_data() -> Dictionary:` |
| 方法 | [`is_remote_committed`](#member-gfstoragesyncresult-methods-is_remote_committed) | `func is_remote_committed() -> bool:` |
| 方法 | [`get_conflict_report`](#member-gfstoragesyncresult-methods-get_conflict_report) | `func get_conflict_report() -> GFStorageConflictReport:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragesyncresult-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfstoragesyncresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 只读比较完成。
	PREVIEW,
	## 当前远端数据与候选相同，没有提交写入。
	UNCHANGED,
	## 已取得明确选择的远端候选，尚未应用到本地业务状态。
	REMOTE_SELECTED,
	## 远端提交和本地 checkpoint 都已持久化确认。
	COMMITTED,
	## revision 不匹配或条件提交发生并发竞争。
	CONFLICT,
	## 本次未发送，或已查证没有提交。
	NOT_COMMITTED,
	## 本次可能已提交，需要按原操作 ID 查证。
	OUTCOME_UNKNOWN,
	## 远端结果已取得，但本地持久化结果尚待恢复。
	RECOVERY_REQUIRED,
	## 请求、能力、所有权或协议准入被拒绝。
	REJECTED,
}
```

唯一终态；不会因迟到响应重新变更。

## 方法

<a id="member-gfstoragesyncresult-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查结果是否已经由引擎封存。

返回：已配置返回 true。

<a id="member-gfstoragesyncresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取唯一终态。

返回：Status 枚举值。

<a id="member-gfstoragesyncresult-methods-get_status_name"></a>

### `get_status_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status_name() -> StringName:
```

获取稳定的 ASCII 状态名。

返回：对应 Status 的小写名称。

<a id="member-gfstoragesyncresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查本次观察是否成功完成；不能替代 COMMITTED 或本地业务事务结果检查。

返回：preview、unchanged、remote_selected 或 committed 时为 true。

<a id="member-gfstoragesyncresult-methods-requires_recovery"></a>

### `requires_recovery`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func requires_recovery() -> bool:
```

检查是否需要按持久化意图恢复。

返回：未知远端结果或未确认本地 checkpoint 时为 true。

<a id="member-gfstoragesyncresult-methods-get_request"></a>

### `get_request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request() -> GFStorageSyncRequest:
```

获取本次实际使用的冻结请求。

返回：请求对象；拒绝非法输入时可能为空。

<a id="member-gfstoragesyncresult-methods-get_error_kind"></a>

### `get_error_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_kind() -> StringName:
```

获取稳定错误种类，不包含适配器的任意原始错误文本。

返回：ASCII 错误种类或空。

<a id="member-gfstoragesyncresult-methods-record_exists"></a>

### `record_exists`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func record_exists() -> bool:
```

检查已观察的远端记录是否存在。

返回：存在时为 true；结果未知时不能据此推断记录不存在。

<a id="member-gfstoragesyncresult-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_revision() -> String:
```

获取已观察的远端 revision。

返回：不透明文本；不得排序比较。

<a id="member-gfstoragesyncresult-methods-get_data"></a>

### `get_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_data() -> Dictionary:
```

显式获取远端数据的隔离副本。

返回：已验证数据副本，是否存在由 record_exists() 和终态决定。

结构：

- `return`: Dictionary of admitted native data.

<a id="member-gfstoragesyncresult-methods-is_remote_committed"></a>

### `is_remote_committed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_remote_committed() -> bool:
```

检查是否已有远端提交的明确证据。

返回：已查证提交时为 true，即使本地 checkpoint 仍待恢复。

<a id="member-gfstoragesyncresult-methods-get_conflict_report"></a>

### `get_conflict_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_conflict_report() -> GFStorageConflictReport:
```

获取隔离的冲突报告。

返回：报告副本或 null。

<a id="member-gfstoragesyncresult-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含业务载荷、身份文本或 revision 的诊断摘要。

返回：终态和确认边界摘要。

结构：

- `return`: Dictionary with valid,status,error_kind,remote_committed,requires_recovery,has_conflict,local_generation.
