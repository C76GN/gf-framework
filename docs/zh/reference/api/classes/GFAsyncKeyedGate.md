# GFAsyncKeyedGate

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_keyed_gate.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

按 key 仲裁异步并发槽位。 用于把“同一个资源、槽位、存档、玩家或编辑器目标”的异步操作限制在可控并发内。 gate 只负责排队、发放租约、释放后推进队列，以及记录取消/超时诊断； 全局槽位按稳定 key 游标轮转，持续繁忙的 key 不会永久阻塞其它 key； 不创建线程、不执行任务，也不解释 key 的业务含义。全部入口只允许在主线程调用； 跨线程请求应先通过 GFMainThreadDispatchQueue 回到主线程。

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
| 常量 | [`STATUS_REJECTED`](#member-gfasynckeyedgate-constants-status_rejected) | `const STATUS_REJECTED: StringName = &"rejected"` |
| 常量 | [`STATUS_BUSY`](#member-gfasynckeyedgate-constants-status_busy) | `const STATUS_BUSY: StringName = &"busy"` |
| 常量 | [`DEFAULT_MAX_CONCURRENCY`](#member-gfasynckeyedgate-constants-default_max_concurrency) | `const DEFAULT_MAX_CONCURRENCY: int = 1` |
| 常量 | [`ABSOLUTE_MAX_CONCURRENCY`](#member-gfasynckeyedgate-constants-absolute_max_concurrency) | `const ABSOLUTE_MAX_CONCURRENCY: int = 4096` |
| 常量 | [`DEFAULT_MAX_RECENT_EVENTS`](#member-gfasynckeyedgate-constants-default_max_recent_events) | `const DEFAULT_MAX_RECENT_EVENTS: int = 64` |
| 常量 | [`ABSOLUTE_MAX_RECENT_EVENTS`](#member-gfasynckeyedgate-constants-absolute_max_recent_events) | `const ABSOLUTE_MAX_RECENT_EVENTS: int = 4096` |
| 常量 | [`DEFAULT_MAX_ACTIVE_LEASES`](#member-gfasynckeyedgate-constants-default_max_active_leases) | `const DEFAULT_MAX_ACTIVE_LEASES: int = 4096` |
| 常量 | [`ABSOLUTE_MAX_ACTIVE_LEASES`](#member-gfasynckeyedgate-constants-absolute_max_active_leases) | `const ABSOLUTE_MAX_ACTIVE_LEASES: int = 65_536` |
| 常量 | [`DEFAULT_MAX_WAITING_REQUESTS`](#member-gfasynckeyedgate-constants-default_max_waiting_requests) | `const DEFAULT_MAX_WAITING_REQUESTS: int = 1024` |
| 常量 | [`ABSOLUTE_MAX_WAITING_REQUESTS`](#member-gfasynckeyedgate-constants-absolute_max_waiting_requests) | `const ABSOLUTE_MAX_WAITING_REQUESTS: int = 65_536` |
| 常量 | [`DEFAULT_MAX_WAITING_PER_KEY`](#member-gfasynckeyedgate-constants-default_max_waiting_per_key) | `const DEFAULT_MAX_WAITING_PER_KEY: int = 64` |
| 常量 | [`ABSOLUTE_MAX_WAITING_PER_KEY`](#member-gfasynckeyedgate-constants-absolute_max_waiting_per_key) | `const ABSOLUTE_MAX_WAITING_PER_KEY: int = 4096` |
| 常量 | [`DEFAULT_MAX_TRACKED_KEYS`](#member-gfasynckeyedgate-constants-default_max_tracked_keys) | `const DEFAULT_MAX_TRACKED_KEYS: int = 256` |
| 常量 | [`ABSOLUTE_MAX_TRACKED_KEYS`](#member-gfasynckeyedgate-constants-absolute_max_tracked_keys) | `const ABSOLUTE_MAX_TRACKED_KEYS: int = 16_384` |
| 常量 | [`DEFAULT_MAX_PUMP_WORK_ITEMS`](#member-gfasynckeyedgate-constants-default_max_pump_work_items) | `const DEFAULT_MAX_PUMP_WORK_ITEMS: int = 256` |
| 常量 | [`ABSOLUTE_MAX_PUMP_WORK_ITEMS`](#member-gfasynckeyedgate-constants-absolute_max_pump_work_items) | `const ABSOLUTE_MAX_PUMP_WORK_ITEMS: int = 4096` |
| 常量 | [`REASON_MAX_WAITING_REQUESTS`](#member-gfasynckeyedgate-constants-reason_max_waiting_requests) | `const REASON_MAX_WAITING_REQUESTS: StringName = &"max_waiting_requests"` |
| 常量 | [`REASON_MAX_WAITING_PER_KEY`](#member-gfasynckeyedgate-constants-reason_max_waiting_per_key) | `const REASON_MAX_WAITING_PER_KEY: StringName = &"max_waiting_per_key"` |
| 常量 | [`REASON_MAX_TRACKED_KEYS`](#member-gfasynckeyedgate-constants-reason_max_tracked_keys) | `const REASON_MAX_TRACKED_KEYS: StringName = &"max_tracked_keys"` |
| 常量 | [`REASON_CANCEL_TOKEN_CONNECT_FAILED`](#member-gfasynckeyedgate-constants-reason_cancel_token_connect_failed) | `const REASON_CANCEL_TOKEN_CONNECT_FAILED: StringName = &"cancel_token_connect_failed"` |
| 属性 | [`default_max_concurrency`](#member-gfasynckeyedgate-properties-default_max_concurrency) | `var default_max_concurrency: int:` |
| 属性 | [`max_recent_events`](#member-gfasynckeyedgate-properties-max_recent_events) | `var max_recent_events: int:` |
| 属性 | [`max_active_leases`](#member-gfasynckeyedgate-properties-max_active_leases) | `var max_active_leases: int:` |
| 属性 | [`max_waiting_requests`](#member-gfasynckeyedgate-properties-max_waiting_requests) | `var max_waiting_requests: int:` |
| 属性 | [`max_waiting_per_key`](#member-gfasynckeyedgate-properties-max_waiting_per_key) | `var max_waiting_per_key: int:` |
| 属性 | [`max_tracked_keys`](#member-gfasynckeyedgate-properties-max_tracked_keys) | `var max_tracked_keys: int:` |
| 属性 | [`max_pump_work_items`](#member-gfasynckeyedgate-properties-max_pump_work_items) | `var max_pump_work_items: int:` |
| 方法 | [`request_lease`](#member-gfasynckeyedgate-methods-request_lease) | `func request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`try_request_lease`](#member-gfasynckeyedgate-methods-try_request_lease) | `func try_request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`wait_for_lease_async`](#member-gfasynckeyedgate-methods-wait_for_lease_async) | `func wait_for_lease_async(key: Variant, options: Dictionary = {}) -> GFAsyncGateLease:` |
| 方法 | [`release_lease`](#member-gfasynckeyedgate-methods-release_lease) | `func release_lease(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:` |
| 方法 | [`cancel_request`](#member-gfasynckeyedgate-methods-cancel_request) | `func cancel_request(request_id: int, reason: StringName = STATUS_CANCELLED, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`clear`](#member-gfasynckeyedgate-methods-clear) | `func clear(reason: StringName = &"cleared", metadata: Dictionary = {}) -> int:` |
| 方法 | [`set_key_max_concurrency`](#member-gfasynckeyedgate-methods-set_key_max_concurrency) | `func set_key_max_concurrency(key: Variant, max_concurrency: int) -> int:` |
| 方法 | [`clear_key_max_concurrency`](#member-gfasynckeyedgate-methods-clear_key_max_concurrency) | `func clear_key_max_concurrency(key: Variant) -> bool:` |
| 方法 | [`clear_all_key_max_concurrency`](#member-gfasynckeyedgate-methods-clear_all_key_max_concurrency) | `func clear_all_key_max_concurrency() -> int:` |
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

<a id="member-gfasynckeyedgate-constants-status_rejected"></a>

### `STATUS_REJECTED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_REJECTED: StringName = &"rejected"
```

请求因等待队列或 key 容量耗尽而被拒绝。

<a id="member-gfasynckeyedgate-constants-status_busy"></a>

### `STATUS_BUSY`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_BUSY: StringName = &"busy"
```

fail-fast 请求未取得租约；请求未进入等待队列。

<a id="member-gfasynckeyedgate-constants-default_max_concurrency"></a>

### `DEFAULT_MAX_CONCURRENCY`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_CONCURRENCY: int = 1
```

默认每个 key 的并发槽位数。

<a id="member-gfasynckeyedgate-constants-absolute_max_concurrency"></a>

### `ABSOLUTE_MAX_CONCURRENCY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_CONCURRENCY: int = 4096
```

每个 key 最多允许配置的并发槽位数。

<a id="member-gfasynckeyedgate-constants-default_max_recent_events"></a>

### `DEFAULT_MAX_RECENT_EVENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_RECENT_EVENTS: int = 64
```

默认保留的最近事件数量。

<a id="member-gfasynckeyedgate-constants-absolute_max_recent_events"></a>

### `ABSOLUTE_MAX_RECENT_EVENTS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_RECENT_EVENTS: int = 4096
```

最近事件历史的绝对数量上限。

<a id="member-gfasynckeyedgate-constants-default_max_active_leases"></a>

### `DEFAULT_MAX_ACTIVE_LEASES`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_ACTIVE_LEASES: int = 4096
```

默认最多同时持有的 lease 总数。

<a id="member-gfasynckeyedgate-constants-absolute_max_active_leases"></a>

### `ABSOLUTE_MAX_ACTIVE_LEASES`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_ACTIVE_LEASES: int = 65_536
```

同时持有 lease 的绝对数量上限。

<a id="member-gfasynckeyedgate-constants-default_max_waiting_requests"></a>

### `DEFAULT_MAX_WAITING_REQUESTS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_WAITING_REQUESTS: int = 1024
```

默认最多保留的等待请求总数。

<a id="member-gfasynckeyedgate-constants-absolute_max_waiting_requests"></a>

### `ABSOLUTE_MAX_WAITING_REQUESTS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_WAITING_REQUESTS: int = 65_536
```

等待请求总数的绝对上限。

<a id="member-gfasynckeyedgate-constants-default_max_waiting_per_key"></a>

### `DEFAULT_MAX_WAITING_PER_KEY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_WAITING_PER_KEY: int = 64
```

默认每个 key 最多保留的等待请求数。

<a id="member-gfasynckeyedgate-constants-absolute_max_waiting_per_key"></a>

### `ABSOLUTE_MAX_WAITING_PER_KEY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_WAITING_PER_KEY: int = 4096
```

单 key 等待请求数的绝对上限。

<a id="member-gfasynckeyedgate-constants-default_max_tracked_keys"></a>

### `DEFAULT_MAX_TRACKED_KEYS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_TRACKED_KEYS: int = 256
```

默认最多跟踪的活跃、等待或显式配置 key 数。

<a id="member-gfasynckeyedgate-constants-absolute_max_tracked_keys"></a>

### `ABSOLUTE_MAX_TRACKED_KEYS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_TRACKED_KEYS: int = 16_384
```

tracked key 数量的绝对上限。

<a id="member-gfasynckeyedgate-constants-default_max_pump_work_items"></a>

### `DEFAULT_MAX_PUMP_WORK_ITEMS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_PUMP_WORK_ITEMS: int = 256
```

默认每次队列推进最多处理的等待请求数量。

<a id="member-gfasynckeyedgate-constants-absolute_max_pump_work_items"></a>

### `ABSOLUTE_MAX_PUMP_WORK_ITEMS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ABSOLUTE_MAX_PUMP_WORK_ITEMS: int = 4096
```

单次队列推进工作预算的绝对上限。

<a id="member-gfasynckeyedgate-constants-reason_max_waiting_requests"></a>

### `REASON_MAX_WAITING_REQUESTS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const REASON_MAX_WAITING_REQUESTS: StringName = &"max_waiting_requests"
```

等待请求总容量耗尽原因。

<a id="member-gfasynckeyedgate-constants-reason_max_waiting_per_key"></a>

### `REASON_MAX_WAITING_PER_KEY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const REASON_MAX_WAITING_PER_KEY: StringName = &"max_waiting_per_key"
```

单 key 等待容量耗尽原因。

<a id="member-gfasynckeyedgate-constants-reason_max_tracked_keys"></a>

### `REASON_MAX_TRACKED_KEYS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const REASON_MAX_TRACKED_KEYS: StringName = &"max_tracked_keys"
```

key 跟踪容量耗尽原因。

<a id="member-gfasynckeyedgate-constants-reason_cancel_token_connect_failed"></a>

### `REASON_CANCEL_TOKEN_CONNECT_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const REASON_CANCEL_TOKEN_CONNECT_FAILED: StringName = &"cancel_token_connect_failed"
```

取消令牌订阅建立失败原因。

## 属性

<a id="member-gfasynckeyedgate-properties-default_max_concurrency"></a>

### `default_max_concurrency`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var default_max_concurrency: int:
```

未显式配置 key 时的最大并发槽位数。

<a id="member-gfasynckeyedgate-properties-max_recent_events"></a>

### `max_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_recent_events: int:
```

最近事件历史上限。设置为 0 时不保留事件。

<a id="member-gfasynckeyedgate-properties-max_active_leases"></a>

### `max_active_leases`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_active_leases: int:
```

最多同时持有的 lease 总数。降低容量不会撤销现有 lease。

<a id="member-gfasynckeyedgate-properties-max_waiting_requests"></a>

### `max_waiting_requests`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_waiting_requests: int:
```

最多保留的等待请求总数。降低容量不会驱逐现有请求。

<a id="member-gfasynckeyedgate-properties-max_waiting_per_key"></a>

### `max_waiting_per_key`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_waiting_per_key: int:
```

每个 key 最多保留的等待请求数。降低容量不会驱逐现有请求。

<a id="member-gfasynckeyedgate-properties-max_tracked_keys"></a>

### `max_tracked_keys`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_tracked_keys: int:
```

最多跟踪的活跃、等待或显式配置 key 数。降低容量不会驱逐现有 key。

<a id="member-gfasynckeyedgate-properties-max_pump_work_items"></a>

### `max_pump_work_items`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_pump_work_items: int:
```

每次队列推进最多处理的等待请求数量。 取消和超时请求也会消耗该预算，剩余可执行工作会延迟到后续主线程迭代。

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
| `options` | 请求选项，支持 metadata、max_concurrency、timeout_msec、lease_timeout_msec 和 cancel_token。max_concurrency 只约束当前请求，不会写入持久 key 配置；正 timeout 的 deadline 超出 int64 时饱和到 int64 上限。 |

返回：请求结果字典。

结构：

- `key`: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
- `options`: Dictionary，可包含 metadata: Dictionary、max_concurrency: int、timeout_msec: int、lease_timeout_msec: int、cancel_token: GFCancellationToken。
- `return`: Dictionary，包含 ok、status、queued、acquired、request_id、key、lease、completion、metadata 和 reason。

<a id="member-gfasynckeyedgate-methods-try_request_lease"></a>

### `try_request_lease`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func try_request_lease(key: Variant, options: Dictionary = {}) -> Dictionary:
```

尝试立即取得一个 key 的执行租约。 合法且未取消的请求只有在不越过同 key waiter、未完成的公平推进周期或生命周期 通知边界时能够立即提交，才返回 acquired；容量或仲裁暂时不可用时返回 busy。 busy 不分配请求 ID 或 completion，不进入等待队列、不发出请求生命周期信号， 也不改变公平游标。非法调用返回 invalid；cancel_token 在租约提交前胜出时返回 cancelled，且按已接受请求记录取消终态。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |
| `options` | 即时请求选项，支持 metadata、max_concurrency、lease_timeout_msec 和 cancel_token。 |

返回：即时请求结果字典。

结构：

- `key`: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
- `options`: Dictionary，可包含 metadata: Dictionary、max_concurrency: int、lease_timeout_msec: int、cancel_token: GFCancellationToken。
- `return`: Dictionary，包含 ok、status、queued、acquired、request_id、key、metadata 和 reason，所有分支 queued 均为 false；status 为 acquired 时包含 lease 和已成功完成的 completion，busy 时 request_id 为 0 且不包含 lease 或 completion，cancelled/invalid 不包含 lease 或 completion。

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
| `options` | 请求选项；wait_options 会传给 GFAsyncWaitUtility.wait_completion_async()。 |

返回：获得的租约；取消、超时或失效时返回 null。

结构：

- `key`: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
- `options`: Dictionary，支持 request_lease() 选项，并可包含 wait_options: Dictionary。

<a id="member-gfasynckeyedgate-methods-release_lease"></a>

### `release_lease`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func release_lease(lease: GFAsyncGateLease, reason: StringName = &"manual") -> bool:
```

释放一个租约。 acquire/release 生命周期通知中的重入释放会延迟到最外层通知结束；通知期间的新请求 只能排队，随后与既有 waiter 一起由公平泵推进。

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

<a id="member-gfasynckeyedgate-methods-clear_key_max_concurrency"></a>

### `clear_key_max_concurrency`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_key_max_concurrency(key: Variant) -> bool:
```

清理某个 key 的显式最大并发槽位配置。 清理后该 key 会回到 default_max_concurrency；如果该 key 没有队列或活跃租约，会被从快照中裁剪。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 并发仲裁 key。 |

返回：找到并清理显式配置时返回 true。

结构：

- `key`: Variant，调用方传入的 key。

<a id="member-gfasynckeyedgate-methods-clear_all_key_max_concurrency"></a>

### `clear_all_key_max_concurrency`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_all_key_max_concurrency() -> int:
```

清理全部显式 key 最大并发槽位配置。 清理后空闲 key 会从快照中裁剪，有等待队列的 key 会按 default_max_concurrency 继续推进。

返回：被清理的显式配置数量。

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

- `return`: Dictionary，包含 queued_count、active_count、key_count、max_active_leases、等待、key 与推进预算配置、high_watermark、key_high_watermark、busy_count、rejected_count、dropped_count、acquired_count、released_count、cancelled_count、timeout_count、keys 和 recent_events。
