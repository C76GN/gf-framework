# GFStorageCatalogResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_catalog_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次 Storage logical catalog 查询的不可变结果。 完整性只相对于发起查询时的 directory、extension、recursive 与 logical depth 范围。 成功但不完整表示 max_file_count 实际截断结果；失败不携带部分文件。 文件存在不代表 payload 已通过解码或完整性校验，也不提供跨 writer 快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FailureKind`](#member-gfstoragecatalogresult-enums-failurekind) | `enum FailureKind` |
| 方法 | [`is_successful`](#member-gfstoragecatalogresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstoragecatalogresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_failure_kind`](#member-gfstoragecatalogresult-methods-get_failure_kind) | `func get_failure_kind() -> FailureKind:` |
| 方法 | [`is_complete`](#member-gfstoragecatalogresult-methods-is_complete) | `func is_complete() -> bool:` |
| 方法 | [`get_files`](#member-gfstoragecatalogresult-methods-get_files) | `func get_files() -> PackedStringArray:` |
| 方法 | [`to_dict`](#member-gfstoragecatalogresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstoragecatalogresult-enums-failurekind"></a>

### `FailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureKind {
	## 查询成功，可能受结果数量上限截断。
	NONE,
	## logical selector 或 options 不满足请求契约。
	INVALID_REQUEST,
	## Utility 已关闭准入，或 drain 期间生命周期与 helper 已更换。
	UNAVAILABLE,
	## drain 后仍有本 Utility 的异步工作或文件锁。
	BUSY,
	## Storage layout 准备或首次恢复失败。
	PREPARATION_FAILED,
	## drain 后的全 catalog 事务恢复失败，包括无法验证恢复所需的 catalog。
	RECOVERY_FAILED,
	## 恢复后的 catalog 枚举或结果验证失败。
	CATALOG_FAILED,
}
```

查询失败的阶段分类；具体底层原因由 Error 码补充。

## 方法

<a id="member-gfstoragecatalogresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查本次查询是否成功完成；结果数量受限仍属于成功。

返回：已配置且 Error 为 OK 时返回 true。

<a id="member-gfstoragecatalogresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取本次查询的 Error 码。

返回：成功为 OK；未配置实例为 FAILED。

<a id="member-gfstoragecatalogresult-methods-get_failure_kind"></a>

### `get_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_kind() -> FailureKind:
```

获取失败阶段；它不替代底层 Error，也不证明损坏的具体物理成员。

返回：成功为 FailureKind.NONE。

<a id="member-gfstoragecatalogresult-methods-is_complete"></a>

### `is_complete`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_complete() -> bool:
```

检查本次 selector 范围内的 committed logical identity 是否已全部返回。 成功但 false 只表示 max_file_count 实际省略条目。深度、递归和扩展名是查询范围， 范围之外的文件不影响此值。不得用有限范围的 true 推断整个 root 中的文件已删除。

返回：成功且未截断时为 true；失败或未配置时为 false。

<a id="member-gfstoragecatalogresult-methods-get_files"></a>

### `get_files`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_files() -> PackedStringArray:
```

获取按 logical identity 排序的文件副本。

返回：无重复 logical identity 的隔离数组；失败为空。

<a id="member-gfstoragecatalogresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

创建只包含查询终态与 logical files 的隔离字典。

返回：不包含物理路径、payload 或 revision 的查询结果。

结构：

- `return`: Dictionary，精确包含 ok: bool、error_code: int (Error)、failure_kind: int (FailureKind)、complete: bool 和 files: PackedStringArray；files 是隔离副本，完整性相对于原查询 selector。
