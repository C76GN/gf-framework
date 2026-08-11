# GFStorageAsyncOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`10.0.0`

单次异步存储请求句柄。 句柄同时表达单个 consumer 的 caller 终态与共享物理请求终态。既有 `completed/is_completed/get_result` 始终表示物理终态；caller 可通过独立查询和 `caller_completed` 提前结束观察，而不会伪造磁盘工作已经停止。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfstorageasyncoperation-signals-completed) | `signal completed(result: GFStorageAsyncResult)` |
| 信号 | [`caller_completed`](#member-gfstorageasyncoperation-signals-caller_completed) | `signal caller_completed(result: GFStorageAsyncCallerResult)` |
| 常量 | [`OPERATION_SAVE`](#member-gfstorageasyncoperation-constants-operation_save) | `const OPERATION_SAVE: StringName = &"save"` |
| 常量 | [`OPERATION_LOAD`](#member-gfstorageasyncoperation-constants-operation_load) | `const OPERATION_LOAD: StringName = &"load"` |
| 常量 | [`OPERATION_DELETE`](#member-gfstorageasyncoperation-constants-operation_delete) | `const OPERATION_DELETE: StringName = &"delete"` |
| 方法 | [`get_request_id`](#member-gfstorageasyncoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_consumer_id`](#member-gfstorageasyncoperation-methods-get_consumer_id) | `func get_consumer_id() -> int:` |
| 方法 | [`get_operation`](#member-gfstorageasyncoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfstorageasyncoperation-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`is_pending`](#member-gfstorageasyncoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfstorageasyncoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfstorageasyncoperation-methods-get_result) | `func get_result() -> GFStorageAsyncResult:` |
| 方法 | [`is_caller_pending`](#member-gfstorageasyncoperation-methods-is_caller_pending) | `func is_caller_pending() -> bool:` |
| 方法 | [`is_caller_completed`](#member-gfstorageasyncoperation-methods-is_caller_completed) | `func is_caller_completed() -> bool:` |
| 方法 | [`get_caller_result`](#member-gfstorageasyncoperation-methods-get_caller_result) | `func get_caller_result() -> GFStorageAsyncCallerResult:` |
| 方法 | [`cancel_observation`](#member-gfstorageasyncoperation-methods-cancel_observation) | `func cancel_observation(reason: StringName = &"cancelled") -> bool:` |
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

物理请求进入终态时发出一次；caller 提前结束观察不会触发该信号。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 与当前请求 ID 匹配的隔离结果。 |

<a id="member-gfstorageasyncoperation-signals-caller_completed"></a>

### `caller_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal caller_completed(result: GFStorageAsyncCallerResult)
```

当前 consumer 进入 caller 终态时发出一次。 owner 已释放时框架可抑制该信号；终态仍可通过 `get_caller_result()` 查询。该信号 不代表物理工作已结束。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 与当前 consumer ID 匹配的隔离 caller 结果。 |

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

<a id="member-gfstorageasyncoperation-methods-get_consumer_id"></a>

### `get_consumer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_consumer_id() -> int:
```

获取当前 consumer 的 Utility 内唯一 ID。

返回：大于零的 consumer ID；尚未配置时返回 0。

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

检查物理请求是否等待终态。

返回：已配置且未完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_completed() -> bool:
```

检查物理请求是否已有终态。

返回：已完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_result() -> GFStorageAsyncResult:
```

获取物理终态结果副本。

返回：已完成结果；等待中返回 null。

<a id="member-gfstorageasyncoperation-methods-is_caller_pending"></a>

### `is_caller_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_caller_pending() -> bool:
```

检查当前 consumer 是否仍等待 caller 终态。

返回：已配置且 caller 尚未完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-is_caller_completed"></a>

### `is_caller_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_caller_completed() -> bool:
```

检查当前 consumer 是否已有 caller 终态。

返回：caller 已完成时返回 true。

<a id="member-gfstorageasyncoperation-methods-get_caller_result"></a>

### `get_caller_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_caller_result() -> GFStorageAsyncCallerResult:
```

获取 caller 终态结果副本。

返回：caller 已完成时返回隔离结果；等待中返回 null。

<a id="member-gfstorageasyncoperation-methods-cancel_observation"></a>

### `cancel_observation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_observation(reason: StringName = &"cancelled") -> bool:
```

显式结束当前 consumer 对物理请求的观察。 返回 true 只表示 caller 终态已被 Utility 线性化，不保证物理 worker 已取消。 save/delete 已接纳时可能进入 `OUTCOME_UNKNOWN`，物理终态仍通过 `completed` 到达。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 最长保留 128 字符的稳定原因；空值规范化为 \`cancelled\`。 |

返回：本次调用首次结束 caller 观察时返回 true。

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
