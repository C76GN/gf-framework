# GFAsyncCompletion

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_async_completion.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

一次性异步完成源。 用于把回调、Signal 或项目侧异步流程归一为 succeeded / failed / cancelled 终态。 状态访问、终态提交和取消 token 绑定都只允许在主线程执行；后台生产者应先把 纯数据投递到框架主线程调度边界。它只保存结果状态，不调度任务，也不强制规定 调用方如何重试或回滚。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfasynccompletion-signals-completed) | `signal completed(completion: GFAsyncCompletion)` |
| 信号 | [`succeeded`](#member-gfasynccompletion-signals-succeeded) | `signal succeeded(result: Variant, metadata: Dictionary)` |
| 信号 | [`failed`](#member-gfasynccompletion-signals-failed) | `signal failed(error: String, metadata: Dictionary)` |
| 信号 | [`cancelled`](#member-gfasynccompletion-signals-cancelled) | `signal cancelled(reason: StringName, metadata: Dictionary)` |
| 枚举 | [`Status`](#member-gfasynccompletion-enums-status) | `enum Status` |
| 方法 | [`succeed`](#member-gfasynccompletion-methods-succeed) | `func succeed(result: Variant = null, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`fail`](#member-gfasynccompletion-methods-fail) | `func fail(error: String = "", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`cancel`](#member-gfasynccompletion-methods-cancel) | `func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}, result: Variant = null) -> bool:` |
| 方法 | [`bind_cancel_token`](#member-gfasynccompletion-methods-bind_cancel_token) | `func bind_cancel_token(token: GFCancellationToken) -> bool:` |
| 方法 | [`is_pending`](#member-gfasynccompletion-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfasynccompletion-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfasynccompletion-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`is_failed`](#member-gfasynccompletion-methods-is_failed) | `func is_failed() -> bool:` |
| 方法 | [`is_cancelled`](#member-gfasynccompletion-methods-is_cancelled) | `func is_cancelled() -> bool:` |
| 方法 | [`get_status`](#member-gfasynccompletion-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_result`](#member-gfasynccompletion-methods-get_result) | `func get_result() -> Variant:` |
| 方法 | [`get_error`](#member-gfasynccompletion-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_cancel_reason`](#member-gfasynccompletion-methods-get_cancel_reason) | `func get_cancel_reason() -> StringName:` |
| 方法 | [`get_metadata`](#member-gfasynccompletion-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfasynccompletion-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasynccompletion-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal completed(completion: GFAsyncCompletion)
```

完成源进入任意终态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `completion` | 当前完成源。 |

<a id="member-gfasynccompletion-signals-succeeded"></a>

### `succeeded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal succeeded(result: Variant, metadata: Dictionary)
```

完成源成功时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 成功结果。 |
| `metadata` | 终态元数据。 |

结构：

- `result`: Variant，调用方定义的成功结果。
- `metadata`: Dictionary，调用方定义的终态元数据。

<a id="member-gfasynccompletion-signals-failed"></a>

### `failed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal failed(error: String, metadata: Dictionary)
```

完成源失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 失败说明。 |
| `metadata` | 终态元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的终态元数据。

<a id="member-gfasynccompletion-signals-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal cancelled(reason: StringName, metadata: Dictionary)
```

完成源取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 终态元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的终态元数据。

## 枚举

<a id="member-gfasynccompletion-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum Status {
	## 等待完成。
	PENDING,
	## 已成功完成。
	SUCCEEDED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
	## 当前调用线程无权读取状态。
	INVALID,
}
```

完成源状态。

## 方法

<a id="member-gfasynccompletion-methods-succeed"></a>

### `succeed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func succeed(result: Variant = null, metadata: Dictionary = {}) -> bool:
```

标记成功完成。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 成功结果。 |
| `metadata` | 终态元数据。 |

返回：主线程首次进入终态时返回 true；非主线程或已有终态时返回 false。

结构：

- `result`: Variant，调用方定义的成功结果。
- `metadata`: Dictionary，调用方定义的终态元数据。

<a id="member-gfasynccompletion-methods-fail"></a>

### `fail`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func fail(error: String = "", metadata: Dictionary = {}) -> bool:
```

标记失败完成。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 失败说明。 |
| `metadata` | 终态元数据。 |

返回：主线程首次进入终态时返回 true；非主线程或已有终态时返回 false。

结构：

- `metadata`: Dictionary，调用方定义的终态元数据。

<a id="member-gfasynccompletion-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}, result: Variant = null) -> bool:
```

标记取消完成。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 终态元数据。 |
| `result` | 可选取消结果。 |

返回：主线程首次进入终态时返回 true；非主线程或已有终态时返回 false。

结构：

- `metadata`: Dictionary，调用方定义的终态元数据。
- `result`: Variant，调用方定义的取消结果。

<a id="member-gfasynccompletion-methods-bind_cancel_token"></a>

### `bind_cancel_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func bind_cancel_token(token: GFCancellationToken) -> bool:
```

绑定取消 token；token 取消时完成源进入 cancelled 终态。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 取消 token。 |

返回：主线程成功绑定或 token 已经触发取消时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_pending() -> bool:
```

当前是否仍在等待。

返回：主线程读取到等待状态时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_completed() -> bool:
```

当前是否已经进入任意终态。

返回：主线程读取到任意终态时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_successful() -> bool:
```

当前是否成功。

返回：主线程读取到成功终态时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-is_failed"></a>

### `is_failed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_failed() -> bool:
```

当前是否失败。

返回：主线程读取到失败终态时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_cancelled() -> bool:
```

当前是否取消。

返回：主线程读取到取消终态时返回 true；非主线程返回 false。

<a id="member-gfasynccompletion-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_status() -> Status:
```

获取当前状态。

返回：主线程返回当前状态；非主线程返回 Status.INVALID。

<a id="member-gfasynccompletion-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_result() -> Variant:
```

获取成功结果。

返回：主线程返回成功结果；未成功或非主线程时为 null。

结构：

- `return`: Variant，调用方定义的成功结果。

<a id="member-gfasynccompletion-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_error() -> String:
```

获取失败说明。

返回：主线程返回失败说明；非主线程返回空字符串。

<a id="member-gfasynccompletion-methods-get_cancel_reason"></a>

### `get_cancel_reason`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_cancel_reason() -> StringName:
```

获取取消原因。

返回：主线程返回取消原因；非主线程返回空 StringName。

<a id="member-gfasynccompletion-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取终态元数据副本。

返回：主线程返回元数据副本；非主线程返回空 Dictionary。

结构：

- `return`: Dictionary，调用方定义的终态元数据。

<a id="member-gfasynccompletion-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取完成源状态快照。

返回：主线程返回完整状态快照；非主线程只返回 Status.INVALID 标记。

结构：

- `return`: Dictionary，主线程包含 status、status_name、completed、successful、failed、cancelled、result、error、cancel_reason、metadata、created_msec、completed_msec 和 duration_msec；非主线程只包含 status 和 status_name。
