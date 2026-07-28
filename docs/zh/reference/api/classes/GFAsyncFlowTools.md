# GFAsyncFlowTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_flow_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

小型异步流程辅助。 在现有 GFAsyncCompletion / GFAsyncWaitUtility 之上提供重试、顺序遍历、折叠和 completion 组合。 它不引入 Promise 类型，不调度后台线程，也不规定业务任务模型；调用方只需要 提供 Callable，并接收稳定的结果字典。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_SUCCEEDED`](#member-gfasyncflowtools-constants-status_succeeded) | `const STATUS_SUCCEEDED: StringName = &"succeeded"` |
| 常量 | [`STATUS_FAILED`](#member-gfasyncflowtools-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfasyncflowtools-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`DEFAULT_MAX_COMPLETIONS`](#member-gfasyncflowtools-constants-default_max_completions) | `const DEFAULT_MAX_COMPLETIONS: int = 256` |
| 常量 | [`ABSOLUTE_MAX_COMPLETIONS`](#member-gfasyncflowtools-constants-absolute_max_completions) | `const ABSOLUTE_MAX_COMPLETIONS: int = 4096` |
| 方法 | [`retry_async`](#member-gfasyncflowtools-methods-retry_async) | `static func retry_async(operation: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`each_async`](#member-gfasyncflowtools-methods-each_async) | `static func each_async(items: Array, operation: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`fold_async`](#member-gfasyncflowtools-methods-fold_async) | `static func fold_async(items: Array, reducer: Callable, initial_value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_all_completions_async`](#member-gfasyncflowtools-methods-wait_all_completions_async) | `static func wait_all_completions_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_any_completion_async`](#member-gfasyncflowtools-methods-wait_any_completion_async) | `static func wait_any_completion_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfasyncflowtools-constants-status_succeeded"></a>

### `STATUS_SUCCEEDED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_SUCCEEDED: StringName = &"succeeded"
```

流程成功完成。

<a id="member-gfasyncflowtools-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

流程失败。

<a id="member-gfasyncflowtools-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

流程被取消。

<a id="member-gfasyncflowtools-constants-default_max_completions"></a>

### `DEFAULT_MAX_COMPLETIONS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_COMPLETIONS: int = 256
```

组合等待默认接受的最大 completion 数量。

<a id="member-gfasyncflowtools-constants-absolute_max_completions"></a>

### `ABSOLUTE_MAX_COMPLETIONS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_COMPLETIONS: int = 4096
```

组合等待允许的 completion 绝对数量上限。

## 方法

<a id="member-gfasyncflowtools-methods-retry_async"></a>

### `retry_async`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func retry_async(operation: Callable, options: Dictionary = {}) -> Dictionary:
```

重试执行一个操作。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 要执行的操作。 |
| `options` | 重试选项。 |

返回：流程报告。

结构：

- `options`: Dictionary，可包含 attempts、delay_seconds、tree、cancel_token、operation_options、pass_attempt 和 metadata。
- `return`: Dictionary with ok, status, value, error, attempts, history, metadata, and optional cancel_reason.

<a id="member-gfasyncflowtools-methods-each_async"></a>

### `each_async`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func each_async(items: Array, operation: Callable, options: Dictionary = {}) -> Dictionary:
```

顺序处理数组项。

参数：

| 名称 | 说明 |
|---|---|
| `items` | 要处理的项目列表。 |
| `operation` | 项目处理回调。 |
| `options` | 遍历选项。 |

返回：流程报告。

结构：

- `items`: Array input items.
- `options`: Dictionary，可包含 stop_on_failure、cancel_token、operation_options、pass_index 和 metadata。
- `return`: Dictionary with ok, status, value, error, attempts, history, metadata, succeeded_count, and failed_count.

<a id="member-gfasyncflowtools-methods-fold_async"></a>

### `fold_async`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func fold_async(items: Array, reducer: Callable, initial_value: Variant, options: Dictionary = {}) -> Dictionary:
```

顺序折叠数组项。

参数：

| 名称 | 说明 |
|---|---|
| `items` | 要处理的项目列表。 |
| `reducer` | 折叠回调。 |
| `initial_value` | 初始累加值。 |
| `options` | 折叠选项。 |

返回：流程报告。

结构：

- `items`: Array input items.
- `initial_value`: Variant accumulator seed.
- `options`: Dictionary，可包含 stop_on_failure、cancel_token、operation_options、pass_index 和 metadata。
- `return`: Dictionary with ok, status, value, error, attempts, history, and metadata.

<a id="member-gfasyncflowtools-methods-wait_all_completions_async"></a>

### `wait_all_completions_async`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func wait_all_completions_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:
```

在主线程等待所有完成源进入终态。

参数：

| 名称 | 说明 |
|---|---|
| `completions` | key -> GFAsyncCompletion 的字典。 |
| `options` | 组合等待选项。 |

返回：组合等待报告；非主线程调用时 fail closed。

结构：

- `completions`: Dictionary，key 为调用方定义的稳定标识，value 必须是 GFAsyncCompletion。
- `options`: Dictionary，可包含 timeout_seconds、tree、cancel_token、guard_node、time_utility、respect_time_scale、process_in_physics、fail_fast、cancel_remaining_on_finish、max_completions 和 metadata。
- `return`: Dictionary，包含 ok、status、value、error、metadata、count、completed_count、pending_count、succeeded_count、failed_count、cancelled_count、items、results、completion_order、first_completed_key、first_success_key、cancel_reason、cancel_metadata 和 timed_out。

<a id="member-gfasyncflowtools-methods-wait_any_completion_async"></a>

### `wait_any_completion_async`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func wait_any_completion_async(completions: Dictionary, options: Dictionary = {}) -> Dictionary:
```

在主线程等待任一完成源成功。

参数：

| 名称 | 说明 |
|---|---|
| `completions` | key -> GFAsyncCompletion 的字典。 |
| `options` | 组合等待选项。 |

返回：组合等待报告；非主线程调用时 fail closed。

结构：

- `completions`: Dictionary，key 为调用方定义的稳定标识，value 必须是 GFAsyncCompletion。
- `options`: Dictionary，可包含 timeout_seconds、tree、cancel_token、guard_node、time_utility、respect_time_scale、process_in_physics、fail_fast、cancel_remaining_on_finish、max_completions 和 metadata。
- `return`: Dictionary，包含 ok、status、value、error、metadata、count、completed_count、pending_count、succeeded_count、failed_count、cancelled_count、items、results、completion_order、first_completed_key、first_success_key、cancel_reason、cancel_metadata 和 timed_out。
