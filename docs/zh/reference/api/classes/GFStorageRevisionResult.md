# GFStorageRevisionResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_revision_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

一次 committed revision 查询的不可变结果。 revision 是只用于相等比较的不透明字符串，不表示时间顺序或内容完整性。 通过工厂创建结果；未使用工厂创建的实例保持 INVALID_REQUEST 失败状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfstoragerevisionresult-enums-status) | `enum Status` |
| 方法 | [`available`](#member-gfstoragerevisionresult-methods-available) | `static func available(revision: String) -> GFStorageRevisionResult:` |
| 方法 | [`failure`](#member-gfstoragerevisionresult-methods-failure) | `static func failure(status: Status, error: Error) -> GFStorageRevisionResult:` |
| 方法 | [`is_successful`](#member-gfstoragerevisionresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstoragerevisionresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_status`](#member-gfstoragerevisionresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_revision`](#member-gfstoragerevisionresult-methods-get_revision) | `func get_revision() -> String:` |
| 方法 | [`to_dict`](#member-gfstoragerevisionresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstoragerevisionresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 已取得成功提交对应的非空 revision。
	AVAILABLE,
	## 目标不存在 committed payload。
	NOT_FOUND,
	## 当前存储布局不支持 committed revision。
	UNSUPPORTED,
	## 查询参数或结果工厂参数无效。
	INVALID_REQUEST,
	## 当前生命周期或存储准入不可用。
	UNAVAILABLE,
	## 同 family 操作或恢复尚未收敛。
	BUSY,
	## 存储身份、提交状态或事务证据损坏。
	CORRUPT,
	## 底层存储 I/O 失败。
	IO_FAILED,
}
```

committed revision 的可用性与失败分类。

## 方法

<a id="member-gfstoragerevisionresult-methods-available"></a>

### `available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func available(revision: String) -> GFStorageRevisionResult:
```

创建包含 committed revision 的成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `revision` | 非空不透明字符串；原样保存，不裁剪或解析。 |

返回：AVAILABLE 结果；空字符串返回 INVALID_REQUEST 与 ERR_INVALID_PARAMETER。

<a id="member-gfstoragerevisionresult-methods-failure"></a>

### `failure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func failure(status: Status, error: Error) -> GFStorageRevisionResult:
```

创建不包含 revision 的失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `status` | 除 AVAILABLE 外的有效 Status。 |
| `error` | 非 OK 的 Godot Error 码。 |

返回：失败结果；无效 status 或 OK 归一为 INVALID_REQUEST 与 ERR_INVALID_PARAMETER。

<a id="member-gfstoragerevisionresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查是否取得可用的 committed revision。

返回：仅 AVAILABLE、OK 与非空 revision 同时成立时返回 true。

<a id="member-gfstoragerevisionresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取查询的 Godot Error 码。

返回：成功时为 OK；失败时为非 OK 错误码。

<a id="member-gfstoragerevisionresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取 revision 的可用性或失败分类。

返回：Status 枚举值。

<a id="member-gfstoragerevisionresult-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_revision() -> String:
```

获取只用于相等比较的 committed revision。

返回：成功时为原始 revision；失败时为空字符串。

<a id="member-gfstoragerevisionresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

创建不含物理路径的独立结果字典。

返回：修改返回字典不会改变当前结果或其他字典副本。

结构：

- `return`: 精确 Dictionary，包含 status: int (Status)、error_code: int (Error)、revision: String 三个字段。
