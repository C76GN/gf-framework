# GFStorageResourceReadResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_resource_read_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

Resource 及其实际读取来源 revision 的不可变配对结果。 结果保存原 Resource 对象引用，不复制或冻结 Resource 的运行时属性。 committed revision 描述读取时的存储来源，不随 Resource 后续修改而变化。 通过工厂创建结果；失败不保留 Resource 或 committed revision。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`success`](#member-gfstorageresourcereadresult-methods-success) | `static func success( resource: Resource, revision: GFStorageRevisionResult ) -> GFStorageResourceReadResult:` |
| 方法 | [`failure`](#member-gfstorageresourcereadresult-methods-failure) | `static func failure(error: Error) -> GFStorageResourceReadResult:` |
| 方法 | [`is_successful`](#member-gfstorageresourcereadresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstorageresourcereadresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_resource`](#member-gfstorageresourcereadresult-methods-get_resource) | `func get_resource() -> Resource:` |
| 方法 | [`get_committed_revision`](#member-gfstorageresourcereadresult-methods-get_committed_revision) | `func get_committed_revision() -> GFStorageRevisionResult:` |

## 方法

<a id="member-gfstorageresourcereadresult-methods-success"></a>

### `success`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func success( resource: Resource, revision: GFStorageRevisionResult ) -> GFStorageResourceReadResult:
```

创建 Resource 与成功 committed revision 的配对结果。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 读取到的非 null Resource；保存同一对象引用。 |
| `revision` | 本次读取对应的成功 revision 结果。 |

返回：成功配对；任一参数无效时返回 ERR_INVALID_PARAMETER 且不保留参数引用。

<a id="member-gfstorageresourcereadresult-methods-failure"></a>

### `failure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func failure(error: Error) -> GFStorageResourceReadResult:
```

创建不包含 Resource 或 committed revision 的失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 非 OK 的 Godot Error 码；OK 归一为 ERR_INVALID_PARAMETER。 |

返回：不保留 Resource 或 committed revision 的失败结果。

<a id="member-gfstorageresourcereadresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查是否成功取得 Resource 及其 committed revision。

返回：仅成功结果返回 true。

<a id="member-gfstorageresourcereadresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取读取的 Godot Error 码。

返回：成功时为 OK；失败时为非 OK 错误码。

<a id="member-gfstorageresourcereadresult-methods-get_resource"></a>

### `get_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resource() -> Resource:
```

获取读取到的原 Resource 对象引用。

返回：成功时返回同一 Resource；失败时为 null。调用方修改该对象会被其他持有者观察到。

<a id="member-gfstorageresourcereadresult-methods-get_committed_revision"></a>

### `get_committed_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_committed_revision() -> GFStorageRevisionResult:
```

获取与本次 Resource 读取配对的 committed revision。

返回：成功时返回不可变 revision 结果；失败时为 null。
