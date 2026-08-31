# GFStorageAsyncCallerResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_caller_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

单个 Storage consumer 的不可变 caller 终态。 caller 终态与 `GFStorageAsyncOperation.completed` 表示的物理终态彼此独立。已接纳 save/delete/reset 在 caller 提前离开时返回 `OUTCOME_UNKNOWN`，不会把“停止观察”伪装成 磁盘工作已取消；晚到物理结果仍由原 Operation 恰好结算一次。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfstorageasynccallerresult-enums-status) | `enum Status` |
| 枚举 | [`EndKind`](#member-gfstorageasynccallerresult-enums-endkind) | `enum EndKind` |
| 方法 | [`get_consumer_id`](#member-gfstorageasynccallerresult-methods-get_consumer_id) | `func get_consumer_id() -> int:` |
| 方法 | [`get_request_id`](#member-gfstorageasynccallerresult-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_operation`](#member-gfstorageasynccallerresult-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_file_name`](#member-gfstorageasynccallerresult-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`get_status`](#member-gfstorageasynccallerresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_end_kind`](#member-gfstorageasynccallerresult-methods-get_end_kind) | `func get_end_kind() -> EndKind:` |
| 方法 | [`get_reason`](#member-gfstorageasynccallerresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_completed_at_msec`](#member-gfstorageasynccallerresult-methods-get_completed_at_msec) | `func get_completed_at_msec() -> int:` |
| 方法 | [`get_error_code`](#member-gfstorageasynccallerresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`is_successful`](#member-gfstorageasynccallerresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`is_outcome_unknown`](#member-gfstorageasynccallerresult-methods-is_outcome_unknown) | `func is_outcome_unknown() -> bool:` |
| 方法 | [`get_physical_result`](#member-gfstorageasynccallerresult-methods-get_physical_result) | `func get_physical_result() -> GFStorageAsyncResult:` |
| 方法 | [`duplicate_result`](#member-gfstorageasynccallerresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageAsyncCallerResult:` |
| 方法 | [`to_dict`](#member-gfstorageasynccallerresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstorageasynccallerresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Status {
	## caller 获得了同一请求的确定物理终态。
	PHYSICAL_SETTLED,
	## caller 已安全停止观察，且不会声称存在持久化副作用的不确定性。
	CANCELLED,
	## caller 已停止观察，但 save/delete/reset 的持久化结果仍未知。
	OUTCOME_UNKNOWN,
}
```

caller 观察的闭合终态分类。

<a id="member-gfstorageasynccallerresult-enums-endkind"></a>

### `EndKind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum EndKind {
	## 物理工作先结算。
	PHYSICAL_SETTLEMENT,
	## 调用方显式调用 `cancel_observation()`。
	EXPLICIT_CANCEL,
	## 绑定的 `GFCancellationToken` 首次请求取消。
	TOKEN_CANCELLED,
	## 单调 caller deadline 到期。
	DEADLINE_EXPIRED,
	## 弱 owner 已经释放。
	OWNER_RELEASED,
	## Utility dispose 在 worker 接纳前终止了排队请求。
	UTILITY_DISPOSED,
}
```

caller 终态的稳定来源分类。

## 方法

<a id="member-gfstorageasynccallerresult-methods-get_consumer_id"></a>

### `get_consumer_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_consumer_id() -> int:
```

获取当前 consumer 的 Utility 内唯一 ID。

返回：大于零的当前 consumer ID；尚未配置时返回 0。

<a id="member-gfstorageasynccallerresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_request_id() -> int:
```

获取物理请求 ID。

返回：大于零的物理请求 ID；尚未配置时返回 0。

<a id="member-gfstorageasynccallerresult-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_operation() -> StringName:
```

获取请求类型。

返回：`save`、`load`、`delete` 或 `reset`；尚未配置时返回空值。

<a id="member-gfstorageasynccallerresult-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_file_name() -> String:
```

获取 portable logical 文件名。

返回：已验证的 portable logical identity；校验前失败时可能为空。

<a id="member-gfstorageasynccallerresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

获取 caller 终态分类。

返回：当前 caller 终态分类。

<a id="member-gfstorageasynccallerresult-methods-get_end_kind"></a>

### `get_end_kind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_end_kind() -> EndKind:
```

获取 caller 结束来源分类。

返回：当前 caller 终态的稳定来源分类。

<a id="member-gfstorageasynccallerresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reason() -> StringName:
```

获取最长 128 字符的稳定原因。

返回：已规范化且最长 128 字符的稳定原因。

<a id="member-gfstorageasynccallerresult-methods-get_completed_at_msec"></a>

### `get_completed_at_msec`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_completed_at_msec() -> int:
```

获取 caller 终态的单调毫秒时间。

返回：caller 终态写入时的非负单调毫秒值。

<a id="member-gfstorageasynccallerresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error_code() -> Error:
```

获取 caller Error 码。

返回：caller 终态对应的 Godot `Error`。

<a id="member-gfstorageasynccallerresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

返回 caller 是否获得了成功的物理领域结果。

返回：caller 获得成功物理领域结果时返回 true。

<a id="member-gfstorageasynccallerresult-methods-is_outcome_unknown"></a>

### `is_outcome_unknown`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_outcome_unknown() -> bool:
```

返回 caller 是否因潜在持久化副作用进入未知结果。

返回：caller 已离开但 save/delete/reset 物理结果未知时返回 true。

<a id="member-gfstorageasynccallerresult-methods-get_physical_result"></a>

### `get_physical_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_physical_result() -> GFStorageAsyncResult:
```

获取 caller 已知的物理终态副本。

返回：`PHYSICAL_SETTLED` 时返回结果；其他 caller 终态返回 null。

<a id="member-gfstorageasynccallerresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_result() -> GFStorageAsyncCallerResult:
```

创建隔离副本。

返回：当前不可变 caller 终态的隔离副本。

<a id="member-gfstorageasynccallerresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可报告字典。

返回：当前 caller 终态的隔离字典表示。

结构：

- `return`: Exact Dictionary with consumer_id: int, request_id: int, operation: StringName, file_name: String, status: int enum, end_kind: int enum, reason: StringName, completed_at_msec: int, error_code: int, and physical_result: Dictionary fields.
