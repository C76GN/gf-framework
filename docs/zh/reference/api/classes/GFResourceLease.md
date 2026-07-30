# GFResourceLease

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_lease.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

共享资源 Broker 返回的消费者所有权句柄。 每次请求都会得到独立 Lease；同一路径可以复用同一个底层 threaded load， 但取消或释放只影响当前消费者。未完成时释放最后一个 Lease 会让 Broker 继续 drain 已经发起且无法中止的 ResourceLoader 请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_QUEUED`](#member-gfresourcelease-constants-status_queued) | `const STATUS_QUEUED: StringName = &"queued"` |
| 常量 | [`STATUS_LOADING`](#member-gfresourcelease-constants-status_loading) | `const STATUS_LOADING: StringName = &"loading"` |
| 常量 | [`STATUS_COMPLETED`](#member-gfresourcelease-constants-status_completed) | `const STATUS_COMPLETED: StringName = &"completed"` |
| 常量 | [`STATUS_FAILED`](#member-gfresourcelease-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfresourcelease-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 方法 | [`cancel`](#member-gfresourcelease-methods-cancel) | `func cancel(reason: StringName = &"cancelled") -> void:` |
| 方法 | [`release`](#member-gfresourcelease-methods-release) | `func release() -> void:` |
| 方法 | [`is_terminal`](#member-gfresourcelease-methods-is_terminal) | `func is_terminal() -> bool:` |
| 方法 | [`is_released`](#member-gfresourcelease-methods-is_released) | `func is_released() -> bool:` |
| 方法 | [`get_status`](#member-gfresourcelease-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_progress`](#member-gfresourcelease-methods-get_progress) | `func get_progress() -> float:` |
| 方法 | [`get_resource`](#member-gfresourcelease-methods-get_resource) | `func get_resource() -> Resource:` |
| 方法 | [`get_path`](#member-gfresourcelease-methods-get_path) | `func get_path() -> String:` |
| 方法 | [`get_type_hint`](#member-gfresourcelease-methods-get_type_hint) | `func get_type_hint() -> String:` |
| 方法 | [`get_consumer_id`](#member-gfresourcelease-methods-get_consumer_id) | `func get_consumer_id() -> StringName:` |
| 方法 | [`get_request_error`](#member-gfresourcelease-methods-get_request_error) | `func get_request_error() -> Error:` |
| 方法 | [`get_error_message`](#member-gfresourcelease-methods-get_error_message) | `func get_error_message() -> String:` |
| 方法 | [`to_poll_result`](#member-gfresourcelease-methods-to_poll_result) | `func to_poll_result() -> Dictionary:` |

## 常量

<a id="member-gfresourcelease-constants-status_queued"></a>

### `STATUS_QUEUED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_QUEUED: StringName = &"queued"
```

请求正在等待 Broker admission。

<a id="member-gfresourcelease-constants-status_loading"></a>

### `STATUS_LOADING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_LOADING: StringName = &"loading"
```

底层 threaded resource request 已经开始。

<a id="member-gfresourcelease-constants-status_completed"></a>

### `STATUS_COMPLETED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_COMPLETED: StringName = &"completed"
```

资源已经成功交付给当前消费者。

<a id="member-gfresourcelease-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

资源请求失败。

<a id="member-gfresourcelease-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

当前消费者已经取消请求。

## 方法

<a id="member-gfresourcelease-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel(reason: StringName = &"cancelled") -> void:
```

取消当前消费者的请求。 取消不会影响复用同一底层请求的其他 Lease。若当前 Lease 是最后一个消费者， Broker 会继续 drain 已经开始的底层请求，但不会交付其结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 用于诊断的稳定取消原因。 |

<a id="member-gfresourcelease-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> void:
```

释放当前 Lease 持有的消费者引用和已交付资源。

<a id="member-gfresourcelease-methods-is_terminal"></a>

### `is_terminal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_terminal() -> bool:
```

请求是否已经到达终态。

返回：completed、failed 或 cancelled 时返回 true。

<a id="member-gfresourcelease-methods-is_released"></a>

### `is_released`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_released() -> bool:
```

Lease 是否已经释放。

返回：已释放时返回 true。

<a id="member-gfresourcelease-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取当前状态。

返回：状态常量。

<a id="member-gfresourcelease-methods-get_progress"></a>

### `get_progress`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_progress() -> float:
```

获取当前加载进度。

返回：范围为 0.0 到 1.0 的进度值。

<a id="member-gfresourcelease-methods-get_resource"></a>

### `get_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resource() -> Resource:
```

获取加载成功的资源。

返回：成功且尚未释放时返回资源，否则返回 null。

<a id="member-gfresourcelease-methods-get_path"></a>

### `get_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_path() -> String:
```

获取资源路径。

返回：Broker 使用的规范化加载路径。

<a id="member-gfresourcelease-methods-get_type_hint"></a>

### `get_type_hint`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_type_hint() -> String:
```

获取请求类型提示。

返回：ResourceLoader 类型提示。

<a id="member-gfresourcelease-methods-get_consumer_id"></a>

### `get_consumer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_consumer_id() -> StringName:
```

获取消费者标识。

返回：调用方提供的诊断标识。

<a id="member-gfresourcelease-methods-get_request_error"></a>

### `get_request_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_error() -> Error:
```

获取请求错误码。

返回：admission 或底层请求失败的 Godot Error。

<a id="member-gfresourcelease-methods-get_error_message"></a>

### `get_error_message`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_message() -> String:
```

获取失败说明。

返回：失败或取消说明。

<a id="member-gfresourcelease-methods-to_poll_result"></a>

### `to_poll_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_poll_result() -> Dictionary:
```

导出当前消费者视角的结构化状态。

返回：Lease 状态字典。

结构：

- `return`: Dictionary with status, progress, resource, has_resource, error, request_error, path, type_hint, consumer_id, exclusive, require_idle, cancel_reason, and released.
