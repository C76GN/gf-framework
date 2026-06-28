# GFAsyncKeyedGate

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_keyed_gate.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

按 key 仲裁异步并发槽位。 用于把“同一个资源、槽位、存档、玩家或编辑器目标”的异步操作限制在可控并发内。 gate 只负责排队、发放租约、释放后推进队列，以及记录取消/超时诊断； 不创建线程、不执行任务，也不解释 key 的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`request_queued`](#member-gfasynckeyedgate-signals-request_queued) | `signal request_queued(request_id: int, key: Variant, metadata: Dictionary)` |
| 信号 | [`lease_acquired`](#member-gfasynckeyedgate-signals-lease_acquired) | `signal lease_acquired(lease: GFAsyncGateLease)` |
| 信号 | [`lease_released`](#member-gfasynckeyedgate-signals-lease_released) | `signal lease_released(lease: GFAsyncGateLease, reason: StringName)` |
| 信号 | [`request_cancelled`](#member-gfasynckeyedgate-signals-request_cancelled) | `signal request_cancelled(request_id: int, key: Variant, reason: StringName, metadata: Dictionary)` |
| 信号 | [`request_timed_out`](#member-gfasynckeyedgate-signals-request_timed_out) | `signal request_timed_out(request_id: int, key: Variant, metadata: Dictionary)` |
| 常量 | [`STATUS_ACQUIRED`](#member-gfasynckeyedgate-constants-status_acquired) | `const STATUS_ACQUIRED: StringName = &"acquired"` |
| 常量 | [`STATUS_QUEUED`](#member-gfasynckeyedgate-constants-status_queued) | `const STATUS_QUEUED: StringName = &"queued"` |
| 常量 | [`STATUS_RELEASED`](#member-gfasynckeyedgate-constants-status_released) | `const STATUS_RELEASED: StringName = &"released"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfasynckeyedgate-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_TIMEOUT`](#member-gfasynckeyedgate-constants-status_timeout) | `const STATUS_TIMEOUT: StringName = &"timeout"` |
| 常量 | [`STATUS_INVALID`](#member-gfasynckeyedgate-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 常量 | [`DEFAULT_MAX_CONCURRENCY`](#member-gfasynckeyedgate-constants-default_max_concurrency) | `const DEFAULT_MAX_CONCURRENCY: int = 1` |
| 常量 | [`DEFAULT_MAX_RECENT_EVENTS`](#member-gfasynckeyedgate-constants-default_max_recent_events) | `const DEFAULT_MAX_RECENT_EVENTS: int = 64` |
| 属性 | [`default_max_concurrency`](#member-gfasynckeyedgate-properties-default_max_concurrency) | `var default_max_concurrency: int = DEFAULT_MAX_CONCURRENCY:` |
| 属性 | [`max_recent_events`](#member-gfasynckeyedgate-properties-max_recent_events) | `var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:` |
| 方法 | [`request_lease`](#member-gfasynckeyedgate-methods-request_lease) | `func request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_for_lease_async`](#member-gfasynckeyedgate-methods-wait_for_lease_async) | `func wait_for_lease_async(key: Variant, options: Dictionary = {}) -> GFAsyncGateLease:` |
| 方法 | [`release_lease`](#member-gfasynckeyedgate-methods-release_lease) | `func release_lease(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:` |
| 方法 | [`cancel_request`](#member-gfasynckeyedgate-methods-cancel_request) | `func cancel_request(request_id: int, reason: StringName = STATUS_CANCELLED, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`clear`](#member-gfasynckeyedgate-methods-clear) | `func clear(reason: StringName = &"cleared", metadata: Dictionary = {}) -> int:` |
| 方法 | [`set_key_max_concurrency`](#member-gfasynckeyedgate-methods-set_key_max_concurrency) | `func set_key_max_concurrency(key: Variant, max_concurrency: int) -> int:` |
| 方法 | [`get_key_max_concurrency`](#member-gfasynckeyedgate-methods-get_key_max_concurrency) | `func get_key_max_concurrency(key: Variant) -> int:` |
| 方法 | [`expire_waiting_requests`](#member-gfasynckeyedgate-methods-expire_waiting_requests) | `func expire_waiting_requests(now_msec: int = -1) -> int:` |
| 方法 | [`expire_active_leases`](#member-gfasynckeyedgate-methods-expire_active_leases) | `func expire_active_leases(now_msec: int = -1) -> int:` |
| 方法 | [`has_key_activity`](#member-gfasynckeyedgate-methods-has_key_activity) | `func has_key_activity(key: Variant) -> bool:` |
| 方法 | [`get_key_snapshot`](#member-gfasynckeyedgate-methods-get_key_snapshot) | `func get_key_snapshot(key: Variant) -> Dictionary:` |
| 方法 | [`get_recent_events`](#member-gfasynckeyedgate-methods-get_recent_events) | `func get_recent_events() -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfasynckeyedgate-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasynckeyedgate-signals-request_queued"></a>

### `request_queued`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal request_queued(request_id: int, key: Variant, metadata: Dictionary)
```

请求进入等待队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | gate 内唯一请求 ID。 |
| `key` | 请求 key 副本。 |
| `metadata` | 请求元数据。 |

结构：

- `key`: Variant，调用方传入的 key。
- `metadata`: Dictionary，调用方定义的请求上下文。

<a id="member-gfasynckeyedgate-signals-lease_acquired"></a>

### `lease_acquired`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal lease_acquired(lease: GFAsyncGateLease)
```

请求获得租约时发出。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 获得的租约句柄。 |

<a id="member-gfasynckeyedgate-signals-lease_released"></a>

### `lease_released`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal lease_released(lease: GFAsyncGateLease, reason: StringName)
```

租约释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 被释放的租约句柄。 |
| `reason` | 稳定释放原因。 |

<a id="member-gfasynckeyedgate-signals-request_cancelled"></a>

### `request_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal request_cancelled(request_id: int, key: Variant, reason: StringName, metadata: Dictionary)
```

等待请求取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | gate 内唯一请求 ID。 |
| `key` | 请求 key 副本。 |
| `reason` | 稳定取消原因。 |
| `metadata` | 取消上下文。 |

结构：

- `key`: Variant，调用方传入的 key。
- `metadata`: Dictionary，包含取消上下文。

<a id="member-gfasynckeyedgate-signals-request_timed_out"></a>

### `request_timed_out`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal request_timed_out(request_id: int, key: Variant, metadata: Dictionary)
```

等待请求超时时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | gate 内唯一请求 ID。 |
| `key` | 请求 key 副本。 |
| `metadata` | 超时上下文。 |

结构：

- `key`: Variant，调用方传入的 key。
- `metadata`: Dictionary，包含超时上下文。

## 常量

<a id="member-gfasynckeyedgate-constants-status_acquired"></a>

### `STATUS_ACQUIRED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_ACQUIRED: StringName = &"acquired"
```

请求已获得租约。

<a id="member-gfasynckeyedgate-constants-status_queued"></a>

### `STATUS_QUEUED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_QUEUED: StringName = &"queued"
```

请求已进入队列。

<a id="member-gfasynckeyedgate-constants-status_released"></a>

### `STATUS_RELEASED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_RELEASED: StringName = &"released"
```

租约已释放。

<a id="member-gfasynckeyedgate-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

请求已取消。

<a id="member-gfasynckeyedgate-constants-status_timeout"></a>

### `STATUS_TIMEOUT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_TIMEOUT: StringName = &"timeout"
```

请求等待超时。

<a id="member-gfasynckeyedgate-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

请求无效。

<a id="member-gfasynckeyedgate-constants-default_max_concurrency"></a>

### `DEFAULT_MAX_CONCURRENCY`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_CONCURRENCY: int = 1
```

默认每个 key 的并发槽位数。

<a id="member-gfasynckeyedgate-constants-default_max_recent_events"></a>

### `DEFAULT_MAX_RECENT_EVENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_RECENT_EVENTS: int = 64
```

默认保留的最近事件数量。

## 属性

<a id="member-gfasynckeyedgate-properties-default_max_concurrency"></a>

### `default_max_concurrency`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var default_max_concurrency: int = DEFAULT_MAX_CONCURRENCY:
```

未显式配置 key 时的最大并发槽位数。

<a id="member-gfasynckeyedgate-properties-max_recent_events"></a>

### `max_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
```

最近事件历史上限。设置为 0 时不保留事件。

## 方法

<a id="member-gfasynckeyedgate-methods-request_lease"></a>

### `request_lease`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:
```

请求一个 key 的执行租约。 如果当前 key 仍有并发槽位，会立即返回 acquired；否则返回 queued，并在 result 中提供 GFAsyncCompletion。队列推进后 completion 会成功并携带 lease。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |
| `options` | 请求选项，支持 metadata、max_concurrency、timeout_msec、lease_timeout_msec 和 cancel_token。 |

返回：请求结果字典。

结构：

- `key`: Variant，建议使用 String、StringName、int 或可稳定 var_to_str() 的纯数据值。
- `options`: Dictionary，可包含 metadata: Dictionary、max_concurrency: int、timeout_msec: int、lease_timeout_msec: int、cancel_token: GFCancelToken。
- `return`: Dictionary，包含 ok、status、queued、acquired、request_id、key、lease、completion、metadata 和 reason。

<a id="member-gfasynckeyedgate-methods-wait_for_lease_async"></a>

### `wait_for_lease_async`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func wait_for_lease_async(key: Variant, options: Dictionary = {}) -> GFAsyncGateLease:
```

等待并返回租约。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |
| `options` | 请求选项；wait_options 会传给 GFAsyncCompletion.wait_async()。 |

返回：获得的租约；取消、超时或失效时返回 null。

结构：

- `key`: Variant，建议使用 String、StringName、int 或可稳定 var_to_str() 的纯数据值。
- `options`: Dictionary，支持 request_lease() 选项，并可包含 wait_options: Dictionary。

<a id="member-gfasynckeyedgate-methods-release_lease"></a>

### `release_lease`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func release_lease(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:
```

释放一个租约。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | request_lease() 或 wait_for_lease_async() 返回的租约。 |
| `reason` | 稳定释放原因。 |

返回：首次释放成功时返回 true。

<a id="member-gfasynckeyedgate-methods-cancel_request"></a>

### `cancel_request`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_request(request_id: int, reason: StringName = STATUS_CANCELLED, metadata: Dictionary = {}) -> bool:
```

取消一个仍在等待队列中的请求。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | request_lease() 返回的请求 ID。 |
| `reason` | 稳定取消原因。 |
| `metadata` | 取消上下文。 |

返回：找到并取消等待请求时返回 true。

结构：

- `metadata`: Dictionary，调用方定义的取消上下文。

<a id="member-gfasynckeyedgate-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear(reason: StringName = &"cleared", metadata: Dictionary = {}) -> int:
```

取消全部等待请求并释放全部活跃租约。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定清理原因。 |
| `metadata` | 清理上下文。 |

返回：受影响的请求和租约数量。

结构：

- `metadata`: Dictionary，调用方定义的清理上下文。

<a id="member-gfasynckeyedgate-methods-set_key_max_concurrency"></a>

### `set_key_max_concurrency`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_key_max_concurrency(key: Variant, max_concurrency: int) -> int:
```

设置某个 key 的最大并发槽位数。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |
| `max_concurrency` | 最大并发槽位数；小于 1 时按 1 处理。 |

返回：归一化后的并发槽位数。

结构：

- `key`: Variant，调用方传入的 key。

<a id="member-gfasynckeyedgate-methods-get_key_max_concurrency"></a>

### `get_key_max_concurrency`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_key_max_concurrency(key: Variant) -> int:
```

获取某个 key 的最大并发槽位数。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |

返回：当前 key 的最大并发槽位数。

结构：

- `key`: Variant，调用方传入的 key。

<a id="member-gfasynckeyedgate-methods-expire_waiting_requests"></a>

### `expire_waiting_requests`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func expire_waiting_requests(now_msec: int = -1) -> int:
```

过期等待队列中已取消或超时的请求。 该方法不会创建计时器；适合由调用方在帧循环、工具刷新或关键操作边界显式调用。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 参考时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：本次过期的等待请求数量。

<a id="member-gfasynckeyedgate-methods-expire_active_leases"></a>

### `expire_active_leases`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func expire_active_leases(now_msec: int = -1) -> int:
```

释放已超过 lease_timeout_msec 的活跃租约。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 参考时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：本次释放的活跃租约数量。

<a id="member-gfasynckeyedgate-methods-has_key_activity"></a>

### `has_key_activity`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_key_activity(key: Variant) -> bool:
```

判断某个 key 当前是否存在等待或活跃租约。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |

返回：存在等待请求或活跃租约时返回 true。

结构：

- `key`: Variant，调用方传入的 key。

<a id="member-gfasynckeyedgate-methods-get_key_snapshot"></a>

### `get_key_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_key_snapshot(key: Variant) -> Dictionary:
```

获取某个 key 的状态快照。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |

返回：key 状态快照。

结构：

- `key`: Variant，调用方传入的 key。
- `return`: Dictionary，包含 key、queued_count、active_count、max_concurrency、waiting_request_ids、active_lease_ids 和 metadata。

<a id="member-gfasynckeyedgate-methods-get_recent_events"></a>

### `get_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_recent_events() -> Array[Dictionary]:
```

获取最近 gate 事件。

返回：最近事件数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 event_index、event_type、request_id、lease_id、key、reason 和 timestamp_msec。

<a id="member-gfasynckeyedgate-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 gate 调试快照。

返回：gate 状态快照。

结构：

- `return`: Dictionary，包含 queued_count、active_count、key_count、acquired_count、released_count、cancelled_count、timeout_count、keys 和 recent_events。
