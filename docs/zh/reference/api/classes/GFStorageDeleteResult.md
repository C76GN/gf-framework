# GFStorageDeleteResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_delete_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次异步 Storage family 删除的不可变终态。 结果只公开有界成员计数与失败成员分类，不暴露 Storage root、family path 或 私有 sidecar 文件名。实例只能由 Storage 框架内部配置一次。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FailureKind`](#member-gfstoragedeleteresult-enums-failurekind) | `enum FailureKind` |
| 枚举 | [`FamilyMember`](#member-gfstoragedeleteresult-enums-familymember) | `enum FamilyMember` |
| 方法 | [`is_successful`](#member-gfstoragedeleteresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstoragedeleteresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_failure_kind`](#member-gfstoragedeleteresult-methods-get_failure_kind) | `func get_failure_kind() -> FailureKind:` |
| 方法 | [`get_existing_member_count`](#member-gfstoragedeleteresult-methods-get_existing_member_count) | `func get_existing_member_count() -> int:` |
| 方法 | [`get_removed_member_count`](#member-gfstoragedeleteresult-methods-get_removed_member_count) | `func get_removed_member_count() -> int:` |
| 方法 | [`get_remaining_member_count`](#member-gfstoragedeleteresult-methods-get_remaining_member_count) | `func get_remaining_member_count() -> int:` |
| 方法 | [`get_failed_member`](#member-gfstoragedeleteresult-methods-get_failed_member) | `func get_failed_member() -> FamilyMember:` |
| 方法 | [`duplicate_result`](#member-gfstoragedeleteresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageDeleteResult:` |
| 方法 | [`to_dict`](#member-gfstoragedeleteresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstoragedeleteresult-enums-failurekind"></a>

### `FailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureKind {
	## 删除成功。
	NONE,
	## 请求参数或 logical identity 无效。
	INVALID_REQUEST,
	## 精确 logical family 未 claim，或已 claim family 不存在任何可变成员。
	NOT_FOUND,
	## family metadata、owner 或事务证据发生冲突。
	CONFLICT,
	## 删除 worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility 生命周期边界拒绝或终止了尚未执行的请求。
	UNAVAILABLE,
	## family 成员删除或底层文件 I/O 失败；无法解析 worker 终态时也使用此回退分类。
	IO_FAILED,
}
```

删除失败的稳定分类。

<a id="member-gfstoragedeleteresult-enums-familymember"></a>

### `FamilyMember`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FamilyMember {
	## 没有失败成员。
	NONE,
	## layout、catalog、owner 或 family metadata。
	FAMILY_METADATA,
	## 已提交 payload 的备份成员。
	BACKUP,
	## prepare、commit 或 pending 事务证据。
	TRANSACTION_EVIDENCE,
	## 尚未提交的 candidate payload。
	CANDIDATE,
	## Resource 保存使用的 staging 成员。
	RESOURCE_STAGE,
	## committed final payload。
	FINAL,
}
```

删除 family 时可报告的有界成员分类。

## 方法

<a id="member-gfstoragedeleteresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查删除是否成功。

返回：已配置为完整成功终态时返回 true。

<a id="member-gfstoragedeleteresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取删除 Error 码。

返回：成功时为 OK；未配置实例返回 FAILED。

<a id="member-gfstoragedeleteresult-methods-get_failure_kind"></a>

### `get_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_kind() -> FailureKind:
```

获取删除失败分类。

返回：`FailureKind` 枚举值。

<a id="member-gfstoragedeleteresult-methods-get_existing_member_count"></a>

### `get_existing_member_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_existing_member_count() -> int:
```

获取删除开始时存在的可变 family 成员数量。

返回：0 到 8 的成员数量。

<a id="member-gfstoragedeleteresult-methods-get_removed_member_count"></a>

### `get_removed_member_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_removed_member_count() -> int:
```

获取本次请求已删除的 family 成员数量。

返回：0 到 8 的成员数量。

<a id="member-gfstoragedeleteresult-methods-get_remaining_member_count"></a>

### `get_remaining_member_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_remaining_member_count() -> int:
```

获取本次请求终态仍存在的 family 成员数量。

返回：0 到 8 的成员数量。

<a id="member-gfstoragedeleteresult-methods-get_failed_member"></a>

### `get_failed_member`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_member() -> FamilyMember:
```

获取阻止删除继续执行的成员分类。

返回：没有失败成员时返回 `FamilyMember.NONE`；无法解析 worker 结果时返回 `FAMILY_METADATA`。

<a id="member-gfstoragedeleteresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFStorageDeleteResult:
```

创建隔离结果副本。

返回：新结果对象；未配置实例返回新的未配置对象。

<a id="member-gfstoragedeleteresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不含物理路径的可报告字典。

返回：删除终态及有界 family 成员计数。

结构：

- `return`: Dictionary with exactly ok: bool, error_code: int (Error), failure_kind: int (FailureKind), existing_member_count: int, removed_member_count: int, remaining_member_count: int, and failed_member: int (FamilyMember).
