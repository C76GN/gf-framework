# GFThumbnailRenderTask

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_thumbnail_render_task.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

一次缩略图渲染任务句柄。 任务持有请求、运行状态、取消 token 和完成源；GFThumbnailRenderer 负责串行执行任务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfthumbnailrendertask-signals-completed) | `signal completed(task: GFThumbnailRenderTask)` |
| 信号 | [`succeeded`](#member-gfthumbnailrendertask-signals-succeeded) | `signal succeeded(task: GFThumbnailRenderTask, result: Variant)` |
| 信号 | [`failed`](#member-gfthumbnailrendertask-signals-failed) | `signal failed(task: GFThumbnailRenderTask, error: String)` |
| 信号 | [`cancelled`](#member-gfthumbnailrendertask-signals-cancelled) | `signal cancelled(task: GFThumbnailRenderTask, reason: StringName)` |
| 枚举 | [`State`](#member-gfthumbnailrendertask-enums-state) | `enum State` |
| 方法 | [`_init`](#member-gfthumbnailrendertask-methods-_init) | `func _init(request: GFThumbnailRenderRequest = null, task_id: int = 0) -> void:` |
| 方法 | [`cancel`](#member-gfthumbnailrendertask-methods-cancel) | `func cancel(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`wait_completed`](#member-gfthumbnailrendertask-methods-wait_completed) | `func wait_completed() -> Variant:` |
| 方法 | [`get_task_id`](#member-gfthumbnailrendertask-methods-get_task_id) | `func get_task_id() -> int:` |
| 方法 | [`get_request`](#member-gfthumbnailrendertask-methods-get_request) | `func get_request() -> GFThumbnailRenderRequest:` |
| 方法 | [`get_state`](#member-gfthumbnailrendertask-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_pending`](#member-gfthumbnailrendertask-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_running`](#member-gfthumbnailrendertask-methods-is_running) | `func is_running() -> bool:` |
| 方法 | [`is_finished`](#member-gfthumbnailrendertask-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`is_succeeded`](#member-gfthumbnailrendertask-methods-is_succeeded) | `func is_succeeded() -> bool:` |
| 方法 | [`is_failed`](#member-gfthumbnailrendertask-methods-is_failed) | `func is_failed() -> bool:` |
| 方法 | [`is_cancelled`](#member-gfthumbnailrendertask-methods-is_cancelled) | `func is_cancelled() -> bool:` |
| 方法 | [`is_cancel_requested`](#member-gfthumbnailrendertask-methods-is_cancel_requested) | `func is_cancel_requested() -> bool:` |
| 方法 | [`get_result`](#member-gfthumbnailrendertask-methods-get_result) | `func get_result() -> Variant:` |
| 方法 | [`get_error`](#member-gfthumbnailrendertask-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_cancel_reason`](#member-gfthumbnailrendertask-methods-get_cancel_reason) | `func get_cancel_reason() -> StringName:` |
| 方法 | [`get_cancel_token`](#member-gfthumbnailrendertask-methods-get_cancel_token) | `func get_cancel_token() -> GFCancellationToken:` |
| 方法 | [`get_completion`](#member-gfthumbnailrendertask-methods-get_completion) | `func get_completion() -> GFAsyncCompletion:` |

## 信号

<a id="member-gfthumbnailrendertask-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal completed(task: GFThumbnailRenderTask)
```

任务进入任意终态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 当前任务。 |

<a id="member-gfthumbnailrendertask-signals-succeeded"></a>

### `succeeded`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal succeeded(task: GFThumbnailRenderTask, result: Variant)
```

任务成功完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 当前任务。 |
| `result` | 成功结果。 |

结构：

- `result`: Variant，Image、ImageTexture 或 MeshLibrary 预览计划 Dictionary。

<a id="member-gfthumbnailrendertask-signals-failed"></a>

### `failed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal failed(task: GFThumbnailRenderTask, error: String)
```

任务失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 当前任务。 |
| `error` | 失败说明。 |

<a id="member-gfthumbnailrendertask-signals-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal cancelled(task: GFThumbnailRenderTask, reason: StringName)
```

任务取消完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 当前任务。 |
| `reason` | 取消原因。 |

## 枚举

<a id="member-gfthumbnailrendertask-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum State {
	## 等待执行。
	PENDING,
	## 正在执行。
	RUNNING,
	## 已成功完成。
	SUCCEEDED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}
```

缩略图渲染任务状态。

## 方法

<a id="member-gfthumbnailrendertask-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func _init(request: GFThumbnailRenderRequest = null, task_id: int = 0) -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 要执行的缩略图渲染请求。 |
| `task_id` | 可选任务 ID。 |

<a id="member-gfthumbnailrendertask-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled") -> bool:
```

请求取消任务。 等待中的任务会立即进入取消终态；正在执行的任务会在下一个渲染检查点取消。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：本次调用是否发出了新的取消请求。

<a id="member-gfthumbnailrendertask-methods-wait_completed"></a>

### `wait_completed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func wait_completed() -> Variant:
```

等待任务完成并返回最终结果。

返回：任务结果；失败时通常为 null，取消的 MeshLibrary 计划任务可返回部分计划。

结构：

- `return`: Variant，Image、ImageTexture、MeshLibrary 预览计划 Dictionary 或 null。

<a id="member-gfthumbnailrendertask-methods-get_task_id"></a>

### `get_task_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_task_id() -> int:
```

返回任务 ID。

返回：任务 ID。

<a id="member-gfthumbnailrendertask-methods-get_request"></a>

### `get_request`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_request() -> GFThumbnailRenderRequest:
```

返回任务请求。

返回：任务请求。

<a id="member-gfthumbnailrendertask-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_state() -> State:
```

返回任务状态。

返回：当前任务状态。

<a id="member-gfthumbnailrendertask-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_pending() -> bool:
```

返回是否仍在等待执行。

返回：等待执行时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_running"></a>

### `is_running`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_running() -> bool:
```

返回是否正在执行。

返回：正在执行时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_finished() -> bool:
```

返回是否已经进入任意终态。

返回：已完成、失败或取消时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_succeeded"></a>

### `is_succeeded`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_succeeded() -> bool:
```

返回是否成功完成。

返回：成功完成时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_failed"></a>

### `is_failed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_failed() -> bool:
```

返回是否失败。

返回：失败时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_cancelled() -> bool:
```

返回是否取消完成。

返回：取消完成时返回 true。

<a id="member-gfthumbnailrendertask-methods-is_cancel_requested"></a>

### `is_cancel_requested`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_cancel_requested() -> bool:
```

返回是否已经请求取消。

返回：已请求取消但可能尚未完成时返回 true。

<a id="member-gfthumbnailrendertask-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_result() -> Variant:
```

返回任务结果。

返回：任务结果。

结构：

- `return`: Variant，Image、ImageTexture、MeshLibrary 预览计划 Dictionary 或 null。

<a id="member-gfthumbnailrendertask-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_error() -> String:
```

返回失败说明。

返回：失败说明；非失败状态返回空字符串。

<a id="member-gfthumbnailrendertask-methods-get_cancel_reason"></a>

### `get_cancel_reason`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cancel_reason() -> StringName:
```

返回取消原因。

返回：取消原因；未取消时返回空 StringName。

<a id="member-gfthumbnailrendertask-methods-get_cancel_token"></a>

### `get_cancel_token`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cancel_token() -> GFCancellationToken:
```

返回任务取消 token。

返回：当前任务的只读取消 token。

<a id="member-gfthumbnailrendertask-methods-get_completion"></a>

### `get_completion`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_completion() -> GFAsyncCompletion:
```

返回任务完成源。

返回：当前任务的完成源。
