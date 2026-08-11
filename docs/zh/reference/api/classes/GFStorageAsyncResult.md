# GFStorageAsyncResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

单次异步存储请求的不可变终态。 结果通过请求 ID 与具体句柄绑定；读取结果保留 `GFStorageReadResult` 的类型化 失败分类；写入结果额外暴露稳定写入失败分类与隔离的 payload 预检报告； 删除结果携带有界、路径无关的 family 成员终态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`WriteFailureKind`](#member-gfstorageasyncresult-enums-writefailurekind) | `enum WriteFailureKind` |
| 方法 | [`get_request_id`](#member-gfstorageasyncresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_operation`](#member-gfstorageasyncresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfstorageasyncresult-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`is_successful`](#member-gfstorageasyncresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstorageasyncresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_read_result`](#member-gfstorageasyncresult-methods-get_read_result) | `func get_read_result() -> GFStorageReadResult:` |
| 方法 | [`get_delete_result`](#member-gfstorageasyncresult-methods-get_delete_result) | `func get_delete_result() -> GFStorageDeleteResult:` |
| 方法 | [`get_write_failure_kind`](#member-gfstorageasyncresult-methods-get_write_failure_kind) | `func get_write_failure_kind() -> WriteFailureKind:` |
| 方法 | [`get_write_validation_report`](#member-gfstorageasyncresult-methods-get_write_validation_report) | `func get_write_validation_report() -> Dictionary:` |
| 方法 | [`duplicate_result`](#member-gfstorageasyncresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageAsyncResult:` |
| 方法 | [`to_dict`](#member-gfstorageasyncresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstorageasyncresult-enums-writefailurekind"></a>

### `WriteFailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum WriteFailureKind {
	## 写入成功，或当前结果不是写入请求。
	NONE,
	## 文件名、transfer 状态或冻结绑定无效。
	INVALID_REQUEST,
	## payload 不是 Storage worker 可安全处理的纯 Variant 图。
	PAYLOAD_INVALID,
	## worker 编码未能生成有效 bytes。
	ENCODE_FAILED,
	## worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility dispose 等生命周期边界使任务不可执行。
	UNAVAILABLE,
	## 目录、临时文件或事务提交 I/O 失败。
	IO_FAILED,
}
```

异步写入失败的稳定分类。

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

返回：已通过路径校验的请求返回规范相对文件名；校验前被拒绝时返回空字符串。

<a id="member-gfstorageasyncresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功。

返回：当前请求的类型化领域结果成功时返回 true。

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

返回：load 请求的结果；save/delete 请求返回 null。

<a id="member-gfstorageasyncresult-methods-get_delete_result"></a>

### `get_delete_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_delete_result() -> GFStorageDeleteResult:
```

获取删除结果副本。

返回：delete 请求的结果；save/load 请求返回 null。

<a id="member-gfstorageasyncresult-methods-get_write_failure_kind"></a>

### `get_write_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_write_failure_kind() -> WriteFailureKind:
```

获取异步写入失败的稳定分类。

返回：`WriteFailureKind` 枚举值；成功或 load/delete 请求为 NONE。

<a id="member-gfstorageasyncresult-methods-get_write_validation_report"></a>

### `get_write_validation_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_write_validation_report() -> Dictionary:
```

获取 worker payload 预检报告副本。

返回：包含 ok、failure_kind、failure_path、path_segments、variant_type、visited_values 和 visited_bytes 的隔离字典；未执行预检时为空。

结构：

- `return`: Dictionary with ok, failure_kind, failure_path, path_segments, variant_type, variant_type_name, visited_values, and visited_bytes fields; path segments contain only structural indexes, never payload keys, values, or correlatable key digests.

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

返回：包含请求身份、终态、领域结果和写入诊断的字典。

结构：

- `return`: Dictionary with request_id, operation, file_name, ok, error_code, read_result, write_failure_kind, write_validation_report, and delete_result fields.
