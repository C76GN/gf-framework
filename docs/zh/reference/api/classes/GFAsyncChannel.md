# GFAsyncChannel

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_channel.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

轻量异步事件通道。 提供多生产者、单消费者的无界队列语义，可同步写入，也可异步等待下一条数据。 它不负责调度任务、流式转换或业务协议，只在生产者和消费者之间传递 Variant 事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`item_written`](#member-gfasyncchannel-signals-item_written) | `signal item_written(item: Variant)` |
| 信号 | [`closed`](#member-gfasyncchannel-signals-closed) | `signal closed(reason: StringName, metadata: Dictionary)` |
| 常量 | [`STATUS_COMPLETED`](#member-gfasyncchannel-constants-status_completed) | `const STATUS_COMPLETED: StringName = GFAsyncWaitUtility.STATUS_COMPLETED` |
| 常量 | [`STATUS_CANCELLED`](#member-gfasyncchannel-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = GFAsyncWaitUtility.STATUS_CANCELLED` |
| 常量 | [`STATUS_TIMEOUT`](#member-gfasyncchannel-constants-status_timeout) | `const STATUS_TIMEOUT: StringName = GFAsyncWaitUtility.STATUS_TIMEOUT` |
| 常量 | [`STATUS_INVALID`](#member-gfasyncchannel-constants-status_invalid) | `const STATUS_INVALID: StringName = GFAsyncWaitUtility.STATUS_INVALID` |
| 常量 | [`STATUS_CLOSED`](#member-gfasyncchannel-constants-status_closed) | `const STATUS_CLOSED: StringName = &"closed"` |
| 常量 | [`STATUS_PENDING`](#member-gfasyncchannel-constants-status_pending) | `const STATUS_PENDING: StringName = &"pending"` |
| 方法 | [`try_write`](#member-gfasyncchannel-methods-try_write) | `func try_write(item: Variant) -> bool:` |
| 方法 | [`close`](#member-gfasyncchannel-methods-close) | `func close(reason: StringName = STATUS_CLOSED, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`try_read`](#member-gfasyncchannel-methods-try_read) | `func try_read(default_value: Variant = null) -> Dictionary:` |
| 方法 | [`read_async`](#member-gfasyncchannel-methods-read_async) | `func read_async(options: Dictionary = {}, default_value: Variant = null) -> Dictionary:` |
| 方法 | [`wait_to_read_async`](#member-gfasyncchannel-methods-wait_to_read_async) | `func wait_to_read_async(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`drain`](#member-gfasyncchannel-methods-drain) | `func drain(max_items: int = -1) -> Array:` |
| 方法 | [`clear`](#member-gfasyncchannel-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_closed`](#member-gfasyncchannel-methods-is_closed) | `func is_closed() -> bool:` |
| 方法 | [`is_open`](#member-gfasyncchannel-methods-is_open) | `func is_open() -> bool:` |
| 方法 | [`has_items`](#member-gfasyncchannel-methods-has_items) | `func has_items() -> bool:` |
| 方法 | [`get_count`](#member-gfasyncchannel-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncchannel-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncchannel-signals-item_written"></a>

### `item_written`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal item_written(item: Variant)
```

成功写入一条数据时发出。

参数：

| 名称 | 说明 |
|---|---|
| `item` | 写入的数据副本。 |

结构：

- `item`: Variant 写入通道的数据副本。

<a id="member-gfasyncchannel-signals-closed"></a>

### `closed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal closed(reason: StringName, metadata: Dictionary)
```

通道关闭时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 关闭原因。 |
| `metadata` | 关闭上下文。 |

结构：

- `metadata`: Dictionary，包含调用方定义的关闭上下文。

## 常量

<a id="member-gfasyncchannel-constants-status_completed"></a>

### `STATUS_COMPLETED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_COMPLETED: StringName = GFAsyncWaitUtility.STATUS_COMPLETED
```

读取已完成。

<a id="member-gfasyncchannel-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_CANCELLED: StringName = GFAsyncWaitUtility.STATUS_CANCELLED
```

读取等待被取消。

<a id="member-gfasyncchannel-constants-status_timeout"></a>

### `STATUS_TIMEOUT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_TIMEOUT: StringName = GFAsyncWaitUtility.STATUS_TIMEOUT
```

读取等待超时。

<a id="member-gfasyncchannel-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVALID: StringName = GFAsyncWaitUtility.STATUS_INVALID
```

读取等待因上下文失效结束。

<a id="member-gfasyncchannel-constants-status_closed"></a>

### `STATUS_CLOSED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_CLOSED: StringName = &"closed"
```

通道已关闭且没有可读数据。

<a id="member-gfasyncchannel-constants-status_pending"></a>

### `STATUS_PENDING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_PENDING: StringName = &"pending"
```

通道当前没有可读数据。

## 方法

<a id="member-gfasyncchannel-methods-try_write"></a>

### `try_write`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_write(item: Variant) -> bool:
```

写入一条数据。

参数：

| 名称 | 说明 |
|---|---|
| `item` | 待写入的数据。 |

返回：写入成功时返回 true；关闭后返回 false。

结构：

- `item`: Variant 待写入通道的数据。

<a id="member-gfasyncchannel-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func close(reason: StringName = STATUS_CLOSED, metadata: Dictionary = {}) -> bool:
```

关闭通道。已缓冲的数据仍可继续读出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 关闭原因。 |
| `metadata` | 关闭上下文。 |

返回：首次关闭时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的关闭上下文。

<a id="member-gfasyncchannel-methods-try_read"></a>

### `try_read`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read(default_value: Variant = null) -> Dictionary:
```

同步尝试读取一条数据。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 无可读数据时返回的兜底 item。 |

返回：读取结果。

结构：

- `default_value`: Variant 无可读数据时写入返回结果 item 的兜底值。
- `return`: Dictionary，包含 status、ok、item、closed、reason 和 metadata。

<a id="member-gfasyncchannel-methods-read_async"></a>

### `read_async`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_async(options: Dictionary = {}, default_value: Variant = null) -> Dictionary:
```

等待并读取下一条数据。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 等待选项，透传给 GFAsyncWaitUtility.wait_until。 |
| `default_value` | 无可读数据时返回的兜底 item。 |

返回：读取结果。

结构：

- `default_value`: Variant 无可读数据时写入返回结果 item 的兜底值。
- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、ok、item、closed、reason、metadata 和 wait_result。

<a id="member-gfasyncchannel-methods-wait_to_read_async"></a>

### `wait_to_read_async`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func wait_to_read_async(options: Dictionary = {}) -> Dictionary:
```

等待通道进入可读或关闭状态，不消费数据。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 等待选项，透传给 GFAsyncWaitUtility.wait_until。 |

返回：等待结果。

结构：

- `options`: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
- `return`: Dictionary，包含 status、readable、closed、reason、metadata 和 count。

<a id="member-gfasyncchannel-methods-drain"></a>

### `drain`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func drain(max_items: int = -1) -> Array:
```

读出当前缓冲区中的数据。

参数：

| 名称 | 说明 |
|---|---|
| `max_items` | 最多读出数量；小于 0 时读出全部。 |

返回：已读出的数据数组。

结构：

- `return`: Array[Variant]，包含按 FIFO 顺序读出的数据副本。

<a id="member-gfasyncchannel-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空当前缓冲区。

<a id="member-gfasyncchannel-methods-is_closed"></a>

### `is_closed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_closed() -> bool:
```

判断通道是否已经关闭。

返回：已关闭时返回 true。

<a id="member-gfasyncchannel-methods-is_open"></a>

### `is_open`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_open() -> bool:
```

判断通道是否仍可写入。

返回：可写入时返回 true。

<a id="member-gfasyncchannel-methods-has_items"></a>

### `has_items`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_items() -> bool:
```

判断缓冲区中是否存在可读数据。

返回：存在可读数据时返回 true。

<a id="member-gfasyncchannel-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_count() -> int:
```

获取当前缓冲数量。

返回：当前缓冲数量。

<a id="member-gfasyncchannel-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取通道调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 closed、count、written_count、read_count、reason 和 metadata。
