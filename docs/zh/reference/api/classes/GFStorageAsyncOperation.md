# GFStorageAsyncOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`10.0.0`

单次异步存储请求句柄。 句柄由 `GFStorageUtility` 分配唯一请求 ID，并且只接受一个终态。调用方应先 检查 `is_completed()`，再决定是否等待 `completed` 信号。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfstorageasyncoperation-signals-completed) | `signal completed(result: GFStorageAsyncResult)` |
| 常量 | [`OPERATION_SAVE`](#member-gfstorageasyncoperation-constants-operation_save) | `const OPERATION_SAVE: StringName = &"save"` |
| 常量 | [`OPERATION_LOAD`](#member-gfstorageasyncoperation-constants-operation_load) | `const OPERATION_LOAD: StringName = &"load"` |
| 常量 | [`OPERATION_DELETE`](#member-gfstorageasyncoperation-constants-operation_delete) | `const OPERATION_DELETE: StringName = &"delete"` |
| 方法 | [`get_request_id`](#member-gfstorageasyncoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_operation`](#member-gfstorageasyncoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfstorageasyncoperation-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`is_pending`](#member-gfstorageasyncoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfstorageasyncoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfstorageasyncoperation-methods-get_result) | `func get_result() -> GFStorageAsyncResult:` |
| 方法 | [`get_payload_transfer`](#member-gfstorageasyncoperation-methods-get_payload_transfer) | `func get_payload_transfer() -> GFStoragePayloadTransfer:` |
| 方法 | [`reclaim_failed_payload`](#member-gfstorageasyncoperation-methods-reclaim_failed_payload) | `func reclaim_failed_payload() -> GFStoragePayloadTransfer:` |

## 信号

<a id="member-gfstorageasyncoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal completed(result: GFStorageAsyncResult)
```

请求进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 与当前请求 ID 匹配的隔离结果。 |

## 常量

<a id="member-gfstorageasyncoperation-constants-operation_save"></a>

### `OPERATION_SAVE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OPERATION_SAVE: StringName = &"save"
```

异步写入请求。

<a id="member-gfstorageasyncoperation-constants-operation_load"></a>

### `OPERATION_LOAD`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OPERATION_LOAD: StringName = &"load"
```

异步读取请求。

<a id="member-gfstorageasyncoperation-constants-operation_delete"></a>

### `OPERATION_DELETE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const OPERATION_DELETE: StringName = &"delete"
```

异步删除请求。

## 方法

<a id="member-gfstorageasyncoperation-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一请求 ID。

返回：大于零的请求 ID。

<a id="member-gfstorageasyncoperation-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_operation() -> StringName:
```

获取请求类型。

返回：`OPERATION_SAVE`、`OPERATION_LOAD` 或 `OPERATION_DELETE`。

<a id="member-gfstorageasyncoperation-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_file_name() -> String:
```

获取规范化存储文件名。

返回：已通过路径校验的请求返回规范相对文件名；校验前被拒绝时返回空字符串。

<a id="member-gfstorageasyncoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_pending() -> bool:
```

检查请求是否等待终态。

返回：已配置且未完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_completed() -> bool:
```

检查请求是否已有终态。

返回：已完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_result() -> GFStorageAsyncResult:
```

获取终态结果副本。

返回：已完成结果；等待中返回 null。

<a id="member-gfstorageasyncoperation-methods-get_payload_transfer"></a>

### `get_payload_transfer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_payload_transfer() -> GFStoragePayloadTransfer:
```

获取当前请求关联的 opaque payload transfer。 该句柄不公开 payload，可在当前 attempt 仍运行时交给同一 Storage 和规范文件 发起 timeout retry。调用方完成整个重试 generation 后必须显式 `release()`。

返回：等待中的 transfer-backed save 请求返回句柄；终态及普通 save/load/delete 请求返回 null。

<a id="member-gfstorageasyncoperation-methods-reclaim_failed_payload"></a>

### `reclaim_failed_payload`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func reclaim_failed_payload() -> GFStoragePayloadTransfer:
```

一次性取回失败请求关联的 opaque payload transfer。 仅请求进入失败终态且 attempt lease 已结束后可取回。返回值仍不公开 payload， 但可直接用于同一冻结 Storage、文件名和 codec options 的重试。

返回：首次取回失败 transfer 时返回原句柄；其他情况返回 null。
