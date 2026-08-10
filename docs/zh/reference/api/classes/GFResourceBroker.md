# GFResourceBroker

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_broker.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

framework-level threaded ResourceLoader admission broker。 一个显式共享实例可以注入 Asset、Scene 与 BackgroundWork Utility， 统一执行有界 FIFO admission、同资源身份复用、消费者级取消和底层请求 drain。 Broker 不使用全局 singleton；架构模式应把它注册为 Utility，独立模式应显式 创建并传给每个消费者。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_ACTIVE_REQUESTS`](#member-gfresourcebroker-constants-default_max_active_requests) | `const DEFAULT_MAX_ACTIVE_REQUESTS: int = 4` |
| 常量 | [`ABSOLUTE_MAX_ACTIVE_REQUESTS`](#member-gfresourcebroker-constants-absolute_max_active_requests) | `const ABSOLUTE_MAX_ACTIVE_REQUESTS: int = 64` |
| 常量 | [`DEFAULT_MAX_PENDING_REQUESTS`](#member-gfresourcebroker-constants-default_max_pending_requests) | `const DEFAULT_MAX_PENDING_REQUESTS: int = 256` |
| 常量 | [`ABSOLUTE_MAX_PENDING_REQUESTS`](#member-gfresourcebroker-constants-absolute_max_pending_requests) | `const ABSOLUTE_MAX_PENDING_REQUESTS: int = 4096` |
| 常量 | [`REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED`](#member-gfresourcebroker-constants-reason_active_type_hint_not_satisfied) | `const REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED: String = "active_type_hint_not_satisfied"` |
| 常量 | [`REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED`](#member-gfresourcebroker-constants-reason_active_admission_constraints_not_satisfied) | `const REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED: String = "active_admission_constraints_not_satisfied"` |
| 属性 | [`max_active_requests`](#member-gfresourcebroker-properties-max_active_requests) | `var max_active_requests: int = DEFAULT_MAX_ACTIVE_REQUESTS:` |
| 属性 | [`max_pending_requests`](#member-gfresourcebroker-properties-max_pending_requests) | `var max_pending_requests: int = DEFAULT_MAX_PENDING_REQUESTS:` |
| 方法 | [`init`](#member-gfresourcebroker-methods-init) | `func init() -> void:` |
| 方法 | [`tick`](#member-gfresourcebroker-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`dispose`](#member-gfresourcebroker-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`request`](#member-gfresourcebroker-methods-request) | `func request(path: String, type_hint: String = "", options: Dictionary = {}) -> GFResourceLease:` |
| 方法 | [`pump`](#member-gfresourcebroker-methods-pump) | `func pump() -> void:` |
| 方法 | [`poll_lease`](#member-gfresourcebroker-methods-poll_lease) | `func poll_lease(lease: GFResourceLease) -> Dictionary:` |
| 方法 | [`cancel_all`](#member-gfresourcebroker-methods-cancel_all) | `func cancel_all(reason: StringName = &"cancelled") -> void:` |
| 方法 | [`is_idle`](#member-gfresourcebroker-methods-is_idle) | `func is_idle() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourcebroker-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_request_threaded_resource`](#member-gfresourcebroker-methods-_request_threaded_resource) | `func _request_threaded_resource(path: String, type_hint: String) -> Error:` |
| 方法 | [`_poll_threaded_resource`](#member-gfresourcebroker-methods-_poll_threaded_resource) | `func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:` |

## 常量

<a id="member-gfresourcebroker-constants-default_max_active_requests"></a>

### `DEFAULT_MAX_ACTIVE_REQUESTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_ACTIVE_REQUESTS: int = 4
```

默认同时允许的底层 threaded resource request 数量。

<a id="member-gfresourcebroker-constants-absolute_max_active_requests"></a>

### `ABSOLUTE_MAX_ACTIVE_REQUESTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_ACTIVE_REQUESTS: int = 64
```

同时活动的底层 threaded resource request 数量绝对上限。

<a id="member-gfresourcebroker-constants-default_max_pending_requests"></a>

### `DEFAULT_MAX_PENDING_REQUESTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_PENDING_REQUESTS: int = 256
```

默认最多等待 admission 的不同资源请求数量。

<a id="member-gfresourcebroker-constants-absolute_max_pending_requests"></a>

### `ABSOLUTE_MAX_PENDING_REQUESTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_PENDING_REQUESTS: int = 4096
```

等待 admission 的不同资源请求数量绝对上限。

<a id="member-gfresourcebroker-constants-reason_active_type_hint_not_satisfied"></a>

### `REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED: String = "active_type_hint_not_satisfied"
```

活动请求无法追溯收紧 type hint 时写入 Lease 的稳定失败原因。

<a id="member-gfresourcebroker-constants-reason_active_admission_constraints_not_satisfied"></a>

### `REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED: String = "active_admission_constraints_not_satisfied"
```

活动请求无法追溯升级 admission 约束时写入 Lease 的稳定失败原因。

## 属性

<a id="member-gfresourcebroker-properties-max_active_requests"></a>

### `max_active_requests`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_active_requests: int = DEFAULT_MAX_ACTIVE_REQUESTS:
```

