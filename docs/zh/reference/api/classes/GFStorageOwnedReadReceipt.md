# GFStorageOwnedReadReceipt

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_owned_read_receipt.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

独占读取的不可变 caller 终态诊断。 只保留请求身份、稳定状态、版本、完整性和实际读取的 committed revision。 不持有业务载荷、任意 metadata、物理路径或领取权限；共享诊断不会复制载荷。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FailureKind`](#member-gfstorageownedreadreceipt-enums-failurekind) | `enum FailureKind` |
| 方法 | [`get_request_id`](#member-gfstorageownedreadreceipt-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_consumer_id`](#member-gfstorageownedreadreceipt-methods-get_consumer_id) | `func get_consumer_id() -> int:` |
| 方法 | [`get_file_name`](#member-gfstorageownedreadreceipt-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`get_status`](#member-gfstorageownedreadreceipt-methods-get_status) | `func get_status() -> GFStorageAsyncCallerResult.Status:` |
| 方法 | [`get_end_kind`](#member-gfstorageownedreadreceipt-methods-get_end_kind) | `func get_end_kind() -> GFStorageAsyncCallerResult.EndKind:` |
| 方法 | [`get_error_code`](#member-gfstorageownedreadreceipt-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_failure_kind`](#member-gfstorageownedreadreceipt-methods-get_failure_kind) | `func get_failure_kind() -> FailureKind:` |
| 方法 | [`get_read_failure_kind`](#member-gfstorageownedreadreceipt-methods-get_read_failure_kind) | `func get_read_failure_kind() -> GFStorageReadResult.FailureKind:` |
| 方法 | [`is_ok`](#member-gfstorageownedreadreceipt-methods-is_ok) | `func is_ok() -> bool:` |
| 方法 | [`get_source_version`](#member-gfstorageownedreadreceipt-methods-get_source_version) | `func get_source_version() -> int:` |
| 方法 | [`get_target_version`](#member-gfstorageownedreadreceipt-methods-get_target_version) | `func get_target_version() -> int:` |
| 方法 | [`was_migrated`](#member-gfstorageownedreadreceipt-methods-was_migrated) | `func was_migrated() -> bool:` |
| 方法 | [`was_integrity_checked`](#member-gfstorageownedreadreceipt-methods-was_integrity_checked) | `func was_integrity_checked() -> bool:` |
| 方法 | [`is_integrity_ok`](#member-gfstorageownedreadreceipt-methods-is_integrity_ok) | `func is_integrity_ok() -> bool:` |
| 方法 | [`get_committed_revision`](#member-gfstorageownedreadreceipt-methods-get_committed_revision) | `func get_committed_revision() -> GFStorageRevisionResult:` |
| 方法 | [`to_dict`](#member-gfstorageownedreadreceipt-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstorageownedreadreceipt-enums-failurekind"></a>

### `FailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureKind {
	## 读取及交付均成功。
	NONE,
	## 文件读取、解码、校验或迁移失败，详见读取失败分类。
	READ_FAILED,
	## 载荷无法安全隔离为独占纯数据；不表示磁盘文件损坏。
	UNSUPPORTED_PAYLOAD,
	## caller 在成功交付前停止观察。
	CANCELLED,
}
```

独占读取交付的稳定失败分类。

## 方法

<a id="member-gfstorageownedreadreceipt-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一的物理请求 ID。

返回：大于零的请求 ID；未配置时为 0。

<a id="member-gfstorageownedreadreceipt-methods-get_consumer_id"></a>

### `get_consumer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_consumer_id() -> int:
```

获取 Utility 内唯一的 consumer ID。

返回：大于零的 consumer ID；未配置时为 0。

<a id="member-gfstorageownedreadreceipt-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_file_name() -> String:
```

获取已校验的规范逻辑文件名。

返回：逻辑文件名；文件名校验前失败时可能为空。

<a id="member-gfstorageownedreadreceipt-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> GFStorageAsyncCallerResult.Status:
```

获取 caller 终态分类。

返回：PHYSICAL_SETTLED 或 CANCELLED；独占读取不会返回 OUTCOME_UNKNOWN。

<a id="member-gfstorageownedreadreceipt-methods-get_end_kind"></a>

### `get_end_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_end_kind() -> GFStorageAsyncCallerResult.EndKind:
```

获取 caller 终态的来源分类。

返回：物理结算、显式取消、令牌、超时、owner 释放或 Utility dispose。

<a id="member-gfstorageownedreadreceipt-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取稳定的 Godot Error 码。

返回：成功时为 OK，失败或取消时为非 OK。

<a id="member-gfstorageownedreadreceipt-methods-get_failure_kind"></a>

### `get_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_kind() -> FailureKind:
```

获取独占读取交付的失败分类。

返回：成功、读取失败、不支持独占交付或取消。

<a id="member-gfstorageownedreadreceipt-methods-get_read_failure_kind"></a>

### `get_read_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_read_failure_kind() -> GFStorageReadResult.FailureKind:
```

获取文件读取、解码、校验或迁移的失败分类。

返回：READ_FAILED 的具体原因；成功、取消和不支持交付时为 NONE。

<a id="member-gfstorageownedreadreceipt-methods-is_ok"></a>

### `is_ok`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_ok() -> bool:
```

检查 caller 是否获得成功的独占读取交付。

返回：已完成读取且没有读取或交付失败时返回 true。

<a id="member-gfstorageownedreadreceipt-methods-get_source_version"></a>

### `get_source_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_version() -> int:
```

获取本次读取发现的数据版本。

返回：迁移前的数据版本；未取得版本时为 0。

<a id="member-gfstorageownedreadreceipt-methods-get_target_version"></a>

### `get_target_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_version() -> int:
```

获取本次读取完成迁移后的数据版本。

返回：迁移后的数据版本；未取得版本时为 0。

<a id="member-gfstorageownedreadreceipt-methods-was_migrated"></a>

### `was_migrated`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func was_migrated() -> bool:
```

检查本次读取是否完成过数据迁移。

返回：已执行数据迁移时返回 true。

<a id="member-gfstorageownedreadreceipt-methods-was_integrity_checked"></a>

### `was_integrity_checked`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func was_integrity_checked() -> bool:
```

检查本次读取是否包含完整性检查结果。

返回：完整性状态不是 NOT_CHECKED 时返回 true。

<a id="member-gfstorageownedreadreceipt-methods-is_integrity_ok"></a>

### `is_integrity_ok`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_integrity_ok() -> bool:
```

检查本次读取的完整性校验是否明确通过。

返回：完整性状态为 VALID 时返回 true；未检查不视为已通过。

<a id="member-gfstorageownedreadreceipt-methods-get_committed_revision"></a>

### `get_committed_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_committed_revision() -> GFStorageRevisionResult:
```

获取与本次实际读取配对的不可变 committed revision 结果。 不会重新查询当前磁盘状态；revision 仅支持相等比较，不表示时间或内容完整性。

返回：本次捕获的 revision 状态；未捕获时为 null。

<a id="member-gfstorageownedreadreceipt-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

创建只包含稳定诊断白名单的独立字典。

返回：不包含载荷、任意 metadata、物理路径或领取权限的诊断字典。

结构：

- `return`: 精确 Dictionary，包含 request_id: int、consumer_id: int、file_name: String、status: int (GFStorageAsyncCallerResult.Status)、end_kind: int (GFStorageAsyncCallerResult.EndKind)、error_code: int (Error)、failure_kind: int (FailureKind)、read_failure_kind: int (GFStorageReadResult.FailureKind)、source_version: int、target_version: int、migrated: bool、integrity_checked: bool、integrity_ok: bool、committed_revision: Dictionary（未捕获时为空，否则含 status: int、error_code: int、revision: String）。
