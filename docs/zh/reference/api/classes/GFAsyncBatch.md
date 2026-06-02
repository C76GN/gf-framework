# GFAsyncBatch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_async_batch.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用异步结果批处理器。 用于等待一组 GFHttpResponse 或手动标记的异步任务完成，并统一汇总结果。 它不负责调度具体任务，只观察任务何时完成。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`item_completed`](#member-gfasyncbatch-signals-item_completed) | `signal item_completed(key: Variant, result: Variant)` |
| 信号 | [`completed`](#member-gfasyncbatch-signals-completed) | `signal completed(results: Dictionary)` |
| 方法 | [`add_item`](#member-gfasyncbatch-methods-add_item) | `func add_item(key: Variant, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`watch_response`](#member-gfasyncbatch-methods-watch_response) | `func watch_response(response: GFHttpResponse, key: Variant = null) -> bool:` |
| 方法 | [`mark_completed`](#member-gfasyncbatch-methods-mark_completed) | `func mark_completed(key: Variant, result: Variant = null) -> bool:` |
| 方法 | [`is_completed`](#member-gfasyncbatch-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_count`](#member-gfasyncbatch-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`get_completed_count`](#member-gfasyncbatch-methods-get_completed_count) | `func get_completed_count() -> int:` |
| 方法 | [`get_results`](#member-gfasyncbatch-methods-get_results) | `func get_results() -> Dictionary:` |
| 方法 | [`clear`](#member-gfasyncbatch-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncbatch-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncbatch-signals-item_completed"></a>

### `item_completed`

- API：`public`

```gdscript
signal item_completed(key: Variant, result: Variant)
```

单个条目完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `result` | 条目结果。 |

结构：

- `key`: Variant，调用方持有的条目标识，会作为结果字典的键。
- `result`: Variant，已完成条目的结果。

<a id="member-gfasyncbatch-signals-completed"></a>

### `completed`

- API：`public`

```gdscript
signal completed(results: Dictionary)
```

全部条目完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `results` | 批处理结果字典。 |

结构：

- `results`: Dictionary，将每个被等待的 key 映射到对应完成结果。

## 方法

<a id="member-gfasyncbatch-methods-add_item"></a>

### `add_item`

- API：`public`

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

```gdscript
func mark_completed(key: Variant, result: Variant = null) -> bool:
```

手动标记条目完成。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 条目标识。 |
| `result` | 条目结果。 |

返回：是否成功标记。

结构：

- `key`: Variant，调用方持有的条目标识，会作为结果字典的键。
- `result`: Variant，已完成条目的结果。

<a id="member-gfasyncbatch-methods-is_completed"></a>

### `is_completed`

- API：`public`

```gdscript
func is_completed() -> bool:
```

是否所有条目都已完成。

返回：所有条目完成时返回 true。

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

```gdscript
func get_completed_count() -> int:
```

获取已完成条目数量。

返回：已完成条目的数量。

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

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 count、completed_count、completed 和 keys。
