# GFAsyncBatch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_async_batch.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用异步结果批处理器。 用于等待一组 [GFHttpResponse] 或手动标记的异步条目，并统一汇总成功、失败、 取消、超时和首个完成项。它不负责调度具体任务，只观察任务何时进入终态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`item_completed`](#member-gfasyncbatch-signals-item_completed) | `signal item_completed(key: Variant, result: Variant)` |
| 信号 | [`item_settled`](#member-gfasyncbatch-signals-item_settled) | `signal item_settled(key: Variant, result: Variant, state: StringName)` |
| 信号 | [`completed`](#member-gfasyncbatch-signals-completed) | `signal completed(results: Dictionary)` |
| 信号 | [`settled`](#member-gfasyncbatch-signals-settled) | `signal settled(report: Dictionary)` |
| 信号 | [`cancelled`](#member-gfasyncbatch-signals-cancelled) | `signal cancelled(reason: StringName, metadata: Dictionary)` |
| 枚举 | [`CompletionPolicy`](#member-gfasyncbatch-enums-completionpolicy) | `enum CompletionPolicy` |
| 枚举 | [`ItemState`](#member-gfasyncbatch-enums-itemstate) | `enum ItemState` |
| 属性 | [`completion_policy`](#member-gfasyncbatch-properties-completion_policy) | `var completion_policy: CompletionPolicy = CompletionPolicy.ALL` |
| 属性 | [`fail_fast`](#member-gfasyncbatch-properties-fail_fast) | `var fail_fast: bool = true` |
| 属性 | [`cancel_remaining_on_finish`](#member-gfasyncbatch-properties-cancel_remaining_on_finish) | `var cancel_remaining_on_finish: bool = false` |
| 方法 | [`add_item`](#member-gfasyncbatch-methods-add_item) | `func add_item(key: Variant, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`set_item_cancel_callback`](#member-gfasyncbatch-methods-set_item_cancel_callback) | `func set_item_cancel_callback(key: Variant, callback: Callable) -> bool:` |
| 方法 | [`watch_response`](#member-gfasyncbatch-methods-watch_response) | `func watch_response(response: GFHttpResponse, key: Variant = null) -> bool:` |
| 方法 | [`mark_completed`](#member-gfasyncbatch-methods-mark_completed) | `func mark_completed(key: Variant, result: Variant = null) -> bool:` |
| 方法 | [`mark_failed`](#member-gfasyncbatch-methods-mark_failed) | `func mark_failed(key: Variant, error: String = "", result: Variant = null) -> bool:` |
| 方法 | [`mark_cancelled`](#member-gfasyncbatch-methods-mark_cancelled) | `func mark_cancelled(key: Variant, reason: StringName = &"cancelled", result: Variant = null) -> bool:` |
| 方法 | [`cancel`](#member-gfasyncbatch-methods-cancel) | `func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`bind_cancel_token`](#member-gfasyncbatch-methods-bind_cancel_token) | `func bind_cancel_token(token: GFCancelToken) -> bool:` |
| 方法 | [`set_timeout`](#member-gfasyncbatch-methods-set_timeout) | `func set_timeout( seconds: float, tree: SceneTree = null, reason: StringName = &"timeout", metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`is_completed`](#member-gfasyncbatch-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfasyncbatch-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_count`](#member-gfasyncbatch-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`get_completed_count`](#member-gfasyncbatch-methods-get_completed_count) | `func get_completed_count() -> int:` |
| 方法 | [`get_pending_count`](#member-gfasyncbatch-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_failed_count`](#member-gfasyncbatch-methods-get_failed_count) | `func get_failed_count() -> int:` |
| 方法 | [`get_cancelled_count`](#member-gfasyncbatch-methods-get_cancelled_count) | `func get_cancelled_count() -> int:` |
| 方法 | [`get_results`](#member-gfasyncbatch-methods-get_results) | `func get_results() -> Dictionary:` |
| 方法 | [`get_report`](#member-gfasyncbatch-methods-get_report) | `func get_report() -> Dictionary:` |
| 方法 | [`clear`](#member-gfasyncbatch-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncbatch-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncbatch-signals-item_completed"></a>

### `item_completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal item_completed(key: Variant, result: Variant)
```

单个条目成功完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `result` | 条目结果。 |

结构：

- `key`: Variant，调用方持有的条目标识，会作为结果字典的键。
- `result`: Variant，已完成条目的结果。

<a id="member-gfasyncbatch-signals-item_settled"></a>

### `item_settled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal item_settled(key: Variant, result: Variant, state: StringName)
```

单个条目进入任意终态后发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `result` | 条目结果。 |
| `state` | 条目终态。 |

结构：

- `key`: Variant，调用方持有的条目标识。
- `result`: Variant，调用方定义的条目结果。

<a id="member-gfasyncbatch-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal completed(results: Dictionary)
```

全部或策略要求的条目完成后发出旧式结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `results` | 批处理结果字典。 |

结构：

- `results`: Dictionary，将每个被等待的 key 映射到对应完成结果。

<a id="member-gfasyncbatch-signals-settled"></a>

### `settled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal settled(report: Dictionary)
```

批处理进入终态后发出结构化报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 批处理终态报告。 |

结构：

- `report`: Dictionary，包含 policy、success、cancelled、timed_out、counts、items、results、completion_order 和 first_completed_key。

<a id="member-gfasyncbatch-signals-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal cancelled(reason: StringName, metadata: Dictionary)
```

批处理被外部取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 取消上下文。 |

结构：

- `metadata`: Dictionary，调用方定义的取消上下文。

## 枚举

<a id="member-gfasyncbatch-enums-completionpolicy"></a>

### `CompletionPolicy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum CompletionPolicy {
	## 所有条目都成功时批处理成功；失败或取消可按 fail_fast 提前结束。
	ALL,
	## 任一条目成功时批处理成功；所有条目都失败或取消时批处理失败。
	ANY,
	## 等待每个条目进入任意终态，适合 all-settled 汇总。
	EACH,
}
```

批处理完成策略。

<a id="member-gfasyncbatch-enums-itemstate"></a>

### `ItemState`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum ItemState {
	## 条目仍在等待。
	PENDING,
	## 条目成功完成。
	SUCCEEDED,
	## 条目失败。
	FAILED,
	## 条目被取消。
	CANCELLED,
}
```

条目状态。

## 属性

<a id="member-gfasyncbatch-properties-completion_policy"></a>

### `completion_policy`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var completion_policy: CompletionPolicy = CompletionPolicy.ALL
```

批处理完成策略。

<a id="member-gfasyncbatch-properties-fail_fast"></a>

### `fail_fast`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var fail_fast: bool = true
```

ALL / ANY 策略遇到失败或取消时是否提前结束。

<a id="member-gfasyncbatch-properties-cancel_remaining_on_finish"></a>

### `cancel_remaining_on_finish`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var cancel_remaining_on_finish: bool = false
```

批处理终态确定后是否取消仍在等待的条目。

## 方法

<a id="member-gfasyncbatch-methods-add_item"></a>

### `add_item`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_item(key: Variant, metadata: Dictionary = {}) -> bool:
```

添加一个等待条目。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `metadata` | 条目元数据。 |

返回：是否添加成功。

结构：

- `key`: Variant，调用方持有的条目标识，会作为结果字典的键。
- `metadata`: Dictionary，调用方持有并关联到该条目的元数据。

<a id="member-gfasyncbatch-methods-set_item_cancel_callback"></a>

### `set_item_cancel_callback`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_item_cancel_callback(key: Variant, callback: Callable) -> bool:
```

为条目设置取消回调。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `callback` | 取消回调，签名推荐为 func(key: Variant, reason: StringName)。 |

返回：设置成功时返回 true。

结构：

- `key`: Variant，调用方持有的条目标识。

<a id="member-gfasyncbatch-methods-watch_response"></a>

### `watch_response`

- API：`public`

```gdscript
func watch_response(response: GFHttpResponse, key: Variant = null) -> bool:
```

监听 GFHttpResponse。

参数：

| 名称 | 说明 |
|---|---|
| `response` | 响应对象。 |
| `key` | 条目标识；为空时使用响应 URL。 |

返回：是否开始监听。

结构：

- `key`: Variant，调用方持有的条目标识；为 null 时使用 response.url。

<a id="member-gfasyncbatch-methods-mark_completed"></a>

### `mark_completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func mark_completed(key: Variant, result: Variant = null) -> bool:
```

手动标记条目成功完成。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `result` | 条目结果。 |

返回：是否成功标记。

结构：

- `key`: Variant，调用方持有的条目标识，会作为结果字典的键。
- `result`: Variant，已完成条目的结果。

<a id="member-gfasyncbatch-methods-mark_failed"></a>

### `mark_failed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_failed(key: Variant, error: String = "", result: Variant = null) -> bool:
```

手动标记条目失败。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `error` | 失败说明。 |
| `result` | 可选失败结果。 |

返回：是否成功标记。

结构：

- `key`: Variant，调用方持有的条目标识。
- `result`: Variant，调用方定义的失败载荷。

<a id="member-gfasyncbatch-methods-mark_cancelled"></a>

### `mark_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_cancelled(key: Variant, reason: StringName = &"cancelled", result: Variant = null) -> bool:
```

手动标记条目取消。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `reason` | 取消原因。 |
| `result` | 可选取消结果。 |

返回：是否成功标记。

结构：

- `key`: Variant，调用方持有的条目标识。
- `result`: Variant，调用方定义的取消载荷。

<a id="member-gfasyncbatch-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
```

取消整个批处理，并取消仍在等待的条目。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 取消上下文。 |

返回：首次取消批处理时返回 true。

结构：

- `metadata`: Dictionary，调用方定义的取消上下文。

<a id="member-gfasyncbatch-methods-bind_cancel_token"></a>

### `bind_cancel_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func bind_cancel_token(token: GFCancelToken) -> bool:
```

绑定取消 token；token 取消时取消整个批处理。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 取消 token。 |

返回：成功绑定或 token 已触发取消时返回 true。

<a id="member-gfasyncbatch-methods-set_timeout"></a>

### `set_timeout`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_timeout( seconds: float, tree: SceneTree = null, reason: StringName = &"timeout", metadata: Dictionary = {} ) -> bool:
```

设置批处理超时。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时时间；小于等于 0 时立即取消。 |
| `tree` | 可选 SceneTree；为空时使用当前主循环。 |
| `reason` | 超时取消原因。 |
| `metadata` | 取消上下文。 |

返回：成功安排或立即触发取消时返回 true。

结构：

- `metadata`: Dictionary，调用方定义的取消上下文。

<a id="member-gfasyncbatch-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_completed() -> bool:
```

是否批处理已经进入终态。

返回：批处理完成、失败或取消时返回 true。

<a id="member-gfasyncbatch-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_successful() -> bool:
```

批处理是否以成功状态结束。

返回：成功结束时返回 true。

<a id="member-gfasyncbatch-methods-get_count"></a>

### `get_count`

- API：`public`

```gdscript
func get_count() -> int:
```

获取条目数量。

返回：当前批处理中的条目数量。

<a id="member-gfasyncbatch-methods-get_completed_count"></a>

### `get_completed_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_completed_count() -> int:
```

获取已进入终态的条目数量。

返回：已进入终态的条目数量。

<a id="member-gfasyncbatch-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_count() -> int:
```

获取等待中的条目数量。

返回：等待中的条目数量。

<a id="member-gfasyncbatch-methods-get_failed_count"></a>

### `get_failed_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_failed_count() -> int:
```

获取失败条目数量。

返回：失败条目数量。

<a id="member-gfasyncbatch-methods-get_cancelled_count"></a>

### `get_cancelled_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_cancelled_count() -> int:
```

获取取消条目数量。

返回：取消条目数量。

<a id="member-gfasyncbatch-methods-get_results"></a>

### `get_results`

- API：`public`

```gdscript
func get_results() -> Dictionary:
```

获取结果字典。

返回：key -> result 的字典副本。

结构：

- `return`: Dictionary，将每个被等待的 key 映射到对应完成结果或 null。

<a id="member-gfasyncbatch-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report() -> Dictionary:
```

获取结构化批处理报告。

返回：批处理报告。

结构：

- `return`: Dictionary，包含 policy、completed、success、cancelled、timed_out、counts、items、results、completion_order、first_completed_key、first_success_key、cancel_reason 和 cancel_metadata。

<a id="member-gfasyncbatch-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空批处理。

<a id="member-gfasyncbatch-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 count、completed_count、completed、success、policy_name、keys 和 counts。
