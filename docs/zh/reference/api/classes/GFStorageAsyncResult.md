# GFStorageAsyncResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

单次异步存储请求的不可变终态。 结果通过请求 ID 与具体句柄绑定；读取结果保留 `GFStorageReadResult` 的类型化 失败分类，写入结果只暴露稳定 Error 码。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_request_id`](#member-gfstorageasyncresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_operation`](#member-gfstorageasyncresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfstorageasyncresult-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`is_successful`](#member-gfstorageasyncresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstorageasyncresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_read_result`](#member-gfstorageasyncresult-methods-get_read_result) | `func get_read_result() -> GFStorageReadResult:` |
| 方法 | [`duplicate_result`](#member-gfstorageasyncresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageAsyncResult:` |
| 方法 | [`to_dict`](#member-gfstorageasyncresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 方法

<a id="member-gfstorageasyncresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_request_id() -> int:
```

获取 Storage Utility 分配的请求 ID。

返回：大于零的 Utility 内唯一请求 ID。

<a id="member-gfstorageasyncresult-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_operation() -> StringName:
```

获取请求类型。

返回：`GFStorageAsyncOperation.OPERATION_*` 常量之一。

<a id="member-gfstorageasyncresult-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_file_name() -> String:
```

获取规范化存储文件名。

返回：请求实际使用的存储相对文件名或绝对文件名。

<a id="member-gfstorageasyncresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功。

返回：写入错误码为 OK，或读取结果成功时返回 true。

<a id="member-gfstorageasyncresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_error_code() -> Error:
```

获取请求 Error 码。

返回：成功时为 OK。

<a id="member-gfstorageasyncresult-methods-get_read_result"></a>

### `get_read_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_read_result() -> GFStorageReadResult:
```

获取读取结果副本。

返回：load 请求的结果；save 请求返回 null。

<a id="member-gfstorageasyncresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_result() -> GFStorageAsyncResult:
```

创建隔离结果副本。

返回：新结果对象。

<a id="member-gfstorageasyncresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可报告字典。

返回：包含请求身份、终态和读取摘要的字典。

结构：

- `return`: Dictionary with request_id, operation, file_name, ok, error_code, and read_result fields.
