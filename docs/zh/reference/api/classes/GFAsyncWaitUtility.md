# GFAsyncWaitUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_wait_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

公共 Signal 等待辅助。 提供带超时、取消 token、生命周期保护和 payload 捕获的 Signal、帧、延迟和条件等待入口。 它只负责等待状态，不创建业务任务，也不替代项目自己的流程编排。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_COMPLETED`](#member-gfasyncwaitutility-constants-status_completed) | `const STATUS_COMPLETED: StringName = &"completed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfasyncwaitutility-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_TIMEOUT`](#member-gfasyncwaitutility-constants-status_timeout) | `const STATUS_TIMEOUT: StringName = &"timeout"` |
| 常量 | [`STATUS_INVALID`](#member-gfasyncwaitutility-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 方法 | [`await_signal`](#member-gfasyncwaitutility-methods-await_signal) | `static func await_signal(result_signal: Signal, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`await_signal_payload`](#member-gfasyncwaitutility-methods-await_signal_payload) | `static func await_signal_payload(result_signal: Signal, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_completion_async`](#member-gfasyncwaitutility-methods-wait_completion_async) | `static func wait_completion_async(completion: GFAsyncCompletion, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`next_frame`](#member-gfasyncwaitutility-methods-next_frame) | `static func next_frame(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`physics_frame`](#member-gfasyncwaitutility-methods-physics_frame) | `static func physics_frame(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`delay_seconds`](#member-gfasyncwaitutility-methods-delay_seconds) | `static func delay_seconds(seconds: float, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_until`](#member-gfasyncwaitutility-methods-wait_until) | `static func wait_until(predicate: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_while`](#member-gfasyncwaitutility-methods-wait_while) | `static func wait_while(predicate: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_until_value_changed`](#member-gfasyncwaitutility-methods-wait_until_value_changed) | `static func wait_until_value_changed(getter: Callable, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfasyncwaitutility-constants-status_completed"></a>

### `STATUS_COMPLETED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_COMPLETED: StringName = &"completed"
```

等待正常由目标 Signal 完成。

<a id="member-gfasyncwaitutility-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

等待被取消 token 结束。

<a id="member-gfasyncwaitutility-constants-status_timeout"></a>

### `STATUS_TIMEOUT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_TIMEOUT: StringName = &"timeout"
```

等待因超时结束。

<a id="member-gfasyncwaitutility-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

等待因目标或保护节点失效结束。

## 方法

<a id="member-gfasyncwaitutility-methods-await_signal"></a>

### `await_signal`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func await_signal(result_signal: Signal, options: Dictionary = {}) -> Dictionary:
```

等待 Signal 发出，不捕获参数。

参数：

| 名称 | 说明 |
|---|---|
| `result_signal` | 要等待的 Signal。 |
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale、process_in_physics 和 timeout_warning。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-await_signal_payload"></a>

### `await_signal_payload`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func await_signal_payload(result_signal: Signal, options: Dictionary = {}) -> Dictionary:
```

等待 Signal 发出，并捕获最多 16 个参数。

参数：

| 名称 | 说明 |
|---|---|
| `result_signal` | 要等待的 Signal。 |
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale、process_in_physics 和 timeout_warning。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-wait_completion_async"></a>

### `wait_completion_async`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func wait_completion_async(completion: GFAsyncCompletion, options: Dictionary = {}) -> Dictionary:
```

等待完成源进入终态。

参数：

| 名称 | 说明 |
|---|---|
| `completion` | 要等待的完成源。 |
| `options` | 等待选项。 |

返回：完成源快照；等待超时、取消或失效时包含 wait_status 字段。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、time_utility、respect_time_scale 和 timeout_warning。
- `return`: Dictionary，包含 status、status_name、completed、result、error、cancel_reason、metadata 和可选 wait_status。

<a id="member-gfasyncwaitutility-methods-next_frame"></a>

### `next_frame`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func next_frame(options: Dictionary = {}) -> Dictionary:
```

等待下一帧 process_frame。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility 和 respect_time_scale。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-physics_frame"></a>

### `physics_frame`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func physics_frame(options: Dictionary = {}) -> Dictionary:
```

等待下一帧 physics_frame。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility 和 respect_time_scale。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-delay_seconds"></a>

### `delay_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func delay_seconds(seconds: float, options: Dictionary = {}) -> Dictionary:
```

等待指定秒数。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 等待秒数；小于等于 0 时立即完成。 |
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-wait_until"></a>

### `wait_until`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func wait_until(predicate: Callable, options: Dictionary = {}) -> Dictionary:
```

等待 predicate 返回 true。

参数：

| 名称 | 说明 |
|---|---|
| `predicate` | 无参判断回调；返回值会收窄为 bool。 |
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-wait_while"></a>

### `wait_while`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func wait_while(predicate: Callable, options: Dictionary = {}) -> Dictionary:
```

等待 predicate 返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `predicate` | 无参判断回调；返回值会收窄为 bool。 |
| `options` | 等待选项。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。

<a id="member-gfasyncwaitutility-methods-wait_until_value_changed"></a>

### `wait_until_value_changed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func wait_until_value_changed(getter: Callable, options: Dictionary = {}) -> Dictionary:
```

等待 getter 返回值发生变化。

参数：

| 名称 | 说明 |
|---|---|
| `getter` | 无参取值回调。 |
| `options` | 等待选项。 |

返回：等待结果；完成时包含 previous_value 和 value。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata、args、previous_value 和 value。