同时允许的底层 threaded resource request 数量。

<a id="member-gfresourcebroker-properties-max_pending_requests"></a>

### `max_pending_requests`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_pending_requests: int = DEFAULT_MAX_PENDING_REQUESTS:
```

最多等待 admission 的不同资源请求数量。 同一路径复用只增加消费者 Lease，不占用额外 pending 配额。

## 方法

<a id="member-gfresourcebroker-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func init() -> void:
```

初始化 Broker。

<a id="member-gfresourcebroker-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

推进底层请求轮询与 admission。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 统一 Utility tick 参数。 |

<a id="member-gfresourcebroker-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

取消所有消费者，并让已发起的请求保留为 drain 状态。

<a id="member-gfresourcebroker-methods-request"></a>

### `request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func request(path: String, type_hint: String = "", options: Dictionary = {}) -> GFResourceLease:
```

请求一个资源消费者 Lease。 admission 使用严格 FIFO：队首独占请求会等待全部活动请求 drain， 后续共享请求不能绕过它。同资源身份且类型提示兼容的请求复用底层加载。

参数：

| 名称 | 说明 |
|---|---|
| `path` | \`res://\` 或 \`uid://\` 资源路径。 |
| `type_hint` | 可选 ResourceLoader 类型提示。 |
| `options` | admission 与诊断选项。 |

返回：独立消费者 Lease；拒绝时返回 failed Lease。

结构：

- `options`: Dictionary with optional exclusive: bool, require_idle: bool, and consumer_id: StringName.

<a id="member-gfresourcebroker-methods-pump"></a>

### `pump`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pump() -> void:
```

推进所有活动请求并尝试 admission。 架构注册的 Broker 会由 Utility tick 自动调用；独立使用时由调用方显式调用。

<a id="member-gfresourcebroker-methods-poll_lease"></a>

### `poll_lease`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func poll_lease(lease: GFResourceLease) -> Dictionary:
```

推进 Broker 并导出指定 Lease 的状态。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 要观察的消费者 Lease。 |

返回：Lease 状态字典。

结构：

- `return`: Dictionary with status, progress, resource, has_resource, error, request_error, path, type_hint, consumer_id, exclusive, require_idle, cancel_reason, and released.

<a id="member-gfresourcebroker-methods-cancel_all"></a>

### `cancel_all`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_all(reason: StringName = &"cancelled") -> void:
```

取消所有尚未完成的消费者 Lease。 尚未 admission 的请求会立即移除；已经发起的请求继续 drain 到 ResourceLoader 终态。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 用于诊断的稳定取消原因。 |

<a id="member-gfresourcebroker-methods-is_idle"></a>

### `is_idle`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_idle() -> bool:
```

Broker 是否已经没有 queued、active 或 draining 请求。

返回：完全 idle 时返回 true。

<a id="member-gfresourcebroker-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

导出有界 admission 与底层请求调试快照。

返回：Broker 状态字典。

结构：

- `return`: Dictionary with active_count, pending_count, draining_count, active_exclusive, active_paths, pending_paths, draining_paths, max_active_requests, and max_pending_requests.

<a id="member-gfresourcebroker-methods-_request_threaded_resource"></a>

### `_request_threaded_resource`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _request_threaded_resource(path: String, type_hint: String) -> Error:
```

发起底层 ResourceLoader threaded request。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 规范化资源路径。 |
| `type_hint` | ResourceLoader 类型提示。 |

返回：Godot Error。

<a id="member-gfresourcebroker-methods-_poll_threaded_resource"></a>

### `_poll_threaded_resource`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
```

轮询底层 ResourceLoader threaded request。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 规范化资源路径。 |
| `previous_progress` | 上次已知进度。 |

返回：adapter 状态字典。

结构：

- `return`: Dictionary with status, progress, resource, has_resource, and error.
